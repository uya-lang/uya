#!/usr/bin/env bash
#
# MIR-C99 @c_import/link-input plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
COVERAGE_FILE="$REPO_ROOT/docs/portable_mir_language_coverage.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 link input plan missing evidence: $description" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 link input plan must not use forbidden path: $description" >&2
        exit 1
    fi
}

for file in "$PLAN_FILE" "$DRIVER_FILE" "$COVERAGE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99LinkInputPlanEntry \
    link_inputs \
    mir_c99_link_input_plan_append \
    mir_c99_link_input_plan_build \
    mir_c99_link_input_plan_ptr; do
    require_pattern "$PLAN_FILE" "$symbol" "plan symbol $symbol"
done

require_pattern "$PLAN_FILE" 'MIR_LINK_INPUT_KIND_C_IMPORT_OBJECT' \
    "@c_import object kind is consumed from PortableMIR"
require_pattern "$PLAN_FILE" 'MIR_LINK_INPUT_KIND_OBJECT_FILE' \
    "object file link input kind is preserved"
require_pattern "$PLAN_FILE" 'MIR_LINK_INPUT_KIND_LIBRARY' \
    "library link input kind is preserved for ldflags"
require_pattern "$PLAN_FILE" 'MIR_LINK_INPUT_KIND_SEARCH_PATH' \
    "search path link input kind is preserved for ldflags"
require_pattern "$PLAN_FILE" 'path_dedupe_id: input\.path_dedupe_id' \
    "path/cflags source metadata is captured"
require_pattern "$PLAN_FILE" 'name_dedupe_id: input\.name_dedupe_id' \
    "library/search name metadata is captured"
require_pattern "$PLAN_FILE" 'target_profile_id: input\.target_profile_id' \
    "target profile metadata is captured"
require_pattern "$PLAN_FILE" 'c_import_id: input\.c_import_id' \
    "@c_import source id is captured"
require_pattern "$PLAN_FILE" 'semantic_vector_init\(&plan\.link_inputs, @size_of\(MirC99LinkInputPlanEntry\)\)' \
    "plan link input table is dynamically initialized"
require_pattern "$PLAN_FILE" 'semantic_vector_release\(&plan\.link_inputs\)' \
    "plan link input table is released"
require_pattern "$PLAN_FILE" 'mir_c99_stats_add_vector\(&stats, &plan\.link_inputs\)' \
    "plan stats include link input table"
require_pattern "$PLAN_FILE" 'module\.link_inputs\.count' \
    "build scans PortableMIR link input table"
require_pattern "$DRIVER_FILE" 'mir_c99_link_input_plan_build\(request\.module,[[:space:]]*plan\)' \
    "driver builds link input plan"
require_pattern "$COVERAGE_FILE" '\| `AST_C_IMPORT_DECL` \| done \| partial \|' \
    "coverage marks AST_C_IMPORT_DECL as partial after link plan"
require_pattern "$COVERAGE_FILE" '\| `@c_import` \| done \| partial \|' \
    "coverage marks @c_import as partial after link plan"

reject_pattern "$PLAN_FILE" 'imports\.sh|verify_mir_c99_oracle_parity_harness|c99_oracle_generate|codegen\.c99' \
    "legacy C99 sidecar/oracle implementation"

tmp="$(mktemp /tmp/mir_c99_link_input_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
grep -v '^use ' "$PLAN_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 @c_import/link input plan verified"
