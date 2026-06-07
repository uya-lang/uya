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
        echo "错误: LoweredProgram worklist roots 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_init_worklist_roots' "roots 初始化入口"
require_pattern "$LOWER_CORE_FILE" 'typed\.reachable_roots' "从 TypedProgram reachable roots 初始化"
require_pattern "$LOWER_CORE_FILE" 'LOWER_WORK_ITEM_FUNCTION' "函数 root work item"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_work_item' "worklist 查询 API"

tmp_dir="$(mktemp -d /tmp/uya-lowered-roots.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_roots_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_roots_program() LoweredProgram {
    return LoweredProgram{
        arena: null,
        function_count: 0usize,
        global_count: 0usize,
        type_count: 0usize,
        interface_count: 0usize,
        err_union_count: 0usize,
        async_frame_count: 0usize,
        helper_count: 0usize,
        work_item_count: 0usize,
        body_op_count: 0usize,
        core_body_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_roots_vector(),
        body_ops: lower_roots_vector(),
        core_bodies: lower_roots_vector(),
        globals: lower_roots_vector(),
        types: lower_roots_vector(),
        interfaces: lower_roots_vector(),
        err_unions: lower_roots_vector(),
        async_frames: lower_roots_vector(),
        helpers: lower_roots_vector(),
        worklist: lower_roots_vector(),
    };
}

fn typed_roots_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: lower_roots_vector(),
        identifier_bindings: lower_roots_vector(),
        call_targets: lower_roots_vector(),
        method_dispatch: lower_roots_vector(),
        field_access: lower_roots_vector(),
        global_init_order: lower_roots_vector(),
        reachable_roots: lower_roots_vector(),
        proof_results: lower_roots_vector(),
    };
}

test "lowered program initializes function roots from typed reachable roots" {
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

    var typed: TypedProgram = typed_roots_program();
    typed_program_init(&typed);
    var i: i32 = 0;
    while i < 64 {
        try assert_eq_i32(typed_program_append_reachable_root(&typed, i + 10), 0);
        i = i + 1;
    }

    var lowered: LoweredProgram = lower_roots_program();
    lowered_program_init(&lowered, &arena);
    try assert_eq_i32(lowered_program_init_worklist_roots(&lowered, &typed), 0);
    try assert_eq_i32(lowered.work_item_count as i32, 64);
    try expect(lowered.worklist.capacity >= 64usize);
    try expect(lowered.worklist.realloc_count > 1);

    var first: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var last: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 0usize, &first), 1);
    try assert_eq_i32(lowered_program_get_work_item(&lowered, 63usize, &last), 1);
    try assert_eq_i32(first.kind, LOWER_WORK_ITEM_FUNCTION);
    try assert_eq_i32(first.primary_id, 10);
    try assert_eq_i32(first.secondary_id, 0);
    try assert_eq_i32(last.kind, LOWER_WORK_ITEM_FUNCTION);
    try assert_eq_i32(last.primary_id, 73);
    try assert_eq_i32(last.secondary_id, 0);

    var stale: LowerWorkItem = LowerWorkItem{
        kind: LOWER_WORK_ITEM_RUNTIME_HELPER,
        primary_id: 999,
        secondary_id: 0,
    };
    try assert_eq_i32(lowered_program_append_work_item(&lowered, &stale), 0);
    try assert_eq_i32(lowered.work_item_count as i32, 65);
    try assert_eq_i32(lowered_program_init_worklist_roots(&lowered, &typed), 0);
    try assert_eq_i32(lowered.work_item_count as i32, 64);

    lowered_program_release(&lowered);
    typed_program_release(&typed);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram worklist roots initialization verified"
