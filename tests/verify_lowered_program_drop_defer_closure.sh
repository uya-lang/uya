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
        echo "错误: LoweredProgram drop/defer closure 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+DropDeferPlan' "DropDeferPlan 结构"
require_pattern "$LOWER_CORE_FILE" 'drop_defer_plans:[[:space:]]*SemanticVector' "drop/defer plan 动态表"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_close_drop_defer_plan' "drop/defer plan 闭包入口"
require_pattern "$LOWER_CORE_FILE" 'LOWER_WORK_ITEM_DROP_DEFER' "drop/defer work item"
require_pattern "$LOWER_CORE_FILE" 'defer_count' "记录 defer range"
require_pattern "$LOWER_CORE_FILE" 'errdefer_count' "记录 errdefer range"

tmp_dir="$(mktemp -d /tmp/uya-lowered-drop-defer.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_drop_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_drop_program() LoweredProgram {
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
        functions: lower_drop_vector(),
        body_ops: lower_drop_vector(),
        core_bodies: lower_drop_vector(),
        core_stmts: lower_drop_vector(),
        core_exprs: lower_drop_vector(),
        core_places: lower_drop_vector(),
        core_cleanup_edges: lower_drop_vector(),
        core_semantic_facts: lower_drop_vector(),
        globals: lower_drop_vector(),
        types: lower_drop_vector(),
        interfaces: lower_drop_vector(),
        err_unions: lower_drop_vector(),
        async_frames: lower_drop_vector(),
        drop_defer_plans: lower_drop_vector(),
        helpers: lower_drop_vector(),
        worklist: lower_drop_vector(),
    };
}

test "lowered program closes drop defer plans" {
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

    var lowered: LoweredProgram = lower_drop_program();
    lowered_program_init(&lowered, &arena);

    var first: DropDeferPlan = DropDeferPlan{
        type_id: 300,
        drop_function_id: 90,
        owner_function_id: 80,
        scope_id: 3,
        defer_start: 7,
        defer_count: 2,
        errdefer_start: 11,
        errdefer_count: 1,
    };
    var second: DropDeferPlan = DropDeferPlan{
        type_id: 301,
        drop_function_id: 91,
        owner_function_id: 81,
        scope_id: 4,
        defer_start: 13,
        defer_count: 3,
        errdefer_start: 17,
        errdefer_count: 2,
    };
    try assert_eq_i32(lowered_program_close_drop_defer_plan(&lowered, &first), 0);
    try assert_eq_i32(lowered_program_close_drop_defer_plan(&lowered, &first), 0);
    try assert_eq_i32(lowered_program_close_drop_defer_plan(&lowered, &second), 0);

    try assert_eq_i32(lowered.drop_defer_count as i32, 2);
    try assert_eq_i32(lowered.work_item_count as i32, 2);
    const first_plan: &DropDeferPlan = semantic_vector_item_ptr(&lowered.drop_defer_plans, 0usize) as &DropDeferPlan;
    const second_plan: &DropDeferPlan = semantic_vector_item_ptr(&lowered.drop_defer_plans, 1usize) as &DropDeferPlan;
    try expect(first_plan != null);
    try expect(second_plan != null);
    try assert_eq_i32(first_plan.type_id, 300);
    try assert_eq_i32(first_plan.drop_function_id, 90);
    try assert_eq_i32(first_plan.owner_function_id, 80);
    try assert_eq_i32(first_plan.scope_id, 3);
    try assert_eq_i32(first_plan.defer_start, 7);
    try assert_eq_i32(first_plan.defer_count, 2);
    try assert_eq_i32(first_plan.errdefer_start, 11);
    try assert_eq_i32(first_plan.errdefer_count, 1);
    try assert_eq_i32(second_plan.type_id, 301);
    try assert_eq_i32(second_plan.drop_function_id, 91);
    try assert_eq_i32(second_plan.owner_function_id, 81);
    try assert_eq_i32(second_plan.scope_id, 4);

    var first_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var second_work: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 0usize, &first_work), 1);
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 1usize, &second_work), 1);
    try assert_eq_i32(first_work.kind, LOWER_WORK_ITEM_DROP_DEFER);
    try assert_eq_i32(first_work.primary_id, 80);
    try assert_eq_i32(first_work.secondary_id, 3);
    try assert_eq_i32(second_work.kind, LOWER_WORK_ITEM_DROP_DEFER);
    try assert_eq_i32(second_work.primary_id, 81);
    try assert_eq_i32(second_work.secondary_id, 4);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram drop/defer closure verified"
