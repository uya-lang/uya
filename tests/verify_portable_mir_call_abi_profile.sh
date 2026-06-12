#!/usr/bin/env bash

# Native build-seed boundary: hosted/freestanding call ABI profile 必须在 PortableMIR 中显式分流，
# 并由 verifier 阻止 hosted-only capability 进入 freestanding native。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_BACKEND_FILE="$REPO_ROOT/src/lower/mir_backend.uya"
HOSTED_LINK_FILE="$REPO_ROOT/src/codegen/native/hosted_link.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: PortableMIR call ABI profile 缺少证据: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_CONTRACT_FILE" "$MIR_VERIFIER_FILE" \
    "$MIR_BACKEND_FILE" "$HOSTED_LINK_FILE" "$PORTABLE_MIR_DOC" \
    "$ARCH_DOC" "$BUILD_DRIVER_SRC"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_TARGET_PROFILE_HOSTED_NATIVE \
    MIR_TARGET_PROFILE_FREESTANDING_NATIVE \
    MIR_CALL_ABI_PROFILE_HOSTED_SYSV \
    MIR_CALL_ABI_PROFILE_FREESTANDING_SYSCALL \
    portable_mir_target_profile_hosted_native \
    portable_mir_target_profile_freestanding_native \
    portable_mir_target_profile_supports_call_abi \
    portable_mir_target_profile_supports_runtime_capability; do
    require_pattern "$MIR_FILE" "$symbol" "MIR profile symbol $symbol"
done

require_pattern "$MIR_FILE" 'call_abi_profile:[[:space:]]*i32' "MirTargetProfile call ABI profile field"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_target_profile_supports_call_abi' "verifier checks call ABI profile"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_target_profile_supports_runtime_capability' "verifier checks runtime capability via profile helper"
require_pattern "$HOSTED_LINK_FILE" 'MIR_CALL_ABI_PROFILE_HOSTED_SYSV' "hosted linker requires hosted SysV ABI profile"
require_pattern "$BUILD_DRIVER_SRC" 'portable_mir_target_profile_hosted_native' "build driver uses hosted profile helper"
require_pattern "$PORTABLE_MIR_DOC" 'hosted/freestanding call ABI profile' "whitepaper call ABI split"
require_pattern "$ARCH_DOC" 'hosted/freestanding call ABI profile' "architecture call ABI split"

if grep -Eq 'target_profile:[[:space:]]*MirTargetProfile\{[^}]*supported_calling_conventions:[[:space:]]*3' "$BUILD_DRIVER_SRC"; then
    echo "错误: build compiler driver 仍在手写 pre-MIR hosted profile magic mask" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-call-abi-profile.XXXXXX)"
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
export const CORE_STMT_KIND_ASM: i32 = 11;
export const CORE_STMT_KIND_DEFER: i32 = 12;
export const CORE_STMT_KIND_ERRDEFER: i32 = 13;
export const CORE_STMT_KIND_DROP: i32 = 14;
export const CORE_STMT_KIND_ERROR_PROPAGATION: i32 = 15;
export const CORE_STMT_KIND_LOCAL_DECL: i32 = 16;
export const CORE_STMT_KIND_IF: i32 = 17;
export const CORE_STMT_KIND_ASSIGN: i32 = 18;
export const CORE_STMT_KIND_EXPR: i32 = 19;
export const CORE_STMT_KIND_WHILE: i32 = 20;
export const CORE_EXPR_KIND_CALL: i32 = 11;
export const CORE_EXPR_KIND_INDEX: i32 = 12;
export const CORE_EXPR_KIND_SLICE: i32 = 13;
export const CORE_EXPR_KIND_ATOMIC: i32 = 14;
export const CORE_EXPR_KIND_VECTOR: i32 = 15;
export const CORE_EXPR_KIND_MASK: i32 = 16;
export const CORE_EXPR_KIND_INT_LITERAL: i32 = 17;
export const CORE_EXPR_KIND_LOCAL_REF: i32 = 18;
export const CORE_EXPR_KIND_I32_NE: i32 = 19;
export const CORE_EXPR_KIND_I32_ADD: i32 = 20;
export const CORE_EXPR_KIND_I32_LE: i32 = 21;
export const CORE_PLACE_KIND_FIELD: i32 = 4;
export const CORE_PLACE_KIND_INDEX: i32 = 5;
export const CORE_PLACE_KIND_SLICE: i32 = 6;
export const CORE_PLACE_KIND_LOCAL: i32 = 7;
export const CORE_CLEANUP_EDGE_KIND_RETURN: i32 = 2;

export struct LoweredProgram {
    functions: SemanticVector,
    core_bodies: SemanticVector,
    core_stmts: SemanticVector,
    core_exprs: SemanticVector,
}

export struct PortableMirCoreInput {
    program: &LoweredProgram,
    body_id: CoreBodyId,
    target_profile_id: i32,
    flags: i32,
}

export fn portable_mir_core_input_is_frozen(input: &PortableMirCoreInput) i32 {
    if input == null || input.program == null {
        return 0;
    }
    if input.body_id != 0 {
        return 0;
    }
    return 1;
}

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
EOF

cat "$MIR_FILE" "$MIR_CONTRACT_FILE" "$MIR_VERIFIER_FILE" \
    "$MIR_BACKEND_FILE" "$HOSTED_LINK_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn abi_empty_vec(item_size: usize) SemanticVector {
    return SemanticVector{
        data: null,
        item_size: item_size,
        count: 0usize,
        capacity: 0usize,
        bytes: item_size * 0usize,
        realloc_count: 0,
    };
}

fn abi_vec(data: &byte, item_size: usize, count: usize) SemanticVector {
    return SemanticVector{
        data: data,
        item_size: item_size,
        count: count,
        capacity: count,
        bytes: item_size * count,
        realloc_count: 0,
    };
}

fn abi_type(id: i32) MirType {
    var typ: MirType = MirType{
        type_id: id,
        kind: MIR_TYPE_KIND_I32,
        source_type_id: id,
        size_bytes: 4usize,
        align_bytes: 4usize,
        layout_id: id,
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
        abi_class: MIR_ABI_CLASS_INTEGER,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        flags: 0,
    };
    if id == 1 {
        typ.kind = MIR_TYPE_KIND_FUNCTION;
        typ.size_bytes = 8usize;
        typ.align_bytes = 8usize;
        typ.element_type_id = 0;
        typ.abi_class = MIR_ABI_CLASS_FUNCTION;
        typ.flags = MIR_CALL_CONV_C;
    }
    return typ;
}

fn abi_function(runtime_cap: i32, call_conv: i32) MirFunction {
    return MirFunction{
        function_id: 0,
        lowered_function_id: 0,
        decl_id: 0,
        source_core_body_id: 0,
        symbol_id: 0,
        signature_type_id: 1,
        param_start: 0,
        param_count: 0,
        local_start: 0,
        local_count: 0,
        block_start: 0,
        block_count: 1,
        entry_block_id: 0,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 1,
        calling_convention: call_conv,
        runtime_capability_mask: runtime_cap,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC,
        body_kind: MIR_FUNCTION_BODY_KIND_NORMAL,
        naked_asm_inst_start: -1,
        naked_asm_inst_count: 0,
        naked_forbidden_lowering_mask: 0,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: MIR_FUNCTION_FLAG_EXTERN,
    };
}

fn abi_block() MirBlock {
    return MirBlock{
        block_id: 0,
        function_id: 0,
        param_start: 0,
        param_count: 0,
        inst_start: 0,
        inst_count: 1,
        terminator_id: 0,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn abi_value(id: i32, defining_inst_id: i32) MirValue {
    return MirValue{
        value_id: id,
        function_id: 0,
        block_id: 0,
        type_id: 0,
        defining_inst_id: defining_inst_id,
        local_id: MIR_LOCAL_INVALID_ID,
        param_index: -1,
        source_expr_id: id,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn abi_inst(runtime_cap: i32, call_conv: i32) MirInst {
    return MirInst{
        inst_id: 0,
        function_id: 0,
        block_id: 0,
        op: MIR_INST_OP_CALL,
        type_id: 0,
        result_value_id: 0,
        operand_start: 0,
        operand_count: 1,
        calling_convention: call_conv,
        runtime_capability_mask: runtime_cap,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn abi_operand(call_conv: i32) MirOperand {
    var operand: MirOperand = MirOperand{
        operand_id: 0,
        kind: MIR_OPERAND_KIND_CALL_TARGET_EXTERN,
        value_id: MIR_VALUE_INVALID_ID,
        local_id: MIR_LOCAL_INVALID_ID,
        type_id: 1,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        immediate_i32: 0,
        flags: 0,
    };
    if call_conv == MIR_CALL_CONV_SYSCALL {
        operand.kind = MIR_OPERAND_KIND_VALUE;
    }
    return operand;
}

fn abi_term() MirTerminator {
    return MirTerminator{
        terminator_id: 0,
        function_id: 0,
        block_id: 0,
        kind: MIR_TERMINATOR_KIND_RETURN,
        operand_start: 0,
        operand_count: 0,
        successor_start: 0,
        successor_count: 0,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn abi_cap(capability: i32) MirCapabilityReq {
    return MirCapabilityReq{
        capability_req_id: 0,
        capability_id: capability,
        function_id: 0,
        inst_id: 0,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn abi_empty_module(profile: MirTargetProfile) PortableMirModule {
    return PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_ACTIVE,
        target_profile: profile,
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
        functions: abi_empty_vec(@size_of(MirFunction)),
        blocks: abi_empty_vec(@size_of(MirBlock)),
        values: abi_empty_vec(@size_of(MirValue)),
        types: abi_empty_vec(@size_of(MirType)),
        locals: abi_empty_vec(@size_of(MirLocal)),
        insts: abi_empty_vec(@size_of(MirInst)),
        terminators: abi_empty_vec(@size_of(MirTerminator)),
        operands: abi_empty_vec(@size_of(MirOperand)),
        block_params: abi_empty_vec(@size_of(MirBlockParam)),
        successors: abi_empty_vec(@size_of(MirSuccessor)),
        debug_locs: abi_empty_vec(@size_of(MirDebugLoc)),
        capability_reqs: abi_empty_vec(@size_of(MirCapabilityReq)),
        field_layouts: abi_empty_vec(@size_of(MirFieldLayout)),
        function_param_types: abi_empty_vec(@size_of(MirFunctionParamType)),
        async_frame_metas: abi_empty_vec(@size_of(MirAsyncFrameMeta)),
    };
}

fn abi_fill_module(module: &PortableMirModule, runtime_cap: i32, call_conv: i32,
    capability: i32, functions: &MirFunction, blocks: &MirBlock, values: &MirValue,
    types: &MirType, insts: &MirInst, terms: &MirTerminator,
    operands: &MirOperand, caps: &MirCapabilityReq) void {
    if module == null || functions == null || blocks == null || values == null ||
       types == null || insts == null || terms == null || operands == null || caps == null {
        return;
    }
    functions[0] = abi_function(runtime_cap, call_conv);
    blocks[0] = abi_block();
    values[0] = abi_value(0, 0);
    types[0] = abi_type(0);
    types[1] = abi_type(1);
    insts[0] = abi_inst(runtime_cap, call_conv);
    operands[0] = abi_operand(call_conv);
    if call_conv == MIR_CALL_CONV_SYSCALL {
        insts[0].op = MIR_INST_OP_NOP;
        insts[0].result_value_id = MIR_VALUE_INVALID_ID;
        insts[0].operand_count = 0;
        functions[0].flags = 0;
        types[1].flags = MIR_CALL_CONV_SYSCALL;
    }
    terms[0] = abi_term();
    caps[0] = abi_cap(capability);
    module.function_count = 1usize;
    module.block_count = 1usize;
    module.value_count = 1usize;
    module.type_count = 2usize;
    module.inst_count = 1usize;
    module.terminator_count = 1usize;
    module.operand_count = 1usize;
    module.capability_req_count = 1usize;
    module.functions = abi_vec(functions as &byte, @size_of(MirFunction), 1usize);
    module.blocks = abi_vec(blocks as &byte, @size_of(MirBlock), 1usize);
    module.values = abi_vec(values as &byte, @size_of(MirValue), 1usize);
    module.types = abi_vec(types as &byte, @size_of(MirType), 2usize);
    module.insts = abi_vec(insts as &byte, @size_of(MirInst), 1usize);
    module.terminators = abi_vec(terms as &byte, @size_of(MirTerminator), 1usize);
    module.operands = abi_vec(operands as &byte, @size_of(MirOperand), 1usize);
    module.capability_reqs = abi_vec(caps as &byte, @size_of(MirFieldLayout), 1usize);
}

fn abi_result(error_code: i32) MirVerifierResult {
    return MirVerifierResult{
        error_code: error_code,
        function_id: MIR_FUNCTION_INVALID_ID,
        block_id: MIR_BLOCK_INVALID_ID,
        inst_id: MIR_INST_INVALID_ID,
        value_id: MIR_VALUE_INVALID_ID,
        type_id: MIR_TYPE_INVALID_ID,
        operand_id: -1,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
    };
}

test "PortableMIR hosted and freestanding target profiles are explicit" {
    const hosted: MirTargetProfile = portable_mir_target_profile_hosted_native();
    const free: MirTargetProfile = portable_mir_target_profile_freestanding_native();

    try assert_eq_i32(hosted.profile_id, MIR_TARGET_PROFILE_HOSTED_NATIVE);
    try assert_eq_i32(hosted.runtime_mode, MIR_RUNTIME_MODE_HOSTED);
    try assert_eq_i32(hosted.call_abi_profile, MIR_CALL_ABI_PROFILE_HOSTED_SYSV);
    try assert_eq_i32(portable_mir_target_profile_supports_call_abi(&hosted, MIR_CALL_ABI_PROFILE_HOSTED_SYSV), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_HOSTED_LIBC), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_C_EXTERN), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_MEMORY_HELPERS), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_STRING_PRIMITIVES), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_PRINT_HELPERS), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_HEAP_HELPERS), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_ENV_FILE_IO), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_SYSCALL), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&hosted, MIR_RUNTIME_CAP_FREESTANDING), 0);

    try assert_eq_i32(free.profile_id, MIR_TARGET_PROFILE_FREESTANDING_NATIVE);
    try assert_eq_i32(free.runtime_mode, MIR_RUNTIME_MODE_FREESTANDING);
    try assert_eq_i32(free.call_abi_profile, MIR_CALL_ABI_PROFILE_FREESTANDING_SYSCALL);
    try assert_eq_i32(portable_mir_target_profile_supports_call_abi(&free, MIR_CALL_ABI_PROFILE_FREESTANDING_SYSCALL), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_call_abi(&free, MIR_CALL_ABI_PROFILE_HOSTED_SYSV), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_FREESTANDING), 1);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_HOSTED_LIBC), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_C_EXTERN), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_MEMORY_HELPERS), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_STRING_PRIMITIVES), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_PRINT_HELPERS), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_HEAP_HELPERS), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_ENV_FILE_IO), 0);
    try assert_eq_i32(portable_mir_target_profile_supports_runtime_capability(&free, MIR_RUNTIME_CAP_SYSCALL), 1);
}

test "PortableMIR verifier gates call ABI and runtime capability by profile" {
    var functions: [MirFunction: 1] = [];
    var blocks: [MirBlock: 1] = [];
    var values: [MirValue: 1] = [];
    var types: [MirType: 2] = [];
    var insts: [MirInst: 1] = [];
    var terms: [MirTerminator: 1] = [];
    var operands: [MirOperand: 1] = [];
    var caps: [MirCapabilityReq: 1] = [];

    var ok_hosted: PortableMirModule = abi_empty_module(portable_mir_target_profile_hosted_native());
    abi_fill_module(&ok_hosted, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_CAP_C_EXTERN, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    var result: MirVerifierResult = abi_result(-1);
    try assert_eq_i32(portable_mir_verify_module(&ok_hosted, &result), 0);
    try assert_eq_i32(result.error_code, MIR_VERIFY_OK);

    var ok_memory: PortableMirModule = abi_empty_module(portable_mir_target_profile_hosted_native());
    abi_fill_module(&ok_memory, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_HELPER_MEMCPY, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&ok_memory, &result), 0);
    try assert_eq_i32(result.error_code, MIR_VERIFY_OK);

    var ok_print: PortableMirModule = abi_empty_module(portable_mir_target_profile_hosted_native());
    abi_fill_module(&ok_print, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_HELPER_PRINT, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&ok_print, &result), 0);
    try assert_eq_i32(result.error_code, MIR_VERIFY_OK);

    var ok_heap: PortableMirModule = abi_empty_module(portable_mir_target_profile_hosted_native());
    abi_fill_module(&ok_heap, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_HELPER_MALLOC, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&ok_heap, &result), 0);
    try assert_eq_i32(result.error_code, MIR_VERIFY_OK);

    var ok_env: PortableMirModule = abi_empty_module(portable_mir_target_profile_hosted_native());
    abi_fill_module(&ok_env, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_HELPER_ENV, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&ok_env, &result), 0);
    try assert_eq_i32(result.error_code, MIR_VERIFY_OK);

    var bad_free: PortableMirModule = abi_empty_module(portable_mir_target_profile_freestanding_native());
    abi_fill_module(&bad_free, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_CAP_C_EXTERN, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    types[1].flags = MIR_CALL_CONV_SYSCALL;
    try assert_eq_i32(portable_mir_verify_module(&bad_free, &result), -1);
    try assert_eq_i32(result.error_code, MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);

    var ok_free: PortableMirModule = abi_empty_module(portable_mir_target_profile_freestanding_native());
    abi_fill_module(&ok_free, MIR_RUNTIME_CAP_FREESTANDING, MIR_CALL_CONV_SYSCALL,
        MIR_RUNTIME_CAP_FREESTANDING, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&ok_free, &result), 0);
    try assert_eq_i32(result.error_code, MIR_VERIFY_OK);

    var bad_memory_free: PortableMirModule =
        abi_empty_module(portable_mir_target_profile_freestanding_native());
    abi_fill_module(&bad_memory_free, MIR_RUNTIME_CAP_FREESTANDING, MIR_CALL_CONV_SYSCALL,
        MIR_RUNTIME_HELPER_MEMCPY, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&bad_memory_free, &result), -1);
    try assert_eq_i32(result.error_code, MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);

    var ok_syscall: PortableMirModule =
        abi_empty_module(portable_mir_target_profile_freestanding_native());
    abi_fill_module(&ok_syscall, MIR_RUNTIME_CAP_FREESTANDING, MIR_CALL_CONV_SYSCALL,
        MIR_RUNTIME_HELPER_SYSCALL, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&ok_syscall, &result), 0);
    try assert_eq_i32(result.error_code, MIR_VERIFY_OK);

    var bad_syscall_hosted: PortableMirModule =
        abi_empty_module(portable_mir_target_profile_hosted_native());
    abi_fill_module(&bad_syscall_hosted, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_HELPER_SYSCALL, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_verify_module(&bad_syscall_hosted, &result), -1);
    try assert_eq_i32(result.error_code, MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
}

test "hosted native link plan only accepts hosted SysV ABI profile" {
    var functions: [MirFunction: 1] = [];
    var blocks: [MirBlock: 1] = [];
    var values: [MirValue: 1] = [];
    var types: [MirType: 2] = [];
    var insts: [MirInst: 1] = [];
    var terms: [MirTerminator: 1] = [];
    var operands: [MirOperand: 1] = [];
    var caps: [MirCapabilityReq: 1] = [];
    var hosted_module: PortableMirModule = abi_empty_module(portable_mir_target_profile_hosted_native());
    abi_fill_module(&hosted_module, MIR_RUNTIME_CAP_C_EXTERN, MIR_CALL_CONV_C,
        MIR_RUNTIME_CAP_C_EXTERN, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    var verifier_ok: MirVerifierResult = abi_result(MIR_VERIFY_OK);
    var request: MirTargetBackendRequest = MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_backend_request_init(&request, &hosted_module,
        &verifier_ok, MIR_TARGET_BACKEND_MACHINE), 0);
    var plan: NativeHostedLinkPlan = native_hosted_link_plan_empty();
    try assert_eq_i32(native_hosted_link_plan_init(&plan, &request), 0);
    try assert_eq_i32(plan.abi_mode, NATIVE_HOSTED_ABI_SYSV);

    var free_module: PortableMirModule = abi_empty_module(portable_mir_target_profile_freestanding_native());
    abi_fill_module(&free_module, MIR_RUNTIME_CAP_FREESTANDING, MIR_CALL_CONV_SYSCALL,
        MIR_RUNTIME_CAP_FREESTANDING, &functions[0], &blocks[0], &values[0],
        &types[0], &insts[0], &terms[0], &operands[0], &caps[0]);
    try assert_eq_i32(portable_mir_backend_request_init(&request, &free_module,
        &verifier_ok, MIR_TARGET_BACKEND_MACHINE), 0);
    try assert_eq_i32(native_hosted_link_plan_init(&plan, &request), -1);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "verify_portable_mir_call_abi_profile: ok"
