# 编译提速：并行编译与增量编译

**更新日期**：2026-10-19

本文记录 Uya 自举构建的三层提速机制、实测数据与全部相关开关。

## 一、构建链的分段

一次 `make uya`（Linux / `--nostdlib` 主线）实际上是两段：

1. **前端**（`bin/uya build src/main.uya`）：解析 → AST 合并 → 类型检查 → 优化 → C99 代码生成。
   这一段是**单个 uya 进程**内的 CPU 工作。
2. **C 阶段**（`make -C src/.uyacache -jN`）：把生成的 100+ 个 `.c` 分别 `cc -c`，再链接。

两者瓶颈性质完全不同，提速手段也不同：前端靠**进程级并行**，C 阶段靠 **make -j** 与**增量**。

## 二、实测基线（44 线程 / gcc 12.3 / Intel 主机）

| 场景 | 提速前 | 现在 |
|---|---:|---:|
| `make uya` 全量 | 22.0 s | **14.0 s** |
| `make uya` 无改动 | 22.4 s | **0.4 s** |
| `make uya` 只改注释（生成 C 不变） | 22.0 s | **14.0 s**（C 阶段 0 个 TU 重编） |
| `make b` 自举验证 | 43.1 s | **26.6 s** |
| 前端 解析（parse） | 2.25 s | **0.54 s** |
| 前端 代码生成（codegen） | 6.70 s | **2.62 s** |
| C 阶段 `make -j` | `-j16` 4.83 s | `-j44` **4.39 s** |

前端 parse 与 codegen 的数字来自 `bin/uya build ... --jobs=N --verbose` 的「编译统计」段落。

## 三、前端进程级并行（`--jobs` / `UYA_JOBS`）

### 3.1 为什么是多进程而不是多线程

编译器是单进程、零 GC 的实现，模块级可变全局有数百个（`src/checker/*` 单独就有上百个），
codegen 还依赖大量文件级静态缓存（`g_c99_identifier_type_*`、`g_c99_string_const_*` 等）。
在这些状态上做多线程等于重写整个 codegen 的并发模型。

fork 出来的子进程对父进程的只读堆是 COW 共享的，而前端各阶段天然是
「父进程准备 + 子进程只读消费」，因此用 fork 拿到的并行度与线程相同，却不引入任何新竞态。

### 3.2 并行 parse（`src/parse_parallel.uya`）

parse 是「每个文件独立」的：lexer + parser 只依赖该文件内容和一个 arena，
`src/parser/*.uya`、`src/lexer.uya`、`src/ast.uya` 都没有模块级可变全局。

- 输入文件按**轮转**分给 N 个 fork 出来的子进程；
- 每个文件一个 `ParseSlot`（AST 根指针 + 状态码），放在 `mmap(MAP_SHARED|MAP_ANONYMOUS)` 的
  共享映射里，AST 节点也落在共享切片中，因此**父进程可以直接读，不需要任何 AST 序列化**；
- 每个 worker 的 arena 切片按其负责的源码字节数 × 320 字节估算（实测约 165 字节/字节源码，留 2 倍余量）；
- 切片不足时 `compiler_arena_alloc` 会退到私有 `malloc` chunk，worker 检测到
  `current_chunk != null` 就判定溢出并整体放弃；
- 任何失败（切片不足 / 读文件失败 / 词法或语法错误 / fork 失败）都会让父进程按原串行循环重做，
  因此**报错文本与顺序与串行完全一致**。

### 3.3 并行 codegen（`src/codegen/c99/parallel.uya`）

codegen 可以切成两段：

| 段 | 内容 | 能否并行 |
|---|---|---|
| 序言（第一~八步 + 第九步 a/b0/b1 的全局变量） | 字符串池、类型/枚举/结构体/err_union、前向声明、vtable、syscall 助手、测试声明、全局变量定义 | **必须串行** |
| 函数体（第九步 b 的函数/方法、第十步测试、第十一步 main） | 每个声明只影响它所属的那一个镜像 `.c` | **按镜像 TU 并行** |

fork 点就在「全局变量全部发射完、函数体开始之前」。三个硬约束：

1. **共享注册表必须已闭合**：字符串常量 / embed 常量 / 单态化实例若在函数体阶段还新增，
   不同 worker 会给同一个字符串分配不同的 `strN`，产物必然错。worker 结束前用
   `c99_parallel_registry_closed` 复核三个计数，漂移即放弃。
2. **跨 TU 写入即违规**：极少数路径（async inline 子函数预定义）会按子声明自己的源文件
   路由到另一个 TU，那会让两个进程同时写同一个文件。`c99_mirror_emit_for_node` 在这类
   情况下置 `parallel_violation`，worker 直接放弃。
3. **全局变量必须在 fork 前登记完**：`gen_global_var` 一边发射一边把全局变量登记进
   `codegen.global_variables[]`，而标识符类型查找只扫这张表、**不回退** `program_decls`
   线性扫描。若各 worker 只登记自己那几个 TU 的全局变量，跨 TU 引用会解析成不同的 C 名
   （曾实测出现 `PATH_MAX` 退化成 `libc_PATH_MAX`，以及指针比较退化成逐字段比较）。
   因此第九步 a / b0 / b1（const、非 export 非常量、export 非常量）全部留在父进程串行发射。

worker 的输出先写 `<tu>.uyabody` 临时分片，**全部 worker 都成功**时父进程才把它们追加进真正的
TU 文件；任何失败都只是删掉临时文件再串行重做一遍，永远不会留下半个 TU。

另外 `codegen.interp_temp_counter`（`__uya_ifexpr_N` / `__uya_interp_N`）现在**按函数复位**，
这样同一份源码在不同发射顺序（串行 / 并行）下会产生完全相同的 C 文本。

### 3.4 开关

| 开关 | 含义 |
|---|---|
| `--jobs N` / `-jN` | 前端并行度（1 = 全串行；上限 32） |
| `UYA_JOBS=N` | 环境变量形式（`--jobs` 优先） |

并行度默认取 `min(CPU 核数, 32)`，并按任务数收敛（文件数 / TU 数）。
Windows 目标没有 fork，`parallel_available()` 返回 0，自动全串行。

## 四、C 阶段并行度

`UYA_GCC_JOBS` 控制 split-C 目录里 `make -j` 的并行度：

- 根 `Makefile`：`UYA_GCC_JOBS ?= $(UYA_TEST_JOBS)`，即默认 CPU 核数；
- `src/compile.sh`：未设置时按 `nproc` / `sysctl -n hw.ncpu` 自动探测（兜底 4），不再封顶 16
  （原先默认 16 在 44 线程机器上白白丢掉约 9%）；
- `src/driver/toolchain.uya`（`uya build` 自己发起的 split 链接）在**未设置** `UYA_GCC_JOBS`
  时仍取字面量 16；根 Makefile 的所有自举目标都显式传入 `UYA_GCC_JOBS="$(UYA_GCC_JOBS)"`
  （= CPU 核数），因此 `make uya` / `make b` 走的是 CPU 核数。

实测 `-j8 / -j16 / -j44` = 6.80 s / 4.83 s / 4.39 s。关键路径是单个大 TU
（`src/codegen/c99/expr.c`，约 1 MB，单文件 `cc -c` 需 3.5 s），所以再提高并行度收益有限。

## 五、增量编译

### 5.1 指纹短路（无改动直接跳过整轮编译）

`src/compile.sh` 在调用编译器之前先算一次输入指纹：

```
sha256( 构建签名 + 编译器命令行 + 编译器二进制内容 + 全部输入源文件内容 )
```

指纹写入 `<split-dir>/.uya-build-stamp`；命中且 `make -q -C <split-dir>` 认为 C 目标全部就绪时，
直接输出「增量命中」并退出，整轮编译跳过（实测 22 s → 0.4 s）。

- `CI` / `GITHUB_ACTIONS` 下**默认不短路**，保证每次都能真正验证；
- `UYA_FORCE_BUILD=1` 强制重建；
- `make b`（自举对比）**永不短路** —— 比对本身就是验证；
- 输入集合取自 `<split-dir>/mirror_manifest.txt`（上一轮真实参与编译的源文件列表）。

### 5.2 生成物 mtime 保持（只重编真正变化的 TU）

uya 写 `.c/.h` 是无条件覆盖，mtime 必然变新，于是 `make` 会重编全部 TU。
`src/compile.sh` 在生成前后各算一次内容哈希：**内容没变的文件把 mtime 还原**，
`make` 就只重编真正改动过的 TU。实测「只加一行注释」的改动 C 阶段重编 **0 个 TU**。

### 5.3 签名式缓存清理

原先每次编译都整目录清掉 split 缓存。现在把
`TOOLCHAIN / CC_DRIVER / CC_TARGET_FLAGS / CFLAGS / LDFLAGS / TARGET_OS / TARGET_ARCH / 镜像开关`
写进 `<split-dir>/.uya-build-sig`：签名一致就**保留**既有 `.c/.o`，只有签名变化
（或 `UYA_SPLIT_C_CLEAN=1`）才走旧的整体清理。清理仍然遵守既有契约：
只删 Uya 生成物，不动目录里的外来 `.c/.h`。

## 六、相关测试

| 测试 | 覆盖内容 |
|---|---|
| `bash tests/verify_parallel_frontend.sh` | `--jobs 1` 与 `--jobs 8` 生成的 C 逐字节一致；无 `*.uyabody` 残留；语法错误报错一致 |
| `bash tests/verify_compile_incremental.sh` | 指纹短路命中 / `UYA_FORCE_BUILD=1` 强制重建 / 改源码后不再命中 / 生成 C 未变时 C 阶段不重编 |
| `bash tests/split_c_smoke.sh` | split-C 基本可用性 |
| `bash tests/verify_compile_sh_split_cache_cleanup.sh` | 签名式清理不误删外来源码 |

## 七、复现命令

```bash
# 前端分段耗时（含并行度对照）
cd src
UYA_ROOT=$(pwd)/../lib/ ../bin/uya build "$PWD/main.uya" -o /tmp/uya.c \
  --c99 --nostdlib --safety-proof --jobs 8 --verbose

# 前端热点（默认已修掉 arena 每分配一次 getenv 的热点）
perf record -F 997 -g -- ../bin/uya build "$PWD/main.uya" -o /tmp/uya.c --c99 --nostdlib --safety-proof
perf report --no-children --sort symbol

# 生成阶段子计时
UYA_PROFILE_CODEGEN=1 ... --verbose

# 共享注册表闭合探测（并行 codegen 的前提）
UYA_PROFILE_REGISTRY=1 ... --verbose

# 各阶段 arena 用量（用于给并行 parse 的切片定容）
UYA_PROFILE_ARENA=1 ... --verbose
```

## 八、还没做的

- **并行类型检查（checker）**：`checker_check_program_node` 按「var → use → other」固定顺序推进，
  期间写符号表、单态化队列、错误列表并回写 AST 节点类型，后一个声明依赖前一个的声明结果；
  加上 100+ 模块级全局与错误顺序敏感，本轮不做。可行的后续设计是
  「先声明后检查、按文件 fork 检查体、错误按文件序合并」。
- **拆大 TU 进一步压 C 阶段关键路径**：`src/codegen/c99/expr.uya`（1 万行、生成 1 MB C）
  决定了 `make -j` 的下限。拆成两个源文件可把 C 阶段从 4.4 s 压到约 2.6 s，
  但需要同步 `use`、`src/compile.sh` 的手写文件列表与镜像说明，单独排期。
- **不引入 ccache**：头文件全量变化时基本全 miss，且会引入外部依赖。
