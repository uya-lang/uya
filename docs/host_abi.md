# 穿戴设备能力运行时 Host ABI（MVP）

**版本**：v0.1  
**日期**：2026-04-05

> **实现状态（2026-10-19 核对，v0.10.4）**：本 ABI 已在 `lib/std/runtime/capability/` 落地，
> 与本文的对应关系：
>
> | 本文条目 | 实现落点 |
> |----------|----------|
> | §4 固定入口 / 执行上下文 | `abi.uya` 的 `CapabilityExecutionContext`（`instance_id` / `state` / `permissions` / `limits` / `last_status`） |
> | §6 Host Call 集合 | `abi.uya` 的 `CapabilityHostCallId`：`TimeNow` / `LogWrite` / `Vibrate` / `ScreenDrawText` / `KvGet` / `KvSet` |
> | §6 权限名 | `types.uya` 的 `CapabilityPermissionId` + `policy.uya` 的 `CapabilityPermissionSet`（声明 / 授予 / `capability_permission_require`） |
> | §7 错误码 0-7 | `abi.uya` 的 `CapabilityStatusCode`：`Ok` / `Failed` / `PermissionDenied` / `InvalidArgument` / `TimedOut` / `ResourceExceeded` / `HostInternalError` / `Disabled` |
> | §8 资源限制 | `types.uya` 的 `CapabilityResourceLimits`（`timeout_ms` / `memory_limit_kb` 等） |
> | §9 生命周期状态 | `types.uya` 的 `CapabilityState`：`Downloaded` / `Verified` / `Installed` / `Active` / `Disabled` / `Failed` |
> | Host Call 实现 | `hostapi.uya`、`adapter.uya`、`native_backend.uya`、`fake_backend.uya`、`wamr_backend.uya`（`screen_draw_text` 目前只有 `CapabilityHostCallId.ScreenDrawText` 枚举，`hostapi.uya` 尚未提供对应函数） |
>
> 编译期侧的边界不在本文范围：`@syscall` 的跨平台汇聚点见
> [`syscall_design.md`](syscall_design.md)，`hosted` 与 `--nostdlib` 的 ABI 通道差异也在那里。

---

## 1. 目标

本文档定义能力运行时与设备宿主之间的**最小 ABI 边界**，目标是：

- 固定能力包入口
- 集中 Host API 调用边界
- 为权限检查、资源限制、版本兼容提供稳定接口

本文档只覆盖 MVP 所需能力。

---

## 2. 设计原则

### 2.1 固定入口

第一版能力包只暴露一个固定入口，避免多入口导致 ABI 演化复杂。

### 2.2 所有设备能力都经由 Host Call

能力包不得直接访问底层设备对象，必须通过宿主提供的 ABI 调用：

- 便于权限检查
- 便于资源统计
- 便于稳定升级

### 2.3 宿主拥有生命周期控制权

宿主可以：

- 启动
- 中断
- 超时终止
- 禁用
- 回滚

---

## 3. 最小执行模型

建议第一版执行模型为：

1. 宿主加载能力包
2. 创建能力执行上下文
3. 以固定 ABI 调用入口函数
4. 能力通过 Host Call 使用设备能力
5. 宿主收集返回码、日志、指标

---

## 4. 固定入口

建议第一版采用固定入口名称：

```text
main
```

其语义可等价为：

```c
int capability_main(host_context* ctx);
```

如果后续以 Uya 形式表达，可映射到统一的导出入口，不建议让每个能力包自由定义多种签名。

---

## 5. 执行上下文

宿主在调用能力包入口时，应提供一个受控上下文句柄，至少承载以下信息：

- 能力实例 ID
- 运行时状态
- 已授予权限视图
- 宿主调用入口表
- 资源限制信息

能力包不应直接持有底层系统资源指针。

---

## 6. Host Call 建议集合

第一版建议只提供少量 Host Call：

| Host Call | 说明 | 权限 |
|-----------|------|------|
| `host_time_now()` | 获取当前时间 | `time.read` |
| `host_log_write(level, msg)` | 写日志 | `log.write` |
| `host_vibrate(ms)` | 触发震动 | `vibrate.use` |
| `host_screen_draw_text(x, y, text)` | 绘制文本 | `screen.draw_basic` |
| `host_kv_get(key, out)` | 读取 KV | `storage.kv.read` |
| `host_kv_set(key, value)` | 写入 KV | `storage.kv.write` |

第一版避免暴露：

- 任意文件系统访问
- 任意网络访问
- 任意线程创建
- 任意内存映射

---

## 7. 错误码建议

建议宿主与能力包之间统一使用稳定错误码，以便跨版本兼容与日志追踪。

### 7.1 建议错误码

| 错误码 | 含义 |
|--------|------|
| `0` | 成功 |
| `1` | 通用失败 |
| `2` | 权限不足 |
| `3` | 参数非法 |
| `4` | 能力已超时 |
| `5` | 资源上限超出 |
| `6` | 宿主内部错误 |
| `7` | 能力已被禁用 |

### 7.2 建议规则

- 同一错误语义应保持错误码稳定
- 权限失败与内部错误必须可区分
- 日志中必须记录原始错误码

---

## 8. 资源限制接口

宿主应在 ABI 外围控制以下限制：

- 单次执行时间
- 总内存占用
- 栈大小
- 调用频率

其中：

- 时间与状态应由宿主主导
- 能力包只接收结果，不应自行绕过

---

## 9. 生命周期状态

建议最小状态机为：

- `downloaded`
- `verified`
- `installed`
- `active`
- `disabled`
- `failed`

能力包仅在 `active` 状态下可被调度执行。

---

## 10. 版本兼容

为避免宿主与能力包演化失配，建议：

- 在 Manifest 中声明 `runtime.abi`
- 宿主只接受已知 ABI 版本
- ABI 发生破坏性变更时提升主版本，如 `uya-cap-2`

---

## 11. 明确不做

MVP 阶段本文档不覆盖：

- 多入口动态发现
- 插件主动注册复杂回调表
- 复杂共享内存协议
- 第三方自定义 Host Call 扩展

---

## 12. 演进方向

后续可考虑支持：

- 事件触发回调 ABI
- 更高效的参数传递形式
- 二进制接口描述生成
- 静态校验能力包所需 Host Call 集合

