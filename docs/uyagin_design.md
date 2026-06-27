# UyaGin HTTP 框架详细设计

UyaGin 是 `std.http.uyagin` 中的 Gin 风格 HTTP 框架核心，目标是在 Uya 的纯 `@async_fn` 异步模型上提供可读、可维护、低分配、低延迟的 Web 服务层。它不是简单复刻 Go Gin，而是利用 Uya 的零 GC、显式错误、RAII、编译期泛型和可注入 allocator，把请求生命周期拆成可预测的状态机与零拷贝视图。

## 目标

- **纯异步**：所有网络读写入口以 `Future<!T>` 和 `@async_fn` 表达，调度交给 `std.async` / `std.async_scheduler` / `std.async_event`。
- **Gin 风格**：保留 `Engine.GET(...)`、`Engine.POST(...)`、`Context.param(...)`、`Context.string(...)`、`Context.json_raw(...)` 这类直观 API。
- **只读切片 API**：路由 pattern、响应 body、header/query/param 名称使用 `&[const byte]`，字符串字面量可直接传入，无需 `&"..."[offset:len]`。
- **优先性能**：请求解析、路由匹配、参数提取、响应写入默认不走 heap；小响应合并 header/body 一次写。
- **可维护**：核心只组合现有 `std.http.types`、`std.http.router`、`std.http.parse`、`std.http.server`，避免重复实现 HTTP 基础层。
- **目标超过 Gin**：最终在相同硬件、相同业务逻辑、keep-alive、同等连接数下，追求 RPS 与 p99 延迟超过 Go Gin；当前提交是框架核心切片，基准达标需按 TODO 路线继续实现和验证。

## 当前落点

- 源码：`lib/std/http/uyagin.uya`
- 测试：`tests/test_http_uyagin.uya`
- 依赖：`std.async`、`std.http.types`、`std.http.router`、`std.http.parse`、`std.http.server`

当前已实现：

- `Engine`：路由注册、路由查找、handler dispatch、`Use(...)`、`Group(...)`、`HEAD/OPTIONS` 自动处理。
- `RouterGroup`：前缀拼接、group middleware 继承、分组路由注册。
- `AsyncHandler`：异步 handler 接口，返回 `Future<!i32>`。
- `GinContext`：请求上下文、path/query/header 访问、`DefaultQuery`、`PostForm`、`PostFormDefault`、`Multipart`、`status`、`header_set`、`abort`、响应写入。
- `uyagin_send_response_async` / `uyagin_write_context_response_async` / `uyagin_send_context_response_*`：异步响应写入；小响应 header/body 合并，大响应走 `writev` 聚合写。
- `ctx.chunked(...)` / `uyagin_send_context_chunked_response_*`：显式 chunked response。
- `ctx.file(...)` / `uyagin_send_file_body_async`：文件响应；Linux x86_64 优先 `sendfile`，其它路径安全回退到 nonblocking `read/write`。
- `uyagin_error_response` / `uyagin_run_chain_recover`：统一错误映射与 recovery 路径。
- `uyagin_method_not_allowed` / `uyagin_auto_options`：`405` / `OPTIONS` 的 `Allow` 头自动生成。
- `uyagin_conn_read_parse_async`：异步读取并解析一个 HTTP/1.x 请求；当前已支持 chunked request 线级解析与连接缓冲内原地解码。
- `uyagin_accept_async`：异步 accept。
- `uyagin_serve_conn`：单连接 keep-alive 请求循环。
- `UyaginAccessLogOptions` / `uyagin_emit_access_log`：可关闭、可采样、栈缓冲零分配 access log。
- `UyaginMetrics` / `UyaginObserveFuture`：请求数、状态码、延迟直方图、连接数与 arena/frame 统计统一收口。
- `UyaginConfig` / `EngineRunOptions`：allocator、limits、backlog、buffer cap、request arena cap、timeouts、mode、access log 配置。
- `GinListener`：监听 socket 的 RAII 包装，`drop` 自动关闭。
- `tls.https.https_server_serve_uyagin_once`：最小 HTTPS -> UyaGin handler 桥接。

## API 草图

```uya
use std.async;
use std.async_event;
use std.async_scheduler;
use std.http.types;
use std.http.uyagin;

struct Hello : AsyncHandler {}

Hello {
    @async_fn
    fn handle(self: &Self, ctx: &GinContext) Future<!i32> {
        _ = self;
        return try @await ctx.string(Status.OK, "hello");
    }
}

export fn main() i32 {
    var app: Engine = uyagin_new();
    var hello: Hello = Hello{};
    const h: AsyncHandler = hello;
    app.GET("/hello", h) catch { return 1; };

    // 生产形态：listen + EventLoop + Scheduler 驱动 app.serve_once/serve_conn。
    return 0;
}
```

## 架构

### 1. 网络层

- `uyagin_accept_async` 使用 `Future<!i32>` 封装非阻塞 `accept`。
- `uyagin_conn_read_parse_async` 使用 `async_fd_read_future` 在 fd 可读时继续读。
- `uyagin_send_response_async` 使用 `async_fd_write_all` 在 fd 可写时继续写。
- 调度器通过 `Waker.wait_readable` / `Waker.wait_writable` 与 epoll EventLoop 组合。

### 2. 解析层

- 复用 `http_parse_request`，请求 path、query、header、body 尽量是输入缓冲的切片视图。
- header 名解析时统一转小写，并缓存 hash / 常见 header kind；`Content-Length` / `Transfer-Encoding` / `Connection` 等查找优先走缓存，手工构造 `Request` 时则按字节回退匹配。
- `ParseResult.consumed` 用于 keep-alive pipeline 场景，处理完一个请求后调用 `http_connbuf_shift` 前移剩余字节。
- `Transfer-Encoding: chunked` 请求体在 parser 侧先做线级完整性检查，再在连接缓冲中原地解码为连续 body 切片。
- 请求体大小沿用 `HTTP_CONN_READ_CAP` 量级，避免无限读取。

### 3. 路由层

- 当前 `Engine.router` 复用 `std.http.router.Router`。
- `Engine.routes` 与底层 `Router.entries` 同序保存 handler，匹配到下标后 O(1) 取 handler。
- `router_apply_path_params_request` 将 `:id` 等 path 参数写回 `Request.path_params`，`Context.param` 零拷贝读取。

### 4. 上下文层

`GinContext` 只保存本次请求必需状态：

- `fd`：连接 fd。
- `request`：指向当前 `Request`。
- `wrote`：handler 是否已经写响应。
- `aborted`：是否中止后续处理。
- `persist`：本轮响应后是否保持连接。
- `allocator`：预留给 per-request arena / typed storage。

### 5. Handler 层

- `AsyncHandler.handle` 是异步接口，业务可在 handler 中 `try @await` 数据库、DNS、HTTP 客户端等 future。
- 返回 `i32` 而不是 `void`，是为了避开当前 C 后端对 `Future<!void>` 的不完整支持，同时为 middleware 返回码预留空间。
- 错误通过 `!T` 传播，框架上层可统一映射为 4xx/5xx；当前 `uyagin_run_chain_recover` 已接通 recovery 返回 `500`。
- `engine.handle(...)` 外层现在统一包一层 `UyaginObserveFuture`：直接覆盖 request count、状态码、延迟统计与 access log，不要求业务自己手工插 middleware。

### 6. 响应层

- 常见小响应直接在栈上 `hdr` 缓冲内拼出 header，再把 body 追加到同一缓冲，一次 `write_all`。
- 大响应优先走 `writev` 聚合写，避免把 body 复制进 header 缓冲。
- 文件响应优先复用 `sendfile`；不满足平台条件时回退到 nonblocking `read/write` future。
- 若调用方显式选择 `ctx.chunked(...)`，则输出 `Transfer-Encoding: chunked` 并按块 framing。
- `Connection` 根据 `persist` 与 HTTP/1.0 keep-alive 规则输出。

### 7. 可观测性与生产配置

- access log 默认可关闭；开启后按 `sample_every` 采样，使用固定栈缓冲格式化 `method/path/status/latency`，debug 模式额外带 `wrote/persist`。
- 错误 trace 统一走 `uyagin_error_response`，在 `500` 或 debug 模式下输出错误名、请求方法/路径，以及 `@src_path` / `@src_line` builtin 生成的位置。
- `UyaginMetrics` 同时覆盖 request/status/latency/connection 与 arena/frame allocator 指标；其中连接计数在 `engine_run` accept/cleanup 路径维护。`EngineRunOptions.latency_sample_every` 可对 latency bucket 采样，设为 `0` 时关闭延迟桶采样以避免每请求时间 syscall；`metrics_detail_sample_every` 可对 status/latency/arena/frame alloc-free 细项采样，设为 `0` 时只保留 request/heap fallback/connection 等核心计数。
- `UyaginConfig` 统一承载 allocator、limits、run options 与 access log；`EngineRunOptions` 负责 backlog、max connections、buffer cap、request arena cap、timeouts、mode 等生产运行项。

## 性能设计

### 零 GC 与低分配

- Uya 没有 GC，handler 不会遇到 Go 风格 STW 或 GC assist 抖动。
- 请求解析默认用调用方连接缓冲，header/query/path 参数都是切片视图。
- `Engine` 路由表为固定数组，注册后运行期不分配。
- async frame 由 `AsyncFramePool` / `IAllocator` 驱动，可做线程本地池化。

### syscall 压缩

- 小响应合并 header/body，减少一次写 syscall。
- keep-alive 与 pipeline 避免频繁 TCP 建连。
- 当前大响应已走 `writev`，文件响应已接通 Linux x86_64 `sendfile` 优先路径。
- 剩余可继续评估的是 `splice` 与更细粒度的零拷贝静态文件/代理链路，而不是继续维护纯 `read/write` 主路径。

### 调度与并发

- 单线程 reactor：一个 epoll EventLoop 驱动大量连接，避免 goroutine 栈增长与调度成本。
- 多核扩展：N 个 reactor shard，每 shard 独立 listener 或 `SO_REUSEPORT`。
- 连接状态机：每连接一个 `Future<!i32>`，只有显式 `@await` 才挂起。

### 路由优化路线

当前路由是线性扫描，适合 MVP 和小路由表；目标超过 Gin 需要：

- 静态段 radix tree。
- 参数段压缩匹配。
- 方法分表。
- 编译期/启动期预计算 segment hash。
- 热路径避免接口 dispatch，提供泛型 typed handler 版本。

## Uya 语言特性使用

### `@async_fn`

所有 I/O 操作都建模成 `Future<!T>`，不阻塞线程。handler 可自然写成顺序代码：

```uya
const id: &[const byte] = try ctx.param("id");
return try @await ctx.string(Status.OK, id);
```

### `defer`

`uyagin_serve_conn` 用 `defer` 保证 fd 退出时关闭。后续连接池、TLS session、临时文件也应使用 `defer` 明确清理。

### `errdefer`

当前 `@async_fn` 外层返回类型是 `Future<!T>`，编译器不允许直接在函数体使用 `errdefer`。设计上错误路径清理应抽到返回 `!T` 的同步 helper，或在 future poll/上层 wrapper 中使用 `errdefer`。TODO 中会补 `with_request_arena(...) !T` 等 helper，把错误路径 rollback 放在同步错误联合中。

### `drop`

`GinListener.drop` 自动关闭监听 fd。后续计划增加：

- `RequestArena.drop`：重置或归还 per-request arena。
- `ResponseBody.drop`：释放文件/heap body。
- `ConnGuard.drop`：shutdown/close 策略统一化。

### `IAllocator`

`GinContext.allocator` 预留 per-request allocator：

- 小对象从 arena 分配，请求结束整体 reset。
- async frame 从 `AsyncFramePool` 分配，减少 malloc/free。
- JSON/YAML/Form 解析使用同一 allocator，便于限额和观测。

### 泛型

当前 `AsyncHandler` 使用接口，优先可用性；性能版计划增加泛型 API：

```uya
fn GET_T<H: AsyncHandler>(engine: &Engine, pattern: &[const byte], h: H) !void
```

泛型版本可在编译期单态化 handler，避免热路径 vtable dispatch，并为 typed state/context 提供零成本抽象。

### 异常处理机制

- 业务错误：handler 返回 `error.X`，上层统一映射响应。
- 协议错误：解析层返回 `InvalidRequest` / `PayloadTooLarge` 等。
- I/O 错误：fd future 返回 syscall 错误或 `ConnectionClosed`。
- 统一恢复：后续 `Recovery` middleware 捕获错误并写 500，同时保留 `errdefer` 日志/指标。

## 当前实现注意

与最初落地阶段相比，Uya C 后端在 UyaGin 主链路上已经明显收口：`return error.X`、await 之间同步语句、尾部 `return try @await ...`、以及 `error.X -> !T` 实参调用路径都已有回归保护并通过了 `make b` / `make check`。

当前代码里仍保留的保守实现主要是：

- 继续优先使用 `Future<!i32>` / `Future<!usize>`，而不是把主链路改成 `Future<!void>`。
- 响应发送仍拆成 `head-only` / `body` / `chunked` 几个 async helper，由外层同步分发；这是对历史 codegen 漏发语句 / 早退 fallthrough 类问题的防御性保留。
- `uyagin_ready_i32` / `uyagin_ready_usize` 这类 ready helper 仍在源码中；其中一部分历史错误包装辅助已经开始清理，但负值编码错误兼容层整体尚未完全收缩。
- 数组索引和部分指针访问仍偏向显式边界 / helper 写法，以配合安全证明器和稳定 codegen。

这些保守写法会随着编译器与回归继续完善逐步收缩；当前状态可参考 [`compiler_bug_report_2026-04-25_uyagin_async.md`](./compiler_bug_report_2026-04-25_uyagin_async.md)。
