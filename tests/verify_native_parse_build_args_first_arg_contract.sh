#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) 首参数处理切片合同。
# 该切片把 body frontier 从默认初始化后的 first_arg 声明推进到 option loop 的 i 初始化。

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

require_pattern "$TODO_DOC" '将 `parse_build_args\(\.\.\.\)` 首参数处理切片迁入 PortableMIR' \
    "todo 缺少 parse_build_args 首参数处理任务"
require_pattern "$SUBSET_DOC" '首参数命令处理：`get_argv\(1\)`、`first_arg != null`' \
    "subset doc 缺少 first_arg 首参数 surface"
require_pattern "$SUBSET_DOC" '`--help` / `-h`' \
    "subset doc 缺少 help/-h surface"
require_pattern "$SUBSET_DOC" '`--version` / `-v`' \
    "subset doc 缺少 version/-v surface"
require_pattern "$SUBSET_DOC" '`build` 子命令分支' \
    "subset doc 缺少 build 子命令 surface"

require_pattern "$BUILD_DRIVER_SRC" 'const first_arg: \*byte = get_argv\(1\);' \
    "parse_build_args 源码缺少 first_arg get_argv(1)"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(first_arg, "--help" as \*byte\) == 0 \|\| strcmp\(first_arg, "-h" as \*byte\) == 0' \
    "parse_build_args 源码缺少 help/-h 分支"
require_pattern "$BUILD_DRIVER_SRC" 'print_usage\(program_name as &byte\);' \
    "parse_build_args 源码缺少 help print_usage"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(first_arg, "--version" as \*byte\) == 0 \|\| strcmp\(first_arg, "-v" as \*byte\) == 0' \
    "parse_build_args 源码缺少 version/-v 分支"
require_pattern "$BUILD_DRIVER_SRC" 'fprintf\(libc\.stdout, "v0\.9\.9\\n" as \*byte\);' \
    "parse_build_args 源码缺少 version stdout"
require_pattern "$BUILD_DRIVER_SRC" 'var start_idx: i32 = 1;' \
    "parse_build_args 源码缺少 start_idx 初始化"
require_pattern "$BUILD_DRIVER_SRC" 'if first_arg != null && strcmp\(first_arg, "build" as \*byte\) == 0' \
    "parse_build_args 源码缺少 build 子命令分支"
require_pattern "$BUILD_DRIVER_SRC" 'start_idx = 2;' \
    "parse_build_args 源码缺少 build 子命令 start_idx 写入"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=22 next_stmt=22 next_kind=AST_VAR_DECL reason=partial_core_body' \
    "no-silent-C99 测试缺少 parse_build_args first-arg frontier"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_first_arg_contract\.sh' \
    "stage1 未纳入 parse_build_args 首参数合同"

echo "verify_native_parse_build_args_first_arg_contract: ok"
