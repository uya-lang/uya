#!/usr/bin/env bash

set -euo pipefail

RUNS=1
MODE="c99"
KEEP_LOGS=0
BENCH_TMPDIR="${UYA_BENCH_TMPDIR:-/tmp}"
WORK_DIR=""

usage() {
    cat <<'EOF'
用法: bash scripts/bench_compiler_1s.sh [选项]

选项:
  --runs N       运行 N 次冷构建（默认: 1）
  --keep-logs    保留每轮 make clean / make uya 日志目录
  -h, --help     显示帮助

示例:
  bash scripts/bench_compiler_1s.sh
  bash scripts/bench_compiler_1s.sh --runs 3
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs)
            RUNS="$2"
            shift 2
            ;;
        --keep-logs)
            KEEP_LOGS=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "错误: 未知参数: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || [[ "$RUNS" -lt 1 ]]; then
    echo "错误: --runs 必须是大于等于 1 的整数" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAKE_CMD="${MAKE:-make}"

cleanup() {
    if [[ "$KEEP_LOGS" -eq 0 && -n "${WORK_DIR:-}" && "$WORK_DIR" == "$BENCH_TMPDIR"/uya-bench-compiler-1s.* ]]; then
        rm -rf "$WORK_DIR"
    fi
}

trap cleanup EXIT

now_ns() {
    local value
    value="$(date +%s%N)"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "错误: 当前 date 不支持纳秒时间戳，无法可靠测量冷构建耗时" >&2
        exit 1
    fi
    printf '%s\n' "$value"
}

elapsed_ms() {
    local start_ns="$1"
    local end_ns="$2"
    printf '%s\n' "$(((end_ns - start_ns + 999999) / 1000000))"
}

run_make_target() {
    local target="$1"
    local log_file="$2"
    "$MAKE_CMD" -C "$REPO_ROOT" "$target" >"$log_file" 2>&1
}

print_failure_log() {
    local label="$1"
    local log_file="$2"
    echo "错误: $label 失败；完整日志如下:" >&2
    cat "$log_file" >&2
}

median_value() {
    printf '%s\n' "$@" | sort -n | awk '
        { values[NR] = $1 }
        END {
            if (NR == 0) {
                exit 1;
            }
            mid = int((NR + 1) / 2);
            if (NR % 2 == 1) {
                print values[mid];
            } else {
                print int((values[mid] + values[mid + 1]) / 2);
            }
        }
    '
}

mkdir -p "$BENCH_TMPDIR"
WORK_DIR="$(mktemp -d "$BENCH_TMPDIR/uya-bench-compiler-1s.XXXXXX")"

if [[ "$KEEP_LOGS" -ne 0 ]]; then
    echo "提示: benchmark 日志将保留在 $WORK_DIR" >&2
fi

clean_values=()
build_values=()
total_values=()

printf 'run\tmode\tclean_ms\tbuild_ms\ttotal_ms\tstatus\n'

run=1
while [[ "$run" -le "$RUNS" ]]; do
    run_dir="$WORK_DIR/run-$run"
    mkdir -p "$run_dir"
    clean_log="$run_dir/make-clean.log"
    build_log="$run_dir/make-uya.log"

    echo "run $run: make clean && make uya ..." >&2
    total_start="$(now_ns)"

    clean_start="$(now_ns)"
    if ! run_make_target clean "$clean_log"; then
        clean_end="$(now_ns)"
        clean_ms="$(elapsed_ms "$clean_start" "$clean_end")"
        total_end="$(now_ns)"
        total_ms="$(elapsed_ms "$total_start" "$total_end")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$MODE" "$clean_ms" 0 "$total_ms" "clean_failed"
        print_failure_log "make clean" "$clean_log"
        exit 1
    fi
    clean_end="$(now_ns)"
    clean_ms="$(elapsed_ms "$clean_start" "$clean_end")"

    build_start="$(now_ns)"
    if ! run_make_target uya "$build_log"; then
        build_end="$(now_ns)"
        build_ms="$(elapsed_ms "$build_start" "$build_end")"
        total_end="$(now_ns)"
        total_ms="$(elapsed_ms "$total_start" "$total_end")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$MODE" "$clean_ms" "$build_ms" "$total_ms" "build_failed"
        print_failure_log "make uya" "$build_log"
        exit 1
    fi
    build_end="$(now_ns)"
    build_ms="$(elapsed_ms "$build_start" "$build_end")"

    total_end="$(now_ns)"
    total_ms="$(elapsed_ms "$total_start" "$total_end")"

    clean_values+=("$clean_ms")
    build_values+=("$build_ms")
    total_values+=("$total_ms")

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$MODE" "$clean_ms" "$build_ms" "$total_ms" "ok"
    run=$((run + 1))
done

if [[ "$RUNS" -gt 1 ]]; then
    printf 'median\t%s\t%s\t%s\t%s\t%s\n' \
        "$MODE" \
        "$(median_value "${clean_values[@]}")" \
        "$(median_value "${build_values[@]}")" \
        "$(median_value "${total_values[@]}")" \
        "ok"
fi
