#!/usr/bin/env bash

# Phase 9A：验证 hosted native 第一阶段通过宿主 ABI/linker 承接运行时链接需求。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_BACKEND_FILE="$REPO_ROOT/src/lower/mir_backend.uya"
HOSTED_LINK_FILE="$REPO_ROOT/src/codegen/native/hosted_link.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: hosted native link contract 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_VERIFIER_FILE" "$MIR_BACKEND_FILE" "$HOSTED_LINK_FILE" \
    "$PORTABLE_MIR_DOC" "$ARCH_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

for symbol in \
    NativeHostedLinkPlan \
    NATIVE_HOSTED_ABI_SYSV \
    NATIVE_HOSTED_LINKER_HOST_CC \
    NATIVE_HOSTED_LINK_REQUIRE_LIBC \
    NATIVE_HOSTED_LINK_REQUIRE_PTHREAD \
    NATIVE_HOSTED_LINK_REQUIRE_FILESYSTEM \
    NATIVE_HOSTED_LINK_REQUIRE_ENV \
    NATIVE_HOSTED_LINK_REQUIRE_MALLOC \
    NATIVE_HOSTED_LINK_REQUIRE_EXTERN \
    NATIVE_HOSTED_LINK_REQUIRE_C_IMPORT \
    native_hosted_link_plan_init \
    native_hosted_link_plan_is_complete \
    native_hosted_link_plan_add_extern_symbol \
    native_hosted_link_plan_add_print_helper_object \
    native_hosted_link_plan_add_c_import_object; do
    require_pattern "$HOSTED_LINK_FILE" "$symbol" "hosted link symbol $symbol"
done

require_pattern "$HOSTED_LINK_FILE" 'request\.backend_kind[[:space:]]*!=[[:space:]]*MIR_TARGET_BACKEND_MACHINE' "Machine backend request gate"
require_pattern "$HOSTED_LINK_FILE" 'portable_mir_backend_request_is_verified' "verifier-clean request gate"
require_pattern "$HOSTED_LINK_FILE" 'runtime_mode[[:space:]]*!=[[:space:]]*MIR_RUNTIME_MODE_HOSTED' "hosted runtime gate"
require_pattern "$ARCH_DOC" 'NativeHostedLinkPlan' "architecture hosted link plan"
require_pattern "$ARCH_DOC" 'libc`、`pthread`、filesystem、env、malloc、extern symbol 和 `@c_import`' "architecture hosted requirements"
require_pattern "$PORTABLE_MIR_DOC" 'NativeHostedLinkPlan' "whitepaper hosted link plan"
require_pattern "$PORTABLE_MIR_DOC" 'filesystem、env、malloc、extern symbol 和 `@c_import` object' "whitepaper hosted requirements"

tmp_dir="$(mktemp -d /tmp/uya-native-hosted-link.XXXXXX)"
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

cat "$MIR_FILE" "$MIR_VERIFIER_FILE" "$MIR_BACKEND_FILE" "$HOSTED_LINK_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn hosted_link_empty_vec(item_size: usize) SemanticVector {
    return SemanticVector{
        data: null,
        item_size: item_size,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn hosted_link_profile(mode: i32) MirTargetProfile {
    return MirTargetProfile{
        profile_id: 99,
        pointer_size: 8,
        endianness: 0,
        default_address_space: MIR_ADDRESS_SPACE_GENERIC,
        runtime_mode: mode,
        call_abi_profile: MIR_CALL_ABI_PROFILE_HOSTED_SYSV,
        supported_address_spaces: MIR_ADDRESS_SPACE_GENERIC + MIR_ADDRESS_SPACE_HOST,
        supported_calling_conventions: 3,
        runtime_capability_mask: 3,
        feature_flags: 0,
    };
}

fn hosted_link_module(mode: i32) PortableMirModule {
    return PortableMirModule{
        arena: null,
        lifecycle_state: PORTABLE_MIR_LIFECYCLE_ACTIVE,
        target_profile: hosted_link_profile(mode),
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
        functions: hosted_link_empty_vec(@size_of(MirFunction)),
        blocks: hosted_link_empty_vec(@size_of(MirBlock)),
        values: hosted_link_empty_vec(@size_of(MirValue)),
        types: hosted_link_empty_vec(@size_of(MirType)),
        locals: hosted_link_empty_vec(@size_of(MirLocal)),
        insts: hosted_link_empty_vec(@size_of(MirInst)),
        terminators: hosted_link_empty_vec(@size_of(MirTerminator)),
        operands: hosted_link_empty_vec(@size_of(MirOperand)),
        block_params: hosted_link_empty_vec(@size_of(MirBlockParam)),
        successors: hosted_link_empty_vec(@size_of(MirSuccessor)),
        debug_locs: hosted_link_empty_vec(@size_of(MirDebugLoc)),
        capability_reqs: hosted_link_empty_vec(@size_of(MirCapabilityReq)),
    };
}

fn hosted_link_result(error_code: i32) MirVerifierResult {
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

fn hosted_link_request(module: &PortableMirModule, result: &MirVerifierResult,
    backend_kind: i32) MirTargetBackendRequest {
    var request: MirTargetBackendRequest = MirTargetBackendRequest{
        module: null,
        backend_kind: 0,
        target_profile_id: 0,
        verifier_error_code: -1,
        flags: 0,
    };
    _ = portable_mir_backend_request_init(&request, module, result, backend_kind);
    return request;
}

test "hosted native link plan records host ABI linker requirements" {
    var module: PortableMirModule = hosted_link_module(MIR_RUNTIME_MODE_HOSTED);
    var result: MirVerifierResult = hosted_link_result(MIR_VERIFY_OK);
    var request: MirTargetBackendRequest = hosted_link_request(&module, &result, MIR_TARGET_BACKEND_MACHINE);
    var plan: NativeHostedLinkPlan = native_hosted_link_plan_empty();
    try assert_eq_i32(native_hosted_link_plan_init(&plan, &request), 0);
    try assert_eq_i32(plan.lifecycle_state, NATIVE_HOSTED_LINK_PLAN_ACTIVE);
    try assert_eq_i32(plan.target_profile_id, 99);
    try assert_eq_i32(plan.abi_mode, NATIVE_HOSTED_ABI_SYSV);
    try assert_eq_i32(plan.linker_mode, NATIVE_HOSTED_LINKER_HOST_CC);
    try assert_eq_i32(native_hosted_link_plan_is_complete(&plan), 1);
    try assert_eq_i32(native_hosted_link_plan_has(&plan, NATIVE_HOSTED_LINK_REQUIRE_LIBC), 1);
    try assert_eq_i32(native_hosted_link_plan_has(&plan, NATIVE_HOSTED_LINK_REQUIRE_PTHREAD), 1);
    try assert_eq_i32(native_hosted_link_plan_has(&plan, NATIVE_HOSTED_LINK_REQUIRE_FILESYSTEM), 1);
    try assert_eq_i32(native_hosted_link_plan_has(&plan, NATIVE_HOSTED_LINK_REQUIRE_ENV), 1);
    try assert_eq_i32(native_hosted_link_plan_has(&plan, NATIVE_HOSTED_LINK_REQUIRE_MALLOC), 1);
    try assert_eq_i32(native_hosted_link_plan_has(&plan, NATIVE_HOSTED_LINK_REQUIRE_EXTERN), 1);
    try assert_eq_i32(native_hosted_link_plan_has(&plan, NATIVE_HOSTED_LINK_REQUIRE_C_IMPORT), 1);
    try assert_eq_i32(native_hosted_link_plan_add_extern_symbol(&plan, 77), 0);
    try assert_eq_i32(native_hosted_link_plan_add_print_helper_object(&plan), 0);
    try assert_eq_i32(native_hosted_link_plan_add_print_helper_object(&plan), 0);
    try assert_eq_i32(native_hosted_link_plan_add_c_import_object(&plan), 0);
    try assert_eq_i32(plan.extern_symbol_count, 1);
    try assert_eq_i32(plan.c_import_object_count, 1);
    try assert_eq_i32(plan.object_count, 2);

    plan.requirement_mask = plan.requirement_mask - NATIVE_HOSTED_LINK_REQUIRE_C_IMPORT;
    try assert_eq_i32(native_hosted_link_plan_is_complete(&plan), 0);
    try assert_eq_i32(native_hosted_link_plan_add_c_import_object(&plan), -1);
}

test "hosted native link plan rejects wrong backend runtime and verifier state" {
    var hosted: PortableMirModule = hosted_link_module(MIR_RUNTIME_MODE_HOSTED);
    var free: PortableMirModule = hosted_link_module(MIR_RUNTIME_MODE_FREESTANDING);
    var ok: MirVerifierResult = hosted_link_result(MIR_VERIFY_OK);
    var bad: MirVerifierResult = hosted_link_result(MIR_VERIFY_ERR_INVALID_MODULE);
    var plan: NativeHostedLinkPlan = native_hosted_link_plan_empty();

    var wrong_backend: MirTargetBackendRequest = hosted_link_request(&hosted, &ok, MIR_TARGET_BACKEND_C99);
    try assert_eq_i32(native_hosted_link_plan_init(&plan, &wrong_backend), -1);

    var bad_verify: MirTargetBackendRequest = hosted_link_request(&hosted, &bad, MIR_TARGET_BACKEND_MACHINE);
    try assert_eq_i32(native_hosted_link_plan_init(&plan, &bad_verify), -1);

    var freestanding: MirTargetBackendRequest = hosted_link_request(&free, &ok, MIR_TARGET_BACKEND_MACHINE);
    try assert_eq_i32(native_hosted_link_plan_init(&plan, &freestanding), -1);

    var good: MirTargetBackendRequest = hosted_link_request(&hosted, &ok, MIR_TARGET_BACKEND_MACHINE);
    try assert_eq_i32(native_hosted_link_plan_init(&plan, &good), 0);
    try assert_eq_i32(native_hosted_link_plan_add_extern_symbol(&plan, -1), -1);
    plan.requirement_mask = plan.requirement_mask - NATIVE_HOSTED_LINK_REQUIRE_EXTERN;
    try assert_eq_i32(native_hosted_link_plan_add_extern_symbol(&plan, 7), -1);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "verify_native_hosted_link_contract: ok"
