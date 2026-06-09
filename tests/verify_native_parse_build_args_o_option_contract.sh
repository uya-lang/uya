#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) `-o` 分支迁入合同。
# 该切片覆盖 `-o` 缺参 diagnostic / return -1、成功分支
# output_file_index[0] = i + 1 和 i = i + 1，并把 frontier 推进到
# backend scalar option 分支。

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

require_pattern "$TODO_DOC" '将 `-o` 分支迁入 verifier-clean PortableMIR' \
    "todo 缺少 -o 分支迁入任务"
require_pattern "$SUBSET_DOC" '`-o` 分支完成后必须报告' \
    "subset doc 缺少 -o 分支完成后的 frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=2 covered_branch=-o next_branch=--c99 next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "subset doc 缺少 -o 分支后的 backend frontier 诊断形状"

require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_o_option_if_supported' \
    "生产代码缺少 -o 分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_o_option_body' \
    "生产代码缺少 -o 分支 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'output_file_index\[0\] = i \+ 1;' \
    "parse_build_args 源码缺少 -o output_file_index 写入"
require_pattern "$BUILD_DRIVER_SRC" '错误: -o 选项需要指定输出文件名' \
    "parse_build_args 源码缺少 -o 缺参 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_reachable_loop_body_branch_frontier' \
    "生产代码缺少 loop-body branch frontier 诊断"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete' \
    "no-silent-C99 测试缺少 loop-body branch frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_o_option_contract\.sh' \
    "stage1 未纳入 parse_build_args -o 合同"

echo "verify_native_parse_build_args_o_option_contract: ok"
