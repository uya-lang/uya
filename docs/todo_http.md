# Uya HTTP 框架实现待办

**参考**：[http_framework_design.md](http_framework_design.md)、[.cursor/plans/uya_高性能_http_框架_09efdaaa.plan.md](.cursor/plans/uya_高性能_http_框架_09efdaaa.plan.md)

实现时遵循项目 TDD 流程：先添加测试 → 实现代码 → `make check` 验证。新增测试需同时通过 `--c99` 与 `--uya --c99`。

## 进展补记（2026-04-25）

- `std.http.parse` 现已补入 8-byte word-at-a-time 扫描、Header 小写/哈希缓存与常见头快速路径。
- `std.http` / `uyagin` 主链路现已支持 **chunked request** 的线级解析 + 连接缓冲原地解码。
- `std.http.server` 与 `std.http.uyagin` 响应热路径现已接通 **`writev`**；UyaGin 文件响应在 **Linux x86_64** 上优先 `sendfile`。
- `tls.https` 现已可把 TLS 握手后的最小 HTTP 请求桥接到 `std.http.uyagin.Engine`，用于 HTTPS loopback server 回归。
- WebSocket 相关拆解、示例与路线占位现已独立整理到 [`todo_http_websocket.md`](./todo_http_websocket.md)、[`std_http_websocket.md`](./std_http_websocket.md) 与 [`std_http_websocket_http2_http3_route.md`](./std_http_websocket_http2_http3_route.md)。
- 因此，本页 Phase 1–8 的“最小 HTTP 基础设施”已超出最初 blocking-only 范围；更偏 UyaGin 的协议 / I/O 优化路线请同步参考 [`uyagin_todo.md`](./uyagin_todo.md) 与 [`uyagin_design.md`](./uyagin_design.md)。

---

## Phase 1：TCP 基础设施

### 1.1 前置

- [x] 确认 Uya 可用的 socket/syscall 封装（`lib/libc/syscall.uya` + `lib/syscall/linux.uya` 提供 socket 相关系统调用）
- [x] 确认 fd 类型（i32）与 close 语义

### 1.2 测试

- [x] TCP 基础测试通过（`tests/test_http_server.uya` fork 子进程 + loopback 连接验证）

---

## Phase 2：http.types

### 2.1 目录与错误

- [x] 创建 `lib/std/http/` 目录
- [x] `types.uya`：预定义错误 InvalidRequest、MethodNotAllowed、URITooLong、HeaderTooLarge、PayloadTooLarge、TooManyParams、ValueTooLong、InvalidToken、InvalidBoundary、TooManyParts

### 2.2 枚举与常量

- [x] Method 枚举：GET、POST、PUT、PATCH、DELETE、OPTIONS、HEAD
- [x] Status 枚举：OK、Created、NoContent、BadRequest、NotFound、MethodNotAllowed、Conflict、InternalServerError 等
- [x] ServerMode 枚举：Blocking、Epoll、ThreadPool
- [x] 常量 P=8、Q=16、L=256、MAX_MULTIPART_PARTS（path_params/query 条数、单 key/value 最大字节、multipart part 数量上限）

### 2.3 结构体

- [x] Request：method、path、path_params、query、headers、body（借用 &[byte]，buffer 归 Server/Conn）；multipart 时提供 Part 类型与 parse_multipart / req.multipart()
- [x] path_params/query 为固定容量线性数组（P、Q、L）
- [x] Response：status、headers、body
- [x] Context：request、response、conn
- [x] Conn：fd；实现 `fn drop(self: Conn) void`（按值关闭 fd）

### 2.4 接口与辅助

- [ ] Handler 接口：`fn serve(self: &Self, ctx: &Context) !void`
- [ ] Middleware 接口：`fn process(self: &Self, ctx: &Context, next: Handler) !void`（首版仅类型）
- [x] `request_get_header(req, name)` / `get_bearer_token(req)`（`lib/std/http/types.uya`；头名大小写不敏感；Bearer 前缀大小写不敏感；测试见 `test_http_types.uya`、`parse_then_request_get_header`）
- [x] ServerConfig：mode、max_connections

### 2.5 测试

- [x] `tests/test_http_types.uya`：枚举、常量、`parse_method_bytes` 失败、`request_get_header` / `get_bearer_token` 成功与错误路径

---

## Phase 3：http.parse

### 3.1 解析器

- [x] `parse.uya`：`parse(buf: &[byte]) !Request` 或 `!ParseResult`；若单请求则仅返回 Request，若支持 Keep-alive 则返回 consumed（或 ParseResult 含 request + consumed），供下一轮 parse 使用剩余数据
- [x] 请求行：METHOD SP URI SP VERSION；URI 含 path + query
- [x] 头部解析：Content-Type、Content-Length 等；单 header 与总 header 受 L/常量限制
- [x] Body：按 Content-Length，首版 body 上限（如 64KB）；Content-Type 为 multipart/form-data 时按 boundary 解析 part
- [x] Multipart：parse_multipart(body, boundary) 或 Request.multipart()；Part 含 name、filename、content_type、body；常量 MAX_MULTIPART_PARTS 限定 part 数；InvalidBoundary/TooManyParts
- [x] 所有下标访问在当前函数内证明安全（循环条件/边界检查），失败返回 error.XXX

### 3.2 Keep-alive

- [x] 单请求边界：请求行 + 头部 + Content-Length body；多请求时根据 parse 返回的 consumed 或 remaining 将剩余数据作为下一轮 parse 输入

### 3.3 测试

- [x] `tests/test_http_parse.uya`：GET/POST、path、query、headers、body、Keep-alive；多种错误（`InvalidRequest`、`URITooLong`、`HeaderTooLarge`、`PayloadTooLarge`、`IncompleteRequest`）
- [x] `tests/test_http_multipart.uya`：`extract_multipart_boundary`（含引号）、缺失 boundary、`parse_multipart` 单段、boundary 过长、`TooManyParts`

---

## Phase 4：http.router

### 4.1 Router

- [x] `router.uya`：路由表 `(method, path_pattern)` 条目 + `router_find_route` 返回命中下标；容量由 `MAX_ROUTES` 限定；首版不存 `Handler`（由调用方按下标映射）
- [x] 路径参数：`/users/:id` 等；`router_apply_path_params` 写入 `Request.path_params`
- [x] 404：`router_find_route` 返回 `-1`；405：返回 `-2`（存在同路径模式但方法不符）

### 4.2 资源组（可选）

- [ ] ResourceHandlers 结构体字面量：get、post、get_by_id、put、delete 等；router.resource("/users", handlers)

### 4.3 测试

- [x] `tests/test_http_router.uya`：注册、匹配、path_params 提取、404/405

---

## Phase 5：http.server

### 5.1 Server

- [x] `server.uya`：`HttpServer`、`ServerConfig`；`http_server_listen` / `http_server_accept` / `http_server_close`（`ServerMode.Blocking` + 127.0.0.1；`port==0` 时 `getsockname` 填端口）
- [x] `http_recv_parse_request`（内部多 `recv` + `parse`）、`http_conn_read_parse_nonblocking`（`EAGAIN`→`error.ReadWouldBlock`，与 epoll 配合；`EINTR` 重试读）、`http_write_all_nonblocking`（非阻塞短写续传，写侧 `EAGAIN`→`ReadWouldBlock`；`EINTR` 重试写）、`http_send_response`（`text/plain` + `Content-Length`；状态行含 200/201/204/400/404/405/500）、`http_tcp_connect_loopback`（测试用）
- [x] 首版路线图：阻塞 accept + 原语级 API（无自动「每连接一线程」封装，由应用显式循环 accept+handle）
- [x] 每连接：读 buffer -> parse -> `router`/Handler -> 写 Response；Keep-alive 多轮 parse（`http_conn_read_parse` + `http_connbuf_shift` + `IncompleteRequest` / 多次 `recv`）
- [x] 错误路径（解析）：非法方法等导致 `!ParseResult` 时服务端可回 `400`（`http_parse_error_returns_400`）；Handler 层统一 5xx 仍待扩展

### 5.2 epoll 预留

- [x] `std.http.epoll_server`（`lib/std/http/epoll_server.uya`）：`ServerMode.Epoll` 下 `epoll_server_listen`（`port==0` 时 `getsockname`）、`listen_fd` 已加入 epoll（`EPOLLIN`）、`epoll_server_wait_events` / `epoll_server_poll`、`epoll_server_event_is_listen`、`epoll_server_slot_for_fd`、`epoll_server_ctl_mod`（`EPOLL_CTL_MOD`，如 `EPOLLIN|EPOLLOUT`）、`epoll_server_accept_register` / `epoll_server_accept_register_nb`、`epoll_server_listen_set_nonblocking`、`epoll_server_try_accept_register_nb`（无挂起连接时 `error.ReadWouldBlock`；`EINTR` 重试 `accept`；其它 `accept` 失败 `error.AcceptFailed`）、`epoll_server_drain_listen_accepts_nb`（循环 `accept` 至 `EAGAIN`）、`epoll_server_release_slot`、`epoll_server_accept` / `epoll_server_close`；`EPOLL_SERVER_IO_CAP` 与槽内 `buf` 一致，供 `http_conn_read_parse`；槽位满返回 `error.EpollSlotsFull`；`EPOLL_SERVER_MAX_SLOTS`（默认 512）控制栈占用与最大并发连接数
- [ ] `server.uya` 阻塞 API 仍仅 `Blocking`；完整 `run_epoll_loop`（客户端 fd 注册、`http_conn_read_parse`、路由与 Keep-alive 多轮）待办

### 5.3 测试与示例

- [x] `tests/test_http_server.uya`：fork 子进程作客户端，父进程 accept → parse → `router_find_route_request` → 响应；校验 plaintext（`--safety-proof` + `make check`）
- [x] `examples/http_server.uya`：最小可运行示例（`127.0.0.1:8765`，单连接一次请求；`match` 成功分支须置于错误分支之后以避免 C99 后端问题）

### 5.4 相关修复（syscall）

- [x] Linux x86_64：`SYS_waitpid`(61) 实为 `wait4`，`sys_waitpid` / `libc.unistd.waitpid` 已改为四参（`rusage=NULL`），避免 `wait` 后异常崩溃（影响 `pthread_join` 等）

---

## Phase 6：测试与示例完善

### 6.1 覆盖

- [x] 所有 !T 错误路径有测试（parse、router、get_header、get_bearer_token）（已部分覆盖：含 query `InvalidRequest`/`ValueTooLong`/`TooManyParams`、`parse_header_*`、`test_http_multipart`、`router_add_*` 等；`get_bearer_token` 的 `InvalidRequest`/`InvalidToken` 错误路径已完整覆盖）
- [x] 多请求 Keep-alive 测试（`tests/test_http_server.uya` 流水线双 GET + `parse_post_body_incomplete`）
- [x] 预期编译失败：`tests/error_http_request_get_header_type.uya`（少传 `request_get_header` 参数）

### 6.2 示例

- [x] REST 场景测试：`http_pipeline_post_created_get_no_content`（流水线 POST→`201 Created`+body、GET→`204 No Content`）；`http_get_path_param_and_query`（`GET /item/99?q=v` + `router_apply_path_params_request`，`path_params[].value` 指向 `Request.path`）
- [x] 在 [readme.md](../readme.md) 已增加「标准库 HTTP（实验性）」小节（TDD、`make check`、`--uya --c99`）；设计文档仍见 [http_framework_design.md](http_framework_design.md)

---

## Phase 7：http.jwt

### 7.1 工具与解析

- [x] `lib/std/http/jwt.uya`：Base64URL 编解码（`decode_base64url` / `b64url_encode`）
- [x] JWT 三段解析：header.payload.signature；不依赖 `get_bearer_token`

### 7.2 API

- [x] `jwt_verify_hs256(token, secret, payload_out) !usize`（HS256 验签，payload 写入缓冲区）
- [x] `jwt_decode_unverified(token, payload_out) !usize`（不验签）
- [x] `jwt_sign_hs256(payload, secret, token_out) !usize`（签发 HS256）
- [x] `jwt_payload_is_expired(payload, now_unix_sec) !bool`（解析 JSON 根对象、`exp` 为整数；无 `exp` 视为未过期；`now >= exp` 为已过期；与 `has_expired` 等价语义由调用方传入当前 Unix 秒）

### 7.3 依赖

- [x] HMAC-SHA256：`lib/std/crypto/sha256.uya`（SHA-256）+ `jwt.uya` 内 HMAC；无 OpenSSL

### 7.4 测试

- [x] `tests/test_http_jwt.uya`：sign/verify 往返、decode、错误密钥、畸形 token → `InvalidToken`

---

## Phase 8：性能基准与验证

### 8.1 基准程序

- [x] `benchmarks/http_bench.uya`：`GET /`（plaintext `hello`）、`GET /json`、`GET /item/:id`（body 为 id）、`GET /payload1k|10k|100k`（`make check` 含 `tests/verify_http_bench_compile.sh`）；`--once` 冒烟；默认 `127.0.0.1:8876` + Keep-alive
- [~] `benchmarks/http_bench_async_epoll.uya`：单线程 epoll + `@async_fn` 示例 bench（`make check` 含 `tests/verify_http_bench_async_epoll_compile.sh`，**仅 C99 编译**）。**运行时**正确响应依赖编译器在嵌套循环内 **await 之间发出语句**（当前缺口见 [todo_async_loop_await.md](todo_async_loop_await.md)）；仅 bind IPv4 时 `localhost` 先试 `::1` 可能拒连属预期。
- [x] `benchmarks/http_bench.go`：Go 参考服务端（与 Uya 版路由/响应一致）
- [x] `benchmarks/http_bench_tokio`：Rust Tokio + Hyper 对照服务端（路由与 Go 版一致；`cargo` 可用时 `run_bench.sh` 会参与 wrk 对比）

### 8.2 环境与脚本

- [x] `benchmarks/run_bench.sh`：运行 wrk 并解析输出，对比 Uya-async/Go/C/nginx（及可选 Tokio）QPS；`--baseline` 保存到 `baseline.json`（含 `tokio_qps` / `nginx_qps` 字段）
- [x] `benchmarks/baseline.json`：基线数据（含测试机配置：Intel i7-14700/31GB/Deepin 25）
- [x] 运行 `./run_bench.sh --baseline` 获取实际基线数据
- [x] 文档记录：CPU、内存、OS、编译器；wrk 使用 keep-alive
- [ ] 回归允许 ±5%；CI 或文档中说明如何复现

---

## Phase 9/10：后续迭代

- [ ] ServerMode.Epoll 多路复用实现（首步：`epoll_server` 监听侧 poll+accept 已落地，见 5.2 与 `tests/test_epoll_server.uya`；待：连接级 epoll、非阻塞 I/O、与 `http_conn_read_parse`/路由闭环）
- [ ] 中间件实现：logging、CORS、jwt_auth（包装 Handler，401/403 语义见设计文档）
- [ ] 异步 Handler、线程池模式（ThreadPool）
- [~] http.client（可选；已有实验性 `lib/std/http/http1_async.uya`，提供 `http1_async_get/post`，通过 nonblocking socket + epoll readiness 完成 connect/read/write）
- [ ] 与 std.json 集成（请求/响应 JSON 序列化）

---

## 与主待办集成

- [x] 在 [todo_mini_to_full.md](todo_mini_to_full.md) 标准库表中已增加 **38.1 std.http** 条目
