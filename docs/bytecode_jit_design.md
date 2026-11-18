# Uya Bytecode JIT / Native 后端草案

**版本**：v0.1
**日期**：2026-11-18
**状态**：原型已落地（M0/M1）；仅支持常量返回 `main`，其余情况回退 VM。

## 1. 结论与定位

实测数据（同一台机器，`tests/` 语料外的小型基准）：

| 负载 | C99 + `gcc -O2` 端到端 | 已编译原生程序执行 | VM 慢速链 | VM 快速分派 |
|---|---|---|---|---|
| 100k 次 u64 饱和加 | 0.142 s | ~1 ms | 50 ms | ~7 ms |
| 5M 次 u64 饱和加 | 0.148 s | 3 ms | 2161~2261 ms | 6 ms |

结论：

- **AOT / native 的运行期确实比 VM 快**：同一循环原生 3 ms，VM 即使加了快速分派仍是 6 ms。
- 但 `run` 的总耗时还包含 codegen + 宿主工具链。小项目里 `gcc` 只要 ~0.15 s，端到端与 VM 接近；大项目里 C99 codegen 曾测到 13 s，VM 反而更优。
- 因此 JIT 的价值不是“替代 build”，而是给 `run/test` 一条**低启动开销 + 接近原生执行速度**的第三选择。

## 2. 为什么以 bytecode 为界

`exec` 后端已经把 checked AST 降成稳定的 `BCProgram`：

```text
checked AST -> Exec HIR -> Bytecode -> VM
```

- `src/exec/bytecode.uya` 的 `BCProgram` 已包含 `functions`、`const_pool`、`globals`、
  `host_calls`、`error_names`、测试入口与 argv 注入字段，足以作为 JIT 输入。
- `make exec-census` 当前 **925/926（99.9%）**，语义覆盖面已足够支撑差分验证。
- 不要复活遗留的 `BACKEND_LLVM` 枚举；源码树里没有 `src/codegen/llvm_capi/`，
  `src/compile.sh` 对它的引用是历史残留。
- 也不要从 C99 文本反推机器码；继续走 `src/exec/` 这条自有 IR 路线。

## 3. 产物形态

| 命令 | 产物 | 说明 |
|---|---|---|
| `run --vm` | bytecode，VM 解释 | 当前主线 |
| `run --jit` | 内存机器码 | 新目标：不落盘、不调用 gcc |
| `build --native` | 目标文件 / 可执行文件 | 后续 AOT 目标，可选 |

第一阶段只做 `run --jit`；`--native` AOT 放到机器码发射器稳定之后。

## 4. 执行模型

生成代码不重新定义值语义，而是**沿用 VM 的槽位模型**：

- 每个 `BCFunction` 编译成一个原生函数，签名对齐
  `exec_vm_run_frame()`：`i32 jit_fn(&ExecVmState, &ExecValue, &ExecValue)`。
- 局部变量仍以 `ExecValue` 数组表示；`slot_count` 来自 `BCFunction`。
- 标量 opcode（`LOAD_LOCAL`、`STORE_LOCAL`、`ADD`、`CMP`、`JMP`、`RET` 等）直接发射机器码。
- 聚合值、`BC_HOSTCALL`、`BC_CALL_INDIRECT`、错误控制流调用现有 `exec_*` helper，
  避免重写 `retain/release`、arena GC 和 errno 语义。
- 常量池 / 全局变量 / 字符串用重定位表在装载时 patch 绝对地址。
- `BCHostCallSite.id` 是数值 id，Generated code 直接按 id 调用宿主桥，不做函数名查找。
- 某函数遇到未支持 opcode 时：该函数回退 VM；整程序仍可混合执行。
  不允许静默产出错误结果。

## 5. 发射器约束

- 首个目标 `x86_64` / System V AMD64；`aarch64` 后续。
- 代码缓冲区用 `mmap` 申请；Linux 用 `PROT_READ|PROT_WRITE|PROT_EXEC`，
  macOS 需处理 W^X（`pthread_jit_write_protect_np` / entitlement）；拿不到可执行内存时回退 VM。
- MVP 可以全栈槽位寻址，不做寄存器分配；只把热路径的标量运算放在寄存器里。
- 生成函数遵守宿主 ABI：保存 callee-saved 寄存器，正确对齐栈，保留 16 字节栈对齐。
- 发射器本身必须用 Uya 写，遵循现有代码风格，不引入新语法。

## 6. 阶段划分

| 阶段 | 内容 | 完成判据 |
|---|---|---|
| M0 | CLI `--jit`、backend 枚举、装载器、回退 VM | 所有用例仍走 VM，CLI 可观察 |
| M1 | 标量 opcode：`LOAD_LOCAL`/`STORE_LOCAL`/`ADD`/`CMP`/`JMP`/`RET` | 纯计算用例与 C99 输出/退出码一致 |
| M2 | 常量池、全局变量、`HOSTCALL` 数值分发 | stdio 用例差分通过 |
| M3 | 聚合值 helper 调用、错误联合、`CALL_INDIRECT` | census 子集通过，剩余用例明确回退原因 |
| M4 | 可选 `build --native` AOT + 代码缓存 | 产物可独立运行，缓存命中可观测 |

## 7. 验证方式

- 每个阶段用同一批用例做三方差分：`run`、`run --vm`、`run --jit` 的 stdout / 退出码 / 测试摘要一致。
- 性能基准固定两条：100k 次与 5M 次饱和加循环，分别记录编译耗时与执行耗时。
- 全量门禁仍以 `make exec-census` / `make exec-parity` 为准；JIT 回退必须带稳定原因码。

## 8. 风险

- macOS W^X 与代码签名可能使 JIT 不可用，必须有 VM 回退。
- 聚合值的 `retain/release` 与 arena GC 不能在生成代码里重写，必须复用 helper。
- 自举要求发射器自身能被 Uya 编译器编译，不能依赖宿主 C 源文件。
- JIT 编译时间可能抵消小程序的收益；需要在基准中分开报告“编译”与“执行”两段。

## 9. M0/M1 原型现状（2026-11-18）

已落地：

- `src/exec/jit.uya`：`--jit` 时检查 `main` 是否为 `LOAD_CONST` + `RET`；命中则在 `mmap(PROT_READ|WRITE|EXEC)` 内存写入
  `mov eax, imm32; ret`，经 `uya_call0_i32` 直接调用，随后 `munmap`。
- `src/exec/main.uya`：`exec_run_jit_program()` 先尝试 JIT，不支持则回退 `vm_run_program()`。
- `src/main.uya`：`--jit` CLI 开关与 verbose 命中标志；仅对 `run` 生效，`test` 仍走 VM。
- `tests/test_exec_jit_smoke.uya`：常量返回 0 的最小回归。

验证结果：

- `run --jit tests/test_exec_jit_smoke.uya`：退出码 0，verbose 报 `exec jit 命中: 1`，VM 运行耗时 0 ms。
- `run --jit` 一个返回 7 的最小程序：退出码 7，确认执行的是生成的机器码而不是 VM 默认值。
- `run --jit tests/test_exec_vm_fast_dispatch.uya`：verbose 报 `exec jit 命中: 0`，自动回退 VM，退出码 0。
- 完整 `make exec-census`：927/928（99.9%），跳过 5；唯一失败 `test_interface_box_return.uya` 仍为既有问题。
- 完整 `make exec-parity`：927/932，跳过 1；5 个 STATUS_MISMATCH 在 `UYA_VM_FAST_DISPATCH=0/1` 下表现一致，均非本次改动引入。

未覆盖：局部变量、算术/比较、跳转、调用、hostcall、聚合值、全局变量、错误联合，以及 aarch64。`--jit` 目前是**受控原型**，
不改变默认 `run`/`test` 行为；M2 起按第 6 节阶段扩展。
