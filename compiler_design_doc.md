# Uya编程语言编译器完整设计文档

## 1. 概述

### 1.1 项目简介
Uya（优雅）是一个系统编程语言，专注于内存安全、并发安全和零运行时开销。设计目标是提供Rust级别的安全性，同时保持C级别的性能和简洁性。

### 1.2 设计哲学
- **安全优先**：将运行时的"可能越界"转化为编译期的"要么证明安全，要么返回显式错误"
- **零运行时开销**：通过路径零指令，失败路径不存在
- **显式控制**：程序员必须提供边界证明，编译器验证证明
- **数学确定性**：每个数组访问都有明确的数学证明

### 1.3 核心特性
- 原子类型：`atomic T` 关键字，自动原子指令，零运行时锁
- 内存安全强制：所有UB必须被编译期证明为安全，失败即编译错误
- 并发安全强制：零数据竞争，通过路径零指令
- 字符串插值：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- 安全指针算术：支持 `ptr +/- offset`，必须通过编译期证明安全
- 模块系统：目录级模块、显式导出、路径导入

## 2. 编译器架构

### 2.1 整体架构
```
源代码(.uya) -> 词法分析器 -> 语法分析器 -> 类型检查器 -> IR生成器 -> 代码生成器 -> 目标代码(.c)
```

### 2.2 模块划分
- **Lexer（词法分析器）**：将源代码转换为Token流
- **Parser（语法分析器）**：将Token流转换为AST
- **TypeChecker（类型检查器）**：验证类型安全
- **IRGenerator（IR生成器）**：将AST转换为中间表示
- **CodeGenerator（代码生成器）**：将IR转换为目标代码
- **Main（主程序）**：协调各模块工作

## 3. 词法分析器（Lexer）

### 3.1 Token类型定义
```c
typedef enum {
    // 基本字面量
    TOKEN_EOF,
    TOKEN_IDENTIFIER,
    TOKEN_NUMBER,
    TOKEN_STRING,
    TOKEN_CHAR,
    
    // 关键字
    TOKEN_STRUCT, TOKEN_LET, TOKEN_MUT, TOKEN_CONST, TOKEN_FN, TOKEN_RETURN,
    TOKEN_EXTERN, TOKEN_TRUE, TOKEN_FALSE, TOKEN_IF, TOKEN_WHILE, TOKEN_BREAK,
    TOKEN_CONTINUE, TOKEN_DEFER, TOKEN_ERRDEFER, TOKEN_TRY, TOKEN_CATCH,
    TOKEN_ERROR, TOKEN_NULL, TOKEN_INTERFACE, TOKEN_IMPL, TOKEN_ATOMIC,
    TOKEN_MAX, TOKEN_MIN, TOKEN_AS, TOKEN_AS_EXCLAMATION, TOKEN_TYPE, TOKEN_MC,
    TOKEN_EXPORT, TOKEN_USE,  // 模块相关
    
    // 运算符
    TOKEN_PLUS, TOKEN_MINUS, TOKEN_ASTERISK, TOKEN_SLASH, TOKEN_PERCENT,
    TOKEN_ASSIGN, TOKEN_EQUAL, TOKEN_NOT_EQUAL, TOKEN_LESS, TOKEN_LESS_EQUAL,
    TOKEN_GREATER, TOKEN_GREATER_EQUAL, TOKEN_LEFT_PAREN, TOKEN_RIGHT_PAREN,
    TOKEN_LEFT_BRACE, TOKEN_RIGHT_BRACE, TOKEN_LEFT_BRACKET, TOKEN_RIGHT_BRACKET,
    TOKEN_SEMICOLON, TOKEN_COMMA, TOKEN_DOT, TOKEN_COLON, TOKEN_EXCLAMATION,
    TOKEN_AMPERSAND, TOKEN_PIPE, TOKEN_CARET, TOKEN_TILDE, TOKEN_LEFT_SHIFT,
    TOKEN_RIGHT_SHIFT, TOKEN_LOGICAL_AND, TOKEN_LOGICAL_OR,
    
    // 特殊符号
    TOKEN_ARROW,        // ->
    TOKEN_ELLIPSIS,     // ...
    TOKEN_RANGE,        // .. 
    TOKEN_SLICE,        // [start:end] 切片操作符
} TokenType;
```

### 3.2 词法分析器功能
- 读取源文件内容到内存缓冲区
- 逐字符解析，生成Token流
- 处理关键字、标识符、字面量、运算符
- 处理注释（单行//和多行/* */）
- 跟踪行列号信息

### 3.3 实现细节
- 使用状态机解析各种Token类型
- 支持Unicode字符（UTF-8编码）
- 错误恢复机制：跳过非法字符序列
- 缓冲区管理：动态扩展

## 4. 语法分析器（Parser）

### 4.1 AST节点类型
```c
typedef enum {
    // 程序结构
    AST_PROGRAM,
    AST_STRUCT_DECL,
    AST_FN_DECL,
    AST_EXTERN_DECL,
    AST_VAR_DECL,
    
    // 语句
    AST_IF_STMT,
    AST_WHILE_STMT,
    AST_RETURN_STMT,
    AST_EXPR_STMT,
    AST_BLOCK,
    AST_BREAK_STMT,
    AST_CONTINUE_STMT,
    AST_DEFER_STMT,
    AST_ERRDEFER_STMT,
    
    // 表达式
    AST_BINARY_EXPR,
    AST_UNARY_EXPR,
    AST_CALL_EXPR,
    AST_MEMBER_ACCESS,
    AST_SUBSCRIPT_EXPR,
    AST_SLICE_EXPR,      // 切片表达式
    AST_IDENTIFIER,
    AST_NUMBER,
    AST_STRING,
    AST_BOOL,
    AST_NULL,
    
    // 类型
    AST_TYPE_NAMED,
    AST_TYPE_POINTER,
    AST_TYPE_ARRAY,
    AST_TYPE_FN,
    AST_TYPE_ERROR_UNION,
    
    // 模块
    AST_EXPORT_DECL,
    AST_IMPORT_DECL,
} ASTNodeType;
```

### 4.2 语法分析器功能
- 使用递归下降解析构建AST
- 支持所有Uya语法结构
- 错误恢复：跳过到下一个同步点
- 生成类型化的AST节点

### 4.3 切片语法解析
- 解析函数调用形式：`slice(arr, start, len)`
- 解析操作符形式：`arr[start:len]`
- 负数索引处理：`-n` 转换为 `len(arr) - n`
- 边界检查：验证 `start >= -len && start < len && len >= 0 && start + len <= len`

## 5. 类型检查器（TypeChecker）

### 5.1 类型检查功能
- 验证变量声明和使用
- 检查函数调用参数类型匹配
- 验证表达式类型安全
- 检查数组访问边界（编译期证明）

### 5.2 内存安全检查
- 数组越界访问检查
- 空指针解引用检查
- 未初始化内存使用检查
- 整数溢出检查
- 除零错误检查

### 5.3 实现策略
- 路径敏感分析：跟踪所有代码路径
- 符号执行：验证数学关系
- 约束求解：验证边界条件

## 6. 中间表示（IR）

### 6.1 IR指令类型
```c
typedef enum {
    IR_FUNC_DECL,        // 函数声明
    IR_FUNC_DEF,         // 函数定义
    IR_VAR_DECL,         // 变量声明
    IR_ASSIGN,           // 赋值
    IR_BINARY_OP,        // 二元运算
    IR_UNARY_OP,         // 一元运算
    IR_CALL,             // 函数调用
    IR_RETURN,           // 返回
    IR_IF,               // if语句
    IR_WHILE,            // while循环
    IR_BLOCK,            // 代码块
    IR_LOAD,             // 加载
    IR_STORE,            // 存储
    IR_SLICE,            // 切片操作
    IR_CAST,             // 类型转换
    IR_ERROR_UNION,      // 错误联合类型
    IR_TRY_CATCH,        // try/catch
} IRInstType;
```

### 6.2 切片IR表示
```c
// 切片操作的IR表示
struct {
    char *dest;           // 目标切片变量
    IRInst *source;       // 源数组
    IRInst *start;        // 起始索引
    IRInst *length;       // 切片长度
} slice_op;
```

### 6.3 IR优化
- 常量折叠
- 死代码消除
- 内存访问优化
- 边界检查消除（当编译期可证明时）

## 7. 代码生成器（CodeGenerator）

### 7.1 C99代码生成
- 将IR转换为C99兼容代码
- 保持Uya的安全性保证
- 生成高效的内存访问代码

### 7.2 切片代码生成
- 生成边界检查代码
- 生成内存拷贝操作
- 优化常量边界检查

### 7.3 类型映射
| Uya类型 | C99类型 |
|---------|---------|
| `i8` `i16` `i32` `i64` | `int8_t` `int16_t` `int32_t` `int64_t` |
| `u8` `u16` `u32` `u64` | `uint8_t` `uint16_t` `uint32_t` `uint64_t` |
| `f32` `f64` | `float` `double` |
| `bool` | `uint8_t` |
| `byte` | `uint8_t` |
| `byte*` | `char*` |
| `&T` | `T*` |
| `[T; N]` | `T[N]` |

## 8. 切片语法实现详解

### 8.1 语法形式
Uya语言支持两种切片语法：

1. **函数调用形式**：
   ```uya
   let slice: [T; M] = slice(arr, start, len);
   ```
   - `arr`：源数组
   - `start`：起始索引（支持负数）
   - `len`：切片长度（必须为正数）

2. **操作符形式**：
   ```uya
   let slice: [T; M] = arr[start:len];
   ```
   - `start`：起始索引（支持负数）
   - `len`：切片长度（必须为正数）

### 8.2 负数索引处理
- `arr[-1]` 表示最后一个元素
- `arr[-n]` 表示倒数第n个元素
- 负数索引转换：`-k` 转换为 `len(arr) - k`
- 例如：对于长度为10的数组，`arr[-3:3]` 等价于 `arr[7:3]`

### 8.3 边界检查
编译期或运行时必须证明：
- `start >= -len(arr) && start < len(arr)`
- `len >= 0 && start + len <= len(arr)`
- 无法证明安全 → 编译错误

### 8.4 类型系统
- `slice(arr: [T; N], start: i32, len: i32) [T; M]`，其中 `M = len`
- 返回类型与源数组元素类型相同
- 切片长度在编译期确定

## 9. 安全保证机制

### 9.1 编译期证明
- 常量索引越界 → 编译错误
- 变量索引 → 必须证明边界条件
- 无法证明安全 → 编译错误，不生成代码

### 9.2 运行时安全
- 通过路径零指令，安全路径直接访问
- 失败路径不存在，不降级、不插运行时锁
- 零运行时开销，性能等同手写C代码

### 9.3 内存安全
- 所有数组访问经过边界验证
- 空指针解引用防护
- 未初始化内存使用防护
- 整数溢出防护

## 10. 性能特性

### 10.1 编译期优化
- 常量边界检查在编译期完成
- 生成高效的内存拷贝代码
- 无运行时边界检查（当编译期可证明时）

### 10.2 运行时性能
- 零GC：栈式数组，无垃圾回收
- 零运行时开销：通过路径零指令
- 高效内存访问：直接内存操作

## 11. 模块系统集成

### 11.1 模块导出
```uya
export fn slice(arr: [T; N], start: i32, len: i32) [T; M];
```

### 11.2 模块导入
```uya
use std.array.slice;
```

## 12. 错误处理集成

### 12.1 切片错误类型
- `error.SliceOutOfBounds` - 切片边界超出范围
- `error.NegativeLength` - 切片长度为负数

### 12.2 错误处理示例
```uya
fn safe_slice(arr: [i32; 10], start: i32, len: i32) ![i32; 5] {
    if start < 0 {
        start = len(arr) + start;  // 转换负数索引
    }
    if start < 0 || start >= len(arr) || len < 0 || start + len > len(arr) {
        return error.SliceOutOfBounds;
    }
    return slice(arr, start, len);
}
```

## 13. 与现有特性的集成

### 13.1 与类型系统的集成
- 切片操作保持类型安全
- 返回类型根据切片长度推断

### 13.2 与内存安全的集成
- 所有切片操作经过内存安全验证
- 与RAII和drop机制兼容

### 13.3 与错误处理的集成
- 切片操作可返回错误联合类型
- 与try/catch机制兼容

## 14. 实现状态

### 14.1 已实现功能
- ✅ 基本切片语法 `slice(arr, start, len)`
- ✅ 操作符语法 `arr[start:len]`
- ✅ 负数索引支持
- ✅ 边界检查机制
- ✅ 与类型系统集成
- ✅ 与错误处理系统集成

### 14.2 待实现功能
- ⏳ 步长支持 `arr[start:end:step]`
- ⏳ 多维数组切片
- ⏳ 切片修改操作

## 15. 测试策略

### 15.1 单元测试
- 词法分析器测试
- 语法分析器测试
- 类型检查器测试
- IR生成器测试
- 代码生成器测试

### 15.2 集成测试
- 完整编译流程测试
- 切片功能测试
- 边界情况测试
- 性能基准测试

## 16. 总结

Uya语言的切片语法成功地将Python风格的便捷切片功能与Uya的安全性哲学相结合。通过编译期证明和边界检查，确保了内存安全，同时保持了零运行时开销的性能特性。该设计既提供了高级语言的便利性，又保持了系统编程语言的安全性和性能。

> **Uya切片 = Python风格语法 + Rust级内存安全 + C级性能**；
> **零运行时开销，编译期边界证明，失败即编译错误**；
> **通过路径零指令，安全路径直接访问内存**。