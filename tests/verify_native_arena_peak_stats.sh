#!/usr/bin/env bash

# Native build-seed 边界：验证 native-built compiler 需要的 arena peak 统计契约。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/codegen/native/arena.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_arena_peak_stats.uya"

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
        echo "错误: 缺少 native arena peak 统计证据: $description" >&2
        exit 1
    fi
}

require_file "$ARENA_FILE"
require_file "$TEST_FILE"

require_pattern "$ARENA_FILE" '^export[[:space:]]+struct[[:space:]]+NativeArenaPeakStats' "NativeArenaPeakStats 结构"
require_pattern "$ARENA_FILE" 'arena_peak_bytes' "总 arena_peak_bytes 字段"
require_pattern "$ARENA_FILE" 'ast_arena_peak_bytes' "AST arena peak 字段"
require_pattern "$ARENA_FILE" 'check_arena_peak_bytes' "checker arena peak 字段"
require_pattern "$ARENA_FILE" 'emit_arena_peak_bytes' "emitter arena peak 字段"
require_pattern "$ARENA_FILE" 'native_arena_peak_stats_from_arenas' "多 arena snapshot helper"
require_pattern "$ARENA_FILE" 'native_arena_peak_stats_total' "总峰值读取 helper"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_arena_peak_stats.uya --no-split-c --project-root src/)

echo "verify_native_arena_peak_stats: ok"
