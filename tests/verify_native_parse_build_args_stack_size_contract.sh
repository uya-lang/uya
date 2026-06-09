#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) --stack-size 数字扫描合同。
# 该叶子只冻结缺参、byte index、digit loop、累积、写入和 warning surface，
# 不迁入生产 CoreBody/PortableMIR recognizer。

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

require_pattern "$TODO_DOC" '为 `--stack-size` 补 CoreBody/PortableMIR 合同' \
    "todo 缺少 --stack-size 合同任务"
require_pattern "$TODO_DOC" '迁入 `--stack-size` 缺参和 `get_argv\(i \+ 1\)` 分支' \
    "todo 缺少 --stack-size 缺参/get_argv 实现任务"
require_pattern "$TODO_DOC" '迁入 `--stack-size` 数字扫描 loop' \
    "todo 缺少 --stack-size 数字扫描 loop 实现任务"
require_pattern "$TODO_DOC" '迁入 `--stack-size` 写入/警告/跳参分支' \
    "todo 缺少 --stack-size 写入/警告/跳参实现任务"

require_pattern "$SUBSET_DOC" '`--stack-size` 数字扫描' \
    "subset doc 缺少 --stack-size 数字扫描合同"
require_pattern "$SUBSET_DOC" '`get_argv\(i \+ 1\)`' \
    "subset doc 缺少 --stack-size get_argv(i + 1) surface"
require_pattern "$SUBSET_DOC" '`size_str\[j\]` byte index' \
    "subset doc 缺少 --stack-size byte index surface"
require_pattern "$SUBSET_DOC" '`while size_str\[j\] >= 48 && size_str\[j\] <= 57`' \
    "subset doc 缺少 --stack-size ASCII digit while surface"
require_pattern "$SUBSET_DOC" '`size_val = size_val \* 10 \+ \(size_str\[j\] - 48\)`' \
    "subset doc 缺少 --stack-size 累积表达式 surface"
require_pattern "$SUBSET_DOC" '`stack_size\[0\] = size_val`、无效 warning、缺参 error' \
    "subset doc 缺少 --stack-size 写入/warning/error surface"
require_pattern "$SUBSET_DOC" 'covered_branch=--stack-size-arg-read next_branch=--stack-size-digit-loop' \
    "subset doc 缺少 --stack-size 参数读取后 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--stack-size" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --stack-size 分支"
require_pattern "$BUILD_DRIVER_SRC" 'if i \+ 1 < argc' \
    "parse_build_args 源码缺少 --stack-size 缺参反向检查"
require_pattern "$BUILD_DRIVER_SRC" 'const size_str: \*byte = get_argv\(i \+ 1\);' \
    "parse_build_args 源码缺少 --stack-size get_argv(i + 1)"
require_pattern "$BUILD_DRIVER_SRC" 'if size_str != null' \
    "parse_build_args 源码缺少 --stack-size null 参数保留语义"
require_pattern "$BUILD_DRIVER_SRC" 'var j: i32 = 0;' \
    "parse_build_args 源码缺少 --stack-size digit index 初始化"
require_pattern "$BUILD_DRIVER_SRC" 'var size_val: i32 = 0;' \
    "parse_build_args 源码缺少 --stack-size 累积值初始化"
require_pattern "$BUILD_DRIVER_SRC" 'while size_str\[j\] >= 48 && size_str\[j\] <= 57' \
    "parse_build_args 源码缺少 --stack-size ASCII digit while"
require_pattern "$BUILD_DRIVER_SRC" 'size_val = size_val \* 10 \+ \(size_str\[j\] - 48\);' \
    "parse_build_args 源码缺少 --stack-size 十进制累积表达式"
require_pattern "$BUILD_DRIVER_SRC" 'j = j \+ 1;' \
    "parse_build_args 源码缺少 --stack-size digit index 递增"
require_pattern "$BUILD_DRIVER_SRC" 'if size_val > 0' \
    "parse_build_args 源码缺少 --stack-size 有效值判定"
require_pattern "$BUILD_DRIVER_SRC" 'stack_size\[0\] = size_val;' \
    "parse_build_args 源码缺少 --stack-size out-param 写入"
require_pattern "$BUILD_DRIVER_SRC" '警告：无效的堆栈大小值' \
    "parse_build_args 源码缺少 --stack-size 无效 warning"
require_pattern "$BUILD_DRIVER_SRC" '错误：--stack-size 选项需要指定堆栈大小（KB）' \
    "parse_build_args 源码缺少 --stack-size 缺参 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_stack_size_arg_read_if_supported' \
    "生产代码缺少 --stack-size 缺参/get_argv shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_stack_size_arg_read_body' \
    "生产代码缺少 --stack-size 缺参/get_argv body/frontier 判定"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=13 covered_branch=--stack-size-arg-read next_branch=--stack-size-digit-loop next_kind=AST_VAR_DECL reason=partial_else_if_chain' \
    "no-silent-C99 测试必须固定 --stack-size 参数读取后 frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$NO_SILENT_TEST" '后端类型: C99' \
    "no-silent-C99 测试缺少 C99 fallback 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_stack_size_contract\.sh' \
    "stage1 未纳入 parse_build_args --stack-size 合同"

echo "verify_native_parse_build_args_stack_size_contract: ok"
