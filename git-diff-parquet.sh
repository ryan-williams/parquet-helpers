#!/usr/bin/env bash

set -e

err() {
  echo "$*" >&2
}

usage() {
  name="$(basename "$0")"
  err "$name:"
  err
  err '  # Invoked by `git diff`:'
  err "  $name <repo relpath> <old version tmpfile> <old hexsha> <old filemode> <new version tmpfile> <new hexsha> <new filemode>"
  err
  err '  # Invoked by e.g. `git diff --no-index --ext-diff`:'
  err "  $name <old version tmpfile> <new version tmpfile>"
  err
  err 'Pass opts via the $GIT_DIFF_PQT_OPTS env var:'
  err
  err '- `-c`: `--color=always`'
  err '- `-C`: `--color=never`'
  err '- `-v`: verbose/debug mode'
  err
  err 'The "opts var" itself ("GIT_DIFF_PQT_OPTS" by default) can also be customized, by setting `$GIT_DIFF_PQT_OPTS_VAR`, e.g.:'
  err
  err '  export GIT_DIFF_PQT_OPTS_VAR=GIT_PQT  # This can be done once, e.g. in your .bashrc'
  err '  GIT_PQT="-cv" git diff                # Shorter var name can then be used to configure diffs (in this case: force colorize, enable debug logging)'
  exit 1
}

color=
verbose=
parse() {
  while getopts "cCv" opt; do
    case "$opt" in
      c) color=always ;;
      C) color=never ;;
      v) verbose=1 ;;
      \?) usage ;;
    esac
  done
}

OPTS_VAR="${GIT_DIFF_PQT_OPTS_VAR:-GIT_DIFF_PQT_OPTS}"
OPTS="${!OPTS_VAR}"
if [ -n "$OPTS" ]; then
  IFS=' ' read -ra opts <<< "$OPTS"
  parse "${opts[@]}"
fi

if [ -n "$verbose" ]; then
  echo "git-diff-parquet.sh ($#):"
  for arg in "$@"; do
    echo "  $arg"
  done
  echo
  set -x
fi

# Export opt vars for parquet2json-all, set `-n2` fallback
OPTS_VAR="${PQT_TXT_OPTS_VAR:-PQT_TXT_OPTS}"
OPTS="-n2 ${!OPTS_VAR}"
printf -v "$OPTS_VAR" '%s' "-n2 $OPTS"
export PQT_TXT_OPTS_VAR
export "$OPTS_VAR"

cmd=(parquet2json-all)

if [ "$#" -eq 7 ]; then
  path="$1"  ; shift  # repo relpath
  pqt0="$1"  ; shift  # old version
  hex0="$1"  ; shift  # old hexsha
  mode0="$1" ; shift  # old filemode
  pqt1="$1"  ; shift  # new version
  hex1="$1"  ; shift  # new hexsha
  mode1="$1" ; shift  # new filemode

  if [ "$mode0" == . ]; then mode0=; fi
  if [ "$mode1" == . ]; then mode1=; fi

  mode_str=0
  if [ "$mode0" != "$mode1" ]; then
    mode_str=", $mode0..$mode1"
  fi
  if [ "$hex0" == . ]; then
    hx0=000000
  else
    hx0="$(git rev-parse --short "$hex0")"
  fi
  if [ "$hex1" == . ]; then
    hx1=000000
  else
    hx1="$(git rev-parse --short "$hex1")"
  fi
  err "$path ($hx0..$hx1$mode_str)"

  cmd0=("${cmd[@]}")
  cmd1=("${cmd[@]}")
  if [ "$hex0" == . ]; then
    cmd0=(cat)
  fi
  if [ "$hex1" == . ]; then
    cmd1=(cat)
  fi
elif [ $# -eq 9 ]; then
  # Called via e.g. `git diff --no-index --ext-diff "$tmppath0" "$tmppath1"` in `git-diff-dvc.sh`
  pqt0="$1"
  pqt1="$8"
  cmd0=("${cmd[@]}")
  cmd1=("${cmd[@]}")
else
  usage
fi

if [ -z "$color" ]; then
  if [ -t 0 ]; then
    color=always
  else
    color=never
  fi
fi
set +e
diff --color=$color <("${cmd0[@]}" "$pqt0") <("${cmd1[@]}" "$pqt1")
set -e
rv=$?
echo
if [ $rv -eq 0 ] || [ $rv -eq 1 ]; then
  exit 0
else
  exit $rv
fi
