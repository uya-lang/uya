#!/usr/bin/env bash
#
# MIR-C99 runtime helper registry boundary verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_FILE="$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 runtime helper registry boundary missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "error: MIR-C99 runtime helper registry boundary found forbidden dependency: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$HELPER_FILE" "$DRIVER_FILE" "$PLAN_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

require_pattern "$HELPER_FILE" 'mir_c99_runtime_helper_plan_build' \
    "runtime helper registry build entry"
require_pattern "$HELPER_FILE" 'module\.capability_reqs\.count' \
    "registry scans MIR capability refs"
require_pattern "$HELPER_FILE" 'module\.insts\.count' \
    "registry scans MIR instruction refs for async helpers"
require_pattern "$HELPER_FILE" 'mir_c99_runtime_helper_capability_req_ptr' \
    "registry reads MirCapabilityReq entries"
require_pattern "$HELPER_FILE" 'mir_c99_runtime_helper_inst_ptr' \
    "registry reads MirInst entries"
require_pattern "$HELPER_FILE" 'mir_c99_plan_append_ref\(mir_plan,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "registry appends helper refs to program plan"
require_pattern "$HELPER_FILE" 'mir_c99_unit_append_ref\(unit,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "registry appends helper refs to unit plan"
require_pattern "$DRIVER_FILE" 'mir_c99_runtime_helper_plan_build' \
    "driver invokes registry build"
require_pattern "$PLAN_FILE" 'MIR_C99_REF_KIND_HELPER' \
    "MIR-C99 plan owns helper ref kind"

reject_pattern "$HELPER_FILE" 'ASTNode|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR or legacy C99 structures in runtime helper registry"
reject_pattern "$HELPER_FILE" 'codegen/c99|codegen\.c99|c99_codegen_generate|helper discovery|AST helper' \
    "legacy C99 helper discovery in runtime helper registry"
reject_pattern "$DRIVER_FILE" 'ASTNode|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR or legacy C99 structures in MIR-C99 driver helper path"

tmp="$(mktemp /tmp/mir_c99_runtime_helper_registry_boundary.XXXXXX.uya)"
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

echo "OK: MIR-C99 runtime helper registry boundary verified"
