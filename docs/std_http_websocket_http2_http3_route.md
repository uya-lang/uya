# Uya WebSocket HTTP/2 / HTTP/3 路线占位

> **核对头（2026-09-27）**：路线占位文档，接口边界仍有效。实现现状：HTTP/2 frame / stream / HPACK 栈在仓库中（`lib/std/http/http2_*.uya`、`hpack.uya`）；**QUIC / HTTP/3 与 HTTP/2 WebSocket transport adapter 尚未实现**。

本文档对应 `std.http.websocket` 的 Phase 11 路线收敛。当前仓库已经补上 **HTTP/2 frame / stream / HPACK 基础栈**，本页继续负责把**模块归属、接口边界、复用策略和后续 transport 落点**固定下来，避免后续 extended CONNECT / QUIC 实现偏航。

## 1. 模块归属

- HTTP/2 WebSocket 继续归属 `std.http.*`，不拆出新的顶层 `std.websocket`。
- HTTP/3 / QUIC WebSocket 也继续归属 `std.http.*`，因为建连入口仍然是 HTTP CONNECT / WebSocket 语义，而不是裸 QUIC stream。
- 当前仓库的实现锚点包括：
  - `lib/std/http/http2_types.uya`
  - `lib/std/http/http2_frame.uya`
  - `lib/std/http/http2_stream.uya`
  - `lib/std/http/hpack.uya`
  - `lib/std/http/websocket_http2_h3_route.uya`

## 2. HTTP/2 RFC 8441

- 建连方式选择 **RFC 8441 extended CONNECT**，`:protocol = websocket`。
- HTTP/2 负责：
  - stream 生命周期；
  - extended CONNECT 请求/响应头；
  - stream 级关闭 / reset 映射。
- 现有 WebSocket 层继续负责：
  - frame 编解码；
  - message 聚合；
  - heartbeat / reconnect / backpressure。
- 对接方式：
  - 新增一个面向 HTTP/2 stream 的 transport adapter；
  - adapter 对上暴露与 `AsyncReader` / `AsyncWriter` 一致的按字节读写；
  - `WebSocketConn` / `read_frame` / `read_message` / `write_message` 继续复用，不重写 frame/message/session 逻辑。
- 当前已落地的基础层：
  - frame header / DATA / SETTINGS / WINDOW_UPDATE / HEADERS payload 解析
  - stream 生命周期与窗口记账
  - HPACK static table、literal、incremental indexing 与 dynamic table 驱逐

## 3. HTTP/3 / QUIC

- HTTP/3 WebSocket 保持在 `std.http.*` 命名空间。
- CONNECT 建连之后，真正的数据面落在 QUIC stream，而不是 TCP fd。
- 评估结论：
  - 现有 `AsyncReader` / `AsyncWriter` **不足以直接表达全部 QUIC 语义**；
  - 需要额外 adapter，把 stream 读写、reset、half-close、最终状态映射到当前 WebSocket transport 生命周期；
  - 但 frame/message/session 层仍可复用。

## 4. 最小验证

- 当前最小验证已扩展为 **protocol unit tests + route smoke**：
  - `tests/test_http_http2_frame.uya`
  - `tests/test_http_http2_stream.uya`
  - `tests/test_http_hpack.uya`
  - `tests/test_http_websocket_http2_h3_route.uya`
  - 验证 HTTP/2 基础栈可编译并通过协议层回归，同时保留路线占位默认值稳定。
- 后续真正进入实现阶段时，再补：
  - HTTP/2 loopback extended CONNECT smoke；
  - HTTP/3 / QUIC adapter compile+loopback smoke。
