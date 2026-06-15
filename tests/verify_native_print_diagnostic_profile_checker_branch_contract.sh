#!/usr/bin/env bash

# Native build-seed 边界：固定 compiler_print_diagnostic_profile(...)
# checker 非空分支切片的 CoreBody/PortableMIR 合同。

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
require_pattern "$SUBSET_DOC" '^## `compiler_print_diagnostic_profile\(\.\.\.\)` Checker Branch Contract' \
    "subset doc 缺少 checker branch 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body' \
    "subset doc 缺少 checker branch 当前 frontier"
require_pattern "$SUBSET_DOC" 'if checker != null' \
    "subset doc 缺少 checker != null 源码"
require_pattern "$SUBSET_DOC" 'count = checker\.diagnostic_format_count' \
    "subset doc 缺少 diagnostic_format_count 写回源码"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_IF' \
    "subset doc 缺少 if CoreIR 合同"
require_pattern "$SUBSET_DOC" 'field read surface' \
    "subset doc 缺少 field read surface"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=3 next_stmt=3 next_kind=AST_CALL_EXPR reason=partial_core_body' \
    "subset doc 缺少 checker branch 迁入后 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn compiler_print_diagnostic_profile\(checker: &TypeChecker\) void' \
    "源码缺少 compiler_print_diagnostic_profile helper"
require_pattern "$BUILD_DRIVER_SRC" 'if checker != null' \
    "源码缺少 checker != null 分支"
require_pattern "$BUILD_DRIVER_SRC" 'count = checker\.diagnostic_format_count' \
    "源码缺少 diagnostic_format_count 写回"
require_pattern "$BUILD_DRIVER_SRC" 'fprintf\(libc\.stderr, "diagnostic_format_count: %d\\n" as \*byte, count\)' \
    "源码缺少 tail fprintf diagnostic profile 输出"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_IF' \
    "CoreIR 缺少 if statement kind"
require_pattern "$CORE_FILE" 'CORE_PLACE_KIND_FIELD' \
    "CoreIR 缺少 field place kind"
require_pattern "$MIR_FILE" 'MIR_INST_OP_LOAD' \
    "PortableMIR 缺少 load inst kind"
require_pattern "$MIR_FILE" 'MIR_INST_OP_LOCAL_SET|MIR_INST_OP_STORE' \
    "PortableMIR 缺少 local write inst kind"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_print_diagnostic_profile_checker_branch_contract: ok"
