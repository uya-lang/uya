# 通用 @async_fn 协程变换实现计划

> **核对头（2026-10-19）**：本文描述的方案**就是**仓库当前实际路线（C99 codegen 层递归段发射，不改 parser/checker、不新增 AST 节点），与 [async_coroutine_transform_design.md](async_coroutine_transform_design.md) 的 AST 变换备选方案相反。
> 关键函数仍在位：`gen_async_function_stage_b()`（`src/codegen/c99/function.uya:1855` 调用点）、`emit_async_segment()`（`:5874`）、`emit_async_segment_with_control()`（`:5082`）、`emit_async_continuation` 路径（`:4939`/`:5051`/`:5070`/`:5106`）。
> 下方"实现步骤"里的行号（2785-3081 等）是 2026-04 快照，已随文件增长漂移，请按**函数名**而非行号定位。
> 第 15 行"`for iter |&x|` 引用绑定需继续报错"已被推翻：该形态已成正向回归 `tests/test_async_for_iterator_ref_await.uya`。

## Context

早期 `@async_fn` 状态机在 C99 codegen 层大量依赖模式匹配 AST 形状，易漏语句与错状态转移（Bug A/B/C/D，以及复合表达式里的 `try @await`）。

**目标**：用通用算法驱动 `gen_async_function_stage_b` 的 poll 体，支持 `@async_fn` 中常见控制流与 `@await` 的组合。

**策略**：不改 parser/checker，不创建新 AST 节点。在 C codegen 层用「递归段发射」与 await 点收集（含循环嵌套信息）直接输出 C 代码。保持相同的外部接口（状态结构体 + poll 函数 + wrapper + vtable）。

### 当前进度（2026-04）

- **已落地**：`emit_async_segment` / `emit_async_continuation` 路径下的通用 lowering；`while` / `if` 内含 `try @await`；**范围 `for`** 与**定长数组 `for`** 内含 `try @await`（状态字段保存循环变量/索引/上界等，resume 后回跳或退出与 `while` 对称）；复合表达式中的 `try @await`（赋值 RHS / return 表达式）也已接入回放/替换路径。
- **回归测试**：`tests/test_async_bug_a_two_while.uya`、`tests/test_async_bug_b_sync_between.uya`、`tests/test_async_bug_c_tail_await.uya`、`tests/test_async_for_await.uya`、`tests/test_async_compound_try_await.uya` 等。
- **仍不支持或需 checker/codegen 明确报错**：`@async_fn` 中带 `@await` 的迭代器 `for` 目前只支持**具体 struct 的值绑定** `for iter |v|`；**接口值迭代** 与 **`for iter |&x|` 引用绑定** 需继续报错，避免退回旧的 codegen fallback。
- **历史备注**：await 循环之间的同步语句（原 Bug B）已由 `tests/test_async_bug_b_sync_between.uya` 复核通过并转正；后续若扩展新的循环形态，可继续对照 [todo_async_loop_await.md](todo_async_loop_await.md)。

---

## 生成的 C 代码模式（不变）

```c
// 1. 状态结构体
struct uya_async_<name> {
    int32_t state;
    struct { void *vtable; void *data; } await_fut;
    <type> _uya_bind_<name>;   // 每个 await 的绑定变量
    <type> _uya_loc_<name>;    // 跨 await 存活的局部变量
    <type> <param>;            // 函数参数
};

// 2. poll 函数
static <Poll_T> uya_<name>_poll(void *self, struct Waker *waker) {
    struct uya_async_<name> *s = (struct uya_async_<name> *)self;
    if (s == NULL) return Pending;
    if (s->state == 0) { /* segment 0 */ }
    if (s->state == 1) { /* poll await 0, then segment 1 */ }
    if (s->state == 2) { /* poll await 1, then segment 2 */ }
    ...
    return Pending; // unreachable
}

// 3. vtable + wrapper（不变）
```

---

## 核心算法：递归段发射

### 概念

函数体被 `@await` 切分为 N+1 个「段」(segment)。每个段是两个相邻 await 之间的代码。段内的代码用普通 `gen_stmt`/`gen_expr` 生成——**不需要任何 async 特殊逻辑**。

### 关键函数

```
emit_segment(codegen, block, start_idx, end_idx_or_await, state_after)
```

遍历 `block.stmts[start_idx .. end_idx]`，对每条语句：
- **普通语句**（不含 await）：直接 `gen_stmt(codegen, stmt)`
- **var_decl with try @await**：这是分裂点——生成「设置 await_fut → state = K → return Pending」
- **return try @await**：同上，但 Ready 后直接 return Ready(value)
- **while/for（体内含 await）**：不生成 C 的 while，而是：
  1. 发射条件检查：`if (cond) {`
  2. 发射循环体的前半段（到第一个 await）
  3. 生成 await 分裂
  4. 下一个 state 中：发射循环体后半段 + 回跳条件检查
  5. 条件为假时：`} else {` 继续发射循环后代码
- **if/else（分支含 await）**：两个分支各自递归 emit_segment
- **while/for（体内无 await）**：直接 `gen_stmt` 生成正常 C while

### 状态编号分配

在发射前，预扫描函数体分配状态号：

```
state 0 = 入口（参数复制 + 第一个 await 之前的代码）
state 1 = await 0 的 poll + await 0 Ready 后到 await 1 之前的代码
state 2 = await 1 的 poll + await 1 Ready 后到 await 2 之前的代码
...
state N = await N-1 的 poll + 最终代码 + return Ready
```

循环内的 await 回跳到自身的 state 号（不分配新号），循环退出跳到下一个 state。

### 变量提升

**保守策略**（简单正确）：函数体**所有**顶层 `var` 声明都提升到状态结构体的 `_uya_loc_*` 字段。函数参数全部捕获。

**生成代码中的变量引用**：现有的 `get_c_name_for_identifier_ref`（global.uya:330-451）已经将 `async_local_names` 中的标识符重写为 `s->_uya_loc_*`。只需正确填充 `async_local_names/types/count`。

---

## 实现步骤

### Step 1：新函数 `gen_async_poll_body_universal`

**文件**：`src/codegen/c99/function.uya`（在 `gen_async_function_stage_b` 旁边）

替换当前 `gen_async_function_stage_b` 中 lines 2785-3081 的状态循环。新函数接收：
- `codegen`, `fn_decl`, `body`（函数体 AST）
- `await_points[]`, `await_count`（已收集的 await 点）
- `poll_ret_c`, `poll_union_c`, `ready_payload_c` 等 C 类型字符串
- `ret_expr`（return 表达式，null 表示 return await）

内部算法：
1. 发射 `if (s->state == 0) { ... }`：初始化 + 第一段代码
2. 对 `state_k = 1 .. await_count`：发射 `if (s->state == K) { poll + 段代码 }`
3. 如果有终态（循环退出后）：发射最终 return Ready

### Step 2：递归段发射函数 `emit_async_segment`

```
fn emit_async_segment(
    codegen, block, from_si, to_si,
    await_points, await_count,
    next_state_on_complete,
    poll_ret_c, poll_union_c, ready_payload_c
)
```

遍历 `block.stmts[from_si .. to_si]`：
- 跳过 `is_await_bind_stmt()` 的语句（由 state 转移处理）
- 对含 await 的 while/for：拆分为条件检查 + 段发射 + 回跳
- 对含 await 的 if：两分支递归
- 其余：`gen_stmt(codegen, stmt)`

### Step 3：while/for 内 await 处理

```
// while (cond) { pre_stmts; @await; post_stmts; }
// 变换为：

// 当前 state 尾部：
if (cond) {
    emit pre_stmts;
    s->await_fut = ...; s->state = K; return Pending;
}
// 后续代码...

// state K:
poll await_fut; extract result;
emit post_stmts;
if (cond) {  // 回跳
    emit pre_stmts;
    s->await_fut = ...; s->state = K; return Pending;
} else {
    emit 循环后代码 or state = next;
}
```

### Step 4：集成

在 `gen_async_function_stage_b` 中：
1. 保留状态结构体生成（lines 2699-2743）——不变
2. 保留 poll 函数签名（line 2789）——不变
3. **替换** 状态循环（lines 2794-3081）为 `gen_async_poll_body_universal`
4. 保留 vtable + wrapper（lines 3210-3274）——不变

### Step 5：清理

- `collect_awaits_recursive` → 用 `async_collect_all_awaits`（async_transform.uya）替换
- 删除 `c99_emit_async_while_multi_loopback` 等旧的模式匹配函数（~400 行）
- 删除 `c99_emit_async_poll_not_last_transition`（~200 行）
- 删除 `c99_emit_async_while_exit_transition` 及相关辅助函数

---

## 关键文件

| 文件 | 改动 |
|------|------|
| `src/codegen/c99/function.uya` | 替换 state 循环为通用算法，删除旧辅助函数 |
| `src/codegen/c99/async_transform.uya` | 扩展：添加 `emit_async_segment` 等函数 |
| `src/codegen/c99/internal.uya` | `async_collect_enclosing_for[]` 等与 await 嵌套循环相关的收集缓冲区 |
| `src/codegen/c99/global.uya` | 无变化（`get_c_name_for_identifier_ref` 保留） |
| `src/codegen/c99/stmt.uya` | 无变化（`gen_stmt` 保留） |
| `src/codegen/c99/expr.uya` | 无变化（`gen_expr` 保留） |

## 复用的现有机制

- `get_c_name_for_identifier_ref`（global.uya:330-451）：标识符 → `s->_uya_loc_*` / `s->_uya_bind_*` 重写
- `gen_stmt` / `gen_expr`（stmt.uya / expr.uya）：普通代码生成，段内直接调用
- `async_local_names/types/count`（internal.uya:328-332）：提升变量的名称/类型存储
- `collect_async_pre_return_locals`（function.uya:2356）：收集函数体顶层 var 声明
- `emit_async_state0_pre_first_await_local_inits`（function.uya:2083）：初始化提升变量
- 状态结构体 / vtable / wrapper 生成逻辑（保留不变）

## 验证

1. **Bug A**：`tests/test_async_bug_a_two_while.uya` 通过
2. **Bug B**：`tests/test_async_bug_b_sync_between.uya` 通过
3. **Bug C**：`tests/test_async_bug_c_tail_await.uya` 通过
4. **`for` + await**：`tests/test_async_for_await.uya`（范围 + 定长数组 + 定长数组引用 + 具体 struct 迭代器值绑定）、`tests/test_async_for_iterator_ref_await.uya`（具体 struct 迭代器引用绑定正向回归），以及 `tests/error_for_iterator_interface_value.uya` / `tests/error_async_for_iterator_interface_await.uya`（接口值 `for` 是同步也不支持的通用失败边界）
5. **复合表达式 `try @await`**：`tests/test_async_compound_try_await.uya`（赋值 RHS / return 表达式）
6. **现有 async 测试**：`test_async_while_multi_await.uya`、`test_async_copy.uya` 等不回归
7. **全量回归**：`make check` / `make tests` 通过
8. **自举**：`./compile.sh --c99 -b` 一致
