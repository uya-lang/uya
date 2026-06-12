#!/usr/bin/env bash
#
# MIR-C99 must reject unverified PortableMIR before any C output path is opened.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
EMITTER_FILE="$REPO_ROOT/src/codegen/mir_c99/emitter.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 unverified reject contract missing evidence: $description" >&2
        exit 1
    fi
}

require_before() {
    local file="$1"
    local first="$2"
    local second="$3"
    local description="$4"
    local first_line second_line
    first_line="$(grep -En "$first" "$file" | head -n 1 | cut -d: -f1 || true)"
    second_line="$(grep -En "$second" "$file" | head -n 1 | cut -d: -f1 || true)"
    if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
        echo "error: MIR-C99 unverified reject contract missing ordering: $description" >&2
        exit 1
    fi
}

for file in "$DRIVER_FILE" "$EMITTER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$DRIVER_FILE" 'MIR_C99_DRIVER_DIAG_UNVERIFIED_REQUEST' \
    "driver has stable unverified diagnostic"
require_pattern "$EMITTER_FILE" 'MIR_C99_EMITTER_DIAG_UNVERIFIED_REQUEST' \
    "emitter has stable unverified diagnostic"
require_pattern "$DRIVER_FILE" 'portable_mir_backend_request_is_verified\(request\)[[:space:]]*==[[:space:]]*0' \
    "driver rejects verifier-failed request"
require_pattern "$EMITTER_FILE" 'portable_mir_backend_request_is_verified\(request\)[[:space:]]*==[[:space:]]*0' \
    "emitter rejects verifier-failed request"
require_pattern "$DRIVER_FILE" 'result\.output_bytes = 0usize' \
    "driver initializes output bytes to zero before rejection"
require_pattern "$EMITTER_FILE" 'emitter\.output_bytes = 0usize' \
    "emitter resets output bytes to zero before rejection"
require_before "$DRIVER_FILE" 'portable_mir_backend_request_is_verified\(request\)[[:space:]]*==[[:space:]]*0' \
    'mir_c99_plan_init' "driver rejects before initializing MIR-C99 plan"
require_before "$EMITTER_FILE" 'portable_mir_backend_request_is_verified\(request\)[[:space:]]*==[[:space:]]*0' \
    'emitter\.request = request' "emitter rejects before accepting request"

tmp="$(mktemp /tmp/mir_c99_reject_unverified.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$EMITTER_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 rejects unverified PortableMIR before C output"
