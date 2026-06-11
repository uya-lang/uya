#!/usr/bin/env bash

# Native build-seed 边界：固定 parse_build_args(...) backend 标量分支迁入合同。
# 该切片覆盖 `--c99` / `--native` enum out-param 写入，并把 frontier
# 推进到 line-directives scalar option 分支。

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

require_pattern "$TODO_DOC" '为 backend 标量分支补独立合同脚本' \
    "todo 缺少 backend 标量分支合同任务"
require_pattern "$TODO_DOC" '将 backend 标量分支迁入 PortableMIR' \
    "todo 缺少 backend 标量分支实现任务"
require_pattern "$SUBSET_DOC" 'backend 标量分支完成后必须继续报告 branch frontier' \
    "subset doc 缺少 backend 分支后的 frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=3 covered_branch=backend next_branch=--no-line-directives next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "subset doc 缺少 backend 分支后的 line-directives frontier 诊断形状"

require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--c99" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --c99 分支"
require_pattern "$BUILD_DRIVER_SRC" 'backend_type\[0\] = BackendType\.BACKEND_C99;' \
    "parse_build_args 源码缺少 BACKEND_C99 out-param 写入"
require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--native" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --native 分支"
require_pattern "$BUILD_DRIVER_SRC" 'backend_type\[0\] = BackendType\.BACKEND_NATIVE;' \
    "parse_build_args 源码缺少 BACKEND_NATIVE out-param 写入"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_backend_option_if_supported' \
    "生产代码缺少 backend 分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_backend_options_body' \
    "生产代码缺少 backend 分支 body/frontier 判定"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete' \
    "no-silent-C99 测试缺少 loop-body branch frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$NO_SILENT_TEST" '后端类型: C99' \
    "no-silent-C99 测试缺少 C99 fallback 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_backend_options_contract\.sh' \
    "stage1 未纳入 parse_build_args backend options 合同"

echo "verify_native_parse_build_args_backend_options_contract: ok"
