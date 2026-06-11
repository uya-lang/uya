#!/usr/bin/env bash

# Phase 10：固定 compile_stats_record_and_release_typed_program(...)
# table_realloc_count aggregate writeback 的 CoreBody/PortableMIR 切片合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
NO_SILENT_TEST="$REPO_ROOT/tests/verify_native_cmd_build_no_silent_c99.sh"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$NO_SILENT_TEST" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'stats\.table_realloc_count = table_agg\.realloc_count' \
    "todo 缺少 compile_stats table_realloc_count 写回任务"
require_pattern "$SUBSET_DOC" '^## `compile_stats_record_and_release_typed_program\(\.\.\.\)` Table Realloc Count Writeback Slice Contract' \
    "subset doc 缺少 compile_stats table_realloc_count 写回合同"
require_pattern "$SUBSET_DOC" 'stats\.table_realloc_count = table_agg\.realloc_count;' \
    "subset doc 缺少 table_realloc_count 写回 surface"
require_pattern "$SUBSET_DOC" 'prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN reason=partial_core_body' \
    "subset doc 缺少 table_realloc_count 写回前 frontier"
require_pattern "$SUBSET_DOC" 'prefix_stmts=15 next_stmt=15 next_kind=AST_CALL_EXPR reason=partial_core_body' \
    "subset doc 缺少 table_realloc_count 写回后的下一 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'stats\.table_realloc_count = table_agg\.realloc_count;' \
    "compile_stats 源码缺少 table_realloc_count 写回"
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN reason=partial_core_body' \
    "no-silent-C99 测试缺少 compile_stats table_realloc_count 当前 frontier"
require_pattern "$STAGE1_TEST" 'verify_native_compile_stats_table_realloc_count_contract\.sh' \
    "stage1 未纳入 compile_stats table_realloc_count 合同"

echo "verify_native_compile_stats_table_realloc_count_contract: ok"
