# 编译提速：并行编译与增量编译

**更新日期**：2026-11-16

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

### 2.1 2026-11 复测（同一台 44 核机器，load ≈ 5，仅作相对比较）

绝对数字受机器负载影响明显（本轮机器上有两个与构建无关的 50% CPU 进程），
所以下面每一条都是**前后脚背靠背**测出来的差分，而不是跨时间点的绝对值：

| 场景 | 改动前 | 现在 | 差分 |
|---|---:|---:|---:|
| `make uya` 无改动（指纹命中） | 0.38 s | **0.16 s** | −0.22 s（批量 `sha256sum`） |
| C 阶段 `make -j44`，OBJS 按声明数排 vs 按实际 C 体积排 | 6.13 s | **5.84 s** | −0.29 s（LPT 排序） |
| `make uya` 全量强制 | 15.0 s | **14.5 s** | −0.5 s |
| `make b` 自举验证 | 28.5 s | **27.4 s** | −1.1 s |

剩下的时间分布（`CC=/bin/true` 把 C 阶段压成 0 后测前端）：
前端 7.9 s（其中类型检查 6.5 s）、C 阶段 5.9 s、链接与脚本开销约 0.7 s。
类型检查是最大单项，见 §2.2 与 §八。

### 2.2 2026-11 第二轮：类型检查器的两处 O(N) 退化（−3.4 s）

`perf record` 在 `uya check src/main.uya` 上抓到两个各占约 30% 的循环，都是「数据量一涨就从
O(1) 变成 O(N)」的结构问题，而不是常数因子问题：

1. **顶层可达性 visited 集写死容量**（`src/checker/symbols.uya`）。原实现是 262144 个槽位的
   开放寻址表，`checker_mark_reachability_node_visited` 在表满后直接 `return 1`
   —— 把「已访问」静默判成「首次访问」，可达性传播于是退化成指数级重复展开，而且**没有任何报错**。
   改成 arena 拥有的**可增长**表：负载因子超过 3/4 时容量翻倍并整表 rehash
   （`checker_reachability_visit_grow` / `checker_reachability_visit_ensure`）。
   初始容量沿用历史值，小工程不发生扩容，行为与改动前逐字节一致。
2. **作用域符号查找扫整条链**（`src/checker/symbols.uya`）。`symbol_table_lookup` 从最内层作用域
   逐层扫 `Symbol.next_in_scope` 链表，链上每一跳都要读一个散落在 400 MB arena 里的 `Symbol`
   （几乎必然 L1 miss），而直接映射的查找缓存又被「每次插入自增的 generation」立刻打掉。
   两处改动：
   - `Symbol.name_hash`：插入时算一次 `hash_string` 落盘，查找先比整数、相等才去碰名字的字节；
     去重扫描（`symbol_table_insert`）与退出作用域（`checker_exit_scope`）也复用这个缓存哈希。
   - `TypeChecker.scope_buckets`：每层 512 个名字哈希桶（下标 `scope*512 + (hash&511)`，
     链用 `Symbol.next_in_bucket` 串），查找一层只扫一个桶（通常 1~2 个符号）。
     退出作用域时整层桶头清零（`checker_scope_buckets_clear`），保证同层兄弟块看不到上一轮的符号。
3. **程序级声明的线性扫描**（`src/checker/lookup.uya`、`src/checker/macro_expand.uya`）。
   `checker_fn_decl_owner_type_name` 与 `checker_fn_decl_is_owned_method` 各自扫
   「全部 program_decls × 每个类型的方法表」，`find_macro_decl_from_program` 扫整张声明表，
   三处合计约 12% 采样，而且直接映射缓存被指针哈希撞掉后每次都要整表重扫。改法：
   - 前两者共用一张 **fn_decl →（所属类型名, 是否 union）** 的开放寻址索引
     （`ensure_owner_method_index`：首次查询时一遍扫描建好，16384 槽、负载 3/4 记溢出，
     溢出即自动退回原来的线性扫描，语义与「首个匹配胜出」完全一致）；
   - 宏查找改走已有的程序级声明索引（`progdecl_index_find_typed`，该索引本来就收
     `AST_MACRO_DECL` 的确切名），索引不可用时退回整表扫描。

背靠背实测（同一台 44 核机器，load ≈ 3.8，old/new 交替）：

| 场景 | 改动前 | 现在 | 差分 |
|---|---:|---:|---:|
| `uya check src/main.uya` | 7.10 s | **3.41 s** | −52% |
| `make uya` 全量强制（A/B 交替 old/new/old/new） | 14.89 / 15.18 s | **13.21 / 12.45 s** | ≈ −2.2 s（−15%） |
| `make b` 自举验证 | 27.4 s | **23.3 s** | −4.1 s |
| 前端类型检查（`--verbose`） | 6.19 s | **3.41 s** | −2.8 s |

两者的收益并不相等：`uya check` 只看前端，所以直接吃掉 3.4 s；`make uya` 里前端省下的时间会被
C 阶段（关键路径是一个 1.13 MB 的 TU）与调度抖动吸收掉一部分，实际体现为 1~2 s（看机器负载）。

产物不变：`make b` 自举比对字节相同，全量测试通过。

检查器现在剩下的热点是**程序级声明的线性扫描**：`checker_fn_decl_owner_type_name` 3.9%、
`find_macro_decl_from_program` 2.8%、`checker_fn_decl_is_owned_method` 2.5%，合计约 0.35 s，
属于下一轮的低优先级项（见 §八）。

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

因此镜像 Makefile 的 `OBJS` **按实际 C 体积降序**输出（`c99_mirror_lpt_order`：体积取
`ftell` 到的已发射字节数，取不到时退回声明数）。`OBJS` 的顺序就是 `make` 的启动顺序，
最大的 TU 必须第一个开始编译，否则它最后才开始、把整段 C 阶段拖成「最慢 TU + 排队时间」。
背靠背实测：把 `OBJS` 反过来（小 TU 先开工）6.13 s，按体积降序 5.84 s（−5%）。

### 4.1 大文件切块（实验开关，默认关闭）

`--split-c-dir` 的镜像模式默认「一个源文件一个 TU」。`UYA_SPLIT_CHUNK=1` 时，顶层声明数
超过 `C99_MIRROR_CHUNK_DECLS`（48）的源文件会被切成最多 4 块（`expr.uya` →
`expr.c` / `expr_c2.c` / …）。路由表 `parallel_decl_tu` 同时承担三件事：并行归属、
分块路由、Makefile 排序权重。

几条硬约束（都是测试踩出来的，全部写在 `c99_mirror_slot_count_for_key` 里）：

- **非函数声明一律钉在块 0**：C 的 const 不是常量表达式，`const size_t B = A | 2;` 要求 A
  在同一个 TU。现场：`lib/libc/heap.uya` 的 `CHUNK_STATE_MASK = CHUNK_FLAG_FREE | CHUNK_FLAG_TCACHE`、
  `lib/libc/math.uya` 的 `libc_HUGE_VALF = (float)libc_INFINITY`，跨块会报
  `initializer element is not constant`。
- **`lib/libc/stdio.uya` 整文件不拆**：stdin/stdout/stderr 三个宏是按源文件判断的，
  拆开后非首块拿到的就是 libc 的 `stdout` 符号（`--nostdlib` 下没有 `<stdio.h>`）。
- **`lib/std/async_frame.uya` 整文件不拆**：`_uya_async_frame_descriptors` 的**定义**由收尾阶段
  一次性发射到 `uya_common.c`，而 `extern` 声明跟着声明所在的源文件走。
- **程序里只要有 `async fn` 就整体关闭切块**：async 变换生成的 `<fn>_poll` / `<fn>_frame_stop`
  是 `static`，定义只发射一次，拆块后同文件其它块只拿到前向声明，链接报
  `undefined reference to <fn>_poll`。
- 切块数按并行度收敛：≤4 核不切，>16 核才允许 4 块（切块用「重复解析 ~700 KB 头」的固定
  开销换关键路径，核少时纯亏）。

实测（44 核，同一台机器前后脚，前端并行度 32）：

| | TU 数 | 前端 codegen CPU | C 阶段 `-j44` | 全量合计 |
|---|---:|---:|---:|---:|
| 不切块（默认） | 106 | 0.94 s | 5.89 s | **13.8 s** |
| 切块 | 164 | 6.55 s | 4.22 s | 18.7 s |

C 阶段确实快 28%（最大 TU 从 1.13 MB 降到 890 KB），但 codegen 的 body 阶段 CPU 从 0.94 s
涨到 6.55 s，净亏约 5 s —— 所以**默认关闭**，只保留 `UYA_SPLIT_CHUNK=1` 做实验。

正确性侧是干净的：拆分前后产物 `diff -r` 逐字节一致，`make b` 自举比对通过，
`tests/verify_async_nested_split_codegen.sh`、`tests/split_c_smoke.sh` 均通过。
未定位的问题：多出来的 5.6 s 与槽位数量成正比，但**不在**「节点→槽位」路由上
（给路由加 filename 指针 O(1) 快路径后毫无改善），下一步应在 body 发射循环里按槽位
统计调用次数与字节数，找出「每槽位一份」的重复工作。定位后把
`c99_split_mirror_prepare` 里的 `allow_chunk` 默认值改成 1 即可。

## 五、增量编译

### 5.1 指纹短路（无改动直接跳过整轮编译）

`src/compile.sh` 在调用编译器之前先算一次输入指纹：

```
sha256( 构建签名 + 编译器命令行 + 编译器二进制内容 + 全部输入源文件内容 )
```

指纹写入 `<split-dir>/.uya-build-stamp`；命中且 `make -q -C <split-dir>` 认为 C 目标全部就绪时，
直接输出「增量命中」并退出，整轮编译跳过（实测 22 s → 0.4 s，批量算哈希后 0.16 s）。

源文件哈希、生成物快照/还原都是**一次 `sha256sum` + 一次 `stat` 处理全部文件**，
不再「每个文件两个子进程」（镜像模式下 160+ 个 `.c/.h`、110+ 个源文件，光 fork 就 300+ 次）。

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
| `bash tests/verify_async_nested_split_codegen.sh` | 含 async 的程序在镜像模式下能编译链接（切块必须整体关闭） |
| `bash tests/verify_split_c_makefile_dependencies.sh` | 镜像 Makefile 的依赖关系（每个 `.o` 只依赖自己的 `.c` 与生成的头） |

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

# 切块实验开/关的前端 codegen 子计时（对比 body_ms）
UYA_SPLIT_CHUNK=1 UYA_PROFILE_CODEGEN=1 ... --verbose

# 只测前端：把 C 阶段压成空操作
UYA_JOBS=32 CC=/bin/true UYA_SPLIT_C_DIR=/tmp/x ../bin/uya build "$PWD/main.uya" -o /tmp/x/a \
  --c99 --nostdlib --safety-proof

# 共享注册表闭合探测（并行 codegen 的前提）
UYA_PROFILE_REGISTRY=1 ... --verbose

# 各阶段 arena 用量（用于给并行 parse 的切片定容）
UYA_PROFILE_ARENA=1 ... --verbose
```

## 八、还没做的

- **并行类型检查（checker）**：`checker_check_program_node` 按「var → use → other」固定顺序推进，
  期间写符号表、单态化队列、错误列表并回写 AST 节点类型，后一个声明依赖前一个的声明结果；
  加上 100+ 模块级全局与错误顺序敏感，本轮不做。可行的后续设计是
  「先声明后检查、按文件 fork 检查体、错误按文件序合并」。§2.2 之后类型检查 3.7 s，
  仍是前端最大单项。
- **切块的「每槽位重复开销」**（最高优先）：§4.1 的分块实现已就绪、正确性已验证，
  但 164 个槽位时 codegen body 阶段 CPU 从 0.94 s 涨到 6.55 s，把 C 阶段的 1.7 s 收益
  吃光（2026-11 复测：不切块 12.9 / 14.0 s，切块 17.3 / 17.9 s）。定位并消掉这段重复工作，
  就能把 `allow_chunk` 默认打开，C 阶段直接 −28%。
- **codegen 局部变量类型查找**：`lookup_identifier_type_c_impl` 的缓存槽把
  `local_variable_count` 编进了键，每加一个局部变量就整体失效，退化成线性 `strcmp` 扫局部数组。
  它占 codegen CPU 的 16.8%，但 body 阶段按镜像 TU 并行（默认 32 worker），对 `make uya`
  的实际墙钟贡献只有约 0.1 s，优先级低于上面两项。
- **不引入 ccache**：头文件全量变化时基本全 miss，且会引入外部依赖。
