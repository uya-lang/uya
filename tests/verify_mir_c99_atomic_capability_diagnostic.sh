#!/usr/bin/env bash
#
# MIR-C99 atomic capability diagnostic verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALUES_FILE="$REPO_ROOT/src/codegen/mir_c99/values.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 atomic capability diagnostic missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$VALUES_FILE" "$DRIVER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_VALUE_DIAG_UNSUPPORTED_ATOMIC_CAPABILITY \
    MIR_C99_EXPR_REJECT_REASON_ATOMIC_CAPABILITY \
    diagnostic_code \
    reject_reason \
    mir_c99_value_plan_diagnostic_code; do
    require_pattern "$VALUES_FILE" "$symbol" "atomic diagnostic symbol $symbol"
done

require_pattern "$VALUES_FILE" 'MIR_C99_EXPR_KIND_ATOMIC_HELPER' \
    "atomic helper/reject expression kind"
require_pattern "$VALUES_FILE" 'portable_mir_inst_op_is_atomic\(inst\.op\)' \
    "atomic opcode classifier drives diagnostic"
require_pattern "$VALUES_FILE" 'entry\.reject_reason == MIR_C99_EXPR_REJECT_REASON_ATOMIC_CAPABILITY' \
    "atomic reject reason selected from expression entry"
require_pattern "$DRIVER_FILE" 'mir_c99_value_plan_diagnostic_code\(value_plan\)' \
    "driver propagates value plan diagnostic"
require_pattern "$TODO_FILE" 'atomic.*首版.*reject' \
    "todo records current atomic oracle strategy"
require_pattern "$TODO_FILE" 'host C compiler oracle parity' \
    "todo keeps parity requirement explicit"

tmp="$(mktemp /tmp/mir_c99_atomic_capability_diagnostic.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$VALUES_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 atomic capability diagnostic verified"
