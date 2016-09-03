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

@test "$SUITE: zero arguments" {
  local expected=('--compact' '--ignore')
  expected+=($(compgen -d))

  run "$BASH" ./go glob --complete 0
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: first argument" {
  local expected=('--compact' '--ignore')
  expected+=($(compgen -d))

  run "$BASH" ./go glob --complete 0 ''
  local IFS=$'\n'
  assert_success "${expected[*]}"

  expected=('--compact' '--ignore')
  run "$BASH" ./go glob --complete 0 '-'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 0 '--c'
  assert_success '--compact'

  run "$BASH" ./go glob --complete 0 '--i'
  assert_success '--ignore'

  expected=('lib' 'libexec')
  run "$BASH" ./go glob --complete 0 'li'
  assert_success "${expected[*]}"
}

@test "$SUITE: completion omits flags already present" {
  local expected=('--ignore' $(compgen -d))
  run "$BASH" ./go glob --complete 1 '--compact'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 1 '--compact' '-'
  assert_success '--ignore'

  expected[0]='--compact'
  run "$BASH" ./go glob --complete 2 '--ignore' 'foo*:bar*'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 2 '--ignore' 'foo*:bar*' '-'
  assert_success '--compact'

  unset expected[0]
  run "$BASH" ./go glob --complete 3 '--ignore' 'foo*:bar*' '--compact'
  assert_success "${expected[*]}"

  expected=('lib' 'libexec')
  run "$BASH" ./go glob --complete 3 '--ignore' 'foo*:bar*' '--compact' 'li'
  assert_success "${expected[*]}"
}

@test "$SUITE: argument does not complete if previous is --ignore" {
  # The next argument should be the GLOBIGNORE value.
  run "$BASH" ./go glob --complete 1 '--ignore'
  assert_failure ''

  run "$BASH" ./go glob --complete 2 '--compact' '--ignore'
  assert_failure ''

  run "$BASH" ./go glob --complete 1 '--ignore' '' 'tests'
  assert_failure
}

@test "$SUITE: argument does not complete if previous is root dir" {
  # The next argument should be the suffix pattern.
  run "$BASH" ./go glob --complete 1 'tests'
  assert_failure ''

  run "$BASH" ./go glob --complete 2 '--compact' 'tests'
  assert_failure ''

  run "$BASH" ./go glob --complete 4 '--compact' '--ignore' 'foo*:bar*' 'tests'
  assert_failure ''
}

@test "$SUITE: arguments before flags only complete other flags" {
  run "$BASH" ./go glob --complete 0 '' '--compact'
  assert_success '--ignore'

  run "$BASH" ./go glob --complete 0 '' '--ignore'
  assert_success '--compact'
}

@test "$SUITE: complete flags before rootdir" {
  local expected=('--compact' '--ignore')
  run "$BASH" ./go glob --complete 0 '' 'tests'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 1 '--compact' '' 'tests'
  assert_success '--ignore'

  run "$BASH" ./go glob --complete 2 '--ignore' 'foo*:bar*' '' 'tests'
  assert_success '--compact'
}

@test "$SUITE: complete rootdir" {
  run "$BASH" ./go glob --complete 0 'tests'
  assert_success 'tests'

  local expected=($(compgen -d 'tests/'))
  run "$BASH" ./go glob --complete 0 'tests/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: complete top-level glob patterns" {
  touch $TESTS_DIR/{foo,bar,baz}.bats
  local expected=('bar' 'baz' 'foo')

  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 3 '--compact' "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 3 "$TESTS_DIR" '.bats' 'foo'
  assert_success "${expected[*]}"

  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats' '' 'foo'
  assert_success "${expected[*]}"
}

@test "$SUITE: match a file and directory of the same name" {
  mkdir "$TESTS_DIR/foo"
  touch $TESTS_DIR/foo{,/bar,/baz}.bats
  local expected=('foo' 'foo/')

  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats' 'f'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: complete second-level glob pattern" {
  mkdir "$TESTS_DIR/foo"
  touch $TESTS_DIR/foo{,/bar,/baz}.bats
  local expected=('foo/bar' 'foo/baz')

  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats' 'foo/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: complete directories that don't match file names" {
  mkdir $TESTS_DIR/foo
  touch $TESTS_DIR/foo/{bar,baz}.bats

  local expected=('foo/bar' 'foo/baz')
  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats' 'foo/'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}

@test "$SUITE: honor --ignore patterns during completion" {
  mkdir $TESTS_DIR/{foo,bar,baz}
  touch $TESTS_DIR/{foo/quux,bar/xyzzy,baz/plugh,baz/xyzzy}.bats

  # Remember that --ignore will add the rootdir to all the patterns.
  run "$BASH" ./go glob --complete 4 '--ignore' "foo/*:bar/*:baz/pl*" \
    "$TESTS_DIR" '.bats'
  local IFS=$'\n'
  assert_success 'baz/xyzzy'

  # Make sure the --ignore argument has any quotes removed, as the shell will
  # not expand any command line arguments or unquote them during completion.
  run "$BASH" ./go glob --complete 4 '--ignore' "'foo/*:bar/*:baz/pl*'" \
    "$TESTS_DIR" '.bats'
  assert_success 'baz/xyzzy'
}

@test "$SUITE: return error if no matches" {
  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats' 'foo'
  assert_failure
}

@test "$SUITE: return full path if only one match" {
  mkdir "$TESTS_DIR/foo"
  touch "$TESTS_DIR/foo/bar.bats"
  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats' 'f'
  assert_success "foo/bar"
}

@test "$SUITE: return completions with longest possible prefix" {
  mkdir -p $TESTS_DIR/foo/bar/{baz,quux}
  touch $TESTS_DIR/foo/bar/{baz/xyzzy,quux/plugh}.bats

  local expected=('foo/bar/baz/' 'foo/bar/quux/')
  run "$BASH" ./go glob --complete 2 "$TESTS_DIR" '.bats' 'f'
  local IFS=$'\n'
  assert_success "${expected[*]}"
}
