#!/usr/bin/env bash
#
# MIR-C99 arithmetic/comparison expression mapping verifier.

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
        echo "error: MIR-C99 expression plan missing evidence: $description" >&2
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
    MirC99ExpressionEntry \
    MIR_C99_EXPR_KIND_I32_ADD \
    MIR_C99_EXPR_KIND_I32_LE \
    MIR_C99_EXPR_KIND_INT_ARITH \
    MIR_C99_EXPR_KIND_INT_COMPARE \
    MIR_C99_EXPR_KIND_INT_UNARY \
    MIR_C99_EXPR_KIND_BOOL_LOGIC \
    MIR_C99_EXPR_KIND_CONVERSION \
    MIR_C99_EXPR_KIND_FLOAT_ARITH \
    MIR_C99_EXPR_KIND_FLOAT_COMPARE \
    MIR_C99_CONSTANT_KIND_F32_LITERAL \
    MIR_C99_CONSTANT_KIND_F64_LITERAL \
    mir_c99_value_plan_build_expressions \
    mir_c99_value_plan_expression_ptr; do
    require_pattern "$VALUE_FILE" "$symbol" "expression symbol $symbol"
done

require_pattern "$VALUE_FILE" 'expressions:[[:space:]]*SemanticVector' \
    "value plan carries expression table"
require_pattern "$VALUE_FILE" 'expression_count:[[:space:]]*usize' \
    "value plan reports expression count"
require_pattern "$VALUE_FILE" 'while i < module\.insts\.count' \
    "all MIR instructions scanned"
require_pattern "$VALUE_FILE" 'inst_id:[[:space:]]*MirInstId' \
    "MIR inst id captured"
require_pattern "$VALUE_FILE" 'result_value_id:[[:space:]]*MirValueId' \
    "result value id captured"
require_pattern "$VALUE_FILE" 'lhs_operand_id:[[:space:]]*MirOperandId' \
    "lhs operand id captured"
require_pattern "$VALUE_FILE" 'rhs_operand_id:[[:space:]]*MirOperandId' \
    "rhs operand id captured"
require_pattern "$VALUE_FILE" 'MIR_INST_OP_I32_ADD' \
    "i32 add opcode handled"
require_pattern "$VALUE_FILE" 'MIR_INST_OP_I32_LE' \
    "i32 <= opcode handled"
require_pattern "$VALUE_FILE" 'portable_mir_inst_op_is_integer_arithmetic' \
    "integer arithmetic opcode family handled"
require_pattern "$VALUE_FILE" 'portable_mir_inst_op_is_integer_compare' \
    "integer comparison opcode family handled"
require_pattern "$VALUE_FILE" 'portable_mir_inst_op_is_integer_unary' \
    "integer unary opcode family handled"
require_pattern "$VALUE_FILE" 'portable_mir_inst_op_is_logic' \
    "bool logic opcode family handled"
require_pattern "$VALUE_FILE" 'portable_mir_inst_op_is_conversion' \
    "conversion opcode family handled"
require_pattern "$VALUE_FILE" 'portable_mir_inst_op_is_float_arithmetic' \
    "float arithmetic opcode family handled"
require_pattern "$VALUE_FILE" 'portable_mir_inst_op_is_float_compare' \
    "float comparison opcode family handled"
require_pattern "$VALUE_FILE" 'MIR_TYPE_KIND_F32' \
    "f32 constant type recognized"
require_pattern "$VALUE_FILE" 'MIR_TYPE_KIND_F64' \
    "f64 constant type recognized"
require_pattern "$VALUE_FILE" 'immediate_i32 == 0' \
    "float constant payload zero boundary checked"
if ! awk '
    /fn mir_c99_constant_kind_for_operand/ { in_fn = 1 }
    in_fn && /MIR_C99_CONSTANT_KIND_F32_LITERAL/ { f32 = NR }
    in_fn && /MIR_C99_CONSTANT_KIND_ZERO/ && zero == 0 { zero = NR }
    in_fn && /^}/ { in_fn = 0 }
    END { exit !(f32 > 0 && zero > 0 && f32 < zero) }
' "$VALUE_FILE"; then
    echo "error: MIR-C99 float literal kind must be selected before generic zero" >&2
    exit 1
fi
require_pattern "$VALUE_FILE" 'operand_count == 2' \
    "binary expression requires two operands"
require_pattern "$VALUE_FILE" 'operand_count == 1' \
    "unary expression requires one operand"
require_pattern "$VALUE_FILE" 'result_value_id == MIR_VALUE_INVALID_ID' \
    "binary expression requires result value"
require_pattern "$DRIVER_FILE" 'mir_c99_value_plan_build_expressions' \
    "driver builds expression plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$VALUE_FILE"; then
    echo "error: MIR-C99 expressions must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_expression_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 value expression plan verified"
