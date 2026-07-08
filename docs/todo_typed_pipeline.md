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
  - [ ] `cmd`
  - [ ] `stage`
  - [ ] `stdout_file`
  - [ ] `capture`
  - [ ] `status`
- [ ] 决定 `filter` 是公共别名，还是仅作为文档术语。
- [ ] 决定精确错误名：
  - [ ] `InvalidPipeline`
  - [ ] `ProcessFailed`
  - [ ] `CaptureLimitExceeded`
  - [ ] `PipelineSpawnFailed`
- [ ] 定义 checked sink 在非零退出时是否默认返回 `error.ProcessFailed`。
- [ ] 定义如何把 `PipelineResult` 附加到进程失败诊断，或如何从诊断中恢复它。
- [ ] 决定 `cmd` 使用 Uya 裸变参 `...` 加 `@params` 校验，还是使用基于 slice 的 `cmd_argv` API。
- [ ] 决定 `_` pipeline 占位符语法糖是延期，还是作为显式 parser/checker 工作实现。
- [ ] 在 `std_script_design.md` 中添加一个短章节链接到本设计。

## 阶段 1：Lexer 与 Parser 骨架

- [ ] 添加 `|>` token。
- [ ] 确保 `|>` 在单字符 `|` 和 `>` 之前识别。
- [ ] 添加低优先级、左结合 pipeline expression 的 parser 支持。
- [ ] 第一版将右侧限制为调用表达式。
- [ ] parser MVP 保持空 pipeline 构造显式；暂不特殊处理 `_`。
- [ ] 添加 parser 正向测试：
  - [ ] `pipeline() |> cmd("a") |> cmd("b") |> stdout_file("out")`
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
- [ ] 添加进程 stage 计划存储。
- [ ] 添加 owned argv 存储。
- [ ] 添加 cwd override 存储。
- [ ] 添加 env overlay 存储。
- [ ] 添加 stream policy 存储：
  - [ ] stdin file/null/inherit
  - [ ] stdout inherit/file/capture/null
  - [ ] stderr inherit/file/capture/null/merge_stdout
- [ ] 添加 stream policy 冲突校验。
- [ ] 添加 `pipeline() Pipeline` 或选定的空构造器。
- [ ] 添加 `cmd(input: Pipeline, program: &const byte, ...) !Pipeline` 或选定的 `cmd_argv` 等价 API。
- [ ] 添加 `stdin_file`、`stdout_file`、`stderr_file`。
- [ ] 添加 `stdout_capture`、`stderr_capture`、`stderr_to_stdout`。
- [ ] 添加 `capture`、`capture_limit`、`inherit_stdio` 和 `status`。
- [ ] 添加显式 `clone(input: &Pipeline) !Pipeline`。

## 阶段 5：POSIX 仅进程 Executor

- [ ] spawn 前创建所有 stage 间 pipe。
- [ ] wait 前 spawn 所有 process stage。
- [ ] 对 stdin/stdout/stderr 使用 `dup2`。
- [ ] 在子进程中关闭未使用 fd。
- [ ] 关闭父进程持有的未使用 fd 副本。
- [ ] 在子进程执行期间并发驱动有界 stdout/stderr capture reader。
- [ ] 仅在 pipe ownership 和 reader 状态不可能死锁后等待子进程。
- [ ] 收集每个 stage 的状态。
- [ ] 实现 checked sink 的 pipefail 行为。
- [ ] 将 `status()` 实现为观察型 sink：非零退出不失败。
- [ ] 实现有界 stdout/stderr capture。
- [ ] 添加输出大于 pipe buffer 的死锁回归测试。
- [ ] 添加测试：
  - [ ] `printf | wc`
  - [ ] 三阶段 pipeline
  - [ ] stdout 文件 sink
  - [ ] stderr 文件 sink
  - [ ] stderr capture
  - [ ] stderr to stdout merge
  - [ ] 缺失命令
  - [ ] 第一 stage 非零退出
  - [ ] 最后一 stage 非零退出

## 阶段 6：自定义 Uya 流 Stage

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
- [ ] 在 pipeline 计划中按值存储 stage 对象。
- [ ] 添加 erased thunk 表示或等价单态化存储。
- [ ] POSIX MVP 选项：
  - [ ] 为每个 Uya stage fork 一个子进程
  - [ ] 调用 `PipelineStage.run`
  - [ ] 将成功/失败映射为子进程退出状态
- [ ] 长期选项：
  - [ ] 用运行时 task/thread 执行替代 fork-backed Uya stage
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
  - [ ] 除非 `cmd` 明确指定，否则无隐式 PATH 行为
  - [ ] capture 限制
  - [ ] 平台后端状态

## 验收标准

- [ ] `|>` 只适用于 `Pipeline` / `!Pipeline` 左侧。
- [ ] 仅进程 pipeline 可在没有 shell 字符串的情况下运行。
- [ ] Checked sink 使用安全 pipefail 语义。
- [ ] `status()` 可以观察非零退出且不失败。
- [ ] stdout/stderr capture 和文件重定向都有测试覆盖。
- [ ] 大输出 pipeline 不会死锁。
- [ ] 自定义 Uya stage 可以处理流数据并传递给下游。
- [ ] 文档解释为什么 `input: Pipeline` 和 `stage: T` 使用基于移动语义的设计。
