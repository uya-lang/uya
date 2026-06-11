#!/usr/bin/env bash

# Phase 10：固定 compiler_print_diagnostic_profile(...)
# count local 初始化切片的 CoreBody/PortableMIR 合同。

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

require_pattern "$TODO_DOC" 'compiler_print_diagnostic_profile\(\.\.\.\).*`count` 局部初始化补' \
    "todo 缺少 compiler_print_diagnostic_profile count 合同任务"
require_pattern "$SUBSET_DOC" '^## `compiler_print_diagnostic_profile\(\.\.\.\)` Count Local Contract' \
    "subset doc 缺少 compiler_print_diagnostic_profile count local 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL reason=partial_core_body' \
    "subset doc 缺少 count 切片当前 frontier"
require_pattern "$SUBSET_DOC" 'var count: i32 = 0;' \
    "subset doc 缺少 count local 源码"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_LOCAL_DECL' \
    "subset doc 缺少 count local CoreIR 合同"
require_pattern "$SUBSET_DOC" 'CORE_EXPR_KIND_INT_LITERAL' \
    "subset doc 缺少 count zero literal 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body' \
    "subset doc 缺少 count 迁入后 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn compiler_print_diagnostic_profile\(checker: &TypeChecker\) void' \
    "源码缺少 compiler_print_diagnostic_profile helper"
require_pattern "$BUILD_DRIVER_SRC" 'var count: i32 = 0' \
    "源码缺少 count local 初始化"
require_pattern "$BUILD_DRIVER_SRC" 'if checker != null' \
    "源码缺少 count 后的 checker 分支"
require_pattern "$BUILD_DRIVER_SRC" 'fprintf\(libc\.stderr, "diagnostic_format_count: %d\\n" as \*byte, count\)' \
    "源码缺少 tail fprintf diagnostic profile 输出"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_LOCAL_DECL' \
    "CoreIR 缺少 local decl statement kind"
require_pattern "$CORE_FILE" 'CORE_EXPR_KIND_INT_LITERAL' \
    "CoreIR 缺少 int literal expr kind"
require_pattern "$MIR_FILE" 'MIR_INST_OP_CONST_I32|MIR_INST_OP_STORE|MIR_INST_OP_ASSIGN|MIR_INST_OP_COPY' \
    "PortableMIR 缺少可表达 count 初始化的 inst kind"
require_pattern "$STAGE1_TEST" 'verify_native_print_diagnostic_profile_count_contract\.sh' \
    "stage1 未纳入 compiler_print_diagnostic_profile count 合同"

echo "verify_native_print_diagnostic_profile_count_contract: ok"
