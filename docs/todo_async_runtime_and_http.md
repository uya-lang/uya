# 异步运行时完善与 HTTP 服务器实现 — 综合待办

**最后更新**：2026-04-16 — `Waker eventfd` 跨线程唤醒、泛型 `TaskQueue<T>`、协作式取消语义、以及结构体/接口方法 `@async_fn` 主链路已落地并通过回归；`http_bench_async_epoll` 与 `@async_fn` codegen 缺口的收口状态、Bug B、复合表达式 `try @await` lowering、AsyncFramePool / caller-owned inline / scheduler 状态已与当前代码同步。此前 2026-03-31 — 记录 `http_bench_async_epoll` 与 `@async_fn` codegen 缺口：嵌套循环内 await 之间语句未发射 → 运行时 `write(...,0)`、curl Empty reply；详见 [todo_async_loop_await.md](todo_async_loop_await.md) 高优先级待办。此前 2026-03-25 — Phase 8 完成：基准测试框架 `run_bench.sh` + `baseline.json`；Uya ~10K QPS vs Go ~145K QPS（wrk -t4 -c64 -d10s，Intel i7-14700）；此前同日 — Phase 8：`benchmarks/run_bench.sh`（wrk 对比 Uya/Go）、`baseline.json`（含测试机 Intel i7-14700/31GB/Deepin 25）；`get_bearer_token` `InvalidToken` 错误路径（`test_get_bearer_token_empty_token`）；`todo_http.md` Phase 6 `!T` 错误路径已完整覆盖标记；此前同日 — `parse` query 边界（`TooManyParams`/`ValueTooLong` 等）与 `parse_multipart` `TooManyParts`。此前同日 — `test_http_multipart`、`error_http_request_get_header_type`；`todo_mini_to_full` std.http。此前同日 — Phase 6：`parse`/`router` 更多 `!T` 错误路径；`readme.md` HTTP 小节。此前同日 — `types.uya`：`request_get_header` / `get_bearer_token`；`parse_then_request_get_header`。此前同日 — HTTP Phase 5：`IncompleteRequest` + `find_crlf_or_incomplete` / 体未收齐时流式续读；`http_conn_read_parse`、`http_connbuf_shift`、`HTTP_CONN_READ_CAP` 与多 `recv` 的 `http_recv_parse_request`；测试 `http_keepalive_pipeline_two_requests`、`parse_post_body_incomplete`。此前同日 — ThreadPool `THREAD_POOL_MAX_WORKERS` / `THREAD_POOL_MAX_PENDING` 提升至 32；此前 2026-03-24 — Phase 4 `lib/std/http/router.uya` 已落地：`router_find_route` 返回命中下标 / `-1`（404）/ `-2`（405）、`path_matches_pattern` / `router_apply_path_params`、`MAX_ROUTES` 与 `RouterFull`；测试 `tests/test_http_router.uya`。此前：2026-03-22 — `f32`/`f64` 已并入 `AsyncComputeFuture<T>`；C99 泛型方法内 `thread_type_is_*(T)` 折叠；前导 `uya_thread_call_f32`/`f64` 以 **u32/u64 位模式** 与槽位对接，内部用 **union** 转 `float`/`double`，并以 **`float(*)(float)` / `double(*)(double)`** 间接调用（**不可**伪装成 `uint32_t(*)(uint32_t)` 等整型 ABI，否则 `async_compute` 浮点用例会错）。

**关联文档**：
- [async_status_matrix.md](async_status_matrix.md) — async 实现现状总表（runtime / codegen / tests / docs）
- [todo_async_loop_await.md](todo_async_loop_await.md) — 循环内 await 实现细节
- [todo_http.md](todo_http.md) — HTTP 框架实现待办（Phase 1-9 详细任务）
- [http_framework_design.md](http_framework_design.md) — HTTP 框架设计文档
- [std_async_design.md](std_async_design.md) — 异步运行时设计文档
- [todo_mini_to_full.md](todo_mini_to_full.md) §16/19/26 — 主待办中异步/标准库/并发安全条目
- [async_loop_await_design.md](async_loop_await_design.md) — 循环 await 设计文档

> **2026-06-22 同步说明**
>
> 本文档保留的是 2026-03/04 阶段“异步运行时完善 + HTTP 服务器路线图”的历史拆解，不是当前 async 生产化权威闸门。
> 当前是否达到“完整语法 + 动态资源 + 共享 runtime 发布闸门”，必须回到 [todo_async_full_language_dynamic_resources.md](todo_async_full_language_dynamic_resources.md)、[async_status_matrix.md](async_status_matrix.md) 与 `tests/async_shared_runtime_mix.sh` 判断。

---

## 第一部分：异步运行时硬伤修复

当前异步基础设施已打通基本闭环（`Future<!T>` 状态机 + `block_on` + `LinuxEpoll` + `ThreadPool`），但存在以下结构性问题，阻碍 HTTP 服务器等真实业务开发。

### P0：阻塞发布 ✅ (已完成)

| # | 问题 | 位置 | 影响 | 修复方案 | 状态 |
|---|------|------|------|----------|------|
| 1 | **@await 上限 32** | `src/checker/check_stmt.uya:615` `max_async_awaits = 32` | 复杂异步函数被拒绝编译（HTTP handler 解析 + 路由 + 响应极易超限） | 提升至 256+；改编译期状态机大小检查替代硬编码上限 | ✅ 已完成 |
| 2 | **epoll fd 槽位 64 硬编码** | `lib/std/async_event.uya` `LinuxEpoll` 结构体 `[i32: 64]` 数组 | 生产环境 64 并发连接即上限 | 改为动态分配（malloc）或宏参数化容量；至少支持 1024+ | ✅ 已完成（提升至 1024） |
| 3 | **TaskQueue 固定 8 槽** | `lib/std/async_scheduler.uya:14` `TASK_QUEUE_I32_CAPACITY = 8` | 仅 8 个任务可入队，超出直接丢弃 | 改为动态数组或环形缓冲区，支持扩容 | ✅ 已完成（提升至 64） |
| 4 | **状态机帧分配仍偏向默认 heap** | `src/codegen/c99/function.uya:1286` 注释"暂未启用" | 大状态机栈溢出（编译期警告阈值 1024 字节） | 已切到统一 `AsyncFramePool` + caller-owned inline，热路径不再直连 `malloc/free` | ✅ 已完成（默认热路径不再直连 `malloc/free`） |

### P1：功能缺失

| # | 问题 | 位置 | 影响 | 修复方案 | 状态 |
|---|------|------|------|----------|------|
| 5 | **Scheduler 空壳** | `lib/std/async_scheduler.uya` | 所有调度方法退化为 `block_on`，无法多任务协作 | 实现 `scheduler_run`：任务队列 + epoll 事件循环 + 贪心 poll；现已推广到 `TaskQueue<T>` / `scheduler_run_task_queue_with_event_loop<T>` | ✅ 已完成（泛型 `TaskQueue<T>` + shared EventLoop） |
| 6 | **无跨线程唤醒** | `lib/std/async.uya` `Waker` | `async_compute` worker 完成后主线程无法被唤醒，只能 busy-wait | 为 `Waker` 增加 `eventfd` 绑定/关闭，`Scheduler` 在 `Pending` 时同步注册 `eventfd + io fd`；worker/外部线程 `wake()` 直接写 `eventfd` 唤醒主 `EventLoop` | ✅ 已完成（`test_std_async_scheduler.uya` 外部 wake + `async_compute` 路径） |
| 7 | **block_on busy-wait** | `lib/std/async.uya` `block_on_*` 系列函数 | CPU 100% 占用，无法用于生产 | 集成 EventLoop：poll 返回 Pending 时注册 epoll，epoll_wait 等待唤醒 | ✅ 已完成（`block_on_with_event_loop`） |
| 8 | **循环变量持久化硬编码** | `src/codegen/c99/function.uya` | 仅 `n`+`written` 组合被识别为循环变量；其他变量名在 await 后值丢失 | 已改为基于「循环内定义 + 跨 await 引用」的作用域分析 | ✅ 已完成（不再依赖 n/written/total 特判） |
| 8a | **async 状态机 lowering 缺陷（历史主链路缺口已转正）** | `collect_awaits_recursive` + emit | Bug A: 连续 while+await 循环状态转移失败；Bug B: await 间同步代码被吃掉；Bug C: `return try @await` 生成非法 C；Bug D: 分裂点局部变量丢失；复合表达式中的 `try @await` 未走正确回放路径 | 相关回归已通过；Bug A/B/C/D 与复合表达式 `try @await` 均已转正；该结论仅表示当时主链路缺口关闭，不等于当前 async 生产化已完成 | ✅ 已完成 |
| 9 | **Waker 单 fd** | `lib/std/async.uya:12` `_io_fd: i32` | 无法同时关注读+写或多个 fd | 改为数组或链表；单 fd 时退化为当前行为 | 待办 |
| 10 | **错误类型不一致** | `async_event`/`async_scheduler` | 调用方难以统一错误处理 | 定义 `std.async.Error` 枚举，统一所有异步错误 | ✅ 已完成（`EventLoopSlotsFull` 等已统一） |

### P2：架构改进

| # | 问题 | 修复方案 | 状态 |
|---|------|----------|------|
| 11 | `async_compute<T>` 曾需 12 套重复 `Future` 实现 | 改用 `void*` + 类型擦除，或编译器泛型 + 单一 `AsyncComputeFuture<T>` | **已完成 API 收敛**：`AsyncComputeFuture<T>` 覆盖 **含 f32/f64** 的全部载荷；**仅**导出 **`async_compute<T>`**（已删 12 个 **`async_compute_*`**）；typedef 别名仍可用。 |
| 12 | `ThreadPool` worker / pending 曾硬编码 8 | `thread_pool_new(n)` 已存在；**已**将 `THREAD_POOL_MAX_WORKERS` / `THREAD_POOL_MAX_PENDING` 与数组维度提升至 **32**，边界比较改用常量 | **部分完成**（仍固定上限数组，非动态扩容） |
| 13 | 无超时/取消机制 | `Waker.cancel()/is_cancelled()`、`TaskQueue.cancel()`、`error.Cancelled`、统一 cleanup | `Future` 在 `poll()` 中显式检查取消位；Scheduler/TaskQueue 在取消或完成时统一 deregister + 释放 eventfd / I/O 资源；`async_compute` queued/running 路径都稳定返回 `error.Cancelled` | ✅ 已完成（协作式取消模型） |
| 14 | 无异步 I/O 原语 | 实现 `AsyncFd`（非当前空壳）：epoll 注册 + 非阻塞 read/write + 自动状态机调度 | ⚠️ 部分完成（`std.async.io` 已有 `read/write/read_exact/write_all/flush`、`async_write_bytes/cstr`、`async_print_to/println_to` 与真实 shared-epoll I/O 回归；更丰富格式化/helper 仍待扩展） |

### P1.5：编译器 / C99（与 `Future<!T>`、`std.thread` typedef 相关）✅ 近期已闭环

以下项已在 `src/codegen/c99/`（`structs.uya`、`stmt.uya`、`expr.uya`、`main.uya` 等）与 `lib/std/thread.uya` 落地，`test_std_thread.uya`、`test_async_compute_types.uya` 与全量 `--uya --c99` 通过：

- 泛型 `AsyncComputeFuture<T>` **不**再按「非泛型 struct」生成占位 interface vtable；`Future<!T>` 单态与 `Poll<!T>` 的 `err_*` 命名一致。
- **接口实参装箱**：实参变量 C 类型为 **typedef**（如 `AsyncComputeI32Future`）时，经 `find_type_alias_from_program` → `get_mono_struct_name` 再生成 `struct uya_interface_Future_err_*` 装箱。
- **成员方法调用**：`f.poll(&w)` 在接收者类型无 `struct ` 前缀时，从类型串解析标识符并走别名解析，生成 `uya_AsyncComputeFuture_*_poll`（修复误生成 `unknown(...)`）。
- **`ok<bool>` / `ok<f32>` / `ok<f64>` 单态**：`finish_from_raw_poll` 按 `T` 分发时由 `thread_ok_bool` / `thread_ok_f32` / `thread_ok_f64` 内显式 `ok<...>` 锚定；codegen 保留 `mark_ok_mono_reachable_for_async_compute_futures`。
- **泛型方法 + `thread_type_is_*(T)`**：`gen_call_expr` 在 `struct_type_args` 上下文中将调用折叠为字面量 `0`/`1`（勿从方法体抽泛型顶层 helper，否则 C 可达性不生成）。
- **宿主线程浮点调用**：`src/codegen/c99/main.uya` 注入的 `uya_thread_call_f32`/`f64` 必须与真实 **`float`/`double` 调用约定**一致；槽位仍为整型位模式仅作存储与传递。
- **async 方法/接口签名**：`@async_fn` 现已支持结构体内部方法、外部方法块与 interface 方法签名；method async wrapper/poll、`Self` 解析、`Type::method` 调用图键与 vtable 分派主链路已接通，固定回归见 `tests/test_async_method_interface.uya`。

**后续清理（非阻塞）**：✅ 已抽取 typedef 解析助手；✅ 已移除 `ok_bool_force` 等冗余；✅ 已移除 12 个 **`async_compute_*`** 导出；**`async_compute<T>`** C99 单态走 **`std_thread_async_compute_future_new_<T>`** + 装箱（**勿**仅靠宏展开体：`thread_type_is_*` 在 C 端不折叠会落回错误分支）。

---

## 第二部分：HTTP 服务器实现路线图

详细任务分解见 [todo_http.md](todo_http.md)，此处为总览与依赖关系。

### 依赖图

```
Phase 1: Socket API
    └── Phase 2: HTTP Types (types.uya)
    └── Phase 3: HTTP Parse (parse.uya)
    └── Phase 4: HTTP Router (router.uya)
            └── Phase 5: Blocking Server (server.uya)
                    └── Phase 6: 测试与示例完善
                            └── Phase 7: JWT
                            └── Phase 8: 性能基准
                            └── Phase 9/10: epoll 多路复用 + 中间件 + 异步 Handler
```

### 里程碑

| 阶段 | 内容 | 前置依赖 | 状态 |
|------|------|----------|------|
| **Phase 1** | TCP Socket 封装（libc/syscall 层） | 无 | ✅ 完成 |
| **Phase 2** | HTTP 类型定义（Request/Response/Context/Handler） | 无 | ✅ 完成 |
| **Phase 3** | HTTP 解析器（请求行 + 头部 + body + multipart） | Phase 2 | ✅ 完成 |
| **Phase 4** | 路由器（路径匹配 + 参数提取 + 404/405） | Phase 2 | ✅ 完成 |
| **Phase 5** | 阻塞式 HTTP 服务器（accept + 原语级 API） | Phase 1-4 | ✅ 完成 |
| **Phase 6** | 测试完善 + 示例应用 | Phase 5 | ✅ 完成 |
| **Phase 7** | JWT 认证（HS256） | Phase 5 | ✅ 完成 |
| **Phase 8** | 性能基准（wrk 对比 Uya/Go/Tokio） | Phase 5 | ✅ 完成 |
| **Phase 9** | epoll 多路复用服务器 | P0 硬伤修复 + Phase 5 | ⚠️ 基础落地（`epoll_server.uya` 已有 accept/slot/event 原语；lowering 侧阻塞已解除，后续以 handler/scheduler 收口为主） |
| **Phase 10** | 中间件 + 异步 Handler + http.client | Phase 9 + P1 修复 | 📋 待开始 |

**阻塞服务器里程碑**（Phase 1-8，历史阶段记录）：✅ 已完成；不等于当前 async 生产化或共享 runtime 发布闸门已完成
**完整异步服务器**（Phase 9-10）：⚠️ 不再受 P1 #8a 阻塞，当前主要剩余高层 handler / middleware / client API 收口

---

## 第三部分：实现顺序建议

### 第一步：P0 硬伤修复（约 2-3 周）✅ 已完成

按依赖顺序：

1. **#8 循环变量持久化泛化**（代码生成，无运行时依赖）✅
   - 位置：`src/codegen/c99/function.uya`
   - 做法：移除 `strcmp("n") && strcmp("written")` 硬编码，改为 AST 层面分析「while 循环内定义、跨 await 引用」的变量集合
   - 测试：扩展 `test_async_copy.uya` 为更通用的循环变量名

2. **#1 @await 上限提升**（编译器检查）✅
   - 位置：`src/checker/check_stmt.uya:615`
   - 做法：`max_async_awaits` 从 32 提升至 256；以编译期状态机大小（已在 621-627 行估算）作为实际限制
   - 测试：超过 32 个 await 的 async 函数

3. **#2 epoll 槽位动态化**（运行时）✅
   - 位置：`lib/std/async_event.uya` `LinuxEpoll`
   - 做法：槽位容量从 64 提升至 1024
   - 测试：注册 >64 个 fd

4. **#3 TaskQueue 动态化**（运行时）✅
   - 位置：`lib/std/async_scheduler.uya`
   - 做法：TaskQueue 容量从 8 提升至 64
   - 测试：入队 >8 个任务

5. **#4 状态机堆分配**（代码生成）✅
   - 位置：`src/codegen/c99/function.uya`
   - 做法：统一 `AsyncFramePool` + caller-owned inline，热路径不再直连 `malloc/free`
   - 测试：大状态机 async 函数与 `tests/test_async_frame_stack_ok.uya`

### 第二步：P1 功能补齐（约 3-4 周）

6. **#7 block_on 集成 EventLoop** ✅
   - 位置：`lib/std/async_scheduler.uya` `block_on_with_event_loop` 系列函数
   - 做法：poll 返回 Pending 时，将 Waker 的 fd 注册到 `LinuxEpoll`，`epoll_wait` 阻塞等待
   - 测试：`test_std_async_scheduler.uya` 验证 EventLoop 集成

7. **#6 跨线程唤醒（futex/eventfd）** ✅
   - 位置：`lib/std/async.uya` `Waker`
   - 做法：`Waker` 现已支持 `eventfd` 绑定/关闭，`Scheduler` 会在 `Pending` 时同步注册 `eventfd + io fd`；worker/外部线程 `wake()` 直接写 `eventfd`
   - 测试：`test_std_async_scheduler.uya` 外部 `eventfd` wake 与 `async_compute` 集成路径通过

8. **#5 Scheduler 真正实现** ✅
   - 位置：`lib/std/async_scheduler.uya`
   - 做法：`scheduler_run_task_queue_with_event_loop<T>` / typed wrappers 实现贪心 poll：Ready 任务直接完成 → Pending 任务注册 `eventfd + io fd` → `epoll_wait` → 唤醒重试
   - 测试：`test_std_async_scheduler.uya` 泛型队列 / cancel / 外部 wake 与 `test_async_multi_fd_concurrent.uya` 多任务并发调度通过

9. **#10 统一错误类型** ✅
   - 位置：`lib/std/async.uya`
   - 做法：定义 `export error EventLoopSlotsFull; export error TaskQueueFull; export error SchedulerStopped; export error FutureNotReady;`
   - 其他模块可 use 并复用
   - 测试：现有测试通过

### 第三步：Phase 1-5 HTTP 阻塞服务器（约 8 周）

参见 [todo_http.md](todo_http.md) Phase 1-5 详细任务。

**Phase 1：TCP 基础设施** ✅
- Socket API 系统调用（socket/bind/listen/accept/connect/send/recv/shutdown/setsockopt/getsockopt）
- Socket 常量（AF_INET/SOCK_STREAM/IPPROTO_TCP 等）
- 测试：`test_tcp_basic.uya` 通过

**Phase 2：http.types** ✅
- 创建 `lib/std/http/` 目录和 `types.uya`
- 错误类型、HTTP 方法枚举、状态码枚举、服务器模式枚举
- 请求/响应/连接/Context 结构体
- Handler/Middleware 接口
- `request_get_header` / `get_bearer_token`（头名与 `Bearer` 前缀大小写不敏感）
- 测试：`test_http_types.uya` 通过

**Phase 3：http.parse** ✅
- `parse.uya`：请求行、头部、body、Keep-alive `ParseResult`、multipart 等
- 测试：`test_http_parse.uya` 等

**Phase 4：http.router** ✅
- `router.uya`：`Router` / `RouteEntry`、`router_add`、`router_find_route`（命中下标；`-1` 未匹配；`-2` 路径有模式但方法不允许）、`path_matches_pattern`、`router_apply_path_params`、`router_apply_path_params_request`（从 `Request.path`/`path_len` 切片，避免手写 `path_copy`）；`types.uya` 中 `MAX_ROUTES` 与 `RouterFull` 错误
- 首版路由表不存 `Handler`（避免接口装箱）；命中下标后由业务自行映射处理函数
- 测试：`test_http_router.uya`

**Phase 5：http.server（进行中）**
- `server.uya`：`http_conn_read_parse`（`IncompleteRequest` 时续读）、`http_connbuf_shift`（已消耗字节前移）、`HTTP_CONN_READ_CAP` 与 `http_recv_parse_request` 内部多 `recv`
- `parse.uya`：首行/头部行末无完整 CRLF 或 body 未收齐时返回 `error.IncompleteRequest`（`find_crlf_or_incomplete`）
- 测试：`test_http_server.uya`（含流水线双 GET、`POST+GET`→`201`/`204`、`path_param+query`、`http_parse_error_returns_400`）、`parse_post_body_incomplete`；`http_send_response` 支持 `Created`/`NoContent` 状态行
- 示例：`examples/http_server.uya`（`try` + `match`：`pr`/成功分支放在各 `error.*` 之后，避免 C 代码 `else` 悬空）

**Phase 9（HTTP epoll，进行中）**
- `lib/std/http/epoll_server.uya`：`epoll_server_listen` / `epoll_server_wait_events` / `epoll_server_accept_register`（accept 后客户端 `EPOLLIN`）/ `epoll_server_release_slot` / `epoll_server_close`；`EPOLL_SERVER_MAX_SLOTS=512`；`error.EpollSlotsFull`
- 测试：`tests/test_epoll_server.uya`（含 `epoll_one_get_route_ok`、`epoll_pipeline_two_gets_slot_buffer`：槽位缓冲 + `http_conn_read_parse` / `http_connbuf_shift` 流水线双 GET，对齐阻塞版 `http_keepalive_pipeline_two_requests`；`--safety-proof`）
- 非阻塞：`http_conn_read_parse_nonblocking`、`epoll_server_fd_set_nonblocking`、`epoll_server_accept_register_nb`；测试 `epoll_nonblocking_read_would_block_then_get`
- 待办：单线程内通用 `run` 循环封装、多连接交错

### 第四步：Phase 9-10 异步 HTTP 服务器（约 6 周）

依赖第二步 P1 修复完成 + Phase 5 阻塞服务器通过。

---

## 第四部分：验证清单

每个修复完成后：

```bash
# 1. 编译器自举
make b

# 2. 全量测试
make tests

# 3. 完整验证 + 备份
make check && make backup
```

新增异步测试应同时通过 `--c99` 与 `--uya --c99`。

---

## 第五部分：风险与决策点

| 风险 | 说明 | 缓解 |
|------|------|------|
| 栈大小 | 状态机栈分配 + 深层调用可能溢出 | 参考 `docs/STACK_SIZE.md`；P0 #4 解决堆分配 |
| 泛型限制 | 曾阻碍 `Future<!T>` + typedef 与 `ok<bool>` 单态 | **已缓解**：`AsyncComputeFuture<T>` 泛型体 + C99 装箱/成员调用修复；对外仅 **`async_compute<T>`**（含 f32/f64）；typedef 别名保留 |
| Linux 专属 | epoll/eventfd 仅 Linux；跨平台需 kqueue/iocp | 当前专注 Linux；设计时抽象 EventLoop 接口 |
| 估计偏差 | HTTP 解析器边界情况可能超预期 | Phase 3 预留 2 周缓冲 |
