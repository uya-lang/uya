#!/usr/bin/env bash

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
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR parallel determinism missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$IDS_FILE" "$ARENA_FILE" "$TABLE_FILE" "$MIR_FILE" "$MIR_CONTRACT_FILE" \
    "$MIR_VERIFIER_FILE" "$PORTABLE_MIR_DOC" "$ARCH_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_PARALLEL_OUTPUT_MIR_FUNCTIONS \
    MIR_PARALLEL_OUTPUT_DIAGNOSTICS \
    MIR_PARALLEL_OUTPUT_DUMP \
    MIR_PARALLEL_OUTPUT_BACKEND_FRAGMENTS \
    MIR_PARALLEL_MERGE_STABLE_FUNCTION_ORDER \
    portable_mir_parallel_worker_input_is_valid \
    portable_mir_parallel_merge_contract_is_deterministic \
    portable_mir_verify_module; do
    if [[ "$symbol" == portable_mir_verify_module ]]; then
        require_pattern "$MIR_VERIFIER_FILE" "$symbol" "verifier symbol $symbol"
    else
        require_pattern "$MIR_CONTRACT_FILE" "$symbol" "parallel symbol $symbol"
    fi
done

require_pattern "$PORTABLE_MIR_DOC" 'stable function order 合并 `MirFunction`、diagnostics、dump 和 backend fragments' \
    "whitepaper stable merge output"
require_pattern "$PORTABLE_MIR_DOC" 'MirFunctionId`、`MirBlockId`、`MirValueId`、dump 文本、diagnostic 顺序或 object symbol order' \
    "whitepaper deterministic IDs and symbol order"
require_pattern "$ARCH_DOC" '并行开关不得改变 ID、dump、' "architecture deterministic switch rule"
require_pattern "$ARCH_DOC" 'symbol order' "architecture symbol order rule"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-parallel-determinism.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat "$IDS_FILE" >"$tmp_dir/main.uya"
cat >>"$tmp_dir/main.uya" <<'EOF'
export type CoreBodyId = i32;
export type CoreStmtId = i32;
export type CoreExprId = i32;
export type CorePlaceId = i32;
export type CoreCleanupEdgeId = i32;

export const CORE_BODY_INVALID_ID: CoreBodyId = -1;
export const CORE_STMT_KIND_RETURN: i32 = 10;
export const CORE_STMT_KIND_ASM: i32 = 11;
export const CORE_STMT_KIND_DEFER: i32 = 12;
export const CORE_STMT_KIND_ERRDEFER: i32 = 13;
export const CORE_STMT_KIND_DROP: i32 = 14;
export const CORE_STMT_KIND_ERROR_PROPAGATION: i32 = 15;
export const CORE_STMT_KIND_EXPR: i32 = 19;
export const CORE_EXPR_KIND_CALL: i32 = 11;
export const CORE_EXPR_KIND_INDEX: i32 = 12;
export const CORE_EXPR_KIND_SLICE: i32 = 13;
export const CORE_EXPR_KIND_ATOMIC: i32 = 14;
export const CORE_EXPR_KIND_VECTOR: i32 = 15;
export const CORE_EXPR_KIND_MASK: i32 = 16;
export const CORE_EXPR_KIND_INT_LITERAL: i32 = 17;
export const CORE_EXPR_KIND_LOCAL_REF: i32 = 18;
export const CORE_EXPR_KIND_I32_ADD: i32 = 20;
export const CORE_PLACE_KIND_FIELD: i32 = 4;
export const CORE_PLACE_KIND_INDEX: i32 = 5;
export const CORE_PLACE_KIND_SLICE: i32 = 6;
export const CORE_CLEANUP_EDGE_KIND_RETURN: i32 = 2;

struct LoweredProgram {
    marker: i32,
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
    if input.body_id < 0 {
        return 0;
    }
    return 1;
}
EOF

cat "$ARENA_FILE" "$TABLE_FILE" "$MIR_FILE" "$MIR_VERIFIER_FILE" "$MIR_CONTRACT_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
struct MirParallelFragment {
    stable_function_id: i32,
    worker_id: i32,
    symbol_id: i32,
    invalid_capability: i32,
}

fn require_i32(actual: i32, expected: i32) i32 {
    if actual != expected {
        fprintf(libc.stderr, "assert failed: actual=%d expected=%d\n" as *byte, actual, expected);
        return -1;
    }
    return 0;
}

fn mir_parallel_enabled() i32 {
    const value: *byte = getenv("UYA_MIR_PARALLEL_FIXTURE" as *byte);
    if value == null {
        return 0;
    }
    if value[0] == 112 as byte {
        return 1;
    }
    return 0;
}

fn mir_parallel_invalid_enabled() i32 {
    const value: *byte = getenv("UYA_MIR_PARALLEL_INVALID" as *byte);
    if value == null {
        return 0;
    }
    if value[0] == 49 as byte && value[1] == 0 as byte {
        return 1;
    }
    return 0;
}

fn mir_parallel_type() MirType {
    return MirType{
        type_id: 0,
        kind: MIR_TYPE_KIND_I32,
        source_type_id: 0,
        size_bytes: 4usize,
        align_bytes: 4usize,
        layout_id: 1,
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
}

fn mir_parallel_function(fragment: &MirParallelFragment) MirFunction {
    var calling_convention: i32 = MIR_CALL_CONV_UYA;
    if fragment.invalid_capability != 0 {
        calling_convention = MIR_CALL_CONV_TARGET_INTRINSIC;
    }
    return MirFunction{
        function_id: fragment.stable_function_id,
        lowered_function_id: 100 + fragment.stable_function_id,
        decl_id: 200 + fragment.stable_function_id,
        source_core_body_id: 300 + fragment.stable_function_id,
        symbol_id: fragment.symbol_id,
        signature_type_id: 0,
        param_start: 0,
        param_count: 0,
        local_start: 0,
        local_count: 0,
        block_start: fragment.stable_function_id,
        block_count: 1,
        entry_block_id: fragment.stable_function_id,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 0,
        calling_convention: calling_convention,
        runtime_capability_mask: MIR_RUNTIME_CAP_HOSTED_LIBC,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC,
        body_kind: MIR_FUNCTION_BODY_KIND_NORMAL,
        naked_asm_inst_start: MIR_INST_INVALID_ID,
        naked_asm_inst_count: 0,
        naked_forbidden_lowering_mask: 0,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn mir_parallel_block(fragment: &MirParallelFragment) MirBlock {
    return MirBlock{
        block_id: fragment.stable_function_id,
        function_id: fragment.stable_function_id,
        param_start: 0,
        param_count: 0,
        inst_start: 0,
        inst_count: 0,
        terminator_id: fragment.stable_function_id,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn mir_parallel_terminator(fragment: &MirParallelFragment) MirTerminator {
    return MirTerminator{
        terminator_id: fragment.stable_function_id,
        function_id: fragment.stable_function_id,
        block_id: fragment.stable_function_id,
        kind: MIR_TERMINATOR_KIND_RETURN,
        operand_start: 0,
        operand_count: 0,
        successor_start: 0,
        successor_count: 0,
        debug_loc_id: MIR_DEBUG_LOC_INVALID_ID,
        flags: 0,
    };
}

fn mir_parallel_fragment(stable_function_id: i32, worker_id: i32, invalid: i32) MirParallelFragment {
    var symbol_id: i32 = 110;
    if stable_function_id == 1 {
        symbol_id = 120;
    }
    return MirParallelFragment{
        stable_function_id: stable_function_id,
        worker_id: worker_id,
        symbol_id: symbol_id,
        invalid_capability: invalid,
    };
}

fn append_mir_parallel_fragment(module: &PortableMirModule, fragment: &MirParallelFragment) i32 {
    var func: MirFunction = mir_parallel_function(fragment);
    var block: MirBlock = mir_parallel_block(fragment);
    var term: MirTerminator = mir_parallel_terminator(fragment);
    if portable_mir_append_function(module, &func) != 0 { return -1; }
    if portable_mir_append_block(module, &block) != 0 { return -1; }
    if portable_mir_append_terminator(module, &term) != 0 { return -1; }
    return 0;
}

fn assert_mir_parallel_contract(parallel: i32) i32 {
    var lowered: LoweredProgram = LoweredProgram{ marker: 7 };
    var input0: PortableMirParallelWorkerInput = PortableMirParallelWorkerInput{
        core_input: PortableMirCoreInput{
            program: &lowered,
            body_id: 0,
            target_profile_id: 9,
            flags: 0,
        },
        stable_function_index: 0,
        worker_id: 0,
        flags: 0,
    };
    var input1: PortableMirParallelWorkerInput = input0;
    input1.stable_function_index = 1;
    input1.worker_id = 1;
    if portable_mir_parallel_worker_input_is_valid(&input0) != 1 { return -1; }
    if portable_mir_parallel_worker_input_is_valid(&input1) != 1 { return -1; }
    input1.stable_function_index = -1;
    if portable_mir_parallel_worker_input_is_valid(&input1) != 0 { return -1; }

    var contract: PortableMirParallelMergeContract = PortableMirParallelMergeContract{
        function_count: 0,
        worker_count: 0,
        output_mask: 0,
        merge_order_mask: 0,
        forbidden_mask: 0,
        flags: 0,
    };
    if portable_mir_parallel_merge_contract_init(&contract, 2, 2) != 0 { return -1; }
    if portable_mir_parallel_merge_contract_is_deterministic(&contract) != 1 { return -1; }
    if portable_mir_lowering_mask_has(contract.output_mask, MIR_PARALLEL_OUTPUT_MIR_FUNCTIONS) != 1 { return -1; }
    if portable_mir_lowering_mask_has(contract.output_mask, MIR_PARALLEL_OUTPUT_DIAGNOSTICS) != 1 { return -1; }
    if portable_mir_lowering_mask_has(contract.output_mask, MIR_PARALLEL_OUTPUT_DUMP) != 1 { return -1; }
    if portable_mir_lowering_mask_has(contract.output_mask, MIR_PARALLEL_OUTPUT_BACKEND_FRAGMENTS) != 1 { return -1; }
    if portable_mir_lowering_mask_has(contract.merge_order_mask, MIR_PARALLEL_MERGE_STABLE_FUNCTION_ORDER) != 1 {
        return -1;
    }
    if parallel != 0 && contract.worker_count != 2 {
        return -1;
    }
    return 0;
}

fn append_mir_parallel_fixture(module: &PortableMirModule, parallel: i32, invalid: i32) i32 {
    var typ: MirType = mir_parallel_type();
    if portable_mir_append_type(module, &typ) != 0 { return -1; }

    if parallel != 0 {
        var completed_first: MirParallelFragment = mir_parallel_fragment(1, 1, invalid);
        var completed_second: MirParallelFragment = mir_parallel_fragment(0, 0, 0);
        if completed_first.stable_function_id != 1 || completed_second.stable_function_id != 0 {
            return -1;
        }
        var stable0: MirParallelFragment = mir_parallel_fragment(0, 0, 0);
        var stable1: MirParallelFragment = mir_parallel_fragment(1, 1, invalid);
        if append_mir_parallel_fragment(module, &stable0) != 0 { return -1; }
        if append_mir_parallel_fragment(module, &stable1) != 0 { return -1; }
        return 0;
    }

    var stable0: MirParallelFragment = mir_parallel_fragment(0, 0, 0);
    var stable1: MirParallelFragment = mir_parallel_fragment(1, 1, invalid);
    if append_mir_parallel_fragment(module, &stable0) != 0 { return -1; }
    if append_mir_parallel_fragment(module, &stable1) != 0 { return -1; }
    return 0;
}

fn dump_mir_parallel_functions(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.functions.count {
        const func: &MirFunction = semantic_vector_item_ptr(&module.functions, i) as &MirFunction;
        printf("fn#%d lowered=%d decl=%d core=%d symbol=%d blocks=%d+%d entry=bb%d cc=%d\n",
            func.function_id, func.lowered_function_id, func.decl_id, func.source_core_body_id,
            func.symbol_id, func.block_start, func.block_count, func.entry_block_id,
            func.calling_convention);
        i = i + 1usize;
    }
}

fn dump_mir_parallel_blocks(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.blocks.count {
        const block: &MirBlock = semantic_vector_item_ptr(&module.blocks, i) as &MirBlock;
        printf("bb#%d fn=%d insts=%d+%d term=%d flags=%d\n",
            block.block_id, block.function_id, block.inst_start, block.inst_count,
            block.terminator_id, block.flags);
        i = i + 1usize;
    }
}

fn dump_mir_parallel_terms(module: &PortableMirModule) void {
    var i: usize = 0usize;
    while i < module.terminators.count {
        const term: &MirTerminator = semantic_vector_item_ptr(&module.terminators, i) as &MirTerminator;
        printf("term#%d fn=%d bb=%d kind=%d\n",
            term.terminator_id, term.function_id, term.block_id, term.kind);
        i = i + 1usize;
    }
}

fn dump_mir_parallel_fragments(module: &PortableMirModule) void {
    var i: usize = 0usize;
    printf("symbol_order=");
    while i < module.functions.count {
        const func: &MirFunction = semantic_vector_item_ptr(&module.functions, i) as &MirFunction;
        if i != 0usize {
            printf(",");
        }
        printf("%d", func.symbol_id);
        i = i + 1usize;
    }
    printf("\n");

    i = 0usize;
    while i < module.functions.count {
        const func: &MirFunction = semantic_vector_item_ptr(&module.functions, i) as &MirFunction;
        printf("backend_fragment#%d symbol=%d body=%d\n",
            func.function_id, func.symbol_id, func.source_core_body_id);
        i = i + 1usize;
    }
}

fn dump_mir_parallel_module(module: &PortableMirModule, result: &MirVerifierResult) void {
    printf("diagnostic code=%d fn=%d bb=%d inst=%d value=%d type=%d cap=%d\n",
        result.error_code, result.function_id, result.block_id, result.inst_id,
        result.value_id, result.type_id, result.capability_req_id);
    printf("mir_module profile=%d ptr=%d funcs=%d blocks=%d terms=%d types=%d values=%d locals=%d insts=%d\n",
        module.target_profile.profile_id, module.target_profile.pointer_size,
        module.function_count as i32, module.block_count as i32, module.terminator_count as i32,
        module.type_count as i32, module.value_count as i32, module.local_count as i32,
        module.inst_count as i32);
    dump_mir_parallel_functions(module);
    dump_mir_parallel_blocks(module);
    dump_mir_parallel_terms(module);
    dump_mir_parallel_fragments(module);
}

export fn main() i32 {
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
            supported_address_spaces: MIR_ADDRESS_SPACE_GENERIC,
            supported_calling_conventions: MIR_CALL_CONV_UYA + MIR_CALL_CONV_C,
            runtime_capability_mask: MIR_RUNTIME_CAP_HOSTED_LIBC + MIR_RUNTIME_CAP_C_EXTERN,
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
        field_layout_count: 0usize,
        function_param_type_count: 0usize,
        async_frame_meta_count: 0usize,
        global_count: 0usize,
        const_count: 0usize,
        link_input_count: 0usize,
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
        field_layouts: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        function_param_types: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        async_frame_metas: SemanticVector{ data: null, item_size: @size_of(MirAsyncFrameMeta), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        globals: SemanticVector{ data: null, item_size: @size_of(MirGlobal), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        consts: SemanticVector{ data: null, item_size: @size_of(MirConst), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        link_inputs: SemanticVector{ data: null, item_size: @size_of(MirLinkInput), count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
    portable_mir_module_init(&module, &arena);
    module.target_profile.profile_id = 9;
    module.target_profile.pointer_size = 8;
    module.target_profile.supported_address_spaces = MIR_ADDRESS_SPACE_GENERIC;
    module.target_profile.supported_calling_conventions = MIR_CALL_CONV_UYA + MIR_CALL_CONV_C;
    module.target_profile.runtime_capability_mask = MIR_RUNTIME_CAP_HOSTED_LIBC + MIR_RUNTIME_CAP_C_EXTERN;

    const parallel: i32 = mir_parallel_enabled();
    const invalid: i32 = mir_parallel_invalid_enabled();
    if assert_mir_parallel_contract(parallel) != 0 {
        return 1;
    }
    if append_mir_parallel_fixture(&module, parallel, invalid) != 0 {
        fprintf(libc.stderr, "append failed\n" as *byte);
        return 1;
    }

    var result: MirVerifierResult = MirVerifierResult{
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
    const verify_code: i32 = portable_mir_verify_module(&module, &result);
    if invalid == 0 {
        if require_i32(verify_code, 0) != 0 { return 1; }
        if require_i32(result.error_code, MIR_VERIFY_OK) != 0 { return 1; }
    } else {
        if require_i32(verify_code, -1) != 0 { return 1; }
        if require_i32(result.error_code, MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY) != 0 { return 1; }
        if require_i32(result.function_id, 1) != 0 { return 1; }
    }

    dump_mir_parallel_module(&module, &result);
    portable_mir_module_release(&module);
    compiler_arena_free_all(&arena);
    return 0;
}
EOF

build_out="$tmp_dir/build.out"
build_err="$tmp_dir/build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$tmp_dir/main.uya" -o "$tmp_dir/mir-parallel-determinism" \
    --no-split-c --project-root "$tmp_dir" >"$build_out" 2>"$build_err"); then
    cat "$build_out" >&2
    cat "$build_err" >&2
    exit 1
fi

run_fixture() {
    local label="$1"
    local mode="$2"
    local invalid="$3"
    local output="$4"
    if [[ "$invalid" == "1" ]]; then
        if ! UYA_MIR_PARALLEL_FIXTURE="$mode" UYA_MIR_PARALLEL_INVALID=1 \
            "$tmp_dir/mir-parallel-determinism" >"$output"; then
            echo "error: $label failed" >&2
            cat "$output" >&2
            exit 1
        fi
        return
    fi
    if ! UYA_MIR_PARALLEL_FIXTURE="$mode" "$tmp_dir/mir-parallel-determinism" >"$output"; then
        echo "error: $label failed" >&2
        cat "$output" >&2
        exit 1
    fi
}

serial_out="$tmp_dir/serial.out"
parallel_out="$tmp_dir/parallel.out"
invalid_serial_out="$tmp_dir/invalid-serial.out"
invalid_parallel_out="$tmp_dir/invalid-parallel.out"

run_fixture "serial MIR fixture" "serial" "0" "$serial_out"
run_fixture "parallel MIR fixture" "parallel" "0" "$parallel_out"

if ! grep -Fq "diagnostic code=0 fn=-1 bb=-1 inst=-1 value=-1 type=-1 cap=-1" "$serial_out"; then
    echo "error: serial MIR fixture missing OK diagnostic" >&2
    exit 1
fi
if ! grep -Fq "fn#0 lowered=100 decl=200 core=300 symbol=110 blocks=0+1 entry=bb0 cc=1" "$serial_out"; then
    echo "error: serial MIR fixture missing first stable function" >&2
    exit 1
fi
if ! grep -Fq "fn#1 lowered=101 decl=201 core=301 symbol=120 blocks=1+1 entry=bb1 cc=1" "$serial_out"; then
    echo "error: serial MIR fixture missing second stable function" >&2
    exit 1
fi
if ! grep -Fq "symbol_order=110,120" "$serial_out"; then
    echo "error: serial MIR fixture missing stable symbol order" >&2
    exit 1
fi
if ! diff -u "$serial_out" "$parallel_out"; then
    echo "error: PortableMIR dump changed between serial and simulated parallel construction" >&2
    exit 1
fi

run_fixture "serial invalid MIR fixture" "serial" "1" "$invalid_serial_out"
run_fixture "parallel invalid MIR fixture" "parallel" "1" "$invalid_parallel_out"

if ! grep -Fq "diagnostic code=12 fn=1 bb=-1 inst=-1 value=-1 type=0 cap=-1" "$invalid_serial_out"; then
    echo "error: invalid MIR fixture missing stable unsupported-target diagnostic" >&2
    exit 1
fi
if ! grep -Fq "fn#1 lowered=101 decl=201 core=301 symbol=120 blocks=1+1 entry=bb1 cc=16" "$invalid_serial_out"; then
    echo "error: invalid MIR fixture missing stable bad function" >&2
    exit 1
fi
if ! diff -u "$invalid_serial_out" "$invalid_parallel_out"; then
    echo "error: PortableMIR diagnostic changed between serial and simulated parallel construction" >&2
    exit 1
fi

echo "OK: PortableMIR parallel determinism verified"
