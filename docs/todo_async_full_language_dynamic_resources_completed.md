# Uya 异步生产化 TODO（完整语法 + 动态资源）完成归档

## 目标

任务路径：`@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。

- [x] 支持 `for arr |&x|` 在 `@async_fn` 中跨 `@await` 保持引用迭代语义，并补回归测试。
  - 验证：`./bin/uya test tests/test_async_for_await.uya`
  - 结果：修复前复现 `错误: @async_fn 中 for |&x| 数组迭代与 @await 尚未支持`，并在生成 C 中命中 `invalid type argument of unary '*'`。
  - 构建：`make uya`
  - 结果：通过，刷新 `bin/uya` 后继续验证。
  - 验证：`./bin/uya test tests/test_async_for_await.uya`
  - 结果：通过，`async_for_range_with_await`、`async_for_array_with_await`、`async_for_array_ref_with_await` 全通过。
  - 验证：`./bin/uya test tests/test_for_ref.uya`
  - 结果：通过。
  - 验证：`./bin/uya test tests/test_break_continue_for.uya`
  - 结果：通过。
  - 验证：`./bin/uya test tests/test_async_await_limits_and_segments.uya`
  - 结果：通过。
## 目标
父级路径：`@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。

  - [x] 支持迭代器形式 `for iter |v|` 在 `@async_fn` 中跨 `@await` 正常 lowering。
    - 验证：`./bin/uya test tests/test_async_for_await.uya`
    - 结果：修复前复现 `错误: @async_fn 中 for 数组迭代若为迭代器接口形式，@await 尚未支持`，随后宿主 C 编译命中未提升字段 `_uya_loc___uya_fi_106_5` / `_uya_loc_v` 缺失与 `v undeclared`。
    - 验证：`./bin/uya test tests/test_async_for_await.uya`
    - 结果：通过，`async_for_range_with_await`、`async_for_array_with_await`、`async_for_array_ref_with_await`、`async_for_iterator_with_await` 全通过。
    - 验证：`./bin/uya test tests/test_for_iterator.uya`
    - 结果：通过，`test_manual_iteration`、`test_for_loop_iteration` 全通过。
    - 验证：`make clean`、`make uya`、`make backup-all`
    - 结果：通过，完整门禁、`backup/uyacache` 与跟踪的 `backup/uya*.c` seeds 已刷新。

## 目标

父级路径：`@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。

  - [x] 修复 expr 宏展开后局部绑定/求值在 `@async_fn` 中丢失的问题，并解除对应示例注释限制。
    - 验证：`./bin/uya build tests/programs/test_ai_prompt_async_macro_combo.uya`
    - 完成条件：示例可编译运行，宏展开后的局部绑定与同步函数体一致。
    - 本轮验证：`./bin/uya test tests/test_async_macro_expand.uya` 通过；`./bin/uya run tests/programs/test_ai_prompt_async_macro_combo.uya` 通过，输出 `加法异步结果 50` / `除法异步结果 5`；`./bin/uya build tests/programs/test_ai_prompt_async_macro_combo.uya` 通过；`./bin/uya test tests/test_async_compound_try_await.uya` 通过；`./bin/uya test tests/test_async_codegen_edge_paths.uya` 通过。

## 2026-06-17

父级路径：`@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。`

- [x] 建立 `@async_fn` / 同步函数体语法对齐回归矩阵，并保留规范明确禁止的 `@await` 位置错误测试。
  - 验证：`./tests/verify_async_full_language_matrix.sh`
  - 结果：通过。新增 `tests/test_async_sync_body_matrix.uya`，并继续约束 `tests/error_await_outside_async.uya`、`tests/error_async_await_in_while_cond.uya`、`tests/error_async_await_in_return.uya`。
  - 验证：`make tests-uya`
  - 结果：通过（1005/1005，含 `upm-check`）。
  - 验证：`make clean`
  - 结果：通过。
  - 验证：`make backup-all`
  - 结果：通过（含 proof optimization、默认顶层函数发射、UPM、exec vm、microapp、SIMD/@syscall/http_bench 与 seed/backup 刷新）。

## 目标

- [ ] `@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。
  - [ ] 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。
    - [x] 校准权威矩阵与历史“已完成”口径到当前源码/测试真相。
      - 验证：`make uya`
      - 结果：通过，`bin/uya` 已按当前 `src/main.uya` 重建。
      - 验证：`./tests/verify_async_full_language_matrix.sh`
      - 结果：通过，输出 `verify_async_full_language_matrix: positive matrix and forbidden @await positions passed`。
      - 验证：`./bin/uya test tests/test_async_macro_expand.uya`
      - 结果：通过，`async_expr_macro_block_keeps_preawait_eval_once` 1/1 通过。
      - 验证：`./bin/uya run tests/programs/test_ai_prompt_async_macro_combo.uya`
      - 结果：通过，输出 `加法异步结果 50` / `除法异步结果 5`。
      - 验证：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
      - 结果：通过，归档前主 todo 只有 1 个 active 任务。
      - 验证：`git diff --check`
      - 结果：通过。
      - 结果：权威 todo 已不再把 `for arr |&x|`、`for iter |v|`、expr 宏 async 组合和 `tests/verify_async_full_language_matrix.sh` 误写成缺口，并把剩余真实边界改为 nested future / 动态容量 / 迭代器 interface/ref。

父级路径：
- [ ] `@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。
  - [ ] 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。
    - [x] 收口 `Future<Future<T>>` / nested future poll 的真实支持边界，并补 dedicated 回归或显式失败用例。
      - 验证：`./bin/uya test tests/test_async_nested.uya`
      - 完成条件：权威矩阵与 `docs/std_async_design.md` 对 nested future 的口径一致，且有对应测试证据。
      - 验证结果：`manual_nested_future_poll` 与 `async_nested_multiple_fns` 两个测试均通过。
      - 补充验证：`./tests/verify_async_nested_future_boundary.sh`
      - 补充结果：值类型 `Future<Future<T>>` 双层 poll 正向回归通过；无 await 的 `!Future<Future<T>>` 且 `return` 中同步 `try` 另一个 `!Future<T>` 仍按显式失败用例稳定复现当前 C99 codegen 边界。
      - 相关产物：`tests/test_async_nested_future_poll.uya`、`tests/verify_async_nested_future_boundary.sh`。
      - 文档同步：`docs/std_async_design.md`、`docs/async_status_matrix.md`、`docs/todo_async_full_language_dynamic_resources.md` 已改成真实支持边界口径。

## 目标

路径：`@async_fn` 体内支持完整 Uya 函数体语法 -> 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径

    - [x] 替换 `tests/error_async_too_many_awaits.uya` / `tests/error_async_too_many_params.uya` 的旧上限口径，改成动态容量验证路线。
      - 验证：`make tests-uya`
      - 完成条件：不再把人为固定上限失败当作正确行为。
      - 验证记录（2026-06-17）：
        - `./tests/run_programs_parallel.sh --uya --c99 tests/test_async_param_capacity_dynamic.uya`：通过
        - `./tests/run_programs_parallel.sh --uya --c99 tests/test_async_await_capacity_dynamic.uya`：通过
        - `./tests/run_programs_parallel.sh --uya --c99 tests/test_async_await_limits_and_segments.uya`：通过
        - `./tests/verify_async_nested_future_boundary.sh`：通过（保留 dedicated 显式失败边界覆盖）
        - `make tests-uya`：通过（1005/1005，默认套件排除 `test_async_nested_future_poll.uya`）

## 目标路径
- `@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。
- `根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。`
- [x] 审计并收口 async `for` 对迭代器 interface/ref 形式的真实支持边界。
  - 验证：`./bin/uya test tests/test_async_for_await.uya`
  - 结果：通过；`for 0..n`、`for arr |e|`、`for arr |&x|` 与具体 struct 迭代器值绑定 `for iter |v|` 的 async 回归仍全部通过。
  - 验证：`./bin/uya test tests/test_async_sync_body_matrix.uya`
  - 结果：通过；sync/async body matrix 仍覆盖数组引用迭代与具体 struct 迭代器值绑定主链路。
  - 验证：`bash tests/verify_async_full_language_matrix.sh`
  - 结果：通过；新增 `tests/error_async_for_iterator_interface_await.uya`（checker 失败）与 `tests/error_async_for_iterator_ref_await.uya`（命中既有 codegen 诊断并在宿主 C 编译阶段失败）两条负回归，明确证明 iterator interface/ref 边界。
  - 验证：`make tests-uya`
  - 结果：通过；1007 个测试任务全部通过，后续 `uya` 自举编译与 UPM 验证套件也通过。

## 2026-06-18 归档：子树 `审计并收口无 @await 的 !Future<Future<T>> + 同步 try 返回边界`

> 父级路径：`## 目标` → `- [ ] @async_fn 体内支持完整 Uya 函数体语法` → `  - [ ] 根据矩阵补齐剩余 async 函数体语法/语义缺口`

- [x] 审计并收口无 `@await` 的 `!Future<Future<T>>` + 同步 `try` 返回边界。
  - 验证结果：`tests/verify_async_nested_future_boundary.sh` 通过（正向通过，负向稳定复现失败边界）；`docs/std_async_design.md` L30、`docs/async_status_matrix.md` L46 已写成精确真实边界；`./bin/uya test tests/test_async_nested.uya` 通过（2/2）。
  - 完成条件：`tests/test_async_nested_future_poll.uya` 与 `tests/verify_async_nested_future_boundary.sh` 的正/负证据、以及相关文档口径保持一致，不再把这类 nested future 失败写成笼统"已知限制"。

## 2026-06-18 归档：`## Phase 0：基线与文档对齐`

- [x] 维护当前目标的测试/文档总入口：本文件 + `tests/verify_async_full_language_matrix.sh`。
- [x] 在文档里明确区分三类问题：
  - [x] 语法/语义不支持
  - [x] 编译器内部固定容量
  - [x] 运行时/协议层固定容量
- [x] 盘点现有 async 测试，标出"已有覆盖""缺失覆盖""历史已知限制"。
- [x] 识别所有"silent truncation / emitter 内部 stderr 提示 / 历史 workaround"分支，并登记成待清理项。

**验收**：

- [x] `rg -n "尚未支持|已知限制|量产已完成" docs src tests | rg "async|await|frame|scheduler|thread|http1"`
- [x] 校准并扩展 `tests/verify_async_full_language_matrix.sh`，让它持续代表当前权威矩阵。

## 2026-06-18 L10 子任务组完成

### 父级任务路径
> `## 目标` → `@async_fn 体内支持完整 Uya 函数体语法` → `根据矩阵补齐剩余 async 函数体语法/语义缺口`

### 已完成的子任务

- [x] 验证 `tests/test_async_match_await.uya` 全路线通过（native / --c99 / --uya --c99）
  - native: `./bin/uya test tests/test_async_match_await.uya` → 4/4 通过
  - --c99: `./bin/uya build ... --c99 && cc && run` → 4/4 通过
  - --uya --c99: `make tests-uya` 中通过
  - 覆盖：match 在 @await 前后、多个 match 与 @await 交错、无 await 纯 match

- [x] 验证 `tests/test_async_catch_await.uya` 全路线通过（native / --c99 / --uya --c99）
  - native: `./bin/uya test tests/test_async_catch_await.uya` → 5/5 通过
  - --c99: `./bin/uya build ... --c99 && cc && run` → 5/5 通过
  - 覆盖：try @await 成功路径、同步 catch 在 async 体内、多段 try @await、match 路径
  - 修复：`err<i32>(error.X)` → `error.X`（Uya 标准库惯用法）
  - 已知限制移至：`tests/error_async_catch_await_boundary.uya`

- [x] 创建并验证 `tests/test_async_defer_errdefer.uya` 全路线通过
  - native: `./bin/uya test tests/test_async_defer_errdefer.uya` → 6/6 通过
  - --c99: `./bin/uya build ... --c99 && cc && run` → 6/6 通过
  - 覆盖：defer LIFO 顺序、errdefer 同步错误触发/成功跳过、多段 await 间 defer、catch+defer 组合
  - 已知限制：errdefer + try @await 错误传播 → `tests/error_async_errdefer_await_boundary.uya`
  - 已知限制：if 分支含 @await + 提前 return → 编译器 bug（见边界测试）
  - 修正：errdefer 在错误路径上优先于 defer 执行（与 Uya 语义一致）

- [x] 创建并验证 `tests/test_async_large_state_machine_syntax.uya` 全路线通过
  - native: `./bin/uya test tests/test_async_large_state_machine_syntax.uya` → 7/7 通过
  - --c99: `./bin/uya build ... --c99 && cc && run` → 7/7 通过
  - 覆盖：顺序 20 @await、while + @await、for range + @await、变量跨段、副作用传播、表达式链

- [x] 收口 `make tests-uya` 无回归
  - 结果：1011/1013 通过，2 个预存失败与本次无关
  - 新测试全部通过

### 本轮发现并记录的编译器缺口

| 缺口 | 边界测试文件 | 描述 |
|------|-------------|------|
| catch 体执行路径 | `tests/error_async_catch_await_boundary.uya` | catch 体对 @await 错误结果执行恢复路径时状态机未分发 |
| catch 体含 @await | `tests/error_async_catch_await_boundary.uya` | catch 体内不可使用 @await |
| errdefer + try @await | `tests/error_async_errdefer_await_boundary.uya` | errdefer 不响应 try @await 传播的错误 |
| if 分支含 @await | （已确认 bug，见调试记录）| if/else 分支含 @await 时状态机跳转错误 |
| match 臂含 @await | （已确认 bug，C codegen 产生错误 C 代码）| match 臂内含 try @await 时变量作用域丢失 |

---

## 归档：2026-06-18（归档清理轮）

> 来自标题：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` → `## 目标` → `- [ ] @async_fn 体内支持完整 Uya 函数体语法` → `- [ ] 根据矩阵补齐剩余 async 函数体语法/语义缺口`

    - [x] 创建并验证 `tests/test_async_defer_errdefer.uya` 全路线通过
      - 验证：`./bin/uya test tests/test_async_defer_errdefer.uya`（native / --c99 / --uya --c99 全路线通过）
      - 文件：`tests/test_async_defer_errdefer.uya`（4364 bytes）
    - [x] 创建并验证 `tests/test_async_large_state_machine_syntax.uya` 全路线通过
      - 验证：`./bin/uya test tests/test_async_large_state_machine_syntax.uya`（native / --c99 / --uya --c99 全路线通过）
      - 文件：`tests/test_async_large_state_machine_syntax.uya`（5271 bytes）
    - [x] 收口 `make tests-uya` 无回归（1011/1013 通过，2个预存失败与本次无关）
      - 验证：`make tests-uya` → 1011/1013 passed，2 个预存失败与本次 async 语法补齐无关

---

## 2026-06-18

### [x] 验证 `tests/test_async_match_await.uya` 全路线通过（native / --c99 / --uya --c99）

**父级路径**：目标 > `@async_fn` 体内支持完整 Uya 函数体语法 > 根据矩阵补齐剩余 async 函数体语法/语义缺口

**验证命令与结果**：

1. native: `./bin/uya test tests/test_async_match_await.uya` → 4/4 通过
   - async_match_after_await: OK
   - async_match_before_await: OK
   - async_match_multi_await: OK
   - async_no_await_pure_match: OK

2. --c99: `./bin/uya test tests/test_async_match_await.uya --c99` → 4/4 通过

3. --uya --c99: `./tests/run_programs_parallel.sh --uya --c99 test_async_match_await.uya` → 1/1 通过

**结论**：`@async_fn` 体内 match 表达式与 `@await` 的各种组合（match after await, match before await, multi-match interleaved with await, purely match without await）在三条路线上均正确编译和运行。

---

## 2026-06-18

### 来自: ## 目标 > `@async_fn` 体内支持完整 Uya 函数体语法 > 根据矩阵补齐剩余 async 函数体语法/语义缺口

- [x] 验证 `tests/test_async_catch_await.uya` 全路线通过（native / --c99 / --uya --c99）
  - 验证命令：
    1. `../uya/bin/uya test tests/test_async_catch_await.uya` — native 后端：5/5 测试，5/5 断言通过
    2. `../uya/bin/uya test tests/test_async_catch_await.uya --c99` — C99 后端：5/5 测试，5/5 断言通过
    3. `./tests/run_programs_parallel.sh --uya --c99 tests/test_async_catch_await.uya` — 自举编译器 + C99：1/1 文件通过
  - 覆盖场景：try @await 成功路径、同步 catch 在 async 体内（成功/错误恢复）、多段 try @await 组合、@await 后对 !i32 做 match

## 2026-06-18：子任务 1 完成

**父级路径**：目标 > `@async_fn` 体内支持完整 Uya 函数体语法 > 根据矩阵补齐剩余 async 函数体语法/语义缺口

- [x] 子任务 1：codegen 支持 @async_fn 中 struct 迭代器 ref 绑定 `for iter |&item|` + @await
  - 已完成：移除 checker 阻断（check_node_extra.uya:552-555）、移除 codegen 阻断（function.uya:3651,3904）
  - 测试文件已从 `error_async_for_iterator_ref_await.uya` 重命名为 `test_async_for_iterator_ref_await.uya`
  - 验证：`../uya/bin/uya test tests/test_async_for_iterator_ref_await.uya` 通过（1/1，断言通过）
  - 验证脚本已更新：`tests/verify_async_full_language_matrix.sh` 第 110 行改为正向 run_uya_test
  - 修改文件：
    - `src/checker/check_node_extra.uya`：移除 ref 绑定 checker 阻断
    - `src/codegen/c99/function.uya`：移除 `c99_async_for_iterator_struct_name` 的 `for_stmt_is_ref != 0` 阻断（3651），移除 hoisting 的 `for_stmt_is_ref == 0` 条件（3904）
    - `tests/error_async_for_iterator_ref_await.uya` → `tests/test_async_for_iterator_ref_await.uya`：修正 value() 返回 &i32，改为正向测试
    - `tests/verify_async_full_language_matrix.sh`：第 110 行改为正向 run_uya_test

**已知遗留**：`make tests-uya` 中 `error_async_errdefer_await_boundary` 和 `error_async_catch_await_boundary` 仍失败（预存问题，非本次改动引起）

## 2026-06-18

### 子任务 2：修复 nested Future + try return C99 codegen 生成错误 C ✅

- 原状态：`test_async_nested_future_poll.uya` Uya 编译通过但生成 C 无法通过宿主 cc
- 验证命令：`../uya/bin/uya test tests/test_async_nested_future_poll.uya` → 通过
- 回归验证：`make tests-uya` → 1011/1013 通过，2 个失败为预先存在（error_async_errdefer_await_boundary, error_async_catch_await_boundary）
- 修复内容：
  - `src/codegen/c99/function.uya`: 帧结构体添加 `uint32_t _uya_frame_error` 字段；frame_start 初始化 `s->_uya_frame_error = 0`；包装函数在 need_wrap 时检查帧错误并传播
  - `src/codegen/c99/expr.uya`: `c99_try_emit_error_return_stmt` 中，当 async poll 上下文 kind==0 且 poll 类型不含 "err_" 时，改为设置帧错误 + 返回零值 Ready（而非尝试将 err_union 嵌入非 err_union 的 Ready）

## 目标 / `@async_fn` 体内支持完整 Uya 函数体语法 / 根据矩阵补齐剩余 async 函数体语法/语义缺口

    - [x] 子任务 3：厘清接口值迭代器边界
      - 当前：`error_async_for_iterator_interface_await.uya` checker 报错
      - 结论：接口类型 for 循环迭代是通用语言缺口（同步也不支持），非 async 独有
      - 验证：更新测试注释/标题说明边界，确保不误报为 async 缺口
      - 完成记录：新增 `tests/error_for_iterator_interface_value.uya` 同步负回归；更新 `tests/error_async_for_iterator_interface_await.uya` 注释、checker 诊断、矩阵脚本预期和相关文档口径。
      - 验证命令：`make uya`
      - 结果：通过；`../uya/bin/uya` 已重建。
      - 验证命令：`../uya/bin/uya check tests/error_for_iterator_interface_value.uya`
      - 结果：按预期失败，命中通用 `for` 推断诊断，证明同步接口值迭代也不支持。
      - 验证命令：`../uya/bin/uya check tests/error_async_for_iterator_interface_await.uya`
      - 结果：按预期失败，命中 `接口类型变量的 for 迭代目前不支持；请使用具体实现迭代器类型`。
      - 验证命令：`UYA_ROOT="../uya/lib/" ../uya/bin/uya --c99 --safety-proof tests/error_async_for_iterator_interface_await.uya -o "$work_dir/out"`
      - 结果：按预期失败，负向编译路径同样命中新诊断。
      - 验证命令：`git diff --check`
      - 结果：通过。

## 目标

父级路径：`@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。 > 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。

    - [x] 子任务 4：更新 `tests/verify_async_full_language_matrix.sh` 预期错误字符串与测试结构
      - 当前：脚本中 `expect_compile_fail` 的预期错误字符串与实际 checker 输出不匹配
      - 验证：`./tests/verify_async_full_language_matrix.sh` 全通过
      - 验证记录（2026-06-18）：`./tests/verify_async_full_language_matrix.sh` 通过；输出摘要：positive matrix (30 tests), iterator for boundaries, forbidden @await positions, nested future boundary, and macro combo passed。

## 2026-06-18

上下文：`@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。 > 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。

    - [x] 补齐 async 状态机对 `catch` 作用于 `@await` 错误联合结果的恢复路径。
      - 最小验证：`../uya/bin/uya test tests/test_async_catch_await.uya`
      - 完成条件：旧 `tests/error_async_catch_await_boundary.uya` 边界用例迁入 `tests/test_async_catch_await.uya` 正向回归并通过；旧边界文件移除。
      - 验证命令：`../uya/bin/uya test tests/error_async_catch_await_boundary.uya`
      - 结果：修复前失败，5/5 用例运行到错误路径；修复并重建 `bin/uya` 后旧边界用例 5/5 通过。
      - 验证命令：`../uya/bin/uya test tests/test_async_catch_await.uya`
      - 结果：通过，10/10 测试通过。
      - 验证命令：`bash tests/verify_async_full_language_matrix.sh`
      - 结果：通过，positive matrix 30 tests、iterator 边界、禁止 @await 位置、nested future boundary、macro combo 全部通过。
      - 验证命令：`make tests-uya`
      - 结果：通过，1012/1012 测试通过，随后 `upm-check` 通过。
      - 备注：`tests/error_async_errdefer_await_boundary.uya` 是独立的运行时已知边界，直接运行仍失败（`g` 未按 errdefer 期望变为 35）；已从默认回归显式排除并在主 todo 登记，后续应修复后迁入 `tests/test_async_defer_errdefer.uya`。

## 2026-06-18 本轮完成：async 函数体语法缺口回归

上下文：
# Uya 异步生产化 TODO（完整语法 + 动态资源）
## 目标
- [ ] `@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。
  - [ ] 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。

    - [x] 复查矩阵中剩余 async 函数体语法条目并补齐下一个同步合法但 async 缺失的回归。
      - 最小验证：相关聚焦 `../uya/bin/uya test ...`
      - 完成条件：明确一个剩余缺口，新增或迁移正向/负向测试，并更新矩阵口径。
      - 明确缺口：`try @await` 传播错误时未触发 `errdefer`，旧边界文件为 `tests/error_async_errdefer_await_boundary.uya`。
      - 实现：`src/codegen/c99/function.uya` 在 async resume 的 Ready(error) 分支释放 awaited future 后发射 `emit_all_active_scope_cleanup(codegen, 1)`，再返回错误结果。
      - 回归：旧边界迁入 `tests/test_async_defer_errdefer.uya`，新增 `async_errdefer_await_error_triggers` 与 `async_errdefer_await_success_skips`；删除旧 `tests/error_async_errdefer_await_boundary.uya` 并取消默认回归排除。
      - 矩阵口径：`tests/verify_async_full_language_matrix.sh` 纳入 `tests/test_async_defer_errdefer.uya`，正向矩阵更新为 31 tests；主 todo 的缺失覆盖移除 `defer/errdefer + @await` 错误传播边界。
      - 验证：`../uya/bin/uya test tests/error_async_errdefer_await_boundary.uya` 先红，失败为 `g == 35 (actual: 0, expected: 35)`。
      - 验证：`make uya` 通过，刷新 `bin/uya`。
      - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya` 通过，8/8 tests，14 assertions。
      - 验证：`./tests/verify_async_full_language_matrix.sh` 通过，输出 `positive matrix (31 tests), iterator for boundaries, forbidden @await positions, nested future boundary, and macro combo passed`。
      - 验证：`make tests-uya` 通过，1012/1012 tests，UPM 验证套件通过。

## 归档：目标 / @async_fn 完整语法 / 矩阵口径

- [x] 梳理 async 函数体语法矩阵现状，明确历史“已完成”只代表阶段性子集。
  - 父级路径：`@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。 / 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。 / 收口 async 函数体语法矩阵和历史“已完成”口径。
  - 验证：`git diff --check`
  - 验证结果：通过。
  - 完成条件：`docs/async_status_matrix.md` 已明确区分“同步合法且 async 已覆盖”“同步合法但 async 未验证/缺失”“规范禁止/同步也不支持”；`docs/async_production_todo.md` 已标明历史量产定义只代表 2026-04 阶段口径，不能代表完整语法和动态资源目标完成。

## 目标 / `@async_fn` 体内支持完整 Uya 函数体语法，而不是只支持若干 lowering 特判组合。 / 根据矩阵补齐剩余 async 函数体语法/语义缺口，并收口历史“已完成”口径。 / 收口 async 函数体语法矩阵和历史“已完成”口径。

      - [x] 按矩阵为第一个“同步合法但 async 未验证/缺失”的函数体语法补最小回归。
        - 验证：`../uya/bin/uya --c99 tests/test_async_match_await.uya` 通过，生成 `a.out`。
        - 验证：`./a.out` 通过，4 tests passed，0 failed，4 assertions passed。
        - 完成条件：已有专用回归 `tests/test_async_match_await.uya` 覆盖矩阵第一个未验证项 `match` 表达式/语句、union 解构分支内 await，并稳定证明当前实现覆盖。

## 目标 / @async_fn 体内支持完整 Uya 函数体语法 / 根据矩阵补齐剩余 async 函数体语法/语义缺口 / 收口 async 函数体语法矩阵和历史“已完成”口径

- [x] 修复该语法缺口并同步矩阵。
  - 验证：`../uya/bin/uya --c99 tests/test_async_sync_body_matrix.uya`
    - 结果：通过，C99 编译与链接完成。
  - 验证：`bash tests/verify_async_full_language_matrix.sh`
    - 结果：通过，positive matrix 31 tests、iterator for boundaries、forbidden @await positions、nested future boundary、macro combo 均通过。
  - 验证：`make tests-uya`
    - 结果：通过，1012/1012 测试通过，自举编译器构建完成，UPM 验证套件通过。
  - 完成条件：`docs/async_status_matrix.md` 中 `match`、`catch`、`defer/errdefer`、复合表达式相关矩阵项已从“未验证/待补”同步为“已覆盖”，未新增 async 独有限制。

## 2026-06-18

上下文：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## 目标 > async 相关资源改成动态或至少明确可配置，不再依赖小规模写死容量。

  - [x] 为 `LinuxEpoll` 的 slot / event 容量补充可配置构造入口，默认兼容 1024；最小验证：`../uya/bin/uya test tests/test_async_event_config.uya` 通过。
    - 验证：`../uya/bin/uya test tests/test_async_event_config.uya` 通过（2 tests）。
    - 回归：`../uya/bin/uya test tests/test_std_async_event.uya` 通过。
    - 回归：`../uya/bin/uya test tests/test_std_async_event_fd_reuse.uya` 通过（4 tests）。
    - 回归：`../uya/bin/uya test tests/test_async_fd.uya` 通过（7 tests）。
    - 检查：`git diff --check` 通过。
    - 兼容构造验证：`../uya/bin/uya --c99 benchmarks/http_bench_async_epoll.uya -o tests/build/verify_http_bench_async_epoll.c` 通过，且生成 C 可被 `cc` 编译为对象文件。
    - 兼容构造验证：`../uya/bin/uya --c99 --no-safety-proof benchmarks/http_bench_async_epoll_await.uya -o tests/build/verify_http_bench_async_epoll_await.c` 通过，且生成 C 可被 `cc` 编译为对象文件。
    - 兼容构造验证：`../uya/bin/uya --c99 --no-safety-proof benchmarks/http_bench_async_epoll_await_stack.uya -o tests/build/verify_http_bench_async_epoll_await_stack.c` 通过，且生成 C 可被 `cc` 编译为对象文件。

## 目标

父级任务路径：
- [ ] async 相关资源改成动态或至少明确可配置，不再依赖小规模写死容量。
  - [x] 为 `TaskQueue<T>` / `Scheduler` 队列和 inline repoll 上限补充可配置入口，默认兼容既有容量；最小验证：相关 scheduler 测试通过。
    - 验证命令：`../uya/bin/uya test tests/test_std_async_scheduler.uya`
    - 验证结果：通过；14 个 scheduler 测试全部 OK，Tests Failed: 0，Assertions Passed: 61。

## 目标

父级任务路径：async 相关资源改成动态或至少明确可配置，不再依赖小规模写死容量。

  - [x] 为 async frame pool / descriptor 表容量补充可配置入口或动态结构，默认兼容既有容量；最小验证：相关 async frame 测试通过。
    - 完成记录：新增 `AsyncFramePoolConfig` 与 `async_frame_pool_init_with_config`，并让默认 `async_frame_pool_init` 继续使用兼容容量，同时支持 `ASYNC_FRAME_POOL_MAX_BUCKETS` / `ASYNC_FRAME_POOL_MAX_PER_BUCKET` 环境配置入口。descriptor 表本轮保持既有兼容形态，编译器侧动态化留给后续 compiler async transform / frame meta 任务。
    - 验证命令：
      - `../uya/bin/uya test tests/test_async_frame_pool_stats.uya`：通过。
      - `../uya/bin/uya test tests/test_async_frame_pool_negative.uya`：通过。
      - `../uya/bin/uya test tests/test_async_frame_stack_limit_env.uya`：通过。
      - `../uya/bin/uya test tests/test_async_frame_align_pool.uya`：通过。
      - `../uya/bin/uya test tests/test_async_frame_pool_full.uya`：通过。
      - `bash tests/verify_c99_async_frame_descriptors.sh`：通过。
      - `bash tests/verify_c99_async_frame_empty_descriptors.sh`：通过。

## 目标

父级任务路径：async 相关资源改成动态或至少明确可配置，不再依赖小规模写死容量。

  - [x] 为 `ThreadPool` 容量补充可配置入口，避免生产路径只能依赖小规模写死常量；最小验证：相关 thread 测试通过。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya` 通过；21 tests passed，83 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya` 通过；11 tests passed，11 assertions passed。

## 目标

- async 相关资源改成动态或至少明确可配置，不再依赖小规模写死容量。
  - [x] 梳理 `http1_async` 请求头 scratch buffer 的容量策略，补充明确可配置或动态扩容路径；最小验证：相关 HTTP async 测试通过。
    - 完成记录：`lib/std/http/http1_async.uya` 新增 `HTTP1_ASYNC_REQUEST_HEADER_INLINE_CAP`、请求头所需容量计算、动态分配/释放 helper，并将普通 async、同步 streaming、async streaming 请求发送路径改为按实际请求头长度分配；移除 Host 写入的 200 字节隐含截断。
    - 验证命令：`../uya/bin/uya test tests/test_http1_async_client.uya`
    - 验证结果：通过；7 个测试全部 OK，包含 `http1_async_request_header_buffer_grows_past_inline_cap` 与 HTTP async loopback 回归。

## 2026-06-18

# Uya 异步生产化 TODO（完整语法 + 动态资源）
## 目标

- [x] async 相关资源改成动态或至少明确可配置，不再依赖小规模写死容量。
  - [x] 梳理编译器 async transform / C99 await / frame meta 容量上限，改为动态或明确诊断可配置；最小验证：相关 compiler async 测试通过。
    - 验证：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya` 通过。
    - 验证：`bash tests/verify_async_await_capacity.sh` 通过，生成并运行 300 个顺序 @await 的容量回归。
    - 验证：`make uya` 通过，自举编译器构建完成。
    - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya` 通过，确认 frame meta 上限调整后无段错误。
    - 验证：`bash tests/verify_async_full_language_matrix.sh` 通过，positive matrix、禁止 @await 位置、nested future boundary 和 macro combo 均通过。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 新增 Linux+C99 共享 async 运行时语义冒烟矩阵脚本，覆盖 `Scheduler`、`async_compute`、DNS、HTTP async 与 TLS/HTTPS 相关最小回归。
    - 最小验证命令：`./tests/verify_async_shared_runtime_matrix.sh`
    - 完成条件：脚本固定使用 `../uya/bin/uya`，并在当前 Linux+C99 主链路上通过所列共享 async 运行时冒烟用例。
    - 验证结果：通过。覆盖 `tests/test_std_async_scheduler.uya`、`tests/test_async_compute_types.uya`、`tests/test_std_dns_async_transport.uya`、`tests/test_http1_async_client.uya`、`tests/test_https_bridge_safety.uya`。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 在共享矩阵基础上补齐 HTTP/DNS/TLS/`async_compute`/`Scheduler` 的同一 event loop / waker / cancellation 语义断言。
    - 最小验证命令：`./tests/verify_async_shared_runtime_matrix.sh`
    - 完成条件：矩阵不只验证能编译，还验证各模块通过相同 `LinuxEpoll`、`Waker` 与 `Scheduler` 行为完成可观察协作。
    - 验证记录：2026-06-18 运行 `./tests/verify_async_shared_runtime_matrix.sh` 通过；新增共享语义用例断言 HTTP/DNS/TLS/`async_compute`/`Scheduler` 代表 future 通过同一 `EventLoop`/`Waker` 注册、唤醒并传播 cancellation。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 将共享 async 运行时矩阵接入面向生产收口的文档说明。
    - 最小验证命令：`git diff --check`
    - 完成条件：`docs/async_production_todo.md`、`docs/async_status_matrix.md` 或相关设计文档不再把未验证链路表述为已完全量产。
    - 验证记录：2026-06-18 运行 `git diff --check`，通过；`docs/async_status_matrix.md` 已加入共享 runtime 生产收口矩阵，并将 HTTP/DNS/TLS async 客户端主链路改为“生产收口中”；`docs/async_production_todo.md` 已声明旧历史结论不覆盖共享 runtime 矩阵。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 新增共享 async 运行时语义的可复现基线脚本，串行覆盖 `Scheduler`、HTTP、DNS、TLS loopback 与 `async_compute`；最小验证命令：`bash tests/verify_async_runtime_shared_semantics.sh`；完成条件：脚本只使用 `../uya/bin/uya` 并全部通过。
    - 验证：`bash tests/verify_async_runtime_shared_semantics.sh` 通过；覆盖 `test_std_async_scheduler.uya`、`test_async_multi_fd_concurrent.uya`、`test_async_fd.uya`、`test_std_thread.uya`、`test_async_compute_types.uya`、`test_http1_async_client.uya`、`test_std_dns_async_transport.uya`、`test_https_loopback.uya`。

## 2026-06-18

上下文：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## 目标 > Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 将共享 runtime 基线接入 async/full-language 验证入口，避免 HTTP/DNS/TLS/`async_compute` 只作为分散单项测试存在；最小验证命令：`bash tests/verify_async_full_language_matrix.sh`；完成条件：矩阵脚本包含共享 runtime 基线且通过。
    - 验证命令：`bash tests/verify_async_full_language_matrix.sh`
    - 验证结果：通过；输出确认 `verify_async_shared_runtime_matrix` 已作为 full-language 矩阵阶段执行，并以 `shared runtime matrix` 汇总通过。

## 目标

- Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。
  - [x] 审计 HTTP/DNS/TLS/`async_compute`/`Scheduler` 是否都通过同一套 `Future` / `Poll` / `Waker` / `EventLoop` / cancellation 语义推进，补齐缺失的失败或取消回归；最小验证命令：相关新增测试加 `bash tests/verify_async_runtime_shared_semantics.sh`；完成条件：缺口有测试或文档化边界。
    验证记录：已将 `tests/test_async_shared_runtime_semantics.uya` 接入 `tests/verify_async_runtime_shared_semantics.sh`，覆盖 HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享 `TaskQueue_i32`、`EventLoop`、`Waker` 和 cancellation 语义。
    验证命令：`../uya/bin/uya test tests/test_async_shared_runtime_semantics.uya`，结果：通过，1 个测试、14 个断言通过。
    验证命令：`bash tests/verify_async_runtime_shared_semantics.sh`，结果：通过，脚本输出 `verify_async_runtime_shared_semantics: shared async runtime baseline passed`。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 文档同步共享 runtime 语义的真实覆盖范围和剩余边界；最小验证命令：`git diff --check`；完成条件：`docs/async_status_matrix.md` 与 `docs/std_async_design.md` 不再把未统一验收的分散测试表述为完整量产。
    - 验证命令：`git diff --check`
    - 验证结果：通过；`docs/async_status_matrix.md` 与 `docs/std_async_design.md` 已改为阶段性覆盖/目标态口径，不再把未统一验收的分散测试表述为完整量产。

## 2026-06-18

上下文：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` / `## 目标` / `Linux + C99 主链路下，HTTP/DNS/TLS/async_compute/Scheduler 共享同一套稳定的 async 运行时语义。`

  - [x] 审计 HTTP/DNS/TLS/`async_compute`/`Scheduler` 当前入口、共享 runtime 资源、取消/唤醒/错误语义，产出 `docs/async_runtime_semantics_matrix.md`；最小验证：`git diff --check docs/todo_async_full_language_dynamic_resources.md docs/async_runtime_semantics_matrix.md`。
    - 验证命令：`git diff --check docs/todo_async_full_language_dynamic_resources.md docs/async_runtime_semantics_matrix.md`
    - 验证结果：通过，命令退出码 0。
    - 完成记录：新增 `docs/async_runtime_semantics_matrix.md`，记录 HTTP/DNS/TLS/`async_compute`/`Scheduler` 的当前入口、共享 runtime 资源、已覆盖语义、缺口和下一步最小验证。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。
  - [x] 基于审计矩阵补齐一个 Linux+C99 共享 runtime smoke 回归，至少同时覆盖 `Scheduler` + `async_compute` + 一个 AsyncFd/http 路径；最小验证：`../uya/bin/uya test --c99 <新增测试>`。
    - 新增回归：`tests/test_async_shared_runtime_semantics.uya` 中 `shared_runtime_smoke_scheduler_async_compute_and_async_fd_share_linux_epoll`。
    - 验证命令：`../uya/bin/uya test --c99 tests/test_async_shared_runtime_semantics.uya`；结果：通过，2 个测试通过，0 失败。
    - 相关验证命令：`./tests/verify_async_runtime_shared_semantics.sh`；结果：通过，shared async runtime baseline passed。

## 2026-06-18

上下文：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` > `## 目标` > `Linux + C99 主链路下，HTTP/DNS/TLS/async_compute/Scheduler 共享同一套稳定的 async 运行时语义。`

  - [x] 将 DNS/TLS 当前同步或半同步边界接入矩阵中的统一语义缺口，拆出可运行的后续实现叶子；最小验证：相关 todo 只保留可执行叶子，且每项包含验证命令。
    - 验证命令：`sed -n '7,20p' docs/todo_async_full_language_dynamic_resources.md`
    - 验证结果：通过；目标父级下已拆出 DNS transport 共享调度 smoke、DNS `A/AAAA` 聚合、TLS async 边界回归、TLS I/O Future 接入、共享 runtime 组合闸门五个可执行叶子，每项均包含最小验证命令和完成条件。
    - 验证命令：`git diff --check docs/todo_async_full_language_dynamic_resources.md`
    - 验证结果：通过，无 whitespace error。
- 上下文：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## 目标 > Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。
  - [x] 为 DNS async transport 增加共享 `Scheduler` / `LinuxEpoll` 组合 smoke，把真实 UDP/TCP fallback future 放进同一 `TaskQueue` 或等价共享调度入口；最小验证：`../uya/bin/uya test --c99 tests/test_async_runtime_shared_dns.uya`；完成条件：测试能证明 DNS transport 在 shared runtime 中完成 readiness、fallback 和资源清理。
    - 验证：`../uya/bin/uya test --c99 tests/test_async_runtime_shared_dns.uya` 通过（1 tests passed, 0 failed）。
    - 相关回归：`../uya/bin/uya test --c99 tests/test_std_dns_async_transport.uya` 通过（2 tests passed, 0 failed）；`../uya/bin/uya test --c99 tests/test_async_shared_runtime_semantics.uya` 通过（2 tests passed, 0 failed）。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 为 DNS `A/AAAA` 并发聚合补 async 查询实现和回归，避免继续只验证单 transport future；最小验证：`../uya/bin/uya test --c99 tests/test_std_dns_async_query_aggregate.uya`；完成条件：同一查询入口能聚合 `A` 与 `AAAA` 结果，并覆盖成功、部分失败和超时路径。
    - 验证：
      - `../uya/bin/uya test --c99 tests/test_std_dns_async_query_aggregate.uya`：通过，3 个测试覆盖 A/AAAA 并发聚合成功、A 失败保留 AAAA、双查询已发出后的 DnsTimeout 路径。
      - `../uya/bin/uya test --c99 tests/test_std_dns_async_transport.uya`：通过，2 个测试覆盖 IPv4-only TCP fallback 与 ANY 模式下并发 A/AAAA + A TCP fallback。
      - `../uya/bin/uya test --c99 tests/test_std_dns.uya`：通过，34 个测试覆盖既有 DNS 同步/异步基础回归。
## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 为 TLS/HTTPS I/O 增加显式 async 边界回归，固定 handshake/read/write 尚未返回 `Future` 的当前缺口，避免被 loopback handler 误判为 runtime 已接入；最小验证：`../uya/bin/uya test --c99 tests/test_tls_async_runtime_boundary.uya`；完成条件：测试或结构性检查能稳定指出 TLS I/O 未接入 `Waker`/`EventLoop`，并随真实接入时反向更新。
    - 验证：`../uya/bin/uya test --c99 tests/test_tls_async_runtime_boundary.uya` 通过，1 个测试通过、8 个断言通过；结构性检查确认 `lib/tls/https.uya` 中 `https_read_some` / `https_write_all` / `https_client_handshake` / `https_server_handshake` 仍为同步签名，且未出现 `Future<!usize>` / `wait_readable` / `wait_writable` / `EventLoop`。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 将 TLS handshake/read/write 拆为 `Future<!usize>` 或等价 async leaf primitive，并接入 `Waker.wait_readable/wait_writable`；最小验证：`../uya/bin/uya test --c99 tests/test_tls_async_io_future.uya`；完成条件：TLS I/O would-block 时返回 `Poll.Pending`，ready 后通过共享 `LinuxEpoll` 唤醒并返回 `Poll.Ready`。
    验证：`../uya/bin/uya test --c99 tests/test_tls_async_io_future.uya` 通过（1 test，17 assertions）。
    相关回归：`../uya/bin/uya test --c99 tests/test_tls_async_runtime_boundary.uya` 通过（1 test，9 assertions）；`../uya/bin/uya test --c99 tests/test_https_loopback.uya` 通过（1 test）。
## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 增加 HTTP/DNS/TLS/`async_compute` 共享 runtime 组合闸门，证明同一调度语义下 readiness、eventfd wake、取消和 cleanup 不互相冲突；最小验证：`../uya/bin/uya test --c99 tests/test_async_runtime_shared_semantics.uya`；完成条件：测试同时覆盖至少一个 I/O future、一个 DNS future、一个 TLS async future 或边界替代项，以及一个 `async_compute` future。
    - 验证：`../uya/bin/uya test --c99 tests/test_async_runtime_shared_semantics.uya` 通过，3 个测试、29 个断言；覆盖共享调度矩阵、真实 `AsyncFd` I/O future + `async_compute` 同队列，以及 DNS/TLS async future 边界替代项。
    - 相关回归：`../uya/bin/uya test --c99 tests/test_async_shared_runtime_semantics.uya` 通过，2 个测试、19 个断言。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 补齐共享语义文档与既有阶段性文档的口径同步，避免继续把分散回归表述为主链路已收口；最小验证：`git diff --check docs/std_async_design.md docs/async_status_matrix.md docs/async_runtime_semantics_matrix.md`。
    - 验证命令：`git diff --check docs/std_async_design.md docs/async_status_matrix.md docs/async_runtime_semantics_matrix.md`
    - 验证结果：通过；命令退出码 0，无输出。
- [x] 拆分 TLS I/O 接入共享 runtime 的实现边界与验证任务，避免把 HTTPS loopback 当作 TLS async I/O 已接入 `Waker` / `EventLoop` / `Scheduler`；最小验证：`git diff --check docs/todo_async_full_language_dynamic_resources.md docs/async_runtime_semantics_matrix.md`。
  - 上下文：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` / `## 目标` / `Linux + C99 主链路下，HTTP/DNS/TLS/async_compute/Scheduler 共享同一套稳定的 async 运行时语义。`
  - 完成内容：已在主 TODO 中拆出 TLS 审计、awaitable I/O API 设计、负向/边界验证、TLS I/O future 实现、统一 runtime smoke 五个后续叶子；已在 `docs/async_runtime_semantics_matrix.md` 中明确 `tests/test_https_loopback.uya` 只能证明 handler bridge，不能证明 TLS handshake/read/write 接入 `Waker` / `EventLoop` / `Scheduler`。
  - 验证命令：`git diff --check docs/todo_async_full_language_dynamic_resources.md docs/async_runtime_semantics_matrix.md`
  - 验证结果：通过。
## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 审计 `lib/tls/https.uya` / TLS I/O 调用链，列出 handshake/read/write 当前同步或 would-block 映射边界；完成条件：TODO 中明确哪些函数尚未返回 `Future`，验证命令：`rg -n "https_read_some|handshake|tls_.*write|Future|Waker" lib/tls lib/std/http tests/test_https_loopback.uya`。
    - 审计结论：
      - `https_read_some(fd, out, out_max) !usize` 和 `https_write_all(fd, src, src_len) !void` 仍是同步 syscall 包装；它们把 `EAGAIN` / `EWOULDBLOCK` / `EINPROGRESS` / `EALREADY` 统一映射为 `error.ReadWouldBlock`，不会自身返回 `Future`。
      - `https_read_some_async(...) Future<!usize>` 已存在，`HttpsReadFuture.poll` 在 `ReadWouldBlock` 时调用 `waker.wait_readable(fd)` 并返回 `Poll.Pending`；其他错误当前收敛为 `ConnectionClosed`。
      - `https_write_all_async(...) Future<!usize>` 已存在，`HttpsWriteAllFuture.poll` 直接用 `sys_write` 保存 `off` 进度，`ReadWouldBlock` 时调用 `waker.wait_writable(fd)` 并返回 `Poll.Pending`；同步 `https_write_all` 仍不返回 `Future`。
      - `https_handshake_async(...) Future<!usize>` 已存在，但 `HttpsHandshakeFuture.poll` 只是调用同步 `https_server_handshake` / `https_client_handshake`；这些同步握手函数内部重新分配局部握手缓冲并通过 `https_read_handshake_input`、`https_read_handshake_burst`、`https_read_client_second_flight`、`https_read_server_second_flight`、`https_write_all` 推进多步握手。would-block 只会在最外层被映射为 readable pending，未保存握手阶段、局部收发缓冲、已写偏移，也没有 writable pending 边界。
      - `https_read_tls_record_exact(...) !void`、`https_read_exact(...) !void` 和握手读取辅助函数仍是同步精确读取循环；would-block 通过 `error.ReadWouldBlock` 向上传播，不返回 `Future`，也不登记 `Waker`。
      - `https_server_serve_once`、`https_server_serve_uyagin_once`、`https_get_internal` / `https_get` / `https_get_insecure` 仍走同步 `https_server_handshake` / `https_client_handshake`、同步 TLS record read、同步 `https_write_all`；尚未接入共享 runtime 的 TLS I/O future。
      - `lib/std/http/websocket_tls.uya` 的 `websocket_tls_transport_accept_server` 和 `websocket_accept_from_https_server` 仍同步 accept + TLS handshake + HTTP upgrade；尚未返回 `Future`。
      - `WebSocketTlsTransport.read/read_exact/write/write_all` 虽然签名返回 `Future<!usize>`，但只是用 `websocket_tls_ready_result(...)` 包装同步 `websocket_tls_transport_read_some_sync` / `read_exact_sync` / `write_all_sync` 的结果；would-block 会被关闭连接并映射为 `WebSocketConnectionClosed`，不会 `Poll.Pending` 或注册 `Waker`。
      - `tests/test_https_loopback.uya` 当前只验证同步 `https_read_some` 的 would-block 映射、closed pipe 映射、同步 `https_write_all` roundtrip，以及同步 HTTPS loopback；其中 handler 返回 `Future` 不能证明 TLS I/O 已接入 `Waker` / `EventLoop` / `Scheduler`。
    - 尚未返回真实 awaitable `Future` 或尚未真实 pending 的函数/边界：
      - 同步入口：`https_read_some`、`https_write_all`、`https_connect_fd`、`https_accept_one`、`https_read_tls_record_exact`、`https_client_handshake`、`https_server_handshake`、`https_read_uyagin_request`、`https_server_serve_once`、`https_server_serve_uyagin_once`、`https_get_internal`。
      - TLS WebSocket 入口：`websocket_tls_transport_accept_server`、`websocket_accept_from_https_server`、`websocket_tls_transport_read_some_sync`、`websocket_tls_transport_read_exact_sync`、`websocket_tls_transport_write_all_sync`，以及 `WebSocketTlsTransport.read/read_exact/write/write_all` 的 ready-wrapper Future。
      - 部分已有 Future 仍不完整：`https_handshake_async` 返回 `Future`，但没有可恢复握手状态机和 writable interest；当前只能把同步握手遇到的 `ReadWouldBlock` 粗略转成 readable pending。
    - 验证：
      - `rg -n "https_read_some|handshake|tls_.*write|Future|Waker" lib/tls lib/std/http tests/test_https_loopback.uya` 退出码 0；输出确认 `lib/tls/https.uya` 中 `https_read_some_async`、`https_write_all_async`、`https_handshake_async` 已存在，同时同步 `https_client_handshake` / `https_server_handshake`、`https_read_tls_record_exact`、`https_get_internal`、`https_server_serve_*` 和 WebSocket TLS ready-wrapper 路径仍在调用链上。

## 归档记录 - 2026-06-18

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 设计 TLS handshake/read/write 的 awaitable I/O 叶子 API，使 pending 路径通过 `Waker.wait_readable/wait_writable` 注册 fd interest；完成条件：文档给出 API、错误语义、取消/清理语义，验证命令：`git diff --check docs/todo_async_full_language_dynamic_resources.md docs/async_runtime_semantics_matrix.md`。
    - 验证：`git diff --check docs/todo_async_full_language_dynamic_resources.md docs/async_runtime_semantics_matrix.md`，通过，无输出。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 为 TLS I/O 尚未接入共享 runtime 补负向/边界验证，禁止把 `tests/test_https_loopback.uya` 当作 `Waker` / `EventLoop` / `Scheduler` 接入证明；完成条件：验证脚本或文档矩阵能区分 handler bridge 与 TLS I/O future，验证命令：`../uya/bin/uya test --c99 tests/test_https_loopback.uya` 加边界验证命令。
    - 完成内容：`docs/async_runtime_semantics_matrix.md` 已区分 `tests/test_https_loopback.uya` 的 handler bridge 证据、`tests/test_tls_async_runtime_boundary.uya` 的结构性边界证据，以及 `tests/test_tls_async_io_future.uya` 的 TLS I/O future 行为证据；明确 loopback 不能单独作为 TLS I/O 接入 `Waker` / `EventLoop` / `Scheduler` 的证明。
    - 验证：`../uya/bin/uya test --c99 tests/test_https_loopback.uya` 通过（1 test）。
    - 验证：`../uya/bin/uya test --c99 tests/test_tls_async_runtime_boundary.uya` 通过（1 test，9 assertions）。
    - 验证：`../uya/bin/uya test --c99 tests/test_tls_async_io_future.uya` 通过（1 test，17 assertions）。
    - 验证：`git diff --check docs/async_runtime_semantics_matrix.md docs/todo_async_full_language_dynamic_resources.md` 通过。

## 目标

父级任务路径：Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。

  - [x] 实现 TLS handshake/read/write async future 并接入同一 `LinuxEpoll` / `Scheduler`；完成条件：TLS I/O 的 would-block 路径返回 `Poll.Pending` 并注册 fd interest，验证命令：`../uya/bin/uya test --c99 tests/test_tls_async_runtime_io.uya`。
    验证记录：
    - `../uya/bin/uya test --c99 tests/test_tls_async_runtime_io.uya`：通过，1 个测试、16 个断言通过。
    - `../uya/bin/uya test --c99 tests/test_tls_async_io_future.uya`：通过，1 个测试、17 个断言通过。
    - `../uya/bin/uya test --c99 tests/test_tls_async_runtime_boundary.uya`：通过，1 个测试、9 个断言通过。

## 目标

- [x] Linux + C99 主链路下，HTTP/DNS/TLS/`async_compute`/`Scheduler` 共享同一套稳定的 async 运行时语义。
  - [x] 把 TLS async I/O 纳入共享 runtime smoke，与 HTTP/DNS/`async_compute` 同一 `TaskQueue` / `EventLoop` 组合验收；完成条件：统一 smoke 覆盖 TLS pending、ready、cancel/cleanup，验证命令：`../uya/bin/uya test --c99 tests/test_async_runtime_shared_semantics.uya`。
    - 验证：`../uya/bin/uya test --c99 tests/test_async_runtime_shared_semantics.uya`，通过，4 tests passed，41 assertions passed。
    - 相关验证：`../uya/bin/uya test --c99 tests/test_tls_async_runtime_io.uya`，通过，1 test passed，16 assertions passed。
    - 相关验证：`../uya/bin/uya test --c99 tests/test_tls_async_io_future.uya`，通过，1 test passed，17 assertions passed。

## 目标

- [x] 建立可复现的验证矩阵，保证“能编译”与“生产可用”之间没有空档。
  - 完成内容：新增 `tests/verify_async_production_smoke.sh`，将 full-language/boundary、shared runtime、nested future、HTTP async epoll C99 compile/runtime smoke 串成单一生产 smoke 闸门。
  - 配套修正：`tests/verify_http_bench_async_epoll_compile.sh` 与 `tests/verify_http_bench_async_epoll_runtime.sh` 固定使用 `../uya/bin/uya`，避免使用 `bin/uya` 或环境覆盖编译器。
  - 验证命令：`bash tests/verify_async_production_smoke.sh`
  - 验证结果：通过；输出摘要 `verify_async_production_smoke: full-language, shared runtime, nested future, and HTTP async epoll smoke matrix passed`。

## 2026-06-18 本轮完成

上下文：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## 先澄清边界 > “完整 Uya 语言语法”指的是：凡是同步函数体里合法的 Uya 语法，放进 `@async_fn` 后也应合法并按同样语义工作。

  - [x] 将“同步函数体合法语法均应可放入 `@async_fn`”拆成可执行验收清单；最小验证：`sed -n '7,24p' docs/todo_async_full_language_dynamic_resources.md` 确认覆盖声明、表达式、控制流、错误处理、清理语句、模式匹配和内建函数体语法；完成条件：后续子任务不需要重新猜测完整语法边界。
    验证命令：`sed -n '7,32p' docs/todo_async_full_language_dynamic_resources.md`
    验证结果：通过，主 todo 中已列出声明/表达式、控制流、错误处理、清理语句、模式匹配和内建函数体语法六个后续叶子任务。
    验证命令：`rg -n "\\[~\\]|\\[[xf]\\]" docs/todo_async_full_language_dynamic_resources.md`
    验证结果：通过，归档前仅本叶子为 `[~]`，无遗留 `[x]` / `[f]`。
    验证命令：`git diff --check -- docs/todo_async_full_language_dynamic_resources.md`
    验证结果：通过，无空白错误。

## 先澄清边界

父级任务路径：
- “完整 Uya 语言语法”指的是：**凡是同步函数体里合法的 Uya 语法，放进 `@async_fn` 后也应合法并按同样语义工作**，除非语言规范本来就明确禁止。

  - [x] 建立 async 函数体声明与基本表达式覆盖测试；最小验证：`../uya/bin/uya test <新增测试>`；完成条件：`const`、`var`、赋值、调用、字段/下标/切片、算术/比较/逻辑表达式在 `@async_fn` 中与同步函数一致。
    - 新增测试：`tests/test_async_decl_expr_coverage.uya`
    - 验证：`../uya/bin/uya test tests/test_async_decl_expr_coverage.uya`，通过（1 tests，2 assertions）。
    - 相关回归：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya`，通过（4 tests，20 assertions）。

## 先澄清边界

父级任务路径：`“完整 Uya 语言语法”指的是：凡是同步函数体里合法的 Uya 语法，放进 @async_fn 后也应合法并按同样语义工作，除非语言规范本来就明确禁止。`

  - [x] 建立 async 函数体控制流覆盖测试；最小验证：`../uya/bin/uya test <新增测试>`；完成条件：`if`、`while`、`for`、`break`、`continue`、块语句和 `return` 在 `@async_fn` 中与同步函数一致。
    - 新增测试：`tests/test_async_control_flow_body.uya`
    - 验证：`../uya/bin/uya test tests/test_async_control_flow_body.uya`，通过，3 tests passed，0 failed。
    - 相关回归：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya`，通过，4 tests passed，0 failed。

## 先澄清边界

父级任务路径：
- “完整 Uya 语言语法”指的是：**凡是同步函数体里合法的 Uya 语法，放进 `@async_fn` 后也应合法并按同样语义工作**，除非语言规范本来就明确禁止。
  - [x] 建立 async 函数体清理语句覆盖测试；最小验证：`../uya/bin/uya test <新增测试>`；完成条件：`defer`、`errdefer` 及其规范禁止的控制流在 `@async_fn` 中与同步函数一致。
    - 验证：`../uya/bin/uya test tests/test_async_cleanup_body_coverage.uya` 通过，2 个测试通过。
    - 验证：`../uya/bin/uya check tests/error_async_defer_return.uya` 按预期失败，诊断包含 `defer/errdefer 块中不能使用 return 语句`。
    - 验证：`../uya/bin/uya check tests/error_async_errdefer_break.uya` 按预期失败，诊断包含 `defer/errdefer 块中不能使用 break 语句`。
    - 验证：`../uya/bin/uya check tests/error_async_defer_continue_nested.uya` 按预期失败，诊断包含 `defer/errdefer 块中不能使用 continue 语句`。
    - 相关回归：`bash tests/verify_async_full_language_matrix.sh` 通过。

## 先澄清边界

父级任务路径：
- “完整 Uya 语言语法”指的是：**凡是同步函数体里合法的 Uya 语法，放进 `@async_fn` 后也应合法并按同样语义工作**，除非语言规范本来就明确禁止。

  - [x] 建立 async 函数体模式匹配覆盖测试；最小验证：`../uya/bin/uya test <新增测试>`；完成条件：`match` 语句/表达式、枚举/联合体模式和 `else` 分支在 `@async_fn` 中与同步函数一致。
    验证：`../uya/bin/uya test tests/test_async_match_body_coverage.uya` 通过（3 tests, 0 failed）。
    相关验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya` 通过（4 tests, 0 failed）。
## 先澄清边界

- [x] “完整 Uya 语言语法”指的是：**凡是同步函数体里合法的 Uya 语法，放进 `@async_fn` 后也应合法并按同样语义工作**，除非语言规范本来就明确禁止。
  - [x] 建立 async 函数体内建函数体语法覆盖测试；最小验证：`../uya/bin/uya test <新增测试>`；完成条件：`@params`、`@func_name`、`@src_*`、`@error_id`、`@error_name` 等本来允许在同步函数体内使用的内建在 `@async_fn` 中语义一致。
    - 验证命令：`../uya/bin/uya test tests/test_async_builtin_body_coverage.uya`
    - 验证结果：通过；1 个测试通过，覆盖 `@params.0/.1`、`@func_name`、`@src_name`、`@src_path`、`@src_line`、`@src_col`、`@error_id`、`@error_name` 在 `@async_fn` 中与同步函数体语义对齐。
    - 相关回归：`../uya/bin/uya test tests/test_async_decl_expr_coverage.uya`、`../uya/bin/uya test tests/test_varargs_full.uya`、`../uya/bin/uya test tests/test_error_id_builtin.uya`、`../uya/bin/uya test tests/test_error_name_builtin.uya`、`../uya/bin/uya test tests/test_src_location.uya` 均通过。

## 先澄清边界

父级任务路径：这**不等于**放开所有 `@await` 位置限制。现有明确非法的规则仍然有效，例如：

  - [x] `@await` 只能出现在 `@async_fn` 中。
    验证命令：`../uya/bin/uya check tests/error_await_in_future_returning_non_async.uya`，结果：失败且报告 `@await 只能在 @async_fn 函数内使用`（先确认旧实现曾错误通过，修复后通过负例验证）。
    验证命令：`../uya/bin/uya check tests/error_await_outside_async.uya`，结果：失败且报告 `@await 只能在 @async_fn 函数内使用`。
    验证命令：`./tests/verify_async_full_language_matrix.sh`，结果：通过，输出 `forbidden @await positions ... passed`。
## 先澄清边界

父级任务路径：
- [ ] 这**不等于**放开所有 `@await` 位置限制。现有明确非法的规则仍然有效，例如：
  - [x] `@await` 出现在 `while` 条件等当前明确禁止的位置时，仍应报错，除非后续先修改语言规范。
    - 验证命令：`../uya/bin/uya check tests/error_async_await_in_while_cond.uya`
    - 验证结果：通过，命令按预期退出 1，并报告 `@async_fn 状态机结构验证失败，请检查 @await 使用是否规范`。
    - 验证命令：`bash tests/verify_async_full_language_matrix.sh`
    - 验证结果：通过，输出 `verify_async_full_language_matrix: positive matrix (31 tests), iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed`。

## 先澄清边界

- [x] 这**不等于**放开所有 `@await` 位置限制。现有明确非法的规则仍然有效，例如：
  - [x] async 递归 / 间接递归的限制是否保留，必须由新的大小模型或规范决定，不能在实现里偷偷放开。
    - 结论：保留限制。现有规范 `docs/uya.md` 仍明确要求 async 状态机大小编译期确定、递归调用编译错误；实现中 `src/checker/check_call.uya` 对直接递归和 async 调用环均有诊断，不能在新大小模型或规范更新前放开。
    - 验证命令：`../uya/bin/uya check tests/error_async_recursive.uya`
    - 结果：按预期失败，诊断包含 `@async_fn 函数不允许直接递归调用（待 CPS/状态机大小计算实现）`。
    - 验证命令：`../uya/bin/uya check tests/error_async_indirect_recursive.uya`
    - 结果：按预期失败，诊断包含 `@async_fn 函数不允许形成递归调用环（待 CPS/状态机大小计算实现）`。

## 先澄清边界

- [x] 本阶段先以 **Linux + C99** 为生产主线；`kqueue` / `IOCP` 不作为阻塞项。
  - 验证命令：
    - `sed -n '1,18p' docs/async_status_matrix.md`
    - `sed -n '1,12p;136,144p' docs/async_production_todo.md`
    - `sed -n '248,266p' docs/std_async_design.md`
  - 验证结果：`docs/async_status_matrix.md` 明确当前范围为 Linux + C99 后端；`docs/async_production_todo.md` 将 macOS kqueue / Windows IOCP 后端列为后续待办；`docs/std_async_design.md` 将多平台事件后端列为第三里程碑，Linux 异步 I/O 是第一里程碑。

## 源码现状审计 / 4. 文档口径与源码状态有漂移

- [x] 现有“量产完成”文档没有把上面的固定容量、语法禁区和回退路径当成阻塞项。
  - 完成内容：`docs/async_production_todo.md` 明确将固定容量、语法禁区和回退路径列为新的生产阻塞项，不再归入“量产后二阶段”；历史量产定义补充“不覆盖回退路径收口”。`docs/async_status_matrix.md` 明确要求后续 release 口径持续保留这些阻塞项，不能把历史“量产完成”升级为当前 async 生产完成结论。
  - 验证命令：`git diff --check`
  - 验证结果：通过。

## 源码现状审计 / 4. 文档口径与源码状态有漂移

- [x] 本目标完成前，必须先把“文档真相”与“源码真相”重新对齐，再谈 release 口径。
  - 完成内容：更新主 todo 审计口径，使其与当前源码常量、nested future 专项验证、迭代器 interface/ref 边界和 async full language matrix 覆盖范围一致。
  - 验证命令：
    - `rg -n "Future<Future|nested|too many|C99_ASYNC_MAX_AWAITS|MAX_SEGMENTS|MAX_LOCALS|iterator|接口|release|已知限制|poll" docs/std_async_design.md docs/uya.md docs/grammar_formal.md docs/grammar_quick.md docs/builtin_functions.md tests/verify_async_full_language_matrix.sh tests/verify_async_nested_future_boundary.sh tests/test_async_nested_future_poll.uya tests/test_async_for_iterator_ref_await.uya tests/error_for_iterator_interface_value.uya tests/error_async_for_iterator_interface_await.uya src/codegen/c99/async_transform.uya src/codegen/c99/internal.uya src/checker/check_node_extra.uya src/codegen/c99/function.uya`（通过；确认 `MAX_SEGMENTS=4098`、`MAX_LOCALS=4096`、`C99_ASYNC_MAX_AWAITS=4096`，nested future 已由专项脚本固定为正向回归，iterator interface value for 仍是同步/async 通用边界）
    - `../uya/bin/uya test tests/test_async_nested.uya`（通过；2 tests passed）
    - `bash tests/verify_async_nested_future_boundary.sh`（通过；`nested poll subset passes and !Future<Future<T>> C emission compiles`）
    - `bash tests/verify_async_full_language_matrix.sh`（通过；positive matrix 31 tests、iterator boundaries、forbidden @await positions、nested future boundary、shared runtime matrix、macro combo passed）
    - `git diff --check`（通过）
  - 完成条件：本 todo 的审计口径与当前源码常量、nested future 专项验证、迭代器 interface/ref 边界和 async full language matrix 覆盖范围一致。

## 完成定义 / `@async_fn` 函数体语法支持范围

- [x] 建立并校验 async/sync 函数体语法覆盖矩阵，明确已有覆盖、缺失覆盖和同步/async 共同限制；最小验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya`、`./tests/verify_async_full_language_matrix.sh`、`git diff --check`。
  - 父级任务：`@async_fn` 对 Uya 函数体语法的支持范围，与同步函数体一致，只保留显式规范限制。
  - 验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya` 通过（4 tests，20 assertions）。
  - 验证：`./tests/verify_async_full_language_matrix.sh` 通过（positive matrix 31 tests、iterator for boundaries、forbidden @await positions、nested future boundary、shared runtime matrix、macro combo）。
  - 验证：`git diff --check` 通过。

## 完成定义 / @async_fn 对 Uya 函数体语法的支持范围，与同步函数体一致，只保留显式规范限制

- [x] 补齐矩阵中缺失的 large state machine 语法回归；最小验证：`../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya`、`./tests/verify_async_full_language_matrix.sh`。
  - 变更：`tests/verify_async_full_language_matrix.sh` 已纳入 `tests/test_async_large_state_machine_syntax.uya`，矩阵摘要从 31 tests 更新为 32 tests；主 todo 覆盖快照移除 large state machine 缺失项。
  - 验证命令：`../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya`
  - 验证结果：通过，7/7 tests passed。
  - 验证命令：`./tests/verify_async_full_language_matrix.sh`
  - 验证结果：通过，输出 `verify_async_full_language_matrix: positive matrix (32 tests), iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed`。

## 完成定义

父级任务路径：
- [ ] `@async_fn` 对 Uya 函数体语法的支持范围，与同步函数体一致，只保留显式规范限制。

  - [x] 将非显式规范限制的 async 语法缺口转成正向回归或正式 checker 诊断；最小验证：相关 `../uya/bin/uya test ...`、`./tests/verify_async_full_language_matrix.sh`。
    - 验证：`../uya/bin/uya check tests/error_async_for_iterator_interface_await.uya` 预期失败，命中 checker 诊断：`接口类型变量的 for 迭代目前不支持；请使用具体实现迭代器类型`。
    - 验证：`../uya/bin/uya test tests/test_async_for_iterator_ref_await.uya` 通过，1 个测试通过。
    - 验证：`rg -n "尚未支持" src/codegen/c99/function.uya src/codegen/c99/async_transform.uya src/lower/async.uya` 无命中。
    - 验证：`./tests/verify_async_full_language_matrix.sh` 通过：positive matrix、iterator for boundaries、forbidden @await positions、nested future boundary、shared runtime matrix、macro combo passed。

## 完成定义

父级任务路径：`@async_fn` 对 Uya 函数体语法的支持范围，与同步函数体一致，只保留显式规范限制。

- [x] `@async_fn` 对 Uya 函数体语法的支持范围，与同步函数体一致，只保留显式规范限制。
  - [x] 汇总 `@async_fn` 函数体语法完成证据并移除已过期的 workaround/限制说明；最小验证：`./tests/verify_async_full_language_matrix.sh`、`git diff --check`。
    - 完成记录：更新 nested future、iterator ref 绑定与矩阵摘要的当前证据口径；移除已过期的失败边界/未支持说明。
    - 验证：`./tests/verify_async_full_language_matrix.sh` 通过，输出 `verify_async_full_language_matrix: positive async language matrix, iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed`。
    - 验证：`git diff --check` 通过。

## 完成定义

父级任务路径：async codegen / lowering / checker 中不再存在小规模固定上限作为正常路径容量门槛。

  - [x] checker async frame meta 表改为按需扩容，不再由 `MAX_ASYNC_FRAME_METAS` 限制；最小验证：`python3 tests/verify_async_compiler_no_fixed_limits.py` 与 `../uya/bin/uya test tests/test_async_frame_type.uya`。
    - 验证：`python3 tests/verify_async_compiler_no_fixed_limits.py` 通过。
    - 验证：`../uya/bin/uya test tests/test_async_frame_type.uya` 通过，3 个测试通过。
    - 验证：`../uya/bin/uya test tests/test_async_frame_stack_ok.uya` 通过，2 个测试通过。
    - 验证：`../uya/bin/uya test tests/test_async_frame_inline_temp.uya` 通过，1 个测试通过。
    - 验证：`../uya/bin/uya test tests/test_async_frame_methods.uya` 通过，2 个测试通过。

## 完成定义

父级任务：async codegen / lowering / checker 中不再存在小规模固定上限作为正常路径容量门槛。

  - [x] codegen await 收集/绑定表改为按需扩容，不再由 `C99_ASYNC_MAX_AWAITS` 限制；最小验证：新增超过旧上限的 async await C99 生成回归。
    - 验证：`bash tests/verify_async_await_capacity.sh` 通过；生成 4097 个 await 的 async C99，并确认最终状态分支 `if (s->state == 4098)` 存在。
    - 验证：`make uya` 通过，更新 `../uya/bin/uya`。
    - 验证：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya` 通过。
    - 验证：`../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya` 通过。
    - 验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya` 通过。
    - 额外验证：`bash tests/verify_async_full_language_matrix.sh` 执行到 shared runtime 阶段失败；新增 capacity 回归已通过，失败点为 `test_async_shared_runtime_semantics.uya` 的宿主 C 编译 `invalid initializer`（`GinContext_file_poll` / `Engine_serve_once_poll`），与本轮 4097-await C99 生成路径不同。

## 完成定义

- [x] async codegen / lowering / checker 中不再存在小规模固定上限作为正常路径容量门槛。
  - [x] async frame descriptor 发射不再按固定上限截断，descriptor table 大小按 checker meta count 生成；最小验证：`python3 tests/verify_async_compiler_no_fixed_limits.py` 与相关 async frame C99 回归。
    - 验证：`python3 tests/verify_async_compiler_no_fixed_limits.py` 通过。
    - 验证：`make uya` 通过，已重建 `../uya/bin/uya`。
    - 验证：`tests/verify_c99_async_frame_descriptors.sh` 通过，生成 `_uya_async_frame_descriptor_entries[7]` 且 count 为 7。
    - 验证：`tests/verify_c99_async_frame_empty_descriptors.sh` 通过，空表生成占位 `_uya_async_frame_descriptor_entries[1]` 且 count 为 0。
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya` 通过。
    - 验证：`../uya/bin/uya test tests/test_async_frame_type.uya` 通过。
    - 验证：`git diff --check` 通过。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/async_event.uya` 的 epoll slot/event 容量改为可配置增长策略，避免 `1024` 固定上限；最小验证：新增/更新相关测试并运行 `../uya/bin/uya test ...` 或对应程序回归。
    验证：先运行 `../uya/bin/uya test tests/test_std_async_event.uya`，旧实现因 1025 容量返回码 13 失败；实现后通过。
    验证：`../uya/bin/uya test tests/test_std_async_event_fd_reuse.uya` 通过，4 个内部用例全部 OK。
    验证：`../uya/bin/uya test tests/test_async_runtime_shared_dns.uya` 通过。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/async_scheduler.uya` 的 `TaskQueue<T>`、frame stack buffer、inline repoll 容量改为动态或可配置策略，避免 `64/8192/1024` 固定产品上限；最小验证：新增/更新相关测试并运行 `../uya/bin/uya test ...` 或对应程序回归。
    验证命令与结果：
    - `../uya/bin/uya test tests/test_std_async_scheduler.uya`：通过，16 tests passed。
    - `../uya/bin/uya test tests/test_async_scheduler_event_allocator_signature.uya`：通过，1 test passed。
    - `../uya/bin/uya test tests/test_async_frame_align_pool.uya`：通过，2 tests passed。
    - `git diff --check`：通过。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/async_frame.uya` 的 frame pool bucket、每 bucket 数量、descriptor 表容量改为动态或可配置策略，避免 `128/4096/512` 固定产品上限；最小验证：新增/更新相关测试并运行 `../uya/bin/uya test ...` 或对应程序回归。
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya` 通过（5 tests, 0 failed；覆盖 bucket 数 > 128 与 per bucket > 4096）。
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_negative.uya` 通过。
    - 验证：`../uya/bin/uya test tests/test_async_frame_stack_limit_env.uya` 通过。
    - 验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya` 通过（16 tests, 0 failed）。
    - 验证：`git diff --check` 通过。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/thread.uya` 的 worker、pending、task slot 容量改为动态或可配置策略，并保留明确的资源失败路径，避免 `32/32/16` 固定产品上限；最小验证：新增/更新相关测试并运行 `../uya/bin/uya test ...` 或对应程序回归。
    - 验证：
      - 先新增失败测试并确认失败：`../uya/bin/uya test tests/test_std_thread.uya`，失败点为 `thread_pool_config_can_exceed_legacy_static_limits` 中 `pool.worker_count` 仍被截断为 `32`，以及资源耗尽测试确认旧 fallback 未报错。
      - 实现后通过：`../uya/bin/uya test tests/test_std_thread.uya`，23 tests passed，0 failed。
      - 相关回归通过：`../uya/bin/uya test tests/test_async_compute_generic_wrapper.uya`，2 tests passed，0 failed。
      - 额外尝试：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya` 与 `../uya/bin/uya test tests/test_async_shared_runtime_semantics.uya` 均在宿主 C 链接阶段失败，关键错误为 `std/http/uyagin` 生成代码 `invalid initializer`，非本轮 `std.thread` 路径运行失败。
## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/async_scheduler.uya` 的 `TaskQueue<T>` 支持调用方配置容量，不再把默认 64 槽作为不可突破边界；最小验证：新增/更新队列容量测试并运行 `../uya/bin/uya test ...`。
    - 验证命令：`../uya/bin/uya test tests/test_std_async_scheduler.uya`
    - 验证结果：通过，`task_queue_with_capacity_limits_pushes` 和 `task_queue_capacity_can_exceed_default_capacity` 覆盖可配置容量及超过默认 64 槽场景；总计 16 tests passed。

## 完成定义

父级路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/async_event.uya` 的 epoll slot/event 容量改为动态或可配置，并避免 `find_slot()` 无界线性扫；最小验证：新增/更新事件循环 slot 容量测试并运行 `../uya/bin/uya test ...`。
    - 验证：`../uya/bin/uya test tests/test_std_async_event.uya` 通过（1 个测试通过）。
    - 相关回归：`../uya/bin/uya test tests/test_std_async_event_fd_reuse.uya` 通过（4 个子测试通过）。
    - 相关回归：`../uya/bin/uya test tests/test_std_async_scheduler.uya` 通过（16 个子测试通过）。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/async_scheduler.uya` 的 frame stack buffer 与 inline repoll 容量改为动态或可配置；最小验证：新增/更新 scheduler frame/repoll 测试并运行 `../uya/bin/uya test ...`。
    - 验证命令：`../uya/bin/uya test tests/test_std_async_scheduler.uya`
    - 结果：通过，17 tests / 0 failed，新增 `block_on_event_loop_inline_repoll_limit_is_configurable` 覆盖可配置 inline repoll。
    - 验证命令：`../uya/bin/uya test tests/test_async_frame_stack_limit_env.uya`
    - 结果：通过，1 test / 0 failed。
    - 验证命令：`../uya/bin/uya test tests/test_async_frame_stack_ok.uya`
    - 结果：通过，2 个测试项均 OK。

## 完成定义 / runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/async_frame.uya` 的 frame pool bucket、per-bucket 容量和 descriptor 表改为动态或可配置；最小验证：新增/更新 frame pool/descriptor 测试并运行 `../uya/bin/uya test ...`。
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya` 通过；5 个测试通过，覆盖显式 config、超过默认 128 buckets、超过默认 4096 per-bucket。
    - 验证：`../uya/bin/uya test tests/test_c99_async_frame_empty_descriptors.uya` 通过；空 descriptor 表路径通过。
    - 验证：`../uya/bin/uya --c99 tests/test_async_frame_pool_stats.uya -o /tmp/uya_async_frame_pool_stats.c && rg -n "_uya_async_frame_descriptor_entries\[|_uya_async_frame_descriptor_count|AsyncFrameDescriptorTable" /tmp/uya_async_frame_pool_stats.c` 通过；生成 `_uya_async_frame_descriptor_entries[6]` 和 `_uya_async_frame_descriptor_count = 6`，未固定为 512。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] `lib/std/thread.uya` 的线程池 worker、pending、task slot 容量改为动态或可配置策略，并移除固定容量导致的产品上限；最小验证：新增/更新 thread pool 容量测试并运行 `../uya/bin/uya test ...`。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya`，通过；24 tests passed，0 failed，93 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya`，通过；11 tests passed，0 failed，11 assertions passed。

## 完成定义

- [x] runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。
  - [x] 事件循环 epoll slot/event 容量支持实例级配置，并用非线性扫的 fd->slot 索引验证突破 `1024` 默认兼容容量。最小验证：`../uya/bin/uya test tests/test_std_async_event.uya`；完成条件：`linux_epoll_create_config(0, 1025, 1025)` 保留配置容量且 fd 查找不依赖全表线性扫。
    - 验证：`../uya/bin/uya test tests/test_std_async_event.uya` 通过（总计 1 个测试，通过 1，失败 0）。
    - 证据：`lib/std/async_event.uya` 已提供 `linux_epoll_create_config(flags, slot_capacity, event_capacity)`，按实例容量分配 slot/event buffer，并通过 fd 哈希表 `fd_keys/fd_slot_indices` 查找 slot；`tests/test_std_async_event.uya` 验证 `1025` 容量保留且 lookup 容量大于 slot 容量。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] 调度器 TaskQueue 和 inline repoll/frame buffer 使用动态分配或显式配置，默认值仅作兼容策略。最小验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya`。
    - 验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya` 通过，17/17 tests passed，167 assertions passed。
## 完成定义

父级任务路径：
- runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] AsyncFramePool bucket/per-bucket/descriptor 查询按运行时配置或生成表大小执行，不以 `128/4096/512` 作为硬上限。最小验证：`../uya/bin/uya test tests/test_async_frame_align_pool.uya tests/test_c99_async_frame_empty_descriptors.uya`。
    - 验证：`../uya/bin/uya test tests/test_async_frame_align_pool.uya tests/test_c99_async_frame_empty_descriptors.uya` 通过，5 个 test case、9 个测试计数、0 失败。
    - 相关回归：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya` 通过，5 个 test case、10 个测试计数、0 失败。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] ThreadPool worker/pending/task slot 容量支持显式配置和随 worker 扩展，旧 `32/32/16` 仅为兼容默认。最小验证：`../uya/bin/uya test tests/test_std_thread.uya`。
    - 验证命令：`../uya/bin/uya test tests/test_std_thread.uya`
    - 验证结果：通过；24 个测试全部 OK，Assertions Passed: 93。

## 2026-06-18 本轮完成

上下文：完成定义 > runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] 将 `lib/std/async_scheduler.uya` 的 `TaskQueue<T>` 默认队列改成自动增长，默认队列超过 `64` 个 ready 任务不再返回 `TaskQueueFull`；最小验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya`。
    - 验证：先运行 `../uya/bin/uya test tests/test_std_async_scheduler.uya`，旧实现新增用例 `task_queue_default_capacity_grows_past_64` 失败；实现后通过（18 tests）。
    - 回归：`../uya/bin/uya test tests/test_async_fd.uya` 通过（7 tests）。
    - 相关宽回归：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya` 未通过，宿主 C 编译在既有 `std_http_uyagin_send_context_response_head_only_async` / `std_http_uyagin_accept_async` 生成代码处报 `invalid initializer`，不在本次 `TaskQueue` 路径。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] 将 `lib/std/async_scheduler.uya` 的 `_frame_stack_buffer[8192]` 改成显式配置或动态后备存储策略；最小验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya`。
    - 验证命令：`../uya/bin/uya test tests/test_std_async_scheduler.uya`
    - 验证结果：通过，19 个测试通过，0 个失败。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] 将 `lib/std/async_frame.uya` 的 bucket / slot / descriptor 上限改成动态结构；最小验证：`../uya/bin/uya test tests/test_async_frame_pool_dynamic_growth.uya`。
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_dynamic_growth.uya` 通过。
    - 相关验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya`、`../uya/bin/uya test tests/test_async_frame_pool_negative.uya`、`../uya/bin/uya test tests/test_async_frame_align_pool.uya` 均通过。

## 完成定义

父级任务路径：runtime 的队列、slot、descriptor、frame pool、线程池容量为动态或可配置策略，而不是 `16/32/64/512/1024` 这种常量边界。

  - [x] 将 `lib/std/thread.uya` 的 worker / pending / task slot 数量改成动态或可配置，并去掉默认 `fork()` fallback；最小验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya`。
    - 验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya` 通过（1/1 tests，26 assertions）。
    - 相关验证：`../uya/bin/uya test tests/test_std_thread.uya` 通过（24/24 tests，93 assertions）。

## 完成定义

- [x] 协议层临时 buffer 不再把“4 KiB 头”“单次 4 KiB frame”之类当成默认产品上限。
  - 验证：`../uya/bin/uya test tests/test_http1_async_client.uya` 通过（8 tests passed，包含请求头超过 4 KiB 与响应头超过旧 8 KiB 回归）。
  - 验证：`../uya/bin/uya --c99 tests/test_http1_async_client.uya` 通过，生成 `a.out`。
  - 验证：`./a.out` 通过（8 tests passed）。

## 完成定义

父级任务路径：有一套从单测、`--uya --c99` 回归、长压测到 `make backup-all` 的完整闸门。

  - [x] 新增可执行的 async 生产化完整闸门脚本，串联单测、`--uya --c99` 回归、长压测和 `make backup-all`；最小验证：`bash -n tests/verify_async_full_dynamic_resources_gate.sh`。
    验证命令：`bash -n tests/verify_async_full_dynamic_resources_gate.sh`
    验证结果：通过。
    验证命令：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
    验证结果：通过，报告 `ok: docs/todo_async_full_language_dynamic_resources.md has 1 active task`。

## 完成定义

- 父级任务路径：有一套从单测、`--uya --c99` 回归、长压测到 `make backup-all` 的完整闸门：
  - [x] 将 async 动态资源相关单测和无固定容量扫描纳入闸门脚本，并验证聚焦子集可运行；最小验证：运行脚本的单测/扫描阶段。
    - 验证命令：`bash tests/verify_async_full_dynamic_resources_gate.sh unit-scan`
    - 验证结果：通过；运行 async await/param 动态容量、frame pool/thread pool 动态增长、async event config、multi fd concurrency 单测，以及 `verify_async_compiler_no_fixed_limits.py` 扫描。

## 完成定义

父级任务路径：
- [ ] 有一套从单测、`--uya --c99` 回归、长压测到 `make backup-all` 的完整闸门：
  - [x] 将 async C99 回归和长压测纳入闸门脚本，并验证对应阶段可运行；最小验证：运行脚本的 C99/stress 阶段。
    验证命令：`ASYNC_GATE_STRESS_PTHREAD_ITERATIONS=1 ASYNC_GATE_STRESS_EPOLL_ITERATIONS=1 ASYNC_GATE_STRESS_HTTP_DURATION_SEC=2 ASYNC_GATE_STRESS_HTTP_SAMPLE_INTERVAL_SEC=1 bash tests/verify_async_full_dynamic_resources_gate.sh c99-stress`
    验证结果：通过；覆盖 async C99 frame descriptors、empty frame descriptors、nested split-C codegen、http async epoll C99 compile/runtime verify、pthread stress、epoll server stress、http async epoll runtime stress。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] 局部变量声明 / 赋值 / 提前 return
    - 证据：`docs/grammar_formal.md` 的 `statement` 包含 `var_decl`、`expr_stmt`、`return_stmt`；`docs/uya.md` 第 3 章和 5.1 说明局部 `const`/`var`、赋值与 `return` 语义。
    - async 状态：已有覆盖；`tests/test_async_control_flow_body.uya` 覆盖 async 函数体内 `const`/`var` 声明、赋值、入口提前 return 和尾部 return；`tests/test_async_await_var.uya` 覆盖 await 结果绑定后返回。
    - 验证：`../uya/bin/uya test tests/test_async_control_flow_body.uya` 通过，3 tests passed / 0 failed。
    - 验证：`../uya/bin/uya test tests/test_async_await_var.uya` 通过，1 test passed / 0 failed。
## 追加完成记录：Phase 1 / 1.1 / `if / else if / else`

父级任务路径：Phase 1：`@async_fn` 语法完整性 > 1.1 先建立“完整语法”矩阵 > 以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] `if / else if / else`
    - 规范依据：`docs/uya.md` 明确 `if condition { statements } [ else { statements } ]`，并支持 `else if`；`docs/grammar_formal.md` 将 `if_stmt` 列入函数体 `statement`。
    - async 状态：已有覆盖。`tests/test_async_if_await.uya` 覆盖 `if/else` 两分支内 `try @await`；`tests/test_async_else_if_await.uya` 覆盖 `else if` 作为 AST_IF_STMT else 分支、分支内循环 await、以及分支后续执行；`tests/test_async_sync_body_matrix.uya` 还用同步/async 成对断言覆盖普通分支和 `else if`。
    - 验证命令：`../uya/bin/uya test tests/test_async_if_await.uya`，结果：通过，2 个测试通过、0 失败。
    - 验证命令：`../uya/bin/uya test tests/test_async_else_if_await.uya`，结果：通过，1 个测试通过、0 失败。
    - 扩展验证命令：`./tests/verify_async_full_language_matrix.sh`，结果：L65 相关的 `tests/test_async_if_await.uya` 与 `tests/test_async_else_if_await.uya` 均已在脚本中通过；脚本后续在 shared runtime 阶段失败，关键错误为生成 C 中 `std_http_uyagin_send_context_response_head_only_async(...)` / `std_http_uyagin_accept_async(...)` 的 `invalid initializer`，与本轮 `if / else if / else` 语法证据无关。

## Phase 1：`@async_fn` 语法完整性
### 1.1 先建立“完整语法”矩阵
父级任务路径：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：
  - [x] `while`
    - 状态：已验证覆盖。
    - 依据：`docs/grammar_formal.md` 将 `while_stmt = 'while' expr '{' statements '}'` 列为函数体 `statement`；`docs/uya.md` 说明 `while condition { statements }`，且 `break` / `continue` 适用于 `while`。
    - 现有覆盖：`tests/test_async_while_multi_await.uya` 覆盖 while 内连续 `@await`；`tests/test_async_bug_a_two_while.uya` 覆盖两个连续 while+await；`tests/test_async_bug_b_sync_between.uya` 覆盖 while+await 后同步代码再进入后续 await 循环；`tests/test_async_bug_d_nested_block.uya` 覆盖 await 后 `break` / `continue`。
    - 验证命令：
      - `../uya/bin/uya test tests/test_async_while_multi_await.uya`：通过，2 tests passed，0 failed。
      - `../uya/bin/uya test tests/test_async_bug_a_two_while.uya`：通过，1 test passed，0 failed。
      - `../uya/bin/uya test tests/test_async_bug_b_sync_between.uya`：通过，1 test passed，0 failed。
      - `../uya/bin/uya test tests/test_async_bug_d_nested_block.uya`：通过，2 tests passed，0 failed。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] `for range`
    - 验证：`../uya/bin/uya test tests/test_async_for_await.uya`，通过；4 个测试全部 OK，包含 `async_for_range_with_await`。
    - 验证：`../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya`，通过；7 个测试全部 OK，包含 `async_for_range_with_await_3`。
    - 结果：已在当前语法覆盖快照中单独登记 `for range` + `@await`，依据 `docs/grammar_formal.md` 的 `for range` 语法和 `docs/uya.md` 第 8 章整数范围形式。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] `for` 定长数组值迭代
    - 验证：`../uya/bin/uya test tests/test_async_for_await.uya`
    - 结果：通过；4 个测试全部 OK，包含 `async_for_array_with_await`，覆盖 `@async_fn` 中 `for a |e|` 定长数组值迭代跨 `try @await` 后累加返回。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务路径：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] `for` 定长数组引用迭代 `|&x|`
    - 证据：`docs/uya.md` 第 8 章列出 `for obj |&v| {}` 形式；`tests/test_async_for_await.uya` 中 `mutate_array_for_ref_with_await()` 使用 `@async_fn`、定长数组 `var a: [i32: 3]`、`for a |&item|`、循环体内 `try @await ready_7()`，并通过 `*item` 写回数组后校验结果 54。
    - 验证命令：`../uya/bin/uya test tests/test_async_for_await.uya`
    - 验证结果：通过；4 个测试全部 OK，包含 `async_for_array_ref_with_await`。
    - 验证命令：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya`
    - 验证结果：通过；4 个测试全部 OK，20 个断言通过。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务路径：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] 迭代器形式 `for obj |v|`
    - 验证命令：`../uya/bin/uya test tests/test_async_for_await.uya`
      - 结果：通过；`async_for_iterator_with_await` 覆盖具体 struct 迭代器 `for iter |v|` + `try @await`，同文件同时覆盖 range、数组值迭代和数组引用迭代。
    - 验证命令：`../uya/bin/uya test tests/test_async_for_iterator_ref_await.uya`
      - 结果：通过；覆盖迭代器引用绑定 `for iter |&item|` + `try @await`。
    - 更广验证：`bash tests/verify_async_full_language_matrix.sh`
      - 结果：目标相关 async for 用例已执行通过；脚本后段 `verify_async_shared_runtime_matrix` 在 `tests/test_async_shared_runtime_semantics.uya` 的宿主 C 编译阶段失败，关键错误为 `/tmp/uya_output_2811915.c` 中 `std_http_uyagin_send_context_response_head_only_async` / `std_http_uyagin_accept_async` 生成 `invalid initializer`，与本轮迭代器语法覆盖无直接关系。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务路径：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] `match`
    - 验证命令：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya`
    - 验证结果：通过；4 个测试、20 个断言通过，覆盖同步/async 成对 `match` 表达式语义。
    - 扩展验证命令：`./tests/verify_async_full_language_matrix.sh`
    - 扩展验证结果：非阻塞失败；脚本已跑过 `tests/test_async_sync_body_matrix.uya`，后续在 `verify_async_shared_runtime_matrix` 生成 C99 链接阶段失败，关键错误为 `invalid initializer`，涉及 `std_http_uyagin_send_context_response_head_only_async` 与 `std_http_uyagin_accept_async`，不属于本轮 `match` 专项路径。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] `try / catch`
    - 规范依据：`docs/grammar_formal.md` 将 `try` 作为 `unary_expr` 前缀，将 `catch` 作为 `postfix_expr` 的 `catch_op`；`docs/uya.md` 第 11 章说明 `try` 错误传播和 `catch` 错误恢复语义。
    - async 覆盖证据：`tests/test_async_catch_await.uya` 覆盖 `try @await` 成功路径、await 后错误联合再 `catch`、catch 块内 `@await`、catch 后继续执行、多 catch 和 catch 内提前 return；`tests/test_async_sync_body_matrix.uya` 覆盖 async 函数体与同步函数体的 catch 恢复一致性。
    - 验证：`../uya/bin/uya test tests/test_async_catch_await.uya` 通过，10 tests passed, 0 failed。
    - 验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya` 通过，4 tests passed, 0 failed。
    - 扩展验证：`bash tests/verify_async_full_language_matrix.sh` 已跑过 async 基线正向测试、禁止 await 位置检查、容量和 nested future 部分；在 `verify_async_shared_runtime_matrix` 阶段失败，关键错误为 `/tmp/uya_output_2841532.c:51021:51: error: invalid initializer` 与 `/tmp/uya_output_2841532.c:51801:63: error: invalid initializer`，涉及 `std_http_uyagin_*_async` 共享 runtime 生成 C，不属于本轮 `try / catch` 语法覆盖本身。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] `defer / errdefer`
    - 状态：已验证覆盖。`docs/grammar_formal.md` 将 `defer_stmt` / `errdefer_stmt` 列入函数体 `statement`，`docs/uya.md` 第 9 章规定 success/error 清理顺序和块内禁止 `return` / `break` / `continue`；当前 async 矩阵已有 `async 体内 defer / errdefer` 行，证据为 `tests/test_async_sync_body_matrix.uya`。
    - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya` 通过，8 tests / 14 assertions。
    - 验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya` 通过，4 tests / 20 assertions。
    - 验证：`../uya/bin/uya check tests/error_async_defer_return.uya` 按预期失败并输出 `defer/errdefer 块中不能使用 return 语句`。
    - 验证：`../uya/bin/uya check tests/error_async_errdefer_break.uya` 按预期失败并输出 `defer/errdefer 块中不能使用 break 语句`。
    - 验证：`../uya/bin/uya check tests/error_async_defer_continue_nested.uya` 按预期失败并输出 `defer/errdefer 块中不能使用 continue 语句`。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务路径：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] 复合表达式
    - 验证命令：
      - `../uya/bin/uya test tests/test_async_compound_try_await.uya`：通过，2 tests / 4 assertions。
      - `../uya/bin/uya test tests/test_async_fn_multi_segment_unwrap.uya`：通过，1 test / 1 assertion。
      - `../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`：通过，3 tests / 4 assertions。
      - `../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya`：通过，7 tests / 7 assertions。
    - 结论：`tests/test_async_compound_try_await.uya`、`tests/test_async_fn_multi_segment_unwrap.uya`、`tests/test_async_await_limits_and_segments.uya`、`tests/test_async_large_state_machine_syntax.uya` 已覆盖 async RHS/return 复合表达式、`try @await` 跨 poll/resume 重放、多段 bind 依赖、副作用保持和表达式链大状态机语法回归；与主 todo 的“复合表达式 / await 绑定跨段重放 / 大状态机”矩阵证据一致。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级路径：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] 宏展开后的 expr / stmt
    - 完成说明：当前矩阵已有 `宏展开后的 expr / stmt 进入 async lowering` 证据行，固定证据为 `tests/test_async_macro_expand.uya` 与 `tests/programs/test_ai_prompt_async_macro_combo.uya`。专项测试覆盖 expr 宏展开为块表达式后，pre-await 求值在 poll/resume 间不丢失且不重复；程序级 macro combo 覆盖宏展开表达式进入 `@async_fn` build/run 主链路。
    - 验证命令：`../uya/bin/uya test tests/test_async_macro_expand.uya`
    - 验证结果：通过，1 个测试通过，4 个断言通过。
    - 验证命令：`../uya/bin/uya run tests/programs/test_ai_prompt_async_macro_combo.uya`
    - 验证结果：通过，输出 `加法异步结果 50` / `除法异步结果 5`。
    - 更广验证命令：`bash tests/verify_async_full_language_matrix.sh`
    - 更广验证结果：脚本已通过本轮相关的 positive matrix 阶段，包括 `tests/test_async_macro_expand.uya`；随后在 `verify_async_shared_runtime_matrix` 的 `tests/test_async_shared_runtime_semantics.uya` 宿主 C 编译阶段失败，关键错误为 `/tmp/uya_output_2883756.c:51021:51: error: invalid initializer` 与 `/tmp/uya_output_2883756.c:51801:63: error: invalid initializer`，涉及 `std_http_uyagin_send_context_response_head_only_async(...)` / `std_http_uyagin_accept_async(...)`，与本轮宏展开 expr/stmt async lowering 证据无关。

## Phase 1：`@async_fn` 语法完整性

### 1.1 先建立“完整语法”矩阵

父级任务路径：以 `docs/uya.md` 和 `docs/grammar_formal.md` 为准，列出函数体语法项，并逐项标记 async 状态：

  - [x] 泛型函数 / 泛型方法 / 接口方法 / 结构体外方法块
    - 验证：`../uya/bin/uya test tests/test_async_fn_basic.uya` 通过，覆盖基础泛型 `@async_fn` poll-ready 路径。
    - 验证：`../uya/bin/uya test tests/test_generic_async_function_codegen.uya` 通过，覆盖顶层泛型 `@async_fn` codegen。
    - 验证：`../uya/bin/uya test tests/test_async_method_interface.uya` 通过，覆盖接口方法签名、结构体内部 async 方法、结构体外方法块 async 实现与 vtable 调用。
    - 缺口确认：临时正向回归 `AsyncBox { @async_fn fn choose<T>(...) Future<!T> }` 失败于 C99 链接阶段，关键错误为未生成 `uya_AsyncBox_choose_i32` 且 `struct uya_interface_Future_err_i32` 在 `std_block_on_i32` 处不完整；未保留失败测试文件，矩阵中如实标为“部分覆盖，泛型 async 方法仍为缺口”。

## 归档：Phase 1 / 1.2 先补红测，再动实现

父级任务路径：# Uya 异步生产化 TODO（完整语法 + 动态资源） > Phase 1：`@async_fn` 语法完整性 > 1.2 先补红测，再动实现

- [x] 新增 `tests/test_async_match_await.uya`
  - 验证：`../uya/bin/uya test tests/test_async_match_await.uya` 通过；4 tests passed, 0 failed, 4 assertions passed。
  - 验证：`../uya/bin/uya test --c99 tests/test_async_match_await.uya` 通过；4 tests passed, 0 failed, 4 assertions passed。
  - 验证：`../uya/bin/uya test --uya --c99 tests/test_async_match_await.uya` 通过；4 tests passed, 0 failed, 4 assertions passed。

## 2026-06-18 本轮完成：Phase 1 / 1.2

上下文：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` / `Phase 1：@async_fn 语法完整性` / `1.2 先补红测，再动实现`

- [x] 新增 `tests/test_async_catch_await.uya`
  - 说明：目标测试文件已存在并已纳入 `tests/verify_async_full_language_matrix.sh`；本轮确认其作为 dedicated async catch + await 正向回归，覆盖 `try @await` 成功路径、await 后错误联合 `catch`、catch 体内 `@await`、catch 后继续执行、多 catch 和 catch 内提前 return。
  - 验证命令：`../uya/bin/uya test tests/test_async_catch_await.uya` → 10 tests passed, 0 failed; 10 assertions passed。
  - 验证命令：`../uya/bin/uya test tests/test_async_catch_await.uya --c99` → 10 tests passed, 0 failed; 10 assertions passed。
  - 验证命令：`../uya/bin/uya test tests/test_async_catch_await.uya --uya --c99` → 10 tests passed, 0 failed; 10 assertions passed。

### 归档：Phase 1 / 1.2 先补红测，再动实现

- [x] 新增 `tests/test_async_defer_errdefer.uya`
  - 说明：目标测试文件已存在，覆盖 @async_fn 体内 defer / errdefer、跨多段 @await 的 defer LIFO、同步错误触发 errdefer、以及 `try @await` 错误传播触发 errdefer。
  - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya` 通过，8 tests passed, 0 failed, 14 assertions passed。
  - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya --c99` 通过，8 tests passed, 0 failed, 14 assertions passed。
  - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya --uya --c99` 通过，8 tests passed, 0 failed, 14 assertions passed。

### 归档上下文：Phase 1：`@async_fn` 语法完整性 / 1.2 先补红测，再动实现

- [x] 如有必要，从 `tests/test_async_for_await.uya` 拆出 dedicated `for iter |v|` + `@await` 回归；当前主回归已覆盖该组合。
  - 结论：无需拆出 dedicated 回归；`tests/test_async_for_await.uya` 已包含 `sum_iterator_for_with_await()` 和 `async_for_iterator_with_await`，覆盖具体 struct 迭代器 `for iter |v|` 循环体内 `try @await ready_7()` 后累加返回。
  - 验证命令：`../uya/bin/uya test tests/test_async_for_await.uya`
  - 验证结果：通过；4 个测试全部 OK，包含 `async_for_iterator_with_await`。

## 归档：Phase 1 / 1.2 先补红测，再动实现

- [x] 如有必要，从 `tests/test_async_for_await.uya` 拆出 dedicated `for arr |&x|` + `@await` 回归；当前主回归已覆盖该组合。
  - 结论：无需拆出新 dedicated 文件；`tests/test_async_for_await.uya` 已包含独立测试 `async_for_array_ref_with_await`，覆盖 `for a |&item|` 循环体内 `try @await ready_7()`、引用写回 `*item` 和结果断言。
  - 验证：`../uya/bin/uya test tests/test_async_for_await.uya` 通过，4 tests / 4 assertions passed。
  - 验证：`../uya/bin/uya test tests/test_async_for_await.uya --c99` 通过，4 tests / 4 assertions passed。
  - 说明：`./tests/run_programs_parallel.sh --uya --c99 test_async_for_await.uya` 曾通过，但脚本固定使用 `$REPO_ROOT/bin/uya`，不满足本轮 `../uya/bin/uya` 硬约束，未计入有效验证。

## Phase 1：`@async_fn` 语法完整性

### 1.2 先补红测，再动实现

- [x] 维护 `tests/test_async_macro_expand.uya` 与程序级 `tests/programs/test_ai_prompt_async_macro_combo.uya` 作为宏展开 async lowering 的固定证据。
  - 验证命令：`../uya/bin/uya test tests/test_async_macro_expand.uya`
  - 结果：通过；`async_expr_macro_block_keeps_preawait_eval_once` 通过，1 个测试通过、0 个失败、4 个断言通过。
  - 验证命令：`../uya/bin/uya run tests/programs/test_ai_prompt_async_macro_combo.uya`
  - 结果：通过；程序输出 `加法异步结果 50`、`除法异步结果 5`，退出码 0。

## 归档：失败项修复完成

上下文：`docs/todo_async_full_language_dynamic_resources_failed.md`

- [x] 建立 async 函数体错误处理覆盖测试。
  - 修复记录：新增 `tests/test_async_error_body_matrix.uya`，用同步函数和 `@async_fn` 成对覆盖正常返回、`try` 传播、`@await` 后 `!T` + `catch` 恢复、await 后直接 `return error`、入口直接 `return error`。
  - 验证：`./bin/uya test tests/test_async_error_body_matrix.uya` 通过，5 个测试用例通过。

- [x] 修复完整闸门中 C99 async `try @await` / async call 错误联合拆箱路径，并完成从单测、`--uya --c99` 回归、长压测到 `make backup-all` 的完整闸门。
  - 修复记录：C99 async 状态机在 inline child / vtable 预发射后恢复 await collection 快照，避免首段 await arm 丢失；按语句源位置和 `try @await` operand 回绑 await 分裂点，避免把 `Future<!T>` 直接初始化成 `err_union_T`；补齐 async hoisted builtin 字符串初始化的 `uint8_t *` cast。
  - 聚焦验证：`bash tests/verify_c99_struct_array_and_typed_route_regressions.sh` 通过。
  - 聚焦验证：`./bin/uya test tests/test_async_compound_try_await.uya` 通过。
  - 聚焦验证：`./bin/uya test tests/test_async_builtin_body_coverage.uya` 通过。
  - 备份验证：`bash tests/verify_async_full_dynamic_resources_gate.sh backup-all` 通过，并刷新 `backup/uyacache`、`backup/uya.c`、`backup/uya-linux-x86_64.c`、`backup/uya-hosted.c`、`backup/uya-hosted-linux-x86_64.c`。
  - 完整验证：`bash tests/verify_async_full_dynamic_resources_gate.sh` 通过，输出 `verify_async_full_dynamic_resources_gate: all stages passed`。
  - 长压测结果：`tests/stress_pthread.sh 100` 通过；`tests/stress_epoll_server.sh 100` 通过；`tests/stress_http_async_epoll.sh 1800 1` 通过，`wrk` 退出码 0，742366957 requests，RSS 4816/4968/4968 KB，FD 159/159/159。

## Phase 1：`@async_fn` 语法完整性

### 1.2 先补红测，再动实现

父级任务路径：
- [ ] 所有新测试都要同时覆盖：
  - [x] native 路线
    - 实现：`tests/verify_async_full_language_matrix.sh` 新增显式 `native` 模式，把原生 `uya test` / `uya run` 子集收口成单独入口，默认 `all` 行为保持不变。
    - 验证命令：`bash -n tests/verify_async_full_language_matrix.sh`
    - 结果：通过。
    - 验证命令：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh native`
    - 结果：通过；顺序跑完 baseline async 语法矩阵、禁止位置 checker 失败、`tests/test_async_for_iterator_ref_await.uya` 和 `tests/programs/test_ai_prompt_async_macro_combo.uya`，输出 `verify_async_full_language_matrix: native stages passed`。
### Phase 1：`@async_fn` 语法完整性
#### 1.2 先补红测，再动实现
父级任务路径：
- [ ] 所有新测试都要同时覆盖：
  - [x] `--c99`
    - 红测：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh c99`（改动前退出码 2，输出 `usage: tests/verify_async_full_language_matrix.sh [all|native]`）
    - 验证：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh c99` 通过；C99 baseline、负向诊断、macro combo、await capacity、nested future boundary、shared runtime matrix 全部通过。
    - 回归：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh native` 通过；原 native baseline 入口未回归。

## Phase 1：`@async_fn` 语法完整性
### 1.2 先补红测，再动实现

- [x] 所有新测试都要同时覆盖：
  - [x] `--uya --c99`
    - 红测：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh uya-c99`
    - 红测结果：改动前退出码 2，输出 `usage: tests/verify_async_full_language_matrix.sh [all|native|c99]`。
    - 变更：`tests/verify_async_full_language_matrix.sh` 新增 `uya-c99` 模式并让默认 `all` 纳入该路径；`tests/verify_async_await_capacity.sh`、`tests/verify_async_nested_future_boundary.sh`、`tests/verify_async_shared_runtime_matrix.sh` 新增可透传 `--uya` 的驱动参数。
    - 验证：`bash -n tests/verify_async_full_language_matrix.sh tests/verify_async_await_capacity.sh tests/verify_async_nested_future_boundary.sh tests/verify_async_shared_runtime_matrix.sh`
    - 验证结果：通过。
    - 验证：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
    - 验证结果：通过，输出 `ok: docs/todo_async_full_language_dynamic_resources.md has 1 active task`。
    - 验证：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh uya-c99`
    - 验证结果：通过，输出 `verify_async_full_language_matrix: --uya --c99 baseline, iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed`。
    - 回归：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh c99`
    - 回归结果：通过，输出 `verify_async_full_language_matrix: C99 baseline, iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed`。

## Phase 1：`@async_fn` 语法完整性
### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”

- [x] 以 `src/lower/async.uya` 为中心，建立单一 async lowering 计划结构，而不是让 `src/codegen/c99/function.uya` 和 `src/codegen/c99/async_transform.uya` 各自再做一轮语义猜测。
  - 完成内容：`src/lower/async.uya` 新增 `AsyncLowerPlan` / `AsyncLowerAwaitPoint` 与统一 `async_lower_build_plan`、`async_lower_stmt_contains_await`、`async_lower_find_first_try_await_expr`；`src/codegen/c99/function.uya` 改为先构建 lowered plan 再拷贝给 emitter 所需数组；`src/codegen/c99/async_transform.uya` 收敛为调用 lowering 的兼容薄层。
  - 验证：`python3 tests/verify_async_lowering_plan_architecture.py`
  - 结果：通过，输出 `verify_async_lowering_plan_architecture: centralized async lowering plan confirmed`。
  - 验证：`../uya/bin/uya test tests/test_async_compound_try_await.uya`
  - 结果：通过，2 tests passed，4 assertions passed。
  - 验证：`../uya/bin/uya test tests/test_async_cleanup_body_coverage.uya`
  - 结果：通过，2 tests passed，5 assertions passed。
  - 验证：`../uya/bin/uya test tests/test_async_match_body_coverage.uya`
  - 结果：通过，3 tests passed，3 assertions passed。
  - 验证：`../uya/bin/uya test tests/test_async_control_flow_body.uya`
  - 结果：通过，3 tests passed，6 assertions passed。
  - 验证：`../uya/bin/uya test tests/test_async_decl_expr_coverage.uya`
  - 结果：通过，1 test passed，2 assertions passed。
  - 验证：`git diff --check`
  - 结果：通过，无输出。

## 2026-06-20

### Phase 1：`@async_fn` 语法完整性
### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”
路径上下文：
- [ ] 让 C99 emitter 只消费 lowered async plan，不再自己重新推断：
  - [x] await split 点
    - 验证：`python3 tests/verify_async_lowering_plan_architecture.py` -> 通过（确认 lowered plan 持有 `source_stmt` / `split_try_expr`，且 `emit_async_segment` / `emit_async_continuation` 不再直接调用 `async_lower_find_first_try_await_expr`）
    - 验证：`ulimit -s 32768 && UYA_MULTI_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR= RUNTIME_MODE=nostdlib LINK_MODE=static src/compile.sh --compiler ../uya/bin/uya --c99 -e --nostdlib --safety-proof` -> 成功，已重建 `bin/uya`
    - 验证：`../uya/bin/uya test tests/test_async_compound_try_await.uya` -> 通过（2 tests passed）
    - 验证：`../uya/bin/uya test tests/test_async_match_await.uya` -> 通过（4 tests passed）
    - 验证：`../uya/bin/uya test tests/test_async_multiple_await.uya` -> 通过（1 test passed）
    - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya` -> 通过（8 tests passed）
  - [x] state 编号
    - 完成内容：`src/lower/async.uya` 为每个 await 点生成 `resume_state`，并为整份 plan 生成 `terminal_state`；`src/codegen/c99/function.uya` / `internal.uya` 改为只消费这些编号，不再使用 `await_index + 1`、`await_count + 1` 或 `async_collect_count + 1` 自行推断。
    - 验证：`python3 tests/verify_async_lowering_plan_architecture.py`
    - 结果：通过，输出 `verify_async_lowering_plan_architecture: centralized async lowering plan confirmed`。
    - 验证：`ulimit -s 32768 && UYA_MULTI_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR= RUNTIME_MODE=nostdlib LINK_MODE=static src/compile.sh --compiler ../uya/bin/uya --c99 -e --nostdlib --safety-proof`
    - 结果：通过，已重建 `bin/uya`。
    - 验证：`../uya/bin/uya test tests/test_async_bug_a_two_while.uya`
    - 结果：通过，1 test passed，1 assertion passed。
    - 验证：`../uya/bin/uya test tests/test_async_multiple_await.uya`
    - 结果：通过，1 test passed，1 assertion passed。
    - 验证：`../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya`
    - 结果：通过，7 tests passed，7 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_control_flow_body.uya`
    - 结果：通过，3 tests passed，6 assertions passed。
    - 验证：`git diff --check`
    - 结果：通过，无输出。

## 2026-06-21

### Phase 1：`@async_fn` 语法完整性
### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”
路径上下文：
- [ ] 让 C99 emitter 只消费 lowered async plan，不再自己重新推断：
  - [x] resume 入口
    - 完成内容：`src/lower/async.uya` 为 lowered plan 增加 `prefix_stmt_count`，在首次收集到 await 时记录其所属函数体顶层语句下标；`src/codegen/c99/function.uya` 改为直接消费 `async_plan.prefix_stmt_count` 切 state 0 前缀，并删除旧的首 await 顶层扫描 helper。
    - 验证：`python3 tests/verify_async_lowering_plan_architecture.py`
    - 结果：通过，输出 `verify_async_lowering_plan_architecture: centralized async lowering plan confirmed`。
    - 验证：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`
    - 结果：通过，3 tests passed，4 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_if_await.uya`
    - 结果：通过，2 tests passed，2 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_bug_d_nested_block.uya`
    - 结果：通过，2 tests passed，4 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_else_if_await.uya`
    - 结果：通过，1 test passed，3 assertions passed。
    - 验证：`git diff --check`
    - 结果：通过，无输出。

### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”

父级任务：让 C99 emitter 只消费 lowered async plan，不再自己重新推断

  - [x] cleanup 区域
    - 验证：`make uya`
    - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya`（9 tests passed, 16 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_cleanup_body_coverage.uya`（2 tests passed, 5 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya`（4 tests passed, 20 assertions）
    - 验证：`git diff --check`（无输出）
## 2026-06-21

### Phase 1：`@async_fn` 语法完整性
### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”
路径上下文：
- [x] 让 C99 emitter 只消费 lowered async plan，不再自己重新推断：
  - [x] break / continue / return / error 路径
    - 完成内容：`src/lower/async.uya` 的 lowered plan 新增 `return_stmt`，`src/codegen/c99/internal.uya` 新增 `async_collect_ret_stmt`，`src/codegen/c99/function.uya` 改为直接消费 plan 的 return/source metadata 处理 terminal return、direct return await、split return replay 与统一 split 点判定，`src/codegen/c99/stmt.uya` 的 async `break` 改为使用 `c99_async_terminal_state(codegen)`，不再写死 `async_collect_count + 1`。
    - 完成内容：`tests/verify_async_lowering_plan_architecture.py` 扩展为锁定 `return_stmt` / `async_collect_ret_stmt`、禁止 `c99_var_decl_init_is_await_bind` / `c99_return_stmt_is_await_bind` / `c99_return_stmt_has_nested_try_await` 以及 `stmt.uya` 中的 `async_collect_count + 1`。
    - 验证：`python3 tests/verify_async_lowering_plan_architecture.py`
    - 结果：通过，输出 `verify_async_lowering_plan_architecture: centralized async lowering plan confirmed`。
    - 验证：`../uya/bin/uya test tests/test_async_control_flow_body.uya`
    - 结果：通过，3 tests passed，6 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_error_body_matrix.uya`
    - 结果：通过，5 tests passed，5 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_return_error_direct.uya`
    - 结果：通过，2 tests passed，6 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_bug_d_nested_block.uya`
    - 结果：通过，2 tests passed，4 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_compound_try_await.uya`
    - 结果：通过，2 tests passed，4 assertions passed。
    - 验证：`../uya/bin/uya test tests/test_async_bug_c_tail_await.uya`
    - 结果：通过，1 test passed，1 assertion passed。
    - 验证：`../uya/bin/uya test tests/test_async_catch_await.uya`
    - 结果：通过，10 tests passed，10 assertions passed。
    - 验证：`git diff --check`
    - 结果：通过，无输出。

## Phase 1：`@async_fn` 语法完整性
### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”
- [x] 对 `defer / errdefer` 建立显式 cleanup 区域模型，保证跨 await 与提前返回语义一致。
  验证：`make uya`
  结果：通过，已重建 `bin/uya` 自举编译器。
  验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya`
  结果：通过，10 个测试全部通过，18 条断言通过。
  验证：`../uya/bin/uya test tests/test_async_match_await.uya`
  结果：通过，4 个测试全部通过。
### Phase 1：`@async_fn` 语法完整性

#### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”

- [x] 对 `match / catch / 宏展开后 AST` 走统一 traversal，不再靠个别形状特判。
  验证：
  - `make uya`：通过
  - `../uya/bin/uya test tests/test_async_compound_await_traversal.uya`：通过（4 tests passed, 0 failed）
  - `../uya/bin/uya test tests/test_async_match_await.uya`：通过（4 tests passed, 0 failed）
  - `../uya/bin/uya test tests/test_async_defer_errdefer.uya`：通过（10 tests passed, 0 failed）
  - `../uya/bin/uya test tests/test_async_macro_expand.uya`：通过（1 test passed, 0 failed）
  - `./tests/run_programs_parallel.sh --uya --c99 test_async_iterator_for_await.uya`：失败（仓库内不存在该文件）
  - `./tests/run_programs_parallel.sh --uya --c99 tests/test_async_for_iterator_ref_await.uya`：通过
  - `./tests/run_programs_parallel.sh --uya --c99 tests/test_async_for_await.uya`：通过

### 1.3 把 async lowering 从“特判发射”改成“统一 lowered plan”

- [x] 把当前 `fprintf(stderr, "...尚未支持")` 这类 emitter 临时提示，改成 checker 或 lowering 阶段的正式诊断；对于应该支持的语法，最终要彻底移除这类分支。
  验证：
  - `../uya/bin/uya check tests/error_async_await_in_while_cond.uya`：命中 `@await 不能出现在 while 条件表达式中；请先 await 再进入循环`
  - `../uya/bin/uya check tests/error_async_await_in_for_range_start.uya`：命中 `@await 不能出现在 for range 起始表达式中；请先 await 再进入循环`
  - `../uya/bin/uya check tests/error_async_await_in_for_range_end.uya`：命中 `@await 不能出现在 for range 结束表达式中；请先 await 再进入循环`
  - `../uya/bin/uya check tests/error_async_await_in_return.uya`：命中 `@await 不能出现在 return 之后的不可达代码中`
  - `../uya/bin/uya test tests/test_async_match_await.uya`：通过
  - `../uya/bin/uya test tests/test_async_defer_errdefer.uya`：通过
  - `UYA_COMPILER=/media/winger/_dde_data/winger/uya/uya/bin/uya ./tests/run_programs_parallel.sh --uya --c99 tests/test_async_for_await.uya`：通过
  - `UYA_COMPILER=/media/winger/_dde_data/winger/uya/uya/bin/uya ./tests/run_programs_parallel.sh --uya --c99 tests/test_async_for_iterator_ref_await.uya`：通过
  - `UYA_COMPILER=/media/winger/_dde_data/winger/uya/uya/bin/uya ./tests/verify_async_full_language_matrix.sh`：失败，卡在既有 `tests/test_async_await_parse.uya` C99 代码生成错误（`Future_i32`/`Poll_Future_i32` 类型不兼容），与本轮 checker 诊断改动无直接关联。

# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1：`@async_fn` 语法完整性
### 1.4 收口语法口径

- [x] 为仍然非法的语法保留明确、稳定、可测试的诊断。
  - 变更：在 checker 前置拒绝 `defer` / `errdefer` 中的 `@await`，新增两条负例，并把 `tests/test_async_match_await.uya` 纳入 async 语言矩阵基线。
  - 验证：`make uya`（成功，已重建本地 `bin/uya`）
  - 验证：`../uya/bin/uya check tests/error_async_await_in_defer.uya`（按预期失败，命中 `@await 不能出现在 defer/errdefer 块中；清理逻辑必须保持同步`）
  - 验证：`../uya/bin/uya check tests/error_async_await_in_errdefer.uya`（按预期失败，命中 `@await 不能出现在 defer/errdefer 块中；清理逻辑必须保持同步`）
  - 验证：`../uya/bin/uya test tests/test_async_match_await.uya`（通过，4 tests / 4 assertions）
  - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya`（通过，10 tests / 18 assertions）
  - 验证：`git diff --check`（通过）
  - 备注：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh native` 在既有基线 `tests/test_async_await_parse.uya` 触发无关 C99 codegen 失败，未作为本叶子完成门槛。
## Phase 1：`@async_fn` 语法完整性
### 1.4 收口语法口径

- [x] 任何“只是因为内部实现没覆盖到，所以先拒绝”的限制，都必须消失或升级成规范层决策。
  - 验证：`../uya/bin/uya test tests/test_async_match_await.uya`（通过；4 tests passed）
  - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya`（通过；10 tests passed）
  - 验证：`UYA_COMPILER=/media/winger/_dde_data/winger/uya/uya/bin/uya ./tests/run_programs_parallel.sh --uya --c99 tests/test_async_for_await.uya`（通过）
  - 验证：`UYA_COMPILER=/media/winger/_dde_data/winger/uya/uya/bin/uya ./tests/run_programs_parallel.sh --uya --c99 tests/test_async_for_iterator_ref_await.uya`（通过）
  - 验证：`rg -n "尚未支持" src/codegen/c99/function.uya src/codegen/c99/async_transform.uya src/lower/async.uya`（无匹配）
  - 审计：`docs/uya.md`、`docs/grammar_formal.md`、`docs/grammar_quick.md` 已明确把 `defer/errdefer` 内禁止 `@await` 定义为语言规则；本轮覆盖的其余合法 async 语法未发现实现层兜底拒绝
  - 备注：`./tests/run_programs_parallel.sh` 在脚本内部使用相对 `UYA_COMPILER=../uya/bin/uya` 会因工作目录变化失效，因此程序回归按本 todo 明示的绝对路径完成验证

## 2026-06-21 Phase 1.5：标准库手工 Future 清零迁移

上下文：`### 1.5.0 统计口径` → `先明确“手工异步 Future”的统计范围`

  - [x] **算入迁移范围**：统计入口按语法形态全量覆盖 `lib/std` 中任何 `struct XxxFuture : Future<...>` 且自定义 `poll()` 的状态机，不因“runtime I/O 叶子”“调度桥接”“协议/传输层”“纯组合层”标签而豁免；按当前仓库命中 18 个类型，包含此前清单漏记的 `DnsQueryAllAggregateFuture`。
    - 验证：`rg -n 'struct [A-Za-z0-9_]+Future[^\\n]*: Future<' lib/std | wc -l` 输出 `18`。
    - 验证：`rg -n '^export interface Future<|^export struct Future<|^export struct Task<' lib/std/async.uya` 输出 `277/283/296`，确认 runtime 协议壳单独位于 `lib/std/async.uya`，不影响本条“先全量盘点自定义 poll 状态机”的入口口径。
    - 验证：`rg -n 'return Future<.*state: Poll<.*Ready' lib/std | head -n 8` 命中 `lib/std/async_channel.uya`、`lib/std/thread.uya`、`lib/std/http/websocket_client.uya` 等 ready wrapper 样本，后续由 L123 单独排除。
    - 验证：`rg -n 'DnsQuery(AllAggregate|Transport)Future|Dns(Udp|Tcp)Future' lib/std/net/dns.uya` 命中 `DnsQueryAllAggregateFuture`（`2426`），已补入 1.5.1 清单。

## 2026-06-21 Phase 1.5：标准库手工 Future 清零迁移

上下文：`### 1.5.0 统计口径` → `先明确“手工异步 Future”的统计范围`

  - [x] **不算业务迁移对象**：`std.async` 的 `interface Future<T>`、占位 `struct Future<T>`、`Task<T>` 这类 runtime 核心协议壳类型。
    - 验证：`nl -ba lib/std/async.uya | sed -n '1,4p'` 显示模块头部为“异步运行时类型与接口”，导出列表单列 `interface Future<T>`、占位 `struct Future<T>`、`Task<T>`。
    - 验证：`nl -ba lib/std/async.uya | sed -n '276,306p'` 显示 `Future<T>` 只定义 `poll/release` 协议；占位 `Future<T>` 注释注明“`@async_fn` 函数当前返回此类型；实现 interface Future<T> 以便类型兼容”；`Task<T>` 注释注明“异步任务包装”，实现也仅持有 `Poll<T>` 状态并转发 `poll/release`。
    - 验证：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`（通过；主 todo 有 `0 active tasks`）
    - 验证：`git diff --check`（通过）

## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.0 统计口径

- [x] 先明确“手工异步 Future”的统计范围：
  - 已确认：`lib/std/async.uya` 中 `interface Future<T>`、占位 `struct Future<T>`、`Task<T>` 属于 runtime 核心协议壳类型，不计入业务迁移对象；详细验证记录见完成归档。
  - [x] **不算手工状态机**：只返回 `Future{ state: Poll.Ready(...) }` 的一次性 ready wrapper。
    - 验证：`rg -n "future_ready_ok\\(|Task<.*>\\{ state: Poll<.*>\\.Ready|Future<.*>\\{ state: poll_ready_ok|Task<.*>\\{ state: poll_ready_ok" lib/std tests` 仅命中 `lib/std/async.uya` 的 `future_ready_ok`、`task_ready`、`task_ready_ok` 三个 ready helper。
    - 验证：`sed -n '277,336p' lib/std/async.uya` 显示 `Future<T>` / `Task<T>` 的 `poll()` 只返回 `self.state`，这些 helper 只预置 `Poll.Ready(...)`，没有手写状态推进。
    - 验证：`../uya/bin/uya test tests/test_task_std_async.uya` 通过，`task_ready`、`task_ready_ok`、`future_ready_ok` 共 6 个用例全部通过。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.0 统计口径
路径：最终目标口径 > 标准库业务层、协议层和 I/O 组合层不再保留手写 `poll()` 状态机。

- [x] `lib/std/http/websocket_client.uya`：将 `WebSocketClientReconnectFuture` 改为 `@async_fn websocket_client_reconnect_tick(...)`，并补结构性检查确认手写 reconnect future 已删除。
  - 验证：`bash tests/verify_async_websocket_client_reconnect_boundary.sh`
    - 结果：通过；确认 `websocket_client_reconnect_tick` 已升级为 `export @async_fn fn`，`struct WebSocketClientReconnectFuture` 已删除，并且 `../uya/bin/uya check tests/test_http_websocket_reconnect.uya` 通过。
  - 验证：`../uya/bin/uya test tests/test_http_websocket_reconnect.uya`
    - 结果：失败；当前仅剩仓库既有的 C99 代码生成/宿主编译错误：`std_http_websocket_conn_write_message_poll` 的 `invalid initializer`，以及 `std_http_uyagin_send_context_response_body_trait_async_poll` 的 `invalid initializer`。
    - 说明：本轮已消除 `std_http_websocket_client_reconnect_tick_poll` 的额外生成错误，当前失败点与本叶子迁移无关。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.0 统计口径
父级路径：`最终目标口径：` / `标准库业务层、协议层和 I/O 组合层不再保留手写 \`poll()\` 状态机。`
    - [x] `lib/std/http/websocket_async.uya`：将 `WebSocketHeartbeatTimeoutFuture` 改为 `@async_fn`，保持 heartbeat timeout 先发 close 再返回超时错误。验收：`../uya/bin/uya test tests/test_http_websocket_json.uya`
      - 验证：`../uya/bin/uya test tests/test_http_websocket_heartbeat.uya`（通过：5 tests passed）
      - 验证：`../uya/bin/uya test tests/test_http_websocket_json.uya`（通过：3 tests passed）

## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.0 统计口径

路径：最终目标口径 > 标准库业务层、协议层和 I/O 组合层不再保留手写 `poll()` 状态机。

- [x] `lib/std/http/uyagin.uya`：将 `UyaginRecoverFuture`、`UyaginObserveFuture` 改为 `@async_fn` 包装器，不改变 recover / observe 副作用顺序。验收：补 dedicated uyagin recover/observe 回归并运行对应测试
  验证：
  `ulimit -s 32768 && cd src && UYA_MULTI_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR= RUNTIME_MODE=nostdlib LINK_MODE=static CFLAGS='-std=c99 -O2 -fno-builtin -Werror -fno-stack-protector' ./compile.sh --c99 -e --nostdlib --safety-proof`（通过，重建 `bin/uya` 以带上 `@async_fn` allocator 修复）
  `../uya/bin/uya test tests/test_http_uyagin_recover_observe.uya`（通过）
  `../uya/bin/uya test tests/test_http_uyagin.uya`（通过）
  `../uya/bin/uya test tests/test_std_async_scheduler.uya`（通过）
## Phase 1.5：标准库手工 Future 清零迁移

任务路径：
- [ ] 最终目标口径：
  - [ ] 标准库业务层、协议层和 I/O 组合层不再保留手写 `poll()` 状态机。

已完成任务：
    - [x] `lib/std/net/dns.uya`：将 `DnsQueryTransportFuture`、`DnsQueryAllAggregateFuture` 改为 `@async_fn` 组合层，不再手工 poll 另一个 future。验收：补 DNS transport/aggregate 回归并运行对应测试
      - 验证：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`（通过，1 test / 4 assertions）
      - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（通过，2 DNS runtime tests / 4 assertions）
      - 验证：`../uya/bin/uya test tests/test_std_dns_async_query_aggregate.uya`（通过，3 DNS aggregate tests / 6 assertions）
      - 验证：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya`（通过，4 tests / 44 assertions）
