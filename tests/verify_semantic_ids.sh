#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"

require_id_alias() {
    local name="$1"
    if ! grep -Eq "^export[[:space:]]+type[[:space:]]+$name[[:space:]]*=[[:space:]]*i32;" "$IDS_FILE"; then
        echo "错误: semantic ids 缺少 i32 ID alias: $name" >&2
        return 1
    fi
}

if [[ ! -f "$IDS_FILE" ]]; then
    echo "错误: 缺少 $IDS_FILE" >&2
    exit 1
fi

for id_name in \
    FileId \
    ModuleId \
    InternedNameId \
    DeclId \
    SymbolId \
    ScopeId \
    TypeId \
    ExprId \
    FunctionId \
    MonoInstanceId; do
    require_id_alias "$id_name"
done

tmp_dir="$(mktemp -d /tmp/uya-semantic-ids.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cp "$IDS_FILE" "$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn semantic_id_sum(
    file_id: FileId,
    module_id: ModuleId,
    name_id: InternedNameId,
    decl_id: DeclId,
    symbol_id: SymbolId,
    scope_id: ScopeId,
    type_id: TypeId,
    expr_id: ExprId,
    function_id: FunctionId,
    mono_id: MonoInstanceId,
) i32 {
    return file_id + module_id + name_id + decl_id + symbol_id +
        scope_id + type_id + expr_id + function_id + mono_id;
}

test "semantic id aliases compile" {
    const total: i32 = semantic_id_sum(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    try assert_eq_i32(total, 55);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ semantic ID aliases are defined and compile in a temporary test module"
