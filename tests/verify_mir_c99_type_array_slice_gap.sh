#!/usr/bin/env bash
#
# MIR-C99 array/slice type gap verifier.

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

missing_mir_kind='MIR_TYPE_KIND_(ARRAY|SLICE)'
missing_c_kind='MIR_C99_C_TYPE_KIND_(ARRAY|SLICE)'

if grep -Eq "$missing_mir_kind" "$MIR_FILE" "$VERIFIER_FILE"; then
    echo "error: PortableMIR gained array/slice type kinds; implement MIR-C99 array/slice typedef support and update TODO evidence" >&2
    grep -En "$missing_mir_kind" "$MIR_FILE" "$VERIFIER_FILE" >&2
    exit 1
fi

if grep -Eq "$missing_mir_kind|$missing_c_kind" "$TYPE_FILE"; then
    echo "error: MIR-C99 type plan claims unsupported array/slice type coverage; update verifier and implementation together" >&2
    grep -En "$missing_mir_kind|$missing_c_kind" "$TYPE_FILE" >&2
    exit 1
fi

if ! grep -Eq 'element_type_id:[[:space:]]*MirTypeId' "$MIR_FILE"; then
    echo "error: PortableMIR type metadata no longer exposes element_type_id; revisit array/slice gap evidence" >&2
    exit 1
fi

if ! grep -Eq 'element_type_id: typ\.element_type_id' "$TYPE_FILE"; then
    echo "error: MIR-C99 type plan no longer preserves element_type_id metadata; revisit array/slice gap evidence" >&2
    exit 1
fi

echo "OK: MIR-C99 array/slice type gap recorded; element metadata exists without array/slice type kinds"
