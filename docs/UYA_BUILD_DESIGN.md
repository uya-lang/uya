# Uya Build 命令设计文档

> **实现状态（2026-10-19 核对，v0.10.4）**：本设计已落地。`./bin/uya build hello.uya` 实测产出
> `a.out`（C 中间产物落在 `.uyacache`），`-o app` 产出可执行文件，`-o app.c` 只产出 C 源码。
> 与设计期写法的差异：链接不是编译器内嵌 `system("gcc ...")`，而是由
> `src/driver/toolchain.uya` 的 `link_with_toolchain()` 驱动宿主工具链（split-C 时走
> `make -C <split-dir> -j`）；`--nostdlib` 的独立链接路径仅支持 Linux x86_64。
> 下文保留设计期原文，命令语义以现状为准。

## 需求概述

`uya build` 命令应直接运行 gcc 编译出二进制文件，行为类似 gcc：

1. **无 `-o` 选项**：默认输出 `a.out` 二进制文件
2. **`-o <binary>`**：输出指定的二进制文件
3. **`-o <name>.c`**：输出 C 源代码文件（不调用 gcc 链接）

## 命令行为

### 1. 默认行为（无 -o）

```bash
uya build main.uya
# 输出: a.out（可执行文件）
# 流程: main.uya → /tmp/uya_xxx.c → a.out
```

### 2. 指定二进制输出

```bash
uya build main.uya -o myapp
# 输出: myapp（可执行文件）
# 流程: main.uya → /tmp/uya_xxx.c → myapp
```

### 3. 指定 C 源代码输出

```bash
uya build main.uya -o main.c
# 输出: main.c（C 源代码）
# 流程: main.uya → main.c（不调用 gcc 链接）
```

### 4. 使用 --nostdlib

```bash
uya build main.uya --nostdlib
# 输出: a.out（静态链接，零依赖）
# 流程: main.uya → /tmp/uya_xxx.c（含 _start）→ a.out
```

## 实现方案

### 修改 main.uya 中的 parse_args 函数

1. **移除 build 命令必须指定 -o 的限制**
   - 删除 `if command[0] == CommandType.COMMAND_BUILD && output_file_index[0] < 0` 的错误处理

2. **添加默认输出逻辑**
   - build 命令无 -o 时：
     - 输出 C 文件到临时目录 `/tmp/uya_<pid>.c`
     - 调用 gcc 链接为 `a.out`

3. **检测输出类型**
   - 如果 `-o` 参数以 `.c` 结尾：只生成 C 代码
   - 否则：生成 C 代码后调用 gcc 链接

### 编译流程

```
输入文件 (.uya)
    ↓
[词法分析 → 语法分析 → 类型检查 → C99 代码生成]
    ↓
C 源代码 (.c)
    ↓
[检测输出类型]
    ├─ 以 .c 结尾 → 直接输出 C 文件（结束）
    └─ 其他 → 调用 gcc 链接 → 可执行文件
```

### 宿主工具链链接

实际调用形态（`src/driver/toolchain.uya`）：

```bash
# 单文件路径：一条命令编译 + 链接（CFLAGS 默认已含 -O2；含 -O2/-O3/-Os 时自动追加
# -fno-inline-small-functions，规避宿主 GCC 对部分生成代码的错误小函数内联）
cc -std=c99 -O2 -fno-builtin -fno-inline-small-functions uya_generated.c -o a.out

# split-C 路径（默认）：Makefile + 并行编译，hosted 模式的最终链接带 -lm
make -C .uyacache -j$UYA_GCC_JOBS UYA_OUT=a.out

# --nostdlib 模式（仅 Linux x86_64）：生成 C 内含 _start
cc -std=c99 -O2 -fno-builtin -fno-stack-protector -no-pie -nostdlib -static \
   "$CRTI" uya.o "$CRTN" -lgcc -o a.out
```

含 `@c_import` 时：先编译导入的 C 到 object，再与主 TU 一起链接；`-o app.c` 时额外写出
`app.cimports.sh` sidecar。

## 代码修改位置

### main.uya

1. **`parse_args()`**：不再要求 `build` 必须带 `-o`；无 `-o` 时标记为「自动输出」并把后端切到 C99。

2. **`export fn main()`**：`build` 且输出不是 `.c` 时调用 `link_with_toolchain(...)`；否则停在只生成 C。

3. **`is_c_output()`**：按扩展名判定「只生成 C」还是「生成并链接」。

### 相关函数（现状）

```uya
// 输出类型判定（src/main.uya）
fn is_c_output(output_path: &byte) i32 {
    if output_path == null { return 0; }
    const len: usize = strlen(output_path as *byte);
    if len < 2 { return 0; }
    return output_path[len - 2] == 46 as byte && output_path[len - 1] == 99 as byte;
}

// 实际链接入口（src/driver/toolchain.uya:929）
fn link_with_toolchain(c_file: &byte, output: &byte, is_nostdlib: i32, plan: &CImportPlan) i32
```

`link_with_toolchain()` 内部负责：单文件 `cc` 链接、split-C 的 `make -C <dir> -j`、
`@c_import` object 的编译与顺序、以及 `--nostdlib` 的 CRT 链接。

## 测试用例

```bash
# 测试 1: 默认输出 a.out
uya build hello.uya
./a.out
rm a.out

# 测试 2: 指定二进制输出
uya build hello.uya -o hello
./hello
rm hello

# 测试 3: 输出 C 源代码
uya build hello.uya -o hello.c
gcc -std=c99 hello.c -o hello
./hello

# 测试 4: --nostdlib 模式（仅 Linux x86_64）
uya build hello.uya --nostdlib
./a.out
```

## 兼容性说明

- `uya build file.uya -o file.c` 行为不变（只生成 C）
- 无 `-o` 时默认输出 `a.out`，C 中间产物在 `.uyacache`
- `uya run` 和 `uya test` 命令行为不变
- `-o *.c` 且程序含 `@c_import` 时，额外写出 `<name>.cimports.sh` sidecar

## 实现优先级（均已落地）

1. ~~移除 build 命令必须指定 -o 的限制~~ ✅
2. ~~实现默认输出 a.out 的逻辑~~ ✅
3. ~~实现调用宿主工具链链接的功能~~ ✅（`link_with_toolchain`）
4. ~~处理 --nostdlib 模式~~ ✅（限 Linux x86_64）