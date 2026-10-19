# Uya Bytecode / IR 执行后端详细设计

**版本**：v0.2
**日期**：2026-05-17  
**状态**：设计完成，第一阶段实现进行中

> **核对头（2026-10-19）**：设计与实现的一致性复核，按第 20 节的 Phase 逐段核对（本文件后续的 2026-05-17 / 2026-05-19"实现状态附记"是历史快照，保留不动）：
>
> | Phase | 设计内容 | 2026-10-19 状态 | 证据 |
> |---|---|---|---|
> | 1 | checked AST → HIR → bytecode → VM；`uya run --exec` 跑 hosted 基础程序 | **已完成** | `src/exec/lower.uya`（264 KB）、`builder.uya`（146 KB）、`vm.uya`（103 KB）；`src/main.uya:2798` 的 `BACKEND_EXEC` 分支 |
> | 2 | `!T` / `try` / `catch`；`defer`/`errdefer`；struct/array/slice/union；全局初始化；`uya test --exec` | **已完成** | `tests/test_exec_vm_error_union.uya`、`test_exec_vm_error_builtin.uya`、`test_exec_vm_catch_*.uya`（5 个）、`test_exec_vm_defer.uya`、`test_exec_vm_drop_local.uya`、`test_exec_vm_aggregates.uya`、`test_exec_vm_union_dispatch.uya`、`test_exec_vm_globals.uya` / `test_exec_vm_globals_multi.uya` / `test_exec_vm_global_init_fail.uya`（+`verify_exec_vm_globals.sh`、`tests/exec_vm_global_chain/`） |
> | 3 | `extern` / `extern "libc"` 通用执行、varargs 长期策略、interface / 间接调用、更完整标准库、fallback 稳定化 | **已完成** | `tests/test_exec_vm_extern_bridge.uya`、`test_exec_vm_extern_impl.uya`、`test_exec_vm_extern_mkdir_bridge.uya`、`test_exec_vm_stdlib_unistd.uya`、`test_exec_vm_libc_module_global.uya`、`test_exec_vm_stdio_varargs.uya`（+`verify_exec_vm_stdio_varargs.sh`）、`test_exec_vm_interface_dispatch.uya`、`test_exec_vm_interface_stateful.uya`；`ExecUnsupportedReason` 枚举 + 回退逻辑在 `src/exec/main.uya:6-19` |
> | 4 | 性能优化 / 可选 bytecode cache / 热点 profiling / 可选 JIT | **未做** | `grep -rn "bytecode_cache\|cache" src/exec/*.uya` 无命中；无 JIT、无 profiling 钩子 |
>
> 另：第 20 节 Phase 2 写的"测试框架接入 `uya test --exec`"已由 `src/main.uya` 的 `--exec`/`--vm` 选项覆盖，不再是待办。

---

## 实现状态附记（2026-05-17）

本设计文档最初写成时，exec backend 仍处于纯设计状态；截至当日晚间，仓库中已经落下第一批实现，因此这里补一段现实状态，避免读者误以为“尚未开始编码”。

已落地部分：

- `src/exec/` 目录与首批文件已经创建：
  - `main.uya`
  - `hir.uya`
  - `lower.uya`
  - `bytecode.uya`
  - `builder.uya`
  - `vm.uya`
  - `value.uya`
  - `frame.uya`
  - `debug.uya`
- `src/main.uya` 已接入：
  - `use exec;`
  - `BACKEND_EXEC`
  - `--exec`
  - `--vm`
  - `--dump-exec-hir`
  - `--dump-bytecode`
  - `--trace-vm`
- `run/test` 已有第一版 exec backend 分支与 fallback 逻辑
- 最小 HIR / bytecode / VM 闭环代码已存在，当前支持的只是很小的标量子集

已验证部分：

- 现有编译器可在 `--no-safety-proof` 下重新编译 `src/main.uya`，例如：

```text
./bin/uya build src/main.uya -o /tmp/uya_exec_backend_smoke.c --no-safety-proof
```

- 现有编译器也可在默认安全证明配置下重新编译 `src/main.uya`，例如：

```text
./bin/uya build src/main.uya -o /tmp/uya_exec_default_smoke.c
```

- 新生成的编译器二进制已经可以跑通最小 VM smoke：

```text
./build/uya_exec_default_smoke_bin run --vm tests/test_main_only.uya
```

这说明：

- 模块发现已打通
- checker/optimizer 后的 exec 分叉已接线
- 新增 exec 模块不会阻塞现有 C99 代码生成
- 默认安全证明下的 `exec` 模块基础边界检查已收敛到可编译状态
- 从“新编译器二进制 -> exec build -> VM 启动最小程序”的闭环已经建立

尚未完成部分：

- 还未验证更大覆盖面的 `uya run/test --vm`
- 当前实现远未覆盖 `struct/array/slice`、`!T`、`try/catch`、`defer` 等设计目标
- 顶层 global init / global read-write 已开始接入第一版执行链路，但目前只在单文件 hosted 子集回归通过；跨模块 global 访问与多模块初始化顺序仍未收口

因此，本文其余章节依旧描述目标架构，但阅读时请以“已开始实现、仍处于第一阶段骨架期”理解。

## 实现状态附记（2026-05-19）

再补一条更新，避免读者把 `module_alias.exported_global` 这一层理解成“仍完全不可用”。

截至 `2026-05-19`，exec backend 在 hosted 标准库路径上又前进了一段：

- `use libc;` + `libc.stdout/libc.stderr` 这类 whole-module import 成员式导出全局访问，识别与导出 decl 解析链已经接通
- 当前 lowering 不再只能依赖 `checker.import_table`；针对这类 whole-module import，已补：
  - 从当前文件 `use` 语句恢复模块别名
  - 按 AST 实际命中的 `module_alias.field` 收集需要进入 exec globals 的导出项
  - `&expr` 经由 `exec_lower_make_ref_expr(...)` 接入地址构造路径

这条链路的意义是：

- `./bin/uya run --vm src/main.uya` 已不再最早卡死在 `fprintf(libc.stdout, ...)` 的 `libc.stdout`
- 此前的 `FILE{ ... }` 缺失 `buffer` 字段阻塞已收口；相关零值补齐不会在 lowering 阶段膨胀成 65536 个常量元素，而是走 HIR / bytecode / VM 聚合值构造与重复填充路径

同日后续收口结果也需要一并记录：

- `[byte: N]`、`[i8: N]`、`[u8: N]` 这一批小元素数组，在 exec VM 中已经有原生连续缓冲表示，不再只能落在 `ExecValue[]` 聚合副本上
- `stream.buffer[...] = ...`、`ctx.buf[...] = ...`、`&stream.buffer[0]`、`&buf[0]` 这类 hosted stdio / 格式化真实会命中的路径已经在 builder + VM 两侧打通
- `tests/test_exec_vm_stdio_varargs.uya` 与 `tests/verify_exec_vm_stdio_varargs.sh` 现已通过，stdout 期望值为：
  - `exec vm fprintf 7 body`
  - `exec vm printf|  ok|9`
  - `snprintf:11:body`
- `tests/verify_exec_vm_compiler_regressions.sh` 已固化两类近期修复：
  - 显式类型局部 + catch 标识符路径
  - 字段数组 / 指针字段 / 全局数组下标写入路径
- `tests/verify_exec_backend_progress.sh` 现已重新回到全绿

---

## 1. 背景

当前 `uya run` / `uya test` 的主路径是：

```text
lexer -> parser -> checker -> optimizer -> C99 codegen -> gcc/clang -> run
```

从近期编译统计看，`src/` 自举编译场景中：

- 解析耗时约 `230 ms`
- 检查耗时约 `2206 ms`
- 优化耗时约 `563 ms`
- **生成耗时约 `13169 ms`**

且上述 `13169 ms` **仅是生成 C 的时间，不包含 gcc/clang 编译与链接时间**。

这说明当前 `run/test` 的主瓶颈已经非常明确：

1. `codegen/c99` 生成大体量 C 文本
2. 宿主 C 编译器再次解析、优化、链接这些 C

因此，最直接、最对症的优化方向不是继续压 parser，而是在 `checker` 之后增加一个**直接执行后端**，让 `run/test` 在不生成 C 的前提下完成程序执行。

---

## 2. 目标

本设计引入一个新的执行后端：

```text
lexer -> parser -> checker -> exec lower -> bytecode -> VM -> run
```

目标如下：

- 为 `uya run` / `uya test` 提供一条**不经过 C99 backend** 的执行路径
- 完整复用现有 `lexer`、`parser`、`checker`、`optimizer`
- 执行输入应为 **checker 后的已定型 AST / lowered IR**，不是原始 parser AST
- 第一阶段优先解决 **hosted 路线开发体验慢** 的问题
- 设计上允许逐步覆盖 Uya 主线语义，而不是永远停留在“受限解释器”
- 未来可在同一 IR 之上同时支持：
  - `tree-walk interpreter`（调试期）
  - `bytecode VM`（主线执行）
  - `hot function JIT`（远期优化，可选）

---

## 3. 非目标

v1 明确不做以下事情：

- 不替代 `build -o xxx.c` / `build -o xxx` 的 C99 产物输出能力
- 不在第一版直接生成 x86_64 / arm64 机器码
- 不在第一版替代 microapp / baremetal / softvm 相关路径
- 不要求第一版在所有 `extern` / `@c_import` / asm / SIMD / async 场景下立即可用
- 不要求第一版解决“前端慢”的全部问题；它主要解决 `codegen + gcc` 这一大头

换句话说，本设计的第一优先级是：

- **让 hosted `run/test` 快起来**

而不是：

- 立刻让所有目标平台、所有语言特性都走执行后端

---

## 4. 总体方案选择

### 4.1 方案 A：checker 后直接执行原始 AST

优点：

- 起步最快
- 几乎不需要新增 IR 结构
- 适合快速验证语义

缺点：

- AST 过于贴近语法，执行期需要处理太多语法形态
- 控制流、`defer`、`errdefer`、`try/catch`、方法调用降级都很分散
- 难以做缓存、字节码优化、调试和后续 JIT

### 4.2 方案 B：checker 后先 lower 成执行友好的 HIR，再 lower 成 bytecode

优点：

- 语义集中，执行器简单
- 便于序列化、缓存、调试
- 便于做寄存器化 / 栈机化 VM
- 后续既能解释，也能 JIT

缺点：

- 第一版实现量高于直接 AST 解释
- 需要定义额外 IR 数据结构

### 4.3 推荐方案

采用 **两层执行 IR**：

```text
checked AST
  -> Exec HIR
  -> Bytecode
  -> VM
```

原因：

- 当前最大收益来自跳过 C99 backend；为此没必要一步到位做 native codegen
- 但如果只做原始 AST interpreter，后面很快会被语义复杂度拖住
- HIR + bytecode 能在“尽快落地”和“后续可演进”之间取得最好平衡

### 4.4 性能约束

本设计从第一天就以**缩短 `run/test` 总耗时**为目标，因此以下内容属于设计约束，不是实现后的可选优化：

- HIR 默认应视为**短生命周期 IR**，不要求整模块常驻内存
- bytecode 构建优先按**函数粒度**工作，避免长期同时持有 checked AST、完整 HIR、完整 bytecode 三份大对象
- 调试数据、source map、HIR dump、bytecode dump 必须默认关闭，仅在显式开关下生成
- VM 热路径必须优先优化：
  - 标量值访问
  - 局部槽位访问
  - 简单函数调用
  - 无 `defer` / 无错误传播 的普通返回

如果某个方案会显著增加分配量、复制量或 frame 体积，应优先调整 IR / lowering，而不是把成本留给 VM 在运行时承担

---

## 5. 执行后端分层

建议新增目录：

```text
src/exec/
  main.uya
  hir.uya
  lower.uya
  bytecode.uya
  builder.uya
  vm.uya
  value.uya
  frame.uya
  memory.uya
  builtin.uya
  extern_bridge.uya
  debug.uya
```

职责如下：

- `hir.uya`
  - 定义执行友好的 HIR 节点
- `lower.uya`
  - 把 checked AST 降为 HIR
- `bytecode.uya`
  - 定义 opcode、常量池、函数块、调试表
- `builder.uya`
  - HIR -> bytecode
- `vm.uya`
  - 字节码解释执行器
- `value.uya`
  - 运行时值表示
- `frame.uya`
  - 调用栈帧、作用域、defer 栈
- `memory.uya`
  - 局部槽位、聚合值、切片/数组/结构体布局辅助
- `builtin.uya`
  - `@print`、`@println`、`@len`、`@size_of` 等执行期桥接
- `extern_bridge.uya`
  - hosted extern/libc 调用桥
- `debug.uya`
  - 源位置、回溯、trace、字节码 dump

性能要求：

- `lower.uya` 与 `builder.uya` 的默认工作模式应按**单函数流水化**实现
- 在正常 `run/test --exec` 路径上，不应为了调试保留全量 HIR 树
- `debug.uya` 中的大多数产物都应延迟生成或显式启用

---

## 6. 输入边界

执行后端的输入不是 parser AST，而是：

- 已完成名字解析
- 已完成类型检查
- 已完成方法绑定
- 已完成泛型实例收敛
- 已完成必要 rewrite

建议在 checker 后增加一层“执行前标准化”：

- 方法调用改成显式函数调用
- `try` / `catch` 改成统一错误控制流
- `for` 改成规范循环形态
- `defer` / `errdefer` 明确挂到作用域
- 字面量结构体/数组初始化标准化
- `match` 统一降级成可执行分支

这样 exec backend 不需要再理解全部原始语法糖。

性能要求：

- 标准化应尽量复用 checker 已有信息，不重复做高成本名字解析/类型推导
- 若标准化结果仅供当前函数生成 bytecode，应允许在该函数 bytecode 构建完成后立即释放

---

## 7. Exec HIR 设计

### 7.1 HIR 目标

HIR 是面向执行的高层 IR，保留结构化控制流，但消除大部分语法糖。

它的职责：

- 比 AST 更接近语义
- 比 bytecode 更易于实现 lowering 和调试
- 让“复杂语法 -> 简化语义”的逻辑只写一次
- 在性能上充当**短生命周期过渡层**，而不是新的长期常驻中间表示

### 7.2 HIR 基本元素

建议包含：

- `HIRModule`
- `HIRFunction`
- `HIRBlock`
- `HIRStmt`
- `HIRExpr`
- `HIRTypeRef`
- `HIRValueId`
- `HIRSymbolId`

### 7.3 HIR 语句节点

建议最小集合：

- `HIR_STMT_VAR_INIT`
- `HIR_STMT_ASSIGN`
- `HIR_STMT_EXPR`
- `HIR_STMT_IF`
- `HIR_STMT_LOOP`
- `HIR_STMT_BREAK`
- `HIR_STMT_CONTINUE`
- `HIR_STMT_RETURN`
- `HIR_STMT_SWITCH_TAG`
- `HIR_STMT_DEFER_PUSH`
- `HIR_STMT_ERRDEFER_PUSH`
- `HIR_STMT_SCOPE_ENTER`
- `HIR_STMT_SCOPE_EXIT`

### 7.4 HIR 表达式节点

建议最小集合：

- `HIR_EXPR_CONST`
- `HIR_EXPR_LOCAL`
- `HIR_EXPR_GLOBAL`
- `HIR_EXPR_UNARY`
- `HIR_EXPR_BINARY`
- `HIR_EXPR_COMPARE`
- `HIR_EXPR_CAST`
- `HIR_EXPR_CALL`
- `HIR_EXPR_BUILTIN_CALL`
- `HIR_EXPR_FIELD`
- `HIR_EXPR_INDEX`
- `HIR_EXPR_SLICE`
- `HIR_EXPR_ADDR_OF`
- `HIR_EXPR_DEREF`
- `HIR_EXPR_STRUCT_INIT`
- `HIR_EXPR_ARRAY_INIT`
- `HIR_EXPR_TUPLE_INIT`
- `HIR_EXPR_TAGGED_UNION_INIT`

### 7.5 HIR 约束

- HIR 中不再保留 parser 级 token 细节
- 每个 HIR 节点都必须挂最终类型
- 每个调用都必须绑定到明确 callee 种类：
  - Uya 函数
  - builtin
  - extern/libc
  - 间接函数值
- 每个局部变量都分配稳定 `local_slot`
- 除非显式请求 dump，HIR 默认只要求在“当前函数 lowering/builder 生命周期”内存活
- 不要求保留“可逆恢复原语法”的冗余信息

---

## 8. Bytecode 设计

### 8.1 选择：寄存器机还是栈机

推荐采用**寄存器化字节码**，而不是纯栈机：

- 执行器更容易避免大量 push/pop
- 与 typed AST / HIR 的局部槽位映射更自然
- 更适合后续做 peephole 和 JIT

每个函数拥有：

- 局部槽位表 `locals`
- 临时值槽位表 `temps`
- 常量池引用
- 字节码指令流

性能要求：

- `temps` 不是“生成过多少临时表达式”的计数，而应是**最大活跃临时槽位数**
- lowering / builder 必须支持临时槽位复用，不允许简单地为每个子表达式永久分配一个新 temp
- 应优先按 block 或基本控制流区间回收 temps，以控制 frame 大小和指令操作数宽度

### 8.2 模块级结构

建议定义：

- `BCProgram`
- `BCModule`
- `BCFunction`
- `BCInstr`
- `BCConstPool`
- `BCGlobalInit`
- `BCTypeDesc`
- `BCSourceMap`

### 8.3 常量池

常量池存储：

- 整数 / 浮点字面量
- 字符串字面量
- 错误名 / 错误 id
- 类型描述引用
- 函数引用元数据

### 8.4 指令分类

建议分组如下：

- 数据搬运
- 算术与位运算
- 比较与逻辑
- 控制流
- 聚合值构造
- 访存
- 调用
- 错误控制流
- defer / 作用域
- builtin / extern

### 8.5 核心指令清单

建议第一版 opcode 集：

#### 数据搬运

- `MOV dst, src`
- `LOAD_CONST dst, const_id`
- `LOAD_LOCAL dst, local_id`
- `STORE_LOCAL local_id, src`
- `LOAD_GLOBAL dst, global_id`
- `STORE_GLOBAL global_id, src`

#### 算术与位运算

- `ADD dst, a, b`
- `SUB dst, a, b`
- `MUL dst, a, b`
- `DIV dst, a, b`
- `REM dst, a, b`
- `BIT_AND dst, a, b`
- `BIT_OR dst, a, b`
- `BIT_XOR dst, a, b`
- `SHL dst, a, b`
- `SHR dst, a, b`
- `NEG dst, src`
- `NOT dst, src`

#### 比较

- `CMP_EQ dst, a, b`
- `CMP_NE dst, a, b`
- `CMP_LT dst, a, b`
- `CMP_LE dst, a, b`
- `CMP_GT dst, a, b`
- `CMP_GE dst, a, b`

#### 控制流

- `JMP label`
- `JMP_IF_TRUE cond, label`
- `JMP_IF_FALSE cond, label`
- `RET src`
- `RET_VOID`

#### 聚合值

- `MAKE_STRUCT dst, type_id`
- `SET_FIELD agg, field_id, src`
- `GET_FIELD dst, agg, field_id`
- `MAKE_ARRAY dst, type_id, len`
- `ARRAY_SET agg, idx, src`
- `ARRAY_GET dst, agg, idx`
- `MAKE_SLICE dst, ptr, len`
- `SLICE_PTR dst, slice`
- `SLICE_LEN dst, slice`

#### 地址与内存

- `ADDR_LOCAL dst, local_id`
- `ADDR_FIELD dst, base_addr, field_id`
- `ADDR_INDEX dst, base_addr, idx`
- `LOAD_AT dst, addr, type_id`
- `STORE_AT addr, src, type_id`
- `MEMCPY dst_addr, src_addr, size`
- `MEMSET dst_addr, byte, size`

#### 调用

- `CALL dst?, func_id, arg_base, arg_count`
- `CALL_INDIRECT dst?, callee_reg, arg_base, arg_count`
- `HOSTCALL dst?, host_call_id, arg_base, arg_count`

#### 错误控制流

- `MAKE_OK dst, src`
- `MAKE_ERR dst, err_id`
- `IS_ERR dst, src`
- `UNWRAP_OK dst, src`
- `UNWRAP_ERR dst, src`
- `JMP_IF_ERR src, label`

#### 作用域与 defer

- `PUSH_DEFER fn_or_block_id, data_reg`
- `PUSH_ERRDEFER fn_or_block_id, data_reg`
- `POP_DEFER scope_id`
- `RUN_DEFER scope_id`
- `RUN_ERRDEFER scope_id`

#### builtin / debug

- `BUILTIN_PRINT arg`
- `BUILTIN_PRINTLN arg`
- `PANIC msg_id`
- `TRAP reason_id`

### 8.6 指令语义原则

- 指令必须是**已定型**的；执行器不再做复杂类型推断
- 每条指令输入输出槽位固定
- 所有跳转目标在函数内静态可解析
- 每个 scope 都有稳定 `scope_id`，便于 defer 清理
- 指令设计应优先减少 VM 热路径上的间接层级与值复制
- 若某类高频语义可在 lowering 阶段合并成更粗粒度 opcode，则不必机械保留“语法一对一”映射

---

## 9. 运行时值模型

### 9.1 Value 分类

VM 需要统一值表示：

- 整数
- 浮点
- bool
- pointer / address
- slice
- struct / tuple
- array
- union
- err union
- function ref

建议采用：

- **标量走 tagged union**
- **大聚合值走 arena / frame storage + handle**

原因：

- 纯按值复制 struct/array 会让 VM 在大对象上过慢
- 但所有东西都装箱也会让标量路径太重

性能约束：

- `Value` 不应直接拥有大 struct / array / tuple 的 payload 字节
- 聚合值默认应放在 frame storage、global storage 或常量区中，并以 handle / address 引用
- 只有经测量确认收益明确的小型 fixed-size 情况，才允许做按值内联优化

### 9.2 值表示建议

- `ValueKind`
- `Value { kind, payload }`
- `Address { base_kind, base_id, offset, type_id }`
- `AggregateHandle { storage_id, offset, type_id }`

补充约束：

- `Value` 的常见标量路径应尽量保持定长、紧凑，避免频繁堆分配
- `Address` 应能够表达“局部变量内字段”“数组元素”“切片底层元素”等常见寻址，避免为了字段访问额外构造中间聚合值

### 9.3 布局

执行后端必须共享或复刻一套稳定布局规则，至少保证：

- struct 字段 offset 与 checker / codegen 一致
- array 连续布局
- slice 为 `(ptr, len)`
- err union 的判错与 payload 读取规则稳定

建议把布局计算逻辑提到共享模块，避免 `codegen/c99` 和 `exec/` 各写一份。

性能要求：

- 执行期不应反复动态计算同一 `type_id` 的布局
- 字段偏移、元素步长、err union 判别布局等应在 bytecode 构建阶段或程序加载阶段缓存

### 9.4 聚合值构造策略

为避免 VM 在 struct/array 路径上退化成“边构造边复制”，冻结以下策略：

- `MAKE_STRUCT` / `MAKE_ARRAY` 的默认语义是**分配目标存储位置**，不是创建拥有独立 payload 的大 Value
- `SET_FIELD` / `ARRAY_SET` 默认直接写入该目标存储
- `GET_FIELD` / `ARRAY_GET` 对标量字段优先返回标量值；对聚合字段优先返回 address/handle
- 若需要整体复制 struct/array，应显式走 `MEMCPY` 或等价聚合复制路径

也就是说，聚合值的主路径是 **in-place build**，不是“先生成临时完整对象，再回写”。

---

## 10. 栈帧与作用域模型

### 10.1 调用帧

每次函数调用创建 `ExecFrame`：

- `func_id`
- `pc`
- `locals`
- `temps`
- `scope_stack`
- `defer_stack`
- `errdefer_stack`
- `return_slot`

性能要求：

- 不应默认给每个 frame 分配完整的 `defer_stack` / `errdefer_stack` / 扩展控制流辅助结构
- frame 元数据应包含快速标志位，例如：
  - `has_defer`
  - `has_errdefer`
  - `may_error_return`
  - `has_indirect_call`
- 对于不使用这些特性的函数，应走更轻的 fast path

### 10.2 作用域

每进入一个 block：

- push 新 scope
- 记录该 scope 声明的局部
- 记录该 scope 注册的 defer / errdefer

离开作用域时：

- 正常路径：运行 `defer`
- 错误路径：先运行 `errdefer`，再运行 `defer`

顺序必须与语言现有语义一致。

性能要求：

- 对无 `defer` / `errdefer` 的 block，不应压入重量级 scope 记录
- 可使用紧凑 scope 记录或静态 metadata + 轻量 cursor，减少每次进入 block 的运行时开销

### 10.3 控制流信号

VM 内部不建议用宿主异常模拟控制流，建议显式使用：

- `FLOW_NORMAL`
- `FLOW_RETURN`
- `FLOW_BREAK`
- `FLOW_CONTINUE`
- `FLOW_ERROR`

这样更贴近 Uya 当前语义，也便于 `defer` 执行。

性能要求：

- 普通直线执行不应为每条指令都走通用“慢速控制流分派”
- 对无异常控制流的 opcode，优先保持紧凑 dispatch；仅在分支、return、错误传播等边界更新 flow 状态

---

## 11. 错误联合、`try`、`catch`

这是第一版必须严肃设计的部分。

### 11.1 表示

`!T` 运行时表示建议为：

- `is_error`
- `error_id`
- `payload`

或压成：

- `tag`
- `payload`

### 11.2 lowering 规则

- `try expr`
  - 求值 `expr`
  - 若为 error，触发当前函数错误返回路径
  - 若为 ok，提取 payload

- `expr catch |err| { ... }`
  - 求值 `expr`
  - 若为 ok，提取 payload
  - 若为 error，将 error 绑定到局部并执行 catch block

### 11.3 返回路径

错误返回必须显式触发：

1. `errdefer`
2. `defer`
3. frame unwind

---

## 12. `defer` / `errdefer` / `drop`

### 12.1 `defer`

lowering 时，每个 `defer` 变成：

- 注册一个延迟动作闭包引用或专用 block id
- 记录所需的捕获值槽位

性能要求：

- 不要求通用闭包对象；若能用 block id + 槽位引用表达，应优先用后者，减少分配和间接调用

### 12.2 `errdefer`

与 `defer` 类似，但只在错误路径执行。

### 12.3 `drop`

`drop` 是完整执行后端最容易被低估的部分。

建议策略：

- checker / lower 阶段产出“离开作用域时哪些局部需要 drop”的显式元数据
- VM 不自己推断是否要 drop，只按元数据执行

也就是说，drop 语义最好前移，不让 VM 动态做所有权分析。

性能要求：

- 不能让 VM 在热路径上做“这个值是否需要 drop”的复杂动态判定
- 对大多数 POD / trivially-droppable 值，应能在 frame metadata 中直接跳过 drop 路径

---

## 13. 函数调用与分发

### 13.1 普通函数

checker 已经知道具体函数定义，bytecode 里直接存 `func_id`。

### 13.2 方法调用

不在 bytecode 层保留“方法”概念。

统一在 lowering 阶段改写成普通调用：

```text
obj.method(a, b) -> Type_method(obj, a, b)
```

### 13.3 泛型函数

执行后端不直接执行“泛型模板”。

要求 checker 已提供：

- 已实例化函数体
- 或可执行的单态化结果

也就是说，bytecode builder 只看**具体实例函数**。

### 13.4 interface / 动态分发

建议在 v1 仍支持，但以最保守方式实现：

- interface value 运行时保存 data ptr + method table ref
- 调用时转成 `CALL_INDIRECT`

这部分不一定要最先完成，但设计上必须预留。

---

## 14. 全局变量与初始化

执行后端必须定义全局初始化顺序。

建议：

- 在 build bytecode 时生成 `global_init_list`
- 程序启动前按模块稳定顺序执行
- 若全局初始化失败，立即终止程序并返回非 0

要避免：

- 依赖宿主 C 静态初始化语义
- 与 C99 backend 用不同顺序，导致行为漂移

---

## 15. builtins 与 hostcall 边界

### 15.1 编译期 builtin

以下 builtin 不进入运行时：

- `@size_of`
- `@align_of`
- 某些纯编译期查询

它们应在 checker / lower 时折叠成常量。

### 15.2 运行期 builtin

以下 builtin 需要桥接：

- `@print`
- `@println`
- `@len`（对动态切片）
- `@error_id`
- `@error_name`
- 部分 `@ptr_from_usize` / `@usize_from_ptr`

### 15.3 extern / libc / hostcall

对于 hosted `run/test`，执行后端应采用“默认走函数体，必要时退到宿主调用”的模型：

- lowering 默认优先把带 body 的 `extern "libc"` / `extern fn` 当普通函数处理
- 只有 extern body 当前不可执行，或明确命中 hostcall override 时，才生成 `HOSTCALL`
- builder 在编译期为每个 hostcall site 注册 `{id, name, arg_count}` 元数据，写入 `BCProgram.host_calls`
- VM 运行时按数值 `host_call_id` 分发宿主调用，不做函数名查找，也不为桥接额外复制整段参数区

第一版边界建议：

- 先支持常见标量参数
- 先支持 `*byte` / `&byte` / `&const byte`
- 聚合值按地址传递
- 复杂 ABI 或 varargs 先禁止，或仅对固定签名的受控场景开放

当前已知需要保留 hostcall 的场景：

- fixed/no-varargs 的 `printf` / `fprintf` / `sprintf` / `snprintf`
- 当前仅对“无函数体 extern stub”或宿主专属符号保留最小 host bridge；`puts` / `atoll` / `llabs` 这类库内已有 Uya body 的 libc 入口已回收到普通 lowering/VM 路径

这一层的长期目标不是扩大函数名白名单，而是随着 lowering/VM 覆盖面提高，持续把可执行的 extern body 收回统一 `CALL` 路径，只把真正的宿主边界留给 `HOSTCALL`。

### 15.4 `@c_import`

`@c_import` 对执行后端是难点。

建议 v1 规则：

- `uya run/test --exec` 遇到 `@c_import` 时，默认报“不支持，回退 C99”
- 后续再评估是否允许：
  - 预编译导入 C 成共享库
  - 执行后端通过 dlsym/ffi 调用

不要在第一版强行吞下这块复杂度。

---

## 16. async / frame / coroutine

完整执行后端最终必须考虑 async，但不建议一开始接入。

设计原则：

- `@async_fn` 不直接在 bytecode VM 里复刻 C99 async lowering
- 先保留接口层：函数可标记 `is_async`
- 后续选择之一：
  - 复用现有 async lowering 思路，生成 frame bytecode
  - 在 HIR 层专门表示 suspend/resume

第一版建议：

- hosted exec backend 遇到 async 先报不支持并回退 C99

---

## 17. 调试与可观测性

执行后端必须从第一天就具备基本可观测性。

建议支持：

- `--dump-exec-hir`
- `--dump-bytecode`
- `--trace-vm`
- 源位置映射
- 运行时 panic/backtrace

最少应做到：

- 报错时能指出 `.uya` 文件、行列、函数名
- 能区分 “lower 失败 / bytecode build 失败 / VM 运行失败”

性能约束：

- `--dump-exec-hir`、`--dump-bytecode`、`--trace-vm` 必须默认关闭
- `BCSourceMap` 应支持按需裁剪；正常执行仅保留错误定位所需的最小映射
- 不能为了默认调试友好而在主路径长期保留大块文本或冗余节点

---

## 18. 与现有命令的集成

### 18.1 CLI 形态

建议新增：

- `uya run --exec file.uya`
- `uya test --exec file.uya`

后续可考虑：

- `UYA_RUN_BACKEND=exec`
- `--backend exec`

### 18.2 默认策略

第一阶段不建议默认替换现有 `run/test`。

建议：

- 显式 opt-in
- 行为稳定后，再考虑：
  - `run/test` 默认先尝试 exec backend
  - 不支持特性自动回退 C99

### 18.3 fallback 规则

需要明确：

- 若 lower 阶段发现未支持语义，应给出稳定原因码
- `run/test` 在允许 fallback 时自动回退到 C99 backend
- `--vm` 模式下则直接失败

---

## 19. 性能预期

按当前统计，若执行后端完全跳过：

- C99 codegen `13169 ms`
- 宿主 gcc/clang 编译与链接

则 `run/test` 理论上能从“十几秒到数十秒”级下降到“数秒级”，主要瓶颈将转为：

- checker
- exec lowering
- VM 执行

第一版即使 VM 还不够快，只要它的 `lower + exec` 显著低于当前 `codegen + gcc`，就已经有很高收益。

### 19.1 第一阶段性能判定标准

第一阶段不以“接近 native 执行速度”为目标，而以“显著降低 `run/test` 总耗时”为目标。

建议用以下标准评估：

- `run/test --exec` 总 wall time 明显低于现有 `run/test`
- `exec lower + bytecode build` 不应重新长成一个新的“13 秒级后端”
- 对无 `defer`、无错误传播、少聚合值的小函数，VM dispatch 开销应保持可控
- 聚合值构造不应成为新的主瓶颈

### 19.2 必须冻结的快速路径约束

以下内容必须在实现前冻结，否则后续很容易出现“语义正确但性能不达标”的情况：

1. HIR 是**短生命周期 IR**，默认按函数释放
2. temps 统计的是**最大活跃数**，不是“曾经分配过多少”
3. 聚合值默认 **in-place build**
4. `defer` / `errdefer` 相关栈结构按需启用，不给所有函数交税
5. 调试产物默认关闭，source map 走最小集

---

## 20. 实现路线

### Phase 1

- checked AST -> HIR
- HIR -> bytecode
- VM 跑纯计算 / 控制流 / 普通函数
- `uya run --exec` 跑 hosted 基础程序

### Phase 2

- `!T`、`try/catch`
- `defer/errdefer`
- struct / array / slice / union
- 全局初始化
- 测试框架接入 `uya test --exec`

### Phase 3

- `extern` / `extern "libc"` 通用执行（带函数体直接 lower，宿主符号最小 bridge）
- varargs extern 的长期策略
- interface / 间接调用
- 更完整标准库支持
- fallback 机制稳定化

### Phase 4

- 性能优化
- 可选 bytecode cache
- 热点函数 profiling
- 可选 JIT

---

## 21. 关键设计结论

本设计的核心结论如下：

1. 当前 `run/test` 最大瓶颈是 **C99 codegen + 宿主 C 编译器**，不是 parser。
2. 最合理的新路径是在 `checker` 之后增加 **exec backend**，而不是重写前端。
3. 不建议直接执行 parser AST；应先 lower 到 **Exec HIR**。
4. 主线执行模型推荐为 **HIR -> bytecode -> VM**，而不是一开始做 native JIT。
5. `run/test` 与 `build` 应分流：`build` 继续走 C99 backend，`run/test` 优先受益于 exec backend。
6. `drop`、`defer`、`!T`、作用域退出语义必须在设计阶段就冻结，不应后补。
7. `@c_import`、async、microapp 不应阻塞第一阶段落地；它们应有明确 fallback 策略。
