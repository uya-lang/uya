# @async_fn 通用协程变换设计

> **核对头（2026-10-19）**：这是一份**未被采纳**的备选设计，不是实现现状。本文主张"把状态机生成提升到 AST 变换层"，计划新增 `src/checker/async_transform.uya`；但该文件**不存在**（`ls src/checker/async_transform.uya` → No such file），`src/checker/` 下与 async 相关的只有 `async_frame_meta.uya`。
> 实际采用并落地的路线是 [plan_async_coroutine_transform.md](plan_async_coroutine_transform.md) 描述的 **C99 codegen 层递归段发射**：`gen_async_function_stage_b()`（`src/codegen/c99/function.uya:1855` 调用）、`emit_async_segment()`（`:5874`）、`emit_async_segment_with_control()`（`:5082`）仍在使用且是唯一路径。
> 本文的算法描述（分裂点标记 / 变量存活 / 线性化分段 / 状态机 AST）可作为未来重构参考；"实现位置""与现有代码的关系"两节与当前仓库不符。

## 目标

将 `@async_fn` 的状态机生成从 C99 codegen 层提升到 **AST 变换层**，使得：
- 变换后的 AST 是普通函数，codegen 无需任何 async 特殊逻辑
- 自动支持所有 Uya 控制流（while/for/if/break/continue/return + @await 任意组合）
- 自动分析跨 await 变量并提升到状态结构体

## 历史问题

codegen 层 `gen_async_function_stage_b()`（~800 行）曾通过模式匹配 AST 形状生成 C 状态机，只识别 `const x = try @await expr` 单一模式，对以下场景失败：
- Bug A: 连续 while+@await 循环
- Bug B: await 间同步代码丢失
- Bug C: return try @await inner()
- Bug D: 分裂点附近局部变量
- 复合表达式中的 `try @await`（如 `total = total + (try @await inner())`、`return 1 + (try @await inner())`）未被正确重放/替换

这些缺口已在主分支的通用 lowering / 回归中转正；复合表达式形态的固定回归为 `tests/test_async_compound_try_await.uya`。当前请以 [plan_async_coroutine_transform.md](plan_async_coroutine_transform.md) 为准。

## 变换算法

### 输入

```uya
@async_fn fn foo(a: i32, b: &Reader) Future<!usize> {
    var x: i32 = 0;
    while x < 10 {
        const n: usize = try @await b.read(buf, len);
        x = x + n as i32;
    }
    var y: i32 = compute(x);       // 同步代码
    const m: usize = try @await b.read(buf2, len2);
    return y as usize + m;
}
```

### 步骤 1：标记分裂点

遍历函数体 AST，为每个 `try @await` 标记唯一编号（split_id = 0, 1, 2, ...）。
同时记录每个 await 的：
- 所在语句的父 block 和索引
- 是否在循环内（while/for）
- await 操作数（Future 表达式）
- 绑定变量名和类型

### 步骤 2：变量存活分析

对每个局部变量，判断是否"跨 await 存活"：
- 定义在 await 之前，使用在 await 之后 → 需要提升
- 仅在同一个 await 段内定义和使用 → 不需要提升

简化版（保守但正确）：**所有函数体顶层声明的变量都提升**。
函数参数默认全部提升（已在当前方案中实现）。

### 步骤 3：线性化为段（Segments）

将函数体拆分为 N+1 个段（N = await 数量）：

```
Segment 0: 函数入口 → 第一个 await 之前的所有代码
Segment 1: 第一个 await 就绪后 → 第二个 await 之前的所有代码
...
Segment N: 最后一个 await 就绪后 → return
```

**关键**：段的切分不是简单的"按语句序号切"。需要处理控制流：

```
while cond {           // ← 这是一个"循环段入口"
    stmt_a;            // segment K 的一部分（循环体前半段）
    @await expr;       // ← 分裂点
    stmt_b;            // segment K+1 的一部分（循环体后半段）
}                      // ← K+1 执行完后，检查 cond，若真 → 回到 K
stmt_c;                // segment K+2
```

### 步骤 4：生成状态机 AST

**状态结构体**（AST_STRUCT_DECL）：
```uya
struct __async_foo {
    state: i32,
    await_fut: FutureInterface,
    // 提升的变量
    _loc_x: i32,
    _loc_y: i32,
    _bind_n: usize,
    _bind_m: usize,
    // 参数
    a: i32,
    b: &Reader,
}
```

**Poll 函数**（普通 AST_FN_DECL）：
```uya
fn __async_foo_poll(self: &void, waker: &Waker) Poll<!usize> {
    const s: &__async_foo = self as &__async_foo;
    
    if s.state == 0 {
        // Segment 0: 入口代码
        s._loc_x = 0;
        // 设置第一个 await
        s.await_fut = b.read(buf, len);  // Future 表达式
        s.state = 1;
        return Poll.Pending;
    }
    
    if s.state == 1 {
        // Poll 子 Future
        const p: Poll<!usize> = s.await_fut.poll(waker);
        if p is Pending { return Poll.Pending; }
        const r: !usize = p.Ready;
        if r is error { return Poll.Ready(error); }
        s._bind_n = r.value;
        
        // Segment 1: await 后的代码 + 循环回跳检查
        s._loc_x = s._loc_x + s._bind_n as i32;
        if s._loc_x < 10 {
            // 循环继续 → 重新设置 await，回到 state 1
            s.await_fut = b.read(buf, len);
            s.state = 1;
            return Poll.Pending;
        }
        // 循环退出 → 执行循环后代码
        s._loc_y = compute(s._loc_x);
        s.await_fut = b.read(buf2, len2);
        s.state = 2;
        return Poll.Pending;
    }
    
    if s.state == 2 {
        // Poll 子 Future
        const p: Poll<!usize> = s.await_fut.poll(waker);
        if p is Pending { return Poll.Pending; }
        const r: !usize = p.Ready;
        if r is error { return Poll.Ready(error); }
        s._bind_m = r.value;
        
        // Segment 2: 最终代码
        return Poll.Ready(Ok(s._loc_y as usize + s._bind_m));
    }
    
    return Poll.Pending;  // unreachable
}
```

**Wrapper 函数**（替换原函数）：
```uya
fn foo(a: i32, b: &Reader) Future<!usize> {
    const s: &__async_foo = malloc(sizeof(__async_foo));
    s.state = 0;
    s.a = a;
    s.b = b;
    return Future{ vtable: &__async_foo_vtable, data: s };
}
```

### 步骤 5：替换原 AST

在 program 的声明列表中：
1. 插入状态结构体声明
2. 插入 poll 函数声明
3. 替换原 @async_fn 为 wrapper 函数
4. 插入 vtable 常量

## 实现位置

新文件：`src/checker/async_transform.uya`

在 `checker_check` 完成后、`c99_codegen_generate` 之前调用。
或者作为 checker 的最后一步（在 main.uya 的 `checker_check` 之后）。

调用点：`src/main.uya` line ~2308

```uya
checker_check(&checker, merged_ast);
// 新增：协程变换
async_transform_all(&checker, merged_ast);
// 然后正常 codegen
c99_codegen_generate(&c99_codegen, merged_ast, ...);
```

## 需要生成的 AST 节点

变换需要创建新的 AST 节点。使用现有的 `ast_alloc_node` + arena 分配。

| 需要创建的节点 | AST 类型 |
|---------------|---------|
| 状态结构体 | AST_STRUCT_DECL |
| poll 函数 | AST_FN_DECL |
| wrapper 函数 | AST_FN_DECL |
| if 语句 (state check) | AST_IF_STMT |
| 赋值 (s.field = val) | AST_ASSIGN |
| 成员访问 (s.field) | AST_MEMBER_ACCESS |
| 函数调用 (poll) | AST_CALL_EXPR |
| return 语句 | AST_RETURN_STMT |

## 与现有代码的关系

变换完成后，`gen_async_function_stage_b()` 不再被调用。
可以逐步迁移：
1. 先实现新 pass，对新 pass 处理过的函数标记 `fn_decl_is_async = 0`
2. codegen 遇到 `is_async == 0` 走正常路径
3. 验证全部通过后，删除旧代码

## 验收

1. 所有 .pending 测试恢复为 .uya 并通过
2. 现有 async 测试不回归
3. make tests e 全量通过
4. make b 自举一致
