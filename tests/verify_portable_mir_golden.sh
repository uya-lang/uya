#!/usr/bin/env bash

# Phase 9A：验证 PortableMIR 的基础 golden dump 形状。
# 覆盖 block、value、load/store、aggregate field address、branch、call、cleanup path、
# atomic、vector 和 mask。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: PortableMIR golden 缺少证据: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$IDS_FILE" "$ARENA_FILE" "$TABLE_FILE" "$MIR_FILE" "$MIR_CONTRACT_FILE" "$MIR_VERIFIER_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_INST_OP_LOAD \
    MIR_INST_OP_STORE \
    MIR_INST_OP_CALL \
    MIR_TERMINATOR_KIND_BR \
    MIR_TERMINATOR_KIND_COND_BR \
    MIR_BLOCK_FLAG_CLEANUP \
    MIR_TYPE_KIND_STRUCT \
    MIR_TYPE_KIND_ATOMIC \
    MIR_TYPE_KIND_VECTOR \
    MIR_TYPE_KIND_MASK \
    portable_mir_append_block \
    portable_mir_append_value \
    portable_mir_append_inst \
    portable_mir_append_terminator; do
    require_pattern "$MIR_FILE" "$symbol" "MIR symbol $symbol"
done

require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_module' "MIR verifier entry"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_INST_OP_FIELD_ADDR' "aggregate field address opcode"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_INST_OP_ATOMIC_LOAD' "atomic load opcode"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_INST_OP_VECTOR_SPLAT' "vector splat opcode"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_INST_OP_VECTOR_SELECT' "mask/vector select opcode"
require_pattern "$PORTABLE_MIR_DOC" '^## 23\. Dump 和 Golden 格式' "dump/golden 文档章节"
require_pattern "$PORTABLE_MIR_DOC" 'golden tests 中 source path 可 normalize 或隐藏' "golden normalize 规则"
require_pattern "$PORTABLE_MIR_DOC" 'golden test 应使用小 MIR program 隔离一个 feature' "小 MIR golden 规则"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-golden.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat "$IDS_FILE" >"$tmp_dir/main.uya"
cat >>"$tmp_dir/main.uya" <<'EOF'
export type CoreBodyId = i32;
EOF
cat "$ARENA_FILE" "$TABLE_FILE" "$MIR_FILE" "$MIR_VERIFIER_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
const GOLDEN_OP_FIELD_ADDR: i32 = 8;
const GOLDEN_OP_ATOMIC_LOAD: i32 = 17;
const GOLDEN_OP_VECTOR_SPLAT: i32 = 21;
const GOLDEN_OP_VECTOR_SELECT: i32 = 24;

fn golden_type(id: i32, kind: i32, pointee: i32, field_count: i32) MirType {
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
        pointee_type_id: pointee,
        field_start: 0,
        field_count: field_count,
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
        typ.address_space = MIR_ADDRESS_SPACE_HOST;
    }
    if kind == MIR_TYPE_KIND_STRUCT {
        typ.size_bytes = 8usize;
        typ.align_bytes = 4usize;
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

fn golden_local(id: i32, type_id: i32) MirLocal {
    return MirLocal{
        local_id: id,
        function_id: 0,
        type_id: type_id,
        source_symbol_id: 200 + id,
        address_space: MIR_ADDRESS_SPACE_HOST,
        alignment: 4usize,
        debug_loc_id: 0,
        flags: MIR_LOCAL_FLAG_ADDRESS_TAKEN,
    };
}

fn golden_value(id: i32, block_id: i32, type_id: i32, defining_inst_id: i32,
    param_index: i32, flags: i32) MirValue {
    return MirValue{
        value_id: id,
        function_id: 0,
        block_id: block_id,
        type_id: type_id,
        defining_inst_id: defining_inst_id,
        local_id: MIR_LOCAL_INVALID_ID,
        param_index: param_index,
        source_expr_id: 300 + id,
        debug_loc_id: 0,
        flags: flags,
    };
}

fn golden_operand(id: i32, value_id: i32, local_id: i32, type_id: i32) MirOperand {
    return MirOperand{
        operand_id: id,
        kind: 0,
        value_id: value_id,
        local_id: local_id,
        type_id: type_id,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        immediate_i32: 0,
        flags: 0,
    };
}

fn golden_inst(id: i32, block_id: i32, op: i32, type_id: i32, result_value_id: i32,
    operand_start: i32, operand_count: i32, address_space: i32) MirInst {
    return MirInst{
        inst_id: id,
        function_id: 0,
        block_id: block_id,
        op: op,
        type_id: type_id,
        result_value_id: result_value_id,
        operand_start: operand_start,
        operand_count: operand_count,
        calling_convention: 1,
        runtime_capability_mask: 0,
        address_space: address_space,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn golden_term(id: i32, block_id: i32, kind: i32, operand_start: i32,
    operand_count: i32, successor_start: i32, successor_count: i32) MirTerminator {
    return MirTerminator{
        terminator_id: id,
        function_id: 0,
        block_id: block_id,
        kind: kind,
        operand_start: operand_start,
        operand_count: operand_count,
        successor_start: successor_start,
        successor_count: successor_count,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn golden_block(id: i32, param_start: i32, param_count: i32, inst_start: i32,
    inst_count: i32, terminator_id: i32, flags: i32) MirBlock {
    return MirBlock{
        block_id: id,
        function_id: 0,
        param_start: param_start,
        param_count: param_count,
        inst_start: inst_start,
        inst_count: inst_count,
        terminator_id: terminator_id,
        debug_loc_id: 0,
        flags: flags,
    };
}

fn golden_successor(id: i32, block_id: i32, arg_start: i32, arg_count: i32) MirSuccessor {
    return MirSuccessor{
        successor_id: id,
        block_id: block_id,
        arg_start: arg_start,
        arg_count: arg_count,
        flags: 0,
    };
}

fn golden_append_module(module: &PortableMirModule) i32 {
    var loc: MirDebugLoc = MirDebugLoc{
        debug_loc_id: 0,
        source_span_id: 500,
        file_id: 0,
        line: 1,
        column: 1,
    };
    if portable_mir_append_debug_loc(module, &loc) != 0 { return -1; }

    var t0: MirType = golden_type(0, MIR_TYPE_KIND_I32, MIR_TYPE_INVALID_ID, 0);
    var t1: MirType = golden_type(1, MIR_TYPE_KIND_POINTER, 0, 0);
    var t2: MirType = golden_type(2, MIR_TYPE_KIND_STRUCT, MIR_TYPE_INVALID_ID, 2);
    var t3: MirType = golden_type(3, MIR_TYPE_KIND_POINTER, 2, 0);
    var t4: MirType = golden_type(4, MIR_TYPE_KIND_ATOMIC, MIR_TYPE_INVALID_ID, 0);
    var t5: MirType = golden_type(5, MIR_TYPE_KIND_VECTOR, MIR_TYPE_INVALID_ID, 0);
    var t6: MirType = golden_type(6, MIR_TYPE_KIND_MASK, MIR_TYPE_INVALID_ID, 0);
    if portable_mir_append_type(module, &t0) != 0 { return -1; }
    if portable_mir_append_type(module, &t1) != 0 { return -1; }
    if portable_mir_append_type(module, &t2) != 0 { return -1; }
    if portable_mir_append_type(module, &t3) != 0 { return -1; }
    if portable_mir_append_type(module, &t4) != 0 { return -1; }
    if portable_mir_append_type(module, &t5) != 0 { return -1; }
    if portable_mir_append_type(module, &t6) != 0 { return -1; }

    var local0: MirLocal = golden_local(0, 0);
    var local1: MirLocal = golden_local(1, 2);
    var local2: MirLocal = golden_local(2, 4);
    if portable_mir_append_local(module, &local0) != 0 { return -1; }
    if portable_mir_append_local(module, &local1) != 0 { return -1; }
    if portable_mir_append_local(module, &local2) != 0 { return -1; }

    var value0: MirValue = golden_value(0, 0, 0, MIR_INST_INVALID_ID, 0, MIR_VALUE_FLAG_PARAM);
    var value1: MirValue = golden_value(1, 0, 0, 0, -1, 0);
    var value2: MirValue = golden_value(2, 0, 0, 1, -1, 0);
    var value3: MirValue = golden_value(3, 1, 3, 3, -1, MIR_VALUE_FLAG_ADDRESS);
    var value4: MirValue = golden_value(4, 1, 0, MIR_INST_INVALID_ID, 0, MIR_VALUE_FLAG_PARAM);
    var value5: MirValue = golden_value(5, 1, 0, 4, -1, 0);
    var value6: MirValue = golden_value(6, 2, 4, 6, -1, 0);
    var value7: MirValue = golden_value(7, 2, 5, 7, -1, 0);
    var value8: MirValue = golden_value(8, 2, 6, 8, -1, 0);
    if portable_mir_append_value(module, &value0) != 0 { return -1; }
    if portable_mir_append_value(module, &value1) != 0 { return -1; }
    if portable_mir_append_value(module, &value2) != 0 { return -1; }
    if portable_mir_append_value(module, &value3) != 0 { return -1; }
    if portable_mir_append_value(module, &value4) != 0 { return -1; }
    if portable_mir_append_value(module, &value5) != 0 { return -1; }
    if portable_mir_append_value(module, &value6) != 0 { return -1; }
    if portable_mir_append_value(module, &value7) != 0 { return -1; }
    if portable_mir_append_value(module, &value8) != 0 { return -1; }

    var param0: MirBlockParam = MirBlockParam{
        param_id: 0,
        block_id: 1,
        value_id: 4,
        type_id: 0,
        debug_loc_id: 0,
        flags: MIR_VALUE_FLAG_PARAM,
    };
    if portable_mir_append_block_param(module, &param0) != 0 { return -1; }

    var op0: MirOperand = golden_operand(0, MIR_VALUE_INVALID_ID, 0, 1);
    var op1: MirOperand = golden_operand(1, 1, MIR_LOCAL_INVALID_ID, 0);
    var op2: MirOperand = golden_operand(2, MIR_VALUE_INVALID_ID, 0, 1);
    var op3: MirOperand = golden_operand(3, 2, MIR_LOCAL_INVALID_ID, 0);
    var op4: MirOperand = golden_operand(4, 2, MIR_LOCAL_INVALID_ID, 0);
    var op5: MirOperand = golden_operand(5, MIR_VALUE_INVALID_ID, 1, 3);
    var op6: MirOperand = golden_operand(6, 3, MIR_LOCAL_INVALID_ID, 3);
    var op7: MirOperand = golden_operand(7, 3, MIR_LOCAL_INVALID_ID, 3);
    var op8: MirOperand = golden_operand(8, 5, MIR_LOCAL_INVALID_ID, 0);
    var op9: MirOperand = golden_operand(9, MIR_VALUE_INVALID_ID, 2, 4);
    var op10: MirOperand = golden_operand(10, 2, MIR_LOCAL_INVALID_ID, 0);
    var op11: MirOperand = golden_operand(11, 7, MIR_LOCAL_INVALID_ID, 5);
    if portable_mir_append_operand(module, &op0) != 0 { return -1; }
    if portable_mir_append_operand(module, &op1) != 0 { return -1; }
    if portable_mir_append_operand(module, &op2) != 0 { return -1; }
    if portable_mir_append_operand(module, &op3) != 0 { return -1; }
    if portable_mir_append_operand(module, &op4) != 0 { return -1; }
    if portable_mir_append_operand(module, &op5) != 0 { return -1; }
    if portable_mir_append_operand(module, &op6) != 0 { return -1; }
    if portable_mir_append_operand(module, &op7) != 0 { return -1; }
    if portable_mir_append_operand(module, &op8) != 0 { return -1; }
    if portable_mir_append_operand(module, &op9) != 0 { return -1; }
    if portable_mir_append_operand(module, &op10) != 0 { return -1; }
    if portable_mir_append_operand(module, &op11) != 0 { return -1; }

    var succ0: MirSuccessor = golden_successor(0, 1, 4, 1);
    var succ1: MirSuccessor = golden_successor(1, 2, 0, 0);
    var succ2: MirSuccessor = golden_successor(2, 3, 0, 0);
    var succ3: MirSuccessor = golden_successor(3, 3, 0, 0);
    if portable_mir_append_successor(module, &succ0) != 0 { return -1; }
    if portable_mir_append_successor(module, &succ1) != 0 { return -1; }
    if portable_mir_append_successor(module, &succ2) != 0 { return -1; }
    if portable_mir_append_successor(module, &succ3) != 0 { return -1; }

    var inst0: MirInst = golden_inst(0, 0, MIR_INST_OP_LOAD, 0, 1, 0, 1, MIR_ADDRESS_SPACE_HOST);
    var inst1: MirInst = golden_inst(1, 0, MIR_INST_OP_CALL, 0, 2, 1, 1, MIR_ADDRESS_SPACE_GENERIC);
    var inst2: MirInst = golden_inst(2, 0, MIR_INST_OP_STORE, 0, MIR_VALUE_INVALID_ID, 2, 2, MIR_ADDRESS_SPACE_HOST);
    var inst3: MirInst = golden_inst(3, 1, GOLDEN_OP_FIELD_ADDR, 3, 3, 5, 1, MIR_ADDRESS_SPACE_HOST);
    var inst4: MirInst = golden_inst(4, 1, MIR_INST_OP_LOAD, 0, 5, 6, 1, MIR_ADDRESS_SPACE_HOST);
    var inst5: MirInst = golden_inst(5, 1, MIR_INST_OP_STORE, 0, MIR_VALUE_INVALID_ID, 7, 2, MIR_ADDRESS_SPACE_HOST);
    var inst6: MirInst = golden_inst(6, 2, GOLDEN_OP_ATOMIC_LOAD, 4, 6, 9, 1, MIR_ADDRESS_SPACE_HOST);
    var inst7: MirInst = golden_inst(7, 2, GOLDEN_OP_VECTOR_SPLAT, 5, 7, 10, 1, MIR_ADDRESS_SPACE_GENERIC);
    var inst8: MirInst = golden_inst(8, 2, GOLDEN_OP_VECTOR_SELECT, 6, 8, 11, 1, MIR_ADDRESS_SPACE_GENERIC);
    if portable_mir_append_inst(module, &inst0) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst1) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst2) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst3) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst4) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst5) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst6) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst7) != 0 { return -1; }
    if portable_mir_append_inst(module, &inst8) != 0 { return -1; }

    var term0: MirTerminator = golden_term(0, 0, MIR_TERMINATOR_KIND_COND_BR, 4, 1, 0, 2);
    var term1: MirTerminator = golden_term(1, 1, MIR_TERMINATOR_KIND_BR, 0, 0, 2, 1);
    var term2: MirTerminator = golden_term(2, 2, MIR_TERMINATOR_KIND_BR, 0, 0, 3, 1);
    var term3: MirTerminator = golden_term(3, 3, MIR_TERMINATOR_KIND_RETURN, 0, 0, 0, 0);
    if portable_mir_append_terminator(module, &term0) != 0 { return -1; }
    if portable_mir_append_terminator(module, &term1) != 0 { return -1; }
    if portable_mir_append_terminator(module, &term2) != 0 { return -1; }
    if portable_mir_append_terminator(module, &term3) != 0 { return -1; }

    var block0: MirBlock = golden_block(0, 0, 0, 0, 3, 0, 0);
    var block1: MirBlock = golden_block(1, 0, 1, 3, 3, 1, 0);
    var block2: MirBlock = golden_block(2, 0, 0, 6, 3, 2, 0);
    var block3: MirBlock = golden_block(3, 0, 0, 9, 0, 3, MIR_BLOCK_FLAG_CLEANUP);
    if portable_mir_append_block(module, &block0) != 0 { return -1; }
    if portable_mir_append_block(module, &block1) != 0 { return -1; }
    if portable_mir_append_block(module, &block2) != 0 { return -1; }
    if portable_mir_append_block(module, &block3) != 0 { return -1; }

    var func: MirFunction = MirFunction{
        function_id: 0,
        lowered_function_id: 10,
        decl_id: 20,
        source_core_body_id: 30,
        symbol_id: 40,
        signature_type_id: 0,
        param_start: 0,
        param_count: 1,
        local_start: 0,
        local_count: 3,
        block_start: 0,
        block_count: 4,
        entry_block_id: 0,
        cleanup_model: 1,
        capability_req_start: 0,
        capability_req_count: 0,
        calling_convention: 1,
        runtime_capability_mask: 1,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC + MIR_ADDRESS_SPACE_HOST,
        body_kind: MIR_FUNCTION_BODY_KIND_NORMAL,
        naked_asm_inst_start: MIR_INST_INVALID_ID,
        naked_asm_inst_count: 0,
        naked_forbidden_lowering_mask: 0,
        debug_loc_id: 0,
        flags: 0,
    };
    if portable_mir_append_function(module, &func) != 0 { return -1; }
    return 0;
}

fn dump_module(module: &PortableMirModule) void {
    printf("mir_module profile=%d ptr=%d funcs=%d blocks=%d values=%d types=%d locals=%d insts=%d terms=%d operands=%d successors=%d block_params=%d cleanup=1\n",
        module.target_profile.profile_id,
        module.target_profile.pointer_size,
        module.function_count as i32,
        module.block_count as i32,
        module.value_count as i32,
        module.type_count as i32,
        module.local_count as i32,
        module.inst_count as i32,
        module.terminator_count as i32,
        module.operand_count as i32,
        module.successor_count as i32,
        module.block_param_count as i32);
}

fn dump_types(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.types.count {
        const typ: &MirType = semantic_vector_item_ptr(&module.types, i) as &MirType;
        printf("type#%d kind=%d size=%d align=%d pointee=%d fields=%d addr=%d\n",
            typ.type_id, typ.kind, typ.size_bytes as i32, typ.align_bytes as i32,
            typ.pointee_type_id, typ.field_count, typ.address_space);
        i = i + 1usize;
    }
}

fn dump_locals(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.locals.count {
        const local: &MirLocal = semantic_vector_item_ptr(&module.locals, i) as &MirLocal;
        printf("local#%d f=%d t=%d addr=%d align=%d flags=%d\n",
            local.local_id, local.function_id, local.type_id, local.address_space,
            local.alignment as i32, local.flags);
        i = i + 1usize;
    }
}

fn dump_values(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.values.count {
        const value: &MirValue = semantic_vector_item_ptr(&module.values, i) as &MirValue;
        printf("value#%d f=%d bb=%d t=%d def=%d local=%d param=%d flags=%d\n",
            value.value_id, value.function_id, value.block_id, value.type_id,
            value.defining_inst_id, value.local_id, value.param_index, value.flags);
        i = i + 1usize;
    }
}

fn dump_operands(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.operands.count {
        const operand: &MirOperand = semantic_vector_item_ptr(&module.operands, i) as &MirOperand;
        printf("operand#%d value=%d local=%d type=%d imm=%d\n",
            operand.operand_id, operand.value_id, operand.local_id, operand.type_id,
            operand.immediate_i32);
        i = i + 1usize;
    }
}

fn dump_insts(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.insts.count {
        const inst: &MirInst = semantic_vector_item_ptr(&module.insts, i) as &MirInst;
        printf("inst#%d bb=%d op=%d type=%d result=%d ops=%d+%d cc=%d cap=%d addr=%d\n",
            inst.inst_id, inst.block_id, inst.op, inst.type_id, inst.result_value_id,
            inst.operand_start, inst.operand_count, inst.calling_convention,
            inst.runtime_capability_mask, inst.address_space);
        i = i + 1usize;
    }
}

fn dump_terms(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.terminators.count {
        const term: &MirTerminator = semantic_vector_item_ptr(&module.terminators, i) as &MirTerminator;
        printf("term#%d bb=%d kind=%d ops=%d+%d succ=%d+%d\n",
            term.terminator_id, term.block_id, term.kind, term.operand_start,
            term.operand_count, term.successor_start, term.successor_count);
        i = i + 1usize;
    }
}

fn dump_successors(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.successors.count {
        const succ: &MirSuccessor = semantic_vector_item_ptr(&module.successors, i) as &MirSuccessor;
        printf("succ#%d ->bb%d args=%d+%d\n",
            succ.successor_id, succ.block_id, succ.arg_start, succ.arg_count);
        i = i + 1usize;
    }
}

fn dump_blocks(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.blocks.count {
        const block: &MirBlock = semantic_vector_item_ptr(&module.blocks, i) as &MirBlock;
        printf("bb#%d f=%d params=%d+%d insts=%d+%d term=%d flags=%d\n",
            block.block_id, block.function_id, block.param_start, block.param_count,
            block.inst_start, block.inst_count, block.terminator_id, block.flags);
        i = i + 1usize;
    }
}

fn dump_functions(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.functions.count {
        const func: &MirFunction = semantic_vector_item_ptr(&module.functions, i) as &MirFunction;
        printf("fn#%d sig=t%d params=%d+%d locals=%d+%d blocks=%d+%d entry=bb%d cleanup=%d cc=%d addrmask=%d\n",
            func.function_id, func.signature_type_id, func.param_start, func.param_count,
            func.local_start, func.local_count, func.block_start, func.block_count,
            func.entry_block_id, func.cleanup_model, func.calling_convention,
            func.required_address_space_mask);
        i = i + 1usize;
    }
}

export fn main() i32 {
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

    var module: PortableMirModule = PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_UNINITIALIZED,
        target_profile: MirTargetProfile{
            profile_id: 0,
            pointer_size: 0,
            endianness: 0,
            default_address_space: MIR_ADDRESS_SPACE_GENERIC,
            runtime_mode: MIR_RUNTIME_MODE_HOSTED,
            call_abi_profile: MIR_CALL_ABI_PROFILE_HOSTED_SYSV,
            supported_address_spaces: MIR_ADDRESS_SPACE_GENERIC + MIR_ADDRESS_SPACE_HOST,
            supported_calling_conventions: 3,
            runtime_capability_mask: 3,
            feature_flags: 0,
        },
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
        functions: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        blocks: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        values: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        types: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        locals: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        insts: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        terminators: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        operands: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        block_params: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        successors: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        debug_locs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        capability_reqs: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    portable_mir_module_init(&module, &arena);
    module.target_profile.profile_id = 7;
    module.target_profile.pointer_size = 8;

    if golden_append_module(&module) != 0 {
        fprintf(libc.stderr, "golden append failed\n" as *byte);
        return 1;
    }

    var verify: MirVerifierResult = MirVerifierResult{
        error_code: MIR_VERIFY_OK,
        function_id: MIR_FUNCTION_INVALID_ID,
        block_id: MIR_BLOCK_INVALID_ID,
        inst_id: MIR_INST_INVALID_ID,
        value_id: MIR_VALUE_INVALID_ID,
        type_id: MIR_TYPE_INVALID_ID,
        operand_id: -1,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
    };
    if portable_mir_verify_module(&module, &verify) != 0 {
        fprintf(libc.stderr, "golden verify failed code=%d fn=%d bb=%d inst=%d value=%d type=%d\n" as *byte,
            verify.error_code, verify.function_id, verify.block_id, verify.inst_id,
            verify.value_id, verify.type_id);
        return 1;
    }

    dump_module(&module);
    dump_functions(&module);
    dump_types(&module);
    dump_locals(&module);
    dump_values(&module);
    dump_operands(&module);
    dump_insts(&module);
    dump_terms(&module);
    dump_successors(&module);
    dump_blocks(&module);

    portable_mir_module_release(&module);
    compiler_arena_free_all(&arena);
    return 0;
}
EOF

expected="$tmp_dir/expected.txt"
actual="$tmp_dir/actual.txt"
build_out="$tmp_dir/build.out"
build_err="$tmp_dir/build.err"

cat >"$expected" <<'EOF'
mir_module profile=7 ptr=8 funcs=1 blocks=4 values=9 types=7 locals=3 insts=9 terms=4 operands=12 successors=4 block_params=1 cleanup=1
fn#0 sig=t0 params=0+1 locals=0+3 blocks=0+4 entry=bb0 cleanup=1 cc=1 addrmask=3
type#0 kind=3 size=4 align=4 pointee=-1 fields=0 addr=1
type#1 kind=5 size=8 align=8 pointee=0 fields=0 addr=2
type#2 kind=6 size=8 align=4 pointee=-1 fields=2 addr=1
type#3 kind=5 size=8 align=8 pointee=2 fields=0 addr=2
type#4 kind=7 size=4 align=4 pointee=-1 fields=0 addr=1
type#5 kind=8 size=16 align=16 pointee=-1 fields=0 addr=1
type#6 kind=9 size=1 align=1 pointee=-1 fields=0 addr=1
local#0 f=0 t=0 addr=2 align=4 flags=1
local#1 f=0 t=2 addr=2 align=4 flags=1
local#2 f=0 t=4 addr=2 align=4 flags=1
value#0 f=0 bb=0 t=0 def=-1 local=-1 param=0 flags=1
value#1 f=0 bb=0 t=0 def=0 local=-1 param=-1 flags=0
value#2 f=0 bb=0 t=0 def=1 local=-1 param=-1 flags=0
value#3 f=0 bb=1 t=3 def=3 local=-1 param=-1 flags=2
value#4 f=0 bb=1 t=0 def=-1 local=-1 param=0 flags=1
value#5 f=0 bb=1 t=0 def=4 local=-1 param=-1 flags=0
value#6 f=0 bb=2 t=4 def=6 local=-1 param=-1 flags=0
value#7 f=0 bb=2 t=5 def=7 local=-1 param=-1 flags=0
value#8 f=0 bb=2 t=6 def=8 local=-1 param=-1 flags=0
operand#0 value=-1 local=0 type=1 imm=0
operand#1 value=1 local=-1 type=0 imm=0
operand#2 value=-1 local=0 type=1 imm=0
operand#3 value=2 local=-1 type=0 imm=0
operand#4 value=2 local=-1 type=0 imm=0
operand#5 value=-1 local=1 type=3 imm=0
operand#6 value=3 local=-1 type=3 imm=0
operand#7 value=3 local=-1 type=3 imm=0
operand#8 value=5 local=-1 type=0 imm=0
operand#9 value=-1 local=2 type=4 imm=0
operand#10 value=2 local=-1 type=0 imm=0
operand#11 value=7 local=-1 type=5 imm=0
inst#0 bb=0 op=1 type=0 result=1 ops=0+1 cc=1 cap=0 addr=2
inst#1 bb=0 op=3 type=0 result=2 ops=1+1 cc=1 cap=0 addr=1
inst#2 bb=0 op=2 type=0 result=-1 ops=2+2 cc=1 cap=0 addr=2
inst#3 bb=1 op=8 type=3 result=3 ops=5+1 cc=1 cap=0 addr=2
inst#4 bb=1 op=1 type=0 result=5 ops=6+1 cc=1 cap=0 addr=2
inst#5 bb=1 op=2 type=0 result=-1 ops=7+2 cc=1 cap=0 addr=2
inst#6 bb=2 op=17 type=4 result=6 ops=9+1 cc=1 cap=0 addr=2
inst#7 bb=2 op=21 type=5 result=7 ops=10+1 cc=1 cap=0 addr=1
inst#8 bb=2 op=24 type=6 result=8 ops=11+1 cc=1 cap=0 addr=1
term#0 bb=0 kind=3 ops=4+1 succ=0+2
term#1 bb=1 kind=2 ops=0+0 succ=2+1
term#2 bb=2 kind=2 ops=0+0 succ=3+1
term#3 bb=3 kind=1 ops=0+0 succ=0+0
succ#0 ->bb1 args=4+1
succ#1 ->bb2 args=0+0
succ#2 ->bb3 args=0+0
succ#3 ->bb3 args=0+0
bb#0 f=0 params=0+0 insts=0+3 term=0 flags=0
bb#1 f=0 params=0+1 insts=3+3 term=1 flags=0
bb#2 f=0 params=0+0 insts=6+3 term=2 flags=0
bb#3 f=0 params=0+0 insts=9+0 term=3 flags=1
EOF

if ! (cd "$REPO_ROOT" && ./bin/uya build "$tmp_dir/main.uya" -o "$tmp_dir/mir-golden" \
    --no-split-c --project-root "$tmp_dir" >"$build_out" 2>"$build_err"); then
    cat "$build_out" >&2
    cat "$build_err" >&2
    exit 1
fi

if ! "$tmp_dir/mir-golden" >"$actual"; then
    cat "$actual" >&2
    exit 1
fi

if ! diff -u "$expected" "$actual"; then
    echo "错误: PortableMIR golden dump 与期望不一致" >&2
    exit 1
fi

echo "verify_portable_mir_golden: ok"
