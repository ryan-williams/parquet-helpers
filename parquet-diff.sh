#!/usr/bin/env bash

if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <repo relpath> <old version tmpfile> <old hexsha> <old filemode> <new version tmpfile> <new hexsha> <new filemode>" >&2
    exit 1
fi

path="$1"  ; shift  # repo relpath
pqt0="$1"  ; shift  # old version
hex0="$1"  ; shift  # old hexsha
mode0="$1" ; shift  # old filemode
pqt1="$1"  ; shift  # new version
hex1="$1"  ; shift  # new hexsha
mode1="$1" ; shift  # new filemode

mode_str=0
if [ "$mode0" != "$mode1" ]; then
    mode_str=", 0$mode0..0$mode1"
fi
hx0="$(git rev-parse --short "$hex0")"
hx1="$(git rev-parse --short "$hex1")"
echo "$path ($hx0..$hx1$mode_str)" >&2

n="$PQT_DIFF_N_ROWS"
if [ -z "$n" ]; then
  n="$(git config diff.parquet.n-rows)"
  if [ -z "$n" ]; then
    n=2
  fi
fi
cmd="pqa -n $n"
diff --color=always <($cmd "$pqt0") <($cmd "$pqt1")
rv=$?
echo
if [ $rv -eq 0 ] || [ $rv -eq 1 ]; then
    exit 0
else
    exit $rv
fi
