#!/usr/bin/env bash

# Output order of fauxgrep-mt is nondeterministic, so both outputs are
# sorted before comparing: same set of lines, order ignored.
run_seq() {
        ./fauxgrep "$1" ./100small_files/ | LC_ALL=C sort
}

run_mt() {
        ./fauxgrep-mt -n "$2" "$1" ./100small_files/ | LC_ALL=C sort
}

compare() {
        search_term="$1"
        threads="$2"

        output1=$(run_seq "$search_term")
        output2=$(run_mt "$search_term" "$threads")

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

        for i in $(seq 1 100); do
                output1=$(run_seq "$search_term")
                output2=$(run_mt "$search_term" "$threads")
                if [ "$output1" != "$output2" ]; then
                        echo "FAIL: outputs differ"
                        diff <(printf '%s\n' "$output1") <(printf '%s\n' "$output2")
                        return 1
                fi
        done
        echo "PASS: outputs match ($search_term, $threads threads) (100 times)"
}

compare France 1
compare Lavaqueresse 1
compare100 France 1
for n in 2 4 16; do
        compare France "$n"
        compare100 France "$n"
done
compare dsajdbhjwhjwej 16
