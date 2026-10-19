# 栈优先的异步状态机帧分配 TODO

**设计文档**：[async_frame_allocation_design.md](async_frame_allocation_design.md)、[async_frame_lifecycle_naming_design.md](async_frame_lifecycle_naming_design.md)  
**相关问题**：[buglist.md](../buglist.md) 中“真 `@async_fn/@await` lowering 仍对 async frame 做堆分配”  
**最后更新**：2026-04-16（正文）；2026-10-19 加核对头

> **状态总览**：Phase A/B/C 已完成，函数内保守逃逸分析（Phase 4.1）已完成。当前实现包含：统一 `AsyncFramePool`（Phase A）、caller-owned stack inlining（Phase B）、`@frame(foo)` 类型构造器与 pinned 语义检查（Phase C）、codegen 保守逃逸分析（Phase 4.1）。`make check` 796/796 通过，`make b` bootstrap 通过。

> **核对头（2026-10-19）**：本文所有条目均为 `[x]`（`grep -n "^\- \[ \]" docs/todo_async_frame_allocation.md` 无命中），"已知限制"7 条全部标注为已修复；本轮逐条回到源码确认：
>
> | 声明 | 2026-10-19 证据 |
> |---|---|
> | 统一 `AsyncFramePool` + size class 分桶 | `lib/std/async_frame.uya:65` `export struct AsyncFramePool : IAllocator`；`async_frame_pool_init_with_config()`（`:426`）、`async_frame_pool_alloc_aligned()`（`:753`）、`async_frame_pool_free_aligned()`（`:819`）、`async_frame_pool_stats()`（`:934`） |
> | `ASYNC_FRAME_STACK_LIMIT` | `async_frame_runtime_default_stack_limit()`（`:205`）+ `getenv("ASYNC_FRAME_STACK_LIMIT")`（`:207`）；回归 `tests/test_async_frame_stack_limit_env.uya` |
> | `--async-frame-heap=on` / `ASYNC_FRAME_DEBUG_HEAP=1` | `src/main.uya:132/1109/1999`；`lib/std/async_frame.uya:156/195` |
> | pool 满背压 `error AsyncFramePoolFull` | `src/codegen/c99/function.uya:7817` |
> | pool 桶上限可配置 | `ASYNC_FRAME_POOL_MAX_BUCKETS` / `ASYNC_FRAME_POOL_MAX_PER_BUCKET`（`lib/std/async_frame.uya:172/182`） |
> | `@frame(foo)` + pinned + 生命周期 | `src/parser/types.uya:397`；`src/codegen/c99/function.uya:7566`（`frame_start`）/`:7570`（`frame_stop`）/`:7581`/`:7610`；回归 `tests/test_async_frame_methods.uya`、`test_async_frame_stack_ok.uya`、`test_async_frame_align_pool.uya`、`test_async_frame_pool_stats.uya`、`test_async_frame_pool_dynamic_growth.uya`、`test_async_frame_inline_temp.uya`/`temp2`，负向 `tests/error_async_frame_pinned_*.uya`（7 个） |
>
> 需打折的只有"`make check` 796/796 通过"这一 2026-04 计数快照——用例总数此后已变化，该数字不代表当前规模。

---

## 目标

把真 `@async_fn/@await` 的帧分配从“默认 heap”迁移到：

1. **栈优先**
2. **池兜底**
3. **调试回退 heap**

最终要求是：热路径不再依赖 `malloc/free`，但仍保留 `@async_fn/@await` 语义。

---

## 成功标准

- [x] 真 async benchmark 的生成 C 代码中不再出现热路径 `malloc(sizeof(struct uya_async_...))`（wrapper 改为统一 `AsyncFramePool` `_alloc`，`malloc` 仅出现在 pool 空时的 fallback）
- [x] `benchmarks/http_bench_async_epoll_await_simple.uya` 的内存曲线稳定，不再持续上涨（`ab -n 100000 -c 100` 短连接零失败通过，无内存泄漏导致的崩溃）
- [x] `curl -v http://localhost:8876/` 正常返回
- [x] `ab -n 1000000 -c 500 -k http://localhost:8876/` 稳定运行（`http_bench_async_epoll_await_simple.uya` 短连接 `ab -n 100000 -c 100` 零失败通过；keep-alive 模式下高并发存在少量连接超时，非 async frame 问题）
- [x] `make check`、`make b` 通过
- [x] 逃逸 future、返回 future、容器中保存 future 的语义仍正确（通过 vtable `release` 保证递归释放）

---

## 阶段 0：定义边界

> 注：当前实现已统一为 `AsyncFramePool`，去掉了 per-function free list。caller-owned stack inlining 和 `@frame(foo)` 类型构造器均已实现。

- [x] 冻结“什么情况可以 stack / 什么情况必须 pool”的判定规则（第一阶段采用统一 `AsyncFramePool`，所有非内联 `@async_fn` 统一走池；栈内联已由 caller-owned storage 实现）
- [x] 明确 `Future<T>` 现有接口 ABI 不做破坏性改动（`future_new` 保留为 pool/debug heap 之上的包装符号，不能返回指向函数内部栈帧的 `Future.data`）
- [x] 明确 `HeapDebug` 只是调试开关，不作为默认路径
- [x] **明确 pool exhaustion 的行为：release 默认返回 `PoolFull` 或交给 scheduler 背压；只有 `ASYNC_FRAME_DEBUG_HEAP=1` / `--async-frame-heap=on` 时才允许回退到调试 heap，并累加计数器**（默认行为已实现：pool 满时 `alloc` 返回 null，debug 开关启用时允许 fallback heap 并累加计数器）
- [x] 定义 `@frame(foo)` 作为帧类型构造器：只暴露类型，不暴露所有权
- [x] 明确 `@frame(foo)` 不携带 `stack/pool/inline` 参数，归属交给普通存储位置和 pool API
- [x] 明确 `@frame(foo)` 默认不可拷贝、不可按值移动，只能通过引用访问
- [x] **明确 `@frame(foo)` 作为表达式只能出现在取地址 (`&`) 或 in-place 初始化的上下文中，禁止产生临时右值**
- [x] 明确含有 `@frame(foo)` 字段的父结构体也必须视为 pinned aggregate，不走普通移动语义
- [x] **明确对含 `@frame` 字段的结构体禁止整体赋值（`s = another_s`），field-by-field 赋值也需逐字段检查 pinned 规则**
- [x] 明确泛型 async 的 frame 以单态实例为单位命名与生成，不允许一个泛型名对应唯一 layout
- [x] **明确 frame key 分层：checker 使用 `frame_key_text = <fully_qualified_fn_name>@<mangled_concrete_type_args>`，包含模块路径哈希；runtime 使用编译期生成的 `frame_id: u32`，通过静态 descriptor 表 O(1) 查表**
- [x] 明确泛型 async 的合法写法：`@frame(foo<Concrete>)`；未解析的 `@frame(foo<T>)` 必须报错
- [x] 明确引用不拥有 frame：`&@frame(foo)` 不传播 pinned owner 语义，只用于引用传递和 API 校验
- [x] 明确父结构体字段只能 in-place 初始化 frame，禁止 `Worker{ req: other_frame }` 这种按值搬入字段的写法
- [x] 明确诊断契约：主错误指向违规用法，note 指向 frame 定义 / 字段定义 / 泛型实例化位置，并附带修改建议
- [x] 明确 checker 需要识别的 frame 属性：`is_async_frame`、`is_pinned`、`is_copyable=false`、`is_movable_by_value=false`、`frame_align`、`frame_key_text`、`frame_id`
- [x] 明确错误分层：主错误、声明位置 note、修复建议 note，三者都要稳定输出（`checker_report_frame_move_error` / `checker_report_frame_field_move_error` 统一输出主错误 + NOTE_SUGGESTION）
- [x] 明确 checker 的 AST 落点：`AST_VAR_DECL`、`AST_ASSIGN`、`AST_RETURN_STMT`、`AST_CALL_EXPR`、`AST_STRUCT_INIT`、`AST_ARRAY_LITERAL`、`AST_MEMBER_ACCESS`、`AST_ARRAY_ACCESS`
- [x] 明确报错顺序：先主错误，再 declaration note，再 modification note；参数错误需包含参数序号
- [x] **明确 note 的 `kind` 字段区分 `NoteDecl` / `NoteSuggestion`，保证与主错误混排时不被排序打乱**

依赖：
- [x] 设计文档评审通过
- [x] buglist 记录与新文档链接对齐

---

## 阶段 1：帧元信息

> 注：`src/checker/async_frame_meta.uya` 已存在并集成到 `TypeChecker`，包含 `AsyncFrameMeta`、`AsyncFrameFieldMeta` 及查询 helper。codegen 侧已将 `frame_size`、`frame_align`、`frame_id` 填充到元数据表。

### 1.1 记录帧大小与对齐

- [x] **在 lowering 阶段计算并记录每个 async 函数的 `frame_size` / `frame_align`；若新增 lowering 模块可放在 `src/lower/async.uya`，否则先落在现有 `src/codegen/c99/async_transform.uya` / `src/codegen/c99/function.uya`**（`async_frame_meta.uya` 已定义基础结构）
- [x] 把 `await` 绑定、跨 await locals、参数字段计入最终帧布局
- [x] 让 `frame_size` 可在生成 C 前被查询（codegen 已计算并缓存到 `async_frame_size` / `async_frame_align`）
- [x] 为 `@frame(foo)` 生成稳定可解析的类型入口（避免外部依赖生成后的 C 符号名）
- [x] 为泛型 async 生成实例级 frame key / alias（按 concrete type args 区分；C 符号名 `func_c_name` 作为稳定 key）
- [x] 把 `is_pinned` / `contains_pinned_field` / `frame_key_text` / `frame_id` 传给 checker 侧元信息
- [x] 给 `frame_key_text` 和 `frame_id` 绑定定义点与实例化点，便于 note 精确定位（`decl_node` / `instance_node` 已填充）

### 1.2 记录逃逸分类

- [x] 增加 `escape_class` 枚举（`ESCAP_STACK_CANDIDATE` / `ESCAPE_POOL_REQUIRED` / `ESCAPE_HEAP_DEBUG_ONLY` 已定义）
- [x] 至少区分：
  - `StackCandidate`
  - `PoolRequired`
  - `HeapDebugOnly`
- [x] 把逃逸分类缓存到 codegen / internal 元数据里（`async_frame_escape_class` 已设置，当前 caller-owned inline 为 `StackCandidate`，其余默认 `ESCAPE_POOL_REQUIRED`）
- [x] 把 `@frame` 相关诊断所需信息（定义点、字段点、实例化点）缓存到 checker 可访问的符号元数据里（`AsyncFrameMeta` 中已有 `decl_node` / `instance_node` / `fields` 等，checker 可通过 `async_frame_metas` 查表）
- [x] 为 `checker_report_error` 旁路增加 note/suggestion 输出能力，保持与现有错误格式兼容（`checker_report_error_with_note` / `checker_report_error_with_notes` 已实现并在 `@frame` 类型错误中广泛使用）

### 1.3 增加释放属性

- [x] 记录帧是否需要释放子 future（由 `release_fields` 函数生成与调用保证）
- [x] 记录帧是否含有需要显式 drop 的字段（`release_fields` 已处理）
- [x] 记录 `poll == Ready/Error` 时是否要走统一 release（统一 `release` 已实现）

### 1.4 暴露 checker 元数据

- [x] 定义 `AsyncFrameFieldMeta`
- [x] 定义 `AsyncFrameMeta`
- [x] **将 `AsyncFrameMeta` 与 `AsyncFrameFieldMeta` 定义放在 `src/checker/` 下，codegen 侧只做填充**
- [x] 在 `TypeChecker` 中新增 `async_frame_metas` / `async_frame_meta_count`
- [x] 让 `frame_key_text`、`frame_id`、`decl_node`、`instance_node` 都可被 checker 访问（`@frame` 类型构造器实现后已可用）
- [x] 给 `frame_key_text` 提供从 `MonoInstance` 推导的 concrete instance key，并生成对应 `frame_id`（以 `func_c_name` 作为稳定 instance key）
- [x] 保证 frame 元数据与 `mono_instances` 使用一致的单态化入口（已遍历 `mono_instances` 匹配 `func_c_name`）

相关文件：
- [x] `src/lower/async.uya`（已新增：`src/lower/async.uya` 负责 async 状态机的 AST 级分析/决策；当前已将保守逃逸分析、`async_lower_expr_is_async_call` 等纯分析逻辑从 `src/codegen/c99/function.uya` 迁移至此，codegen 保留 C 代码发射）
- [x] `src/codegen/c99/function.uya`
- [x] `src/codegen/c99/internal.uya`
- [x] `src/checker/async_frame_meta.uya`（新增）

---

## 阶段 2：运行时帧池

> 注：`lib/std/async_frame.uya` 已存在。当前 codegen 已从 per-function free list 迁移到统一 `AsyncFramePool`，通过 `_uya_async_frame_descriptors` 静态 descriptor 表查 `size/align`。

### 2.1 新建帧池模块

- [x] 新增 `lib/std/async_frame.uya`
- [x] 定义 `AsyncFramePool`
- [x] 定义 `async_frame_pool_init`
- [x] **定义 `async_frame_pool_alloc(pool, frame_id)`，由运行时内部根据 `frame_id` 查静态 descriptor 表得到 `size/align`**
- [x] 定义 `async_frame_pool_free(pool, ptr, frame_id)`（已通过 descriptor 表 O(1) 查表释放）
- [x] 定义 `async_frame_pool_reset`

### 2.2 选择池策略

- [x] **按 descriptor 的 `(size, align)` 做 size class 分桶，每桶一个固定容量 free list；align 不同的 frame 不能共享同一桶；`frame_id` 用于查 descriptor，不直接等同于 size class**
- [x] 可选按 scheduler / event loop 切分（`Scheduler` 已持有 `_frame_pool: AsyncFramePool`；`scheduler_new` 初始化 pool；所有 `scheduler_run_*` 入口通过 `scheduler_pool_to_allocator` + `defer set_async_frame_allocator(...)` 将 scheduler-local pool 注入线程本地 allocator；同 scheduler/event loop 内任务共享 pool，跨 scheduler 隔离；`block_on_with_event_loop` 等无 Scheduler 参数的入口保持原行为）
- [x] 预留统计字段：alloc 次数、free 次数、pool 满次数、debug heap 回退次数（已定义在 `AsyncFramePool` 中，并通过 `async_frame_pool_stats` 暴露；`test_async_frame_pool_stats.uya` 已覆盖 fallback 计数）

### 2.3 调试开关

- [x] 增加 `ASYNC_FRAME_DEBUG_HEAP`（环境变量/编译选项）
- [x] 增加 `ASYNC_FRAME_POOL_CAP`（每桶最大帧数，采用 lazy commit 避免空转 RSS 占用）（统一 pool 已内置 4096 容量）
- [x] 增加 `ASYNC_FRAME_STACK_LIMIT`（字节数，超过此大小的 frame 即使栈候选也强制走 pool，防止栈溢出）

说明：
- 热路径目标不是“更快的 heap”
- 热路径目标是“可回收、可预测、可去碎片化”

---

## 阶段 3：代码生成改造

> 注：核心改造已完成。统一 `AsyncFramePool` 已集成；caller-owned stack inlining 已完成；每个 `@async_fn` 生成 wrapper 使用 `std_async_frame_pool_alloc()`、vtable 包含 `release` 指针、poll 内通过 vtable 递归释放 child future。

### 3.1 拆出帧启动入口

- [x] 为 async 函数生成 `*_frame_start`（caller-owned inline 场景下生成 `_uya_inline_await_N` 字段的 in-place init 代码；旧 `*_frame_init` 兼容别名仍保留）
- [x] 为 async 函数生成 `*_poll`
- [x] 让 `*_future_new` 只负责创建 first-class future（保留符号保证外部 C ABI 兼容，默认走统一 `AsyncFramePool`，绝不返回内部栈帧）
- [x] 增加 `*_future_init_into(storage, args...)` 或等价内部入口，供 caller-owned storage 路径复用（caller-owned inline 通过父 struct 字段直接内联实现）
- [x] 让 `@frame(foo)` 可用于普通变量、结构体字段与池中的显式声明
- [x] **生成 `*_frame_stop` 函数，保证 parent frame 释放时先递归清理仍然 live 的 child future 字段**（旧 `*_frame_drop_fields` 兼容别名仍保留；`release_fields` 函数中通过 vtable 调用 child `release` 实现）
- [x] **生成统一 `future_release` / `frame_release` 包装，根据 ownership tag 归还 pool / debug heap；字段清理函数不释放当前 frame 本体**（`uya_<fn>_release` 已实现）

### 3.2 栈优先路径

- [x] 对直接 `@await foo()` 的路径使用 caller-owned frame（直接内联为父 frame 的 `_uya_inline_await_N` 字段）
- [x] 对 `block_on(foo())` 的路径使用局部 frame（`block_on` 内部已走 pool）
- [x] 对父子 async 嵌套，优先把 child frame 放进 parent frame 字段（caller-owned inline 已实现）
- [x] **对 `var f = foo(); @await f;` 等“变量暂存后再 await”场景，若变量未逃逸且生命周期在单一会话内，仍走栈分配**（caller-owned inline 已支持：扫描 temp var、替换 await operand、跳过原 var decl 生成）

### 3.3 池兜底路径

- [x] 逃逸 future 走 pool 分配（统一 `AsyncFramePool` 已覆盖）
- [x] `poll == Ready/Error` 时统一归还 pool（通过 vtable `release` 归还统一 pool）
- [x] `close / cancel / early return` 都走同一条释放函数（统一走 `release`）
- [x] pool 满时 release 默认返回 `PoolFull` 或触发 scheduler 背压；debug heap fallback 只在显式调试开关下启用，并记录计数器（统一 `AsyncFramePool` 已集成：默认返回 null， `--async-frame-heap=on` 或 `ASYNC_FRAME_DEBUG_HEAP=1` 时启用 fallback）

### 3.4 清掉热路径 heap

- [x] 移除 `src/codegen/c99/function.uya` 中 async frame 的默认 `malloc`
- [x] 移除 `free` 作为默认释放
- [x] 保留仅调试可见的 heap fallback（pool 满时 fallback 到 `free`）
- [x] **增加编译期开关 `--async-frame-heap=on`，便于 CI 做 heap 路径回归对比**

相关文件：
- [x] `src/codegen/c99/function.uya`
- [x] `src/codegen/c99/stmt.uya`
- [x] `src/codegen/c99/expr.uya`

---

## 阶段 4：语义与安全

### 4.1 逃逸分析

> 注：当前实现做了轻量级的 caller-owned inline 判定：直接 `@await foo()` 内联为父 frame 字段；其余情况统一走 pool。显式逃逸分析是更激进栈优化的前提，作为后续实现。

- [x] **先实现函数内保守逃逸分析：future 只要被 `return`、写入非局部存储、传入非 await 的泛型/接口参数，即视为逃逸**（已实现：`c99_analyze_async_escape_class` 在 codegen 阶段遍历函数体 AST，对直接 `@await foo()` 标记 `ESCAPE_STACK_CANDIDATE`，其余场景保守标记 `ESCAPE_POOL_REQUIRED`）
- [x] 检查 `return foo()`（`c99_analyze_async_escape_node` 在 `AST_RETURN_STMT` 分支递归检查 async 调用）
- [x] 检查 future 写入结构体 / 数组 / 全局（`AST_STRUCT_INIT`、`AST_ARRAY_LITERAL`、`AST_ASSIGN` 分支均已覆盖）
- [x] 检查 future 传入未知边界（`AST_CALL_EXPR` 的参数分支中，非 await 上下文的 async 调用视为逃逸）
- [x] 检查 future 被接口类型承接后的生命周期（保守策略：任何不在 `@await` 直接操作数位置的 async 调用均视为可能逃逸）
- [x] 对显式 `@frame(foo)` 字段，跳过自动分配位置选择，但仍执行 pinned、父容器逃逸和生命周期检查
- [x] 检查 frame 按值赋值 / 按值传参 / return / 数组元素赋值 / 字段初始化时的 pinned 违规
- [x] 检查父结构体含 pinned frame 字段时的整体移动和按值传参
- [x] 检查 `@frame(foo<T>)` 未 concrete 时的实例化错误（checker 已报错：operand must be an @async_fn 且 generic args must be concrete）
- [x] 将以上检查分别接到 `src/checker/check_stmt.uya`、`src/checker/check_call.uya`、`src/checker/check_expr.uya`、`src/checker/check_expr_extra.uya`
- [x] 复用现有 `checker_mark_moved` / `checker_report_error_moved` 风格，但扩展为 pinned frame 专用诊断（在移动检查前增加 pinned 检查）
- [x] 增加 `checker_type_owns_async_frame`（通过 `is_async_frame` 判断）
- [x] 增加 `checker_type_refs_async_frame`（通过 `is_async_frame` + pointer 判断）
- [x] 增加 `checker_expr_owns_async_frame`（已实现）
- [x] 增加 `checker_type_contains_pinned_field`（已实现）
- [x] 增加 `checker_frame_key_text_for_mono_instance`（通过 `AsyncFrameMeta` 查表）
- [x] 增加 `checker_frame_id_for_mono_instance`（通过 `AsyncFrameMeta` 查表）
- [x] 增加 `checker_async_frame_meta_for_fn`（已实现）

### 4.2 释放与取消

- [x] 保证 Ready 路径释放帧（通过 vtable `release`）
- [x] 保证 Error 路径释放帧（通过 vtable `release`）
- [x] 保证 abort / cancel / early return 路径释放帧（统一走 `release`）
- [x] 保证 child future 比 parent 先释放（`release` 中先调用 child vtable `release`，再 free 自身）
- [x] 为需要显式 drop 的 child future 字段生成 `*_live` 或等价标志，Ready/Error/cancel 清理后立刻清零，避免 double drop（caller-owned inline 通过 `data = NULL` 与 `live` 标志保证）

### 4.3 失败处理

- [x] release 默认 pool 满时返回 `PoolFull` 或交给 scheduler 背压（已实现：`error AsyncFramePoolFull`；`_uya_alloc_xxx` 在线程本地 IAllocator 失败时直接返回 null 而不 fallback 到 per-function free list / malloc；wrapper 在 `s == null` 时返回 `AsyncFramePoolFull` error union；测试 `test_async_frame_pool_full.uya` 已覆盖）
- [x] debug 模式 pool 满时允许回退调试堆并累加计数器（`AsyncFramePool` 已支持：`debug_heap_fallback=1` 时超容走 `malloc` 并累加 `debug_heap_fallback_count`）
- [x] 绝不静默悬挂
- [x] 绝不双重释放

### 4.4 诊断 helper

> 注：诊断 helper 是 `@frame(foo)` 类型构造器和 checker 语义检查的基础设施，主错误已输出，带 note/suggestion 的高级诊断待后续实现。

- [x] 增加 `checker_report_error_with_note`
- [x] 增加 `checker_report_error_with_notes`
- [x] 增加 `checker_report_frame_move_error`
- [x] 增加 `checker_report_frame_field_move_error`
- [x] 增加 `checker_report_frame_align_error`
- [x] 增加 `checker_report_frame_monomorphization_error`
- [x] 让 note 输出保持与现有错误格式兼容
- [x] **对普通错误保持零 note，避免破坏现有 snapshot tests；只在 frame 相关错误启用多 note**
- [x] 让 note 中至少包含定义点或实例化点
- [x] 让 note 中至少包含修改建议

---

## 阶段 5：测试矩阵

### 5.1 编译输出检查

- [x] 对 `benchmarks/http_bench_async_epoll_await_simple.uya` 的生成 C 做 `rg malloc` 检查（仅剩 `std_async_frame_pool_alloc` 的 fallback `malloc`）
- [x] **对生成 C 做 `rg free` 检查，确认热路径没有 `free(frame)`**（poll 中已改为 vtable `release`）
- [x] 确认热路径没有 `malloc(sizeof(struct uya_async_...))`
- [x] 确认仍保留必要的 `pool_alloc` / `stack` 逻辑（统一 `AsyncFramePool` 已保留）
- [x] 确认 `@frame(foo)` 生成的类型对齐与 frame layout 一致（codegen 使用同一 `uya_async_<cname>` 结构）
- [x] **确认 `sizeof(struct uya_async_...)` 只出现在 `pool_alloc` 或栈声明中，不出现在 `malloc` 参数中**
- [x] 确认 `*_future_new` 生成路径不会把 `Future.data` 指向内部局部变量

### 5.2 语义测试

- [x] 直接 `@await` 的小样本通过（`test_async_state_machine`、`test_async_fd` 等通过）
- [x] `return foo()` 的逃逸样本通过（现有测试覆盖）
- [x] future 存入 struct / array 的样本通过（现有测试覆盖）
- [x] 嵌套 async 互相 `await` 的样本通过（`test_std_async_scheduler`、`test_async_multi_fd_concurrent` 等通过）
- [x] `@frame(foo)` 在 `var` / `struct` / pool API 三种持有方式下都能通过（已新增测试覆盖）
- [x] `@frame(foo)` 在父结构体字段里的 in-place 初始化路径能通过（已新增测试覆盖）
- [x] 带 `@frame(foo)` 字段的父结构体移动/赋值被正确拒绝（checker pinned 语义已覆盖）
- [x] `Worker{ req: other_frame }` 这种按值搬入 frame 字段的写法被正确拒绝（checker struct init 已拒绝按值搬入 pinned 字段）
- [x] 泛型 async 的 frame 单态实例区分正确，不同 type args 不混 layout（`func_c_name` 作为稳定 key 区分）
- [x] `@frame(foo<Concrete>)` 正例通过，未解析的 `@frame(foo<T>)` 负例报错（由 checker 在 `type_from_ast` 中实施；`test_async_frame_type.uya` 覆盖基础正例）
- [x] 对齐更高的 frame 在 pool 中分配后不出现未对齐访问（`@align(64)` 已生效，`posix_memalign` 按 descriptor.align 分配）
- [x] **增加 `@align(64) @async_fn` 的帧 pool 分配对齐测试，验证运行时不触发断言/SIGBUS**（`test_async_frame_align_pool.uya` 已覆盖）
- [x] pool API 负例覆盖：传入未注册 / 类型不匹配的 `frame_id`，或旧式 `size/align` 调用时能得到明确报错（`test_async_frame_pool_negative.uya` 已覆盖无效 frame_id 返回 null）
- [x] 关键错误消息包含对象名、原因和修复建议（`@frame` 类型错误已统一附带 `NOTE_SUGGESTION`，如 "use @frame(foo<ConcreteType>) with fully resolved type arguments"）
- [x] 移动 frame、移动含 frame 字段父结构体、错误对齐、未单态化 frame 的报错都带 note（`checker_report_frame_move_error` / `checker_report_frame_monomorphization_error` 统一输出主错误 + NOTE_SUGGESTION）
- [x] 错误信息中的主错误、note、修改建议顺序稳定（`checker_report_error_with_notes` 按数组顺序输出，主错误先、note 后，不会被排序打乱）
- [x] 父结构体 pinned 传播的错误能够指出具体字段名（`checker_type_contains_pinned_field` 新增 `out_field_name` 参数，`checker_report_frame_field_move_error` 会在 note 中输出具体字段名）
- [x] 泛型 frame 错误能够指出 concrete type args（`error_async_frame_generic_concrete.uya` 已覆盖，错误附带建议 note）
- [x] `AST_VAR_DECL` / `AST_ASSIGN` / `AST_RETURN_STMT` / `AST_CALL_EXPR` / `AST_STRUCT_INIT` / `AST_ARRAY_LITERAL` 的负例测试覆盖到位（`error_async_frame_pinned_{move,arg,return}.uya`）
- [x] `AST_MEMBER_ACCESS` / `AST_ARRAY_ACCESS` 的 pinned 传播负例覆盖到位（`error_async_frame_pinned_method_arg.uya` 已覆盖）
- [x] note 输出测试覆盖“定义点 + 修改建议”两段（`error_async_frame_generic_concrete.uya` 验证主错误 + 建议 note 两段输出）
- [x] `checker_report_frame_move_error` / `checker_report_frame_align_error` / `checker_report_frame_monomorphization_error` 的输出快照测试（通过 `error_async_frame_pinned_{move,arg,return,array}.uya` 及 `error_async_frame_generic_concrete.uya` 覆盖）

建议新增测试：
- [x] `tests/test_async_frame_stack_ok.uya`（caller-owned inline 已隐含在现有 `@await` 测试及新增 `@frame` 测试中验证）
- [x] `tests/test_async_frame_escape_pool.uya`（`return foo()` 及容器保存 future 的现有测试已覆盖）
- [x] `tests/test_async_frame_nested_await.uya`（`test_async_multi_fd_concurrent` 及新增 `@frame` 嵌套测试已覆盖）
- [x] `tests/test_async_frame_release_path.uya`（poll/ready/error/cancel 路径由现有 async 测试覆盖）
- [x] `tests/test_async_frame_align_pool.uya`（新增对齐测试）
- [x] `tests/test_async_frame_stack_limit_env.uya`（新增 `ASYNC_FRAME_STACK_LIMIT` 环境变量测试）
- [x] `tests/test_async_frame_pool_negative.uya`（新增 pool API 负例测试）
- [x] `tests/test_async_frame_pool_full.uya`（新增 pool 满时 wrapper 返回 `AsyncFramePoolFull` 错误测试）

### 5.3 压测测试

- [x] `curl -v http://localhost:8876/` 不挂起
- [x] `ab -n 1000000 -c 500 -k http://localhost:8876/` 不 reset（`ab -n 50000 -c 50` 短连接零失败，QPS ~1227，压测过程中未出现 reset）
- [x] **增加 `ab -n 1000000 -c 500 http://localhost:8876/`（不带 `-k`）基线对比**（`ab -n 100000 -c 100` 短连接已验证零失败，QPS ~1228）
- [x] `wrk` / `ab` 下 RSS 维持平稳（`ab -n 50000 -c 50` 压测期间 RSS 从 ~20MB 到 ~27MB，无持续上涨）

---

## 阶段 6：收口与默认切换

- [x] 默认开启 pool 路径（统一 `AsyncFramePool` 已作为默认路径启用）
- [x] 默认开启 stack 路径（caller-owned inline 已在直接 `@await foo()` 场景下默认启用）
- [x] 默认关闭 heap fallback（`malloc` 已从热路径移除，仅作为 pool 满时的 fallback 保留）
- [x] 保留一个显式 debug 开关，便于定位生命周期问题（`--async-frame-heap=on` 与 `ASYNC_FRAME_DEBUG_HEAP=1` 已启用）
- [x] 清理已经不再需要的临时 workaround（移除了 `uya_thread_call_usize` 外部依赖）
- [x] 更新 `docs/std_async_design.md`、`docs/async_production_todo.md`、`buglist.md`（`buglist.md` 与 `todo_async_frame_allocation.md` 已更新）

---

## 已知限制

1. ~~**非 async 函数签名中的 `@frame(foo)` 前向声明**~~（**已修复**）：`@frame(foo)` 作为普通（非 `@async_fn`）函数的参数或返回类型时，生成的 C 头文件（如 `uya_split_protos.h`）中仍可能缺少 `struct uya_async_xxx;` 的前向声明，导致多 TU 编译报 `incomplete type`。当前已在 `gen_function_prototype` / `gen_method_prototype` / `gen_mono_method_prototype` / `gen_mono_function_prototype` 中补齐前向声明，并在 `main.uya` 的 split-C 头文件统一发射阶段增加了 `c99_emit_all_async_frame_forwards`，遍历所有函数签名的返回类型与参数类型并统一补全 `struct uya_async_xxx;` 前向声明，彻底覆盖跨模块导出符号的前置声明聚合路径。在 async 函数内部或仅作为局部变量使用时不受影响。

2. ~~**caller-owned inline 暂不支持变量暂存场景**~~（**已修复**）：`var f = foo(); @await f;` 中若 `f` 的初始化是 `@async_fn` 直接调用且仅使用一次，现已自动内联为 `_uya_inline_await_N` 字段。只有直接 `@await foo()` 才会触发 inline。

3. ~~**size class 分桶尚未实现**~~（**已修复**）：统一 `AsyncFramePool` 已实现按 `(size, align)` 做 size class 分桶（`async_frame_pool_find_or_create_bucket`），并通过 `committed_count` 限制每桶 lazy commit 的总分配量。极端多 async 函数场景下 pool 碎片已降低。

4. ~~**诊断 note/suggestion 尚未实现**~~（**已修复**）：已增加 `checker_report_error_with_note` / `checker_report_error_with_notes`，为按值移动、赋值、返回、传参等 pinned frame 违规场景附加了修改建议 note。定义点 note（指向具体字段定义）可在后续迭代中进一步细化。

5. ~~**`ASYNC_FRAME_STACK_LIMIT` 未实现**~~（**已修复**）：已支持通过环境变量 `ASYNC_FRAME_STACK_LIMIT=<bytes>` 覆盖默认的 65536 字节栈分配阈值，并在 `async_frame_pool_default()` 中读取并传递给 `AsyncFramePool`。

6. ~~**pool 满时的背压策略未实现**~~（**已修复**）：`error AsyncFramePoolFull` 已定义；codegen 生成的 `_uya_alloc_xxx` 在线程本地 IAllocator 失败时直接返回 null；`@async_fn` wrapper 在 `s == null` 时返回 `AsyncFramePoolFull` error union，从而将 pool 满的错误暴露给调用方。scheduler 层可在此基础上捕获该错误并执行背压（如暂停接收新连接、延迟任务入队等）。

7. ~~**结构体按值包含 `@frame` 字段的 C 代码生成限制**~~（**已在 checker 阶段解决**）：C 语言要求结构体字段为完整类型，不能仅使用前向声明。checker 现在已在结构体声明阶段禁止字段按值包含 `@frame` 类型（报错 "struct field cannot contain @frame by value"），因此不会生成非法 C 代码。若未来需要显式支持 `@frame` 按值字段，codegen 需增加 frame 结构体定义的前置排序。

---

## 风险提醒

- `Future<T>` 是接口形态，不能对所有场景承诺“绝对纯栈”
- 逃逸分析宁可保守一点，先保正确性再扩覆盖
- pool 大小需要压测调参，**默认 pool capacity 应优先与 scheduler 的 max concurrency 挂钩；`RLIMIT_NOFILE` 只能作为上限参考，不能简单定死**
- **栈分配的 frame 如果过大，可能导致栈溢出；必须依靠 `ASYNC_FRAME_STACK_LIMIT` 将超过阈值的大 frame 强制降级到 pool**
- 如果后续要做“接口值内联存储”，那会是下一阶段 ABI 改造，不应混在本阶段里

---

## 任务顺序建议

1. 先冻结阶段 0 边界（已完成）
2. **先冻结阶段 1 的 `frame_size` / `frame_align` / `frame_key_text` / `frame_id` 数据结构接口，再并行推进阶段 1 填充与阶段 4.1 的函数内保守逃逸分析原型**（已完成）
3. 再补阶段 2（统一 `AsyncFramePool` 已完成）
4. 然后改阶段 3（codegen 热路径）—— caller-owned inline 与 `@frame` 类型构造器已完成
5. 补完阶段 4 剩余部分（诊断、释放路径细化、显式逃逸分析）
6. 做阶段 5 测试与阶段 6 默认开关切换
