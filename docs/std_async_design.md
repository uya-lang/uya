# std.async 异步标准库设计文档

**相关文档**：
- [std/libc 标准库设计](std_c_design.md) — 同步 I/O（`std.io`）、C 兼容层（`lib/libc`）
- [语言规范 第 18 章](uya.md#18-异步编程) — 异步编程语言核心（`@async_fn`、`@await`、`interface Future<T>`、`union Poll<T>`）
- [async_status_matrix.md](async_status_matrix.md) — async 实现现状总表（runtime / codegen / tests / docs）
- [todo_async_full_language_dynamic_resources.md](todo_async_full_language_dynamic_resources.md) — 当前 async 生产化权威 TODO（完整语法 + 动态资源）

## 概述

`std.async` 是 Uya 异步编程的标准库模块，基于语言核心类型（`interface Future<T>`、`union Poll<T>`、`struct Waker`）实现高级异步抽象。

**设计原则**：
- 基于语言核心的 `@async_fn` / `@await` / `Future<T>` / `Poll<T>`
- 零成本抽象：状态机栈分配，无运行时堆分配
- 显式控制：所有挂起必须 `@await`，无隐式行为
- 与 `std.io` 形成同步/异步对称设计

> **2026-06-17 注意**
>
> 本文档主要描述 async 标准库的目标设计与阶段性实现，并不单独证明当前实现已经达到“完整语法 + 动态资源 + 生产可用”。
> 当前权威 TODO 请看：[todo_async_full_language_dynamic_resources.md](todo_async_full_language_dynamic_resources.md)。
> 尤其要注意三点：
> 1. 当前实现里仍存在固定容量资源与 fallback 路径，和“全部动态化”目标并不一致。
> 2. 当前 `@async_fn` 的已通过回归不等于已经覆盖完整 Uya 函数体语法。
> 3. 本文中的“设计原则”包含目标态表述；评估当前真实状态时，应以源码、测试和权威 TODO 为准。
> 4. HTTP、DNS、TLS、`async_compute` 与 `Scheduler` 的分散回归只能证明各自阶段性主路径，尚不能当作“共享同一套稳定 async runtime 语义”已经统一验收。
> 5. 共享 runtime 口径以 [async_runtime_semantics_matrix.md](async_runtime_semantics_matrix.md) 为准；在该矩阵补齐统一 smoke 前，本文中的主路径、主链路、生产收口等表述都只表示局部阶段性能力。

## 架构概览

**当前实现快照**：`lib/std/async.uya` 提供 **`struct Waker`**（`wake/reset/is_woken`、单次 `fd + interest` I/O 注册请求、`eventfd` 绑定/关闭、`cancel/is_cancelled`）、**`union Poll<T>`**（Ready/Pending）、**`interface Future<T>`**、**`struct Future<T>`**（含 `state: Poll<T>`、`fn poll(...) Poll<T>`）、**`struct Task<T> : Future<T>`**（含 `task_ready`、`poll`）。统一异步错误现已收敛到 `EventLoopSlotsFull` / `TaskQueueFull` / `SchedulerStopped` / `FutureNotReady` / `AsyncFramePoolFull` / `Cancelled` / `WriteZero`。针对常见标量 **`i32` / `u32` / `usize`** 的 **`Future<!T>`** 路径，已导出 **`poll_ready_ok_*` / `future_ready_ok_*` / `task_ready_ok_*`**，便于自定义 `Future` 与测试构造 `Ready(ok(...))`。`std.async.io` 当前已收敛到 **`Future<!usize>`** 主路径：`MemAsyncWriter` / `MemAsyncReader` 已支持 `write` / `write_all` / `flush` 与 `read` / `read_exact`，`AsyncFd` 已支持 `read` / `read_exact` / `write` / `write_all` / `flush`；helper 层也已补上 **`async_write_bytes`**、**`async_write_cstr`**、**`async_print_to`**、**`async_println_to`**（含 bytes 变体）。其中 `AsyncFd` 在 `poll()` 时确保 `O_NONBLOCK`，并将 `EAGAIN` / `EWOULDBLOCK` 映射为 `Poll.Pending`；此时 future 会把读/写关注记录到 `Waker`，由 `Scheduler` 通过 `EventLoop.register()/poll()/deregister()` 驱动下一轮唤醒。`Scheduler` 现已同时提供 `scheduler_run_*_with_event_loop`、`scheduler_run_pair_i32_with_event_loop`、泛型 **`TaskQueue<T>`** / `TaskQueue_i32` / `TaskQueue_u32` / `TaskQueue_usize` 与 **`scheduler_run_task_queue_with_event_loop<T>`** / typed wrappers；`Pending` 时会为每个 `Waker` 同步 `eventfd + io fd` 注册，支持 Linux 跨线程/跨执行上下文 wake。取消语义在已覆盖路径中走通：`Waker.cancel()` / `TaskQueue.cancel()` 会把取消位显式传给 future，调度器在取消或完成时统一清理 `eventfd`、I/O 注册与 slot 资源，并以 `error.Cancelled` 写回结果路径。`std.thread.async_compute<T>` 已在自身回归中复用这一链路：未启动/排队/one-shot 任务可立即取消，已运行共享槽任务会在结果回收时稳定返回 `error.Cancelled`。`LinuxEpoll` 当前会在 `register()` 命中 slot 满载时自动扩容 slot / lookup / poll scratch 存储，并暴露当前注册数、历史峰值和扩容次数指标；`std.async_scheduler.async_runtime_metrics_linux_epoll()` 现已把这些 epoll 指标与 scheduler 自身的 frame/queue 指标汇总到统一快照。`poll()` 命中后按 fd 查找已注册 `Waker` 并调用 `wake()`。这一 readiness 路径同时被 `lib/std/http/http1_async.uya` 复用，用于 HTTP/1.1 客户端的 nonblocking connect/read/write。以上能力仍是阶段性覆盖：HTTP、DNS、TLS、`async_compute` 与 `Scheduler` 尚未通过同一共享 runtime 矩阵统一验收，固定容量资源、多 interest、跨平台后端、TLS async 化和组合取消语义仍是边界。语言/编译器侧现已支持把 `@async_fn` 放在结构体内部方法、外部方法块以及接口方法签名上，因此基于接口的 async 抽象可以直接通过 vtable 分派 `Future<!T>`；固定回归见 `tests/test_async_method_interface.uya`。编译器侧已补齐两处直接支撑队列的 codegen 能力：数组元素上的接口字段方法调用（如 `queue.slots[i].future.poll(...)`）可正确保留接口类型；结构体字段依赖收集也会跳过接口类型，避免误展开 `struct Future<T>` 模板。`test_async_await_parse.uya`、`test_task_std_async.uya`、`test_async_return_value.uya`、`test_async_nested.uya`、`test_std_async_waker.uya`、`test_async_io.uya`、`test_async_fd.uya`、`test_async_copy.uya`、`test_std_async_event.uya`、`test_std_async_scheduler.uya`、`test_async_multi_fd_concurrent.uya`、`test_std_thread.uya`、`test_async_compute_types.uya`、`test_async_method_interface.uya` 已通过相关 `--c99` 回归；这些分散测试证明对应子能力，不单独证明完整量产。**@async_fn 中可直接 `return T`**：无 `@await` 时自动包装为 `Future<T>{ state: Poll<T>.Ready(expr) }`，poll 立即返回 Ready。Checker 对单态/泛型名做基名匹配（如 `Future<T>`、`Future_i32` 可解析为接口/结构体 `Future`），方法解析失败时回退到基名查找。**nested future 的当前状态**：`Future<Future<T>>` 这个值类型本身可以双层 poll，`tests/test_async_nested.uya` 已固定手工构造的 `Future<Future<i32>>` 与单层 `!Future<i32>` handoff 两条正向回归；无 await 的 `@async_fn` 若返回 `!Future<Future<T>>`，且 `return` 表达式里同步 `try` 另一个 `!Future<T>`，当前也已通过 `tests/test_async_nested_future_poll.uya` 与 `tests/verify_async_nested_future_boundary.sh` 固定为 C99 发射和宿主 C 编译正向回归。编译器在结构体含泛型 union 字段时会先输出该 union 的单态定义（如 `Poll_i32`、`uya_tagged_Poll_i32`），且通过 arena 持久化 tagged 名避免重定义。**无 await 且返回 `!Future<T>` 的 @async_fn**：状态机形态为 `Future<!Future<T>>`，其 `struct uya_interface_*` / `struct uya_vtable_*` 在 `src/codegen/c99/function.uya` 中按需生成（不经过 `mono_instances`），并用 `is_struct_defined` 避免重复定义。以下为**目标**目录结构，后续按阶段拆分实现。

```
std/async/
├── io/             # 异步 I/O 抽象
│   ├── writer.uya  # AsyncWriter 接口
│   ├── reader.uya  # AsyncReader 接口
│   └── async_fd.uya # 基于文件描述符的异步 I/O 实现
├── task.uya        # Task<T>, Waker 完整实现
├── event/          # 平台事件循环后端
│   ├── common.uya  # 统一事件接口
│   ├── linux.uya   # epoll / io_uring
│   ├── macos.uya   # kqueue
│   └── windows.uya # IOCP
├── async_channel.uya # Channel<T>, MpscChannel<T>
└── scheduler.uya   # Scheduler 事件循环调度器
```

## 1. std.async.io - 异步 I/O 抽象层

**设计目标**：提供基于 `Future<T>` + `Waker` 的非阻塞 I/O 接口，与 `std.io` 形成同步/异步对称设计。

### 与 std.io（同步）的对比

| 维度 | `std.io` | `std.async.io` |
|------|----------|----------------|
| 返回类型 | `!usize` / `!void` | `Future<!usize>`（当前最小实现） |
| 执行方式 | 同步阻塞 | 状态机 + 非阻塞 |
| 使用场景 | 普通函数 | `@async_fn` 函数 |
| I/O 后端 | 直接系统调用 | poll + waker 事件驱动 |

**注意**：
- `std.io` 的同步接口返回 `!T`，**不能**被 `@await` 调用
- 在 `@async_fn` 中调用同步 `std.io` 方法虽然语法合法，但会**阻塞当前任务**
- 异步场景应使用 `std.async.io` 中的 `AsyncWriter` / `AsyncReader`

**当前现状补充**：
- 语言层已提供 `@error_id(err)`，可读取 `@syscall` 失败路径的 errno 数值
- `AsyncFd` 已将 `EAGAIN` / `EWOULDBLOCK` 映射为 `Poll.Pending`，并通过 `Waker` 记录 `fd + interest`
- `Scheduler` 已可在 `Pending` 时读取该 I/O 请求，调用 `EventLoop.register()/poll()/deregister()` 后再重试 future
- `Scheduler` 已有单任务、双任务与固定容量任务队列入口，可让多个 future 共享一次 `EventLoop.poll()` 与唤醒周期
- `LinuxEpoll.poll()` 已能在事件命中后唤醒对应 `Waker`
- 后续主要剩余多-interest `Waker`、更丰富的 async formatting/helper（例如 typed writer / `write_byte` / 更高层格式化输出）、跨平台 `EventLoop` 后端与更严格的唤醒安全性验证
- 实际代码中的 `AsyncWriter` / `AsyncReader` 已支持 `write_all` / `read_exact`；helper 层也已有 `async_write_bytes` / `async_write_cstr` / `async_print_to` / `async_println_to`。

### 核心接口

- [~] **AsyncWriter 接口**：统一的异步输出抽象（当前已实现 `write` / `write_all` / `flush`）
  ```uya
  export interface AsyncWriter {
      fn write(self: &Self, data: &[u8]) Future<!usize>;
      fn write_all(self: &Self, data: &[u8]) Future<!usize>;
      fn write_str(self: &Self, s: &[i8]) Future<!usize>;
      fn flush(self: &Self) Future<!usize>;
  }
  ```

- [~] **AsyncReader 接口**：统一的异步输入抽象（当前已实现 `read` / `read_exact`）
  ```uya
  export interface AsyncReader {
      fn read(self: &Self, buf: &[u8]) Future<!usize>;
      fn read_exact(self: &Self, buf: &[u8]) Future<!usize>;
  }
  ```

- [~] **辅助函数**（当前已提供 `Future<!usize>` 版）：
  - `async_write_bytes(writer: AsyncWriter, data: &[byte]) Future<!usize>`
  - `async_write_cstr(writer: AsyncWriter, text: &const byte) Future<!usize>`
  - `async_print_to(writer: AsyncWriter, text: &const byte) Future<!usize>`
  - `async_println_to(writer: AsyncWriter, text: &const byte) Future<!usize>`

**历史计划口径**：早期曾把 `AsyncWriter` / `AsyncReader` 接口作为待新建拆分模块描述；当前实现仍主要集中在 `lib/std/async.uya` 等文件中。下面的“涉及”路径是目标结构说明，不表示这些模块已经按该结构完成落地，也不表示共享 runtime 主链路已收口。

**涉及**：目标结构中的 `std/async/io/writer.uya`、`std/async/io/reader.uya`

### 实现原理

异步 I/O 基于 `poll()` + `Waker` 模式，底层使用平台事件机制：

```uya
// std/async/io/async_fd.uya
struct AsyncFd {
    fd: i32,
    waker: Option<&Waker>
}

AsyncFd : AsyncWriter {
    fn write(self: &Self, data: &[u8]) Future<!usize> {
        // 内部实现：
        // 1. poll() 时确保 fd 为 O_NONBLOCK
        // 2. 尝试非阻塞写入
        // 3. 如果返回 EAGAIN，向 Waker 记录“等待可写 fd”
        // 4. Scheduler 代为 register/poll/deregister
        // 5. EventLoop 命中后 wake，再次 poll() 重试 syscall
    }
}

AsyncFd : AsyncReader {
    fn read(self: &Self, buf: &[u8]) Future<!usize> {
        // 类似 write，当前已接到 Waker + EventLoop 的最小闭环
    }
}
```

**涉及**：目标结构中的 `std/async/io/async_fd.uya`

### 使用示例

```uya
use std.async.io;

@async_fn
fn fetch_and_write(reader: &AsyncReader, writer: &AsyncWriter) !Future<void> {
    var buf: [u8: 4096] = [];
    const n = try @await reader.read(&buf);
    try @await writer.write(&buf[0:n]);
}
```

## 2. std.async.task - 异步任务

### Task\<T\>

- 异步任务的包装类型
- 实现 `Future<T>` 接口（即实现 `poll(self: &Self, waker: &Waker) union Poll<T>`）
- 提供任务生命周期管理

### Waker

- **定义**：唤醒器，用于在异步操作就绪时通知异步运行时重新调度任务
- **作用**：
  - 当异步操作（如 I/O、定时器等）就绪时，通过 `waker.wake()` 通知运行时
  - 运行时收到通知后，会重新调用 `poll()` 方法检查任务状态
  - 实现高效的异步任务调度，避免忙等待（busy-waiting）
- **当前阶段**：
  - 已落地最小状态语义：`wake()`、`reset()`、`is_woken()`
  - 已可暂存单次 I/O interest（`fd + readable/writable`）并绑定 `eventfd`，供调度器同步注册 `io fd + eventfd`
  - `Scheduler` 可利用该状态在 `poll()` 内同步唤醒时直接重试，避免额外一次 `EventLoop.poll()`
  - `cancel()` / `is_cancelled()` 已落地，Future 可在 `poll()` 内显式检查并返回 `error.Cancelled`
  - 已有双任务、泛型 `TaskQueue<T>` 与跨线程/跨执行上下文 `eventfd` wake 的验证入口；后续主要剩余多-interest `Waker`、跨平台后端与更严格的唤醒安全性验证
- **编译期验证**：
  - 编译期验证唤醒安全性（Waker 使用）
  - 确保 Waker 不会被错误使用或泄漏

**涉及**：新建 `std/async/task.uya`

## 3. std.async.event - 平台事件后端

异步 I/O 需要平台特定的事件通知机制：

| 平台 | 事件机制 | 模块 |
|------|---------|------|
| Linux | `epoll` / `io_uring` | `std/async/event/linux.uya` |
| macOS | `kqueue` | `std/async/event/macos.uya` |
| Windows | `IOCP` | `std/async/event/windows.uya` |

- [x] **统一事件接口**（当前实现于 `lib/std/async_event.uya`，模块路径 `use std.async_event`）：
  ```uya
  export interface EventLoop {
      fn register(self: &Self, fd: i32, interest: EventKind, waker: &Waker) !i32;
      fn deregister(self: &Self, fd: i32) !i32;
      fn poll(self: &Self, timeout_ms: i32) !i32;
  }

  export union EventKind {
      Readable: void,
      Writable: void,
      ReadWrite: void
  }
  ```

- [x] **Linux 实现**（`lib/std/async_event.uya`，`struct LinuxEpoll : EventLoop`）：
  - 基于 `libc.syscall` 的 `sys_epoll_create1` / `sys_epoll_ctl` / `sys_epoll_wait`（底层为 `@syscall`）
  - epoll 常量（含 `EPOLLET`）与 `EpollEvent` 已加入 `lib/libc/syscall.uya` 与 `lib/syscall/linux.uya`
  - `register()` / `deregister()` 当前成功返回 `0`；`poll()` 会在事件命中后按 fd 查找并 `wake()` 已注册 `Waker`
  - `slot_capacity` / `event_capacity` 为初始容量；slot / lookup / poll scratch 存储在满载时自动扩容，不再把第三个、第六十五个或第一千零二十五个合法 fd 直接判成产品错误
  - **显式状态机与 fd 复用安全**：引入 `SLOT_STATE_EMPTY` / `SLOT_STATE_REGISTERED` 显式状态、`slot_generations` 代际数组与 `next_generation` 计数器，防止 fd 关闭复用后的 `ENOENT` / `EEXIST` 混乱
  - **运行时指标**：测试/调试口径已暴露 `linux_epoll_registered_count()`、`linux_epoll_peak_registered_count()`、`linux_epoll_resize_count()`
  - **timeout/deadline 支持**：`block_on_with_event_loop_deadline<T>` 可在 EventLoop 层设置总超时；`lib/std/http/http1_async.uya` 与 `lib/tls/https.uya` 在各 I/O 边界（connect、read、write、handshake）采用 deadline-based 超时策略
  - 端到端测试 `test_std_async_event.uya`、`test_epoll_syscall.uya`、`test_std_async_event_fd_reuse.uya` 已通过 `--c99` 与 `--uya --c99`（codegen 已修复）

- [ ] **macOS 实现**（`std/async/event/macos.uya`）：
  - 基于 `kqueue` / `kevent` 系统调用

- [ ] **Windows 实现**（`std/async/event/windows.uya`）：
  - 基于 IOCP（I/O Completion Ports）

**涉及**：新建 `std/async/event/` 目录

## 4. std.async.channel - 异步通道

- [x] **Channel\<T\>**：
  - 单槽异步通道，用于异步任务间通信
  - 当前提供 `send/recv -> Future<_>` 最小接口
  - 仅保留泛型入口（不再维护 `Channel_i32` / `Channel_usize` 兼容别名）

- [x] **MpscChannel\<T\>**：
  - 多生产者、单消费者、运行时容量版通道
  - 当前以原子锁 + 环形队列实现，容量由调用方传入
  - 已覆盖单槽 Pending 与多槽 FIFO/环回；Send/Sync 约束推导仍待后续实现

**涉及**：`lib/std/async_channel.uya`、`lib/std/collections/ring_queue.uya`

## 5. std.async.scheduler - 调度器

- [~] **Scheduler**：
  - 异步运行时调度器
  - 基于事件循环实现
  - 零堆分配，栈分配状态机
  - 当前已覆盖单任务、双任务与固定容量任务队列共享 `EventLoop` 的最小运行入口
  - 后续管理所有 `Task<T>` 的生命周期
  - 集成 `EventLoop` 处理 I/O 事件

**涉及**：新建 `std/async/scheduler.uya`

## 6. 实现优先级

| 阶段 | 内容 | 优先级 | 依赖 |
|------|------|--------|------|
| 1 | **语言核心**（`@async_fn`, `@await`, `interface Future<T>`, `union Poll<T>`） | ⭐⭐⭐⭐⭐ | 编译器 |
| 2 | **std.async.task**（`Task<T>`, `Waker`） | ⭐⭐⭐⭐ | 阶段 1 |
| 3 | **std.async.event**（`EventLoop` + Linux epoll） | ⭐⭐⭐⭐ | 阶段 1 + `@syscall` |
| 4 | **std.async.io**（`AsyncWriter`, `AsyncReader`, `AsyncFd`） | ⭐⭐⭐⭐ | 阶段 2 + 3 |
| 5 | **std.async.scheduler**（`Scheduler`） | ⭐⭐⭐ | 阶段 2 + 3 |
| 6 | **std.async.channel**（`Channel<T>`, `MpscChannel<T>`） | ⭐⭐⭐ | 阶段 2 |
| 7 | **多平台事件后端**（macOS kqueue, Windows IOCP） | ⭐⭐ | 阶段 3 + `std.cfg` |

**第一个里程碑**（目标态：最小可用）：
完成阶段 1-4，可以在 Linux 上使用异步 I/O。

**第二个里程碑**（目标态：完整运行时）：
完成阶段 1-6，具备完整的异步运行时支持（调度器 + 通道）。

**第三个里程碑**（目标态：跨平台）：
完成阶段 1-7，支持 Linux / macOS / Windows 异步编程。

---

## 文档评审要点（供维护参考）

- **与 uya.md 一致**：语言核心类型采用规范中的精确写法——`interface Future<T>`、`union Poll<T>`、`struct Waker`；阶段 1 与 uya.md 第 18.1/18.3 节对齐。
- **取消与显式控制**：uya.md 要求“取消必须显式检查 `is_cancelled()`”；本设计在概述中体现了“显式控制”，若后续增加任务取消 API，需与 18 章保持一致。
- **辅助函数归属**：`async_print_to` / `async_println_to` 未指定所在文件，实现时可放在 `std/async/io/writer.uya` 或单独工具模块。
- **Option 依赖**：`AsyncFd` 示例使用 `Option<&Waker>`，依赖 `std.core.option`（见 [std_c_design](std_c_design.md)）；实现时需确保 use 或本模块提供等价类型。
