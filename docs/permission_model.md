# 穿戴设备能力运行时权限模型（MVP）

**版本**：v0.1  
**日期**：2026-04-05

> **实现状态（2026-10-19 核对，v0.10.4）**：本权限模型已在 `lib/std/runtime/capability/` 落地。
>
> - §3 权限分类与 §4 MVP 集合 → `types.uya` 的 `CapabilityPermissionId`（`TimeRead` / `DeviceInfoRead` /
>   `LogWrite` / `VibrateUse` / `ScreenDrawBasic` / `NotificationPost` / `SensorStepRead` / `SensorHrRead` /
>   `SensorAccelRead` / `StorageKvRead` / `StorageKvWrite` / `BleRead` / `BleWrite` / `NetRequest`），
>   位图映射见 `capability_permission_to_mask`。
> - §2.1/2.2 声明与授予分离 → `policy.uya` 的 `CapabilityPermissionSet` 与
>   `capability_permission_set_declare` / `_grant` / `_is_declared` / `_is_granted` / `_require`；
>   对应错误 `CapabilityPermissionDenied` / `CapabilityPermissionNotDeclared`。
> - §2.3 调用时检查 → `capability_permission_require()` 在 Host API 入口调用。
> - §5 判定流程 → `policy.uya` + `abi.uya` 的 `CapabilityStatusCode`（`PermissionDenied` / `Disabled` /
>   `TimedOut` / `ResourceExceeded`）。
> - §8 Host API 与权限映射 → `hostapi.uya` 的 `CapabilityHostApi` 与 `abi.uya` 的 `CapabilityHostCallId`。
>   已实现权限检查的 Host API 为 `time_now` / `log_write` / `vibrate` / `kv_get` / `kv_set`；
>   `ScreenDrawText` 目前只有 `CapabilityHostCallId` 枚举值，`hostapi.uya` 尚未提供该函数。
> - Manifest 侧声明字段：`manifest.uya` 的 `permissions: [CapabilityPermissionId: CAPABILITY_MAX_PERMISSIONS]`。
>
> 本文仍是**语义与策略**的定义处；实现细节以代码为准。

---

## 1. 目标

本文档定义穿戴设备能力运行时的**最小权限模型**，目标是：

- 保证能力包只能访问被允许的设备能力
- 让设备厂商可控制开放边界
- 让日志、审计、问题排查可追踪

本模型服务于“无 App 能力手表”的轻量插件运行时，不追求通用操作系统权限复杂度。

---

## 2. 核心原则

### 2.1 默认拒绝

Manifest 未声明的权限，一律禁止。

### 2.2 声明不等于授予

能力包声明了权限，只表示“申请”；设备宿主可根据策略：

- 允许
- 拒绝
- 降级开放

### 2.3 调用时检查

权限检查不仅发生在安装阶段，也必须发生在运行时的 API 调用入口。

### 2.4 可审计

系统应能记录：

- 申请了什么权限
- 实际授予了什么权限
- 哪些调用被拒绝

---

## 3. 权限分类

### 3.1 基础权限

| 权限 | 说明 |
|------|------|
| `time.read` | 读取当前时间、日期、时区相关信息 |
| `device.info.read` | 读取设备基础信息，如型号、固件版本 |
| `log.write` | 写运行时日志 |

### 3.2 交互权限

| 权限 | 说明 |
|------|------|
| `vibrate.use` | 触发震动 |
| `screen.draw_basic` | 进行基础屏幕输出，如文字、简单图形 |
| `notification.post` | 发送受控的通知或提示 |

### 3.3 传感器权限

| 权限 | 说明 |
|------|------|
| `sensor.step.read` | 读取步数 |
| `sensor.hr.read` | 读取心率 |
| `sensor.accel.read` | 读取加速度相关数据 |

### 3.4 存储权限

| 权限 | 说明 |
|------|------|
| `storage.kv.read` | 读取本地 KV 存储 |
| `storage.kv.write` | 写本地 KV 存储 |

### 3.5 连接权限

| 权限 | 说明 |
|------|------|
| `ble.read` | 读取 BLE 相关数据 |
| `ble.write` | 写入 BLE 数据 |
| `net.request` | 发起受控网络请求 |

---

## 4. MVP 推荐开放集合

第一版建议只开放以下权限：

- `time.read`
- `log.write`
- `vibrate.use`
- `screen.draw_basic`
- `storage.kv.read`
- `storage.kv.write`

原因：

- 风险低
- 商业场景足够验证
- 容易做出稳定的隔离边界

传感器、BLE、网络权限建议在第二阶段按场景逐步放开。

---

## 5. 权限判定流程

一次 API 调用是否允许，建议按以下顺序判断：

1. 该能力包是否在 Manifest 中声明了权限
2. 宿主策略是否允许该权限
3. 当前能力状态是否为激活状态
4. 当前执行上下文是否超时、崩溃或被禁用
5. 调用频率、资源上限是否已超出

全部满足后才允许调用对应 Host API。

---

## 6. 宿主策略

宿主应保留最终裁决权。可按以下维度裁决：

- 设备型号
- 固件版本
- 发布者身份
- 能力包来源
- 当前业务场景

例如：

- 某低端机型禁止 `screen.draw_basic`
- 某特定发布者不得使用 `sensor.hr.read`
- 某些体验版固件禁止全部写存储能力

---

## 7. 审计与日志建议

系统至少应记录以下事件：

- 能力包安装时声明的权限列表
- 宿主实际授予的权限列表
- 权限调用成功次数
- 权限调用拒绝次数
- 权限拒绝原因

建议的拒绝原因包括：

- `PermissionNotDeclared`
- `PermissionDeniedByPolicy`
- `CapabilityDisabled`
- `CapabilityTimedOut`
- `RateLimitExceeded`

---

## 8. Host API 与权限映射

建议对每个公开 Host API 明确绑定权限：

| Host API | 所需权限 |
|----------|----------|
| `host_time_now()` | `time.read` |
| `host_vibrate(ms)` | `vibrate.use` |
| `host_screen_draw_text(...)` | `screen.draw_basic` |
| `host_kv_get(...)` | `storage.kv.read` |
| `host_kv_set(...)` | `storage.kv.write` |

不得存在“无需权限即可访问敏感设备能力”的隐藏接口。

---

## 9. 明确不做

MVP 阶段本文档不覆盖：

- 用户交互式授权弹窗
- 复杂角色/租户权限继承体系
- 设备侧脚本自定义权限表达式
- 细粒度到字段级别的传感器权限

---

## 10. 演进方向

后续可逐步支持：

- 基于能力来源的信任等级
- 基于设备状态的动态权限
- 更细粒度的传感器/网络访问控制
- 权限使用统计与异常检测

