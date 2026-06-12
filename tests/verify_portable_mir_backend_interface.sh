#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
MIR_BACKEND_FILE="$REPO_ROOT/src/lower/mir_backend.uya"
NATIVE_MIR_EMITTER_FILE="$REPO_ROOT/src/codegen/native/mir_emitter.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR backend interface missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_VERIFIER_FILE" "$MIR_CONTRACT_FILE" "$MIR_BACKEND_FILE" \
    "$NATIVE_MIR_EMITTER_FILE" "$PORTABLE_MIR_DOC" "$ARCH_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_TARGET_BACKEND_MACHINE \
    MIR_TARGET_BACKEND_PTX \
    MIR_TARGET_BACKEND_EXEC \
    MIR_TARGET_BACKEND_C99 \
    MIR_BACKEND_OUTPUT_MACHINE_MODULE \
    MIR_BACKEND_OUTPUT_PTX_MODULE \
    MIR_BACKEND_OUTPUT_EXEC_BYTECODE \
    MIR_BACKEND_OUTPUT_MIR_C99_PLAN \
    MIR_BACKEND_OUTPUT_C99_PLAN \
    MirTargetBackendRequest \
    MirTargetBackendOutput \
    portable_mir_backend_request_init \
    portable_mir_backend_request_is_verified \
    portable_mir_backend_output_init \
    portable_mir_backend_output_matches_request; do
    require_pattern "$MIR_BACKEND_FILE" "$symbol" "backend symbol $symbol"
done

require_pattern "$MIR_BACKEND_FILE" 'module:[[:space:]]*&PortableMirModule' "request only carries PortableMIR module"
require_pattern "$MIR_BACKEND_FILE" 'result:[[:space:]]*&MirVerifierResult' "request records verifier result"
require_pattern "$MIR_BACKEND_FILE" 'request\.verifier_error_code[[:space:]]*!=[[:space:]]*MIR_VERIFY_OK' "verified request gate"
require_pattern "$MIR_BACKEND_FILE" 'MIR_BACKEND_OUTPUT_MACHINE_MODULE' "MachineModule output kind"
require_pattern "$MIR_BACKEND_FILE" 'MIR_BACKEND_OUTPUT_PTX_MODULE' "PtxModule output kind"
require_pattern "$MIR_BACKEND_FILE" 'MIR_BACKEND_OUTPUT_EXEC_BYTECODE' "ExecBytecode output kind"
require_pattern "$MIR_BACKEND_FILE" 'MIR_BACKEND_OUTPUT_MIR_C99_PLAN' "MirC99Plan output kind"
require_pattern "$MIR_BACKEND_FILE" 'MIR_BACKEND_OUTPUT_C99_PLAN:[[:space:]]*i32[[:space:]]*=[[:space:]]*MIR_BACKEND_OUTPUT_MIR_C99_PLAN' "legacy C99Plan output alias"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_lowering_contract_required_features' "single PortableMIR lowering feature contract"
require_pattern "$MIR_CONTRACT_FILE" 'missing_feature_mask' "lowering feature gaps are reported before backend"
require_pattern "$NATIVE_MIR_EMITTER_FILE" 'request:[[:space:]]*&MirTargetBackendRequest' "native emitter request input"
require_pattern "$NATIVE_MIR_EMITTER_FILE" 'portable_mir:[[:space:]]*&PortableMirModule' "native emitter PortableMIR input"
require_pattern "$NATIVE_MIR_EMITTER_FILE" 'native_mir_emitter_read_portable_mir' "native emitter consumes PortableMIR"
require_pattern "$PORTABLE_MIR_DOC" 'MirTargetBackendRequest' "whitepaper backend request"
require_pattern "$PORTABLE_MIR_DOC" 'MirTargetBackendOutput' "whitepaper backend output"
require_pattern "$PORTABLE_MIR_DOC" '让多个后端复用同一份' "whitepaper single language lowering owner"
require_pattern "$PORTABLE_MIR_DOC" '语言 lowering，而不是让 native、PTX、exec、C99 各自重新发现 Uya 语义' "whitepaper forbids per-backend semantic rediscovery"
require_pattern "$PORTABLE_MIR_DOC" '某个 feature 未实现时必须表现为缺失合同' "whitepaper feature gaps surface before backend"
require_pattern "$PORTABLE_MIR_DOC" 'request\.module` 是 backend 的唯一 IR' "whitepaper PortableMIR-only backend input"
require_pattern "$PORTABLE_MIR_DOC" '输入，且必须来自 verifier 通过后的 `PortableMirModule`' "whitepaper verified PortableMIR input"
require_pattern "$PORTABLE_MIR_DOC" 'MachineModule.*PtxModule.*ExecBytecode.*MirC99Plan' "whitepaper backend output mapping"
require_pattern "$PORTABLE_MIR_DOC" 'backend 不允许新增 generic instance' "whitepaper backend cannot own language discovery"
require_pattern "$ARCH_DOC" 'MirTargetBackendRequest' "architecture backend request"
require_pattern "$ARCH_DOC" '不能新增 `TypedProgram`' "architecture forbids TypedProgram backend entry"

if grep -Eq 'TypedProgram|LoweredProgram|CoreBody|TypeChecker|ASTNode' "$MIR_BACKEND_FILE" "$NATIVE_MIR_EMITTER_FILE"; then
    echo "error: target backend interface must not accept pre-MIR compiler IR" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-backend-interface.XXXXXX)"
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

cat "$MIR_FILE" "$MIR_VERIFIER_FILE" "$MIR_BACKEND_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn backend_empty_vec(item_size: usize) SemanticVector {
    return SemanticVector{
        data: null,
        item_size: item_size,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn backend_profile(profile_id: i32) MirTargetProfile {
    return MirTargetProfile{
        profile_id: profile_id,
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

fn backend_module(profile_id: i32, lifecycle_state: i32) PortableMirModule {
    return PortableMirModule{
        arena: null,
        lifecycle_state: lifecycle_state,
        target_profile: backend_profile(profile_id),
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
        functions: backend_empty_vec(@size_of(MirFunction)),
        blocks: backend_empty_vec(@size_of(MirBlock)),
        values: backend_empty_vec(@size_of(MirValue)),
        types: backend_empty_vec(@size_of(MirType)),
        locals: backend_empty_vec(@size_of(MirLocal)),
        insts: backend_empty_vec(@size_of(MirInst)),
        terminators: backend_empty_vec(@size_of(MirTerminator)),
        operands: backend_empty_vec(@size_of(MirOperand)),
        block_params: backend_empty_vec(@size_of(MirBlockParam)),
        successors: backend_empty_vec(@size_of(MirSuccessor)),
        debug_locs: backend_empty_vec(@size_of(MirDebugLoc)),
        capability_reqs: backend_empty_vec(@size_of(MirCapabilityReq)),
        field_layouts: backend_empty_vec(@size_of(MirFieldLayout)),
        function_param_types: backend_empty_vec(@size_of(MirFunctionParamType)),
    };
}

fn backend_result(error_code: i32) MirVerifierResult {
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

fn backend_request_scratch() MirTargetBackendRequest {
    return MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
}

fn backend_output_scratch() MirTargetBackendOutput {
    return MirTargetBackendOutput{
        backend_kind: 0,
        output_kind: MIR_BACKEND_OUTPUT_NONE,
        machine_module: null,
        ptx_module: null,
        exec_bytecode: null,
        c99_plan: null,
        diagnostic_code: 0,
        flags: 0,
    };
}

test "PortableMIR backend kind maps to target output payload" {
    try assert_eq_i32(portable_mir_backend_kind_is_valid(MIR_TARGET_BACKEND_MACHINE), 1);
    try assert_eq_i32(portable_mir_backend_kind_is_valid(MIR_TARGET_BACKEND_PTX), 1);
    try assert_eq_i32(portable_mir_backend_kind_is_valid(MIR_TARGET_BACKEND_EXEC), 1);
    try assert_eq_i32(portable_mir_backend_kind_is_valid(MIR_TARGET_BACKEND_C99), 1);
    try assert_eq_i32(portable_mir_backend_kind_is_valid(99), 0);
    try assert_eq_i32(portable_mir_backend_output_kind_for_backend(MIR_TARGET_BACKEND_MACHINE),
        MIR_BACKEND_OUTPUT_MACHINE_MODULE);
    try assert_eq_i32(portable_mir_backend_output_kind_for_backend(MIR_TARGET_BACKEND_PTX),
        MIR_BACKEND_OUTPUT_PTX_MODULE);
    try assert_eq_i32(portable_mir_backend_output_kind_for_backend(MIR_TARGET_BACKEND_EXEC),
        MIR_BACKEND_OUTPUT_EXEC_BYTECODE);
    try assert_eq_i32(portable_mir_backend_output_kind_for_backend(MIR_TARGET_BACKEND_C99),
        MIR_BACKEND_OUTPUT_C99_PLAN);
    try assert_eq_i32(portable_mir_backend_output_kind_for_backend(99), MIR_BACKEND_OUTPUT_NONE);
}

test "PortableMIR backend request requires verifier clean active module" {
    var module: PortableMirModule = backend_module(42, PORTABLE_MIR_LIFECYCLE_ACTIVE);
    var ok_result: MirVerifierResult = backend_result(MIR_VERIFY_OK);
    var bad_result: MirVerifierResult = backend_result(MIR_VERIFY_ERR_INVALID_MODULE);
    var request: MirTargetBackendRequest = backend_request_scratch();
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &ok_result,
        MIR_TARGET_BACKEND_MACHINE), 0);
    try assert_eq_i32(request.backend_kind, MIR_TARGET_BACKEND_MACHINE);
    try assert_eq_i32(request.target_profile_id, 42);
    try assert_eq_i32(request.verifier_error_code, MIR_VERIFY_OK);
    try assert_eq_i32(portable_mir_backend_request_is_verified(&request), 1);

    request.verifier_error_code = MIR_VERIFY_ERR_INVALID_MODULE;
    try assert_eq_i32(portable_mir_backend_request_is_verified(&request), 0);
    request.verifier_error_code = MIR_VERIFY_OK;
    module.lifecycle_state = PORTABLE_MIR_LIFECYCLE_RELEASED;
    try assert_eq_i32(portable_mir_backend_request_is_verified(&request), 0);
    module.lifecycle_state = PORTABLE_MIR_LIFECYCLE_ACTIVE;
    request.backend_kind = 99;
    try assert_eq_i32(portable_mir_backend_request_is_verified(&request), 0);

    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &bad_result,
        MIR_TARGET_BACKEND_PTX), 0);
    try assert_eq_i32(portable_mir_backend_request_is_verified(&request), 0);
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &ok_result, 99), -1);
    try assert_eq_i32(portable_mir_backend_request_init(&request, null, &ok_result,
        MIR_TARGET_BACKEND_MACHINE), -1);
}

test "PortableMIR backend output must match verified request" {
    var module: PortableMirModule = backend_module(7, PORTABLE_MIR_LIFECYCLE_ACTIVE);
    var ok_result: MirVerifierResult = backend_result(MIR_VERIFY_OK);
    var request: MirTargetBackendRequest = backend_request_scratch();
    var output: MirTargetBackendOutput = backend_output_scratch();
    try assert_eq_i32(portable_mir_backend_request_init(&request, &module, &ok_result,
        MIR_TARGET_BACKEND_EXEC), 0);
    try assert_eq_i32(portable_mir_backend_output_init(&output, MIR_TARGET_BACKEND_EXEC), 0);
    try assert_eq_i32(output.backend_kind, MIR_TARGET_BACKEND_EXEC);
    try assert_eq_i32(output.output_kind, MIR_BACKEND_OUTPUT_EXEC_BYTECODE);
    try assert_eq_i32(portable_mir_backend_output_matches_request(&request, &output), 1);

    output.backend_kind = MIR_TARGET_BACKEND_C99;
    try assert_eq_i32(portable_mir_backend_output_matches_request(&request, &output), 0);
    try assert_eq_i32(portable_mir_backend_output_init(&output, MIR_TARGET_BACKEND_EXEC), 0);
    output.output_kind = MIR_BACKEND_OUTPUT_C99_PLAN;
    try assert_eq_i32(portable_mir_backend_output_matches_request(&request, &output), 0);
    request.verifier_error_code = MIR_VERIFY_ERR_INVALID_MODULE;
    try assert_eq_i32(portable_mir_backend_output_matches_request(&request, &output), 0);
    try assert_eq_i32(portable_mir_backend_output_init(&output, 99), -1);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR target backend interface verified"
