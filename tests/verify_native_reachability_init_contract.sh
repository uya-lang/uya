#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_reachability_init(...)
# 完整初始化 body 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_mir_c99_backend.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
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

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'native_build_reachability_init\(\.\.\.\).*12 statement body-complete.*completed body detail' \
    "todo 缺少 native_build_reachability_init 12 statement body-complete 完成记录"
require_pattern "$TODO_DOC" '已把 `native_build_type_is_i32\(\.\.\.\)` 3 statement body-complete 记录为 completed body detail' \
    "todo 缺少 reachability_init 后续的 type_is_i32 body-complete 完成记录"
require_pattern "$TODO_DOC" 'native_build_type_is_usize\(\.\.\.\).*generic_corebody_type_is_usize_body_lowering' \
    "todo 缺少 reachability_init 迁入后的下一处 frontier"
require_pattern "$SUBSET_DOC" '^## `native_build_reachability_init\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_reachability_init 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_reachability_init .*body_stmts=12 reason=pending_core_body' \
    "subset doc 缺少当前 native_build_reachability_init pending frontier"
require_pattern "$SUBSET_DOC" 'var reach: NativeBuildReachability = native_build_reachability_empty\(\)' \
    "subset doc 缺少 reach empty 初始化"
require_pattern "$SUBSET_DOC" 'arena == null \|\| decl_count <= 0' \
    "subset doc 缺少 arena/decl_count guard"
require_pattern "$SUBSET_DOC" 'decl_count as! usize' \
    "subset doc 缺少 decl_count checked cast"
require_pattern "$SUBSET_DOC" 'count_usize_result catch' \
    "subset doc 缺少 count_usize catch fallback"
require_pattern "$SUBSET_DOC" 'const bytes: usize = @size_of\(i32\) \* count_usize' \
    "subset doc 缺少 bytes 计算"
require_pattern "$SUBSET_DOC" 'reach\.decl_to_function_index = compiler_arena_alloc' \
    "subset doc 缺少 decl_to_function_index alloc"
require_pattern "$SUBSET_DOC" 'reach\.function_decl_indices = compiler_arena_alloc' \
    "subset doc 缺少 function_decl_indices alloc"
require_pattern "$SUBSET_DOC" 'native_build_reachability_empty\(\)' \
    "subset doc 缺少 alloc null fallback"
require_pattern "$SUBSET_DOC" 'reach\.capacity = decl_count' \
    "subset doc 缺少 capacity 写入"
require_pattern "$SUBSET_DOC" 'while i < decl_count' \
    "subset doc 缺少 loop surface"
require_pattern "$SUBSET_DOC" 'reach\.decl_to_function_index\[i\] = -1' \
    "subset doc 缺少 decl_to_function_index loop 初始化"
require_pattern "$SUBSET_DOC" 'reach\.function_decl_indices\[i\] = -1' \
    "subset doc 缺少 function_decl_indices loop 初始化"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_reachability_init prefix_stmts=12 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_reachability_init\(arena: &CompilerArena, decl_count: i32\) NativeBuildReachability' \
    "源码缺少 native_build_reachability_init helper"
require_pattern "$BUILD_DRIVER_SRC" 'var reach: NativeBuildReachability = native_build_reachability_empty\(\)' \
    "源码缺少 reach empty 初始化"
require_pattern "$BUILD_DRIVER_SRC" 'if arena == null \|\| decl_count <= 0' \
    "源码缺少 arena/decl_count guard"
require_pattern "$BUILD_DRIVER_SRC" 'const count_usize_result: !usize = decl_count as! usize' \
    "源码缺少 checked usize cast"
require_pattern "$BUILD_DRIVER_SRC" 'const count_usize: usize = count_usize_result catch' \
    "源码缺少 checked cast catch"
require_pattern "$BUILD_DRIVER_SRC" 'const bytes: usize = @size_of\(i32\) \* count_usize' \
    "源码缺少 bytes 计算"
require_pattern "$BUILD_DRIVER_SRC" 'reach\.decl_to_function_index = compiler_arena_alloc' \
    "源码缺少 decl_to_function_index alloc"
require_pattern "$BUILD_DRIVER_SRC" 'reach\.function_decl_indices = compiler_arena_alloc' \
    "源码缺少 function_decl_indices alloc"
require_pattern "$BUILD_DRIVER_SRC" 'reach\.capacity = decl_count' \
    "源码缺少 capacity 写入"
require_pattern "$BUILD_DRIVER_SRC" 'while i < decl_count' \
    "源码缺少 loop"
require_pattern "$BUILD_DRIVER_SRC" 'reach\.function_decl_indices\[i\] = -1' \
    "源码缺少 function_decl_indices sentinel"
require_pattern "$STAGE1_TEST" 'verify_native_reachability_init_contract\.sh' \
    "stage1 未纳入 native_build_reachability_init 合同"

echo "verify_native_reachability_init_contract: ok"
