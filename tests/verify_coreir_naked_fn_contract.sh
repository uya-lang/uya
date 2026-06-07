#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
BUILD_DRIVER_FILE="$REPO_ROOT/src/build_compiler_driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: CoreIR naked function contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$BUILD_DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'CORE_FUNCTION_FLAG_NAKED' "frozen ConcreteFunction naked flag"
require_pattern "$LOWER_CORE_FILE" 'flags:[[:space:]]*i32' "ConcreteFunction flags field"
require_pattern "$LOWER_CORE_FILE" 'CORE_BODY_FLAG_NAKED' "frozen CoreBody naked flag"
require_pattern "$LOWER_CORE_FILE" 'CORE_STMT_KIND_ASM' "asm-only CoreStmt kind"
require_pattern "$LOWER_CORE_FILE" 'CORE_STMT_KIND_DEFER' "defer CoreStmt marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_STMT_KIND_ERRDEFER' "errdefer CoreStmt marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_STMT_FLAG_LOCAL_STACK_SLOT' "ordinary local stack slot marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_PLACE_FLAG_STACK_SLOT' "ordinary stack slot marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_BODY_FLAG_CLEANUP' "defer cleanup body marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_BODY_FLAG_DROP' "implicit drop body marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_BODY_FLAG_ASYNC' "async body marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_BODY_FLAG_ERROR_PROPAGATION' "error path body marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_STMT_FLAG_ERROR_PROPAGATION' "error propagation marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_BODY_FLAG_IMPLICIT_RETURN' "implicit return marker"
require_pattern "$LOWER_CORE_FILE" 'CORE_CAPABILITY_NAKED_FUNCTION' "naked function capability"
require_pattern "$LOWER_CORE_FILE" 'CORE_CAPABILITY_INLINE_ASM' "inline asm capability"
require_pattern "$LOWER_CORE_FILE" 'COREIR_VERIFY_ERR_NAKED_BODY' "naked verifier diagnostic"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_coreir_verify_naked_body' "naked verifier pass"
require_pattern "$BUILD_DRIVER_FILE" 'fn_decl_is_naked' "AST naked attribute source"
require_pattern "$BUILD_DRIVER_FILE" 'CORE_FUNCTION_FLAG_NAKED' "AST naked attribute frozen into function flags"

tmp_dir="$(mktemp -d /tmp/uya-coreir-naked.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn naked_arena() CompilerArena {
    return CompilerArena{
        buffer: null,
        size: 0usize,
        offset: 0usize,
        first_chunk: null,
        current_chunk: null,
        total_allocated: 0usize,
        peak_allocated: 0usize,
    };
}

fn naked_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn naked_lowered_value() LoweredProgram {
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
        functions: naked_vec(),
        body_ops: naked_vec(),
        core_bodies: naked_vec(),
        core_stmts: naked_vec(),
        core_exprs: naked_vec(),
        core_places: naked_vec(),
        core_cleanup_edges: naked_vec(),
        core_semantic_facts: naked_vec(),
        globals: naked_vec(),
        types: naked_vec(),
        interfaces: naked_vec(),
        err_unions: naked_vec(),
        async_frames: naked_vec(),
        drop_defer_plans: naked_vec(),
        helpers: naked_vec(),
        worklist: naked_vec(),
    };
}

fn naked_capability_fact(fact_id: CoreSemanticFactId, capability_id: i32) CoreSemanticFact {
    return CoreSemanticFact{
        fact_id: fact_id,
        kind: CORE_SEMANTIC_FACT_CAPABILITY,
        body_id: 0,
        stmt_id: CORE_STMT_INVALID_ID,
        expr_id: CORE_EXPR_INVALID_ID,
        source_expr_id: TYPED_PROGRAM_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_id: CORE_CLEANUP_EDGE_INVALID_ID,
        call_target_kind: TYPED_CALL_TARGET_UNKNOWN,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        target_symbol_id: TYPED_PROGRAM_INVALID_ID,
        mono_instance_id: TYPED_PROGRAM_INVALID_ID,
        arg_count: 0,
        receiver_type_id: TYPED_PROGRAM_INVALID_ID,
        method_symbol_id: TYPED_PROGRAM_INVALID_ID,
        interface_symbol_id: TYPED_PROGRAM_INVALID_ID,
        vtable_slot: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        type_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        proof_status: TYPED_PROOF_UNKNOWN,
        proof_error_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 900 + fact_id,
        drop_defer_plan_id: TYPED_PROGRAM_INVALID_ID,
        cleanup_scope_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: capability_id,
        flags: 0,
    };
}

fn append_naked_function(lowered: &LoweredProgram, mode: i32) !void {
    var flags: i32 = CORE_FUNCTION_FLAG_NAKED;
    if mode == 8 {
        flags = 0;
    }
    var func: ConcreteFunction = ConcreteFunction{
        function_id: 11,
        decl_id: 12,
        mono_instance_id: TYPED_PROGRAM_INVALID_ID,
        body_start: 0,
        body_count: 1,
        flags: flags,
    };
    try assert_eq_i32(lowered_program_append_function(lowered, &func), 0);
}

fn append_naked_stmt(lowered: &LoweredProgram, mode: i32) !void {
    var kind: i32 = CORE_STMT_KIND_ASM;
    var flags: i32 = 0;
    if mode == 1 {
        kind = CORE_STMT_KIND_RETURN;
    }
    if mode == 12 {
        kind = CORE_STMT_KIND_DEFER;
    }
    if mode == 13 {
        kind = CORE_STMT_KIND_ERRDEFER;
    }
    if mode == 17 {
        kind = CORE_STMT_KIND_DROP;
    }
    if mode == 18 {
        kind = CORE_STMT_KIND_ERROR_PROPAGATION;
    }
    if mode == 5 {
        flags = CORE_STMT_FLAG_ERROR_PROPAGATION;
    }
    if mode == 7 {
        flags = CORE_STMT_FLAG_DROP;
    }
    if mode == 11 {
        flags = CORE_STMT_FLAG_LOCAL_STACK_SLOT;
    }
    var cleanup_count: i32 = 0;
    if mode == 3 {
        cleanup_count = 1;
    }
    var stmt: CoreStmt = CoreStmt{
        stmt_id: 0,
        kind: kind,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: cleanup_count,
        source_span_id: 501,
        cleanup_scope_id: TYPED_PROGRAM_INVALID_ID,
        flags: flags,
    };
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
}

fn append_naked_place(lowered: &LoweredProgram, mode: i32) !void {
    if mode != 2 {
        return;
    }
    var place: CorePlace = CorePlace{
        place_id: 0,
        kind: CORE_PLACE_KIND_FIELD,
        body_id: 0,
        source_expr_id: TYPED_PROGRAM_INVALID_ID,
        type_id: 77,
        base_place_id: CORE_PLACE_INVALID_ID,
        index_expr_id: CORE_EXPR_INVALID_ID,
        field_id: 301,
        symbol_id: 302,
        source_span_id: 502,
        flags: CORE_PLACE_FLAG_STACK_SLOT,
    };
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place), 0);
}

fn append_naked_expr(lowered: &LoweredProgram, mode: i32) !void {
    if mode != 9 {
        return;
    }
    var expr: CoreExpr = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 0,
        source_expr_id: 7,
        type_id: 77,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 503,
        flags: CORE_EXPR_FLAG_ERROR_PROPAGATION,
    };
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
}

fn append_naked_cleanup(lowered: &LoweredProgram, mode: i32) !void {
    if mode != 3 {
        return;
    }
    var edge: CoreCleanupEdge = CoreCleanupEdge{
        edge_id: 0,
        kind: CORE_CLEANUP_EDGE_KIND_RETURN,
        body_id: 0,
        from_stmt_id: 0,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 601,
        drop_defer_plan_id: 701,
        payload_expr_id: CORE_EXPR_INVALID_ID,
        source_span_id: 504,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge), 0);
}

fn append_naked_facts(lowered: &LoweredProgram, mode: i32) !void {
    var naked_fact: CoreSemanticFact = naked_capability_fact(0, CORE_CAPABILITY_NAKED_FUNCTION);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &naked_fact), 0);
    if mode == 4 {
        return;
    }
    var asm_fact: CoreSemanticFact = naked_capability_fact(1, CORE_CAPABILITY_INLINE_ASM);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &asm_fact), 0);
}

fn append_naked_body(lowered: &LoweredProgram, mode: i32) !void {
    var body_flags: i32 = CORE_BODY_FLAG_SOURCE_BODY | CORE_BODY_FLAG_NAKED;
    if mode == 6 {
        body_flags = body_flags | CORE_BODY_FLAG_IMPLICIT_RETURN;
    }
    if mode == 10 {
        body_flags = body_flags | CORE_BODY_FLAG_ASYNC;
    }
    if mode == 14 {
        body_flags = body_flags | CORE_BODY_FLAG_CLEANUP;
    }
    if mode == 15 {
        body_flags = body_flags | CORE_BODY_FLAG_DROP;
    }
    if mode == 16 {
        body_flags = body_flags | CORE_BODY_FLAG_ERROR_PROPAGATION;
    }
    var root_count: i32 = 1;
    if mode == 6 {
        root_count = 0;
    }
    var place_count: i32 = 0;
    if mode == 2 {
        place_count = 1;
    }
    var cleanup_count: i32 = 0;
    if mode == 3 {
        cleanup_count = 1;
    }
    var expr_count: i32 = 0;
    if mode == 9 {
        expr_count = 1;
    }
    var fact_count: i32 = 2;
    if mode == 4 {
        fact_count = 1;
    }
    var body: CoreBody = CoreBody{
        body_id: 0,
        function_id: 11,
        decl_id: 12,
        root_stmt_start: 0,
        root_stmt_count: root_count,
        expr_start: 0,
        expr_count: expr_count,
        place_start: 0,
        place_count: place_count,
        cleanup_edge_start: 0,
        cleanup_edge_count: cleanup_count,
        semantic_fact_start: 0,
        semantic_fact_count: fact_count,
        source_span_id: 500,
        flags: body_flags,
    };
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    if root_count > 0 {
        try append_naked_stmt(lowered, mode);
    }
    try append_naked_expr(lowered, mode);
    try append_naked_place(lowered, mode);
    try append_naked_cleanup(lowered, mode);
    try append_naked_facts(lowered, mode);
}

fn expect_naked_verify(mode: i32, expected_result: i32) !void {
    var arena_buf: [byte: 8192] = [];
    var arena: CompilerArena = naked_arena();
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);
    var lowered: LoweredProgram = naked_lowered_value();
    lowered_program_init(&lowered, &arena);
    try append_naked_function(&lowered, mode);
    try append_naked_body(&lowered, mode);
    var result: CoreVerifierResult = CoreVerifierResult{
        ok: 0,
        error_code: COREIR_VERIFY_OK,
        body_id: CORE_BODY_INVALID_ID,
        stmt_id: CORE_STMT_INVALID_ID,
        expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_id: CORE_CLEANUP_EDGE_INVALID_ID,
        fact_id: CORE_SEMANTIC_FACT_INVALID_ID,
        source_span_id: TYPED_PROGRAM_INVALID_ID,
    };
    try assert_eq_i32(lowered_program_verify_coreir_result(&lowered, &result), expected_result);
    if expected_result == 0 {
        try assert_eq_i32(result.error_code, COREIR_VERIFY_OK);
    } else {
        try assert_eq_i32(result.error_code, COREIR_VERIFY_ERR_NAKED_BODY);
    }
    lowered_program_release(&lowered);
}

test "CoreIR accepts asm-only naked body with frozen flags and capabilities" {
    try expect_naked_verify(0, 0);
}

test "CoreIR rejects non asm-only naked body and ordinary stack slots" {
    try expect_naked_verify(1, -1);
    try expect_naked_verify(2, -1);
    try expect_naked_verify(11, -1);
}

test "CoreIR rejects naked defer drop async error propagation and implicit return" {
    try expect_naked_verify(3, -1);
    try expect_naked_verify(12, -1);
    try expect_naked_verify(13, -1);
    try expect_naked_verify(14, -1);
    try expect_naked_verify(7, -1);
    try expect_naked_verify(15, -1);
    try expect_naked_verify(17, -1);
    try expect_naked_verify(10, -1);
    try expect_naked_verify(5, -1);
    try expect_naked_verify(9, -1);
    try expect_naked_verify(16, -1);
    try expect_naked_verify(18, -1);
    try expect_naked_verify(6, -1);
}

test "CoreIR rejects naked body without capabilities or frozen function flag" {
    try expect_naked_verify(4, -1);
    try expect_naked_verify(8, -1);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --project-root "$tmp_dir")

echo "OK: CoreIR naked function contract verified"
