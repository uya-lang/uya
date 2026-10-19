# Uya 语言版本变更日志

本文档记录 Uya 语言的所有版本变更历史。

---

## 0.6x 版本变更（规划中）

**发布日期：** 待定

### `--strict-overflow` 静态溢出闸门（规范 0.49.55，2026-10-19）

- **行为**：开启后普通上下文的整数 `+` `-` `*` 必须能证明不溢出，否则报编译错误：
  `i32 溢出无法证明（--strict-overflow）：改用 try a + b、(a + b) catch、加区间守卫，或用饱和/包装运算符`。
- **只覆盖有符号整数**：C99 无符号算术是良定义模运算，不是 UB；强制证明只会禁掉二补数取负
  与散列/校验和里的有意回绕，换不来安全性。`try` 仍可用于无符号的运行时检查。
- **默认关闭**：仓库自身（`src/` + `lib/`）开启后报约 447 处（仅计有符号，`i8`/`i16` 为 0），
  翻默认需先完成存量迁移或引入参数/返回值区间契约。
- **消除 C UB**：构建与生成代码统一加 `-fwrapv -fno-strict-overflow`，未证明的有符号溢出
  退化为定义良好的回绕，不再有 `-O2` 下被任意误编译的风险（实测 `-fsanitize=undefined` 由报错转为干净）。
- **证明器**：`checker_prove_no_overflow`（`src/checker/proof.uya`）基于 i64 宽化区间
  （`wide_*`，`src/checker/interval.uya`）；加法/减法做显式溢出预处理，乘法限制端点 ≤ 2^31。
  只采纳 `constraint_sound = 1` 的约束（用户守卫、无回绕的 `i = i + c`、直接常量初始化），
  抽象区间计算（`eval_expr_interval`，内部 u32 回绕）产出的约束一律不可信。
- **豁免**：`try`/`catch` 的 checked 算术操作数（运行时检查负责）、饱和 `+|`/`-|`/`*|`、
  包装 `+%`/`-%`/`*%`、浮点与向量算术。
- **CLI**：`--strict-overflow` / `--no-strict-overflow`。
- **回归**：`tests/verify_strict_overflow.sh`（已并入 `make check`）。

### 区间契约 `@range(lo, hi)`（规范 0.49.55，2026-10-19）

- **语法**：`x: i32 @range(0, 1000)`（参数）、`var c: i32 @range(0, 1000000) = 0;`（局部变量）、
  `fn f(...) i32 @range(0, 2000)`（返回值）。复用 `@` 声明属性风格，无新关键字。
- **语义**：**声明式假设**，不做运行时检查（与 `@align` 同类）；调用方负责满足。
  参数/局部契约在函数体内作为可信约束参与溢出与越界证明；返回契约成为调用点可依赖的区间。
- **价值**：让 `--strict-overflow` 能覆盖「参数位置算术」「调用结果算术」「无上界计数器」
  这三类**本质上无法静态推断**的场景，是翻默认闸门的前置能力。
- **限制**：`lo`/`hi` 为整型常量表达式（支持 `@max`/`@min`），不支持依赖其他参数的区间。
- **测试**：`tests/test_range_contract.uya`（7 用例）；`verify_strict_overflow.sh` 第 6 项。

### `try`/`catch` 支持整数溢出检查（规范 0.49.55，2026-10-19）

- **语义**：`!T` 的操作数集合扩展为两类 —— ① 本身是错误联合类型；② **整数算术表达式**（根为
  `+` `-` `*` `/` `%` 或一元 `-`）。后者按 **checked 算术**求值：越界 → `error.Overflow`，
  除数为 0 → `error.DivisionByZero`，有符号 `MIN / -1`、`MIN % -1` → `error.Overflow`。
  整棵算术树共享一次检查，每棵子树只求值一次。`try`/`catch` 原有规则（操作数须提供 `!T`）不变。
- **写法**：`try a + b`（传播；操作数走相对表达式，无需加括号）与 `(a + b) catch |e| { … }`
  （就地处理；`catch` 是 cast 级后缀，必须给整条算术加括号）。
- **兼容性**：非 `try`/`catch` 上下文的 `a + b` 行为完全不变；此前被判「操作数必须是错误联合类型」
  的 `try a + b` 现在合法 —— 纯增量，无破坏性变更。
- **入口 main**：`export fn main() !T` / `fn main() !T` 现在可链接运行：用户函数发射为
  `uya_main_result()`，编译器发射 `int32_t main_main(void)` 桥接解包，成功值作为退出码，
  未捕获错误打印 `未捕获的错误: <name>` 并返回 1。
- **顺带修复**：`gen_return_error_union` 的「标识符名含 result 即视为错误联合」启发式原先会误判
  `return result;`（`result: i32`，函数返回 `!i32`）从而生成非法 C；现在以类型判定优先于名字猜测。
- **测试**：`tests/test_try_overflow_arith.uya`、`test_try_overflow_div.uya`、`test_try_overflow_catch.uya`、
  `test_try_overflow_types.uya`；负例 `tests/error_try_overflow_*.uya`（4 个）。

### 规范文档同步 v0.10.4（2026-10-19）

本轮按 `src/` 实现回填语言规范，规范版本升到 **0.49.54**（详见 `uya.md` 的「规范变更」）：

- **类型化管道 `|>`**：收录 `pipeline_expr = or_expr { '|>' postfix_expr }`（左结合，优先级在 `||` 与 `=` 之间）与类型规则：左侧必须 `Pipeline` / `!Pipeline`，右侧最外层必须是调用，callee 首参必须是 `Pipeline`，`!Pipeline` 走 try-forward；`Pipeline` 是 `std.process` 的不透明 move-only 执行计划。
- **`@align(N)` 声明属性**：写在 `fn` 前、`@async_fn` 之前，设置异步状态机帧对齐；属声明属性而非 `@` 内置函数。
- **`for` 迭代**：受体是定长数组 / 迭代器接口 / 整数范围；切片不能直接 for 迭代；`for obj |i|` 只是值绑定，**没有**专门的索引迭代形式（需要索引用 `for 0..@len(obj) |i|`）；数组也不支持 `for obj {}`。
- **`try` 语义**：只做 `!T` 错误传播，不做算术溢出检查（`try a + b` 报错）；溢出改用区间证明或饱和/包装运算符。
- **切片**：没有负数索引，`&arr[-3:3]` 会切出越界内容（缺口登记在 `buglist.md`）。
- **`extern struct`**：语言没有这个声明语法；`extern` 只支持 `extern fn` / `extern union` / `extern const|var`，Uya `struct` 统一 C 布局。
- **复合赋值**：`+=` `-=` `*=` `/=` `%=` 支持；只有 `&=` `|=` `^=` `<<=` `>>=` 与 `++`/`--` 不支持。
- **清单对齐**：关键字表、类型表（补 `isize`）、内置函数表（补 `@params` / `@src_*` / `@func_name` / `@print` / `@println` / `@syscall` / `@asm_target` / `@ptr_from_usize` / `@usize_from_ptr`）、标准库模块清单按 `lib/std/` 实际导出核对。

### Hosted Web / unknown target：libc/syscall bridge smoke（2026-05-20）

- **运行时桥接**：`lib/libc/syscall.uya` 在 `std.target_os == .tos_unknown` 下补入一组受限 `libc.sys_*` 实现，通过宿主 bridge 覆盖 `read/write/open/close/mmap/gettimeofday/clock_gettime/nanosleep` 等 bring-up 所需路径，避免与仓库内同名 wrapper 递归。
- **libc / runtime 收口**：`heap`、`unistd`、`stdlib`、`stdio`、`pthread`、`signal`、`setjmp` 与 `std.runtime.entry` 同步补入 unknown 目标分支或保护，确保 Web/Node hosted smoke 不再误走 Linux 栈限制与原生 syscall 路径。
- **测试入口**：新增 `tests/emcc_unknown_runtime_smoke.uya`、`tests/emcc_unknown_host.c`、`tests/verify_emcc_unknown_runtime.sh` 与 `make tests-emcc`；该 smoke 需本机安装 `emcc` 与 `node`，当前不默认并入 `make check` / `make release-dirty`。

### 语言：对象方法无限制链式调用（2026-04-26）

- **Parser**：统一了后缀表达式链的解析，`.` / `[]` / `()` 现在都可以在同一对象表达式后无限继续组合。
- **方法调用**：以下形式现都属于同一条主链能力，后续可继续接成员访问或方法调用：
  - `Struct{ ... }.method().next()`
  - `(expr).method().next()`
  - `arr[i].method().next()`
  - `obj.method<T>(...).next()`
- **Checker**：方法参数与返回类型现在会基于实际 receiver 继续替换 `Self`、owner 泛型和方法泛型，因此匿名表达式上的实例方法返回值也能继续正确参与下一段链。
- **测试**：新增 `tests/test_struct_method_chain.uya`，覆盖结构体字面量链、泛型方法链、括号表达式链、数组下标结果链。
- **文档**：同步更新 `uya.md`、`grammar_quick.md`、`grammar_formal.md`、`compiler_status.md`，并修正文档中遗留的静态方法旧语义描述。

### 标准库 HTTP / UyaGin P7：Benchmark Harness（2026-04-25）

- **Benchmark 服务端**：新增 **`benchmarks/uyagin_http_bench.uya`**，基于 `std.http.uyagin` 固化 P7 五个场景：**12B plaintext**、**100B JSON**、**`/users/:id`**、**middleware x3**（disabled logger + recovery + auth stub）以及 **64KiB body**。
- **Gin 对照实现**：新增 **`benchmarks/uyagin_http_bench_gin/main.go`**，在相同路由与响应负载下提供 Gin baseline，构建时统一使用 **`go build -ldflags="-s -w"`**。
- **统一 runner**：新增 **`benchmarks/run_uyagin_http_bench.py`** 与 shell 包装 **`benchmarks/run_uyagin_http_bench.sh`**；runner 负责统一编译、启动服务、执行 **5 次 wrk/wrk2** 采样、记录 **CPU governor / kernel / ulimit / somaxconn**、汇总 **median / p99**，并导出 **JSON/CSV** 报告。
- **热路径指标采集**：runner 会读取 UyaGin **`heap_fallback_count`** / frame 指标，并在环境支持 `strace` 时对 hello 场景补充 **syscall/req** 统计；同时新增 **same-RPS keep-alive CPU probe**，对 `hello plaintext` 在相同目标 RPS 下比较 Uya/Gin 的 `user+sys` CPU。
- **阈值判断**：报告现内置 P7 **RPS / p99 / alloc / syscall / CPU** 目标阈值，生成逐场景 pass/fail 字段，并支持 **`--fail-on-target`** 用于 CI / 回归门禁。
- **核心热路径修正**：为避免 benchmark 走专用旁路，`std.async_scheduler` 现改为 **lazy eventfd**，`std.http.uyagin` 的 `uyagin_conn_read_parse_async` 改为手写 Future，`uyagin_engine_run` 也补入 “`Pending` 但未挂 fd 时立即重试” 逻辑；`benchmarks/uyagin_http_bench.uya` 已切回官方 **`engine.run_shards()`** 主链路。
- **验证**：新增 **`tests/verify_uyagin_http_bench_runtime.sh`**，覆盖 benchmark 服务器的核心路由与 body 长度校验。

### 标准库 HTTP / UyaGin P6：可观测性与生产配置（2026-04-25）

- **`std.http.uyagin`**：新增 **`UyaginMode`**、**`UyaginAccessLogOptions`**、**`UyaginConfig`**，并扩展 **`EngineRunOptions`** 支持 **`listen_backlog`**、**`buffer_cap`**、**`request_arena_cap`**、**`mode`**。
- **Access log / error trace**：`engine.handle(...)` 外层补入统一 observation wrapper；access log 现支持开关与 **`sample_every`** 采样，并使用固定栈缓冲零分配格式化；recovery / limit error 现可输出带 **`@src_path`** / **`@src_line`** 的 trace。
- **Metrics**：`UyaginMetrics` 扩展为同时统计 **request count**、常见 **HTTP status**、延迟直方图、accept/close/active 连接数，以及既有 arena/frame allocator 指标。
- **生产运行配置**：新增 **`uyagin_new_with_config`**、**`uyagin_set_config`**、**`uyagin_set_run_options`**、**`uyagin_set_access_log_options`**、**`uyagin_listen_loopback_with_options`**、**`uyagin_listen_loopback_with_config`**；`engine.run()` / `run_shards()` 默认直接使用 engine 上配置。
- **测试**：更新 **`tests/test_http_uyagin.uya`** 覆盖 access log 采样/禁用、debug trace、config round-trip 与扩展 metrics；并补跑 **`test_http_server.uya`**、**`test_https_loopback.uya`** 相关链路。

### 标准库 HTTP / UyaGin P5 与 async lowering 收口（2026-04-25）

- **`std.http.parse` / `std.http.types`**：HTTP/1.x 解析热路径补入 **8-byte word-at-a-time** 的 `CRLF` / `:` / 空格扫描；Header 名在解析时统一转小写、缓存 **hash** 与常见头 **kind**（`Content-Length` / `Connection` / `Transfer-Encoding` / `Content-Type` / `Host` / `Authorization`），并保留“无缓存元数据时按字节回退比较”的兼容路径。
- **Chunked request**：`http_parse_request` 现在识别 **`Transfer-Encoding: chunked`**，并通过 `http_decode_chunked_body_inplace` 将 request body 在连接缓冲内原地解码；阻塞 `http_recv_parse_request` 与异步 `uyagin_conn_read_parse_async` 主链路已接通。
- **UyaGin I/O**：`lib/std/http/uyagin.uya` 补入大响应 **`writev`** 聚合写与文件响应 **Linux x86_64 `sendfile` 优先 / 其它路径 nonblocking `read/write` 回退**；同时新增显式 `ctx.chunked(...)` API 与 `uyagin_send_context_chunked_response_*`。
- **TLS server 适配**：`lib/tls/https.uya` 新增 `https_server_serve_uyagin_once`，可将 TLS 握手后的 HTTP 请求桥接到 `std.http.uyagin.Engine`；`tests/test_https_loopback.uya` 现同时覆盖“固定 body HTTPS server”与 “TLS -> UyaGin handler” 两条最小 loopback。
- **C99 async lowering**：修复了“直接把 `@await` 结果绑定到 `!T` 变量”时的状态机漏切段 / 绑定变量类型丢失问题。`src/codegen/c99/function.uya`、`types.uya`、`expr.uya` 现支持：
  - `const r: !i32 = @await fut;`
  - 恢复后在后续表达式中正确识别 `r` 为错误联合类型
- **测试**：新增 `tests/test_async_await_direct_err_union.uya`，并更新 `tests/test_http_parse.uya`、`tests/test_http_server.uya`、`tests/test_http_uyagin.uya`、`tests/test_https_loopback.uya` 覆盖 P5 主链路。

### 语言：静态方法 `Type.method(...)`（2026-04-25）

- **语言 / Checker / C99**：结构体与联合体的方法现在支持“无 `self` 参数”的静态方法，公开调用语法为 **`Type.method(...)`**。
- **调用约束**：
  - 所有方法都支持 `Type.method(...)` 调用。
  - 只有首参为实例 receiver 的方法，额外支持 `obj.method(...)` 语法糖。
  - 接口方法签名仍要求显式 `self`，不支持静态方法。
- **冲突规则**：
  - 同一类型中不允许静态/实例同名方法。
  - 联合体静态方法不得与变体名冲突。
- **测试**：新增 `tests/test_static_method_struct.uya`、`tests/test_static_method_generic_struct.uya`、`tests/test_static_method_generic_method.uya`、`tests/test_static_method_union.uya`，并补充多条误用负例。

### 标准库：`std.sql` 通用数据库抽象（2026-04-21）

- **标准库**：新增 **`lib/std/sql/`**，包含 **`sql.uya`**、**`types.uya`**、**`driver.uya`**、**`db.uya`**。首版提供参考 Go `database/sql` 的核心对象模型：**`Value`**、**`NamedArg`**、**`ColumnInfo`**、**`Driver`**、**`Conn`**、**`Stmt`**、**`Rows`**、**`Tx`**、**`Result`**、高层 **`DB`** / **`Row`** 包装以及 **`db_open`**。
- **实现取舍**：为兼容当前 C99 backend，接口层优先使用“普通返回值 + `out` 参数”的稳定组合，避免“接口方法返回接口值”这类尚不稳定的 codegen 路径。
- **测试**：新增 **`tests/test_std_sql.uya`**，使用 fake driver 覆盖 `db_open`、`ping`、`prepare`、`exec`、`query`、`query_row`、`begin`、`commit`、`rollback` 以及 `ErrNoRows` / `ErrDBClosed` / `ErrTxDone`。
- **文档**：新增 **`docs/std_sql.md`**，说明模块分层、驱动接入方式，以及 SQLite / MySQL 的推荐对接路线。

### 标准库：`std.crypto.blake3`（2026-05-22）

- **标准库**：新增 **`lib/std/crypto/blake3.uya`**。接口为 **`blake3_digest(data, digest_out)`**；实现为纯 Uya 的一次性摘要，默认输出 **32** 字节。
- **测试**：新增 **`tests/test_crypto_blake3.uya`**，对齐 BLAKE3 官方 reference vectors，覆盖空输入、块边界、chunk 边界与短输出缓冲区保护。
- **工具链集成**：`uyabuild` bootstrap seed 已切换到 **`std.crypto.blake3`** 作为 snapshot、CAS 与 action key 的统一摘要后端。

### 标准库：`std.crypto.blake2b` / `std.crypto.blake2s`（2026-04-21）

- **标准库**：新增 **`lib/std/crypto/blake2b.uya`** 与 **`lib/std/crypto/blake2s.uya`**。接口分别为 **`blake2b_digest(data, digest_out)`** 与 **`blake2s_digest(data, digest_out)`**；均为纯 Uya 的一次性摘要实现，分别输出 **64** / **32** 字节。
- **测试**：新增 **`tests/test_crypto_blake2b.uya`** 与 **`tests/test_crypto_blake2s.uya`**，覆盖空串、短消息、跨块消息与短输出缓冲区保护。

### 标准库：`std.crypto.md5` / `std.crypto.crc32`（2026-04-21）

- **标准库**：新增 **`lib/std/crypto/md5.uya`** 与 **`lib/std/crypto/crc32.uya`**。接口分别为 **`md5_digest(data, digest_out)`** 与 **`crc32_compute(data)`**；MD5 为 RFC 1321 一次性摘要实现，CRC-32 使用 IEEE/ZIP 反射多项式 **`0xEDB88320`**。
- **内核复用**：`lib/kernel/update.uya` 的元数据 CRC32 计算切换为复用 **`std.crypto.crc32`**，避免重复维护同一算法实现。
- **测试**：新增 **`tests/test_crypto_md5.uya`** 与 **`tests/test_crypto_crc32.uya`**。

### Hosted C backend：异步重型单文件程序在代码生成阶段出现病态 tiny-write 卡顿（2026-04-21）

- **已知问题 / Hosted C backend**：当同一单文件程序重构为**单线程 async/event-loop** 设计（移除 `fork` worker、更多 `@async_fn` 任务、用户态单线程调度循环）后，前端 **parse / type check / optimize** 可正常完成，但在打印 `=== 代码生成阶段 ===` 与 `模块名: .../main.uya` 后，编译器可能长时间占满一个 CPU 核，看起来像“hang”。
- **定位结论**：这不是空转死锁。`strace` 显示编译器仍在主动生成 `uya_common.c`，但输出方式极度低效：在一次 **20s** 捕获窗口内，对同一输出 fd 发起 **1,194,005** 次 `write(2)`，总写入 **4,810,865** 字节，平均每次仅约 **4.03** 字节；其中 **1,018,642** 次为 **4B** 写入，**84,465** 次为 **1B** 写入，典型尾迹为重复输出缩进 `"    "`、`"if ("`、`" != "`、`"0"`、`") {\n"` 等极小片段。
- **影响判断**：前端已接受程序并完成优化，剩余工作仅为 C 发射；对约 **4.8 MiB** 的生成 C 持续进行百万级 tiny writes，表明问题更可能位于 hosted C backend 的**发射缓冲 / writer 策略**，而非用户程序语义错误。
- **后续修复方向**：为 C emitter 引入**按行 / 按块 / 按文件**的大缓冲输出；避免通过独立 `write("    ", 4)` 反复发射缩进；在大文件输出阶段加入进度日志，区分“慢代码生成”和真实卡死；补充 async-heavy、大单文件场景的回归 / 基准测试。

### 内置资源嵌入：`@embed` / `@embed_dir`（2026-04-20）

- **语言 / Checker / C99**：新增 `@embed("path")` 与 `@embed_dir("path")`。`@embed` 返回 `&[const byte]`；`@embed_dir` 返回 `&[const EmbedDirEntry]`，并在 checker 前置阶段合成真实 `EmbedDirEntry` 结构体声明注入 AST。目录递归收集普通文件、相对路径统一 `/`、按字典序排序；对 `&[const T]` 元素成员写入新增拒绝规则。
- **Codegen**：新增独立二进制常量池与目录表池；单文件 / split-C / 全局初始化路径均支持。资源去重使用绝对规范化路径，因此相对/绝对路径混用会收敛到同一份静态常量。
- **测试**：新增 `test_embed_builtin.uya`、`verify_embed_split_c.sh`、`verify_embed_empty_dir.sh`、`verify_embed_symlink_rejected.sh`、`verify_embed_type_only.sh`、`verify_embed_dedupe.sh` 以及多条负例用例。
- **文档**：`embed_design.md`、`todo_embed.md`、`builtin_functions.md`、`uya.md`、`grammar_quick.md`、`compiler_status.md`。

### 标准库：`std.mem.arena` 实现 `IAllocator`（2026-03-22）

- **标准库**：**`lib/std/mem/arena.uya`** — **`export struct Arena : IAllocator`**；**`dealloc`** 为空操作；**`realloc`** 仅当目标为**当前最后一次 bump 块**时在缓冲区内原地缩/扩，否则 **`AllocInvalidPointer`**；内部字段 **`has_last` / `last_start` / `last_aligned`**（带默认值，现有 **`Arena{ buffer, size, used }`** 初始化方式不变）。
- **测试**：**`tests/test_mem_arena.uya`**。
- **文档**：**`docs/todo_std_refactor.md`**、**`docs/std_refactor_design.md`** v0.7.3。

### 标准库：`std.mem.allocator` 与测试（2026-03-22）

- **标准库**：**`lib/std/mem/allocator.uya`** — **`export interface IAllocator`**（`alloc` / `dealloc` / `realloc`，**`!&byte`**）、**`MallocAllocator`**（**`malloc` / `free` / `realloc`**）、**`g_allocator`**、**`get_allocator()`**；错误类型 **`AllocOutOfMemory`** 等。
- **测试**：**`tests/test_mem_allocator.uya`**（纳入 **`make tests`**）。
- **文档**：**`docs/todo_std_refactor.md`**（Phase 2 §2.1）、**`docs/std_refactor_design.md`**、**`docs/todo_mini_to_full.md`**（**`std.mem.allocator`** 勾选与 Sprint 表）、**`docs/libc_progress.md`**、**`docs/uya.md`**（模块前缀示例）。

### v0.49.37 - C99：`@vector.reduce_add` 助手发射与收集阶段作用域（2026-03-20）

- **C99**：**`i32`/`u32`/`f32`** 的 **`×2`/`×4`** **`@vector.reduce_add`** 与 **`@vector.select`** 助手在 **`c99_simd_need_emit_i32_u32_f32`** 中按 **`simd_emit_*`** 标志参与判定；收集遍历时为 **形参** 与 **块内局部** 建立 **`local_variables`** 视图，与 **`c99_resolve_simd_type_ast_from_expr`** 一致，修复 **`test_simd_vector_reduce_add`** 等场景的 **undefined reference**。
- **文档**：规范 **0.49.37**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`、`changelog.md`）。

### v0.49.39 - SIMD：`@vector.reduce_min` / `@vector.reduce_max`（2026-03-20）

- **语言 / 检查 / C99**：新增 **`@vector.reduce_min(v)`** / **`@vector.reduce_max(v)`**（**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，分别为各通道最小值 / 最大值；C99 全部 **`while` 循环** scalar 回退）。
- **测试**：`test_simd_vector_reduce_min_max.uya`。
- **文档**：规范 **0.49.39**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`、`changelog.md`）。

### v0.49.38 - SIMD：`@vector.reduce_mul`（2026-03-20）

- **语言 / 检查 / C99**：新增 **`@vector.reduce_mul(v)`**（**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，各通道按 **`\*`** 累乘）；**`i32`/`u32`/`f32`** 的 **`×2`/`×4`** 发射 **`uya_simd_*_reduce_mul_*`** 助手（SSE2 `_mm_mul_*`，i32/u32 ×4 用 SSE4.1 `_mm_mullo_epi32`，无 SSE4.1 时自动回退标量循环）。
- **测试**：`test_simd_vector_reduce_mul.uya`。
- **文档**：规范 **0.49.38**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`、`changelog.md`）。

### v0.49.36 - SIMD：`@vector.reduce_add`（2026-03-20）

- **语言 / 检查 / C99**：新增 **`@vector.reduce_add(v)`**（**`v`** 为 **`@vector(T,N)`**，**`T`** 为 **`i8`–`i64`、`u8`–`u64`、`f32`、`f64`**；结果为标量 **`T`**，各通道按 **`+` 求和**；C99 为语句表达式内循环累加）。
- **测试**：`test_simd_vector_reduce_add.uya`、`error_simd_vector_reduce_add_not_vector.uya`。
- **文档**：规范 **0.49.36**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`、`changelog.md`）。

### v0.49.35 - SIMD：`@vector.select`（2026-03-20）

- **语言 / 检查 / C99**：新增 **`@vector.select(m, a, b)`**（**`m`** 为 **`@mask(N)`**，**`a`**/**`b`** 为相同 **`@vector(T,N)`**；逐通道混合；C99 为标量逐通道赋值）。
- **测试**：`test_simd_vector_select.uya`、`error_simd_vector_select_mask_lanes.uya`。
- **文档**：规范 **0.49.35**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`、`changelog.md`）。

### v0.49.34 - SIMD：`@vector.store`（2026-03-20）

- **语言 / 检查 / C99**：新增 **`@vector.store(ptr, v)`**（**`v`** 为 **`@vector(T,N)`**，**`ptr`** 为 **`&T`** 且元素类型匹配；**`void`**）；代码生成 **`__uya_memcpy((void*)ptr, &tmp, sizeof(...))`**。
- **测试**：`test_simd_vector_store.uya`、`error_simd_vector_store_pointee_mismatch.uya`。
- **文档**：规范 **0.49.34**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`）。

### v0.49.33 - SIMD：`@vector.load` 与 `std.json` `skip_ws` 向量化（2026-03-20）

- **语言 / 检查 / C99**：新增 **`@vector.load(ptr)`**（目标 **`@vector(T,N)`** 上下文与 **`@vector.splat`** 一致；**`&byte`/`&u8`** 与 **`u8`** 元素向量匹配）；代码生成 **`__uya_memcpy`** 装入 **`struct uya_simd_vector_*`**。
- **标准库**：**`lib/std/json/parser.uya`** 的 **`skip_ws`** 在剩余长度 **≥16** 时用 **`@vector(u8,16)`** 检测全空白块并 **`pos += 16`**，否则回退原标量循环。
- **测试**：`test_simd_vector_load.uya`、`error_simd_vector_load_pointee_mismatch.uya`。
- **文档**：规范 **0.49.33**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`、`todo_json.md`）。

### v0.49.32 - SIMD：C99 运行库按需生成 i16/u16 与 f64 族（2026-03-20）

- **C99**：`internal.uya` / `utils.uya` 增加 **`simd_max_lanes_{i16,u16,f64}`**（与既有 max_lanes 一并归零）；**`c99_simd_update_max_lanes_for_element`** 对 **`int16_t` / `uint16_t` / `double`** 更新；**`c99_simd_need_emit_f64`**、**`c99_simd_need_emit_i16_u16`**（与 **`simd_emit_all`** 配合：仅 `@mask` 时仍输出全套）。`types.uya` 将 **`f64`** 与 **`i16`/`u16`** 运行库从 **`emit_simd_x86_sse_runtime_helpers`** 拆成 **`emit_simd_runtime_helpers_f64_*`**、**`emit_simd_runtime_helpers_i16_u16_*`**（SSE / NEON / 标量各一），未使用对应元素类型时不生成。

### v0.49.31 - SIMD：C99 运行库按需生成 i8/u8/i64/u64 族（2026-03-19）

- **C99**：`internal.uya` / `utils.uya` 增加 **`simd_vector_struct_reg_count`**、**`simd_max_lanes_{i8,u8,i64,u64}`**；`c99_register_simd_struct` 在注册向量时更新；**仅当**翻译单元出现上述元素类型的 `@vector`，或仅有 **`@mask`**（无法与向量元素类型关联）时，才在生成的 C 中输出 **`uya_simd_sse_*`** 的 **i8/u8/i64/u64** 大块（SSE / NEON / 标量三份）；否则省略以缩短生成 C 与编译时间。`emit_simd_x86_sse_runtime_helpers` 拆出 **`emit_simd_runtime_helpers_i8_u8_i64_u64_*`** 三个子函数。

### v0.49.30 - SIMD：`i8`/`u8`/`i64`/`u64` 向量与掩码 C99 快路径（2026-03-19）

- **C99**：`types.uya` 增补 **`uya_simd_sse_*_i8x16`/`x8`/`x4`/`x2`**、**`*_u8x*`**、**`*_i64x2`**、**`*_u64x2`**（SSE **`_mm_*_epi8` / `epi64`** 或小宽度零填充块、**NEON/`#else`** 标量同签名）；`scripts/gen_simd_i8_i64_helpers.py` 生成 **SSE** 与 **`portable`** 片段。`expr.uya`：**`fast_kind` 123–186**、**`c99_simd_sse_i8_u8_lane_ok`** / **`i64_u64`**、**i8/u8 变步长分块**、**`splat` / 一元 `-`**。**测试**：`test_simd_i8_u8_i64_sse.uya`。
- **文档**：规范 **0.49.30**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md`）。

### v0.49.29 - SIMD：`2×i32` / `2×u32` / `2×f32` 与 `@mask(2)` C99 快路径（2026-03-19）

- **C99**：`types.uya`：`uya_simd_sse_*_i32x2`、`*_u32x2`、`*_f32x2` 及掩码（SSE/NEON/`#else`）；`expr.uya`：`c99_simd_sse_i32_u32_f32_two_or_x4_lane_ok`、分派 **`x2`**、`splat`/`一元-`；`test_simd_vec2_i32_u32_f32.uya`、夹具 **`simd_c99_neon.uya`**。
- **文档**：规范 **0.49.29**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.28 - SIMD：`f64` `+`/`-`/一元`-`；`i16`/`u16` 扩展比较与 `splat`；`4×i16` 安全 64 位块（2026-03-19）

- **C99**：`types.uya` / `expr.uya`：`add_f64x2`、`sub_f64x2`、`neg_f64x2`；`i16`/`u16` 掩码六比较；`i16x4`/`u16x4` 与 `x8` 向量助手；`splat_i16*`、`splat_u16*`；`fast_kind` 39/40、41–43、112–122 等；`test_simd_i16_add.uya`、`test_simd_u16_basic.uya`、夹具 **`simd_c99_neon.uya`**。
- **文档**：规范 **0.49.28**（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.27 - SIMD：`4×/8×i16` 向量 `-` / `*` C99 快路径（2026-03-20）

- **C99**：`types.uya` 增加 **`uya_simd_sse_sub_i16x8`**、**`uya_simd_sse_mul_i16x8`**（SSE2 `_mm_sub_epi16` / `_mm_mullo_epi16`，NEON `vsubq_s16` / `vmulq_s16`，标量）；`expr.uya` **`fast_kind` 37 / 38**；`test_simd_i16_add.uya`、夹具 **`simd_c99_neon.uya`** 增补。
- **文档**：规范 0.49.27（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.26 - SIMD：`4×/8×i16` 向量 `+` / `==` C99 快路径（2026-03-19）

- **C99**：`types.uya` 增加 **`uya_simd_sse_add_i16x8`**、**`uya_simd_sse_eq_i16x8_mask`**（SSE2 `__m128i` / NEON `int16x8_t` / 标量）；`expr.uya` **`fast_kind` 36 / 111**，支持 **4×/8×** 通道（4× 复用 8× 助手）；`test_simd_i16_add.uya` 验证通过。
- **文档**：规范 0.49.26（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.25 - SIMD：`2×/4×f64` 向量 `*` / `/` C99 快路径（2026-03-19）

- **C99**：`types.uya` 增加 **`uya_simd_sse_mul_f64x2`**、**`uya_simd_sse_div_f64x2`**（SSE2 `__m128d` / NEON `float64x2_t` / 标量）；`expr.uya` **`fast_kind` 34 / 35**，支持 **2×/4×** 通道（4× 为两次 2× 调用）；`test_simd_f64_mul_div.uya` 验证通过。
- **文档**：规范 0.49.25（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.24 - SIMD：`4×i32` / `4×u32` 向量 `<<` / `>>` C99 助手（2026-03-19）

- **C99**：`types.uya` 增加 **`uya_simd_sse_shl_i32x4`**、**`uya_simd_sse_shr_i32x4`**、**`uya_simd_sse_shl_u32x4`**、**`uya_simd_sse_shr_u32x4`**（三档均为标量逐通道位移）；`expr.uya` **`fast_kind` 18 / 19 / 28 / 29**；`test_simd_mask_bitwise_shift.uya` 增补左移用例；夹具 **`simd_c99_neon.uya`** 增补位移用例。
- **文档**：规范 0.49.24（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.23 - SIMD：`4×i32` / `4×u32` 向量 `%` C99 助手（2026-03-19）

- **C99**：`types.uya` 增加 **`uya_simd_sse_rem_i32x4`**、**`uya_simd_sse_rem_u32x4`**；`expr.uya` **`fast_kind` 17 / 27**；`test_simd_u32_basic.uya`、**`simd_c99_neon.uya`** 夹具增补。
- **文档**：规范 0.49.23（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.22 - SIMD：`4×i32` 向量 `/` C99 助手（2026-03-19）

- **C99**：`types.uya` 增加 **`uya_simd_sse_div_i32x4`**；`expr.uya` **`fast_kind` 16**；`test_simd_div_f32_i32.uya`、夹具 **`simd_c99_neon.uya`** 增补用例。
- **文档**：规范 0.49.22（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.21 - SIMD：`4×u32` 向量 `/` C99 助手（2026-03-19）

- **C99**：`types.uya` 增加 **`uya_simd_sse_div_u32x4`**（三档均为 `uint32_t` 逐通道除）；`expr.uya` **`fast_kind` 26**；`test_simd_u32_basic.uya` 增补 `7/2→3`。
- **文档**：规范 0.49.21（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.20 - SIMD：`4×u32` 向量 `*` C99 快路径（2026-03-19）

- **C99**：`types.uya` 增加 **`uya_simd_sse_mul_u32x4`**（SSE4.1 / NEON `vmulq_u32` / 标量）；`expr.uya` **`fast_kind` 22**；`test_simd_u32_basic.uya` 增补高位无符号乘用例。
- **文档**：规范 0.49.20（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.19 - SIMD：32×/64×`i32`/`u32`/`f32` 八/十六 x4 lowering（2026-03-19）

- **C99**：`expr.uya` 增加 **`c99_simd_sse_x4_tile_lane_count_ok`**；**32 / 64** 通道与 **4/8/16** 同属 x4 分块快路径；测试 `test_simd_vec32_sse_chain.uya`、`test_simd_vec64_sse_chain.uya`。
- **文档**：规范 0.49.19（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.18 - SIMD：16×`i32`/`u32`/`f32` 四 x4 lowering（2026-03-19）

- **C99**：`expr.uya` 对 **16 通道**向量/掩码复用 **`uya_simd_sse_*x4`** 四次（`&lanes[4|8|12]`）；`splat` 用循环生成多次调用；测试 `test_simd_vec16_sse_chain.uya`。
- **文档**：规范 0.49.18（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.17 - SIMD：8×`i32`/`u32`/`f32` 双 x4 lowering（2026-03-19）

- **C99**：`expr.uya` 对 **8 通道**向量/掩码复用 **`uya_simd_sse_*x4`** 两次（`&lanes[4]`）；`@vector.splat` / 一元 `-` 同步；测试 `test_simd_vec8_sse_chain.uya`。
- **文档**：规范 0.49.17（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.16 - SIMD：C99 ARM NEON 分支（2026-03-19）

- **C99**：`emit_simd_*` 在 **`UYA_HAVE_SIMD_ARM_NEON`** 下输出与 SSE 同名的 **`uya_simd_sse_*`** NEON 实现（`<arm_neon.h>`）；`#if` / `#elif` / `#else` 三档（SSE / NEON / 标量）。
- **验证**：`tests/verify_simd_c99_neon.sh`；`tests/simd_c99_neon.uya`（`make check` / `make check-hosted`，与并行测试共用）。
- **文档**：规范 0.49.16（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.15 - SIMD：4×`u32` 有序比较 C99 lowering（2026-03-19）

- **C99**：`emit_simd_x86_sse_runtime_helpers` 增加 `uya_simd_sse_{lt,gt,le,ge}_u32x4_mask`（SSE：与 `0x80000000` 异或后有符号比较；`#else`：按 `uint32_t` 通道比较）；`expr.uya` 掩码分支为 `uint32_t` 的 `<` `>` `<=` `>=` 映射 fast_kind 107–110。
- **测试**：`test_simd_sse_compare_ops.uya` 增补无符号绕序（`0xFFFFFFFEu32` vs `0xFFFFFFFFu32`、`0` vs `0xFFFFFFFFu32`）。
- **文档**：规范 0.49.15（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.14 - C99 `@syscall`：Linux ARM32（EABI）分支（2026-03-19）

- **C99**：`uya_syscall0`…`6` 增加 **`#elif __arm__ && !__aarch64__ && __linux__`**（`svc 0`，nr→**r7**，参数 **r0**–**r5**；Thumb 安全保存/恢复 r7）。
- **验证**：`tests/verify_syscall_c99_cross.sh`（AArch64 整文件 + ARM 抽出片段 `zig cc arm-linux-gnueabihf`）；`tests/syscall_c99_cross.uya`（macOS 默认跳过并行运行）。
- **文档**：规范 0.49.14；`uya.md` 附录 C 与规范变更同步。

### v0.49.13 - C99 `@syscall`：Linux AArch64 分支（2026-03-19）

- **C99**：`uya_syscall0`…`6` 增加 **`#elif (__aarch64__||_M_ARM64) && __linux__`**（`svc 0`），交叉 **`aarch64-linux-gnu`** 不再唯一条 `#error`。
- **验证**：`make check`；`tests/syscall_c99_cross.uya`（发布时脚本为 `verify_syscall_c99_aarch64.sh`，**0.49.14** 起合并为 `verify_syscall_c99_cross.sh`）。
- **文档**：规范 0.49.13；`uya.md` 附录 C 补充 `@syscall` 说明。

### v0.49.12 - SIMD：C99 向量比较 lowering 扩展（2026-03-19）

- **C99**：`uya_simd_sse_{eq,ne,lt,gt,le,ge}_{i32,f32}x4_mask` 及标量 `#else`；`expr.uya` 掩码分支映射六种比较；`u32`×4 仅 `==`/`!=` 走快路径。
- **测试**：`test_simd_sse_compare_ops.uya`。
- **文档**：规范 0.49.12（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md`）。

### v0.49.11 - 文档：交叉编译（工具链）附录（2026-03-19）

- **文档**：`uya.md` 新增 **附录 C. 交叉编译（工具链）**（`HOST_*` / `TARGET_*`、`TARGET_TRIPLE`、`CC_DRIVER` / `CC_TARGET_FLAGS`、`TOOLCHAIN=zig`、自举与应用编译示例、限制与引用 [UYA_BUILD_RUN.md](./UYA_BUILD_RUN.md)）。
- **规范版本**：0.49.11（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`、`uya_ai_prompt.md` 版本号同步）。

### v0.49.10 - SIMD：C99 x86_64 SSE 初版 lowering（2026-03-19）

- **C99**：`emit_simd_x86_sse_runtime_helpers` 在含 `@vector/@mask` 的翻译单元中输出 `uya_simd_sse_*`（顶层 `#if UYA_HAVE_SIMD_X86_SSE`：SSE 内建；`#else`：逐通道标量）。`expr.uya` 对 4 宽 `i32`/`u32`/`f32` 向量与 `==`→掩码、`splat`、一元 `-` 生成对上述助手的调用（**不在** GNU `({ ... })` 内使用 `#if`）。
- **测试**：`test_simd_sse_lower_i32x4.uya`。
- **文档**：规范 0.49.10（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.9 - SIMD：C99 `catch` 向量别名载荷与掩码预收集（2026-03-19）

- **C99**：`gen_catch_expr` 从 `struct err_union_<name>` 反推载荷时，若 `name` 为 `type` 别名（如 `Vec4i32` → `@vector`），成功分支中间变量使用与 `typedef` 一致的标识符，避免误生成 `struct Vec4i32`。
- **C99**：切片/SIMD 收集遍历函数体时设置 `current_function_decl`；`collect_inferred_simd_type_from_expr` 对向量相等比较预注册 `@mask(N)`，避免仅出现在 `@vector.all( v == splat )` 中的掩码在 C 中不完整类型。
- **测试**：`test_simd_return_splat_binary.uya`（`catch` + `!Vec4i32`）、`test_simd_mask_inline_compare.uya`。
- **文档**：规范 0.49.9（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.8 - SIMD：`return` 与 splat 类型检查及 `!向量` err_union C99（2026-03-19）

- **类型检查**：`checker_simd_prep_expr_with_expected_vector` — 在推断 `return` 子表达式前，按函数返回 `@vector` 或 `!T` 载荷为 `@vector` 绑定其中 `@vector.splat`（含嵌套二元式双 splat）。
- **C99**：`c99_err_union_payload_is_emittable` + `emit_pending_err_union_structs` — 对载荷为 `@vector`/`@mask` 或类型别名指向它们的错误联合输出完整 `struct err_union_*`。
- **测试**：`test_simd_return_splat_binary.uya`。
- **文档**：规范 0.49.8（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.7 - SIMD splat 二元式 C99 类型解析补强（2026-03-19）

- **C99 代码生成**：`c99_resolve_simd_type_ast_from_expr` 对 `@vector.splat` 增加 `expected_type` / `current_function_return_type` 回退；二元 SIMD 操作数在仅一侧能解析向量类型时将对侧 `splat` 对齐为该 `@vector`。
- **测试**：`test_simd_splat_binary_context.uya`。
- **文档**：规范 0.49.7（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.6 - SIMD 向量饱和与包装运算（2026-03-19）

- **类型检查**：相同类型的 `@vector(T, N)` 支持按通道 `+|`/`-|`/`*|`（`T` 须为有符号整数）、`+%`/`-%`/`*%`（`T` 须为整数，含无符号）。
- **C99 代码生成**：`c99_emit_simd_lane_sat_wrap` + `c99_gen_simd_binary_expr` 分支，与标量 `__builtin_*_overflow` / 无符号包装转换一致。
- **`@vector.splat` 推断**：饱和/包装二元表达式与算术、取模等一致，可从对侧向量绑定 splat。
- **测试**：`test_simd_vector_sat_wrap_i32.uya`；负例 `error_simd_float_vector_plus_pipe.uya`、`error_simd_u32_vector_plus_pipe.uya`。
- **文档**：规范 0.49.6（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.5 - SIMD 整数向量取模（2026-03-19）

- **类型检查 / C99 代码生成**：相同类型的整数元素 `@vector(T, N)` 支持按通道 `%`；浮点元素向量取模为编译错误。
- **`@vector.splat` 推断**：取模表达式与算术/比较等一致，可从对侧 `@vector` 绑定 splat 目标类型。
- **测试**：`test_simd_vector_mod_i32.uya`；负例 `error_simd_float_vector_mod.uya`（取代原「全向量取模均非法」的 `error_simd_vector_mod.uya`）。
- **文档**：规范 0.49.5（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.4 - SIMD 一元运算规范与测试（2026-03-19）

- **文档**：`uya.md` / `grammar_formal.md` 明确向量一元 `-`（整数/浮点元素）与一元 `~`（仅整数元素）。
- **测试**：`test_simd_unary_ops.uya`。

### v0.49.3 - SIMD splat 对侧向量类型推断（2026-03-19）

- **类型检查**：`checker_check_binary_expr` 在向量算术、比较、整数向量位运算与位移中，若一侧为 `@vector`、另一侧为未绑定目标的 `@vector.splat`，则从向量侧绑定 splat 目标类型。
- **测试**：`test_simd_splat_peer_infer.uya`；`test_simd_struct_field_ops.uya` 恢复内联 `@vector.splat` 比较写法。
- **文档**：规范 0.49.3（`uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.2 - 浮点后缀解析与 SIMD 代码生成补强（2026-03-19）

- **编译器**：`parse_float_literal_with_suffix` 正确识别以小写 `f32` / `f64` 结尾的浮点字面量（此前 `TOKEN_FLOAT` 路径会漏识后缀）。
- **C99 代码生成**：`c99_resolve_simd_type_ast_from_expr` 支持 `AST_MEMBER_ACCESS`，结构体字段上的 SIMD 比较与 `@vector.all`/`any` 生成合法 C。
- **测试**：`test_simd_struct_field_ops.uya`、`test_simd_splat_f32_suffix.uya`。
- **文档**：规范版本 0.49.2；`@vector.splat` 与 `f32` 字面量说明及示例修正（见 `uya.md`、`grammar_formal.md`、`grammar_quick.md`、`builtin_functions.md`）。

### v0.49.1 - SIMD 规范同步与版本更新（2026-03-19）

- **语法规范版本**：`docs/uya.md`、`docs/grammar_formal.md`、`docs/grammar_quick.md`、`docs/builtin_functions.md` 同步更新为 0.49.1。
- **SIMD 规范收口**：`@vector(T, N)`、`@mask(N)` 及 `@vector.splat`、`@vector.any`、`@vector.all` 的第一阶段语义已在规范与辅助文档中对齐。

### v0.49 - 字符串与字符字面量规范与实现（2026-03-17）

- **字符串字面量**：规范明确可赋值给 `[byte: N]`、`&byte`、`*byte`；语义上自动带 `\0` 结尾（长度为可见字符数 + 1）。详见 uya.md §1.4、grammar_formal.md。
- **字符字面量**（新增语法）：单引号 `'x'`、`'\n'` 等可赋给 `byte`；支持转义 `\n` `\t` `\0` `\\` `\'` `\r` `\"`；编译器已实现（词法 TOKEN_CHAR、AST AST_CHAR、解析/类型/代码生成）。
- **测试**：`tests/test_string_literal_init.uya` 覆盖字符串→[byte:N]、字符串→*byte、字符→byte。

### @await 操作数类型约束收紧（2026-03-12）

- **语义修正**：`@await` 的操作数现在必须是 `!Future<T>`（错误联合包裹的 Future）
- **新增错误用例**：
  - `tests/error_await_operand_not_error_union.uya`
  - `tests/error_await_operand_not_future.uya`
- **验证**：`make check` 通过（自举对比一致 + 全量测试通过）

### stdio _vfprintf_impl C99 兼容（2026-03-12）

#### 主要变更

1. **格式说明符 C99 对齐**
   - **flags**：`-`、`+`、空格、`0`、`#` 全支持
   - **width / precision**：数字与 `*` / `.*`，用于 `%s`、`%d`、`%f` 等
   - **length**：`h`/`hh`、`l`、`ll`、`j`、`z`、`t`、`L`

2. **新增 / 修正的转换**
   - **%zu / %zd**：size_t 无符号/有符号，带 width 填充
   - **%j**（intmax_t/uintmax_t）、**%t**（ptrdiff_t）：d/i/u/o/x/X，temp buffer + padding
   - **%h / %hh**：在 %d/%i/%u/%o/%x/%X 中按 length 1/2 做 8/16 位 mask
   - **%a / %A**：C99 十六进制浮点（`0x1.xxxp±d` / `0X1.XXXP±d`），新增 `_fmt_f64_hex_to_buf`

3. **浮点、%c、%p 的 width**
   - 浮点（%f/%e/%g/%F/%E/%G）与 %c、%p 统一先写入 temp buffer，再按 width 做左/右对齐与零填充

#### 测试

- `tests/test_libc_stdio_new.uya`：新增 %zu/%zd、%jd/%ju、%hd/%hu、%a/%A、%8.2f、%5c 等用例
- `make check`：497 通过，0 失败

---

### v0.7.3 - va_list 内置类型

**发布日期：** 2026-03-03

#### 主要变更

1. **va_list 升级为编译器内置类型**
   - 不再是结构体，而是平台相关的编译器内置类型
   - 直接映射到 C 的 `__builtin_va_list`
   - 与 C 代码完全兼容

2. **新增 `@va_copy` 内置函数**
   - 复制 va_list 状态，用于多次遍历可变参数
   - 语法：`@va_copy(&dest, src)`

3. **放宽 `@va_arg` 使用限制**
   - 可在接收 `va_list` 参数的函数内使用（之前只能在可变参数函数内使用）
   - 支持将 va_list 传递给其他函数处理

4. **初始化语法**
   - 使用 `var ap: va_list = va_list{};` 初始化
   - 然后用 `@va_start(&ap, last_param)` 初始化

#### 使用示例

```uya
// 可变参数函数
fn my_printf(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);

    const val: i32 = @va_arg(ap, i32);
    const str: &const byte = @va_arg(ap, &const byte);

    @va_end(&ap);
    return 0;
}

// 接收 va_list 参数的函数
fn process_va_list(ap: va_list) i32 {
    return @va_arg(ap, i32);  // ✅ 现在可以直接使用
}

// va_copy 示例
fn multi_pass(format: &const byte, ...) i32 {
    var ap1: va_list = va_list{};
    @va_start(&ap1, format);

    var ap2: va_list = va_list{};
    @va_copy(&ap2, ap1);

    const v1: i32 = @va_arg(ap1, i32);
    const v2: i32 = @va_arg(ap2, i32);  // 相同的参数

    @va_end(&ap1);
    @va_end(&ap2);
    return v1 + v2;
}
```

#### 破坏性变更

- 删除旧的 `test_stdarg.uya` 测试（使用结构体 API）
- `lib/libc/stdarg.uya` 简化为文档注释
- 直接访问 va_list 结构体成员（如 `ap.count`）不再支持

#### 测试状态

- 自举验证：✓ 通过
- 测试验证：473/473 通过

---

### v0.7.2 - 裸函数属性 @naked_fn

**发布日期：** 2026-03-03

#### 主要变更

1. **新增 `@naked_fn` 函数属性**
   - 标记函数为裸函数（无 prologue/epilogue）
   - 函数体必须只包含 `@asm` 内联汇编
   - 生成的 C 代码添加 `__attribute__((naked))`
   - 用于实现底层系统代码：`setjmp`/`longjmp`、操作系统内核等

2. **内联汇编块合并**
   - 修复：`@asm` 块中所有指令现在合并为单个 `__asm__ volatile`
   - 之前：每条指令生成独立的 `__asm__ volatile`（导致裸函数无法正常工作）
   - 现在：所有指令在同一个汇编块中执行

3. **实现 setjmp/longjmp**
   - 使用 `@naked_fn` 重新实现 `lib/libc/setjmp.uya`
   - x86-64 调用约定：参数在 rdi/rsi/rdx，返回值在 rax
   - 保存/恢复 callee-saved 寄存器：rbx, rbp, r12-r15

#### 使用示例

```uya
// 裸函数示例：setjmp
export @naked_fn fn setjmp(env: &jmp_buf) i32 {
    @asm {
        "movq %%rbx, 0(%0)" (env as usize);
        "movq %%rbp, 8(%0)" (env as usize);
        // ... 保存其他寄存器
        "xorl %%eax, %%eax" ();
        "ret" ();
    } clobbers = ["memory"];
}
```

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：`tests/test_naked_fn.uya`、`tests/test_longjmp_full.uya`

### v0.7.1 - 切片字面量 & 语法增强

**发布日期：** 2026-02-21

#### 主要变更

1. **切片字面量（从数组字面量创建切片）**
   - 新增语法：`&[elem1, elem2, ...]` 和 `&[value: N]`
   - 无需先声明数组变量，直接从字面量创建切片
   - 示例：
     ```uya
     const slice1: &[i32] = &[1, 2, 3];      // 从列表创建
     const slice2: &[i32] = &[0: 10];        // 从重复值创建
     ```
   - 实现位置：
     - `src/codegen/c99/expr.uya`: 新增 `gen_slice_from_array_literal()` 函数
     - `src/codegen/c99/types.uya`: 切片类型推断
     - `src/codegen/c99/stmt.uya`: 变量声明时设置 expected_type

2. **match 表达式省略分号**
   - 当 match 的所有分支都是 block（用 `{}` 包裹）时，可省略分号
   - 提升代码流畅性，减少语法噪音
   - 示例：
     ```uya
     match status {
         200 => { process_success(); },
         404 => { handle_error(); },
         else => { handle_default(); }
     }  // 可以省略这里的分号
     ```
   - 实现位置：`src/parser/statements.uya`

3. **类型推断改进**
   - 变量声明时正确传递 expected_type
   - 支持从目标类型推断切片元素类型

#### 代码统计

- 修改文件：6 个
- 新增代码：~180 行
- 测试状态：自举通过

### v0.6.0 - 标准库重构（规划中）

本版本将重构标准库架构，使用 Uya 现代特性。

#### 主要变更

1. **std 使用现代特性**
   - `!T` 错误处理替代裸指针返回
   - `union Option<T>` 类型安全
   - `interface` 定义抽象（Writer, Reader, Clone, Eq）
   - 泛型容器（Vec<T>, StringBuf）

2. **libc 薄封装**
   - 保持 C99 标准库签名兼容
   - 内部调用 std 实现，零重复代码
   - 更安全的 API（边界检查、空指针防护）

3. **分层架构**
   ```
   libc/  →  std/  →  syscall/
   (C ABI)  (Uya)    (底层)
   ```

#### Sprint 规划

| Sprint | 内容 | 说明 |
|--------|------|------|
| 6 | std.core | Error, Option<T>, traits |
| 7 | std.io | Writer/Reader 接口，File 实现 |
| 8 | std.string | 安全字符串操作（!T） |
| 9 | std.collections | Vec<T>, StringBuf 泛型容器 |
| 10 | libc 薄封装 | 调用 std，保持 C ABI |

#### 详细设计

参见 [`docs/std_refactor_design.md`](./std_refactor_design.md)

---

## 0.55 版本变更（相对于 0.50）

**发布日期：** 2026年2月19日

### v0.5.9 - --outlibc 生成独立 libc

本版本实现 `--outlibc` 功能，可生成零外部依赖的 libuya.c 和 libuya.h。

#### 主要变更

1. **--outlibc 命令**
   - `uya --outlibc <目录>` 生成独立 C 库
   - 生成 `libuya.h`（头文件）：类型定义、函数声明
   - 生成 `libuya.c`（实现文件）：所有函数实现

2. **零依赖类型定义**
   - int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t
   - int64_t, uint64_t, size_t, ssize_t

3. **包含的模块**
   - syscall: uya_syscall0-6（x86-64 内联汇编）
   - string: strlen, strcmp, strncmp, strcpy, strncpy, strcat, strchr, strrchr
   - mem: memcpy, memmove, memset, memcmp, memchr
   - stdio: putchar, puts
   - stdlib: exit, atoi, atol
   - unistd: write, read, close

#### 使用方法

```bash
# 生成 libuya 库
uya --outlibc /tmp/libuya

# 编译库
gcc -c libuya.c -o libuya.o

# freestanding 模式使用
gcc -nostdlib -ffreestanding your_program.c libuya.o -o your_program -lgcc
```

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：399/399 通过
- Freestanding 测试：✓ 通过

### v0.5.8 - 编译器零依赖构建 & 约束证明增强

本版本实现编译器完全静态链接（零外部依赖），并增强约束证明系统。

#### 主要变更

1. **编译器 -nostdlib 构建（Sprint 4）**
   - 编译器现在可以完全静态链接，零外部依赖
   - `ldd bin/uya`: 不是动态可执行文件
   - `nm bin/uya | grep ' U '`: 无未定义符号
   - 使用 C 内联汇编实现 `_start` 启动代码
   - 清理编译器中的 C 标准库依赖，全部使用纯 Uya 实现的标准库

2. **约束证明系统增强**
   - **交换律支持**: `10 > i` 等价于 `i < 10`
   - **线性表达式支持**: `i + offset < n` 转换为 `i < n - offset`
   - **const 变量识别**: `if i < N { }` 其中 N 是 const 变量
   - **错误去重**: 同一 (变量名, 数组大小) 只报告一次安全证明错误

3. **Makefile 更新**
   - `make uya` 默认静态链接，零外部依赖
   - 新增 `make uya-std` 目标（标准库链接，用于调试）

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：399/399 通过
- 新增 5 个约束证明测试用例

### v0.5.7 - 调试打印内置函数

本版本新增 `@print` 和 `@println` 内置函数，用于调试输出。

#### 主要变更

1. **新增 @print/@println 内置函数**
   - `@print(expr)` - 打印表达式值（不换行）
   - `@println(expr)` - 打印表达式值并换行
   - 返回 `i32` 类型（printf 返回值）

2. **支持的类型**
   - 整数类型：`i8`、`i16`、`i32`、`i64`、`u8`、`u16`、`u32`、`u64`、`usize`
   - 浮点类型：`f32`、`f64`
   - 布尔类型：`bool`
   - 字符串：`&[i8]`、`*i8`、`[i8: N]`
   - 字符串插值：`"text${expr}text"`

3. **插值格式支持**
   - 十六进制：`${num:#x}`、`${num:#X}`
   - 八进制：`${num:#o}`
   - 浮点精度：`${f:.2f}`、`${f:.4f}`

#### 使用示例

```uya
fn main() i32 {
    // 基础用法
    @println(42);              // 输出: 42
    @println("Hello");         // 输出: Hello
    @println(3.14);            // 输出: 3.14
    @println(true);            // 输出: 1

    // 字符串插值
    const name: &byte = "Uya";
    @println("Hello, ${name}!");  // 输出: Hello, Uya!

    // 格式化输出
    const x: i32 = 255;
    @println("hex = ${x:#x}");    // 输出: hex = ff

    return 0;
}
```

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：399/399 通过

### v0.5.6 - 编译选项可配置化

本版本将硬编码的编译选项改为可通过环境变量配置。

#### 主要变更

1. **CFLAGS/LDFLAGS 环境变量支持**
   - 新增 `CFLAGS` 环境变量控制编译选项
   - 新增 `LDFLAGS` 环境变量控制链接选项
   - 默认使用调试模式：`-std=c99 -O0 -g -fno-builtin`

2. **Makefile 更新**
   - 所有编译命令使用 `$(CFLAGS)` 和 `$(LDFLAGS)`
   - `make release` 使用固定 `-O3 -DNDEBUG` 优化选项

3. **compile.sh 更新**
   - 支持从环境变量读取 `CFLAGS` 和 `LDFLAGS`
   - 所有 gcc 命令统一使用变量

#### 使用示例

```bash
# 默认调试模式构建
make from-c

# 使用自定义优化级别
CFLAGS='-std=c99 -O2' make uya

# 构建发布版本（自动 -O3 优化 + strip）
make release
```

### v0.5.5 - 代码规范化与编译优化

本版本进行了代码规范化工作，并优化了编译选项。

#### 主要变更

1. **代码规范化**
   - 将代码中的魔法数字替换为命名常量，提高代码可读性和可维护性
   - 新增常量：
     - `C99_MAX_ERROR_IDS: i32 = 256`
     - `C99_GENERIC_NAME_BUF_SIZE: i32 = 128`
     - `C99_MAX_INTERFACE_METHODS: i32 = 128`
     - `C99_TYPE_ARG_BUF_SIZE: i32 = 256`
     - `C99_TYPE_ARG_BUF_LIMIT: i32 = 250`
     - `C99_OUTPUT_FILENAME_BUF_SIZE: i32 = 100`
     - `C99_STRING_INTERP_BUF_SIZE: i32 = 2048`
     - `C99_STRING_INTERP_LIMIT: i32 = 2046`
     - `C99_SUFFIX_BUF_SIZE: i32 = 512`
     - `MAX_MONO_NAME_LEN: i32 = 256`
     - `MAX_MONO_NAME_LIMIT: i32 = 250`
     - `MAX_GENERIC_NAME_BUF: i32 = 512`

2. **编译选项优化**
   - 移除 `-fwrapv` 编译选项
   - 当前编译选项：`gcc -std=c99 -O3 -fno-builtin`

3. **Bug 修复**
   - 修复 `stmt.uya` 中变量赋值错误 (`j2 = j + 1` -> `j2 = j2 + 1`)

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：393/393 通过
- Valgrind 验证：✓ 无内存泄漏，无内存错误

### v0.5.4 - 代码规范化

将代码中的魔法数字替换为命名常量，提高代码可读性和可维护性。

### v0.5.3-O3 - 编译选项统一

统一使用 `-O3 -fwrapv` 编译选项：
- 更新所有 gcc 命令使用一致的优化选项
- `-O3` 最高优化级别，`-fwrapv` 确保有符号整数溢出行为确定

### v0.5.2 - 编译问题排查

排查 `gcc -O2` 编译导致的段错误问题。

---

## 0.51 版本变更（相对于 0.50）

**发布日期：** 2026年2月17日

### 0.51 内存安全证明增强

本版本增强了内存安全证明系统的类型支持和表达式分析能力。

#### 新增功能

1. **无符号类型约束支持**
   - 新增 `is_unsigned_type()` 函数判断无符号整数类型
   - 自动为 `usize`, `u8`, `u16`, `u32`, `u64`, `byte` 类型变量添加 `>= 0` 约束
   - 类型转换表达式支持：`extract_linear_expr` 和 `checker_eval_const_expr` 现在支持 `as` 类型转换

2. **区间算术（Interval Arithmetic）**
   - 新增 `Interval` 结构表示值范围 `[min, max]`
   - 实现区间运算函数：`interval_add`, `interval_sub`, `interval_mul`, `interval_div`, `interval_shl`, `interval_shr`
   - 支持从约束系统推导变量区间：`get_var_interval()`
   - 表达式区间求值：`eval_expr_interval()`
   - 区间边界验证：`verify_expr_bounds_interval()`

3. **非线性表达式边界检查**
   - 支持乘法表达式边界检查：`arr[i * 2]`
   - 支持除法表达式边界检查：`arr[i / 2]`
   - 支持移位表达式边界检查：`arr[i << 1]`, `arr[i >> 1]`

#### 使用示例

```uya
// 非线性表达式边界检查
fn test_mul() void {
    var arr: [i32: 20] = [...];
    var i: i32 = 3;

    if i == 3 {
        arr[i * 2] = 42;  // i * 2 == 6 < 20, 安全
    }
}

// 移位运算边界检查
fn test_shift() void {
    var arr: [i32: 100] = [...];
    var i: i32 = 5;

    if i == 5 {
        arr[i << 1] = 42;  // i << 1 == 10 < 100, 安全
    }
}

// usize 类型自动约束
fn test_usize() void {
    var arr: [i32: 10] = [...];
    var i: usize = get_index();

    if i < 10 {
        arr[i] = 42;  // usize 天然满足 i >= 0，只需检查上界
    }
}
```

#### 新增测试

- `test_usize_constraints.uya`：usize 类型约束测试
- `test_nonlinear_bounds.uya`：非线性表达式边界检查测试

#### 技术细节

- Token 类型名称修正：`TOKEN_ASTERISK`（乘法）、`TOKEN_LSHIFT`（左移）、`TOKEN_RSHIFT`（右移）
- 区间乘法需要考虑所有极值组合
- 区间除法需要处理除以零情况

---

## 0.50 版本变更（相对于 0.48）

**发布日期：** 2026年2月17日（农历春节）

### 0.50 内存安全证明系统（里程碑版本）

本版本实现了完整的编译期内存安全证明系统，使 Uya 成为具有形式化安全保证的系统编程语言。

#### 核心功能

1. **常量折叠增强（阶段1）**
   - 整数溢出检测：编译期检测算术运算溢出
   - 数组越界检测：常量索引编译期验证
   - 除零检测：编译期检测除法和取模的除零错误

2. **路径敏感分析框架（阶段2）**
   - 约束系统：收集和传播变量约束（`>=`, `<=`, `<`, `>`, `==`, `!=`）
   - 作用域隔离：每个函数独立约束环境，避免污染
   - 指针非空状态跟踪：记录指针是否可能为空

3. **符号执行引擎（阶段3）**
   - 线性表达式提取：识别 `var + offset` 形式的索引表达式
   - 边界验证：自动验证 `while i < @len(arr)` 循环中的数组访问
   - `@len()` 编译时求值：支持 `@len()` 作为约束边界

4. **证明超时机制（阶段4）**
   - 步数限制：默认 1000 步上限，防止无限证明循环
   - 超时报告：清晰的超时错误消息和优化建议

5. **未初始化变量检测（阶段5）**
   - 初始化状态跟踪：检测未初始化变量的使用
   - 路径敏感分析：区分不同控制流路径的初始化状态

6. **空指针解引用检测（阶段6）**
   - 空值状态跟踪：记录指针初始化和检查状态
   - 解引用验证：验证指针解引用前是否通过空检查

7. **证明失败错误报告（阶段7）**
   - 详细错误消息：包含变量名、数组大小、安全建议
   - 修复建议：自动生成边界检查代码模板

#### 新增命令行参数

```bash
uya --safety-proof -c source.uya -o output.c
```

#### 使用示例

```uya
// 循环边界自动推断
fn sum(arr: [i32: 10]) i32 {
    var total: i32 = 0;
    var i: i32 = 0;
    while i < @len(arr) {  // 自动建立约束: i >= 0 && i < 10
        total = total + arr[i];  // 安全：约束已满足
        i = i + 1;
    }
    return total;
}

// 边界检查验证
fn process(arr: [i32: 10], i: i32) i32 {
    if i >= 0 && i < 10 {  // 边界检查
        return arr[i];
    }
    return -1;
}

// 空指针检查验证
fn deref(ptr: &i32) i32 {
    if ptr != null {  // 空检查
        return *ptr;
    }
    return 0;
}
```

#### 技术改进

- 函数间约束隔离，避免跨函数污染
- 循环变量递增后上界约束保留
- 支持 `i32` 类型约束（`usize` 需转换）

#### 修复的问题

| 问题 | 修复 |
|------|------|
| `while i < @len(arr)` 约束失效 | 支持 `@len()` 编译时求值 |
| 循环变量递增后上界丢失 | 循环内保留上界约束 |
| 函数间约束污染 | 函数开始时重置约束系统 |
| `usize` 类型不支持约束 | 文档说明使用 `i32` |

---

## 0.48 版本变更（相对于 0.47）

### 0.48 内存安全证明机制变更

- **证明失败处理变更**：
  - 之前：证明超时 → 自动插入运行时检查
  - 现在：证明失败 → 编译错误并给出修改建议
  - 更符合"坚如磐石"设计哲学：所有安全问题必须在编译期解决

- **编译器友好错误提示**：
  - 编译器无法完成证明时，报编译错误
  - 给出友好的修改建议（如：建议添加边界检查 `if i >= 0 && i < len { ... }`）
  - 不存在运行时才发现的安全问题

- **证明场景分类**（新增文档章节 14.5）：
  - **需要显式 `if` 判断**：变量数组索引、指针解引用、变量除法、变量运算溢出
  - **不需要显式 `if` 判断**：常量数组索引、循环变量范围推导、饱和/包装运算符、`try` 关键字

- **编译器优化规则**：
  - 证明条件为真 → 消除 `if`，直接执行 then 块
  - 证明条件为假 → 消除 then 块（死代码）
  - 无法证明 → 保留 `if` 运行时检查

- **约束系统实现**（memory-safety-proof 分支）：
  - 新增路径敏感分析框架
  - 支持从 if 条件提取约束（`i >= 0 && i < len`）
  - 支持约束验证数组边界
  - 嵌套 if 条件约束传播

---

## 0.47 版本变更（相对于 0.46）

### 0.47 泛型方法支持

- **泛型方法定义**：
  - 结构体/联合体方法支持独立的泛型参数：`fn method<T>(self: &Self) ReturnType`
  - 方法类型参数与结构体类型参数分离，形成二级查找
  - `Self` 类型在方法内自动替换为当前结构体的单态化类型

- **泛型方法调用**：
  - 方法调用支持显式类型参数：`obj.method<ConcreteType>()`
  - 单态化生成专门函数，零运行时开销
  - 示例：
    ```uya
    struct Container<T> {
        value: T,
        fn as_type<U>(self: &Self) U {
            return self.value as U;
        }
    }
    const c: Container<i32> = Container<i32>{ value: 42 };
    const v: i64 = c.as_type<i64>();  // 显式指定 U = i64
    ```

- **用途**：
  - 简化 Union 类型安全访问
  - 实现类型转换方法
  - 支持泛型工厂方法

---

## 0.45 版本变更（相对于 0.44）

### 0.45 extern 变量/常量支持

- **导入 C 全局变量**：
  - `extern const name: type;` - 导入只读 C 变量，生成 `extern const type name;`
  - `extern var name: type;` - 导入可变 C 变量，生成 `extern type name;`
  - 用途：访问 C 标准库全局变量（如 `errno`, `stdout`）

- **导出 Uya 全局变量给 C**：
  - `export const name: type = value;` - 导出只读常量，生成 `const type name = value;`
  - `export var name: type = value;` - 导出可变变量，生成 `type name = value;`
  - 用途：导出 Uya 全局状态给 C

- **`export extern "libc" fn` 语法**：
  - 支持用 Uya 实现替代 C 标准库函数
  - 生成裸函数名（无模块前缀），与 C 标准库链接

### 0.45 Scheme C 双入口架构

- **`export fn main()`**：生成 `main_main()`（应用入口）
- **`export extern fn main(argc, argv)`**：生成 `main()`（C 入口）
- **`fn main()`**：生成 `uya_main()`（旧架构兼容）
- 新增 `lib/std/runtime/entry/` 模块

---

## 0.44 版本变更（相对于 0.43）

### 0.44 @va_start / @va_end / @va_arg / @va_copy 内置函数

- **`va_list` 内置类型**：
  - `va_list` 是编译器内置类型，大小与目标平台相关（x86-64: 24字节，ARM64: 32字节，Windows x64: 8字节）
  - 可作为函数参数、结构体成员，可取指针

- **新增 `@va_start` / `@va_end` / `@va_arg` / `@va_copy` 内置函数**：
  - **语法**：`@va_start(&ap, last)`、`@va_end(&ap)`、`@va_arg(ap, Type)`、`@va_copy(&dest, src)`
  - **用途**：在可变参数函数内初始化/结束 va_list，或在接收 va_list 参数的函数内使用 @va_arg
  - **约束**：`@va_start` 仅可在形参含 `...` 的可变参数函数内使用；`@va_arg` 可在可变参数函数内或接收 va_list 参数的函数内使用
  - **实现**：编译时展开为 C 的对应宏
  - **设计目的**：支持实现 vprintf 等 C 标准库函数，完全兼容 C ABI

---

## 0.43 版本变更（相对于 0.42）

### 0.43 extern "libc" 语法支持

- **新增字符字面量**（0.43 新增）：
  - **语法**：`'a'`、`'x'`、`'\n'`、`'\t'`
  - **类型**：`byte`（对应 C 的 char）
  - **支持转义序列**：`\n`（换行）、`\t`（制表）、`\\`（反斜杠）、`\'`（单引号）、`\0`（空字符）
  - **用途**：表示单个字符的 ASCII 码值

- **byte 类型映射简化**（0.43 变更）：
  - `byte` 现在直接对应 C 的 `char`（之前是 `uint8_t`）
  - 这简化了 FFI，使 `byte` 与 C 字符串完全兼容

- **新增 `extern "libc" fn` 语法**：
  - **语法**：`extern "libc" fn name(...) type;` 或 `export extern "libc" fn name(...) type { }`
  - **用途**：显式声明 C 标准库函数，或用 Uya 实现替代 C 标准库函数
  - **设计目的**：使 FFI 代码意图更清晰，支持无 libc 依赖的编译
  - **byte 映射**：在 `extern "libc"` 上下文中，`byte` 映射为 C 的 `char`

- **新增 `extern` 变量支持**：
  - **导入 C 全局变量**：
    - `extern const name: type;` - 导入只读 C 变量，生成 `extern const type name;`
    - `extern var name: type;` - 导入可变 C 变量，生成 `extern type name;`
  - **导出 Uya 变量给 C**：
    - `export const name: type = value;` - 导出只读常量，生成 `const type name = value;`
    - `export var name: type = value;` - 导出可变变量，生成 `type name = value;`
    - `export extern const name: type;` - 链接到 C 库定义，不生成代码
  - **用途**：访问 C 标准库全局变量（如 `errno`, `stdout`），或导出 Uya 全局状态给 C
  - **类型限制**：仅支持 C 兼容类型（基本类型、指针、extern struct）

- **编译器修改**：
  - AST 新增 `fn_decl_extern_lib_name` 字段
  - Parser 支持解析 `extern "libc" fn` 和 `extern const/var` 语法
  - Checker 允许 `extern "libc" fn` 使用 FFI 指针类型
  - Codegen 为 `extern "libc" fn` 生成裸函数名（无模块前缀）

---

## 0.42 版本变更（相对于 0.41）

### 0.42 只读指针类型和函数导出规则

- **引入只读指针类型 `&const T` 和 `*const T`**：
  - **语法**：新增 `&const T` (Uya 内部只读引用) 和 `*const T` (FFI 只读指针) 语法
  - **语义**：在类型系统中明确区分可变和只读指针，提升类型安全和 C 互操作性
  - **C 映射**：`&const T` 和 `*const T` 均映射为 `const T*`
  - **字符串字面量**：`"..."` 可赋值给 `[byte: N]`、`&byte`、`*byte`，自动带 `\0` 结尾（规范见 uya.md §1.4）
  - **FFI 函数签名**：C 标准库中接受 `const char *` 的函数，在 `extern` 声明中应使用 `*const byte`
  - **类型转换规则**：
    - `&T` 可以隐式转换为 `&const T`（放宽约束，安全）
    - `&const T` 不能隐式转换为 `&T`（收紧约束，需要显式转换）
    - `&T` 可以通过 `as *const T` 显式转换为 `*const T`
    - `&const T` 可以通过 `as *const T` 显式转换为 `*const T`
  - **设计目的**：减少 `-Wdiscarded-qualifiers` 警告，提升 C 互操作性，在语言层面表达只读指针语义

- **函数导出规则完善**：
  - **函数可见性规则**：
    - `fn foo() void` → `static void foo(void)`（内部函数，不导出，带 `uya_` 前缀）
    - `export fn foo() void` → `void module_prefix_foo(void)`（导出函数，供其他模块使用，带模块前缀）
      - 模块前缀规则：
        - **同目录文件合并规则**：同一目录下的所有 `.uya` 文件都属于同一个模块（模块路径由目录路径决定，不包含文件名）
        - `lib/std/io/file.uya` 和 `lib/std/io/stream.uya` 都属于 `std.io` 模块 → 模块前缀 `std_io`
        - `lib/std/io/file.uya` 中的 `export fn fopen(...)` → `std_io_fopen(...)`
        - `lib/std/io/stream.uya` 中的 `export fn fgetc(...)` → `std_io_fgetc(...)`
        - `lib/std/mem/mem.uya` 属于 `std.mem` 模块 → 模块前缀 `std_mem`
        - `lib/std/mem/mem.uya` 中的 `export fn mem_copy(...)` → `std_mem_mem_copy(...)`
        - 主模块 `main.uya` 中的 `export fn my_func(...)` → `main_my_func(...)`
    - `extern fn foo() void` → `extern void foo(void);`（外部 C 函数声明，裸名）
    - `extern fn foo() void { ... }` → `void foo(void) { ... }`（Uya 实现，以裸函数名导出）
    - `export extern fn foo() void;`（无函数体）→ 不生成代码，链接到 C 标准库（裸名）
    - `export extern fn foo() void { ... }`（有函数体）→ `void foo(void) { ... }`（Uya 实现，以裸函数名导出）
  - **设计目的**：
    - 明确函数可见性：内部函数使用 `static`，避免符号冲突
    - 模块前缀避免不同模块的同名函数冲突
    - extern 函数使用裸名，便于与 C 标准库互操作
    - 符合 C 语言惯例：只有导出的函数才在全局命名空间
    - 支持标准库实现：Uya 标准库中的函数可以以裸 C 名称导出

**参考文档**：
- [uya.md](uya.md) §0.42 - 规范变更说明
- [uya.md](uya.md) §2.1.1 - 指针类型说明
- [uya.md](uya.md) §5.1 - 函数定义语法
- [uya.md](uya.md) §5.2 - 外部 C 函数（FFI）

---

## 0.41 版本变更（相对于 0.40）

### 0.41 宏系统规范细化（新增第 25 章）

- **宏定义语法**：`mc ID(param_list) return_tag { statements }`
  - 参数类型：`expr`（表达式）、`stmt`（语句）、`type`（类型）、`pattern`（模式）
  - 返回标签：`expr`（表达式）、`stmt`（语句）、`struct`（结构体成员）、`type`（类型标识符）
- **编译时内置函数**：
  - `@mc_eval(expr)`：编译时求值
  - `@mc_type(expr)`：编译时类型反射，返回 `TypeInfo` 结构体
  - `@mc_ast(expr)`：代码转抽象语法树
  - `@mc_code(ast)`：抽象语法树转代码
  - `@mc_error(msg)`：编译时错误报告
  - `@mc_get_env(name)`：编译时环境变量读取
- **缓存机制**：相同宏调用自动缓存，提升编译性能
- **安全限制**：递归深度、展开次数、嵌套层数限制
- **完整示例**：编译时断言、类型驱动代码生成、配置系统等

---

## 0.40 版本变更（相对于 0.39）

### 0.40.1 内置函数命名统一

- **`@sizeof(T)` → `@size_of(T)`**：复合概念使用 snake_case
- **`@alignof(T)` → `@align_of(T)`**：复合概念使用 snake_case
- **命名惯例确立**：
  - 单一概念：`@len`, `@max`, `@min`（短形式）
  - 复合概念：`@size_of`, `@align_of`, `@async_fn`（下划线分隔）

### 0.40.2 泛型语法确定

- 使用尖括号：`<T>`
- 约束紧邻参数：`<T: Ord>`
- 多约束连接：`<T: Ord + Clone + Default>`
- 示例：`fn max<T: Ord>(a: T, b: T) T { ... }`，`struct Vec<T: Default> { ... }`

### 0.40.3 结构体默认值语法

- 支持在结构体定义中为字段指定默认值：`field: Type = default_value`
- 初始化时可以使用 `Struct{}` 使用所有默认值，或 `Struct{ field: value }` 部分使用默认值（有默认值的字段可以忽略）
- 默认值必须是编译期常量，零运行时开销
- 与移动语义、RAII、接口实现完全兼容

### 0.40.4 异步编程基础设施（新增第 18 章）

- **语言核心**（编译器实现）：
  - `@async_fn`：函数属性，触发 CPS 变换生成显式状态机
  - `@await`：唯一显式挂起点
  - `union Poll<T>`：异步计算结果类型
  - `interface Future<T>`：异步计算抽象
- **函数签名约束**：必须返回 `!Future<T>`（显式异步，无隐式包装）
- **标准库实现**（基于核心类型）：
  - `std.async`：`Task<T>`, `Waker`
  - `std.channel`：`Channel<T>`, `MpscChannel<T>`
  - `std.runtime`：`Scheduler`
  - `std.thread`：`ThreadPool`, `async_compute<T>`
- **设计哲学**：
  - 显式控制：所有挂起必须 `try @await`，取消必须显式检查 `is_cancelled()`
  - 零成本：状态机栈分配，无运行时堆分配，无隐式锁
  - 编译期证明：状态机安全性、Send/Sync 推导、跨线程验证编译期完成
  - 类型安全：`Poll<T>` 使用 `union`（编译期标签跟踪），非 `enum`

---

## 0.39 版本变更（相对于 0.38）

### 0.39 方法 self 统一为 &T，*T 仅用于 FFI（破坏性变更）

- **方法首个参数统一为 `self: &T`**：
  - 接口：`interface I { fn method(self: &Self, ...) Ret; ... }`
  - 结构体方法：`S { fn method(self: &Self, ...) Ret { ... } }`
  - 替换原有的 `self: *Self` / `self: *StructName`
- **`*T` 仅用于 FFI**：`extern fn foo(buf: *byte, ...) i32`，作为 extern 函数的参数与返回值
- **`&T as *T` 转换**：调用 FFI 函数时，可使用 `expr as *T` 将 Uya 普通指针转为 FFI 指针
- **向后兼容性**：破坏性变更，需将现有 `self: *Self` 改为 `self: &Self`

---

## 0.38 版本变更（相对于 0.36）

### 0.38 指针类型 *T 用途澄清（已由 0.39 修订）

- 此前补充了 `*T` 在方法签名中的用法；0.39 将其统一为 `self: &T`，`*T` 仅用于 FFI。

---

## 0.36 版本变更（相对于 0.35）

### 0.36 drop 定义位置（规范澄清）

- **drop 只能在结构体/联合体内部或方法块中定义**：
  - 禁止顶层 `fn drop(self: T) void`，与「不引入函数重载」的设计一致。
  - 结构体：`struct S { fn drop(self: S) void { ... } }` 或 `S { fn drop(self: S) void { ... } }`。
  - 联合体同理：在联合体内部或方法块中定义 drop。
- **规范与实现**：uya.md §12、§4.1、§4.5.10 已更新；compiler-mini 已实现禁止顶层 drop 的检查。

---

## 0.35 版本变更（相对于 0.34）

### 0.35.1 error_id 分配与稳定性（规范补充）

- **error_id 分配**：`error_id = hash(error_name)`（djb2 算法），相同错误名在任意编译中映射到相同 `error_id`
- **hash 冲突**：不同错误名 hash 冲突时，编译器报错并提示冲突的两个名称，开发者需重命名其一
- **规范更新**：uya.md、grammar_formal.md、grammar_quick.md、uya_ai_prompt.md 已同步

### 0.35 联合体（union）支持

- **联合体类型**（规范 0.35，第 4.5 章）：
  - 添加 `union` 关键字定义标签联合体
  - 语法：`union UnionName { variant1: Type1, variant2: Type2, ... }`
  - 创建：`UnionName.variant(expr)`，如 `IntOrFloat.i(42)`
  - 访问：必须通过 `match` 模式匹配（处理所有变体）或编译器可证明的已知标签直接访问
- **编译期标签跟踪**：标签仅在编译期使用，不占用运行时内存，零运行时开销
- **C 互操作**：与 C union 100% 内存布局兼容，支持 `extern union`
- **完整能力**：支持联合体方法、接口实现、移动语义、drop 机制
- **向后兼容性**：非破坏性变更，纯新增特性

---

## 0.34 版本变更（相对于 0.33）

### 0.34 参数列表即元组、可变参数、字符串插值与 printf

- **参数列表即元组**（规范 0.34）：
  - 当函数使用 **`@params` 内置变量**时，编译器将整个参数列表视为一个元组。
  - 对于**所有函数**（无论是否可变参数），`@params` 都包含所有参数，提供统一、类型安全的访问方式（`.0`/`.1` 或解构）。
  - 参数的类型序列与元组类型等价；命名访问与按位置元组访问两种视图并存。
- **可变参数（C 语法兼容 + 类型安全元组访问）**：
  - **声明语法**：沿用 C 的 `...` 语法，如 `fn printf(fmt: *byte, ...) i32;`
  - **统一访问**：函数体内使用 `@params` 访问所有参数作为元组
  - **编译器智能优化**：使用 `@params` 时生成元组打包代码；未使用时直接转发参数，零开销
  - **ABI 兼容**：与 C variadic 约定兼容；C 可直接调用 Uya 导出的可变参数函数
  - **格式串推断**：对 printf 风格 API，可由格式串推断可变参数元组类型
- **字符串插值与 printf 结合**：
  - 当插值结果仅作为 printf/print 的格式参数时，允许脱糖为单次 `printf(fmt, ...)`，无需中间缓冲区。
- **向后兼容性**：非破坏性变更；均为新增或可选优化。

---

## 0.33 版本变更（相对于 0.32）

### 0.33 数组字面量重复形式与类型语法统一为冒号

- **重复数组字面量**（第 1 章、第 7 章）：
  - 语法由 `[value; N]` 改为 **`[value: N]`**，与数组类型 `[T: N]` 一致，统一使用冒号表示「内容 : 长度」
  - N 须为编译期常量（字面量或顶层 const）
- **类型与字面量一致性**：数组类型 `[T: N]` 与重复字面量 `[value: N]` 均使用 `:`，便于记忆、减少符号种类
- **向后兼容性**：破坏性变更，现有使用 `[value; N]` 的代码需改为 `[value: N]`

---

## 0.32 版本变更（相对于 0.31）

### 0.32 内置函数统一以 @ 开头

- **所有内置函数以 `@` 开头**（第 1 章、第 16 章）：
  - `sizeof` → `@sizeof(T)`：类型大小查询
  - `alignof` → `@alignof(T)`：类型对齐查询
  - `len` → `@len(a)`：数组长度查询
  - `max` → `@max`：整数类型最大值（类型从上下文推断，原为关键字）
  - `min` → `@min`：整数类型最小值（类型从上下文推断，原为关键字）
- **关键字变更**：`max`、`min` 从关键字中移除，改为内置函数标识（以 `@` 开头）
- **语法**：内置函数调用形式为 `@sizeof(T)`、`@alignof(T)`、`@len(expr)`；极值形式为 `@max`、`@min`（无参数，类型由上下文推断）
- **向后兼容性**：破坏性变更，现有使用 `sizeof`、`alignof`、`len`、`max`、`min` 的代码需改为 `@sizeof`、`@alignof`、`@len`、`@max`、`@min`

---

## 0.30 版本变更（相对于 0.29）

### 0.30 alignof 改为内置函数

- **alignof 改为内置函数**（第 16 章）：
  - `alignof` 从标准库函数改为编译器内置函数，无需导入即可使用
  - 不再需要 `use std.mem.alignof;`，可以直接使用 `alignof(T)`
  - 编译期折叠为常数，零运行时开销
  - 与 `sizeof` 和 `len` 函数一致，都是编译器内置的，自动可用
- **向后兼容性**：
  - 这是破坏性变更，现有使用 `use std.mem.alignof;` 的代码需要移除导入语句

### 0.30 Uya 指针到 FFI 指针的显式转换

- **指针类型转换支持**（第 5.2 章、第 11 章）：
  - ✅ **Uya 普通指针 `&T` 可以通过 `as` 显式转换为 FFI 指针类型 `*T`**
  - 使用 `as` 进行安全转换：`&T as *T`（无精度损失，编译期检查）
  - 仅在 FFI 函数调用时使用，符合 Uya "显式控制"的设计哲学
  - 示例：`extern write(fd: i32, buf: *byte, count: i32) i32;` 调用时使用 `write(1, &buffer[0] as *byte, 10);`
- **类型转换规则更新**（第 11.4 章）：
  - 在转换规则表中添加指针类型转换：
    - `&T` → `*T`：✅ 支持 `as`（安全转换）
    - `*T` → `&T`：❌ 不支持 `as`，✅ 支持 `as!`（强转）
- **设计哲学一致性**：
  - 保持"零隐式转换"原则，通过显式 `as` 转换
  - 编译期验证，无运行时开销
  - 类型安全，防止误用
- **向后兼容性**：
  - 这是新增功能，不影响现有代码
  - 现有代码可以继续使用，新代码可以使用显式转换更方便地与 C 函数互操作

---

## 0.29 版本变更（相对于 0.28）

### 0.29 文档增强和规范细化

- **结构体内存布局详细规则**（第 4.2 章）：
  - 新增详细章节，完整说明结构体字段对齐、填充、嵌套结构体布局规则
  - 明确字段偏移计算公式：`offset(field_n) = align_up(offset(field_n-1) + sizeof(field_n-1), alignof(field_n))`
  - 明确填充字节内容为 0（零填充），确保结构体布局的可预测性
  - 详细说明嵌套结构体、数组字段、特殊类型字段（切片、接口、错误联合类型）的布局规则
  - 提供结构体大小和对齐的完整计算规则
  - 说明不同平台（32位/64位）的结构体布局差异
  - 明确空结构体的特殊规则（大小 = 1 字节，对齐 = 1 字节）
- **函数调用约定详细说明**（第 5.1.2 章）：
  - 新增详细章节，完整说明函数调用约定（ABI）规则
  - 详细说明 x86-64 System V ABI（Linux、macOS、BSD）的参数传递、返回值传递、寄存器使用规则
  - 详细说明 x86-64 Microsoft x64 Calling Convention（Windows）的调用约定
  - 详细说明 ARM64 ABI（AArch64）的调用约定
  - 详细说明 32位 x86 平台的 cdecl 调用约定
  - 明确错误联合类型 `!T` 的返回值处理规则（与普通结构体相同）
  - 提供调用约定总结表，对比不同平台的规则差异
  - 强调所有调用约定都与 C ABI 完全兼容，编译器自动选择正确的调用约定
- **文档优化**：
  - 优化文档结构和章节组织
  - 增强技术细节的完整性和准确性
  - 为编译器实现提供更详细的参考规范

---

## 0.28 版本变更（相对于 0.27）

### 0.28 sizeof 改为内置函数

- **sizeof 改为内置函数**（第 16 章）：
  - `sizeof` 从标准库函数改为编译器内置函数，无需导入即可使用
  - 不再需要 `use std.mem.{sizeof, alignof};`，可以直接使用 `sizeof(T)`
  - 编译期折叠为常数，零运行时开销
  - 与 `len` 函数一致，都是编译器内置的，自动可用
- **向后兼容性**：
  - 这是破坏性变更，现有使用 `use std.mem.{sizeof, alignof};` 的代码需要移除导入语句
  - `alignof` 仍然保留为标准库函数，需要导入使用

---

## 0.25 版本变更（相对于 0.24）

### 0.25 函数指针类型和导出函数支持

- **函数指针类型**（第 5 章）：
  - 新增函数指针类型语法：`fn(param_types) return_type`
  - 支持类型别名：`type ComparFunc = fn(*void, *void) i32;`
  - `&function_name` 的类型是函数指针类型（不是 `*void`）
  - 仅在 FFI 上下文中使用，用于与 C 函数指针互操作
- **导出函数给 C**（第 5.2 章）：
  - `extern fn name(...) type { ... }` - 导出 Uya 函数为 C 函数（导出，供 C 调用）
  - 导出的函数可以使用 `&name` 获取函数指针，传递给需要函数指针的 C 函数
  - 函数参数和返回值必须使用 C 兼容的类型
- **类型系统更新**：
  - 在类型系统中添加函数指针类型：`fn(...) type`
  - 函数指针类型大小：4/8 B（平台相关，与普通指针相同）

---

## 0.24 版本变更（相对于 0.23）

### 0.24 接口实现语法简化

- **移除接口实现块语法**（第 6 章）：
  - 删除了 `StructName : InterfaceName { ... }` 这种单独的接口实现块语法
  - 结构体在定义时声明接口：`struct StructName : InterfaceName { ... }`
  - 接口方法作为结构体方法定义，可以在结构体内部（与字段一起）或外部方法块中定义
  - 语法更简洁，接口方法就是结构体方法，无需区分
- **接口实现语法简化**（第 6 章）：
  - 移除了 `impl` 关键字，接口实现语法从 `impl StructName : InterfaceName {}` 简化为 `StructName : InterfaceName {}`
  - 语法更简洁，与结构体方法定义更对称（结构体方法：`StructName {}`，接口实现：`StructName : InterfaceName {}`）
  - `:` 符号语义清晰，表示"实现"关系，与类型标注的 `:` 一致
- **接口组合语法优化**（第 6 章）：
  - 接口组合语法保持不变，在接口体中直接列出被组合的接口名
  - 推荐使用分号分隔组合接口名（如 `IReader; IWriter;`），与方法签名格式一致，更清晰
  - 接口组合和方法签名可以混合使用
- **关键字列表更新**：
  - 从关键字列表中移除 `impl`，不再是保留关键字
- **向后兼容性**：
  - 这是破坏性变更，需要迁移现有代码中的 `impl` 语法
  - 建议作为版本升级的一部分

---

## 0.23 版本变更（相对于 0.22）

### 0.23 统一结构体标准

- **统一结构体标准**（第 4 章）：
  - 所有 `struct` 统一使用 C 内存布局，无需 `extern` 关键字
  - 移除了 `extern struct` 的特殊语法，统一为标准 `struct`
  - 所有结构体都可以直接与 C 代码互操作，编译器自动生成对应的 C 兼容布局
- **支持所有类型**（第 4 章）：
  - 结构体可以包含所有类型（基础类型、数组、切片、接口、错误联合类型、原子类型等）
  - 不再限制结构体字段类型，支持完整的 Uya 类型系统
- **完整 Uya 能力**（第 4 章）：
  - 所有结构体都可以有方法（结构体内部或外部定义）
  - 所有结构体都可以有 drop 函数（实现 RAII 自动资源管理）
  - 所有结构体都可以实现接口（支持动态派发）
  - 同一个结构体，两面性：C 代码看到纯数据，Uya 代码看到完整对象
- **C 内存布局定义**（第 4.1 章）：
  - 定义了切片类型 `&[T]` 在 C 中的表示：`{ void* ptr; size_t len; }`
  - 定义了接口类型 `InterfaceName` 在 C 中的表示：`{ void* vtable; void* data; }`
  - 定义了错误联合类型 `!T` 在 C 中的表示：`{ uint32_t error_id; T value; }`（error_id == 0 表示成功）
- **文档优化**：
  - 优化了 `grammar.md` 和 `uya.md` 的一致性和清晰度
  - 添加了结构体方法的完整语法定义
  - 添加了文档间的交叉引用
  - 统一了术语表述

---

## 0.22 版本变更（相对于 0.21）

### 0.22 切片类型重构
- **切片类型系统**（第 2 章）：
  - 新增切片类型 `&[T]`（动态长度切片引用）和 `&[T: N]`（已知长度切片引用）
  - 切片是胖指针（指针+长度），大小 16 字节，零堆分配
- **切片语法更新**（第 4 章）：
  - 废弃旧语法 `arr[start:len]`（返回新数组）
  - 新语法 `&arr[start:len]`（返回切片视图）
  - 支持负数索引：`&arr[-3:3]` 等价于 `&arr[7:3]`（对于长度为 10 的数组）
- **for循环支持切片**（第 8 章）：
  - 值迭代：`for slice |value| { }`（只读）
  - 引用迭代：`for slice |&ptr| { }`（可修改）
  - 索引迭代：`for slice |i| { }`（只获取索引）
  - 索引和值：`for slice |i, value| { }` 或 `for slice |i, &ptr| { }`
- **切片生命周期规则**（第 6.5 章）：
  - 切片生命周期 ≤ 原数据生命周期
  - 编译器自动验证切片不会超过原数据的生命周期
  - 切片是原数据的视图，修改原数组会影响切片
- **字符串切片**（第 17 章）：
  - 字符串数组 `[i8: N]` 支持切片操作：`&text[start:len]`
  - 字符串切片类型为 `&[i8]`，可定义类型别名 `type str = &[i8]`
- **性能保证**：
  - 零分配：切片是胖指针，无堆分配
  - 编译期展开：for循环编译期展开
  - 编译期验证：边界检查在编译期完成
  - 内存安全：生命周期自动绑定，防止悬垂引用

---

## 0.20 版本变更（相对于 0.19）

### 0.20 泛型语法优化
- **泛型定义语法优化**：定义使用括号 `struct S(T)` / `interface I(T)`，与实例化 `S(i32)` / `I(i32)` 完全对称，参数顺序明确
- **函数自动推断**：泛型函数保持自动推断，无需显式指定类型参数，更简洁
- **新增泛型容器库示例**：完整的 `ArrayList(T)`、`Collection(T)` 接口和实现示例（第 20 章 6.3 节）

---

## 0.19 版本变更（相对于 0.18）

### 0.19 文档更新
- **FFI 指针类型支持扩展**（第 2 章、第 5.2 章、第 5.3 章）：
  - 明确 FFI 指针 `*T` 支持所有 C 兼容类型，包括 `*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`, `*f32`, `*f64`, `*bool`, `*byte`, `*void`, `*CStruct`
  - 统一指针语法：将所有 `byte*` 替换为 `*byte`（即 `*T` 形式，T=byte），统一使用 `*T` 语法
  - 添加统一指针语法规则说明，明确区分三种指针类型：
    - `&T`：Uya 内部安全指针，支持所有 Uya 类型
    - `*T`：FFI 专用指针，仅用于 C 语言互操作，支持所有 C 兼容类型
    - `&[T]`：参数语法糖，表示指针+长度的组合
  - FFI 指针使用规则：
    - ✅ 仅用于 FFI 函数声明/调用和 extern struct 字段
    - ✅ 支持下标访问 `ptr[i]`，但必须提供长度约束证明
    - ❌ 不能用于普通变量声明（编译错误）
    - ❌ 不能进行普通指针算术（只能用于 FFI 上下文）
  - 添加 `*u16` 等类型的完整使用示例和禁止用法示例
  - 强调设计哲学一致性：显式区分、安全强化、编译期验证、零隐式转换、C 兼容性

---

## 0.17 版本变更（相对于 0.16）

### 0.17 新增特性
- **移动语义**（第 12.5 章）：结构体赋值时转移所有权，避免不必要的拷贝
  - 自动移动场景：赋值、函数参数传递、返回值、结构体字段初始化、数组元素赋值
  - 严格检查机制：存在活跃指针时禁止移动，防止悬垂指针
  - 与 RAII 完美配合：移动后只有目标对象调用 drop，防止 double free
- **结构体方法语法糖**（第 29.3 章）：`obj.method()` 语法糖，编译期展开为静态函数调用
  - 支持 `Self` 占位符：`fn method(self: *Self) ReturnType`，与接口实现语法一致
  - 必须使用指针：`self: *Self` 或 `self: *StructName`，不允许按值传递，避免语义歧义
  - 方法调用不触发移动：调用时自动传递指针（`&obj`），确保方法调用后原对象仍然可用
  - 编译期展开：编译期展开为静态函数，所有方法都是静态绑定
- **Self 类型扩展**：`Self` 占位符现在可以在结构体方法中使用，与接口实现保持一致
- ***T 语法扩展**：`*T` 语法现在可以在结构体方法的方法签名中使用

---

## 0.16 版本变更（相对于 0.15）

### 0.16 新增特性
- **字符串插值**（第 23 章）：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **安全指针算术**（第 27 章）：支持 `ptr +/- offset`，必须通过编译期证明安全
- **测试单元**（第 28 章）：`test` 块用于单元测试

---

## 0.15 版本变更（相对于 0.14）

### 0.15 新增特性
- **sizeof 和 alignof**：标准库函数，用于获取类型大小和对齐，编译期常量
  - 位置：`std/mem.uya`
  - 使用：`use std.mem.{sizeof, alignof};`
  - 支持所有基础类型、数组、结构体、原子类型等

---

## 语法简化（跨版本）

### for 循环语法简化
- 移除 `iter()` 和 `range()` 函数，直接支持 `for obj |v| {}` 和 `for 0..10 |v| {}`
- 新增可修改迭代语法：`for obj |&v| {}`（用于修改数组元素）
- 支持丢弃元素语法：`for obj {}` 和 `for 0..N {}`（只循环次数，不绑定变量）

### 运算符简化
- 移除 `checked_*` 函数，使用 `try` 关键字进行溢出检查（如 `try a + b`）
- 移除 `saturating_*` 函数，使用饱和运算符（`+|`, `-|`, `*|`）
- 移除 `wrapping_*` 函数，使用包装运算符（`+%`, `-%`, `*%`）

---

## 向后兼容性

- 所有 0.13 代码保持兼容（语法变更不影响现有代码）
- 新语法完全可选，可以继续使用原有方式
