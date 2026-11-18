#!/usr/bin/env bash
#
# Benchmarks fauxgrep(-mt) and fhistogram(-mt) and prints LaTeX tables
# (time, files/s, MB/s per program) to stdout. Progress goes to stderr, so:
#
#   ./bench.sh > bench.tex
#
# Every (program, algorithm, dataset) cell is run at least once. Cells that
# are fast are repeated until roughly CELL_BUDGET seconds are spent (at most
# MAX_RUNS runs), so the total is about 54 * CELL_BUDGET plus the cells whose
# single run already exceeds the budget.
#
# Needs bash >= 5 for EPOCHREALTIME and associative arrays.

set -uo pipefail
export LC_ALL=C

if ((BASH_VERSINFO[0] < 5)); then
        echo "bench.sh needs bash >= 5 (macOS: brew install bash)" >&2
        exit 1
fi

CELL_BUDGET=${CELL_BUDGET:-5}
MAX_RUNS=${MAX_RUNS:-100}
PATTERN="Lavaqueresse"

THREADS=(1 2 4 8 16 32 64 128)

DATASETS=(
        "./100small_files/"
        "./1big_file/"
        "./100big_files/"
)
DATASET_NAMES=("100 small files" "1 big file" "100 big files")

PROGRAMS=(fauxgrep fhistogram)

now() { printf '%s' "${EPOCHREALTIME/,/.}"; }

# Dataset sizes, computed once.
declare -A FILES BYTES
for dataset in "${DATASETS[@]}"; do
        FILES[$dataset]=$(find "$dataset" -type f | wc -l | tr -d ' ')
        BYTES[$dataset]=$(find "$dataset" -type f -exec wc -c {} + |
                awk '$2 != "total" { s += $1 } END { print s }')
done

# RES_<metric>[program|algorithm|dataset] = value
declare -A TIME FSPEED BSPEED RUNS ERR

run_cmd() { # program, algorithm-args..., dataset
        local prog=$1 dataset=${*: -1}
        shift
        local args=("${@:1:$#-1}")
        if [[ $prog == fauxgrep ]]; then
                "${args[@]}" "$PATTERN" "$dataset" >/dev/null 2>&1
        else
                "${args[@]}" "$dataset" >/dev/null 2>&1
        fi
}

bench_cell() { # program, label, dataset, command words...
        local prog=$1 label=$2 dataset=$3
        shift 3
        local key="$prog|$label|$dataset"
        local total=0 runs=0 first t0 t1 dt max

        t0=$(now)
        run_cmd "$prog" "$@" "$dataset" || ERR[$key]=1
        t1=$(now)
        first=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.6f", b - a }')
        total=$first
        runs=1

        max=$(awk -v f="$first" -v b="$CELL_BUDGET" -v m="$MAX_RUNS" \
                'BEGIN { n = int(b / (f > 0 ? f : 1e-6)); if (n > m) n = m; if (n < 1) n = 1; print n }')
        while ((runs < max)); do
                t0=$(now)
                run_cmd "$prog" "$@" "$dataset" || ERR[$key]=1
                t1=$(now)
                total=$(awk -v t="$total" -v a="$t0" -v b="$t1" \
                        'BEGIN { printf "%.6f", t + b - a }')
                runs=$((runs + 1))
        done

        local avg
        avg=$(awk -v t="$total" -v n="$runs" 'BEGIN { printf "%.6f", t / n }')
        TIME[$key]=$(awk -v a="$avg" 'BEGIN { printf "%.3f", a }')
        FSPEED[$key]=$(awk -v a="$avg" -v n="${FILES[$dataset]}" \
                'BEGIN { printf "%.1f", n / a }')
        BSPEED[$key]=$(awk -v a="$avg" -v n="${BYTES[$dataset]}" \
                'BEGIN { printf "%.1f", n / a / 1000000 }')
        RUNS[$key]=$runs
        printf '%-10s %-12s %-16s %4d runs  %9s s\n' \
                "$prog" "$label" "$dataset" "$runs" "${TIME[$key]}" >&2
}

start=$(now)
for prog in "${PROGRAMS[@]}"; do
        for dataset in "${DATASETS[@]}"; do
                bench_cell "$prog" seq "$dataset" "./$prog"
                for n in "${THREADS[@]}"; do
                        bench_cell "$prog" "$n" "$dataset" "./$prog-mt" -n "$n"
                done
        done
done
end=$(now)
awk -v a="$start" -v b="$end" \
        'BEGIN { printf "Total: %.1f s\n", b - a }' >&2

emit() { # program, metric, caption suffix, label suffix
        local prog=$1 metric=$2 caption=$3 lab=$4
        local -n arr=$metric
        printf '\\begin{table}[h]\n\\centering\n'
        printf '\\begin{tabular}{l r r r}\n\\toprule\n'
        printf 'Variant'
        local name
        for name in "${DATASET_NAMES[@]}"; do printf ' & %s' "$name"; done
        printf ' \\\\\n\\midrule\n'
        local label dataset key cell
        for label in seq "${THREADS[@]}"; do
                if [[ $label == seq ]]; then
                        printf '\\texttt{%s}' "$prog"
                else
                        printf '\\texttt{%s-mt -n %s}' "$prog" "$label"
                fi
                for dataset in "${DATASETS[@]}"; do
                        key="$prog|$label|$dataset"
                        cell=${arr[$key]}
                        [[ -n ${ERR[$key]:-} ]] && cell="$cell\\textsuperscript{err}"
                        printf ' & %s' "$cell"
                done
                printf ' \\\\\n'
        done
        printf '\\bottomrule\n\\end{tabular}\n'
        printf '\\caption{\\texttt{%s}: %s}\n' "$prog" "$caption"
        printf '\\label{tab:%s-%s}\n\\end{table}\n\n' "$prog" "$lab"
}

printf '%% Requires \\usepackage{booktabs}\n'
printf '%% Pattern: %s, max %s runs/cell, budget %s s/cell\n\n' \
        "$PATTERN" "$MAX_RUNS" "$CELL_BUDGET"
for prog in "${PROGRAMS[@]}"; do
        emit "$prog" TIME "mean running time in seconds." time
        emit "$prog" FSPEED "throughput in files per second." files
        emit "$prog" BSPEED "throughput in MB/s." bytes
done
