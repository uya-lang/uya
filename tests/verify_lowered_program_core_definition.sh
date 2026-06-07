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
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+CoreBody' "CoreBody 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+CoreStmt' "CoreStmt 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+CoreExpr' "CoreExpr 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+CorePlace' "CorePlace 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+CoreCleanupEdge' "CoreCleanupEdge 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+CoreSemanticFact' "CoreSemanticFact 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+LoweredBodyOp' "LoweredBodyOp 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+ConcreteType' "ConcreteType 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+RuntimeHelper' "RuntimeHelper 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+ErrorUnionLayout' "ErrorUnionLayout 结构"
require_pattern "$LOWER_CORE_FILE" '^export[[:space:]]+struct[[:space:]]+AsyncFramePlan' "AsyncFramePlan 结构"
require_pattern "$LOWER_CORE_FILE" 'semantic_fact_start:[[:space:]]*CoreSemanticFactId' "CoreBody semantic fact range start"
require_pattern "$LOWER_CORE_FILE" 'semantic_fact_count:[[:space:]]*i32' "CoreBody semantic fact range count"
require_pattern "$LOWER_CORE_FILE" 'arena:[[:space:]]*&CompilerArena' "LoweredProgram 独立 arena 句柄"
require_pattern "$LOWER_CORE_FILE" 'functions:[[:space:]]*SemanticVector' "functions 动态表"
require_pattern "$LOWER_CORE_FILE" 'body_ops:[[:space:]]*SemanticVector' "body_ops 动态表"
require_pattern "$LOWER_CORE_FILE" 'core_bodies:[[:space:]]*SemanticVector' "CoreBody 动态表"
require_pattern "$LOWER_CORE_FILE" 'core_stmts:[[:space:]]*SemanticVector' "CoreStmt 动态表"
require_pattern "$LOWER_CORE_FILE" 'core_exprs:[[:space:]]*SemanticVector' "CoreExpr 动态表"
require_pattern "$LOWER_CORE_FILE" 'core_places:[[:space:]]*SemanticVector' "CorePlace 动态表"
require_pattern "$LOWER_CORE_FILE" 'core_cleanup_edges:[[:space:]]*SemanticVector' "CoreCleanupEdge 动态表"
require_pattern "$LOWER_CORE_FILE" 'core_semantic_facts:[[:space:]]*SemanticVector' "Core semantic metadata 动态表"
require_pattern "$LOWER_CORE_FILE" 'call_target_kind:[[:space:]]*i32' "resolved call target kind metadata"
require_pattern "$LOWER_CORE_FILE" 'method_symbol_id:[[:space:]]*SymbolId' "method dispatch metadata"
require_pattern "$LOWER_CORE_FILE" 'field_id:[[:space:]]*FieldId' "field id metadata"
require_pattern "$LOWER_CORE_FILE" 'proof_status:[[:space:]]*i32' "proof result metadata"
require_pattern "$LOWER_CORE_FILE" 'drop_defer_plan_id:[[:space:]]*i32' "drop/defer/errdefer metadata"
require_pattern "$LOWER_CORE_FILE" 'capability_id:[[:space:]]*i32' "capability metadata"
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
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_core_body' "CoreBody append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_core_stmt' "CoreStmt append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_core_expr' "CoreExpr append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_core_place' "CorePlace append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_core_cleanup_edge' "CoreCleanupEdge append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_append_core_semantic_fact' "CoreSemanticFact append API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_body_op' "body op get API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_core_body' "CoreBody get API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_core_stmt' "CoreStmt get API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_core_expr' "CoreExpr get API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_core_place' "CorePlace get API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_core_cleanup_edge' "CoreCleanupEdge get API"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_get_core_semantic_fact' "CoreSemanticFact get API"
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
        core_body_count: 0usize,
        core_stmt_count: 0usize,
        core_expr_count: 0usize,
        core_place_count: 0usize,
        core_cleanup_edge_count: 0usize,
        core_semantic_fact_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_test_vector(),
        body_ops: lower_test_vector(),
        core_bodies: lower_test_vector(),
        core_stmts: lower_test_vector(),
        core_exprs: lower_test_vector(),
        core_places: lower_test_vector(),
        core_cleanup_edges: lower_test_vector(),
        core_semantic_facts: lower_test_vector(),
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

fn lower_test_core_semantic_fact(i: i32, offset: i32, kind: i32) CoreSemanticFact {
    return CoreSemanticFact{
        fact_id: (i * 8) + offset,
        kind: kind,
        body_id: i,
        stmt_id: i,
        expr_id: i,
        place_id: i,
        cleanup_edge_id: i,
        call_target_kind: TYPED_CALL_TARGET_FUNCTION,
        target_function_id: i + 100,
        target_decl_id: i + 200,
        target_symbol_id: i + 210,
        mono_instance_id: i + 220,
        receiver_type_id: i + 230,
        method_symbol_id: i + 240,
        interface_symbol_id: i + 250,
        vtable_slot: i + 3,
        field_id: i + 500,
        type_id: i + 600,
        proof_result_id: i + 300,
        proof_status: TYPED_PROOF_OK,
        source_span_id: i + 400,
        drop_defer_plan_id: i + 700,
        cleanup_scope_id: i + 10,
        capability_id: i + 800,
        flags: 0,
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
        var core_body: CoreBody = CoreBody{
            body_id: i,
            function_id: i,
            decl_id: i,
            root_stmt_start: i * 2,
            root_stmt_count: 2,
            expr_start: i * 3,
            expr_count: 3,
            place_start: i,
            place_count: 1,
            cleanup_edge_start: i,
            cleanup_edge_count: 0,
            semantic_fact_start: i * 8,
            semantic_fact_count: 8,
            source_span_id: i,
            flags: CORE_BODY_FLAG_SOURCE_BODY,
        };
        var core_stmt: CoreStmt = CoreStmt{
            stmt_id: i,
            kind: CORE_STMT_KIND_RETURN,
            body_id: i,
            parent_stmt_id: CORE_STMT_INVALID_ID,
            first_child_stmt: CORE_STMT_INVALID_ID,
            child_stmt_count: 0,
            expr_id: i,
            place_id: CORE_PLACE_INVALID_ID,
            cleanup_edge_start: i,
            cleanup_edge_count: 1,
            source_span_id: i,
            cleanup_scope_id: i + 10,
            flags: 0,
        };
        var core_expr: CoreExpr = CoreExpr{
            expr_id: i,
            kind: CORE_EXPR_KIND_CALL,
            body_id: i,
            source_expr_id: i,
            type_id: i,
            lhs_expr_id: CORE_EXPR_INVALID_ID,
            rhs_expr_id: CORE_EXPR_INVALID_ID,
            callee_expr_id: i + 1,
            place_id: i,
            target_function_id: i + 100,
            target_decl_id: i + 200,
            field_id: -1,
            proof_result_id: i + 300,
            capability_id: i + 400,
            source_span_id: i,
            flags: 0,
        };
        var core_place: CorePlace = CorePlace{
            place_id: i,
            kind: CORE_PLACE_KIND_FIELD,
            body_id: i,
            source_expr_id: i,
            type_id: i,
            base_place_id: CORE_PLACE_INVALID_ID,
            index_expr_id: CORE_EXPR_INVALID_ID,
            field_id: i + 500,
            symbol_id: i + 600,
            source_span_id: i,
            flags: 0,
        };
        var cleanup_edge: CoreCleanupEdge = CoreCleanupEdge{
            edge_id: i,
            kind: CORE_CLEANUP_EDGE_KIND_RETURN,
            body_id: i,
            from_stmt_id: i,
            to_stmt_id: CORE_STMT_INVALID_ID,
            cleanup_scope_id: i + 10,
            drop_defer_plan_id: i + 700,
            payload_expr_id: i,
            source_span_id: i,
            flags: 0,
        };
        try assert_eq_i32(lowered_program_append_function(&lowered, &fn_item), 0);
        try assert_eq_i32(lowered_program_append_body_op(&lowered, &body_op), 0);
        try assert_eq_i32(lowered_program_append_core_body(&lowered, &core_body), 0);
        try assert_eq_i32(lowered_program_append_core_stmt(&lowered, &core_stmt), 0);
        try assert_eq_i32(lowered_program_append_core_expr(&lowered, &core_expr), 0);
        try assert_eq_i32(lowered_program_append_core_place(&lowered, &core_place), 0);
        try assert_eq_i32(lowered_program_append_core_cleanup_edge(&lowered, &cleanup_edge), 0);
        var fact_offset: i32 = 0;
        while fact_offset < 8 {
            var semantic_fact: CoreSemanticFact = lower_test_core_semantic_fact(i, fact_offset, fact_offset + 1);
            try assert_eq_i32(lowered_program_append_core_semantic_fact(&lowered, &semantic_fact), 0);
            fact_offset = fact_offset + 1;
        }
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
    try assert_eq_i32(lowered.core_body_count as i32, 40);
    try assert_eq_i32(lowered.core_stmt_count as i32, 40);
    try assert_eq_i32(lowered.core_expr_count as i32, 40);
    try assert_eq_i32(lowered.core_place_count as i32, 40);
    try assert_eq_i32(lowered.core_cleanup_edge_count as i32, 40);
    try assert_eq_i32(lowered.core_semantic_fact_count as i32, 320);
    try assert_eq_i32(lowered.global_count, 40);
    try assert_eq_i32(lowered.type_count, 40);
    try assert_eq_i32(lowered.interface_count, 40);
    try assert_eq_i32(lowered.err_union_count, 40);
    try assert_eq_i32(lowered.async_frame_count, 40);
    try assert_eq_i32(lowered.helper_count, 40);
    try assert_eq_i32(lowered.work_item_count, 40);
    try expect(lowered.functions.capacity >= 40usize);
    try expect(lowered.body_ops.capacity >= 40usize);
    try expect(lowered.core_bodies.capacity >= 40usize);
    try expect(lowered.core_stmts.capacity >= 40usize);
    try expect(lowered.core_exprs.capacity >= 40usize);
    try expect(lowered.core_places.capacity >= 40usize);
    try expect(lowered.core_cleanup_edges.capacity >= 40usize);
    try expect(lowered.core_semantic_facts.capacity >= 320usize);
    try expect(lowered.worklist.capacity >= 40usize);
    try expect(lowered.functions.realloc_count > 1);
    try expect(lowered.body_ops.realloc_count > 1);
    try expect(lowered.core_bodies.realloc_count > 1);
    try expect(lowered.core_stmts.realloc_count > 1);
    try expect(lowered.core_exprs.realloc_count > 1);
    try expect(lowered.core_places.realloc_count > 1);
    try expect(lowered.core_cleanup_edges.realloc_count > 1);
    try expect(lowered.core_semantic_facts.realloc_count > 1);
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
    var got_core_body: CoreBody = CoreBody{
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
    try assert_eq_i32(lowered_program_get_core_body(&lowered, 39usize, &got_core_body), 1);
    try assert_eq_i32(got_core_body.body_id, 39);
    try assert_eq_i32(got_core_body.function_id, 39);
    try assert_eq_i32(got_core_body.root_stmt_start, 78);
    try assert_eq_i32(got_core_body.expr_start, 117);
    try assert_eq_i32(got_core_body.semantic_fact_start, 312);
    try assert_eq_i32(got_core_body.semantic_fact_count, 8);
    var got_core_stmt: CoreStmt = CoreStmt{
        stmt_id: CORE_STMT_INVALID_ID,
        kind: 0,
        body_id: CORE_BODY_INVALID_ID,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: CORE_CLEANUP_EDGE_INVALID_ID,
        cleanup_edge_count: 0,
        source_span_id: 0,
        cleanup_scope_id: 0,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_get_core_stmt(&lowered, 39usize, &got_core_stmt), 1);
    try assert_eq_i32(got_core_stmt.stmt_id, 39);
    try assert_eq_i32(got_core_stmt.kind, CORE_STMT_KIND_RETURN);
    try assert_eq_i32(got_core_stmt.cleanup_scope_id, 49);
    var got_core_expr: CoreExpr = CoreExpr{
        expr_id: CORE_EXPR_INVALID_ID,
        kind: 0,
        body_id: CORE_BODY_INVALID_ID,
        source_expr_id: 0,
        type_id: 0,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: 0,
        target_decl_id: 0,
        field_id: 0,
        proof_result_id: 0,
        capability_id: 0,
        source_span_id: 0,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_get_core_expr(&lowered, 39usize, &got_core_expr), 1);
    try assert_eq_i32(got_core_expr.expr_id, 39);
    try assert_eq_i32(got_core_expr.kind, CORE_EXPR_KIND_CALL);
    try assert_eq_i32(got_core_expr.target_function_id, 139);
    var got_core_place: CorePlace = CorePlace{
        place_id: CORE_PLACE_INVALID_ID,
        kind: 0,
        body_id: CORE_BODY_INVALID_ID,
        source_expr_id: 0,
        type_id: 0,
        base_place_id: CORE_PLACE_INVALID_ID,
        index_expr_id: CORE_EXPR_INVALID_ID,
        field_id: 0,
        symbol_id: 0,
        source_span_id: 0,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_get_core_place(&lowered, 39usize, &got_core_place), 1);
    try assert_eq_i32(got_core_place.place_id, 39);
    try assert_eq_i32(got_core_place.kind, CORE_PLACE_KIND_FIELD);
    try assert_eq_i32(got_core_place.field_id, 539);
    var got_cleanup_edge: CoreCleanupEdge = CoreCleanupEdge{
        edge_id: CORE_CLEANUP_EDGE_INVALID_ID,
        kind: 0,
        body_id: CORE_BODY_INVALID_ID,
        from_stmt_id: CORE_STMT_INVALID_ID,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 0,
        drop_defer_plan_id: 0,
        payload_expr_id: CORE_EXPR_INVALID_ID,
        source_span_id: 0,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_get_core_cleanup_edge(&lowered, 39usize, &got_cleanup_edge), 1);
    try assert_eq_i32(got_cleanup_edge.edge_id, 39);
    try assert_eq_i32(got_cleanup_edge.kind, CORE_CLEANUP_EDGE_KIND_RETURN);
    try assert_eq_i32(got_cleanup_edge.drop_defer_plan_id, 739);
    var got_semantic_fact: CoreSemanticFact = CoreSemanticFact{
        fact_id: CORE_SEMANTIC_FACT_INVALID_ID,
        kind: 0,
        body_id: CORE_BODY_INVALID_ID,
        stmt_id: CORE_STMT_INVALID_ID,
        expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_id: CORE_CLEANUP_EDGE_INVALID_ID,
        call_target_kind: TYPED_CALL_TARGET_UNKNOWN,
        target_function_id: 0,
        target_decl_id: 0,
        target_symbol_id: 0,
        mono_instance_id: 0,
        receiver_type_id: 0,
        method_symbol_id: 0,
        interface_symbol_id: 0,
        vtable_slot: 0,
        field_id: 0,
        type_id: 0,
        proof_result_id: 0,
        proof_status: TYPED_PROOF_UNKNOWN,
        source_span_id: 0,
        drop_defer_plan_id: 0,
        cleanup_scope_id: 0,
        capability_id: 0,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_get_core_semantic_fact(&lowered, 313usize, &got_semantic_fact), 1);
    try assert_eq_i32(got_semantic_fact.fact_id, 313);
    try assert_eq_i32(got_semantic_fact.kind, CORE_SEMANTIC_FACT_METHOD_DISPATCH);
    try assert_eq_i32(got_semantic_fact.target_function_id, 139);
    try assert_eq_i32(got_semantic_fact.target_decl_id, 239);
    try assert_eq_i32(got_semantic_fact.method_symbol_id, 279);
    try assert_eq_i32(got_semantic_fact.interface_symbol_id, 289);
    try assert_eq_i32(got_semantic_fact.field_id, 539);
    try assert_eq_i32(got_semantic_fact.type_id, 639);
    try assert_eq_i32(got_semantic_fact.proof_result_id, 339);
    try assert_eq_i32(got_semantic_fact.proof_status, TYPED_PROOF_OK);
    try assert_eq_i32(got_semantic_fact.source_span_id, 439);
    try assert_eq_i32(got_semantic_fact.drop_defer_plan_id, 739);
    try assert_eq_i32(got_semantic_fact.cleanup_scope_id, 49);
    try assert_eq_i32(got_semantic_fact.capability_id, 839);

    const stats: LoweredProgramStats = lowered_program_stats(&lowered);
    try assert_eq_i32(stats.table_count, 16);
    try expect(stats.table_capacity >= 880usize);

    lowered_program_release(&lowered);
    try assert_eq_i32(lowered_program_lifecycle_state(&lowered), LOWERED_PROGRAM_LIFECYCLE_RELEASED);
    try expect(lowered_program_current_bytes(&lowered) == 0usize);
    try expect(lowered_program_peak_bytes(&lowered) > @size_of(LoweredProgram));
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ LoweredProgram core definition and dynamic storage verified"
