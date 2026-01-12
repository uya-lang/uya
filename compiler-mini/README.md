# Uya Mini 编译器

Uya Mini 是 Uya 语言的最小子集编译器，设计目标是能够编译自身，实现编译器的自举。

## 项目状态

✅ **核心功能已完成** - 当前进度：阶段1-9已完成（编译器实现完成）

详细进度请参考 [PROGRESS.md](PROGRESS.md)

**已完成模块**：
- ✅ Arena 分配器
- ✅ AST 数据结构
- ✅ 词法分析器（Lexer）
- ✅ 语法分析器（Parser）
- ✅ 类型检查器（Checker）
- ✅ 代码生成器（CodeGen）
- ✅ 主程序（Main）
- ✅ 测试和验证

## 核心特性

- **最小子集**：仅包含编译自身所需的最少功能
- **无堆分配**：编译器自身代码不使用堆分配，使用 Arena 分配器
- **结构体支持**：支持结构体定义、实例化和字段访问
- **外部函数支持（FFI）**：支持 `extern` 关键字声明外部 C 函数（基础类型参数）
- **LLVM C API**：使用 LLVM C API 直接从 AST 生成二进制代码
- **自举目标**：最终目标是用 Uya Mini 编译器编译自身

**当前实现状态**（基于源码分析）：
- ✅ **已实现**：基础类型（`i32`、`bool`、`void`）、结构体、控制流（`if`、`while`、`return`）、基本表达式、`extern` 函数（基础类型参数）
- ⏳ **规范已定义，编译器未实现**：指针类型（`&T`、`*T`）、数组类型（`[T: N]`）、`sizeof` 内置函数、`for` 循环、`break`/`continue`、取地址/解引用运算符、`null` 字面量、`byte` 类型

详细实现状态请参考 [TODO_uya_mini_extension.md](TODO_uya_mini_extension.md)

## 快速开始

### 构建

```bash
make build         # 构建编译器
make test          # 运行所有单元测试
make test-programs # 运行 Uya 测试程序（需要 LLVM 环境）
make clean         # 清理编译产物
```

### 编译 Uya 程序

```bash
# 编译 Uya 程序生成二进制文件
./compiler-mini program.uya -o program

# 运行编译后的程序
./program
```

### 依赖

- C99 编译器（GCC 或 Clang）
- LLVM 库（用于代码生成）

## 文档

- [语言规范](spec/UYA_MINI_SPEC.md) - Uya Mini 完整语言规范
- [规范扩展 TODO](TODO_uya_mini_extension.md) - Uya Mini 规范扩展任务（自举重构准备）
- [开发规则](.cursorrules) - 开发规则和规范
- [待办事项](TODO.md) - 实现任务索引
- [进度跟踪](PROGRESS.md) - 当前实现进度
- [上下文切换指南](CONTEXT_SWITCH.md) - 多上下文协作指南

## 项目结构

```
compiler-mini/
├── spec/                          # 语言规范
│   ├── UYA_MINI_SPEC.md          # 语言规范文档
│   └── examples/                  # 示例代码
├── src/                           # 源代码
│   ├── arena.h / arena.c          # Arena 分配器
│   ├── lexer.h / lexer.c          # 词法分析器
│   ├── parser.h / parser.c        # 语法分析器
│   ├── checker.h / checker.c      # 类型检查器
│   ├── codegen.h / codegen.c      # 代码生成器
│   ├── ast.h / ast.c              # AST 定义
│   └── main.c                     # 主程序
├── tests/                         # 测试用例
└── TODO_phase*.md                 # 分阶段待办事项
```

## 相关项目

- [Uya 语言规范](../uya.md) - Uya 语言完整规范
- [Uya 编译器](../compiler/) - Uya 完整编译器（C 实现）
- [Uya 编译器 Go 版本](../compiler-go/) - Uya 编译器 Go 迁移版本

## 许可证

（待添加）

## 版本信息

- **版本**：0.1.0（开发中）
- **创建日期**：2026-01-11
- **目标**：实现 Uya Mini 编译器的自举
