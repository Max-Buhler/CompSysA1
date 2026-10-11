#!/usr/bin/env bash

set -uo pipefail

ALGORITHMS=(
        "./fauxgrep"
        "./fauxgrep-mt -n 1"
        "./fauxgrep-mt -n 2"
        "./fauxgrep-mt -n 4"
        "./fauxgrep-mt -n 8"
        "./fauxgrep-mt -n 16"
        "./fauxgrep-mt -n 32"
        "./fauxgrep-mt -n 64"
        "./fauxgrep-mt -n 128"
)

PATTERN="Lavaqueresse"

DATASETS=(
        "./100small_files/"
        "./1big_file/"
        "./100big_files/"
)
printf 'Pattern: Lavaqueresse\n'

printf '%-25s %15s %15s %15s\n' \
        Algorithm '100small (s)' '1big (s)' '100big (s)'
printf '%s\n' "------------------------------------------------------------------------"

for algorithm in "${ALGORITHMS[@]}"; do
        read -r -a CMD <<<"$algorithm"

        printf "%-25s" "$algorithm"

        for dataset in "${DATASETS[@]}"; do
                start=$EPOCHREALTIME

                if "${CMD[@]}" "$PATTERN" "$dataset" >/dev/null 2>&1; then
                        status=0
                else
                        status=$?
                fi

                end=$EPOCHREALTIME

                elapsed=$(awk -v start="$start" -v end="$end" \
                        'BEGIN { printf "%.3f", end - start }')

                if ((status == 0)); then
                        printf " %14s" "$elapsed"
                else
                        printf " %11s (ERR)" "$elapsed"
                fi
        done

        printf '\n'
done
