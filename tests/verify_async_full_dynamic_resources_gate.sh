#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"

MODE="${1:-all}"

case "$MODE" in
    all|unit-scan|c99-stress|backup-all)
        ;;
    *)
        echo "usage: $0 [all|unit-scan|c99-stress|backup-all]"
        exit 2
        ;;
esac

run_stage() {
    local name="$1"
    shift
    echo "==> $name"
    "$@"
}

require_compiler() {
    if [ ! -x "$COMPILER" ]; then
        echo "missing compiler: $COMPILER"
        echo "hint: run 'make uya' first"
        exit 1
    fi
}

run_uya_test() {
    local rel="$1"
    local log
    log="$(mktemp)"
    if ! "$COMPILER" test "$REPO_ROOT/$rel" >"$log" 2>&1; then
        echo "uya test failed: $rel"
        cat "$log"
        rm -f "$log"
        exit 1
    fi
    rm -f "$log"
}

run_unit_scan_stages() {
    run_stage "async await dynamic capacity" \
        run_uya_test "tests/test_async_await_capacity_dynamic.uya"
    run_stage "async param dynamic capacity" \
        run_uya_test "tests/test_async_param_capacity_dynamic.uya"
    run_stage "async frame pool dynamic growth" \
        run_uya_test "tests/test_async_frame_pool_dynamic_growth.uya"
    run_stage "async thread pool dynamic growth" \
        run_uya_test "tests/test_async_thread_pool_dynamic_growth.uya"
    run_stage "async event config" \
        run_uya_test "tests/test_async_event_config.uya"
    run_stage "async event dynamic growth" \
        run_uya_test "tests/test_async_event_dynamic_growth.uya"
    run_stage "async multi fd concurrency" \
        run_uya_test "tests/test_async_multi_fd_concurrent.uya"

    run_stage "async no fixed compiler capacity scan" \
        python3 "$SCRIPT_DIR/verify_async_compiler_no_fixed_limits.py"
}

run_c99_stress_stages() {
    local stress_pthread_iterations="${ASYNC_GATE_STRESS_PTHREAD_ITERATIONS:-100}"
    local stress_epoll_iterations="${ASYNC_GATE_STRESS_EPOLL_ITERATIONS:-100}"
    local stress_http_duration="${ASYNC_GATE_STRESS_HTTP_DURATION_SEC:-1800}"
    local stress_http_sample_interval="${ASYNC_GATE_STRESS_HTTP_SAMPLE_INTERVAL_SEC:-1}"

    run_stage "async C99 frame descriptors" \
        bash "$SCRIPT_DIR/verify_c99_async_frame_descriptors.sh"
    run_stage "async C99 empty frame descriptors" \
        bash "$SCRIPT_DIR/verify_c99_async_frame_empty_descriptors.sh"
    run_stage "async nested split-C codegen" \
        bash "$SCRIPT_DIR/verify_async_nested_split_codegen.sh"
    run_stage "http async epoll C99 compile" \
        bash "$SCRIPT_DIR/verify_http_bench_async_epoll_compile.sh"
    run_stage "http async epoll runtime verify" \
        bash "$SCRIPT_DIR/verify_http_bench_async_epoll_runtime.sh"

    run_stage "pthread stress" \
        bash "$SCRIPT_DIR/stress_pthread.sh" "$stress_pthread_iterations"
    run_stage "epoll server stress" \
        bash "$SCRIPT_DIR/stress_epoll_server.sh" "$stress_epoll_iterations"
    run_stage "http async epoll runtime stress" \
        bash "$SCRIPT_DIR/stress_http_async_epoll.sh" "$stress_http_duration" "$stress_http_sample_interval"
}

run_backup_all_stages() {
    run_stage "clean before backup-all" \
        make -C "$REPO_ROOT" clean
    run_stage "backup-all" \
        make -C "$REPO_ROOT" backup-all
}

if [ "$MODE" = "all" ] || [ "$MODE" = "unit-scan" ]; then
    require_compiler
    run_unit_scan_stages
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "c99-stress" ]; then
    require_compiler
    run_c99_stress_stages
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "backup-all" ]; then
    run_backup_all_stages
fi

echo "verify_async_full_dynamic_resources_gate: $MODE stages passed"
