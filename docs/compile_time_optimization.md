# Uya 编译期优化设计文档

**版本**：v0.7.3  
**更新日期**：2026-02-23

> **实现状态（2026-10-19 核对，v0.10.4）**：本文设计的 Pass 1–5 已在
> `src/checker/optimizer.uya` 落地，实现状态见 [`compile_time_optimization_status.md`](compile_time_optimization_status.md)。
> 两点口径差异务必注意：
>
> 1. **Pass 4（内联）与 Pass 5（循环展开）目前只做 AST 标记**（`is_inlined` / `inlined_body` /
>    `is_unrolled` / `unroll_count` + `optimizer_stats`），`src/codegen/c99/` 尚未消费这些字段；
>    真正生效的是 Pass 1（常量折叠）、Pass 2（死代码消除）、Pass 3（证明优化）。
> 2. **`--opt=N` 不等于宿主 C 编译器的 `-O`**。C99 后端生成的 C 由宿主 `CFLAGS` 编译，
>    其默认值自 v0.10.4 起为 `-std=c99 -O2 -fno-builtin`（提交 `6c90874c`），指令级内联/展开由宿主编译器完成。

## 概述

本文档定义 Uya 编译器的编译期优化功能，遵循"程序员提供证明，编译器验证证明"的设计哲学。

## 设计原则

### 1. 安全优先
- 所有优化必须保持内存安全证明的有效性
- 优化不能引入新的未定义行为
- 优化后的代码必须通过所有安全检查

### 2. 编译期证明
- 利用现有的内存安全证明机制
- 在证明条件为真时消除运行时检查
- 在证明条件为假时消除死代码

### 3. 零运行时开销
- 所有优化在编译期完成
- 不引入额外的运行时数据结构
- 优化后的代码更简洁高效

## 优化类别

### 1. 常量折叠（Constant Folding）

**触发条件**：
- 所有操作数都是编译期常量
- 表达式类型为整数、布尔或枚举

**示例**：
```uya
const a: i32 = 10 + 20;        // 优化为: const a: i32 = 30;
const b: i32 = a * 2;          // 优化为: const b: i32 = 60;
const c: bool = true && false; // 优化为: const c: bool = false;
```

**实现**：
- 在类型检查阶段识别常量表达式
- 使用 `checker_eval_const_expr` 进行求值
- 替换 AST 节点为常量值

### 2. 死代码消除（Dead Code Elimination）

**触发条件**：
- if 条件在编译期可确定为真或假
- match 表达式可确定匹配分支
- 永远不会执行的代码块

**示例**：
```uya
// 条件恒为真
if true {
    do_something();  // 保留
} else {
    do_other();      // 移除
}

// 条件恒为假
const debug: bool = false;
if debug {
    log_debug();     // 移除
}
```

**实现**：
- 在类型检查阶段识别常量条件
- 标记死代码分支
- 在代码生成阶段跳过死代码

### 3. 证明优化（Proof Optimization）

**触发条件**：
- 边界检查条件在编译期可证明为真
- 空指针检查条件在编译期可证明为真
- 其他安全检查条件可证明

**示例**：
```uya
const arr: [i32: 10] = [0: 10];
const i: i32 = 5;

// 编译器可以证明 i >= 0 && i < 10
if i >= 0 && i < 10 {  // 条件恒为真
    const x: i32 = arr[i];  // 优化：移除 if，直接访问
}
```

**实现**：
- 扩展现有的 `checker_can_prove_safety` 函数
- 在证明条件为真时标记优化机会
- 在代码生成阶段生成优化后的代码

### 4. 内联优化（Inline Optimization）

**触发条件**：
- 函数调用是简单的常量表达式
- 函数体很小（< 10 条语句）
- 函数标记为 `inline`（未来特性）

**示例**：
```uya
fn square(x: i32) i32 {
    return x * x;
}

const a: i32 = square(5);  // 优化为: const a: i32 = 25;
```

**实现**：
- 在类型检查阶段识别简单函数
- 内联函数调用
- 继续进行常量折叠

### 5. 循环展开（Loop Unrolling）

**触发条件**：
- 循环次数是编译期常量
- 循环体很小（< 5 条语句）
- 循环次数较小（< 10 次）

**示例**：
```uya
// 编译期循环
for 0..3 |i| {
    printf("%d\n", i);
}

// 优化为：
printf("%d\n", 0);
printf("%d\n", 1);
printf("%d\n", 2);
```

**实现**：
- 在类型检查阶段识别常量循环
- 展开循环体
- 继续进行其他优化

## 实现架构

### 优化阶段

```
┌─────────────────────────────────────────────────────────┐
│                    编译器优化流程                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. 词法分析 → AST                                      │
│     ↓                                                   │
│  2. 类型检查 + 证明                                     │
│     ↓                                                   │
│  3. 【新增】优化阶段                                    │
│     ├─ 常量折叠                                         │
│     ├─ 死代码消除                                       │
│     ├─ 证明优化                                         │
│     ├─ 内联优化                                         │
│     └─ 循环展开                                         │
│     ↓                                                   │
│  4. 代码生成（C99）                                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 优化器模块

```uya
// src/checker/optimizer.uya

// 优化配置
struct OptimizationConfig {
    enable_constant_folding: i32,    // 启用常量折叠
    enable_dead_code_elimination: i32, // 启用死代码消除
    enable_proof_optimization: i32,  // 启用证明优化
    enable_inline: i32,              // 启用内联优化
    enable_loop_unrolling: i32,      // 启用循环展开
    optimization_level: i32          // 优化级别 (0-3)
}

// 优化器
struct Optimizer {
    config: OptimizationConfig,
    checker: &TypeChecker,
    optimization_count: i32  // 优化次数统计
}
```

### 优化 Pass

每个优化实现为一个独立的 Pass：

```uya
// 优化 Pass
fn optimize_pass(optimizer: &Optimizer, node: &ASTNode) &ASTNode {
    var result: &ASTNode = node;
    
    // Pass 1: 常量折叠
    if optimizer.config.enable_constant_folding != 0 {
        result = constant_folding_pass(optimizer, result);
    }
    
    // Pass 2: 死代码消除
    if optimizer.config.enable_dead_code_elimination != 0 {
        result = dead_code_elimination_pass(optimizer, result);
    }
    
    // Pass 3: 证明优化
    if optimizer.config.enable_proof_optimization != 0 {
        result = proof_optimization_pass(optimizer, result);
    }
    
    // Pass 4: 内联优化
    if optimizer.config.enable_inline != 0 {
        result = inline_pass(optimizer, result);
    }
    
    // Pass 5: 循环展开
    if optimizer.config.enable_loop_unrolling != 0 {
        result = loop_unrolling_pass(optimizer, result);
    }
    
    return result;
}
```

## 命令行选项

添加优化相关的命令行选项：

```bash
# 不优化（默认，开发模式）
uya build --opt=0

# 基础优化（常量折叠、死代码消除）
uya build --opt=1

# 标准优化（+ 证明优化）
uya build --opt=2

# 激进优化（+ 内联、循环展开）
uya build --opt=3

# 单独控制
uya build --no-constant-folding
uya build --no-dead-code-elimination
uya build --no-proof-optimization
```

## 实现步骤

### 阶段 1：基础设施（v0.7.3）
1. 创建 `src/checker/optimizer.uya` 模块
2. 实现优化配置结构
3. 添加命令行选项解析
4. 创建优化 Pass 框架

### 阶段 2：常量折叠（v0.7.3）
1. 实现常量表达式识别
2. 扩展 `checker_eval_const_expr`
3. 实现 AST 节点替换
4. 添加测试用例

### 阶段 3：死代码消除（v0.7.4）
1. 实现常量条件识别
2. 标记死代码分支
3. 修改代码生成跳过死代码
4. 添加测试用例

### 阶段 4：证明优化（v0.7.4）
1. 扩展证明系统
2. 实现证明条件优化
3. 生成优化后的代码
4. 添加测试用例

### 阶段 5：高级优化（v0.7.5）
1. 实现函数内联
2. 实现循环展开
3. 性能测试
4. 文档更新

## 测试策略

### 单元测试

每个优化 Pass 都有对应的测试用例：

```uya
// tests/programs/test_constant_folding.uya
test "constant_folding_basic" {
    const a: i32 = 10 + 20;
    try assert_eq_i32(a, 30, "10 + 20 should be folded to 30");
}

test "constant_folding_nested" {
    const a: i32 = 10;
    const b: i32 = a * 2 + 5;
    try assert_eq_i32(b, 25, "nested constant should be folded");
}
```

### 集成测试

验证优化后的代码正确性：

```uya
// tests/programs/test_optimization_integration.uya
test "optimization_preserves_semantics" {
    const arr: [i32: 5] = [1, 2, 3, 4, 5];
    const i: i32 = 2;
    
    // 优化后应该直接访问 arr[2]，移除 if 检查
    if i >= 0 && i < 5 {
        const value: i32 = arr[i];
        try assert_eq_i32(value, 3, "optimized access should be correct");
    }
}
```

### 性能测试

对比优化前后的性能：

```bash
# 运行性能测试
make tests-performance

# 输出性能报告
uya build --opt=3 --bench
```

## 安全保证

### 优化不变性

1. **语义等价**：优化前后代码行为一致
2. **内存安全**：优化不破坏内存安全证明
3. **类型安全**：优化保持类型正确性
4. **证明有效**：优化不影响证明系统

### 验证机制

```uya
// 优化后的代码必须通过验证
fn verify_optimization(original: &ASTNode, optimized: &ASTNode) i32 {
    // 1. 类型检查
    if !type_check(optimized) {
        return 0;  // 优化失败
    }
    
    // 2. 内存安全证明
    if !prove_memory_safety(optimized) {
        return 0;  // 优化失败
    }
    
    // 3. 语义等价验证（可选）
    if !verify_semantic_equivalence(original, optimized) {
        return 0;  // 优化失败
    }
    
    return 1;  // 优化成功
}
```

## 调试支持

### 优化日志

```bash
# 启用优化日志
uya build --opt=2 --verbose

# 输出：
# [optimize] constant folding: 10 + 20 -> 30
# [optimize] dead code eliminated: if (false) { ... }
# [optimize] proof optimized: bounds check removed for arr[i]
```

### 优化报告

```bash
# 生成优化报告
uya build --opt=3 --report

# 输出：
# Optimization Report:
# - Constant folding: 23 expressions
# - Dead code eliminated: 5 branches
# - Proof optimized: 12 bounds checks
# - Inlined functions: 3 calls
# - Loops unrolled: 2 loops
# - Total optimizations: 45
```

## 限制与约束

### 当前限制

1. **跨函数优化**：仅在函数内优化，不支持跨函数分析
2. **指针别名分析**：不支持复杂的指针别名分析
3. **动态内存**：不优化堆内存分配
4. **递归函数**：不支持递归函数优化

### 安全约束

1. **证明限制**：仅在当前函数内进行证明
2. **不变量维护**：优化不能破坏编译期不变量
3. **错误报告**：优化失败时保持原有错误信息

## 未来计划

### v0.7.6
- 跨函数内联优化
- 更强大的循环优化
- 指针别名分析

### v0.8.0
- 链接时优化（LTO）
- Profile-guided 优化（PGO）
- 自动向量化

## 参考资料

- [Uya 语言规范](./uya.md)
- [内存安全证明机制](./uya.md#内存安全规则)
- [开发流程](./DEVELOPMENT.md)
- [测试指南](./testing_guide.md)
