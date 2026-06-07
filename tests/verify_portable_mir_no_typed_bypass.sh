#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
COREIR_DOC="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR no TypedProgram bypass contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_CONTRACT_FILE" "$PORTABLE_MIR_DOC" "$COREIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for gap in \
    MIR_METADATA_GAP_SOURCE_SPAN \
    MIR_METADATA_GAP_PROOF \
    MIR_METADATA_GAP_CAPABILITY \
    MIR_METADATA_GAP_LAYOUT \
    MIR_METADATA_GAP_CALL_TARGET \
    MIR_METADATA_GAP_FIELD_ID \
    MIR_METADATA_GAP_CLEANUP; do
    require_pattern "$MIR_CONTRACT_FILE" "export const ${gap}" "metadata gap $gap"
done

require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_metadata_gap_requires_coreir_backfill' "metadata gap backfill API"
require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_core_input_is_frozen\(input\)' "lowering entry is frozen CoreIR gated"
require_pattern "$PORTABLE_MIR_DOC" '默认不查询 `TypedProgram`' "PortableMIR whitepaper forbids TypedProgram default query"
require_pattern "$PORTABLE_MIR_DOC" '先回补 CoreIR' "PortableMIR whitepaper requires CoreIR backfill"
require_pattern "$COREIR_DOC" '不能把 `TypedProgram` 当作语义查询旁路' "CoreIR whitepaper forbids TypedProgram bypass"

if grep -En '\b(TypedProgram|TypeChecker)\b|typed_program_' "$MIR_FILE" "$MIR_CONTRACT_FILE"; then
    echo "error: PortableMIR lowering source mentions checker/TypedProgram bypass state" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-no-typed-bypass.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat >"$tmp_dir/main.uya" <<'EOF'
export type CoreBodyId = i32;
export const CORE_BODY_INVALID_ID: CoreBodyId = -1;
export const CORE_STMT_KIND_RETURN: i32 = 10;
export const CORE_STMT_KIND_ASM: i32 = 11;
export const CORE_STMT_KIND_DEFER: i32 = 12;
export const CORE_STMT_KIND_ERRDEFER: i32 = 13;
export const CORE_STMT_KIND_DROP: i32 = 14;
export const CORE_STMT_KIND_ERROR_PROPAGATION: i32 = 15;
export const CORE_EXPR_KIND_CALL: i32 = 11;
export const CORE_EXPR_KIND_INDEX: i32 = 12;
export const CORE_EXPR_KIND_SLICE: i32 = 13;
export const CORE_EXPR_KIND_ATOMIC: i32 = 14;
export const CORE_EXPR_KIND_VECTOR: i32 = 15;
export const CORE_EXPR_KIND_MASK: i32 = 16;
export const CORE_EXPR_KIND_INT_LITERAL: i32 = 17;
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
    if input.body_id != 0 {
        return 0;
    }
    return 1;
}
EOF

cat "$MIR_CONTRACT_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

test "PortableMIR metadata gaps require CoreIR backfill" {
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(MIR_METADATA_GAP_SOURCE_SPAN), 1);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(MIR_METADATA_GAP_PROOF), 1);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(MIR_METADATA_GAP_CAPABILITY), 1);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(MIR_METADATA_GAP_LAYOUT), 1);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(MIR_METADATA_GAP_CALL_TARGET), 1);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(MIR_METADATA_GAP_FIELD_ID), 1);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(MIR_METADATA_GAP_CLEANUP), 1);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(0), 0);
    try assert_eq_i32(portable_mir_metadata_gap_requires_coreir_backfill(999), 0);

    var lowered: LoweredProgram = LoweredProgram{ marker: 1 };
    var input: PortableMirCoreInput = PortableMirCoreInput{
        program: &lowered,
        body_id: 0,
        target_profile_id: 1,
        flags: 0,
    };
    var contract: PortableMirLoweringContract = portable_mir_lowering_contract_empty();
    try assert_eq_i32(portable_mir_lowering_contract_init(&contract, &input, portable_mir_lowering_contract_required_features()), 0);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR no TypedProgram bypass contract verified"
