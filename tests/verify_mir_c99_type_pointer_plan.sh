#!/usr/bin/env bash
#
# MIR-C99 pointer type typedef mapping verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 pointer type plan missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$TYPE_FILE" "$MIR_FILE" "$VERIFIER_FILE" "$DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99TypeDef \
    MIR_C99_C_TYPE_KIND_POINTER \
    mir_c99_type_plan_build \
    mir_c99_type_plan_entry_ptr; do
    require_pattern "$TYPE_FILE" "$symbol" "type symbol $symbol"
done

require_pattern "$MIR_FILE" 'MIR_TYPE_KIND_POINTER' \
    "PortableMIR pointer type kind exists"
require_pattern "$MIR_FILE" 'pointee_type_id:[[:space:]]*MirTypeId' \
    "PortableMIR pointer pointee metadata exists"
require_pattern "$MIR_FILE" 'kind:[[:space:]]*MIR_TYPE_KIND_POINTER' \
    "PortableMIR pointer constructor emits pointer kind"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_POINTER' \
    "PortableMIR verifier checks pointer type"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_type_ptr\(module, typ\.pointee_type_id\)' \
    "PortableMIR verifier validates pointee type"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_POINTER' \
    "pointer type kind mapped"
require_pattern "$TYPE_FILE" 'c_kind = MIR_C99_C_TYPE_KIND_POINTER' \
    "pointer C type kind assigned"
require_pattern "$TYPE_FILE" 'pointee_type_id:[[:space:]]*MirTypeId' \
    "pointer pointee metadata captured in type def"
require_pattern "$TYPE_FILE" 'pointee_type_id: typ\.pointee_type_id' \
    "pointer pointee metadata copied from MIR"
require_pattern "$DRIVER_FILE" 'mir_c99_type_plan_build' \
    "driver builds type plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$TYPE_FILE"; then
    echo "error: MIR-C99 types must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_type_pointer_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$TYPE_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 pointer type typedef plan verified"
