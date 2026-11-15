#!/bin/bash
# exec VM 与 C99 后端逐用例差分
#
# 判据（与 docs/exec_vm_c99_parity.md 一致）：
#   C99 后端能编译、能运行的程序，exec VM 必须同样能跑，且执行结果一致。
#
# 本脚本做两件事：
#   1. 测试摘要差分（默认开启）：对每个 tests/test_*.uya 分别跑 `uya test` 与
#      `uya test --vm`，比较退出码与测试摘要 `总计/通过/失败`。
#   2. 程序输出差分（PARITY_STDOUT=1 开启）：对含 `export fn main` 的用例跑
#      `uya run` 与 `uya run --vm`，比较退出码与 stdout（十六进制地址做归一化）。
#
# 用法:
#   bash tests/verify_exec_vm_parity.sh
#   PARITY_STDOUT=1 bash tests/verify_exec_vm_parity.sh
#   UYA_PARITY_JOBS=8 UYA_PARITY_REPORT=/tmp/parity.tsv bash tests/verify_exec_vm_parity.sh
#
# 并行度默认取 CPU 核数，但会被内存预算自动压低（见 UYA_PARITY_MEM_MB /
# UYA_PARITY_MEM_BUDGET_PCT）：每个用例要各跑一遍 C99 和 exec VM，单用例峰值
# 可达数 GB，核数直接当并行度足以把整机打进 OOM。
#
# 环境变量:
#   UYA_COMPILER         编译器路径（默认 <repo>/bin/uya）
#   UYA_ROOT             UYA_ROOT（默认 <repo>/lib/）
#   UYA_PARITY_JOBS      并行度（默认 CPU 核数）
#   UYA_PARITY_TIMEOUT   单用例超时秒数（默认 300）
#   UYA_PARITY_REPORT    明细 TSV 落盘路径（默认 /tmp/uya_exec_vm_parity.tsv）
#   UYA_PARITY_STDOUT    1=同时做 run/run --vm 的 stdout 差分（默认 0）
#   UYA_PARITY_SKIP      跳过表路径（默认 tests/exec_vm_parity_skip.txt）

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
TIMEOUT="${UYA_PARITY_TIMEOUT:-300}"
REPORT="${UYA_PARITY_REPORT:-/tmp/uya_exec_vm_parity.tsv}"
PARITY_STDOUT="${UYA_PARITY_STDOUT:-0}"
SKIP_FILE="${UYA_PARITY_SKIP:-$SCRIPT_DIR/exec_vm_parity_skip.txt}"
# 单用例超时覆盖表（只放宽「语义对齐但解释器慢」的纯算法用例）
TIMEOUT_FILE="${UYA_PARITY_TIMEOUTS:-$SCRIPT_DIR/exec_vm_parity_timeouts.txt}"
export TIMEOUT_FILE

if [ ! -x "$COMPILER" ]; then
    echo "✗ 编译器不存在或不可执行: $COMPILER" >&2
    exit 1
fi

ulimit -s unlimited 2>/dev/null || ulimit -s 524288 2>/dev/null || true

WORK_DIR="$(mktemp -d /tmp/uya_exec_parity.XXXXXX)"
RESULTS_DIR="$WORK_DIR/results"
mkdir -p "$RESULTS_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

declare -A SKIP_SET=()
if [ -f "$SKIP_FILE" ]; then
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        if [ -n "$line" ]; then
            SKIP_SET["$line"]=1
        fi
    done < "$SKIP_FILE"
fi

# 测试摘要解析：失败用例没有摘要，归一化成 "-"
extract_summary() {
    printf '%s' "$1" | grep -o '总计: [0-9]* / 通过: [0-9]* / 失败: [0-9]*' | tail -1
}

# 地址归一化：指针值在两次运行间必然不同，只比较"是否打印了地址"
normalize_stdout() {
    sed -E 's/0x[0-9a-fA-F]+/0xADDR/g' "$1"
}

# 按进程组超时执行：解释器里互相等待的用例会忽略 SIGTERM，个别用例的子进程
# 甚至会 kill 掉自己的父进程（`timeout` 因此消失、uya 变孤儿挂一小时）。
# 用作业控制让命令自成一组，超时后对**整组**发 SIGKILL。
# 注意：不能用 `setsid`——它在调用方是进程组长时会 fork，捕获到的 PID 和真正
# 运行的进程组对不上，看门狗等于打空（实测 async_dns 依旧挂 38 分钟）。
run_with_timeout() {
    local t="$1"
    shift
    # 单用例地址空间上限：本脚本原本完全没有限制，失控用例（解释器里
    # test_crypto_bigint 会一路涨到 7GB+）在 17 路并行下足以打爆整机。
    # 与 census 保持同一口径：设上限让它快速失败，并记为原因 mem。
    if [ "${MEM_LIMIT_MB:-0}" -gt 0 ] 2>/dev/null; then
        local limit_kb=$(( MEM_LIMIT_MB * 1024 ))
        bash -c 'limit_kb="$1"; t="$2"; shift 2; ulimit -v "$limit_kb" 2>/dev/null; set -m; "$@" & p=$!; setsid bash -c "sleep $t; kill -9 -$p 2>/dev/null" >/dev/null 2>&1 & w=$!; wait "$p"; rc=$?; kill "$w" 2>/dev/null; exit $rc' _ \
            "$limit_kb" "$t" "$@"
        return $?
    fi
    set -m
    "$@" &
    local run_pid=$!
    # 看门狗放进独立会话：个别用例会 kill 掉自己的父 shell，普通子 shell 会被一起
    # 带走，看门狗死了孤儿就没人收（实测 async_dns 仍挂 12 分钟以上）。
    setsid bash -c "sleep $t; kill -9 -$run_pid 2>/dev/null" >/dev/null 2>&1 &
    local watch_pid=$!
    wait "$run_pid"
    local rc=$?
    kill "$watch_pid" 2>/dev/null
    wait "$watch_pid" 2>/dev/null
    set +m
    return $rc
}
export -f run_with_timeout

run_one() {
    local uya_file="$1"
    local results_dir="$2"
    local compiler="$3"
    local timeout_s="$4"
    local parity_stdout="$5"
    local override_s=""
    if [ -n "${TIMEOUT_FILE:-}" ] && [ -f "$TIMEOUT_FILE" ]; then
        override_s="$(awk -F'\t' -v n="$(basename "$uya_file")" '$1 == n { print $2; exit }' "$TIMEOUT_FILE" 2>/dev/null)"
    fi
    if [[ "$override_s" =~ ^[0-9]+$ ]]; then
        timeout_s="$override_s"
    fi
    local base
    base="$(basename "$uya_file")"
    local out_file="$results_dir/${base}.txt"

    # 与 census 共用同一张单用例内存覆盖表：`test_http_uyagin` 这类用例
    # 实测需要 6144MB 地址空间，用默认上限会把「内存不够」误报成「行为不一致」。
    if [ -f "${MEM_FILE:-}" ]; then
        local override_mem
        override_mem="$(awk -F'\t' -v n="$base" '$1 == n { print $2; exit }' "$MEM_FILE" 2>/dev/null)"
        if [[ "$override_mem" =~ ^[0-9]+$ ]] && [ "$override_mem" -gt 0 ]; then
            MEM_LIMIT_MB="$override_mem"
        fi
    fi

    # `-k 10`：解释器里互相等待的用例会忽略 SIGTERM，只发 TERM 的 timeout 会一直
    # 等下去（实测 test_async_runtime_shared_dns 挂住整轮），补 SIGKILL 才能收工。
    local c99_out c99_st vm_out vm_st
    # 需要伴随 C 源才能链接的 FFI 用例：按 tests/Makefile 的同一张对应表补上，
    # 否则 `uya test` 直连会 undefined reference（那不是 exec VM 的缺口，
    # 而是 C99 侧构建输入不全——差分口径要跟 Makefile 一致）。
    local extra_c=""
    case "$base" in
        test_abi_calling_convention.uya) extra_c="$SCRIPT_DIR/test_abi_helpers.c" ;;
        test_extern_union.uya|test_ffi_cast.uya) extra_c="$SCRIPT_DIR/external_functions.c" ;;
    esac
    if [ -n "$extra_c" ] && [ -f "$extra_c" ]; then
        local cfile="$WORK_DIR/${base}.c"
        local cbin="$WORK_DIR/${base}.bin"
        if run_with_timeout "$timeout_s" "$compiler" build --c99 --nostdlib --no-strict-overflow "$uya_file" -o "$cfile" >/dev/null 2>&1 &&
           CC=gcc "$SCRIPT_DIR/link_cimports_posix.sh" "$cfile" "$cbin" "$extra_c" >/dev/null 2>&1; then
            c99_out="$(run_with_timeout "$timeout_s" "$cbin" 2>/dev/null)"
            c99_st=$?
        else
            c99_st=1
            c99_out=""
        fi
    else
        c99_out="$(run_with_timeout "$timeout_s" "$compiler" test --no-strict-overflow "$uya_file" 2>/dev/null)"
        c99_st=$?
    fi
    vm_out="$(run_with_timeout "$timeout_s" "$compiler" test --vm --no-strict-overflow "$uya_file" 2>/dev/null)"
    vm_st=$?

    local c99_sum vm_sum
    c99_sum="$(extract_summary "$c99_out")"
    vm_sum="$(extract_summary "$vm_out")"
    [ -z "$c99_sum" ] && c99_sum="-"
    [ -z "$vm_sum" ] && vm_sum="-"

    local verdict="OK"
    local detail=""
    if [ "$c99_st" -ne "$vm_st" ]; then
        verdict="STATUS_MISMATCH"
        detail="test 退出码 C99=$c99_st VM=$vm_st"
    elif [ "$c99_sum" != "$vm_sum" ]; then
        verdict="SUMMARY_MISMATCH"
        detail="测试摘要 C99=[$c99_sum] VM=[$vm_sum]"
    fi

    # 程序输出差分：仅对含 main 的用例，且两边 test 都通过时才有意义
    if [ "$parity_stdout" = "1" ] && [ "$verdict" = "OK" ] && grep -q 'export fn main' "$uya_file"; then
        local c99_run_out vm_run_out c99_run_st vm_run_st
        c99_run_out="$WORK_DIR/${base}.c99run.out"
        vm_run_out="$WORK_DIR/${base}.vmrun.out"
        run_with_timeout "$timeout_s" "$compiler" run --no-strict-overflow "$uya_file" > "$c99_run_out" 2>/dev/null
        c99_run_st=$?
        run_with_timeout "$timeout_s" "$compiler" run --vm --no-strict-overflow "$uya_file" > "$vm_run_out" 2>/dev/null
        vm_run_st=$?
        if [ "$c99_run_st" -ne "$vm_run_st" ]; then
            verdict="RUN_STATUS_MISMATCH"
            detail="run 退出码 C99=$c99_run_st VM=$vm_run_st"
        elif ! diff -q <(normalize_stdout "$c99_run_out") <(normalize_stdout "$vm_run_out") >/dev/null 2>&1; then
            verdict="STDOUT_MISMATCH"
            detail="run stdout 不一致（已做地址归一化）"
        fi
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$base" "$c99_st" "$c99_sum" "$vm_st" "$vm_sum" "$verdict" "$detail" > "$out_file"

    # 实时进度：整轮差分要跑几十分钟，只在结尾打汇总会让人误以为卡死。
    # 每完成一例就往共用计数文件追加一行并回报进度（小写入，PIPE_BUF 内原子）。
    if [ -n "${PROGRESS_FILE:-}" ]; then
        printf '.\n' >> "$PROGRESS_FILE" 2>/dev/null
        local done_n
        done_n="$(wc -l < "$PROGRESS_FILE" 2>/dev/null | tr -d ' ')"
        printf '  [%s/%s] %-52s %s\n' "${done_n:-?}" "${PROGRESS_TOTAL:-?}" "$base" "$verdict" >&2
    fi
}
export -f run_one extract_summary normalize_stdout
export WORK_DIR

FILES=()
SKIPPED=0
while IFS= read -r f; do
    base="$(basename "$f")"
    # 调试/单点复测时只跑匹配的用例：`UYA_PARITY_GLOB='test_signal*' make exec-parity`。
    # 空值表示跑全量（默认）。
    if [ -n "${UYA_PARITY_GLOB:-}" ] && [[ "$base" != $UYA_PARITY_GLOB ]]; then
        continue
    fi
    if [ -n "${SKIP_SET[$base]:-}" ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    FILES+=("$f")
done < <(ls "$SCRIPT_DIR"/test_*.uya 2>/dev/null | sort)

TOTAL=${#FILES[@]}
if [ "$TOTAL" -eq 0 ]; then
    echo "✗ 未找到 tests/test_*.uya 用例" >&2
    exit 1
fi

MEM_FILE="${UYA_PARITY_MEMS:-$SCRIPT_DIR/exec_vm_census_mems.txt}"
export MEM_FILE

MEM_LIMIT_MB="${UYA_PARITY_MEM_LIMIT_MB:-4096}"
case "$MEM_LIMIT_MB" in
    ''|*[!0-9]*) MEM_LIMIT_MB=4096 ;;
esac
# 0 = 不限；否则不要低于 1024：编译器自己的 CompilerArena 就要几百 MB。
if [ "$MEM_LIMIT_MB" -ne 0 ] && [ "$MEM_LIMIT_MB" -lt 1024 ]; then
    MEM_LIMIT_MB=1024
fi
export MEM_LIMIT_MB

JOBS="${UYA_PARITY_JOBS:-$( (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) )}"
case "$JOBS" in
    ''|*[!0-9]*) JOBS=4 ;;
esac
[ "$JOBS" -lt 1 ] && JOBS=1

# 并行度直接取 nproc 会把峰值放大到「核数 × 单用例用量」。44 路并行足以把整机
# 打进 OOM，内核 killer 会挑**任意**大进程杀掉 —— 包括调用方自己的 agent 会话
# （真实发生过多次）。
#
# 预算基准必须是 **MemAvailable** 而不是 MemTotal：开发机上常驻进程（浏览器、
# fcitx5、macOS 虚拟机等）实测能占掉 45GB/62GB，按 MemTotal 的百分比算出来的
# 并行度照样会超。单用例用量按**实测峰值**估算：本脚本对同一个用例先跑 C99
# 再跑 exec VM，两者串行，峰值与单跑一次相当。
#
# 可用环境变量覆盖：
#   UYA_PARITY_CASE_MB        单用例峰值估算（默认 800，实测最重 794MB）
#   UYA_PARITY_MEM_BUDGET_PCT 可用内存的使用比例（默认 50，留一半给系统）
case_mb="${UYA_PARITY_CASE_MB:-800}"
case "$case_mb" in
    ''|*[!0-9]*) case_mb=800 ;;
esac
[ "$case_mb" -lt 64 ] && case_mb=64
avail_mb="$(awk '/^MemAvailable:/ { printf "%d", $2 / 1024; exit }' /proc/meminfo 2>/dev/null)"
if [ -z "$avail_mb" ]; then
    avail_mb="$(awk '/^MemTotal:/ { printf "%d", $2 / 1024; exit }' /proc/meminfo 2>/dev/null)"
fi
if [ -z "$avail_mb" ]; then
    avail_mb="$(sysctl -n hw.memsize 2>/dev/null | awk '{ printf "%d", $1 / 1048576 }')"
fi
pct="${UYA_PARITY_MEM_BUDGET_PCT:-50}"
case "$pct" in
    ''|*[!0-9]*) pct=50 ;;
esac
[ "$pct" -lt 5 ] && pct=5
[ "$pct" -gt 90 ] && pct=90
if [ -n "$avail_mb" ] && [ "$avail_mb" -gt 0 ] 2>/dev/null; then
    budget_mb=$(( avail_mb * pct / 100 ))
    safe_jobs=$(( budget_mb / case_mb ))
    [ "$safe_jobs" -lt 1 ] && safe_jobs=1
    if [ "$JOBS" -gt "$safe_jobs" ]; then
        echo "注意: 并行度 $JOBS 会超出内存预算（可用 ${avail_mb}MB，预算 ${pct}% = ${budget_mb}MB，单用例按 ${case_mb}MB 估）；" >&2
        echo "      已压到 $safe_jobs。需要原样跑请设 UYA_PARITY_JOBS=<n>。" >&2
        JOBS="$safe_jobs"
    fi
fi

echo "exec VM / C99 差分: $TOTAL 个用例（跳过 $SKIPPED），并行度 $JOBS，stdout 差分=$PARITY_STDOUT"
PROGRESS_FILE="$WORK_DIR/progress.count"
: > "$PROGRESS_FILE"
PROGRESS_TOTAL="$TOTAL"
export PROGRESS_FILE PROGRESS_TOTAL
printf '%s\n' "${FILES[@]}" | xargs -P "$JOBS" -I{} bash -c \
    'run_one "$@"' _ {} "$RESULTS_DIR" "$COMPILER" "$TIMEOUT" "$PARITY_STDOUT"

: > "$REPORT"
OK=0
MISMATCH=0
declare -A VERDICT_COUNT=()
MISMATCH_LIST="$WORK_DIR/mismatches.txt"
: > "$MISMATCH_LIST"
for f in "$RESULTS_DIR"/*.txt; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r base c99_st c99_sum vm_st vm_sum verdict detail < "$f"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$base" "$c99_st" "$c99_sum" "$vm_st" "$vm_sum" "$verdict" "$detail" >> "$REPORT"
    if [ "$verdict" = "OK" ]; then
        OK=$((OK + 1))
    else
        MISMATCH=$((MISMATCH + 1))
        VERDICT_COUNT["$verdict"]=$(( ${VERDICT_COUNT["$verdict"]:-0} + 1 ))
        printf '%s\t%s\t%s\n' "$base" "$verdict" "$detail" >> "$MISMATCH_LIST"
    fi
done

echo ""
echo "================================"
echo "exec VM / C99 差分结果"
echo "================================"
echo "总数:     $TOTAL"
echo "一致:     $OK"
echo "不一致:   $MISMATCH"
[ "$SKIPPED" -gt 0 ] && echo "跳过:     $SKIPPED（见 $SKIP_FILE）"
echo "明细:     $REPORT"

if [ "$MISMATCH" -gt 0 ]; then
    echo ""
    echo "不一致分类:"
    for key in "${!VERDICT_COUNT[@]}"; do
        printf '  %-20s %s\n' "$key" "${VERDICT_COUNT[$key]}"
    done | sort -k2 -nr
    echo ""
    echo "不一致用例（前 20）："
    head -20 "$MISMATCH_LIST" | sed 's/^/  /'
    echo ""
    echo "✗ exec VM 与 C99 后端存在行为差异"
    exit 1
fi

echo ""
echo "✓ 全部用例的 C99 / exec VM 行为一致"
