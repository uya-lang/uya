#!/usr/bin/env bash
#
# MIR-C99 scalar type metadata verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"

if [[ ! -f "$MIR_FILE" ]]; then
    echo "error: missing PortableMIR source: $MIR_FILE" >&2
    exit 1
fi
if [[ ! -f "$TYPE_FILE" ]]; then
    echo "error: missing MIR-C99 type source: $TYPE_FILE" >&2
    exit 1
fi

VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 scalar type metadata missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

if [[ ! -f "$VERIFIER_FILE" ]]; then
    echo "error: missing PortableMIR verifier source: $VERIFIER_FILE" >&2
    exit 1
fi

for scalar in I8 U8 I16 U16 U32 I64 U64 ISIZE BYTE F32 F64; do
    require_pattern "$MIR_FILE" "MIR_TYPE_KIND_${scalar}" "PortableMIR scalar kind ${scalar}"
    require_pattern "$TYPE_FILE" "MIR_C99_C_TYPE_KIND_${scalar}" "MIR-C99 scalar C kind ${scalar}"
    require_pattern "$TYPE_FILE" "typ\\.kind == MIR_TYPE_KIND_${scalar}" "MIR-C99 maps scalar ${scalar}"
    require_pattern "$TYPE_FILE" "c_kind = MIR_C99_C_TYPE_KIND_${scalar}" "MIR-C99 assigns scalar C kind ${scalar}"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_expected_scalar_size_align' \
    "verifier has scalar size/align helper"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_I8 \|\| typ\.kind == MIR_TYPE_KIND_U8 \|\| typ\.kind == MIR_TYPE_KIND_BYTE' \
    "verifier groups one-byte scalar layout"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_I16 \|\| typ\.kind == MIR_TYPE_KIND_U16' \
    "verifier groups two-byte scalar layout"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_I32 \|\| typ\.kind == MIR_TYPE_KIND_U32 \|\| typ\.kind == MIR_TYPE_KIND_F32' \
    "verifier groups four-byte scalar layout"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_I64 \|\| typ\.kind == MIR_TYPE_KIND_U64 \|\| typ\.kind == MIR_TYPE_KIND_ISIZE \|\| typ\.kind == MIR_TYPE_KIND_USIZE \|\| typ\.kind == MIR_TYPE_KIND_F64' \
    "verifier groups eight-byte scalar layout"

echo "OK: MIR-C99 scalar type metadata verified for i8/u8/i16/u16/u32/i64/u64/isize/byte/f32/f64"
