#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$TABLE_FILE"; then
        echo "错误: semantic table stats 缺少证据: $description" >&2
        return 1
    fi
}

if [[ ! -f "$TABLE_FILE" ]]; then
    echo "错误: 缺少 $TABLE_FILE" >&2
    exit 1
fi

require_pattern "^export[[:space:]]+struct[[:space:]]+SemanticTableStats" "SemanticTableStats"
require_pattern "count:[[:space:]]*usize" "count 字段"
require_pattern "capacity:[[:space:]]*usize" "capacity 字段"
require_pattern "bytes:[[:space:]]*usize" "bytes 字段"
require_pattern "realloc_count:[[:space:]]*i32" "realloc_count 字段"
require_pattern "export[[:space:]]+fn[[:space:]]+semantic_vector_stats" "vector stats API"
require_pattern "export[[:space:]]+fn[[:space:]]+semantic_hash_stats" "hash stats API"
require_pattern "export[[:space:]]+fn[[:space:]]+semantic_range_builder_stats" "range builder stats API"

bash "$REPO_ROOT/tests/verify_semantic_table.sh"

echo "✓ semantic dynamic table stats are recorded and exercised"
