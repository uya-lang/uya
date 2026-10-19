# Async Runtime 共享语义矩阵

**最后更新**：2026-10-19
**范围**：Linux + C99 主链路；HTTP/DNS/TLS/`async_compute`/`Scheduler` 是否共享同一套稳定 async runtime 语义。

> **核对头（2026-10-19）**：本文写于 2026-06-18，正文里"统一 smoke 尚未落地""`A/AAAA` 并发聚合未完成""连接复用/keep-alive 不在当前语义内""TLS 会话复用缺失"四条已被后续提交推翻，本轮按源码与回归逐条改正：
>
> | 旧结论（2026-06-18） | 2026-10-19 实际状态 | 证据 |
> |---|---|---|
> | 缺少统一共享 runtime smoke | **已落地**：`tests/verify_async_shared_runtime_matrix.sh` 串联 `test_std_async_scheduler.uya` / `test_async_shared_runtime_semantics.uya` / `test_async_compute_types.uya` / `test_std_dns_async_transport.uya` / `test_http1_async_client.uya` / `test_https_bridge_safety.uya`；`tests/verify_async_production_smoke.sh` 为四段串联生产闸门 | 两个脚本均存在（2026-06-21） |
> | DNS `A/AAAA` 并发聚合未完成 | **已完成** | `dns_client_query_all_async()`（`lib/std/net/dns.uya:1826`） |
> | HTTP 连接复用/keep-alive 不在语义内 | **已落地** | `Http1AsyncPool` + `http1_async_pool_take_raw/put_raw`（`lib/std/http/http1_async.uya:226-261`，取用 `:1199`、存回 `:1413`） |
> | TLS 会话复用缺失 | **已落地**（会话 ID 路径；session ticket 未做） | `tls_session_cache_store/lookup`、`handshake_set_resume_session_id`、`handshake_session_resumed`（`lib/tls/ssl/handshake.uya:174/221/360/377`） |
> | `https_handshake_async` 缺真实 pending/ready 回归 | **已有回归** | `tests/test_tls_async_runtime_io.uya:151-156`（`https_handshake_async` + `expect_pending_read_interest`） |
> | 平台后端只有 Linux | **macOS kqueue 已落地**（`lib/std/async_event.uya`，kqueue 失败回退 `poll(2)`）；Windows IOCP 仍缺 | `KQUEUE_EVFILT_*`（`:24-28`）、`register()` 的 `std.cfg` 分支（`:617-623`） |
>
> 下方正文保留原结构，`未落地`类旧句已就地标注。

**口径**：本文是共享 runtime 语义的对齐矩阵，不是完成证明。共享 smoke 已于 2026-06 落地（见核对头第一行），但单项分散回归仍不能单独代表"生产完成"。

## 共同语义基线

当前可视为共享的 runtime 基线只包括源码中已经落到同一批类型和接口的部分：

- `lib/std/async.uya`：`Future<T>` / `Poll<T>` / `Waker` / `AsyncReader` / `AsyncWriter` / `AsyncFd`。
- `lib/std/async_event.uya`：`EventLoop` 接口与 `LinuxEpoll` 实现（Linux 走 epoll；macOS 在同一结构体内走 kqueue，kqueue 创建失败回退 `poll(2)`；Windows 无后端）。
- `lib/std/async_scheduler.uya`：`Scheduler`、`TaskQueue<T>`、`scheduler_run_*_with_event_loop` 和 `scheduler_run_task_queue_with_event_loop<T>`。
- `lib/std/thread.uya`：`async_compute<T>` 返回 `Future<!T>`，运行中通过 `Waker` 的 eventfd / I/O interest 语义接入调度器。

统一语义口径：

- `Poll.Pending` 表示 future 还不能产出结果；业务成功或失败都必须回到 `Poll.Ready(!T)`。
- I/O future 在 `EAGAIN` / `EWOULDBLOCK` 时通过 `Waker.wait_readable(fd)` 或 `Waker.wait_writable(fd)` 登记关注；同一 `Waker` 可以在一轮 poll 里登记**多个 fd**（有界槽表 `WAKER_IO_SLOT_MAX = 4`），同一个 fd 的读+写关注会合并成 `READWRITE`。
- `Scheduler` 在 pending 后同步注册 `eventfd + 全部已登记 io fd`，由 `EventLoop.poll()` 唤醒后再 poll future；对「上轮注册、本轮不再关注」的 fd 做差集注销，避免陈旧注册在 fd 复用后误唤醒。
- 取消是协作式语义：`TaskQueue.cancel()` / `Waker.cancel()` 只设置取消位，future 必须在 `poll()` 中读取 `waker.is_cancelled()` 并返回 `error.Cancelled`。
- 清理语义由调度层负责关闭 eventfd、注销 I/O fd、清理 slot；具体 future 仍负责自身 fd 或任务资源释放。

## 链路矩阵

| 链路 | 当前入口 | 已共享的 runtime 资源 | 已覆盖语义 | 缺口 |
|------|----------|------------------------|------------|------|
| `Scheduler` | `scheduler_run_with_event_loop<T>`、`scheduler_run_task_queue_with_event_loop<T>` | `Future<!T>`、`Waker`、`EventLoop`、`LinuxEpoll`、async frame allocator | pending 后注册 I/O interest，eventfd 跨线程 wake，inline repoll，完成/取消时清理注册资源 | `TaskQueue<T>` 默认队列已自动增长；frame pool backing buffer 与 inline repoll 默认策略已支持实例配置和 `UYA_SCHEDULER_FRAME_BUFFER_BYTES` / `UYA_SCHEDULER_INLINE_REPOLL_LIMIT`；还缺跨 HTTP/DNS/TLS/`async_compute` 同队列 smoke |
| `async_compute<T>` | `async_compute<T>(&ThreadPool, fn, arg)` | `Future<!T>`、`Waker`、eventfd wake、线程池结果 fd | 排队/运行/one-shot 路径可返回 pending；取消最终以 `error.Cancelled` 回到调用侧；已覆盖多标量类型 | worker/pending/task slot 仍有固定容量；运行中取消不抢占计算；未与 HTTP/DNS/TLS 同一 `TaskQueue` 组合验收 |
| HTTP/1.1 async client | `http1_request_async`、`http1_async_get`、`http1_async_post`、`http1_request_stream_async` | `Future<!Http1AsyncResponse>`、`AsyncFd`、`Waker.wait_*`、`LinuxEpoll` deadline block_on、`Http1AsyncPool` | nonblocking connect/read/write 走 readiness；请求头 buffer 已改为按需堆分配；loopback 回归覆盖主路径；**keep-alive 连接池已落地**（`http1_async_pool_take_raw/put_raw`，`lib/std/http/http1_async.uya:226-261`） | 同步封装仍单独创建 `LinuxEpoll` 并 block_on；未证明与外部 `Scheduler` task queue 共享调度 |
| DNS async transport | `lib/std/net/dns.uya` 中 UDP/TCP transport future；测试入口 `test_std_dns_async_transport.uya` | `Future<!usize>`、`Waker.wait_readable/wait_writable`、`block_on_with_event_loop`、`LinuxEpoll` | UDP send/recv 与 TCP fallback 均在 would-block 时 pending；Ready(error) 后 fallthrough 到 TCP 的状态机语义有专门回归；**`A/AAAA` 并发聚合已落地**（`dns_client_query_all_async()`，`lib/std/net/dns.uya:1826`） | 与 HTTP/TLS/`async_compute` 同调度器组合未验收；fd/packet buffer 容量仍有固定边界 |
| TLS / HTTPS | `lib/tls/https.uya`、`tests/test_https_loopback.uya`、`tests/test_tls_async_runtime_boundary.uya`、`tests/test_tls_async_io_future.uya` | UyaGin handler bridge 复用 `Future` / `@async_fn`；TLS leaf I/O 另有 `https_read_some_async`、`https_write_all_async`、`https_handshake_async` 返回 `Future<!usize>` 并通过 `Waker.wait_readable/wait_writable` 记录 fd interest（`lib/tls/https.uya:430/437/444`）；**TLS 1.2 会话复用已落地** | `test_https_loopback.uya` 只证明 TLS -> UyaGin async handler 桥接可运行；`test_tls_async_runtime_boundary.uya` 结构性区分 handler bridge 与 TLS I/O future；`test_tls_async_io_future.uya` 覆盖 read pending/ready、LinuxEpoll wake 与 write ready；`test_tls_async_runtime_io.uya:151-156` 覆盖 `https_handshake_async` pending/read-interest；`test_tls_session_resumption.uya` 覆盖会话复用 | session ticket（RFC 5077）未做；TLS 尚未与 HTTP/DNS/`async_compute` 纳入同一 `TaskQueue` / `EventLoop` 组合 smoke |

## 最小验证矩阵草案

> 2026-10-19 状态：本表 6 行**全部已有对应测试文件**；统一串联入口为 `tests/verify_async_shared_runtime_matrix.sh`（逐行注解见括号）。

后续实现应优先补一个 Linux + C99 smoke，避免继续依赖分散测试推断共享语义：

| 目标 | 建议测试 | 验证命令 |
|------|----------|----------|
| `Scheduler` + `async_compute` 共享 eventfd wake 与取消 | 一个 `TaskQueue<usize>` 同时推入可取消 `async_compute` 和一个手写 pending-then-ready future | `../uya/bin/uya test --c99 tests/test_async_runtime_shared_semantics.uya` |
| `Scheduler` + AsyncFd/HTTP readiness | 在同一 `LinuxEpoll` 上运行 pipe/socket AsyncFd future 或 HTTP loopback future | `../uya/bin/uya test --c99 tests/test_async_runtime_shared_semantics.uya` |
| DNS TCP fallback 状态机保持 `Ready(error)` fallthrough 语义 | 保留 `test_async_transport_fallthrough.uya`，并把真实 DNS async transport 纳入共享调度组合 | `../uya/bin/uya test --c99 tests/test_std_dns_async_transport.uya` |
| TLS handler bridge 与 TLS I/O future 边界显式化 | `test_https_loopback.uya` 只能证明 handler bridge；`test_tls_async_runtime_boundary.uya` 结构性检查 TLS async leaf primitive 与 `Waker` interest；`test_tls_async_io_future.uya` 行为检查 TLS read/write future 的 pending/ready 与 `LinuxEpoll` wake | `../uya/bin/uya test --c99 tests/test_https_loopback.uya`；`../uya/bin/uya test --c99 tests/test_tls_async_runtime_boundary.uya`；`../uya/bin/uya test --c99 tests/test_tls_async_io_future.uya` |
| TLS handshake/read/write async I/O | 新增 TLS I/O future，在 would-block 时返回 `Poll.Pending` 并通过 `Waker.wait_readable/wait_writable` 注册 fd interest | `../uya/bin/uya test --c99 tests/test_tls_async_runtime_io.uya` |
| TLS 加入统一 runtime smoke | 在同一 `TaskQueue` / `LinuxEpoll` 中组合 TLS pending/ready、HTTP/DNS readiness 与 `async_compute` eventfd wake | `../uya/bin/uya test --c99 tests/test_async_runtime_shared_semantics.uya` |

## TLS awaitable I/O 叶子 API 合约

TLS/HTTPS 接入共享 runtime 时只允许把最底层会阻塞的 fd 边界做成 awaitable 叶子；TLS 记录解析、握手状态推进和 HTTP handler bridge 继续保持协议语义，不直接拥有 `EventLoop` 或 `Scheduler`。叶子 API 固定为：

| API | 返回类型 | pending interest | Ready 成功语义 |
|-----|----------|------------------|----------------|
| `https_read_some_async(fd, out, out_max)` | `Future<!usize>` | 底层 `https_read_some` 命中 `ReadWouldBlock` 时调用 `waker.wait_readable(fd)`，然后返回 `Poll.Pending` | 返回本次读到的密文字节数；`out` / `out_max` 生命周期必须覆盖 future 完成或取消 |
| `https_write_all_async(fd, src, src_len)` | `Future<!usize>` | `sys_write` 命中 `EAGAIN` / `EWOULDBLOCK` / `EINPROGRESS` / `EALREADY` 时调用 `waker.wait_writable(fd)`，然后返回 `Poll.Pending` | 完成后返回累计写入字节数；future 内部保存偏移，重复 poll 不得重写已完成前缀 |
| `https_handshake_async(fd, ctx, role)` | `Future<!usize>` | handshake 读边界命中 `ReadWouldBlock` 时调用 `waker.wait_readable(fd)`；后续如果 handshake 状态机暴露写阻塞，应在写边界调用 `waker.wait_writable(fd)` | 握手完成返回 `0`；`role` 仅允许 `HS_ROLE_CLIENT` / `HS_ROLE_SERVER` |

错误语义：

- 同步 helper 的 `ReadWouldBlock` / 写 would-block 只用于 leaf 内部判断；async API 对调用者不得以 `Ready(error.ReadWouldBlock)` 暴露 pending，而必须返回 `Poll.Pending` 并注册 fd interest。
- EOF、短写为 0、TLS alert/认证失败、handshake 状态机失败和不可恢复 syscall 错误必须返回 `Poll.Ready(error.ConnectionClosed)` 或后续更精确的 TLS 错误；业务失败仍属于 `Ready(!T)`，不能伪装为 pending。
- `EINTR` 在 leaf 内部重试，不改变 `Waker` interest。
- `https_handshake_async` 不拥有 `SslContext`，不能在错误路径释放调用者持有的证书、握手状态或记录层缓冲。

取消与清理语义：

- 每个 TLS leaf future 的 `poll()` 开头必须检查 `waker.is_cancelled()`；观察到取消后返回 `Poll.Ready(error.Cancelled)`，不得继续推进 TLS 状态机或读写 fd。
- `release()` 只清理 future 自身分配的 async frame 或临时缓冲；不关闭 `fd`，不释放调用者传入的 `out` / `src` / `SslContext`。
- `Scheduler` 负责在完成或取消后注销 `EventLoop` 中的 fd interest、关闭 eventfd 并清理 task slot；TLS leaf 不直接调用 `EventLoop.deregister()`。
- pending 后下一轮 poll 必须重新执行真实 syscall 或 handshake step；禁止只因为上轮注册过 interest 就直接返回 Ready。

## 当前结论

> **2026-10-19 更新（推翻 2026-06-18 原文，原文以引用块保留在下）**

当前状态：

- HTTP、DNS、`async_compute`、`Scheduler` 已在源码层共享 `Future` / `Poll` / `Waker` / `LinuxEpoll` 核心语义，并已有统一串联回归 `tests/verify_async_shared_runtime_matrix.sh`（6 个子测试）与 `tests/verify_async_production_smoke.sh`。
- TLS/HTTPS：handler bridge 与 TLS I/O future 的边界仍由 `test_tls_async_runtime_boundary.uya` 结构性区分；read / write / handshake 三条 async leaf 均有 pending/ready 回归（`test_tls_async_io_future.uya`、`test_tls_async_runtime_io.uya:151-156`）；TLS 1.2 会话复用已由 `test_tls_session_resumption.uya` 覆盖。
- 仍未收口：Windows IOCP 后端、TLS session ticket（RFC 5077）、`ThreadPool` 真动态扩缩容。

同步到其他阶段性文档时，应使用以下结论句：

- 分散回归已经证明若干局部主路径可用。
- 共享 runtime 主链路已有统一矩阵入口（`tests/verify_async_shared_runtime_matrix.sh`），但"生产完成"仍需 Windows 后端与剩余动态资源边界清零。
- TLS I/O 叶子已接入 `Waker` / `EventLoop`（不再是显式缺口）；未做的只有 session ticket。

> **历史结论（2026-06-18，已过期，保留备查）**：HTTP、DNS、`async_compute` 和 `Scheduler` 已经在源码层共享 `Future` / `Poll` / `Waker` / `LinuxEpoll` 的核心语义，但还没有一个统一回归同时证明这些链路在同一 scheduler/event loop 下工作。TLS/HTTPS 已经能用专门边界测试区分 handler bridge 与 TLS I/O future，且 read/write async leaf 已有 pending/ready 与 `LinuxEpoll` wake 回归；但 `test_https_loopback.uya` 本身仍不能作为 TLS I/O 接入 `Waker` / `EventLoop` / `Scheduler` 的证明，TLS handshake 行为回归和跨 HTTP/DNS/`async_compute` 的统一 smoke 仍待补齐。因此第 9 行总目标不能标记完成。
