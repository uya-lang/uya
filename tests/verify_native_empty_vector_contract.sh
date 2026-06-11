#!/usr/bin/env bash

# Phase 10：固定 native_build_empty_vector()
# struct literal return 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
SEMANTIC_TABLE_SRC="$REPO_ROOT/src/semantic/table.uya"
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

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$SEMANTIC_TABLE_SRC" "$CORE_FILE" "$MIR_FILE" \
    "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'native_build_empty_vector\(\).*body-complete 合同' \
    "todo 缺少 native_build_empty_vector 合同任务"
require_pattern "$SUBSET_DOC" '^## `native_build_empty_vector\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_empty_vector 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_empty_vector .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_empty_vector pending frontier"
require_pattern "$SUBSET_DOC" 'data: null' \
    "subset doc 缺少 data null 字段"
require_pattern "$SUBSET_DOC" 'item_size: 0usize' \
    "subset doc 缺少 item_size 0usize 字段"
require_pattern "$SUBSET_DOC" 'count: 0usize' \
    "subset doc 缺少 count 0usize 字段"
require_pattern "$SUBSET_DOC" 'capacity: 0usize' \
    "subset doc 缺少 capacity 0usize 字段"
require_pattern "$SUBSET_DOC" 'bytes: 0usize' \
    "subset doc 缺少 bytes 0usize 字段"
require_pattern "$SUBSET_DOC" 'realloc_count: 0' \
    "subset doc 缺少 realloc_count 0 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_empty_vector prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$SEMANTIC_TABLE_SRC" 'export struct SemanticVector' \
    "源码缺少 SemanticVector struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_empty_vector\(\) SemanticVector' \
    "源码缺少 native_build_empty_vector helper"
require_pattern "$BUILD_DRIVER_SRC" 'return SemanticVector\{' \
    "源码缺少 SemanticVector return literal"
require_pattern "$BUILD_DRIVER_SRC" 'data: null' \
    "源码缺少 data null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'item_size: 0usize' \
    "源码缺少 item_size 0usize 字段"
require_pattern "$BUILD_DRIVER_SRC" 'count: 0usize' \
    "源码缺少 count 0usize 字段"
require_pattern "$BUILD_DRIVER_SRC" 'capacity: 0usize' \
    "源码缺少 capacity 0usize 字段"
require_pattern "$BUILD_DRIVER_SRC" 'bytes: 0usize' \
    "源码缺少 bytes 0usize 字段"
require_pattern "$BUILD_DRIVER_SRC" 'realloc_count: 0' \
    "源码缺少 realloc_count 0 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_empty_vector_contract\.sh' \
    "stage1 未纳入 native_build_empty_vector 合同"

echo "verify_native_empty_vector_contract: ok"
