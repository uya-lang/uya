#!/usr/bin/env bash

# Phase 10：固定 native_build_ast_plan_empty()
# struct literal return 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
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

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$CORE_FILE" "$MIR_FILE" \
    "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'native_build_ast_plan_empty\(\).*body-complete 合同' \
    "todo 缺少 native_build_ast_plan_empty 合同任务"
require_pattern "$SUBSET_DOC" '^## `native_build_ast_plan_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_ast_plan_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_ast_plan_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_ast_plan_empty pending frontier"
require_pattern "$SUBSET_DOC" 'plans: null' \
    "subset doc 缺少 plans null 字段"
require_pattern "$SUBSET_DOC" 'function_count: 0' \
    "subset doc 缺少 function_count 0 字段"
require_pattern "$SUBSET_DOC" 'entry_index: -1' \
    "subset doc 缺少 entry_index -1 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_ast_plan_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildAstPlan' \
    "源码缺少 NativeBuildAstPlan struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_ast_plan_empty\(\) NativeBuildAstPlan' \
    "源码缺少 native_build_ast_plan_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildAstPlan\{' \
    "源码缺少 NativeBuildAstPlan return literal"
require_pattern "$BUILD_DRIVER_SRC" 'plans: null' \
    "源码缺少 plans null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'function_count: 0' \
    "源码缺少 function_count 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'entry_index: -1' \
    "源码缺少 entry_index -1 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_ast_plan_empty_contract\.sh' \
    "stage1 未纳入 native_build_ast_plan_empty 合同"

echo "verify_native_ast_plan_empty_contract: ok"
