#!/usr/bin/env bash

set -uo pipefail

ALGORITHMS=(
        "./fhistogram"
        "./fhistogram-mt -n 1"
        "./fhistogram-mt -n 2"
        "./fhistogram-mt -n 4"
        "./fhistogram-mt -n 8"
        "./fhistogram-mt -n 16"
        "./fhistogram-mt -n 32"
        "./fhistogram-mt -n 64"
        "./fhistogram-mt -n 128"
)

DATASETS=(
        "./100small_files/"
        "./1big_file/"
        "./100big_files/"
)

printf '%-25s %15s %15s %15s\n' \
        Algorithm '100small (s)' '1big (s)' '100big (s)'
printf '%s\n' "------------------------------------------------------------------------"

for algorithm in "${ALGORITHMS[@]}"; do
        read -r -a CMD <<<"$algorithm"

        printf "%-25s" "$algorithm"

        for dataset in "${DATASETS[@]}"; do
                # Fixed repeat counts: 100 runs everywhere, except 100big_files
                # where the sequential and -n 1/2 variants run once and the
                # rest run 5 times.
                status=0
                total=0
                runs=100
                if [[ "$dataset" == "./100big_files/" ]]; then
                        case "$algorithm" in
                        "./fhistogram" | "./fhistogram-mt -n 1" | "./fhistogram-mt -n 2")
                                runs=1 ;;
                        *)
                                runs=5 ;;
                        esac
                fi
                i=0
                while ((i < runs)); do
                        start=$EPOCHREALTIME

                        if ! "${CMD[@]}" "$dataset" >/dev/null 2>&1; then
                                status=$?
                        fi

                        end=$EPOCHREALTIME

                        total=$(awk -v t="$total" -v start="$start" -v end="$end" \
                                'BEGIN { printf "%.6f", t + end - start }')

                        i=$((i + 1))
                done

                elapsed=$(awk -v t="$total" -v n="$runs" \
                        'BEGIN { printf "%.3f", t / n }')

                if ((status == 0)); then
                        printf " %14s" "$elapsed"
                else
                        printf " %11s (ERR)" "$elapsed"
                fi
        done

        printf '\n'
done
