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
        echo "错误: Phase 2 dynamic indexes 缺少证据: $description" >&2
        return 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: Phase 2 dynamic indexes 发现禁止模式: $description" >&2
        grep -En "$pattern" "$file" >&2 || true
        return 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$DB_FILE" "$BUILD_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TABLE_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticHash" "动态 hash 结构"
require_pattern "$TABLE_FILE" "semantic_hash_reserve" "hash reserve API"
require_pattern "$TABLE_FILE" "semantic_hash_ensure_capacity" "hash ensure_capacity API"
require_pattern "$TABLE_FILE" "semantic_hash_insert" "hash insert API"
require_pattern "$TABLE_FILE" "hash\\.capacity[[:space:]]*-[[:space:]]*\\(hash\\.capacity[[:space:]]*/[[:space:]]*4usize\\)" "hash 按负载因子触发扩容"
require_pattern "$TABLE_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticVector" "动态 vector 结构"
require_pattern "$TABLE_FILE" "^export[[:space:]]+struct[[:space:]]+SemanticRangeBuilder" "动态 range builder 结构"

require_pattern "$DB_FILE" "decl_ranges:[[:space:]]+SemanticVector" "decl range 动态 vector"
require_pattern "$DB_FILE" "decl_range_ids:[[:space:]]+SemanticVector" "decl range payload 动态 vector"
require_pattern "$DB_FILE" "decls_by_name:[[:space:]]+SemanticHash" "decls_by_name 动态 hash"
require_pattern "$DB_FILE" "function_ranges:[[:space:]]+SemanticVector" "function range 动态 vector"
require_pattern "$DB_FILE" "function_range_decl_ids:[[:space:]]+SemanticVector" "function range payload 动态 vector"
require_pattern "$DB_FILE" "functions_by_name:[[:space:]]+SemanticHash" "functions_by_name 动态 hash"
require_pattern "$DB_FILE" "type_ranges:[[:space:]]+SemanticVector" "type range 动态 vector"
require_pattern "$DB_FILE" "type_range_decl_ids:[[:space:]]+SemanticVector" "type range payload 动态 vector"
require_pattern "$DB_FILE" "types_by_name:[[:space:]]+SemanticHash" "types_by_name 动态 hash"
require_pattern "$DB_FILE" "global_var_ranges:[[:space:]]+SemanticVector" "global var range 动态 vector"
require_pattern "$DB_FILE" "global_var_range_decl_ids:[[:space:]]+SemanticVector" "global var range payload 动态 vector"
require_pattern "$DB_FILE" "global_vars_by_name:[[:space:]]+SemanticHash" "global_vars_by_name 动态 hash"
require_pattern "$DB_FILE" "enum_variant_ranges:[[:space:]]+SemanticVector" "enum variant range 动态 vector"
require_pattern "$DB_FILE" "enum_variant_range_record_ids:[[:space:]]+SemanticVector" "enum variant range payload 动态 vector"
require_pattern "$DB_FILE" "enum_variants_by_name:[[:space:]]+SemanticHash" "enum_variants_by_name 动态 hash"
require_pattern "$DB_FILE" "exports_by_module_name:[[:space:]]+SemanticHash" "exports_by_module_name 动态 hash"
require_pattern "$DB_FILE" "aliases_by_file_name:[[:space:]]+SemanticHash" "aliases_by_file_name 动态 hash"
require_pattern "$DB_FILE" "use_items_by_file_name:[[:space:]]+SemanticHash" "use_items_by_file_name 动态 hash"

require_pattern "$BUILD_FILE" "semantic_db_rebuild_decls_by_name" "decls_by_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_functions_by_name" "functions_by_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_types_by_name" "types_by_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_global_vars_by_name" "global_vars_by_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_enum_variants_by_name" "enum_variants_by_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_exports_by_module_name" "exports_by_module_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_aliases_by_file_name" "aliases_by_file_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_db_rebuild_use_items_by_file_name" "use_items_by_file_name 构建入口"
require_pattern "$BUILD_FILE" "semantic_vector_append\\(&db\\.decl_range_ids" "decl range payload append"
require_pattern "$BUILD_FILE" "semantic_vector_append\\(&db\\.function_range_decl_ids" "function range payload append"
require_pattern "$BUILD_FILE" "semantic_vector_append\\(&db\\.type_range_decl_ids" "type range payload append"
require_pattern "$BUILD_FILE" "semantic_vector_append\\(&db\\.global_var_range_decl_ids" "global var range payload append"
require_pattern "$BUILD_FILE" "semantic_vector_append\\(&db\\.enum_variant_range_record_ids" "enum variant range payload append"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.decls_by_name" "decl range 查询直接读 hash"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.functions_by_name" "function range 查询直接读 hash"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.types_by_name" "type range 查询直接读 hash"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.global_vars_by_name" "global var range 查询直接读 hash"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.enum_variants_by_name" "enum variant range 查询直接读 hash"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.exports_by_module_name" "export 查询直接读 hash"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.aliases_by_file_name" "alias 查询直接读 hash"
require_pattern "$DB_FILE" "semantic_hash_get\\(&db\\.use_items_by_file_name" "use item 查询直接读 hash"
reject_pattern "$DB_FILE" "program_decls|program_decl_count|find_.*from_program|lookup_scan_" "SemanticDb 查询不能回退到全程序线性扫描"

for field in \
    decls_by_name functions_by_name types_by_name global_vars_by_name enum_variants_by_name \
    exports_by_module_name aliases_by_file_name use_items_by_file_name; do
    reject_pattern "$DB_FILE" "$field:[[:space:]]*\\[" "$field 不能是固定数组"
    reject_pattern "$BUILD_FILE" "${field}[^\\n]*(MAX|SIZE|BUCKET|CAPACITY)" "$field 不能依赖固定容量常量"
done

tmp_dir="$(mktemp -d /tmp/uya-semantic-phase2-indexes.XXXXXX)"
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
    if kind == ASTNodeType.AST_FN_DECL {
        node.fn_decl_name = name;
    } else if kind == ASTNodeType.AST_TYPE_ALIAS {
        node.type_alias_name = name;
    } else if kind == ASTNodeType.AST_ENUM_DECL {
        node.enum_decl_name = name;
    } else if kind == ASTNodeType.AST_USE_STMT {
        node.use_stmt_alias = name;
    }
    return node;
}

fn expect_hash_grew(hash: &SemanticHash, expected_count: i32) !void {
    try assert_eq_i32(hash.count as i32, expected_count);
    try expect(hash.capacity >= expected_count as usize);
    try expect(hash.realloc_count > 1);
}

fn expect_decl_range_decl_id(db: &SemanticDb, name_id: i32, expected_decl_id: i32) !void {
    var range: SemanticDeclRange = SemanticDeclRange{
        name_id: -1,
        decl_start: -1,
        decl_count: -1,
    };
    try assert_eq_i32(semantic_db_find_decl_range(db, name_id, &range), 1);
    try assert_eq_i32(range.decl_count, 1);
    try assert_eq_i32(semantic_db_decl_range_decl_id(db, &range, 0), expected_decl_id);
}

fn expect_function_range_decl_id(db: &SemanticDb, name_id: i32, expected_decl_id: i32) !void {
    var range: SemanticFunctionOverloadRange = SemanticFunctionOverloadRange{
        name_id: -1,
        function_start: -1,
        function_count: -1,
    };
    try assert_eq_i32(semantic_db_find_function_overload_range(db, name_id, &range), 1);
    try assert_eq_i32(range.function_count, 1);
    try assert_eq_i32(semantic_db_function_range_decl_id(db, &range, 0), expected_decl_id);
}

fn expect_type_range_decl_id(db: &SemanticDb, name_id: i32, expected_decl_id: i32) !void {
    var range: SemanticTypeDeclRange = SemanticTypeDeclRange{
        name_id: -1,
        type_start: -1,
        type_count: -1,
    };
    try assert_eq_i32(semantic_db_find_type_decl_range(db, name_id, &range), 1);
    try assert_eq_i32(range.type_count, 1);
    try assert_eq_i32(semantic_db_type_range_decl_id(db, &range, 0), expected_decl_id);
}

fn expect_enum_variant_record(db: &SemanticDb, name_id: i32, expected_record_id: i32, expected_enum_decl_id: i32) !void {
    var range: SemanticEnumVariantRange = SemanticEnumVariantRange{
        name_id: -1,
        variant_start: -1,
        variant_count: -1,
    };
    try assert_eq_i32(semantic_db_find_enum_variant_range(db, name_id, &range), 1);
    try assert_eq_i32(range.variant_count, 1);
    const record_id: i32 = semantic_db_enum_variant_range_record_id(db, &range, 0);
    try assert_eq_i32(record_id, expected_record_id);

    var record: SemanticEnumVariantRecord = SemanticEnumVariantRecord{
        name_id: -1,
        enum_decl_id: -1,
        variant_index: -1,
    };
    try assert_eq_i32(semantic_db_enum_variant_record_get(db, record_id, &record), 1);
    try assert_eq_i32(record.enum_decl_id, expected_enum_decl_id);
    try assert_eq_i32(record.variant_index, 0);
}

fn expect_export_symbol_decl(db: &SemanticDb, module_id: i32, name_id: i32, expected_symbol_id: i32, expected_decl_id: i32) !void {
    var symbol_id: i32 = -1;
    try assert_eq_i32(semantic_db_find_export_symbol(db, module_id, name_id, &symbol_id), 1);
    try assert_eq_i32(symbol_id, expected_symbol_id);

    var symbol: SemanticSymbolRecord = SemanticSymbolRecord{
        name_id: -1,
        decl_id: -1,
        kind: -1,
    };
    try assert_eq_i32(semantic_db_symbol_record_get(db, symbol_id, &symbol), 1);
    try assert_eq_i32(symbol.decl_id, expected_decl_id);
}

const PHASE2_COLLISION_COUNT: i32 = 24;
const PHASE2_COLLISION_BUCKET: usize = 64usize;

fn phase2_collision_name_id(ordinal: i32) i32 {
    var candidate: i32 = 0;
    var found: i32 = 0;
    while candidate < 200000 {
        const slot: usize = semantic_hash_key(candidate as i64) % PHASE2_COLLISION_BUCKET;
        if slot == 0usize {
            if found == ordinal {
                return candidate;
            }
            found = found + 1;
        }
        candidate = candidate + 1;
    }
    return -1;
}

fn append_i32_item(vec: &SemanticVector, value: i32) !void {
    var stored: i32 = value;
    try assert_eq_i32(semantic_vector_append(vec, &stored as &const void), 0);
}

fn append_phase2_collision_indexes(db: &SemanticDb) !void {
    var i: i32 = 0;
    while i < PHASE2_COLLISION_COUNT {
        const name_id: i32 = phase2_collision_name_id(i);
        try expect(name_id >= 0);
        try expect((semantic_hash_key(name_id as i64) % PHASE2_COLLISION_BUCKET) == 0usize);

        try append_i32_item(&db.decl_range_ids, 1000 + i);
        try assert_eq_i32(semantic_db_append_decl_range(db, name_id, i, 1), i);

        try append_i32_item(&db.function_range_decl_ids, 2000 + i);
        try assert_eq_i32(semantic_db_append_function_overload_range(db, name_id, i, 1), i);

        try append_i32_item(&db.type_range_decl_ids, 3000 + i);
        try assert_eq_i32(semantic_db_append_type_decl_range(db, name_id, i, 1), i);

        const variant_record_id: i32 = semantic_db_append_enum_variant_record(db, name_id, 4000 + i, 0);
        try assert_eq_i32(variant_record_id, i);
        try append_i32_item(&db.enum_variant_range_record_ids, variant_record_id);
        try assert_eq_i32(semantic_db_append_enum_variant_range(db, name_id, i, 1), i);

        const symbol_id: i32 = semantic_db_append_symbol_record(db, name_id, 5000 + i, 1);
        try assert_eq_i32(symbol_id, i);
        try assert_eq_i32(semantic_db_append_export_symbol_index(db, 0, name_id, symbol_id), 0);
        try assert_eq_i32(semantic_db_append_file_alias_index(db, 0, name_id, 6000 + i), 0);
        try assert_eq_i32(semantic_db_append_file_use_item_index(db, 0, name_id, 7000 + i), 0);

        i = i + 1;
    }
}

test "phase 2 semantic indexes dynamically grow and remain queryable" {
    var decls: [&ASTNode: 160] = [];
    var variants: [EnumVariant: 40] = [];
EOF

for i in $(seq 0 39); do
    slot_fn=$((i))
    slot_alias=$((40 + i))
    slot_enum=$((80 + i))
    slot_use=$((120 + i))
    printf '    var fn_%02d: ASTNode = semantic_test_node(ASTNodeType.AST_FN_DECL, "phase2.uya", "fn_%02d");\n' "$i" "$i" >>"$tmp_dir/main.uya"
    printf '    decls[%d] = &fn_%02d;\n' "$slot_fn" "$i" >>"$tmp_dir/main.uya"
    printf '    var alias_%02d: ASTNode = semantic_test_node(ASTNodeType.AST_TYPE_ALIAS, "phase2.uya", "Alias_%02d");\n' "$i" "$i" >>"$tmp_dir/main.uya"
    printf '    decls[%d] = &alias_%02d;\n' "$slot_alias" "$i" >>"$tmp_dir/main.uya"
    printf '    variants[%d] = EnumVariant{ name: "Variant_%02d", value: null };\n' "$i" "$i" >>"$tmp_dir/main.uya"
    printf '    var enum_%02d: ASTNode = semantic_test_node(ASTNodeType.AST_ENUM_DECL, "phase2.uya", "Enum_%02d");\n' "$i" "$i" >>"$tmp_dir/main.uya"
    printf '    enum_%02d.enum_decl_variants = &variants[%d] as &EnumVariant;\n' "$i" "$i" >>"$tmp_dir/main.uya"
    printf '    enum_%02d.enum_decl_variant_count = 1;\n' "$i" >>"$tmp_dir/main.uya"
    printf '    decls[%d] = &enum_%02d;\n' "$slot_enum" "$i" >>"$tmp_dir/main.uya"
    printf '    var use_%02d: ASTNode = semantic_test_node(ASTNodeType.AST_USE_STMT, "phase2.uya", "Use_%02d");\n' "$i" "$i" >>"$tmp_dir/main.uya"
    printf '    decls[%d] = &use_%02d;\n' "$slot_use" "$i" >>"$tmp_dir/main.uya"
done

cat >>"$tmp_dir/main.uya" <<'EOF'

    var program: ASTNode = semantic_test_node(ASTNodeType.AST_PROGRAM, "phase2.uya", null);
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 160;

    var db: SemanticDb = semantic_test_db();
    try assert_eq_i32(semantic_db_build_from_merged_ast(&db, &program), 0);
    try assert_eq_i32(db.decl_count, 160);
    try assert_eq_i32(db.symbol_count, 120);
    try assert_eq_i32(db.function_count, 40);
    try assert_eq_i32(db.type_count, 80);
    try assert_eq_i32(semantic_db_decl_range_count(&db), 120);
    try assert_eq_i32(semantic_db_function_overload_range_count(&db), 40);
    try assert_eq_i32(semantic_db_type_decl_range_count(&db), 80);
    try assert_eq_i32(semantic_db_enum_variant_range_count(&db), 40);
    try assert_eq_i32(semantic_db_enum_variant_record_count(&db), 40);
    try assert_eq_i32(semantic_db_import_binding_count(&db), 40);
    try assert_eq_i32(semantic_db_export_binding_count(&db), 120);

    try expect_hash_grew(&db.decls_by_name, 120);
    try expect_hash_grew(&db.functions_by_name, 40);
    try expect_hash_grew(&db.types_by_name, 80);
    try expect_hash_grew(&db.enum_variants_by_name, 40);
    try expect_hash_grew(&db.exports_by_module_name, 120);
    try expect_hash_grew(&db.aliases_by_file_name, 40);
    try expect_hash_grew(&db.use_items_by_file_name, 40);

    try expect(db.decl_range_ids.capacity >= 120usize);
    try expect(db.function_range_decl_ids.capacity >= 40usize);
    try expect(db.type_range_decl_ids.capacity >= 80usize);
    try expect(db.enum_variant_range_record_ids.capacity >= 40usize);
    try expect(db.decl_range_ids.realloc_count > 1);
    try expect(db.function_range_decl_ids.realloc_count > 1);
    try expect(db.type_range_decl_ids.realloc_count > 1);
    try expect(db.enum_variant_range_record_ids.realloc_count > 1);

    const fn_name_id: i32 = semantic_intern_find(&db.name_intern, "fn_39");
    const alias_name_id: i32 = semantic_intern_find(&db.name_intern, "Alias_39");
    const enum_name_id: i32 = semantic_intern_find(&db.name_intern, "Enum_39");
    const variant_name_id: i32 = semantic_intern_find(&db.name_intern, "Variant_39");
    const use_name_id: i32 = semantic_intern_find(&db.name_intern, "Use_39");
    try expect(fn_name_id >= 0);
    try expect(alias_name_id >= 0);
    try expect(enum_name_id >= 0);
    try expect(variant_name_id >= 0);
    try expect(use_name_id >= 0);

    var range_id: i32 = -1;
    try assert_eq_i32(semantic_hash_get(&db.functions_by_name, fn_name_id as i64, &range_id), 1);
    try expect(range_id >= 0);
    range_id = -1;
    try assert_eq_i32(semantic_hash_get(&db.types_by_name, alias_name_id as i64, &range_id), 1);
    try expect(range_id >= 0);
    range_id = -1;
    try assert_eq_i32(semantic_hash_get(&db.enum_variants_by_name, variant_name_id as i64, &range_id), 1);
    try expect(range_id >= 0);

    try expect_decl_range_decl_id(&db, fn_name_id, 39);
    try expect_decl_range_decl_id(&db, alias_name_id, 79);
    try expect_decl_range_decl_id(&db, enum_name_id, 119);
    try expect_function_range_decl_id(&db, fn_name_id, 39);
    try expect_type_range_decl_id(&db, alias_name_id, 79);
    try expect_type_range_decl_id(&db, enum_name_id, 119);
    try expect_enum_variant_record(&db, variant_name_id, 39, 119);

    var symbol_id: i32 = -1;
    try assert_eq_i32(semantic_db_find_export_symbol(&db, 0, enum_name_id, &symbol_id), 1);
    try expect(symbol_id >= 0);
    try expect_export_symbol_decl(&db, 0, enum_name_id, 119, 119);

    var alias_decl_id: i32 = -1;
    try assert_eq_i32(semantic_db_find_file_alias_decl(&db, 0, alias_name_id, &alias_decl_id), 1);
    try assert_eq_i32(alias_decl_id, 79);

    var use_binding_id: i32 = -1;
    try assert_eq_i32(semantic_db_find_file_use_item_binding(&db, 0, use_name_id, &use_binding_id), 1);
    try assert_eq_i32(use_binding_id, 39);

    semantic_db_release(&db);
}

test "phase 2 semantic indexes handle high hash collisions without program scan" {
    var db: SemanticDb = semantic_test_db();
    semantic_db_init(&db);

    try append_phase2_collision_indexes(&db);
    try assert_eq_i32(db.decls_by_name.count as i32, PHASE2_COLLISION_COUNT);
    try assert_eq_i32(db.functions_by_name.count as i32, PHASE2_COLLISION_COUNT);
    try assert_eq_i32(db.types_by_name.count as i32, PHASE2_COLLISION_COUNT);
    try assert_eq_i32(db.enum_variants_by_name.count as i32, PHASE2_COLLISION_COUNT);
    try assert_eq_i32(db.exports_by_module_name.count as i32, PHASE2_COLLISION_COUNT);
    try assert_eq_i32(db.aliases_by_file_name.count as i32, PHASE2_COLLISION_COUNT);
    try assert_eq_i32(db.use_items_by_file_name.count as i32, PHASE2_COLLISION_COUNT);

    try expect(db.decls_by_name.capacity >= PHASE2_COLLISION_BUCKET);
    try expect(db.functions_by_name.capacity >= PHASE2_COLLISION_BUCKET);
    try expect(db.types_by_name.capacity >= PHASE2_COLLISION_BUCKET);
    try expect(db.enum_variants_by_name.capacity >= PHASE2_COLLISION_BUCKET);
    try expect(db.exports_by_module_name.capacity >= PHASE2_COLLISION_BUCKET);
    try expect(db.aliases_by_file_name.capacity >= PHASE2_COLLISION_BUCKET);
    try expect(db.use_items_by_file_name.capacity >= PHASE2_COLLISION_BUCKET);

    const name_id: i32 = phase2_collision_name_id(PHASE2_COLLISION_COUNT - 1);
    try expect(name_id >= 0);
    try expect_decl_range_decl_id(&db, name_id, 1023);
    try expect_function_range_decl_id(&db, name_id, 2023);
    try expect_type_range_decl_id(&db, name_id, 3023);
    try expect_enum_variant_record(&db, name_id, 23, 4023);
    try expect_export_symbol_decl(&db, 0, name_id, 23, 5023);

    var alias_decl_id: i32 = -1;
    try assert_eq_i32(semantic_db_find_file_alias_decl(&db, 0, name_id, &alias_decl_id), 1);
    try assert_eq_i32(alias_decl_id, 6023);

    var use_binding_id: i32 = -1;
    try assert_eq_i32(semantic_db_find_file_use_item_binding(&db, 0, name_id, &use_binding_id), 1);
    try assert_eq_i32(use_binding_id, 7023);

    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb Phase 2 dynamic index checks passed"
