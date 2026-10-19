# Uya 卫生宏实现待办

**参考**：[macro_hygiene_design.md](macro_hygiene_design.md)（详细设计）、[uya.md](uya.md) §25 宏系统

> **核对头（2026-10-19，v0.10.4）**：Phase 1–4 **全部完成**。代码侧 `hygiene_enabled` /
> `create_hygiene_name` 在 `src/checker/macro_expand.uya`，生成名格式
> `<原名>__hyg_<expansion_id>_<local_id>`（`macro_expand.uya:1116`）；文档侧 `uya.md` §25.2.2
> 「卫生宏（宏卫生化）」已写入，`grammar_formal.md` 宏章节与 `grammar_quick.md` §十四 已补卫生宏说明；
> 回归 `tests/test_macro_hygiene.uya`（12 断言）通过。下文复选框保留历史形式。

**当前状态**：Phase 1-3 已完成，Phase 4（文档）部分完成。实现位于 `src/checker/macro_expand.uya`，测试位于 `tests/test_macro_hygiene.uya`（6/6 通过）。

实现时遵循项目 TDD 流程：先添加测试（或先实现再补测）→ 实现代码 → `make check` 验证。

---

## Phase 1：数据结构与预处理 ✅

### 1.1 上下文与旁表

- [x] 在 [src/checker/macro_expand.uya](../src/checker/macro_expand.uya) 中定义 `HygieneCopyState`（scope_names/scope_renamed_names/scope_entry_count/scope_starts/scope_depth），字段见 macro_expand.uya:34-51。
- [x] 扩展 `MacroExpandContext`：增加 `hygiene_enabled`、`hygiene_expansion_id`、`hygiene_next_local_id`。

### 1.2 收集 local_binding 声明节点

- [x] 实现 local_bindings 收集：在 `extract_macro_output_with_params` 内对 `const x = @mc_eval(...)` 和 `const x = @mc_type(...)` 收集声明节点，与宏参数合并传入深拷贝。

### 1.3 卫生名称生成与作用域管理

- [x] 实现 `create_hygiene_name(ctx, original_name)`：生成 `<name>__hyg_<expansion_id>_<local_id>` 格式的唯一名称（macro_expand.uya:929）。
- [x] 实现作用域管理函数：`hygiene_enter_scope`、`hygiene_exit_scope`、`hygiene_add_binding`、`hygiene_lookup_binding`（macro_expand.uya:884-927）。
- [x] 实现 `init_hygiene_copy_state`（macro_expand.uya:945）。

### 1.4 expansion_id

- [x] 使用 macro_expand 模块内静态变量 `macro_hygiene_expansion_counter`（macro_expand.uya:53），每次展开前通过 `next_macro_hygiene_expansion_id()` 递增。

### 1.5 两处展开入口启用卫生

- [x] **AST_CALL_EXPR 路径**（~line 3570）：设置 `hygiene_enabled: 1`，获取 expansion_id，初始化 `hygiene_next_local_id: 0`。
- [x] **AST_METHOD_BLOCK 路径**（~line 3703）：同上，设置 `hygiene_enabled: 1`。

### 1.6 merged_ctx 传递 hygiene

- [x] 在 `extract_macro_output_with_params` 中，`merged_ctx = *ctx` 后 hygiene 相关字段随结构体拷贝传递。

---

## Phase 2：拷贝时应用卫生 ✅

### 2.1 deep_copy_ast_with_params / deep_copy_ast_internal

采用了与设计文档不同但等效的实现方案：不使用预计算的 use_sites/binding_sites 查找表，而是在 AST 深拷贝过程中直接进行作用域跟踪和名称重命名。

- [x] **前置判断**：通过 `macro_ctx_has_hygiene(ctx)` 检查 `ctx.hygiene_enabled`（macro_expand.uya:871）。
- [x] **AST_IDENTIFIER**（lines 972-977）：若启用卫生，通过 `hygiene_lookup_binding` 在当前作用域中查找；找到则替换为重命名后的名称；未找到则保留原名。
- [x] **AST_VAR_DECL**（lines 1117-1130）：若启用卫生且变量名非 `self`，通过 `create_hygiene_name` 生成唯一名称，调用 `hygiene_add_binding` 记录映射。
- [x] **AST_FOR_STMT**（lines 1098-1114）：若启用卫生，循环变量通过 `create_hygiene_name` 重命名，进入新作用域处理循环体，退出作用域。
- [x] **AST_FN_DECL**（lines 1173-1191）：`fn_decl_name` 保持原样不参与卫生。函数参数通过递归走 AST_VAR_DECL 分支处理。
- [x] **AST_CATCH_EXPR**（lines 1194-1206）：若启用卫生，错误变量重命名，进入新作用域处理 catch 块，退出作用域。
- [x] **AST_BLOCK**（lines 1077-1090）：进入/退出作用域，维护正确的嵌套层级。

### 2.2 deep_copy_ast_with_field_subst

- [x] `for info.fields` 展开也使用卫生（通过 deep_copy_ast_with_field_subst 调用，macro_expand.uya:1290）。

---

## Phase 3：测试 ✅

### 3.1 测试用例

- [x] 新增 `tests/test_macro_hygiene.uya`，包含 6 则测试用例（比原计划多 1 则）：
  - [x] 用例 1 `macro_hygiene_local_var_not_shadow_callsite`：宏体内 `var tmp` 不覆盖调用处的 `tmp`。
  - [x] 用例 2 `macro_hygiene_param_still_reads_outer_name`：宏参数仍被实参替换，宏内 `x` 被重命名，调用处 `x` 不受影响。
  - [x] 用例 3 `macro_hygiene_catch_err_not_shadow_callsite`：宏体内 `catch |err|` 与调用处同名 `err` 不互相干扰。
  - [x] 用例 4 `macro_hygiene_local_bindings_exclude_by_node`：`const info = @mc_type(T)` 排除按节点而非按名字工作，内层 `var info` 仍被重命名。
  - [x] 用例 5 `macro_hygiene_for_loop_var_does_not_capture_dest`：for 循环变量 `i` 不干扰参数表达式中的 `counts[i]`。
  - [x] 用例 6 `macro_hygiene_unique_names_per_expansion`：同一宏展开两次，各自局部变量互不影响。
- [x] 所有现有宏测试仍通过。

---

## Phase 4：文档

### 4.1 语言规范

- [ ] 在 [docs/uya.md](uya.md) 宏系统章节（§25）中增加"卫生宏"小节：说明宏体内引入的变量/循环变量/函数参数/`catch` 错误变量会做卫生重命名，避免与调用处名字捕获；宏参数与 `const x = @mc_eval/@mc_type` 的语义不变；`fn_decl_name` 首版保持原样；生成名格式可注明（如 `__hyg_<expansion>_<id>`）。

### 4.2 语法规范文档

- [ ] 在 [docs/grammar_formal.md](grammar_formal.md) 中补充卫生宏相关说明：宏展开阶段对宏体内绑定的标识符进行卫生重命名的语义规则（可与 uya.md §25 对应）；若要宣称生成名"绝不与用户代码冲突"，需同步保留 `__hyg_` 前缀，否则仅表述为实现约定。
- [ ] 若 [docs/grammar_quick.md](grammar_quick.md) 有宏系统速查，可增加一句"宏为卫生宏，宏内引入的名字不与调用处冲突"的说明。

### 4.3 与主待办集成

- [ ] 在 [docs/todo_mini_to_full.md](todo_mini_to_full.md) 中增加"卫生宏"已实现项（或链接到本 todo），便于主待办跟踪。

---

## 验收清单

- [x] 现有所有宏测试（test_macro*.uya）通过。
- [x] test_macro_hygiene.uya 中六则用例通过。
- [ ] uya.md §25 包含卫生宏说明。
- [ ] grammar_formal.md（及可选 grammar_quick.md）已更新卫生宏相关描述。
- [x] make check 通过。
