#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"
SCOPE_FILE="$REPO_ROOT/src/checker/function_scope.uya"
CHECK_STMT_FILE="$REPO_ROOT/src/checker/check_stmt.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 局部 shadowing 测试缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$TABLE_FILE" "$INTERN_FILE" "$SCOPE_FILE" "$CHECK_STMT_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$SCOPE_FILE" "previous_binding_id" "FunctionScopeIndex 记录被 shadow 的外层 binding"
require_pattern "$SCOPE_FILE" "function_scope_index_exit_scope" "FunctionScopeIndex 退出作用域恢复 binding"
require_pattern "$CHECK_STMT_FILE" "变量遮蔽错误" "语言层同名局部仍然拒绝"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-shadowing.XXXXXX)"
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

fn expect_current_binding(
    index: &FunctionScopeIndex,
    expected_kind: i32,
    expected_depth: i32,
    expected_previous: i32,
) !void {
    var binding: FunctionScopeBinding = empty_scope_binding();
    try assert_eq_i32(function_scope_index_find_binding(index, "value", &binding), 1);
    try assert_eq_i32(binding.kind, expected_kind);
    try assert_eq_i32(binding.depth, expected_depth);
    try assert_eq_i32(binding.previous_binding_id, expected_previous);
}

test "function scope local shadowing restores nearest visible binding" {
    var index: FunctionScopeIndex = function_scope_index_empty();
    try assert_eq_i32(function_scope_index_init(&index), 0);

    const param_id: i32 = function_scope_index_add_param(&index, "value", null, null);
    try expect(param_id >= 0);
    try expect_current_binding(&index, FUNCTION_SCOPE_BINDING_PARAM, 0, -1);

    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    const first_local_id: i32 = function_scope_index_add_local(&index, "value", null, null);
    try expect(first_local_id > param_id);
    try expect_current_binding(&index, FUNCTION_SCOPE_BINDING_LOCAL, 1, param_id);

    try assert_eq_i32(function_scope_index_enter_scope(&index), 0);
    const second_local_id: i32 = function_scope_index_add_local(&index, "value", null, null);
    try expect(second_local_id > first_local_id);
    try expect_current_binding(&index, FUNCTION_SCOPE_BINDING_LOCAL, 2, first_local_id);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try expect_current_binding(&index, FUNCTION_SCOPE_BINDING_LOCAL, 1, param_id);
    try assert_eq_i32(function_scope_index_binding_count(&index), 2);

    try assert_eq_i32(function_scope_index_exit_scope(&index), 0);
    try expect_current_binding(&index, FUNCTION_SCOPE_BINDING_PARAM, 0, -1);
    try assert_eq_i32(function_scope_index_binding_count(&index), 1);

    function_scope_index_release(&index);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && "$COMPILER" test "$tmp_dir/main.uya" --no-split-c)

if (cd "$REPO_ROOT" && "$COMPILER" build tests/error_variable_shadowing.uya --c99 --no-split-c -O0 -o "$tmp_dir/shadowing.c") \
    >"$tmp_dir/error.out" 2>"$tmp_dir/error.err"; then
    echo "错误: tests/error_variable_shadowing.uya 应该编译失败，但当前通过了" >&2
    exit 1
fi

if ! grep -Eq "变量遮蔽错误|shadow" "$tmp_dir/error.out" "$tmp_dir/error.err"; then
    echo "错误: 变量遮蔽失败信息中缺少可识别 diagnostic" >&2
    cat "$tmp_dir/error.out" >&2
    cat "$tmp_dir/error.err" >&2
    exit 1
fi

echo "✓ FunctionScopeIndex local shadowing restore and language-level shadowing diagnostics verified"
