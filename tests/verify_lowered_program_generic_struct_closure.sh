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
        echo "错误: LoweredProgram generic struct closure 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_close_generic_struct_instance' "泛型结构体实例闭包入口"
require_pattern "$LOWER_CORE_FILE" 'LOWER_WORK_ITEM_TYPE' "类型 work item"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_type' "输出 ConcreteType"
require_pattern "$LOWER_CORE_FILE" 'type_id' "按 TypeId 收敛结构体实例"

tmp_dir="$(mktemp -d /tmp/uya-lowered-generic-struct.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_struct_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_struct_program() LoweredProgram {
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
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_struct_vector(),
        body_ops: lower_struct_vector(),
        globals: lower_struct_vector(),
        types: lower_struct_vector(),
        interfaces: lower_struct_vector(),
        err_unions: lower_struct_vector(),
        async_frames: lower_struct_vector(),
        drop_defer_plans: lower_struct_vector(),
        helpers: lower_struct_vector(),
        worklist: lower_struct_vector(),
    };
}

test "lowered program closes generic struct instances" {
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

    var lowered: LoweredProgram = lower_struct_program();
    lowered_program_init(&lowered, &arena);

    var box_i32: ConcreteType = ConcreteType{
        type_id: 300,
        decl_id: 30,
        layout_id: 700,
        method_range_start: 0,
        method_range_count: 2,
    };
    var box_i64: ConcreteType = ConcreteType{
        type_id: 301,
        decl_id: 30,
        layout_id: 701,
        method_range_start: 2,
        method_range_count: 2,
    };
    try assert_eq_i32(lowered_program_close_generic_struct_instance(&lowered, &box_i32), 0);
    try assert_eq_i32(lowered_program_close_generic_struct_instance(&lowered, &box_i32), 0);
    try assert_eq_i32(lowered_program_close_generic_struct_instance(&lowered, &box_i64), 0);

    try assert_eq_i32(lowered.type_count as i32, 2);
    try assert_eq_i32(lowered.work_item_count as i32, 2);
    const first_type: &ConcreteType = semantic_vector_item_ptr(&lowered.types, 0usize) as &ConcreteType;
    const second_type: &ConcreteType = semantic_vector_item_ptr(&lowered.types, 1usize) as &ConcreteType;
    try expect(first_type != null);
    try expect(second_type != null);
    try assert_eq_i32(first_type.type_id, 300);
    try assert_eq_i32(first_type.decl_id, 30);
    try assert_eq_i32(first_type.layout_id, 700);
    try assert_eq_i32(second_type.type_id, 301);
    try assert_eq_i32(second_type.decl_id, 30);
    try assert_eq_i32(second_type.layout_id, 701);

    var first_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var second_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 0usize, &first_work), 1);
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 1usize, &second_work), 1);
    try assert_eq_i32(first_work.kind, LOWER_WORK_ITEM_TYPE);
    try assert_eq_i32(first_work.primary_id, 300);
    try assert_eq_i32(first_work.secondary_id, 30);
    try assert_eq_i32(second_work.kind, LOWER_WORK_ITEM_TYPE);
    try assert_eq_i32(second_work.primary_id, 301);
    try assert_eq_i32(second_work.secondary_id, 30);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram generic struct closure verified"
