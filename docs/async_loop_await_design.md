# 循环内 await 代码生成设计文档

**版本**：v0.2  
**状态**：通用 lowering 主路径已落地，Bug B 与复合表达式 `try @await` 已转正（维护/补洞）
**相关**：[std_async_design.md](std_async_design.md)、[todo_mini_to_full.md](todo_mini_to_full.md) §16 异步编程、[plan_async_coroutine_transform.md](plan_async_coroutine_transform.md)

> **核对头（2026-10-19）**：正文状态与源码一致，无过期结论。
> - 实现仍在 `src/codegen/c99/` 层：`gen_async_function_stage_b()`（`function.uya:1855` 调用点）、`emit_async_segment()`（`function.uya:5874`）、`emit_async_segment_with_control()`（`:5082`）；§7 表的 `collect_awaits_recursive` / `async_collect_*` 也仍在 `function.uya` / `internal.uya`。
> - §7 里 `src/codegen/c99/async_transform.uya` 标注的"（若存在）"已确认：**该文件存在**（`src/codegen/c99/async_transform.uya`），是 c99 codegen 目录的 12 个文件之一。
> - §6 最后一行"接口值迭代仍需显式报错"仍成立，且**不是 async 独有缺口**（同步 `for` 迭代接口值同样被禁止），反向回归为 `tests/error_for_iterator_interface_value.uya` / `tests/error_async_for_iterator_interface_await.uya`；引用绑定 `for iter |&x|` 已是正向回归 `tests/test_async_for_iterator_ref_await.uya`。

---

## 1. 概述

### 1.1 问题背景

`@async_fn` 中的 `try @await` 可能出现在循环内，例如 `async_copy`：

```uya
@async_fn fn async_copy(reader: &MemAsyncReader, writer: &MemAsyncWriter, buf: &byte, buf_len: usize) !Future<usize> {
    var total: usize = 0;
    while true {
        const n: usize = try @await reader.read(buf, buf_len);
        if n == 0 { return total; }
        const written: usize = try @await writer.write(buf as &const byte, n);
        total = total + written;
        if written < n { return total; }
    }
}
```

需要支持：
- **递归收集**：在 while / if / for / block 内递归收集所有 await 点，并记录每个点外层的 `while` / `for`（内层循环优先）
- **循环回跳**：完成一轮循环体内的 await 后回到下一轮条件/迭代头，而非线性结束
- **持久化变量**：跨 await 仍可达的局部变量与参数存于状态结构体（`_uya_loc_*`、绑定字段等）；**不再**依赖 `n`+`written`+`_uya_total` 特判

### 1.2 设计目标

| 目标 | 说明 |
|------|------|
| 正确性 | 生成的状态机语义与源码等价 |
| 类型安全 | slot 类型与 operand 类型匹配，`!Future<T>` 需 try 后存 `.value` |
| 无悬挂指针 | sync 方法返回的 Future 若指向栈上 compound literal，需复制到状态存储 |
| 与现有兼容 | 线性 await 行为不变，新增逻辑仅影响循环内 await |

---

## 2. 整体架构

```
                    collect_awaits_recursive()
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ await_operands[]  await_bind_names[]  await_bind_types[]  has_await_loop │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 状态机生成（`gen_async_function_stage_b` + `emit_async_segment` 等）        │
│  • 按 await 点划分 segment；段内直接 `gen_stmt` / `gen_expr`               │
│  • 分裂点：设子 Future、`state`、`_uya_bind_*`，`return Pending`            │
│  • `while` / `for` 内含 await：`emit_async_while_*` / `emit_async_for_*`   │
│    与 `emit_async_continuation` 中回跳或退出到下一状态                     │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ C 输出                                                                    │
│  struct uya_async_xxx { state; await_fut; _uya_bind_*; _uya_loc_*; … }     │
│  static Poll_xxx poll(...) { if state==0 {...} if state==1 {...} ... }     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. 核心数据流

### 3.1 await 收集

| 阶段 | 说明 |
|------|------|
| **collect_awaits_recursive** | 递归遍历 block / while / if / for，收集 `try @await expr` 的 operand、绑定名、绑定类型；填充 `enclosing_while` / `enclosing_for` |
| **has_await_loop** | 当任一 await 在循环（while/for）内时置 1 |
| **async_loop_var_is_total** | （历史）已移除特判路径；累加器等由顶层 `var` → `_uya_loc_*` 通用提升 |

### 3.2 状态机结构体（示意）

```c
struct uya_async_std_async_copy {
    int32_t state;
    struct Future_usize _uya_await_storage;      // 仅当需要避免 operand 悬挂时存在
    struct uya_interface_Future_usize await_fut;
    size_t _uya_loc_total;                       // 示例：原局部 total 提升为状态字段
    struct MemAsyncReader * reader;
    struct MemAsyncWriter * writer;
    uint8_t * buf;
    size_t buf_len;
};
```

| 字段 | 用途 |
|------|------|
| `state` | 当前状态：0=起点，1..n=各 await 就绪后 |
| `_uya_await_storage` | 存储 sync 方法返回的 Future 值，避免 compound literal 悬挂指针 |
| `await_fut` | 当前 poll 的 child future（接口 fat 指针） |
| `_uya_loc_*` | 原函数体内需跨 await 存活的 `var`（含循环累加器等） |

### 3.3 类型与 try 判定

| 变量 | 说明 |
|------|------|
| `return_future_err_union` | 返回类型为 `!Future<T>` 时置 1 |
| `concrete_future_safe` | 从 `effective_return_type` 提取，若 type_args[0] 为 error union 则用 payload 生成 `Future_usize` 等 |
| `state_slot_iface_c` | await_fut 槽位的 C 类型，如 `struct uya_interface_Future_usize` |
| `await_operand_is_err_future` | 当 `return_future_err_union` 或绑定类型为 Future 时置 1，表示 operand 返回 `!Future<T>` 需 try |

---

## 4. 关键实现点

### 4.1 递归 await 收集

```uya
fn collect_awaits_recursive(...) void {
    // 遍历 AST：block、while、if、for
    // 遇到 try @await expr 时：
    //   await_operands[ci] = operand;
    //   await_bind_names[ci] = bind_name;   // 如 "n", "written"
    //   await_bind_types[ci] = bind_type;   // 如 usize
    // 若在 while/for 内，has_await_loop = 1
}
```

### 4.2 return_future_err_union 判定

- **原逻辑**：依赖 `await_count==0`、`ret_expr` 为 Future 初始化、`await_bind_types[0]` 为 Future
- **现逻辑**：当 `full_return_type` 为 error union 且 payload 为 `Future<T>` 时，直接置 1

### 4.3 concrete_future_safe 与 state_slot

- 当 `effective_return_type.type_named_type_args[0]` 为 `AST_TYPE_ERROR_UNION` 时，用 payload 作为 slot 类型参数
- 例：`!Future<usize>` → type_args[0]=`!usize` → payload=`usize` → slot 类型为 `Future_usize`

### 4.4 await 赋值时的 try 与 storage 复制

当 `await_operand_is_err_future` 且存在 `_uya_await_storage` 时：

```c
({
  struct err_union_uya_interface_Future_usize _uya_await_tmp = reader.read(...);
  if (_uya_await_tmp.error_id != 0) return ...;
  s->_uya_await_storage = *(struct Future_usize *)_uya_await_tmp.value.data;
  s->await_fut = (struct uya_interface_Future_usize){
    .vtable = _uya_await_tmp.value.vtable,
    .data = (void*)&s->_uya_await_storage
  };
})
```

**原因**：sync 方法（如 `MemAsyncReader.read`）返回的 Future 的 `.data` 指向函数内 compound literal，函数返回后失效；复制到 `_uya_await_storage` 后由状态机持有，生命周期正确。

### 4.5 循环回跳逻辑（`while`）

- 由 `emit_async_while_with_await`、`emit_async_while_loopback_or_exit` 等与 `emit_async_continuation` 协作完成：resume 后先执行 await 之后的语句，再根据条件回到循环头或落到循环外下一 segment。
- 内层 `while` 与外层 `for` 同时存在时，收集层用 `enclosing_while` 优先，避免错误归属。

### 4.6 `for` 循环内含 await

- **范围 `for`**：循环变量、上界（及丢弃元素时的内部计数）写入状态机合成字段（如 `__uya_fe_*`），与 `while` 类似地做「条件 → 段内代码 → await 分裂 → continuation 回跳或退出」。
- **定长数组 `for`**：合成索引/长度；**元素变量**需进入 `_uya_loc_*`（或等价字段），以便跨 await 绑定；元素类型在 hoist 阶段可从函数体 AST / 形参类型回退解析（`c99_async_for_array_elem_type_c` 等）。
- **已覆盖**：范围 `for`、定长数组值/引用迭代、**具体 struct 迭代器值绑定** `for iter |v|`，以及**具体 struct 迭代器引用绑定** `for iter |&x|` 与 `@async_fn + @await` 的组合。
- **显式边界**：**接口值迭代**是同步 checker 也不支持的通用语言边界，在 `@async_fn + @await` 下继续保持明确编译错误。

### 4.7 标识符重写

- `get_c_name_for_identifier_ref`：将 `async_local_names` 中的名字映射为 `s->_uya_loc_*`；await 绑定映射为 `s->_uya_bind_*`。

### 4.8 复合表达式中的 `try @await`

- 赋值 RHS、return 表达式等复合场景（例如 `total = total + (try @await foo())`、`return 1 + (try @await foo())`）现已纳入 async transform 的 replay/substitution 路径。
- 相关实现会先为嵌套 `try @await` 建立绑定与 continuation，再回放外层表达式，避免继续退回旧的“只识别单一 var_decl 形状”的路径。
- 固定回归：`tests/test_async_compound_try_await.uya`。

---

## 5. 状态转换示意

以 `async_copy` 为例：

```
state 0 ──────────────────────────────────────────────────────────────┐
    │ await_fut = try reader.read();  state=1                          │
    ▼                                                                  │
state 1 (poll reader)                                                  │
    │ n = p.u.Ready                                                    │
    │ if n==0 return Ready(s->_uya_loc_total)                          │
    │ await_fut = try writer.write();  state=2                         │
    ▼                                                                  │
state 2 (poll writer)                                                  │
    │ written = p.u.Ready                                              │
    │ total += written                                                 │
    │ if written<n return Ready(s->_uya_loc_total)                     │
    │ await_fut = try reader.read();  state=1 ─────────────────────────┘
    │ return Pending
```

---

## 6. 已知限制与待修复

| 问题 | 状态 | 说明 |
|------|------|------|
| test_async_copy / block_on | ✅ 已修 | 历史 ASan 问题已处理；保持 `test_async_copy.uya` 回归 |
| Poll / `Future<!T>` 类型链 | ✅ 主路径已对齐 | 详见 `test_async_state_machine.uya` 等 |
| 循环变量持久化 | ✅ 通用提升 | 顶层 `var` → `_uya_loc_*`，不再依赖 `n`+`written` 特判 |
| 无 `@await` 的 `@async_fn` 同步语句 / `try !void` | ✅ 已修 | `gen_async_function_stage_b` 现会先发出函数体再包装 `Poll.Ready`；回归见 `tests/test_async_codegen_edge_paths.uya` |
| await 循环间同步语句 | ✅ 已修复 | `tests/test_async_bug_b_sync_between.uya` |
| 复合表达式中的 `try @await` | ✅ 已修复 | 覆盖赋值 RHS 与 return 表达式；回归见 `tests/test_async_compound_try_await.uya` |
| 接口值迭代 + `@async_fn` | 显式通用语言边界 | 具体 struct 的值绑定 `for iter |v|` 与引用绑定 `for iter |&x|` 已支持；接口值迭代仍需显式报错 |

---

## 7. 涉及文件

| 路径 | 职责 |
|------|------|
| `src/codegen/c99/function.uya` | `collect_awaits_recursive`、`gen_async_function_stage_b`、`emit_async_*`、状态机生成 |
| `src/codegen/c99/internal.uya` | `async_collect_*`、缓冲区（含 `async_collect_enclosing_for`） |
| `src/codegen/c99/async_transform.uya` | 与 async 变换相关的辅助（若存在） |
| `src/codegen/c99/global.uya` | `get_c_name_for_identifier_ref` |
| `lib/std/async.uya` | `async_copy` 等 |
| `tests/test_async_copy.uya`、`tests/test_async_for_await.uya`、`tests/test_async_bug_*.uya`、`tests/test_async_compound_try_await.uya`、`tests/test_async_transport_fallthrough.uya`、`tests/test_async_codegen_edge_paths.uya` | 回归 |
