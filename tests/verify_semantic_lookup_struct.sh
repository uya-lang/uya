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
        echo "错误: Semantic struct lookup 缺少证据: $description" >&2
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
require_pattern "$LOOKUP_FILE" "checker_register_semantic_lookup_db" "checker 注册 SemanticDb lookup 上下文"
require_pattern "$LOOKUP_FILE" "lookup_find_struct_decl_from_semantic_db" "struct SemanticDb 查询 helper"
require_pattern "$LOOKUP_FILE" "semantic_db_find_type_decl_range" "通过 SemanticDb types_by_name 查询 type range"
require_pattern "$LOOKUP_FILE" "semantic_db_type_range_decl_id" "通过 SemanticDb range 读取 DeclId"
require_pattern "$LOOKUP_FILE" "semantic_db_decl_ast_node" "通过 DeclId 读取 AST 节点"
require_pattern "$LOOKUP_FILE" "AST_STRUCT_DECL" "SemanticDb 查询结果过滤为结构体声明"
require_pattern "$LOOKUP_FILE" "lookup_name_matches_exact_or_generic_base" "保留泛型基名匹配语义"
require_pattern "$LOOKUP_FILE" "lookup_find_struct_decl_from_semantic_db\\(program_node, struct_name\\)" "find_struct_decl_from_program 调用 SemanticDb helper"
require_pattern "$CHECKER_ENTRY_FILE" "checker_register_semantic_lookup_db\\(ast_ptr, &checker\\.semantic_db\\)" "SemanticDb 构建完成后注册 lookup 上下文"

"$COMPILER" test "$REPO_ROOT/tests/struct_test.uya" --no-split-c >/tmp/uya-semantic-struct.stdout 2>/tmp/uya-semantic-struct.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_static_method_struct.uya" --no-split-c >/tmp/uya-semantic-static-struct.stdout 2>/tmp/uya-semantic-static-struct.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_generic_multi_instance.uya" --no-split-c >/tmp/uya-semantic-generic-struct.stdout 2>/tmp/uya-semantic-generic-struct.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_async_future_interface_box.uya" --no-split-c >/tmp/uya-semantic-future-struct.stdout 2>/tmp/uya-semantic-future-struct.stderr

echo "✓ SemanticDb struct lookup migration verified"
