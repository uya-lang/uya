# Uya 错误处理架构设计

## 1. 核心概念

### 1.1 错误类型 (`error`)
- `error` 是全局命名空间，类似于 Rust 的 `std::error` 或 Zig 的全局 error set
- `error.TestError` 语法访问错误类型
- 错误类型在编译时转换为唯一的错误码（`uint16_t`）

### 1.2 错误联合类型 (`!T`)
- `!T` 表示 `T | Error`，即要么返回类型 `T` 的值，要么返回错误
- 在内存中需要用标记联合（tagged union）表示，以区分正常值和错误值

### 1.3 错误码生成
- 每个错误名称（如 `TestError`）生成唯一的 `uint16_t` 错误码
- 错误码不能为 0（0 表示成功/无错误）
- 可以使用哈希函数生成错误码：`hash("TestError") -> uint16_t`

## 2. 数据流分析

### 2.1 AST 层 (`parser.c`)
```
return error.TestError;
```
- 解析为：`AST_RETURN_STMT` 
  - `expr`: `AST_MEMBER_ACCESS`
    - `object`: `AST_IDENTIFIER("error")`
    - `field_name`: "TestError"

### 2.2 IR 层 (`ir_generator.c`)
```
AST_MEMBER_ACCESS("error", "TestError") 
  -> IR_MEMBER_ACCESS
    - object: IR_VAR_DECL(name="error", type=IR_TYPE_I32)
    - field_name: "TestError"
```

**问题**：`IR_MEMBER_ACCESS` 无法直接表达"这是一个错误值"的语义

### 2.3 代码生成层 (`codegen.c`)
```
return error.TestError;
  -> _return_var = <生成的错误码>;
  -> goto _error_return_func;
```

**问题**：需要能够识别 `error.TestError` 是错误值，并生成正确的错误码

## 3. 架构设计

### 3.1 方案A：在 IR 层引入 `IR_ERROR_VALUE`

**优点**：
- IR 语义清晰，明确表达错误值
- 代码生成简单，直接生成错误码

**缺点**：
- 需要修改 IR 结构和生成逻辑
- 需要在 `ir_generator.c` 中识别 `error.*` 模式

**实现**：
```c
// ir.h
case IR_ERROR_VALUE: {
    uint16_t error_code;  // 错误码
    char *error_name;     // 错误名称（可选，用于调试）
}

// ir_generator.c
case AST_MEMBER_ACCESS:
    if (is_error_namespace_access(expr)) {
        IRInst *error_val = irinst_new(IR_ERROR_VALUE);
        error_val->data.error_value.error_code = generate_error_code(expr->data.member_access.field_name);
        error_val->data.error_value.error_name = strdup(expr->data.member_access.field_name);
        return error_val;
    }
    // ... 普通成员访问
```

### 3.2 方案B：在代码生成层识别错误值（当前方案）

**优点**：
- 不需要修改 IR 结构
- 实现简单，快速

**缺点**：
- IR 语义不清晰，`IR_MEMBER_ACCESS` 无法区分 `obj.field` 和 `error.ErrorName`
- 代码生成逻辑复杂，需要特殊判断

**当前实现的问题**：
- `codegen_write_value` 中的检查可能没有正确工作
- 需要调试为什么 `error.TestError` 生成为 `0`

### 3.3 方案C：混合方案（推荐）

**设计原则**：
1. **错误值识别**：在 IR 生成时识别 `error.*` 并标记
2. **错误码生成**：在代码生成时生成唯一的错误码
3. **标记联合**：对于 `!T` 类型，在代码生成时生成标记联合结构

**具体实现**：

#### 步骤1：IR 层识别错误值
```c
// 在 ir_generator.c 中
case AST_MEMBER_ACCESS:
    // 检查是否是 error.* 访问
    if (expr->data.member_access.object->type == AST_IDENTIFIER &&
        strcmp(expr->data.member_access.object->data.identifier.name, "error") == 0) {
        // 这是 error.ErrorName，生成特殊的 IR 指令
        // 使用 IR_ERROR_VALUE 或标记 IR_MEMBER_ACCESS 为错误访问
        // 为了不破坏现有结构，我们可以：
        // 1. 使用 IR_MEMBER_ACCESS，但添加一个标记
        // 2. 或者引入 IR_ERROR_VALUE
        
        // 推荐：引入 IR_ERROR_VALUE
        IRInst *error_val = irinst_new(IR_ERROR_VALUE);
        error_val->data.error_value.error_name = strdup(expr->data.member_access.field_name);
        return error_val;
    }
    // ... 普通成员访问
```

#### 步骤2：代码生成错误码
```c
// 在 codegen.c 中
case IR_ERROR_VALUE:
    {
        const char *error_name = inst->data.error_value.error_name;
        uint16_t error_code = generate_error_code_hash(error_name);
        fprintf(codegen->output_file, "%uU", (unsigned int)error_code);
    }
    break;
```

#### 步骤3：`!T` 类型的标记联合
```c
// 对于函数返回类型是 !T 的情况
// 生成标记联合结构：
typedef struct {
    bool is_error;
    union {
        T success_value;
        uint16_t error_code;
    } value;
} ErrorUnion_T;

// 函数签名：
ErrorUnion_i32 func_name(...);

// 返回值：
ErrorUnion_i32 result;
if (is_error_value) {
    result.is_error = true;
    result.value.error_code = error_code;
} else {
    result.is_error = false;
    result.value.success_value = normal_value;
}
```

#### 步骤4：errdefer 执行判断
```c
// 在函数末尾：
if (result.is_error) {
    // 执行 errdefer
    // 执行 defer
    // 执行 drop
    return result;
} else {
    // 执行 defer
    // 执行 drop
    return result;
}
```

## 4. 推荐实现路径

### 阶段1：修复错误值识别（最小改动）
- 引入 `IR_ERROR_VALUE` IR 指令类型
- 在 `ir_generator.c` 中识别 `error.*` 并生成 `IR_ERROR_VALUE`
- 在 `codegen.c` 中生成错误码
- **目标**：`error.TestError` 能正确生成错误码

### 阶段2：实现标记联合（完整支持）
- 修改 `!T` 类型的代码生成，生成标记联合结构
- 修改函数返回值处理，使用标记联合
- **目标**：`!T` 类型函数能正确返回标记联合

### 阶段3：实现运行时检测（errdefer 支持）
- 在函数末尾检测 `is_error` 标记
- 根据标记决定是否执行 `errdefer`
- **目标**：`errdefer` 只在错误返回时执行

### 阶段4：优化和测试
- 测试各种场景
- 优化代码生成
- 错误处理优化

## 5. 关键技术点

### 5.1 错误码生成算法
```c
static uint16_t generate_error_code(const char *error_name) {
    uint16_t code = 0;
    for (const char *p = error_name; *p; p++) {
        code = code * 31 + (unsigned char)*p;  // 简单的哈希函数
    }
    // 确保错误码不为 0（0 表示成功）
    if (code == 0) code = 1;
    return code;
}
```

### 5.2 标记联合结构生成
- 需要根据 base type (`T`) 生成对应的标记联合类型
- 类型名称：`ErrorUnion_<BaseTypeName>`
- 例如：`!i32` -> `ErrorUnion_i32`, `!void` -> `ErrorUnion_void`

### 5.3 错误值检测
- 在函数返回时，需要检测返回值是否为错误值
- 如果返回值是 `IR_ERROR_VALUE`，则 `is_error = true`
- 如果返回值是普通值，则 `is_error = false`


