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
require_pattern "$MIR_FILE" 'MIR_INST_OP_ATOMIC_INIT' "PortableMIR atomic init opcode"
require_pattern "$MIR_FILE" 'MIR_INST_FLAG_ATOMIC_ORDERED' "PortableMIR atomic ordered metadata flag"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_atomic_inst' "verifier validates atomic instruction shape"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_inst_op_is_atomic' "verifier classifies atomic opcodes explicitly"
require_pattern "$MIR_FILE" 'MIR_INST_OP_VECTOR_LOAD' "PortableMIR vector load opcode"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_vector_mask_inst' "verifier validates vector/mask instruction shape"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_inst_op_is_vector_mask' "verifier classifies vector/mask opcodes explicitly"
require_pattern "$MIR_FILE" 'MIR_INST_OP_DROP_VALUE' "PortableMIR drop value opcode"
require_pattern "$MIR_FILE" 'MIR_CLEANUP_MODEL_UNWIND' "PortableMIR cleanup unwind metadata"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_drop_inst' "verifier validates drop instruction shape"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_cleanup_model_known' "verifier validates cleanup model metadata"
require_pattern "$MIR_FILE" 'MIR_INST_OP_ERROR_UNION_IS_ERR' "PortableMIR error-union tag check opcode"
require_pattern "$MIR_FILE" 'MIR_ERROR_UNION_PATH_FAILURE' "PortableMIR error-union failure path metadata"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_error_union_inst' "verifier validates error-union instruction shape"
require_pattern "$MIR_FILE" 'MIR_INST_OP_ASYNC_FRAME_ALLOC' "PortableMIR async frame allocation opcode"
require_pattern "$MIR_FILE" 'MIR_ASYNC_FRAME_SLOT_CAPTURED_LOCAL' "PortableMIR async captured local metadata"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_async_frame_inst' "verifier validates async frame instruction shape"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_RUNTIME_CAP_ASYNC_FRAME' "verifier validates async frame capability"
require_pattern "$MIR_FILE" 'MirGlobal' "PortableMIR global metadata table"
require_pattern "$MIR_FILE" 'MirConst' "PortableMIR constant metadata table"
require_pattern "$MIR_FILE" 'MirLinkInput' "PortableMIR link input metadata table"
require_pattern "$MIR_FILE" 'MirCrossUnitSymbol' "PortableMIR cross-unit symbol metadata table"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_global_initializer' "verifier validates global initializer metadata"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_link_inputs' "verifier validates link input metadata"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_cross_unit_symbols' "verifier validates cross-unit symbol metadata"

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
export const CORE_STMT_KIND_IF: i32 = 17;
export const CORE_STMT_KIND_EXPR: i32 = 19;
export const CORE_STMT_KIND_WHILE: i32 = 20;
export const CORE_STMT_KIND_BLOCK: i32 = 21;
export const CORE_EXPR_KIND_CALL: i32 = 11;
export const CORE_EXPR_KIND_INT_LITERAL: i32 = 17;
export const CORE_EXPR_KIND_LOCAL_REF: i32 = 18;
export const CORE_EXPR_KIND_I32_ADD: i32 = 20;
export const MIR_CALL_CONV_UYA: i32 = 1;
export const MIR_RUNTIME_CAP_HOSTED_LIBC: i32 = 1;
export const MIR_RUNTIME_CAP_MEMORY_HELPERS: i32 = 8;
export const MIR_RUNTIME_CAP_STRING_PRIMITIVES: i32 = 16;
export const MIR_RUNTIME_HELPER_MEMCPY: i32 = 101;
export const MIR_RUNTIME_HELPER_MEMSET: i32 = 102;
export const MIR_RUNTIME_HELPER_MEMCMP: i32 = 103;
export const MIR_RUNTIME_HELPER_STRING_PRIMITIVE: i32 = 104;
export const MIR_RUNTIME_CAP_PRINT_HELPERS: i32 = 32;
export const MIR_RUNTIME_CAP_HEAP_HELPERS: i32 = 64;
export const MIR_RUNTIME_CAP_ENV_FILE_IO: i32 = 128;
export const MIR_RUNTIME_CAP_SYSCALL: i32 = 256;
export const MIR_RUNTIME_HELPER_PRINT: i32 = 201;
export const MIR_RUNTIME_HELPER_PRINTLN: i32 = 202;
export const MIR_RUNTIME_HELPER_MALLOC: i32 = 203;
export const MIR_RUNTIME_HELPER_FREE: i32 = 204;
export const MIR_RUNTIME_HELPER_ENV: i32 = 205;
export const MIR_RUNTIME_HELPER_FILE_IO: i32 = 206;
export const MIR_RUNTIME_HELPER_SYSCALL: i32 = 207;

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
export const MIR_RUNTIME_CAP_FREESTANDING: i32 = 4;
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
        runtime_capability_mask: 3 + MIR_RUNTIME_CAP_ASYNC_FRAME,
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
        abi_class: portable_mir_abi_class_for_type_kind(kind),
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
        typ.abi_class = MIR_ABI_CLASS_ERROR_UNION;
    }
    if kind == MIR_TYPE_KIND_FUNCTION {
        typ.size_bytes = 8usize;
        typ.align_bytes = 8usize;
        typ.element_type_id = 0;
        typ.field_start = 0;
        typ.field_count = 2;
        typ.abi_class = MIR_ABI_CLASS_FUNCTION;
        typ.flags = MIR_CALL_CONV_UYA;
    }
    if kind == MIR_TYPE_KIND_FUNCTION_POINTER {
        typ.size_bytes = 8usize;
        typ.align_bytes = 8usize;
        typ.element_type_id = 0;
        typ.pointee_type_id = 20;
        typ.abi_class = MIR_ABI_CLASS_POINTER;
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
        abi_class: MIR_ABI_CLASS_INTEGER,
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
        async_frame_meta_count: 0usize,
        global_count: 0usize,
        const_count: 0usize,
        link_input_count: 0usize,
        cross_unit_symbol_count: 0usize,
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
        async_frame_metas: verifier_empty_vec(@size_of(MirAsyncFrameMeta)),
        globals: verifier_empty_vec(@size_of(MirGlobal)),
        consts: verifier_empty_vec(@size_of(MirConst)),
        link_inputs: verifier_empty_vec(@size_of(MirLinkInput)),
        cross_unit_symbols: verifier_empty_vec(@size_of(MirCrossUnitSymbol)),
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
    var operands: [MirOperand: 4] = [];
    var globals: [MirGlobal: 1] = [];
    var consts: [MirConst: 1] = [];
    var link_inputs: [MirLinkInput: 1] = [];
    var cross_symbols: [MirCrossUnitSymbol: 1] = [];
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
    globals[0] = MirGlobal{
        global_id: 0,
        decl_id: 0,
        symbol_id: 0,
        type_id: 0,
        init_const_id: 0,
        init_kind: MIR_GLOBAL_INIT_SCALAR,
        linkage: MIR_GLOBAL_LINKAGE_INTERNAL,
        visibility: MIR_SYMBOL_VISIBILITY_DEFAULT,
        section: MIR_GLOBAL_SECTION_DATA,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        alignment: 4usize,
        dedupe_id: -1,
        debug_loc_id: 0,
        flags: 0,
    };
    consts[0] = MirConst{
        const_id: 0,
        kind: MIR_CONST_KIND_SCALAR,
        type_id: 0,
        dedupe_id: -1,
        byte_offset: 0usize,
        byte_count: 4usize,
        scalar_i64: 7i64,
        debug_loc_id: 0,
        flags: 0,
    };
    link_inputs[0] = MirLinkInput{
        link_input_id: 0,
        kind: MIR_LINK_INPUT_KIND_C_IMPORT_OBJECT,
        target_profile_id: 0,
        c_import_id: 17,
        symbol_id: 0,
        path_dedupe_id: 40,
        name_dedupe_id: 41,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        debug_loc_id: 0,
        flags: 0,
    };
    cross_symbols[0] = MirCrossUnitSymbol{
        cross_unit_symbol_id: 0,
        unit_id: 0,
        symbol_id: 0,
        kind: MIR_CROSS_UNIT_SYMBOL_EXPORT,
        owner_kind: MIR_CROSS_UNIT_OWNER_FUNCTION,
        owner_function_id: 0,
        owner_global_id: MIR_GLOBAL_INVALID_ID,
        target_profile_id: 0,
        visibility: MIR_SYMBOL_VISIBILITY_DEFAULT,
        debug_loc_id: 0,
        flags: 0,
    };
    locals[0] = verifier_local();
    insts[0] = verifier_inst();
    terminators[0] = verifier_terminator();
    operands[0] = verifier_operand(0, 0, 1);
    operands[1] = verifier_operand(1, 1, 0);
    operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 0);
    operands[3] = verifier_operand(3, 1, 0);
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
        insts[0].operand_count = 3;
        insts[0].calling_convention = MIR_CALL_CONV_C;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM + MIR_CALL_FLAG_FLOAT_ABI;
        values[1].type_id = 16;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_EXTERN;
        operands[0].immediate_i32 = 0;
        functions[0].flags = MIR_FUNCTION_FLAG_EXTERN;
        functions[0].calling_convention = MIR_CALL_CONV_C;
        functions[0].signature_type_id = 20;
        types[20].element_type_id = 16;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 16);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 48 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 15;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].calling_convention = MIR_CALL_CONV_C;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM + MIR_CALL_FLAG_FLOAT_ABI;
        values[1].type_id = 15;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_EXTERN;
        operands[0].immediate_i32 = 0;
        functions[0].flags = MIR_FUNCTION_FLAG_EXTERN;
        functions[0].calling_convention = MIR_CALL_CONV_C;
        functions[0].signature_type_id = 20;
        types[20].element_type_id = 16;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 15);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
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
    if mode == 72 {
        insts[0].op = MIR_INST_OP_AGGREGATE_COPY;
        insts[0].type_id = 22;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_NO_OVERLAP;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 23);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 23);
    }
    if mode == 73 {
        insts[0].op = MIR_INST_OP_AGGREGATE_MOVE;
        insts[0].type_id = 22;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_NO_OVERLAP;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 23);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 23);
    }
    if mode == 74 {
        insts[0].op = MIR_INST_OP_AGGREGATE_COPY;
        insts[0].type_id = 22;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 23);
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 23);
    }
    if mode == 75 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM;
        values[1].type_id = 0;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 0);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 76 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM;
        values[1].type_id = 0;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 0);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_METHOD_INSTANCE;
        operands[0].immediate_i32 = 0;
        operands[0].flags = 9;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 77 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM;
        values[0].type_id = 21;
        values[1].type_id = 0;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 0);
        operands[0] = verifier_operand(0, 0, 21);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_FUNCTION_POINTER;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 78 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].immediate_i32 = 0;
    }
    if mode == 79 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_EXTERN;
        operands[0].immediate_i32 = 0;
    }
    if mode == 80 {
        types[20].element_type_id = 22;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 22;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM +
            MIR_CALL_FLAG_AGGREGATE_RETURN + MIR_CALL_FLAG_OUT_PARAM_WRITEBACK;
        values[1].type_id = 22;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 22);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 23);
        operands[1].flags = MIR_CALL_FLAG_OUT_PARAM_WRITEBACK;
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 81 {
        types[20].element_type_id = 19;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 19;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM + MIR_CALL_FLAG_ERROR_UNION_RETURN;
        values[1].type_id = 19;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 19);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 82 {
        types[20].element_type_id = 15;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 15;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM + MIR_CALL_FLAG_FLOAT_ABI;
        values[1].type_id = 15;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 15);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 83 {
        types[20].element_type_id = 16;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 16;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM + MIR_CALL_FLAG_FLOAT_ABI;
        values[1].type_id = 16;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 16);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 84 {
        types[20].element_type_id = 16;
        types[16].abi_class = MIR_ABI_CLASS_INTEGER;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 16;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM + MIR_CALL_FLAG_FLOAT_ABI;
        values[1].type_id = 16;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 16);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 85 {
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = 0;
        values[1].type_id = 0;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 0);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 86 {
        types[20].element_type_id = 22;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 22;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM + MIR_CALL_FLAG_AGGREGATE_RETURN;
        values[1].type_id = 22;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 22);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 23);
        operands[1].flags = MIR_CALL_FLAG_OUT_PARAM_WRITEBACK;
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 87 {
        types[20].element_type_id = 19;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 19;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM;
        values[1].type_id = 19;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 19);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 88 {
        types[20].element_type_id = 16;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 16;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM;
        values[1].type_id = 16;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 16);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 0);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 89 {
        types[20].element_type_id = 22;
        insts[0].op = MIR_INST_OP_CALL;
        insts[0].type_id = 22;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_CALL_FLAG_MULTI_PARAM +
            MIR_CALL_FLAG_AGGREGATE_RETURN + MIR_CALL_FLAG_OUT_PARAM_WRITEBACK;
        values[1].type_id = 22;
        terminators[0].operand_start = 3;
        operands[3] = verifier_operand(3, 1, 22);
        functions[0].signature_type_id = 20;
        operands[0] = verifier_operand(0, MIR_VALUE_INVALID_ID, 20);
        operands[0].kind = MIR_OPERAND_KIND_CALL_TARGET_DIRECT;
        operands[0].immediate_i32 = 0;
        operands[1] = verifier_operand(1, MIR_VALUE_INVALID_ID, 23);
        operands[2] = verifier_operand(2, MIR_VALUE_INVALID_ID, 5);
    }
    if mode == 90 {
        insts[0].op = MIR_INST_OP_ATOMIC_INIT;
        insts[0].type_id = 2;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_ATOMIC_ORDERED;
        values[0].type_id = 2;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 2);
        operands[1] = verifier_operand(1, 1, 0);
    }
    if mode == 91 {
        insts[0].op = MIR_INST_OP_ATOMIC_LOAD;
        insts[0].type_id = 2;
        insts[0].operand_count = 1;
        insts[0].flags = MIR_INST_FLAG_ATOMIC_ORDERED;
        values[0].type_id = 2;
        values[1].type_id = 2;
        operands[0] = verifier_operand(0, 0, 2);
    }
    if mode == 92 {
        insts[0].op = MIR_INST_OP_ATOMIC_STORE;
        insts[0].type_id = 2;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_ATOMIC_ORDERED;
        values[0].type_id = 2;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 2);
        operands[1] = verifier_operand(1, 1, 0);
    }
    if mode == 93 {
        insts[0].op = MIR_INST_OP_ATOMIC_RMW;
        insts[0].type_id = 2;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_ATOMIC_ORDERED;
        values[0].type_id = 2;
        values[1].type_id = 2;
        operands[0] = verifier_operand(0, 0, 2);
        operands[1] = verifier_operand(1, 0, 0);
        operands[1].immediate_i32 = MIR_ATOMIC_RMW_ADD;
    }
    if mode == 94 {
        insts[0].op = MIR_INST_OP_ATOMIC_CMPXCHG;
        insts[0].type_id = 2;
        insts[0].operand_count = 3;
        insts[0].flags = MIR_INST_FLAG_ATOMIC_ORDERED;
        values[0].type_id = 2;
        values[1].type_id = 2;
        operands[0] = verifier_operand(0, 0, 2);
        operands[1] = verifier_operand(1, 0, 0);
        operands[2] = verifier_operand(2, 0, 0);
    }
    if mode == 95 {
        insts[0].op = MIR_INST_OP_LOAD;
        insts[0].type_id = 2;
        values[1].type_id = 2;
    }
    if mode == 96 {
        insts[0].op = MIR_INST_OP_STORE;
        insts[0].type_id = 2;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        values[0].type_id = 2;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 2);
        operands[1] = verifier_operand(1, 1, 0);
    }
    if mode == 97 {
        insts[0].op = MIR_INST_OP_ATOMIC_LOAD;
        insts[0].type_id = 2;
        insts[0].operand_count = 1;
        values[0].type_id = 2;
        values[1].type_id = 2;
        operands[0] = verifier_operand(0, 0, 2);
    }
    if mode == 98 {
        insts[0].op = MIR_INST_OP_ATOMIC_CMPXCHG;
        insts[0].type_id = 2;
        insts[0].operand_count = 2;
        insts[0].flags = MIR_INST_FLAG_ATOMIC_ORDERED;
        values[0].type_id = 2;
        values[1].type_id = 2;
        operands[0] = verifier_operand(0, 0, 2);
        operands[1] = verifier_operand(1, 0, 0);
    }
    if mode == 99 {
        insts[0].op = MIR_INST_OP_VECTOR_SPLAT;
        insts[0].type_id = 3;
        insts[0].operand_count = 1;
        values[0].type_id = 0;
        values[1].type_id = 3;
        operands[0] = verifier_operand(0, 0, 0);
    }
    if mode == 100 {
        insts[0].op = MIR_INST_OP_VECTOR_LOAD;
        insts[0].type_id = 3;
        insts[0].operand_count = 1;
        values[0].type_id = 3;
        values[1].type_id = 3;
        operands[0] = verifier_operand(0, 0, 3);
    }
    if mode == 101 {
        insts[0].op = MIR_INST_OP_VECTOR_STORE;
        insts[0].type_id = 3;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        values[0].type_id = 3;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 3);
        operands[1] = verifier_operand(1, 1, 3);
    }
    if mode == 102 {
        insts[0].op = MIR_INST_OP_VECTOR_SELECT;
        insts[0].type_id = 3;
        insts[0].operand_count = 3;
        values[0].type_id = 3;
        values[1].type_id = 3;
        operands[0] = verifier_operand(0, 0, 4);
        operands[1] = verifier_operand(1, 0, 3);
        operands[2] = verifier_operand(2, 0, 3);
    }
    if mode == 103 {
        insts[0].op = MIR_INST_OP_VECTOR_LOAD;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        values[0].type_id = 0;
        values[1].type_id = 0;
    }
    if mode == 104 {
        insts[0].op = MIR_INST_OP_VECTOR_STORE;
        insts[0].type_id = 3;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 2;
        values[0].type_id = 3;
        values[1].type_id = 3;
        operands[0] = verifier_operand(0, 0, 3);
        operands[1] = verifier_operand(1, 0, 3);
    }
    if mode == 105 {
        insts[0].op = MIR_INST_OP_VECTOR_SELECT;
        insts[0].type_id = 3;
        insts[0].operand_count = 2;
        values[0].type_id = 3;
        values[1].type_id = 3;
        operands[0] = verifier_operand(0, 0, 4);
        operands[1] = verifier_operand(1, 0, 3);
    }
    if mode == 106 {
        insts[0].op = MIR_INST_OP_DROP_VALUE;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 1;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 0);
    }
    if mode == 107 {
        insts[0].op = MIR_INST_OP_DROP_IN_PLACE;
        insts[0].type_id = 1;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 1;
        values[1].defining_inst_id = MIR_INST_INVALID_ID;
        values[1].flags = MIR_VALUE_FLAG_PARAM;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 108 {
        blocks[0].flags = MIR_BLOCK_FLAG_CLEANUP;
        functions[0].cleanup_model = MIR_CLEANUP_MODEL_RETURN +
            MIR_CLEANUP_MODEL_ERROR + MIR_CLEANUP_MODEL_UNWIND;
    }
    if mode == 109 {
        functions[0].cleanup_model = 8;
    }
    if mode == 110 {
        insts[0].op = MIR_INST_OP_DROP_VALUE;
        insts[0].type_id = 0;
        insts[0].result_value_id = 1;
        insts[0].operand_count = 1;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 0);
    }
    if mode == 111 {
        insts[0].op = MIR_INST_OP_ERROR_UNION_OK;
        insts[0].type_id = 19;
        insts[0].operand_count = 1;
        values[0].type_id = 0;
        values[1].type_id = 19;
        operands[0] = verifier_operand(0, 0, 0);
    }
    if mode == 112 {
        insts[0].op = MIR_INST_OP_ERROR_UNION_ERR;
        insts[0].type_id = 19;
        insts[0].operand_count = 1;
        values[0].type_id = 0;
        values[1].type_id = 19;
        operands[0] = verifier_operand(0, 0, 0);
    }
    if mode == 113 {
        insts[0].op = MIR_INST_OP_ERROR_UNION_IS_ERR;
        insts[0].type_id = 5;
        insts[0].operand_count = 1;
        insts[0].flags = MIR_INST_FLAG_ERROR_UNION_CHECKED;
        values[0].type_id = 19;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 19);
    }
    if mode == 114 {
        insts[0].op = MIR_INST_OP_ERROR_UNION_PAYLOAD;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        insts[0].flags = MIR_INST_FLAG_ERROR_UNION_CHECKED;
        values[0].type_id = 19;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 19);
    }
    if mode == 115 {
        insts[0].op = MIR_INST_OP_ERROR_UNION_ERROR;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        insts[0].flags = MIR_INST_FLAG_ERROR_UNION_CHECKED;
        values[0].type_id = 19;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 19);
    }
    if mode == 116 {
        insts[0].op = MIR_INST_OP_ERROR_UNION_PAYLOAD;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        values[0].type_id = 19;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 19);
    }
    if mode == 117 {
        insts[0].op = MIR_INST_OP_ASYNC_FRAME_ALLOC;
        insts[0].type_id = 1;
        insts[0].operand_count = 0;
        insts[0].runtime_capability_mask = MIR_RUNTIME_CAP_ASYNC_FRAME;
        values[1].type_id = 1;
    }
    if mode == 118 {
        insts[0].op = MIR_INST_OP_ASYNC_FRAME_FREE;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 1;
        insts[0].runtime_capability_mask = MIR_RUNTIME_CAP_ASYNC_FRAME;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 119 {
        insts[0].op = MIR_INST_OP_ASYNC_STATE_LOAD;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 120 {
        insts[0].op = MIR_INST_OP_ASYNC_STATE_STORE;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 2;
        operands[0] = verifier_operand(0, 0, 1);
        operands[1] = verifier_operand(1, 0, 0);
    }
    if mode == 121 {
        insts[0].op = MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT;
        insts[0].type_id = 1;
        insts[0].operand_count = 1;
        values[1].type_id = 1;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 122 {
        insts[0].op = MIR_INST_OP_ASYNC_POLL_CHILD;
        insts[0].type_id = 5;
        insts[0].operand_count = 1;
        values[1].type_id = 5;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 123 {
        insts[0].op = MIR_INST_OP_ASYNC_RESUME_EDGE;
        insts[0].type_id = 0;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 1;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 124 {
        insts[0].op = MIR_INST_OP_ASYNC_RESULT_LOAD;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 125 {
        insts[0].op = MIR_INST_OP_ASYNC_FRAME_ALLOC;
        insts[0].type_id = 1;
        values[1].type_id = 1;
    }
    if mode == 126 {
        insts[0].op = MIR_INST_OP_ASYNC_POLL_CHILD;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 127 {
        insts[0].op = MIR_INST_OP_ASYNC_RESULT_LOAD;
        insts[0].type_id = 0;
        insts[0].operand_count = 1;
        types[0].kind = MIR_TYPE_KIND_VOID;
        values[1].type_id = 0;
        operands[0] = verifier_operand(0, 0, 1);
    }
    if mode == 128 {
        globals[0].init_kind = MIR_GLOBAL_INIT_SCALAR;
        globals[0].section = MIR_GLOBAL_SECTION_DATA;
        consts[0].kind = MIR_CONST_KIND_SCALAR;
    }
    if mode == 129 {
        globals[0].type_id = 22;
        globals[0].init_kind = MIR_GLOBAL_INIT_AGGREGATE;
        globals[0].section = MIR_GLOBAL_SECTION_DATA;
        consts[0].type_id = 22;
        consts[0].kind = MIR_CONST_KIND_AGGREGATE;
        consts[0].byte_count = 8usize;
    }
    if mode == 130 {
        globals[0].type_id = 27;
        globals[0].init_kind = MIR_GLOBAL_INIT_STRING;
        globals[0].section = MIR_GLOBAL_SECTION_RODATA;
        globals[0].dedupe_id = 77;
        globals[0].flags = MIR_GLOBAL_FLAG_CONST;
        consts[0].type_id = 27;
        consts[0].kind = MIR_CONST_KIND_STRING;
        consts[0].dedupe_id = 77;
        consts[0].byte_count = 6usize;
    }
    if mode == 131 {
        globals[0].type_id = 27;
        globals[0].init_kind = MIR_GLOBAL_INIT_STRING;
        globals[0].section = MIR_GLOBAL_SECTION_RODATA;
        consts[0].type_id = 27;
        consts[0].kind = MIR_CONST_KIND_STRING;
        consts[0].byte_count = 6usize;
    }
    if mode == 132 {
        globals[0].init_kind = MIR_GLOBAL_INIT_EXTERN;
        globals[0].init_const_id = MIR_CONST_INVALID_ID;
        globals[0].linkage = MIR_GLOBAL_LINKAGE_EXTERN;
        globals[0].visibility = MIR_SYMBOL_VISIBILITY_DEFAULT;
        globals[0].section = MIR_GLOBAL_SECTION_BSS;
    }
    if mode == 133 {
        link_inputs[0].kind = MIR_LINK_INPUT_KIND_C_IMPORT_OBJECT;
        link_inputs[0].target_profile_id = 0;
        link_inputs[0].path_dedupe_id = 40;
    }
    if mode == 134 {
        link_inputs[0].kind = MIR_LINK_INPUT_KIND_C_IMPORT_OBJECT;
        link_inputs[0].target_profile_id = 99;
        link_inputs[0].path_dedupe_id = 40;
    }
    if mode == 135 {
        cross_symbols[0].kind = MIR_CROSS_UNIT_SYMBOL_EXPORT;
        cross_symbols[0].owner_kind = MIR_CROSS_UNIT_OWNER_FUNCTION;
        cross_symbols[0].owner_function_id = 0;
        cross_symbols[0].visibility = MIR_SYMBOL_VISIBILITY_DEFAULT;
    }
    if mode == 136 {
        globals[0].init_kind = MIR_GLOBAL_INIT_EXTERN;
        globals[0].init_const_id = MIR_CONST_INVALID_ID;
        globals[0].linkage = MIR_GLOBAL_LINKAGE_EXTERN;
        globals[0].visibility = MIR_SYMBOL_VISIBILITY_DEFAULT;
        globals[0].section = MIR_GLOBAL_SECTION_BSS;
        cross_symbols[0].kind = MIR_CROSS_UNIT_SYMBOL_IMPORT;
        cross_symbols[0].owner_kind = MIR_CROSS_UNIT_OWNER_GLOBAL;
        cross_symbols[0].owner_function_id = MIR_FUNCTION_INVALID_ID;
        cross_symbols[0].owner_global_id = 0;
    }
    if mode == 137 {
        cross_symbols[0].unit_id = -1;
    }
    if functions[0].signature_type_id != 20 &&
       terminators[0].operand_start >= 0 && terminators[0].operand_start < 4 {
        functions[0].signature_type_id =
            operands[terminators[0].operand_start].type_id;
    }

    var module: PortableMirModule = verifier_empty_module();
    var global_fixture_count: usize = 0usize;
    var const_fixture_count: usize = 0usize;
    var link_input_fixture_count: usize = 0usize;
    var cross_unit_symbol_fixture_count: usize = 0usize;
    if mode >= 128 && mode <= 131 {
        global_fixture_count = 1usize;
        const_fixture_count = 1usize;
    }
    if mode == 132 {
        global_fixture_count = 1usize;
    }
    if mode == 133 || mode == 134 {
        link_input_fixture_count = 1usize;
    }
    if mode == 135 || mode == 137 {
        cross_unit_symbol_fixture_count = 1usize;
    }
    if mode == 136 {
        global_fixture_count = 1usize;
        cross_unit_symbol_fixture_count = 1usize;
    }
    module.functions = verifier_vec(&functions[0] as &byte, @size_of(MirFunction), 1usize);
    module.blocks = verifier_vec(&blocks[0] as &byte, @size_of(MirBlock), 1usize);
    module.values = verifier_vec(&values[0] as &byte, @size_of(MirValue), 2usize);
    module.types = verifier_vec(&types[0] as &byte, @size_of(MirType), 29usize);
    module.locals = verifier_vec(&locals[0] as &byte, @size_of(MirLocal), 1usize);
    module.insts = verifier_vec(&insts[0] as &byte, @size_of(MirInst), 1usize);
    module.terminators = verifier_vec(&terminators[0] as &byte, @size_of(MirTerminator), 1usize);
    module.operands = verifier_vec(&operands[0] as &byte, @size_of(MirOperand), 4usize);
    module.capability_reqs = verifier_vec(&caps[0] as &byte, @size_of(MirCapabilityReq), 1usize);
    module.field_layouts = verifier_vec(&field_layouts[0] as &byte,
        @size_of(MirFieldLayout), 1usize);
    module.function_param_types = verifier_vec(&fn_params[0] as &byte,
        @size_of(MirFunctionParamType), 2usize);
    module.globals = verifier_vec(&globals[0] as &byte, @size_of(MirGlobal),
        global_fixture_count);
    module.consts = verifier_vec(&consts[0] as &byte, @size_of(MirConst),
        const_fixture_count);
    module.link_inputs = verifier_vec(&link_inputs[0] as &byte, @size_of(MirLinkInput),
        link_input_fixture_count);
    module.cross_unit_symbols = verifier_vec(&cross_symbols[0] as &byte,
        @size_of(MirCrossUnitSymbol), cross_unit_symbol_fixture_count);
    module.function_count = 1usize;
    module.block_count = 1usize;
    module.value_count = 2usize;
    module.type_count = 29usize;
    module.local_count = 1usize;
    module.inst_count = 1usize;
    module.terminator_count = 1usize;
    module.operand_count = 4usize;
    module.capability_req_count = 1usize;
    module.field_layout_count = 1usize;
    module.function_param_type_count = 2usize;
    module.async_frame_meta_count = 0usize;
    module.global_count = global_fixture_count;
    module.const_count = const_fixture_count;
    module.link_input_count = link_input_fixture_count;
    module.cross_unit_symbol_count = cross_unit_symbol_fixture_count;

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
    try assert_eq_i32(verifier_run(72), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(73), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(75), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(76), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(77), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(80), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(81), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(82), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(83), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(90), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(91), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(92), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(93), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(94), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(99), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(100), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(101), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(102), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(106), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(107), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(108), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(111), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(112), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(113), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(114), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(115), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(117), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(118), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(119), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(120), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(121), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(122), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(123), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(124), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(128), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(129), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(130), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(132), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(133), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(135), MIR_VERIFY_OK);
    try assert_eq_i32(verifier_run(136), MIR_VERIFY_OK);
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
    try assert_eq_i32(verifier_run(74), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(78), MIR_VERIFY_ERR_INVALID_OPERAND);
    try assert_eq_i32(verifier_run(79), MIR_VERIFY_ERR_INVALID_FUNCTION);
    try assert_eq_i32(verifier_run(84), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(16), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(85), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(86), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(87), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(88), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(89), MIR_VERIFY_ERR_INVALID_LAYOUT);
}

test "PortableMIR verifier rejects atomic vector mask cleanup and naked violations" {
    try assert_eq_i32(verifier_run(4), MIR_VERIFY_ERR_INVALID_ATOMIC);
    try assert_eq_i32(verifier_run(5), MIR_VERIFY_ERR_INVALID_VECTOR_MASK);
    try assert_eq_i32(verifier_run(6), MIR_VERIFY_ERR_INVALID_CLEANUP);
    try assert_eq_i32(verifier_run(9), MIR_VERIFY_ERR_INVALID_NAKED_BODY);
    try assert_eq_i32(verifier_run(12), MIR_VERIFY_ERR_INVALID_CLEANUP);
    try assert_eq_i32(verifier_run(13), MIR_VERIFY_ERR_INVALID_VECTOR_MASK);
    try assert_eq_i32(verifier_run(95), MIR_VERIFY_ERR_INVALID_ATOMIC);
    try assert_eq_i32(verifier_run(96), MIR_VERIFY_ERR_INVALID_ATOMIC);
    try assert_eq_i32(verifier_run(97), MIR_VERIFY_ERR_INVALID_ATOMIC);
    try assert_eq_i32(verifier_run(98), MIR_VERIFY_ERR_INVALID_OPERAND);
    try assert_eq_i32(verifier_run(103), MIR_VERIFY_ERR_INVALID_VECTOR_MASK);
    try assert_eq_i32(verifier_run(104), MIR_VERIFY_ERR_INVALID_OPERAND);
    try assert_eq_i32(verifier_run(105), MIR_VERIFY_ERR_INVALID_OPERAND);
    try assert_eq_i32(verifier_run(109), MIR_VERIFY_ERR_INVALID_CLEANUP);
    try assert_eq_i32(verifier_run(110), MIR_VERIFY_ERR_INVALID_OPERAND);
    try assert_eq_i32(verifier_run(116), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(125), MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
    try assert_eq_i32(verifier_run(126), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(127), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(131), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(134), MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
    try assert_eq_i32(verifier_run(137), MIR_VERIFY_ERR_INVALID_LAYOUT);
}
EOF

(cd "$REPO_ROOT" && ../uya/bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR verifier contract verified"
