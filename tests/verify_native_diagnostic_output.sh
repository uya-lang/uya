#!/usr/bin/env bash

# Phase 10：验证 native build compiler 子集所需 diagnostics 字符串输出缓冲。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIAG_FILE="$REPO_ROOT/src/codegen/native/diagnostics.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_diagnostic_output.uya"

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
        echo "错误: 缺少 native diagnostics 输出证据: $description" >&2
        exit 1
    fi
}

require_file "$DIAG_FILE"
require_file "$TEST_FILE"

require_pattern "$DIAG_FILE" '^export[[:space:]]+struct[[:space:]]+NativeDiagnosticBuffer' "diagnostic buffer 结构"
require_pattern "$DIAG_FILE" 'native_diag_append_byte' "append byte"
require_pattern "$DIAG_FILE" 'native_diag_append_bytes' "append bytes"
require_pattern "$DIAG_FILE" 'native_diag_append_c_string' "append C string"
require_pattern "$DIAG_FILE" 'native_diag_append_line' "append line"
require_pattern "$DIAG_FILE" 'native_diag_data' "data pointer"
require_pattern "$DIAG_FILE" 'native_diag_release' "release helper"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_diagnostic_output.uya --no-split-c --project-root src/)

echo "verify_native_diagnostic_output: ok"
