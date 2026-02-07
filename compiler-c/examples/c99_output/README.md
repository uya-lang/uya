# C99 后端示例

本目录包含使用 Uya Mini 编译器的 C99 后端生成的示例代码。

## 文件说明

- `example.uya` - 简单的 Uya Mini 示例程序
- `example.c` - 由 C99 后端生成的 C99 源代码

## 使用方法

### 方法1：使用编译脚本

```bash
# 从 compiler-mini 目录运行
cd /path/to/compiler-mini
./examples/compile_with_c99.sh examples/c99_output/example.uya

# 只生成 C99 代码
./examples/compile_with_c99.sh examples/c99_output/example.uya -c

# 编译并运行
./examples/compile_with_c99.sh examples/c99_output/example.uya -r
```

### 方法2：手动编译

```bash
# 1. 生成 C99 代码
./build/compiler-mini examples/c99_output/example.uya -o example.c --c99

# 2. 使用 gcc 编译 C99 代码
gcc --std=c99 -o example example.c

# 3. 运行程序
./example
```

### 方法3：使用 Makefile

```bash
# 使用 C99 后端编译示例
make c99-backend

# 运行 C99 后端测试
make test-c99
```

## 生成的 C99 代码特点

- 符合 C99 标准
- 使用标准 C 类型（`int32_t`, `size_t`, `_Bool` 等）
- 包含必要的头文件（`<stdint.h>`, `<stddef.h>`, `<stdbool.h>` 等）
- 结构化的代码格式，包含注释
- 支持所有 Uya Mini 语言特性

## 查看生成的代码

生成的 C99 代码可以直接查看，了解 Uya Mini 如何映射到 C99：

```bash
cat examples/c99_output/example.c
```

## 更多示例

更多测试用例请参考 `tests/programs/` 目录，这些测试用例都可以使用 C99 后端编译：

```bash
# 运行所有 C99 后端测试
make test-c99

# 或使用测试脚本
./tests/run_programs.sh --c99
```

