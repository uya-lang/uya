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
        echo "错误: LoweredProgram err_union closure 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_close_err_union_type' "err_union 类型闭包入口"
require_pattern "$LOWER_CORE_FILE" 'LOWER_WORK_ITEM_ERR_UNION' "err_union work item"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_error_union' "输出 ErrorUnionLayout"
require_pattern "$LOWER_CORE_FILE" 'payload_type_id' "记录 payload type"
require_pattern "$LOWER_CORE_FILE" 'error_type_id' "记录 error type"

tmp_dir="$(mktemp -d /tmp/uya-lowered-err-union.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_err_union_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_err_union_program() LoweredProgram {
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
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_err_union_vector(),
        globals: lower_err_union_vector(),
        types: lower_err_union_vector(),
        interfaces: lower_err_union_vector(),
        err_unions: lower_err_union_vector(),
        async_frames: lower_err_union_vector(),
        drop_defer_plans: lower_err_union_vector(),
        helpers: lower_err_union_vector(),
        worklist: lower_err_union_vector(),
    };
}

test "lowered program closes err_union layouts" {
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

    var lowered: LoweredProgram = lower_err_union_program();
    lowered_program_init(&lowered, &arena);

    var first: ErrorUnionLayout = ErrorUnionLayout{
        type_id: 400,
        payload_type_id: 401,
        error_type_id: 402,
    };
    var second: ErrorUnionLayout = ErrorUnionLayout{
        type_id: 410,
        payload_type_id: 411,
        error_type_id: 412,
    };
    try assert_eq_i32(lowered_program_close_err_union_type(&lowered, &first), 0);
    try assert_eq_i32(lowered_program_close_err_union_type(&lowered, &first), 0);
    try assert_eq_i32(lowered_program_close_err_union_type(&lowered, &second), 0);

    try assert_eq_i32(lowered.err_union_count as i32, 2);
    try assert_eq_i32(lowered.work_item_count as i32, 2);
    const first_layout: &ErrorUnionLayout = semantic_vector_item_ptr(&lowered.err_unions, 0usize) as &ErrorUnionLayout;
    const second_layout: &ErrorUnionLayout = semantic_vector_item_ptr(&lowered.err_unions, 1usize) as &ErrorUnionLayout;
    try expect(first_layout != null);
    try expect(second_layout != null);
    try assert_eq_i32(first_layout.type_id, 400);
    try assert_eq_i32(first_layout.payload_type_id, 401);
    try assert_eq_i32(first_layout.error_type_id, 402);
    try assert_eq_i32(second_layout.type_id, 410);
    try assert_eq_i32(second_layout.payload_type_id, 411);
    try assert_eq_i32(second_layout.error_type_id, 412);

    var first_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var second_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 0usize, &first_work), 1);
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 1usize, &second_work), 1);
    try assert_eq_i32(first_work.kind, LOWER_WORK_ITEM_ERR_UNION);
    try assert_eq_i32(first_work.primary_id, 400);
    try assert_eq_i32(first_work.secondary_id, 401);
    try assert_eq_i32(second_work.kind, LOWER_WORK_ITEM_ERR_UNION);
    try assert_eq_i32(second_work.primary_id, 410);
    try assert_eq_i32(second_work.secondary_id, 411);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram err_union closure verified"
