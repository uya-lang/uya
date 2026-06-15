#!/usr/bin/env bash

# Native build-seed 边界：固定 parse_build_args(...) 首参数处理切片合同。
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

echo "verify_native_parse_build_args_first_arg_contract: ok"
