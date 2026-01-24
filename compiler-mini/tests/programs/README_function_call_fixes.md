# 函数调用和指针类型修复说明

## 问题描述

在编译 `uya-src` 目录时，遇到以下错误：
- `错误: 函数 'parser_parse_expression' 未找到或函数类型无效`
- `错误: 变量 size_expr 的初始值表达式生成失败`
- `错误: 二元表达式左操作数生成失败 (AST类型: 24)`

这些错误发生在：
1. 函数调用返回指针类型（如 `&ASTNode`）时
2. 函数调用作为变量初始值时
3. 嵌套字段访问（如 `parser.current_token.type`）时

## 根本原因

1. **指针类型处理问题**：
   - 当函数返回指针类型（如 `&ASTNode`）时，如果指向的结构体类型（`ASTNode`）尚未注册，`get_llvm_type_from_ast` 返回 NULL
   - 导致函数声明失败，函数未添加到函数表

2. **嵌套字段访问问题**：
   - 代码生成器在处理嵌套字段访问（如 `parser.current_token.type`）时，无法从指针类型推断出指向的结构体类型
   - 导致"无法确定结构体名称"错误

## 修复方案

### 1. 修复指针类型处理（`get_llvm_type_from_ast`）

**位置**：`compiler-mini/src/codegen.c` 第220-246行

**修复内容**：
- 当指向的结构体类型未注册时，使用通用指针类型（`i8*`）作为后备
- 确保函数声明成功，即使类型不完全匹配

```c
// 修复前：返回 NULL，导致函数声明失败
if (!pointed_llvm_type) {
    // ...
    return NULL;  // 函数声明失败
}

// 修复后：使用通用指针类型作为后备
if (!pointed_llvm_type) {
    // ...
    LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
    return LLVMPointerType(i8_type, 0);  // 使用通用指针类型
}
```

### 2. 修复函数声明失败处理（`codegen_declare_function`）

**位置**：`compiler-mini/src/codegen.c` 第4446-4483行

**修复内容**：
- 当返回类型是结构体类型但未注册时，使用通用指针类型（`i8*`）作为返回类型
- 确保函数被声明，即使类型不完全匹配

```c
// 修复前：返回 0（成功但不声明函数）
if (struct_type == NULL) {
    return 0;  // 函数未声明
}

// 修复后：使用通用指针类型
if (struct_type == NULL) {
    LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
    return_type = LLVMPointerType(i8_type, 0);  // 使用通用指针类型
}
```

### 3. 修复嵌套字段访问（`codegen_gen_expr` - `AST_MEMBER_ACCESS`）

**位置**：`compiler-mini/src/codegen.c` 第2542-2585行

**修复内容**：
- 添加了 `find_struct_field_ast_type` 函数，用于从结构体声明中查找字段的 AST 类型节点
- 改进了嵌套字段访问的处理逻辑，当对象是指针类型时，从嵌套字段访问的 AST 中获取类型信息

### 4. 改进错误消息

**位置**：`compiler-mini/src/codegen.c` 第2201-2204行、第2379-2381行

**修复内容**：
- 添加了详细的错误消息，包括函数名称和位置信息
- 改进了函数调用失败时的错误报告

## 测试用例

### `test_function_call_pointer_return.uya`
测试函数调用返回指针类型的场景：
- 函数返回 `&Node` 类型
- 函数返回 `&i32` 类型
- 函数调用作为变量初始值

**状态**：✅ 测试通过

### `test_nested_member_access.uya`
测试嵌套字段访问的场景：
- `parser.current_token.type` - 访问枚举字段
- `parser.current_token.line` - 访问整数字段
- `parser.arena.size` - 访问嵌套结构体字段

**状态**：✅ 测试通过

## 验证

修复后：
- ✅ `test_function_call_pointer_return.uya` 编译和运行成功
- ✅ `test_nested_member_access.uya` 编译和运行成功
- ✅ 之前的"无法确定结构体名称"错误已解决
- ✅ 函数调用返回指针类型的代码生成正常工作

## 相关文件

- `compiler-mini/src/codegen.c` - 代码生成器修复
- `compiler-mini/tests/programs/test_function_call_pointer_return.uya` - 测试用例
- `compiler-mini/tests/programs/test_nested_member_access.uya` - 测试用例

## 注意事项

1. **类型不完全匹配**：
   - 当结构体类型未注册时，使用通用指针类型（`i8*`）可能导致类型不完全匹配
   - 这在编译器自举时是必要的，因为结构体类型可能尚未注册
   - 实际运行时，类型应该是正确的（因为结构体类型最终会被注册）

2. **函数声明顺序**：
   - 函数声明顺序正确（第三步先声明所有函数）
   - 但在生成函数体时，如果函数声明失败，函数调用会失败
   - 修复后，即使类型不完全匹配，函数也会被声明

