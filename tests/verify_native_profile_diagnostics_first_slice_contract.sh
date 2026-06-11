#!/usr/bin/env bash

# Native build-seed 边界：固定 compiler_should_profile_diagnostics(...)
# 首个 getenv local-decl 切片的 CoreBody/PortableMIR 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
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

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$CORE_FILE" "$MIR_FILE" \
    "$NO_SILENT_TEST" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" '为下一个 helper 的首个最小切片补 CoreBody/PortableMIR golden/verifier 合同' \
    "todo 缺少下一个 helper 首切片合同任务"
require_pattern "$SUBSET_DOC" '^## `compiler_should_profile_diagnostics\(\.\.\.\)` Surface Audit' \
    "subset doc 缺少 compiler_should_profile_diagnostics surface audit"
require_pattern "$SUBSET_DOC" '^## `compiler_should_profile_diagnostics\(\.\.\.\)` First Slice Contract' \
    "subset doc 缺少 compiler_should_profile_diagnostics 首切片合同"
require_pattern "$SUBSET_DOC" 'const value: \*byte = getenv\("UYA_PROFILE_DIAGNOSTICS" as \*byte\);' \
    "subset doc 缺少 getenv local-decl 首切片源码"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_LOCAL_DECL' \
    "subset doc 缺少 local decl CoreIR 合同"
require_pattern "$SUBSET_DOC" 'CORE_EXPR_KIND_CALL' \
    "subset doc 缺少 getenv call CoreIR 合同"
require_pattern "$SUBSET_DOC" 'MIR_INST_OP_CALL' \
    "subset doc 缺少 getenv call PortableMIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=1 next_stmt=1 next_kind=AST_IF_STMT reason=partial_core_body' \
    "subset doc 缺少迁入后首切片 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn compiler_should_profile_diagnostics\(\) i32' \
    "源码缺少 compiler_should_profile_diagnostics helper"
require_pattern "$BUILD_DRIVER_SRC" 'const value: \*byte = getenv\("UYA_PROFILE_DIAGNOSTICS" as \*byte\);' \
    "源码缺少 getenv local-decl 首语句"
require_pattern "$BUILD_DRIVER_SRC" 'if value == null \|\| value\[0\] == 0 as byte' \
    "源码缺少首切片后的 null/empty branch"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_PROFILE_DIAGNOSTICS_FIRST_SLICE_PREFIX_STMT_COUNT: i32 = 1' \
    "build driver 缺少 profile diagnostics 首切片 prefix 常量"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_profile_diagnostics_getenv_decl_supported' \
    "build driver 缺少 profile diagnostics getenv 声明支持判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_materialize_profile_diagnostics_first_slice_body' \
    "build driver 缺少 profile diagnostics CoreBody 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_profile_diagnostics_first_slice_body' \
    "build driver 缺少 profile diagnostics CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_lower_profile_diagnostics_first_slice_mir_body' \
    "build driver 缺少 profile diagnostics PortableMIR 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_profile_diagnostics_first_slice_body_function' \
    "build driver 缺少 profile diagnostics PortableMIR builder"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_LOCAL_DECL' \
    "CoreIR 缺少 local decl statement kind"
require_pattern "$CORE_FILE" 'CORE_EXPR_KIND_CALL' \
    "CoreIR 缺少 call expression kind"
require_pattern "$MIR_FILE" 'MIR_INST_OP_CALL' \
    "PortableMIR 缺少 call inst kind"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=1 next_stmt=1 next_kind=AST_IF_STMT reason=partial_core_body' \
    "no-silent-C99 测试缺少 profile diagnostics 首切片后继 frontier"
require_pattern "$NO_SILENT_TEST" '不应在 profile diagnostics 首切片迁入后继续报告整个 helper pending' \
    "no-silent-C99 测试缺少旧 profile diagnostics pending 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_profile_diagnostics_first_slice_contract\.sh' \
    "stage1 未纳入 profile diagnostics 首切片合同"

echo "verify_native_profile_diagnostics_first_slice_contract: ok"
