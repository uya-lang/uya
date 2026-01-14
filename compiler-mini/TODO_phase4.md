# 阶段4：语法分析器

## 概述

翻译语法分析器（Parser）模块，代码量最大（2,556行），逻辑复杂。

**优先级**：P0

**工作量估算**：8-12 小时

**依赖**：阶段0（准备工作 - str_utils.uya）、阶段1（Arena）、阶段2（AST）、阶段3（Lexer）

**原因**：Checker 和 CodeGen 依赖 Parser。

---

## 任务列表

### 任务 4.1：阅读和理解 C99 代码

- [ ] 阅读 `src/parser.h` - 理解 Parser 接口
- [ ] 阅读 `src/parser.c` - 理解 Parser 实现
- [ ] 理解递归下降解析的工作原理：
  - [ ] 表达式解析（优先级处理）
  - [ ] 语句解析
  - [ ] 声明解析
  - [ ] 类型解析
  - [ ] 错误处理和恢复
- [ ] 理解 Parser 的递归调用结构

**参考**：代码量最大（2,556行），逻辑复杂（递归下降解析）

---

### 任务 4.2：翻译 Parser 结构体定义

**文件**：`uya-src/parser.uya`

- [ ] 翻译 `Parser` 结构体：
  - [ ] Lexer 字段（`lexer`）
  - [ ] Arena 分配器字段（`arena`）
  - [ ] 错误相关字段（`has_error`, `error_message` 等）
  - [ ] 其他辅助字段

**类型映射**：
- `Lexer *` → `&Lexer`
- `Arena *` → `&Arena`
- `char *` → `&byte` 或 `*byte`（如果是 extern 函数参数）
- `int` → `i32`

---

### 任务 4.3：翻译表达式解析函数

- [ ] 翻译表达式解析函数（按优先级从低到高）：
  - [ ] `parse_expression` - 表达式入口
  - [ ] `parse_assignment` - 赋值表达式
  - [ ] `parse_logical_or` - 逻辑或
  - [ ] `parse_logical_and` - 逻辑与
  - [ ] `parse_equality` - 相等比较
  - [ ] `parse_comparison` - 比较运算
  - [ ] `parse_additive` - 加减运算
  - [ ] `parse_multiplicative` - 乘除运算
  - [ ] `parse_unary` - 一元运算
  - [ ] `parse_primary` - 基本表达式
- [ ] 确保递归调用正确
- [ ] 确保优先级处理正确

**关键挑战**：
- 递归函数调用：Uya Mini 支持递归，但需要确保正确
- 优先级处理：保持与 C99 版本相同的优先级规则

---

### 任务 4.4：翻译语句解析函数

- [ ] 翻译语句解析函数：
  - [ ] `parse_statement` - 语句入口
  - [ ] `parse_block` - 代码块
  - [ ] `parse_if` - if 语句
  - [ ] `parse_while` - while 语句
  - [ ] `parse_for` - for 语句（数组遍历）
  - [ ] `parse_break` - break 语句
  - [ ] `parse_continue` - continue 语句
  - [ ] `parse_return` - return 语句
  - [ ] `parse_expression_stmt` - 表达式语句
  - [ ] `parse_variable_decl` - 变量声明
  - [ ] 其他语句类型

---

### 任务 4.5：翻译声明解析函数

- [ ] 翻译声明解析函数：
  - [ ] `parse_declaration` - 声明入口
  - [ ] `parse_function` - 函数声明
  - [ ] `parse_struct` - 结构体声明
  - [ ] `parse_enum` - 枚举声明（如果有）
  - [ ] `parse_extern` - extern 函数声明
  - [ ] 其他声明类型

---

### 任务 4.6：翻译类型解析函数

- [ ] 翻译类型解析函数：
  - [ ] `parse_type` - 类型入口
  - [ ] `parse_base_type` - 基础类型
  - [ ] `parse_pointer_type` - 指针类型（`&T` 和 `*T`）
  - [ ] `parse_array_type` - 数组类型（`[T: N]`）
  - [ ] `parse_struct_type` - 结构体类型
  - [ ] 其他类型

---

### 任务 4.7：翻译错误处理函数

- [ ] 翻译错误处理函数：
  - [ ] `report_error` - 报告错误（使用 `fprintf`）
  - [ ] `expect_token` - 期望特定 Token
  - [ ] `skip_to_recovery_point` - 错误恢复
  - [ ] 其他错误处理函数

**关键挑战**：
- 错误处理：使用返回值代替异常，使用 `fprintf` 输出错误消息
- 错误恢复：保持与 C99 版本相同的错误恢复策略

---

### 任务 4.8：使用字符串辅助函数

- [ ] 在 `parser.uya` 中包含或引用 `str_utils.uya` 的声明
- [ ] 将所有字符串操作改为使用 `str_utils.uya` 中的函数
- [ ] 确保所有错误消息使用 `fprintf` 输出

---

### 任务 4.9：添加中文注释

- [ ] 为所有结构体添加中文注释
- [ ] 为所有函数添加中文注释
- [ ] 为递归下降解析逻辑添加中文注释
- [ ] 为优先级处理添加中文注释
- [ ] 为错误处理逻辑添加中文注释

---

### 任务 4.10：验证功能

- [ ] 创建简单的测试程序（`uya-src/test_parser.uya`）：
  - [ ] 测试表达式解析
  - [ ] 测试语句解析
  - [ ] 测试声明解析
  - [ ] 测试类型解析
  - [ ] 测试错误处理
- [ ] 使用 C99 编译器编译测试程序
- [ ] 运行测试程序验证功能正确性

**参考**：`tests/test_parser.c` - 现有的 C99 测试程序

---

## 完成标准

- [ ] `parser.uya` 已创建，包含完整的 Parser 实现
- [ ] 所有结构体已翻译
- [ ] 所有表达式解析函数已翻译
- [ ] 所有语句解析函数已翻译
- [ ] 所有声明解析函数已翻译
- [ ] 所有类型解析函数已翻译
- [ ] 所有错误处理函数已翻译
- [ ] 使用 `str_utils.uya` 中的字符串函数
- [ ] 所有代码使用中文注释
- [ ] 功能与 C99 版本完全一致
- [ ] 测试程序通过
- [ ] 已更新 `PROGRESS.md`，标记阶段4为完成

---

## 参考文档

- `src/parser.h` - C99 版本的 Parser 接口
- `src/parser.c` - C99 版本的 Parser 实现
- `tests/test_parser.c` - Parser 测试程序
- `uya-src/str_utils.uya` - 字符串辅助函数模块
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范，确认语法规则
- `BOOTSTRAP_PLAN.md` - 字符串处理策略和类型映射规则

---

## 注意事项

1. **递归调用**：Uya Mini 支持递归，但需要确保递归深度合理
2. **优先级处理**：保持与 C99 版本相同的运算符优先级
3. **错误处理**：使用返回值表示成功/失败，使用 `fprintf` 输出错误消息
4. **字符串处理**：必须使用 `str_utils.uya` 中的封装函数
5. **文件大小**：如果文件超过 1500 行，需要拆分为多个文件

---

## C99 → Uya Mini 映射示例

```c
// C99
Expr *parse_expression(Parser *parser) {
    return parse_assignment(parser);
}

Expr *parse_assignment(Parser *parser) {
    Expr *left = parse_logical_or(parser);
    if (parser->lexer->current_token.kind == TOKEN_EQ) {
        lexer_next_token(parser->lexer);
        Expr *right = parse_assignment(parser);
        return new_expr_assign(parser->arena, left, right);
    }
    return left;
}

// Uya Mini
fn parse_expression(parser: &Parser) &Expr {
    return parse_assignment(parser);
}

fn parse_assignment(parser: &Parser) &Expr {
    const left: &Expr = parse_logical_or(parser);
    if parser.lexer.current_token.kind == TOKEN_EQ {
        lexer_next_token(&parser.lexer);
        const right: &Expr = parse_assignment(parser);
        return new_expr_assign(parser.arena, left, right);
    }
    return left;
}
```

