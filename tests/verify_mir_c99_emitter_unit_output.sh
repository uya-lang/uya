#!/usr/bin/env bash
#
# MIR-C99 emitter must account for single-C unit output without legacy fallback.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EMITTER_FILE="$REPO_ROOT/src/codegen/mir_c99/emitter.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 emitter unit output missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$EMITTER_FILE" "$DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$EMITTER_FILE" 'use codegen\.mir_c99\.unit_output' \
    "emitter consumes unit output writer"
require_pattern "$EMITTER_FILE" 'cfg_plan:[[:space:]]*&MirC99CfgPlan' \
    "emitter carries CFG plan"
require_pattern "$EMITTER_FILE" 'mir_c99_emitter_bind_cfg' \
    "emitter exposes CFG binding"
require_pattern "$EMITTER_FILE" 'mir_c99_unit_output_writer_begin' \
    "emitter starts unit output writer"
require_pattern "$EMITTER_FILE" 'mir_c99_unit_output_writer_bind_cfg' \
    "emitter binds unit output writer to CFG"
require_pattern "$EMITTER_FILE" 'mir_c99_unit_output_writer_finish' \
    "emitter records unit output bytes"
require_pattern "$EMITTER_FILE" 'emitter\.output_bytes = emitter\.output_bytes \+ written' \
    "emitter accumulates output bytes"
require_pattern "$EMITTER_FILE" 'emitter\.status = MIR_C99_EMITTER_STATUS_DONE' \
    "emitter reaches done after unit output accounting"
require_pattern "$DRIVER_FILE" 'mir_c99_emitter_bind_cfg' \
    "driver binds CFG into emitter"
require_pattern "$DRIVER_FILE" 'mir_c99_emitter_record_unit_outputs' \
    "driver records single-C unit outputs before result"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' "$EMITTER_FILE" "$DRIVER_FILE"; then
    echo "error: MIR-C99 emitter/driver must not use legacy C99 fallback" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_emitter_unit_output.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$EMITTER_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 emitter records single-C unit output without fallback"
