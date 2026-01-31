# Uya v0.1.0 版本说明

**发布日期**：2026-01-31

本版本为 Uya 项目的首个正式发布版本，以 **Uya Mini 编译器** 为核心：实现 Uya 语言最小子集，并完成**自举**（编译器能编译自身，且与 C 编译器生成的 C 代码一致）。

---

## 核心亮点

### 自举达成

- **自举编译**：使用 C 编写的编译器将 Uya 源码（`uya-src/`）编译为 C 代码，再链接为可执行文件；该可执行文件（自举编译器）能再次编译同一套 Uya 源码。
- **输出一致**：自举编译器生成的 C 文件与 C 编译器生成的 C 文件**逐字节一致**，可通过 `./uya-src/compile.sh --c99 -b` 进行自举对比验证。
- **意义**：证明 Uya Mini 语言及其编译器实现正确、可自我维持，为后续扩展打下基础。

### Uya Mini 语言

Uya Mini 是 Uya 语言的**最小可自举子集**，本版本包含：

- **类型系统**：基础类型（`i32`、`bool`、`byte`、`void`）、数组 `[T: N]`、指针 `&T` / `*T`（FFI）、结构体、枚举。
- **控制流**：`if` / `else`、`while`、`for`（含数组遍历）、`break` / `continue`。
- **结构体与枚举**：定义、实例化、字段访问、枚举变体与比较、`sizeof` / `alignof`。
- **FFI**：`extern` 声明 C 函数，`as` 显式转换（如 `&T as *T`），与 C 互操作。
- **其它**：`const` / `var`、多文件编译（最多 64 个文件）、无堆分配（使用 Arena）。

### 编译器架构

- **双后端**：
  - **LLVM 后端**：由 AST 经 LLVM C API 生成原生二进制。
  - **C99 后端**：生成符合 ISO C99 的源代码，仅需 gcc/clang，不依赖 LLVM。
- **前端统一**：词法、语法、类型检查与两套后端共用，保证语义一致。
- **实现语言**：当前宿主实现为 C99（`compiler-mini/src/`）；自举实现为 Uya Mini（`compiler-mini/uya-src/`）。
- **C 实现维护**：C 版编译器（`compiler-mini/src/`）将维护至 Uya 版编译器（`uya-src/`）完整实现。在此之前，C 版为唯一 bootstrap 与自举验证参考；新特性需在 C 与 Uya 两套实现中同步，以保证 `--c99 -b` 自举对比有效。

---

## 主要功能

| 功能           | 说明 |
|----------------|------|
| 词法分析       | 完整 Uya Mini 词法，支持注释、字符串、数字、标识符与关键字。 |
| 语法分析       | 递归下降解析，输出统一 AST。 |
| 类型检查       | 符号表、函数表、跨文件引用检查。 |
| C99 代码生成   | 结构体/枚举/表达式/语句/函数/全局，生成可读 C99。 |
| LLVM 代码生成  | 直接生成目标代码，可执行。 |
| 多文件编译     | 多 `.uya` 一次传入，AST 合并后统一检查与代码生成。 |
| 自举脚本       | `uya-src/compile.sh` 支持 `--c99`、`-e`（可执行文件）、`-b`（自举对比）。 |

---

## 目录与使用

### 构建与测试（在 `compiler-mini/` 下）

```bash
make build          # 构建 C 版编译器
make test           # 单元测试
make test-c99       # C99 后端测试
make test-programs  # Uya 测试程序（需 LLVM）
```

### 使用 C 版编译器编译 Uya 程序

```bash
# 单文件 → C99
./build/compiler-mini program.uya -o program.c --c99
gcc --std=c99 -o program program.c

# 多文件
./build/compiler-mini a.uya b.uya c.uya -o out.c --c99
```

### 自举：用 Uya 源码编译出“用 Uya 写的编译器”

```bash
cd compiler-mini/uya-src
./compile.sh --c99 -e    # 生成 C 代码并链接为可执行文件
./compile.sh --c99 -b    # 同上，并做自举对比（两次 C 输出一致）
```

---

## 已知限制与后续方向

- **语言范围**：当前仅实现 Uya Mini 子集，泛型、接口、错误联合、并发等见顶层 `uya.md` 规范，尚未在本编译器中实现。
- **依赖**：LLVM 后端需安装 LLVM（如 17）；C99 后端仅需 gcc/clang。
- **自举**：自举使用 32MB Arena；若遇解析失败，可检查 Arena 或查看 parser 详细错误（文件:行:列 + 意外 token）。

后续计划：在稳定 Mini 与自举的基础上，逐步扩展语言特性与后端能力。

---

## 致谢

感谢所有参与 Uya 语言设计与 Uya Mini 实现、测试与文档工作的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.1.0  
- **仓库**：<https://github.com/uya-lang/uya>  
- **许可**：MIT（见 [LICENSE](LICENSE)）
