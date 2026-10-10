#!/usr/bin/env bash

compare() {
        search_term="$1"
        threads="$2"

        output1=$(./fauxgrep "$search_term" ./fauxgrep-testfiles)
        output2=$(./fauxgrep-mt -n "$threads" "$search_term" ./fauxgrep-testfiles)

        if [ "$output1" = "$output2" ]; then
                echo "PASS: outputs match ($search_term, $threads threads)"
        else
                echo "FAIL: outputs differ"
                diff <(printf '%s\n' "$output1") <(printf '%s\n' "$output2")
                return 1
        fi
}

compare France 1
compare France 16
compare dsajdbhjwhjwej 16
