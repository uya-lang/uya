#!/usr/bin/env bash
#
# MIR-C99 error-union type layout metadata verifier.

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
        echo "error: error-union layout missing evidence: $description" >&2
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

require_pattern "$MIR_FILE" 'MIR_TYPE_KIND_ERROR_UNION' \
    "PortableMIR error-union type kind"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_error_union_layout' \
    "verifier has error-union layout helper"
require_pattern "$VERIFIER_FILE" 'typ\.kind != MIR_TYPE_KIND_ERROR_UNION' \
    "verifier checks error-union kind"
require_pattern "$VERIFIER_FILE" 'typ\.payload_offset_bytes <= typ\.tag_offset_bytes' \
    "verifier checks tag/payload ordering"
require_pattern "$VERIFIER_FILE" 'typ\.abi_class != MIR_ABI_CLASS_ERROR_UNION' \
    "verifier rejects non-error-union ABI class"
require_pattern "$TYPE_FILE" 'MIR_C99_C_TYPE_KIND_ERROR_UNION' \
    "MIR-C99 error-union C type kind"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_ERROR_UNION' \
    "MIR-C99 maps error-union type kind"
require_pattern "$TYPE_FILE" 'tag_offset_bytes: typ\.tag_offset_bytes' \
    "MIR-C99 type plan preserves tag offset"
require_pattern "$TYPE_FILE" 'payload_offset_bytes: typ\.payload_offset_bytes' \
    "MIR-C99 type plan preserves payload offset"
require_pattern "$TYPE_FILE" 'abi_class: typ\.abi_class' \
    "MIR-C99 type plan preserves ABI class"

echo "OK: MIR-C99 error-union type layout metadata verified"
