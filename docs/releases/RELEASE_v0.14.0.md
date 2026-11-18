# Uya v0.14.0 发布说明

> **类型**：**执行性能 + 安全证明增强**（minor）
> **发布日期**：2026-11-18
> **语言规范**：0.49.57（无语义变更）

**v0.14.0** 的主线是「同一份 bytecode，两条执行路径」：exec VM 热点指令快速分派把解释执行从
秒级压到毫秒级；在同一份 `BCProgram` 上新增了内存 JIT 原型 `--jit`。同时，跨函数非空证明
（B2）收口了局部别名、调用链传播与全局 const null 三种缺口，C99 后端修掉切片下标、宽整数字面量、
字符串插值与装箱接口返回等一批真实缺陷。

---

## 核心变更

### 1. exec VM：热点指令快速分派

`vm_step_fast()` 在 103 路 opcode 链之前直接处理 `BC_JMP`、`BC_JMP_IF_FALSE`、`BC_LOAD_LOCAL`、
`BC_STORE_LOCAL`、`BC_ADD_SAT`、`BC_CMP_LT`、`BC_CMP_NE`。`BC_LOAD_CONST` 曾进入快速路径，但会让
全局结构体常量初始化用例出现字段越界回归，已移除。

- 500 万次 `u64` 饱和加循环：慢速链 `2161~2261 ms` → 快速分派 `6 ms`（约 360×）。
- 端到端 wall time：`2.32 s` → `0.032 s`。
- A/B 开关：`UYA_VM_FAST_DISPATCH=0` 全关；`UYA_VM_FAST_MASK` 按 opcode 组关。
- 回归：`tests/test_exec_vm_fast_dispatch.uya` 覆盖饱和加、比较、条件跳转与函数调用。

### 2. bytecode 内存 JIT 原型 `--jit`

`--jit` 只对 `run` 生效：当 `main` 恰好由 `LOAD_CONST` + `RET` 组成时，在 `mmap` 的可执行内存里
写入 x86-64 `mov eax, imm32; ret`，经 `uya_call0_i32` 直接调用；其他情况自动回退 VM。
这是一个**受控原型**，不是通用 JIT：局部变量、算术/比较、跳转、调用、hostcall、聚合值、错误联合
与 aarch64 均未覆盖。设计路线与阶段划分见 [docs/bytecode_jit_design.md](../bytecode_jit_design.md)。

### 3. 跨函数证明与 C99 后端修复

- B2 非空义务认出局部别名、沿具名调用链传播（深度上限 3）、认出初值为 null 的全局 const。
- 动态切片下标补运行时守卫；定长切片常量下标接上边界检查；全局数组开窗的类型错配修好。
- `&数组` 传 `&[T:N]` 形参生成正确切片视图；宽整数字面量不再被 i32 常量折叠截断。
- 字符串插值三连修（静默空指针 / 栈溢出 / 读越界）；装箱局部接口值返回不再悬垂或链接失败。
- 新增 `--strict-loop-bounds`；审计面扩容到 41 个根、40 个标准库模块，`ptr_int` 逃逸面 35785 → 197。

### 4. 文档与覆盖口径

- exec VM census 更新到 927/928（99.9%，跳过 5），旧的 24% / 909/913 明确标为历史快照。
- exec VM / C99 parity 为 927/932；5 个 STATUS_MISMATCH 在快速分派开关下表现一致，均为既有差异。
- 新增 JIT 设计文档与 VM 快速分派实测记录，所有 A/B 开关与回退行为都有文档可查。

---

## 验证

| 项目 | 结果 |
|---|---|
| `make release` | ✓ 2026-11-18 通过（clean 冷启动 → 自举字节一致 → `make check` → 种子刷新 → `-O3 -DNDEBUG` + strip 发布构建） |
| `bash tests/verify_version_sources.sh` | `version sources ok (0.14.0)` |
| `make exec-census` | 927/928（99.9%），唯一失败为既有 `test_interface_box_return.uya` |
| `make exec-parity` | 927/932；5 个既有 STATUS_MISMATCH，与本次改动无关 |

---

## 已知限制

- `--jit` 是原型，仅支持常量返回 `main`，不能替代通用 native 后端；默认 `run`/`test` 行为不变。
- macOS W^X 可能让 JIT 不可用，此时回退 VM。
- exec VM 与 C99 仍有 5 个既有差分用例，详见 `docs/exec_vm_c99_parity.md`。
