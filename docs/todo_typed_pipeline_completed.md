# 类型化管道 TODO — 完成归档

> 本文件记录已完成并验证的任务，从 `docs/todo_typed_pipeline.md` 移入。

---

## 阶段 0：规格锁定

- [x] 按当前 Uya grammar 和接口语法复核 `typed_pipeline_design.md`。
  验证：已在归档前完成并验证。

---

- [x] 在 `std_script_design.md` 中添加一个短章节链接到本设计。
  验证：已在归档前完成并验证。

---

## 阶段 9：文档与稳定性门禁

- [x] 更新 `std_script_design.md`。
  验证：已在归档前完成并验证。

---

## 阶段 0：规格锁定

- [x] 确定最终名称：
  - [x] `pipeline`（空管道构造器最终名称为 `pipeline()`，`empty_pipeline` 废弃）
    验证：复核 `docs/typed_pipeline_design.md` L126-L131、L196，以及 `docs/std_script_design.md` L238 均使用 `pipeline()`；无 `.uya` 实现引用任一候选名。

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `pipeline`（空管道构造器最终名称为 `pipeline()`，`empty_pipeline` 废弃）
    验证：复核 `docs/typed_pipeline_design.md` L126-L131、L196，以及 `docs/std_script_design.md` L238 均使用 `pipeline()`；无 `.uya` 实现引用任一候选名。
    归档验证（2026-07-10）：
    - `sed -n '126,131p' docs/typed_pipeline_design.md` 确认使用 `pipeline()`
    - `sed -n '196p' docs/typed_pipeline_design.md` 确认 `fn pipeline() Pipeline;`
    - `sed -n '238p' docs/std_script_design.md` 确认引用 typed_pipeline_design.md 的 pipeline 语义
    - `grep -R -n -E '(empty_pipeline|pipeline\s*\()' --include='*.uya' .` 未发现 `empty_pipeline`；`pipeline(` 仅在 `examples/example_152.uya` 中作为用户自定义函数名出现，非 typed pipeline 构造器。

---

## 阶段 0：规格锁定

- [x] 确定最终名称：
  - [x] `cmd_argv` / `cmd_path_argv`，以及后续 `cmd` / `cmd_path` facade
    验证（2026-07-10）：
    - `sed -n '190,210p' docs/typed_pipeline_design.md` 确认 API 列表已使用 `cmd_argv`、`cmd_path_argv`、`cmd`、`cmd_path`
    - `grep -cE 'cmd_argv|cmd_path_argv|fn cmd\(|fn cmd_path\(' docs/typed_pipeline_design.md` 返回 21 处引用
    - `grep -nE '\b(exec_argv|run_argv|spawn_argv|exec_path_argv|run_path_argv|spawn_path_argv|process_argv|process_path_argv|pipeline_cmd_argv|pipe_cmd_argv|command_argv|command_path_argv)\b' docs/typed_pipeline_design.md docs/std_script_design.md` 未发现竞争候选名
    - 已在 `typed_pipeline_design.md` API 列表标题处添加"名称已锁定为最终公共名"说明，并在 `cmd` / `cmd_path` 注释处补充"名称同样锁定"

---

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `stage`
    验证：`docs/typed_pipeline_design.md` L449 已声明“名称锁定”；L459-L463 将 transformer 标记为“最终 transformer（名称已锁定）”并使用 `fn stage<T: PipelineStage>(input: Pipeline, stage: T) !Pipeline;`；未决问题 L741 已更新为“`stage` 已锁定为最终名称；`filter` 是否应保留为 `stage` 的公共别名（由 TODO L21 单独决定）”。`python3 scripts/todo_progress.py summary docs/todo_typed_pipeline.md` 确认 L17 已更新。

---

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `stage`
    验证（2026-07-10）：
    - `sed -n '449p' docs/typed_pipeline_design.md` 确认“名称锁定：自定义 Uya pipeline stage 的 transformer 最终名称为 `stage`”。
    - `sed -n '462p' docs/typed_pipeline_design.md` 确认 `fn stage<T: PipelineStage>(input: Pipeline, stage: T) !Pipeline;`。
    - `sed -n '741p' docs/typed_pipeline_design.md` 确认未决问题中写明“`stage` 已锁定为最终名称；`filter` 是否应保留为 `stage` 的公共别名（由 TODO L21 单独决定）”。
    - `grep -nE '\b(filter|step|node)\b.*stage|stage.*\b(filter|step|node)\b' docs/typed_pipeline_design.md` 未发现将 `filter`/`step`/`node` 作为 transformer 最终名的声明。

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `stdout_file`：锁定为最终公共名 `fn stdout_file(input: Pipeline, path: &const byte) !Pipeline;`；验证命令 `grep -n "stdout_file" docs/typed_pipeline_design.md` 命中 9 处，包括 API 列表 L213、示例 L30/L48/L501、语义说明 L266/L268、冲突策略 L423/L424/L426。

---

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `capture_into` / `capture_limit_into`
    验证（2026-07-10）：
    - `sed -n '193,222p' docs/typed_pipeline_design.md` 确认 API 列表标题写明“名称已锁定为最终公共名”，并声明 `fn capture_into(input: Pipeline, statuses: &[PipelineStageStatus], stdout_buf: &[byte], stderr_buf: &[byte], result: &PipelineCaptureResult) !void;` 和 `fn capture_limit_into(input: Pipeline, max_bytes: usize, statuses: &[PipelineStageStatus], stdout_buf: &[byte], stderr_buf: &[byte], result: &PipelineCaptureResult) !void;`
    - `grep -cE 'capture_into|capture_limit_into' docs/typed_pipeline_design.md` 返回 15 处引用
    - `grep -nE '\b(capture_output|output_of|read_into|collect_into|get_output|exec_capture|run_capture|spawn_capture|capture_stdout|capture_stderr|capture_all)\b' docs/typed_pipeline_design.md docs/std_script_design.md docs/todo_typed_pipeline.md` 未发现竞争候选名

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `capture_into` / `capture_limit_into`

验证命令：
```bash
grep -n "capture_into\|capture_limit_into" docs/typed_pipeline_design.md
```

验证结果：在设计文档中发现多处使用 `capture_into()` / `capture_limit_into()` 命名，包括 API 声明（L221-L222）、sink 说明（L268、L270、L332、L338、L371、L381、L383、L397、L429、L431）和约束条款（L672、L695）。名称已锁定。

## 阶段 0：规格锁定

- [x] 确定最终名称：
  - [x] `status_into`
    验证（2026-07-10）：
    - `sed -n '193,222p' docs/typed_pipeline_design.md` 确认 API 列表在“名称已锁定为最终公共名”标题下列出 `fn status_into(input: Pipeline, statuses: &[PipelineStageStatus], result: &PipelineResult) !void;`
    - `grep -cE 'status_into' docs/typed_pipeline_design.md` 返回 9 处引用
    - `grep -nE '\b(status_of|exit_status_into|result_into|statuses_into|get_status|pipe_status|wait_status|run_status|exec_status|process_status|pipeline_status|exit_into|wait_into|observe_status)\b' docs/typed_pipeline_design.md docs/std_script_design.md docs/todo_typed_pipeline.md` 未发现竞争候选名

## 阶段 0：规格锁定

- [x] 决定 `filter` 是公共别名，还是仅作为文档术语。
  决策：`filter` 不作为公共 API 别名，仅作为文档/概念术语使用；自定义 Uya pipeline stage 的唯一公共 transformer 名称保持为 `stage`。
  验证（2026-07-10）：
  - `sed -n '449p' docs/typed_pipeline_design.md` 确认“名称锁定：自定义 Uya pipeline stage 的 transformer 最终名称为 `stage`”。
  - `sed -n '505p' docs/typed_pipeline_design.md` 确认“`filter` 不作为公共 API 别名……”。
  - `sed -n '741p' docs/typed_pipeline_design.md` 确认未决问题中写明“`filter` 仅作为文档术语，不暴露为公共别名”。
  - `grep -nE '\bfn\s+filter\b|\bfilter\s*\(' docs/typed_pipeline_design.md docs/std_script_design.md docs/todo_typed_pipeline.md` 未发现公共 `filter` API 声明。


## 阶段 0：规格锁定

### 决定精确错误名

- [x] `InvalidPipeline`
  - 决策：采用 `error.InvalidPipeline` 作为类型化管道的通用“无效 / 不可执行 pipeline”错误名。
  - 语义锁定（详见 `docs/typed_pipeline_design.md`）：
    - 已消费或已 drop 的 capability 再次使用；
    - 空 pipeline 传给 sink；
    - `cmd` 命令名为空或含路径分隔符；
    - `cmd_path` 使用 Windows drive-relative 路径（如 `C:tool.exe`）；
    - stream policy 冲突或错误的 transformer 位置；
    - `cwd` / `env` / `unset_env` 作用于非 process stage 或空计划；
    - capture sink 与 file / inherit 策略冲突；
    - `clone` 遇到不可克隆的 erased stage；
    - caller-provided statuses / 缓冲区容量不足或重叠；
    - `stage_count(&Pipeline)` 查询到无效 / 过期 capability。
  - 验证：人工复核 `docs/typed_pipeline_design.md` 中所有 `InvalidPipeline` 出现位置，语义一致且无同名歧义。无代码实现，无需编译/运行验证。

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `InvalidPipeline` — 锁定为 `error.InvalidPipeline`：表示 pipeline 处于不可执行或不可转换状态（已消费/过期 capability、空 pipeline、策略冲突、参数无效、不可克隆 stage、caller 缓冲区问题等）。已复核 `typed_pipeline_design.md` 中全部出现位置，语义一致。

验证：
- 已人工复核 `docs/typed_pipeline_design.md` 中所有 `InvalidPipeline` 出现位置，语义一致。
- 归档时间：2026-07-10。

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `ProcessFailed`
    验证（2026-07-10）：
    - `sed -n '375,380p' docs/typed_pipeline_design.md` 确认 `check()` / `check_into()` 使用 `error.ProcessFailed` 表示任一 process stage 非零退出或 signal 终止。
    - `sed -n '695p' docs/typed_pipeline_design.md` 确认“需要失败详情时不能依赖 `error.ProcessFailed` 携带 payload，必须使用 `check_into` / `status_into` / `capture_into` / `capture_limit_into`”。
    - `grep -cE 'error\.ProcessFailed' docs/typed_pipeline_design.md` 返回 5 处引用；语义一致，无竞争候选名。
    - 决策：采用 `error.ProcessFailed` 作为 checked sink 的 process stage 非零退出 / signal 终止错误名；优先级低于 `error.PipelineSpawnFailed` 与 `error.PipelineStageFailed`。

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `CaptureLimitExceeded`
    验证（2026-07-10）：
    - `sed -n '338p' docs/typed_pipeline_design.md` 确认超过 capture limit 时返回 `error.CaptureLimitExceeded`，并通过独立一字节 scratch overflow probe 区分 exact-fit 与 overflow。
    - `sed -n '342p' docs/typed_pipeline_design.md` 确认返回 `error.CaptureLimitExceeded` 前必须把输出 `PipelineCaptureResult` 重置为空摘要，不通过 `CaptureStreamResult` 表示截断。
    - `sed -n '397p' docs/typed_pipeline_design.md` 确认任一 captured stream 超过有效限制时进入强制取消路径，终止所有直接 stage、reap 后重置输出 result 为空摘要并返回 `error.CaptureLimitExceeded`。
    - `grep -cE 'error\.CaptureLimitExceeded|CaptureLimitExceeded' docs/typed_pipeline_design.md` 返回 6 处匹配行；语义一致，无竞争候选名。
    - 决策：采用 `error.CaptureLimitExceeded` 作为 capture sink 输出超过有效上限时的稳定 Uya error 名。


## 2026-07-10 完成归档

### 阶段 0：规格锁定

- [x] 决定精确错误名：
  - [x] `Interrupted`
    - **验证**：`docs/typed_pipeline_design.md` 已将 `error.Interrupted` 作为稳定错误名使用：
      - L360：executor 收到未被忽略的终止/取消信号 => `error.Interrupted`
      - L361：直接 stage 进入 stopped 状态 => `error.Interrupted`
      - L385/L545/L547/L549/L609/L687：取消/中断路径统一返回 `error.Interrupted`
    - `docs/std_refactor_design.md` L183 已声明 `error Interrupted;`，名称一致。
    - **结论**：`Interrupted` 锁定为 pipeline executor 在自身收到未忽略取消信号、等待 terminal lease 被中断、以及 stopped child 强制收敛时的精确 Uya error 名。

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `Interrupted`

验证：
- 命令：`grep -n "error.Interrupted" docs/typed_pipeline_design.md`
- 结果：设计文档中稳定使用 `error.Interrupted` 表示 executor/同步 sink 收到未忽略终止信号、直接 stage stopped、前台终端 lease 中断等场景（如 L360-L361、L385、L395、L549、L609 等）。命名已锁定。

---

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `PipelineSpawnFailed`
    验证：`grep -n 'error.PipelineSpawnFailed' docs/typed_pipeline_design.md` 命中 L378、L379；设计文档已将 checked sink 的 spawn 失败路径统一命名为 `error.PipelineSpawnFailed`，与 `PipelineStageStatusKind.spawn_failed` 状态对应。

---

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `PipelineStageFailed`
    验证（2026-07-10）：
    - `sed -n '378p' docs/typed_pipeline_design.md` 确认 `check()` 在 Uya stage 返回错误时使用 `error.PipelineStageFailed`。
    - `sed -n '379p' docs/typed_pipeline_design.md` 确认 `check_into()` 在 Uya stage 返回错误时返回 `error.PipelineStageFailed` 并保留完整摘要。
    - `sed -n '342p' docs/typed_pipeline_design.md` 确认 `check_into()` 返回 `error.PipelineStageFailed` 时必须保留已写入 statuses 的完整 stage 摘要。
    - `grep -cE 'error\.PipelineStageFailed' docs/typed_pipeline_design.md` 返回 3 处引用；语义一致，无竞争候选名。
    - 决策：采用 `error.PipelineStageFailed` 作为 checked sink 遇到 `PipelineStageStatusKind.stage_failed` 时返回的精确 Uya error 名；优先级低于 `error.PipelineSpawnFailed`，高于 `error.ProcessFailed`。

## 阶段 0：规格锁定

- [x] 定义 checked sink 在非零退出时是否默认返回 `error.ProcessFailed`。
  决策：是。`check()` / `check_into()` 使用固定 all-stage/pipefail；任一 process stage 非零退出或 signal 终止默认返回 `error.ProcessFailed`。`spawn_failed` / `not_started` 链路优先返回 `error.PipelineSpawnFailed`，Uya stage 错误优先返回 `error.PipelineStageFailed`。`check_into()` 在返回上述错误前必须先写入完整 `PipelineResult`。
  验证（2026-07-10）：
  - `sed -n '373,379p' docs/typed_pipeline_design.md` 确认 `check()` 固定 all-stage/pipefail，非零退出或 signal 终止默认返回 `error.ProcessFailed`，`spawn_failed`/`not_started` 链路优先返回 `error.PipelineSpawnFailed`，Uya stage 错误优先返回 `error.PipelineStageFailed`。
  - `sed -n '382,383p' docs/typed_pipeline_design.md` 确认 `check_into()` 与 `check()` 语义相同，且返回错误前必须先写入完整 stage 状态。

---

## 阶段 0：规格锁定

- [x] 定义失败详情通过 `check_into`、`status_into`、`capture_into`、`capture_limit_into` 返回，不依赖 Uya error payload。
  验证（2026-07-10）：
  - `sed -n '373,379p' docs/typed_pipeline_design.md` 确认新增“失败详情返回路径”章节已明确该原则。
  - `sed -n '391p' docs/typed_pipeline_design.md` 确认“需要失败详情时，调用方必须使用 `check_into`/`status_into`/`capture_into`/`capture_limit_into`”。
  - `sed -n '703p' docs/typed_pipeline_design.md` 确认检查表再次强调该原则。
  - `grep -cE 'check_into|status_into|capture_into|capture_limit_into' docs/typed_pipeline_design.md` 返回多处 API 声明与语义说明，所有失败详情写入调用方提供的 `statuses`/`result`/`stdout_buf`/`stderr_buf`。

# 类型化管道 TODO
## 阶段 0：规格锁定
- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `not_started`
    - 验证：`grep -n "not_started" docs/typed_pipeline_design.md` 命中 10 处；`PipelineStageStatusKind` 枚举已包含 `not_started`（L278），语义定义为“因更早预检、启动失败或执行器取消而未越过执行释放边界”（L326），POSIX/Windows 边界（L551、L615）、预检失败场景（L348、L561）与字段约束（L328）均一致。

---

# 类型化管道 TODO
## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `spawn_failed`
    - 验证：已确认 `docs/typed_pipeline_design.md` 中 `PipelineStageStatusKind` 定义了 `spawn_failed`，`PipelineStageStatus` 包含 `spawn_failure: PipelineSpawnFailureKind` 与 `platform_code: u32`，文档 L326-L369 明确语义、执行释放边界、`not_started` 区别、平台错误码映射及 `check()`/`status_into()`/`capture_into()` 的处理规则。
