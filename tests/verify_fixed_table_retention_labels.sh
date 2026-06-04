#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"

require_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 旧固定表保留标注缺少证据: $description" >&2
        return 1
    fi
}

require_pattern "旧固定表临时保留标注" "$ARCH_DOC" "架构文档必须有专门保留标注小节"
require_pattern "不计入[[:space:]]*1 秒硬路径成功" "$ARCH_DOC" "旧固定表不得计入 1 秒 hard path"
require_pattern "oracle|fallback" "$ARCH_DOC" "旧固定表必须标注 oracle/fallback 角色"
require_pattern "src/main\\.uya.*(fallback|legacy|旧驱动)" "$ARCH_DOC" "main 输入图固定表保留角色"
require_pattern "src/codegen/c99/.*(oracle|fallback|legacy)" "$ARCH_DOC" "C99 固定表保留角色"
require_pattern "src/checker/.*(oracle|fallback|legacy)" "$ARCH_DOC" "checker 固定表保留角色"
require_pattern "src/exec/.*(fallback|staged|legacy)" "$ARCH_DOC" "exec 固定表保留角色"
require_pattern "tests/verify_fixed_table_retention_labels\\.sh" "$TODO_DOC" "TODO 验证块必须包含本门禁"

echo "✓ 旧固定表临时保留均有 oracle/fallback 标注"
