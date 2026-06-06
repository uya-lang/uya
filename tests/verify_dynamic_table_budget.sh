#!/usr/bin/env bash

# Phase 5A L392 动态表预算检查：
# 防止编译器通过“启动时一次性预分配超大容量”来压低重分配次数、伪装动态表达标。
#
# 用真实 bin/uya 编译 src/main.uya，解析编译统计里的动态表聚合字段：
#   table_count          实际项数之和
#   table_capacity       容量项数之和
#   table_bytes          实际占用字节之和
#   table_capacity_bytes 容量字节之和
#   table_realloc_count  重分配次数之和
#
# 断言：
#   1. table_count > 0                          —— 动态表确实被使用。
#   2. table_realloc_count >= 1                 —— 容量是按需增长得来，而非一次性巨型预分配。
#   3. table_capacity <= table_count * RATIO    —— 没有用超大预分配把 capacity/count 比例撑大。
#   4. table_capacity_bytes >= table_bytes      —— 字节口径自洽。
#
# RATIO 默认 8，可用 UYA_TABLE_BUDGET_RATIO 覆盖（与 bench 的容量告警阈值一致）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

RATIO="${UYA_TABLE_BUDGET_RATIO:-8}"
if ! [[ "$RATIO" =~ ^[0-9]+$ ]] || [[ "$RATIO" -lt 1 ]]; then
    echo "错误: UYA_TABLE_BUDGET_RATIO 必须是大于等于 1 的整数" >&2
    exit 1
fi

if [[ ! -x "$REPO_ROOT/bin/uya" ]]; then
    echo "错误: 缺少可执行 bin/uya，请先 make uya" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d /tmp/uya-table-budget.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG="$TMP_DIR/compile.log"
# 用真实编译器跑直接 C99 全流程，触发完整 SemanticDb / TypedProgram 动态表。
if ! UYA_ROOT="$REPO_ROOT/lib/" "$REPO_ROOT/bin/uya" \
        "$REPO_ROOT/src/main.uya" -o "$TMP_DIR/out.c" \
        --c99 --nostdlib --safety-proof > "$LOG" 2>&1; then
    echo "错误: 基准编译失败，无法采集动态表统计" >&2
    tail -n 40 "$LOG" >&2
    exit 1
fi

extract() {
    local label="$1"
    local value
    value="$(awk -F': ' -v l="$label" '$1 == l { v = $2 } END { if (v == "") print "NA"; else print v }' "$LOG" | tr -d ' ')"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "错误: 编译统计缺少字段 $label（值='$value'）" >&2
        exit 1
    fi
    printf '%s\n' "$value"
}

TABLE_COUNT="$(extract table_count)"
TABLE_CAPACITY="$(extract table_capacity)"
TABLE_BYTES="$(extract table_bytes)"
TABLE_CAPACITY_BYTES="$(extract table_capacity_bytes)"
TABLE_REALLOC_COUNT="$(extract table_realloc_count)"

echo "动态表预算: count=$TABLE_COUNT capacity=$TABLE_CAPACITY bytes=$TABLE_BYTES capacity_bytes=$TABLE_CAPACITY_BYTES realloc=$TABLE_REALLOC_COUNT ratio_threshold=$RATIO"

fail=0

if [[ "$TABLE_COUNT" -le 0 ]]; then
    echo "✗ table_count 必须 > 0（动态表未被使用？）" >&2
    fail=1
fi

if [[ "$TABLE_REALLOC_COUNT" -lt 1 ]]; then
    echo "✗ table_realloc_count 必须 >= 1：容量应按需增长，不能靠启动时一次性巨型预分配" >&2
    fail=1
fi

if [[ "$TABLE_CAPACITY" -gt $((TABLE_COUNT * RATIO)) ]]; then
    echo "✗ table_capacity($TABLE_CAPACITY) > table_count($TABLE_COUNT) * $RATIO：疑似超大预分配" >&2
    fail=1
fi

if [[ "$TABLE_CAPACITY_BYTES" -lt "$TABLE_BYTES" ]]; then
    echo "✗ table_capacity_bytes($TABLE_CAPACITY_BYTES) < table_bytes($TABLE_BYTES)：字节口径不自洽" >&2
    fail=1
fi

if [[ "$fail" -ne 0 ]]; then
    echo "✗ 动态表预算检查失败" >&2
    exit 1
fi

echo "✓ 动态表预算检查通过（容量随项数按需增长，无超大预分配）"
