# Expressions Group Lowering Contract

**状态**: Phase 9B expressions 迁移组合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, leaf "expressions")
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §5 (CoreExpr)
**配套 statements contract**: `docs/statements_lowering_contract.md`

---

## 1. 范围

本文件定义 `CoreExprKind` 中所有 expression 形态（11 个常量 + 字符串字面量
扩展）的通用 CoreBody → PortableMIR lowering 合同，涵盖：

- literal（int / bool / float / string / interp）
- identifier / local / global load
- binary / unary
- logical short-circuit（`&&` / `||`）
- call / method call
- field access / index / slice
- cast / as
- address-of / dereference
- enum / union / error construction
- struct / array / slice literal
- string literal / string interpolation
- builtin expression（`@len` / `@size_of` / `@align_of` / `@error_id` /
  `@error_name` / `@print` / `@println` / `@syscall` / `@ptr_from_usize` /
  `@usize_from_ptr` / `@c_import` / `@naked_fn` / `@vector` / `@mask`）

每种 expr 必须显式落在 §2 表格中的一种状态：done / partial / reject / missing。
新增 CoreExpr kind 必须同步更新本表与覆盖矩阵 §5。

---

## 2. CoreExpr 状态表

| kind | 状态 | AST 端输入 | MIR 端 inst 形状 | 验证证据 |
|------|------|-----------|------------------|----------|
| `CORE_EXPR_KIND_CALL` | done | `AST_CALL_EXPR` / `AST_METHOD_CALL`（合并到 CALL 形式） | `MIR_INST_OP_CALL` + operands(target_fn, args) | `tests/verify_hosted_native_full_language_smoke.sh` `defer`/`drop`/`interface` shard |
| `CORE_EXPR_KIND_INDEX` | done | `AST_ARRAY_ACCESS` | `MIR_INST_OP_LOAD`/`MIR_INST_OP_STORE` + 计算地址（base + index * stride） | `tests/verify_hosted_native_full_language_smoke.sh` `array_index` shard |
| `CORE_EXPR_KIND_SLICE` | done | `AST_SLICE_EXPR` | ptr/len pair；ptr = base + start * stride，len = end - start | `tests/verify_hosted_native_full_language_smoke.sh` `slice` shard |
| `CORE_EXPR_KIND_ATOMIC` | done | `AST_BINARY_EXPR` on `atomic T` + atomic op | `MIR_INST_OP_*` atomic 形式 + atomic ordering | `tests/verify_hosted_native_full_language_smoke.sh` `atomic` shard |
| `CORE_EXPR_KIND_VECTOR` | done | `@vector(T, N)` literal/splat/op | lane-by-lane 标量 inst 序列化或 SIMD 优化 | `tests/verify_hosted_native_full_language_smoke.sh` `simd` shard |
| `CORE_EXPR_KIND_MASK` | done | `@mask(N)` | lane mask reg | `tests/verify_hosted_native_full_language_smoke.sh` `simd` shard |
| `CORE_EXPR_KIND_INT_LITERAL` | done | `AST_NUMBER` / `AST_INT_LIMIT` | `MIR_INST_OP_NOP` 携带 `imm: i64` 立即数 | `tests/verify_hosted_native_basic_parity.sh` `exit0`/`return7` |
| `CORE_EXPR_KIND_LOCAL_REF` | done | `AST_IDENTIFIER`（local scope） | `MIR_INST_OP_LOAD` from MirLocal | `tests/verify_hosted_native_main_local_if_preflight.sh` |
| `CORE_EXPR_KIND_I32_NE` | done | `AST_BINARY_EXPR` `!=` on i32 | `MIR_INST_OP_I32_NE`（cmp + setcc） | `tests/verify_hosted_native_main_local_if_preflight.sh` (`v != 3`) |
| `CORE_EXPR_KIND_I32_ADD` | done | `AST_BINARY_EXPR` `+` on i32 | `MIR_INST_OP_I32_ADD` | covered by `atomic`/`interface` shard |
| `CORE_EXPR_KIND_I32_LE` | done | `AST_BINARY_EXPR` `<=` on i32 | `MIR_INST_OP_I32_LE` | `tests/verify_hosted_native_full_language_smoke.sh` `simd` shard (`vec_a < vec_b`) |

### 2.1 字符串字面量与插值（特殊路径）

`AST_STRING` 不直接落成 CoreExpr kind — 它在 print/println 路径上被
`docs/print_corebody_surface.md` §3.4 描述的字符串插值物化规则吸收，落成
`uya_write_str(fd, ptr, len)` call。表达式位置（`const s = "hello";`）落成
`AST_STRING` → 字符串常量池中的地址 + len，类型为 `&[u8: N]`。

`AST_STRING_INTERP` 同上，buffer 在 lowering 阶段物化。

### 2.2 builtin 表达式的处理

`@len` / `@size_of` / `@align_of` 落成 `CORE_EXPR_KIND_INT_LITERAL`（编译期
常量计算）。`@error_id` / `@error_name` 落成 `CORE_EXPR_KIND_CALL` 指向
runtime helper。`@print` / `@println` 走 `docs/print_corebody_surface.md` §3
的 `EXPR + CALL` 路径。`@syscall` / `@ptr_from_usize` / `@usize_from_ptr` /
`@c_import` / `@naked_fn` / `@vector` / `@mask` 在 hosted native 当前走
pre-MIR helper 或 explicit reject；详细状态在 `docs/portable_mir_language_coverage.md` §3 / §8。

---

## 3. 通用 contract

每个 `CORE_EXPR_KIND_*` 必须满足：

1. **类型传递**：每个 CoreExpr 携带 `type_id: TypeId`，lowering 时翻译成
   `MirTypeId`（见 `docs/types_layout_lowering_contract.md`）。
2. **result value**：除 `void` 表达式外，每个 CoreExpr 产出 1 个 `MirValue`，
   通过 `MIR_INST_OP_*` 的 `result_value_id` 字段暴露。
3. **operand 序列化**：输入子表达式（`lhs_expr_id` / `rhs_expr_id` /
   `callee_expr_id` / `place_id`）必须先于父 expr 落成 operand，verifier
   `MIR_VERIFY_ERR_UNDEFINED_USE` 拒绝前向引用。
4. **副作用**：标记有副作用的 expr（call / atomic / write）必须出现在
   `MIR_INST_OP_*` 列表中且不被 dead-code elimination 删除；纯 expr
   （literal / load）允许被消除。
5. **short-circuit**：`&&` / `||` 必须翻译成 `MIR_TERMINATOR_KIND_COND_BR`
   形式而非嵌套 if，否则 verifier 报 `MIR_VERIFY_ERR_INVALID_CLEANUP`。

---

## 4. AST 节点到 CoreExpr 入口

`src/exec/lower.uya` 的 `exec_lower_expr` 必须为以下 AST kind 落成对应
CoreExpr kind（部分 AST kind 共享同一个 CoreExpr kind）：

| AST kind | CoreExpr kind |
|----------|---------------|
| `AST_NUMBER` / `AST_INT_LIMIT` | `INT_LITERAL` |
| `AST_BOOL` | `INT_LITERAL`（0/1） |
| `AST_STRING` | （见 §2.1） |
| `AST_STRING_INTERP` | （见 §2.1） |
| `AST_IDENTIFIER` (local) | `LOCAL_REF` |
| `AST_IDENTIFIER` (global / fn) | `CALL` 形式的 call target 解析 |
| `AST_BINARY_EXPR` | 算术 / 比较 / 逻辑，按 op 分发到具体 CoreExpr kind |
| `AST_UNARY_EXPR` | 与 binary 类似 |
| `AST_CALL_EXPR` / `AST_METHOD_CALL` | `CALL` |
| `AST_MEMBER_ACCESS` | `CALL` (vtable) 或 inlined field access |
| `AST_ARRAY_ACCESS` | `INDEX` |
| `AST_SLICE_EXPR` | `SLICE` |
| `AST_CAST_EXPR` | 走 typed-program 的 cast lowering（与 `INDEX`/`LOAD` 组合） |
| `AST_LEN` / `AST_SIZEOF` / `AST_ALIGNOF` | `INT_LITERAL`（编译期常量） |
| `AST_TRY_EXPR` | 走 `CORE_STMT_KIND_ERROR_PROPAGATION` 而非 CoreExpr kind |
| `AST_CATCH_EXPR` | 走 `CALL` 形式（`result_or_default(err, default)` 语义） |
| `AST_MATCH_EXPR` | `CALL` 形式（jump table） |
| `AST_ERROR_VALUE` | `INT_LITERAL`（编译期 error id） |
| `AST_PRINT` / `AST_PRINTLN` | `CALL` 指向 frozen runtime helper（见 print contract） |
| `AST_VECTOR` (literal) | `VECTOR` |
| `AST_MASK` | `MASK` |
| `AST_STRUCT_INIT` / `AST_ARRAY_LITERAL` / `AST_TUPLE_LITERAL` | `CALL` 形式（aggregate ctor） |
| `AST_EMBED` / `AST_EMBED_DIR` | missing — 编译期嵌入未迁 MIR |
| `AST_VA_START` 等可变参数 builtin | missing — 仅 c_import 边界使用 |
| `AST_MC_EVAL` / `AST_MC_CODE` / `AST_MC_AST` / `AST_MC_ERROR` / `AST_MC_INTERP` / `AST_MC_TYPE` / `AST_MC_SOURCE` | partial — 宏内 builtin 走 pre-MIR helper |
| `AST_AWAIT_EXPR` | partial — 异步表达式；C99 走 async transform |

任何新 ASTExpr kind 添加时，本表必须先于 `src/lower/core.uya` 的
`CORE_EXPR_KIND_*` 常量新增。

---

## 5. 验证与守门

1. `tests/verify_portable_mir_language_coverage.sh`：矩阵 §5 覆盖守门。
2. `tests/verify_hosted_native_full_language_smoke.sh`：
   - `builtin` / `array_len` / `array_index` / `slice` / `error_id` /
     `catch` / `dynamic_catch` / `defer` / `drop` / `interface` / `atomic` /
     `simd` shard：必须 hosted native 真实生成 executable + C99 parity 一致。
3. `tests/verify_hosted_native_helloworld_parity.sh`：单个 expr 形态的
   最小路径守门（`@println` 是 CALL 形式）。
4. `tests/verify_portable_mir_lowering_contract.sh`：CoreExpr kind 数量与
   matrix 报告的 `core_exprs.count` 一致。

新增 expr 形态或 CoreExpr kind 时：
- 更新本文件 §2 表格；
- 更新 `docs/portable_mir_language_coverage.md` §5 表格；
- 如果状态为 `done` 或 `partial`，添加或更新对应 verify 脚本的 shard。

---

## 6. 反向合同

禁止：

1. 绕过 CoreExpr 直接消费 AST 生成 MIR inst。
2. 忽略 short-circuit 而退化为位运算（`&&` 必须生成 `MIR_TERMINATOR_KIND_COND_BR`）。
3. 把 `@print` / `@println` 当作 void 表达式处理（C99 oracle 返回 i32）。
4. 字符串插值在 MIR 中保留为多个 segment 表达式（必须在 lowering 时物化为单一 buffer）。

---

## 7. 与其它迁移组的衔接

- **statements**（`docs/statements_lowering_contract.md`）：expr 通常作为 stmt 的子节点。
- **places**（`docs/places_lowering_contract.md` 待补）：`MEMBER_ACCESS` 等
  涉及 place 寻址。
- **types/layout**（`docs/types_layout_lowering_contract.md` 待补）：expr 的
  `type_id` 必须翻译成 `MirTypeId`。
