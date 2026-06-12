# MIR-C99 Backend Contract

**状态**: v0.1 contract
**更新日期**: 2026-06-12
**配套 TODO**: `docs/todo_mir_c99_backend.md`
**覆盖矩阵**: `docs/portable_mir_language_coverage.md`
**架构设计**: `docs/compiler_1s_architecture_design.md`

---

## 1. 目标

MIR-C99 是独立 target backend。它消费 verifier-clean `PortableMIR`，生成最小低级 C99，再交给
host C99 compiler 编译、链接和运行：

```text
CoreBody -> PortableMIR -> MirC99Plan -> MirC99Emitter -> host C99 compiler
```

这里的 C99 是 portable assembly，不是 Uya 源码重建格式。MIR-C99 只要求输出满足 C99 compiler、
linker 和 runtime behavior 合同；它不追求可读性、源码结构还原、原始变量名、原始 block 形状或原始
statement 形态。

MIR-C99 的目标程序是合法 Uya 程序，而不是某个自举源码特例。`cmd/build` self-build 只是普通程序经同一套
parser、checker、CoreBody、PortableMIR 和 MirC99Emitter 后的验收样本；任何 self-build frontier 都必须归因到
CFG、value、place/memory、types/layout、call ABI、cleanup/error、runtime capability、async frame 或 MIR
instruction coverage 等通用语言结构。

## 2. 输入边界

MIR-C99 backend 的唯一生产输入是 `MirTargetBackendRequest` 中已验证的 `PortableMirModule` 及其 target
profile、backend kind、verifier result 和 MIR 显式 metadata。

允许消费：

- `PortableMIR` function、block、terminator、value、local、type、layout、debug location 和 capability
  requirement。
- CoreIR 已冻结并下沉到 MIR metadata 的 call ABI、helper reference、layout identity、cleanup edge、
  async frame、error-union 和 target capability 信息。
- host target profile 中明确登记的 size、align、pointer width、runtime helper 和 link capability。

禁止消费：

- AST body、AST statement/expression tree 或 parser 私有结构。
- `LoweredProgram` body、CoreBody body 或未下沉到 MIR 的 checker/typed-program 查询结果。
- 现有 AST/LoweredProgram C99 backend 的生产 emitter、planner、split-C writer 或 safe-name cache。
- 后端本地 discovery 产生的新泛型实例、类型布局、runtime helper、async frame 或 error-union layout。

如果 MIR-C99 发现缺失 metadata，必须把缺口推回 CoreIR / PortableMIR 合同或输出 capability diagnostic；
不得回查高层 body 或调用现有 C99 作为语义补丁。

## 3. 输出合同

MIR-C99 输出分两层：

- `MirC99Plan`：稳定记录 C unit、include、typedef、prototype、global、function、helper reference、
  link item、fingerprint 和 diagnostics。
- `MirC99Emitter`：只把 `MirC99Plan` 输出为 C bytes，不重新解析 Uya 语义，不发现新 symbol，不改变
  `PortableMIR`。

首版可以只生成一个 `.c` unit，但数据结构必须是 `MirC99Unit[]`，且 unit fingerprint、prototype/global/function
表、helper registry 和 link plan 都必须可动态增长。单文件输出是阶段策略，不是架构上限。

生成的 C99 应优先使用低级、可预测的形态：

- MIR function -> C function。
- MIR block -> C label。
- MIR branch -> `goto` / `if (...) goto ...; goto ...;`。
- MIR value/local -> C temp 或 addressable local slot。
- MIR place/load/store -> C address expression、load、store 或 helper call。
- MIR cleanup/error/async -> 已在 MIR 中显式化的 CFG、state 或 helper reference。

## 4. 非目标

MIR-C99 明确不追求以下目标：

- 生成可读、可维护或接近手写风格的 C。
- 恢复原始 Uya 函数体、statement nesting、scope nesting、变量名或注释。
- 保持现有 `src/codegen/c99*` 输出文本、split-C 文件布局或 safe symbol 命名。
- 用固定函数名、固定 statement count、固定 AST/body shape 或编译器源码白名单证明成功。
- 用现有 C99 backend 成功替代 MIR-C99 成功。
- 为了目标 backend 方便而新增 Uya 语法、关键字、内建函数、checker 方言或 proof 绕过。

## 5. 禁止路径

MIR-C99 生产路径不得：

- `use codegen.c99`、`use codegen.c99_build` 或等价导入现有 C99 生产 backend。
- 调用 `c99_codegen_generate`、`C99CodeGenerator`、legacy `C99Plan` 生产 emitter 或现有 split-C writer。
- 读取 AST body / `LoweredProgram` body 来补 MIR-C99 语义。
- 在 MIR verifier 失败时继续生成 C。
- 静默 fallback 到现有 C99 backend 后声称 MIR-C99 成功。
- 把 unsupported capability 降级成 noop、hostcall 偷换、普通 C 赋值或跳过 safety proof。

现有 C99 backend 只能作为 oracle、fallback 和 release 兜底。parity harness 可以调用它生成 oracle 结果，但
MIR-C99 的生产成功路径必须由 `PortableMIR -> MirC99Plan -> MirC99Emitter` 独立完成。

## 6. Capability 与 Reject

MIR-C99 不支持某个 target capability 时，必须输出明确 diagnostic，并在覆盖矩阵中登记为 `reject`。diagnostic
至少包含：

- capability 名称。
- 触发的 MIR instruction、helper reference 或 source attachment。
- target profile。
- 缺失的 backend/runtime/link 支持。

`reject` 不是永久失败；它是已登记、可复现且不会静默 fallback 的状态。async frame 属于完整语言支持范围，
不能作为 MIR-C99 v1 的长期 reject。atomic、SIMD、`@asm`、`@syscall` 和 `@c_import` 等 target-sensitive
能力在支持前可以按矩阵登记 reject；支持后必须进入 parity。

## 7. 完成证据

MIR-C99 的 `done` 只能由以下证据支撑：

- 专用 MIR-C99 harness 生成 `.c`，host C99 compiler 编译、链接、运行，并与现有 C99 oracle 的 stdout、
  stderr、exit code 和 diagnostics 对齐。
- MIR-C99-built compiler 复跑 `cmd/build` self-build、compiler regression、C99 output parity 和完整语言后端
  parity 通过。
- unsupported capability 产生明确 MIR-C99 diagnostic，并在
  `docs/portable_mir_language_coverage.md` 中登记为 `reject`。

以下证据不能单独标记 MIR-C99 `done`：

- 现有 AST/LoweredProgram C99 backend 成功。
- 只通过 MIR dump 或 verifier，没有 host C99 compiler 编译运行结果。
- 固定源码样本、函数名白名单或 body-shape 白名单。
- 只生成 C 文本但没有运行结果和 no-fallback 检查。

## 8. Minimal C99 子集

MIR-C99 emitter 只能把 `PortableMIR` 映射成低级、可移植、接近 assembly 的 C99 子集。允许形态：

- C99 include、typedef、struct/union/enum declaration、extern prototype、global definition 和 function definition。
- block label、`goto`、`if (cond) goto label; goto label;`、`return expr;`、`return;`。
- scalar local、addressable local slot、temp assignment、load/store、field/index address、pointer dereference。
- integer/float scalar arithmetic、comparison、logical operation、cast 和 explicit helper call。
- 由 MIR capability/helper reference 显式登记的 `memcpy`、`memset`、`memcmp`、stdout/runtime、file/env/link helper。
- 只使用可移植 C99 表达的 layout check；需要 compile-time check 时使用 `typedef char array[(expr) ? 1 : -1];`
  形式承载 size/align/offset 断言，必须避免 C11 或 compiler extension。

禁用形态：

- C11 `_Static_assert`、`_Generic`、`_Atomic`、`thread_local`。
- GCC/Clang extension：`typeof`、`__typeof__`、statement expression `({ ... })`、nested function、computed goto
  `goto *expr`、labels-as-values `&&label`、`__attribute__`、`__builtin_*`、`__asm__`。
- 可读源码还原目标：原始 Uya statement nesting、原始变量名恢复、AST pretty-print、backend-local source reconstruction。
- 依赖 host compiler 非 C99 语义来提供 Uya safety proof、atomic semantics、SIMD semantics 或 unsupported capability。

如果某个语言面确实需要超出该子集，必须先在 MIR-C99 TODO 和覆盖矩阵中登记 capability / ABI 决策，再扩展本文和
对应 gate；不能在 emitter 中直接输出扩展语法。

## 9. 后续门禁引用点

后续测试和脚本应以本文作为边界口径：

- `tests/verify_mir_c99_independent_boundary.sh`：扫描 MIR-C99 源码禁止导入或调用 legacy C99 生产 backend。
- `tests/verify_mir_c99_minimal_subset_contract.sh`：固定 MIR-C99 允许的低级 C99 子集和禁用项。
- `tests/verify_mir_c99_oracle_parity_harness.sh`：统一生成 MIR-C99、现有 C99 oracle、host C compiler 编译运行、
  stdout/stderr/exit diff 和 no-fallback 检查。
- `docs/portable_mir_language_coverage.md`：逐 kind 记录 MIR-C99 `missing` / `partial` / `done` / `reject`。
