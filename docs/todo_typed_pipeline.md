# 类型化管道 TODO

**状态**：可执行 TODO，规划中
**更新日期**：2026-07-09
**配套设计**：[`typed_pipeline_design.md`](typed_pipeline_design.md)
**相关设计**：[`std_script_design.md`](std_script_design.md)

## 定位

类型化管道为 `.ush` 脚本提供 shell 管道之外的结构化替代方案。它应建立在 `std.process` 和宿主抽象工作之上，而不是变成另一套 shell 实现。

实现应按小阶段推进。第一个可用里程碑应能在没有 shell 字符串的情况下运行简单 argv 管道；自定义 Uya 流 stage 可以在 process-only 管道稳定后再跟进。

## 阶段 0：规格锁定

- [ ] 按当前 Uya grammar 和接口语法复核 `typed_pipeline_design.md`。
- [ ] 确定最终名称：
  - [ ] `pipeline` 或 `empty_pipeline`
  - [ ] `cmd_argv` / `cmd_path_argv`，以及后续 `cmd` / `cmd_path` facade
  - [ ] `stage`
  - [ ] `stdout_file`
  - [ ] `capture_into` / `capture_limit_into`
  - [ ] `status_into`
- [ ] 决定 `filter` 是公共别名，还是仅作为文档术语。
- [ ] 决定精确错误名：
  - [ ] `InvalidPipeline`
  - [ ] `ProcessFailed`
  - [ ] `CaptureLimitExceeded`
  - [ ] `PipelineSpawnFailed`
- [ ] 定义 checked sink 在非零退出时是否默认返回 `error.ProcessFailed`。
- [ ] 定义失败详情通过 `check_into`、`status_into`、`capture_into`、`capture_limit_into` 返回，不依赖 Uya error payload。
- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [ ] per-stage `not_started`
  - [ ] per-stage `spawn_failed`
  - [ ] per-stage `exited(exit_code)`
  - [ ] per-stage `signaled(signal)`
  - [ ] `PipelineResult.statuses` 指向调用方提供的 status 缓冲区已写入前缀，不指向执行器临时数组
  - [ ] 公共字段使用当前 Uya 可声明的 slice/handle 形态，不使用伪动态数组 `[T]`
  - [ ] `CaptureBuffer.captured`
  - [ ] `CaptureBuffer.bytes`
  - [ ] capture bytes 指向调用方提供的 stdout/stderr 缓冲区已写入前缀，slice 只在调用方缓冲区有效且未复用覆盖期间有效
- [ ] 锁定 checked/observing sink 分层：
  - [ ] `check()`：pipefail，非零返回 `error.ProcessFailed`
  - [ ] `check()`：启动失败返回 `error.PipelineSpawnFailed`
  - [ ] `check_into(statuses, result)`：pipefail，返回 `ProcessFailed` / `PipelineSpawnFailed` 前写入完整 `PipelineResult`
  - [ ] `status_into(statuses, result)`：观察型，非零、signal、启动失败不作为 Uya error
  - [ ] `capture_into(statuses, stdout_buf, stderr_buf, result)` / `capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)`：观察型，结果中包含 `PipelineResult`
- [ ] 锁定 capture sink 语义：
  - [ ] `capture_into()` 隐式捕获 terminal stdout
  - [ ] stderr 只有显式 `stderr_capture()` 或 `stderr_to_stdout()` 后才进入返回值
  - [ ] 显式 stdout file/inherit 后调用 `capture_into()` / `capture_limit_into()` 报 `InvalidPipeline`
  - [ ] capture policy 与 `check` / `check_into` / `status_into` 组合报 `InvalidPipeline`
- [ ] 锁定 `CaptureLimitExceeded`：超限后关闭 pipe、回收子进程、重置输出 result 为空视图，并返回普通 Uya error；该路径不承诺返回部分状态。
- [ ] 锁定空 result 视图的字段值：`PipelineResult` 为 `stage_count=0`、空 `statuses`、`pipefail=false`；`PipelineCaptureResult` 还需把 stdout/stderr 置为 `captured=false` 与空 bytes。
- [ ] 锁定 `capture_into()` 使用调用方缓冲区容量作为上限，`capture_limit_into()` 在缓冲区容量之外额外施加 `max_bytes`，不引入隐藏默认上限常量。
- [ ] 锁定 `stdout_file` / `stderr_file` 为 stream policy transformer，不作为 sink。
- [ ] 锁定空 pipeline 传给任何 sink 返回 `error.InvalidPipeline`。
- [ ] 锁定 `inherit_stdio` 是显式策略而不是 reset，和已有 terminal policy 冲突。
- [ ] 锁定 `cwd` / `env` / `unset_env` 作用于最近追加的 process stage。
- [ ] 锁定相对 `cmd_path` 按该 stage 最终 cwd 解释，而不是按 transformer 调用时的父进程 cwd 解释。
- [ ] 锁定 terminal stdout/stderr 策略与 inter-stage pipe 的边界。
- [ ] 锁定整条 pipeline stderr 策略是 shell group 级语义，不是 per-stage stderr 数据流。
- [ ] 锁定 `cmd` 的 PATH-searching 语义，并提供 exact-path API `cmd_path`。
- [ ] 锁定 `cmd` 只接受不含路径分隔符的命令名；路径执行必须使用 `cmd_path`。
- [ ] 锁定 `cmd` PATH 查找复用 `std.process` / `std.path` 平台 helper，不在 executor 内重复实现。
- [ ] 先定义可由 pipeline 复用的 PATH helper，例如 `process_resolve_path(program, env, cwd)` 或等价接口。
- [ ] 锁定错误分类：API 误用返回 `InvalidPipeline`；stage 启动链路失败进入 `PipelineResult`；文件重定向、pipe、内存、编码转换等执行器资源失败返回普通 Uya error。
- [ ] 决定 `cmd` 使用 Uya 裸变参 `...` 加 `@params` 校验，还是使用基于 slice 的 `cmd_argv` API。
- [ ] 若开放裸变参 `cmd(input, program, ...)`，明确 `@params` 包含固定参数，必须跳过 `input` / `program` 后校验剩余 argv。
- [ ] MVP 优先考虑 `cmd_argv` / `cmd_path_argv` 基础 API，裸变参只作为 facade。
- [ ] 锁定 `Pipeline` 在缺少真正 non-copyable / opaque 类型时必须有单所有者 handle 或 consumed 运行时兜底。
- [ ] 决定 `_` pipeline 占位符语法糖是延期，还是作为显式 parser/checker 工作实现。
- [ ] 明确 process-only MVP 不包含自定义 Uya stage；Uya stage 需等待 owned-data 与 runtime task/thread 方案。
- [ ] 在 `std_script_design.md` 中添加一个短章节链接到本设计。

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
- [ ] 强制 `|>` 左侧为 `Pipeline` 或 `!Pipeline`。
- [ ] 强制右侧 callee 的首个参数为 `Pipeline`。
- [ ] 仅为 `|>` 添加 `!Pipeline` try-forward 语义。
- [ ] 拒绝对非 `Pipeline` 值使用通用数据管道。
- [ ] 拒绝 sink 之后继续链式管道，因为左侧不再是 `Pipeline`。
- [ ] 添加诊断：
  - [ ] 左侧不是 `Pipeline`
  - [ ] 右侧不是调用表达式
  - [ ] 首个参数不是 `Pipeline`
  - [ ] sink 后继续管道的误用
- [ ] 添加 `1 |> cmd("x")` 的 checker 负向测试。
- [ ] 添加 `!Pipeline |> transformer` 的 checker 测试。
- [ ] 添加 checker 测试证明非 `Pipeline` 的 `!T` 不会得到 try-forward。

## 阶段 3：Lowering

- [ ] 将 `lhs |> f(args...)` 降低为普通调用和临时变量。
- [ ] 保留 `Pipeline` 的移动语义。
- [ ] 以和普通 `try` 一致的方式降低 `!Pipeline` try-forward。
- [ ] `!Pipeline` try-forward 使用 AST/临时变量语义实现，不通过文本级 `f(try lhs, ...)` 重新解析。
- [ ] 确保诊断源位置指向有用 span。
- [ ] 为以下场景添加 lowering snapshot 或等价内部 dump：
  - [ ] 单个 transformer
  - [ ] 多个 transformer
  - [ ] 最终 sink
  - [ ] `!Pipeline` try-forward

## 阶段 4：`std.process.Pipeline` MVP

- [ ] 添加对调用方抽象的 `Pipeline` 表示。
- [ ] 如果使用 `type Pipeline = opaque...`，先实现并验证真正的 opaque-type 编译器/codegen 支持。
- [ ] 否则使用由 `std.process` 拥有的 struct/handle 表示，并避免通过 script facade 暴露内部结构。
- [ ] 如果暂用 struct/handle，必须实现单所有者或 consumed 兜底，防止浅拷贝后双执行。
- [ ] 添加进程 stage 计划存储。
- [ ] 添加 `PipelineStageStatus` / `PipelineResult` / `CaptureBuffer` / `PipelineCaptureResult` 表示。
- [ ] 为 `PipelineResult.statuses` 和 capture bytes 实现调用方缓冲区写入与非拥有视图返回路径，不引入结果自有存储或析构路径。
- [ ] 添加 owned argv 存储。
- [ ] 为 process stage 添加 execution-time `exec_path` 存储或等价临时结构；不要把解析结果持久化到可 clone 的 plan。
- [ ] 添加 cwd override 存储。
- [ ] 添加 env overlay 存储。
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
- [ ] 定义并实现 `cmd` 的 PATH 查找使用 stage 最终 child env，且复用 `std.process` / `std.path` helper。
- [ ] 在 pipeline executor 前实现并测试 PATH helper，避免 executor 内私有 PATH 搜索逻辑。
- [ ] 添加 `stdin_file`、`stdout_file`、`stderr_file`。
- [ ] 添加 `stdout_capture`、`stderr_capture`、`stderr_to_stdout`。
- [ ] 添加 `inherit_stdio` stream transformer。
- [ ] 添加 `check`、`check_into`、`status_into`、`capture_into` 和 `capture_limit_into`。
- [ ] 添加显式 `clone(input: &Pipeline) !Pipeline`。
- [ ] `clone` 对包含不可克隆 erased stage 的计划返回 `error.InvalidPipeline`。

## 阶段 5：POSIX 仅进程 Executor

- [ ] spawn 前构造每个 process stage 的最终 argv/env/cwd。
- [ ] spawn 前解析所有 `cmd` stage 的 PATH；失败时不启动任何子进程，并写入 `spawn_failed` / `not_started` 状态。
- [ ] 对 stage cwd 失败写入 `spawn_failed` / `not_started` 状态。
- [ ] 对文件重定向打开失败、pipe 创建失败、内存分配失败返回普通 Uya error。
- [ ] PATH/stage 预检通过后再创建所有 stage 间 pipe。
- [ ] wait 前 spawn 所有 process stage。
- [ ] 对 stdin/stdout/stderr 使用 `dup2`。
- [ ] 在子进程中关闭未使用 fd。
- [ ] 为 child-side `execve` 失败实现 close-on-exec diagnostic pipe。
- [ ] 关闭父进程持有的未使用 fd 副本。
- [ ] 在子进程执行期间并发驱动有界 stdout/stderr capture reader。
- [ ] 仅在 pipe ownership 和 reader 状态不可能死锁后等待子进程。
- [ ] 收集每个 stage 的状态。
- [ ] 实现 checked sink 的 pipefail 行为。
- [ ] `check_into` 在返回 `error.ProcessFailed` 或 `error.PipelineSpawnFailed` 前写入完整 `PipelineResult`。
- [ ] 将 `status_into()` 实现为观察型 sink：非零退出、signal、启动失败不失败。
- [ ] 将 `capture_into()` / `capture_limit_into()` 实现为观察型 sink：非零退出、signal、启动失败不失败且结果包含 `PipelineResult`。
- [ ] 实现有界 stdout/stderr capture。
- [ ] `capture_limit_into` 超限时关闭 pipe、回收子进程、重置输出 result 为空视图，并返回 `error.CaptureLimitExceeded`。
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
  - [ ] 相对 `cmd_path` 搭配 `cwd()`
  - [ ] 文件重定向打开失败返回普通 Uya error
  - [ ] signal 终止状态
  - [ ] `stdout_file(...) |> capture_into(...)` 冲突
  - [ ] `stderr_capture() |> status_into(...)` 冲突
  - [ ] 第一 stage 非零退出
  - [ ] 最后一 stage 非零退出

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
- [ ] 用运行时 task/thread 执行 Uya stage，不假设 fork 语义。
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
- [ ] 为 pipe 实现 handle 继承/复制。
- [ ] 在不假设 POSIX fd 的情况下实现 stdout/stderr capture。
- [ ] 使用 UTF-8 公共 API 和 UTF-16 bridge 实现 cwd/env 转换。
- [ ] 明确 argv 到 Windows command line 的 quoting 规则，且不隐式调用 `cmd.exe`。
- [ ] 决定自定义 Uya stage 在 Windows 上如何运行：
  - [ ] 优先 runtime thread/task
  - [ ] 不假设 fork 语义
- [ ] 添加 Windows hosted smoke 测试：
  - [ ] 两阶段 pipeline
  - [ ] stdout 文件 sink
  - [ ] stderr capture
  - [ ] 非零 stage 结果

## 阶段 9：文档与稳定性门禁

- [ ] 更新 `std_script_design.md`。
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
- [ ] Checked sink 使用安全 pipefail 语义，并且 `check_into` 可保留失败状态详情。
- [ ] `status_into()` 可以观察非零退出、signal 和启动失败且不失败。
- [ ] `capture_into()` 可以观察非零退出、signal 和启动失败且不失败，并返回输出与完整状态。
- [ ] stdout/stderr capture 和文件重定向都有测试覆盖，文件重定向作为 transformer 与 `check` / `status_into` 组合。
- [ ] 大输出 pipeline 不会死锁。
- [ ] 阶段 6 完成后，自定义 Uya stage 可以处理流数据并传递给下游。
- [ ] 文档解释为什么 `input: Pipeline` 和 `stage: T` 使用基于移动语义的设计。
