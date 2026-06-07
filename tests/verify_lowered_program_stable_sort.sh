#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: LoweredProgram stable sort 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_stable' "稳定排序入口"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_functions' "functions 稳定排序"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_drop_defer_plans' "drop/defer plans 稳定排序"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_helpers' "helpers 稳定排序"

tmp_dir="$(mktemp -d /tmp/uya-lowered-stable-sort.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_sort_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_sort_program() LoweredProgram {
    return LoweredProgram{
        arena: null,
        function_count: 0usize,
        global_count: 0usize,
        type_count: 0usize,
        interface_count: 0usize,
        err_union_count: 0usize,
        async_frame_count: 0usize,
        drop_defer_count: 0usize,
        helper_count: 0usize,
        work_item_count: 0usize,
        body_op_count: 0usize,
        core_body_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_sort_vector(),
        body_ops: lower_sort_vector(),
        core_bodies: lower_sort_vector(),
        globals: lower_sort_vector(),
        types: lower_sort_vector(),
        interfaces: lower_sort_vector(),
        err_unions: lower_sort_vector(),
        async_frames: lower_sort_vector(),
        drop_defer_plans: lower_sort_vector(),
        helpers: lower_sort_vector(),
        worklist: lower_sort_vector(),
    };
}

test "lowered program sorts output tables by stable ids" {
    var arena_buf: [byte: 4096] = [];
    var arena: CompilerArena = CompilerArena{
        buffer: null,
        size: 0usize,
        offset: 0usize,
        first_chunk: null,
        current_chunk: null,
        total_allocated: 0usize,
        peak_allocated: 0usize,
    };
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);

    var lowered: LoweredProgram = lower_sort_program();
    lowered_program_init(&lowered, &arena);

    var fn_b: ConcreteFunction = ConcreteFunction{ function_id: 30, decl_id: 30, mono_instance_id: 2, body_start: 0, body_count: 0 };
    var fn_a: ConcreteFunction = ConcreteFunction{ function_id: 10, decl_id: 10, mono_instance_id: 1, body_start: 0, body_count: 0 };
    var fn_c: ConcreteFunction = ConcreteFunction{ function_id: 20, decl_id: 20, mono_instance_id: 3, body_start: 0, body_count: 0 };
    try assert_eq_i32(lowered_program_append_function(&lowered, &fn_b), 0);
    try assert_eq_i32(lowered_program_append_function(&lowered, &fn_a), 0);
    try assert_eq_i32(lowered_program_append_function(&lowered, &fn_c), 0);

    var global_b: GlobalObject = GlobalObject{ global_id: 22, decl_id: 22, type_id: 22, init_expr_id: 22 };
    var global_a: GlobalObject = GlobalObject{ global_id: 11, decl_id: 11, type_id: 11, init_expr_id: 11 };
    try assert_eq_i32(lowered_program_append_global(&lowered, &global_b), 0);
    try assert_eq_i32(lowered_program_append_global(&lowered, &global_a), 0);

    var type_b: ConcreteType = ConcreteType{ type_id: 9, decl_id: 9, layout_id: 9, method_range_start: 0, method_range_count: 0 };
    var type_a: ConcreteType = ConcreteType{ type_id: 4, decl_id: 4, layout_id: 4, method_range_start: 0, method_range_count: 0 };
    try assert_eq_i32(lowered_program_append_type(&lowered, &type_b), 0);
    try assert_eq_i32(lowered_program_append_type(&lowered, &type_a), 0);

    var iface_b: InterfacePlan = InterfacePlan{ type_id: 7, symbol_id: 7, method_range_start: 0, method_range_count: 0 };
    var iface_a: InterfacePlan = InterfacePlan{ type_id: 3, symbol_id: 3, method_range_start: 0, method_range_count: 0 };
    try assert_eq_i32(lowered_program_append_interface(&lowered, &iface_b), 0);
    try assert_eq_i32(lowered_program_append_interface(&lowered, &iface_a), 0);

    var err_b: ErrorUnionLayout = ErrorUnionLayout{ type_id: 6, payload_type_id: 60, error_type_id: 61 };
    var err_a: ErrorUnionLayout = ErrorUnionLayout{ type_id: 1, payload_type_id: 10, error_type_id: 11 };
    try assert_eq_i32(lowered_program_append_error_union(&lowered, &err_b), 0);
    try assert_eq_i32(lowered_program_append_error_union(&lowered, &err_a), 0);

    var async_b: AsyncFramePlan = AsyncFramePlan{ function_id: 5, frame_type_id: 50, slot_start: 0, slot_count: 2 };
    var async_a: AsyncFramePlan = AsyncFramePlan{ function_id: 2, frame_type_id: 20, slot_start: 0, slot_count: 1 };
    try assert_eq_i32(lowered_program_append_async_frame(&lowered, &async_b), 0);
    try assert_eq_i32(lowered_program_append_async_frame(&lowered, &async_a), 0);

    var drop_b: DropDeferPlan = DropDeferPlan{
        type_id: 8,
        drop_function_id: 18,
        owner_function_id: 8,
        scope_id: 2,
        defer_start: 0,
        defer_count: 1,
        errdefer_start: 0,
        errdefer_count: 0,
    };
    var drop_a: DropDeferPlan = DropDeferPlan{
        type_id: 1,
        drop_function_id: 11,
        owner_function_id: 1,
        scope_id: 1,
        defer_start: 0,
        defer_count: 1,
        errdefer_start: 0,
        errdefer_count: 0,
    };
    try assert_eq_i32(lowered_program_append_drop_defer_plan(&lowered, &drop_b), 0);
    try assert_eq_i32(lowered_program_append_drop_defer_plan(&lowered, &drop_a), 0);

    var helper_b: RuntimeHelper = RuntimeHelper{ helper_id: 12, kind: LOWERED_RUNTIME_HELPER_UNKNOWN, name_id: 112 };
    var helper_a: RuntimeHelper = RuntimeHelper{ helper_id: 11, kind: LOWERED_RUNTIME_HELPER_UNKNOWN, name_id: 111 };
    try assert_eq_i32(lowered_program_append_helper(&lowered, &helper_b), 0);
    try assert_eq_i32(lowered_program_append_helper(&lowered, &helper_a), 0);

    try assert_eq_i32(lowered_program_sort_stable(&lowered), 0);

    const first_fn: &ConcreteFunction = semantic_vector_item_ptr(&lowered.functions, 0usize) as &ConcreteFunction;
    const first_global: &GlobalObject = semantic_vector_item_ptr(&lowered.globals, 0usize) as &GlobalObject;
    const first_type: &ConcreteType = semantic_vector_item_ptr(&lowered.types, 0usize) as &ConcreteType;
    const first_iface: &InterfacePlan = semantic_vector_item_ptr(&lowered.interfaces, 0usize) as &InterfacePlan;
    const first_err: &ErrorUnionLayout = semantic_vector_item_ptr(&lowered.err_unions, 0usize) as &ErrorUnionLayout;
    const first_async: &AsyncFramePlan = semantic_vector_item_ptr(&lowered.async_frames, 0usize) as &AsyncFramePlan;
    const first_drop: &DropDeferPlan = semantic_vector_item_ptr(&lowered.drop_defer_plans, 0usize) as &DropDeferPlan;
    const first_helper: &RuntimeHelper = semantic_vector_item_ptr(&lowered.helpers, 0usize) as &RuntimeHelper;
    try expect(first_fn != null);
    try expect(first_global != null);
    try expect(first_type != null);
    try expect(first_iface != null);
    try expect(first_err != null);
    try expect(first_async != null);
    try expect(first_drop != null);
    try expect(first_helper != null);
    try assert_eq_i32(first_fn.function_id, 10);
    try assert_eq_i32(first_global.global_id, 11);
    try assert_eq_i32(first_type.type_id, 4);
    try assert_eq_i32(first_iface.type_id, 3);
    try assert_eq_i32(first_err.type_id, 1);
    try assert_eq_i32(first_async.function_id, 2);
    try assert_eq_i32(first_drop.owner_function_id, 1);
    try assert_eq_i32(first_helper.helper_id, 11);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram stable output sort verified"
