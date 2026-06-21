#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/verify_async_full_language_matrix.sh"

require_contains() {
    local pattern="$1"
    if ! grep -Fq "$pattern" "$TARGET"; then
        echo "missing expected matrix contract: $pattern" >&2
        exit 1
    fi
}

require_not_contains() {
    local pattern="$1"
    if grep -Fq "$pattern" "$TARGET"; then
        echo "unexpected matrix contract drift: $pattern" >&2
        exit 1
    fi
}

require_contains 'COMPILER="$REPO_ROOT/../uya/bin/uya"'
require_not_contains 'UYA_COMPILER:-'
require_contains 'verify_async_handwritten_future_whitelist.py'
require_contains 'verify_async_await_capacity.sh'
require_contains 'verify_async_nested_future_boundary.sh'
require_contains 'verify_async_shared_runtime_matrix.sh'
require_contains 'test_ai_prompt_async_macro_combo.uya'

echo "verify_async_full_language_matrix_contract: compiler path and stage coverage contracts passed"
