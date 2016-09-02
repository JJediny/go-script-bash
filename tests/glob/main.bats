#! /usr/bin/env bats

load ../environment
load ../assertions
load ../script_helper

TESTS_DIR="$TEST_GO_ROOTDIR/tests"

setup() {
  mkdir -p "$TESTS_DIR"
}

teardown() {
  remove_test_go_rootdir
}

@test "glob: error on unknown flag" {
  run "$BASH" ./go glob --foobar
  assert_failure 'Unknown flag: --foobar'

  run "$BASH" ./go glob --compact --ignore '*' --foobar
  assert_failure 'Unknown flag: --foobar'
}

@test "glob: error if rootdir not specified" {
  local err_msg='Root directory argument not specified.'
  run "$BASH" ./go glob
  assert_failure "$err_msg"

  run "$BASH" ./go glob --compact --ignore '*'
  assert_failure "$err_msg"
}

@test "glob: error if rootdir argument is not a directory" {
  local err_msg='Root directory argument bogus_dir is not a directory.'
  run "$BASH" ./go glob bogus_dir
  assert_failure "$err_msg"

  run "$BASH" ./go glob --compact --ignore '*' bogus_dir
  assert_failure "$err_msg"
}

@test "glob: error if file suffix argument not specified" {
  local err_msg='File suffix argument not specified.'
  run "$BASH" ./go glob "$TESTS_DIR"
  assert_failure "$err_msg"

  run "$BASH" ./go glob --compact --ignore '*' "$TESTS_DIR"
  assert_failure "$err_msg"
}

@test "glob: error if no files match pattern" {
  run "$BASH" ./go glob "$TESTS_DIR" '.bats'
  assert_failure "\"*\" does not match any .bats files in $TESTS_DIR."

  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'foo'
  assert_failure "\"foo\" does not match any .bats files in $TESTS_DIR."
}

@test "glob: no glob patterns defaults to matching all files" {
  local expected=(
    "$TESTS_DIR/bar.bats" "$TESTS_DIR/baz.bats" "$TESTS_DIR/foo.bats")
  touch "${expected[@]}"

  run "$BASH" ./go glob "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: start glob matches all files" {
  local expected=(
    "$TESTS_DIR/bar.bats" "$TESTS_DIR/baz.bats" "$TESTS_DIR/foo.bats")
  touch "${expected[@]}"

  run "$BASH" ./go glob "$TESTS_DIR" '.bats' '*'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: --compact strips rootdir and suffix from all files" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  local expected=('bar' 'baz' 'foo')

  run "$BASH" ./go glob --compact "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: match nothing if the suffix doesn't match" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bash'
  local IFS=$'\n'
  assert_failure "\"*\" does not match any .bash files in $TESTS_DIR."
}

@test "glob: set --ignore patterns" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  local expected=('bar' 'baz' 'foo')

  run "$BASH" ./go glob --ignore 'ba*' "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "$TESTS_DIR/foo.bats"

  run "$BASH" ./go glob --ignore 'f*' --compact "$TESTS_DIR" '.bats'
  expected=('bar' 'baz')
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --compact --ignore 'ba*:f*' "$TESTS_DIR" '.bats'
  assert_failure "\"*\" does not match any .bats files in $TESTS_DIR."
}

@test "glob: match single file" {
  touch $TESTS_DIR/{bar,baz,foo}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'foo'
  local IFS=$'\n'
  assert_success "$TESTS_DIR/foo.bats"
}

@test "glob: match multiple files" {
  local expected=("$TESTS_DIR/bar.bats" "$TESTS_DIR/baz.bats")
  touch $TESTS_DIR/{bar,baz,foo}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'ba*'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: match multiple patterns" {
  local expected=(
    "$TESTS_DIR/bar.bats" "$TESTS_DIR/baz.bats" "$TESTS_DIR/foo.bats")
  touch $TESTS_DIR/{bar,baz,foo,quux,plugh,xyzzy}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'ba*' 'foo'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: exact file match when a directory of the same name exists" {
  mkdir $TESTS_DIR/foo
  touch $TESTS_DIR/foo.bats $TESTS_DIR/foo/{bar,baz,quux}.bats
  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'foo'
  local IFS=$'\n'
  assert_success "$TESTS_DIR/foo.bats"
}

@test "glob: recursive directory match when pattern ends with a separator" {
  mkdir $TESTS_DIR/foo
  touch $TESTS_DIR/foo.bats $TESTS_DIR/foo/{bar,baz,quux}.bats
  local expected=(
    "$TESTS_DIR/foo/bar.bats"
    "$TESTS_DIR/foo/baz.bats"
    "$TESTS_DIR/foo/quux.bats")

  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'foo/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: pattern matches file and a directory of the same name" {
  mkdir $TESTS_DIR/foo
  touch $TESTS_DIR/foo.bats $TESTS_DIR/foo/{bar,baz,quux}.bats
  local expected=(
    "$TESTS_DIR/foo.bats"
    "$TESTS_DIR/foo/bar.bats"
    "$TESTS_DIR/foo/baz.bats"
    "$TESTS_DIR/foo/quux.bats")

  run "$BASH" ./go glob "$TESTS_DIR" '.bats' 'foo*'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "glob: recursively discover files" {
  mkdir -p $TESTS_DIR/foo/bar/baz $TESTS_DIR/quux/xyzzy $TESTS_DIR/plugh \
    $TESTS_DIR/ignore-me $TESTS_DIR/bar/ignore-me
  touch $TESTS_DIR/foo/bar/baz/{frobozz,zork,ignore-me}.bats \
    $TESTS_DIR/quux/xyzzy/frotz.bats \
    $TESTS_DIR/quux/xyzzy.bats \
    $TESTS_DIR/plugh/bogus.not-the-right-type \
    $TESTS_DIR/plugh/{jimi,john}.bats \
    $TESTS_DIR/plugh.{bats,c,md} \
    $TESTS_DIR/ignore-me/{foo,bar,baz}.bats \
    $TESTS_DIR/bar/ignore-me/{foo,bar,baz}.bats
  local expected=(
    "foo/bar/baz/frobozz"
    "foo/bar/baz/zork"
    "plugh"
    "plugh/jimi"
    "plugh/john"
    "quux/xyzzy"
    "quux/xyzzy/frotz")

  run "$BASH" ./go glob --ignore '*ignore-me*' --compact "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
