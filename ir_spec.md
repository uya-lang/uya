# Uya语言中间表示（IR）规范文档

## 1. 概述

### 1.1 设计目标
Uya语言的中间表示（IR）旨在提供一个C语言友好的中间层，便于代码生成和优化。IR设计遵循以下原则：

- **C语言友好**：IR指令可以直接映射到C语言构造
- **零运行时开销**：所有安全检查在编译期完成
- **类型安全**：保持Uya语言的类型安全特性
- **内存安全**：确保所有内存访问都经过验证

### 1.2 IR架构
```
源代码(.uya) -> 词法分析 -> 语法分析 -> AST -> IR生成器 -> IR -> 代码生成器 -> C代码(.c)
```

## 2. IR指令类型

### 2.1 指令类型枚举

```c
typedef enum {
    IR_FUNC_DECL,        // 函数声明
    IR_FUNC_DEF,         // 函数定义
    IR_EXTERN_DECL,      // 外部函数声明
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
    IR_ERROR_UNION,      // 错误联合类型操作
    IR_TRY_CATCH,        // try/catch
} IRInstType;
```

### 2.2 指令操作符枚举

```c
typedef enum {
    IR_OP_ADD,           // 加法 (+)
    IR_OP_SUB,           // 减法 (-)
    IR_OP_MUL,           // 乘法 (*)
    IR_OP_DIV,           // 除法 (/)
    IR_OP_MOD,           // 取模 (%)
    IR_OP_BIT_AND,       // 按位与 (&)
    IR_OP_BIT_OR,        // 按位或 (|)
    IR_OP_BIT_XOR,       // 按位异或 (^)
    IR_OP_BIT_NOT,       // 按位取反 (~)
    IR_OP_LEFT_SHIFT,    // 左移 (<<)
    IR_OP_RIGHT_SHIFT,   // 右移 (>>)
    IR_OP_LOGIC_AND,     // 逻辑与 (&&)
    IR_OP_LOGIC_OR,      // 逻辑或 (||)
    IR_OP_NEG,           // 负号 (-)
    IR_OP_NOT,           // 逻辑非 (!)
    IR_OP_EQ,            // 相等 (==)
    IR_OP_NE,            // 不等 (!=)
    IR_OP_LT,            // 小于 (<)
    IR_OP_LE,            // 小于等于 (<=)
    IR_OP_GT,            // 大于 (>)
    IR_OP_GE,            // 大于等于 (>=)
} IROp;
```

### 2.3 数据类型枚举

```c
typedef enum {
    IR_TYPE_I8,          // 8位有符号整数
    IR_TYPE_I16,         // 16位有符号整数
    IR_TYPE_I32,         // 32位有符号整数
    IR_TYPE_I64,         // 64位有符号整数
    IR_TYPE_U8,          // 8位无符号整数
    IR_TYPE_U16,         // 16位无符号整数
    IR_TYPE_U32,         // 32位无符号整数
    IR_TYPE_U64,         // 64位无符号整数
    IR_TYPE_F32,         // 32位浮点数
    IR_TYPE_F64,         // 64位浮点数
    IR_TYPE_BOOL,        // 布尔类型
    IR_TYPE_BYTE,        // 字节类型
    IR_TYPE_VOID,        // 空类型
    IR_TYPE_PTR,         // 指针类型
    IR_TYPE_ARRAY,       // 数组类型
    IR_TYPE_STRUCT,      // 结构体类型
    IR_TYPE_FN,          // 函数类型
    IR_TYPE_ERROR_UNION, // 错误联合类型 !T
} IRType;
```

## 3. IR指令结构

### 3.1 基础IR指令结构

```c
typedef struct IRInst {
    IRInstType type;      // 指令类型
    int id;               // 指令ID，用于SSA形式
    int line;             // 源代码行号
    int column;           // 源代码列号
    char *filename;       // 源文件名

    union {
        // 函数声明/定义
        struct {
            char *name;                    // 函数名
            struct IRInst **params;        // 参数列表
            int param_count;               // 参数数量
            IRType return_type;            // 返回类型
            struct IRInst **body;          // 函数体指令列表
            int body_count;                // 函数体指令数量
            int is_extern;                 // 是否为外部函数
        } func;

        // 变量声明
        struct {
            char *name;                    // 变量名
            IRType type;                   // 变量类型
            struct IRInst *init;           // 初始化表达式
            int is_mut;                    // 是否可变
        } var;

        // 赋值
        struct {
            char *dest;                    // 目标变量
            struct IRInst *src;            // 源表达式
        } assign;

        // 二元运算
        struct {
            char *dest;                    // 目标变量
            IROp op;                       // 运算符
            struct IRInst *left;           // 左操作数
            struct IRInst *right;          // 右操作数
        } binary_op;

        // 一元运算
        struct {
            char *dest;                    // 目标变量
            IROp op;                       // 运算符
            struct IRInst *operand;        // 操作数
        } unary_op;

        // 函数调用
        struct {
            char *dest;                    // 返回值目标（可能为NULL）
            char *func_name;               // 函数名
            struct IRInst **args;          // 参数列表
            int arg_count;                 // 参数数量
        } call;

        // 返回
        struct {
            struct IRInst *value;          // 返回值（NULL表示void返回）
        } ret;

        // if语句
        struct {
            struct IRInst *condition;      // 条件表达式
            struct IRInst **then_body;     // then分支体
            int then_count;                // then分支指令数量
            struct IRInst **else_body;     // else分支体
            int else_count;                // else分支指令数量
        } if_stmt;

        // while循环
        struct {
            struct IRInst *condition;      // 循环条件
            struct IRInst **body;          // 循环体
            int body_count;                // 循环体指令数量
        } while_stmt;

        // 代码块
        struct {
            struct IRInst **insts;         // 指令列表
            int inst_count;                // 指令数量
        } block;

        // 加载/存储
        struct {
            char *dest;                    // 目标变量
            char *src;                     // 源地址
        } load, store;

        // 类型转换
        struct {
            char *dest;                    // 目标变量
            struct IRInst *src;            // 源表达式
            IRType from_type;              // 源类型
            IRType to_type;                // 目标类型
        } cast;

        // 错误联合类型
        struct {
            char *dest;                    // 目标变量
            struct IRInst *value;          // 值或错误
            int is_error;                  // 0=正常值，1=错误值
        } error_union;

        // try/catch
        struct {
            struct IRInst *try_body;       // try块
            char *error_var;               // 错误变量名
            struct IRInst *catch_body;     // catch块
        } try_catch;

        // 切片操作
        struct {
            char *dest;                    // 目标切片变量
            struct IRInst *source;         // 源数组
            struct IRInst *start;          // 起始索引
            struct IRInst *length;         // 切片长度
        } slice_op;
    } data;
} IRInst;
```

### 3.2 IR生成器结构

```c
typedef struct IRGenerator {
    IRInst **instructions;    // IR指令列表
    int inst_count;           // 当前指令数量
    int inst_capacity;        // 指令列表容量
    int current_id;           // 当前指令ID（用于SSA）
} IRGenerator;
```

## 4. IR生成器接口

### 4.1 IR生成器函数

```c
// 创建IR生成器
IRGenerator *irgenerator_new();

// 释放IR生成器
void irgenerator_free(IRGenerator *gen);

// 创建IR指令
IRInst *irinst_new(IRInstType type);

// 释放IR指令
void irinst_free(IRInst *inst);

// 打印IR指令（用于调试）
void ir_print(IRInst *inst, int indent);

// 从AST生成IR
void *irgenerator_generate(IRGenerator *ir_gen, ASTNode *ast);

// 释放IR资源
void ir_free(void *ir);
```

## 5. 特殊IR指令详解

### 5.1 切片指令（IR_SLICE）

切片指令用于表示Uya语言的切片操作，支持类似Python的语法。

**语法映射**：
- `slice(arr, start, len)` → `IR_SLICE` 指令
- `arr[start:end]` → `IR_SLICE` 指令（操作符语法糖）

**字段说明**：
- `dest`：目标切片变量名
- `source`：源数组的IR表示
- `start`：起始索引的IR表示（支持负数索引）
- `length`：切片长度的IR表示

**负数索引处理**：
- 编译期将负数索引转换为正数索引：`-n` 转换为 `len(arr) - n`
- 例如：`slice(arr, -3, 3)` 对于长度为10的数组转换为 `slice(arr, 7, 3)`

**边界检查**：
- 编译期或运行时验证：`start >= 0 && start < len(source) && length >= 0 && start + length <= len(source)`
- 无法验证安全 → 编译错误

### 5.2 错误联合类型指令（IR_ERROR_UNION）

用于表示Uya语言的错误联合类型 `!T`。

**字段说明**：
- `dest`：目标变量名
- `value`：值或错误的IR表示
- `is_error`：标识是否为错误值（0=正常值，1=错误值）

### 5.3 try/catch指令（IR_TRY_CATCH）

用于表示Uya语言的错误处理机制。

**字段说明**：
- `try_body`：try块的IR表示
- `error_var`：错误变量名
- `catch_body`：catch块的IR表示

## 6. 代码生成映射

### 6.1 类型映射

| Uya类型 | IR类型 | C类型 |
|---------|--------|-------|
| `i8` | `IR_TYPE_I8` | `int8_t` |
| `i16` | `IR_TYPE_I16` | `int16_t` |
| `i32` | `IR_TYPE_I32` | `int32_t` |
| `i64` | `IR_TYPE_I64` | `int64_t` |
| `u8` | `IR_TYPE_U8` | `uint8_t` |
| `u16` | `IR_TYPE_U16` | `uint16_t` |
| `u32` | `IR_TYPE_U32` | `uint32_t` |
| `u64` | `IR_TYPE_U64` | `uint64_t` |
| `f32` | `IR_TYPE_F32` | `float` |
| `f64` | `IR_TYPE_F64` | `double` |
| `bool` | `IR_TYPE_BOOL` | `uint8_t` |
| `byte` | `IR_TYPE_BYTE` | `uint8_t` |
| `void` | `IR_TYPE_VOID` | `void` |
| `&T` | `IR_TYPE_PTR` | `T*` |
| `[T; N]` | `IR_TYPE_ARRAY` | `T[N]` |
| `!T` | `IR_TYPE_ERROR_UNION` | `union { T value; Error error; }` |

### 6.2 运算符映射

| Uya运算符 | IR操作符 | C运算符 |
|-----------|----------|---------|
| `+` | `IR_OP_ADD` | `+` |
| `-` | `IR_OP_SUB` | `-` |
| `*` | `IR_OP_MUL` | `*` |
| `/` | `IR_OP_DIV` | `/` |
| `%` | `IR_OP_MOD` | `%` |
| `==` | `IR_OP_EQ` | `==` |
| `!=` | `IR_OP_NE` | `!=` |
| `<` | `IR_OP_LT` | `<` |
| `<=` | `IR_OP_LE` | `<=` |
| `>` | `IR_OP_GT` | `>` |
| `>=` | `IR_OP_GE` | `>=` |
| `&` | `IR_OP_BIT_AND` | `&` |
| `\|` | `IR_OP_BIT_OR` | `\|` |
| `^` | `IR_OP_BIT_XOR` | `^` |
| `<<` | `IR_OP_LEFT_SHIFT` | `<<` |
| `>>` | `IR_OP_RIGHT_SHIFT` | `>>` |
| `&&` | `IR_OP_LOGIC_AND` | `&&` |
| `\|\|` | `IR_OP_LOGIC_OR` | `\|\|` |

## 7. 切片语法的IR表示

### 7.1 基本切片

**Uya代码**：
```uya
let arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
let slice1: [i32; 3] = slice(arr, 2, 3);  // [2, 3, 4]
```

**对应的IR**：
```c
// 源数组
IRInst *arr_ir = irinst_new(IR_VAR_DECL);
arr_ir->data.var.name = "arr";
arr_ir->data.var.type = IR_TYPE_ARRAY;
// ... 初始化数组

// 切片操作
IRInst *slice_ir = irinst_new(IR_SLICE);
slice_ir->data.slice_op.dest = "slice1";
slice_ir->data.slice_op.source = arr_ir;  // 源数组
slice_ir->data.slice_op.start = constant_2_ir;  // 起始索引2
slice_ir->data.slice_op.length = constant_3_ir;  // 长度3
```

### 7.2 负数索引切片

**Uya代码**：
```uya
let slice2: [i32; 3] = slice(arr, -3, 3);  // [7, 8, 9]，从倒数第3个开始
```

**对应的IR**：
```c
// 对于长度为10的数组，-3转换为7
IRInst *slice_neg_ir = irinst_new(IR_SLICE);
slice_neg_ir->data.slice_op.dest = "slice2";
slice_neg_ir->data.slice_op.source = arr_ir;  // 源数组
slice_neg_ir->data.slice_op.start = constant_7_ir;  // 起始索引7（-3转换后）
slice_neg_ir->data.slice_op.length = constant_3_ir;  // 长度3
```

### 7.3 操作符语法切片

**Uya代码**：
```uya
let slice3: [i32; 3] = arr[2:5];  // [2, 3, 4]，从索引2到4
```

**对应的IR**：
```c
// 操作符语法 [start:end] 等价于 slice(arr, start, end-start)
IRInst *slice_op_ir = irinst_new(IR_SLICE);
slice_op_ir->data.slice_op.dest = "slice3";
slice_op_ir->data.slice_op.source = arr_ir;  // 源数组
slice_op_ir->data.slice_op.start = constant_2_ir;  // 起始索引2
// 长度为 end - start = 5 - 2 = 3
slice_op_ir->data.slice_op.length = constant_3_ir;  // 长度3
```

## 8. 安全保证

### 8.1 边界检查

所有切片操作都必须经过边界检查：
- `start >= 0 && start < len(source)`
- `length >= 0 && start + length <= len(source)`

### 8.2 编译期验证

- 常量索引越界 → 编译错误
- 变量索引 → 必须通过编译期证明安全
- 无法证明安全 → 编译错误，不生成代码

### 8.3 零运行时开销

- 通过路径零指令，安全路径直接访问内存
- 失败路径不存在，不降级、不插运行时锁
- 所有检查在编译期完成

## 9. 优化机会

### 9.1 常量折叠
- 编译期计算常量表达式的值
- 直接替换为常量值，减少运行时计算

### 9.2 边界检查消除
- 当编译期可以证明边界安全时，消除运行时检查
- 零运行时开销的数组访问

### 9.3 内存访问优化
- 优化切片操作的内存拷贝
- 使用高效的内存访问模式

## 10. 与Uya语言哲学的一致性

Uya IR设计完全符合Uya语言的核心哲学：

1. **安全优先**：将运行时的"可能越界"转化为编译期的"要么证明安全，要么返回显式错误"
2. **零运行时开销**：通过路径零指令，失败路径不存在
3. **显式控制**：程序员必须提供边界证明，编译器验证证明
4. **数学确定性**：每个数组访问都有明确的数学证明

> **Uya IR = C语言友好的中间表示 + 编译期安全验证 + 零运行时开销**；
> **所有内存安全在编译期验证，运行时直接访问内存**；
> **通过路径零指令，安全路径零开销**。