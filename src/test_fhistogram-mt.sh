#!/usr/bin/env bash

compare() {
        threads="$1"

        output1=$(./fhistogram ./100small_files/)
        output2=$(./fhistogram-mt -n "$threads" ./100small_files/)

        if [ "$output1" = "$output2" ]; then
                echo "PASS: outputs match ($search_term, $threads threads)"
        else
                echo "FAIL: outputs differ"
                diff <(printf '%s\n' "$output1") <(printf '%s\n' "$output2")
                return 1
        fi
}

compare 1
