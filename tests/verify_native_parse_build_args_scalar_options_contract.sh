#!/usr/bin/env bash

# Native build-seed 边界：固定 parse_build_args(...) 基础 flag / scalar option
# CoreBody/PortableMIR 合同。该脚本只冻结源码 surface、文档化的
# loop-body child frontier 形状和 stage1 接入点；具体分支 lower 由后续
# 叶子逐项完成。

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
require_pattern "$SUBSET_DOC" '基础 flag / scalar option：`-o` 缺参与 `output_file_index\[0\] = i \+ 1`' \
    "subset doc 缺少 scalar option surface"
require_pattern "$SUBSET_DOC" 'loop-body child frontier' \
    "subset doc 缺少 scalar option loop-body child frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_frontier: function=parse_build_args parent_stmt=23' \
    "subset doc 缺少 parse_build_args loop-body child frontier 诊断形状"

require_pattern "$BUILD_DRIVER_SRC" 'if strcmp\(arg, "-o" as \*byte\) == 0' \
    "parse_build_args 源码缺少 -o 分支"
require_pattern "$BUILD_DRIVER_SRC" 'output_file_index\[0\] = i \+ 1;' \
    "parse_build_args 源码缺少 -o output_file_index 写入"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--c99" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --c99 分支"
require_pattern "$BUILD_DRIVER_SRC" 'backend_type\[0\] = BackendType\.BACKEND_C99;' \
    "parse_build_args 源码缺少 BACKEND_C99 写入"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--native" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --native 分支"
require_pattern "$BUILD_DRIVER_SRC" 'backend_type\[0\] = BackendType\.BACKEND_NATIVE;' \
    "parse_build_args 源码缺少 BACKEND_NATIVE 写入"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--no-line-directives" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --no-line-directives 分支"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--line-directives" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --line-directives 分支"
require_pattern "$BUILD_DRIVER_SRC" 'emit_line_directives\[0\] = 1;' \
    "parse_build_args 源码缺少 emit_line_directives 写入"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--safety-proof" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --safety-proof 分支"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--no-safety-proof" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --no-safety-proof 分支"
require_pattern "$BUILD_DRIVER_SRC" 'enable_safety_proof\[0\] = 0;' \
    "parse_build_args 源码缺少 enable_safety_proof 写入"

for level in 0 1 2 3; do
    require_pattern "$BUILD_DRIVER_SRC" "strcmp\\(arg, \"--opt=$level\" as \\*byte\\) == 0 \\|\\| strcmp\\(arg, \"-O$level\" as \\*byte\\) == 0" \
        "parse_build_args 源码缺少 opt level $level 分支"
    require_pattern "$BUILD_DRIVER_SRC" "opt_level\\[0\\] = $level;" \
        "parse_build_args 源码缺少 opt level $level 写入"
done

require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--nostdlib" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --nostdlib 分支"
require_pattern "$BUILD_DRIVER_SRC" 'is_nostdlib\[0\] = 1;' \
    "parse_build_args 源码缺少 is_nostdlib 写入"

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

echo "verify_native_parse_build_args_scalar_options_contract: ok"
