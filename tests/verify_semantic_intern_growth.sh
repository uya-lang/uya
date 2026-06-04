#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"

if [[ ! -f "$INTERN_FILE" ]]; then
    echo "错误: 缺少 $INTERN_FILE" >&2
    exit 1
fi

if grep -Eq "4096|8192" "$INTERN_FILE"; then
    echo "错误: intern 表不得使用固定 4096/8192 槽作为语义上限" >&2
    exit 1
fi

if ! grep -Eq "semantic_intern_load_limit" "$INTERN_FILE"; then
    echo "错误: intern 表缺少负载因子阈值 helper" >&2
    exit 1
fi

if ! grep -Eq "next_count[[:space:]]*>=[[:space:]]*semantic_intern_load_limit" "$INTERN_FILE"; then
    echo "错误: intern 插入路径未按负载因子触发扩容" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-semantic-intern-growth.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cp "$INTERN_FILE" "$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

test "semantic intern grows at load factor threshold" {
    var table: SemanticInternTable = SemanticInternTable{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
        string_bytes: 0usize,
    };
    semantic_intern_init(&table);
    try assert_eq_i32(semantic_intern_reserve(&table, 8usize), 0);
    try assert_eq_i32(table.capacity as i32, 8);
    try assert_eq_i32(semantic_intern_load_limit(table.capacity) as i32, 6);
    try expect(semantic_intern_get_or_put(&table, "n0") >= 0);
    try expect(semantic_intern_get_or_put(&table, "n1") >= 0);
    try expect(semantic_intern_get_or_put(&table, "n2") >= 0);
    try expect(semantic_intern_get_or_put(&table, "n3") >= 0);
    try expect(semantic_intern_get_or_put(&table, "n4") >= 0);
    try assert_eq_i32(table.capacity as i32, 8);
    try expect(semantic_intern_get_or_put(&table, "n5") >= 0);
    try expect(table.capacity > 8usize);
    try expect(table.realloc_count >= 2);
    semantic_intern_free(&table);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ semantic intern table grows by load factor without fixed slot limits"
