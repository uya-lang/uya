# 穿戴设备能力包 Manifest 设计（MVP）

> **实现状态（2026-10-19 核对，v0.10.4）**：本设计与 `lib/std/runtime/capability/manifest.uya` 的
> `CapabilityManifest` 已对齐（字段：`id` / `name` / `version` / `publisher` / `entry` /
> `abi_version` / `backend_kind` / `limits` / `permissions` / `triggers` / `signature_alg` /
> `key_id` / `signature`；`CAPABILITY_ABI_V1 = 1`）。
> 校验入口：`capability_manifest_init()` / `capability_manifest_validate()`；错误为
> `ManifestInvalid` / `ManifestUnsupportedAbi` / `ManifestMissingEntry` /
> `ManifestTooManyPermissions` / `ManifestTooManyTriggers`。
> 下文保留设计期原文；字段语义以 `manifest.uya` 为准。

**版本**：v0.1  
**日期**：2026-04-05

---

## 1. 目标

本文档定义“无 App 能力穿戴设备”场景下的**能力包（capability package）**最小 Manifest 结构，用于支撑以下闭环：

- 描述一个可下发的小功能模块
- 声明版本、入口、权限、资源限制
- 为设备端验签、安装、激活、回滚提供元数据

本文档聚焦 **MVP**，不追求插件市场级复杂度。

### 1.1 与微容器的关系

`capability` 与“微容器”不是两个平行且互斥的概念，而是上下层关系：

- `capability` 负责描述一个可下发能力的产品协议与运行时协议
- `manifest` 负责声明入口、权限、触发器、资源限制、签名等元数据
- “微容器”负责定义该能力最终以什么隔离载体执行，以及如何做地址空间、系统调用、调度和崩溃恢复

可以把它理解为：

- `capability` 回答“这是什么能力、允许做什么、怎样被管理”
- “微容器”回答“这个能力如何被安全地装载和执行”

因此，Manifest 中的 `runtime` 字段不是在重复定义微容器机制，而是在给底层执行载体提供调度、隔离和校验所需的最小约束。

---

## 2. 设计原则

### 2.1 Manifest 只描述“运行所需最小事实”

第一版只关心：

- 这是什么能力
- 由谁发布
- 从哪里进入
- 需要哪些权限
- 可占用多少资源
- 如何校验来源可信

### 2.2 默认保守

- 默认不授予权限
- 默认不允许无限时运行
- 默认不允许无限内存
- 默认不信任未签名内容

### 2.3 与宿主策略解耦

Manifest 负责“声明”，宿主负责“批准”：

- 包里写了权限，不代表设备一定给
- 包里写了限制，宿主仍可进一步收紧

---

## 3. Manifest 顶层结构

建议第一版使用 JSON，后续如需节省体积，可换为二进制格式或定长头 + 紧凑编码。

### 3.1 示例

```json
{
  "id": "health.reminder.drink_water",
  "name": "Drink Water Reminder",
  "version": "1.0.0",
  "publisher": "acme",
  "entry": "main",
  "runtime": {
    "abi": "uya-cap-1",
    "timeout_ms": 50,
    "memory_limit_kb": 128,
    "stack_limit_kb": 32
  },
  "permissions": [
    "time.read",
    "vibrate.use",
    "storage.kv.read",
    "storage.kv.write"
  ],
  "triggers": [
    {
      "type": "timer",
      "interval_sec": 1800
    }
  ],
  "signature": {
    "alg": "ed25519",
    "key_id": "acme-prod-2026",
    "value": "BASE64_SIGNATURE"
  }
}
```

---

## 4. 字段说明

### 4.1 基本标识

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | 是 | 能力唯一标识，建议采用 `domain.module.feature` 风格 |
| `name` | string | 是 | 人类可读名称 |
| `version` | string | 是 | 语义化版本，建议 `major.minor.patch` |
| `publisher` | string | 是 | 发布方标识，用于审计与信任策略 |
| `entry` | string | 是 | 固定入口名称，第一版建议统一为 `main` |

### 4.2 运行时限制

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `runtime.abi` | string | 是 | 宿主 ABI 版本，如 `uya-cap-1` |
| `runtime.timeout_ms` | integer | 是 | 单次执行超时上限 |
| `runtime.memory_limit_kb` | integer | 是 | 可用内存上限 |
| `runtime.stack_limit_kb` | integer | 是 | 栈空间上限 |

### 4.3 权限声明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `permissions` | string[] | 是 | 能力所需权限列表 |

Manifest 中声明的权限仅是“申请”，实际授予以宿主策略为准。

### 4.4 触发器

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `triggers` | object[] | 否 | 描述能力如何被触发 |

第一版建议仅支持：

- `timer`
- `manual`
- `event`

其中 `timer` 可用于定时提醒、周期检查等轻量逻辑。

### 4.5 签名信息

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `signature.alg` | string | 是 | 签名算法，第一版建议 `ed25519` |
| `signature.key_id` | string | 是 | 公钥标识 |
| `signature.value` | string | 是 | Base64 编码签名值 |

---

## 5. 包内容建议

第一版能力包可由以下部分组成：

```text
capability.pkg
  |- manifest.json
  |- payload.bin
  |- assets/           (可选)
```

说明：

- `manifest.json`：元数据
- `payload.bin`：可执行内容或中间表示
- `assets/`：字体、图标、小型模板资源；MVP 可先不支持或限制大小

---

## 6. 字段约束

### 6.1 标识规则

- `id` 必须稳定，升级时不改变
- `version` 只表示内容版本，不表示设备兼容等级
- 同一设备上，同一 `id` 同时只允许一个激活版本

### 6.2 资源限制规则

- `timeout_ms` 不可缺省
- `memory_limit_kb` 不可缺省
- 宿主可将请求值向下收紧
- 宿主不得因 Manifest 缺省而默认为“无限制”

### 6.3 权限规则

- 未声明权限不得使用
- 声明未获批的权限不得使用
- 调用时必须再次检查，不仅在安装时检查

---

## 7. 安装与升级语义

### 7.1 安装

安装流程建议为：

1. 解析 Manifest
2. 校验字段完整性
3. 校验签名
4. 检查 ABI 是否兼容
5. 检查权限是否允许
6. 注册到本地能力表

若底层执行器采用微容器实现，则上述流程通常还会继续映射到：

7. 选择目标执行载体或后端
8. 校验镜像 / payload 是否满足该载体要求
9. 创建容器实例或等价执行上下文
10. 将 capability 生命周期状态与容器状态建立关联

### 7.2 升级

升级要求：

- 新版本与旧版本 `id` 相同
- `version` 更高
- 通过验签
- 通过宿主兼容性检查

### 7.3 回滚

若新版本安装成功但运行失败，宿主应支持：

- 自动禁用新版本
- 回退到上一稳定版本
- 保留失败原因日志

---

## 8. 明确不做

MVP 阶段本文档不覆盖：

- 复杂依赖解析
- 多能力包事务安装
- 开放式第三方插件市场
- 细粒度资源配额层级嵌套
- 网络权限下的复杂策略语法

---

## 9. 后续演进方向

后续可扩展但不应阻塞 MVP 的方向：

- 更紧凑的二进制 Manifest 编码
- 灰度发布元数据
- 设备型号/固件版本兼容范围
- 能力包依赖声明
- 更细粒度权限与审计策略
- 面向微容器后端的镜像类型、隔离等级、syscall profile 等扩展字段
