#!/usr/bin/env bash

# Phase 10：固定 compile_stats_record_and_release_typed_program(...)
# TypedProgram aggregate call 的 CoreBody/PortableMIR 切片合同。

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

require_pattern "$TODO_DOC" 'typed_program_accumulate_table_stats\(&checker\.typed_program, &table_agg\)' \
    "todo 缺少 compile_stats TypedProgram aggregate call 任务"
require_pattern "$SUBSET_DOC" '^## `compile_stats_record_and_release_typed_program\(\.\.\.\)` TypedProgram Agg Slice Contract' \
    "subset doc 缺少 compile_stats TypedProgram aggregate 合同"
require_pattern "$SUBSET_DOC" 'typed_program_accumulate_table_stats\(&checker\.typed_program, &table_agg\);' \
    "subset doc 缺少 TypedProgram aggregate call surface"
require_pattern "$SUBSET_DOC" 'prefix_stmts=10 next_stmt=10 next_kind=AST_ASSIGN reason=partial_core_body' \
    "subset doc 缺少 TypedProgram aggregate 后的下一 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'typed_program_accumulate_table_stats\(&checker\.typed_program, &table_agg\);' \
    "compile_stats 源码缺少 TypedProgram aggregate call"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_COMPILE_STATS_TYPED_PROGRAM_AGG_SLICE_PREFIX_STMT_COUNT: i32 = 10' \
    "build driver 缺少 compile_stats TypedProgram aggregate prefix 常量"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_compile_stats_typed_program_agg_call_supported' \
    "build driver 缺少 compile_stats TypedProgram aggregate 支持判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_materialize_compile_stats_typed_program_agg_slice_body' \
    "build driver 缺少 compile_stats TypedProgram aggregate CoreBody 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_compile_stats_typed_program_agg_call' \
    "build driver 缺少 compile_stats TypedProgram aggregate CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_lower_compile_stats_typed_program_agg_slice_mir_body' \
    "build driver 缺少 compile_stats TypedProgram aggregate PortableMIR 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_compile_stats_typed_program_agg_slice_body_function' \
    "build driver 缺少 compile_stats TypedProgram aggregate PortableMIR builder"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=10 next_stmt=10 next_kind=AST_ASSIGN reason=partial_core_body' \
    "no-silent-C99 测试缺少 compile_stats TypedProgram aggregate frontier"
require_pattern "$NO_SILENT_TEST" '不应在 compile_stats typed_program aggregate 迁入后继续报告 prefix_stmts=9' \
    "no-silent-C99 测试缺少旧 compile_stats prefix=9 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_compile_stats_typed_program_agg_contract\.sh' \
    "stage1 未纳入 compile_stats TypedProgram aggregate 合同"

echo "verify_native_compile_stats_typed_program_agg_contract: ok"
