#!/usr/bin/env bash
#
# Full-language runtime/basic async MIR-C99 parity shard: ready/block_on,
# @async_fn return, direct @await binding, and async error-union return.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing full-language async basic evidence: $description" >&2
        exit 1
    fi
}

bash "$REPO_ROOT/tests/verify_mir_c99_async_runtime_basic_parity.sh" >/dev/null

require_pattern "$MATRIX_DOC" \
    '\| `AST_AWAIT_EXPR` \| partial \| partial \| MIR-C99 full-language async basic parity shard 覆盖 direct `@await`' \
    "AST_AWAIT_EXPR MIR-C99 partial coverage"
require_pattern "$MATRIX_DOC" \
    '\| `@await` \| partial \| partial \| MIR-C99 full-language async basic parity shard 覆盖 direct `@await`' \
    "@await builtin MIR-C99 partial coverage"
require_pattern "$MATRIX_DOC" \
    '\| `AST_TYPE_ERROR_UNION` \| done \| partial \| .*async basic parity shard 覆盖 async error union return' \
    "AST_TYPE_ERROR_UNION async return evidence"
require_pattern "$TODO_FILE" \
    'runtime/basic async full-language parity' \
    "todo tracks runtime/basic async full-language shard"

echo "OK: MIR-C99 full-language runtime/basic async parity matched C99 oracle"
