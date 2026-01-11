# 测试程序 Bug 修复待办事项

本文档跟踪测试程序运行中发现的问题和修复进度。

**创建时间**：2026-01-11（测试脚本运行后）

---

## 🔍 测试运行结果

运行 `tests/run_programs.sh` 脚本的结果：
- **总计**：18 个测试程序
- **通过**：11 个
- **失败**：7 个

---

## 🐛 待修复问题列表

### 1. boolean_logic.uya - 链接失败（缺少 main 符号）

**问题描述**：
- 链接错误：`undefined reference to 'main'`
- `nm` 检查显示目标文件中只有 `is_positive` 和 `is_even` 函数，缺少 `main` 函数

**状态**：🔴 待修复

**可能原因**：
- 代码生成器没有生成 main 函数
- 或者代码生成失败但编译器没有报告错误

**修复步骤**：
1. 检查编译器编译 boolean_logic.uya 时是否有错误输出
2. 检查代码生成器是否正确生成所有函数（包括 main）
3. 验证函数代码生成逻辑是否正确处理所有函数声明

**相关文件**：
- `tests/programs/boolean_logic.uya`
- `src/codegen.c` - `codegen_gen_function()` 函数
- `src/codegen.c` - `codegen_generate()` 函数

---

### 2. comparison.uya - 链接失败（缺少 main 符号）

**问题描述**：
- 链接错误：`undefined reference to 'main'`
- 与 boolean_logic.uya 相同的问题

**状态**：🔴 待修复

**修复步骤**：
- 与问题 1 相同（可能是相同根本原因）

**相关文件**：
- `tests/programs/comparison.uya`
- `src/codegen.c`

---

### 3. nested_control.uya - 链接失败（缺少 main 符号）

**问题描述**：
- 链接错误：`undefined reference to 'main'`
- 与 boolean_logic.uya 相同的问题

**状态**：🔴 待修复

**修复步骤**：
- 与问题 1 相同（可能是相同根本原因）

**相关文件**：
- `tests/programs/nested_control.uya`
- `src/codegen.c`

---

### 4. struct_comparison.uya - 链接失败（缺少 main 符号）

**问题描述**：
- 链接错误：`undefined reference to 'main'`
- 与 boolean_logic.uya 相同的问题

**状态**：🔴 待修复

**修复步骤**：
- 与问题 1 相同（可能是相同根本原因）

**相关文件**：
- `tests/programs/struct_comparison.uya`
- `src/codegen.c`

---

### 5. extern_function.uya - 链接失败（缺少外部函数）

**问题描述**：
- 链接错误：`undefined reference to 'add'`
- 程序声明了 extern 函数 `add`，但没有提供实现或链接库

**状态**：🔴 待修复

**可能原因**：
- extern 函数需要外部实现，但测试程序没有提供
- 或者需要链接外部库

**修复步骤**：
1. 选项1：创建外部函数实现文件（C 文件），编译后与目标文件链接
2. 选项2：修改测试脚本，为 extern_function.uya 提供特殊处理（链接外部实现）
3. 选项3：修改测试程序，使用系统提供的函数（如 `printf` 等，但 Uya Mini 不支持字符串）

**推荐方案**：选项1 - 创建简单的 C 实现文件，在测试脚本中特殊处理

**相关文件**：
- `tests/programs/extern_function.uya`
- `tests/run_programs.sh` - 需要修改以支持链接外部函数

---

### 6. nested_struct.uya - 编译失败

**问题描述**：
- 编译器编译失败
- 错误信息：`错误: 代码生成失败`

**状态**：🔴 待修复

**可能原因**：
- 代码生成器对嵌套结构体的支持有问题
- 结构体类型注册或查找失败

**修复步骤**：
1. 运行编译器查看详细错误信息
2. 检查嵌套结构体的代码生成逻辑
3. 验证结构体字段访问代码生成是否正确处理嵌套结构体

**相关文件**：
- `tests/programs/nested_struct.uya`
- `src/codegen.c` - 结构体相关代码生成函数

---

### 7. struct_params.uya - 运行时段错误（Segmentation fault）

**问题描述**：
- 编译和链接成功
- 运行时发生段错误（退出码 139）
- 可能发生在结构体参数传递或返回值处理时

**状态**：🔴 待修复

**可能原因**：
- 结构体参数传递的调用约定问题
- 结构体返回值处理问题
- 栈对齐问题
- 内存访问越界

**修复步骤**：
1. 使用调试工具（gdb）定位段错误位置
2. 检查结构体参数传递的代码生成（可能需要在栈上传参）
3. 检查结构体返回值的代码生成（可能需要使用 sret 调用约定）
4. 验证栈对齐是否正确

**相关文件**：
- `tests/programs/struct_params.uya`
- `src/codegen.c` - 函数调用和结构体处理相关代码

---

## 📋 修复优先级

1. **P0（高优先级）**：问题 1-4（缺少 main 符号）- 影响多个测试程序，可能是同一根本原因
2. **P1（中优先级）**：问题 6（nested_struct 编译失败）- 影响嵌套结构体功能
3. **P2（中优先级）**：问题 7（struct_params 段错误）- 影响结构体参数传递功能
4. **P3（低优先级）**：问题 5（extern_function 链接失败）- 需要特殊处理，不影响核心功能

---

## 🔧 调试建议

### 调试缺少 main 符号问题（问题 1-4）

1. **检查编译器输出**：
   ```bash
   ./compiler-mini tests/programs/boolean_logic.uya -o tests/programs/boolean_logic.o
   ```

2. **检查生成的目标文件**：
   ```bash
   nm tests/programs/boolean_logic.o
   ```

3. **检查 LLVM IR**（如果可能）：
   - 修改代码生成器，输出 LLVM IR 到文件
   - 检查 IR 中是否包含 main 函数

4. **对比成功的测试程序**：
   - 检查 `simple_function.uya` 为什么成功（它也有多个函数）
   - 对比两者的代码生成差异

### 调试 nested_struct 编译失败（问题 6）

1. **运行编译器获取详细错误**：
   ```bash
   ./compiler-mini tests/programs/nested_struct.uya -o tests/programs/nested_struct.o 2>&1
   ```

2. **检查代码生成器错误处理**：
   - 查看 `codegen_generate()` 和 `codegen_gen_function()` 的错误处理
   - 添加更详细的错误信息输出

### 调试 struct_params 段错误（问题 7）

1. **使用 gdb 调试**：
   ```bash
   gdb tests/programs/struct_params
   (gdb) run
   (gdb) bt  # 查看堆栈跟踪
   ```

2. **检查调用约定**：
   - LLVM 对结构体参数和返回值有特定的调用约定
   - 小结构体可能通过寄存器传递
   - 大结构体可能需要通过内存传递

---

## ✅ 修复检查清单

修复每个问题后，确认：
- [ ] 问题已修复
- [ ] 相关测试程序可以通过
- [ ] 没有引入新的问题（其他测试程序仍然通过）
- [ ] 代码质量检查通过（函数 < 200 行，文件 < 1500 行，中文注释）
- [ ] 更新本文档，标记问题为已修复

---

## 📝 修复记录

（待添加修复记录）

---

**参考文档**：
- `PROGRESS.md` - 项目进度
- `TEST_PROGRAMS_VALIDATION.md` - 测试程序验证说明
- `tests/run_programs.sh` - 测试脚本

