#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_step() {
    local label="$1"
    shift

    echo "==> $label"
    "$@"
}

# 这里只验证 benchmark/demo 相关的运行时冒烟与资源回收。
# 共享 runtime / 生产语义留在 verify_async_production_smoke.sh。
run_step "HTTP async epoll C99 compile smoke" \
    bash "$SCRIPT_DIR/verify_http_bench_async_epoll_compile.sh"

run_step "HTTP async epoll runtime smoke" \
    bash "$SCRIPT_DIR/verify_http_bench_async_epoll_runtime.sh"

run_step "HTTP async epoll fd leak smoke" \
    bash "$SCRIPT_DIR/verify_async_no_fd_leak.sh"

echo "verify_async_bench_runtime_smoke: benchmark/demo runtime smoke passed"
