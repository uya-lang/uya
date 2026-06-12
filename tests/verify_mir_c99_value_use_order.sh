#!/usr/bin/env bash
#
# MIR-C99 value use order relies on PortableMIR verifier-clean input.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
VALUE_FILE="$REPO_ROOT/src/codegen/mir_c99/values.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 value use order missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$VERIFIER_FILE" "$DRIVER_FILE" "$VALUE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$VERIFIER_FILE" 'fn portable_mir_verify_operand_use' \
    "verifier checks operand value uses"
require_pattern "$VERIFIER_FILE" 'value\.defining_inst_id == MIR_INST_INVALID_ID' \
    "undefined value definitions rejected"
require_pattern "$VERIFIER_FILE" 'value\.defining_inst_id >= inst\.inst_id' \
    "future value definitions rejected"
require_pattern "$VERIFIER_FILE" 'value\.block_id != inst\.block_id' \
    "cross-block value uses rejected"
require_pattern "$VERIFIER_FILE" 'MIR_VERIFY_ERR_UNDEFINED_USE' \
    "undefined/cross-block use uses stable verifier diagnostic"
require_pattern "$DRIVER_FILE" 'portable_mir_backend_request_is_verified\(request\)[[:space:]]*==[[:space:]]*0' \
    "MIR-C99 driver rejects unverified request"
require_pattern "$VALUE_FILE" 'defining_inst_id:[[:space:]]*MirInstId' \
    "value plan records defining inst id"
require_pattern "$VALUE_FILE" 'block_id:[[:space:]]*MirBlockId' \
    "value plan records defining block id"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$VALUE_FILE"; then
    echo "error: MIR-C99 value order plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_value_use_order.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$VALUE_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 value use order is guarded by PortableMIR verifier"
