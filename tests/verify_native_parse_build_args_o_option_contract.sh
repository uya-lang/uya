#!/usr/bin/env bash

# Native build-seed 边界：固定 parse_build_args(...) `-o` 分支迁入合同。
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

require_pattern "$NO_SILENT_TEST" 'native_hosted_coreir_preflight: status=-1 verifier_error=0 functions=\[1-9\]\[0-9\]\* core_bodies=\[1-9\]\[0-9\]\* pending_bodies=\[1-9\]\[0-9\]\*' \
    "no-silent-C99 测试缺少当前 CoreIR fail-closed preflight"
require_pattern "$NO_SILENT_TEST" 'native_hosted_preflight: status=-1 verifier_error=-1 mir_extern_functions=\[1-9\]\[0-9\]\* mir_body_functions=0' \
    "no-silent-C99 测试缺少当前 PortableMIR fail-closed preflight"
require_pattern "$NO_SILENT_TEST" '103 个文件' \
    "no-silent-C99 测试缺少当前 cmd/build 依赖数"
require_pattern "$NO_SILENT_TEST" '不能静默回落 C99，也不能使用 build-seed LoweredProgram helper' \
    "no-silent-C99 测试缺少禁止 C99 fallback/build-seed helper 证据"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_parse_build_args_o_option_contract: ok"
