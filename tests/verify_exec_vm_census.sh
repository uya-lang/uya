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
#   UYA_EXEC_CENSUS_MEM_MB    单用例地址空间上限（MB，默认 2048；0 表示不限）
#                             解释器里的失控用例（如 test_crypto_bigint 会一路
#                             涨到 7GB+ 再被超时杀掉）只会在白等之前先把内存
#                             吃光；设上限让它快速失败，并记为原因 mem。
#   UYA_EXEC_CENSUS_REPORT    明细 TSV 落盘路径（默认 /tmp/uya_exec_vm_census.tsv）
#   UYA_EXEC_CENSUS_SKIP      跳过表路径（默认 tests/exec_vm_census_skip.txt）

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
MIN_PASS="${UYA_EXEC_CENSUS_MIN:-0}"
TIMEOUT="${UYA_EXEC_CENSUS_TIMEOUT:-300}"
MEM_MB="${UYA_EXEC_CENSUS_MEM_MB:-2048}"
REPORT="${UYA_EXEC_CENSUS_REPORT:-/tmp/uya_exec_vm_census.tsv}"
SKIP_FILE="${UYA_EXEC_CENSUS_SKIP:-$SCRIPT_DIR/exec_vm_census_skip.txt}"

if [ ! -x "$COMPILER" ]; then
    echo "✗ 编译器不存在或不可执行: $COMPILER" >&2
    exit 1
fi

ulimit -s unlimited 2>/dev/null || ulimit -s 524288 2>/dev/null || true

WORK_DIR="$(mktemp -d /tmp/uya_exec_census.XXXXXX)"
RESULTS_DIR="$WORK_DIR/results"
mkdir -p "$RESULTS_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

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
    local base
    base="$(basename "$uya_file")"
    local out_file="$results_dir/${base}.txt"
    local err
    local limit_kb=$((MEM_MB * 1024))
    if [ "$MEM_MB" -gt 0 ]; then
        err="$(bash -c 'ulimit -v "$1" 2>/dev/null; shift; exec timeout "$@"' _ \
            "$limit_kb" "$timeout_s" "$compiler" test --vm --no-strict-overflow "$uya_file" 2>&1 >/dev/null)"
    else
        err="$(timeout "$timeout_s" "$compiler" test --vm --no-strict-overflow "$uya_file" 2>&1 >/dev/null)"
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
}
export -f run_one

FILES=()
SKIPPED=0
while IFS= read -r f; do
    base="$(basename "$f")"
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

echo "exec VM 覆盖普查: $TOTAL 个用例（跳过 $SKIPPED），并行度 $JOBS"
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
