# Uya 微应用源码到 `.uapp` 编译链说明

**版本**: v0.2  
**日期**: 2026-04-05  
**关联文档**:

- `docs/microcontainer/requirements_v1.3.md`
- `docs/microcontainer/image_validation.md`
- `docs/microcontainer/syscall_abi.md`
- `lib/kernel/image.uya`

---

## 1. 文档目的

本文档说明一条真正的“源码 -> `.uapp`”编译链应该如何设计、产出什么中间结果，以及它与当前仓库现状之间的差距。

目标不是立刻定义所有实现细节，而是先把下面三件事说清楚：

- 当前 `.uapp` 产物是怎样得到的
- 真正的编译链应该经过哪些阶段
- 后续应该由编译器、打包器、加载器各自负责什么

---

## 2. 当前状态

当前仓库已经具备以下能力：

- 已定义微容器镜像格式与加载期三重验证规范
- 已实现 `image_validate()` 对 `.uapp` 做完整性、结构、指令策略验证
- 已具备模拟加载路径 `sim_load_image()`
- 已有 `examples/microapp/microcontainer_hello.uapp` 可被加载执行
- 现阶段 `microapp` 的 `code` 仍由目标 gcc 编译并链接后的 `.text` 提供，但目标选择已经切到 `profile-first`
- `MICROAPP_TARGET_GCC` 优先于 `TARGET_GCC`，可覆盖具体工具链；默认编译/链接旗标也已按 profile 区分：
  - `call_gate` profile 默认 `-fpie/-pie`
  - `trap` profile 默认 `-fno-pie/-no-pie`
- 默认目标三元组映射当前覆盖 `rv32 / x86_64 / aarch64 / xtensa`，对应的默认 gcc 分别是：
  - `riscv32-unknown-elf-gcc`
  - `x86_64-linux-gnu-gcc`
  - `aarch64-linux-gnu-gcc`
  - `xtensa-unknown-elf-gcc`
- 当前推荐的 portable source 已经形成官方示例集：
  - `examples/microapp/microcontainer_hello_source.uya`
  - `examples/microapp/microcontainer_alloc_yield_source.uya`
  - `examples/microapp/microcontainer_time_source.uya`
  - `examples/microapp/microcontainer_bss_source.uya`

当前实现已经打通 `build --app microapp -> target gcc .text -> payload_obj -> .uapp` 这条链路。
如果后续要继续演进，重点会转向：

- 把 `code` 从 C 后端产物进一步收敛成更明确的目标载荷表示
- 为更多 `target_arch` 梳理默认 gcc 与验证策略

当前示例镜像 `examples/microapp/microcontainer_hello.uapp` 仍可作为对照，但正式的 `microapp` 路径已经能从源码一路生成到 `.uapp`。

### 2.1 当前实现进度

目前已经补上了最小的 `payload_obj -> .uapp` 实现层：

- `lib/kernel/payload.uya`
- `tests/test_kernel_payload.uya`
- `tests/run_kernel_payload.sh`

当前仓库里的 `.pobj` 版本已经开始携带源文件路径等 provenance 信息，便于后续追踪输入来源与调试中间产物。

同时，宿主侧示例 builder 已经从手工拼镜像改成调用 `payload_pack_to_uapp()`：

- `examples/microapp/microcontainer_hello_build.uya`

宿主侧示例 loader 也已经改为从命令行读取 `.uapp` 路径并走加载验证链，未传参时默认回退到示例镜像：

- `examples/microapp/microcontainer_hello_load.uya`

这意味着本文档中的“pack”阶段已经有了可运行的第一版实现，而不只是目标规划。

---

## 3. 目标定义

本文档中的“真正编译链”指的是：

1. 开发者编写微应用源码
2. 编译器以 `app` / `microapp` 语义分析源码
3. 编译器直接生成目标 profile 指定架构的载荷码与元数据
4. 打包器把代码段、只读数据段、重定位信息、权限位图等封装为 `.uapp`
5. 生成的 `.uapp` 可直接通过 `image_validate()` 验证，并进入加载执行链

换句话说，目标不是“有一个能写出 `.uapp` 的脚本”，而是：

`源码级产物能够稳定进入镜像格式与加载验证闭环。`

---

## 4. 编译链总览

建议的标准编译链如下：

1. 源码前端
2. microapp 模式语义检查
3. microapp 模式降级与约束注入
4. 目标代码生成
5. 载荷对象产物生成
6. 镜像打包
7. 镜像签名/哈希写入
8. 镜像自验证

可以抽象成：

```text
app.uya / microapp.uya
  -> parse / typecheck
  -> app / microapp semantic check
  -> microapp-safe lowering
  -> codegen(target_arch)
  -> payload code + rodata + reloc + caps
  -> payload_obj
  -> uapp pack
  -> sha256 fill
  -> image_validate
  -> app.uapp
```

这里有一个关键约束：

- `payload code` 永远是目标 profile 指定 ISA 的目标码

例如：

- `profile = linux_x86_64_hardvm` 时，载荷码就是 `x86_64` 机器码
- `profile = linux_aarch64_hardvm` 时，载荷码就是 `aarch64` 机器码
- `profile = rv32_baremetal_softvm` 时，载荷码就是 `rv32` 机器码

因此开发阶段完全可以让 profile 对齐当前开发机平台，用本机原生执行方式验证微应用逻辑；而部署阶段再切换到目标平台对应 profile。

---

## 5. 各阶段职责

### 5.1 源码前端

输入：

- 一个或多个 `.uya` 源文件

输出：

- AST
- 符号表
- 类型信息

这部分与普通编译流程一致，不需要因为 `.uapp` 单独设计一套前端。

### 5.2 app / microapp 语义检查

这一阶段是“源码能否成为微应用”的第一道门槛。

建议由编译器在显式模式下启用：

- `--app microapp`

该阶段至少要拒绝：

- `@asm`
- `extern`
- 物理地址字面量直接解引用
- 未声明 capability 的设备接口访问
- 不允许的内建或 ABI 入口

这部分应与：

- [requirements_v1.3.md](../../docs/microcontainer/requirements_v1.3.md)
- [syscall_abi.md](../../docs/microcontainer/syscall_abi.md)

保持一致。

### 5.3 microapp 安全降级与约束注入

这是 `app` 与 `microapp` 的关键分水岭。

该阶段负责：

- 将允许的宿主交互统一降为 `syscall` 或受控 Host API 包装
- 为容器态指针访问注入必要的边界/翻译语义
- 限制不可接受的控制流或指令生成路径
- 产生最终 capability 位图所需的静态信息

这一阶段不直接生成 `.uapp`，但它决定最终镜像是否有资格通过加载验证。

编译器内部当然可以有自己的 IR，但对这条外部编译链来说，没有必要把 IR 单独定义成一个正式接口层。

外部真正需要稳定下来的，是后面的 `payload_obj`。

### 5.4 目标代码生成

输入：

- 通过 microapp 模式检查并完成安全降级的源码/内部表示

输出：

- 目标架构代码
- 只读数据段
- 重定位信息

关键要求：

- 生成结果必须与 `target_arch` 一致
- 不能把“宿主工具 native 码”和“镜像载荷码”混为一谈

例如：

- `examples/microapp/microcontainer_hello_build.uya` 编译出来的是宿主工具 native 码
  - 而 `.uapp` 内部的 `code` 段，才是面向目标 profile/ISA 的载荷码

当前仓库的加载与验证主要围绕 `rv32`，但长期设计不应把 `.uapp` 限死为 `rv32`；`target_arch` 应该决定载荷 ISA。

### 5.5 载荷对象产物生成

建议在 `.uapp` 之前引入一个中间产物：

- `payload_obj`

它不是最终可加载镜像，而是编译器与打包器之间的稳定边界。

建议 `payload_obj` 至少包含：

- 目标架构
- build mode
- entry symbol / entry offset 基础信息
- code section
- rodata section
- relocations
- required capabilities bitmap
- optional exported symbol table

这样做的好处是：

- 编译器与镜像打包器可以解耦
- 未来可单独测试“编译正确”与“打包正确”
- 加载器规则变更时，不必立刻牵动所有前端代码

### 5.6 镜像打包

打包器负责把 `payload_obj` 转成最终 `.uapp`。

它应该完成：

- 写入 96 字节镜像头
- 写入代码段
- 写入 rodata 段
- 写入重定位区
- 回填 `image_size`
- 回填 `entry_offset`
- 回填 `code_size`
- 回填 `rodata_size`
- 回填 `reloc_count`
- 写入 `required_caps`
- 写入 `build_mode`
- 写入 `target_arch`

这一步当前已经有了第一版实现：`payload_pack_to_uapp()`。
当前 `build --app microapp` 生成的 `.pobj/.uapp v2` 也已经开始携带非零 `reloc_count / reloc table`，便于后续 runtime 真正应用 relocation。

长期目标应该是：

- 示例构建脚本继续演化为更完整的 packer demo
- 而不是唯一 `.uapp` 生成方式

### 5.7 哈希写入

打包器在输出最终镜像前必须执行：

1. 先将 `sha256` 字段清零
2. 对整镜像求 SHA-256
3. 将结果写回 `sha256` 字段

这一行为必须与：

- [image_validation.md](../../docs/microcontainer/image_validation.md)
- [image.uya](../../lib/kernel/image.uya)

中的校验语义严格一致。

### 5.8 镜像自验证

为了避免“编译器产物”和“加载器期望”悄悄漂移，建议打包完成后默认执行一次：

- `image_validate(output_bytes)`

也就是：

- 编译器/打包器生成镜像
- 立即用加载器同源验证器回读一次

如果自验证失败，则编译视为失败。

这样可以尽早暴露：

- 布局错误
- hash 填写错误
- `entry_offset` 越界
- 指令策略不满足

---

## 6. 命令行形态建议

建议最终用户看到的是一条面向产物的命令，而不是多脚本拼接。
目标 CLI 统一走 `uya microapp build|pack|inspect|verify|run` 命名空间；当前仓库中的
`build --app microapp`、`pack-image`、`inspect-image`、`verify-image` 仍可作为过渡实现对照。

### 6.1 最小目标命令

```bash
uya microapp build \
  --microapp-profile linux_x86_64_hardvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o examples/microapp/microcontainer_hello.uapp
```

这条命令是目标最短路径。

如果想把编译和打包拆开，仍然可以先生成 `.pobj`，再单独运行：

```bash
uya microapp pack build/hello.pobj -o examples/microapp/microcontainer_hello.uapp
```

这条目标命令可以拆成两步：

```bash
uya microapp build \
  --microapp-profile linux_x86_64_hardvm \
  examples/microapp/microcontainer_hello_source.uya \
  -o build/hello.pobj
uya microapp pack build/hello.pobj -o examples/microapp/microcontainer_hello.uapp
```

其中：

- `microapp build -o xxx.pobj` 负责前端、microapp 模式检查、目标代码生成、`payload_obj` 输出
- `microapp pack` 负责封装 `.uapp`

当前仓库里，`build --app microapp` 已经可以直接产出 `.pobj` 或 `.uapp`；宿主打包器示例主要用于对照验证和格式调试。

### 6.2 调试型命令

建议额外支持：

```bash
uya microapp inspect examples/microapp/microcontainer_hello.uapp
uya microapp verify examples/microapp/microcontainer_hello.uapp
make microapp-compat-check
```

这样可以降低镜像格式开发期的排错成本。

示例 loader 的运行方式现在也更通用了：

```bash
uya run examples/microapp/microcontainer_hello_load.uya -- path/to/your.uapp
```

如果不传路径，它会继续默认读取 `examples/microapp/microcontainer_hello.uapp`。

如果你只是想验证当前仓库已经接通的链路，推荐直接用：

```bash
make microapp-check
make microapp-hosted-smoke
make microapp-recovery-check
```

---

## 7. 建议的产物层级

建议将微应用产物链固定为三层：

1. 源码层
2. 载荷对象层
3. 镜像层

具体如下：

### 7.1 源码层

- `foo.uya`

这是开发者维护的业务逻辑源文件。

### 7.2 载荷对象层

- `foo.pobj`

这是编译器内部与打包器之间的接口产物。

它应该足够稳定，便于：

- 回归测试
- 二进制对比
- 不同 packer 后端复用

### 7.3 镜像层

- `foo.uapp`

这是最终加载器消费的产物。

加载器只需要知道：

- `.uapp` 是合法的吗
- `.uapp` 能否装入

加载器不应该反过来承担前端编译职责。

---

## 8. 宿主工具码与载荷码的区别

这一点需要单独说清楚，避免把两类产物混淆。

### 8.1 宿主工具码

例如：

- `examples/microapp/microcontainer_hello_build.uya`
- `examples/microapp/microcontainer_hello_load.uya`

这类源码编译出来的是宿主环境 native 程序。

它们负责：

- 构造镜像
- 读取镜像
- 调用验证器或加载器

它们不是 `.uapp` 里的载荷。

### 8.2 载荷码

`.uapp` 内部 `code` 段中的内容，才是微容器真正要运行的载荷码。

它的架构必须由 `target_arch` 决定。

也就是说：

- 宿主工具可以是开发机 `x86_64` 程序
- 但镜像载荷可以同时是 `x86_64`、`aarch64`、`rv32` 或其他目标架构码

### 8.3 开发阶段与部署阶段

开发阶段，完全可以把：

- `target_arch = 当前开发机架构`

这样生成的 `.uapp` 载荷码就是开发机 native 码，便于快速验证微应用逻辑，而不必依赖 ISA 模拟器。

部署阶段，再将：

- `target_arch = 目标设备架构`

生成真正下发到设备侧的载荷镜像。

因此：

- `sim.uya` 更适合作为目标载荷验证与加载测试路径
- 而不应成为日常微应用逻辑开发的唯一主路径

---

## 9. 与 capability / 微应用平台的关系

如果未来上层产品表达改为“手表微应用平台”，那么：

- `.uapp` 是执行载荷
- manifest / capability 权限声明是产品层描述
- 微容器 runtime 是执行与隔离层

可以理解为：

```text
微应用源码
  -> 编译为 .uapp
  -> 被 capability / 微应用管理层安装
  -> 由微容器 runtime 验证并执行
```

这意味着未来很可能有两类文件：

1. 微应用二进制载荷：
   - `.uapp`

2. 微应用描述文件：
   - manifest / package metadata

前者回答“跑什么”，后者回答“怎么装、要什么权限、由谁发布”。

---

## 10. 当前仓库建议的最小落地顺序

为了尽快把“手工构造镜像”升级为“源码编译镜像”，建议按下面顺序推进。

### 10.1 第一步：固化 `payload_obj`

先定义一个最小中间产物格式，不急着一步到位。

只要能表达：

- entry
- code
- rodata
- reloc_count / reloc table
- required_caps
- target_arch

就足够支撑第一版。

### 10.2 第二步：把示例源码编译为 `payload_obj`

先不要直接打 `.uapp`。

先证明：

- 源码能变成规范化 `payload_obj`

### 10.3 第三步：实现通用 packer

把当前示例中的人工头部拼装逻辑抽成通用 packer。

这一步完成后，应该变成：

- `hello.uya -> hello.pobj -> hello.uapp`

而不是：

- `build script -> hardcoded hello.uapp`

### 10.4 第四步：接入自验证

打包完成后自动调用：

- `image_validate()`

把打包错误前置到构建期。

### 10.5 第五步：接入加载执行回归

对关键示例执行：

- `sim_load_image()`

这样就把：

- 编译
- 打包
- 校验
- 加载

串成了真正闭环。

---

## 11. 验收标准

当满足下面条件时，可以认为“源码 -> `.uapp` 编译链”已经初步成立：

1. 开发者只需编写 `.uya` 源码，不需要手工拼镜像头
2. `microapp build` 能产出 `payload_obj`
3. `microapp pack` 能把 `payload_obj` 打包为 `.uapp`
4. 生成的 `.uapp` 默认通过 `image_validate()`
5. 示例镜像能通过 `sim_load_image()` 正常运行
6. 非法源码或非法指令路径会在编译期或打包期被拒绝

---

## 12. 当前与目标的差距总结

当前已经有：

- `.uapp` 规格
- `.uapp` 校验器
- `.uapp` 模拟加载路径
- 手工构造镜像示例

当前还缺：

- 源码级 `microapp` 编译产物定义
- `payload_obj` 中间层
- 通用 `.uapp` packer 的目标入口：`microapp pack`
- 从源码直接产出 `.uapp` 的正式命令入口：`microapp build`

所以当前阶段最准确的表述应该是：

> 仓库已经证明微容器镜像格式、校验与加载链路可行，但尚未完全打通“微应用源码直接编译为 `.uapp`”的正式编译链。

---

## 13. 建议的下一步

最值得优先推进的不是继续写更多手工构造示例，而是：

1. 定义 `payload_obj`
2. 抽出通用 `microapp pack`
3. 让示例源码成为真正的编译输入
4. 把 `.uapp` 从“脚本构造产物”升级为“编译链产物”

这样后续无论是微容器路线，还是手表微应用平台路线，都会更扎实。
