#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) 首切片的 CoreBody/PortableMIR
# golden/verifier 合同输入面。该脚本不声明函数体已经迁入；它保证下一步
# 实现必须从这些已审计 surface 开始，并继续保持 no-silent-C99 frontier。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
NO_SILENT_TEST="$REPO_ROOT/tests/verify_native_cmd_build_no_silent_c99.sh"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"
COREIR_GOLDEN_TEST="$REPO_ROOT/tests/verify_coreir_dump_golden.sh"
MIR_GOLDEN_TEST="$REPO_ROOT/tests/verify_portable_mir_golden.sh"
MIR_VERIFIER_TEST="$REPO_ROOT/tests/verify_portable_mir_verifier.sh"
MIR_VERIFIER_SRC="$REPO_ROOT/src/lower/mir_verifier.uya"

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

require_pattern "$TODO_DOC" '为 `parse_build_args\(\.\.\.\)` 首切片补 CoreBody/PortableMIR golden/verifier 合同' \
    "todo 缺少 parse_build_args 首切片合同任务"
require_pattern "$SUBSET_DOC" '^## `parse_build_args\(\.\.\.\)` PortableMIR Surface Audit' \
    "subset doc 缺少 parse_build_args surface audit"
require_pattern "$SUBSET_DOC" '入口 argv/argc 和 early return' \
    "subset doc 缺少 argv/argc early-return 首切片"
require_pattern "$SUBSET_DOC" '`get_argc\(\)`、`get_argv\(0\)`、`argc < 2`' \
    "subset doc 缺少 get_argc/get_argv/argc 首切片"
require_pattern "$SUBSET_DOC" '`program_name != null`、`print_usage\(program_name as &byte\)`、`return -1`' \
    "subset doc 缺少 program_name/print_usage/return 首切片"
require_pattern "$SUBSET_DOC" '`input_file_capacity <= 0` 时的 `fprintf\(libc.stderr, \.\.\.\)`' \
    "subset doc 缺少 input_file_capacity early-return 首切片"
require_pattern "$SUBSET_DOC" '迁移顺序应先补对应 CoreBody/PortableMIR golden/verifier surface' \
    "subset doc 缺少 golden/verifier 先行规则"

require_pattern "$BUILD_DRIVER_SRC" 'const argc: i32 = get_argc\(\);' \
    "parse_build_args 源码缺少 get_argc 入口"
require_pattern "$BUILD_DRIVER_SRC" 'const program_name: \*byte = get_argv\(0\);' \
    "parse_build_args 源码缺少 get_argv(0) 入口"
require_pattern "$BUILD_DRIVER_SRC" 'if argc < 2' \
    "parse_build_args 源码缺少 argc < 2 early return"
require_pattern "$BUILD_DRIVER_SRC" 'if program_name != null' \
    "parse_build_args 源码缺少 program_name null guard"
require_pattern "$BUILD_DRIVER_SRC" 'print_usage\(program_name as &byte\);' \
    "parse_build_args 源码缺少 print_usage early-return call"
require_pattern "$BUILD_DRIVER_SRC" 'if input_file_capacity <= 0' \
    "parse_build_args 源码缺少 input_file_capacity guard"
require_pattern "$BUILD_DRIVER_SRC" 'fprintf\(libc\.stderr, "错误: 输入文件索引容量无效\\n" as \*byte\);' \
    "parse_build_args 源码缺少容量错误 diagnostic"

require_pattern "$COREIR_GOLDEN_TEST" 'CORE_EXPR_KIND_CALL' \
    "CoreIR golden 缺少 call expr 合同"
require_pattern "$COREIR_GOLDEN_TEST" 'CORE_STMT_KIND_RETURN' \
    "CoreIR golden 缺少 return stmt 合同"
require_pattern "$MIR_GOLDEN_TEST" 'MIR_INST_OP_CALL' \
    "PortableMIR golden 缺少 call inst 合同"
require_pattern "$MIR_GOLDEN_TEST" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR golden 缺少 return terminator 合同"
require_pattern "$MIR_GOLDEN_TEST" 'MIR_TERMINATOR_KIND_COND_BR' \
    "PortableMIR golden 缺少 conditional branch 合同"
require_pattern "$MIR_VERIFIER_SRC" 'portable_mir_verify_range\(term\.successor_start, term\.successor_count' \
    "PortableMIR verifier 缺少 successor range 合同"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=22 next_stmt=22 next_kind=AST_VAR_DECL reason=partial_core_body' \
    "no-silent-C99 测试缺少 parse_build_args body-prefix frontier"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_first_slice_contract\.sh' \
    "stage1 未纳入 parse_build_args 首切片合同"

echo "verify_native_parse_build_args_first_slice_contract: ok"
