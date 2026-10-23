# Uya build/check/run 与宿主工具链说明

**最后核对**：2026-10-19（v0.10.4）

## 概述

Uya 编译器支持 `build`、`check` 和 `run` 子命令。

- `check`：只执行到 lexer / parser / checker，不进入代码生成、链接或运行。
- `build` / `run`：在需要生成 C99 之后自动调用**宿主工具链**完成链接。

当前共享工具链模型已经统一为：

- `HOST_OS` / `HOST_ARCH`
- `TARGET_OS` / `TARGET_ARCH` / `TARGET_TRIPLE`
- `RUNTIME_MODE`
- `LINK_MODE`
- `TOOLCHAIN`
- `CC`
- `CC_DRIVER`
- `CC_TARGET_FLAGS`

默认仍可使用系统 `cc` / `clang` / `gcc`，但对于 Linux、macOS、Windows 与交叉编译统一入口，推荐优先使用 `zig cc`。

截至 2026-04-17，Darwin hosted 路线已经在 Linux 上通过 `zig cc` 实测产出 `arm64` 与 `x86_64` 两种 Mach-O 编译器二进制；当前文档里的 “支持” 指的是这层交叉产物已经成立，不等同于 “macOS 真机运行与测试已全部完成”。

截至 v0.10.4（2026-10-19），Windows 目标（`TARGET_OS=windows`）也已用 `zig cc` 打通自举：`@syscall` 统一汇聚到 `uya_windows_syscall`（Win32 API + Winsock）、控制台写路径按代码页转码、`long` 在 LLP64 下的指针截断问题已修。

## 使用方法

### 方式一：直接用 `bin/uya`（推荐）

`bin/uya` 已经自己完成「生成 C → 调宿主工具链链接」这一整条链路，不需要额外的包装脚本
（历史上的 `bin/uya-wrapper.sh` 已不在仓库中）：

```bash
# check 命令：仅做语法/类型检查
./bin/uya check input.uya

# build 命令：编译并链接为可执行文件
./bin/uya build input.uya -o app

# build 命令：只生成 C 代码（不链接）
./bin/uya build input.uya -o app.c --c99

# run 命令：编译、链接并运行
./bin/uya run input.uya -- arg1 arg2

# test 命令：编译测试并运行
./bin/uya test input.uya
```

如果程序里使用了 `@c_import`，则有两种常见构建形态：

- `-o app`：编译器直接编译并链接导入的 C translation unit
- `-o app.c`：除 `app.c` 外，还会生成 `app.cimports.sh`（sidecar），供后续手动链接或脚本消费

### 方式二：使用 `src/compile.sh`

`compile.sh` 是自举构建脚本，`-e/--exec` 触发自动链接、`-b` 触发自举对比：

```bash
cd src
./compile.sh --c99 -e input.uya          # 编译并链接成可执行文件
./compile.sh --c99 -e -b --nostdlib      # 自举对比（nostdlib 主线）
```

### 方式三：显式选择 zig cc

```bash
# 使用 zig 作为统一工具链
TOOLCHAIN=zig ZIG=/path/to/zig bin/uya build input.uya -o app --c99

# 等价写法：直接指定 CC_DRIVER
CC_DRIVER="/path/to/zig cc" bin/uya build input.uya -o app --c99
```

> 注意：`bin/uya` 的 `--help` 里没有 `-e` 选项——链接是 `build` 命令的默认行为（`-o` 不是 `.c` 就链接）。
> `-e` 只属于 `src/compile.sh`。

## `check` 命令语义

`bin/uya check foo.uya` 用于快速确认输入文件及其模块依赖能够通过：

- 词法分析
- 语法分析
- AST 合并
- 类型检查 / 安全证明

它**不会**进入：

- 优化
- C99 / exec backend 代码生成
- 宿主工具链链接
- 程序运行

因此它适合在修改语法、checker、HIR lowering 或测试样例时先做快速红绿验证。

## 链接选项

`compile.sh` 在 `-e` 模式下会自动使用宿主工具链。逻辑上区分两条路径：

```bash
# hosted 模式（默认）
${CC_DRIVER:-cc} ${CC_TARGET_FLAGS} -std=c99 -O2 -fno-builtin input.c -o output

# --nostdlib 模式（当前仅 Linux x86_64 已实现）
${CC_DRIVER:-cc} ${CC_TARGET_FLAGS} -std=c99 -O2 -fno-builtin -fno-stack-protector \
    -nostdlib -static -o output "$CRTI" uya.o "$CRTN"
```

宿主 `CFLAGS` 默认值自 v0.10.4 起为 `-std=c99 -O2 -fno-builtin`（`compile.sh` 默认再追加
`-g -Werror`，根 `Makefile` 为 `-std=c99 -O2 -fno-builtin -Werror`），可用同名环境变量覆盖。
若设置了 `TARGET_TRIPLE` 且未手动设置 `CC_TARGET_FLAGS`，脚本会自动补出 `-target <triple>`。

## 工作原理

1. **`bin/uya`**（单一可执行，无包装脚本）:
   - `build` / `run` / `test` 自己完成「前端 + C99 代码生成 + 宿主链接」
   - 只有 `-o *.c` 才停在「只生成 C」
   - `--nostdlib` 时由生成 C 内含 `_start`，链接走 `crti.o + uya.o + crtn.o` 的 `-nostdlib -static`

2. **compile.sh**（自举构建脚本）:
   - 检测 `-e` 选项
   - C99 编译成功后，调用宿主工具链链接（`UYA_MULTI_FILE_C=1` 时走 `make -C .uyacache -j`）
   - `--nostdlib` 模式下向编译器传入 `--nostdlib`（不再拼接重复序言）
   - 非 Linux 目标 / 非 x86_64 的 `--nostdlib` 会直接报错，不再误走 Linux `_start`

3. **生成的 C 代码**:
   - hosted 模式下包含 `#include <stdlib.h>` 等宿主头
   - 在 Darwin hosted 目标下，部分 libc/syscall 能力会通过生成的 C helper bridge 到宿主 libc（例如 `stat/fstat/lstat`、`fcntl`、`pipe2`、`clock_gettime`、`nanosleep`）
   - 在 Windows 目标下，`@syscall` 汇聚到 `uya_windows_syscall`（Win32 API + Winsock），并处理 LLP64 与控制台代码页

## 冷启动与 make 目标

| 命令 | 用途 |
|------|------|
| `make from-c` | Linux 冷启动：从 `bin/uya.c` / `backup/uya-<os>-<arch>.c` 构建（macOS 上会拒绝执行） |
| `make from-c-native` | macOS 冷启动：从 `backup/uya-hosted-macos-<arch>.c` 构建 |
| `make uya` | 自举编译器（默认 `--nostdlib` + 静态链接 + 多文件 C） |
| `make uya-hosted` | hosted 主线编译器 |
| `make b` / `make b-hosted` | 自举验证 |
| `make check` / `make check-hosted` | 构建 + 测试 + 验证闸门 |

## 推荐工具链

### 原生 Linux / macOS

```bash
# 使用系统工具链
make uya-hosted

# 使用 zig cc 统一工具链
TOOLCHAIN=zig ZIG=/path/to/zig make uya-hosted
```

### Windows hosted 交叉链接

```bash
TOOLCHAIN=zig \
ZIG=/path/to/zig \
TARGET_OS=windows \
TARGET_ARCH=x86_64 \
TARGET_TRIPLE=x86_64-windows-gnu \
make uya-hosted
```

### Darwin hosted 交叉构建

```bash
TOOLCHAIN=zig \
ZIG=/path/to/zig \
TARGET_OS=macos \
TARGET_ARCH=arm64 \
TARGET_TRIPLE=aarch64-macos-none \
make uya-hosted
```

Intel macOS 目标改为：

```bash
TOOLCHAIN=zig \
ZIG=/path/to/zig \
TARGET_OS=macos \
TARGET_ARCH=x86_64 \
TARGET_TRIPLE=x86_64-macos-none \
make uya-hosted
```

如果当前 `bin/uya` 还没带上最新 Darwin backend，而你正在开发 `src/codegen/c99/`、`lib/libc/syscall.uya`、runtime 等相关代码，建议先重建一个 Linux hosted 编译器，再用它交叉出 macOS 产物：

```bash
cd src

# 1. 先在 Linux 上重建一个新的 hosted 编译器
./compile.sh --c99 -e --name uya-hosted-stage-linux --no-safety-proof

# 2. 交叉出 Apple Silicon macOS 编译器
UYA_COMPILER="../bin/uya-hosted-stage-linux" \
TOOLCHAIN=zig \
ZIG=/path/to/zig \
TARGET_OS=macos \
TARGET_ARCH=arm64 \
TARGET_TRIPLE=aarch64-macos-none \
./compile.sh --c99 -e --name uya-hosted-macos-arm64 --no-safety-proof

# 3. 交叉出 Intel macOS 编译器
UYA_COMPILER="../bin/uya-hosted-stage-linux" \
TOOLCHAIN=zig \
ZIG=/path/to/zig \
TARGET_OS=macos \
TARGET_ARCH=x86_64 \
TARGET_TRIPLE=x86_64-macos-none \
./compile.sh --c99 -e --name uya-hosted-macos-x86_64 --no-safety-proof
```

注意：

- `zig cc` 是当前推荐的**统一构建驱动**，特别适合共享基础、Windows 目标和交叉编译。
- 原生平台 bring-up 时仍可继续使用系统 `cc` / `clang` 做对照验证。
- Darwin hosted 交叉产出目前已经覆盖 `arm64` 与 `x86_64` 两条主架构。
- 交叉产出“能否运行”仍取决于目标平台 ABI、runtime、`@syscall`、`pthread`、`std.async` 等后续迁移状态。

## 示例

```bash
# 创建测试文件
cat > /tmp/test.uya << 'EOF'
export fn main() i32 {
    return 42;
}
EOF

# 使用 zig cc 统一工具链编译
TOOLCHAIN=zig ZIG=/path/to/zig ./bin/uya build /tmp/test.uya -o /tmp/test.c --c99
cc -std=c99 -O2 -fno-builtin /tmp/test.c -o /tmp/test

# 运行生成的可执行文件
/tmp/test
echo "退出码：$?"  # 输出 42
```

## 注意事项

1. **0 依赖限制**:
   - 不能使用标准库函数（printf, malloc 等）
   - 需要使用 libc 模块的系统调用
   - 参考 `lib/libc/` 下的实现

2. **_start 入口**:
   - `--nostdlib` 模式下，编译器在生成 C 中写入 `_start`；`compile.sh` 直接编译该 C 并链接 `crti.o`/`crtn.o`
   - 仅支持 x86-64 Linux 平台

3. **平台支持**:
   - `hosted` 路径已具备 host/target/toolchain 统一入口
   - `hosted + zig cc` 已实测交叉产出 macOS `arm64` / `x86_64` 编译器二进制
   - Windows 目标（`TARGET_OS=windows`）已用 zig cc 打通自举：`@syscall` 汇聚到 `uya_windows_syscall`、Winsock、控制台代码页、LLP64 指针截断
   - `--nostdlib` 目前仍仅支持 Linux x86-64
   - Darwin 真机 smoke、`pthread`、`std.async` / `kqueue` 与 Windows IOCP 仍需后续平台迁移文档逐步落地

## 文档与阶段进度

- 共享平台基础（Linux 可完成项）：[todo_platform_shared_foundation.md](todo_platform_shared_foundation.md)（已勾选同步）

## 相关文件

- `src/compile.sh` - 编译脚本（包含工具链与链接逻辑）
- `src/driver/toolchain.uya` - `bin/uya` 的宿主工具链与 `@c_import` 驱动
- `Makefile` - 顶层 host/target/toolchain 入口
- `lib/std/runtime/entry/entry.uya` - C main 入口（`set_process_stack_limit_bytes` 按需设置栈）
