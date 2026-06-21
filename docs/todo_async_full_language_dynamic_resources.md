# Uya 异步生产化 TODO（完整语法 + 动态资源）

**最后更新**：2026-06-17  
**当前定位**：本文件是当前“让异步编程生产级可用”目标的权威 TODO。  
**口径说明**：在本文件完成前，`docs/async_production_todo.md`、`docs/async_status_matrix.md`、`docs/std_async_design.md` 中“量产已完成”或“主链路已收口”的表述都只能视为历史阶段结论，不能直接当作本目标的完成依据。

## 源码现状审计

### 1. 运行时资源仍有明显硬编码

| 模块 | 现状 | 影响 |
|------|------|------|
| `lib/std/async_event.uya` | `LinuxEpoll` 的 slot / event 数组均固定 `1024`，`find_slot()` 线性扫描固定容量 | 并发 fd 上限、退化 O(n)、容量达到上限时只能报错 |
| `lib/std/async_scheduler.uya` | `TaskQueue<T>` 默认队列已自动增长；scheduler 自带 `_frame_stack_buffer[8192]`，inline repoll 上限默认 `1024` | 池后备缓冲和默认轮询策略仍需继续收口 |
| `lib/std/thread.uya` | 仍保留 `THREAD_POOL_MAX_WORKERS=32`、`THREAD_POOL_MAX_PENDING=32`、`THREAD_POOL_MAX_TASK_SLOTS=16` 兼容常量；`ThreadPoolConfig.submit_strategy` 已显式固定默认策略为 queue-or-error（共享 FIFO，容量不足返回资源错误） | 容量与饱和策略虽然已显式化，但仍缺更丰富的生产级策略与动态扩缩容 |
| `lib/std/async_frame.uya` | `ASYNC_FRAME_POOL_MAX_BUCKETS=128`、`ASYNC_FRAME_POOL_MAX_PER_BUCKET=4096`、descriptor 表固定 `512` | frame 元信息和池容量都有硬上限 |
| `lib/std/http/http1_async.uya` | 多处请求头 scratch buffer 固定 `4096` | 大 header / 扩展请求场景不是真动态 |

### 2. 编译器 async 相关容量仍有硬编码

| 模块 | 现状 | 影响 |
|------|------|------|
| `src/codegen/c99/internal.uya` | `C99_ASYNC_MAX_AWAITS=4096` 且大量数组按此大小静态展开 | 仍是固定容量设计，不是动态结构 |
| `src/checker/async_frame_meta.uya` | `MAX_ASYNC_FRAME_METAS=512` | async frame 元信息会在大工程中截断 |
| `src/codegen/c99/main.uya` | 生成 `_uya_async_frame_descriptors` 时仍按 `MAX_ASYNC_FRAME_METAS` 截断 | codegen 与 runtime descriptor 上限耦合 |

### 3. 已知语法/语义缺口仍存在

| 位置 | 现状 | 证据 |
|------|------|------|
| `src/checker/check_node_extra.uya` / `src/codegen/c99/function.uya` | `@async_fn` 中迭代器 `for` 当前只支持“具体 struct + 值迭代”；接口类型变量的 `for` 迭代是同步也不支持的通用语言边界，iterator ref 绑定已转为正向回归 | 正向回归：`tests/test_async_for_await.uya`、`tests/test_async_for_iterator_ref_await.uya`；接口值反向回归：`tests/error_for_iterator_interface_value.uya`（同步 checker 失败）与 `tests/error_async_for_iterator_interface_await.uya`（async checker 失败） |
| `docs/std_async_design.md` | nested future 口径已从“Future<Future<T>>.poll 一概受限”改成当前真实边界 | 值类型双层 poll、无 await 的 `!Future<Future<T>>` + 同步 `try` 返回、C99 发射与 host C 编译均由 `tests/test_async_nested_future_poll.uya` / `tests/verify_async_nested_future_boundary.sh` 固定为正向回归 |
| `tests/error_async_too_many_awaits.uya` / `tests/error_async_too_many_params.uya` | 当前测试仍把固定上限失败当成正确行为 | 与“资源动态化”目标正面冲突 |
| `tests/verify_async_full_language_matrix.sh` | 当前脚本已是高价值基线入口，但还不能单独证明“完整函数体语法已收口” | 它目前覆盖已存在主链路回归、明确禁止位置、nested future 专项和迭代器 interface/ref 边界；仍不覆盖动态容量闸门 |

### 5. 三类问题明确区分

以下从审计结果中明确区分三类问题：

| 类别 | 具体项 | 位置 |
|------|--------|------|
| **通用语言边界** | iterator `for` 接口值（同步与 async checker 均失败，非 async 独有缺口） | `src/checker/check_node_extra.uya`、`tests/error_for_iterator_interface_value.uya`、`tests/error_async_for_iterator_interface_await.uya` |
| 语法/语义不支持 | iterator `for` 引用绑定 + `@await`（历史缺口，现已转入 `tests/test_async_for_iterator_ref_await.uya` 正向回归） | `src/codegen/c99/function.uya`、`tests/test_async_for_iterator_ref_await.uya` |
| 语法/语义已收口 | 无 await 的 `!Future<Future<T>>` + 同步 `try` 返回（C99 发射与 host C 编译已由专项脚本验证） | `tests/test_async_nested_future_poll.uya`、`tests/verify_async_nested_future_boundary.sh` |
| **编译器内部固定容量** | `C99_ASYNC_MAX_AWAITS=4096` 静态数组 | `src/codegen/c99/internal.uya` |
| 编译器内部固定容量 | `MAX_ASYNC_FRAME_METAS=512` | `src/checker/async_frame_meta.uya` |
| 编译器内部固定容量 | frame descriptor 静默截断到 `512` | `src/codegen/c99/main.uya` |
| **运行时/协议层固定容量** | epoll slot/event `1024`、`find_slot()` 线性扫 | `lib/std/async_event.uya` |
| 运行时/协议层固定容量 | `TaskQueue<T>` 默认队列已自动增长，显式容量队列仍保留调用方配置上限 | `lib/std/async_scheduler.uya` |
| 运行时/协议层固定容量 | `_frame_stack_buffer[8192]`、inline repoll `1024` | `lib/std/async_scheduler.uya` |
| 运行时/协议层固定容量 | `ASYNC_FRAME_POOL_MAX_BUCKETS=128`、`MAX_PER_BUCKET=4096`、descriptor 表 `512` | `lib/std/async_frame.uya` |
| 运行时/协议层固定容量 | `THREAD_POOL_MAX_WORKERS=32`、`MAX_PENDING=32`、`MAX_TASK_SLOTS=16`、`fork()` fallback | `lib/std/thread.uya` |
| 运行时/协议层固定容量 | 请求头 scratch buffer 固定 `4096` | `lib/std/http/http1_async.uya` |

## 完成定义

- runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。
## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

### 1.1.1 当前语法覆盖快照（基于现有仓库）

| 语法类别 | 当前证据 | 状态 | 说明 |
|------|------|------|------|
| `@async_fn` / `@await` 基础解析与上下文约束 | `tests/test_async_await_parse.uya` | 已有基础覆盖 | 证明基础 parse 与返回类型约束可工作，但不代表完整函数体语法都已接通 |
| Ready/Pending 基本语义 | `tests/test_async_await.uya`、`tests/test_async_await_ready.uya`、`tests/test_async_multiple_await.uya`、`tests/test_async_state_machine.uya` | 已有基础覆盖 | 覆盖单段与多段状态机的最小语义 |
| 局部变量声明 / 赋值 / 提前 return | `tests/test_async_control_flow_body.uya`、`tests/test_async_await_var.uya` | 已验证覆盖 | `docs/grammar_formal.md` 将 `var_decl`、`expr_stmt` 与 `return_stmt` 列为函数体 `statement`；`docs/uya.md` 第 3 章和 5.1 说明 `const`/`var`、赋值与 `return` 语义。回归覆盖 async 函数体内 `const`/`var` 声明、`i = i + 1`/`total = total + ...` 赋值、函数入口和尾部提前 `return`，以及 await 结果绑定后返回 |
| direct err-union await / 直接 `return error.X` | `tests/test_async_await_direct_err_union.uya`、`tests/test_async_return_error_direct.uya` | 已有覆盖 | 证明部分错误传播形态已打通 |
| `if / else / else if` + `@await` | `tests/test_async_if_await.uya`、`tests/test_async_else_if_await.uya` | 已有覆盖 | 仍只覆盖常见形态，不等于所有分支语法 |
| `while` / 连续多循环 / await 间同步语句 | `tests/test_async_while_multi_await.uya`、`tests/test_async_bug_a_two_while.uya`、`tests/test_async_bug_b_sync_between.uya`、`tests/test_async_bug_d_nested_block.uya` | 已有覆盖 | 这些是当前最强的循环 lowering 回归 |
| `for range` + `@await` | `docs/grammar_formal.md` 的 `for range '\|' ID '\|'` 与 `for range {}`；`docs/uya.md` 第 8 章整数范围形式；`tests/test_async_for_await.uya`、`tests/test_async_large_state_machine_syntax.uya` | 已验证覆盖 | `@async_fn` 中 `for 0..3 |k|` 和 `for 0..n |k|` 循环体内 `try @await` 已有正向回归，覆盖范围循环变量参与 await 后累加与状态机跨段恢复 |
| 定长数组值迭代 / 定长数组引用迭代 / 具体 struct 迭代器值迭代 + `@await` | `tests/test_async_for_await.uya` | 已有覆盖 | 已覆盖 `for arr |e|`、`for arr |&x|` 与 `for iter |v|` 的 async 体回归；后续叶子任务将分别核对和归档 |
| 迭代器 interface/ref 边界 + `@await` | `tests/error_for_iterator_interface_value.uya`、`tests/error_async_for_iterator_interface_await.uya`、`tests/test_async_for_iterator_ref_await.uya` | 已有覆盖 | 接口值 `for` 是同步也不支持的通用语言边界；`for iter |&x|` 引用绑定已作为 async 正向回归覆盖 |
| 复合表达式 / await 绑定跨段重放 / 大状态机 | `tests/test_async_compound_try_await.uya`、`tests/test_async_fn_multi_segment_unwrap.uya`、`tests/test_async_await_limits_and_segments.uya`、`tests/test_async_large_state_machine_syntax.uya` | 已有覆盖 | 覆盖 RHS/return 表达式、多段 bind 依赖，以及包含顺序 20 awaits、循环、跨段变量、副作用和表达式链的大状态机语法回归 |
| 方法 / 接口 / 局部接口 future | `tests/test_async_method_interface.uya`、`tests/test_async_local_interface_await.uya` | 已有覆盖 | 证明结构体方法、方法块和接口签名主链路可用 |
| 泛型函数 / 泛型方法 / 接口方法 / 结构体外方法块 | `docs/grammar_formal.md` 的 `fn_decl`、`method_decl`、`struct_method_block`、`method_sig`；`docs/uya.md` 第 18.3.1；`tests/test_async_fn_basic.uya`、`tests/test_generic_async_function_codegen.uya`、`tests/test_async_method_interface.uya` | 部分覆盖，泛型 async 方法仍为缺口 | 顶层泛型 `@async_fn`、接口 `@async_fn` 方法签名、结构体内部 async 方法与结构体外方法块 async 实现已有正向回归；本轮临时正向回归 `AsyncBox { @async_fn fn choose<T>(...) Future<!T> }` 暴露 C99 未生成 `uya_AsyncBox_choose_i32`，因此泛型方法与 `@async_fn` 的组合不能标为已验证覆盖 |
| caller-owned inline / frame / 局部定长数组 | `tests/test_async_frame_inline_temp.uya`、`tests/test_async_frame_inline_temp2.uya`、`tests/test_async_fn_local_fixed_array.uya`、`tests/test_async_frame_type.uya` | 已有覆盖 | 更偏 codegen/frame correctness，不等于完整语法 |
| runtime / scheduler / real client 集成 | `tests/test_std_async_scheduler.uya`、`tests/test_async_compute_types.uya`、`tests/test_http1_async_client.uya` | 已有覆盖 | 是“真实使用链路”证据，但不覆盖全部语法 |
| sync/async 函数体对齐矩阵 | `tests/test_async_sync_body_matrix.uya`、`tests/verify_async_full_language_matrix.sh` | 已有覆盖 | 用同步/async 成对断言覆盖局部变量、提前 return、分支、循环、`match`、`catch`、`defer/errdefer` 等组合语法 |
| async 体内 `match` | `tests/test_async_sync_body_matrix.uya` | 已有覆盖 | dedicated async-body 回归已比较同步/async 的 `match` 表达式语义 |
| async 体内 `catch` 与 `@await` 组合 | `tests/test_async_sync_body_matrix.uya`、`tests/test_async_catch_await.uya` | 已有覆盖 | dedicated async-body 回归已覆盖 `try/@await` 后接 `catch` 恢复、`@await` 错误联合结果交给 `catch`、catch 体内 `@await` 与提前 return |
| async 体内 `defer / errdefer` | `tests/test_async_sync_body_matrix.uya` | 已有覆盖 | dedicated async-body 回归已覆盖 success/error 两条清理顺序 |
| 宏展开后的 expr / stmt 进入 async lowering | `tests/test_async_macro_expand.uya`、`tests/programs/test_ai_prompt_async_macro_combo.uya` | 已有覆盖 | 已验证 pre-await 求值不会在 poll/resume 间丢失或重复执行，程序级 macro combo 也可 build/run |
| `Future<Future<T>>` / nested future poll | `tests/test_async_nested.uya`、`tests/test_async_nested_future_poll.uya`、`tests/verify_async_nested_future_boundary.sh`、`docs/std_async_design.md` | 已收口为正向回归 | 值类型 `Future<Future<T>>` 双层 poll 已有正向回归；无 await 的 `!Future<Future<T>>` + 同步 `try` 返回、C99 发射与 host C 编译也已由专项脚本验证通过 |
| 大状态机 / 大量 await / 参数与 meta 动态扩容 | `tests/error_async_too_many_awaits.uya`、`tests/error_async_too_many_params.uya` | 历史已知限制 | 这些旧测试本身就是“仍有固定上限”的证据 |

> 盘点汇总：

> 待清理项登记（silent truncation / emitter stderr / workaround）：
> - `src/codegen/c99/function.uya:758`："简化处理：使用临时缓冲区" → 确认是否仍为临时方案
> - `src/checker/async_frame_meta.uya:41,49,58`：`MAX_ASYNC_FRAME_METAS=512` 静默截断 → 待 Phase 2 动态化
> - `src/codegen/c99/main.uya`：frame descriptor 静默截断到 512 → 待 Phase 2 动态化
> - `tests/error_async_too_many_awaits.uya`、`tests/error_async_too_many_params.uya`：旧人为上限测试 → 待 Phase 2 替换为压力测试
> - `tests/test_async_defer_errdefer.uya`：已迁入 `try @await` 错误传播触发 `errdefer` 的正向回归；默认回归不再排除旧边界文件
> - **已有覆盖**（20项）：基础解析、Ready/Pending、err-union await、if/else if、while、for range/array/iter、复合表达式、大状态机、方法/接口、frame、runtime/scheduler/client、sync/async对齐矩阵、match/catch/defer/errdefer、宏展开、nested future（边界明确）
> - **缺失覆盖**：暂无；后续继续审计非显式规范限制的 async 语法缺口
> - **历史已知限制**：固定上限测试（error_async_too_many_awaits/params）、iterator interface value for 不支持（同步与 async 通用语言边界）

> 建议把 [tests/verify_async_full_language_matrix.sh](../tests/verify_async_full_language_matrix.sh) 当作当前快照入口：
> 它当前能证明“已有高价值基线 + large state machine + 明确禁止位置 + nested future 专项 + 迭代器 interface/ref 边界”仍成立，但不能单独替代完整语法矩阵或动态容量闸门。

### 1.2 先补红测，再动实现

### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”

### 1.4 收口语法口径


## Phase 1.5：标准库手工 Future 清零迁移

> **用户新增要求（2026-06-17）**
>
> 标准库里的所有手工异步 `Future` 都要转成 `@async_fn` / `@await` 路线，并把任务拆解进本 TODO。

### 1.5.0 统计口径

> 当前口径已在完成归档固化；后续以 1.5.1 的“当前手工 Future 清单”和 1.5.6 的“runtime substrate 唯一例外集”为准。

### 1.5.1 当前手工 Future 清单（基于当前仓库）

| 模块 | 手工 Future | 类型 | 当前作用 |
|------|------|------|------|
| `lib/std/async.uya` | `AsyncWaitFdFuture` | runtime substrate（fd readiness wait） | fd readiness wait substrate；`async_fd_read_deadline_future` / `async_fd_write_deadline_future` 已只在 `@async_fn` 里 `@await` 它 |
| `lib/std/thread.uya` | `AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture` | runtime substrate（线程调度桥接） | ThreadPool shared slot / pending queue / result pipe / cooperative cancel / cleanup 协议仍需手写 `poll()` 直接串接 |

- 代码核对说明（2026-06-21）：
  - 阶段验收基线应使用 `rg -nP "^(export )?struct (?!Future<|Task<).*: Future<" lib/std --glob '*.uya'`；当前只命中 `AsyncWaitFdFuture` 与 `std.thread` worker 调度桥接 5 个类型。`Future<T>` / `Task<T>` 只是基础包装容器，不计入手工 Future 盘点。
  - `WebSocketClientReconnectFuture`、`WebSocketReadMessageFuture`、`WebSocketHeartbeatTimeoutFuture`、`UyaginRecoverFuture`、`UyaginObserveFuture`、`DnsQueryTransportFuture`、`DnsQueryAllAggregateFuture` 已不再以 `struct ... : Future<...>` 形式存在。
  - `async_join2_usize_results`、`async_writev`、`async_sendfile`、`async_connect`、`async_socket_send`、`async_socket_recv`、`async_accept`、`async_read_parse`、`async_read_parse_into` 已不再保留手写 `struct ... : Future<...>`；`std.async` 侧当前只剩 `AsyncWaitFdFuture` 一个 hand-written `poll()` substrate。
  - `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_read_parse` / `async_read_parse_into` 已统一到 `lib/std/async.uya`，`http1_async` / `uyagin` / `dns` 已通过 `@await` 组合；线程桥接 awaitable 已收口到 `lib/std/thread.uya` 专属 helper，协议层待办只剩真实未统一叶子。

### 1.5.2 迁移顺序原则

### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

> 2026-06-21 代码核对：`websocket_client_reconnect_tick`、`websocket_conn_read_message` / `websocket_conn_heartbeat_tick`、`uyagin_run_chain_recover`、`uyagin_observe_request_future`、`dns_query_transport_future_new` 已经是 `@async_fn` / join 组合层；本节剩余 TODO 以“语义回归与防倒退”为准，不再把不存在的手写 `poll()` 重复记成迁移目标。

**验收**：

### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

> **最终 substrate 边界（2026-06-21 代码核对）**
>
> 在 1.5.4 / 1.5.5 收口后，当前真实残留的 hand-written `poll()` 已经收口成两类 runtime substrate 边界叶子：
>
> - fd readiness wait substrate：`lib/std/async.uya` 的 `AsyncWaitFdFuture`
> - `std.thread` worker 调度桥接 substrate：`AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`
>
> 上述两类就是 1.5.6 / 1.5.7 唯一允许保留的 runtime substrate 例外集；“业务层 hand-written future = 0” 的终态不包含其他模糊豁免。
>
> `std.async` syscall / 聚合 / 协议壳 residual（`AsyncJoin2UsizeResultsFuture`、`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`、`AsyncReadParseFuture`、`AsyncReadParseIntoFuture`）已在前序叶子中清零，不再计入“当前真实残留”。
>
> `Http1ConnectFuture`、`DnsUdpFuture`、`DnsTcpFuture`、`UyaginWritevFuture`、`UyaginSendFileBodyFuture`、`UyaginConnReadParseFuture`、`UyaginConnReadParseIntoFuture`、`UyaginAcceptFuture` 都不计入 substrate，必须在前面阶段迁移出业务模块，不能作为“底座例外”无限期保留。

### 1.5.8 建议执行顺序

1. [ ] 先完成 Phase 1 的语法缺口，尤其是 `catch`、`defer/errdefer`、`match`。
2. [ ] 再做 1.5.3，把纯组合层 hand-written future 先全部改掉。
3. [ ] 然后做 1.5.4，提炼统一 syscall/I/O awaitable 原语。
4. [ ] 再做 1.5.5，迁移 DNS / HTTP1 / WebSocket / UyaGin 热路径。
5. [ ] 最后做 1.5.6，把 runtime 叶子手写 future 收缩到最终边界并清零或正式归类。

## Phase 2：编译器 async 资源动态化

- [ ] 把 `src/codegen/c99/internal.uya` 的 `C99_ASYNC_MAX_AWAITS` 固定数组改成 arena/vector 风格的动态结构。
- [ ] 把 `src/checker/async_frame_meta.uya` 的 `MAX_ASYNC_FRAME_METAS` 改成动态元信息表。
- [ ] 把 `src/codegen/c99/main.uya` 的 async frame descriptor emission 改成“按真实数量生成”，不再静默截断到 `512`。
- [ ] 为“超大 async 函数”建立新的错误模型：
  - [ ] 若只是旧的人为上限，不应再报错
  - [ ] 若真因内存耗尽或编译器资源不足失败，要给出明确诊断，而不是静默丢字段/丢状态
- [ ] 替换现有 `tests/error_async_too_many_awaits.uya`：
  - [ ] 不再把 “>256 await 编译失败” 视为正确
  - [ ] 改成“旧上限附近成功编译+运行”的压力测试
- [ ] 补一个“多 frame / 多 mono instance / 多 generic async”压力样本，验证 descriptor 和 meta 表不会截断。

**验收**：

- [ ] `./bin/uya test tests/test_async_await_limits_and_segments.uya`
- [ ] 新增 `tests/verify_async_large_state_machine.sh`
- [ ] 新增 `tests/test_async_descriptor_growth.uya`
- [ ] 在旧 `256 await`、`32 locals`、`512 frame meta` 边界附近的样本全部通过

## Phase 3：运行时 async 资源动态化

### 3.1 EventLoop / epoll

- [ ] 将 `lib/std/async_event.uya` 的固定 `1024` slot / event buffer 改成动态容量。
- [ ] 消灭 `find_slot()` 线性扫固定数组的实现，改成更适合生产的索引结构。
- [ ] 把“容量满直接失败”改成可增长或可配置策略，并补上指标。

### 3.2 Scheduler / TaskQueue

- [ ] 把 scheduler 的 `_frame_stack_buffer[8192]` 改成显式配置或动态后备存储策略。
- [ ] 评估并收口 `SCHEDULER_INLINE_REPOLL_LIMIT=1024` 的策略，让它成为调度策略参数，而不是写死常量。

### 3.3 AsyncFramePool

- [ ] 将 `lib/std/async_frame.uya` 的 bucket / slot / descriptor 上限改成动态结构。
- [ ] 为 pool 建立明确的 ownership 跟踪，修掉 reset/free 语义只能靠注释解释的隐患。
- [ ] 区分：
  - [ ] 真正来自 caller buffer 的 frame
  - [ ] 池内复用 frame
  - [ ] debug heap fallback frame
- [ ] 默认生产路径不应依赖 heap fallback 才能跑通。

### 3.4 ThreadPool / async_compute

- [ ] 将 `lib/std/thread.uya` 的 worker / pending / task slot 数量改成动态或可配置。
- [ ] 明确 `async_compute` 饱和后的生产策略：
  - [ ] 要么动态排队并背压
  - [ ] 要么显式返回容量错误
  - [ ] 不再默默回退到 `sys_fork()` 作为默认生产路径
- [ ] 为 thread pool 增加容量、排队深度、取消、排空时间的指标。

### 3.5 协议层临时 buffer

- [ ] 将 `lib/std/http/http1_async.uya` 的固定 `4096` 请求头 scratch buffer 改成 growable buffer 或调用方可控容量。
- [ ] 审计 `websocket_async`、DNS/TLS 等 async 协议模块中的固定 scratch buffer，把“协议暂存”与“产品上限”拆开。

**验收**：

- [ ] 新增 `tests/test_async_event_dynamic_growth.uya`
- [ ] 新增 `tests/test_async_task_queue_dynamic_growth.uya`
- [ ] 新增 `tests/test_async_frame_pool_dynamic_growth.uya`
- [ ] 新增 `tests/test_async_thread_pool_dynamic_growth.uya`
- [ ] 新增 `tests/stress_async_dynamic_resources.sh`
- [ ] 压测时不再因为 `16/32/64/512/1024` 这类旧常量直接失败

## Phase 4：生产级可靠性与可观测性

- [ ] 为 async runtime 增加统一指标：
  - [ ] frame alloc/free/full/fallback
  - [ ] scheduler queue depth
  - [ ] epoll registered fd / resize count
  - [ ] thread pool queue depth / running workers / saturation count
  - [ ] timeout / cancel / wake 来源统计
- [ ] 建立长压测与泄漏验证：
  - [ ] fd 不泄漏
  - [ ] frame 不泄漏
  - [ ] eventfd 不泄漏
  - [ ] 取消后资源能稳定回收
- [ ] 清理“只在 bench/特定 demo 下成立”的 workaround，把生产路径与测试绕过分开。
- [ ] 对 `http1_async`、DNS、TLS、`async_compute` 做混合压力测试，验证共享 runtime 不互相踩资源上限。

**验收**：

- [ ] `tests/stress_http_async_epoll.sh`
- [ ] `tests/verify_http_bench_async_epoll_runtime.sh`
- [ ] 新增 `tests/verify_async_no_fd_leak.sh`
- [ ] 新增 `tests/verify_async_cancel_cleanup.sh`

## Phase 5：发布闸门与文档同步

- [ ] 新增/更新权威验证脚本：
  - [ ] `tests/verify_async_full_language_matrix.sh`
  - [ ] `tests/verify_async_dynamic_resources.sh`
  - [ ] `tests/verify_async_production_smoke.sh`
- [ ] 收口前至少跑通：
  - [ ] `make uya`
  - [ ] `make tests-uya`
  - [ ] `make check`
  - [ ] `make clean`
  - [ ] `make backup-all`
- [ ] 文档同步：
  - [ ] `docs/async_production_todo.md`
  - [ ] `docs/async_status_matrix.md`
  - [ ] `docs/std_async_design.md`
  - [ ] 如语义/规范改变，再同步 `docs/uya.md`、`docs/grammar_formal.md`、`docs/grammar_quick.md`

## 执行顺序

1. [ ] 先做 Phase 0，把“真实缺口”与“验证入口”钉住。
2. [ ] 再做 Phase 1，先拿下完整语法支持，不继续在 emitter 里堆特判。
3. [ ] 接着做 Phase 2，把编译器内部 async 容量全部动态化。
4. [ ] 然后做 Phase 3，把 runtime 和协议层资源动态化。
5. [ ] 最后做 Phase 4 和 Phase 5，用真实压测和 release 闸门把“生产级”口径关上。

## 未完成前不得宣称完成的条件

- [ ] 仍存在合法 async 语法被“尚未支持”拒绝。
- [ ] 仍存在 `16/32/64/512/1024` 这类固定上限决定正常功能成败。
- [ ] 仍需要 `fork` fallback 才能掩盖线程池饱和。
- [ ] 仍把 `tests/error_async_too_many_awaits.uya` 这类旧人为上限测试当成正确口径。
- [ ] 文档仍声称“量产已完成”，但源码和闸门没有证据支撑。
