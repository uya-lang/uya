#!/usr/bin/env bash
#
# MIR-C99 split unit assignment planner verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 split unit assignment missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$PLAN_FILE" "$CFG_FILE" "$DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

require_pattern "$PLAN_FILE" 'export struct MirC99UnitAssignment' \
    "unit assignment row"
require_pattern "$PLAN_FILE" 'unit_assignments:[[:space:]]*SemanticVector' \
    "plan stores assignment rows dynamically"
require_pattern "$PLAN_FILE" 'semantic_vector_init\(&plan\.unit_assignments,[[:space:]]*@size_of\(MirC99UnitAssignment\)\)' \
    "assignment vector initialized"
require_pattern "$PLAN_FILE" 'mir_c99_plan_find_cross_unit_for_function' \
    "cross-unit symbol assignment source"
require_pattern "$PLAN_FILE" 'module\.cross_unit_symbols\.count' \
    "cross-unit metadata scanned"
require_pattern "$PLAN_FILE" 'mir_c99_plan_debug_loc_source_file_id' \
    "source file assignment source"
require_pattern "$PLAN_FILE" 'module\.debug_locs\.count' \
    "debug loc source files scanned"
require_pattern "$PLAN_FILE" 'MIR_C99_UNIT_KIND_FUNCTION_GROUP' \
    "function-group fallback unit kind"
require_pattern "$PLAN_FILE" 'mir_c99_plan_prepare_function_units' \
    "assignment planner API"
require_pattern "$PLAN_FILE" 'mir_c99_plan_unit_for_function' \
    "function-to-unit lookup API"
require_pattern "$PLAN_FILE" 'while i < module\.functions\.count' \
    "all functions assigned"
require_pattern "$CFG_FILE" 'mir_c99_plan_unit_for_function\(output_plan,[[:space:]]*function\)' \
    "CFG function mapping consumes assignment"
require_pattern "$DRIVER_FILE" 'mir_c99_plan_prepare_function_units\(request\.module,[[:space:]]*plan,[[:space:]]*primary_unit\)' \
    "driver builds assignment plan before CFG function mapping"

tmp="$(mktemp /tmp/mir_c99_split_unit_assignment_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$PLAN_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$CFG_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 split unit assignment plan verified"
