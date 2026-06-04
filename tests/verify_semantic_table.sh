#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$TABLE_FILE"; then
        echo "错误: semantic table 基础设施缺少证据: $description" >&2
        return 1
    fi
}

if [[ ! -f "$TABLE_FILE" ]]; then
    echo "错误: 缺少 $TABLE_FILE" >&2
    exit 1
fi

require_pattern "^export[[:space:]]+struct[[:space:]]+SemanticVector" "dynamic vector 结构"
require_pattern "^export[[:space:]]+struct[[:space:]]+SemanticHash" "dynamic hash 结构"
require_pattern "^export[[:space:]]+struct[[:space:]]+SemanticRangeBuilder" "range builder 结构"
require_pattern "semantic_vector_append" "vector append API"
require_pattern "semantic_hash_insert" "hash insert API"
require_pattern "semantic_range_builder_append" "range append API"

tmp_dir="$(mktemp -d /tmp/uya-semantic-table.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cp "$TABLE_FILE" "$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

test "semantic vector grows and inserts" {
    var vec: SemanticVector = SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
    semantic_vector_init(&vec, @size_of(i32));
    var i: i32 = 0;
    while i < 20 {
        var value: i32 = i * 2;
        try assert_eq_i32(semantic_vector_append(&vec, &value as &const void), 0);
        i = i + 1;
    }
    var inserted: i32 = 99;
    try assert_eq_i32(semantic_vector_insert(&vec, 3usize, &inserted as &const void), 0);
    const inserted_ptr: &i32 = semantic_vector_item_ptr(&vec, 3usize) as &i32;
    try expect(inserted_ptr != null);
    try assert_eq_i32(inserted_ptr[0], 99);
    const stats: SemanticTableStats = semantic_vector_stats(&vec);
    try assert_eq_i32(stats.count as i32, 21);
    try expect(stats.capacity >= 21usize);
    try expect(stats.bytes >= stats.capacity * @size_of(i32));
    try expect(stats.realloc_count > 0);
    semantic_vector_free(&vec);
    try assert_eq_i32(vec.count as i32, 0);
    try assert_eq_i32(vec.capacity as i32, 0);
}

test "semantic hash grows and updates" {
    var hash: SemanticHash = SemanticHash{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
    semantic_hash_init(&hash);
    var i: i32 = 0;
    while i < 40 {
        try assert_eq_i32(semantic_hash_insert(&hash, i as i64, i + 100), 0);
        i = i + 1;
    }
    try assert_eq_i32(semantic_hash_insert(&hash, 12 as i64, 777), 0);
    var out: i32 = 0;
    try assert_eq_i32(semantic_hash_get(&hash, 12 as i64, &out), 1);
    try assert_eq_i32(out, 777);
    try assert_eq_i32(semantic_hash_get(&hash, 500 as i64, &out), 0);
    const stats: SemanticTableStats = semantic_hash_stats(&hash);
    try assert_eq_i32(stats.count as i32, 40);
    try expect(stats.capacity >= 64usize);
    try expect(stats.realloc_count > 0);
    semantic_hash_free(&hash);
    try assert_eq_i32(hash.count as i32, 0);
    try assert_eq_i32(hash.capacity as i32, 0);
}

test "semantic range builder stores ranges dynamically" {
    var builder: SemanticRangeBuilder = SemanticRangeBuilder{
        ranges: SemanticVector{
            data: null,
            item_size: 0usize,
            count: 0usize,
            capacity: 0usize,
            bytes: 0usize,
            realloc_count: 0,
        },
    };
    semantic_range_builder_init(&builder);
    try assert_eq_i32(semantic_range_builder_append(&builder, 5, 3), 0);
    try assert_eq_i32(semantic_range_builder_append(&builder, 12, 4), 0);
    var out: SemanticRange = SemanticRange{ start: 0, count: 0 };
    try assert_eq_i32(semantic_range_builder_get(&builder, 1usize, &out), 1);
    try assert_eq_i32(out.start, 12);
    try assert_eq_i32(out.count, 4);
    const stats: SemanticTableStats = semantic_range_builder_stats(&builder);
    try assert_eq_i32(stats.count as i32, 2);
    semantic_range_builder_free(&builder);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ semantic table vector/hash/range builder smoke passed"
