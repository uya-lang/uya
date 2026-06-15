#!/usr/bin/env bash

# MIR-C99 self-build：固定 11 参数 parse/out-param helper 的
# CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"
COVERAGE_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

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

for file in "$SUBSET_DOC" "$BUILD_DRIVER_SRC" "$STAGE1_TEST" "$COVERAGE_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$SUBSET_DOC" '^## `native_build_decl_is_parse11_i32_fn\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_decl_is_parse11_i32_fn 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_decl_is_parse11_i32_fn .*body_stmts=21 reason=pending_core_body' \
    "subset doc 缺少当前 parse11 pending frontier"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_decl_is_parse11_i32_fn prefix_stmts=21 reason=body_complete' \
    "subset doc 缺少 parse11 body-complete frontier"
require_pattern "$SUBSET_DOC" 'generic_corebody_parse11_pointer_out_param_lowering' \
    "subset doc 缺少 parse11 generic lowering coverage 名称"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_hosted_decl_can_materialize_parse11_pointer_out_param_body' \
    "源码缺少通用 parse11 pointer out-param CoreBody materializer"
require_pattern "$BUILD_DRIVER_SRC" 'has_parse11_pointer_out_param_body' \
    "源码未把 parse11 helper 纳入 MIR preflight materializer 集合"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*generic_corebody_parse11_pointer_out_param_lowering.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage doc 未记录 parse11 已纳入 lowering"

echo "verify_native_decl_is_parse11_i32_fn_contract: ok"
