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
        echo "错误: SemanticDb enum_variants_by_name 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$DB_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticEnumVariantRecord" "EnumVariantRecord 结构"
require_pattern "$DB_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticEnumVariantRange" "EnumVariantRange 结构"
require_pattern "$DB_FILE" "enum_variant_records:[[:space:]]+SemanticVector" "enum variant record 为动态 vector"
require_pattern "$DB_FILE" "enum_variant_ranges:[[:space:]]+SemanticVector" "enum variant range 为动态 vector"
require_pattern "$DB_FILE" "enum_variants_by_name:[[:space:]]+SemanticHash" "enum_variants_by_name 为动态 hash"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_enum_variants_by_name" "构建 enum_variants_by_name 索引"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-enum-variant-ranges.XXXXXX)"
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
        macro_decl_name: null,
        type_alias_name: null,
        var_decl_name: null,
        extern_var_decl_name: null,
        use_stmt_path_segments: null,
        use_stmt_path_segment_count: 0,
        use_stmt_item_name: null,
        use_stmt_alias: null,
    };
    if kind == ASTNodeType.AST_ENUM_DECL {
        node.enum_decl_name = name;
    }
    return node;
}

test "semantic db enum_variants_by_name groups variants across enums" {
    var color_variants: [EnumVariant: 2] = [];
    color_variants[0] = EnumVariant{ name: "Red", value: null };
    color_variants[1] = EnumVariant{ name: "Shared", value: null };
    var color_enum: ASTNode = semantic_test_node(ASTNodeType.AST_ENUM_DECL, "color.uya", "Color");
    color_enum.enum_decl_variants = &color_variants[0];
    color_enum.enum_decl_variant_count = 2;

    var state_variants: [EnumVariant: 2] = [];
    state_variants[0] = EnumVariant{ name: "Shared", value: "7" };
    state_variants[1] = EnumVariant{ name: "Done", value: null };
    var state_enum: ASTNode = semantic_test_node(ASTNodeType.AST_ENUM_DECL, "state.uya", "State");
    state_enum.enum_decl_variants = &state_variants[0];
    state_enum.enum_decl_variant_count = 2;

    var decls: [&ASTNode: 2] = [];
    decls[0] = &color_enum;
    decls[1] = &state_enum;

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "color.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 2;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(db.decl_count, 2);
    try assert_eq_i32(db.type_count, 2);
    try assert_eq_i32(db.interned_name_count, 5);
    try assert_eq_i32(semantic_db_enum_variant_record_count(&db), 4);
    try assert_eq_i32(semantic_db_enum_variant_range_count(&db), 3);

    const shared_name_id: i32 = semantic_db_find_interned_name(&db, "Shared");
    try expect(shared_name_id >= 0);

    var shared_range: SemanticEnumVariantRange = SemanticEnumVariantRange{
        name_id: -1,
        variant_start: -1,
        variant_count: 0,
    };
    try assert_eq_i32(semantic_db_find_enum_variant_range(&db, shared_name_id, &shared_range), 1);
    try assert_eq_i32(shared_range.name_id, shared_name_id);
    try assert_eq_i32(shared_range.variant_count, 2);

    const first_record_id: i32 = semantic_db_enum_variant_range_record_id(&db, &shared_range, 0);
    const second_record_id: i32 = semantic_db_enum_variant_range_record_id(&db, &shared_range, 1);
    try assert_eq_i32(first_record_id, 1);
    try assert_eq_i32(second_record_id, 2);

    var first_record: SemanticEnumVariantRecord = SemanticEnumVariantRecord{ name_id: -1, enum_decl_id: -1, variant_index: -1 };
    var second_record: SemanticEnumVariantRecord = SemanticEnumVariantRecord{ name_id: -1, enum_decl_id: -1, variant_index: -1 };
    try assert_eq_i32(semantic_db_enum_variant_record_get(&db, first_record_id, &first_record), 1);
    try assert_eq_i32(semantic_db_enum_variant_record_get(&db, second_record_id, &second_record), 1);
    try assert_eq_i32(first_record.enum_decl_id, 0);
    try assert_eq_i32(first_record.variant_index, 1);
    try assert_eq_i32(second_record.enum_decl_id, 1);
    try assert_eq_i32(second_record.variant_index, 0);
    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb enum_variants_by_name range lookup passed"
