# Uya 微容器系统调用 ABI 规范

> **实现状态（2026-10-19 核对，v0.10.4）**：syscall ABI 在 `lib/std/microapp/abi.uya` 与生成 C 的
> `uya_microapp_bridge_dispatch*` 落地；x86_64 / aarch64 hosted call-gate 已走 bridge slot，
> `rv32_baremetal_softvm` / `xtensa_baremetal_softvm` 走 trap profile。回归见 `make microapp-check`
> 与 `tests/run_kernel_payload.sh`。下文是规范原文，字段以 `abi.uya` 为准。

**版本**: v1.3  
**日期**: 2026-04-02  
**适用平台**: CH32V003（RV32）/ ESP32（Xtensa）/ RV1106（兼容模式）  
**关联文档**: `docs/microcontainer/requirements_v1.3.md`

---

## 1. 设计目标

本规范定义容器态与内核态之间的唯一调用边界，目标如下：

- 调用开销可界定
- 参数语义可审计
- 错误返回可编程处理
- 阻塞行为与可重入规则可验证

---

## 2. 容器侧接口

容器代码仅允许以下内建入口：

```uya
syscall(number: u32, arg1: u32, arg2: u32) !u32
```

说明：

- `number` 为系统调用号。
- `arg1`、`arg2` 为调用参数，指针参数一律按容器虚拟地址传入。
- 返回 `!u32`，成功返回值位于 `u32`，失败返回错误码联合。

---

## 3. Trap 与寄存器约定

### 3.1 触发方式

- 容器通过 `ecall` 进入内核 trap 入口。

### 3.2 寄存器约定

- `a7`: syscall number（输入）
- `a0`: arg1（输入）/ value（成功返回）
- `a1`: arg2（输入）/ errno（失败返回）
- `a2`: 保留，当前必须为 0
- `t0..t6`: 可破坏
- `s0..s11`: 由内核按 ABI 约定保存恢复

### 3.3 返回编码

- 成功：`a0 = value`，`a1 = 0`
- 失败：`a0 = 0xFFFFFFFF`，`a1 = errno`

编译器生成的容器侧包装逻辑必须执行：

- `a1 == 0` 时转为 `ok(a0)`
- `a1 != 0` 时转为 `error(errno)`

---

## 4. 系统调用号与语义

### 4.1 调用号

- `SYS_PRINT = 1`
- `SYS_ALLOC = 2`
- `SYS_IO = 3`
- `SYS_YIELD = 4`
- `SYS_TIME = 5`

### 4.2 `SYS_PRINT`

参数约定：

- `arg1`: `msg_ptr`（容器虚拟地址）
- `arg2`: `msg_len`

校验流程：

- 校验 `[msg_ptr, msg_ptr + msg_len)` 位于容器可读映射区。
- 校验长度不超过单次输出上限（默认 256B，可配置）。

失败返回：

- `E_BUF_RANGE`
- `E_BUF_ALIGN`
- `E_TOO_LARGE`

### 4.3 `SYS_ALLOC`

参数约定：

- `arg1`: `size`（字节）
- `arg2`: `flags`（当前仅支持 0）

分配规则：

- 以 64KB 页为最小分配单位，向上取整。
- 超出容器配额或页池不足直接失败。
- 成功返回容器虚拟地址（页对齐）。

失败返回：

- `E_INVALID_SIZE`
- `E_QUOTA_EXCEEDED`
- `E_NO_MEMORY`

### 4.4 `SYS_IO`

参数约定：

- `arg1`: `device_id`
- `arg2`: `operation`

规则：

- 仅允许访问 capability 中声明的设备。
- 仅允许白名单操作码。
- `.uapp` 头部 `required_caps_bitmap` 会在加载期映射为当前槽位的 `SYS_IO` 白名单；未声明时默认拒绝。
- 当前最小位定义：
  - bit 0：`io.uart`，映射 `device_id = 0`
  - bit 1：`io.gpio`，映射 `device_id = 1`
  - bit 2：`io.timer`，映射 `device_id = 2`
- 当前最小操作白名单：
  - `operation = 0`：read
  - `operation = 1`：write
- portable source 层当前通过 `std.microapp.io.read_uart/write_uart/read_gpio/write_gpio/read_timer/write_timer`
  表达这些设备访问；编译器会把这些 wrapper 的使用推导为 `.uapp required_caps_bitmap`。
- 未知 capability 位必须拒绝加载/授权，不允许静默忽略。

失败返回：

- `E_DEV_DENIED`
- `E_OP_DENIED`
- `E_DEV_UNAVAILABLE`

### 4.5 `SYS_YIELD`

参数约定：

- `arg1 = 0`
- `arg2 = 0`

行为：

- 当前容器主动放弃剩余时间片。
- 重新入队到同优先级可运行队列尾部。

### 4.6 `SYS_TIME`

参数约定：

- `arg1 = 0`
- `arg2 = 0`

行为：

- 返回当前宿主时间的毫秒值低 32 位。

---

## 5. 错误码域

错误码为 `u32`，范围 `0x0001..0x7FFF`，按域分段：

- `0x0001..0x00FF`: 通用参数错误
- `0x0100..0x01FF`: 内存与映射错误
- `0x0200..0x02FF`: 设备与权限错误
- `0x0300..0x03FF`: 调度与状态错误
- `0x0400..0x04FF`: 加载与镜像错误

保留 `0` 作为成功。

---

## 6. 阻塞与超时规则

### 6.1 阻塞语义

- `SYS_PRINT`: 非阻塞，超过环形缓冲上限返回 `E_BUSY`
- `SYS_ALLOC`: 非阻塞，立即返回
- `SYS_IO`: 默认非阻塞；仅当设备明确支持同步模式时允许阻塞
- `SYS_YIELD`: 立即让出，不阻塞
- `SYS_TIME`: 非阻塞，立即返回

### 6.2 超时语义

- 当前 ABI 不提供通用 timeout 参数。
- 需要超时控制的业务由容器层轮询 + `SYS_YIELD` 组合实现。

---

## 7. 可重入与上下文约束

### 7.1 中断上下文

- 容器没有中断上下文执行权限。
- 内核中断处理函数禁止直接执行可阻塞 syscall 路径。

### 7.2 可重入约束

- 同一容器在一次 trap 未返回前，禁止再次进入 syscall 入口。
- 内核使用每容器 `in_syscall` 标志检测重入，违规返回 `E_REENTRANT`.

### 7.3 抢占约束

- syscall 关键区可短暂禁中断，窗口必须受上限约束。
- 禁中断窗口内不得执行设备等待。

---

## 8. 审计与追踪

每次 syscall 必须写入环形审计项：

- 时间戳
- container_id
- syscall number
- 参数摘要
- 返回值
- errno
- 执行周期

默认保存最近 256 条记录，覆盖写入。

---

## 9. 实现约束

- 容器包装层必须由编译器生成，不允许用户自定义 trap 汇编。
- 内核侧 dispatcher 必须使用 `switch(number)` 的显式分发，不允许函数指针动态跳转。
- 所有非法调用号统一返回 `E_BAD_SYSCALL`.

---

## 10. 验收标准

- ABI 文档可独立指导容器 wrapper 与内核 dispatcher 编写。
- 所有 syscall 都具备输入校验、失败路径、错误码归类。
- 阻塞、重入、中断约束均可由测试覆盖验证。

---

## 11. 多平台 ABI 适配约定

### 11.1 统一语义层

以下逻辑 ABI 在所有平台保持不变：

- 调用号定义与错误码域
- syscall 参数语义
- 成功/失败返回编码语义
- 阻塞与可重入规则

### 11.2 CH32V003（RV32）硬件映射

- 使用本规范第 3 节寄存器约定与 `ecall`。

### 11.3 ESP32（Xtensa）硬件映射

- 由 `arch/xtensa` 提供 trap 入口封装与寄存器映射。
- 语义层保持 `syscall(number, arg1, arg2)` 不变，不向上层暴露寄存器差异。
- 平台适配层必须保证“失败可返回 errno，成功返回 value”的一致编码。

### 11.4 RV1106 兼容模式映射

- `baremetal_compat`：使用本地 trap 入口，行为对齐 CH32 语义。
- `linux_hosted`：由 runtime 将 syscall 语义映射到宿主调用或受限代理接口。
- 不论运行形态，容器侧 ABI 与错误处理语义保持一致。
