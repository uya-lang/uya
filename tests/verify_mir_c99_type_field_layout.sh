#!/usr/bin/env bash
#
# MIR-C99 aggregate field layout metadata verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

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

for file in "$MIR_FILE" "$VERIFIER_FILE"; do
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

echo "OK: aggregate field layout metadata verified"
