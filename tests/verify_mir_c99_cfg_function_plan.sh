#!/usr/bin/env bash
#
# MIR-C99 CFG function mapping verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 CFG function plan missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$CFG_FILE" "$DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$CFG_FILE" 'export struct MirC99FunctionPlanEntry' "function plan entry"
require_pattern "$CFG_FILE" 'function_id:[[:space:]]*MirFunctionId' "MIR function id captured"
require_pattern "$CFG_FILE" 'signature_type_id:[[:space:]]*MirTypeId' "signature type id captured"
require_pattern "$CFG_FILE" 'block_start:[[:space:]]*i32' "block range captured"
require_pattern "$CFG_FILE" 'entry_block_id:[[:space:]]*MirBlockId' "entry block captured"
require_pattern "$CFG_FILE" 'mir_c99_plan_append_ref\(output_plan,[[:space:]]*MIR_C99_REF_KIND_FUNCTION' "program function ref registered"
require_pattern "$CFG_FILE" 'mir_c99_unit_append_ref\(unit,[[:space:]]*MIR_C99_REF_KIND_FUNCTION' "unit function ref registered"
require_pattern "$CFG_FILE" 'while i < module\.functions\.count' "all MIR functions scanned"
require_pattern "$DRIVER_FILE" 'use codegen\.mir_c99\.cfg' "driver imports CFG plan"
require_pattern "$DRIVER_FILE" 'cfg_plan:[[:space:]]*&MirC99CfgPlan' "driver accepts CFG plan"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_functions' "driver builds function mapping"
require_pattern "$DRIVER_FILE" 'result\.function_count = cfg_plan\.function_count' "driver reports function count"

tmp="$(mktemp /tmp/mir_c99_cfg_function_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$CFG_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 function-to-C-function plan verified"
