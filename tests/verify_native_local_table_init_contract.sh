#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_local_table_init(...)
# 完整初始化 body 的 CoreBody/PortableMIR body-complete 合同。

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

require_pattern "$TODO_DOC" 'native_build_local_table_init\(\.\.\.\).*15 statement body-complete' \
    "todo 缺少 native_build_local_table_init 15 statement body-complete 完成记录"
require_pattern "$TODO_DOC" 'native_build_reachability_init\(\.\.\.\).*generic_corebody_reachability_init_body_lowering' \
    "todo 缺少 local_table_init 迁入后的下一处 frontier"
require_pattern "$SUBSET_DOC" '^## `native_build_local_table_init\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_local_table_init 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_local_table_init .*body_stmts=15 reason=pending_core_body' \
    "subset doc 缺少当前 native_build_local_table_init pending frontier"
require_pattern "$SUBSET_DOC" 'var locals: NativeBuildLocalTable = native_build_local_table_empty\(\)' \
    "subset doc 缺少 locals empty 初始化"
require_pattern "$SUBSET_DOC" 'arena == null \|\| capacity <= 0' \
    "subset doc 缺少 arena/capacity guard"
require_pattern "$SUBSET_DOC" 'capacity as! usize' \
    "subset doc 缺少 capacity checked cast"
require_pattern "$SUBSET_DOC" 'cap_usize_result catch' \
    "subset doc 缺少 cap_usize catch fallback"
require_pattern "$SUBSET_DOC" 'locals\.names = compiler_arena_alloc' \
    "subset doc 缺少 names alloc"
require_pattern "$SUBSET_DOC" 'locals\.call_targets = compiler_arena_alloc' \
    "subset doc 缺少 call_targets alloc"
require_pattern "$SUBSET_DOC" 'locals\.kinds = compiler_arena_alloc' \
    "subset doc 缺少 kinds alloc"
require_pattern "$SUBSET_DOC" 'locals\.init_values = compiler_arena_alloc' \
    "subset doc 缺少 init_values alloc"
require_pattern "$SUBSET_DOC" 'locals\.static_knowns = compiler_arena_alloc' \
    "subset doc 缺少 static_knowns alloc"
require_pattern "$SUBSET_DOC" 'locals\.lengths = compiler_arena_alloc' \
    "subset doc 缺少 lengths alloc"
require_pattern "$SUBSET_DOC" 'native_build_local_table_empty\(\)' \
    "subset doc 缺少 alloc null fallback"
require_pattern "$SUBSET_DOC" 'locals\.capacity = capacity' \
    "subset doc 缺少 capacity 写入"
require_pattern "$SUBSET_DOC" 'while i < capacity' \
    "subset doc 缺少 loop surface"
require_pattern "$SUBSET_DOC" 'locals\.names\[i\] = null' \
    "subset doc 缺少 names loop 初始化"
require_pattern "$SUBSET_DOC" 'locals\.call_targets\[i\] = -1' \
    "subset doc 缺少 call_targets loop 初始化"
require_pattern "$SUBSET_DOC" 'locals\.kinds\[i\] = 0' \
    "subset doc 缺少 kinds loop 初始化"
require_pattern "$SUBSET_DOC" 'locals\.init_values\[i\] = 0' \
    "subset doc 缺少 init_values loop 初始化"
require_pattern "$SUBSET_DOC" 'locals\.static_knowns\[i\] = 0' \
    "subset doc 缺少 static_knowns loop 初始化"
require_pattern "$SUBSET_DOC" 'locals\.lengths\[i\] = 0' \
    "subset doc 缺少 lengths loop 初始化"
require_pattern "$SUBSET_DOC" 'return locals' \
    "subset doc 缺少 final return"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_local_table_init prefix_stmts=15 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_local_table_init\(arena: &CompilerArena, capacity: i32\) NativeBuildLocalTable' \
    "源码缺少 native_build_local_table_init helper"
require_pattern "$BUILD_DRIVER_SRC" 'var locals: NativeBuildLocalTable = native_build_local_table_empty\(\)' \
    "源码缺少 locals empty 初始化"
require_pattern "$BUILD_DRIVER_SRC" 'if arena == null \|\| capacity <= 0' \
    "源码缺少 arena/capacity guard"
require_pattern "$BUILD_DRIVER_SRC" 'const cap_usize_result: !usize = capacity as! usize' \
    "源码缺少 checked usize cast"
require_pattern "$BUILD_DRIVER_SRC" 'const cap_usize: usize = cap_usize_result catch' \
    "源码缺少 checked cast catch"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.names = compiler_arena_alloc' \
    "源码缺少 names alloc"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.call_targets = compiler_arena_alloc' \
    "源码缺少 call_targets alloc"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.kinds = compiler_arena_alloc' \
    "源码缺少 kinds alloc"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.init_values = compiler_arena_alloc' \
    "源码缺少 init_values alloc"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.static_knowns = compiler_arena_alloc' \
    "源码缺少 static_knowns alloc"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.lengths = compiler_arena_alloc' \
    "源码缺少 lengths alloc"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.capacity = capacity' \
    "源码缺少 capacity 写入"
require_pattern "$BUILD_DRIVER_SRC" 'while i < capacity' \
    "源码缺少 loop"
require_pattern "$BUILD_DRIVER_SRC" 'locals\.call_targets\[i\] = -1' \
    "源码缺少 call_targets sentinel"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_local_table_init_contract\.sh' \
    "stage1 未纳入 native_build_local_table_init 合同"

echo "verify_native_local_table_init_contract: ok"
