#!/usr/bin/env bash

# Phase 10：验证 native build compiler 子集所需最小 snprintf/format 替代。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORMAT_FILE="$REPO_ROOT/src/codegen/native/format.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_format_minimal.uya"

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
        echo "错误: 缺少 native format 证据: $description" >&2
        exit 1
    fi
}

require_file "$FORMAT_FILE"
require_file "$TEST_FILE"

require_pattern "$FORMAT_FILE" '^export[[:space:]]+struct[[:space:]]+NativeFormatArg' "format argument 结构"
require_pattern "$FORMAT_FILE" 'native_format_snprintf' "snprintf replacement"
require_pattern "$FORMAT_FILE" 'native_format_arg_cstr' "string argument"
require_pattern "$FORMAT_FILE" 'native_format_arg_i64' "signed integer argument"
require_pattern "$FORMAT_FILE" 'native_format_arg_usize' "usize argument"
require_pattern "$TEST_FILE" 'prefix-%d' "截断 snprintf pattern"
require_pattern "$TEST_FILE" '%zu' "usize format pattern"
require_pattern "$TEST_FILE" '%ld' "long format pattern"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_format_minimal.uya --no-split-c --project-root src/)

echo "verify_native_format_minimal: ok"
