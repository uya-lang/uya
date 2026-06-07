# MicroApp Profile 说明

本文档专门解释 `microapp profile` 是什么、为什么需要它、当前有哪些 profile，以及编译器如何选择它。

---

## 1. 什么是 Profile

这里的 `profile` 可以理解成：

- 一个微程序目标运行环境模板

它不是“程序自己的业务配置”，而是：

- 这个 `microapp` 要面向哪类目标环境构建

一句话说：

- `profile = 目标运行环境的完整身份`

---

## 2. 为什么不只用 Arch

`arch` 只回答一个问题：

- 目标 CPU/ISA 是什么

例如：

- `x86_64`
- `aarch64`
- `rv32`
- `xtensa`

但微程序真正需要决定的不只有 ISA，还包括：

- 运行模型是 `hard-vm` 还是 `soft-vm`
- bridge 走 `call_gate` 还是 `trap`
- 默认 toolchain / triple 是什么
- 默认编译/链接参数是什么
- 镜像里写入哪个 `profile_id`

所以：

- `arch` 是 profile 的一部分
- `profile` 比 `arch` 更完整

---

## 3. Profile 里包含什么

`v0.9.5` 冻结的 `MicroAppTargetProfile` 对外字段包含这些关键信息：

- `profile_id`
- `arch_raw`
- `bridge_kind_raw`
- `name`
- `triple`
- `default_gcc`

这些信息会影响：

- `.pobj/.uapp` 里写入的 profile 元数据
- 目标 gcc / triple 的默认选择
- `hard-vm` / `soft-vm` 的路径选择
- `call_gate` / `trap` 的运行时路径选择
- 默认编译/链接旗标

补充说明：

- `os` / `hard-vm` / `soft-vm` / 默认 bridge 这些语义，当前以 `name + profile_id + bridge_kind_raw` 为正式外部口径
- 当前不再把更多推导语义扩成新的 public struct 字段

---

## 4. 当前支持的 Profile

当前代码里已经支持这些名字：

- `linux_x86_64_hardvm`
- `linux_aarch64_hardvm`
- `macos_arm64_hardvm`
- `rv32_baremetal_softvm`
- `xtensa_baremetal_softvm`

它们的大致含义是：

- `linux_x86_64_hardvm`
  - Linux
  - x86_64
  - `hard-vm`
  - 默认 bridge 是 `call_gate`

- `linux_aarch64_hardvm`
  - Linux
  - AArch64
  - `hard-vm`
  - 默认 bridge 是 `call_gate`

- `macos_arm64_hardvm`
  - macOS
  - arm64 / aarch64
  - `hard-vm`
  - 默认 bridge 是 `call_gate`

- `rv32_baremetal_softvm`
  - RV32 裸机
  - `soft-vm`
  - 默认 bridge 是 `trap`

- `xtensa_baremetal_softvm`
  - Xtensa 裸机
  - `soft-vm`
  - 默认 bridge 是 `trap`

---

## 5. Hard-VM 和 Soft-VM

这里的 profile 名字里会出现：

- `hardvm`
- `softvm`

它们的含义是：

- `hard-vm`
  - 运行时依赖真实页映射能力
  - payload 会被装载到容器虚拟地址空间
  - 典型宿主路径是 `mmap + mprotect + call_gate`

- `soft-vm`
  - 不依赖真实硬件 MMU
  - 统一的虚拟地址语义主要靠软件模型实现
  - 更适合裸机 / trap 路线

所以 profile 不只是“编到哪种 ISA”，还是“按哪种虚拟内存后端语义运行”。

---

## 6. Bridge 是什么

当前 profile 还会隐含一个默认 bridge：

- `call_gate`
- `trap`

含义是：

- `call_gate`
  - payload 更接近 hosted/native 入口跳转
  - 典型用于 `x86_64/aarch64 hard-vm`

- `trap`
  - payload 更接近裸机/软中断/受控 syscall 路线
  - 典型用于 `rv32/xtensa soft-vm`

所以：

- `profile` 会顺带决定默认 bridge

---

## 7. 编译器如何选择 Profile

当前选择优先级是：

1. `--microapp-profile <name>`
2. `MICROAPP_TARGET_PROFILE`
3. `MICROAPP_TARGET_ARCH` + `TARGET_OS`
4. `TARGET_OS + TARGET_ARCH`
5. `HOST_OS + HOST_ARCH`
6. 默认回退

也就是说：

- CLI 显式指定优先级最高
- `profile` 显式指定次之
- 如果没有显式 profile，编译器会优先按目标平台组合推导默认 profile
- 只有在缺少完整平台信息时，才继续退回到 arch 推导

例如：

- `TARGET_OS=linux TARGET_ARCH=x86_64` 会默认推到 `linux_x86_64_hardvm`
- `TARGET_OS=linux TARGET_ARCH=arm64` 会默认推到 `linux_aarch64_hardvm`
- `TARGET_OS=macos TARGET_ARCH=arm64` 会默认推到 `macos_arm64_hardvm`
- `rv32` 会默认推到 `rv32_baremetal_softvm`

### 7.1 Linux x86_64 Toolchain 契约

`linux_x86_64_hardvm` 是默认 profile，也是当前 Linux hosted 真执行样板。它的构建契约是：

- 未显式指定 profile 时，默认解析到 `linux_x86_64_hardvm`
- `.uapp` 构建从目标 `gcc -c` 产出的 `.o` 直接提取 section / symbol / rela
- 构建不能依赖 `objdump` / `readelf` / `nm` / `objcopy`
- 构建不能回退到“先链接中间 ELF，再导出 `.text/.rodata`”的旧链路
- payload object 不能带 undefined 宿主符号，也不能出现裸 libc/helper 符号；允许符号由 `tests/verify_microapp_payload_symbols.sh` 的白名单固定

上述契约已纳入 `make microapp-check`。本地单跑入口：

```bash
./tests/verify_microapp_payload_symbols.sh
```

---

## 8. 当前推荐用法

推荐优先用 CLI，而不是只依赖环境变量：

> 目标 CLI 为 `uya microapp build|inspect|verify|run`。在 `cmd/microapp` 完全接线前，
> 旧的 `build --app microapp` / `inspect-image` / `verify-image` 仍可作为过渡实现对照。

```bash
./bin/uya microapp build \
  --microapp-profile linux_x86_64_hardvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello.uapp
```

也支持环境变量：

```bash
MICROAPP_TARGET_PROFILE=linux_x86_64_hardvm \
./bin/uya microapp build \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello.uapp
```

如果两者同时存在：

- `--microapp-profile` 优先

如果你不想显式写 profile，也可以让目标平台 tuple 自动推导：

```bash
TARGET_OS=macos TARGET_ARCH=arm64 \
./bin/uya microapp build \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello.uapp
```

### 8.1 同一份源码的 Profile 矩阵

当前推荐直接拿同一份 portable source 做 profile 矩阵验证：

- 源码：`examples/microapp/microcontainer_hello_source.uya`
- 目标 profile：
  - `linux_x86_64_hardvm`
  - `linux_aarch64_hardvm`
  - `macos_arm64_hardvm`
  - `rv32_baremetal_softvm`
  - `xtensa_baremetal_softvm`

如果当前机器没有对应交叉 gcc，最稳的做法是先编到 `.c`，验证 profile 选择、bridge 和前端可移植子集都成立：

```bash
./bin/uya microapp build \
  --microapp-profile linux_x86_64_hardvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello_linux_x86_64.c

./bin/uya microapp build \
  --microapp-profile linux_aarch64_hardvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello_linux_aarch64.c

./bin/uya microapp build \
  --microapp-profile macos_arm64_hardvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello_macos_arm64.c

./bin/uya microapp build \
  --microapp-profile rv32_baremetal_softvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello_rv32.c

./bin/uya microapp build \
  --microapp-profile xtensa_baremetal_softvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o /tmp/hello_xtensa.c
```

当前矩阵可以这样理解：

- compile matrix：5 个 profile 都应能接受同一份源码
- runtime matrix：当前仓库里已经打通的是 `linux_x86_64_hardvm`
- 其他 profile 目前仍属于“元数据/前端契约已接通，runtime 仍待补齐”的状态

---

## 9. 和 inspect/verify 的关系

当前可以通过下面两个命令查看/校验 profile 相关信息：

```bash
./bin/uya microapp inspect hello.pobj
./bin/uya microapp inspect hello.uapp
./bin/uya microapp verify hello.pobj
./bin/uya microapp verify hello.uapp
```

其中会直接显示：

- `target_arch`
- `profile`
- `bridge`

这有助于确认：

- CLI / 环境变量是否按预期生效
- 最终镜像是否真的落在目标 profile 上

---

## 10. 当前边界

目前 profile 体系已经能驱动：

- x86_64 hard-vm
- aarch64 hard-vm
- rv32 soft-vm
- xtensa soft-vm
- macOS arm64 hard-vm 元数据路径

但还没有完全做完的部分包括：

- 多平台 profile 的完整回归矩阵
- relocation、stack、trampoline 的完整 profile 化
- 所有 hosted / baremetal profile 的运行时完全对齐

所以当前可以把它理解成：

- profile 机制已经成型
- 当前剩下的重点主要是 runtime 覆盖面，而不是 profile-first 心智本身

---

## 11. 和相关文档的关系

如果你想继续往下看，建议顺序是：

1. `docs/microcontainer/microapp_profiles.md`
2. `docs/microcontainer/source_to_uapp_pipeline.md`
3. `docs/microcontainer/portable_native_design.md`
4. `docs/microcontainer/portable_native_todo.md`
