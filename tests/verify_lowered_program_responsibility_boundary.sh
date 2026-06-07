#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
WHITEPAPER_FILE="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: LoweredProgram 职责边界缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$LOWER_CORE_FILE" "$MIR_FILE" "$WHITEPAPER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

actual_fields="$(awk '
    /^export struct LoweredProgram[[:space:]]*\{/ { in_struct = 1; next }
    in_struct && /^\}/ { exit }
    in_struct && /^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:/ {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        sub(/:.*/, "", line)
        print line
    }
' "$LOWER_CORE_FILE")"

expected_fields="$(cat <<'EOF'
arena
function_count
global_count
type_count
interface_count
err_union_count
async_frame_count
drop_defer_count
helper_count
work_item_count
body_op_count
core_body_count
core_stmt_count
core_expr_count
core_place_count
core_cleanup_edge_count
core_semantic_fact_count
estimated_bytes
resident_peak_bytes
lifecycle_state
functions
body_ops
core_bodies
core_stmts
core_exprs
core_places
core_cleanup_edges
core_semantic_facts
globals
types
interfaces
err_unions
async_frames
drop_defer_plans
helpers
worklist
EOF
)"

if [[ "$actual_fields" != "$expected_fields" ]]; then
    echo "错误: LoweredProgram 字段清单已变化；新增职责需先更新边界合同和本门禁。" >&2
    diff -u <(printf "%s\n" "$expected_fields") <(printf "%s\n" "$actual_fields") >&2 || true
    exit 1
fi

for field in functions globals types interfaces err_unions async_frames drop_defer_plans helpers worklist; do
    require_pattern "$WHITEPAPER_FILE" "\`${field}\`" "白皮书定义 $field 职责"
done

require_pattern "$WHITEPAPER_FILE" 'stable symbol order.*lowered_program_sort_stable' "stable symbol order 由 lowered_program_sort_stable 统一"
require_pattern "$WHITEPAPER_FILE" 'LoweredProgram.*不拥有低级 CFG/value/local/inst/terminator' "LoweredProgram 不拥有低级 CFG/value/local/inst/terminator"
require_pattern "$WHITEPAPER_FILE" 'PortableMIR.*低级函数体形态' "PortableMIR 拥有低级函数体形态"
require_pattern "$WHITEPAPER_FILE" 'LoweredBodyOp' "白皮书提到 LoweredBodyOp 过渡输入"
require_pattern "$WHITEPAPER_FILE" 'transition / legacy-only' "LoweredBodyOp 保持 transition / legacy-only"

for api in \
    lowered_program_sort_functions \
    lowered_program_sort_globals \
    lowered_program_sort_types \
    lowered_program_sort_interfaces \
    lowered_program_sort_err_unions \
    lowered_program_sort_async_frames \
    lowered_program_sort_drop_defer_plans \
    lowered_program_sort_helpers \
    lowered_program_sort_work_items \
    lowered_program_sort_stable; do
    require_pattern "$LOWER_CORE_FILE" "$api" "稳定排序 API $api"
done

for forbidden in \
    'blocks:[[:space:]]*SemanticVector' \
    'values:[[:space:]]*SemanticVector' \
    'locals:[[:space:]]*SemanticVector' \
    'insts:[[:space:]]*SemanticVector' \
    'terminators:[[:space:]]*SemanticVector' \
    'operands:[[:space:]]*SemanticVector' \
    'successors:[[:space:]]*SemanticVector'; do
    if awk '
        /^export struct LoweredProgram[[:space:]]*\{/ { in_struct = 1; next }
        in_struct && /^\}/ { exit }
        in_struct { print }
    ' "$LOWER_CORE_FILE" | grep -Eq "$forbidden"; then
        echo "错误: 低级 MIR 表不能回流进 LoweredProgram: $forbidden" >&2
        exit 1
    fi
done

for mir_struct in MirBlock MirValue MirLocal MirInst MirTerminator MirOperand MirSuccessor PortableMirModule; do
    require_pattern "$MIR_FILE" "export struct ${mir_struct}" "PortableMIR 定义 $mir_struct"
done

echo "✓ LoweredProgram responsibility boundary verified"
