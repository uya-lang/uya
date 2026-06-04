#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"
DB_FILE="$REPO_ROOT/src/semantic/db.uya"
BUILD_FILE="$REPO_ROOT/src/semantic/build.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: SemanticDb use_items_by_file_name 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$DB_FILE" "use_items_by_file_name:[[:space:]]+SemanticHash" "use_items_by_file_name 动态 hash"
require_pattern "$DB_FILE" "semantic_db_append_file_use_item_index" "use item 索引 append API"
require_pattern "$DB_FILE" "semantic_db_find_file_use_item_binding" "use item 索引 lookup API"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_use_items_by_file_name" "构建 use_items_by_file_name 索引"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-use-items.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;
EOF

cat "$TABLE_FILE" >>"$tmp_dir/main.uya"
cat "$INTERN_FILE" >>"$tmp_dir/main.uya"
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

struct EnumVariant {
    name: &byte,
    value: &byte,
}

struct ASTNode {
    type: ASTNodeType,
    filename: &byte,
    program_decls: & & ASTNode,
    program_decl_count: i32,
    enum_decl_name: &byte,
    enum_decl_variants: &EnumVariant,
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
    use_stmt_path_segments: & & byte,
    use_stmt_path_segment_count: i32,
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

fn semantic_test_intern() SemanticInternTable {
    return SemanticInternTable{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
        string_bytes: 0usize,
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
        name_intern: semantic_test_intern(),
        file_records: semantic_test_vector(),
        module_records: semantic_test_vector(),
        decl_records: semantic_test_vector(),
        symbol_records: semantic_test_vector(),
        name_ranges: semantic_test_vector(),
        name_range_index: semantic_test_hash(),
        decl_ranges: semantic_test_vector(),
        decl_range_ids: semantic_test_vector(),
        decls_by_name: semantic_test_hash(),
        function_ranges: semantic_test_vector(),
        function_range_decl_ids: semantic_test_vector(),
        functions_by_name: semantic_test_hash(),
        type_ranges: semantic_test_vector(),
        type_range_decl_ids: semantic_test_vector(),
        types_by_name: semantic_test_hash(),
        enum_variant_records: semantic_test_vector(),
        enum_variant_ranges: semantic_test_vector(),
        enum_variant_range_record_ids: semantic_test_vector(),
        enum_variants_by_name: semantic_test_hash(),
        import_bindings: semantic_test_vector(),
        export_bindings: semantic_test_vector(),
        exports_by_module_name: semantic_test_hash(),
        aliases_by_file_name: semantic_test_hash(),
        use_items_by_file_name: semantic_test_hash(),
    };
}

fn semantic_test_node(kind: ASTNodeType, filename: &byte, name: &byte) ASTNode {
    var node: ASTNode = ASTNode{
        type: kind,
        filename: filename,
        program_decls: null,
        program_decl_count: 0,
        enum_decl_name: null,
        enum_decl_variants: null,
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
        use_stmt_path_segments: null,
        use_stmt_path_segment_count: 0,
        use_stmt_item_name: null,
        use_stmt_alias: null,
    };
    if kind == ASTNodeType.AST_FN_DECL {
        node.fn_decl_name = name;
    } else if kind == ASTNodeType.AST_TYPE_ALIAS {
        node.type_alias_name = name;
    }
    return node;
}

fn semantic_test_expect_binding(db: &SemanticDb, file_id: i32, name: &byte, expected_id: i32, expected_name: &byte) !void {
    const name_id: i32 = semantic_db_find_interned_name(db, name);
    try expect(name_id >= 0);
    var binding_id: i32 = -99;
    try assert_eq_i32(semantic_db_find_file_use_item_binding(db, file_id, name_id, &binding_id), 1);
    try assert_eq_i32(binding_id, expected_id);
    var binding: SemanticImportBinding = SemanticImportBinding{ file_id: -1, module_id: -1, name: null, ast_node: null };
    try assert_eq_i32(semantic_db_import_binding_get(db, binding_id, &binding), 1);
    try assert_eq_i32(binding.file_id, file_id);
    try expect(semantic_test_cstr_equals(binding.name, expected_name) != 0);
}

test "semantic db indexes use items by file and import name" {
    var alias_a: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "src/a.uya", null);
    alias_a.use_stmt_alias = "io";
    var alias_b: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "src/b.uya", null);
    alias_b.use_stmt_alias = "io";
    var item_a: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "src/a.uya", null);
    item_a.use_stmt_item_name = "printf";

    var path_segments: [&byte: 3] = [];
    path_segments[0] = "std";
    path_segments[1] = "io";
    path_segments[2] = "file";
    var whole_module_a: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "src/a.uya", null);
    whole_module_a.use_stmt_path_segments = &path_segments[0] as & & byte;
    whole_module_a.use_stmt_path_segment_count = 3;

    var decls: [&ASTNode: 4] = [];
    decls[0] = &alias_a;
    decls[1] = &alias_b;
    decls[2] = &item_a;
    decls[3] = &whole_module_a;

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "src/a.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 4;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(semantic_db_import_binding_count(&db), 4);
    try expect(db.use_items_by_file_name.count == 4usize);

    try semantic_test_expect_binding(&db, 0, "io", 0, "io");
    try semantic_test_expect_binding(&db, 1, "io", 1, "io");
    try semantic_test_expect_binding(&db, 0, "printf", 2, "printf");
    try semantic_test_expect_binding(&db, 0, "file", 3, "file");

    const missing_name_id: i32 = semantic_db_find_interned_name(&db, "missing");
    try assert_eq_i32(missing_name_id, -1);
    const io_name_id: i32 = semantic_db_find_interned_name(&db, "io");
    var missing_binding_id: i32 = 1234;
    try assert_eq_i32(semantic_db_find_file_use_item_binding(&db, 2, io_name_id, &missing_binding_id), 0);
    try assert_eq_i32(missing_binding_id, 1234);

    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb use_items_by_file_name lookup passed"
