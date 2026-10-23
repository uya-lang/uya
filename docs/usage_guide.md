# Uya 编译器使用指南

**适用版本**：v0.10.4（唯一版本来源 `src/version.uya`）
**更新日期**：2026-10-19

本文的命令、选项与默认值均以仓库代码为准：`./bin/uya --help`、`src/main.uya` 的 `parse_args()`、`src/driver/toolchain.uya`、`src/compile.sh` 与根目录 `Makefile`。

---

## 安装

### 从源码构建

#### 系统要求

- GCC 或兼容 C99 的 `cc` / `clang`（`--c99` 后端的宿主编译器）
- Make、Bash
- 可选：`zig cc`（跨平台与交叉目标统一驱动，`TOOLCHAIN=zig ZIG=<path>`）
- 可选：`emcc` + `node`（仅 `make tests-emcc` 需要）

#### 冷启动（无可用编译器时）

```bash
git clone <repo> uya
cd uya

# Linux：从 C99 种子构建（bin/uya.c / backup/uya-<os>-<arch>.c）
make from-c

# macOS：从本机 hosted 种子构建（backup/uya-hosted-macos-<arch>.c）
make from-c-native
```

`make from-c` 在 macOS 上会直接报错并提示改用 `make from-c-native`（通用种子可能是 Linux nostdlib 产物）。

#### 自举构建

```bash
# 默认：--nostdlib + 静态链接，产物 bin/uya
make uya

# hosted 主线（依赖系统 libc / Winsock / macOS shim），产物 bin/uya-hosted
make uya-hosted

# 跨平台入口：Linux 走 uya，其它平台走 uya-hosted
make uya-portable
```

`make uya` 默认走多文件 C（`src/.uyacache` + `make -j`），并带增量指纹短路：源码/选项/编译器二进制都没变时整轮编译直接跳过（实测 22 s → 0.4 s，详见 `docs/build_speed.md`）。

### 验证安装

```bash
make check                 # 自举构建 + 并行测试套件 + 若干验证闸门
make b                     # 自举验证：编译器编译自身，产物比对
./bin/uya --version        # 输出 v0.10.4
./bin/uya --help
```

---

## 命令行总览

### 子命令

| 子命令 | 说明 |
|--------|------|
| `uya build <文件...> [-o <输出>]` | 编译为可执行文件或中间产物；`-o *.c` 只生成 C 代码 |
| `uya check <文件...>` | 只做词法/语法/类型检查与内存安全证明，不进入代码生成、链接、运行 |
| `uya run <文件...> [-- <参数>...]` | 编译、链接并运行目标程序 |
| `uya test <文件...>` | 编译测试并运行（子进程栈：`--stack-size` 或默认 65536 KB） |
| `uya fmt <文件>` | 格式化单个 Uya 源文件（见下文「fmt」的最小限制） |
| `uya upm <子命令>` | Uya 包管理工作流（外置可执行 `bin/cmd/upm`） |
| `uya pack-image <xxx.pobj> -o <xxx.uapp>` | 把 microapp 载荷对象打包为 `.uapp` |
| `uya inspect-image <xxx.pobj\|xxx.uapp>` | 打印 microapp 头信息 |
| `uya verify-image <xxx.pobj\|xxx.uapp>` | 校验 microapp 镜像或载荷对象 |
| `uya --outlibc <目录>` | 把标准库输出为 C 代码 |

隐式入口仍可用：`uya hello.uya -o hello` 等价于 `uya build hello.uya -o hello`。

```bash
# 生成可执行文件
./bin/uya build hello.uya -o hello
./bin/uya hello.uya -o hello            # 隐式 build

# 只生成 C 代码（不调用宿主工具链）
./bin/uya build hello.uya -o hello.c --c99

# 不带 -o：临时 C 输出到 .uyacache，最终链接为 ./a.out
./bin/uya build hello.uya

# 检查 / 运行 / 测试
./bin/uya check hello.uya
./bin/uya run hello.uya -- arg1 arg2
./bin/uya test tests/test_hello.uya
```

### 通用选项

| 选项 | 默认 | 说明 |
|------|------|------|
| `--c99` | 自动 | 使用 C99 后端；输出文件名以 `.c` 结尾时自动启用 |
| `--app <app\|microapp>` | `app` | `microapp` 启用更严格的容器检查，可输出 `.pobj` / `.uapp` |
| `--microapp-profile <name>` | 见「microapp」 | 覆盖 microapp target profile（优先于 `MICROAPP_TARGET_PROFILE`） |
| `--line-directives` | 关闭 | 生成 `#line` 指令 |
| `--no-line-directives` | — | 关闭 `#line` 指令 |
| `--opt=<0-3>` / `-O0`..`-O3` | `1` | 编译器内部优化级别（常量折叠 / DCE / 证明优化 / 标记式内联与展开） |
| `--safety-proof` | 开启 | 启用内存安全证明 |
| `--no-safety-proof` | — | 关闭内存安全证明 |
| `--nostdlib` | 关闭 | 生成含 `_start` 的独立程序；链接走 `-nostdlib -static`（仅 Linux x86_64） |
| `--async-frame-heap=on` | 关闭 | async frame pool 满时回退到调试 heap |
| `--jobs <N>` / `-j<N>` / `--jobs=N` / `-jN` | CPU 核数（上限 32） | 前端进程级并行度；`1` = 全串行 |
| `--stack-size <KB>` | `65536` | 编译期设置编译器进程栈上限，并作为 `run`/`test` 子进程栈 |
| `--split-c-dir [<dir>]` / `--split-c-dir=<dir>` | `.uyacache` | 多文件 C 输出目录；`--split-c-dir=` 空值或它作为最后一个参数时回落到默认 `.uyacache` |
| `--no-split-c` | — | 强制单文件/临时 `.c`；忽略 `UYA_SPLIT_C_DIR` 与 `--split-c-dir` |
| `-o <文件>` | `a.out`（`build`） | 输出路径；`.c` 结尾只生成 C，其它视为可执行文件 |
| `--verbose` | 关闭 | 打印详细编译日志（含编译统计分段耗时） |
| `-h` / `--help`、`-v` / `--version` | — | 帮助 / 版本 |

### 调试与内部选项

以下选项不在 `--help` 主表里，供调试与工具链使用：

| 选项 | 说明 |
|------|------|
| `--project-root <dir>` | 覆盖模块解析根目录 |
| `--manifest-path <path>` | 覆盖 `uya.json` 清单路径 |
| `--exec` / `--vm` | 走 exec 后端（`--vm` 只跑 VM，不做 C 代码生成） |
| `--dump-exec-hir` / `--dump-bytecode` / `--trace-vm` | 打印 exec HIR / 字节码 / 执行跟踪 |

### 环境变量

宿主工具链（`src/driver/toolchain.uya`、`src/compile.sh`）：

| 变量 | 默认 | 说明 |
|------|------|------|
| `CC` | `cc` | 宿主 C 编译器 |
| `CC_DRIVER` | `$(CC)` | 实际调用的编译命令，可为多词（如 `"zig cc"`） |
| `CC_TARGET_FLAGS` | 空 | 目标平台额外参数（如 `-target x86_64-windows-gnu`） |
| `CFLAGS` | `-std=c99 -O2 -fno-builtin`（`compile.sh`/`Makefile` 追加 `-Werror`） | 宿主 C 编译选项；含 `-O2/-O3/-Os` 时自动追加 `-fno-inline-small-functions` |
| `LDFLAGS` | 空 | 宿主链接选项 |
| `TOOLCHAIN` / `ZIG` | `system` / `PATH 中的 zig` | `zig` 时用 `zig cc` 作为驱动 |
| `HOST_OS` / `HOST_ARCH` | 自动探测 | 宿主平台 |
| `TARGET_OS` / `TARGET_ARCH` / `TARGET_TRIPLE` | 继承宿主 | 目标平台 |
| `RUNTIME_MODE` / `LINK_MODE` | `hosted` / `default` | `nostdlib`+`static` 为独立链接路线 |
| `UYA_ROOT` | 编译器目录的上一级 | 标准库位置（`bin` → `lib`） |

并行与增量：

| 变量 | 默认 | 说明 |
|------|------|------|
| `UYA_JOBS` | CPU 核数 | 前端并行度，`--jobs`/`-j` 优先 |
| `UYA_GCC_JOBS` | CPU 核数（Makefile / `compile.sh`；`uya build` 自身链接为 `16`） | split-C 目录里 `make -j` 的并行度 |
| `UYA_TEST_JOBS` | CPU 核数 | `make tests` 的并行 worker 数 |
| `UYA_FORCE_BUILD` | 关闭 | `1` 时跳过增量指纹短路，强制重建 |
| `UYA_SPLIT_C_CLEAN` | 关闭 | `1` 时强制清空 split-C 缓存 |
| `UYA_SPLIT_C` | 开启 | `0`/`false`/`no`/`off` 强制单文件 C |
| `UYA_SPLIT_C_DIR` | 空 | 指定 split-C 输出目录 |
| `UYA_SPLIT_C_MIRROR` | 开启 | `0`/`false`/`no`/`off` 时用 `uya_part1+part2` 两文件模式 |
| `UYA_MULTI_FILE_C` / `UYA_SINGLE_FILE_C` | 空 | `compile.sh` 的多文件 / 单文件种子开关（互斥，后者优先） |
| `UYA_SKIP_UYA` | 关闭 | `1` 时 `make uya` 复用现有 `bin/uya` |

微应用与交叉目标变量见下文对应章节。

### 编译流程

```
Uya 源文件 (.uya) + 模块依赖
        ↓
   词法 / 语法分析          ← --jobs 进程级并行（parse）
        ↓
     AST 合并
        ↓
   类型检查 + 内存安全证明  ← --safety-proof / --no-safety-proof
        ↓
   优化分析 (-O0..-O3)      ← --opt / -O
        ↓
   代码生成 (C99)           ← 默认多文件 .uyacache，按镜像 TU 并行
        ↓
   宿主工具链 (cc / zig cc)
        ↓
   可执行文件
```

---

## 项目结构

```
uya/
├── bin/                    # 本地构建产物（不入库）
│   ├── uya                 # 自举编译器（--nostdlib 主线）
│   ├── uya-hosted          # hosted 编译器
│   ├── uyafmt              # make check-fmt 产出的完整格式化器
│   └── cmd/upm             # make cmd-upm 产出的外置 upm
├── src/                    # 自举编译器源码（唯一维护源）
│   ├── main.uya            # CLI 入口与命令分发
│   ├── lexer.uya / parser/ # 词法 / 语法
│   ├── ast.uya
│   ├── checker/            # 类型检查、内存安全证明、优化 Pass
│   ├── codegen/c99/        # C99 后端（含 @syscall 汇聚点）
│   ├── driver/             # 模块解析与宿主工具链驱动
│   ├── cmd/                # 外置子命令（build / upm）
│   ├── fmt.uya             # `uya fmt` 的进程内实现
│   └── compile.sh          # 自举构建脚本（-e / -b / split-C / 增量）
├── lib/                    # 标准库（std/、libc/、kernel/、microapp/ …）
├── tools/                  # 独立工具（fmt.uya 等）
├── tests/                  # 回归 / 错误用例与验证脚本
├── examples/               # 示例程序
├── benchmarks/             # 基准测试
├── backup/                 # 自举种子（uya.c、hosted 种子、uyacache 多文件备份）
└── docs/                   # 文档
```

---

## Make 目标速查

### 覆盖变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CFLAGS` | `-std=c99 -O2 -fno-builtin -Werror` | 宿主 C 编译选项；调试可 `CFLAGS='-std=c99 -O0 -g -fno-builtin'` |
| `LDFLAGS` | （空） | 链接选项 |
| `UYA_TEST_JOBS` | CPU 核数 | `make tests` 并行度 |
| `UYA_GCC_JOBS` | CPU 核数 | split-C `make -j` 并行度 |
| `TARGET_OS` / `TARGET_ARCH` / `TARGET_TRIPLE` | 宿主 | 交叉目标 |
| `TOOLCHAIN` / `ZIG` / `CC_DRIVER` | `system` / `PATH 中的 zig` / `$(CC)` | 宿主工具链 |

```bash
# 调试构建（关掉 -O2）
CFLAGS='-std=c99 -O0 -g -fno-builtin' make from-c

# 用 zig cc 统一工具链
TOOLCHAIN=zig ZIG=/path/to/zig make uya-hosted
```

### 构建与自举

| 命令 | 说明 |
|------|------|
| `make from-c` | Linux 冷启动：从 `bin/uya.c` / `backup/uya-<os>-<arch>.c` 构建 |
| `make from-c-native` | macOS 冷启动：从本机 hosted 种子构建 |
| `make uya` | 自举编译器（默认 `--nostdlib`、静态链接、多文件 C + 增量短路） |
| `make uya-hosted` | hosted 主线编译器 |
| `make uya-portable` | 跨平台入口：Linux→`uya`，其它→`uya-hosted` |
| `make uya-std` | 标准库链接版本（= `uya-hosted`，调试用） |
| `make uya-safety` | 启用内存安全检查构建 |
| `make b` / `b-hosted` / `b-portable` | 自举验证（编译自身 + 比对） |
| `make restore` | 从 `backup/uya.c` 恢复 `bin/uya.c` |

### 验证与回归

| 命令 | 说明 |
|------|------|
| `make check` | `make uya` + 并行测试套件 + 若干验证闸门（提交前主入口） |
| `make check-hosted` | hosted 路线的自举 + 测试验证 |
| `make tests` | `tests/run_programs_parallel.sh --uya --c99`（默认隐藏逐条 ✓） |
| `make tests e` | 同上 + 最小输出（仅失败详情） |
| `make tests-hosted` / `tests-portable` | hosted 测试集 / 跨平台入口 |
| `make tests-uya` | 快捷方式：测试自举编译器 |
| `make tests-emcc` | emcc / unknown target smoke（需 `emcc` 与 `node`，不在 `make check` 内） |
| `make bench-compile-stats` | 抓取前端 CompileStats 分段耗时（`ARGS='--runs 3'`） |

单个程序回归：

```bash
./bin/uya test tests/test_hello.uya
./tests/run_programs_parallel.sh test_hello.uya
```

### microapp / upm / examples / fmt

| 命令 | 说明 |
|------|------|
| `make microapp-check` | microapp 聚合回归套件 |
| `make microapp-hosted-smoke` | hosted 平台可用的 microapp smoke |
| `make microapp-aarch64-runtime-check` | arm64 host 门控的 aarch64 runtime 回归 |
| `make microapp-macos-runtime-check` | macOS arm64 host 门控 runtime 回归 |
| `make microapp-compat-check` | `.uapp` v1/v2 兼容回归 |
| `make microapp-recovery-check` | crash / recovery / update 回归 |
| `make cmds` / `make cmd-upm` | 构建外置子命令（当前仅 `bin/cmd/upm`） |
| `make upm-check` | UPM / 包管理专项回归 |
| `make examples-check` | examples 可执行 / 服务 / package / microapp 验证 |
| `make outlibc` | 输出标准库 C 代码 |
| `make fmt` | 运行 `tests/verify_fmt_cli.sh`（`uya fmt` CLI 验证） |
| `make check-fmt` | 构建 `bin/uyafmt` 并对 `src lib tests tools` 跑 `-l` |

### 备份、发布、安装

| 命令 | 说明 |
|------|------|
| `make backup` | 依赖 `make check`，把 `src/.uyacache` 复制为 `backup/uyacache` |
| `make backup-seed` | 单文件重编译，更新 `bin/uya.c`、`backup/uya.c` 与 host/arch 种子 |
| `make backup-hosted-seed` / `-native` | hosted 单文件种子 |
| `make backup-all` | `backup` + `backup-all-seed`（提交前完整备份） |
| `make release` | 要求干净工作树；`clean` + 自举验证 + 备份 + `-O3 -DNDEBUG` 重链 + strip |
| `make release-dirty` | 在当前工作树强行跑完整 release（本地调试，不作最终结论） |
| `make release-clean` | 在 Git HEAD 干净快照里跑 `make release`（贴近 CI） |
| `make install` | 安装 `uya`、`lib/`、`docs/`、`tests/`；支持 `PREFIX`/`BINDIR`/`LIBDIR`/`DOCDIR`/`TESTSDIR`/`DESTDIR` |
| `make clean` | 清理构建产物 |
| `make help` | 打印全部目标与环境变量 |

提交前建议顺序：`make clean` → `make backup-all`（失败不要提交）。

---

## 交叉编译与目标平台

目标平台由 `TARGET_OS` / `TARGET_ARCH` 决定，推荐用 `zig cc` 作为统一驱动：

| 变量 | 取值 |
|------|------|
| `TARGET_OS` | `linux` / `macos`（别名 `darwin`）/ `windows` |
| `TARGET_ARCH` | `x86_64` / `arm64`（别名 `aarch64`）/ `riscv64` |

```bash
# Windows x86_64 hosted 交叉（Winsock / 控制台代码页 / LLP64 / @syscall 汇聚点已打通）
TOOLCHAIN=zig ZIG=/path/to/zig \
TARGET_OS=windows TARGET_ARCH=x86_64 TARGET_TRIPLE=x86_64-windows-gnu \
make uya-hosted

# macOS Apple Silicon hosted 交叉
TOOLCHAIN=zig ZIG=/path/to/zig \
TARGET_OS=macos TARGET_ARCH=arm64 TARGET_TRIPLE=aarch64-macos-none \
make uya-hosted
```

`--nostdlib` 的入口与链接策略目前仅实现 **Linux x86_64**；其它目标请走 hosted 路线（`src/compile.sh` 会直接报错而不是误走 Linux `_start`）。

---

## microapp 模式

```bash
# 直接生成 .uapp 镜像
./bin/uya build --app microapp main.uya -o microapp.uapp

# 先出载荷对象，再打包 / 检查 / 校验
./bin/uya build --app microapp main.uya -o microapp.pobj
./bin/uya pack-image microapp.pobj -o microapp.uapp
./bin/uya inspect-image microapp.uapp
./bin/uya verify-image microapp.uapp
```

profile 推导优先级：`--microapp-profile` > `MICROAPP_TARGET_PROFILE` > `MICROAPP_TARGET_ARCH`(+`TARGET_OS`) > `TARGET_OS`/`TARGET_ARCH` > `HOST_OS`/`HOST_ARCH` > `linux_x86_64_hardvm`。

| profile | 三元组 |
|---------|--------|
| `linux_x86_64_hardvm` | `x86_64-linux-gnu` |
| `linux_aarch64_hardvm` | `aarch64-linux-gnu` |
| `macos_arm64_hardvm` | `arm64-apple-darwin` |
| `rv32_baremetal_softvm` | `riscv32-unknown-elf` |
| `xtensa_baremetal_softvm` | `xtensa-unknown-elf` |

相关环境变量：`MICROAPP_TARGET_PROFILE`、`MICROAPP_TARGET_ARCH`、`MICROAPP_TARGET_GCC`（优先于 `TARGET_GCC`）、`MICROAPP_TARGET_CFLAGS`、`MICROAPP_TARGET_LDFLAGS`。

---

## upm（包管理）

`uya upm` 转发到外置可执行 `bin/cmd/upm`（`make cmd-upm` / `make cmds` 构建）；缺失时报
「缺少可执行子命令 …；请先运行 make cmds」。

```bash
./bin/uya upm init --src-layout demo_pkg
./bin/uya upm add gui_uya --git https://github.com/uya-lang/gui-uya.git --branch main
./bin/uya upm add gui_uya --dev --path ../gui_uya
./bin/uya upm install
./bin/uya upm graph
./bin/uya upm why gui_uya
./bin/uya upm doctor
./bin/uya upm vendor
./bin/uya upm build --c99 -o app
```

完整子命令：`init`、`install`、`update`、`add`（`--path` / `--git` + `--branch|--tag|--commit`、`--dev`）、`remove`（`--dep` / `--dev`）、`graph`、`why`、`doctor`、`cache dir`、`vendor`、`publish`、`build`。

---

## fmt（格式化）

`uya fmt` 是**最小**格式化入口（实现见 `src/fmt.uya`）：

```bash
./bin/uya fmt src/main.uya        # 输出到 stdout
./bin/uya fmt -w src/main.uya     # 原地写回
```

限制（以代码为准）：只接受**一个文件**，只支持 `-w`；`-d` / `-l` / `-s` / `-r` / 目录递归 / stdin 均不支持（传 `-s` 会被当成文件名并报「无法读取文件」）。

完整的 gofmt 式 CLI 在 `tools/fmt.uya`，由 `make check-fmt` 构建为 `bin/uyafmt`：

```bash
make check-fmt                    # 构建 bin/uyafmt 并对 src lib tests tools 跑 -l

./bin/uyafmt -w file.uya          # 写回
./bin/uyafmt -l src lib           # 只列出未格式化文件（支持多路径与目录递归）
./bin/uyafmt -d file.uya          # 输出 diff
./bin/uyafmt -s -w file.uya       # 先 simplify 再写回
./bin/uyafmt -r 'old -> new' -w file.uya
./bin/uyafmt < file.uya           # 无路径时读 stdin
```

组合约束：`-w`/`-l`/`-d` 三者互斥；stdin 模式不能再带 `-w`/`-l`/`-d`/`-s`/`-r`。

---

## split-C 多文件 C 输出

C99 后端默认把 C 输出拆成多份放在 `.uyacache`（或 `--split-c-dir` 指定目录），生成 `Makefile` 后由 `make -j` 并行编译：

```bash
./bin/uya build main.uya -o app --c99                      # 默认 .uyacache
./bin/uya build main.uya --split-c-dir=/tmp/uyac -o app --c99
./bin/uya build main.uya --split-c-dir /tmp/uyac -o app --c99
./bin/uya build main.uya --split-c-dir= -o app --c99       # 空值 → 默认 .uyacache
./bin/uya build main.uya --no-split-c -o app --c99         # 单文件 / 临时 .c
./bin/uya build main.uya -o app.c --c99                    # 显式 -o *.c → 单文件
```

- 布局：默认**镜像分 TU**（一源一 `.c`，外加 `uya_part1.c`、`uya_common.c` 等）；`UYA_SPLIT_C_MIRROR=0|false|no|off` 退回 `uya_part1+part2`。
- **separated 写法会吃掉下一个 argv**：`--split-c-dir` 后面只要有参数就当目录（`--split-c-dir -o app` 会把 `-o` 当目录名）。要保留默认目录请用 `--split-c-dir=`，或把它放到命令行最后。
- 同一输出目录**不支持并发写入**：第二个进程会在代码生成前直接报 busy（`<dir>/.uya-lock`）。
- 含 `@c_import` 时：单文件 `.c` 输出附带同名 sidecar（`app.cimports.sh`），split-C 则把导入的 C 直接写进 Makefile 的 object 规则。

细节见 [`multi_file_codegen.md`](multi_file_codegen.md)。

---

## 并行与增量编译

三层各管一段，互不冲突：

| 层面 | 手段 | 开关 |
|------|------|------|
| 前端（parse / codegen） | fork 多进程，按文件 / 按镜像 TU 分派，`mmap(MAP_SHARED)` 共享 AST | `--jobs N` / `-jN` / `UYA_JOBS` |
| C 阶段 | split-C + `make -jN` | `UYA_GCC_JOBS` |
| 增量 | 输入指纹短路 + 生成物 mtime 保持 + 签名式缓存清理 | `UYA_FORCE_BUILD` / `UYA_SPLIT_C_CLEAN` |

- 并行度默认 `min(CPU 核数, 32)`，并按任务数收敛；`1` 为全串行；Windows 目标没有 fork，自动串行。
- 指纹命中（源码 / 选项 / 编译器二进制都没变）时整轮编译跳过；`CI` / `GITHUB_ACTIONS` 下不短路，`make b` 永不短路。
- 实测：`make uya` 22.0 s → 14.0 s，无改动 0.4 s，`make b` 43.1 s → 26.6 s。详见 [`build_speed.md`](build_speed.md)。

---

## 内存安全证明

Uya 支持编译期内存安全证明，在编译时验证数组访问安全。

### 启用 / 关闭安全证明

```bash
./bin/uya --safety-proof source.uya -o app     # 默认即开启
./bin/uya --no-safety-proof source.uya -o app  # 临时关闭（调试用）
```

### 安全证明示例

```uya
// 安全：编译器可以证明
fn safe_access() void {
    var arr: [i32: 10] = [...];
    var i: i32 = 5;

    if i >= 0 && i < 10 {
        arr[i] = 42;  // 安全：已验证边界
    }
}

// 不安全：编译错误
fn unsafe_access() void {
    var arr: [i32: 10] = [...];
    var i: i32 = get_value();  // 未知值

    arr[i] = 42;  // 编译错误：无法证明安全
}
```

### 安全证明规则

1. **边界检查**：数组索引必须在编译期可验证范围内
2. **空指针检查**：指针解引用前必须通过空检查
3. **未初始化检测**：变量使用前必须初始化

### 越界访问检测

```uya
// 编译期常量检测
const arr: [i32: 10] = [0: 10];
const val = arr[5];   // SAFE: 编译期验证 5 < 10
// const err = arr[15]; // ERROR: 编译期检测到越界

// 变量索引区间分析
fn safe_index(arr: &[i32], i: i32) i32 {
    if i >= 0 && i < @len(arr) {
        return arr[i];  // SAFE: 已证明边界安全
    }
    return 0;
}
```

**检测级别**：
- `SAFE`：编译期可证明安全，无需运行时检查
- `WARNING`：需要运行时边界检查
- `ERROR`：编译期可证明越界，编译错误

v0.10.4 仍在账上的漏检（见 `CHANGELOG.md`）：取值路径的非线性下标（如 `a[w + h]`）、循环体内下标、切片形参下标、指针形参解引用尚未全部收口；`a / 0` 形式也还不报错。

---

## 编译期优化

### 优化级别控制

```bash
./bin/uya -O0 source.uya -o app     # 关闭内部优化（调试）
./bin/uya -O1 source.uya -o app     # 默认：常量折叠 + 死代码消除
./bin/uya -O2 source.uya -o app     # + 证明优化
./bin/uya -O3 source.uya -o app     # + 内联 / 循环展开标记
./bin/uya --opt=2 source.uya -o app # 长选项形式
```

注意 **`--opt=N` 只控制 Uya 自己的优化 Pass，不等于宿主 C 编译器的 `-O`**。C99 后端的宿主 `CFLAGS` 默认已是 `-std=c99 -O2 -fno-builtin`（v0.10.4 从 `-O0` 提升到 `-O2`），真正的指令级内联与展开由宿主 C 编译器完成。

### 优化级别说明

| 级别 | 功能 | 是否被 C99 后端消费 |
|------|------|--------------------|
| `-O0` | 无优化 | — |
| `-O1` | 常量折叠 + 死代码消除 | 是（`optimized_value` / `is_dead_code`） |
| `-O2` | + 证明优化（恒真条件去掉 if 包装） | 是（`is_proved_safe`） |
| `-O3` | + 内联 / 循环展开 | 目前仅做 AST 标记与统计（`is_inlined` / `is_unrolled`），后端尚未消费 |

### 常量折叠示例

```uya
const x: i32 = 10 + 20;  // 编译期计算为 30
const y: i32 = x * 2;    // 编译期计算为 60
const z: i32 = 100 / 5;  // 编译期计算为 20

// 生成的 C 代码直接使用计算结果
// int x = 30;
// int y = 60;
// int z = 20;
```

### 死代码消除示例

```uya
fn example() void {
    const x: i32 = 42;
    if false {
        // 死代码：编译期消除
        const y: i32 = unreachable_function();
    }
    // 只生成有效代码
}
```

### @asm 块优化

`src/checker/optimizer.uya` 会对 `@asm` 块做指令级分析：

```asm
# 优化前
mul r0, r1, r2
add r0, r0, r3

# 优化后（乘加融合）
madd r0, r1, r2, r3
```

**支持的融合模式**：乘加融合（MAC）：`mul` + `add` → `madd`

**冗余检测**：`nop` 等无副作用指令、自移动（`mov r0, r0`）、死寄存器写入。

---

## 调试输出

Uya 提供 `@print` 和 `@println` 内置函数用于调试输出，无需导入任何模块。

### 基本用法

```uya
fn main() i32 {
    // 打印整数
    @println(42);           // 输出: 42

    // 打印字符串
    @println("Hello");      // 输出: Hello

    // 打印变量
    const x: i32 = 100;
    @println(x);            // 输出: 100

    // 打印表达式
    @println(x + 50);       // 输出: 150

    // 打印浮点数
    @println(3.14159);      // 输出: 3.14159

    // 打印布尔值
    @println(true);         // 输出: 1

    return 0;
}
```

### @print 与 @println

- `@print(expr)` - 打印但不换行
- `@println(expr)` - 打印并换行

```uya
fn main() i32 {
    @print("Name: ");
    @print("Uya");
    @println("");           // 手动换行
    // 输出: Name: Uya

    @println("One line");   // 自动换行
    return 0;
}
```

### 字符串插值

```uya
fn main() i32 {
    const name: &byte = "World";
    const count: i32 = 42;

    @println("Hello, ${name}!");       // 输出: Hello, World!
    @println("Count: ${count}");       // 输出: Count: 42
    @println("Sum: ${count + 8}");     // 输出: Sum: 50
    return 0;
}
```

### 格式化输出

```uya
fn main() i32 {
    const num: i32 = 255;
    const pi: f64 = 3.14159;

    // 十六进制
    @println("hex: ${num:#x}");        // 输出: hex: ff
    @println("HEX: ${num:#X}");        // 输出: HEX: FF

    // 八进制
    @println("octal: ${num:#o}");      // 输出: octal: 377

    // 浮点精度
    @println("pi: ${pi:.2f}");         // 输出: pi: 3.14
    @println("pi: ${pi:.4f}");         // 输出: pi: 3.1416

    return 0;
}
```

### 返回值

`@print` / `@println` 返回 `i32`（printf 的返回值），可用于检测输出错误：

```uya
fn main() i32 {
    const result: i32 = @println("Hello");
    if result < 0 {
        return 1;
    }
    return 0;
}
```

### 不支持的类型

自定义结构体和联合体不能直接打印：

```uya
struct Point { x: i32, y: i32 }

fn main() i32 {
    const p: Point = Point { x: 1, y: 2 };
    // @println(p);  // ❌ 编译错误：该类型不支持 @print/@println

    // 手动打印字段
    @println("Point(${p.x}, ${p.y})");  // ✓ 正确
    return 0;
}
```

---

## 开发流程

### TDD 开发流程

```bash
# 1. 先写测试
vim tests/test_new_feature.uya

# 2. 运行单个测试，确认失败
./bin/uya test tests/test_new_feature.uya

# 3. 编写代码
vim src/related_module.uya

# 4. 重建编译器并跑相关回归
make uya
make tests-uya

# 5. 收口前跑完整验证
make check
```

### 先做语法 / checker 检查

怀疑问题出在语法、模块解析或类型检查阶段时，先只跑前端：

```bash
./bin/uya check your_file.uya
```

这不会进入代码生成与宿主 C 编译器，定位更快。

### 自举验证

```bash
make uya      # 构建编译器
make b        # 自举验证：编译自身 + 产物比对
```

自举对比是多文件 C 模式的 `cmp`（含 `-g` 时先剥离调试段与 build-id，再比对可执行代码）。

---

## 常见问题

### 编译段错误

多数是大依赖编译时栈空间不足。编译器启动时会自行把栈抬到 65536 KB；如需更大：

```bash
./bin/uya build big.uya -o app --stack-size 131072
```

脚本侧可配合 `ulimit -s 32768`（根 Makefile 的各构建目标已内置）。

### 找不到编译器

```bash
make from-c            # Linux：从种子恢复
make from-c-native     # macOS：从本机 hosted 种子恢复
make restore           # 仅恢复 bin/uya.c
```

### 增量构建看起来「没编译」

`make uya` 命中指纹时会打印「增量命中」并直接返回。需要强制重建：

```bash
UYA_FORCE_BUILD=1 make uya
```

### split-C 报 busy

同一 `--split-c-dir`（含默认 `.uyacache`）不支持并发写。给每个任务分配独立目录或串行化调用。

### 测试失败

```bash
# 单个程序
./tests/run_programs_parallel.sh test_xxx.uya

# 只生成 C，手动排查
./bin/uya build tests/test_xxx.uya -o /tmp/test.c --c99 --no-split-c
cc -std=c99 -O2 -fno-builtin /tmp/test.c -o /tmp/test && /tmp/test
```

---

## 更多资源

- [语法快速参考](grammar_quick.md)
- [语法正式规范](grammar_formal.md)
- [内置函数](builtin_functions.md)
- [测试指南](TESTING.md)
- [变更日志](changelog.md)
- [@asm API 参考](asm_api_reference.md)
- [编译期优化状态](compile_time_optimization_status.md)
- [编译提速：并行与增量](build_speed.md)
- [多文件 C 输出](multi_file_codegen.md)
