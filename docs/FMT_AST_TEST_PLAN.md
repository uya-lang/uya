# Uya AST 格式化器 TDD 测试计划

## 测试策略

**TDD 原则**：先写测试，再写代码，确保 100% 功能覆盖。

**覆盖率目标**：
- Phase 1: Lexer 注释收集 - 100%
- Phase 2: AST 注释挂载 - 100%
- Phase 3: Uya 后端格式化 - 100%
- Phase 4: 集成测试 - 完整场景

---

## Phase 1: Lexer 注释收集测试

### 测试文件：`tests/fmt/test_lexer_comment.uya`

### 1.1 单行注释测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 1 | `test_single_line_comment` | `// comment\nconst x = 1;` | `comments[0].text = "// comment"` | 基本单行注释 |
| 2 | `test_empty_comment` | `//\nconst x = 1;` | `comments[0].text = "//"` | 空注释 |
| 3 | `test_comment_with_spaces` | `//   spaces   \nconst x = 1;` | `comments[0].text = "//   spaces   "` | 含空格注释 |
| 4 | `test_comment_after_code` | `const x = 1;  // trailing` | `comments[0].text = "// trailing"` | 行尾注释 |
| 5 | `test_multiple_line_comments` | `// line1\n// line2\nconst x = 1;` | `comments[0].text = "// line1"`, `comments[1].text = "// line2"` | 多行注释 |
| 6 | `test_comment_at_eof` | `const x = 1;\n// eof` | `comments[0].text = "// eof"` | 文件尾注释 |

### 1.2 块注释测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 7 | `test_block_comment` | `/* block */\nconst x = 1;` | `comments[0].text = "/* block */"`, `comments[0].kind = BLOCK` | 基本块注释 |
| 8 | `test_multiline_block_comment` | `/* line1\nline2 */\nconst x = 1;` | `comments[0].start_line = 1`, `comments[0].end_line = 2` | 多行块注释 |
| 9 | `test_nested_stars` | `/* * * */\nconst x = 1;` | `comments[0].text = "/* * * */"` | 含星号块注释 |
| 10 | `test_inline_block_comment` | `const x = 1;  /* inline */` | `comments[0].text = "/* inline */"` | 行内块注释 |
| 11 | `test_empty_block_comment` | `/**/\nconst x = 1;` | `comments[0].text = "/**/"` | 空块注释 |

### 1.3 混合注释测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 12 | `test_mixed_comments` | `// line\n/* block */\nconst x = 1;` | `comments[0].kind = LINE`, `comments[1].kind = BLOCK` | 混合注释类型 |
| 13 | `test_comment_between_tokens` | `const x = 1;  // c1\nconst y = 2;  // c2` | `comments[0].text = "// c1"`, `comments[1].text = "// c2"` | 多注释 |
| 14 | `test_no_comment` | `const x = 1;` | `comment_count = 0` | 无注释代码 |

### 1.4 位置信息测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 15 | `test_comment_line_column` | `// comment` | `start_line = 1`, `start_col = 1` | 位置信息 |
| 16 | `test_comment_after_spaces` | `    // indented` | `start_line = 1`, `start_col = 5` | 缩进注释 |
| 17 | `test_multiline_positions` | `/* a\nb\nc */` | `start_line = 1`, `end_line = 3` | 多行位置 |

### 1.5 边界条件测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 18 | `test_max_comments` | 100 行注释 + 代码 | `comment_count = 100` | 最大注释数 |
| 19 | `test_comment_in_string` | `const s = "// not comment";` | `comment_count = 0` | 字符串内伪注释 |
| 20 | `test_comment_in_block_string` | `const s = \`\n// not comment\n\`;` | `comment_count = 0` | 块字符串内伪注释 |

### 1.6 测试代码示例

```uya
// tests/fmt/test_lexer_comment.uya
// Lexer 注释收集测试

use std.testing.assert_eq_i32;
use std.testing.expect;

test "test_single_line_comment" {
    // 测试基本单行注释
    const input: &byte = "// comment\nconst x = 1;";
    const lexer: Lexer = lexer_init(input);
    
    // 收集注释
    lexer_collect_comments(&lexer);
    
    try assert_eq_i32(lexer.comment_count, 1);
    try expect(str_equals(lexer.comments[0].text, "// comment") != 0);
}

test "test_block_comment" {
    const input: &byte = "/* block */\nconst x = 1;";
    const lexer: Lexer = lexer_init(input);
    
    lexer_collect_comments(&lexer);
    
    try assert_eq_i32(lexer.comment_count, 1);
    try expect(lexer.comments[0].kind == CommentKind.BLOCK);
}

test "test_no_comment" {
    const input: &byte = "const x = 1;";
    const lexer: Lexer = lexer_init(input);
    
    lexer_collect_comments(&lexer);
    
    try assert_eq_i32(lexer.comment_count, 0);
}
```

---

## Phase 2: AST 注释挂载测试

### 测试文件：`tests/fmt/test_ast_comment.uya`

### 2.1 Leading Comments 测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 1 | `test_leading_single` | `// leading\nconst x = 1;` | `VarDecl.leading_comments[0].text = "// leading"` | 单行前导注释 |
| 2 | `test_leading_multiple` | `// l1\n// l2\nconst x = 1;` | `VarDecl.leading_comments.count = 2` | 多行前导注释 |
| 3 | `test_leading_block` | `/* leading */\nconst x = 1;` | `VarDecl.leading_comments[0].kind = BLOCK` | 块前导注释 |
| 4 | `test_leading_before_fn` | `// fn comment\nfn foo() void {}` | `FnDecl.leading_comments[0].text = "// fn comment"` | 函数前导注释 |
| 5 | `test_leading_before_struct` | `// struct comment\nstruct S {}` | `StructDecl.leading_comments[0].text` | 结构体前导注释 |

### 2.2 Trailing Comments 测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 6 | `test_trailing_single` | `const x = 1;  // trailing` | `VarDecl.trailing_comments[0].text = "// trailing"` | 行尾注释 |
| 7 | `test_trailing_block` | `const x = 1;  /* trailing */` | `VarDecl.trailing_comments[0].kind = BLOCK` | 块行尾注释 |
| 8 | `test_no_trailing` | `const x = 1;\nconst y = 2;` | `VarDecl.trailing_comments = null` | 无行尾注释 |

### 2.3 Standalone Comments 测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 9 | `test_standalone_comment` | `const x = 1;\n// standalone\nconst y = 2;` | 第二行注释不属于任何节点 | 独立注释 |
| 10 | `test_eof_standalone` | `const x = 1;\n// eof` | EOF 注释作为独立注释 | 文件尾注释 |
| 11 | `test_file_header` | `// header\n// line2\nconst x = 1;` | 文件头注释 | 文件头 |

### 2.4 注释归属判定测试

| # | 测试名 | 输入 | 预期结果 | 覆盖场景 |
|---|--------|------|----------|----------|
| 12 | `test_comment_same_line` | `const x = 1;  // same line` | 属于 trailing | 同行判定 |
| 13 | `test_comment_next_line` | `const x = 1;\n// next line\nconst y = 2;` | 属于 y 的 leading | 下一行判定 |
| 14 | `test_blank_line_separator` | `const x = 1;\n\n// after blank\nconst y = 2;` | 属于 y 的 leading | 空行分隔 |
| 15 | `test_multiple_blank_lines` | `const x = 1;\n\n\n// after blanks\nconst y = 2;` | 仍然属于 y 的 leading | 多空行 |

### 2.5 测试代码示例

```uya
// tests/fmt/test_ast_comment.uya
// AST 注释挂载测试

use std.testing.assert_eq_i32;
use std.testing.expect;

test "test_leading_single" {
    const input: &byte = "// leading\nconst x: i32 = 1;";
    const ast: &ASTNode = parse(input);
    
    try expect_not_null(ast);
    try assert_eq_i32(ast.body[0].leading_comments_count, 1);
    try expect(str_equals(ast.body[0].leading_comments[0].text, "// leading") != 0);
}

test "test_trailing_single" {
    const input: &byte = "const x: i32 = 1;  // trailing";
    const ast: &ASTNode = parse(input);
    
    try expect_not_null(ast);
    try assert_eq_i32(ast.body[0].trailing_comments_count, 1);
}

test "test_standalone_comment" {
    const input: &byte = "const x: i32 = 1;\n// standalone\nconst y: i32 = 2;";
    const ast: &ASTNode = parse(input);
    
    // 独立注释应该在 y 的 leading 中
    try assert_eq_i32(ast.body[1].leading_comments_count, 1);
}
```

---

## Phase 3: Uya 后端格式化测试

### 测试目录：`tests/fmt/`

### 3.1 基础格式化测试 (`test_fmt_basic.uya`)

| # | 测试名 | 输入 | 预期输出 | 覆盖场景 |
|---|--------|------|----------|----------|
| 1 | `test_indent_spaces` | `fn f(){x=1;}` | `fn f() {\n    x = 1;\n}` | 4空格缩进 |
| 2 | `test_binary_op_space` | `x=a+b*c` | `x = a + b * c` | 运算符空格 |
| 3 | `test_colon_space` | `x:i32=1` | `x: i32 = 1` | 冒号后空格 |
| 4 | `test_comma_space` | `f(a,b,c)` | `f(a, b, c)` | 逗号后空格 |
| 5 | `test_brace_space` | `fn f()i32{}` | `fn f() i32 {}` | 大括号前空格 |
| 6 | `test_return_space` | `fn f()i32{}` | `fn f() i32 {}` | 返回类型前空格 |
| 7 | `test_no_space_paren` | `f( a , b )` | `f(a, b)` | 括号内无空格 |
| 8 | `test_no_space_bracket` | `a[ i ]` | `a[i]` | 中括号内无空格 |
| 9 | `test_no_space_dot` | `obj . field` | `obj.field` | 点号无空格 |
| 10 | `test_single_space_between` | `x=1;y=2;` | `x = 1;\ny = 2;` | 语句分隔 |

### 3.2 空行规则测试 (`test_fmt_blank.uya`)

| # | 测试名 | 输入 | 预期输出 | 覆盖场景 |
|---|--------|------|----------|----------|
| 11 | `test_fn_blank` | `fn a(){}fn b(){}` | `fn a() {}\n\nfn b() {}` | 函数间空行 |
| 12 | `test_struct_blank` | `struct S{}fn f(){}` | `struct S {}\n\nfn f() {}` | 结构体后空行 |
| 13 | `test_max_blank` | `fn a(){}\n\n\n\nfn b(){}` | `fn a() {}\n\nfn b() {}` | 最多1空行 |
| 14 | `test_no_leading_blank` | `{\n\nx=1;}` | `{\n    x = 1;\n}` | 块内无前导空行 |
| 15 | `test_no_trailing_blank` | `{x=1;\n\n}` | `{\n    x = 1;\n}` | 块内无尾随空行 |
| 16 | `test_no_trailing_ws` | `x = 1;   ` | `x = 1;` | 删除行尾空白 |

### 3.3 控制语句格式化测试 (`test_fmt_control.uya`)

| # | 测试名 | 输入 | 预期输出 | 覆盖场景 |
|---|--------|------|----------|----------|
| 17 | `test_if_basic` | `if c{a();}` | `if c {\n    a();\n}` | if语句 |
| 18 | `test_if_else` | `if c{a();}else{b();}` | `if c {\n    a();\n} else {\n    b();\n}` | if-else |
| 19 | `test_if_elseif` | `if c1{a();}else if c2{b();}else{c();}` | 格式化后 | if-else-if |
| 20 | `test_while` | `while c{a();}` | `while c {\n    a();\n}` | while语句 |
| 21 | `test_for` | `for a\|x\|{f(x);}` | `for a \|x\| {\n    f(x);\n}` | for语句 |
| 22 | `test_match` | `match v{.A=>1,.B=>2}` | `match v {\n    .A => 1,\n    .B => 2,\n}` | match语句 |
| 23 | `test_match_else` | `match v{.A=>1,else=>2}` | `match v {\n    .A => 1,\n    else => 2,\n}` | match else |

### 3.4 声明格式化测试 (`test_fmt_decl.uya`)

| # | 测试名 | 输入 | 预期输出 | 覆盖场景 |
|---|--------|------|----------|----------|
| 24 | `test_fn_decl` | `fn f(a:i32,b:i32)i32{return a+b;}` | 格式化后 | 函数声明 |
| 25 | `test_fn_export` | `export fn f()void{}` | `export fn f() void {}` | export函数 |
| 26 | `test_fn_extern` | `extern fn f(a:i32)i32;` | `extern fn f(a: i32) i32;` | extern函数 |
| 27 | `test_struct_decl` | `struct S{x:i32,y:i32}` | `struct S {\n    x: i32,\n    y: i32,\n}` | 结构体 |
| 28 | `test_enum_decl` | `enum E{A,B,C}` | `enum E {\n    A,\n    B,\n    C,\n}` | 枚举 |
| 29 | `test_enum_values` | `enum E{A=1,B=2}` | `enum E {\n    A = 1,\n    B = 2,\n}` | 枚举值 |
| 30 | `test_union_decl` | `union U{A:i32,B:f64}` | `union U {\n    A: i32,\n    B: f64,\n}` | union |
| 31 | `test_const_decl` | `const X:i32=1` | `const X: i32 = 1;` | const声明 |
| 32 | `test_var_decl` | `var x:i32=0` | `var x: i32 = 0;` | var声明 |
| 33 | `test_use_stmt` | `use std.io` | `use std.io;` | use语句 |
| 34 | `test_type_alias` | `type I=i32` | `type I = i32;` | 类型别名 |
| 35 | `test_error_decl` | `error MyError` | `error MyError;` | 错误声明 |

### 3.5 表达式格式化测试 (`test_fmt_expr.uya`)

| # | 测试名 | 输入 | 预期输出 | 覆盖场景 |
|---|--------|------|----------|----------|
| 36 | `test_binary_expr` | `a+b*c-d` | `a + b * c - d` | 二元表达式 |
| 37 | `test_unary_expr` | `!flag` | `!flag` | 一元表达式 |
| 38 | `test_call_expr` | `f(a,b)` | `f(a, b)` | 函数调用 |
| 39 | `test_member_access` | `a.b.c` | `a.b.c` | 成员访问 |
| 40 | `test_array_access` | `a[i]` | `a[i]` | 数组访问 |
| 41 | `test_slice_expr` | `a[i:j]` | `a[i:j]` | 切片 |
| 42 | `test_struct_init` | `S{x:1,y:2}` | `S {\n    x: 1,\n    y: 2,\n}` | 结构体初始化 |
| 43 | `test_array_literal` | `[1,2,3]` | `[1, 2, 3]` | 数组字面量 |
| 44 | `test_try_expr` | `try f()` | `try f()` | try表达式 |
| 45 | `test_cast_expr` | `x as i32` | `x as i32` | 类型转换 |
| 46 | `test_addr_expr` | `&x` | `&x` | 取地址 |
| 47 | `test_deref_expr` | `*p` | `*p` | 解引用 |
| 48 | `test_ternary` | `c?a:b` | `c ? a : b` | 三元表达式 |

### 3.6 注释格式化测试 (`test_fmt_comment.uya`)

| # | 测试名 | 输入 | 预期输出 | 覆盖场景 |
|---|--------|------|----------|----------|
| 49 | `test_leading_comment` | `// c\nx=1` | `// c\nx = 1` | 前导注释 |
| 50 | `test_trailing_comment` | `x=1  // c` | `x = 1;  // c` | 行尾注释 |
| 51 | `test_block_comment` | `/* c */x=1` | `/* c */\nx = 1` | 块注释 |
| 52 | `test_multiline_block` | `/*\nline1\nline2\n*/x=1` | 保持块注释格式 | 多行块注释 |
| 53 | `test_comment_indent` | `if true{\n// c\nx=1\n}` | 正确缩进注释 | 注释缩进 |
| 54 | `test_standalone_comment` | `x=1\n// s\ny=2` | `x = 1;\n\n// s\ny = 2` | 独立注释 |
| 55 | `test_file_header` | `// h1\n// h2\nx=1` | `// h1\n// h2\n\nx = 1` | 文件头注释 |
| 56 | `test_no_align_trailing` | `a=1  // s\nlongname=2  // l` | 不对齐 | 不对齐行尾注释 |

### 3.7 特殊语法格式化测试 (`test_fmt_special.uya`)

| # | 测试名 | 输入 | 预期输出 | 覆盖场景 |
|---|--------|------|----------|----------|
| 57 | `test_defer_stmt` | `defer f()` | `defer f();` | defer语句 |
| 58 | `test_defer_block` | `defer{a();b();}` | `defer {\n    a();\n    b();\n}` | defer块 |
| 59 | `test_errdefer_stmt` | `errdefer f()` | `errdefer f();` | errdefer语句 |
| 60 | `test_test_stmt` | `test "t"{}` | `test "t" {}` | test块 |
| 61 | `test_method_block` | `Type{fn f(){}}` | `Type {\n    fn f() {}\n}` | 方法块 |
| 62 | `test_macro_decl` | `mc m(x:expr)expr{x}` | `mc m(x: expr) expr {\n    ${x}\n}` | 宏声明 |
| 63 | `test_atomic_type` | `var x:atomic i32=0` | `var x: atomic i32 = 0;` | 原子类型 |
| 64 | `test_asm_block` | `@asm{"nop"()}` | `@asm {\n    "nop" ();\n}` | 内联汇编 |

### 3.8 测试代码示例

```uya
// tests/fmt/test_fmt_basic.uya
// 基础格式化测试

use std.testing.assert_eq_i32;
use std.testing.expect;

test "test_indent_spaces" {
    const input: &byte = "fn f(){x=1;}";
    const expected: &byte = "fn f() {\n    x = 1;\n}";
    
    const output: &byte = fmt_format(input);
    try expect(str_equals(output, expected) != 0);
}

test "test_binary_op_space" {
    const input: &byte = "x=a+b*c";
    const expected: &byte = "x = a + b * c";
    
    const output: &byte = fmt_format(input);
    try expect(str_equals(output, expected) != 0);
}

test "test_max_blank" {
    const input: &byte = "fn a(){}\n\n\n\nfn b(){}";
    const expected: &byte = "fn a() {}\n\nfn b() {}";
    
    const output: &byte = fmt_format(input);
    try expect(str_equals(output, expected) != 0);
}
```

---

## Phase 4: 集成测试

### 测试文件：`tests/fmt/test_fmt_integration.uya`

### 4.1 幂等性测试

| # | 测试名 | 测试内容 | 覆盖场景 |
|---|--------|----------|----------|
| 1 | `test_idempotent_basic` | 格式化两次，结果相同 | 基本幂等 |
| 2 | `test_idempotent_comment` | 含注释代码，格式化两次相同 | 注释幂等 |
| 3 | `test_idempotent_complex` | 复杂嵌套结构，格式化两次相同 | 复杂幂等 |
| 4 | `test_idempotent_src_files` | 格式化 src/ 所有文件，二次相同 | 完整幂等 |

### 4.2 完整文件测试

| # | 测试名 | 测试内容 | 覆盖场景 |
|---|--------|----------|----------|
| 5 | `test_complete_file_1` | 完整源文件格式化 | 综合测试 |
| 6 | `test_complete_file_2` | 含多种声明的文件 | 综合测试 |
| 7 | `test_complete_file_3` | 含注释的完整文件 | 注释保留 |

### 4.3 测试代码示例

```uya
// tests/fmt/test_fmt_integration.uya
// 集成测试

use std.testing.expect;

test "test_idempotent_basic" {
    const input: &byte = "fn f(){x=1;}";
    
    const pass1: &byte = fmt_format(input);
    const pass2: &byte = fmt_format(pass1);
    
    try expect(str_equals(pass1, pass2) != 0);
}

test "test_idempotent_comment" {
    const input: &byte = "// header\nfn f(){// comment\nx=1;}";
    
    const pass1: &byte = fmt_format(input);
    const pass2: &byte = fmt_format(pass1);
    
    try expect(str_equals(pass1, pass2) != 0);
}
```

---

## 测试用例统计

| Phase | 测试文件 | 用例数 | 覆盖率目标 |
|-------|----------|--------|------------|
| Phase 1 | test_lexer_comment.uya | 20 | 100% |
| Phase 2 | test_ast_comment.uya | 15 | 100% |
| Phase 3 | test_fmt_basic.uya | 10 | 100% |
| Phase 3 | test_fmt_blank.uya | 6 | 100% |
| Phase 3 | test_fmt_control.uya | 7 | 100% |
| Phase 3 | test_fmt_decl.uya | 12 | 100% |
| Phase 3 | test_fmt_expr.uya | 13 | 100% |
| Phase 3 | test_fmt_comment.uya | 8 | 100% |
| Phase 3 | test_fmt_special.uya | 8 | 100% |
| Phase 4 | test_fmt_integration.uya | 7 | 100% |
| **总计** | **10 文件** | **106 用例** | **100%** |

---

## 测试执行顺序

### TDD 红绿重构流程

```
Phase 1:
  1. 创建 tests/fmt/test_lexer_comment.uya
  2. 运行: make tests → 失败（红）
  3. 实现: src/lexer.uya 注释收集
  4. 运行: make tests → 通过（绿）
  5. 重构: 优化代码结构

Phase 2:
  1. 创建 tests/fmt/test_ast_comment.uya
  2. 运行: make tests → 失败（红）
  3. 实现: src/ast.uya + src/parser/main.uya
  4. 运行: make tests → 通过（绿）
  5. 重构: 优化代码结构

Phase 3:
  1. 创建 tests/fmt/test_fmt_*.uya (6个文件)
  2. 运行: make tests → 失败（红）
  3. 实现: src/codegen/uya/
  4. 运行: make tests → 通过（绿）
  5. 重构: 优化代码结构

Phase 4:
  1. 创建 tests/fmt/test_fmt_integration.uya
  2. 运行: make tests → 失败（红）
  3. 实现: src/main.uya --uya 选项
  4. 运行: make tests → 通过（绿）
  5. 运行: scripts/verify_fmt.sh
  6. 运行: make check
  7. 运行: make backup
```

---

## 验收标准

1. **所有测试通过**：`make tests` 无失败
2. **幂等性验证**：格式化两次结果相同
3. **自举验证**：`make check` 通过
4. **备份验证**：`make backup` 成功
