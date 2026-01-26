# Uya Mini 编译器源代码编译

本目录包含 Uya Mini 编译器的 Uya 源代码，这些代码最终将用于编译器的自举。

## 文件列表

- `arena.uya` - Arena 分配器模块
- `str_utils.uya` - 字符串工具函数
- `extern_decls.uya` - 外部函数声明（C 标准库函数）
- `llvm_api.uya` - LLVM C API 外部函数声明
- `ast.uya` - AST（抽象语法树）定义
- `lexer.uya` - 词法分析器模块
- `parser.uya` - 语法分析器模块
- `checker.uya` - 类型检查器模块
- `codegen.uya` - 代码生成器模块
- `main.uya` - 主程序模块（编译器入口点）

## 编译

### 快速开始

使用 `compile.sh` 脚本编译所有文件：

```bash
# 基本编译（使用默认设置）
./compile.sh

# 详细输出模式
./compile.sh -v

# 指定输出目录和文件名
./compile.sh -o /tmp/my_compiler -n my_compiler

# 清理后重新编译
./compile.sh -c
```

### 脚本选项

- `-h, --help` - 显示帮助信息
- `-v, --verbose` - 详细输出模式
- `-d, --debug` - 调试模式（保留中间文件）
- `-o, --output DIR` - 指定输出目录
- `-n, --name NAME` - 指定输出文件名
- `-c, --clean` - 清理输出目录后再编译
- `--compiler PATH` - 指定编译器路径（默认使用 `../build/compiler-mini`）

### 手动编译

如果不使用脚本，也可以直接使用 C 版本的编译器：

```bash
# 从 compiler-mini 目录运行
cd ..

# 编译所有 uya-src 文件
./build/compiler-mini uya-src/*.uya -o build/uya-compiler/compiler

# 或者指定文件顺序（按依赖关系）
./build/compiler-mini \
    uya-src/arena.uya \
    uya-src/str_utils.uya \
    uya-src/extern_decls.uya \
    uya-src/llvm_api.uya \
    uya-src/ast.uya \
    uya-src/lexer.uya \
    uya-src/parser.uya \
    uya-src/checker.uya \
    uya-src/codegen.uya \
    uya-src/main.uya \
    -o build/uya-compiler/compiler
```

## 依赖关系

文件之间的依赖关系：

```
arena.uya (基础，无依赖)
  ├─> str_utils.uya
  ├─> extern_decls.uya (仅 extern 声明)
  ├─> llvm_api.uya (仅 extern 声明)
  └─> ast.uya
       ├─> lexer.uya
       │    └─> parser.uya
       │         └─> checker.uya
       │              └─> codegen.uya
       └─> main.uya (主程序，依赖所有模块)
```

## 编译输出

编译成功后，会在输出目录生成目标文件（`.o` 文件）。如果要生成可执行文件，需要使用链接器链接：

```bash
# 链接为目标文件
gcc -no-pie build/uya-compiler/compiler.o -o build/uya-compiler/compiler.exe

# 如果需要链接外部库（如 LLVM），添加相应选项
gcc -no-pie build/uya-compiler/compiler.o \
    -L/usr/lib/llvm-17/lib -lLLVM-17 \
    -o build/uya-compiler/compiler.exe
```

## 注意事项

1. **编译器要求**：需要使用已构建的 C 版本编译器（`../build/compiler-mini`）
2. **文件顺序**：虽然编译器支持任意顺序的多文件编译，但建议按照依赖关系顺序排列文件
3. **类型检查**：编译器会检查跨文件的符号引用和类型匹配
4. **输出格式**：默认输出为目标文件（`.o`），需要使用链接器生成可执行文件

## 故障排除

### 编译器不存在

如果提示编译器不存在，请先构建 C 版本编译器：

```bash
cd ..
make build
```

### 编译错误

如果遇到编译错误，可以：

1. 使用 `-v` 选项查看详细输出
2. 使用 `-d` 选项保留中间文件以便调试
3. 检查文件是否完整（是否有语法错误）

### 类型检查错误

如果遇到类型检查错误，检查：

1. 跨文件的函数声明是否一致
2. 结构体定义是否完整
3. `extern` 函数声明是否正确

## 自举进度

当前状态：
- ✅ 词法分析阶段：通过
- ✅ 语法分析阶段：通过
- ✅ AST 合并阶段：通过
- ✅ 类型检查阶段：通过（已修复所有类型检查错误）
- ⚠️ 代码生成阶段：进行中（有段错误需要修复）

## 参考

- [Uya Mini 规范](../spec/UYA_MINI_SPEC.md) - 完整语言规范
- [自举计划](../BOOTSTRAP_PLAN.md) - 自举实现计划



