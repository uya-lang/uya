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
        echo "错误: LoweredProgram async frame closure 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_close_async_frame_metadata' "async frame 元数据闭包入口"
require_pattern "$LOWER_CORE_FILE" 'LOWER_WORK_ITEM_ASYNC_FRAME' "async frame work item"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_async_frame' "输出 AsyncFramePlan"
require_pattern "$LOWER_CORE_FILE" 'frame_type_id' "记录 frame type"
require_pattern "$LOWER_CORE_FILE" 'slot_count' "记录 frame slot range"

tmp_dir="$(mktemp -d /tmp/uya-lowered-async-frame.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_async_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_async_program() LoweredProgram {
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
        functions: lower_async_vector(),
        body_ops: lower_async_vector(),
        globals: lower_async_vector(),
        types: lower_async_vector(),
        interfaces: lower_async_vector(),
        err_unions: lower_async_vector(),
        async_frames: lower_async_vector(),
        drop_defer_plans: lower_async_vector(),
        helpers: lower_async_vector(),
        worklist: lower_async_vector(),
    };
}

test "lowered program closes async frame metadata" {
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

    var lowered: LoweredProgram = lower_async_program();
    lowered_program_init(&lowered, &arena);

    var first: AsyncFramePlan = AsyncFramePlan{
        function_id: 80,
        frame_type_id: 180,
        slot_start: 5,
        slot_count: 3,
    };
    var second: AsyncFramePlan = AsyncFramePlan{
        function_id: 81,
        frame_type_id: 181,
        slot_start: 8,
        slot_count: 4,
    };
    try assert_eq_i32(lowered_program_close_async_frame_metadata(&lowered, &first), 0);
    try assert_eq_i32(lowered_program_close_async_frame_metadata(&lowered, &first), 0);
    try assert_eq_i32(lowered_program_close_async_frame_metadata(&lowered, &second), 0);

    try assert_eq_i32(lowered.async_frame_count as i32, 2);
    try assert_eq_i32(lowered.work_item_count as i32, 2);
    const first_frame: &AsyncFramePlan = semantic_vector_item_ptr(&lowered.async_frames, 0usize) as &AsyncFramePlan;
    const second_frame: &AsyncFramePlan = semantic_vector_item_ptr(&lowered.async_frames, 1usize) as &AsyncFramePlan;
    try expect(first_frame != null);
    try expect(second_frame != null);
    try assert_eq_i32(first_frame.function_id, 80);
    try assert_eq_i32(first_frame.frame_type_id, 180);
    try assert_eq_i32(first_frame.slot_start, 5);
    try assert_eq_i32(first_frame.slot_count, 3);
    try assert_eq_i32(second_frame.function_id, 81);
    try assert_eq_i32(second_frame.frame_type_id, 181);
    try assert_eq_i32(second_frame.slot_start, 8);
    try assert_eq_i32(second_frame.slot_count, 4);

    var first_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var second_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 0usize, &first_work), 1);
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 1usize, &second_work), 1);
    try assert_eq_i32(first_work.kind, LOWER_WORK_ITEM_ASYNC_FRAME);
    try assert_eq_i32(first_work.primary_id, 80);
    try assert_eq_i32(first_work.secondary_id, 180);
    try assert_eq_i32(second_work.kind, LOWER_WORK_ITEM_ASYNC_FRAME);
    try assert_eq_i32(second_work.primary_id, 81);
    try assert_eq_i32(second_work.secondary_id, 181);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram async frame closure verified"
