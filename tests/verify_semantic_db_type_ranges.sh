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
        echo "错误: SemanticDb types_by_name 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$DB_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticTypeDeclRange" "TypeDeclRange 结构"
require_pattern "$DB_FILE" "type_ranges:[[:space:]]+SemanticVector" "type range 为动态 vector"
require_pattern "$DB_FILE" "type_range_decl_ids:[[:space:]]+SemanticVector" "类型 DeclId range 数据为动态 vector"
require_pattern "$DB_FILE" "types_by_name:[[:space:]]+SemanticHash" "types_by_name 为动态 hash"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_types_by_name" "构建 types_by_name 索引"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-type-ranges.XXXXXX)"
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
    } else if kind == ASTNodeType.AST_STRUCT_DECL {
        node.struct_decl_name = name;
    } else if kind == ASTNodeType.AST_TYPE_ALIAS {
        node.type_alias_name = name;
    } else if kind == ASTNodeType.AST_UNION_DECL {
        node.union_decl_name = name;
    }
    return node;
}

test "semantic db types_by_name keeps only type declarations" {
    var struct_decl: ASTNode = semantic_test_node(ASTNodeType.AST_STRUCT_DECL, "thing_struct.uya", "Thing");
    var same_name_fn: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "thing_fn.uya", "Thing");
    var alias_decl: ASTNode = semantic_test_node(ASTNodeType.AST_TYPE_ALIAS, "thing_alias.uya", "Thing");
    var union_decl: ASTNode = semantic_test_node(ASTNodeType.AST_UNION_DECL, "other.uya", "Other");

    var decls: [&ASTNode: 4] = [];
    decls[0] = &struct_decl;
    decls[1] = &same_name_fn;
    decls[2] = &alias_decl;
    decls[3] = &union_decl;

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "thing_struct.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 4;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(db.decl_count, 4);
    try assert_eq_i32(db.type_count, 3);
    try assert_eq_i32(db.function_count, 1);
    try assert_eq_i32(db.interned_name_count, 2);
    try assert_eq_i32(semantic_db_type_decl_range_count(&db), 2);

    const thing_name_id: i32 = semantic_db_find_interned_name(&db, "Thing");
    const other_name_id: i32 = semantic_db_find_interned_name(&db, "Other");
    try expect(thing_name_id >= 0);
    try expect(other_name_id >= 0);

    var thing_range: SemanticTypeDeclRange = SemanticTypeDeclRange{
        name_id: -1,
        type_start: -1,
        type_count: 0,
    };
    try assert_eq_i32(semantic_db_find_type_decl_range(&db, thing_name_id, &thing_range), 1);
    try assert_eq_i32(thing_range.name_id, thing_name_id);
    try assert_eq_i32(thing_range.type_count, 2);
    try assert_eq_i32(semantic_db_type_range_decl_id(&db, &thing_range, 0), 0);
    try assert_eq_i32(semantic_db_type_range_decl_id(&db, &thing_range, 1), 2);

    var other_range: SemanticTypeDeclRange = SemanticTypeDeclRange{
        name_id: -1,
        type_start: -1,
        type_count: 0,
    };
    try assert_eq_i32(semantic_db_find_type_decl_range(&db, other_name_id, &other_range), 1);
    try assert_eq_i32(other_range.type_count, 1);
    try assert_eq_i32(semantic_db_type_range_decl_id(&db, &other_range, 0), 3);
    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb types_by_name range lookup passed"
