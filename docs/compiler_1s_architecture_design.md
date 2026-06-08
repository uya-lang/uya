# Uya 编译器 1 秒冷构建设计

**版本**: v0.1
**日期**: 2026-06-04
**状态**: design draft
**配套评估**: `docs/compiler_1s_speed_assessment.md`
**配套 TODO**: `docs/todo_compiler_1s.md`

---

## 1. 背景

当前 `make uya` 的主路径仍是：

```text
backup/bin seed 或现有 bin/uya
  -> Uya 前端解析 src/main.uya 及依赖
  -> checker / optimizer
  -> C99 codegen
  -> split-C / 单文件 C
  -> 宿主 cc 编译链接
  -> bin/uya
```

按 2026-06-04 的本机复核，直接 C99 生成 `src/main.uya` 约 20 秒，`make uya` 真实落地约 30 秒。主要瓶颈不是某一个慢函数，而是当前架构把多个高成本动作叠在了一起：

- `src/main.uya` 入口仍带入 compiler core、C99、exec、microapp、kernel image/payload、upm lib、fmt 等大量子系统。
- checker / codegen 都把扁平 `AST_PROGRAM.program_decls` 当全局数据库，频繁做线性查找和字符串比较。
- C99 后端在输出 C 的同时继续做名称解析、类型推断、泛型实例发现、err_union/async frame 补登记和 split-C 规划。
- `make uya` 的最终产物还要经过宿主 C 编译器；传统 `cc` 全量编译大体量 C 文件本身无法稳定进入 1 秒。

因此，“1 秒冷构建”不是 C99 后端微优化问题，而是自举架构问题。

---

## 2. 目标

### 2.1 硬目标

在 Linux x86_64 主线下，满足：

```bash
make clean
make uya
```

冷构建 `bin/uya` 的三次中位数小于 1.0 秒，P95 小于 1.2 秒。

同一口径下还必须把内存打下来：

- Phase 0 先记录可信 `peak_rss_kb`、compiler arena 峰值、输出字节数和中间产物字节数。
- Phase 3 前，直接 C99 路径 peak RSS 至少低于 Phase 0 基线 25%。
- Phase 5 前，native build compiler 路径 peak RSS 至少低于 Phase 0 基线 50%。
- 最终 `make clean && make uya` 不能通过把时间换成内存来达标；RSS、arena 和输出体积都必须随阶段下降。

### 2.2 约束

- 保持准确性：默认安全证明语义不能为了 KPI 被静默关闭。
- 纯源码重编：硬 KPI 不依赖提交 `.o`、IR cache、平台二进制或常驻 daemon。
- C99 继续保留：C99 后端是可审计产物、跨平台兜底和差分 oracle。
- 当前完整语言 native 第一平台固定为 Linux x86_64 hosted；freestanding / nostdlib 作为 build-seed
  下沉目标继续保留，其它平台后续扩展。
- 不改变 Uya 语法、BNF 或内建函数；语言规范不因本设计自动升级。
- 所有随程序规模增长的表都必须动态扩容；不得用写死槽数或固定最大项数换取暂时可跑。

### 2.3 非目标

- 不要求第一阶段把所有用户程序编译都压到 1 秒。
- 不要求第一阶段替代 `build -o app.c` 的 C99 输出能力。
- 不把热增量、ccache、daemon 或对象缓存计入硬 KPI。
- 不用“预分配巨大表”换取表面速度；索引必须有按需增长、负载因子、溢出检查和失败诊断。
- 不以 VM/exec backend 作为 `make uya` 的最终产物生成路径；exec 仍主要服务 `run/test`。

---

## 3. KPI 分层

| 层级 | 口径 | 时间目标 | 内存目标 | 说明 |
| --- | --- | ---: | ---: | --- |
| L0 | benchmark 可信度 | 可复现 | 记录 `peak_rss_kb` | 不覆盖 `bin/uya`，固定 `-O2`、临时输出、profile 字段 |
| L1 | 直接 C99 codegen body | `< 4000ms` | RSS 降低 25% | 先证明语义索引与局部查找收敛 |
| L2 | 直接 C99 全流程 | `< 5000ms` | arena 峰值下降 | C99 作为 oracle，不作为 1 秒硬路径 |
| L3 | launcher 冷构建 | `< 1000ms` | 只保留 launcher 常驻集 | 入口瘦身后可先达成 |
| L4 | `cmd/build` native 冷构建 | `< 1000ms` | RSS 降低 50% | 1 秒硬目标的真正路径 |
| L5 | `make uya` 冷构建 | `< 1000ms` | 不高于 L4 | `make clean && make uya` 端到端 |

L1/L2 是工程安全垫；L4/L5 才是 1 秒承诺。

---

## 4. 总体架构

目标流水线：

```text
Parse
  -> Binder / Resolver
  -> SemanticDb
  -> TypeCheck
  -> TypedProgram
  -> CoreLower
  -> LoweredProgram / CoreIR
  -> PortableMIR
  -> BuildPlan
  -> Target backend
```

其中：

- `SemanticDb` 是全程序符号、模块、作用域、类型和导入导出的稳定数据库。
- `TypedProgram` 是 checker 对外合同，后端不得再重新推断类型。
- `CoreLower` 负责收敛泛型、async、err_union、drop/defer、runtime helper 闭包，输出
  `LoweredProgram` / CoreIR 程序清单，并用 `CoreBody` 冻结完整函数体语义。
- `PortableMIR` 消费 frozen `LoweredProgram + CoreBody`，生成低级 CFG/value/memory IR，供 native、PTX、
  exec、C99 等后端复用。
- `BuildPlan` 描述要生成哪些二进制、命令、seed、链接单元和验证产物。
- `Target backend` 将 `PortableMIR` 映射到 `MachineModule`、`PtxModule`、exec bytecode 或 staged C99 plan。
- `NativeEmitter` 是 `make uya` 1 秒目标的主路径；完整语言 parity 第一阶段走 hosted native。
- `C99Emitter` 只消费已完成的 plan，不再边打印边解析语义。

---

## 5. 语义数据库

### 5.1 动态表原则

所有编译器表都必须采用动态增长结构，程序规模相关表没有固定容量例外：

- `SemanticDb`、`TypedProgram`、`LoweredProgram`、`PortableMIR`、`C99Plan`、`NativePlan`、intern 表、scope 表、worklist、reloc/symbol table 都不得使用 `C99_MAX_*`、`CHECKER_*_SIZE`、固定数组长度或魔法容量作为语义上限。
- 该规则同时适用于现有 C99/checker/exec 代码里的旧表；迁移计划不能只约束新模块。
- 每个表必须显式记录 `count`、`capacity`、`bytes` 和可选的 `realloc_count`。
- 每个表必须提供 `reserve`、`ensure_capacity`、`append/insert` 或等价接口；增长策略可按 1.5x/2x，但必须检查整数溢出。
- hash table 必须按负载因子增长，冲突处理不得退化为全程序线性扫描；高冲突场景要有回归测试。
- allocation/growth 失败必须返回明确错误或 diagnostic，不能静默截断、覆盖旧项或继续生成错误代码。
- 迁移前允许保留旧固定表作为 oracle 或 fallback，但不能作为 1 秒路径的成功条件；任何 `count >= MAX` 后静默丢弃、截断或继续生成的逻辑都必须先改成错误诊断。
- 静态数组只允许用于语言或 ABI 明确定界的非 table 小栈/小缓冲，并且必须在代码旁说明界限来源；凡是承担 table/index/cache/list/mapping 角色，或与源文件数、声明数、表达式数、函数数、类型数、泛型实例数、字符串常量数、reloc 数相关的结构，都不属于此例外。
- benchmark 必须能报告所有编译器表的峰值容量、实际项数、重分配次数和字节数；可先按表类别汇总，但不能遗漏新引入的表，防止“动态表”变成隐藏的大块预分配。

### 5.2 现有固定表迁移范围

初扫当前源码后，以下旧表必须纳入迁移，不得在新架构中继续作为容量上限：

| 区域 | 代表文件 | 必须动态增长的内容 |
| --- | --- | --- |
| C99 codegen state | `src/codegen/c99/internal.uya` | string constants、embedded constants、struct/enum/function/global/local tables、defer/drop stacks、slice/err_union/SIMD tables、mono instances、async await/bind tables |
| C99 direct caches | `src/codegen/c99/global.uya`, `src/codegen/c99/types.uya`, `src/codegen/c99/utils.uya` | identifier ref cache、identifier type cache、type-to-C cache、safe identifier cache、string constant cache |
| checker lookup/generic/reachability | `src/checker/lookup.uya`, `src/checker/types.uya`, `src/checker/generics.uya`, `src/checker/symbols.uya` | lookup caches、mono instance index、function table、reachable function roots/queue |
| exec / VM staging | `src/exec/lower.uya`, `src/exec/builder.uya`, `src/exec/frame.uya` | locals/globals/scope stacks、HIR functions/globals、bytecode instrs、const pool、cleanup scopes、frame slots |
| main compiler input graph | `src/main.uya` | input files、resolved files、processed files、program list |

迁移顺序建议先从 C99/checker 热点表开始，因为它们同时影响 1 秒目标、内存目标和 correctness。exec/VM 表如果不在 `make uya` 最终路径中，也必须在相关 staged smoke 中保持动态增长，避免以后成为自举边界。

### 5.2.1 旧固定表临时保留标注

动态表基础设施完成前，旧固定表只能作为 legacy oracle/fallback 留在迁移边界内，不计入 1 秒硬路径成功。任何 benchmark、阶段 KPI 或 release readiness 都不能把下表中的 legacy/fallback 路径当作 L4/L5 成功证据；只有迁到动态表后的 `cmd/build` native hard path 才能计入 1 秒承诺。

| 区域 | 临时角色标注 | 不能计入 hard path 的原因 | 退出条件 |
| --- | --- | --- | --- |
| `src/main.uya` 旧驱动输入图 | legacy driver fallback | 输入/依赖/program 列表仍有固定容量，当前仅用于旧入口兼容和自举兜底 | `FileId`/dependency worklist/program range 迁为动态 vector |
| `src/codegen/c99/` 固定 codegen 表 | C99 oracle / fallback | C99 是差分 oracle 与跨平台 fallback，不是 1 秒主路径；固定 registry/cache/worklist 不能作为成功容量 | C99Plan/C99Emitter 改为动态 plan/table 后保留 oracle，后续可增加 MIR->C99Plan |
| `src/checker/` 固定 checker 表 | legacy checker oracle until SemanticDb | checker hash/cache/proof/worklist 仍由固定容量承载，只能作为 SemanticDb 迁移前的对照实现 | SemanticDb/TypedProgram 动态索引接管 lookup、mono、proof 和 reachability |
| `src/exec/` 固定 VM 表 | staged exec fallback | exec VM 仍是 staged backend，locals/bytecode/frame/cleanup/call args 固定表不能定义自举容量 | PortableMIR + bytecode/frame dynamic vector 或 native path 替换固定 staging 表 |

### 5.2.2 固定表新增冻结门禁

动态表基础设施完成前，不得新增任何承担 compiler table/index/cache/list/mapping 角色的固定容量结构。新增小缓冲只有在不承载源文件数、声明数、函数数、类型数、局部变量数、泛型实例数、字符串常量数或 bytecode/reloc 项数时才允许，并且不能使用 `C99_MAX_*`、`CHECKER_*_SIZE`、`EXEC_MAX_*` 或等价语义上限命名。

该冻结期由 `tests/verify_no_fixed_compiler_tables.sh` 对 diff 执行门禁；策略自测必须覆盖 `src/main.uya`、`src/codegen/c99/`、`src/checker/` 和 `src/exec/`，直到 Phase 1 动态 vector/hash/range builder 和 SemanticDb 动态索引完成后，才允许按动态表 API 新增 compiler 表。

### 5.3 核心 ID

引入以下稳定 ID：

```text
FileId
ModuleId
InternedNameId
DeclId
SymbolId
ScopeId
TypeId
ExprId
FunctionId
MonoInstanceId
```

所有热点比较必须优先比较整数 ID。字符串只在：

- lexer/parser 输入阶段
- intern 表首次登记
- diagnostics 输出
- C 名字/native symbol 名字最终生成

这四类路径使用。

### 5.4 声明索引

`SemanticDb` 构建以下索引：

```text
decls_by_name: InternedNameId -> DeclRange
functions_by_name: InternedNameId -> FunctionOverloadRange
types_by_name: InternedNameId -> TypeDeclRange
enum_variants_by_name: InternedNameId -> EnumVariantRange
exports_by_module_name: (ModuleId, InternedNameId) -> SymbolId
aliases_by_file_name: (FileId, InternedNameId) -> DeclId
use_items_by_file_name: (FileId, InternedNameId) -> ImportBinding
```

函数同名选择在索引构建时预分类：

```text
best_body
best_stub
family_body
family_stub
extern_decl
```

C99 当前的 `find_function_decl_c99` 不应在缓存命中后继续扫全程序。上下文敏感规则必须在索引层表达清楚。

### 5.5 作用域索引

函数进入时一次性构建局部符号表：

```text
FunctionScopeIndex
  params_by_name
  locals_by_block_depth
  captures
  async_bindings
  globals_visible
```

block 进入/退出只更新栈式 generation。`c99_find_identifier_type_node` 和 `lookup_identifier_type_c_impl` 这类倒扫局部变量的逻辑要迁出后端。

### 5.6 类型索引

类型转换和布局必须可缓存：

```text
TypeId -> CanonicalType
TypeId -> LayoutInfo
TypeId -> CName
TypeId -> NativeAbiClass
TypeId -> DropPlan
```

泛型实例的 key：

```text
(template DeclId, TypeArgSignatureId, ConstArgSignatureId)
```

不能用函数名字符串和临时上下文拼接作为主要 key。

---

## 6. TypedProgram 合同

`TypedProgram -> LoweredProgram` 的详细合同见 `docs/coreir_lowered_program_whitepaper.md`；本节保留
checker 输出摘要和后端禁令。

checker 完成后输出：

```text
TypedProgram
  semantic_db: SemanticDb
  expr_types: ExprId -> TypeId
  identifier_bindings: ExprId -> SymbolId
  call_targets: ExprId -> CallTarget
  method_dispatch: ExprId -> MethodDispatch
  field_access: ExprId -> FieldId
  global_init_order: GlobalId[]
  reachable_roots: FunctionId[]
  proof_results: ProofResult[]
```

后端禁止：

- 调用 `checker_infer_type` 做常规类型查询。
- 临时修改 `checker.current_function_decl` 以便生成某段 C/native。
- 重新从 AST 字符串名推断调用目标。
- 在输出过程中新增未登记的语义实体。

如果后端发现必须重新问 checker，说明 `TypedProgram` 合同缺字段，应先补合同。

---

## 7. LoweredProgram 与闭包收敛

详细合同见 `docs/coreir_lowered_program_whitepaper.md`；本节保留闭包收敛摘要。

### 7.1 Worklist

lowering 使用 worklist 一次性收敛：

```text
roots = entry functions + runtime roots
while worklist not empty:
  resolve function body
  instantiate generic functions / methods / structs
  lower async frame when required
  register err_union / slice / tuple / interface / vtable / drop plan
  register runtime helpers
  append newly referenced concrete functions and types
```

闭包稳定后，输出阶段才能开始。

### 7.2 输出结构

```text
LoweredProgram
  functions: ConcreteFunction[]
  globals: GlobalObject[]
  types: ConcreteType[]
  interfaces: InterfacePlan[]
  err_unions: ErrorUnionLayout[]
  async_frames: AsyncFramePlan[]
  helpers: RuntimeHelper[]
  diagnostics: LowerDiagnostic[]
```

`LoweredProgram` 是闭包清单和 Core-level 程序合同，不再承担完整低级函数体 IR。C99 第一阶段仍可直接
消费 `LoweredProgram` 作为 oracle；native、PTX、exec 等需要共享低级 body lowering 的后端必须消费
`PortableMIR`。

完整函数体语义由 `CoreBody` 承载。`CoreBody` 保存已经从 `TypedProgram` 冻结的 resolved call target、
method dispatch、field id、type id、proof result、source span、cleanup path 和 capability metadata。
PortableMIR 实现之前必须先完成 `CoreBody`、CoreIR dump 和 CoreIR verifier；如果 MIR lowering 发现
缺少语义事实，说明 CoreIR 合同不完整，应先补 CoreIR，而不是直接回查 `TypedProgram`。
新增完整函数体语义不得只接入 C99 oracle；新增 CoreStmt/CoreExpr/CorePlace/Cleanup 形状必须先被
CoreBody 稳定 dump 和 CoreIR verifier 白名单接受，之后 C99 才能继续作为独立 oracle 消费冻结事实。

### 7.3 正确性规则

- 泛型实例发现不得发生在 emitter 中。
- err_union / async frame / string constants 不允许在函数体输出后再“补发”。
- vtable、method wrapper、runtime helper 必须有确定的依赖顺序。
- split-C/native unit 的依赖 fingerprint 来自 `LoweredProgram`，不来自 C 文本差异。
- `LoweredBodyOp` 只允许作为过渡兼容层，不再扩展为完整语言 IR。

### 7.4 PortableMIR

详细合同见 `docs/portable_mir_whitepaper.md`；本节只保留架构摘要。

`PortableMIR` 位于 `LoweredProgram + CoreBody` 和 target backend 之间：

```text
LoweredProgram / CoreIR / CoreBody
  -> PortableMIR
  -> Target backend
```

核心结构：

```text
MirModule
  functions: MirFunction[]
  globals: MirGlobal[]
  types: MirType[]

MirFunction
  locals: MirLocal[]
  blocks: MirBlock[]

MirBlock
  insts: MirInst[]
  terminator: MirTerminator
```

职责：

- 显式表达 basic block、value、local、load/store/address、call、return、branch 和 cleanup path。
- 统一 field/index/slice 地址计算、aggregate copy/move/drop、error union、defer/errdefer 和 drop path。
- 保存 target-neutral layout metadata、calling convention 需求、hosted/freestanding runtime capability 和
  address space 预留字段；target profile 还必须显式保存 hosted/freestanding call ABI profile。
- 不保存 x86_64 寄存器、ELF section、PTX 指令、C 文本等 target-specific 细节。
- 通过 verifier 在线性扫描中检查 block 终结、value 使用、类型、地址/布局、cleanup path 和 target
  capability。
- 默认不查询 `TypedProgram`；source/proof/capability 辅助信息必须先由 CoreIR 合同转交。

后端扩展接口只允许从 `PortableMIR` 进入 target IR：

```text
PortableMIR -> MachineModule -> object / executable
PortableMIR -> PtxModule     -> PTX / cubin
PortableMIR -> ExecBytecode  -> VM
PortableMIR -> C99Plan       -> C99 text
```

接口用 `MirTargetBackendRequest` / `MirTargetBackendOutput` 固定输入输出形状。backend request 只能保存已
验证 `PortableMirModule`、target profile ID、backend kind 和 verifier 结果码；不能新增 `TypedProgram`、
`LoweredProgram` 或 `CoreBody` 入口。output kind 固定映射为 `MachineModule`、`PtxModule`、
`ExecBytecode` 或 `C99Plan`。

C99 迁移到 MIR 是后续选项，不是第一阶段强制要求；在 hosted native parity 稳定前，C99 继续作为独立
oracle 更有利于差分定位。

### 7.5 语言语义与 Target Capability

完整 Uya 语言语义只由 parser、checker、TypedProgram 和 CoreIR 定义。Hosted native、freestanding native、
PTX device、microapp 等 target profile 只能裁决能力是否可用，不能引入独立语法、关键字、内建函数或
checker 方言。

例如 `@c_import`、filesystem、pthread、environment、malloc、syscall、`@asm` 和未来 PTX device subset
都必须表达为 target capability requirement。target 不支持时输出明确 diagnostic；不能静默回落 C99，
不能跳过 safety proof，也不能让同一段 Uya 代码在语言语义层面分叉。

capability diagnostic 必须指出 capability 名称、触发源构造和目标 profile。`@c_import` 仍是顶层 build graph
声明；filesystem / environment / pthread / syscall / `@asm` / future PTX device subset 仍共享同一套
parser、checker、TypedProgram 和 CoreIR 语义。target 可以拒绝能力，不能把拒绝实现成 Uya 方言、C99 fallback、
hostcall 偷换、proof 跳过或标准库语义重写。CoreIR capability metadata 只能描述能力需求和 source attachment，
不得混入 type/call/field/proof/cleanup 事实；该规则由 CoreIR verifier 先于 MIR lowering 检查。

`@naked_fn` 也是 capability-gated 函数属性。CoreIR 必须把 naked flag 冻结到 concrete function；
PortableMIR 必须把它降为 asm-only naked body；native backend 不得为它生成普通 prologue/epilogue。
不支持 naked function 的 target 必须明确拒绝。

并行编译只能发生在冻结边界之后，或通过 stable request merge 归并。并行开关不得改变 ID、dump、
diagnostic 顺序、symbol order 或 object layout fingerprint。

CoreLower 的并行合同是：冻结前的 discovery worker 只能产出本地 request buffer，主线程按 stable key
排序、去重并统一分配 ID；冻结后的 per-function CoreBody materialization 只能消费 frozen
`LoweredProgram + TypedProgram + AST` 只读视图，输出本地 CoreBody / diagnostic / dump fragment，再按
stable function order 归并。任何并行开关都不得改变 CoreIR IDs、CoreBody ranges、dump 文本或
diagnostic 顺序。

---

## 8. C99 后端重构

C99 后端拆成三层：

```text
C99Planner
  -> C99UnitPlan
  -> C99Emitter
```

### 8.1 C99Planner

职责：

- 第一阶段将 `LoweredProgram` 映射到 C 类型、C 函数、C 全局和 helper 列表。
- 决定 split-C 单元归属。
- 生成原型、定义和 include 需求。
- 输出稳定的 unit fingerprint。
- 不作为新增完整函数体语义的唯一落点；新增 body 形状先通过 CoreBody dump/verifier 门禁。

### 8.2 C99UnitPlan

单元内容：

```text
C99UnitPlan
  filename
  includes
  type_defs
  prototypes
  globals
  functions
  helper_refs
  deps
  fingerprint
```

### 8.3 C99Emitter

只负责 bytes 输出：

- 不查找 AST 声明。
- 不调用 checker。
- 不新建 mono instance。
- 不改变 `LoweredProgram`。

这样 C99 虽未作为 1 秒硬路径，也能成为稳定 oracle。

当 `PortableMIR` 和 hosted native parity 稳定后，可以新增实验性 `MIR -> C99Plan` 路线；迁移前不能
删除现有 C99 oracle。
第一阶段 C99 oracle 不要求依赖 PortableMIR；`MIR -> C99Plan` 只能在 hosted native parity 稳定后作为
实验路径加入。

---

## 9. 入口与命令拆分

`src/main.uya` 目标态只做 launcher：

```text
bin/uya
  --version / help
  command dispatch
  compatibility diagnostics
```

真实编译器在：

```text
bin/cmd/build
```

其它命令独立：

```text
bin/cmd/check
bin/cmd/run
bin/cmd/test
bin/cmd/fmt
bin/cmd/upm
bin/cmd/microapp
```

Microapp / microcontainer 目标 CLI 统一收敛到：

```text
uya microapp build ...
uya microapp pack ...
uya microapp inspect ...
uya microapp verify ...
uya microapp run ...
```

旧顶层 `pack-image` / `inspect-image` / `verify-image` 只允许作为兼容诊断或薄转发，
不能重新把 microapp image/payload 大逻辑导入 `bin/uya` 或 `cmd/build` seed。

### 9.1 自举约束

不能先删除隐式入口再要求它生成 `cmd/build`。阶段顺序必须是：

1. `src/main.uya` 仍可编译。
2. 抽出 compiler driver。
3. 生成并验证 `cmd/build`。
4. 生成 `cmd/build` seed 或等价源码 bootstrap。
5. `make from-c` / `make from-c-native` 先恢复 `bin/cmd/build`。
6. `bin/uya` 变纯 dispatcher。

---

## 10. Native 自举后端

### 10.1 为什么必须做 native

纯源码 `make uya` 冷构建 1 秒不能依赖：

- 大 C 文件生成后再给 `cc` 编译。
- split-C 后再让 `make -j` 全量编译。
- `.o` / IR / 二进制缓存。
- daemon 常驻状态。

因此最终路径必须让 Uya 自己直接生成目标平台可执行产物。新的长期后端分层是：

```text
LoweredProgram / CoreIR / CoreBody
  -> PortableMIR
  -> MachineModule
  -> object / executable
```

完整语言 parity 第一阶段采用 Linux x86_64 hosted native：Uya 函数体生成机器码，libc、pthread、
filesystem、env、malloc、extern 和 `@c_import` 链接需求交给宿主 ABI / linker 承接。
该承接由 `NativeHostedLinkPlan` 固定：只从 verifier-clean Machine backend request 初始化，要求 hosted
runtime profile 和 hosted SysV call ABI profile，并记录 `libc`、`pthread`、filesystem、env、malloc、extern symbol 和 `@c_import`
object/linker 输入。freestanding profile 必须拒绝该 plan，而不是静默退回 C99。
已迁入 PortableMIR 的 hosted shard 必须真实生成 executable；尚未迁入 MIR 的复杂 no-deps shard 必须明确
报告 lowering gap，不能走 build-seed `LoweredProgram` helper。

freestanding / nostdlib build-seed 目标继续保留，但作为 hosted native 已验证能力的后续下沉路径：

```text
PortableMIR -> MachineModule -> ELF64 executable
PortableMIR -> MachineModule -> relocatable .o -> tiny internal linker -> executable
```

这避免为了追 `cmd/build` 某个新形状继续堆 ad hoc `LoweredBodyOp`，同时仍保留 1 秒冷构建最终所需的
freestanding executable 路线。

### 10.2 v1 范围

native 范围分成两层：

- hosted native 完整语言 parity：第一阶段以 C99 为 oracle；已迁 MIR 的 shard 真实运行一致，未迁 MIR 的复杂
  shard 先保持 explicit reject。当前已迁 MIR shard 包括 `@size_of` / `@align_of` 标量 builtin、
  数组字面量 `@len([1, 2, 3, 4])`、slice 构造/索引 no-deps shard，以及
  `@error_id(error.SmokeError)` compile-time-only builtin shard、常量输入 error union `catch` success/fallback shard，
  `get_argc()` 驱动的动态 error union `catch` fallback/success shard、最小
  `defer { local = const; }` return-value 冻结 shard、最小 lexical drop cleanup shard、
  interface/method dispatch no-deps shard，以及 atomic i32 init/write/read shard。
- freestanding native build-seed：保留 Phase 10 `cmd/build` 子集，后续从已通过 MIR 的能力逐步下沉。

freestanding native build-seed 失败只能阻塞 build-seed 里程碑，不能阻塞 hosted native 完整语言 parity。

`CoreBody` 和 `PortableMIR` 首批必须覆盖完整语言主干：

- 整数、bool、byte、浮点、指针、数组、slice、struct、union、enum、tuple、`atomic T`、
  `@vector(T, N)` 和 `@mask(N)`。
- 函数调用、方法调用、泛型单态化后的 concrete function。
- `if`、`while`、`for range`、`break`、`continue`、`return`。
- `!T`、`try`、`catch`、`defer`、`errdefer` 的 lowered form。
- hosted libc / extern / runtime helper bridge，以及 freestanding syscall bridge 的 capability 标记。
- 必需字符串、全局、静态表、vtable 和 async frame descriptor。

暂不作为 hosted native 完整语言第一阶段硬范围：

- `uya microapp build/pack/inspect/verify/run`。
- Windows / macOS native executable emission。
- SIMD 高级优化。
- debug info。

用户级 `@c_import` 在 hosted native parity 中必须通过宿主 toolchain/linker 路径保持与 C99 行为一致。
不支持的 freestanding 能力必须给明确 capability diagnostic，不能静默 fallback。

### 10.3 Native IR

`NativeEmitter` 不直接消费 parser AST，而消费：

```text
PortableMIR
  -> MachineModule
  -> RegisterAllocation
  -> ObjectLayout
  -> ObjectWriter / ELFWriter
```

当前 native 主合同由 `NativeMirEmitter` 表达：入口接收 `MirTargetBackendRequest`，确认其 backend kind 为
`MIR_TARGET_BACKEND_MACHINE` 且 verifier-clean，然后按 MIR function / block / inst range 导入
`MachineModule`，再交给 object/executable writer。历史 build-seed 子集里的 `LoweredProgram -> MachineModule`
helper 只作为 Phase 10 freestanding 回归边界保留，不能作为 hosted native 完整语言主路径。

v1 可采用简单策略：

- 固定调用约定。
- 保守栈分配。
- 基础线性扫描寄存器分配。
- 必要时 spill。
- 不做全局优化。

目标是构建速度和正确性，不是产物运行速度极限。

---

## 11. Seed 策略

当前 `make uya` 冷启动可能走 `from-c`，再自举一轮。1 秒目标下 seed 需要拆分：

```text
backup/
  seed-launcher.uya.c     # 或当前平台 C seed，最小 launcher
  seed-build-core.uya     # 源码级 build core roots
  seed-build-native.uya   # native emitter roots
```

在纯源码约束下，允许源码 seed，不允许对象或二进制 seed。

目标：

- seed 不包含 exec、microapp、upm、fmt、kernel packaging。
- seed 只恢复 `bin/cmd/build` 和最小 `bin/uya`。
- `make clean && make uya` 不触发大 C 编译器重编完整历史产物。

如果仍必须保留 C seed，那么 C seed 必须是最小 build compiler seed，而不是完整 `src/main.uya` 大入口产物。

---

## 12. 内存模型

### 12.1 需要测量的内存

1 秒目标必须同时报告：

```text
peak_rss_kb          # 进程峰值常驻内存
arena_peak_bytes     # compiler arena 峰值
semantic_db_bytes    # SemanticDb 与索引占用
typed_program_bytes  # TypedProgram 表占用
lowered_bytes        # LoweredProgram / PortableMIR / BuildPlan 占用
c99_output_buffer_peak_bytes # C99 输出 FILE 缓冲峰值
output_bytes         # 生成 C/native/object/executable/build seed 字节数
table_count          # 所有编译器动态表实际项数汇总
table_capacity       # 所有编译器动态表容量项数汇总
table_bytes          # 所有编译器动态表实际占用汇总
table_capacity_bytes # 所有编译器动态表容量占用汇总
table_realloc_count  # 所有编译器动态表增长次数汇总
```

当前环境不应依赖 GNU `/usr/bin/time -v`；benchmark 脚本应优先通过 `/proc/<pid>/status` 或 `/proc/<pid>/smaps_rollup` 采样 RSS。非 Linux 平台再提供平台专用实现。

### 12.2 生命周期原则

- AST、SemanticDb、TypedProgram、LoweredProgram、PortableMIR 不能无界同时常驻；后续阶段一旦不再需要，必须可释放或复用 arena。
- C99 字符串输出不能先构造整份巨型内存字符串再一次写出；planner 输出 unit，emitter 流式写文件。
- `SemanticDb` 索引必须是压缩数组/range 结构，避免为每个名字单独分配链表节点。
- `TypeId`、`SymbolId`、`DeclId` 等表用紧凑整数索引，不在热点表里重复存储 `&byte` 名字。
- 动态表必须按实际项数增长，不能在初始化时预分配“足够大”的全局表；释放点要跟 arena 生命周期一起记录。
- 表容量增长后必须保持 ID 稳定，禁止通过移动 AST 节点地址作为长期身份。
- diagnostic 字符串默认延迟格式化，只在报错或显式 dump 时生成。
- debug dump、HIR dump、bytecode dump、semantic dump 默认关闭，不能影响 KPI。

### 12.3 内存优化方向

| 区域 | 当前风险 | 目标形态 |
| --- | --- | --- |
| AST | 扁平 program + 多阶段重复引用 | AST 只保留语法树，语义结果放紧凑表 |
| lookup cache | 多个直接映射缓存重复存名字 | 统一 intern id + range 索引 |
| TypedProgram | 可能复制 AST/type 信息 | 只存 `ExprId -> TypeId` 等整数映射 |
| LoweredProgram / PortableMIR | 可能同时保留所有临时 IR | 按函数/单元释放临时 lowering arena |
| C99 输出 | 大体量文本和 split 文件 | 单元化、流式写、稳定 fingerprint |
| Native 输出 | 机器码/reloc/debug 表膨胀 | v1 不生成 debug info，reloc 表最小化 |

### 12.4 内存验收

每个性能报告必须包含：

- Phase 0 baseline 的 `peak_rss_kb`。
- 当前阶段 `peak_rss_kb`。
- 与 baseline 的百分比变化。
- arena 峰值。
- 输出产物总字节数。
- 所有编译器动态表的 count/capacity/realloc/bytes 摘要或按表明细。
- 是否打开 dump/debug/cache/daemon。

如果 wall time 达标但 peak RSS 或 arena 峰值显著上升，该阶段不能标记完成。

### 12.5 已落地的子系统独立 arena（Phase 5A L388/L389）

`src/main.uya` 的 `compile_files` 已把原先共用单一 64MB 静态 `arena` 的子系统拆为独立 arena，
每个 arena 的创建点、最后使用点、释放点如下（均为纯动态 arena：静态 buffer 为 null，按需 malloc 1MB chunk）：

| arena | 承载内容 | create | last-use | free |
| --- | --- | --- | --- | --- |
| `arena` | driver 杂项：c_import plan、sidecar、module_root 拷贝 | `compile_files` 入口 `compiler_arena_init` | codegen 收尾 sidecar 写出 | `compile_files_maybe_release_transient_arenas`（依赖 artifacts 时延后） |
| `lex_arena` | 每文件 `Lexer` 结构 | `compile_files` 入口 | 各文件 `lexer_init` | `compile_files` 末尾 `compiler_arena_free_all` |
| `ast_arena` | lexer token 文本 + parser AST + merge/flatten | `compile_files` 入口 | C99 codegen 读取 AST | `compile_files` 末尾 |
| `check_arena` | `TypeChecker` 结构与检查期工作内存 | `compile_files` 入口 | codegen 读取 reachable/mono | `compile_files` 末尾 |
| `emit_arena` | `C99CodeGenerator` 结构与输出缓冲 | C99 阶段 alloc | `c99_codegen_generate` | `compile_files` 末尾 |

`SemanticDb` / `TypedProgram` / `LoweredProgram` / `PortableMIR` 不走编译器 arena，而是各自使用 malloc/realloc 后端的动态表
（`SemanticVector` / `SemanticHash` 或等价动态表），由各自 release/free 接口独立释放，
因此它们天然与上述 arena 生命周期解耦。

各 arena 峰值通过 `ast_arena_peak_bytes` / `check_arena_peak_bytes` / `emit_arena_peak_bytes`
打印到编译统计（stderr），`arena_peak_bytes` 为五个 arena 峰值之和，保持与 Phase 0 baseline 的口径连续。
旧全量 C99 入口实测（96 文件）：`ast_arena≈1.2GB`、`check_arena≈77MB`、`emit_arena≈9.9MB`、driver `arena≈40B`，
说明 AST 仍是该口径的常驻大头。Phase 7 把 `make uya` 主入口瘦为 20 文件 launcher 后，
硬 KPI 口径的 peak RSS 已低于 Phase 0 baseline 25% 阈值；全量 C99 输入的 AST 常驻问题仍留作后续结构性优化。

---

## 13. Benchmark 与验收

### 13.1 固定口径

新增或扩展：

```bash
make bench-compile-stats
make bench-compiler-1s
make bench-compiler-1s-check
```

`bench-compiler-1s` 输出：

```text
run	mode	seed_ms	parse_ms	bind_ms	check_ms	lower_ms	emit_ms	link_ms	total_ms	peak_rss_kb	arena_peak_bytes	output_bytes	c99_output_buffer_peak_bytes
1	native	...
```

### 13.2 冷构建门禁

测试脚本必须：

- 记录 commit、CPU、OS、compiler config。
- 清理 `bin/`、`src/build/`、`src/.uyacache/`。
- 禁用 daemon。
- 禁用对象/IR cache。
- 采样 peak RSS。
- 记录 compiler 内部 arena 峰值。
- 记录输出产物字节数。
- 三次运行取中位数。
- 报告时间和内存是否同时进入 KPI。

### 13.3 正确性验收

每个阶段都要跑：

```bash
git diff --check
make bench-compile-stats-check
make tests-uya
```

涉及 native 或 seed 时追加：

```bash
make check
make check-hosted
make microapp-check
make backup-all
```

native 与 C99 对照：

- native-built compiler 跑测试。
- C99-built compiler 跑同样测试。
- 比较关键输出、退出码、错误诊断。
- 对编译器二次自举产物做 normalized section hash。

语言兼容验收：

- C99 backend 与 hosted native backend 必须支持完整 Uya 语言，不能只以 `cmd/build` 子集或 launcher 子集作为
  release 成功依据。
- 完整语言基线以 main 分支的语言规范文档和回归测试为准，包括语法、类型系统、内建函数、标准库入口、
  多文件模块、泛型、接口、error union、defer/errdefer、async、`atomic T`、`@vector(T, N)`、
  `@mask(N)`、`@c_import` 和 diagnostics 行为。
- Microapp / microcontainer 必须在语言层面兼容 main 分支，不允许引入独立语法、关键字、内建函数或 checker
  方言；它只能在 runtime/capability/profile/host API 层面施加限制。
- Microapp 对不支持能力的拒绝必须是明确 diagnostic，不能通过改变语言语义、跳过安全证明或静默降级实现。

---

## 13. 风险

| 风险 | 说明 | 缓解 |
| --- | --- | --- |
| 语义数据库引入错误 | 旧代码依赖 AST 扫描顺序 | 先为 lookup 建对照测试，再逐类替换 |
| C99 后端与 native 后端漂移 | 双后端容易语义不一致 | native 统一消费 `PortableMIR`，C99 做 oracle |
| native ABI 错误 | hosted/freestanding、调用约定、栈对齐出错 | hosted parity 先用系统 ABI 对齐，freestanding 下沉时做 ABI smoke |
| seed 死锁 | dispatcher 无法生成 build compiler | 阶段内保留旧入口和 C99 fallback |
| KPI 误报 | 热缓存或 daemon 混入冷测 | benchmark 脚本主动清理并报告状态 |
| 内存换时间 | 大表预分配让 wall time 下降但 RSS 上升 | peak RSS / arena 同时门禁 |
| IR 常驻膨胀 | AST、TypedProgram、LoweredProgram、PortableMIR 同时保留 | 分 arena 生命周期，按阶段释放 |
| 过早删除 C99 能力 | 失去跨平台与审计兜底 | C99 只降级为 fallback，不删除 |

---

## 14. 阶段路线

### Phase 0: Benchmark 固化

- 当前 `bench_compile_stats` 修正已作为起点。
- 增加 1 秒专用 benchmark。
- 固定所有 profile、RSS、arena 和临时产物清理规则。

### Phase 1: SemanticDb

- 建 intern 表。
- 建 declaration / scope / module / export 索引。
- 将 checker 热点 lookup 迁入 `SemanticDb`。
- 保持 C99 输出不变。

### Phase 2: TypedProgram

- checker 输出类型和绑定表。
- 后端读表，不再常规重进 checker。
- 增加后端禁止 checker 查询的统计/断言。

### Phase 3: LoweredProgram

- 泛型、err_union、async frame、drop/defer 闭包先收敛。
- C99 planner 只消费闭包结果。
- `UYA_PROFILE_CODEGEN` 下 `body_ms < 4000ms`。
- peak RSS 相比 Phase 0 下降至少 25%。

### Phase 3A: CoreIR / CoreBody

- 定义 `CoreBody`、`CoreStmt`、`CoreExpr`、`CorePlace` 和 cleanup edge。
- 从 `TypedProgram` 冻结 resolved call target、field id、type id、proof result、source span 和
  capability metadata。
- 冻结 `@naked_fn` 函数属性，并在 CoreIR verifier 中拒绝非 asm-only naked body。
- 若引入并行 CoreLower，只允许 worker 产生局部 request buffer，再按 stable key 串行归并；冻结后的
  per-function CoreBody materialization 也必须按 stable function order 归并，且不改变 ID、dump 或
  diagnostics 顺序。
- 新增 CoreIR dump / verifier / closure contract 门禁。
- MIR lowering 不得把 `TypedProgram` 当成语义查询旁路。

### Phase 3B: PortableMIR

- 定义完整函数体低级 IR：module、function、block、value、type、local、inst、terminator。
- 从 frozen `LoweredProgram + CoreBody` lowering 到 MIR，不继续扩展 ad hoc `LoweredBodyOp`。
- MIR verifier 覆盖类型、block、value、address/layout、cleanup path 和 target capability。
- `@naked_fn` 降为 `MirFunction.flags.naked` + asm-only body，不走普通栈帧、cleanup 或 prologue/epilogue。
- 支持 per-function 并行 MIR 构造时，按 stable function order 归并 diagnostics、dump 和 backend fragments。
- native backend 改为 `PortableMIR -> MachineModule`。
- hosted native 与 C99 建立完整语言 smoke 差分：已迁 MIR 的 shard 比对运行结果，未迁 MIR 的 shard
  固定明确拒绝语义。

### Phase 4: 内存生命周期收口

- 分离 AST、SemanticDb、TypedProgram、LoweredProgram、PortableMIR arena。
- 后端输出后释放不再需要的临时 arena。
- 输出缓冲改为单元化流式写。
- 建立内存回归测试。

### Phase 5: 入口与 seed 瘦身

- `bin/uya` 变 dispatcher。
- `cmd/build` 变真实编译器。
- seed 只覆盖 build core。
- launcher 冷构建进入 1 秒。
- launcher 常驻内存只保留调度所需集合。

### Phase 6: Native v1

- Linux x86_64 ELF64 emitter。
- hosted native 先支持完整语言 parity。
- freestanding build compiler 子集从已通过 MIR 的能力逐步下沉。
- `cmd/build` native 自举通过核心测试后再计入 build-seed 完成。
- peak RSS 相比 Phase 0 下降至少 50%。

### Phase 7: `make uya` 1 秒收口

- `make uya` 默认走 native build path，hosted native 与 freestanding build-seed 结论分别记录。
- C99 fallback 保留为 `make uya-c99`。
- 冷构建时间和内存 benchmark 同时达标。
- `make backup-all` 和 release 流程纳入 native 对照。

---

## 15. 成功标准

1. `make clean && make uya` 冷构建三次中位数 `< 1.0s`。
2. 默认安全证明路径保留。
3. C99 backend 支持完整 Uya 语言，并与 main 分支语言行为兼容。
4. Hosted native backend 经由 `PortableMIR` 支持完整 Uya 语言，并与 C99 / main 分支语言行为兼容。
5. Microapp / microcontainer 语言层面兼容 main 分支；仅允许 runtime/capability/profile 限制。
6. native-built compiler 通过 `make check`。
7. C99 fallback 仍可构建并通过差分验证。
8. `bin/uya`、`bin/cmd/build`、backup seed 之间不存在自举死锁。
9. benchmark 脚本能稳定证明当前是冷构建，不混入缓存或 daemon。
10. `peak_rss_kb`、arena 峰值和输出字节数都有基线、趋势和门禁；不能用内存换时间。
