#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
DB_FILE="$REPO_ROOT/src/semantic/db.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$DB_FILE"; then
        echo "错误: SemanticDb 定义缺少证据: $description" >&2
        return 1
    fi
}

for file in "$TABLE_FILE" "$DB_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "^export[[:space:]]+struct[[:space:]]+SemanticDb" "SemanticDb 结构"
require_pattern "^export[[:space:]]+struct[[:space:]]+SemanticDeclRecord" "SemanticDeclRecord 结构"
require_pattern "semantic_db_init" "init API"
require_pattern "semantic_db_reset" "reset API"
require_pattern "semantic_db_estimated_bytes" "bytes API"
require_pattern "semantic_db_release" "release API"
require_pattern "file_count" "file_count 字段"
require_pattern "module_count" "module_count 字段"
require_pattern "decl_count" "decl_count 字段"
require_pattern "interned_name_count" "interned_name_count 字段"
require_pattern "decl_records" "decl_records 字段"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$TABLE_FILE" >"$tmp_dir/main.uya"
cat "$DB_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

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

test "semantic db definition initializes and resets" {
    var db: SemanticDb = SemanticDb{
        file_count: 7,
        module_count: 6,
        interned_name_count: 5,
        decl_count: 4,
        symbol_count: 3,
        scope_count: 2,
        type_count: 1,
        expr_count: 9,
        function_count: 8,
        mono_instance_count: 10,
        estimated_bytes: 123usize,
        file_records: semantic_test_vector(),
        module_records: semantic_test_vector(),
        decl_records: semantic_test_vector(),
        symbol_records: semantic_test_vector(),
        name_ranges: semantic_test_vector(),
        name_range_index: semantic_test_hash(),
    };
    semantic_db_init(&db);
    try assert_eq_i32(db.file_count, 0);
    try assert_eq_i32(db.module_count, 0);
    try assert_eq_i32(db.interned_name_count, 0);
    try assert_eq_i32(semantic_db_decl_record_count(&db), 0);
    try assert_eq_i32(semantic_db_estimated_bytes(&db) as i32, 0);
    db.decl_count = 11;
    db.estimated_bytes = 44usize;
    semantic_db_reset(&db);
    try assert_eq_i32(db.decl_count, 0);
    try assert_eq_i32(semantic_db_symbol_record_count(&db), 0);
    try assert_eq_i32(semantic_db_estimated_bytes(&db) as i32, 0);
    semantic_db_release(&db);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ SemanticDb definition smoke passed"
