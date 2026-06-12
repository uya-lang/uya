#!/usr/bin/env bash
#
# MIR-C99 split unit header/prototype/dependency output verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
OUTPUT_FILE="$REPO_ROOT/src/codegen/mir_c99/unit_output.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 split header/deps plan missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$PLAN_FILE" "$CFG_FILE" "$OUTPUT_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

require_pattern "$PLAN_FILE" 'deps:[[:space:]]*SemanticVector' \
    "unit dependency refs are stored dynamically"
require_pattern "$PLAN_FILE" 'mir_c99_unit_fingerprint_refs\(h,[[:space:]]*&unit\.deps\)' \
    "unit deps participate in structural fingerprint"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_header_guard_begin' \
    "header guard begin writer"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_header_guard_end' \
    "header guard end writer"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_dep_section' \
    "dependency include section writer"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_header_file' \
    "independent header file writer"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_source_header_include' \
    "source unit includes its own header"
require_pattern "$OUTPUT_FILE" 'UYA_MIR_UNIT_' \
    "stable unit header guard prefix"
require_pattern "$OUTPUT_FILE" 'uya_mir_unit_' \
    "stable unit header filename prefix"
require_pattern "$OUTPUT_FILE" 'writer\.unit\.deps' \
    "header writer consumes per-unit deps"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_typedef_section\(writer,[[:space:]]*stream\)' \
    "header file emits typedefs"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_extern_prototype_section\(writer,[[:space:]]*stream\)' \
    "header file emits extern prototypes"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_function_prototype_section\(writer,[[:space:]]*stream\)' \
    "header file emits function prototypes"

if grep -Eq 'c99_write_split_makefile|split_makefile|codegen\.c99|C99CodeGenerator' "$OUTPUT_FILE"; then
    echo "error: MIR-C99 split header writer must not call legacy C99 split writer" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_split_header_deps_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' "$PLAN_FILE" "$CFG_FILE" "$OUTPUT_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 split header/prototype/dependency output plan verified"
