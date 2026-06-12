#!/usr/bin/env bash
#
# MIR-C99 scalar type typedef mapping verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 scalar type plan missing evidence: $description" >&2
        exit 1
    fi
}

if [[ ! -f "$TYPE_FILE" ]]; then
    echo "error: missing MIR-C99 type source: $TYPE_FILE" >&2
    exit 1
fi
if [[ ! -f "$MIR_FILE" ]]; then
    echo "error: missing PortableMIR source: $MIR_FILE" >&2
    exit 1
fi
if [[ ! -f "$DRIVER_FILE" ]]; then
    echo "error: missing MIR-C99 driver source: $DRIVER_FILE" >&2
    exit 1
fi

for symbol in \
    MirC99TypeDef \
    MirC99TypePlan \
    MIR_C99_C_TYPE_KIND_BOOL \
    MIR_C99_C_TYPE_KIND_I32 \
    MIR_C99_C_TYPE_KIND_USIZE \
    mir_c99_type_plan_build \
    mir_c99_type_plan_entry_ptr; do
    require_pattern "$TYPE_FILE" "$symbol" "type symbol $symbol"
done

require_pattern "$MIR_FILE" 'MIR_TYPE_KIND_BOOL' \
    "PortableMIR bool type kind exists"
require_pattern "$MIR_FILE" 'MIR_TYPE_KIND_I32' \
    "PortableMIR i32 type kind exists"
require_pattern "$MIR_FILE" 'MIR_TYPE_KIND_USIZE' \
    "PortableMIR usize type kind exists"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_BOOL' \
    "bool type kind mapped"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_I32' \
    "i32 type kind mapped"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_USIZE' \
    "usize type kind mapped"
require_pattern "$TYPE_FILE" 'c_kind = MIR_C99_C_TYPE_KIND_BOOL' \
    "bool C type kind assigned"
require_pattern "$TYPE_FILE" 'c_kind = MIR_C99_C_TYPE_KIND_I32' \
    "i32 C type kind assigned"
require_pattern "$TYPE_FILE" 'c_kind = MIR_C99_C_TYPE_KIND_USIZE' \
    "usize C type kind assigned"
require_pattern "$TYPE_FILE" 'size_bytes:[[:space:]]*usize' \
    "type size metadata captured"
require_pattern "$TYPE_FILE" 'align_bytes:[[:space:]]*usize' \
    "type align metadata captured"
require_pattern "$TYPE_FILE" 'while i < module\.types\.count' \
    "all MIR types scanned"
require_pattern "$DRIVER_FILE" 'use codegen\.mir_c99\.types' \
    "driver imports type plan"
require_pattern "$DRIVER_FILE" 'mir_c99_type_plan_build' \
    "driver builds type plan"
require_pattern "$DRIVER_FILE" 'result\.type_count = type_plan\.count' \
    "driver reports type count"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$TYPE_FILE"; then
    echo "error: MIR-C99 types must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_type_scalar_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 scalar type typedef plan verified"
