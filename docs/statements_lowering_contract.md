# Statements Group Lowering Contract

**状态**: Phase 9B statements 迁移组合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, leaf "statements")
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §4 (CoreStmt)
**配套 surface contract**: `docs/print_corebody_surface.md`

---

## 1. 范围

本文件定义 `CoreStmtKind` 中所有 statement 形态（10 个常量）的通用
CoreBody → PortableMIR lowering 合同，涵盖：

- expression statement
- var / const decl
- assign
- if / else
- while / for
- break / continue
- return
- block
- defer / errdefer / drop
- try / catch
- 裸 call statement（`a();` 形式，非 expression 位置）

每种 stmt 必须显式落在 §2 表格中的一种状态：done / partial / reject / missing。
新增 CoreStmt kind 必须同步更新本表与覆盖矩阵 §4。

---

## 2. CoreStmt 状态表

| kind | 状态 | AST 端输入 | MIR 端 inst 形状 | 验证证据 |
|------|------|-----------|------------------|----------|
| `CORE_STMT_KIND_RETURN` | done | `AST_RETURN_STMT`，可携带 value expr | `MIR_TERMINATOR_KIND_RETURN` + 0/N 个 operand（return value） | `tests/verify_hosted_native_basic_parity.sh` `exit0`/`return7` shard |
| `CORE_STMT_KIND_ASM` | partial | `AST_ASM`，仅在 microapp/freestanding | 直接 emit `@asm` 内容到裸 inst，hosted native 显式 reject | `tests/verify_microapp_*` 走 microapp 路径 |
| `CORE_STMT_KIND_DEFER` | done | `AST_DEFER_STMT` | CoreBody 维护 defer stack（`MIR_INST_OP_STORE` 到 defer-local slot + cleanup edge） | `tests/verify_hosted_native_full_language_smoke.sh` `defer` shard |
| `CORE_STMT_KIND_ERRDEFER` | partial | `AST_ERRDEFER_STMT` | cleanup edge 区分 error/ok path，hosted native 端到端 parity 待 Phase 9B | C99 端 `c99/cleanup_capacity_diagnostics.sh` 验证 |
| `CORE_STMT_KIND_DROP` | done | `AST_METHOD_BLOCK` 的 `fn drop` 调用点 | `MIR_INST_OP_CALL` 指向 struct 的 drop impl | `tests/verify_hosted_native_full_language_smoke.sh` `drop` shard |
| `CORE_STMT_KIND_ERROR_PROPAGATION` | done | `AST_TRY_EXPR` | cleanup edge + 短路到 caller 的 error return | `tests/verify_hosted_native_full_language_smoke.sh` `dynamic_catch` shard |
| `CORE_STMT_KIND_LOCAL_DECL` | done | `AST_VAR_DECL` / `AST_DESTRUCTURE_DECL` | `MIR_INST_OP_LOCAL_SET` 绑定到 MirLocal，初始化表达式作为 init operand | `tests/verify_hosted_native_main_local_if_preflight.sh` shard |
| `CORE_STMT_KIND_IF` | done | `AST_IF_STMT` | 1 个 cond block + 2 个 successor（then/else 或 then/fallthrough）+ `MIR_TERMINATOR_KIND_COND_BR` | `tests/verify_hosted_native_main_local_if_preflight.sh` shard |
| `CORE_STMT_KIND_ASSIGN` | done | `AST_ASSIGN`（含 `+=` 等复合） | `MIR_INST_OP_STORE` 或 `MIR_INST_OP_LOCAL_SET`；atomic 走 atomic op | `tests/verify_hosted_native_full_language_smoke.sh` `atomic` shard（`atomic_value += 2`） |
| `CORE_STMT_KIND_EXPR` | done | `AST_EXPR_STMT` | 内部 expr 转 1+ MirInst，结果丢弃 | `tests/verify_hosted_native_helloworld_parity.sh` bare/split/return-as-expr 三变体 |
| `CORE_STMT_KIND_WHILE` | partial | `AST_WHILE_STMT` | cond block + body block + loop exit block，body 尾部回到 cond block | MIR-C99 structured CFG leaf 待补 |
| `CORE_STMT_KIND_BLOCK` | partial | block body / scope body | 子 statement range 保持结构化顺序，供 CFG lowering 展开 | `tests/verify_lowered_program_core_verifier.sh` contract shard |
| `CORE_STMT_KIND_BREAK` | partial | `AST_BREAK_STMT` | `MIR_TERMINATOR_KIND_BR` 到当前 loop exit target | MIR-C99 structured CFG break/continue leaf 待补 |
| `CORE_STMT_KIND_CONTINUE` | partial | `AST_CONTINUE_STMT` | `MIR_TERMINATOR_KIND_BR` 到当前 loop continue/backedge target | MIR-C99 structured CFG break/continue leaf 待补 |

### 2.1 状态语义

- **done**：C99 + hosted native 端到端 parity 验证脚本已存在并通过。
- **partial**：C99 端通过；hosted native 端到端 parity 待 Phase 9B 收口叶子补齐。
- **reject**：在覆盖矩阵 §7 显式登记，可复现 diagnostic。
- **missing**：尚未迁 MIR；本阶段不新增 `missing`。

---

## 3. CoreStmt → MirInst/Block 映射合同

每种 stmt 必须满足：

1. **terminator 形状**：除 `IF` 用 `MIR_TERMINATOR_KIND_COND_BR`、普通 stmt
   用 fallthrough block 终结（即每个 stmt 是 1 个独立 MirBlock，terminator 是
   `MIR_TERMINATOR_KIND_BR` 指向下一个 block），`RETURN` 用
   `MIR_TERMINATOR_KIND_RETURN`。
2. **block 数量**：
   - `RETURN` 终止当前 block，**不**新建 block。
   - `IF` 创建 1 个 cond block + 2 个 successor block（then/else or then/fallthrough）。
   - `WHILE`/`FOR` 创建 loop header + loop body + exit block，循环出口为
     `MIR_TERMINATOR_KIND_BR`。
   - `DEFER`/`DROP`/`ERRDEFER` 不创建新 block，**仅**在 cleanup edge 链中追加。
   - `LOCAL_DECL`/`ASSIGN`/`EXPR` 不创建新 block，原地 inst 序列化。
3. **operand 序列化**：每个 value 都通过 `portable_mir_append_operand` 注册，
   verifier `portable_mir_verify_operand` 必须接受。
4. **cleanup edge**：任何引入 `MirLocal` 的 stmt 都必须在 cleanup edge table
   中注册 drop/restore 动作，verifier `MIR_VERIFY_ERR_INVALID_CLEANUP` 拒绝。
5. **source span**：每个 stmt/terminator 携带 `debug_loc_id` 指向
   `MirDebugLoc`；缺失则 verifier `MIR_VERIFY_ERR_INVALID_LAYOUT` 拒绝。

---

## 4. AST 节点到 CoreStmt 入口

`src/exec/lower.uya` 的 `exec_lower_stmt` 必须为以下 AST kind 落成对应
CoreStmt kind：

| AST kind | CoreStmt kind | 备注 |
|----------|---------------|------|
| `AST_EXPR_STMT` | `EXPR` | 表达式结果丢弃 |
| `AST_VAR_DECL` | `LOCAL_DECL` | 包含 `AST_DESTRUCTURE_DECL`（`const (x, y) = expr`） |
| `AST_ASSIGN` | `ASSIGN` | 含 `+=` `-=` 等复合 |
| `AST_IF_STMT` | `IF` | |
| `AST_WHILE_STMT` | `IF` (loop header) | 循环结构在 body / successor 上 |
| `AST_FOR_STMT` | `IF` (loop header) | 同上 |
| `AST_BREAK_STMT` | `BR` terminator (loop exit) | 终止 block |
| `AST_CONTINUE_STMT` | `BR` terminator (loop header) | 终止 block |
| `AST_RETURN_STMT` | `RETURN` | |
| `AST_BLOCK` | fallthrough | 内部 stmt 序列展开 |
| `AST_DEFER_STMT` | `DEFER` | |
| `AST_ERRDEFER_STMT` | `ERRDEFER` | |
| `AST_METHOD_BLOCK` 中的 drop 注入点 | `DROP` | 隐式注入 |
| `AST_TRY_EXPR` (statement position) | `ERROR_PROPAGATION` | 落成 cleanup edge |
| `AST_ASM` | `ASM` | microapp / freestanding only |

任何新 ASTStmt kind 添加时，本表必须先于 `src/lower/core.uya` 的 `CORE_STMT_KIND_*`
常量新增；否则 lowering pass 会在新 AST 形态上静默回退到 pre-MIR helper。

---

## 5. 验证与守门

1. `tests/verify_portable_mir_language_coverage.sh`：矩阵 §4 覆盖守门。
2. `tests/verify_hosted_native_full_language_smoke.sh`：
   - `defer` / `drop` / `dynamic_catch` shard：必须 hosted native 真实生成
     executable + C99 parity 一致。
   - 当前三 shard 在 Phase 9A 收口时走 `run_native_parity_fragment`，要求
     parity 成功；当新通用 lowering 落地后仍必须保持该行为。
3. `tests/verify_hosted_native_helloworld_parity.sh`：单 expression statement
   形态的最小路径守门。
4. `tests/verify_portable_mir_lowering_contract.sh`：确认 CoreStmt kind 数量
   与 matrix 报告的 `core_stmts.count` 一致。

新增 stmt 形态或 CoreStmt kind 时，必须：
- 更新本文件 §2 表格；
- 更新 `docs/portable_mir_language_coverage.md` §4 表格；
- 如果状态为 `done` 或 `partial`，添加或更新对应 verify 脚本的 shard。

---

## 6. 反向合同

禁止以下任一行为破坏 §2 状态：

1. **绕过 CoreStmt**：直接消费 `ASTNode` 生成 MIR inst，绕过 CoreBody contract。
2. **一个 stmt 多个 MirBlock**（除 `IF`/`WHILE`/`FOR` 等控制流）：阻塞 verifier
   静态分析。
3. **cleanup edge 缺失**：任何引入 `MirLocal` 的 stmt 缺少对应 cleanup edge
   都会导致 `MIR_VERIFY_ERR_INVALID_CLEANUP`。
4. **partial 静默变 done**：必须在 `tests/verify_hosted_native_full_language_smoke.sh`
   shard 中真实生成 ELF 才算 done。

---

## 7. 与其它迁移组的衔接

- **expressions**（`docs/expressions_lowering_contract.md` 待补）：每个
  CoreStmt 内部引用的 CoreExpr 必须先在 expressions 组落地。
- **places**（`docs/places_lowering_contract.md` 待补）：`LOCAL_DECL` 和
  `ASSIGN` 涉及的 CorePlace 必须先在 places 组落地。
- **types/layout**（`docs/types_layout_lowering_contract.md` 待补）：stmt
  中的 type_id 转换必须走 types/layout 组的 type translation。

本文件不重复这些组的合同，只锁定 statements 自身的形状。
