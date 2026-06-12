#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR lowering contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$LOWER_CORE_FILE" "$MIR_FILE" "$MIR_CONTRACT_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for feature in \
    MIR_LOWER_FEATURE_EXPRESSIONS \
    MIR_LOWER_FEATURE_STATEMENTS \
    MIR_LOWER_FEATURE_CONTROL_FLOW \
    MIR_LOWER_FEATURE_LOAD_STORE_ADDRESS \
    MIR_LOWER_FEATURE_ATOMIC \
    MIR_LOWER_FEATURE_VECTOR_MASK \
    MIR_LOWER_FEATURE_CALL_RETURN_BRANCH \
    MIR_LOWER_FEATURE_FIELD_INDEX_SLICE_ADDRESS \
    MIR_LOWER_FEATURE_COPY_MOVE_DROP \
    MIR_LOWER_FEATURE_CLEANUP_PATH; do
    require_pattern "$MIR_CONTRACT_FILE" "export const ${feature}" "lowering feature $feature"
done

for op in \
    MIR_INST_OP_ADDR_OF_LOCAL \
    MIR_INST_OP_ADDR_OF_GLOBAL \
    MIR_INST_OP_FIELD_ADDR \
    MIR_INST_OP_INDEX_ADDR \
    MIR_INST_OP_SLICE_PTR_ADDR \
    MIR_INST_OP_SLICE_LEN_ADDR \
    MIR_INST_OP_COPY \
    MIR_INST_OP_MOVE \
    MIR_INST_OP_DROP_VALUE \
    MIR_INST_OP_DROP_IN_PLACE \
    MIR_INST_OP_ATOMIC_INIT \
    MIR_INST_OP_ATOMIC_LOAD \
    MIR_INST_OP_ATOMIC_STORE \
    MIR_INST_OP_ATOMIC_RMW \
    MIR_INST_OP_ATOMIC_CMPXCHG \
    MIR_INST_OP_VECTOR_SPLAT \
    MIR_INST_OP_VECTOR_LOAD \
    MIR_INST_OP_VECTOR_STORE \
    MIR_INST_OP_VECTOR_SELECT \
    MIR_INST_OP_ERROR_UNION_OK \
    MIR_INST_OP_ERROR_UNION_ERR \
    MIR_INST_OP_ERROR_UNION_IS_ERR \
    MIR_INST_OP_ERROR_UNION_PAYLOAD \
    MIR_INST_OP_ERROR_UNION_ERROR \
    MIR_INST_OP_ASYNC_FRAME_ALLOC \
    MIR_INST_OP_ASYNC_FRAME_FREE \
    MIR_INST_OP_ASYNC_STATE_LOAD \
    MIR_INST_OP_ASYNC_STATE_STORE \
    MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT \
    MIR_INST_OP_ASYNC_POLL_CHILD \
    MIR_INST_OP_ASYNC_RESUME_EDGE \
    MIR_INST_OP_ASYNC_RESULT_LOAD; do
    require_pattern "$MIR_CONTRACT_FILE" "export const ${op}" "MIR opcode $op"
done

require_pattern "$MIR_CONTRACT_FILE" 'export[[:space:]]+struct[[:space:]]+PortableMirLoweringContract' "PortableMIR lowering contract struct"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_lowering_contract_required_features' "required full-language feature mask"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_lowering_contract_init' "lowering contract initialization"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_INST_FLAG_ATOMIC_ORDERED' "atomic memory-order metadata flag"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_ATOMIC_RMW_ADD' "atomic RMW operation metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_CLEANUP_MODEL_UNWIND' "cleanup unwind metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_CLEANUP_ACTION_ERRDEFER' "errdefer cleanup action metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_ERROR_UNION_PATH_FAILURE' "error-union failure path metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_INST_FLAG_ERROR_UNION_CHECKED' "error-union checked extraction metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_ASYNC_FRAME_SLOT_CAPTURED_LOCAL' "async captured local slot metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_ASYNC_EDGE_RESUME' "async resume edge metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_RUNTIME_CAP_ASYNC_FRAME' "async frame runtime capability"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_GLOBAL_INIT_AGGREGATE' "global aggregate initializer metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_CONST_KIND_STRING' "string constant metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_GLOBAL_SECTION_RODATA' "global section metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_GLOBAL_LINKAGE_EXPORT' "global linkage metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_GLOBAL_LINKAGE_EXTERN' "extern global linkage metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_SYMBOL_VISIBILITY_HIDDEN' "symbol visibility metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_LINK_INPUT_KIND_C_IMPORT_OBJECT' "C import object link input metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_CROSS_UNIT_SYMBOL_EXPORT' "cross-unit export symbol metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_CROSS_UNIT_SYMBOL_IMPORT' "cross-unit import symbol metadata"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_CROSS_UNIT_OWNER_GLOBAL' "cross-unit owner metadata"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_lowering_feature_for_stmt_kind' "CoreStmt to MIR feature mapping"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_lowering_feature_for_expr_kind' "CoreExpr to MIR feature mapping"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_lowering_feature_for_place_kind' "CorePlace to MIR feature mapping"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_lowering_feature_for_cleanup_kind' "CoreCleanupEdge to MIR feature mapping"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_core_input_is_frozen\(input\)' "lowering contract is gated by frozen CoreIR input"
require_pattern "$MIR_FILE" 'export const MIR_INST_OP_LOAD' "base MIR load opcode remains in MIR data model"
require_pattern "$MIR_FILE" 'export const MIR_INST_OP_STORE' "base MIR store opcode remains in MIR data model"
require_pattern "$MIR_FILE" 'export const MIR_TERMINATOR_KIND_BR' "base MIR branch terminator remains in MIR data model"
require_pattern "$MIR_FILE" 'export const MIR_TERMINATOR_KIND_COND_BR' "base MIR conditional branch terminator remains in MIR data model"
require_pattern "$PORTABLE_MIR_DOC" 'LoweredProgram \+ CoreBody -> PortableMIR lowering 合同' "whitepaper lowering contract section"

if grep -En 'portable_mir_lowering_[[:alnum:]_]+[[:space:]]*\([^)]*(TypedProgram|TypeChecker)' "$MIR_CONTRACT_FILE"; then
    echo "error: PortableMIR lowering contract accepts checker/TypedProgram bypass state" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-lowering-contract.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat >"$tmp_dir/main.uya" <<'EOF'
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
export const CORE_CLEANUP_EDGE_KIND_RETURN: i32 = 2;
export const MIR_INST_OP_STORE: i32 = 2;
export const MIR_TERMINATOR_KIND_RETURN: i32 = 1;
export const MIR_TERMINATOR_KIND_BR: i32 = 2;
export const MIR_TERMINATOR_KIND_COND_BR: i32 = 3;

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
    if input.body_id != 0 {
        return 0;
    }
    return 1;
}
EOF

cat "$MIR_CONTRACT_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

test "PortableMIR lowering contract covers full language CoreBody features" {
    const all_features: i32 = portable_mir_lowering_contract_required_features();
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_EXPRESSIONS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_STATEMENTS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_CONTROL_FLOW), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_LOAD_STORE_ADDRESS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_ATOMIC), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_VECTOR_MASK), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_CALL_RETURN_BRANCH), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_FIELD_INDEX_SLICE_ADDRESS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_COPY_MOVE_DROP), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(all_features, MIR_LOWER_FEATURE_CLEANUP_PATH), 1);

    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_RETURN), MIR_LOWER_FEATURE_CALL_RETURN_BRANCH), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_DROP), MIR_LOWER_FEATURE_COPY_MOVE_DROP), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_DEFER), MIR_LOWER_FEATURE_CLEANUP_PATH), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_IF), MIR_LOWER_FEATURE_CONTROL_FLOW), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_WHILE), MIR_LOWER_FEATURE_CONTROL_FLOW), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_ASSIGN), MIR_LOWER_FEATURE_COPY_MOVE_DROP), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_EXPR), MIR_LOWER_FEATURE_CALL_RETURN_BRANCH), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_CALL), MIR_LOWER_FEATURE_CALL_RETURN_BRANCH), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_LOCAL_REF), MIR_LOWER_FEATURE_EXPRESSIONS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_I32_LE), MIR_LOWER_FEATURE_CONTROL_FLOW), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_ATOMIC), MIR_LOWER_FEATURE_ATOMIC), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_VECTOR), MIR_LOWER_FEATURE_VECTOR_MASK), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_MASK), MIR_LOWER_FEATURE_VECTOR_MASK), 1);
    try assert_eq_i32(portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_INT_LITERAL), MIR_LOWER_FEATURE_EXPRESSIONS);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_place_kind(CORE_PLACE_KIND_FIELD), MIR_LOWER_FEATURE_FIELD_INDEX_SLICE_ADDRESS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_place_kind(CORE_PLACE_KIND_INDEX), MIR_LOWER_FEATURE_FIELD_INDEX_SLICE_ADDRESS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_place_kind(CORE_PLACE_KIND_SLICE), MIR_LOWER_FEATURE_FIELD_INDEX_SLICE_ADDRESS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(portable_mir_lowering_feature_for_cleanup_kind(CORE_CLEANUP_EDGE_KIND_RETURN), MIR_LOWER_FEATURE_CLEANUP_PATH), 1);

    var lowered: LoweredProgram = LoweredProgram{ marker: 1 };
    var input: PortableMirCoreInput = PortableMirCoreInput{
        program: &lowered,
        body_id: 0,
        target_profile_id: 1,
        flags: 0,
    };
    var contract: PortableMirLoweringContract = portable_mir_lowering_contract_empty();
    try assert_eq_i32(portable_mir_lowering_contract_init(&contract, &input, all_features), 0);
    try assert_eq_i32(contract.missing_feature_mask, 0);
    try assert_eq_i32(portable_mir_lowering_contract_accepts_feature(&contract, MIR_LOWER_FEATURE_ATOMIC), 1);
    try assert_eq_i32(portable_mir_lowering_contract_accepts_feature(&contract, MIR_LOWER_FEATURE_CLEANUP_PATH), 1);

    const without_cleanup: i32 = all_features - MIR_LOWER_FEATURE_CLEANUP_PATH;
    try assert_eq_i32(portable_mir_lowering_contract_init(&contract, &input, without_cleanup), -1);
    try assert_eq_i32(contract.missing_feature_mask, MIR_LOWER_FEATURE_CLEANUP_PATH);

    try assert_eq_i32(MIR_INST_OP_FIELD_ADDR > MIR_INST_OP_STORE, 1);
    try assert_eq_i32(MIR_INST_OP_ATOMIC_LOAD > MIR_INST_OP_DROP_VALUE, 1);
    try assert_eq_i32(MIR_INST_OP_VECTOR_SELECT > MIR_INST_OP_VECTOR_STORE, 1);
    try assert_eq_i32(MIR_TERMINATOR_KIND_BR > MIR_TERMINATOR_KIND_RETURN, 1);
    try assert_eq_i32(MIR_TERMINATOR_KIND_COND_BR > MIR_TERMINATOR_KIND_BR, 1);

}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR lowering contract verified"
