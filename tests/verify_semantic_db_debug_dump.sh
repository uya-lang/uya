#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKER_SYMBOLS_FILE="$REPO_ROOT/src/checker/symbols.uya"
CHECKER_ENTRY_FILE="$REPO_ROOT/src/checker/check_expr_extra.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: SemanticDb debug dump 缺少证据: $description" >&2
        return 1
    fi
}

for file in "$CHECKER_SYMBOLS_FILE" "$CHECKER_ENTRY_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$CHECKER_SYMBOLS_FILE" "UYA_DUMP_SEMANTIC_DB" "debug dump 环境变量"
require_pattern "$CHECKER_SYMBOLS_FILE" "checker_maybe_dump_semantic_db" "debug dump 调度函数"
require_pattern "$CHECKER_SYMBOLS_FILE" "=== semantic db ===" "debug dump 起始标记"
require_pattern "$CHECKER_SYMBOLS_FILE" "semantic_db_estimated_bytes" "debug dump 输出 bytes"
require_pattern "$CHECKER_SYMBOLS_FILE" "checker_dump_semantic_phase2_index" "Phase 2 索引摘要输出函数"
require_pattern "$CHECKER_SYMBOLS_FILE" "load_ppm" "Phase 2 索引 load factor 字段"
require_pattern "$CHECKER_ENTRY_FILE" "checker_maybe_dump_semantic_db\\(checker\\)" "checker 入口调用 debug dump"

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-dump.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

default_stderr="$tmp_dir/default.stderr"
dump_stderr="$tmp_dir/dump.stderr"

(cd "$REPO_ROOT" && "$COMPILER" check "$tmp_dir/main.uya" >"$tmp_dir/default.stdout" 2>"$default_stderr")
if grep -Fq "=== semantic db ===" "$default_stderr"; then
    echo "错误: 未设置 UYA_DUMP_SEMANTIC_DB 时不应输出 SemanticDb dump" >&2
    exit 1
fi

(cd "$REPO_ROOT" && UYA_DUMP_SEMANTIC_DB=1 "$COMPILER" check "$tmp_dir/main.uya" >"$tmp_dir/dump.stdout" 2>"$dump_stderr")
if ! grep -Fq "=== semantic db ===" "$dump_stderr"; then
    echo "错误: UYA_DUMP_SEMANTIC_DB=1 时缺少 SemanticDb dump 起始标记" >&2
    exit 1
fi
if ! grep -Fq "files=" "$dump_stderr" || ! grep -Fq "decls=" "$dump_stderr" || ! grep -Fq "bytes=" "$dump_stderr"; then
    echo "错误: SemanticDb dump 缺少核心摘要字段" >&2
    exit 1
fi
for index_name in decls_by_name functions_by_name types_by_name global_vars_by_name enum_variants_by_name exports_by_module_name aliases_by_file_name use_items_by_file_name; do
    if ! grep -Eq "phase2_index name=${index_name} count=[0-9]+ capacity=[0-9]+ load_ppm=[0-9]+ reallocs=[0-9]+ bytes=[0-9]+" "$dump_stderr"; then
        echo "错误: SemanticDb dump 缺少 Phase 2 索引摘要: $index_name" >&2
        exit 1
    fi
done
if ! grep -Fq "=== semantic db end ===" "$dump_stderr"; then
    echo "错误: UYA_DUMP_SEMANTIC_DB=1 时缺少 SemanticDb dump 结束标记" >&2
    exit 1
fi

echo "✓ SemanticDb debug dump env switch verified"
