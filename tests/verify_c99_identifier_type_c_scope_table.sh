#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPES_FILE="$REPO_ROOT/src/codegen/c99/types.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: C99 identifier C type 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$TYPES_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TYPES_FILE" "c99_find_scope_identifier_type_node\\(codegen, name\\)" "局部/参数 C 类型通过 scope type-node 查询"
require_pattern "$TYPES_FILE" "c99_find_global_identifier_type_node\\(codegen, name\\)" "全局 C 类型通过 SemanticDb type-node 查询"
require_pattern "$TYPES_FILE" "c99_type_to_c\\(codegen, scope_type_node\\)" "scope type-node 转换为 C 类型"
require_pattern "$TYPES_FILE" "c99_type_to_c\\(codegen, global_type_node\\)" "global type-node 转换为 C 类型"

fn_body="$(awk '/fn lookup_identifier_type_c_impl/{flag=1} flag{print} flag && /^}/{exit}' "$TYPES_FILE")"
if grep -Eq "c99_local_var_name_at|c99_local_var_type_c_at|global_var_name_matches|codegen\\.global_variables\\[i\\]" <<<"$fn_body"; then
    echo "错误: lookup_identifier_type_c_impl 仍包含局部/全局线性扫描路径" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-c99-ident-type-c.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
var global_arr: [i32: 2] = [5, 6];

fn use_param(values: &[i32]) i32 {
    return values[0];
}

export fn main() i32 {
    var local_arr: [i32: 2] = [7, 8];
    if local_arr[1] != 8 {
        return 1;
    }
    if global_arr[0] != 5 {
        return 2;
    }
    if use_param(&local_arr[0:2]) != 7 {
        return 3;
    }
    return 0;
}
EOF

out_c="$tmp_dir/main.c"
out_bin="$tmp_dir/main.bin"
"$COMPILER" build "$tmp_dir/main.uya" --c99 --no-split-c -O0 -o "$out_c" >/dev/null
cc -std=c99 -O0 "$out_c" -o "$out_bin"
"$out_bin"

echo "✓ lookup_identifier_type_c_impl reads FunctionScopeIndex and SemanticDb type nodes"
