#!/usr/bin/env bash
#
# MIR-C99 call return/out-param lowering plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CALL_FILE="$REPO_ROOT/src/codegen/mir_c99/calls.uya"
PLACE_FILE="$REPO_ROOT/src/codegen/mir_c99/place_memory.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 call return lowering plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CALL_FILE" "$PLACE_FILE" "$VERIFIER_FILE" "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_CALL_RETURN_KIND_VOID \
    MIR_C99_CALL_RETURN_KIND_DIRECT_VALUE \
    MIR_C99_CALL_RETURN_KIND_OUT_PARAM_AGGREGATE \
    return_kind \
    out_param_operand_id \
    out_param_type_id \
    aggregate_return_size_bytes \
    aggregate_return_align_bytes \
    mir_c99_call_return_kind_for_signature \
    mir_c99_call_bind_out_param_return; do
    require_pattern "$CALL_FILE" "$symbol" "return lowering symbol $symbol"
done

require_pattern "$CALL_FILE" 'return_type\.kind == MIR_TYPE_KIND_VOID' \
    "void return recognized"
require_pattern "$CALL_FILE" 'return_type\.kind == MIR_TYPE_KIND_STRUCT' \
    "struct aggregate return type recognized"
require_pattern "$CALL_FILE" 'return_type\.kind == MIR_TYPE_KIND_UNION' \
    "union aggregate return type recognized"
require_pattern "$CALL_FILE" 'MIR_CALL_FLAG_AGGREGATE_RETURN' \
    "aggregate return ABI flag consumed"
require_pattern "$CALL_FILE" 'MIR_CALL_FLAG_OUT_PARAM_WRITEBACK' \
    "out-param writeback flag consumed"
require_pattern "$CALL_FILE" 'out_param\.flags & MIR_CALL_FLAG_OUT_PARAM_WRITEBACK' \
    "out-param operand writeback metadata consumed"
require_pattern "$CALL_FILE" 'pointer_type\.pointee_type_id != return_type\.type_id' \
    "out-param pointee must match aggregate return type"
require_pattern "$CALL_FILE" 'aggregate_return_size_bytes = return_type\.size_bytes' \
    "aggregate return size captured"
require_pattern "$CALL_FILE" 'aggregate_return_align_bytes = return_type\.align_bytes' \
    "aggregate return alignment captured"
require_pattern "$CALL_FILE" 'return MIR_C99_CALL_STATUS_REJECT' \
    "invalid return/out-param metadata rejects"
require_pattern "$PLACE_FILE" 'MIR_C99_MEMORY_OP_FLAG_MEMCPY_HELPER' \
    "place/memory plan already exposes aggregate copy helper path"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_call_out_param_writeback' \
    "PortableMIR verifier validates out-param writeback"
require_pattern "$MIR_FILE" 'MIR_CALL_FLAG_AGGREGATE_RETURN' \
    "PortableMIR exposes aggregate return flag"
require_pattern "$MIR_FILE" 'MIR_ABI_CLASS_OUT_PARAM_POINTER' \
    "PortableMIR exposes out-param ABI class"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CALL_FILE"; then
    echo "error: MIR-C99 calls must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_call_return_lowering_plan.XXXXXX.uya)"
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
    "$CALL_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/driver.uya" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 call return/out-param lowering plan verified"
