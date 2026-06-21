#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/../uya/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

SRC="$REPO_ROOT/benchmarks/http_bench_async_epoll.uya"
OUT_C="$BUILD_DIR/verify_async_no_fd_leak.c"
OUT_BIN="$BUILD_DIR/verify_async_no_fd_leak"
SERVER_LOG="$BUILD_DIR/verify_async_no_fd_leak_server.log"
REPORT="$BUILD_DIR/verify_async_no_fd_leak_report.txt"

HOST="${ASYNC_NO_FD_LEAK_HOST:-127.0.0.1}"
PORT="${ASYNC_NO_FD_LEAK_PORT:-8876}"
BASE_URL="http://$HOST:$PORT"
THREADS="${ASYNC_NO_FD_LEAK_THREADS:-4}"
ROUNDS="${ASYNC_NO_FD_LEAK_ROUNDS:-3}"
REQUESTS_PER_ROUTE="${ASYNC_NO_FD_LEAK_REQUESTS_PER_ROUTE:-80}"
CONCURRENCY="${ASYNC_NO_FD_LEAK_CONCURRENCY:-8}"
RECOVERY_POLLS="${ASYNC_NO_FD_LEAK_RECOVERY_POLLS:-50}"
RECOVERY_SLEEP_SECONDS="${ASYNC_NO_FD_LEAK_RECOVERY_SLEEP_SECONDS:-0.10}"
FD_TOLERANCE="${ASYNC_NO_FD_LEAK_TOLERANCE:-2}"
MAX_TIME_SECONDS="${ASYNC_NO_FD_LEAK_MAX_TIME_SECONDS:-2}"

if [ "$(uname -s)" != "Linux" ]; then
    echo "verify_async_no_fd_leak requires Linux /proc fd accounting"
    exit 1
fi

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing command: $cmd"
        exit 1
    fi
}

require_cmd curl

CC_CMD="${CC_DRIVER:-${CC:-cc}}"
CC_FLAGS="${ASYNC_NO_FD_LEAK_CFLAGS:-${CFLAGS:--std=c99 -O3 -g -fno-builtin -fno-inline-small-functions -I${REPO_ROOT}}}"
CC_TARGET_FLAGS_USE="${CC_TARGET_FLAGS:-}"

server_pid=""

cleanup() {
    if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

count_fds() {
    local pid="$1"
    ls "/proc/$pid/fd" 2>/dev/null | wc -l
}

show_server_log_tail() {
    if [ -f "$SERVER_LOG" ]; then
        tail -n 40 "$SERVER_LOG"
    fi
}

wait_ready() {
    local url="$1"
    local tries=0
    while [ "$tries" -lt 100 ]; do
        if curl -fsS --http1.1 --max-time 1 "$url" >/dev/null 2>&1; then
            return 0
        fi
        tries=$((tries + 1))
        sleep 0.05
    done
    echo "server did not become ready: $url"
    show_server_log_tail
    return 1
}

run_request_batch() {
    local label="$1"
    local url="$2"
    local remaining="$REQUESTS_PER_ROUTE"

    while [ "$remaining" -gt 0 ]; do
        local batch="$CONCURRENCY"
        local failed=0
        local pids=()
        if [ "$remaining" -lt "$batch" ]; then
            batch="$remaining"
        fi
        local launched=0
        while [ "$launched" -lt "$batch" ]; do
            curl -fsS --http1.1 -H 'Connection: close' \
                --max-time "$MAX_TIME_SECONDS" \
                "$url" >/dev/null &
            pids+=("$!")
            launched=$((launched + 1))
        done
        local pid=""
        for pid in "${pids[@]}"; do
            if ! wait "$pid"; then
                failed=1
            fi
        done
        if [ "$failed" -ne 0 ]; then
            echo "request batch failed: $label"
            show_server_log_tail
            return 1
        fi
        remaining=$((remaining - batch))
    done
}

wait_for_fd_recovery() {
    local baseline="$1"
    local round_label="$2"
    local limit=$((baseline + FD_TOLERANCE))
    local poll=0
    local current=0

    while [ "$poll" -lt "$RECOVERY_POLLS" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            echo "server exited during $round_label"
            show_server_log_tail
            return 1
        fi
        current="$(count_fds "$server_pid")"
        if [ "$current" -le "$limit" ]; then
            printf '%s post_fd=%s baseline=%s tolerance=%s\n' \
                "$round_label" "$current" "$baseline" "$FD_TOLERANCE" | tee -a "$REPORT"
            return 0
        fi
        poll=$((poll + 1))
        sleep "$RECOVERY_SLEEP_SECONDS"
    done

    echo "fd count did not recover after $round_label: current=$current baseline=$baseline tolerance=$FD_TOLERANCE"
    show_server_log_tail
    return 1
}

echo "==> build http_bench_async_epoll for fd leak verification"
"$COMPILER" --c99 "$SRC" -o "$OUT_C" >/dev/null
$CC_CMD $CC_TARGET_FLAGS_USE $CC_FLAGS -no-pie "$OUT_C" -o "$OUT_BIN" -lm

echo "==> launch bench server (--threads $THREADS)"
rm -f "$SERVER_LOG" "$REPORT"
"$OUT_BIN" --threads "$THREADS" >"$SERVER_LOG" 2>&1 &
server_pid=$!

wait_ready "$BASE_URL/"
wait_ready "$BASE_URL/json"

curl -fsS --http1.1 --max-time "$MAX_TIME_SECONDS" "$BASE_URL/" >/dev/null
curl -fsS --http1.1 --max-time "$MAX_TIME_SECONDS" "$BASE_URL/json" >/dev/null

baseline_fd="$(count_fds "$server_pid")"
printf 'baseline_fd=%s threads=%s rounds=%s requests_per_route=%s concurrency=%s\n' \
    "$baseline_fd" "$THREADS" "$ROUNDS" "$REQUESTS_PER_ROUTE" "$CONCURRENCY" | tee "$REPORT"

round=1
while [ "$round" -le "$ROUNDS" ]; do
    echo "==> round $round/$ROUNDS root route"
    run_request_batch "round $round root" "$BASE_URL/"
    echo "==> round $round/$ROUNDS json route"
    run_request_batch "round $round json" "$BASE_URL/json"
    wait_for_fd_recovery "$baseline_fd" "round_$round"
    round=$((round + 1))
done

final_fd="$(count_fds "$server_pid")"
printf 'final_fd=%s baseline_fd=%s tolerance=%s\n' \
    "$final_fd" "$baseline_fd" "$FD_TOLERANCE" | tee -a "$REPORT"

if [ "$final_fd" -gt $((baseline_fd + FD_TOLERANCE)) ]; then
    echo "fd leak suspected: final_fd=$final_fd baseline_fd=$baseline_fd tolerance=$FD_TOLERANCE"
    show_server_log_tail
    exit 1
fi

echo "verify_async_no_fd_leak: fd count returned to baseline after repeated async HTTP load"
