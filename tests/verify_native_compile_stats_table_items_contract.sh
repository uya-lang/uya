#!/usr/bin/env bash

# Native build-seed 边界：固定 compile_stats_record_and_release_typed_program(...)
# table_items aggregate writeback 的 CoreBody/PortableMIR 切片合同。

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

require_pattern "$TODO_DOC" 'stats\.table_items = table_agg\.items' \
    "todo 缺少 compile_stats table_items 写回任务"
require_pattern "$SUBSET_DOC" '^## `compile_stats_record_and_release_typed_program\(\.\.\.\)` Table Items Writeback Slice Contract' \
    "subset doc 缺少 compile_stats table_items 写回合同"
require_pattern "$SUBSET_DOC" 'stats\.table_items = table_agg\.items;' \
    "subset doc 缺少 table_items 写回 surface"
require_pattern "$SUBSET_DOC" 'prefix_stmts=11 next_stmt=11 next_kind=AST_ASSIGN reason=partial_core_body' \
    "subset doc 缺少 table_items 写回后的下一 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'stats\.table_items = table_agg\.items;' \
    "compile_stats 源码缺少 table_items 写回"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_COMPILE_STATS_TABLE_ITEMS_SLICE_PREFIX_STMT_COUNT: i32 = 11' \
    "build driver 缺少 compile_stats table_items prefix 常量"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_compile_stats_table_items_assign_supported' \
    "build driver 缺少 compile_stats table_items 支持判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_materialize_compile_stats_table_items_slice_body' \
    "build driver 缺少 compile_stats table_items CoreBody 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_compile_stats_table_items_assign' \
    "build driver 缺少 compile_stats table_items CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_lower_compile_stats_table_items_slice_mir_body' \
    "build driver 缺少 compile_stats table_items PortableMIR 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_compile_stats_table_items_slice_body_function' \
    "build driver 缺少 compile_stats table_items PortableMIR builder"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program' \
    "no-silent-C99 测试缺少 compile_stats table_items 后续 frontier"
require_pattern "$NO_SILENT_TEST" '不应在 compile_stats table_items 迁入后继续报告 prefix_stmts=10' \
    "no-silent-C99 测试缺少旧 compile_stats prefix=10 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_compile_stats_table_items_contract\.sh' \
    "stage1 未纳入 compile_stats table_items 合同"

echo "verify_native_compile_stats_table_items_contract: ok"
