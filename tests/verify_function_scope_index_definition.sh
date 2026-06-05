#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"
SCOPE_FILE="$REPO_ROOT/src/checker/function_scope.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$SCOPE_FILE"; then
        echo "错误: FunctionScopeIndex 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "^export[[:space:]]+struct[[:space:]]+FunctionScopeIndex" "FunctionScopeIndex 结构"
require_pattern "SemanticVector" "动态 binding/scope frame 存储"
require_pattern "SemanticHash" "按名字查询 hash"
require_pattern "SemanticInternTable" "名字 intern 表"
require_pattern "function_scope_index_enter_scope" "进入作用域 API"
require_pattern "function_scope_index_exit_scope" "退出作用域 API"
require_pattern "function_scope_index_add_binding" "追加 binding API"
require_pattern "function_scope_index_find_binding" "查询 binding API"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-index.XXXXXX)"
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

fn expect_scope_binding(index: &FunctionScopeIndex, name: &byte, kind: i32, depth: i32) !void {
    var binding: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(index, name, &binding), 1);
    try assert_eq_i32(binding.kind, kind);
    try assert_eq_i32(binding.depth, depth);
}

test "function scope index shadows and restores bindings" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);
    try assert_eq_i32(function_scope_index_scope_count(&index), 1);

    const root_id: i32 = function_scope_index_add_binding(&index, "item", FUNCTION_SCOPE_BINDING_PARAM, null, null);
    try expect(root_id >= 0);
    try expect_scope_binding(&index, "item", FUNCTION_SCOPE_BINDING_PARAM, 0);

    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    const local_id: i32 = function_scope_index_add_binding(&index, "item", FUNCTION_SCOPE_BINDING_LOCAL, null, null);
    try expect(local_id > root_id);
    try expect_scope_binding(&index, "item", FUNCTION_SCOPE_BINDING_LOCAL, 1);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try expect_scope_binding(&index, "item", FUNCTION_SCOPE_BINDING_PARAM, 0);
    try assert_eq_i32(function_scope_index_binding_count(&index), 1);

    try assert_eq_i32(function_scope_index_reset(&index), 0);
    var missing: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(&index, "item", &missing), 0);
    try assert_eq_i32(function_scope_index_scope_count(&index), 1);

    function_scope_index_release(&index);
    try assert_eq_i32(function_scope_index_binding_count(&index), 0);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && "$COMPILER" test "$tmp_dir/main.uya" --no-split-c)

echo "✓ FunctionScopeIndex definition and basic scope behavior verified"
