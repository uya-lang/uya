#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_lowered_plan_empty()
# 嵌套 struct literal return 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_mir_c99_backend.md"
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

require_pattern "$TODO_DOC" 'native_build_lowered_plan_empty\(\).*body-complete' \
    "todo 缺少 native_build_lowered_plan_empty 合同任务"
require_pattern "$SUBSET_DOC" '^## `native_build_lowered_plan_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_lowered_plan_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_lowered_plan_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_lowered_plan_empty pending frontier"
require_pattern "$SUBSET_DOC" 'NativeBuildLoweredPlan' \
    "subset doc 缺少 NativeBuildLoweredPlan surface"
require_pattern "$SUBSET_DOC" 'LoweredProgram' \
    "subset doc 缺少 LoweredProgram nested surface"
require_pattern "$SUBSET_DOC" 'arena = null' \
    "subset doc 缺少 arena null 字段"
require_pattern "$SUBSET_DOC" 'lifecycle_state = LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED' \
    "subset doc 缺少 lifecycle_state 合同"
require_pattern "$SUBSET_DOC" 'functions.*body_ops.*core_bodies.*core_stmts' \
    "subset doc 缺少 vector 字段顺序"
require_pattern "$SUBSET_DOC" 'worklist' \
    "subset doc 缺少 worklist 字段"
require_pattern "$SUBSET_DOC" 'entry_index.*-1' \
    "subset doc 缺少 entry_index -1 合同"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_lowered_plan_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildLoweredPlan' \
    "源码缺少 NativeBuildLoweredPlan struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_lowered_plan_empty\(\) NativeBuildLoweredPlan' \
    "源码缺少 native_build_lowered_plan_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildLoweredPlan\{' \
    "源码缺少 NativeBuildLoweredPlan return literal"
require_pattern "$BUILD_DRIVER_SRC" 'lowered: LoweredProgram\{' \
    "源码缺少 LoweredProgram nested literal"
require_pattern "$BUILD_DRIVER_SRC" 'arena: null' \
    "源码缺少 arena null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED' \
    "源码缺少 lifecycle_state 字段"
require_pattern "$BUILD_DRIVER_SRC" 'functions: native_build_empty_vector\(\)' \
    "源码缺少 functions empty vector 字段"
require_pattern "$BUILD_DRIVER_SRC" 'worklist: native_build_empty_vector\(\)' \
    "源码缺少 worklist empty vector 字段"
require_pattern "$BUILD_DRIVER_SRC" 'entry_index: -1' \
    "源码缺少 entry_index -1 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_lowered_plan_empty_contract\.sh' \
    "stage1 未纳入 native_build_lowered_plan_empty 合同"

echo "verify_native_lowered_plan_empty_contract: ok"
