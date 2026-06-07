#!/usr/bin/env bash

# Phase 10：验证 native build compiler 子集所需 memcpy/memset/strcmp/strlen。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_FILE="$REPO_ROOT/src/codegen/native/memory.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_memory_string_primitives.uya"

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
        echo "错误: 缺少 native memory/string primitive 证据: $description" >&2
        exit 1
    fi
}

require_file "$MEMORY_FILE"
require_file "$TEST_FILE"

require_pattern "$MEMORY_FILE" 'export[[:space:]]+fn[[:space:]]+native_memcpy' "native memcpy"
require_pattern "$MEMORY_FILE" 'export[[:space:]]+fn[[:space:]]+native_memset' "native memset"
require_pattern "$MEMORY_FILE" 'export[[:space:]]+fn[[:space:]]+native_strlen' "native strlen"
require_pattern "$MEMORY_FILE" 'export[[:space:]]+fn[[:space:]]+native_strcmp' "native strcmp"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_memory_string_primitives.uya --no-split-c --project-root src/)

echo "verify_native_memory_string_primitives: ok"
