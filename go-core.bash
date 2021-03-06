#! /bin/bash
#
# Framework for writing "./go" scripts in Bash.
#
# Version: v1.0.0
# URL: https://github.com/mbland/go-script-bash
#
# To use this framework, create a bash script in the root directory of your
# project to act as the main './go' script. This script need not be named 'go',
# but it must contain the following as the first and last executable lines,
# respectively:
#
#   . "${0%/*}/go-core.bash" "scripts"
#   @go "$@"
#
# where "${0%/*}" produces the path to the project's root directory,
# "/go-core.bash" is the relative path to this file, and "scripts" is the
# relative path from the project root to the command script directory.
#
# See README.md for details about other available features.
#
# Inspired by:
# - "In Praise of the ./go Script: Parts I and II" by Pete Hodgson
#   https://www.thoughtworks.com/insights/blog/praise-go-script-part-i
#   https://www.thoughtworks.com/insights/blog/praise-go-script-part-ii
# - rbenv: https://github.com/rbenv/rbenv
#
# Author: Mike Bland <mbland@acm.org>
#           https://mike-bland.com/
#           https://github.com/mbland

if [[ "${BASH_VERSINFO[0]}" -lt '3' || "${BASH_VERSINFO[1]}" -lt '2' ]]; then
  printf "This module requires bash version 3.2 or greater:\n  %s %s\n" \
    "$BASH" "$BASH_VERSION"
  exit 1
fi

declare __go_orig_dir="$PWD"
cd "${0%/*}" || exit 1

# Path to the project's root directory
#
# This is directory containing the main ./go script. All functions, commands,
# and scripts are invoked relative to this directory.
#
# NOTE:
# ----
# This and other variables are exported, so that command scripts written in
# languages other than Bash (and hence run in new processes) can access them.
declare -r -x _GO_ROOTDIR="$PWD"

if [[ "${BASH_SOURCE[0]:0:1}" != '/' ]]; then
  cd "$__go_orig_dir/${BASH_SOURCE[0]%/*}" || exit 1
else
  cd "${BASH_SOURCE[0]%/*}" || exit 1
fi
unset __go_orig_dir

# Path to the ./go script framework's directory
declare -r -x _GO_CORE_DIR="$PWD"
cd "$_GO_ROOTDIR" || exit 1

# Path to the script used to import optional library modules.
#
# After sourcing go-core.bash, your `./go` script, Bash command scripts, and
# individual Bash functions can then import optional Bash library modules from
# the core framework, from installed plugins, and from your scripts directory
# like so:
#
#   . "$_GO_USE_MODULES" 'log'
#
# See `./go modules --help` for more information.
#
# NOTE:
# ----
# This and some other variables are _not_ exported, since they are specific to
# Bash command scripts, which are sourced into the ./go script process itself.
declare -r _GO_USE_MODULES="$_GO_CORE_DIR/lib/internal/use"

# Array of modules imported via _GO_USE_MODULES
declare _GO_IMPORTED_MODULES=()

# Path to the project's script directory
declare -x _GO_SCRIPTS_DIR=

# Path to the main ./go script in the project's root directory
declare -r -x _GO_SCRIPT="$_GO_ROOTDIR/${0##*/}"

# The name of either the ./go script itself or the shell function invoking it.
declare -r -x _GO_CMD="${_GO_CMD:=$0}"

# The URL of the framework's original source repository.
declare -r -x _GO_CORE_URL='https://github.com/mbland/go-script-bash'

# Invokes printf builtin, then folds output to $COLUMNS width if 'fold' exists.
#
# Should be used as the last step to print to standard output or error, as that
# is more efficient than calling this multiple times due to the pipe to 'fold'.
#
# Arguments:
#   everything accepted by the printf builtin except the '-v varname' option
@go.printf() {
  local format="$1"
  shift

  if [[ "$#" -eq 0 ]]; then
    format="${format//\%/%%}"
  fi

  if command -v fold >/dev/null; then
    printf "$format" "$@" | fold -s -w $COLUMNS
  else
    printf "$format" "$@"
  fi
}

# Main driver of ./go script functionality.
#
# Arguments:
#   $1: name of the command to invoke
#   $2..$#: arguments to the specified command
@go() {
  local cmd="$1"
  shift

  case "$cmd" in
  '')
    _@go.source_builtin 'help' 1>&2
    return 1
    ;;
  -h|-help|--help)
    cmd='help'
    ;;
  -*)
    @go.printf "Unknown flag: $cmd\n\n"
    _@go.source_builtin 'help' 1>&2
    return 1
    ;;
  edit)
    if [[ -z "$EDITOR" ]]; then
      echo "Cannot edit $@: \$EDITOR not defined."
      return 1
    fi
    "$EDITOR" "$@"
    return
    ;;
  run)
    "$@"
    return
    ;;
  cd|pushd|unenv)
    @go.printf "$cmd is only available after using \"$_GO_CMD env\" %s\n" \
      "to set up your shell environment." >&2
    return 1
    ;;
  esac

  if _@go.source_builtin 'aliases' --exists "$cmd"; then
    "$cmd" "$@"
    return
  fi

  . "$_GO_CORE_DIR/lib/internal/path"
  local __go_cmd_path
  local __go_argv

  if ! _@go.set_command_path_and_argv "$cmd" "$@"; then
    return 1
  fi
  _@go.run_command_script "$__go_cmd_path" "${__go_argv[@]}"
}

_@go.source_builtin() {
  local c="$1"
  shift
  . "$_GO_CORE_DIR/libexec/$c"
}

_@go.run_command_script() {
  local cmd_path="$1"
  shift

  local interpreter
  read -r interpreter < "$cmd_path"

  if [[ "${interpreter:0:2}" != '#!' ]]; then
    @go.printf \
      "The first line of %s does not contain #!/path/to/interpreter.\n" \
      "$cmd_path" >&2
    return 1
  fi

  interpreter="${interpreter%$'\r'}"
  interpreter="${interpreter:2}"
  interpreter="${interpreter#*/env }"
  interpreter="${interpreter##*/}"
  interpreter="${interpreter%% *}"

  if [[ "$interpreter" == 'bash' || "$interpreter" == 'sh' ]]; then
    . "$cmd_path" "$@"
  elif [[ -n "$interpreter" ]]; then
    "$interpreter" "$cmd_path" "$@"
  else
    @go.printf "Could not parse interpreter from first line of $cmd_path.\n" >&2
    return 1
  fi
}

_@go.set_scripts_dir() {
  local scripts_dir="$_GO_ROOTDIR/$1"

  if [[ "$#" -ne '1' ]]; then
    echo "ERROR: there should be exactly one command script dir specified" >&2
    return 1
  elif [[ ! -e "$scripts_dir" ]]; then
    echo "ERROR: command script directory $scripts_dir does not exist" >&2
    return 1
  elif [[ ! -d "$scripts_dir" ]]; then
    echo "ERROR: $scripts_dir is not a directory" >&2
    return 1
  elif [[ ! -r "$scripts_dir" || ! -x "$scripts_dir" ]]; then
    echo "ERROR: you do not have permission to access the $scripts_dir" \
      "directory" >&2
    return 1
  fi
  _GO_SCRIPTS_DIR="$scripts_dir"
}

if ! _@go.set_scripts_dir "$@"; then
  exit 1
elif [[ -z "$COLUMNS" ]]; then
  if command -v 'tput' >/dev/null; then
    COLUMNS="$(tput cols)"
  elif command -v 'mode.com' >/dev/null; then
    COLUMNS="$(mode.com) con:"
    shopt -s extglob
    COLUMNS="${COLUMNS##*Columns:+( )}"
    shopt -u extglob
    COLUMNS="${COLUMNS%%[ $'\r'$'\n']*}"
  else
    COLUMNS=80
  fi
  export COLUMNS
fi
