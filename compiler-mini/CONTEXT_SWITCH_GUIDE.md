# 编译器修复工作 - 上下文切换指南

## 📋 当前状态概览

**测试结果**: 61 个测试中 58 个通过，3 个失败

**失败的测试**:
1. `pointer_deref_assign` - 段错误（Segmentation Fault）
2. `pointer_test` - 函数体生成失败: get_global_pointer（全局变量支持未实现）
3. `sizeof_test` - 函数体生成失败: main（可能涉及数组字面量的其他问题或sizeof对数组的处理）

---

## ✅ 已完成的修复

### 问题 3: sizeof_test - 数组字面量支持（已完成基础实现）

**完成的工作**:

1. **AST 节点类型添加** (`src/ast.h`)
   - ✅ 添加了 `AST_ARRAY_LITERAL` 枚举值
   - ✅ 添加了 `array_literal` union 成员：`elements` (ASTNode**) 和 `element_count` (int)

2. **AST 初始化** (`src/ast.c`)
   - ✅ 在 `ast_new_node` 中添加了 `AST_ARRAY_LITERAL` 的初始化代码

3. **解析器实现** (`src/parser.c`)
   - ✅ 在 `parser_parse_primary_expr` 函数中（约1330行之前）添加了数组字面量解析
   - ✅ 支持语法：`[expr1, expr2, ..., exprN]`
   - ✅ 处理空数组 `[]`
   - ✅ 使用动态数组分配（类似结构体字面量）

4. **类型检查支持** (`src/checker.c`)
   - ✅ 在 `checker_infer_type` 函数中（约558行）添加了 `AST_ARRAY_LITERAL` case
   - ✅ 从第一个元素推断元素类型
   - ✅ 使用元素数量作为数组大小

5. **代码生成基础实现** (`src/codegen.c`)
   - ✅ 在 `codegen_gen_expr` 函数中（约1237行）添加了 `AST_ARRAY_LITERAL` case
   - ✅ 使用 alloca + store 模式生成数组值
   - ✅ 从第一个元素推断数组类型（简化实现）
   - ⚠️ 注意：当前实现从元素推断类型，但在变量初始化时可能需要使用变量类型（待优化）

**相关文件**:
- `src/ast.h` - AST 节点定义
- `src/ast.c` - AST 节点创建
- `src/parser.c` - 解析器（约1330行附近）
- `src/checker.c` - 类型检查（约558行附近）
- `src/codegen.c` - 代码生成（约1461行附近）

---

### 问题 2: pointer_test - 结构体指针字段访问支持

**完成的工作**:

1. **字段访问代码修改** (`src/codegen.c`)
   - 位置：`codegen_gen_expr` 函数中的 `AST_MEMBER_ACCESS` case（约1269行）
   - 修改：添加了对指针类型对象的支持
   - 逻辑：
     - 当对象是标识符且变量类型是指针类型时，加载指针值
     - 从指针类型中提取指向的结构体类型
     - 使用 `find_struct_name_from_type` 获取结构体名称

2. **参数处理改进** (`src/codegen.c`)
   - 位置：`codegen_gen_function` 函数中的参数处理循环（约2183行）
   - 修改：为指针类型参数也提取结构体名称
   - 逻辑：
     - 检查参数类型是否为 `AST_TYPE_POINTER`
     - 如果是，递归检查 `pointed_type` 是否为结构体类型
     - 如果是结构体类型，提取结构体名称并存储到变量表

**相关文件**:
- `src/codegen.c` - 代码生成（约1269行和2183行附近）

**当前状态**: 代码已实现，但测试仍失败。可能的问题：
- 结构体名称查找失败
- 指针加载逻辑有问题
- 类型匹配问题

---

## 🔍 待修复的问题

### 问题 1: pointer_deref_assign - 段错误

**错误信息**:
```
测试: pointer_deref_assign
  ❌ 编译失败（段错误，exit code 139）
```

**问题分析**:
- 测试文件：`tests/programs/pointer_deref_assign.uya`
- 问题出现在指针解引用赋值：`*p = value`
- 涉及指针类型函数参数：`fn set_value(p: &i32, value: i32) void`

**可能的原因**:
1. `codegen_gen_lvalue_address` 函数在处理 `*p` 时出现问题
2. 指针类型参数在变量表中的存储方式问题
3. 类型检查或代码生成时的空指针访问

**相关代码位置**:
- `src/codegen.c` - `codegen_gen_lvalue_address` 函数（约326行）
- `src/codegen.c` - `codegen_gen_expr` 函数中的 `AST_UNARY_EXPR` case（约923行）

**调试建议**:
1. 使用 gdb 或 valgrind 定位具体崩溃位置
2. 检查 `codegen_gen_lvalue_address` 中的 `AST_UNARY_EXPR` 处理
3. 验证指针类型参数的加载逻辑

---

### 问题 2: pointer_test - 函数体生成失败（部分完成）

**错误信息**:
```
错误: 函数体生成失败: get_point_x (返回值: -1)
错误: 函数代码生成失败: get_point_x
```

**失败的函数** (`tests/programs/pointer_test.uya:30-33`):
```uya
fn get_point_x(p: &Point) i32 {
    return p.x;  // 结构体指针字段访问
}
```

**已完成的工作**:
- ✅ 字段访问代码已修改支持指针类型
- ✅ 参数处理代码已改进存储结构体名称

**可能的问题**:
1. `lookup_var_struct_name` 无法找到指针类型参数的结构体名称
2. `find_struct_name_from_type` 函数无法从 LLVM 类型找到结构体名称
3. 结构体类型映射表未正确建立

**调试建议**:
1. 添加调试输出，确认 `struct_name` 是否为 NULL
2. 检查 `find_struct_name_from_type` 函数的实现
3. 验证结构体类型映射表的建立时机
4. 检查参数处理代码是否正确存储结构体名称

**相关代码位置**:
- `src/codegen.c` - `codegen_gen_expr` 函数的 `AST_MEMBER_ACCESS` case（约1269行）
- `src/codegen.c` - `codegen_gen_function` 函数的参数处理（约2183行）
- `src/codegen.c` - `find_struct_name_from_type` 函数（约541行）
- `src/codegen.c` - `lookup_var_struct_name` 函数（约469行）

---

### 问题 3: sizeof_test - 函数体生成失败（部分完成）

**错误信息**:
```
错误: 函数体生成失败: main (返回值: -1)
错误: 函数代码生成失败: main
```

**测试文件**: `tests/programs/sizeof_test.uya`

**已完成的工作**:
- ✅ 数组字面量解析已实现
- ✅ 类型推断已添加

**可能的问题**:
1. 数组字面量的代码生成需要知道目标类型（变量类型）
2. 当前实现从第一个元素推断类型，可能与变量类型不匹配
3. 结构体数组字面量的代码生成未实现

**相关代码位置**:
- `src/codegen.c` - `codegen_gen_expr` 函数的 `AST_ARRAY_LITERAL` case（约1461行）
- `src/codegen.c` - `codegen_gen_stmt` 函数的 `AST_VAR_DECL` case（约1723行，变量初始化）

**调试建议**:
1. 查看变量初始化时数组字面量的处理
2. 考虑在变量初始化时传入目标类型
3. 检查结构体数组字面量的代码生成
4. 查看类型检查阶段的类型匹配逻辑

**失败的代码行** (`tests/programs/sizeof_test.uya:118`):
```uya
var nums: [i32: 5] = [1, 2, 3, 4, 5];
```

---

## 🔧 调试工具和命令

### 编译
```bash
cd /media/winger/_dde_home/winger/uya/compiler-mini
make clean && make
```

### 运行测试
```bash
./tests/run_programs.sh
```

### 单独测试失败用例
```bash
# 问题 1
./build/compiler-mini tests/programs/pointer_deref_assign.uya -o /tmp/test.o

# 问题 2
./build/compiler-mini tests/programs/pointer_test.uya -o /tmp/test.o

# 问题 3
./build/compiler-mini tests/programs/sizeof_test.uya -o /tmp/test.o
```

### 使用调试器（如果可用）
```bash
# GDB
gdb --args ./build/compiler-mini tests/programs/pointer_deref_assign.uya -o /tmp/test.o

# Valgrind
valgrind --leak-check=full ./build/compiler-mini tests/programs/pointer_deref_assign.uya -o /tmp/test.o
```

---

## 📝 代码变更摘要

### 新增文件
- `BUG_REVIEW.md` - 问题评审报告
- `FIX_PROGRESS.md` - 修复进度报告
- `CONTEXT_SWITCH_GUIDE.md` - 本文档

### 修改的文件

1. **src/ast.h**
   - 添加 `AST_ARRAY_LITERAL` 枚举值
   - 添加 `array_literal` union 成员

2. **src/ast.c**
   - 在 `ast_new_node` 中添加 `AST_ARRAY_LITERAL` 初始化

3. **src/parser.c**
   - 在 `parser_parse_primary_expr` 中添加数组字面量解析（约1330行之前）

4. **src/checker.c**
   - 在 `checker_infer_type` 中添加 `AST_ARRAY_LITERAL` case（约558行）

5. **src/codegen.c**
   - 在 `codegen_gen_expr` 中添加 `AST_ARRAY_LITERAL` case（约1461行）
   - 修改 `AST_MEMBER_ACCESS` case 支持指针类型对象（约1269行）
   - 修改 `codegen_gen_function` 参数处理支持指针类型参数的结构体名称（约2183行）

---

## 🎯 下一步行动计划

### 优先级 1: 实现全局变量支持（pointer_test - get_global_pointer）

**原因**: 这是导致pointer_test失败的直接原因，需要实现全局变量支持

**步骤**:
1. 在代码生成器中添加全局变量表（类似函数表）
2. 在 `codegen_generate` 中处理全局变量声明（在函数声明之前）
3. 在 `lookup_var` 中添加全局变量查找逻辑（如果局部变量表中找不到，查找全局变量表）
4. 在取地址运算符中支持全局变量（`&global_var`）

**关键代码位置**:
```c
// src/codegen.c:1913 - codegen_generate 函数（需要添加全局变量处理）
// src/codegen.c:708 - AST_UNARY_EXPR case（取地址运算符）
// src/codegen.c:290 - lookup_var 函数（需要添加全局变量查找）
// src/codegen.h - 需要添加全局变量表定义
```

### 优先级 2: 修复问题 1（pointer_deref_assign 段错误）

**原因**: 段错误需要调试工具定位

**步骤**:
1. 如果有调试工具，使用 gdb/valgrind 定位崩溃位置
2. 检查 `codegen_gen_lvalue_address` 函数
3. 验证指针类型参数的加载逻辑
4. 检查空指针访问的可能性

**关键代码位置**:
```c
// src/codegen.c:326 - codegen_gen_lvalue_address 函数
// src/codegen.c:341 - AST_UNARY_EXPR case（解引用处理）
```

### 优先级 3: 调试问题 3（sizeof_test）

**原因**: 基础功能已实现，但仍失败，需要调试

**已完成的工作**:
- ✅ 数组字面量语法解析
- ✅ 数组字面量类型推断
- ✅ 数组字面量代码生成（支持基础类型和结构体类型）
- ✅ 简单的数组字面量和结构体数组字面量测试通过

**待调试的问题**:
1. sizeof_test仍然失败，需要查看具体的错误信息
2. 可能需要检查sizeof对数组类型的处理
3. 可能需要检查变量初始化时数组字面量的类型匹配

**关键代码位置**:
```c
// src/codegen.c:1237 - AST_ARRAY_LITERAL case（代码生成）
// src/checker.c:558 - AST_ARRAY_LITERAL case（类型推断）
// src/codegen.c:1478 - AST_VAR_DECL case（变量初始化）
```

---

## 📚 相关文档

- `BUG_REVIEW.md` - 详细的问题评审和分析
- `FIX_PROGRESS.md` - 修复进度报告
- `tests/programs/pointer_deref_assign.uya` - 问题 1 测试文件
- `tests/programs/pointer_test.uya` - 问题 2 测试文件
- `tests/programs/sizeof_test.uya` - 问题 3 测试文件

---

## 💡 关键洞察

1. **数组字面量的类型推断问题**: 当前实现从元素推断类型，但在变量初始化时需要从变量类型推断，这两个方向可能不一致。

2. **指针类型参数的结构体名称存储**: 指针类型参数的结构体名称需要从 `AST_TYPE_POINTER.pointed_type` 中提取，这是一个递归过程。

3. **字段访问的双重处理**: 字段访问需要同时支持结构体类型和指针类型对象，逻辑略有不同（指针类型需要先加载）。

4. **类型映射表的建立时机**: 结构体类型需要在代码生成之前建立映射表，否则 `find_struct_name_from_type` 无法工作。

---

## 🔍 调试技巧

1. **添加临时调试输出**:
   ```c
   fprintf(stderr, "调试: struct_name = %s\n", struct_name ? struct_name : "(null)");
   ```

2. **检查返回值**:
   - 所有可能返回 NULL 的函数调用都应该检查
   - 特别关注 `lookup_var`, `lookup_var_type`, `lookup_var_struct_name`

3. **验证类型匹配**:
   - 使用 `LLVMGetTypeKind` 验证类型
   - 使用 `LLVMGetElementType` 获取指针指向的类型

4. **结构体名称查找**:
   - 先尝试 `lookup_var_struct_name`（从变量表）
   - 如果失败，尝试 `find_struct_name_from_type`（从类型映射表）

---

## ✅ 验证清单

继续工作时，可以使用以下清单：

- [ ] 编译是否成功？（`make`）
- [ ] 简单测试是否通过？（`./tests/run_programs.sh`）
- [ ] 问题 2 的调试输出是否显示正确的结构体名称？
- [ ] 问题 1 的崩溃位置是否已定位？
- [ ] 问题 3 的数组字面量代码生成是否使用正确的类型？
- [ ] 所有三个测试是否都能通过？

---

**最后更新**: 2024年（当前会话）
**当前状态**: 
- ✅ 数组字面量语法解析已完成（2024年当前会话）
- ✅ 数组字面量类型检查和代码生成已完成（2024年当前会话）
- ❌ 全局变量支持待实现（导致get_global_pointer失败）
- ⚠️ 结构体指针字段访问部分完成（代码已实现但测试失败）
- ❌ 指针解引用赋值段错误待调试
- ⚠️ sizeof_test仍然失败，需要进一步调试（可能涉及sizeof对数组类型的处理或其他问题）

**最新更新**（2024年当前会话）:
- 完成了数组字面量的完整实现（语法解析、类型检查、代码生成）
- 测试程序文件已整理到 `tests/programs/` 目录（61个.uya文件）
- 简单的数组字面量和结构体数组字面量测试通过

