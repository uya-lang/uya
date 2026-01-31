# Uya Mini 编译器

Uya Mini 是 Uya 语言的最小子集编译器，设计目标是能够编译自身，实现编译器的自举。

## 项目状态（v0.1.0）

✅ **核心功能已完成** - Uya Mini 规范已全部实现，编译器功能完整

✅ **自举已达成** - 用 Uya 编写的编译器可编译自身，且与 C 编译器生成的 C 文件完全一致（`./uya-src/compile.sh --c99 -b` 验证）。详见项目根目录 [RELEASE_v0.1.0.md](../RELEASE_v0.1.0.md)

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
- **多文件编译**：支持同时编译多个 `.uya` 文件，通过 AST 合并统一进行类型检查和代码生成
- **类型系统**：基础类型（`i32`、`bool`、`byte`、`void`）、数组类型（`[T: N]`）、指针类型（`&T`、`*T`）、结构体类型、枚举类型
- **控制流**：`if`、`while`、`for`（数组遍历）、`break`、`continue`
- **结构体支持**：支持结构体定义、实例化和字段访问
- **枚举支持**：支持枚举定义、枚举值访问、显式赋值、自动递增、混合赋值、枚举比较、枚举 sizeof
- **外部函数支持（FFI）**：支持 `extern` 关键字声明外部 C 函数，支持基础类型和 FFI 指针类型（`*T`）参数，支持 `&T as *T` 类型转换语法将普通指针转换为 FFI 指针
- **内置函数**：`sizeof`（类型大小查询）
- **类型转换**：支持 `as` 关键字进行显式类型转换
- **双后端架构**：
  - **LLVM 后端**：使用 LLVM C API 直接从 AST 生成二进制代码
  - **C99 后端**：生成标准 C99 源代码，不依赖 LLVM 库
- **自举目标**：最终目标是用 Uya Mini 编译器编译自身

**当前实现状态**：
- ✅ **Uya Mini 规范已全部实现** - 所有语言特性已在编译器中实现
- ✅ **编译器功能完整** - 可以编译所有 Uya Mini 程序
- ✅ **自举已达成** - Uya 版编译器可编译自身，C 输出与 C 版一致

**维护策略**：C 版编译器（`src/`）将维护至 Uya 版编译器（`uya-src/`）完整实现。在此之前，C 版为唯一 bootstrap 与自举验证参考；新特性在 C 与 Uya 两套实现中同步维护，以保证 `./uya-src/compile.sh --c99 -b` 自举对比有效。

## 快速开始

### 构建

```bash
make build         # 构建编译器
make test          # 运行所有单元测试
make test-programs # 运行 Uya 测试程序（LLVM 后端，需要 LLVM 环境）
make test-c99      # 运行 C99 后端测试（不需要 LLVM）
make c99-backend   # 使用 C99 后端编译示例程序
make clean         # 清理编译产物
```

### 编译 Uya 程序

#### 使用 LLVM 后端（默认）

```bash
# 单文件编译
./build/compiler-mini program.uya -o program

# 多文件编译（支持同时编译多个文件）
./build/compiler-mini file1.uya file2.uya file3.uya -o output

# 运行编译后的程序
./program
```

#### 使用 C99 后端

```bash
# 生成 C99 源代码
./build/compiler-mini program.uya -o program.c --c99

# 使用 gcc 编译生成的 C99 代码
gcc --std=c99 -o program program.c

# 运行程序
./program

# 或者使用 --exec 选项自动编译和运行
./build/compiler-mini program.uya -o program.c --c99 --exec
```

**C99 后端特性**：
- ✅ 支持所有 Uya Mini 语言特性
- ✅ 生成标准 C99 代码，符合 ISO/IEC 9899:1999 标准
- ✅ 不依赖 LLVM 库，只需要标准 C 编译器（gcc/clang）
- ✅ 生成的代码可读性强，便于理解和调试
- ✅ 所有测试用例通过验证（100% 通过率）

**多文件编译说明**：
- 支持同时编译多个 `.uya` 文件
- 所有文件的声明会合并到一个程序中
- 支持跨文件引用（一个文件中可以使用另一个文件中定义的函数、结构体等）
- 类型检查器会检查跨文件的符号引用
- 最大支持 64 个输入文件

### 依赖

- C99 编译器（GCC 或 Clang）
- LLVM 库（用于 LLVM 后端代码生成，C99 后端不需要）

## 文档

- [语言规范](spec/UYA_MINI_SPEC.md) - Uya Mini 完整语言规范
- [v0.1.0 版本说明](../RELEASE_v0.1.0.md) - 自举达成与发布说明
- [开发规则](.cursorrules) - 开发规则和规范

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
│   ├── programs/                  # 测试程序
│   │   └── multifile/            # 多文件编译测试
│   └── run_programs.sh           # 测试运行脚本
└── examples/                      # 示例代码
    ├── c99_output/               # C99 后端示例
    └── compile_with_c99.sh       # C99 后端编译脚本
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
