#!/usr/bin/env bash
#
# PortableMIR integer/logical value opcode inventory verifier.

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
        echo "error: PortableMIR value opcode inventory missing evidence: $description" >&2
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
    MIR_INST_OP_INT_UNARY_MIN \
    MIR_INST_OP_INT_UNARY_MAX \
    MIR_INST_OP_INT_ARITH_MIN \
    MIR_INST_OP_INT_ARITH_MAX \
    MIR_INST_OP_INT_CMP_MIN \
    MIR_INST_OP_INT_CMP_MAX \
    MIR_INST_OP_LOGIC_MIN \
    MIR_INST_OP_LOGIC_MAX \
    MIR_INST_OP_I8_ADD \
    MIR_INST_OP_U8_ADD \
    MIR_INST_OP_I16_ADD \
    MIR_INST_OP_U16_ADD \
    MIR_INST_OP_U32_ADD \
    MIR_INST_OP_I64_ADD \
    MIR_INST_OP_U64_ADD \
    MIR_INST_OP_ISIZE_ADD \
    MIR_INST_OP_I8_SUB \
    MIR_INST_OP_U16_MUL \
    MIR_INST_OP_U32_DIV \
    MIR_INST_OP_ISIZE_MOD \
    MIR_INST_OP_INT_NEG \
    MIR_INST_OP_INT_NOT \
    MIR_INST_OP_I8_LE \
    MIR_INST_OP_U64_LE \
    MIR_INST_OP_BOOL_AND \
    MIR_INST_OP_BOOL_OR \
    MIR_INST_OP_BOOL_NOT \
    portable_mir_type_kind_is_integer \
    portable_mir_inst_op_is_integer_unary \
    portable_mir_inst_op_is_integer_arithmetic \
    portable_mir_inst_op_is_integer_compare \
    portable_mir_inst_op_is_logic; do
    require_pattern "$MIR_FILE" "$symbol" "MIR inventory symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_integer_value_inst' \
    "integer value verifier helper"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_integer_arithmetic' \
    "verifier uses arithmetic opcode classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_integer_compare' \
    "verifier uses comparison opcode classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_integer_unary' \
    "verifier uses unary opcode classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_logic' \
    "verifier uses logic opcode classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_type_kind_is_integer' \
    "verifier uses integer type classification"

echo "OK: PortableMIR integer/logical value opcode inventory verified"
