# Async Frame 生命周期命名统一设计

**状态**：已实现
**最后更新**：2026-04-16（正文）；2026-10-19 加核对头
**相关文档**：
- [async_frame_allocation_design.md](async_frame_allocation_design.md) - `@frame(foo)`、pinned 语义、caller-owned storage 背景
- [todo_async_frame_allocation.md](todo_async_frame_allocation.md) - async frame 分配与生命周期 TODO
- [std_async_design.md](std_async_design.md) - `Future<T>` / `Poll<T>` / `Waker` / `release` 现状

> **核对头（2026-10-19）**：命名方案与源码一致。`*_frame_start` / `*_frame_stop` 由 `src/codegen/c99/function.uya:7566` / `:7570`（并发前向声明 `:6934-6938`）生成，`@frame.start` / `@frame.stop` 的低层调用别名为 `"_frame_start"` / `"_frame_stop"`（`src/codegen/c99/expr.uya:2419/2423`）；高层方法面由回归 `tests/test_async_frame_methods.uya` 固定（`start` / `poll` / `stop` 三方法）。`@frame` 语法解析在 `src/parser/types.uya:397`。

**当前实现备注**：
- 编译器现已生成 `*_frame_start` / `*_poll` / `*_frame_stop`
- `@frame(foo)` 现已公开 `frame.start(...)` / `frame.poll(&waker)` / `frame.stop()`
- 为兼容旧代码，底层仍保留 `*_frame_init` / `*_frame_drop_fields` 转发别名

## 1. 背景

当前编译器已经为每个 `@async_fn` 生成一组 caller-owned frame helper：

- `foo_frame_init(frame, args...)`
- `foo_poll(frame, waker)`
- `foo_frame_drop_fields(frame)`

它们已经足以支撑以下两类用法：

1. **局部根 frame**
   - `var root: @frame(foo);`
   - `foo_frame_init(&root, args...)`
   - `foo_poll(&root, &waker)`

2. **长期持有的 caller-owned frame**
   - 例如 benchmark 中由 `BenchClientHandle` 自己维护 raw storage + live bit，再转成 `&@frame(handle_bench_client)` 驱动。

但当前命名存在两个问题：

- `frame_init` / `frame_drop_fields` 太偏向实现细节，不像一个稳定的生命周期 API
- 用户在心智上会把它们和“启动一次运行”“停止一次运行”对应起来，而不是“初始化字段”“递归 drop 子字段”

这会导致高层 API 很难自然落成方法形式。相比之下：

- `frame.start(...)`
- `frame.poll(&waker)`
- `frame.stop()`

更接近 caller-owned frame 的实际使用方式。

## 2. 目标

本设计的目标是统一 async frame 生命周期命名，并为后续方法糖提供明确规范。

具体目标：

- 将底层 helper 命名从 `*_frame_init` / `*_frame_drop_fields` 统一为 `*_frame_start` / `*_frame_stop`
- 为 `@frame(foo)` 定义稳定的高层方法名：`start` / `poll` / `stop`
- 明确 `@frame` 生命周期与 `Future.release()` 的边界，避免混淆
- 不引入新的内置类型或新的语法构造器
- 让 benchmark 这类 caller-owned 场景能自然表达“复用同一块 storage，多次 start/stop”

非目标：

- 本设计**不**引入 `@slot(...)`
- 本设计**不**改变 `Future<T>` 接口里的 `release`
- 本设计**不**重写 async lowering / frame pool 分配策略

## 3. 设计结论

### 3.1 统一命名

| 层级 | 当前名称 | 新名称 | 说明 |
| --- | --- | --- | --- |
| 低层 helper | `foo_frame_init` | `foo_frame_start` | 在 caller-owned storage 上开始一次 frame 运行 |
| 低层 helper | `foo_poll` | `foo_poll` | 保持不变 |
| 低层 helper | `foo_frame_drop_fields` | `foo_frame_stop` | 停止当前运行，释放内部资源，不释放 storage |
| 高层方法 | 无 | `frame.start(...)` | 映射到 `foo_frame_start(...)` |
| 高层方法 | 无 | `frame.poll(&waker)` | 映射到 `foo_poll(...)` |
| 高层方法 | 无 | `frame.stop()` | 映射到 `foo_frame_stop(...)` |

### 3.2 为什么不用 `drop`

`drop` 在语言层已经是“按值析构”的既有语义：

- 签名要求 `drop(self: T) -> void`
- 适用于普通值类型离开作用域时的销毁

而 `@frame` 的 caller-owned 语义不是“销毁整个值”，而是：

- 结束这次运行
- 释放内部挂着的 child future / inline child frame
- 保留 storage，以便后续再次 `start(...)`

因此 `@frame.stop()` 比 `@frame.drop()` 更准确。

### 3.3 为什么不用 `release`

`release` 已经属于 `Future<T>` 运行时接口：

- `Future.release()` 表示“这个 first-class future 对象可以被回收了”
- 对 pool/heap-backed future，它通常还会回收对象自身存储

caller-owned `@frame` 的 `stop()` 只释放**内部占用**，不释放 storage 本体。  
如果在 `@frame` 上也叫 `release()`，很容易让用户误以为那块 frame 内存也被回收。

因此：

- `Future<T>` 继续使用 `release`
- `@frame(foo)` 使用 `stop`

## 4. 用户可见语义

### 4.1 推荐写法

```uya
var frame: @frame(handle_bench_client);

frame.start(ctx, cfd, slot);

while true {
    const p: Poll<!usize> = frame.poll(&waker);
    match p {
        .Ready(_) => {
            frame.stop();
            break;
        },
        .Pending(_) => {
            if should_cancel() {
                frame.stop();
                break;
            }
        },
    }
}
```

### 4.2 低层等价形式

```uya
var frame: @frame(handle_bench_client);

handle_bench_client_frame_start(&frame, ctx, cfd, slot);
const p: Poll<!usize> = handle_bench_client_poll(&frame, &waker);
handle_bench_client_frame_stop(&frame);
```

### 4.3 benchmark 场景

当前 benchmark 里的手写 handle：

- `bench_client_handle_init(...)`
- `bench_client_handle_poll(...)`
- `bench_client_handle_release(...)`

本质上就是一个还未内建的 `@frame(handle_bench_client)` owner。  
统一命名后，它在语义上会更接近：

- `start`：开始处理一个新连接
- `poll`：推进连接处理
- `stop`：停止当前连接处理并清空内部子状态

## 5. 生命周期模型

### 5.1 外部可见状态

从 caller-owned `@frame` 的角度，只区分两种生命周期状态：

1. `Inactive`
   - 从未启动
   - 或者已经 `stop()`
   - 当前不可 `poll()`

2. `Active`
   - 已 `start(...)`
   - 尚未 `stop()`
   - 可以 `poll()`
   - 即使最近一次 `poll()` 已返回 `Ready`，在生命周期上仍视为 `Active`，直到显式 `stop()`

### 5.2 规则

- `start(...)`
  - 从 `Inactive -> Active`
  - 允许对已 `Active` 的 frame 重启，语义等价于先 `stop()` 再 `start(...)`

- `poll(&waker)`
  - 仅允许在 `Active` 状态调用
  - `Pending` / `Ready` 都**不会**自动让 frame 回到 `Inactive`

- `stop()`
  - 从 `Active -> Inactive`
  - 释放内部 child future / inline child frame
  - 不释放 frame 自身 storage
  - 允许重复调用；对 `Inactive` frame 为幂等 no-op

### 5.3 为什么 `Ready` 后仍要求 `stop`

`poll == Ready` 只表示“这次运行已经给出最终结果”，不表示：

- frame storage 已经可安全复用
- 所有 child future 都已经被统一清理
- 这个 frame 已经回到“未运行”状态

因此 caller-owned frame 与 first-class `Future<T>` 不同：

- first-class `Future<T>` 常由 `release()` 结束生命周期
- caller-owned `@frame` 必须显式 `stop()` 才能复用 storage

## 6. 存储与初始化规则

### 6.1 编译器保证的零初始化

为了让 `start/stop` 命名拥有稳定语义，编译器应保证：

- `var f: @frame(foo);` 生成的本地变量为零初始化
- `@frame(...)` 作为结构体字段、且整个结构体走 `T{}` / `[]` / 零初始化路径时，也处于零初始化状态

这使得以下行为成立：

- 对新声明但尚未 `start()` 的 frame 调用 `stop()` 是安全 no-op
- `start()` 可以可靠判断“当前是否已 active”

### 6.2 用户自管 raw storage

若用户自行维护 raw storage，再手动 cast 为 `&@frame(foo)`，则需要满足：

- 第一次 `frame_start` 前，这块 storage 必须先被清零

例如：

```uya
var storage: [usize: N] = [];
const f: &@frame(foo) = @ptr_from_usize(@usize_from_ptr(&storage[0] as &void)) as &@frame(foo);
f.start(...);
```

这是合法的，因为 `storage` 用 `[]` 零初始化。

## 7. 生成代码与 ABI 规范

### 7.1 保留 `foo_poll`

`foo_poll` 不改名，理由是：

- 现有 vtable 已经复用它
- `poll` 这个名字本身已经与 `Future<T>` / `Poll<T>` 语义一致
- 改成 `foo_frame_poll` 收益有限，但会扩大 ABI 变更范围

因此 lifecycle 相关的命名统一仅覆盖：

- `*_frame_init -> *_frame_start`
- `*_frame_drop_fields -> *_frame_stop`

### 7.2 新 helper 规范

每个 `@async_fn foo(args...) Future<T>` 生成：

- `foo_poll(frame: &@frame(foo), waker: &Waker) Poll<T>`
- `foo_frame_start(frame: &@frame(foo), args...) void`
- `foo_frame_stop(frame: &@frame(foo)) void`

### 7.3 兼容期别名

为了避免一次性打断所有现有 benchmark / 测试 / 可能的外部 C 集成，建议保留一个兼容期：

- 继续生成旧名 wrapper：
  - `foo_frame_init(...)` -> 转调 `foo_frame_start(...)`
  - `foo_frame_drop_fields(...)` -> 转调 `foo_frame_stop(...)`

兼容期结束后再删除旧名。

## 8. `frame_start` / `frame_stop` 的精确定义

### 8.1 `frame_start`

`frame_start` 的语义是：

1. 若 frame 当前为 `Active`，先执行 `frame_stop`
2. 将 frame 置为新的 `Active` 运行实例
3. 写入参数字段
4. 重置状态机运行所需的内部状态

建议实现要求：

- `frame_start` 对零初始化但未启动的 frame 直接可用
- `frame_start` 对已启动 frame 可重入调用，等价于 restart

### 8.2 `frame_stop`

`frame_stop` 的语义是：

1. 若 frame 当前为 `Inactive`，直接返回
2. 若 frame 当前持有 child future，则调用其 `release`
3. 递归停止所有 inline child frame
4. 将当前 frame 重新置回 `Inactive`

建议实现要求：

- 幂等
- 不 double-release
- 结束后允许再次 `frame_start`

### 8.3 `poll` 在非法状态下的行为

`poll` 对 `Inactive` frame 的调用属于程序错误。

建议语义：

- debug / sanitizer 路径下直接 `abort()` 并给出明确诊断
- 非 debug 路径至少保持一致的 fail-fast 行为

不建议返回 `Pending` 来掩盖错误，因为这会让生命周期 bug 难以定位。

## 9. 语言与编译器改动

### 9.1 Parser

无需新增语法。  
直接复用现有成员方法调用语法：

- `frame.start(...)`
- `frame.poll(...)`
- `frame.stop()`

### 9.2 Checker

checker 需要把 `@frame(foo)` 视为一种带编译器合成方法的特殊 struct：

- `start(self: &Self, <foo params...>) -> void`
- `poll(self: &Self, waker: &Waker) -> Poll<T>`
- `stop(self: &Self) -> void`

需要修改的逻辑点：

- `member_access`：识别 `@frame` 上的 `start/poll/stop`
- `call_expr`：为合成方法补参数个数与类型检查
- 诊断：对 `drop/release` 给出更明确的 note，提示改用 `stop`

### 9.3 Codegen

codegen 需要：

- 生成 `*_frame_start` / `*_frame_stop`
- 为旧名生成兼容 wrapper
- 将 `frame.start(...)` 降成 `*_frame_start(&frame, ...)`
- 将 `frame.poll(&waker)` 降成 `*_poll(&frame, &waker)`
- 将 `frame.stop()` 降成 `*_frame_stop(&frame)`

### 9.4 `@frame` 本地变量零初始化

为了支持 `stop()` 幂等与 restart 语义，codegen 还应补齐：

- `var f: @frame(foo);`
  - 生成为零初始化，而不是未初始化的 C 局部变量

这一点属于行为增强，不只是命名替换。

## 10. 对 `Future<T>` 的影响

### 10.1 保持 `Future.release()` 不变

`Future<T>` 接口继续保持：

```uya
interface Future<T> {
    fn poll(self: &Self, waker: &Waker) Poll<T>;
    fn release(self: &Self) void;
}
```

原因：

- 它已经是运行时 ABI 的一部分
- 它表达的是“回收这个 first-class future 对象”
- 它既适用于 heap/pool-backed future，也适用于手写 future

### 10.2 `@frame.stop()` 与 `Future.release()` 的区别

| API | 作用对象 | 释放内部资源 | 释放对象自身 storage |
| --- | --- | --- | --- |
| `Future.release()` | first-class future 值 | 是 | 通常是 |
| `@frame.stop()` | caller-owned frame | 是 | 否 |

## 11. 迁移策略

### 11.1 代码迁移

现有手写调用点统一替换：

- `foo_frame_init(...)` -> `foo_frame_start(...)`
- `foo_frame_drop_fields(...)` -> `foo_frame_stop(...)`

如果方法糖同时落地，则业务代码优先迁移到：

- `frame.start(...)`
- `frame.poll(...)`
- `frame.stop()`

### 11.2 benchmark 迁移

`benchmarks/http_bench_async_epoll_await_stack.uya` 可以逐步收敛为：

- `bench_client_handle_init` -> `bench_client_handle_start`
- `bench_client_handle_release` -> `bench_client_handle_stop`

再进一步收敛到直接在 owner 上转发 `frame.start/poll/stop`。

### 11.3 文档迁移

以下文档需要同步更新：

- `async_frame_allocation_design.md`
- `todo_async_frame_allocation.md`
- 任意引用 `frame_init` / `frame_drop_fields` 的 benchmark 或设计说明

## 12. 测试计划

### 12.1 checker / parser

- `@frame(foo)` 可识别 `start/poll/stop`
- `@frame(foo)` 上调用 `drop/release` 报出可理解错误
- `start` 参数数量和类型检查正确
- `stop` 无参数

### 12.2 codegen

- 生成 `*_frame_start` / `*_frame_stop`
- 旧名 wrapper 仍可链接
- `frame.start(...)` 正确降为 helper 调用
- `var f: @frame(foo);` 生成零初始化

### 12.3 运行时

- `start -> poll -> stop` 正常
- `stop` 幂等
- `start` 可 restart
- `poll` on inactive fail-fast
- inline child frame 在 `stop` 时递归释放

### 12.4 回归

- `tests/test_async_frame_stack_ok.uya`
- `tests/test_async_frame_align_pool.uya`
- `benchmarks/http_bench_async_epoll_await_stack.uya`

## 13. 分阶段落地建议

### Phase 1：底层 helper 重命名

- 生成 `*_frame_start` / `*_frame_stop`
- 保留旧名别名
- 更新 benchmark / 文档

### Phase 2：`@frame` 方法糖

- checker 识别 `start/poll/stop`
- codegen 降成 helper 调用

### Phase 3：语义补齐

- `@frame` 局部变量默认零初始化
- `stop` 幂等
- restart 语义落地
- `poll(inactive)` fail-fast

## 14. 最终建议

推荐采用以下统一口径：

- 高层：`frame.start(...) / frame.poll(...) / frame.stop()`
- 低层：`*_frame_start / *_poll / *_frame_stop`
- runtime interface：`Future.release()` 保持不变

这样可以同时满足三件事：

1. caller-owned frame 的 API 更像“启动 / 轮询 / 停止”而不是“初始化字段 / drop 字段”
2. `Future.release()` 与 `@frame.stop()` 的语义边界更清晰
3. 不需要引入新的内置构造器或新的 ownership 语法，也能把现有 benchmark 的样板明显收敛
