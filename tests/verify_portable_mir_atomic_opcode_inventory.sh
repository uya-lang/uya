#!/usr/bin/env bash
#
# PortableMIR atomic opcode verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
WHITEPAPER_FILE="$REPO_ROOT/docs/portable_mir_whitepaper.md"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR atomic opcode missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$CONTRACT_FILE" "$VERIFIER_FILE" "$WHITEPAPER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_INST_OP_ATOMIC_INIT \
    MIR_INST_OP_ATOMIC_LOAD \
    MIR_INST_OP_ATOMIC_STORE \
    MIR_INST_OP_ATOMIC_RMW \
    MIR_INST_OP_ATOMIC_CMPXCHG \
    MIR_INST_FLAG_ATOMIC_ORDERED \
    MIR_ATOMIC_ORDER_SEQ_CST \
    MIR_ATOMIC_RMW_ADD \
    portable_mir_inst_op_is_atomic; do
    require_pattern "$MIR_FILE" "$symbol" "MIR atomic symbol $symbol"
done

for symbol in \
    MIR_INST_OP_ATOMIC_INIT \
    MIR_INST_OP_ATOMIC_LOAD \
    MIR_INST_OP_ATOMIC_STORE \
    MIR_INST_OP_ATOMIC_RMW \
    MIR_INST_OP_ATOMIC_CMPXCHG \
    MIR_INST_FLAG_ATOMIC_ORDERED \
    MIR_ATOMIC_ORDER_SEQ_CST \
    MIR_ATOMIC_RMW_ADD; do
    require_pattern "$CONTRACT_FILE" "$symbol" "contract atomic symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_atomic_inst' \
    "verifier has atomic instruction helper"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_atomic' \
    "verifier uses explicit atomic opcode classifier"
require_pattern "$VERIFIER_FILE" 'MIR_INST_FLAG_ATOMIC_ORDERED' \
    "verifier requires atomic memory-order metadata"
require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_LOAD \|\| inst\.op == MIR_INST_OP_STORE' \
    "ordinary load/store atomic guard"
require_pattern "$WHITEPAPER_FILE" 'atomic_load' \
    "whitepaper records atomic load"
require_pattern "$TODO_FILE" 'atomic init/load/store/RMW/CMPXCHG opcode' \
    "todo records atomic leaf"

echo "OK: PortableMIR atomic opcode inventory verified"
