# Uya v0.10.3 发布说明

> **类型**：**v0.10.x 发行线上的补丁版本**（patch）
> **发布日期**：2026-10-05

在 **v0.10.2** 把 `std.process` 进程/流水线运行时与 typed pipeline 推到端到端口径之后，**v0.10.3** 用一周（2026-09-27 → 2026-10-05）收口两类问题：一是**大工程与 C99 split-C 的容量/命名**——checker 五张写死容量的表改成通用动态哈希表，split-C 下的同名顶层常量与 hosted 系统头宏名冲突；二是 **async 缺失项的三条主线**——hosted 多线程并发 `malloc/free` 堆损坏、`Waker` 多 fd/多 interest、HTTP/1 连接池与 keep-alive、TLS 1.2 会话复用、macOS `kqueue` 后端。

---

## 核心变更

### 1. checker：五张定长表 → 通用动态哈希表（大工程不再撞容量）

`symbol_table` / `function_table` / `module_table` / `import_table` / `string_pool` 原先都是写死容量的数组（32768 / 8192 / 256 / 512 / 16384）。实测一个 112 文件、约 6800 个声明的工程（`uya-agent`）在 `FUNCTION_TABLE_SIZE = 8192` 下**只剩 9 个函数**的余量：再加第 10 个就报 `函数表容量不足，请增大 FUNCTION_TABLE_SIZE`，而报错点落在**标准库**里（`lib/std/http/uyagin_router.uya`），使用者完全看不出根因，也没有可用的开关。

新增 `src/checker/dyn_table.uya`：一套「开放寻址 + 线性探测 + 满载 2 倍扩容 + rehash」的实现，五张表共用（`string_pool` 是链式桶，单独把桶数组改成动态并支持扩容重挂链）。旧常量保留为**初始容量**（不再是上限），小工程的容量、内存画像与性能与改动前一致。

函数表的插入/查找语义（同名不同模块共存、调用点模块优先、extern 签名一致则不重复插入、一 extern 一普通则覆盖）**逐条保持**。表按**指针**元素存储（元素大小 = `@size_of(&X)`），保持编译器的指针身份语义——作用域链表的 `next_in_scope` 与表槽必须指向同一个 `Symbol`。

修复过程中踩到并修掉三个实现缺陷（都写进了 `dyn_table.uya` 的注释）：① 扩容时只清零键数组、没清值缓冲 ⇒ 空槽读到 malloc 垃圾指针（编译器自编当场段错误）；② 表按值拷贝结构体会切断作用域链表的指针身份（符号查找依赖 `==` 比较）；③ 旧的 `hash & (SIZE - 1)` 掩码天生非负，换成 `hash % capacity` 后会得到负下标，所有调用点都要补一次负数归一。

### 2. C99 split-C 与 hosted 的命名收口

- **同名顶层常量重复发射定义**。`gen_extern_var_decl` 用上限 512 的 `codegen.global_variables` 注册表判断「这个 C 名是否已经发射过定义」，而该表**表满后静默丢弃登记**：小程序撑不满、去重生效看不出问题，`uya-agent`（1700+ 顶层全局）表早就满了，两份定义一路漏到链接期报 `multiple definition`。现在新增一张独立的「已发射定义的全局 C 名」集合（开放寻址 + 线性探测，容量 8192），定义路径先查再登记；**表满时不再静默降级，而是当场报错退出**，错误信息带 `文件:(行:列)`、表名与容量、要登记的全局名与修复指引。`gen_global_var`（模块内私有非常量全局）刻意不动——那里重名会**大声**报链接错误，去重反而会把 loud failure 换成 silent wrong。
- **`libc.stdlib` / `libc.time` 的 `CLOCKS_PER_SEC` 重复定义**（真实例子）：合并命名空间里两份同名 `export const`，split-C 下每个模块各出一个 `.o`、都带外部定义，链接期报 `multiple definition of 'CLOCKS_PER_SEC'`。按 C 标准（`CLOCKS_PER_SEC` 属于 `<time.h>`）只由 `libc.time` 提供，`libc.stdlib` 不再定义第二份，`use libc.CLOCKS_PER_SEC` 用法不变。
- **hosted 下用户顶层全局与系统头宏同名**。hosted 生成会为非 bootstrap 编译单元 `#include <errno.h>` 等系统头，宏是文本替换，于是 `const ETIMEDOUT: i32 = 110;` 这类裸名顶层全局的单文件定义与镜像头声明双双报 `error: expected identifier or '(' before numeric constant`。现在在全局声明/定义前按需发射 `#ifdef X / #undef X / #endif` 护栏（判据为"宏形态"标识符——纯标识符且含大写字母，外加 `errno`/`stdin`/`stdout`/`stderr`；跳过编译器自身发射的 `uya_`/`UYA_` 前缀），覆盖 `gen_global_var`、`gen_extern_var_decl`、`c99_mirror_emit_extern_global_line` 三个发射点。

### 3. async 缺失项：堆、调度与网络组合

- **hosted 多线程并发 `malloc/free` 必然踩坏堆（P0）**。根因是 `lib/libc/pthread.uya` 的 `clone` 不含 `CLONE_SETTLS`，子线程只用 `arch_prctl(ARCH_SET_GS)` 设了 GS、从不建立 FS/TLS；而 hosted 模式把 `malloc/free` 让给了宿主 glibc（per-thread tcache/arena 挂在 FS 上），于是所有 uya 线程共用父线程的 glibc TLS。独立 C 复现确认：glibc `pthread_create` 3/3 通过、raw clone（无 `CLONE_SETTLS`）3/3 堆损坏。修法是 hosted 下保留 uya 自己的线程安全堆（`lib/libc/heap.uya`），`libc.stdlib` 的 `calloc` 一并留在 uya 侧避免跨分配器错配。
- **`Waker` 单 fd / 单 interest**。原先「同时等两个 fd」会退化成只等最后一个；现扩为有界槽表（`WAKER_IO_SLOT_MAX = 4`，同 fd 的 RD|WR 合并成 `READWRITE`，不同 fd 各占一槽），`_io_fd`/`_io_interest` 保留为「最后一次声明」的主槽镜像，单 fd 调用点行为不变；`async_scheduler` 新增 `SchedulerFdRegs` 记录每个已注册 fd，遍历全槽注册并对陈旧注册做差集注销。
- **HTTP/1 客户端连接池 + keep-alive 复用**。修复前每个请求都发 `Connection: close`、用完即关（N 个请求 = N 次 TCP，HTTPS 还要 N 次握手）。新增进程内单例 `Http1AsyncPool`（有界 8 个空闲槽，按 host 字节 + port 精确匹配，池满或 host 超长时关 fd 而不是截断误配）；`Http1AsyncRequest.persist`（默认 0 = 旧行为）控制是否走 keep-alive；响应头解析新增 `Connection: close` 识别，`http1_async_finish_connection` 只在「调用方要求 persist + 响应非 `read_until_eof` + 未声明 close」时回池——**宁可少复用，也不要把坏连接放回池**。
- **TLS 1.2 会话复用（会话 ID 路径）**。新增 `TlsSessionCache`（`lib/tls/ssl/handshake.uya`，按 host 缓存会话 ID + `master_secret` + 密码套件；进程内单例、有界 8 条、同 host 覆盖）。客户端可让 ClientHello 携带会话 ID 请求复用（为空时与修复前逐字节一致）；服务器只在「客户端带了 ID **且**本地缓存有同 host 同 ID 的白名单条目」时才回显接受，接受时把缓存的 `master_secret` 装回上下文；客户端解析到一致的回显会话 ID 才算「已复用」，为空/不一致视为拒绝并**退回完整握手而不失败**。
- **macOS `kqueue` 后端**。修复前 macOS 分支退化成 `poll(2)` 全表扫描（功能正确但 O(n)）。现在 `kqueue()` 成功即走 kqueue、失败回退原 poll，采用水平触发（不加 `EV_CLEAR`）对齐 epoll 默认语义，**Linux 路径逐字节未变**。`kqueue`/`kevent` 走 `dlsym` 而不是直接引用宿主符号——因为 macOS 目标的 C 也会被 `tests/verify_std_path_platform_targets.sh` 用宿主 Linux cc 编译来跑语义测试，直接引用会在链接期 `undefined reference`。
- **HTTP/1 响应头块上限可配置**。新增 `http1_async_response_header_max_cap()`（默认 65536，`UYA_HTTP1_RESPONSE_HEADER_MAX_CAP` 可覆盖，非法值回退默认），与 `LinuxEpoll` / `AsyncFramePool` / `Scheduler` 的既有口径一致。

### 4. 标准库信号修复

- **`libc.signal`：`signal()` 装的处理器一收到信号就 SIGSEGV（x86_64）**。x86-64 的信号交付路径要求 `sa_flags` 带 `SA_RESTORER` 且 `sa_restorer` 指向执行 `rt_sigreturn` 的垫片，而旧实现用裸 `rt_sigaction` 装处理器（`sa_flags = 0`、`sa_restorer = null`），于是处理器体一次都不执行、进程直接以 SIGSEGV(139) 退出。回移 0.11 的同名实现：新增 `@naked_fn _signal_restorer()`（x86_64 走 `movq $15, %rax; syscall`，arm64/arm32 分支同在）；`signal()` 置 `SA_RESTORER` + `sa_restorer` 并返回内核回填的旧动作；`SIG_ERR` 由 `0xFFFFFFFF` 改成全 1（64 位 `(void*)-1`，否则旧处理器判等永远不成立）；`sigprocmask` 改为把 `sigset_t` 指针交给内核（旧实现传值必然 `EFAULT`）；`raise` 用 `gettid` 定位调用线程；`atexit`/`on_exit` 改为声明宿主实现（旧实现只把回调存表、从不调用）。

---

## 升级指南

从 `v0.10.2` 升级到 `v0.10.3`：

```bash
git pull
git checkout v0.10.3

make clean && make release
```

异步网络相关的新能力默认保持旧行为：HTTP/1 的 keep-alive 需要显式设置 `Http1AsyncRequest.persist` 才启用；`Waker` 单 fd 调用点不变；HTTP/1 响应头上限可用 `UYA_HTTP1_RESPONSE_HEADER_MAX_CAP` 放宽。

---

## 统计与验证

| 项目 | 说明 |
|------|------|
| 相对 `v0.10.2` | 11 个提交（2026-09-27 → 2026-10-05，不含本次发布收口提交），`src/` + `lib/` + `tests/` 37 个文件、+5505/-471 行（`src/` 16 文件 +1052/-249；`lib/` 9 文件 +1448/-222；`tests/` 12 文件 +3005/-0） |
| 新增回归 | `tests/test_dyn_table_growth.uya`、`tests/test_pthread_heap_concurrency.uya`、`tests/test_async_waker_multi_interest.uya`、`tests/test_http1_async_client.uya`（3 个新用例）、`tests/test_tls_session_resumption.uya`、`tests/test_async_event_kqueue_transition.uya`、`tests/test_hosted_macro_name_collision.uya`、`tests/test_signal.uya`（2 个新用例）、`tests/verify_split_dup_global.sh`（+ `tests/fixtures/split_dup_global/`） |
| 自举一致性 | `make b` 自举对比通过（主编译器与自举编译器产物 `cmp` 字节一致） |
| 大工程验证 | 用新编译器编译 `uya-agent` 的 49 个源文件，并额外加上 100 / 8000 / 20000 个空函数全部通过（改动前 +10 个就失败）；`uya-agent` split-C 构建由链接失败恢复为编译完成并跑通 `--selftest` |
| 验证闸门 | async 专项闸门（shared_runtime_matrix / production_smoke / full_language_matrix / nested_future_boundary / cancel_cleanup）、`tests/verify_std_path_platform_targets.sh` 全部通过 |
| 发布产物 | `bin/uya` 使用 `-O3 -fno-builtin -DNDEBUG` 构建并 strip |
| 上一标签 | `v0.10.2` |

---

## 已知限制

- **macOS `kqueue` 后端未经真机验收**：本机无 macOS SDK/runtime，只做了 ABI/C 级与「poll 掩码 → kevent 变更集」翻译规则级验证（`tests/test_async_event_kqueue_transition.uya`，7 个用例，Linux 上也能覆盖纯函数部分）。真实 `kqueue`/`kevent` 调用与唤醒时序待真机验证。另外本机用 zig 交叉编译任何含 libc 的 uya 程序到 macOS 都会因 `struct timeval` 与 Darwin SDK 重定义而失败（与本项无关）。
- **TLS 会话复用只覆盖会话 ID 路径**：未实现会话票据（session ticket）；会话缓存为进程内单例、有界 8 条。
- **Windows IOCP 后端**仍未落地（沿用 poll 回退）。

---

## 致谢

感谢所有为本版本 checker 动态表、C99 split-C 命名收口、async 堆/调度/网络组合与信号修复贡献的参与者。

---

**标签**：`v0.10.3`
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.10.3)
**完整变更日志**：[CHANGELOG.md](../../CHANGELOG.md)
