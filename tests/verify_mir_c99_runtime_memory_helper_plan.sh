#!/usr/bin/env bash
#
# MIR-C99 memory/string runtime helper plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_FILE="$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 runtime memory helper plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$DRIVER_FILE" "$PLAN_FILE" "$MIR_FILE" "$VERIFIER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done
if [[ ! -f "$HELPER_FILE" ]]; then
    echo "error: missing MIR-C99 runtime helper source: $HELPER_FILE" >&2
    exit 1
fi

for symbol in \
    MirC99RuntimeHelperPlan \
    helper_count \
    reject_count \
    mir_c99_runtime_helper_plan_init \
    mir_c99_runtime_helper_plan_build \
    mir_c99_runtime_helper_is_memory_string \
    MIR_RUNTIME_HELPER_MEMCPY \
    MIR_RUNTIME_HELPER_MEMSET \
    MIR_RUNTIME_HELPER_MEMCMP \
    MIR_RUNTIME_HELPER_STRING_PRIMITIVE \
    MIR_RUNTIME_CAP_MEMORY_HELPERS \
    MIR_RUNTIME_CAP_STRING_PRIMITIVES; do
    require_pattern "$HELPER_FILE" "$symbol" "runtime helper symbol $symbol"
done

require_pattern "$HELPER_FILE" 'module\.capability_reqs\.count' \
    "helper plan scans MIR capability requirements"
require_pattern "$HELPER_FILE" 'portable_mir_target_profile_supports_runtime_capability' \
    "helper plan checks target profile capability"
require_pattern "$HELPER_FILE" 'mir_c99_plan_append_ref\(mir_plan,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "helper refs appended to program plan"
require_pattern "$HELPER_FILE" 'mir_c99_unit_append_ref\(unit,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "helper refs appended to unit plan"
require_pattern "$DRIVER_FILE" 'use codegen\.mir_c99\.runtime_helpers' \
    "driver imports runtime helper plan"
require_pattern "$DRIVER_FILE" 'mir_c99_runtime_helper_plan_build' \
    "driver builds runtime helper plan"
require_pattern "$DRIVER_FILE" 'result\.helper_count = runtime_helper_plan\.helper_count' \
    "driver reports runtime helper count"
require_pattern "$PLAN_FILE" 'MIR_C99_REF_KIND_HELPER' \
    "MIR-C99 plan has helper ref kind"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_runtime_helper_capability_id' \
    "PortableMIR verifier validates runtime helper capability ids"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$HELPER_FILE"; then
    echo "error: MIR-C99 runtime helpers must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_runtime_memory_helper_plan.XXXXXX.uya)"
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
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$HELPER_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 memory/string runtime helper plan verified"
