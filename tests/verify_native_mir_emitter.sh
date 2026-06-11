#!/usr/bin/env bash

# Phase 9A：验证 native backend 主路径消费 PortableMIR 并导入 MachineModule。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_BACKEND_FILE="$REPO_ROOT/src/lower/mir_backend.uya"
MACHINE_FILE="$REPO_ROOT/src/codegen/native/machine.uya"
ELF64_FILE="$REPO_ROOT/src/codegen/native/elf64.uya"
ABI_FILE="$REPO_ROOT/src/codegen/native/abi.uya"
X86_FILE="$REPO_ROOT/src/codegen/native/x86_64.uya"
MIR_EMITTER_FILE="$REPO_ROOT/src/codegen/native/mir_emitter.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: native MIR emitter 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$MIR_FILE" "$MIR_VERIFIER_FILE" \
    "$MIR_BACKEND_FILE" "$MACHINE_FILE" "$ELF64_FILE" "$ABI_FILE" "$X86_FILE" \
    "$MIR_EMITTER_FILE" "$PORTABLE_MIR_DOC" "$ARCH_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$MIR_EMITTER_FILE" '^export[[:space:]]+struct[[:space:]]+NativeMirEmitter' "NativeMirEmitter 结构"
require_pattern "$MIR_EMITTER_FILE" 'request:[[:space:]]*&MirTargetBackendRequest' "backend request 输入"
require_pattern "$MIR_EMITTER_FILE" 'portable_mir:[[:space:]]*&PortableMirModule' "PortableMIR 输入"
require_pattern "$MIR_EMITTER_FILE" 'machine_module:[[:space:]]*&MachineModule' "MachineModule 输出"
require_pattern "$MIR_EMITTER_FILE" 'native_mir_emitter_begin' "PortableMIR emitter 初始化入口"
require_pattern "$MIR_EMITTER_FILE" 'native_mir_emitter_read_portable_mir' "PortableMIR 导入入口"
require_pattern "$MIR_EMITTER_FILE" 'native_mir_emitter_import_naked_function' "naked function native 专用导入入口"
require_pattern "$MIR_EMITTER_FILE" 'portable_mir_function_has_naked_flag' "naked function 分流"
require_pattern "$MIR_EMITTER_FILE" 'portable_mir_function_has_asm_only_naked_body' "naked function asm-only gate"
require_pattern "$MIR_EMITTER_FILE" 'request\.backend_kind[[:space:]]*!=[[:space:]]*MIR_TARGET_BACKEND_MACHINE' "machine backend kind gate"
require_pattern "$MIR_EMITTER_FILE" 'portable_mir_backend_request_is_verified' "verifier-clean request gate"
require_pattern "$MIR_EMITTER_FILE" 'semantic_vector_item_ptr\(&emitter\.portable_mir\.functions' "枚举 MIR functions"
require_pattern "$MIR_EMITTER_FILE" 'machine_module_add_function' "导入 MachineModule function"
require_pattern "$MIR_EMITTER_FILE" 'machine_function_add_block' "导入 MachineModule block"
require_pattern "$MIR_EMITTER_FILE" 'machine_block_add_inst' "导入 MachineModule inst"
require_pattern "$MIR_EMITTER_FILE" 'native_mir_emitter_write_executable_stream' "executable streaming writer"
require_pattern "$PORTABLE_MIR_DOC" 'NativeMirEmitter' "whitepaper native MIR emitter"
require_pattern "$ARCH_DOC" 'NativeMirEmitter' "architecture native MIR emitter"
require_pattern "$ARCH_DOC" 'LoweredProgram -> MachineModule' "architecture legacy LoweredProgram helper"
require_pattern "$ARCH_DOC" '不能作为 hosted native 完整语言主路径' "architecture legacy boundary"

if grep -Eq 'lowered_program:[[:space:]]*&LoweredProgram|body_ops:[[:space:]]*SemanticVector' "$MIR_EMITTER_FILE"; then
    echo "错误: native MIR emitter 主路径不应接受 LoweredProgram body_ops" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-native-mir-emitter.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
output_path="$tmp_dir/native-mir-emitter.bin"
mkdir -p "$tmp_dir/codegen/native"
cp "$ELF64_FILE" "$tmp_dir/codegen/native/elf64.uya"
cp "$ABI_FILE" "$tmp_dir/codegen/native/abi.uya"
cp "$X86_FILE" "$tmp_dir/codegen/native/x86_64.uya"
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" >"$tmp_dir/main.uya"
cat >>"$tmp_dir/main.uya" <<'EOF'
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
use codegen.native.abi;
use codegen.native.x86_64;
EOF
cat >>"$tmp_dir/main.uya" <<'EOF'
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
cat "$MIR_FILE" "$MIR_VERIFIER_FILE" \
    "$MIR_BACKEND_FILE" "$MACHINE_FILE" "$MIR_EMITTER_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fclose;
use libc.fopen;
use libc.fread;
use libc.rewind;

fn native_mir_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

fn native_mir_profile() MirTargetProfile {
    return MirTargetProfile{
        profile_id: 77,
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

fn native_mir_type_i32() MirType {
    return MirType{
        type_id: 0,
        kind: MIR_TYPE_KIND_I32,
        source_type_id: 10,
        size_bytes: 4usize,
        align_bytes: 4usize,
        layout_id: 100,
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
}

fn native_mir_type_void(id: i32) MirType {
    return MirType{
        type_id: id,
        kind: MIR_TYPE_KIND_VOID,
        source_type_id: 10,
        size_bytes: 0usize,
        align_bytes: 0usize,
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
        abi_class: 0,
        address_space: 0,
        flags: 0,
    };
}

fn native_mir_type_pointer(id: i32, pointee_type_id: i32) MirType {
    return MirType{
        type_id: id,
        kind: MIR_TYPE_KIND_POINTER,
        source_type_id: 12,
        size_bytes: 8usize,
        align_bytes: 8usize,
        layout_id: 100 + id,
        tag_offset_bytes: 0usize,
        payload_offset_bytes: 0usize,
        atomic_align_bytes: 0usize,
        element_type_id: MIR_TYPE_INVALID_ID,
        pointee_type_id: pointee_type_id,
        field_start: 0,
        field_count: 0,
        lane_count: 0,
        lane_stride_bytes: 0usize,
        mask_representation: 0,
        abi_class: 1,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        flags: 0,
    };
}

fn native_mir_function() MirFunction {
    return MirFunction{
        function_id: 0,
        lowered_function_id: 100,
        decl_id: 200,
        source_core_body_id: 0,
        symbol_id: 300,
        signature_type_id: 0,
        param_start: 0,
        param_count: 0,
        local_start: 0,
        local_count: 0,
        block_start: 0,
        block_count: 1,
        entry_block_id: 0,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 0,
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

fn native_mir_print_helper_extern_function() MirFunction {
    return MirFunction{
        function_id: 0,
        lowered_function_id: 0,
        decl_id: MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR,
        source_core_body_id: CORE_BODY_INVALID_ID,
        symbol_id: MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR,
        signature_type_id: 1,
        param_start: 0,
        param_count: 0,
        local_start: 0,
        local_count: 0,
        block_start: 0,
        block_count: 0,
        entry_block_id: MIR_BLOCK_INVALID_ID,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 0,
        calling_convention: MIR_CALL_CONV_C,
        runtime_capability_mask: MIR_RUNTIME_CAP_C_EXTERN,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC,
        body_kind: MIR_FUNCTION_BODY_KIND_NORMAL,
        naked_asm_inst_start: -1,
        naked_asm_inst_count: 0,
        naked_forbidden_lowering_mask: 0,
        debug_loc_id: 0,
        flags: MIR_FUNCTION_FLAG_EXTERN,
    };
}

fn native_mir_print_body_function() MirFunction {
    return MirFunction{
        function_id: 1,
        lowered_function_id: 101,
        decl_id: 201,
        source_core_body_id: 0,
        symbol_id: 301,
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
        capability_req_count: 0,
        calling_convention: MIR_CALL_CONV_UYA,
        runtime_capability_mask: MIR_RUNTIME_CAP_HOSTED_LIBC + MIR_RUNTIME_CAP_C_EXTERN,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC,
        body_kind: MIR_FUNCTION_BODY_KIND_NORMAL,
        naked_asm_inst_start: -1,
        naked_asm_inst_count: 0,
        naked_forbidden_lowering_mask: 0,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn native_mir_naked_function() MirFunction {
    return MirFunction{
        function_id: 0,
        lowered_function_id: 100,
        decl_id: 200,
        source_core_body_id: 0,
        symbol_id: 300,
        signature_type_id: 0,
        param_start: 0,
        param_count: 0,
        local_start: 0,
        local_count: 0,
        block_start: 0,
        block_count: 0,
        entry_block_id: MIR_BLOCK_INVALID_ID,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 0,
        calling_convention: 1,
        runtime_capability_mask: 1,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC,
        body_kind: MIR_FUNCTION_BODY_KIND_ASM_ONLY_NAKED,
        naked_asm_inst_start: 0,
        naked_asm_inst_count: 1,
        naked_forbidden_lowering_mask: portable_mir_naked_forbidden_lowering_mask(),
        debug_loc_id: 0,
        flags: MIR_FUNCTION_FLAG_NAKED,
    };
}

fn native_mir_block() MirBlock {
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

fn native_mir_inst() MirInst {
    return MirInst{
        inst_id: 0,
        function_id: 0,
        block_id: 0,
        op: MIR_INST_OP_NOP,
        type_id: 0,
        result_value_id: MIR_VALUE_INVALID_ID,
        operand_start: 0,
        operand_count: 0,
        calling_convention: 1,
        runtime_capability_mask: 0,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        debug_loc_id: 44,
        flags: 9,
    };
}

fn native_mir_call_inst(operand_count: i32) MirInst {
    return MirInst{
        inst_id: 0,
        function_id: 0,
        block_id: 0,
        op: MIR_INST_OP_CALL,
        type_id: 0,
        result_value_id: MIR_VALUE_INVALID_ID,
        operand_start: 0,
        operand_count: operand_count,
        calling_convention: 2,
        runtime_capability_mask: 1,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        debug_loc_id: 1600,
        flags: 12,
    };
}

fn native_mir_print_write_str_call_inst() MirInst {
    return MirInst{
        inst_id: 0,
        function_id: 1,
        block_id: 0,
        op: MIR_INST_OP_CALL,
        type_id: 0,
        result_value_id: 0,
        operand_start: 0,
        operand_count: 4,
        calling_convention: MIR_CALL_CONV_C,
        runtime_capability_mask: MIR_RUNTIME_CAP_C_EXTERN,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        debug_loc_id: 1700,
        flags: MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR,
    };
}

fn native_mir_print_result_value() MirValue {
    return MirValue{
        value_id: 0,
        function_id: 1,
        block_id: 0,
        type_id: 0,
        defining_inst_id: 0,
        local_id: MIR_LOCAL_INVALID_ID,
        param_index: -1,
        source_expr_id: 4242,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn native_mir_call_value(id: i32) MirValue {
    return MirValue{
        value_id: id,
        function_id: 0,
        block_id: 0,
        type_id: 0,
        defining_inst_id: MIR_INST_INVALID_ID,
        local_id: MIR_LOCAL_INVALID_ID,
        param_index: id,
        source_expr_id: 5000 + id,
        debug_loc_id: 0,
        flags: MIR_VALUE_FLAG_PARAM,
    };
}

fn native_mir_call_operand(id: i32) MirOperand {
    return MirOperand{
        operand_id: id,
        kind: 1,
        value_id: id,
        local_id: MIR_LOCAL_INVALID_ID,
        type_id: 0,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        immediate_i32: 0,
        flags: 0,
    };
}

fn native_mir_print_operand(id: i32, type_id: i32, immediate: i32) MirOperand {
    return MirOperand{
        operand_id: id,
        kind: 0,
        value_id: MIR_VALUE_INVALID_ID,
        local_id: MIR_LOCAL_INVALID_ID,
        type_id: type_id,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        immediate_i32: immediate,
        flags: 0,
    };
}

fn native_mir_terminator() MirTerminator {
    return MirTerminator{
        terminator_id: 0,
        function_id: 0,
        block_id: 0,
        kind: MIR_TERMINATOR_KIND_RETURN,
        operand_start: 0,
        operand_count: 0,
        successor_start: 0,
        successor_count: 0,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn native_mir_result(error_code: i32) MirVerifierResult {
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

fn native_mir_empty_module() PortableMirModule {
    return PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_ACTIVE,
        target_profile: native_mir_profile(),
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
        functions: SemanticVector{ data: null, item_size: @size_of(MirFunction), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        blocks: SemanticVector{ data: null, item_size: @size_of(MirBlock), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        values: SemanticVector{ data: null, item_size: @size_of(MirValue), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        types: SemanticVector{ data: null, item_size: @size_of(MirType), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        locals: SemanticVector{ data: null, item_size: @size_of(MirLocal), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        insts: SemanticVector{ data: null, item_size: @size_of(MirInst), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        terminators: SemanticVector{ data: null, item_size: @size_of(MirTerminator), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        operands: SemanticVector{ data: null, item_size: @size_of(MirOperand), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        block_params: SemanticVector{ data: null, item_size: @size_of(MirBlockParam), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        successors: SemanticVector{ data: null, item_size: @size_of(MirSuccessor), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        debug_locs: SemanticVector{ data: null, item_size: @size_of(MirDebugLoc), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        capability_reqs: SemanticVector{ data: null, item_size: @size_of(MirCapabilityReq), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
}

test "native MIR emitter lowers print helper call to SysV x86_64 extern call" {
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

    var functions: [MirFunction: 2] = [];
    var blocks: [MirBlock: 1] = [];
    var values: [MirValue: 1] = [];
    var insts: [MirInst: 1] = [];
    var terminators: [MirTerminator: 1] = [];
    var operands: [MirOperand: 4] = [];
    var types: [MirType: 3] = [];
    functions[0] = native_mir_print_helper_extern_function();
    functions[1] = native_mir_print_body_function();
    blocks[0] = native_mir_block();
    blocks[0].function_id = 1;
    insts[0] = native_mir_print_write_str_call_inst();
    terminators[0] = native_mir_terminator();
    terminators[0].function_id = 1;
    values[0] = native_mir_print_result_value();
    types[0] = native_mir_type_i32();
    types[1] = native_mir_type_void(1);
    types[2] = native_mir_type_pointer(2, 0);
    operands[0] = native_mir_print_operand(0, 1, 0);
    operands[1] = native_mir_print_operand(1, 0, 1);
    operands[2] = native_mir_print_operand(2, 2, 4242);
    operands[3] = native_mir_print_operand(3, 0, 13);

    var module: PortableMirModule = native_mir_empty_module();
    module.arena = &arena;
    module.functions = SemanticVector{ data: &functions[0] as &byte, item_size: @size_of(MirFunction), count: 2usize, capacity: 2usize, bytes: @size_of(MirFunction) * 2usize, realloc_count: 0 };
    module.blocks = SemanticVector{ data: &blocks[0] as &byte, item_size: @size_of(MirBlock), count: 1usize, capacity: 1usize, bytes: @size_of(MirBlock), realloc_count: 0 };
    module.values = SemanticVector{ data: &values[0] as &byte, item_size: @size_of(MirValue), count: 1usize, capacity: 1usize, bytes: @size_of(MirValue), realloc_count: 0 };
    module.insts = SemanticVector{ data: &insts[0] as &byte, item_size: @size_of(MirInst), count: 1usize, capacity: 1usize, bytes: @size_of(MirInst), realloc_count: 0 };
    module.terminators = SemanticVector{ data: &terminators[0] as &byte, item_size: @size_of(MirTerminator), count: 1usize, capacity: 1usize, bytes: @size_of(MirTerminator), realloc_count: 0 };
    module.operands = SemanticVector{ data: &operands[0] as &byte, item_size: @size_of(MirOperand), count: 4usize, capacity: 4usize, bytes: @size_of(MirOperand) * 4usize, realloc_count: 0 };
    module.types = SemanticVector{ data: &types[0] as &byte, item_size: @size_of(MirType), count: 3usize, capacity: 3usize, bytes: @size_of(MirType) * 3usize, realloc_count: 0 };
    module.function_count = 2usize;
    module.block_count = 1usize;
    module.value_count = 1usize;
    module.inst_count = 1usize;
    module.terminator_count = 1usize;
    module.operand_count = 4usize;
    module.type_count = 3usize;

    var verifier: MirVerifierResult = native_mir_result(MIR_VERIFY_ERR_INVALID_MODULE);
    try assert_eq_i32(portable_mir_verify_module(&module, &verifier), 0);
    try assert_eq_i32(verifier.error_code, MIR_VERIFY_OK);

    var request: MirTargetBackendRequest = MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &verifier,
        MIR_TARGET_BACKEND_MACHINE), 0);

    var machine: MachineModule = MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        relocs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        symbols: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        strings: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        sections: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    machine_module_init(&machine, &arena);
    var emitter: NativeMirEmitter = native_mir_emitter_empty();
    try assert_eq_i32(native_mir_emitter_begin(&emitter, &request, &machine, 1), 0);
    try assert_eq_i32(native_mir_emitter_read_portable_mir(&emitter), 0);
    try assert_eq_i32(emitter.imported_function_count as i32, 2);
    try assert_eq_i32(emitter.imported_block_count as i32, 1);
    try assert_eq_i32(emitter.imported_inst_count as i32, 4);

    const got_block: &MachineBlock = machine_function_block_ptr(&machine, 1, 0);
    try expect(got_block != null);
    try assert_eq_i32(got_block.insts.count as i32, 4);
    const got_fd: &MachineInst = semantic_vector_item_ptr(&got_block.insts, 0usize) as &MachineInst;
    const got_ptr: &MachineInst = semantic_vector_item_ptr(&got_block.insts, 1usize) as &MachineInst;
    const got_len: &MachineInst = semantic_vector_item_ptr(&got_block.insts, 2usize) as &MachineInst;
    const got_call: &MachineInst = semantic_vector_item_ptr(&got_block.insts, 3usize) as &MachineInst;
    try expect(got_fd != null && got_ptr != null && got_len != null && got_call != null);
    try assert_eq_i32(got_fd.opcode, X86_64_OP_MOV_R32_IMM32);
    try assert_eq_i32(got_fd.dst, native_abi_sysv_gpr_arg_reg(0));
    try assert_eq_i32(got_fd.imm as i32, 1);
    try assert_eq_i32(got_ptr.opcode, X86_64_OP_MOV_R64_IMM64);
    try assert_eq_i32(got_ptr.dst, native_abi_sysv_gpr_arg_reg(1));
    try assert_eq_i32(got_ptr.imm as i32, 4242);
    try assert_eq_i32(got_len.opcode, X86_64_OP_MOV_R32_IMM32);
    try assert_eq_i32(got_len.dst, native_abi_sysv_gpr_arg_reg(2));
    try assert_eq_i32(got_len.imm as i32, 13);
    try assert_eq_i32(got_call.opcode, X86_64_OP_CALL_REL32);
    try assert_eq_i32(got_call.dst, 0);
    try assert_eq_i32(got_call.target_id, MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR);
    try assert_eq_i32(got_call.flags, MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR);
    try assert_eq_i32(machine.symbols.count as i32, 1);
    try assert_eq_i32(machine.relocs.count as i32, 1);
    const got_symbol: &MachineSymbol = semantic_vector_item_ptr(&machine.symbols, 0usize) as &MachineSymbol;
    const got_reloc: &MachineReloc = semantic_vector_item_ptr(&machine.relocs, 0usize) as &MachineReloc;
    try expect(got_symbol != null && got_reloc != null);
    try assert_eq_i32(got_symbol.name_id, MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR);
    try assert_eq_i32(got_symbol.kind, MACHINE_SYMBOL_KIND_FUNC);
    try assert_eq_i32(got_symbol.binding, MACHINE_SYMBOL_BIND_GLOBAL);
    try assert_eq_i32(got_reloc.symbol_id, 0);
    try assert_eq_i32(got_reloc.kind, MACHINE_RELOC_KIND_X86_64_PC32);
    try assert_eq_i32(got_reloc.offset as i32, 21);
    try assert_eq_i32(got_reloc.addend as i32, -4);

    machine_module_release(&machine);
    compiler_arena_free_all(&arena);
}

test "native MIR emitter imports verified PortableMIR into MachineModule" {
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

    var functions: [MirFunction: 1] = [];
    var blocks: [MirBlock: 1] = [];
    var insts: [MirInst: 1] = [];
    var terminators: [MirTerminator: 1] = [];
    var types: [MirType: 1] = [];
    functions[0] = native_mir_function();
    blocks[0] = native_mir_block();
    insts[0] = native_mir_inst();
    terminators[0] = native_mir_terminator();
    types[0] = native_mir_type_i32();

    var module: PortableMirModule = native_mir_empty_module();
    module.arena = &arena;
    module.functions = SemanticVector{ data: &functions[0] as &byte, item_size: @size_of(MirFunction), count: 1usize, capacity: 1usize, bytes: @size_of(MirFunction), realloc_count: 0 };
    module.blocks = SemanticVector{ data: &blocks[0] as &byte, item_size: @size_of(MirBlock), count: 1usize, capacity: 1usize, bytes: @size_of(MirBlock), realloc_count: 0 };
    module.insts = SemanticVector{ data: &insts[0] as &byte, item_size: @size_of(MirInst), count: 1usize, capacity: 1usize, bytes: @size_of(MirInst), realloc_count: 0 };
    module.terminators = SemanticVector{ data: &terminators[0] as &byte, item_size: @size_of(MirTerminator), count: 1usize, capacity: 1usize, bytes: @size_of(MirTerminator), realloc_count: 0 };
    module.types = SemanticVector{ data: &types[0] as &byte, item_size: @size_of(MirType), count: 1usize, capacity: 1usize, bytes: @size_of(MirType), realloc_count: 0 };
    module.function_count = 1usize;
    module.block_count = 1usize;
    module.inst_count = 1usize;
    module.terminator_count = 1usize;
    module.type_count = 1usize;

    var verifier: MirVerifierResult = native_mir_result(MIR_VERIFY_ERR_INVALID_MODULE);
    try assert_eq_i32(portable_mir_verify_module(&module, &verifier), 0);
    try assert_eq_i32(verifier.error_code, MIR_VERIFY_OK);

    var request: MirTargetBackendRequest = MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &verifier,
        MIR_TARGET_BACKEND_MACHINE), 0);

    var machine: MachineModule = MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        relocs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        symbols: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        strings: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        sections: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    machine_module_init(&machine, &arena);
    var emitter: NativeMirEmitter = native_mir_emitter_empty();
    try assert_eq_i32(native_mir_emitter_begin(&emitter, &request, &machine, 1), 0);
    try assert_eq_i32(emitter.status, NATIVE_MIR_EMITTER_STATUS_READY);
    try assert_eq_i32(emitter.mir_function_count as i32, 1);
    try assert_eq_i32(emitter.mir_block_count as i32, 1);
    try assert_eq_i32(emitter.mir_inst_count as i32, 1);
    try assert_eq_i32(native_mir_emitter_read_portable_mir(&emitter), 0);
    try assert_eq_i32(emitter.status, NATIVE_MIR_EMITTER_STATUS_DONE);
    try assert_eq_i32(emitter.imported_function_count as i32, 1);
    try assert_eq_i32(emitter.imported_block_count as i32, 1);
    try assert_eq_i32(emitter.imported_inst_count as i32, 1);
    try assert_eq_i32(machine_module_function_count(&machine) as i32, 1);

    const got_fn: &MachineFunction = machine_module_function_ptr(&machine, 0);
    try expect(got_fn != null);
    try assert_eq_i32(got_fn.function_id, 0);
    try assert_eq_i32(got_fn.name_id, 300);
    try assert_eq_i32(got_fn.blocks.count as i32, 1);
    const got_block: &MachineBlock = machine_function_block_ptr(&machine, 0, 0);
    try expect(got_block != null);
    try assert_eq_i32(got_block.block_id, 0);
    try assert_eq_i32(got_block.insts.count as i32, 1);
    const got_inst: &MachineInst = semantic_vector_item_ptr(&got_block.insts, 0usize) as &MachineInst;
    try expect(got_inst != null);
    try assert_eq_i32(got_inst.opcode, MIR_INST_OP_NOP);
    try assert_eq_i32(got_inst.dst, MIR_VALUE_INVALID_ID);
    try assert_eq_i32(got_inst.target_id, 0);
    try assert_eq_i32(got_inst.imm as i32, 44);
    try assert_eq_i32(got_inst.flags, 9);

    var output: MirTargetBackendOutput = MirTargetBackendOutput{
        backend_kind: 0,
        output_kind: 0,
        machine_module: null,
        ptx_module: null,
        exec_bytecode: null,
        c99_plan: null,
        diagnostic_code: 0,
        flags: 0,
    };
    try assert_eq_i32(native_mir_emitter_finish_output(&emitter, &output), 0);
    try assert_eq_i32(portable_mir_backend_output_matches_request(&request, &output), 1);
    try expect(output.machine_module != null);

    machine_module_release(&machine);
    compiler_arena_free_all(&arena);
}

test "native MIR emitter preserves compile_files shaped 16 argument call ABI" {
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

    var functions: [MirFunction: 1] = [];
    var blocks: [MirBlock: 1] = [];
    var values: [MirValue: 16] = [];
    var insts: [MirInst: 1] = [];
    var terminators: [MirTerminator: 1] = [];
    var operands: [MirOperand: 16] = [];
    var types: [MirType: 1] = [];
    functions[0] = native_mir_function();
    functions[0].param_count = 16;
    blocks[0] = native_mir_block();
    insts[0] = native_mir_call_inst(16);
    terminators[0] = native_mir_terminator();
    types[0] = native_mir_type_i32();
    var i: i32 = 0;
    while i < 16 {
        values[i] = native_mir_call_value(i);
        operands[i] = native_mir_call_operand(i);
        i = i + 1;
    }

    var module: PortableMirModule = native_mir_empty_module();
    module.arena = &arena;
    module.functions = SemanticVector{ data: &functions[0] as &byte, item_size: @size_of(MirFunction), count: 1usize, capacity: 1usize, bytes: @size_of(MirFunction), realloc_count: 0 };
    module.blocks = SemanticVector{ data: &blocks[0] as &byte, item_size: @size_of(MirBlock), count: 1usize, capacity: 1usize, bytes: @size_of(MirBlock), realloc_count: 0 };
    module.values = SemanticVector{ data: &values[0] as &byte, item_size: @size_of(MirValue), count: 16usize, capacity: 16usize, bytes: @size_of(MirValue) * 16usize, realloc_count: 0 };
    module.insts = SemanticVector{ data: &insts[0] as &byte, item_size: @size_of(MirInst), count: 1usize, capacity: 1usize, bytes: @size_of(MirInst), realloc_count: 0 };
    module.terminators = SemanticVector{ data: &terminators[0] as &byte, item_size: @size_of(MirTerminator), count: 1usize, capacity: 1usize, bytes: @size_of(MirTerminator), realloc_count: 0 };
    module.operands = SemanticVector{ data: &operands[0] as &byte, item_size: @size_of(MirOperand), count: 16usize, capacity: 16usize, bytes: @size_of(MirOperand) * 16usize, realloc_count: 0 };
    module.types = SemanticVector{ data: &types[0] as &byte, item_size: @size_of(MirType), count: 1usize, capacity: 1usize, bytes: @size_of(MirType), realloc_count: 0 };
    module.function_count = 1usize;
    module.block_count = 1usize;
    module.value_count = 16usize;
    module.inst_count = 1usize;
    module.terminator_count = 1usize;
    module.operand_count = 16usize;
    module.type_count = 1usize;

    var verifier: MirVerifierResult = native_mir_result(MIR_VERIFY_ERR_INVALID_MODULE);
    try assert_eq_i32(portable_mir_verify_module(&module, &verifier), 0);
    try assert_eq_i32(verifier.error_code, MIR_VERIFY_OK);

    var request: MirTargetBackendRequest = MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &verifier,
        MIR_TARGET_BACKEND_MACHINE), 0);
    try assert_eq_i32(request.target_profile_id, 77);

    var machine: MachineModule = MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        relocs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        symbols: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        strings: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        sections: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    machine_module_init(&machine, &arena);
    var emitter: NativeMirEmitter = native_mir_emitter_empty();
    try assert_eq_i32(native_mir_emitter_begin(&emitter, &request, &machine, 1), 0);
    try assert_eq_i32(native_mir_emitter_read_portable_mir(&emitter), 0);
    try assert_eq_i32(emitter.imported_function_count as i32, 1);
    try assert_eq_i32(emitter.imported_block_count as i32, 1);
    try assert_eq_i32(emitter.imported_inst_count as i32, 1);

    const got_block: &MachineBlock = machine_function_block_ptr(&machine, 0, 0);
    try expect(got_block != null);
    const got_inst: &MachineInst = semantic_vector_item_ptr(&got_block.insts, 0usize) as &MachineInst;
    try expect(got_inst != null);
    try assert_eq_i32(got_inst.opcode, MIR_INST_OP_CALL);
    try assert_eq_i32(got_inst.src0, 0);
    try assert_eq_i32(got_inst.src1, 16);
    try assert_eq_i32(got_inst.target_id, 0);
    try assert_eq_i32(got_inst.imm as i32, 1600);
    try assert_eq_i32(got_inst.flags, 12);

    machine_module_release(&machine);
    compiler_arena_free_all(&arena);
}

test "native MIR emitter imports naked functions without ordinary frame blocks" {
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

    var functions: [MirFunction: 1] = [];
    var types: [MirType: 1] = [];
    functions[0] = native_mir_naked_function();
    types[0] = native_mir_type_i32();

    var module: PortableMirModule = native_mir_empty_module();
    module.arena = &arena;
    module.functions = SemanticVector{ data: &functions[0] as &byte, item_size: @size_of(MirFunction), count: 1usize, capacity: 1usize, bytes: @size_of(MirFunction), realloc_count: 0 };
    module.types = SemanticVector{ data: &types[0] as &byte, item_size: @size_of(MirType), count: 1usize, capacity: 1usize, bytes: @size_of(MirType), realloc_count: 0 };
    module.function_count = 1usize;
    module.type_count = 1usize;

    var verifier: MirVerifierResult = native_mir_result(MIR_VERIFY_ERR_INVALID_MODULE);
    try assert_eq_i32(portable_mir_verify_module(&module, &verifier), 0);
    try assert_eq_i32(verifier.error_code, MIR_VERIFY_OK);

    var request: MirTargetBackendRequest = MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &verifier,
        MIR_TARGET_BACKEND_MACHINE), 0);

    var machine: MachineModule = MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        relocs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        symbols: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        strings: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        sections: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    machine_module_init(&machine, &arena);

    var emitter: NativeMirEmitter = native_mir_emitter_empty();
    try assert_eq_i32(native_mir_emitter_begin(&emitter, &request, &machine, 1), 0);
    try assert_eq_i32(native_mir_emitter_read_portable_mir(&emitter), 0);
    try assert_eq_i32(emitter.imported_function_count as i32, 1);
    try assert_eq_i32(emitter.imported_block_count as i32, 0);
    try assert_eq_i32(emitter.imported_inst_count as i32, 0);
    try assert_eq_i32(machine_module_function_count(&machine) as i32, 1);

    const got_fn: &MachineFunction = machine_module_function_ptr(&machine, 0);
    try expect(got_fn != null);
    try assert_eq_i32(got_fn.function_id, 0);
    try assert_eq_i32(got_fn.name_id, 300);
    try assert_eq_i32(got_fn.frame_size, 0);
    try assert_eq_i32(got_fn.frame_align, 0);
    try assert_eq_i32(got_fn.blocks.count as i32, 0);

    machine_module_release(&machine);
    compiler_arena_free_all(&arena);
}

test "native MIR emitter gates request kind verifier and streaming executable output" {
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
    var module: PortableMirModule = native_mir_empty_module();
    module.arena = &arena;
    var verifier: MirVerifierResult = native_mir_result(MIR_VERIFY_OK);
    var request: MirTargetBackendRequest = MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
    var machine: MachineModule = MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        relocs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        symbols: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        strings: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        sections: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    machine_module_init(&machine, &arena);
    var emitter: NativeMirEmitter = native_mir_emitter_empty();
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &verifier,
        MIR_TARGET_BACKEND_C99), 0);
    try assert_eq_i32(native_mir_emitter_begin(&emitter, &request, &machine, 1), -1);
    try assert_eq_i32(emitter.status, NATIVE_MIR_EMITTER_STATUS_ERROR);

    request.backend_kind = MIR_TARGET_BACKEND_MACHINE;
    request.verifier_error_code = MIR_VERIFY_ERR_INVALID_MODULE;
    emitter = native_mir_emitter_empty();
    try assert_eq_i32(native_mir_emitter_begin(&emitter, &request, &machine, 1), -1);

    request.verifier_error_code = MIR_VERIFY_OK;
    emitter = native_mir_emitter_empty();
    try assert_eq_i32(native_mir_emitter_begin(&emitter, &request, &machine, 1), 0);
    var code: [byte: 4] = [];
    code[0] = 195 as byte;
    code[1] = 144 as byte;
    code[2] = 144 as byte;
    code[3] = 144 as byte;
    const fp: &FILE = fopen("$output_path" as &const byte, "w+b" as &const byte);
    try expect(fp != null);
    const result: NativeMirEmitterOutputResult = native_mir_emitter_write_executable_stream(&emitter,
        fp, &code[0] as &const byte, 4usize);
    try assert_eq_i32(result.status, NATIVE_MIR_EMITTER_STATUS_DONE);
    try assert_eq_i32(result.output_bytes as i32, ELF64_MIN_EXEC_HEADERS + 4);
    try assert_eq_i32(result.code_bytes as i32, 4);
    try expect(result.temp_peak_bytes == ELF64_MIN_EXEC_HEADERS as usize);
    try expect(native_mir_emitter_stream_temp_peak_bytes(4096usize) == ELF64_MIN_EXEC_HEADERS as usize);

    rewind(fp);
    var out: [byte: 128] = [];
    const nread: usize = fread(&out[0], 1usize, result.output_bytes, fp);
    try expect(nread == result.output_bytes);
    try assert_eq_i32(native_mir_bval(&out[0], 0usize), 127);
    try assert_eq_i32(native_mir_bval(&out[0], 1usize), 69);
    try assert_eq_i32(native_mir_bval(&out[0], 2usize), 76);
    try assert_eq_i32(native_mir_bval(&out[0], 3usize), 70);
    try assert_eq_i32(native_mir_bval(&out[0], ELF64_MIN_EXEC_HEADERS as usize), 195);
    _ = fclose(fp);
    machine_module_release(&machine);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c --project-root "$tmp_dir/")

echo "verify_native_mir_emitter: ok"
