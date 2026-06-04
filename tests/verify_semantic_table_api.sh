#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"

require_api() {
    local name="$1"
    if ! grep -Eq "^export[[:space:]]+fn[[:space:]]+$name\\b" "$TABLE_FILE"; then
        echo "错误: dynamic table API 缺少 $name" >&2
        return 1
    fi
}

if [[ ! -f "$TABLE_FILE" ]]; then
    echo "错误: 缺少 $TABLE_FILE" >&2
    exit 1
fi

for api_name in \
    semantic_vector_reserve \
    semantic_vector_ensure_capacity \
    semantic_vector_append \
    semantic_vector_insert \
    semantic_vector_reset \
    semantic_vector_free \
    semantic_vector_release \
    semantic_hash_reserve \
    semantic_hash_ensure_capacity \
    semantic_hash_insert \
    semantic_hash_reset \
    semantic_hash_free \
    semantic_hash_release \
    semantic_range_builder_reserve \
    semantic_range_builder_ensure_capacity \
    semantic_range_builder_append \
    semantic_range_builder_reset \
    semantic_range_builder_free \
    semantic_range_builder_release; do
    require_api "$api_name"
done

bash "$REPO_ROOT/tests/verify_semantic_table.sh"

echo "✓ semantic dynamic table API surface is complete"
