#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SOURCE="lib/std/http/websocket_client.uya"

if ! rg -Fq 'export @async_fn fn websocket_client_reconnect_tick(self: &WebSocketClient, connector: WebSocketClientConnector, now_ms: u64) Future<!bool>' "$SOURCE"; then
    echo "missing async reconnect_tick signature in $SOURCE" >&2
    exit 1
fi

if rg -Fq 'struct WebSocketClientReconnectFuture : Future<!bool>' "$SOURCE"; then
    echo "manual reconnect future still present in $SOURCE" >&2
    exit 1
fi

../uya/bin/uya check tests/test_http_websocket_reconnect.uya
