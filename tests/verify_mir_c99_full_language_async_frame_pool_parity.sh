#!/usr/bin/env bash
#
# Full-language frame/pool async MIR-C99 parity shard: @frame type/methods,
# inline temps, stack/pool/stats, and heap fallback.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"
TODO_COMPLETED_FILE="$REPO_ROOT/docs/todo_mir_c99_backend_completed.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing full-language async frame/pool evidence: $description" >&2
        exit 1
    fi
}

require_pattern_any() {
    local pattern="$1"
    local description="$2"
    shift 2
    local file
    for file in "$@"; do
        if grep -Eq "$pattern" "$file"; then
            return 0
        fi
    done
    echo "error: missing full-language async frame/pool evidence: $description" >&2
    exit 1
}

bash "$REPO_ROOT/tests/verify_mir_c99_async_frame_pool_parity.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_async_frame_pool_fallback_parity.sh" >/dev/null

require_pattern "$MATRIX_DOC" \
    '\| `AST_AWAIT_EXPR` \| partial \| partial \| .*frame/pool async full-language parity shard 覆盖 @frame method poll 与 inline temp await' \
    "AST_AWAIT_EXPR frame/pool async evidence"
require_pattern "$MATRIX_DOC" \
    '\| `AST_TYPE_FRAME` \| partial \| partial \| .*frame/pool async full-language parity shard 覆盖 @frame type/methods、inline temp、stack/pool/stats/heap fallback' \
    "AST_TYPE_FRAME MIR-C99 partial coverage"
require_pattern "$MATRIX_DOC" \
    '\| `@await` \| partial \| partial \| .*frame/pool async full-language parity shard 覆盖 @frame method poll 与 inline temp await' \
    "@await builtin frame/pool async evidence"
require_pattern_any \
    'frame/pool async full-language parity' \
    "todo tracks frame/pool async full-language shard" \
    "$TODO_FILE" "$TODO_COMPLETED_FILE"

echo "OK: MIR-C99 full-language async frame/pool parity matched C99 oracle"
