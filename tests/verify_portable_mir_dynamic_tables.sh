#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR dynamic table contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$MIR_FILE" 'functions:[[:space:]]*SemanticVector' "dynamic function table"
require_pattern "$MIR_FILE" 'blocks:[[:space:]]*SemanticVector' "dynamic block table"
require_pattern "$MIR_FILE" 'values:[[:space:]]*SemanticVector' "dynamic value table"
require_pattern "$MIR_FILE" 'types:[[:space:]]*SemanticVector' "dynamic type table"
require_pattern "$MIR_FILE" 'locals:[[:space:]]*SemanticVector' "dynamic local table"
require_pattern "$MIR_FILE" 'insts:[[:space:]]*SemanticVector' "dynamic instruction table"
require_pattern "$MIR_FILE" 'terminators:[[:space:]]*SemanticVector' "dynamic terminator table"
require_pattern "$MIR_FILE" 'portable_mir_append_function' "function append API"
require_pattern "$MIR_FILE" 'portable_mir_append_inst' "instruction append API"

if grep -En '(^|[^A-Z])(PORTABLE_MIR_MAX|MIR_MAX)_' "$MIR_FILE"; then
    echo "error: PortableMIR introduced a fixed semantic MIR_MAX capacity" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-dynamic.XXXXXX)"
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

export fn compiler_arena_init(arena: &CompilerArena, buffer: &byte, size: usize) void {
    if arena == null || buffer == null || size == 0usize {
        return;
    }
    arena.marker = 1;
}

export fn compiler_arena_free_all(arena: &CompilerArena) void {
    if arena == null {
        return;
    }
    arena.marker = 0;
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
    if vec.capacity == 0usize {
        vec.capacity = 8usize;
        vec.realloc_count = vec.realloc_count + 1;
    }
    if vec.count >= vec.capacity {
        vec.capacity = vec.capacity * 2usize;
        vec.realloc_count = vec.realloc_count + 1;
    }
    vec.count = vec.count + 1usize;
    vec.bytes = vec.count * vec.item_size;
    return 0;
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

cat "$MIR_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn portable_mir_dynamic_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn portable_mir_dynamic_arena() CompilerArena {
    return CompilerArena{
        marker: 0,
    };
}

fn portable_mir_dynamic_profile() MirTargetProfile {
    return MirTargetProfile{
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
    };
}

fn portable_mir_dynamic_module() PortableMirModule {
    return PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_UNINITIALIZED,
        target_profile: portable_mir_dynamic_profile(),
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
        functions: portable_mir_dynamic_vec(),
        blocks: portable_mir_dynamic_vec(),
        values: portable_mir_dynamic_vec(),
        types: portable_mir_dynamic_vec(),
        locals: portable_mir_dynamic_vec(),
        insts: portable_mir_dynamic_vec(),
        terminators: portable_mir_dynamic_vec(),
        operands: portable_mir_dynamic_vec(),
        block_params: portable_mir_dynamic_vec(),
        successors: portable_mir_dynamic_vec(),
        debug_locs: portable_mir_dynamic_vec(),
        capability_reqs: portable_mir_dynamic_vec(),
    };
}

fn append_portable_mir_dynamic_row(module: &PortableMirModule, id: i32) !void {
    var debug_loc: MirDebugLoc = MirDebugLoc{
        debug_loc_id: id,
        source_span_id: 500 + id,
        file_id: id,
        line: id,
        column: id,
    };
    var type_item: MirType = MirType{
        type_id: id,
        kind: MIR_TYPE_KIND_I32,
        source_type_id: 700 + id,
        size_bytes: 4usize,
        align_bytes: 4usize,
        layout_id: 1700 + id,
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
        local_id: id,
        function_id: id,
        type_id: id,
        source_symbol_id: 800 + id,
        address_space: MIR_ADDRESS_SPACE_HOST,
        alignment: 4usize,
        debug_loc_id: id,
        flags: 0,
    };
    var value: MirValue = MirValue{
        value_id: id,
        function_id: id,
        block_id: id,
        type_id: id,
        defining_inst_id: id,
        local_id: id,
        param_index: -1,
        source_expr_id: 900 + id,
        debug_loc_id: id,
        flags: 0,
    };
    var operand: MirOperand = MirOperand{
        operand_id: id,
        kind: 1,
        value_id: id,
        local_id: id,
        type_id: id,
        capability_req_id: id,
        immediate_i32: id,
        flags: 0,
    };
    var block_param: MirBlockParam = MirBlockParam{
        param_id: id,
        block_id: id,
        value_id: id,
        type_id: id,
        debug_loc_id: id,
        flags: 0,
    };
    var successor: MirSuccessor = MirSuccessor{
        successor_id: id,
        block_id: id,
        arg_start: id,
        arg_count: 1,
        flags: 0,
    };
    var cap: MirCapabilityReq = MirCapabilityReq{
        capability_req_id: id,
        capability_id: 1000 + id,
        function_id: id,
        inst_id: id,
        debug_loc_id: id,
        flags: 0,
    };
    var inst: MirInst = MirInst{
        inst_id: id,
        function_id: id,
        block_id: id,
        op: MIR_INST_OP_LOAD,
        type_id: id,
        result_value_id: id,
        operand_start: id,
        operand_count: 1,
        calling_convention: 1,
        runtime_capability_mask: 0,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        debug_loc_id: id,
        flags: 0,
    };
    var term: MirTerminator = MirTerminator{
        terminator_id: id,
        function_id: id,
        block_id: id,
        kind: MIR_TERMINATOR_KIND_RETURN,
        operand_start: id,
        operand_count: 1,
        successor_start: id,
        successor_count: 0,
        debug_loc_id: id,
        flags: 0,
    };
    var block: MirBlock = MirBlock{
        block_id: id,
        function_id: id,
        param_start: id,
        param_count: 1,
        inst_start: id,
        inst_count: 1,
        terminator_id: id,
        debug_loc_id: id,
        flags: 0,
    };
    var func: MirFunction = MirFunction{
        function_id: id,
        lowered_function_id: 2000 + id,
        decl_id: 3000 + id,
        source_core_body_id: id,
        symbol_id: 4000 + id,
        signature_type_id: id,
        param_start: id,
        param_count: 1,
        local_start: id,
        local_count: 1,
        block_start: id,
        block_count: 1,
        entry_block_id: id,
        cleanup_model: 0,
        capability_req_start: id,
        capability_req_count: 1,
        calling_convention: 1,
        runtime_capability_mask: 1,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC + MIR_ADDRESS_SPACE_HOST,
        body_kind: MIR_FUNCTION_BODY_KIND_NORMAL,
        naked_asm_inst_start: -1,
        naked_asm_inst_count: 0,
        naked_forbidden_lowering_mask: 0,
        debug_loc_id: id,
        flags: 0,
    };

    try assert_eq_i32(portable_mir_append_debug_loc(module, &debug_loc), 0);
    try assert_eq_i32(portable_mir_append_type(module, &type_item), 0);
    try assert_eq_i32(portable_mir_append_local(module, &local), 0);
    try assert_eq_i32(portable_mir_append_value(module, &value), 0);
    try assert_eq_i32(portable_mir_append_operand(module, &operand), 0);
    try assert_eq_i32(portable_mir_append_block_param(module, &block_param), 0);
    try assert_eq_i32(portable_mir_append_successor(module, &successor), 0);
    try assert_eq_i32(portable_mir_append_capability_req(module, &cap), 0);
    try assert_eq_i32(portable_mir_append_inst(module, &inst), 0);
    try assert_eq_i32(portable_mir_append_terminator(module, &term), 0);
    try assert_eq_i32(portable_mir_append_block(module, &block), 0);
    try assert_eq_i32(portable_mir_append_function(module, &func), 0);
}

fn expect_mir_table_grew(vec: &SemanticVector, expected: usize) !void {
    try expect(vec.count == expected);
    try expect(vec.capacity >= expected);
    try expect(vec.realloc_count > 0);
}

test "PortableMIR tables grow dynamically without semantic caps" {
    const expected: usize = 72usize;
    var arena_buf: [byte: 4096] = [];
    var arena: CompilerArena = portable_mir_dynamic_arena();
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);
    var module: PortableMirModule = portable_mir_dynamic_module();
    portable_mir_module_init(&module, &arena);

    var i: i32 = 0;
    while i < expected as i32 {
        try append_portable_mir_dynamic_row(&module, i);
        i = i + 1;
    }

    try expect(module.function_count == expected);
    try expect(module.block_count == expected);
    try expect(module.value_count == expected);
    try expect(module.type_count == expected);
    try expect(module.local_count == expected);
    try expect(module.inst_count == expected);
    try expect(module.terminator_count == expected);
    try expect(module.operand_count == expected);
    try expect(module.block_param_count == expected);
    try expect(module.successor_count == expected);
    try expect(module.debug_loc_count == expected);
    try expect(module.capability_req_count == expected);
    try expect_mir_table_grew(&module.functions, expected);
    try expect_mir_table_grew(&module.blocks, expected);
    try expect_mir_table_grew(&module.values, expected);
    try expect_mir_table_grew(&module.types, expected);
    try expect_mir_table_grew(&module.locals, expected);
    try expect_mir_table_grew(&module.insts, expected);
    try expect_mir_table_grew(&module.terminators, expected);

    portable_mir_module_release(&module);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --project-root "$tmp_dir")

echo "OK: PortableMIR dynamic table contract verified"
