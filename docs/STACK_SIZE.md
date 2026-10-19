# Uya 编译器自动堆栈大小设置

## 概述

Uya 编译器**默认使用 65536 KB（64MB）堆栈**，通过 `set_process_stack_limit_bytes`（内部
`setrlimit(RLIMIT_STACK, ...)`）在进程启动时自动抬高。也可以通过 `--stack-size` 选项自定义。

## 默认设置

**默认堆栈大小：65536 KB（64MB）**

```uya
// src/main.uya
var stack_size: i32 = 65536;  // 默认 64MB 堆栈
...
var eff_compiler_stack_kb: i32 = stack_size;
if eff_compiler_stack_kb <= 0 {
    eff_compiler_stack_kb = 65536;
}
set_process_stack_limit_bytes(eff_compiler_stack_kb as u64 * 1024);
```

`./bin/uya --help` 对应文案：

```
--stack-size <KB>    设置堆栈大小（KB），默认 65536 (64MB)
```

**注意**：根 `Makefile` 的构建目标另外在 shell 侧设置了 `ulimit -s 32768`（32MB），
`src/compile.sh` 的自举对比步骤用 `ulimit -s 65536`，两者都是为「编译器启动阶段」兜底，
与编译器自己设置的 65536 KB 上限并不冲突。

## 功能特性

### 1. 默认 64MB 堆栈

无需任何参数，编译器默认把自身栈上限抬到 64MB：

```bash
# 使用默认 65536 KB 堆栈
bin/uya build src/main.uya -o output.c --c99
```

**实现原理**：
- `--stack-size` 未传时 `stack_size` 为 0，入口按默认 65536 KB 计算有效值
- 在 `export fn main()` 里调用 `set_process_stack_limit_bytes(...)`（`lib/std/runtime/entry/entry.uya`），
  在 **Linux**（x86_64 / arm64 / arm / riscv64）上直接 `@syscall(setrlimit, RLIMIT_STACK, ...)`；
  其它目标 `std.cfg` 裁掉该分支，是 no-op
- 实际传给 `compile_files()` 的仍是 0：**生成的 C 代码里不再注入 `setrlimit` / `<sys/resource.h>`**
  （曾与生成类型、系统头冲突）；显式 `--stack-size` 只在生成 C 的文件头留一行提示注释
- 生成程序的 C `main`（`lib/std/runtime/entry/entry.uya`）在 Linux 上会自己把栈抬到
  `ENTRY_DEFAULT_STACK_LIMIT_BYTES`（= 65536 KB），所以直接执行 split-C 产物也不会因默认栈崩溃

### 2. compile.sh 集成

`src/compile.sh` 的 `--stack-size` 会原样传给编译器（`bin/uya`），由编译器在启动时设置。

```bash
# 设置 128MB 堆栈
./src/compile.sh --stack-size 131072 --c99 -e
```

**注意**：堆栈大小由 Uya 编译器代码中的 `set_process_stack_limit_bytes` 设置，不是靠 shell 的
`ulimit`；shell 侧 `ulimit` 只用来保证编译器能顺利启动。

### 3. 生成的 C 代码中的堆栈提示

当显式使用 `--stack-size` 编译时，生成的 C 只有一行文件头注释，不含任何 `setrlimit` 调用：

```c
// C99 代码由 Uya 生成
// 堆栈大小提示：此程序需要至少 131072 KB 的堆栈空间
```

### 4. run / test 子进程的栈

- `uya test`：约定是经 `/bin/sh -c 'ulimit -s <N>; exec "<exe>"'` 启动子进程，`<N>` 默认 65536，
  可用 `--stack-size` 覆盖。这是测试体在默认 8MB 栈下容易段错误的原因，也是默认值取 64MB 的原因。
- `uya run`：直接 `exec` 目标程序，不额外加 `ulimit`；需要大栈时自行 `ulimit -s` 或在程序里按需调用
  `set_process_stack_limit_bytes`。

### 5. 帮助信息

```bash
# 查看编译器帮助
bin/uya --help | grep -A1 "stack-size"

# 查看 compile.sh 帮助
./src/compile.sh --help | grep -A1 "stack-size"
```

## 使用场景

### 场景 1：编译大型项目

当编译包含大量源代码或复杂泛型的项目时，编译器可能需要较大的栈空间：

```bash
# 默认 64MB 堆栈
./src/compile.sh --c99 -e

# 如果仍然栈溢出，加倍到 128MB
./src/compile.sh --stack-size 131072 --c99 -e
```

### 场景 2：运行需要大栈空间的程序

当运行包含大数组或深度递归的程序时：

```bash
# 编译时设置大堆栈提示
bin/uya build myprogram.uya -o myprogram --stack-size 131072

# 运行时设置堆栈（使用 ulimit）
ulimit -s 131072
./myprogram
```

### 场景 3：自举编译

自举编译编译器自身时，仓库脚本已经够用；需要更大余量时显式指定：

```bash
./src/compile.sh --stack-size 131072 --c99 -e -b
```

## 技术实现

### 编译器 (main.uya)

`--stack-size` 命令行参数解析（分离写法，值必须是正整数 KB）：

```uya
} else if strcmp(arg, "--stack-size" as *byte) == 0 {
    // 解析下一参数为 KB 数值
    stack_size[0] = size_val;
}
```

入口处的有效值计算与设置：

```uya
var eff_compiler_stack_kb: i32 = stack_size;
if eff_compiler_stack_kb <= 0 {
    eff_compiler_stack_kb = 65536;
}
set_process_stack_limit_bytes(eff_compiler_stack_kb as u64 * 1024);
```

### 编译脚本 (compile.sh)

1. **选项解析**：
```bash
--stack-size)
    STACK_SIZE="$2"
    shift 2
    ;;
```

2. **自举对比步骤的 shell 兜底**：
```bash
(ulimit -s 65536 2>/dev/null || true; "$EXECUTABLE_FILE" build "$INPUT_PATH" ...)
```

3. **根 Makefile 的构建目标兜底**：
```bash
( ulimit -s 32768 && cd src && ./compile.sh --c99 -e --nostdlib --safety-proof )
```

## 推荐配置

| 场景 | 推荐堆栈大小 | 说明 |
|------|-------------|------|
| 日常开发 | 64MB（默认） | 适用于绝大多数情况 |
| 超大项目 / 深层泛型 | 128MB | `--stack-size 131072` |
| 自举编译 | 64MB（默认） | 根 Makefile 已经配置好 |
| 深度递归程序 | 按实际需求 | 运行时 `ulimit -s` 或入口自设 |

## 注意事项

1. **ulimit 限制**：`ulimit -s` 设置受系统限制，可能需要 root 权限才能超过系统硬限制

2. **跨平台兼容性**：`ulimit` 只在 Linux/Unix 有效；`set_process_stack_limit_bytes`
   当前只在 Linux 目标的 x86_64 / arm64 / arm / riscv64 分支上真正下发 `setrlimit`，
   其它目标编译期裁掉、保持宿主默认栈

3. **内存消耗**：栈上限只是上限，按需提交；但过大的上限在极端递归下会更快撞到内存边界

4. **调试栈溢出**：如果程序栈溢出，可以逐步增加堆栈大小直到问题解决：
   ```bash
   # 从默认 64MB 开始
   ./src/compile.sh --stack-size 65536 --c99 -e

   # 如果失败，加倍
   ./src/compile.sh --stack-size 131072 --c99 -e

   # 继续增加直到成功
   ```

## 示例

### 示例 1：编译编译器自身

```bash
cd <repo>

# 使用默认堆栈大小
./src/compile.sh --c99 -e

# 使用 128MB 堆栈
./src/compile.sh --stack-size 131072 --c99 -e
```

### 示例 2：编译大型项目

```bash
# 编译大型项目
bin/uya build large_project.uya -o large_project --stack-size 131072
ulimit -s 131072 && ./large_project
```

## 故障排除

### 问题：段错误（Segmentation Fault）

**症状**：编译过程中出现段错误

**解决方案**：
```bash
# 增加堆栈大小
./src/compile.sh --stack-size 131072 --c99 -e

# 或者在运行前设置
ulimit -s 131072
./src/compile.sh --c99 -e
```

### 问题：ulimit 设置失败

**症状**：`ulimit: stack size: cannot modify limit: Operation not permitted`

**解决方案**：
- 检查系统限制：`ulimit -a`
- 可能需要修改 `/etc/security/limits.conf`
- 或者联系系统管理员

## 相关文档

- [usage_guide.md](usage_guide.md) - 命令行选项与 Make 目标速查
- [UYA_BUILD_RUN.md](UYA_BUILD_RUN.md) - build/check/run 与宿主工具链
- [compile.sh](../src/compile.sh) - 编译脚本源码

## 版本历史

- **v0.7.5** (2026-02-26): 初始版本，添加自动和手动堆栈大小设置功能
- **v0.10.4** (2026-10-19): 默认值从 16MB 更正为 65536 KB（64MB）；补充 `test` 子进程
  `ulimit -s` 行为与「生成 C 不再注入 `setrlimit`」的说明
