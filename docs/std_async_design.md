# std.async 异步标准库设计文档

**相关文档**：
- [std.c 标准库设计](std_c_design.md) — 同步 I/O（`std.io`）、C 标准库替代（`std.c`）
- [语言规范 第 18 章](uya.md) — 异步编程语言核心（`@async_fn`、`@await`、`Future<T>`、`Poll<T>`）

## 概述

`std.async` 是 Uya 异步编程的标准库模块，基于语言核心类型（`Future<T>`、`Poll<T>`、`Waker`）实现高级异步抽象。

**设计原则**：
- 基于语言核心的 `@async_fn` / `@await` / `Future<T>` / `Poll<T>`
- 零成本抽象：状态机栈分配，无运行时堆分配
- 显式控制：所有挂起必须 `@await`，无隐式行为
- 与 `std.io` 形成同步/异步对称设计

## 架构概览

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
├── channel.uya     # Channel<T>, MpscChannel<T>
└── scheduler.uya   # Scheduler 事件循环调度器
```

## 1. std.async.io - 异步 I/O 抽象层

**设计目标**：提供基于 `Future<T>` + `Waker` 的非阻塞 I/O 接口，与 `std.io` 形成同步/异步对称设计。

### 与 std.io（同步）的对比

| 维度 | `std.io` | `std.async.io` |
|------|----------|----------------|
| 返回类型 | `!usize` / `!void` | `!Future<usize>` / `!Future<void>` |
| 执行方式 | 同步阻塞 | 状态机 + 非阻塞 |
| 使用场景 | 普通函数 | `@async_fn` 函数 |
| I/O 后端 | 直接系统调用 | poll + waker 事件驱动 |

**注意**：
- `std.io` 的同步接口返回 `!T`，**不能**被 `@await` 调用
- 在 `@async_fn` 中调用同步 `std.io` 方法虽然语法合法，但会**阻塞当前任务**
- 异步场景应使用 `std.async.io` 中的 `AsyncWriter` / `AsyncReader`

### 核心接口

- [ ] **AsyncWriter 接口**：统一的异步输出抽象
  ```uya
  export interface AsyncWriter {
      fn write(self: &Self, data: &[u8]) !Future<usize>;
      fn write_str(self: &Self, s: &[i8]) !Future<usize>;
      fn flush(self: &Self) !Future<void>;
  }
  ```

- [ ] **AsyncReader 接口**：统一的异步输入抽象
  ```uya
  export interface AsyncReader {
      fn read(self: &Self, buf: &[u8]) !Future<usize>;
      fn read_exact(self: &Self, buf: &[u8]) !Future<void>;
  }
  ```

- [ ] **辅助函数**：
  - `async_print_to(writer: &AsyncWriter, s: &[i8]) !Future<void>`
  - `async_println_to(writer: &AsyncWriter, s: &[i8]) !Future<void>`

**涉及**：新建 `std/async/io/writer.uya`、`std/async/io/reader.uya`

### 实现原理

异步 I/O 基于 `poll()` + `Waker` 模式，底层使用平台事件机制：

```uya
// std/async/io/async_fd.uya
struct AsyncFd {
    fd: i32,
    waker: Option<&Waker>
}

AsyncFd : AsyncWriter {
    fn write(self: &Self, data: &[u8]) !Future<usize> {
        // 内部实现：
        // 1. 尝试非阻塞写入
        // 2. 如果返回 EAGAIN，注册到事件循环，返回 Pending
        // 3. 事件就绪时，waker.wake() 唤醒任务
        // 4. 重新 poll 时完成写入，返回 Ready
    }
}

AsyncFd : AsyncReader {
    fn read(self: &Self, buf: &[u8]) !Future<usize> {
        // 类似 write，基于非阻塞读取 + 事件通知
    }
}
```

**涉及**：新建 `std/async/io/async_fd.uya`

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
- 实现 `Future<T>` 接口
- 提供任务生命周期管理

### Waker

- **定义**：唤醒器，用于在异步操作就绪时通知异步运行时重新调度任务
- **作用**：
  - 当异步操作（如 I/O、定时器等）就绪时，通过 `waker.wake()` 通知运行时
  - 运行时收到通知后，会重新调用 `poll()` 方法检查任务状态
  - 实现高效的异步任务调度，避免忙等待（busy-waiting）
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

- [ ] **统一事件接口**（`std/async/event/common.uya`）：
  ```uya
  export interface EventLoop {
      fn register(self: &Self, fd: i32, interest: EventKind, waker: &Waker) !void;
      fn deregister(self: &Self, fd: i32) !void;
      fn poll(self: &Self, timeout_ms: i32) !i32;
  }

  export union EventKind {
      Readable: void,
      Writable: void,
      ReadWrite: void
  }
  ```

- [ ] **Linux 实现**（`std/async/event/linux.uya`）：
  - 基于 `epoll_create1` / `epoll_ctl` / `epoll_wait` 系统调用
  - 可选 `io_uring` 高性能后端（需 Linux 5.1+）
  - 通过 `@syscall` 内置函数实现，零外部依赖

- [ ] **macOS 实现**（`std/async/event/macos.uya`）：
  - 基于 `kqueue` / `kevent` 系统调用

- [ ] **Windows 实现**（`std/async/event/windows.uya`）：
  - 基于 IOCP（I/O Completion Ports）

**涉及**：新建 `std/async/event/` 目录

## 4. std.async.channel - 异步通道

- [ ] **Channel\<T\>**：
  - 异步通道，用于异步任务间通信
  - 基于 `atomic T` 和 `union` 实现
  - 零运行时锁，编译期验证并发安全

- [ ] **MpscChannel\<T\>**：
  - 多生产者单消费者通道
  - 基于原子操作实现
  - 编译期验证 Send/Sync 约束

**涉及**：新建 `std/async/channel.uya`

## 5. std.async.scheduler - 调度器

- [ ] **Scheduler**：
  - 异步运行时调度器
  - 基于事件循环实现
  - 零堆分配，栈分配状态机
  - 管理所有 `Task<T>` 的生命周期
  - 集成 `EventLoop` 处理 I/O 事件

**涉及**：新建 `std/async/scheduler.uya`

## 6. 实现优先级

| 阶段 | 内容 | 优先级 | 依赖 |
|------|------|--------|------|
| 1 | **语言核心**（`@async_fn`, `@await`, `Future<T>`, `Poll<T>`） | ⭐⭐⭐⭐⭐ | 编译器 |
| 2 | **std.async.task**（`Task<T>`, `Waker`） | ⭐⭐⭐⭐ | 阶段 1 |
| 3 | **std.async.event**（`EventLoop` + Linux epoll） | ⭐⭐⭐⭐ | 阶段 1 + `@syscall` |
| 4 | **std.async.io**（`AsyncWriter`, `AsyncReader`, `AsyncFd`） | ⭐⭐⭐⭐ | 阶段 2 + 3 |
| 5 | **std.async.scheduler**（`Scheduler`） | ⭐⭐⭐ | 阶段 2 + 3 |
| 6 | **std.async.channel**（`Channel<T>`, `MpscChannel<T>`） | ⭐⭐⭐ | 阶段 2 |
| 7 | **多平台事件后端**（macOS kqueue, Windows IOCP） | ⭐⭐ | 阶段 3 + `std.target` |

**第一个里程碑**（最小可用）：
完成阶段 1-4，可以在 Linux 上使用异步 I/O。

**第二个里程碑**（完整运行时）：
完成阶段 1-6，具备完整的异步运行时支持（调度器 + 通道）。

**第三个里程碑**（跨平台）：
完成阶段 1-7，支持 Linux / macOS / Windows 异步编程。

