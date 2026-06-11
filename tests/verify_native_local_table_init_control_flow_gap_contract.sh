#!/usr/bin/env bash

# Phase 10：固定 native_build_local_table_init(...)
# 完整迁入前必须先补 while/control-flow surface，不得用单 return 伪装完成。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$SUBSET_DOC" "$TODO_DOC" "$CORE_FILE" "$MIR_FILE" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'native_build_local_table_init\(\.\.\.\).*loop/control-flow 缺口' \
    "todo 缺少 local_table_init control-flow gap 前置任务"
require_pattern "$TODO_DOC" '不得用 noop/单 return 伪装完成' \
    "todo 缺少禁止伪完成说明"
require_pattern "$SUBSET_DOC" '^## `native_build_local_table_init\(\.\.\.\)` Control-Flow Gap Contract' \
    "subset doc 缺少 local_table_init control-flow gap 合同"
require_pattern "$SUBSET_DOC" 'CoreIR 当前没有 `CORE_STMT_KIND_WHILE`' \
    "subset doc 缺少 CoreIR while 缺口"
require_pattern "$SUBSET_DOC" 'PortableMIR generic lowering 当前只接受 call expr statements 和 final return' \
    "subset doc 缺少 PortableMIR generic lowering 缺口"
require_pattern "$SUBSET_DOC" '不得把 `native_build_local_table_init\(\.\.\.\)` 降成 noop、单 return empty table 或 pending body complete 假阳性' \
    "subset doc 缺少禁止伪完成规则"
require_pattern "$SUBSET_DOC" '必须先引入可验证的 while/control-flow surface' \
    "subset doc 缺少 while/control-flow 前置要求"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_ASSIGN' \
    "CoreIR 缺少当前 statement kind baseline"
if grep -Eq 'CORE_STMT_KIND_WHILE' "$CORE_FILE"; then
    echo "错误: CoreIR 已出现 CORE_STMT_KIND_WHILE，请更新本 gap 合同为 while surface 验证" >&2
    exit 1
fi
require_pattern "$MIR_FILE" 'portable_mir_lower_stmt_to_module' \
    "PortableMIR 缺少 generic stmt lowering 入口"
require_pattern "$MIR_FILE" 'if stmt.kind == CORE_STMT_KIND_EXPR' \
    "PortableMIR generic lowering baseline 不再只显式接受 expr stmt"
require_pattern "$MIR_FILE" 'if current_stmt.kind == CORE_STMT_KIND_RETURN' \
    "PortableMIR generic lowering baseline 缺少 final return"
require_pattern "$STAGE1_TEST" 'verify_native_local_table_init_control_flow_gap_contract\.sh' \
    "stage1 未纳入 local_table_init control-flow gap 合同"

echo "verify_native_local_table_init_control_flow_gap_contract: ok"
