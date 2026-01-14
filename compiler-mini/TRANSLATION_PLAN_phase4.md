# 阶段4：Parser 模块翻译计划

## 概述

本文档详细规划了将 `src/parser.c/h`（2587行）翻译为 `uya-src/parser.uya` 的完整策略和步骤。

**文件规模**：
- `src/parser.c`: 2587 行
- `src/parser.h`: 63 行
- **总计**: 2650 行

**工作量估算**：8-12 小时

---

## 翻译进度

**最后更新**：2026-01-13

**当前状态**：阶段7已完成，所有翻译工作已完成！

**代码行数统计**：
- C99 版本（`src/parser.c`）：2587 行
- Uya Mini 版本（`uya-src/parser.uya`，当前）：2741 行
- 进度：100% ✅
- 行数增加：+154 行（约 6%，主要因为 Uya Mini 语法更冗长）

**已完成阶段**：
- ✅ **阶段1**：准备工作（外部函数声明、文件结构、Parser结构体定义）
- ✅ **阶段2**：基础函数翻译（parser_init, parser_match, parser_consume, parser_expect, parser_peek_is_struct_init, arena_strdup_for_parser）
- ✅ **阶段3**：类型解析函数（parser_parse_type）
- ✅ **阶段4**：代码块解析函数（parser_parse_block）
- ✅ **阶段5**：声明解析函数（parser_parse_struct, parser_parse_enum, parser_parse_function, parser_parse_extern_function, parser_parse_declaration, parser_parse）
- ✅ **阶段6**：表达式解析函数（parser_parse_primary_expr, parser_parse_unary_expr, parser_parse_cast_expr, parser_parse_mul_expr, parser_parse_add_expr, parser_parse_rel_expr, parser_parse_eq_expr, parser_parse_and_expr, parser_parse_or_expr, parser_parse_assign_expr, parser_parse_expression）
- ✅ **阶段7**：语句解析函数（parser_parse_statement）

**验证状态**：
- ✅ **语法检查**：通过，无错误
- ✅ **函数完整性**：所有函数已翻译
- ⏳ **功能测试**：待进行（需要编译和运行测试）

---

## 函数结构分析

根据代码分析，parser.c 包含以下主要函数（按调用顺序组织）：

### 1. 基础函数（约150行）
- `parser_init` - 初始化函数
- `parser_match` - 辅助函数：检查Token类型
- `parser_consume` - 辅助函数：消费Token
- `parser_expect` - 辅助函数：期望Token
- `parser_peek_is_struct_init` - 辅助函数：检查结构体初始化
- `arena_strdup` - 辅助函数：字符串复制（需替换为 `arena_strdup_from_literal`）

### 2. 类型解析函数（约110行）
- `parser_parse_type` - 类型解析入口

### 3. 代码块解析函数（约75行）
- `parser_parse_block` - 代码块解析

### 4. 声明解析函数（约600行）
- `parser_parse_struct` - 结构体声明
- `parser_parse_enum` - 枚举声明
- `parser_parse_function` - 函数声明
- `parser_parse_extern_function` - extern函数声明
- `parser_parse_declaration` - 声明入口
- `parser_parse` - 顶层解析入口

### 5. 表达式解析函数（约1400行）
- `parser_parse_primary_expr` - 基础表达式（约900行，最复杂）
  - 数字、布尔、字符串字面量
  - 标识符
  - sizeof/alignof/len表达式
  - 函数调用
  - 结构体字面量
  - 数组字面量
  - 字段访问和数组访问
- `parser_parse_unary_expr` - 一元表达式
- `parser_parse_cast_expr` - 类型转换表达式
- `parser_parse_mul_expr` - 乘除模表达式
- `parser_parse_add_expr` - 加减表达式
- `parser_parse_rel_expr` - 比较表达式
- `parser_parse_eq_expr` - 相等性表达式
- `parser_parse_and_expr` - 逻辑与表达式
- `parser_parse_or_expr` - 逻辑或表达式
- `parser_parse_assign_expr` - 赋值表达式
- `parser_parse_expression` - 表达式入口

### 6. 语句解析函数（约280行）
- `parser_parse_statement` - 语句入口
  - return语句
  - break/continue语句
  - if语句
  - while语句
  - for语句
  - 变量声明
  - 代码块
  - 表达式语句

---

## 翻译步骤

### 阶段1：准备工作（约30分钟）

1. **创建 parser.uya 文件结构**
   - 添加文件头注释
   - 添加外部函数声明（参考 lexer.uya）

2. **外部函数声明**
   - `extern fn fprintf(stream: *void, format: *byte, ...) i32;`（来自 str_utils.uya）
   - `extern fn atoi(s: *byte) i32;`（字符串转整数，需添加）
   - `extern fn strlen(s: *byte) i32;`（来自 str_utils.uya）
   - `extern fn strcmp(s1: *byte, s2: *byte) i32;`（来自 str_utils.uya）
   - `extern fn memcpy(dest: &byte, src: &byte, n: i32) &void;`（内存复制）
   - `extern fn arena_alloc(arena: &Arena, size: i32) &void;`（来自 arena.uya）
   - `extern fn ast_new_node(type: ASTNodeType, line: i32, column: i32, arena: &Arena) &ASTNode;`（来自 ast.uya）
   - `extern fn lexer_next_token(lexer: &Lexer, arena: &Arena) &Token;`（来自 lexer.uya）

3. **类型定义引用**
   - 假设 `Parser`, `Lexer`, `Token`, `Arena`, `ASTNode`, `ASTNodeType`, `TokenType`, `EnumVariant` 已定义

4. **常量定义**
   - `const stderr: *void = ...;`（如果需要，或直接使用数字常量）

### 阶段2：基础函数翻译（约2小时）

按顺序翻译以下函数：

1. **parser_init**（~20行）
   - 映射：`Parser *` → `&Parser`
   - 映射：`Lexer *` → `&Lexer`
   - 映射：`Arena *` → `&Arena`

2. **parser_match**（~10行）
   - 映射：`int` → `i32`
   - 映射：`TokenType` → `TokenType`（枚举保持不变）

3. **parser_consume**（~15行）
   - 映射：`Token *` → `&Token`

4. **parser_expect**（~15行）

5. **parser_peek_is_struct_init**（~55行）
   - 注意：`size_t` → `i32`
   - 注意：需要保存和恢复 lexer 状态

6. **arena_strdup**（~15行，替换为使用 `arena_strdup_from_literal`）
   - 注意：C99 版本使用 `memcpy`，Uya Mini 版本应该使用 `arena_strdup_from_literal`（来自 lexer.uya）
   - 或者：如果需要按长度复制，使用 `arena_strdup`（来自 lexer.uya）

### 阶段3：类型解析函数（约1.5小时）

1. **parser_parse_type**（~110行）
   - 关键映射：`node->data.type_pointer.pointed_type` → `node.type_pointer_pointed_type`
   - 关键映射：`node->data.type_pointer.is_ffi_pointer` → `node.type_pointer_is_ffi_pointer`
   - 关键映射：`node->data.type_array.element_type` → `node.type_array_element_type`
   - 关键映射：`node->data.type_array.size_expr` → `node.type_array_size_expr`
   - 关键映射：`node->data.type_named.name` → `node.type_named_name`

### 阶段4：代码块解析函数（约1小时）

1. **parser_parse_block**（~75行）
   - 关键映射：`node->data.block.stmts` → `node.block_stmts`
   - 关键映射：`node->data.block.stmt_count` → `node.block_stmt_count`
   - 注意：动态数组扩展逻辑（`sizeof(ASTNode *)` → 指针大小，通常是 8 字节）

### 阶段5：声明解析函数（约3小时）

按顺序翻译：

1. **parser_parse_struct**（~135行）
   - 关键映射：`node->data.struct_decl.name` → `node.struct_decl_name`
   - 关键映射：`node->data.struct_decl.fields` → `node.struct_decl_fields`
   - 关键映射：`node->data.struct_decl.field_count` → `node.struct_decl_field_count`

2. **parser_parse_enum**（~130行）
   - 关键映射：`node->data.enum_decl.name` → `node.enum_decl_name`
   - 关键映射：`node->data.enum_decl.variants` → `node.enum_decl_variants`
   - 关键映射：`node->data.enum_decl.variant_count` → `node.enum_decl_variant_count`

3. **parser_parse_function**（~150行）
   - 关键映射：`node->data.fn_decl.name` → `node.fn_decl_name`
   - 关键映射：`node->data.fn_decl.params` → `node.fn_decl_params`
   - 关键映射：`node->data.fn_decl.param_count` → `node.fn_decl_param_count`
   - 关键映射：`node->data.fn_decl.return_type` → `node.fn_decl_return_type`
   - 关键映射：`node->data.fn_decl.body` → `node.fn_decl_body`

4. **parser_parse_extern_function**（~170行）
   - 类似 `parser_parse_function`，但 body 为 null

5. **parser_parse_declaration**（~25行）
   - 声明入口，调用上述函数

6. **parser_parse**（~75行）
   - 顶层解析入口
   - 关键映射：`node->data.program.decls` → `node.program_decls`
   - 关键映射：`node->data.program.decl_count` → `node.program_decl_count`
   - 注意：错误处理使用 `fprintf(stderr, ...)`

### 阶段6：表达式解析函数（约4小时）

按优先级从高到低翻译（递归调用关系）：

1. **parser_parse_primary_expr**（~900行，最复杂）
   - 数字字面量：`node->data.number.value` → `node.number_value`，使用 `atoi`
   - 布尔字面量：`node->data.bool_literal.value` → `node.bool_literal_value`
   - 字符串字面量：`node->data.string_literal.value` → `node.string_literal_value`
   - 标识符：`node->data.identifier.name` → `node.identifier_name`
   - sizeof表达式：`node->data.sizeof_expr.target` → `node.sizeof_expr_target`
   - alignof表达式：`node->data.alignof_expr.target` → `node.alignof_expr_target`
   - len表达式：`node->data.len_expr.array` → `node.len_expr_array`
   - 函数调用：`node->data.call_expr.callee` → `node.call_expr_callee`
   - 字段访问：`node->data.member_access.object` → `node.member_access_object`
   - 数组访问：`node->data.array_access.array` → `node.array_access_array`
   - 结构体字面量：`node->data.struct_init.*` → `node.struct_init_*`
   - 数组字面量：`node->data.array_literal.*` → `node.array_literal_*`

2. **parser_parse_unary_expr**（~40行）
   - 关键映射：`node->data.unary_expr.op` → `node.unary_expr_op`
   - 关键映射：`node->data.unary_expr.operand` → `node.unary_expr_operand`

3. **parser_parse_cast_expr**（~40行）
   - 关键映射：`node->data.cast_expr.expr` → `node.cast_expr_expr`
   - 关键映射：`node->data.cast_expr.target_type` → `node.cast_expr_target_type`

4. **parser_parse_mul_expr**（~50行）
   - 关键映射：`node->data.binary_expr.*` → `node.binary_expr_*`

5. **parser_parse_add_expr**（~50行）

6. **parser_parse_rel_expr**（~50行）

7. **parser_parse_eq_expr**（~50行）

8. **parser_parse_and_expr**（~40行）

9. **parser_parse_or_expr**（~40行）

10. **parser_parse_assign_expr**（~40行）
    - 关键映射：`node->data.assign.dest` → `node.assign_dest`
    - 关键映射：`node->data.assign.src` → `node.assign_src`

11. **parser_parse_expression**（~10行）
    - 表达式入口

### 阶段7：语句解析函数（约2小时）

1. **parser_parse_statement**（~280行）
   - return语句：`node->data.return_stmt.expr` → `node.return_stmt_expr`
   - if语句：`node->data.if_stmt.*` → `node.if_stmt_*`
   - while语句：`node->data.while_stmt.*` → `node.while_stmt_*`
   - for语句：`node->data.for_stmt.*` → `node.for_stmt_*`
   - 变量声明：`node->data.var_decl.*` → `node.var_decl_*`
   - 赋值语句：`node->data.assign.*` → `node.assign_*`

---

## 关键映射规则

### 1. 类型映射

| C99 | Uya Mini | 说明 |
|-----|----------|------|
| `Parser *` | `&Parser` | 引用类型 |
| `Lexer *` | `&Lexer` | 引用类型 |
| `Arena *` | `&Arena` | 引用类型 |
| `Token *` | `&Token` | 引用类型 |
| `ASTNode *` | `&ASTNode` | 引用类型 |
| `ASTNode **` | `&(&ASTNode)` | 指针数组 |
| `int` | `i32` | 整数类型 |
| `size_t` | `i32` | 大小类型 |
| `const char *` | `&byte` 或 `*byte` | 字符串（参数用 `*byte`，内部用 `&byte`） |
| `NULL` | `null` | 空指针 |

### 2. AST 节点字段访问映射

**重要**：Uya Mini 不支持 union，所以 C99 的 `node->data.field_name` 映射为 Uya Mini 的 `node.field_name`。

| C99 | Uya Mini |
|-----|----------|
| `node->data.type_pointer.pointed_type` | `node.type_pointer_pointed_type` |
| `node->data.type_pointer.is_ffi_pointer` | `node.type_pointer_is_ffi_pointer` |
| `node->data.type_array.element_type` | `node.type_array_element_type` |
| `node->data.type_array.size_expr` | `node.type_array_size_expr` |
| `node->data.type_named.name` | `node.type_named_name` |
| `node->data.binary_expr.left` | `node.binary_expr_left` |
| `node->data.binary_expr.op` | `node.binary_expr_op` |
| `node->data.binary_expr.right` | `node.binary_expr_right` |
| `node->data.unary_expr.op` | `node.unary_expr_op` |
| `node->data.unary_expr.operand` | `node.unary_expr_operand` |
| `node->data.call_expr.callee` | `node.call_expr_callee` |
| `node->data.call_expr.args` | `node.call_expr_args` |
| `node->data.call_expr.arg_count` | `node.call_expr_arg_count` |
| `node->data.member_access.object` | `node.member_access_object` |
| `node->data.member_access.field_name` | `node.member_access_field_name` |
| `node->data.array_access.array` | `node.array_access_array` |
| `node->data.array_access.index` | `node.array_access_index` |
| `node->data.struct_init.struct_name` | `node.struct_init_struct_name` |
| `node->data.struct_init.field_names` | `node.struct_init_field_names` |
| `node->data.struct_init.field_values` | `node.struct_init_field_values` |
| `node->data.struct_init.field_count` | `node.struct_init_field_count` |
| `node->data.array_literal.elements` | `node.array_literal_elements` |
| `node->data.array_literal.element_count` | `node.array_literal_element_count` |
| `node->data.sizeof_expr.target` | `node.sizeof_expr_target` |
| `node->data.sizeof_expr.is_type` | `node.sizeof_expr_is_type` |
| `node->data.len_expr.array` | `node.len_expr_array` |
| `node->data.alignof_expr.target` | `node.alignof_expr_target` |
| `node->data.alignof_expr.is_type` | `node.alignof_expr_is_type` |
| `node->data.cast_expr.expr` | `node.cast_expr_expr` |
| `node->data.cast_expr.target_type` | `node.cast_expr_target_type` |
| `node->data.identifier.name` | `node.identifier_name` |
| `node->data.number.value` | `node.number_value` |
| `node->data.bool_literal.value` | `node.bool_literal_value` |
| `node->data.string_literal.value` | `node.string_literal_value` |
| `node->data.program.decls` | `node.program_decls` |
| `node->data.program.decl_count` | `node.program_decl_count` |
| `node->data.enum_decl.name` | `node.enum_decl_name` |
| `node->data.enum_decl.variants` | `node.enum_decl_variants` |
| `node->data.enum_decl.variant_count` | `node.enum_decl_variant_count` |
| `node->data.struct_decl.name` | `node.struct_decl_name` |
| `node->data.struct_decl.fields` | `node.struct_decl_fields` |
| `node->data.struct_decl.field_count` | `node.struct_decl_field_count` |
| `node->data.fn_decl.name` | `node.fn_decl_name` |
| `node->data.fn_decl.params` | `node.fn_decl_params` |
| `node->data.fn_decl.param_count` | `node.fn_decl_param_count` |
| `node->data.fn_decl.return_type` | `node.fn_decl_return_type` |
| `node->data.fn_decl.body` | `node.fn_decl_body` |
| `node->data.var_decl.name` | `node.var_decl_name` |
| `node->data.var_decl.type` | `node.var_decl_type` |
| `node->data.var_decl.init` | `node.var_decl_init` |
| `node->data.var_decl.is_const` | `node.var_decl_is_const` |
| `node->data.if_stmt.condition` | `node.if_stmt_condition` |
| `node->data.if_stmt.then_branch` | `node.if_stmt_then_branch` |
| `node->data.if_stmt.else_branch` | `node.if_stmt_else_branch` |
| `node->data.while_stmt.condition` | `node.while_stmt_condition` |
| `node->data.while_stmt.body` | `node.while_stmt_body` |
| `node->data.for_stmt.array` | `node.for_stmt_array` |
| `node->data.for_stmt.var_name` | `node.for_stmt_var_name` |
| `node->data.for_stmt.is_ref` | `node.for_stmt_is_ref` |
| `node->data.for_stmt.body` | `node.for_stmt_body` |
| `node->data.return_stmt.expr` | `node.return_stmt_expr` |
| `node->data.assign.dest` | `node.assign_dest` |
| `node->data.assign.src` | `node.assign_src` |
| `node->data.block.stmts` | `node.block_stmts` |
| `node->data.block.stmt_count` | `node.block_stmt_count` |

### 3. 函数调用映射

| C99 | Uya Mini |
|-----|----------|
| `lexer_next_token(lexer, arena)` | `lexer_next_token(lexer, arena)` |
| `ast_new_node(type, line, column, arena)` | `ast_new_node(type, line, column, arena)` |
| `arena_alloc(arena, size)` | `arena_alloc(arena, size)` |
| `arena_strdup(arena, src)` | `arena_strdup_from_literal(arena, src)` 或 `arena_strdup(arena, start, len)` |
| `strlen(str)` | `strlen(str)` |
| `strcmp(s1, s2)` | `strcmp(s1, s2)` |
| `atoi(str)` | `atoi(str)`（需声明 extern） |
| `memcpy(dest, src, len)` | `memcpy(dest, src, len)` |
| `fprintf(stderr, format, ...)` | `fprintf(stderr, format, ...)`（需声明 stderr） |

### 4. 语法映射

| C99 | Uya Mini |
|-----|----------|
| `if (condition)` | `if condition` |
| `while (condition)` | `while condition` |
| `for (init; cond; inc)` | `for expr \| id \| { ... }`（仅数组遍历） |
| `return value;` | `return value;` |
| `var->field` | `var.field` |
| `*ptr` | `*ptr`（解引用） |
| `&var` | `&var`（取地址） |
| `NULL` | `null` |
| `0` | `0`（整数） |
| `1` | `1`（整数） |
| `int x = 0;` | `var x: i32 = 0;` |
| `const int x = 0;` | `const x: i32 = 0;` |

### 5. sizeof 表达式映射

| C99 | Uya Mini |
|-----|----------|
| `sizeof(ASTNode *)` | `8`（64位系统，指针大小为8字节） |
| `sizeof(ASTNode **)` | `8`（指针大小） |
| `sizeof(EnumVariant)` | `16`（两个指针，每个8字节） |

**注意**：Uya Mini 不支持 `sizeof` 表达式（作为语言特性），但在翻译 C99 代码时，需要将这些 `sizeof` 替换为具体的数值。

---

## 特殊情况处理

### 1. 字符串复制

C99 版本中的 `arena_strdup` 函数使用 `memcpy`。在 Uya Mini 版本中：
- 如果源字符串是字面量（`*byte`），使用 `arena_strdup_from_literal`（来自 lexer.uya）
- 如果需要按长度复制，使用 `arena_strdup(arena, start, len)`（来自 lexer.uya）

### 2. 错误处理

C99 版本使用 `fprintf(stderr, ...)` 输出错误信息。在 Uya Mini 版本中：
- 需要声明 `extern fn fprintf(stream: *void, format: *byte, ...) i32;`
- 需要定义 `stderr` 常量，或使用数字常量（通常是 `2`）

### 3. 动态数组扩展

C99 版本使用 `sizeof(ASTNode *) * capacity` 计算数组大小。在 Uya Mini 版本中：
- 指针大小通常是 8 字节（64位系统）
- 使用 `8 * capacity` 代替 `sizeof(ASTNode *) * capacity`

### 4. 递归调用

所有解析函数都使用递归调用，Uya Mini 支持递归，无需特殊处理。

### 5. 前向声明

Uya Mini 不需要前向声明，函数可以按任意顺序定义。

---

## 验证策略

### 1. 编译验证

每个阶段完成后：
1. 检查语法错误
2. 检查类型错误
3. 确保所有函数都已翻译

### 2. 功能验证

完整翻译后：
1. 创建简单的测试程序
2. 使用 C99 编译器编译 `parser.uya`
3. 运行测试验证功能正确性

### 3. 对比验证

- 对比 C99 版本和 Uya Mini 版本的 AST 输出
- 确保解析结果一致

---

## 风险点

### 1. 文件大小

parser.c 有 2587 行，翻译后可能超过 1500 行。如果超过，需要考虑拆分为多个文件。

### 2. 复杂度

`parser_parse_primary_expr` 函数有约 900 行，非常复杂，需要仔细翻译。

### 3. 字段映射

AST 节点字段映射规则很多，容易出错，需要仔细对照 `ast.uya`。

### 4. 递归深度

解析函数使用递归调用，需要确保递归深度合理。

---

## 时间估算

| 阶段 | 内容 | 时间估算 |
|------|------|----------|
| 阶段1 | 准备工作 | 30分钟 |
| 阶段2 | 基础函数 | 2小时 |
| 阶段3 | 类型解析 | 1.5小时 |
| 阶段4 | 代码块解析 | 1小时 |
| 阶段5 | 声明解析 | 3小时 |
| 阶段6 | 表达式解析 | 4小时 |
| 阶段7 | 语句解析 | 2小时 |
| **总计** | | **约14小时** |

---

## 翻译进度

**最后更新**：2026-01-13

**当前状态**：阶段7已完成，所有翻译工作已完成！

**已完成阶段**：
- ✅ 阶段1：准备工作（外部函数声明、文件结构）
- ✅ 阶段2：基础函数翻译（parser_init, parser_match, parser_consume等）
- ✅ 阶段3：类型解析函数（parser_parse_type）
- ✅ 阶段4：代码块解析函数（parser_parse_block）
- ✅ 阶段5：声明解析函数（parser_parse_struct, parser_parse_enum, parser_parse_function, parser_parse_extern_function, parser_parse_declaration, parser_parse）
- ✅ 阶段6：表达式解析函数（parser_parse_primary_expr等，最复杂）
- ✅ 阶段7：语句解析函数（parser_parse_statement）

**代码行数**：
- C99 版本：2587 行
- Uya Mini 版本（当前）：约 2730 行
- 进度：100% ✅

---

## 下一步行动

1. ✅ 创建翻译计划文档（本文件）
2. ✅ 阶段1：准备工作（已完成）
3. ✅ 阶段2：基础函数（已完成）
4. ✅ 阶段3：类型解析函数（已完成）
5. ✅ 阶段4：代码块解析函数（已完成）
6. ✅ 阶段5：声明解析函数（已完成）
7. ✅ 阶段6：表达式解析函数（已完成）
8. ✅ 阶段7：语句解析函数（已完成）
9. ✅ 阶段8：验证和测试（语法检查完成，功能测试待进行）

---

## 验证报告

详细的验证结果请参考：`VERIFICATION_REPORT_phase4.md`

---

## 参考文档

- `VERIFICATION_REPORT_phase4.md` - 验证报告（最新）
- `TODO_phase4.md` - 阶段4任务列表
- `BOOTSTRAP_PLAN.md` - 自举实现计划
- `src/parser.c/h` - C99 版本实现
- `uya-src/lexer.uya` - 词法分析器参考
- `uya-src/ast.uya` - AST 数据结构定义
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范

