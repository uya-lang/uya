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
- 当前第一平台固定为 Linux x86_64 nostdlib；其它平台后续扩展。
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
  -> BuildPlan
  -> NativeEmitter 或 C99Emitter
```

其中：

- `SemanticDb` 是全程序符号、模块、作用域、类型和导入导出的稳定数据库。
- `TypedProgram` 是 checker 对外合同，后端不得再重新推断类型。
- `CoreLower` 负责收敛泛型、async、err_union、drop/defer、runtime helper 闭包。
- `BuildPlan` 描述要生成哪些二进制、命令、seed、链接单元和验证产物。
- `NativeEmitter` 是 `make uya` 1 秒目标的主路径。
- `C99Emitter` 只消费已完成的 plan，不再边打印边解析语义。

---

## 5. 语义数据库

### 5.1 动态表原则

所有编译器表都必须采用动态增长结构，程序规模相关表没有固定容量例外：

- `SemanticDb`、`TypedProgram`、`LoweredProgram`、`C99Plan`、`NativePlan`、intern 表、scope 表、worklist、reloc/symbol table 都不得使用 `C99_MAX_*`、`CHECKER_*_SIZE`、固定数组长度或魔法容量作为语义上限。
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
| `src/codegen/c99/` 固定 codegen 表 | C99 oracle / fallback | C99 是差分 oracle 与跨平台 fallback，不是 1 秒主路径；固定 registry/cache/worklist 不能作为成功容量 | C99Plan/C99Emitter 改为动态 plan/table 后仅作为 oracle 消费 LoweredProgram |
| `src/checker/` 固定 checker 表 | legacy checker oracle until SemanticDb | checker hash/cache/proof/worklist 仍由固定容量承载，只能作为 SemanticDb 迁移前的对照实现 | SemanticDb/TypedProgram 动态索引接管 lookup、mono、proof 和 reachability |
| `src/exec/` 固定 VM 表 | staged exec fallback | exec VM 仍是 staged backend，locals/bytecode/frame/cleanup/call args 固定表不能定义自举容量 | LoweredProgram + bytecode/frame dynamic vector 或 native path 替换固定 staging 表 |

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

C99 和 native 都读取同一份 `LoweredProgram`。差异只在 ABI、名字、指令和文件格式。

### 7.3 正确性规则

- 泛型实例发现不得发生在 emitter 中。
- err_union / async frame / string constants 不允许在函数体输出后再“补发”。
- vtable、method wrapper、runtime helper 必须有确定的依赖顺序。
- split-C/native unit 的依赖 fingerprint 来自 `LoweredProgram`，不来自 C 文本差异。

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

- 将 `LoweredProgram` 映射到 C 类型、C 函数、C 全局和 helper 列表。
- 决定 split-C 单元归属。
- 生成原型、定义和 include 需求。
- 输出稳定的 unit fingerprint。

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
bin/cmd/pack-image
```

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

因此最终路径必须让 Uya 自己直接生成目标平台可执行产物，至少在 Linux x86_64 主线做到：

```text
LoweredProgram -> ELF64 x86_64 executable
```

或：

```text
LoweredProgram -> relocatable .o -> tiny internal linker -> executable
```

v1 推荐先生成 ELF64 executable，减少外部链接成本。

### 10.2 v1 范围

支持 `bin/cmd/build` 所需语言子集：

- 整数、bool、byte、指针、数组、slice、struct、union、enum、tuple。
- 函数调用、方法调用、泛型单态化后的 concrete function。
- `if`、`while`、`for range`、`break`、`continue`、`return`。
- `!T`、`try`、`catch`、`defer`、`errdefer` 的 lowered form。
- libc/syscall 最小 nostdlib bridge。
- 必需字符串、全局、静态表、vtable 和 async frame descriptor。

暂不作为 v1 native 硬范围：

- 用户级 `@c_import`。
- microapp image packing。
- Windows / macOS native executable emission。
- SIMD 高级优化。
- debug info。

这些能力可继续走 C99 fallback。

### 10.3 Native IR

`NativeEmitter` 不直接消费 parser AST，而消费：

```text
LoweredProgram
  -> MachineFunction
  -> RegisterAllocation
  -> ObjectLayout
  -> ELFWriter
```

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
lowered_bytes        # LoweredProgram / BuildPlan 占用
emit_buffer_bytes    # C99/native 输出缓冲峰值
output_bytes         # 生成 C/native/object/executable 字节数
table_count          # 所有编译器动态表实际项数汇总
table_capacity       # 所有编译器动态表容量项数汇总
table_bytes          # 所有编译器动态表实际占用汇总
table_capacity_bytes # 所有编译器动态表容量占用汇总
table_realloc_count  # 所有编译器动态表增长次数汇总
```

当前环境不应依赖 GNU `/usr/bin/time -v`；benchmark 脚本应优先通过 `/proc/<pid>/status` 或 `/proc/<pid>/smaps_rollup` 采样 RSS。非 Linux 平台再提供平台专用实现。

### 12.2 生命周期原则

- AST、SemanticDb、TypedProgram、LoweredProgram 不能无界同时常驻；后续阶段一旦不再需要，必须可释放或复用 arena。
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
| LoweredProgram | 可能同时保留所有临时 IR | 按函数/单元释放临时 lowering arena |
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

`SemanticDb` / `TypedProgram` / `LoweredProgram` 不走编译器 arena，而是各自使用 malloc/realloc 后端的动态表
（`SemanticVector` / `SemanticHash`），由 `typed_program_release` / `semantic_*_free` 独立释放，
因此它们天然与上述 arena 生命周期解耦。

各 arena 峰值通过 `ast_arena_peak_bytes` / `check_arena_peak_bytes` / `emit_arena_peak_bytes`
打印到编译统计（stderr），`arena_peak_bytes` 为五个 arena 峰值之和，保持与 Phase 0 baseline 的口径连续。
当前实测（直接 C99，96 文件）：`ast_arena≈1.2GB`、`check_arena≈77MB`、`emit_arena≈9.9MB`、driver `arena≈40B`，
说明 AST 仍是常驻大头，是后续 L382（peak RSS 下降 25%）按阶段释放 AST 的主要目标。

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
run	mode	seed_ms	parse_ms	bind_ms	check_ms	lower_ms	emit_ms	link_ms	total_ms	peak_rss_kb	arena_peak_bytes	output_bytes
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

---

## 13. 风险

| 风险 | 说明 | 缓解 |
| --- | --- | --- |
| 语义数据库引入错误 | 旧代码依赖 AST 扫描顺序 | 先为 lookup 建对照测试，再逐类替换 |
| C99 后端与 native 后端漂移 | 双后端容易语义不一致 | 统一 `LoweredProgram`，C99 做 oracle |
| native ABI 错误 | nostdlib、调用约定、栈对齐出错 | 先覆盖 compiler build 子集，做 ABI smoke |
| seed 死锁 | dispatcher 无法生成 build compiler | 阶段内保留旧入口和 C99 fallback |
| KPI 误报 | 热缓存或 daemon 混入冷测 | benchmark 脚本主动清理并报告状态 |
| 内存换时间 | 大表预分配让 wall time 下降但 RSS 上升 | peak RSS / arena 同时门禁 |
| IR 常驻膨胀 | AST、TypedProgram、LoweredProgram 同时保留 | 分 arena 生命周期，按阶段释放 |
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

### Phase 4: 内存生命周期收口

- 分离 AST、SemanticDb、TypedProgram、LoweredProgram arena。
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
- 支持 build compiler 子集。
- `cmd/build` native 自举通过核心测试。
- peak RSS 相比 Phase 0 下降至少 50%。

### Phase 7: `make uya` 1 秒收口

- `make uya` 默认走 native build path。
- C99 fallback 保留为 `make uya-c99`。
- 冷构建时间和内存 benchmark 同时达标。
- `make backup-all` 和 release 流程纳入 native 对照。

---

## 15. 成功标准

1. `make clean && make uya` 冷构建三次中位数 `< 1.0s`。
2. 默认安全证明路径保留。
3. native-built compiler 通过 `make check`。
4. C99 fallback 仍可构建并通过差分验证。
5. `bin/uya`、`bin/cmd/build`、backup seed 之间不存在自举死锁。
6. benchmark 脚本能稳定证明当前是冷构建，不混入缓存或 daemon。
7. `peak_rss_kb`、arena 峰值和输出字节数都有基线、趋势和门禁；不能用内存换时间。
