#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
COREIR_DOC="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: CoreIR C99 oracle boundary missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$COREIR_DOC" "$ARCH_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'COREIR_VERIFY_ERR_UNDUMPED_BODY_SEMANTIC' "verifier error for body semantics without CoreBody dump/verifier contract"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_coreir_stmt_kind_is_dumped_and_verified' "CoreStmt kind dump/verifier gate"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_coreir_expr_kind_is_dumped_and_verified' "CoreExpr kind dump/verifier gate"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_coreir_place_kind_is_dumped_and_verified' "CorePlace kind dump/verifier gate"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_coreir_cleanup_kind_is_dumped_and_verified' "CoreCleanupEdge kind dump/verifier gate"
require_pattern "$COREIR_DOC" 'C99 可以继续直接消费 `LoweredProgram` 作为 oracle' "C99 oracle remains allowed"
require_pattern "$COREIR_DOC" '新增的完整函数体语义必须先进入 `CoreBody` dump 和 verifier' "new body semantics must land in CoreBody first"
require_pattern "$ARCH_DOC" '新增完整函数体语义不得只接入 C99 oracle' "architecture records no C99-only body semantics"

tmp_dir="$(mktemp -d /tmp/uya-coreir-c99-oracle.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn oracle_boundary_arena() CompilerArena {
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

fn oracle_boundary_empty_program() LoweredProgram {
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
}

fn oracle_boundary_cleanup_fact() CoreSemanticFact {
    return CoreSemanticFact{
        fact_id: 0,
        kind: CORE_SEMANTIC_FACT_CLEANUP,
        body_id: 0,
        stmt_id: 0,
        expr_id: 0,
        source_expr_id: 7,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_id: 0,
        call_target_kind: TYPED_CALL_TARGET_UNKNOWN,
        target_function_id: TYPED_PROGRAM_INVALID_ID,
        target_decl_id: TYPED_PROGRAM_INVALID_ID,
        target_symbol_id: TYPED_PROGRAM_INVALID_ID,
        mono_instance_id: TYPED_PROGRAM_INVALID_ID,
        receiver_type_id: TYPED_PROGRAM_INVALID_ID,
        method_symbol_id: TYPED_PROGRAM_INVALID_ID,
        interface_symbol_id: TYPED_PROGRAM_INVALID_ID,
        vtable_slot: TYPED_PROGRAM_INVALID_ID,
        field_id: TYPED_PROGRAM_INVALID_ID,
        type_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        proof_status: TYPED_PROOF_UNKNOWN,
        proof_error_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 703,
        drop_defer_plan_id: 901,
        cleanup_scope_id: 601,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        flags: 0,
    };
}

fn append_oracle_boundary_program(lowered: &LoweredProgram, mode: i32) !void {
    var func: ConcreteFunction = ConcreteFunction{
        function_id: 11,
        decl_id: 12,
        mono_instance_id: TYPED_PROGRAM_INVALID_ID,
        body_start: 0,
        body_count: 1,
        flags: 0,
    };
    var cleanup_count: i32 = 0;
    var fact_count: i32 = 0;
    if mode == 4 {
        cleanup_count = 1;
        fact_count = 1;
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
        cleanup_edge_count: cleanup_count,
        semantic_fact_start: 0,
        semantic_fact_count: fact_count,
        source_span_id: 500,
        flags: CORE_BODY_FLAG_SOURCE_BODY,
    };
    var stmt_kind: i32 = CORE_STMT_KIND_RETURN;
    var expr_kind: i32 = CORE_EXPR_KIND_CALL;
    var place_kind: i32 = CORE_PLACE_KIND_FIELD;
    var cleanup_kind: i32 = CORE_CLEANUP_EDGE_KIND_RETURN;
    if mode == 1 { stmt_kind = 777; }
    if mode == 2 { expr_kind = 777; }
    if mode == 3 { place_kind = 777; }
    if mode == 4 { cleanup_kind = 777; }
    var stmt: CoreStmt = CoreStmt{
        stmt_id: 0,
        kind: stmt_kind,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 0,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: cleanup_count,
        source_span_id: 501,
        cleanup_scope_id: 601,
        flags: 0,
    };
    var expr: CoreExpr = CoreExpr{
        expr_id: 0,
        kind: expr_kind,
        body_id: 0,
        source_expr_id: 7,
        type_id: 77,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 0,
        target_function_id: 101,
        target_decl_id: 102,
        field_id: TYPED_PROGRAM_INVALID_ID,
        proof_result_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 701,
        flags: 0,
    };
    var place: CorePlace = CorePlace{
        place_id: 0,
        kind: place_kind,
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
        kind: cleanup_kind,
        body_id: 0,
        from_stmt_id: 0,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 601,
        drop_defer_plan_id: 901,
        payload_expr_id: 0,
        source_span_id: 703,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_function(lowered, &func), 0);
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place), 0);
    if mode == 4 {
        var fact: CoreSemanticFact = oracle_boundary_cleanup_fact();
        try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge), 0);
        try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &fact), 0);
    }
}

fn expect_oracle_boundary(mode: i32, expected_result: i32, expected_code: i32) !void {
    var arena_buf: [byte: 8192] = [];
    var arena: CompilerArena = oracle_boundary_arena();
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);
    var lowered: LoweredProgram = oracle_boundary_empty_program();
    lowered_program_init(&lowered, &arena);
    try append_oracle_boundary_program(&lowered, mode);
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
    lowered_program_release(&lowered);
}

test "C99 oracle can keep consuming LoweredProgram while known CoreBody semantics verify" {
    try expect_oracle_boundary(0, 0, COREIR_VERIFY_OK);
}

test "new full body semantics must first be dumped and verified in CoreBody" {
    try expect_oracle_boundary(1, -1, COREIR_VERIFY_ERR_UNDUMPED_BODY_SEMANTIC);
    try expect_oracle_boundary(2, -1, COREIR_VERIFY_ERR_UNDUMPED_BODY_SEMANTIC);
    try expect_oracle_boundary(3, -1, COREIR_VERIFY_ERR_UNDUMPED_BODY_SEMANTIC);
    try expect_oracle_boundary(4, -1, COREIR_VERIFY_ERR_UNDUMPED_BODY_SEMANTIC);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --project-root "$tmp_dir")

echo "OK: CoreIR C99 oracle boundary verified"
