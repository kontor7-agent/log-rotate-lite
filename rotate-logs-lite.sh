#!/usr/bin/env bash
# rotate-logs-lite.sh - compress big log files to .gz and expire old archives.
# Dry-run by default. Only touches files directly inside the given folder.
# No network. Requires Bash 4+, gzip, GNU coreutils (Linux).
#
# Usage: ./rotate-logs-lite.sh DIR [--pattern '*.log'] [--min-kb 1024]
#                              [--keep-days 30] [--apply]
# Exit codes: 0 ok | 1 warnings | 2 usage error
set -u -o pipefail

PATTERN='*.log'; MIN_KB=1024; KEEP_DAYS=30; APPLY=0; DIR=""

die() { echo "ERROR: $*" >&2; exit 2; }
usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; }
is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

while [ $# -gt 0 ]; do
  case "$1" in
    --pattern)   [ $# -ge 2 ] || die "$1 needs a value"; PATTERN="$2"; shift 2;;
    --min-kb)    [ $# -ge 2 ] || die "$1 needs a value"; MIN_KB="$2"; shift 2;;
    --keep-days) [ $# -ge 2 ] || die "$1 needs a value"; KEEP_DAYS="$2"; shift 2;;
    --apply)     APPLY=1; shift;;
    -h|--help)   usage; exit 0;;
    -*)          die "Unknown option: $1";;
    *)           [ -z "$DIR" ] || die "Only one folder allowed"; DIR="$1"; shift;;
  esac
done

[ -n "$DIR" ] || { usage >&2; exit 2; }
[ -d "$DIR" ] || die "Not a folder: $DIR"
is_uint "$MIN_KB" || die "--min-kb must be a whole number"
is_uint "$KEEP_DAYS" || die "--keep-days must be a whole number (0 = keep forever)"
case "$PATTERN" in */*) die "--pattern must be a file name pattern, not a path";; esac
command -v gzip >/dev/null 2>&1 || die "gzip not found"
stat -c %s / >/dev/null 2>&1 || die "GNU stat required (Linux)"

DIR="${DIR%/}"; [ -n "$DIR" ] || DIR="/"
STAMP="$(date +%Y%m%d-%H%M%S)"
ROT=0; DEL=0; ERR=0
say() { echo "$(date '+%H:%M:%S') [$1] $2"; }

[ $APPLY -eq 1 ] || say INFO "DRY RUN - nothing is changed. Add --apply to do it."
say INFO "Folder: $DIR  pattern: $PATTERN  min: ${MIN_KB} KB  keep-days: $KEEP_DAYS"

# 1) compress + empty (copytruncate: safe while a program keeps the log open)
while IFS= read -r -d '' f; do
  size="$(stat -c %s -- "$f" 2>/dev/null)" || { say WARN "Cannot read $f"; ERR=$((ERR+1)); continue; }
  [ "$size" -ge $((MIN_KB * 1024)) ] && [ "$size" -gt 0 ] || continue
  gz="$f.$STAMP.gz"
  [ ! -e "$gz" ] || { say WARN "Exists, skipped: $gz"; ERR=$((ERR+1)); continue; }
  if [ $APPLY -eq 0 ]; then
    say INFO "Would rotate: ${f##*/} ($size bytes)"; ROT=$((ROT+1)); continue
  fi
  if gzip -c -- "$f" > "$gz" && gzip -t -- "$gz"; then
    if : > "$f"; then say INFO "Rotated: ${f##*/} -> ${gz##*/}"; ROT=$((ROT+1))
    else say WARN "Archive written, could not empty $f"; ERR=$((ERR+1)); fi
  else
    rm -f -- "$gz"; say WARN "Compression failed, original kept: $f"; ERR=$((ERR+1))
  fi
done < <(find "$DIR" -maxdepth 1 -type f -name "$PATTERN" ! -name '*.gz' -print0)

# 2) expire old archives (only <name matching pattern>.<yyyymmdd-HHMMSS>.gz)
if [ "$KEEP_DAYS" -gt 0 ]; then
  while IFS= read -r -d '' a; do
    b="${a##*/}"
    [[ "$b" =~ ^(.+)\.[0-9]{8}-[0-9]{6}\.gz$ ]] || continue
    # shellcheck disable=SC2254
    case "${BASH_REMATCH[1]}" in $PATTERN) ;; *) continue;; esac
    if [ $APPLY -eq 0 ]; then say INFO "Would delete old archive: $b"; DEL=$((DEL+1))
    elif rm -f -- "$a"; then say INFO "Deleted old archive: $b"; DEL=$((DEL+1))
    else say WARN "Could not delete $b"; ERR=$((ERR+1)); fi
  done < <(find "$DIR" -maxdepth 1 -type f -name '*.gz' -mtime +"$KEEP_DAYS" -print0)
fi

say INFO "Rotated: $ROT   Old archives removed: $DEL   Errors: $ERR"
[ $ERR -eq 0 ] || exit 1
exit 0
