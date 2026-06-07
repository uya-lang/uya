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
        echo "错误: LoweredBodyOp transition contract 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_body_op_is_transition_compat_opcode' "冻结兼容 opcode 白名单 API"
require_pattern "$LOWER_CORE_FILE" 'LOWERED_BODY_COMPAT_OPCODE_COUNT:[[:space:]]*i32[[:space:]]*=[[:space:]]*25' "冻结 opcode 数量"
require_pattern "$LOWER_CORE_FILE" 'LOWERED_BODY_COMPAT_MAX_OPCODE:[[:space:]]*i32[[:space:]]*=[[:space:]]*LOWERED_BODY_OP_SET_STACK_LIMIT_BYTES' "冻结 opcode 最大值"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_body_op' "body op append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_body_op_is_transition_compat_opcode\(item\.opcode\)[[:space:]]*==[[:space:]]*0' "append 拒绝未知 opcode"

actual_ops="$(grep -E '^export const LOWERED_BODY_OP_[A-Z0-9_]+:[[:space:]]*i32[[:space:]]*=' "$LOWER_CORE_FILE" | sed -E 's/^export const ([A-Z0-9_]+):.*/\1/')"
expected_ops="$(cat <<'EOF'
LOWERED_BODY_OP_NOP
LOWERED_BODY_OP_RETURN_CONST_I32
LOWERED_BODY_OP_RETURN_CALL
LOWERED_BODY_OP_ADD_I32
LOWERED_BODY_OP_LOCAL_CALL_I32
LOWERED_BODY_OP_RETURN_LOCAL_I32
LOWERED_BODY_OP_LOCAL_CALL_CONST1_I32
LOWERED_BODY_OP_RETURN_PARAM_I32
LOWERED_BODY_OP_LOCAL_CALL_CONST2_I32
LOWERED_BODY_OP_RETURN_ADD_PARAMS_I32
LOWERED_BODY_OP_LOCAL_I32_CONST
LOWERED_BODY_OP_LOCAL_CALL_ADDR1_I32
LOWERED_BODY_OP_STORE_PARAM0_CONST_I32
LOWERED_BODY_OP_STORE_PARAMS01_CONST_I32
LOWERED_BODY_OP_LOCAL_CALL_ADDR2_I32
LOWERED_BODY_OP_RETURN_ARGC_I32
LOWERED_BODY_OP_LOCAL_ARGC_I32
LOWERED_BODY_OP_LOCAL_ARGV_PTR
LOWERED_BODY_OP_RETURN_ARGV_BYTE_I32
LOWERED_BODY_OP_LOCAL_CALL_PARSE11_I32
LOWERED_BODY_OP_STORE_PARAM_CONST_I32
LOWERED_BODY_OP_IF_LOCAL_EQ_CONST_RETURN_I32
LOWERED_BODY_OP_IF_LOCAL_NE_CONST_RETURN_I32
LOWERED_BODY_OP_IF_LOCAL_LE_CONST_ASSIGN_CONST_I32
LOWERED_BODY_OP_SET_STACK_LIMIT_BYTES
EOF
)"

if [[ "$actual_ops" != "$expected_ops" ]]; then
    echo "错误: LoweredBodyOp opcode 清单已变化；新增函数体形状应先进入 CoreBody/PortableMIR，而不是扩展过渡 body op。" >&2
    diff -u <(printf "%s\n" "$expected_ops") <(printf "%s\n" "$actual_ops") >&2 || true
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-lowered-body-op-contract.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn compat_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn compat_program() LoweredProgram {
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
        functions: compat_vec(),
        body_ops: compat_vec(),
        core_bodies: compat_vec(),
        core_stmts: compat_vec(),
        core_exprs: compat_vec(),
        core_places: compat_vec(),
        core_cleanup_edges: compat_vec(),
        core_semantic_facts: compat_vec(),
        globals: compat_vec(),
        types: compat_vec(),
        interfaces: compat_vec(),
        err_unions: compat_vec(),
        async_frames: compat_vec(),
        drop_defer_plans: compat_vec(),
        helpers: compat_vec(),
        worklist: compat_vec(),
    };
}

fn compat_op(opcode: i32) LoweredBodyOp {
    return LoweredBodyOp{
        opcode: opcode,
        dst: 0,
        src0: 0,
        src1: 0,
        target_id: -1,
        imm: 0i64,
        flags: 0,
    };
}

fn expect_compat_opcode(opcode: i32) !void {
    try assert_eq_i32(lowered_body_op_is_transition_compat_opcode(opcode), 1);
}

test "LoweredBodyOp is frozen as transition compatibility input" {
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

    try assert_eq_i32(LOWERED_BODY_COMPAT_OPCODE_COUNT, 25);
    try assert_eq_i32(LOWERED_BODY_COMPAT_MAX_OPCODE, LOWERED_BODY_OP_SET_STACK_LIMIT_BYTES);
    try expect_compat_opcode(LOWERED_BODY_OP_NOP);
    try expect_compat_opcode(LOWERED_BODY_OP_RETURN_CONST_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_RETURN_CALL);
    try expect_compat_opcode(LOWERED_BODY_OP_ADD_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_CALL_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_RETURN_LOCAL_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_CALL_CONST1_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_RETURN_PARAM_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_CALL_CONST2_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_RETURN_ADD_PARAMS_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_I32_CONST);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_CALL_ADDR1_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_STORE_PARAM0_CONST_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_STORE_PARAMS01_CONST_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_CALL_ADDR2_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_RETURN_ARGC_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_ARGC_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_ARGV_PTR);
    try expect_compat_opcode(LOWERED_BODY_OP_RETURN_ARGV_BYTE_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_LOCAL_CALL_PARSE11_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_STORE_PARAM_CONST_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_IF_LOCAL_EQ_CONST_RETURN_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_IF_LOCAL_NE_CONST_RETURN_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_IF_LOCAL_LE_CONST_ASSIGN_CONST_I32);
    try expect_compat_opcode(LOWERED_BODY_OP_SET_STACK_LIMIT_BYTES);
    try assert_eq_i32(lowered_body_op_is_transition_compat_opcode(LOWERED_BODY_COMPAT_MAX_OPCODE + 1), 0);
    try assert_eq_i32(lowered_body_op_is_transition_compat_opcode(-1), 0);

    var lowered: LoweredProgram = compat_program();
    lowered_program_init(&lowered, &arena);
    var allowed: LoweredBodyOp = compat_op(LOWERED_BODY_OP_RETURN_CONST_I32);
    var unknown: LoweredBodyOp = compat_op(LOWERED_BODY_COMPAT_MAX_OPCODE + 1);
    try assert_eq_i32(lowered_program_append_body_op(&lowered, &allowed), 0);
    try assert_eq_i32(lowered_program_append_body_op(&lowered, &unknown), -1);
    try assert_eq_i32(lowered.body_op_count as i32, 1);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredBodyOp transition compatibility contract verified"
