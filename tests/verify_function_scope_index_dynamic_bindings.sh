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
        echo "错误: FunctionScopeIndex 动态 binding 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "param_binding_ids:[[:space:]]+SemanticVector" "params 动态 ID 列表"
require_pattern "local_binding_ids:[[:space:]]+SemanticVector" "locals 动态 ID 列表"
require_pattern "capture_binding_ids:[[:space:]]+SemanticVector" "captures 动态 ID 列表"
require_pattern "async_binding_ids:[[:space:]]+SemanticVector" "async bindings 动态 ID 列表"
require_pattern "function_scope_index_add_param" "参数追加 API"
require_pattern "function_scope_index_add_local" "局部变量追加 API"
require_pattern "function_scope_index_add_capture" "capture 追加 API"
require_pattern "function_scope_index_add_async_binding" "async binding 追加 API"
require_pattern "function_scope_index_kind_capacity" "分类容量统计 API"
require_pattern "function_scope_index_kind_realloc_count" "分类扩容统计 API"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-bindings.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;
EOF
    cat "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE"
    cat <<'EOF'

const FUNCTION_SCOPE_DYNAMIC_COUNT: i32 = 96;
const FUNCTION_SCOPE_DYNAMIC_TOTAL: i32 = 384;

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

fn expect_kind_growth(index: &FunctionScopeIndex, kind: i32, expected: i32) !void {
    try assert_eq_i32(function_scope_index_kind_count(index, kind), expected);
    try expect(function_scope_index_kind_capacity(index, kind) >= expected);
    try expect(function_scope_index_kind_realloc_count(index, kind) > 1);
}

test "function scope binding categories grow independently" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);
EOF

    for i in $(seq 0 95); do
        printf '    const param_id_%03d: i32 = function_scope_index_add_param(&index, "param_%03d", null, null);\n' "$i" "$i"
        printf '    try expect(param_id_%03d >= 0);\n' "$i"
    done

    cat <<'EOF'
    try expect_kind_growth(&index, FUNCTION_SCOPE_BINDING_PARAM, FUNCTION_SCOPE_DYNAMIC_COUNT);
    try expect_scope_binding(&index, "param_000", FUNCTION_SCOPE_BINDING_PARAM, 0);
    try expect_scope_binding(&index, "param_095", FUNCTION_SCOPE_BINDING_PARAM, 0);

    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
EOF

    for i in $(seq 0 95); do
        printf '    const local_id_%03d: i32 = function_scope_index_add_local(&index, "local_%03d", null, null);\n' "$i" "$i"
        printf '    try expect(local_id_%03d >= 0);\n' "$i"
    done
    for i in $(seq 0 95); do
        printf '    const capture_id_%03d: i32 = function_scope_index_add_capture(&index, "capture_%03d", null, null);\n' "$i" "$i"
        printf '    try expect(capture_id_%03d >= 0);\n' "$i"
    done
    for i in $(seq 0 95); do
        printf '    const async_id_%03d: i32 = function_scope_index_add_async_binding(&index, "async_%03d", null, null);\n' "$i" "$i"
        printf '    try expect(async_id_%03d >= 0);\n' "$i"
    done

    cat <<'EOF'
    try expect_kind_growth(&index, FUNCTION_SCOPE_BINDING_LOCAL, FUNCTION_SCOPE_DYNAMIC_COUNT);
    try expect_kind_growth(&index, FUNCTION_SCOPE_BINDING_CAPTURE, FUNCTION_SCOPE_DYNAMIC_COUNT);
    try expect_kind_growth(&index, FUNCTION_SCOPE_BINDING_ASYNC, FUNCTION_SCOPE_DYNAMIC_COUNT);
    try expect_scope_binding(&index, "local_095", FUNCTION_SCOPE_BINDING_LOCAL, 1);
    try expect_scope_binding(&index, "capture_095", FUNCTION_SCOPE_BINDING_CAPTURE, 1);
    try expect_scope_binding(&index, "async_095", FUNCTION_SCOPE_BINDING_ASYNC, 1);
    try assert_eq_i32(function_scope_index_binding_count(&index), FUNCTION_SCOPE_DYNAMIC_TOTAL);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try assert_eq_i32(function_scope_index_binding_count(&index), FUNCTION_SCOPE_DYNAMIC_COUNT);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_PARAM), FUNCTION_SCOPE_DYNAMIC_COUNT);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_CAPTURE), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_ASYNC), 0);

    var missing: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(&index, "local_095", &missing), 0);
    try expect_scope_binding(&index, "param_095", FUNCTION_SCOPE_BINDING_PARAM, 0);

    function_scope_index_release(&index);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_PARAM), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_LOCAL), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_CAPTURE), 0);
    try assert_eq_i32(function_scope_index_kind_count(&index, FUNCTION_SCOPE_BINDING_ASYNC), 0);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && "$COMPILER" test "$tmp_dir/main.uya" --no-split-c)

echo "✓ FunctionScopeIndex params/locals/captures/async bindings grow dynamically"
