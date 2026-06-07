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
export type CoreBodyId = i32;

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
    };
}

fn verifier_run(mode: i32) i32 {
    var functions: [MirFunction: 1] = [];
    var blocks: [MirBlock: 1] = [];
    var values: [MirValue: 2] = [];
    var types: [MirType: 5] = [];
    var locals: [MirLocal: 1] = [];
    var insts: [MirInst: 1] = [];
    var terminators: [MirTerminator: 1] = [];
    var operands: [MirOperand: 2] = [];
    var caps: [MirCapabilityReq: 1] = [];

    functions[0] = verifier_function();
    blocks[0] = verifier_block();
    values[0] = verifier_value(0, 1, MIR_INST_INVALID_ID, MIR_VALUE_FLAG_PARAM);
    values[1] = verifier_value(1, 0, 0, 0);
    types[0] = verifier_type(0, MIR_TYPE_KIND_I32);
    types[1] = verifier_type(1, MIR_TYPE_KIND_POINTER);
    types[2] = verifier_type(2, MIR_TYPE_KIND_ATOMIC);
    types[3] = verifier_type(3, MIR_TYPE_KIND_VECTOR);
    types[4] = verifier_type(4, MIR_TYPE_KIND_MASK);
    locals[0] = verifier_local();
    insts[0] = verifier_inst();
    terminators[0] = verifier_terminator();
    operands[0] = verifier_operand(0, 0, 1);
    operands[1] = verifier_operand(1, 1, 0);
    caps[0] = verifier_capability();

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

    var module: PortableMirModule = verifier_empty_module();
    module.functions = verifier_vec(&functions[0] as &byte, @size_of(MirFunction), 1usize);
    module.blocks = verifier_vec(&blocks[0] as &byte, @size_of(MirBlock), 1usize);
    module.values = verifier_vec(&values[0] as &byte, @size_of(MirValue), 2usize);
    module.types = verifier_vec(&types[0] as &byte, @size_of(MirType), 5usize);
    module.locals = verifier_vec(&locals[0] as &byte, @size_of(MirLocal), 1usize);
    module.insts = verifier_vec(&insts[0] as &byte, @size_of(MirInst), 1usize);
    module.terminators = verifier_vec(&terminators[0] as &byte, @size_of(MirTerminator), 1usize);
    module.operands = verifier_vec(&operands[0] as &byte, @size_of(MirOperand), 2usize);
    module.capability_reqs = verifier_vec(&caps[0] as &byte, @size_of(MirCapabilityReq), 1usize);
    module.function_count = 1usize;
    module.block_count = 1usize;
    module.value_count = 2usize;
    module.type_count = 5usize;
    module.local_count = 1usize;
    module.inst_count = 1usize;
    module.terminator_count = 1usize;
    module.operand_count = 2usize;
    module.capability_req_count = 1usize;

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

test "PortableMIR verifier rejects malformed control and data flow" {
    try assert_eq_i32(verifier_run(1), MIR_VERIFY_ERR_MISSING_TERMINATOR);
    try assert_eq_i32(verifier_run(2), MIR_VERIFY_ERR_TYPE_MISMATCH);
    try assert_eq_i32(verifier_run(8), MIR_VERIFY_ERR_UNDEFINED_USE);
}

test "PortableMIR verifier rejects target and layout violations" {
    try assert_eq_i32(verifier_run(3), MIR_VERIFY_ERR_INVALID_ADDRESS);
    try assert_eq_i32(verifier_run(7), MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
    try assert_eq_i32(verifier_run(10), MIR_VERIFY_ERR_INVALID_LAYOUT);
    try assert_eq_i32(verifier_run(11), MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
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
