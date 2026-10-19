# 穿戴设备能力运行时兼容层设计（WAMR / Native）

> **实现状态（2026-10-19 核对，v0.10.4）**：后端抽象与两套后端均在
> `lib/std/runtime/capability/` 落地：`backend.uya`（`CapabilityBackendKind`：`Fake` / `Wamr` /
> `NativeUya`）、`adapter.uya`、`fake_backend.uya`、`wamr_backend.uya`、`native_backend.uya`；
> 兼容性回归 `tests/test_capability_runtime_compat.uya` + `tests/run_capability_runtime_compat.sh`，
> 基准 `tests/bench_capability_runtime.uya` + `tests/run_capability_runtime_benchmark.sh`。
> 下文保留设计期原文。

**版本**：v0.1  
**日期**：2026-04-05

---

## 1. 目标

本文档定义能力运行时的**最大兼容层**，用于在同一套平台协议下同时支持：

- `WAMR` 后端
- `Native Uya` 自定义执行后端

本文档的核心目标不是先决定哪种后端更优，而是确保两者在以下方面可直接对比：

- 生命周期
- 权限控制
- Host API
- 错误码
- 性能指标

### 1.1 与微容器的分工

本兼容层文档讨论的是 `capability runtime` 如何对接不同执行后端，不等同于微容器需求本身。

两者建议按以下边界理解：

- `capability runtime` 是上层抽象，负责包协议、权限、生命周期、Host API 和 benchmark 口径
- `backend adapter` 是桥接层，负责把某个执行引擎接成统一接口
- “微容器”是某类执行引擎或隔离载体，负责地址空间、syscall 边界、调度、故障恢复等底层机制

也就是说：

- 不是“capability 对立于微容器”
- 而是“capability 可以运行在微容器之上，也可以运行在其他后端之上”

---

## 2. 设计原则

### 2.1 上层不感知执行后端

业务侧、测试侧、演示场景侧不应直接区分：

- `WAMR`
- `Native Uya`

它们只应通过统一的 capability manager 和 backend interface 交互。

### 2.2 包格式尽量统一

除 `runtime.backend` 外，Manifest 其余字段应保持一致，避免对不同后端维护两套协议。

### 2.3 Host API 完全统一

所有能力包都只能通过统一 Host API 使用设备能力。

### 2.4 Benchmark 必须复用同一套用例

只比较同一业务能力在不同执行后端下的表现，避免把产品逻辑差异混入性能结论。

---

## 3. 分层结构

建议分为以下 6 层：

1. `Capability Package`
2. `Capability Manager`
3. `Compatibility Layer`
4. `Execution Backend Adapter`
5. `Host API`
6. `Telemetry / Benchmark`

其中：

- `Capability Manager` 负责安装、激活、禁用、回滚、调度
- `Execution Backend Adapter` 负责把具体后端接入统一接口
- `Telemetry / Benchmark` 负责收集资源与性能指标

若底层采用微容器实现，可进一步细化为：

1. `Capability Package`
2. `Capability Manager`
3. `Compatibility Layer`
4. `Microcontainer Adapter`
5. `Microcontainer Runtime`
6. `Kernel / Syscall / Isolation`

其中 `Microcontainer Adapter` 仍对上暴露统一 backend interface，对下再去绑定微容器镜像格式、系统调用 ABI 和容器生命周期。

---

## 4. Manifest 扩展

建议在 `runtime` 中增加后端字段：

```json
{
  "runtime": {
    "backend": "wamr",
    "abi": "uya-cap-1",
    "timeout_ms": 50,
    "memory_limit_kb": 128,
    "stack_limit_kb": 32
  }
}
```

`backend` 第一版建议只允许：

- `wamr`
- `native_uya`

这样可在不改变上层产品协议的前提下切换执行器。

---

## 5. 统一 Backend Interface

建议所有执行后端实现同一组语义接口：

```text
init(host_api, policy, limits)
validate_module(payload)
load_module(payload)
create_instance(module, manifest)
invoke(instance, entry, trigger_ctx)
destroy_instance(instance)
unload_module(module)
```

### 5.1 语义说明

- `init`：初始化后端运行时
- `validate_module`：验证载荷是否为该后端可接受格式
- `load_module`：装载模块
- `create_instance`：创建可执行实例
- `invoke`：执行统一入口
- `destroy_instance`：释放实例资源
- `unload_module`：卸载模块本体

---

## 6. 统一 Host API

第一版建议统一以下 Host API：

- `host_time_now`
- `host_log_write`
- `host_vibrate`
- `host_kv_get`
- `host_kv_set`
- `host_screen_draw_text`
- `host_sensor_step_read`

### 6.1 WAMR 后端

WAMR 后端将上述 API 暴露为 wasm imports。

### 6.2 Native Uya 后端

Native Uya 后端通过固定 ABI 或宿主调用表映射到同名能力。

---

## 7. 统一错误模型

兼容层建议统一使用平台级错误语义：

- `Ok`
- `InvalidPackage`
- `InvalidModule`
- `PermissionDenied`
- `InvalidArgument`
- `TimedOut`
- `ResourceExceeded`
- `Disabled`
- `BackendInternalError`
- `HostApiError`

具体后端错误必须被映射到上述语义，不应直接泄漏底层私有错误码。

---

## 8. 统一 Benchmark Harness

应使用同一组能力包与同一组场景进行对比。建议至少覆盖：

### 8.1 生命周期类

- install latency
- activate latency
- disable latency
- rollback latency

### 8.2 执行类

- cold invoke
- warm invoke
- repeated invoke x100
- repeated invoke x1000

### 8.3 Host API 类

- time read
- kv read
- kv write
- vibrate
- screen draw text

### 8.4 异常类

- permission denied
- timeout
- invalid payload
- backend trap / abort

---

## 9. 指标建议

建议统一采集以下指标：

- `rom_bytes`
- `ram_idle_bytes`
- `ram_peak_bytes`
- `install_us`
- `activate_us`
- `first_invoke_us`
- `avg_invoke_us`
- `p99_invoke_us`
- `host_call_overhead_us`
- `failure_count`
- `timeout_count`

---

## 10. Adapter 职责边界

### 10.1 WAMR Adapter 负责

- wasm 模块格式验证
- wasm 模块装载
- wasm 实例创建
- Host API import 注册
- wasm trap 映射为统一错误语义

### 10.2 Native Uya Adapter 负责

- 原生 payload 验证
- 原生执行上下文创建
- Host API 调用桥接
- 原生执行错误映射

### 10.3 两者都不负责

- 签名校验
- 权限策略本身
- 版本与回滚策略
- 产品级日志聚合

这些逻辑应由 capability manager 与兼容层统一管理。

### 10.4 若引入微容器后端，Adapter 额外负责

- 将 manifest 中的资源限制映射到容器配额
- 将 capability 权限映射到 syscall / host capability 白名单
- 将 capability 的 `install/load/activate/invoke/unload` 语义映射到容器的加载、启动、调用、销毁语义
- 将容器 trap、越界、非法 syscall 等底层故障映射回统一能力状态与错误码

---

## 11. 建议实现顺序

1. 固定 backend interface
2. 固定 `runtime.backend`
3. 固定统一 Host API 集
4. 先实现 `fake backend`
5. 接入 `WAMR backend`
6. 跑第一轮 benchmark
7. 接入 `Native Uya backend`
8. 使用同一组 case 做对比

当前最小 benchmark harness 入口：

- `lib/std/runtime/capability/benchmark.uya`：`capability_benchmark_run_manager_case`
- `tests/bench_capability_runtime.uya`
- `tests/run_capability_runtime_benchmark.sh`

当前 benchmark 运行约定：

- 默认输出控制台摘要，并写出 `build/capability_runtime_benchmark.csv`
- 默认写出 `build/capability_runtime_benchmark.json`
- 可通过 `tests/run_capability_runtime_benchmark.sh --baseline <history.json|history.csv>` 读取历史结果
- 基线比对默认使用 `--regression-threshold-pct 5.0` 与 `--min-regression-us 2` 过滤微小抖动
- 可通过 `--fail-on-regression` 在存在超阈值 regression 时返回非零退出码
- 可通过 `--fail-metrics <csv>` 指定哪些 metric 参与失败判定
- 可通过 `--ignore-metrics <csv>` 从失败判定集合中排除 metric
- 启用基线比对后，会额外写出 `build/capability_runtime_benchmark_compare.csv`
- 启用基线比对后，会额外写出 `build/capability_runtime_benchmark_compare.json`
- compare 输出以 `backend + case` 对齐，并对 `latency_us`、`install_us`、`activate_us`、`first_invoke_us`、`avg_invoke_us`、`p99_invoke_us`、`failure_count`、`timeout_count` 给出百分比变化
- 百分比大于 `0` 记为 regression，小于 `0` 记为 improvement，等于 `0` 记为 stable
- compare 结果额外包含 `exceeds_threshold`，用于区分纯波动和应拦截的回退
- compare 结果额外包含 `monitored_for_failure`，用于标记该 metric 是否参与 CI 失败判定
- 当前默认失败判定集合是 `latency_us,p99_invoke_us,failure_count,timeout_count`

当前基准覆盖：

- `InvokeLoop`：`Fake` / `WAMR` / `Native Uya` 横向对比
- `InvokeWarm`：先给 warm path 留单独观测点
- `PermissionDenied`：先覆盖失败语义是否稳定落到结果结构
- 导出：运行 benchmark 后会生成 `build/capability_runtime_benchmark.csv` 与 `build/capability_runtime_benchmark.json`

---

## 12. 成功标准

若满足以下条件，可认为兼容层设计成功：

- 上层 manager 不感知具体执行后端
- 同一 manifest 可切换 backend
- 同一业务 case 可在两个 backend 上运行
- 同一套 benchmark 可直接产出对比数据
- 在引入微容器后端后，不需要重写 capability 层协议，只需要补齐对应 adapter
