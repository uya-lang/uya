#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR verifier contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_VERIFIER_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for symbol in \
    MirVerifierResult \
    MIR_VERIFY_ERR_MISSING_TERMINATOR \
    MIR_VERIFY_ERR_UNDEFINED_USE \
    MIR_VERIFY_ERR_TYPE_MISMATCH \
    MIR_VERIFY_ERR_INVALID_ADDRESS \
    MIR_VERIFY_ERR_INVALID_ATOMIC \
    MIR_VERIFY_ERR_INVALID_VECTOR_MASK \
    MIR_VERIFY_ERR_INVALID_CLEANUP \
    MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY \
    MIR_VERIFY_ERR_INVALID_NAKED_BODY \
    portable_mir_verify_module; do
    require_pattern "$MIR_VERIFIER_FILE" "$symbol" "verifier symbol $symbol"
done

require_pattern "$MIR_FILE" 'MIR_INST_OP_I32_LE' "PortableMIR i32 <= opcode"
require_pattern "$MIR_FILE" 'MIR_INST_OP_LOCAL_SET' "PortableMIR local assignment opcode"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_inst_op_is_integer_compare' "verifier validates integer comparison shape"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_integer_value_inst' "verifier validates integer value expressions"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_INST_OP_LOCAL_SET' "verifier validates local assignment shape"

require_pattern "$MIR_VERIFIER_FILE" 'semantic_vector_item_ptr' "linear table traversal"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_function_has_asm_only_naked_body' "naked body verifier hook"
require_pattern "$PORTABLE_MIR_DOC" 'MIR verifier 是所有 backend 的强制门禁' "whitepaper verifier gate"
require_pattern "$PORTABLE_MIR_DOC" 'block 有且只有一个 terminator' "whitepaper block terminator rule"
require_pattern "$PORTABLE_MIR_DOC" 'atomic / vector / mask' "whitepaper atomic/vector/mask rule"
require_pattern "$PORTABLE_MIR_DOC" 'target capability' "whitepaper target capability rule"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-verifier.XXXXXX)"
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

export const CORE_STMT_INVALID_ID: CoreStmtId = -1;
export const CORE_EXPR_INVALID_ID: CoreExprId = -1;
export const CORE_PLACE_INVALID_ID: CorePlaceId = -1;
export const CORE_STMT_KIND_RETURN: i32 = 10;
export const CORE_STMT_KIND_EXPR: i32 = 19;
export const CORE_EXPR_KIND_CALL: i32 = 11;
export const CORE_EXPR_KIND_INT_LITERAL: i32 = 17;
export const CORE_EXPR_KIND_LOCAL_REF: i32 = 18;
export const CORE_EXPR_KIND_I32_ADD: i32 = 20;
export const MIR_CALL_CONV_UYA: i32 = 1;
export const MIR_RUNTIME_CAP_HOSTED_LIBC: i32 = 1;

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
    if vec == null || item == null {
        return -1;
    }
    vec.count = vec.count + 1usize;
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

cat >>"$tmp_dir/main.uya" <<'EOF'
export const MIR_CALL_CONV_C: i32 = 2;
export const MIR_RUNTIME_CAP_C_EXTERN: i32 = 2;
EOF

cat "$MIR_FILE" "$MIR_VERIFIER_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn verifier_vec(data: &byte, item_size: usize, count: usize) SemanticVector {
    return SemanticVector{
        data: data,
        item_size: item_size,
        count: count,
        capacity: count,
        bytes: item_size * count,
        realloc_count: 0,
    };
}

fn verifier_empty_vec(item_size: usize) SemanticVector {
    return verifier_vec(null, item_size, 0usize);
}

fn verifier_profile() MirTargetProfile {
    return MirTargetProfile{
        profile_id: 0,
        pointer_size: 8,
        endianness: 0,
        default_address_space: MIR_ADDRESS_SPACE_GENERIC,
        runtime_mode: MIR_RUNTIME_MODE_HOSTED,
        call_abi_profile: MIR_CALL_ABI_PROFILE_HOSTED_SYSV,
        supported_address_spaces: MIR_ADDRESS_SPACE_GENERIC + MIR_ADDRESS_SPACE_HOST,
        supported_calling_conventions: 3,
        runtime_capability_mask: 3,
        feature_flags: 0,
    };
}

fn verifier_type(id: i32, kind: i32) MirType {
    var typ: MirType = MirType{
        type_id: id,
        kind: kind,
        source_type_id: id,
        size_bytes: 4usize,
        align_bytes: 4usize,
        layout_id: 100 + id,
        tag_offset_bytes: 0usize,
        payload_offset_bytes: 0usize,
        atomic_align_bytes: 0usize,
        element_type_id: MIR_TYPE_INVALID_ID,
        pointee_type_id: MIR_TYPE_INVALID_ID,
        field_start: 0,
        field_count: 0,
        lane_count: 0,
        lane_stride_bytes: 0usize,
        mask_representation: 0,
        abi_class: 1,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        flags: 0,
    };
    if kind == MIR_TYPE_KIND_POINTER {
        typ.size_bytes = 8usize;
        typ.align_bytes = 8usize;
        typ.pointee_type_id = 0;
        typ.address_space = MIR_ADDRESS_SPACE_HOST;
    }
    if kind == MIR_TYPE_KIND_BOOL || kind == MIR_TYPE_KIND_I8 ||
       kind == MIR_TYPE_KIND_U8 || kind == MIR_TYPE_KIND_BYTE {
        typ.size_bytes = 1usize;
        typ.align_bytes = 1usize;
    }
    if kind == MIR_TYPE_KIND_I16 || kind == MIR_TYPE_KIND_U16 {
        typ.size_bytes = 2usize;
        typ.align_bytes = 2usize;
    }
    if kind == MIR_TYPE_KIND_U32 || kind == MIR_TYPE_KIND_F32 {
        typ.size_bytes = 4usize;
        typ.align_bytes = 4usize;
    }
    if kind == MIR_TYPE_KIND_I64 || kind == MIR_TYPE_KIND_U64 ||
       kind == MIR_TYPE_KIND_ISIZE || kind == MIR_TYPE_KIND_USIZE ||
       kind == MIR_TYPE_KIND_F64 {
        typ.size_bytes = 8usize;
        typ.align_bytes = 8usize;
    }
    if kind == MIR_TYPE_KIND_ARRAY {
        typ.size_bytes = 16usize;
        typ.align_bytes = 4usize;
        typ.element_type_id = 0;
        typ.field_count = 4;
        typ.lane_count = 4;
    }
    if kind == MIR_TYPE_KIND_SLICE {
        typ.size_bytes = 16usize;
        typ.align_bytes = 8usize;
        typ.tag_offset_bytes = 0usize;
        typ.payload_offset_bytes = 8usize;
        typ.element_type_id = 0;
        typ.pointee_type_id = 1;
        typ.field_count = 2;
        typ.lane_count = 2;
    }
    if kind == MIR_TYPE_KIND_ERROR_UNION {
        typ.size_bytes = 16usize;
        typ.align_bytes = 8usize;
        typ.tag_offset_bytes = 0usize;
        typ.payload_offset_bytes = 8usize;
        typ.abi_class = 3;
    }
    if kind == MIR_TYPE_KIND_FUNCTION {
        typ.size_bytes = 8usize;
        typ.align_bytes = 8usize;
        typ.element_type_id = 0;
        typ.field_start = 0;
        typ.field_count = 2;
        typ.abi_class = 4;
        typ.flags = MIR_CALL_CONV_UYA;
    }
    if kind == MIR_TYPE_KIND_FUNCTION_POINTER {
        typ.size_bytes = 8usize;
        typ.align_bytes = 8usize;
        typ.element_type_id = 0;
        typ.pointee_type_id = 20;
        typ.abi_class = 4;
        typ.flags = MIR_CALL_CONV_UYA;
    }
    if kind == MIR_TYPE_KIND_STRUCT {
        typ.size_bytes = 4usize;
        typ.align_bytes = 4usize;
        typ.field_start = 0;
        typ.field_count = 1;
    }
    if kind == MIR_TYPE_KIND_ATOMIC {
        typ.atomic_align_bytes = 4usize;
        typ.element_type_id = 0;
    }
    if kind == MIR_TYPE_KIND_VECTOR {
        typ.size_bytes = 16usize;
        typ.align_bytes = 16usize;
        typ.element_type_id = 0;
        typ.lane_count = 4;
        typ.lane_stride_bytes = 4usize;
    }
    if kind == MIR_TYPE_KIND_MASK {
        typ.size_bytes = 1usize;
        typ.align_bytes = 1usize;
        typ.lane_count = 4;
        typ.mask_representation = 1;
    }
    return typ;
}

fn verifier_function_param_type(id: i32, owner_type_id: i32, param_index: i32,
    type_id: i32) MirFunctionParamType {
    return MirFunctionParamType{
        function_param_type_id: id,
        owner_type_id: owner_type_id,
        param_index: param_index,
        type_id: type_id,
        abi_class: 1,
        flags: 0,
    };
}

fn verifier_field_layout(id: i32, owner_type_id: i32, field_index: i32,
    field_type_id: i32) MirFieldLayout {
    return MirFieldLayout{
        field_layout_id: id,
        owner_type_id: owner_type_id,
        field_index: field_index,
        field_type_id: field_type_id,
        offset_bytes: 0usize,
        size_bytes: 4usize,
        align_bytes: 4usize,
        flags: 0,
    };
}

fn verifier_function() MirFunction {
    return MirFunction{
        function_id: 0,
        lowered_function_id: 1,
        decl_id: 2,
        source_core_body_id: 0,
        symbol_id: 3,
        signature_type_id: 0,
        param_start: 0,
        param_count: 1,
        local_start: 0,
        local_count: 1,
        block_start: 0,
        block_count: 1,
        entry_block_id: 0,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 1,
        calling_convention: 1,
        runtime_capability_mask: 1,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC,
        body_kind: MIR_FUNCTION_BODY_KIND_NORMAL,
        naked_asm_inst_start: -1,
        naked_asm_inst_count: 0,
        naked_forbidden_lowering_mask: 0,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn verifier_block() MirBlock {
    return MirBlock{
        block_id: 0,
        function_id: 0,
        param_start: 0,
        param_count: 0,
        inst_start: 0,
        inst_count: 1,
        terminator_id: 0,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn verifier_inst() MirInst {
    return MirInst{
        inst_id: 0,
        function_id: 0,
        block_id: 0,
        op: MIR_INST_OP_LOAD,
        type_id: 0,
        result_value_id: 1,
        operand_start: 0,
        operand_count: 1,
        calling_convention: 1,
        runtime_capability_mask: 0,
        address_space: MIR_ADDRESS_SPACE_HOST,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn verifier_value(id: i32, type_id: i32, defining_inst_id: i32, flags: i32) MirValue {
    return MirValue{
        value_id: id,
        function_id: 0,
        block_id: 0,
        type_id: type_id,
        defining_inst_id: defining_inst_id,
        local_id: MIR_LOCAL_INVALID_ID,
        param_index: -1,
        source_expr_id: id,
        debug_loc_id: 0,
        flags: flags,
    };
}

fn verifier_operand(id: i32, value_id: i32, type_id: i32) MirOperand {
    return MirOperand{
        operand_id: id,
        kind: 1,
        value_id: value_id,
        local_id: MIR_LOCAL_INVALID_ID,
        type_id: type_id,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        immediate_i32: 0,
        flags: 0,
    };
}

fn verifier_terminator() MirTerminator {
    return MirTerminator{
        terminator_id: 0,
        function_id: 0,
        block_id: 0,
        kind: MIR_TERMINATOR_KIND_RETURN,
        operand_start: 1,
        operand_count: 1,
        successor_start: 0,
        successor_count: 0,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn verifier_local() MirLocal {
    return MirLocal{
        local_id: 0,
        function_id: 0,
        type_id: 1,
        source_symbol_id: 9,
        address_space: MIR_ADDRESS_SPACE_HOST,
        alignment: 8usize,
        debug_loc_id: 0,
        flags: MIR_LOCAL_FLAG_ADDRESS_TAKEN,
    };
}

fn verifier_capability() MirCapabilityReq {
    return MirCapabilityReq{
        capability_req_id: 0,
        capability_id: 1,
        function_id: 0,
        inst_id: MIR_INST_INVALID_ID,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn verifier_empty_module() PortableMirModule {
    return PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_ACTIVE,
        target_profile: verifier_profile(),
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
        field_layout_count: 0usize,
        function_param_type_count: 0usize,
        functions: verifier_empty_vec(@size_of(MirFunction)),
        blocks: verifier_empty_vec(@size_of(MirBlock)),
        values: verifier_empty_vec(@size_of(MirValue)),
        types: verifier_empty_vec(@size_of(MirType)),
        locals: verifier_empty_vec(@size_of(MirLocal)),
        insts: verifier_empty_vec(@size_of(MirInst)),
        terminators: verifier_empty_vec(@size_of(MirTerminator)),
        operands: verifier_empty_vec(@size_of(MirOperand)),
        block_params: verifier_empty_vec(@size_of(MirBlockParam)),
        successors: verifier_empty_vec(@size_of(MirSuccessor)),
        debug_locs: verifier_empty_vec(@size_of(MirDebugLoc)),
        capability_reqs: verifier_empty_vec(@size_of(MirCapabilityReq)),
        field_layouts: verifier_empty_vec(@size_of(MirFieldLayout)),
        function_param_types: verifier_empty_vec(@size_of(MirFunctionParamType)),
    };
}

fn verifier_run(mode: i32) i32 {
    var functions: [MirFunction: 1] = [];
    var blocks: [MirBlock: 1] = [];
    var values: [MirValue: 2] = [];
    var types: [MirType: 29] = [];
    var locals: [MirLocal: 1] = [];
    var insts: [MirInst: 1] = [];
    var terminators: [MirTerminator: 1] = [];
    var operands: [MirOperand: 3] = [];
    var caps: [MirCapabilityReq: 1] = [];
    var field_layouts: [MirFieldLayout: 1] = [];
    var fn_params: [MirFunctionParamType: 2] = [];

    functions[0] = verifier_function();
    blocks[0] = verifier_block();
    values[0] = verifier_value(0, 1, MIR_INST_INVALID_ID, MIR_VALUE_FLAG_PARAM);
    values[1] = verifier_value(1, 0, 0, 0);
    types[0] = verifier_type(0, MIR_TYPE_KIND_I32);
    types[1] = verifier_type(1, MIR_TYPE_KIND_POINTER);
    types[2] = verifier_type(2, MIR_TYPE_KIND_ATOMIC);
    types[3] = verifier_type(3, MIR_TYPE_KIND_VECTOR);
    types[4] = verifier_type(4, MIR_TYPE_KIND_MASK);
    types[5] = verifier_type(5, MIR_TYPE_KIND_BOOL);
    types[6] = verifier_type(6, MIR_TYPE_KIND_I8);
    types[7] = verifier_type(7, MIR_TYPE_KIND_U8);
    types[8] = verifier_type(8, MIR_TYPE_KIND_I16);
    types[9] = verifier_type(9, MIR_TYPE_KIND_U16);
    types[10] = verifier_type(10, MIR_TYPE_KIND_U32);
    types[11] = verifier_type(11, MIR_TYPE_KIND_I64);
    types[12] = verifier_type(12, MIR_TYPE_KIND_U64);
    types[13] = verifier_type(13, MIR_TYPE_KIND_ISIZE);
    types[14] = verifier_type(14, MIR_TYPE_KIND_BYTE);
    types[15] = verifier_type(15, MIR_TYPE_KIND_F32);
    types[16] = verifier_type(16, MIR_TYPE_KIND_F64);
    types[17] = verifier_type(17, MIR_TYPE_KIND_ARRAY);
    types[18] = verifier_type(18, MIR_TYPE_KIND_SLICE);
    types[19] = verifier_type(19, MIR_TYPE_KIND_ERROR_UNION);
    types[20] = verifier_type(20, MIR_TYPE_KIND_FUNCTION);
    types[21] = verifier_type(21, MIR_TYPE_KIND_FUNCTION_POINTER);
    types[22] = verifier_type(22, MIR_TYPE_KIND_STRUCT);
    types[23] = verifier_type(23, MIR_TYPE_KIND_POINTER);
    types[23].pointee_type_id = 22;
    types[24] = verifier_type(24, MIR_TYPE_KIND_POINTER);
    types[24].pointee_type_id = 17;
    types[25] = verifier_type(25, MIR_TYPE_KIND_USIZE);
    types[26] = verifier_type(26, MIR_TYPE_KIND_POINTER);
    types[26].pointee_type_id = 18;
    types[27] = verifier_type(27, MIR_TYPE_KIND_POINTER);
    types[27].pointee_type_id = 1;
    types[28] = verifier_type(28, MIR_TYPE_KIND_POINTER);
    types[28].pointee_type_id = 25;
    locals[0] = verifier_local();
    insts[0] = verifier_inst();
    terminators[0] = verifier_terminator();
    operands[0] = verifier_operand(0, 0, 1);
    operands[1] = verifier_operand(1, 1, 0);
    operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 0);
    caps[0] = verifier_capability();
    field_layouts[0] = verifier_field_layout(0, 22, 0, 0);
    fn_params[0] = verifier_function_param_type(0, 20, 0, 0);
    fn_params[1] = verifier_function_param_type(1, 20, 1, 5);

    if mode == 1 {
        blocks[0].terminator_id = MIR_TERMINATOR_INVALID_ID;
    }
    if mode == 2 {
        values[1].type_id = 1;
    }
    if mode == 3 {
        insts[0].address_space = 64;
    }
    if mode == 4 {
        insts[0].op = 17;
    }
    if mode == 5 {
        insts[0].op = 21;
    }
    if mode == 6 {
        blocks[0].flags = MIR_BLOCK_FLAG_CLEANUP;
    }
    if mode == 7 {
        functions[0].calling_convention = 16;
    }
    if mode == 8 {
        values[0].flags = 0;
    }
    if mode == 9 {
        functions[0].flags = MIR_FUNCTION_FLAG_NAKED;
    }
    if mode == 10 {
        types[0].align_bytes = 0usize;
    }
    if mode == 11 {
        caps[0].function_id = 99;
    }
    if mode == 12 {
        functions[0].cleanup_model = 1;
    }
    if mode == 13 {
        types[4].mask_representation = 0;
    }
    if mode == 14 {
        insts[0].op = MIR_INST_OP_I32_LE;
        insts[0].type_id = 5;
        insts[0].operand_count = 2;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 0);
        operands[1] = verifier_operand(1, 0, 0);
    }
    if mode == 15 {
        insts[0].op = MIR_INST_OP_LOCAL_SET;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        locals[0].type_id = 0;
        locals[0].address_space = MIR_ADDRESS_SPACE_GENERIC;
        locals[0].alignment = 4usize;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 0);
        operands[0].local_id = 0;
        operands[1] = verifier_operand(1, 0, 0);
    }
    if mode == 16 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 0;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
    }
    if mode == 17 {
        insts[0].op = MIR_INST_OP_U64_ADD;
        insts[0].type_id = 12;
        insts[0].operand_count = 2;
        values[0].type_id = 12;
        values[1].type_id = 12;
        operands[0] = verifier_operand(0, 0, 12);
        operands[1] = verifier_operand(1, 0, 12);
    }
    if mode == 18 {
        insts[0].op = MIR_INST_OP_U64_ADD;
        insts[0].type_id = 12;
        insts[0].operand_count = 2;
        values[0].type_id = 12;
        values[1].type_id = 12;
        operands[0] = verifier_operand(0, 0, 12);
        operands[1] = verifier_operand(1, 0, 0);
    }
    if mode == 19 {
        insts[0].op = MIR_INST_OP_U32_GE;
        insts[0].type_id = 5;
        insts[0].operand_count = 2;
        values[0].type_id = 10;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 10);
        operands[1] = verifier_operand(1, 0, 10);
    }
    if mode == 20 {
        insts[0].op = MIR_INST_OP_U32_GE;
        insts[0].type_id = 10;
        insts[0].operand_count = 2;
        values[0].type_id = 10;
        values[1].type_id = 10;
        operands[0] = verifier_operand(0, 0, 10);
        operands[1] = verifier_operand(1, 0, 10);
    }
    if mode == 21 {
        insts[0].op = MIR_INST_OP_INT_NEG;
        insts[0].type_id = 11;
        insts[0].operand_count = 1;
        values[0].type_id = 11;
        values[1].type_id = 11;
        operands[0] = verifier_operand(0, 0, 11);
    }
    if mode == 22 {
        insts[0].op = MIR_INST_OP_INT_NEG;
        insts[0].type_id = 11;
        insts[0].operand_count = 1;
        values[0].type_id = 11;
        values[1].type_id = 11;
        operands[0] = verifier_operand(0, 0, 12);
    }
    if mode == 23 {
        insts[0].op = MIR_INST_OP_BOOL_AND;
        insts[0].type_id = 5;
        insts[0].operand_count = 2;
        values[0].type_id = 5;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 5);
        operands[1] = verifier_operand(1, 0, 5);
    }
    if mode == 24 {
        insts[0].op = MIR_INST_OP_BOOL_NOT;
        insts[0].type_id = 5;
        insts[0].operand_count = 1;
        values[0].type_id = 5;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 5);
    }
    if mode == 25 {
        insts[0].op = MIR_INST_OP_BOOL_AND;
        insts[0].type_id = 5;
        insts[0].operand_count = 2;
        values[0].type_id = 5;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 5);
        operands[1] = verifier_operand(1, 0, 0);
    }
    if mode == 26 {
        insts[0].op = MIR_INST_OP_INT_TO_F64;
        insts[0].type_id = 16;
        insts[0].operand_count = 1;
        values[0].type_id = 0;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, 0, 0);
    }
    if mode == 27 {
        insts[0].op = MIR_INST_OP_INT_TO_F64;
        insts[0].type_id = 16;
        insts[0].operand_count = 1;
        values[0].type_id = 16;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, 0, 16);
    }
    if mode == 28 {
        insts[0].op = MIR_INST_OP_SIGN_EXTEND;
        insts[0].type_id = 11;
        insts[0].operand_count = 1;
        values[0].type_id = 8;
        values[1].type_id = 11;
        operands[0] = verifier_operand(0, 0, 8);
    }
    if mode == 29 {
        insts[0].op = MIR_INST_OP_SIGN_EXTEND;
        insts[0].type_id = 8;
        insts[0].operand_count = 1;
        values[0].type_id = 11;
        values[1].type_id = 8;
        operands[0] = verifier_operand(0, 0, 11);
    }
    if mode == 30 {
        insts[0].op = MIR_INST_OP_TRUNCATE;
        insts[0].type_id = 8;
        insts[0].operand_count = 1;
        values[0].type_id = 11;
        values[1].type_id = 8;
        operands[0] = verifier_operand(0, 0, 11);
    }
    if mode == 31 {
        insts[0].op = MIR_INST_OP_TRUNCATE;
        insts[0].type_id = 11;
        insts[0].operand_count = 1;
        values[0].type_id = 8;
        values[1].type_id = 11;
        operands[0] = verifier_operand(0, 0, 8);
    }
    if mode == 32 {
        insts[0].op = MIR_INST_OP_F64_TO_INT;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        values[0].type_id = 16;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 16);
    }
    if mode == 33 {
        insts[0].op = MIR_INST_OP_F64_TO_INT;
        insts[0].type_id = 15;
        insts[0].operand_count = 1;
        values[0].type_id = 16;
        values[1].type_id = 15;
        operands[0] = verifier_operand(0, 0, 16);
    }
    if mode == 34 {
        insts[0].op = MIR_INST_OP_F32_TO_F64;
        insts[0].type_id = 16;
        insts[0].operand_count = 1;
        values[0].type_id = 15;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, 0, 15);
    }
    if mode == 35 {
        insts[0].op = MIR_INST_OP_F64_TO_F32;
        insts[0].type_id = 15;
        insts[0].operand_count = 1;
        values[0].type_id = 16;
        values[1].type_id = 15;
        operands[0] = verifier_operand(0, 0, 16);
    }
    if mode == 36 {
        insts[0].op = MIR_INST_OP_F32_TO_F64;
        insts[0].type_id = 15;
        insts[0].operand_count = 1;
        values[0].type_id = 15;
        values[1].type_id = 15;
        operands[0] = verifier_operand(0, 0, 15);
    }
    if mode == 37 {
        insts[0].op = MIR_INST_OP_F64_TO_F32;
        insts[0].type_id = 16;
        insts[0].operand_count = 1;
        values[0].type_id = 16;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, 0, 16);
    }
    if mode == 38 {
        insts[0].op = MIR_INST_OP_CONST_F32;
        insts[0].type_id = 15;
        insts[0].operand_count = 0;
        values[1].type_id = 15;
    }
    if mode == 39 {
        insts[0].op = MIR_INST_OP_CONST_F32;
        insts[0].type_id = 0;
        insts[0].operand_count = 0;
        values[1].type_id = 0;
    }
    if mode == 40 {
        insts[0].op = MIR_INST_OP_F64_ADD;
        insts[0].type_id = 16;
        insts[0].operand_count = 2;
        values[0].type_id = 16;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, 0, 16);
        operands[1] = verifier_operand(1, 0, 16);
    }
    if mode == 41 {
        insts[0].op = MIR_INST_OP_F64_ADD;
        insts[0].type_id = 16;
        insts[0].operand_count = 2;
        values[0].type_id = 16;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, 0, 16);
        operands[1] = verifier_operand(1, 0, 15);
    }
    if mode == 42 {
        insts[0].op = MIR_INST_OP_F32_LE;
        insts[0].type_id = 5;
        insts[0].operand_count = 2;
        values[0].type_id = 15;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 15);
        operands[1] = verifier_operand(1, 0, 15);
    }
    if mode == 43 {
        insts[0].op = MIR_INST_OP_F32_LE;
        insts[0].type_id = 15;
        insts[0].operand_count = 2;
        values[0].type_id = 15;
        values[1].type_id = 15;
        operands[0] = verifier_operand(0, 0, 15);
        operands[1] = verifier_operand(1, 0, 15);
    }
    if mode == 44 {
        insts[0].op = MIR_INST_OP_F32_LE;
        insts[0].type_id = 5;
        insts[0].operand_count = 2;
        values[0].type_id = 15;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 15);
        operands[1] = verifier_operand(1, 0, 16);
    }
    if mode == 45 {
        functions[0].signature_type_id = 20;
        types[20].element_type_id = 16;
        insts[0].type_id = 16;
        values[0].type_id = 16;
        values[1].type_id = 16;
        operands[1] = verifier_operand(1, 1, 16);
    }
    if mode == 46 {
        functions[0].signature_type_id = 20;
        types[20].element_type_id = 16;
        insts[0].type_id = 15;
        values[0].type_id = 15;
        values[1].type_id = 15;
        operands[1] = verifier_operand(1, 1, 15);
    }
    if mode == 47 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 16;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        insts[0].calling_convention = MIR_CALL_CONV_C;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].immediate_i32 = 0;
        functions[0].flags = MIR_FUNCTION_FLAG_EXTERN;
        functions[0].calling_convention = MIR_CALL_CONV_C;
        functions[0].signature_type_id = 20;
        types[20].element_type_id = 16;
        operands[1] = verifier_operand(1, 1, 16);
    }
    if mode == 48 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 15;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        insts[0].calling_convention = MIR_CALL_CONV_C;
        values[1].type_id = 15;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].immediate_i32 = 0;
        functions[0].flags = MIR_FUNCTION_FLAG_EXTERN;
        functions[0].calling_convention = MIR_CALL_CONV_C;
        functions[0].signature_type_id = 20;
        types[20].element_type_id = 16;
        operands[1] = verifier_operand(1, 1, 15);
    }
    if mode == 49 {
        insts[0].op = MIR_INST_OP_ADDR_OF_LOCAL;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        locals[0].type_id = 0;
        locals[0].alignment = 4usize;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 0);
        operands[0].local_id = 0;
        operands[1] = verifier_operand(1, 1, 1);
    }
    if mode == 50 {
        insts[0].op = MIR_INST_OP_ADDR_OF_LOCAL;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        locals[0].type_id = 0;
        locals[0].alignment = 4usize;
        locals[0].flags = 0;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 0);
        operands[0].local_id = 0;
        operands[1] = verifier_operand(1, 1, 1);
    }
    if mode == 51 {
        insts[0].op = MIR_INST_OP_ADDR_OF_PARAM;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[0].type_id = 0;
        values[0].param_index = 0;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 0);
        operands[1] = verifier_operand(1, 1, 1);
    }
    if mode == 52 {
        insts[0].op = MIR_INST_OP_ADDR_OF_GLOBAL;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 0);
        operands[0].immediate_i32 = 7;
        operands[1] = verifier_operand(1, 1, 1);
    }
    if mode == 53 {
        insts[0].op = MIR_INST_OP_FIELD_ADDR;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 23;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 23);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 22);
        operands[1].immediate_i32 = 0;
    }
    if mode == 54 {
        insts[0].op = MIR_INST_OP_FIELD_LOAD;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 23;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 23);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 22);
        operands[1].immediate_i32 = 0;
    }
    if mode == 55 {
        insts[0].op = MIR_INST_OP_FIELD_STORE;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 3;
        values[0].type_id = 23;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 23);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 22);
        operands[1].immediate_i32 = 0;
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 0);
    }
    if mode == 56 {
        insts[0].op = MIR_INST_OP_FIELD_ADDR;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 23;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 23);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 22);
        operands[1].immediate_i32 = 2;
    }
    if mode == 57 {
        insts[0].op = MIR_INST_OP_INDEX_ADDR;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 24;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 24);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[1].immediate_i32 = 2;
    }
    if mode == 58 {
        insts[0].op = MIR_INST_OP_INDEX_LOAD;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 24;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 24);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[1].immediate_i32 = 2;
    }
    if mode == 59 {
        insts[0].op = MIR_INST_OP_INDEX_STORE;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 3;
        values[0].type_id = 24;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 24);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[1].immediate_i32 = 2;
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 0);
    }
    if mode == 60 {
        insts[0].op = MIR_INST_OP_INDEX_LOAD;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_BOUNDS_CHECKED;
        values[0].type_id = 24;
        values[1].type_id = 0;
        locals[0].type_id = 0;
        locals[0].alignment = 4usize;
        operands[0] = verifier_operand(0, 0, 24);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[1].local_id = 0;
    }
    if mode == 61 {
        insts[0].op = MIR_INST_OP_INDEX_LOAD;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 24;
        values[1].type_id = 0;
        locals[0].type_id = 0;
        locals[0].alignment = 4usize;
        operands[0] = verifier_operand(0, 0, 24);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[1].local_id = 0;
    }
    if mode == 62 {
        insts[0].op = MIR_INST_OP_SLICE_PTR_ADDR;
        insts[0].type_id = 27;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[0].type_id = 26;
        values[1].type_id = 27;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 26);
    }
    if mode == 63 {
        insts[0].op = MIR_INST_OP_SLICE_PTR_LOAD;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[0].type_id = 26;
        values[1].type_id = 1;
        operands[0] = verifier_operand(0, 0, 26);
    }
    if mode == 64 {
        insts[0].op = MIR_INST_OP_SLICE_LEN_ADDR;
        insts[0].type_id = 28;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[0].type_id = 26;
        values[1].type_id = 28;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 26);
    }
    if mode == 65 {
        insts[0].op = MIR_INST_OP_SLICE_LEN_LOAD;
        insts[0].type_id = 25;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[0].type_id = 26;
        values[1].type_id = 25;
        operands[0] = verifier_operand(0, 0, 26);
    }
    if mode == 66 {
        insts[0].op = MIR_INST_OP_SLICE_INDEX_ADDR;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_BOUNDS_CHECKED;
        values[0].type_id = 26;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 26);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
    }
    if mode == 67 {
        insts[0].op = MIR_INST_OP_SLICE_INDEX_LOAD;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_BOUNDS_CHECKED;
        values[0].type_id = 26;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 26);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
    }
    if mode == 68 {
        insts[0].op = MIR_INST_OP_SLICE_INDEX_STORE;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_INST_FLAG_BOUNDS_CHECKED;
        values[0].type_id = 26;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 26);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 0);
    }
    if mode == 69 {
        insts[0].op = MIR_INST_OP_SLICE_INDEX_LOAD;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 26;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 26);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
    }
    if mode == 70 {
        insts[0].op = MIR_INST_OP_POINTER_OFFSET;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_OVERFLOW_CHECKED;
        values[0].type_id = 1;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 1);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[1].immediate_i32 = 2;
    }
    if mode == 71 {
        insts[0].op = MIR_INST_OP_POINTER_OFFSET;
        insts[0].type_id = 1;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 1;
        values[1].type_id = 1;
        values[1].flags = MIR_VALUE_FLAG_ADDRESS;
        operands[0] = verifier_operand(0, 0, 1);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[1].immediate_i32 = 2;
    }

    var module: PortableMirModule = verifier_empty_module();
    module.functions = verifier_vec(&functions[0] as &byte, @size_of(MirFunction), 1usize);
    module.blocks = verifier_vec(&blocks[0] as &byte, @size_of(MirBlock), 1usize);
    module.values = verifier_vec(&values[0] as &byte, @size_of(MirValue), 2usize);
    module.types = verifier_vec(&types[0] as &byte, @size_of(MirType), 29usize);
    module.locals = verifier_vec(&locals[0] as &byte, @size_of(MirLocal), 1usize);
    module.insts = verifier_vec(&insts[0] as &byte, @size_of(MirInst), 1usize);
    module.terminators = verifier_vec(&terminators[0] as &byte, @size_of(MirTerminator), 1usize);
    module.operands = verifier_vec(&operands[0] as &byte, @size_of(MirOperand), 3usize);
    module.capability_reqs = verifier_vec(&caps[0] as &byte, @size_of(MirCapabilityReq), 1usize);
    module.field_layouts = verifier_vec(&field_layouts[0] as &byte,
        @size_of(MirFieldLayout), 1usize);
    module.function_param_types = verifier_vec(&fn_params[0] as &byte,
        @size_of(MirFunctionParamType), 2usize);
    module.function_count = 1usize;
    module.block_count = 1usize;
    module.value_count = 2usize;
    module.type_count = 29usize;
    module.local_count = 1usize;
    module.inst_count = 1usize;
    module.terminator_count = 1usize;
    module.operand_count = 3usize;
    module.capability_req_count = 1usize;
    module.field_layout_count = 1usize;
    module.function_param_type_count = 2usize;

    var result: MirVerifierResult = MirVerifierResult{
        error_code: 0,
        function_id: 0,
        block_id: 0,
        inst_id: 0,
        value_id: 0,
        type_id: 0,
        operand_id: 0,
        capability_req_id: 0,
        debug_loc_id: 0,
    };
    _ = portable_mir_verify_module(&module, &result);
    return result.error_code;
}

test "PortableMIR verifier accepts a complete linear module" {
    try assert_eq_i32(verifier_run(0), MIR_VERIFY_OK);
}

test "PortableMIR verifier accepts partial surface for compare assign and call statement" {
    try assert_eq_i32(verifier_run(14), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(15), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(16), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(17), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(19), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(21), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(23), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(24), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(26), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(28), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(30), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(32), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(34), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(35), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(38), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(40), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(42), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(45), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(47), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(49), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(51), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(52), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(53), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(54), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(55), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(57), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(58), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(59), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(60), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(62), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(63), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(64), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(65), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(66), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(67), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(68), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(70), MIR_VERIFY_OK);
}

test "PortableMIR verifier rejects malformed control and data flow" {
    try assert_eq_i32(verifier_run(1), MIR_VERIFY_ERR_MISSING_TERMINATOR);
    try assert_eq_i32(verifier_run(2), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(8), MIR_VERIFY_ERR_UNDEFINED_USE);
    try assert_eq_i32(verifier_run(18), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(20), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(22), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(25), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(27), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(29), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(31), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(33), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(36), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(37), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(39), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(41), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(43), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(44), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(46), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(48), MIR_VERIFY_ERR_TYPE_MISMATCH);
}

test "PortableMIR verifier rejects target and layout violations" {
    try assert_eq_i32(verifier_run(3), MIR_VERIFY_ERR_INVALID_ADDRESS);
    try assert_eq_i32(verifier_run(50), MIR_VERIFY_ERR_INVALID_ADDRESS);
    try assert_eq_i32(verifier_run(7), MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
    try assert_eq_i32(verifier_run(10), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(11), MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
    try assert_eq_i32(verifier_run(56), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(61), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(69), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(71), MIR_VERIFY_ERR_INVALID_ADDRESS);
}

test "PortableMIR verifier rejects atomic vector mask cleanup and naked violations" {
    try assert_eq_i32(verifier_run(4), MIR_VERIFY_ERR_INVALID_ATOMIC);
    try assert_eq_i32(verifier_run(5), MIR_VERIFY_ERR_INVALID_VECTOR_MASK);
    try assert_eq_i32(verifier_run(6), MIR_VERIFY_ERR_INVALID_CLEANUP);
    try assert_eq_i32(verifier_run(9), MIR_VERIFY_ERR_INVALID_NAKED_BODY);
    try assert_eq_i32(verifier_run(12), MIR_VERIFY_ERR_INVALID_CLEANUP);
    try assert_eq_i32(verifier_run(13), MIR_VERIFY_ERR_INVALID_VECTOR_MASK);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR verifier contract verified"
