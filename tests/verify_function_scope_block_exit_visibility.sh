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
        echo "错误: block exit visibility 测试缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$SCOPE_FILE" "function_scope_index_exit_scope" "FunctionScopeIndex 退出 block scope"
require_pattern "$SCOPE_FILE" "binding.previous_binding_id" "退出 block 时恢复 previous binding"
require_pattern "$SCOPE_FILE" "binding_id < 0" "无外层 binding 时查询不可见"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-block-exit.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;
EOF
    cat "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE"
    cat <<'EOF'

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

fn expect_not_visible(index: &FunctionScopeIndex, name: &byte) !void {
    var binding: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(index, name, &binding), 0);
}

fn expect_visible_local(index: &FunctionScopeIndex, name: &byte, expected_depth: i32) !void {
    var binding: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(index, name, &binding), 1);
    try assert_eq_i32(binding.kind, FUNCTION_SCOPE_BINDING_LOCAL);
    try assert_eq_i32(binding.depth, expected_depth);
}

test "function scope block exit hides locals without outer bindings" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);

    try expect_not_visible(&index, "hidden");
    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    const hidden_id: i32 = function_scope_index_add_local(&index, "hidden", null, null);
    try expect(hidden_id >= 0);
    try expect_visible_local(&index, "hidden", 1);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), 1);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try expect_not_visible(&index, "hidden");
    try assert_eq_i32(function_scope_index_binding_count(&index), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), 0);
    try assert_eq_i32(function_scope_index_current_depth(&index), 0);

    function_scope_index_release(&index);
}

test "function scope nested block exit hides only the exited depth" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);

    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    const outer_id: i32 = function_scope_index_add_local(&index, "outer", null, null);
    try expect(outer_id >= 0);
    try expect_visible_local(&index, "outer", 1);

    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    const deep_id: i32 = function_scope_index_add_local(&index, "deep", null, null);
    try expect(deep_id > outer_id);
    try expect_visible_local(&index, "deep", 2);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try expect_not_visible(&index, "deep");
    try expect_visible_local(&index, "outer", 1);
    try assert_eq_i32(function_scope_index_binding_count(&index), 1);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try expect_not_visible(&index, "outer");
    try assert_eq_i32(function_scope_index_binding_count(&index), 0);

    function_scope_index_release(&index);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && "$COMPILER" test "$tmp_dir/main.uya" --no-split-c)

echo "✓ FunctionScopeIndex hides block-local bindings after block exit"
