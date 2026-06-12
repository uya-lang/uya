#!/usr/bin/env bash
#
# PortableMIR conversion opcode inventory verifier.

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
        echo "error: PortableMIR conversion opcode inventory missing evidence: $description" >&2
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
    MIR_INST_OP_CONVERT_MIN \
    MIR_INST_OP_CONVERT_MAX \
    MIR_INST_OP_SIGN_EXTEND \
    MIR_INST_OP_ZERO_EXTEND \
    MIR_INST_OP_TRUNCATE \
    MIR_INST_OP_INT_TO_F32 \
    MIR_INST_OP_INT_TO_F64 \
    MIR_INST_OP_F32_TO_INT \
    MIR_INST_OP_F64_TO_INT \
    MIR_INST_OP_F32_TO_F64 \
    MIR_INST_OP_F64_TO_F32 \
    portable_mir_type_kind_is_float \
    portable_mir_inst_op_is_conversion; do
    require_pattern "$MIR_FILE" "$symbol" "MIR conversion symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_conversion_inst' \
    "conversion verifier helper"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_conversion' \
    "verifier uses conversion opcode classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_type_kind_is_float' \
    "verifier uses float type classification"
require_pattern "$VERIFIER_FILE" 'portable_mir_type_kind_is_integer' \
    "verifier uses integer type classification"

echo "OK: PortableMIR conversion opcode inventory verified"
