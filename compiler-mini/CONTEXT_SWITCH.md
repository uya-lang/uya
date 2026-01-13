# 上下文切换指南

当 Cursor 上下文满了，需要在新会话中继续工作时，请按照以下步骤操作：

## 🔄 快速恢复步骤

### 1. 新会话开始时

打开 Cursor 后，立即执行以下操作：

1. **阅读当前进度**
   ```bash
   # 查看进度文档
   cat compiler-mini/PROGRESS.md
   ```

2. **查看待办任务**
   ```bash
   # 查看任务索引
   cat compiler-mini/TODO.md
   # 查看当前阶段的详细任务（例如阶段3）
   cat compiler-mini/TODO_phase3.md
   # 查看 Uya Mini 规范扩展任务（如果进行自举重构）
   cat compiler-mini/TODO_uya_mini_extension.md
   ```

3. **查看规则文件**
   ```bash
   # 确认开发规则
   cat compiler-mini/.cursorrules
   ```

4. **查看语言规范**
   ```bash
   # 确认语言规范（重要参考）
   cat compiler-mini/spec/UYA_MINI_SPEC.md
   ```

### 2. 确认当前状态

检查以下内容：

- ✅ 查看 `PROGRESS.md` 中的"已完成模块"部分
- ✅ 查看 `PROGRESS.md` 中的"下一步行动"
- ✅ 确认上次会话完成的工作状态
- ✅ 检查代码是否可以编译（如果可能）
- ✅ 确认语言规范了解（`spec/UYA_MINI_SPEC.md`）

### 3. 继续执行计划

根据 `PROGRESS.md` 中的"下一步行动"，继续实现：

1. **从标记的模块开始**
   - 不要重复已完成的工作
   - 按照依赖顺序实现（Arena → AST → Lexer → Parser → Checker → CodeGen → Main）

2. **遵循 TDD 开发流程**
   - **Red（红）**：先编写测试用例，运行测试确保失败
   - **Green（绿）**：实现最小代码使测试通过
   - **Refactor（重构）**：重构优化代码，保持测试通过
   - 添加中文注释
   - **不能简化功能**：必须完整实现，不能偷懒

3. **保持代码质量**
   - 所有代码使用中文注释
   - **函数 < 200 行，文件 < 1500 行**（严格限制）
   - 不使用堆分配（malloc/free）
   - 使用 Arena 分配器
   - 遵循 C99 标准
   - **使用枚举类型，不能用字面量代替枚举**（提高代码可维护性）

### 4. 完成模块后

立即更新进度：

1. **更新 PROGRESS.md**
   - 将完成的模块标记为 ✅
   - 更新"下一步行动"
   - 记录完成时间
   - 记录遇到的问题和解决方案

2. **更新对应的 TODO_phase*.md 或 TODO_bugfixes.md（可选）**
   - 标记已完成的任务项
   - 如果是 bug 修复，更新 `TODO_bugfixes.md`

3. **提交代码（如果使用 git）**
   ```bash
   git add compiler-mini/
   git commit -m "feat: 完成 [模块名称] 实现"
   # 或
   git commit -m "fix: 修复 [问题描述]"
   ```

## 📋 检查清单

在新会话开始前，确认：

- [ ] 已阅读 `PROGRESS.md`
- [ ] 已阅读 `TODO.md`（了解任务索引）和对应的 `TODO_phase*.md`（了解详细任务）
- [ ] 如果进行自举重构，已阅读 `TODO_uya_mini_extension.md`（了解规范扩展任务）
- [ ] 已阅读 `.cursorrules`（了解开发规范）
- [ ] 已了解语言规范（`spec/UYA_MINI_SPEC.md`）
- [ ] 如果扩展规范，已了解完整 Uya 语言规范（`uya_ai_prompt.md`）
- [ ] 了解当前进度状态
- [ ] 知道下一步要做什么
- [ ] 确认依赖的模块已完成

在模块完成后，确认：

- [ ] **遵循了 TDD 流程**（先写测试，再实现）
- [ ] **功能完整实现**（不能简化，不能偷懒）
- [ ] **所有函数 < 200 行，文件 < 1500 行**
- [ ] 所有代码使用中文注释
- [ ] 无堆分配（不使用 malloc/free）
- [ ] 使用 Arena 分配器
- [ ] **使用枚举类型，不能用字面量代替枚举**（提高代码可维护性）
- [ ] **所有测试通过**
- [ ] 代码可以编译（或至少语法正确）
- [ ] 已更新 `PROGRESS.md`
- [ ] 已提交代码（如果使用版本控制）

## 🔍 关键文件说明

| 文件 | 用途 | 何时查看 |
|------|------|----------|
| `PROGRESS.md` | 当前进度和状态 | 每次新会话开始时 |
| `TODO.md` | 任务索引 | 了解各阶段任务分布时 |
| `TODO_phase*.md` | 各阶段详细任务列表 | 需要了解具体任务时 |
| `TODO_bugfixes.md` | Bug 修复待办事项 | 修复测试失败问题时 |
| `TODO_uya_mini_extension.md` | Uya Mini 规范扩展任务 | 进行自举重构（阶段10）时 |
| `.cursorrules` | 开发规则和规范 | 新会话开始时确认规则 |
| `spec/UYA_MINI_SPEC.md` | 语言规范（重要！） | 实现功能前必须参考 |
| `uya_ai_prompt.md` | 完整 Uya 语言规范 | 扩展 Uya Mini 规范时参考 |
| `.cursor/plans/*.plan.md` | 原始实现计划 | 需要了解整体架构时 |

## 💡 提示

1. **从 PROGRESS.md 开始**：这是最重要的文件，包含当前状态
2. **参考语言规范**：实现前必须查看 `spec/UYA_MINI_SPEC.md`
3. **扩展规范时参考完整 Uya**：如果进行自举重构（阶段10），扩展 Uya Mini 规范时必须参考 `uya_ai_prompt.md` 确保语法一致
4. **按顺序实现**：不要跳过依赖的模块
5. **小步提交**：完成一个模块就更新进度，不要等到全部完成
6. **保持一致性**：遵循已有的代码风格和结构
7. **中文注释**：所有代码必须使用中文注释
8. **无堆分配**：严格遵守无堆分配约束
9. **使用枚举**：使用枚举类型代替字面量，提高代码可维护性

## 🚨 常见问题

**Q: 如何知道从哪里继续？**
A: 查看 `PROGRESS.md` 中的"下一步行动"部分

**Q: 如果上次会话没有完成模块怎么办？**
A: 查看代码状态，如果基本功能已实现但测试未完成，继续完成测试和优化

**Q: 如何确认代码质量？**
A: 检查代码是否使用中文注释，是否遵循 TDD 流程，函数是否 < 200 行，文件是否 < 1500 行，是否使用堆分配，是否使用 Arena 分配器，是否使用枚举类型而不是字面量，所有测试是否通过，是否可以编译

**Q: 为什么不能用字面量代替枚举？**
A: 使用枚举类型可以提高代码的可维护性和可读性：
- **类型安全**：枚举提供类型检查，避免使用错误的数值
- **可读性**：枚举名称比数字更有意义，代码更容易理解
- **可维护性**：如果需要修改值，只需在枚举定义处修改，而不是在整个代码库中搜索字面量
- **自文档化**：枚举名称本身就是文档，说明每个值的含义

**错误示例**（使用字面量）：
```c
// ❌ 不好：使用数字字面量
if (token_type == 1) {  // 1 是什么意思？
    // ...
}

// ✅ 正确：使用枚举
if (token_type == TOKEN_IDENTIFIER) {  // 清晰明确
    // ...
}
```

**注意**：对于简单的单字符或短字符串（如运算符 "+"、"-"），可以使用字符串字面量，因为它们本身就是自解释的。但对于类型、状态、选项等，必须使用枚举。

**Q: 如果上下文限制无法完成一个模块怎么办？**
A: 可以分部实现，但必须：
- 在 PROGRESS.md 中详细记录已完成的部分和待完成的部分
- 确保已实现的代码可以编译和测试
- 下次会话从 PROGRESS.md 标记的位置继续
- **不能因为上下文限制就简化功能，必须完整实现**

**Q: 如何拆分大文件？**
A: 如果文件超过 1500 行，必须拆分为多个文件。例如：
- `parser.c` → `parser.c`（核心）+ `parser_expression.c` + `parser_statement.c`
- `codegen.c` → `codegen.c`（核心）+ `codegen_expr.c` + `codegen_stmt.c`

**Q: 可以并行实现多个模块吗？**
A: 不建议，因为模块之间有依赖关系。按照依赖顺序实现更安全。

**Q: LLVM API 调用需要注意什么？**
A: LLVM API 内部会使用堆分配，这是允许的。但编译器自身代码不能使用堆分配。

**Q: 结构体支持如何实现？**
A: 参考 `spec/UYA_MINI_SPEC.md` 中的结构体语法和 LLVM 结构体处理说明。

**Q: 如何验证编译器生成的二进制是否正确？**
A: 创建 Uya 测试程序，编译后运行并验证输出结果。参见下面的"Uya 测试程序验证"章节。

## 🧪 Uya 测试程序验证

在编译器实现完成后（特别是阶段7：代码生成器和阶段8：主程序完成后），需要创建 Uya 测试程序来验证编译器生成二进制的正确性。

### 测试程序目录结构

建议在 `tests/` 目录下创建 `programs/` 子目录，存放 Uya 测试程序：

```
compiler-mini/
├── tests/
│   ├── test_arena.c          # 单元测试
│   ├── test_ast.c
│   └── programs/             # Uya 测试程序目录
│       ├── simple_function.uya    # 简单函数测试
│       ├── arithmetic.uya         # 算术运算测试
│       ├── control_flow.uya       # 控制流测试
│       ├── struct_test.uya        # 结构体测试
│       └── expected_output.txt    # 预期输出（可选）
```

### 创建测试程序的步骤

1. **编写 Uya 测试程序**
   - 使用 Uya Mini 语法编写测试程序
   - 程序必须包含 `fn main() i32` 函数
   - 使用 `return` 语句返回退出码（0 表示成功，非0表示失败）
   - 参考 `spec/examples/` 目录下的示例程序

2. **编译测试程序**
   ```bash
   # 使用编译器编译 Uya 程序
   ./compiler-mini tests/programs/simple_function.uya -o tests/programs/simple_function
   ```

3. **运行并验证输出**
   ```bash
   # 运行编译后的二进制文件
   ./tests/programs/simple_function
   
   # 检查退出码（使用 echo $? 在 bash 中）
   echo $?
   # 应该输出 0（表示程序成功执行）
   ```

4. **验证测试程序正确性**
   - 检查程序是否正常编译（无错误）
   - 检查生成的二进制是否可以执行
   - 检查程序退出码是否符合预期
   - 如果程序有输出，验证输出内容是否正确

### 测试程序示例

#### 简单函数测试（simple_function.uya）

```uya
fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn main() i32 {
    const result: i32 = add(10, 20);
    if result == 30 {
        return 0;  // 测试通过
    }
    return 1;  // 测试失败
}
```

#### 算术运算测试（arithmetic.uya）

```uya
fn main() i32 {
    const a: i32 = 10;
    const b: i32 = 5;
    
    var sum: i32 = a + b;
    var diff: i32 = a - b;
    var prod: i32 = a * b;
    var quot: i32 = a / b;
    var mod: i32 = a % b;
    
    if sum == 15 && diff == 5 && prod == 50 && quot == 2 && mod == 0 {
        return 0;
    }
    return 1;
}
```

#### 控制流测试（control_flow.uya）

```uya
fn main() i32 {
    var x: i32 = 0;
    
    if true {
        x = 10;
    } else {
        x = 20;
    }
    
    var count: i32 = 0;
    while count < 5 {
        count = count + 1;
    }
    
    if x == 10 && count == 5 {
        return 0;
    }
    return 1;
}
```

#### 结构体测试（struct_test.uya）

```uya
struct Point {
    x: i32,
    y: i32,
}

fn main() i32 {
    const p: Point = Point{ x: 10, y: 20 };
    
    if p.x == 10 && p.y == 20 {
        return 0;
    }
    return 1;
}
```

### 自动化测试脚本

可以创建测试脚本自动运行所有测试程序：

```bash
#!/bin/bash
# tests/run_programs.sh

COMPILER="./compiler-mini"
TEST_DIR="tests/programs"
PASSED=0
FAILED=0

for uya_file in "$TEST_DIR"/*.uya; do
    if [ -f "$uya_file" ]; then
        base_name=$(basename "$uya_file" .uya)
        echo "测试: $base_name"
        
        # 编译
        $COMPILER "$uya_file" -o "$TEST_DIR/$base_name"
        if [ $? -ne 0 ]; then
            echo "  ❌ 编译失败"
            FAILED=$((FAILED + 1))
            continue
        fi
        
        # 运行
        "$TEST_DIR/$base_name"
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "  ✓ 测试通过"
            PASSED=$((PASSED + 1))
        else
            echo "  ❌ 测试失败（退出码: $exit_code）"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "总计: $((PASSED + FAILED)) 个测试"
echo "通过: $PASSED"
echo "失败: $FAILED"

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
```

### 测试程序编写注意事项

1. **每个测试程序应该测试一个特定功能**
   - 不要在一个程序中测试多个不相关的功能
   - 保持测试程序简单易懂

2. **使用返回值表示测试结果**
   - 返回 0 表示测试通过
   - 返回非0值表示测试失败
   - 可以使用不同的退出码表示不同的失败原因

3. **测试程序应该覆盖所有语言特性**
   - **基础类型**：`i32`、`bool`、`byte`、`void`
   - **数组类型**：固定大小数组（`[T: N]`）
   - **指针类型**：`&T`（普通指针）和 `*T`（FFI 指针）
   - **结构体类型**：结构体定义、实例化和字段访问
   - **变量声明**：`const` 和 `var`
   - **函数声明和调用**：普通函数和外部函数（`extern`，支持 FFI 指针类型 `*T`）
   - **控制流**：`if`、`while`、`for`（数组遍历）、`break`、`continue`
   - **表达式运算**：算术、逻辑、比较运算、函数调用、结构体字段访问、数组访问
   - **类型转换**：`as` 关键字进行显式类型转换
   - **内置函数**：`sizeof`（类型大小查询）
   - **字符串字面量**：类型为 `*byte`，仅可用于 `extern` 函数参数

4. **参考语言规范**
   - 所有测试程序必须符合 `spec/UYA_MINI_SPEC.md` 中的语法规范
   - 参考 `spec/examples/` 目录下的示例程序

5. **测试程序命名规范**
   - 使用描述性的文件名
   - 使用小写字母和下划线
   - 例如：`simple_function.uya`, `struct_test.uya`

### 集成到 Makefile

可以在 Makefile 中添加测试程序编译和运行的规则：

```makefile
# 测试程序目录
PROGRAMS_DIR = tests/programs
PROGRAMS = $(wildcard $(PROGRAMS_DIR)/*.uya)
PROGRAM_BINARIES = $(PROGRAMS:.uya=)

# 编译所有测试程序
compile-programs: $(PROGRAM_BINARIES)

$(PROGRAM_BINARIES): %: %.uya
	$(COMPILER) $< -o $@

# 运行所有测试程序
test-programs: compile-programs
	@bash tests/run_programs.sh

.PHONY: compile-programs test-programs
```

## 💻 Windows/WSL 开发说明

### 在 Windows 下使用 WSL

如果开发环境是 Windows，可以使用 WSL（Windows Subsystem for Linux）来执行命令行操作：

```bash
# 在 Windows 的 Cursor 或终端中，使用 wsl 命令执行 Linux 命令

# 1. 查看当前进度
wsl bash -c "cd /mnt/c/Users/27027/uya/compiler-mini && cat PROGRESS.md"

# 2. Git 操作（推荐在 WSL 中执行）
wsl bash -c "cd /mnt/c/Users/27027/uya && git status compiler-mini/"
wsl bash -c "cd /mnt/c/Users/27027/uya && git add compiler-mini/"
wsl bash -c "cd /mnt/c/Users/27027/uya && git commit -m 'feat: 完成 [模块名称] 实现'"

# 3. 编译和测试（如果使用 make）
wsl bash -c "cd /mnt/c/Users/27027/uya/compiler-mini && make test_parser"

# 4. 路径映射说明
# Windows 路径: C:\Users\27027\uya\compiler-mini
# WSL 路径:     /mnt/c/Users/27027/uya/compiler-mini
```

### Git 提交示例

```bash
# 查看修改状态
wsl bash -c "cd /mnt/c/Users/27027/uya && git status compiler-mini/"

# 添加文件
wsl bash -c "cd /mnt/c/Users/27027/uya && git add compiler-mini/src/ compiler-mini/tests/ compiler-mini/PROGRESS.md"

# 提交代码
wsl bash -c "cd /mnt/c/Users/27027/uya && git commit -m 'feat: 完成阶段5会话3 - 语句解析实现'"
```

## 📝 示例：新会话开始

```bash
# 1. 查看当前进度
cat compiler-mini/PROGRESS.md

# 输出示例：
# 下一步行动: 继续实现阶段2：Arena 分配器，实现 arena_alloc 函数

# 2. 查看具体任务
cat compiler-mini/TODO_phase2.md  # 查看阶段2的详细任务

# 3. 查看语言规范（如果需要）
grep -A 10 "结构体" compiler-mini/spec/UYA_MINI_SPEC.md

# 4. 开始实现（根据 PROGRESS.md 的指示）
# 实现 arena.c 中的 arena_alloc 函数...
```

## 📚 参考实现

如果需要参考现有编译器实现：

- `../compiler/src/` - 现有的 C 编译器实现（但需要注意：现有实现使用堆分配，需要改为 Arena 分配器）
- `../compiler/architecture.md` - 编译器架构说明

**注意**：参考现有实现时，需要：
- 移除所有 malloc/free 调用，改用 Arena 分配器
- 添加中文注释
- 简化功能（仅实现 Uya Mini 子集）
- 代码生成改为使用 LLVM C API

