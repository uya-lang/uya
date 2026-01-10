---
name: C to Go Compiler Migration Research Plan
overview: 研究将 Uya C 编译器迁移到 Go 的完整方案，包括架构映射、技术挑战分析和迁移策略。
todos: []
---

#C 编译器到 Go 迁移研究计划

## 项目概况

当前 C 编译器包含：

- **28个 C 源文件**，14个头文件
- **约30,000+ 行代码**（估算）
- **283个内存分配调用**（malloc/calloc/realloc）
- **961个内存释放调用**（free）
- **5个主要模块**：lexer, parser, checker, ir_generator, codegen

## 架构映射

### 模块结构对应关系

```javascript
C 版本                          →  Go 版本
compiler/src/lexer/            →  compiler-go/src/lexer/
compiler/src/parser/           →  compiler-go/src/parser/
compiler/src/checker/          →  compiler-go/src/checker/
compiler/src/ir/               →  compiler-go/src/ir/
compiler/src/ir_generator/     →  compiler-go/src/irgen/
compiler/src/codegen/          →  compiler-go/src/codegen/
compiler/src/main.c            →  compiler-go/cmd/uyac/main.go
```



### 数据流保持不变

```javascript
Uya源代码 → Lexer → Parser → AST → TypeChecker → IRGenerator → CodeGenerator → C99代码
```



## 关键技术挑战

### 1. 数据结构转换

**C Union → Go Interface/类型系统**

- `ASTNode.data` union → Go interface{} + 类型断言，或使用结构体嵌入
- `IRInst.data` union → 类似处理
- 推荐：为每种节点类型创建独立的结构体，使用接口统一

**C 枚举 → Go 常量/类型**

- `TokenType`, `ASTNodeType`, `IRInstType` → Go `const` + 自定义类型
- 保持值的一致性以便测试

### 2. 内存管理

**C 手动管理 → Go GC**

- 移除所有 `malloc/free` 调用
- 使用 Go 的结构体值和切片
- 字符串使用 Go 的 `string` 类型（不可变）
- 动态数组使用 `[]T` 切片，自动扩容

**指针使用**

- C 的 `*T` → Go 的 `*T`（仅在必要时使用）
- 大多数情况可以使用值类型，Go 的传值性能良好
- 共享数据使用指针

### 3. 错误处理

**C 模式：返回 NULL/错误码**

```c
ASTNode *parser_parse(Parser *parser) {
    if (!parser) return NULL;
    // ...
}
```

**Go 模式：返回 error**

```go
func (p *Parser) Parse() (*ASTNode, error) {
    if p == nil {
        return nil, errors.New("parser is nil")
    }
    // ...
}
```



### 4. 字符串处理

- C `char*` + `malloc` → Go `string`（不可变，GC管理）
- 字符串拼接使用 `strings.Builder` 或 `fmt.Sprintf`
- 文件路径使用 `filepath` 包

### 5. 文件 I/O

- C `FILE*` → Go `os.File` 或 `*bufio.Writer`
- 文件读取使用 `os.ReadFile` 或 `bufio.Scanner`
- 输出代码使用 `fmt.Fprintf` 或 `strings.Builder`

## 代码质量约束

### 严格的代码组织规则

1. **函数长度限制**

- 每个函数不超过 **150 行**
- 超过限制必须拆分为多个小函数
- 使用辅助函数提取逻辑

2. **文件长度限制**

- 每个文件不超过 **1500 行**
- 超过限制必须拆分为多个文件
- 按功能或类型分组到不同文件

3. **拆分策略**

- **按功能拆分**：将相关功能分组到独立文件
    - 例如：`lexer.go` (核心), `lexer_keywords.go` (关键字处理), `lexer_numbers.go` (数字解析)
- **按类型拆分**：将相关类型定义分组
    - 例如：`ast.go` (基础接口), `ast_decl.go` (声明节点), `ast_expr.go` (表达式节点)
- **提取辅助函数**：将复杂逻辑提取为独立函数
    - 私有辅助函数放在同一文件
    - 公共辅助函数可放在 `*_util.go` 或 `*_helper.go`

4. **文件命名约定**

- 核心文件：`package_name.go`（主类型和接口）
- 功能文件：`package_name_feature.go`（如 `lexer_numbers.go`）
- 测试文件：`package_name_test.go`
- 辅助文件：`package_name_util.go` 或 `package_name_helper.go`

## 迁移策略

### 阶段1：项目初始化

1. 创建 `compiler-go/` 目录结构
2. 初始化 Go 模块（`go mod init github.com/uya/compiler-go`）
3. 创建基础包结构，定义接口和常量
4. 设置测试框架
5. 设置代码质量检查工具（golangci-lint 配置函数和文件长度限制）

### 阶段2：核心数据结构迁移

1. **Token 和 Lexer**

- 迁移 `lexer.h` 中的 Token 类型定义
- 迁移 `lexer.c` 的实现
- **拆分策略**：
- `token.go`: Token 类型定义
- `lexer.go`: Lexer 核心结构和方法（<1500行）
- `lexer_keywords.go`: 关键字识别
- `lexer_numbers.go`: 数字字面量解析
- `lexer_strings.go`: 字符串和字符字面量解析
- `lexer_test.go`: 测试文件
- Go 优势：字符串处理更简单，无需手动内存管理

2. **AST 节点**

- 将 C union 转换为 Go 接口或结构体层次
- 创建 `ast.Node` 接口
- 为每种节点类型创建具体结构体
- **拆分策略**：
- `ast.go`: Node 接口和基础类型
- `ast_decl.go`: 声明节点（FuncDecl, VarDecl, StructDecl 等）
- `ast_expr.go`: 表达式节点（BinaryExpr, UnaryExpr, CallExpr 等）
- `ast_stmt.go`: 语句节点（IfStmt, WhileStmt, ReturnStmt 等）
- `ast_type.go`: 类型节点
- `ast_test.go`: 测试文件

3. **IR 指令**

- 类似 AST 的转换方式
- 使用接口 + 具体类型
- **拆分策略**：
- `ir.go`: IR 接口和基础类型
- `ir_inst.go`: 指令定义
- `ir_type.go`: 类型定义
- `ir_test.go`: 测试文件

### 阶段3：模块迁移（按依赖顺序，TDD驱动）

每个模块迁移时：

1. 先分析 C 代码，识别需要拆分的部分
2. 编写测试（TDD Red 阶段）
3. 实现功能，保持函数<150行，文件<1500行
4. 运行测试（TDD Green 阶段）
5. 重构优化（TDD Refactor 阶段）
6. **Lexer**（无依赖）

- 原文件：`lexer/lexer.c` (~450行), `lexer/lexer.h`
- 目标文件：
- `token.go`: Token 类型和常量（<500行）
- `lexer.go`: Lexer 核心（<1500行）
- `lexer_keywords.go`: 关键字表和处理（<300行）
- `lexer_numbers.go`: 数字解析（<300行）
- `lexer_strings.go`: 字符串/字符解析（<400行）
- `lexer_test.go`: 完整测试套件
- 复杂度：中等
- Go 优势：字符串处理、错误处理更清晰

2. **Parser**（依赖 Lexer）

- 原文件：`parser/*.c` (多个文件，总计~5000+行)
- 目标文件（按功能拆分）：
- `parser.go`: Parser 核心和接口（<1500行）
- `parser_decl.go`: 声明解析（<1500行）
- `parser_expr.go`: 表达式解析（<1500行）
- `parser_stmt.go`: 语句解析（<1500行）
- `parser_type.go`: 类型解析（<1000行）
- `parser_match.go`: match 表达式解析（<1000行）
- `parser_string_interp.go`: 字符串插值（<500行）
- `parser_test.go`: 测试文件
- 复杂度：高（多文件，递归下降解析）
- 关键：每个解析函数<150行，复杂解析拆分为多个辅助函数

3. **Checker**（依赖 Parser/AST）

- 原文件：`checker/*.c` (~4000+行)
- 目标文件：
- `checker.go`: TypeChecker 核心（<1500行）
- `checker_decl.go`: 声明检查（<1500行）
- `checker_expr.go`: 表达式检查（<1500行）
- `checker_stmt.go`: 语句检查（<1000行）
- `symbol_table.go`: 符号表管理（<800行）
- `constraints.go`: 约束系统（<1500行）
- `const_eval.go`: 常量求值（<800行）
- `checker_test.go`: 测试文件
- 复杂度：高（类型系统、约束系统）
- 关键：符号表管理（Go map 更简单），每个检查函数<150行

4. **IR Generator**（依赖 AST, IR）

- 原文件：`ir_generator*.c` (~3000+行), `ir/*.c`
- 目标文件：
- `ir/generator.go`: IRGenerator 核心（<1500行）
- `ir/generator_expr.go`: 表达式生成（<1500行）
- `ir/generator_stmt.go`: 语句生成（<1500行）
- `ir/generator_func.go`: 函数生成（<1000行）
- `ir/generator_type.go`: 类型生成（<800行）
- `ir/generator_test.go`: 测试文件
- 复杂度：高
- 关键：AST 到 IR 的转换逻辑，每个转换函数<150行

5. **Code Generator**（依赖 IR）

- 原文件：`codegen/*.c` (~4000+行)
- 目标文件：
- `codegen/generator.go`: CodeGenerator 核心（<1500行）
- `codegen/inst.go`: 指令生成（<1500行）
- `codegen/type.go`: 类型生成（<800行）
- `codegen/value.go`: 值生成（<800行）
- `codegen/error.go`: 错误处理生成（<600行）
- `codegen/main.go`: 主函数生成（<500行）
- `codegen/generator_test.go`: 测试文件
- 复杂度：高（代码生成逻辑）
- Go 优势：字符串格式化更强大，每个生成函数<150行

6. **Main**（协调所有模块）

- 原文件：`main.c` (~400行)
- 目标文件：
- `cmd/uyac/main.go`: 主程序（<800行）
- `cmd/uyac/compile.go`: 编译逻辑（<500行）
- `cmd/uyac/main_test.go`: 测试文件
- 复杂度：低
- Go 优势：错误处理、并发处理（如需要）

## 具体转换示例

### 示例1：结构体定义

**C 版本：**

```c
typedef struct Lexer {
    char *buffer;
    size_t buffer_size;
    size_t position;
    int line;
    int column;
    char *filename;
} Lexer;

Lexer *lexer_new(const char *filename) {
    Lexer *lexer = malloc(sizeof(Lexer));
    // ...
    return lexer;
}
```

**Go 版本：**

```go
type Lexer struct {
    buffer     string
    position   int
    line       int
    column     int
    filename   string
}

func NewLexer(filename string) (*Lexer, error) {
    data, err := os.ReadFile(filename)
    if err != nil {
        return nil, err
    }
    return &Lexer{
        buffer:   string(data),
        filename: filename,
        line:     1,
        column:   1,
    }, nil
}
```



### 示例3：函数拆分（保持<150行）

**C 版本（可能超过150行的函数）：**

```c
// 假设这是一个很长的解析函数（>200行）
ASTNode *parse_expression(Parser *parser) {
    // 处理数字字面量（50行代码）
    if (is_number(...)) {
        // ... 50行代码
    }
    // 处理字符串字面量（50行代码）
    else if (is_string(...)) {
        // ... 50行代码
    }
    // 处理函数调用（50行代码）
    else if (is_call(...)) {
        // ... 50行代码
    }
    // 处理二元表达式（50行代码）
    else if (is_binary(...)) {
        // ... 50行代码
    }
    return node;
}
```

**Go 版本（拆分为多个<150行的函数）：**

```go
// 主函数保持简洁（<50行）
func (p *Parser) parseExpression() (ast.Expr, error) {
    if p.match(token.NUMBER) {
        return p.parseNumberLiteral()
    }
    if p.match(token.STRING) {
        return p.parseStringLiteral()
    }
    if p.match(token.IDENTIFIER) && p.peek().Type == token.LEFT_PAREN {
        return p.parseCallExpression()
    }
    return p.parseBinaryExpression(0)
}

// 每个辅助函数<150行
func (p *Parser) parseNumberLiteral() (*ast.NumberLiteral, error) {
    // ... <100行代码
}

func (p *Parser) parseStringLiteral() (*ast.StringLiteral, error) {
    // ... <100行代码
}

func (p *Parser) parseCallExpression() (*ast.CallExpr, error) {
    // ... <120行代码
}

func (p *Parser) parseBinaryExpression(precedence int) (ast.Expr, error) {
    // ... <130行代码
}
```



### 示例4：Union 转换

```c
typedef struct ASTNode {
    ASTNodeType type;
    union {
        struct { char *name; ... } fn_decl;
        struct { ... } var_decl;
        // ...
    } data;
} ASTNode;
```

**Go 版本：**

```go
type Node interface {
    Type() ASTNodeType
    Line() int
    Column() int
    Filename() string
}

type FuncDecl struct {
    nodeBase
    Name       string
    Params     []*Param
    ReturnType Type
    Body       *Block
}

type VarDecl struct {
    nodeBase
    Name  string
    Type  Type
    Init  Expr
    IsMut bool
}
```



## TDD 测试驱动开发策略

### TDD 工作流程

每个模块遵循 **Red-Green-Refactor** 循环：

1. **Red**: 先写测试（定义接口和测试用例），运行测试确保失败
2. **Green**: 实现最小代码使测试通过
3. **Refactor**: 重构代码，保持测试通过

### 测试层级

1. **单元测试**（每个模块）

- 使用 Go 标准 `testing` 包
- 每个包都有对应的 `*_test.go` 文件
- 测试文件与被测文件在同一包内（可测试私有函数）

2. **集成测试**（模块协作）

- 测试完整编译流程
- 复用 `compiler/tests/` 中的 `.uya` 测试文件
- 比较生成的 C 代码输出是否与原 C 编译器一致

3. **端到端测试**（完整编译）

- 编译真实的 Uya 程序
- 验证生成的 C 代码可编译运行

### TDD 实施步骤（每个模块）

1. **定义接口**（基于 C 版本的函数签名转换为 Go）
2. **编写测试用例**（`*_test.go`）

- 测试正常情况
- 测试边界情况
- 测试错误情况

3. **运行测试**（`go test`）- 应该失败（Red）
4. **实现功能**（最小实现使测试通过）
5. **运行测试**（`go test`）- 应该通过（Green）
6. **重构优化**（保持测试通过）
7. **代码审查和文档**（添加注释和文档）

### 测试数据来源

- **单元测试数据**：从 C 代码中提取测试用例，或基于 C 版本的行为编写
- **集成测试数据**：直接使用 `compiler/tests/*.uya` 文件
- **预期输出**：使用原 C 编译器生成的结果作为 golden file

## 文件组织

```javascript
compiler-go/
├── cmd/
│   └── uyac/
│       ├── main.go          # 主程序入口（<800行）
│       ├── compile.go       # 编译逻辑（<500行）
│       └── main_test.go
├── src/
│   ├── lexer/               # 词法分析器
│   │   ├── token.go         # Token 类型（<500行）
│   │   ├── lexer.go         # 核心 Lexer（<1500行）
│   │   ├── lexer_keywords.go # 关键字处理（<300行）
│   │   ├── lexer_numbers.go  # 数字解析（<300行）
│   │   ├── lexer_strings.go  # 字符串解析（<400行）
│   │   └── lexer_test.go
│   ├── parser/              # 语法分析器
│   │   ├── parser.go        # Parser 核心（<1500行）
│   │   ├── parser_decl.go   # 声明解析（<1500行）
│   │   ├── parser_expr.go   # 表达式解析（<1500行）
│   │   ├── parser_stmt.go   # 语句解析（<1500行）
│   │   ├── parser_type.go   # 类型解析（<1000行）
│   │   ├── parser_match.go  # match 表达式（<1000行）
│   │   ├── parser_string_interp.go # 字符串插值（<500行）
│   │   ├── ast.go           # Node 接口和基础（<800行）
│   │   ├── ast_decl.go      # 声明节点（<1000行）
│   │   ├── ast_expr.go      # 表达式节点（<1200行）
│   │   ├── ast_stmt.go      # 语句节点（<1000行）
│   │   ├── ast_type.go      # 类型节点（<800行）
│   │   └── parser_test.go
│   ├── checker/             # 类型检查器
│   │   ├── checker.go       # TypeChecker 核心（<1500行）
│   │   ├── checker_decl.go  # 声明检查（<1500行）
│   │   ├── checker_expr.go  # 表达式检查（<1500行）
│   │   ├── checker_stmt.go  # 语句检查（<1000行）
│   │   ├── symbol_table.go  # 符号表（<800行）
│   │   ├── constraints.go   # 约束系统（<1500行）
│   │   ├── const_eval.go    # 常量求值（<800行）
│   │   └── checker_test.go
│   ├── ir/                  # 中间表示和生成器
│   │   ├── ir.go            # IR 接口和基础（<1000行）
│   │   ├── ir_inst.go       # 指令定义（<1200行）
│   │   ├── ir_type.go       # 类型定义（<800行）
│   │   ├── generator.go     # IRGenerator 核心（<1500行）
│   │   ├── generator_expr.go # 表达式生成（<1500行）
│   │   ├── generator_stmt.go # 语句生成（<1500行）
│   │   ├── generator_func.go # 函数生成（<1000行）
│   │   ├── generator_type.go # 类型生成（<800行）
│   │   └── ir_test.go
│   └── codegen/             # 代码生成器
│       ├── generator.go     # CodeGenerator 核心（<1500行）
│       ├── inst.go          # 指令生成（<1500行）
│       ├── type.go          # 类型生成（<800行）
│       ├── value.go         # 值生成（<800行）
│       ├── error.go         # 错误处理（<600行）
│       ├── main.go          # 主函数生成（<500行）
│       └── generator_test.go
├── tests/                   # 测试用例（复用 compiler/tests/）
├── go.mod
├── .golangci.yml            # Linter 配置（包含行数限制）
└── README.md
```



### 文件拆分检查清单

迁移每个模块时，检查：

- [ ] 每个 `.go` 文件是否 < 1500 行
- [ ] 每个函数是否 < 150 行
- [ ] 超过限制的文件是否已拆分
- [ ] 超过限制的函数是否已提取为辅助函数
- [ ] 文件命名是否符合约定
- [ ] 测试文件是否完整覆盖

## 优势与风险

### Go 迁移的优势

1. **内存安全**：GC 自动管理，避免内存泄漏
2. **错误处理**：显式 error 返回，更安全
3. **代码可读性**：接口和结构体更清晰
4. **测试支持**：内置测试框架
5. **并发能力**：如需要可轻松添加并发编译
6. **工具链**：go fmt, go vet, go test 等工具

### 潜在风险

1. **性能**：GC 可能带来轻微性能开销（但编译器通常不是性能瓶颈）
2. **学习曲线**：需要熟悉 Go 语言特性
3. **迁移时间**：需要逐模块迁移和测试

## 下一步行动（TDD 驱动）

1. ✅ 研究现有 C 代码结构（已完成）
2. ✅ 创建迁移计划文档（本文档）
3. ⏭️ 初始化 Go 项目结构

- 创建目录结构
- 初始化 `go mod`
- 配置 `.golangci.yml`（设置函数和文件长度限制）

4. ⏭️ Lexer 模块迁移（TDD 试点）

- 分析 `lexer.c` 代码，规划拆分策略
- 编写 `token_test.go`（TDD Red）
- 实现 `token.go`（TDD Green）
- 编写 `lexer_test.go`（TDD Red）
- 实现 `lexer.go` 和拆分文件（TDD Green）
- 重构优化（TDD Refactor）
- 验证所有文件<1500行，函数<150行

5. ⏭️ 建立测试框架

- 设置集成测试框架
- 复用 `compiler/tests/*.uya` 文件

6. ⏭️ 按依赖顺序迁移其他模块（每个模块都遵循 TDD 流程）