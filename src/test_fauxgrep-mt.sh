#!/usr/bin/env bash

compare() {
        search_term="$1"
        threads="$2"

        output1=$(./fauxgrep "$search_term" ./100small_files/)
        output2=$(./fauxgrep-mt -n "$threads" "$search_term" ./100small_files/)

        if [ "$output1" = "$output2" ]; then
                echo "PASS: outputs match ($search_term, $threads threads)"
        else
                echo "FAIL: outputs differ"
                diff <(printf '%s\n' "$output1") <(printf '%s\n' "$output2")
                return 1
        fi
}

compare100() {
        search_term="$1"
        threads="$2"

        output1=$(./fauxgrep "$search_term" ./100small_files/)
        output2=$(./fauxgrep-mt -n "$threads" "$search_term" ./100small_files/)

        for i in $(seq 1 10); do
                output1=$(./fauxgrep "$search_term" ./100small_files/)
                output2=$(./fauxgrep-mt -n "$threads" "$search_term" ./100small_files/)
                if [ "$output1" != "$output2" ]; then
                        echo "FAIL: outputs differ"
                        diff <(printf '%s\n' "$output1") <(printf '%s\n' "$output2")
                        return 1
                fi
        done
        echo "PASS: outputs match ($search_term, $threads threads) (100 times)"
}

compare France 1
compare100 France 1
compare dsajdbhjwhjwej 16
