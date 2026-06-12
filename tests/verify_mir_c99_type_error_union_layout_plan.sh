#!/usr/bin/env bash
#
# MIR-C99 error-union layout plan verifier.

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
        echo "error: MIR-C99 error-union layout plan missing evidence: $description" >&2
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
    MirC99ErrorUnionLayoutEntry \
    error_union_layouts \
    error_union_layout_count \
    mir_c99_type_plan_append_error_union_layout \
    mir_c99_type_plan_error_union_layout_ptr; do
    require_pattern "$TYPE_FILE" "$symbol" "error-union layout symbol $symbol"
done

require_pattern "$TYPE_FILE" 'owner_type_id:[[:space:]]*MirTypeId' \
    "error-union owner type captured"
require_pattern "$TYPE_FILE" 'payload_type_id:[[:space:]]*MirTypeId' \
    "error-union payload type captured"
require_pattern "$TYPE_FILE" 'tag_offset_bytes:[[:space:]]*usize' \
    "error-union tag offset captured"
require_pattern "$TYPE_FILE" 'payload_offset_bytes:[[:space:]]*usize' \
    "error-union payload offset captured"
require_pattern "$TYPE_FILE" 'size_bytes:[[:space:]]*usize' \
    "error-union size captured"
require_pattern "$TYPE_FILE" 'align_bytes:[[:space:]]*usize' \
    "error-union align captured"
require_pattern "$TYPE_FILE" 'abi_class:[[:space:]]*i32' \
    "error-union ABI class captured"
require_pattern "$TYPE_FILE" 'typ\.kind != MIR_TYPE_KIND_ERROR_UNION' \
    "error-union layout append rejects non-error-union type"
require_pattern "$TYPE_FILE" 'payload_type_id: typ\.element_type_id' \
    "error-union payload type comes from MIR element type"
require_pattern "$TYPE_FILE" 'portable_mir_verify_error_union_layout' \
    "error-union layout plan reuses verifier-clean layout contract"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_error_union_layout' \
    "PortableMIR verifier checks error-union layout"
require_pattern "$MIR_FILE" 'MIR_ABI_CLASS_ERROR_UNION' \
    "PortableMIR exposes error-union ABI class"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$TYPE_FILE"; then
    echo "error: MIR-C99 error-union layout type plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_type_error_union_layout_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 error-union layout plan verified"
