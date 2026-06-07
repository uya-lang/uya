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
        echo "错误: LoweredProgram generic function closure 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_close_generic_function_instances' "泛型函数实例闭包入口"
require_pattern "$LOWER_CORE_FILE" 'TYPED_CALL_TARGET_FUNCTION' "读取 TypedProgram 函数调用目标"
require_pattern "$LOWER_CORE_FILE" 'mono_instance_id' "按 MonoInstanceId 收敛实例"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_function' "输出 ConcreteFunction"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_work_item' "将实例加入 lowering worklist"

tmp_dir="$(mktemp -d /tmp/uya-lowered-generic-fn.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_generic_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_generic_program() LoweredProgram {
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
        functions: lower_generic_vector(),
        body_ops: lower_generic_vector(),
        core_bodies: lower_generic_vector(),
        globals: lower_generic_vector(),
        types: lower_generic_vector(),
        interfaces: lower_generic_vector(),
        err_unions: lower_generic_vector(),
        async_frames: lower_generic_vector(),
        drop_defer_plans: lower_generic_vector(),
        helpers: lower_generic_vector(),
        worklist: lower_generic_vector(),
    };
}

fn typed_generic_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: lower_generic_vector(),
        identifier_bindings: lower_generic_vector(),
        call_targets: lower_generic_vector(),
        method_dispatch: lower_generic_vector(),
        field_access: lower_generic_vector(),
        global_init_order: lower_generic_vector(),
        reachable_roots: lower_generic_vector(),
        proof_results: lower_generic_vector(),
    };
}

fn set_call_target(program: &TypedProgram, expr_id: ExprId, kind: i32,
                   function_id: FunctionId, decl_id: DeclId, mono_id: MonoInstanceId) !void {
    var target: TypedCallTarget = TypedCallTarget{
        kind: kind,
        function_id: function_id,
        decl_id: decl_id,
        symbol_id: 0,
        mono_instance_id: mono_id,
    };
    try assert_eq_i32(typed_program_set_call_target(program, expr_id, &target), 0);
}

test "lowered program closes generic function call targets" {
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

    var typed: TypedProgram = typed_generic_program();
    typed_program_init(&typed);
    try set_call_target(&typed, 2, TYPED_CALL_TARGET_FUNCTION, 42, 142, 100);
    try set_call_target(&typed, 5, TYPED_CALL_TARGET_FUNCTION, 42, 142, 100);
    try set_call_target(&typed, 7, TYPED_CALL_TARGET_FUNCTION, 43, 143, 101);
    try set_call_target(&typed, 9, TYPED_CALL_TARGET_METHOD, 44, 144, 102);
    try set_call_target(&typed, 11, TYPED_CALL_TARGET_FUNCTION, 45, 145, TYPED_PROGRAM_INVALID_ID);

    var lowered: LoweredProgram = lower_generic_program();
    lowered_program_init(&lowered, &arena);
    try assert_eq_i32(lowered_program_close_generic_function_instances(&lowered, &typed), 0);
    try assert_eq_i32(lowered.function_count as i32, 2);
    try assert_eq_i32(lowered.work_item_count as i32, 2);
    try expect(lowered.functions.capacity >= 2usize);

    const first_fn: &ConcreteFunction = semantic_vector_item_ptr(&lowered.functions, 0usize) as &ConcreteFunction;
    const second_fn: &ConcreteFunction = semantic_vector_item_ptr(&lowered.functions, 1usize) as &ConcreteFunction;
    try expect(first_fn != null);
    try expect(second_fn != null);
    try assert_eq_i32(first_fn.function_id, 42);
    try assert_eq_i32(first_fn.decl_id, 142);
    try assert_eq_i32(first_fn.mono_instance_id, 100);
    try assert_eq_i32(second_fn.function_id, 43);
    try assert_eq_i32(second_fn.decl_id, 143);
    try assert_eq_i32(second_fn.mono_instance_id, 101);

    var first_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var second_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 0usize, &first_work), 1);
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 1usize, &second_work), 1);
    try assert_eq_i32(first_work.kind, LOWER_WORK_ITEM_FUNCTION);
    try assert_eq_i32(first_work.primary_id, 42);
    try assert_eq_i32(first_work.secondary_id, 100);
    try assert_eq_i32(second_work.kind, LOWER_WORK_ITEM_FUNCTION);
    try assert_eq_i32(second_work.primary_id, 43);
    try assert_eq_i32(second_work.secondary_id, 101);

    try assert_eq_i32(lowered_program_close_generic_function_instances(&lowered, &typed), 0);
    try assert_eq_i32(lowered.function_count as i32, 2);
    try assert_eq_i32(lowered.work_item_count as i32, 2);

    lowered_program_release(&lowered);
    typed_program_release(&typed);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram generic function closure verified"
