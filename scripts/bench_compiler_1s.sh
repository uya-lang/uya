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
PROC_ROOT="${UYA_BENCH_PROC_ROOT:-/proc}"
RSS_SAMPLE_INTERVAL="${UYA_BENCH_RSS_SAMPLE_INTERVAL:-0.10}"
RSS_AVAILABLE=0
if [[ -d "$PROC_ROOT" && -r "$PROC_ROOT/self/status" ]]; then
    RSS_AVAILABLE=1
fi

flag_enabled() {
    local value
    value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
    case "$value" in
        1|true|yes|on|enabled)
            return 0
            ;;
    esac
    return 1
}

reject_hard_kpi_cache_inputs() {
    local bad=()
    local var_name value cc_driver_value
    local cache_vars=(
        UYA_DAEMON
        UYA_USE_DAEMON
        UYA_BUILD_DAEMON
        UYA_OBJECT_CACHE
        UYA_USE_OBJECT_CACHE
        UYA_ENABLE_OBJECT_CACHE
        UYA_IR_CACHE
        UYA_USE_IR_CACHE
        UYA_ENABLE_IR_CACHE
        UYA_BUILD_CACHE
        UYA_COMPILER_CACHE
        UYA_SKIP_UYA
    )

    for var_name in "${cache_vars[@]}"; do
        value="${!var_name:-}"
        if flag_enabled "$value"; then
            bad+=("$var_name=$value")
        fi
    done

    cc_driver_value="${CC_DRIVER:-${CC:-}}"
    if [[ "$cc_driver_value" == *ccache* || "$cc_driver_value" == *sccache* ]]; then
        bad+=("CC_DRIVER=$cc_driver_value")
    fi

    if [[ "${#bad[@]}" -gt 0 ]]; then
        echo "错误: bench-compiler-1s 硬 KPI 禁止 daemon/object cache/IR cache: ${bad[*]}" >&2
        exit 1
    fi
}

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

git_value() {
    local fallback="$1"
    shift
    git -C "$REPO_ROOT" "$@" 2>/dev/null || printf '%s\n' "$fallback"
}

detect_os() {
    if [[ -n "${HOST_OS:-}" ]]; then
        printf '%s\n' "$HOST_OS"
        return
    fi
    uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed -e 's/darwin/macos/' -e 's/msys.*/windows/' -e 's/mingw.*/windows/' -e 's/cygwin.*/windows/' || printf 'unknown\n'
}

detect_arch() {
    if [[ -n "${HOST_ARCH:-}" ]]; then
        printf '%s\n' "$HOST_ARCH"
        return
    fi
    uname -m 2>/dev/null | sed -e 's/amd64/x86_64/' -e 's/aarch64/arm64/' || printf 'unknown\n'
}

detect_cpu_count() {
    nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || printf 'unknown\n'
}

print_metadata() {
    local commit branch os_name arch_name cpu_count cflags cc_driver backend native_enabled c99_enabled
    commit="$(git_value unknown rev-parse --short=12 HEAD)"
    branch="$(git_value unknown rev-parse --abbrev-ref HEAD)"
    os_name="$(detect_os)"
    arch_name="$(detect_arch)"
    cpu_count="$(detect_cpu_count)"
    cflags="${CFLAGS:-}"
    cc_driver="${CC_DRIVER:-${CC:-cc}}"
    backend="${UYA_BUILD_BACKEND:-$MODE}"
    native_enabled=0
    c99_enabled=1
    if [[ "$backend" == "native" ]]; then
        native_enabled=1
        c99_enabled=0
    fi

    printf 'metadata\tcommit\t%s\n' "$commit" >&2
    printf 'metadata\tbranch\t%s\n' "$branch" >&2
    printf 'metadata\tos\t%s\n' "$os_name" >&2
    printf 'metadata\tarch\t%s\n' "$arch_name" >&2
    printf 'metadata\tcpu_count\t%s\n' "$cpu_count" >&2
    printf 'metadata\tcflags\t%s\n' "$cflags" >&2
    printf 'metadata\tcc_driver\t%s\n' "$cc_driver" >&2
    printf 'metadata\tbackend\t%s\n' "$backend" >&2
    printf 'metadata\tnative_enabled\t%s\n' "$native_enabled" >&2
    printf 'metadata\tc99_enabled\t%s\n' "$c99_enabled" >&2
}

clean_cold_build_artifacts() {
    rm -rf "$REPO_ROOT/bin" "$REPO_ROOT/src/build" "$REPO_ROOT/src/.uyacache"
}

process_is_active() {
    local pid="$1"
    local state
    if [[ "$RSS_AVAILABLE" -ne 1 || ! -r "$PROC_ROOT/$pid/status" ]]; then
        return 1
    fi
    state="$(awk '/^State:/ { print $2; exit }' "$PROC_ROOT/$pid/status" 2>/dev/null || true)"
    [[ -n "$state" && "$state" != "Z" && "$state" != "X" ]]
}

rss_kb_for_pid() {
    local pid="$1"
    local value
    if [[ -r "$PROC_ROOT/$pid/smaps_rollup" ]]; then
        value="$(awk '/^Rss:/ { print $2; found = 1; exit } END { if (!found) print 0 }' "$PROC_ROOT/$pid/smaps_rollup" 2>/dev/null || printf '0\n')"
    elif [[ -r "$PROC_ROOT/$pid/status" ]]; then
        value="$(awk '/^VmRSS:/ { print $2; found = 1; exit } END { if (!found) print 0 }' "$PROC_ROOT/$pid/status" 2>/dev/null || printf '0\n')"
    else
        value=0
    fi
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        value=0
    fi
    printf '%s\n' "$value"
}

collect_process_tree_pids() {
    local root_pid="$1"
    local seen=" $root_pid "
    local result=("$root_pid")
    local changed stat_file pid stat_content after_comm state ppid

    changed=1
    while [[ "$changed" -eq 1 ]]; do
        changed=0
        for stat_file in "$PROC_ROOT"/[0-9]*/stat; do
            [[ -r "$stat_file" ]] || continue
            pid="${stat_file#"$PROC_ROOT"/}"
            pid="${pid%/stat}"
            [[ "$seen" == *" $pid "* ]] && continue
            stat_content="$(<"$stat_file")" || continue
            after_comm="${stat_content##*) }"
            read -r state ppid _ <<< "$after_comm"
            [[ -n "$ppid" ]] || continue
            if [[ "$seen" == *" $ppid "* ]]; then
                seen="$seen$pid "
                result+=("$pid")
                changed=1
            fi
        done
    done

    printf '%s\n' "${result[@]}"
}

sample_process_tree_rss_kb() {
    local root_pid="$1"
    local total=0
    local pid rss

    if [[ "$RSS_AVAILABLE" -ne 1 ]]; then
        printf '0\n'
        return
    fi

    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        rss="$(rss_kb_for_pid "$pid")"
        total=$((total + rss))
    done < <(collect_process_tree_pids "$root_pid")

    printf '%s\n' "$total"
}

run_make_target() {
    local target="$1"
    local log_file="$2"
    local rss_out_var="$3"
    local pid status peak_rss sample_rss

    if [[ "$RSS_AVAILABLE" -ne 1 ]]; then
        if "$MAKE_CMD" -C "$REPO_ROOT" "$target" >"$log_file" 2>&1; then
            status=0
        else
            status=$?
        fi
        printf -v "$rss_out_var" '%s' "NA"
        return "$status"
    fi

    "$MAKE_CMD" -C "$REPO_ROOT" "$target" >"$log_file" 2>&1 &
    pid="$!"
    peak_rss=0

    if [[ "$RSS_AVAILABLE" -eq 1 ]]; then
        while process_is_active "$pid"; do
            sample_rss="$(sample_process_tree_rss_kb "$pid")"
            if [[ "$sample_rss" =~ ^[0-9]+$ && "$sample_rss" -gt "$peak_rss" ]]; then
                peak_rss="$sample_rss"
            fi
            sleep "$RSS_SAMPLE_INTERVAL" 2>/dev/null || sleep 1
        done
    fi

    if wait "$pid"; then
        status=0
    else
        status=$?
    fi

    printf -v "$rss_out_var" '%s' "$peak_rss"
    return "$status"
}

combine_peak_rss() {
    local first="$1"
    local second="$2"
    if [[ "$first" == "NA" || "$second" == "NA" ]]; then
        printf 'NA\n'
    elif [[ "$second" -gt "$first" ]]; then
        printf '%s\n' "$second"
    else
        printf '%s\n' "$first"
    fi
}

print_rss_unavailable_warning() {
    if [[ "$RSS_AVAILABLE" -ne 1 ]]; then
        echo "RSS 未测量: 缺少可用的 $PROC_ROOT/<pid>/status 或 smaps_rollup；该运行不能计入内存达标。" >&2
    fi
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

reject_hard_kpi_cache_inputs
mkdir -p "$BENCH_TMPDIR"
WORK_DIR="$(mktemp -d "$BENCH_TMPDIR/uya-bench-compiler-1s.XXXXXX")"

if [[ "$KEEP_LOGS" -ne 0 ]]; then
    echo "提示: benchmark 日志将保留在 $WORK_DIR" >&2
fi

clean_values=()
build_values=()
total_values=()
rss_values=()

print_metadata
print_rss_unavailable_warning
printf 'run\tmode\tclean_ms\tbuild_ms\ttotal_ms\tpeak_rss_kb\tstatus\n'

run=1
while [[ "$run" -le "$RUNS" ]]; do
    run_dir="$WORK_DIR/run-$run"
    mkdir -p "$run_dir"
    clean_log="$run_dir/make-clean.log"
    build_log="$run_dir/make-uya.log"

    echo "run $run: make clean && make uya ..." >&2
    total_start="$(now_ns)"

    clean_start="$(now_ns)"
    clean_cold_build_artifacts
    clean_rss=0
    if ! run_make_target clean "$clean_log" clean_rss; then
        clean_end="$(now_ns)"
        clean_ms="$(elapsed_ms "$clean_start" "$clean_end")"
        total_end="$(now_ns)"
        total_ms="$(elapsed_ms "$total_start" "$total_end")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$MODE" "$clean_ms" 0 "$total_ms" "$clean_rss" "clean_failed"
        print_failure_log "make clean" "$clean_log"
        exit 1
    fi
    clean_end="$(now_ns)"
    clean_ms="$(elapsed_ms "$clean_start" "$clean_end")"

    build_start="$(now_ns)"
    build_rss=0
    if ! run_make_target uya "$build_log" build_rss; then
        build_end="$(now_ns)"
        build_ms="$(elapsed_ms "$build_start" "$build_end")"
        total_end="$(now_ns)"
        total_ms="$(elapsed_ms "$total_start" "$total_end")"
        peak_rss="$(combine_peak_rss "$clean_rss" "$build_rss")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$MODE" "$clean_ms" "$build_ms" "$total_ms" "$peak_rss" "build_failed"
        print_failure_log "make uya" "$build_log"
        exit 1
    fi
    build_end="$(now_ns)"
    build_ms="$(elapsed_ms "$build_start" "$build_end")"

    total_end="$(now_ns)"
    total_ms="$(elapsed_ms "$total_start" "$total_end")"
    peak_rss="$(combine_peak_rss "$clean_rss" "$build_rss")"

    clean_values+=("$clean_ms")
    build_values+=("$build_ms")
    total_values+=("$total_ms")
    rss_values+=("$peak_rss")

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$MODE" "$clean_ms" "$build_ms" "$total_ms" "$peak_rss" "ok"
    run=$((run + 1))
done

if [[ "$RUNS" -gt 1 ]]; then
    median_rss="NA"
    if [[ "$RSS_AVAILABLE" -eq 1 ]]; then
        median_rss="$(median_value "${rss_values[@]}")"
    fi
    printf 'median\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$MODE" \
        "$(median_value "${clean_values[@]}")" \
        "$(median_value "${build_values[@]}")" \
        "$(median_value "${total_values[@]}")" \
        "$median_rss" \
        "ok"
fi
