# PortableMIR Language Coverage Matrix

**状态**: Phase 9B 覆盖矩阵合同
**更新日期**: 2026-06-12
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B)
**MIR-C99 TODO**: `docs/todo_mir_c99_backend.md`
**MIR-C99 parity harness**: 待新增；当前以现有 C99 backend 作为行为 oracle

---

## 1. 目的与范围

本文件是 Uya 编译器在 `CoreBody -> PortableMIR` 及其后端消费路径上的**语言面覆盖矩阵**。
当前表格的 `状态` 列只描述 Core/PortableMIR 语言面覆盖；`MIR-C99 状态` 列描述独立
`PortableMIR -> MirC99Plan -> MirC99Emitter` 后端的 per-kind 支持状态。两列不能互相替代。
MIR-C99 的目标口径是：普通 Uya 程序经 `CoreBody -> PortableMIR -> MirC99Plan -> MirC99Emitter`
生成 host C99 compiler 可编译运行的产物，并与现有 C99 oracle 行为一致。直到新增独立
`src/codegen/mir_c99/` 后端和专用 parity harness 前，MIR-C99 全局状态和 per-kind 状态均为
`missing`。

每一行（kind）的 Core/PortableMIR 状态必须落在以下四种状态之一：

- `done`：AST/Core kind 已被 lowering 到 PortableMIR，并有 MIR dump/verifier 或 C99 oracle 证据。
- `partial`：单一维度落地但未端到端 parity；例如 lowering 已写出 inst，但 runtime
  capability、layout、call ABI 或 verifier 边角尚缺。
- `reject`：在覆盖矩阵中显式登记的拒绝路径。`reject` 必须有可复现的
  MIR-C99 capability / lowering diagnostic；不得通过现有 C99 fallback、pre-MIR helper 或
  helper-specific path 静默成功。
- `missing`：尚未开始 lowering。`missing` 行在 Phase 9B 收口前必须全部转入
  `done` 或带可复现 diagnostic 的 `reject`。

`done` 必须代表对应口径下的通用语言结构已经被覆盖，而不是某个文件名、函数名、helper 名或固定
body shape 命中。编译器自举、`cmd/build` 和 full-language smoke 都只能作为样本输入；它们不能定义新的
language kind。当前文件中历史 `done` 行若只来自现有 C99 oracle，不能作为 MIR-C99 done 证据；
MIR-C99 状态以 §2.1 和 `docs/todo_mir_c99_backend.md` 的详细任务列表为准。

矩阵由 `tests/verify_portable_mir_language_coverage.sh` 强制：

- 矩阵文件存在且每行可解析；
- `src/ast.uya` 中每个 `ASTNodeType` 常量在矩阵的"ASTNode"分类下有状态；
- `src/lower/core.uya` 中每个 `CORE_STMT_KIND_*`、`CORE_EXPR_KIND_*`、`CORE_PLACE_KIND_*`
  常量在矩阵对应分类下有状态；
- AST/Core kind 行必须同时带有合法的 `MIR-C99 状态`；
- 新增 AST/Core 常量时矩阵必须更新（CI 由脚本在 PR 时检查）。

---

## 2. 状态说明

| 状态      | CoreBody lowering | PortableMIR dump | Verifier clean | MIR-C99 parity |
|-----------|-------------------|------------------|----------------|----------------|
| `done`    | 是                | 是               | 是             | 待 MIR-C99 列确认 |
| `partial` | 是                | 是/部分          | 部分           | 待补 |
| `reject`  | 否                | n/a              | n/a            | 诊断可复现 |
| `missing` | 否                | n/a              | n/a            | n/a |

`reject` 路径对应的诊断必须来自 MIR-C99 capability / lowering gate；不允许走现有 C99 fallback、
pre-MIR helper 或 helper-specific path 后报"成功"。

### 2.1 MIR-C99 全局状态

| 范围 | MIR-C99 状态 | 证据 / 下一步 |
|------|--------------|---------------|
| 独立后端目录 `src/codegen/mir_c99/` | missing | 尚未建立 `MirC99Plan` / `MirC99Unit` / `MirC99Emitter` / driver。 |
| 后端接线 `MIR_TARGET_BACKEND_C99` | partial | 目前只有 `src/lower/mir_backend.uya` 的 backend kind / `c99_plan: &void` 占位。 |
| HelloWorld MIR-C99 parity | missing | 需新增专用 harness，经 host C99 compiler 编译运行并与现有 C99 oracle 比对。 |
| 完整语言 MIR-C99 parity | missing | 需覆盖 `tests/verify_full_language_backend_parity.sh`、`make check` 主语言面和 async 回归。 |
| MIR-C99 self-build | missing | 需 MIR-C99-built compiler 复跑 self-build、compiler regression 和 C99 output parity。 |

---

## 3. ASTNode 覆盖

`src/ast.uya` 中 `enum ASTNodeType` 的 92 个常量。

| kind | 状态 | MIR-C99 状态 | 备注 |
|------|------|---------------|------|
| `AST_PROGRAM` | done | missing | 模块入口；`tests/verify_portable_mir_structs.sh` 固定。 |
| `AST_ENUM_DECL` | done | partial | MIR-C99 full-language enum parity shard 覆盖 enum tag、显式/自动值、比较、cast 和 enum match arms。 |
| `AST_ERROR_DECL` | done | missing | `error SmokeError;` 由 Phase 9A 验证。 |
| `AST_INTERFACE_DECL` | done | partial | MIR-C99 full-language interface dispatch parity shard 覆盖基础 interface value + vtable method dispatch；generic interface parity shard 覆盖 `Scorer<i32>` / `Scorer<f64>` concrete interface instances；interface composition/field/global init parity shard 覆盖组合接口、接口字段和全局接口初始化。 |
| `AST_STRUCT_DECL` | done | partial | MIR-C99 full-language struct parity shard 覆盖 struct literal、field access 和 method-style aggregate call；generic struct parity shard 覆盖 `Box<T>` 的 i32/f64 concrete instances；generic method parity shard 覆盖 `Box<T>` concrete method instances；interface dispatch parity shard 覆盖 `Counter : IAdd` concrete implementation；generic interface parity shard 覆盖 `IntScorer : Scorer<i32>` 与 `FloatScorer : Scorer<f64>` concrete implementations；interface composition/field/global init parity shard 覆盖带 interface 字段的 struct 和全局 aggregate initializer。 |
| `AST_UNION_DECL` | done | partial | MIR-C99 full-language union parity shard 覆盖 tagged union layout、构造和 payload match 解包。 |
| `AST_METHOD_BLOCK` | partial | partial | MIR-C99 full-language struct parity shard 覆盖 method-style aggregate call；generic method parity shard 覆盖 owner 泛型实参和方法泛型实参的 concrete method calls；interface dispatch parity shard 覆盖基础 vtable method lowering；generic interface parity shard 覆盖泛型 interface concrete vtable method lowering；interface composition/field/global init parity shard 覆盖组合接口的 read/write/flush vtable method lowering。 |
| `AST_FN_DECL` | done | missing | 主路径；`export fn` / `fn` 已走 CoreBody。 |
| `AST_MACRO_DECL` | partial | missing | `mc` 宏 lowered 到 CoreBody 仅 `MC_EVAL` 走通用路径；`MC_AST`/`MC_CODE`/`MC_TYPE` 仍走 pre-MIR helper。 |
| `AST_TYPE_ALIAS` | done | missing | `type SmokeVec = @vector(i32, 4);` 在 full_language smoke 中通过。 |
| `AST_VAR_DECL` | done | partial | MIR-C99 interface composition/field/global init parity shard 覆盖全局 `const` aggregate initializer 内的 interface value 初始化；`var array`/`var atomic_value` 等仍待专用 shard。 |
| `AST_EXTERN_VAR_DECL` | done | partial | MIR-C99 已支持 extern global plan/output 的 declaration-only 路径；extern global parity 待后续 shard。 |
| `AST_DESTRUCTURE_DECL` | partial | missing | `const (x, y) = expr` 在 C99 中通过；MIR 的 destructure surface 正在收敛。 |
| `AST_USE_STMT` | done | partial | MIR-C99 full-language multi-file module item use parity shard 覆盖跨文件 item import；whole-module alias parity 待补。 |
| `AST_C_IMPORT_DECL` | done | partial | MIR-C99 已保留 @c_import object/library/search path link plan；sidecar object parity 待补。 |
| `AST_IF_STMT` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖基础和嵌套 branch；break/continue cleanup edge 待补。 |
| `AST_WHILE_STMT` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 loop backedge；break/continue 待补。 |
| `AST_FOR_STMT` | done | missing | Phase 9A 验证。 |
| `AST_BREAK_STMT` | done | missing | 走 loop/cleanup edge。 |
| `AST_CONTINUE_STMT` | done | missing | 走 loop/cleanup edge。 |
| `AST_RETURN_STMT` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 literal/local/binary result return；aggregate/error returns 由后续 shard 覆盖。 |
| `AST_DEFER_STMT` | done | missing | C99 oracle 已覆盖；MIR cleanup edge 到 MIR-C99 parity 待补。 |
| `AST_ERRDEFER_STMT` | partial | missing | C99 通过；MIR 已有 `CORE_STMT_KIND_ERRDEFER` 占位，MIR-C99 cleanup parity 待补。 |
| `AST_TEST_STMT` | missing | missing | `test "..." { ... }` 尚未迁 MIR；`make test` 走单独 driver 路径。 |
| `AST_ASSIGN` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 scalar local assign；atomic/aggregate assign 由专用 shard 覆盖。 |
| `AST_EXPR_STMT` | done | missing | Phase 9A 验证。 |
| `AST_BLOCK` | done | missing | `CORE_STMT_KIND_EXPR` 入口。 |
| `AST_BINARY_EXPR` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 scalar arithmetic/comparison in branch/loop；完整类型矩阵待后续 shard。 |
| `AST_UNARY_EXPR` | done | partial | MIR-C99 full-language pointer parity shard 覆盖 `&local` 取地址和 `*ptr` 解引用 load/store；其他一元运算由后续 shard 覆盖。 |
| `AST_CALL_EXPR` | done | partial | MIR-C99 full-language float/double call ABI parity shard 覆盖 local float call 和 extern C float/double call，struct parity shard 覆盖 method-style aggregate call；generic function parity shard 覆盖 i32/f64 concrete function instances；generic method parity shard 覆盖 `Box<T>.make/get` 和 `tag_with<U>` concrete calls；interface dispatch parity shard 覆盖基础 vtable interface call；generic interface parity shard 覆盖 generic interface concrete vtable calls；interface composition/field/global init parity shard 覆盖组合接口字段上的 vtable calls。 |
| `AST_MEMBER_ACCESS` | done | partial | MIR-C99 full-language struct parity shard 覆盖 struct field access 和 method member call；generic struct parity shard 覆盖 generic struct field access；generic method parity shard 覆盖 concrete generic owner/member method access；union parity shard 覆盖 payload field access；tuple parity shard 覆盖 `.0/.1` numeric member access；interface composition/field/global init parity shard 覆盖 interface 字段 member access。 |
| `AST_ARRAY_ACCESS` | done | partial | MIR-C99 full-language array parity shard 覆盖 array index load/store；slice shard 覆盖 slice index load。 |
| `AST_SLICE_EXPR` | done | partial | MIR-C99 full-language slice parity shard 覆盖 array-to-slice 和 slice-to-slice 表达式。 |
| `AST_STRUCT_INIT` | done | partial | MIR-C99 full-language struct parity shard 覆盖 struct literal 初始化；generic struct parity shard 覆盖 `Box<T>` concrete init；interface composition/field/global init parity shard 覆盖含 interface value 字段的全局 struct initializer。 |
| `AST_ARRAY_LITERAL` | done | partial | MIR-C99 full-language array parity shard 覆盖 `[i32: N]` 字面量和空数组初始化。 |
| `AST_TUPLE_LITERAL` | partial | partial | MIR-C99 full-language tuple parity shard 覆盖 `(i32, i32)` 字面量、`.0/.1` numeric member access 和由 tuple field 构造新 tuple。 |
| `AST_SIZEOF` | done | missing | `@size_of` 由 `builtin` shard 验证。 |
| `AST_LEN` | done | missing | `@len` 由 `array_len` shard 验证。 |
| `AST_ALIGNOF` | done | missing | `@align_of` 由 `builtin` shard 验证。 |
| `AST_CAST_EXPR` | done | partial | MIR-C99 full-language float/double parity shard 覆盖 f32/f64 widen 和 float-to-int cast；完整 cast 矩阵由后续 shard 覆盖。 |
| `AST_IDENTIFIER` | done | missing | Phase 9A 验证。 |
| `AST_UNDERSCORE` | done | missing | ignore placeholder。 |
| `AST_NUMBER` | done | missing | `CORE_EXPR_KIND_INT_LITERAL`。 |
| `AST_FLOAT` | partial | partial | MIR-C99 full-language float/double parity shard 覆盖 f32/f64 literal、arithmetic、comparison 和 cast；非零 literal payload 的完整 MIR 常量模型仍按后续 value-plan 收敛。 |
| `AST_BOOL` | done | missing | `true`/`false`。 |
| `AST_INT_LIMIT` | missing | missing | `i32.min`/`u64.max` 等暂未在 MIR-C99 shard 中独立验证。 |
| `AST_STRING` | done | partial | MIR-C99 已支持 string global initializer plan/output 和 dedupe id；完整字符串 parity 待后续 shard。 |
| `AST_CHAR` | done | missing | C99 通过。 |
| `AST_STRING_INTERP` | partial | missing | C99 通过（`c99/expr.uya:9175` 周围）；MIR 端 `"text${expr}text"` 走 runtime helper 占位，MIR-C99 parity 待补。 |
| `AST_PARAMS` | missing | missing | `@params` 内置变量走 pre-MIR helper；`build_compiler_driver.uya` 在 self-build 路径上才用。 |
| `AST_TRY_EXPR` | done | missing | `try expr` 经 `CORE_STMT_KIND_ERROR_PROPAGATION`。 |
| `AST_CATCH_EXPR` | done | missing | `expr catch { ... }` 由 `catch` shard 验证。 |
| `AST_ERROR_VALUE` | done | missing | `error.SmokeError` 由 `error_id` shard 验证。 |
| `AST_MATCH_EXPR` | done | partial | MIR-C99 full-language union parity shard 覆盖 `match union_value { .number(x) => x, .payload(p) => p.left + p.right }`。 |
| `AST_MC_EVAL` | partial | missing | 宏内求值；MIR 端走 pre-MIR helper。 |
| `AST_MC_CODE` | partial | missing | 宏内生成代码。 |
| `AST_MC_AST` | partial | missing | 宏内获取 AST。 |
| `AST_MC_ERROR` | partial | missing | 宏内报错。 |
| `AST_MC_INTERP` | partial | missing | 宏内插值。 |
| `AST_MC_TYPE` | partial | missing | 宏内类型反射。 |
| `AST_MC_SOURCE` | partial | missing | 宏内源码字符串序列化。 |
| `AST_AWAIT_EXPR` | partial | missing | 异步表达式；C99 走 async transform。 |
| `AST_SRC_NAME` | done | missing | C99 builtin；MIR-C99 runtime helper parity 待补。 |
| `AST_SRC_PATH` | done | missing | C99 builtin。 |
| `AST_SRC_LINE` | done | missing | C99 builtin。 |
| `AST_SRC_COL` | done | missing | C99 builtin。 |
| `AST_FUNC_NAME` | done | missing | C99 builtin。 |
| `AST_EMBED` | missing | missing | `@embed("path")` 编译期嵌入未迁 MIR。 |
| `AST_EMBED_DIR` | missing | missing | `@embed_dir("path")` 同上。 |
| `AST_SYSCALL` | missing | missing | `@syscall(nr, ...)` 需要 capability diagnostic 和 MIR-C99 parity/reject 记录。 |
| `AST_PTR_FROM_USIZE` | missing | missing | `@ptr_from_usize`。 |
| `AST_USIZE_FROM_PTR` | missing | missing | `@usize_from_ptr`。 |
| `AST_ERROR_ID` | done | missing | `@error_id` 由 `error_id` shard 验证。 |
| `AST_ERROR_NAME` | done | missing | `@error_name` 由 `error_id` shard 邻接路径覆盖。 |
| `AST_VA_START` | missing | missing | `@va_start` 仅 `c_import` 边界使用。 |
| `AST_VA_END` | missing | missing | 同上。 |
| `AST_VA_ARG` | missing | missing | 同上。 |
| `AST_VA_COPY` | missing | missing | 同上。 |
| `AST_ASM` | missing | missing | `@asm { ... }` 需要 capability diagnostic 和 MIR-C99 reject 记录。 |
| `AST_ASM_TARGET` | missing | missing | `@asm_target()` 平台检测。 |
| `AST_PRINT` | done | missing | `@print(expr)` C99 已完整 codegen（`c99/expr.uya:9167`）；MIR-C99 HelloWorld parity 待补。 |
| `AST_PRINTLN` | done | missing | `@println(expr)` 同上；目标合同 `docs/helloworld_parity_target.md` 锁定 bare / split / return-as-expr 三变体。 |
| `AST_TYPE_NAMED` | done | missing | Phase 9A 验证。 |
| `AST_TYPE_POINTER` | done | partial | MIR-C99 full-language pointer parity shard 覆盖 `&i32` 指针类型、取地址、解引用读写和指针别名。 |
| `AST_TYPE_ARRAY` | done | missing | `[T: N]` 数组类型。 |
| `AST_TYPE_SLICE` | done | partial | MIR-C99 full-language slice parity shard 覆盖 `&[i32]` 切片类型。 |
| `AST_TYPE_TUPLE` | partial | missing | 走 typed-program 路径。 |
| `AST_TYPE_ERROR_UNION` | done | missing | `!T` 由 `catch`/`dynamic_catch` shard 邻接覆盖。 |
| `AST_TYPE_ATOMIC` | done | missing | `atomic T` 由 `atomic` shard 验证。 |
| `AST_TYPE_VECTOR` | done | missing | `@vector(T, N)` 由 `simd` shard 验证。 |
| `AST_TYPE_MASK` | done | missing | `@mask(N)` 由 `simd` shard 验证。 |
| `AST_TYPE_FRAME` | partial | missing | `@frame(foo)` 异步帧类型走 async transform。 |

注：`done` 行不必然代表 MIR-C99 已经端到端 parity；MIR-C99 状态以 §2.1 和 TODO 详细任务列表为准。

---

## 4. CoreStmt 覆盖

`src/lower/core.uya` 中 `CORE_STMT_KIND_*` 11 个常量。

| kind | 状态 | MIR-C99 状态 | 备注 |
|------|------|---------------|------|
| `CORE_STMT_KIND_RETURN` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 scalar return。 |
| `CORE_STMT_KIND_ASM` | partial | missing | 内联汇编需要 capability diagnostic 和 MIR-C99 reject 记录。 |
| `CORE_STMT_KIND_DEFER` | done | missing | C99 oracle 已覆盖；MIR-C99 cleanup parity 待补。 |
| `CORE_STMT_KIND_ERRDEFER` | partial | missing | 占位；C99 端到端。 |
| `CORE_STMT_KIND_DROP` | done | missing | `drop` shard 同上。 |
| `CORE_STMT_KIND_ERROR_PROPAGATION` | done | missing | `try` 表达式。 |
| `CORE_STMT_KIND_LOCAL_DECL` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 scalar local declaration。 |
| `CORE_STMT_KIND_IF` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖基础和嵌套 branch。 |
| `CORE_STMT_KIND_ASSIGN` | done | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 scalar local assignment。 |
| `CORE_STMT_KIND_EXPR` | done | missing | 表达式语句入口。 |
| `CORE_STMT_KIND_WHILE` | partial | partial | MIR-C99 full-language return/local/binary/branch/loop parity shard 覆盖 loop backedge；break/continue 和复杂 cleanup edge 待补。 |

---

## 5. CoreExpr 覆盖

`src/lower/core.uya` 中 `CORE_EXPR_KIND_*` 11 个常量。

| kind | 状态 | MIR-C99 状态 | 备注 |
|------|------|---------------|------|
| `CORE_EXPR_KIND_CALL` | done | partial | MIR-C99 full-language float/double call ABI parity shard 覆盖 local call 和 extern C call，struct parity shard 覆盖 method-style aggregate call；generic function parity shard 覆盖 i32/f64 concrete function instances；generic method parity shard 覆盖 owner/method 泛型 concrete calls；interface dispatch parity shard 覆盖基础 vtable interface call；generic interface parity shard 覆盖 concrete generic interface vtable calls；interface composition/field/global init parity shard 覆盖组合接口字段上的 concrete vtable calls。 |
| `CORE_EXPR_KIND_INDEX` | done | missing | `array_index` shard。 |
| `CORE_EXPR_KIND_SLICE` | done | partial | MIR-C99 full-language slice parity shard 覆盖 array-to-slice 和 slice-to-slice lowering。 |
| `CORE_EXPR_KIND_ATOMIC` | done | missing | `atomic` shard。 |
| `CORE_EXPR_KIND_VECTOR` | done | missing | `simd` shard。 |
| `CORE_EXPR_KIND_MASK` | done | missing | `simd` shard。 |
| `CORE_EXPR_KIND_INT_LITERAL` | done | missing | Phase 9A 验证。 |
| `CORE_EXPR_KIND_LOCAL_REF` | done | missing | Phase 9A 验证。 |
| `CORE_EXPR_KIND_I32_NE` | done | missing | Phase 9A 验证。 |
| `CORE_EXPR_KIND_I32_ADD` | done | missing | Phase 9A 验证。 |
| `CORE_EXPR_KIND_I32_LE` | done | missing | Phase 9A 验证。 |

---

## 6. CorePlace 覆盖

`src/lower/core.uya` 中 `CORE_PLACE_KIND_*` 4 个常量。

| kind | 状态 | MIR-C99 状态 | 备注 |
|------|------|---------------|------|
| `CORE_PLACE_KIND_FIELD` | done | partial | MIR-C99 full-language struct parity shard 覆盖 struct field load/store；generic struct parity shard 覆盖 generic struct field load；union parity shard 覆盖 match payload field load；tuple parity shard 覆盖 tuple numeric member load；interface composition/field/global init parity shard 覆盖 interface 字段 load 和 offset 字段 load。 |
| `CORE_PLACE_KIND_INDEX` | done | partial | MIR-C99 full-language array parity shard 覆盖 array index load/store；slice shard 覆盖 slice index load。 |
| `CORE_PLACE_KIND_SLICE` | done | partial | MIR-C99 full-language slice parity shard 覆盖 slice place 构造。 |
| `CORE_PLACE_KIND_LOCAL` | done | partial | MIR-C99 full-language pointer parity shard 覆盖 local address-of 和经 local pointer 的 deref load/store。 |

---

## 8. builtin 覆盖

| builtin | 状态 | MIR-C99 状态 | 备注 |
|---------|------|---------------|------|
| `@size_of` | done | missing | `builtin` shard 覆盖。 |
| `@align_of` | done | missing | 同上。 |
| `@len` | done | missing | `array_len` shard 覆盖。 |
| `@print` | done | missing | MIR-C99 HelloWorld parity 待补。 |
| `@println` | done | missing | 同上。 |
| `@syscall` | missing | missing | capability diagnostic 和 MIR-C99 parity/reject 待补。 |
| `@ptr_from_usize` | missing | missing | microapp 路径。 |
| `@usize_from_ptr` | missing | missing | microapp 路径。 |
| `@error_id` | done | missing | `error_id` shard。 |
| `@error_name` | done | missing | 同上。 |
| `@c_import` | done | partial | MIR-C99 已保留 @c_import object/library/search path link plan；最小 @c_import parity 待补。 |
| `@naked_fn` | done | missing | `verify_portable_mir_naked_fn.sh` 固定。 |
| `@vector` | done | missing | `simd` shard。 |
| `@mask` | done | missing | 同上。 |
| `@params` | partial | missing | `build_compiler_driver.uya` 内 pre-MIR helper 路径。 |
| `@src_name`/`@src_path`/`@src_line`/`@src_col`/`@func_name` | done | missing | C99 builtin；MIR-C99 runtime helper parity 待补。 |
| `@embed`/`@embed_dir` | missing | missing | 编译期嵌入未迁 MIR。 |
| `@asm`/`@asm_target` | missing | missing | capability diagnostic 和 MIR-C99 reject 待补。 |
| `@va_start`/`@va_end`/`@va_arg`/`@va_copy` | missing | missing | `c_import` 边界。 |
| `@mc_eval`/`@mc_code`/`@mc_ast`/`@mc_error`/`@mc_interp`/`@mc_type`/`@mc_source` | partial | missing | 宏内 builtin；MIR 端走 pre-MIR helper。 |
| `@await` | partial | missing | 异步表达式。 |

---

## 9. 标准库 / runtime 入口覆盖

| 入口 | 状态 | MIR-C99 状态 | 备注 |
|------|------|---------------|------|
| `std.runtime.entry` | done | missing | runtime entry 自动注入；MIR-C99 parity 待补。 |
| `get_argc` / `get_argv` | done | missing | C99 oracle 已覆盖；MIR-C99 runtime helper parity 待补。 |
| stdout / stderr | done | missing | `@print`/`@println` 走 libc / runtime helper。 |
| `malloc` / `free` | done | missing | C99 oracle 已覆盖；MIR-C99 runtime helper parity 待补。 |
| file IO | done | missing | `libc_bindings` 路径。 |
| env | done | missing | 同上。 |
| toolchain / linker handoff | done | missing | MIR-C99 link plan parity 待补。 |
| capability 分流 | done | missing | `tests/verify_portable_mir_target_metadata.sh` 覆盖。 |

---

## 10. 阶段 KPI 落地

- [x] Core/PortableMIR 状态矩阵覆盖 `src/ast.uya` 和 `src/lower/core.uya` 中的现有 kind。
- [x] 覆盖矩阵新增 MIR-C99 per-kind 状态列，区分 `missing` / `partial` / `done` / `reject`。
- [ ] HelloWorld 作为 MIR-C99 首个目标完成 MIR-C99 / 现有 C99 oracle parity。
- [ ] MIR-C99 经由 `PortableMIR` 支持完整 Uya 语言，不只支持 launcher / `cmd/build` / fixed-shape smoke。

第一条由本文件 + `tests/verify_portable_mir_language_coverage.sh` 守门；其余条目属于
`docs/todo_mir_c99_backend.md` 的详细任务列表和 Phase 9B 收口门禁。
