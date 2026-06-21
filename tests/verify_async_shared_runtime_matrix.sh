#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
DRIVER_ARGS=("$@")

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

run_uya_test() {
    local label="$1"
    local src="$2"

    echo "verify: $label"
    "$COMPILER" test "${DRIVER_ARGS[@]}" --c99 "$REPO_ROOT/$src"
}

run_uya_test "Scheduler shared EventLoop/Waker semantics" "tests/test_std_async_scheduler.uya"
run_uya_test "HTTP/DNS/TLS/async_compute/Scheduler shared runtime assertions" "tests/test_async_shared_runtime_semantics.uya"
run_uya_test "async_compute shares scheduler wakeup path" "tests/test_async_compute_types.uya"
run_uya_test "DNS async transport on Linux+C99" "tests/test_std_dns_async_transport.uya"
run_uya_test "HTTP/1 async client runtime path" "tests/test_http1_async_client.uya"
run_uya_test "TLS/HTTPS bridge safety stays compatible" "tests/test_https_bridge_safety.uya"

echo "verify_async_shared_runtime_matrix: Linux+C99 shared async runtime smoke matrix passed"
