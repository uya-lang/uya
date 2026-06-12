#!/usr/bin/env bash
#
# MIR-C99 call ABI metadata reject verifier.

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
        echo "error: MIR-C99 call ABI reject plan missing evidence: $description" >&2
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
    required_call_flags \
    mir_c99_call_signature_required_flags \
    MIR_CALL_FLAG_MULTI_PARAM \
    MIR_CALL_FLAG_AGGREGATE_RETURN \
    MIR_CALL_FLAG_OUT_PARAM_WRITEBACK \
    MIR_CALL_FLAG_ERROR_UNION_RETURN \
    MIR_CALL_FLAG_FLOAT_ABI; do
    require_pattern "$CALL_FILE" "$symbol" "ABI required flag symbol $symbol"
done

require_pattern "$CALL_FILE" 'signature\.field_count > 1' \
    "multi-param signatures require explicit metadata"
require_pattern "$CALL_FILE" 'return_type\.kind == MIR_TYPE_KIND_ERROR_UNION' \
    "error-union return requires explicit metadata"
require_pattern "$CALL_FILE" 'inst\.flags & required_call_flags' \
    "missing required call ABI metadata rejected"
require_pattern "$CALL_FILE" 'return MIR_C99_CALL_STATUS_REJECT' \
    "reject status used for missing metadata"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_call_abi_metadata' \
    "PortableMIR verifier already validates call ABI metadata"
require_pattern "$MIR_FILE" 'portable_mir_call_flag_for_param_count' \
    "PortableMIR exposes param-count ABI flag helper"
require_pattern "$MIR_FILE" 'portable_mir_call_flag_for_return_type' \
    "PortableMIR exposes return-type ABI flag helper"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CALL_FILE"; then
    echo "error: MIR-C99 calls must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_call_abi_metadata_reject_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 call ABI metadata reject plan verified"
