#!/usr/bin/env bash
# check-diff.sh — mechanical checks for the dev-cycle (deterministic, no LLM).
#
#   check-diff.sh run  <name> <out-dir> <command> [prep]
#       Runs the command, keeps the raw log outside the notes dir, and writes to <out-dir>:
#       <name>.rc (exit code) and <name>.sig (error signatures, with counts).
#   check-diff.sh diff <baseline-dir> <attempt-dir>
#       Compares error by error. Ends with "RESULT: CLEAN" or "RESULT: REGRESSION".
#   check-diff.sh sig  <log-file>
#       Extracts the signatures only (for debugging).
#
# A signature is file + error code/message, without line and column numbers,
# so an old error that merely moved lines does not look new.
set -u
LC_ALL=C; export LC_ALL

sig() {
  esc="$(printf '\033')"
  tr -d '\r' <"$1" | sed "s/${esc}\[[0-9;]*[A-Za-z]//g" | awk -v cwd="$PWD/" '
    function norm(s,   i) {
      while ((i = index(s, cwd)) > 0) s = substr(s, 1, i - 1) substr(s, i + length(cwd))
      gsub(/\([0-9]+,[0-9]+\)/, "", s)          # tsc: file(12,5)
      gsub(/:[0-9]+:[0-9]+/, "", s)             # file:12:5
      gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s)
      return s
    }
    # ESLint stylish: a line with the path, then "  12:5  error  msg  rule"
    /^\/.*\.(ts|tsx|js|jsx|mjs|cjs|html|json|vue|scss|css)$/ || /^[^ \t]+\.(ts|tsx|js|jsx|mjs|cjs|html|json|vue|scss|css)$/ { fname = $0; next }
    /^[ \t]+[0-9]+:[0-9]+[ \t]+error[ \t]/ {
      l = $0; sub(/^[ \t]+[0-9]+:[0-9]+[ \t]+/, "", l); print norm(fname " " l); next }
    /^[ \t]+[0-9]+:[0-9]+[ \t]+warning[ \t]/ { next }
    /error TS[0-9]+/ || /error NG[0-9]+/ || /NG[0-9]+:/ { print norm($0); next }      # tsc / Angular
    /^FAIL[ \t]/ { print norm($0); next }                                              # Jest: suite
    /^[ \t]*● / { if ($0 !~ /Console|Cannot log after/) print norm($0); next }         # Jest: test
    /^[ \t]*(ERROR|Error|error)[: ]/ || /ERR_|ELIFECYCLE|heap out of memory|Killed/ { print norm($0); next }
  ' | sort | uniq -c | sed 's/^ *//'
}

run() {
  name="$1"; out="$2"; cmd="$3"; prep="${4:-}"
  mkdir -p "$out" || { echo "ERROR: could not create $out"; exit 2; }
  logdir="${TMPDIR:-/tmp}/dev-cycle/$(basename "$(dirname "$(dirname "$out")")")/$(basename "$out")"
  mkdir -p "$logdir"; log="$logdir/$name.log"
  limit="${DEV_CYCLE_TIMEOUT:-1800}"
  [ -n "$prep" ] && cmd="$prep && $cmd"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$limit" bash -c "$cmd" >"$log" 2>&1; rc=$?
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$limit" bash -c "$cmd" >"$log" 2>&1; rc=$?
  else
    bash -c "$cmd" >"$log" 2>&1; rc=$?
  fi
  [ "$rc" = "124" ] && echo "TIMEOUT after ${limit}s" >>"$log"
  echo "$rc" >"$out/$name.rc"
  sig "$log" >"$out/$name.sig"
  echo "$name: rc=$rc distinct_errors=$(wc -l <"$out/$name.sig" | tr -d ' ') log=$log"
}

diff_dirs() {
  base="$1"; new="$2"; regression=0
  [ -d "$new" ] || { echo "ERROR: directory $new does not exist"; exit 2; }
  for f in "$new"/*.sig; do
    [ -e "$f" ] || { echo "ERROR: no checks found in $new"; exit 2; }
    name="$(basename "$f" .sig)"
    rcn="$(cat "$new/$name.rc" 2>/dev/null || echo '?')"
    if [ ! -e "$base/$name.sig" ]; then
      echo "== $name: NO BASELINE (rc=$rcn) — not comparable"
      [ "$rcn" != "0" ] && regression=1
      continue
    fi
    rcb="$(cat "$base/$name.rc" 2>/dev/null || echo '?')"
    res="$(awk '
      { n = $1; s = $0; sub(/^[0-9]+ /, "", s) }
      FILENAME == ARGV[1] { b[s] = n; next }
      { v[s] = n; if (!(s in b)) print "NEW\t+" n "\t" s; else if (n > b[s]) print "NEW\t+" (n - b[s]) "\t" s }
      END { for (s in b) if (!(s in v)) r++; print "RESOLVED\t" r + 0 }
    ' "$base/$name.sig" "$f")"
    news="$(printf '%s\n' "$res" | grep -c '^NEW')"
    resolved="$(printf '%s\n' "$res" | awk -F'\t' '/^RESOLVED/ {print $2}')"
    echo "== $name: rc $rcb -> $rcn | new errors: $news | resolved: $resolved"
    printf '%s\n' "$res" | grep '^NEW' | cut -f2- | head -40
    [ "$news" -gt 40 ] && echo "   ... (+$((news - 40)) not shown)"
    [ "$news" -gt 0 ] && regression=1
    [ "$rcb" = "0" ] && [ "$rcn" != "0" ] && regression=1
  done
  if [ "$regression" = "1" ]; then echo "RESULT: REGRESSION"; else echo "RESULT: CLEAN"; fi
}

case "${1:-}" in
  run)  [ $# -ge 4 ] || { echo "usage: check-diff.sh run <name> <out-dir> <command> [prep]"; exit 2; }; run "$2" "$3" "$4" "${5:-}";;
  diff) [ $# -eq 3 ] || { echo "usage: check-diff.sh diff <baseline-dir> <attempt-dir>"; exit 2; }; diff_dirs "$2" "$3";;
  sig)  [ $# -eq 2 ] || { echo "usage: check-diff.sh sig <log>"; exit 2; }; sig "$2";;
  *)    echo "usage: check-diff.sh run|diff|sig ..."; exit 2;;
esac
