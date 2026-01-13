# Uya Mini 编译器

Uya Mini 是 Uya 语言的最小子集编译器，设计目标是能够编译自身，实现编译器的自举。

## 项目状态

✅ **核心功能已完成** - Uya Mini 规范已全部实现，编译器功能完整

✅ **准备开始自举** - 可以开始将 C99 编译器翻译成 Uya Mini 版本

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
- **类型系统**：基础类型（`i32`、`bool`、`byte`、`void`）、数组类型（`[T: N]`）、指针类型（`&T`、`*T`）、结构体类型、枚举类型
- **控制流**：`if`、`while`、`for`（数组遍历）、`break`、`continue`
- **结构体支持**：支持结构体定义、实例化和字段访问
- **枚举支持**：支持枚举定义、枚举值访问、显式赋值、自动递增、混合赋值、枚举比较、枚举 sizeof
- **外部函数支持（FFI）**：支持 `extern` 关键字声明外部 C 函数，支持基础类型和 FFI 指针类型（`*T`）参数
- **内置函数**：`sizeof`（类型大小查询）
- **类型转换**：支持 `as` 关键字进行显式类型转换
- **LLVM C API**：使用 LLVM C API 直接从 AST 生成二进制代码
- **自举目标**：最终目标是用 Uya Mini 编译器编译自身

**当前实现状态**：
- ✅ **Uya Mini 规范已全部实现** - 所有语言特性已在编译器中实现
- ✅ **编译器功能完整** - 可以编译所有 Uya Mini 程序
- ✅ **准备开始自举** - 参考 [BOOTSTRAP_PLAN.md](BOOTSTRAP_PLAN.md) 了解自举实现计划

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
- [自举实现计划](BOOTSTRAP_PLAN.md) - 将 C99 编译器翻译成 Uya Mini 的详细计划
- [开发规则](.cursorrules) - 开发规则和规范
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
