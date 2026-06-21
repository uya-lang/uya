#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PRODUCTION_SMOKE="$REPO_ROOT/tests/verify_async_production_smoke.sh"
BENCH_SMOKE="$REPO_ROOT/tests/verify_async_bench_runtime_smoke.sh"

require_contains() {
    local file="$1"
    local needle="$2"
    if ! grep -Fq "$needle" "$file"; then
        echo "missing expected entry in $(basename "$file"): $needle" >&2
        return 1
    fi
}

require_not_contains() {
    local file="$1"
    local needle="$2"
    if grep -Fq "$needle" "$file"; then
        echo "unexpected bench/demo entry in $(basename "$file"): $needle" >&2
        return 1
    fi
}

if [ ! -f "$PRODUCTION_SMOKE" ]; then
    echo "missing production smoke gate: $PRODUCTION_SMOKE" >&2
    exit 1
fi

if [ ! -f "$BENCH_SMOKE" ]; then
    echo "missing bench/runtime smoke gate: $BENCH_SMOKE" >&2
    exit 1
fi

require_contains "$PRODUCTION_SMOKE" "verify_async_full_language_matrix.sh"
require_contains "$PRODUCTION_SMOKE" "verify_async_shared_runtime_matrix.sh"
require_contains "$PRODUCTION_SMOKE" "verify_async_nested_future_boundary.sh"
require_contains "$PRODUCTION_SMOKE" "verify_async_cancel_cleanup.sh"

require_not_contains "$PRODUCTION_SMOKE" "verify_http_bench_async_epoll_compile.sh"
require_not_contains "$PRODUCTION_SMOKE" "verify_http_bench_async_epoll_runtime.sh"
require_not_contains "$PRODUCTION_SMOKE" "verify_async_no_fd_leak.sh"

require_contains "$BENCH_SMOKE" "verify_http_bench_async_epoll_compile.sh"
require_contains "$BENCH_SMOKE" "verify_http_bench_async_epoll_runtime.sh"
require_contains "$BENCH_SMOKE" "verify_async_no_fd_leak.sh"

echo "verify_async_smoke_gate_separation: production smoke and bench/runtime smoke are separated"
