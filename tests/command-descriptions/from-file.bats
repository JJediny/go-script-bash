#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

TEST_COMMAND_SCRIPT_PATH="$TEST_GO_SCRIPTS_DIR/test-command"

setup() {
  . 'lib/internal/command_descriptions'

  local script='#
# Command that does something in {{root}}
#
# Usage: {{go}} {{cmd}} [args...]
#
# Paragraphs of adjacent lines
# will be joined. They will not be
# folded; @go.printf will take care of
# that.
#
# Lines indented by two spaces
# like the following are considered
# preformatted, and will not be joined:
#
#   foo bar baz
#     preformatted lines should support
#       multiple indentations
#   quux xyzzy plugh
#
# Indented lines that look like tables
# (there are two or more adjacent spaces
# after the first non-space character)
# will be parsed as summary items and folded
# as appropriate. Each table item should be only
# one line long.
#
#   foo    All work and no play makes Mike a dull boy.
#   bar    All Work and no play makes Mike a dull boy.
#   baz    All work and nO play makes Mike a dull boy.
#   quux   All work and no play Makes Mike a dull boy.
#   xyzzy  all work and no play makes mike a Dull Boy.
#   plugh  all werk and no play makes mike a dull Boy

echo The command script starts now.
'
  create_test_command_script 'test-command' "$script"
}

teardown() {
  remove_test_go_rootdir
}

@test "$SUITE: return error if there's an error reading" {
  if fs_missing_permission_support; then
    skip "Can't trigger condition on this file system"
  elif [[ "$EUID" -eq '0' ]]; then
    skip "Can't trigger condition when run by superuser"
  fi

  chmod ugo-r "$TEST_COMMAND_SCRIPT_PATH"

  run _@go.command_summary "$TEST_COMMAND_SCRIPT_PATH"
  assert_failure
  assert_output_matches "ERROR: problem reading $TEST_COMMAND_SCRIPT_PATH\$"

  output=''
  run _@go.command_description "$TEST_COMMAND_SCRIPT_PATH"
  assert_failure
  assert_output_matches "ERROR: problem reading $TEST_COMMAND_SCRIPT_PATH\$"
}

@test "$SUITE: return default text when no description is available" {
  create_test_command_script 'test-command' \
    'echo "This script has no description"'

  local __go_cmd_desc=''
  _@go.command_summary "$TEST_COMMAND_SCRIPT_PATH"
  assert_equal 'No description available' "$__go_cmd_desc" 'command summary'

  __go_cmd_desc=''
  _@go.command_description "$TEST_COMMAND_SCRIPT_PATH"
  assert_equal 'No description available' "$__go_cmd_desc" 'command description'
}

@test "$SUITE: parse summary from command script" {
  _GO_ROOTDIR='/foo/bar'
  _@go.command_summary "$TEST_COMMAND_SCRIPT_PATH"
  assert_equal 'Command that does something in /foo/bar' "$__go_cmd_desc" \
    'command summary'
}

@test "$SUITE: one-line description from command script has no trailing space" {
  echo '# Command that does something in {{root}}' > "$TEST_COMMAND_SCRIPT_PATH"
  _GO_ROOTDIR='/foo/bar'
  COLUMNS=40

  _@go.command_description "$TEST_COMMAND_SCRIPT_PATH"
  assert_equal 'Command that does something in /foo/bar' "$__go_cmd_desc" \
    'one-line command description'
}

@test "$SUITE: parse description from command script" {
  _GO_CMD='test-go'
  _GO_ROOTDIR='/foo/bar'
  COLUMNS=40
  _@go.command_description "$TEST_COMMAND_SCRIPT_PATH"

  local expected='Command that does something in /foo/bar

Usage: test-go test-command [args...]

Paragraphs of adjacent lines will be joined. They will not be folded; @go.printf will take care of that.

Lines indented by two spaces like the following are considered preformatted, and will not be joined:

  foo bar baz
    preformatted lines should support
      multiple indentations
  quux xyzzy plugh

Indented lines that look like tables (there are two or more adjacent spaces after the first non-space character) will be parsed as summary items and folded as appropriate. Each table item should be only one line long.

  foo    All work and no play makes
           Mike a dull boy.
  bar    All Work and no play makes
           Mike a dull boy.
  baz    All work and nO play makes
           Mike a dull boy.
  quux   All work and no play Makes
           Mike a dull boy.
  xyzzy  all work and no play makes
           mike a Dull Boy.
  plugh  all werk and no play makes
           mike a dull Boy
'

  # With this test, I learned that you _do_ have to quote strings even inside of
  # '[[' and ']]' in case the strings themselves contain '[' or ']', as with
  # '[args...]' above.
  assert_equal "$expected" "$__go_cmd_desc" 'command description'
}
