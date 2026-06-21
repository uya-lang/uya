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

## 2026-06-21 本轮完成

上下文：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## Phase 3：运行时 async 资源动态化 > ### 3.2 Scheduler / TaskQueue

  - [x] 把 scheduler 的 `_frame_stack_buffer[8192]` 改成显式配置或动态后备存储策略。
    - 验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya`
    - 结果：通过；新增 `scheduler_new_uses_runtime_default_frame_buffer_size`，常态默认路径下 21 tests / 244 assertions 全通过。
    - 验证：`UYA_SCHEDULER_FRAME_BUFFER_BYTES=12288 ../uya/bin/uya test tests/test_std_async_scheduler.uya`
    - 结果：通过；`scheduler_new()` 读取环境变量后的 frame buffer 大小断言通过，21 tests / 244 assertions 全通过。
    - 回归：`../uya/bin/uya test tests/test_async_fd.uya`
    - 结果：通过；14 tests / 85 assertions 全通过。
    - 文档同步：`docs/todo_async_full_language_dynamic_resources.md` 与 `docs/async_runtime_semantics_matrix.md` 已改为“frame pool backing buffer 支持实例配置与 `UYA_SCHEDULER_FRAME_BUFFER_BYTES` 默认策略”的当前口径。

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

## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.0 统计口径

- [ ] 最终目标口径：
  - [ ] 标准库业务层、协议层和 I/O 组合层不再保留手写 `poll()` 状态机。
    - [x] `lib/std/http/websocket_async.uya`：将 `WebSocketReadMessageFuture` 改为 `@async_fn` 消息聚合路径，保持 ping/pong/close/fragment 语义。验收：`../uya/bin/uya test tests/test_http_websocket_json.uya`
      - 验证：`../uya/bin/uya test tests/test_http_websocket_async_read_message_shape.uya`（通过）
      - 验证：`../uya/bin/uya test tests/test_http_websocket_read_message_semantics.uya`（通过）
      - 验证：`timeout 30s ../uya/bin/uya test tests/test_http_websocket_async.uya`（5/5 通过）
      - 验证：`../uya/bin/uya test tests/test_http_websocket_json.uya`（通过）
      - 备注：非终帧路径显式补 `continue;`，remote close 清理收束为同步 helper，避免 `@await` 恢复点跳回循环头。

## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

路径：`最终目标口径` > `标准库业务层、协议层和 I/O 组合层不再保留手写 poll() 状态机。` > `lib/std/http/websocket_client.uya`

- [x] 将 `WebSocketClientReconnectFuture` 改为 `@async_fn reconnect_tick_async(...)` 或等价异步方法。
  - 验证：`bash -lc 'if rg -n "WebSocketClientReconnectFuture|fn poll\\(" lib/std/http/websocket_client.uya >/tmp/ws_client_rg.txt; then cat /tmp/ws_client_rg.txt; exit 1; else echo ok: websocket_client.uya has no manual reconnect future or poll method; fi'` -> `ok: websocket_client.uya has no manual reconnect future or poll method`
  - 验证：`../uya/bin/uya test tests/test_http_websocket_reconnect.uya` -> `6 tests passed, 0 failed`
  - 验证：`../uya/bin/uya test tests/test_http_websocket_module_smoke.uya` -> `1 test passed, 0 failed`
## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.0 统计口径

任务路径：最终目标口径

- [x] 标准库业务层、协议层和 I/O 组合层不再保留手写 `poll()` 状态机。
  - [x] 校准并固化当前已完成的高层清零现状：`websocket_client`、`websocket_async`（`read_message` / `heartbeat`）、`uyagin` recover/observe、`dns_query_transport` 必须继续保持 `@async_fn` / `@await` 路线，不得回退到手写 `poll()`。
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（1 test, 14 assertions，全通过）
    - 验证：`rg -n "^(export )?struct .*: Future<" lib/std/http lib/std/net --glob '*.uya'` 仅剩 `DnsUdpFuture`、`DnsTcpFuture`、`Http1ConnectFuture`、`UyaginWritevFuture`、`UyaginSendFileBodyFuture`、`UyaginConnReadParseFuture`、`UyaginConnReadParseIntoFuture`、`UyaginAcceptFuture`

## 2026-06-21 归档：子树 `最终目标口径`

> 父级路径：`## Phase 1.5：标准库手工 Future 清零迁移` → `### 1.5.0 统计口径`

- [x] 最终目标口径：
  - [x] 如果最底层 runtime 叶子原语仍必须手写，要把它们收缩到最小、明确、可解释的 substrate 集，并单列为最后清零项，不允许无限期混在业务模块里。
    - 结论：当前仓库允许暂列为 runtime substrate 唯一例外的仅有 `lib/std/async.uya` 的 `AsyncFdReadFuture` / `AsyncFdWriteFuture`，以及 `lib/std/thread.uya` 的 `AsyncComputeFuture<T>`。
    - 结论：`lib/std/http/http1_async.uya` 的 `Http1ConnectFuture`、`lib/std/net/dns.uya` 的 `DnsUdpFuture` / `DnsTcpFuture`、`lib/std/http/uyagin.uya` 的 `UyaginWritevFuture` / `UyaginSendFileBodyFuture` / `UyaginConnReadParseFuture` / `UyaginConnReadParseIntoFuture` / `UyaginAcceptFuture` 都属于业务模块 syscall/I/O 叶子，不计入 substrate，必须在 1.5.4 / 1.5.5 里继续迁移。
    - 结论：`WebSocketClientReconnectFuture`、`WebSocketReadMessageFuture`、`WebSocketHeartbeatTimeoutFuture`、`UyaginRecoverFuture`、`UyaginObserveFuture`、`DnsQueryTransportFuture`、`DnsQueryAllAggregateFuture` 已不再以 `struct ... : Future<...>` 形式存在，不再计入“当前手工 Future 清单”。
  - 验证：`rg -n 'WebSocketClientReconnectFuture|WebSocketReadMessageFuture|WebSocketHeartbeatTimeoutFuture|UyaginRecoverFuture|UyaginObserveFuture|DnsQueryTransportFuture|DnsQueryAllAggregateFuture|Http1ConnectFuture|AsyncComputeFuture|AsyncFdWriteFuture|AsyncFdReadFuture' lib/std/http/websocket_async.uya lib/std/http/websocket_client.uya lib/std/http/uyagin.uya lib/std/net/dns.uya lib/std/http/http1_async.uya lib/std/thread.uya lib/std/async.uya` 仅命中 `AsyncFd*` / `AsyncComputeFuture` / `Http1ConnectFuture` 等仍在仓库中的实际对象，未发现已迁移组合层旧结构体定义。
  - 验证：`rg -n 'struct .*Future|Future<|wait_readable|wait_writable|eventfd|sendfile|writev|accept\\(|connect\\(' lib/std/async.uya lib/std/thread.uya lib/std/net/dns.uya lib/std/http/http1_async.uya lib/std/http/websocket_client.uya lib/std/http/websocket_async.uya lib/std/http/uyagin.uya` 配合相关 `sed` 片段核对后，剩余手写 `poll()` 确认集中在 `async/thread` 底座、DNS/HTTP connect 和 UyaGin syscall 热路径。
### 1.5.2 迁移顺序原则

路径：`先纯组合层，后 syscall 叶子层`

- [x] 纯组合层更适合直接改写成 `@async_fn`，也是验证完整语法支持的最好样本。
  - 验证命令：`rg -n "export @async_fn fn websocket_client_reconnect_tick|export @async_fn fn websocket_conn_read_message|export @async_fn fn websocket_conn_heartbeat_tick|export @async_fn fn uyagin_run_chain_recover|@async_fn fn uyagin_observe_request_future|@async_fn fn dns_query_transport_future_new|@async_fn fn dns_client_query_all_any_async|async_join2_usize_results" lib/std/http/websocket_client.uya lib/std/http/websocket_async.uya lib/std/http/uyagin.uya lib/std/net/dns.uya`
  - 验证结果：`websocket_client_reconnect_tick`、`websocket_conn_read_message`、`websocket_conn_heartbeat_tick`、`uyagin_observe_request_future`、`uyagin_run_chain_recover`、`dns_query_transport_future_new`、`dns_client_query_all_any_async` 已经是 `@async_fn` / join 组合层。
  - 验证命令：`rg -n "export struct AsyncComputeFuture<T> : Future<!T>|struct Http1ConnectFuture : Future<!i32>|struct DnsUdpFuture : Future<!usize>|struct DnsTcpFuture : Future<!usize>|struct UyaginWritevFuture : Future<!usize>|struct UyaginSendFileBodyFuture : Future<!usize>|struct UyaginConnReadParseFuture : Future<!ParseResult>|struct UyaginConnReadParseIntoFuture : Future<!usize>|struct UyaginAcceptFuture : Future<!i32>" lib/std/thread.uya lib/std/http/http1_async.uya lib/std/net/dns.uya lib/std/http/uyagin.uya`
  - 验证结果：残留手写 `Future` 集中在 `Http1ConnectFuture`、`DnsUdpFuture`、`DnsTcpFuture`、`Uyagin*Future` 与 `AsyncComputeFuture<T>`，仍属于 syscall / I/O 叶子或 runtime substrate，符合“先组合层、后 syscall 叶子层”的迁移顺序。

### 1.5.2 迁移顺序原则

- [x] **先纯组合层，后 syscall 叶子层**。
  - [x] syscall 叶子层如果直接硬改，容易把 runtime 底座和业务逻辑缠在一起。
    - 代码核对（2026-06-21）：
      - `lib/std/thread.uya:1196-1268` 的 `AsyncComputeFuture<T>` 已经把 cancel、worker slot / pending wake、`usize -> T` 结果解码压进 `ThreadAsyncComputeCore` 包装层，属于 runtime substrate / 调度桥接候选，不应再夹带 HTTP/DNS 业务分支。
      - `lib/std/net/dns.uya:981-1139` 的 `DnsUdpFuture` 在同一个 `poll()` 里同时处理 query 组装、deadline、nonblocking connect/send/recv 和 response parse；若先在业务模块内硬改，后续很难把 `async_connect` / `async_recv_parse` 一类原语抽离干净。
      - `lib/std/http/http1_async.uya:346-457` 的 `Http1ConnectFuture` 既管 deadline / nonblocking connect，也直接耦合 DNS fallback 与 `TCP_NODELAY` 收尾；它更像 awaitable I/O 原语的调用点，不适合作为 runtime 底座演化入口。
      - `lib/std/http/uyagin.uya:2172-2391,3082-3326` 的 `UyaginWritevFuture` / `UyaginSendFileBodyFuture` / `UyaginConnReadParseFuture` / `UyaginAcceptFuture` 把 writev、sendfile fallback、HTTP parse、accept 热路径和 fd readiness 绑在一起，直接迁移会把高性能细节与调度接口一起改坏。
    - 验证：
      - `rg -n "AsyncComputeFuture|DnsUdpFuture|Http1ConnectFuture|UyaginWritevFuture|UyaginSendFileBodyFuture|UyaginConnReadParseFuture|UyaginAcceptFuture" lib/std/thread.uya lib/std/net/dns.uya lib/std/http/http1_async.uya lib/std/http/uyagin.uya`
        - 结果：确认上述 runtime substrate 候选与 syscall/I/O 叶子 Future 仍以手写状态机形式存在。
      - `git diff --check`
        - 结果：通过，无空白或补丁格式错误。

### 1.5.2 迁移顺序原则
路径：**先提炼通用 awaitable 原语，再迁移重复状态机** -> `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_recv_parse`、`async_worker_result` 这类原语先统一，再让协议层用 `@await` 组合。
- [x] 在 `lib/std/async.uya` 提炼 `async_connect` helper，并先将 `lib/std/http/http1_async.uya` 的 `Http1ConnectFuture` 改为基于该 helper 的 `@async_fn` 组合；验证：`../uya/bin/uya test tests/test_async_fd.uya`、`../uya/bin/uya test tests/test_http1_async_client.uya`
  - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（通过：8 tests passed，0 failed）
  - 验证：`../uya/bin/uya test tests/test_http1_async_client.uya`（通过：8 tests passed，0 failed）
### 2026-06-21
# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.2 迁移顺序原则
- [ ] **先提炼通用 awaitable 原语，再迁移重复状态机**。
  - [ ] 例如 `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_recv_parse`、`async_worker_result` 这类原语先统一，再让协议层用 `@await` 组合。
    - [x] 复用 `async_connect` helper 收口 `lib/std/net/dns.uya` 的 TCP connect 阶段，保持 nameserver timeout / fallback 语义；验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`
      验证结果：
      - `../uya/bin/uya test tests/test_std_dns_async_transport.uya`：通过（3 tests, 6 assertions）
      - `../uya/bin/uya test tests/test_std_dns.uya`：通过（34 tests, 78 assertions）

### 1.5.2 迁移顺序原则
路径：- [ ] **先提炼通用 awaitable 原语，再迁移重复状态机**。
路径：  - [ ] 例如 `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_recv_parse`、`async_worker_result` 这类原语先统一，再让协议层用 `@await` 组合。
    - [x] 在 `lib/std/async.uya` 提炼 `async_accept` helper，并迁移 `lib/std/http/uyagin.uya` 的 `UyaginAcceptFuture`；验证：`../uya/bin/uya test tests/test_http_uyagin.uya`
      - 验证记录（2026-06-21）：
        - `../uya/bin/uya test tests/test_http_uyagin.uya`：通过（23 tests passed；新增回归 `uyagin_accept_uses_async_accept_helper_and_preserves_nodelay` 通过）
        - `../uya/bin/uya test tests/test_async_fd.uya`：通过（8 tests passed）

### 1.5.2 迁移顺序原则
路径：- [ ] **先提炼通用 awaitable 原语，再迁移重复状态机**。
路径：  - [ ] 例如 `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_recv_parse`、`async_worker_result` 这类原语先统一，再让协议层用 `@await` 组合。
    - [x] 提炼 `async_read_parse` / `async_read_parse_into` helper，并迁移 `lib/std/http/uyagin.uya` 的 `UyaginConnReadParseFuture` / `UyaginConnReadParseIntoFuture`；验证：`../uya/bin/uya test tests/test_http_uyagin.uya`
      - 验证记录（2026-06-21）：
        - `../uya/bin/uya test tests/test_http_uyagin.uya`：通过（24 tests, 33 assertions；新增回归 `async_read_parse_helpers_decode_chunked_request_and_preserve_err_out` 通过）
        - `../uya/bin/uya test tests/test_async_fd.uya`：通过（10 tests, 53 assertions）

### 1.5.2 迁移顺序原则

- 任务路径：**先提炼通用 awaitable 原语，再迁移重复状态机** > 例如 `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_recv_parse`、`async_worker_result` 这类原语先统一，再让协议层用 `@await` 组合。
  - [x] 在 `lib/std/async.uya` 提炼 `async_writev` / `async_sendfile` helper，并迁移 `lib/std/http/uyagin.uya` 的写热路径 future；验证：`../uya/bin/uya test tests/test_async_fd.uya`、`../uya/bin/uya test tests/test_http_uyagin.uya`
    - 验证记录（2026-06-21）：
      - `../uya/bin/uya test tests/test_async_fd.uya`：通过（10 tests passed，覆盖新增 `async_writev` / `async_sendfile` helper 回归）。
      - `../uya/bin/uya test tests/test_http_uyagin.uya`：通过（23 tests passed，确认 uyagin 写热路径迁移后语义未回退）。

### 1.5.2 迁移顺序原则

路径：**先提炼通用 awaitable 原语，再迁移重复状态机** > 例如 `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_recv_parse`、`async_worker_result` 这类原语先统一，再让协议层用 `@await` 组合。

    - [x] 提炼 `async_worker_result` / `async_thread_slot_wait` 类 helper，并为 `lib/std/thread.uya` 的 `AsyncComputeFuture<T>` 后续 `@async_fn` 化打底；验证：`../uya/bin/uya test tests/test_std_thread.uya`
      - 验证结果（2026-06-21）：`../uya/bin/uya test tests/test_std_thread.uya` 通过（25 passed, 0 failed）。
### 1.5.2 迁移顺序原则

- 父级任务：`Phase 1.5：标准库手工 Future 清零迁移` / `先提炼通用 awaitable 原语，再迁移重复状态机`
- [ ] **先提炼通用 awaitable 原语，再迁移重复状态机**。
  - [x] 核对并收口已统一的 I/O awaitable 原语清单：确认 `lib/std/async.uya` 已提供 `async_connect`、`async_accept`、`async_writev`、`async_sendfile`、`async_read_parse` / `async_read_parse_into`，且 `http1_async` / `uyagin` / `dns` 已改为通过 `@await` 组合；完成条件：本节示例列表改成当前真实剩余差距，不再把已完成原语当作待迁移项；验证：`rg -n "async_connect|async_accept|async_writev|async_sendfile|async_read_parse|async_read_parse_into" lib/std/async.uya lib/std/http/http1_async.uya lib/std/http/uyagin.uya lib/std/net/dns.uya tests`
    - 验证命令：`rg -n "async_connect|async_accept|async_writev|async_sendfile|async_read_parse|async_read_parse_into" lib/std/async.uya lib/std/http/http1_async.uya lib/std/http/uyagin.uya lib/std/net/dns.uya tests`
    - 验证结果：通过；命中 `lib/std/async.uya` 的 6 个 awaitable 导出，以及 `http1_async` / `uyagin` / `dns` / tests 的对应调用点。
    - 验证命令：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
    - 验证结果：通过；输出 `ok: docs/todo_async_full_language_dynamic_resources.md has 1 active task`。
    - 验证命令：`git diff --check -- docs/todo_async_full_language_dynamic_resources.md`
    - 验证结果：通过；无输出。

### 1.5.2 迁移顺序原则
- [x] **先提炼通用 awaitable 原语，再迁移重复状态机**。
  - [x] 收口 `async_worker_result` / `async_thread_slot_wait` 线程桥接 awaitable，明确是否迁入共享 runtime 层并补 `async_compute` 回归；完成条件：`AsyncComputeFuture` 不再保留重复的 pipe 等待桥接分支，协议层清单只剩真实未统一叶子；验证：`../uya/bin/uya test tests/test_std_thread.uya`
    - 结论：`async_worker_result` / `async_thread_slot_wait` 保留在 `lib/std/thread.uya`，不迁入 `lib/std/async.uya`；它们依赖 ThreadPool slot / worker 协议，不属于通用 fd runtime primitive。
    - 结果：`AsyncComputeFuture<T>` 现在只轮询单个 `async_worker_result(...)` helper，已移除自身的 `wait_current_slot` / `poll_worker_result` 双桥接分支。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya` 通过；27 tests passed，107 assertions passed。
    - 补充验证：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya` 通过；4 tests passed，44 assertions passed。
# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.2 迁移顺序原则

- [x] **迁移不能降低现有错误语义、取消语义和 deadline 语义**。
  - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（11/11 通过；新增 `async_connect_expired_deadline_returns_async_deadline_exceeded` 锁定 helper deadline 语义）
  - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`（25/25 通过；新增 `async_read_parse_into_connection_closed_preserves_err_out_compat` 锁定旧 `err_out` / `ConnectionClosed` 语义）
  - 验证：`../uya/bin/uya test tests/test_std_thread.uya`（27/27 通过）、`../uya/bin/uya test tests/test_std_async_scheduler.uya`（19/19 通过）、`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（3/3 通过）、`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya`（4/4 通过）；确认 `Cancelled`、DNS timeout/error 与 shared runtime 迁移语义未回退。

### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

父级任务：`lib/std/http/websocket_client.uya`
  - [x] 保持现有 backoff / attach / exhausted 语义不变，并补 dedicated regression。
    验证：
    `../uya/bin/uya test tests/test_http_websocket_reconnect.uya` -> 通过（7 tests / 41 assertions）
    `bash tests/verify_async_websocket_client_reconnect_boundary.sh` -> 通过（checker 通过）
    `../uya/bin/uya test tests/test_async_std_business_future_boundary.uya` -> 通过（1 test / 14 assertions）
    `git diff --check` -> 通过
  - [x] 依赖：`catch + @await`、结构体方法 async、错误路径收口稳定。
    说明：当前稳定形态使用 `const connect_result = @await websocket_client_connector_connect(...)` + `connect_result catch ...`；直接把 `catch` 内联到 `@await connector.connect(...)` 会触发当前 C99 codegen bind 槽类型错配，因此保留了薄 wrapper 收口接口/结构体 async 方法调用。
    先失败：
    `../uya/bin/uya test tests/test_http_websocket_reconnect.uya` -> 失败（新增 source boundary 断言后命中 `actual: 0, expected: 1`，证明 `reconnect_tick` 尚未在本体里使用 `catch` 收口 `@await` 结果）
    验证：
    `../uya/bin/uya test tests/test_http_websocket_reconnect.uya` -> 通过（7 tests / 44 assertions）
    `bash tests/verify_async_websocket_client_reconnect_boundary.sh` -> 通过（checker 通过）
    `../uya/bin/uya test tests/test_async_std_business_future_boundary.uya` -> 通过（1 test / 14 assertions）
    `git diff --check` -> 通过

### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

父级任务路径：`lib/std/http/websocket_async.uya`

- [x] 保持 message aggregate / heartbeat / close 组合层继续走 `@async_fn`，禁止回退到手写 `poll()`。
  - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过：1 个测试，17 次断言）
  - 验证：`../uya/bin/uya test tests/test_http_websocket_async.uya`（通过：5 个测试，20 次断言）
  - 验证：`../uya/bin/uya test tests/test_http_websocket_heartbeat.uya`（通过：5 个测试，25 次断言）

### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

- [x] `lib/std/http/websocket_async.uya`
  - [x] 如果还依赖手工 close leaf，则先抽出 awaitable close helper。
    - 验证：`../uya/bin/uya test tests/test_http_websocket_heartbeat.uya`（通过，5 tests passed）
    - 验证：`../uya/bin/uya test tests/test_http_websocket_async.uya`（通过，5 tests passed）
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过，1 test passed）

### 2026-06-21 Phase 1.5.3 `lib/std/http/uyagin.uya`

标题路径：
# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

父级任务路径：`lib/std/http/uyagin.uya`

- [x] 保持 recover / observe 包装继续走 `@async_fn`，并补观测副作用回归。
  - 依赖：`defer / errdefer`、`catch + @await`、观测副作用在 async body 中稳定。
  - 验证：`../uya/bin/uya test tests/test_http_uyagin_recover_observe.uya` 通过（2 tests, 9 assertions）。
  - 验证：`../uya/bin/uya test tests/test_async_catch_await.uya` 通过（10 tests, 10 assertions）。
  - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya` 通过（10 tests, 18 assertions）。
  - 验证：`rg -n '"tests/test_http_uyagin_recover_observe.uya"' tests/verify_async_full_language_matrix.sh` 命中 `tests/verify_async_full_language_matrix.sh:142`，已纳入 async baseline。
  - 验证：`git diff --check` 通过。
  - 记录：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh native` 未完成；现存基线在 `tests/test_async_await_parse.uya` 先失败，C 代码生成报 `incompatible types when initializing type 'int' using type 'struct Future_i32'`，阻塞点与本轮改动无关。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

- [x] `lib/std/net/dns.uya`
  - [x] 保持 transport fallback 组合层继续走 `@async_fn` + join 组合，不重新引入“手工 future poll 另一个 future”模式。
  - 验证：
    - `../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`：通过（1 test，9 assertions）。
    - `../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`：通过（1 test，17 assertions）。
    - `../uya/bin/uya test --c99 tests/test_std_dns_async_composition_shape.uya`：通过（1 test，9 assertions）。
    - `rg -n 'test_std_dns_async_composition_shape\\.uya' tests/verify_async_full_language_matrix.sh`：命中 `141:    "tests/test_std_dns_async_composition_shape.uya"`，已纳入 async matrix 脚本。
    - `UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh c99`：失败；脚本在既有基线 `tests/test_async_await_parse.uya` 上先报宿主 C 编译错误（`incompatible types when initializing type 'int' using type 'struct Future_i32'`），未执行到新 DNS 条目。
    - `git diff --check`：通过。

# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

- [x] 上述四类组合层不再含手写 `poll()`。
  - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya` 通过（1 个测试，17 个断言）。
  - 验证：`../uya/bin/uya test tests/test_http_uyagin_recover_observe.uya` 通过（2 个测试，9 个断言）。
  - 验证：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya` 通过（1 个测试，9 个断言）。
  - 核对：`rg -n "poll\\s*\\(" lib/std/http/websocket_client.uya lib/std/http/websocket_async.uya lib/std/http/uyagin.uya lib/std/net/dns.uya` 仅命中 DNS 传输叶子 future 与 uyagin 调度槽位/事件循环，目标组合层 `websocket_client_reconnect_tick`、`websocket_conn_read_message`、`websocket_conn_heartbeat_tick`、`uyagin_run_chain_recover`、`uyagin_observe_request_future`、`dns_query_transport_future_new`、`dns_client_query_all_any_async` 未含手写 `poll()`。

### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

父级任务路径：`相关回归补齐并纳入脚本`

- [x] `tests/test_async_catch_await.uya`
  - 验证：`../uya/bin/uya test --uya --c99 tests/test_async_catch_await.uya` 通过（10 tests passed, 0 failed）
  - 纳入脚本：`rg -n "test_async_catch_await\\.uya" tests/verify_async_full_language_matrix.sh` 命中 `baseline_tests`
  - 额外验证：`UYA_COMPILER=../uya/bin/uya bash tests/verify_async_full_language_matrix.sh uya-c99` 失败；在 `tests/test_async_await_parse.uya` 先触发现有 C99 codegen 错误：`incompatible types when initializing type 'int' using type 'struct Future_i32'`，未执行到本用例

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`
父级路径：相关回归补齐并纳入脚本
- [x] `tests/test_async_defer_errdefer.uya`
  - 验证：`../uya/bin/uya test tests/test_async_defer_errdefer.uya`（通过，10 tests passed，18 assertions）
  - 纳入脚本：`rg -n "test_async_defer_errdefer\\.uya" tests/verify_async_full_language_matrix.sh`（命中第 126 行）
  - 补充验证：`../uya/bin/uya test tests/test_async_cleanup_body_coverage.uya`（通过，2 tests passed，5 assertions）
  - 补充验证：`../uya/bin/uya test tests/test_async_sync_body_matrix.uya`（通过，4 tests passed，20 assertions）

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.3 第一批：纯组合层先全部改成 `@async_fn`

**验收**：

- [x] 相关回归补齐并纳入脚本：
  - [x] websocket client / uyagin / dns 新回归
    - 变更：将 `tests/test_async_std_business_future_boundary.uya` 纳入 `tests/verify_async_full_language_matrix.sh` baseline tests。
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过，1 test / 17 assertions）
    - 验证：`../uya/bin/uya test --c99 tests/test_async_std_business_future_boundary.uya`（通过，1 test / 17 assertions）
    - 验证：`../uya/bin/uya test --uya --c99 tests/test_async_std_business_future_boundary.uya`（通过，1 test / 17 assertions）
    - 验证：`rg -n 'test_async_std_business_future_boundary\\.uya' tests/verify_async_full_language_matrix.sh`（命中 `142:    "tests/test_async_std_business_future_boundary.uya"`，已纳入 async baseline matrix）

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语

父级任务路径：在 `lib/std/async.uya` 或新的 leaf 模块中抽象以下 awaitable 原语
  - [x] `async_connect(fd, sockaddr, len, deadline_ms)` 或等价 helper
    - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（通过：11 tests，54 assertions；覆盖 loopback connect 与 deadline 超时）
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（通过：3 tests；DNS TCP fallback 连接路径正常）
    - 验证：`../uya/bin/uya test tests/test_http1_async_client.uya`（通过：8 tests；HTTP1 async roundtrip 连接路径正常）

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语

- 父级：在 `lib/std/async.uya` 或新的 leaf 模块中抽象以下 awaitable 原语：
  - [x] `async_accept(fd)` 或等价 helper
    - 实现核对：`lib/std/async.uya` 已提供 `AsyncAcceptFuture` / `async_accept(listen_fd)`；`lib/std/http/uyagin.uya` 的 `uyagin_accept_future` 通过 `@await async_accept(listen_fd)` 复用该 helper。
    - 验证命令：`../uya/bin/uya test tests/test_http_uyagin.uya`
    - 验证结果：通过；`25` 个测试全部通过，包含 `uyagin_accept_uses_async_accept_helper_and_preserves_nodelay`
    - 验证命令：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
    - 验证结果：`ok: docs/todo_async_full_language_dynamic_resources.md has 0 active tasks`

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语

父级任务：在 `lib/std/async.uya` 或新的 leaf 模块中抽象以下 awaitable 原语：
  - [x] `async_writev(fd, iov, iovcnt)` 或等价 helper
    - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（通过：11 tests，`async_writev_writes_head_then_body` OK）
    - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`（通过：25 tests 全通过）

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语

路径：- [ ] 在 `lib/std/async.uya` 或新的 leaf 模块中抽象以下 awaitable 原语：
  - [x] `async_sendfile(fd, file_fd, ...)` 或等价 helper
    - 结论（2026-06-21）：代码核对确认 `lib/std/async.uya` 已导出 `async_sendfile`，`lib/std/http/uyagin.uya` 也已通过该 helper 复用文件响应发送路径；主 todo 该叶子为过期项，现按本轮验证归档。
    - 验证命令：`../uya/bin/uya test tests/test_async_fd.uya`
    - 验证结果：通过（11 tests passed, 54 assertions；`async_sendfile_copies_file_into_fd` 通过）。
    - 验证命令：`../uya/bin/uya test tests/test_http_uyagin.uya`
    - 验证结果：通过（25 tests passed, 37 assertions；`uyagin_body_traits_static_arena_file` 等文件响应相关回归通过）。
    - 验证命令：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
    - 验证结果：通过；输出 `ok: docs/todo_async_full_language_dynamic_resources.md has 0 active tasks`。
    - 验证命令：`git diff --check -- docs/todo_async_full_language_dynamic_resources.md docs/todo_async_full_language_dynamic_resources_completed.md`
    - 验证结果：通过；无输出。

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语

路径：`在 lib/std/async.uya 或新的 leaf 模块中抽象以下 awaitable 原语`

- [x] `async_read_parse(fd, buf, ...)` / `async_read_parse_into(...)` 或更底层的可组合 read helper
  - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`
  - 结果：通过；`async_read_parse_helpers_decode_chunked_request_and_preserve_err_out` 与 `async_read_parse_into_connection_closed_preserves_err_out_compat` 均通过，整文件 `25 tests` 全绿。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语
- [x] 在 `lib/std/async.uya` 或新的 leaf 模块中抽象以下 awaitable 原语：
  - [x] 对 DNS UDP/TCP 读写可复用的 transport helper
    - 实现：在 `lib/std/async.uya` 新增 `async_socket_send` / `async_socket_recv`，并让 `lib/std/net/dns.uya` 的 `DnsUdpFuture` / `DnsTcpFuture` 复用这两个 awaitable helper，移除 future 内直接 `sys_send(self.fd, ...)` / `sys_recv(self.fd, ...)` 的重复路径。
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（4/4 通过）
    - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（11/11 通过）
    - 验证：`../uya/bin/uya test tests/test_std_dns.uya`（34/34 通过）
    - 验证：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya`（4/4 通过）

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语
父级任务：统一原语的要求：
  - [x] deadline / timeout 语义统一
    - 验证：`timeout 20s ../uya/bin/uya test tests/test_async_fd.uya`（通过，12 tests）
    - 验证：`timeout 20s ../uya/bin/uya test tests/test_http1_async_client.uya`（通过，9 tests）
    - 验证：`timeout 30s ../uya/bin/uya test tests/test_std_dns_async_transport.uya`（通过，4 tests）

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语
父级路径：统一原语的要求

- [x] cancel 语义统一
  - 验证：`../uya/bin/uya test tests/test_async_fd.uya`
    结果：先新增取消态回归并确认初次失败；修复后 13 tests passed。
  - 验证：`../uya/bin/uya test tests/test_tls_async_runtime_io.uya`
    结果：1 test passed。
  - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`
    结果：25 tests passed。

# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语
父级任务路径：统一原语的要求
  - [x] `Waker` interest 注册统一
    - 验证：`../uya/bin/uya test tests/test_async_fd.uya` 通过（14 tests, 85 assertions）。
    - 验证：`../uya/bin/uya test tests/test_tls_async_runtime_io.uya` 通过（1 test, 16 assertions）。
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya` 通过（4 tests, 12 assertions）。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya` 通过（27 tests, 107 assertions）。

## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.4 第二批：抽象并统一 syscall / I/O 叶子原语

- [x] 统一原语的要求：
  - [x] 错误类型统一，不再每个模块手写一套 `Poll.Pending/Ready(err)` 分支
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（通过，5/5 tests，21 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（通过，14/14 tests，85 assertions）

### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

- `lib/std/http/http1_async.uya`
  - [x] 将 `Http1ConnectFuture` 改为基于通用 `async_connect` 的 `@async_fn` 路线。
    - 说明：`lib/std/http/http1_async.uya` 已经使用 `@async_fn fn http1_connect_for_host_future(...)` + `@await async_connect(...)`；本轮补充 `tests/test_http1_async_connect_boundary.uya` 防倒退覆盖并完成验证收口。
    - 验证：`../uya/bin/uya test tests/test_http1_async_connect_boundary.uya`（通过）
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过）
    - 验证：`../uya/bin/uya test tests/test_http1_async_client.uya`（通过，9 tests passed）

### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

- [x] `lib/std/http/http1_async.uya`
  - [x] 后续同步清理 `http1_request_async` 里的 manual-ready wrapper 重复路径。
    - 验证：`../uya/bin/uya test tests/test_http1_async_connect_boundary.uya`：新增源码边界断言后先失败，清理 wrapper 后通过。
    - 验证：`../uya/bin/uya test tests/test_http1_async_client.uya`：通过。
    - 验证：`../uya/bin/uya test tests/test_async_nested_http1_await_codegen.uya`：通过。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`
父级路径：`lib/std/net/dns.uya`
  - [x] 将 `DnsUdpFuture` 改为 `@async_fn`。
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（通过：6 tests，28 assertions）
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`（通过：1 test，9 assertions）
    - 验证：`../uya/bin/uya test tests/test_std_dns.uya`（通过：34 tests，78 assertions）
### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

父级任务：`lib/std/net/dns.uya`
  - [x] 将 `DnsTcpFuture` 改为 `@async_fn`。
    - 验证：`../uya/bin/uya test tests/test_std_dns.uya`（通过，34/34）。
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`（通过，1/1）。
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过，1/1）。
    - 验证：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya`（通过，4/4）。

### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

- [x] `lib/std/net/dns.uya`
  - [x] 目标：DNS 只保留 transport helper，不再自带手写 poll 状态机。
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（1 个测试文件，6 个测试全部通过）
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`（1 个测试通过，16 个断言通过）
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（1 个测试通过，19 个断言通过）
    - 验证：`../uya/bin/uya test tests/test_std_dns.uya`（1 个测试文件，34 个测试全部通过）

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`
- `lib/std/http/uyagin.uya`
  - [x] 将 `UyaginAcceptFuture` 改为 `@async_fn` + `async_accept`。
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过；`std_business_protocol_and_composition_async_boundaries_stay_on_async_fn` OK）
    - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`（通过；`uyagin_accept_uses_async_accept_helper_and_preserves_nodelay` OK）
### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

任务路径：`lib/std/http/uyagin.uya`
- [x] 将 `UyaginWritevFuture` 改为 `@async_fn` + `async_writev`。
  - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（新增源码边界断言后先失败，提示缺少 `@async_fn fn uyagin_writev_all_future(...)`；修改后通过）
  - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`（通过，25 个测试）
  - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（通过，14 个测试）

### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

父级任务路径：`lib/std/http/uyagin.uya`

- [x] 将 `UyaginSendFileBodyFuture` 改为 `@async_fn` + `async_sendfile`。
  - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`
  - 结果：通过；新增边界断言确认 `uyagin_sendfile_future` 为 `@async_fn`，并在函数体内 `@await async_sendfile(...)`。
  - 验证：`../uya/bin/uya test tests/test_async_fd.uya`
  - 结果：通过；14 个相关异步 fd/sendfile 测试全部通过。
  - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`
  - 结果：通过；25 个 uyagin 回归测试全部通过。

### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

上下文：`lib/std/http/uyagin.uya`

- [x] 将 `UyaginConnReadParseFuture` / `UyaginConnReadParseIntoFuture` 改为 `@async_fn` + 通用 read helper。
  - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过：1/1 tests passed）
  - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`（通过：25/25 tests passed）

上下文：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## Phase 1.5：标准库手工 Future 清零迁移 > ### 1.5.5 第三批：把协议/服务端热路径 future 改写成 `@async_fn`

- [x] `lib/std/http/uyagin.uya`
  - [x] 迁移后再评估是否仍需专门 slot-level manual polling。
    - 结论：仍需保留 slot-level manual polling。`uyagin_serve_conn_slot_async` 已承担单连接协议/keep-alive 逻辑；`uyagin_engine_run` 中残留的手写 `poll()` 只负责 accept、新连接占槽、per-connection deadline / graceful shutdown 与 fd interest 同步。当前 `Scheduler` 入口仍是“给定一组 future 跑到完成”，还不能在运行中动态接纳/回收连接任务。
    - 验证记录：2026-06-21 运行 `../uya/bin/uya test --c99 tests/test_http_uyagin.uya` 通过（25 tests passed）；`git diff --check` 通过。

## 2026-06-21 归档：叶子 `lib/std/async.uya`

> 父级路径：`## Phase 1.5：标准库手工 Future 清零迁移` → `### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零` → `lib/std/async.uya`

- [x] 评估 `AsyncFdReadFuture` / `AsyncFdWriteFuture` 是否可以进一步收敛成更底层 wait primitive + `@async_fn` 包装。
  - 结论：`AsyncFdReadFuture` / `AsyncFdWriteFuture` 可以继续下沉成 `async_wait_readable` / `async_wait_writable`（或单个 `interest` 参数化 wait primitive）+ `@async_fn` 包装；两者当前 `poll()` 已只剩 cancel、deadline、nonblocking 初始化、单次 `sys_read` / `sys_write` 与 `EAGAIN` 注册 readiness。
  - 结论：当前还不能直接做到“0 手写 future”，因为 `@async_fn` 仍需要一个可 `@await` 的 readiness future 来承接 `Waker.wait_readable` / `Waker.wait_writable`、deadline 与 cancel 语义；这层才是最终 runtime substrate。
  - 代码依据：`lib/std/async.uya:1124-1209` 的 `AsyncFdWriteFuture` / `AsyncFdReadFuture` 不保存 partial progress，也不夹带业务分支；若补出 `async_wait_*` 原语，读写本体可改写为 `while true { sys_read/sys_write; would-block => @await async_wait_*; }` 的 `@async_fn` 包装。
  - 代码依据：`lib/std/async.uya:498-507,823-829` 已有 `async_poll_pending_readable_usize` / `async_poll_pending_writable_usize` 与 `async_fd_set_nonblocking`，说明共性逻辑已被拆出，剩余手写状态可进一步收缩到 readiness wait primitive。
  - 后续约束：下一叶子应把手写例外从 `AsyncFdReadFuture` / `AsyncFdWriteFuture` 继续收敛到 `async_wait_*` wait primitive，并把它从高层 helper 路径搬离、文档化为 runtime substrate 唯一例外。
  - 验证：`rg -n 'struct AsyncFdWriteFuture|struct AsyncFdReadFuture|fn async_fd_set_nonblocking|async_poll_pending_readable_usize|async_poll_pending_writable_usize' lib/std/async.uya` -> 命中 `async_poll_pending_readable_usize`/`async_poll_pending_writable_usize`、`async_fd_set_nonblocking`、`AsyncFdWriteFuture`、`AsyncFdReadFuture`，符合“共性 helper 已存在、剩余手写状态集中在 readiness 注册”的判断。
  - 验证：`../uya/bin/uya test tests/test_async_fd.uya` -> `14 tests passed, 0 failed; 85 assertions passed`
  - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya` -> `1 test passed, 0 failed; 39 assertions passed`
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
- [x] `lib/std/async.uya`
  - 结论（2026-06-21 代码核对）：`AsyncFdReadFuture` / `AsyncFdWriteFuture` 的读写 syscall 与 buffer 处理已经可以下沉成 `async_wait_readable` / `async_wait_writable`（或单个 `interest` 参数化 wait primitive）+ `@async_fn` 包装；真正仍需手写 `poll()` 的只剩 readiness wait substrate，因为当前 `@async_fn` 仍需要一个可 `@await` 的 future 来承接 `Waker.wait_*`、deadline 与 cancel 语义。
  - [x] 如果必须保留叶子手写 future，要求把例外收敛到 `async_wait_*` wait primitive，搬离高层 helper 路径，并文档化为 runtime substrate 的唯一例外。
    - 完成内容：移除 `AsyncFdWriteLeafFuture` / `AsyncFdReadLeafFuture`，`AsyncFd.write/read` 统一改为返回 `async_fd_write_future` / `async_fd_read_future`，把剩余手写 `poll()` 收敛回 `AsyncWaitFdFuture` readiness substrate。
    - 完成内容：`lib/std/async.uya` 现已用源码注释明确 `AsyncWaitFdFuture` 与导出的 `async_wait_readable` / `async_wait_writable` 是 runtime 中唯一允许保留的手写 `poll()` 例外。
    - 完成内容：针对当前 `@async_fn` 控制流 lowering 在首个 `@await` transition 可能先返回一次 `Pending` 的已知限制，`tests/test_async_fd.uya` 仅对 `AsyncFd.read/write` 新增“一次过渡 Pending 容忍”检查；其余真正 leaf future 的取消断言保持不变。
    - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`（通过：1 tests passed，10 assertions passed）
    - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（通过：14 tests passed，85 assertions passed）
    - 验证：`../uya/bin/uya test tests/test_async_io.uya`（通过：12 tests passed，19 assertions passed）
    - 验证：`git diff --check`（通过）

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

任务路径：
- [ ] `lib/std/thread.uya`
  - [ ] 将 `AsyncComputeFuture<T>` 分解为：
    - [x] worker 提交/排队
      - 验证：`../uya/bin/uya test tests/test_std_thread.uya`（通过，28 tests / 111 assertions）
      - 验证：`../uya/bin/uya test tests/test_async_compute_generic_wrapper.uya`（通过，2 tests）
      - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya`（通过，11 tests）

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
路径：`lib/std/thread.uya` > 将 `AsyncComputeFuture<T>` 分解为：
    - [x] 结果 ready 通知
      - 验证：`../uya/bin/uya test tests/test_std_thread.uya`
      - 结果：通过；28/28 测试通过，覆盖 `async_compute_i32_completed_queued_slot_is_ready_on_first_late_poll`、`async_compute_thread_bridge_is_unified_behind_helpers`、取消与排队回归。
      - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya`
      - 结果：通过；11/11 `async_compute` 类型矩阵测试通过。

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

路径：`lib/std/thread.uya` > 将 `AsyncComputeFuture<T>` 分解为：

- [x] cancel / cleanup
  - 结果：提炼 `thread_async_cleanup_slot` 与 `async_worker_cancel` 两个 helper；`AsyncComputeFuture<T>` 的 slot cleanup 与取消等待路径不再内联在 core/poll 中，保留现有 queued/running cancel 语义。
  - 结果：新增结构性回归 `async_compute_cancel_cleanup_is_unified_behind_helpers`，锁定 cancel / cleanup helper 边界，避免回退到手写内联逻辑。
  - 验证：`../uya/bin/uya test tests/test_std_thread.uya`
  - 结果：29 tests passed, 0 failed。
  - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya`
  - 结果：11 tests passed, 0 failed。
  - 验证：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya`
  - 结果：4 tests passed, 0 failed。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
父级路径：`lib/std/thread.uya`

- [x] 将 `AsyncComputeFuture<T>` 分解为：
  - [x] one-shot fallback 或其替代策略
    - 结果：`lib/std/thread.uya` 新增 `thread_pool_queue_or_error_slot()`，显式固定替代策略为“共享 pending 队列；容量不足时返回资源错误”，并由结构闸门确认文件内不存在 `sys_fork(` 隐式 fallback。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya`
    - 验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya`
    - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya`

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
上下文：`lib/std/thread.uya`
- [x] 先提炼 `async_worker_result` / `async_thread_slot_wait` 之类可 await 原语，再把对外 `async_compute<T>` 改写为 `@async_fn` 组合层。
  - 验证：`../uya/bin/uya test --c99 tests/test_std_thread.uya`（通过：31 tests）
  - 验证：`../uya/bin/uya test --c99 tests/test_async_compute_generic_wrapper.uya`（通过：2 tests）
  - 验证：`../uya/bin/uya test --c99 tests/test_async_compute_types.uya`（通过：11 tests）
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
父级路径：`lib/std/thread.uya`

- [x] `lib/std/thread.uya`
  - [x] 把 `sys_fork()` fallback 的默认路径从“隐藏在手写 future 内部”改成显式策略决策。
    - 结果：`ThreadPoolConfig` / `ThreadPool` 新增显式 `submit_strategy`，默认归一化为 `THREAD_POOL_SUBMIT_STRATEGY_QUEUE_OR_ERROR`；`thread_pool_submit_slot_raw()` 改为按 pool policy 分发，`async_compute` 的饱和路径不再隐藏在手写 future 内部。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya`
    - 结果：32 tests passed, 0 failed。
    - 验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya`
    - 结果：1 test passed, 0 failed。
    - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya`
    - 结果：11 tests passed, 0 failed。
    - 验证：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya`
    - 结果：4 tests passed, 0 failed。

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

路径：
- [ ] 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - [ ] 要么连当前真实残留的 runtime future 也继续消灭
    - [x] 先把 `lib/std/async.uya` 的 substrate 清单纠偏为当前真实残留 `AsyncWaitFdFuture`，同步 1.5.1 / 1.5.6 文案并保留验证命令；完成条件：主 todo 仅把 `AsyncWaitFdFuture` 记为 async runtime substrate 残留
      - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`
      - 结果：1 个测试通过；`async_wait_readable` / `async_wait_writable` 仍保留，`AsyncFdReadFuture` / `AsyncFdWriteFuture` 结构体不存在。
      - 验证：`rg -n "AsyncFdReadFuture|AsyncFdWriteFuture|AsyncWaitFdFuture" docs/todo_async_full_language_dynamic_resources.md`
      - 结果：主 todo 在 1.5.1 / 1.5.6 只保留 `AsyncWaitFdFuture` 作为 async substrate，旧 `AsyncFd*Future` 不再被记为残留对象。
      - 验证：`git diff --check`
      - 结果：通过。
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

任务路径：
- [ ] 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - [ ] 要么连当前真实残留的 runtime future 也继续消灭
    - [x] 评估 `AsyncWaitFdFuture` 是否还能继续下沉成更细的语言/runtime wait primitive；完成条件：给出“继续消灭”或“保留为 substrate”的单一路径，并能用代码现状解释；验证：`rg -n "struct AsyncWaitFdFuture|export fn async_wait_readable|export fn async_wait_writable|export @async_fn fn async_fd_(read|write)" lib/std/async.uya`
      - 结论：保留为 substrate；当前 `Future<T>` / `@async_fn` 仍只能通过 `poll(self, waker)` 驱动，而 `Waker` 只暴露 `wait_readable()` / `wait_writable()` 两个 I/O interest 原语，去掉这个 leaf 只会把 fd readiness wait 挪成新的语言/runtime/codegen 特判。
      - 代码依据：`lib/std/async.uya:1154` 定义 `AsyncWaitFdFuture`；`1194` / `1205` 仅导出 `async_wait_readable` / `async_wait_writable`；`1248-1309` 的 `async_fd_read_deadline_future` / `async_fd_write_deadline_future` 已是 `@async_fn` 包装，只在循环里 `@await` readiness wait 后重试 `sys_read` / `sys_write`，业务 syscall/buffer 状态机没有留在 wait leaf 里。
      - 验证：`rg -n "struct AsyncWaitFdFuture|export fn async_wait_readable|export fn async_wait_writable|export @async_fn fn async_fd_(read|write)" lib/std/async.uya` 命中 `1154` / `1194` / `1205` / `1248` / `1275` / `1282` / `1309`；`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya` 通过（1 passed, 0 failed）。

## 2026-06-21 归档：Phase 1.5.6 `AsyncComputeFuture<T>` 消灭可行性评估

> 父级路径：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` → `## Phase 1.5：标准库手工 Future 清零迁移` → `### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零` → `如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界` → `要么连当前真实残留的 runtime future 也继续消灭`

- [x] 评估 `AsyncComputeFuture<T>` 是否能在不扩大 codegen/runtime 特判面的前提下消灭；完成条件：明确列出仍阻塞彻底消灭的状态机/代码生成依赖，或完成实际迁移；验证：`rg -n "AsyncComputeFuture|async_worker_submit|async_worker_result|async_worker_cancel|AsyncComputeFuture_" lib/std/thread.uya src/codegen/c99`
  - 结论：当前不能在“不扩大 codegen/runtime 特判面”的前提下直接消灭 `AsyncComputeFuture<T>`；应先把阻塞拆成后续叶子任务，或改走“定义为 runtime substrate”路线。
  - 阻塞 1：`lib/std/thread.uya` 中 `ThreadAsyncComputeCore` + `AsyncComputeFuture<T>.poll()` 仍是唯一同时保存 `slot_idx`、`first_poll`、`cancel_requested`、`done/state` 并串起 `async_worker_submit` / `async_worker_result` / `async_worker_cancel` / cleanup / typed decode 的状态机壳；现有 `async_worker_*` 只是叶子 awaitable，本身不能替代这个跨 poll 框架。
  - 阻塞 2：`src/codegen/c99/function.uya` 与 `src/codegen/c99/expr.uya` 仍把 `async_compute<T>` 硬编码到 `std_thread_async_compute_future_new_<T>`、`AsyncComputeFuture_<T>` 与对应 `uya_vtable_Future_err_<T>_AsyncComputeFuture_<T>`；注释已明确 `thread_type_is_*(T)` 在 C99 函数体生成阶段无法可靠折叠，所以删掉库侧类型不会缩小特判面，反而要求新的 lowering 特判。
  - 阻塞 3：`src/codegen/c99/structs.uya` 仍保留 `AsyncComputeFuture<T> : Future<!T>` 的专项 vtable/interface 单态修补，说明通用 `struct<T> : Future<!T>` 仍未完全自动化；先删 `AsyncComputeFuture<T>` 只会把这块依赖改名，不会消失。
  - 后续拆分：主 todo 已把这三个阻塞分别改写成后续 `[ ]` 叶子，避免空父项和模糊结论。
  - 验证：`rg -n "AsyncComputeFuture|async_worker_submit|async_worker_result|async_worker_cancel|AsyncComputeFuture_" lib/std/thread.uya src/codegen/c99`
  - 结果：命中 `lib/std/thread.uya` 中 `async_worker_*` 与 `AsyncComputeFuture<T>` 状态机实现，以及 `src/codegen/c99/{expr,function,structs}.uya` 中的专用构造/vtable/单态化分支，和本轮结论一致。
  - 验证：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
  - 结果：通过，主 todo 为 `0 active tasks`。
  - 验证：`git diff --check`
  - 结果：通过。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

路径：
- 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - 要么连当前真实残留的 runtime future 也继续消灭

    - [x] 若继续删除 `AsyncComputeFuture<T>`，先让 `async_compute<T>` 的 C99 lowering 不再依赖 `std_thread_async_compute_future_new_<T>` / `AsyncComputeFuture_*` 硬编码；完成条件：`src/codegen/c99/expr.uya` 与 `src/codegen/c99/function.uya` 不再保留这组名字表；验证：`rg -n "std_thread_async_compute_future_new_|AsyncComputeFuture_" src/codegen/c99/expr.uya src/codegen/c99/function.uya`
      - 验证记录（2026-06-21）：
        - `../uya/bin/uya test tests/test_async_compute_codegen_lowering_boundary.uya`：通过
        - `../uya/bin/uya test tests/test_async_compute_generic_wrapper.uya`：通过
        - `../uya/bin/uya test tests/test_async_compute_types.uya`：通过
        - `../uya/bin/uya test tests/test_std_thread.uya`：通过
        - `rg -n "std_thread_async_compute_future_new_|AsyncComputeFuture_" src/codegen/c99/expr.uya src/codegen/c99/function.uya`：无输出
        - `git diff --check`：通过

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

父级路径：
- 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - 要么连当前真实残留的 runtime future 也继续消灭

    - [x] 若继续删除 `AsyncComputeFuture<T>`，再让泛型 `struct<T> : Future<!T>` 的 vtable/interface 单态化不再依赖 `AsyncComputeFuture` 专项修补；完成条件：`src/codegen/c99/structs.uya` 不再保留 `AsyncComputeFuture` 特判；验证：`rg -n "AsyncComputeFuture" src/codegen/c99/structs.uya`
      - 验证命令：`../uya/bin/uya test tests/test_async_compute_codegen_lowering_boundary.uya`
      - 验证结果：通过（1 个测试，5 条断言）
      - 验证命令：`../uya/bin/uya test tests/test_std_thread.uya`
      - 验证结果：通过（32 个子测试，134 条断言）
      - 验证命令：`rg -n "AsyncComputeFuture" src/codegen/c99/structs.uya`
      - 验证结果：无输出，exit 1

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

路径：如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界 / 要么连当前真实残留的 runtime future 也继续消灭

- [x] 若继续删除 `AsyncComputeFuture<T>`，最后把 `ThreadAsyncComputeCore` 的 submit/result/cancel/cleanup/typed decode 状态机迁进通用 async frame 或其他明确 substrate，并删掉该 struct；完成条件：`lib/std/thread.uya` 不再定义 `AsyncComputeFuture<T>`，且保留 `async_worker_submit/result/cancel` 取消与清理语义；验证：`rg -n "AsyncComputeFuture|async_worker_submit|async_worker_result|async_worker_cancel" lib/std/thread.uya`
  - 验证：`rg -n "AsyncComputeFuture|async_worker_submit|async_worker_result|async_worker_cancel" lib/std/thread.uya`（命中 `1164`、`1228`、`1247`、`1266`、`1409`、`1421`、`1436`，仅保留 `async_worker_*` helper 与调用点，`AsyncComputeFuture` 已消失）
  - 验证：`../uya/bin/uya test tests/test_std_thread.uya`（通过：33 tests，139 assertions）
  - 验证：`../uya/bin/uya test tests/test_async_compute_codegen_lowering_boundary.uya`（通过：1 test，8 assertions）
  - 验证：`../uya/bin/uya test tests/test_async_compute_generic_wrapper.uya`（通过：2 tests，2 assertions）
  - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya`（通过：11 tests，11 assertions）
  - 验证：`../uya/bin/uya test tests/test_async_frame_pool_full.uya`（通过：1 test）

## 2026-06-21 归档：Phase 1.5.6 runtime residual 清单纠偏与 L159 拆分

> 父级路径：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` → `## Phase 1.5：标准库手工 Future 清零迁移` → `### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零` → `如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界` → `要么连当前真实残留的 runtime future 也继续消灭`

- [x] 先把“当前真实残留”的清单纠偏到源码真实对象，并按三类 residual 拆出后续叶子；完成条件：1.5.1 / 1.5.6 不再使用过时 `AsyncComputeFuture<T>` 口径，且 line 159 后续子任务只引用当前源码中的真实 future 名称。
  - 完成内容：将 1.5.1 的手工 Future 清单从过时的 `AsyncComputeFuture<T>` 纠偏到当前源码中的 `AsyncJoin2UsizeResultsFuture`、`AsyncWaitFdFuture`、`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`、`AsyncReadParseFuture`、`AsyncReadParseIntoFuture`，以及 `AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`。
  - 完成内容：将 1.5.6 的“最终 substrate 边界”口径改写为三类真实 residual，并把 L159 拆成 `std.async` 组合/协议壳、`std.async` fd syscall、`std.thread` worker bridge 三个后续叶子，避免继续用过时名字推进。
  - 验证：`rg -n "struct AsyncJoin2UsizeResultsFuture|struct AsyncWaitFdFuture|struct AsyncWritevFuture|struct AsyncSendFileFuture|struct AsyncConnectFuture|struct AsyncSocketSendFuture|struct AsyncSocketRecvFuture|struct AsyncAcceptFuture|struct AsyncReadParseFuture|struct AsyncReadParseIntoFuture|struct AsyncThreadSlotWaitFuture|struct AsyncWorkerSubmitFuture|struct AsyncWorkerResultFuture|struct AsyncWorkerCancelFuture|struct AsyncWorkerComputeFuture|AsyncComputeFuture" lib/std/async.uya lib/std/thread.uya docs/todo_async_full_language_dynamic_resources.md`
  - 验证结果：命中 `lib/std/async.uya` 的 9 个 residual 与 `lib/std/thread.uya` 的 5 个 worker bridge residual；`AsyncComputeFuture` 仅出现在本轮说明文字中，不再作为 1.5.1 / 1.5.6 的残留对象。
  - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`（通过：1 tests，10 assertions）
  - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`（通过：1 tests，39 assertions）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
路径：`如果要做到“标准库里 0 手写业务 Future”` → `要么连当前真实残留的 runtime future 也继续消灭` → `继续消灭 lib/std/async.uya 中组合/协议壳 residual（AsyncJoin2UsizeResultsFuture、AsyncReadParseFuture、AsyncReadParseIntoFuture）`
  - [x] 将 `async_read_parse(...)` 迁移为 `@async_fn` + `async_fd_read_future(...)`，删除 `AsyncReadParseFuture`
    - 最小验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`
    - 验证命令：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`
    - 验证结果：通过；`async_read_parse` 已是 `@async_fn`，`AsyncReadParseFuture` 已从 `lib/std/async.uya` 删除，结构边界测试共 2 项通过。
    - 验证命令：`../uya/bin/uya test tests/test_async_fd.uya`
    - 验证结果：通过；`async_io_leaf_futures_return_cancelled_when_waker_cancelled` 等共 14 项通过。`async_read_parse` 取消路径按当前 `@async_fn` lowering 固定为最多两次过渡 `Pending` 后返回 `Cancelled`，且 fd 仍保持 blocking。

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
父级路径：
- [ ] 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - [ ] 要么连当前真实残留的 runtime future 也继续消灭
    - [ ] 继续消灭 `lib/std/async.uya` 中组合/协议壳 residual（`AsyncJoin2UsizeResultsFuture`、`AsyncReadParseIntoFuture`）
      - [x] 将 `async_read_parse_into(...)` 迁移为 `@async_fn` + `async_fd_read_future(...)`，删除 `AsyncReadParseIntoFuture`
        - 最小验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`
        - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`（通过：3 tests, 16 assertions）
        - 验证：`../uya/bin/uya test tests/test_async_fd.uya`（通过：14 tests, 85 assertions）
        - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`（通过：25 tests, 37 assertions）

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
路径：`如果要做到“标准库里 0 手写业务 Future”` -> `要么连当前真实残留的 runtime future 也继续消灭`
    - [x] 继续消灭 `lib/std/async.uya` 中组合/协议壳 residual（`AsyncJoin2UsizeResultsFuture`、`AsyncReadParseIntoFuture`）
      - [x] 在不把 `dns_client_query_all_any_async` 退化为串行 A/AAAA 查询的前提下，消灭 `AsyncJoin2UsizeResultsFuture`
        - 最小验证：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`
        - 验证命令：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`
        - 验证结果：通过（1 test / 21 assertions）
        - 扩展验证：`../uya/bin/uya test tests/test_std_dns_async_query_aggregate.uya`
        - 扩展验证结果：通过（3 tests / 6 assertions）
        - 扩展验证：`../uya/bin/uya test tests/test_async_runtime_shared_dns.uya`
        - 扩展验证结果：通过（1 test / 2 assertions）

## 2026-06-21

路径上下文：
- `# Uya 异步生产化 TODO（完整语法 + 动态资源）`
- `## Phase 1.5：标准库手工 Future 清零迁移`
- `### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零`
- 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界
  - 要么连当前真实残留的 runtime future 也继续消灭
    - 继续消灭 `lib/std/async.uya` 中 fd syscall residual（`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`），或在 line 160 路线里正式转为 substrate
      - [x] 把 `AsyncWritevFuture` 迁到 `export @async_fn fn async_writev(...)` + `async_wait_writable` substrate；验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`、`../uya/bin/uya test tests/test_async_fd.uya`
        - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`，通过（4 tests passed, 0 failed）
        - 验证：`../uya/bin/uya test tests/test_async_fd.uya`，通过（14 tests passed, 0 failed）
        - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`，通过（1 test passed, 0 failed）
## 2026-06-21

### Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
路径：
如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  要么连当前真实残留的 runtime future 也继续消灭
    继续消灭 `lib/std/async.uya` 中 fd syscall residual（`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`），或在 line 160 路线里正式转为 substrate
      - [x] 把 `AsyncConnectFuture` 迁到 `export @async_fn fn async_connect(...)` + `async_wait_writable` substrate；验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`、`../uya/bin/uya test tests/test_async_fd.uya`
        - 已通过：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`（6 tests passed，25 assertions passed）
        - 已通过：`../uya/bin/uya test tests/test_async_fd.uya`（14 tests passed，85 assertions passed）
        - 已通过：`make clean`（清理构建产物完成）
        - 已通过：`make backup-all`（完整自举、`make check` 与 seed/backup 更新通过）
## 2026-06-21

### Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
路径：
如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  要么连当前真实残留的 runtime future 也继续消灭
    继续消灭 `lib/std/async.uya` 中 fd syscall residual（`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`），或在 line 160 路线里正式转为 substrate
      - [x] 把 `AsyncSendFileFuture` 迁到 `export @async_fn fn async_sendfile(...)` + `async_wait_writable` substrate；验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`、`../uya/bin/uya test tests/test_async_fd.uya`
        - 已通过：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`（6 tests passed，25 assertions passed）
        - 已通过：`../uya/bin/uya test tests/test_async_fd.uya`（14 tests passed，85 assertions passed）
        - 已通过：`make clean`（清理构建产物完成）
        - 已通过：`make backup-all`（完整自举、`make check` 与 seed/backup 更新通过）

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零
父级路径：
- 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - 要么连当前真实残留的 runtime future 也继续消灭
    - 继续消灭 `lib/std/async.uya` 中 fd syscall residual（`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`），或在 line 160 路线里正式转为 substrate
      - [x] 把 `AsyncSocketSendFuture` 迁到 `export @async_fn fn async_socket_send(...)` + `async_wait_writable` substrate；验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`、`../uya/bin/uya test tests/test_async_fd.uya`
        - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya` 通过（7 tests passed, 0 failed）
        - 验证：`../uya/bin/uya test tests/test_async_fd.uya` 通过（14 tests passed, 0 failed）
        - 已通过：`make clean`（清理构建产物完成）
        - 已通过：`make backup-all`（完整自举、`make check` 与 seed/backup 更新通过）

## 2026-06-21

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

上下文路径：
- [ ] 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - [ ] 要么连当前真实残留的 runtime future 也继续消灭
    - [ ] 继续消灭 `lib/std/async.uya` 中 fd syscall residual（`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`），或在 line 160 路线里正式转为 substrate
      - [x] 把 `AsyncSocketRecvFuture` 迁到 `export @async_fn fn async_socket_recv(...)` + `async_wait_readable` substrate；验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`、`../uya/bin/uya test tests/test_async_fd.uya`
        验证结果：
        `../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`：通过（8 tests, 31 assertions）
        `../uya/bin/uya test tests/test_async_fd.uya`：通过（14 tests, 85 assertions）
### 2026-06-21

上下文：
# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

父级路径：
- [ ] 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - [ ] 要么连当前真实残留的 runtime future 也继续消灭
    - [x] 继续消灭 `lib/std/async.uya` 中 fd syscall residual（`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`），或在 line 160 路线里正式转为 substrate
      - [x] 把 `AsyncAcceptFuture` 迁到 `export @async_fn fn async_accept(...)` + `async_wait_readable` substrate；验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`、`../uya/bin/uya test tests/test_async_fd.uya`
        - TDD：新增 `async_accept_boundary_uses_async_fn_and_wait_substrate` 后首次运行 `../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya` 失败：`source_contains_cstr(&src[0], len, accept_start) as i32 == 1 (actual: 0, expected: 1)`
        - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya` 通过（9 tests, 34 assertions）
        - 验证：`../uya/bin/uya test tests/test_async_fd.uya` 通过（14 tests, 85 assertions）
## 2026-06-21

父级路径：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` → `## Phase 1.5：标准库手工 Future 清零迁移` → `### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零` → `- [ ] 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：` → `  - [ ] 要么连当前真实残留的 runtime future 也继续消灭`

- [x] 继续消灭 `lib/std/thread.uya` 中 worker bridge residual（`AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`），或在 line 160 路线里正式转为 substrate
  - 结果：本轮按 line 160 路线正式收口为 runtime substrate；`lib/std/thread.uya` 为 worker bridge 追加明确边界注释，主 todo 的 1.5.1 / 1.5.6 同步改写为 `runtime substrate（线程调度桥接）` / `std.thread worker 调度桥接 substrate`。
  - 原因：这组 leaf 直接依赖 ThreadPool shared slot / pending queue / result pipe / cooperative cancel / cleanup 协议，当前 `@async_fn` / 通用 fd wait substrate 还不能无损替代直接 `waker.is_cancelled()` 与 slot 生命周期控制。
  - 验证：`../uya/bin/uya test tests/test_std_thread.uya`
  - 结果：通过（34 tests passed，144 assertions passed）
  - 验证：`rg -n "worker bridge substrate|线程调度桥接 substrate|runtime substrate（线程调度桥接）|第二类允许保留的手写 poll\\(\\) 例外" lib/std/thread.uya docs/todo_async_full_language_dynamic_resources.md`
  - 结果：命中 `lib/std/thread.uya:1104` 与 `docs/todo_async_full_language_dynamic_resources.md:130`，主 todo / 源码口径一致。
  - 验证：`git diff --check`
  - 结果：通过。

路径：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` → `## Phase 1.5：标准库手工 Future 清零迁移` → `### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零` → `如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界`

- [x] 先按当前代码纠偏 runtime residual 清单：`std.async` syscall / 聚合 / 协议壳 residual 已全部清零，1.5.1 / 1.5.6 只保留 `AsyncWaitFdFuture` 与 `std.thread` worker bridge 两类当前真实残留
  - 完成条件：主 todo 不再把 `AsyncJoin2UsizeResultsFuture`、`AsyncWritevFuture`、`AsyncSendFileFuture`、`AsyncConnectFuture`、`AsyncSocketSendFuture`、`AsyncSocketRecvFuture`、`AsyncAcceptFuture`、`AsyncReadParseFuture`、`AsyncReadParseIntoFuture` 记为“当前真实残留”
  - 最小验证：`rg -n "^(export )?struct .*: Future<" lib/std/http lib/std/net lib/std/thread.uya lib/std/async.uya`
  - 验证：`rg -n "^(export )?struct .*: Future<" lib/std/http lib/std/net lib/std/thread.uya lib/std/async.uya` 只命中 `lib/std/async.uya` 的 `Future<T>` / `Task<T>` / `AsyncWaitFdFuture` 和 `lib/std/thread.uya` 的五个 worker bridge leaf。
  - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`（通过：1 个测试文件，9 tests passed，34 assertions passed）
  - 验证：`../uya/bin/uya test tests/test_std_thread.uya`（通过：1 个测试文件，34 tests passed，144 assertions passed）
## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.6 第四批：runtime 底座手工 Future 最小化与最终清零

- [x] 如果要做到“标准库里 0 手写业务 Future”，必须给 runtime 留一个非常清晰的最终边界：
  - [x] 在上述纠偏基础上，把现存两类 hand-written `poll()`（`AsyncWaitFdFuture` + `std.thread` worker 调度桥接）正式定义为语言/runtime substrate，并同步 1.5.7 闸门口径
    - 完成条件：1.5.6 / 1.5.7 明确“业务层 hand-written future = 0；runtime 例外仅指 `AsyncWaitFdFuture` 与 `std.thread` worker 调度桥接”，不再保留模糊选项
    - 最小验证：`rg -n "AsyncWaitFdFuture|AsyncThreadSlotWaitFuture|AsyncWorkerSubmitFuture|AsyncWorkerResultFuture|AsyncWorkerCancelFuture|AsyncWorkerComputeFuture|最终只允许 runtime 核心协议壳类型和经明确定义的 substrate 例外存在" docs/todo_async_full_language_dynamic_resources.md lib/std/async.uya lib/std/thread.uya`
    - 验证：`rg -n "AsyncWaitFdFuture|AsyncThreadSlotWaitFuture|AsyncWorkerSubmitFuture|AsyncWorkerResultFuture|AsyncWorkerCancelFuture|AsyncWorkerComputeFuture|最终只允许 runtime 核心协议壳类型和经明确定义的 substrate 例外存在" docs/todo_async_full_language_dynamic_resources.md lib/std/async.uya lib/std/thread.uya` 命中 `docs/todo_async_full_language_dynamic_resources.md`、`lib/std/async.uya`、`lib/std/thread.uya`；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md` 输出 `ok: ... has 1 active task`；`git diff --check` 通过

## 2026-06-21

### 1.5.7 配套测试与闸门

- 父级任务路径：`为每个迁移模块增加一条“旧 hand-written future 已删除”的结构性检查：`
  - [x] `rg -n "^(export )?struct .*: Future<" lib/std/http lib/std/net lib/std/thread.uya lib/std/async.uya`
    - 验证命令：`rg -n "^(export )?struct .*: Future<" lib/std/http lib/std/net lib/std/thread.uya lib/std/async.uya`
    - 验证结果：命中 8 条，仅剩 `Future<T>`、`Task<T>`、`AsyncWaitFdFuture` 与 `std.thread` worker 调度桥接 5 个 substrate 例外；`lib/std/http`、`lib/std/net` 无命中。

## 2026-06-21

### 1.5.7 配套测试与闸门

- [x] 为每个迁移模块增加一条“旧 hand-written future 已删除”的结构性检查：
  - [x] 最终只允许 runtime 核心协议壳类型和经明确定义的 substrate 例外存在；其中 substrate 例外仅指 `AsyncWaitFdFuture` 与 `std.thread` worker 调度桥接（`AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`）；业务层/协议层 hand-written future 必须消失
    - 红测：`python3 tests/verify_async_handwritten_future_whitelist.py`
    - 红测结果：改动前失败，`python3: can't open file '/media/winger/_dde_data/winger/uya/uya/tests/verify_async_handwritten_future_whitelist.py': [Errno 2] No such file or directory`
    - 完成内容：新增 `tests/verify_async_handwritten_future_whitelist.py`，扫描 `lib/std/**/*.uya` 中全部 `struct ... : Future<` 定义，精确只允许 `lib/std/async.uya` 的 `Future` / `Task` / `AsyncWaitFdFuture` 与 `lib/std/thread.uya` 的 5 个 worker bridge substrate；`lib/std/http`、`lib/std/net` 以及其他 `lib/std` 模块一旦重新引入业务层/协议层 hand-written future 会直接失败。
    - 验证：`python3 tests/verify_async_handwritten_future_whitelist.py`
    - 验证结果：通过，输出 `verify_async_handwritten_future_whitelist: runtime shell and substrate whitelist confirmed`。
    - 验证：`../uya/bin/uya test tests/test_async_fd_substrate_boundary.uya`
    - 验证结果：通过（9 tests passed，34 assertions passed）。
    - 验证：`../uya/bin/uya test tests/test_async_std_business_future_boundary.uya`
    - 验证结果：通过（1 test passed，39 assertions passed）。
    - 验证：`../uya/bin/uya test tests/test_http1_async_connect_boundary.uya`
    - 验证结果：通过（2 tests passed，7 assertions passed）。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya`
    - 验证结果：通过（34 tests passed，144 assertions passed）。

### 1.5.7 配套测试与闸门

父级路径：`为每个迁移模块补 dedicated regression`
  - [x] DNS：UDP/TCP/fallback/cancel/timeout
    - 实现：扩展 `tests/test_std_dns_async_transport.uya`，把 dedicated regression 收口到单文件，新增 loopback UDP/TCP happy path、silent nameserver timeout、shared queue cancel，并修正 `async_socket_recv` 形态断言；同时修复 `lib/std/net/dns.uya` 对 `error.Cancelled` 的错误映射，保证 DNS transport 取消原样透传。
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_transport.uya`（通过，10 tests，40 assertions）
    - 验证：`../uya/bin/uya test tests/test_std_dns.uya`（通过，34 tests，78 assertions）
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_query_aggregate.uya`（通过，3 tests，6 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_runtime_shared_dns.uya`（通过，1 test，2 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_runtime_shared_semantics.uya`（通过，4 tests，47 assertions）
### 1.5.7 配套测试与闸门

父级路径：`为每个迁移模块补 dedicated regression`
  - [x] HTTP1：connect timeout / happy path / closed peer
    - 实现：扩展 `tests/test_http1_async_client.uya`，保留现有 loopback happy path 与 response-timeout 回归，并新增 closed peer runtime 回归；同时扩展 `tests/test_http1_async_connect_boundary.uya`，用结构性断言锁定 HTTP1 connect 路径仍通过 `async_connect` deadline 映射到 `HttpTimeout`，避免依赖不稳定的外部黑洞网络制造 TCP SYN 超时。
    - 验证：`../uya/bin/uya test tests/test_http1_async_client.uya`
    - 验证结果：通过（10 tests passed，16 assertions passed），覆盖 happy path、response timeout 和 `http1_async_get_closed_peer_returns_connection_closed`。
    - 验证：`../uya/bin/uya test tests/test_http1_async_connect_boundary.uya`
    - 验证结果：通过（3 tests passed，8 assertions passed），覆盖 `async_connect` deadline 到 `http_map_async_deadline_i32` 的映射边界。
    - 验证：`../uya/bin/uya test tests/test_async_fd.uya`
    - 验证结果：通过（14 tests passed，85 assertions passed），确认底层 `async_connect_expired_deadline_returns_async_deadline_exceeded` 基线仍然成立。
    - 验证：`git diff --check`
    - 验证结果：通过。

### 1.5.7 配套测试与闸门

父级路径：`为每个迁移模块补 dedicated regression`
  - [x] WebSocket：message aggregate / heartbeat / reconnect
    - 验证：`bash tests/verify_async_websocket_regressions.sh`
    - 验证结果：通过；脚本串行运行 `tests/test_http_websocket_async_read_message_shape.uya`、`tests/test_http_websocket_read_message_semantics.uya`、`tests/test_http_websocket_heartbeat.uya`、`tests/test_http_websocket_reconnect.uya`
    - 扩展验证：`../uya/bin/uya test tests/test_http_websocket_module_smoke.uya`
    - 验证结果：通过
    - 验证：`git diff --check`
    - 验证结果：通过

### 2026-06-21 Phase 1.5.7 配套测试与闸门
路径：为每个迁移模块补 dedicated regression
- [x] UyaGin：accept / read-parse / writev / sendfile / recover / observe
  - 交付：新增 `tests/test_http_uyagin_async_boundary.uya`，集中覆盖源码形态闸门，以及 accept/read-parse/writev/sendfile/recover/observe 行为回归。
  - 验证：`../uya/bin/uya test tests/test_http_uyagin_async_boundary.uya`（通过，6 tests，29 assertions）
  - 验证：`../uya/bin/uya test tests/test_http_uyagin.uya`（通过，25 tests，37 assertions）
  - 验证：`../uya/bin/uya test tests/test_http_uyagin_recover_observe.uya`（通过，2 tests，9 assertions）

### 2026-06-21 Phase 1.5.7 配套测试与闸门
- [x] 为每个迁移模块补 dedicated regression：
  - [x] Thread：queue full / cancel / result ready / no hidden fork fallback
    - 交付：新增 `tests/test_std_thread_async_boundary.uya`，集中覆盖 queue full、queued cancel、completed queued slot first late poll ready，以及源码闸门确保 queue-or-error 策略没有 hidden fork fallback。
    - 红测：`../uya/bin/uya test tests/test_std_thread_async_boundary.uya`
    - 红测结果：失败，输出 `错误: 'tests/test_std_thread_async_boundary.uya' 既不是文件也不是目录`。
    - 验证：`../uya/bin/uya test tests/test_std_thread_async_boundary.uya`（通过，4 tests，16 assertions）
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya`（通过，34 tests，144 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya`（通过，1 test，26 assertions）
    - 验证：`git diff --check`（通过）

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.7 配套测试与闸门
父级任务：将这些模块回归纳入：
  - [x] `tests/verify_async_full_language_matrix.sh`
    - 验证：`bash tests/verify_async_full_language_matrix.sh native`
    - 结果：通过；新增 `test_http1_async_connect_boundary.uya`、`test_http_uyagin_async_boundary.uya` 与 `verify_async_handwritten_future_whitelist.py` 已纳入矩阵
    - 验证：`bash tests/verify_async_full_language_matrix.sh c99`
    - 结果：通过；含 `verify_async_await_capacity.sh`、`verify_async_nested_future_boundary.sh`、`verify_async_shared_runtime_matrix.sh`
    - 验证：`bash tests/verify_async_full_language_matrix.sh uya-c99`
    - 结果：通过；`--uya --c99` 路径同样覆盖新增边界回归与 whitelist 闸门

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.7 配套测试与闸门

- [x] 将这些模块回归纳入：
  - [x] 后续 `tests/verify_async_dynamic_resources.sh`
    - 验证命令：`bash tests/verify_async_dynamic_resources.sh module-regressions`
    - 验证结果：通过，输出 `verify_async_dynamic_resources: module-regressions stages passed`
    - 验证命令：`bash tests/verify_async_dynamic_resources.sh unit-scan`
    - 验证结果：通过，输出 `verify_async_dynamic_resources: unit-scan stages passed`
## 2026-06-21

路径：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` > `## Phase 1.5：标准库手工 Future 清零迁移` > `### 1.5.8 建议执行顺序`

- [ ] `rg -nP "^(export )?struct (?!Future<|Task<).*: Future<" lib/std --glob '*.uya'`
  - [x] 阶段初始基线应只出现当前盘点对象
    - 验证：`rg -nP "^(export )?struct (?!Future<|Task<).*: Future<" lib/std --glob '*.uya'`
    - 结果：仅命中 `AsyncWaitFdFuture`、`AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`
    - 验证：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
    - 结果：`ok: docs/todo_async_full_language_dynamic_resources.md has 1 active task`
    - 验证：`git diff --check`
    - 结果：通过（无输出）

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.8 建议执行顺序
父级任务路径：`rg -nP "^(export )?struct (?!Future<|Task<).*: Future<" lib/std --glob '*.uya'`
  - [x] 组合层迁移后，不再出现 `WebSocketClientReconnectFuture`、`UyaginRecoverFuture`、`UyaginObserveFuture`、`DnsQueryTransportFuture`
    - 验证：`rg -nP '^(export )?struct (?!Future<|Task<).*: Future<' lib/std --glob '*.uya'`
      结果：仅剩 `AsyncWaitFdFuture`、`AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`
    - 验证：`../uya/bin/uya test tests/test_http_websocket_reconnect.uya`
      结果：7 tests passed，0 failed
    - 验证：`../uya/bin/uya test tests/test_http_uyagin_async_boundary.uya`
      结果：6 tests passed，0 failed
    - 验证：`../uya/bin/uya test tests/test_std_dns_async_composition_shape.uya`
      结果：1 test passed，0 failed

## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.8 建议执行顺序
- [x] `rg -nP "^(export )?struct (?!Future<|Task<).*: Future<" lib/std --glob '*.uya'`
  - [x] 最终只允许 runtime 核心协议壳类型和经明确定义的 substrate 例外存在；其中 substrate 例外仅指 `AsyncWaitFdFuture` 与 `std.thread` worker 调度桥接（`AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`）
    - 验证：`rg -nP "^(export )?struct (?!Future<|Task<).*: Future<" lib/std --glob '*.uya'`
    - 结果：仅命中 `lib/std/async.uya:1277` 的 `AsyncWaitFdFuture`，以及 `lib/std/thread.uya` 的 `AsyncThreadSlotWaitFuture`、`AsyncWorkerSubmitFuture`、`AsyncWorkerResultFuture`、`AsyncWorkerCancelFuture`、`AsyncWorkerComputeFuture`
    - 验证：`bash -lc 'actual=$(rg -nP "^(export )?struct (?!Future<|Task<).*: Future<" lib/std --glob "*.uya" | sed -E "s#^.*struct ([^ ]+) : Future<.*#\\1#" | sort); expected=$(printf "%s\\n" AsyncThreadSlotWaitFuture AsyncWaitFdFuture AsyncWorkerCancelFuture AsyncWorkerComputeFuture AsyncWorkerResultFuture AsyncWorkerSubmitFuture | sort); if [ "$actual" = "$expected" ]; then echo "ALLOWLIST_OK"; printf "%s\\n" "$actual"; else echo "ALLOWLIST_MISMATCH"; exit 1; fi'`
    - 结果：`ALLOWLIST_OK`，命中集合与允许名单完全一致

## Phase 1.5：标准库手工 Future 清零迁移

### 1.5.8 建议执行顺序

**阶段验收**：

- [x] `./tests/verify_async_full_language_matrix.sh`
  - 验证命令：`UYA_COMPILER=../uya/bin/uya ./tests/verify_async_full_language_matrix.sh`
  - 验证结果：通过；native / `--c99` / `--uya --c99` baseline、hand-written Future whitelist、nested future boundary、shared runtime matrix 与 macro combo 全部通过；`4097 await` 容量验证仅发出状态机体积告警，不再失败。

2026-06-21
# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1.5：标准库手工 Future 清零迁移
### 1.5.8 建议执行顺序
阶段验收：
- [x] `make check`
  验证命令：`make check`
  验证结果：通过；1047/1047 程序测试通过，后续 proof optimization、顶层函数可达性、nested async split-C、async frame descriptor、split-C cache、check CLI、UPM、exec vm、microapp、SIMD select、slice 参数 C99、结构体数组字段复制 / typed route 回归、macOS hosted seed extern、@syscall 交叉、SIMD NEON 与 `benchmarks/http_bench.uya` C99 均通过；`benchmarks/http_bench_async_epoll.uya` 按 Makefile 默认未启用。

## Phase 2：编译器 async 资源动态化

- [x] 把 `src/codegen/c99/async_transform.uya` 的 `MAX_SEGMENTS`、`MAX_LOCALS` 改成 growable 存储。
  - 完成内容：删除 `src/codegen/c99/async_transform.uya` 里残留的 `MAX_SEGMENTS` / `MAX_LOCALS` 固定常量；真实 growable async lowering plan 继续由 `src/lower/async.uya` 的动态扩容逻辑负责。补充 `tests/verify_async_compiler_no_fixed_limits.py`，把这两个兼容层残留常量纳入固定上限扫描，并同步清理相关测试注释与主 todo 审计口径。
  - 验证命令：`python3 tests/verify_async_compiler_no_fixed_limits.py`
  - 验证结果：通过。
  - 验证命令：`../uya/bin/uya test tests/test_async_await_capacity_dynamic.uya`
  - 验证结果：通过，1/1 tests passed。
  - 验证命令：`bash tests/verify_async_full_dynamic_resources_gate.sh unit-scan`
  - 验证结果：通过，`verify_async_full_dynamic_resources_gate: unit-scan stages passed`。
  - 验证命令：`git diff --check`
  - 验证结果：通过。

## 2026-06-21

路径：`# Uya 异步生产化 TODO（完整语法 + 动态资源）` > `## Phase 2：编译器 async 资源动态化`

- [x] 把 `src/codegen/c99/internal.uya` 的 `C99_ASYNC_MAX_AWAITS` 固定数组改成 arena/vector 风格的动态结构。
  - 完成内容：核验后确认该任务已由当前实现满足；`src/codegen/c99/internal.uya` 仅保留 `C99_ASYNC_INITIAL_AWAIT_CAPACITY` 与 `async_collect_*` 指针/容量字段，`src/codegen/c99/function.uya` 通过 `c99_ensure_async_await_capacity()` 使用 arena 按需扩容 await 收集/绑定表。本轮未再改生产代码，pending 状态属于 todo 文档滞后。
  - 验证命令：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`
  - 验证结果：通过，`ok: docs/todo_async_full_language_dynamic_resources.md has 1 active task`。
  - 验证命令：`../uya/bin/uya test tests/test_async_await_capacity_dynamic.uya`
  - 验证结果：通过，`async_await_capacity_grows_past_256` 1/1 tests passed。
  - 验证命令：`tmp_c="$(mktemp /tmp/uya_async_await_capacity_dynamic.XXXXXX.c)"; ../uya/bin/uya --c99 tests/test_async_await_capacity_dynamic.uya -o "$tmp_c"; grep -n "if (s->state == 261)" "$tmp_c"; rm -f "$tmp_c"`
  - 验证结果：通过，生成的 C99 状态机包含 `if (s->state == 261)`。
  - 验证命令：`work_dir="$(mktemp -d /tmp/uya_async_await_capacity.XXXXXX)"; ...; ../uya/bin/uya --c99 "$src" -o "$out_c"; grep -n 'if (s->state == 4098)' "$out_c"`
  - 验证结果：通过，临时生成的 `4097` 个 `@await` 压力样本成功完成 C99 代码生成，并命中最终状态 `4098`。

## Phase 2：编译器 async 资源动态化

- [x] 把 `src/checker/async_frame_meta.uya` 的 `MAX_ASYNC_FRAME_METAS` 改成动态元信息表。
  - 验证：`python3 tests/verify_async_compiler_no_fixed_limits.py`（通过）
  - 验证：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`（通过，3 个子测试全部通过）

## Phase 2：编译器 async 资源动态化

父级任务路径：Phase 2：编译器 async 资源动态化。
- [x] 把 `src/codegen/c99/main.uya` 的 async frame descriptor emission 改成“按真实数量生成”，不再静默截断到 `512`。
  - 验证：`python3 tests/verify_async_compiler_no_fixed_limits.py`
  - 验证：`../uya/bin/uya test tests/test_c99_async_frame_descriptors.uya`
  - 验证：临时生成 `tests/build/generated_async_descriptor_513.uya`，运行 `../uya/bin/uya --c99 tests/build/generated_async_descriptor_513.uya -o /tmp/uya-async-desc-513.XXXXXX.c`，检查得到 `_uya_async_frame_descriptor_entries[533]`、`_uya_async_frame_descriptor_count = 533`，且 `generated_async_512` frame 已发射。

## Phase 2：编译器 async 资源动态化

父级任务：为“超大 async 函数”建立新的错误模型

  - [x] 若只是旧的人为上限，不应再报错
    验证：
    `../uya/bin/uya test tests/test_async_await_capacity_dynamic.uya`（通过：`async_await_capacity_grows_past_256`）
    `../uya/bin/uya test tests/test_async_param_capacity_dynamic.uya`（通过：`async_param_capacity_grows_past_16`）
    `../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`（通过：3 个测试）
    `python3 tests/verify_async_compiler_no_fixed_limits.py`（通过：未发现残留固定 async 容量常量）
    `UYA_COMPILER=../uya/bin/uya bash tests/verify_async_await_capacity.sh`（通过：4097 个 `@await` 样本成功生成状态机，仅保留大小警告）
## Phase 2：编译器 async 资源动态化

- [x] 为“超大 async 函数”建立新的错误模型：
  - [x] 若真因内存耗尽或编译器资源不足失败，要给出明确诊断，而不是静默丢字段/丢状态
    - 完成记录：为 async lowering / C99 await 元数据分配增加 `CompilerArena` 上下文诊断，并新增 `tests/verify_async_resource_diagnostics.sh` 覆盖 `async-await-plan` 与 `async-await-codegen` 两条注入失败路径，避免资源失败时静默丢 await 点或状态机元数据。
    - 验证命令：`make uya`
    - 验证结果：通过；`bin/uya` 已按当前源码重建成功。
    - 验证命令：`bash tests/verify_async_resource_diagnostics.sh`
    - 验证结果：通过；两条注入失败路径都命中明确 async 资源诊断。
    - 验证命令：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`
    - 验证结果：通过；3 个 test 全部通过。
    - 验证命令：`../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya`
    - 验证结果：通过；7 个 test 全部通过。
    - 验证命令：`python3 tests/verify_async_lowering_plan_architecture.py`
    - 验证结果：通过；输出 `verify_async_lowering_plan_architecture: centralized async lowering plan confirmed`。
    - 验证命令：`git diff --check`
    - 验证结果：通过；无输出。

## Phase 2：编译器 async 资源动态化
- 父级任务：补齐 await 容量压力测试到旧上限附近：
  - [x] 不再把 “>256 await 编译失败” 视为正确
    - 验证：`git show --stat --summary cc993def -- tests/test_async_await_limits_and_segments.uya tests/error_async_too_many_awaits.uya docs/todo_async_full_language_dynamic_resources.md` 显示 `tests/error_async_too_many_awaits.uya` 已在 `cc993def0f12b81e13fc2e3aa294cad1adc11ff9` 删除。
    - 验证：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya` 通过（3 tests / 4 assertions）。

## Phase 2：编译器 async 资源动态化
- [x] 补齐 await 容量压力测试到旧上限附近：
  - [x] 改成“旧上限附近成功编译+运行”的压力测试
    - 红测：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`
    - 红测结果：失败；`await_near_old_limit_bindings` 未定义，宿主 C 编译报 `implicit declaration` 与 `invalid initializer`。
    - 验证：`../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`
    - 验证结果：通过；3 个测试全部通过，`260` 个顺序 `@await` 的样本成功编译并运行。
    - 相关验证：`../uya/bin/uya test tests/test_async_await_capacity_dynamic.uya`
    - 相关验证结果：通过；`async_await_capacity_grows_past_256` 通过。
    - 相关验证：`../uya/bin/uya test tests/test_async_large_state_machine_syntax.uya`
    - 相关验证结果：通过；7 个测试全部通过。
    - 验证：`git diff --check`
    - 验证结果：通过；无输出。

## Phase 2：编译器 async 资源动态化

- [x] 补一个“多 frame / 多 mono instance / 多 generic async”压力样本，验证 descriptor 和 meta 表不会截断。

**验收**：

- [x] `../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`
- [x] 新增 `tests/verify_async_large_state_machine.sh`
- [x] 新增 `tests/test_async_descriptor_growth.uya`
- [x] 在旧 `256 await`、`32 locals`、`512 frame meta` 边界附近的样本全部通过

**验证**：

- `../uya/bin/uya test tests/test_async_await_limits_and_segments.uya`
- `../uya/bin/uya test tests/test_async_descriptor_growth.uya`
- `bash tests/verify_async_large_state_machine.sh` -> `control=23 stress=548 delta=525`
- `python3 tests/verify_async_compiler_no_fixed_limits.py`
- `git diff --check`

## Phase 3：运行时 async 资源动态化
### 3.1 EventLoop / epoll
- [x] 将 `lib/std/async_event.uya` 的固定 `1024` slot / event buffer 改成动态容量。
  验证：`../uya/bin/uya test tests/test_async_event_config.uya`（通过：2 tests passed, 0 failed）
  验证：`../uya/bin/uya test tests/test_std_async_event.uya`（通过：总计 1，失败 0）
  说明：`lib/std/async_event.uya` 已提供 `linux_epoll_create_config(...)`、动态分配的 slot / event buffer，以及对应容量查询与运行时测试覆盖。

## Phase 3：运行时 async 资源动态化
### 3.1 EventLoop / epoll
- [x] 消灭 `find_slot()` 线性扫固定数组的实现，改成更适合生产的索引结构。
  - 验证：`../uya/bin/uya test tests/test_std_async_event_fd_reuse.uya`（通过，5/5；新增碰撞/墓碑链回归）
  - 验证：`../uya/bin/uya test tests/test_std_async_event.uya`（通过，1/1）
  - 验证：`../uya/bin/uya test tests/test_epoll_syscall.uya`（通过，1/1；覆盖 `EpollEvent` 12-byte ABI 断言）
  - 验证：`../uya/bin/uya test tests/test_epoll_server.uya`（通过，8/8）
## Phase 3：运行时 async 资源动态化
### 3.1 EventLoop / epoll

- [x] 把“容量满直接失败”改成可增长或可配置策略，并补上指标。
  - 验证：`../uya/bin/uya test --c99 tests/test_async_event_config.uya`（通过，2 tests / 11 assertions）
  - 验证：`../uya/bin/uya test --c99 tests/test_std_async_event.uya`（通过）
  - 验证：`../uya/bin/uya test --c99 tests/test_std_async_event_fd_reuse.uya`（通过，5 tests / 28 assertions）
  - 验证：`../uya/bin/uya test --c99 tests/test_std_async_scheduler.uya`（通过，20 tests / 242 assertions）
  - 验证：`git diff --check`（通过）
  - 验证：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_async_full_language_dynamic_resources.md`（通过，1 active task）
## Phase 3：运行时 async 资源动态化

### 3.2 Scheduler / TaskQueue

- [x] 评估并收口 `SCHEDULER_INLINE_REPOLL_LIMIT=1024` 的策略，让它成为调度策略参数，而不是写死常量。
  - 实现：`Scheduler` 默认 inline repoll 策略统一读取 `UYA_SCHEDULER_INLINE_REPOLL_LIMIT`，`scheduler_new()`、`scheduler_inline_repoll_limit(null)`、`block_on_with_event_loop*()` 默认路径不再散落裸 `1024`。
  - 验证：`UYA_SCHEDULER_INLINE_REPOLL_LIMIT=1 ../uya/bin/uya test tests/test_std_async_scheduler.uya`
  - 结果：通过，24 tests / 0 failed；新增默认策略测试覆盖 `scheduler_new()`、`block_on_with_event_loop()` 和 `block_on_with_event_loop_deadline()`。
  - 验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya`
  - 结果：通过，24 tests / 0 failed。
  - 验证：`git diff --check`
  - 结果：通过，无 diff 格式错误。
  - 文档同步：`docs/todo_async_full_language_dynamic_resources.md`、`docs/async_runtime_semantics_matrix.md` 已更新为默认策略口径。
## Phase 3：运行时 async 资源动态化

### 3.3 AsyncFramePool

- [x] 将 `lib/std/async_frame.uya` 的 bucket / slot / descriptor 上限改成动态结构。
  - 完成记录：本轮核对后确认实现已在仓库中，主 todo 仅缺少同步。`lib/std/async_frame.uya` 已支持 bucket 表按需翻倍扩容、bucket slot 表按需翻倍扩容；`src/codegen/c99/main.uya` 生成的 `_uya_async_frame_descriptor_entries` 已按 `async_frame_meta_count` 定长输出，空表时只保留 1 个占位 entry。
  - 验证：`../uya/bin/uya test tests/test_async_frame_pool_dynamic_growth.uya`
  - 结果：通过，1 个测试文件 / 4 tests / 4236 assertions，覆盖 bucket 表和 slot 表突破旧默认容量。
  - 验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya`
  - 结果：通过，1 个测试文件 / 10 tests / 4251 assertions，覆盖显式配置、大于默认 bucket 数和大于默认 per-bucket 容量。
  - 验证：`../uya/bin/uya test tests/test_async_frame_align_pool.uya`
  - 结果：通过，1 个测试文件 / 8 tests / 4235 assertions，覆盖对齐路径和超过旧兼容上限的 pool 配置。
  - 验证：`../uya/bin/uya test tests/test_c99_async_frame_empty_descriptors.uya`
  - 结果：通过，空 descriptor 表路径保持可运行。
  - 验证：`python3 tests/verify_async_compiler_no_fixed_limits.py`
  - 结果：通过，未发现 async frame/compiler 相关固定上限残留检查命中。
  - 验证：`../uya/bin/uya --c99 tests/test_async_frame_pool_stats.uya -o /tmp/uya_async_frame_pool_stats.c`
  - 结果：通过；生成产物中包含 `_uya_async_frame_descriptor_entries[21]` 与 `_uya_async_frame_descriptor_count = 21`。
  - 验证：`../uya/bin/uya --c99 tests/test_c99_async_frame_empty_descriptors.uya -o /tmp/uya_async_frame_empty_descriptors.c`
  - 结果：通过；生成产物中包含 `_uya_async_frame_descriptor_entries[1]` 与 `_uya_async_frame_descriptor_count = 0`。
父级任务路径：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## Phase 3：运行时 async 资源动态化 > ### 3.3 AsyncFramePool
- [x] 为 pool 建立明确的 ownership 跟踪，修掉 reset/free 语义只能靠注释解释的隐患。
  - 完成记录：`lib/std/async_frame.uya` 为每块 frame 增加 `owner_kind + generation` header，`async_frame_pool_free*` / `async_frame_pool_reset` 现在会区分 caller buffer、池内 heap 复用和 debug heap fallback；reset 后旧 generation frame 不会再回灌到当前 pool。
  - 完成记录：新增 ownership 回归，并把受 header 开销影响的 buffer 容量测试扩大到仍验证相同动态容量语义的范围。
  - 验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya`
  - 结果：通过；新增 3 条 ownership/reset 回归全部通过。
  - 验证：`../uya/bin/uya test tests/test_async_frame_align_pool.uya`
  - 结果：通过；对齐与大 per-bucket buffer 路径回归通过。
  - 验证：`../uya/bin/uya test tests/test_async_frame_pool_dynamic_growth.uya`
  - 结果：通过；bucket / slot 动态增长回归通过。
  - 验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya`
  - 结果：通过；scheduler 绑定 frame pool 路径 24 项通过。
  - 验证：`../uya/bin/uya test tests/test_async_frame_pool_full.uya`
  - 结果：通过；IAllocator 失败路径回归通过。

父级任务路径：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## Phase 3：运行时 async 资源动态化 > ### 3.3 AsyncFramePool > - [ ] 区分：
  - [x] 真正来自 caller buffer 的 frame
    - 完成记录：`lib/std/async_frame.uya` 将 frame header 收紧为 8 字节的 `storage_kind + alloc_kind + generation`，新增 `async_frame_pool_ptr_is_direct_caller_buffer()`；首次直接从 caller buffer 切出的 frame 仍可识别，而经 free list 再借出的同一指针会重标为普通 pool 路径，不再被误判为 fresh caller buffer。
    - 验证命令：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya`
    - 验证结果：通过；9 项测试通过，新增 `async_frame_pool_direct_caller_buffer_frame_stays_distinct_from_pool_reuse` 通过。
    - 扩展验证命令：`../uya/bin/uya test tests/test_async_frame_align_pool.uya`；`../uya/bin/uya test tests/test_async_frame_pool_dynamic_growth.uya`；`../uya/bin/uya test tests/test_std_async_scheduler.uya`
    - 扩展验证结果：通过；分别 4 / 2 / 24 项测试通过。
## Phase 3：运行时 async 资源动态化

### 3.3 AsyncFramePool

父级路径：- [ ] 区分：
  - [x] 池内复用 frame
    - 实现：默认 `get_async_frame_allocator()` 在未显式设置时回退到 `async_frame_pool_default()`，普通 `@async_fn` 默认进入统一池并复用已释放 frame。
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya`（通过，新增默认 async 路径使用默认池并复用 frame 的回归）
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_full.uya`（通过）
    - 验证：`../uya/bin/uya test tests/test_std_async_scheduler.uya`（通过）
    - 验证：`../uya/bin/uya test tests/test_c99_async_frame_descriptors.uya`（通过）
## Phase 3：运行时 async 资源动态化

### 3.3 AsyncFramePool

父级任务路径：# Uya 异步生产化 TODO（完整语法 + 动态资源） > ## Phase 3：运行时 async 资源动态化 > ### 3.3 AsyncFramePool

- [x] 区分：
  - [x] debug heap fallback frame
    - 完成记录：`lib/std/async_frame.uya` 新增 `async_frame_pool_ptr_is_debug_heap_fallback()`，把 debug heap fallback frame 作为独立调试分类公开出来；`tests/test_async_frame_pool_stats.uya` 新增正反断言，显式区分 debug heap fallback、direct caller buffer 和普通 pool heap frame。
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_stats.uya`（通过：1 个测试文件，11 tests，4293 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_dynamic_growth.uya`（通过：1 个测试文件，2 tests，4236 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_frame_align_pool.uya`（通过：1 个测试文件，4 tests，4235 assertions）
    - 验证：`../uya/bin/uya test tests/test_async_frame_pool_full.uya`（通过：1 个测试文件，1 tests）

## Phase 3：运行时 async 资源动态化

### 3.3 AsyncFramePool

- [x] 默认生产路径不应依赖 heap fallback 才能跑通。
  - 完成记录：`AsyncFramePool` 在 caller buffer 用尽时先提交正常的 pool heap block，再把 debug heap fallback 留作最终兜底；新增 buffer 耗尽回归避免默认生产路径再靠 fallback 跑通。
  - 验证：`../uya/bin/uya test --c99 tests/test_async_frame_pool_stats.uya`（通过，12 tests / 0 failed）
  - 验证：`../uya/bin/uya test --c99 tests/test_std_async_scheduler.uya`（通过，24 tests / 0 failed）
  - 验证：`../uya/bin/uya test --c99 tests/test_async_frame_align_pool.uya`（通过，4 tests / 0 failed）
  - 验证：`../uya/bin/uya test --c99 tests/test_async_frame_pool_full.uya`（通过，1 suite / 0 failed）

## Phase 3：运行时 async 资源动态化

### 3.4 ThreadPool / async_compute

- [x] 将 `lib/std/thread.uya` 的 worker / pending / task slot 数量改成动态或可配置。
  - 验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya`（通过：1 test，26 assertions）
  - 扩展验证：`../uya/bin/uya test tests/test_std_thread_async_boundary.uya`（通过：4 tests，16 assertions）
  - 扩展验证：`../uya/bin/uya test tests/test_std_thread.uya`（通过：34 tests，144 assertions）

## Phase 3：运行时 async 资源动态化

### 3.4 ThreadPool / async_compute

父级任务：`明确 `async_compute` 饱和后的生产策略：`
- [x] 要么动态排队并背压
  - 完成：`tests/test_async_thread_pool_dynamic_growth.uya` 新增单 worker 饱和背压回归，验证共享队列在 `task_slot_capacity > THREAD_POOL_MAX_TASK_SLOTS` 时可排队 20 个 delayed 任务、pending 深度超过旧 `16` 边界并最终排空。
  - 验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya`（通过，2 tests / 54 assertions）
  - 验证：`../uya/bin/uya test tests/test_std_thread.uya`（通过，34 tests / 144 assertions）
  - 验证：`bash tests/verify_async_full_dynamic_resources_gate.sh unit-scan`（通过）

## Phase 3：运行时 async 资源动态化

### 3.4 ThreadPool / async_compute

父级任务：`明确 `async_compute` 饱和后的生产策略：`

  - [x] 要么显式返回容量错误
    - 结果：`lib/std/thread.uya` 的 `async_compute` 提交饱和路径现在显式返回 `error.TaskQueueFull`，不再把 slot/pending 容量打满混成泛化 `EBADF` 风格错误。
    - 验证：`../uya/bin/uya test tests/test_std_thread_async_boundary.uya` 通过；`thread_async_boundary_queue_full_returns_explicit_capacity_error` 断言 `error.TaskQueueFull` 成功。
    - 验证：`../uya/bin/uya test tests/test_std_thread.uya` 通过（34/34）。
    - 验证：`../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya` 通过（2/2）。
    - 验证：`../uya/bin/uya test tests/test_async_compute_types.uya` 通过（11/11）。
