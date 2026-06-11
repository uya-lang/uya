#!/usr/bin/env bash

# Phase 9B: verify the first CoreBody -> PortableMIR lowering slice.
# The covered shape is one concrete function with one CoreBody:
#   CORE_STMT_KIND_RETURN(CORE_EXPR_KIND_INT_LITERAL)
# It must lower to a verifier-clean PortableMIR module with one function, one
# entry block, one i32 type, one return operand and one return terminator.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-core-body-lowering.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
export type FileId = i32;
export type DeclId = i32;
export type SymbolId = i32;
export type TypeId = i32;
export type ExprId = i32;
export type FunctionId = i32;
export type MonoInstanceId = i32;
export type CoreBodyId = i32;
export type CoreStmtId = i32;
export type CoreExprId = i32;
export type CorePlaceId = i32;

export const CORE_BODY_INVALID_ID: CoreBodyId = -1;
export const CORE_STMT_INVALID_ID: CoreStmtId = -1;
export const CORE_EXPR_INVALID_ID: CoreExprId = -1;
export const CORE_PLACE_INVALID_ID: CorePlaceId = -1;
export const CORE_STMT_KIND_RETURN: i32 = 10;
export const CORE_EXPR_KIND_INT_LITERAL: i32 = 17;
export const CORE_EXPR_KIND_LOCAL_REF: i32 = 18;
export const CORE_EXPR_KIND_I32_ADD: i32 = 20;
export const MIR_CALL_CONV_UYA: i32 = 1;
export const MIR_CALL_CONV_C: i32 = 2;
export const MIR_RUNTIME_CAP_HOSTED_LIBC: i32 = 1;
export const MIR_RUNTIME_CAP_C_EXTERN: i32 = 2;

export struct CompilerArena {
    marker: i32,
}

export struct SemanticVector {
    data: &byte,
    item_size: usize,
    count: usize,
    capacity: usize,
    bytes: usize,
    realloc_count: i32,
}

export fn semantic_vector_init(vec: &SemanticVector, item_size: usize) void {
    if vec == null {
        return;
    }
    vec.data = null;
    vec.item_size = item_size;
    vec.count = 0usize;
    vec.capacity = 0usize;
    vec.bytes = 0usize;
    vec.realloc_count = 0;
}

export fn semantic_vector_append(vec: &SemanticVector, item: &const void) i32 {
    if vec == null || item == null || vec.data == null ||
       vec.item_size == 0usize || vec.count >= vec.capacity {
        return -1;
    }
    const dst_addr: usize = @usize_from_ptr(vec.data) + vec.count * vec.item_size;
    const dst: &byte = @ptr_from_usize(dst_addr) as &byte;
    const src: &const byte = item as &const byte;
    var i: usize = 0usize;
    while i < vec.item_size {
        dst[i] = src[i];
        i = i + 1usize;
    }
    vec.count = vec.count + 1usize;
    vec.bytes = vec.item_size * vec.count;
    return 0;
}

export fn semantic_vector_item_ptr(vec: &SemanticVector, index: usize) &byte {
    if vec == null || vec.data == null || vec.item_size == 0usize || index >= vec.count {
        return null;
    }
    const addr: usize = @usize_from_ptr(vec.data) + index * vec.item_size;
    return @ptr_from_usize(addr) as &byte;
}

export fn semantic_vector_release(vec: &SemanticVector) void {
    if vec == null {
        return;
    }
    vec.data = null;
    vec.count = 0usize;
    vec.capacity = 0usize;
    vec.bytes = 0usize;
}

export struct ConcreteFunction {
    function_id: FunctionId,
    decl_id: DeclId,
    mono_instance_id: MonoInstanceId,
    body_start: i32,
    body_count: i32,
    flags: i32,
}

export struct CoreBody {
    body_id: CoreBodyId,
    function_id: FunctionId,
    decl_id: DeclId,
    root_stmt_start: CoreStmtId,
    root_stmt_count: i32,
    expr_start: CoreExprId,
    expr_count: i32,
    place_start: CorePlaceId,
    place_count: i32,
    cleanup_edge_start: i32,
    cleanup_edge_count: i32,
    semantic_fact_start: i32,
    semantic_fact_count: i32,
    source_span_id: i32,
    flags: i32,
}

export struct CoreStmt {
    stmt_id: CoreStmtId,
    kind: i32,
    body_id: CoreBodyId,
    parent_stmt_id: CoreStmtId,
    first_child_stmt: CoreStmtId,
    child_stmt_count: i32,
    expr_id: CoreExprId,
    place_id: CorePlaceId,
    cleanup_edge_start: i32,
    cleanup_edge_count: i32,
    source_span_id: i32,
    cleanup_scope_id: i32,
    flags: i32,
}

export struct CoreExpr {
    expr_id: CoreExprId,
    kind: i32,
    body_id: CoreBodyId,
    source_expr_id: ExprId,
    type_id: TypeId,
    literal_i64: i64,
    lhs_expr_id: CoreExprId,
    rhs_expr_id: CoreExprId,
    callee_expr_id: CoreExprId,
    place_id: CorePlaceId,
    target_function_id: FunctionId,
    target_decl_id: DeclId,
    field_id: i32,
    proof_result_id: i32,
    capability_id: i32,
    source_span_id: i32,
    flags: i32,
}

export struct LoweredProgram {
    functions: SemanticVector,
    core_bodies: SemanticVector,
    core_stmts: SemanticVector,
    core_exprs: SemanticVector,
}
EOF

cat "$MIR_FILE" "$MIR_VERIFIER_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn fixture_vec(data: &byte, item_size: usize, count: usize, capacity: usize) SemanticVector {
    return SemanticVector{
        data: data,
        item_size: item_size,
        count: count,
        capacity: capacity,
        bytes: item_size * count,
        realloc_count: 0,
    };
}

test "CoreBody return i32 literal lowers to verifier-clean PortableMIR" {
    var source_functions: [ConcreteFunction: 1] = [];
    var source_bodies: [CoreBody: 1] = [];
    var source_stmts: [CoreStmt: 1] = [];
    var source_exprs: [CoreExpr: 1] = [];
    source_functions[0] = ConcreteFunction{
        function_id: 0,
        decl_id: 10,
        mono_instance_id: -1,
        body_start: 0,
        body_count: 1,
        flags: 0,
    };
    source_bodies[0] = CoreBody{
        body_id: 0,
        function_id: 0,
        decl_id: 10,
        root_stmt_start: 0,
        root_stmt_count: 1,
        expr_start: 0,
        expr_count: 1,
        place_start: 0,
        place_count: 0,
        cleanup_edge_start: 0,
        cleanup_edge_count: 0,
        semantic_fact_start: 0,
        semantic_fact_count: 0,
        source_span_id: 70,
        flags: 0,
    };
    source_exprs[0] = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_INT_LITERAL,
        body_id: 0,
        source_expr_id: 20,
        type_id: 0,
        literal_i64: 7i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: -1,
        target_decl_id: -1,
        field_id: -1,
        proof_result_id: -1,
        capability_id: 0,
        source_span_id: 71,
        flags: 0,
    };
    source_stmts[0] = CoreStmt{
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
        source_span_id: 72,
        cleanup_scope_id: 0,
        flags: 0,
    };
    var lowered: LoweredProgram = LoweredProgram{
        functions: fixture_vec(&source_functions[0] as &byte, @size_of(ConcreteFunction), 1usize, 1usize),
        core_bodies: fixture_vec(&source_bodies[0] as &byte, @size_of(CoreBody), 1usize, 1usize),
        core_stmts: fixture_vec(&source_stmts[0] as &byte, @size_of(CoreStmt), 1usize, 1usize),
        core_exprs: fixture_vec(&source_exprs[0] as &byte, @size_of(CoreExpr), 1usize, 1usize),
    };

    var mir_functions: [MirFunction: 1] = [];
    var mir_blocks: [MirBlock: 1] = [];
    var mir_types: [MirType: 1] = [];
    var mir_operands: [MirOperand: 1] = [];
    var mir_terminators: [MirTerminator: 1] = [];
    var arena: CompilerArena = CompilerArena{ marker: 0 };
    var module: PortableMirModule = PortableMirModule{
        arena: &arena,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_ACTIVE,
        target_profile: portable_mir_target_profile_hosted_native(),
        function_count: 0usize,
        block_count: 0usize,
        value_count: 0usize,
        type_count: 0usize,
        local_count: 0usize,
        inst_count: 0usize,
        terminator_count: 0usize,
        operand_count: 0usize,
        block_param_count: 0usize,
        successor_count: 0usize,
        debug_loc_count: 0usize,
        capability_req_count: 0usize,
        functions: fixture_vec(&mir_functions[0] as &byte, @size_of(MirFunction), 0usize, 1usize),
        blocks: fixture_vec(&mir_blocks[0] as &byte, @size_of(MirBlock), 0usize, 1usize),
        values: fixture_vec(null, @size_of(MirValue), 0usize, 0usize),
        types: fixture_vec(&mir_types[0] as &byte, @size_of(MirType), 0usize, 1usize),
        locals: fixture_vec(null, @size_of(MirLocal), 0usize, 0usize),
        insts: fixture_vec(null, @size_of(MirInst), 0usize, 0usize),
        terminators: fixture_vec(&mir_terminators[0] as &byte, @size_of(MirTerminator), 0usize, 1usize),
        operands: fixture_vec(&mir_operands[0] as &byte, @size_of(MirOperand), 0usize, 1usize),
        block_params: fixture_vec(null, @size_of(MirBlockParam), 0usize, 0usize),
        successors: fixture_vec(null, @size_of(MirSuccessor), 0usize, 0usize),
        debug_locs: fixture_vec(null, @size_of(MirDebugLoc), 0usize, 0usize),
        capability_reqs: fixture_vec(null, @size_of(MirCapabilityReq), 0usize, 0usize),
    };

    try assert_eq_i32(portable_mir_lower_core_body_to_module(&lowered, 0, &module), 0);
    try expect(module.function_count == 1usize);
    try expect(module.block_count == 1usize);
    try expect(module.type_count == 1usize);
    try expect(module.operand_count == 1usize);
    try expect(module.terminator_count == 1usize);
    try expect(module.inst_count == 0usize);
    try expect(module.value_count == 0usize);

    const typ: &MirType = semantic_vector_item_ptr(&module.types, 0usize) as &MirType;
    try expect(typ != null);
    try assert_eq_i32(typ.type_id, 0);
    try assert_eq_i32(typ.kind, MIR_TYPE_KIND_I32);
    try expect(typ.size_bytes == 4usize);
    try expect(typ.align_bytes == 4usize);

    const function: &MirFunction = semantic_vector_item_ptr(&module.functions, 0usize) as &MirFunction;
    try expect(function != null);
    try assert_eq_i32(function.function_id, 0);
    try assert_eq_i32(function.lowered_function_id, 0);
    try assert_eq_i32(function.source_core_body_id, 0);
    try assert_eq_i32(function.block_count, 1);
    try assert_eq_i32(function.entry_block_id, 0);

    const block: &MirBlock = semantic_vector_item_ptr(&module.blocks, 0usize) as &MirBlock;
    try expect(block != null);
    try assert_eq_i32(block.block_id, 0);
    try assert_eq_i32(block.function_id, 0);
    try assert_eq_i32(block.inst_count, 0);
    try assert_eq_i32(block.terminator_id, 0);

    const operand: &MirOperand = semantic_vector_item_ptr(&module.operands, 0usize) as &MirOperand;
    try expect(operand != null);
    try assert_eq_i32(operand.value_id, MIR_VALUE_INVALID_ID);
    try assert_eq_i32(operand.local_id, MIR_LOCAL_INVALID_ID);
    try assert_eq_i32(operand.type_id, 0);
    try assert_eq_i32(operand.immediate_i32, 7);

    const terminator: &MirTerminator = semantic_vector_item_ptr(&module.terminators, 0usize) as &MirTerminator;
    try expect(terminator != null);
    try assert_eq_i32(terminator.kind, MIR_TERMINATOR_KIND_RETURN);
    try assert_eq_i32(terminator.operand_start, 0);
    try assert_eq_i32(terminator.operand_count, 1);

    var verifier: MirVerifierResult = MirVerifierResult{
        error_code: -1,
        function_id: MIR_FUNCTION_INVALID_ID,
        block_id: MIR_BLOCK_INVALID_ID,
        inst_id: MIR_INST_INVALID_ID,
        value_id: MIR_VALUE_INVALID_ID,
        type_id: MIR_TYPE_INVALID_ID,
        operand_id: -1,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
    };
    portable_mir_verifier_result_init(&verifier);
    try assert_eq_i32(portable_mir_verify_module(&module, &verifier), 0);
}

test "CoreBody return i32 add lowers local and value use operands" {
    var source_functions: [ConcreteFunction: 1] = [];
    var source_bodies: [CoreBody: 1] = [];
    var source_stmts: [CoreStmt: 1] = [];
    var source_exprs: [CoreExpr: 3] = [];
    source_functions[0] = ConcreteFunction{
        function_id: 0,
        decl_id: 30,
        mono_instance_id: -1,
        body_start: 0,
        body_count: 1,
        flags: 0,
    };
    source_bodies[0] = CoreBody{
        body_id: 0,
        function_id: 0,
        decl_id: 30,
        root_stmt_start: 0,
        root_stmt_count: 1,
        expr_start: 0,
        expr_count: 3,
        place_start: 0,
        place_count: 1,
        cleanup_edge_start: 0,
        cleanup_edge_count: 0,
        semantic_fact_start: 0,
        semantic_fact_count: 0,
        source_span_id: 170,
        flags: 0,
    };
    source_exprs[0] = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_LOCAL_REF,
        body_id: 0,
        source_expr_id: 40,
        type_id: 0,
        literal_i64: 0i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 0,
        target_function_id: -1,
        target_decl_id: -1,
        field_id: -1,
        proof_result_id: -1,
        capability_id: 0,
        source_span_id: 171,
        flags: 0,
    };
    source_exprs[1] = CoreExpr{
        expr_id: 1,
        kind: CORE_EXPR_KIND_INT_LITERAL,
        body_id: 0,
        source_expr_id: 41,
        type_id: 0,
        literal_i64: 5i64,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: -1,
        target_decl_id: -1,
        field_id: -1,
        proof_result_id: -1,
        capability_id: 0,
        source_span_id: 172,
        flags: 0,
    };
    source_exprs[2] = CoreExpr{
        expr_id: 2,
        kind: CORE_EXPR_KIND_I32_ADD,
        body_id: 0,
        source_expr_id: 42,
        type_id: 0,
        literal_i64: 0i64,
        lhs_expr_id: 0,
        rhs_expr_id: 1,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        target_function_id: -1,
        target_decl_id: -1,
        field_id: -1,
        proof_result_id: -1,
        capability_id: 0,
        source_span_id: 173,
        flags: 0,
    };
    source_stmts[0] = CoreStmt{
        stmt_id: 0,
        kind: CORE_STMT_KIND_RETURN,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 2,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: 0,
        source_span_id: 174,
        cleanup_scope_id: 0,
        flags: 0,
    };
    var lowered: LoweredProgram = LoweredProgram{
        functions: fixture_vec(&source_functions[0] as &byte, @size_of(ConcreteFunction), 1usize, 1usize),
        core_bodies: fixture_vec(&source_bodies[0] as &byte, @size_of(CoreBody), 1usize, 1usize),
        core_stmts: fixture_vec(&source_stmts[0] as &byte, @size_of(CoreStmt), 1usize, 1usize),
        core_exprs: fixture_vec(&source_exprs[0] as &byte, @size_of(CoreExpr), 3usize, 3usize),
    };

    var mir_functions: [MirFunction: 1] = [];
    var mir_blocks: [MirBlock: 1] = [];
    var mir_values: [MirValue: 1] = [];
    var mir_types: [MirType: 1] = [];
    var mir_locals: [MirLocal: 1] = [];
    var mir_insts: [MirInst: 1] = [];
    var mir_operands: [MirOperand: 3] = [];
    var mir_terminators: [MirTerminator: 1] = [];
    var arena: CompilerArena = CompilerArena{ marker: 0 };
    var module: PortableMirModule = PortableMirModule{
        arena: &arena,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_ACTIVE,
        target_profile: portable_mir_target_profile_hosted_native(),
        function_count: 0usize,
        block_count: 0usize,
        value_count: 0usize,
        type_count: 0usize,
        local_count: 0usize,
        inst_count: 0usize,
        terminator_count: 0usize,
        operand_count: 0usize,
        block_param_count: 0usize,
        successor_count: 0usize,
        debug_loc_count: 0usize,
        capability_req_count: 0usize,
        functions: fixture_vec(&mir_functions[0] as &byte, @size_of(MirFunction), 0usize, 1usize),
        blocks: fixture_vec(&mir_blocks[0] as &byte, @size_of(MirBlock), 0usize, 1usize),
        values: fixture_vec(&mir_values[0] as &byte, @size_of(MirValue), 0usize, 1usize),
        types: fixture_vec(&mir_types[0] as &byte, @size_of(MirType), 0usize, 1usize),
        locals: fixture_vec(&mir_locals[0] as &byte, @size_of(MirLocal), 0usize, 1usize),
        insts: fixture_vec(&mir_insts[0] as &byte, @size_of(MirInst), 0usize, 1usize),
        terminators: fixture_vec(&mir_terminators[0] as &byte, @size_of(MirTerminator), 0usize, 1usize),
        operands: fixture_vec(&mir_operands[0] as &byte, @size_of(MirOperand), 0usize, 3usize),
        block_params: fixture_vec(null, @size_of(MirBlockParam), 0usize, 0usize),
        successors: fixture_vec(null, @size_of(MirSuccessor), 0usize, 0usize),
        debug_locs: fixture_vec(null, @size_of(MirDebugLoc), 0usize, 0usize),
        capability_reqs: fixture_vec(null, @size_of(MirCapabilityReq), 0usize, 0usize),
    };

    try assert_eq_i32(portable_mir_lower_core_body_to_module(&lowered, 0, &module), 0);
    try expect(module.function_count == 1usize);
    try expect(module.block_count == 1usize);
    try expect(module.type_count == 1usize);
    try expect(module.local_count == 1usize);
    try expect(module.value_count == 1usize);
    try expect(module.inst_count == 1usize);
    try expect(module.operand_count == 3usize);
    try expect(module.terminator_count == 1usize);

    const function: &MirFunction = semantic_vector_item_ptr(&module.functions, 0usize) as &MirFunction;
    try expect(function != null);
    try assert_eq_i32(function.local_start, 0);
    try assert_eq_i32(function.local_count, 1);

    const block: &MirBlock = semantic_vector_item_ptr(&module.blocks, 0usize) as &MirBlock;
    try expect(block != null);
    try assert_eq_i32(block.inst_start, 0);
    try assert_eq_i32(block.inst_count, 1);

    const local: &MirLocal = semantic_vector_item_ptr(&module.locals, 0usize) as &MirLocal;
    try expect(local != null);
    try assert_eq_i32(local.local_id, 0);
    try assert_eq_i32(local.type_id, 0);

    const value: &MirValue = semantic_vector_item_ptr(&module.values, 0usize) as &MirValue;
    try expect(value != null);
    try assert_eq_i32(value.value_id, 0);
    try assert_eq_i32(value.defining_inst_id, 0);
    try assert_eq_i32(value.type_id, 0);
    try assert_eq_i32(value.source_expr_id, 42);

    const inst: &MirInst = semantic_vector_item_ptr(&module.insts, 0usize) as &MirInst;
    try expect(inst != null);
    try assert_eq_i32(inst.op, MIR_INST_OP_I32_ADD);
    try assert_eq_i32(inst.type_id, 0);
    try assert_eq_i32(inst.result_value_id, 0);
    try assert_eq_i32(inst.operand_start, 0);
    try assert_eq_i32(inst.operand_count, 2);

    const lhs_operand: &MirOperand = semantic_vector_item_ptr(&module.operands, 0usize) as &MirOperand;
    const rhs_operand: &MirOperand = semantic_vector_item_ptr(&module.operands, 1usize) as &MirOperand;
    const result_operand: &MirOperand = semantic_vector_item_ptr(&module.operands, 2usize) as &MirOperand;
    try expect(lhs_operand != null);
    try expect(rhs_operand != null);
    try expect(result_operand != null);
    try assert_eq_i32(lhs_operand.local_id, 0);
    try assert_eq_i32(lhs_operand.value_id, MIR_VALUE_INVALID_ID);
    try assert_eq_i32(lhs_operand.type_id, 0);
    try assert_eq_i32(rhs_operand.local_id, MIR_LOCAL_INVALID_ID);
    try assert_eq_i32(rhs_operand.value_id, MIR_VALUE_INVALID_ID);
    try assert_eq_i32(rhs_operand.type_id, 0);
    try assert_eq_i32(rhs_operand.immediate_i32, 5);
    try assert_eq_i32(result_operand.value_id, 0);
    try assert_eq_i32(result_operand.local_id, MIR_LOCAL_INVALID_ID);
    try assert_eq_i32(result_operand.type_id, 0);

    const terminator: &MirTerminator = semantic_vector_item_ptr(&module.terminators, 0usize) as &MirTerminator;
    try expect(terminator != null);
    try assert_eq_i32(terminator.kind, MIR_TERMINATOR_KIND_RETURN);
    try assert_eq_i32(terminator.operand_start, 2);
    try assert_eq_i32(terminator.operand_count, 1);

    var verifier: MirVerifierResult = MirVerifierResult{
        error_code: -1,
        function_id: MIR_FUNCTION_INVALID_ID,
        block_id: MIR_BLOCK_INVALID_ID,
        inst_id: MIR_INST_INVALID_ID,
        value_id: MIR_VALUE_INVALID_ID,
        type_id: MIR_TYPE_INVALID_ID,
        operand_id: -1,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
    };
    portable_mir_verifier_result_init(&verifier);
    try assert_eq_i32(portable_mir_verify_module(&module, &verifier), 0);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)
echo "OK: PortableMIR CoreBody return literal/local/add lowering verified"
