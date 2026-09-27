# @asm 实施风险识别与化解方案

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**创建日期**：2026-02-23  
**目的**：详细识别每个实施步骤的风险，并提供具体的化解方案

---

## 🎯 风险评估方法论

### 风险等级定义
- **🔴 高风险**：可能导致编译器崩溃或自举失败，需要重点关注
- **🟡 中风险**：可能导致功能缺陷或性能问题，需要适当关注
- **🟢 低风险**：影响较小，可以接受或后续优化

### 风险化解策略
1. **预防**：提前识别风险点，设计时避免
2. **缓解**：降低风险发生概率或影响
3. **应急**：风险发生后的应对措施
4. **监控**：持续监控风险指标

---

## 📋 第一阶段：基础架构风险

### 1.1 Lexer 修改风险

#### 🔴 风险 1.1.1：TOKEN_AT_IDENTIFIER 识别冲突

**描述**：`@asm` 与其他 `@` 开头的内置函数冲突

**风险场景**：
```uya
@size_of(i32)  // 现有内置函数
@asm { "nop" (); }  // 新增 @asm
```

**影响**：Parser 可能误识别 @asm 为其他内置函数

**化解方案**：
```uya
// ✅ 正确方案：在 Parser 中明确检查
fn parser_parse_primary_expr(parser: &Parser) &ASTNode {
    if parser.current_token.type == TokenType.TOKEN_AT_IDENTIFIER {
        const name: &byte = parser.current_token.value.string;
        
        // 明确检查每个内置函数
        if str_equals(name, "size_of") != 0 {
            return parser_parse_size_of(parser);
        }
        if str_equals(name, "align_of") != 0 {
            return parser_parse_align_of(parser);
        }
        // === 新增：明确检查 @asm ===
        if str_equals(name, "asm") != 0 {
            return parser_parse_asm_block(parser);
        }
        // 其他内置函数...
    }
}
```

**验证方法**：
```bash
# 测试所有内置函数
cat > /tmp/test_builtins.uya << 'EOF'
const x: i32 = @size_of(i32);
const y: i32 = @align_of(i32);
@asm { "nop" (); }
EOF
bin/uya --parse-only /tmp/test_builtins.uya
```

**监控指标**：
- 所有内置函数测试通过率 = 100%
- 无识别冲突错误

---

### 1.2 AST 节点扩展风险

#### 🔴 风险 1.2.1：ASTNode 结构体字段过多

**描述**：ASTNode 结构体不断增加字段，可能影响内存布局和性能

**当前状态**：
```uya
struct ASTNode {
    type: ASTNodeType,
    // 数十个字段...
    // 预计新增 8 个字段用于 @asm
}
```

**影响**：
- 每个 ASTNode 占用内存增加
- 可能影响缓存命中率
- 编译器性能下降

**化解方案 1：使用扁平化设计（推荐）**

```uya
struct ASTNode {
    type: ASTNodeType,
    // === 通用字段（所有节点共享）===
    line: i32,
    column: i32,
    
    // === 特定字段（扁平化，无 union）===
    // 数字节点
    number_value: i32,
    // 字符串节点
    string_value: &byte,
    // ... 其他字段 ...
    
    // === @asm 字段（新增）===
    asm_instructions: & & byte,
    asm_instruction_count: i32,
    asm_inputs: & & ASTNode,
    asm_input_count: i32,
    asm_outputs: & & ASTNode,
    asm_output_count: i32,
    asm_clobbers: & & byte,
    asm_clobber_count: i32,
    asm_clobbers_memory: i32,
}
```

**优点**：
- ✅ 无需 union 支持（Uya 无 union）
- ✅ 访问简单直接
- ✅ 与现有设计一致

**缺点**：
- ⚠️ 每个 ASTNode 占用内存增加约 32 字节（8 个字段 × 平均 4 字节）

**化解方案 2：使用间接引用（优化）**

```uya
// 定义专用结构体
struct ASMData {
    instructions: & & byte,
    instruction_count: i32,
    inputs: & & ASTNode,
    input_count: i32,
    outputs: & & ASTNode,
    output_count: i32,
    clobbers: & & byte,
    clobber_count: i32,
    clobbers_memory: i32,
}

struct ASTNode {
    type: ASTNodeType,
    // ... 其他字段 ...
    
    // 使用指针引用（节省内存）
    asm_data: &ASMData,  // 仅 @asm 节点使用
}
```

**优点**：
- ✅ 节省内存（仅 @asm 节点分配）
- ✅ 结构清晰

**缺点**：
- ⚠️ 增加一次间接访问
- ⚠️ 需要额外的内存分配

**决策**：初期使用方案 1（扁平化），后续优化时考虑方案 2

**验证方法**：
```bash
# 测试内存占用
bin/uya --profile-memory tests/test_ast_size.uya

# 测试性能
time bin/uya --c99 tests/test_perf.uya
```

**监控指标**：
- ASTNode 平均大小 < 200 字节
- 编译时间增加 < 5%

---

#### 🟡 风险 1.2.2：字段命名冲突

**描述**：新增字段名与现有字段名冲突

**风险场景**：
```uya
struct ASTNode {
    // 现有字段
    instructions: &byte,  // 可能已存在
    
    // 新增字段（冲突）
    asm_instructions: & & byte,  // 使用前缀避免冲突
}
```

**化解方案**：
```uya
// ✅ 使用 asm_ 前缀统一命名
struct ASTNode {
    // ... 其他字段 ...
    
    // @asm 相关字段（统一前缀）
    asm_instructions: & & byte,
    asm_instruction_count: i32,
    asm_inputs: & & ASTNode,
    asm_input_count: i32,
    asm_outputs: & & ASTNode,
    asm_output_count: i32,
    asm_clobbers: & & byte,
    asm_clobber_count: i32,
    asm_clobbers_memory: i32,
}
```

**验证方法**：
```bash
# 检查字段名冲突
grep -n "^    asm_" src/ast.uya
# 确保所有字段都以 asm_ 开头
```

---

### 1.3 Parser 解析风险

#### 🔴 风险 1.3.1：内存分配失败

**描述**：解析复杂 @asm 块时，内存分配可能失败

**风险场景**：
```uya
@asm {
    "instruction1" (input1, input2, -> output1);
    "instruction2" (input3, input4, -> output2);
    // ... 大量指令 ...
}
```

**影响**：编译器崩溃

**化解方案**：
```uya
fn parser_parse_asm_block(parser: &Parser) &ASTNode {
    // === 方案 1：检查每次分配 ===
    var instructions: & & byte = arena_alloc(parser.arena, capacity * @size_of(&byte));
    if instructions == null {
        fprintf(libc.stderr, "错误: 内存分配失败\n" as *byte);
        return null;
    }
    
    // === 方案 2：限制容量 ===
    const MAX_ASM_INSTRUCTIONS: i32 = 64;  // 最大指令数
    if instruction_count >= MAX_ASM_INSTRUCTIONS {
        fprintf(libc.stderr, "错误: @asm 块指令数超过限制 (%d)\n", MAX_ASM_INSTRUCTIONS as *byte);
        return null;
    }
    
    // === 方案 3：渐进式扩容 ===
    if instruction_count >= instruction_capacity {
        // 扩容策略：2 倍扩容
        const new_capacity: i32 = instruction_capacity * 2;
        const new_instructions: & & byte = arena_alloc(parser.arena, new_capacity * @size_of(&byte));
        if new_instructions == null {
            fprintf(libc.stderr, "错误: 内存扩容失败\n" as *byte);
            return null;
        }
        
        // 复制旧数据
        var i: i32 = 0;
        while i < instruction_count {
            new_instructions[i] = instructions[i];
            i = i + 1;
        }
        
        instructions = new_instructions;
        instruction_capacity = new_capacity;
    }
}
```

**决策**：初期使用方案 2（限制容量），后续优化时实现方案 3

**验证方法**：
```bash
# 测试大量指令
cat > /tmp/test_asm_large.uya << 'EOF'
@asm {
    "nop" ();
    "nop" ();
    # ... 100 条指令 ...
}
EOF
bin/uya --parse-only /tmp/test_asm_large.uya
```

**监控指标**：
- 内存分配失败次数 = 0
- 解析成功率 = 100%

---

#### 🔴 风险 1.3.2：嵌套表达式解析错误

**描述**：@asm 参数中的复杂表达式解析错误

**风险场景**：
```uya
@asm {
    "add {a}, {b}" (x + y * z, foo().bar, -> result);
}
```

**影响**：解析错误导致编译失败

**化解方案**：
```uya
fn parser_parse_asm_block(parser: &Parser) &ASTNode {
    // === 使用现有的表达式解析器 ===
    while parser.current_token.type != TokenType.TOKEN_ARROW && 
          parser.current_token.type != TokenType.TOKEN_RIGHT_PAREN {
        // 复用现有的表达式解析函数
        const expr: &ASTNode = parser_parse_expression(parser);
        if expr == null {
            fprintf(libc.stderr, "错误: 解析 @asm 输入表达式失败\n" as *byte);
            return null;
        }
        
        // 添加到输入数组
        inputs[input_count] = expr;
        input_count = input_count + 1;
        
        // 消费逗号
        if parser.current_token.type == TokenType.TOKEN_COMMA {
            parser_consume(parser);
        }
    }
}
```

**关键点**：
- ✅ 复用 `parser_parse_expression` 函数
- ✅ 支持任意复杂度的表达式
- ✅ 错误处理与现有逻辑一致

**验证方法**：
```bash
# 测试复杂表达式
cat > /tmp/test_asm_complex.uya << 'EOF'
fn foo() i32 { return 42; }
fn bar() void {
    var x: i32 = 10;
    var y: i32 = 20;
    var z: i32 = 0;
    @asm {
        "add {x}, {y}" (x + y * foo(), -> z);
    }
}
EOF
bin/uya --parse-only /tmp/test_asm_complex.uya
```

---

#### 🟡 风险 1.3.3：错误恢复不完整

**描述**：解析错误后，编译器状态不一致

**风险场景**：
```uya
@asm {
    "add {a}, {b}" (x, y  // 缺少 )
    "sub {c}, {d}" (z, -> w);
}
```

**影响**：后续解析可能产生级联错误

**化解方案**：
```uya
fn parser_parse_asm_block(parser: &Parser) &ASTNode {
    // === 方案 1：同步到下一个有效标记 ===
    if parser.current_token.type != TokenType.TOKEN_RIGHT_PAREN {
        fprintf(libc.stderr, "错误: 期望 ')' 但发现 '%s'\n", parser.current_token.value.string as *byte);
        
        // 跳过到下一个有效标记
        while parser.current_token.type != TokenType.TOKEN_RIGHT_BRACE &&
              parser.current_token.type != TokenType.TOKEN_EOF {
            parser_consume(parser);
        }
        
        return null;  // 返回错误
    }
    
    // === 方案 2：使用错误节点继续解析 ===
    const error_node: &ASTNode = ast_new_node(ASTNodeType.AST_ERROR, line, column, parser.arena, parser_get_filename(parser));
    error_node.error_message = "解析 @asm 块失败";
    return error_node;
}
```

**决策**：使用方案 1（同步到下一个有效标记）

**验证方法**：
```bash
# 测试错误恢复
cat > /tmp/test_asm_error.uya << 'EOF'
@asm {
    "add" (x, y  // 错误：缺少 )
}
@asm {
    "nop" ();  // 应该能继续解析
}
EOF
bin/uya --parse-only /tmp/test_asm_error.uya
# 应该报告第一个错误，然后继续解析第二个 @asm 块
```

---

### 1.4 Checker 类型检查风险

#### 🔴 风险 1.4.1：类型检查遗漏导致运行时错误

**描述**：未检查的类型导致运行时崩溃

**风险场景**：
```uya
fn bad() void {
    var x: f32 = 3.14;
    @asm {
        "add {x}, 5" (x, -> x);  // 错误：浮点数不能用于整数指令
    }
}
```

**影响**：生成的汇编代码执行错误

**化解方案**：
```uya
fn check_asm_block(checker: &TypeChecker, node: &ASTNode) Type {
    // === 严格类型检查 ===
    var i: i32 = 0;
    while i < node.asm_input_count {
        const input: &ASTNode = node.asm_inputs[i];
        const input_type: Type = check_expression(checker, input);
        
        // 验证输入类型
        if !is_valid_asm_input_type(input_type) {
            fprintf(libc.stderr, "错误: @asm 输入参数类型 '%s' 无效\n", type_to_string(input_type) as *byte);
            fprintf(libc.stderr, "  位置: 第 %d 行, 第 %d 列\n", input.line as *byte, input.column as *byte);
            fprintf(libc.stderr, "  允许的类型: i32, i64, u32, u64, 指针\n" as *byte);
            checker.error_count = checker.error_count + 1;
        }
        
        i = i + 1;
    }
}

// === 严格的类型验证函数 ===
fn is_valid_asm_input_type(t: Type) i32 {
    // 仅允许整数类型
    if t.kind == TypeKind.TYPE_I8 || t.kind == TypeKind.TYPE_I16 {
        return 1;
    }
    if t.kind == TypeKind.TYPE_I32 || t.kind == TypeKind.TYPE_I64 {
        return 1;
    }
    if t.kind == TypeKind.TYPE_U8 || t.kind == TypeKind.TYPE_U16 {
        return 1;
    }
    if t.kind == TypeKind.TYPE_U32 || t.kind == TypeKind.TYPE_U64 {
        return 1;
    }
    if t.kind == TypeKind.TYPE_USIZE {
        return 1;
    }
    
    // 允许指针类型
    if t.kind == TypeKind.TYPE_POINTER {
        return 1;
    }
    
    // 拒绝浮点数
    if t.kind == TypeKind.TYPE_F32 || t.kind == TypeKind.TYPE_F64 {
        return 0;  // 明确拒绝
    }
    
    // 拒绝其他类型
    return 0;
}
```

**验证方法**：
```bash
# 测试类型检查
cat > /tmp/test_asm_typecheck.uya << 'EOF'
fn test_valid() void {
    var x: i32 = 10;
    @asm { "add {x}, 5" (x, -> x); }  // ✅ 应该通过
}

fn test_invalid() void {
    var x: f32 = 3.14;
    @asm { "add {x}, 5" (x, -> x); }  // ❌ 应该失败
}
EOF
bin/uya --check-only /tmp/test_asm_typecheck.uya
# 应该报告 test_invalid 中的类型错误
```

**监控指标**：
- 类型检查覆盖率 = 100%
- 无效类型拦截率 = 100%

---

#### 🟡 风险 1.4.2：左值判断不准确

**描述**：左值判断错误导致输出参数无法赋值

**风险场景**：
```uya
fn bad() void {
    @asm {
        "mov {x}, 42" (-> x + 1);  // 错误：x + 1 不是左值
    }
}
```

**影响**：生成的 C 代码编译错误

**化解方案**：
```uya
fn check_asm_block(checker: &TypeChecker, node: &ASTNode) Type {
    // === 检查输出参数 ===
    var i: i32 = 0;
    while i < node.asm_output_count {
        const output: &ASTNode = node.asm_outputs[i];
        
        // 检查输出是否是左值
        if !is_lvalue(output) {
            fprintf(libc.stderr, "错误: @asm 输出参数必须是左值（可赋值）\n" as *byte);
            fprintf(libc.stderr, "  位置: 第 %d 行, 第 %d 列\n", output.line as *byte, output.column as *byte);
            fprintf(libc.stderr, "  示例: 变量名 x、数组访问 arr[i]、字段访问 obj.field\n" as *byte);
            checker.error_count = checker.error_count + 1;
        }
        
        i = i + 1;
    }
}

// === 左值判断函数 ===
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
    
    // 解引用是左值
    if node.type == ASTNodeType.AST_UNARY_EXPR {
        // 检查是否是解引用操作 *
        // (需要访问 node.op 字段)
        return 0;  // 简化处理
    }
    
    // 其他情况不是左值
    return 0;
}
```

**验证方法**：
```bash
# 测试左值检查
cat > /tmp/test_asm_lvalue.uya << 'EOF'
fn test_valid() void {
    var x: i32 = 0;
    @asm { "mov {x}, 42" (-> x); }  // ✅ x 是左值
}

fn test_invalid() void {
    var x: i32 = 0;
    @asm { "mov {x}, 42" (-> x + 1); }  // ❌ x + 1 不是左值
}
EOF
bin/uya --check-only /tmp/test_asm_lvalue.uya
```

---

### 1.5 Codegen 代码生成风险

#### 🔴 风险 1.5.1：生成的 C 代码语法错误

**描述**：生成的内联汇编语法错误

**风险场景**：
```c
// 错误的生成代码
__asm__ volatile (
    "add %0, 5"
    : "=r" (_uya_asm_output_0)
    : "r" (_uya_asm_input_0)
    : "memory"
);  // 缺少必要的分隔符或格式错误
```

**影响**：GCC/Clang 编译失败

**化解方案**：
```uya
fn gen_asm_block(gen: &CodeGenC99, node: &ASTNode) void {
    // === 使用模板化的代码生成 ===
    
    // 1. 生成临时变量声明（格式化）
    fprintf(gen.output, "    // === @asm 块开始 ===\n");
    
    var i: i32 = 0;
    while i < node.asm_input_count {
        const input: &ASTNode = node.asm_inputs[i];
        const input_type: Type = get_expression_type(input);
        
        fprintf(gen.output, "    register ");
        gen_type(gen, input_type);
        fprintf(gen.output, " _uya_asm_input_%d = ", i);
        gen_expression(gen, input);
        fprintf(gen.output, ";  // 输入 %d\n", i);
        
        i = i + 1;
    }
    
    // 2. 生成内联汇编（严格格式化）
    i = 0;
    while i < node.asm_instruction_count {
        const instruction: &byte = node.asm_instructions[i];
        
        fprintf(gen.output, "    __asm__ volatile (\n");
        fprintf(gen.output, "        \"%s\"\n", instruction);
        
        // 输出操作数（格式化）
        fprintf(gen.output, "        : ");
        if node.asm_output_count > 0 {
            var j: i32 = 0;
            while j < node.asm_output_count {
                if j > 0 {
                    fprintf(gen.output, ", ");
                }
                fprintf(gen.output, "\"=r\" (_uya_asm_output_%d)", j);
                j = j + 1;
            }
        }
        fprintf(gen.output, "\n");
        
        // 输入操作数（格式化）
        fprintf(gen.output, "        : ");
        if node.asm_input_count > 0 {
            var j: i32 = 0;
            while j < node.asm_input_count {
                if j > 0 {
                    fprintf(gen.output, ", ");
                }
                fprintf(gen.output, "\"r\" (_uya_asm_input_%d)", j);
                j = j + 1;
            }
        }
        fprintf(gen.output, "\n");
        
        // Clobbers（格式化）
        fprintf(gen.output, "        : \"memory\"\n");
        fprintf(gen.output, "    );\n");
        
        i = i + 1;
    }
    
    fprintf(gen.output, "    // === @asm 块结束 ===\n\n");
}
```

**验证方法**：
```bash
# 生成并编译
cat > /tmp/test_asm_gen.uya << 'EOF'
export fn main() i32 {
    var x: i32 = 10;
    @asm { "add %0, 5" (x, -> x); }
    return x;
}
EOF
bin/uya --c99 /tmp/test_asm_gen.uya -o /tmp/test_asm_gen.c
gcc -Wall -Werror /tmp/test_asm_gen.c -o /tmp/test_asm_gen  # 使用严格模式编译
```

**监控指标**：
- 生成的 C 代码编译成功率 = 100%
- GCC/Clang 警告数 = 0

---

#### 🔴 风险 1.5.2：临时变量名冲突

**描述**：临时变量名与其他变量冲突

**风险场景**：
```c
// 生成的代码
int _uya_asm_input_0 = x;  // 可能与用户定义的变量冲突
register int _uya_asm_output_0;
```

**化解方案**：
```uya
fn gen_asm_block(gen: &CodeGenC99, node: &ASTNode) void {
    // === 使用唯一前缀 ===
    // _uya_asm_ 前缀：
    // - _uya: Uya 编译器保留前缀
    // - asm: @asm 相关
    // - input/output: 用途标识
    
    fprintf(gen.output, "    register ");
    gen_type(gen, input_type);
    fprintf(gen.output, " _uya_asm_input_%d = ", i);  // 使用唯一前缀
    gen_expression(gen, input);
    fprintf(gen.output, ";\n");
}
```

**关键点**：
- ✅ 使用 `_uya_asm_` 前缀
- ✅ 与用户命名空间隔离
- ✅ GCC/Clang 接受下划线开头的标识符

**验证方法**：
```bash
# 测试变量名冲突
cat > /tmp/test_asm_conflict.uya << 'EOF'
export fn main() i32 {
    var _uya_asm_input_0: i32 = 100;  // 用户变量
    var x: i32 = 10;
    @asm { "add %0, 5" (x, -> x); }
    return x + _uya_asm_input_0;
}
EOF
bin/uya --c99 /tmp/test_asm_conflict.uya -o /tmp/test_asm_conflict.c
gcc /tmp/test_asm_conflict.c -o /tmp/test_asm_conflict
/tmp/test_asm_conflict
echo $?  # 应该输出 115
```

---

#### 🟡 风险 1.5.3：指令字符串未转义

**描述**：指令字符串中的特殊字符未正确转义

**风险场景**：
```uya
@asm {
    "mov %eax, \"hello\"" ();  // 包含引号
    "add %0, %1\n" (x, y, -> z);  // 包含换行
}
```

**影响**：生成的 C 代码语法错误

**化解方案（初期简化）**：
```uya
fn gen_asm_block(gen: &CodeGenC99, node: &ASTNode) void {
    // === 初期：直接输出字符串 ===
    // 后续：增加转义处理
    
    fprintf(gen.output, "        \"%s\"\n", instruction);
    
    // === 后续优化：转义处理 ===
    // var escaped: [i8: 256] = escape_asm_string(instruction);
    // fprintf(gen.output, "        \"%s\"\n", &escaped[0]);
}

// === 后续实现：字符串转义 ===
fn escape_asm_string(str: &byte) [i8: 256] {
    var result: [i8: 256] = [];
    var i: i32 = 0;
    var j: i32 = 0;
    
    while str[i] != 0 && j < 255 {
        if str[i] == '"' as i32 {
            result[j] = '\\' as i32;
            j = j + 1;
            result[j] = '"' as i32;
        } else if str[i] == '\\' as i32 {
            result[j] = '\\' as i32;
            j = j + 1;
            result[j] = '\\' as i32;
        } else if str[i] == '\n' as i32 {
            result[j] = '\\' as i32;
            j = j + 1;
            result[j] = 'n' as i32;
        } else {
            result[j] = str[i];
        }
        
        i = i + 1;
        j = j + 1;
    }
    
    result[j] = 0;
    return result;
}
```

**决策**：初期不处理转义，要求用户在字符串中正确转义

**验证方法**：
```bash
# 测试简单指令
cat > /tmp/test_asm_simple.uya << 'EOF'
export fn main() i32 {
    var x: i32 = 10;
    @asm { "add %0, 5" (x, -> x); }
    return x;
}
EOF
bin/uya --c99 /tmp/test_asm_simple.uya -o /tmp/test_asm_simple.c
cat /tmp/test_asm_simple.c
# 检查生成的字符串是否正确
```

---

## 📊 风险总结

### 风险优先级排序

| 优先级 | 风险 | 影响 | 化解成本 | 行动 |
|--------|------|------|----------|------|
| P0 | 自举失败 | 🔴 高 | 中 | 立即实施 |
| P0 | 内存分配失败 | 🔴 高 | 低 | 立即实施 |
| P0 | 类型检查遗漏 | 🔴 高 | 中 | 立即实施 |
| P1 | 代码生成错误 | 🟡 中 | 中 | 尽快实施 |
| P1 | ASTNode 字段过多 | 🟡 中 | 低 | 后续优化 |
| P2 | 临时变量名冲突 | 🟢 低 | 低 | 测试验证 |
| P2 | 左值判断错误 | 🟢 低 | 低 | 测试验证 |

### 风险化解检查清单

- [ ] **每次修改后**：运行 `make check` 确保自举通过
- [ ] **每次分配后**：检查 null 返回值
- [ ] **每次类型检查**：验证所有类型规则
- [ ] **每次代码生成**：立即编译测试
- [ ] **每个功能点**：编写完整测试用例

---

**最后更新**：2026-02-23  
**下次审查**：每周五  
**维护者**：Uya 开发团队
