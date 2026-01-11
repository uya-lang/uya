# 待实现特性清单

本文档记录规范支持但代码中未实现的特性，用于逐步实现。

**最后更新**：2026-01-11

---

## 📋 未实现特性列表

### 1. extern 函数声明 ✅

**状态**：✅ 已完成（已实现并验证）

**功能描述**：
- 支持声明外部 C 函数（用于 FFI）
- 语法：`extern fn name(...) type;`
- 必须在顶层声明
- 以分号结尾，无函数体

**实现状态**：
- ✅ Lexer：已支持 `TOKEN_EXTERN` 关键字
- ✅ Parser：已实现 `parser_parse_extern_function()` 函数
- ✅ Parser：`parser_parse_declaration()` 已调用 extern 函数解析
- ✅ Checker：已处理 extern 函数（body 为 NULL 时标记为 extern），修复了参数类型填充问题
- ✅ CodeGen：已处理 extern 函数（body 为 NULL 时只生成声明）
- ✅ 测试：已创建测试用例验证完整流程

**完成工作**：
1. **验证和测试**（优先级：P0）
   - [x] 创建测试用例验证 extern 函数声明语法解析（test_parser.c）
   - [x] 创建测试用例验证 extern 函数类型检查（test_checker.c）
   - [x] 修复 Checker 中 extern 函数参数类型未填充的问题
   - [x] 创建 Uya 测试程序验证完整流程（extern_function.uya）
   - [x] 所有测试通过

**完成时间**：2026-01-11（续29）

**参考文档**：
- `spec/UYA_MINI_SPEC.md` 第 4.2 节（外部函数声明语法）
- `spec/UYA_MINI_SPEC.md` 第 36 行（extern 关键字说明）

**相关文件**：
- `src/lexer.c` - 关键字识别
- `src/parser.c` - `parser_parse_extern_function()` 函数（第 484 行）
- `src/checker.c` - extern 函数类型检查（第 596 行）
- `src/codegen.c` - extern 函数代码生成（第 1085-1145 行）

---

### 2. 结构体比较（==, !=）✅

**状态**：✅ 已完成（已实现并验证）

**功能描述**：
- 支持结构体相等性比较（`==` 和 `!=`）
- 必须逐字段比较
- 仅支持相同结构体类型之间的比较
- 返回 `bool` 类型

**实现状态**：
- ✅ Parser：已支持比较运算符解析（结构体表达式可以参与比较）
- ✅ Checker：类型检查已支持结构体比较（比较运算符要求类型相同，对结构体类型也适用）
- ✅ CodeGen：已实现结构体比较代码生成（逐字段比较，支持嵌套结构体）

**完成工作**：
1. **验证类型检查器**（优先级：P0）
   - [x] 验证 checker 是否已支持结构体比较的类型检查（已支持，比较运算符要求类型相同）
   - [x] 类型检查逻辑无需修改

2. **实现代码生成**（优先级：P0）
   - [x] 在 `codegen_gen_expr()` 的二元表达式处理中，检测结构体类型比较
   - [x] 实现结构体比较辅助函数 `codegen_gen_struct_comparison()`
   - [x] 对于每个字段，生成字段比较代码（使用 `LLVMBuildExtractValue` 提取字段值）
   - [x] 对于 `==` 运算符：使用 `LLVMBuildAnd` 组合所有字段比较结果
   - [x] 对于 `!=` 运算符：使用 `LLVMBuildXor` 对 `==` 结果取反
   - [x] 处理空结构体（0个字段）的比较情况
   - [x] 支持嵌套结构体比较（递归调用）

3. **测试**（优先级：P0）
   - [x] 创建 Uya 测试程序验证结构体比较功能（struct_comparison.uya）
   - [x] 测试程序包含相同结构体比较、不同结构体比较、== 和 != 运算符测试

**完成时间**：2026-01-11（续30）

**参考文档**：
- `spec/UYA_MINI_SPEC.md` 第 340 行（结构体比较规则）
- `spec/UYA_MINI_SPEC.md` 第 436 行（结构体比较代码生成说明）

**相关文件**：
- `src/codegen.c` - `codegen_gen_expr()` 函数中的二元表达式处理（第 479-550 行）
- `src/checker.c` - 二元表达式类型检查（需要验证结构体比较支持）
- `tests/programs/` - 需要创建测试程序

**实现细节**：

结构体比较代码生成示例（伪代码）：
```c
// 对于 struct Point { x: i32, y: i32 } 的 == 比较
// left_val 和 right_val 是结构体值（LLVMValueRef）

// 提取左操作数的字段
LLVMValueRef left_x = LLVMBuildExtractValue(codegen->builder, left_val, 0, "left.x");
LLVMValueRef left_y = LLVMBuildExtractValue(codegen->builder, left_val, 1, "left.y");

// 提取右操作数的字段
LLVMValueRef right_x = LLVMBuildExtractValue(codegen->builder, right_val, 0, "right.x");
LLVMValueRef right_y = LLVMBuildExtractValue(codegen->builder, right_val, 1, "right.y");

// 比较字段
LLVMValueRef x_eq = LLVMBuildICmp(codegen->builder, LLVMIntEQ, left_x, right_x, "x_eq");
LLVMValueRef y_eq = LLVMBuildICmp(codegen->builder, LLVMIntEQ, left_y, right_y, "y_eq");

// 组合字段比较结果（逻辑与）
LLVMValueRef result = LLVMBuildAnd(codegen->builder, x_eq, y_eq, "struct_eq");
```

**注意**：
- 需要从结构体声明获取字段数量
- 需要按字段顺序提取和比较
- 需要处理不同字段类型（i32, bool, 嵌套结构体）

---

## 🎯 实现优先级

### 优先级 P0（高优先级）
1. **extern 函数声明** - 验证和测试完整流程
2. **结构体比较** - 完整实现（类型检查 + 代码生成 + 测试）

### 优先级 P1（中优先级）
- （暂无）

### 优先级 P2（低优先级）
- （暂无）

---

## 📝 实现流程

每个特性实现时，遵循以下流程：

1. **阅读规范**：参考 `spec/UYA_MINI_SPEC.md` 了解语法和语义要求
2. **创建测试**：遵循 TDD 流程，先编写测试用例（Red）
3. **实现功能**：实现最小代码使测试通过（Green）
4. **重构优化**：重构代码，保持测试通过（Refactor）
5. **更新文档**：更新 `PROGRESS.md` 和相关文档

---

## ✅ 完成标准

每个特性完成后，需要满足以下条件：

- ✅ 所有测试用例通过
- ✅ 代码质量检查通过（函数 < 200 行，文件 < 1500 行）
- ✅ 无堆分配（使用 Arena 分配器）
- ✅ 中文注释完整
- ✅ 更新 `PROGRESS.md` 记录完成状态
- ✅ 更新 `TEST_COVERAGE_ANALYSIS.md` 标记特性已实现

