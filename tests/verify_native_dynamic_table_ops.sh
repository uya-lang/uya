#!/usr/bin/env bash

# Native build-seed 边界：验证 native build compiler 子集所需动态表 reserve/append/grow/free。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/codegen/native/table.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_dynamic_table_ops.uya"

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "错误: 缺少 $path" >&2
        exit 1
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 native dynamic table 证据: $description" >&2
        exit 1
    fi
}

require_file "$TABLE_FILE"
require_file "$TEST_FILE"

require_pattern "$TABLE_FILE" '^export[[:space:]]+struct[[:space:]]+NativeTable' "NativeTable 结构"
require_pattern "$TABLE_FILE" '^export[[:space:]]+struct[[:space:]]+NativeTableStats' "NativeTableStats 结构"
require_pattern "$TABLE_FILE" 'native_table_reserve' "reserve helper"
require_pattern "$TABLE_FILE" 'native_table_ensure_capacity' "ensure capacity helper"
require_pattern "$TABLE_FILE" 'native_table_append' "append helper"
require_pattern "$TABLE_FILE" 'native_table_item_ptr' "item ptr helper"
require_pattern "$TABLE_FILE" 'native_table_reset' "reset helper"
require_pattern "$TABLE_FILE" 'native_table_release' "release helper"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_dynamic_table_ops.uya --no-split-c --project-root src/)

echo "verify_native_dynamic_table_ops: ok"
