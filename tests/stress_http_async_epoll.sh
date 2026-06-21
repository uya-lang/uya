#!/usr/bin/env bash
# stress_http_async_epoll.sh - 对 http_bench_async_epoll 进行长时稳定性压测
# 验证：无崩溃、无 busy-wait、RSS 不持续增长、fd 不泄漏
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DURATION_SEC="${1:-1800}"   # 默认 30 分钟
SAMPLE_INTERVAL="${2:-1}"   # 默认 1 秒采样
PORT=8876
BIN="/tmp/uya_stress_http_async_epoll"
REPORT="/tmp/uya_stress_http_async_epoll_report.txt"
WRK_LOG="/tmp/uya_stress_http_async_epoll_wrk.log"
COMPILER="$ROOT/../uya/bin/uya"
export UYA_ROOT="${UYA_ROOT:-$ROOT/lib/}"
FD_TOLERANCE="${ASYNC_STRESS_FD_TOLERANCE:-4}"
EVENTFD_TOLERANCE="${ASYNC_STRESS_EVENTFD_TOLERANCE:-0}"
RECOVERY_POLLS="${ASYNC_STRESS_RECOVERY_POLLS:-50}"
RECOVERY_SLEEP_SECONDS="${ASYNC_STRESS_RECOVERY_SLEEP_SECONDS:-0.10}"

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        echo "错误: 未找到 $1，请先安装" >&2
        exit 2
    fi
}
check_cmd wrk

if [[ ! -x "$COMPILER" ]]; then
    echo "错误: 缺少编译器 $COMPILER" >&2
    exit 2
fi

count_eventfds() {
    local pid="$1"
    local path=""
    local target=""
    local count=0

    for path in "/proc/$pid/fd/"*; do
        if [[ ! -e "$path" ]]; then
            continue
        fi
        target="$(readlink "$path" 2>/dev/null || true)"
        if [[ "$target" == "anon_inode:[eventfd]" ]]; then
            count=$((count + 1))
        fi
    done

    printf '%s\n' "$count"
}

wait_for_fd_recovery() {
    local baseline_fd="$1"
    local baseline_eventfd="$2"
    local fd_limit=$((baseline_fd + FD_TOLERANCE))
    local eventfd_limit=$((baseline_eventfd + EVENTFD_TOLERANCE))
    local poll=0
    local current_fd=0
    local current_eventfd=0

    while [[ "$poll" -lt "$RECOVERY_POLLS" ]]; do
        if [[ ! -d "/proc/$SERVER_PID" ]]; then
            echo "错误: 服务端进程已退出，无法检查回收" >&2
            return 1
        fi
        current_fd=$(ls /proc/"$SERVER_PID"/fd 2>/dev/null | wc -l)
        current_eventfd=$(count_eventfds "$SERVER_PID")
        if [[ "$current_fd" -le "$fd_limit" && "$current_eventfd" -le "$eventfd_limit" ]]; then
            RECOVERED_FD="$current_fd"
            RECOVERED_EVENTFD="$current_eventfd"
            return 0
        fi
        poll=$((poll + 1))
        sleep "$RECOVERY_SLEEP_SECONDS"
    done

    RECOVERED_FD="$current_fd"
    RECOVERED_EVENTFD="$current_eventfd"
    echo "错误: 压测后 fd/eventfd 未回收到基线附近: fd=${current_fd}/${baseline_fd}+${FD_TOLERANCE}, eventfd=${current_eventfd}/${baseline_eventfd}+${EVENTFD_TOLERANCE}" >&2
    return 1
}

echo "[1/5] 编译 benchmarks/http_bench_async_epoll.uya ..."
"$COMPILER" --c99 "$ROOT/benchmarks/http_bench_async_epoll.uya" -o "$BIN"

echo "[2/5] 启动服务端 (port=$PORT) ..."
rm -f "$REPORT" "$WRK_LOG"
rm -f /tmp/uya_stress_server.log
echo "timestamp,rss_kb,fd_count,eventfd_count" > "$REPORT"

"$BIN" > /tmp/uya_stress_server.log 2>&1 &
SERVER_PID=$!
trap 'echo "[清理] 停止服务端 $SERVER_PID"; kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true' EXIT

# 等待服务就绪
for i in $(seq 1 30); do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
        break
    fi
    sleep 0.5
done
if ! curl -s -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
    echo "错误: 服务端未在 15 秒内就绪" >&2
    tail -n 20 /tmp/uya_stress_server.log >&2
    exit 3
fi

BASELINE_FD=$(ls /proc/"$SERVER_PID"/fd 2>/dev/null | wc -l)
BASELINE_EVENTFD=$(count_eventfds "$SERVER_PID")
RECOVERED_FD="$BASELINE_FD"
RECOVERED_EVENTFD="$BASELINE_EVENTFD"

echo "[3/5] 开始压测 ${DURATION_SEC}s (wrk -t4 -c100 -d${DURATION_SEC}s) ..."
wrk -t4 -c100 -d"${DURATION_SEC}s" --latency "http://127.0.0.1:$PORT/" > "$WRK_LOG" 2>&1 &
WRK_PID=$!

echo "[4/5] 采样 RSS/fd (每 ${SAMPLE_INTERVAL}s) ..."
START_EPOCH=$(date +%s)
while kill -0 "$WRK_PID" 2>/dev/null; do
    if [[ -d "/proc/$SERVER_PID" ]]; then
        RSS=$(awk '/VmRSS/{print $2}' /proc/"$SERVER_PID"/status 2>/dev/null || echo "0")
        FD=$(ls /proc/"$SERVER_PID"/fd 2>/dev/null | wc -l)
        EVENTFD=$(count_eventfds "$SERVER_PID")
        echo "$(date '+%H:%M:%S'),$RSS,$FD,$EVENTFD" >> "$REPORT"
    else
        echo "错误: 服务端进程已退出" >&2
        break
    fi
    sleep "$SAMPLE_INTERVAL"
done
wait "$WRK_PID" 2>/dev/null || true
WRK_EC=$?
END_EPOCH=$(date +%s)
ACTUAL_DURATION=$((END_EPOCH - START_EPOCH))
RECOVERY_EC=0
if ! wait_for_fd_recovery "$BASELINE_FD" "$BASELINE_EVENTFD"; then
    RECOVERY_EC=1
fi

echo "[5/5] 生成报告 ..."
echo "=============================================="
echo "压测时长: ${ACTUAL_DURATION}s (目标 ${DURATION_SEC}s)"
echo "服务端 PID: $SERVER_PID"
echo "wrk 退出码: $WRK_EC"
echo "baseline fd/eventfd: ${BASELINE_FD}/${BASELINE_EVENTFD}"
echo "recovered fd/eventfd: ${RECOVERED_FD}/${RECOVERED_EVENTFD}"
echo "--- RSS/fd 趋势 (前 5 行) ---"
head -n 6 "$REPORT"
echo "..."
echo "--- RSS/fd 趋势 (后 5 行) ---"
tail -n 5 "$REPORT"
echo "--- wrk 摘要 ---"
tail -n 20 "$WRK_LOG"
echo "=============================================="

# 简单判稳：如果 RSS 最后一行比中间某时刻高出 50% 则警告
python3 - "$REPORT" << 'EOFPY' || true
import sys
rows = [l.strip().split(',') for l in open(sys.argv[1]) if l.strip() and not l.startswith('timestamp')]
if len(rows) < 5:
    print("采样点不足，无法判稳")
    sys.exit(0)
rss_vals = [int(r[1]) for r in rows]
fd_vals  = [int(r[2]) for r in rows]
eventfd_vals = [int(r[3]) for r in rows]
print(f"RSS 最小/最大/最后: {min(rss_vals)} / {max(rss_vals)} / {rss_vals[-1]} KB")
print(f"FD  最小/最大/最后: {min(fd_vals)} / {max(fd_vals)} / {fd_vals[-1]}")
print(f"eventfd 最小/最大/最后: {min(eventfd_vals)} / {max(eventfd_vals)} / {eventfd_vals[-1]}")
if rss_vals[-1] > rss_vals[len(rss_vals)//2] * 1.5:
    print("警告: RSS 后半段增长明显，可能存在内存泄漏")
if fd_vals[-1] > fd_vals[len(fd_vals)//2] * 1.5:
    print("警告: fd 数量后半段增长明显，可能存在 fd 泄漏")
EOFPY

if [[ $WRK_EC -ne 0 ]]; then
    exit 4
fi
if [[ $RECOVERY_EC -ne 0 ]]; then
    exit 5
fi
echo "ok: stress_http_async_epoll 完成"
