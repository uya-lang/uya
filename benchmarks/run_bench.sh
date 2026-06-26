#!/bin/bash
# benchmarks/run_bench.sh — HTTP 基准测试脚本
#
# 用法: ./run_bench.sh [options] [bench_names...]
#
# 选项:
#   --baseline     保存结果到 baseline.json（用于回归对比）
#   --ab           运行 ab 测试
#   -k             运行 ab -k (Keep-Alive) 测试
#
# 可指定的 bench 名称（不指定则运行全部）:
#   uya, uya-fork, uya-async-epoll, uya-async-await,
#   uya-async-await-simple, uya-async-await-stack,
#   c, c-async-epoll, go-gnet, uyagin, zap, nginx, go, tokio
#
# 依赖: wrk, cc, bin/uya；go / cargo / zig / git / nginx 作为可选对照项

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

UYA_BIN="${REPO_ROOT}/bin/uya"
GO_SRC="${SCRIPT_DIR}/http_bench.go"
UYA_HTTP_SRC="${SCRIPT_DIR}/http_bench.uya"
UYA_FORK_SRC="${SCRIPT_DIR}/http_bench_fork.uya"
UYA_ASYNC_EPOLL_SRC="${SCRIPT_DIR}/http_bench_async_epoll.uya"
UYA_ASYNC_AWAIT_SRC="${SCRIPT_DIR}/http_bench_async_epoll_await.uya"
UYA_ASYNC_AWAIT_SIMPLE_SRC="${SCRIPT_DIR}/http_bench_async_epoll_await_simple.uya"
UYA_ASYNC_AWAIT_STACK_SRC="${SCRIPT_DIR}/http_bench_async_epoll_await_stack.uya"
UYA_HTTP_ENTRY="http_bench.uya"
UYA_FORK_ENTRY="http_bench_fork.uya"
UYA_ASYNC_EPOLL_ENTRY="http_bench_async_epoll.uya"
UYA_ASYNC_AWAIT_ENTRY="http_bench_async_epoll_await.uya"
UYA_ASYNC_AWAIT_SIMPLE_ENTRY="http_bench_async_epoll_await_simple.uya"
UYA_ASYNC_AWAIT_STACK_ENTRY="http_bench_async_epoll_await_stack.uya"
C_SRC="${SCRIPT_DIR}/http_bench.c"
C_ASYNC_EPOLL_SRC="${SCRIPT_DIR}/http_bench_async_epoll.c"
GO_GNET_REPO_URL="https://github.com/gnet-io/gnet-benchmarks.git"
GO_GNET_REPO_TAG="v2"
GO_GNET_REPO_DIR="/tmp/http_bench_go_gnet_repo"
GO_GNET_EXEC="/tmp/http_bench_go_gnet"
UYA_GIN_SRC="${SCRIPT_DIR}/uyagin_http_bench.uya"
UYA_GIN_ENTRY="uyagin_http_bench.uya"
UYA_GIN_EXEC="/tmp/http_bench_uyagin"
UYA_GIN_MODE="${UYA_GIN_MODE:-nostdlib}"
UYA_GIN_CFLAGS="${UYA_GIN_CFLAGS:--std=c99 -O3 -fno-builtin -pthread -I${REPO_ROOT}}"
UYA_GIN_NOSTDLIB_CFLAGS="${UYA_GIN_NOSTDLIB_CFLAGS:--std=c99 -O3 -fno-builtin -fno-stack-protector -I${REPO_ROOT}}"
NGINX_BENCH_DIR="/tmp/http_bench_nginx"
NGINX_CONF_FILE="${NGINX_BENCH_DIR}/nginx.conf"
NGINX_PID_FILE="${NGINX_BENCH_DIR}/nginx.pid"
NGINX_EXEC=""
export UYA_ROOT="${UYA_ROOT:-${SCRIPT_DIR}/../lib/}"

# 编译输出
GO_EXEC="/tmp/http_bench_go"
UYA_HTTP_EXEC="/tmp/http_bench_uya"
UYA_FORK_EXEC="/tmp/http_bench_fork"
UYA_ASYNC_EPOLL_EXEC="/tmp/http_bench_async_epoll"
UYA_ASYNC_AWAIT_EXEC="/tmp/http_bench_async_epoll_await"
UYA_ASYNC_AWAIT_SIMPLE_EXEC="/tmp/http_bench_async_epoll_await_simple"
UYA_ASYNC_AWAIT_STACK_EXEC="/tmp/http_bench_async_epoll_await_stack"
C_EXEC="/tmp/http_bench_c"
C_ASYNC_EPOLL_EXEC="/tmp/http_bench_c_async_epoll"
ZAP_REPO_URL="https://github.com/zigzap/zap.git"
ZAP_REPO_TAG="v0.11.0"
ZAP_REPO_DIR="/tmp/http_bench_zap_repo"
ZAP_EXEC="/tmp/http_bench_zap"
ZAP_SRC="${SCRIPT_DIR}/http_bench_zap/hello.zig"
ZIG_BIN="${ZIG_BIN:-/home/winger/zig/zig}"
TOKIO_DIR="${SCRIPT_DIR}/http_bench_tokio"
TOKIO_EXEC="/tmp/http_bench_tokio"
# async epoll 系列在 hosted 模式下沿用已验证可启动的宿主编译旗标
ASYNC_BENCH_CFLAGS="-std=c99 -O3 -g -fno-builtin -fno-inline-small-functions -I${REPO_ROOT}"

# 表格列宽（第一列由 main 按 benchmark 名称自动计算）
TABLE_NAME_WIDTH=0
TABLE_REMARK_WIDTH=0
TABLE_QPS_WIDTH=12
TABLE_P50_WIDTH=12
TABLE_P95_WIDTH=12
TABLE_P99_WIDTH=12
TABLE_AB_REQ_WIDTH=14
TABLE_AB_FAILED_WIDTH=12
TABLE_AB_RPS_WIDTH=12
TABLE_KA_REQ_WIDTH=14
TABLE_KA_FAILED_WIDTH=12
TABLE_KA_RPS_WIDTH=12

# wrk / server 参数（默认对齐机器 CPU/2，可用环境变量覆盖）
CPU_COUNT="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1)"
DEFAULT_BENCH_THREADS=$((CPU_COUNT / 2))
if [ "$DEFAULT_BENCH_THREADS" -lt 1 ]; then
    DEFAULT_BENCH_THREADS=1
fi
WRK_THREADS="${WRK_THREADS:-$DEFAULT_BENCH_THREADS}"
WRK_CONNECTIONS="${WRK_CONNECTIONS:-64}"
WRK_DURATION="${WRK_DURATION:-10s}"
SERVER_THREADS="${SERVER_THREADS:-$DEFAULT_BENCH_THREADS}"
ASYNC_BENCH_MODE="${UYA_ASYNC_BENCH_MODE:-auto}"
if [ "$ASYNC_BENCH_MODE" = "auto" ]; then
    case "$(uname -s 2>/dev/null || echo unknown):$(uname -m 2>/dev/null || echo unknown)" in
        Linux:x86_64|Linux:amd64)
            ASYNC_BENCH_MODE="nostdlib"
            ;;
        *)
            ASYNC_BENCH_MODE="hosted"
            ;;
    esac
fi

# Linux nostdlib async 基准使用一线程一 reactor。默认跑满在线 CPU，可显著降低
# 高 QPS 下的 p99 尾延迟；hosted 路线仍沿用 CPU/2，避免过度放大宿主 pthread 路径噪声。
if [ "$ASYNC_BENCH_MODE" = "nostdlib" ]; then
    DEFAULT_UYA_ASYNC_SERVER_THREADS="$CPU_COUNT"
else
    DEFAULT_UYA_ASYNC_SERVER_THREADS="$DEFAULT_BENCH_THREADS"
fi
UYA_ASYNC_SERVER_THREADS="${UYA_ASYNC_SERVER_THREADS:-$DEFAULT_UYA_ASYNC_SERVER_THREADS}"
AB_KEEPALIVE_REQUESTS="${AB_KEEPALIVE_REQUESTS:-20000}"
AB_KEEPALIVE_CONCURRENCY="${AB_KEEPALIVE_CONCURRENCY:-100}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }

nginx_bench_pid_matches() {
    local pid="$1"
    local args=""

    case "$pid" in
        ""|*[!0-9]*) return 1 ;;
    esac

    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    case "$args" in
        *"$NGINX_BENCH_DIR"*) return 0 ;;
        *) return 1 ;;
    esac
}

cleanup_nginx_bench_processes() {
    local nginx_bin="$NGINX_EXEC"
    local pid=""
    local child_pids=""
    local child_pid=""
    local i=0

    if [ -z "$nginx_bin" ]; then
        nginx_bin="$(command -v nginx 2>/dev/null || true)"
    fi

    if [ ! -f "$NGINX_PID_FILE" ]; then
        return
    fi

    pid="$(cat "$NGINX_PID_FILE" 2>/dev/null || true)"
    if ! nginx_bench_pid_matches "$pid"; then
        rm -f "$NGINX_PID_FILE" 2>/dev/null || true
        return
    fi

    if [ -n "$pid" ]; then
        child_pids="$(pgrep -P "$pid" 2>/dev/null || true)"
    fi

    if [ -n "$nginx_bin" ]; then
        "$nginx_bin" -p "$NGINX_BENCH_DIR" -c nginx.conf -s quit >/dev/null 2>&1 || \
            "$nginx_bin" -p "$NGINX_BENCH_DIR" -c nginx.conf -s stop >/dev/null 2>&1 || true
    fi

    while [ "$i" -lt 20 ]; do
        local any_alive=0
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            any_alive=1
        fi
        for child_pid in $child_pids; do
            if kill -0 "$child_pid" 2>/dev/null; then
                any_alive=1
            fi
        done
        if [ "$any_alive" -eq 0 ]; then
            break
        fi
        sleep 0.1
        i=$((i + 1))
    done

    for child_pid in $child_pids; do
        if kill -0 "$child_pid" 2>/dev/null; then
            kill "$child_pid" 2>/dev/null || true
        fi
    done
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi

    sleep 0.2
    for child_pid in $child_pids; do
        if kill -0 "$child_pid" 2>/dev/null; then
            kill -9 "$child_pid" 2>/dev/null || true
        fi
    done
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$NGINX_PID_FILE" 2>/dev/null || true
}

cleanup_http_bench_processes() {
    pkill -9 -f "http_bench_uya" 2>/dev/null || true
    pkill -9 -f "http_bench_fork" 2>/dev/null || true
    pkill -9 -f "http_bench_async_epoll_await_simple" 2>/dev/null || true
    pkill -9 -f "http_bench_async_epoll_await_stack" 2>/dev/null || true
    pkill -9 -f "http_bench_async_epoll_await" 2>/dev/null || true
    pkill -9 -f "http_bench_async_epoll" 2>/dev/null || true
    pkill -9 -f "http_bench_go" 2>/dev/null || true
    pkill -9 -f "http_bench_go_gnet" 2>/dev/null || true
    pkill -9 -f "http_bench_uyagin" 2>/dev/null || true
    pkill -9 -f "http_bench_c_async_epoll" 2>/dev/null || true
    pkill -9 -f "http_bench_c" 2>/dev/null || true
    pkill -9 -f "http_bench_zap" 2>/dev/null || true
    pkill -9 -f "http_bench_tokio" 2>/dev/null || true
    cleanup_nginx_bench_processes
}

result_field() {
    local result="$1"
    local idx="$2"
    echo "$result" | awk -F'|' -v n="$idx" '{print $n}' | tr -d '\r\n '
}

table_dashes() {
    local width="$1"
    local dash_width=$((width + 2))
    printf '%*s' "$dash_width" '' | tr ' ' '-'
}

table_name_width() {
    local padding=1
    local max=0
    local name
    local len

    for name in "$@"; do
        len=${#name}
        if [ "$len" -gt "$max" ]; then
            max=$len
        fi
    done

    printf '%s' $((max + padding))
}

table_remark_for() {
    local name="$1"
    case "$name" in
        http_bench.uya) echo "base" ;;
        http_bench_fork.uya) echo "fork" ;;
        http_bench_async_epoll.uya) echo "epoll" ;;
        http_bench_async_epoll_await.uya) echo "await" ;;
        http_bench_async_epoll_await_simple.uya) echo "simp" ;;
        http_bench_async_epoll_await_stack.uya) echo "stack" ;;
        http_bench.go) echo "go" ;;
        go-gnet) echo "gnet" ;;
        uyagin) echo "uyagin" ;;
        http_bench.c) echo "c" ;;
        http_bench_async_epoll.c) echo "c-ep" ;;
        zap) echo "zap" ;;
        nginx) echo "nginx" ;;
        http_bench_tokio) echo "tokio" ;;
        *) echo "" ;;
    esac
}

table_remark_width() {
    local padding=1
    local max=0
    local name
    local remark
    local len

    for name in "$@"; do
        remark="$(table_remark_for "$name")"
        len=${#remark}
        if [ "$len" -gt "$max" ]; then
            max=$len
        fi
    done

    printf '%s' $((max + padding))
}

# 检查依赖
check_dep() {
    if ! command -v "$1" &> /dev/null; then
        log_err "缺少依赖: $1"
        exit 1
    fi
}

wrk_latency_to_us() {
    local token="${1:-}"
    local value

    token="${token//$'\r'/}"
    token="${token//$'\n'/}"
    token="${token// /}"
    if [ -z "$token" ]; then
        echo "0"
        return
    fi

    case "$token" in
        *ns)
            value="${token%ns}"
            awk "BEGIN { printf \"%.2f\", $value / 1000.0 }"
            ;;
        *us)
            printf '%s' "${token%us}"
            ;;
        *ms)
            value="${token%ms}"
            awk "BEGIN { printf \"%.2f\", $value * 1000.0 }"
            ;;
        *s)
            value="${token%s}"
            awk "BEGIN { printf \"%.2f\", $value * 1000000.0 }"
            ;;
        *m)
            value="${token%m}"
            awk "BEGIN { printf \"%.2f\", $value * 60000000.0 }"
            ;;
        *)
            echo "0"
            ;;
    esac
}

# 解析 wrk 输出，返回格式: req|count|dur|p50|p95|p99|rps
parse_wrk() {
    local output="$1"
    local req=0
    local count=0
    local dur=0
    local avg_token=""
    local p50_token=""
    local p95_token=""
    local p99_token=""
    local p50=0
    local p95=0
    local p99=0
    local rps=0

    rps=$(printf '%s\n' "$output" | awk '/Requests\/sec:/ {print $2; exit}')
    if [ -z "$rps" ]; then rps=0; fi

    req=$(printf '%s\n' "$output" | awk '/requests in/ {print $1; exit}')
    if [ -z "$req" ]; then req=0; fi

    count="$req"

    dur=$(printf '%s\n' "$output" | awk '/requests in/ {gsub(/,/, "", $4); sub(/[smh]$/, "", $4); print $4; exit}')
    if [ -z "$dur" ]; then dur=0; fi

    avg_token=$(printf '%s\n' "$output" | awk '/^[[:space:]]*Latency[[:space:]]/ {print $2; exit}')
    p50_token=$(printf '%s\n' "$output" | awk '/^[[:space:]]*50(%|\.00%)/ {print $2; exit}')
    p95_token=$(printf '%s\n' "$output" | awk '/^[[:space:]]*95(%|\.00%)/ {print $2; exit}')
    p99_token=$(printf '%s\n' "$output" | awk '/^[[:space:]]*99(%|\.00%)/ {print $2; exit}')

    # 某些 wrk 版本默认只输出 50/75/90/99 分位；缺少 95% 时退回 90% 近似值，避免显示为 0。
    if [ -z "$p95_token" ]; then
        p95_token=$(printf '%s\n' "$output" | awk '/^[[:space:]]*90(%|\.00%)/ {print $2; exit}')
    fi

    if [ -z "$p50_token" ]; then p50_token="$avg_token"; fi
    if [ -z "$p95_token" ]; then p95_token="$avg_token"; fi
    if [ -z "$p99_token" ]; then p99_token="$avg_token"; fi

    p50=$(wrk_latency_to_us "$p50_token")
    p95=$(wrk_latency_to_us "$p95_token")
    p99=$(wrk_latency_to_us "$p99_token")

    echo "$req|$count|$dur|$p50|$p95|$p99|$rps"
}

# 准备 nginx 对照服务：仅服务根路径 "/"，与其它实现保持同样的响应体大小。
prepare_nginx_bench() {
    if ! command -v nginx &> /dev/null; then
        log_warn "未找到 nginx，跳过 nginx 版本编译与压测"
        return 1
    fi
    NGINX_EXEC="$(command -v nginx)"

    cleanup_nginx_bench_processes
    rm -rf "$NGINX_BENCH_DIR"
    mkdir -p "$NGINX_BENCH_DIR"

    cat > "$NGINX_CONF_FILE" << EOF
worker_processes  1;
error_log stderr warn;
pid ${NGINX_PID_FILE};

events {
    worker_connections  1024;
}

http {
    access_log off;
    keepalive_timeout 65;
    default_type text/plain;

    server {
        listen 127.0.0.1:8876;
        server_name 127.0.0.1;

        location = / {
            return 200 "hello";
        }

        location = /plaintext {
            return 200 "hello";
        }
    }
}
EOF

    if ! "$NGINX_EXEC" -p "$NGINX_BENCH_DIR" -c nginx.conf -t >/tmp/http_bench_nginx_config.log 2>&1; then
        log_err "nginx 配置校验失败，日志:"
        cat /tmp/http_bench_nginx_config.log >&2
        return 1
    fi

    log_info "nginx 版本配置完成: $NGINX_CONF_FILE"
    return 0
}

# 编译 Uya fork 版本
build_uya_fork() {
    log_info "编译 Uya fork HTTP 服务器..."
    if [ ! -f "$UYA_BIN" ]; then
        log_err "找不到 Uya 编译器: $UYA_BIN"
        exit 1
    fi
    if [ ! -f "$UYA_FORK_SRC" ]; then
        log_err "找不到 Uya fork 源文件: $UYA_FORK_SRC"
        exit 1
    fi
    if ! "$UYA_BIN" build "$UYA_FORK_ENTRY" -o /tmp/http_bench_fork.c --c99 >/tmp/uya_fork_build.log 2>&1; then
        log_err "Uya fork 编译失败，日志:"
        cat /tmp/uya_fork_build.log >&2
        exit 1
    fi
    if ! cc -std=c99 -no-pie -O2 -fno-builtin -o "$UYA_FORK_EXEC" /tmp/http_bench_fork.c -lm >/tmp/uya_fork_cc.log 2>&1; then
        log_err "Uya fork C 编译失败，日志:"
        cat /tmp/uya_fork_cc.log >&2
        exit 1
    fi
    log_info "Uya fork 版本编译完成: $UYA_FORK_EXEC"
}

# 编译 Uya C99 直出版本
build_uya_c99_variant() {
    local label="$1"
    local src="$2"
    local entry="$3"
    local exec="$4"
    local cfile="$5"
    local cflags_override="${6:-}"
    local stem
    stem="$(basename "$cfile" .c)"
    local -a cflags_argv=()

    log_info "编译 ${label} HTTP 服务器..."
    if [ ! -f "$UYA_BIN" ]; then
        log_err "找不到 Uya 编译器: $UYA_BIN"
        exit 1
    fi
    if [ ! -f "$src" ]; then
        log_err "找不到 ${label} 源文件: $src"
        exit 1
    fi
    if [ -n "$cflags_override" ]; then
        read -r -a cflags_argv <<< "$cflags_override"
    else
        cflags_argv=(-std=c99 -O2 -fno-builtin)
    fi
    # 这里使用 --c99 直出路径，和 verify_http_bench_async_epoll_runtime.sh 保持一致，避免 build 子命令路径差异
    if ! "$UYA_BIN" --c99 "$entry" -o "$cfile" >/tmp/"${stem}"_build.log 2>&1; then
        log_err "${label} 编译失败，日志:"
        cat "/tmp/${stem}_build.log" >&2
        exit 1
    fi
    # async 系列使用单独的已验证旗标，避免与 fork / 基础版共用较弱的默认组合。
    if ! cc "${cflags_argv[@]}" -no-pie -o "$exec" "$cfile" -lm >/tmp/"${stem}"_cc.log 2>&1; then
        log_err "${label} C 编译失败，日志:"
        cat "/tmp/${stem}_cc.log" >&2
        exit 1
    fi
    log_info "${label} 版本编译完成: $exec"
}

build_uya_nostdlib_c99_variant() {
    local label="$1"
    local src="$2"
    local entry="$3"
    local exec="$4"
    local cfile="$5"
    local cflags_override="${6:-}"
    local stem
    stem="$(basename "$cfile" .c)"
    local -a cflags_argv=()

    log_info "编译 ${label} HTTP 服务器（nostdlib）..."
    if [ ! -f "$UYA_BIN" ]; then
        log_err "找不到 Uya 编译器: $UYA_BIN"
        exit 1
    fi
    if [ ! -f "$src" ]; then
        log_err "找不到 ${label} 源文件: $src"
        exit 1
    fi
    if [ -n "$cflags_override" ]; then
        read -r -a cflags_argv <<< "$cflags_override"
    else
        cflags_argv=(-std=c99 -O3 -fno-builtin -fno-stack-protector)
    fi
    if ! "$UYA_BIN" --c99 --nostdlib "$entry" -o "$cfile" >/tmp/"${stem}"_build.log 2>&1; then
        log_err "${label} nostdlib 编译失败，日志:"
        cat "/tmp/${stem}_build.log" >&2
        exit 1
    fi
    if ! cc "${cflags_argv[@]}" -no-pie -nostdlib -static -o "$exec" "$cfile" -lgcc >/tmp/"${stem}"_cc.log 2>&1; then
        log_err "${label} nostdlib C 编译失败，日志:"
        cat "/tmp/${stem}_cc.log" >&2
        exit 1
    fi
    log_info "${label} nostdlib 版本编译完成: $exec"
}

build_uya_async_variant() {
    local label="$1"
    local src="$2"
    local entry="$3"
    local exec="$4"
    local cfile="$5"
    local stem
    local split_root=""
    local split_dir=""
    stem="$(basename "$cfile" .c)"

    if [ "$ASYNC_BENCH_MODE" = "nostdlib" ]; then
        log_info "编译 ${label} HTTP 服务器（nostdlib）..."
        if [ ! -f "$UYA_BIN" ]; then
            log_err "找不到 Uya 编译器: $UYA_BIN"
            exit 1
        fi
        if [ ! -f "$src" ]; then
            log_err "找不到 ${label} 源文件: $src"
            exit 1
        fi
        # 多文件 C mirror Makefile 会把标准库镜像产物写到 split_dir 的上一级 ../lib；
        # 这里把 split 根整体放到 /tmp，避免在 benchmarks/ 下生成 lib/libc、lib/std 中间物。
        split_root="/tmp/uya-bench-${stem}"
        split_dir="${split_root}/cache"
        rm -rf "$split_root"
        mkdir -p "$split_dir"
        if ! "$UYA_BIN" --c99 --nostdlib -O2 "$entry" --split-c-dir "$split_dir" -o "$exec" >/tmp/"${stem}"_build.log 2>&1; then
            log_err "${label} nostdlib 编译失败，日志:"
            cat "/tmp/${stem}_build.log" >&2
            exit 1
        fi
        log_info "${label} nostdlib 版本编译完成: $exec"
        return 0
    fi

    build_uya_c99_variant "$label" "$src" "$entry" "$exec" "$cfile" "$ASYNC_BENCH_CFLAGS"
}

# 编译 Uya HTTP 基础版本
build_uya_http() {
    build_uya_c99_variant "Uya HTTP" "$UYA_HTTP_SRC" "$UYA_HTTP_ENTRY" "$UYA_HTTP_EXEC" /tmp/http_bench_uya.c
}

# 编译 UyaGin 版本
build_uyagin() {
    if [ "$UYA_GIN_MODE" = "nostdlib" ]; then
        build_uya_nostdlib_c99_variant "UyaGin" "$UYA_GIN_SRC" "$UYA_GIN_ENTRY" "$UYA_GIN_EXEC" /tmp/http_bench_uyagin.c "$UYA_GIN_NOSTDLIB_CFLAGS"
    else
        build_uya_c99_variant "UyaGin" "$UYA_GIN_SRC" "$UYA_GIN_ENTRY" "$UYA_GIN_EXEC" /tmp/http_bench_uyagin.c "$UYA_GIN_CFLAGS"
    fi
}

# 编译 Uya async epoll 版本
build_uya_async_epoll() {
    build_uya_async_variant "Uya async epoll" "$UYA_ASYNC_EPOLL_SRC" "$UYA_ASYNC_EPOLL_ENTRY" "$UYA_ASYNC_EPOLL_EXEC" /tmp/http_bench_async_epoll.c
}

# 编译 Uya async await 版本
build_uya_async_await() {
    build_uya_async_variant "Uya async await" "$UYA_ASYNC_AWAIT_SRC" "$UYA_ASYNC_AWAIT_ENTRY" "$UYA_ASYNC_AWAIT_EXEC" /tmp/http_bench_async_epoll_await.c
}

# 编译 Uya async await simple 版本
build_uya_async_await_simple() {
    build_uya_async_variant "Uya async await simple" "$UYA_ASYNC_AWAIT_SIMPLE_SRC" "$UYA_ASYNC_AWAIT_SIMPLE_ENTRY" "$UYA_ASYNC_AWAIT_SIMPLE_EXEC" /tmp/http_bench_async_epoll_await_simple.c
}

# 编译 Uya async await stack 版本
build_uya_async_await_stack() {
    build_uya_async_variant "Uya async await stack" "$UYA_ASYNC_AWAIT_STACK_SRC" "$UYA_ASYNC_AWAIT_STACK_ENTRY" "$UYA_ASYNC_AWAIT_STACK_EXEC" /tmp/http_bench_async_epoll_await_stack.c
}

# 编译 Go 版本
build_go() {
    log_info "编译 Go HTTP 服务器..."
    if ! command -v go &> /dev/null; then
        log_warn "未找到 go，跳过 Go 版本编译与压测"
        return 1
    fi
    if [ ! -f "$GO_SRC" ]; then
        log_err "找不到 Go 源文件: $GO_SRC"
        exit 1
    fi
    go build -o "$GO_EXEC" "$GO_SRC"
    log_info "Go 版本编译完成: $GO_EXEC"
}

# 编译 go-gnet 版本
build_go_gnet() {
    log_info "编译 go-gnet HTTP 服务器..."
    if ! command -v git &> /dev/null; then
        log_warn "未找到 git，跳过 go-gnet 版本编译与压测"
        return 1
    fi
    if ! command -v go &> /dev/null; then
        log_warn "未找到 go，跳过 go-gnet 版本编译与压测"
        return 1
    fi

    if [ ! -d "$GO_GNET_REPO_DIR/.git" ]; then
        rm -rf "$GO_GNET_REPO_DIR"
        if ! git clone --depth 1 --branch "$GO_GNET_REPO_TAG" "$GO_GNET_REPO_URL" "$GO_GNET_REPO_DIR" >/tmp/http_bench_go_gnet_clone.log 2>&1; then
            log_warn "go-gnet 仓库克隆失败，跳过 go-gnet 版本编译与压测"
            cat /tmp/http_bench_go_gnet_clone.log >&2
            return 1
        fi
    fi

    local current_tag=""
    current_tag="$(git -C "$GO_GNET_REPO_DIR" describe --tags --exact-match 2>/dev/null || true)"
    if [ "$current_tag" != "$GO_GNET_REPO_TAG" ]; then
        rm -rf "$GO_GNET_REPO_DIR"
        if ! git clone --depth 1 --branch "$GO_GNET_REPO_TAG" "$GO_GNET_REPO_URL" "$GO_GNET_REPO_DIR" >/tmp/http_bench_go_gnet_clone.log 2>&1; then
            log_warn "go-gnet 仓库克隆失败，跳过 go-gnet 版本编译与压测"
            cat /tmp/http_bench_go_gnet_clone.log >&2
            return 1
        fi
    fi

    if [ ! -f "$GO_GNET_REPO_DIR/http-gnet-server/main.go" ]; then
        log_err "go-gnet 仓库中找不到 http-gnet-server/main.go"
        exit 1
    fi

    local goproxy_override="${GO_GNET_BENCH_GOPROXY:-}"
    local attempts=()
    if [ -n "$goproxy_override" ]; then
        attempts+=("override:${goproxy_override}" "$goproxy_override")
    else
        attempts+=("goproxy.cn" "https://goproxy.cn,direct" "default" "" "direct" "direct")
    fi

    local build_log="/tmp/http_bench_go_gnet_build.log"
    local failure_logs=()
    local used_goproxy="default"
    local idx=0
    while [ "$idx" -lt "${#attempts[@]}" ]; do
        local label="${attempts[$idx]}"
        local goproxy_value="${attempts[$((idx + 1))]}"
        local env_args=()
        local attempt_log=""
        idx=$((idx + 2))

        if [ -n "$goproxy_value" ]; then
            env_args=("GOPROXY=$goproxy_value")
        fi
        attempt_log="$build_log"
        if [ -n "$goproxy_override" ] || [ "${#attempts[@]}" -gt 2 ]; then
            attempt_log="/tmp/http_bench_go_gnet_attempt${idx}.log"
        fi

        if (cd "$GO_GNET_REPO_DIR" && env "${env_args[@]}" go build -gcflags="-l=4" -ldflags="-s -w" -o "$GO_GNET_EXEC" ./http-gnet-server >/dev/null 2>"$attempt_log"); then
            used_goproxy="${goproxy_value:-default}"
            if [ "$attempt_log" != "$build_log" ]; then
                {
                    printf '# go-gnet build attempt: %s\n' "$label"
                    printf '# GOPROXY=%s\n\n' "$used_goproxy"
                    cat "$attempt_log"
                } >"$build_log"
            fi
            log_info "go-gnet 版本编译完成: $GO_GNET_EXEC"
            return 0
        fi

        failure_logs+=("## attempt: ${label}" "$(cat "$attempt_log" 2>/dev/null || true)" "")
    done

    {
        for line in "${failure_logs[@]}"; do
            printf '%s\n' "$line"
        done
    } >"$build_log"
    log_err "go-gnet 编译失败，日志:"
    cat "$build_log" >&2
    exit 1
}

# 编译 Rust Tokio 版本（与 http_bench.go 路由一致）
build_tokio() {
    if ! command -v cargo &> /dev/null; then
        log_warn "未找到 cargo，跳过 Tokio 版本编译与压测"
        return 1
    fi
    if [ ! -f "${TOKIO_DIR}/Cargo.toml" ]; then
        log_warn "未找到 ${TOKIO_DIR}/Cargo.toml，跳过 Tokio"
        return 1
    fi
    log_info "编译 Rust Tokio HTTP 服务器..."
    (cd "$TOKIO_DIR" && cargo build --release -q)
    cp "${TOKIO_DIR}/target/release/http_bench_tokio" "$TOKIO_EXEC"
    log_info "Tokio 版本编译完成: $TOKIO_EXEC"
    return 0
}

# 编译 C 版本
build_c() {
    log_info "编译 C HTTP 服务器..."
    if [ ! -f "$C_SRC" ]; then
        log_err "找不到 C 源文件: $C_SRC"
        exit 1
    fi
    cc -O3 -Wall -Wextra -pthread -o "$C_EXEC" "$C_SRC"
    log_info "C 版本编译完成: $C_EXEC"
}

# 编译 C async epoll 版本
build_c_async_epoll() {
    log_info "编译 C async epoll HTTP 服务器..."
    if [ ! -f "$C_ASYNC_EPOLL_SRC" ]; then
        log_err "找不到 C async epoll 源文件: $C_ASYNC_EPOLL_SRC"
        exit 1
    fi
    cc -O3 -Wall -Wextra -pthread -o "$C_ASYNC_EPOLL_EXEC" "$C_ASYNC_EPOLL_SRC"
    log_info "C async epoll 版本编译完成: $C_ASYNC_EPOLL_EXEC"
}

# 编译 Zap 版本
build_zap() {
    log_info "编译 Zap HTTP 服务器..."
    if ! command -v git &> /dev/null; then
        log_warn "未找到 git，跳过 Zap 版本编译与压测"
        return 1
    fi
    if [ ! -x "$ZIG_BIN" ]; then
        log_warn "未找到可执行的 Zig: $ZIG_BIN，跳过 Zap 版本编译与压测"
        return 1
    fi
    if [ ! -f "$ZAP_SRC" ]; then
        log_err "找不到 Zap 源文件: $ZAP_SRC"
        exit 1
    fi

    if [ ! -d "$ZAP_REPO_DIR/.git" ]; then
        rm -rf "$ZAP_REPO_DIR"
        if ! git clone --depth 1 --branch "$ZAP_REPO_TAG" "$ZAP_REPO_URL" "$ZAP_REPO_DIR" >/tmp/http_bench_zap_clone.log 2>&1; then
            log_warn "Zap 仓库克隆失败，跳过 Zig 版本编译与压测"
            cat /tmp/http_bench_zap_clone.log >&2
            return 1
        fi
    fi

    local current_tag=""
    current_tag="$(git -C "$ZAP_REPO_DIR" describe --tags --exact-match 2>/dev/null || true)"
    if [ "$current_tag" != "$ZAP_REPO_TAG" ]; then
        rm -rf "$ZAP_REPO_DIR"
        if ! git clone --depth 1 --branch "$ZAP_REPO_TAG" "$ZAP_REPO_URL" "$ZAP_REPO_DIR" >/tmp/http_bench_zap_clone.log 2>&1; then
            log_warn "Zap 仓库克隆失败，跳过 Zig 版本编译与压测"
            cat /tmp/http_bench_zap_clone.log >&2
            return 1
        fi
    fi

    if [ ! -f "$ZAP_REPO_DIR/examples/hello/hello.zig" ]; then
        log_err "Zap 仓库中找不到 examples/hello/hello.zig"
        exit 1
    fi

    cp "$ZAP_SRC" "$ZAP_REPO_DIR/examples/hello/hello.zig"

    if ! (cd "$ZAP_REPO_DIR" && "$ZIG_BIN" build hello -Doptimize=ReleaseFast >/tmp/http_bench_zap_build.log 2>&1); then
        log_err "Zap 编译失败，日志:"
        cat /tmp/http_bench_zap_build.log >&2
        exit 1
    fi

    if [ ! -f "$ZAP_REPO_DIR/zig-out/bin/hello" ]; then
        log_err "Zap 编译成功但未找到输出文件: $ZAP_REPO_DIR/zig-out/bin/hello"
        exit 1
    fi

    cat > "$ZAP_EXEC" <<EOF
#!/bin/sh
cd "$ZAP_REPO_DIR" || exit 1
exec "$ZAP_REPO_DIR/zig-out/bin/hello" "\$@"
EOF
    chmod +x "$ZAP_EXEC"
    log_info "Zap 版本编译完成: $ZAP_EXEC"
}

# 运行服务器并执行基准测试
run_benchmark() {
    local name="$1"
    local exec="$2"
    local port="$3"
    local url="$4"
    shift 4
    local extra_args=("$@")

    echo "--- $name 基准测试 ---" >&2

    # 启动服务器前强制清理同名旧进程并等待端口释放
    cleanup_http_bench_processes
    sleep 2

    # 启动服务器
    local server_log="/tmp/http_bench_${name//[^a-zA-Z0-9_]/_}.server.log"
    rm -f "$server_log"
    "$exec" "${extra_args[@]}" >"$server_log" 2>&1 &
    local pid=$!
    sleep 2

    # 检查服务器是否运行
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ERROR: $name 服务器启动失败" >&2
        if [ -f "$server_log" ]; then
            echo "---- $name 启动日志 ----" >&2
            sed -n '1,80p' "$server_log" >&2
            echo "-----------------------" >&2
        fi
        wait "$pid" 2>/dev/null || true
        return 1
    fi

    # 运行 wrk
    echo "运行 wrk --latency -t${WRK_THREADS} -c${WRK_CONNECTIONS} -d${WRK_DURATION} $url" >&2
    local output
    output=$(wrk --latency -t"$WRK_THREADS" -c"$WRK_CONNECTIONS" -d"$WRK_DURATION" "$url" 2>&1)
    echo "$output" >&2

    # 解析结果
    local parsed
    parsed=$(parse_wrk "$output")
    IFS='|' read -r req count dur p50 p95 p99 rps <<< "$parsed"

    # 清理服务器（Uya fork 会 fork 子进程，需要用 pkill）
    cleanup_http_bench_processes
    wait "$pid" 2>/dev/null || true
    sleep 2

    # 输出结果摘要
    echo "" >&2
    echo "$name 结果:" >&2
    echo "  QPS: ${rps:-0}" >&2
    echo "  总请求: ${count:-0}" >&2
    echo "  耗时: ${dur:-0}s" >&2
    echo "  p50: ${p50:-0}us" >&2
    echo "  p95: ${p95:-0}us" >&2
    echo "  p99: ${p99:-0}us" >&2
    echo "" >&2

    echo "$name|$req|$count|$dur|$p50|$p95|$p99|$rps"
}

run_benchmark_safe() {
    local name="$1"
    local exec="$2"
    local port="$3"
    local url="$4"
    shift 4
    local extra_args=("$@")
    local result
    if result=$(run_benchmark "$name" "$exec" "$port" "$url" "${extra_args[@]}"); then
        echo "$result"
        return 0
    fi
    log_err "$name 基准测试失败，按 0 计入结果"
    echo "$name|0|0|0|0|0|0|0"
    return 0
}

run_keepalive_probe() {
    local name="$1"
    local exec="$2"
    local port="$3"
    local url="$4"
    shift 4
    local extra_args=("$@")

    echo "--- $name Keep-Alive 验证（ab -k）---" >&2

    cleanup_http_bench_processes
    sleep 2

    local server_log="/tmp/http_bench_${name//[^a-zA-Z0-9_]/_}.keepalive.log"
    rm -f "$server_log"
    "$exec" "${extra_args[@]}" >"$server_log" 2>&1 &
    local pid=$!
    sleep 2

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ERROR: $name Keep-Alive 验证服务启动失败" >&2
        if [ -f "$server_log" ]; then
            echo "---- $name Keep-Alive 启动日志 ----" >&2
            sed -n '1,80p' "$server_log" >&2
            echo "-----------------------" >&2
        fi
        wait "$pid" 2>/dev/null || true
        return 1
    fi

    local output
    output=$(ab -k -n "$AB_KEEPALIVE_REQUESTS" -c "$AB_KEEPALIVE_CONCURRENCY" "$url" 2>&1 || true)
    echo "$output" >&2

    local ka
    local failed
    local rps
    ka=$(echo "$output" | awk '/Keep-Alive requests/ {print $3}' | tr -d '\r\n ')
    failed=$(echo "$output" | awk '/Failed requests/ {print $3}' | tr -d '\r\n ')
    rps=$(echo "$output" | awk '/Requests per second/ {print $4}' | tr -d '\r\n ')
    if [ -z "$ka" ]; then ka=0; fi
    if [ -z "$failed" ]; then failed=0; fi
    if [ -z "$rps" ]; then rps=0; fi

    cleanup_http_bench_processes
    wait "$pid" 2>/dev/null || true
    sleep 2

    echo "$name Keep-Alive 结果: keep_alive=${ka}, failed=${failed}, rps=${rps}" >&2
    echo "$name|$ka|$failed|$rps"
}

run_keepalive_probe_safe() {
    local name="$1"
    local exec="$2"
    local port="$3"
    local url="$4"
    shift 4
    local extra_args=("$@")
    local result
    if result=$(run_keepalive_probe "$name" "$exec" "$port" "$url" "${extra_args[@]}"); then
        echo "$result"
        return 0
    fi
    log_err "$name Keep-Alive 验证失败，按 0 计入结果"
    echo "$name|0|0|0"
    return 0
}

run_ab_probe() {
    local name="$1"
    local exec="$2"
    local port="$3"
    local url="$4"
    shift 4
    local extra_args=("$@")

    echo "--- $name AB 验证 ---" >&2

    cleanup_http_bench_processes
    sleep 2

    local server_log="/tmp/http_bench_${name//[^a-zA-Z0-9_]/_}.ab.log"
    rm -f "$server_log"
    "$exec" "${extra_args[@]}" >"$server_log" 2>&1 &
    local pid=$!
    sleep 2

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ERROR: $name AB 验证服务启动失败" >&2
        if [ -f "$server_log" ]; then
            echo "---- $name AB 启动日志 ----" >&2
            sed -n '1,80p' "$server_log" >&2
            echo "-----------------------" >&2
        fi
        wait "$pid" 2>/dev/null || true
        return 1
    fi

    local output
    output=$(ab -n "$AB_KEEPALIVE_REQUESTS" -c "$AB_KEEPALIVE_CONCURRENCY" "$url" 2>&1 || true)
    echo "$output" >&2

    local req=0
    local failed=0
    local rps=0
    req=$(echo "$output" | awk '/Complete requests:/ {print $3}' | tr -d '\r\n ')
    failed=$(echo "$output" | awk '/Failed requests:/ {print $3}' | tr -d '\r\n ')
    rps=$(echo "$output" | awk '/Requests per second:/ {print $4}' | tr -d '\r\n ')
    if [ -z "$req" ]; then req=0; fi
    if [ -z "$failed" ]; then failed=0; fi
    if [ -z "$rps" ]; then rps=0; fi

    cleanup_http_bench_processes
    wait "$pid" 2>/dev/null || true
    sleep 2

    echo "$name AB 结果: req=${req}, failed=${failed}, rps=${rps}" >&2
    echo "$name|$req|$failed|$rps"
}

run_ab_probe_safe() {
    local name="$1"
    local exec="$2"
    local port="$3"
    local url="$4"
    shift 4
    local extra_args=("$@")
    local result
    if result=$(run_ab_probe "$name" "$exec" "$port" "$url" "${extra_args[@]}"); then
        echo "$result"
        return 0
    fi
    log_err "$name AB 验证失败，按 0 计入结果"
    echo "$name|0|0|0"
    return 0
}

# 生成 baseline.json
save_baseline() {
    local uya_root_rps="$1"
    local uya_fork_root_rps="$2"
    local uya_async_epoll_root_rps="$3"
    local uya_async_await_root_rps="$4"
    local uya_async_await_simple_root_rps="$5"
    local uya_async_await_stack_root_rps="$6"
    local go_root_rps="$7"
    local go_gnet_root_rps="$8"
    local uyagin_root_rps="$9"
    local c_root_rps="${10}"
    local c_async_epoll_root_rps="${11}"
    local zap_root_rps="${12}"
    local nginx_root_rps="${13}"
    local tokio_root_rps="${14}"
    local timestamp
    timestamp=$(date -Iseconds)

    log_info "保存基线数据到 baseline.json..."

    cat > "${SCRIPT_DIR}/baseline.json" << EOF
{
  "timestamp": "${timestamp}",
  "machine": {
    "cpu": "Intel(R) Core(TM) i7-14700 (20C/28T)",
    "memory_gb": 31,
    "os": "Deepin 25 (crimson)",
    "kernel": "6.12.65-amd64-desktop-rolling",
    "cc": "Deepin 12.3.0-17deepin15",
    "go": "1.24.2"
  },
  "wrk_params": {
    "threads": ${WRK_THREADS},
    "connections": ${WRK_CONNECTIONS},
    "duration": "${WRK_DURATION}",
    "server_threads": ${SERVER_THREADS}
  },
  "results": {
    "root": {
      "uya_qps": ${uya_root_rps:-0},
      "uya_fork_qps": ${uya_fork_root_rps:-0},
      "uya_async_epoll_qps": ${uya_async_epoll_root_rps:-0},
      "uya_async_epoll_await_qps": ${uya_async_await_root_rps:-0},
      "uya_async_epoll_await_simple_qps": ${uya_async_await_simple_root_rps:-0},
      "uya_async_epoll_await_stack_qps": ${uya_async_await_stack_root_rps:-0},
      "go_qps": ${go_root_rps:-0},
      "go_gnet_qps": ${go_gnet_root_rps:-0},
      "uyagin_qps": ${uyagin_root_rps:-0},
      "c_qps": ${c_root_rps:-0},
      "c_async_epoll_qps": ${c_async_epoll_root_rps:-0},
      "zap_qps": ${zap_root_rps:-0},
      "nginx_qps": ${nginx_root_rps:-0},
      "tokio_qps": ${tokio_root_rps:-0}
    }
  }
}
EOF
    log_info "基线数据已保存"
}

# 主函数
main() {
    trap cleanup_http_bench_processes EXIT
    trap 'cleanup_http_bench_processes; exit 130' INT
    trap 'cleanup_http_bench_processes; exit 143' TERM

    log_info "HTTP 基准测试开始"
    echo ""

    check_dep wrk
    check_dep cc

    # 解析参数
    local do_baseline=0
    local do_ab=0
    local do_abk=0
    local BENCH_LIST=""

    for arg in "$@"; do
        case "$arg" in
            --baseline) do_baseline=1 ;;
            --ab) do_ab=1 ;;
            -k) do_abk=1 ;;
            *) BENCH_LIST="$BENCH_LIST $arg" ;;
        esac
    done

    if [ "$do_ab" -eq 1 ] || [ "$do_abk" -eq 1 ]; then
        check_dep ab
    fi

    bench_enabled() {
        local name="$1"
        if [ -z "$BENCH_LIST" ]; then
            return 0
        fi
        for b in $BENCH_LIST; do
            if [ "$b" = "$name" ]; then
                return 0
            fi
        done
        return 1
    }

    # 编译
    if bench_enabled "uya"; then build_uya_http; fi
    if bench_enabled "uya-fork"; then build_uya_fork; fi
    if bench_enabled "uya-async-epoll"; then build_uya_async_epoll; fi
    if bench_enabled "uya-async-await"; then build_uya_async_await; fi
    if bench_enabled "uya-async-await-simple"; then build_uya_async_await_simple; fi
    if bench_enabled "uya-async-await-stack"; then build_uya_async_await_stack; fi
    if bench_enabled "c"; then build_c; fi
    if bench_enabled "c-async-epoll"; then build_c_async_epoll; fi
    local have_zap=0
    if bench_enabled "zap"; then
        if build_zap; then have_zap=1; fi
    fi
    local have_nginx=0
    if bench_enabled "nginx"; then
        if prepare_nginx_bench; then have_nginx=1; fi
    fi

    local have_go=0
    if bench_enabled "go"; then
        if build_go; then have_go=1; fi
    fi

    local have_go_gnet=0
    if bench_enabled "go-gnet"; then
        if build_go_gnet; then have_go_gnet=1; fi
    fi

    local have_uyagin=0
    if bench_enabled "uyagin"; then
        if build_uyagin; then have_uyagin=1; fi
    fi

    local have_tokio=0
    if bench_enabled "tokio"; then
        if build_tokio; then have_tokio=1; fi
    fi

    # 测试端口
    local PORT=8876
    local URL="http://127.0.0.1:$PORT/plaintext"

    # 初始化结果
    local uya_http_result="http_bench.uya|0|0|0|0|0|0|0"
    local uya_fork_result="http_bench_fork.uya|0|0|0|0|0|0|0"
    local uya_epoll_result="http_bench_async_epoll.uya|0|0|0|0|0|0|0"
    local uya_async_await_result="http_bench_async_epoll_await.uya|0|0|0|0|0|0|0"
    local uya_async_await_simple_result="http_bench_async_epoll_await_simple.uya|0|0|0|0|0|0|0"
    local uya_async_await_stack_result="http_bench_async_epoll_await_stack.uya|0|0|0|0|0|0|0"
    local go_result="http_bench.go|0|0|0|0|0|0|0"
    local go_gnet_result="go-gnet|0|0|0|0|0|0|0"
    local uyagin_result="uyagin|0|0|0|0|0|0|0"
    local c_result="http_bench.c|0|0|0|0|0|0|0"
    local c_async_epoll_result="http_bench_async_epoll.c|0|0|0|0|0|0|0"
    local zap_result="zap|0|0|0|0|0|0|0"
    local nginx_result="nginx|0|0|0|0|0|0|0"
    local tokio_result="http_bench_tokio|0|0|0|0|0|0|0"
    local tokio_rps=0

    # 预热
    local any_enabled=0
    for b in uya uya-fork uya-async-epoll uya-async-await uya-async-await-simple uya-async-await-stack go go-gnet uyagin c c-async-epoll zap nginx tokio; do
        if bench_enabled "$b"; then any_enabled=1; break; fi
    done
    if [ "$any_enabled" -eq 1 ]; then
        if bench_enabled "uya-async-epoll" || bench_enabled "uya-async-await" || bench_enabled "uya-async-await-simple" || bench_enabled "uya-async-await-stack"; then
            if [ "$ASYNC_BENCH_MODE" = "nostdlib" ]; then
                log_info "Uya async benchmarks 默认使用 nostdlib + --threads ${UYA_ASYNC_SERVER_THREADS}"
            else
                log_warn "Uya async hosted benchmarks 默认使用 --threads ${UYA_ASYNC_SERVER_THREADS}；多线程 raw-clone pthread 路径当前不稳定，需显式设 UYA_ASYNC_SERVER_THREADS 覆盖"
            fi
        fi
        log_info "预热..."
        echo "" | wrk -t1 -c1 -d2s "$URL" >/dev/null 2>&1 || true
    fi

    # wrk 基准测试
    if bench_enabled "uya"; then
        uya_http_result=$(run_benchmark_safe "http_bench.uya" "$UYA_HTTP_EXEC" "$PORT" "$URL")
        sleep 1
    fi
    if bench_enabled "uya-fork"; then
        uya_fork_result=$(run_benchmark_safe "http_bench_fork.uya" "$UYA_FORK_EXEC" "$PORT" "$URL")
        sleep 1
    fi
    if bench_enabled "uya-async-epoll"; then
        uya_epoll_result=$(run_benchmark_safe "http_bench_async_epoll.uya" "$UYA_ASYNC_EPOLL_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS")
        sleep 1
    fi
    if bench_enabled "uya-async-await"; then
        uya_async_await_result=$(run_benchmark_safe "http_bench_async_epoll_await.uya" "$UYA_ASYNC_AWAIT_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS")
        sleep 1
    fi
    if bench_enabled "uya-async-await-simple"; then
        uya_async_await_simple_result=$(run_benchmark_safe "http_bench_async_epoll_await_simple.uya" "$UYA_ASYNC_AWAIT_SIMPLE_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS")
        sleep 1
    fi
    if bench_enabled "uya-async-await-stack"; then
        uya_async_await_stack_result=$(run_benchmark_safe "http_bench_async_epoll_await_stack.uya" "$UYA_ASYNC_AWAIT_STACK_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS")
        sleep 1
    fi
    if bench_enabled "go" && [ "$have_go" -eq 1 ]; then
        go_result=$(run_benchmark_safe "http_bench.go" "$GO_EXEC" "$PORT" "$URL")
        sleep 1
    fi
    if bench_enabled "go-gnet" && [ "$have_go_gnet" -eq 1 ]; then
        go_gnet_result=$(run_benchmark_safe "go-gnet" "$GO_GNET_EXEC" "$PORT" "$URL" --port "$PORT" --multicore=true)
        sleep 1
    fi
    if bench_enabled "uyagin" && [ "$have_uyagin" -eq 1 ]; then
        uyagin_result=$(run_benchmark_safe "uyagin" "$UYA_GIN_EXEC" "$PORT" "$URL" --port "$PORT" --threads "$SERVER_THREADS")
        sleep 1
    fi
    if bench_enabled "c"; then
        c_result=$(run_benchmark_safe "http_bench.c" "$C_EXEC" "$PORT" "$URL")
        sleep 1
    fi
    if bench_enabled "c-async-epoll"; then
        c_async_epoll_result=$(run_benchmark_safe "http_bench_async_epoll.c" "$C_ASYNC_EPOLL_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS")
        sleep 1
    fi
    if bench_enabled "zap" && [ "$have_zap" -eq 1 ]; then
        zap_result=$(run_benchmark_safe "zap" "$ZAP_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS")
        sleep 1
    fi
    if bench_enabled "nginx" && [ "$have_nginx" -eq 1 ]; then
        nginx_result=$(run_benchmark_safe "nginx" "$NGINX_EXEC" "$PORT" "$URL" -p "$NGINX_BENCH_DIR" -c nginx.conf -g "daemon off;")
        sleep 1
    fi
    if bench_enabled "tokio" && [ "$have_tokio" -eq 1 ]; then
        tokio_result=$(run_benchmark_safe "http_bench_tokio" "$TOKIO_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS")
        tokio_rps=$(echo "$tokio_result" | awk -F'|' '{print $8}')
        if [ -z "$tokio_rps" ]; then tokio_rps=0; fi
    fi

    # 提取 QPS
    local uya_rps=$(result_field "$uya_http_result" 8)
    local uya_fork_rps=$(result_field "$uya_fork_result" 8)
    local uya_epoll_rps=$(result_field "$uya_epoll_result" 8)
    local uya_async_await_rps=$(result_field "$uya_async_await_result" 8)
    local uya_async_await_simple_rps=$(result_field "$uya_async_await_simple_result" 8)
    local uya_async_await_stack_rps=$(result_field "$uya_async_await_stack_result" 8)
    local go_rps=$(result_field "$go_result" 8)
    local go_gnet_rps=$(result_field "$go_gnet_result" 8)
    local uyagin_rps=$(result_field "$uyagin_result" 8)
    local c_rps=$(result_field "$c_result" 8)
    local c_async_epoll_rps=$(result_field "$c_async_epoll_result" 8)
    local zap_rps=$(result_field "$zap_result" 8)
    local nginx_rps=$(result_field "$nginx_result" 8)
    local tokio_rps_val=$(result_field "$tokio_result" 8)
    if [ -z "$uya_rps" ]; then uya_rps=0; fi
    if [ -z "$uya_fork_rps" ]; then uya_fork_rps=0; fi
    if [ -z "$uya_epoll_rps" ]; then uya_epoll_rps=0; fi
    if [ -z "$uya_async_await_rps" ]; then uya_async_await_rps=0; fi
    if [ -z "$uya_async_await_simple_rps" ]; then uya_async_await_simple_rps=0; fi
    if [ -z "$uya_async_await_stack_rps" ]; then uya_async_await_stack_rps=0; fi
    if [ -z "$go_rps" ]; then go_rps=0; fi
    if [ -z "$go_gnet_rps" ]; then go_gnet_rps=0; fi
    if [ -z "$uyagin_rps" ]; then uyagin_rps=0; fi
    if [ -z "$c_rps" ]; then c_rps=0; fi
    if [ -z "$c_async_epoll_rps" ]; then c_async_epoll_rps=0; fi
    if [ -z "$zap_rps" ]; then zap_rps=0; fi
    if [ -z "$nginx_rps" ]; then nginx_rps=0; fi
    if [ -z "$tokio_rps_val" ]; then tokio_rps_val=0; fi

    # AB / Keep-Alive 测试
    local uya_ab_result="http_bench.uya|0|0|0"
    local uya_fork_ab_result="http_bench_fork.uya|0|0|0"
    local uya_epoll_ab_result="http_bench_async_epoll.uya|0|0|0"
    local uya_async_await_ab_result="http_bench_async_epoll_await.uya|0|0|0"
    local uya_async_await_simple_ab_result="http_bench_async_epoll_await_simple.uya|0|0|0"
    local uya_async_await_stack_ab_result="http_bench_async_epoll_await_stack.uya|0|0|0"
    local go_ab_result="http_bench.go|0|0|0"
    local go_gnet_ab_result="go-gnet|0|0|0"
    local uyagin_ab_result="uyagin|0|0|0"
    local c_ab_result="http_bench.c|0|0|0"
    local c_async_epoll_ab_result="http_bench_async_epoll.c|0|0|0"
    local zap_ab_result="zap|0|0|0"
    local nginx_ab_result="nginx|0|0|0"
    local tokio_ab_result="http_bench_tokio|0|0|0"

    local uya_ka_result="http_bench.uya|0|0|0"
    local uya_fork_ka_result="http_bench_fork.uya|0|0|0"
    local uya_epoll_ka_result="http_bench_async_epoll.uya|0|0|0"
    local uya_async_await_ka_result="http_bench_async_epoll_await.uya|0|0|0"
    local uya_async_await_simple_ka_result="http_bench_async_epoll_await_simple.uya|0|0|0"
    local uya_async_await_stack_ka_result="http_bench_async_epoll_await_stack.uya|0|0|0"
    local go_ka_result="http_bench.go|0|0|0"
    local go_gnet_ka_result="go-gnet|0|0|0"
    local uyagin_ka_result="uyagin|0|0|0"
    local c_ka_result="http_bench.c|0|0|0"
    local c_async_epoll_ka_result="http_bench_async_epoll.c|0|0|0"
    local zap_ka_result="zap|0|0|0"
    local nginx_ka_result="nginx|0|0|0"
    local tokio_ka_result="http_bench_tokio|0|0|0"

    if [ "$do_ab" -eq 1 ] || [ "$do_abk" -eq 1 ]; then
        echo ""
        if [ "$do_ab" -eq 1 ]; then
            log_info "AB 对比（ab -n${AB_KEEPALIVE_REQUESTS} -c${AB_KEEPALIVE_CONCURRENCY}）"
            if bench_enabled "uya"; then uya_ab_result=$(run_ab_probe_safe "http_bench.uya" "$UYA_HTTP_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "uya-fork"; then uya_fork_ab_result=$(run_ab_probe_safe "http_bench_fork.uya" "$UYA_FORK_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "uya-async-epoll"; then uya_epoll_ab_result=$(run_ab_probe_safe "http_bench_async_epoll.uya" "$UYA_ASYNC_EPOLL_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "uya-async-await"; then uya_async_await_ab_result=$(run_ab_probe_safe "http_bench_async_epoll_await.uya" "$UYA_ASYNC_AWAIT_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "uya-async-await-simple"; then uya_async_await_simple_ab_result=$(run_ab_probe_safe "http_bench_async_epoll_await_simple.uya" "$UYA_ASYNC_AWAIT_SIMPLE_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "uya-async-await-stack"; then uya_async_await_stack_ab_result=$(run_ab_probe_safe "http_bench_async_epoll_await_stack.uya" "$UYA_ASYNC_AWAIT_STACK_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "go" && [ "$have_go" -eq 1 ]; then go_ab_result=$(run_ab_probe_safe "http_bench.go" "$GO_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "go-gnet" && [ "$have_go_gnet" -eq 1 ]; then go_gnet_ab_result=$(run_ab_probe_safe "go-gnet" "$GO_GNET_EXEC" "$PORT" "$URL" --port "$PORT" --multicore=true); fi
            if bench_enabled "uyagin" && [ "$have_uyagin" -eq 1 ]; then uyagin_ab_result=$(run_ab_probe_safe "uyagin" "$UYA_GIN_EXEC" "$PORT" "$URL" --port "$PORT" --threads "$SERVER_THREADS"); fi
            if bench_enabled "c"; then c_ab_result=$(run_ab_probe_safe "http_bench.c" "$C_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "c-async-epoll"; then c_async_epoll_ab_result=$(run_ab_probe_safe "http_bench_async_epoll.c" "$C_ASYNC_EPOLL_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS"); fi
            if bench_enabled "zap" && [ "$have_zap" -eq 1 ]; then zap_ab_result=$(run_ab_probe_safe "zap" "$ZAP_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS"); fi
            if bench_enabled "nginx" && [ "$have_nginx" -eq 1 ]; then nginx_ab_result=$(run_ab_probe_safe "nginx" "$NGINX_EXEC" "$PORT" "$URL" -p "$NGINX_BENCH_DIR" -c nginx.conf -g "daemon off;"); fi
            if bench_enabled "tokio" && [ "$have_tokio" -eq 1 ]; then tokio_ab_result=$(run_ab_probe_safe "http_bench_tokio" "$TOKIO_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS"); fi
        fi
        if [ "$do_abk" -eq 1 ]; then
            log_info "Keep-Alive 对比（ab -k -n${AB_KEEPALIVE_REQUESTS} -c${AB_KEEPALIVE_CONCURRENCY}）"
            if bench_enabled "uya"; then uya_ka_result=$(run_keepalive_probe_safe "http_bench.uya" "$UYA_HTTP_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "uya-fork"; then uya_fork_ka_result=$(run_keepalive_probe_safe "http_bench_fork.uya" "$UYA_FORK_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "uya-async-epoll"; then uya_epoll_ka_result=$(run_keepalive_probe_safe "http_bench_async_epoll.uya" "$UYA_ASYNC_EPOLL_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "uya-async-await"; then uya_async_await_ka_result=$(run_keepalive_probe_safe "http_bench_async_epoll_await.uya" "$UYA_ASYNC_AWAIT_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "uya-async-await-simple"; then uya_async_await_simple_ka_result=$(run_keepalive_probe_safe "http_bench_async_epoll_await_simple.uya" "$UYA_ASYNC_AWAIT_SIMPLE_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "uya-async-await-stack"; then uya_async_await_stack_ka_result=$(run_keepalive_probe_safe "http_bench_async_epoll_await_stack.uya" "$UYA_ASYNC_AWAIT_STACK_EXEC" "$PORT" "$URL" --threads "$UYA_ASYNC_SERVER_THREADS"); fi
            if bench_enabled "go" && [ "$have_go" -eq 1 ]; then go_ka_result=$(run_keepalive_probe_safe "http_bench.go" "$GO_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "go-gnet" && [ "$have_go_gnet" -eq 1 ]; then go_gnet_ka_result=$(run_keepalive_probe_safe "go-gnet" "$GO_GNET_EXEC" "$PORT" "$URL" --port "$PORT" --multicore=true); fi
            if bench_enabled "uyagin" && [ "$have_uyagin" -eq 1 ]; then uyagin_ka_result=$(run_keepalive_probe_safe "uyagin" "$UYA_GIN_EXEC" "$PORT" "$URL" --port "$PORT" --threads "$SERVER_THREADS"); fi
            if bench_enabled "c"; then c_ka_result=$(run_keepalive_probe_safe "http_bench.c" "$C_EXEC" "$PORT" "$URL"); fi
            if bench_enabled "c-async-epoll"; then c_async_epoll_ka_result=$(run_keepalive_probe_safe "http_bench_async_epoll.c" "$C_ASYNC_EPOLL_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS"); fi
            if bench_enabled "nginx" && [ "$have_nginx" -eq 1 ]; then nginx_ka_result=$(run_keepalive_probe_safe "nginx" "$NGINX_EXEC" "$PORT" "$URL" -p "$NGINX_BENCH_DIR" -c nginx.conf -g "daemon off;"); fi
            if bench_enabled "tokio" && [ "$have_tokio" -eq 1 ]; then tokio_ka_result=$(run_keepalive_probe_safe "http_bench_tokio" "$TOKIO_EXEC" "$PORT" "$URL" --threads "$SERVER_THREADS"); fi
        fi
    fi

    # 解析 AB 结果
    local uya_ab_req=0 uya_ab_failed=0 uya_ab_rps=0
    local uya_fork_ab_req=0 uya_fork_ab_failed=0 uya_fork_ab_rps=0
    local uya_epoll_ab_req=0 uya_epoll_ab_failed=0 uya_epoll_ab_rps=0
    local uya_async_await_ab_req=0 uya_async_await_ab_failed=0 uya_async_await_ab_rps=0
    local uya_async_await_simple_ab_req=0 uya_async_await_simple_ab_failed=0 uya_async_await_simple_ab_rps=0
    local uya_async_await_stack_ab_req=0 uya_async_await_stack_ab_failed=0 uya_async_await_stack_ab_rps=0
    local go_ab_req=0 go_ab_failed=0 go_ab_rps=0
    local go_gnet_ab_req=0 go_gnet_ab_failed=0 go_gnet_ab_rps=0
    local uyagin_ab_req=0 uyagin_ab_failed=0 uyagin_ab_rps=0
    local c_ab_req=0 c_ab_failed=0 c_ab_rps=0
    local c_async_epoll_ab_req=0 c_async_epoll_ab_failed=0 c_async_epoll_ab_rps=0
    local zap_ab_req=0 zap_ab_failed=0 zap_ab_rps=0
    local nginx_ab_req=0 nginx_ab_failed=0 nginx_ab_rps=0
    local tokio_ab_req=0 tokio_ab_failed=0 tokio_ab_rps=0

    if [ "$do_ab" -eq 1 ]; then
        uya_ab_req=$(result_field "$uya_ab_result" 2); uya_ab_failed=$(result_field "$uya_ab_result" 3); uya_ab_rps=$(result_field "$uya_ab_result" 4)
        uya_fork_ab_req=$(result_field "$uya_fork_ab_result" 2); uya_fork_ab_failed=$(result_field "$uya_fork_ab_result" 3); uya_fork_ab_rps=$(result_field "$uya_fork_ab_result" 4)
        uya_epoll_ab_req=$(result_field "$uya_epoll_ab_result" 2); uya_epoll_ab_failed=$(result_field "$uya_epoll_ab_result" 3); uya_epoll_ab_rps=$(result_field "$uya_epoll_ab_result" 4)
        uya_async_await_ab_req=$(result_field "$uya_async_await_ab_result" 2); uya_async_await_ab_failed=$(result_field "$uya_async_await_ab_result" 3); uya_async_await_ab_rps=$(result_field "$uya_async_await_ab_result" 4)
        uya_async_await_simple_ab_req=$(result_field "$uya_async_await_simple_ab_result" 2); uya_async_await_simple_ab_failed=$(result_field "$uya_async_await_simple_ab_result" 3); uya_async_await_simple_ab_rps=$(result_field "$uya_async_await_simple_ab_result" 4)
        uya_async_await_stack_ab_req=$(result_field "$uya_async_await_stack_ab_result" 2); uya_async_await_stack_ab_failed=$(result_field "$uya_async_await_stack_ab_result" 3); uya_async_await_stack_ab_rps=$(result_field "$uya_async_await_stack_ab_result" 4)
        go_ab_req=$(result_field "$go_ab_result" 2); go_ab_failed=$(result_field "$go_ab_result" 3); go_ab_rps=$(result_field "$go_ab_result" 4)
        go_gnet_ab_req=$(result_field "$go_gnet_ab_result" 2); go_gnet_ab_failed=$(result_field "$go_gnet_ab_result" 3); go_gnet_ab_rps=$(result_field "$go_gnet_ab_result" 4)
        uyagin_ab_req=$(result_field "$uyagin_ab_result" 2); uyagin_ab_failed=$(result_field "$uyagin_ab_result" 3); uyagin_ab_rps=$(result_field "$uyagin_ab_result" 4)
        c_ab_req=$(result_field "$c_ab_result" 2); c_ab_failed=$(result_field "$c_ab_result" 3); c_ab_rps=$(result_field "$c_ab_result" 4)
        c_async_epoll_ab_req=$(result_field "$c_async_epoll_ab_result" 2); c_async_epoll_ab_failed=$(result_field "$c_async_epoll_ab_result" 3); c_async_epoll_ab_rps=$(result_field "$c_async_epoll_ab_result" 4)
        zap_ab_req=$(result_field "$zap_ab_result" 2); zap_ab_failed=$(result_field "$zap_ab_result" 3); zap_ab_rps=$(result_field "$zap_ab_result" 4)
        nginx_ab_req=$(result_field "$nginx_ab_result" 2); nginx_ab_failed=$(result_field "$nginx_ab_result" 3); nginx_ab_rps=$(result_field "$nginx_ab_result" 4)
        tokio_ab_req=$(result_field "$tokio_ab_result" 2); tokio_ab_failed=$(result_field "$tokio_ab_result" 3); tokio_ab_rps=$(result_field "$tokio_ab_result" 4)
    fi

    local uya_ka_req=0 uya_ka_failed=0 uya_ka_rps=0
    local uya_fork_ka_req=0 uya_fork_ka_failed=0 uya_fork_ka_rps=0
    local uya_epoll_ka_req=0 uya_epoll_ka_failed=0 uya_epoll_ka_rps=0
    local uya_async_await_ka_req=0 uya_async_await_ka_failed=0 uya_async_await_ka_rps=0
    local uya_async_await_simple_ka_req=0 uya_async_await_simple_ka_failed=0 uya_async_await_simple_ka_rps=0
    local uya_async_await_stack_ka_req=0 uya_async_await_stack_ka_failed=0 uya_async_await_stack_ka_rps=0
    local go_ka_req=0 go_ka_failed=0 go_ka_rps=0
    local go_gnet_ka_req=0 go_gnet_ka_failed=0 go_gnet_ka_rps=0
    local uyagin_ka_req=0 uyagin_ka_failed=0 uyagin_ka_rps=0
    local c_ka_req=0 c_ka_failed=0 c_ka_rps=0
    local c_async_epoll_ka_req=0 c_async_epoll_ka_failed=0 c_async_epoll_ka_rps=0
    local zap_ka_req=0 zap_ka_failed=0 zap_ka_rps=0
    local nginx_ka_req=0 nginx_ka_failed=0 nginx_ka_rps=0
    local tokio_ka_req=0 tokio_ka_failed=0 tokio_ka_rps=0

    if [ "$do_abk" -eq 1 ]; then
        uya_ka_req=$(result_field "$uya_ka_result" 2); uya_ka_failed=$(result_field "$uya_ka_result" 3); uya_ka_rps=$(result_field "$uya_ka_result" 4)
        uya_fork_ka_req=$(result_field "$uya_fork_ka_result" 2); uya_fork_ka_failed=$(result_field "$uya_fork_ka_result" 3); uya_fork_ka_rps=$(result_field "$uya_fork_ka_result" 4)
        uya_epoll_ka_req=$(result_field "$uya_epoll_ka_result" 2); uya_epoll_ka_failed=$(result_field "$uya_epoll_ka_result" 3); uya_epoll_ka_rps=$(result_field "$uya_epoll_ka_result" 4)
        uya_async_await_ka_req=$(result_field "$uya_async_await_ka_result" 2); uya_async_await_ka_failed=$(result_field "$uya_async_await_ka_result" 3); uya_async_await_ka_rps=$(result_field "$uya_async_await_ka_result" 4)
        uya_async_await_simple_ka_req=$(result_field "$uya_async_await_simple_ka_result" 2); uya_async_await_simple_ka_failed=$(result_field "$uya_async_await_simple_ka_result" 3); uya_async_await_simple_ka_rps=$(result_field "$uya_async_await_simple_ka_result" 4)
        uya_async_await_stack_ka_req=$(result_field "$uya_async_await_stack_ka_result" 2); uya_async_await_stack_ka_failed=$(result_field "$uya_async_await_stack_ka_result" 3); uya_async_await_stack_ka_rps=$(result_field "$uya_async_await_stack_ka_result" 4)
        go_ka_req=$(result_field "$go_ka_result" 2); go_ka_failed=$(result_field "$go_ka_result" 3); go_ka_rps=$(result_field "$go_ka_result" 4)
        go_gnet_ka_req=$(result_field "$go_gnet_ka_result" 2); go_gnet_ka_failed=$(result_field "$go_gnet_ka_result" 3); go_gnet_ka_rps=$(result_field "$go_gnet_ka_result" 4)
        uyagin_ka_req=$(result_field "$uyagin_ka_result" 2); uyagin_ka_failed=$(result_field "$uyagin_ka_result" 3); uyagin_ka_rps=$(result_field "$uyagin_ka_result" 4)
        c_ka_req=$(result_field "$c_ka_result" 2); c_ka_failed=$(result_field "$c_ka_result" 3); c_ka_rps=$(result_field "$c_ka_result" 4)
        c_async_epoll_ka_req=$(result_field "$c_async_epoll_ka_result" 2); c_async_epoll_ka_failed=$(result_field "$c_async_epoll_ka_result" 3); c_async_epoll_ka_rps=$(result_field "$c_async_epoll_ka_result" 4)
        zap_ka_req=$(result_field "$zap_ka_result" 2); zap_ka_failed=$(result_field "$zap_ka_result" 3); zap_ka_rps=$(result_field "$zap_ka_result" 4)
        nginx_ka_req=$(result_field "$nginx_ka_result" 2); nginx_ka_failed=$(result_field "$nginx_ka_result" 3); nginx_ka_rps=$(result_field "$nginx_ka_result" 4)
        tokio_ka_req=$(result_field "$tokio_ka_result" 2); tokio_ka_failed=$(result_field "$tokio_ka_result" 3); tokio_ka_rps=$(result_field "$tokio_ka_result" 4)
    fi

    # 格式化空值
    if [ -z "$uya_ab_req" ]; then uya_ab_req=0; fi
    if [ -z "$uya_fork_ab_req" ]; then uya_fork_ab_req=0; fi
    if [ -z "$uya_epoll_ab_req" ]; then uya_epoll_ab_req=0; fi
    if [ -z "$uya_async_await_ab_req" ]; then uya_async_await_ab_req=0; fi
    if [ -z "$uya_async_await_simple_ab_req" ]; then uya_async_await_simple_ab_req=0; fi
    if [ -z "$uya_async_await_stack_ab_req" ]; then uya_async_await_stack_ab_req=0; fi
    if [ -z "$go_ab_req" ]; then go_ab_req=0; fi
    if [ -z "$go_gnet_ab_req" ]; then go_gnet_ab_req=0; fi
    if [ -z "$uyagin_ab_req" ]; then uyagin_ab_req=0; fi
    if [ -z "$c_ab_req" ]; then c_ab_req=0; fi
    if [ -z "$c_async_epoll_ab_req" ]; then c_async_epoll_ab_req=0; fi
    if [ -z "$zap_ab_req" ]; then zap_ab_req=0; fi
    if [ -z "$nginx_ab_req" ]; then nginx_ab_req=0; fi
    if [ -z "$tokio_ab_req" ]; then tokio_ab_req=0; fi
    if [ -z "$uya_ka_req" ]; then uya_ka_req=0; fi
    if [ -z "$uya_fork_ka_req" ]; then uya_fork_ka_req=0; fi
    if [ -z "$uya_epoll_ka_req" ]; then uya_epoll_ka_req=0; fi
    if [ -z "$uya_async_await_ka_req" ]; then uya_async_await_ka_req=0; fi
    if [ -z "$uya_async_await_simple_ka_req" ]; then uya_async_await_simple_ka_req=0; fi
    if [ -z "$uya_async_await_stack_ka_req" ]; then uya_async_await_stack_ka_req=0; fi
    if [ -z "$go_ka_req" ]; then go_ka_req=0; fi
    if [ -z "$go_gnet_ka_req" ]; then go_gnet_ka_req=0; fi
    if [ -z "$uyagin_ka_req" ]; then uyagin_ka_req=0; fi
    if [ -z "$c_ka_req" ]; then c_ka_req=0; fi
    if [ -z "$c_async_epoll_ka_req" ]; then c_async_epoll_ka_req=0; fi
    if [ -z "$zap_ka_req" ]; then zap_ka_req=0; fi
    if [ -z "$nginx_ka_req" ]; then nginx_ka_req=0; fi
    if [ -z "$tokio_ka_req" ]; then tokio_ka_req=0; fi

    TABLE_NAME_WIDTH="$(
        table_name_width \
            "http_bench.uya" \
            "http_bench_fork.uya" \
            "http_bench_async_epoll.uya" \
            "http_bench_async_epoll_await.uya" \
            "http_bench_async_epoll_await_simple.uya" \
            "http_bench_async_epoll_await_stack.uya" \
            "http_bench.go" \
            "go-gnet" \
            "uyagin" \
            "http_bench.c" \
            "http_bench_async_epoll.c" \
            "zap" \
            "nginx" \
            "http_bench_tokio"
    )"
    TABLE_REMARK_WIDTH="$(
        table_remark_width \
            "http_bench.uya" \
            "http_bench_fork.uya" \
            "http_bench_async_epoll.uya" \
            "http_bench_async_epoll_await.uya" \
            "http_bench_async_epoll_await_simple.uya" \
            "http_bench_async_epoll_await_stack.uya" \
            "http_bench.go" \
            "go-gnet" \
            "uyagin" \
            "http_bench.c" \
            "http_bench_async_epoll.c" \
            "zap" \
            "nginx" \
            "http_bench_tokio"
    )"

    print_sep() {
        local name_dashes
        local remark_dashes
        local qps_dashes
        local p50_dashes
        local p95_dashes
        local p99_dashes
        local ab_req_dashes
        local ab_failed_dashes
        local ab_rps_dashes
        local ka_req_dashes
        local ka_failed_dashes
        local ka_rps_dashes

        name_dashes="$(table_dashes "$TABLE_NAME_WIDTH")"
        remark_dashes="$(table_dashes "$TABLE_REMARK_WIDTH")"
        qps_dashes="$(table_dashes "$TABLE_QPS_WIDTH")"
        p50_dashes="$(table_dashes "$TABLE_P50_WIDTH")"
        p95_dashes="$(table_dashes "$TABLE_P95_WIDTH")"
        p99_dashes="$(table_dashes "$TABLE_P99_WIDTH")"
        ab_req_dashes="$(table_dashes "$TABLE_AB_REQ_WIDTH")"
        ab_failed_dashes="$(table_dashes "$TABLE_AB_FAILED_WIDTH")"
        ab_rps_dashes="$(table_dashes "$TABLE_AB_RPS_WIDTH")"
        ka_req_dashes="$(table_dashes "$TABLE_KA_REQ_WIDTH")"
        ka_failed_dashes="$(table_dashes "$TABLE_KA_FAILED_WIDTH")"
        ka_rps_dashes="$(table_dashes "$TABLE_KA_RPS_WIDTH")"

        if [ "$do_ab" -eq 0 ] && [ "$do_abk" -eq 0 ]; then
            echo "|${name_dashes}|${remark_dashes}|${qps_dashes}|${p50_dashes}|${p95_dashes}|${p99_dashes}|"
        elif [ "$do_ab" -eq 1 ] && [ "$do_abk" -eq 0 ]; then
            echo "|${name_dashes}|${remark_dashes}|${qps_dashes}|${p50_dashes}|${p95_dashes}|${p99_dashes}|${ab_req_dashes}|${ab_failed_dashes}|${ab_rps_dashes}|"
        elif [ "$do_ab" -eq 0 ] && [ "$do_abk" -eq 1 ]; then
            echo "|${name_dashes}|${remark_dashes}|${qps_dashes}|${p50_dashes}|${p95_dashes}|${p99_dashes}|${ka_req_dashes}|${ka_failed_dashes}|${ka_rps_dashes}|"
        else
            echo "|${name_dashes}|${remark_dashes}|${qps_dashes}|${p50_dashes}|${p95_dashes}|${p99_dashes}|${ab_req_dashes}|${ab_failed_dashes}|${ab_rps_dashes}|${ka_req_dashes}|${ka_failed_dashes}|${ka_rps_dashes}|"
        fi
    }

    print_row() {
        local name="$1"
        local qps="$2"
        local p50="$3"
        local p95="$4"
        local p99="$5"
        local ab_req="$6"
        local ab_failed="$7"
        local ab_rps="$8"
        local ka_req="$9"
        local ka_failed="${10}"
        local ka_rps="${11}"
        local remark

        remark="$(table_remark_for "$name")"
        if [ "$do_ab" -eq 0 ] && [ "$do_abk" -eq 0 ]; then
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "$name" "$TABLE_REMARK_WIDTH" "$remark" "$TABLE_QPS_WIDTH" "$qps" "$TABLE_P50_WIDTH" "$p50" "$TABLE_P95_WIDTH" "$p95" "$TABLE_P99_WIDTH" "$p99"
        elif [ "$do_ab" -eq 1 ] && [ "$do_abk" -eq 0 ]; then
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "$name" "$TABLE_REMARK_WIDTH" "$remark" "$TABLE_QPS_WIDTH" "$qps" "$TABLE_P50_WIDTH" "$p50" "$TABLE_P95_WIDTH" "$p95" "$TABLE_P99_WIDTH" "$p99" "$TABLE_AB_REQ_WIDTH" "$ab_req" "$TABLE_AB_FAILED_WIDTH" "$ab_failed" "$TABLE_AB_RPS_WIDTH" "$ab_rps"
        elif [ "$do_ab" -eq 0 ] && [ "$do_abk" -eq 1 ]; then
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "$name" "$TABLE_REMARK_WIDTH" "$remark" "$TABLE_QPS_WIDTH" "$qps" "$TABLE_P50_WIDTH" "$p50" "$TABLE_P95_WIDTH" "$p95" "$TABLE_P99_WIDTH" "$p99" "$TABLE_KA_REQ_WIDTH" "$ka_req" "$TABLE_KA_FAILED_WIDTH" "$ka_failed" "$TABLE_KA_RPS_WIDTH" "$ka_rps"
        else
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "$name" "$TABLE_REMARK_WIDTH" "$remark" "$TABLE_QPS_WIDTH" "$qps" "$TABLE_P50_WIDTH" "$p50" "$TABLE_P95_WIDTH" "$p95" "$TABLE_P99_WIDTH" "$p99" "$TABLE_AB_REQ_WIDTH" "$ab_req" "$TABLE_AB_FAILED_WIDTH" "$ab_failed" "$TABLE_AB_RPS_WIDTH" "$ab_rps" "$TABLE_KA_REQ_WIDTH" "$ka_req" "$TABLE_KA_FAILED_WIDTH" "$ka_failed" "$TABLE_KA_RPS_WIDTH" "$ka_rps"
        fi
    }

    print_header() {
        if [ "$do_ab" -eq 0 ] && [ "$do_abk" -eq 0 ]; then
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "Benchmark" "$TABLE_REMARK_WIDTH" "备注" "$TABLE_QPS_WIDTH" "QPS(wrk)" "$TABLE_P50_WIDTH" "P50(us)" "$TABLE_P95_WIDTH" "P95(us)" "$TABLE_P99_WIDTH" "P99(us)"
        elif [ "$do_ab" -eq 1 ] && [ "$do_abk" -eq 0 ]; then
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "Benchmark" "$TABLE_REMARK_WIDTH" "备注" "$TABLE_QPS_WIDTH" "QPS(wrk)" "$TABLE_P50_WIDTH" "P50(us)" "$TABLE_P95_WIDTH" "P95(us)" "$TABLE_P99_WIDTH" "P99(us)" "$TABLE_AB_REQ_WIDTH" "AB-Req(ab)" "$TABLE_AB_FAILED_WIDTH" "AB-Failed" "$TABLE_AB_RPS_WIDTH" "AB-RPS"
        elif [ "$do_ab" -eq 0 ] && [ "$do_abk" -eq 1 ]; then
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "Benchmark" "$TABLE_REMARK_WIDTH" "备注" "$TABLE_QPS_WIDTH" "QPS(wrk)" "$TABLE_P50_WIDTH" "P50(us)" "$TABLE_P95_WIDTH" "P95(us)" "$TABLE_P99_WIDTH" "P99(us)" "$TABLE_KA_REQ_WIDTH" "KA-Req(ab -k)" "$TABLE_KA_FAILED_WIDTH" "KA-Failed" "$TABLE_KA_RPS_WIDTH" "KA-RPS"
        else
            printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" "$TABLE_NAME_WIDTH" "Benchmark" "$TABLE_REMARK_WIDTH" "备注" "$TABLE_QPS_WIDTH" "QPS(wrk)" "$TABLE_P50_WIDTH" "P50(us)" "$TABLE_P95_WIDTH" "P95(us)" "$TABLE_P99_WIDTH" "P99(us)" "$TABLE_AB_REQ_WIDTH" "AB-Req(ab)" "$TABLE_AB_FAILED_WIDTH" "AB-Failed" "$TABLE_AB_RPS_WIDTH" "AB-RPS" "$TABLE_KA_REQ_WIDTH" "KA-Req(ab -k)" "$TABLE_KA_FAILED_WIDTH" "KA-Failed" "$TABLE_KA_RPS_WIDTH" "KA-RPS"
        fi
    }

    summary_rows=""

    append_summary_row() {
        local name="$1"
        local qps="$2"
        local p50="$3"
        local p95="$4"
        local p99="$5"
        local ab_req="$6"
        local ab_failed="$7"
        local ab_rps="$8"
        local ka_req="$9"
        local ka_failed="${10}"
        local ka_rps="${11}"

        summary_rows+="${name}|${qps}|${p50}|${p95}|${p99}|${ab_req}|${ab_failed}|${ab_rps}|${ka_req}|${ka_failed}|${ka_rps}"$'\n'
    }

    sorted_summary_rows() {
        local sort_metric="$1"
        case "$sort_metric" in
            qps)
                printf '%s' "$summary_rows" | sort -t '|' -k2,2nr -k1,1
                ;;
            p50)
                printf '%s' "$summary_rows" | sort -t '|' -k3,3n -k1,1
                ;;
            p95)
                printf '%s' "$summary_rows" | sort -t '|' -k4,4n -k1,1
                ;;
            p99)
                printf '%s' "$summary_rows" | sort -t '|' -k5,5n -k1,1
                ;;
            *)
                printf '%s' "$summary_rows"
                ;;
        esac
    }

    print_result_table() {
        local title="$1"
        local sort_metric="$2"

        log_info "$title"
        echo "=========================================="
        print_header
        print_sep
        while IFS='|' read -r name qps p50 p95 p99 ab_req ab_failed ab_rps ka_req ka_failed ka_rps; do
            if [ -z "$name" ]; then
                continue
            fi
            print_row "$name" "$qps" "$p50" "$p95" "$p99" "$ab_req" "$ab_failed" "$ab_rps" "$ka_req" "$ka_failed" "$ka_rps"
        done < <(sorted_summary_rows "$sort_metric")
        print_sep
        echo "=========================================="
    }

    if bench_enabled "uya"; then append_summary_row "http_bench.uya" "$uya_rps" "$(result_field "$uya_http_result" 5)" "$(result_field "$uya_http_result" 6)" "$(result_field "$uya_http_result" 7)" "$uya_ab_req" "$uya_ab_failed" "$uya_ab_rps" "$uya_ka_req" "$uya_ka_failed" "$uya_ka_rps"; fi
    if bench_enabled "uya-fork"; then append_summary_row "http_bench_fork.uya" "$uya_fork_rps" "$(result_field "$uya_fork_result" 5)" "$(result_field "$uya_fork_result" 6)" "$(result_field "$uya_fork_result" 7)" "$uya_fork_ab_req" "$uya_fork_ab_failed" "$uya_fork_ab_rps" "$uya_fork_ka_req" "$uya_fork_ka_failed" "$uya_fork_ka_rps"; fi
    if bench_enabled "uya-async-epoll"; then append_summary_row "http_bench_async_epoll.uya" "$uya_epoll_rps" "$(result_field "$uya_epoll_result" 5)" "$(result_field "$uya_epoll_result" 6)" "$(result_field "$uya_epoll_result" 7)" "$uya_epoll_ab_req" "$uya_epoll_ab_failed" "$uya_epoll_ab_rps" "$uya_epoll_ka_req" "$uya_epoll_ka_failed" "$uya_epoll_ka_rps"; fi
    if bench_enabled "uya-async-await"; then append_summary_row "http_bench_async_epoll_await.uya" "$uya_async_await_rps" "$(result_field "$uya_async_await_result" 5)" "$(result_field "$uya_async_await_result" 6)" "$(result_field "$uya_async_await_result" 7)" "$uya_async_await_ab_req" "$uya_async_await_ab_failed" "$uya_async_await_ab_rps" "$uya_async_await_ka_req" "$uya_async_await_ka_failed" "$uya_async_await_ka_rps"; fi
    if bench_enabled "uya-async-await-simple"; then append_summary_row "http_bench_async_epoll_await_simple.uya" "$uya_async_await_simple_rps" "$(result_field "$uya_async_await_simple_result" 5)" "$(result_field "$uya_async_await_simple_result" 6)" "$(result_field "$uya_async_await_simple_result" 7)" "$uya_async_await_simple_ab_req" "$uya_async_await_simple_ab_failed" "$uya_async_await_simple_ab_rps" "$uya_async_await_simple_ka_req" "$uya_async_await_simple_ka_failed" "$uya_async_await_simple_ka_rps"; fi
    if bench_enabled "uya-async-await-stack"; then append_summary_row "http_bench_async_epoll_await_stack.uya" "$uya_async_await_stack_rps" "$(result_field "$uya_async_await_stack_result" 5)" "$(result_field "$uya_async_await_stack_result" 6)" "$(result_field "$uya_async_await_stack_result" 7)" "$uya_async_await_stack_ab_req" "$uya_async_await_stack_ab_failed" "$uya_async_await_stack_ab_rps" "$uya_async_await_stack_ka_req" "$uya_async_await_stack_ka_failed" "$uya_async_await_stack_ka_rps"; fi
    if bench_enabled "go"; then append_summary_row "http_bench.go" "$go_rps" "$(result_field "$go_result" 5)" "$(result_field "$go_result" 6)" "$(result_field "$go_result" 7)" "$go_ab_req" "$go_ab_failed" "$go_ab_rps" "$go_ka_req" "$go_ka_failed" "$go_ka_rps"; fi
    if bench_enabled "go-gnet"; then append_summary_row "go-gnet" "$go_gnet_rps" "$(result_field "$go_gnet_result" 5)" "$(result_field "$go_gnet_result" 6)" "$(result_field "$go_gnet_result" 7)" "$go_gnet_ab_req" "$go_gnet_ab_failed" "$go_gnet_ab_rps" "$go_gnet_ka_req" "$go_gnet_ka_failed" "$go_gnet_ka_rps"; fi
    if bench_enabled "uyagin"; then append_summary_row "uyagin" "$uyagin_rps" "$(result_field "$uyagin_result" 5)" "$(result_field "$uyagin_result" 6)" "$(result_field "$uyagin_result" 7)" "$uyagin_ab_req" "$uyagin_ab_failed" "$uyagin_ab_rps" "$uyagin_ka_req" "$uyagin_ka_failed" "$uyagin_ka_rps"; fi
    if bench_enabled "c"; then append_summary_row "http_bench.c" "$c_rps" "$(result_field "$c_result" 5)" "$(result_field "$c_result" 6)" "$(result_field "$c_result" 7)" "$c_ab_req" "$c_ab_failed" "$c_ab_rps" "$c_ka_req" "$c_ka_failed" "$c_ka_rps"; fi
    if bench_enabled "c-async-epoll"; then append_summary_row "http_bench_async_epoll.c" "$c_async_epoll_rps" "$(result_field "$c_async_epoll_result" 5)" "$(result_field "$c_async_epoll_result" 6)" "$(result_field "$c_async_epoll_result" 7)" "$c_async_epoll_ab_req" "$c_async_epoll_ab_failed" "$c_async_epoll_ab_rps" "$c_async_epoll_ka_req" "$c_async_epoll_ka_failed" "$c_async_epoll_ka_rps"; fi
    if bench_enabled "zap"; then append_summary_row "zap" "$zap_rps" "$(result_field "$zap_result" 5)" "$(result_field "$zap_result" 6)" "$(result_field "$zap_result" 7)" "$zap_ab_req" "$zap_ab_failed" "$zap_ab_rps" "$zap_ka_req" "$zap_ka_failed" "$zap_ka_rps"; fi
    if bench_enabled "nginx"; then append_summary_row "nginx" "$nginx_rps" "$(result_field "$nginx_result" 5)" "$(result_field "$nginx_result" 6)" "$(result_field "$nginx_result" 7)" "$nginx_ab_req" "$nginx_ab_failed" "$nginx_ab_rps" "$nginx_ka_req" "$nginx_ka_failed" "$nginx_ka_rps"; fi
    if bench_enabled "tokio"; then append_summary_row "http_bench_tokio" "$tokio_rps_val" "$(result_field "$tokio_result" 5)" "$(result_field "$tokio_result" 6)" "$(result_field "$tokio_result" 7)" "$tokio_ab_req" "$tokio_ab_failed" "$tokio_ab_rps" "$tokio_ka_req" "$tokio_ka_failed" "$tokio_ka_rps"; fi

    print_result_table "统一对比结果（按 QPS 排序）" qps
    print_result_table "统一对比结果（按 P50 排序，越低越好）" p50
    print_result_table "统一对比结果（按 P95 排序，越低越好）" p95
    print_result_table "统一对比结果（按 P99 排序，越低越好）" p99

    # 保存基线（如果指定）
    if [ "$do_baseline" -eq 1 ]; then
        save_baseline "$uya_rps" "$uya_fork_rps" "$uya_epoll_rps" "$uya_async_await_rps" "$uya_async_await_simple_rps" "$uya_async_await_stack_rps" "$go_rps" "$go_gnet_rps" "$uyagin_rps" "$c_rps" "$c_async_epoll_rps" "$zap_rps" "$nginx_rps" "${tokio_rps_val:-0}"
    fi

    # 清理
    rm -f "$GO_EXEC" "$GO_GNET_EXEC" "$UYA_GIN_EXEC" "$C_EXEC" "$C_ASYNC_EPOLL_EXEC" "$UYA_HTTP_EXEC" "$UYA_FORK_EXEC" "$UYA_ASYNC_EPOLL_EXEC" "$UYA_ASYNC_AWAIT_EXEC" "$UYA_ASYNC_AWAIT_SIMPLE_EXEC" "$UYA_ASYNC_AWAIT_STACK_EXEC" "$ZAP_EXEC" "$TOKIO_EXEC"
    rm -rf "$NGINX_BENCH_DIR"

    log_info "基准测试完成"
}

main "$@"
