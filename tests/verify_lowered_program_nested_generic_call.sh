#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

if ! grep -Eq 'lowered_program_close_generic_function_instances' "$LOWER_CORE_FILE"; then
    echo "错误: nested generic call 覆盖缺少泛型函数闭包入口" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-lowered-nested-generic.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_nested_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_nested_program() LoweredProgram {
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
        core_stmt_count: 0usize,
        core_expr_count: 0usize,
        core_place_count: 0usize,
        core_cleanup_edge_count: 0usize,
        core_semantic_fact_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_nested_vector(),
        body_ops: lower_nested_vector(),
        core_bodies: lower_nested_vector(),
        core_stmts: lower_nested_vector(),
        core_exprs: lower_nested_vector(),
        core_places: lower_nested_vector(),
        core_cleanup_edges: lower_nested_vector(),
        core_semantic_facts: lower_nested_vector(),
        globals: lower_nested_vector(),
        types: lower_nested_vector(),
        interfaces: lower_nested_vector(),
        err_unions: lower_nested_vector(),
        async_frames: lower_nested_vector(),
        drop_defer_plans: lower_nested_vector(),
        helpers: lower_nested_vector(),
        worklist: lower_nested_vector(),
    };
}

fn typed_nested_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: lower_nested_vector(),
        identifier_bindings: lower_nested_vector(),
        call_targets: lower_nested_vector(),
        method_dispatch: lower_nested_vector(),
        field_access: lower_nested_vector(),
        global_init_order: lower_nested_vector(),
        reachable_roots: lower_nested_vector(),
        proof_results: lower_nested_vector(),
    };
}

fn set_nested_target(program: &TypedProgram, expr_id: ExprId,
                     function_id: FunctionId, decl_id: DeclId, mono_id: MonoInstanceId) !void {
    var target: TypedCallTarget = TypedCallTarget{
        kind: TYPED_CALL_TARGET_FUNCTION,
        function_id: function_id,
        decl_id: decl_id,
        symbol_id: 0,
        mono_instance_id: mono_id,
    };
    try assert_eq_i32(typed_program_set_call_target(program, expr_id, &target), 0);
}

test "lowered program closes nested generic call targets" {
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

    var typed: TypedProgram = typed_nested_program();
    typed_program_init(&typed);
    try set_nested_target(&typed, 1, 101, 201, 501);
    try set_nested_target(&typed, 2, 102, 202, 502);
    try set_nested_target(&typed, 3, 101, 201, 501);

    var lowered: LoweredProgram = lower_nested_program();
    lowered_program_init(&lowered, &arena);
    try assert_eq_i32(lowered_program_close_generic_function_instances(&lowered, &typed), 0);

    try assert_eq_i32(lowered.function_count as i32, 2);
    try assert_eq_i32(lowered.work_item_count as i32, 2);
    const inner_fn: &ConcreteFunction = semantic_vector_item_ptr(&lowered.functions, 0usize) as &ConcreteFunction;
    const outer_fn: &ConcreteFunction = semantic_vector_item_ptr(&lowered.functions, 1usize) as &ConcreteFunction;
    try expect(inner_fn != null);
    try expect(outer_fn != null);
    try assert_eq_i32(inner_fn.function_id, 101);
    try assert_eq_i32(inner_fn.mono_instance_id, 501);
    try assert_eq_i32(outer_fn.function_id, 102);
    try assert_eq_i32(outer_fn.mono_instance_id, 502);

    lowered_program_release(&lowered);
    typed_program_release(&typed);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram nested generic call closure verified"
