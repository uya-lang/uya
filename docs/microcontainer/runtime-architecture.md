# MicroContainer Core 与 Capability Adapter 分层原则

> **实现状态（2026-10-19 核对，v0.10.4）**：MicroContainer Core 的编译器侧与运行库侧已落地——
> `src/microapp/main.uya`（profile / 镜像发射 / `pack-image` / `inspect-image` / `verify-image`）、
> `lib/std/microapp/{abi,io,mem,microapp,task,time}.uya`、`lib/std/runtime/microapp/`；
> Capability Adapter 在 `lib/std/runtime/capability/{adapter,backend,native_backend,wamr_backend,fake_backend}.uya`。
> 聚合回归 `make microapp-check` / `microapp-hosted-smoke` / `microapp-compat-check` / `microapp-recovery-check`；
> 可移植 native 剩余项见 `portable_native_todo.md`，共享库未实现见 `shared_library_todo.md`。

## 1. 目标

MicroContainer 必须被设计为统一运行时核心，而不是设备版和 native 版两套实现。

设计目标：

- 同一份 microapp artifact 在不同环境下行为一致
- native 环境用于高保真调试与测试
- device 环境用于量产运行
- 运行时核心不分叉
- 平台差异仅收敛在 capability adapter 层

> 平台差异属于能力后端差异，不属于运行时语义差异。

---

## 2. 总体分层

```text
MicroApp Artifact
  |
  v
MicroContainer Core
  |
  v
Capability Abstraction Layer
  |
  v
+------------------------------+
| Device Adapter               |
| Native Mock Adapter          |
+------------------------------+
```

---

## 3. 核心原则

### 原则 1：同一 artifact，双环境可运行

同一份 microapp artifact 应同时满足：

- 可被 device microcontainer 加载
- 可被 native microcontainer 加载

### 原则 2：运行时语义必须一致

以下语义必须一致：

- 加载规则
- verifier 规则
- capability 检查
- 生命周期状态机
- 调度模型
- 权限检查
- 预算控制
- 错误处理

### 原则 3：差异仅存在于 Capability Adapter

允许差异：

- 时间来源
- 显示输出
- 传感器输入
- 存储实现
- 网络实现

不允许差异：

- runtime 状态机
- loader / verifier
- 调度逻辑
- 预算系统
- 错误模型

### 原则 4：多观测，不多语义

native 可增加：

- trace
- debug log
- inspection API

但不得改变执行语义。

---

## 4. MicroContainer Core 职责

### 4.1 Artifact Loader

- 解析 artifact
- 解析 manifest
- 校验 ABI / version
- 提取 capability 声明

### 4.2 Verifier

- 校验结构合法性
- 校验 capability 合法性
- 校验内存 / 元数据
- 拒绝非法产物

### 4.3 Lifecycle Manager

状态管理：

- installed
- loaded
- ready
- running
- suspended
- stopped
- crashed
- disabled

### 4.4 Scheduler

- 事件驱动
- 队列管理
- 单次执行模型

### 4.5 Capability Dispatcher

- capability 分发
- 参数校验
- 权限检查
- 调用记账

### 4.6 Budget Enforcement

- exec time budget
- wakeup budget
- API budget
- memory budget

### 4.7 Fault Isolation

- crash 捕获
- 应用隔离
- 状态恢复

### 4.8 Event / Trace

- 生命周期日志
- 调用日志
- 错误日志

---

## 5. Capability Abstraction Layer

职责：

- 定义能力接口
- 定义参数模型
- 定义权限等级

示例：

- `TimeCapability`
- `StorageCapability`
- `DisplayCapability`
- `SensorCapability`
- `MotorCapability`
- `NetworkCapability`

---

## 6. Capability Adapter Backend

### 6.1 Device Adapter

- RTC
- 显示设备
- 传感器
- 马达
- 存储
- 网络

### 6.2 Native Mock Adapter

- mock clock
- fake display
- fake sensor
- local storage
- simulated network

---

## 7. 行为一致性要求

### 7.1 加载一致

相同 artifact -> 相同加载结果

### 7.2 权限一致

相同 capability -> 相同权限判断

### 7.3 调度一致

相同事件 -> 相同行为

### 7.4 预算一致

相同配置 -> 相同限制结果

### 7.5 错误一致

相同错误 -> 相同处理策略

---

## 8. 唯一允许差异

- IO 表现形式
- 时间来源
- 数据来源
- 调试可见性

---

## 9. 禁止行为

### 禁止在 core 中写平台分支

```text
if native then ...
if debug then bypass ...
```

### 禁止 runtime 语义分叉

### 禁止绕过 capability dispatch

### 禁止 native 提供额外能力

---

## 10. 接口建议

统一入口：

```text
invoke(capability_id, args, ctx) -> result
```

或分类接口：

- `time.now()`
- `storage.get()`
- `display.show()`
- `sensor.read()`

---

## 11. 调试体系

### 11.1 Native MicroContainer

用途：

- 高保真调试
- 集成测试
- runtime 验证

### 11.2 Direct Native Exec（可选）

用途：

- 单元测试
- 快速调试

---

## 12. 推荐目录结构

```text
/runtime/core
/runtime/capability
/runtime/backend/device
/runtime/backend/native
```

---

## 13. 架构验收标准

- 同一 artifact 双端运行
- core 不依赖 backend
- capability 流程统一
- mock 不改变语义
- native 支持事件重放

---

## 14. 总定义

> MicroContainer 必须是统一运行时核心，其在 native 与 device 环境中的唯一差异仅存在于 Capability Adapter Backend；除能力实现外，其加载、校验、调度、预算和错误语义必须完全一致。

---

## 15. 后续文档建议

建议补充：

- [Capability API Schema](./capability_api_schema.md)
- [Backend Adapter Contract](./backend_adapter_contract.md)
- [Native Mock 语义规范](./native_mock_semantics.md)
