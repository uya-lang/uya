#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="$REPO_ROOT/lib/"

MODE="${1:-all}"

case "$MODE" in
    all|module-regressions|unit-scan)
        ;;
    *)
        echo "usage: $0 [all|module-regressions|unit-scan]"
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

run_module_regressions() {
    run_stage "runtime hand-written Future whitelist" \
        python3 "$SCRIPT_DIR/verify_async_handwritten_future_whitelist.py"
    run_stage "async fd substrate boundary" \
        run_uya_test "tests/test_async_fd_substrate_boundary.uya"
    run_stage "std.thread async worker boundary" \
        run_uya_test "tests/test_std_thread_async_boundary.uya"
    run_stage "dns async composition boundary" \
        run_uya_test "tests/test_std_dns_async_composition_shape.uya"
    run_stage "dns async transport runtime" \
        run_uya_test "tests/test_std_dns_async_transport.uya"
    run_stage "async business future boundary" \
        run_uya_test "tests/test_async_std_business_future_boundary.uya"
    run_stage "http1 async connect boundary" \
        run_uya_test "tests/test_http1_async_connect_boundary.uya"
    run_stage "http1 async client runtime" \
        run_uya_test "tests/test_http1_async_client.uya"
    run_stage "shared async runtime semantics" \
        run_uya_test "tests/test_async_shared_runtime_semantics.uya"
    run_stage "uyagin async boundary" \
        run_uya_test "tests/test_http_uyagin_async_boundary.uya"
}

run_unit_scan() {
    run_stage "dynamic resource unit scan" \
        bash "$SCRIPT_DIR/verify_async_full_dynamic_resources_gate.sh" unit-scan
}

require_compiler

if [ "$MODE" = "all" ] || [ "$MODE" = "module-regressions" ]; then
    run_module_regressions
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "unit-scan" ]; then
    run_unit_scan
fi

echo "verify_async_dynamic_resources: $MODE stages passed"
