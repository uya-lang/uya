#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) build-seed 明确拒绝选项合同。
# 该叶子只冻结 seed 边界、diagnostic、return -1 和 source-order frontier，
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

require_pattern "$TODO_DOC" '为 build-seed reject group 补 CoreBody/PortableMIR 合同' \
    "todo 缺少 build-seed reject group 合同任务"
require_pattern "$TODO_DOC" '迁入 `--manifest-path` 直接拒绝分支' \
    "todo 缺少 --manifest-path 拒绝实现任务"
require_pattern "$TODO_DOC" '迁入 exec/vm/dump/trace 拒绝分支' \
    "todo 缺少 exec/vm/dump/trace 拒绝实现任务"
require_pattern "$TODO_DOC" '迁入 microapp profile 拒绝分支' \
    "todo 缺少 microapp profile 拒绝实现任务"
require_pattern "$TODO_DOC" '迁入 `--outlibc` 直接拒绝分支' \
    "todo 缺少 --outlibc 拒绝实现任务"

require_pattern "$SUBSET_DOC" 'build-seed reject group 合同固定 source-order frontier' \
    "subset doc 缺少 build-seed reject group 合同"
require_pattern "$SUBSET_DOC" '通过 `upm build` 解析包 manifest' \
    "subset doc 缺少 --manifest-path seed 边界"
require_pattern "$SUBSET_DOC" 'seed 不包含 exec backend' \
    "subset doc 缺少 exec backend seed 边界"
require_pattern "$SUBSET_DOC" '使用 `uya microapp build \.\.\.`' \
    "subset doc 缺少 microapp seed 边界"
require_pattern "$SUBSET_DOC" 'seed 不包含 `--outlibc` 生成器' \
    "subset doc 缺少 --outlibc seed 边界"
require_pattern "$SUBSET_DOC" 'covered_branch=--manifest-path next_branch=exec-reject' \
    "subset doc 缺少 --manifest-path 后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=exec-reject next_branch=microapp-reject' \
    "subset doc 缺少 exec reject 后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=microapp-reject next_branch=--outlibc' \
    "subset doc 缺少 microapp reject 后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=--outlibc next_branch=--stack-size' \
    "subset doc 缺少 --outlibc 后 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--manifest-path" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --manifest-path 拒绝分支"
require_pattern "$BUILD_DRIVER_SRC" '错误: cmd/build seed 不支持 --manifest-path；请通过 upm build 解析包 manifest' \
    "parse_build_args 源码缺少 --manifest-path diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--exec" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --exec 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--vm" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --vm 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--dump-exec-hir" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --dump-exec-hir 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--dump-bytecode" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --dump-bytecode 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--trace-vm" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --trace-vm 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" '错误: cmd/build seed 不包含 exec backend' \
    "parse_build_args 源码缺少 exec backend diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--app" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --app 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" 'strcmp\(arg, "--microapp-profile" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --microapp-profile 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" 'strncmp\(arg as &const byte, "--microapp-profile=" as &const byte, 19\) == 0' \
    "parse_build_args 源码缺少 inline microapp profile 拒绝条件"
require_pattern "$BUILD_DRIVER_SRC" '错误: cmd/build seed 不包含 microapp image/payload 支持；请使用 `uya microapp build \.\.\.`' \
    "parse_build_args 源码缺少 microapp diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--outlibc" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --outlibc 拒绝分支"
require_pattern "$BUILD_DRIVER_SRC" '错误: cmd/build seed 不包含 --outlibc 生成器' \
    "parse_build_args 源码缺少 --outlibc diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_manifest_path_if_supported' \
    "生产代码缺少 --manifest-path 拒绝分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_manifest_path_body' \
    "生产代码缺少 --manifest-path 拒绝分支 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_exec_reject_if_supported' \
    "生产代码缺少 exec/vm/dump/trace 拒绝分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_exec_reject_body' \
    "生产代码缺少 exec/vm/dump/trace 拒绝分支 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_microapp_reject_if_supported' \
    "生产代码缺少 microapp profile 拒绝分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_microapp_reject_body' \
    "生产代码缺少 microapp profile 拒绝分支 body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_outlibc_if_supported' \
    "生产代码缺少 --outlibc 拒绝分支 shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_outlibc_body' \
    "生产代码缺少 --outlibc 拒绝分支 body/frontier 判定"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=16 covered_branch=--split-c-dir-inline-disabled next_branch=--split-c-dir-inline-success next_kind=AST_VAR_DECL reason=partial_else_if_chain' \
    "no-silent-C99 测试必须固定 inline split-c disabled 完成后的 success frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_seed_reject_contract\.sh' \
    "stage1 未纳入 build-seed reject group 合同"

echo "verify_native_parse_build_args_seed_reject_contract: ok"
