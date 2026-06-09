#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) 位置输入文件收集合同。
# 该叶子只冻结 arg[0] byte index、容量检查、index/count 写入、
# 未知 dash option no-op 和后续 source-order frontier；不改生产实现。

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

require_pattern "$TODO_DOC" '为位置输入文件收集补 CoreBody/PortableMIR 合同' \
    "todo 缺少位置输入文件收集合同任务"
require_pattern "$TODO_DOC" '迁入 `arg\[0\]` / 非 dash 判定分支' \
    "todo 缺少位置输入 arg[0] / 非 dash 实现任务"
require_pattern "$TODO_DOC" '迁入输入容量检查分支' \
    "todo 缺少位置输入容量检查实现任务"
require_pattern "$TODO_DOC" '迁入输入索引写入分支' \
    "todo 缺少位置输入 index/count 写入实现任务"

require_pattern "$SUBSET_DOC" '位置输入文件收集合同固定' \
    "subset doc 缺少位置输入文件收集合同章节"
require_pattern "$SUBSET_DOC" '`arg\[0\]` byte index' \
    "subset doc 缺少 arg[0] byte index surface"
require_pattern "$SUBSET_DOC" '`c != 45`' \
    "subset doc 缺少非 dash 判定 surface"
require_pattern "$SUBSET_DOC" '`input_file_count\[0\] >= input_file_capacity`' \
    "subset doc 缺少输入容量检查 surface"
require_pattern "$SUBSET_DOC" '`input_file_indices\[idx\] = i`' \
    "subset doc 缺少输入索引写入 surface"
require_pattern "$SUBSET_DOC" '`input_file_count\[0\] = idx \+ 1`' \
    "subset doc 缺少输入计数写入 surface"
require_pattern "$SUBSET_DOC" '未知 dash option no-op' \
    "subset doc 缺少未知 dash option no-op 语义"
require_pattern "$SUBSET_DOC" 'covered_branch=--split-c-dir next_branch=positional-input' \
    "subset doc 缺少 split-c 后的位置输入 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=positional-input-arg next_branch=positional-input-capacity next_kind=AST_IF_STMT' \
    "subset doc 缺少位置输入 arg 判定后的容量检查 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=positional-input-capacity next_branch=positional-input-store next_kind=AST_VAR_DECL' \
    "subset doc 缺少位置输入容量检查后的 store frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=positional-input next_branch=parse-tail-input-count next_kind=AST_IF_STMT' \
    "subset doc 缺少位置输入完成后的 parse tail frontier"

require_pattern "$BUILD_DRIVER_SRC" 'const c: byte = arg\[0\];' \
    "parse_build_args 源码缺少 arg[0] byte index"
require_pattern "$BUILD_DRIVER_SRC" 'if c != 45' \
    "parse_build_args 源码缺少非 dash 判定"
require_pattern "$BUILD_DRIVER_SRC" 'if input_file_count\[0\] >= input_file_capacity' \
    "parse_build_args 源码缺少输入容量检查"
require_pattern "$BUILD_DRIVER_SRC" '错误: 输入文件数量超过最大限制' \
    "parse_build_args 源码缺少输入容量 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'const idx: i32 = input_file_count\[0\];' \
    "parse_build_args 源码缺少 input_file_count 读取到 idx"
require_pattern "$BUILD_DRIVER_SRC" 'input_file_indices\[idx\] = i;' \
    "parse_build_args 源码缺少 input_file_indices 写入"
require_pattern "$BUILD_DRIVER_SRC" 'input_file_count\[0\] = idx \+ 1;' \
    "parse_build_args 源码缺少 input_file_count 写入"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_positional_input_arg_if_supported' \
    "生产代码缺少位置输入 arg[0] / 非 dash 判定 recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_positional_input_arg_body' \
    "生产代码缺少位置输入 arg[0] / 非 dash body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_positional_input_capacity_if_supported' \
    "生产代码缺少位置输入容量检查 recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_positional_input_capacity_body' \
    "生产代码缺少位置输入容量检查 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_positional_input_store_supported' \
    "生产代码缺少位置输入 index/count 写入 recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_positional_input_body' \
    "生产代码缺少位置输入完整 body/frontier 判定"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete' \
    "no-silent-C99 测试必须固定显式输出路径读取后的 return frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_inputs_contract\.sh' \
    "stage1 未纳入 parse_build_args 位置输入合同"

echo "verify_native_parse_build_args_inputs_contract: ok"
