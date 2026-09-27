# Uya 1.0 语法锁定目标清单（goal_v1_lockdown）

> **核对头（2026-09-27）**：本文件自述"进行中"，核对后仍成立，但**T3 已有实质进展**：
> - T3（卫生宏）：**代码已完成**（`src/checker/macro_expand.uya`、`tests/test_macro_hygiene.uya` 6/6），`docs/uya.md` §25.2.2 已写卫生宏章节；仍缺 `docs/grammar_formal.md` 的引用与 `macro_hygiene_design.md`/`todo_macro_hygiene.md` 的状态回填。
> - T2/T5：`tests/error_try_catch_combined.uya`、`tests/test_catch_multistmt_block.uya`、`tests/test_async_await_catch_multistmt.uya` 三个本文件要求的用例**均不存在**，说明对应语义收敛尚未落地。
> - T4/T6：闭包契约文档与 stdlib 手写状态机收编未完成（`lib/std/async.uya` 的 `AsyncWaitFdFuture`、`lib/std/thread.uya` 的 worker 桥接仍为手写 `poll()`，属既定 substrate 例外）。
> 结论：本文件是**真实的未完成清单**，可作为 1.0 收口闸门；各项进展请按上面证据更新，而不是按复选框数量推断。

**创建：** 2026-06-06
**状态：** 进行中
**达标定义：** 本文件 6 个工作项全部勾选完成、`make check` 通过，方算达标。未全部完成不得收口。

本目标来自一次语法 1.0 评审结论：core 语法可冻结，但四个"实验性边缘"必须先处理。
四块的命运由同一条主线决定——它们都最容易捅破 Uya 的身份标签
（**无 lifetime 符号 · 无隐式控制 · 本函数内编译期证明 · 零新符号 · 单页纸可读完**）。

- **catch**：纯属自己没收敛，与身份不冲突 → 进 1.0，但先修干净。
- **宏**：会撑爆"单页纸" → 卫生性必须做完（已完成，见 §3）。
- **闭包**：会把捕获生命周期推理塞回来 → 正式"不做"，写进契约。
- **async**：`@frame` 的 pinned 语义事实上是 lifetime 系统、跨 await 破坏"本函数内证明" → 标 provisional，补 lowering。
- **stdlib 手写状态机**：是 async 表达力不足的证据 → 收编，但受 async 完善程度约束。

---

## 依赖顺序

```
T1 (本文档) ─ 已起步
T3 (卫生宏)   ── 代码已完成，仅剩文档
T4 (闭包契约) ── 纯文档
T2 (catch)  ──→ T5 (async await/catch) ──→ T6 (stdlib 状态机收编)
```

catch 的 block-expr lowering 是 async `@await catch` 的前置；async 完善是 stdlib 收编的前置。

---

## T1 · 写独立 goal/todo 文档

- [x] 建立本文件 `docs/goal_v1_lockdown.md`，含验收标准、依赖顺序、逐项 checklist。
- [ ] 每完成一项回写本文件状态。

---

## T2 · catch 语义收敛 + block-expr lowering 修复

**现状（已核实文件位置）：**
- AST：`src/ast.uya:114-115`（`AST_TRY_EXPR` / `AST_CATCH_EXPR`），字段 `src/ast.uya:294-300`。
- 解析：`try` 前缀 `src/parser/expressions.uya:12-28`；`catch` 后缀左结合循环 `src/parser/expressions.uya:101-133`。
  - 当前 `try X catch` **语法上可解析**为 `try (X catch {...})`（try 走到 `parser_parse_cast_expr`，catch 在那里挂）。
- 类型检查：try `src/checker/check_expr.uya:1893-1975`；catch `infer_catch_expr` `src/checker/check_expr.uya:4017-4088`。
  - catch block-expr 取值：最后一条语句的类型须等于 payload `T`，`return` 可发散（4076-4087）。
- C99 codegen：`gen_catch_expr` `src/codegen/c99/expr.uya:8418-8719`；多语句块 lowering 8660-8717（非末句走 `gen_stmt` 丢值，末句赋给 `_uya_catch_result`）。
- `try` 当前**双重语义**：错误传播 + 溢出/UB 检查标记（`docs/uya.md:2856`）。

**要做：**
- [ ] **拆分 `try` 双重语义**：错误传播与"溢出/UB 检查"分离，`try a + b` 不再二义。决定：保留 `try` 仅做错误传播，溢出检查另用机制（评估 `@`-内建或显式形式），同步 `docs/uya.md`、`grammar_formal.md`。
- [ ] **禁止 `try X catch` 叠用**：在 parser 或 checker 报明确错误（二者互斥：try 传播 / catch 处理）。补 `tests/error_try_catch_combined.uya` 负测。
- [ ] **修复多语句 catch block-expr lowering**：在同步路径与 `@await` 路径都正确处理"非末句副作用 + 末句产值 / 发散"。补 `tests/test_catch_multistmt_block.uya`。
- [ ] `make check` 通过。

---

## T3 · 卫生宏实现完成

**现状：已实现并通过测试。** `docs/macro_hygiene_design.md` 头部"待实现"是过期信息。
- 实现：`src/checker/macro_expand.uya`（`deep_copy_ast_internal` 在拷贝期对 var/for/fn 参数/catch 错误变量重命名为 `<name>__hyg_<expansion>_<local>`；旁表 + scope 栈；宏参数与 `const x=@mc_eval/@mc_type` 不重命名）。
- 测试：`tests/test_macro_hygiene.uya` **6/6 通过**（已实测 2026-06-06）。

**要做：**
- [ ] `docs/uya.md` §25 新增"卫生宏"小节：重命名范围、宏参数/`@mc_eval` 不重命名、`fn_decl_name` 首版不重命名、生成名格式。
- [ ] `docs/grammar_formal.md` 补卫生语义引用。
- [ ] `docs/macro_hygiene_design.md` 头部状态改为"已实现"，`docs/todo_macro_hygiene.md` 勾掉 Phase 4。
- [ ] 复跑 `tests/test_macro_hygiene.uya` + 其它 `tests/test_macro*.uya` 确认无回归。

---

## T4 · 闭包：正式写入"不做"契约并锁定 `|...|`

**现状：** 只有函数指针 `fn(P) R`（`docs/uya.md:2786,3001,3017`，FFI 回调）。无闭包。`|...|` 已被 for 捕获 / catch 错误变量 / match 绑定占用。

**判断：** 隐式捕获闭包需要捕获变量生命周期跟踪或堆分配——与"无 lifetime 符号 / 零 GC"根本冲突。故"不做"是设计决定，不是缺口。

**要做：**
- [ ] `docs/uya.md` 明确写入：1.0 不提供隐式捕获闭包；理由（身份冲突）。
- [ ] 锁定 `|...|` 仅用于 for 捕获 / catch / match 绑定，规范中写明保留语义。
- [ ] 给出符合身份的逃生口约定：显式 context（`fn(ctx: &Ctx, ...)` 或 `(fn_ptr, &ctx)` 胖函数），说明非逃逸非捕获 lambda 可后续非破坏性添加。
- [ ] `readme.md` 同步一句话表态。

---

## T5 · 完善 async：canonical Future 形式 + await/catch lowering

**现状（已核实）：**
- CPS 变换：`src/codegen/c99/async_transform.uya`（收集 await、分段）+ `src/codegen/c99/function.uya:4766+`（状态机生成）。
- `try @await` lowering：`function.uya:2174-2196`、`async_transform.uya:76-122`。
- **两种返回形式都接受**：`Future<!T>` 与 `!Future<T>`，校验在 `src/checker/check_stmt.uya:612-648`（注释明示"旧语义/新语义"），`@await` 推断 `check_expr.uya:1985-2039`。
- `@frame` pinned 语义强制：`src/checker/async_frame_meta.uya`（move/assign/传参/返回拦截）、`check_call.uya:1698-1744`。
- 已知未实现（`docs/async_loop_await_design.md` §6、`docs/plan_async_coroutine_transform.md`）：
  - 迭代器 `for |v|` + `@await` 不支持；`for |&x|` 元素绑定 + `@await` 不支持。
  - `@await catch` 多语句 block 限制（与 T2 同源；stdlib 用 `soft_error` / `err_id_out` 侧通道绕过）。

**要做：**
- [ ] **选定 canonical Future 形式**：定 `Future<!T>` 为唯一规范（与状态机 `Poll<!T>` 对齐），`!Future<T>` 降为 alias 或在 checker 给弃用警告。同步 `check_stmt.uya` 与文档。
- [ ] **补全 `@await` + `catch` 多语句 lowering**（依赖 T2 的 block-expr 修复在 async 路径生效）。补 `tests/test_async_await_catch_multistmt.uya`。
- [ ] 文档标注：async 安全模型在 `@await` 点为弱保证（跨挂起别名不受"本函数内证明"覆盖），`@frame` pinned 是 async 子集独有的所有权约束。
- [ ] （可选，按 stdlib 需要）评估 `for |v|`+`@await` 支持，作为 T6 的前置。
- [ ] `make check` 通过。

---

## T6 · 收编 stdlib 手写状态机为 @async_fn

**现状（已盘点）：** 手写状态机多数有硬理由（裸 syscall、跨 poll 的部分读写、waker/EAGAIN），不是改皮即可。
- `lib/std/net/dns.uya`：`DnsUdpFuture`（74-101 / poll 981-1137，stage 0-4）、`DnsTcpFuture`（1980-2009 / poll 2025-2298，stage 0-7，含部分读写 `bytes_sent/received`）、`DnsQueryTransportFuture`（2325-2404，UDP→TCP 回退）。
- `lib/std/async.uya`：`AsyncFdReadFuture` / `AsyncFdWriteFuture`（单 flag，最易迁移）。
- `lib/std/http/http1_async.uya`：`Http1ConnectFuture`。
- `lib/std/http/uyagin.uya`：`UyaginRecoverFuture` / `UyaginObserveFuture` / `UyaginWritevFuture` / `UyaginAcceptFuture` 等。

**要做（按难度递增，能收一个算一个，收不动的明确记录原因）：**
- [ ] 先收**简单 flag 型**：`UyaginObserveFuture`、`UyaginRecoverFuture`、`AsyncFdRead/Write`（视 async 表达力）。
- [ ] 收 `DnsQueryTransportFuture`（UDP→TCP 回退 = await + 条件分支，T5 完成后应可表达）。
- [ ] 评估 `DnsUdpFuture` / `DnsTcpFuture`：需要部分读写循环 + 裸 syscall；若 async 仍无法干净表达，**保留手写**并在本文件记录"为何保留"，不算未达标（前提：已用 `@async_fn` 收掉所有可收的，并在文档登记保留清单）。
- [ ] `tests/test_std_dns*.uya`、`tests/test_async*.uya`、`tests/test_http1_async*.uya` 通过。
- [ ] `make check` 通过。

---

## 收口检查

- [ ] T1–T6 全部勾选（T6 保留项已登记理由）。
- [ ] `make check` 全量通过。
- [ ] 涉及语法/语义变更的文档（`uya.md` / `grammar_formal.md` / `grammar_quick.md` / `builtin_functions.md`）已同步。
