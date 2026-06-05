#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"
SCOPE_FILE="$REPO_ROOT/src/checker/function_scope.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: FunctionScopeIndex growth stress missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$SCOPE_FILE" "local_binding_ids:[[:space:]]+SemanticVector" "locals use dynamic vectors"
require_pattern "$SCOPE_FILE" "async_binding_ids:[[:space:]]+SemanticVector" "async bindings use dynamic vectors"
require_pattern "$SCOPE_FILE" "scope_frames:[[:space:]]+SemanticVector" "block frames use dynamic vectors"
require_pattern "$SCOPE_FILE" "function_scope_index_binding_capacity" "binding capacity query"
require_pattern "$SCOPE_FILE" "function_scope_index_kind_realloc_count" "kind realloc query"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-growth-stress.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;
EOF
    cat "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE"
    cat <<'EOF'

const MANY_LOCALS_COUNT: i32 = 1050;
const DEEP_BLOCK_DEPTH: i32 = 192;
const ASYNC_LOCAL_COUNT: i32 = 192;

fn empty_scope_binding() FunctionScopeBinding {
    return FunctionScopeBinding{
        name_id: -1,
        name: null,
        type_node: null,
        decl_node: null,
        depth: -1,
        generation: -1,
        kind: -1,
        previous_binding_id: -1,
    };
}

fn expect_binding(index: &FunctionScopeIndex, name: &byte, expected_kind: i32, expected_depth: i32) !void {
    var binding: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(index, name, &binding), 1);
    try assert_eq_i32(binding.kind, expected_kind);
    try assert_eq_i32(binding.depth, expected_depth);
}

fn expect_missing(index: &FunctionScopeIndex, name: &byte) !void {
    var binding: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(index, name, &binding), 0);
}

fn expect_vector_growth(vec: &SemanticVector, expected_count: i32) !void {
    try expect(vec.count as i32 >= expected_count);
    try expect(vec.capacity >= expected_count as usize);
    try expect(vec.realloc_count > 1);
}

test "function scope grows past legacy local pressure" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);
    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    var binding_id: i32 = -1;
EOF

    i=0
    for i in $(seq 0 1049); do
        printf '    binding_id = function_scope_index_add_local(&index, "local_pressure_%04d", null, null);\n' "$i"
        printf '    try expect(binding_id >= 0);\n'
    done

    cat <<'EOF'
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), MANY_LOCALS_COUNT);
    try assert_eq_i32(function_scope_index_binding_count(&index), MANY_LOCALS_COUNT);
    try expect(function_scope_index_binding_capacity(&index) >= MANY_LOCALS_COUNT);
    try expect(function_scope_index_kind_capacity(&index, FUNCTION_SCOPE_BINDING_LOCAL) >= MANY_LOCALS_COUNT);
    try expect(function_scope_index_kind_realloc_count(&index, FUNCTION_SCOPE_BINDING_LOCAL) > 1);
    try expect(index.bindings.realloc_count > 1);
    try expect_binding(&index, "local_pressure_0000", FUNCTION_SCOPE_BINDING_LOCAL, 1);
    try expect_binding(&index, "local_pressure_1049", FUNCTION_SCOPE_BINDING_LOCAL, 1);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try assert_eq_i32(function_scope_index_binding_count(&index), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), 0);
    try expect_missing(&index, "local_pressure_1049");

    function_scope_index_release(&index);
}

test "function scope frames grow under deep block nesting" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);

    var depth: i32 = 0;
    while depth < DEEP_BLOCK_DEPTH {
        try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
        depth = depth + 1;
        const local_id: i32 = function_scope_index_add_local(&index, "deep_shadow", null, null);
        try expect(local_id >= 0);
        try expect_binding(&index, "deep_shadow", FUNCTION_SCOPE_BINDING_LOCAL, depth);
    }

    try assert_eq_i32(function_scope_index_current_depth(&index), DEEP_BLOCK_DEPTH);
    try assert_eq_i32(function_scope_index_scope_count(&index), DEEP_BLOCK_DEPTH + 1);
    try assert_eq_i32(function_scope_index_binding_count(&index), DEEP_BLOCK_DEPTH);
    try expect_vector_growth(&index.scope_frames, DEEP_BLOCK_DEPTH + 1);
    try expect_vector_growth(&index.bindings, DEEP_BLOCK_DEPTH);

    while depth > 0 {
        try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
        depth = depth - 1;
        if depth > 0 {
            try expect_binding(&index, "deep_shadow", FUNCTION_SCOPE_BINDING_LOCAL, depth);
        } else {
            try expect_missing(&index, "deep_shadow");
        }
    }

    try assert_eq_i32(function_scope_index_current_depth(&index), 0);
    try assert_eq_i32(function_scope_index_scope_count(&index), 1);
    try assert_eq_i32(function_scope_index_binding_count(&index), 0);

    function_scope_index_release(&index);
}

test "function scope async bindings and async locals grow together" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);
    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    var async_binding_id: i32 = -1;
    var async_local_binding_id: i32 = -1;
EOF

    for i in $(seq 0 191); do
        printf '    async_binding_id = function_scope_index_add_async_binding(&index, "await_value_%03d", null, null);\n' "$i"
        printf '    try expect(async_binding_id >= 0);\n'
        printf '    async_local_binding_id = function_scope_index_add_local(&index, "async_local_%03d", null, null);\n' "$i"
        printf '    try expect(async_local_binding_id >= 0);\n'
    done

    cat <<'EOF'
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_ASYNC), ASYNC_LOCAL_COUNT);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), ASYNC_LOCAL_COUNT);
    try assert_eq_i32(function_scope_index_binding_count(&index), ASYNC_LOCAL_COUNT * 2);
    try expect(function_scope_index_kind_capacity(&index, FUNCTION_SCOPE_BINDING_ASYNC) >= ASYNC_LOCAL_COUNT);
    try expect(function_scope_index_kind_capacity(&index, FUNCTION_SCOPE_BINDING_LOCAL) >= ASYNC_LOCAL_COUNT);
    try expect(function_scope_index_kind_realloc_count(&index, FUNCTION_SCOPE_BINDING_ASYNC) > 1);
    try expect(function_scope_index_kind_realloc_count(&index, FUNCTION_SCOPE_BINDING_LOCAL) > 1);
    try expect(index.bindings.realloc_count > 1);
    try expect_binding(&index, "await_value_000", FUNCTION_SCOPE_BINDING_ASYNC, 1);
    try expect_binding(&index, "await_value_191", FUNCTION_SCOPE_BINDING_ASYNC, 1);
    try expect_binding(&index, "async_local_000", FUNCTION_SCOPE_BINDING_LOCAL, 1);
    try expect_binding(&index, "async_local_191", FUNCTION_SCOPE_BINDING_LOCAL, 1);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try assert_eq_i32(function_scope_index_binding_count(&index), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_ASYNC), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), 0);
    try expect_missing(&index, "await_value_191");
    try expect_missing(&index, "async_local_191");

    function_scope_index_release(&index);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && "$COMPILER" test "$tmp_dir/main.uya" --no-split-c)

echo "✓ FunctionScopeIndex dynamic growth stress covers many locals, deep blocks, and async locals"
