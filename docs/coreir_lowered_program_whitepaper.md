# TypedProgram 到 LoweredProgram / CoreIR 白皮书

**状态**: 设计白皮书，待实现
**更新日期**: 2026-06-07
**相关文档**: `docs/todo_compiler_1s.md`、`docs/compiler_1s_architecture_design.md`、
`docs/portable_mir_whitepaper.md`

## 1. 目的

本文定义 `TypedProgram -> LoweredProgram / CoreIR` 的工程合同。

目标流水线是：

```text
AST
  -> SemanticDb
  -> TypedProgram
  -> LoweredProgram / CoreIR
  -> PortableMIR
  -> Target backend
```

`TypedProgram` 是 checker 的输出合同，保存已经解析好的类型、绑定、调用目标、字段访问、proof 等事实。
`LoweredProgram / CoreIR` 是全程序语义闭包层，负责把这些事实收敛成确定的 concrete program inventory：
concrete functions、concrete types、globals、interface/vtable plans、error-union layouts、async frame plans、
drop/defer plans、runtime helper requirements 和规范化的 CoreBody。

`PortableMIR` 只消费冻结后的 CoreIR，把 CoreBody 降成低级 CFG/value/memory IR。target backend 只消费
验证后的 PortableMIR。

一句话：**CoreIR 关闭 Uya 语言语义，PortableMIR 关闭低级控制流和内存形态。**

## 2. 为什么需要这一层

如果没有清晰的 CoreIR 合同，每个后端都会被迫重新判断语言语义：

- 哪些泛型函数、泛型方法、泛型类型需要实例化。
- 哪些 concrete type 和 layout 必须存在。
- 哪些 interface wrapper、vtable entry、method thunk 需要生成。
- 哪个 error-union layout 对应哪个返回值或字段。
- 哪个 async frame layout 对应哪个 future。
- 哪些值需要 drop。
- 哪些路径要运行 `defer` / `errdefer`。
- 哪些 runtime helper 必须存在。
- 哪些语言构造需要 hosted / freestanding / device capability。

这些决策必须在 target lowering 之前完成。否则 C99、native、PTX、exec 会各自发明一套 lowering，语义漂移会变成常态。

## 3. 目标和非目标

目标：

- 在 target emission 前完成全程序语义闭包。
- 阻止 emitter、MIR lowering 和 backend 重新进入 checker 推断。
- 用结构化 `CoreBody` 取代继续扩张的 ad hoc `LoweredBodyOp`。
- 保存 PortableMIR 所需的类型、source span、proof、cleanup 和 capability 信息。
- 保持所有表动态增长并纳入 1 秒编译器内存统计。
- 保留 C99 作为第一阶段 native/MIR 迁移的独立 oracle。

非目标：

- CoreIR 不是寄存器级 IR，也不是 basic-block 级 IR。
- CoreIR 不决定目标寄存器、栈槽、ELF section、PTX 参数语法等 target ABI 细节。
- CoreIR 不替代 `TypedProgram`，它消费 `TypedProgram`。
- CoreIR 不替代 `PortableMIR`，它喂给 `PortableMIR`。
- CoreIR v1 不要求实现目标无关优化。

## 4. 分层边界

### 4.1 SemanticDb

`SemanticDb` 拥有名称、声明、模块、scope、import/export 和稳定 symbol ID。CoreLower 可以查询已经建立的索引，
但不能退回到全程序字符串扫描。凡是应该由 `DeclId`、`SymbolId`、`TypeId` 或 module range 表达的身份，都不能靠临时字符串比较决定。

### 4.2 TypedProgram

`TypedProgram` 拥有 checker 输出：

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

CoreLower 可以遍历 AST 结构，但语义答案必须来自 `TypedProgram` 和 `SemanticDb`。

CoreLower 禁止：

- 调用 `checker_infer_type` 做常规 lowering 决策。
- 临时修改 checker 上下文来逼出答案。
- 用原始函数字符串名重新解析调用目标。
- 在 target emission 阶段发现新语义实体。
- `TypedProgram` 缺字段时静默退回 `unknown`。

如果 CoreLower 需要的事实不在 `TypedProgram` 或 `SemanticDb` 中，正确修复是先补合同，再继续 lowering。

### 4.3 LoweredProgram / CoreIR

`LoweredProgram` 拥有冻结后的 concrete program 清单：

- concrete functions
- concrete types
- 全局对象
- interface / vtable 计划
- error-union layout
- async frame 计划
- drop / defer 计划
- runtime helper 需求
- 规范化 CoreBody 记录
- diagnostics
- worklist 状态，直到闭包完成

闭包完成后的 `LoweredProgram` 对 emitter、PortableMIR 和 target backend 只读。

LoweredProgram 责任边界：

- `functions`：冻结 concrete function inventory，包括 source decl、mono instance、body range 和函数级 flags。
- `globals`：冻结全局对象清单、source symbol 和初始化入口，不承载低级 store/load CFG。
- `types`：冻结 concrete type / layout identity；PortableMIR 可消费 layout 结果，但不能在这里发现新类型。
- `interfaces`：冻结 interface / vtable 计划和 dispatch 所需 stable slot，不让 backend 搜索实现。
- `err_unions`：冻结 error-union tag/payload layout，PortableMIR 只降低 tag check 和控制流。
- `async_frames`：冻结 async frame layout 和 state identity，PortableMIR 只降低 frame memory 操作。
- `drop_defer_plans`：冻结 drop/defer/errdefer obligation，PortableMIR 只生成 cleanup control flow。
- `helpers`：冻结 runtime helper requirement，backend 只能消费或按 capability 拒绝。
- `worklist`：冻结前用于 closure discovery；冻结后按 stable order 只读，emitter / MIR lowering / backend 不得追加。

stable symbol order 由 `lowered_program_sort_stable` 统一归并：functions、globals、types、interfaces、
err_unions、async_frames、drop_defer_plans、helpers、worklist 和 CoreBody 相关表都按稳定整数 ID / key 排序。
PortableMIR 和 target backend 必须消费这个顺序，不能通过 hash iteration、backend-local discovery 或 target 输出顺序重新定义 identity。

`LoweredProgram` 不拥有低级 CFG/value/local/inst/terminator。完整函数体低级形态属于 `PortableMIR`。`LoweredBodyOp`
只保留为 native bootstrap 的 transition / legacy-only 兼容输入，不能继续扩成完整语言 IR。

### 4.4 PortableMIR

PortableMIR 拥有低级函数体形态：

- basic blocks
- values
- locals
- 地址计算
- load / store / copy / move / drop
- calls
- branches
- cleanup 控制流
- target capability 验证

PortableMIR 不允许发现新的泛型实例、类型布局、async frame、error-union layout 或 runtime helper。这些都属于 CoreIR。

## 5. 核心数据模型

所有 CoreIR 表必须是动态 vector、动态 hash 或动态 range table。程序规模不能受固定容量限制。

```text
LoweredProgram
  functions: ConcreteFunction[]
  core_bodies: CoreBody[]
  globals: GlobalObject[]
  types: ConcreteType[]
  interfaces: InterfacePlan[]
  err_unions: ErrorUnionLayout[]
  async_frames: AsyncFramePlan[]
  drop_defer_plans: DropDeferPlan[]
  helpers: RuntimeHelper[]
  strings: CoreString[]
  constants: CoreConst[]
  diagnostics: LowerDiagnostic[]
  worklist: LowerWorkItem[]
  stats: LoweredProgramStats
```

当前 `LoweredBodyOp` 只是过渡数据。长期替代物是 `CoreBody`。

## 6. ID 模型

CoreIR 使用稳定整数 ID：

- `ConcreteFunctionId`
- `CoreBodyId`
- `ConcreteTypeId`
- `GlobalObjectId`
- `InterfacePlanId`
- `ErrorUnionLayoutId`
- `AsyncFramePlanId`
- `DropDeferPlanId`
- `RuntimeHelperId`
- `CoreStringId`
- `CoreConstId`
- `CoreStmtId`
- `CoreExprId`

Core ID 在一个 `LoweredProgram` 生命周期内稳定。它们可以引用上游 ID：

- `DeclId`
- `FunctionId`
- `TypeId`
- `SymbolId`
- `ExprId`
- `FieldId`
- `GlobalId`
- `MonoInstanceId`

上游 ID 是语义身份来源；Core ID 是 lowered concrete inventory 的身份。

## 7. Worklist 闭包

CoreLower 从 `TypedProgram.reachable_roots` 和当前 build mode 所需 runtime roots 开始。

闭包循环：

```text
initialize worklist from reachable roots
while worklist not empty:
  pop item
  materialize concrete function/type/global/helper
  scan normalized body for referenced functions/types/helpers
  instantiate generic functions and methods
  instantiate generic structs/unions/interfaces
  register error-union layouts
  register async frame plans
  register drop/defer plans
  register interface/vtable plans
  register runtime helpers
  append new work items
sort output tables into stable order
freeze LoweredProgram
```

emitter 不允许追加 worklist。backend 发现冻结后的 `LoweredProgram` 缺实体，就说明 CoreLower 不完整。

## 8. ConcreteFunction

`ConcreteFunction` 表示泛型、方法、wrapper、helper 等绑定后的一个可调用实现。

必需字段：

- 源函数或方法 `DeclId`
- 可选 `MonoInstanceId`
- 方法所属 receiver concrete type
- concrete type arguments
- concrete parameter types
- concrete return type
- 调用约定需求：Uya、C、syscall、runtime helper 等
- 函数属性：async、extern、naked、export、varargs、test、runtime helper、entry
- body kind：source body、extern declaration、runtime helper、generated wrapper、generated drop、generated async poll
- 有函数体时的 `CoreBodyId`
- stable symbol name
- required capabilities
- source span

函数身份不是显示名字。身份 key 是结构化的：

```text
(template DeclId, receiver type, type args, const args, calling convention, body kind)
```

symbol name 在身份稳定后派生。

### 8.1 `@naked_fn`

`@naked_fn` 是函数属性，不是新的调用语法。CoreIR 必须把它冻结到 `ConcreteFunction` flags 和
capability requirement 中，供 PortableMIR 和 target backend 做专门 lowering。

CoreIR 层规则：

- `@naked_fn` 不能和 `extern` 函数体混用；parser 已经拒绝该组合，CoreIR verifier 仍要防御性检查。
- naked 函数必须声明明确 calling convention 和 target capability，例如 native ABI、inline asm。
- naked 函数体只能包含 `@asm` 或未来明确标记为 naked-compatible 的构造。
- naked 函数不得包含 `defer`、`errdefer`、隐式 drop、async await、error propagation、普通局部变量栈槽、
  隐式返回补全或 runtime helper 自动插入。
- 参数和返回值只能通过目标 ABI 约定或 `@asm` operand 明确处理；CoreIR 不生成参数搬运或返回值修补。

如果用户在 naked 函数中使用普通 Uya 语句，CoreIR verifier 必须给稳定 diagnostic，而不是让 native
backend 在 prologue/epilogue 阶段失败。

## 9. CoreBody

`CoreBody` 是结构化、typed、target-neutral 的函数体合同。它比 AST 更低级，比 PortableMIR 更高级。

它保留：

- 源 statement / expression 身份
- 每个表达式的 `TypeId`
- 已解析 call / method / field target
- concrete generic substitution
- scope 嵌套
- cleanup scope 边界
- 需要 drop 的值
- error propagation 位置
- async await 位置
- capability requirement

它规范化：

- method call -> concrete call 或 interface dispatch record
- field access -> `FieldId`
- generic call -> concrete function ID
- type expression -> concrete type ID
- `try` / `catch` / `defer` / `errdefer` / drop obligation -> 显式 Core 构造
- compile-time-only builtin -> 常量或 type/layout record

它不负责：

- 源控制流 -> basic blocks
- expression tree -> three-address temporaries
- locals -> machine stack slots
- aggregate access -> 目标字节偏移
- target ABI -> register/stack 分类

这些由 PortableMIR 和 target backend 处理。

## 10. CoreStmt

初始 Core statement kind：

- block
- variable declaration
- assignment
- expression statement
- if
- while
- for range
- break
- continue
- return
- try propagate
- catch binding
- defer
- errdefer
- scope enter / scope exit marker
- asm block
- unreachable marker

每条 statement 记录 source span，以及它打开或关闭的 cleanup scope。控制流 statement 必须记录边上活跃的 cleanup scope。

## 11. CoreExpr

初始 Core expression kind：

- constant
- integer literal
- local reference
- parameter reference
- global reference
- field access
- index access
- slice expression
- unary operation
- binary operation
- cast
- call
- method call
- interface dispatch
- struct literal
- tuple literal
- array literal
- enum literal
- union literal
- error value
- error-union ok
- error-union err
- builtin
- async await
- address-of
- dereference

每个 Core expression 都有：

- 适用时的源 AST `ExprId`
- `TypeId`
- literal expression 的规范化值字段，例如 `CORE_EXPR_KIND_INT_LITERAL.literal_i64`
- source span
- call / method / interface dispatch 的 resolved target、`MonoInstanceId` 和 typed argument count
- 可选 proof result ID
- 可选 capability requirement

Core expression 可以保持树形。PortableMIR 再把它拆成 values 和 memory operations。

## 12. 类型闭包

`ConcreteType` 表示下游 planner 必须知道的类型。

必须收敛：

- primitive aliases used by generated ABI
- pointers and slices
- arrays
- structs
- unions
- enums
- tuples
- atomic types
- SIMD vector types
- SIMD mask types
- function types
- interface object shapes
- error-union layouts
- async frame types
- opaque extern types

每个 concrete type 记录：

- canonical `TypeId`
- kind
- size / alignment，若已知
- layout ID 或 inline layout metadata
- aggregate field offsets
- enum / union / error-union tag 和 payload layout
- atomic value type、默认 memory order 和 lock-free / helper requirement
- vector element type、lane count、lane layout 和 scalar fallback requirement
- mask lane count、mask representation 和 vector comparison result mapping
- drop requirement
- target-neutral ABI class hint，若能提前判断
- required runtime helpers

CoreLower 可以查询既有 type/layout 服务，但必须把 PortableMIR 和 backend 需要的结果存入 CoreIR。

## 13. 泛型闭包

泛型闭包必须在 PortableMIR 前完成。

generic function key：

```text
(template FunctionId, type arg signature, const arg signature)
```

generic method key：

```text
(template MethodId, receiver concrete type, type arg signature, const arg signature)
```

generic type key：

```text
(template TypeDeclId, type arg signature, const arg signature)
```

规则：

- 同一 key 映射到唯一 concrete ID。
- key 使用 canonical IDs/signatures，不使用字符串。
- 递归发现通过 worklist 收敛。
- emitter 和 MIR lowering 只能读取 concrete instances，不能创建。
- 闭包失败的 diagnostic 必须能指出 instantiation chain。

## 14. Interface 和 VTable

CoreIR 拥有 interface planning：

- implemented interface declarations
- method signature matching results
- concrete method implementations
- vtable layout
- interface object layout
- receiver adaptation wrapper
- interface composition
- generic interface instantiation

`InterfacePlan` 包含：

- interface type ID
- implementer concrete type ID
- method entry list
- vtable symbol
- wrapper concrete function IDs
- required runtime helpers

PortableMIR 可以降低 interface call，但不能搜索实现。

## 15. Error Union

CoreIR 拥有 error-union layout 注册和传播语义。

`ErrorUnionLayout` 包含：

- payload type
- error tag type
- result storage layout
- tag offset
- payload offset
- ok constructor helper，若需要
- err constructor helper，若需要
- payload access helper，若需要
- error access helper，若需要

CoreBody 标记：

- `try` propagation sites
- `catch` binding sites
- ok / err 显式构造
- 返回 error-union 的路径

PortableMIR 把这些记录降低成 tag check、branch、load/store 和 cleanup edge。

## 16. Defer、Errdefer 和 Drop

CoreIR 拥有 cleanup obligation。PortableMIR 拥有 cleanup control flow。

`DropDeferPlan` 包含：

- scope ID
- 需要 drop 的值
- custom drop concrete function IDs
- recursive aggregate drop requirements
- `defer` action body references
- `errdefer` action body references
- ordering requirements
- source spans

CoreBody 标记 scope enter/exit 和活跃 cleanup set。PortableMIR 用这些信息生成 cleanup blocks。

规则：

- `defer` 在 success/error exit 都运行。
- `errdefer` 只在 error exit 运行。
- drop 顺序遵循语言生命周期规则。
- 用户代码不能手动调用 compiler-only drop hook。
- cleanup lowering 必须保留 source diagnostics。

## 17. Async Frame

CoreIR 拥有 async frame metadata。PortableMIR 降低 frame memory 和 state transition。

`AsyncFramePlan` 包含：

- async function concrete ID
- frame type ID
- state enum layout
- parameter captures
- await 后仍存活的 local captures
- await point list
- poll function concrete ID
- start / stop / drop helper requirements
- result type
- error-union result layout，若适用

CoreBody 标记 await sites 和跨 suspension 存活的值。PortableMIR 将这些标记降低为 frame field load/store、
state transition 和 runtime helper call。

## 18. Runtime Helper

CoreIR 拥有 runtime helper requirements。

helper 类别：

- memory copy / set / compare
- string constants and string access
- diagnostics / panic
- bounds check failure
- error name / id
- recursive drop
- async runtime
- interface / vtable helpers
- varargs helpers
- hosted libc bridge
- syscall bridge
- target intrinsic bridge

每个 helper 包含：

- stable helper ID
- symbol name
- signature
- body kind：generated、extern、runtime library、target intrinsic
- required capabilities
- dependencies on other helpers

helper closure 是 worklist 收敛的一部分。

## 19. Globals 和 Constants

CoreIR 拥有 global object planning：

- global variables
- global constants
- string literals
- embedded constants
- vtables
- async frame descriptors
- runtime helper data
- global initialization order

每个 global 包含：

- 源 `GlobalId`，若适用
- concrete type
- initializer Core expression 或 constant data
- mutability
- linkage / export attributes
- required capabilities
- stable symbol name

global initializer 不能在 target emission 阶段触发新的语义发现。

## 20. 语言语义和 Target Capability

CoreIR 必须区分“Uya 语言语义是否支持”和“目标能力是否支持”。

语言语义层面，普通 build、hosted native、freestanding native、PTX、microapp 都共享 parser/checker/CoreIR
语义。不同目标只能在 capability 层拒绝不支持能力，不能创建方言。

### 20.1 Capability 边界合同

语言语义只能由 parser、checker、TypedProgram 和 CoreIR 冻结。target profile 只回答“这个已经合法的 Uya
程序是否能在当前目标上使用某项能力”。因此：

- target 不能新增、删除或重解释 Uya 语法、关键字、内建函数、类型规则、proof 规则或标准 CoreIR
  lowering 语义。
- capability 拒绝必须是 diagnostic；diagnostic 至少携带 capability 名称、触发源构造和目标 profile。
- capability diagnostic 不能静默回落 C99，不能跳过 safety proof，也不能在 checker 阶段伪装成另一套语言规则。
- CoreIR metadata 中的 capability fact 只能描述能力需求和 source attachment，不能携带 type/call/field/proof/
  cleanup 等会改变语言语义的事实；CoreIR verifier 必须拒绝这种混入。

capability 示例：

- hosted libc
- filesystem
- process environment
- argv access
- malloc / free
- pthread / threading
- C extern linking
- `@c_import`
- syscall
- inline asm
- async runtime
- diagnostic runtime
- freestanding runtime helper
- future PTX device / kernel capability

### 20.2 具体能力边界

| 能力 | CoreIR 表达 | 不支持时的行为 | 禁止行为 |
| --- | --- | --- | --- |
| `@c_import` | 顶层 build graph capability，记录导入路径、cflags/ldflags 和源位置 | 目标或 profile 不支持 C 构建导入时输出 capability diagnostic | 把 `@c_import` 改成表达式 builtin、删除该语法、静默忽略 C 文件或回落 C99 |
| filesystem | 标记文件系统访问、路径解析、目录遍历和宿主工具链文件 IO 需求 | freestanding/device/microapp profile 不支持时诊断具体 API 或源构造 | 改变 `std.fs`/libc 绑定语义、伪造空结果或跳过错误联合 |
| pthread / threading | 标记线程、mutex、condvar、TLS/TSD 和原子等待等需求 | 单线程 profile 或 device profile 不支持时诊断 threading capability | 把程序改写成单线程方言、改变内存/同步语义或忽略 join/cancel 错误 |
| syscall | 标记裸 syscall 或 libc syscall bridge 需求，保留 errno/error-union 语义 | 非对应 OS/ABI 或禁用 syscall profile 下诊断 syscall capability | 改变 `@syscall` 返回/错误语义、绕过 proof 或偷偷替换为不等价 hostcall |
| `@asm` | 标记 inline asm、寄存器约束、clobber 和目标 ISA 需求 | 目标 ISA/backend 不支持时诊断 asm capability 和源位置 | 让 asm 语法变成目标专属方言、生成普通 Uya 语义替代或吞掉 clobber |
| future PTX device subset | 标记 device/kernel、地址空间、SIMD/atomic 和 host bridge 需求 | PTX profile 不支持某能力时诊断 device capability | 引入 PTX-only Uya 语法、改变标准库可见语义或让 host/device checker 分叉 |

拒绝规则：

- 不支持 capability 时必须给明确 diagnostic。
- diagnostic 要指向触发该 capability 的源构造。
- 不能静默回落 C99。
- 不能跳过安全证明。
- 不能用改变语言语义的方式“支持”目标。

PortableMIR 和 backend 可以细化 capability 检查，但源头 requirement 应该已由 CoreIR 记录。

## 21. 确定性

`LoweredProgram` 输出必须确定：

- 同一输入在稳定排序后产生相同 concrete IDs。
- symbol name 从结构身份派生。
- worklist 顺序不泄漏 hash iteration nondeterminism。
- diagnostics 按源码顺序或稳定依赖顺序输出。
- dump 输出稳定。
- fingerprint 不依赖 C 文本、object section order 或 backend emission order。

建议 stable sort key：

```text
(module id, declaration id, mono key, body kind)
```

### 21.1 并行 CoreLower 归并规则

CoreLower 可以在未来并行化，但并行不能改变语义、ID 或 diagnostics 顺序。

CoreLower 并行边界分三段：

1. discovery 阶段可以并行收集“请求”，但 worker 只能写入线程本地 request buffer，不得分配
   `FunctionId` / `CoreBodyId` / `CoreStmtId` / `CoreExprId` / `CorePlaceId` / `CoreSemanticFactId`，
   也不得写共享 `LoweredProgram` 表。
2. stable merge barrier 由主线程执行：按 stable key 排序、去重、追加 worklist，并在这一点统一分配
   concrete function/type/helper/interface/error-union/async-frame/drop-defer/core body 相关 ID。
3. worklist closure 冻结后，per-function CoreBody materialization 才允许并行。worker 只消费 frozen
   `LoweredProgram`、`TypedProgram` 和 AST 只读视图，输出本地 CoreBody fragment、diagnostic fragment
   和 dump fragment；主线程按 stable function order 归并，归并结果必须与串行执行的 ID、dump 文本和
   diagnostic 顺序一致。

允许并行的工作：

- per-function CoreBody 实体化，前提是 worklist closure 已冻结。
- per-type layout summary 计算，前提是 canonical type IDs 已冻结。
- dump/golden 生成前的只读摘要收集。

必须串行或稳定归并的工作：

- reachable roots、generic instance、runtime helper、error-union layout、async frame 和 drop/defer plan discovery。
- worklist 追加和去重。
- concrete function/type/helper ID 分配。
- diagnostics 输出顺序。

如果实现采用并行发现请求，worker 只能产生局部 request buffer；主线程按 stable key 合并后再分配 ID。
冻结后的并行阶段不得再新增 concrete function、concrete type、helper、vtable、error-union layout 或 async frame。
每个 worker 使用独立 scratch arena，不得写共享 `LoweredProgram` 表。

禁止模式：

- worker 在 discovery 阶段直接 append `LoweredProgram` 输出表。
- worker 依据 hash iteration 顺序分配 stable ID。
- 冻结后的 per-function materialization 追加新 reachable root、generic instance、runtime helper、layout 或
  async/drop/defer discovery 项。
- 并行开关改变 CoreIR dump、verifier diagnostic、source span 排序或 CoreBody range。

## 22. 内存和生命周期

`LoweredProgram` 使用独立动态表和内存统计。

必须统计：

- function count / capacity / bytes
- body count / capacity / bytes
- type count / capacity / bytes
- global count / capacity / bytes
- interface count / capacity / bytes
- error-union count / capacity / bytes
- async-frame count / capacity / bytes
- drop/defer plan count / capacity / bytes
- helper count / capacity / bytes
- worklist count / capacity / bytes
- total estimated bytes
- 当前阶段 current / peak resident bytes

生命周期：

```text
TypedProgram complete
  -> initialize LoweredProgram
  -> close worklist
  -> verify CoreIR
  -> freeze and optionally dump
  -> PortableMIR lowering
  -> release LoweredProgram when no longer needed
```

CoreBody 实体化可能仍需要 AST 结构。CoreBody 和 source spans 稳定后，PortableMIR 不应该需要完整 checker state。

## 23. CoreIR Verifier

CoreIR verifier 必须在 PortableMIR 之前运行。

module 检查：

- 所有 table ID reference 在范围内。
- concrete function / type / helper identity key 无重复。
- 所有 reachable roots 都有 concrete function。
- 每个 concrete function 有合法 signature。
- 每个 body 引用合法 concrete function。
- 每个 referenced type 有 concrete type 或合法 upstream `TypeId`。
- 每个 interface dispatch 有 `InterfacePlan`。
- 每个 error-union use 有 `ErrorUnionLayout`。
- 每个 async function 有 `AsyncFramePlan`。
- 每个 runtime helper dependency 已注册。

body 检查：

- 每个 Core expression 有 `TypeId`。
- Core expression 的直接 `TypeId` 与冻结的 type semantic fact 必须一致。
- call targets 已解析。
- method dispatches 已解析。
- field accesses 有 `FieldId`。
- `try` / `catch` 只作用于 error-union 值。
- cleanup scopes 嵌套合法。
- `defer` / `errdefer` body 不包含禁止的控制流。
- 需要 drop 的值有 drop plan。
- extern、`@c_import`、syscall、asm、hosted-only 构造带 capability requirement。
- `@naked_fn` body 只包含 naked-compatible `@asm` 构造，不包含普通 cleanup、drop、async、error propagation
  或隐式 return 语义。
- 并行 CoreLower 产物在 stable merge 后与串行输出的 IDs、dump 和 diagnostics 一致。

verifier 输出必须稳定并带 source location。

## 24. Dump 格式

CoreIR dump 独立于 MIR dump。

示例：

```text
lowered_program
  functions=3 types=5 globals=1 helpers=2

fn #0 @main decl=12 body=#0 sig=() -> i32 caps=[hosted_libc]
body #0:
  stmt #0 return expr=#2
  expr #2 const_int type=i32 value=0
```

dump 目标：

- 证明 closure 已在 backend 前完成。
- 让 generic/helper discovery 可审计。
- 支持 CoreLower golden 测试。
- 避免 target-specific 输出细节。
- 必要时规范化 source paths。

## 25. 与现有 LoweredBodyOp 的关系

`LoweredBodyOp` 当前只记录 native build subset 的狭窄形状，不是完整 CoreIR。

迁移规则：

- 现有 `LoweredBodyOp` 可在 MIR bootstrap 期间保留为兼容数据。
- 新 native 语言能力不得新增 one-off `LoweredBodyOp` opcode。
- 现有 body op smoke 测试应迁移为 CoreBody dump 和 MIR dump。
- CoreBody 覆盖当前 native subset 后，`LoweredBodyOp` 标记为 legacy-only。

`compile_files(...)` 16 参数缺口必须通过 CoreBody + PortableMIR 解决，不能加特殊 call opcode。

## 26. 与 C99 的关系

第一阶段 C99 可以继续直接消费 `LoweredProgram` 作为 oracle。这样 native 迁移到 MIR 时，C99 仍是
独立 oracle。

新增的完整函数体语义必须先进入 `CoreBody` dump 和 verifier。C99 可以继续把 `LoweredProgram` 作为
oracle，但不能成为新 body 语义的唯一实现位置；如果需要新的 statement、expression、place 或 cleanup
形状，先扩展 CoreBody 节点、稳定 dump 和 verifier 负例，再决定 C99 是否直接消费该事实或继续作为差分
oracle。

C99 必须遵守 CoreIR 合同：

- 不重新进入 checker。
- emission 阶段不新增 generic instance。
- emission 阶段不新增 error-union layout。
- emission 阶段不新增 helper discovery。
- 不修改冻结的 `LoweredProgram`。

后续主线优先引入独立 `PortableMIR -> MirC99Plan`，把 C99 当 portable assembly 验证完整 MIR 语义；
该路线不得混用现有 AST/LoweredProgram `C99Plan` / `C99Emitter` 作为生产成功路径，且在 parity 证明前
不能删除现有 C99 oracle。

## 27. 与 PortableMIR 的关系

PortableMIR lowering 接收：

- 冻结的 `LoweredProgram`
- 每个有函数体的 concrete function 的 `CoreBody`
- target profile，用于 capability 检查
- source span / proof metadata，只能通过 CoreIR 明确转交

PortableMIR lowering 默认不查询 `TypedProgram`。确实需要 `TypedProgram` 中的 source/proof 辅助信息时，必须先把该字段列入 CoreIR 合同；不能把 `TypedProgram` 当作语义查询旁路。

PortableMIR lowering 禁止：

- 实例化泛型。
- 创建新的 concrete type。
- 创建新的 helper。
- 推断 call target。
- 推断 field ID。
- 修补缺失 cleanup plan。

如果 MIR 需要这些信息，说明 CoreIR 不完整。

## 28. 迁移策略

推荐顺序：

1. 新增本文并接入文档引用。
2. 在 `LoweredProgram` 旁新增 `CoreBody` 设计骨架。
3. 为现有 closure tables 增加 CoreIR dump。
4. 为现有 closure tables 增加 CoreIR verifier。
5. 把当前简单 `LoweredBodyOp` case 导入等价 CoreBody。
6. 增加 call、local、return、simple branch 的 CoreBody 记录。
7. 增加 cleanup scope 记录。
8. 增加 aggregate、interface、error-union、async、helper 记录。
9. 让 PortableMIR 消费 CoreBody，而不是 ad hoc body op。
10. 将 `LoweredBodyOp` 冻结为 legacy compatibility。
11. 用 `compile_files(...)` 作为第一个大型 CoreIR + MIR 验收样本。

每一步都应该先补 dump/verifier 测试，再改变 backend 行为。

## 29. 测试计划

CoreIR 测试：

- empty program closure
- single `main` root
- direct function call closure
- generic function instance closure
- generic method instance closure
- generic struct instance closure
- interface method plan 和 vtable plan
- error-union layout closure
- async frame plan closure
- drop/defer plan closure
- runtime helper closure
- stable sorting
- dynamic table growth beyond old fixed limits
- CoreBody dump for return/call/local/branch
- `@naked_fn` CoreBody dump 和 verifier negative cases
- parallel CoreLower stable merge / deterministic dump
- CoreIR verifier negative cases

建议门禁脚本：

```bash
bash tests/verify_coreir_dump_golden.sh
bash tests/verify_coreir_verifier.sh
bash tests/verify_coreir_closure_contract.sh
```

集成测试：

- representative inputs 的 C99 emission 不漂移。
- native minimal subset 可经 CoreBody 再到 MIR。
- `UYA_STRICT_TYPED_BACKEND=1` 继续兼容。
- `UYA_DUMP_LOWERED_PROGRAM=1` 包含 CoreIR summary 且不带 target details。
- no-silent-C99 fallback 测试继续固定 native 失败边界。

## 30. 验收标准

`TypedProgram -> LoweredProgram/CoreIR` 层准备好喂给 PortableMIR 的条件：

- CoreIR 有书面合同和稳定 dump。
- CoreIR verifier 在 PortableMIR 前运行。
- worklist closure 在 backend 前创建所有 concrete functions / types / helpers。
- 有源码函数体的 concrete function 都有 CoreBody。
- 新 native language feature 不再新增 `LoweredBodyOp` variant。
- C99 仍能使用冻结 `LoweredProgram` 作为 oracle。
- PortableMIR 能从 CoreBody lower 当前 native subset。
- 缺语义事实时修 CoreIR/TypedProgram 合同，而不是让 backend 重新进 checker。

## 31. 未决问题

延期到实现压力出现后再决定：

- CoreBody 是否长期保持树形，还是演进成更扁的 structured HIR。
- CoreIR 是否负责 compile-time-only builtin 之外的常量折叠。
- C99 应消费 CoreBody，还是继续保持现有 planner 到 MIR->C99 成熟。
- async 状态机展开多少放在 CoreIR，多少放在 PortableMIR。
- CoreIR 是否需要显式 dominance/scope index，还是完全交给 MIR。

v1 默认保守：CoreIR 关闭语言语义并记录结构化 body；PortableMIR 负责低级控制流和内存。
