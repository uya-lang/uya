# Uya `std.http.websocket` 详细设计

**版本**：v0.2
**状态**：部分实现（协议层、async 会话核心、TLS / WSS、JSON、heartbeat、reconnect 与队列 pump 已落地；HTTP/2 frame/stream/HPACK 基础栈已落地；HTTP/2 extended CONNECT transport 与 HTTP/3 / QUIC 仍待实现）
**定位**：放在 `std.http` 下的 WebSocket 能力层，优先服务 `uyagin`，同时保持可脱离框架单独复用

**实现拆解**：见 [todo_http_websocket.md](./todo_http_websocket.md)
**用户文档**：见 [std_http_websocket.md](./std_http_websocket.md)
**HTTP/2 / HTTP/3 路线占位**：见 [std_http_websocket_http2_http3_route.md](./std_http_websocket_http2_http3_route.md)

**当前实现进度（截至 2026-05-30）**：

> **核对头（2026-10-19）**：本节状态逐条复核**仍然成立**，另补两处遗漏：
> - 下列文件名清单缺 `websocket_json.uya`，该模块实际存在（`export fn websocket_json_decode_value` / `websocket_conn_write_json_value` / `websocket_conn_write_json<T>`），已补入清单。
> - "仍待实现"两项保持不变，并有反向证据：`grep -rln "extended_connect\|quic_" lib/std/http/*.uya` 只命中 `websocket_http2_h3_route.uya` 占位文件；该文件只有 `WebSocketHttp2RoutePlan` / `WebSocketHttp3RoutePlan` 两个结构体与 `websocket_http2_route_plan_default()` / `websocket_http3_route_plan_default()`，`validation_scope = "compile_and_interface_smoke"`。
> - HTTP/2 基础栈导出规模（可用于判断"基础栈"到底覆盖到哪）：`http2_types.uya` 37 个导出、`http2_frame.uya` 9 个、`http2_stream.uya` 11 个、`hpack.uya` 11 个。

- 已落地：
  - `http2_types.uya`
  - `http2_frame.uya`
  - `http2_stream.uya`
  - `hpack.uya`
  - `websocket_types.uya`
  - `websocket_handshake.uya`
  - `websocket_frame.uya`
  - `websocket_async.uya`
  - `websocket_tls.uya`
  - `websocket_client.uya`
  - `websocket_json.uya`
  - `websocket_http2_h3_route.uya`
  - `uyagin_websocket.uya`
  - `std.crypto.sha1`
- 已验证：
  - HTTP/2 frame header / DATA / SETTINGS / WINDOW_UPDATE / HEADERS payload 解析
  - HTTP/2 stream 状态迁移与窗口记账
  - HPACK integer / string / static table / incremental indexing / dynamic table 驱逐
  - `Sec-WebSocket-Accept`
  - HTTP/1.1 Upgrade 请求校验
  - 裸 HTTP `websocket_accept_from_http(...)`
  - frame 编解码 / mask / continuation 基础规则
  - loopback async 会话收发、消息聚合、auto pong、close 失败语义、最小 send queue
  - `uyagin` route -> upgrade -> echo roundtrip / fallback / hijack 防呆
  - HTTPS -> WebSocket upgrade / TLS transport / WSS loopback echo
- 已补齐：
  - JSON 文本消息辅助 API
  - 外部调度驱动 heartbeat / reconnect
  - 控制帧优先、close 抢占与 flush pump
  - HTTP/2 / HTTP/3 路线占位 compile smoke
- 仍待实现：
  - HTTP/2 extended CONNECT transport 与 WebSocket session bridge
  - 真实 HTTP/3 / QUIC stream adapter

## 1. 设计目标

### 1.1 目标

- 提供一套参考 Go WebSocket 使用体验的 Uya API，但保持 Uya 风格：
  - 复用结构体承载会话状态；
  - 复用结构体 `@async_fn` 方法承载高频语义操作；
  - 通过接口抽象 transport / session 能力；
  - 优先 caller-owned buffer，避免隐式堆分配。
- 先支持 **HTTP/1.1 Upgrade -> WebSocket**，并明确归属到 `std.http`。
- 与现有 `std.http.uyagin`、`std.async`、`std.async_event`、`std.async_scheduler`、`std.http.types`、`std.http.server` 风格对齐。
- 让业务代码可以像 Go 一样围绕“连接对象”编写，而不是把所有逻辑摊平成函数。
- 这一版同时覆盖完整可用链路上的高级能力：
  - WebSocket over TLS transport 适配；
  - JSON 消息编解码辅助 API；
  - 自动重连策略；
  - 自动心跳 / ping-pong 保活策略；
  - 写队列、背压与后台发送模型。

### 1.2 非目标

- 本设计不追求首稿就覆盖浏览器扩展生态兼容层，例如 DOM / JS bridge、浏览器专属 API 适配等宿主集成问题。
- 本设计不把“任意三方实时协议网关”作为首要目标，例如 MQTT-over-WebSocket 网关、SSE/WS 混合桥等跨协议编排。
- 本设计优先完成仓库内可直接验证的 `std.http` / `uyagin` / `tls.https` / `std.async` 主链路，再考虑更外围生态封装。

## 2. 设计原则

### 2.1 参考 Go，但不直接照搬

Go 常见使用方式是：

- `Upgrader.Upgrade(...)` 建连
- `Conn.ReadMessage()` / `Conn.WriteMessage()`
- `SetReadDeadline()` / `WriteControl()` / `NextReader()` / `NextWriter()`

Uya 版本保留“围绕连接对象调用方法”的体验，但做这些调整：

- 不隐藏生命周期，连接状态明确放进 `struct WebSocketConn`。
- 不默认分配消息对象，读写缓冲由调用方或连接对象显式提供。
- 不依赖 goroutine；异步语义全部通过 `@async_fn` + `Future<!T>`。
- 不强调“writer 对象必须 close 才 flush”的 Go 习惯，优先做显式 frame/message API。

### 2.2 复用现有标准库形态

直接借鉴两个已存在模式：

- `std.mqtt.async`
  - `AsyncMqttClient` 接口 + `MqttFdClient` 结构体实现
  - caller-owned `tx` / `rx` buffer
  - 语义动作挂在结构体 `@async_fn` 方法上
- `std.http.uyagin`
  - `AsyncHandler` 接口
  - `GinContext` 作为单次请求上下文
  - 框架层与协议层分离

因此 WebSocket 也分四层：

1. HTTP Upgrade / Handshake 层
2. Frame 编解码层
3. Async session 接口层
4. 基于 fd 的默认连接实现层

在这一版范围扩展后，还需要再补三层：

5. TLS / WSS transport 适配层
6. Client policy 层（自动重连、心跳、背压）
7. JSON 辅助 API 层

## 3. 模块布局

建议新增：

```text
lib/std/http/
  websocket_types.uya
  websocket_frame.uya
  websocket_handshake.uya
  websocket_async.uya
  websocket_tls.uya
  websocket_client.uya
  websocket_json.uya
  uyagin_websocket.uya
```

建议职责：

- `websocket_types.uya`
  - 错误、常量、枚举、公共结构体、接口
- `websocket_frame.uya`
  - frame header 编解码
  - masking / payload copy / fragmentation 基础逻辑
- `websocket_handshake.uya`
  - `Sec-WebSocket-Key` 校验
  - `Sec-WebSocket-Accept` 计算
  - 与 HTTP request / response 的 Upgrade 协商
- `websocket_async.uya`
  - `AsyncWebSocketConn` 接口
  - `WebSocketFdTransport`
  - `WebSocketConn`
  - 高层 `@async_fn` 会话方法
  - 直接读写与连接自持发送缓冲
- `websocket_tls.uya`
  - WSS transport 适配
  - TLS 握手后与 WebSocket upgrade 的桥接
- `websocket_client.uya`
  - `WebSocketClient`
  - `ReconnectPolicy`
  - 心跳、重连、后台发送 pump
- `websocket_json.uya`
  - JSON 文本消息辅助读写
- `uyagin_websocket.uya`
  - `GinContext` upgrade 桥接

首期文档与实现都放在 `std.http` 命名空间下，不另起 `std.websocket`，因为：

- 握手依赖 HTTP request / header / response；
- `uyagin` 集成是第一落点；
- 后续 HTTPS 接入也更自然沿 `std.http` 扩展。

这也意味着：

- `HTTP/2 WebSocket` 与 `HTTP/3/QUIC WebSocket` 仍然归属本设计范围；
- 但模块归属仍保留在 `std.http.*`，不拆成新的顶层命名空间。

## 4. 核心类型设计

### 4.1 错误

建议新增错误：

```uya
export error WebSocketBadHandshake;
export error WebSocketUnsupportedVersion;
export error WebSocketMissingKey;
export error WebSocketInvalidKey;
export error WebSocketProtocolError;
export error WebSocketFrameTooLarge;
export error WebSocketMessageTooLarge;
export error WebSocketNeedMoreData;
export error WebSocketConnectionClosed;
export error WebSocketMaskedServerFrame;
export error WebSocketUnmaskedClientFrame;
export error WebSocketUnsupportedOpcode;
export error WebSocketUtf8Required;
export error WebSocketControlFrameTooLarge;
export error WebSocketFragmentedControlFrame;
export error WebSocketContinuationMissing;
```

这些错误不替换 `std.http.types` 现有错误，而是专用于 WebSocket 层。

### 4.2 常量与枚举

建议放在 `websocket_types.uya`：

```uya
export const WS_GUID: &const byte = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
export const WS_MAX_HEADER_BYTES: usize = 14;
export const WS_CONTROL_MAX_PAYLOAD: usize = 125;

export enum WebSocketOpcode {
    Continuation = 0,
    Text = 1,
    Binary = 2,
    Close = 8,
    Ping = 9,
    Pong = 10,
}

export enum WebSocketRole {
    Server,
    Client,
}
```

### 4.3 Frame 视图与消息视图

首期分成“frame 视图”和“message 视图”两层。

```uya
export struct WebSocketFrameView {
    fin: bool,
    opcode: WebSocketOpcode,
    masked: bool,
    payload_ptr: &byte,
    payload_len: usize,
    mask_key: [byte: 4],
}

export struct WebSocketMessageView {
    opcode: WebSocketOpcode,
    payload_ptr: &byte,
    payload_len: usize,
}
```

说明：

- `FrameView` 更贴近协议，可用于调试、测试、低层代理。
- `MessageView` 更贴近业务，可隐藏 continuation 拼接细节。
- 当前实现使用 `ptr + len`，而不是直接把 `&[byte]` 放进 view。
- 这样做不是语义退化，而是为了避开当前编译器在 “复杂 view struct 穿过多次 `@await`” 场景下的 lowering 不稳定点。
- `payload_ptr/payload_len` 的生命周期仍然绑定到调用方提供的缓冲区。

### 4.4 握手配置

建议提供可复用的配置结构体，而不是只暴露一个大函数。

```uya
export struct WebSocketHeartbeatConfig {
    ping_interval_ms: u32 = 0,
    pong_timeout_ms: u32 = 0,
    idle_timeout_ms: u32 = 0,
}

export struct WebSocketAcceptOptions {
    subprotocols: &const byte = null,
    subprotocol_count: i32 = 0,
    allow_extensions: bool = false,
    max_frame_size: usize = 65536,
    max_message_size: usize = 1048576,
    auto_pong: bool = true,
    send_queue_capacity: i32 = 16,
    heartbeat: WebSocketHeartbeatConfig = WebSocketHeartbeatConfig{},
}
```

说明：

- `subprotocols` 当前实现是“指向 C 风格字符串数组首元素的头指针”，不是 `&[const byte]`。
- 这样做是为了保持当前编译器下接口与握手 helper 的稳定性；后续若类型系统路径更稳，可再回到更高层切片表示。
- `allow_extensions` 首期只是配置位，实际默认不协商 `permessage-deflate`。
- `max_frame_size` 与 `max_message_size` 分开，便于后续做聚合消息限制。
- `send_queue_capacity` 控制连接内 owned queue 容量；当前实现还会再被固定上限 32 截断。
- `heartbeat` 当前已进入配置结构，但主动定时任务仍待补。
- Phase 8 的收敛方向明确为“**外部调度驱动的主动任务**”：连接对象负责保存 `last_activity_ms / last_ping_ms / last_pong_ms / waiting_pong` 等状态，`read_* / write_*` 路径只做时间戳更新与被动 `auto_pong`，不在业务读写函数内部隐式 sleep / 轮询定时器。

### 4.5 连接状态结构体

参考 Go `Conn`，但显式化 Uya 所需状态：

```uya
export struct WebSocketConn {
    io: WebSocketFdTransport,
    role: WebSocketRole,
    auto_pong: bool,
    max_frame_size: usize,
    max_message_size: usize,
    heartbeat: WebSocketHeartbeatConfig,
    last_activity_ms: u64,
    last_ping_ms: u64,
    last_pong_ms: u64,
    waiting_pong: bool,
    close_sent: bool,
    close_received: bool,
    closed: bool,
    // 连接内 fixed queue：当前实现为 owned payload + 固定槽位
}
```

设计意图：

- 连接对象长期复用，承载会话状态与策略。
- 结构体方法就是主要 API 面。
- 当前实现已经内置一个 fixed-slot owned queue，而不是只预留空位。
- 这样先把背压与 flush 语义真正跑起来，再决定是否升级为 channel / pump / 多生产者模型。
- 后续可在不破坏调用面的前提下增加 deadline、metrics、subprotocol、close 状态。

## 5. transport 与接口设计

### 5.1 transport 层

默认基础实现是 fd transport，形态对齐 `MqttFdTransport`：

```uya
export struct WebSocketFdTransport : AsyncReader, AsyncWriter {
    fd: i32,
}
```

职责：

- 复用 `std.async.AsyncReader` / `AsyncWriter`
- 可直接挂到 epoll readiness
- `drop` 自动关闭 fd

另外补一个 WSS transport 层：

```uya
export struct WebSocketTlsTransport : AsyncReader, AsyncWriter {
    // 具体字段依赖 tls.https / TLS 会话抽象收敛结果
}
```

这样 `ws://` 与 `wss://` 共用会话层，而不是在 `WebSocketConn` 内写死 fd 特判。

### 5.1.1 Phase 6 收敛决策（2026-05-30）

- **先保留独立 `WebSocketTlsTransport`，不立即把 `WebSocketConn` 泛化到任意 `AsyncReader` / `AsyncWriter`。**
  当前 `WebSocketConn` 已经绑定了 `WebSocketFdTransport`、fixed queue、心跳时间戳与多处 `@async_fn` 状态机；如果在这一阶段把它整体泛化成“任意 reader/writer”，会把 Phase 6 变成一次大范围重构，而不是 WSS 能力接入。
- **`WebSocketTlsTransport` 的职责是包装已完成 TLS 握手后的连接，而不是重复发明 TLS 会话栈。**
  也就是说，TLS 握手、record 加解密、应用数据收发的事实来源仍然是 `tls.https` + `tls.ssl.context`；`websocket_tls.uya` 只补 WebSocket 侧需要的 transport 生命周期、upgrade glue 与后续 frame/message I/O 接口。
- **与现有 `tls.https` 对齐时，优先复用已验证过的 server 路径，而不是复制一份“WebSocket 专用 TLS server”。**
  当前仓库已经有 `https_server_handshake(...)`、`https_read_uyagin_request(...)`、`ssl_read(...)`、`ssl_write(...)` 和 `https_server_serve_uyagin_once(...)` 这条最小 HTTPS -> UyaGin 主链路。Phase 6 应该把其中“TLS 握手完成后得到明文 HTTP 请求”和“把明文响应重新封装回 TLS record”这两个边界提炼成可复用 helper，而不是在 `websocket_tls.uya` 里再手写一套握手/record 驱动。
- **`https_server_serve_uyagin_once(...)` 的 capture-file 响应路径不能直接复用到 WSS upgrade 成功后的会话期。**
  普通 HTTPS handler 可以先把 HTTP 响应写到 capture fd，再统一 TLS 加密回放；但 WebSocket upgrade 成功后，连接所有权已经被会话对象接管，后续 frame 需要立即经由活跃 TLS session 双向收发，因此 hijack 后必须切到 transport 直通模式。
- **TLS -> WebSocket upgrade 的桥接顺序明确为：**
  1. `https_accept_one(...)` 接受 TCP 连接。
  2. `https_server_handshake(...)` 完成 TLS 握手，拿到可用 `SslContext`。
  3. 通过 `https_read_uyagin_request(...)`（或等价复用 helper）读取并解密首个 HTTP 请求。
  4. 在明文请求上继续复用现有 `websocket_request_is_upgrade(...)` / `websocket_validate_upgrade_request(...)` / `websocket_build_upgrade_response(...)`。
  5. 将 `101 Switching Protocols` 响应通过 `ssl_write(...)` 回写。
  6. 把 `fd + SslContext + 生命周期状态` 移交给 `WebSocketTlsTransport`，后续 `read_frame` / `write_frame` 只走 TLS application data，不再回到 capture-file HTTP 响应路径。
- **`uyagin` 集成层也遵循同样边界。**
  WSS 版本不应把 upgrade 后的流量重新塞回普通 `GinContext` 响应写入路径，而是应在 TLS 已解密的请求上下文里完成一次 WebSocket upgrade 判断后，直接把活跃 TLS session 交给 `WebSocketTlsTransport` / `WebSocketConn`。

### 5.2 AsyncWebSocketConn 接口

建议像 `AsyncMqttClient` 一样定义能力接口，便于接 fd、TLS、内存环回、测试桩。

```uya
export interface AsyncWebSocketConn {
    @async_fn
    fn read_frame(self: &Self, rx: &byte, rx_cap: usize, opcode_out: &WebSocketOpcode, fin_out: &bool, payload_len_out: &usize) Future<!usize>;
    @async_fn
    fn read_message(self: &Self, rx: &byte, rx_cap: usize, msg: &byte, msg_cap: usize, opcode_out: &WebSocketOpcode) Future<!usize>;
    @async_fn
    fn write_frame(self: &Self, opcode: WebSocketOpcode, payload: &const byte, payload_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn write_message(self: &Self, opcode: WebSocketOpcode, payload: &const byte, payload_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn ping(self: &Self, payload: &const byte, payload_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn close_with_code(self: &Self, code: u16, reason: &const byte, reason_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn enqueue_message(self: &Self, opcode: WebSocketOpcode, payload: &const byte, payload_len: usize) Future<!usize>;
    @async_fn
    fn flush_pending(self: &Self) Future<!usize>;
}
```

要点：

- `read_frame` 提供底层能力，并把 payload 压紧到 `rx[0: payload_len]`。
- `read_message` 聚合 continuation，把整条消息写进 caller-owned `msg` 缓冲区，并通过 `opcode_out` 返回消息类型。
- `write_frame` / `write_message` 同时保留，避免 API 过早锁死。
- `ping` / `close_with_code` 是 WebSocket 语义动作，值得成为一等方法。
- `enqueue_message` / `flush_pending` 负责给后台发送、背压与自动重连后的恢复留稳定接口。
- 当前 async read API 之所以不直接返回 `WebSocketFrameView` / `WebSocketMessageView`，是为了避开现阶段编译器在 “复杂 view struct + 多次 `@await`” 路径上的 lowering 缺陷。

### 5.3 直接写与排队写双层 API

这是本版和前一稿最大的修正。

前一稿只定义了 caller-owned `tx/rx/msg` 风格的直接方法，这适合：

- 简单 echo
- 同步 request/response 风格会话
- 协议测试

但它不适合：

- 后台发送 pump
- 自动心跳
- 自动重连后重发
- 多生产者业务写入

因此本设计明确分成两层：

1. 直接 I/O 层  
   - `read_frame(rx, rx_cap, opcode_out, fin_out, payload_len_out)`
   - `read_message(rx, rx_cap, msg, msg_cap, opcode_out)`
   - `write_frame(..., tx, tx_cap)`
   - `write_message(..., tx, tx_cap)`

2. 连接自持队列层  
   - `enqueue_message(...)`
   - `flush_pending()`
   - 后台 heartbeat / reconnect / sender pump 只使用这层

约束也要写清楚：

- caller-owned buffer API 不跨 await 长期持有调用方栈缓冲；
- 队列层只接受“复制进连接内 owned queue”的消息；
- 需要背压时，以队列层语义为准，而不是直接写语义。
- 当前 `flush_pending()` 已落地，但还是“显式 drain + 立即写出”，后台 pump 仍待补。

## 6. 握手 API 设计

### 6.1 低层握手函数

建议先提供协议层函数，便于 `uyagin` 和裸 `std.http.server` 都能接。

```uya
export fn websocket_request_is_upgrade(req: &Request) bool;
export fn websocket_validate_upgrade_request(req: &Request) !void;
export fn websocket_compute_accept(key: &[byte], out: &byte, out_cap: usize) !usize;
export fn websocket_pick_subprotocol(req: &Request, supported: &&const byte, supported_count: i32) !&[const byte];
export fn websocket_build_upgrade_response(out: &byte, out_cap: usize, accept: &[byte], subprotocol: &[const byte]) !usize;
```

### 6.2 与 `uyagin` 的集成入口

建议提供一个框架友好的升级函数：

```uya
export @async_fn fn uyagin_websocket_upgrade(
    ctx: &GinContext,
    options: &WebSocketAcceptOptions
) Future<!WebSocketConn>;
```

当前实现同时补了一个同步 helper：

```uya
export fn uyagin_websocket_upgrade_sync(
    ctx: &GinContext,
    options: &WebSocketAcceptOptions
) !WebSocketConn;
```

原因不是语义分叉，而是当前编译器在“handler 内升级后把 `WebSocketConn` 这个大结构体跨多次 `@await` 持有”时 lowering 仍不稳定。
因此当前推荐写法是：

- 简单场景直接用 `uyagin_websocket_upgrade_sync(...)` 拿到连接；
- 后续读/写动作仍然调用 `WebSocketConn` 的 `@async_fn` 方法；
- 若 handler 内需要同时做多次 WebSocket `@await`，优先把另一半工作拆到同步 helper 或单次 `@await` 路径，直到 lowering 稳定后再完全收敛回纯 async 风格。

行为：

1. 从 `ctx.req()` 读取 header
2. 校验 `Connection: Upgrade`、`Upgrade: websocket`
3. 校验 `Sec-WebSocket-Version: 13`
4. 校验 `Sec-WebSocket-Key`
5. 发送 `101 Switching Protocols`
6. 从 `ctx.fd` 偷走连接所有权，构造 `WebSocketConn`

这里“偷走 fd 所有权”的语义必须写清楚，因为它是和普通 HTTP handler 最大的差异点：

- upgrade 成功后，这个连接不再由 `uyagin` 常规响应路径管理；
- 后续 fd 生命周期由 `WebSocketConn.drop()` 接管；
- `GinContext` 进入“已接管连接”状态，禁止再走普通 `ctx.string()` / `ctx.bytes()`。

### 6.3 裸 HTTP 集成入口

为了不绑死在 `uyagin`，还要提供：

```uya
export fn websocket_accept_from_http(
    fd: i32,
    req: &Request,
    options: &WebSocketAcceptOptions
) !WebSocketConn;
```

这个函数可用于：

- `std.http.server` 的自定义 accept 循环
- 更轻量的非框架 HTTP 服务
- 测试中手写握手场景

当前扩展策略也已收敛：

- 当客户端带 `Sec-WebSocket-Extensions` 且 `allow_extensions == false` 时，直接返回 `error.WebSocketExtensionsNotSupported`
- 当 `allow_extensions == true` 时，当前版本仍只表示“允许未来协商”，并不会回写扩展响应头

## 7. 读写 API 风格

### 7.1 最短路径

目标是让基础业务代码能写成：

```uya
const ws: WebSocketConn = try @await uyagin_websocket_upgrade(ctx, &opts);
var opcode: WebSocketOpcode = WebSocketOpcode.Binary;
const n: usize = try @await ws.read_message(&rx[0], 4096, &msg_buf[0], 4096, &opcode);
_ = try @await ws.write_message(opcode, &msg_buf[0] as &const byte, n, &tx[0], 4096);
```

这就是本设计最核心的“更优美”标准：

- 围绕 `ws` 调方法
- 复用一个连接对象
- 复用已有缓冲区
- 与 `MqttFdClient.connect()/publish_qos0()` 风格一致

而当业务需要后台发送、心跳和广播时，再切到：

```uya
_ = try @await ws.enqueue_message(WebSocketOpcode.Text, data, data_len);
_ = try @await ws.flush_pending();
```

### 7.2 为什么同时保留 frame/message 两层

只做 `ReadMessage/WriteMessage` 会丢掉协议灵活性；只做 frame 又不够优雅；只做 caller-owned 直接写又承载不了背压/重连。

因此建议：

- 业务代码默认用 `read_message` / `write_message`
- 协议代理、调试、网关场景用 `read_frame` / `write_frame`
- 后台任务、广播器、重连恢复场景用 `enqueue_message` / `flush_pending`

### 7.3 控制帧行为

建议默认策略：

- 收到 `Ping` 且 `auto_pong == true` 时，`read_message` 内部自动回 `Pong`
- 收到 `Pong` 时默认忽略，不作为业务消息返回
- 收到 `Close` 时返回 `error.WebSocketConnectionClosed`，并将 `closed = true`

同时保留一个更底层选择：

- `read_frame` 不隐藏控制帧
- 由调用方决定如何处理

### 7.4 Phase 7 JSON helper 决策（2026-05-30）

Phase 7 的 JSON helper 先收敛成“**JSON = text message 的高层便利层**”，而不是再引入第二套 message opcode 语义：

- `websocket_json_decode_value(...)` 只接受 `Text` 消息；若读到任意非 `Text` opcode，返回 `error.WebSocketProtocolError`
- 若业务明确需要 binary JSON、压缩 JSON 或自定义 envelope，不走 helper，直接用 `std.json` + `write_message(...)`

这样做的原因：

- RFC 语义和大多数现有生态默认把 JSON 放进 text frame
- helper 的目标是减少业务样板，而不是把“payload 格式”和“opcode 策略”重新抽象一层
- 保持 `write_message(...)` 作为唯一“调用方自行指定 opcode”的入口，避免 helper API 发生重复分叉

与现有 `std.json` 的衔接也明确收敛为两条固定路径：

- **typed path**：提供 `websocket_conn_write_json<T>(...)`；实现上直接在 helper 内单态化展开 `encode_to_to_json(T, ...)`，避免再额外依赖 `to_json<T>` 的二次泛型包装发射路径
- **value path**：`write_json_value(...)` 使用 `std.json.encoder.encode(arena, &value)`；raw `JsonValue` 解码提供同步 `websocket_json_decode_value(...)`，给调用方在 `read_message(...)` 之后复用

当前实现额外遵守一条编译器收敛约束：

- `write_json<T>` 已可用，但当前仍不额外提供 typed `read_json<T>`；读取侧继续收敛为 “`read_message(...)` -> `websocket_json_decode_value(...)`”
- 需要 JSON 读取时，优先走 “`read_message(...)` -> `websocket_json_decode_value(...)`” 两步链路；业务若要落到结构体，再基于 `JsonValue` 做现有 `std.json` 风格提取

错误映射保持“WebSocket 错误与 JSON 错误分层可见”：

- transport / frame / message 层错误原样透传，例如 `WebSocketConnectionClosed`、`WebSocketMessageTooLarge`
- 非 `Text` 消息走 JSON decode helper 时返回 `error.WebSocketProtocolError`
- JSON 解析与类型解码失败时，保留 `std.json.errors` 原始错误，例如 `UnexpectedToken`、`UnexpectedEof`、`WrongType`、`MissingField`

这意味着：

- 业务层可以用单个 `catch` 处理“不是 JSON 消息”
- 也可以按 `std.json.errors` 精细区分“payload 不是合法 JSON”与“JSON 合法但结构不匹配”

## 8. frame 编码与解析策略

### 8.1 编码函数

建议拆成可组合的低层函数：

```uya
export fn websocket_encode_frame_header(
    role: WebSocketRole,
    fin: bool,
    opcode: WebSocketOpcode,
    payload_len: usize,
    mask_key: [byte: 4],
    out: &byte,
    out_cap: usize
) !usize;

export fn websocket_apply_mask_inplace(data: &byte, payload_len: usize, mask_key: [byte: 4]) void;
export fn websocket_encode_frame_raw(role: WebSocketRole, fin: bool, opcode: WebSocketOpcode, payload: &const byte, payload_len: usize, mask_key: [byte: 4], out: &byte, out_cap: usize) !usize;
```

### 8.2 解析函数

```uya
export fn websocket_parse_frame_from_buffer(
    role: WebSocketRole,
    raw: &byte,
    raw_len: usize,
    continuation_active: bool
) !WebSocketFrameView;
```

解析规则：

- server 侧读客户端帧时，必须要求 `masked == true`
- client 侧读服务端帧时，必须要求 `masked == false`
- 控制帧必须 `FIN == true`
- 控制帧 payload 不能超过 125
- continuation 规则必须严格校验

## 9. 分片与消息聚合

### 9.1 首期支持

首期建议：

- `write_message` 在 `tx` 缓冲区装不下整条消息时，自动切成 continuation 分片
- `read_message` 支持把多 frame continuation 聚合进 `msg` 缓冲区

原因：

- 读路径比写路径更需要兼容外部客户端
- 写路径当前也已经覆盖“固定 caller buffer 下的大消息发送”，避免业务方手工切 continuation

### 9.2 后续扩展

如果后面要支持超大消息流式发送，再补：

```uya
export interface AsyncWebSocketMessageWriter {
    @async_fn
    fn write_chunk(self: &Self, data: &const byte, data_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn finish(self: &Self, tx: &byte, tx_cap: usize) Future<!usize>;
}
```

但这不进入首期，因为会明显提高状态机复杂度。

## 10. 与 `uyagin` 的集成设计

### 10.1 新模块建议

如果不想把所有逻辑塞进 `uyagin.uya`，可新增一个桥接文件：

```text
lib/std/http/uyagin_websocket.uya
```

职责只做：

- 读取 `GinContext`
- 发送 `101`
- 移交 fd
- 构造 `WebSocketConn`

这样能避免：

- `uyagin.uya` 继续膨胀
- WebSocket 协议层反向依赖框架细节

### 10.2 业务 handler 风格

建议业务端这样写：

```uya
export struct ChatHandler : AsyncHandler {
    @async_fn
    fn handle(self: &Self, ctx: &GinContext) Future<!i32> {
        const opts: WebSocketAcceptOptions = WebSocketAcceptOptions{};
        var ws: WebSocketConn = try @await uyagin_websocket_upgrade(ctx, &opts);

        var rx: [byte: 4096] = [0: 4096];
        var msg: [byte: 4096] = [0: 4096];
        var tx: [byte: 4096] = [0: 4096];
        var opcode: WebSocketOpcode = WebSocketOpcode.Binary;

        while true {
            const n: usize = try @await ws.read_message(&rx[0], 4096, &msg[0], 4096, &opcode);
            _ = try @await ws.write_message(opcode, &msg[0] as &const byte, n, &tx[0], 4096);
        }
        return 0;
    }
}
```

这份风格文档层面要明确鼓励，因为它正好体现：

- handler 是结构体
- websocket 会话也是结构体
- 高层动作全是方法
- caller-owned buffer 清晰可见

## 11. 所有权与生命周期

### 11.1 Upgrade 后的所有权转移

需要写死这些规则：

- `WebSocketConn` 独占连接 fd 的关闭责任
- upgrade 成功后，HTTP 层不得再关闭同一个 fd
- 从 HTTP request 借来的 header/path 切片不能跨 WebSocket 会话长期持有
- 若连接启用了内部发送队列，队列中的消息副本由连接对象拥有，不再借用调用方 payload

### 11.2 缓冲区生命周期

- `read_frame` 返回的 payload 信息绑定到 `rx` 缓冲区；当前实现会把 payload 压到 `rx[0: n]`
- `read_message` 返回的 payload 信息绑定到 `msg` 聚合缓冲区；当前实现直接返回长度并通过 `opcode_out` 告知类型
- 调用下一次 `read_*` 之前，若业务还要保留数据，必须自己复制
- `enqueue_message` 必须在进入队列前完成复制，不能悬挂外部栈上 payload

### 11.3 drop 行为

`WebSocketConn` 应实现：

```uya
fn drop(self: WebSocketConn) void
```

行为：

- 如果底层 transport fd 仍有效，则关闭
- 若已经显式 close 过，则 drop 幂等

## 12. 与 async/runtime 的适配

### 12.1 直接复用 `AsyncReader` / `AsyncWriter`

这是最重要的兼容点，因为能自然复用：

- `AsyncFd`
- `LinuxEpoll`
- `block_on_with_event_loop`
- 未来 TLS transport

同时，Client policy 层不能直接依赖“临时传入的 tx/rx 缓冲区”，而应依赖连接对象自持状态。

### 12.2 `@async_fn` 方法优先

所有高频 API 都设计成结构体 `@async_fn` 方法，而不是只给自由函数：

- `ws.read_message(...)`
- `ws.write_message(...)`
- `ws.ping(...)`
- `ws.close_with_code(...)`
- `ws.enqueue_message(...)`
- `ws.flush_pending(...)`

自由函数只保留在：

- 握手工具
- frame 编解码
- 连接构造

## 13. 分阶段落地计划

### Phase 1：基础类型与握手

- `websocket_types.uya`
- `websocket_handshake.uya`
- 纯函数测试：header 校验、accept 计算、subprotocol 选择

### Phase 2：frame 编解码

- `websocket_frame.uya`
- 单 frame text/binary/ping/pong/close 编解码
- 掩码与长度边界测试

### Phase 3：async fd 会话

- `WebSocketFdTransport`
- `WebSocketConn`
- `read_frame` / `write_frame`
- 最小 send queue / close 状态机

### Phase 4：message 聚合与控制帧策略

- `read_message`
- auto pong
- continuation 聚合
- close frame 后失败语义

### Phase 5：`uyagin` 集成

- `uyagin_websocket_upgrade`
- 示例 handler
- loopback 集成测试

### Phase 6：TLS / WSS transport

- `WebSocketTlsTransport`
- HTTPS / WSS loopback

### Phase 7：JSON 辅助 API

- `write_json`
- `read_json`

### Phase 8：心跳、重连、背压

- `WebSocketClient`
- `ReconnectPolicy`
- sender queue / flush pump / heartbeat

## 14. 测试设计

建议新增测试：

```text
tests/test_http_websocket_handshake.uya
tests/test_http_websocket_frame.uya
tests/test_http_websocket_async.uya
tests/test_http_uyagin_websocket.uya
tests/test_https_websocket_loopback.uya
tests/test_http_websocket_json.uya
tests/test_http_websocket_reconnect.uya
tests/test_http_websocket_heartbeat.uya
tests/test_http_websocket_backpressure.uya
```

覆盖重点：

- 握手成功
- 缺失 `Sec-WebSocket-Key`
- `Sec-WebSocket-Version != 13`
- 服务端拒绝未 masked 客户端帧
- 控制帧长度超限
- continuation 乱序
- ping 自动 pong
- close 后 `read_message` / `write_message` 行为
- `uyagin` upgrade 后 echo roundtrip
- WSS loopback
- JSON 编解码
- 重连与队列满背压

## 15. 与现有模块关系

### 15.1 依赖方向

建议依赖关系：

```text
std.http.types
        ^
        |
std.http.websocket_handshake
        ^
        |
std.http.websocket_async
        ^
        |
std.http.websocket_tls
std.http.websocket_json
std.http.websocket_client

std.async ----^
std.http.uyagin_websocket -> std.http.uyagin + std.http.websocket_async
```

注意避免：

- `std.http.types` 反向依赖 websocket
- `std.http.websocket_async` 直接深度耦合 `uyagin`
- `websocket_client` 反向侵入协议层基础编码逻辑

### 15.2 为什么不直接塞进 `uyagin`

因为 WebSocket 是“基于 HTTP Upgrade 的长期连接协议”，不是单纯框架语法糖：

- 底层 `std.http.server` 也能用
- 测试桩和工具程序也能用
- 后面 HTTPS bridge 也能复用
- client policy 层也需要共享同一套协议核心

## 16. API 草案汇总

```uya
export enum WebSocketOpcode {
    Continuation = 0,
    Text = 1,
    Binary = 2,
    Close = 8,
    Ping = 9,
    Pong = 10,
}

export enum WebSocketRole {
    Server,
    Client,
}

export struct WebSocketAcceptOptions {
    subprotocols: &const byte = null,
    subprotocol_count: i32 = 0,
    allow_extensions: bool = false,
    max_frame_size: usize = 65536,
    max_message_size: usize = 1048576,
    auto_pong: bool = true,
    send_queue_capacity: i32 = 16,
    heartbeat: WebSocketHeartbeatConfig = WebSocketHeartbeatConfig{},
}

export struct WebSocketFrameView {
    fin: bool,
    opcode: WebSocketOpcode,
    masked: bool,
    payload_ptr: &byte,
    payload_len: usize,
    mask_key: [byte: 4],
}

export struct WebSocketMessageView {
    opcode: WebSocketOpcode,
    payload_ptr: &byte,
    payload_len: usize,
}

export struct WebSocketFdTransport : AsyncReader, AsyncWriter {
    fd: i32,
}

export struct WebSocketConn : AsyncWebSocketConn {
    io: WebSocketFdTransport,
    role: WebSocketRole,
    auto_pong: bool,
    max_frame_size: usize,
    max_message_size: usize,
    heartbeat: WebSocketHeartbeatConfig,
    close_sent: bool,
    close_received: bool,
    closed: bool,
}

export interface AsyncWebSocketConn {
    @async_fn
    fn read_frame(self: &Self, rx: &byte, rx_cap: usize, opcode_out: &WebSocketOpcode, fin_out: &bool, payload_len_out: &usize) Future<!usize>;
    @async_fn
    fn read_message(self: &Self, rx: &byte, rx_cap: usize, msg: &byte, msg_cap: usize, opcode_out: &WebSocketOpcode) Future<!usize>;
    @async_fn
    fn write_frame(self: &Self, opcode: WebSocketOpcode, payload: &const byte, payload_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn write_message(self: &Self, opcode: WebSocketOpcode, payload: &const byte, payload_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn ping(self: &Self, payload: &const byte, payload_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn close_with_code(self: &Self, code: u16, reason: &const byte, reason_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn enqueue_message(self: &Self, opcode: WebSocketOpcode, payload: &const byte, payload_len: usize) Future<!usize>;
    @async_fn
    fn flush_pending(self: &Self) Future<!usize>;
}

export fn websocket_request_is_upgrade(req: &Request) bool;
export fn websocket_validate_upgrade_request(req: &Request) !void;
export fn websocket_compute_accept(key: &[byte], out: &byte, out_cap: usize) !usize;
export fn websocket_pick_subprotocol(req: &Request, supported: &&const byte, supported_count: i32) !&[const byte];
export fn websocket_build_upgrade_response(out: &byte, out_cap: usize, accept: &[byte], subprotocol: &[const byte]) !usize;
export fn websocket_accept_from_http(fd: i32, req: &Request, options: &WebSocketAcceptOptions) !WebSocketConn;

export @async_fn fn uyagin_websocket_upgrade(ctx: &GinContext, options: &WebSocketAcceptOptions) Future<!WebSocketConn>;

export fn websocket_conn_write_json<T>(self: &WebSocketConn, arena: &Arena, value: T, tx: &byte, tx_cap: usize) Future<!usize>;
export fn websocket_conn_write_json_value(self: &WebSocketConn, arena: &Arena, value: &JsonValue, tx: &byte, tx_cap: usize) Future<!usize>;
export fn websocket_json_decode_value(arena: &Arena, opcode: WebSocketOpcode, msg: &byte, msg_len: usize) !JsonValue;
```

## 17. 关键决策

### 17.1 放在 `std.http`

决定放在 `std.http`，不是 `std.net.websocket` 或独立顶层模块。

### 17.2 连接对象优先

决定优先把能力挂在 `WebSocketConn` 结构体方法上，而不是只提供函数式 API。

### 17.3 接口 + 默认实现并存

决定同时提供：

- `AsyncWebSocketConn` 接口
- `WebSocketConn` / `WebSocketFdTransport` 默认实现

### 17.4 caller-owned buffer

决定继续沿用 `std.mqtt.async` 风格提供直接读写 API，但同时补上连接内 owned queue，避免后续背压/心跳/重连推翻接口。

### 17.5 `uyagin` 只做桥接

决定 `uyagin` 负责 upgrade 集成，不负责承载全部协议实现。

### 17.6 高级能力不再视为“后续再想”

决定把 TLS、JSON、心跳、重连、背压明确纳入这一版架构设计，而不是只在 TODO 里挂名。

## 18. 后续文档同步建议

如果进入实现阶段，建议同步补这些文档：

- `docs/todo_http.md`
- 若新增公开 API，再补充相关 std/http 使用文档
- 若最终把 WebSocket 视为框架能力的一部分，可再加 `docs/std_http_websocket.md` 作为用户文档
