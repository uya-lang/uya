#!/usr/bin/env bash
#
# PortableMIR f32/f64 value opcode inventory verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR float opcode inventory missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$VERIFIER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_INST_OP_FLOAT_ARITH_MIN \
    MIR_INST_OP_FLOAT_ARITH_MAX \
    MIR_INST_OP_FLOAT_CMP_MIN \
    MIR_INST_OP_FLOAT_CMP_MAX \
    MIR_INST_OP_FLOAT_CONST_MIN \
    MIR_INST_OP_FLOAT_CONST_MAX \
    MIR_INST_OP_F32_ADD \
    MIR_INST_OP_F32_SUB \
    MIR_INST_OP_F32_MUL \
    MIR_INST_OP_F32_DIV \
    MIR_INST_OP_F64_ADD \
    MIR_INST_OP_F64_SUB \
    MIR_INST_OP_F64_MUL \
    MIR_INST_OP_F64_DIV \
    MIR_INST_OP_F32_EQ \
    MIR_INST_OP_F32_LT \
    MIR_INST_OP_F32_LE \
    MIR_INST_OP_F64_EQ \
    MIR_INST_OP_F64_LT \
    MIR_INST_OP_F64_LE \
    MIR_INST_OP_CONST_F32 \
    MIR_INST_OP_CONST_F64 \
    portable_mir_inst_op_is_float_arithmetic \
    portable_mir_inst_op_is_float_compare \
    portable_mir_inst_op_is_float_constant; do
    require_pattern "$MIR_FILE" "$symbol" "MIR float symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_float_value_inst' \
    "float value verifier helper"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_float_arithmetic' \
    "verifier uses float arithmetic classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_float_compare' \
    "verifier uses float comparison classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_float_constant' \
    "verifier uses float constant classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_type_kind_is_float' \
    "verifier uses float type classification"

echo "OK: PortableMIR f32/f64 value opcode inventory verified"
