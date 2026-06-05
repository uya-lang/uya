#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOOKUP_FILE="$REPO_ROOT/src/checker/lookup.uya"
CHECKER_ENTRY_FILE="$REPO_ROOT/src/checker/check_expr_extra.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: Semantic type alias lookup 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$LOOKUP_FILE" "$CHECKER_ENTRY_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOOKUP_FILE" "g_lookup_semantic_db" "lookup 层持有当前 SemanticDb"
require_pattern "$LOOKUP_FILE" "checker_clear_semantic_lookup_db" "SemanticDb lookup 上下文独立清理"
require_pattern "$LOOKUP_FILE" "checker_register_semantic_lookup_db" "checker 注册 SemanticDb lookup 上下文"
require_pattern "$LOOKUP_FILE" "lookup_find_type_alias_from_semantic_db" "type alias SemanticDb 查询 helper"
require_pattern "$LOOKUP_FILE" "semantic_db_find_type_decl_range" "通过 SemanticDb types_by_name 查询 type range"
require_pattern "$LOOKUP_FILE" "semantic_db_type_range_decl_id" "通过 SemanticDb range 读取 DeclId"
require_pattern "$LOOKUP_FILE" "semantic_db_decl_ast_node" "通过 DeclId 读取 AST 节点"
require_pattern "$LOOKUP_FILE" "lookup_find_type_alias_from_semantic_db\\(program_node, alias_name\\)" "find_type_alias_from_program 调用 SemanticDb helper"
require_pattern "$CHECKER_ENTRY_FILE" "checker_register_semantic_lookup_db\\(ast_ptr, &checker\\.semantic_db\\)" "SemanticDb 构建完成后注册 lookup 上下文"

"$COMPILER" test "$REPO_ROOT/tests/test_type_alias.uya" --no-split-c >/tmp/uya-semantic-type-alias.stdout 2>/tmp/uya-semantic-type-alias.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_static_method_type_alias.uya" --no-split-c >/tmp/uya-semantic-static-type-alias.stdout 2>/tmp/uya-semantic-static-type-alias.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_semantic_lookup_alias_context.uya" --no-split-c >/tmp/uya-semantic-alias-context.stdout 2>/tmp/uya-semantic-alias-context.stderr

echo "✓ SemanticDb type alias lookup migration verified"
