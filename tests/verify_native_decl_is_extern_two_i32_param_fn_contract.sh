#!/usr/bin/env bash

# Phase 10：固定 native_build_decl_is_extern_two_i32_param_fn(...)
# 7 statement helper 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
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

for file in "$SUBSET_DOC" "$BUILD_DRIVER_SRC" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$SUBSET_DOC" '^## `native_build_decl_is_extern_two_i32_param_fn\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_decl_is_extern_two_i32_param_fn 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_decl_is_extern_two_i32_param_fn prefix_stmts=7 reason=body_complete' \
    "subset doc 缺少 native_build_decl_is_extern_two_i32_param_fn body-complete frontier"
require_pattern "$SUBSET_DOC" 'decl\.fn_decl_param_count != 2 \|\| decl\.fn_decl_is_extern == 0' \
    "subset doc 缺少 two-param/extern-required guard"
require_pattern "$SUBSET_DOC" 'const param0: &ASTNode = decl\.fn_decl_params\[0\];' \
    "subset doc 缺少 param0 local"
require_pattern "$SUBSET_DOC" 'const param1: &ASTNode = decl\.fn_decl_params\[1\];' \
    "subset doc 缺少 param1 local"
require_pattern "$SUBSET_DOC" 'native_build_type_is_i32\(param0\.var_decl_type\) == 0' \
    "subset doc 缺少 param0 type guard"
require_pattern "$SUBSET_DOC" 'return native_build_type_is_i32\(param1\.var_decl_type\);' \
    "subset doc 缺少 tail param1 type helper-call"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_decl_is_extern_two_i32_param_fn prefix_stmts=7 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_decl_is_extern_two_i32_param_fn\(decl: &ASTNode\) i32' \
    "源码缺少 native_build_decl_is_extern_two_i32_param_fn helper"
require_pattern "$BUILD_DRIVER_SRC" 'decl\.fn_decl_param_count != 2 \|\| decl\.fn_decl_is_extern == 0' \
    "源码缺少 extern-required guard"
require_pattern "$BUILD_DRIVER_SRC" 'return native_build_type_is_i32\(param1\.var_decl_type\);' \
    "源码缺少 tail param1 type helper-call"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_hosted_decl_can_materialize_guard_call_tail_return_body' \
    "源码缺少通用 guard/call/tail-return CoreBody materializer"
require_pattern "$BUILD_DRIVER_SRC" 'has_guard_call_tail_return_body' \
    "源码未把 extern two-i32 helper 纳入通用 guard/call/tail-return materializer"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_decl_is_extern_two_i32_param_fn_contract: ok"
