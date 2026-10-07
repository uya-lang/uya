# 编译器 / 标准库 Bug 待办清单

**最后更新：** 2026-10-04（异步编程缺失项收口第一轮：**hosted 模式下多线程并发 `malloc/free` 必然踩坏堆**（P0）已定位并修复 —— 根因是 `lib/libc/pthread.uya` 的 `clone` 不含 `CLONE_SETTLS`，线程没有 FS/TLS，而 hosted 下 `malloc/free` 让给了宿主 glibc（per-thread tcache/arena 挂在 FS 上），于是所有 uya 线程共用父线程的 glibc TLS；独立 C 复现：glibc `pthread_create` 3/3 通过、raw clone 3/3 堆损坏。修法是 hosted 下保留 uya 自己的线程安全堆（`lib/libc/heap.uya`）并把 `calloc` 一并留在 uya 侧避免跨分配器错配；新增回归 `tests/test_pthread_heap_concurrency.uya`，hosted 套件 1112/1112。同轮：**`Waker` 单 fd/单 interest**（P2）扩成有界槽表并让调度器注册全部 fd（新增 `tests/test_async_waker_multi_interest.uya`）；**HTTP/1 响应头上限**（P2）改为默认值 + `UYA_HTTP1_RESPONSE_HEADER_MAX_CAP` 可覆盖。详见"运行时 bug"与"标准库 bug"首两条。；另 2026-10-04：2026-10-04（split-C 下同名顶层常量重复发射定义（`multiple definition`）的**根因**已在后端收口：`gen_extern_var_decl` 原本用上限 512 的 `global_variables` 注册表当查重依据，`uya-agent` 有 1700+ 顶层全局、表满后静默停登导致去重失效；新增独立的「已发射全局 C 名」集合（`C99_EMITTED_GLOBAL_CAP = 8192`，**表满即报错并指出文件:行:列与全局名**，不再静默降级）与 `tests/verify_split_dup_global.sh` 回归（已挂进 `make check` / `make check-hosted`），`make b` 自举字节一致、`make check` 1111/1111，详见"编译器 bug"首条；2026-10-03（split-C 下 `libc.stdlib` 与 `libc.time` 的 `CLOCKS_PER_SEC` 双双 emit 成外部定义导致链接期 multiple definition 已修复：`lib/libc/stdlib.uya` 删掉那份重复常量，`uya-agent` 工程 split 构建恢复通过，详见"标准库 bug"首条；`libc.signal` 的 `signal()` 装的处理器一收到信号就 SIGSEGV（x86_64 缺 SA_RESTORER / rt_sigreturn 垫片）已修复：回移 0.11 实现，新增回归 `tests/test_signal.uya` 的 `signal_handler_is_invoked` / `sigprocmask_blocks_delivery`，详见"标准库 bug"首条；2026-09-27（hosted 下用户顶层全局与系统头宏同名（如 `const ETIMEDOUT: i32 = 110;`）导致镜像头 `uya_mirror_globals.h` 与单文件定义双双编译失败已修复，详见"编译器 bug"首条，新增回归 `tests/test_hosted_macro_name_collision.uya`；本轮复核并关闭 3 条已被代码推翻的旧条目：`DNS_PREFER_ANY` 异步聚合已并发化、`@async_fn` 的 `while true` 回跳已改为统一 label + goto、`uintptr_t` 指针算术模式在当前生成 C 中已不存在；`test_async_event_dynamic_growth` 在默认 fd 软上限（1024）的终端里必然失败（`make release` 只挂这一项）已修复：根因是用例要同时持有 2050+ 个 fd 才能跨过 `LinuxEpoll` 默认 1024 slot 边界，而登录终端/CI 的 `RLIMIT_NOFILE` 软上限常为 1024，`pipe2` 报 `EMFILE`；`tests/run_programs_parallel.sh` 启动时把软上限提升到硬上限，用例自身也用 `setrlimit` 抬够（抬不够则 stderr 报 `skip:` 并跳过扩容部分）；同限制下 `make check` 1110/1110；`bench_malloc_phase4` 系列满并发偶发 SIGSEGV 已定位并修复：根因是 pthread join 在子线程还在内核返回路径上就 `free(stack)`/`munmap(desc)`，栈被后续 mmap 复用清零后子线程从栈里取到 0 返回地址跳转到地址 0（use-after-unmap），修复方式是用 `clear_child_tid`(set_tid_address) + 共享 `FUTEX_WAIT` 做退出确认，新增回归 `tests/test_pthread_join_stack_reuse.uya`；"数组索引边界证明器不跨 `as usize` cast 传递范围事实"经当前树复现验证已修复（文档复现命令编译通过），补回归 `tests/test_bounds_prover_as_usize_cast.uya` + 负例 `tests/error_array_bounds_signed_cast_lower_bound.uya`；同源的反向漏判（有符号源 `as usize` 下标被当作天然非负 → 静默越界读）及其暴露出的成员访问约束名悬垂指针（负哈希跳过池化 → 证明结果随变量名变化）一并修复；跟踪的自举种子陈旧导致 `make release` 冷启动链接失败（`uya_pipeline_worker_dispatch` 未定义）：已按流程刷新 `backup/*.c` 种子；hosted 路线下 `bin/uya-hosted` 一运行即 abort（`glibc detected an invalid stdio handle`）已修复：hosted 下 stdio 整体保留 uya 实现，调用点/声明点/文本发射的 C 名统一解析到 uya 的模块前缀符号，`stdin/stdout/stderr` 一并绑回 uya 流对象；模块作用域 bug 经 `make check` 全绿确认关闭）；2026-09-11 新增并修复 5 项编译器 bug：macOS 交叉目标宿主绑定被 `#ifdef __APPLE__` 裁掉、微应用 payload 打包失败与宿主辅助符号泄漏：指向 const 元素指针形参切片发射未定义 `struct uya_slice_constuint8_t`、多个模块导出同名函数时模块限定调用被发射成另一模块实现、函数查找不区分模块导致用户模块同名函数劫持依赖模块内部调用；后两项同源，均属"扁平 `program_decls` 按名查找不带模块限定"；2026-06-06 新增“数组索引边界证明器不跨 `as usize` cast 传递范围事实”编译器 bug，P2/中，含最小复现 `tests/repros/bounds_prover_as_usize_cast.uya`；2026-05-28 曾新增“`std.thread.async_compute<usize>` 并行 worker 返回结构体结果时运行时崩溃”编译器/运行时交界 bug，及“泛型 wrapper 转发 `std.thread.async_compute<T>` 时 C99 backend 漏发射单态化符号”

本文档用于跟踪 release 验证中发现的问题，便于逐项修复、验证和关闭。

## 分类规则

- **编译器 bug**：语法分析、类型检查、代码生成、优化、lowering 等问题。
- **标准库 bug**：`lib/std/**` 里的实现问题。
- **运行时 bug**：异步调度、事件循环、waker/future 状态机等问题。
- **网络 / TLS 回归**：TCP、HTTP、HTTPS、DNS、TLS 链路问题。

## 标准库 bug

- [x] **P2 / 中：HTTP/1 响应头块上限 `65536` 是硬边界，调用方无法在不改库的情况下放宽**
  - 状态：已修复（2026-10-04）
  - 现象：`lib/std/http/http1_async.uya` 的 `HTTP1_ASYNC_RESPONSE_HEADER_MAX_CAP = 65536` 直接写死在
    两处增长逻辑里，响应头超过它时读取消以 `error.HeaderTooLarge` 结束。
    与 `LinuxEpoll` / `AsyncFramePool` / `Scheduler` 的「默认值 + 环境变量可覆盖」口径不一致：
    同一份库，别的容量都能按部署调，只有这一项不能。
  - 修复内容：新增 `http1_async_response_header_max_cap()`（默认 `65536`，
    环境变量 `UYA_HTTP1_RESPONSE_HEADER_MAX_CAP` 给正整数时以它为准，非法值回退默认）；
    两处增长点（`http1_response_header_buffer_grow` 与 `http1_async_request_stream` 内的内联增长）
    改为调用该函数。请求头一侧本来就是「按 `required` 动态分配、4096 只是起步容量」，本次一并核对口径。
  - 验证状态：`tests/test_http1_async_client.uya` 新增
    `http1_async_response_header_max_cap_defaults_and_env_override`（默认值 / 覆盖 / 0 / 负数 / 非数字回退），
    与既有 `http1_async_response_header_buffer_grows_past_legacy_cap`、
    `http1_async_request_header_buffer_grows_past_inline_cap` 一并通过。
  - 归属：`lib/std/http/http1_async.uya`。

- [x] **P1 / 高：split-C 下 `libc.stdlib` 与 `libc.time` 的 `CLOCKS_PER_SEC` 双双 emit 成外部定义（链接期 multiple definition）**
  - 状态：已修复（2026-10-03）
  - 现象：`UYA_SPLIT_C_DIR=<dir>`（split-C 后端）构建任何同时用到 `libc.stdlib` 与 `libc.time` 的程序，链接期报
    `/usr/bin/ld: lib/libc/time.o:(.rodata+…): multiple definition of 'CLOCKS_PER_SEC'; lib/libc/stdlib.o: first defined here`
  - 复现：`uya-agent` 工程（33+ 个 `.uya`、`UYA_SPLIT_C_DIR` 打开）**必然**链接失败；把 `lib/libc/stdlib.uya` 里那份常量删掉即通过
  - 根因：两个模块都写了 `export const CLOCKS_PER_SEC: i64 = 1000000;`；合并后的 libc 命名空间里是同一个名字，单 TU 构建时
    只 emit 一份（所以 `UYA_SPLIT_C=0`，也就是 `make check` 的跑法，看不到问题），split-C 下每个模块各自出一个 `.o`，
    后端对「同名顶层常量的定义该落在哪个模块」判断不稳定（同一棵树增减若干用户文件就会从「一处定义 + 一处 extern」
    变成「两处定义」）—— 这一层属于编译器的拆分逻辑，本次先在库里消掉重复定义
  - 修复内容：`lib/libc/stdlib.uya` 不再定义 `CLOCKS_PER_SEC`（C 标准里它本来就属于 `<time.h>`，由 `libc.time` 提供）；
    `use libc.CLOCKS_PER_SEC` 不受影响（名字仍在合并命名空间里）
  - 验证状态：`uya-agent` 工程 split-C 构建从「链接失败」变为「编译完成」并跑通 `--selftest`；
    `./bin/uya test tests/test_signal.uya` 6/6 通过
  - 归属：`lib/libc/stdlib.uya`
  - 备注：编译器侧（split 时对同名顶层常量去重）已于 2026-10-04 在 `src/codegen/c99` 里收口
    （根因是查重用的 `global_variables` 注册表上限 512 饱和后静默停登），详见"编译器 bug"首条；
    库里这份重复常量保持删除状态。

- [x] **P0 / 严重：`signal()` 装的处理器一收到信号就 SIGSEGV（x86_64 缺 SA_RESTORER）**
  - 状态：已修复（2026-10-03）
  - 现象：`libc.signal.signal(sig, handler)` 装好处理器后，一收到信号进程就以 SIGSEGV(139) 退出，**处理器体一次都不执行**。外部项目文档里"uya 0.10.1 的信号处理器一调用就 SIGSEGV，所以干脆不装信号处理器"的限制即此（`uya-agent` 的 README 踩坑 20、`src/tty.uya` 的注释）。
  - 根因：`signal()` 用裸 `rt_sigaction` 装处理器，`sa_flags = 0`、`sa_restorer = null`。x86-64 上 glibc/musl 一律置 `SA_RESTORER`(0x04000000) 并把 `sa_restorer` 指向执行 `rt_sigreturn` 的垫片；缺了它，信号交付路径本身就崩。旧代码那句注释"sa_restorer 为 null 时不要置 SA_RESTORER（与 Linux uapi / glibc 行为一致）"是错的。
  - 证据（最小复现 + 三项对照，均在 uya 0.10 上实测）：
    1. `signal()` 装处理器 + `sys_kill(self, SIGUSR1)` → 退出码 139，处理器体未执行；
    2. 同一套裸 `rt_sigaction`，只补 `SA_RESTORER|SA_RESTART` 并复用 glibc 的 `sa_restorer` → 处理器正常执行并返回；
    3. 直接绑定宿主 `sigaction`（它自己填 `SA_RESTORER`）→ 同样正常；回读宿主装好的动作可见 `sa_flags` 带 `SA_RESTORER`、`sa_restorer` 非空。
  - 修复内容：回移 0.11 的同名实现（`224dc6f`，本文件与 `uya-0.11/lib/libc/signal.uya` 逐字节一致）：
    * 新增 `@naked_fn _signal_restorer()`：x86_64 走 `movq $15, %%rax; syscall`（arm64/arm32 各有分支）；
    * `signal()` 置 `SA_RESTORER` + `sa_restorer`，并把内核回填的旧动作（`oact`）作为返回值；删掉从未生效的 `_signal_handlers` 分发表与空壳 `_signal_dispatch`；
    * `SIG_ERR` 由 `0xFFFFFFFF` 改成全 1（64 位下 `(void*)-1`），否则"旧处理器判等"永远不成立；
    * `sigprocmask` 把 `sigset_t` 的**指针**交给内核（旧实现传的是值，必然 `EFAULT`）；
    * `raise` 用 `gettid` 定位调用线程；`atexit`/`on_exit` 改为声明宿主实现（旧实现只把回调存进表里，从不调用）。
  - 验证状态：`uya test tests/test_signal.uya` → 6/6 通过、24 条断言；把 `libc.signal` 换回未修版本重跑同一用例集 → `Segmentation fault`、退出码 139（说明新增用例是有效回归闸门）。
  - 归属：`lib/libc/signal.uya`、`tests/test_signal.uya`
  - 备注：`uya-agent` 项目侧不依赖本修复（它自己 `extern "libc" fn sigaction` 走宿主实现）；本修复是给 0.10 路线上所有项目补上。

- [x] **P0 / 严重：`dns_client_query_all_async` 仍依赖手工状态机绕过 lowering 问题**
  - 状态：已修复
  - 验证状态：`tests/test_std_dns_async_transport.uya`、`tests/test_std_dns.uya` 均通过；`make check` 779/779 通过
  - 归属：`lib/std/net/dns.uya`
  - 迁移内容：`dns_client_query_all_any_async` 从 `DnsQueryAllFuture` 手工状态机迁移为 `@async_fn`；`DnsQueryTransportFuture` 增加 `soft_error` 模式，在 `@async_fn` 中通过 `err_id_out` 侧向传递错误，避免 `@await catch` 多语句 block 的编译器限制
  - 备注：`DnsUdpFuture` / `DnsTcpFuture` 底层 I/O 状态机保留为手工实现，上层组合逻辑已 `@async_fn` 化。

- [x] **P3 / 低：`DNS_PREFER_ANY` 的异步聚合路径仍是顺序查询**
  - 状态：已修复（2026-09-27 复核）
  - 验证状态：`dns_client_query_all_any_async` 现在先同时创建 A / AAAA 两个 transport future（`dns_query_transport_future_new` 两次），再用 `async_join2_usize_results` 并发 join，最后 `dns_query_all_merge_results` 汇总；`async_join2_usize_results` 在 `lib/std/async.uya` 中用同一个 waker 轮询两个 future，属于真正的并发等待，不是"先 A 后 AAAA"的顺序等待。引入提交：`61469fe3`（Refactor DNS async composition layers），它把原 `DnsQueryAllAggregateFuture` 手工状态机改成 `@async_fn` + join 组合层
  - 归属：`lib/std/net/dns.uya`
  - 结论：条目描述的"异步聚合顺序查询"已不成立；同步入口 `dns_client_query_all` 仍按 A→AAAA 顺序执行，这是同步 API 的应有语义，不作为待优化项
  - 相关文件：`lib/std/net/dns.uya`（`dns_client_query_all_async`、`dns_client_query_all_any_async`）、`lib/std/async.uya`（`async_join2_usize_results`）
  - 备注：并发化的延迟收益未单独测 benchmark；若后续要做多变 nameserver 竞争，另开新条目。

## 运行时 bug

- [x] **P0 / 严重：hosted 模式下多线程并发 `malloc/free` 必然踩坏堆（`double free detected in tcache 2` / SIGSEGV）**
  - 状态：已修复（2026-10-04）
  - 现象：hosted（默认 `RUNTIME_MODE=hosted`）下任何「uya 线程 + 堆分配」的组合都不可信：
    `./bin/uya test --c99 tests/test_pthread_heap_cache_identity.uya` 连跑 3 次全挂，
    退出码 139（SIGSEGV）/134（SIGABRT），stderr 为 glibc 的
    `free(): double free detected in tcache 2`、`Fatal glibc error: malloc.c:2600 (sysmalloc): assertion failed`。
    同一用例的 nostdlib 静态产物 20/20 通过 —— 缺陷只在 hosted 路线。
  - 根因（C 层隔离复现，三层证据）：
    1) `gdb` 回溯命中 **glibc** 分配器：`#0 tcache_get_n (malloc.c:3179) ← #2 __GI___libc_malloc ← #3 worker ← #4 _pthread_call_start`；
       `nm` 显示 `U malloc@GLIBC_2.2.5`（hosted 下 heap 让给 glibc），而 `libc_pthread_create` 仍是 uya 自己的 raw clone 实现。
    2) `lib/libc/pthread.uya` 的 `CLONE_FLAGS = 0x00150F00` **不含 `CLONE_SETTLS`**，子线程只用
       `arch_prctl(ARCH_SET_GS)` 设了 GS；实测 `parent_fs == child_fs`（`movq %fs:0` 双端相同）。
       glibc 的 per-thread tcache/arena 挂在 **FS** 上，于是所有 uya 线程共用父线程的 glibc TLS。
    3) 独立 C 复现（不依赖 uya）：同一份 `malloc/free` 负载下，glibc `pthread_create` 3/3 通过，
       而模拟 uya 的 raw `clone`（无 `CLONE_SETTLS`）3/3 堆损坏；连「不用用户 malloc、只走 glibc 内部
       分配（`snprintf`/`fopen`）」也 10/10 崩 —— 证明是 TLS 缺失而非调用方用法。
  - 修复内容：hosted 下**保留 uya 自己的线程安全堆**（per-thread GS 缓存 + 全局自旋锁，
    `lib/libc/heap.uya`），即 `src/codegen/c99` 不再把 `heap.uya` 的实现/全局让给宿主 libc；
    同时把 `libc.stdlib` 的 `calloc` 也保留在 uya 侧，避免「glibc `calloc` + uya `free`」的跨分配器错配
    （uya `free` 对非自有指针静默返回 ⇒ 泄漏）。hosted 下发射的线程缓存钩子桩改为只在
    `.uyacache/libc/heap.c` 确实为空时才补，避免与真实 `heap.uya` 定义冲突。
  - 验证状态：新增回归 `tests/test_pthread_heap_concurrency.uya`（8 线程 × 800 轮 malloc/free + 模式校验）：
    修复前 hosted 3/3 崩（139/134），修复后 hosted 连跑 10 次 0 失败；`tests/test_pthread_heap_cache_identity.uya`
    hosted 5/5 通过；`tests/test_std_thread.uya`、`tests/test_async_compute_types.uya` 保持通过；
    全量 hosted 套件 1112/1112、nostdlib 套件 1111/1112（唯一失败 `test_raw_tls` 是依赖公网 DNS 的用例，单跑通过）。
  - 归属：`src/codegen/c99/function.uya`（`c99_should_skip_hosted_libc_function_body` /
    `c99_should_skip_hosted_libc_global_var`）、`src/codegen/c99/main.uya`（hosted 线程缓存钩子桩）。
  - 备注：这是 uya-agent 当初放弃「TUI 渲染与 agent loop 双线程」的真实底层原因（见其 README 踩坑 47 ——
    当时归因为「分配器不支持两条线程并发 malloc」，实际是 hosted 下 glibc TLS 缺失）。
    仍未做的是 `CLONE_SETTLS` + TCB + static TLS image 的完整 NPTL 化（见 `docs/pthread_nptl_todo.md`）；
    当前修法让 hosted 不再依赖宿主分配器，因而不需要 TCB。

- [x] **P2 / 中：`Waker` 只有单 fd / 单 interest，「同时等两个 fd」会退化成只等最后一个**
  - 状态：已修复（2026-10-04）
  - 现象：`Waker` 只有 `_io_fd` + `_io_interest` 两个标量，`wait_readable(a)` 之后
    `wait_writable(b)`（或第二次 `wait_readable`）会把前一个 fd **覆盖**掉。于是
    「同一轮 poll 里关注两个 fd」（TLS 全双工、socketpair 双向、组合 future）只有最后一次声明生效，
    先就绪的 fd 永远不产生唤醒。上一条 P1（`LinuxEpoll` 注册语义）的备注里
    「后续如需同时关注读写再扩展为小数组或链表」即指本项。
  - 根因：`lib/std/async.uya` 的 `Waker` 用两个标量承载 I/O 关注；
    `lib/std/async_scheduler.uya` 的 `scheduler_sync_waker_registrations` 只读 `waker.io_fd()` 注册一个 fd。
  - 修复内容：
    1) `Waker` 增加有界槽表（`WAKER_IO_SLOT_MAX = 4`，`_io_slot_fds` / `_io_slot_interests` / `_io_slot_count`）：
       同 fd 的 RD+WR **合并**成 READWRITE(3)，不同 fd 各占一槽；`_io_fd` / `_io_interest` 保留为
       「最后一次声明」的主槽镜像，单 fd 调用点读到的值与旧实现逐字节一致。
    2) `async_scheduler` 新增 `SchedulerFdRegs` 记录**每一个**已注册 fd，遍历 waker 全部槽注册，
       并对「上轮注册、本轮不再关注」的 fd 做差集注销（否则 epoll 留陈旧注册，数字 fd 复用时会收到
       别的 future 的唤醒）。原单 fd 入口保留为兼容包装。
  - 验证状态：新增回归 `tests/test_async_waker_multi_interest.uya`（4 个用例）：
    ① 同 fd RD+WR 合并成 READWRITE；② 三个不同 fd 各占一槽且主槽 = 最后一次声明；
    ③ 超出槽位数不越界、不挤掉已登记槽；④ 调度器把同一 waker 的两个 fd **同时**注册进 EventLoop。
    该用例在「临时退回单 fd 注册」时无法通过（挂死到超时），在修复后通过；
    `tests/test_std_async_waker.uya`、`test_async_fd`、`test_async_io`、`test_async_multi_fd_concurrent`、
    `test_std_async_scheduler`、`test_task_std_async`、`test_async_task_queue_dynamic_growth` 全部保持通过；
    `tests/verify_async_shared_runtime_matrix.sh`、`verify_async_production_smoke.sh`、
    `verify_async_full_language_matrix.sh`、`verify_async_nested_future_boundary.sh`、
    `verify_async_cancel_cleanup.sh` 全部通过。
  - 归属：`lib/std/async.uya`、`lib/std/async_scheduler.uya`。
  - 备注：槽位是**有界**的（4 个），超出后新 fd 不再登记（不会覆盖已登记的）；
    按当前主链路（HTTP/1 + eventfd + 组合 future 的两个子 future）足够。
    若后续需要无界关注，应把槽表改成可增长结构，同时保持 `Waker` 的 Copy 语义评估。

- [x] **P1 / 高：`LinuxEpoll` 的注册/反注册语义仍偏脆弱**
  - 状态：已修复
  - 验证状态：`tests/test_std_dns_async_transport.uya`、`tests/test_http1_async_client.uya` 已通过；`tests/test_async_fd.uya`、`tests/test_std_dns.uya`、`tests/test_std_async_event_fd_reuse.uya` 也已通过
  - 归属：`lib/std/async_event.uya`
  - 现象：`block_on_with_event_loop` / `LinuxEpoll` 在 fd 复用、slot 清理和 epoll interest 重建时出现过 `ENOENT`、`EEXIST` 一类边界错误。
  - 修复内容：引入显式状态机（`SLOT_STATE_EMPTY` / `SLOT_STATE_REGISTERED`）与 `slot_generations` 代际数组，彻底消除 fd 复用混淆；新增 `find_slot` / `alloc_slot` / `init_slot` / `clear_slot` 方法。
  - 可能位置：`lib/std/async_event.uya`
  - 备注：当前已补了幂等清理和失败回退。~~量产阶段建议保持单 fd interest 语义，后续如需同时关注读写再扩展为小数组或链表~~
    —— **该建议已于 2026-10-04 落地**：`Waker` 扩为有界槽表并由调度器全槽注册（见上一条 P2），
    本条不再把「单 fd interest」当作量产前提。

## 运行时 / 调度限制

- [x] **P2 / 中：HTTP/1.1 客户端没有连接池，也不复用连接（每次请求都 `Connection: close`）**
  - 状态：已修复（2026-10-04）
  - 现象：`lib/std/http/http1_async.uya` 的请求头构建里写死 `\r\nConnection: close\r\n`，
    且 API 是「一次请求一条连接」：连续 N 个请求 = N 次 TCP（HTTPS 还要 N 次 TLS 握手）。
  - 修复内容：
    1) `Http1AsyncPool`：进程内单例、有界（`HTTP1_ASYNC_POOL_MAX = 8` 个空闲槽），
       按 host 字节 + port 精确匹配取用；池满或 host 超长时关闭 fd 而不是截断误配。
    2) `Http1AsyncRequest.persist`（默认 0 = 旧行为）控制是否走 keep-alive；
       URL 版入口 `http1_async_get/post` 透传该字段。
    3) `Connection` 行按 persist 精确计入容量（keep-alive 26 字节 / close 21 字节）。
    4) 响应头解析新增 `Connection: close` 识别；`http1_async_finish_connection` 只在
       「要求 persist + 响应非 read_until_eof + 未声明 close」时回池 —— 宁可少复用，
       也不要把坏连接放回池。
    5) 观测/测试入口：`http1_async_pool_stats` / `http1_async_pool_close_all` /
       `http1_async_pool_put_raw` / `http1_async_pool_take_raw`。
  - 验证状态：`tests/test_http1_async_client.uya` 新增
    `http1_async_keepalive_reuses_one_connection`（客户端连发 3 个 persist 请求，
    服务端只 `accept` 一次并在同一条连接上读满 3 个 —— 临时关掉池复用该用例在 iter=1 报
    `HttpTimeout`，证实判据有效）、`http1_async_non_persist_request_leaves_pool_empty`、
    `http1_async_pool_take_put_and_close`；该文件 15/15 通过，
    `test_http_server` / `test_http_uyagin` / `test_https_loopback` / `test_std_dns_async_transport` 无回归。
  - 归属：`lib/std/http/http1_async.uya`。

- [x] **P2 / 中：TLS 无会话复用（没有 session ID 缓存）**
  - 状态：已修复（2026-10-04，**会话 ID 路径**；session ticket 仍未做）
  - 现象：`lib/tls/` 全仓库无会话复用实现；每次新建 HTTPS 连接都走完整握手
    （ClientHello → 服务器 flight → ClientKeyExchange/Finished → ServerFinished）。
  - 修复内容：
    1) `TlsSessionCache`（`lib/tls/ssl/handshake.uya`）：按 host 缓存会话 ID + master_secret +
       密码套件，进程内单例、有界（`TLS_SESSION_CACHE_MAX = 8`），同 host 覆盖。
    2) `HandshakeCtx` 增加复用字段；`handshake_set_resume_session_id()` 让客户端在
       ClientHello 里携带会话 ID（小写、长度字段与记录长度同步增长）。
    3) 服务器侧 `hs_server_decide_session_resumption()`：客户端带了 ID **且**本地缓存有
       同 host 同 ID 的白名单条目时才回显接受（不因为客户端给了 ID 就接受），
       回显时把缓存的 master_secret 装回上下文。
    4) 客户端解析服务器回显的会话 ID：与请求一致才算「已复用」
       （`handshake_session_resumed()`）；不一致/为空视为拒绝，连接退回完整握手而不失败。
    5) `https_client_handshake` 在握手成功后把本次会话写入缓存，并在下次连接时按 host 查询。
  - 验证状态：新增 `tests/test_tls_session_resumption.uya`（7 个用例，覆盖缓存的存/查/覆盖/
    入参校验/有界、ClientHello 线上格式、服务器接受与拒绝两种往返）；
    临时禁掉服务器回显时 `test_roundtrip_server_accepts` 报 `ServerDidNotAccept`（判据有效）；
    `test_https_loopback` / `test_tls_async_io_future` / `test_tls_async_runtime_boundary` /
    `test_https_real_site` 均无回归。
  - 归属：`lib/tls/ssl/handshake.uya`、`lib/tls/https.uya`。
  - 备注：本项实现期间撞到一个**编译器 bug**（切片字面量传给 `&const byte` 形参时发射错指针），
    见本文件「编译器 bug」首条；测试里按仓库既有做法改用局部数组传参绕开。

- [x] **P3 / 低：跨平台 `EventLoop` 后端缺失（macOS `kqueue`；Windows `IOCP` 仍缺）**
  - 状态：**macOS kqueue 已实现（2026-10-04）**；Windows `IOCP` 仍未做
  - 现象（修复前）：`lib/std/async_event.uya` 只有 `LinuxEpoll`；macOS 分支退化成 `poll(2)`
    全表扫描（功能性正确，但 O(n) 且有 1024 级别的 `poll(2)` 上限），全仓库无 `kqueue`/`kevent`。
  - 修复内容：
    1) `lib/libc/syscall.uya`：macOS 分支新增 `uya_macos_kqueue()` / `uya_macos_kevent(...)`
       宿主声明，并导出 `sys_kqueue()` / `sys_kevent()`（非 macOS 目标返回 `error.NotSupported`）。
    2) `src/codegen/c99/main.uya`：按仓库既有垫片模式发射 `uya_host_kqueue` / `uya_host_kevent`
       宿主符号声明（`__asm__("_kqueue")` / `__asm__("kevent")`）与 `uya_macos_*` 包装体。
    3) `lib/std/async_event.uya`：新增 `Kevent`（BSD `struct kevent`，x86_64/arm64 均 32 字节）
       与 `TimeSpec`；`LinuxEpoll` 增加 `kqfd` 字段；macOS 上 `kqueue()` 成功即走 kqueue
       （`register` 发 `EV_ADD|EV_ENABLE` + `EVFILT_READ/WRITE`，`deregister` 发 `EV_DELETE`，
       `poll` 用 `kevent` 取就绪列表后按 slot 唤醒 waker）；`kqueue()` 失败则**回退**到原
       `poll(2)` 实现；`linux_epoll_close` 一并关闭 `kqfd`。采用水平触发（不加 `EV_CLEAR`）
       以对齐 epoll 默认语义。Linux 路径逐字节未变（仍是 `epoll_*`）。
  - 验证状态：
    - **Linux 无回归**：`test_std_async_event` / `test_std_async_scheduler` / `test_async_fd` /
      `test_async_waker_multi_interest` 全部 `通过: 1 失败: 0`。
    - **kqueue 翻译规则有 Linux 回归**：新增 `tests/test_async_event_kqueue_transition.uya`
      （7 个用例：首次注册 RD/WR/RDWR、RD→WR 切换、RD→RDWR 升级、RDWR→RDWR 幂等、
      EVFILT_*/EV_*, POLLIN/POLLOUT 常量 ABI 交叉校验）。因为这条翻译规则是纯函数、
      与平台无关，所以在 Linux 上也能覆盖。
    - **ABI 交叉验证**：`Kevent`/`TimeSpec` 的 C 侧同构定义在 zig 交叉编译下通过
      32/16 字节静态断言，并成功产出 `Mach-O 64-bit x86_64` 与 `Mach-O 64-bit arm64` object；
      生成的 `uya_macos_kqueue`/`uya_macos_kevent` 包装体在生成的 C 中确认存在。
  - **未验证的部分（重要）**：macOS 上的**运行时行为**（`kqueue()`/`kevent()` 真实调用、
    事件投递、唤醒时序）本机无 macOS SDK/runtime，**未真机验收**。同时发现：本机
    zig 交叉编译**任何**含 `libc` 的 uya 程序到 macOS 都会因 `struct timeval` 与 Darwin SDK
    的 `_STRUCT_TIMEVAL` 重定义而失败（用最小 `libc.sys_write` 程序即可复现，与本项无关），
    所以「生成 C → 交叉编译成 Mach-O」这条路径当前对含 libc 的程序走不通。
  - 归属：`lib/std/async_event.uya`、`lib/libc/syscall.uya`、`src/codegen/c99/main.uya`。
  - 备注：Windows `IOCP` 仍未做（Windows 目标当前仅 hosted bring-up）。

- [ ] **P2 / 中：`benchmarks/http_bench_async_epoll_await_simple.uya` 单 worker 顺序处理模型无法支撑高并发 keep-alive 连接**
  - 状态：已知限制，非编译器 bug
  - 验证状态：`-c 28` 正常；`-c 100` 时 `ab` 最后少量请求 timeout（`apr_pollset_poll: The timeout specified has expired`）
  - 归属：benchmark 设计 / 异步调度模型
  - 现象：
    1. 每个 worker 线程运行独立的 `block_on_with_event_loop` + `serve_forever`
    2. `serve_forever` 内顺序执行 `accept` → `await handle_bench_client(cfd)` → 回到 `accept`
    3. `handle_bench_client` 含 `while true` 处理 keep-alive，导致一个 worker 拿到连接后会持续独占该连接，不再 accept 新连接
    4. 当并发连接数（`-c 100`）远大于 worker 数（7）时，大量已建立的 keep-alive 连接上的请求无人处理，ab 等待超时
  - 影响：仅影响高并发 keep-alive 压测场景；功能正确，但并发上限受限于 worker 线程数
  - 修复方向：将 `serve_forever` 改为 `accept` 后把 client handler **spawn** 为独立 Future 并注册到同一 event loop 中并发调度，而非顺序 await。
  - 相关文件：`benchmarks/http_bench_async_epoll_await_simple.uya`

## 网络 / TLS 回归

- [x] **P0 / 严重：`make release-dirty` 还需要重新跑一轮做最终验收**
  - 状态：已修复，测试通过
  - 验证状态：2026-04-11 已修复 `test_https_real_site` 与 `test_raw_tls` 的编译问题；两个测试现均已通过
  - 归属：整体验收
  - 现象：
    1. `test_raw_tls.uya` 存在语法错误（catch 块内使用表达式语法不正确）
    2. GitHub CI 环境下无法连接外部网络，导致网络测试失败
  - 修复内容：
    - `test_raw_tls.uya`：修正 catch 块语法，使用 `0 as isize;` 替代错误的表达式语法；添加 allow_skip_network 检查
    - `test_https_real_site.uya`：修复 O_RDONLY 导入（添加 fcntl），网络失败时返回 0 而非 1
    - `test_https_debug.uya`：添加 allow_skip_network 检查，网络失败时返回 0 而非 1
  - 影响：release 流程不再被这些测试阻塞，CI 环境下网络测试会优雅跳过

## 编译器 bug

- [ ] **P1 / 高：除数是「函数形参的加减表达式」时编译器自己 SIGFPE（浮点数例外）**
  - 状态：**已定位并给出最小复现**（2026-10-07，做 `std.image.jpeg_*` 时踩到）
  - 现象：`uya build` / `uya check` 在**编译期**以 `SIGFPE`（shell 报「浮点数例外」、
    退出码 136）中止，不打印任何错误信息 —— 看起来像编译器崩了，而不是源码有错，
    所以第一反应会去翻被测代码。
  - 最小复现（`/tmp` 里试出来的，两条对照）：
    ```uya
    // 崩：除数是「两个形参相加减」
    fn f(w: i32, h: i32) i32 {
        var x: i32 = 3;
        var y: i32 = 4;
        const bv: i32 = ((x + y) * 255) / (w + h - 2);
        return bv;
    }
    export fn main() i32 { const v: i32 = f(8, 8); return v - v; }
    ```
    把除数换成 `(w - 1)`、或换成 `(w + h)`（**没有那个 `- 2`**）都能编过；
    换成 `a * 10 / b`（单个形参做除数）也能编过 —— 触发点集中在
    「形参参与、且含减法的表达式」当除数。
  - 规避：**把除数先落到一个临时量**再除，即可编过（同形状、同语义）：
    ```uya
    const d: i32 = w + h - 2;
    const bv: i32 = ((x + y) * 255) / d;
    ```
    实测「除数与被除数都落临时量」也正常。
  - 推测方向（未坐实）：常量折叠 / 区间证明里对除法做了「除以区间含 0 则先算个值」
    的处理，形参的区间是 `INT32_MIN..INT32_MAX`（含 0），减 2 之后仍然含 0，
    某处直接执行了整数除零；而 `w + h` 或 `w - 1` 的区间推导路径不同，没走到那一步。
    编译器是 nostdlib 构建（不装 SIGFPE handler），所以直接死。
  - 为什么值得单列：**报错形式完全误导**（无消息 + 非 0 退出码，退出码还被 shell
    解释成「浮点数例外」），且触发条件（形参表达式做除数）在数值代码里非常常见 ——
    `std.image.jpeg_encode` 的测试第一版就写成了 `/(w + h - 2)`，整份测试编不过。
  - 归属：`src/`（checker 的区间证明或 codegen 的常量折叠，未定位到具体文件）。

- [ ] **P1 / 高：同一份源码用 0.10.3 编出来的程序，整组 TUI 自测轮红；0.10.1 编则全绿**
  - 状态：**已定位到「编译器/标准库侧的行为差异」，但**根因未坐实**（2026-10-06）
  - 现象：`uya-agent` 这个工程，**源码一字不改**，换编译器就换结论：
      * `0.10.1`（`/home/winger/uya-0.10`，配它的 `lib/`）编译 → 全部自测轮通过，0 条 FAIL；
      * `0.10.3 + 本仓两处容量修复`（`/home/winger/uya/uya`）编译 → `tui-approve` /
        `tui-plan` / `tui-ask` / `tui-quit` / `tui-p30` 等轮红 23~38 条；
        报的是「首屏没有输入面板占位文案」「没有进备用屏幕」「mock LLM 侧报错（mock_rc=62，
        即请求数不够）」—— 即**子进程根本没跑起来**。
  - 已排除的假设（都实测过）：
      * **不是 `uya-agent` 那一轮拆分引入的**：拆前（62 个构建文件）FAIL 27、拆后（89 个）FAIL 21，
        同一量级；两边的生成 C 在语义上逐 TU 比对（去掉 `#ifdef` 守卫与空行后 diff）**完全一致**。
      * **不是「容量常量抬多高」的问题**：把 `C99_MAX_REACHABLE_FUNCTIONS` 等一批常量静态抬到
        65536、或改成按实际条数动态分配，红法一模一样。
      * **不是本仓输入文件表的改动**：只用 reachable 表那一处修复（不动输入文件表）也能编过本仓，
        TUI 轮同样红。
  - 未坐实的部分：曾怀疑 `entry.uya` 的 `uya_pipeline_worker_dispatch()` 弱桥接抢先接管
    `main`（codegen 在 `container_mode == 0` 时总是发射它，`process.uya` 里
    `uya_pipeline_worker_main_if_requested` 也无条件导出）。**但该判据是
    `argc == 2 && argv[1] == "--uya-pipeline-worker"`，自测子进程的 argv 不可能满足**，
    所以这条不能解释现象 —— 留作**线索**而非结论。下一步应该做的是：把 0.10.3 与 0.10.1
    生成的两份 `uya_common.c` 的 `main` 路径逐指令对一遍，看 `main_main()` 之前
    多了/少了什么（目前已知的两份差异里有 `uya_interface_*`、`uya_pipeline_image_anchor`
    等宿主辅助符号的有无，以及一张 `AsyncFrameDescriptor` 表的偏移量差异）。
  - 为什么值得单列：它让「`uya-agent` 的 split-C 自测」在 0.10.3 上**不可用**，
    而本仓（`uya-agent`）已经把默认编译器指向 0.10.3，所以这条不修，那边的
    `make selftest` 就一直红。

## 运行时 bug

- [x] **P0 / 严重：hosted 模式下多线程并发 `malloc/free` 必然踩坏堆（`double free detected in tcache 2` / SIGSEGV）**
  - 状态：已修复（2026-10-04）
  - 现象：hosted（默认 `RUNTIME_MODE=hosted`）下任何「uya 线程 + 堆分配」的组合都不可信：
    `./bin/uya test --c99 tests/test_pthread_heap_cache_identity.uya` 连跑 3 次全挂，
    退出码 139（SIGSEGV）/134（SIGABRT），stderr 为 glibc 的
    `free(): double free detected in tcache 2`、`Fatal glibc error: malloc.c:2600 (sysmalloc): assertion failed`。
    同一用例的 nostdlib 静态产物 20/20 通过 —— 缺陷只在 hosted 路线。
  - 根因（C 层隔离复现，三层证据）：
    1) `gdb` 回溯命中 **glibc** 分配器：`#0 tcache_get_n (malloc.c:3179) ← #2 __GI___libc_malloc ← #3 worker ← #4 _pthread_call_start`；
       `nm` 显示 `U malloc@GLIBC_2.2.5`（hosted 下 heap 让给 glibc），而 `libc_pthread_create` 仍是 uya 自己的 raw clone 实现。
    2) `lib/libc/pthread.uya` 的 `CLONE_FLAGS = 0x00150F00` **不含 `CLONE_SETTLS`**，子线程只用
       `arch_prctl(ARCH_SET_GS)` 设了 GS；实测 `parent_fs == child_fs`（`movq %fs:0` 双端相同）。
       glibc 的 per-thread tcache/arena 挂在 **FS** 上，于是所有 uya 线程共用父线程的 glibc TLS。
    3) 独立 C 复现（不依赖 uya）：同一份 `malloc/free` 负载下，glibc `pthread_create` 3/3 通过，
       而模拟 uya 的 raw `clone`（无 `CLONE_SETTLS`）3/3 堆损坏；连「不用用户 malloc、只走 glibc 内部
       分配（`snprintf`/`fopen`）」也 10/10 崩 —— 证明是 TLS 缺失而非调用方用法。
  - 修复内容：hosted 下**保留 uya 自己的线程安全堆**（per-thread GS 缓存 + 全局自旋锁，
    `lib/libc/heap.uya`），即 `src/codegen/c99` 不再把 `heap.uya` 的实现/全局让给宿主 libc；
    同时把 `libc.stdlib` 的 `calloc` 也保留在 uya 侧，避免「glibc `calloc` + uya `free`」的跨分配器错配
    （uya `free` 对非自有指针静默返回 ⇒ 泄漏）。hosted 下发射的线程缓存钩子桩改为只在
    `.uyacache/libc/heap.c` 确实为空时才补，避免与真实 `heap.uya` 定义冲突。
  - 验证状态：新增回归 `tests/test_pthread_heap_concurrency.uya`（8 线程 × 800 轮 malloc/free + 模式校验）：
    修复前 hosted 3/3 崩（139/134），修复后 hosted 连跑 10 次 0 失败；`tests/test_pthread_heap_cache_identity.uya`
    hosted 5/5 通过；`tests/test_std_thread.uya`、`tests/test_async_compute_types.uya` 保持通过；
    全量 hosted 套件 1112/1112、nostdlib 套件 1111/1112（唯一失败 `test_raw_tls` 是依赖公网 DNS 的用例，单跑通过）。
  - 归属：`src/codegen/c99/function.uya`（`c99_should_skip_hosted_libc_function_body` /
    `c99_should_skip_hosted_libc_global_var`）、`src/codegen/c99/main.uya`（hosted 线程缓存钩子桩）。
  - 备注：这是 uya-agent 当初放弃「TUI 渲染与 agent loop 双线程」的真实底层原因（见其 README 踩坑 47 ——
    当时归因为「分配器不支持两条线程并发 malloc」，实际是 hosted 下 glibc TLS 缺失）。
    仍未做的是 `CLONE_SETTLS` + TCB + static TLS image 的完整 NPTL 化（见 `docs/pthread_nptl_todo.md`）；
    当前修法让 hosted 不再依赖宿主分配器，因而不需要 TCB。

- [x] **P2 / 中：`Waker` 只有单 fd / 单 interest，「同时等两个 fd」会退化成只等最后一个**
  - 状态：已修复（2026-10-04）
  - 现象：`Waker` 只有 `_io_fd` + `_io_interest` 两个标量，`wait_readable(a)` 之后
    `wait_writable(b)`（或第二次 `wait_readable`）会把前一个 fd **覆盖**掉。于是
    「同一轮 poll 里关注两个 fd」（TLS 全双工、socketpair 双向、组合 future）只有最后一次声明生效，
    先就绪的 fd 永远不产生唤醒。上一条 P1（`LinuxEpoll` 注册语义）的备注里
    「后续如需同时关注读写再扩展为小数组或链表」即指本项。
  - 根因：`lib/std/async.uya` 的 `Waker` 用两个标量承载 I/O 关注；
    `lib/std/async_scheduler.uya` 的 `scheduler_sync_waker_registrations` 只读 `waker.io_fd()` 注册一个 fd。
  - 修复内容：
    1) `Waker` 增加有界槽表（`WAKER_IO_SLOT_MAX = 4`，`_io_slot_fds` / `_io_slot_interests` / `_io_slot_count`）：
       同 fd 的 RD+WR **合并**成 READWRITE(3)，不同 fd 各占一槽；`_io_fd` / `_io_interest` 保留为
       「最后一次声明」的主槽镜像，单 fd 调用点读到的值与旧实现逐字节一致。
    2) `async_scheduler` 新增 `SchedulerFdRegs` 记录**每一个**已注册 fd，遍历 waker 全部槽注册，
       并对「上轮注册、本轮不再关注」的 fd 做差集注销（否则 epoll 留陈旧注册，数字 fd 复用时会收到
       别的 future 的唤醒）。原单 fd 入口保留为兼容包装。
  - 验证状态：新增回归 `tests/test_async_waker_multi_interest.uya`（4 个用例）：
    ① 同 fd RD+WR 合并成 READWRITE；② 三个不同 fd 各占一槽且主槽 = 最后一次声明；
    ③ 超出槽位数不越界、不挤掉已登记槽；④ 调度器把同一 waker 的两个 fd **同时**注册进 EventLoop。
    该用例在「临时退回单 fd 注册」时无法通过（挂死到超时），在修复后通过；
    `tests/test_std_async_waker.uya`、`test_async_fd`、`test_async_io`、`test_async_multi_fd_concurrent`、
    `test_std_async_scheduler`、`test_task_std_async`、`test_async_task_queue_dynamic_growth` 全部保持通过；
    `tests/verify_async_shared_runtime_matrix.sh`、`verify_async_production_smoke.sh`、
    `verify_async_full_language_matrix.sh`、`verify_async_nested_future_boundary.sh`、
    `verify_async_cancel_cleanup.sh` 全部通过。
  - 归属：`lib/std/async.uya`、`lib/std/async_scheduler.uya`。
  - 备注：槽位是**有界**的（4 个），超出后新 fd 不再登记（不会覆盖已登记的）；
    按当前主链路（HTTP/1 + eventfd + 组合 future 的两个子 future）足够。
    若后续需要无界关注，应把槽表改成可增长结构，同时保持 `Waker` 的 Copy 语义评估。

- [x] **P1 / 高：`LinuxEpoll` 的注册/反注册语义仍偏脆弱**
  - 状态：已修复
  - 验证状态：`tests/test_std_dns_async_transport.uya`、`tests/test_http1_async_client.uya` 已通过；`tests/test_async_fd.uya`、`tests/test_std_dns.uya`、`tests/test_std_async_event_fd_reuse.uya` 也已通过
  - 归属：`lib/std/async_event.uya`
  - 现象：`block_on_with_event_loop` / `LinuxEpoll` 在 fd 复用、slot 清理和 epoll interest 重建时出现过 `ENOENT`、`EEXIST` 一类边界错误。
  - 修复内容：引入显式状态机（`SLOT_STATE_EMPTY` / `SLOT_STATE_REGISTERED`）与 `slot_generations` 代际数组，彻底消除 fd 复用混淆；新增 `find_slot` / `alloc_slot` / `init_slot` / `clear_slot` 方法。
  - 可能位置：`lib/std/async_event.uya`
  - 备注：当前已补了幂等清理和失败回退。~~量产阶段建议保持单 fd interest 语义，后续如需同时关注读写再扩展为小数组或链表~~
    —— **该建议已于 2026-10-04 落地**：`Waker` 扩为有界槽表并由调度器全槽注册（见上一条 P2），
    本条不再把「单 fd interest」当作量产前提。

## 运行时 / 调度限制

- [x] **P2 / 中：HTTP/1.1 客户端没有连接池，也不复用连接（每次请求都 `Connection: close`）**
  - 状态：已修复（2026-10-04）
  - 现象：`lib/std/http/http1_async.uya` 的请求头构建里写死 `\r\nConnection: close\r\n`，
    且 API 是「一次请求一条连接」：连续 N 个请求 = N 次 TCP（HTTPS 还要 N 次 TLS 握手）。
  - 修复内容：
    1) `Http1AsyncPool`：进程内单例、有界（`HTTP1_ASYNC_POOL_MAX = 8` 个空闲槽），
       按 host 字节 + port 精确匹配取用；池满或 host 超长时关闭 fd 而不是截断误配。
    2) `Http1AsyncRequest.persist`（默认 0 = 旧行为）控制是否走 keep-alive；
       URL 版入口 `http1_async_get/post` 透传该字段。
    3) `Connection` 行按 persist 精确计入容量（keep-alive 26 字节 / close 21 字节）。
    4) 响应头解析新增 `Connection: close` 识别；`http1_async_finish_connection` 只在
       「要求 persist + 响应非 read_until_eof + 未声明 close」时回池 —— 宁可少复用，
       也不要把坏连接放回池。
    5) 观测/测试入口：`http1_async_pool_stats` / `http1_async_pool_close_all` /
       `http1_async_pool_put_raw` / `http1_async_pool_take_raw`。
  - 验证状态：`tests/test_http1_async_client.uya` 新增
    `http1_async_keepalive_reuses_one_connection`（客户端连发 3 个 persist 请求，
    服务端只 `accept` 一次并在同一条连接上读满 3 个 —— 临时关掉池复用该用例在 iter=1 报
    `HttpTimeout`，证实判据有效）、`http1_async_non_persist_request_leaves_pool_empty`、
    `http1_async_pool_take_put_and_close`；该文件 15/15 通过，
    `test_http_server` / `test_http_uyagin` / `test_https_loopback` / `test_std_dns_async_transport` 无回归。
  - 归属：`lib/std/http/http1_async.uya`。

- [x] **P2 / 中：TLS 无会话复用（没有 session ID 缓存）**
  - 状态：已修复（2026-10-04，**会话 ID 路径**；session ticket 仍未做）
  - 现象：`lib/tls/` 全仓库无会话复用实现；每次新建 HTTPS 连接都走完整握手
    （ClientHello → 服务器 flight → ClientKeyExchange/Finished → ServerFinished）。
  - 修复内容：
    1) `TlsSessionCache`（`lib/tls/ssl/handshake.uya`）：按 host 缓存会话 ID + master_secret +
       密码套件，进程内单例、有界（`TLS_SESSION_CACHE_MAX = 8`），同 host 覆盖。
    2) `HandshakeCtx` 增加复用字段；`handshake_set_resume_session_id()` 让客户端在
       ClientHello 里携带会话 ID（小写、长度字段与记录长度同步增长）。
    3) 服务器侧 `hs_server_decide_session_resumption()`：客户端带了 ID **且**本地缓存有
       同 host 同 ID 的白名单条目时才回显接受（不因为客户端给了 ID 就接受），
       回显时把缓存的 master_secret 装回上下文。
    4) 客户端解析服务器回显的会话 ID：与请求一致才算「已复用」
       （`handshake_session_resumed()`）；不一致/为空视为拒绝，连接退回完整握手而不失败。
    5) `https_client_handshake` 在握手成功后把本次会话写入缓存，并在下次连接时按 host 查询。
  - 验证状态：新增 `tests/test_tls_session_resumption.uya`（7 个用例，覆盖缓存的存/查/覆盖/
    入参校验/有界、ClientHello 线上格式、服务器接受与拒绝两种往返）；
    临时禁掉服务器回显时 `test_roundtrip_server_accepts` 报 `ServerDidNotAccept`（判据有效）；
    `test_https_loopback` / `test_tls_async_io_future` / `test_tls_async_runtime_boundary` /
    `test_https_real_site` 均无回归。
  - 归属：`lib/tls/ssl/handshake.uya`、`lib/tls/https.uya`。
  - 备注：本项实现期间撞到一个**编译器 bug**（切片字面量传给 `&const byte` 形参时发射错指针），
    见本文件「编译器 bug」首条；测试里按仓库既有做法改用局部数组传参绕开。

- [x] **P3 / 低：跨平台 `EventLoop` 后端缺失（macOS `kqueue`；Windows `IOCP` 仍缺）**
  - 状态：**macOS kqueue 已实现（2026-10-04）**；Windows `IOCP` 仍未做
  - 现象（修复前）：`lib/std/async_event.uya` 只有 `LinuxEpoll`；macOS 分支退化成 `poll(2)`
    全表扫描（功能性正确，但 O(n) 且有 1024 级别的 `poll(2)` 上限），全仓库无 `kqueue`/`kevent`。
  - 修复内容：
    1) `lib/libc/syscall.uya`：macOS 分支新增 `uya_macos_kqueue()` / `uya_macos_kevent(...)`
       宿主声明，并导出 `sys_kqueue()` / `sys_kevent()`（非 macOS 目标返回 `error.NotSupported`）。
    2) `src/codegen/c99/main.uya`：按仓库既有垫片模式发射 `uya_host_kqueue` / `uya_host_kevent`
       宿主符号声明（`__asm__("_kqueue")` / `__asm__("kevent")`）与 `uya_macos_*` 包装体。
    3) `lib/std/async_event.uya`：新增 `Kevent`（BSD `struct kevent`，x86_64/arm64 均 32 字节）
       与 `TimeSpec`；`LinuxEpoll` 增加 `kqfd` 字段；macOS 上 `kqueue()` 成功即走 kqueue
       （`register` 发 `EV_ADD|EV_ENABLE` + `EVFILT_READ/WRITE`，`deregister` 发 `EV_DELETE`，
       `poll` 用 `kevent` 取就绪列表后按 slot 唤醒 waker）；`kqueue()` 失败则**回退**到原
       `poll(2)` 实现；`linux_epoll_close` 一并关闭 `kqfd`。采用水平触发（不加 `EV_CLEAR`）
       以对齐 epoll 默认语义。Linux 路径逐字节未变（仍是 `epoll_*`）。
  - 验证状态：
    - **Linux 无回归**：`test_std_async_event` / `test_std_async_scheduler` / `test_async_fd` /
      `test_async_waker_multi_interest` 全部 `通过: 1 失败: 0`。
    - **kqueue 翻译规则有 Linux 回归**：新增 `tests/test_async_event_kqueue_transition.uya`
      （7 个用例：首次注册 RD/WR/RDWR、RD→WR 切换、RD→RDWR 升级、RDWR→RDWR 幂等、
      EVFILT_*/EV_*, POLLIN/POLLOUT 常量 ABI 交叉校验）。因为这条翻译规则是纯函数、
      与平台无关，所以在 Linux 上也能覆盖。
    - **ABI 交叉验证**：`Kevent`/`TimeSpec` 的 C 侧同构定义在 zig 交叉编译下通过
      32/16 字节静态断言，并成功产出 `Mach-O 64-bit x86_64` 与 `Mach-O 64-bit arm64` object；
      生成的 `uya_macos_kqueue`/`uya_macos_kevent` 包装体在生成的 C 中确认存在。
  - **未验证的部分（重要）**：macOS 上的**运行时行为**（`kqueue()`/`kevent()` 真实调用、
    事件投递、唤醒时序）本机无 macOS SDK/runtime，**未真机验收**。同时发现：本机
    zig 交叉编译**任何**含 `libc` 的 uya 程序到 macOS 都会因 `struct timeval` 与 Darwin SDK
    的 `_STRUCT_TIMEVAL` 重定义而失败（用最小 `libc.sys_write` 程序即可复现，与本项无关），
    所以「生成 C → 交叉编译成 Mach-O」这条路径当前对含 libc 的程序走不通。
  - 归属：`lib/std/async_event.uya`、`lib/libc/syscall.uya`、`src/codegen/c99/main.uya`。
  - 备注：Windows `IOCP` 仍未做（Windows 目标当前仅 hosted bring-up）。

- [ ] **P2 / 中：`benchmarks/http_bench_async_epoll_await_simple.uya` 单 worker 顺序处理模型无法支撑高并发 keep-alive 连接**
  - 状态：已知限制，非编译器 bug
  - 验证状态：`-c 28` 正常；`-c 100` 时 `ab` 最后少量请求 timeout（`apr_pollset_poll: The timeout specified has expired`）
  - 归属：benchmark 设计 / 异步调度模型
  - 现象：
    1. 每个 worker 线程运行独立的 `block_on_with_event_loop` + `serve_forever`
    2. `serve_forever` 内顺序执行 `accept` → `await handle_bench_client(cfd)` → 回到 `accept`
    3. `handle_bench_client` 含 `while true` 处理 keep-alive，导致一个 worker 拿到连接后会持续独占该连接，不再 accept 新连接
    4. 当并发连接数（`-c 100`）远大于 worker 数（7）时，大量已建立的 keep-alive 连接上的请求无人处理，ab 等待超时
  - 影响：仅影响高并发 keep-alive 压测场景；功能正确，但并发上限受限于 worker 线程数
  - 修复方向：将 `serve_forever` 改为 `accept` 后把 client handler **spawn** 为独立 Future 并注册到同一 event loop 中并发调度，而非顺序 await。
  - 相关文件：`benchmarks/http_bench_async_epoll_await_simple.uya`

## 网络 / TLS 回归

- [x] **P0 / 严重：`make release-dirty` 还需要重新跑一轮做最终验收**
  - 状态：已修复，测试通过
  - 验证状态：2026-04-11 已修复 `test_https_real_site` 与 `test_raw_tls` 的编译问题；两个测试现均已通过
  - 归属：整体验收
  - 现象：
    1. `test_raw_tls.uya` 存在语法错误（catch 块内使用表达式语法不正确）
    2. GitHub CI 环境下无法连接外部网络，导致网络测试失败
  - 修复内容：
    - `test_raw_tls.uya`：修正 catch 块语法，使用 `0 as isize;` 替代错误的表达式语法；添加 allow_skip_network 检查
    - `test_https_real_site.uya`：修复 O_RDONLY 导入（添加 fcntl），网络失败时返回 0 而非 1
    - `test_https_debug.uya`：添加 allow_skip_network 检查，网络失败时返回 0 而非 1
  - 影响：release 流程不再被这些测试阻塞，CI 环境下网络测试会优雅跳过

## 编译器 bug

- [ ] **P1 / 高：普通用户程序的 `main` 也被弱 worker 入口抢先接管 —— 凡带 argv 的用户进程都可能被误判成 pipeline worker**
  - 状态：**未修复**（2026-10-06 定位；`uya-agent` 的整组 TUI 自测轮因此红）
  - 现象：`lib/std/runtime/entry/entry.uya` 的 `main` 在调用 `main_main()` **之前**先调
    `uya_pipeline_worker_dispatch()`；而 codegen 在 `container_mode == 0` 时**总是**发射那个
    弱桥接（`src/codegen/c99/main.uya` 的 `uya_thread_call_*` 一族旁边）：它取
    `uya_pipeline_worker_main_if_requested` 的地址并直接调用。该函数在
    `lib/std/process.uya` 里**无条件**导出，判据是 `get_argc() == 2 &&
    pipeline_worker_arg_matches(get_argv(1))`。
  - 后果：**任何**用新版标准库编译出来的用户程序，只要 `argc == 2` 且 `argv[1]` 恰好是
    `--uya-pipeline-worker`，就会被当作 worker 走进 pipeline 分支；反过来，
    `0.10.1` 的 `entry.uya` **没有**这段桥接，所以同一个程序在 0.10.1 下行为正常。
    `uya-agent` 的 `tui-approve` / `tui-plan` / `tui-ask` / `tui-quit` 等轮都在真 PTY 里
    fork 子进程并在父进程里断言首帧，实测**同一份未改动源码**：
      0.10.1 编 → 0 条 FAIL；新编译器编 → 23~38 条 FAIL，
    且与「怎么改容量」（静态常量抬高 / 改成动态表）无关 —— 只要编译器能把本仓编过就会红。
  - 为什么与本仓拆分无关：拆分前后各编一次，FAIL 数是 21（拆后）与 27（拆前），都在同一量级；
    把 `input_file_indices` 与 reachable 表两处**都**修好（本仓 build 能过）之后，拆前拆后
    仍同样红。也就是它是**编译器/标准库侧**的行为改变，不是搬文件引入的。
  - 建议修法（二选一）：
    1. codegen 只在「确实要走 pipeline worker 入口」时才发射弱桥接（例如按 `--exec` /
       `container_mode` / 显式开关决定），普通用户程序不发射；或
    2. `entry.uya` 的这段调用改成「先看环境变量/显式标记」，别只看 argc/argv 形状。

- [ ] **P1 / 高：切片字面量传给 `&const byte` 形参时，生成 C 传的是「切片描述符临时量的地址」而不是字节指针**
  - 状态：**未修复**（2026-10-04 发现并记录；本轮通过在测试里改用局部数组绕开）
  - 现象：被调函数按 `&const byte` / `*const byte` 声明形参时，调用方写
    `f(&"abc"[0: 3])`（或任何 `&[byte]` 切片表达式的取址）→ 进了函数读到的**不是** `"abc"`，
    而是栈上切片描述符的位模式（实测打印出 `38514DD3…` 这类指针/长度字节）。
    形参写成 `&[byte]`（切片）则正常。
  - 复现（最小，已实测）：
    ```uya
    const N: usize = 64;
    export struct S { len: usize, buf: [byte: N] }
    fn setter(s: &S, name: &const byte, n: usize) void {
        s.len = n;
        var i: usize = 0;
        while i < n { s.buf[i] = name[i]; i = i + 1; }
    }
    // 调用：setter(&a, &"r.example.com"[0: 13], 13);
    //   → a.buf 里拿到的不是 "r.example.com"
    // 同一函数若形参改写成 `name: &[byte]`（并用 name.ptr），则字节正确。
    ```
  - 生成的 C（`UYA_SPLIT_C_DIR=… uya build --c99`，观察调用点）：
    ```c
    // 形参：const uint8_t * name
    // 调用点实际发射：
    setter((&a), (&(struct uya_slice_uint8_t){ .ptr = (uint8_t *)((uint8_t *)str0) + 0, .len = 13}), 13);
    //            ^^ 取了整个切片描述符临时量的地址；应传它的 .ptr
    ```
    即「切片值 → 指针形参」这条隐式转换漏了取 `.ptr`，直接把描述符地址当指针传。
  - 影响：所有「形参是 `&const byte` + 实参写切片字面量」的调用点都静默拿到错数据
    （不报错、不崩溃，只是内容不对）。本轮在 `lib/tls/ssl/handshake.uya` 的
    `handshake_set_hostname` 上撞到：SNI hostname 字段因此写坏，会话复用按 host 匹配
    必然失败（表现为「客户端带了会话 ID，服务器也解析到了，但按 host 查缓存永远 miss」）。
  - 现有绕法（仓库既有测试同款）：把字面量先拷进**局部数组**，再传 `&arr[0]`。
    例如 `tests/test_https_loopback.uya` 的 `var host: [byte: 9] = [...]; ssl_set_hostname(ctx, &host[0], 9);`。
  - 待定修复方向：`src/codegen/c99` 里「切片表达式作为指针形参实参」的转换分支，
    应发射 `(uint8_t *)(<切片>.ptr)` 而不是 `&(struct uya_slice_*){...}`；
    需要先补齐回归（形参 `&const byte` + 实参各种切片形式：
    字面量切片、数组切片、字段切片、函数返回切片）。
  - 归属：`src/codegen/c99/expr.uya`（切片/取址发射）或 `src/checker`（隐式转换注入点）。

- [x] **P1 / 高：split-C 下同名顶层常量会重复发射定义（`multiple definition`），根因是去重用的全局注册表在 512 槽饱和后静默停登**
  - 状态：已修复（2026-10-04）
  - 现象：`UYA_SPLIT_C_DIR=<dir>`（split-C 后端）下，合并命名空间里两个源文件各写一份同名 `export const`
    （真实例子：`lib/libc` 的 `CLOCKS_PER_SEC` 同时存在于 `stdlib.uya` 与 `time.uya`）时，两个镜像 TU
    各自发射一份定义，链接期直接：
    ```
    /usr/bin/ld: lib/libc/time.o:(.rodata+0x560): multiple definition of `CLOCKS_PER_SEC';
                  lib/libc/stdlib.o:(.rodata+0x570): first defined here
    ```
  - 复现：`uya-agent` 工程（47 个 `.uya`、`UYA_SPLIT_C_DIR` 打开）**必然**链接失败；
    `lib/libc/stdlib.uya` 里删掉那份重复常量即通过。**同一个 bug 只用纯用户码也能复现**：
    两个源文件各写一份 `export const DUP_SHARED_CONST: i64 = 1000000;`，主程序再铺 600 个
    `export const` 撑满注册表，链接期同样报 `multiple definition`（见 `tests/verify_split_dup_global.sh`）。
  - 根因：`gen_extern_var_decl` 用 `codegen.global_variables` 注册表判断「这个 C 名是否已经
    发射过定义」，而该表上限是 `C99_MAX_GLOBAL_VARS`（512）；登记语句只写
    `if (idx >= 0 && idx < C99_MAX_GLOBAL_VARS)`，**表满后静默丢弃**，查重随即失效。
    小程序（顶层全局数 < 512）撑不满 ⇒ 去重生效、看不出问题；`uya-agent` 有 1700+ 顶层全局，
    表早就满了 ⇒ libc 的那份重复常量一路漏到链接期。这也解释了 2026-10-03 那条备注里
    「同一棵树增减若干用户文件就会从一处定义翻成两处定义」的抖动。
    注：`global_variables` 本身是**缓存**（满了按名查找会退回 `program_decls` 线性扫描），
    它继续保留「满则降级」的语义；出问题的是把它当**查重依据**用。
  - 修复内容（`src/codegen/c99/global.uya`、`src/codegen/c99/utils.uya`）：
    * 新增一张独立的「已发射定义的全局 C 名」集合（开放寻址 + 线性探测，
      `C99_EMITTED_GLOBAL_CAP = 8192`），走
      `c99_global_c_name_emitted` / `c99_global_c_name_mark_emitted`；
    * **表满时不再静默降级，而是当场报错退出**（`c99_report_global_table_overflow`），
      错误信息带 `文件:(行:列)`、表名与容量、以及本次要登记的全局名，并指明去调哪个常量：
      `main.uya:(8:14): 错误: 顶层全局变量过多，已发射全局 C 名集合（容量 4）已满，无法登记；
      本次要登记的是 `PAD_C4`。`（缩容实验实测输出）。
      这条判据之所以必须 fail loud：漏登记会静默产出「会链接失败或结果错误」的 C，
      比直接编译失败更难排查；
    * `c99_emitted_global_names_reset()` 挂进 `c99_codegen_new` 的初始化序列；
    * `gen_extern_var_decl` 的**定义**路径改走新判据（`export const/var … = value` 一律经此函数），
      先查再登记，保证同一个 C 名全树只有一份定义。
    * 刻意**不动** `gen_global_var`（模块内私有非常量全局）：两个 `var g` 落在不同模块时，
      合并命名空间会给同一个裸 C 名，现在会**大声**报 `multiple definition`；
      若在那里也去重就会变成「静默只留第一份」的错误结果，属于把 loud failure 换成 silent wrong。
      私有全局重名应由模块前缀机制解决，不由这里兜。
  - 验证状态：
    * 新增回归 `tests/verify_split_dup_global.sh`（固定装置 `tests/fixtures/split_dup_global/`），
      已挂进 `make check` 与 `make check-hosted`「验证 split-C 重名顶层常量」；
      **门是有效的**：把修复 stash 掉重跑同一脚本 → `multiple definition of 'DUP_SHARED_CONST'`、退出码 1；
      带修复 → `verify_split_dup_global: ok`。
    * `uya-agent` 工程 split-C 构建：把那份重复常量加回 `lib/libc/stdlib.uya` 后
      **从「链接失败」变为「编译完成」（3.2 MB ELF，`--print-config` 正常）**。
    * `make uya` 自举对比**字节一致**（`cmp`）；`make check` **1111/1111** 全绿。
  - 归属：`src/codegen/c99/global.uya`、`src/codegen/c99/utils.uya`
  - 备注：本次把「同名顶层常量」这一层在**后端**收口了，库里那份重复常量仍保持删除状态
    （`CLOCKS_PER_SEC` 按 C 标准只由 `libc.time` 提供）。同类饱和问题若再出现，
    应优先怀疑「用 `global_variables` / 其它定容表当查重依据」的写法。

- [x] **P1 / 高：hosted 下用户顶层全局与系统头宏同名即编译失败（`ETIMEDOUT` 等）**
  - 状态：已修复（2026-09-27）
  - 现象：hosted（默认 `uya test` / `uya build`）会为非 bootstrap 编译单元 `#include <errno.h>`
    （`src/codegen/c99/main.uya` 的 `is_bootstrap == 0` 分支），宏是文本替换，于是两处发射都被打断：
    1. 定义路径：`__attribute__((used)) const int32_t ETIMEDOUT = 110;`（`src/codegen/c99/global.uya` 的 `gen_global_var`）
    2. 镜像分 TU 路径：`uya_mirror_globals.h` 里的 `extern const int32_t ETIMEDOUT;`
    两者都报 `error: expected identifier or '(' before numeric constant`。
  - 最小复现：`const ETIMEDOUT: i32 = 110;` + `export fn main() i32 { return ETIMEDOUT; }`
    → 修复前 `uya_mirror_globals.h:5:22: error: expected identifier or '(' before numeric constant`（单文件路径同样失败）
  - 影响面：`./bin/uya test tests/test_pthread_cond.uya` 修复前必挂（该用例顶层声明 `const ETIMEDOUT: i32 = 110;`），
    而 `tests/run_programs_parallel.sh` 把该用例归入 nostdlib 名单后仍然通过——即"`make check` 全绿，但 hosted 直跑同一用例红"；
    连带 `tests/stress_pthread.sh` 第 1 轮必挂，`tests/verify_async_full_dynamic_resources_gate.sh all|c99-stress` 在 `pthread stress` 阶段失败。
  - 根因：`1f617994`（2026-06-25）为 hosted 生成补 `#include <errno.h>`，但没有配套的同名宏撤销机制；
    `lib/libc/errno.uya` 自身的常量带 `libc_` 前缀不受影响，只有**用户顶层全局是裸名**，因此必然撞上宏名。
  - 修复内容：`src/codegen/c99/global.uya` 新增
    `c99_global_name_may_collide_with_c_macro()`（判据为"宏形态"：纯标识符且含大写字母，外加 `errno`/`stdin`/`stdout`/`stderr`；
    跳过编译器自身发射的 `uya_`/`UYA_` 宏前缀）与 `c99_emit_global_macro_undef_guard()`（发射 `#ifdef X / #undef X / #endif`），
    并接入三个发射点：`gen_global_var`、`gen_extern_var_decl`、`c99_mirror_emit_extern_global_line`。
  - 验证状态：新增回归 `tests/test_hosted_macro_name_collision.uya`（顶层 `ETIMEDOUT`/`EAGAIN` 常量、`EINVAL` 可变全局、export 常量），
    `./bin/uya test` 3/3 通过、`./tests/run_programs_parallel.sh` 通过；`./bin/uya test tests/test_pthread_cond.uya` 4/4 通过；
    `tests/stress_pthread.sh 1` 通过；最小复现程序在默认 split 与 `--no-split-c` 两种模式下都能构建并返回 110
  - 相关文件：`src/codegen/c99/global.uya`、`src/codegen/c99/main.uya`、`tests/test_hosted_macro_name_collision.uya`

- [x] **P0 / 严重：跟踪的自举种子里没有 `uya_pipeline_worker_dispatch`，`make release` 冷启动链接失败**
  - 状态：已修复
  - 验证状态：`make release` 冷启动段（`clean` → `from-c` → `uya`）通过；`make b` 自举对比一致；`make check` 全绿（主测试 1107/1107）
  - 归属：`backup/` 下跟踪的自举种子种子陈旧，非编译器逻辑缺陷
  - 现象：`make release` 在 `from-c` 之后的 `make uya` 阶段链接失败：
    `/usr/bin/ld: uya_common.o: in function 'main': undefined reference to 'uya_pipeline_worker_dispatch'`。
    注意 `make check` / `make release-dirty` 都不做 `clean`，因此走不到这条冷启动路径，长期未被发现。
  - 根因：`lib/std/runtime/entry/entry.uya` 的 `main` 会调用由编译器发射的运行时 shim
    `uya_pipeline_worker_dispatch()`（`src/codegen/c99/main.uya`）。该特性随 `eba705c2`
    （2026-07-11，「feat(process): run Uya stages in exec workers」）引入，而仓库跟踪的种子
    `backup/uya-linux-x86_64.c` / `backup/uya.c` 最后一次刷新是 `588248d3`（2026-07-07），
    早于该提交——种子里根本没有这个符号，用它编译当前 `src/` 必然留下未定义引用。
  - 修复内容：按仓库既有流程刷新自举种子（`make backup-seed` + `make backup-hosted-seed`），
    使 `backup/uya.c`、`backup/uya-linux-x86_64.c`、`backup/uya-hosted.c`、
    `backup/uya-hosted-linux-x86_64.c` 与当前 `src/` 一致。
    由于旧种子无法独立编译出可用编译器（缺的正是它自己不会发射的符号），
    刷新时先用一个仅用于冷启动的 `uya_pipeline_worker_dispatch` 恒为 -1 的临时 C 桩把首个
    `bin/uya` 链接出来，再由该编译器正常重编译自身并生成正式种子；该桩未进入仓库。
  - 预防：把 `backup/*.c` 与当前 `src/` 的一致性纳入 release 收口（种子陈旧属于"工作树干净但种子过期"，
    preflight 的 `bin/uya.c` 对比检查覆盖不到，因为 `bin/` 被忽略）。

- [x] **P2 / 中：macOS 交叉目标下 `uya_macos_*` 宿主包装被 `#ifdef __APPLE__` 裁掉，调用点报 `invalid initializer`**
  - 状态：已修复
  - 验证状态：`bash tests/verify_std_path_platform_targets.sh` 通过（`✓ std.path Linux/macOS/Windows 平台条件验证通过`）；`make check` 整体转绿（主测试 1107/1107，25 个验证项全过）
  - 归属：`src/codegen/c99/main.uya` 中 macOS 宿主绑定的发射
  - 现象：`TARGET_OS=macos`（宿主 Linux）生成 `std_path_platform_macos_x86_64.c` 后由宿主 cc 编译，报
    `implicit declaration of function 'uya_macos_write'` 与 `error: invalid initializer`（`sys_write` / `sys_read` 等调用点）。
  - 根因（共 4 层，逐层修复）：
    1. **块被裁**：`uya_macos_write` 等宿主包装定义全部位于 `#ifdef __APPLE__` … `#endif` 内（生成文件第 262–717 行）。该 `#ifdef` 由 `c99_codegen_generate` 发射，本意只是让 `stat`/`time_t`/`timespec`/`S_IF*` 宏重命名避开 macOS SDK 同名屏蔽，但包装定义被一并纳入；宿主非 macOS 时整块被预处理器裁掉，调用点仍在 → 隐式声明 → `invalid initializer`。
    2. **stat 时间戳成员名**：`struct stat` 的时间戳字段，macOS 是 `st_atime`/`st_atimensec`，glibc 是 `st_atim`（POSIX timespec）。
    3. **timeval 成员名**：`st_atim` 的类型是在本文件宏重命名期间由 `<sys/stat.h>` 引入的，其成员名同样被 `#define tv_sec ...` 改成了 `uya_macos_native_tv_sec_hidden`。
    4. **宿主符号名与 errno 入口**：`__asm__("_write")` 的 macOS 前导下划线、以及 `__error()` 在 glibc 上应为 `__errno_location()`。
  - 修复内容：
    1. 发射块条件由 `#ifdef __APPLE__` 改为 `#if defined(__APPLE__) || defined(UYA_TARGET_MACOS)`，并在 `target_os_is_macos != 0` 时定义 `UYA_TARGET_MACOS`：使「目标 macOS 而宿主非 macOS」的交叉场景也能让该块生效（宿主 macOS 路径行为不变）。
    2. `uya_macos_copy_stat` 的 6 个时间戳字段按 `#ifdef __APPLE__` 分支：macOS 用 `st_atime`/`st_atimensec`，其他宿主用重命名后的 `st_atim.uya_macos_native_tv_sec_hidden`。
    3. `__error()` / `__errno_location()` 按宿主分支。
    4. 新增 `c99_emit_host_symbol_decl(codegen, macos_decl, posix_decl)`：按 `HOST_OS` 在生成期选择要发射的声明文本，用于 27 处 `__asm__("_xxx")` 宿主符号声明。**注意**：不能用 `#define UYA_HOST_ASM(n)` 之类的宏——`tests/verify_macos_hosted_seed_decls.sh` 用 `grep -Fqx` 校验完整声明行（含 `__asm__("_getsockname")`），宏化会让该行不再出现。同理，最初把 27 处写成 27 个独立 `if/else` 块会使 `c99_codegen_generate` 体积增大并触发 `数组索引安全证明失败`，故收敛为一个辅助函数调用。
  - 影响面：原先仅影响「宿主非 macOS 且目标为 macOS + 由宿主 cc 编译」的交叉场景；现已覆盖。

- [x] **P1 / 高：hosted 路线下 `bin/uya-hosted` 一运行即 abort（`glibc detected an invalid stdio handle`）**
  - 状态：已修复
  - 验证状态：`make uya-hosted` 构建成功；`./bin/uya-hosted build tests/test_slice_expr_from_const_byte_param.uya -o /tmp/...` 正常完成并生成可运行程序（此前该命令立即 `SIGABRT`）；`make check` 全绿（主测试 1107/1107，25 个验证项全过），其中绝大多数用例走 hosted 生成路径
  - 归属：`lib/libc/stdio.uya` 的 FILE 模型与 hosted 链接方式的冲突
  - 根因：`lib/libc/stdio.uya` 自定义了 `struct FILE { fd, buffer, buf_pos, buf_len, buf_mode }` 与 `_stdin/_stdout/_stderr`，而 stdio 函数带函数体、C 符号名不加前缀。**hosted 构建下同名符号由宿主 glibc 提供**，于是 uya 自造的 `FILE` 被交给 glibc 的 `fprintf`，`_IO_vtable_check` 校验 `vtable == 0` 失败 → `__libc_fatal` → abort。另有配套的一处错配：头文件里 `extern struct FILE *stderr;` 绑定的是 glibc 的 `stderr`，而 `fprintf` 调用点却发射成 uya 的 `libc_fprintf`，同样把 glibc FILE 交给了 uya 实现。
  - 已推进的崩溃点（早前改动，方向正确且经 `verify_split_c_cache_lock.sh` / `verify_split_c_cache_stale_lock.sh` / `verify_compile_sh_split_cache_cleanup.sh` 验证）：
    1. `src/main.uya` 的 `split_c_write_lock_owner_pid` 原为 `fopen` 后 `fprintf(file as *void, "%d\n", getpid())`——把 std.io 的 FILE 交给宿主 fprintf。已改为 `snprintf` 到缓冲区 + std.io 自己的 `fwrite`。
    2. `src/main.uya` 的 `split_c_read_lock_owner_pid` 原用宿主 `fgets`。已改为 std.io 的 `fread` + 手工截断换行。
  - 最终修复内容（采用建议方向 1，并把不彻底处补齐）：
    1. `c99_should_skip_hosted_libc_function_body`：hosted 下 `lib/libc/stdio.uya` 整体保留 uya 实现，只把纯字符串缓冲区格式化/解析（`snprintf`/`sprintf`/`vsnprintf`/`vsprintf`/`sscanf`/`fscanf`，名单收敛在 `c99_hosted_stdio_name_uses_host_libc`）继续交给宿主 libc。
    2. `should_use_raw_libc_symbol_name` / `get_c_name_for_function_decl`：调用点与声明点一律解析到 uya 实现的模块前缀名（`libc_fprintf` 等），不再按实参归属在「uya 实现 / 宿主裸符号」之间切换；`c99_hosted_uya_stdio_impl_c_name` 负责「实现已并入本编译单元」时才接管，未并入时仍走裸名 + `<stdio.h>`。
    3. `get_c_name_for_identifier_ref`：`stdin/stdout/stderr` 不再映射到宿主同名对象，改为解析到 uya 的 `libc_stdin/libc_stdout/libc_stderr`，与变量定义处一致。
    4. 以文本直接发射 `printf` 的几处（`gen_test_runner`、测试汇总 `main_main`、字符串插值 `expr.uya`/`stmt.uya`）统一走 `c99_printf_c_name`，避免「定义叫 libc_printf、调用叫 printf」的错配。
  - 影响面：`make check-hosted` / `make b-hosted`（hosted 路线）与 hosted 生成路径下的全部用例；`make check`（nostdlib 路线）行为不变。

- [x] **P1 / 高：微应用 payload 打包失败且镜像混入宿主辅助符号**
  - 状态：已修复
  - 验证状态：`make microapp-check` 全部通过（此前 `verify_microapp_loader_generic.sh` 直接失败）；`./bin/uya run --app microapp examples/microapp/microcontainer_hello_source.uya` 输出 `microapp run x86_64 ok`
  - 归属：`src/codegen/c99/main.uya` 的 `c99_codegen_generate`
  - 现象：
    1. `--app microapp` 构建 payload 时报 `无法从 microapp 对象文件提取段与 relocation 信息`，`.pobj` 无法生成。
    2. 修好打包后，payload 目标文件出现白名单外符号 `uya_interface_get_vtable` / `uya_interface_set_vtable` / `uya_interface_set_data` / `uya_pipeline_image_anchor`。
  - 根因：`eba705c2`（typed pipeline exec worker）在 `c99_codegen_generate` 中无条件发射了 `uya_pipeline_worker_dispatch`（引用未定义弱符号 `uya_pipeline_worker_main_if_requested`）、`uya_interface_*` 读写辅助与 `uya_pipeline_image_anchor`。其中：
    1. `-fpie` 下对弱符号取地址生成 `R_X86_64_GOTPCREL` 重定位，而微应用镜像不含 GOT，`microapp_extract_object_elf64` 遇到该重定位类型即失败。
    2. 宿主侧辅助符号被一并带入微应用载荷。
  - 修复内容：
    1. `gen_expr` 在微应用（`container_mode != 0`）下把 `uya_pipeline_worker_dispatch()` 调用点内联为 `-1`：调用点不再引用该符号，函数随之不被发射，微应用载荷因此不含任何宿主辅助符号。**未修改 `tests/verify_microapp_payload_symbols.sh` 的符号白名单**。
    2. 微应用下不发射 `uya_pipeline_worker_dispatch` 定义（连同 `split_protos_out` 中的前向声明）与 `uya_interface_*`、`uya_pipeline_image_anchor`，它们不参与微应用调用路径。
    3. `microapp_extract_object_elf64` 对无法定位的符号（未定义/WEAK UND）改为以 0 作为符号值继续处理，而不是让整次打包失败。
  - 相关验证：`tests/verify_microapp_loader_generic.sh`、`tests/verify_microapp_payload_symbols.sh`（脚本原样未改，`make microapp-check` 全绿）
  - 备注：非微应用路径保持原样——`uya_pipeline_worker_dispatch` 仍按 `__attribute__((weak))` 弱符号分派，`lib/std/runtime/entry/entry.uya` 的 C 入口逻辑不变。

- [x] **P1 / 高：多个模块导出同名函数时，模块限定调用被发射成另一个模块的实现**
  - 状态：已修复
  - 验证状态：`bash tests/verify_module_alias_import_table_codegen.sh` 输出 `verify_module_alias_import_table_codegen: ok`；`make check` 该项由失败转绿
  - 归属：`src/codegen/c99/expr.uya` 的 `gen_expr` 模块限定调用分支
  - 现象：`use fixture.noop; use fixture.target;` 且两模块都 `export fn value` 时，`fixture_target_value()` 的调用被发射成 `fixture_noop_value()`，即运行时取到另一个模块的实现。加任意一条额外的 `use` 即可触发，与导入数量无关。
  - 根因：该分支用 `find_function_decl_c99(codegen, callee.member_access_field_name)` 仅按函数名（`value`）在扁平声明表中查找，返回第一个同名声明；模块信息（`member_access_module_name`）没有参与限定。
  - 修复内容：先按「模块名 + 导出名」用 `c99_find_module_export_function_decl` 精确定位声明，取不到时才回退到按名查找。该函数在同类逻辑（`types.uya` 的调用返回类型推断）中已被使用，故此修复与既有行为一致。
  - 最小复现：两个模块各 `export fn value() i32`（返回不同常量），`main` 中调用其中之一的模块限定名
  - 相关验证：`tests/verify_module_alias_import_table_codegen.sh`

- [x] **P0 / 严重：指向 const 元素的指针形参切片时发射未定义 `struct uya_slice_constuint8_t`**
  - 状态：已修复
  - 验证状态：`./bin/uya test tests/test_slice_expr_from_const_byte_param.uya` 通过；`make tests` 1106 项中原先失败的网络/TLS/WebSocket/MQTT 等 35 项全部转绿
  - 归属：`src/codegen/c99/types.uya` 的 `c99_slice_element_name_token`（切片结构体名归一化）
  - 现象：形参为 `&const byte`（C 侧 `const uint8_t *`）时，对其切片 `pem[a: b]` 生成 `(struct uya_slice_constuint8_t){ .ptr = …, .len = … }`。该结构体从不曾被发射，C 编译报 `'struct uya_slice_constuint8_t' has no member named 'ptr'`，直接导致链接失败。
  - 根因：切片元素类型词元保留了前导 `const` 限定（`const uint8_t` → `constuint8_t`），于是结构体名多出 `const`，与 `uint8_t` 分支的 `uya_slice_uint8_t` 归一化规则不一致。
  - 修复内容：`c99_slice_element_name_token` 在剥离 `struct`/`enum` 前缀之前，先通过新增的 `c99_slice_element_const_is_strippable` 判断前导 `const ` 是否可安全剥离。判据为「带前导 `const ` 且剥离后剩余部分不含 `*`」：
    - `const uint8_t` / `const int32_t` / `const struct Foo` 等**非指针**元素 → 剥离，与不带 const 的元素归一化为同一 `uya_slice_*`；
    - `const uint8_t *` 等**指针**元素 → 保留，否则会与 `uint8_t *` 混用，破坏「指针元素 slice 保留指针层级」的既有约定（`tests/test_slice_pointer_element_codegen.uya` 即为此约定的守卫）。
  - 注意：判据必须排除指针。最初只对 const 字节做归一化，随后发现 `examples/example_147.uya` 的 `&[const i32]` 仍会发射未定义的 `struct uya_slice_constint32_t`（`examples-check` 构建失败），故泛化为「非指针 const 一律归一化」。
  - 最小复现/回归：`tests/test_slice_expr_from_const_byte_param.uya`（const byte 形参切片）、`examples/example_147.uya`（`&[const i32]`）
  - 备注：真实命中点为 `lib/tls/x509/trust_store.uya` 的 `parse_one_pem_cert`（`decode_base64_mime(pem_data[b64_start: b64_len], …)`）。

- [x] **P2 / 中：函数查找不区分模块，用户模块同名函数劫持依赖模块内部调用**
  - 状态：已修复
  - 验证状态：`./bin/uya test tests/test_module_scope_isolation_stdlib_check.uya` 通过；`make check` 全绿（主测试 1107/1107，25 个验证项全过），其中包含 `tests/test_typed_pipeline_parser_positive.uya`（定义本地 `fn check`）
  - 归属：`src/checker/lookup.uya` 的函数声明查找与 `src/checker/symbols.uya` 的函数表
  - 现象：主文件定义一个与依赖模块内部函数同名的函数后，依赖模块内部的同名调用会被解析到主文件的那个函数。例如主文件写 `fn check(input: Pipeline) i32` 后，`lib/std/process.uya` 的 `pipeline_terminal_inherit_child_run` 中 `try check(try inherit_stdio(command))` 被解析为返回 `i32` 的版本，于是类型检查失败且错误位置落在标准库内部。
  - 根因：编译器把主文件与全部依赖模块合并为扁平的 `program_decls`（`src/ast.uya`），函数查找按名字扫描该扁平数组并返回第一个同名 `AST_FN_DECL`，不比较声明所属模块；函数表（`FunctionSignature`）同样只按名索引，同名函数先注册者胜出并遮蔽后者。
  - 修复内容：
    1. `FunctionSignature` 新增 `filename`（`src/checker/types.uya`），`checker_register_fn_decl` 注册时写入（`src/checker/check_stmt.uya`）。
    2. `function_table_lookup` 优先返回与当前函数同模块（相同 `filename`）的签名，无同模块匹配时回退到第一个同名签名；重复定义检测改用新增的 `function_table_lookup_same_file`，只拦截同模块内的重复定义，使不同模块的同名函数得以共存（`src/checker/symbols.uya`）。
    3. `src/checker/lookup.uya` 新增 `scan_fn_decl_in_file`：按调用点所在模块文件限定查找，并加了嵌套深度上限（`CHECKER_SCAN_DECL_MAX_DEPTH`）避免查找与返回类型推断相互递归耗尽 C 栈。
  - 影响面：任何用户模块自定义与标准库内部函数同名的函数（`check`、`inherit_stdio` 等）都可能让标准库代码被误解析。
  - 已观察实例：`tests/test_typed_pipeline_parser_positive.uya`（定义了 `fn check(p: Pipeline) i32`）
  - 回归：`tests/test_module_scope_isolation_stdlib_check.uya`

- [x] **P2 / 中：`bench_malloc_phase4` 系列在满并发测试下偶发 SIGSEGV（单独运行稳定通过）**
  - 状态：已修复
  - 验证状态：
    - 修复前 44 路并发复现：`PARALLEL_JOBS=44` 风格压测（44 个 bench 进程同时跑，40 轮 = 1760 次）失败 **1294 次，全部为退出码 139**；钉单 CPU 的最小用例 `tests/test_pthread_join_stack_reuse.uya` 修复前 10/10 SIGSEGV。
    - 修复后同样压测 1760 次 **0 失败**（另用 `-O3 -DNDEBUG` + strip 的 release 风格编译器复跑 12 轮 × 44 并发 = 528 次同样 0 失败；两者生成的 C 逐字节相同）；最小用例 10/10 通过、单次约 64ms。
    - `make check` 全绿（主测试 1110/1110，含本轮新增 3 个用例 + UPM 套件）；`make b` 自举对比字节一致；`make from-c` 冷启动（种子未刷新）仍可用，冷启动 + 重新自举后的 `bin/uya` 与之前逐字节相同。
  - 归属：`lib/libc/pthread.uya` 的 join/退出握手（`_pthread_thread_exit` / `pthread_join` / `_pthread_release_resources_once`），不是 `tests/bench_malloc_phase4*.uya` 基准自身的问题
  - 现象：满并发批量跑套件时偶发段错误；单独运行、直接运行产物均正常
  - 根因（use-after-unmap）：
    1. 子线程执行完 worker 后在 `_pthread_thread_exit` 里把 `joinstate` CAS 成 `EXITED`，再 `FUTEX_WAKE` 唤醒 join 侧，然后才走 `sys_exit(0)`；此时它仍在**内核 syscall 返回路径**上。
    2. join 侧被唤醒后立即返回 `pthread_join` → `_pthread_release_resources_once` 直接 `free(stack)`（8MiB，走 mmap/munmap）+ `munmap(desc)`。
    3. 紧接着的 mmap（下一轮线程的栈/其它 8MiB 分配）复用同一地址段，匿名映射按页零填充；子线程恢复执行时从栈里 `pop %rbp` / `ret` 取到 0 → 跳转到地址 0 → SIGSEGV。
    - gdb 现场与该序列完全吻合：`rip=0x0`、`siginfo.si_addr=0x0`、`rbp=0x0`（栈槽已被清零）、`rsp` 仍在线程栈范围内、`rax=1`（`FUTEX_WAKE` 唤醒 1 个等待者）、`rdi=&desc->joinstate`、`rcx` 指向 `sys_futex` 里 `syscall` 的下一条指令；main 线程此时已在 `pthread_create` 里创建下一组线程（即已复用被释放的地址段）。
    4. 只在满并发时出现的原因：机器空闲时被唤醒的 main 会被调度到空闲核并行执行，子线程几纳秒内就跑完 `sys_exit`；CPU 全部被占满时 main 只能在子线程所在 CPU 上做 wakeup preemption 抢占，子线程被挂在队列里，等它恢复执行时栈早已被释放并复用。
  - 修复内容（`lib/libc/pthread.uya`）：
    1. `pthread_desc` 新增 `tid_clear`；子线程在 `_pthread_child_bootstrap` 里通过 `sys_set_tid_address(&desc.tid_clear)` 注册 clear_child_tid 并写入非 0 哨兵；非 Linux 目标注册失败时保持 0（不做额外等待）。
    2. 新增 `_pthread_wait_thread_cleared`：用 `FUTEX_WAIT`（共享 futex，与内核 clear_child_tid 的唤醒方式一致）等待该字段被内核清零。内核在 `do_exit → mm_release` 阶段清零并唤醒，此后线程只会在内核里走完退出流程，不会再碰用户栈。
    3. `_pthread_release_resources_once` 在释放栈/描述符之前先做上述等待（join/detach 共用的唯一释放点）。
  - 影响面：所有使用 `libc.pthread` 的程序（hosted 与 `--nostdlib` 都走同一份 uya 实现）；修复前偶发崩溃概率随机器负载升高，最小用例在单 CPU 上即可 100% 复现
  - 回归：`tests/test_pthread_join_stack_reuse.uya`（已加入 nostdlib 用例列表；修复前 10/10 崩溃，修复后 10/10 通过）
  - 复现尝试：`UYA_COMPILER=$PWD/bin/uya PARALLEL_JOBS=44 RUNTIME_MODE=nostdlib LINK_MODE=static ./tests/run_programs_parallel.sh --uya --c99 --hide-pass`

- [x] **P2 / 中：数组索引边界证明器不跨 `as usize` cast 传递范围事实**
  - 状态：已修复（当前树已验证通过；补了回归用例锁定）
  - 验证状态：
    - 文档中的复现命令 `./bin/uya build tests/repros/bounds_prover_as_usize_cast.uya -o /tmp/bounds_prover_as_usize_cast` 现已编译通过（退出码 0），产物可运行
    - 变体矩阵全部通过：命名常量/字面量上界、上下界顺序互换、`&&` 型守卫、`i + 偏移` 线性下标、结构体字段下标、i8/u64/usize 源类型、循环体内下标
    - 曾"仍未编译"的 `benchmarks/http_bench_async_epoll_await.uya` 现在 `check` 通过（0 错误）
    - 新增 `tests/test_bounds_prover_as_usize_cast.uya`（编译 + 运行期取值校验），已进主套件
  - 归属：`src/checker/interval.uya` 的 `extract_linear_expr`（识别 `AST_CAST_EXPR` 并递归剥离，保留源变量的线性形式）+ `verify_linear_expr_bounds_ex`（下界/上界判定）
  - 根因与现状：下标的线性形式现在能跨 cast 保留到源变量 `i`，上界由守卫给出的 `i < N` 约束提供；下界此前是靠"下标类型是 usize ⇒ 天然 ≥ 0"这条假设兜住的（该假设本身不安全，见下一条，已改为"只在源表达式无符号时才自动成立"）。修掉该假设后本用例仍通过——因为 `i < 0` 守卫的反条件给出了真正的 `i >= 0` 约束，说明现在确实是**证明**通过而不是靠假设
  - 影响面：任何"先在窄整型上做范围守卫、再 `as usize` 下标定长数组"的写法不再被误报
  - 最小复现（保留）：`tests/repros/bounds_prover_as_usize_cast.uya`
  - 相关文档：`docs/compiler_bug_report_2026-06-06_bounds_prover_as_usize_cast.md`

- [x] **P2 / 中：边界证明器把 `有符号源 as usize` 的下标当成天然非负（反向漏判，可静默越界读）**
  - 状态：已修复
  - 验证状态：
    - 修复前：`if i >= 8 { return -1; } return g[i as usize];`（`i: i32`，只证明上界）**编译通过**；`i = -1` 时下标实际是 `(usize)-1`，生成的 C 是 `g[(size_t)i]`（无运行期边界检查）→ 越界读
    - 修复后：同形代码报 `数组索引安全证明失败`；`if i >= 0 && i < 8`、`if i < 0 || i >= 8 { return }`、`if i <= -1 || i > 7 { return }` 等"上下界都证明过"的写法仍全部通过
    - 回归面：用新编译器编译 `tests/*.uya` 全部 1107 个用例，编译失败集合与改动前完全一致（只有 `check_cli_no_main` 这个刻意无 `main` 的用例）；最小复现 `tests/repros/bounds_prover_as_usize_cast.uya` 仍编译通过
    - `make check` 全绿
  - 根因：`infer_array_access` 用**下标表达式自身的类型**（cast 之后是 `usize`）判定 `is_unsigned_index`，于是 `verify_linear_expr_bounds_ex` 自动认定下界为 0；而 unchecked `as` 从有符号源转出来时，负值会回绕成巨大下标
  - 修复内容：
    1. 新增 `index_lower_bound_is_zero_by_type()`（`src/checker/type_utils.uya`）：只看 unchecked cast 的**源表达式**类型，源是无符号类型才自动认定下界 0；`as!`（checked，溢出会返回错误而非回绕）按目标类型处理；两个证明入口（`infer_array_access` / `checker_check_array_access`）统一改用它
    2. 顺带补上比较约束的边界换算（`src/checker/interval.uya`）：`i > val` 等价 `i >= val+1`、`i <= val` 等价 `i < val+1`，避免收紧后把 `if i <= -1 || i > N-1 { return }` 这类等价守卫误判
    3. `eval_expr_interval` 支持一元表达式（`-1`/`+x`/`~x`/`!x`）与字符字面量：旧实现遇到 `i <= -1` 的右操作数直接判为无效区间，整条约束都不会被记录
  - 归属：`src/checker/check_expr.uya`（`infer_array_access`）、`src/checker/check_expr_extra.uya`（`checker_check_array_access`）、`src/checker/interval.uya`、`src/checker/type_utils.uya`
  - 负例回归：`tests/error_array_bounds_signed_cast_lower_bound.uya`（只证明上界 → 预期编译失败）
  - 仍存在的宽松点（未修，另计）：非线性下标表达式（如 `g[(n * 2) as usize]`）在线性式提取失败后没有任何兜底检查；`checker_check_array_access` 对非 i32 下标类型也会提前放行（"放宽检查，允许通过"）。收紧这一块会拒绝大量"复杂下标 + 无证明"的现有写法，需要先决定是报错还是由 codegen 插入运行期检查

- [x] **P2 / 中：成员访问约束名用栈缓冲 + 负哈希跳过池化 → 约束表里留下悬垂名字（证明结果随变量名变化）**
  - 状态：已修复
  - 现象：同一段代码只改局部变量名，边界证明结果就不同：`probe.index`/`a.index`/`abc.index` 报"数组索引安全证明失败"，`s.index`/`abcd.index`/`probe2.index` 通过
  - 根因：
    1. `constraint_expr_name()` 把 `对象.字段` 拼进**栈上** `buf`，再交给 `checker_intern_strdup`
    2. `string_pool_intern()` 用 `hash_string()` 的返回值（`u32 as i32`，高位为 1 时是负数）算桶下标，负数时直接 `return str` —— 于是返回的是那个**已经失效的栈指针**
    3. 该指针被存进 `checker.constraint_var_names[]`，之后按名字比较约束时结果取决于栈内容被谁覆盖 → 表现为"换个变量名就时好时坏"
  - 修复内容：
    1. `constraint_expr_name()` 改用 `compiler_arena_alloc` 分配名字缓冲（生命周期稳定）
    2. `string_pool_intern()` 把桶下标规范化为非负（`(hash & 0x7FFFFFFF) % STRING_POOL_SIZE`），负哈希不再跳过池化
  - 影响面：所有靠 `对象.字段` 形式下标做边界证明的代码（本轮就是在这个路径上发现测试用例名字不同结果不同的）
  - 验证状态：名字扫描（`a`/`s`/`ab`/`abc`/`abcd`/`probe`/`probe2`/`probeindex`/`xxxxxxxxxx`）修复后全部通过；`make check` 全绿
  - 回归：`tests/test_bounds_prover_as_usize_cast.uya` 的 `bounds_pick_member`（结构体字段下标）覆盖该路径


- [x] **P1 / 高：`std.thread.async_compute<usize>` 承载“worker 返回结构体结果指针”场景时，生成程序运行期 SIGSEGV**
  - 状态：已修复
  - 验证状态：`./bin/uya test tests/test_pthread_api_create_join.uya` 通过；`./bin/uya test tests/test_std_thread.uya` 20/20 通过；`./bin/uya build tests/repros/async_compute_parallel_struct_result_bug.uya -o /tmp/async_compute_parallel_struct_result_bug` 通过且运行返回 `exit 0`
  - 归属：`lib/std/thread.uya` worker 模型 + `lib/libc/pthread.uya` x86_64 线程启动 trampoline
  - 现象：
    1. 前端解析、类型检查、C99 代码生成和宿主 C 链接全部通过
    2. worker 通过 `async_compute<usize>` 接收任务指针，返回堆分配结果指针（同样以 `usize` 传回）
    3. 结果结构体里包含 `&PairHash`，而 `PairHash` 内又嵌套两个 `[byte:32]` 的 `Hash32`
    4. worker 内部还会走 `Arena + blake3_digest` 风格的哈希计算
    5. 最终程序运行时直接 SIGSEGV，而不是返回业务错误码
  - 修复内容：
    1. ThreadPool 常驻 worker 从 `fork` 子进程切换为 `pthread` 线程，使堆对象指针可在调用方与 worker 间共享地址空间
    2. 修正 `libc.pthread` 的 x86_64 `_pthread_call_start` 栈对齐，消除线程入口后续调用链中的 `movaps` 对齐崩溃
    3. 新增 `tests/test_std_thread.uya` 指针往返回归，覆盖“worker 返回堆对象指针，经 `usize` 往返后主线程解引用”的场景
  - 影响：会阻塞把“并行 worker 计算结果 -> 主线程汇总”的模式安全用于真实项目；HyperGit 那边把大文件 chunk/hash 并行化时就命中过同类崩溃
  - 最小复现：`tests/repros/async_compute_parallel_struct_result_bug.uya`
  - 相关文档：`docs/compiler_bug_report_2026-05-28_async_compute_parallel_struct_result.md`

- [x] **P1 / 高：泛型 wrapper 转发 `std.thread.async_compute<T>` 时 C99 backend 漏发射单态化符号**
  - 状态：已修复
  - 验证状态：`./bin/uya build src/main.uya -o /tmp/uya_codegen_fix` 通过；`UYA_ROOT=./lib /tmp/uya_codegen_fix build tests/repros/c99_generic_async_compute_wrapper_codegen_bug.uya -o /tmp/c99_generic_async_compute_wrapper_codegen_bug` 通过；`UYA_ROOT=./lib /tmp/uya_codegen_fix test tests/test_async_compute_generic_wrapper.uya` 通过
  - 归属：`src/codegen/c99/**` 或泛型单态化发射路径
  - 现象：
    1. Uya 前端解析、类型检查和 C 代码生成都通过
    2. 宿主 C 编译阶段出现 `implicit declaration of function 'std_async_compute_i32'`
    3. 随后同一行报 `error: invalid initializer`
  - 影响：项目本地无法安全封装 `std.thread.async_compute<T>` 这类标准库泛型 API
  - 最小复现：`tests/repros/c99_generic_async_compute_wrapper_codegen_bug.uya`
  - 回归测试：`tests/test_async_compute_generic_wrapper.uya`
  - 相关文档：`docs/compiler_bug_report_2026-05-28_generic_async_compute_wrapper.md`

- [x] **P1 / 高：`@size_of(u64)` 在 C99 backend 被错误发成 `sizeof(u64)`**
  - 状态：已修复
  - 验证状态：`make release-dirty` 通过；`./bin/uya build tests/repros/c99_sizeof_u64_codegen_bug.uya -o /tmp/c99_sizeof_u64_codegen_bug` 通过
  - 归属：`src/codegen/c99/**`
  - 现象：
    1. Uya 前端类型检查与常量折叠都通过
    2. 生成的 C 把 `@size_of(u64)` 发成 `sizeof(u64)`
    3. 随后 C 编译报 `error: ‘u64’ undeclared`
  - 期望行为：应发成后端真实类型的 `sizeof(...)`，或直接折叠成整数字面量
  - 最小复现：`tests/repros/c99_sizeof_u64_codegen_bug.uya`
  - 相关文档：`docs/compiler_bug_report_2026-05-23_c99_sizeof_err_union.md`

- [x] **P1 / 高：`catch |err|` 内把错误回绑到 `!T` 时生成非法 C 初始化**
  - 状态：已修复
  - 验证状态：`make release-dirty` 通过；`./bin/uya build tests/repros/c99_err_union_from_catch_codegen_bug.uya -o /tmp/c99_err_union_from_catch_codegen_bug` 通过
  - 归属：`src/codegen/c99/expr.uya` / `src/codegen/c99/stmt.uya`
  - 现象：
    1. 类型检查允许 `const y: !i32 = err;`
    2. C99 backend 把它错误发成 `struct err_union_int32_t y = err;`
    3. 随后 C 编译报 `error: invalid initializer`
  - 影响：手写 `Future<!T>` / 状态机 / `catch |err|` 中回传错误联合的代码
  - 最小复现：`tests/repros/c99_err_union_from_catch_codegen_bug.uya`
  - 相关文档：`docs/compiler_bug_report_2026-05-23_c99_sizeof_err_union.md`

- [x] **P0 / 严重：`@async_fn` 中 `while true` 含嵌套 await 时生成空终态，导致 keep-alive 连接死锁**
  - 状态：已修复
  - 验证状态：`make check` 780/780 通过；`ab -k -n 1000000 -c 28` 100万 keep-alive 请求 0 失败，RSS 稳定 1.7MB，吞吐量稳定 ~8579 req/sec
  - 归属：`src/codegen/c99/function.uya`
  - 现象：
    1. `handle_bench_client` 的 while true 循环在处理 keep-alive 请求后，错误地落入 `if (s->state == 3) { }` 空块
    2. poll 函数无 return 语句，产生 fallthrough UB，返回未初始化的垃圾 `Pending`
    3. `block_on_with_event_loop` 看到 `Pending` + woken waker 后立即 repoll，造成 100% CPU 无限忙循环，`CLOSE_WAIT` 连接堆积
  - 根因：`gen_async_function_stage_b` 的终态分支（`s->state == await_count + 1`）在 `terminal_return_stmt == null`（函数体以循环结尾）时生成空块，未处理循环回跳。
  - 修复内容：在终态分支生成逻辑中，当 `terminal_return_stmt == null` 且函数体最后一个语句是 `while`/`for` 循环时，生成 `s->state = 0; return Pending;` 安全回跳到循环入口。
  - 相关文件：`src/codegen/c99/function.uya`
  - 备注：此修复同时覆盖 `serve_forever` 与 `handle_bench_client` 的类似模式。

- [x] **P0 / 严重：真 `@async_fn/@await` lowering 仍对 async frame 做堆分配，热路径产生 `malloc/free`**
  - 状态：已修复
  - 验证状态：`make check` 780/780 通过；`benchmarks/http_bench_async_epoll_await_simple.uya` 编译出的 C 代码中，`@async_fn` 的 wrapper 函数不再直接生成 `malloc(sizeof(struct uya_async_...))`，改为调用 per-function free list allocator `_uya_alloc_...()`；热路径无 malloc，仅在 pool 空时 fallback 到 malloc。benchmark 可正常编译运行，`curl` 返回正常。
  - 归属：`src/codegen/c99/**` / async lowering
  - 修复内容：
    1. 为每个 `@async_fn` 生成 per-function free list allocator（`_alloc` / `_free`）
    2. 为每个 `@async_fn` 生成 `release` 函数，并在 vtable 中填充 `release` 指针
    3. wrapper 函数使用 `_alloc()` 替代 `malloc`
    4. poll 函数中 await 完成后的 child future 清理改为通过 vtable 调用 `release`，替代直接 `free`
    5. 修复了 `Future<T>` 接口新增 `release` 方法后，benchmark 和测试中手工 Future 结构体缺少 `release` 的编译错误
  - 相关文件：`src/codegen/c99/function.uya`、`benchmarks/http_bench_async_epoll_await_simple.uya`、`benchmarks/http_bench_async_epoll.uya`、`tests/test_*.uya`
  - 设计文档：`docs/async_frame_allocation_design.md`
  - TODO 文档：`docs/todo_async_frame_allocation.md`

- [x] **P1 / 高：生成的 C 代码在 GCC `-O2` 下运行时 SIGSEGV，`-O1` 正常**
  - 状态：已修复（不再复现，待持续观察）
  - 验证状态：`make check` 780/780 通过；`cc -O2` 编译的 `http_bench_async_epoll` 可正常启动，`ab -n 10000 -c 28` 零失败完成；自举字节一致
  - 归属：C99 代码生成 / 未定义行为
  - 现象（历史）：
    1. 此前 `cc -O2 ... /tmp/http_bench_async_epoll.c` 生成的二进制启动即 `Segmentation fault`
    2. 同一 `.c` 文件用 `-O1` 或 `-O0` 编译则正常
  - 根因（推测）：与 `@async_fn` 状态机的空终态 fallthrough UB（已修复）及错误的 async frame 生命周期管理有关。`while true` 空终态导致 poll 返回未初始化值，`-O2` 内联/常量传播将该 UB 放大为立即崩溃。
  - 修复关联：
    1. `@async_fn` while true 终态死锁修复（`d4511335` 系列提交）消除了 fallthrough UB
    2. async frame per-function free list 分配器修复了潜在的 use-after-free 和 double-free
  - 后续观察：`-O2` 已恢复正常，若后续在更复杂场景下复现，再单独 reopen 并做 ASan/UBSan 深度排查。注意：`benchmarks/run_bench.sh` 使用 `-no-pie -O2 -fno-builtin` 编译标志可稳定通过压测；若使用不带 `-no-pie` 的自定义 CFLAGS，多线程 benchmark 可能因 PIC/PIE 与自定义 pthread 实现的交互出现 segfault。
  - 相关文件：`src/codegen/c99/function.uya`、`benchmarks/http_bench_async_epoll.uya`

- [x] **P2 / 中：`@async_fn` 的 `while true` 回跳逻辑导致生成代码体积膨胀**
  - 状态：已修复（2026-09-27 复核；按原"修复方向"落地）
  - 验证状态：`emit_async_while_loopback_or_exit` 现在只发射 `goto _uya_async_while_head_<id>;` 一条语句，不再调用 `emit_async_segment_with_control(...)` 重新内联整个循环体；循环入口由 `emit_async_while_with_await` 发射的 `_uya_async_while_head_<id>:` label 承接，编号来自 `c99_async_while_label_id`（每个 while 稳定编号），即需求里的"统一顶部 label + 所有回跳 goto 到该 label"已实现
  - 归属：`src/codegen/c99/function.uya`
  - 结论：条目描述的"每个 continuation 末尾重复复制循环体、体积近似指数增长"已不成立
  - 相关文件：`src/codegen/c99/function.uya`（`emit_async_while_loopback_or_exit`、`emit_async_while_with_await`、`c99_async_while_label_id`）
  - 备注：如需量化，可对 `benchmarks/http_bench_async_epoll_await.uya` 统计生成 C 行数前后差异；当前无相关失败用例。

- [x] **P3 / 低：生成代码中大量使用 `uintptr_t` 指针算术，存在 strict aliasing 违规风险**
  - 状态：不再成立（2026-09-27 复核）
  - 验证状态：条目描述的形态在生成 C 中命中 0 次——`grep -rho '(uint8_t\*)(void\*)(uintptr_t)' .uyacache/` 为空。当前生成 C 里的 `uintptr_t` 只出现在明确用途：ptr↔usize 内建（`@ptr_from_usize` / `@usize_from_ptr`，`src/codegen/c99/expr.uya:1293`、`:1303`）、async frame 分配头（`src/codegen/c99/function.uya:7643` 起）、microapp MMU 桥接与平台 helper（`src/codegen/c99/main.uya`），都不再是"把切片/数组偏移算完后强转回另一种指针类型"的形态
  - 归属：`src/codegen/c99/expr.uya`、`src/codegen/c99/function.uya`
  - 结论：`-O2` SIGSEGV 的根因后来分别定位到别处并修复（`@async_fn` while true 终态死锁、async frame per-function free list 分配器、pthread join 早释放线程栈），与 aliasing 无关；本条不再作为待确认风险保留
  - 备注：如后续在 `-O2` 下再次出现与指针类型相关的可疑裁剪，再按"用 memcpy / `char *` 偏移"的方向重新开条目。

- [x] **P1 / 高：microapp `run` / `build` 在 LTO + `--gc-sections` 下链接失败（`undefined reference`）**
  - 状态：已修复
  - 验证状态：`make check` 780/780 通过；`tests/verify_microapp_loader_generic.sh` 通过
  - 归属：C99 代码生成 / 链接器交互
  - 现象：
    1. `microapp run --app microapp ...` 报 `undefined reference to '_pthread_call_start'`、`'_pthread_thread_exit'`、`'_pthread_child_desc'` 等
    2. `microapp build --app microapp ...` 生成的 `.uapp` 同样在链接阶段失败
  - 根因：microapp 默认启用 `-flto -Wl,--gc-sections -ffunction-sections -fdata-sections`。`lib/libc/pthread.uya` 中的 `@asm` 块通过**原始汇编字符串**引用若干内部 `static` 函数与全局变量（`_pthread_call_start`、`_pthread_thread_exit`、`_pthread_child_desc`、`_pthread_start_fn_tmp`、`_pthread_start_arg_tmp`）。LTO 和链接器 `--gc-sections` 无法识别汇编字符串中的符号依赖，将这些符号视为死代码/死数据回收，导致链接报错。
  - 修复内容：
    - `src/codegen/c99/function.uya`：所有 `static` 内部函数的 `__attribute__((unused))` 改为 `__attribute__((used))`
    - `src/codegen/c99/global.uya`：全局变量定义前统一添加 `__attribute__((used))`
  - 影响：任何在 `@asm` 字符串中引用内部 static 函数或全局变量的代码，在启用 LTO/GC-sections 时都可能触发此问题。
  - 相关文件：`src/codegen/c99/function.uya`、`src/codegen/c99/global.uya`、`lib/libc/pthread.uya`

- [x] **P1 / 高：`@async_fn` 中 `http_check_deadline` 触发变量提升 bug**
  - 状态：已修复
  - 验证状态：`tests/test_http1_async_client.uya` 与所有 HTTP/HTTPS 测试通过；`http1_async.uya` 中 TODO 绕过已移除，超时检查已重新启用
  - 归属：编译器 lowering / async 状态机生成
  - 现象：在 `@async_fn` 函数中调用 `http_check_deadline()` 检查超时后，编译器 lowering 过程触发变量提升 bug，导致生成代码行为异常；深层原因是 `while`/`if` 等嵌套块内的 `const` 指针变量被 hoist 到状态机字段后，在 resume 路径上未重新初始化，产生 SIGSEGV
  - 触发代码形态：
    ```uya
    // 读 header 前检查超时
    http_check_deadline(deadline) catch {
        return error.Timeout;
    };
    ```
  - 影响：HTTP 异步客户端无法在读取 header 前进行超时检查
  - 修复位置：
    - `src/codegen/c99/internal.uya`：将 `async_local_*` 与 `async_param_names` 容量从 16 扩至 32
    - `src/codegen/c99/function.uya`、`global.uya`、`types.uya`、`utils.uya`：移除所有硬编码 16 限制
    - `src/codegen/c99/stmt.uya`：`gen_var_decl_stmt` 中若变量已被 hoist，直接生成状态机字段初始化（含数组 `memset`/`memcpy` 处理）
    - `src/codegen/c99/stmt.uya` / `expr.uya`：`return error.X` 与 `as!` 泛型 payload 类型通过 `c99_mono_type_to_c` 正确单态化
  - 相关文件：`lib/std/http/http1_async.uya`、`lib/tls/https.uya`

- [x] **P1 / 高：复合表达式中的 `try @await` lowering 未走统一回放路径**
  - 状态：已修复
  - 验证状态：新增 `tests/test_async_compound_try_await.uya`，覆盖赋值 RHS 与 return 表达式内的 `try @await`，并已通过 `./bin/uya test tests/test_async_compound_try_await.uya --c99`
  - 归属：`src/codegen/c99/async_transform.uya` / `src/codegen/c99/function.uya` / `src/checker/check_expr.uya`
  - 现象：
    1. `total = total + (try @await foo())` 这类赋值 RHS 内的 `try @await` 会落回旧的形状识别路径
    2. `return 1 + (try @await foo())` 这类 return 表达式内的 `try @await` 也无法稳定重放
    3. codegen 阶段还可能重复触发同一 checker 诊断，导致同一问题报两遍
  - 影响：async helper / I/O 包装代码需要被迫拆成“先单独 bind await 结果，再参与外层表达式”的写法
  - 修复内容：
    - `src/codegen/c99/async_transform.uya` / `function.uya`：将嵌套 `try @await` 纳入 replay/substitution，允许 continuation 回放外层复合表达式
    - `src/checker/check_expr.uya`、`proof.uya`、`symbols.uya`、`types.uya`：补齐 `@await` 结果类型预注册，并避免 codegen 阶段重复 checker 诊断
  - 相关文件：`tests/test_async_compound_try_await.uya`

- [x] **P0 / 严重：`@async_fn` 复杂状态机 lowering 后行为错位导致 SIGSEGV**
  - 状态：已修复
  - 验证状态：`tests/test_async_else_if_await.uya` 与 `tests/test_http1_async_client.uya` 已通过，`http1_async_get_chunked_loopback_roundtrip` 不再 SIGSEGV
  - 归属：编译器 lowering / async 状态机生成
  - 现象：
    1. `http1_request_async` 中 `else if meta.read_until_eof { ... if meta.transfer_encoding_chunked { ... } }` 分支的 lowering 生成代码错位
    2. 状态机 state 6 (read_until_eof 分支) 完成后，chunked 解码逻辑未正确放置，直接进入 state 7 返回
    3. 导致 `body_total` 保持为 `MAX_BODY_SIZE` 而非实际解码长度，socket 关闭后 epoll 空转，最终 child 进程 segfault
  - 触发代码形态：
    ```uya
    if meta.has_content_length {
        // ... 正常路径
    } else if meta.read_until_eof {
        // 读循环 ...
        body_total = copied;  // 这一行 lowering 后未正确放入 state
        if meta.transfer_encoding_chunked {
            // 解码逻辑 lowering 后缺失或错位
        }
    }
    ```
  - 影响：任何使用 `else if` 分支并在其中修改变量后继续使用该变量的 `@async_fn` 都可能触发。
  - 修复位置：`src/codegen/c99/function.uya` / `src/codegen/c99/stmt.uya`，补齐 `else if` 分支续接、分支内同步语句发射与循环控制流 resume
  - 备注：此前将 chunked 解码拆出独立 Future 的绕过路径不再是该 lowering 问题的必要条件
  - 相关文件：`lib/std/http/http1_async.uya`

- [x] **P1 / 高：`@async_fn` 中 `return error.X` 报"返回错误值只能在返回错误联合类型 !T 的函数中使用"**
  - 状态：已修复
  - 验证状态：新增 `tests/test_async_return_error_direct.uya`，覆盖 `Future<!i32>` no-await / after-await 直接 `return error.X` 并已通过
  - 归属：编译器 lowering / 错误类型推断
  - 现象：
    1. `@async_fn fn foo() Future<!usize>` 函数体内直接 `return error.X` 类型检查失败
    2. 错误信息："返回错误值只能在返回错误联合类型 !T 的函数中使用"
    3. 即使函数签名明确返回 `!usize`，lowering 后的状态机 poll 函数可能丢失错误联合类型信息
  - 触发代码：
    ```uya
    export @async_fn fn http1_read_chunked_body_async(...) Future<!usize> {
        if rn == 0 {
            return error.ConnectionClosed;  // 报错位置
        }
    }
    ```
  - 影响：所有需要在 `@async_fn` 中提前返回错误的场景
  - 修复位置：`src/checker/main.uya` / `src/codegen/c99/stmt.uya`，类型检查允许 async `Future<!T>` 的直接错误返回，poll lowering 将其包装为 `Poll.Ready(error.X)`
  - 历史绕过方案：使用辅助函数包装错误返回：
    ```uya
    fn http1_err_conn_closed() !usize { return error.ConnectionClosed; }
    // 在 async_fn 中：const e: !usize = try http1_err_conn_closed(); return e;
    ```
  - 备注：`Future<!void>` 直接错误返回仍依赖 `Poll_err_void` / `Future_err_void` / `block_on<void>` 等 void monomorph 支持，需后续单独补齐

- [x] **P1 / 高：`error.X` 作为 `!T` 实参参与普通函数调用时被错误降成裸 `u32`**
  - 状态：已修复
  - 验证状态：新增 `tests/test_error_value_err_union_arg.uya`，覆盖 `error.X -> !i32` 普通函数实参，以及 `error.X -> fn ready_i32(v: !i32) Future<!i32>` 两条路径，并已通过；`make b` 与 `make check` 也已通过
  - 归属：C99 codegen / 调用实参发射
  - 现象：
    1. `fn ready_i32(v: !i32) Future<!i32>` 这类普通函数形参要求 `struct err_union_*`
    2. 调用 `ready_i32(error.InvalidRequest)` 时，生成的 C 却把实参发射成裸 `unsigned int`
    3. 宿主 `cc` 报参数类型不匹配
  - 影响：所有把 `error.X` 直接作为 `!T` 实参传入普通函数的路径；UyaGin 中一度需要保留 `uyagin_error_from_error_id_i32` / `uyagin_ready_i32` 这类兼容辅助
  - 修复位置：`src/codegen/c99/expr.uya`，调用实参发射时若目标形参最终 C 类型为 `err_union_*`，则将 `error.X` 生成为对应 err-union 复合字面量，而不是裸错误 ID
  - 备注：UyaGin 源码中的兼容 helper 仍保留，后续可继续评估是否逐步删除

- [x] **P0 / 严重：`@async_fn` 无 `@await` 与 `catch` 组合路径的 lowering 丢副作用**
  - 状态：已修复，待 release 验收确认
  - 验证状态：已在 DNS async transport 中复现过 lowering 丢副作用问题；现已补 `tests/test_async_transport_fallthrough.uya` 与 `tests/test_async_codegen_edge_paths.uya` 做无网络纯编译器回归，并已通过 `make uya`、`make b`
  - 归属：编译器 lowering / 代码生成
  - 现象：此前 `@async_fn` 在无 `@await` 的 codegen 分支里会直接生成 `Poll.Ready(...)`，导致函数体中的同步语句可能被跳过；在 `Future<!T>` 的 `poll` 实现里又会放大成 `catch` 分支副作用丢失、状态转移不稳定。
  - 影响：这类问题会表现为“编译通过，但运行时没有执行本该在返回前执行的同步逻辑”，尤其会影响 `try !void` 传播和 future 状态切换。
  - 可能位置：`src/codegen/c99/function.uya` 的 async lowering / 代码生成路径，尤其是 `Future<!T>`、`catch`、`Ready` 组合和无 `@await` 返回路径。
  - 备注：当前回归已覆盖 `@async_fn` 无 `@await` 时的同步副作用 / `try !void` 路径，以及 `catch` 直接作用于函数调用的 payload 推断；涉及真实 socket/epoll 的集成路径仍继续由 release 验收观察。

- [ ] **P3 / 低：`test_pthread_api` 单测偶发 flaky（make check 偶尔失败）**
  - 状态：偶发，待排查
  - 验证状态：`make check` 780 tests 中 `test_pthread_api` 偶尔失败，重试后通过
  - 归属：`lib/libc/pthread.uya` / 测试稳定性
  - 现象：多线程并行测试环境下，`tests/test_pthread_api.uya` 存在竞态条件或时间敏感断言，导致非确定性失败
  - 影响：CI/本地验证时偶发误报，需重试
  - 修复方向：增加同步屏障、放宽时间敏感断言容差，或拆分为更小粒度的无竞态子测试
  - 相关文件：`tests/test_pthread_api.uya`、`lib/libc/pthread.uya`

- [x] **P2 / 中：`test_async_event_dynamic_growth` 在默认 fd 软上限的终端里必然失败（`make release` 只挂这一项）**
  - 状态：已修复（环境限制，不是扩容回归）
  - 验证状态：修复前在“终端同款限制”下 100% 复现（软上限 1024 / 硬上限 1048576：旧用例 `exit=1`，`Tests Failed: 1`）；修复后同一限制下 `make check` 1110/1110 通过，`./bin/uya test tests/test_async_event_dynamic_growth.uya` 也由 139 断言（跳过扩容）变为 150 断言（完整跑完扩容用例）
  - 归属：测试环境依赖 / `tests/run_programs_parallel.sh`、`tests/test_async_event_dynamic_growth.uya`
  - 现象：`make release` 走到 `check` 时报 `❌ test_async_event_dynamic_growth:测试失败（退出码: 1）`，总计 1110 / 通过 1109 / 失败 1；单独重跑该用例又通过
  - 根因：该用例要注册 1025 个 fd 才能跨过 `LinuxEpoll` 默认的 1024 slot 边界，用 pipe 对制造可读事件，因此**单个测试进程需同时持有 2050+ 个 fd**。登录终端（本机 `deepin-terminal`：`Max open files 1024 1048576`）与多数 CI 的 `RLIMIT_NOFILE` 软上限是 1024，`pipe2` 返回 `EMFILE`，`try test_sys_pipe2(...)` 把错误抛出测试块 → 退出码 1。代理/自动化环境里软上限是 1048576，所以同样的树在代理侧全绿、在用户终端必挂——“偶发”只是因为跑命令的环境不同
  - 修复内容：
    1. `tests/run_programs_parallel.sh`：启动时把 `RLIMIT_NOFILE` 软上限提升到硬上限（软→硬是合法提升，与脚本已有的 `ulimit -s unlimited` 同一手法），并在头部打印生效的 fd 上限、上限仍不足时给出提示，避免环境限制再被当成回归
    2. `tests/test_async_event_dynamic_growth.uya`：用例自己先用 `getrlimit`/`setrlimit`（`@syscall`，与 `lib/std/runtime/entry` 抬栈同一手法）把软上限抬够，使 `./bin/uya test ...` 这类直接运行也自洽；抬到硬上限仍不足时向 stderr 打印 `skip:` 说明并跳过扩容部分（默认容量断言仍覆盖），不再把环境问题记成失败
  - 影响：任何需要同时持有大量 fd 的用例；排查此类“代理通过、终端失败”时应先比对 `ulimit -Sn`/`/proc/<pid>/limits`
  - 相关文件：`tests/run_programs_parallel.sh`、`tests/test_async_event_dynamic_growth.uya`

## 修复验收

修复完成后，请至少确认以下内容：

- `make release-dirty` 重新通过，或明确缩小失败范围。
- 相关单测通过：
  - `test_std_dns`
  - `test_std_dns_async_transport`
  - `test_epoll_server`
  - `test_tcp_basic`
  - `test_http_server`
  - `test_https_debug`
  - `test_https_loopback`
  - `test_https_real_site`
  - `test_raw_tls`
- 若问题涉及新行为，补充对应测试或回归用例。

## TLS 生产环境改进（2026-04-11）

### 已完成改进

1. **证书验证框架**
   - 新增 `lib/tls/x509/trust_store.uya`：系统根证书存储加载模块
   - 新增 `lib/tls/x509/cert.uya` 有效期字段和验证函数框架
   - 新增错误类型：`TlsCertificateVerificationFailed`, `TlsCertificateExpired`, `TlsCertificateNotYetValid`

2. **HTTPS API 改进**
   - `https_get()`：生产环境安全（默认启用证书验证）
   - `https_get_insecure()`：测试用途（跳过验证）
   - 自动加载系统根证书（支持 Debian/Ubuntu、RHEL/CentOS、macOS）
   - PEM 证书链解析和 Base64 解码已可用
   - 标准 Base64 / Base64URL 能力已提取到 `lib/std/encoding/base64.uya`

3. **生产环境测试**
   - 新增 `tests/test_https_production.uya`：验证生产环境配置
   - GitHub CI / 通用 CI 环境下自动跳过外网访问，仅保留本地信任存储检查

### 使用示例

```uya
// 生产环境（推荐）
var resp: HttpsResponse = https_get(&"example.com"[0], 11, 443, &"/"[0:1]) catch {
    // 处理错误：证书无效、连接失败等
};

// 测试环境（不安全）
var resp: HttpsResponse = https_get_insecure(&"example.com"[0], 11, 443, &"/"[0:1]) catch {
    // 处理错误
};
```

### 已知限制

- 证书有效期验证已添加框架，完整 ASN.1 时间解析待完善
- 生产环境外网验证测试在 CI 中默认跳过，本地仍可直接验证 `example.com`

### 客户端能力现状

- 已完成：真实外站 HTTPS `GET` 已可直连，当前 `example.com` 生产测试不依赖 `curl` 桥接。
- 部分完成：HTTP 方法枚举已包含 `POST` / `PUT` / `DELETE` / `HEAD`，但客户端侧公开 HTTPS API 当前主要仍是 `https_get()` / `https_get_insecure()`。
- 未完成：响应 `Transfer-Encoding: chunked` 目前仍直接返回 `HttpChunkedNotSupported`。
- 未完成：客户端连接池、持久连接复用、TLS 会话复用尚未实现；当前请求路径默认按单次连接处理。

## 相关文件

- `lib/std/async_event.uya`
- `lib/std/encoding/base64.uya` (新增)
- `lib/std/net/dns.uya`
- `lib/tls/x509/trust_store.uya` (新增)
- `lib/tls/x509/cert.uya`
- `lib/tls/x509/verify.uya`
- `lib/tls/https.uya`
- `tests/test_std_dns_async_transport.uya`
- `tests/test_std_dns.uya`
- `tests/test_epoll_server.uya`
- `tests/test_http_server.uya`
- `tests/test_https_debug.uya`
- `tests/test_https_loopback.uya`
- `tests/test_https_real_site.uya`
- `tests/test_https_production.uya` (新增)
- `tests/test_std_base64.uya` (新增)
- `tests/test_raw_tls.uya`
- `tests/test_tcp_basic.uya`
- `tests/test_async_transport_fallthrough.uya`
- `tests/test_async_codegen_edge_paths.uya`
- `lib/std/http/http1_async.uya`（chunked 读取实现，涉及 lowering bug）
