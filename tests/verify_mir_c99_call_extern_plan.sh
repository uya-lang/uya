#!/usr/bin/env bash
#
# MIR-C99 extern function call plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CALL_FILE="$REPO_ROOT/src/codegen/mir_c99/calls.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 extern call plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CALL_FILE" "$DRIVER_FILE" "$VERIFIER_FILE" "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_CALL_TARGET_KIND_EXTERN \
    MirC99CallEntry \
    MirC99CallPlan \
    mir_c99_call_plan_build \
    mir_c99_call_plan_entry_ptr; do
    require_pattern "$CALL_FILE" "$symbol" "extern-call symbol $symbol"
done

require_pattern "$CALL_FILE" 'target\.kind != MIR_OPERAND_KIND_CALL_TARGET_DIRECT &&' \
    "direct and extern target kinds accepted"
require_pattern "$CALL_FILE" 'target\.kind == MIR_OPERAND_KIND_CALL_TARGET_EXTERN' \
    "extern target kind recognized"
require_pattern "$CALL_FILE" 'return MIR_C99_CALL_TARGET_KIND_EXTERN' \
    "extern target kind mapped to MIR-C99"
require_pattern "$CALL_FILE" '\(callee\.flags & MIR_FUNCTION_FLAG_EXTERN\) == 0' \
    "extern call requires extern callee flag"
require_pattern "$CALL_FILE" 'callee\.calling_convention != MIR_CALL_CONV_C' \
    "extern call requires C calling convention"
require_pattern "$CALL_FILE" 'callee_function_id = target\.immediate_i32' \
    "extern callee function id captured"
require_pattern "$CALL_FILE" 'callee_function_id: callee_function_id' \
    "extern callee function id stored"
require_pattern "$CALL_FILE" 'signature_type_id = callee\.signature_type_id' \
    "extern callee signature captured"
require_pattern "$CALL_FILE" 'signature_type_id: signature\.type_id' \
    "extern callee signature stored"
require_pattern "$CALL_FILE" 'calling_convention: inst\.calling_convention' \
    "extern call instruction convention captured"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_extern_call_target' \
    "PortableMIR verifier validates extern call targets"
require_pattern "$MIR_FILE" 'MIR_OPERAND_KIND_CALL_TARGET_EXTERN' \
    "PortableMIR exposes extern call target operand kind"
require_pattern "$DRIVER_FILE" 'mir_c99_call_plan_build' \
    "driver builds MIR-C99 call plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CALL_FILE"; then
    echo "error: MIR-C99 calls must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_call_extern_plan.XXXXXX.uya)"
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
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 extern call plan verified"
