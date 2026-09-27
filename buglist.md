# 编译器 / 标准库 Bug 待办清单

**最后更新：** 2026-09-27（`bench_malloc_phase4` 系列满并发偶发 SIGSEGV 已定位并修复：根因是 pthread join 在子线程还在内核返回路径上就 `free(stack)`/`munmap(desc)`，栈被后续 mmap 复用清零后子线程从栈里取到 0 返回地址跳转到地址 0（use-after-unmap），修复方式是用 `clear_child_tid`(set_tid_address) + 共享 `FUTEX_WAIT` 做退出确认，新增回归 `tests/test_pthread_join_stack_reuse.uya`；"数组索引边界证明器不跨 `as usize` cast 传递范围事实"经当前树复现验证已修复（文档复现命令编译通过），补回归 `tests/test_bounds_prover_as_usize_cast.uya`，同时记录同源的反向漏判问题（有符号源 `as usize` 下标被当作天然非负，可静默越界读，未修复）；跟踪的自举种子陈旧导致 `make release` 冷启动链接失败（`uya_pipeline_worker_dispatch` 未定义）：已按流程刷新 `backup/*.c` 种子；hosted 路线下 `bin/uya-hosted` 一运行即 abort（`glibc detected an invalid stdio handle`）已修复：hosted 下 stdio 整体保留 uya 实现，调用点/声明点/文本发射的 C 名统一解析到 uya 的模块前缀符号，`stdin/stdout/stderr` 一并绑回 uya 流对象；模块作用域 bug 经 `make check` 全绿确认关闭）；2026-09-11 新增并修复 5 项编译器 bug：macOS 交叉目标宿主绑定被 `#ifdef __APPLE__` 裁掉、微应用 payload 打包失败与宿主辅助符号泄漏：指向 const 元素指针形参切片发射未定义 `struct uya_slice_constuint8_t`、多个模块导出同名函数时模块限定调用被发射成另一模块实现、函数查找不区分模块导致用户模块同名函数劫持依赖模块内部调用；后两项同源，均属"扁平 `program_decls` 按名查找不带模块限定"；2026-06-06 新增“数组索引边界证明器不跨 `as usize` cast 传递范围事实”编译器 bug，P2/中，含最小复现 `tests/repros/bounds_prover_as_usize_cast.uya`；2026-05-28 曾新增“`std.thread.async_compute<usize>` 并行 worker 返回结构体结果时运行时崩溃”编译器/运行时交界 bug，及“泛型 wrapper 转发 `std.thread.async_compute<T>` 时 C99 backend 漏发射单态化符号”

本文档用于跟踪 release 验证中发现的问题，便于逐项修复、验证和关闭。

## 分类规则

- **编译器 bug**：语法分析、类型检查、代码生成、优化、lowering 等问题。
- **标准库 bug**：`lib/std/**` 里的实现问题。
- **运行时 bug**：异步调度、事件循环、waker/future 状态机等问题。
- **网络 / TLS 回归**：TCP、HTTP、HTTPS、DNS、TLS 链路问题。

## 标准库 bug

- [x] **P0 / 严重：`dns_client_query_all_async` 仍依赖手工状态机绕过 lowering 问题**
  - 状态：已修复
  - 验证状态：`tests/test_std_dns_async_transport.uya`、`tests/test_std_dns.uya` 均通过；`make check` 779/779 通过
  - 归属：`lib/std/net/dns.uya`
  - 迁移内容：`dns_client_query_all_any_async` 从 `DnsQueryAllFuture` 手工状态机迁移为 `@async_fn`；`DnsQueryTransportFuture` 增加 `soft_error` 模式，在 `@async_fn` 中通过 `err_id_out` 侧向传递错误，避免 `@await catch` 多语句 block 的编译器限制
  - 备注：`DnsUdpFuture` / `DnsTcpFuture` 底层 I/O 状态机保留为手工实现，上层组合逻辑已 `@async_fn` 化。

- [ ] **P3 / 低：`DNS_PREFER_ANY` 的异步聚合路径仍是顺序查询**
  - 状态：未优化
  - 验证状态：当前行为已确认，未做并发化改造
  - 归属：`lib/std/net/dns.uya`
  - 现象：`dns_client_query_all_async` 目前先查 A 再查 AAAA，再汇总结果，并不是并发竞争。
  - 影响：功能正确，但延迟仍然偏高，尤其在高 RTT 或 nameserver 慢响应时会放大等待时间。
  - 可能位置：`lib/std/net/dns.uya`
  - 备注：这不是阻塞性 bug，但属于后续可优化项。

## 运行时 bug

- [x] **P1 / 高：`LinuxEpoll` 的注册/反注册语义仍偏脆弱**
  - 状态：已修复
  - 验证状态：`tests/test_std_dns_async_transport.uya`、`tests/test_http1_async_client.uya` 已通过；`tests/test_async_fd.uya`、`tests/test_std_dns.uya`、`tests/test_std_async_event_fd_reuse.uya` 也已通过
  - 归属：`lib/std/async_event.uya`
  - 现象：`block_on_with_event_loop` / `LinuxEpoll` 在 fd 复用、slot 清理和 epoll interest 重建时出现过 `ENOENT`、`EEXIST` 一类边界错误。
  - 修复内容：引入显式状态机（`SLOT_STATE_EMPTY` / `SLOT_STATE_REGISTERED`）与 `slot_generations` 代际数组，彻底消除 fd 复用混淆；新增 `find_slot` / `alloc_slot` / `init_slot` / `clear_slot` 方法。
  - 可能位置：`lib/std/async_event.uya`
  - 备注：当前已补了幂等清理和失败回退，量产阶段建议保持单 fd interest 语义，后续如需同时关注读写再扩展为小数组或链表。

## 运行时 / 调度限制

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
    - 修复后同样压测 1760 次 **0 失败**；最小用例 10/10 通过、单次约 64ms。
    - `make check` 全绿（主测试 1107/1107 + UPM 套件）。
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
  - 归属：`src/checker/interval.uya` 的 `extract_linear_expr`（识别 `AST_CAST_EXPR` 并递归剥离，保留源变量的线性形式）+ `verify_linear_expr_bounds_ex`（无符号下标的自动下界 0）
  - 根因：下标走 `LinearExpr` 提取时，`i as usize` 曾经不是可识别的线性式（或未剥离 cast），导致守卫里对源变量 `i` 的范围事实无法用到下标判定上
  - 影响面：任何"先在窄整型上做范围守卫、再 `as usize` 下标定长数组"的写法不再被误报
  - 最小复现（保留）：`tests/repros/bounds_prover_as_usize_cast.uya`
  - 相关文档：`docs/compiler_bug_report_2026-06-06_bounds_prover_as_usize_cast.md`

- [ ] **P2 / 中：边界证明器把 `有符号源 as usize` 的下标当成天然非负（反向漏判，可静默越界读）**
  - 状态：未修复（与上一条同源：都是 `as usize` cast 与范围事实的关系）
  - 验证状态：
    - `if i >= 8 { return -1; } return g[i as usize];`（`i: i32`，只证明上界）**编译通过**；`i = -1` 时下标的实际值是 `(usize)-1`，生成的 C 是 `g[(size_t)i]`（无运行期边界检查）→ 越界读
    - 同一 cast 写在 `const u: usize = i as usize;` 里会被要求 `as!`（"可能溢出的整数转换必须使用 as!"），但写在**下标位置**时该检查被跳过
    - `g[(n * 2) as usize]`（非线性下标）连"无法证明"的报错都没有，直接放行
  - 根因：`infer_array_access` 用**下标表达式自身的类型**（cast 之后是 `usize`）判定 `is_unsigned_index`，于是 `verify_linear_expr_bounds_ex` 自动认定下界为 0；而 unchecked `as` 从有符号源转出来时，负值会回绕成巨大下标
  - 期望行为（与 2026-06-06 文档一致）：只有"源表达式本身是无符号类型"或"上下文已证明 `0 <= v`"时才能认定下界为 0，否则应报证明失败（或强制 `as!`）
  - 归属：`src/checker/check_expr.uya`（`infer_array_access`）、`src/checker/check_expr_extra.uya`（`checker_check_array_access`）
  - 备注：收紧要谨慎——很多"有符号循环计数 + `as usize` 下标"的现有代码依赖当前宽松判定，需要先评估迁移面

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

- [ ] **P2 / 中：`@async_fn` 的 `while true` 回跳逻辑导致生成代码体积膨胀**
  - 状态：已知问题，功能正确，待优化
  - 验证状态：生成 C 可正常编译运行，未触发测试失败；但 `handle_bench_client`、`serve_forever` 等含多层嵌套 await 的循环体被重复内联多次
  - 归属：`src/codegen/c99/function.uya`
  - 现象：
    1. `emit_async_while_loopback_or_exit` 在 `while true` 回跳时，调用 `emit_async_segment_with_control(codegen, wbody, 0, wbody.block_stmt_count, ew, null)` 重新发射整个循环体
    2. 若循环体内有多个 await 分支点，每个 continuation 末尾都会再次完整复制一遍循环体
    3. 生成 C 代码体积随循环体大小和 await 数量近似指数增长
  - 影响：编译时间增加、二进制体积膨胀、ICache 压力增大；目前功能未受影响
  - 修复方向：将 while 循环体统一 lowering 为一个顶部 label，所有回跳和 continuation 统一 `goto` 到该 label，而非重复内联整个块
  - 相关文件：`src/codegen/c99/function.uya`
  - 备注：需要引入 `async_loop_state_index` 或类似机制，把循环入口状态编号化管理

- [ ] **P3 / 低：生成代码中大量使用 `uintptr_t` 指针算术，存在 strict aliasing 违规风险**
  - 状态：潜在问题，待确认是否与 `-O2` SIGSEGV 直接相关
  - 验证状态：生成 C 代码中常见形态：`(uint8_t*)(void*)(uintptr_t)(((uintptr_t)((void *)(&s->_uya_loc_xxx[0])) + offset))`
  - 归属：`src/codegen/c99/expr.uya`、`src/codegen/c99/function.uya`
  - 现象：
    1. `-O2` 下 GCC 的 type-based alias analysis 可能将 `uintptr_t` 转换后的指针与原类型指针视为无别名关系
    2. 若后续通过该指针写入 `uint8_t`，再读取原始字段类型，可能被优化器错误裁剪
    3. 目前 `-O1` 正常，`-O2` crash，高度怀疑与此模式有关
  - 影响：所有涉及切片/数组偏移计算的状态机字段访问
  - 修复方向：
    1. 短期：默认编译 flags 加 `-fno-strict-aliasing`（会掩盖真正 UB，不推荐）
    2. 长期：codegen 中对所有 state machine 字段访问统一使用 `memcpy`/`__uya_memcpy`，避免 type punning；或在生成指针偏移时使用 `char *` 而非 `uintptr_t` 转换
  - 相关文件：`src/codegen/c99/expr.uya`（数组索引/切片偏移生成逻辑）
  - 备注：建议优先通过 `-O2 -fno-strict-aliasing` 实验确认根因

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
