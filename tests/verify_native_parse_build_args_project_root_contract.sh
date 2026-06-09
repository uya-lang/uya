#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) --project-root 分支迁入合同。
# 该叶子冻结 project-root 的全分支目标，同时随着实现推进固定当前已
# 完成的子切片 frontier。

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

require_pattern "$TODO_DOC" '为 `--project-root` 补 CoreBody/PortableMIR 合同' \
    "todo 缺少 --project-root 合同任务"
require_pattern "$TODO_DOC" '迁入 `--project-root` 缺参分支' \
    "todo 缺少 --project-root 缺参实现任务"
require_pattern "$TODO_DOC" '迁入 `--project-root` 参数读取分支' \
    "todo 缺少 --project-root 参数读取实现任务"
require_pattern "$TODO_DOC" '迁入 `--project-root` 长度检查分支' \
    "todo 缺少 --project-root 长度检查实现任务"
require_pattern "$TODO_DOC" '迁入 `--project-root` 成功写入分支' \
    "todo 缺少 --project-root 成功写入实现任务"

require_pattern "$SUBSET_DOC" 'project-root 分支完成后必须继续报告 branch frontier' \
    "subset doc 缺少 --project-root 分支后的 frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root next_branch=--manifest-path next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "subset doc 缺少 --project-root 分支后的 manifest-path frontier 诊断形状"
require_pattern "$SUBSET_DOC" 'project-root 缺参子切片完成后必须继续报告 branch frontier' \
    "subset doc 缺少 --project-root 缺参子切片 frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root-missing-arg next_branch=--project-root-arg-read next_kind=AST_ASSIGN reason=partial_else_if_chain' \
    "subset doc 缺少 --project-root 缺参后的参数读取 frontier 诊断形状"
require_pattern "$SUBSET_DOC" 'project-root 参数读取子切片完成后必须继续报告 branch frontier' \
    "subset doc 缺少 --project-root 参数读取子切片 frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root-arg-read next_branch=--project-root-length next_kind=AST_VAR_DECL reason=partial_else_if_chain' \
    "subset doc 缺少 --project-root 参数读取后的长度检查 frontier 诊断形状"
require_pattern "$SUBSET_DOC" 'project-root 长度检查子切片完成后必须继续报告 branch frontier' \
    "subset doc 缺少 --project-root 长度检查子切片 frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root-length next_branch=--project-root-success next_kind=AST_CALL_EXPR reason=partial_else_if_chain' \
    "subset doc 缺少 --project-root 长度检查后的成功写入 frontier 诊断形状"

require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--project-root" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --project-root 分支"
require_pattern "$BUILD_DRIVER_SRC" 'if i \+ 1 >= argc' \
    "parse_build_args 源码缺少 --project-root 缺参检查"
require_pattern "$BUILD_DRIVER_SRC" '错误: --project-root 需要指定目录' \
    "parse_build_args 源码缺少 --project-root 缺参 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'i = i \+ 1;' \
    "parse_build_args 源码缺少 --project-root 参数索引递增"
require_pattern "$BUILD_DRIVER_SRC" 'const root_arg: \*byte = get_argv\(i\);' \
    "parse_build_args 源码缺少 --project-root get_argv(i)"
require_pattern "$BUILD_DRIVER_SRC" 'root_arg == null \|\| root_arg\[0\] == 0 as byte' \
    "parse_build_args 源码缺少 --project-root 空参数检查"
require_pattern "$BUILD_DRIVER_SRC" '错误: --project-root 不能为空' \
    "parse_build_args 源码缺少 --project-root 空参数 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'const root_len: usize = strlen\(root_arg\);' \
    "parse_build_args 源码缺少 --project-root strlen"
require_pattern "$BUILD_DRIVER_SRC" 'root_len >= PATH_MAX' \
    "parse_build_args 源码缺少 --project-root PATH_MAX 检查"
require_pattern "$BUILD_DRIVER_SRC" '错误: --project-root 路径过长' \
    "parse_build_args 源码缺少 --project-root 路径过长 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'strcpy\(&g_module_root_override\[0\] as \*byte, root_arg\);' \
    "parse_build_args 源码缺少 --project-root strcpy 写入"
require_pattern "$BUILD_DRIVER_SRC" 'g_module_root_override_active = 1;' \
    "parse_build_args 源码缺少 --project-root active 写入"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_missing_arg_if_supported' \
    "生产代码缺少 --project-root 缺参分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_missing_arg_body' \
    "生产代码缺少 --project-root 缺参分支 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_arg_read_if_supported' \
    "生产代码缺少 --project-root 参数读取分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_arg_read_body' \
    "生产代码缺少 --project-root 参数读取分支 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_length_if_supported' \
    "生产代码缺少 --project-root 长度检查分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_length_body' \
    "生产代码缺少 --project-root 长度检查分支 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_success_writes_supported' \
    "生产代码缺少 --project-root 成功写入 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_project_root_success_body' \
    "生产代码缺少 --project-root 成功写入 body/frontier 判定"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=12 covered_branch=--outlibc next_branch=--stack-size next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "no-silent-C99 测试必须固定 --outlibc 完成后的 --stack-size frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$NO_SILENT_TEST" '后端类型: C99' \
    "no-silent-C99 测试缺少 C99 fallback 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_project_root_contract\.sh' \
    "stage1 未纳入 parse_build_args --project-root 合同"

echo "verify_native_parse_build_args_project_root_contract: ok"
