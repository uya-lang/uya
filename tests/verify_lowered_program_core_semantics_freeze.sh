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
        echo "错误: Core semantics freeze 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_freeze_core_body_semantics_from_typed' "单个 CoreBody freeze API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_freeze_core_semantics_from_typed' "全部 CoreBody freeze API"
require_pattern "$LOWER_CORE_FILE" 'typed_program_get_expr_type' "冻结 TypeId metadata"
require_pattern "$LOWER_CORE_FILE" 'typed_program_get_call_target' "冻结 resolved call target"
require_pattern "$LOWER_CORE_FILE" 'typed_program_get_method_dispatch' "冻结 method dispatch"
require_pattern "$LOWER_CORE_FILE" 'typed_program_get_field_access' "冻结 field id"
require_pattern "$LOWER_CORE_FILE" 'proof_error_id:[[:space:]]*i32' "冻结 proof error id"
require_pattern "$LOWER_CORE_FILE" 'source_expr_id:[[:space:]]*ExprId' "保留源 ExprId metadata"

tmp_dir="$(mktemp -d /tmp/uya-core-semantics-freeze.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn freeze_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn freeze_lowered_program() LoweredProgram {
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
        functions: freeze_vec(),
        body_ops: freeze_vec(),
        core_bodies: freeze_vec(),
        core_stmts: freeze_vec(),
        core_exprs: freeze_vec(),
        core_places: freeze_vec(),
        core_cleanup_edges: freeze_vec(),
        core_semantic_facts: freeze_vec(),
        globals: freeze_vec(),
        types: freeze_vec(),
        interfaces: freeze_vec(),
        err_unions: freeze_vec(),
        async_frames: freeze_vec(),
        drop_defer_plans: freeze_vec(),
        helpers: freeze_vec(),
        worklist: freeze_vec(),
    };
}

fn freeze_typed_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: freeze_vec(),
        identifier_bindings: freeze_vec(),
        call_targets: freeze_vec(),
        method_dispatch: freeze_vec(),
        field_access: freeze_vec(),
        global_init_order: freeze_vec(),
        reachable_roots: freeze_vec(),
        proof_results: freeze_vec(),
    };
}

fn setup_typed_facts(typed: &TypedProgram) !void {
    try assert_eq_i32(typed_program_set_expr_type(typed, 7, 77), 0);
    var target: TypedCallTarget = TypedCallTarget{
        kind: TYPED_CALL_TARGET_FUNCTION,
        function_id: 101,
        decl_id: 102,
        symbol_id: 103,
        mono_instance_id: 104,
    };
    try assert_eq_i32(typed_program_set_call_target(typed, 7, &target), 0);
    var dispatch: TypedMethodDispatch = TypedMethodDispatch{
        receiver_type_id: 201,
        method_symbol_id: 202,
        interface_symbol_id: 203,
        vtable_slot: 4,
    };
    try assert_eq_i32(typed_program_set_method_dispatch(typed, 7, &dispatch), 0);
    try assert_eq_i32(typed_program_set_field_access(typed, 7, 301), 0);
    var proof: TypedProofResult = TypedProofResult{
        expr_id: 7,
        status: TYPED_PROOF_ERROR,
        error_id: 901,
    };
    try assert_eq_i32(typed_program_append_proof_result(typed, &proof), 0);
}

fn append_core_body(lowered: &LoweredProgram) !void {
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
        semantic_fact_start: CORE_SEMANTIC_FACT_INVALID_ID,
        semantic_fact_count: 0,
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
        literal_i64: 0i64,
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
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place), 0);
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge), 0);
}

fn expect_fact(lowered: &LoweredProgram, index: usize, kind: i32, out: &CoreSemanticFact) !void {
    try assert_eq_i32(lowered_program_get_core_semantic_fact(lowered, index, out), 1);
    try assert_eq_i32(out.kind, kind);
}

test "core lowering freezes typed semantics into CoreSemanticFact table" {
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

    var typed: TypedProgram = freeze_typed_program();
    typed_program_init(&typed);
    try setup_typed_facts(&typed);

    var lowered: LoweredProgram = freeze_lowered_program();
    lowered_program_init(&lowered, &arena);
    try append_core_body(&lowered);
    try assert_eq_i32(lowered_program_freeze_core_semantics_from_typed(&lowered, &typed), 0);

    var body: CoreBody = CoreBody{
        body_id: CORE_BODY_INVALID_ID,
        function_id: 0,
        decl_id: 0,
        root_stmt_start: 0,
        root_stmt_count: 0,
        expr_start: 0,
        expr_count: 0,
        place_start: 0,
        place_count: 0,
        cleanup_edge_start: 0,
        cleanup_edge_count: 0,
        semantic_fact_start: CORE_SEMANTIC_FACT_INVALID_ID,
        semantic_fact_count: 0,
        source_span_id: 0,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_get_core_body(&lowered, 0usize, &body), 1);
    try assert_eq_i32(body.semantic_fact_start, 0);
    try assert_eq_i32(body.semantic_fact_count, 10);
    try assert_eq_i32(lowered.core_semantic_fact_count as i32, 10);

    var fact: CoreSemanticFact = lowered_program_empty_semantic_fact(&lowered, 0, 0);
    try expect_fact(&lowered, 0usize, CORE_SEMANTIC_FACT_TYPE_ID, &fact);
    try assert_eq_i32(fact.expr_id, 0);
    try assert_eq_i32(fact.source_expr_id, 7);
    try assert_eq_i32(fact.type_id, 77);

    try expect_fact(&lowered, 1usize, CORE_SEMANTIC_FACT_RESOLVED_CALL, &fact);
    try assert_eq_i32(fact.call_target_kind, TYPED_CALL_TARGET_FUNCTION);
    try assert_eq_i32(fact.target_function_id, 101);
    try assert_eq_i32(fact.target_decl_id, 102);
    try assert_eq_i32(fact.target_symbol_id, 103);
    try assert_eq_i32(fact.mono_instance_id, 104);

    try expect_fact(&lowered, 2usize, CORE_SEMANTIC_FACT_METHOD_DISPATCH, &fact);
    try assert_eq_i32(fact.receiver_type_id, 201);
    try assert_eq_i32(fact.method_symbol_id, 202);
    try assert_eq_i32(fact.interface_symbol_id, 203);
    try assert_eq_i32(fact.vtable_slot, 4);

    try expect_fact(&lowered, 3usize, CORE_SEMANTIC_FACT_FIELD_ID, &fact);
    try assert_eq_i32(fact.field_id, 301);

    try expect_fact(&lowered, 4usize, CORE_SEMANTIC_FACT_SOURCE_SPAN, &fact);
    try assert_eq_i32(fact.source_span_id, 701);

    try expect_fact(&lowered, 5usize, CORE_SEMANTIC_FACT_CAPABILITY, &fact);
    try assert_eq_i32(fact.capability_id, 801);

    try expect_fact(&lowered, 6usize, CORE_SEMANTIC_FACT_PROOF_RESULT, &fact);
    try assert_eq_i32(fact.expr_id, 0);
    try assert_eq_i32(fact.source_expr_id, 7);
    try assert_eq_i32(fact.proof_result_id, 0);
    try assert_eq_i32(fact.proof_status, TYPED_PROOF_ERROR);
    try assert_eq_i32(fact.proof_error_id, 901);

    try expect_fact(&lowered, 7usize, CORE_SEMANTIC_FACT_SOURCE_SPAN, &fact);
    try assert_eq_i32(fact.stmt_id, 0);
    try assert_eq_i32(fact.cleanup_scope_id, 601);

    try expect_fact(&lowered, 8usize, CORE_SEMANTIC_FACT_SOURCE_SPAN, &fact);
    try assert_eq_i32(fact.place_id, 0);
    try assert_eq_i32(fact.field_id, 301);

    try expect_fact(&lowered, 9usize, CORE_SEMANTIC_FACT_CLEANUP, &fact);
    try assert_eq_i32(fact.cleanup_edge_id, 0);
    try assert_eq_i32(fact.drop_defer_plan_id, 901);
    try assert_eq_i32(fact.flags, 5);

    typed_program_release(&typed);
    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ Core semantics freeze from TypedProgram verified"
