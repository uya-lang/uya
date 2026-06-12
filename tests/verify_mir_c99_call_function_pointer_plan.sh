#!/usr/bin/env bash
#
# MIR-C99 function pointer call plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CALL_FILE="$REPO_ROOT/src/codegen/mir_c99/calls.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 function-pointer call plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CALL_FILE" "$VERIFIER_FILE" "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_CALL_TARGET_KIND_FUNCTION_POINTER \
    callee_value_id \
    callee_type_id \
    mir_c99_call_plan_build \
    mir_c99_call_plan_entry_ptr; do
    require_pattern "$CALL_FILE" "$symbol" "function-pointer call symbol $symbol"
done

require_pattern "$CALL_FILE" 'target\.kind == MIR_OPERAND_KIND_CALL_TARGET_FUNCTION_POINTER' \
    "function-pointer target kind recognized"
require_pattern "$CALL_FILE" 'return MIR_C99_CALL_TARGET_KIND_FUNCTION_POINTER' \
    "function-pointer target kind mapped to MIR-C99"
require_pattern "$CALL_FILE" 'target\.value_id == MIR_VALUE_INVALID_ID' \
    "function-pointer call requires callee value"
require_pattern "$CALL_FILE" 'callee_value_id = target\.value_id' \
    "callee function-pointer value captured"
require_pattern "$CALL_FILE" 'callee_type_id = target\.type_id' \
    "callee function-pointer type captured"
require_pattern "$CALL_FILE" 'callee_value_id: callee_value_id' \
    "callee function-pointer value stored in entry"
require_pattern "$CALL_FILE" 'callee_type_id: callee_type_id' \
    "callee function-pointer type stored in entry"
require_pattern "$CALL_FILE" 'signature_type_id = pointee_type\.type_id' \
    "function-pointer pointee signature captured"
require_pattern "$CALL_FILE" 'signature_type_id: signature_type_id' \
    "callee signature stored in entry"
require_pattern "$CALL_FILE" 'function_pointer_type\.kind != MIR_TYPE_KIND_FUNCTION_POINTER' \
    "callee type must be function pointer"
require_pattern "$CALL_FILE" 'pointee_type\.kind != MIR_TYPE_KIND_FUNCTION' \
    "pointee type must be function signature"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_function_pointer_call_target' \
    "PortableMIR verifier validates function-pointer call targets"
require_pattern "$MIR_FILE" 'MIR_OPERAND_KIND_CALL_TARGET_FUNCTION_POINTER' \
    "PortableMIR exposes function-pointer call target operand kind"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CALL_FILE"; then
    echo "error: MIR-C99 calls must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_call_function_pointer_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$CALL_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/driver.uya" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 function-pointer call plan verified"
