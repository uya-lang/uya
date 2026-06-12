#!/usr/bin/env bash
#
# MIR-C99 function/function-pointer signature plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 function signature plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$TYPE_FILE" "$VERIFIER_FILE" "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99FunctionSignatureEntry \
    MirC99FunctionParamEntry \
    function_signatures \
    function_signature_count \
    function_params \
    function_param_count \
    mir_c99_type_plan_append_function_signature \
    mir_c99_type_plan_function_signature_ptr \
    mir_c99_type_plan_function_param_ptr; do
    require_pattern "$TYPE_FILE" "$symbol" "function signature symbol $symbol"
done

require_pattern "$TYPE_FILE" 'return_type_id:[[:space:]]*MirTypeId' \
    "function return type captured"
require_pattern "$TYPE_FILE" 'callable_type_id:[[:space:]]*MirTypeId' \
    "function-pointer callable type captured"
require_pattern "$TYPE_FILE" 'param_start:[[:space:]]*i32' \
    "function param range start captured"
require_pattern "$TYPE_FILE" 'param_count:[[:space:]]*i32' \
    "function param count captured"
require_pattern "$TYPE_FILE" 'param_type_id:[[:space:]]*MirTypeId' \
    "function param type captured"
require_pattern "$TYPE_FILE" 'calling_convention:[[:space:]]*i32' \
    "function calling convention captured"
require_pattern "$TYPE_FILE" 'param\.owner_type_id != typ\.type_id' \
    "function param owner relation validated"
require_pattern "$TYPE_FILE" 'param\.param_index != i' \
    "function param order validated"
require_pattern "$TYPE_FILE" 'portable_mir_verify_function_type_layout' \
    "function signature plan reuses verifier-clean type layout contract"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_function_type_layout' \
    "PortableMIR verifier checks function type layout"
require_pattern "$MIR_FILE" 'MirFunctionParamType' \
    "PortableMIR exposes function param metadata"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$TYPE_FILE"; then
    echo "error: MIR-C99 function signature type plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_type_function_signature_plan.XXXXXX.uya)"
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
    "$REPO_ROOT/src/codegen/mir_c99/driver.uya" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 function signature plan verified"
