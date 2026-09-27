# Uya 顶层函数可达性重构待办

> **归档/核对头（2026-09-27）**：本重构已落地，清单复选框为历史形式。
>
> - 核对证据：checker 侧已建立可达性记录（`src/checker/check_call.uya` 的 `checker_record_reachable_call` / `checker_add_function_root_decl` / `checker_add_function_edge`）；codegen 侧 `should_emit_top_level_function_decl`（`src/codegen/c99/main.uya`）已从"总是发射"改为查询 `is_top_level_function_reachable`，`export fn` 与无函数体的 extern/前向声明按 root 保活。
> - 剩余：无已知剩余项；如后续新增发射判定（例如新的 root 形态）需在同处补 root 建模与回归。

**目标**：把“顶层函数是否发射”收敛为分析阶段的一次性结论，恢复 `checker -> reachability -> codegen` 的单向职责链。

**当前状态**：C99 backend 侧仍保留 reachability owner。当前实现位于 `src/codegen/c99/main.uya`，其中 `prepare_codegen_tests_and_emit_flags()` 会在 codegen 阶段全量标记，`should_emit_top_level_function_decl()` 目前等价于“总是发射”。

**本待办只覆盖最小实现面**：

- 只处理顶层 `AST_FN_DECL` 的发射判定。
- 处理普通函数调用、模块限定函数调用，以及“直接取地址的顶层函数”保活。
- tests 通过显式 root 建模保活；宏展开后的普通调用仍走 call edge。
- `export fn` / `export extern fn` 作为显式 ABI surface，第一刀按 root 保活。
- `codegen` 只消费顶层函数 reachable set；backend 自己生成的 C helper 仍由 backend owner 管理。

**本待办明确不覆盖**：

- 结构体/联合体内部方法裁剪。
- `method block` 裁剪。
- 泛型 mono instance 的精细 reachability。
- 任意间接函数指针/回调数据流闭包；第一刀只保活“源码里直接取地址到顶层函数”的场景。
- release/bootstrap/libc/split C 的顺手重构。
- “为了修回归再加一层全发射”式兜底。

实现时遵循项目的小步验证流程：每完成一个阶段，只验证对应回归面；若开始牵出 bootstrap/release/libc，则先停、先缩回最小实现。

**口径约束（本刀必须明确）**：

- reachable set 的 owner 仍是 checker，但其口径以“宏展开完成后的 checker AST”为准。
- 第一刀只要求这个 reachable set 对后续整个编译流程保持**保守正确**：允许优化后留下少量“已不再需要但仍被保活”的函数，不允许因为 owner 漂移而漏发射仍需函数。
- `optimize_program()` 不参与重算顶层 reachability；若未来某个优化 pass 会新引入跨顶层 call site，再单独开刀处理，不在本待办顺手扩面。

---

## Phase 0：范围与验收口径

### 0.1 最小成功标准

- [ ] 普通 `--c99` 下，dead non-exported / non-address-taken top-level function 不再发射。
- [ ] microapp 模式下，dead non-exported / non-address-taken top-level function 不再发射。
- [ ] `test` 语句仍能运行，`uya_run_tests()` 路径不坏。
- [ ] 直接取地址传给回调/线程/异步入口的顶层函数仍会发射。
- [ ] `export fn` / `export extern fn` 仍按 ABI surface 保留。
- [ ] self-host 编译时间不明显退化。
- [ ] release 行为不受影响。

### 0.2 非目标确认

- [ ] 第一刀不裁剪方法、结构体内部方法、联合体方法。
- [ ] 第一刀不做 mono instance 的精细闭包，只保持现有行为。
- [ ] 第一刀不把 test 收集逻辑整体迁出 codegen；只迁移“发射决策 owner”。
- [ ] 第一刀不把 backend 生成的 `uya_print_i32` / synthetic runner `printf` 这类 C helper 纳入 checker reachability。
- [ ] 第一刀不顺手把 `detect_main_function()` 的入口自动注入 owner 改成 AST 版；`node_has_tests()` / `program_has_tests()` 只服务 reachability root 建模。

---

## Phase 1：在 Checker 中建立 reachability 状态

### 1.1 扩展 `TypeChecker`

- [ ] 在 [src/checker/types.uya](../src/checker/types.uya) 中新增容量常量：
  - [ ] `MAX_FN_CALL_EDGES`
  - [ ] `MAX_FN_ROOTS`
  - [ ] `MAX_REACHABLE_FN_DECLS`
- [ ] 在 `TypeChecker` 中新增字段：
  - [ ] `fn_call_edge_from`
  - [ ] `fn_call_edge_to`
  - [ ] `fn_call_edge_count`
  - [ ] `fn_root_decls`
  - [ ] `fn_root_count`
  - [ ] `reachable_fn_decls`
  - [ ] `reachable_fn_decl_count`
- [ ] 顶层函数可达性状态统一使用 `&ASTNode`，不使用纯字符串作为最终 owner。
- [ ] `fn_root_decls` / `reachable_fn_decls` 只存 `AST_FN_DECL`；`AST_TEST_STMT` 只能作为 root source，不直接塞进函数集合。

### 1.2 初始化与辅助函数

- [ ] 在 [src/checker/symbols.uya](../src/checker/symbols.uya) 的 `checker_init()` 中清零上述数组与计数器。
- [ ] 在 [src/checker/symbols.uya](../src/checker/symbols.uya) 中新增 helper：
  - [ ] `checker_find_reachable_fn_decl_by_name`
  - [ ] `checker_add_function_root_decl`
  - [ ] `checker_add_function_root_by_name`
  - [ ] `checker_add_function_edge`
  - [ ] `checker_is_function_reachable`
  - [ ] `checker_compute_function_reachability`
- [ ] `checker_find_reachable_fn_decl_by_name` 需优先返回 `fn_decl_body != null` 的定义，避免把 root 种到仅声明节点。
- [ ] `checker_add_function_edge` / `checker_add_function_root_decl` 需做简单去重，避免闭包前数组被重复灌满。
- [ ] 任一 reachability 数组容量打满时，必须报错或至少给出显式诊断；不允许静默丢 edge / root / reachable 结果后继续编译。

### 1.3 闭包算法

- [ ] `checker_compute_function_reachability()` 第一版采用朴素 BFS/DFS，避免提前优化。
- [ ] 起点仅来自显式 `roots`。
- [ ] 遍历边时仅沿 `fn_call_edge_from -> fn_call_edge_to` 推进，不混入 codegen 规则。
- [ ] 闭包结果按“checker 结束时的 AST”一次性定稿；`optimize_program()` 不回写也不重算该集合。

---

## Phase 2：在调用与取地址检查阶段收集 edge / roots

### 2.1 普通函数调用解析

- [ ] 在 [src/checker/check_call.uya](../src/checker/check_call.uya) 中新增 `resolve_reachable_callee_fn_decl(checker, callee)`。
- [ ] 第一版只支持：
  - [ ] `identifier(...)`
  - [ ] `module.func(...)`
- [ ] 第一版不支持：
  - [ ] 方法调用
  - [ ] 接口 dispatch
  - [ ] 任意间接函数指针调用
  - [ ] union variant constructor

### 2.2 记录调用边与 test roots

- [ ] 在 `checker_check_call_expr()` 中，当 `reachable_callee != null` 且 `current_function_decl != null` 时：
  - [ ] 若当前 owner 是 `AST_FN_DECL`，记录 `from -> to`。
  - [ ] 若当前 owner 是 `AST_TEST_STMT`，将命中的 `AST_FN_DECL` 记为 root。
- [ ] `std.testing.run_test` 这类宏展开后的 `test_fn()` 继续按普通 call edge 收集，不额外做特殊分支。
- [ ] 不在 codegen 再次推断“tests 需要哪些函数”。
- [ ] 不因单个回归引入“tests 全发射”式兜底。

### 2.3 记录直接取地址 roots

- [ ] 在 [src/checker/check_expr_extra.uya](../src/checker/check_expr_extra.uya) 的 `checker_check_unary_expr()` / `checker_check_cast_expr()` 中补最小保活：
  - [ ] `&identifier`
  - [ ] `&module.func`
  - [ ] 一层 cast 包裹的 `&identifier as &void`
  - [ ] 一层 cast 包裹的 `&module.func as &void`
- [ ] 仅当被取地址目标可解析到顶层 `AST_FN_DECL` 时记为 root。
- [ ] 第一刀只保活“直接取地址命中顶层函数”的场景，不追踪地址写入容器后的后续数据流。

### 2.4 所有权边界

- [ ] `check_call.uya` / `check_expr_extra.uya` 只负责收集边与 root，不决定发射。
- [ ] `checker` 结束时 reachable set 应已可用；backend 不再重建这一信息。

---

## Phase 3：显式定义 roots

### 3.1 普通编译 roots

- [ ] 在 [src/main.uya](../src/main.uya) 中新增 `seed_function_reachability_roots()`。
- [ ] 普通 `--c99` / microapp 模式下，将实际入口层显式加入 roots：
  - [ ] `fn main`
  - [ ] 若自动注入 `std.runtime.entry`，其 `export extern fn main` 也作为 root
- [ ] 只在 checker 通过后、进入 codegen 前计算 reachability。
- [ ] 第一刀保持当前 `detect_main_function()` 的入口自动注入逻辑不变；`seed_function_reachability_roots()` 只消费已经进入 merged AST 的入口函数。

### 3.2 tests roots

- [ ] 在 [src/main.uya](../src/main.uya) 中新增 `node_has_tests()` / `program_has_tests()`，不要依赖 codegen 的 test 收集函数。
- [ ] 若程序中存在 `AST_TEST_STMT`：
  - [ ] `AST_TEST_STMT` 只作为“需要从测试体播种 roots”的来源，不直接进入 `fn_root_decls`。
  - [ ] 测试体里展开后的普通函数调用继续通过 call edge 保活。
  - [ ] synthetic runner 仍可保留在 backend 生成；不要为其 C helper 额外引入 checker root。
- [ ] `node_has_tests()` / `program_has_tests()` 在本刀只负责 reachability 判定与验收辅助，不替换 CLI 侧的 entry 自动注入策略。

### 3.3 ABI / callback roots

- [ ] 在 `seed_function_reachability_roots()` 中显式保活 ABI surface：
  - [ ] `export fn`
  - [ ] `export extern fn`
- [ ] 将“源码里直接取地址命中的顶层函数”视为 callback roots，而不是要求 backend 再次扫描表达式补洞。

### 3.4 roots 策略约束

- [ ] root 只来自入口、tests、ABI surface、direct address-taken callback sites 等显式来源。
- [ ] 不允许引入“某类函数默认保活”的宽泛策略。

---

## Phase 4：让 C99 Backend 只消费 reachable set

### 4.1 传递 checker 结果

- [ ] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 中新增 `c99_codegen_set_reachable_functions(codegen, checker)`。
- [ ] 该函数只复制 `checker.reachable_fn_decls` 到 `codegen.reachable_function_decls`。
- [ ] 在 [src/main.uya](../src/main.uya) 中，`c99_codegen_set_mono_instances()` 后调用 `c99_codegen_set_reachable_functions()`。
- [ ] `c99_codegen_set_reachable_functions()` 调用后，backend 只读消费该结果；不得再把它重置为空或回填为“全体可达”。

### 4.2 收缩 backend owner

- [ ] 在 [src/codegen/c99/main.uya](../src/codegen/c99/main.uya) 中保留 `collect_tests_from_node()` 作为 test 收集逻辑。
- [ ] 收缩 `prepare_codegen_tests_and_emit_flags()`：
  - [ ] 保留 test 收集。
  - [ ] 保留 decl cache 初始化等非 reachability 准备逻辑。
  - [ ] 删除“标记所有顶层函数 reachable”。
  - [ ] 不再清空或覆盖 `reachable_function_decl_count` / `reachable_function_decls`。
- [ ] 第一刀保留当前 `reachable_mono_instances` 初始化语义，不在这一步一起迁移 mono owner。
- [ ] 将 `should_emit_top_level_function_decl()` 改为真正查询 `reachable_function_decls`。

### 4.3 backend 约束

- [ ] codegen 不再重建顶层 `AST_FN_DECL` reachability。
- [ ] backend 生成的 C helper（如 `uya_print_i32`）继续由 backend owner，不混入 checker reachable set。
- [ ] tests/microapp/release 不再通过 backend 全发射分支耦合进来。
- [ ] 若有回归，优先检查 root 或 edge，不新增 backend 兜底。
- [ ] 若 `reachable_function_decls` 为空，优先回查 root/edge/传递链路；不要在 backend 内偷偷恢复“全发射”。

---

## Phase 5：测试与验证

### 5.1 回归测试

- [ ] 调整 [tests/verify_function_reachability_codegen.sh](../tests/verify_function_reachability_codegen.sh) 的预期：
  - [ ] `dead_internal` 不再出现在生成的 C 中。
  - [ ] `dead_exported` 仍保留（`export fn` 作为显式 ABI root）。
  - [ ] `export extern` 的 `kept_c_api` 仍保留。
- [ ] 新增最小 microapp reachability 用例：
  - [ ] dead non-exported / non-address-taken top-level 不发射。
  - [ ] live top-level 仍正常生成。
- [ ] 新增或复用一个最小 callback / address-taken 用例：
  - [ ] `&top_level_fn as &void` 命中的函数仍发射。
- [ ] 运行至少一个带 `test` 语句的现有测试，确认 runner 路径正常。
- [ ] 运行至少一个现有 callback 用例（如 `std.thread` / `pthread_create`），确认 direct address-taken root 正常。

### 5.2 性能与自举

- [ ] 跑一次 self-host 编译时间，对比改动前后的总耗时。
- [ ] 若编译时间明显向错误方向退化，先检查 reachable set 是否膨胀，再决定是否继续。
- [ ] 至少跑一次现有 `split_c` 冒烟，确认“虽然第一刀不扩面，但不引入 split C 回归”。

### 5.3 调试辅助

- [ ] 可选添加临时诊断开关（如 `UYA_DEBUG_REACHABILITY`），输出：
  - [ ] root 数量
  - [ ] reachable 函数数量
  - [ ] 关键入口函数是否在 reachable 集合中
- [ ] 合并前移除或最小化临时调试输出。

---

## Phase 6：后续扩展（第二刀以后再做）

### 6.1 方法与内部定义

- [ ] 结构体/联合体内部方法 reachability。
- [ ] `method block` reachability。
- [ ] 相关 vtable / method prototype 的按需发射。

### 6.2 泛型实例

- [ ] 将 `reachable_mono_instances` 从“默认放开”收紧为“按实际 reachable 函数/方法驱动”。
- [ ] 区分函数 mono 与类型 mono 的保活来源。

### 6.3 解释性与可观测性

- [ ] 增加“为什么 reachable”的 provenance 调试能力。
- [ ] 支持打印某个符号的 root/edge 路径，便于回归定位。

---

## 止损规则

- [ ] 任何回归优先归类为“缺 root”或“缺 edge”。
- [ ] 如果问题开始牵出 release/bootstrap/libc/split C，先停、先缩回，不扩面。
- [ ] 不把“修当前回归”和“顺手修其他问题”混在同一刀。
- [ ] 一旦出现明显编译时间退化，优先回到最小实现面。

---

## 验收清单

- [ ] 顶层函数发射 owner 已从 codegen 收回到 checker。
- [ ] `should_emit_top_level_function_decl()` 不再恒为真。
- [ ] 普通 `--c99` 下 dead non-exported / non-address-taken top-level 不发射。
- [ ] microapp 下 dead non-exported / non-address-taken top-level 不发射。
- [ ] tests 仍能正常运行。
- [ ] direct address-taken callback 函数仍能正常发射。
- [ ] `export fn` / `export extern fn` 仍按 ABI surface 保留。
- [ ] self-host 时间无明显退化。
- [ ] 第一刀未扩散到方法裁剪、mono 精细裁剪、release/bootstrap/libc 重构。
