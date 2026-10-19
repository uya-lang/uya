# Uya `std.http.websocket` 使用说明

`std.http.websocket` 提供 HTTP/1.1 Upgrade WebSocket、TLS/WSS transport、JSON helper、heartbeat、reconnect wrapper 与队列/pump 能力。

> **核对头（2026-10-19）**：下方能力清单已按 `lib/std/http/*.uya` 逐个核对，补上真实定义位置（本文原先只写裸名，容易被误读成自由函数）：
>
> | 文档里的名字 | 实际定义 |
> |---|---|
> | `websocket_accept_from_http(fd, req, &opts)` | `lib/std/http/websocket_handshake.uya:300`（`export fn`） |
> | `websocket_accept_from_https_server(&srv, &opts)` | `lib/std/http/websocket_tls.uya:49`（`export fn`） |
> | `read_frame` / `write_frame` | `WebSocketConn` 的接口方法（`lib/std/http/websocket_async.uya:261` / `:272`），底层实现 `websocket_conn_read_frame` / `websocket_conn_write_frame` |
> | `read_message` / `write_message` | `WebSocketConn` 方法（`:266` / `:277`）；导出实现 `websocket_conn_read_message`（`:722`）/ `websocket_conn_write_message`（`:839`），均为 `export @async_fn` |
> | `websocket_conn_heartbeat_tick(...)` | `lib/std/http/websocket_async.uya:902`（`export @async_fn`） |
> | `websocket_client_reconnect_tick(...)` / `WebSocketClientConnector` | `lib/std/http/websocket_client.uya:199` / `:65`（`export interface`） |
> | `enqueue_message` / `flush_one_pending` / `flush_pending` / `shutdown_pending` | `WebSocketConn` 方法 + 导出实现 `websocket_conn_enqueue_message`（`:944`）、`websocket_conn_flush_one_pending`（`:973`）、`websocket_conn_flush_pending`（`:1039`）、`websocket_conn_shutdown_pending`（`:1050`） |
> | `websocket_json_decode_value(...)` / `websocket_conn_write_json<T>(...)` | `lib/std/http/websocket_json.uya` |
> | `uyagin_websocket_upgrade_sync(ctx, &opts)` | `lib/std/http/uyagin_websocket.uya` |
>
> 传输层现状：HTTP/1.1 Upgrade 是本模块**唯一已实现的 WebSocket 握手路径**；RFC 8441 extended CONNECT（HTTP/2）与 HTTP/3 / QUIC **仅有路线占位结构体**（`lib/std/http/websocket_http2_h3_route.uya` 的 `WebSocketHttp2RoutePlan` / `WebSocketHttp3RoutePlan`，无任何帧/流实现），详见 [std_http_websocket_http2_http3_route.md](./std_http_websocket_http2_http3_route.md)。

## 最短路径

- 裸 HTTP:
  - `websocket_accept_from_http(fd, req, &opts)`
- UyaGin:
  - `uyagin_websocket_upgrade_sync(ctx, &opts)`
  - `@await ws.read_message(...)`
  - `@await ws.write_message(...)`
- HTTPS / WSS:
  - `websocket_accept_from_https_server(&srv, &opts)`

## 常用能力

- 协议层:
  - `read_frame(...)`
  - `write_frame(...)`
- 消息层:
  - `read_message(...)`
  - `write_message(...)`
- JSON:
  - `websocket_json_decode_value(...)`
  - `websocket_conn_write_json<T>(...)`
- 心跳:
  - `websocket_conn_heartbeat_tick(...)`
- 自动重连:
  - `websocket_client_reconnect_tick(...)`
  - `WebSocketClientConnector`
- 队列 / pump:
  - `enqueue_message(...)`
  - `flush_one_pending(...)`
  - `flush_pending(...)`
  - `shutdown_pending(...)`

## 示例

- 最小 echo:
  - [uyagin_websocket_echo.uya](../examples/uyagin_websocket_echo.uya)
- chat/session:
  - [uyagin_websocket_chat_session.uya](../examples/uyagin_websocket_chat_session.uya)
- WSS:
  - [https_websocket_echo.uya](../examples/https_websocket_echo.uya)
- JSON:
  - [uyagin_websocket_json_echo.uya](../examples/uyagin_websocket_json_echo.uya)

## 路线占位

- HTTP/2 RFC 8441 / HTTP/3 / QUIC 路线说明：
  - [std_http_websocket_http2_http3_route.md](./std_http_websocket_http2_http3_route.md)
