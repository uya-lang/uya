#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$INTERN_FILE"; then
        echo "错误: semantic intern 缺少证据: $description" >&2
        return 1
    fi
}

reject_pattern() {
    local pattern="$1"
    local description="$2"
    if grep -Eq "$pattern" "$INTERN_FILE"; then
        echo "错误: semantic intern 不应包含: $description" >&2
        return 1
    fi
}

if [[ ! -f "$INTERN_FILE" ]]; then
    echo "错误: 缺少 $INTERN_FILE" >&2
    exit 1
fi

require_pattern "^export[[:space:]]+struct[[:space:]]+SemanticInternTable" "SemanticInternTable"
require_pattern "semantic_intern_get_or_put" "get_or_put API"
require_pattern "semantic_intern_find" "find API"
require_pattern "semantic_intern_name" "name lookup API"
require_pattern "semantic_intern_reserve" "reserve API"
require_pattern "semantic_intern_realloc_count" "realloc_count 统计"
require_pattern "semantic_intern_load_limit" "负载因子阈值 helper"
reject_pattern "4096|8192" "固定 4096/8192 intern 槽上限"

tmp_dir="$(mktemp -d /tmp/uya-semantic-intern.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cp "$INTERN_FILE" "$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

test "semantic intern table interns and grows" {
    var table: SemanticInternTable = SemanticInternTable{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
        string_bytes: 0usize,
    };
    semantic_intern_init(&table);
    const alpha1: i32 = semantic_intern_get_or_put(&table, "alpha");
    const beta: i32 = semantic_intern_get_or_put(&table, "beta");
    const alpha2: i32 = semantic_intern_get_or_put(&table, "alpha");
    try expect(alpha1 >= 0);
    try expect(beta >= 0);
    try assert_eq_i32(alpha1, alpha2);
    try assert_eq_i32(semantic_intern_find(&table, "beta"), beta);
    try assert_eq_i32(semantic_intern_find(&table, "missing"), -1);
    try expect(semantic_intern_name(&table, alpha1) != null);
EOF

for i in $(seq 0 79); do
    printf '    try expect(semantic_intern_get_or_put(&table, "name_%03d") >= 0);\n' "$i" >>"$tmp_dir/main.uya"
done

cat >>"$tmp_dir/main.uya" <<'EOF'
    try expect(table.count >= 82usize);
    try expect(table.capacity > 8usize);
    try expect(table.realloc_count > 0);
    try expect(table.string_bytes > 0usize);
    semantic_intern_free(&table);
    try assert_eq_i32(table.count as i32, 0);
    try assert_eq_i32(table.capacity as i32, 0);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ semantic intern table smoke passed"
