#!/usr/bin/env bash
#
# MIR-C99 literal/zero/null constant mapping verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALUE_FILE="$REPO_ROOT/src/codegen/mir_c99/values.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 constant plan missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$VALUE_FILE" "$DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99ConstantEntry \
    MIR_C99_CONSTANT_KIND_I32_LITERAL \
    MIR_C99_CONSTANT_KIND_ZERO \
    MIR_C99_CONSTANT_KIND_NULL \
    mir_c99_value_plan_build_constants \
    mir_c99_value_plan_constant_ptr; do
    require_pattern "$VALUE_FILE" "$symbol" "constant symbol $symbol"
done

require_pattern "$VALUE_FILE" 'constants:[[:space:]]*SemanticVector' \
    "value plan carries constant table"
require_pattern "$VALUE_FILE" 'constant_count:[[:space:]]*usize' \
    "value plan reports constant count"
require_pattern "$VALUE_FILE" 'while i < module\.operands\.count' \
    "all MIR operands scanned"
require_pattern "$VALUE_FILE" 'operand_id:[[:space:]]*MirOperandId' \
    "MIR operand id captured"
require_pattern "$VALUE_FILE" 'immediate_i32:[[:space:]]*i32' \
    "literal i32 payload captured"
require_pattern "$VALUE_FILE" 'value_id == MIR_VALUE_INVALID_ID' \
    "literal operand requires no value def"
require_pattern "$VALUE_FILE" 'local_id == MIR_LOCAL_INVALID_ID' \
    "literal operand requires no local ref"
require_pattern "$VALUE_FILE" 'MIR_TYPE_KIND_I32' \
    "i32 literal type handled"
require_pattern "$VALUE_FILE" 'MIR_TYPE_KIND_POINTER' \
    "pointer null type handled"
require_pattern "$VALUE_FILE" 'immediate_i32 == 0' \
    "zero/null immediate recognized"
require_pattern "$DRIVER_FILE" 'mir_c99_value_plan_build_constants' \
    "driver builds constant plan"
require_pattern "$DRIVER_FILE" 'result\.value_count = value_plan\.count' \
    "driver keeps value count reporting stable"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$VALUE_FILE"; then
    echo "error: MIR-C99 constants must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_constant_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$VALUE_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 literal/zero/null constant plan verified"
