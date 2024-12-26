#!/usr/bin/env bash

set -e

err() {
  echo "$*" >&2
}

# err "$# args:"
# for arg in "$@"; do
#   err "  $arg"
# done

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

color=()
verbose=
parse() {
  while getopts "cCv" opt; do
    case "$opt" in
      c) color=(--color=always) ;;
      C) color=(--color=never) ;;
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

if [ $# -eq 7 ] || [ $# -eq 9 ]; then
  path0="$1"  ; shift  # repo relpath
  pqt0="$1"  ; shift  # old version
  hex0="$1"  ; shift  # old hexsha
  mode0="$1" ; shift  # old filemode
  pqt1="$1"  ; shift  # new version
  hex1="$1"  ; shift  # new hexsha
  mode1="$1" ; shift  # new filemode
  if [ $# -eq 2 ]; then
    path1="$1" ; shift  # new repo relpath
    index="$1" ; shift  # index range or info
    if [ "$path1" == "$pqt1" ]; then
      # Callers can construct tempfiles at "`mktemp`/{0,1}/<relpath>", e.g. `git-diff-dvc.sh` (from https://github.com/ryan-williams/dvc-helpers)
      path1="${path1##*/1/}"
    fi
  else
    path1=
    index=
  fi
  if [ "$path0" == "$pqt0" ]; then
    # Callers can construct tempfiles at "`mktemp`/{0,1}/<relpath>", e.g. `git-diff-dvc.sh` (from https://github.com/ryan-williams/dvc-helpers)
    path0="${path0##*/0/}"
  fi
  # Example 9-arg invocations:
  #
  # `git diff --cached` with a changed DVC dir:
  # ```
  # /var/folders/dc/gqj_cd8d0d9c1nppd5_yl7bc0000gn/T/tmp.MDhcfE6Y1W/0/data/test.parquet
  # /var/folders/dc/gqj_cd8d0d9c1nppd5_yl7bc0000gn/T/tmp.MDhcfE6Y1W/0/data/test.parquet
  # 0000000000000000000000000000000000000000
  # 100644
  # /var/folders/dc/gqj_cd8d0d9c1nppd5_yl7bc0000gn/T/tmp.MDhcfE6Y1W/1/data/test.parquet
  # 0000000000000000000000000000000000000000
  # 100644
  # /var/folders/dc/gqj_cd8d0d9c1nppd5_yl7bc0000gn/T/tmp.MDhcfE6Y1W/1/data/test.parquet
  # index 0109fa9..8d25654 100644
  # ```
  #
  # `git diff test^..test` when `test` commit performed `git mv test{,2}.parquet`:
  # ```
  # test.parquet
  # /var/folders/dc/gqj_cd8d0d9c1nppd5_yl7bc0000gn/T//git-blob-JdmzEA/test.parquet
  # 14a2491912de12a8039bdf0fa3e846593b5bcf0b
  # 100644
  # /var/folders/dc/gqj_cd8d0d9c1nppd5_yl7bc0000gn/T//git-blob-DqNBDU/test2.parquet
  # 14a2491912de12a8039bdf0fa3e846593b5bcf0b
  # 100644
  # test2.parquet
  # similarity index 100%
  # ```

  if [ "$mode0" == . ]; then mode0=; fi
  if [ "$mode1" == . ]; then mode1=; fi

  mode_str=
  if [ "$mode0" != "$mode1" ]; then
    mode_str="$mode0..$mode1"
  fi
  null_mode=000000
  if [ "$hex0" == . ]; then
    hx0="$null_mode"
  else
    hx0="$(git rev-parse --short "$hex0")"
  fi
  if [ "$hex1" == . ]; then
    hx1="$null_mode"
  else
    hx1="$(git rev-parse --short "$hex1")"
  fi
  hex_str="$hx0..$hx1"
  if [[ $hx0 =~ ^0+$ ]] && [[ $hx1 =~ ^0+$ ]]; then
    hex_str=
  fi
  hex_mode_str=
  if [ -n "$hex_str" ] || [ -n "$mode_str" ]; then
    hex_mode_str=" ("
    if [ -n "$hex_str" ] && [ -n "$mode_str" ]; then
      hex_mode_str+="$hex_str, $mode_str"
    else
      hex_mode_str+="$hex_str$mode_str"
    fi
    hex_mode_str+=")"
  fi
  path_str="$path0"
  if [ -n "$path1" ] && [ "$path0" != "$path1" ]; then
    path_str="$path0..$path1"
  fi
  err "$path_str$hex_mode_str"

  cmd0=("${cmd[@]}")
  cmd1=("${cmd[@]}")
  if [ "$hex0" == . ]; then
    cmd0=(cat)
  fi
  if [ "$hex1" == . ]; then
    cmd1=(cat)
  fi
else
  usage
fi

set +e
diff "${color[@]}" <("${cmd0[@]}" "$pqt0") <("${cmd1[@]}" "$pqt1")
set -e
rv=$?
echo
if [ $rv -eq 0 ] || [ $rv -eq 1 ]; then
  exit 0
else
  exit $rv
fi
