# 类型化管道 TODO

**状态**：可执行 TODO，规划中
**更新日期**：2026-07-10
**配套设计**：[`typed_pipeline_design.md`](typed_pipeline_design.md)
**相关设计**：[`std_script_design.md`](std_script_design.md)

## 定位

类型化管道为 `.ush` 脚本提供 shell 管道之外的结构化替代方案。它应建立在 `std.process` 和宿主抽象工作之上，而不是变成另一套 shell 实现。

实现应按小阶段推进。第一个可用里程碑应能在没有 shell 字符串的情况下运行简单 argv 管道；自定义 Uya 流 stage 可以在 process-only 管道稳定后再跟进。

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `Interrupted`
  - [ ] `PipelineSpawnFailed`
  - [ ] `PipelineStageFailed`
- [ ] 定义 checked sink 在非零退出时是否默认返回 `error.ProcessFailed`。
- [ ] 定义失败详情通过 `check_into`、`status_into`、`capture_into`、`capture_limit_into` 返回，不依赖 Uya error payload。
- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [ ] per-stage `not_started`
  - [ ] per-stage `spawn_failed`
  - [ ] per-stage `cancelled`
  - [ ] per-stage `exited(exit_code: u32)`；POSIX 0..255 扩宽，Windows `DWORD` 原样保存
  - [ ] per-stage `signaled(signal)`
  - [ ] process `spawn_failed` 保存稳定的 `PipelineSpawnFailureKind` 与可选平台错误码
  - [ ] Uya stage `completed`
  - [ ] Uya stage `stage_failed(error_name)`
  - [ ] `stage_count` 与 statuses 覆盖完整可执行 stage 列表，`stage_index` 不因混合 stage 压缩
  - [ ] `PipelineResult` 只保存 `stage_count` 摘要，不保存指向调用方 status 缓冲区的 slice/pointer
  - [ ] `stage_count(&Pipeline) !usize` 在 sink 前提供不消费、不执行的精确容量查询，无效 capability 返回 `InvalidPipeline`
  - [ ] `CaptureStreamResult.captured`
  - [ ] `CaptureStreamResult.byte_count`
  - [ ] `CaptureStreamResult.complete`，只有观察到 EOF 才为 true，normal cutoff 必须显式为 false
  - [ ] capture result 只记录 stdout/stderr 已写入长度，调用方通过自己的缓冲区和长度取得有效前缀，不建立跨参数借用
  - [ ] 后续按值 facade 使用独立的 `OwnedPipelineResult` / `OwnedPipelineCaptureResult` 或不透明 handle，不复用仅含长度的摘要类型
- [ ] 锁定 checked/observing sink 分层：
  - [ ] `check()`：pipefail，非零返回 `error.ProcessFailed`
  - [ ] `check()`：启动失败返回 `error.PipelineSpawnFailed`
  - [ ] `check_into(statuses, result)`：固定 all-stage/pipefail，返回 `ProcessFailed` / `PipelineSpawnFailed` / `PipelineStageFailed` 前写入完整 `PipelineResult`
  - [ ] `status_into(statuses, result)`：观察型，非零、signal、启动失败和 Uya stage 错误不作为 sink 自身的 Uya error
  - [ ] `capture_into(statuses, stdout_buf, stderr_buf, result)` / `capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)`：观察型，结果中包含完整 `PipelineResult`
- [ ] 锁定 capture sink 语义：
  - [ ] `capture_into()` 隐式捕获 terminal stdout
  - [ ] stderr 只有显式 `stderr_capture()` 或 `stderr_to_stdout()` 后才进入返回值
  - [ ] 显式 stdout file/inherit 后调用 `capture_into()` / `capture_limit_into()` 报 `InvalidPipeline`
  - [ ] capture policy 与 `check` / `check_into` / `status_into` 组合报 `InvalidPipeline`
- [ ] 锁定 `CaptureLimitExceeded`：超限后 POSIX 同时终止 process group 与全部直接 PID，Windows 终止 Job Object；取消路径关闭 capture 读端、不得无限 drain 或等待逃离后代持有的 pipe EOF，完成直接 stage 的 reap 后重置输出 result 为空摘要并返回普通 Uya error。
- [ ] 锁定空 result 摘要的字段值：`PipelineResult.stage_count=0`；`PipelineCaptureResult` 还需把 stdout/stderr 置为 `captured=false`、`byte_count=0`、`complete=false`。
- [ ] 锁定正常完成只等待直接 stage：全部直接 stage reap 后做有界非阻塞 capture 收尾并关闭读端，不等待/终止非直接后代；只有 EOF 设置 `complete=true`，EAGAIN/预算 cutoff 必须返回 `complete=false`。
- [ ] 锁定 caller-provided `statuses` / stdout / stderr / result writable region 必须两两不重叠；重叠在任何文件打开或 stage 启动前返回 `InvalidPipeline`。
- [ ] 锁定 capture exact-fit 探测：达到有效上限但尚未 EOF 时使用独立一字节 scratch；EOF 成功、读到额外字节返回 `CaptureLimitExceeded`，不得停止 drain 后等待 child。
- [ ] 锁定 `capture_into()` 使用调用方缓冲区容量作为上限，`capture_limit_into()` 在缓冲区容量之外额外施加 `max_bytes`，不引入隐藏默认上限常量。
- [ ] 锁定 `stdout_file` / `stderr_file` 为 stream policy transformer，不作为 sink。
- [ ] 锁定空 pipeline 传给任何 sink 返回 `error.InvalidPipeline`。
- [ ] 锁定 `inherit_stdio` 是显式策略而不是 reset，和已有 terminal policy 冲突。
- [ ] 锁定所有 sink 对 unset stdin 默认使用 inherit。
- [ ] 锁定 `cwd` / `env` / `unset_env` 作用于最近追加的 process stage。
- [ ] 锁定所有 stage 使用同一个 sink-time canonical base-env 快照；overlay 按调用顺序决议，PATH 查找与 spawn 使用同一最终 env block。
- [ ] 锁定 POSIX env key 按 byte 区分、Windows env key 按 ordinal case-insensitive 合并且最终 UTF-16 block 使用同一比较规则排序；大小写变体不能重复传给 child。
- [ ] 锁定 `env` / `unset_env` 复用 `std.env` 的 key/value 校验并在 transformer 阶段复制数据。
- [ ] 锁定相对 `cmd_path` 按该 stage 最终 cwd 解释，而不是按 transformer 调用时的父进程 cwd 解释。
- [ ] 锁定 Windows drive-relative path（例如 `C:foo`）对 `cmd_path`、`cwd` 和 file redirection 均为 `InvalidPipeline`；只接受明确 absolute 或普通 relative 形式。
- [ ] 锁定 sink 开始时捕获宿主 cwd 快照；相对 stage cwd 与 stdin/stdout/stderr file path 都按该快照解释，file path 不跟随 stage-local cwd。
- [ ] 锁定同一 stage 多次 `cwd()` 时最后一次覆盖前一次，不做相对前值的链式拼接。
- [ ] 锁定 terminal stdout/stderr 策略与 inter-stage pipe 的边界。
- [ ] 锁定整条 pipeline stderr 策略是 shell group 级语义，不是 per-stage stderr 数据流。
- [ ] 锁定 `cmd` 的 PATH-searching 语义，并提供 exact-path API `cmd_path`。
- [ ] 锁定 `cmd` 只接受不含路径分隔符的命令名；路径执行必须使用 `cmd_path`。
- [ ] 锁定 `cmd` PATH 查找复用 `std.process` / `std.path` 平台 helper，不在 executor 内重复实现。
- [ ] 先定义可由 pipeline 复用的 PATH helper，例如 `process_resolve_path(program, env, cwd)` 或等价接口。
- [ ] 锁定 PATH 缺失、空/相对 component、Windows `.exe` fallback、无隐式 PATHEXT/`cmd.exe` 和 lookup/spawn 失败分类。
- [ ] 锁定错误分类：API 误用返回 `InvalidPipeline`；stage 启动链路失败和 Uya stage 错误进入 `PipelineResult`；文件重定向、pipe、内存、编码转换等执行器资源失败返回普通 Uya error；executor 自身收到未忽略的取消信号返回 `Interrupted`。
- [ ] 决定 `cmd` 使用 Uya 裸变参 `...` 加 `@params` 校验，还是使用基于 slice 的 `cmd_argv` API。
- [ ] 若开放裸变参 `cmd(input, program, ...)`，明确 `@params` 包含固定参数，必须跳过 `input` / `program` 后校验剩余 argv。
- [ ] MVP 优先考虑 `cmd_argv` / `cmd_path_argv` 基础 API，裸变参只作为 facade。
- [ ] 锁定公开 `Pipeline` 必须依赖真正 opaque / non-copyable 类型能力；导出普通 struct/raw pointer handle 不得作为稳定 API。
- [ ] 若内部 bring-up 使用 capability handle，必须使用 generation 校验与私有注册表，并拒绝伪造、过期和重复消费；公开 API 仍等待 opaque 类型。
- [ ] 锁定 transformer/sink 在所有返回路径上消费 input，失败路径释放计划；未进入 sink 的 live pipeline 离开作用域时自动 drop。
- [ ] 决定 `_` pipeline 占位符语法糖是延期，还是作为显式 parser/checker 工作实现。
- [ ] 明确 process-only MVP 不包含自定义 Uya stage；Uya stage 需等待 owned-data 与满足取消/终止门槛的 execution domain 方案。
- [ ] 锁定 POSIX process group 通过 parent/child 双侧 `setpgid`、per-child startup-report/launch pipe 与显式 `RUN`/`ABORT` protocol 建立；EOF 必须 abort，不能释放 child；不得用无法识别 token 接收者的共享 launch pipe。
- [ ] 锁定每个 POSIX child 在 READY 前关闭所有无关控制/数据/runtime-broker fd，parent 在最后一个继承者 fork 后立即关闭对应 child-only fd，发送 RUN 前不再持有 capture writer。
- [ ] 锁定所有 POSIX 内部 control/data/file source fd 避开 0/1/2，或实现循环安全 remap 与 `source == target` 的 `FD_CLOEXEC` 清理；不能假设宿主标准 fd 已打开。
- [ ] 锁定 controlling terminal 只有在 executor 当前就是前台 process group 时才转交/恢复 PGID；后台 executor 不得抢占终端，终止信号仍需转发。
- [ ] 锁定 Windows child 必须 suspended 创建、加入 Job Object 后才能恢复，并使用严格 handle allowlist；默认 direct-stage 模式不使用 kill-on-close，取消显式终止 Job。
- [ ] 锁定平台中立执行释放边界：POSIX 为消费 RUN，Windows 为 primary thread 成功 resume，未来 Uya stage 为开始调用 `run`；未越过为 `not_started`，已释放后被 executor 强制终止为 `cancelled`，不声称用户指令已经实际运行。
- [ ] 锁定信号/console cancellation 由 runtime broker 唤醒正常 executor 路径，去重转发、有限取消、清理后返回 `error.Interrupted`；异步 handler/callback 不执行复杂清理。
- [ ] 锁定 runtime broker 用订阅/引用计数协调并发 sink；进程定向信号通知全部活跃 sink，最后一个订阅者只能在仍拥有 disposition 时恢复原 handler，等待 terminal lease 前必须先完成订阅。
- [ ] 锁定 fork child 在 READY 前移除 sink 临时 signal mask/disposition 与 broker fd；launch token 写入必须以 per-thread mask 处理 `SIGPIPE`，不能永久改变进程级 disposition。
- [ ] 锁定同步 sink 观察 stopped direct child；当前无 job-control 模式将 stop 收敛为终端恢复、整组强制取消、reap 和 `error.Interrupted`。
- [ ] 锁定按 terminal identity 串行化的 interruptible foreground lease；所有返回路径都先恢复终端再释放 lease，避免并发 sink 的 `tcsetpgrp` 竞态。
- [ ] 锁定 Uya stage 只有具备内存安全的强制 task 终止或隔离 worker process 时才能继承有限取消承诺；单纯 cancellation flag + join 不足。

## 阶段 1：Lexer 与 Parser 骨架

- [ ] 添加 `|>` token。
- [ ] 确保 `|>` 在单字符 `|` 和 `>` 之前识别。
- [ ] 添加左结合 pipeline expression 的 parser 支持，优先级低于当前 parser 中最低的非赋值表达式层级、高于赋值；实现前同步 formal grammar 中缺失的位或层级。
- [ ] 第一版将右侧限制为最外层是 call 的 postfix expression。
- [ ] parser MVP 保持空 pipeline 构造显式；暂不特殊处理 `_`。
- [ ] 添加 parser 正向测试：
  - [ ] `pipeline() |> cmd("a") |> cmd("b") |> stdout_file("out") |> check()`
  - [ ] `x = pipeline() |> cmd("a")`
  - [ ] `pipeline() |> script.cmd("a")`
  - [ ] 允许的泛型 callee 形式
  - [ ] 必要时支持带括号的左侧表达式
  - [ ] 多行格式
- [ ] 添加 parser 负向测试：
  - [ ] `pipeline() |> y + z`
  - [ ] EOF 处不完整的 `|>`
- [ ] parser 行为稳定后更新 grammar 文档。

## 阶段 2：Type Checker 规则

- [ ] 添加 checker 可识别的 `Pipeline` 类型身份。
- [ ] checker 按 canonical 声明身份识别 `Pipeline`，不得仅比较未限定类型名字符串。
- [ ] 强制 `|>` 左侧为 `Pipeline` 或 `!Pipeline`。
- [ ] 强制右侧 callee 的首个参数为 `Pipeline`。
- [ ] 仅为 `|>` 添加 `!Pipeline` try-forward 语义。
- [ ] 拒绝对非 `Pipeline` 值使用通用数据管道。
- [ ] 拒绝 sink 之后继续链式管道，因为左侧不再是 `Pipeline`。
- [ ] MVP 拒绝把带隐式 `self` receiver 的实例方法调用用作 `|>` 右侧；module-qualified 和无 receiver 静态调用继续支持。
- [ ] 添加诊断：
  - [ ] 左侧不是 `Pipeline`
  - [ ] 右侧不是调用表达式
  - [ ] 首个参数不是 `Pipeline`
  - [ ] sink 后继续管道的误用
  - [ ] 实例方法 receiver 与 synthetic lhs 冲突
- [ ] 添加 `1 |> cmd("x")` 的 checker 负向测试。
- [ ] 添加 `!Pipeline |> transformer` 的 checker 测试。
- [ ] 添加 checker 测试证明非 `Pipeline` 的 `!T` 不会得到 try-forward。
- [ ] 添加 checker 测试证明 `!Pipeline` 成功载荷只能提取并移动一次。

## 阶段 3：Lowering

- [ ] 将 `lhs |> f(args...)` 降低为普通调用和临时变量。
- [ ] 保留 `Pipeline` 的移动语义。
- [ ] transformer lowering 的成功路径转移所有权，错误路径触发输入计划清理。
- [ ] 以和普通 `try` 一致的方式降低 `!Pipeline` try-forward。
- [ ] `!Pipeline` try-forward 使用 AST/临时变量语义实现，不通过文本级 `f(try lhs, ...)` 重新解析。
- [ ] 确保诊断源位置指向有用 span。
- [ ] 为以下场景添加 lowering snapshot 或等价内部 dump：
  - [ ] 单个 transformer
  - [ ] 多个 transformer
  - [ ] 最终 sink
  - [ ] `!Pipeline` try-forward

## 阶段 4：`std.process.Pipeline` MVP

- [ ] 先实现并验证真正的 opaque/non-copyable type checker、C99 codegen、exec lowering 和 drop 支持。
- [ ] 添加由 `std.process` 拥有且字段不可见、不可构造、不可浅拷贝的公开 `Pipeline` 表示。
- [ ] 将 `|>` 绑定到该 canonical `Pipeline` 声明身份。
- [ ] 内部 capability bring-up 若先行，只能使用 generation 校验注册表，不能作为稳定公开类型。
- [ ] 添加 pipeline 自动 drop；覆盖未执行离开作用域、transformer 失败和 sink 失败路径。
- [ ] 添加进程 stage 计划存储。
- [ ] 添加包含 `cancelled` 和 `exit_code: u32` 的 `PipelineStageStatus`、`PipelineSpawnFailureKind`、`PipelineResult`、带 `complete` 的 `CaptureStreamResult` 与 `PipelineCaptureResult` 表示。
- [ ] 为 statuses/capture 实现调用方缓冲区写入；result 仅返回 `stage_count` / `byte_count` / `complete` 摘要，不保存调用方 buffer 借用；statuses 容量按完整可执行 stage 数量校验。
- [ ] 添加 `stage_count(input: &Pipeline) !usize`，保证不消费、不执行、不缓存 execution state，无效 capability 返回 `InvalidPipeline`；statuses 容量检查早于文件打开或进程启动。
- [ ] 添加 owned argv 存储。
- [ ] 为 process stage 添加 execution-time `exec_path` 存储或等价临时结构；不要把解析结果持久化到可 clone 的 plan。
- [ ] 添加 cwd override 存储。
- [ ] 添加 env overlay 存储。
- [ ] sink 开始时捕获一次 canonical base env；为每个 stage 按顺序应用 overlay/remove，并让 PATH helper 与 spawn 共用同一 env block。
- [ ] `env` / `unset_env` 复用 `EnvInvalidName` / `EnvInvalidValue` 校验，计划保存 key/value 副本。
- [ ] 添加 stage-local modifier 校验：`cwd/env/unset_env` 只能作用于最近 process stage。
- [ ] 添加 stream policy 存储：
  - [ ] stdin unset/file/inherit
  - [ ] stdout unset/inherit/file/capture
  - [ ] stderr unset/inherit/file/capture/merge_stdout
- [ ] 添加 stream policy 冲突校验。
- [ ] 添加 `pipeline() Pipeline` 或选定的空构造器。
- [ ] 添加 `cmd_argv(input: Pipeline, program: &const byte, args: &[&const byte]) !Pipeline` 或选定的等价基础 API。
- [ ] 若添加 `cmd(input: Pipeline, program: &const byte, ...) !Pipeline` facade，跳过固定参数后校验 `@params` argv 类型。
- [ ] 校验 `cmd` 命令名非空且不含路径分隔符；违反时返回 `error.InvalidPipeline`。
- [ ] 添加 `cmd_path_argv(input: Pipeline, path: &const byte, args: &[&const byte]) !Pipeline` 或选定的 exact-path 基础 API。
- [ ] 实现相对 `cmd_path` 按 stage 最终 cwd 解释的语义。
- [ ] 在 sink 开始时捕获一次 cwd；实现相对 stage cwd 与 stream file path 的统一解析规则。
- [ ] 在语义预检中拒绝 Windows drive-relative command/cwd/file path。
- [ ] 定义并实现 `cmd` 的 PATH 查找使用 stage 最终 child env，且复用 `std.process` / `std.path` helper。
- [ ] 在 pipeline executor 前实现并测试 PATH helper，避免 executor 内私有 PATH 搜索逻辑。
- [ ] PATH helper 覆盖 PATH 缺失、空/相对 component、POSIX executable non-directory、Windows exact/`.exe` 查找以及 lookup 与 spawn 错误分类。
- [ ] 添加 `stdin_file`、`stdout_file`、`stderr_file`。
- [ ] 添加 `stdout_capture`、`stderr_capture`、`stderr_to_stdout`。
- [ ] 添加 `inherit_stdio` stream transformer。
- [ ] 添加 `check`、`check_into`、`status_into`、`capture_into` 和 `capture_limit_into`。
- [ ] 为所有 `*_into` sink 添加 caller writable-region 容量与两两不重叠预检，失败时在外部副作用前返回 `InvalidPipeline` 并清空 result。
- [ ] 添加显式 `clone(input: &Pipeline) !Pipeline`。
- [ ] `clone` 对包含不可克隆 erased stage 的计划返回 `error.InvalidPipeline`。

## 阶段 5：POSIX 仅进程 Executor

- [ ] spawn 前构造每个 process stage 的最终 argv/env/cwd。
- [ ] spawn 前解析所有 `cmd` stage 的 PATH；失败时不启动任何子进程，并写入 `spawn_failed` / `not_started` 状态。
- [ ] 对 stage cwd 失败写入 `spawn_failed` / `not_started` 状态。
- [ ] 对文件重定向打开失败、pipe 创建失败、内存分配失败返回普通 Uya error。
- [ ] 所有 PATH/cwd/buffer 预检和 pipe/control-fd 创建成功后、首个 fork 前，在 parent 中为每个活跃 file-redirection policy 打开一次文件；group stderr 的同一 open file description 供全部 stage 共享。
- [ ] 按 stdin/stdout/stderr 固定顺序和文档化平台 flags 打开重定向；后续 open 失败时关闭资源但不声称回滚已经发生的 create/truncate 副作用。
- [ ] PATH/stage 预检通过后再创建所有 stage 间 pipe。
- [ ] 为每次 POSIX pipeline 执行创建独立 process group；child/parent 双侧调用 `setpgid`，每个 child 通过独立 startup-report pipe 发送 `READY` 并等待自己的 launch pipe token。
- [ ] fork 前把所有内部 control/data/file source fd 移到 0/1/2 之外并配置正确 close-on-exec；child 在 READY 前关闭其他 stage 控制端、parent-only 端、runtime broker fd 和无关数据 pipe，parent 在最后一个继承者 fork 后立即关闭对应 launch/report/data/file 副本。
- [ ] 定义 per-child launch pipe：只有 `RUN` 允许继续，`ABORT`/EOF/短读/未知 token 必须 `_exit`；全部 READY 前不得发送 RUN。
- [ ] 为 parent 的 RUN/ABORT 写入实现 per-thread `SIGPIPE` 屏蔽、pending-signal 精确消费、EINTR 重试和 exact-token/`EPIPE` 处理；不得永久忽略进程级 `SIGPIPE`。
- [ ] 任一 fork/setpgid/barrier 失败时向尚未释放的 child 发送 ABORT 或关闭其 launch pipe，终止 group 与每个直接 PID并 reap；关闭 pipe 不得被解释为 release。
- [ ] inherit stdio 指向 controlling terminal 且 `tcgetpgrp(tty) == getpgrp()` 时才在 RUN 前 `tcsetpgrp` 到 pipeline PGID，并只在确实转交后恢复保存的前台 PGID。
- [ ] runtime broker 在等待 foreground lease 前注册 sink；按 terminal identity 独占 lease，所有正常/失败/中断路径在恢复终端后释放 lease并注销 broker。
- [ ] executor 已在后台时保持后台语义，不忽略 `SIGTTOU` 抢占终端；`tcgetpgrp`/`tcsetpgrp` 失败在 RUN 前走 ABORT 与普通 Uya error 路径。
- [ ] signal handler 只写原子标志/self-pipe；正常等待路径向 group 转发一次信号，只对 `getpgid(pid) != pipeline_pgid` 或无法证明仍在 group 的直接 PID 补发，bounded grace 后强制取消并返回 `error.Interrupted`。
- [ ] 保存/恢复既有 signal disposition/mask，保持 `SIG_IGN`，自定义 handler 由 runtime signal broker 统一协调。
- [ ] child 在 READY 前关闭 broker fd、恢复 sink 前调用线程 mask；broker 管理的 signal 若原为 `SIG_IGN` 则保持，否则改为默认 disposition，失败通过 `signal_setup` startup phase 回传。
- [ ] wait loop 使用 `WUNTRACED`/必要的 `WCONTINUED` 观察 stopped direct child；任一 stop 都恢复终端、强制取消整组、reap 并返回 `error.Interrupted`。
- [ ] wait 前 spawn 所有 process stage。
- [ ] 对 stdin/stdout/stderr 使用 source fd > 2 的安全 `dup2`；若采用通用 remap，覆盖 source/target 环和 `source == target` 时的 `FD_CLOEXEC` 清理。
- [ ] 保持 child 的 fd 关闭逻辑在 READY 前完成；`dup2` 后再关闭本 stage 为 stdio setup 临时保留的数据 fd 和 launch fd，仅让 startup-report writer 依靠 close-on-exec 结束成功诊断。
- [ ] 为每个 child 实现固定大小、单次 async-signal-safe write 的 startup diagnostic record，包含 `READY|FAILED`、setup phase 与平台码，并让 report pipe 在 exec 成功时 close-on-exec。
- [ ] 为 child-side `setpgid`、barrier、chdir、三路 `dup2` 和 `execve` 失败回传精确 phase；不得只回传裸 errno。
- [ ] 最后一个继承者 fork 后立即关闭父进程对应的 data/file fd；全部 READY 后、任何 RUN 前断言 parent 不再持有 child-only control/data fd 或 capture writer。
- [ ] 在子进程执行期间并发驱动有界 stdout/stderr capture reader。
- [ ] 仅在 pipe ownership 和 reader 状态不可能死锁后等待子进程。
- [ ] 正常路径在全部直接 child reap 后做有界非阻塞最终 drain，到 EAGAIN/EOF/预算耗尽即关闭 capture 读端，不等待非直接后代；仅 EOF 返回 `complete=true`，其他 cutoff 返回 `complete=false`。
- [ ] 收集每个 stage 的状态。
- [ ] `spawn_failed` 写入稳定 `spawn_failure` 类别以及 diagnostic pipe/平台 bridge 返回的原始平台码。
- [ ] 实现 checked sink 的 pipefail 行为。
- [ ] `check_into` 在返回 `error.ProcessFailed` 或 `error.PipelineSpawnFailed` 前写入完整 `PipelineResult`。
- [ ] 将 `status_into()` 实现为观察型 sink：非零退出、signal、启动失败不失败。
- [ ] 将 `capture_into()` / `capture_limit_into()` 实现为观察型 sink：非零退出、signal、启动失败不失败且结果包含 `PipelineResult`。
- [ ] observing capture 在预检 spawn failure 时仍对启用流返回 `captured=true, byte_count=0, complete=false`；部分启动取消只在实际观察到 EOF 时返回 `complete=true`。
- [ ] 实现有界 stdout/stderr capture。
- [ ] capture 达到有效上限时使用一字节 scratch probe，覆盖 0 容量以及 exact N / N+1 输出，不能因剩余容量为 0 停止读取并死锁。
- [ ] event loop 在取消前锁存 terminal cause；同批次 interruption/stopped 优先，后续 cleanup signal 不覆盖已经锁存的 capture/基础设施错误。
- [ ] `capture_limit_into` 超限时对 process group 和全部直接 PID 强制终止，关闭 capture 读端且不等待 EOF，reap 直接 child、重置输出 result 为空摘要，并返回 `error.CaptureLimitExceeded`。
- [ ] 部分启动后发生 spawn/infrastructure 错误时复用同一整组取消路径，不能等待 stage 自然退出。
- [ ] 添加输出大于 pipe buffer 的死锁回归测试。
- [ ] 添加测试：
  - [ ] `printf | wc`
  - [ ] 三阶段 pipeline
  - [ ] stdout 文件 sink
  - [ ] stderr 文件 sink
  - [ ] stderr capture
  - [ ] stderr to stdout merge
  - [ ] `cmd("a/b")` 返回 `error.InvalidPipeline`
  - [ ] 缺失命令
  - [ ] child-side exec 失败诊断
  - [ ] PATH/cwd/permission/process-create/exec 失败写入不同 `PipelineSpawnFailureKind`
  - [ ] 相对 `cmd_path` 搭配 `cwd()`
  - [ ] 相对 `cwd()` 与 file stream path 使用同一 sink-time cwd 快照
  - [ ] 文件重定向打开失败返回普通 Uya error
  - [ ] 多 stage group stderr file 只 open/truncate 一次，不因每个 stage 重复打开而覆盖输出
  - [ ] 宿主 0/1/2 任一路预先关闭时，pipe/file stdio remap 仍正确且 exec 后目标 fd 不带 `FD_CLOEXEC`
  - [ ] parent 在 RUN 前关闭所有 child-only pipe writer，`printf | wc` 不会因 parent 持有写端而等待 EOF
  - [ ] child 在 READY 前不会继承 runtime broker handler/self-pipe 或 sink 临时 signal mask
  - [ ] launch reader 提前关闭时 RUN/ABORT 写入返回可处理的 `EPIPE`，executor 不被 `SIGPIPE` 终止
  - [ ] signal 终止状态
  - [ ] executor 收到 SIGINT/SIGTERM 时不重复投递给仍在 group 的 PID，有限清理并返回 `error.Interrupted`
  - [ ] `stdout_file(...) |> capture_into(...)` 冲突
  - [ ] `stderr_capture() |> status_into(...)` 冲突
  - [ ] 第一 stage 非零退出
  - [ ] 最后一 stage 非零退出
  - [ ] 忽略 `SIGPIPE` 并持续输出的程序在 capture 超限后仍能被有限终止
  - [ ] 直接 stage 调用 `setsid` 逃离 group 后仍会被按 PID 终止并 reap
  - [ ] 逃离后代持有 capture 写端时取消路径不会等待 EOF
  - [ ] 正常完成时后代持续持有/写入 capture pipe 也不会阻止 sink 返回，后代后续 bytes 不进入结果
  - [ ] 未观察到 capture EOF 时 `complete=false`，不会静默报告完整输出
  - [ ] capture 有效上限为 N 时覆盖 N-1、N、N+1 字节；N 正常完成，N+1 有限取消并返回 `CaptureLimitExceeded`
  - [ ] stdout/stderr/statuses/result writable region 重叠时在启动前返回 `InvalidPipeline`
  - [ ] 终端继承下读取 stdin 不会因后台 process group 收到 `SIGTTIN`，完成后恢复父前台 PGID
  - [ ] executor 自身位于后台 process group 时不会调用 `tcsetpgrp` 抢占前台终端
  - [ ] 前台 child 收到 Ctrl-Z/SIGTSTP 或后台 child 收到 SIGTTIN 时，sink 恢复终端、有限取消并返回 `Interrupted`，不会永久等待 stopped child

## 阶段 6：自定义 Uya 流 Stage

阶段 6 必须在 process-only pipeline 稳定后开始；默认实现不使用 fork-backed Uya stage。

- [ ] 添加 `StreamReader`。
- [ ] 添加 `StreamWriter`。
- [ ] 定义 stage 函数的阻塞 read/write 语义。
- [ ] 定义 EOF 行为。
- [ ] 添加 `PipelineStage` 接口：

```uya
interface PipelineStage {
    fn run(self: &Self, input: &StreamReader, output: &StreamWriter) !void;
}
```

- [ ] 添加 `stage<T: PipelineStage>(input: Pipeline, stage: T) !Pipeline`。
- [ ] 在 pipeline 计划中按值存储 stage 对象，并拒绝未拥有的内部借用。
- [ ] 定义含 slice/pointer/interface 字段的 stage owned-data 规则。
- [ ] 添加 erased thunk 表示或等价单态化存储：
  - [ ] `run_fn`
  - [ ] `clone_fn`
  - [ ] `drop_fn`
- [ ] 选择满足有限终止门槛的 Uya-stage execution domain：内存安全的强制可取消 runtime task，或可强制终止的隔离 worker process；不能只假设普通 thread + cooperative flag。
- [ ] 让 Uya stage 成功写入 `completed`，错误写入 `stage_failed(error_name)`；`stage_index` 使用完整 stage 列表索引。
- [ ] checked sink 遇到 `stage_failed` 返回 `error.PipelineStageFailed`，observing sink 保留状态并成功返回。
- [ ] 若 runtime task 路线成立，证明阻塞 StreamReader/Writer 和 CPU-bound stage 都能安全终止；否则把有限取消后端收敛到隔离 worker process，并将普通 thread 路线标记为实验性协作取消。
- [ ] 若保留 fork-backed 实验路径，必须显式标记为非默认测试/实验模式。
- [ ] 添加测试：
  - [ ] line filter stage
  - [ ] line map stage
  - [ ] 两个外部命令之间的 stage
  - [ ] stage 错误传播
  - [ ] 大输入流式处理，不全量缓冲

## 阶段 7：Script Facade 集成

- [ ] 如合适，通过 `std.script` 重新导出常用 API。
- [ ] 在脚本文档中添加示例。
- [ ] 将一个简单 `.ush` 验证脚本从 `system("... | ...")` 迁移出去。
- [ ] 添加与旧 shell 命令并列的行为 oracle。
- [ ] 保持显式 shell fallback API 独立且命名清晰。

## 阶段 8：Windows Hosted 后端

- [ ] 将 process stage 映射到 `CreateProcessW`。
- [ ] 每次执行先创建用于显式取消的 Job Object；默认 direct-stage 模式不设置 `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`，避免正常关闭 handle 隐式终止非直接后代。
- [ ] 在首个 CreateProcess 前完成 pipe、每个 file-redirection policy 的单次 parent-side `CreateFileW` 和严格 handle allowlist；group stderr handle 由全部 stage 共享，最后一个继承者创建后关闭 parent 副本。
- [ ] child 使用 `CREATE_SUSPENDED` 创建，成功 `AssignProcessToJobObject` 后才允许恢复执行；全部 child 入 job、parent 关闭所有 child-only/capture-writer handle 后逐个恢复所有 primary thread，成功 resume 是 Windows 执行释放边界。
- [ ] 分别跟踪 `created_unassigned`、`assigned_suspended`、`resumed`；创建、assignment 或 resume 失败时对未入 Job child 调用 `TerminateProcess`，对已入 Job child 调用 `TerminateJobObject`，等待全部 direct process 后再关闭 handle；未 resume stage 为 `not_started`，已 resume 但被终止的 stage 为 `cancelled`。
- [ ] 为 pipe 实现 handle 继承/复制，并通过 `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` 或等价严格 allowlist 防止无关 child 继承多余 pipe 端。
- [ ] capture 超限和部分启动失败使用 `TerminateJobObject` 或等价整组终止；宿主 job policy 不允许 assignment 时必须在 child 恢复前稳定失败。
- [ ] console-control callback 只通知 runtime broker；正常 executor 路径终止 Job、清理并返回 `error.Interrupted`。
- [ ] Windows console broker 对并发 sink 使用安全订阅表并广播 process-directed cancellation，注销后 callback 不得访问已释放 execution state。
- [ ] Windows wait 结果把完整 `GetExitCodeProcess` `DWORD` 保存为公共 `u32 exit_code`，覆盖高位为 1 的退出码。
- [ ] 在不假设 POSIX fd 的情况下实现 stdout/stderr capture。
- [ ] 使用 UTF-8 公共 API 和 UTF-16 bridge 实现 cwd/env 转换。
- [ ] Windows env overlay 以 ordinal case-insensitive key 规则去重，最后 spelling/value 获胜，最终 UTF-16 environment block 同序排序并双 null 结尾。
- [ ] 明确 argv 到 Windows command line 的 quoting 规则，且不隐式调用 `cmd.exe`。
- [ ] 决定自定义 Uya stage 在 Windows 上如何运行：
  - [ ] 复用阶段 6 已证明满足强制终止门槛的 runtime task 或隔离 worker process
  - [ ] 不假设 fork 语义
- [ ] 添加 Windows hosted smoke 测试：
  - [ ] 两阶段 pipeline
  - [ ] stdout 文件 sink
  - [ ] stderr capture
  - [ ] 非零 stage 结果
  - [ ] `AssignProcessToJobObject` 失败不会遗留 suspended child，且 `CloseHandle` 不被误当作终止操作
  - [ ] 高位 Windows exit code（例如 `0xffffffff`）按 `u32` bit pattern 无损返回

## 阶段 9：文档与稳定性门禁

- [ ] 如果本工作成为标准脚本路线图的一部分，更新 `todo_std_script.md`。
- [ ] 为 `|>` 更新 grammar 文档。
- [ ] 向用户文档添加示例。
- [ ] 添加迁移说明：使用类型化管道替代 `system("a | b")`。
- [ ] 添加已知限制章节：
  - [ ] 无 shell globbing
  - [ ] 无命令替换
  - [ ] `cmd` 只做显式 PATH-searching；`cmd_path` 不查 PATH；两者都不做 shell 展开
  - [ ] capture 限制
  - [ ] 平台后端状态

## 验收标准

- [ ] `|>` 只适用于 `Pipeline` / `!Pipeline` 左侧。
- [ ] 仅进程 pipeline 可在没有 shell 字符串的情况下运行。
- [ ] Checked sink 使用固定的安全 all-stage/pipefail 语义，并且 `check_into` 可保留 process 与 Uya stage 失败状态详情。
- [ ] `status_into()` 可以观察非零退出、signal、启动失败、`cancelled` 和 Uya stage 错误且不失败；executor interruption 仍返回 `error.Interrupted`。
- [ ] `capture_into()` 可以观察非零退出、signal、启动失败、`cancelled` 和 Uya stage 错误且不失败，把输出/状态写入 caller buffers，并返回长度与完整性摘要；executor interruption 仍返回 `error.Interrupted`。
- [ ] stdout/stderr capture 和文件重定向都有测试覆盖，文件重定向作为 transformer 与 `check` / `status_into` 组合。
- [ ] 大输出 pipeline 不会死锁。
- [ ] caller-provided writable regions 重叠会在外部副作用前被拒绝；capture exact-fit/overflow 使用 scratch probe 正确区分且不会在满缓冲区后停止 drain。
- [ ] observing capture 的 preflight spawn failure 和部分启动取消具有稳定的 `captured` / `complete` 语义。
- [ ] `stage_count(&Pipeline) !usize` 能让动态构造的 pipeline 在 sink 前精确分配 status 缓冲区，并拒绝无效 capability。
- [ ] capture 超限不会因 stage 忽略 broken-pipe、直接 stage 逃离 process group 或后代持有 pipe 写端而无限等待。
- [ ] POSIX executor 仅在自身当前拥有 controlling terminal 前台权时让 pipeline 获得并归还前台 PGID，后台 executor 不抢占终端，信号不会遗留后台 stage。
- [ ] 并发 POSIX sink 通过 runtime broker 订阅和 per-terminal foreground lease 避免覆盖 signal disposition 或竞态切换前台 PGID，等待 lease 本身可被中断。
- [ ] POSIX startup report 能区分 setpgid/chdir/dup2/execve，launch EOF 不会执行用户映像。
- [ ] POSIX startup report 能额外区分 child `signal_setup` 失败，child 不继承 runtime broker 状态。
- [ ] POSIX READY/EOF 检测不会被 parent 或兄弟 child 多持有 startup/launch/data fd 阻塞，launch 写入不受默认 `SIGPIPE` 杀死，全部内部 source fd 与 0/1/2 不冲突。
- [ ] POSIX stopped child 不会让同步 sink 或 controlling terminal 永久挂起。
- [ ] capture 成功结果通过 `complete` 明确区分 EOF 完整输出和 normal cutoff 前缀。
- [ ] 文件重定向 flags、固定打开顺序及非事务 create/truncate 副作用有跨平台测试和文档覆盖。
- [ ] process `exit_code: u32` 无损覆盖 POSIX 正常退出值和 Windows 完整 `DWORD`。
- [ ] Windows child 在执行释放前已进入 Job Object，且只继承 allowlist 中的 handles；resume 边界正确区分 `not_started` / `cancelled`，正常关闭不杀非直接后代，取消显式终止 Job，assignment 失败的未入 Job child 也会被单独终止并等待。
- [ ] 阶段 6 完成后，自定义 Uya stage 可以处理流数据并传递给下游；只有满足强制终止门槛的后端才能宣称有限取消。
- [ ] 文档解释为什么 `input: Pipeline` 和 `stage: T` 使用基于移动语义的设计。
