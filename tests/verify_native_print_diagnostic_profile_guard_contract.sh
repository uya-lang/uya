#!/usr/bin/env bash

# Native build-seed 边界：固定 compiler_print_diagnostic_profile(...)
# guard early-return 切片的 CoreBody/PortableMIR 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
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
    "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done
require_pattern "$SUBSET_DOC" '^## `compiler_print_diagnostic_profile\(\.\.\.\)` Surface Audit' \
    "subset doc 缺少 compiler_print_diagnostic_profile surface audit"
require_pattern "$SUBSET_DOC" '^## `compiler_print_diagnostic_profile\(\.\.\.\)` Guard Slice Contract' \
    "subset doc 缺少 compiler_print_diagnostic_profile guard 切片合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile decl=246 function_id=6 body_stmts=4 reason=pending_core_body' \
    "subset doc 缺少当前 compiler_print_diagnostic_profile pending frontier"
require_pattern "$SUBSET_DOC" 'if compiler_should_profile_diagnostics\(\) == 0 \|\| libc\.stderr == null' \
    "subset doc 缺少 guard 源码"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_IF' \
    "subset doc 缺少 guard CoreIR if 合同"
require_pattern "$SUBSET_DOC" 'compiler_should_profile_diagnostics\(\).*resolved local call surface' \
    "subset doc 缺少 profile helper local call surface"
require_pattern "$SUBSET_DOC" '必须保持 global/field 读取 surface' \
    "subset doc 缺少 stderr global/field surface"
require_pattern "$SUBSET_DOC" 'MIR_TERMINATOR_KIND_COND_BR|conditional branch' \
    "subset doc 缺少 PortableMIR conditional branch 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL reason=partial_core_body' \
    "subset doc 缺少 guard 迁入后 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn compiler_print_diagnostic_profile\(checker: &TypeChecker\) void' \
    "源码缺少 compiler_print_diagnostic_profile helper"
require_pattern "$BUILD_DRIVER_SRC" 'if compiler_should_profile_diagnostics\(\) == 0 \|\| libc\.stderr == null' \
    "源码缺少 compiler_print_diagnostic_profile guard"
require_pattern "$BUILD_DRIVER_SRC" 'var count: i32 = 0' \
    "源码缺少 guard 后的 count 局部"
require_pattern "$BUILD_DRIVER_SRC" 'fprintf\(libc\.stderr, "diagnostic_format_count: %d\\n" as \*byte, count\)' \
    "源码缺少 tail fprintf diagnostic profile 输出"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_IF' \
    "CoreIR 缺少 if statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_COND_BR' \
    "PortableMIR 缺少 conditional branch terminator"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_print_diagnostic_profile_guard_contract: ok"
