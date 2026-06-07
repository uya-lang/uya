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
        echo "错误: LoweredProgram core 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+LoweredProgram' "LoweredProgram 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+ConcreteFunction' "ConcreteFunction 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+LoweredBodyOp' "LoweredBodyOp 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+ConcreteType' "ConcreteType 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+RuntimeHelper' "RuntimeHelper 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+ErrorUnionLayout' "ErrorUnionLayout 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+AsyncFramePlan' "AsyncFramePlan 结构"
require_pattern "$LOWER_CORE_FILE" 'arena:[[:space:]]*&CompilerArena' "LoweredProgram 独立 arena 句柄"
require_pattern "$LOWER_CORE_FILE" 'functions:[[:space:]]*SemanticVector' "functions 动态表"
require_pattern "$LOWER_CORE_FILE" 'body_ops:[[:space:]]*SemanticVector' "body_ops 动态表"
require_pattern "$LOWER_CORE_FILE" 'globals:[[:space:]]*SemanticVector' "globals 动态表"
require_pattern "$LOWER_CORE_FILE" 'types:[[:space:]]*SemanticVector' "types 动态表"
require_pattern "$LOWER_CORE_FILE" 'interfaces:[[:space:]]*SemanticVector' "interfaces 动态表"
require_pattern "$LOWER_CORE_FILE" 'err_unions:[[:space:]]*SemanticVector' "err_unions 动态表"
require_pattern "$LOWER_CORE_FILE" 'async_frames:[[:space:]]*SemanticVector' "async_frames 动态表"
require_pattern "$LOWER_CORE_FILE" 'helpers:[[:space:]]*SemanticVector' "helpers 动态表"
require_pattern "$LOWER_CORE_FILE" 'worklist:[[:space:]]*SemanticVector' "lowering worklist 动态表"
require_pattern "$LOWER_CORE_FILE" 'estimated_bytes:[[:space:]]*usize' "LoweredProgram bytes 估算字段"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_function' "function append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_body_op' "body op append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_body_op' "body op get API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_work_item' "worklist append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_estimated_bytes' "estimated bytes API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_release' "release API"

if grep -Eq 'C99_MAX|CHECKER_.*_SIZE|EXEC_MAX|\\[[^\\]\\n]+:[[:space:]]*[0-9]{2,}\\]' "$LOWER_CORE_FILE"; then
    echo "错误: LoweredProgram core 不应引入固定容量表" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-lowered-core.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn lower_test_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_test_program() LoweredProgram {
    return LoweredProgram{
        arena: null,
        function_count: 0,
        global_count: 0,
        type_count: 0,
        interface_count: 0,
        err_union_count: 0,
        async_frame_count: 0,
        drop_defer_count: 0,
        helper_count: 0,
        work_item_count: 0,
        body_op_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_test_vector(),
        body_ops: lower_test_vector(),
        globals: lower_test_vector(),
        types: lower_test_vector(),
        interfaces: lower_test_vector(),
        err_unions: lower_test_vector(),
        async_frames: lower_test_vector(),
        drop_defer_plans: lower_test_vector(),
        helpers: lower_test_vector(),
        worklist: lower_test_vector(),
    };
}

test "lowered program core uses dynamic tables and records lifetime bytes" {
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

    var lowered: LoweredProgram = lower_test_program();
    lowered_program_init(&lowered, &arena);
    try assert_eq_i32(lowered_program_lifecycle_state(&lowered), LOWERED_PROGRAM_LIFECYCLE_ACTIVE);
    try expect(lowered_program_current_bytes(&lowered) >= @size_of(LoweredProgram));
    try expect(@usize_from_ptr(lowered_program_arena(&lowered)) == @usize_from_ptr(&arena));

    var i: i32 = 0;
    while i < 40 {
        var fn_item: ConcreteFunction = ConcreteFunction{
            function_id: i,
            decl_id: i,
            mono_instance_id: i,
            body_start: i,
            body_count: i + 1,
        };
        var global_item: GlobalObject = GlobalObject{
            global_id: i,
            decl_id: i,
            type_id: i,
            init_expr_id: i,
        };
        var type_item: ConcreteType = ConcreteType{
            type_id: i,
            decl_id: i,
            layout_id: i,
            method_range_start: i,
            method_range_count: i + 1,
        };
        var interface_item: InterfacePlan = InterfacePlan{
            type_id: i,
            symbol_id: i,
            method_range_start: i,
            method_range_count: i + 1,
        };
        var err_item: ErrorUnionLayout = ErrorUnionLayout{
            type_id: i,
            payload_type_id: i,
            error_type_id: i + 1,
        };
        var async_item: AsyncFramePlan = AsyncFramePlan{
            function_id: i,
            frame_type_id: i,
            slot_start: i,
            slot_count: i + 1,
        };
        var helper_item: RuntimeHelper = RuntimeHelper{
            helper_id: i,
            kind: LOWERED_RUNTIME_HELPER_UNKNOWN,
            name_id: i,
        };
        var work_item: LowerWorkItem = LowerWorkItem{
            kind: LOWER_WORK_ITEM_FUNCTION,
            primary_id: i,
            secondary_id: i + 1,
        };
        var body_op: LoweredBodyOp = LoweredBodyOp{
            opcode: LOWERED_BODY_OP_RETURN_CONST_I32,
            dst: 0,
            src0: 0,
            src1: 0,
            target_id: i,
            imm: i as i64,
            flags: 0,
        };
        try assert_eq_i32(lowered_program_append_function(&lowered, &fn_item), 0);
        try assert_eq_i32(lowered_program_append_body_op(&lowered, &body_op), 0);
        try assert_eq_i32(lowered_program_append_global(&lowered, &global_item), 0);
        try assert_eq_i32(lowered_program_append_type(&lowered, &type_item), 0);
        try assert_eq_i32(lowered_program_append_interface(&lowered, &interface_item), 0);
        try assert_eq_i32(lowered_program_append_error_union(&lowered, &err_item), 0);
        try assert_eq_i32(lowered_program_append_async_frame(&lowered, &async_item), 0);
        try assert_eq_i32(lowered_program_append_helper(&lowered, &helper_item), 0);
        try assert_eq_i32(lowered_program_append_work_item(&lowered, &work_item), 0);
        i = i + 1;
    }

    try assert_eq_i32(lowered.function_count, 40);
    try assert_eq_i32(lowered.body_op_count as i32, 40);
    try assert_eq_i32(lowered.global_count, 40);
    try assert_eq_i32(lowered.type_count, 40);
    try assert_eq_i32(lowered.interface_count, 40);
    try assert_eq_i32(lowered.err_union_count, 40);
    try assert_eq_i32(lowered.async_frame_count, 40);
    try assert_eq_i32(lowered.helper_count, 40);
    try assert_eq_i32(lowered.work_item_count, 40);
    try expect(lowered.functions.capacity >= 40usize);
    try expect(lowered.body_ops.capacity >= 40usize);
    try expect(lowered.worklist.capacity >= 40usize);
    try expect(lowered.functions.realloc_count > 1);
    try expect(lowered.body_ops.realloc_count > 1);
    try expect(lowered.worklist.realloc_count > 1);
    try expect(lowered_program_estimated_bytes(&lowered) > @size_of(LoweredProgram));
    try expect(lowered_program_peak_bytes(&lowered) >= lowered_program_current_bytes(&lowered));
    var got_body_op: LoweredBodyOp = LoweredBodyOp{
        opcode: 0,
        dst: 0,
        src0: 0,
        src1: 0,
        target_id: 0,
        imm: 0i64,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_get_body_op(&lowered, 39usize, &got_body_op), 1);
    try assert_eq_i32(got_body_op.opcode, LOWERED_BODY_OP_RETURN_CONST_I32);
    try assert_eq_i32(got_body_op.target_id, 39);
    try assert_eq_i32(got_body_op.imm as i32, 39);

    const stats: LoweredProgramStats = lowered_program_stats(&lowered);
    try assert_eq_i32(stats.table_count, 10);
    try expect(stats.table_capacity >= 360usize);

    lowered_program_release(&lowered);
    try assert_eq_i32(lowered_program_lifecycle_state(&lowered), LOWERED_PROGRAM_LIFECYCLE_RELEASED);
    try expect(lowered_program_current_bytes(&lowered) == 0usize);
    try expect(lowered_program_peak_bytes(&lowered) > @size_of(LoweredProgram));
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram core definition and dynamic storage verified"
