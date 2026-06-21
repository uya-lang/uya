#!/usr/bin/env bash
# stress_async_dynamic_resources.sh - 压测 async 动态资源路径，确保旧常量边界不再直接决定成功/失败。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="$REPO_ROOT/lib/"

MODE="${1:-all}"
RUNTIME_ITERATIONS="${ASYNC_DYNAMIC_RUNTIME_ITERATIONS:-5}"
PROTOCOL_ITERATIONS="${ASYNC_DYNAMIC_PROTOCOL_ITERATIONS:-2}"
EPOLL_LEGACY_CAP="${ASYNC_DYNAMIC_EPOLL_LEGACY_CAP:-1024}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uya_async_dynamic_resources.XXXXXX")"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

case "$MODE" in
    all|compiler|runtime|protocol|smoke)
        ;;
    *)
        echo "usage: $0 [all|compiler|runtime|protocol|smoke]"
        exit 2
        ;;
esac

if [ "$MODE" = "smoke" ]; then
    RUNTIME_ITERATIONS=1
    PROTOCOL_ITERATIONS=1
fi

require_compiler() {
    if [ ! -x "$COMPILER" ]; then
        echo "missing compiler: $COMPILER"
        echo "hint: run 'make uya' first"
        exit 1
    fi
}

run_stage() {
    local name="$1"
    shift
    echo "==> $name"
    "$@"
}

run_uya_test_file() {
    local file_path="$1"
    local label="$2"
    local log="$TMP_DIR/uya_test.log"

    if ! "$COMPILER" test "$file_path" >"$log" 2>&1; then
        echo "uya test failed: $label"
        tail -n 80 "$log"
        exit 1
    fi
}

run_repeated_uya_suite() {
    local suite_name="$1"
    local iterations="$2"
    shift 2
    local suite=("$@")
    local iter
    local test_path

    for iter in $(seq 1 "$iterations"); do
        echo "   iteration $iter/$iterations"
        for test_path in "${suite[@]}"; do
            run_uya_test_file "$test_path" "$suite_name iteration $iter: $test_path"
        done
    done
}

run_logged_command() {
    local label="$1"
    shift
    local log="$TMP_DIR/command.log"

    if ! "$@" >"$log" 2>&1; then
        echo "command failed: $label"
        tail -n 80 "$log"
        exit 1
    fi
}

prepare_epoll_legacy_boundary_test() {
    local out="$TMP_DIR/test_async_event_dynamic_growth_${EPOLL_LEGACY_CAP}.uya"

    sed \
        -e "s/const LEGACY_SLOT_CAPACITY: i32 = 64;/const LEGACY_SLOT_CAPACITY: i32 = ${EPOLL_LEGACY_CAP};/" \
        -e 's/while i < count {/while i < TARGET_REGISTERED_FDS {/g' \
        -e '/const idx: usize = i as usize;/d' \
        -e '/const idx: usize = ((i as! usize).value);/d' \
        -e 's/\[idx\]/[i]/g' \
        "$REPO_ROOT/tests/test_async_event_dynamic_growth.uya" >"$out"

    if ! grep -q "const LEGACY_SLOT_CAPACITY: i32 = ${EPOLL_LEGACY_CAP};" "$out"; then
        echo "failed to prepare epoll legacy boundary test"
        exit 1
    fi

    printf '%s\n' "$out"
}

run_compiler_stage() {
    run_stage "compiler fixed-limit source scan" \
        run_logged_command "verify_async_compiler_no_fixed_limits.py" \
        python3 "$SCRIPT_DIR/verify_async_compiler_no_fixed_limits.py"
    run_stage "async params past fixed 64" \
        run_uya_test_file "$REPO_ROOT/tests/test_async_param_capacity_dynamic.uya" \
        "tests/test_async_param_capacity_dynamic.uya"
    run_stage "async awaits past legacy 256" \
        run_uya_test_file "$REPO_ROOT/tests/test_async_await_capacity_dynamic.uya" \
        "tests/test_async_await_capacity_dynamic.uya"
    run_stage "async await segments boundary matrix" \
        run_uya_test_file "$REPO_ROOT/tests/test_async_await_limits_and_segments.uya" \
        "tests/test_async_await_limits_and_segments.uya"
    run_stage "async await 4097 c99 stress" \
        run_logged_command "verify_async_await_capacity.sh" \
        env UYA_COMPILER="$COMPILER" UYA_ROOT="$REPO_ROOT/lib/" \
        bash "$SCRIPT_DIR/verify_async_await_capacity.sh"
}

run_runtime_stage() {
    local epoll_boundary_test
    epoll_boundary_test="$(prepare_epoll_legacy_boundary_test)"

    run_stage "runtime dynamic growth suite (${RUNTIME_ITERATIONS} iterations)" \
        run_repeated_uya_suite "runtime dynamic growth" "$RUNTIME_ITERATIONS" \
        "$REPO_ROOT/tests/test_async_task_queue_dynamic_growth.uya" \
        "$REPO_ROOT/tests/test_async_event_dynamic_growth.uya" \
        "$epoll_boundary_test" \
        "$REPO_ROOT/tests/test_async_frame_pool_dynamic_growth.uya" \
        "$REPO_ROOT/tests/test_async_thread_pool_dynamic_growth.uya"
}

run_protocol_stage() {
    run_stage "protocol/runtime async suite (${PROTOCOL_ITERATIONS} iterations)" \
        run_repeated_uya_suite "protocol/runtime async" "$PROTOCOL_ITERATIONS" \
        "$REPO_ROOT/tests/test_http1_async_client.uya" \
        "$REPO_ROOT/tests/test_std_mqtt_async.uya" \
        "$REPO_ROOT/tests/test_tls_async_runtime_io.uya" \
        "$REPO_ROOT/tests/test_async_shared_runtime_semantics.uya"
}

require_compiler

if [ "$MODE" = "all" ] || [ "$MODE" = "compiler" ] || [ "$MODE" = "smoke" ]; then
    run_compiler_stage
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "runtime" ] || [ "$MODE" = "smoke" ]; then
    run_runtime_stage
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "protocol" ] || [ "$MODE" = "smoke" ]; then
    run_protocol_stage
fi

echo "stress_async_dynamic_resources: $MODE stages passed"
