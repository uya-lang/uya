#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UYA_BIN="${UYA_BIN:-$ROOT_DIR/bin/uya}"
UYA_UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
CURL_BIN="${CURL_BIN:-curl}"
KEEP_TMP="${EXAMPLES_CHECK_KEEP_TMP:-0}"
SKIP_NET="${EXAMPLES_CHECK_SKIP_NET:-0}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uya-examples-check.XXXXXX")"

declare -A EXPECTED_EXIT_CODES=(
    ["examples/add.uya"]=3
)

declare -A HOST_RUN_SKIP=(
    ["examples/http_server.uya"]=1
    ["examples/https_get_example.uya"]=1
    ["examples/https_server_once.uya"]=1
    ["examples/https_websocket_echo.uya"]=1
    ["examples/uyagin_websocket_chat_session.uya"]=1
    ["examples/uyagin_websocket_echo.uya"]=1
    ["examples/uyagin_websocket_json_echo.uya"]=1
    ["examples/microapp/microcontainer_alloc_yield_source.uya"]=1
    ["examples/microapp/microcontainer_bss_source.uya"]=1
    ["examples/microapp/microcontainer_hello_build.uya"]=1
    ["examples/microapp/microcontainer_hello_load.uya"]=1
    ["examples/microapp/microcontainer_hello_source.uya"]=1
    ["examples/microapp/microcontainer_reloc_data_source.uya"]=1
    ["examples/microapp/microcontainer_reloc_source.uya"]=1
    ["examples/microapp/microcontainer_time_source.uya"]=1
    ["examples/package_example/flat/main.uya"]=1
    ["examples/package_example/path_dep/app/src/main.uya"]=1
    ["examples/package_example/src_layout/src/main.uya"]=1
)

log() {
    printf '[examples-check] %s\n' "$*"
}

fail() {
    printf '[examples-check] FAIL: %s\n' "$*" >&2
    exit 1
}

require_cmd() {
    local cmd="$1"
    if [[ "$cmd" == */* ]]; then
        [[ -x "$cmd" ]] || fail "缺少可执行文件: $cmd"
        return
    fi
    command -v "$cmd" >/dev/null 2>&1 || fail "缺少命令: $cmd"
}

cleanup() {
    local status=$?
    if [[ $status -ne 0 || "$KEEP_TMP" == "1" ]]; then
        log "保留临时目录: $TMP_DIR"
    else
        rm -rf "$TMP_DIR"
    fi
    exit $status
}
trap cleanup EXIT

sanitize_label() {
    local rel="$1"
    local label="${rel//\//__}"
    printf '%s' "${label%.uya}"
}

run_with_timeout() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "${seconds}s" "$@"
    else
        "$@"
    fi
}

build_host_example() {
    local rel="$1"
    local label
    label="$(sanitize_label "$rel")"
    local out="$TMP_DIR/bin/$label"
    local log_file="$TMP_DIR/logs/$label.build.log"
    UYA_ROOT="$ROOT_DIR/lib" "$UYA_BIN" build "$ROOT_DIR/$rel" -o "$out" --no-split-c >"$log_file" 2>&1 || {
        cat "$log_file" >&2
        fail "构建失败: $rel"
    }
    printf '%s' "$out"
}

run_binary_expect_rc() {
    local out="$1"
    local expected_rc="$2"
    local run_log="$3"
    local cwd="${4:-$ROOT_DIR}"
    local rc=0
    (
        cd "$cwd"
        run_with_timeout 5 "$out" >"$run_log" 2>&1
    ) || rc=$?
    if [[ $rc -ne $expected_rc ]]; then
        [[ -s "$run_log" ]] && cat "$run_log" >&2
        fail "运行退出码不匹配: 期望 $expected_rc, 实际 $rc, 日志: $run_log"
    fi
}

wait_for_process_exit() {
    local pid="$1"
    local label="$2"
    local run_log="$3"
    local tries=0
    while kill -0 "$pid" >/dev/null 2>&1; do
        if [[ $tries -ge 50 ]]; then
            kill "$pid" >/dev/null 2>&1 || true
            wait "$pid" >/dev/null 2>&1 || true
            [[ -s "$run_log" ]] && cat "$run_log" >&2
            fail "服务示例未按预期退出: $label"
        fi
        sleep 0.1
        tries=$((tries + 1))
    done
    local rc=0
    wait "$pid" || rc=$?
    if [[ $rc -ne 0 ]]; then
        [[ -s "$run_log" ]] && cat "$run_log" >&2
        fail "服务示例退出失败($rc): $label"
    fi
}

verify_http_server_example() {
    local rel="examples/http_server.uya"
    local out
    out="$(build_host_example "$rel")"
    local run_log="$TMP_DIR/logs/$(sanitize_label "$rel").service.log"
    (
        cd "$ROOT_DIR"
        "$out" >"$run_log" 2>&1
    ) &
    local pid=$!
    local body=""
    local ok=0
    for _ in $(seq 1 25); do
        if body="$("$CURL_BIN" -sS --max-time 2 http://127.0.0.1:8765/ 2>/dev/null)"; then
            ok=1
            break
        fi
        if ! kill -0 "$pid" >/dev/null 2>&1; then
            break
        fi
        sleep 0.2
    done
    if [[ $ok -ne 1 || "$body" != "hello" ]]; then
        kill "$pid" >/dev/null 2>&1 || true
        wait "$pid" >/dev/null 2>&1 || true
        [[ -s "$run_log" ]] && cat "$run_log" >&2
        fail "HTTP 示例未返回预期正文"
    fi
    wait_for_process_exit "$pid" "$rel" "$run_log"
    log "HTTP 示例通过: $rel"
}

verify_https_server_once_example() {
    local rel="examples/https_server_once.uya"
    local out
    out="$(build_host_example "$rel")"
    local run_log="$TMP_DIR/logs/$(sanitize_label "$rel").service.log"
    (
        cd "$ROOT_DIR"
        "$out" >"$run_log" 2>&1
    ) &
    local pid=$!
    local body=""
    local ok=0
    for _ in $(seq 1 25); do
        if body="$("$CURL_BIN" -ksS --max-time 2 https://127.0.0.1:8443/ 2>/dev/null)"; then
            ok=1
            break
        fi
        if ! kill -0 "$pid" >/dev/null 2>&1; then
            break
        fi
        sleep 0.2
    done
    if [[ $ok -ne 1 || "$body" != "hello https demo" ]]; then
        kill "$pid" >/dev/null 2>&1 || true
        wait "$pid" >/dev/null 2>&1 || true
        [[ -s "$run_log" ]] && cat "$run_log" >&2
        fail "HTTPS server 示例未返回预期正文"
    fi
    wait_for_process_exit "$pid" "$rel" "$run_log"
    log "HTTPS server 示例通过: $rel"
}

verify_ws_example() {
    local rel="$1"
    local port="$2"
    local path="$3"
    local payload="$4"
    local expected="$5"
    local tls_flag="$6"
    local out
    out="$(build_host_example "$rel")"
    local run_log="$TMP_DIR/logs/$(sanitize_label "$rel").service.log"
    (
        cd "$ROOT_DIR"
        "$out" >"$run_log" 2>&1
    ) &
    local pid=$!
    UYA_EXAMPLES_WS_PORT="$port" \
    UYA_EXAMPLES_WS_PATH="$path" \
    UYA_EXAMPLES_WS_PAYLOAD="$payload" \
    UYA_EXAMPLES_WS_EXPECT="$expected" \
    UYA_EXAMPLES_WS_TLS="$tls_flag" \
    "$PYTHON_BIN" - <<'PY'
import base64
import os
import socket
import ssl
import struct
import sys
import time

port = int(os.environ["UYA_EXAMPLES_WS_PORT"])
path = os.environ["UYA_EXAMPLES_WS_PATH"]
payload = os.environ["UYA_EXAMPLES_WS_PAYLOAD"].encode()
expected = os.environ["UYA_EXAMPLES_WS_EXPECT"]
use_tls = os.environ["UYA_EXAMPLES_WS_TLS"] == "1"

deadline = time.time() + 5
last_error = None
sock = None
while time.time() < deadline:
    try:
        raw = socket.create_connection(("127.0.0.1", port), timeout=1)
        if use_tls:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            sock = ctx.wrap_socket(raw, server_hostname="localhost")
        else:
            sock = raw
        break
    except Exception as exc:  # noqa: BLE001
        last_error = exc
        time.sleep(0.2)

if sock is None:
    raise RuntimeError(f"connect failed: {last_error!r}")

key = base64.b64encode(os.urandom(16)).decode()
request = (
    f"GET {path} HTTP/1.1\r\n"
    f"Host: localhost:{port}\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    "Sec-WebSocket-Version: 13\r\n\r\n"
).encode()
sock.sendall(request)
response = b""
while b"\r\n\r\n" not in response:
    chunk = sock.recv(4096)
    if not chunk:
        raise RuntimeError("websocket handshake closed early")
    response += chunk
status_line = response.split(b"\r\n", 1)[0]
if b"101" not in status_line:
    raise RuntimeError(f"unexpected handshake: {status_line!r}")

mask = os.urandom(4)
masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
sock.sendall(bytes([0x81, 0x80 | len(payload)]) + mask + masked)

header = sock.recv(2)
if len(header) != 2:
    raise RuntimeError(f"short websocket frame header: {header!r}")
_, length_byte = header
length = length_byte & 0x7F
if length == 126:
    length = struct.unpack("!H", sock.recv(2))[0]
elif length == 127:
    length = struct.unpack("!Q", sock.recv(8))[0]
if length_byte & 0x80:
    mask2 = sock.recv(4)
else:
    mask2 = None
data = b""
while len(data) < length:
    data += sock.recv(length - len(data))
if mask2 is not None:
    data = bytes(b ^ mask2[i % 4] for i, b in enumerate(data))
reply = data.decode()
sock.close()

if reply != expected:
    raise RuntimeError(f"unexpected websocket reply: {reply!r}")
PY
    local client_rc=$?
    if [[ $client_rc -ne 0 ]]; then
        kill "$pid" >/dev/null 2>&1 || true
        wait "$pid" >/dev/null 2>&1 || true
        [[ -s "$run_log" ]] && cat "$run_log" >&2
        fail "WebSocket 示例交互失败: $rel"
    fi
    wait_for_process_exit "$pid" "$rel" "$run_log"
    log "WebSocket 示例通过: $rel"
}

verify_https_get_example() {
    if [[ "$SKIP_NET" == "1" ]]; then
        log "跳过外网 HTTPS GET 示例（EXAMPLES_CHECK_SKIP_NET=1）"
        return
    fi
    local rel="examples/https_get_example.uya"
    local out
    out="$(build_host_example "$rel")"
    local run_log="$TMP_DIR/logs/$(sanitize_label "$rel").run.log"
    run_binary_expect_rc "$out" 0 "$run_log" "$ROOT_DIR"
    log "HTTPS GET 示例通过: $rel"
}

verify_host_examples() {
    log "验证普通 examples 可执行程序"
    mapfile -t main_files < <(cd "$ROOT_DIR" && rg -l '(^|[[:space:]])(export )?fn main\(' examples --glob '*.uya' | sort)
    local rel
    for rel in "${main_files[@]}"; do
        if [[ -n "${HOST_RUN_SKIP[$rel]+x}" ]]; then
            continue
        fi
        local out
        out="$(build_host_example "$rel")"
        local label
        label="$(sanitize_label "$rel")"
        local run_log="$TMP_DIR/logs/$label.run.log"
        local expected_rc="${EXPECTED_EXIT_CODES[$rel]:-0}"
        run_binary_expect_rc "$out" "$expected_rc" "$run_log" "$ROOT_DIR"
        log "通过: $rel (rc=$expected_rc)"
    done
}

verify_microapp_source_builds() {
    log "验证 microapp source 示例可打包"
    local rel
    for rel in "$ROOT_DIR"/examples/microapp/*_source.uya; do
        local name
        name="$(basename "$rel" .uya)"
        local out="$TMP_DIR/bin/${name}.uapp"
        local log_file="$TMP_DIR/logs/${name}.microapp.log"
        UYA_ROOT="$ROOT_DIR/lib" "$UYA_BIN" build --app microapp "$rel" -o "$out" >"$log_file" 2>&1 || {
            cat "$log_file" >&2
            fail "microapp source 打包失败: $(basename "$rel")"
        }
        log "microapp 打包通过: $(basename "$rel")"
    done
}

verify_microapp_build_and_load_examples() {
    log "验证 microapp build/load 示例（隔离目录）"
    local case_root="$TMP_DIR/cases"
    mkdir -p "$case_root/examples"
    cp -R "$ROOT_DIR/examples/microapp" "$case_root/examples/"

    local build_rel="examples/microapp/microcontainer_hello_build.uya"
    local load_rel="examples/microapp/microcontainer_hello_load.uya"
    local build_bin
    build_bin="$(build_host_example "$build_rel")"
    local load_bin
    load_bin="$(build_host_example "$load_rel")"
    run_binary_expect_rc "$build_bin" 0 "$TMP_DIR/logs/microcontainer_hello_build.run.log" "$case_root"
    run_binary_expect_rc "$load_bin" 0 "$TMP_DIR/logs/microcontainer_hello_load.run.log" "$case_root"
    [[ -f "$case_root/examples/microapp/microcontainer_hello.uapp" ]] || fail "microcontainer_hello.uapp 未在隔离目录生成"
}

verify_package_examples() {
    log "验证 package examples（隔离目录）"
    local case_root="$TMP_DIR/cases/package"
    mkdir -p "$case_root/examples"
    cp -R "$ROOT_DIR/examples/package_example" "$case_root/examples/"

    local pkg_root="$case_root/examples/package_example"
    local pkg
    local out
    local log_file
    local run_log
    local stdout_text

    pkg="$pkg_root/flat"
    out="$TMP_DIR/bin/package_example_flat"
    log_file="$TMP_DIR/logs/package_example_flat.build.log"
    UYA_ROOT="$ROOT_DIR/lib" "$UYA_UPM_BIN" build "$pkg" -o "$out" --no-split-c >"$log_file" 2>&1 || {
        cat "$log_file" >&2
        fail "package example 构建失败: flat"
    }
    run_log="$TMP_DIR/logs/package_example_flat.run.log"
    run_binary_expect_rc "$out" 0 "$run_log" "$ROOT_DIR"
    stdout_text="$(tr -d '\r' <"$run_log")"
    [[ "$stdout_text" == "example-flat" ]] || fail "flat package 输出不符"

    pkg="$pkg_root/src_layout"
    out="$TMP_DIR/bin/package_example_src_layout"
    log_file="$TMP_DIR/logs/package_example_src_layout.build.log"
    UYA_ROOT="$ROOT_DIR/lib" "$UYA_UPM_BIN" build "$pkg" -o "$out" --no-split-c >"$log_file" 2>&1 || {
        cat "$log_file" >&2
        fail "package example 构建失败: src_layout"
    }
    run_log="$TMP_DIR/logs/package_example_src_layout.run.log"
    run_binary_expect_rc "$out" 0 "$run_log" "$ROOT_DIR"
    stdout_text="$(tr -d '\r' <"$run_log")"
    [[ "$stdout_text" == "example-src" ]] || fail "src_layout package 输出不符"

    pkg="$pkg_root/path_dep/app"
    out="$TMP_DIR/bin/package_example_path_dep"
    log_file="$TMP_DIR/logs/package_example_path_dep.build.log"
    UYA_ROOT="$ROOT_DIR/lib" "$UYA_UPM_BIN" build "$pkg" -o "$out" --no-split-c >"$log_file" 2>&1 || {
        cat "$log_file" >&2
        fail "package example 构建失败: path_dep"
    }
    run_log="$TMP_DIR/logs/package_example_path_dep.run.log"
    run_binary_expect_rc "$out" 0 "$run_log" "$ROOT_DIR"
    stdout_text="$(tr -d '\r' <"$run_log")"
    [[ "$stdout_text" == "example-path-dep" ]] || fail "path_dep package 输出不符"
}

require_cmd "$UYA_BIN"
require_cmd "$UYA_UPM_BIN"
require_cmd "$PYTHON_BIN"
require_cmd "$CURL_BIN"

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/logs" "$TMP_DIR/cases"

verify_host_examples
verify_http_server_example
verify_https_get_example
verify_https_server_once_example
verify_ws_example "examples/uyagin_websocket_echo.uya" 8766 "/ws" "ping" "ping" 0
verify_ws_example "examples/uyagin_websocket_chat_session.uya" 8767 "/chat" "hi" "room[lobby] hi" 0
verify_ws_example "examples/uyagin_websocket_json_echo.uya" 8772 "/json" '{"x":1}' '{"ok":true,"kind":"json"}' 0
verify_ws_example "examples/https_websocket_echo.uya" 8771 "/ws" "secure" "secure" 1
verify_microapp_source_builds
verify_microapp_build_and_load_examples
verify_package_examples

echo "examples suite ok"
