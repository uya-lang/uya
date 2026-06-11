#!/usr/bin/env bash

# Phase 10：固定 native_build_local_table_empty()
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

require_pattern "$TODO_DOC" 'native_build_local_table_empty\(\).*body-complete' \
    "todo 缺少 native_build_local_table_empty 合同任务"
require_pattern "$SUBSET_DOC" '^## `native_build_local_table_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_local_table_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_local_table_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_local_table_empty pending frontier"
require_pattern "$SUBSET_DOC" 'names: null' \
    "subset doc 缺少 names null 字段"
require_pattern "$SUBSET_DOC" 'call_targets: null' \
    "subset doc 缺少 call_targets null 字段"
require_pattern "$SUBSET_DOC" 'kinds: null' \
    "subset doc 缺少 kinds null 字段"
require_pattern "$SUBSET_DOC" 'init_values: null' \
    "subset doc 缺少 init_values null 字段"
require_pattern "$SUBSET_DOC" 'static_knowns: null' \
    "subset doc 缺少 static_knowns null 字段"
require_pattern "$SUBSET_DOC" 'lengths: null' \
    "subset doc 缺少 lengths null 字段"
require_pattern "$SUBSET_DOC" 'count: 0' \
    "subset doc 缺少 count 0 字段"
require_pattern "$SUBSET_DOC" 'capacity: 0' \
    "subset doc 缺少 capacity 0 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_local_table_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildLocalTable' \
    "源码缺少 NativeBuildLocalTable struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_local_table_empty\(\) NativeBuildLocalTable' \
    "源码缺少 native_build_local_table_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildLocalTable\{' \
    "源码缺少 NativeBuildLocalTable return literal"
require_pattern "$BUILD_DRIVER_SRC" 'names: null' \
    "源码缺少 names null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'call_targets: null' \
    "源码缺少 call_targets null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'kinds: null' \
    "源码缺少 kinds null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'init_values: null' \
    "源码缺少 init_values null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'static_knowns: null' \
    "源码缺少 static_knowns null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'lengths: null' \
    "源码缺少 lengths null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'count: 0' \
    "源码缺少 count 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'capacity: 0' \
    "源码缺少 capacity 0 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_local_table_empty_contract\.sh' \
    "stage1 未纳入 native_build_local_table_empty 合同"

echo "verify_native_local_table_empty_contract: ok"
