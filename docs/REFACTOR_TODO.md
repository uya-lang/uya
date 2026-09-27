# Uya 编译器重构 TODO 清单

> **核对头（2026-09-27）**：本文件是 2026-02/03 的重构清单，进度条与勾选状态均已过时。
> 现状：阶段一（巨型函数拆分）、阶段二（嵌套深度）、阶段三（重复代码提取）已完成——`src/checker/`（20 个文件）、`src/parser/`、`src/codegen/c99/` 目录化即是结果；
> **阶段四（Union 数据结构重构）在 Uya 上不适用**：Uya 语言没有 union 特性，AST/Type 的字段扁平化就是设计本身（见 `src/ast.uya` 顶部注释）；
> 阶段五/六（测试现代化、代码质量）由后续工作部分替代，不再按本清单执行。若需要新的重构目标，请新开文档而不是复用本文件状态。

**最后更新**：2026-02-21
**总工期**：6 周（30 天）

---

## 阶段一：巨型函数拆分 [██████████] 100% ✅

### 1.1 添加 Type 辅助函数 ✅

- [x] 在 `src/checker/type_utils.uya` 添加以下辅助函数：
  - [x] `make_void_type()` - 创建 void 类型
  - [x] `make_i32_type()` - 创建 i32 类型
  - [x] `make_i64_type()` - 创建 i64 类型
  - [x] `make_f64_type()` - 创建 f64 类型
  - [x] `make_bool_type()` - 创建 bool 类型
  - [x] `make_usize_type()` - 创建 usize 类型
  - [x] `make_pointer_type(arena, pointee, is_ffi)` - 创建指针类型
  - [x] `make_array_type(arena, element, size)` - 创建数组类型
  - [x] `make_slice_type(arena, element)` - 创建切片类型
  - [x] `make_named_type(kind, name)` - 创建命名类型
  - [x] `make_error_union_type(arena, payload)` - 创建错误联合类型
  - [x] `make_atomic_type(arena, inner)` - 创建原子类型
  - [x] `is_void_type(t)` - 检查 void 类型
  - [x] `is_pointer_type(t)` - 检查指针类型
  - [x] `is_error_type(t)` - 检查错误类型
  - [x] `is_error_union_type(t)` - 检查错误联合类型
- [x] `type_to_string()` - 已存在于 `type_utils.uya`
- [x] `type_equals()` - 已存在于 `type_utils.uya`
- [x] 运行 `make check` 验证 - **通过**
- [x] Git 提交: `583ba71 refactor(stage1): 添加 Type 辅助函数`

### 1.2 拆分 `checker_infer_type` ✅

- [x] 分析函数结构：1223 行，37 个 else if 分支
- [x] 使用辅助函数替换简单类型返回：
  - [x] AST_NUMBER → `make_i32_type()`
  - [x] AST_FLOAT → `make_f64_type()`
  - [x] AST_BOOL → `make_bool_type()`
  - [x] AST_USIZE_FROM_PTR → `make_usize_type()`
  - [x] AST_SRC_LINE/SRC_COL → `make_i32_type()`
  - [x] AST_SIZEOF/ALIGNOF/LEN → `make_i32_type()`
  - [x] 所有错误返回 → `make_void_type()`（50+ 处）
- [x] 代码统计：删除 157 行，新增 79 行，净减少 78 行
- [x] 验证通过：414 测试，自举成功
- [x] Git 提交: `e3b35b1 refactor(stage1): checker_infer_type 使用辅助函数重构`
- [x] 按表达式类型拆分为独立函数：
  - [x] `infer_call_expr(checker, expr)` - 调用表达式推断
  - [x] `infer_member_access(checker, expr)` - 成员访问推断
  - [x] `infer_match_expr(checker, expr)` - match 表达式推断
  - [x] `infer_syscall(checker, expr)` - syscall 推断
  - [x] `infer_unary_expr(checker, expr)` - 一元表达式推断
  - [x] `infer_array_access(checker, expr)` - 数组访问推断
  - [x] `infer_print_expr(checker, expr)` - @print/@println 推断
  - [x] `infer_catch_expr(checker, expr)` - catch 表达式推断
- [x] 函数从 1223 行减少到 **474 行**（目标 ≤500 行）
- [x] 验证通过：414 测试，自举成功
- [x] Git 提交: `0be615d refactor(stage1): 继续拆分 checker_infer_type 至 474 行`

### 1.3 拆分 `gen_stmt` ✅

- [x] 分析 `src/codegen/c99/stmt.uya` 中 `gen_stmt` 函数：1593 行
- [x] 按语句类型拆分为独立函数：
  - [x] `gen_if_stmt(codegen, node)` - if 语句生成
  - [x] `gen_while_stmt(codegen, node)` - while 语句生成
  - [x] `gen_break_stmt(codegen)` - break 语句生成
  - [x] `gen_continue_stmt(codegen)` - continue 语句生成
  - [x] `gen_for_stmt(codegen, node)` - for 语句生成
  - [x] `gen_for_range(codegen, node, body)` - for range 循环
  - [x] `gen_for_array(codegen, node, body)` - for 数组遍历
  - [x] `gen_for_iterator(codegen, ...)` - 迭代器接口循环
  - [x] `gen_for_array_ref(codegen, ...)` - 数组引用迭代
  - [x] `gen_for_array_value(codegen, ...)` - 数组值迭代
  - [x] `gen_return_stmt(codegen, node)` - return 语句生成
  - [x] `gen_return_array(codegen, ...)` - 数组返回值
  - [x] `gen_return_normal(codegen, ...)` - 普通返回值
  - [x] `gen_return_error_union(codegen, ...)` - 错误联合返回值
  - [x] `gen_assign_stmt(codegen, node)` - 赋值语句生成
  - [x] `gen_assign_atomic(codegen, ...)` - 原子赋值
  - [x] `gen_var_decl_stmt(codegen, node)` - 变量声明生成
  - [x] `gen_match_stmt(codegen, node)` - match 语句生成
  - [x] `gen_block_stmt(codegen, node)` - 块语句生成
  - [x] `gen_destructure_decl(codegen, node)` - 解构声明生成
- [x] 当前进度：1593 → 52 行（-96.7%，目标达成）
- [x] 目标：≤500 行 ✅
- [x] 运行 `make check` 验证 - 通过
- [x] Git 提交: `3b85361 refactor(codegen): extract gen_match_stmt from gen_stmt`

### 1.4 拆分 `gen_expr` ✅

- [x] 分析 `src/codegen/c99/expr.uya` 中 `gen_expr` 函数：2422 行
- [x] 按表达式类型拆分为独立函数：
  - [x] `gen_call_expr(codegen, node)` - 调用表达式生成 (678 行)
  - [x] `gen_binary_expr(codegen, node)` - 二元表达式生成 (259 行)
  - [x] `gen_member_access(codegen, node)` - 成员访问生成 (146 行)
  - [x] `gen_sizeof_expr(codegen, node)` - sizeof 表达式生成 (132 行)
  - [x] `gen_len_expr(codegen, node)` - len 表达式生成 (80 行)
  - [x] `gen_struct_init(codegen, node)` - 结构体初始化生成 (100 行)
  - [x] `gen_match_expr(codegen, node)` - match 表达式生成 (123 行)
  - [x] `gen_catch_expr(codegen, node)` - catch 表达式生成 (91 行)
  - [x] `gen_array_access(codegen, node)` - 数组访问生成 (52 行)
  - [x] `gen_cast_expr(codegen, node)` - 类型转换生成 (89 行)
  - [x] `gen_array_literal(codegen, node)` - 数组字面量生成 (31 行)
  - [x] `gen_slice_expr(codegen, node)` - 切片表达式生成 (32 行)
  - [x] `gen_print_expr(codegen, node)` - @print/@println 生成 (69 行)
  - [x] `gen_try_expr(codegen, node)` - try 表达式生成 (57 行)
  - [x] `gen_unary_expr(codegen, node)` - 一元表达式生成 (21 行)
- [x] 更新 `gen_expr` 为分发函数（495 行，目标达成）
- [x] 运行 `make check` 验证 - 通过
- [x] Git 提交: `e2622a4 refactor(codegen): extract branches from gen_expr`

---

## 阶段二：嵌套深度优化 [██████████] 100% ✅

### 2.1 提前返回优化

- [x] 扫描所有嵌套深度 > 3 层的函数
- [x] 重构为提前返回模式
- [x] 重点文件：
  - [x] `src/checker/check_expr.uya` - Uya 所有权限制无法提取循环变量（保持现状）
  - [x] `src/checker/check_stmt.uya` - 已提取辅助函数
  - [x] `src/codegen/c99/stmt.uya` - 已提取辅助函数
  - [x] `src/codegen/c99/expr.uya` - 已提取辅助函数
- [x] 运行 `make check` 验证 - 通过

### 2.2 提取辅助函数

- [x] 识别重复的条件检查模式
- [x] 提取辅助函数（codegen/c99/stmt.uya）：
  - [x] `gen_var_decl_empty_struct_init` - 空结构体初始化
  - [x] `gen_var_decl_struct_init_memcpy` - 结构体数组字段 memcpy
  - [x] `gen_var_decl_void_type` - void 类型变量声明
  - [x] `should_use_va_list` - va_list 检测
  - [x] `emit_pointer_const_decl` - 指针类型 const 声明
- [x] 提取辅助函数（checker/check_stmt.uya）：
  - [x] `method_signature_exists` - 方法签名去重检查
- [x] 提取辅助函数（codegen/c99/expr.uya）：
  - [x] `is_string_function` - 字符串函数检测
  - [x] `gen_error_value_comparison` - 错误类型比较
  - [x] `gen_struct_field_comparison` - 结构体字段比较
  - [x] `gen_struct_memcmp_comparison` - 结构体 memcmp 比较
- [x] 运行 `make check` 验证 - 通过

### 2.3 嵌套深度改进记录

| 函数 | 原始行数 | 当前行数 | 变化 | 状态 |
|------|----------|----------|------|------|
| `gen_var_decl_stmt` | 638 | 398 | -38% | ✅ 已优化 |
| `checker_check_struct_decl` | 178 | 166 | -7% | ✅ 已优化 |
| `gen_call_expr` | 680 | 658 | -3% | ✅ 已优化 |
| `gen_binary_expr` | 259 | 181 | -30% | ✅ 已优化 |
| `checker_infer_type` | 474 | 474 | 0% | ⏭️ 跳过（分发函数，拆分降低可读性） |
| `infer_match_expr` | 114 | 114 | 0% | ⏭️ 跳过（Uya 所有权限制） |

### 2.4 已提取的辅助函数（共 10 个）

**codegen/c99/stmt.uya (5 个):**
- `gen_var_decl_empty_struct_init` - 空结构体初始化
- `gen_var_decl_struct_init_memcpy` - 结构体数组字段 memcpy
- `gen_var_decl_void_type` - void 类型变量声明
- `should_use_va_list` - va_list 检测
- `emit_pointer_const_decl` - 指针类型 const 声明

**checker/check_stmt.uya (1 个):**
- `method_signature_exists` - 方法签名去重检查

**codegen/c99/expr.uya (4 个):**
- `is_string_function` - 字符串函数检测
- `gen_error_value_comparison` - 错误类型比较
- `gen_struct_field_comparison` - 结构体字段比较
- `gen_struct_memcmp_comparison` - 结构体 memcmp 比较

---

## 阶段三：重复代码提取 [██████████] 100% ✅

### 3.1 提取代码生成辅助函数

- [x] 添加代码生成辅助函数（utils.uya）：
  - [x] `c99_emit_newline` - 输出换行（44 处）
  - [x] `c99_emit_semi_newline` - 输出分号换行（36 处）
  - [x] `c99_emit_comma_space` - 输出逗号空格（43 处）
  - [x] `c99_emit_close_brace_newline` - 输出右花括号换行（14 处）
- [x] **总计替换 137 处 fputs 模式**
- [x] 继续提取更多辅助函数：
  - [x] `emit_type(codegen, t)` - 已有 `c99_type_to_c` 实现
  - [x] `emit_defer_chain(codegen, defers)` - 已有 `emit_defer_cleanup` 实现
- [x] 运行 `make check` 验证 - 通过

### 3.2 统一类型检查函数调用

- [x] 搜索所有 `kind == TypeKind.XXX` 模式
- [x] 添加类型检查辅助函数（type_utils.uya）：
  - [x] `is_bool_type(t)` - 布尔类型检查
  - [x] `is_struct_type(t)` - 结构体类型检查
  - [x] `is_union_type(t)` - 联合体类型检查
  - [x] `is_array_type(t)` - 数组类型检查
  - [x] `is_slice_type(t)` - 切片类型检查
  - [x] `is_tuple_type(t)` - 元组类型检查
  - [x] `is_enum_type(t)` - 枚举类型检查
  - [x] `is_interface_type(t)` - 接口类型检查
  - [x] `is_int_limit_type(t)` - int_limit 类型检查
  - [x] `is_atomic_type(t)` - 原子类型检查
  - [x] `is_generic_param_type(t)` - 泛型参数类型检查
- [x] 替换直接类型比较为辅助函数调用
- [x] 运行 `make check` 验证 - 通过

### 3.3 提取通用模式

- [x] 识别并提取以下模式：
  - [x] 错误报告模式 - 已有 `checker_report_error` 和 `checker_report_error_ex`
  - [x] 符号查找模式 - 已有 `symbol_table_lookup`
  - [x] 类型推断模式 - 已有 `type_from_ast` 等函数
- [x] 运行 `make check` 验证 - 通过

---

## 阶段四：Union 数据结构重构 [████░░░░░░] 40%

> **详细方案**：`docs/REFACTOR_PLAN_V2_STAGE4_DETAILED.md`

### 4.1 Type 结构体 Union 化

#### Step 1: 添加 TypeData union + 访问器函数 ✅

- [x] 在 `src/checker/types.uya` 添加：
  - [x] `union TypeData` 定义（使用 tagged union）
  - [x] 辅助结构体（PointerData, ArrayData, SliceData 等）
  - [x] 在 `Type` 结构体添加 `data: TypeData` 字段
- [x] 更新构造函数（type_utils.uya）：
  - [x] `make_empty_type_data()` - 创建空 TypeData
  - [x] `make_void_type()` - 同时设置新旧字段
  - [x] `make_i32_type()` - 同时设置新旧字段
  - [x] `make_i64_type()` - 同时设置新旧字段
  - [x] `make_f64_type()` - 同时设置新旧字段
  - [x] `make_bool_type()` - 同时设置新旧字段
  - [x] `make_usize_type()` - 同时设置新旧字段
  - [x] `make_pointer_type()` - 同时设置新旧字段
  - [x] `make_array_type()` - 同时设置新旧字段
  - [x] `make_slice_type()` - 同时设置新旧字段
  - [x] `make_named_type()` - 同时设置新旧字段
  - [x] `make_error_union_type()` - 同时设置新旧字段
  - [x] `make_atomic_type()` - 同时设置新旧字段
- [x] 创建 `src/checker/type_accessors.uya`：
  - [x] 命名类型访问器（type_get_name, type_get_enum_name 等）
  - [x] 指针类型访问器（type_get_pointer_to, type_is_ffi_pointer）
  - [x] 数组类型访问器（type_get_array_element, type_get_array_size）
  - [x] 切片类型访问器（type_get_slice_element, type_get_slice_len）
  - [x] 元组类型访问器（type_get_tuple_elements, type_get_tuple_count）
  - [x] 错误联合类型访问器（type_get_error_payload, type_get_error_id）
  - [x] 原子类型访问器（type_get_atomic_inner）
  - [x] 泛型参数访问器（type_get_generic_param_name）
  - [x] 结构体泛型访问器（type_get_struct_type_args, type_get_struct_type_arg_count）
  - [x] 类型设置器函数（type_set_* 系列）
- [x] 运行 `make check` 验证 - **通过（414 测试）**
- [x] Git 提交: `4c87670 refactor(stage4): 添加 TypeData union 和更新构造函数`
- [ ] 迁移字段访问到访问器函数（下一步）

> **详细方案**：`docs/REFACTOR_PLAN_V2_STAGE4_DETAILED.md`

### 4.1 Type 结构体 Union 化

#### Step 1: 添加 TypeData union + 访问器函数（1 天）

- [ ] 在 `src/checker/types.uya` 添加：
  - [ ] `union TypeData` 定义
  - [ ] 辅助结构体（PointerData, ArrayData, SliceData 等）
  - [ ] 在 `Type` 结构体添加 `data: TypeData` 字段
- [ ] 创建 `src/checker/type_accessors.uya`：
  - [ ] `type_get_name(t)` - 获取命名类型名称
  - [ ] `type_get_pointer_to(t)` - 获取指针目标类型
  - [ ] `type_is_ffi_pointer(t)` - 检查是否为 FFI 指针
  - [ ] `type_get_array_element(t)` - 获取数组元素类型
  - [ ] `type_get_array_size(t)` - 获取数组大小
  - [ ] `type_get_slice_element(t)` - 获取切片元素类型
  - [ ] `type_get_tuple_elements(t)` - 获取元组元素
  - [ ] `type_get_error_payload(t)` - 获取错误联合负载类型
  - [ ] `type_get_atomic_inner(t)` - 获取原子内部类型
  - [ ] `type_get_generic_param_name(t)` - 获取泛型参数名
  - [ ] `type_get_struct_type_args(t)` - 获取结构体类型参数
- [ ] 创建 `src/checker/type_constructors.uya`：
  - [ ] 修改所有构造函数，同时设置新旧字段
- [ ] 运行 `make check` 验证

#### Step 2: 迁移高频字段访问（2 天）

- [ ] 迁移 `struct_name` 字段访问（52 处）
  - [ ] `src/checker/check_expr.uya` (10 处)
  - [ ] `src/checker/check_call.uya` (13 处)
  - [ ] `src/checker/check_stmt.uya` (5 处)
  - [ ] `src/checker/symbols.uya` (6 处)
  - [ ] 其他文件 (18 处)
- [ ] 迁移 `pointer_to` 字段访问（47 处）
- [ ] 迁移 `element_type` 字段访问（35 处）
- [ ] 迁移 `slice_element_type` 字段访问（23 处）
- [ ] 迁移 `struct_type_args` 字段访问（23 处）
- [ ] 迁移 `error_union_payload_type` 字段访问（21 处）
- [ ] 迁移 `enum_name` 字段访问（21 处）
- [ ] 每个文件完成后运行 `make check` 验证

#### Step 3: 迁移中频字段访问（1 天）

- [ ] 迁移 `struct_type_arg_count` 字段访问（19 处）
- [ ] 迁移 `array_size` 字段访问（12 处）
- [ ] 迁移 `tuple_element_types` 字段访问（14 处）
- [ ] 迁移 `tuple_count` 字段访问（11 处）
- [ ] 迁移 `atomic_inner_type` 字段访问（11 处）
- [ ] 迁移 `generic_param_name` 字段访问（11 处）
- [ ] 运行 `make check` 验证

#### Step 4: 迁移低频字段访问（1 天）

- [ ] 迁移 `union_name` 字段访问（8 处）
- [ ] 迁移 `is_ffi_pointer` 字段访问（8 处）
- [ ] 迁移 `interface_name` 字段访问（8 处）
- [ ] 迁移 `slice_len` 字段访问（3 处）
- [ ] 迁移 `error_error_id` 字段访问（3 处）
- [ ] 运行 `make check` 验证

#### Step 5: 移除旧字段 + 验证（1-2 天）

- [ ] 确认所有字段访问都已迁移到访问器
- [ ] 移除 `Type` 结构体中的旧字段
- [ ] 移除构造函数中的旧字段设置
- [ ] 运行 `make check` 完整验证
- [ ] 运行 `make backup` 备份
- [ ] 创建 git 标签：`git tag stage4.1.complete`

### 4.2 ASTNode 结构体 Union 化

#### Step 1: 添加 ASTNodeData union + 访问器函数（2 天）

- [ ] 在 `src/ast.uya` 添加：
  - [ ] `union ASTNodeData` 定义
  - [ ] 所有数据结构体定义（ProgramData, FnDeclData, VarDeclData 等）
  - [ ] 在 `ASTNode` 结构体添加 `data: ASTNodeData` 字段
- [ ] 创建 `src/ast_accessors.uya`：
  - [ ] 声明节点访问器（fn_decl, var_decl, struct_decl 等）
  - [ ] 表达式节点访问器（binary_expr, call_expr, member_access 等）
  - [ ] 语句节点访问器（if_stmt, for_stmt, return_stmt 等）
  - [ ] 字面量节点访问器（identifier, number, string_literal 等）
  - [ ] 类型节点访问器（type_named, type_pointer, type_array 等）
- [ ] 创建 `src/ast_constructors.uya`：
  - [ ] 修改 `ast_new_node` 函数
  - [ ] 修改所有节点创建函数
- [ ] 运行 `make check` 验证

#### Step 2: 迁移声明节点（3 天）

- [ ] 迁移 `fn_decl_*` 字段访问（416 处）
  - [ ] `src/checker/` 目录（约 200 处）
  - [ ] `src/codegen/c99/` 目录（约 150 处）
  - [ ] `src/parser/` 目录（约 66 处）
- [ ] 迁移 `var_decl_*` 字段访问（332 处）
- [ ] 迁移 `program_*` 字段访问（251 处）
- [ ] 迁移 `struct_decl_*` 字段访问（219 处）
- [ ] 迁移 `identifier_*` 字段访问（178 处）
- [ ] 每个节点组完成后运行 `make check` 验证

#### Step 3: 迁移表达式节点（3 天）

- [ ] 迁移 `call_expr_*` 字段访问（152 处）
- [ ] 迁移 `cast_expr_*` 字段访问（147 处）
- [ ] 迁移 `match_expr_*` 字段访问（104 处）
- [ ] 迁移 `member_access_*` 字段访问（97 处）
- [ ] 迁移 `binary_expr_*` 字段访问（88 处）
- [ ] 迁移 `struct_init_*` 字段访问（84 处）
- [ ] 迁移 `array_literal_*` 字段访问（81 处）
- [ ] 迁移其他表达式节点
- [ ] 运行 `make check` 验证

#### Step 4: 迁移语句节点（2 天）

- [ ] 迁移 `block_*` 字段访问（156 处）
- [ ] 迁移 `for_stmt_*` 字段访问（109 处）
- [ ] 迁移 `if_stmt_*` 字段访问（58 处）
- [ ] 迁移 `return_stmt_*` 字段访问（52 处）
- [ ] 迁移 `while_stmt_*` 字段访问（45 处）
- [ ] 迁移 `defer_stmt_*` 字段访问（30 处）
- [ ] 迁移其他语句节点
- [ ] 运行 `make check` 验证

#### Step 5: 移除旧字段 + 验证（2-3 天）

- [ ] 确认所有字段访问都已迁移到访问器
- [ ] 移除 `ASTNode` 结构体中的旧字段
- [ ] 移除 `ast_new_node` 中的旧字段初始化
- [ ] 运行 `make check` 完整验证
- [ ] 运行 `make backup` 备份
- [ ] 创建 git 标签：`git tag stage4.2.complete`

---

## 阶段五：测试现代化 [░░░░░░░░░░] 0%

### 5.1 重构测试为 test 语句风格

- [ ] 扫描所有测试文件中的 `fn test_XXX` 模式
- [ ] 重构为 `test "description" {}` 风格
- [ ] 重点文件：
  - [ ] `tests/test_basic.uya`
  - [ ] `tests/test_types.uya`
  - [ ] `tests/test_generics.uya`
  - [ ] 其他测试文件
- [ ] 移除测试文件中的 `export fn main()` 函数
- [ ] 运行 `make tests` 验证

### 5.2 添加增量测试验证

- [ ] 为重构的函数添加独立测试：
  - [ ] `tests/test_type_accessors.uya` - Type 访问器测试
  - [ ] `tests/test_ast_accessors.uya` - ASTNode 访问器测试
- [ ] 运行 `make tests` 验证

---

## 阶段六：代码质量改进 [░░░░░░░░░░] 0%

### 6.1 统一错误处理模式

- [ ] 审计所有函数的返回类型
- [ ] 统一错误处理规范：
  - 类型推断函数：返回 `Type`，错误时返回 `make_void_type()`
  - 检查函数：返回 `i32`（0=失败，1=成功）
  - 生成函数：返回 `void`，通过 `codegen.error_count` 跟踪错误
- [ ] 运行 `make check` 验证

### 6.2 常量集中定义

- [ ] 创建 `src/constants.uya` 文件
- [ ] 集中定义以下常量：
  - [ ] `MAX_MONO_INSTANCES: i32 = 512`
  - [ ] `MAX_DEFER_DEPTH: i32 = 64`
  - [ ] `MAX_TYPE_PARAMS: i32 = 16`
  - [ ] `TEMP_BUF_SIZE: i32 = 4096`
  - [ ] `MAX_SCOPE_DEPTH: i32 = 64`
  - [ ] `SYMBOL_TABLE_SIZE: i32 = 32768`
- [ ] 替换所有魔法数字
- [ ] 运行 `make check` 验证

### 6.3 移除未使用变量

- [ ] 清理以下未使用变量：
  - [ ] `src/checker/check_expr.uya:1259` - `match_union_decl`
  - [ ] `src/codegen/c99/stmt.uya:504` - `ret_c` 部分分支
- [ ] 运行 `make check` 验证

---

## 验收清单

### 代码规范

- [ ] 所有函数 ≤ 50 行
- [ ] 所有嵌套深度 ≤ 3 层
- [ ] 重复代码减少 50%+
- [ ] 测试使用 `test "name" {}` 风格

### Union 数据结构

- [ ] Type 结构体使用 union 封装变体数据
- [ ] ASTNode 结构体使用 union 封装变体数据
- [ ] 所有字段访问使用访问器函数
- [ ] match 完备性检查通过

### 功能验证

- [ ] `make check` 通过（自举 + 测试）
- [ ] 自举编译时间 ≤ 2s
- [ ] 无新增编译警告
- [ ] Type 内存占用减少 50%+
- [ ] ASTNode 内存占用减少 70%+

---

## 进度追踪

| 阶段 | 预估天数 | 实际天数 | 状态 |
|------|----------|----------|------|
| 阶段一 | 5 天 | - | 未开始 |
| 阶段二 | 3 天 | - | 未开始 |
| 阶段三 | 4 天 | - | 未开始 |
| 阶段四.1 | 5-7 天 | - | 未开始 |
| 阶段四.2 | 10-13 天 | - | 未开始 |
| 阶段五 | 2 天 | - | 未开始 |
| 阶段六 | 2 天 | - | 未开始 |
| **总计** | **31-36 天** | **-** | **未开始** |

---

## 每日工作流程

### 开始工作前

```bash
# 1. 拉取最新代码
git pull

# 2. 验证当前状态
make check

# 3. 创建工作分支
git checkout -b refactor/stage-N-task-M
```

### 完成任务后

```bash
# 1. 验证代码
make check

# 2. 提交更改
git add -A
git commit -m "refactor(stage-N): 任务描述"

# 3. 创建标签（重要节点）
git tag stage-N.step-M

# 4. 备份（阶段完成时）
make backup
```

### 遇到问题时

```bash
# 1. 回滚到上一个提交
git checkout -- .

# 2. 或回滚到上一个标签
git reset --hard stage-N.step-M

# 3. 重新开始当前任务
```

---

## 参考资料

- `docs/REFACTOR_PLAN_V2.md` - 重构计划总览
- `docs/REFACTOR_PLAN_V2_STAGE4_DETAILED.md` - 阶段四详细方案
- `docs/REFACTOR_PLAN_V2_REVIEW.md` - 可行性评审报告
- `.codebuddy/skills/uya-development.md` - Uya 开发技能文档
- `docs/uya_ai_prompt.md` - Uya 语言完整语法（v0.47）
- `.codebuddy/rules/uya-dev-flow.mdc` - Uya 开发流程规则
