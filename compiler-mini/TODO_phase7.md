# 阶段7：主程序

## 概述

翻译主程序（Main）模块，编译器入口点。

**优先级**：P0

**工作量估算**：2-3 小时

**依赖**：阶段0（准备工作 - str_utils.uya）、阶段1（Arena）、阶段2（AST）、阶段3（Lexer）、阶段4（Parser）、阶段5（Checker）、阶段6（CodeGen）

**原因**：编译器入口点。

---

## 任务列表

### 任务 7.1：阅读和理解 C99 代码

- [ ] 阅读 `src/main.c` - 理解主程序实现
- [ ] 理解编译器的工作流程：
  - [ ] 命令行参数解析
  - [ ] 文件读取
  - [ ] 词法分析
  - [ ] 语法分析
  - [ ] 类型检查
  - [ ] 代码生成
  - [ ] 输出处理
  - [ ] 错误处理

**参考**：代码量小（187行），主要是流程控制

---

### 任务 7.2：翻译文件 I/O 外部函数声明

**文件**：`uya-src/main.uya`

- [ ] 声明文件 I/O 外部函数：
  - [ ] `fopen` - 打开文件
  - [ ] `fclose` - 关闭文件
  - [ ] `fread` - 读取文件
  - [ ] `fwrite` - 写入文件
  - [ ] `fseek` - 文件定位
  - [ ] `ftell` - 获取文件位置
  - [ ] `feof` - 文件结束检查
  - [ ] `ferror` - 文件错误检查
  - [ ] 其他文件 I/O 函数

---

### 任务 7.3：翻译命令行参数处理函数

- [ ] 翻译命令行参数处理：
  - [ ] `parse_args` - 解析命令行参数
  - [ ] `print_usage` - 打印使用说明（使用 `fprintf`）
  - [ ] `print_version` - 打印版本信息（使用 `fprintf`）
  - [ ] 处理 `-o` 选项（输出文件）
  - [ ] 处理输入文件参数

**关键挑战**：
- 命令行参数处理：使用 `extern` 函数（`argc`, `argv`）
- 字符串操作：使用 `str_utils.uya` 中的函数

---

### 任务 7.4：翻译文件读取函数

- [ ] 翻译文件读取函数：
  - [ ] `read_file` - 读取源文件内容
  - [ ] `read_file_to_string` - 读取文件到字符串（使用 Arena 分配）
  - [ ] 错误处理（文件不存在、读取失败等）

**注意**：
- 使用 Arena 分配器分配文件内容缓冲区
- 使用 `extern` 函数进行文件 I/O

---

### 任务 7.5：翻译编译器主流程函数

- [ ] 翻译 `main` 函数：
  - [ ] 解析命令行参数
  - [ ] 读取源文件
  - [ ] 初始化 Arena 分配器
  - [ ] 初始化 Lexer
  - [ ] 初始化 Parser
  - [ ] 初始化 Checker
  - [ ] 初始化 CodeGen
  - [ ] 执行编译流程：
    1. 词法分析
    2. 语法分析
    3. 类型检查
    4. 代码生成
  - [ ] 输出结果（LLVM IR 或目标代码）
  - [ ] 清理资源
  - [ ] 错误处理和退出码

---

### 任务 7.6：翻译错误处理函数

- [ ] 翻译错误处理函数：
  - [ ] `report_compile_error` - 报告编译错误（使用 `fprintf`）
  - [ ] `report_file_error` - 报告文件错误
  - [ ] 设置适当的退出码

---

### 任务 7.7：使用字符串辅助函数

- [ ] 在 `main.uya` 中包含或引用 `str_utils.uya` 的声明
- [ ] 将所有字符串操作改为使用 `str_utils.uya` 中的函数
- [ ] 确保所有输出使用 `fprintf` 或 `printf`

---

### 任务 7.8：添加中文注释

- [ ] 为所有函数添加中文注释
- [ ] 为编译器主流程添加中文注释
- [ ] 为错误处理逻辑添加中文注释

---

### 任务 7.9：整合所有模块

- [ ] 确保所有模块可以正确整合：
  - [ ] `arena.uya`
  - [ ] `ast.uya`
  - [ ] `lexer.uya`
  - [ ] `parser.uya`
  - [ ] `checker.uya`
  - [ ] `codegen.uya`
  - [ ] `main.uya`
  - [ ] `str_utils.uya`
  - [ ] `llvm_api.uya`
- [ ] 处理模块之间的依赖关系
- [ ] 确保所有类型定义正确
- [ ] 确保所有函数声明正确

**注意**：
- Uya Mini 可能不支持模块系统，需要将所有模块合并到一个文件，或使用链接器
- 如果使用链接器，需要确保链接顺序正确

---

### 任务 7.10：验证功能

- [ ] 使用 C99 编译器编译完整的 Uya Mini 编译器
- [ ] 测试编译简单的 Uya Mini 程序：
  - [ ] 测试编译成功的情况
  - [ ] 测试编译失败的情况（语法错误、类型错误等）
  - [ ] 测试生成的二进制可以执行
- [ ] 验证生成的代码正确性

**参考**：`tests/programs/*.uya` - 现有的 Uya Mini 测试程序

---

## 完成标准

- [ ] `main.uya` 已创建，包含完整的主程序实现
- [ ] 所有文件 I/O 外部函数已声明
- [ ] 所有命令行参数处理函数已翻译
- [ ] 所有文件读取函数已翻译
- [ ] 编译器主流程函数已翻译
- [ ] 所有错误处理函数已翻译
- [ ] 使用 `str_utils.uya` 中的字符串函数
- [ ] 所有代码使用中文注释
- [ ] 所有模块可以正确整合
- [ ] 功能与 C99 版本完全一致
- [ ] 可以编译完整的 Uya Mini 编译器
- [ ] 可以编译和运行 Uya Mini 测试程序
- [ ] 已更新 `PROGRESS.md`，标记阶段7为完成

---

## 参考文档

- `src/main.c` - C99 版本的主程序实现
- `uya-src/str_utils.uya` - 字符串辅助函数模块
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范
- `BOOTSTRAP_PLAN.md` - 文件 I/O 和命令行参数处理策略
- `tests/programs/*.uya` - Uya Mini 测试程序

---

## 注意事项

1. **文件 I/O**：使用 `extern` 函数调用 C 标准库（`fopen`, `fread`, `fclose` 等）
2. **命令行参数**：使用 `extern` 函数（`argc`, `argv`）
3. **字符串处理**：必须使用 `str_utils.uya` 中的封装函数
4. **模块整合**：如果 Uya Mini 不支持模块系统，需要合并所有模块或使用链接器
5. **错误处理**：设置适当的退出码（0 表示成功，非0表示失败）

---

## C99 → Uya Mini 映射示例

```c
// C99
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <input> -o <output>\n", argv[0]);
        return 1;
    }
    
    FILE *file = fopen(argv[1], "r");
    if (!file) {
        fprintf(stderr, "Error: cannot open file %s\n", argv[1]);
        return 1;
    }
    
    // 读取文件内容
    // ...
    
    fclose(file);
    return 0;
}

// Uya Mini
extern fn fprintf(stream: *void, format: *byte, ...) i32;
extern fn fopen(filename: *byte, mode: *byte) *void;
extern fn fclose(stream: *void) i32;

fn main(argc: i32, argv: *byte) i32 {
    if argc < 2 {
        fprintf(stderr, "Usage: %s <input> -o <output>\n", argv[0]);
        return 1;
    }
    
    const file: *void = fopen(argv[1], "r");
    if file == null {
        fprintf(stderr, "Error: cannot open file %s\n", argv[1]);
        return 1;
    }
    
    // 读取文件内容
    // ...
    
    fclose(file);
    return 0;
}
```

---

## 后续工作

完成阶段7后，可以进行：

1. **自举验证**：
   - 使用 C99 编译器编译 Uya Mini 编译器（生成 `compiler-mini-uya-v1`）
   - 使用 `compiler-mini-uya-v1` 编译自身（生成 `compiler-mini-uya-v2`）
   - 比较 `v1` 和 `v2` 的功能等价性

2. **集成测试**：
   - 使用 Uya Mini 编译器编译所有测试程序
   - 验证生成的二进制正确性

3. **性能优化**：
   - 优化翻译后的 Uya Mini 编译器性能
   - 代码清理和重构

