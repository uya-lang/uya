# Uya 微程序可移植 Native 运行架构设计

**版本**: v0.1  
**日期**: 2026-04-19  
**关联文档**:

- `docs/microcontainer/requirements_v1.3.md`
- `docs/microcontainer/runtime-architecture.md`
- `docs/microcontainer/source_to_uapp_pipeline.md`
- `docs/microcontainer/syscall_abi.md`
- `docs/microcontainer/platform_impl.md`
- `docs/microcontainer/portable_native_todo.md`

---

## 1. 文档目标

本文档定义一个可落地的目标：

- 同一份 `microapp` 源码一次编写
- 在不同目标平台分别编译为对应 ISA 的 native payload
- 运行时由微容器 loader 将 payload 装载到容器虚拟地址空间
- payload 从容器虚拟地址入口真正执行，而不是退回到宿主对照 ELF

这里的“跨平台”指：

- `source portable`
- `per-target native compile`
- `per-target native run`

它**不**指“一份二进制在不同 ISA 上直接运行”。

---

## 2. 非目标

本文档明确排除以下目标：

- 不追求“一份 `.uapp` 在 x86_64 / aarch64 / rv32 上直接共用”
- 不追求第一阶段就覆盖所有现有 libc API
- 不要求所有目标平台都拥有硬件 MMU
- 不要求第一阶段就支持动态链接器语义、线程本地存储、异常展开等完整宿主 ABI

---

## 3. 当前实现与缺口

当前仓库已经具备：

- `--app microapp` 源码检查与降级路径
- `profile-first` 的目标选择与目标 gcc 编译链
- `.pobj -> .uapp` 打包链
- 镜像头、校验、加载模拟路径
- x86_64 hosted loader 真执行路径
- `std.microapp.*` 第一版 API 与 `E4004` 宿主 API 诊断

当前缺口主要有：

1. `.uapp` 只稳定承载了 `code + rodata`，`data / bss / relocations` 仍未成为正式运行时契约。
2. 现有 `microapp` payload 是“先链接 ELF，再抽 `.text/.rodata`”，许多真正运行所需的信息在抽取时被丢失。
3. 当前 `sim_exec_loaded()` 只有 `linux_x86_64_hardvm + call_gate` 走到了真正入口执行，其他 profile / bridge 仍未统一到同一语义。
4. 当前 hosted 路径里，x86_64 已不再依赖对照 ELF，但其他 profile 仍未补齐真执行链。
5. 当前 `microapp` 的宿主交互仍部分依赖宿主符号级 helper，不是稳定的 payload ABI。

---

## 4. 总体设计原则

### 4.1 一次编写，到处编译

可移植性建立在**源码级 ABI**上，而不是二进制兼容上。

统一语义层：

- `microapp` 入口模型
- 容器虚拟地址模型
- syscall / host API 模型
- capability / 权限 / 错误模型

按目标平台变化的只有：

- ISA
- 调用约定
- 执行入口 trampoline
- 页映射方式
- trap / call gate 实现

### 4.2 真执行优先于对照执行

一旦进入“portable native runtime”模式：

- `.uapp` 中的 payload 必须是实际执行对象
- 宿主 ELF 只允许用于构建、调试、对照和离线分析
- 运行路径不得再依赖“外部对照 ELF 实际执行业务逻辑”

### 4.3 双路径虚拟内存模型

为了兼顾有 MMU 与无 MMU 平台，统一虚拟地址语义分两类后端：

- `hard-vm`：
  - 平台具备可用 MMU 或宿主进程页映射能力
  - payload 在保留的容器虚拟地址范围内真实映射并执行
- `soft-vm`：
  - 平台无硬件 MMU
  - 代码仍 native 运行，但数据访问通过编译器插桩与软件页表执行同一套虚拟地址语义

要求：

- 两类后端对上层暴露的虚拟地址语义一致
- 允许实现方式不同
- 不允许放宽安全或 ABI 约束

---

## 5. 总体分层

```text
MicroApp Source (.uya)
  |
  v
Portable MicroApp Frontend
  |
  v
Target Profile Lowering
  |
  v
Payload Builder (PIC / relocation aware)
  |
  v
Portable Native Image (.uapp v2)
  |
  v
Runtime Loader
  |
  +--> hard-vm backend (MMU / mmap / mprotect)
  |
  +--> soft-vm backend (compiler-instrumented memory model)
  |
  v
MicroApp Native Execution
  |
  v
Capability / Syscall Dispatch
```

---

## 6. 核心设计

### 6.1 Source ABI：可移植微程序源码契约

为保证“一次编写，到处编译”，必须定义一个更严格的源码契约，简称 `Portable MicroApp ABI`。

`v0.9.5` 冻结的最小源码子集是：

- `export fn main() i32`
- `@syscall(...)`，但其语义统一落到 profile 对应的 bridge ABI
- `std.microapp.io`
- `std.microapp.mem`
- `std.microapp.task`
- `std.microapp.time`
- 受控常量、切片、结构体、错误联合、基础控制流

源码层禁止或不计入 portable source 子集：

- 直接 `use/call libc.*`
- 直接 `use/call std.time`
- 直接依赖宿主 libc 行为差异的 API
- 假定页大小、缓存线、字节序、对齐细节的代码
- 假定宿主进程地址布局的代码
- 假定宿主线程/进程模型的代码
- `examples/microapp/*_build.uya` / `*_load.uya` 这类宿主侧构建/加载工具源码

结论：

- 用户看到的是“源码级可移植子集”
- 编译器负责把这套子集翻译到各目标 profile

### 6.2 Target Profile：目标平台配置档案

新增 `MicroAppTargetProfile` 概念，每个平台至少有一个 profile。

`v0.9.5` 冻结的 `MicroAppTargetProfile` 对外字段集合是：

- `profile_id`
- `arch_raw`
- `bridge_kind_raw`
- `name`
- `triple`
- `default_gcc`

建议首批 profile：

- `linux_x86_64_hardvm`
- `linux_aarch64_hardvm`
- `macos_arm64_hardvm`
- `rv32_baremetal_softvm`
- `xtensa_baremetal_softvm`

说明：

- `hard-vm` profile 负责“真实虚拟地址映射 + 入口跳转”
- `soft-vm` profile 负责“统一虚拟地址语义 + 数据访问插桩”
- `os` / `hard-vm` / `soft-vm` / 默认编译链接旗标等语义，以 `name + profile_id + bridge_kind_raw` 为正式对外口径，不再要求扩展新的 public struct 字段

### 6.3 Portable Native Image：镜像格式 v2

现有 `.uapp` 已升级为支持真实 native 执行的 `v2` 布局。

`v0.9.5` 冻结的 `.uapp v2` 头字段口径是：

- `magic`
- `format_version`
- `container_api_version`
- `image_size`
- `entry_offset`
- `code_size`
- `rodata_size`
- `data_size`
- `bss_size`
- `stack_size_hint`
- `reloc_count`
- `code_offset`
- `rodata_offset`
- `data_offset`
- `reloc_offset`
- `profile_id`
- `entry_va`
- `code_va`
- `rodata_va`
- `data_va`
- `sha256`
- `required_caps`
- `flags`
- `build_mode`
- `target_arch`
- `bridge_kind`

`v0.9.5` 冻结的 `PayloadObj` 对外字段口径是：

- `target_arch`
- `bridge_kind`
- `build_mode`
- `profile_id`
- `required_caps`
- `flags`
- `entry_offset`
- `entry_va`
- `code_va`
- `rodata_va`
- `data_va`
- `code`
- `rodata`
- `data`
- `bss_size`
- `stack_size_hint`
- `relocs`
- `reloc_count`

补充说明：

- `entry_offset` 保留为代码段内兼容偏移字段
- `entry_va` 是 runtime 真执行入口的正式口径
- `.text / .rodata / .data / .bss / .reloc` 是当前正式段模型

镜像段模型：

- `.text`
- `.rodata`
- `.data`
- `.bss`
- `.reloc`
- `optional debug/manifest extensions`

要求：

- `entry_offset` 升级为 `entry_va`
- relocation 不再允许长期写死为 `0`
- `data/bss` 成为正式一等公民

### 6.4 编译器：从“抽 `.text/.rodata`”升级为“构建可执行 payload”

当前链路的问题是：

- 先生成 ELF
- 再只抽 `.text/.rodata`

目标链路应改为：

```text
source
  -> microapp check
  -> target profile lowering
  -> target object / ELF (PIC aware)
  -> segment extraction
  -> relocation extraction
  -> image v2 pack
```

编译器必须新增的能力：

1. `PIC/PIE` 模式 payload 构建
2. `.data/.bss` 提取
3. relocation 表提取与规范化
4. `entry_va` 计算
5. syscall bridge 信息写入镜像
6. profile 元数据写入镜像

建议：

- 对 `hard-vm` profile 默认使用 `-fpie` / `-fPIC`
- 对 `soft-vm` profile 允许继续用现有插桩路径，但镜像字段仍统一

### 6.5 Syscall Bridge：统一宿主交互边界

这是当前实现最关键的重构点。

现在的问题：

- `microapp` payload 里仍依赖 `write_stdout_bytes` / `posix_memalign` / `sched_yield` 这类宿主 helper
- 这种符号依赖不适合进入真正 `.uapp` 真执行路径

因此要定义正式的 `MicroApp Call Bridge`：

#### 6.5.1 Bridge 形式

按 profile 分两类：

- `trap bridge`
  - 适合 `rv32` 等 baremetal trap 型平台
  - 通过 `ecall` / trap 进入 runtime
- `call_gate bridge`
  - 适合 hosted `x86_64 / aarch64`
  - payload 调用一个已知 ABI 的 gateway function

#### 6.5.2 对 payload 的要求

payload 只能依赖：

- 固定 ABI 的 bridge symbol / entry
- 固定 ABI 的参数和返回约定

payload 不应再直接依赖：

- 宿主 libc 的具体函数名
- `malloc` / `fprintf` / `sched_yield` 之类的宿主实现细节

#### 6.5.3 对编译器的要求

在 `microapp` 模式下：

- `@syscall` 降级到 `call_gate` / `trap` bridge call
- 受控 `std.microapp` API 也统一经 bridge
- 编译器生成 helper 命名统一冻结为 `uya_microapp_bridge_dispatch*`
- 用户代码与宿主 libc 的直接符号绑定必须被消除

#### 6.5.4 Payload Result Model

`v0.9.5` 冻结 loader / sim / recovery 的统一结果面：

- `ok`
- `exit`
- `fault`
- `validated`
- `unwired`

稳定语义：

- `ok`：payload 正常结束，退出码为 `0`
- `exit`：payload 正常返回了非零退出码
- `fault`：payload 进入统一结构化故障结果，必须同时携带 `fault_class / fault_code / fault_signal`
- `validated`：当前只完成镜像/ABI 校验，没有 native 执行
- `unwired`：当前 profile / bridge 没有执行路径

loader 对外稳定输出一行机器可依赖的结果面：

- `[microapp loader] payload result=ok`
- `[microapp loader] payload result=exit code=<n>`
- `[microapp loader] payload result=fault class=<name> code=<n> signal=<n>`
- `[microapp loader] payload result=validated bridge=<name> target=<arch>`
- `[microapp loader] payload result=unwired bridge=<name> target=<arch>`

同一次 payload 运行不应再额外输出旧式 `payload fault class=...` 这类第二套结果面；其他日志只能作为人类诊断，不作为稳定 ABI。

稳定 `fault_class` 最小集合：

- `none`
- `segv`
- `ill`
- `bus`
- `abort`
- `unknown`

### 6.6 Runtime Loader：真正装载与执行

loader 的目标从“校验 + 对照运行”改为“校验 + 装载 + 真执行”。

标准步骤：

1. `image_validate()`
2. 解析 profile
3. 申请容器地址空间
4. 映射 `.text / .rodata / .data`
5. 清零 `.bss`
6. 建立 stack / heap 初始区
7. 写入 syscall bridge 或 trap gate
8. 应用 relocation
9. 准备入口调用上下文
10. 跳转到 `entry_va`

### 6.7 hard-vm 后端：真实虚拟地址执行

适用于 Linux/macOS hosted 和未来具备 MMU 的 device runtime。

实现要求：

- 使用 `mmap` 预留容器虚拟地址窗口
- `.text` 映射为 `RX`
- `.rodata` 映射为 `R`
- `.data/.bss` 映射为 `RW`
- syscall gate 单独放入受控页

执行模型：

- 入口地址由 `entry_va` 决定
- loader 将 `entry_va` 翻译为宿主函数指针
- 通过 arch-specific trampoline 调用

首批硬平台实现建议：

- Linux x86_64
- Linux aarch64
- macOS arm64

### 6.8 soft-vm 后端：无 MMU 设备的统一语义

适用于 `rv32 / xtensa` 等无硬件 MMU 场景。

实现方式：

- 代码 native 跑在物理地址
- 数据访问经编译器插桩走软件页表
- loader 仍按统一镜像格式建立段布局
- bridge 通过 trap 进入 runtime

要求：

- 地址模型与 `hard-vm` 逻辑一致
- 只是映射手段不同
- `hard-vm` / `soft-vm` 对上层共享同一份 source ABI、镜像字段口径和结果模型
- 二者的正式差别只落在装载方式、地址翻译实现与入口执行机制

### 6.9 运行时状态机

统一状态机：

- `installed`
- `loaded`
- `mapped`
- `ready`
- `running`
- `yielded`
- `stopped`
- `crashed`
- `disabled`

新增关键状态：

- `mapped`
  - 说明虚拟地址空间与段映射已经完成
  - 区分于当前仅“header 已记录”的 loaded 状态

### 6.10 CLI 与构建体验

建议形成清晰的用户心智：

- `microapp build`：
  - 产出可执行 `.uapp`
- `microapp run`：
  - 真正执行 `.uapp`
- `microapp build --emit-loader-elf`
  - 仅用于调试
- `microapp inspect`
  - 展示 profile、segment、relocation、entry_va

新增建议参数：

- `--microapp-profile <profile>`
- `--microapp-exec-mode <verify|native>`
- `--microapp-softvm`
- `--microapp-hardvm`

---

## 7. 模块级详细设计

### 7.1 `src/main.uya`

当前进度：

- 已引入 `MicroAppTargetProfile`
- 已把 `MICROAPP_TARGET_ARCH` 升级为 `profile` 选择的一部分
- 已从只抽 `.text/.rodata` 升级到提取 `segment + entry_va + data/bss`
- `run --app microapp` 已改为默认真执行 `.uapp`
- 当前仍保留构建期 ELF 提取与其他 profile 的过渡路径

### 7.2 `lib/kernel/payload.uya`

需要做的事：

- 扩展 `PayloadObj`
- 增加 `.data/.bss`
- 增加 relocation table
- 增加 `entry_va`
- 增加 profile 元数据

### 7.3 `lib/kernel/image.uya`

需要做的事：

- 升级 header 定义到 v2
- 解析 segment table
- 校验 relocation 区
- 校验 `entry_va` 是否位于 `.text`
- 为不同 profile 加入对应验证策略

### 7.4 `lib/kernel/sim.uya`

需要做的事：

- `sim_load_image()` 从“复制整镜像并简单映射”升级为“按段映射”
- `sim_exec_loaded()` 从“入口检查”升级为“真执行入口”
- 保存每容器的 mapped segment 状态、stack、bridge 信息
- 引入 `mapped` 状态转换

### 7.5 `lib/std/runtime/microapp/loader.uya`

需要做的事：

- hosted loader 不再启动 native payload 对照 ELF
- 改为调用 runtime 真执行接口
- 保留对照 ELF 模式仅供调试选项使用

### 7.6 `src/codegen/c99/*`

需要做的事：

- 当前 `uya_microapp_syscall*` helper 改造为正式 bridge ABI
- 对 `hard-vm` profile 生成可重定位 / PIC 兼容 payload
- 对 `soft-vm` profile 保留现有 MMU 插桩但统一 ABI 边界

### 7.7 `std.microapp`

当前已经落地的统一可移植 API 层：

- `std.microapp.io`
- `std.microapp.mem`
- `std.microapp.time`
- `std.microapp.task`

当前目标：

- 让用户不必直接写裸 `@syscall`
- 隔离不同 profile 的底层桥接差异
- 对用户源码直接宿主 API 依赖给出明确诊断

---

## 8. 兼容性策略

### 8.1 与当前 `.uapp` 的兼容

建议保留：

- `v1 image`
- `v2 image`

策略：

- `v1`：只支持 `verify` 与当前对照运行模式
- `v2`：支持真执行

### 8.2 与当前示例的兼容

当前示例可以分两类迁移：

- `legacy example`
  - 保持当前行为
- `portable-native example`
  - 只使用 `std.microapp.*` 与正式 bridge ABI

当前已经收敛出来的 portable source 官方示例包括：

- `examples/microapp/microcontainer_hello_source.uya`
- `examples/microapp/microcontainer_alloc_yield_source.uya`
- `examples/microapp/microcontainer_time_source.uya`
- `examples/microapp/microcontainer_bss_source.uya`

仍保留为宿主侧工具示例的包括：

- `examples/microapp/microcontainer_hello_build.uya`
- `examples/microapp/microcontainer_hello_load.uya`

---

## 9. 风险与边界

### 9.1 最大风险

- relocation / PIC 处理不完整会导致“能加载不能执行”
- bridge ABI 若和 codegen 耦合过深，会让不同平台难以统一
- 直接跳进 payload 后，崩溃恢复与错误观测链要重做

### 9.2 必须避免的错误方向

- 继续依赖“对照 ELF 实际跑逻辑”
- 在 payload 中偷偷链接宿主 libc 普通符号
- 让不同平台暴露不同源码层 API
- 用“特判 x86_64”代替正式 profile 设计

---

## 10. 分阶段 TODO 计划

详细执行清单见：

- `docs/microcontainer/portable_native_todo.md`

### 阶段 0：规格冻结

- [x] 冻结 `Portable MicroApp ABI` 最小源码子集
- [x] 冻结 `MicroAppTargetProfile` 结构
- [x] 冻结 `.uapp v2` 头与段布局
- [x] 冻结 bridge ABI 形式：`trap bridge` / `call_gate bridge`

### 阶段 1：镜像格式升级

- [ ] 扩展 `PayloadObj` 支持 `data/bss/reloc/entry_va/profile`
- [ ] 扩展 `image.uya` 支持 v2 header
- [ ] 扩展 `microapp pack` 支持 v2 生成
- [ ] 增加 `.uapp v2` roundtrip 测试

### 阶段 2：编译链升级

- [x] 为 `hard-vm` profile 切到 `PIC/PIE` payload 构建
- [x] 从 ELF 提取 relocation 表
- [x] 抽取 `.data/.bss`
- [ ] 将 `@syscall` lowering 改为正式 bridge ABI
- [x] 新增 `std.microapp` 可移植 API 第一版

### 阶段 3：hosted x86_64 真执行

- [x] `linux_x86_64_hardvm` profile 落地
- [x] loader 使用 `mmap/mprotect` 映射容器地址空间
- [~] 实现 x86_64 call gate
- [x] `sim_exec_loaded()` 真正跳到 `entry_va`
- [x] 回归用例：不再启动对照 ELF，也能打印和 `yield`

### 阶段 4：hosted aarch64 真执行

- [ ] `linux_aarch64_hardvm` profile 落地
- [ ] `macos_arm64_hardvm` profile 落地
- [ ] 补齐 trampoline 与桥接实现
- [ ] 补齐 hosted 跨平台回归

### 阶段 5：soft-vm 统一语义

- [ ] `rv32_baremetal_softvm` profile 落地
- [ ] `xtensa_baremetal_softvm` profile 落地
- [ ] 统一软 MMU 地址模型
- [ ] 对齐 `hard-vm` / `soft-vm` 运行语义测试

### 阶段 6：源码可移植子集收敛

- [~] 审计现有 microapp 示例，剔除宿主依赖 API
- [~] 用 `std.microapp.*` 改写示例
- [x] 为“不允许的 API”提供明确编译错误
- [x] 编写“源码一次编写、多 profile 编译”的示例矩阵

当前推荐的本地验证入口：

- `make microapp-check`
- `make microapp-hosted-smoke`
- `make microapp-compat-check`
- `make microapp-recovery-check`

### 阶段 7：验证与发布

- [~] 增加 profile 级 CI
- [x] 增加 `.uapp v1/v2` 兼容验证
- [~] 增加真实执行、崩溃恢复、syscall 预算回归
- [x] 发布迁移指南

当前状态可概括为：

- Linux 主线已经有全量 `microapp-check`
- hosted 平台已经有 `microapp-hosted-smoke`
- `.uapp v1/v2` 已有独立兼容入口
- recovery/update 已有独立回归入口

---

## 11. 最小可交付里程碑

建议最小里程碑不是“完整跨所有平台”，而是：

### M1

- 同一份 microapp 源码
- 可编译到 `linux_x86_64_hardvm`
- `.uapp v2` 可加载
- payload 从容器虚拟地址入口真正执行
- `SYS_PRINT / SYS_ALLOC / SYS_YIELD` 可用
- 不再依赖对照 ELF 执行

### M2

- 同一份源码
- `linux_x86_64_hardvm` + `linux_aarch64_hardvm`
- 共用同一套源码级 API

### M3

- 同一份源码
- hosted hard-vm + baremetal soft-vm
- 行为语义与错误模型统一

---

## 12. 结论

“一次编写，到处编译，native 运行”这个目标是可实现的。

但前提不是继续沿用当前“抽 `.text/.rodata` + 对照 ELF 实际执行”的过渡链路，而是要正式引入：

- 可移植源码 ABI
- target profile
- 可执行镜像 v2
- 正式 bridge ABI
- hard-vm / soft-vm 双后端

只有这样，才能同时满足：

- 源码级可移植
- 真正虚拟地址执行
- 不同目标平台 native 运行
- runtime 语义一致
