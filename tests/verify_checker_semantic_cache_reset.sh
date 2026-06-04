#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAIN_FILE="$REPO_ROOT/src/main.uya"
CHECKER_TYPES_FILE="$REPO_ROOT/src/checker/types.uya"
CHECKER_SYMBOLS_FILE="$REPO_ROOT/src/checker/symbols.uya"
CHECKER_ENTRY_FILE="$REPO_ROOT/src/checker/check_expr_extra.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: checker SemanticDb cache reset 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$MAIN_FILE" "$CHECKER_TYPES_FILE" "$CHECKER_SYMBOLS_FILE" "$CHECKER_ENTRY_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$MAIN_FILE" "^use[[:space:]]+semantic;" "主编译器导入 semantic 模块"
require_pattern "$CHECKER_TYPES_FILE" "semantic_db:[[:space:]]+SemanticDb" "TypeChecker 持有 SemanticDb cache"
require_pattern "$CHECKER_SYMBOLS_FILE" "fn[[:space:]]+checker_reset_semantic_cache" "checker semantic cache reset helper"
require_pattern "$CHECKER_SYMBOLS_FILE" "semantic_db_init\\(&checker\\.semantic_db\\)" "checker_init 初始化 SemanticDb"
require_pattern "$CHECKER_SYMBOLS_FILE" "semantic_db_reset\\(&checker\\.semantic_db\\)" "checker_init/reset 复用时清空 SemanticDb"
require_pattern "$CHECKER_SYMBOLS_FILE" "checker_reset_semantic_cache\\(checker\\)" "checker_init 调用 semantic cache reset"
require_pattern "$CHECKER_ENTRY_FILE" "checker_reset_semantic_cache\\(checker\\)" "checker_check 入口清空 semantic cache"
require_pattern "$CHECKER_ENTRY_FILE" "semantic_db_build_from_merged_ast\\(&checker\\.semantic_db,[[:space:]]*ast_ptr\\)" "checker_check 使用最终 AST 重建 SemanticDb"

echo "✓ checker SemanticDb cache reset integration verified"
