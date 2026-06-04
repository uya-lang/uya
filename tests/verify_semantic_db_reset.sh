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
        echo "错误: SemanticDb reset 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$DB_FILE" "^export[[:space:]]+fn[[:space:]]+semantic_db_reset" "reset API"
require_pattern "$DB_FILE" "semantic_vector_reset\\(&db\\.decl_records\\)" "reset declaration vector"
require_pattern "$DB_FILE" "semantic_hash_reset\\(&db\\.name_range_index\\)" "reset name range hash"
require_pattern "$DB_FILE" "semantic_vector_reset\\(&db\\.import_bindings\\)" "reset import bindings"
require_pattern "$DB_FILE" "semantic_vector_reset\\(&db\\.export_bindings\\)" "reset export bindings"
require_pattern "$BUILD_FILE" "semantic_db_prepare_for_build" "build reuse preparation"
require_pattern "$BUILD_FILE" "semantic_db_reset\\(db\\)" "build entry resets reused db"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-reset.XXXXXX)"
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
        import_bindings: semantic_test_vector(),
        export_bindings: semantic_test_vector(),
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
        use_stmt_path_segments: null,
        use_stmt_path_segment_count: 0,
        use_stmt_item_name: null,
        use_stmt_alias: null,
    };
    if kind == ASTNodeType.AST_FN_DECL {
        node.fn_decl_name = name;
    }
    return node;
}

fn semantic_test_assert_empty(db: &SemanticDb) !void {
    try assert_eq_i32(db.file_count, 0);
    try assert_eq_i32(db.module_count, 0);
    try assert_eq_i32(db.interned_name_count, 0);
    try assert_eq_i32(db.decl_count, 0);
    try assert_eq_i32(db.symbol_count, 0);
    try assert_eq_i32(db.function_count, 0);
    try assert_eq_i32(semantic_db_decl_record_count(db), 0);
    try assert_eq_i32(semantic_db_file_record_count(db), 0);
    try assert_eq_i32(semantic_db_module_record_count(db), 0);
    try assert_eq_i32(semantic_db_symbol_record_count(db), 0);
    try assert_eq_i32(semantic_db_name_range_count(db), 0);
    try assert_eq_i32(semantic_db_import_binding_count(db), 0);
    try assert_eq_i32(semantic_db_export_binding_count(db), 0);
    try assert_eq_i32(semantic_db_estimated_bytes(db) as i32, 0);

    var stale_range: i32 = -1;
    try assert_eq_i32(semantic_db_find_name_range(db, 0, &stale_range), 0);
    try assert_eq_i32(semantic_db_find_name_range(db, 1, &stale_range), 0);
}

fn semantic_test_assert_old_program(db: &SemanticDb) !void {
    try assert_eq_i32(db.decl_count, 4);
    try assert_eq_i32(db.file_count, 2);
    try assert_eq_i32(db.module_count, 2);
    try assert_eq_i32(db.function_count, 2);
    try assert_eq_i32(db.symbol_count, 2);
    try assert_eq_i32(db.interned_name_count, 2);
    try assert_eq_i32(semantic_db_decl_record_count(db), 4);
    try assert_eq_i32(semantic_db_name_range_count(db), 2);
    try assert_eq_i32(semantic_db_import_binding_count(db), 2);
    try assert_eq_i32(semantic_db_export_binding_count(db), 2);
    try expect(semantic_db_estimated_bytes(db) > @size_of(SemanticDb));

    var range_id: i32 = -1;
    try assert_eq_i32(semantic_db_find_name_range(db, 0, &range_id), 1);
    try assert_eq_i32(range_id, 0);
    try assert_eq_i32(semantic_db_find_name_range(db, 1, &range_id), 1);
    try assert_eq_i32(range_id, 1);
}

test "semantic db reset supports same-process rebuilds" {
    var old_use_item: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "old_a.uya", null);
    old_use_item.use_stmt_item_name = "printf";
    var old_main: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "old_a.uya", "old_main");
    var old_helper: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "old_b.uya", "old_helper");
    var old_use_alias: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "old_b.uya", null);
    old_use_alias.use_stmt_alias = "old_io";

    var old_decls: [&ASTNode: 4] = [];
    old_decls[0] = &old_use_item;
    old_decls[1] = &old_main;
    old_decls[2] = &old_helper;
    old_decls[3] = &old_use_alias;

    var old_program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "old_a.uya", null);
    old_program.program_decls = &old_decls[0] as & & ASTNode;
    old_program.program_decl_count = 4;

    var fresh_use: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "fresh.uya", null);
    fresh_use.use_stmt_alias = "fresh_io";
    var fresh_main: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "fresh.uya", "fresh_main");

    var fresh_decls: [&ASTNode: 2] = [];
    fresh_decls[0] = &fresh_use;
    fresh_decls[1] = &fresh_main;

    var fresh_program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "fresh.uya", null);
    fresh_program.program_decls = &fresh_decls[0] as & & ASTNode;
    fresh_program.program_decl_count = 2;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &old_program), 0);
    try semantic_test_assert_old_program(&db);

    const old_decl_capacity: usize = db.decl_records.capacity;
    const old_import_capacity: usize = db.import_bindings.capacity;
    const old_hash_capacity: usize = db.name_range_index.capacity;

    semantic_db_reset(&db);
    try semantic_test_assert_empty(&db);
    try expect(db.decl_records.capacity == old_decl_capacity);
    try expect(db.import_bindings.capacity == old_import_capacity);
    try expect(db.name_range_index.capacity == old_hash_capacity);

    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &old_program), 0);
    try semantic_test_assert_old_program(&db);

    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &fresh_program), 0);
    try assert_eq_i32(db.decl_count, 2);
    try assert_eq_i32(db.file_count, 1);
    try assert_eq_i32(db.module_count, 1);
    try assert_eq_i32(db.function_count, 1);
    try assert_eq_i32(db.symbol_count, 1);
    try assert_eq_i32(db.interned_name_count, 1);
    try assert_eq_i32(semantic_db_decl_record_count(&db), 2);
    try assert_eq_i32(semantic_db_name_range_count(&db), 1);
    try assert_eq_i32(semantic_db_import_binding_count(&db), 1);
    try assert_eq_i32(semantic_db_export_binding_count(&db), 1);

    var fresh_import: SemanticImportBinding = SemanticImportBinding{ file_id: -1, module_id: -1, name: null, ast_node: null };
    var fresh_export: SemanticExportBinding = SemanticExportBinding{ file_id: -1, module_id: -1, name: null, decl_id: -1 };
    try assert_eq_i32(semantic_db_import_binding_get(&db, 0, &fresh_import), 1);
    try assert_eq_i32(semantic_db_export_binding_get(&db, 0, &fresh_export), 1);
    try expect(semantic_test_cstr_equals(fresh_import.name, "fresh_io") != 0);
    try expect(semantic_test_cstr_equals(fresh_export.name, "fresh_main") != 0);
    try assert_eq_i32(fresh_export.decl_id, 1);
    try expect(semantic_db_decl_ast_node(&db, 1) == &fresh_main);
    try expect(semantic_db_file_name(&db, 0) != null);
    try expect(semantic_test_cstr_equals(semantic_db_file_name(&db, 0), "fresh.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_module_name(&db, 0), "fresh.uya") != 0);

    var stale_range: i32 = -1;
    try assert_eq_i32(semantic_db_find_name_range(&db, 1, &stale_range), 0);
    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb reset reuse smoke passed"
