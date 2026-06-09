#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

tmp_dir="$(mktemp -d /tmp/uya-coreir-dump-golden.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn coreir_dump_golden_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn coreir_dump_golden_program() LoweredProgram {
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
        functions: coreir_dump_golden_vec(),
        body_ops: coreir_dump_golden_vec(),
        core_bodies: coreir_dump_golden_vec(),
        core_stmts: coreir_dump_golden_vec(),
        core_exprs: coreir_dump_golden_vec(),
        core_places: coreir_dump_golden_vec(),
        core_cleanup_edges: coreir_dump_golden_vec(),
        core_semantic_facts: coreir_dump_golden_vec(),
        globals: coreir_dump_golden_vec(),
        types: coreir_dump_golden_vec(),
        interfaces: coreir_dump_golden_vec(),
        err_unions: coreir_dump_golden_vec(),
        async_frames: coreir_dump_golden_vec(),
        drop_defer_plans: coreir_dump_golden_vec(),
        helpers: coreir_dump_golden_vec(),
        worklist: coreir_dump_golden_vec(),
    };
}

fn coreir_dump_golden_fact(fact_id: CoreSemanticFactId, kind: i32) CoreSemanticFact {
    return CoreSemanticFact{
        fact_id: fact_id,
        kind: kind,
        body_id: 0,
        stmt_id: CORE_STMT_INVALID_ID,
        expr_id: CORE_EXPR_INVALID_ID,
        source_expr_id: 7,
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
        source_span_id: 700 + fact_id,
        drop_defer_plan_id: TYPED_PROGRAM_INVALID_ID,
        cleanup_scope_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        flags: 0,
    };
}

fn append_coreir_dump_golden_fixture(lowered: &LoweredProgram) !void {
    var body: CoreBody = CoreBody{
        body_id: 0,
        function_id: 11,
        decl_id: 12,
        root_stmt_start: 0,
        root_stmt_count: 2,
        expr_start: 0,
        expr_count: 2,
        place_start: 0,
        place_count: 1,
        cleanup_edge_start: 0,
        cleanup_edge_count: 1,
        semantic_fact_start: 0,
        semantic_fact_count: 4,
        source_span_id: 500,
        flags: CORE_BODY_FLAG_SOURCE_BODY,
    };
    var stmt: CoreStmt = CoreStmt{
        stmt_id: 0,
        kind: CORE_STMT_KIND_RETURN,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 0,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: 1,
        source_span_id: 501,
        cleanup_scope_id: 601,
        flags: 0,
    };
    var assign_stmt: CoreStmt = CoreStmt{
        stmt_id: 1,
        kind: CORE_STMT_KIND_ASSIGN,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 1,
        place_id: 0,
        cleanup_edge_start: CORE_CLEANUP_EDGE_INVALID_ID,
        cleanup_edge_count: 0,
        source_span_id: 502,
        cleanup_scope_id: TYPED_PROGRAM_INVALID_ID,
        flags: 0,
    };
    var expr: CoreExpr = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 0,
        source_expr_id: 7,
        type_id: 77,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 0,
        target_function_id: 101,
        target_decl_id: 102,
        field_id: 301,
        proof_result_id: 401,
        capability_id: 801,
        source_span_id: 701,
        flags: 0,
    };
    var zero_expr: CoreExpr = CoreExpr{
        expr_id: 1,
        kind: CORE_EXPR_KIND_INT_LITERAL,
        body_id: 0,
        source_expr_id: 8,
        type_id: 77,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 704,
        flags: 0,
    };
    var place: CorePlace = CorePlace{
        place_id: 0,
        kind: CORE_PLACE_KIND_FIELD,
        body_id: 0,
        source_expr_id: 7,
        type_id: 77,
        base_place_id: CORE_PLACE_INVALID_ID,
        index_expr_id: CORE_EXPR_INVALID_ID,
        field_id: 301,
        symbol_id: 302,
        source_span_id: 702,
        flags: 0,
    };
    var edge: CoreCleanupEdge = CoreCleanupEdge{
        edge_id: 0,
        kind: CORE_CLEANUP_EDGE_KIND_RETURN,
        body_id: 0,
        from_stmt_id: 0,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 601,
        drop_defer_plan_id: 901,
        payload_expr_id: 0,
        source_span_id: 703,
        flags: 5,
    };
    var call_fact: CoreSemanticFact = coreir_dump_golden_fact(0, CORE_SEMANTIC_FACT_RESOLVED_CALL);
    call_fact.expr_id = 0;
    call_fact.call_target_kind = TYPED_CALL_TARGET_FUNCTION;
    call_fact.target_function_id = 101;
    call_fact.target_decl_id = 102;
    call_fact.target_symbol_id = 103;
    call_fact.mono_instance_id = 104;
    call_fact.type_id = 77;
    call_fact.proof_result_id = 401;
    call_fact.proof_status = TYPED_PROOF_OK;
    call_fact.capability_id = 801;

    var field_fact: CoreSemanticFact = coreir_dump_golden_fact(1, CORE_SEMANTIC_FACT_FIELD_ID);
    field_fact.expr_id = 0;
    field_fact.place_id = 0;
    field_fact.field_id = 301;

    var cleanup_fact: CoreSemanticFact = coreir_dump_golden_fact(2, CORE_SEMANTIC_FACT_CLEANUP);
    cleanup_fact.stmt_id = 0;
    cleanup_fact.expr_id = 0;
    cleanup_fact.cleanup_edge_id = 0;
    cleanup_fact.drop_defer_plan_id = 901;
    cleanup_fact.cleanup_scope_id = 601;

    var capability_fact: CoreSemanticFact = coreir_dump_golden_fact(3, CORE_SEMANTIC_FACT_CAPABILITY);
    capability_fact.expr_id = 0;
    capability_fact.capability_id = 801;

    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &assign_stmt), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &zero_expr), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place), 0);
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &call_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &field_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &cleanup_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &capability_fact), 0);
}

test "coreir dump matches stable golden text" {
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

    var lowered: LoweredProgram = coreir_dump_golden_program();
    lowered_program_init(&lowered, &arena);
    try append_coreir_dump_golden_fixture(&lowered);
    lowered_program_maybe_dump_coreir(&lowered);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}

fn append_coreir_dump_surface_functions(lowered: &LoweredProgram) !void {
    var file0_fn: ConcreteFunction = ConcreteFunction{
        function_id: 210,
        decl_id: 310,
        mono_instance_id: 910,
        body_start: 0,
        body_count: 1,
        flags: 0,
    };
    var file1_fn: ConcreteFunction = ConcreteFunction{
        function_id: 211,
        decl_id: 311,
        mono_instance_id: 911,
        body_start: 1,
        body_count: 1,
        flags: 0,
    };
    var naked_fn: ConcreteFunction = ConcreteFunction{
        function_id: 212,
        decl_id: 312,
        mono_instance_id: 912,
        body_start: 2,
        body_count: 1,
        flags: CORE_FUNCTION_FLAG_NAKED,
    };
    try assert_eq_i32(lowered_program_append_function(lowered, &file0_fn), 0);
    try assert_eq_i32(lowered_program_append_function(lowered, &file1_fn), 0);
    try assert_eq_i32(lowered_program_append_function(lowered, &naked_fn), 0);
}

fn append_coreir_dump_surface_fixture(lowered: &LoweredProgram) !void {
    try append_coreir_dump_surface_functions(lowered);
    var body0: CoreBody = CoreBody{
        body_id: 0,
        function_id: 210,
        decl_id: 310,
        root_stmt_start: 0,
        root_stmt_count: 2,
        expr_start: 0,
        expr_count: 4,
        place_start: 0,
        place_count: 3,
        cleanup_edge_start: 0,
        cleanup_edge_count: 1,
        semantic_fact_start: 0,
        semantic_fact_count: 4,
        source_span_id: 900,
        flags: CORE_BODY_FLAG_SOURCE_BODY,
    };
    var body1: CoreBody = CoreBody{
        body_id: 1,
        function_id: 211,
        decl_id: 311,
        root_stmt_start: 2,
        root_stmt_count: 2,
        expr_start: 4,
        expr_count: 4,
        place_start: 3,
        place_count: 0,
        cleanup_edge_start: 1,
        cleanup_edge_count: 1,
        semantic_fact_start: 4,
        semantic_fact_count: 4,
        source_span_id: 1900,
        flags: CORE_BODY_FLAG_SOURCE_BODY | CORE_BODY_FLAG_DROP | CORE_BODY_FLAG_ERROR_PROPAGATION,
    };
    var body2: CoreBody = CoreBody{
        body_id: 2,
        function_id: 212,
        decl_id: 312,
        root_stmt_start: 4,
        root_stmt_count: 1,
        expr_start: 8,
        expr_count: 0,
        place_start: 3,
        place_count: 0,
        cleanup_edge_start: 2,
        cleanup_edge_count: 0,
        semantic_fact_start: 8,
        semantic_fact_count: 2,
        source_span_id: 2900,
        flags: CORE_BODY_FLAG_SOURCE_BODY | CORE_BODY_FLAG_NAKED,
    };
    var stmt0: CoreStmt = CoreStmt{
        stmt_id: 0,
        kind: CORE_STMT_KIND_RETURN,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 0,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: 0,
        source_span_id: 901,
        cleanup_scope_id: 0,
        flags: 0,
    };
    var stmt1: CoreStmt = CoreStmt{
        stmt_id: 1,
        kind: CORE_STMT_KIND_DEFER,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 1,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: 1,
        source_span_id: 902,
        cleanup_scope_id: 601,
        flags: CORE_STMT_FLAG_CLEANUP,
    };
    var stmt2: CoreStmt = CoreStmt{
        stmt_id: 2,
        kind: CORE_STMT_KIND_DROP,
        body_id: 1,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 5,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 1,
        cleanup_edge_count: 0,
        source_span_id: 1901,
        cleanup_scope_id: 1601,
        flags: CORE_STMT_FLAG_DROP,
    };
    var stmt3: CoreStmt = CoreStmt{
        stmt_id: 3,
        kind: CORE_STMT_KIND_ERROR_PROPAGATION,
        body_id: 1,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 4,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 1,
        cleanup_edge_count: 1,
        source_span_id: 1902,
        cleanup_scope_id: 1602,
        flags: CORE_STMT_FLAG_ERROR_PROPAGATION,
    };
    var stmt4: CoreStmt = CoreStmt{
        stmt_id: 4,
        kind: CORE_STMT_KIND_ASM,
        body_id: 2,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 2,
        cleanup_edge_count: 0,
        source_span_id: 2901,
        cleanup_scope_id: TYPED_PROGRAM_INVALID_ID,
        flags: 0,
    };
    var expr0: CoreExpr = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 0,
        source_expr_id: 100,
        type_id: 1000,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 0,
        target_function_id: 1001,
        target_decl_id: 1002,
        field_id: 1200,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 903,
        flags: 0,
    };
    var expr1: CoreExpr = CoreExpr{
        expr_id: 1,
        kind: CORE_EXPR_KIND_INDEX,
        body_id: 0,
        source_expr_id: 101,
        type_id: 1003,
        literal_i64: 0i64,
        lhs_expr_id: 0,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 1,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 904,
        flags: 0,
    };
    var expr2: CoreExpr = CoreExpr{
        expr_id: 2,
        kind: CORE_EXPR_KIND_SLICE,
        body_id: 0,
        source_expr_id: 102,
        type_id: 1004,
        literal_i64: 0i64,
        lhs_expr_id: 1,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 2,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 905,
        flags: 0,
    };
    var expr3: CoreExpr = CoreExpr{
        expr_id: 3,
        kind: CORE_EXPR_KIND_ATOMIC,
        body_id: 0,
        source_expr_id: 103,
        type_id: 1005,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 906,
        flags: 0,
    };
    var expr4: CoreExpr = CoreExpr{
        expr_id: 4,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 1,
        source_expr_id: 200,
        type_id: 2000,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: 4815,
        target_decl_id: 4816,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 1903,
        flags: CORE_EXPR_FLAG_ERROR_PROPAGATION,
    };
    var expr5: CoreExpr = CoreExpr{
        expr_id: 5,
        kind: CORE_EXPR_KIND_VECTOR,
        body_id: 1,
        source_expr_id: 201,
        type_id: 2001,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 1904,
        flags: 0,
    };
    var expr6: CoreExpr = CoreExpr{
        expr_id: 6,
        kind: CORE_EXPR_KIND_MASK,
        body_id: 1,
        source_expr_id: 202,
        type_id: 2002,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 1905,
        flags: 0,
    };
    var expr7: CoreExpr = CoreExpr{
        expr_id: 7,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 1,
        source_expr_id: 203,
        type_id: 2003,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: 2101,
        target_decl_id: 2102,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 1906,
        flags: 0,
    };
    var place0: CorePlace = CorePlace{
        place_id: 0,
        kind: CORE_PLACE_KIND_FIELD,
        body_id: 0,
        source_expr_id: 100,
        type_id: 1000,
        base_place_id: CORE_PLACE_INVALID_ID,
        index_expr_id: CORE_EXPR_INVALID_ID,
        field_id: 1200,
        symbol_id: 1201,
        source_span_id: 907,
        flags: 0,
    };
    var place1: CorePlace = CorePlace{
        place_id: 1,
        kind: CORE_PLACE_KIND_INDEX,
        body_id: 0,
        source_expr_id: 101,
        type_id: 1003,
        base_place_id: 0,
        index_expr_id: 1,
        field_id: TYPED_PROGRAM_INVALID_ID,
        symbol_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 908,
        flags: 0,
    };
    var place2: CorePlace = CorePlace{
        place_id: 2,
        kind: CORE_PLACE_KIND_SLICE,
        body_id: 0,
        source_expr_id: 102,
        type_id: 1004,
        base_place_id: 0,
        index_expr_id: 2,
        field_id: TYPED_PROGRAM_INVALID_ID,
        symbol_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 909,
        flags: 0,
    };
    var edge0: CoreCleanupEdge = CoreCleanupEdge{
        edge_id: 0,
        kind: CORE_CLEANUP_EDGE_KIND_RETURN,
        body_id: 0,
        from_stmt_id: 1,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 601,
        drop_defer_plan_id: 701,
        payload_expr_id: 1,
        source_span_id: 910,
        flags: 1,
    };
    var edge1: CoreCleanupEdge = CoreCleanupEdge{
        edge_id: 1,
        kind: CORE_CLEANUP_EDGE_KIND_RETURN,
        body_id: 1,
        from_stmt_id: 3,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 1602,
        drop_defer_plan_id: 1702,
        payload_expr_id: 4,
        source_span_id: 1907,
        flags: 2,
    };
    var call_fact: CoreSemanticFact = coreir_dump_golden_fact(0, CORE_SEMANTIC_FACT_RESOLVED_CALL);
    call_fact.expr_id = 0;
    call_fact.call_target_kind = TYPED_CALL_TARGET_FUNCTION;
    call_fact.target_function_id = 1001;
    call_fact.target_decl_id = 1002;
    call_fact.target_symbol_id = 1003;
    call_fact.mono_instance_id = 901;
    call_fact.arg_count = 2;
    call_fact.type_id = 1000;

    var field_fact: CoreSemanticFact = coreir_dump_golden_fact(1, CORE_SEMANTIC_FACT_FIELD_ID);
    field_fact.expr_id = 0;
    field_fact.place_id = 0;
    field_fact.field_id = 1200;

    var type_fact: CoreSemanticFact = coreir_dump_golden_fact(2, CORE_SEMANTIC_FACT_TYPE_ID);
    type_fact.expr_id = 3;
    type_fact.type_id = 1005;

    var defer_fact: CoreSemanticFact = coreir_dump_golden_fact(3, CORE_SEMANTIC_FACT_CLEANUP);
    defer_fact.stmt_id = 1;
    defer_fact.expr_id = 1;
    defer_fact.cleanup_edge_id = 0;
    defer_fact.drop_defer_plan_id = 701;
    defer_fact.cleanup_scope_id = 601;

    var compile_fact: CoreSemanticFact = coreir_dump_golden_fact(4, CORE_SEMANTIC_FACT_RESOLVED_CALL);
    compile_fact.body_id = 1;
    compile_fact.expr_id = 4;
    compile_fact.source_expr_id = 200;
    compile_fact.call_target_kind = TYPED_CALL_TARGET_FUNCTION;
    compile_fact.target_function_id = 4815;
    compile_fact.target_decl_id = 4816;
    compile_fact.target_symbol_id = 4817;
    compile_fact.mono_instance_id = TYPED_PROGRAM_INVALID_ID;
    compile_fact.arg_count = 16;
    compile_fact.type_id = 2000;

    var method_fact: CoreSemanticFact = coreir_dump_golden_fact(5, CORE_SEMANTIC_FACT_METHOD_DISPATCH);
    method_fact.body_id = 1;
    method_fact.expr_id = 7;
    method_fact.source_expr_id = 203;
    method_fact.mono_instance_id = 902;
    method_fact.receiver_type_id = 2100;
    method_fact.method_symbol_id = 2101;
    method_fact.interface_symbol_id = 2102;
    method_fact.vtable_slot = 3;

    var error_fact: CoreSemanticFact = coreir_dump_golden_fact(6, CORE_SEMANTIC_FACT_CLEANUP);
    error_fact.body_id = 1;
    error_fact.stmt_id = 3;
    error_fact.expr_id = 4;
    error_fact.source_expr_id = 200;
    error_fact.cleanup_edge_id = 1;
    error_fact.drop_defer_plan_id = 1702;
    error_fact.cleanup_scope_id = 1602;

    var vector_type_fact: CoreSemanticFact = coreir_dump_golden_fact(7, CORE_SEMANTIC_FACT_TYPE_ID);
    vector_type_fact.body_id = 1;
    vector_type_fact.expr_id = 5;
    vector_type_fact.source_expr_id = 201;
    vector_type_fact.type_id = 2001;

    var naked_fact: CoreSemanticFact = coreir_dump_golden_fact(8, CORE_SEMANTIC_FACT_CAPABILITY);
    naked_fact.body_id = 2;
    naked_fact.source_expr_id = TYPED_PROGRAM_INVALID_ID;
    naked_fact.capability_id = CORE_CAPABILITY_NAKED_FUNCTION;

    var asm_fact: CoreSemanticFact = coreir_dump_golden_fact(9, CORE_SEMANTIC_FACT_CAPABILITY);
    asm_fact.body_id = 2;
    asm_fact.source_expr_id = TYPED_PROGRAM_INVALID_ID;
    asm_fact.capability_id = CORE_CAPABILITY_INLINE_ASM;

    try assert_eq_i32(lowered_program_append_core_body(lowered, &body0), 0);
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body1), 0);
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body2), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt0), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt1), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt2), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt3), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt4), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr0), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr1), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr2), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr3), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr4), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr5), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr6), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr7), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place0), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place1), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place2), 0);
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge0), 0);
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge1), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &call_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &field_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &type_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &defer_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &compile_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &method_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &error_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &vector_type_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &naked_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &asm_fact), 0);
}

test "coreir dump covers broad language surface markers" {
    var arena_buf: [byte: 8192] = [];
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

    var lowered: LoweredProgram = coreir_dump_golden_program();
    lowered_program_init(&lowered, &arena);
    try append_coreir_dump_surface_fixture(&lowered);
    try assert_eq_i32(lowered_program_verify_coreir(&lowered), 0);
    lowered_program_maybe_dump_coreir(&lowered);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

dump_stderr="$tmp_dir/dump.stderr"
actual_golden="$tmp_dir/actual_coreir.txt"
expected_golden="$tmp_dir/expected_coreir.txt"

(cd "$REPO_ROOT" && UYA_DUMP_COREIR=1 ./bin/uya test "$tmp_dir/main.uya" --no-split-c >"$tmp_dir/dump.stdout" 2>"$dump_stderr")

awk '
    /^=== coreir ===$/ { in_dump = 1 }
    in_dump { print }
    /^=== coreir end ===$/ { exit }
' "$dump_stderr" >"$actual_golden"

cat >"$expected_golden" <<'EOF'
=== coreir ===
core_bodies=1 core_stmts=2 core_exprs=2 core_places=1 core_cleanup_edges=1 core_semantic_facts=4
body #0 function=11 decl=12 roots=0+2 exprs=0+2 places=0+1 cleanups=0+1 facts=0+4 source=500 flags=1
stmt #0 body=0 kind=10 parent=-1 children=-1+0 expr=0 place=-1 cleanup=0+1 source=501 scope=601 flags=0
stmt #1 body=0 kind=18 parent=-1 children=-1+0 expr=1 place=0 cleanup=-1+0 source=502 scope=-1 flags=0
expr #0 body=0 kind=11 source_expr=7 type=77 literal=0 lhs=-1 rhs=-1 callee=-1 place=0 target_fn=101 target_decl=102 field=301 proof=401 capability=801 source=701 flags=0
expr #1 body=0 kind=17 source_expr=8 type=77 literal=0 lhs=-1 rhs=-1 callee=-1 place=-1 target_fn=-1 target_decl=-1 field=-1 proof=-1 capability=-1 source=704 flags=0
place #0 body=0 kind=4 source_expr=7 type=77 base=-1 index=-1 field=301 symbol=302 source=702 flags=0
cleanup #0 body=0 kind=2 from=0 to=-1 scope=601 drop_defer=901 payload=0 source=703 flags=5
fact #0 kind=1 body=0 stmt=-1 expr=0 source_expr=7 place=-1 cleanup=-1
  call kind=1 target_fn=101 target_decl=102 target_symbol=103 mono=104 arg_count=0 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=-1 type=77 proof=401 proof_status=1 proof_error=-1 source=700 drop_defer=-1 scope=-1 capability=801 flags=0
fact #1 kind=3 body=0 stmt=-1 expr=0 source_expr=7 place=0 cleanup=-1
  call kind=0 target_fn=-1 target_decl=-1 target_symbol=-1 mono=-1 arg_count=0 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=301 type=-1 proof=-1 proof_status=0 proof_error=-1 source=701 drop_defer=-1 scope=-1 capability=-1 flags=0
fact #2 kind=7 body=0 stmt=0 expr=0 source_expr=7 place=-1 cleanup=0
  call kind=0 target_fn=-1 target_decl=-1 target_symbol=-1 mono=-1 arg_count=0 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=-1 type=-1 proof=-1 proof_status=0 proof_error=-1 source=702 drop_defer=901 scope=601 capability=-1 flags=0
fact #3 kind=8 body=0 stmt=-1 expr=0 source_expr=7 place=-1 cleanup=-1
  call kind=0 target_fn=-1 target_decl=-1 target_symbol=-1 mono=-1 arg_count=0 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=-1 type=-1 proof=-1 proof_status=0 proof_error=-1 source=703 drop_defer=-1 scope=-1 capability=801 flags=0
=== coreir end ===
EOF

if ! diff -u "$expected_golden" "$actual_golden"; then
    echo "error: CoreIR dump golden changed" >&2
    exit 1
fi

if ! grep -Fq "core_bodies=3 core_stmts=5 core_exprs=8 core_places=3 core_cleanup_edges=2 core_semantic_facts=10" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing multi-body table summary" >&2
    exit 1
fi
if ! grep -Fq "body #0 function=210 decl=310 roots=0+2 exprs=0+4 places=0+3 cleanups=0+1 facts=0+4 source=900 flags=1" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing first multi-file body marker" >&2
    exit 1
fi
if ! grep -Fq "body #1 function=211 decl=311 roots=2+2 exprs=4+4 places=3+0 cleanups=1+1 facts=4+4 source=1900 flags=49" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing second multi-file body marker" >&2
    exit 1
fi
if ! grep -Fq "body #2 function=212 decl=312 roots=4+1 exprs=8+0 places=3+0 cleanups=2+0 facts=8+2 source=2900 flags=3" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing naked body flags marker" >&2
    exit 1
fi
if ! grep -Fq "stmt #1 body=0 kind=12" "$dump_stderr" ||
   ! grep -Fq "stmt #2 body=1 kind=14" "$dump_stderr" ||
   ! grep -Fq "stmt #3 body=1 kind=15" "$dump_stderr" ||
   ! grep -Fq "stmt #4 body=2 kind=11" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing defer/drop/error statement markers" >&2
    exit 1
fi
if ! grep -Fq "expr #1 body=0 kind=12" "$dump_stderr" ||
   ! grep -Fq "expr #2 body=0 kind=13" "$dump_stderr" ||
   ! grep -Fq "expr #3 body=0 kind=14" "$dump_stderr" ||
   ! grep -Fq "expr #5 body=1 kind=15" "$dump_stderr" ||
   ! grep -Fq "expr #6 body=1 kind=16" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing index/slice/atomic/vector/mask expression markers" >&2
    exit 1
fi
if ! grep -Fq "place #0 body=0 kind=4" "$dump_stderr" ||
   ! grep -Fq "place #1 body=0 kind=5" "$dump_stderr" ||
   ! grep -Fq "place #2 body=0 kind=6" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing field/index/slice place markers" >&2
    exit 1
fi
if ! grep -Fq "call kind=1 target_fn=1001 target_decl=1002 target_symbol=1003 mono=901 arg_count=2" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing generic function call marker" >&2
    exit 1
fi
if ! grep -Fq "call kind=1 target_fn=4815 target_decl=4816 target_symbol=4817 mono=-1 arg_count=16" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing compile_files 16-argument call marker" >&2
    exit 1
fi
if ! grep -Fq "fact #5 kind=2 body=1" "$dump_stderr" ||
   ! grep -Fq "mono=902 arg_count=0 receiver_type=2100 method_symbol=2101 interface_symbol=2102 slot=3" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing generic method interface dispatch marker" >&2
    exit 1
fi
if ! grep -Fq "fact #8 kind=8 body=2" "$dump_stderr" ||
   ! grep -Fq "source=708 drop_defer=-1 scope=-1 capability=2 flags=0" "$dump_stderr" ||
   ! grep -Fq "fact #9 kind=8 body=2" "$dump_stderr" ||
   ! grep -Fq "source=709 drop_defer=-1 scope=-1 capability=1 flags=0" "$dump_stderr"; then
    echo "error: CoreIR surface dump missing naked capability markers" >&2
    exit 1
fi

echo "OK: CoreIR dump golden verified"
