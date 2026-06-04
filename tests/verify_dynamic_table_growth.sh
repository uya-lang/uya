#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
TMP_DIR=""

cleanup() {
    if [[ -n "${TMP_DIR:-}" && "$TMP_DIR" == /tmp/uya-dynamic-table-growth.* ]]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

run_check() {
    local script="$1"
    local path="$SCRIPT_DIR/$script"
    if [[ ! -x "$path" ]]; then
        echo "错误: 缺少可执行验证脚本: $path" >&2
        exit 1
    fi
    echo "== $script =="
    bash "$path"
}

verify_large_legacy_counts() {
    if [[ ! -f "$TABLE_FILE" ]]; then
        echo "错误: 缺少 $TABLE_FILE" >&2
        exit 1
    fi

    TMP_DIR="$(mktemp -d /tmp/uya-dynamic-table-growth.XXXXXX)"
    cp "$TABLE_FILE" "$TMP_DIR/main.uya"
    cat >>"$TMP_DIR/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_FUNCTION_TABLE_SIZE: i32 = 4097;
const OVER_C99_LOCAL_VARS: i32 = 1025;
const OVER_EXEC_LOCALS: i32 = 257;
const OVER_MONO_INSTANCES: i32 = 513;

fn dynamic_growth_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn dynamic_growth_append_i32(vec: &SemanticVector, count: i32) !void {
    var i: i32 = 0;
    while i < count {
        var value: i32 = i;
        try assert_eq_i32(semantic_vector_append(vec, &value as &const void), 0);
        i = i + 1;
    }
}

fn dynamic_growth_verify_count(vec: &SemanticVector, expected: i32) !void {
    try assert_eq_i32(vec.count as i32, expected);
    try expect(vec.capacity >= expected as usize);
    try expect(vec.realloc_count > 0);
}

test "dynamic vectors exceed legacy compiler table capacities" {
    var decls: SemanticVector = dynamic_growth_vector();
    var functions: SemanticVector = dynamic_growth_vector();
    var c99_locals: SemanticVector = dynamic_growth_vector();
    var exec_locals: SemanticVector = dynamic_growth_vector();
    var mono_instances: SemanticVector = dynamic_growth_vector();

    semantic_vector_init(&decls, @size_of(i32));
    semantic_vector_init(&functions, @size_of(i32));
    semantic_vector_init(&c99_locals, @size_of(i32));
    semantic_vector_init(&exec_locals, @size_of(i32));
    semantic_vector_init(&mono_instances, @size_of(i32));

    try dynamic_growth_append_i32(&decls, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_append_i32(&functions, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_append_i32(&c99_locals, OVER_C99_LOCAL_VARS);
    try dynamic_growth_append_i32(&exec_locals, OVER_EXEC_LOCALS);
    try dynamic_growth_append_i32(&mono_instances, OVER_MONO_INSTANCES);

    try dynamic_growth_verify_count(&decls, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_verify_count(&functions, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_verify_count(&c99_locals, OVER_C99_LOCAL_VARS);
    try dynamic_growth_verify_count(&exec_locals, OVER_EXEC_LOCALS);
    try dynamic_growth_verify_count(&mono_instances, OVER_MONO_INSTANCES);

    semantic_vector_release(&decls);
    semantic_vector_release(&functions);
    semantic_vector_release(&c99_locals);
    semantic_vector_release(&exec_locals);
    semantic_vector_release(&mono_instances);
}
EOF

    (cd "$REPO_ROOT" && ./bin/uya test "$TMP_DIR/main.uya" --no-split-c)
    echo "✓ dynamic vectors exceed legacy declaration/function/local/mono capacities"
}

verify_large_legacy_counts
run_check "verify_semantic_table_growth_failures.sh"
run_check "verify_semantic_intern_growth.sh"
run_check "verify_semantic_db_dynamic_growth.sh"

echo "✓ dynamic table growth aggregate checks passed"
