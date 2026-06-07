#!/usr/bin/env bash

# Phase 10：验证 native build compiler 子集所需 malloc/arena 能力。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/codegen/native/arena.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_malloc_arena.uya"

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
        echo "错误: 缺少 native malloc/arena 证据: $description" >&2
        exit 1
    fi
}

require_file "$ARENA_FILE"
require_file "$TEST_FILE"

require_pattern "$ARENA_FILE" '^export[[:space:]]+struct[[:space:]]+NativeArena' "native arena 结构"
require_pattern "$ARENA_FILE" 'native_malloc_bytes' "malloc facade"
require_pattern "$ARENA_FILE" 'native_realloc_bytes' "realloc facade"
require_pattern "$ARENA_FILE" 'native_free_bytes' "free facade"
require_pattern "$ARENA_FILE" 'native_arena_alloc' "arena alloc"
require_pattern "$ARENA_FILE" 'native_arena_reset' "arena reset"
require_pattern "$ARENA_FILE" 'native_arena_release' "arena release"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_malloc_arena.uya --no-split-c --project-root src/)

echo "verify_native_malloc_arena: ok"
