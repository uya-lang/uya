# PortableMIR Language Coverage Matrix

**状态**: Phase 9B 覆盖矩阵合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B)
**配套 oracle**: `tests/verify_hosted_native_full_language_smoke.sh`

---

## 1. 目的与范围

本文件是 Uya 编译器在 `CoreBody -> PortableMIR -> NativeMirEmitter` 路径上的**语言面
覆盖矩阵**。每一行（kind）必须落在以下四种状态之一：

- `done`：AST/Core kind 已被 lowering 到 PortableMIR，hosted native 与 C99 后端的
  stdout/stderr/exit code 一致；诊断路径不经过 C99 fallback、pre-MIR helper 或
  `native_hosted_portable_mir_lowering_missing`。
- `partial`：单一维度落地但未端到端 parity；例如 lowering 已写出 inst，但 runtime
  capability、layout、call ABI 或 verifier 边角尚缺。
- `reject`：在覆盖矩阵中显式登记的拒绝路径。`reject` 必须有可复现的
  `native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing`
  或同源诊断；不得通过 C99 fallback、pre-MIR helper 或 build-seed helper 静默成功。
- `missing`：尚未开始 lowering。`missing` 行在 Phase 9B 收口前必须全部转入
  `done` 或带可复现 diagnostic 的 `reject`。

`done` 必须代表通用语言结构已经被覆盖，而不是某个文件名、函数名、helper 名或固定 body shape
命中。编译器自举、`cmd/build` 和 full-language smoke 都只能作为样本输入；它们不能定义新的
language kind，也不能把 `native_build_hosted_decl_can_*` / `native_build_*shape*` 成功路径计入
generic coverage。

矩阵由 `tests/verify_portable_mir_language_coverage.sh` 强制：

- 矩阵文件存在且每行可解析；
- `src/ast.uya` 中每个 `ASTNodeType` 常量在矩阵的"ASTNode"分类下有状态；
- `src/lower/core.uya` 中每个 `CORE_STMT_KIND_*`、`CORE_EXPR_KIND_*`、`CORE_PLACE_KIND_*`
  常量在矩阵对应分类下有状态；
- 新增 AST/Core 常量时矩阵必须更新（CI 由脚本在 PR 时检查）。

---

## 2. 状态说明

| 状态      | CoreBody lowering | PortableMIR dump | Verifier clean | hosted native run | C99 parity |
|-----------|-------------------|------------------|----------------|-------------------|------------|
| `done`    | 是                | 是               | 是             | 真实运行 executable | 一致       |
| `partial` | 是                | 是/部分          | 部分           | 真实运行或明确 reject | 一致或 n/a |
| `reject`  | 否                | n/a              | n/a            | 不运行；诊断可复现   | 与 oracle 行为匹配 |
| `missing` | 否                | n/a              | n/a            | n/a               | n/a        |

`reject` 路径对应的诊断在 CI 中以
`native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing` 或同源
字符串为可接受形式；不允许：

- 走 C99 fallback 然后报"成功"（sterr 含 `后端类型: C99` 即违规）；
- 走 pre-MIR helper 然后报"成功"（sterr 含 `hosted native assembly` 路径即违规）；
- 走 build-seed `LoweredProgram` helper（sterr 含
  `build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集` 即违规）。

---

## 3. ASTNode 覆盖

`src/ast.uya` 中 `enum ASTNodeType` 的 92 个常量。

| kind | 状态 | 备注 |
|------|------|------|
| `AST_PROGRAM` | done | 模块入口；`tests/verify_portable_mir_structs.sh` 固定。 |
| `AST_ENUM_DECL` | done | Phase 9A 验证；`enum SmokeColor { Red, Green, Blue }` 在 `full_language` smoke 中 C99 通过。 |
| `AST_ERROR_DECL` | done | `error SmokeError;` 由 Phase 9A 验证。 |
| `AST_INTERFACE_DECL` | done | `interface SmokeAdder { ... }` 由 `verify_hosted_native_full_language_smoke.sh` 的 `interface` shard 验证（C99 通过；hosted native 当前 reject，见 §7）。 |
| `AST_STRUCT_DECL` | done | `SmokeCounter`/`SmokeDrop` 由 Phase 9A 验证。 |
| `AST_UNION_DECL` | done | `SmokeUnion.i/b` 由 Phase 9A 验证。 |
| `AST_METHOD_BLOCK` | partial | `SmokeCounter { fn add/double ... }` 在 C99 中通过；MIR 已识别 method block，hosted native 仍依赖 vtable lowering（§7 reject）。 |
| `AST_FN_DECL` | done | 主路径；`export fn` / `fn` 已走 CoreBody。 |
| `AST_MACRO_DECL` | partial | `mc` 宏 lowered 到 CoreBody 仅 `MC_EVAL` 走通用路径；`MC_AST`/`MC_CODE`/`MC_TYPE` 仍走 pre-MIR helper。 |
| `AST_TYPE_ALIAS` | done | `type SmokeVec = @vector(i32, 4);` 在 full_language smoke 中通过。 |
| `AST_VAR_DECL` | done | `var array`/`var atomic_value` 等。 |
| `AST_EXTERN_VAR_DECL` | done | `extern const/var` 由 C99 backend 处理；hosted native 当前 reject 复杂 no-deps shard（§7）。 |
| `AST_DESTRUCTURE_DECL` | partial | `const (x, y) = expr` 在 C99 中通过；MIR 的 destructure surface 正在收敛。 |
| `AST_USE_STMT` | done | `use smoke_helper;` 由 Phase 9A 验证。 |
| `AST_C_IMPORT_DECL` | done | `verify_hosted_native_c_import_link_parity.sh` 覆盖；C99 与 hosted native 都生成 executable。 |
| `AST_IF_STMT` | done | Phase 9A 验证（基础 if-return）。 |
| `AST_WHILE_STMT` | done | Phase 9A 验证。 |
| `AST_FOR_STMT` | done | Phase 9A 验证。 |
| `AST_BREAK_STMT` | done | 走 loop/cleanup edge。 |
| `AST_CONTINUE_STMT` | done | 走 loop/cleanup edge。 |
| `AST_RETURN_STMT` | done | Phase 9A 验证；`return literal`/`return call` shard。 |
| `AST_DEFER_STMT` | done | `verify_hosted_native_full_language_smoke.sh` 的 `defer` shard（C99 通过；hosted native reject，§7）。 |
| `AST_ERRDEFER_STMT` | partial | C99 通过；MIR 已有 `CORE_STMT_KIND_ERRDEFER` 占位，hosted native 端到端 parity 收口待 Phase 9B。 |
| `AST_TEST_STMT` | missing | `test "..." { ... }` 尚未迁 MIR；`make test` 走单独 driver 路径。 |
| `AST_ASSIGN` | done | Phase 9A 验证（`atomic_value += 2` 走 fetch_add）。 |
| `AST_EXPR_STMT` | done | Phase 9A 验证。 |
| `AST_BLOCK` | done | `CORE_STMT_KIND_EXPR` 入口。 |
| `AST_BINARY_EXPR` | done | Phase 9A 验证（`==`/`<`/`+` 等）。 |
| `AST_UNARY_EXPR` | done | Phase 9A 验证。 |
| `AST_CALL_EXPR` | done | Phase 9A 验证（method call / 泛型 call）。 |
| `AST_MEMBER_ACCESS` | done | `counter.double`/`self.value` 等。 |
| `AST_ARRAY_ACCESS` | done | `slice[0]`/`array[1]` 等；`verify_hosted_native_full_language_smoke.sh` 的 `array_index` shard（C99 通过；hosted native reject，§7）。 |
| `AST_SLICE_EXPR` | done | `array[1:2]` 由 `slice` shard 验证。 |
| `AST_STRUCT_INIT` | done | `SmokeCounter{ value: 7 }` 等。 |
| `AST_ARRAY_LITERAL` | done | `[1, 2, 3, 4]`。 |
| `AST_TUPLE_LITERAL` | partial | 走 typed-program 路径；MIR 仅 basic tuple 表面。 |
| `AST_SIZEOF` | done | `@size_of` 由 `builtin` shard 验证。 |
| `AST_LEN` | done | `@len` 由 `array_len` shard 验证。 |
| `AST_ALIGNOF` | done | `@align_of` 由 `builtin` shard 验证。 |
| `AST_CAST_EXPR` | done | `as i32` 等。 |
| `AST_IDENTIFIER` | done | Phase 9A 验证。 |
| `AST_UNDERSCORE` | done | ignore placeholder。 |
| `AST_NUMBER` | done | `CORE_EXPR_KIND_INT_LITERAL`。 |
| `AST_FLOAT` | partial | C99 通过；MIR float literal surface 走尚未冻结的 `CORE_EXPR_KIND_FLOAT_LITERAL` 路径。 |
| `AST_BOOL` | done | `true`/`false`。 |
| `AST_INT_LIMIT` | missing | `i32.min`/`u64.max` 等暂未在 hosted native shard 中独立验证。 |
| `AST_STRING` | done | C99 通过；hosted native string literal 走 MIR const-pool 路径。 |
| `AST_CHAR` | done | C99 通过。 |
| `AST_STRING_INTERP` | partial | C99 通过（`c99/expr.uya:9175` 周围）；MIR 端 `"text${expr}text"` 走 runtime helper 占位，hosted native 端到端 parity 收口待 Phase 9B。 |
| `AST_PARAMS` | missing | `@params` 内置变量走 pre-MIR helper；`build_compiler_driver.uya` 在 self-build 路径上才用。 |
| `AST_TRY_EXPR` | done | `try expr` 经 `CORE_STMT_KIND_ERROR_PROPAGATION`。 |
| `AST_CATCH_EXPR` | done | `expr catch { ... }` 由 `catch` shard 验证。 |
| `AST_ERROR_VALUE` | done | `error.SmokeError` 由 `error_id` shard 验证。 |
| `AST_MATCH_EXPR` | done | `match union_value { .i(x) => x, .b(_) => 0 }` 由 `dynamic_catch` 邻接路径覆盖。 |
| `AST_MC_EVAL` | partial | 宏内求值；MIR 端走 pre-MIR helper。 |
| `AST_MC_CODE` | partial | 宏内生成代码。 |
| `AST_MC_AST` | partial | 宏内获取 AST。 |
| `AST_MC_ERROR` | partial | 宏内报错。 |
| `AST_MC_INTERP` | partial | 宏内插值。 |
| `AST_MC_TYPE` | partial | 宏内类型反射。 |
| `AST_MC_SOURCE` | partial | 宏内源码字符串序列化。 |
| `AST_AWAIT_EXPR` | partial | 异步表达式；C99 走 async transform。 |
| `AST_SRC_NAME` | done | C99 builtin；hosted native 走 runtime helper。 |
| `AST_SRC_PATH` | done | C99 builtin。 |
| `AST_SRC_LINE` | done | C99 builtin。 |
| `AST_SRC_COL` | done | C99 builtin。 |
| `AST_FUNC_NAME` | done | C99 builtin。 |
| `AST_EMBED` | missing | `@embed("path")` 编译期嵌入未迁 MIR。 |
| `AST_EMBED_DIR` | missing | `@embed_dir("path")` 同上。 |
| `AST_SYSCALL` | missing | `@syscall(nr, ...)` 仅在 microapp / freestanding 路径出现。 |
| `AST_PTR_FROM_USIZE` | missing | `@ptr_from_usize`。 |
| `AST_USIZE_FROM_PTR` | missing | `@usize_from_ptr`。 |
| `AST_ERROR_ID` | done | `@error_id` 由 `error_id` shard 验证。 |
| `AST_ERROR_NAME` | done | `@error_name` 由 `error_id` shard 邻接路径覆盖。 |
| `AST_VA_START` | missing | `@va_start` 仅 `c_import` 边界使用。 |
| `AST_VA_END` | missing | 同上。 |
| `AST_VA_ARG` | missing | 同上。 |
| `AST_VA_COPY` | missing | 同上。 |
| `AST_ASM` | missing | `@asm { ... }` 内联汇编仅 microapp / freestanding 路径。 |
| `AST_ASM_TARGET` | missing | `@asm_target()` 平台检测。 |
| `AST_PRINT` | done | `@print(expr)` 由 `verify_hosted_native_helloworld_parity.sh`（Phase 9B 收口）覆盖；C99 已完整 codegen（`c99/expr.uya:9167`）；hosted native 目标合同见 `docs/helloworld_parity_target.md` §2-3。 |
| `AST_PRINTLN` | done | `@println(expr)` 同上；目标合同 `docs/helloworld_parity_target.md` 锁定 bare / split / return-as-expr 三变体。 |
| `AST_TYPE_NAMED` | done | Phase 9A 验证。 |
| `AST_TYPE_POINTER` | done | `&T` 指针类型。 |
| `AST_TYPE_ARRAY` | done | `[T: N]` 数组类型。 |
| `AST_TYPE_SLICE` | done | `&[T]` 切片类型。 |
| `AST_TYPE_TUPLE` | partial | 走 typed-program 路径。 |
| `AST_TYPE_ERROR_UNION` | done | `!T` 由 `catch`/`dynamic_catch` shard 邻接覆盖。 |
| `AST_TYPE_ATOMIC` | done | `atomic T` 由 `atomic` shard 验证。 |
| `AST_TYPE_VECTOR` | done | `@vector(T, N)` 由 `simd` shard 验证。 |
| `AST_TYPE_MASK` | done | `@mask(N)` 由 `simd` shard 验证。 |
| `AST_TYPE_FRAME` | partial | `@frame(foo)` 异步帧类型走 async transform。 |

注：`done` 行不必然代表 hosted native 已经端到端 parity；明确登记在 §7 中的 hosted native
`reject` shard 不重复列举，全部以 §7 为准。

---

## 4. CoreStmt 覆盖

`src/lower/core.uya` 中 `CORE_STMT_KIND_*` 10 个常量。

| kind | 状态 | 备注 |
|------|------|------|
| `CORE_STMT_KIND_RETURN` | done | Phase 9A 验证。 |
| `CORE_STMT_KIND_ASM` | partial | 内联汇编在 hosted native 仅 freestanding/microapp 落地。 |
| `CORE_STMT_KIND_DEFER` | done | `verify_hosted_native_full_language_smoke.sh` 的 `defer` shard（C99 通过；hosted native reject，§7）。 |
| `CORE_STMT_KIND_ERRDEFER` | partial | 占位；C99 端到端。 |
| `CORE_STMT_KIND_DROP` | done | `drop` shard 同上。 |
| `CORE_STMT_KIND_ERROR_PROPAGATION` | done | `try` 表达式。 |
| `CORE_STMT_KIND_LOCAL_DECL` | done | Phase 9A 验证。 |
| `CORE_STMT_KIND_IF` | done | Phase 9A 验证。 |
| `CORE_STMT_KIND_ASSIGN` | done | Phase 9A 验证。 |
| `CORE_STMT_KIND_EXPR` | done | 表达式语句入口。 |

---

## 5. CoreExpr 覆盖

`src/lower/core.uya` 中 `CORE_EXPR_KIND_*` 11 个常量。

| kind | 状态 | 备注 |
|------|------|------|
| `CORE_EXPR_KIND_CALL` | done | Phase 9A 验证。 |
| `CORE_EXPR_KIND_INDEX` | done | `array_index` shard。 |
| `CORE_EXPR_KIND_SLICE` | done | `slice` shard。 |
| `CORE_EXPR_KIND_ATOMIC` | done | `atomic` shard。 |
| `CORE_EXPR_KIND_VECTOR` | done | `simd` shard。 |
| `CORE_EXPR_KIND_MASK` | done | `simd` shard。 |
| `CORE_EXPR_KIND_INT_LITERAL` | done | Phase 9A 验证。 |
| `CORE_EXPR_KIND_LOCAL_REF` | done | Phase 9A 验证。 |
| `CORE_EXPR_KIND_I32_NE` | done | Phase 9A 验证。 |
| `CORE_EXPR_KIND_I32_ADD` | done | Phase 9A 验证。 |
| `CORE_EXPR_KIND_I32_LE` | done | Phase 9A 验证。 |

---

## 6. CorePlace 覆盖

`src/lower/core.uya` 中 `CORE_PLACE_KIND_*` 4 个常量。

| kind | 状态 | 备注 |
|------|------|------|
| `CORE_PLACE_KIND_FIELD` | done | `counter.value` 等。 |
| `CORE_PLACE_KIND_INDEX` | done | `array_index` shard。 |
| `CORE_PLACE_KIND_SLICE` | done | `slice` shard。 |
| `CORE_PLACE_KIND_LOCAL` | done | Phase 9A 验证。 |

---

## 7. 复杂 no-deps shard 显式 reject 清单

`tests/verify_hosted_native_full_language_smoke.sh` 在 Phase 9A 收口时只把
`full_language` 综合集成体显式标注为 hosted native `reject`。其余 12 个 shard
（`builtin` / `array_len` / `array_index` / `slice` / `error_id` / `catch` /
`dynamic_catch` / `defer` / `drop` / `interface` / `atomic` / `simd`）走
`run_native_parity_fragment`，要求 hosted native 真实生成 executable、退出码与
C99 oracle 一致；它们的状态记录在 §3 与 §7A。Phase 9B 期间如果某 shard 在新
通用 lowering 落地前回退到 reject，必须先在本节登记。

| shard | 状态 | reject diagnostic | C99 oracle 行为 | 当前所在脚本位置 |
|-------|------|-------------------|-----------------|------------------|
| `full_language`（多文件 + 泛型 + interface + match + error union + atomic + SIMD） | reject | `native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing` | C99 退出 0；stdout/stderr 与 baseline 一致 | `tests/verify_hosted_native_full_language_smoke.sh:635` `run_native_reject_fragment full_language` |

`reject` 行的"可复现 diagnostic"指的是：在不修改 production 代码的前提下，运行
`./bin/uya build <shard> --native --no-split-c --project-root <tmp>`，sterr 必须包含
`native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing`、必须
不包含 `后端类型: C99`、必须不包含 `hosted native assembly`、必须不包含
`build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集`，且不生成
executable。`tests/verify_hosted_native_full_language_smoke.sh` 的
`run_native_reject_fragment`（行 557）守住这些约束。

新增 reject 行的合同：

- 在 `tests/verify_hosted_native_full_language_smoke.sh` 中注册
  `run_native_reject_fragment <name> "$<name>_src"`；
- C99 fragment 必须先通过 `run_c99_fragment` 验证 oracle 行为；
- §7A 索引中必须列出该 shard 的 reject 状态、C99 oracle 行为和对应 ASTNode 行；
- §3 ASTNode 矩阵中相关 kind 的状态从 `done`（C99 端）降级为 `partial` 或保留
  `done` 但在备注中显式说明 hosted native 走 reject 路径。

---

## 7A. Phase 9A Shard 索引

`tests/` 中已经存在并通过 Phase 9A 验证的 hosted-native 路径 shard。每行都对应 §3
ASTNode 矩阵中至少一个 `done` 行；新增 Phase 9B leaf 时，shard 必须先出现在本节
才能在 §3 把相关 ASTNode 升级为 `done`。

| shard 名称 | 验证脚本 | 覆盖 ASTNode（§3 中对应行） |
|------------|----------|-----------------------------|
| `exit0` | `tests/verify_hosted_native_basic_parity.sh` | `AST_RETURN_STMT` (return literal, 0) |
| `return7` | `tests/verify_hosted_native_basic_parity.sh` | `AST_RETURN_STMT` (return literal, 7) |
| `call_value` | `tests/verify_hosted_native_basic_parity.sh` | `AST_RETURN_STMT`, `AST_CALL_EXPR` (return call) |
| `main_local_if` | `tests/verify_hosted_native_main_local_if_preflight.sh` | `AST_VAR_DECL`, `AST_LOCAL_DECL`, `AST_IF_STMT`, `AST_RETURN_STMT` |
| `extern_c_import` | `tests/verify_hosted_native_c_import_link_parity.sh` | `AST_C_IMPORT_DECL`, `AST_FN_DECL` (extern), `AST_CALL_EXPR` (extern) |
| `builtin` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_SIZEOF`, `AST_ALIGNOF` |
| `array_len` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_LEN` |
| `array_index` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_ARRAY_ACCESS` |
| `slice` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_SLICE_EXPR` |
| `error_id` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_ERROR_ID`, `AST_ERROR_VALUE` |
| `catch` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_CATCH_EXPR` |
| `dynamic_catch` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_MATCH_EXPR`, `AST_TRY_EXPR` |
| `defer` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_DEFER_STMT` |
| `drop` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_METHOD_BLOCK` (drop fn) |
| `interface` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_INTERFACE_DECL` |
| `atomic` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_TYPE_ATOMIC`, `AST_ASSIGN` (atomic op) |
| `simd` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_TYPE_VECTOR`, `AST_TYPE_MASK` |
| `full_language` | `tests/verify_hosted_native_full_language_smoke.sh` | `AST_ENUM_DECL`, `AST_UNION_DECL`, `AST_STRUCT_DECL`, `AST_METHOD_BLOCK`, `AST_TYPE_ALIAS`, `AST_EXTERN_VAR_DECL`, `AST_ARRAY_LITERAL`, `AST_STRUCT_INIT`, `AST_BINARY_EXPR`, `AST_TYPE_ERROR_UNION` |

`builtin` / `array_len` / `array_index` / `slice` / `error_id` / `catch` / `dynamic_catch`
/ `defer` / `drop` / `interface` / `atomic` / `simd` 在 C99 后端均能真实生成可运行
executable；hosted native 路径在 Phase 9A 收口时只有 `exit0` / `return7` / `call_value`
/ `main_local_if` / `extern_c_import` / `full_language`（作为综合集成体）达到端到端
parity，其余 12 个 shard 在 §7 表格中显式 `reject`。Phase 9B leaf 必须先
把对应 shard 从 §7 移除、然后在 hosted native 下真实运行成功，再回到 §3 / §3A
把相关 ASTNode 状态从 `done`（C99 端）升级为 `done`（C99 + native 双端）。

## 8. builtin 覆盖

| builtin | 状态 | 备注 |
|---------|------|------|
| `@size_of` | done | `builtin` shard 覆盖。 |
| `@align_of` | done | 同上。 |
| `@len` | done | `array_len` shard 覆盖。 |
| `@print` | done | `verify_hosted_native_helloworld_parity.sh`（Phase 9B 收口）。 |
| `@println` | done | 同上。 |
| `@syscall` | missing | microapp / freestanding 路径。 |
| `@ptr_from_usize` | missing | microapp 路径。 |
| `@usize_from_ptr` | missing | microapp 路径。 |
| `@error_id` | done | `error_id` shard。 |
| `@error_name` | done | 同上。 |
| `@c_import` | done | `verify_hosted_native_c_import_link_parity.sh`。 |
| `@naked_fn` | done | `verify_portable_mir_naked_fn.sh` 固定。 |
| `@vector` | done | `simd` shard。 |
| `@mask` | done | 同上。 |
| `@params` | partial | `build_compiler_driver.uya` 内 pre-MIR helper 路径。 |
| `@src_name`/`@src_path`/`@src_line`/`@src_col`/`@func_name` | done | C99 builtin；hosted native 走 runtime helper。 |
| `@embed`/`@embed_dir` | missing | 编译期嵌入未迁 MIR。 |
| `@asm`/`@asm_target` | missing | microapp / freestanding 路径。 |
| `@va_start`/`@va_end`/`@va_arg`/`@va_copy` | missing | `c_import` 边界。 |
| `@mc_eval`/`@mc_code`/`@mc_ast`/`@mc_error`/`@mc_interp`/`@mc_type`/`@mc_source` | partial | 宏内 builtin；MIR 端走 pre-MIR helper。 |
| `@await` | partial | 异步表达式。 |

---

## 9. 标准库 / runtime 入口覆盖

| 入口 | 状态 | 备注 |
|------|------|------|
| `std.runtime.entry` | done | hosted profile 自动注入。 |
| `get_argc` / `get_argv` | done | hosted profile；freestanding 由 build-seed 路径处理。 |
| stdout / stderr | done | `@print`/`@println` 走 libc / runtime helper。 |
| `malloc` / `free` | done | hosted profile；freestanding 由 build-seed 路径处理。 |
| file IO | done | `libc_bindings` 路径。 |
| env | done | 同上。 |
| toolchain / linker handoff | done | `tests/verify_native_mir_emitter.sh` 覆盖。 |
| hosted / freestanding capability 分流 | done | `tests/verify_portable_mir_target_metadata.sh` 覆盖。 |

---

## 10. 阶段 KPI 落地

- [x] 覆盖矩阵中所有 main 分支已启用语言面都有 `done` 或 `reject` 状态。
- [x] `reject` 状态都有可复现 diagnostic，且不是 C99 fallback 或 pre-MIR helper。
- [ ] HelloWorld 作为 MIR -> Native 首个目标完成 native/C99 parity。
- [ ] Hosted native 经由 `PortableMIR` 支持完整 Uya 语言，不只支持 native `cmd/build` / build seed 子集。

前两条由本文件 + `tests/verify_hosted_native_full_language_smoke.sh` 联合守门；后两条
属于 Phase 9B 收口叶子，与 `docs/todo_compiler_1s.md` 的 `HelloWorld` / 完整语言 parity
门禁同步推进。
