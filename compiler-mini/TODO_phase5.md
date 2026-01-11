# 阶段5：实现语法分析器（Parser）

## 5.1 Parser 结构定义

- [x] 创建 `src/parser.h`
  - [x] 定义 Parser 结构体（Lexer 指针、当前 Token 等）
  - [x] 声明解析函数
  - [x] 添加中文注释说明

## 5.2 Parser 核心实现（TDD，必须分部实现）

**注意**：Parser 功能复杂，必须分多次会话完成，不能简化。

### TDD Red: 编写测试

- [x] 创建测试文件
  - [x] 测试函数声明解析
  - [x] 测试结构体声明解析
  - [x] 测试表达式解析
  - [x] 测试结构体字面量和字段访问解析
  - [x] 运行测试确保失败

### TDD Green: 实现功能（分多次会话）

**会话1：基础解析功能** ✅ 已完成
- [x] 创建 `src/parser.c`
- [x] 实现 `parser_init()` - 初始化 Parser（使用栈分配，不使用堆分配）
- [x] 实现 `parser_parse()` - 解析程序的基础框架
- [x] 实现辅助函数（parser_match, parser_consume, parser_expect）
- [x] 创建测试文件 `tests/test_parser.c`
- [x] 运行测试通过，更新 PROGRESS.md

**会话2：函数和结构体解析** ✅ 已完成
- [x] 实现 `parser_parse_type()` - 解析类型（i32, bool, void, 结构体名称）
- [x] 实现 `arena_strdup()` 辅助函数
- [x] 实现 `parser_parse_declaration()` - 解析声明基础框架
- [x] 实现 `parser_parse_function()` - 解析函数声明（完整实现，不能简化）
- [x] 实现 `parser_parse_struct()` - 解析结构体声明（完整实现，不能简化）
- [x] 运行测试，更新 PROGRESS.md

**会话3：语句解析** ✅ 已完成
- [x] 实现 `parser_parse_statement()` - 解析语句（完整实现）
- [x] 运行测试，更新 PROGRESS.md

**会话4：表达式解析** ✅ 已完成
- [x] 实现 `parser_parse_expression()` - 解析表达式（完整实现，不能简化）
- [x] 实现结构体字面量解析（完整实现）
- [x] 实现字段访问解析（完整实现）
- [x] 运行测试，更新 PROGRESS.md

**所有会话完成后：**
- [x] 所有 AST 节点从 Arena 分配
- [x] 添加中文注释说明
- [x] **验证每个函数 < 200 行，文件 < 1500 行**
- [x] **如果文件超过 1500 行，拆分为 parser_*.c 多个文件**（文件正好1500行，不需要拆分）

### TDD Refactor: 优化

- [x] 代码审查和重构
- [x] 运行所有测试确保通过

## 5.3 Parser 测试

- [x] 创建测试用例验证 Parser 功能
- [x] 测试函数解析
- [x] 测试结构体解析
- [x] 测试表达式解析
- [x] 测试结构体字面量和字段访问解析

