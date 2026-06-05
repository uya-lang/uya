#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
AST_FILE="$REPO_ROOT/src/ast.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
TYPED_ASSIGN_FILE="$REPO_ROOT/src/typed/assign.uya"
CHECKER_ENTRY_FILE="$REPO_ROOT/src/checker/check_expr_extra.uya"
CHECKER_TYPES_FILE="$REPO_ROOT/src/checker/types.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: TypedProgram ExprId 分配缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$AST_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$TYPED_ASSIGN_FILE" "$CHECKER_ENTRY_FILE" "$CHECKER_TYPES_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$AST_FILE" 'expr_id:[[:space:]]*i32' "ASTNode 持有 ExprId 字段"
require_pattern "$AST_FILE" 'node\.expr_id[[:space:]]*=[[:space:]]*-1' "ast_new_node 初始化 ExprId"
require_pattern "$TYPED_ASSIGN_FILE" 'typed_program_assign_expr_ids' "稳定 ExprId 分配入口"
require_pattern "$TYPED_ASSIGN_FILE" 'typed_program_walk_ast_expr_ids' "AST 前序遍历"
require_pattern "$TYPED_ASSIGN_FILE" 'typed_program_reserve_exprs' "ExprId 分配后预留 TypedProgram 表容量"
require_pattern "$CHECKER_TYPES_FILE" 'typed_program:[[:space:]]*TypedProgram' "TypeChecker 持有 TypedProgram"
require_pattern "$CHECKER_ENTRY_FILE" 'typed_program_assign_expr_ids\(&checker\.typed_program, ast_ptr\)' "checker 在宏展开后分配 ExprId"

tmp_dir="$(mktemp -d /tmp/uya-typed-expr-ids.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" >"$tmp_dir/main.uya"
cat "$AST_FILE" >>"$tmp_dir/main.uya"
cat "$TABLE_FILE" >>"$tmp_dir/main.uya"
cat "$IDS_FILE" >>"$tmp_dir/main.uya"
cat "$TYPED_PROGRAM_FILE" >>"$tmp_dir/main.uya"
cat "$TYPED_ASSIGN_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn typed_expr_test_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        identifier_bindings: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        call_targets: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        method_dispatch: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        field_access: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        global_init_order: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        reachable_roots: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
        proof_results: SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize, bytes: 0usize, realloc_count: 0 },
    };
}

test "typed program assigns stable preorder expr ids" {
    var buffer: [byte: 4096] = [];
    var arena: CompilerArena = CompilerArena{
        buffer: null,
        size: 0usize,
        offset: 0usize,
        first_chunk: null,
        current_chunk: null,
        total_allocated: 0usize,
        peak_allocated: 0usize,
    };
    compiler_arena_init(&arena, &buffer[0], @len(buffer) as usize);

    const program_node: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "expr_ids.uya");
    const fn_node: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "expr_ids.uya");
    const block_node: &ASTNode = ast_new_node(ASTNodeType.AST_BLOCK, 1, 10, &arena, "expr_ids.uya");
    const return_node: &ASTNode = ast_new_node(ASTNodeType.AST_RETURN_STMT, 2, 5, &arena, "expr_ids.uya");
    const number_node: &ASTNode = ast_new_node(ASTNodeType.AST_NUMBER, 2, 12, &arena, "expr_ids.uya");

    var decls: [&ASTNode: 1] = [];
    var stmts: [&ASTNode: 1] = [];
    decls[0] = fn_node;
    stmts[0] = return_node;
    program_node.program_decls = &decls[0] as & & ASTNode;
    program_node.program_decl_count = 1;
    fn_node.fn_decl_body = block_node;
    block_node.block_stmts = &stmts[0] as & & ASTNode;
    block_node.block_stmt_count = 1;
    return_node.return_stmt_expr = number_node;
    number_node.number_value = 42;

    var typed: TypedProgram = typed_expr_test_program();
    typed_program_init(&typed);
    try assert_eq_i32(typed_program_assign_expr_ids(&typed, program_node), 0);
    try assert_eq_i32(typed_program_lifecycle_state(&typed), TYPED_PROGRAM_LIFECYCLE_ACTIVE);
    try assert_eq_i32(program_node.expr_id, 0);
    try assert_eq_i32(fn_node.expr_id, 1);
    try assert_eq_i32(block_node.expr_id, 2);
    try assert_eq_i32(return_node.expr_id, 3);
    try assert_eq_i32(number_node.expr_id, 4);
    try assert_eq_i32(typed.expr_count, 5);
    try assert_eq_i32(typed.expr_types.capacity >= 5usize, true);

    number_node.expr_id = 99;
    try assert_eq_i32(typed_program_assign_expr_ids(&typed, program_node), 0);
    try assert_eq_i32(number_node.expr_id, 4);
    try assert_eq_i32(typed.expr_count, 5);
    typed_program_release(&typed);
    try assert_eq_i32(typed_program_lifecycle_state(&typed), TYPED_PROGRAM_LIFECYCLE_RELEASED);
    try assert_eq_i32(typed_program_peak_bytes(&typed) >= @size_of(TypedProgram), true);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ TypedProgram stable ExprId assignment verified"
