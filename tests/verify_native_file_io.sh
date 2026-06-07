#!/usr/bin/env bash

# Phase 10：验证 native build compiler 子集所需最小 file IO 读取。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILE_IO="$REPO_ROOT/src/codegen/native/file_io.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_file_io.uya"
FIXTURE="$REPO_ROOT/tests/fixtures/native_file_io_sample.txt"

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
        echo "错误: 缺少 native file IO 证据: $description" >&2
        exit 1
    fi
}

require_file "$FILE_IO"
require_file "$TEST_FILE"
require_file "$FIXTURE"

require_pattern "$FILE_IO" '^export[[:space:]]+struct[[:space:]]+NativeFileBuffer' "file buffer 结构"
require_pattern "$FILE_IO" 'native_file_read_all' "read all helper"
require_pattern "$FILE_IO" 'sys_open' "open syscall"
require_pattern "$FILE_IO" 'sys_read' "read syscall"
require_pattern "$FILE_IO" 'sys_close' "close syscall"
require_pattern "$FILE_IO" 'native_file_release' "release helper"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_file_io.uya --no-split-c --project-root src/)

echo "verify_native_file_io: ok"
