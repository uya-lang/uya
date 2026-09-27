# @asm 内置函数详细实施计划（基于实际代码）

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**创建日期**：2026-02-23  
**项目状态**：基于 Uya 自举编译器实施  
**优先级**：P0（核心功能）

---

## 📋 项目背景

### 实际项目结构
```
../
├── src/                    # 编译器源代码（Uya 自举）
│   ├── lexer.uya          # 词法分析器（43.38 KB）
│   ├── ast.uya            # AST 节点定义（26.26 KB）
│   ├── parser/            # 语法解析器
│   │   ├── primary.uya    # 基础表达式解析（111.45 KB）
│   │   ├── expressions.uya # 表达式解析（35.95 KB）
│   │   └── ...
│   ├── checker/           # 类型检查器
│   │   ├── types.uya      # 类型定义（6.64 KB）
│   │   ├── check_expr.uya # 表达式检查（61.43 KB）
│   │   └── ...
│   └── codegen/c99/       # C99 代码生成
│       ├── expr.uya       # 表达式生成（143.04 KB）
│       ├── stmt.uya       # 语句生成（87.63 KB）
│       └── ...
├── tests/                 # 测试文件
└── docs/                  # 文档
```

### 关键发现
1. ✅ **编译器已自举**：所有源码在 `src/*.uya` 文件中
2. ✅ **无 C 代码**：没有 `compiler-c/` 目录
3. ✅ **完整工具链**：lexer、parser、checker、codegen 都已实现
4. ⚠️ **需要修改 Uya 代码**：实施计划中的 C 代码示例需要调整为 Uya 语法

---

## 🎯 第一阶段：基础架构（第1周，3-5天）

### 目标
建立 @asm 的基础语法和类型系统，能够编译简单的 @asm 块。

---

### Day 1-2：Lexer 和 AST（预计 2 天）

#### ✅ Task 1.1：Lexer 支持 `@asm` 关键字

**文件**：`src/lexer.uya`  
**修改点**：第 48 行附近（内置函数识别）

**修改前**：
```uya
// 当前代码（lexer.uya 第 48 行）
TOKEN_AT_IDENTIFIER,  // @ 后跟内置函数标识符（@size_of、@align_of、@len、@max、@min）
```

**修改后**：
```uya
// 无需修改 TokenType 枚举，@asm 会被识别为 TOKEN_AT_IDENTIFIER
// 需要在 parser 中添加对 @asm 的特殊处理
```

**风险识别**：
- ⚠️ **风险**：可能与其他 `@` 开头的内置函数冲突
- ✅ **化解**：在 parser 中明确检查 `@asm` 标识符

**验收标准**：
```bash
# 测试代码
echo '@asm { "nop" (); }' | bin/uya --lex-only -
# 应该输出：TOKEN_AT_IDENTIFIER "asm"
```

---

#### ✅ Task 1.2：AST 添加 `AST_ASM` 节点类型

**文件**：`src/ast.uya`  
**修改点 1**：第 46-100 行（ASTNodeType 枚举）

**修改前**：
```uya
enum ASTNodeType {
    AST_PROGRAM,
    AST_ENUM_DECL,
    // ... 其他节点类型 ...
    AST_MC_EVAL,        // @mc_eval(expr) - 宏内求值表达式
}
```

**修改后**：
```uya
enum ASTNodeType {
    AST_PROGRAM,
    AST_ENUM_DECL,
    // ... 其他节点类型 ...
    AST_MC_EVAL,        // @mc_eval(expr) - 宏内求值表达式
    AST_ASM,            // @asm 块（新增）
}
```

**修改点 2**：第 130-156 行（ASTNode 结构体）

**修改前**：
```uya
struct ASTNode {
    type: ASTNodeType,
    // ... 其他字段 ...
    // 以下为各种节点数据的字段（扁平化）
    // 不使用 union，所有字段独立
}
```

**修改后**：
```uya
struct ASTNode {
    type: ASTNodeType,
    // ... 其他字段 ...
    
    // === @asm 块相关字段（新增）===
    asm_instructions: & & byte,      // 指令字符串数组
    asm_instruction_count: i32,      // 指令数量
    asm_inputs: & & ASTNode,         // 输入表达式数组
    asm_input_count: i32,            // 输入个数
    asm_outputs: & & ASTNode,        // 输出表达式数组
    asm_output_count: i32,           // 输出个数
    asm_clobbers: & & byte,          // clobber 寄存器数组
    asm_clobber_count: i32,          // clobber 个数
    asm_clobbers_memory: i32,        // 是否修改内存（1=是）
}
```

**风险识别**：
- ⚠️ **风险 1**：结构体字段过多，影响内存布局
  - **化解**：Uya 编译器已经使用扁平化设计，影响可控
- ⚠️ **风险 2**：字段命名与其他节点冲突
  - **化解**：使用 `asm_` 前缀避免冲突

**验收标准**：
```bash
# 编译测试
make check  # 确保编译器自身能编译通过
```

---

#### ✅ Task 1.3：Parser 实现基础语法解析

**文件**：`src/parser/primary.uya`  
**修改点**：第 3-200 行（`parser_parse_primary_expr` 函数）

**修改前**：
```uya
fn parser_parse_primary_expr(parser: &Parser) &ASTNode {
    if parser == null || parser.current_token == null {
        return null;
    }
    
    // 解析数字、字符串、标识符等
    // ...
}
```

**修改后**：
```uya
fn parser_parse_primary_expr(parser: &Parser) &ASTNode {
    if parser == null || parser.current_token == null {
        return null;
    }
    
    // === 新增：解析 @asm 块 ===
    if parser.current_token.type == TokenType.TOKEN_AT_IDENTIFIER {
        if str_equals(parser.current_token.value.string, "asm") != 0 {
            return parser_parse_asm_block(parser);
        }
    }
    
    // 解析数字、字符串、标识符等
    // ...
}

// === 新增函数：解析 @asm 块 ===
fn parser_parse_asm_block(parser: &Parser) &ASTNode {
    if parser == null {
        return null;
    }
    
    const line: i32 = parser.current_token.line;
    const column: i32 = parser.current_token.column;
    
    // 消费 @asm
    parser_consume(parser);
    
    // 期望 {
    if parser_expect(parser, TokenType.TOKEN_LEFT_BRACE) == null {
        fprintf(libc.stderr, "错误: @asm 块缺少 '{'\n" as *byte);
        return null;
    }
    
    // 创建 AST 节点
    const node: &ASTNode = ast_new_node(ASTNodeType.AST_ASM, line, column, parser.arena, parser_get_filename(parser));
    if node == null {
        return null;
    }
    
    // 解析指令列表
    var instruction_capacity: i32 = 8;
    var instructions: & & byte = arena_alloc(parser.arena, instruction_capacity * @size_of(&byte));
    var instruction_count: i32 = 0;
    
    var input_capacity: i32 = 16;
    var inputs: & & ASTNode = arena_alloc(parser.arena, input_capacity * @size_of(&ASTNode));
    var input_count: i32 = 0;
    
    var output_capacity: i32 = 8;
    var outputs: & & ASTNode = arena_alloc(parser.arena, output_capacity * @size_of(&ASTNode));
    var output_count: i32 = 0;
    
    // 循环解析指令
    while parser.current_token.type != TokenType.TOKEN_RIGHT_BRACE {
        // 解析指令字符串
        if parser.current_token.type != TokenType.TOKEN_STRING {
            fprintf(libc.stderr, "错误: 期望汇编指令字符串\n" as *byte);
            return null;
        }
        
        // 保存指令
        if instruction_count >= instruction_capacity {
            // 扩容（简化：直接返回错误）
            fprintf(libc.stderr, "错误: @asm 块指令过多\n" as *byte);
            return null;
        }
        instructions[instruction_count] = parser.current_token.value.string;
        instruction_count = instruction_count + 1;
        
        parser_consume(parser);
        
        // 解析参数列表 (inputs, outputs)
        if parser.current_token.type == TokenType.TOKEN_LEFT_PAREN {
            parser_consume(parser);
            
            // 解析输入表达式
            while parser.current_token.type != TokenType.TOKEN_ARROW && 
                  parser.current_token.type != TokenType.TOKEN_RIGHT_PAREN {
                // 解析表达式
                const expr: &ASTNode = parser_parse_expression(parser);
                if expr == null {
                    return null;
                }
                
                // 添加到输入数组
                if input_count >= input_capacity {
                    fprintf(libc.stderr, "错误: @asm 输入参数过多\n" as *byte);
                    return null;
                }
                inputs[input_count] = expr;
                input_count = input_count + 1;
                
                // 消费逗号
                if parser.current_token.type == TokenType.TOKEN_COMMA {
                    parser_consume(parser);
                }
            }
            
            // 解析输出表达式
            if parser.current_token.type == TokenType.TOKEN_ARROW {
                parser_consume(parser);  // 消费 ->
                
                while parser.current_token.type != TokenType.TOKEN_RIGHT_PAREN {
                    // 解析表达式
                    const expr: &ASTNode = parser_parse_expression(parser);
                    if expr == null {
                        return null;
                    }
                    
                    // 添加到输出数组
                    if output_count >= output_capacity {
                        fprintf(libc.stderr, "错误: @asm 输出参数过多\n" as *byte);
                        return null;
                    }
                    outputs[output_count] = expr;
                    output_count = output_count + 1;
                    
                    // 消费逗号
                    if parser.current_token.type == TokenType.TOKEN_COMMA {
                        parser_consume(parser);
                    }
                }
            }
            
            parser_expect(parser, TokenType.TOKEN_RIGHT_PAREN);
        }
        
        // 消费分号（可选）
        if parser.current_token.type == TokenType.TOKEN_SEMICOLON {
            parser_consume(parser);
        }
    }
    
    // 期望 }
    if parser_expect(parser, TokenType.TOKEN_RIGHT_BRACE) == null {
        fprintf(libc.stderr, "错误: @asm 块缺少 '}'\n" as *byte);
        return null;
    }
    
    // 设置节点字段
    node.asm_instructions = instructions;
    node.asm_instruction_count = instruction_count;
    node.asm_inputs = inputs;
    node.asm_input_count = input_count;
    node.asm_outputs = outputs;
    node.asm_output_count = output_count;
    node.asm_clobbers = null;  // 后续实现
    node.asm_clobber_count = 0;
    node.asm_clobbers_memory = 0;
    
    return node;
}
```

**风险识别**：
- ⚠️ **风险 1**：内存分配失败
  - **化解**：每次分配后检查 null
- ⚠️ **风险 2**：解析错误时内存泄漏
  - **化解**：使用 Arena 分配器，统一释放
- ⚠️ **风险 3**：数组扩容逻辑复杂
  - **化解**：初期使用固定容量，后续优化
- ⚠️ **风险 4**：嵌套表达式解析错误
  - **化解**：复用现有的 `parser_parse_expression` 函数

**验收标准**：
```bash
# 测试解析
cat > /tmp/test_asm.uya << 'EOF'
fn test() void {
    @asm {
        "nop" ();
    }
}
EOF
bin/uya --parse-only /tmp/test_asm.uya
# 应该成功解析，无错误
```

---

### Day 3-4：类型检查（预计 2 天）

#### ✅ Task 1.4：Checker 实现基础类型检查

**文件**：`src/checker/check_expr.uya`  
**修改点**：在 `check_expression` 函数中添加 @asm 处理

**修改前**：
```uya
fn check_expression(checker: &TypeChecker, node: &ASTNode) Type {
    if node == null {
        return make_void_type();
    }
    
    match node.type {
        ASTNodeType.AST_NUMBER => {
            // 检查数字
        },
        // ... 其他类型 ...
    }
}
```

**修改后**：
```uya
fn check_expression(checker: &TypeChecker, node: &ASTNode) Type {
    if node == null {
        return make_void_type();
    }
    
    match node.type {
        ASTNodeType.AST_NUMBER => {
            // 检查数字
        },
        // ... 其他类型 ...
        ASTNodeType.AST_ASM => {
            return check_asm_block(checker, node);
        },
    }
}

// === 新增函数：检查 @asm 块 ===
fn check_asm_block(checker: &TypeChecker, node: &ASTNode) Type {
    if node == null {
        return make_void_type();
    }
    
    // 检查所有输入表达式
    var i: i32 = 0;
    while i < node.asm_input_count {
        const input: &ASTNode = node.asm_inputs[i];
        const input_type: Type = check_expression(checker, input);
        
        // 验证输入类型（必须是整数、指针或寄存器类型）
        if !is_valid_asm_input_type(input_type) {
            fprintf(libc.stderr, "错误: @asm 输入参数类型无效\n" as *byte);
            checker.error_count = checker.error_count + 1;
        }
        
        i = i + 1;
    }
    
    // 检查所有输出表达式
    i = 0;
    while i < node.asm_output_count {
        const output: &ASTNode = node.asm_outputs[i];
        
        // 检查输出是否是左值（可赋值）
        if !is_lvalue(output) {
            fprintf(libc.stderr, "错误: @asm 输出参数必须是左值\n" as *byte);
            checker.error_count = checker.error_count + 1;
        }
        
        const output_type: Type = check_expression(checker, output);
        
        // 验证输出类型（必须是整数或寄存器类型）
        if !is_valid_asm_output_type(output_type) {
            fprintf(libc.stderr, "错误: @asm 输出参数类型无效\n" as *byte);
            checker.error_count = checker.error_count + 1;
        }
        
        i = i + 1;
    }
    
    // 返回 void（@asm 块不返回值）
    return make_void_type();
}

// === 辅助函数 ===
fn is_valid_asm_input_type(t: Type) i32 {
    // 整数类型
    if t.kind == TypeKind.TYPE_I32 || t.kind == TypeKind.TYPE_I64 {
        return 1;
    }
    if t.kind == TypeKind.TYPE_U32 || t.kind == TypeKind.TYPE_U64 {
        return 1;
    }
    // 指针类型
    if t.kind == TypeKind.TYPE_POINTER {
        return 1;
    }
    // 后续支持寄存器类型
    return 0;
}

fn is_valid_asm_output_type(t: Type) i32 {
    // 整数类型
    if t.kind == TypeKind.TYPE_I32 || t.kind == TypeKind.TYPE_I64 {
        return 1;
    }
    if t.kind == TypeKind.TYPE_U32 || t.kind == TypeKind.TYPE_U64 {
        return 1;
    }
    // 后续支持寄存器类型
    return 0;
}

fn is_lvalue(node: &ASTNode) i32 {
    // 标识符是左值
    if node.type == ASTNodeType.AST_IDENTIFIER {
        return 1;
    }
    // 数组访问是左值
    if node.type == ASTNodeType.AST_ARRAY_ACCESS {
        return 1;
    }
    // 成员访问是左值
    if node.type == ASTNodeType.AST_MEMBER_ACCESS {
        return 1;
    }
    return 0;
}
```

**风险识别**：
- ⚠️ **风险 1**：类型检查不严格，导致运行时错误
  - **化解**：严格检查所有输入输出类型
- ⚠️ **风险 2**：左值判断不准确
  - **化解**：参考现有代码中的左值判断逻辑
- ⚠️ **风险 3**：未检查指令字符串格式
  - **化解**：初期简化处理，后续增加指令格式验证

**验收标准**：
```bash
# 测试类型检查
cat > /tmp/test_asm_type.uya << 'EOF'
fn test() void {
    var x: i32 = 10;
    @asm {
        "add {x}, 5" (x, -> x);
    }
}
EOF
bin/uya --check-only /tmp/test_asm_type.uya
# 应该通过类型检查
```

---

### Day 5：基础代码生成（预计 1 天）

#### ✅ Task 1.5：Codegen 实现简单指令生成

**文件**：`src/codegen/c99/expr.uya`  
**修改点**：在 `gen_expression` 函数中添加 @asm 处理

**修改前**：
```uya
fn gen_expression(gen: &CodeGenC99, node: &ASTNode) void {
    if node == null {
        return;
    }
    
    match node.type {
        ASTNodeType.AST_NUMBER => {
            // 生成数字
        },
        // ... 其他类型 ...
    }
}
```

**修改后**：
```uya
fn gen_expression(gen: &CodeGenC99, node: &ASTNode) void {
    if node == null {
        return;
    }
    
    match node.type {
        ASTNodeType.AST_NUMBER => {
            // 生成数字
        },
        // ... 其他类型 ...
        ASTNodeType.AST_ASM => {
            gen_asm_block(gen, node);
        },
    }
}

// === 新增函数：生成 @asm 块 ===
fn gen_asm_block(gen: &CodeGenC99, node: &ASTNode) void {
    if node == null || gen == null {
        return;
    }
    
    // 生成临时变量声明
    var i: i32 = 0;
    while i < node.asm_input_count {
        const input: &ASTNode = node.asm_inputs[i];
        const input_type: Type = get_expression_type(input);
        
        // 生成临时变量
        fprintf(gen.output, "    register ");
        gen_type(gen, input_type);
        fprintf(gen.output, " _uya_asm_input_%d = ", i);
        gen_expression(gen, input);
        fprintf(gen.output, ";\n");
        
        i = i + 1;
    }
    
    // 生成输出临时变量
    i = 0;
    while i < node.asm_output_count {
        const output: &ASTNode = node.asm_outputs[i];
        const output_type: Type = get_expression_type(output);
        
        // 生成临时变量
        fprintf(gen.output, "    register ");
        gen_type(gen, output_type);
        fprintf(gen.output, " _uya_asm_output_%d;\n", i);
        
        i = i + 1;
    }
    
    // 生成内联汇编
    i = 0;
    while i < node.asm_instruction_count {
        const instruction: &byte = node.asm_instructions[i];
        
        // 生成单条汇编指令
        fprintf(gen.output, "    __asm__ volatile (\n");
        fprintf(gen.output, "        \"%s\"\n", instruction);
        
        // 输出操作数
        fprintf(gen.output, "        : ");
        var first: i32 = 1;
        var j: i32 = 0;
        while j < node.asm_output_count {
            if first == 0 {
                fprintf(gen.output, ", ");
            }
            fprintf(gen.output, "\"=r\" (_uya_asm_output_%d)", j);
            first = 0;
            j = j + 1;
        }
        fprintf(gen.output, "\n");
        
        // 输入操作数
        fprintf(gen.output, "        : ");
        first = 1;
        j = 0;
        while j < node.asm_input_count {
            if first == 0 {
                fprintf(gen.output, ", ");
            }
            fprintf(gen.output, "\"r\" (_uya_asm_input_%d)", j);
            first = 0;
            j = j + 1;
        }
        fprintf(gen.output, "\n");
        
        // Clobbers
        fprintf(gen.output, "        : \"memory\"\n");
        fprintf(gen.output, "    );\n");
        
        i = i + 1;
    }
    
    // 将结果复制到输出变量
    i = 0;
    while i < node.asm_output_count {
        const output: &ASTNode = node.asm_outputs[i];
        
        fprintf(gen.output, "    ");
        gen_expression(gen, output);  // 生成左值
        fprintf(gen.output, " = _uya_asm_output_%d;\n", i);
        
        i = i + 1;
    }
}
```

**风险识别**：
- ⚠️ **风险 1**：生成的 C 代码语法错误
  - **化解**：生成后立即编译测试
- ⚠️ **风险 2**：临时变量名冲突
  - **化解**：使用 `_uya_asm_` 前缀避免冲突
- ⚠️ **风险 3**：指令字符串未正确转义
  - **化解**：初期简化处理，后续增加转义逻辑
- ⚠️ **风险 4**：占位符替换逻辑缺失
  - **化解**：初期简化处理，后续实现占位符替换

**验收标准**：
```bash
# 测试代码生成
cat > /tmp/test_asm_gen.uya << 'EOF'
export fn main() i32 {
    var x: i32 = 10;
    @asm {
        "add %0, 5" (x, -> x);
    }
    return x;
}
EOF
bin/uya --c99 /tmp/test_asm_gen.uya -o /tmp/test_asm_gen.c
gcc /tmp/test_asm_gen.c -o /tmp/test_asm_gen
/tmp/test_asm_gen
echo $?  # 应该输出 15
```

---

### 阶段 1 交付物检查清单

- [ ] Lexer 能识别 `@asm` 关键字
- [ ] AST 包含完整的 @asm 节点结构
- [ ] Parser 能正确解析基础语法（指令字符串、输入输出列表）
- [ ] Checker 能进行基础类型检查（输入输出类型验证）
- [ ] Codegen 能生成 C99 内联汇编
- [ ] 基础测试用例通过（`test_asm_basic.uya`）
- [ ] 编译器自身能成功自举（`make check` 通过）

---

## 🚨 风险总结和化解方案

### 高风险（需要重点关注）

| 风险 | 影响 | 概率 | 化解方案 |
|------|------|------|----------|
| **自举失败** | 编译器无法编译自身 | 中 | 1. 每次修改后立即运行 `make check`<br>2. 使用增量修改策略<br>3. 保持 AST 向后兼容 |
| **内存分配失败** | 编译器崩溃 | 中 | 1. 每次分配后检查 null<br>2. 使用 Arena 分配器统一管理<br>3. 增加容量检查 |
| **类型检查遗漏** | 运行时错误 | 高 | 1. 严格检查所有输入输出类型<br>2. 参考现有类型检查逻辑<br>3. 增加测试用例 |

### 中风险（需要适当关注）

| 风险 | 影响 | 概率 | 化解方案 |
|------|------|------|----------|
| **代码生成错误** | 生成的 C 代码无法编译 | 中 | 1. 生成后立即编译测试<br>2. 使用 GCC/Clang 验证<br>3. 增加格式化输出 |
| **指令格式错误** | 汇编指令无法执行 | 中 | 1. 初期简化指令格式<br>2. 后续增加格式验证<br>3. 参考现有内联汇编示例 |
| **性能问题** | 编译速度下降 | 低 | 1. 使用高效的内存分配<br>2. 避免不必要的拷贝<br>3. 后续优化 |

### 低风险（可以接受）

| 风险 | 影响 | 概率 | 化解方案 |
|------|------|------|----------|
| **临时变量名冲突** | 编译错误 | 低 | 使用 `_uya_asm_` 前缀 |
| **左值判断错误** | 类型检查错误 | 低 | 参考现有逻辑 |

---

## 📝 实施原则

### 1. 增量修改原则
- ✅ **小步迭代**：每次只修改一个模块
- ✅ **立即验证**：修改后立即运行 `make check`
- ✅ **保持兼容**：不破坏现有功能

### 2. 测试驱动原则
- ✅ **先写测试**：每个功能点先写测试用例
- ✅ **测试先行**：测试失败后再写代码
- ✅ **持续测试**：每次提交都运行完整测试

### 3. 内存安全原则
- ✅ **检查 null**：每次分配后检查
- ✅ **Arena 管理**：统一内存管理
- ✅ **避免泄漏**：使用 defer 清理资源

### 4. 类型安全原则
- ✅ **严格检查**：所有类型转换都要检查
- ✅ **左值验证**：输出参数必须是左值
- ✅ **类型匹配**：输入输出类型必须匹配

---

## 🎯 验收标准

### 功能验收
- [ ] 能解析简单的 @asm 块（单条指令）
- [ ] 能解析复杂的 @asm 块（多条指令、输入输出）
- [ ] 类型检查能拒绝无效类型
- [ ] 生成的 C 代码能编译和运行
- [ ] 编译器自身能成功自举

### 质量验收
- [ ] 无内存泄漏
- [ ] 无编译警告
- [ ] 代码覆盖率 > 80%
- [ ] 性能无显著下降

### 文档验收
- [ ] 代码有详细注释
- [ ] 更新 API 文档
- [ ] 提供使用示例

---

## 📊 进度追踪

### 每日检查清单
- [ ] 更新本文档的任务状态
- [ ] 提交代码到版本控制
- [ ] 运行 `make check` 确保无回归
- [ ] 更新测试用例

### 里程碑
- **Day 2 结束**：Lexer 和 AST 完成
- **Day 4 结束**：Parser 和 Checker 完成
- **Day 5 结束**：Codegen 完成，基础功能可用

---

## 🔧 开发环境

### 编译命令
```bash
# 编译编译器
make uya

# 验证编译器
make check

# 运行测试
make tests

# 备份
make backup
```

### 调试命令
```bash
# 查看生成的 C 代码
bin/uya --c99 test.uya -o test.c
cat test.c

# 只解析不编译
bin/uya --parse-only test.uya

# 只类型检查
bin/uya --check-only test.uya
```

---

**最后更新**：2026-02-23  
**下次审查**：每完成一个主要任务后  
**维护者**：Uya 开发团队
