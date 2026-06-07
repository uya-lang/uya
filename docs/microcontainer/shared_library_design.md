# Uya 微容器通用共享库机制设计

**版本**: v0.1  
**日期**: 2026-04-28  
**关联文档**:

- `docs/microcontainer/requirements_v1.3.md`
- `docs/microcontainer/runtime-architecture.md`
- `docs/microcontainer/source_to_uapp_pipeline.md`
- `docs/microcontainer/portable_native_design.md`
- `docs/microcontainer/image_validation.md`
- `docs/microcontainer/microapp_profiles.md`

---

## 1. 文档目标

本文档定义一套**微容器自己的通用共享库机制**，用于在不退回宿主 `libc.so` / `dlopen()` 模型的前提下，实现：

- 多个 `uapp` 复用同一份共享代码
- 共享库与普通 `microapp` 走同一套安全边界
- loader 在装载期完成依赖解析与导入绑定
- 同一机制可用于 `libc` 子集、算法库、协议库、capability 辅助库等后续场景

核心目标不是“兼容 Linux `.so`”，而是：

- 保留微容器现有镜像验证、权限、隔离和 profile 语义
- 在此基础上引入可审计、可版本化、可扩展的共享模块 ABI

---

## 2. 非目标

本设计明确排除以下目标：

- 不追求直接加载宿主 ELF `.so`
- 不追求容器内任意时刻 `dlopen()` / `dlsym()` 式动态加载
- 不追求第一阶段就支持线程本地存储、异常展开、构造/析构器链
- 不追求第一阶段就支持共享库导出可写全局数据
- 不追求第一阶段就覆盖完整 `libc`
- 不追求绕过 `microapp` 模式限制去直接 `extern` 宿主函数

第一阶段的正式目标是：

- **装载期链接**
- **函数级共享**
- **代码页共享**
- **调用方容器语义不变**

---

## 3. 设计原则

### 3.1 共享库仍是微容器产物，不是宿主产物

共享库必须与普通 `microapp` 一样，接受：

- `uya microapp build` 语义检查
- 镜像结构校验
- relocation 校验
- profile / bridge / target_arch 一致性检查

共享库不能通过“我是库，不是应用”为理由绕过：

- `extern` 禁令
- 宿主 `libc/std.time` 访问禁令
- capability / syscall / bridge 统一边界

### 3.2 链接时机固定在 loader

第一阶段不支持容器运行中任意新库装入。

正式语义是：

- 编译器产出 import/export 元数据
- loader 在 `load/activate` 阶段做依赖解析
- 若有任意未解析导入或 ABI 不兼容，则整个装载失败

这样可以保证：

- 行为确定
- 失败面可预测
- 调试和验证口径统一

### 3.3 共享代码与共享状态必须分离

第一阶段只共享：

- `code`
- `rodata`

第一阶段不共享：

- 可写 `data`
- `.bss`
- `errno`
- `FILE`
- allocator heap
- 任何隐式进程全局状态

原因是共享可写状态会直接破坏容器间隔离。

### 3.4 符号身份以稳定 ID 为准，不以字符串查找为准

正式匹配键应为：

- `library_id`
- `abi_major`
- `symbol_id`

字符串名仅用于：

- 调试
- inspect 输出
- 错误报告

### 3.5 ABI 先稳定，源码语法后演进

本设计优先冻结：

- 镜像元数据
- loader 解析规则
- import/export 二进制结构

至于最终源码层使用：

- manifest 驱动
- 绑定代码生成
- 新关键字/属性

可以后续迭代，不阻塞底层 ABI 收口。

---

## 4. 术语

- `exec image`：普通可执行微应用镜像，通常输出为 `.uapp`
- `shared lib image`：共享库镜像，推荐输出为 `.ulib`
- `image kind`：镜像种类，至少区分 `exec` 与 `shared_lib`
- `library_id`：共享库稳定身份 ID，不与文件名强绑定
- `abi_major/minor`：共享库 ABI 版本
- `symbol_id`：库内稳定导出符号 ID
- `import slot`：调用方镜像中的导入槽位，loader 在装载期写入目标地址
- `library registry`：运行时已安装共享库的注册表
- `library instance`：未来用于有状态库的每容器实例对象；第一阶段保留概念，不正式启用

---

## 5. 总体分层

建议分为以下 5 层：

```text
Shared Library Source / Bindings
  |
  v
MicroApp Compiler / Packer
  |
  v
Shared Library ABI (.ulib / .uapp v3)
  |
  v
MicroContainer Loader / Library Registry
  |
  v
Shared Page Mapping + Import Binding + Runtime Dispatch
```

各层职责如下：

### 5.1 编译器 / 打包器

- 识别共享库导出
- 识别应用导入
- 生成 import/export/dependency 元数据
- 为导入调用生成 import slot 降级代码
- 打包为统一镜像格式

### 5.2 镜像 ABI

- 定义 `exec/shared_lib` 两类镜像
- 定义 section directory
- 定义 import/export/dependency 表
- 定义版本兼容规则

### 5.3 loader / registry

- 安装共享库
- 校验 profile / ABI / capability 兼容性
- 解析依赖拓扑
- 绑定导入槽
- 维护共享页映射与引用计数

### 5.4 runtime mapping

- 映射共享库 `RX/R` 页
- 为调用方建立容器私有导入槽和运行时状态
- 对接 hard-vm / soft-vm 两类后端

### 5.5 capability / syscall 边界

- 共享库代码执行时仍处于调用方容器上下文
- 其 syscall / capability 权限按调用方容器检查
- 库本身不能绕过调用方权限模型

---

## 6. Artifact 与镜像格式设计

### 6.1 镜像种类

建议把当前镜像格式从“只服务可执行 `uapp`”扩展为“统一模块镜像”：

- `exec`
- `shared_lib`

推荐文件扩展名：

- `exec` -> `.uapp`
- `shared_lib` -> `.ulib`

但 loader 的正式判断依据必须是镜像头中的 `image_kind`，不能依赖扩展名。

### 6.2 格式版本建议

当前 `.uapp v2` 已经稳定承载：

- `code`
- `rodata`
- `data`
- `bss`
- `reloc`
- `profile`
- `bridge`

共享库机制建议从 `format_version = 3` 开始引入新增元数据。

设计原则：

- 保留 v2 基础段模型
- 新增可扩展的 section directory
- 后续新增 metadata 时不再频繁扩展固定头

### 6.3 `ImageKind`

建议新增：

```text
enum ImageKind {
  ik_invalid = 0
  ik_exec = 1
  ik_shared_lib = 2
}
```

语义：

- `ik_exec`：必须有主入口，可被 `microapp run` 直接执行
- `ik_shared_lib`：不可直接作为容器主程序运行，只能被 loader 解析并绑定

### 6.4 `ImageHeader v3`

建议在现有 v2 基础上增加以下逻辑字段：

```text
ImageHeaderV3 extension {
  image_kind: u16
  link_abi_version: u16
  section_table_offset: u32
  section_count: u16
  reserved0: u16
  module_id: u64
  abi_major: u16
  abi_minor: u16
  reserved1: u32
}
```

字段语义：

- `image_kind`
  - `exec` / `shared_lib`
- `link_abi_version`
  - import/export section 的 ABI 版本
- `section_table_offset`
  - section directory 起始位置
- `section_count`
  - section 数量
- `module_id`
  - `shared_lib` 的稳定 `library_id`
  - `exec` 可填 `0`
- `abi_major/minor`
  - 库 ABI 版本
  - `exec` 可填 `0`

### 6.5 section directory

建议新增统一 section 表：

```text
ImageSectionEntry {
  kind: u16
  flags: u16
  offset: u32
  size: u32
  entry_size: u16
  entry_count: u16
}
```

建议的 `kind` 集合：

```text
1  = code
2  = rodata
3  = data
4  = reloc
16 = imports
17 = exports
18 = dependencies
19 = strings
20 = link_aux
```

说明：

- `code/rodata/data/reloc` 与 v2 段语义对齐
- `imports/exports/dependencies/strings` 用于共享库链接
- `link_aux` 预留给后续有状态库扩展或额外链接信息

### 6.6 `PayloadObj vNext`

建议在当前 `PayloadObj` 基础上新增：

```text
PayloadObj {
  ...
  image_kind
  module_id
  abi_major
  abi_minor
  imports: [ImportEntry]
  exports: [ExportEntry]
  dependencies: [DependencyEntry]
  string_table: [byte]
}
```

---

## 7. 共享库链接 ABI

### 7.1 库身份与版本

推荐正式匹配键：

```text
LibraryIdentity {
  library_id: u64
  abi_major: u16
  abi_minor: u16
  profile_id: u32
  target_arch: u8
  bridge_kind: u8
}
```

兼容规则：

- `library_id` 必须相同
- `abi_major` 必须完全相同
- `provider.abi_minor >= consumer.min_abi_minor`
- `profile_id` 必须一致
- `target_arch` 必须一致
- `bridge_kind` 必须一致

第一阶段不支持：

- 跨 profile 解析
- 跨 bridge 解析
- 跨 arch 解析

### 7.2 `ExportEntry`

第一阶段只正式支持**函数导出**。

建议结构：

```text
ExportEntry {
  symbol_id: u32
  symbol_kind: u16
  flags: u16
  target_va: u32
  signature_hash: u64
  name_offset: u32
}
```

字段说明：

- `symbol_id`
  - 库内稳定 ID
- `symbol_kind`
  - v1 只允许 `func`
- `flags`
  - 预留，如 `public`、`unstable`
- `target_va`
  - 导出函数入口 VA
- `signature_hash`
  - 用于校验调用约定与参数布局
- `name_offset`
  - 指向 strings section，仅用于诊断

第一阶段限制：

- `symbol_kind != func` 直接拒绝
- 共享库 `data_size != 0` 或 `bss_size != 0` 直接拒绝

### 7.3 `ImportEntry`

建议结构：

```text
ImportEntry {
  library_id: u64
  abi_major: u16
  min_abi_minor: u16
  symbol_id: u32
  patch_kind: u16
  flags: u16
  slot_va: u32
  signature_hash: u64
  name_offset: u32
}
```

字段说明：

- `library_id`
  - 目标共享库
- `abi_major/min_abi_minor`
  - 版本要求
- `symbol_id`
  - 目标导出 ID
- `patch_kind`
  - 第一阶段只允许 `import_slot_func_ptr`
- `slot_va`
  - 调用方镜像中的导入槽 VA
- `signature_hash`
  - 要求与导出项一致
- `name_offset`
  - 调试字符串

### 7.3.1 为什么采用 slot patch，而不是直接改 call 指令

正式原因如下：

- 降低架构相关性
- 避免为每个 ISA 维护不同 call relocation 规则
- 允许后续接入有状态 thunk
- 更容易在 inspect/verify 中可视化

第一阶段调用形式统一为：

```text
caller code
  -> load imported fn pointer from slot
  -> indirect call
```

loader 在装载时只需要把 `slot_va` 指向的槽写成目标函数地址。

### 7.3.2 import slot 的内存归属

建议：

- `exec image` 的 import slot 放在调用方私有 `data` 或专用 `link_data`
- `shared_lib image` 若有依赖，也可带自己的 import slot

第一阶段为了简单，建议统一规则：

- import slot 所在页由调用方拥有
- loader 绑定完成后可按需要保留 `RW`
- 未来若引入只读 link data，再进一步细分

### 7.4 `DependencyEntry`

建议结构：

```text
DependencyEntry {
  library_id: u64
  abi_major: u16
  min_abi_minor: u16
  flags: u32
  name_offset: u32
}
```

用途：

- 提前表达依赖图
- 允许 loader 做拓扑排序
- 在未真正扫描 imports 前就能快速做 install-time 检查

### 7.5 `strings section`

该 section 不参与正式匹配，只服务：

- inspect 输出
- 错误文案
- 调试诊断

---

## 8. 源码与构建模型

### 8.1 总体原则

底层 ABI 先冻结，源码层可以分两步走：

1. v1：manifest + 绑定代码生成
2. v2：必要时再考虑引入语言级 attribute / sugar

### 8.2 共享库清单

建议引入共享库清单，作为库身份与导出 ID 的单一来源。

逻辑示例：

```yaml
library:
  id: std.mem
  abi_major: 1
  abi_minor: 0
  image_kind: shared_lib

exports:
  - name: memcpy
    symbol_id: 1
    signature: fn(dst: &byte, src: &const byte, n: usize) &byte
  - name: memset
    symbol_id: 2
    signature: fn(dst: &byte, value: i32, n: usize) &byte
```

这里的 YAML 只是逻辑示例，正式格式可以是：

- YAML
- JSON
- Uya 自己的 manifest 语法

关键点是：

- `library_id`
- `symbol_id`
- `abi_major/minor`
- `signature`

必须有稳定来源，不能靠编译期自动哈希名字临时生成。

### 8.3 共享库构建

建议新增构建语义：

```text
uya microapp build --emit-shared-lib foo.uya -o foo.ulib
```

编译器职责：

- 仍按 `microapp` 语义检查源码
- 收集导出函数
- 生成 export/dependency 元数据
- 拒绝不符合 v1 限制的共享库

第一阶段共享库构建限制：

- 必须没有主入口 `main`
- 必须没有可写全局导出
- 建议 `data_size == 0 && bss_size == 0`

### 8.4 应用侧绑定

应用不直接 `extern` 共享库函数。

建议做法：

- 由共享库清单生成一份绑定模块
- 绑定模块对用户暴露正常函数声明
- codegen 识别这些声明属于“共享导入”
- 生成 import slot 调用序列

这样可以保持：

- 源码调用体验接近普通函数
- 不破坏 `microapp` 禁止 `extern` 的边界
- ABI 信息由生成器和 manifest 统一维护

### 8.5 codegen 降级规则

当编译器识别到共享导入函数调用时：

- 不直接生成静态本地函数调用
- 不生成宿主 `extern` 调用
- 为该导入分配一个 `slot_va`
- 调用点改成“从 slot 取指针后间接调用”

---

## 9. Loader 与运行时设计

### 9.1 Library Registry

建议新增全局共享库注册表：

```text
LibraryRegistryRecord {
  library_id: u64
  abi_major: u16
  abi_minor: u16
  profile_id: u32
  target_arch: u8
  bridge_kind: u8
  image_hash: [32]byte
  ref_count: u32
  state: enum
  image_bytes: ref
  export_index: ref
  mapping_handle: ref
}
```

注册表职责：

- 记录已安装库
- 记录已解析导出索引
- 维护引用计数
- 维护共享映射
- 为 loader 提供快速匹配

### 9.2 装载流程

建议标准装载序列如下：

1. 解析 `exec image`
2. 校验普通镜像结构
3. 读取 dependency/import section
4. 在 registry 中解析所有依赖
5. 校验：
   - `library_id`
   - ABI 版本
   - `profile_id`
   - `target_arch`
   - `bridge_kind`
   - `signature_hash`
6. 构建依赖拓扑
7. 映射共享库 `code/rodata`
8. 为调用方分配并初始化 import slot
9. 将每个 import slot 写为解析后的目标地址
10. 汇总 capability / resource 要求
11. 完成最终页权限设置
12. 进入可执行入口

任一步失败都必须使整个装载失败。

### 9.3 capability 与权限合并

共享库代码运行在调用方容器上下文中，因此：

- 真正的权限检查对象仍是调用方容器
- 库不能凭自己的镜像单独获得新 capability

loader 应计算：

```text
effective_required_caps =
  exec.required_caps OR closure(dep.required_caps)
```

若调用方镜像声明不能覆盖整个依赖闭包需求，则拒绝装载。

这可以避免：

- 应用看起来没声明某能力
- 但某共享库在运行时偷偷调用对应 syscall

### 9.4 页映射模型

### 9.4.1 hard-vm

在 `linux_x86_64_hardvm` / `linux_aarch64_hardvm` / `macos_arm64_hardvm` 等 hosted profile 下：

- 共享库 `code` 页映射为 `RX`
- 共享库 `rodata` 页映射为 `R`
- 多个容器可映射同一宿主 backing
- 页表项标记 `PTE_S`

### 9.4.2 soft-vm

在 `rv32_baremetal_softvm` / `xtensa_baremetal_softvm` 下：

- 多个容器页表可指向同一物理代码页
- 仍由软件页表维持统一虚拟地址语义
- 共享页必须是只读/可执行，不允许共享可写段

### 9.4.3 地址一致性

第一阶段建议要求：

- 同一共享库在同一 profile 下有稳定 `code_va/rodata_va`
- 所有依赖该库的调用方都按该 VA 解释导出地址

这样 loader 只需：

- 把导出地址写入 import slot
- 不必为每个调用方重写库内代码

### 9.5 引用计数与卸载

注册表应维护 `ref_count`：

- 新容器装载依赖时 `+1`
- 容器卸载或崩溃回收时 `-1`
- 归零后共享库可进入可卸载态

第一阶段建议：

- 先支持“安装后常驻”
- 卸载只在显式管理命令里触发

这样能先把链接与共享路径跑通，不被复杂回收策略阻塞。

### 9.6 错误模型

建议新增链接级错误：

- `LinkLibraryNotFound`
- `LinkAbiMismatch`
- `LinkProfileMismatch`
- `LinkBridgeMismatch`
- `LinkTargetArchMismatch`
- `LinkSymbolMissing`
- `LinkSignatureMismatch`
- `LinkDependencyCycle`
- `LinkStateUnsupported`

---

## 10. 有状态共享库路线

第一阶段正式 ABI 只支持**无状态函数库**。

但长期必须预留“有状态库”扩展方向，例如：

- `errno`
- allocator
- stdio buffer
- protocol session cache

建议路线如下：

### 10.1 v1

- 只支持函数导出
- 共享库必须 `data_size == 0 && bss_size == 0`
- 不支持库级 init/fini

### 10.2 v2

- 引入 `library instance`
- 每容器为库分配私有 `ctx`
- 库可声明 `init/fini`
- 调用通过 thunk 或 hidden ctx 进入真实导出函数

### 10.3 v3

- 支持受控只读常量导出
- 支持更复杂的库依赖链
- 支持升级兼容策略和多版本并存

当前明确决策：

- `libc` 中 `memcpy/memset/strlen/ctype/部分 math` 适合 v1
- `errno/FILE/malloc/signal 全局状态` 不适合直接进入 v1 共享库

---

## 11. 安全、隔离与资源记账

### 11.1 安全边界

共享库不会引入新的安全例外：

- 仍需通过 `image_validate()`
- 仍需满足 `microapp` 模式限制
- 仍通过统一 bridge/syscall 路径访问宿主能力

### 11.2 隔离边界

共享只发生在：

- 代码页
- 只读数据页

以下资源仍属于调用方容器：

- 栈
- heap
- import slot
- 容器页表
- fault 状态
- budget

### 11.3 资源记账

共享库执行时间、syscall 次数、fault 和内存使用，都记到调用方容器。

注册表层只记录：

- 常驻共享页占用
- 安装/卸载计数

不承担“替调用方分账”的职责。

---

## 12. 校验与 inspect 设计

建议扩展 `microapp verify` / `microapp inspect`：

### 12.1 `microapp inspect`

应显示：

- `image_kind`
- `library_id`
- `abi_major/minor`
- dependency 列表
- export 列表
- import 列表

### 12.2 `microapp verify`

新增检查：

- `shared_lib` 是否错误携带入口
- v1 共享库是否错误携带 `data/bss`
- import slot VA 是否落在合法段
- dependency/import/export section 是否越界
- 同一 `symbol_id` 是否重复
- `symbol_id` 与 `signature_hash` 是否自洽

---

## 13. CLI 与工具链建议

建议新增或扩展以下能力：

```text
uya microapp build --emit-shared-lib foo.uya -o foo.ulib
uya microapp install-shared-lib foo.ulib
uya microapp inspect foo.ulib
uya microapp verify foo.ulib
uya microapp run app.uapp
```

可选增强：

```text
uya microapp list-shared-lib
uya microapp remove-shared-lib <library_id>
uya microapp inspect-link app.uapp
```

其中：

- `install-shared-lib` 负责注册到 library registry
- `inspect-link` 用于查看依赖闭包与版本解析结果

---

## 14. 测试与验收

第一阶段至少需要以下回归：

### 14.1 格式回归

- `.ulib` 基本打包与解析
- import/export/dependency section roundtrip
- `microapp inspect` / `microapp verify` 可见性

### 14.2 失败回归

- 库不存在
- ABI major 不匹配
- profile 不匹配
- bridge 不匹配
- symbol 缺失
- signature hash 不匹配
- 共享库含非零 `data/bss`

### 14.3 正向运行回归

- 两个 `uapp` 共享同一 `memcpy` 库
- loader 绑定 import slot 后运行正确
- 两个容器页表指向同一代码页
- ref_count 正常增减

### 14.4 体积收益回归

至少要有一组 benchmark 或对照：

- 纯静态链接 `uapp`
- 改成共享库后的 `uapp`

验收口径应同时记录：

- 单个 `uapp` 体积
- 全系统总 ROM 占用
- cold load 时间
- invoke 开销变化

---

## 15. 迁移建议

推荐按收益和复杂度逐步迁移：

### 15.1 第一批适合共享化的库

- `memcpy`
- `memmove`
- `memset`
- `memcmp`
- `strlen`
- `strcmp`
- `strncpy`
- `ctype` 子集
- 纯数学函数

### 15.2 暂缓共享的能力

- allocator
- stdio
- signal 全局状态
- pthread / TLS
- 依赖隐式宿主状态的 libc 封装

### 15.3 实施策略

- 先做 1 个官方示例共享库
- 再让 2 个以上 `uapp` 复用它
- 再扩到标准库或 `libc` 子集

---

## 16. 当前决策摘要

为避免讨论长期悬空，本设计先明确以下决策：

1. 共享库是微容器自己的模块 ABI，不兼容 Linux `.so`
2. 第一阶段只做 loader-time linking，不做容器内 `dlopen()`
3. 第一阶段只支持函数导出，不支持共享可写全局数据
4. 第一阶段用 `import slot + indirect call`，不做 ISA 相关 call 指令打补丁
5. 共享库执行时仍按调用方容器 capability / budget / fault 语义运行
6. 正式匹配键用 `library_id + abi_major + symbol_id`，字符串只做诊断
7. 共享机制设计成通用能力，不对 `libc` 做专用格式

这些决策共同保证：

- 机制可复用
- 实现可分阶段推进
- 不会破坏当前 `microapp` 的安全和运行模型
