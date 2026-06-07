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
        echo "错误: CoreIR verifier 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+CoreVerifierResult' "Core verifier 结果结构"
require_pattern "$LOWER_CORE_FILE" 'COREIR_VERIFY_ERR_MISSING_CORE_BODY' "缺失 CoreBody 诊断码"
require_pattern "$LOWER_CORE_FILE" 'COREIR_VERIFY_ERR_UNFROZEN_CALL' "未冻结 call target 诊断码"
require_pattern "$LOWER_CORE_FILE" 'COREIR_VERIFY_ERR_INCOMPLETE_CLEANUP' "cleanup path 不完整诊断码"
require_pattern "$LOWER_CORE_FILE" 'COREIR_VERIFY_ERR_CAPABILITY_SEMANTICS' "capability 语义污染诊断码"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_verify_coreir_result' "带诊断的 CoreIR verifier API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_verify_coreir' "CoreIR verifier 便捷 API"

tmp_dir="$(mktemp -d /tmp/uya-coreir-verifier.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn core_verify_arena() CompilerArena {
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

fn append_core_verify_function(lowered: &LoweredProgram) !void {
    var func: ConcreteFunction = ConcreteFunction{
        function_id: 11,
        decl_id: 12,
        mono_instance_id: TYPED_PROGRAM_INVALID_ID,
        body_start: 0,
        body_count: 1,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_function(lowered, &func), 0);
}

fn core_verify_fact(body_id: CoreBodyId, fact_id: CoreSemanticFactId, kind: i32) CoreSemanticFact {
    return CoreSemanticFact{
        fact_id: fact_id,
        kind: kind,
        body_id: body_id,
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

fn append_core_verify_body(lowered: &LoweredProgram, mode: i32) !void {
    var fact_count: i32 = 6;
    if mode == 4 {
        fact_count = 5;
    }
    var body: CoreBody = CoreBody{
        body_id: 0,
        function_id: 11,
        decl_id: 12,
        root_stmt_start: 0,
        root_stmt_count: 1,
        expr_start: 0,
        expr_count: 1,
        place_start: 0,
        place_count: 1,
        cleanup_edge_start: 0,
        cleanup_edge_count: 1,
        semantic_fact_start: 0,
        semantic_fact_count: fact_count,
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
    var expr: CoreExpr = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 0,
        source_expr_id: 7,
        type_id: TYPED_PROGRAM_INVALID_ID,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 0,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: 801,
        source_span_id: 701,
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
        field_id: TYPED_PROGRAM_INVALID_ID,
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
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place), 0);
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge), 0);

    var type_fact: CoreSemanticFact = core_verify_fact(0, 0, CORE_SEMANTIC_FACT_TYPE_ID);
    type_fact.expr_id = 0;
    type_fact.type_id = 77;
    if mode == 1 {
        type_fact.type_id = TYPED_PROGRAM_INVALID_ID;
    }
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &type_fact), 0);

    var call_fact: CoreSemanticFact = core_verify_fact(0, 1, CORE_SEMANTIC_FACT_RESOLVED_CALL);
    call_fact.expr_id = 0;
    call_fact.call_target_kind = TYPED_CALL_TARGET_FUNCTION;
    call_fact.target_function_id = 101;
    call_fact.target_decl_id = 102;
    call_fact.target_symbol_id = 103;
    if mode == 2 {
        call_fact.call_target_kind = TYPED_CALL_TARGET_UNKNOWN;
        call_fact.target_function_id = TYPED_PROGRAM_INVALID_ID;
        call_fact.target_decl_id = TYPED_PROGRAM_INVALID_ID;
        call_fact.target_symbol_id = TYPED_PROGRAM_INVALID_ID;
    }
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &call_fact), 0);

    var field_fact: CoreSemanticFact = core_verify_fact(0, 2, CORE_SEMANTIC_FACT_FIELD_ID);
    field_fact.expr_id = 0;
    field_fact.place_id = 0;
    field_fact.field_id = 301;
    if mode == 3 {
        field_fact.field_id = TYPED_PROGRAM_INVALID_ID;
    }
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &field_fact), 0);

    var proof_fact: CoreSemanticFact = core_verify_fact(0, 3, CORE_SEMANTIC_FACT_PROOF_RESULT);
    proof_fact.expr_id = 0;
    proof_fact.proof_result_id = 401;
    proof_fact.proof_status = TYPED_PROOF_OK;
    if mode == 6 {
        proof_fact.proof_status = TYPED_PROOF_UNKNOWN;
    }
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &proof_fact), 0);

    if mode != 4 {
        var cleanup_fact: CoreSemanticFact = core_verify_fact(0, 4, CORE_SEMANTIC_FACT_CLEANUP);
        cleanup_fact.stmt_id = 0;
        cleanup_fact.expr_id = 0;
        cleanup_fact.cleanup_edge_id = 0;
        cleanup_fact.drop_defer_plan_id = 901;
        cleanup_fact.cleanup_scope_id = 601;
        try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &cleanup_fact), 0);
    }

    var capability_fact: CoreSemanticFact = core_verify_fact(0, 5, CORE_SEMANTIC_FACT_CAPABILITY);
    capability_fact.expr_id = 0;
    capability_fact.capability_id = 801;
    if mode == 5 {
        capability_fact.type_id = 77;
    }
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &capability_fact), 0);
}

fn make_core_verify_program(lowered: &LoweredProgram, arena: &CompilerArena, mode: i32) !void {
    lowered_program_init(lowered, arena);
    try append_core_verify_function(lowered);
    if mode != 7 {
        try append_core_verify_body(lowered, mode);
    }
}

fn expect_core_verify(mode: i32, expected_result: i32, expected_code: i32) !void {
    var arena_buf: [byte: 8192] = [];
    var arena: CompilerArena = core_verify_arena();
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);
    var lowered: LoweredProgram = LoweredProgram{
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
        functions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        body_ops: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        core_bodies: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        core_stmts: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        core_exprs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        core_places: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        core_cleanup_edges: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        core_semantic_facts: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        globals: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        types: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        interfaces: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        err_unions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        async_frames: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        drop_defer_plans: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        helpers: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        worklist: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    try make_core_verify_program(&lowered, &arena, mode);
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
    try assert_eq_i32(result.error_code, expected_code);
    try assert_eq_i32(lowered_program_verify_coreir(&lowered), expected_result);
    lowered_program_release(&lowered);
}

test "CoreIR verifier accepts fully frozen CoreBody metadata" {
    try expect_core_verify(0, 0, COREIR_VERIFY_OK);
}

test "CoreIR verifier rejects missing concrete function CoreBody" {
    try expect_core_verify(7, -1, COREIR_VERIFY_ERR_MISSING_CORE_BODY);
}

test "CoreIR verifier rejects unfrozen type call field and proof metadata" {
    try expect_core_verify(1, -1, COREIR_VERIFY_ERR_UNFROZEN_TYPE);
    try expect_core_verify(2, -1, COREIR_VERIFY_ERR_UNFROZEN_CALL);
    try expect_core_verify(3, -1, COREIR_VERIFY_ERR_UNFROZEN_FIELD);
    try expect_core_verify(6, -1, COREIR_VERIFY_ERR_UNFROZEN_PROOF);
}

test "CoreIR verifier rejects incomplete cleanup and capability semantic pollution" {
    try expect_core_verify(4, -1, COREIR_VERIFY_ERR_INCOMPLETE_CLEANUP);
    try expect_core_verify(5, -1, COREIR_VERIFY_ERR_CAPABILITY_SEMANTICS);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --project-root "$tmp_dir")

echo "✓ CoreIR verifier contract verified"
