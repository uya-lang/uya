#!/usr/bin/env bash
#
# MIR-C99 scalar type gap verifier.

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

missing_mir_kind='MIR_TYPE_KIND_(I8|U8|I16|U16|U32|I64|U64|ISIZE|BYTE|F32|F64)'
missing_c_kind='MIR_C99_C_TYPE_KIND_(I8|U8|I16|U16|U32|I64|U64|ISIZE|BYTE|F32|F64)'

if grep -Eq "$missing_mir_kind" "$MIR_FILE"; then
    echo "error: PortableMIR gained scalar type kinds; update MIR-C99 scalar typedef implementation and TODO evidence" >&2
    grep -En "$missing_mir_kind" "$MIR_FILE" >&2
    exit 1
fi

if grep -Eq "$missing_mir_kind|$missing_c_kind" "$TYPE_FILE"; then
    echo "error: MIR-C99 type plan claims unsupported scalar type coverage; update verifier and implementation together" >&2
    grep -En "$missing_mir_kind|$missing_c_kind" "$TYPE_FILE" >&2
    exit 1
fi

echo "OK: MIR-C99 scalar type gap recorded for i8/u8/i16/u16/u32/i64/u64/isize/byte/f32/f64"
