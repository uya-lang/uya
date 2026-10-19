# Uya 宏卫生化详细设计文档

**版本**：v0.1 ｜ **状态**：**已实现**（2026-10-19 核对，编译器 v0.10.4；原文为"设计完成，待实现"）｜ **参考**：[uya.md](uya.md) §25 宏系统、[grammar_formal.md](grammar_formal.md)、[src/checker/macro_expand.uya](../src/checker/macro_expand.uya)

> **实现状态**：`MacroExpandContext.hygiene_enabled` 在宏展开入口置 1（`src/checker/macro_expand.uya:3939`、`4072`），重命名按 `<原名>__hyg_<expansion_id>_<local_id>` 生成（`src/checker/macro_expand.uya:1116` 的 `snprintf`；编号来自 `next_macro_hygiene_expansion_id` / `hygiene_next_local_id`，见 `964-1025`）。验收测试 `tests/test_macro_hygiene.uya` 已存在并通过（`./bin/uya test tests/test_macro_hygiene.uya`，12 条断言全过）。下方 §1-§9 保留原设计文本。

---

## 1. 概述

### 1.1 背景与问题

当前 Uya 宏展开时，仅对**宏参数**做替换（实参 AST 替换形参引用）；宏体内**非参数**的标识符（如 `var tmp`、`for x in ...`、`fn foo`）在拷贝时**原样保留名字**。展开后的 AST 在类型检查阶段解析名字时，这些标识符会在**调用处作用域**中解析，导致：

- **宏体名字被调用处捕获**：宏里写的 `var tmp = ...` 若调用处也有 `tmp`，展开后可能误用调用处的 `tmp`。
- **调用处名字被宏体遮蔽**：调用处本意使用外层的 `x`，若宏体也声明了 `x`，展开后该引用可能错误地绑定到宏生成的 `x`。

### 1.2 目标

实现**卫生宏**：宏体内**引入的**局部标识符（变量、循环变量、函数参数、`catch` 错误变量）在展开时被重命名为**唯一生成名**，使得：

1. 宏体引入的名字与调用处（及任意外层）的名字互不捕获、互不遮蔽。
2. 宏参数、`const x = @mc_eval(...)` / `@mc_type(...)` 的语义**不变**（仍按现有替换/合并 ctx 逻辑处理）。

### 1.3 术语

| 术语 | 含义 |
|------|------|
| 宏体 (macro body) | 宏声明的 `macro_decl_body`，即 `mc name(...) tag { ... }` 中 `{ ... }` 的 AST（通常为 `AST_BLOCK`）。 |
| 绑定点 (binding site) | 在宏体内引入新名字的 AST 节点：`AST_VAR_DECL`、`AST_FOR_STMT`（循环变量）、`fn_decl_params[i]`（函数参数，即 `AST_VAR_DECL`）、`AST_CATCH_EXPR`（错误变量）。 |
| 使用点 (use site) | 引用某个名字的 `AST_IDENTIFIER` 节点（包括作为 `member_access_object`、`mc_interp_operand` 等子节点出现时）。 |
| 宏局部 (macro-local) | 在宏体内绑定、且**不是**宏参数、也**不是**具体 `local_bindings` 声明节点（如 `const x = @mc_eval(...)`）的名字。 |
| 自由名 (free name) | 在宏体内被使用、但既不是宏参数也不是宏局部绑定的名字；展开后在**调用处**解析。 |

---

## 2. 设计约束与首版范围

### 2.1 需重命名的绑定（macro-local）

- `AST_VAR_DECL` 的 `var_decl_name`（**排除具体声明节点**为 `const x = @mc_eval(...)` / `const x = @mc_type(...)` 的情形）。
- `AST_FOR_STMT` 的 `for_stmt_var_name`。
- `AST_FN_DECL` 的 `fn_decl_params[i].var_decl_name`（参数节点类型为 `AST_VAR_DECL`）。
- `AST_CATCH_EXPR` 的 `catch_expr_err_name`（若存在）。

**不**重命名：

- 宏参数名：由 `find_param_binding` 替换为实参 AST。
- 会加入 `local_bindings` 的 const 名：在 `extract_macro_output_with_params` 中合并进 `merged_ctx`，拷贝时按参数方式替换。
- `AST_FN_DECL.fn_decl_name`：首版保持原样。它通常属于宏输出的可见结果，而不是宏内部临时绑定；默认重命名会改变 `struct` 返回宏等场景的外部接口。

### 2.2 首版范围

- **仅**处理 var / for / fn 参数 / catch 错误变量。**不**处理 `fn_decl_name`、`struct_decl_name`、`enum_decl_name`、`interface_decl_name` 等声明名。
- 若后续需要“宏生成类型名”也卫生化，可扩展绑定点种类与 `binding_sites` 表。

---

## 3. 数据结构

### 3.1 旁表（与 AST 节点对应）

AST 节点无内置“卫生用” id 字段，采用在 arena 上分配的**旁表**，用节点指针做键：

```text
HygieneUseEntry   = { node: &ASTNode, binding_id: i32 }   // 使用点 -> 解析结果
HygieneBindingEntry = { node: &ASTNode, binding_id: i32 } // 绑定点 -> 分配的 id
```

**binding_id 约定（use_sites）**：

- `-1`：该标识符解析为**宏参数**（拷贝时做实参 AST 替换）。
- `-2`：**自由名**（拷贝时保留原名，在调用处解析）。
- `>= 0`：解析为**宏局部**绑定的 `binding_id`（拷贝时用 `rename_map[binding_id]`）。

### 3.2 重命名表

- `hygiene_rename_map: &(&byte)`，下标为 `binding_id`，值为在 arena 上生成的唯一名（如 `tmp__hyg_7_0`）。
- `hygiene_rename_count: i32`，表示当前展开中 macro-local 绑定数量；查找时须保证 `0 <= binding_id < hygiene_rename_count`，避免越界。

### 3.3 MacroExpandContext 扩展

在现有 `MacroExpandContext` 上增加（或通过指针共享一个 HygieneData 结构体）：

| 字段 | 类型 | 说明 |
|------|------|------|
| hygiene_use_sites | &HygieneUseEntry（或等价线性表） | 使用点表；可为 null 表示未启用卫生。 |
| hygiene_use_count | i32 | 表项数量。 |
| hygiene_binding_sites | &HygieneBindingEntry | 绑定点表；可为 null。 |
| hygiene_binding_count | i32 | 表项数量。 |
| hygiene_rename_map | &(&byte) | binding_id -> 新名字。 |
| hygiene_rename_count | i32 | 同上。 |

**约定**：仅当 `hygiene_use_sites != null`（或等价条件）时，拷贝逻辑才进行卫生查找与重命名；否则保持当前“只做参数替换”的行为。

---

## 4. 算法

### 4.1 唯一名生成

格式：`name + "__hyg_" + expansion_id + "_" + binding_id`。

- `expansion_id`：每次宏展开（不论哪条入口）递增的计数器，保证不同次展开得到的后缀不同。
- 实现二选一：（a）在 `TypeChecker` 上增加字段（如 `macro_expansion_counter`），每次展开前递增；（b）在 macro_expand 模块内用静态变量。当前编译为单线程，不考虑并发。

### 4.2 收集 local_binding 声明节点

与 `extract_macro_output_with_params` 开头的逻辑一致（可抽成共用函数 `collect_local_binding_decls(body, arena)`）：

- 遍历宏体**顶层**语句（body 为 `AST_BLOCK` 时的 `block_stmts[i]`）。
- 若为 `AST_VAR_DECL` 且 `var_decl_is_const != 0`、`var_decl_init` 为 `AST_MC_EVAL` 或 `AST_MC_TYPE`，则将该**声明节点本身**加入集合 L。
- L 用于在“绑定收集”时排除：**节点在 L 中**的绑定点**不**分配 binding_id，也不进入 binding_sites / rename_map（它们在 merged_ctx 中作为“形参”被替换）。这里不能仅按名字排除，否则会误伤内层同名局部变量。

### 4.3 绑定收集（第一遍遍历）

- 递归遍历**整棵**宏体 AST，按遍历顺序为每个需重命名的绑定点分配 binding_id（即 next_id++），顺序无语义要求。
- 对每个**绑定点**：
  - `AST_VAR_DECL`：若该节点**不在 L 中**，且 `var_decl_name` 不在宏参数名集合，则分配 `binding_id = next_id++`，写入 `binding_sites`，并生成 `new_name` 写入 `rename_map[binding_id]`。
  - `AST_FOR_STMT`：对 `for_stmt_var_name` 同上（不在参数名则分配 binding_id 并重命名）。
  - `AST_FN_DECL`：**仅**处理 `fn_decl_params[i]`（每个为 `AST_VAR_DECL`）；`fn_decl_name` 首版不分配 binding_id。
  - `AST_CATCH_EXPR`：若 `catch_expr_err_name != null` 且不在宏参数名集合，则为该错误变量分配 binding_id。
- 宏参数名集合来自 `macro_decl_params[i].var_decl_name`，不分配 binding_id。

### 4.4 作用域解析（第二遍遍历）

- 递归遍历宏体 AST，维护**当前作用域**：名字 -> 整数的映射（可用栈或链式表实现“进入作用域压栈、退出弹栈”）。取值约定：**宏参数名映射为 -1**，宏局部绑定映射为对应的 binding_id（≥ 0）。
- **初始作用域**：在进入宏体前，先将所有宏参数名加入映射，对应值均为 **-1**，这样“找到且为宏参数”即“查到的值为 -1”。
- **进入作用域**：`AST_BLOCK`、`AST_FN_DECL`、`AST_FOR_STMT`、带 `catch_expr_err_name` 的 `AST_CATCH_EXPR`。
- **退出作用域**：离开上述节点时弹栈。
- **AST_FN_DECL** 顺序：先进入函数作用域；将 `fn_decl_params` 中每个参数的 `var_decl_name` 与对应 binding_id（若为宏局部）或 -1（若为宏参数）加入该作用域；再递归 `fn_decl_body`，这样函数体内引用的是参数或本层绑定。
- **AST_FOR_STMT** 顺序：先解析迭代对象/范围表达式；再进入循环作用域，将 `for_stmt_var_name` 加入该作用域；最后递归 `for_stmt_body`。该顺序必须与现有类型检查器保持一致。
- **AST_CATCH_EXPR** 顺序：先解析 `catch_expr_operand`；若 `catch_expr_err_name != null`，进入 catch 作用域并加入错误变量；最后递归 `catch_expr_catch_block`。
- 对**每一个** `AST_IDENTIFIER` 节点（无论作为独立表达式还是作为 `member_access_object`、`mc_interp_operand` 等子节点）：
  - 用 `identifier_name` 在当前作用域链中查找（从内到外）。
  - 若查到值为 -1：在 use_sites 中记录 `(node, -1)`（宏参数）。
  - 若查到值为某 binding_id（≥ 0）：在 use_sites 中记录 `(node, binding_id)`。
  - 若未找到：在 use_sites 中记录 `(node, -2)`（自由名）。

### 4.5 拷贝时应用

- **仅当** `ctx.hygiene_use_sites != null`（或约定的“已启用卫生”条件）时才进行下列查找；否则保持现有逻辑。
- **AST_IDENTIFIER**：
  - 在 use_sites 中查当前节点（按指针比较）。
  - 若查到 `binding_id == -1`：按现有逻辑 `find_param_binding(ctx, name)` 并替换为实参 AST。
  - 若查到 `binding_id >= 0`：`copy.identifier_name = rename_map[binding_id]`（并保证 `binding_id < hygiene_rename_count`）。
  - 若查到 `-2` 或未查到：`copy.identifier_name = node.identifier_name`。
- **AST_VAR_DECL**：在 binding_sites 中查当前节点；若查到则 `copy.var_decl_name = rename_map[binding_id]`，否则保持原名。
- **AST_FOR_STMT**：binding_sites 中以该 for 节点为键存储的是其 `for_stmt_var_name` 对应的 binding_id。拷贝时：在 binding_sites 中查当前 for 节点，若查到则 `copy.for_stmt_var_name = rename_map[binding_id]`，否则保持 `node.for_stmt_var_name`。
- **AST_FN_DECL**：`fn_decl_name` 保持原名；`fn_decl_params[i]` 在递归拷贝时作为 `AST_VAR_DECL` 已由上面规则处理。
- **AST_CATCH_EXPR**：若错误变量存在且在 binding_sites 中查到该 catch 节点，则将 `copy.catch_expr_err_name` 改为 `rename_map[binding_id]`。

---

## 5. 作用域规则（与语言一致）

- **块**：`AST_BLOCK` 引入新作用域；块内 `var x` 遮蔽外层同名。
- **函数**：`AST_FN_DECL` 进入新作用域；参数先加入该作用域，再检查函数体。
- **for**：`AST_FOR_STMT` 进入新作用域；循环变量绑定在该作用域中，仅对循环体可见。实现必须镜像当前类型检查器的进入/插入顺序，不能“依实现而定”。
- **catch**：`expr catch |err| { ... }` 在 catch 块前进入新作用域，并将 `err` 绑定到该作用域。

---

## 6. 与现有流程的集成

### 6.1 两处展开入口

1. **AST_CALL_EXPR**（约 2755–2778 行）：识别到宏调用、构建好 `ctx.bindings` 后，先调用 `collect_local_binding_decls(body, arena)`（或内联等价逻辑），再调用 `build_hygiene_data(body, param_names, local_binding_decls, arena, expansion_id)`，将返回的 use_sites、binding_sites、rename_map、count 填入 `ctx`，再调用 `extract_macro_output_with_params(body, &ctx, ...)`。
2. **AST_METHOD_BLOCK**（约 2862–2912 行）：对 struct 返回宏展开时，同样在构建好 `ctx.bindings` 后先得到 `local_binding_decls`，再调用 `build_hygiene_data(...)` 并填入 `ctx`，再调用 `extract_macro_output_with_params`。

### 6.2 merged_ctx 传递 hygiene

在 `extract_macro_output_with_params` 中，`merged_ctx = *ctx` 后，**不**覆盖 hygiene 相关字段（即保持 `merged_ctx.hygiene_* = ctx.hygiene_*`），这样后续所有 `deep_copy_ast_with_params(..., &merged_ctx, ...)` 和 `deep_copy_ast_with_field_subst(..., &merged_ctx, ...)` 都能读到同一套表。

### 6.3 deep_copy_ast_with_field_subst

该函数用于 `for info.fields` 的展开，也会拷贝宏体片段。传入的 `ctx` 已包含同一次展开的 hygiene 数据。在拷贝 `AST_IDENTIFIER`、`AST_VAR_DECL`、`AST_FOR_STMT`、`AST_CATCH_EXPR` 与 `AST_FN_DECL` 的参数节点时，应用与 `deep_copy_ast_with_params` **相同**的查找与重命名规则（先判断 ctx 是否带 hygiene 数据，再查 use_sites / binding_sites）。

---

## 7. 边界情况与注意事项

- **空宏体 / 无绑定**：binding_count 为 0，rename_map 可为空；use_sites 仍可包含“全部为参数或自由名”的项。拷贝时 hygiene 数据非空但查不到 binding_id 时按现有逻辑（参数替换或保留原名）。
- **同名多绑定（遮蔽）**：不同作用域中同名变量对应不同 binding_id，rename_map 中各有唯一新名；作用域解析保证每个使用点只解析到一个 binding_id。`local_bindings` 的排除必须按**节点**而非按名字进行。
- **C 代码生成**：生成名形如 `tmp__hyg_7_0`，符合 C 合法标识符，codegen 无需特殊处理。
- **错误信息**：类型错误等可能显示生成名；友好还原为宏内原名留作后续优化。
- **前缀冲突**：`__hyg_` 目前仅是实现约定，不应在文档中宣称“绝不与用户代码冲突”。若后续要把此保证提升为语言级承诺，应在规范中显式保留该前缀。

---

## 8. 风险与后续优化

| 风险/点 | 说明 |
|---------|------|
| 作用域实现细节 | 需严格镜像现有类型检查器中的 BLOCK/FN_DECL/FOR/CATCH 作用域进入顺序；不能使用“近似作用域”实现。 |
| 性能 | use_sites / binding_sites 线性查找；宏体通常较小，若后续宏体变大可考虑按节点指针或 (line,col) 的简单哈希。 |
| 唯一名冲突 | 若需要语言级“绝不冲突”保证，应在规范中保留 `__hyg_` 前缀；否则只能将其视为实现约定。 |

---

## 9. 验收标准

- 现有所有宏测试（`test_macro*.uya`）仍通过。
- 新增 `test_macro_hygiene.uya`：宏内局部变量、`for` 循环变量、函数参数、`catch` 错误变量与调用处同名时不互相干扰；同一宏在同一文件内展开两次得到不同唯一名；宏参数与自由名行为与现有一致。
- [uya.md](uya.md) §25 增加“卫生宏”小节，说明重命名规则与例外（参数、local_bindings）。
- [grammar_formal.md](grammar_formal.md)（及可选 [grammar_quick.md](grammar_quick.md)）已补充卫生宏相关描述。
