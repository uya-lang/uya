#!/usr/bin/env bash
#
# MIR-C99 array/slice type metadata verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"

for file in "$MIR_FILE" "$VERIFIER_FILE" "$TYPE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 array/slice type metadata missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for kind in ARRAY SLICE; do
    require_pattern "$MIR_FILE" "MIR_TYPE_KIND_${kind}" "PortableMIR type kind ${kind}"
    require_pattern "$TYPE_FILE" "MIR_C99_C_TYPE_KIND_${kind}" "MIR-C99 C type kind ${kind}"
    require_pattern "$TYPE_FILE" "typ\\.kind == MIR_TYPE_KIND_${kind}" "MIR-C99 maps ${kind}"
    require_pattern "$TYPE_FILE" "c_kind = MIR_C99_C_TYPE_KIND_${kind}" "MIR-C99 assigns C kind ${kind}"
done

require_pattern "$MIR_FILE" 'element_type_id:[[:space:]]*MirTypeId' \
    "PortableMIR type metadata exposes element_type_id"
require_pattern "$MIR_FILE" 'field_count:[[:space:]]*i32' \
    "PortableMIR type metadata exposes array length field_count"
require_pattern "$MIR_FILE" 'lane_count:[[:space:]]*i32' \
    "PortableMIR type metadata exposes slice capacity lane_count"
require_pattern "$MIR_FILE" 'tag_offset_bytes:[[:space:]]*usize' \
    "PortableMIR type metadata exposes slice ptr offset"
require_pattern "$MIR_FILE" 'payload_offset_bytes:[[:space:]]*usize' \
    "PortableMIR type metadata exposes slice len offset"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_array_slice_layout' \
    "verifier has array/slice layout helper"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_ARRAY' \
    "verifier checks array layout"
require_pattern "$VERIFIER_FILE" 'typ\.kind != MIR_TYPE_KIND_ARRAY && typ\.kind != MIR_TYPE_KIND_SLICE' \
    "verifier checks slice layout"
require_pattern "$VERIFIER_FILE" 'typ\.field_count <= 0' \
    "verifier rejects missing array length"
require_pattern "$VERIFIER_FILE" 'typ\.lane_count < typ\.field_count' \
    "verifier rejects invalid slice capacity metadata"

require_pattern "$TYPE_FILE" 'element_type_id: typ\.element_type_id' \
    "MIR-C99 type plan preserves element type"
require_pattern "$TYPE_FILE" 'field_count: typ\.field_count' \
    "MIR-C99 type plan preserves length metadata"
require_pattern "$TYPE_FILE" 'lane_count: typ\.lane_count' \
    "MIR-C99 type plan preserves capacity metadata"

echo "OK: MIR-C99 array/slice type metadata verified"
