#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

run_step() {
    local label="$1"
    shift

    echo "==> $label"
    "$@"
}

run_step "async full-language and boundary matrix" \
    bash "$SCRIPT_DIR/verify_async_full_language_matrix.sh"

run_step "shared runtime semantic matrix" \
    bash "$SCRIPT_DIR/verify_async_shared_runtime_matrix.sh"

run_step "nested future boundary matrix" \
    bash "$SCRIPT_DIR/verify_async_nested_future_boundary.sh"

run_step "HTTP async epoll C99 compile smoke" \
    bash "$SCRIPT_DIR/verify_http_bench_async_epoll_compile.sh"

run_step "HTTP async epoll runtime smoke" \
    bash "$SCRIPT_DIR/verify_http_bench_async_epoll_runtime.sh"

run_step "HTTP async epoll fd leak smoke" \
    bash "$SCRIPT_DIR/verify_async_no_fd_leak.sh"

echo "verify_async_production_smoke: full-language, shared runtime, nested future, and HTTP async epoll smoke matrix passed"
