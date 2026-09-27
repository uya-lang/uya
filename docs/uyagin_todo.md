# UyaGin TODO / 路线图

> **核对头（2026-09-27）**：P0–P6 已完成；**P7（性能达标）与 P8（文档）仍未收口**。
> - 运行时门禁不再是 blocker：本轮实测 `tests/verify_uyagin_http_bench_runtime.sh` 在 `threads=4` 下通过（2026-04 记录的 multi-shard SIGSEGV 已不复现）。
> - 但正式验收口径所需的"5 场景 × 5 run + syscall/CPU probe + 原始 report.json/summary.csv"从未产出；仓库里唯一带 Gin 对照的一次是 `build/uyagin_http_bench/20260627_063210`（runs=1、server_threads=1、单场景 hello），其 `rps_ratio_vs_gin=2.17`、`p99_ratio_vs_gin=0.227` 只是 smoke 证据，不能替代 P7 验收。
> - P8 的 API 文档 / 迁移指南 / 示例 / 压测报告四项均未开始。
> 因此本文件的勾选状态（P7 全部门槛未勾）与事实一致，属于**真实的未完成工作**。

本 TODO 以“先稳定、再压测、最后超过 Gin”为主线。所有性能结论必须用同机、同业务、同连接模型的 benchmark 证明，不能只凭设计假设宣称达标。

## P0：核心切片（已完成）

- [x] 新增 `std.http.uyagin` 模块。
- [x] 定义 `Engine`、`GinContext`、`AsyncHandler`、`AsyncMiddleware`。
- [x] 支持 `GET/POST/PUT/PATCH/DELETE/OPTIONS/HEAD` 注册。
- [x] 支持 path 参数：`/users/:id` + `ctx.param("id")`。
- [x] 支持 `ctx.string`、`ctx.json_raw`、`ctx.no_content`。
- [x] 支持异步响应写入与小响应合并写。
- [x] 支持异步 read + parse 与单连接 keep-alive loop。
- [x] 增加核心单测：200、path param、404。

## P1：框架语义补齐

- [x] 增加 middleware chain：`Use(...)`、route group、`Abort()` 后停止链。
- [x] 增加统一错误映射：协议错误→4xx，业务未处理错误→500。
- [x] 增加 recovery middleware：记录错误、写 500、防止连接状态污染。
- [x] 增加 `ctx.status`、`ctx.header_set`、`ctx.redirect`、`ctx.bytes`。
- [x] 增加 query/form helpers：`DefaultQuery`、`PostForm`、multipart file view。
- [x] 增加 HEAD 自动去 body、OPTIONS 自动 Allow。

## P2：高性能路由

- [x] 将线性 `Router` 替换为方法分表 radix tree。
- [x] 静态路由优先，参数路由次之，通配路由最后。
- [x] 启动期预计算 pattern segment、param name offset、literal hash。
- [~] 提供 `GET_T<H: AsyncHandler>` 泛型注册，减少 vtable dispatch。
  当前已落地兼容入口 `GET_T(engine, pattern, handler)`；受当前编译器对泛型 thunk / `sizeof(H)` codegen 限制，仍走 `AsyncHandler` 接口派发。
- [x] 增加路由冲突检测：重复路径、参数名冲突、wildcard 非尾部。
- [x] Benchmark 路由：1、16、128、1024 条路由的 ns/match 与 Gin 对比。
  2026-04-24 本机实测：已新增 `benchmarks/uyagin_route_bench.uya`、`benchmarks/gin_route_bench/uyagin_route_gin_bench_test.go` 与 `benchmarks/run_uyagin_route_bench.sh`，并完成 Uya/Gin 对照。

## P3：连接与调度

- [x] 实现 `Engine.run(listener, loop, scheduler)` accept loop。
- [x] 支持单 EventLoop 多连接任务队列，连接 future 完成后回收 slot。
- [x] 支持多 reactor shard：按 CPU 数启动 N 个 loop。
- [x] 支持 `SO_REUSEPORT` 或 accept 后 fd 分发。
- [x] 增加连接限流、read timeout、write timeout、idle timeout。
- [x] 增加优雅关闭：停止 accept、drain keep-alive、deadline 强关。

## P4：内存与 allocator

- [x] 为每请求增加 `Arena`，通过 `GinContext.allocator` 注入。
- [x] `RequestArena.drop` 自动 reset/归还，错误路径用同步 helper + `errdefer` rollback。
- [x] async frame pool 与 scheduler 绑定，避免热路径 malloc。
- [x] 增加响应 body trait：static slice、arena bytes、file/sendfile。
- [x] 增加最大 header/body/form 限额并暴露配置。
- [x] 增加内存指标：arena used、frame alloc/free、heap fallback 次数。

注：当前实现里 `RequestArena` 采用作用域 `reset`/归还完成自动回收；语言层 `drop(self: T)` 限制使其没有单独暴露按值 `drop` 方法名。默认请求路径可通过 `ctx.request_arena` / `ctx.arena_alloc()` 使用 arena；若显式配置 engine allocator，则 `ctx.allocator` 保留该自定义 allocator。

## P5：HTTP 协议与 I/O 优化

- [x] 解析器 SIMD/word-at-a-time 扫描 CRLF、冒号、空格。
  当前已落地为 8-byte word-at-a-time 扫描；暂未引入平台相关 SIMD 指令分支。
- [x] Header name 小写/哈希缓存，常见 header 快速路径。
- [x] 响应使用 `writev` 合并 header/body，避免大 body 复制。
- [x] 静态文件使用 `sendfile` / `splice`。
  当前 Linux x86_64 优先 `sendfile`，其它路径安全回退到 nonblocking `read/write`；`splice` 暂无额外收益，先不引入。
- [x] 支持 chunked request/response。
- [x] 支持 TLS accept/serve，复用现有 `tls` 模块。
- [x] 评估 HTTP/2：优先 h2c/TLS ALPN 设计，不影响 HTTP/1 热路径。
  结论：
  1. `std.http` / `uyagin` 继续把 HTTP/1.1 parser 与 response builder 保持独立热路径，不在现有 `Request` / `GinContext` 上混入 h2 stream 状态。
  2. TLS 路径优先走 ALPN，在 `tls.https` 握手完成后基于协商结果分派 `http/1.1` 与未来 `h2` server。
  3. 明文路径若支持 HTTP/2，优先独立 h2c preface / upgrade 检测入口，不让 HTTP/1 parser 承担 frame 层分支。
  4. 当前版本先冻结为“HTTP/1.1 热路径 + TLS/ALPN 预留”，不在 P5 内引入 HTTP/2 frame / HPACK 实现。

## P6：可观测性与生产配置

- [x] Access log middleware：可关闭、可采样、零分配格式化。
- [x] Metrics middleware：请求数、状态码、延迟直方图、连接数。
- [x] Panic/error trace：结合 Uya 源码位置 builtin 输出。
- [x] 配置结构：backlog、max connections、buffer cap、timeouts、allocator。
- [x] 运行模式：debug/release，debug 开启更多边界检查和日志。

## P7：Benchmark 达标计划

### 基准场景

- [x] `hello plaintext`：固定 12B body，keep-alive。
- [x] `json small`：100B JSON。
- [x] `path param`：`/users/:id`。
- [x] `middleware x3`：logger disabled + recovery + auth stub。
- [x] `large body`：64KiB 响应。

### 对照条件

- [x] 同一台 Linux x86_64 机器。
- [x] 同一编译级别：Uya `-O2/-O3`，Gin 使用 `go build -ldflags="-s -w"`。
- [x] 同一工具：`wrk` 或 `wrk2`，固定线程/连接/持续时间。
- [x] 记录 CPU governor、内核版本、ulimit、somaxconn。
- [x] 每项至少 5 次，取 median 与 p99。

### 达标指标

#### 硬性通过条件

- [ ] 吞吐门槛：5 个基准场景都要求 `summary.csv.rps_ratio_vs_gin >= 1.20`，按每场景 5 次采样的 `median_rps` 判定，不接受只挑单次峰值或最优 run。
- [ ] 尾延迟门槛：5 个基准场景都要求 `summary.csv.p99_ratio_vs_gin <= 0.85`，按每场景 5 次采样的 `median_p99_latency_us` 判定，不用 avg/p50 替代。
- [ ] 分配门槛：5 个基准场景都要求 `summary.csv.uya_median_heap_fallback_delta == 0`，以 `/__uyagin/metrics` 中 `heap_fallback_count` 的 run 前后 delta 作为热路径是否仍有 heap fallback 的唯一口径。
- [ ] syscall 门槛：仅 `hello plaintext` 场景要求 `write_per_req <= 1.10` 且 `(read_per_req + epoll_wait_per_req) <= 1.50`；这是“接近 1 write + 摊销 read/epoll”的机器化近似，不用人工读 `strace` 摘要替代。
- [ ] 同 RPS CPU 门槛：仅 `hello plaintext` 场景要求 same-RPS CPU probe 双方都命中 `target_rps ±10%`，且 UyaGin `cpu_per_req_us < Gin`；默认目标 RPS 取 hello 场景双方 median RPS 的较小值再乘 `0.80`。
- [ ] 总判定：正式验收以 `report.json.overall_pass_target == true` 为总开关，同时要求 `summary.csv` 中所有场景 `overall_pass_target == 1`；任一场景任一硬门槛为 `0`，都不得把 P7 标记为达标。
- [ ] 辅助指标：`cpu_per_req_pass_estimate` 仅作为常规 `wrk` 轮次里的粗粒度参考，不单独作为 P7 验收依据。

#### 执行与证据

- [ ] 当前门禁状态：以 2026-04-25 HEAD 实测为准，`tests/verify_uyagin_http_bench_runtime.sh`（当前覆盖 `threads=1`）已恢复通过；正式 benchmark 仍必须先过这条语义门禁，不能跳过 runtime 校验直接引用性能数字。
- [ ] 统一执行命令：正式验收默认使用 `python3 benchmarks/run_uyagin_http_bench.py --fail-on-target`；若需要改 `runs/wrk_threads/connections/duration/server_threads`，必须先同步本文档与历史基线，再重新出完整报告。
- [ ] 统一默认参数：正式验收沿用 runner 默认值 `runs=5`、`wrk_threads=4`、`connections=64`、`duration=10s`、`server_threads=4`；其中 `connections > 64` 已超出当前 UyaGin 连接槽上限，不属于 P7 可比口径。
- [ ] 统一输出物：每次正式验收都要保留当次 `output_dir` 下的 `report.json`、`summary.csv` 与 `raw/` 原始结果；没有原始输出，不允许复用或转述“已达标”结论。
- [ ] 禁止跳项验收：正式达标结论不得基于 `--backend` 单边运行、`--scenario` 子集运行、`--skip-syscall-probe` 或 `--skip-cpu-probe`；这些模式只允许用于本地调优和缩小回归范围。
- [ ] 禁止 benchmark 专用快路径：当前 benchmark server 已切回官方 `engine.run_shards()` 主链路，后续性能收敛只接受 core 路径优化，不接受只在 benchmark binary 生效的特殊分支。

#### 反作弊约束

- [ ] 先校验语义，再看性能：任何正式性能数据都必须先通过 `tests/verify_uyagin_http_bench_runtime.sh`；若 `/plaintext`、`/json`、`/users/42`、`/middleware/ping`、`/blob64k` 的 body、`Content-Length`、状态码、keep-alive 或授权语义不一致，则该轮 benchmark 结果作废。
- [ ] 禁止挑样本：固定 5 次 run 全部纳入 `median_rps` / `median_p99_latency_us` 计算，不得手工删除慢样本、只截取最优 run、失败后反复重跑直到撞到“好看数字”再宣称达标。
- [ ] 禁止单边调参：UyaGin 与 Gin 必须使用同一组场景、同一 `wrk` 参数、同一请求头与同类编译级别；不得只对一边额外绑核、改单独线程数、改单独连接数、改单独持续时间、关额外运行时开销或施加退化配置。
- [ ] 禁止缩语义换吞吐：不得通过减少响应字节数、移除 middleware、放宽错误处理、跳过 header/协议语义、降低超时/限额约束、绕开正式执行链路等方式换取数字；任何会让 benchmark 请求不再代表真实框架语义的改动，都不计入 P7 成绩。
- [ ] 禁止改规则后复用旧结果：若 benchmark 场景、runner 字段、阈值、构建方式或统计逻辑发生变化，必须重新跑完整 UyaGin/Gin 对照并生成新的 `report.json` / `summary.csv`；旧报告不得继续作为当前口径的达标证据。

2026-04-25：已新增 `benchmarks/uyagin_http_bench.uya`、`benchmarks/uyagin_http_bench_gin/main.go`、`benchmarks/run_uyagin_http_bench.py` 与 `tests/verify_uyagin_http_bench_runtime.sh`。
当前 runner 会固定 5 次采样，导出 median / p99、环境信息、Uya heap fallback 指标，并在可用时追加 hello 场景 `strace` syscall 统计；同时新增 same-RPS CPU probe（内置 keep-alive paced client），可直接在报告里给出 `rps/p99/alloc/syscall/cpu` 的 pass/fail 字段，并支持 `--fail-on-target`。Gin 对照构建现已增加 `GOPROXY` fallback（优先 `https://goproxy.cn,direct`），并且在 server startup 失败时会直接输出 `server.log` 路径与退出信号，避免 runner 静默卡住。P7 是否达标，只以当次 `summary.csv` / `report.json` 的字段为准；缺少 Gin 对照、syscall probe、same-RPS CPU probe 或原始输出目录的结果，只能用于调优，不得用于对外宣称达标。

2026-04-25 修复更新：重新执行 `tests/verify_uyagin_http_bench_runtime.sh` 已通过。此前阻塞 benchmark runtime 的两类 C99 codegen 问题已修复：
1. `GinContext.param/query` 的 `HttpKvSlice` 切片表达式现在优先走 checker 推断类型，不再错误降成 `struct uya_slice_int32_t`。
2. `uyagin_ready_i32(...)` / `uyagin_ready_usize(...)` 这类 `!T` helper future 调用现在会按形参期望类型发射 `err_union_*` 实参，不再把 `error.X` 降成裸整数。

2026-04-25 实测补充：
1. 正式默认口径 `server_threads=4` 运行 `python3 benchmarks/run_uyagin_http_bench.py --scenario hello_plaintext --runs 1 --duration 1s --skip-syscall-probe --skip-cpu-probe` 时，Uya benchmark server 会在 `engine.run_shards()` 启动阶段 `SIGSEGV`，runner 现已能明确报出 `process exited via signal 11` 与对应 `server.log`；因此默认 4 线程正式 benchmark 目前仍被 multi-shard 回归阻塞。
2. 已补记一组当前 HEAD 的 single-shard smoke 指标：先通过 `tests/verify_uyagin_http_bench_runtime.sh`，再运行 `python3 benchmarks/run_uyagin_http_bench.py --scenario hello_plaintext --runs 1 --duration 2s --server-threads 1 --skip-syscall-probe --skip-cpu-probe`；产物位于 `build/uyagin_http_bench/20260425_232813/`，包含 `report.json`、`summary.csv` 与 `raw/` 原始 `wrk/server.log`。
3. 上述 smoke 报告对应机器信息为 `Linux 6.12.65-amd64-desktop-rolling`、`x86_64`、`Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz`、CPU governor=`performance`、`somaxconn=4096`、`ulimit -n=1048576`；执行参数为 `wrk_threads=4`、`connections=64`、`duration=2s`、`server_threads=1`、`runs=1`。
4. `build/uyagin_http_bench/20260425_232813/summary.csv` 记录的 `hello_plaintext` 指标为：`uya_rps=12539.27`、`gin_rps=41556.29`、`rps_ratio=0.3017`；`uya_p99_us=8640.0`、`gin_p99_us=3990.0`、`p99_ratio=2.1654`；`uya_cpu_per_req_us=79.3808`、`gin_cpu_per_req_us=24.1778`；`uya_heap_fallback_delta=0`、`alloc_pass_target=1`、`overall_pass_target=0`。
5. 由于本次只跑 `hello_plaintext` 且显式跳过 `syscall/cpu probe`，`syscall_pass_target` 与 `cpu_matched_pass_target` 仍为空；这组数字只能作为“single-shard smoke 已恢复”的指标记录，不能替代默认 4 线程、5 场景、5 次采样的正式 P7 验收结果。

结论：P7 当前状态应表述为“single-shard smoke benchmark 已恢复、默认 multi-shard 正式 benchmark 仍有运行时 blocker”；`rps/p99/alloc/syscall/cpu` 指标是否达标，仍必须以当次完整实测报告为准，上述“达标指标”继续保留为验收门槛，不在代码提交时预先勾选。

## P8：兼容性与文档

- [ ] 完整 API 文档：注册、上下文、错误、响应、生命周期。
- [ ] 迁移指南：Gin handler → UyaGin handler。
- [ ] 示例：hello、JSON、JWT、multipart、static file、middleware。
- [ ] 压测报告：包含命令、硬件、原始数据、火焰图。
- [ ] 编译器边界清理：继续随着 Uya C 后端修复删除 UyaGin 中的兼容层 / workaround；当前状态见 [`compiler_bug_report_2026-04-25_uyagin_async.md`](./compiler_bug_report_2026-04-25_uyagin_async.md)。
  当前报告已同步到：direct err-union await bind、文件发送路径 lowering 缺口、Header 缓存兼容回退，以及 benchmark runtime 的 `HttpKvSlice` 切片 lowering / `!T` helper future 实参 lowering 问题均已修复；parser 对 `catch { ... }` 的假性“意外 token”诊断仍待清理。
