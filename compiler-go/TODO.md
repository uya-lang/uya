# Uya 编译器 C 到 Go 迁移待办事项

本文档跟踪从 C 编译器迁移到 Go 编译器的详细任务列表。

## 代码质量约束

- ✅ 每个函数不超过 **150 行**
- ✅ 每个文件不超过 **1500 行**
- ✅ 遵循 TDD（测试驱动开发）方法
- ✅ 每个模块都有完整的测试覆盖

---

## 阶段1：项目初始化

### 1.1 创建项目结构

- [ ] 创建 `compiler-go/` 目录
- [ ] 创建目录结构：
  - [ ] `cmd/uyac/`
  - [ ] `src/lexer/`
  - [ ] `src/parser/`
  - [ ] `src/checker/`
  - [ ] `src/ir/`
  - [ ] `src/codegen/`
  - [ ] `tests/`（复用 compiler/tests/）

### 1.2 初始化 Go 模块

- [ ] 运行 `go mod init github.com/uya/compiler-go`
- [ ] 创建 `README.md`（项目说明）
- [ ] 创建 `.gitignore`（Go 项目标准）

### 1.3 配置开发工具

- [ ] 创建 `.golangci.yml` 配置文件
  - [ ] 配置函数长度限制（max-func-body-length: 150）
  - [ ] 配置文件长度检查
  - [ ] 启用常用 linter 规则
- [ ] 创建 `Makefile` 或构建脚本
  - [ ] `make test` - 运行所有测试
  - [ ] `make lint` - 运行 linter
  - [ ] `make build` - 构建编译器

---

## 阶段2：Lexer 模块迁移（TDD 驱动）

### 2.1 Token 类型定义

#### TDD Red: 编写测试

- [ ] 创建 `src/lexer/token_test.go`
  - [ ] 测试 TokenType 枚举值
  - [ ] 测试 Token 结构体
  - [ ] 测试 Token 创建函数

#### TDD Green: 实现功能

- [ ] 创建 `src/lexer/token.go`（<500行）
  - [ ] 定义 TokenType 类型和常量（从 lexer.h 迁移）
  - [ ] 定义 Token 结构体
  - [ ] 实现 Token 创建辅助函数
  - [ ] 验证文件<500行

#### TDD Refactor: 优化

- [ ] 代码审查和重构
- [ ] 运行测试确保通过
- [ ] 运行 linter 检查

### 2.2 Lexer 核心实现

#### TDD Red: 编写测试

- [ ] 扩展 `src/lexer/lexer_test.go`
  - [ ] 测试 Lexer 创建（NewLexer）
  - [ ] 测试基本 Token 识别（标识符、关键字）
  - [ ] 测试数字字面量
  - [ ] 测试字符串字面量
  - [ ] 测试字符字面量
  - [ ] 测试运算符和标点符号
  - [ ] 测试注释处理
  - [ ] 测试错误情况

#### TDD Green: 实现核心 Lexer

- [ ] 创建 `src/lexer/lexer.go`（<1500行）
  - [ ] 定义 Lexer 结构体
  - [ ] 实现 NewLexer 函数（文件读取）
  - [ ] 实现 NextToken 主函数（<150行）
  - [ ] 实现 peek/advance 辅助函数（<50行每个）
  - [ ] 实现 skipWhitespace 函数（<80行）
  - [ ] 实现基本 Token 识别逻辑
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现关键字处理

- [ ] 创建 `src/lexer/lexer_keywords.go`（<300行）
  - [ ] 定义关键字映射表
  - [ ] 实现 isKeyword 函数（<150行）
  - [ ] 实现关键字识别逻辑
  - [ ] 验证文件<300行

#### TDD Green: 实现数字解析

- [ ] 创建 `src/lexer/lexer_numbers.go`（<300行）
  - [ ] 实现 parseNumber 函数（<150行）
  - [ ] 支持整数和浮点数
  - [ ] 处理数字字面量边界情况
  - [ ] 验证文件<300行

#### TDD Green: 实现字符串/字符解析

- [ ] 创建 `src/lexer/lexer_strings.go`（<400行）
  - [ ] 实现 parseString 函数（<150行）
  - [ ] 实现 parseChar 函数（<150行）
  - [ ] 处理转义序列
  - [ ] 处理字符串插值开始标记
  - [ ] 验证文件<400行

#### TDD Refactor: 优化 Lexer

- [ ] 代码审查
- [ ] 提取重复代码为辅助函数
- [ ] 运行所有测试
- [ ] 运行 linter 检查
- [ ] 验证所有文件符合行数限制

### 2.3 Lexer 集成测试

- [ ] 创建集成测试
  - [ ] 测试完整的源代码文件词法分析
  - [ ] 复用 `compiler/tests/` 中的简单测试文件
  - [ ] 验证输出 Token 序列正确性

---

## 阶段3：Parser 和 AST 模块迁移（TDD 驱动）

### 3.1 AST 节点定义

#### TDD Red: 编写测试

- [ ] 创建 `src/parser/ast_test.go`
  - [ ] 测试 Node 接口
  - [ ] 测试基础节点类型
  - [ ] 测试节点位置信息

#### TDD Green: 实现 AST 基础

- [ ] 创建 `src/parser/ast.go`（<800行）
  - [ ] 定义 Node 接口
  - [ ] 定义 nodeBase 结构体（位置信息）
  - [ ] 定义 ASTNodeType 类型和常量
  - [ ] 定义基础类型（Type 接口等）
  - [ ] 验证文件<800行

#### TDD Green: 实现声明节点

- [ ] 创建 `src/parser/ast_decl.go`（<1000行）
  - [ ] 定义 FuncDecl 结构体
  - [ ] 定义 VarDecl 结构体
  - [ ] 定义 StructDecl 结构体
  - [ ] 定义 EnumDecl 结构体
  - [ ] 定义 InterfaceDecl 结构体
  - [ ] 定义 ErrorDecl 结构体
  - [ ] 定义 ExternDecl 结构体
  - [ ] 实现各类型的 Type() 方法（每个<20行）
  - [ ] 验证文件<1000行，函数<150行

#### TDD Green: 实现表达式节点

- [ ] 创建 `src/parser/ast_expr.go`（<1200行）
  - [ ] 定义 Expr 接口
  - [ ] 定义 BinaryExpr 结构体
  - [ ] 定义 UnaryExpr 结构体
  - [ ] 定义 CallExpr 结构体
  - [ ] 定义 Identifier 结构体
  - [ ] 定义 NumberLiteral 结构体
  - [ ] 定义 StringLiteral 结构体
  - [ ] 定义 BoolLiteral 结构体
  - [ ] 定义其他表达式类型
  - [ ] 实现各类型的 Type() 方法
  - [ ] 验证文件<1200行，函数<150行

#### TDD Green: 实现语句节点

- [ ] 创建 `src/parser/ast_stmt.go`（<1000行）
  - [ ] 定义 Stmt 接口
  - [ ] 定义 IfStmt 结构体
  - [ ] 定义 WhileStmt 结构体
  - [ ] 定义 ForStmt 结构体
  - [ ] 定义 ReturnStmt 结构体
  - [ ] 定义 Block 结构体
  - [ ] 定义其他语句类型
  - [ ] 实现各类型的 Type() 方法
  - [ ] 验证文件<1000行，函数<150行

#### TDD Green: 实现类型节点

- [ ] 创建 `src/parser/ast_type.go`（<800行）
  - [ ] 定义 Type 接口
  - [ ] 定义 NamedType 结构体
  - [ ] 定义 PointerType 结构体
  - [ ] 定义 ArrayType 结构体
  - [ ] 定义 FuncType 结构体
  - [ ] 定义 ErrorUnionType 结构体
  - [ ] 定义其他类型节点
  - [ ] 验证文件<800行，函数<150行

#### TDD Refactor: 优化 AST

- [ ] 代码审查
- [ ] 运行所有测试
- [ ] 运行 linter 检查

### 3.2 Parser 核心实现

#### TDD Red: 编写测试

- [ ] 创建 `src/parser/parser_test.go`
  - [ ] 测试 Parser 创建
  - [ ] 测试基础解析函数（expect, match, consume）
  - [ ] 测试简单程序解析

#### TDD Green: 实现 Parser 核心

- [ ] 创建 `src/parser/parser.go`（<1500行）
  - [ ] 定义 Parser 结构体
  - [ ] 实现 NewParser 函数
  - [ ] 实现 Parse 函数（主入口，<150行）
  - [ ] 实现 expect/match/consume 函数（每个<50行）
  - [ ] 实现错误处理机制
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现声明解析

- [ ] 创建 `src/parser/parser_decl.go`（<1500行）
  - [ ] 实现 parseDeclaration 函数（<100行）
  - [ ] 实现 parseFuncDecl 函数（<150行）
  - [ ] 实现 parseVarDecl 函数（<150行）
  - [ ] 实现 parseStructDecl 函数（<150行）
  - [ ] 实现 parseEnumDecl 函数（<150行）
  - [ ] 实现 parseInterfaceDecl 函数（<150行）
  - [ ] 实现 parseErrorDecl 函数（<100行）
  - [ ] 实现其他声明解析函数
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现表达式解析

- [ ] 创建 `src/parser/parser_expr.go`（<1500行）
  - [ ] 实现 parseExpression 函数（主入口，<80行）
  - [ ] 实现 parseBinaryExpression 函数（<150行）
  - [ ] 实现 parseUnaryExpression 函数（<100行）
  - [ ] 实现 parseCallExpression 函数（<150行）
  - [ ] 实现 parsePrimaryExpression 函数（<150行）
  - [ ] 实现 parseNumberLiteral 函数（<80行）
  - [ ] 实现 parseStringLiteral 函数（<100行）
  - [ ] 实现其他表达式解析函数
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现语句解析

- [ ] 创建 `src/parser/parser_stmt.go`（<1500行）
  - [ ] 实现 parseStatement 函数（主入口，<100行）
  - [ ] 实现 parseIfStmt 函数（<150行）
  - [ ] 实现 parseWhileStmt 函数（<100行）
  - [ ] 实现 parseForStmt 函数（<150行）
  - [ ] 实现 parseReturnStmt 函数（<80行）
  - [ ] 实现 parseBlock 函数（<100行）
  - [ ] 实现其他语句解析函数
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现类型解析

- [ ] 创建 `src/parser/parser_type.go`（<1000行）
  - [ ] 实现 parseType 函数（主入口，<100行）
  - [ ] 实现 parseNamedType 函数（<80行）
  - [ ] 实现 parsePointerType 函数（<80行）
  - [ ] 实现 parseArrayType 函数（<100行）
  - [ ] 实现 parseFuncType 函数（<150行）
  - [ ] 实现其他类型解析函数
  - [ ] 验证文件<1000行，所有函数<150行

#### TDD Green: 实现 match 表达式解析

- [ ] 创建 `src/parser/parser_match.go`（<1000行）
  - [ ] 实现 parseMatchExpr 函数（<150行）
  - [ ] 实现 parsePattern 函数（<150行）
  - [ ] 实现模式匹配相关辅助函数
  - [ ] 验证文件<1000行，所有函数<150行

#### TDD Green: 实现字符串插值解析

- [ ] 创建 `src/parser/parser_string_interp.go`（<500行）
  - [ ] 实现 parseStringInterpolation 函数（<150行）
  - [ ] 实现解析插值表达式的辅助函数
  - [ ] 验证文件<500行，所有函数<150行

#### TDD Refactor: 优化 Parser

- [ ] 代码审查
- [ ] 提取重复代码
- [ ] 运行所有测试
- [ ] 运行 linter 检查
- [ ] 验证所有文件符合行数限制

### 3.3 Parser 集成测试

- [ ] 创建集成测试
  - [ ] 测试完整程序解析
  - [ ] 复用 `compiler/tests/` 中的测试文件
  - [ ] 验证生成的 AST 结构正确性

---

## 阶段4：Checker 模块迁移（TDD 驱动）

### 4.1 符号表和基础结构

#### TDD Red: 编写测试

- [ ] 创建 `src/checker/checker_test.go`
  - [ ] 测试符号表操作
  - [ ] 测试作用域管理

#### TDD Green: 实现符号表

- [ ] 创建 `src/checker/symbol_table.go`（<800行）
  - [ ] 定义 Symbol 结构体
  - [ ] 定义 SymbolTable 结构体
  - [ ] 实现符号表操作方法（每个<100行）
  - [ ] 实现作用域管理
  - [ ] 验证文件<800行，所有函数<150行

### 4.2 TypeChecker 核心实现

#### TDD Red: 编写测试

- [ ] 扩展 `src/checker/checker_test.go`
  - [ ] 测试类型检查基础功能
  - [ ] 测试简单程序类型检查

#### TDD Green: 实现 TypeChecker 核心

- [ ] 创建 `src/checker/checker.go`（<1500行）
  - [ ] 定义 TypeChecker 结构体
  - [ ] 实现 NewTypeChecker 函数
  - [ ] 实现 Check 函数（主入口，<150行）
  - [ ] 实现错误收集和报告机制
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现声明检查

- [ ] 创建 `src/checker/checker_decl.go`（<1500行）
  - [ ] 实现 checkDeclaration 函数（<100行）
  - [ ] 实现 checkFuncDecl 函数（<150行）
  - [ ] 实现 checkVarDecl 函数（<150行）
  - [ ] 实现 checkStructDecl 函数（<150行）
  - [ ] 实现其他声明检查函数
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现表达式检查

- [ ] 创建 `src/checker/checker_expr.go`（<1500行）
  - [ ] 实现 checkExpression 函数（主入口，<100行）
  - [ ] 实现 checkBinaryExpr 函数（<150行）
  - [ ] 实现 checkUnaryExpr 函数（<100行）
  - [ ] 实现 checkCallExpr 函数（<150行）
  - [ ] 实现类型转换检查
  - [ ] 实现其他表达式检查函数
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现语句检查

- [ ] 创建 `src/checker/checker_stmt.go`（<1000行）
  - [ ] 实现 checkStatement 函数（主入口，<100行）
  - [ ] 实现 checkIfStmt 函数（<150行）
  - [ ] 实现 checkWhileStmt 函数（<100行）
  - [ ] 实现 checkReturnStmt 函数（<100行）
  - [ ] 实现其他语句检查函数
  - [ ] 验证文件<1000行，所有函数<150行

#### TDD Green: 实现约束系统

- [ ] 创建 `src/checker/constraints.go`（<1500行）
  - [ ] 定义约束结构
  - [ ] 实现约束添加和检查函数
  - [ ] 实现路径敏感分析
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现常量求值

- [ ] 创建 `src/checker/const_eval.go`（<800行）
  - [ ] 实现常量表达式求值函数
  - [ ] 支持编译时常量计算
  - [ ] 验证文件<800行，所有函数<150行

#### TDD Refactor: 优化 Checker

- [ ] 代码审查
- [ ] 运行所有测试
- [ ] 运行 linter 检查
- [ ] 验证所有文件符合行数限制

### 4.3 Checker 集成测试

- [ ] 创建集成测试
  - [ ] 测试类型检查功能
  - [ ] 测试错误检测
  - [ ] 验证类型错误报告正确性

---

## 阶段5：IR 模块迁移（TDD 驱动）

### 5.1 IR 基础定义

#### TDD Red: 编写测试

- [ ] 创建 `src/ir/ir_test.go`
  - [ ] 测试 IR 类型定义
  - [ ] 测试 IR 指令创建

#### TDD Green: 实现 IR 基础

- [ ] 创建 `src/ir/ir.go`（<1000行）
  - [ ] 定义 IRType 类型和常量
  - [ ] 定义 IROp 类型和常量
  - [ ] 定义 IRInstType 类型和常量
  - [ ] 定义 Inst 接口
  - [ ] 定义基础 IR 结构
  - [ ] 验证文件<1000行

#### TDD Green: 实现 IR 指令定义

- [ ] 创建 `src/ir/ir_inst.go`（<1200行）
  - [ ] 定义各种 IR 指令结构体
  - [ ] 实现指令创建函数（每个<100行）
  - [ ] 验证文件<1200行，所有函数<150行

#### TDD Green: 实现 IR 类型定义

- [ ] 创建 `src/ir/ir_type.go`（<800行）
  - [ ] 定义 IR 类型系统
  - [ ] 实现类型转换函数
  - [ ] 验证文件<800行，所有函数<150行

#### TDD Refactor: 优化 IR

- [ ] 代码审查
- [ ] 运行所有测试
- [ ] 运行 linter 检查

### 5.2 IR Generator 实现

#### TDD Red: 编写测试

- [ ] 创建 `src/ir/generator_test.go`
  - [ ] 测试 IRGenerator 创建
  - [ ] 测试简单 AST 到 IR 转换

#### TDD Green: 实现 IRGenerator 核心

- [ ] 创建 `src/ir/generator.go`（<1500行）
  - [ ] 定义 IRGenerator 结构体
  - [ ] 实现 NewIRGenerator 函数
  - [ ] 实现 Generate 函数（主入口，<150行）
  - [ ] 实现 IR 指令管理
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现表达式生成

- [ ] 创建 `src/ir/generator_expr.go`（<1500行）
  - [ ] 实现 generateExpression 函数（主入口，<100行）
  - [ ] 实现各种表达式到 IR 的转换函数（每个<150行）
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现语句生成

- [ ] 创建 `src/ir/generator_stmt.go`（<1500行）
  - [ ] 实现 generateStatement 函数（主入口，<100行）
  - [ ] 实现各种语句到 IR 的转换函数（每个<150行）
  - [ ] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现函数生成

- [ ] 创建 `src/ir/generator_func.go`（<1000行）
  - [ ] 实现 generateFunction 函数（<150行）
  - [ ] 实现函数参数和返回处理
  - [ ] 验证文件<1000行，所有函数<150行

#### TDD Green: 实现类型生成

- [ ] 创建 `src/ir/generator_type.go`（<800行）
  - [ ] 实现类型到 IR 类型的转换函数
  - [ ] 验证文件<800行，所有函数<150行

#### TDD Refactor: 优化 IR Generator

- [ ] 代码审查
- [ ] 运行所有测试
- [ ] 运行 linter 检查
- [ ] 验证所有文件符合行数限制

### 5.3 IR Generator 集成测试

- [ ] 创建集成测试
  - [ ] 测试完整程序的 IR 生成
  - [ ] 验证生成的 IR 结构正确性

---

## 阶段6：CodeGen 模块迁移（TDD 驱动）

### 6.1 CodeGenerator 核心实现

#### TDD Red: 编写测试

- [x] 创建 `src/codegen/generator_test.go`
  - [x] 测试 CodeGenerator 创建
  - [x] 测试简单 IR 到 C 代码生成

#### TDD Green: 实现 CodeGenerator 核心

- [x] 创建 `src/codegen/generator.go`（<1500行）
  - [x] 定义 CodeGenerator 结构体
  - [x] 实现 NewCodeGenerator 函数
  - [x] 实现 Generate 函数（主入口，<150行）
  - [x] 实现代码输出管理
  - [x] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现指令生成

- [x] 创建 `src/codegen/inst.go`（<1500行）
  - [x] 实现 generateInstruction 函数（主入口，<100行）
  - [x] 实现各种 IR 指令到 C 代码的转换函数（每个<150行）
  - [x] 验证文件<1500行，所有函数<150行

#### TDD Green: 实现类型生成

- [x] 创建 `src/codegen/type.go`（<800行）
  - [x] 实现 IR 类型到 C 类型的转换函数
  - [x] 验证文件<800行，所有函数<150行

#### TDD Green: 实现值生成

- [x] 创建 `src/codegen/value.go`（<800行）
  - [x] 实现值到 C 代码的转换函数
  - [x] 验证文件<800行，所有函数<150行

#### TDD Green: 实现错误处理生成

- [x] 创建 `src/codegen/error.go`（<600行）
  - [x] 实现错误联合类型代码生成
  - [x] 实现错误处理代码生成
  - [x] 验证文件<600行，所有函数<150行

#### TDD Green: 实现主函数生成

- [x] 创建 `src/codegen/main.go`（<500行）
  - [x] 实现主函数生成逻辑
  - [x] 验证文件<500行，所有函数<150行

#### TDD Refactor: 优化 CodeGenerator

- [x] 代码审查
- [x] 运行所有测试
- [x] 运行 linter 检查
- [x] 验证所有文件符合行数限制

### 6.2 CodeGen 集成测试

- [ ] 创建集成测试
  - [ ] 测试完整程序的代码生成
  - [ ] 与 C 编译器输出对比验证
  - [ ] 验证生成的 C 代码可编译

---

## 阶段7：Main 程序集成（TDD 驱动）

### 7.1 主程序实现

#### TDD Red: 编写测试

- [x] 创建 `cmd/uyac/main_test.go`
  - [x] 测试编译流程
  - [x] 测试错误处理

#### TDD Green: 实现主程序

- [x] 创建 `cmd/uyac/main.go`（<800行）
  - [x] 实现 main 函数（<100行）
  - [x] 实现命令行参数解析
  - [x] 实现错误处理和退出码
  - [x] 验证文件<800行，所有函数<150行

#### TDD Green: 实现编译逻辑

- [x] 创建 `cmd/uyac/compile.go`（<500行）
  - [x] 实现 compileFile 函数（<150行）
  - [x] 整合所有模块的调用流程
  - [x] 实现资源清理
  - [x] 验证文件<500行，所有函数<150行

#### TDD Refactor: 优化主程序

- [x] 代码审查
- [x] 运行所有测试
- [x] 运行 linter 检查

### 7.2 端到端测试

- [ ] 创建端到端测试套件
  - [ ] 测试完整编译流程
  - [ ] 使用 `compiler/tests/` 中的所有测试文件
  - [ ] 对比生成的 C 代码与 C 编译器输出
  - [ ] 验证生成的 C 代码可以编译和运行

---

## 阶段8：优化和收尾

### 8.1 代码质量检查

- [ ] 运行完整的 linter 检查
- [ ] 检查所有文件<1500行
- [ ] 检查所有函数<150行
- [ ] 修复所有代码质量问题

### 8.2 文档

- [ ] 编写 API 文档（godoc）
- [ ] 更新 README.md
- [ ] 编写迁移说明文档
- [ ] 记录已知问题和限制

### 8.3 性能对比

- [ ] 性能基准测试
- [ ] 与 C 编译器性能对比
- [ ] 内存使用对比
- [ ] 记录性能数据

### 8.4 最终验证

- [x] 运行完整的测试套件（所有测试通过）
- [x] 验证所有测试通过（6个包的测试全部通过）
- [ ] 验证代码质量检查通过（部分完成：linter检查通过，文件/函数长度检查待完成）
- [ ] 准备发布

---

## 进度跟踪

- **阶段1**: 100% - 项目初始化 ✅
- **阶段2**: 100% - Lexer 模块 ✅
- **阶段3**: 100% - Parser 和 AST 模块 ✅
- **阶段4**: 100% - Checker 模块 ✅
- **阶段5**: ~80% - IR 模块 ⏭️ (核心功能已完成，复杂表达式类型标记为TODO)
- **阶段6**: ~90% - CodeGen 模块 ⏭️ (核心功能已完成，部分功能标记为TODO)
- **阶段7**: 100% - Main 程序集成 ✅
- **阶段8**: 0% - 优化和收尾 ⏭️

**总体进度**: ~75%

---

## 注意事项

1. **严格遵守 TDD 流程**：每个功能先写测试，再写实现
2. **严格遵守代码质量约束**：函数<150行，文件<1500行
3. **持续集成**：每个阶段完成后运行完整测试套件
4. **代码审查**：每个模块完成后进行代码审查
5. **文档同步**：实现功能时同步更新文档

