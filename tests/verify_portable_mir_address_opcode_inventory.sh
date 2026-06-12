#!/usr/bin/env bash
#
# PortableMIR local/global/param address opcode inventory verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR address opcode inventory missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$VERIFIER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_INST_OP_ADDR_OF_LOCAL \
    MIR_INST_OP_ADDR_OF_GLOBAL \
    MIR_INST_OP_ADDR_OF_PARAM \
    MIR_INST_OP_ADDRESS_MIN \
    MIR_INST_OP_ADDRESS_MAX \
    portable_mir_inst_op_is_address \
    MIR_VALUE_FLAG_ADDRESS; do
    require_pattern "$MIR_FILE" "$symbol" "MIR address symbol $symbol"
done

for symbol in \
    portable_mir_verify_address_value_inst \
    portable_mir_verify_address_result_value \
    portable_mir_verify_address_source_lifetime \
    portable_mir_inst_op_is_address; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier address helper $symbol"
done

require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_ADDR_OF_LOCAL' \
    "local address opcode verified"
require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_ADDR_OF_GLOBAL' \
    "global address opcode verified"
require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_ADDR_OF_PARAM' \
    "param address opcode verified"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_POINTER' \
    "address result requires pointer type"
require_pattern "$VERIFIER_FILE" 'MIR_VALUE_FLAG_ADDRESS' \
    "address result value flag enforced"
require_pattern "$VERIFIER_FILE" 'MIR_LOCAL_FLAG_ADDRESS_TAKEN' \
    "local slot lifetime/address-taken constraint enforced"
require_pattern "$VERIFIER_FILE" 'param_index' \
    "param address source relation checked"
require_pattern "$TODO_FILE" 'local/global/param address opcode' \
    "todo records address opcode leaf"

if grep -Eq 'MIR_INST_OP_ADDR_OF_(LOCAL|GLOBAL|PARAM)' "$REPO_ROOT/src/lower/mir_contract.uya" &&
   ! grep -Eq 'MIR_INST_OP_ADDR_OF_(LOCAL|GLOBAL|PARAM)' "$MIR_FILE"; then
    echo "error: address opcodes exist only in mir_contract.uya, not real PortableMIR" >&2
    exit 1
fi

echo "OK: PortableMIR local/global/param address opcode inventory verified"
