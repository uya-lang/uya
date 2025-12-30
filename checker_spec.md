# Uya语言类型检查器规范文档

## 1. 概述

### 1.1 设计目标
Uya语言的类型检查器旨在在编译期验证代码的类型安全性和内存安全性，确保所有未定义行为（UB）都被证明为安全，否则导致编译错误。类型检查器遵循以下原则：

- **零运行时开销**：所有类型检查在编译期完成
- **内存安全强制**：所有UB必须被编译期证明为安全，失败即编译错误
- **显式边界检查**：程序员必须提供边界证明，编译器验证证明
- **数学确定性**：每个数组访问都有明确的数学证明

### 1.2 检查器架构
```
AST -> 类型检查器 -> 安全证明 -> 通过 → IR生成器
                    ↓
                 编译错误 ← 无法证明安全
```

## 2. 类型检查器接口

### 2.1 类型检查器结构

```c
typedef struct TypeChecker {
    // 检查器状态
    int error_count;              // 错误计数
    char **errors;                // 错误消息列表
    int error_capacity;           // 错误列表容量
    int current_line;             // 当前行号
    int current_column;           // 当前列号
    char *current_file;           // 当前文件名
    
    // 符号表
    SymbolTable *symbol_table;    // 符号表，用于类型查找
    ScopeStack *scopes;           // 作用域栈，用于变量作用域管理
    
    // 类型系统
    TypeRegistry *type_registry;  // 类型注册表
} TypeChecker;
```

### 2.2 符号表结构

```c
typedef struct Symbol {
    char *name;                   // 符号名
    ASTNodeType symbol_type;      // 符号类型（变量、函数、类型等）
    IRType type;                  // 类型信息
    int scope_level;              // 作用域层级
    int line;                     // 定义行号
    int column;                   // 定义列号
    char *filename;               // 定义文件名
} Symbol;

typedef struct SymbolTable {
    Symbol **symbols;             // 符号列表
    int symbol_count;             // 符号数量
    int symbol_capacity;          // 符号容量
} SymbolTable;

typedef struct ScopeStack {
    int *levels;                  // 作用域层级列表
    int level_count;              // 层级数量
    int level_capacity;           // 层级容量
} ScopeStack;
```

## 3. 类型检查器函数接口

### 3.1 基础函数

```c
// 创建类型检查器
TypeChecker *typechecker_new();

// 释放类型检查器
void typechecker_free(TypeChecker *checker);

// 执行类型检查
int typechecker_check(TypeChecker *checker, ASTNode *ast);

// 添加错误
void typechecker_add_error(TypeChecker *checker, const char *fmt, ...);

// 查找符号
Symbol *typechecker_lookup_symbol(TypeChecker *checker, const char *name);

// 添加符号到符号表
int typechecker_add_symbol(TypeChecker *checker, Symbol *symbol);

// 进入新作用域
void typechecker_enter_scope(TypeChecker *checker);

// 退出当前作用域
void typechecker_exit_scope(TypeChecker *checker);
```

## 4. 类型安全检查

### 4.1 数组边界检查

类型检查器必须验证所有数组访问的安全性：

**检查规则**：
- 常量索引越界 → **编译错误**
- 变量索引 → 必须证明 `i >= 0 && i < len`，证明失败 → **编译错误**

**示例**：
```uya
let arr: [i32; 10] = [0; 10];
let i: i32 = get_index();

// 类型检查器验证：必须证明 i >= 0 && i < 10
let x: i32 = arr[i];  // 编译期验证安全
```

**验证方法**：
1. **路径敏感分析**：跟踪所有代码路径，分析变量状态
2. **条件分支约束**：通过if语句建立约束条件
3. **数学证明**：验证索引表达式的数学关系

### 4.2 切片边界检查

对于切片操作，类型检查器验证：

**检查规则**：
- `slice(arr, start, len)` 必须证明：
  - `start >= -len(arr) && start < len(arr)` （起始索引边界）
  - `len >= 0 && start + len <= len(arr)` （长度和结束边界）
- 无法证明安全 → **编译错误**

**负数索引处理**：
- 编译期将负数索引转换为正数索引：`-n` 转换为 `len(arr) - n`
- 例如：`slice(arr, -3, 3)` 对于长度为10的数组，验证 `7 >= 0 && 7 < 10 && 3 >= 0 && 7 + 3 <= 10`

### 4.3 空指针解引用检查

**检查规则**：
- 必须证明 `ptr != null` 或前序有 `if ptr == null { return error; }`，证明失败 → **编译错误**

**示例**：
```uya
let ptr: byte* = get_ptr();
if ptr == null {
    return error.NullPointer;  // 提前返回错误
}
let val: byte = *ptr;  // 编译器证明 ptr != null，安全
```

### 4.4 整数溢出检查

**检查规则**：
- 常量运算溢出 → **编译错误**
- 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
- 无法证明无溢出 → **编译错误**

**溢出检查模式**：
- **加法上溢**：`a > 0 && b > 0 && a > MAX - b`
- **加法下溢**：`a < 0 && b < 0 && a < MIN - b`
- **乘法上溢**：`a > 0 && b > 0 && a > MAX / b`

### 4.5 除零错误检查

**检查规则**：
- 常量除零 → **编译错误**
- 变量 → 必须证明 `y != 0`，证明失败 → **编译错误**

## 5. 类型系统检查

### 5.1 类型匹配检查

**规则**：所有运算符两边的类型必须完全一致，无隐式转换。

**示例**：
```uya
let x: i32 = 10;
let y: f64 = 3.14;
let z: i32 = x + y;  // 编译错误：类型不匹配
```

### 5.2 函数调用检查

**参数类型检查**：
- 函数调用时，参数类型必须与函数签名完全匹配
- 不支持隐式类型转换

**返回类型检查**：
- 返回值类型必须与函数声明的返回类型匹配

### 5.3 变量声明检查

**类型一致性**：
- 变量声明的类型必须与初始化表达式的类型一致
- `mut` 变量可以重新赋值，但类型必须一致

## 6. 切片语法的类型检查

### 6.1 切片函数调用检查

**语法**：`slice(arr, start, len)`

**检查项目**：
1. **函数存在性**：验证`slice`函数存在
2. **参数数量**：必须有3个参数
3. **参数类型**：
   - 第1个参数：数组类型 `[T; N]`
   - 第2个参数：整数类型 `i32`
   - 第3个参数：整数类型 `i32`
4. **边界验证**：验证 `start` 和 `len` 的边界条件

### 6.2 操作符语法检查

**语法**：`arr[start:len]`

**检查项目**：
1. **源类型**：`arr` 必须是数组类型
2. **索引类型**：`start` 和 `len` 必须是整数类型
3. **边界验证**：同切片函数调用检查

### 6.3 负数索引检查

**规则**：
- 负数索引在编译期转换为正数索引
- 转换后的索引必须满足边界条件
- 例如：`arr[-3:5]` 转换为 `arr[len(arr)-3:5]`，然后验证边界

## 7. 错误处理检查

### 7.1 错误联合类型检查

**语法**：`!T` 表示 `T | Error`

**检查项目**：
- `try` 表达式只能用于返回错误联合类型的函数
- `catch` 块必须返回与try表达式相同类型的值
- 错误传播的类型必须匹配

### 7.2 错误定义检查

**预定义错误**：
- 错误必须在顶层定义（可选）
- 错误名称必须唯一

**运行时错误**：
- 支持 `error.ErrorName` 语法，无需预定义
- 编译器收集所有使用的错误名称

## 8. 接口系统检查

### 8.1 接口实现检查

**规则**：
- 实现必须提供接口声明的所有方法
- 方法签名必须完全匹配
- 参数和返回类型必须一致

### 8.2 接口调用检查

**规则**：
- 接口方法调用时，必须验证实现类型具有相应方法
- 类型安全验证

## 9. 原子类型检查

### 9.1 原子操作检查

**规则**：
- `atomic T` 类型的所有操作都必须是原子的
- 复合赋值操作（`+=`, `-=`, 等）自动生成原子指令
- 类型安全验证

## 10. 类型检查算法

### 10.1 遍历算法

类型检查器使用深度优先遍历算法检查AST：

```c
int typechecker_check_node(TypeChecker *checker, ASTNode *node) {
    if (!node) return 1;  // 空节点视为安全
    
    switch (node->type) {
        case AST_VAR_DECL:
            return typechecker_check_var_decl(checker, node);
        case AST_FN_DECL:
            return typechecker_check_fn_decl(checker, node);
        case AST_BINARY_EXPR:
            return typechecker_check_binary_expr(checker, node);
        case AST_CALL_EXPR:
            return typechecker_check_call_expr(checker, node);
        case AST_SUBSCRIPT_EXPR:
            return typechecker_check_subscript_expr(checker, node);
        case AST_SLICE_EXPR:  // 新增：切片表达式检查
            return typechecker_check_slice_expr(checker, node);
        // ... 其他节点类型
        default:
            return 1;  // 默认视为安全
    }
}
```

### 10.2 切片表达式检查算法

```c
int typechecker_check_slice_expr(TypeChecker *checker, ASTNode *node) {
    if (!node || node->type != AST_SLICE_EXPR) {
        return 0;  // 不是切片表达式
    }
    
    // 检查源数组
    ASTNode *source = node->data.slice_expr.source;
    if (!typechecker_check_node(checker, source)) {
        return 0;
    }
    
    // 验证源是数组类型
    IRType source_type = typechecker_infer_type(checker, source);
    if (!typechecker_is_array_type(source_type)) {
        typechecker_add_error(checker, "切片操作的源必须是数组类型，但得到了 %s", 
                             typechecker_type_name(source_type));
        return 0;
    }
    
    // 检查起始索引
    ASTNode *start = node->data.slice_expr.start;
    if (!typechecker_check_node(checker, start)) {
        return 0;
    }
    
    IRType start_type = typechecker_infer_type(checker, start);
    if (!typechecker_is_integer_type(start_type)) {
        typechecker_add_error(checker, "切片起始索引必须是整数类型，但得到了 %s", 
                             typechecker_type_name(start_type));
        return 0;
    }
    
    // 检查长度
    ASTNode *length = node->data.slice_expr.length;
    if (!typechecker_check_node(checker, length)) {
        return 0;
    }
    
    IRType length_type = typechecker_infer_type(checker, length);
    if (!typechecker_is_integer_type(length_type)) {
        typechecker_add_error(checker, "切片长度必须是整数类型，但得到了 %s", 
                             typechecker_type_name(length_type));
        return 0;
    }
    
    // 边界检查：尝试证明安全性
    if (!typechecker_prove_slice_bounds(checker, source, start, length)) {
        typechecker_add_error(checker, "无法证明切片操作的安全性：slice(%s, %s, %s)", 
                             node->data.slice_expr.source_name,
                             node->data.slice_expr.start_name,
                             node->data.slice_expr.length_name);
        return 0;
    }
    
    return 1;  // 检查通过
}
```

### 10.3 边界证明算法

类型检查器使用路径敏感分析来证明边界：

```c
int typechecker_prove_slice_bounds(TypeChecker *checker, 
                                   ASTNode *source, 
                                   ASTNode *start, 
                                   ASTNode *length) {
    // 获取数组长度（编译期常量或运行时值）
    int array_len = typechecker_get_array_length(source);
    
    // 分析起始索引的可能值
    ValueRange start_range = typechecker_analyze_range(start);
    
    // 分析长度的可能值
    ValueRange length_range = typechecker_analyze_range(length);
    
    // 验证边界条件
    // start >= -array_len && start < array_len
    if (start_range.min < -array_len || start_range.max >= array_len) {
        return 0;  // 无法证明起始索引安全
    }
    
    // length >= 0 && start + length <= array_len
    if (length_range.min < 0 || 
        (start_range.max + length_range.max) > array_len) {
        return 0;  // 无法证明长度安全
    }
    
    return 1;  // 边界安全
}
```

## 11. 与Uya语言哲学的一致性

类型检查器完全符合Uya语言的核心哲学：

1. **安全优先**：将运行时的"可能越界"转化为编译期的"要么证明安全，要么返回显式错误"
2. **零运行时开销**：所有类型检查在编译期完成
3. **显式控制**：程序员必须提供边界证明，编译器验证证明
4. **数学确定性**：每个数组访问都有明确的数学证明

## 12. 性能特性

### 12.1 编译期优化
- 常量边界检查在编译期完成
- 类型推断优化
- 符号表查找优化

### 12.2 内存效率
- 符号表使用哈希表实现，O(1)查找
- 作用域管理优化内存使用
- 错误消息池减少内存分配

## 13. 错误报告

### 13.1 错误类型
- `TYPE_MISMATCH`：类型不匹配错误
- `ARRAY_BOUNDS_ERROR`：数组边界错误
- `SLICE_BOUNDS_ERROR`：切片边界错误
- `NULL_POINTER_ERROR`：空指针解引用错误
- `INTEGER_OVERFLOW_ERROR`：整数溢出错误
- `DIVISION_BY_ZERO_ERROR`：除零错误

### 13.2 错误格式
```
错误: [错误类型] [错误消息]
  --> 文件名:行号:列号
   |
行号 | 源代码行
   |     ^^^^^^^^ 错误位置
   |
   = note: 附加信息
   = help: 修复建议
```

## 14. 与现有特性的集成

### 14.1 与类型系统的集成
- 类型推断与类型检查协同工作
- 泛型类型检查支持
- 错误联合类型检查

### 14.2 与内存安全的集成
- 所有内存访问经过类型检查器验证
- 与RAII和drop机制兼容
- 与指针算术检查集成

### 14.3 与错误处理的集成
- 错误联合类型验证
- try/catch类型安全检查
- 错误传播路径验证

> **Uya类型检查器 = 编译期安全证明 + 零运行时开销 + 数学确定性**；
> **所有UB必须被证明安全 → 失败即编译错误**；
> **通过路径零指令，失败路径不存在**。