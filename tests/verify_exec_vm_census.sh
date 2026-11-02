#!/bin/bash
# exec VM 全量覆盖普查
#
# 对 tests/test_*.uya 逐个执行 `uya test --vm`，统计通过率与失败原因直方图。
# 这是「exec VM 与 C99 后端对齐」计划的覆盖度门禁：
#   - 目的：让"还差多少"变成可复现的数字，而不是靠人工抽查；
#   - 门禁：UYA_EXEC_CENSUS_MIN 设定本阶段最低通过数，低于阈值直接失败；
#   - 跳过：tests/exec_vm_census_skip.txt 只允许登记"C99 侧同样不适用"的用例，
#           并在行内写明原因；"VM 还没做"不属于可跳过理由。
#
# 用法:
#   bash tests/verify_exec_vm_census.sh
#   UYA_EXEC_CENSUS_MIN=540 bash tests/verify_exec_vm_census.sh
#   UYA_EXEC_CENSUS_JOBS=8 UYA_EXEC_CENSUS_REPORT=/tmp/census.tsv bash tests/verify_exec_vm_census.sh
#
# 环境变量:
#   UYA_COMPILER              编译器路径（默认 <repo>/bin/uya）
#   UYA_ROOT                  UYA_ROOT（默认 <repo>/lib/）
#   UYA_EXEC_CENSUS_MIN       最低通过用例数（默认 0，不设门禁）
#   UYA_EXEC_CENSUS_JOBS      并行度（默认 CPU 核数）
#   UYA_EXEC_CENSUS_TIMEOUT   单用例超时秒数（默认 300）
#   UYA_EXEC_CENSUS_MEM_MB    单用例地址空间上限（MB，默认 4096；0 表示不限）
#                             census 的峰值内存 ≈ JOBS × MEM_MB，跑之前先看一下
#                             机器余量（实测单用例峰值：TLS 186MB / https 456MB
#                             / kernel_sim 548MB，失控用例靠这个上限快速失败）
#                             解释器里的失控用例（如 test_crypto_bigint 会一路
#                             涨到 7GB+ 再被超时杀掉）只会在白等之前先把内存
#                             吃光；设上限让它快速失败，并记为原因 mem。
#                             不要再降到 1024：编译器自己的 CompilerArena 就要
#                             1GB 以上，1024 会让 79 个用例在「编译期」就
#                             `CompilerArena 无法分配 chunk` 假失败（已实测）。
#   UYA_EXEC_CENSUS_REPORT    明细 TSV 落盘路径（默认 /tmp/uya_exec_vm_census.tsv）
#   UYA_EXEC_CENSUS_SKIP      跳过表路径（默认 tests/exec_vm_census_skip.txt）
#   UYA_EXEC_CENSUS_GLOB      只跑匹配该 bash 通配的用例（默认全部），例如
#                             UYA_EXEC_CENSUS_GLOB='test_a*'；用于分片跑，避免一次
#                             连续占用机器几十分钟
#   UYA_EXEC_CENSUS_TIMEOUTS  单用例超时覆盖表（默认 tests/exec_vm_census_timeouts.txt）
#                             格式：`用例名<TAB>秒数`，行内 # 起注释。给"能跑通但
#                             纯 CPU 很贵"的用例（如 4096 位模幂）单独放宽。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
MIN_PASS="${UYA_EXEC_CENSUS_MIN:-0}"
TIMEOUT="${UYA_EXEC_CENSUS_TIMEOUT:-300}"
MEM_MB="${UYA_EXEC_CENSUS_MEM_MB:-4096}"
REPORT="${UYA_EXEC_CENSUS_REPORT:-/tmp/uya_exec_vm_census.tsv}"
SKIP_FILE="${UYA_EXEC_CENSUS_SKIP:-$SCRIPT_DIR/exec_vm_census_skip.txt}"
TIMEOUT_FILE="${UYA_EXEC_CENSUS_TIMEOUTS:-$SCRIPT_DIR/exec_vm_census_timeouts.txt}"
GLOB_FILTER="${UYA_EXEC_CENSUS_GLOB:-}"

if [ ! -x "$COMPILER" ]; then
    echo "✗ 编译器不存在或不可执行: $COMPILER" >&2
    exit 1
fi

ulimit -s unlimited 2>/dev/null || ulimit -s 524288 2>/dev/null || true

# run_one 由 xargs 在子 shell 里跑：用到的变量都必须导出，否则子进程里
# MEM_MB 是空的 —— ulimit 分支会被静默跳过（内存上限从来没生效过）。
export TIMEOUT_FILE
export MEM_MB
export TIMEOUT
# 这里**不做任何按名字的进程清理**。
#
# 早先写的是 `pkill -f -- "$COMPILER test --vm"`：按命令行子串匹配，会把同机
# 其它会话正在跑的 `./bin/uya test --vm ...` 一并杀掉（实测误伤过别的
# uya-agent 会话；而且它也会命中 census 自己的轮询 shell，表现为整轮普查
# 「已终止」并被记成 0/0）。
#
# 换成了两条结构性保证，不再需要模式匹配：
#   1. 每个 worker 都由 `timeout -k <grace>` 硬性封顶（TERM 不理就补 KILL），
#      所以单个用例不可能无限期占着 CPU；
#   2. 因此本脚本即使被 SIGKILL 掐掉，留下的也只是一批「各自会在超时后
#      自动退出」的进程，不需要事后按名字扫射。
# 确实要清上一轮的遗留时，显式设置 UYA_EXEC_CENSUS_REAP=1。
if [ "${UYA_EXEC_CENSUS_REAP:-0}" = "1" ]; then
    pkill -f -- "$COMPILER test --vm" 2>/dev/null || true
fi

# 临时目录可用 UYA_EXEC_CENSUS_TMPDIR 指定：/tmp 常常是 32G tmpfs，
# 别的任务写满后这里会 ENOSPC，整轮普查直接算成 0/0。
CENSUS_TMPDIR="${UYA_EXEC_CENSUS_TMPDIR:-/tmp}"
WORK_DIR="$(mktemp -d "$CENSUS_TMPDIR/uya_exec_census.XXXXXX")"
RESULTS_DIR="$WORK_DIR/results"
mkdir -p "$RESULTS_DIR"
cleanup() {
    # 只删自己的临时目录。worker 由各自 `timeout -k` 封顶，会自行退出，
    # 这里不去碰任何按名字匹配的进程（避免误伤同机其它会话）。
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

# 收集跳过表（只取非注释、非空行；匹配 basename）
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

run_one() {
    local uya_file="$1"
    local results_dir="$2"
    local compiler="$3"
    local timeout_s="$4"
    local base_name
    base_name="$(basename "$uya_file")"
    local override_s=""
    if [ -f "$TIMEOUT_FILE" ]; then
        override_s="$(awk -F'\t' -v n="$base_name" '$1 == n { print $2; exit }' "$TIMEOUT_FILE" 2>/dev/null)"
    fi
    if [[ "$override_s" =~ ^[0-9]+$ ]]; then
        timeout_s="$override_s"
    fi
    local base
    base="$(basename "$uya_file")"
    local out_file="$results_dir/${base}.txt"
    local err
    local mem_mb="${MEM_MB:-0}"
    local limit_kb=$((mem_mb * 1024))
    # `-k` 必不可少：解释器里互相等待的用例会忽略 SIGTERM，只发 TERM 的 timeout
    # 会一直等下去 —— 实测 test_std_dns_async_query_aggregate 卡了 50 分钟，
    # 整轮普查被它一个人拖死（TIMEOUT=240 完全没生效）。加 `-k` 后超时再补 SIGKILL。
    # 进程组超时：个别用例会 kill 掉自己的父进程（timeout 消失、uya 变孤儿挂一小时），
    # 所以放进独立会话，超时后对整组发 SIGKILL。
    if [ "$mem_mb" -gt 0 ]; then
        err="$(bash -c 'set -m; ulimit -v "$1" 2>/dev/null; shift; "$@" & p=$!; setsid bash -c "sleep $1; kill -9 -$p 2>/dev/null" >/dev/null 2>&1 & w=$!; wait "$p"; rc=$?; kill "$w" 2>/dev/null; exit $rc' _ \
            "$limit_kb" "$timeout_s" "$compiler" test --vm --no-strict-overflow "$uya_file" 2>&1 >/dev/null)"
    else
        err="$(bash -c 't="$1"; shift; set -m; "$@" & p=$!; setsid bash -c "sleep $t; kill -9 -$p 2>/dev/null" >/dev/null 2>&1 & w=$!; wait "$p"; rc=$?; kill "$w" 2>/dev/null; exit $rc' _ \
            "$timeout_s" "$compiler" test --vm --no-strict-overflow "$uya_file" 2>&1 >/dev/null)"
    fi
    local st=$?

    local reason=""
    reason="$(printf '%s' "$err" | grep -o 'exec unsupported 原因码: [A-Za-z0-9_]*' | head -1 | sed 's/.*: //')"
    if [ -z "$reason" ] && printf '%s' "$err" | grep -q 'exec runtime:'; then
        reason="runtime"
    fi
    if [ -z "$reason" ] && printf '%s' "$err" | grep -q 'exec backend 失败'; then
        reason="build"
    fi
    if [ -z "$reason" ] && printf '%s' "$err" | grep -qiE '内存不足|out of memory|bad_alloc|Cannot allocate memory'; then
        reason="mem"
    fi
    if [ -z "$reason" ] && [ "$st" -eq 124 ]; then
        reason="timeout"
    fi

    local detail
    detail="$(printf '%s' "$err" | grep -o 'exec: [^"]*' | head -1 | cut -c1-160)"
    if [ -z "$detail" ]; then
        detail="$(printf '%s' "$err" | grep -E '错误:|失败:' | head -1 | cut -c1-160)"
    fi

    printf '%s\t%s\t%s\t%s\n' "$base" "$st" "$reason" "$detail" > "$out_file"

    # 实时进度：整轮普查十几分钟，只在结尾打汇总会让人误以为卡死。
    if [ -n "${PROGRESS_FILE:-}" ]; then
        printf '.\n' >> "$PROGRESS_FILE" 2>/dev/null
        local done_n
        done_n="$(wc -l < "$PROGRESS_FILE" 2>/dev/null | tr -d ' ')"
        # 必须带上退出码：`reason` 只是「匹配到哪种错误模式」，为空时默认打 ok，
        # 于是断言失败的用例（退出码非 0）在进度里也显示成 ok，会误导排查。
        printf '  [%s/%s] %-52s st=%-3s %s\n' "${done_n:-?}" "${PROGRESS_TOTAL:-?}" "$base" "${st:-?}" "${reason}" >&2
    fi
}
export -f run_one

FILES=()
SKIPPED=0
while IFS= read -r f; do
    base="$(basename "$f")"
    if [ -n "$GLOB_FILTER" ] && [[ "$base" != $GLOB_FILTER ]]; then
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

JOBS="${UYA_EXEC_CENSUS_JOBS:-$( (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) )}"
case "$JOBS" in
    ''|*[!0-9]*) JOBS=4 ;;
esac
[ "$JOBS" -lt 1 ] && JOBS=1

# 不限内存（MEM_MB=0）乘以高并行度会把整机打爆：实测单用例峰值 crypto_bigint 7GB+、
# kernel_sim 548MB、https 456MB。一旦整机进 OOM，内核 killer 会挑**任意**大进程
# 杀掉 —— 包括同机的 uya-agent 会话（真实发生过）。所以 MEM_MB=0 时把并行度压到
# 保守值，除非调用方显式 UYA_EXEC_CENSUS_ALLOW_UNLIMITED=1。
if [ "$MEM_MB" = "0" ] && [ "${UYA_EXEC_CENSUS_ALLOW_UNLIMITED:-0}" != "1" ]; then
    if [ "$JOBS" -gt 4 ]; then
        echo "注意: MEM_MB=0 表示不限内存，并行度 $JOBS 会放大峰值；已压到 4。" >&2
        echo "      需要原样跑请设 UYA_EXEC_CENSUS_ALLOW_UNLIMITED=1。" >&2
        JOBS=4
    fi
fi

echo "exec VM 覆盖普查: $TOTAL 个用例（跳过 $SKIPPED），并行度 $JOBS（单用例内存上限 ${MEM_MB}MB，0=不限）"
PROGRESS_FILE="$WORK_DIR/progress.count"
: > "$PROGRESS_FILE"
PROGRESS_TOTAL="$TOTAL"
export PROGRESS_FILE PROGRESS_TOTAL
printf '%s\n' "${FILES[@]}" | xargs -P "$JOBS" -I{} bash -c \
    'run_one "$@"' _ {} "$RESULTS_DIR" "$COMPILER" "$TIMEOUT"

: > "$REPORT"
PASS=0
FAIL=0
declare -A REASON_COUNT=()
FAIL_LIST="$WORK_DIR/failures.txt"
: > "$FAIL_LIST"
for f in "$RESULTS_DIR"/*.txt; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r base st reason detail < "$f"
    printf '%s\t%s\t%s\t%s\n' "$base" "$st" "$reason" "$detail" >> "$REPORT"
    if [ "$st" -eq 0 ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        key="${reason:-unknown}"
        REASON_COUNT["$key"]=$(( ${REASON_COUNT["$key"]:-0} + 1 ))
        printf '%s\t%s\t%s\n' "$base" "$st" "$detail" >> "$FAIL_LIST"
    fi
done

echo ""
echo "================================"
echo "exec VM 覆盖普查结果"
echo "================================"
echo "总数:   $TOTAL"
echo "通过:   $PASS"
echo "失败:   $FAIL"
[ "$SKIPPED" -gt 0 ] && echo "跳过:   $SKIPPED（见 $SKIP_FILE）"
printf '通过率: %s%%\n' "$(awk -v p="$PASS" -v t="$TOTAL" 'BEGIN { printf "%.1f", (t > 0 ? p * 100 / t : 0) }')"
echo "明细:   $REPORT"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "失败原因分布:"
    for key in "${!REASON_COUNT[@]}"; do
        printf '  %-12s %s\n' "$key" "${REASON_COUNT[$key]}"
    done | sort -k2 -nr
    echo ""
    echo "失败用例（前 20）："
    head -20 "$FAIL_LIST" | sed 's/^/  /'
fi

if [ "$MIN_PASS" -gt 0 ] && [ "$PASS" -lt "$MIN_PASS" ]; then
    echo ""
    echo "✗ 覆盖度低于门禁: 通过 $PASS < 期望 $MIN_PASS"
    exit 1
fi

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "✗ exec VM 仍有未覆盖用例"
    exit 1
fi

echo ""
echo "✓ exec VM 全量用例通过"
