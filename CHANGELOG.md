# Uya 变更日志

## Unreleased

### 修复

- **C99 split-C 后端：同名顶层常量的「定义」会重复发射（链接期 `multiple definition`）**。
  合并命名空间下两个源文件可以各写一份同名 `export const`（真实例子：`lib/libc` 的
  `CLOCKS_PER_SEC` 曾由 `stdlib.uya` 与 `time.uya` 各定义一次）。`gen_extern_var_decl` 用
  `codegen.global_variables` 注册表判断「这个 C 名是否已经发射过定义」，而该表上限是
  `C99_MAX_GLOBAL_VARS`（512）且**表满后静默丢弃登记**：小程序撑不满、去重生效看不出问题，
  `uya-agent`（1700+ 顶层全局）表早就满了，两份定义一路漏到链接期。
  现在新增一张独立的「已发射定义的全局 C 名」集合（开放寻址 + 线性探测，容量 8192），
  在定义路径上先查再登记；**表满时不再静默降级，而是当场报错退出**，错误信息带
  `文件:(行:列)`、表名与容量、以及本次要登记的全局名，并指明去调哪个常量 ——
  漏登记会静默产出「会链接失败或结果错误」的 C，比直接编译失败更难排查。
  `gen_global_var`（模块内私有非常量全局）刻意不动 —— 那里重名会**大声**报链接错误，
  去重反而会把 loud failure 换成 silent wrong。注意 `global_variables` 本身是**缓存**
  （满了按名查找会退回 `program_decls` 线性扫描），它继续保留「满则降级」的语义。
  新增回归 `tests/verify_split_dup_global.sh`（固定装置 `tests/fixtures/split_dup_global/`），
  已挂进 `make check` / `make check-hosted`；修复前该脚本报
  `multiple definition of 'DUP_SHARED_CONST'`。修复后 `make b` 自举对比字节一致，
  `make check` 1111/1111 通过。

- **C99 hosted 后端：用户顶层全局与系统头宏同名导致编译失败**。hosted 生成会为非 bootstrap 编译单元
  `#include <errno.h>` 等系统头，宏是文本替换，因此用户顶层全局写成裸名时，单文件定义
  （`__attribute__((used)) const int32_t ETIMEDOUT = 110;`）与镜像分 TU 的声明
  （`uya_mirror_globals.h` 里的 `extern const int32_t ETIMEDOUT;`）都会被写成
  `error: expected identifier or '(' before numeric constant`。
  现在在全局声明/定义前按需发射 `#ifdef X / #undef X / #endif` 护栏（判据为"宏形态"标识符——
  纯标识符且含大写字母，外加 `errno`/`stdin`/`stdout`/`stderr`；跳过编译器自身发射的 `uya_`/`UYA_`
  宏前缀），覆盖 `gen_global_var`、`gen_extern_var_decl`、`c99_mirror_emit_extern_global_line`
  三个发射点。新增回归 `tests/test_hosted_macro_name_collision.uya`。
  该缺陷此前被闸门漏检：`tests/run_programs_parallel.sh` 把 `tests/test_pthread_cond.uya` 归入
  nostdlib 名单，于是 `make check` 全绿，但 hosted 直跑同一用例必挂，并连带
  `tests/stress_pthread.sh` 第 1 轮失败、`tests/verify_async_full_dynamic_resources_gate.sh`
  的 `c99-stress` 阶段失败。修复后 `make check` 1111/1111 通过。

## v0.10.2 - std.process 进程流水线、typed pipeline 落地与偶发红定位

> 发布日期：2026-09-27

### 概要

**v0.10.2** 在 **v0.10.1** 的 async runtime 动态资源与 UPM/package 工作流基础上，把两条新主线推到端到端可发布口径，并把"偶发红"逐个定位到具体机制：

1. **`std.process` 进程与流水线运行时收口**：stage stream 抽象、owned erased stage 生命周期、exec worker stage、child broker 隔离与信号/终端作业控制、capture 策略与取消、spawn 失败分类与结构化诊断。
2. **typed pipeline 端到端**：checker 诊断（首个形参非 `Pipeline`、非 `Pipeline` 左值、sink-after-chain 等）、lowering 所有权转移与错误路径清理、C99 codegen，以及 `std.script` process facade。
3. **`std.path` 与检查器/编译器修复**：平台条件与目录模块别名统一（含交叉目标验证）；边界证明器 `as usize` 范围事实、有符号下标下界与约束名悬垂指针修复；hosted stdio、模块作用域同名函数查找、macOS 交叉宿主绑定与微应用发射修复。
4. **偶发红与发布闸门**：pthread join 早释放线程栈导致的偶发 SIGSEGV（`clear_child_tid` + 共享 `FUTEX_WAIT` 退出确认）；自举种子陈旧导致的 `make release` 冷启动链接失败；`RLIMIT_NOFILE` 软上限 1024 环境把 fd 密集用例的环境限制报成回归。

详见 [docs/releases/RELEASE_v0.10.2.md](./docs/releases/RELEASE_v0.10.2.md)。

### `std.process` / 流水线运行时

- 新增 stage stream 抽象与 owned erased stage 计划，明确 stage 间所有权与析构顺序；新增 exec worker 上的 Uya stage 执行与实验性 fork-backed stage 闸门。
- child broker 隔离、信号 disposition 保留、子进程信号状态清理；覆盖中断信号路由、停止作业取消与终端作业控制（前台所有权）。
- capture 策略与取消语义收敛，stdio remap 加固并让内部 fd 保持在 stdio 之上；spawn 失败分类与结构化启动诊断补齐回归。

### typed pipeline / `std.path`

- checker 诊断补全并归档：首个形参不是 `Pipeline`、非 `Pipeline` 左值参与管道、sink-after-chain、实例方法接收者与合成左值冲突。
- lowering 收口：成功路径转移所有权、错误路径清理输入计划、`try` 前向传播；新增 lowering dump / 诊断验证脚本。
- `std.path` 平台条件（Linux / macOS / Windows）与目录模块别名统一，新增 `tests/verify_std_path_platform_targets.sh` 交叉目标验证。

### 检查器 / 编译器 / 运行时

- 边界证明器：范围事实跨 `as usize` 传递、有符号源 `as usize` 下标下界判定、成员访问约束名悬垂指针（负哈希跳过池化导致结果随变量名变化）修复；配套正向回归 `tests/test_bounds_prover_as_usize_cast.uya` 与负例 `tests/error_array_bounds_signed_cast_lower_bound.uya`。
- 编译器：hosted stdio 符号统一到模块前缀、模块作用域同名函数查找、macOS 交叉目标宿主绑定、微应用 payload 与宿主辅助符号泄漏修复；split-C 缓存锁验证补齐。
- 运行时：pthread join 早释放线程栈导致的 use-after-unmap（偶发 SIGSEGV，#139）修复，新增 `tests/test_pthread_join_stack_reuse.uya`。

### 发布流程

- 刷新自举种子（`backup/*.c`）并修复由此暴露的冷启动链接失败（`uya_pipeline_worker_dispatch` 未定义）。
- 测试脚本把 `RLIMIT_NOFILE` 软上限提升到硬上限；`test_async_event_dynamic_growth` 自身也会先抬够 fd 预算，环境确实不足时明确报 `skip:` 而不是失败。
- UPM 运行时版本号对齐到 `0.10.2`（此前停在 `0.10.0`，影响 `upm --version` 与 `uya_min_version` 门控）；min_version 失败用例改用当前发行线达不到的版本号断言，不再与发布版本号耦合。
- 全量单文件测试 1110/1110 通过；`bin/uya` 以 `-O3 -fno-builtin -DNDEBUG` 构建并 strip。

## v0.10.0 - fmt CLI 收口、if expression 与 C99 主线稳定性

> 发布日期：2026-06-04

### 概要

**v0.10.0** 在 **v0.9.9** 的 WebSocket / HTTP/2 / exec VM 稳定性基础上，把开发工具链与 C99 后端继续推到可发布口径：

1. **`fmt` CLI / API 收口**：完成 phase4 命令行集成，保留注释与 doc comment，稳定 import sort、simplify、rewrite 与 idempotent 行为。
2. **语言与 C99 路径增强**：新增 if expression 的 parser / checker / C99 codegen 路径，并补齐 bare `catch` statement、const pointer 与若干 codegen 回归。
3. **发布种子与 split-C 稳定性**：刷新 backup seeds，修复 split-C cache 清理、Makefile 依赖与私有函数命名冲突，继续保持自举输出与 C99 种子一致。

详见 [docs/releases/RELEASE_v0.10.0.md](./docs/releases/RELEASE_v0.10.0.md)。

### fmt 工具链

- `lib/std/fmt/*.uya` 与 `tools/fmt.uya` 完成 CLI/API 收口，覆盖 tokenization、parser、printer、comments、import sort、simplify 与 rewrite。
- 新增 / 扩展 `tests/test_fmt_*.uya` 与 `tests/verify_fmt_cli.sh`，锁定注释保真、doc comment 附着、语句注释附着、导入排序与幂等格式化。

### 语言 / 编译器

- `src/parser/primary.uya`、`src/checker/check_expr.uya` 与 C99 codegen 支持 if expression。
- C99 后端修复 monomorphized method、typed route generic method、struct array field member copy、async frame descriptor、empty slice zero-init、private function name collision 与 VP8 short payload codegen 回归。
- `src/compile.sh` 与 Makefile 补齐 split-C cache cleanup、Makefile dependency 与 release seed 刷新路径。

## v0.9.6 - microapp 结果面 / 能力契约收口与 CLI 设计同步

> 发布日期：2026-05-12

### 概要

**v0.9.6** 在 **v0.9.5** 的 microapp hosted 多平台闭环基础上，继续做补丁线收口：

1. **runtime / trap 结果面统一**：hosted loader、native fallback 与 unwired 路径统一到单一 bridge ABI 与 `payload result=` 输出口径。
2. **`.uapp required_caps` 正式生效**：镜像声明的能力位图现在会映射为 `SYS_IO` 设备与操作白名单，宿主桩对未知 capability bit 明确拒绝。
3. **发布契约继续锁定**：Linux toolchain / payload symbol 合约与 microapp 文档继续收口，同时同步 `cmd` 子命令拆分设计文档，给后续 CLI 重构提供稳定基线。

详见 [docs/releases/RELEASE_v0.9.6.md](./docs/releases/RELEASE_v0.9.6.md)。

### microapp / 运行时契约

- `lib/kernel/sim.uya`、`lib/std/runtime/microapp/loader.uya` 统一 trap runtime bridge ABI 与 loader 结果输出；hosted loader / native fallback / unwired 路径统一使用单行 `payload result=` 结果面。
- 新增 / 扩展 `tests/verify_microapp_result_surface.sh`、`tests/verify_microapp_trap_runtime.sh`、`tests/verify_microapp_trap_bridge_result.sh`、`tests/verify_microapp_loader_unwired_profile.sh`，锁定 `ok / exit / fault / validated / unwired` 结果口径。
- 新增 `tests/verify_microapp_payload_symbols.sh`，继续拒绝 payload 直接泄漏宿主 libc 普通符号，并锁定 Linux microapp runtime P0 合约。

### 能力模型 / SYS_IO

- 新增 `lib/kernel/capability.uya`，定义 `KERNEL_CAP_IO_*` 与已知能力位校验。
- `lib/kernel/dispatch.uya` 根据 `.uapp` 头部 `required_caps` 建立 `SYS_IO` 设备与操作白名单，未知能力位直接拒绝。
- 新增 `tests/test_kernel_dispatch.uya`，扩展 `tests/test_kernel_sim.uya`，覆盖 capability validate、device/op 授权与宿主桩行为。

### 文档与后续 CLI 收口

- `docs/microcontainer/README.md`、`docs/microcontainer/microapp_profiles.md`、`docs/microcontainer/portable_native_design.md`、`docs/microcontainer/syscall_abi.md` 同步当前 bridge / result / capability 契约。
- `docs/cmd_subcommand_split_design.md` 与 `docs/todo_cmd_subcommand_split.md` 对齐当前 CLI 拆分设计与待办，作为下一阶段 `build/run/test` / image 子命令收口基线。

## v0.9.5 - microapp hosted 多平台真执行闭环

> 发布日期：2026-05-02

### 概要

**v0.9.5** 将 **v0.9.0 - v0.9.4** 已经铺开的 microapp / 微容器链路推进到 hosted 多平台真执行闭环，同时收口同期落地的 HTTP / UyaGin 与编译器修复：

1. **Portable MicroApp ABI / `.uapp v2` / Profile / bridge / result model 规格冻结**：微容器镜像、profile 与结果面不再继续频繁改名或改字段。
2. **发布闸门与 CI 口径统一**：`make microapp-check`、`make microapp-hosted-smoke` 与平台专属 runtime 检查形成稳定组合，`linux_x86_64_hardvm` 真执行链路成立，`linux_aarch64_hardvm` 与 `macos_arm64_hardvm` 具备 host-gated 回归入口。
3. **同期功能面并入发行线**：纳入 UyaGin P5、最小 HTTPS -> UyaGin 桥接，以及 direct err-union await bind 的 async lowering 修复。

详见 [docs/releases/RELEASE_v0.9.5.md](./docs/releases/RELEASE_v0.9.5.md)。

### HTTP / UyaGin / 编译器 async lowering（2026-04-25）

- `std.http.parse/types/server` 与 `std.http.uyagin` 完成 UyaGin P5 主链路：Header 小写/哈希缓存、8-byte word-at-a-time 扫描、chunked request 原地解码、显式 chunked response、`writev` 聚合写，以及 Linux x86_64 `sendfile` 优先文件发送。
- `tls.https` 新增最小 `https_server_serve_uyagin_once` 桥接，可将 TLS 握手后的 HTTP 请求交给 `std.http.uyagin.Engine`。
- C99 async lowering 修复 direct err-union await bind：`const r: !T = @await fut;` 现在能正确切段、恢复并在后续 `catch` / 表达式中保留错误联合类型。
- 回归新增 / 扩展：`tests/test_async_await_direct_err_union.uya`、`tests/test_http_parse.uya`、`tests/test_http_server.uya`、`tests/test_http_uyagin.uya`、`tests/test_https_loopback.uya`。

## v0.9.4 - microapp 运行时收口、`@embed` / `@c_import` 与标准库扩展

> 发布日期：2026-04-22

### 概要

**v0.9.4** 在 **v0.9.x** 发行线上继续推进 “可发布、可验证、可移植” 这条主线：

1. **microapp / 微容器运行时链路继续收口**：补齐 mapped payload、reloc / bss / fault / exit-code / recovery 路径，新增 `inspect-image` / `verify-image` / profile-first 默认解析，并用聚合脚本覆盖样例源码、镜像、运行时与恢复流程。
2. **语言与构建能力补齐**：新增 `@embed` / `@embed_dir`，完成 `@c_import` 构建集成；同时修复 macro 展开后的切片表达式 codegen 崩溃，并改进 codegen 输出缓冲与 release / zig / gcc 构建路径。
3. **标准库继续扩展**：新增 `std.sql` 抽象、`std.mqtt.async`，并为 `std.crypto` 补上 BLAKE2b / BLAKE2s / MD5 / CRC32。

`./tests/run_programs_parallel.sh --uya --c99` **828** 项测试通过，`make b` 自举验证通过，`make release-clean` 通过。详见 [docs/releases/RELEASE_v0.9.4.md](./docs/releases/RELEASE_v0.9.4.md)。

### microapp / 工具链

- `src/main.uya`：新增 / 完善 `pack-image`、`inspect-image`、`verify-image`、microapp profile 默认推导与诊断输出。
- `lib/std/runtime/microapp/loader.uya`、`lib/kernel/image.uya`、`lib/kernel/sim.uya`、`lib/kernel/recovery.uya`：收口 mapped payload、relocation、BSS、fault / trap、recovery / update 与 host API 诊断路径。
- `Makefile`、`src/compile.sh`：修复 release / release-clean、zig / gcc、`run` / `test` 与 hosted cross-build 工作流问题；补充 host-specific seeds 与 macOS hosted 交叉构建支持。

### 语言 / 编译器

- `src/parser/primary.uya`、`src/main.uya`：新增 `@embed` / `@embed_dir` 内建能力与配套 CLI / codegen 路径。
- `src/compile.sh`、`tests/link_cimports_posix.sh`：完成 `@c_import` 的 sidecar / split-C 构建集成。
- `src/main.uya`：补齐 `-v` / `--version`，使 CLI 版本查询与文档保持一致。
- `src/codegen/c99/expr.uya`、`src/codegen/c99/function.uya`、`lib/std/io/file.uya`：修复 macro 展开切片表达式 codegen SIGSEGV，并改进 codegen 输出缓冲与 async / split-build 稳定性。

### 标准库

- `lib/std/sql/*.uya`：新增 `std.sql` 抽象层与文档。
- `lib/std/mqtt/async.uya`：新增 async MQTT 客户端基础模块。
- `lib/std/crypto/*.uya`：新增 BLAKE2b / BLAKE2s / MD5 / CRC32 实现。

### 测试与文档

- 新增 / 扩展 `tests/test_embed_builtin.uya`、`tests/test_c_import_file.uya`、`tests/test_c_import_dir.uya`、`tests/test_std_sql.uya`、`tests/test_std_mqtt_async.uya`、`tests/test_macro_slice_expr_codegen.uya` 及多组 microapp 验证脚本。
- 更新 `readme.md`、`docs/TESTING.md`、`docs/UYA_BUILD_RUN.md`、`docs/c_import_design.md`、`docs/embed_design.md`、`docs/std_sql.md`、`docs/std_mqtt_async.md` 等文档。
- 新增 `docs/releases/RELEASE_v0.9.4.md`

---

## v0.9.3 - `@frame(foo)` 类型构造器与 pinned 语义

> 发布日期：2026-04-14

### 概要

**v0.9.3** 在异步帧分配基础设施之上，引入 `@frame(foo)` 类型构造器及其完整的 checker 语义：

1. **`@frame(foo)` 类型构造器**：解析器支持 `@frame(fn_name[<T>])` 语法，类型检查器将其解析为对应 async 函数的状态机结构体类型 `uya_async_<fn>`。
2. **无初始化声明**：`@frame` 类型变量允许无显式初始化（`var f: @frame(foo);`），由声明点负责分配/零初始化。
3. **Pinned 语义检查**：async frame 类型被视为 pinned，禁止按值移动、整体赋值、按值传参和按值返回。
4. **C99 前向声明**：codegen 在函数原型中自动为 `@frame` 参数/返回类型生成 `struct uya_async_xxx;` 前向声明，避免跨 TU 编译失败。

`make check` **785** 项测试通过（新增 5 项），`make b` 自举验证通过。评审后修复：补全方法调用路径的 pinned 参数检查，修复 export async 函数 frame struct 命名不一致。详见 [docs/releases/RELEASE_v0.9.3.md](./docs/releases/RELEASE_v0.9.3.md)。

### 语言特性

- `src/lexer.uya`：将 `@frame` 加入内置函数白名单。
- `src/parser/types.uya`：解析 `@frame(fn_name[<T>])` 为 `AST_TYPE_FRAME`。
- `src/parser/statements.uya`：`@frame(...)` 类型变量允许无初始化声明。
- `src/checker/type_from_ast.uya`：`AST_TYPE_FRAME` 解析为 `TYPE_STRUCT("uya_async_<fn>")`；校验目标为 `@async_fn`、泛型实参数量匹配、实参 concrete。
- `src/checker/check_node_extra.uya`：赋值语句中禁止对 pinned 类型整体赋值和按值移动。
- `src/checker/check_stmt.uya`：变量声明禁止用 pinned 类型按值初始化。
- `src/checker/check_call.uya`：函数调用禁止按值传递 pinned 类型参数。
- `src/checker/main.uya`：return 语句禁止按值返回 pinned 类型。

### 代码生成

- `src/codegen/c99/types.uya`：新增 `c99_emit_async_frame_forward_for_type`，递归扫描类型中的 `@frame` 并生成 C 前向声明；`AST_TYPE_FRAME` 生成 `struct uya_async_<cname>`。
- `src/codegen/c99/function.uya`：`gen_function_prototype`、`gen_method_prototype`、`gen_mono_method_prototype` 在原型发射前调用前向声明 helper；修复 `c99_async_collect_locals_recursive` 使无初始化的 `@frame` 局部变量也能被提升到状态机字段。

### 测试

- 新增 `tests/test_async_frame_type.uya`（3 项正向测试）
- 新增 `tests/error_async_frame_pinned_move.uya`
- 新增 `tests/error_async_frame_pinned_arg.uya`
- 新增 `tests/error_async_frame_pinned_return.uya`

### 文档

- 更新 `docs/async_frame_allocation_design.md`、`docs/todo_async_frame_allocation.md`
- 新增 `docs/releases/RELEASE_v0.9.3.md`

---

## v0.9.2 - 测试基础设施：并行测试独立目录与实时输出

> 发布日期：2026-04-12

### 概要

**v0.9.x** 补丁：改进并行测试脚本与 `make tests` 体验。

1. **独立输出目录避免冲突**：基于测试文件相对路径生成唯一 ID，每个单文件/多文件测试用例拥有独立的编译输出目录，彻底消除同名 `.uya` 文件在并行运行时的产物覆盖问题。
2. **实时结果输出**：后台测试每完成一个立即输出 `✓` / `❌`，不再等全部跑完才汇总；通过 `stdbuf -oL` 自动处理非 TTY 环境（如 `make`/`CI`）的行缓冲，解决 `make tests` 看不到实时进度的问题。
3. **`make tests` 去掉 `--hide-pass`**：默认模式下通过的测试也会实时显示，与直接运行脚本行为保持一致。

`make check` **779** 项测试通过。详见 [docs/releases/RELEASE_v0.9.2.md](./docs/releases/RELEASE_v0.9.2.md)。

### 测试基础设施

- `tests/run_programs_parallel.sh`：新增 `generate_test_id()`、`process_ready_single_results()`；重构编译产物路径与流水线式结果收集逻辑；顶部增加 `stdbuf -oL` 自举逻辑。
- `Makefile`：`tests:`、`tests-hosted:`、`tests-uya:` 移除 `--hide-pass`。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.9.2.md`
- 编译器帮助中的版本字符串更新为 **v0.9.2**

---

## v0.9.1 - 修复 `@async_fn` 变量提升与嵌套块初始化 bug

> 发布日期：2026-04-12

### 概要

**v0.8.x** 补丁：修复编译器在 `@async_fn` 状态机 lowering 中的两类关键 bug：

1. **变量提升容量不足**：`async_local_*` 数组硬编码为 16 条目，导致像 `http1_request_async` 这种拥有大量局部变量的函数在 lowering 时丢失后续局部，生成未定义局部引用的 C 代码。
2. **嵌套块内 hoisted 变量未初始化**：`while`/`if` 等不含 `@await` 的嵌套控制流中的 `const` 指针被 hoist 到状态机字段后，`gen_var_decl_stmt` 仍将其生成为普通局部变量，而后续引用已映射为 `s->_uya_loc_xxx`，导致该字段在 resume 路径上为未初始化（null），运行时 SIGSEGV。

同时修复了 `@async_fn` 中 `return error.X` 与 `as!` 强制类型转换在泛型上下文下的 payload 类型单态化问题。所有 HTTP/HTTPS 测试（14 项）全部通过，`make check` **779** 项测试通过。详见 [docs/releases/RELEASE_v0.9.1.md](./docs/releases/RELEASE_v0.9.1.md)。

### 编译器

- `src/codegen/c99/internal.uya`：`async_local_names` / `async_local_types` / `async_local_inits` / `async_local_root_stmt` / `async_param_names` 从 16 扩至 32。
- `src/codegen/c99/function.uya`、`global.uya`、`types.uya`、`utils.uya`：将所有硬编码 `16` 改为 `@len(...)` 动态检查。
- `src/codegen/c99/stmt.uya`：`gen_var_decl_stmt` 在 async poll 上下文中，若变量已被 hoist 到 `async_local_names`，直接生成状态机字段初始化（`s->_uya_loc_xxx = init`）；数组类型额外处理 `memset`/`memcpy`。
- `src/codegen/c99/stmt.uya` / `expr.uya`：`return error.X` 与 `as!` 的 payload C 类型通过 `c99_mono_type_to_c` 正确单态化泛型参数。

### 标准库

- `lib/std/http/http1_async.uya`：移除 `catch` 块内多余分号；重新启用此前被 TODO 绕过的 `http_check_deadline(deadline_ms)` 超时检查。
- `lib/tls/https.uya`：修复 `catch` 块语法与 `as!` 溢出使用方式（先提取 `.value` 再运算）。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.9.1.md`
- 编译器帮助中的版本字符串更新为 **v0.9.1**

---

## v0.8.2 - 主线程栈上限改为应用显式设置

> 发布日期：2026-03-31

### 概要

**v0.8.x** 补丁：`std.runtime.entry` 不再在 C `main` 中固定提高 `RLIMIT_STACK`；新增 **`set_process_stack_limit_bytes`**，应用按需调用；编译器在 **`main_main`** 内根据 **`--stack-size`** 调用该函数；`make check` **698** 项测试通过。详见 [docs/releases/RELEASE_v0.8.2.md](./docs/releases/RELEASE_v0.8.2.md)。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.8.2.md`
- 编译器帮助中的版本字符串更新为 **v0.8.2**

---

## v0.8.1 - v0.8.0 发行线补丁：TFLM、epoll HTTP、压测与稳定性

> 发布日期：2026-03-30

### 概要

自 **v0.8.0** 起的**补丁版本**，在同一发行线下合并 TFLM 标准库与多后端（含 CMSIS-NN）、`std.http` 非阻塞与 epoll 路径、`http_bench_async` 与基准脚本、全局数组字符串字面量初始化、编译器与 pthread / nostdlib / 自举对比等修复；`make check` **697** 项测试通过。详见 [docs/releases/RELEASE_v0.8.1.md](./docs/releases/RELEASE_v0.8.1.md)。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.8.1.md`
- 编译器帮助中的版本字符串更新为 **v0.8.1**

---

## v0.8.0 - 里程碑：异步运行时、std.http、多文件 C99 与工具链

> 发布日期：2026-03-25

### 概要

自 **v0.7.4** 起的里程碑版本（**~379** 次提交），`make check` **658** 项测试通过。

### 新特性与重大改进

- **异步运行时**：`@async_fn` 状态机大小与转换验证、多 fd 调度、`MpscChannel` / `RingQueue`、`ThreadPool` 扩展；泛型异步与 C99 单态修复。
- **std.http**：TCP、解析、路由、阻塞服务器、Keep-alive / 流水线、multipart、JWT（HS256 + `exp`）与 SHA-256（无 OpenSSL）；压测程序与 Go 对照基准。
- **C99 后端**：默认多文件输出与镜像 TU、`--no-split-c`；切片形参按值；vtable 与自举对比修复；codegen/SIMD 性能与缓存。
- **工具链**：`--nostdlib` 与 Makefile/种子流程；`build` / `run` / `test` 子命令；默认更大堆栈、默认 `--safety-proof`；字符串 `\xHH` / `\uXXXX` 转义。
- **标准库**：`IAllocator` / `Arena`、`Vec` / `HashMap` 等与分配器协同；`std.json` 编码写路径优化。

### 文档与发布

- 新增 `docs/releases/RELEASE_v0.8.0.md`
- 编译器 `--version` / 帮助中的版本字符串更新为 **v0.8.0**

---

## v0.7.4 - P1/P2 可选任务实现

> 发布日期：2026-02-24

### 新特性

#### P1 任务

- **越界访问检测（bounds_check_pass）**
  - 在 `checker/proof.uya` 中实现编译期静态分析
  - 检测数组访问越界风险
  - 检测指针算术越界风险
  - 检测切片边界越界风险
  - 支持 `BoundsCheckRisk` 枚举（SAFE/WARNING/ERROR）

#### P2 任务

- **指令融合优化（instruction_fusion_pass）**
  - 在 `checker/optimizer.uya` 中实现指令融合框架
  - 检测可融合的连续算术指令
  - 检测乘加融合（MAC）模式
  - 为后续优化提供分析基础

- **冗余指令消除（redundant_instruction_elimination_pass）**
  - 在 `checker/optimizer.uya` 中实现冗余指令检测
  - 检测 nop 等无副作用指令
  - 检测自移动指令（如 mov r0, r0）
  - 寄存器生命周期分析框架

- **RISC-V 平台扩展支持**
  - 新增 `TYPE_ASM_REG_RISCV_V` 类型（向量扩展）
  - 新增 `TYPE_ASM_REG_RISCV_F` 类型（单精度浮点）
  - 新增 `TYPE_ASM_REG_RISCV_D` 类型（双精度浮点）
  - 更新 `is_riscv_reg_type()` 函数支持新类型
  - 更新 `asm_reg_type_name()` 函数支持新类型

### 新增函数

- `check_array_bounds_const()` - 检测数组访问越界（常量索引）
- `check_pointer_arithmetic_bounds()` - 检测指针算术越界
- `check_slice_bounds()` - 检测切片边界越界
- `bounds_check_pass()` - 全程序越界访问检测 Pass
- `can_fuse_arithmetic_instructions()` - 检测指令融合机会
- `instruction_fusion_pass()` - 指令融合优化 Pass
- `detect_redundant_instruction()` - 检测冗余指令
- `analyze_register_lifecycle()` - 寄存器生命周期分析
- `redundant_instruction_elimination_pass()` - 冗余指令消除 Pass
- `optimize_asm_block()` - @asm 块综合优化入口

### 测试

- 新增 `tests/programs/test_bounds_check.uya` 测试文件
- 所有 462 个现有测试通过

---

## v0.7.3 - 编译期优化功能完善

> 发布日期：2026-02-24

### 新特性

- **优化级别命令行选项**
  - `--opt=<0-3>` 设置优化级别
  - `-O0`, `-O1`, `-O2`, `-O3` 简写形式
  - 默认优化级别为 1（常量折叠 + 死代码消除）

### 优化级别说明

| 级别 | 功能 |
|------|------|
| 0 | 禁用优化（调试模式） |
| 1 | 常量折叠 + 死代码消除（默认） |
| 2 | + 证明优化 |
| 3 | + 内联 + 循环展开（未来） |

### 修复

- **修复 Lexer 不支持三元运算符导致的优化器解析问题**
  - 问题：lexer 遇到 `?` 返回 `TOKEN_EOF`，导致 parser 提前终止
  - 影响：`optimizer.uya` 中三元运算符后的函数定义全部丢失
  - 修复：将三元运算符改为 if-else 语句
  - 同时修复了被掩盖的 TokenType 名称错误：
    - `TOKEN_AND_AND` → `TOKEN_LOGICAL_AND`
    - `TOKEN_OR_OR` → `TOKEN_LOGICAL_OR`
    - `TOKEN_EQUAL_EQUAL` → `TOKEN_EQUAL`
    - `TOKEN_BANG_EQUAL` → `TOKEN_NOT_EQUAL`
  - 修复 ASTNodeType 和字段名错误：
    - `AST_INDEX_EXPR` → `AST_ARRAY_ACCESS`
    - `bool_value` → `bool_literal_value`

### 文档更新

- 更新 `docs/compile_time_optimization_status.md` 状态文档

---

## v0.7.2 - @asm 测试覆盖率完善

> 发布日期：2026-02-23

### 测试

- **@asm 功能测试覆盖率 100%**
  - 新增 9 个正向测试文件，覆盖基础功能、类型系统、clobbers、边界情况等
  - 新增 17 个反向测试文件，覆盖语法错误、类型错误、限制检查等
  - 修复了类型检查器中 `AST_ASM` 节点作为语句使用时未进行类型检查的 bug

### 新增测试文件

**正向测试（9 个）：**
- `test_asm_basic.uya` - 基础功能：简单指令、无输入输出、多输入多输出
- `test_asm_types.uya` - 类型系统：i8/i16/i32/i64/u8/u16/u32/u64/usize/指针
- `test_asm_clobbers.uya` - clobbers 声明：单/多寄存器、memory、混合
- `test_asm_edge_cases.uya` - 边界情况：空指令、最大输入/输出、控制流中使用
- `test_asm_codegen.uya` - 代码生成验证
- `test_asm_expressions.uya` - 表达式：变量、常量、数组元素、结构体字段
- `test_asm_duplicate_output.uya` - 多输出变量测试
- `test_asm_const_output.uya` - 输出测试
- `test_asm_void_output.uya` - 无输出测试

**反向测试（17 个）：**
- `error_asm_empty_block.uya` - @asm 块不能为空
- `error_asm_missing_string.uya` - 期望指令字符串
- `error_asm_invalid_input_type.uya` - f32 输入类型错误
- `error_asm_invalid_output_type.uya` - f64 输出类型错误
- `error_asm_output_pointer.uya` - 指针不能作为输出
- `error_asm_f64_input.uya` - f64 输入类型错误
- `error_asm_f64_output.uya` - f64 输出类型错误
- `error_asm_missing_paren.uya` - 语法错误：缺少 '('
- `error_asm_missing_close_paren.uya` - 语法错误：缺少 ')'
- `error_asm_missing_brace.uya` - 语法错误：缺少 '{'
- `error_asm_missing_close_brace.uya` - 语法错误：缺少 '}'
- `error_asm_too_many_inputs.uya` - 输入超过最大限制
- `error_asm_too_many_outputs.uya` - 输出超过最大限制
- `error_asm_void_input.uya` - void 类型输入错误
- `error_asm_struct_input.uya` - 结构体输入错误
- `error_asm_array_input.uya` - 数组输入错误
- `error_asm_slice_input.uya` - 切片输入错误

### 修复

- 修复 `src/checker/main.uya`：`AST_ASM` 节点作为语句使用时未调用类型检查

---

## v0.7.1 - 切片字面量 & 语法增强

> 发布日期：2026-02-21

### 新特性

- **切片字面量**：支持从数组字面量直接创建切片
  - `const slice: &[i32] = &[1, 2, 3];`
  - `const slice: &[i32] = &[0: 10];`
  - 无需先声明数组变量，直接创建切片

- **match 表达式省略分号**
  - 当所有分支都是 block 时可省略分号
  - 提升代码流畅性和可读性

### 改进

- 类型推断增强：变量声明时正确推断切片类型
- 代码生成优化：切片字面量生成高效的 C99 复合字面量

---

## v0.7.0 - 编译器重构 & 性能优化

> 发布日期：2026-02-21

### 重构（阶段一：模块拆分）

**checker.uya 拆分为 16 个文件：**
- `types.uya` - 类型定义 (224 行)
- `symbols.uya` - 符号表操作 (668 行)
- `type_utils.uya` - 类型工具函数 (481 行)
- `lookup.uya` - 查找函数 (452 行)
- `generics.uya` - 泛型单态化 (177 行)
- `proof.uya` - 安全证明 (331 行)
- `type_from_ast.uya` - 类型解析 (335 行)
- `check_expr.uya` - 表达式检查 (1465 行)
- `check_stmt.uya` - 语句检查 (754 行)
- `check_call.uya` - 调用检查 (747 行)
- `interval.uya` - 区间算术 (1027 行)
- `check_expr_extra.uya` - 表达式辅助 (824 行)
- `check_node_extra.uya` - 节点检查 (641 行)
- `modules.uya` - 模块系统 (1197 行)
- `macro_expand.uya` - 宏展开 (1168 行)
- `main.uya` - 检查器入口 (610 行)

**parser.uya 拆分为 6 个文件：**
- `types.uya` - 类型解析 (599 行)
- `primary.uya` - 基础表达式 (2393 行)
- `expressions.uya` - 二元/一元表达式 (925 行)
- `statements.uya` - 语句解析 (616 行)
- `declarations.uya` - 声明解析 (2200 行)
- `main.uya` - 解析器入口 (479 行)

### 内存优化（阶段二）

- **Arena 按需增长**：动态分配新 chunk，避免静态分配浪费
- **静态内存减少 75%**：320MB → 81MB

### 性能优化（阶段三）

- **作用域链表优化**：符号表查找从 O(32768) → O(当前作用域符号数)
- **自举编译时间**：8.2s → 1.8s（提升 4.5 倍）
- **字符串池**：减少字符串比较开销

### 修复

- 修复 `fprintf` 参数类型警告

### 代码统计

| 模块 | 文件数 | 总行数 |
|------|--------|--------|
| checker | 16 | 10,978 |
| parser | 6 | 7,212 |
| codegen/c99 | 10 | ~8,000 |

---

## v0.6.0 - 统一测试框架 & CLI 重构

> 发布日期：2026-02-20

### 新特性

- **统一命令行接口**：`uya build`、`uya run`、`uya test` 子命令
- **统一测试框架**：`test "name" {}` 语法，自动收集和运行测试
- **自动入口检测**：编译器自动检测 `test` 和 `export fn main`
- **--nostdlib 模式**：静态链接，零依赖可执行文件
- **编译阶段计时**：显示各编译阶段耗时

### 修复

- `try` 表达式在 void 函数中正确工作

---

## v0.5.9 - 错误处理增强

### 新特性

- 错误联合类型 `!T` 改进
- 预定义错误集支持

---

## v0.5.8 - 接口系统

### 新特性

- 鸭子类型接口
- 零注册，编译期生成

---

## v0.5.7 - 泛型系统

### 新特性

- 泛型语法 `<T>` 支持
- 泛型约束 `<T: Trait>`
- 泛型单态化

---

## v0.5.5 - 内存安全

### 新特性

- 编译期内存安全证明
- 指针非空追踪
- 移动语义检查

---

## v0.5.4 - Union 类型

### 新特性

- 联合体（union）类型
- 编译期标签跟踪
- C union 100% 互操作

---

## v0.5.3 - 模块系统

### 新特性

- 目录级模块
- 显式导出 `export`
- 路径导入 `use`

---

## v0.5.0 - 初始发布

### 核心特性

- 零 GC
- 默认高级安全
- 单页纸可读完
- 无 lifetime 符号
- 无隐式控制
- 编译期证明
