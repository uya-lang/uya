#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$TABLE_FILE"; then
        echo "错误: semantic table growth failure 缺少证据: $description" >&2
        return 1
    fi
}

if [[ ! -f "$TABLE_FILE" ]]; then
    echo "错误: 缺少 $TABLE_FILE" >&2
    exit 1
fi

require_pattern "semantic_table_add_overflows" "加法溢出检查 helper"
require_pattern "semantic_table_mul_overflows" "乘法溢出检查 helper"
require_pattern "if[[:space:]]+new_data[[:space:]]*==[[:space:]]*null" "vector realloc failure 检查"
require_pattern "if[[:space:]]+new_entries[[:space:]]*==[[:space:]]*null" "hash allocation failure 检查"
require_pattern "return[[:space:]]+-1;" "失败路径必须返回错误"

tmp_dir="$(mktemp -d /tmp/uya-semantic-table-growth.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cp "$TABLE_FILE" "$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

test "semantic table growth rejects overflow" {
    var vec: SemanticVector = SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
    semantic_vector_init(&vec, @size_of(i32));
    const huge_vec_capacity: usize = (SEMANTIC_TABLE_MAX_BYTES / @size_of(i32)) + 1usize;
    try assert_eq_i32(semantic_vector_reserve(&vec, huge_vec_capacity), -1);
    try assert_eq_i32(vec.capacity as i32, 0);
    try assert_eq_i32(vec.realloc_count, 0);

    var hash: SemanticHash = SemanticHash{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
    semantic_hash_init(&hash);
    const huge_hash_capacity: usize = (SEMANTIC_TABLE_MAX_BYTES / @size_of(SemanticHashEntry)) + 1usize;
    try assert_eq_i32(semantic_hash_reserve(&hash, huge_hash_capacity), -1);
    try assert_eq_i32(hash.capacity as i32, 0);
    try assert_eq_i32(hash.realloc_count, 0);

    try expect(semantic_vector_append(null, null) == -1);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ semantic table growth rejects overflow and checks allocation failure"
