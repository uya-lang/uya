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
        echo "error: CoreIR parallel determinism missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_core_bodies' "CoreBody stable merge sort"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_core_stmts' "CoreStmt stable merge sort"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_core_exprs' "CoreExpr stable merge sort"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_core_places' "CorePlace stable merge sort"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_core_cleanup_edges' "CoreCleanupEdge stable merge sort"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_core_semantic_facts' "CoreSemanticFact stable merge sort"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_sort_work_items' "LowerWorkItem request stable merge sort"

tmp_dir="$(mktemp -d /tmp/uya-coreir-parallel.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn coreir_parallel_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn coreir_parallel_program() LoweredProgram {
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
        functions: coreir_parallel_vec(),
        body_ops: coreir_parallel_vec(),
        core_bodies: coreir_parallel_vec(),
        core_stmts: coreir_parallel_vec(),
        core_exprs: coreir_parallel_vec(),
        core_places: coreir_parallel_vec(),
        core_cleanup_edges: coreir_parallel_vec(),
        core_semantic_facts: coreir_parallel_vec(),
        globals: coreir_parallel_vec(),
        types: coreir_parallel_vec(),
        interfaces: coreir_parallel_vec(),
        err_unions: coreir_parallel_vec(),
        async_frames: coreir_parallel_vec(),
        drop_defer_plans: coreir_parallel_vec(),
        helpers: coreir_parallel_vec(),
        worklist: coreir_parallel_vec(),
    };
}

fn coreir_parallel_enabled() i32 {
    const value: *byte = getenv("UYA_COREIR_PARALLEL_FIXTURE" as *byte);
    if value == null {
        return 0;
    }
    if value[0] == 112 as byte {
        return 1;
    }
    return 0;
}

fn coreir_parallel_invalid_enabled() i32 {
    const value: *byte = getenv("UYA_COREIR_PARALLEL_INVALID" as *byte);
    if value == null {
        return 0;
    }
    if value[0] == 49 as byte && value[1] == 0 as byte {
        return 1;
    }
    return 0;
}

fn coreir_parallel_fact(fact_id: CoreSemanticFactId, body_id: CoreBodyId, kind: i32) CoreSemanticFact {
    return CoreSemanticFact{
        fact_id: fact_id,
        kind: kind,
        body_id: body_id,
        stmt_id: CORE_STMT_INVALID_ID,
        expr_id: CORE_EXPR_INVALID_ID,
        source_expr_id: 30 + body_id,
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

fn append_coreir_parallel_function(lowered: &LoweredProgram, body_id: CoreBodyId) !void {
    var func: ConcreteFunction = ConcreteFunction{
        function_id: 100 + body_id,
        decl_id: 200 + body_id,
        mono_instance_id: TYPED_PROGRAM_INVALID_ID,
        body_start: body_id,
        body_count: 1,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_function(lowered, &func), 0);
}

fn append_coreir_parallel_fragment(lowered: &LoweredProgram, body_id: CoreBodyId, invalid_range: i32) !void {
    const fact_start: i32 = body_id * 5;
    var root_start: i32 = body_id;
    if invalid_range != 0 {
        root_start = -1;
    }

    var body: CoreBody = CoreBody{
        body_id: body_id,
        function_id: 100 + body_id,
        decl_id: 200 + body_id,
        root_stmt_start: root_start,
        root_stmt_count: 1,
        expr_start: body_id,
        expr_count: 1,
        place_start: body_id,
        place_count: 1,
        cleanup_edge_start: body_id,
        cleanup_edge_count: 1,
        semantic_fact_start: fact_start,
        semantic_fact_count: 5,
        source_span_id: 500 + body_id,
        flags: CORE_BODY_FLAG_SOURCE_BODY,
    };
    var stmt: CoreStmt = CoreStmt{
        stmt_id: body_id,
        kind: CORE_STMT_KIND_RETURN,
        body_id: body_id,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: body_id,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: body_id,
        cleanup_edge_count: 1,
        source_span_id: 510 + body_id,
        cleanup_scope_id: 600 + body_id,
        flags: 0,
    };
    var expr: CoreExpr = CoreExpr{
        expr_id: body_id,
        kind: CORE_EXPR_KIND_CALL,
        body_id: body_id,
        source_expr_id: 30 + body_id,
        type_id: 700 + body_id,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: body_id,
        target_function_id: 1000 + body_id,
        target_decl_id: 1100 + body_id,
        field_id: 1200 + body_id,
        proof_result_id: 1300 + body_id,
        capability_id: 1400 + body_id,
        source_span_id: 520 + body_id,
        flags: 0,
    };
    var place: CorePlace = CorePlace{
        place_id: body_id,
        kind: CORE_PLACE_KIND_FIELD,
        body_id: body_id,
        source_expr_id: 30 + body_id,
        type_id: 700 + body_id,
        base_place_id: CORE_PLACE_INVALID_ID,
        index_expr_id: CORE_EXPR_INVALID_ID,
        field_id: 1200 + body_id,
        symbol_id: 1500 + body_id,
        source_span_id: 530 + body_id,
        flags: 0,
    };
    var edge: CoreCleanupEdge = CoreCleanupEdge{
        edge_id: body_id,
        kind: CORE_CLEANUP_EDGE_KIND_RETURN,
        body_id: body_id,
        from_stmt_id: body_id,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 600 + body_id,
        drop_defer_plan_id: 1600 + body_id,
        payload_expr_id: body_id,
        source_span_id: 540 + body_id,
        flags: body_id,
    };
    var call_fact: CoreSemanticFact = coreir_parallel_fact(fact_start, body_id, CORE_SEMANTIC_FACT_RESOLVED_CALL);
    call_fact.expr_id = body_id;
    call_fact.call_target_kind = TYPED_CALL_TARGET_FUNCTION;
    call_fact.target_function_id = 1000 + body_id;
    call_fact.target_decl_id = 1100 + body_id;
    call_fact.target_symbol_id = 1110 + body_id;
    call_fact.mono_instance_id = 1120 + body_id;
    call_fact.type_id = 700 + body_id;
    call_fact.proof_result_id = 1300 + body_id;
    call_fact.proof_status = TYPED_PROOF_OK;
    call_fact.capability_id = 1400 + body_id;

    var field_fact: CoreSemanticFact = coreir_parallel_fact(fact_start + 1, body_id, CORE_SEMANTIC_FACT_FIELD_ID);
    field_fact.expr_id = body_id;
    field_fact.place_id = body_id;
    field_fact.field_id = 1200 + body_id;

    var proof_fact: CoreSemanticFact = coreir_parallel_fact(fact_start + 2, body_id, CORE_SEMANTIC_FACT_PROOF_RESULT);
    proof_fact.expr_id = body_id;
    proof_fact.proof_result_id = 1300 + body_id;
    proof_fact.proof_status = TYPED_PROOF_OK;

    var cleanup_fact: CoreSemanticFact = coreir_parallel_fact(fact_start + 3, body_id, CORE_SEMANTIC_FACT_CLEANUP);
    cleanup_fact.stmt_id = body_id;
    cleanup_fact.expr_id = body_id;
    cleanup_fact.cleanup_edge_id = body_id;
    cleanup_fact.drop_defer_plan_id = 1600 + body_id;
    cleanup_fact.cleanup_scope_id = 600 + body_id;

    var capability_fact: CoreSemanticFact = coreir_parallel_fact(fact_start + 4, body_id, CORE_SEMANTIC_FACT_CAPABILITY);
    capability_fact.expr_id = body_id;
    capability_fact.capability_id = 1400 + body_id;

    try append_coreir_parallel_function(lowered, body_id);
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place), 0);
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &call_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &field_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &proof_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &cleanup_fact), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &capability_fact), 0);
}

fn append_coreir_parallel_fixture(lowered: &LoweredProgram, parallel: i32, invalid: i32) !void {
    if parallel != 0 {
        var invalid_body1: i32 = 0;
        if invalid != 0 {
            invalid_body1 = 1;
        }
        try append_coreir_parallel_fragment(lowered, 1, invalid_body1);
        try append_coreir_parallel_fragment(lowered, 0, 0);
        return;
    }
    try append_coreir_parallel_fragment(lowered, 0, 0);
    if invalid != 0 {
        try append_coreir_parallel_fragment(lowered, 1, 1);
        return;
    }
    try append_coreir_parallel_fragment(lowered, 1, 0);
}

fn append_coreir_parallel_request(lowered: &LoweredProgram, kind: i32, primary_id: i32, secondary_id: i32) !void {
    var request: LowerWorkItem = LowerWorkItem{
        kind: kind,
        primary_id: primary_id,
        secondary_id: secondary_id,
    };
    try assert_eq_i32(lowered_program_append_work_item(lowered, &request), 0);
}

fn append_coreir_parallel_request_fixture(lowered: &LoweredProgram, parallel: i32) !void {
    if parallel != 0 {
        try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_RUNTIME_HELPER, 900, 90);
        try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_TYPE, 300, 30);
        try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_FUNCTION, 200, 20);
        try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_FUNCTION, 100, 10);
        return;
    }
    try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_FUNCTION, 100, 10);
    try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_FUNCTION, 200, 20);
    try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_TYPE, 300, 30);
    try append_coreir_parallel_request(lowered, LOWER_WORK_ITEM_RUNTIME_HELPER, 900, 90);
}

fn assert_coreir_parallel_requests_sorted(lowered: &LoweredProgram) !void {
    var work0: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var work1: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var work2: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    var work3: LowerWorkItem = LowerWorkItem{ kind: 0, primary_id: 0, secondary_id: 0 };
    try assert_eq_i32(lowered.work_item_count as i32, 4);
    try assert_eq_i32(lowered_program_get_work_item(lowered, 0usize, &work0), 1);
    try assert_eq_i32(lowered_program_get_work_item(lowered, 1usize, &work1), 1);
    try assert_eq_i32(lowered_program_get_work_item(lowered, 2usize, &work2), 1);
    try assert_eq_i32(lowered_program_get_work_item(lowered, 3usize, &work3), 1);
    try assert_eq_i32(work0.kind, LOWER_WORK_ITEM_FUNCTION);
    try assert_eq_i32(work0.primary_id, 100);
    try assert_eq_i32(work0.secondary_id, 10);
    try assert_eq_i32(work1.kind, LOWER_WORK_ITEM_FUNCTION);
    try assert_eq_i32(work1.primary_id, 200);
    try assert_eq_i32(work1.secondary_id, 20);
    try assert_eq_i32(work2.kind, LOWER_WORK_ITEM_TYPE);
    try assert_eq_i32(work2.primary_id, 300);
    try assert_eq_i32(work2.secondary_id, 30);
    try assert_eq_i32(work3.kind, LOWER_WORK_ITEM_RUNTIME_HELPER);
    try assert_eq_i32(work3.primary_id, 900);
    try assert_eq_i32(work3.secondary_id, 90);
}

fn assert_coreir_parallel_sorted(lowered: &LoweredProgram) !void {
    const body0: &CoreBody = semantic_vector_item_ptr(&lowered.core_bodies, 0usize) as &CoreBody;
    const body1: &CoreBody = semantic_vector_item_ptr(&lowered.core_bodies, 1usize) as &CoreBody;
    const stmt0: &CoreStmt = semantic_vector_item_ptr(&lowered.core_stmts, 0usize) as &CoreStmt;
    const expr0: &CoreExpr = semantic_vector_item_ptr(&lowered.core_exprs, 0usize) as &CoreExpr;
    const place0: &CorePlace = semantic_vector_item_ptr(&lowered.core_places, 0usize) as &CorePlace;
    const edge0: &CoreCleanupEdge = semantic_vector_item_ptr(&lowered.core_cleanup_edges, 0usize) as &CoreCleanupEdge;
    const fact0: &CoreSemanticFact = semantic_vector_item_ptr(&lowered.core_semantic_facts, 0usize) as &CoreSemanticFact;
    const fact9: &CoreSemanticFact = semantic_vector_item_ptr(&lowered.core_semantic_facts, 9usize) as &CoreSemanticFact;
    try expect(body0 != null);
    try expect(body1 != null);
    try expect(stmt0 != null);
    try expect(expr0 != null);
    try expect(place0 != null);
    try expect(edge0 != null);
    try expect(fact0 != null);
    try expect(fact9 != null);
    try assert_eq_i32(body0.body_id, 0);
    try assert_eq_i32(body1.body_id, 1);
    try assert_eq_i32(stmt0.stmt_id, 0);
    try assert_eq_i32(expr0.expr_id, 0);
    try assert_eq_i32(place0.place_id, 0);
    try assert_eq_i32(edge0.edge_id, 0);
    try assert_eq_i32(fact0.fact_id, 0);
    try assert_eq_i32(fact9.fact_id, 9);
}

test "CoreIR stable merge keeps serial and parallel fixtures deterministic" {
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

    var lowered: LoweredProgram = coreir_parallel_program();
    lowered_program_init(&lowered, &arena);
    const parallel: i32 = coreir_parallel_enabled();
    const invalid: i32 = coreir_parallel_invalid_enabled();
    try append_coreir_parallel_fixture(&lowered, parallel, invalid);
    try append_coreir_parallel_request_fixture(&lowered, parallel);
    try assert_eq_i32(lowered_program_sort_stable(&lowered), 0);
    try assert_coreir_parallel_sorted(&lowered);
    try assert_coreir_parallel_requests_sorted(&lowered);

    var result: CoreVerifierResult = lowered_program_coreir_verify_ok_result();
    const verify_result: i32 = lowered_program_verify_coreir_result(&lowered, &result);
    if invalid != 0 {
        try assert_eq_i32(verify_result, -1);
        try assert_eq_i32(result.ok, 0);
        try assert_eq_i32(result.error_code, COREIR_VERIFY_ERR_INVALID_BODY_RANGE);
        try assert_eq_i32(result.body_id, 1);
    } else {
        if verify_result != 0 {
            try assert_eq_i32(result.error_code, COREIR_VERIFY_OK);
        }
        try assert_eq_i32(verify_result, 0);
        try assert_eq_i32(result.ok, 1);
        try assert_eq_i32(result.error_code, COREIR_VERIFY_OK);
    }

    lowered_program_maybe_dump_coreir(&lowered);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

extract_coreir() {
    local input="$1"
    local output="$2"
    awk '
        /^=== coreir ===$/ { in_dump = 1 }
        in_dump { print }
        /^=== coreir end ===$/ { exit }
    ' "$input" >"$output"
}

serial_stderr="$tmp_dir/serial.stderr"
parallel_stderr="$tmp_dir/parallel.stderr"
serial_coreir="$tmp_dir/serial.coreir"
parallel_coreir="$tmp_dir/parallel.coreir"
invalid_serial_stderr="$tmp_dir/invalid-serial.stderr"
invalid_parallel_stderr="$tmp_dir/invalid-parallel.stderr"
invalid_serial_coreir="$tmp_dir/invalid-serial.coreir"
invalid_parallel_coreir="$tmp_dir/invalid-parallel.coreir"

run_fixture() {
    local label="$1"
    local mode="$2"
    local invalid="$3"
    local stdout_path="$4"
    local stderr_path="$5"
    if [[ "$invalid" == "1" ]]; then
        if ! (cd "$REPO_ROOT" && UYA_DUMP_COREIR=1 UYA_COREIR_PARALLEL_FIXTURE="$mode" UYA_COREIR_PARALLEL_INVALID=1 ./bin/uya test "$tmp_dir/main.uya" --no-split-c >"$stdout_path" 2>"$stderr_path"); then
            echo "error: $label failed" >&2
            cat "$stderr_path" >&2
            cat "$stdout_path" >&2
            exit 1
        fi
        return
    fi
    if ! (cd "$REPO_ROOT" && UYA_DUMP_COREIR=1 UYA_COREIR_PARALLEL_FIXTURE="$mode" ./bin/uya test "$tmp_dir/main.uya" --no-split-c >"$stdout_path" 2>"$stderr_path"); then
        echo "error: $label failed" >&2
        cat "$stderr_path" >&2
        cat "$stdout_path" >&2
        exit 1
    fi
}

run_fixture "serial CoreIR dump fixture" "serial" "0" "$tmp_dir/serial.stdout" "$serial_stderr"
run_fixture "parallel CoreIR dump fixture" "parallel" "0" "$tmp_dir/parallel.stdout" "$parallel_stderr"

extract_coreir "$serial_stderr" "$serial_coreir"
extract_coreir "$parallel_stderr" "$parallel_coreir"

if ! grep -Fq "core_bodies=2 core_stmts=2 core_exprs=2 core_places=2 core_cleanup_edges=2 core_semantic_facts=10" "$serial_coreir"; then
    echo "error: serial CoreIR dump missing expected table summary" >&2
    exit 1
fi
if ! grep -Fq "body #0 function=100 decl=200 roots=0+1 exprs=0+1 places=0+1 cleanups=0+1 facts=0+5 source=500 flags=1" "$serial_coreir"; then
    echo "error: serial CoreIR dump missing first stable body" >&2
    exit 1
fi
if ! grep -Fq "body #1 function=101 decl=201 roots=1+1 exprs=1+1 places=1+1 cleanups=1+1 facts=5+5 source=501 flags=1" "$serial_coreir"; then
    echo "error: serial CoreIR dump missing second stable body" >&2
    exit 1
fi
if ! diff -u "$serial_coreir" "$parallel_coreir"; then
    echo "error: CoreIR dump changed between serial and simulated parallel stable merge" >&2
    exit 1
fi

run_fixture "serial invalid CoreIR fixture" "serial" "1" "$tmp_dir/invalid-serial.stdout" "$invalid_serial_stderr"
run_fixture "parallel invalid CoreIR fixture" "parallel" "1" "$tmp_dir/invalid-parallel.stdout" "$invalid_parallel_stderr"

extract_coreir "$invalid_serial_stderr" "$invalid_serial_coreir"
extract_coreir "$invalid_parallel_stderr" "$invalid_parallel_coreir"
if ! grep -Fq "body #1 function=101 decl=201 roots=-1+1 exprs=1+1 places=1+1 cleanups=1+1 facts=5+5 source=501 flags=1" "$invalid_serial_coreir"; then
    echo "error: serial invalid CoreIR fixture did not keep the expected stable bad body" >&2
    exit 1
fi
if ! diff -u "$invalid_serial_coreir" "$invalid_parallel_coreir"; then
    echo "error: invalid CoreIR dump changed between serial and simulated parallel stable merge" >&2
    exit 1
fi

echo "OK: CoreIR parallel determinism verified"
