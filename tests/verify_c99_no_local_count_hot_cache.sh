#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GLOBAL_FILE="$REPO_ROOT/src/codegen/c99/global.uya"
TYPES_FILE="$REPO_ROOT/src/codegen/c99/types.uya"
COMPILER="$REPO_ROOT/bin/uya"

for file in "$GLOBAL_FILE" "$TYPES_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: C99 后端仍包含按 local_variable_count 参与 key 的热点缓存: $description" >&2
        exit 1
    fi
}

reject_pattern "$GLOBAL_FILE" "g_c99_ident_ref_local_counts" "identifier-ref cache 仍保留 local-count key 字段"
reject_pattern "$TYPES_FILE" "g_c99_identifier_type_local_counts" "identifier-type cache 仍保留 local-count key 字段"
reject_pattern "$GLOBAL_FILE" "local_variable_count[[:space:]]*\\*" "identifier-ref cache hash 仍拼接 local_variable_count"
reject_pattern "$TYPES_FILE" "local_variable_count[[:space:]]*\\*" "identifier-type cache hash 仍拼接 local_variable_count"

lookup_body="$(awk '/fn lookup_identifier_type_c_impl/{flag=1} flag{print} flag && /^}/{exit}' "$TYPES_FILE")"
if grep -Eq "local_variable_count|use_ident_cache" <<<"$lookup_body"; then
    echo "错误: lookup_identifier_type_c_impl 仍接入旧 local-count 热点缓存" >&2
    exit 1
fi

ref_body="$(awk '/fn get_c_name_for_identifier_ref/{flag=1} flag{print} flag && /^}/{exit}' "$GLOBAL_FILE")"
if grep -Eq "local_variable_count[[:space:]]*==" <<<"$ref_body"; then
    echo "错误: get_c_name_for_identifier_ref 仍接入旧 local-count 热点缓存" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-c99-no-local-count-cache.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
var global_arr: [i32: 2] = [11, 12];

fn pick(values: &[i32]) i32 {
    return values[1];
}

export fn main() i32 {
    var local_arr: [i32: 2] = [21, 22];
    if pick(&local_arr[0:2]) != 22 {
        return 1;
    }
    if global_arr[0] != 11 {
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

echo "✓ C99 local_variable_count hot caches are disabled"
