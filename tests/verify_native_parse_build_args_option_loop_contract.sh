#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) option loop 骨架切片合同。
# 该切片覆盖 i 初始化、while i < argc、get_argv(i) null diagnostic 和 loop 尾部递增。

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

require_pattern "$TODO_DOC" '将 `parse_build_args\(\.\.\.\)` option loop 骨架迁入 PortableMIR' \
    "todo 缺少 parse_build_args option loop 骨架任务"
require_pattern "$SUBSET_DOC" '主 option loop 骨架：`var start_idx`、`var i`、`while i < argc`' \
    "subset doc 缺少 option loop 骨架 surface"
require_pattern "$SUBSET_DOC" '`get_argv\(i\)`' \
    "subset doc 缺少 get_argv(i) surface"
require_pattern "$SUBSET_DOC" 'null 参数 diagnostic' \
    "subset doc 缺少 null 参数 diagnostic surface"
require_pattern "$SUBSET_DOC" 'loop 尾部 `i = i \+ 1`' \
    "subset doc 缺少 loop 尾部递增 surface"

require_pattern "$BUILD_DRIVER_SRC" 'var i: i32 = start_idx;' \
    "parse_build_args 源码缺少 i 初始化"
require_pattern "$BUILD_DRIVER_SRC" 'while i < argc' \
    "parse_build_args 源码缺少 while i < argc"
require_pattern "$BUILD_DRIVER_SRC" 'const arg: \*byte = get_argv\(i\);' \
    "parse_build_args 源码缺少 get_argv(i)"
require_pattern "$BUILD_DRIVER_SRC" 'if arg == null' \
    "parse_build_args 源码缺少 arg null guard"
require_pattern "$BUILD_DRIVER_SRC" 'fprintf\(libc\.stderr, "错误: 无法获取命令行参数（索引 %d）\\n" as \*byte, i\);' \
    "parse_build_args 源码缺少 arg null diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'return -1;' \
    "parse_build_args 源码缺少 null arg return"
require_pattern "$BUILD_DRIVER_SRC" 'i = i \+ 1;' \
    "parse_build_args 源码缺少 loop 尾部递增"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=24 next_stmt=24 next_kind=AST_IF_STMT reason=partial_core_body' \
    "no-silent-C99 测试缺少 parse_build_args option-loop frontier"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_option_loop_contract\.sh' \
    "stage1 未纳入 parse_build_args option loop 合同"

echo "verify_native_parse_build_args_option_loop_contract: ok"
