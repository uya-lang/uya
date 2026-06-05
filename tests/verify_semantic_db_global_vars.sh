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
        echo "错误: SemanticDb global vars 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$DB_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticGlobalVarRange" "GlobalVarRange 结构"
require_pattern "$DB_FILE" "global_var_ranges:[[:space:]]+SemanticVector" "global var range 为动态 vector"
require_pattern "$DB_FILE" "global_var_range_decl_ids:[[:space:]]+SemanticVector" "global var range payload 为动态 vector"
require_pattern "$DB_FILE" "global_vars_by_name:[[:space:]]+SemanticHash" "global_vars_by_name 为动态 hash"
require_pattern "$DB_FILE" "semantic_db_find_global_var_range" "global var 查询 API"
require_pattern "$DB_FILE" "semantic_db_global_var_range_decl_id" "global var range DeclId 读取 API"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_global_vars_by_name" "构建 global_vars_by_name 索引"
require_pattern "$BUILD_FILE" "AST_VAR_DECL" "普通全局 var 进入 global var 索引"
require_pattern "$BUILD_FILE" "AST_EXTERN_VAR_DECL" "extern global var 进入 global var 索引"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-globals.XXXXXX)"
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
    AST_BLOCK,
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
    fn_decl_body: &ASTNode,
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
        global_var_ranges: semantic_test_vector(),
        global_var_range_decl_ids: semantic_test_vector(),
        global_vars_by_name: semantic_test_hash(),
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
        fn_decl_body: null,
        macro_decl_name: null,
        type_alias_name: null,
        var_decl_name: null,
        extern_var_decl_name: null,
        use_stmt_path_segments: null,
        use_stmt_path_segment_count: 0,
        use_stmt_item_name: null,
        use_stmt_alias: null,
    };
    if kind == ASTNodeType.AST_VAR_DECL {
        node.var_decl_name = name;
    } else if kind == ASTNodeType.AST_EXTERN_VAR_DECL {
        node.extern_var_decl_name = name;
    } else if kind == ASTNodeType.AST_FN_DECL {
        node.fn_decl_name = name;
    } else if kind == ASTNodeType.AST_TYPE_ALIAS {
        node.type_alias_name = name;
    }
    return node;
}

fn expect_global_decl(db: &SemanticDb, range: &SemanticGlobalVarRange, offset: i32, expected_decl_id: i32, expected_kind: ASTNodeType) !void {
    const decl_id: i32 = semantic_db_global_var_range_decl_id(db, range, offset);
    try assert_eq_i32(decl_id, expected_decl_id);
    const decl: &ASTNode = semantic_db_decl_ast_node(db, decl_id);
    try expect(decl != null);
    try assert_eq_i32(decl.type as i32, expected_kind as i32);
}

test "semantic db exposes global variable visibility by name" {
    var global_shared: ASTNode = semantic_test_node(ASTNodeType.AST_VAR_DECL, "globals.uya", "shared");
    var extern_shared: ASTNode = semantic_test_node(ASTNodeType.AST_EXTERN_VAR_DECL, "globals.uya", "shared");
    var fn_shared: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "globals.uya", "shared");
    var global_other: ASTNode = semantic_test_node(ASTNodeType.AST_VAR_DECL, "globals.uya", "other");
    var alias_not_global: ASTNode = semantic_test_node(ASTNodeType.AST_TYPE_ALIAS, "globals.uya", "Alias");
    var decls: [&ASTNode: 5] = [&global_shared, &extern_shared, &fn_shared, &global_other, &alias_not_global];

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "globals.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 5;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(semantic_db_decl_record_count(&db), 5);
    try assert_eq_i32(semantic_db_function_overload_range_count(&db), 1);
    try assert_eq_i32(semantic_db_type_decl_range_count(&db), 1);
    try assert_eq_i32(semantic_db_global_var_range_count(&db), 2);

    const shared_name_id: i32 = semantic_db_find_interned_name(&db, "shared");
    const other_name_id: i32 = semantic_db_find_interned_name(&db, "other");
    const alias_name_id: i32 = semantic_db_find_interned_name(&db, "Alias");
    try expect(shared_name_id >= 0);
    try expect(other_name_id >= 0);
    try expect(alias_name_id >= 0);

    var shared_range: SemanticGlobalVarRange = SemanticGlobalVarRange{ name_id: -1, global_start: -1, global_count: -1 };
    try assert_eq_i32(semantic_db_find_global_var_range(&db, shared_name_id, &shared_range), 1);
    try assert_eq_i32(shared_range.global_count, 2);
    try expect_global_decl(&db, &shared_range, 0, 0, ASTNodeType.AST_VAR_DECL);
    try expect_global_decl(&db, &shared_range, 1, 1, ASTNodeType.AST_EXTERN_VAR_DECL);
    try assert_eq_i32(semantic_db_global_var_range_decl_id(&db, &shared_range, 2), -1);

    var other_range: SemanticGlobalVarRange = SemanticGlobalVarRange{ name_id: -1, global_start: -1, global_count: -1 };
    try assert_eq_i32(semantic_db_find_global_var_range(&db, other_name_id, &other_range), 1);
    try assert_eq_i32(other_range.global_count, 1);
    try expect_global_decl(&db, &other_range, 0, 3, ASTNodeType.AST_VAR_DECL);

    var alias_range: SemanticGlobalVarRange = SemanticGlobalVarRange{ name_id: -1, global_start: -1, global_count: -1 };
    try assert_eq_i32(semantic_db_find_global_var_range(&db, alias_name_id, &alias_range), 0);

    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && "$REPO_ROOT/bin/uya" test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb global variable visibility lookup passed"
