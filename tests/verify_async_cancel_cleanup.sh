#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"

ROUNDS="${ASYNC_CANCEL_CLEANUP_ROUNDS:-3}"

if [ "$(uname -s)" != "Linux" ]; then
    echo "verify_async_cancel_cleanup requires Linux epoll"
    exit 1
fi

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

run_uya_test() {
    local round="$1"
    local rel="$2"

    echo "==> round $round/$ROUNDS: uya test $rel"
    "$COMPILER" test --c99 "$REPO_ROOT/$rel"
}

round=1
while [ "$round" -le "$ROUNDS" ]; do
    run_uya_test "$round" "tests/test_std_async_scheduler.uya"
    run_uya_test "$round" "tests/test_async_runtime_shared_semantics.uya"
    round=$((round + 1))
done

echo "verify_async_cancel_cleanup: repeated registered-slot cancellation cleanup passed for $ROUNDS rounds"
