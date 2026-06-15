#!/usr/bin/env bash

# Native build-seed 边界：固定 compile_stats_record_and_release_typed_program(...)
# peak-bytes 后的 SemanticTableAgg 局部初始化切片合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
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

for file in "$SUBSET_DOC" "$BUILD_DRIVER_SRC" "$NO_SILENT_TEST" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done
require_pattern "$SUBSET_DOC" '^## `compile_stats_record_and_release_typed_program\(\.\.\.\)` Table Agg Init Slice Contract' \
    "subset doc 缺少 compile_stats table-agg init 合同"
require_pattern "$SUBSET_DOC" 'var table_agg: SemanticTableAgg = semantic_table_agg_init\(\);' \
    "subset doc 缺少 table_agg 局部初始化 surface"
require_pattern "$SUBSET_DOC" 'prefix_stmts=8 next_stmt=8 next_kind=AST_CALL_EXPR reason=partial_core_body' \
    "subset doc 缺少 table-agg 后的下一 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'var table_agg: SemanticTableAgg = semantic_table_agg_init\(\);' \
    "compile_stats 源码缺少 table_agg 局部初始化"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_COMPILE_STATS_TABLE_AGG_SLICE_PREFIX_STMT_COUNT: i32 = 8' \
    "build driver 缺少 compile_stats table-agg slice prefix 常量"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_compile_stats_table_agg_decl_supported' \
    "build driver 缺少 compile_stats table_agg 支持判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_materialize_compile_stats_table_agg_slice_body' \
    "build driver 缺少 compile_stats table-agg CoreBody 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_compile_stats_table_agg_decl' \
    "build driver 缺少 compile_stats table_agg CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_lower_compile_stats_table_agg_slice_mir_body' \
    "build driver 缺少 compile_stats table-agg PortableMIR 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_compile_stats_table_agg_slice_body_function' \
    "build driver 缺少 compile_stats table-agg PortableMIR builder"
require_pattern "$NO_SILENT_TEST" 'native_hosted_coreir_preflight: status=-1 verifier_error=0 functions=\[1-9\]\[0-9\]\* core_bodies=\[1-9\]\[0-9\]\* pending_bodies=\[1-9\]\[0-9\]\*' \
    "no-silent-C99 测试缺少当前 CoreIR fail-closed preflight"
require_pattern "$NO_SILENT_TEST" 'native_hosted_preflight: status=-1 verifier_error=-1 mir_extern_functions=\[1-9\]\[0-9\]\* mir_body_functions=0' \
    "no-silent-C99 测试缺少当前 PortableMIR fail-closed preflight"
require_pattern "$NO_SILENT_TEST" '103 个文件' \
    "no-silent-C99 测试缺少当前 cmd/build 依赖数"
require_pattern "$NO_SILENT_TEST" '不能静默回落 C99，也不能使用 build-seed LoweredProgram helper' \
    "no-silent-C99 测试缺少禁止 C99 fallback/build-seed helper 证据"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 compile_stats helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_compile_stats_table_agg_contract: ok"
