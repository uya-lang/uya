#!/usr/bin/env bash
#
# Full-language control-flow async MIR-C99 parity shard: if/else-if, while,
# for, nested blocks, multiple await points, and compound try-await.

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
        echo "error: missing full-language async control-flow evidence: $description" >&2
        exit 1
    fi
}

bash "$REPO_ROOT/tests/verify_mir_c99_async_control_flow_parity.sh" >/dev/null

require_pattern "$MATRIX_DOC" \
    '\| `AST_AWAIT_EXPR` \| partial \| partial \| .*control-flow async full-language parity shard 覆盖 if/else-if/while/for/nested/multiple await 与 compound try-await' \
    "AST_AWAIT_EXPR control-flow async evidence"
require_pattern "$MATRIX_DOC" \
    '\| `AST_FOR_STMT` \| done \| partial \| .*control-flow async full-language parity shard 覆盖 range for 和 array for' \
    "AST_FOR_STMT MIR-C99 partial coverage"
require_pattern "$MATRIX_DOC" \
    '\| `AST_BLOCK` \| done \| partial \| .*control-flow async full-language parity shard 覆盖 async nested block' \
    "AST_BLOCK MIR-C99 partial coverage"
require_pattern "$MATRIX_DOC" \
    '\| `CORE_STMT_KIND_IF` \| done \| partial \| .*control-flow async full-language parity shard 覆盖 async if/else-if' \
    "CORE_STMT_KIND_IF async control-flow evidence"
require_pattern "$MATRIX_DOC" \
    '\| `CORE_STMT_KIND_WHILE` \| partial \| partial \| .*control-flow async full-language parity shard 覆盖 async while' \
    "CORE_STMT_KIND_WHILE async control-flow evidence"
require_pattern "$MATRIX_DOC" \
    '\| `@await` \| partial \| partial \| .*control-flow async full-language parity shard 覆盖 if/else-if/while/for/nested/multiple await 与 compound try-await' \
    "@await builtin control-flow async evidence"
require_pattern "$TODO_FILE" \
    'control-flow async full-language parity' \
    "todo tracks control-flow async full-language shard"

echo "OK: MIR-C99 full-language control-flow async parity matched C99 oracle"
