#!/usr/bin/env bash
#
# MIR-C99 float/double call ABI plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CALL_FILE="$REPO_ROOT/src/codegen/mir_c99/calls.uya"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 float call ABI plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CALL_FILE" "$TYPE_FILE" "$VERIFIER_FILE" "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    return_type_id \
    return_abi_class \
    float_abi_arg_count \
    required_call_flags \
    mir_c99_call_function_param_type_ptr \
    mir_c99_call_float_abi_class_matches_type \
    mir_c99_call_signature_float_abi_arg_count \
    mir_c99_call_signature_required_flags; do
    require_pattern "$CALL_FILE" "$symbol" "float call ABI symbol $symbol"
done

require_pattern "$CALL_FILE" 'MIR_CALL_FLAG_FLOAT_ABI' \
    "float ABI call flag consumed"
require_pattern "$CALL_FILE" 'MIR_ABI_CLASS_FLOAT' \
    "f32 ABI class consumed"
require_pattern "$CALL_FILE" 'MIR_ABI_CLASS_DOUBLE' \
    "f64 ABI class consumed"
require_pattern "$CALL_FILE" 'return_type\.kind == MIR_TYPE_KIND_F32 \|\| return_type\.kind == MIR_TYPE_KIND_F64' \
    "float/double return recognized"
require_pattern "$CALL_FILE" 'param_type\.kind == MIR_TYPE_KIND_F32 \|\| param_type\.kind == MIR_TYPE_KIND_F64' \
    "float/double params recognized"
require_pattern "$CALL_FILE" 'return_type\.abi_class' \
    "return ABI metadata consumed"
require_pattern "$CALL_FILE" 'param\.abi_class' \
    "param ABI metadata consumed"
require_pattern "$CALL_FILE" 'inst\.flags & required_call_flags' \
    "missing call ABI flags rejected"
require_pattern "$CALL_FILE" 'return MIR_C99_CALL_STATUS_REJECT' \
    "missing or mismatched float ABI metadata rejects"
require_pattern "$TYPE_FILE" 'MIR_C99_FLOAT_LAYOUT_USE_RETURN_VALUE' \
    "type plan tracks float return layout"
require_pattern "$TYPE_FILE" 'MIR_C99_FLOAT_LAYOUT_USE_PARAM' \
    "type plan tracks float param layout"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_call_abi_metadata' \
    "PortableMIR verifier validates call ABI metadata"
require_pattern "$MIR_FILE" 'MIR_CALL_FLAG_FLOAT_ABI' \
    "PortableMIR exposes float ABI call flag"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CALL_FILE"; then
    echo "error: MIR-C99 calls must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_call_float_abi_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 float/double call ABI plan verified"
