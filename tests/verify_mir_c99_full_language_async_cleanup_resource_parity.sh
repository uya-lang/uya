#!/usr/bin/env bash
#
# Full-language cleanup/resource async MIR-C99 parity shard: async error-union
# cleanup, defer/errdefer, frame release, and make-check manifest closure.

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
        echo "error: missing full-language async cleanup/resource evidence: $description" >&2
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
    echo "error: missing full-language async cleanup/resource evidence: $description" >&2
    exit 1
}

bash "$REPO_ROOT/tests/verify_mir_c99_async_cleanup_resource_parity.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_async_cleanup_release_plan.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_async_make_check_manifest.sh" >/dev/null

require_pattern "$MATRIX_DOC" \
    '\| `AST_AWAIT_EXPR` \| partial \| partial \| .*cleanup/resource async full-language parity shard 覆盖 async error union cleanup、defer/errdefer 和 frame release' \
    "AST_AWAIT_EXPR async cleanup/resource coverage"
require_pattern "$MATRIX_DOC" \
    '\| `AST_DEFER_STMT` \| done \| partial \| .*cleanup/resource async full-language parity shard 覆盖 async error path 上的 defer cleanup' \
    "AST_DEFER_STMT async defer coverage"
require_pattern "$MATRIX_DOC" \
    '\| `AST_ERRDEFER_STMT` \| partial \| partial \| .*cleanup/resource async full-language parity shard 覆盖 async error path 上的 errdefer cleanup' \
    "AST_ERRDEFER_STMT async errdefer coverage"
require_pattern "$MATRIX_DOC" \
    '\| `AST_TYPE_ERROR_UNION` \| done \| partial \| .*cleanup/resource async full-language parity shard 覆盖 async error union cleanup' \
    "AST_TYPE_ERROR_UNION async cleanup coverage"
require_pattern "$MATRIX_DOC" \
    '\| `AST_TYPE_FRAME` \| partial \| partial \| .*cleanup/resource async full-language parity shard 覆盖 frame release' \
    "AST_TYPE_FRAME release coverage"
require_pattern "$MATRIX_DOC" \
    '\| `@await` \| partial \| partial \| .*cleanup/resource async full-language parity shard 覆盖 async error union cleanup、defer/errdefer 和 frame release' \
    "@await async cleanup/resource coverage"
require_pattern "$MATRIX_DOC" \
    '\| async runtime / Future / Waker \| partial \| partial \| .*cleanup/resource async full-language parity shard 覆盖 async cleanup/resource paths，并由 async make-check manifest 收口' \
    "async runtime cleanup/resource and manifest coverage"
require_pattern "$MATRIX_DOC" \
    '\| async channel / scheduler / event loop / async_compute \| partial \| partial \| .*async make-check manifest 收口覆盖当前 `tests/test_async_\*\.uya`' \
    "async make-check manifest closure coverage"
require_pattern_any \
    'async cleanup/resource full-language parity' \
    "todo tracks cleanup/resource async full-language shard" \
    "$TODO_FILE" "$TODO_COMPLETED_FILE"

echo "OK: MIR-C99 full-language async cleanup/resource parity matched C99 oracle"
