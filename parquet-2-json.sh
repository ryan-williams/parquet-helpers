#!/usr/bin/env bash
#
# Wrapper for parquet2json rearranges the arguments:
#
# $ parquet2json.sh <subcommand> [args...] <path>
#
# as opposed to the original, whose usage says:
#
# $ parquet2json [OPTIONS] <FILE> <SUBCOMMAND>
#
# but in reality requires:
#
# $ parquet2json <FILE> <SUBCOMMAND> [OPTIONS]
#
# Either way, putting the arg last, and the subcmd and its options first, makes lots of other piping and wrapping easier.
#
# Additionally, this wrapper supports reading input data from stdin (which parquet2json doesn't support).

set -e

args=("$@")
err() {
  echo "$*" >&2
}
usage() {
  err "Usage: $0 <subcommand> [opts...] [path]" >&2
  err
  err "Received (${#args[@]}): ${args[*]}" >&2
  exit 1
}
if [ $# -eq 0 ]; then
  usage
fi

subcmd="$1"; shift
opts=("$subcmd")
if [ "$subcmd" == cat ]; then
  while getopts "c:l:no:" opt; do
    case "$opt" in
      c) opts+=(-c "$OPTARG") ;;
      l) opts+=(-l "$OPTARG") ;;
      n) opts+=(-n) ;;
      o) opts+=("-o$OPTARG") ;;
      \?) usage ;;
    esac
  done
  shift $((OPTIND-1))
fi

if [ $# -eq 0 ] || { [ $# -eq 1 ] && [ "$1" == "-" ]; }; then
  path="$(mktemp)"
  cat > "$path"
  trap "rm -f '$path'" EXIT
  parquet2json "$path" "${opts[@]}"
elif [ $# -eq 1 ]; then
  parquet2json "$1" "${opts[@]}"
else
  usage
fi
