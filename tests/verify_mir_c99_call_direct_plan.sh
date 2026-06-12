#!/usr/bin/env bash
#
# MIR-C99 Uya direct-call plan verifier.

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
        echo "error: MIR-C99 direct call plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$DRIVER_FILE" "$VERIFIER_FILE" "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

if [[ ! -f "$CALL_FILE" ]]; then
    echo "error: missing MIR-C99 call source: $CALL_FILE" >&2
    exit 1
fi

for symbol in \
    MIR_C99_CALL_TARGET_KIND_DIRECT \
    MirC99CallEntry \
    MirC99CallPlan \
    calls \
    call_count \
    mir_c99_call_plan_build \
    mir_c99_call_plan_entry_ptr; do
    require_pattern "$CALL_FILE" "$symbol" "direct-call symbol $symbol"
done

require_pattern "$CALL_FILE" 'inst\.op != MIR_INST_OP_CALL' \
    "non-call instructions ignored"
require_pattern "$CALL_FILE" 'target\.kind != MIR_OPERAND_KIND_CALL_TARGET_DIRECT' \
    "only direct call targets accepted in this leaf"
require_pattern "$CALL_FILE" 'callee_function_id: target\.immediate_i32' \
    "callee function id captured from MIR operand"
require_pattern "$CALL_FILE" 'signature_type_id: callee\.signature_type_id' \
    "callee signature type captured"
require_pattern "$CALL_FILE" 'arg_start: inst\.operand_start \+ 1' \
    "argument range starts after callee operand"
require_pattern "$CALL_FILE" 'arg_count: inst\.operand_count - 1' \
    "argument count excludes callee operand"
require_pattern "$CALL_FILE" 'result_value_id: inst\.result_value_id' \
    "call result value captured"
require_pattern "$CALL_FILE" 'calling_convention: inst\.calling_convention' \
    "call calling convention captured"
require_pattern "$CALL_FILE" 'callee\.calling_convention != MIR_CALL_CONV_UYA' \
    "direct call rejects non-Uya callee convention"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_direct_call_target' \
    "PortableMIR verifier validates direct call targets"
require_pattern "$MIR_FILE" 'MIR_OPERAND_KIND_CALL_TARGET_DIRECT' \
    "PortableMIR exposes direct call target operand kind"
require_pattern "$DRIVER_FILE" 'use codegen\.mir_c99\.calls' \
    "driver imports MIR-C99 call plan"
require_pattern "$DRIVER_FILE" 'mir_c99_call_plan_build' \
    "driver builds MIR-C99 call plan"
require_pattern "$DRIVER_FILE" 'result\.call_count = call_plan\.call_count' \
    "driver reports call plan count"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CALL_FILE"; then
    echo "error: MIR-C99 calls must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_call_direct_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 Uya direct-call plan verified"
