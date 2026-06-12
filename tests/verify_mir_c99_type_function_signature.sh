#!/usr/bin/env bash
#
# MIR-C99 function/function-pointer type signature metadata verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: function signature metadata missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$VERIFIER_FILE" "$TYPE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_TYPE_KIND_FUNCTION \
    MIR_TYPE_KIND_FUNCTION_POINTER \
    MirFunctionParamType \
    function_param_type_count \
    function_param_types \
    portable_mir_append_function_param_type; do
    require_pattern "$MIR_FILE" "$symbol" "PortableMIR symbol $symbol"
done

for symbol in \
    portable_mir_verify_function_type_layout \
    portable_mir_verify_function_param_type \
    portable_mir_verify_function_param_types; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_FUNCTION' \
    "verifier checks function type kind"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_FUNCTION_POINTER' \
    "verifier checks function pointer type kind"
require_pattern "$VERIFIER_FILE" 'param\.owner_type_id != typ\.type_id' \
    "verifier checks param owner relation"
require_pattern "$VERIFIER_FILE" 'param\.param_index != offset' \
    "verifier checks param order"
require_pattern "$VERIFIER_FILE" 'typ\.abi_class == 0' \
    "verifier rejects missing ABI class"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_call_abi_supported\(module, typ\.flags\)' \
    "verifier checks calling convention via flags"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_type_ptr\(module, typ\.element_type_id\)' \
    "verifier checks return type"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_type_ptr\(module, typ\.pointee_type_id\)' \
    "verifier checks function-pointer target type"

for symbol in \
    MIR_C99_C_TYPE_KIND_FUNCTION \
    MIR_C99_C_TYPE_KIND_FUNCTION_POINTER \
    return_type_id \
    callable_type_id \
    calling_convention; do
    require_pattern "$TYPE_FILE" "$symbol" "MIR-C99 type-plan symbol $symbol"
done

require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_FUNCTION' \
    "MIR-C99 maps function type kind"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_FUNCTION_POINTER' \
    "MIR-C99 maps function pointer type kind"
require_pattern "$TYPE_FILE" 'return_type_id: typ\.element_type_id' \
    "MIR-C99 preserves return type"
require_pattern "$TYPE_FILE" 'callable_type_id: typ\.pointee_type_id' \
    "MIR-C99 preserves callable relation"
require_pattern "$TYPE_FILE" 'calling_convention: typ\.flags' \
    "MIR-C99 preserves calling convention"

echo "OK: MIR-C99 function signature type metadata verified"
