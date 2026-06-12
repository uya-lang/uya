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
        echo "error: PortableMIR naked function contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_VERIFIER_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for constant in \
    MIR_FUNCTION_FLAG_NAKED \
    MIR_FUNCTION_BODY_KIND_ASM_ONLY_NAKED \
    MIR_NAKED_FORBID_PROLOGUE_EPILOGUE \
    MIR_NAKED_FORBID_STACK_SLOT \
    MIR_NAKED_FORBID_CLEANUP \
    MIR_NAKED_FORBID_DROP \
    MIR_NAKED_FORBID_ASYNC \
    MIR_NAKED_FORBID_IMPLICIT_RETURN; do
    require_pattern "$MIR_FILE" "export const ${constant}" "constant $constant"
done

require_pattern "$MIR_FILE" 'body_kind:[[:space:]]*i32' "MirFunction body kind"
require_pattern "$MIR_FILE" 'naked_asm_inst_start:[[:space:]]*i32' "naked asm start"
require_pattern "$MIR_FILE" 'naked_asm_inst_count:[[:space:]]*i32' "naked asm count"
require_pattern "$MIR_FILE" 'naked_forbidden_lowering_mask:[[:space:]]*i32' "forbidden lowering mask"
require_pattern "$MIR_FILE" 'portable_mir_naked_forbidden_lowering_mask' "naked forbidden lowering helper"
require_pattern "$MIR_FILE" 'portable_mir_function_has_naked_flag' "naked flag helper"
require_pattern "$MIR_FILE" 'portable_mir_function_rejects_naked_lowering' "naked lowering rejection helper"
require_pattern "$MIR_FILE" 'portable_mir_function_has_asm_only_naked_body' "asm-only naked body helper"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_VERIFY_ERR_INVALID_NAKED_BODY' "naked verifier diagnostic"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY' "unsupported target verifier diagnostic"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_module' "MIR verifier entry"
require_pattern "$PORTABLE_MIR_DOC" 'MirFunction\.flags\.naked' "documented naked flag"
require_pattern "$PORTABLE_MIR_DOC" 'body_kind = asm_only_naked' "documented asm-only naked body kind"
require_pattern "$PORTABLE_MIR_DOC" 'naked_forbidden_lowering_mask' "documented forbidden lowering mask"
require_pattern "$PORTABLE_MIR_DOC" 'prologue/epilogue' "documented prologue/epilogue ban"
require_pattern "$PORTABLE_MIR_DOC" 'stack slot' "documented stack slot ban"
require_pattern "$PORTABLE_MIR_DOC" 'cleanup' "documented cleanup ban"
require_pattern "$PORTABLE_MIR_DOC" 'drop' "documented drop ban"
require_pattern "$PORTABLE_MIR_DOC" 'async' "documented async ban"
require_pattern "$PORTABLE_MIR_DOC" 'implicit return' "documented implicit return ban"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-naked.XXXXXX)"
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
export const MIR_CALL_CONV_C: i32 = 2;
export const MIR_RUNTIME_CAP_HOSTED_LIBC: i32 = 1;
export const MIR_RUNTIME_CAP_C_EXTERN: i32 = 2;
export const MIR_RUNTIME_CAP_FREESTANDING: i32 = 4;
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

export fn semantic_vector_free(vec: &SemanticVector) void {
    if vec == null {
        return;
    }
    vec.data = null;
    vec.count = 0usize;
    vec.capacity = 0usize;
    vec.bytes = 0usize;
}

export fn semantic_vector_release(vec: &SemanticVector) void {
    semantic_vector_free(vec);
}
EOF

cat "$MIR_FILE" "$MIR_VERIFIER_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn naked_vec(data: &byte, item_size: usize, count: usize) SemanticVector {
    return SemanticVector{
        data: data,
        item_size: item_size,
        count: count,
        capacity: count,
        bytes: item_size * count,
        realloc_count: 0,
    };
}

fn naked_empty_vec(item_size: usize) SemanticVector {
    return naked_vec(null, item_size, 0usize);
}

fn portable_mir_naked_test_function(mode: i32) MirFunction {
    const forbidden: i32 = portable_mir_naked_forbidden_lowering_mask();
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
        naked_forbidden_lowering_mask: forbidden,
        debug_loc_id: 0,
        flags: MIR_FUNCTION_FLAG_NAKED,
    };
    if mode == 1 {
        func.flags = 0;
        func.body_kind = MIR_FUNCTION_BODY_KIND_NORMAL;
        func.naked_forbidden_lowering_mask = 0;
    }
    if mode == 2 {
        func.body_kind = MIR_FUNCTION_BODY_KIND_NORMAL;
    }
    if mode == 3 {
        func.local_count = 1;
    }
    if mode == 4 {
        func.block_count = 1;
        func.entry_block_id = 0;
    }
    if mode == 5 {
        func.cleanup_model = 1;
    }
    if mode == 6 {
        func.naked_forbidden_lowering_mask = MIR_NAKED_FORBID_PROLOGUE_EPILOGUE;
    }
    if mode == 7 {
        func.naked_asm_inst_count = 0;
    }
    return func;
}

fn portable_mir_naked_test_type() MirType {
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

fn portable_mir_naked_test_local() MirLocal {
    return MirLocal{
        local_id: 0,
        function_id: 0,
        type_id: 0,
        source_symbol_id: 1,
        address_space: MIR_ADDRESS_SPACE_GENERIC,
        alignment: 4usize,
        debug_loc_id: 0,
        flags: 0,
    };
}

fn portable_mir_naked_verify_result(mode: i32) i32 {
    var functions: [MirFunction: 1] = [];
    var types: [MirType: 1] = [];
    var locals: [MirLocal: 1] = [];
    functions[0] = portable_mir_naked_test_function(0);
    types[0] = portable_mir_naked_test_type();
    locals[0] = portable_mir_naked_test_local();

    var local_count: usize = 0usize;
    if mode == 1 {
        functions[0].calling_convention = 16;
    }
    if mode == 2 {
        functions[0].local_count = 1;
        local_count = 1usize;
    }
    if mode == 3 {
        functions[0].cleanup_model = 1;
    }
    if mode == 4 {
        functions[0].entry_block_id = 0;
    }
    if mode == 5 {
        functions[0].body_kind = MIR_FUNCTION_BODY_KIND_NORMAL;
    }
    if mode == 6 {
        functions[0].naked_forbidden_lowering_mask = MIR_NAKED_FORBID_PROLOGUE_EPILOGUE;
    }

    var module: PortableMirModule = PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_ACTIVE,
        target_profile: MirTargetProfile{
            profile_id: 0,
            pointer_size: 8,
            endianness: 0,
            default_address_space: MIR_ADDRESS_SPACE_GENERIC,
            runtime_mode: MIR_RUNTIME_MODE_HOSTED,
            call_abi_profile: MIR_CALL_ABI_PROFILE_HOSTED_SYSV,
            supported_address_spaces: MIR_ADDRESS_SPACE_GENERIC,
            supported_calling_conventions: 3,
            runtime_capability_mask: 3,
            feature_flags: 0,
        },
        function_count: 1usize,
        block_count: 0usize,
        value_count: 0usize,
        type_count: 1usize,
        local_count: local_count,
        inst_count: 0usize,
        terminator_count: 0usize,
        operand_count: 0usize,
        block_param_count: 0usize,
        successor_count: 0usize,
        debug_loc_count: 0usize,
        capability_req_count: 0usize,
        field_layout_count: 0usize,
        function_param_type_count: 0usize,
        functions: naked_vec(&functions[0] as &byte, @size_of(MirFunction), 1usize),
        blocks: naked_empty_vec(@size_of(MirBlock)),
        values: naked_empty_vec(@size_of(MirValue)),
        types: naked_vec(&types[0] as &byte, @size_of(MirType), 1usize),
        locals: naked_vec(&locals[0] as &byte, @size_of(MirLocal), local_count),
        insts: naked_empty_vec(@size_of(MirInst)),
        terminators: naked_empty_vec(@size_of(MirTerminator)),
        operands: naked_empty_vec(@size_of(MirOperand)),
        block_params: naked_empty_vec(@size_of(MirBlockParam)),
        successors: naked_empty_vec(@size_of(MirSuccessor)),
        debug_locs: naked_empty_vec(@size_of(MirDebugLoc)),
        capability_reqs: naked_empty_vec(@size_of(MirCapabilityReq)),
        field_layouts: naked_empty_vec(@size_of(MirFieldLayout)),
        function_param_types: naked_empty_vec(@size_of(MirFunctionParamType)),
    };

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

test "PortableMIR records asm-only naked body and forbidden lowering mask" {
    const forbidden: i32 = portable_mir_naked_forbidden_lowering_mask();
    try assert_eq_i32(forbidden, MIR_NAKED_FORBID_PROLOGUE_EPILOGUE + MIR_NAKED_FORBID_STACK_SLOT +
        MIR_NAKED_FORBID_CLEANUP + MIR_NAKED_FORBID_DROP + MIR_NAKED_FORBID_ASYNC +
        MIR_NAKED_FORBID_IMPLICIT_RETURN);

    var valid: MirFunction = portable_mir_naked_test_function(0);
    try assert_eq_i32(portable_mir_function_has_naked_flag(&valid), 1);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&valid), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_PROLOGUE_EPILOGUE), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_STACK_SLOT), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_CLEANUP), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_DROP), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_ASYNC), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_IMPLICIT_RETURN), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, forbidden), 1);

    var ordinary: MirFunction = portable_mir_naked_test_function(1);
    try assert_eq_i32(portable_mir_function_has_naked_flag(&ordinary), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&ordinary), 0);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&ordinary, forbidden), 0);
}

test "PortableMIR rejects ordinary lowering shape for naked functions" {
    var normal_body: MirFunction = portable_mir_naked_test_function(2);
    var local_stack: MirFunction = portable_mir_naked_test_function(3);
    var ordinary_block: MirFunction = portable_mir_naked_test_function(4);
    var cleanup_body: MirFunction = portable_mir_naked_test_function(5);
    var partial_forbidden: MirFunction = portable_mir_naked_test_function(6);
    var empty_asm_body: MirFunction = portable_mir_naked_test_function(7);

    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&normal_body), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&local_stack), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&ordinary_block), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&cleanup_body), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&partial_forbidden), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&empty_asm_body), 0);
}

test "PortableMIR verifier rejects invalid naked lowering and unsupported target" {
    try assert_eq_i32(portable_mir_naked_verify_result(0), MIR_VERIFY_OK);
    try assert_eq_i32(portable_mir_naked_verify_result(1), MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY);
    try assert_eq_i32(portable_mir_naked_verify_result(2), MIR_VERIFY_ERR_INVALID_NAKED_BODY);
    try assert_eq_i32(portable_mir_naked_verify_result(3), MIR_VERIFY_ERR_INVALID_NAKED_BODY);
    try assert_eq_i32(portable_mir_naked_verify_result(4), MIR_VERIFY_ERR_INVALID_NAKED_BODY);
    try assert_eq_i32(portable_mir_naked_verify_result(5), MIR_VERIFY_ERR_INVALID_NAKED_BODY);
    try assert_eq_i32(portable_mir_naked_verify_result(6), MIR_VERIFY_ERR_INVALID_NAKED_BODY);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR naked function contract verified"
