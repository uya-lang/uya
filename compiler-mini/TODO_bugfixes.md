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
- LLVM IR 检查显示 `boolean_logic_debug.ll` 只有 `is_positive` 和 `is_even` 函数，没有 `main` 函数

**状态**：🟡 调查中（已定位问题）

**根本原因**：
- **已确认**：`main` 函数根本没有被生成到 LLVM 模块中（从 LLVM IR 可以看出）
- **问题定位**：逻辑与（`&&`）运算符导致函数体生成失败
  - 使用逻辑与（`&&`）的 `main` 函数都没有被生成
  - 使用逻辑或（`||`）的 `main` 函数可以正常生成（`logical_expr3.uya` 测试通过）
  - 只有比较表达式（无逻辑运算符）的 `if` 语句也能正常工作（`simple_function.uya` 测试通过）

**调试发现**：
1. 已添加 LLVM IR 输出功能（`.ll` 文件），可以查看生成的 IR
2. 创建了逻辑表达式测试程序：
   - `logical_expr.uya` - 简单的逻辑与表达式（失败）
   - `logical_expr2.uya` - 使用布尔变量的逻辑与表达式（失败）
   - `logical_expr3.uya` - 逻辑或表达式（成功）
   - `logical_expr4.uya` - 长的逻辑与表达式链（失败）
3. 所有包含逻辑与（`&&`）表达式的程序都失败，但编译器没有报错（返回码为0）
4. 逻辑与和逻辑或使用相同的处理代码路径，但结果不同

**修复步骤**：
1. ✅ 添加 LLVM IR 输出功能，可以查看生成的 IR
2. ✅ 创建逻辑表达式测试程序，确认问题出在逻辑与运算符
3. ✅ 添加返回值检查（但问题仍然存在，说明这不是根本原因）
4. ✅ 添加调试输出，发现关键问题：
   - 逻辑或（`op=26`, TOKEN_LOGICAL_OR=26）可以进入逻辑运算符处理代码（有调试输出）
   - 逻辑与（`op=25`, TOKEN_LOGICAL_AND=25）完全没有调试输出，说明代码根本没有进入逻辑运算符处理路径
   - 编译器返回0（成功），但函数未被生成到IR中
   - 逻辑与和逻辑或的处理代码完全相同，只是运算符值不同（25 vs 26）
5. ✅ **关键发现（2026-01-11，调试会话）**：
   - 逻辑或（`op=26`）可以进入 `AST_IF_STMT` 处理代码（有调试输出："调试: AST_IF_STMT - 条件表达式是逻辑运算符 (op=26)"）
   - 逻辑或可以进入 `AST_BINARY_EXPR` 分支（有调试输出："调试: AST_BINARY_EXPR - 逻辑运算符 (op=26)"）
   - 逻辑与（`op=25`）完全没有调试输出，说明代码根本没有进入 `AST_IF_STMT` 处理代码
   - **结论**：逻辑与表达式的 if 语句在代码生成阶段根本没有被处理，或者函数体生成在更早的阶段失败
   - 编译器返回0（成功），但函数体未被生成，说明错误没有被正确检测和传播
6. 🔄 **下一步调查方向**：
   - 检查逻辑与表达式的 if 语句是否进入了 `codegen_gen_stmt` 函数
   - 检查函数体生成是否在更早的阶段失败
   - 检查是否有其他导致逻辑与表达式的 if 语句被跳过的原因
   - 检查解析器是否正确解析了逻辑与表达式（可能需要在解析阶段添加调试输出）
7. 🔄 修复逻辑与运算符的代码生成问题

**相关文件**：
- `tests/programs/boolean_logic.uya`
- `tests/programs/logical_expr.uya`（新创建的测试程序）
- `tests/programs/logical_expr2.uya`（新创建的测试程序）
- `tests/programs/logical_expr3.uya`（新创建的测试程序，逻辑或，可以工作）
- `tests/programs/logical_expr4.uya`（新创建的测试程序）
- `src/codegen.c` - `codegen_gen_function()` 函数（第1260行）
- `src/codegen.c` - `codegen_gen_expr()` 函数（第564行，逻辑运算符处理在第722-741行）
- `src/codegen.c` - `codegen_generate()` 函数（第1517-1540行，已添加 IR 输出）

---

### 2. comparison.uya - 链接失败（缺少 main 符号）

**问题描述**：
- 链接错误：`undefined reference to 'main'`
- LLVM IR 检查显示 `comparison_debug.ll` 只有模块头，完全没有函数定义
- 与问题 1 相同的问题（逻辑与运算符）

**状态**：🟡 调查中（与问题1相同根本原因）

**根本原因**：
- **已确认**：与问题1相同，逻辑与（`&&`）运算符导致 `main` 函数没有被生成
- `comparison.uya` 的 `if` 条件包含长的逻辑与表达式链：`a < b && b > a && a <= c && b >= a && a == c && a != b`

**修复步骤**：
- 与问题 1 相同（相同根本原因，修复问题1后应该也能解决此问题）

**相关文件**：
- `tests/programs/comparison.uya`
- `tests/programs/logical_expr4.uya`（新创建的测试程序，相同模式）
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

