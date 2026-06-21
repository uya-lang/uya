#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

COMPILER="../uya/bin/uya"
export UYA_ROOT="../uya/lib/"

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

run_uya_test() {
    local rel="$1"
    local log
    log="$(mktemp)"
    echo "==> uya test $rel"
    if ! "$COMPILER" test "$rel" >"$log" 2>&1; then
        echo "uya test failed: $rel"
        cat "$log"
        rm -f "$log"
        exit 1
    fi
    rm -f "$log"
}

websocket_tests=(
    "tests/test_http_websocket_async_read_message_shape.uya"
    "tests/test_http_websocket_read_message_semantics.uya"
    "tests/test_http_websocket_heartbeat.uya"
    "tests/test_http_websocket_reconnect.uya"
)

for test_file in "${websocket_tests[@]}"; do
    run_uya_test "$test_file"
done

echo "verify_async_websocket_regressions: message aggregate, heartbeat, reconnect passed"
