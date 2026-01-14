# 数组访问修复上下文

## 当前状态

**最后更新**：2026-01-14

**总体进度**：核心逻辑已修复，段错误问题待解决

## 已完成的工作

### 1. 核心修复 ✅

- **问题**：指针类型（如 `&byte`）的数组访问（如 `buffer_ptr[0]`）无法正确生成代码
- **解决方案**：
  - 参考 clang 生成的 IR：`getelementptr inbounds i8, ptr %buffer_ptr, i64 0`
  - 修改了 `codegen_gen_expr` 和 `codegen_gen_lvalue_address` 中的数组访问处理
  - 对于指针类型，直接使用元素类型（`i8`）和单个索引进行 GEP，而不是创建数组类型

### 2. 修复位置

- `compiler-mini/src/codegen.c`：
  - `codegen_gen_expr` 中的 `AST_ARRAY_ACCESS` 处理（约第1868-1884行）
  - `codegen_gen_lvalue_address` 中的 `AST_ARRAY_ACCESS` 处理（约第597-608行）

### 3. 验证

- 创建了 C 测试程序 `tests/test_llvm_gep.c` 验证 LLVM C API 的正确使用
- 对比了 clang 生成的 IR 和我们的实现，确认方法正确

## 当前问题

### 段错误问题 ⏳

- **位置**：`codegen_gen_stmt` 中的 `LLVMBuildStore` 调用（约第2616行）
- **现象**：
  - `LLVMBuildGEP2` 和 `LLVMBuildLoad2` 调用都成功
  - 段错误发生在最后一个 `LLVMBuildStore` 调用时
  - 堆栈跟踪显示问题发生在 `llvm::Value::setName` 中
- **可能原因**：
  - 类型不匹配（即使宽度相同，类型对象可能不同）
  - LLVM context 问题（基础类型使用全局类型，其他类型在 context 中创建）
  - 内存问题
- **最新进展**（2026-01-14）：
  - 添加了详细的类型验证和调试输出
  - 改进了类型转换逻辑，处理宽度相同但类型对象不同的情况
  - 添加了 bitcast 转换作为最后的类型匹配手段

## 测试程序

- `tests/programs/test_buffer_ptr_access.uya` - 测试指针类型数组访问
- `tests/programs/test_buffer_ptr_access.c` - 等效的 C 程序
- `tests/programs/test_buffer_ptr_access_clang.ll` - clang 生成的 IR（参考）
- `tests/test_llvm_gep.c` - LLVM C API 测试程序

## 关键代码位置

### codegen.c 中的关键修改

1. **codegen_gen_expr - AST_ARRAY_ACCESS**（约第1827-1884行）
   - 对于指针类型，使用元素类型和单个索引进行 GEP
   - 不再创建单元素数组类型

2. **codegen_gen_lvalue_address - AST_ARRAY_ACCESS**（约第569-608行）
   - 类似的修复，支持指针类型数组访问作为左值

3. **codegen_gen_stmt - AST_VAR_DECL**（约第2572-2622行）
   - 添加了详细的类型验证和调试输出
   - 改进了类型转换逻辑，处理宽度相同但类型对象不同的情况
   - 添加了 bitcast 转换作为最后的类型匹配手段
   - 验证了 `var_ptr` 指向的类型与 `llvm_type` 的匹配

4. **调试输出**（需要清理）
   - 多处添加了 `fprintf(stderr, "调试: ...")` 输出
   - 包括类型检查、类型转换、GEP/Load/Store 调用的详细信息
   - 建议在修复完成后移除

## 下一步工作

1. **调试段错误**（进行中）：
   - ✅ 添加了详细的类型验证和调试输出
   - ✅ 改进了类型转换逻辑，处理宽度相同但类型对象不同的情况
   - ⏳ 运行测试程序，查看调试输出，定位具体问题
   - ⏳ 检查是否所有类型都来自同一个 LLVM context

2. **验证修复**：
   - 编译 `arena.uya` 验证修复
   - 运行测试程序验证功能
   - 查看调试输出，确认类型匹配情况

3. **代码清理**：
   - 移除调试输出
   - 整理代码注释

## 参考文档

- `PROGRESS.md` - 项目进度文档（问题12）
- `tests/programs/test_buffer_ptr_access_clang.ll` - clang 生成的 IR（参考实现）
- `tests/test_llvm_gep.c` - LLVM C API 测试程序

## 技术细节

### LLVM GEP 的正确使用

对于指针类型数组访问：
```c
// 错误方法（会导致段错误）：
array_type = LLVMArrayType(element_type, 1);  // 创建数组类型
LLVMBuildGEP2(builder, array_type, array_ptr, indices, 2, "");

// 正确方法（参考 clang）：
LLVMBuildGEP2(builder, element_type, array_ptr, indices, 1, "");
// 直接使用元素类型（如 i8）和单个索引
```

### 关键发现

- `LLVMArrayType` 调用失败是因为传入的 `element_type` 可能无效或类型不匹配
- 直接使用元素类型进行 GEP 是正确的方法，与 clang 的实现一致

