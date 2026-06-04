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
        echo "错误: SemanticDb estimated bytes 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$DB_FILE" "semantic_db_storage_bytes" "storage bytes helper"
require_pattern "$BUILD_FILE" "semantic_db_storage_bytes" "build 使用统一 bytes helper"
require_pattern "$DB_FILE" "decl_records\\.bytes" "声明记录 bytes 计入估算"
require_pattern "$DB_FILE" "symbol_records\\.bytes" "符号记录 bytes 计入估算"
require_pattern "$DB_FILE" "name_ranges\\.bytes" "名字 range bytes 计入估算"
require_pattern "$DB_FILE" "name_range_index\\.bytes" "hash bucket bytes 计入估算"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-bytes.XXXXXX)"
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

test "semantic db estimated bytes include dynamic storage" {
    var decls: [&ASTNode: 12] = [];
EOF

for i in $(seq 0 11); do
    printf '    var fn_%02d: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "bytes.uya", "fn_%02d");\n' "$i" "$i" >>"$tmp_dir/main.uya"
    printf '    decls[%d] = &fn_%02d;\n' "$i" "$i" >>"$tmp_dir/main.uya"
done

cat >>"$tmp_dir/main.uya" <<'EOF'
    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "bytes.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 12;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    const storage_bytes: usize = semantic_db_storage_bytes(&db);
    try expect(storage_bytes > @size_of(SemanticDb));
    try expect(semantic_db_estimated_bytes(&db) == storage_bytes);
    try expect(storage_bytes >= @size_of(SemanticDb) + db.decl_records.bytes +
        db.symbol_records.bytes + db.name_ranges.bytes + db.name_range_index.bytes);
    semantic_db_release(&db);
    try assert_eq_i32(semantic_db_estimated_bytes(&db) as i32, 0);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb estimated bytes smoke passed"
