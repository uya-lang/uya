#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"
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

for file in "$TABLE_FILE" "$INTERN_FILE" "$DB_FILE" "$BUILD_FILE"; do
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
cat "$INTERN_FILE" >>"$tmp_dir/main.uya"
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
    try assert_eq_i32(db.interned_name_count, 6);
    try assert_eq_i32(semantic_db_decl_record_count(&db), 5);
    try assert_eq_i32(semantic_db_symbol_record_count(&db), 5);
    try assert_eq_i32(semantic_db_name_range_count(&db), 5);
    try expect(db.use_items_by_file_name.count == 1usize);
    try expect(semantic_db_estimated_bytes(&db) >= @size_of(SemanticDb));
    semantic_db_release(&db);
}

test "semantic db build keeps same-name function body and stub" {
    var body_block: ASTNode = semantic_test_node(ASTNodeType.AST_BLOCK, "family_body.uya", null);
    var body_fn: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "family_body.uya", "family");
    body_fn.fn_decl_body = &body_block;
    var stub_fn: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "family_stub.uya", "family");

    var decls: [&ASTNode: 2] = [];
    decls[0] = &body_fn;
    decls[1] = &stub_fn;

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "family_body.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 2;

    var db: SemanticDb = semantic_test_db();

    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(db.decl_count, 2);
    try assert_eq_i32(db.file_count, 2);
    try assert_eq_i32(db.function_count, 2);
    try assert_eq_i32(db.symbol_count, 2);
    try expect(semantic_db_decl_ast_node(&db, 0) == &body_fn);
    try expect(semantic_db_decl_ast_node(&db, 1) == &stub_fn);
    try expect(body_fn.fn_decl_body != null);
    try expect(stub_fn.fn_decl_body == null);
    semantic_db_release(&db);
}

test "semantic db build preserves libc and std family contexts" {
    var libc_read: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "lib/libc/unistd.uya", "read");
    var libc_strlen: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "lib/libc/string.uya", "strlen");
    var std_read: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "lib/std/io/reader.uya", "read");
    var std_string_alias: ASTNode = semantic_test_node(ASTNodeType.AST_TYPE_ALIAS, "lib/std/string/string.uya", "String");

    var decls: [&ASTNode: 4] = [];
    decls[0] = &libc_read;
    decls[1] = &libc_strlen;
    decls[2] = &std_read;
    decls[3] = &std_string_alias;

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "lib/std/io/reader.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 4;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(db.decl_count, 4);
    try assert_eq_i32(db.file_count, 4);
    try assert_eq_i32(db.module_count, 4);
    try assert_eq_i32(db.function_count, 3);
    try assert_eq_i32(db.type_count, 1);
    try assert_eq_i32(db.symbol_count, 4);

    try expect(semantic_test_cstr_equals(semantic_db_file_name(&db, 0), "lib/std/io/reader.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_file_name(&db, 1), "lib/libc/unistd.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_file_name(&db, 2), "lib/libc/string.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_file_name(&db, 3), "lib/std/string/string.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_module_name(&db, 0), "lib/std/io/reader.uya") != 0);
    try expect(semantic_test_cstr_equals(semantic_db_module_name(&db, 1), "lib/libc/unistd.uya") != 0);

    var rec0: SemanticDeclRecord = SemanticDeclRecord{ ast_node: null, name_id: -1, kind: -1, file_id: -1, module_id: -1 };
    var rec1: SemanticDeclRecord = SemanticDeclRecord{ ast_node: null, name_id: -1, kind: -1, file_id: -1, module_id: -1 };
    var rec2: SemanticDeclRecord = SemanticDeclRecord{ ast_node: null, name_id: -1, kind: -1, file_id: -1, module_id: -1 };
    var rec3: SemanticDeclRecord = SemanticDeclRecord{ ast_node: null, name_id: -1, kind: -1, file_id: -1, module_id: -1 };
    try assert_eq_i32(semantic_db_decl_record_get(&db, 0, &rec0), 1);
    try assert_eq_i32(semantic_db_decl_record_get(&db, 1, &rec1), 1);
    try assert_eq_i32(semantic_db_decl_record_get(&db, 2, &rec2), 1);
    try assert_eq_i32(semantic_db_decl_record_get(&db, 3, &rec3), 1);
    try assert_eq_i32(rec0.file_id, 1);
    try assert_eq_i32(rec0.module_id, 1);
    try assert_eq_i32(rec1.file_id, 2);
    try assert_eq_i32(rec1.module_id, 2);
    try assert_eq_i32(rec2.file_id, 0);
    try assert_eq_i32(rec2.module_id, 0);
    try assert_eq_i32(rec3.file_id, 3);
    try assert_eq_i32(rec3.module_id, 3);
    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb build smoke passed"
