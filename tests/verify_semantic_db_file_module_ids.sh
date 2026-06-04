#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
DB_FILE="$REPO_ROOT/src/semantic/db.uya"
BUILD_FILE="$REPO_ROOT/src/semantic/build.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: SemanticDb FileId/ModuleId 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$DB_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticFileRecord" "FileId 记录结构"
require_pattern "$DB_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticModuleRecord" "ModuleId 记录结构"
require_pattern "$DB_FILE" "file_records:[[:space:]]+SemanticVector" "文件记录动态 vector"
require_pattern "$DB_FILE" "module_records:[[:space:]]+SemanticVector" "模块记录动态 vector"
require_pattern "$DB_FILE" "semantic_db_file_name" "FileId 名字 accessor"
require_pattern "$DB_FILE" "semantic_db_module_name" "ModuleId 名字 accessor"
require_pattern "$DB_FILE" "semantic_db_decl_record_get" "DeclRecord accessor"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-file-module.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;
EOF

cat "$TABLE_FILE" >>"$tmp_dir/main.uya"
cat "$DB_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
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
EOF

cat "$BUILD_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
fn semantic_test_cstr_equals(a: &byte, b: &byte) i32 {
    if a == null || b == null {
        return 0;
    }
    var i: usize = 0usize;
    while a[i] != 0 as byte && b[i] != 0 as byte {
        if a[i] != b[i] {
            return 0;
        }
        i = i + 1usize;
    }
    if a[i] == b[i] {
        return 1;
    }
    return 0;
}

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
        file_records: semantic_test_vector(),
        module_records: semantic_test_vector(),
        decl_records: semantic_test_vector(),
        symbol_records: semantic_test_vector(),
        name_ranges: semantic_test_vector(),
        name_range_index: semantic_test_hash(),
    };
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
    }
    return node;
}

test "semantic db assigns file and module ids" {
    var fn_decl: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "a.uya", "main");
    var struct_decl: ASTNode = semantic_test_node(ASTNodeType.AST_STRUCT_DECL, "b.uya", "Box");
    var alias_decl: ASTNode = semantic_test_node(ASTNodeType.AST_TYPE_ALIAS, "b.uya", "Alias");

    var decls: [&ASTNode: 3] = [];
    decls[0] = &fn_decl;
    decls[1] = &struct_decl;
    decls[2] = &alias_decl;

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "a.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 3;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(db.file_count, 2);
    try assert_eq_i32(db.module_count, 2);
    try assert_eq_i32(semantic_db_file_record_count(&db), 2);
    try assert_eq_i32(semantic_db_module_record_count(&db), 2);
    try expect(semantic_test_cstr_equals(semantic_db_file_name(&db, 0), "a.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_file_name(&db, 1), "b.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_module_name(&db, 1), "b.uya") != 0);

    var rec0: SemanticDeclRecord = SemanticDeclRecord{ ast_node: null, name_id: -1, kind: -1, file_id: -1, module_id: -1 };
    var rec1: SemanticDeclRecord = SemanticDeclRecord{ ast_node: null, name_id: -1, kind: -1, file_id: -1, module_id: -1 };
    var rec2: SemanticDeclRecord = SemanticDeclRecord{ ast_node: null, name_id: -1, kind: -1, file_id: -1, module_id: -1 };
    try assert_eq_i32(semantic_db_decl_record_get(&db, 0, &rec0), 1);
    try assert_eq_i32(semantic_db_decl_record_get(&db, 1, &rec1), 1);
    try assert_eq_i32(semantic_db_decl_record_get(&db, 2, &rec2), 1);
    try assert_eq_i32(rec0.file_id, 0);
    try assert_eq_i32(rec0.module_id, 0);
    try assert_eq_i32(rec1.file_id, 1);
    try assert_eq_i32(rec1.module_id, 1);
    try assert_eq_i32(rec2.file_id, 1);
    try assert_eq_i32(rec2.module_id, 1);
    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb FileId/ModuleId smoke passed"
