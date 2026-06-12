#!/usr/bin/env bash
#
# PortableMIR call target/callee expression verifier.

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
        echo "error: PortableMIR call target inventory missing evidence: $description" >&2
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
    MIR_OPERAND_KIND_CALL_TARGET_DIRECT \
    MIR_OPERAND_KIND_CALL_TARGET_EXTERN \
    MIR_OPERAND_KIND_CALL_TARGET_METHOD_INSTANCE \
    MIR_OPERAND_KIND_CALL_TARGET_FUNCTION_POINTER \
    portable_mir_operand_kind_is_call_target; do
    require_pattern "$MIR_FILE" "$symbol" "MIR call target symbol $symbol"
done

for symbol in \
    portable_mir_verify_call_target_operand \
    portable_mir_verify_direct_call_target \
    portable_mir_verify_extern_call_target \
    portable_mir_verify_method_instance_call_target \
    portable_mir_verify_function_pointer_call_target; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier call target helper $symbol"
done

require_pattern "$VERIFIER_FILE" 'MIR_OPERAND_KIND_CALL_TARGET_DIRECT' \
    "direct call target checked"
require_pattern "$VERIFIER_FILE" 'MIR_OPERAND_KIND_CALL_TARGET_EXTERN' \
    "extern call target checked"
require_pattern "$VERIFIER_FILE" 'MIR_OPERAND_KIND_CALL_TARGET_METHOD_INSTANCE' \
    "method/monomorphized call target checked"
require_pattern "$VERIFIER_FILE" 'MIR_OPERAND_KIND_CALL_TARGET_FUNCTION_POINTER' \
    "function pointer call target checked"
require_pattern "$VERIFIER_FILE" 'MIR_TYPE_KIND_FUNCTION_POINTER' \
    "function pointer callee type checked"
require_pattern "$TODO_FILE" 'direct call、extern call、method/monomorphized call、function pointer call' \
    "todo records call target leaf"

echo "OK: PortableMIR call target inventory verified"
