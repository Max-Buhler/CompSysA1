#!/usr/bin/env bash

# Tries to break fauxgrep(-mt) and fhistogram(-mt) with awkward inputs.
# Builds a fixture tree with setup_torture.sh, then
#   * checks the -mt programs agree with the sequential ones (stdout and
#     exit code) for every fixture on its own and for combinations,
#   * checks nothing crashes (signal) or hangs on bad arguments.
#
# Env: THREADS="1 2 ..." thread counts, REPS=n race repetitions,
#      TMO=secs per-run timeout, KEEP=1 keeps the fixture tree.

cd "$(dirname "$0")" || exit 1

THREADS=${THREADS:-"1 2 3 8 64"}
REPS=${REPS:-20}
TMO=${TMO:-20}

for b in fauxgrep fauxgrep-mt fhistogram fhistogram-mt; do
        [ -x "./$b" ] || { echo "missing ./$b (run make)"; exit 1; }
done

W=$(mktemp -d)
R="$W/fx"  # ROOT.eol is created next to it
bash ./setup_torture.sh "$R" || { echo "setup failed"; exit 1; }
cleanup() {
        chmod -R u+rwx "$W" "$R.eol" 2>/dev/null
        [ -n "${KEEP:-}" ] && echo "fixtures kept in $W" || rm -rf "$W" "$R.eol"
}
trap cleanup EXIT

pass=0
fail=0

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $*"; }

# run_to FILE ARGS...: stdout to FILE, stderr dropped, returns exit code.
# Exit code >= 124 means killed by a signal or timed out.
run_to() {
        local out="$1"; shift
        perl -e 'alarm shift; exec @ARGV or die' "$TMO" "$@" >"$out" 2>/dev/null
}

crashed() { [ "$1" -ge 124 ]; }

# Only the last frame of the histogram is deterministic.  An all-zero
# frame is treated as no output at all (the sequential program prints
# nothing when there are no files, the threaded one may print a frame).
norm_hist() {
        perl -pe 's/\e\[\d*[A-Za-z]//g' "$1" | tail -n 9 \
                | perl -0pe 's/\A.*^0 bits processed\.\n\z//ms'
}

norm_grep() { LC_ALL=C sort "$1"; }

# check_grep LABEL THREADS NEEDLE PATHS...
check_grep() {
        local label="$1" n="$2" needle="$3"; shift 3
        run_to "$W/s" ./fauxgrep "$needle" "$@"; local rs=$?
        run_to "$W/m" ./fauxgrep-mt -n "$n" "$needle" "$@"; local rm=$?
        if crashed "$rs"; then bad "fauxgrep rc=$rs [$label] needle='${needle:0:20}'"; return; fi
        if crashed "$rm"; then bad "fauxgrep-mt rc=$rm [$label] -n $n needle='${needle:0:20}'"; return; fi
        norm_grep "$W/s" >"$W/a"; norm_grep "$W/m" >"$W/b"
        if [ "$rs" != "$rm" ]; then
                bad "fauxgrep exit codes differ seq=$rs mt=$rm [$label] -n $n"
        elif ! cmp -s "$W/a" "$W/b"; then
                bad "fauxgrep output differs [$label] -n $n needle='${needle:0:20}' ($(wc -l <"$W/a") vs $(wc -l <"$W/b") lines)"
                diff "$W/a" "$W/b" | head -n 6 | cut -c1-120
        else
                ok
        fi
}

# check_hist LABEL THREADS PATHS...
check_hist() {
        local label="$1" n="$2"; shift 2
        run_to "$W/s" ./fhistogram "$@"; local rs=$?
        run_to "$W/m" ./fhistogram-mt -n "$n" "$@"; local rm=$?
        if crashed "$rs"; then bad "fhistogram rc=$rs [$label]"; return; fi
        if crashed "$rm"; then bad "fhistogram-mt rc=$rm [$label] -n $n"; return; fi
        norm_hist "$W/s" >"$W/a"; norm_hist "$W/m" >"$W/b"
        if [ "$rs" != "$rm" ]; then
                bad "fhistogram exit codes differ seq=$rs mt=$rm [$label] -n $n"
        elif ! cmp -s "$W/a" "$W/b"; then
                bad "fhistogram final frame differs [$label] -n $n"
                diff "$W/a" "$W/b" | head -n 6
        else
                ok
        fi
}

# survives CMD...: must neither crash nor hang (any normal exit code ok).
survives() {
        local label="$1"; shift
        run_to "$W/o" "$@"; local rc=$?
        if crashed "$rc"; then bad "rc=$rc on [$label]: $*"; else ok; fi
}

echo "== 1. argument abuse (must not crash or hang) =="
for prog in fauxgrep-mt fhistogram-mt; do
        needle=(); [ "$prog" = fauxgrep-mt ] && needle=(x)
        survives "no args"            "./$prog"
        survives "-n only"            "./$prog" -n
        survives "-n 4 only"          "./$prog" -n 4
        survives "-n 4 + needle only" "./$prog" -n 4 "${needle[@]}"
        survives "-n 0"               "./$prog" -n 0 "${needle[@]}" "$R/one_byte"
        survives "-n -1"              "./$prog" -n -1 "${needle[@]}" "$R/one_byte"
        survives "-n abc"             "./$prog" -n abc "${needle[@]}" "$R/one_byte"
        survives "-n 4abc"            "./$prog" -n 4abc "${needle[@]}" "$R/one_byte"
        survives "-n huge"            "./$prog" -n 99999999999 "${needle[@]}" "$R/one_byte"
        survives "-n 3000 threads"    "./$prog" -n 3000 "${needle[@]}" "$R/one_byte"
        survives "empty string path"  "./$prog" -n 2 "${needle[@]}" ""
        survives "nonexistent path"   "./$prog" -n 2 "${needle[@]}" "$R/nope"
        survives "fifo as path"       "./$prog" -n 2 "${needle[@]}" "$R/links/fifo"
        survives "/dev/null as path"  "./$prog" -n 2 "${needle[@]}" /dev/null
done
survives "fauxgrep no args"      ./fauxgrep
survives "fauxgrep needle only"  ./fauxgrep x
survives "fhistogram no args"    ./fhistogram
survives "fauxgrep-mt needle only" ./fauxgrep-mt x
survives "fauxgrep-mt without -n" ./fauxgrep-mt x "$R/one_byte"

echo "== 2. every fixture on its own, every thread count =="
needles=(needle e "" "z")
for entry in $(ls -A "$R"); do
        for n in $THREADS; do
                for nd in "${needles[@]}"; do
                        check_grep "$entry" "$n" "$nd" "$R/$entry"
                done
                check_hist "$entry" "$n" "$R/$entry"
        done
done

echo "== 3. needle abuse on the whole tree =="
long_needle=$(perl -e 'print "needle" x 2000')
for nd in needle NEEDLE "needle " " needle" "needle
needle" '[' '.*' '\' '\n' '%s' '%n' '-' '--' '-n' '$(id)' "'" '"' "é" "$(printf '\xff')" "$long_needle" "ne" "e" ; do
        for n in 1 4 64; do
                check_grep "whole tree" "$n" "$nd" "$R"
        done
done

echo "== 4. path forms and combinations =="
for n in $THREADS; do
        for set in \
                "$R/many $R/many" \
                "$R/many $R/many/f1 $R/many/f1" \
                "$R/many/f1 $R/many" \
                "$R/empty_file $R/empty_file" \
                "$R/empty_dir $R/empty_file $R/one_byte" \
                "$R/nope $R/one_byte $R/nope2" \
                "$R/many/ $R/many//" \
                "$R/many/../many" \
                "$R/links $R/dup $R/names" \
                "$R/size_100000 $R/size_99999 $R/size_100001 $R/big_text $R/long_line_1_5MB"; do
                # shellcheck disable=SC2086
                check_grep "paths: $set" "$n" needle $set
                # shellcheck disable=SC2086
                check_hist "paths: $set" "$n" $set
        done
        # many separate arguments (more files than queue slots)
        check_grep "700 args" "$n" needle "$R"/many/f*
        check_hist "700 args" "$n" "$R"/many/f*
        (cd "$R" && check_grep "relative path" "$n" needle many names)
        (cd "$R/many" && check_hist "dot path" "$n" .)
done

echo "== 5. whole tree, all thread counts =="
for n in $THREADS; do
        check_grep "whole tree" "$n" needle "$R"
        check_hist "whole tree" "$n" "$R"
done

echo "== 6. race hunting (x$REPS) =="
for i in $(seq 1 "$REPS"); do
        check_grep "race many" 16 needle "$R/many"
        check_grep "race many 3t" 3 needle "$R/many" "$R/wide"
        check_hist "race many" 16 "$R/many"
        check_hist "race wide" 8 "$R/wide" "$R/nested_empty"
        check_hist "race tiny" 64 "$R/one_byte"
        check_hist "race empty" 4 "$R/empty_dir"
        check_hist "race merge boundary" 8 "$R/size_100000" "$R/size_100001" "$R/size_99999"
done

echo "== 7. last line without trailing newline (several files) =="
for n in $THREADS; do
        check_grep "no EOL" "$n" needle "$R.eol"
        check_hist "no EOL" "$n" "$R.eol"
done

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
