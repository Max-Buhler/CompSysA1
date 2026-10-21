#!/usr/bin/env bash

# The histogram is redrawn repeatedly while files are processed, and the
# intermediate frames depend on thread timing.  Only the final frame
# (8 bit lines + the "bits processed" line) is deterministic, so strip
# the cursor escape codes and compare just the last 9 lines.
final_frame() {
        perl -pe 's/\e\[\d*[A-Za-z]//g' | tail -n 9
}

run_seq() {
        ./fhistogram "$1" | final_frame
}

run_mt() {
        ./fhistogram-mt -n "$2" "$1" | final_frame
}

compare() {
        dir="$1"
        threads="$2"

        output1=$(run_seq "$dir")
        output2=$(run_mt "$dir" "$threads")

        if [ "$output1" = "$output2" ]; then
                echo "PASS: outputs match ($dir, $threads threads)"
        else
                echo "FAIL: outputs differ ($dir, $threads threads)"
                diff <(printf '%s\n' "$output1") <(printf '%s\n' "$output2")
                return 1
        fi
}

compare100() {
        dir="$1"
        threads="$2"

        for i in $(seq 1 100); do
                output1=$(run_seq "$dir")
                output2=$(run_mt "$dir" "$threads")
                if [ "$output1" != "$output2" ]; then
                        echo "FAIL: outputs differ ($dir, $threads threads)"
                        diff <(printf '%s\n' "$output1") <(printf '%s\n' "$output2")
                        return 1
                fi
        done
        echo "PASS: outputs match ($dir, $threads threads) (100 times)"
}

for n in 1 2 4 16; do
        compare ./100small_files/ "$n"
        compare100 ./100small_files/ "$n"
done
compare ./1big_file/ 4
compare ./100big_files/ 16
