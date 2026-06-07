#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR structure contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$MIR_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+PortableMirModule' "PortableMIR top-level module struct"
require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+MirFunction' "MirFunction struct"
require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+MirBlock' "MirBlock struct"
require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+MirValue' "MirValue struct"
require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+MirType' "MirType struct"
require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+MirLocal' "MirLocal struct"
require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+MirInst' "MirInst struct"
require_pattern "$MIR_FILE" 'export[[:space:]]+struct[[:space:]]+MirTerminator' "MirTerminator struct"
require_pattern "$MIR_FILE" 'portable_mir_module_init' "PortableMIR module initialization"
require_pattern "$PORTABLE_MIR_DOC" 'MirModule' "PortableMIR whitepaper data model"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-structs.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$MIR_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn portable_mir_struct_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn portable_mir_struct_arena() CompilerArena {
    return CompilerArena{
        buffer: null,
        size: 0usize,
        offset: 0usize,
        first_chunk: null,
        current_chunk: null,
        total_allocated: 0usize,
        peak_allocated: 0usize,
    };
}

fn portable_mir_struct_profile() MirTargetProfile {
    return MirTargetProfile{
        profile_id: 0,
        pointer_size: 0,
        endianness: 0,
        default_address_space: MIR_ADDRESS_SPACE_GENERIC,
        runtime_mode: MIR_RUNTIME_MODE_HOSTED,
        supported_address_spaces: MIR_ADDRESS_SPACE_GENERIC + MIR_ADDRESS_SPACE_HOST,
        supported_calling_conventions: 3,
        runtime_capability_mask: 3,
        feature_flags: 0,
    };
}

fn portable_mir_struct_module() PortableMirModule {
    return PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_UNINITIALIZED,
        target_profile: portable_mir_struct_profile(),
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
        functions: portable_mir_struct_vec(),
        blocks: portable_mir_struct_vec(),
        values: portable_mir_struct_vec(),
        types: portable_mir_struct_vec(),
        locals: portable_mir_struct_vec(),
        insts: portable_mir_struct_vec(),
        terminators: portable_mir_struct_vec(),
        operands: portable_mir_struct_vec(),
        block_params: portable_mir_struct_vec(),
        successors: portable_mir_struct_vec(),
        debug_locs: portable_mir_struct_vec(),
        capability_reqs: portable_mir_struct_vec(),
    };
}

fn append_minimal_portable_mir(module: &PortableMirModule) !void {
    var debug_loc: MirDebugLoc = MirDebugLoc{
        debug_loc_id: 0,
        source_span_id: 500,
        file_id: 1,
        line: 2,
        column: 3,
    };
    var type_i32: MirType = MirType{
        type_id: 0,
        kind: MIR_TYPE_KIND_I32,
        source_type_id: 77,
        size_bytes: 4usize,
        align_bytes: 4usize,
        layout_id: 707,
        tag_offset_bytes: 0usize,
        payload_offset_bytes: 0usize,
        atomic_align_bytes: 4usize,
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
    var local: MirLocal = MirLocal{
        local_id: 0,
        function_id: 0,
        type_id: 0,
        source_symbol_id: 88,
        address_space: MIR_ADDRESS_SPACE_HOST,
        alignment: 4usize,
        debug_loc_id: 0,
        flags: MIR_LOCAL_FLAG_ADDRESS_TAKEN,
    };
    var value: MirValue = MirValue{
        value_id: 0,
        function_id: 0,
        block_id: 0,
        type_id: 0,
        defining_inst_id: 0,
        local_id: 0,
        param_index: -1,
        source_expr_id: 99,
        debug_loc_id: 0,
        flags: 0,
    };
    var operand: MirOperand = MirOperand{
        operand_id: 0,
        kind: 1,
        value_id: 0,
        local_id: MIR_LOCAL_INVALID_ID,
        type_id: 0,
        capability_req_id: MIR_CAPABILITY_REQ_INVALID_ID,
        immediate_i32: 0,
        flags: 0,
    };
    var inst: MirInst = MirInst{
        inst_id: 0,
        function_id: 0,
        block_id: 0,
        op: MIR_INST_OP_LOAD,
        type_id: 0,
        result_value_id: 0,
        operand_start: 0,
        operand_count: 1,
        calling_convention: 1,
        runtime_capability_mask: 0,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        debug_loc_id: 0,
        flags: 0,
    };
    var term: MirTerminator = MirTerminator{
        terminator_id: 0,
        function_id: 0,
        block_id: 0,
        kind: MIR_TERMINATOR_KIND_RETURN,
        operand_start: 0,
        operand_count: 1,
        successor_start: 0,
        successor_count: 0,
        debug_loc_id: 0,
        flags: 0,
    };
    var block: MirBlock = MirBlock{
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
    var func: MirFunction = MirFunction{
        function_id: 0,
        lowered_function_id: 11,
        decl_id: 12,
        source_core_body_id: 0,
        symbol_id: 13,
        signature_type_id: 0,
        param_start: 0,
        param_count: 0,
        local_start: 0,
        local_count: 1,
        block_start: 0,
        block_count: 1,
        entry_block_id: 0,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 0,
        calling_convention: 1,
        runtime_capability_mask: 1,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC + MIR_ADDRESS_SPACE_HOST,
        debug_loc_id: 0,
        flags: 0,
    };

    try assert_eq_i32(semantic_vector_append(&module.debug_locs, &debug_loc as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.types, &type_i32 as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.locals, &local as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.values, &value as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.operands, &operand as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.insts, &inst as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.terminators, &term as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.blocks, &block as &const void), 0);
    try assert_eq_i32(semantic_vector_append(&module.functions, &func as &const void), 0);
    module.debug_loc_count = module.debug_locs.count;
    module.type_count = module.types.count;
    module.local_count = module.locals.count;
    module.value_count = module.values.count;
    module.operand_count = module.operands.count;
    module.inst_count = module.insts.count;
    module.terminator_count = module.terminators.count;
    module.block_count = module.blocks.count;
    module.function_count = module.functions.count;
}

test "PortableMIR top-level structures initialize and store a minimal function" {
    var arena_buf: [byte: 4096] = [];
    var arena: CompilerArena = portable_mir_struct_arena();
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);

    var module: PortableMirModule = portable_mir_struct_module();
    portable_mir_module_init(&module, &arena);
    try assert_eq_i32(module.lifecycle_state, PORTABLE_MIR_LIFECYCLE_ACTIVE);
    try assert_eq_i32(module.target_profile.default_address_space, MIR_ADDRESS_SPACE_GENERIC);
    try assert_eq_i32(module.target_profile.supported_calling_conventions, 3);
    try assert_eq_i32(module.target_profile.runtime_capability_mask, 3);
    try expect(module.functions.item_size == @size_of(MirFunction));
    try expect(module.blocks.item_size == @size_of(MirBlock));
    try expect(module.values.item_size == @size_of(MirValue));
    try expect(module.types.item_size == @size_of(MirType));
    try expect(module.locals.item_size == @size_of(MirLocal));
    try expect(module.insts.item_size == @size_of(MirInst));
    try expect(module.terminators.item_size == @size_of(MirTerminator));

    try append_minimal_portable_mir(&module);
    try expect(module.function_count == 1usize);
    try expect(module.block_count == 1usize);
    try expect(module.value_count == 1usize);
    try expect(module.type_count == 1usize);
    try expect(module.local_count == 1usize);
    try expect(module.inst_count == 1usize);
    try expect(module.terminator_count == 1usize);

    const func: &MirFunction = semantic_vector_item_ptr(&module.functions, 0usize) as &MirFunction;
    const type_item: &MirType = semantic_vector_item_ptr(&module.types, 0usize) as &MirType;
    const block: &MirBlock = semantic_vector_item_ptr(&module.blocks, 0usize) as &MirBlock;
    const inst: &MirInst = semantic_vector_item_ptr(&module.insts, 0usize) as &MirInst;
    const term: &MirTerminator = semantic_vector_item_ptr(&module.terminators, 0usize) as &MirTerminator;
    try expect(func != null);
    try expect(type_item != null);
    try expect(block != null);
    try expect(inst != null);
    try expect(term != null);
    try assert_eq_i32(type_item.layout_id, 707);
    try assert_eq_i32(type_item.abi_class, 1);
    try assert_eq_i32(func.calling_convention, 1);
    try assert_eq_i32(func.runtime_capability_mask, 1);
    try assert_eq_i32(inst.address_space, MIR_ADDRESS_SPACE_GENERIC);
    try assert_eq_i32(func.entry_block_id, block.block_id);
    try assert_eq_i32(block.terminator_id, term.terminator_id);
    try assert_eq_i32(inst.result_value_id, 0);
    try assert_eq_i32(term.kind, MIR_TERMINATOR_KIND_RETURN);

    portable_mir_module_release(&module);
    try assert_eq_i32(module.lifecycle_state, PORTABLE_MIR_LIFECYCLE_RELEASED);
    try expect(module.function_count == 0usize);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --project-root "$tmp_dir")

echo "OK: PortableMIR structure contract verified"
