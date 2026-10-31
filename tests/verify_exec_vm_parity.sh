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

run_one() {
    local uya_file="$1"
    local results_dir="$2"
    local compiler="$3"
    local timeout_s="$4"
    local parity_stdout="$5"
    local base
    base="$(basename "$uya_file")"
    local out_file="$results_dir/${base}.txt"

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
        if timeout -k 10 "$timeout_s" "$compiler" build --c99 --nostdlib --no-strict-overflow "$uya_file" -o "$cfile" >/dev/null 2>&1 &&
           CC=gcc "$SCRIPT_DIR/link_cimports_posix.sh" "$cfile" "$cbin" "$extra_c" >/dev/null 2>&1; then
            c99_out="$(timeout -k 10 "$timeout_s" "$cbin" 2>/dev/null)"
            c99_st=$?
        else
            c99_st=1
            c99_out=""
        fi
    else
        c99_out="$(timeout -k 10 "$timeout_s" "$compiler" test --no-strict-overflow "$uya_file" 2>/dev/null)"
        c99_st=$?
    fi
    vm_out="$(timeout -k 10 "$timeout_s" "$compiler" test --vm --no-strict-overflow "$uya_file" 2>/dev/null)"
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
        timeout -k 10 "$timeout_s" "$compiler" run --no-strict-overflow "$uya_file" > "$c99_run_out" 2>/dev/null
        c99_run_st=$?
        timeout -k 10 "$timeout_s" "$compiler" run --vm --no-strict-overflow "$uya_file" > "$vm_run_out" 2>/dev/null
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
}
export -f run_one extract_summary normalize_stdout
export WORK_DIR

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

JOBS="${UYA_PARITY_JOBS:-$( (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) )}"
case "$JOBS" in
    ''|*[!0-9]*) JOBS=4 ;;
esac
[ "$JOBS" -lt 1 ] && JOBS=1

echo "exec VM / C99 差分: $TOTAL 个用例（跳过 $SKIPPED），并行度 $JOBS，stdout 差分=$PARITY_STDOUT"
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
