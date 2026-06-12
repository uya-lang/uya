#!/usr/bin/env bash
#
# MIR-C99 portable layout compile-time check plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
CONTRACT_DOC="$REPO_ROOT/docs/mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 layout check plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$TYPE_FILE" "$CONTRACT_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_LAYOUT_CHECK_KIND_SIZE \
    MIR_C99_LAYOUT_CHECK_KIND_ALIGN \
    MIR_C99_LAYOUT_CHECK_KIND_OFFSET \
    MIR_C99_LAYOUT_CHECK_FORM_TYPEDEF_CHAR_ARRAY \
    MirC99LayoutCheckEntry \
    layout_checks \
    layout_check_count \
    mir_c99_type_plan_append_layout_check \
    mir_c99_type_plan_layout_check_ptr; do
    require_pattern "$TYPE_FILE" "$symbol" "layout check symbol $symbol"
done

require_pattern "$TYPE_FILE" 'expected_bytes:[[:space:]]*usize' \
    "layout check expected byte count captured"
require_pattern "$TYPE_FILE" 'field_index:[[:space:]]*i32' \
    "field offset check field index captured"
require_pattern "$TYPE_FILE" 'check_form:[[:space:]]*i32' \
    "portable check form captured"
require_pattern "$TYPE_FILE" 'check_form: MIR_C99_LAYOUT_CHECK_FORM_TYPEDEF_CHAR_ARRAY' \
    "layout check uses typedef char array form"
require_pattern "$TYPE_FILE" 'typ\.size_bytes' \
    "type size checks come from MIR layout metadata"
require_pattern "$TYPE_FILE" 'typ\.align_bytes' \
    "type align checks come from MIR layout metadata"
require_pattern "$TYPE_FILE" 'field\.offset_bytes' \
    "field offset checks come from MIR field layout metadata"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_STRUCT \|\|' \
    "aggregate kinds receive layout checks"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_UNION \|\|' \
    "union kind receives layout checks"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_ERROR_UNION' \
    "error-union type receives layout checks"
require_pattern "$CONTRACT_DOC" 'typedef char array' \
    "contract documents portable typedef-char-array check form"

if grep -Eiq '_Static_assert|__attribute__[[:space:]]*\(|__builtin_|typeof[[:space:]]*\(|_Generic' "$TYPE_FILE"; then
    echo "error: MIR-C99 layout checks must not use C11/GNU-only constructs" >&2
    exit 1
fi

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$TYPE_FILE"; then
    echo "error: MIR-C99 layout check plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_type_layout_check_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 portable layout check plan verified"
