#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
DB_FILE="$REPO_ROOT/src/semantic/db.uya"
BUILD_FILE="$REPO_ROOT/src/semantic/build.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$BUILD_FILE"; then
        echo "错误: SemanticDb build 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "semantic_db_build_from_merged_ast" "merged AST build API"
require_pattern "ASTNodeType\\.AST_PROGRAM" "AST_PROGRAM 校验"
require_pattern "program_decl_count" "顶层声明扫描"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-smoke.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

enum ASTNodeType {
    AST_PROGRAM,
    AST_ENUM_DECL,
    AST_ERROR_DECL,
    AST_INTERFACE_DECL,
    AST_STRUCT_DECL,
    AST_UNION_DECL,
    AST_METHOD_BLOCK,
    AST_FN_DECL,
    AST_MACRO_DECL,
    AST_TYPE_ALIAS,
    AST_VAR_DECL,
    AST_EXTERN_VAR_DECL,
    AST_USE_STMT,
    AST_C_IMPORT_DECL,
}

struct ASTNode {
    type: ASTNodeType,
    filename: &byte,
    program_decls: & & ASTNode,
    program_decl_count: i32,
    enum_decl_name: &byte,
    enum_decl_variant_count: i32,
    error_decl_name: &byte,
    interface_decl_name: &byte,
    interface_decl_method_sigs: & & ASTNode,
    interface_decl_method_sig_count: i32,
    struct_decl_name: &byte,
    struct_decl_methods: & & ASTNode,
    struct_decl_method_count: i32,
    union_decl_name: &byte,
    union_decl_methods: & & ASTNode,
    union_decl_method_count: i32,
    method_block_methods: & & ASTNode,
    method_block_method_count: i32,
    fn_decl_name: &byte,
    macro_decl_name: &byte,
    type_alias_name: &byte,
    var_decl_name: &byte,
    extern_var_decl_name: &byte,
    use_stmt_item_name: &byte,
    use_stmt_alias: &byte,
}

fn semantic_test_node(kind: ASTNodeType, filename: &byte, name: &byte) ASTNode {
    var node: ASTNode = ASTNode{
        type: kind,
        filename: filename,
        program_decls: null,
        program_decl_count: 0,
        enum_decl_name: null,
        enum_decl_variant_count: 0,
        error_decl_name: null,
        interface_decl_name: null,
        interface_decl_method_sigs: null,
        interface_decl_method_sig_count: 0,
        struct_decl_name: null,
        struct_decl_methods: null,
        struct_decl_method_count: 0,
        union_decl_name: null,
        union_decl_methods: null,
        union_decl_method_count: 0,
        method_block_methods: null,
        method_block_method_count: 0,
        fn_decl_name: null,
        macro_decl_name: null,
        type_alias_name: null,
        var_decl_name: null,
        extern_var_decl_name: null,
        use_stmt_item_name: null,
        use_stmt_alias: null,
    };
    if kind == ASTNodeType.AST_FN_DECL {
        node.fn_decl_name = name;
    } else if kind == ASTNodeType.AST_STRUCT_DECL {
        node.struct_decl_name = name;
    } else if kind == ASTNodeType.AST_TYPE_ALIAS {
        node.type_alias_name = name;
    } else if kind == ASTNodeType.AST_VAR_DECL {
        node.var_decl_name = name;
    } else if kind == ASTNodeType.AST_EXTERN_VAR_DECL {
        node.extern_var_decl_name = name;
    } else if kind == ASTNodeType.AST_INTERFACE_DECL {
        node.interface_decl_name = name;
    } else if kind == ASTNodeType.AST_UNION_DECL {
        node.union_decl_name = name;
    } else if kind == ASTNodeType.AST_ENUM_DECL {
        node.enum_decl_name = name;
    } else if kind == ASTNodeType.AST_ERROR_DECL {
        node.error_decl_name = name;
    } else if kind == ASTNodeType.AST_MACRO_DECL {
        node.macro_decl_name = name;
    }
    return node;
}
EOF

cat "$TABLE_FILE" >>"$tmp_dir/main.uya"
cat "$DB_FILE" >>"$tmp_dir/main.uya"
cat "$BUILD_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
fn semantic_test_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn semantic_test_hash() SemanticHash {
    return SemanticHash{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn semantic_test_db() SemanticDb {
    return SemanticDb{
        file_count: 0,
        module_count: 0,
        interned_name_count: 0,
        decl_count: 0,
        symbol_count: 0,
        scope_count: 0,
        type_count: 0,
        expr_count: 0,
        function_count: 0,
        mono_instance_count: 0,
        estimated_bytes: 0usize,
        decl_records: semantic_test_vector(),
        symbol_records: semantic_test_vector(),
        name_ranges: semantic_test_vector(),
        name_range_index: semantic_test_hash(),
    };
}

test "semantic db build rejects invalid input" {
    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, null), -1);
    var bad: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "a.uya", "bad");
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &bad), -1);
}

test "semantic db build counts merged ast declarations" {
    var main_fn: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "a.uya", "main");
    var method: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "a.uya", "push");
    var methods: [&ASTNode: 1] = [];
    methods[0] = &method;

    var struct_decl: ASTNode = semantic_test_node(ASTNodeType.AST_STRUCT_DECL, "a.uya", "Vec");
    struct_decl.struct_decl_methods = &methods[0] as & & ASTNode;
    struct_decl.struct_decl_method_count = 1;

    var alias_decl: ASTNode = semantic_test_node(ASTNodeType.AST_TYPE_ALIAS, "a.uya", "Count");
    var global_decl: ASTNode = semantic_test_node(ASTNodeType.AST_EXTERN_VAR_DECL, "b.uya", "errno");
    var use_decl: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "b.uya", null);
    use_decl.use_stmt_item_name = "printf";

    var decls: [&ASTNode: 5] = [];
    decls[0] = &main_fn;
    decls[1] = &struct_decl;
    decls[2] = &alias_decl;
    decls[3] = &global_decl;
    decls[4] = &use_decl;

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "a.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 5;

    var db: SemanticDb = semantic_test_db();

    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(db.decl_count, 5);
    try assert_eq_i32(db.file_count, 2);
    try assert_eq_i32(db.module_count, 2);
    try assert_eq_i32(db.function_count, 2);
    try assert_eq_i32(db.type_count, 2);
    try assert_eq_i32(db.symbol_count, 5);
    try assert_eq_i32(db.interned_name_count, 5);
    try assert_eq_i32(semantic_db_decl_record_count(&db), 5);
    try assert_eq_i32(semantic_db_symbol_record_count(&db), 5);
    try assert_eq_i32(semantic_db_name_range_count(&db), 5);
    try expect(semantic_db_estimated_bytes(&db) >= @size_of(SemanticDb));
    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb build smoke passed"
