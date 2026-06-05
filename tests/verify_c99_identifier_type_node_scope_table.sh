#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXPR_FILE="$REPO_ROOT/src/codegen/c99/expr.uya"
TYPES_FILE="$REPO_ROOT/src/codegen/c99/types.uya"
GLOBAL_FILE="$REPO_ROOT/src/codegen/c99/global.uya"
FUNCTION_FILE="$REPO_ROOT/src/codegen/c99/function.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: C99 identifier type node 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$EXPR_FILE" "$TYPES_FILE" "$GLOBAL_FILE" "$FUNCTION_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TYPES_FILE" "function_scope_index_find_binding\\(&codegen\\.checker\\.function_scope_index" "局部/参数类型节点通过 FunctionScopeIndex 查询"
require_pattern "$TYPES_FILE" "semantic_db_find_global_var_range\\(&codegen\\.checker\\.semantic_db" "全局变量类型节点通过 SemanticDb range 查询"
require_pattern "$TYPES_FILE" "semantic_db_global_var_range_decl_id\\(&codegen\\.checker\\.semantic_db" "全局变量 range 通过 DeclId 读取"
require_pattern "$TYPES_FILE" "semantic_db_decl_ast_node\\(&codegen\\.checker\\.semantic_db" "全局变量 DeclId 映射回 AST"
require_pattern "$EXPR_FILE" "c99_find_scope_identifier_type_node\\(codegen, name\\)" "c99_find_identifier_type_node 读取 scope helper"
require_pattern "$EXPR_FILE" "c99_find_global_identifier_type_node\\(codegen, name\\)" "c99_find_identifier_type_node 读取 global helper"
require_pattern "$GLOBAL_FILE" "function_scope_index_add_local\\(&codegen\\.checker\\.function_scope_index" "C99 局部 push 同步登记 scope 表"
require_pattern "$FUNCTION_FILE" "function_scope_index_reset\\(&codegen\\.checker\\.function_scope_index" "C99 函数入口重置 scope 表"

fn_body="$(awk '/fn c99_find_identifier_type_node/{flag=1} flag{print} flag && /^}/{exit}' "$EXPR_FILE")"
if grep -Eq "local_variable_count|program_decl_count|c99_find_var_decl_type_in_node" <<<"$fn_body"; then
    echo "错误: c99_find_identifier_type_node 仍包含局部/全局线性扫描路径" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-c99-ident-type-node.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
type V4i = @vector(i32, 4);

struct Pair {
    x: i32,
    y: i32,
}

var global_pair: Pair = Pair{ x: 3, y: 4 };

fn from_param(v: V4i) i32 {
    return @vector.reduce_max(v);
}

export fn main() i32 {
    const local_vec: V4i = @vector.splat(7);
    if from_param(local_vec) != 7 {
        return 1;
    }
    if global_pair.x != 3 {
        return 2;
    }
    return 0;
}
EOF

out_c="$tmp_dir/main.c"
out_bin="$tmp_dir/main.bin"
"$COMPILER" build "$tmp_dir/main.uya" --c99 --no-split-c -O0 -o "$out_c" >/dev/null
cc -std=c99 -O0 "$out_c" -o "$out_bin"
"$out_bin"

echo "✓ c99_find_identifier_type_node reads FunctionScopeIndex and SemanticDb global var ranges"
