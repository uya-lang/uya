#!/usr/bin/env bash

# Phase 10：固定 compiler_should_profile_diagnostics(...)
# false-like strcmp early-return branch 的 CoreBody/PortableMIR 合同。

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

require_pattern "$TODO_DOC" 'compiler_should_profile_diagnostics\(\.\.\.\).*false-like `strcmp' \
    "todo 缺少 profile diagnostics false-like branch 当前任务"
require_pattern "$SUBSET_DOC" '^## `compiler_should_profile_diagnostics\(\.\.\.\)` False-Like Branch Contract' \
    "subset doc 缺少 compiler_should_profile_diagnostics false-like branch 合同"
require_pattern "$SUBSET_DOC" 'strcmp\(value, "0" as \*byte\) == 0' \
    "subset doc 缺少 false-like strcmp 源码"
require_pattern "$SUBSET_DOC" 'CORE_EXPR_KIND_CALL' \
    "subset doc 缺少 false-like strcmp call CoreIR 合同"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_IF' \
    "subset doc 缺少 false-like branch if CoreIR 合同"
require_pattern "$SUBSET_DOC" 'MIR_INST_OP_CALL' \
    "subset doc 缺少 false-like strcmp PortableMIR call 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=3 next_stmt=3 next_kind=return reason=partial_core_body' \
    "subset doc 缺少 false-like branch 迁入后的 tail return frontier"

require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_PROFILE_DIAGNOSTICS_FALSE_LIKE_BRANCH_PREFIX_STMT_COUNT: i32 = 3' \
    "build driver 缺少 false-like branch prefix 常量"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_profile_diagnostics_false_like_branch_supported' \
    "build driver 缺少 false-like branch 支持判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_profile_diagnostics_false_like_branch_body' \
    "build driver 缺少 false-like branch CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_profile_diagnostics_false_like_branch_body_function' \
    "build driver 缺少 false-like branch PortableMIR builder"
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=3 next_stmt=3 next_kind=return reason=partial_core_body' \
    "no-silent-C99 测试缺少 false-like branch 后继 frontier"
require_pattern "$NO_SILENT_TEST" '不应在 profile diagnostics false-like branch 迁入后继续报告 prefix_stmts=2' \
    "no-silent-C99 测试缺少旧 prefix_stmts=2 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_profile_diagnostics_false_like_branch_contract\.sh' \
    "stage1 未纳入 profile diagnostics false-like branch 合同"

echo "verify_native_profile_diagnostics_false_like_branch_contract: ok"
