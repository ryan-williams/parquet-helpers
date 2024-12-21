#!/usr/bin/env bash

set -e
# echo "parquet-diff.sh ($#):"
# for arg in "$@"; do
#   echo "  $arg"
# done
# echo

n="$PQT_DIFF_N_ROWS"
if [ -z "$n" ]; then
  n="$(git config diff.parquet.n-rows)"
  if [ -z "$n" ]; then
    n=2
  fi
fi
cmd="pqa -n $n"

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
  echo "$path ($hx0..$hx1$mode_str)" >&2

  cmd0="$cmd"
  cmd1="$cmd"
  if [ "$hex0" == . ]; then
    cmd0="cat"
  fi
  if [ "$hex1" == . ]; then
    cmd1="cat"
  fi
elif [ $# -eq 9 ]; then
  # Called via e.g. `git diff --no-index --ext-diff "$tmppath0" "$tmppath1"` in `git-diff-dvc.sh`
  pqt0="$1"
  pqt1="$8"
  cmd0="$cmd"
  cmd1="$cmd"
else
  echo "Usage: $0 <repo relpath> <old version tmpfile> <old hexsha> <old filemode> <new version tmpfile> <new hexsha> <new filemode>" >&2
  echo "Usage: $0 <old version tmpfile> <new version tmpfile>" >&2
  exit 1
fi

set +e
diff --color=always <($cmd0 "$pqt0") <($cmd1 "$pqt1")
rv=$?
echo
if [ $rv -eq 0 ] || [ $rv -eq 1 ]; then
  exit 0
else
  exit $rv
fi
