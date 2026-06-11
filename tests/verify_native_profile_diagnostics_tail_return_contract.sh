#!/usr/bin/env bash

# Native build-seed 边界：固定 compiler_should_profile_diagnostics(...)
# tail return 1 的 CoreBody/PortableMIR body-complete 合同。

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

require_pattern "$TODO_DOC" 'compiler_should_profile_diagnostics\(\.\.\.\).*tail `return 1`' \
    "todo 缺少 profile diagnostics tail return 当前任务"
require_pattern "$SUBSET_DOC" '^## `compiler_should_profile_diagnostics\(\.\.\.\)` Tail Return Contract' \
    "subset doc 缺少 compiler_should_profile_diagnostics tail return 合同"
require_pattern "$SUBSET_DOC" 'return 1;' \
    "subset doc 缺少 tail return 源码"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 tail return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'MIR_TERMINATOR_KIND_RETURN' \
    "subset doc 缺少 tail return PortableMIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile .*reason=pending_core_body' \
    "subset doc 缺少迁入 tail return 后的下一个 pending body frontier"

require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_PROFILE_DIAGNOSTICS_TAIL_RETURN_PREFIX_STMT_COUNT: i32 = 4' \
    "build driver 缺少 tail return prefix 常量"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_profile_diagnostics_tail_return_supported' \
    "build driver 缺少 tail return 支持判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_profile_diagnostics_tail_return_body' \
    "build driver 缺少 tail return CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_profile_diagnostics_tail_return_body_function' \
    "build driver 缺少 tail return PortableMIR builder"
require_pattern "$NO_SILENT_TEST" 'native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile .*reason=pending_core_body' \
    "no-silent-C99 测试缺少 tail return 后的下一个 pending body frontier"
require_pattern "$NO_SILENT_TEST" '不应在 profile diagnostics tail return 迁入后继续报告 prefix_stmts=3' \
    "no-silent-C99 测试缺少旧 prefix_stmts=3 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_profile_diagnostics_tail_return_contract\.sh' \
    "stage1 未纳入 profile diagnostics tail return 合同"

echo "verify_native_profile_diagnostics_tail_return_contract: ok"
