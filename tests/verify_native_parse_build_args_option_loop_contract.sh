#!/usr/bin/env bash

# Native build-seed 边界：固定 parse_build_args(...) option loop 骨架切片合同。
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

echo "verify_native_parse_build_args_option_loop_contract: ok"
