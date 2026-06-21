# Uya Async 现状总表

**最后更新**：2026-06-21
**范围**：Linux + C99 后端；聚焦 `@async_fn` / `@await` / `Future` / `Poll` / `Waker` / `AsyncFd` / `Scheduler` / `async_compute`

> **2026-06-21 注意**
>
> 本表是 2026-04/05 阶段以来的能力快照，`✅` 仅表示对应子问题已有聚焦回归或阶段性验收，**不等于**当前目标“异步编程生产级可用”已经完成。
> 当前权威 TODO 请看：[todo_async_full_language_dynamic_resources.md](todo_async_full_language_dynamic_resources.md)。
> 仍未被本表覆盖为“已完成”的关键目标包括：
> - `@async_fn` 对完整 Uya 函数体语法的支持，而不只是当前回归已覆盖的子集
> - async 编译器/runtime 资源的动态化仍未全部完成；**已收口** 的包括 `TaskQueue<T>` 默认队列自动增长、`LinuxEpoll` 满载自动扩容，以及 async frame meta / descriptor 按真实数量生成；**仍待收口** 的包括 `ThreadPool` worker/pending/task slot 容量策略、`AsyncFramePool` bucket 默认上限、HTTP/1 请求头 scratch buffer 等运行时/协议层硬边界
> - HTTP、DNS、TLS、`async_compute` 与 `Scheduler` 在同一 `Scheduler` / `EventLoop` / cancellation 语义下的统一 smoke 或矩阵验收
> - 历史“已知限制”与源码现状、验证闸门之间的重新对齐
>
> 因此，本表中的 `✅` 只表示单项能力或局部链路已有证据；不得再写成“Linux + C99 async 主链路已完全收口”。共享 runtime 口径以 [async_runtime_semantics_matrix.md](async_runtime_semantics_matrix.md) 的缺口列和最小验证矩阵为准。
>
> 生产阻塞项必须显式保留在后续 release 口径中：剩余 runtime/protocol 层容量边界没有动态化前、语法禁区没有被转正或规范化前、fallback 路径没有被去除/配置化/验收前，历史“量产完成”结论都不能升级为当前 async 生产完成结论。

## 总览

| 能力 | 状态 | Runtime | Codegen | Tests | Docs |
|------|------|---------|---------|-------|------|
| async lowering / 状态机控制流 | ⚠️ 部分完成 | `if/else if`、`while`、范围 `for`、定长数组值/引用迭代、具体 struct 迭代器值迭代、嵌套块、循环间同步语句已稳定 | Bug A/B/C/D 与复合表达式中的 `try @await`（赋值 RHS / return 表达式）已修复；`const r: !T = @await fut` 这类 direct err-union await 绑定也已接通；`return error.X`、局部变量提升、await 间同步语句恢复；**接口值迭代** 是同步也不支持的通用语言边界，不再计作 async 独有缺口；迭代器 `for iter |&x|` 引用绑定已有 async 正向回归 | `test_async_bug_b_sync_between.uya` `test_async_for_await.uya` `test_async_for_iterator_ref_await.uya` `test_async_bug_d_nested_block.uya` `test_async_compound_try_await.uya` `test_async_await_direct_err_union.uya` `error_for_iterator_interface_value.uya` `error_async_for_iterator_interface_await.uya` | `async_coroutine_transform_design.md` `plan_async_coroutine_transform.md` `async_loop_await_design.md` |
| async 方法 / 接口方法签名 | ✅ 已覆盖 | 结构体内部方法、外部方法块、接口方法签名均支持 `@async_fn`；接口 ABI 仍以 `Future<!T>` / `!Future<T>` 表达 | 方法 async wrapper/poll、`Self` 解析、`Type::method` async 调用图键与 vtable 分派已接通 | `test_async_method_interface.uya` `test_interface_error_union_method.uya` `test_struct_inner_method_void.uya` | `uya.md` `builtin_functions.md` `grammar_formal.md` `std_async_design.md` |
| async frame 分配 / 生命周期 | ✅ 已覆盖 | 默认路径已切 `AsyncFramePool` + caller-owned inline + pinned 语义；`@frame(foo)` 暴露 `start/poll/stop`；Ready/Error/Cancel 统一释放 | `@frame(foo)` 类型构造器与 frame 生命周期命名已收口 | `test_async_frame_methods.uya` `test_async_frame_stack_ok.uya` `test_async_frame_release_path.uya` | `async_frame_allocation_design.md` `todo_async_frame_allocation.md` |
| `Waker` / `EventLoop` / `AsyncFd` | ✅ Linux 主路径已覆盖 | `Waker` 支持单 interest、`eventfd` 绑定/关闭、`cancel/is_cancelled`；`LinuxEpoll` + `AsyncFd` 已接通 readiness；`LinuxEpoll` 的 `slot/lookup/poll scratch` 在满载时会自动扩容并暴露 resize metrics；`AsyncWriter/AsyncReader` 已具备 `write_all` / `read_exact`，helper 层已有 `async_write_bytes/cstr`、`async_print_to/println_to` | 已验证的是 Linux 单 fd/单 interest 主路径；多 interest、跨 HTTP/DNS/TLS 组合与跨平台后端仍需另行验收 | `test_std_async_event.uya` `test_async_event_dynamic_growth.uya` `test_async_event_config.uya` `test_async_fd.uya` `test_async_io.uya` | `std_async_design.md` `async_production_todo.md` |
| `Scheduler` / 泛型 `TaskQueue<T>` | ✅ 阶段性覆盖 | `scheduler_run_*_with_event_loop`、`scheduler_run_pair_i32_with_event_loop`、`TaskQueue<T>` / typed wrappers、共享 `EventLoop` 单轮推进已覆盖；默认 `TaskQueue<T>` 现以 legacy `64` 为起步容量并在 `push()` 时自动增长，`task_queue_new_with_capacity<T>()` 保留调用方显式上限；`Future<!usize>` 的真实 shared-epoll I/O 队列也已验证 | 队列依赖的“数组元素上的接口字段方法调用”与“结构体依赖收集误展开接口模板”已修复；frame buffer / inline repoll 资源策略已支持 runtime 配置；仍缺跨链路共享 runtime 矩阵与同队列 smoke | `test_std_async_scheduler.uya` `test_async_task_queue_dynamic_growth.uya` `test_async_multi_fd_concurrent.uya` `test_async_fd.uya` | `std_async_design.md` `todo_async_runtime_and_http.md` `todo_mini_to_full.md` |
| 跨线程 wake / `eventfd` | ✅ Linux 阶段性覆盖 | `Scheduler` 在 `Pending` 时同步注册 `eventfd + io fd`；worker/外部线程 `wake()` 可直接唤醒主 `EventLoop` | 仅证明 Linux eventfd 路径；跨平台与跨 HTTP/DNS/TLS 组合仍需另行验收 | `test_std_async_scheduler.uya` 外部 wake 场景 | `async_production_todo.md` `todo_async_runtime_and_http.md` |
| 协作式取消语义 | ✅ 阶段性覆盖 | `Waker.cancel()`、`TaskQueue.cancel()`、统一 deregister / eventfd close / slot cleanup；结果用 `error.Cancelled` 写回 | 已覆盖调度器和 async_compute 相关路径；HTTP/DNS/TLS 与共享调度组合中的取消语义仍需矩阵化验收 | `test_std_async_scheduler.uya` 取消 slot；`test_std_thread.uya` queued/running cancel | `std_async_design.md` `async_production_todo.md` |
| `std.thread.async_compute<T>` 集成 | ✅ Linux 主路径已覆盖 | 未启动/排队/one-shot 任务可立即取消；运行中的共享槽任务在结果回收时稳定返回 `error.Cancelled`；`ThreadPoolConfig.submit_strategy` 已显式固定默认策略为 queue-or-error，pending/task slot 容量可配置到 legacy 常量之上 | `Future<!T>` 单态、typedef 装箱、成员调用、`f32/f64` helper 已收口；ThreadPool 仍保留兼容常量和显式容量边界，尚未形成真正动态扩缩容；仍需纳入跨 HTTP/DNS/TLS 的共享 runtime 验收 | `test_std_thread.uya` `test_std_thread_async_boundary.uya` `test_async_compute_types.uya` `test_async_compute_dynamic_resource_pressure.uya` `test_async_thread_pool_dynamic_growth.uya` | `todo_async_runtime_and_http.md` `todo_mini_to_full.md` |
| HTTP/DNS/TLS async 客户端主链路 | ⚠️ 生产收口中 | HTTP/1.1 nonblocking connect/read/write、DNS async 查询、timeout/deadline 已接通；但尚未作为“HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一 runtime 语义”的完整矩阵统一验收 | async lowering / 变量提升相关缺口已修复到主链路可用；仍需把共享 runtime 矩阵纳入生产闸门 | `test_http1_async_client.uya` `test_std_dns_async_transport.uya` `test_https_loopback.uya`；待补共享 runtime 矩阵 | `async_production_todo.md` `todo_async_full_language_dynamic_resources.md` |
| UyaGin async 服务端协议热路径 | ✅ P6 阶段性覆盖 | request parser 已支持 chunked request 原地解码；response 已支持 `writev` 聚合写、显式 chunked response、Linux x86_64 `sendfile` 优先发送；`Engine` 已补入 access log/metrics/error trace/config/mode 主链路 | 为支撑观测包装，`engine.handle` 现在统一走 request observation wrapper；当前剩余噪音仍是 parser 对 `catch { ... }` 某些写法的假告警，不影响 codegen/run；不代表 HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享 runtime 已统一验收 | `test_http_parse.uya` `test_http_server.uya` `test_http_uyagin.uya` `test_https_loopback.uya` | `uyagin_todo.md` `uyagin_design.md` `tls_https_todo.md` |

## 阶段性回归与共享主链路的区别

本表保留历史阶段性验收结果，但从当前生产化 TODO 开始，以下口径必须分开使用：

- **分散回归**：某个测试文件证明一条局部路径可编译、可运行或可处理特定错误。例如 HTTP async client、DNS async transport、`async_compute<T>` 或 `Scheduler` 单独测试。
- **共享 runtime 收口**：HTTP、DNS、TLS、`async_compute` 与 `Scheduler` 在同一套 `Future` / `Poll` / `Waker` / `EventLoop` / cancellation 语义下组合运行，并有明确 Linux + C99 验证命令。

当前只有前者证据较充分，后者仍依赖 [async_runtime_semantics_matrix.md](async_runtime_semantics_matrix.md) 中列出的 smoke 与缺口补齐。因此历史文档中的“主路径已覆盖”“Linux 主路径已覆盖”“阶段性覆盖”不应升级解读为当前 TODO 的第一个总目标完成。

## `@async_fn` 函数体语法矩阵

本节只收口“同步函数体语法放入 `@async_fn` 后是否也可用”的口径。`✅ 已覆盖` 表示已有针对 async 的正向或负向回归；`⚠️ 未验证/待补` 表示同步语法本身合法，但还不能把历史“量产已完成”解读为完整 async 函数体语法已完成；`🚫 非 async 独有缺口` 表示语言规范禁止，或同步函数体也不支持。

| 函数体语法/语义 | async 状态 | 依据 | 后续动作 |
|-----------------|------------|------|----------|
| 普通表达式语句、局部 `const` / `var`、赋值、await 间同步语句 | ✅ 已覆盖 | `test_async_bug_b_sync_between.uya`、`test_async_bug_d_nested_block.uya` | 保持回归 |
| `return value`、`return error.X`、无 await 自动包装 | ✅ 已覆盖 | `test_async_return_value.uya`、`test_async_return_error_direct.uya`、`test_async_nested.uya` | 保持回归 |
| `try @await` 独立语句、赋值 RHS、return 表达式、direct err-union await 绑定 | ✅ 已覆盖 | `test_async_await_parse.uya`、`test_async_compound_try_await.uya`、`test_async_await_direct_err_union.uya` | 保持回归 |
| `if` / `else if` / `else`、嵌套块、分支后继续使用局部变量 | ✅ 已覆盖 | `test_async_else_if_await.uya`、`test_async_bug_d_nested_block.uya` | 保持回归 |
| `while` 循环体内 await、循环间同步语句 | ✅ 已覆盖 | `test_async_bug_b_sync_between.uya`、HTTP async 主链路回归 | 保持回归；不要把调度 workaround 误写成完整语法证明 |
| 范围 `for`、定长数组值/引用迭代、具体 struct 迭代器值/引用迭代 | ✅ 已覆盖 | `test_async_for_await.uya`、`test_async_for_iterator_ref_await.uya` | 保持回归 |
| 结构体/联合体内部方法、外部方法块、接口方法签名上的 `@async_fn` | ✅ 已覆盖 | `test_async_method_interface.uya` | 保持回归 |
| `@frame(fn)` 类型构造器和 `start` / `poll` / `stop` | ✅ 已覆盖 | `test_async_frame_methods.uya`、`test_async_frame_stack_ok.uya`、`test_async_frame_release_path.uya` | 保持回归 |
| `match` 表达式/语句、union 解构分支内 await | ✅ 已覆盖 | `test_async_sync_body_matrix.uya` 用同步/async 成对断言覆盖 `match` 表达式、union 分支和 await 后值进入 match | 保持回归 |
| `catch { ... }` 与 `try` 非 await 表达式组合 | ✅ 已覆盖 | `test_async_sync_body_matrix.uya` 覆盖同步 `!T` 的 `catch` 恢复；`test_async_catch_await.uya` 覆盖 `@await` 结果、catch 体内 await、catch 后继续执行与提前 return | 保持回归；parser 假诊断作为通用噪音另行处理 |
| `defer`、作用域退出 drop、提前 return/error 与 await 混合 | ✅ 已覆盖 | `test_async_sync_body_matrix.uya` 覆盖成功/错误路径清理顺序；`test_async_defer_errdefer.uya` 覆盖跨 await、同步错误与 await 错误触发 `defer/errdefer` | 保持回归 |
| 指针/数组/切片访问、结构体字面量、数组/tuple 字面量中嵌套 async 调用逃逸 | ✅ 已覆盖 | `test_async_sync_body_matrix.uya` 覆盖数组值/引用迭代与指针写回；`test_async_compound_try_await.uya`、`test_async_fn_multi_segment_unwrap.uya`、`test_async_await_limits_and_segments.uya` 覆盖复合表达式和 await 绑定跨段重放 | 保持回归 |
| `@await` 出现在 `while` 条件等非允许位置 | 🚫 规范禁止 | 当前边界说明仍要求禁止 | 保持负向回归，不计入 async 缺口 |
| 接口值迭代 | 🚫 非 async 独有缺口 | 同步也不支持；已有 `error_for_iterator_interface_value.uya` / `error_async_for_iterator_interface_await.uya` | 不作为 async 生产化阻塞项 |
| async 递归/间接递归 | 🚫 当前禁止 | 状态机大小要求编译期确定 | 除非先修改大小模型和规范，否则保持禁止 |
| nested future：无 await 的 `@async_fn` 返回 `!Future<Future<T>>` 且 `return` 中同步 `try` 另一个 `!Future<T>` | ✅ 已覆盖 | `tests/test_async_nested.uya`、`tests/test_async_nested_future_poll.uya`、`tests/verify_async_nested_future_boundary.sh` 已固定值类型双层 poll、无 await wrapper、C99 发射与宿主 C 编译边界 | 保持回归 |

## 当前口径

- `Pending` 仍表示“调度层未就绪”，业务错误走 `!T`
- 取消模型是**协作式取消**，future 需要在 `poll()` 中显式检查 `waker.is_cancelled()`
- `Waker` 当前仍是**单 interest / 单 fd** 模型；多 interest 不是当前实现范围
- 跨线程唤醒当前依赖 **Linux `eventfd`**，因此这部分能力口径是 **Linux-only**
- 生产收口必须同时证明 HTTP、DNS、TLS、`async_compute` 与 `Scheduler` 共享同一套 `Future` / `Poll` / `Waker` / `EventLoop` / cancellation 语义；单项测试通过不能再单独视为“异步主链路已完全量产”
- 共享 runtime 是否收口，以 `docs/async_runtime_semantics_matrix.md` 的链路矩阵和后续统一测试为准；本表不再单独给出“主链路已收口”结论

## 共享 runtime 生产收口矩阵

本矩阵用于连接当前权威 TODO 的生产收口口径。`✅` 表示对应链路已有独立回归证明，`⚠️` 表示仍缺少跨链路共享语义或端到端组合验证。

| 链路 | 已验证共享语义 | 仍需收口 |
|------|----------------|----------|
| `Scheduler` / `TaskQueue<T>` | ✅ `Future` / `Poll` / `Waker` / `LinuxEpoll` 单轮推进、协作式取消与 slot 清理已有回归；默认队列超过 legacy `64` 可自动增长 | 仍缺 HTTP/DNS/TLS/`async_compute` 同队列 smoke，以及 release 口径下的统一共享 runtime 验收 |
| `async_compute<T>` | ✅ worker wake 复用 `eventfd`；取消结果通过共享调度语义回到调用侧；pending/task slot 容量可显式配置到 legacy 常量之上 | 运行中取消不抢占宿主计算；ThreadPool 仍未形成真正动态扩缩容；仍需纳入跨 HTTP/DNS/TLS 的组合矩阵 |
| HTTP/1.1 async 客户端 | ✅ nonblocking connect/read/write 复用 `AsyncFd`、`Waker` 与 `LinuxEpoll` readiness | 连接池、keep-alive、真实服务端压力和共享调度组合仍是后续项 |
| DNS async 查询 | ✅ 上层 async 查询已接入 timeout/deadline 和 async transport 回归 | `A/AAAA` 并发聚合未完成；仍需证明与其他链路共享 `Scheduler` 时的资源边界 |
| TLS / HTTPS | ⚠️ loopback 与同步 HTTPS 生产基础能力已有回归 | TLS 仍未证明完整接入同一 async runtime；会话复用、handshake async 化与共享调度组合仍未收口 |

## 已完成但仍需记住的约束

- `test_async_multi_fd_concurrent.uya` 现在按“event loop 推进一步后 Ready”的契约断言，不再依赖旧的 `waker.is_woken()` 时序假设
- `async_compute` 的“运行中取消”不会抢占停止宿主计算，而是保证调用侧最终看到 `error.Cancelled`
- `TaskQueue<T>` 现已泛型化；默认队列以 legacy `64` 为起步容量但可自动增长，只有 `task_queue_new_with_capacity<T>()` 才保留调用方显式上限
- 复合表达式中的 `try @await` 现已支持赋值 RHS 与 return 表达式，固定回归见 `tests/test_async_compound_try_await.uya`
- direct `const r: !T = @await fut` 绑定现已纳入固定回归；但 parser 对 `catch { 0 - 1 }` 一类写法仍会打印假性的“意外的 token `}`”诊断
- 接口方法签名可写 `@async_fn`，但对接口来说这仍是“返回 future 的异步契约”，不是单独的新 ABI
- `@frame(foo)` 当前公开高层方法只有 `start` / `poll` / `stop`
- `Future<Future<T>>` 需要区分值类型与 async wrapper 两类：`tests/test_async_nested.uya` 已证明手工构造的 `Future<Future<i32>>` 可双层 poll；无 await 的 `@async_fn` 返回 `!Future<Future<T>>` 且 `return` 里同步 `try` 另一个 `!Future<T>` 的 wrapper 边界也已由 `tests/test_async_nested_future_poll.uya` 与 `tests/verify_async_nested_future_boundary.sh` 固定为正向回归

## 剩余 P2

- 跨平台 `EventLoop` 后端：macOS `kqueue` / Windows `IOCP`
- 更丰富 async formatting/helper（typed writer、`write_byte`、更高层格式化输出等）
- 多 interest `Waker`
- HTTP 连接池与 keep-alive 复用
- TLS 会话复用
- DNS `A/AAAA` 并发聚合
