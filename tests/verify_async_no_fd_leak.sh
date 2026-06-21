#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
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
EVENTFD_TOLERANCE="${ASYNC_NO_FD_LEAK_EVENTFD_TOLERANCE:-0}"
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

count_fd_targets() {
    local pid="$1"
    local needle="$2"
    local path=""
    local target=""
    local count=0

    for path in "/proc/$pid/fd/"*; do
        if [ ! -e "$path" ]; then
            continue
        fi
        target="$(readlink "$path" 2>/dev/null || true)"
        if [ "$target" = "$needle" ]; then
            count=$((count + 1))
        fi
    done

    printf '%s\n' "$count"
}

count_eventfds() {
    local pid="$1"
    count_fd_targets "$pid" "anon_inode:[eventfd]"
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
    local baseline_fd="$1"
    local baseline_eventfd="$2"
    local round_label="$3"
    local fd_limit=$((baseline_fd + FD_TOLERANCE))
    local eventfd_limit=$((baseline_eventfd + EVENTFD_TOLERANCE))
    local poll=0
    local current_fd=0
    local current_eventfd=0

    while [ "$poll" -lt "$RECOVERY_POLLS" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            echo "server exited during $round_label"
            show_server_log_tail
            return 1
        fi
        current_fd="$(count_fds "$server_pid")"
        current_eventfd="$(count_eventfds "$server_pid")"
        if [ "$current_fd" -le "$fd_limit" ] && [ "$current_eventfd" -le "$eventfd_limit" ]; then
            printf '%s post_fd=%s baseline_fd=%s fd_tolerance=%s post_eventfd=%s baseline_eventfd=%s eventfd_tolerance=%s\n' \
                "$round_label" "$current_fd" "$baseline_fd" "$FD_TOLERANCE" \
                "$current_eventfd" "$baseline_eventfd" "$EVENTFD_TOLERANCE" | tee -a "$REPORT"
            return 0
        fi
        poll=$((poll + 1))
        sleep "$RECOVERY_SLEEP_SECONDS"
    done

    echo "fd/eventfd count did not recover after $round_label: current_fd=$current_fd baseline_fd=$baseline_fd fd_tolerance=$FD_TOLERANCE current_eventfd=$current_eventfd baseline_eventfd=$baseline_eventfd eventfd_tolerance=$EVENTFD_TOLERANCE"
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
baseline_eventfd="$(count_eventfds "$server_pid")"
printf 'baseline_fd=%s baseline_eventfd=%s threads=%s rounds=%s requests_per_route=%s concurrency=%s\n' \
    "$baseline_fd" "$baseline_eventfd" "$THREADS" "$ROUNDS" "$REQUESTS_PER_ROUTE" "$CONCURRENCY" | tee "$REPORT"

round=1
while [ "$round" -le "$ROUNDS" ]; do
    echo "==> round $round/$ROUNDS root route"
    run_request_batch "round $round root" "$BASE_URL/"
    echo "==> round $round/$ROUNDS json route"
    run_request_batch "round $round json" "$BASE_URL/json"
    wait_for_fd_recovery "$baseline_fd" "$baseline_eventfd" "round_$round"
    round=$((round + 1))
done

final_fd="$(count_fds "$server_pid")"
final_eventfd="$(count_eventfds "$server_pid")"
printf 'final_fd=%s baseline_fd=%s fd_tolerance=%s final_eventfd=%s baseline_eventfd=%s eventfd_tolerance=%s\n' \
    "$final_fd" "$baseline_fd" "$FD_TOLERANCE" \
    "$final_eventfd" "$baseline_eventfd" "$EVENTFD_TOLERANCE" | tee -a "$REPORT"

if [ "$final_fd" -gt $((baseline_fd + FD_TOLERANCE)) ]; then
    echo "fd leak suspected: final_fd=$final_fd baseline_fd=$baseline_fd tolerance=$FD_TOLERANCE"
    show_server_log_tail
    exit 1
fi
if [ "$final_eventfd" -gt $((baseline_eventfd + EVENTFD_TOLERANCE)) ]; then
    echo "eventfd leak suspected: final_eventfd=$final_eventfd baseline_eventfd=$baseline_eventfd tolerance=$EVENTFD_TOLERANCE"
    show_server_log_tail
    exit 1
fi

echo "verify_async_no_fd_leak: fd/eventfd count returned to baseline after repeated async HTTP load"
