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
        root_stmt_count: 1,
        expr_start: 0,
        expr_count: 1,
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
    var expr: CoreExpr = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 0,
        source_expr_id: 7,
        type_id: 77,
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
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
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
core_bodies=1 core_stmts=1 core_exprs=1 core_places=1 core_cleanup_edges=1 core_semantic_facts=4
body #0 function=11 decl=12 roots=0+1 exprs=0+1 places=0+1 cleanups=0+1 facts=0+4 source=500 flags=1
stmt #0 body=0 kind=10 parent=-1 children=-1+0 expr=0 place=-1 cleanup=0+1 source=501 scope=601 flags=0
expr #0 body=0 kind=11 source_expr=7 type=77 lhs=-1 rhs=-1 callee=-1 place=0 target_fn=101 target_decl=102 field=301 proof=401 capability=801 source=701 flags=0
place #0 body=0 kind=4 source_expr=7 type=77 base=-1 index=-1 field=301 symbol=302 source=702 flags=0
cleanup #0 body=0 kind=2 from=0 to=-1 scope=601 drop_defer=901 payload=0 source=703 flags=5
fact #0 kind=1 body=0 stmt=-1 expr=0 source_expr=7 place=-1 cleanup=-1
  call kind=1 target_fn=101 target_decl=102 target_symbol=103 mono=104 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=-1 type=77 proof=401 proof_status=1 proof_error=-1 source=700 drop_defer=-1 scope=-1 capability=801 flags=0
fact #1 kind=3 body=0 stmt=-1 expr=0 source_expr=7 place=0 cleanup=-1
  call kind=0 target_fn=-1 target_decl=-1 target_symbol=-1 mono=-1 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=301 type=-1 proof=-1 proof_status=0 proof_error=-1 source=701 drop_defer=-1 scope=-1 capability=-1 flags=0
fact #2 kind=7 body=0 stmt=0 expr=0 source_expr=7 place=-1 cleanup=0
  call kind=0 target_fn=-1 target_decl=-1 target_symbol=-1 mono=-1 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=-1 type=-1 proof=-1 proof_status=0 proof_error=-1 source=702 drop_defer=901 scope=601 capability=-1 flags=0
fact #3 kind=8 body=0 stmt=-1 expr=0 source_expr=7 place=-1 cleanup=-1
  call kind=0 target_fn=-1 target_decl=-1 target_symbol=-1 mono=-1 receiver_type=-1 method_symbol=-1 interface_symbol=-1 slot=-1
  meta field=-1 type=-1 proof=-1 proof_status=0 proof_error=-1 source=703 drop_defer=-1 scope=-1 capability=801 flags=0
=== coreir end ===
EOF

if ! diff -u "$expected_golden" "$actual_golden"; then
    echo "error: CoreIR dump golden changed" >&2
    exit 1
fi

echo "OK: CoreIR dump golden verified"
