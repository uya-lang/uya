#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) --nostdlib 标量分支迁入合同。
# 该叶子固定 `is_nostdlib[0] = 1` store surface、下一段 branch frontier、
# 生产 recognizer 和 stage1 接入点。

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

require_pattern "$TODO_DOC" '为 `--nostdlib` 标量分支补独立合同脚本' \
    "todo 缺少 --nostdlib 标量分支合同任务"
require_pattern "$TODO_DOC" '将 `--nostdlib` 标量分支迁入 PortableMIR' \
    "todo 缺少 --nostdlib 标量分支实现任务"
require_pattern "$SUBSET_DOC" 'nostdlib 标量分支完成后必须继续报告 branch frontier' \
    "subset doc 缺少 --nostdlib 分支后的 frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=7 covered_branch=--nostdlib next_branch=--project-root next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "subset doc 缺少 --nostdlib 分支后的 project-root frontier 诊断形状"

require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--nostdlib" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --nostdlib 分支"
require_pattern "$BUILD_DRIVER_SRC" 'is_nostdlib\[0\] = 1;' \
    "parse_build_args 源码缺少 is_nostdlib out-param 写入"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_nostdlib_option_if_supported' \
    "生产代码缺少 --nostdlib 分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_nostdlib_body' \
    "生产代码缺少 --nostdlib 分支 body/frontier 判定"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete' \
    "no-silent-C99 测试缺少 scalar option loop-body branch frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$NO_SILENT_TEST" '后端类型: C99' \
    "no-silent-C99 测试缺少 C99 fallback 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_nostdlib_contract\.sh' \
    "stage1 未纳入 parse_build_args --nostdlib 合同"

echo "verify_native_parse_build_args_nostdlib_contract: ok"
