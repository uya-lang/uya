#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOOKUP_FILE="$REPO_ROOT/src/checker/lookup.uya"
CHECKER_ENTRY_FILE="$REPO_ROOT/src/checker/check_expr_extra.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: Semantic enum variant lookup 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$LOOKUP_FILE" "$CHECKER_ENTRY_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOOKUP_FILE" "g_lookup_semantic_db" "lookup 层持有当前 SemanticDb"
require_pattern "$LOOKUP_FILE" "checker_register_semantic_lookup_db" "checker 注册 SemanticDb lookup 上下文"
require_pattern "$LOOKUP_FILE" "lookup_is_enum_variant_name_from_semantic_db" "enum variant SemanticDb 查询 helper"
require_pattern "$LOOKUP_FILE" "semantic_db_find_enum_variant_range" "通过 SemanticDb enum_variants_by_name 查询 variant range"
require_pattern "$LOOKUP_FILE" "semantic_db_enum_variant_range_record_id" "通过 SemanticDb range 读取 variant record id"
require_pattern "$LOOKUP_FILE" "semantic_db_enum_variant_record_get" "读取 enum variant 记录"
require_pattern "$LOOKUP_FILE" "lookup_is_enum_variant_name_from_semantic_db\\(program_node, name\\)" "is_enum_variant_name_in_program 调用 SemanticDb helper"
require_pattern "$CHECKER_ENTRY_FILE" "checker_register_semantic_lookup_db\\(ast_ptr, &checker\\.semantic_db\\)" "SemanticDb 构建完成后注册 lookup 上下文"

"$COMPILER" test "$REPO_ROOT/tests/test_enum_basic.uya" --no-split-c >/tmp/uya-semantic-enum-variant-basic.stdout 2>/tmp/uya-semantic-enum-variant-basic.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_enum_member_access.uya" --no-split-c >/tmp/uya-semantic-enum-variant-member.stdout 2>/tmp/uya-semantic-enum-variant-member.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_enum_auto_increment.uya" --no-split-c >/tmp/uya-semantic-enum-variant-auto.stdout 2>/tmp/uya-semantic-enum-variant-auto.stderr
"$COMPILER" test "$REPO_ROOT/tests/test_semantic_lookup_enum_variant.uya" --no-split-c >/tmp/uya-semantic-enum-variant-context.stdout 2>/tmp/uya-semantic-enum-variant-context.stderr

tmp_dir="$(mktemp -d /tmp/uya-semantic-enum-variant.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/bare_enum.uya" <<'EOF'
enum Color {
    RED,
    BLUE,
}

export fn main() i32 {
    const value: Color = RED;
    _ = value;
    return 0;
}
EOF

if "$COMPILER" check "$tmp_dir/bare_enum.uya" >"$tmp_dir/bare.stdout" 2>"$tmp_dir/bare.stderr"; then
    echo "错误: 裸枚举常量应触发诊断" >&2
    exit 1
fi
if ! grep -Fq "不能使用裸枚举常量" "$tmp_dir/bare.stderr"; then
    echo "错误: 裸枚举常量诊断文案缺失" >&2
    cat "$tmp_dir/bare.stderr" >&2
    exit 1
fi

echo "✓ SemanticDb enum variant lookup migration verified"
