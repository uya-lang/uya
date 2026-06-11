#!/usr/bin/env bash

# Native build-seed 边界：验证 native build compiler 子集所需 hash/intern table 基础内存操作。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HASH_FILE="$REPO_ROOT/src/codegen/native/hash.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_hash_intern_memory_ops.uya"

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
        echo "错误: 缺少 native hash/intern 证据: $description" >&2
        exit 1
    fi
}

require_file "$HASH_FILE"
require_file "$TEST_FILE"

require_pattern "$HASH_FILE" '^export[[:space:]]+struct[[:space:]]+NativeHashEntry' "hash entry 结构"
require_pattern "$HASH_FILE" '^export[[:space:]]+struct[[:space:]]+NativeInternEntry' "intern entry 结构"
require_pattern "$HASH_FILE" 'native_hash_find_slot' "hash probe helper"
require_pattern "$HASH_FILE" 'native_hash_put_entry' "hash put helper"
require_pattern "$HASH_FILE" 'native_hash_get_entry' "hash get helper"
require_pattern "$HASH_FILE" 'native_intern_hash_bytes' "intern FNV hash"
require_pattern "$HASH_FILE" 'native_intern_bytes_equal' "intern byte compare"
require_pattern "$HASH_FILE" 'native_intern_find_slot' "intern probe helper"
require_pattern "$HASH_FILE" 'native_intern_put_entry' "intern put helper"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_hash_intern_memory_ops.uya --no-split-c --project-root src/)

echo "verify_native_hash_intern_memory_ops: ok"
