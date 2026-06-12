#!/usr/bin/env bash
#
# MIR-C99 aggregate field layout metadata verifier.

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
        echo "error: aggregate field layout missing evidence: $description" >&2
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
    MirFieldLayout \
    field_layout_count \
    field_layouts \
    portable_mir_append_field_layout \
    MIR_TYPE_KIND_UNION \
    MIR_TYPE_KIND_ENUM; do
    require_pattern "$MIR_FILE" "$symbol" "PortableMIR symbol $symbol"
done

for symbol in \
    portable_mir_verify_field_layout \
    portable_mir_verify_aggregate_field_layout \
    portable_mir_verify_field_layouts \
    MIR_VERIFY_ERR_INVALID_LAYOUT; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'field\.owner_type_id != owner\.type_id' \
    "field owner/type relation checked"
require_pattern "$VERIFIER_FILE" 'field\.field_index != offset' \
    "field order checked"
require_pattern "$VERIFIER_FILE" 'field\.offset_bytes < previous_offset' \
    "struct field offset order checked"
require_pattern "$VERIFIER_FILE" 'field\.size_bytes == 0usize \|\| field\.align_bytes == 0usize' \
    "field size/align checked"

for symbol in \
    MIR_C99_C_TYPE_KIND_UNION \
    MIR_C99_C_TYPE_KIND_ENUM \
    tag_offset_bytes \
    payload_offset_bytes; do
    require_pattern "$TYPE_FILE" "$symbol" "MIR-C99 type-plan symbol $symbol"
done

require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_UNION' \
    "MIR-C99 maps union type kind"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_ENUM' \
    "MIR-C99 maps enum type kind"
require_pattern "$TYPE_FILE" 'field_start: typ\.field_start' \
    "MIR-C99 type plan preserves field_start"
require_pattern "$TYPE_FILE" 'field_count: typ\.field_count' \
    "MIR-C99 type plan preserves field_count"
require_pattern "$TYPE_FILE" 'tag_offset_bytes: typ\.tag_offset_bytes' \
    "MIR-C99 type plan preserves tag offset"
require_pattern "$TYPE_FILE" 'payload_offset_bytes: typ\.payload_offset_bytes' \
    "MIR-C99 type plan preserves payload offset"

echo "OK: aggregate field layout metadata verified"
