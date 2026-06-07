# PortableMIR 白皮书

**状态**: 设计白皮书，待实现
**更新日期**: 2026-06-07
**相关文档**: `docs/coreir_lowered_program_whitepaper.md`、`docs/todo_compiler_1s.md`、
`docs/compiler_1s_architecture_design.md`、`docs/native_cmd_build_subset.md`

## 1. 目的

PortableMIR 是 Uya Core lowering 和 target backend 之间共享的低级函数体 IR。它的目标是让多个后端复用同一份
语言 lowering，而不是让 native、PTX、exec、C99 各自重新发现 Uya 语义。

目标流水线：

```text
AST
  -> SemanticDb
  -> TypedProgram
  -> LoweredProgram / CoreIR
  -> PortableMIR
  -> Target backend
```

`LoweredProgram / CoreIR` 的详细上游合同见 `docs/coreir_lowered_program_whitepaper.md`。PortableMIR 只消费冻结后的
`LoweredProgram + CoreBody`，负责把结构化 CoreBody 降成 target-neutral CFG/value/memory IR。

第一消费者是 Linux x86_64 hosted native，但设计必须给 freestanding native、PTX、exec bytecode 和 C99 留出扩展路径。

## 2. 目标和非目标

目标：

- 表达当前完整 Uya 语言在 CoreIR 闭包后的低级函数体。
- 为 native、PTX、exec、未来 MIR->C99 提供统一 lowering 输入。
- 保持 MIR 构造和 verifier 线性、紧凑，兼容 1 秒编译器目标。
- 通过 target capability 显式拒绝不支持能力，而不是让 backend 临时报错。
- 保留 diagnostics、safety proof、cleanup path 和 ABI lowering 所需 metadata。

非目标：

- PortableMIR 不是 LLVM IR，不提供大型优化框架。
- PortableMIR 不编码 x86_64 register、ELF section、PTX instruction、C syntax 或 object relocation。
- PortableMIR v1 不要求全局优化流水线。
- PortableMIR 不替代 `LoweredProgram`，它消费 `LoweredProgram`。
- 第一阶段不要求 C99 默认迁移到 MIR，因为 C99 仍是独立 oracle。

## 3. 分层边界

### 3.1 输入合同

PortableMIR lowering 默认接收：

- 冻结的 `LoweredProgram`
- 每个 concrete function 的 `CoreBody`
- `CoreBody` 中已转交的 source span、proof、layout、capability metadata
- target profile

PortableMIR lowering 默认不查询 `TypedProgram`。如果确实需要 `TypedProgram` 里的 source/proof 辅助信息，必须先把该事实加入
CoreIR 合同，再由 CoreBody 或 LoweredProgram 转交。MIR 不能把 `TypedProgram` 当成语义查询旁路。

### 3.2 PortableMIR

PortableMIR 拥有低级函数体：

- basic blocks 和 terminators
- typed values 和 locals
- 地址计算
- 显式 load / store / copy / move / drop
- calls 和 returns
- branch / switch-like 控制流
- error / defer / errdefer / drop cleanup paths
- target capability requirements

### 3.3 LoweredProgram + CoreBody -> PortableMIR lowering 合同

PortableMIR lowering 合同必须把完整语言面拆成可验证 feature mask：

- expressions 和 statements。
- structured control flow 到 basic blocks / terminators。
- load/store/address 显式内存形态。
- atomic operation。
- SIMD vector / mask operation。
- call / return / branch。
- field / index / slice address lowering。
- copy / move / drop。
- cleanup path。

`portable_mir_lowering_contract_init` 只接受 verifier-clean 的 `PortableMirCoreInput`，并要求当前 lowering
实现声明支持上述全部 feature。某个 feature 未实现时必须表现为缺失合同，而不是让 backend 临时发现语义缺口。
合同 API 不接受 `TypedProgram` 或 checker state；缺 source/proof/capability/layout metadata 时先回补 CoreIR。

metadata gap 分类：

- source span。
- proof result。
- capability requirement。
- layout metadata。
- call target。
- field ID。
- cleanup plan。

这些缺口在 `portable_mir_metadata_gap_requires_coreir_backfill` 中统一判定为 CoreIR 回补需求。

### 3.4 Target backend

backend 消费 verifier 通过后的 PortableMIR：

```text
PortableMIR -> MachineModule -> object / executable
PortableMIR -> PtxModule     -> PTX / cubin
PortableMIR -> ExecBytecode  -> VM
PortableMIR -> C99Plan       -> C99 text
```

backend 可以决定 ABI 细节、寄存器分配、指令选择、文本输出、object layout、runtime linkage。backend 不允许新增 generic instance、
新增 error-union body、重新进入 checker 或修改 frozen LoweredProgram。

## 4. 核心数据模型

所有 MIR 表都是动态 vector。程序规模不能由固定容量限制。

PortableMIR 必须显式记录 target-neutral layout metadata、calling convention、hosted/freestanding runtime capability
和 address space。layout metadata 包括 size/alignment、layout ID、tag/payload offset、atomic alignment、
vector lane stride、mask representation 和 ABI class；function / instruction 记录 calling convention 与 runtime
capability mask，target profile 记录支持的 address space 和 calling convention mask。

```text
MirModule
  target_profile: MirTargetProfile
  functions: MirFunction[]
  globals: MirGlobal[]
  types: MirType[]
  constants: MirConst[]
  debug_locs: MirDebugLoc[]
  capability_reqs: MirCapabilityReq[]

MirFunction
  lowered_function_id: ConcreteFunctionId
  symbol_name: InternId
  signature: MirSignatureId
  attrs: MirFunctionAttrs
  body_kind: normal | asm_only_naked
  naked_asm_inst_start/count
  naked_forbidden_lowering_mask
  params: MirValueId[]
  locals: MirLocal[]
  blocks: MirBlock[]
  entry_block: MirBlockId
  cleanup_model: MirCleanupModel
  required_caps: MirCapabilitySet

MirBlock
  label: MirBlockId
  params: MirBlockParam[]
  inst_range: MirInstRange
  terminator: MirTerminator
  debug_loc: MirDebugLocId

MirInst
  op: MirOp
  type_id: MirTypeId
  operands: MirOperandRange
  result: MirValueId
  debug_loc: MirDebugLocId

MirTerminator
  kind: MirTerminatorKind
  operands: MirOperandRange
  successors: MirSuccessorRange
  debug_loc: MirDebugLocId
```

## 5. ID 模型

MIR 使用稳定整数 ID：

- `MirFunctionId`
- `MirBlockId`
- `MirInstId`
- `MirValueId`
- `MirTypeId`
- `MirLocalId`
- `MirGlobalId`
- `MirConstId`
- `MirDebugLocId`

ID 是动态表索引，在 owning MIR module 生命周期内稳定。target backend 不得把 MIR 表 raw pointer 当作长期身份。

## 6. Values、Locals 和 Blocks

PortableMIR 是 typed three-address code，带显式 addressable locals。它可以是 SSA-like，但不是完整 optimizer SSA 合同。

- function parameters 是 `MirValueId`。
- instruction results 是 `MirValueId`。
- block parameters 表达 control-flow edge 上传入的值。
- 可变 source variable 若需要 storage，就降低为 `MirLocalId + addr_of_local`。
- aggregate storage、defer state、async frame、out-param 使用显式地址。

v1 不需要 `phi` 指令。需要 edge-dependent selection 时使用 block parameters；源变量可通过 local load/store 表达。

每个 block 必须有且只有一个 terminator。

初始 terminator：

- `return`
- `br`
- `cond_br`
- `switch_int`
- `unreachable`
- `cleanup_return`
- `cleanup_resume`

`cleanup_return` / `cleanup_resume` 是可选规范形式；v1 若更简单，也可以展开为普通 cleanup blocks。

## 7. 类型模型

MIR type 是 concrete、lowered、layout-aware 的类型，不是 parser type syntax。

初始 type kind：

- `void`
- `bool`
- signed integers: `i8`, `i16`, `i32`, `i64`, `isize`
- unsigned integers: `u8`, `u16`, `u32`, `u64`, `usize`
- floating point: `f32`, `f64`
- pointer: pointee type、mutability、address space
- array: element type、length
- slice: pointer field、length field、constness
- struct: concrete layout ID、fields
- union: tag layout、payload layout、active-variant metadata
- enum: tag integer type、variant mapping
- tuple: ordered fields
- atomic: value type、memory order、lock-free / helper requirement
- vector: element type、lane count、lane layout
- mask: lane count、representation、comparison result mapping
- function pointer / callable ABI descriptor
- error value
- error union: tag + payload layout
- async frame reference / concrete frame layout
- opaque external type

aggregate type 引用来自 CoreIR 的 layout metadata：

- size
- alignment
- field offsets
- tag offset / size
- payload offset / size
- atomic alignment / lock-free requirement
- vector lane count / lane stride
- mask storage representation
- ABI class hint

verifier 按 canonical `MirTypeId` 检查类型，不按字符串名比较。

## 8. 内存和地址模型

PortableMIR 必须显式表达内存。backend 不应从 AST shape 推断地址。

address-producing operations：

- `addr_of_local`
- `addr_of_global`
- `addr_of_param`
- `field_addr`
- `index_addr`
- `slice_ptr_addr`
- `slice_len_addr`
- `ptr_offset`
- `bitcast_addr`

memory operations：

- `load`
- `store`
- `copy`
- `move`
- `memset`
- `memcpy`
- `atomic_load`
- `atomic_store`
- `atomic_rmw`
- `atomic_cmpxchg`
- `drop_value`
- `drop_in_place`

address metadata：

- pointee type
- alignment
- mutability
- address space
- provenance category: local、global、param、heap、external、frame、unknown
- safety proof ID，若 bounds/lifetime proof 相关

target-neutral address spaces：

- `generic`
- `host`
- `global`
- `shared`
- `local`
- `constant`
- `device`

CPU hosted native 主要使用 `generic` / `host`。PTX 后续映射到 `.global`、`.shared`、`.local`、`.const`。

bounds check 表达为普通 control flow + diagnostic/runtime helper reference；已证明安全的访问保留 proof metadata。

## 9. 指令集合

v1 指令集合保持小而规则。

constants：

- `const_int`
- `const_bool`
- `const_null`
- `const_error`
- `const_string_ref`
- `const_aggregate`
- `const_vector`
- `const_mask`

arithmetic / bit ops：

- `add`, `sub`, `mul`
- `sdiv`, `udiv`, `srem`, `urem`
- `and`, `or`, `xor`
- `shl`, `shr_s`, `shr_u`
- `neg`, `not`
- checked / wrapping / saturating variants，按 Uya 语义需要加入
- vector lane-wise variants 使用同一 opcode + vector type，或使用明确 `vector_*` opcode；两者都必须保留
  `@vector(T, N)` 语义和 scalar fallback 能力

comparisons：

- `icmp_eq`, `icmp_ne`
- `icmp_slt`, `icmp_sle`, `icmp_sgt`, `icmp_sge`
- `icmp_ult`, `icmp_ule`, `icmp_ugt`, `icmp_uge`
- `fcmp_*`，按当前 `f32` / `f64` 语义启用
- vector comparison 返回 `MirType.mask(lanes)`，不得退化为 scalar `bool`

conversions：

- `int_cast`
- `ptr_to_usize`
- `usize_to_ptr`
- `bitcast`
- `addrspace_cast`

memory：

- `addr_of_local`, `addr_of_global`, `field_addr`, `index_addr`, `ptr_offset`
- `load`, `store`, `copy`, `move`, `memset`, `memcpy`

calls：

- `call`
- `call_indirect`
- `call_extern`
- `call_builtin`
- `invoke_cleanup`，若 cleanup edge 直接表达

aggregate：

- `make_struct`
- `extract_field`
- `make_tuple`
- `extract_tuple`
- `make_slice`
- `slice_ptr`
- `slice_len`
- `make_error_union_ok`
- `make_error_union_err`
- `error_union_is_err`
- `error_union_payload`
- `error_union_error`

runtime / target hooks：

- `runtime_helper`
- `target_intrinsic`
- `asm_block`

`target_intrinsic` 和 `asm_block` 必须携带 capability requirement；backend 可在不支持时明确拒绝。

## 10. 控制流 lowering

structured source statements 从 CoreBody 降到 blocks：

- `if` -> condition value + `cond_br`
- `while` -> preheader、condition、body、exit blocks
- `for range` -> iterator/index blocks
- `break` / `continue` -> 先运行必要 cleanup，再跳到 loop target
- `return` -> 若有 active defer/drop，先经过 cleanup
- `try` -> 检查 error-union tag，错误路径运行 errdefer/cleanup 后传播
- `catch` -> 错误路径绑定 error payload

每个拥有 cleanup 的 source scope 都有 cleanup record。lowering 可选择 inline cleanup blocks 或 shared cleanup blocks。
verifier 只要求每条 exit path 满足 active scope stack 的 cleanup obligations。

## 11. Error、Defer、Errdefer 和 Drop

Uya cleanup 语义必须在 target lowering 前表达。

MIR lowering 使用 CoreIR 提供的 cleanup stack：

```text
scope_enter
  push defer actions
  push errdefer actions
  register values requiring drop
scope_exit_success
  run drops and defers in required order
scope_exit_error
  run drops, errdefers, and defers in required order
```

生成的 MIR 是普通 blocks 和 calls：

- custom `drop` 降为 concrete drop function call。
- recursive aggregate drop 由 CoreIR 展开或引用 `LoweredProgram` 中的 helper/plan。
- `defer` / `errdefer` statement 变成带 source location 的 cleanup actions。
- error propagation 显式传递或存储 error value。

verifier 规则：

- 每条 `return` 路径满足 active `defer` 和 drop actions。
- 每条 error propagation 路径满足 active `errdefer`、`defer` 和 drop actions。
- `errdefer` 不在 success exit 运行。
- cleanup block 不回跳到未声明的用户控制流。

## 12. Calls、ABI 和 Extern

MIR call 是 target-neutral，但带足够 ABI metadata。

call metadata：

- callee kind: internal、method、interface dispatch、function pointer、extern、runtime helper、builtin
- calling convention: Uya、C、syscall、target intrinsic、future kernel/device
- argument ABI classes，若已知
- return ABI class，若已知
- varargs metadata
- can unwind / can error / no-return flags
- required capabilities

internal generic / method call 必须已经指向 `LoweredProgram` 中的 concrete function。

interface call 降为：

- 有事实证明时 direct concrete call
- vtable load + indirect call
- boxed interface runtime helper call

`extern fn` 和 `@c_import` 在 MIR 中仍是 target-neutral，但携带 hosted capability requirement。hosted native 可降为 object references 和 linker inputs；freestanding native / PTX 可在 capability pass 明确拒绝。

## 13. Builtin 和特殊形式

compile-time-only builtin 在 MIR 前解决：

- `@size_of`
- `@align_of`
- statically known array 上的 `@len`
- source location / function name constants
- 已由 CoreIR materialize 的 type info

runtime builtin 降为 MIR 指令或 runtime helper：

- slice 上的 `@len`
- error ID / name access
- varargs operations
- `atomic T` 的 load / store / fetch-add / fetch-sub / CAS-loop 复合赋值，默认 `seq_cst`
- `@vector.splat`、`@vector.load`、`@vector.store`、`@vector.select`、`@vector.reduce_*`、`@vector.any`、
  `@vector.all`
- syscall-like operations
- target intrinsics
- `@asm`

`@asm` 表达为 opaque MIR operation，带 inputs、outputs、clobbers、target constraints 和 capability requirements。
backend 可因 target、register class、memory operand 或 clobber unsupported 而拒绝。

### 13.1 `@naked_fn`

`@naked_fn` 在 MIR 中必须是函数级 flag，不是普通 `asm_block` 的局部属性。

MIR 表达规则：

- `MirFunction.flags.naked = true`。
- `MirFunction.body_kind = asm_only_naked`，并用 `naked_asm_inst_start/count` 指向唯一裸汇编 body。
- `MirFunction.naked_forbidden_lowering_mask` 必须覆盖 prologue/epilogue、stack slot、cleanup、drop、async 和
  implicit return lowering。
- body 必须是 `MirNakedBody` 或等价的 asm-only body 形态，不能复用普通 `blocks` / `entry_block` 形态。
- body 只能包含 target-checked asm / target intrinsic，不允许普通 MIR local、stack slot、spill、cleanup block、
  drop、defer、errdefer、async frame 或隐式 return lowering。
- 参数和返回值 ABI 只作为 verifier metadata 记录；backend 不生成常规参数搬运、栈帧、prologue 或 epilogue。
- naked 函数必须携带 `naked_function`、`inline_asm` 和目标 calling convention capability。

native backend 对 naked 函数的目标形态是：

```text
symbol label
  raw / checked asm body
  no compiler-generated prologue
  no compiler-generated epilogue
```

不支持 naked 函数的 target 必须在 capability pass 报错。不能把 naked 函数降级为普通函数，也不能静默走 C99。

## 14. Async

async closure data 在 `LoweredProgram`；MIR 表达 concrete async frame layout 上的操作。

MIR 需要表达：

- frame allocation 或 frame address
- frame field access
- state load/store
- poll calls
- await suspension / resume points
- cancellation / stop / drop paths
- future result extraction

hosted native v1 可以通过现有 runtime helper 降低 async，但 MIR 仍要显式表达 frame layout、state transition 和 cleanup path，方便后续 freestanding lowering。

## 15. Target Profile 和 Capability

每个 backend 声明 target profile：

```text
MirTargetProfile
  os
  arch
  pointer_size
  endianness
  default_address_space
  object_format
  runtime_mode: hosted | freestanding | device
  supported_call_conventions
  supported_address_spaces
  supported_features
```

capability 示例：

- hosted libc
- filesystem
- environment
- process argv
- malloc/free
- pthread/threading
- C extern linking
- c_import objects
- `naked_function`
- syscall
- inline asm
- async runtime
- panic/diagnostic runtime
- GPU kernel entry
- GPU global memory
- GPU shared memory

capability verification 在 MIR 构造后、backend emission 前运行。diagnostic 必须指向触发 unsupported capability 的源构造。

## 16. 语言语义和 Target Capability

PortableMIR 必须继承 CoreIR 的产品边界：**语言语义统一，target capability 可拒绝**。

这意味着：

- `@c_import` 是语言能力；某个 target 不支持时要报 capability diagnostic。
- filesystem、pthread、env、malloc、syscall 是 target/runtime capability，不是新的语言方言。
- PTX/device subset 未来只能拒绝 heap、libc、递归、host-only helper 等 capability，不能改变普通 Uya 语义。
- microapp / freestanding 限制必须表现为 capability diagnostic，不能静默降级或跳过 proof。
- hosted native 不能在 native 失败时静默回落 C99。

## 17. Hosted Native 优先

hosted native 是第一个完整语言 target，因为它可复用系统 ABI 和 linker 行为，同时验证 MIR 语义。

hosted native 接受：

- C ABI extern calls
- 基于 libc 的 IO / memory helpers
- 基于 pthread 的 threading helpers
- filesystem / environment operations
- `@c_import` object/linker integration

hosted native 仍然把 Uya 函数体生成 native machine code。它不是 C99 fallback，也不能静默绕回 C99。

## 18. Freestanding Native 后续推进

freestanding native 对 1 秒 self-build 和 build-seed 仍重要。它消费同一份 PortableMIR，但 target profile 更严格：

- 无 hosted libc，除非显式 bridge。
- 无 `@c_import` linker path，除非 freestanding build plan 支持。
- syscall/runtime helper 必须显式。
- filesystem/process/env/threading 未实现时明确 diagnostic。

当前 `cmd/build` native subset 是回归边界。`compile_files(...)` 缺口应成为 MIR + ABI 验收样本，不再增加 one-off `LoweredBodyOp`。

## 19. PTX 和 Device 后端

PTX 不是第一实现目标，但 MIR 不能阻断 PTX。

PTX 相关要求：

- address space 显式。
- kernel/device calling convention 可表达。
- hosted-only capability 可拒绝。
- global/shared/local/constant memory 可区分。
- target intrinsic 可表达 thread/block ID、barrier、atomic 等。
- 递归、heap、libc、unsupported runtime helper 可在 PTX emission 前拒绝。

PTX 应在 target capability pass 筛出 device subset 后消费同一份 MIR。

## 20. C99 后端关系

C99 第一阶段继续作为独立 oracle：

- MIR lowering 出 bug 时，native 和 MIR->C99 不应一起错而隐藏问题。
- 现有 C99 行为是最强兼容参考。
- hosted native parity suite 应与当前 C99 比对。

hosted native parity 稳定后，可实验性新增 `PortableMIR -> C99Plan`。生成的 C 可以更低级，使用 labels、temporaries、gotos。可读性次于语义一致。

## 21. Exec 后端关系

exec VM 继续服务 `run/test/debug`，不是 `make uya` 主产物路径。

长期形态：

```text
PortableMIR -> ExecBytecode -> VM
```

这让 exec 复用同一份语言 lowering 和 cleanup 语义。现有 VM 固定表不能定义语言或 self-build 上限；成为完整 MIR 消费者前需要动态 bytecode/frame/local tables。

## 22. Verifier

MIR verifier 是所有 backend 的强制门禁，应该便宜且线性。

module checks：

- 所有 referenced IDs 在范围内。
- 所有表 count 稳定，无固定语义容量。
- function signatures 引用合法 types。
- global initializers 匹配声明 types。
- capability requirements 已记录。

function checks：

- entry block 存在。
- 每个 block 有且只有一个 terminator。
- successor block arguments 匹配 block parameter types。
- 每个 value 有唯一 type。
- instruction operands 符合 opcode type rules。
- 当前 dominance/block-parameter 模型下不存在未定义使用。
- local address 和 store type 匹配。
- aggregate field/index 操作在 layout bounds 内。
- return/error/unreachable path 满足 cleanup obligations。
- extern/builtin/asm capability requirements 已存在。
- naked function 不含普通 blocks、locals、stack slots、cleanup obligations、implicit return 或非 naked-compatible
  instructions。

target checks：

- pointer size 和 layout assumptions 匹配 target。
- address spaces 受 target 支持。
- calling conventions 受 target 支持。
- hosted/freestanding/device capability requirements 被满足。
- target intrinsics 和 asm blocks 受 target 支持。
- `naked_function` capability、inline asm capability 和 calling convention 均受 target 支持。

默认报告第一个稳定 diagnostic；dump 模式可报告更多。

## 23. Dump 和 Golden 格式

MIR 需要稳定文本 dump。

示例：

```text
mir_module target=linux_x86_64_hosted pointer_size=8

fn @main() -> i32 caps=[hosted_libc] {
bb0:
  %0:i32 = const_int 0
  return %0
}
```

规则：

- ID 按确定顺序打印。
- type 用 canonical short name 或 stable type ID。
- golden tests 中 source path 可 normalize 或隐藏。
- target-specific generated symbol name 必须稳定，但 semantic MIR tests 不应依赖过多。
- dump 不要求完整 object/native emission。

golden test 应使用小 MIR program 隔离一个 feature。

### 23.1 并行 MIR 构造和后端归并

PortableMIR 可以在 CoreIR 冻结后并行构造，但并行边界必须清晰：

- 每个 worker 只处理一个或一组 concrete functions。
- worker 输入只能是只读 `LoweredProgram + CoreBody + target profile`。
- worker 输出写入局部 `MirFunctionBuilder` / scratch arena。
- 主线程按 stable function order 合并 `MirFunction`、diagnostics、symbols 和 dump 片段。
- 并行开关不得改变 `MirFunctionId`、`MirBlockId`、`MirValueId`、dump 文本、diagnostic 顺序或 object symbol order。

禁止事项：

- worker 不得新增 generic instance、helper、concrete type、vtable、error-union layout 或 async frame。
- worker 不得直接写全局 `MirModule` 动态表，除非使用按 stable slot 预分配的无竞争写入协议。
- worker 不得用 hash iteration order 决定 block、value、local 或 diagnostic 顺序。
- backend 并行 emission 必须先生成 per-function target fragments，再按 stable symbol order 归并 reloc/symbol/string 表。

## 24. Lowering 策略

实现按薄 vertical slices 推进：

1. 定义 MIR tables、lifecycle、dump。
2. 增加 empty module、empty function、constants、return 的 verifier。
3. 从 CoreBody lower 当前 native subset 的 returns/calls。
4. 将 MIR 导入 `MachineModule`，复用现有 native smoke。
5. 增加 locals、load/store、branch、block parameters。
6. 增加 aggregate address operations。
7. 增加 call ABI metadata 和 hosted extern calls。
8. 增加 error-union、defer/errdefer、drop cleanup paths。
9. 增加 interface、vtable、method dispatch。
10. 增加 async frame operations。
11. 增加 `@naked_fn` asm-only MIR path 和 verifier negative cases。
12. 增加并行 MIR 构造的 deterministic dump / diagnostic 归并测试。
13. 增加 hosted native/C99 full-language parity smoke。
14. 使用 `compile_files(...)` 作为第一个大型真实 MIR 验收样本。

每个 slice 必须增加 verifier test、dump/golden test；backend 行为变化时增加 backend smoke。

## 25. 验收标准

PortableMIR 准备成为 native 主路径的条件：

- 所有 MIR 表动态增长并可测量。
- `LoweredBodyOp` 不再为新 native language shape 扩展。
- verifier 在 native emission 前运行。
- 现有 native minimal tests 通过 MIR 路径。
- `@naked_fn` 通过 MIR verifier 和 native backend 专用 path，不走普通 prologue/epilogue。
- 并行 MIR 构造开关不改变 dump、diagnostics、IDs 或 symbol order。
- hosted native 和 C99 在 full-language smoke suite 上一致。
- `compile_files(...)` 16 参数调用通过 CoreBody + MIR lower 到达，而不是特殊 body opcode。
- native 失败不静默回落 C99。
- 文档和 TODO 引用本文作为 MIR 合同。

## 26. 未决问题

延期到实现压力出现后再定：

- v1 block-parameter MIR 稳定后，是否值得引入严格 SSA。
- MIR 是否保留高层 `cleanup_return` terminator，还是总是展开 cleanup blocks。
- native parity 完成后，`MIR -> C99Plan` 是否替代当前 C99 默认路径。
- async lowering v1 多少 helper-based，多少 fully expanded。
- target-independent optimization 应放多少，才不会拖慢编译器。

v1 默认保守：MIR 小、线性、可验证；只有当优化能消除真实重复或修正正确性问题时才加入。
