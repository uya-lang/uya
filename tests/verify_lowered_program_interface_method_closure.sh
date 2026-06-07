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
        echo "错误: interface method closure 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_close_interface_method_plan' "interface/vtable 方法闭包入口"
require_pattern "$LOWER_CORE_FILE" 'LOWER_WORK_ITEM_INTERFACE' "interface work item"
require_pattern "$LOWER_CORE_FILE" 'method_range_start' "记录接口方法 range 起点"
require_pattern "$LOWER_CORE_FILE" 'method_range_count' "记录接口方法 range 数量"

tmp_dir="$(mktemp -d /tmp/uya-lowered-interface-method.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_interface_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_interface_program() LoweredProgram {
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
        functions: lower_interface_vector(),
        body_ops: lower_interface_vector(),
        core_bodies: lower_interface_vector(),
        globals: lower_interface_vector(),
        types: lower_interface_vector(),
        interfaces: lower_interface_vector(),
        err_unions: lower_interface_vector(),
        async_frames: lower_interface_vector(),
        drop_defer_plans: lower_interface_vector(),
        helpers: lower_interface_vector(),
        worklist: lower_interface_vector(),
    };
}

test "lowered program closes vtable interface method plans" {
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

    var lowered: LoweredProgram = lower_interface_program();
    lowered_program_init(&lowered, &arena);

    var read_method: InterfacePlan = InterfacePlan{
        type_id: 300,
        symbol_id: 501,
        method_range_start: 12,
        method_range_count: 2,
    };
    var write_method: InterfacePlan = InterfacePlan{
        type_id: 300,
        symbol_id: 502,
        method_range_start: 14,
        method_range_count: 1,
    };
    var early_type_method: InterfacePlan = InterfacePlan{
        type_id: 250,
        symbol_id: 499,
        method_range_start: 8,
        method_range_count: 3,
    };

    try assert_eq_i32(lowered_program_close_interface_method_plan(&lowered, &read_method), 0);
    try assert_eq_i32(lowered_program_close_interface_method_plan(&lowered, &read_method), 0);
    try assert_eq_i32(lowered_program_close_interface_method_plan(&lowered, &write_method), 0);
    try assert_eq_i32(lowered_program_close_interface_method_plan(&lowered, &early_type_method), 0);

    try assert_eq_i32(lowered.interface_count as i32, 3);
    try assert_eq_i32(lowered.work_item_count as i32, 3);

    const first_iface: &InterfacePlan = semantic_vector_item_ptr(&lowered.interfaces, 0usize) as &InterfacePlan;
    const second_iface: &InterfacePlan = semantic_vector_item_ptr(&lowered.interfaces, 1usize) as &InterfacePlan;
    try expect(first_iface != null);
    try expect(second_iface != null);
    try assert_eq_i32(first_iface.type_id, 300);
    try assert_eq_i32(first_iface.symbol_id, 501);
    try assert_eq_i32(first_iface.method_range_start, 12);
    try assert_eq_i32(first_iface.method_range_count, 2);
    try assert_eq_i32(second_iface.type_id, 300);
    try assert_eq_i32(second_iface.symbol_id, 502);
    try assert_eq_i32(second_iface.method_range_start, 14);
    try assert_eq_i32(second_iface.method_range_count, 1);

    var first_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var second_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 0usize, &first_work), 1);
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 1usize, &second_work), 1);
    try assert_eq_i32(first_work.kind, LOWER_WORK_ITEM_INTERFACE);
    try assert_eq_i32(first_work.primary_id, 300);
    try assert_eq_i32(first_work.secondary_id, 501);
    try assert_eq_i32(second_work.kind, LOWER_WORK_ITEM_INTERFACE);
    try assert_eq_i32(second_work.primary_id, 300);
    try assert_eq_i32(second_work.secondary_id, 502);

    try assert_eq_i32(lowered_program_sort_stable(&lowered), 0);
    const sorted_first: &InterfacePlan = semantic_vector_item_ptr(&lowered.interfaces, 0usize) as &InterfacePlan;
    const sorted_second: &InterfacePlan = semantic_vector_item_ptr(&lowered.interfaces, 1usize) as &InterfacePlan;
    const sorted_third: &InterfacePlan = semantic_vector_item_ptr(&lowered.interfaces, 2usize) as &InterfacePlan;
    try expect(sorted_first != null);
    try expect(sorted_second != null);
    try expect(sorted_third != null);
    try assert_eq_i32(sorted_first.type_id, 250);
    try assert_eq_i32(sorted_first.symbol_id, 499);
    try assert_eq_i32(sorted_second.type_id, 300);
    try assert_eq_i32(sorted_second.symbol_id, 501);
    try assert_eq_i32(sorted_third.type_id, 300);
    try assert_eq_i32(sorted_third.symbol_id, 502);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram vtable/interface method closure verified"
