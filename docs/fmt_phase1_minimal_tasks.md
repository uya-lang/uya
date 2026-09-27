# Uya fmt Phase 1 TodoList

> **核对头（2026-09-27）**：本 phase 文档的 "Not started" 勾选状态已过时——对应能力已在 `src/fmt.uya` + `tests/test_fmt_*.uya` 落地（`uya fmt` 命令见 `src/main.uya` 的 `COMMAND_FMT`）。
> 保留本文件作为任务分解记录；唯一仍明确未支持的是 `fmt_phase4_cli_tasks.md` 里的"stdin 与 `-s/-r` 组合"。

> 基于 `docs/fmt_development_plan.md` 的方案 B，Phase 1 聚焦最小可运行 formatter 主链路。

**Goal**: 做出一个可运行、可测试、可幂等的最小 formatter。  
**Scope**: 暂不实现 comments / import_sort / rewrite / simplify / 完整 CLI。

---

## Status

- [ ] Not started
- [x] MVP Done

---

## Phase 1 Goals

- [x] 能读取一段简单 Uya 源码
- [x] 能完成最基础的 tokenize + parse
- [x] 能生成基础 AST
- [x] 能把 AST 重新打印成统一格式
- [x] 能保证基础幂等性
- [x] 能通过最小测试集

---

## Scope

- [x] 支持整数面量
- [x] 支持标识符
- [x] 支持二元表达式 `a + b` / `a * b`
- [x] 支持一元表达式 `-x`
- [x] 支持调用表达式 `foo(a, b)`
- [x] 支持赋值语句 `x = 1;`
- [x] 支持 `return` 语句
- [x] 支持表达式语句 `foo(x);`
- [x] 支持 `fn` 函数声明
- [x] 支持简单参数列表
- [x] 支持简单代码块
- [x] 支持单文件内多个函数声明

---

## Out of Scope

- [ ] 注释保留与附着
- [ ] use/import 排序
- [ ] rewrite 规则
- [ ] simplify 规则
- [ ] stdin / `-w` / `-d` / `-l` 完整 CLI
- [ ] 复杂声明（struct/interface/export 细节）
- [ ] 错误恢复

---

## Main Pipeline

- [x] 打通 `source -> tokenize -> parse_file -> File AST -> print_file -> formatted source`

---

## File Tasks

### `lib/std/fmt/formatter.uya`

- [x] 定义 `Formatter` 结构体
- [x] 实现 `formatter_init()`
- [x] 实现 `formatter_write()`
- [x] 实现 `formatter_write_byte()`
- [x] 实现 `formatter_indent()`
- [x] 实现 `formatter_dedent()`
- [x] 实现 `formatter_newline()`
- [x] 实现 `formatter_write_indent()`
- [x] 验证能正确跟踪 `pos` / `line`
- [x] 验证换行后可正确写入缩进

### `lib/std/fmt/positions.uya`

- [x] 定义 `Position { offset, line, column }`
- [x] 定义 `Span { start, end }`
- [x] 让 tokenizer 产出的 token 带 `Span`
- [x] 让 parser 构造的节点带 `Span`

### `lib/std/fmt/tokenizer.uya`

- [x] 定义 `TokenType`
- [x] 定义 `Token`
- [x] 实现 `tokenize(arena, source)`
- [x] 支持 `EOF`
- [x] 支持 `IDENT`
- [x] 支持 `NUMBER`
- [x] 支持 `FN`
- [x] 支持 `RETURN`
- [x] 支持 `LPAREN` / `RPAREN`
- [x] 支持 `LBRACE` / `RBRACE`
- [x] 支持 `COMMA`
- [x] 支持 `SEMICOLON`
- [x] 支持 `ASSIGN`
- [x] 支持 `PLUS` / `MINUS` / `STAR` / `SLASH`
- [x] 验证 `fn add(a, b) { return a+b; }` 可正确切分 token
- [x] 对非法字符返回错误

### `lib/std/fmt/ast.uya`

- [x] 定义 `File`
- [x] 定义 `FnDecl`
- [x] 定义 `Param`
- [x] 定义 `BlockStmt`
- [x] 定义 `AssignStmt`
- [x] 定义 `ReturnStmt`
- [x] 定义 `ExprStmt`
- [x] 定义 `IdentExpr`
- [x] 定义 `NumberExpr`
- [x] 定义 `UnaryExpr`
- [x] 定义 `BinaryExpr`
- [x] 定义 `CallExpr`
- [x] 为每个节点补齐 `Span`

### `lib/std/fmt/parser.uya`

- [x] 实现 `parse_file()`
- [x] 实现 `parse_decl()`
- [x] 实现 `parse_fn_decl()`
- [x] 实现 `parse_block()`
- [x] 实现 `parse_stmt()`
- [x] 实现 `parse_expr()`
- [x] 实现表达式优先级解析
- [x] 验证函数声明可正确解析
- [x] 验证返回语句可正确解析
- [x] 验证 `1 + 2 * 3` 优先级正确
- [x] 验证调用表达式可正确解析

### `lib/std/fmt/printer.uya`

- [x] 实现 `print_file()`
- [x] 实现 `print_decl()`
- [x] 实现 `print_fn_decl()`
- [x] 实现 `print_block()`
- [x] 实现 `print_stmt()`
- [x] 实现 `print_expr()`
- [x] 统一二元运算符两边一个空格
- [x] 统一参数逗号后一个空格
- [x] 保持 `{` 与前一部分同一行
- [x] 保持块内缩进一级
- [x] 保持语句独占一行
- [x] 保持函数之间空一行
- [x] 验证示例输入输出符合预期

### `lib/std/fmt/fmt.uya`

- [x] 实现 `format(arena, source)`
- [x] 实现 `format_node(arena, file)`
- [x] 实现 `is_formatted(arena, source)`
- [x] 串联 `tokenize -> parse_file -> print_file`
- [x] 验证一次调用可完成最小格式化流程

---

## Tests

### `tests/test_fmt_formatter.uya`
- [x] 验证写入字符串
- [x] 验证写入字节
- [x] 验证换行行为
- [x] 验证缩进行为

### `tests/test_fmt_tokenizer.uya`
- [x] 验证 token 类型序列正确
- [x] 验证 token 数量正确
- [x] 验证位置信息存在

### `tests/test_fmt_parser.uya`
- [x] 验证能解析函数声明
- [x] 验证能解析 return
- [x] 验证能解析 `1 + 2 * 3` 的优先级
- [x] 验证能解析调用表达式

### `tests/test_fmt_printer.uya`
- [x] 验证 AST 可打印为稳定文本
- [x] 验证简单函数打印结果符合预期

### `tests/test_fmt_api.uya`
- [x] 验证 `format(source)` 返回预期文本
- [x] 验证 `is_formatted(source)` 判断正确
- [x] 验证 `format_result(source)` 返回 changed 信息
- [x] 验证 `format_result_with_options(...)` 支持 simplify / rewrite

### `tests/test_fmt_idempotent.uya`
- [x] 验证 `format(format(x)) == format(x)`

---

## Acceptance Sample

### Input

```uya
fn add(a,b){return a+b;}
fn main(){x=1+2;foo(x);}
```

### Expected Output

```uya
fn add(a, b) {
    return a + b;
}

fn main() {
    x = 1 + 2;
    foo(x);
}
```

- [x] 对预期输出再次执行 `format()`，结果完全一致

---

## Definition of Done

- [x] 存在最小 formatter 主链路：`tokenize -> parse -> print`
- [x] `format(source)` 可处理简单函数文件
- [x] 输出结果符合统一格式规则
- [x] 最小测试集全部通过
- [x] 通过幂等测试：`format(format(x)) == format(x)`
- [x] 不依赖编译器 `src/` 内部 parser / lexer
- [x] 库层 API 已补充 changed 信息返回能力
