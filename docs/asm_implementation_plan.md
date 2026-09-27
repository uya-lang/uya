# @asm 内置函数实施计划

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**版本**：v1.0.0
**创建日期**：2026-02-22
**预计完成时间**：2026-03-15（3周）
**优先级**：P0（核心功能）

---

## 1. 实施阶段

### 阶段 1：基础架构（第1周，3-5天）

**目标**：建立 @asm 的基础语法和类型系统

**任务清单**：

#### Day 1-2：语法和 AST
- [ ] Lexer 支持 `@asm` 关键字
- [ ] AST 添加 `AST_ASM` 节点
- [ ] Parser 实现基础语法解析

#### Day 3-4：类型检查
- [ ] Checker 实现基础类型检查
- [ ] 寄存器类型系统
- [ ] 内存操作类型系统

#### Day 5：基础代码生成
- [ ] Codegen 实现简单指令生成
- [ ] 寄存器分配基础实现

**交付物**：
- 可以编译简单的 `@asm` 块
- 生成对应的 C99 内联汇编
- 基础测试用例通过

---

### 阶段 2：核心功能（第2周，5-7天）

**目标**：完善类型安全、内存安全和并发安全机制

**任务清单**：

#### Day 6-7：类型安全增强
- [ ] 完善输入/输出类型检查
- [ ] 寄存器约束验证
- [ ] 占位符类型推断

#### Day 8-9：内存安全验证
- [ ] 指针类型安全检查
- [ ] 内存操作类型验证
- [ ] 越界访问检测（编译期可证明时）

#### Day 10-11：并发安全验证
- [ ] 原子操作类型检查
- [ ] 数据竞争检测
- [ ] 内存屏障指令验证

#### Day 12：平台抽象
- [ ] 平台检测实现
- [ ] 条件编译支持
- [ ] 平台特定寄存器类型

**交付物**：
- 完整的类型安全验证
- 内存安全机制
- 并发安全机制
- 平台抽象基础

---

### 阶段 3：优化和测试（第3周，5-7天）

**目标**：性能优化、跨平台支持、完整测试

**任务清单**：

#### Day 13-14：代码生成优化
- [ ] 编译期常量折叠
- [ ] 指令融合
- [ ] 冗余消除
- [ ] 寄存器重用优化

#### Day 15-16：跨平台支持
- [ ] ARM64 平台支持
- [ ] RISC-V 平台支持（可选）
- [ ] 平台特定优化

#### Day 17-18：完整测试
- [ ] 单元测试完善
- [ ] 集成测试
- [ ] 性能基准测试
- [ ] 跨平台测试

#### Day 19：文档和示例
- [ ] API 文档完善
- [ ] 使用示例
- [ ] 最佳实践指南

**交付物**：
- 优化的代码生成
- 完整的测试套件
- 完善的文档
- 跨平台支持

---

## 2. 详细实现步骤

### 2.1 Lexer 实现（src/lexer.uya）

**文件位置**：`src/lexer.uya`

**修改点 1**：在内置函数列表中添加 `asm`（第 1069 行附近）

当前支持的内置函数列表：
```uya
// 支持：@size_of、@align_of、@len、@max、@min、@params、@va_start、@va_end、@va_arg、
//       @async_fn、@await、@mc_eval、@mc_type、@mc_ast、@mc_code、@mc_error、@mc_get_env、
//       @syscall、@ptr_from_usize、@usize_from_ptr、@print、@println
// 需要添加：@asm
```

**修改点 2**：添加字符串字面量转义序列支持

```uya
// 支持在指令字符串中使用 \n, \t, \\, \" 等转义
fn process_asm_string_escape(str: &byte) void {
    // 实现转义序列处理
}
```

**测试**：
```bash
make tests
```

---

### 2.2 AST 实现（src/ast.uya）

**文件位置**：`src/ast.uya`

**修改点 1**：在 `ASTNodeType` 枚举中添加 `AST_ASM`（第 112 行之后）

```uya
// 当前枚举（第 110-114 行）：
AST_SRC_COL,        // @src_col - 源文件列号
AST_FUNC_NAME,      // @func_name - 当前函数名
AST_SYSCALL,        // @syscall(nr, arg1, ..., arg6) - 系统调用
AST_PTR_FROM_USIZE, // @ptr_from_usize(value) - 从 usize 转换为指针
AST_USIZE_FROM_PTR, // @usize_from_ptr(ptr) - 从指针转换为 usize

// 新增：
AST_ASM,            // @asm { ... } - 内联汇编块
```

**修改点 2**：定义 `AsmStmt` 结构体

```uya
// 汇编语句结构体
struct AsmStmt {
    instruction: &byte,      // 指令字符串
    inputs: &&ASTNode,       // 输入表达式数组
    outputs: &&ASTNode,      // 输出表达式数组
    input_count: i32,        // 输入个数
    output_count: i32,       // 输出个数
}
```

**修改点 3**：在 `ASTNode` 结构体中添加字段

```uya
// 在 ASTNode 结构体末尾添加（第 375 行之后）：
// asm（@asm { ... } 内联汇编块）
asm_stmts: &AsmStmt,        // 语句数组
asm_stmt_count: i32,        // 语句个数
asm_clobbers: &&byte,       // clobber 寄存器名称数组
asm_clobber_count: i32,     // clobber 个数
asm_clobbers_memory: bool,  // 是否修改内存
```

**测试**：
```bash
make tests
```

---

### 2.3 Parser 实现（src/parser/primary.uya）

**文件位置**：`src/parser/primary.uya`

**修改点 1**：在 `parser_parse_primary_expr` 中识别 `@asm`

当前 `@syscall` 解析示例（第 745-783 行）：
```uya
// 解析 @syscall 表达式：@syscall(nr, arg1, ..., arg6)
if parser.current_token.type == TokenType.TOKEN_AT_IDENTIFIER && parser.current_token.value != null &&
    str_equals_lexer(parser.current_token.value, "syscall" as &byte) != 0 {
    // ... 解析逻辑
}
```

**修改点 2**：添加 `@asm` 解析函数

```uya
// 解析 @asm { ... } 内联汇编块
fn parser_parse_asm_block(parser: &Parser) &ASTNode {
    // 1. 消费 @asm
    // 2. 消费 {
    // 3. 解析语句列表
    //    - 解析指令字符串
    //    - 解析 (inputs, -> outputs)
    //    - 解析 clobbers = [...]
    // 4. 消费 }
    // 5. 创建 AST_ASM 节点
}
```

**解析语法**：
```uya
@asm {
    "instruction template" (input1, input2, ..., -> output1, output2, ...)
        clobbers = [reg1, reg2, ..., "memory"];
}
```

**测试**：
```bash
make tests
```

---

### 2.4 Checker 实现（src/checker/）

**文件位置**：`src/checker/check_expr.uya`

**修改点 1**：添加 `check_asm_block` 函数

参考 `infer_syscall` 函数（第 1089-1132 行）的模式：

```uya
// 检查 @asm 块的类型安全性
fn check_asm_block(checker: &TypeChecker, node: &ASTNode) void {
    // 1. 遍历所有语句
    // 2. 检查输入表达式类型
    // 3. 检查输出表达式类型（必须是左值）
    // 4. 检查 clobbers 声明
    // 5. 验证内存操作类型安全
}
```

**修改点 2**：在 `infer_expr` 函数中添加 `AST_ASM` 分支

当前函数在 `check_expr.uya` 中处理各种表达式类型。

**文件位置**：`src/checker/type_utils.uya`

**修改点 3**：添加类型验证辅助函数

```uya
// 检查是否是有效的 @asm 输入类型
fn is_valid_asm_input_type(type: Type) i32 {
    // 整数类型
    if is_integer_type(type.kind) != 0 { return 1; }
    // 指针类型
    if is_pointer_type(type.kind) != 0 { return 1; }
    // 寄存器类型（待实现）
    // if is_register_type(type.kind) != 0 { return 1; }
    return 0;
}

// 检查是否是有效的 @asm 输出类型
fn is_valid_asm_output_type(type: Type) i32 {
    // 整数类型
    if is_integer_type(type.kind) != 0 { return 1; }
    return 0;
}
```

**测试**：
```bash
make tests
```

---

### 2.5 Codegen 实现（src/codegen/c99/）

#### 2.5.1 expr.uya

**文件位置**：`src/codegen/c99/expr.uya`

**修改点 1**：添加 `gen_asm_block` 函数

参考 `gen_syscall` 函数（第 285-320 行）的模式：

```uya
// 生成 @asm 块的 C99 内联汇编代码
fn gen_asm_block(codegen: &CodeGenC99, node: &ASTNode) void {
    // 1. 生成临时变量声明（输入/输出）
    // 2. 生成 __asm__ volatile (...) 语句
    // 3. 将结果复制到输出变量
}
```

**修改点 2**：生成内联汇编语句

```uya
fn gen_asm_stmt(codegen: &CodeGenC99, stmt: &AsmStmt, stmt_index: i32) void {
    // 生成格式：
    // __asm__ volatile (
    //     "instruction"
    //     : "=r" (output1), "=r" (output2)
    //     : "r" (input1), "r" (input2)
    //     : "rcx", "r11", "memory"
    // );
}
```

**修改点 3**：在 `gen_expr` 函数中添加 `AST_ASM` 分支

当前函数处理各种表达式类型（第 284-286 行有 `AST_SYSCALL` 示例）。

**测试**：
```bash
make tests
```

#### 2.5.2 utils.uya

**文件位置**：`src/codegen/c99/utils.uya`

**修改点 1**：添加临时变量名生成函数

```uya
// 生成 @asm 临时变量名
fn gen_asm_temp_var(prefix: &byte, stmt_index: i32, var_index: i32) void {
    // 生成名称如：_uya_asm_input_0_0
}
```

**修改点 2**：添加寄存器约束映射函数

```uya
// 获取寄存器的 C99 约束字符串
fn get_register_constraint(reg_name: &byte) &byte {
    // x86-64: rax→"a", rbx→"b", rcx→"c", rdx→"d", rsi→"S", rdi→"D"
    // ARM64: x0-x30→"r"
    // 通用: "r"
}
```

---

## 3. 测试用例实现

### 3.1 基础功能测试

**文件位置**：`tests/test_asm_basic.uya`

```uya
test "asm basic addition" {
    fn add_asm(a: i32, b: i32) i32 {
        var result: i32;

        @asm {
            "add {a}, {b}" (a, b, -> result);
        }

        return result;
    }

    const x: i32 = 10;
    const y: i32 = 20;
    const z: i32 = add_asm(x, y);

    if z != 30 {
        return error.TestFailed;
    }

    return true;
}

test "asm multiplication" {
    fn mul_asm(a: i32, b: i32) i32 {
        var result: i32;

        @asm {
            "imul {a}, {b}" (a, b, -> result);
        }

        return result;
    }

    const x: i32 = 5;
    const y: i32 = 6;
    const z: i32 = mul_asm(x, y);

    if z != 30 {
        return error.TestFailed;
    }

    return true;
}
```

### 3.2 系统调用测试

**文件位置**：`tests/test_asm_syscall.uya`

```uya
test "asm syscall write" {
    const SYS_write: i64 = 1;
    const msg = "Hello from @asm!\n";

    var result: i64;  // 显式声明输出变量

    @asm {
        "mov rax, {nr}" (SYS_write, -> rax);
        "mov rdi, 1" (-> rdi);
        "mov rsi, {msg}" (msg, -> rsi);
        "mov rdx, 17" (-> rdx);
        "syscall" (rax, rdi, rsi, rdx, -> result);
    } clobbers = ["rcx", "r11", "memory"];

    if result != 17 {
        return error.TestFailed;
    }

    return true;
}

test "asm syscall exit" {
    const SYS_exit: i64 = 60;

    @asm {
        "mov rax, {nr}" (SYS_exit, -> rax);
        "mov rdi, 42" (-> rdi);
        "syscall" (rax, rdi, -> _);
    } clobbers = ["rcx", "r11"];

    return true;
}
```

### 3.3 类型安全测试

**文件位置**：`tests/error_asm_type_mismatch.uya`

```uya
// 这个测试应该编译失败

fn add_wrong_types(a: i32, b: f64) i32 {
    var result: i32;

    @asm {
        "add {a}, {b}" (a, b, -> result);  // 类型不匹配，应该编译失败
    }

    return result;
}
```

### 3.4 内存安全测试

**文件位置**：`tests/test_asm_memory_safe.uya`

```uya
test "asm memory read" {
    fn read_u32(ptr: &u32) u32 {
        var value: u32;

        @asm {
            "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
        }

        return value;
    }

    const data: u32 = 0xDEADBEEF;
    const result: u32 = read_u32(&data);

    if result != 0xDEADBEEF {
        return error.TestFailed;
    }

    return true;
}

test "asm memory write" {
    fn write_u32(ptr: &u32, value: u32) void {
        @asm {
            "mov [{ptr}], {value}" (value, @asm_mem(ptr), -> _);
        }
    }

    var data: u32 = 0;
    write_u32(&data, 0xCAFEBABE);

    if data != 0xCAFEBABE {
        return error.TestFailed;
    }

    return true;
}
```

### 3.5 并发安全测试

**文件位置**：`tests/test_asm_atomic_ops.uya`

```uya
test "asm atomic fetch_add" {
    fn atomic_fetch_add(ptr: &atomic i32, value: i32) i32 {
        var old: i32;

        @asm {
            "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
        }

        return old;
    }

    var counter: atomic i32 = 0;
    const old: i32 = atomic_fetch_add(&counter, 5);

    if old != 0 {
        return error.TestFailed;
    }

    if counter != 5 {
        return error.TestFailed;
    }

    return true;
}

test "asm atomic compare_exchange" {
    fn atomic_compare_exchange(ptr: &atomic i32, expected: i32, desired: i32) bool {
        var prev: i32;

        @asm {
            "lock cmpxchg [{ptr}], {desired}" (
                @asm_mem(ptr), desired, -> prev
            );
        }

        return prev == expected;
    }

    var value: atomic i32 = 10;
    const success: bool = atomic_compare_exchange(&value, 10, 20);

    if !success {
        return error.TestFailed;
    }

    if value != 20 {
        return error.TestFailed;
    }

    return true;
}
```

### 3.6 平台检测测试

**文件位置**：`tests/test_asm_platform.uya`

```uya
test "asm platform detection" {
    const target: @asm_target = @asm_target();

    if @asm_target() == .x86_64_linux {
        return true;
    } else if @asm_target() == .arm64_linux {
        return true;
    }

    return error.TestFailed;
}

test "asm platform specific code" {
    var result: i32;

    if @asm_target() == .x86_64_linux {
        @asm {
            "mov {result}, 42" (-> result);
        }
    } else if @asm_target() == .arm64_linux {
        @asm {
            "mov {result}, #42" (-> result);
        }
    } else {
        return error.UnsupportedPlatform;
    }

    if result != 42 {
        return error.TestFailed;
    }

    return true;
}
```

---

## 4. 集成和测试流程

### 4.1 编译和测试

```bash
# 构建编译器
make uya

# 运行基础测试
make tests

# 运行特定测试
bin/uya tests/test_asm_basic.uya

# 查看生成的 C 代码
cat tests/build/test_asm_basic.c
```

### 4.2 调试

```bash
# 启用详细输出
bin/uya --verbose tests/test_asm_basic.uya

# 查看生成的 C 代码
cat tests/build/test_asm_basic.c

# 使用 GDB 调试
gcc tests/build/test_asm_basic.c -o test_asm_basic -g
gdb ./test_asm_basic
```

---

## 5. 验收标准

### 5.1 功能完整性

- [ ] 所有基础功能测试通过
- [ ] 所有类型安全测试通过
- [ ] 所有内存安全测试通过
- [ ] 所有并发安全测试通过
- [ ] 所有平台检测测试通过

### 5.2 性能指标

- [ ] @asm 生成的代码与 C99 内联汇编性能一致（误差 < 1%）
- [ ] 编译时间增加 < 5%
- [ ] 生成的代码大小增加 < 2%

### 5.3 代码质量

- [ ] 代码覆盖率 > 90%
- [ ] 无内存泄漏
- [ ] 无编译警告
- [ ] 符合代码规范

---

## 6. 风险和应对

### 6.1 技术风险

**风险 1**：寄存器分配复杂度高

**应对**：
- 初期使用 GCC/Clang 的自动分配（`"r"` 约束）
- 后期优化显式寄存器指定

**风险 2**：跨平台支持困难

**应对**：
- 先实现 x86-64 Linux 平台
- 后续逐步支持其他平台
- 使用条件编译隔离平台特定代码

**风险 3**：性能不如预期

**应对**：
- 提前进行性能基准测试
- 根据测试结果优化代码生成
- 确保零成本抽象

### 6.2 进度风险

**风险 1**：实现时间超出预期

**应对**：
- 按优先级分阶段实施
- 核心功能优先
- 非关键功能可以延后

**风险 2**：测试用例不足

**应对**：
- 边开发边测试
- 增加测试覆盖率
- 使用模糊测试工具

---

## 7. 后续优化方向

### 7.1 性能优化

- 指令级优化
- 寄存器重用
- 常量传播
- 死代码消除

### 7.2 功能扩展

- SIMD 抽象
- 标签跳转
- 内联函数
- 宏支持

### 7.3 工具支持

- 语法高亮
- 自动补全
- 错误提示优化
- 调试信息

---

## 8. 总结

本实施计划详细描述了 @asm 内置函数的实现步骤，包括：

1. **阶段划分**：3周3个阶段，逐步实现
2. **详细步骤**：每个文件的修改点和代码示例
3. **测试用例**：完整的测试套件
4. **验收标准**：明确的功能、性能、质量标准
5. **风险应对**：识别风险并提供应对方案

**预期成果**：

- 完整的 @asm 内置函数实现
- 类型安全、内存安全、并发安全
- 跨平台支持
- 零成本抽象
- 完善的测试和文档

---

**文档版本**：v1.0.0
**最后更新**：2026-02-22
**下次审查**：每周五
