#!/usr/bin/env bash
#
# MIR-C99 struct/union/enum aggregate layout plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 aggregate layout plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$TYPE_FILE" "$DRIVER_FILE" "$VERIFIER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99AggregateLayoutEntry \
    aggregate_layouts \
    aggregate_layout_count \
    mir_c99_type_plan_append_aggregate_layout \
    mir_c99_type_plan_aggregate_layout_ptr; do
    require_pattern "$TYPE_FILE" "$symbol" "aggregate layout symbol $symbol"
done

require_pattern "$TYPE_FILE" 'owner_type_id:[[:space:]]*MirTypeId' \
    "aggregate owner type captured"
require_pattern "$TYPE_FILE" 'c_type_kind:[[:space:]]*i32' \
    "aggregate C kind captured"
require_pattern "$TYPE_FILE" 'field_start:[[:space:]]*i32' \
    "field range start captured"
require_pattern "$TYPE_FILE" 'field_count:[[:space:]]*i32' \
    "field count captured"
require_pattern "$TYPE_FILE" 'size_bytes:[[:space:]]*usize' \
    "aggregate size captured"
require_pattern "$TYPE_FILE" 'align_bytes:[[:space:]]*usize' \
    "aggregate align captured"
require_pattern "$TYPE_FILE" 'tag_offset_bytes:[[:space:]]*usize' \
    "enum/union tag offset captured"
require_pattern "$TYPE_FILE" 'payload_offset_bytes:[[:space:]]*usize' \
    "enum/union payload offset captured"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_STRUCT \|\|' \
    "struct aggregate recognized"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_UNION \|\|' \
    "union aggregate recognized"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_ENUM' \
    "enum aggregate recognized"
require_pattern "$TYPE_FILE" 'portable_mir_verify_aggregate_field_layout' \
    "aggregate layout plan reuses verifier-clean field layout contract"
require_pattern "$DRIVER_FILE" 'result\.type_count = type_plan\.count' \
    "driver still reports type plan count"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_aggregate_field_layout' \
    "PortableMIR verifier checks aggregate field layout"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$TYPE_FILE"; then
    echo "error: MIR-C99 aggregate layout type plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_type_aggregate_layout_plan.XXXXXX.uya)"
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
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 aggregate layout plan verified"
