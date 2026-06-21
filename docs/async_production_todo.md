# Uya 异步量产 TODO

**最后更新**：2026-06-21（2026-04 历史收口记录保留；补充当前生产收口口径，避免把旧主链路结论误读为共享 async runtime 矩阵已完成）
**目标范围**：Linux + C99 后端 + `@async_fn` / `@await` / `Future` / `Poll` / `Waker` + `AsyncFd` / `LinuxEpoll`，优先保障 DNS、HTTP/1.1、HTTPS 客户端主链路达到可量产状态。

> **2026-06-17 注意**
>
> 本文档是 2026-04 阶段的历史量产收口记录，不再单独代表当前 async 生产化目标的完成定义。
> 当前权威 TODO 请看：[todo_async_full_language_dynamic_resources.md](todo_async_full_language_dynamic_resources.md)。
> 新目标额外要求：
> 1. `@async_fn` 支持完整 Uya 函数体语法，而不只是若干已收口形态。
> 2. async 相关资源改成动态或可配置，而不是继续依赖 `16/32/64/512/1024` 这类固定容量。
> 3. HTTP、DNS、TLS、`async_compute` 与 `Scheduler` 必须被同一套共享 runtime 语义矩阵验证，不能只凭单项主链路测试通过宣称“已完全量产”。
> 4. 文档口径必须与当前源码和验证闸门一致，不能仅凭本文历史结论宣称“已量产”。
>
> 2026-06-21 同步：
> - 旧文档里把 `LinuxEpoll=1024`、`TaskQueue=64`、descriptor/meta 表固定上限写成“当前阻塞”的表述已经过时，见下方“当前同步说明”。
> - 当前真正的生产阻塞判断，请回到 `docs/todo_async_full_language_dynamic_resources.md`、`docs/async_status_matrix.md` 与 `docs/async_runtime_semantics_matrix.md`。

## 当前同步说明（2026-06-21）

- 不应再把 `LinuxEpoll=1024` 当作当前产品上限。`lib/std/async_event.uya` 中 `LinuxEpoll` 仍以 `1024` 作为兼容默认初始容量，但 slot / lookup / poll scratch 存储在满载时会自动扩容。
- 不应再把默认 `TaskQueue=64` 当作固定功能上限。`lib/std/async_scheduler.uya` 的 `task_queue_new<T>()` 以 `64` 起步，但默认队列会在 `push()` 时 `grow_slots()`；只有 `task_queue_new_with_capacity<T>()` 才把容量当成调用方显式上限。
- 不应再把 async frame descriptor/meta 表写成固定 `512`。`src/checker/async_frame_meta.uya` 已支持 meta 扩容，`src/codegen/c99/main.uya` 现按 `async_frame_meta_count` 真实数量发射 `_uya_async_frame_descriptors`。
- 不应再把 direct err-union await 或本文提到的 nested future 路径写成当前未解阻塞。对应路径已有 `tests/test_async_await_direct_err_union.uya`、`tests/test_async_nested_future_poll.uya` 与 `tests/verify_async_nested_future_boundary.sh` 正向回归。
- 当前仍未完成的生产收口，应回到 `docs/todo_async_full_language_dynamic_resources.md`、`docs/async_status_matrix.md` 与 `docs/async_runtime_semantics_matrix.md`：完整函数体语法矩阵、共享 runtime 统一验收，以及真实仍存在的 fixed scratch/fallback/compat 上限需要分别审计。

## 量产定义（历史阶段口径）

以下 `[x]` 仅表示 2026-04 阶段针对 DNS / HTTP / HTTPS 主链路和当时已知 async lowering 缺口的验收结论。它们不覆盖完整 Uya 函数体语法矩阵、动态资源目标、回退路径收口，也不覆盖 HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享 runtime 生产收口矩阵；当前是否完成必须回到 `docs/todo_async_full_language_dynamic_resources.md` 与 `docs/async_status_matrix.md` 判断。

- [x] `@async_fn` 在常见复杂控制流中稳定：`if/else if`、`while`、`for`、嵌套分支、await 间同步语句、提前返回错误。
- [x] 异步运行时在 fd 复用、短连接、服务端提前关闭、注册/反注册重复调用等边界下不崩溃、不忙等、不泄漏 fd。
- [x] DNS、HTTP/1.1、HTTPS 主链路有端到端回归，并能连续多轮通过。
- [x] release 闸门清晰：`make b`、`make check`、`make release-dirty`、关键网络测试通过或在无网络环境下明确 skip。
- [x] 已知限制被文档化：跨平台 async 后端、连接池、TLS 会话复用、DNS A/AAAA 并发可作为量产后二阶段。
  - 见 [P2：量产后二阶段能力](#p2量产后二阶段能力)。

## P0：编译器 async lowering 稳定化（已完成）

- [x] 修复复杂状态机 lowering 错位导致的运行期 SIGSEGV。
  - 关联：`buglist.md` 中 `@async_fn` 复杂状态机 lowering 后行为错位导致 SIGSEGV。
  - 重点形态：`else if` 分支内 await、分支内修改变量、分支后继续使用变量。
  - 验收：`tests/test_http1_async_client.uya` 中 chunked loopback 路径不再 SIGSEGV。
  - 验证：`tests/test_async_else_if_await.uya`、`tests/test_http1_async_client.uya` 通过。

- [x] 转正并修复 await 循环间同步语句丢失。
  - 关联：`docs/todo_async_loop_await.md` 的 Bug B。
  - 重点形态：读 header 循环后执行同步 parse/malloc/assign，再进入读 body 循环。
  - 验收：`tests/test_async_bug_b_sync_between.uya` 通过。

- [x] 修复分裂点附近局部变量与表达式提升问题。
  - 关联：`docs/todo_async_loop_await.md` 的 Bug D。
  - 覆盖：if 内局部变量、切片表达式、嵌套循环、`break` / `continue` resume 后错位。
  - 验收：`tests/test_async_bug_d_nested_block.uya` 通过，覆盖嵌套局部变量、`break` / `continue` resume、切片表达式与局部变量 `s` 的 poll state 指针命名冲突。

- [x] 修复 `@async_fn fn ... Future<!T>` 内直接 `return error.X` 的类型检查。
  - 关联：`buglist.md` 中 `@async_fn` 中 `return error.X` 报错。
  - 验收：新增 `tests/test_async_return_error_direct.uya`，覆盖 `Future<!i32>` no-await / after-await 直接 `return error.X`。
  - 后续：`Future<!void>` 直接错误返回还依赖 `Poll_err_void` / `Future_err_void` / `block_on<void>` 等 void monomorph 支持，单独纳入后续泛型特化工作。

- [x] 修复 `@async_fn` 变量提升 bug（局部变量跨 await 点未被正确提升为状态机字段）。
  - 关联：`docs/async_production_todo.md` 2026-04-11 记录的阻塞问题。
  - 修复提交：`06e2b206 fix(codegen): async local hoisting limit and nested block init`
  - 验收：`lib/std/http/http1_async.uya` 中 `http_check_deadline(deadline_ms)` 调用全部启用，`test_http1_async_client.uya` 通过。

- [x] 修复复合表达式中的 `try @await` lowering/codegen。
  - 典型形态：`total = total + (try @await foo())`、`return 1 + (try @await foo())`。
  - 修复：将复合表达式内的 `try @await` 纳入 async transform 的回放/替换路径，并补齐 `@await` 结果类型预注册与重复诊断去重。
  - 验收：`tests/test_async_compound_try_await.uya` 通过。

## P1：异步运行时硬化（已完成）

- [x] 将 `LinuxEpoll` 注册状态显式化。
  - 位置：`lib/std/async_event.uya`。
  - 实现：
    - 添加 `SLOT_STATE_EMPTY` / `SLOT_STATE_REGISTERED` 显式状态常量
    - 添加 `slot_generations` 数组防止 fd 复用混淆
    - 添加 `next_generation` 全局代际计数器
    - 添加 `find_slot`、`alloc_slot`、`init_slot`、`clear_slot` 方法
  - 验收：重复 register、重复 deregister、fd 关闭后复用、短连接快速创建销毁均不触发 `ENOENT` / `EEXIST` 异常路径失控。

- [x] 修复 `EPOLL_CTL_MOD` 与 `EPOLL_CTL_DEL` 常量错位。
  - 位置：`lib/libc/syscall.uya`、`lib/syscall/linux.uya`。
  - 根因：`EPOLL_CTL_MOD` 被错误定义为 `2`（实际应为 `3`），`EPOLL_CTL_DEL` 被错误定义为 `3`（实际应为 `2`）。这导致 `LinuxEpoll.register` 在尝试 `MOD` 时实际执行了 `DEL`，`deregister` 在尝试 `DEL` 时实际执行了 `MOD`（events=0），造成 fd 在 epoll 中残留或事件丢失，引发 async 网络测试 timeout/失败。
  - 修复：交换两者定义，恢复为内核正确值（`ADD=1`、`DEL=2`、`MOD=3`）。
  - 验收：`make check` 全量通过，`test_http1_async_client`、`test_std_dns_async_transport`、`test_std_async_event_fd_reuse` 均通过。

- [x] 修复 `LinuxEpoll.deregister` 使用 `null` 作为 epoll_event 指针。
  - 位置：`lib/std/async_event.uya`。
  - 修复：`deregister` 改用 `sys_epoll_ctl_del`（内部构造 dummy `EpollEvent` 再传入 syscall），避免在部分路径下触发 `EFAULT` 或 `EINVAL`。
  - 验收：`test_std_async_event.uya`、`test_std_async_event_fd_reuse.uya` 不再因 deregister 失败而返回错误。

- [x] 增加 fd 复用与短连接压力回归。
  - 新增测试：`tests/test_std_async_event_fd_reuse.uya`
  - 覆盖：
    - `fd_reuse_basic`：基本注册/写入/poll/注销流程
    - `fd_reuse_after_close`：socket close 后新 fd 复用旧编号
    - `rapid_register_deregister`：100 次快速注册/注销压力测试
    - `two_fds_sequential`：顺序测试两个 fd 的独立性
  - 验收：所有测试通过 `test_std_async_event`、`test_async_fd`、`test_std_async_scheduler`、`test_std_async_event_fd_reuse`。

- [x] 明确 `Waker` 单 fd 语义，决定是否扩展。
  - 当前策略：量产第一版保持单 fd，文档化"单个 Future 同时只能挂一个 I/O interest"。
  - `block_on_with_event_loop` 在每次 poll 前都会 `w.reset()` / `w.clear_io_interest()`，因此单 interest 足够覆盖当前 HTTP/TLS 的 sequential 读写模式。
  - 若后续需要同时关注读写，则扩展为小数组或链表 interest。
  - 验收：`docs/std_async_design.md` 与实际实现一致。

- [x] 检查状态机堆分配与 fd 生命周期释放。
  - 覆盖：Ready、Error、Pending 后关闭、socket EOF、TLS handshake 失败。
  - 验收：`make check` 全量通过；30 分钟长时压测（`benchmarks/http_bench_async_epoll.uya` + `wrk -t4 -c100 -d1800s`）RSS 2460 KB / FD 105 完全平稳，无泄漏、无 use-after-free。
  - 备注：当前默认路径已迁移为统一 `AsyncFramePool` + caller-owned inline，热路径不再直连 `malloc/free`；`release` 通过 vtable 递归保证 child future 先释放。详见 `docs/todo_async_frame_allocation.md`。

## P1：DNS / HTTP / HTTPS 主链路收敛

- [x] 重新评估 `dns_client_query_all_async` 的手工状态机。
  - 当前状态：`dns_client_query_all_any_async` 已迁移为 `@async_fn`；`DnsTcpFuture` / `DnsUdpFuture` 底层 I/O 状态机保留手工实现，上层组合逻辑已 `@async_fn` 化。
  - 验收：`TC=1` TCP fallback、默认 `ANY`、A / AAAA 路径连续多轮通过。

- [x] 恢复并稳定 HTTP/1.1 chunked / read-until-eof 路径。
  - 位置：`lib/std/http/http1_async.uya`。
  - 当前状态：
    - `http1_request_async` 使用 `parse_response_meta` 拒绝 chunked 编码（返回 `HttpChunkedNotSupported`）。
    - 流式接口 `http1_request_streaming` / `http1_request_stream_async` 使用 `parse_response_meta_allow_chunked` 支持 chunked。
    - 同步读取 chunked body 接口 `http1_read_chunked_body_sync` 已可用（避开 async lowering 问题）。
  - 验收：chunked loopback、content-length、read-until-eof 三条路径均有测试。

- [x] 给 HTTP/DNS/TLS 主链路增加 timeout 策略。
  - 优先级：connect timeout、read timeout、write timeout、DNS query timeout、TLS handshake timeout。
  - 采用 deadline-based 策略：`deadline_ms = now_ms() + timeout_ms`，在每个 I/O 边界检查是否过期。
  - 实现位置：`lib/std/http/http1_async.uya`、`lib/std/async_scheduler.uya`、`lib/tls/https.uya`。
  - 2026-04-12 更新：`@async_fn` 变量提升 bug 已修复，`http1_request_async` 中所有 `http_check_deadline` 调用已启用。
  - 验收：连接拒绝、服务端不响应、服务端半关闭不导致无限等待或 busy-wait。

- [x] 完善 HTTPS 生产限制。
  - 证书验证框架已实现：
    - `lib/tls/x509/trust_store.uya`：系统根证书存储加载模块
    - `lib/tls/x509/cert.uya` 有效期字段和验证函数框架
    - 错误类型：`TlsCertificateVerificationFailed`, `TlsCertificateExpired`, `TlsCertificateNotYetValid`
  - `https_get()`：生产环境安全（默认启用证书验证）
  - `https_get_insecure()`：测试用途（跳过验证）
  - 证书有效期 ASN.1 时间解析补齐或明确标记为未完成。
  - chunked 响应支持或公开 API 明确返回 `HttpChunkedNotSupported`。
  - 验收：`test_https_production`、`test_https_real_site`、`test_https_loopback` 行为一致。

## P2：量产后二阶段能力（2026-04 历史口径）

- [ ] DNS A / AAAA 并发聚合，减少高 RTT 下延迟。
  - 当前状态：`dns_client_query_all_any_async` 采用顺序 `A -> AAAA` 查询，功能正确但延迟未优化。
- [ ] HTTP 连接池与 keep-alive 复用。
- [ ] TLS 会话复用。
- [ ] macOS kqueue / Windows IOCP 后端。
- [ ] 更细粒度性能优化，建立每 release 的 async benchmark baseline。

## 验收清单（2026-04 历史验收）

- [x] `make b` 自举一致。
- [x] `make check` 关键子集通过（`test_std_async_event`、`test_async_fd`、`test_std_async_scheduler`、`test_std_dns_async_transport`、`test_http1_async_client`）。
- [x] `make check` 全量通过（2026-04-14 `@frame(foo)` + pinned 语义实现后）。
- [x] `make release-dirty` 核心 async 网络测试通过；无外网环境下网络测试明确 skip。
- [x] `./tests/run_programs_parallel.sh --uya --c99 test_async_bug_b_sync_between.uya` 通过。
- [x] `./tests/run_programs_parallel.sh --uya --c99 test_http1_async_client.uya` 通过。
- [x] `./tests/run_programs_parallel.sh --uya --c99 test_std_dns_async_transport.uya` 连续多轮通过。
- [x] `./tests/run_programs_parallel.sh --uya --c99 test_std_async_event_fd_reuse.uya` 通过（新增 fd 复用压力测试）。
- [x] 关键测试通过：`test_async_fd`、`test_std_async_event`、`test_std_async_scheduler`、`test_std_dns`、`test_http_server`、`test_epoll_server`、`test_https_loopback`、`test_https_real_site`、`test_raw_tls`。
- [x] HTTP async loopback 稳定性：30 分钟压测通过（`benchmarks/http_bench_async_epoll.uya` + `wrk -t4 -c100 -d1800s`），RSS 2460 KB / FD 105 完全平稳，无崩溃、无 busy-wait、无泄漏。
- [x] `docs/std_async_design.md`、`docs/todo_async_loop_await.md`、`buglist.md`、`docs/async_production_todo.md` 与最终状态同步。

## 推进顺序

1. ~~先关闭 P0 lowering：SIGSEGV、Bug B、Bug D、`return error.X`。~~ ✅ 已完成
2. ~~再硬化 `LinuxEpoll` / `Waker` / 生命周期释放。~~ ✅ 已完成（LinuxEpoll 显式状态机 + fd 复用测试 + epoll 常量修复 + deregister 修正）
3. ~~收敛 DNS / HTTP / HTTPS 主链路，移除或正式化绕过方案。~~ ✅ 已完成（超时策略启用，变量提升 bug 修复）
4. ~~压测、release 闸门、文档同步。~~ ✅ 已完成

## 当前状态摘要（截至 2026-04-16）

**已完成**：
- ✅ P0 编译器 async lowering 稳定化全部完成（含变量提升 bug 修复）
- ✅ LinuxEpoll 显式状态机（SlotState + generation）
- ✅ **修复 epoll_ctl 常量错位**：`EPOLL_CTL_MOD` 与 `EPOLL_CTL_DEL` 在 `lib/libc/syscall.uya`、`lib/syscall/linux.uya` 中被错误互换，现已恢复为内核正确值
- ✅ **修复 `deregister` 实现**：由 `sys_epoll_ctl(..., null)` 改为 `sys_epoll_ctl_del(...)`，避免 `EFAULT`/`EINVAL`
- ✅ **增加 `block_on_with_event_loop` 空等 workaround**：当 `@async_fn` 状态机在 await transition 时返回 Pending 但未设置 I/O interest，`block_on` 以 `loop.poll(1)` 重试，避免 1000ms 空等，同时防止并行测试时 CPU 忙等
- ✅ fd 复用与短连接压力回归测试
- ✅ HTTP/1.1 主链路（content-length、read-until-eof、chunked 同步读取 + chunked header 异步流式读取）
- ✅ HTTPS 生产环境基础能力（证书验证框架、系统根证书加载）
- ✅ DNS 异步查询（上层 `@async_fn` 化，底层保留手工 I/O 状态机）
- ✅ 核心 async 运行时（`LinuxEpoll`、`Waker`、`AsyncFd`、`AsyncFramePool`）
- ✅ **跨线程 wake/eventfd 已打通**：`Waker` 可绑定/关闭 `eventfd`，`Scheduler` 在 `Pending` 时同步注册 `eventfd + io fd`；`async_compute` worker 与外部 wake 现可直接唤醒主 `EventLoop`
- ✅ **复合表达式 `try @await` 已转正**：赋值 RHS 与 return 表达式已纳入通用 lowering，回归 `tests/test_async_compound_try_await.uya` 通过
- ✅ **结构体/接口 async 方法已打通**：结构体内部方法、外部方法块与 interface 方法签名均可写 `@async_fn`；direct call 与 vtable 分派主链路回归见 `tests/test_async_method_interface.uya`
- ✅ **通用泛型 `TaskQueue<T>` 已完成**：`TaskQueue<T>`、`TaskQueue_i32`、`TaskQueue_u32` 与 `scheduler_run_task_queue_with_event_loop<T>` / typed wrappers 已落地，`test_std_async_scheduler.uya` 与 `test_async_multi_fd_concurrent.uya` 已覆盖
- ✅ **协作式完整取消语义已完成**：`Waker.cancel()/is_cancelled()`、`TaskQueue.cancel()`、slot/eventfd/I/O deregister 统一清理；`async_compute` 对未启动/排队/one-shot 路径立即取消，对已运行共享槽任务在结果回收时稳定返回 `error.Cancelled`
- ✅ HTTP/DNS/TLS timeout 策略实现并启用（`http_check_deadline` 已取消注释）
- ✅ `make check` 全量通过

**已知限制（已文档化，纳入 P2）**：
- 跨平台 async 后端（macOS kqueue / Windows IOCP）
- HTTP 连接池与 keep-alive 复用
- TLS 会话复用
- DNS A/AAAA 并发聚合（当前为顺序查询）

---

## 超时策略实现详情（2026-04-12）

### 设计

采用 **deadline-based** 超时策略：请求开始时计算绝对截止时间 `deadline_ms = now_ms() + timeout_ms`，在每个 I/O 边界检查 `now >= deadline_ms`。`timeout_ms = 0` 表示不超时（无限等待）。

### 已修改文件

#### 1. `lib/std/http/http1_async.uya`（主要改动）

- 新增 `export error HttpTimeout;`
- 新增 7 个本地时间辅助函数（避免跨模块 `time.xxx` 在 `@async_fn` 中的编译器 bug）：
  - `http_now_ms() !u64` — 基于 `sys_gettimeofday`
  - `http_deadline_after_ms(timeout_ms) !u64`
  - `http_deadline_expired(deadline_ms) !bool`
  - `http_deadline_remaining_ms(deadline_ms) !i32`
  - `http_deadline_expired_or_false(deadline_ms) bool` — 出错返回 false
  - `http_deadline_remaining_or_neg1(deadline_ms) i32` — 出错返回 -1
  - `http_check_deadline(deadline_ms) !void` — 过期返回 `error.HttpTimeout`
- `Http1ConnectFuture` 增加 `deadline_ms: u64` 字段，`poll()` 中检查超时
- 修改函数签名（增加 `timeout_ms: u32`）：
  - `http1_request_async(req, timeout_ms)` — `@async_fn`
  - `http1_request_blocking(req, timeout_ms)`
  - `http1_async_get(url, req, timeout_ms)` — `@async_fn`
  - `http1_async_post(url, req, timeout_ms)` — `@async_fn`
- `http1_connect_for_host_future(host, port, deadline_ms)` — DNS 查询超时从剩余 deadline 派生
- `http1_request_blocking` — 使用 `block_on_with_event_loop_deadline`
- ✅ `http1_request_async` 中的 `try http_check_deadline(deadline_ms)` 调用已启用（行 845、854、910、929）

#### 2. `lib/std/async_scheduler.uya`

- 新增本地时间辅助函数：`sched_now_ms()`, `sched_deadline_expired()`, `sched_deadline_remaining_ms()`
- 新增 `block_on_with_event_loop_deadline<T>(loop, f, timeout_ms, deadline_ms)` — 带总超时保护的 block_on
- `block_on_with_event_loop` 保持独立实现（不调用 deadline 版本），避免泛型实例化顺序 bug
- **workaround 新增**：当 `w.has_io_interest()` 为 false 时，直接 `continue` 而非 `loop.poll(timeout_ms)`，避免 `@async_fn` 状态机 transition 时的空等

#### 3. `lib/tls/https.uya`

- 新增本地时间辅助函数：`https_now_ms()`, `https_deadline_after_ms()`, `https_deadline_expired()`
- 新增 socket 超时函数：`https_socket_set_recv_timeout(fd, ms)`, `https_socket_set_send_timeout(fd, ms)` — 使用 `setsockopt(SO_RCVTIMEO/SO_SNDTIMEO)`
- 新增 `HttpsClientConfig` 结构体：含 `verify_server_cert`, `verify_hostname`, `trust_store`, `timeout_ms`
- 新增 `https_client_config_default()`, `https_client_config_insecure()`, `https_get_with_config()`
- `https_get_internal()` 改为接受 `&HttpsClientConfig`，设置 socket 超时，在 connect/handshake 后检查 deadline
- `https_get()` 和 `https_get_insecure()` 改为使用配置对象

#### 4. `lib/std/time.uya`（已创建但未使用）

- 提供 `now_ms()`, `deadline_after_ms()`, `deadline_expired()`, `deadline_remaining_ms()` 通用时间工具
- 因跨模块 `time.xxx` 在 `@async_fn` 中存在编译器 bug，各模块临时使用本地重复函数绕过

#### 5. `lib/libc/syscall.uya` / `lib/syscall/linux.uya`

- **修复 epoll_ctl 常量定义**：`EPOLL_CTL_DEL` 由 `3` 修正为 `2`，`EPOLL_CTL_MOD` 由 `2` 修正为 `3`，与 Linux 内核定义一致

#### 6. `lib/std/async_event.uya`

- `deregister` 由 `sys_epoll_ctl(self.epfd, EPOLL_CTL_DEL, fd, null)` 改为 `sys_epoll_ctl_del(self.epfd, fd)`

#### 7. `tests/test_http1_async_client.uya`

- 所有 `http1_async_get`/`http1_async_post` 调用已更新为 3 参数版本（增加 `timeout_ms`）

### 超时覆盖范围

| 阶段 | HTTP (async) | HTTPS (sync) | 实现方式 |
|------|-------------|-------------|---------|
| DNS 查询 | ✅ | ✅ | 从 deadline 计算剩余时间作为 DNS timeout |
| TCP 连接 | ✅ | ❌（阻塞 connect） | `Http1ConnectFuture.poll()` 中检查 deadline |
| TLS 握手 | N/A | ✅ | handshake 前后检查 deadline |
| Socket 读 | ✅ | ✅ | HTTPS: `SO_RCVTIMEO`；HTTP: `http_check_deadline` 已启用 |
| Socket 写 | ✅ | ✅ | HTTPS: `SO_SNDTIMEO`；HTTP: `http_check_deadline` 已启用 |
| 读 body 循环 | ✅ | N/A | `http_check_deadline` 已启用 |
| EventLoop 层 | ✅ | N/A | `block_on_with_event_loop_deadline` 检查 deadline |

### 历史已知问题（2026-04 快照）

1. **跨模块 `time.xxx` 调用在 `@async_fn` 中的 bug**：`use std.time` 后在 `@async_fn` 中调用 `time.now_ms()` 触发编译器错误（符号名生成 mismatch）。各模块临时使用本地时间函数绕过。待修复后可统一使用 `lib/std/time.uya`，删除重复时间函数。
2. **`catch { value }` 语法解析问题**：`expr catch { 0 as u64 }` 在复杂上下文可能触发 "unexpected token '}'" 错误。使用中间变量绕过。
3. **`@async_fn` 内 await transition 的 compiler lowering 限制**：当 `@await` 位于 `while` / `if` 等控制流块内部时，状态机在某些 transition 点会返回 Pending 但未设置 I/O interest，导致 `block_on_with_event_loop` 若不做 workaround 会出现 1000ms 空等。当前已通过 `block_on_with_event_loop` 的 `loop.poll(1)` 重试 workaround 规避。长远应在 compiler lowering 层修复，使 transition 后直接 fallthrough 到新 future 的 poll。

### 历史验证状态（2026-04 快照）

- `make b`（自举）：✅ 通过
- `make tests`：✅ 核心 async 网络测试通过（`test_http1_async_client`、`test_std_dns_async_transport`、`test_https_loopback` 等）
- `make check`：✅ 全量通过（2026-04-14 `@frame(foo)` + pinned 语义实现后）

### 当前后续入口（2026-06-21 同步）

- 当前权威排期：`docs/todo_async_full_language_dynamic_resources.md`
- 当前能力/阻塞快照：`docs/async_status_matrix.md`
- 共享 runtime 统一验收矩阵：`docs/async_runtime_semantics_matrix.md`
