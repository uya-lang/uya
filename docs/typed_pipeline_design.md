# 类型化管道设计

**状态**：design draft
**更新日期**：2026-07-09
**配套 TODO**：[`todo_typed_pipeline.md`](todo_typed_pipeline.md)
**相关设计**：[`std_script_design.md`](std_script_design.md)

## 概述

类型化管道是面向 Uya 脚本的结构化进程管道模型。它的目标是在 `.ush` 文件中替代 shell 风格管道，同时避免把命令字符串传给 `/bin/sh`。

核心形态如下：

- `Pipeline` 是不透明、move-only、延迟执行的执行计划。
- `|>` 是仅用于 `Pipeline` 的前向操作符，不是通用数据管道操作符。
- transformer 函数消费 `Pipeline`，返回 `!Pipeline`。
- sink 函数消费 `Pipeline`、执行它，并返回非 `Pipeline` 结果。
- 未来自定义 Uya 流处理通过接口表示，而不是通过 shell 片段表示。

MVP 示例使用 slice 形式的 `cmd_argv` / `cmd_path_argv`，避免依赖尚未完成的 typed varargs 反射能力：

```uya
const rg_args: [&const byte: 4] = ["-n", "TODO", "src", "docs"];
const sort_args: [&const byte: 0] = [];

try (pipeline()
    |> cmd_argv("rg", &rg_args[0:4])
    |> cmd_argv("sort", &sort_args[0:0])
    |> stderr_file("build/todos.err")
    |> stdout_file("build/todos.txt")
    |> check());
```

语义意图等价于：

```sh
{ rg -n TODO src docs | sort > build/todos.txt; } 2> build/todos.err
```

但它不会通过向 shell 发送字符串来实现。

如果后续编译器支持 typed varargs materialization，`cmd(...)` 可以作为上面 slice API 的人体工学 facade：

```uya
try (pipeline()
    |> cmd("rg", "-n", "TODO", "src", "docs")
    |> cmd("sort")
    |> stdout_file("build/todos.txt")
    |> check());
```

## 目标

1. **没有隐式 shell**

命令是 argv 数组，不是命令字符串。shell 展开、命令替换、glob、alias 和 shell function 都不属于这个模型。

2. **类型化组合**

类型检查器证明每一个 `|>` 链接都接收有效的 `Pipeline` 或 `!Pipeline` 值，并调用首个参数为 `Pipeline` 的函数。

3. **脚本人体工学**

常见 shell 管道模式在 `.ush` 脚本中应足够紧凑。最终 sink 是执行点；MVP 常见场景用 `check()`、`status_into()`、`capture_into()` 等明确 sink 结尾，不使用含义含混的尾随 `run()`。

4. **可扩展的流处理**

process-only MVP 先只支持外部进程 stage；设计为后续 `PipelineStage` 接口预留扩展点。未来 Uya stage 对象可以携带状态与配置，但不属于第一版公共 API。

5. **可移植的宿主抽象**

公共 API 保持平台中立。POSIX `fork` / `execve` / `pipe` / `dup2` / `waitpid` 和 Windows `CreateProcess` 细节保留在 `std.process` / `osal` 之下。

## 非目标

- 不兼容 bash 语法。
- 不提供交互式 shell、job control、`trap`、shell alias 或 shell function。
- 本提案不提供适用于所有 Uya 值的通用数据管道操作符。
- 不做隐式命令字符串解析。
- 在 sink 消费 pipeline 前，不做隐藏执行。

## 语言表面

### 仅用于 Pipeline 的 `|>`

`|>` 的适用范围刻意收窄：

```text
lhs |> f(args...)
```

仅当满足以下条件时合法：

- `lhs` 的类型是 `Pipeline` 或 `!Pipeline`。
- 右侧是调用表达式。
- 被调用函数的首个参数是 `Pipeline`。

如果 `lhs: Pipeline`，表达式等价于：

```uya
f(lhs, args...)
```

如果 `lhs: !Pipeline`，表达式等价于：

```uya
f(try lhs, args...)
```

这个 try-forward 规则只针对 `!Pipeline`。它不能变成通用的 `!T` 数据管道特性。

非法示例：

```uya
const empty_args: [&const byte: 0] = [];

123 |> cmd_argv("sort", &empty_args[0:0]); // 左侧不是 Pipeline
"abc" |> trim();                         // |> 不是通用数据管道
result |> exit_code();                   // 左侧不是 Pipeline
```

### 空 Pipeline 构造器

MVP 应使用显式空 pipeline 构造器作为管道起点：

```uya
const rg_args: [&const byte: 1] = ["TODO"];
pipeline() |> cmd_argv("rg", &rg_args[0:1])
```

这样可以避免重载 `_`。当前 Uya 已经在 discard assignment、模式和部分实参位置中特殊处理 `_`，因此若要把 `_` 用作 pipeline 语法糖，需要单独做 parser/type-checker 决策。若后续加入该语法糖，`_` 必须限制在第一个 `Pipeline` 实参位置，且不能变成通用默认值表达式。

## Pipeline 类型

`Pipeline` 是由 `std.process` 拥有的抽象 move-only 执行计划。

当前 Uya 源码尚不支持如下形式的可工作声明：

```text
type Pipeline = opaque std.process.Pipeline;
```

第一版实现应将 `Pipeline` 表示为 `std.process` 的结构体/handle，并通过 `std.script` facade 隐藏内部细节；或者先把真正的 opaque type 支持作为明确的编译器任务完成，再把 opaque 语法发布为面向用户的 Uya 语法。

执行计划是延迟的。transformer 会同步构造或修改计划，但不会启动子进程。sink 消费计划并执行它。

move-only 规则是有意设计：

```uya
const rg_args: [&const byte: 1] = ["TODO"];
const sort_args: [&const byte: 0] = [];
const wc_args: [&const byte: 1] = ["-l"];

const p: Pipeline = try (pipeline() |> cmd_argv("rg", &rg_args[0:1]));
const sorted: Pipeline = try (p |> cmd_argv("sort", &sort_args[0:0]));
const counted: Pipeline = try (p |> cmd_argv("wc", &wc_args[0:1])); // 错误：p 已被移动
```

如果编译器已经具备按类型标记的 non-copyable / opaque 资源能力，第一版可以把 `Pipeline` 接入该移动检查。但当前普通结构体按值移动检查不足以独立证明所有调用参数、pipeline lowering 临时值和返回值路径；因此在该能力完成前，`Pipeline` 实现必须提供单所有者 handle 或运行时 consumed 标记兜底。库实现不得暴露内部字段，所有 transformer 都按值消费旧计划并返回新计划。`clone` 是唯一显式复制入口。

如果第一版还没有真正的 opaque / non-copyable 类型，`Pipeline` 的公开 facade 仍必须维持单所有者语义：浅拷贝内部句柄不能让两个变量都能执行同一计划。实现可以通过隐藏字段的单所有者 handle、运行时 consumed 标记，或二者结合兜底；但不能把可自由复制的普通 struct 直接暴露给脚本作者。

如果脚本需要从共同基础派生多个计划，必须显式 clone：

```uya
fn clone(input: &Pipeline) !Pipeline;
```

`clone` 必须深拷贝 argv、cwd/env overlay、stream policy、以及可克隆的 Uya stage 数据。若计划中包含不可克隆的 erased stage，`clone` 必须返回 `error.InvalidPipeline`，不能浅拷贝内部指针。

## Transformer 与 Sink

Transformer：

```text
fn(Pipeline, ...) !Pipeline
```

Sink：

```text
fn(Pipeline, ...) !T where T != Pipeline
```

推荐的基础 API：

```uya
fn pipeline() Pipeline;

fn cmd_argv(input: Pipeline, program: &const byte, args: &[&const byte]) !Pipeline;
fn cmd_path_argv(input: Pipeline, path: &const byte, args: &[&const byte]) !Pipeline;

// 后续 facade；不属于缺少 typed varargs materialization 时的 MVP。
fn cmd(input: Pipeline, program: &const byte, ...) !Pipeline;
fn cmd_path(input: Pipeline, path: &const byte, ...) !Pipeline;
fn cwd(input: Pipeline, path: &const byte) !Pipeline;
fn env(input: Pipeline, key: &const byte, value: &const byte) !Pipeline;
fn unset_env(input: Pipeline, key: &const byte) !Pipeline;

fn stdin_file(input: Pipeline, path: &const byte) !Pipeline;
fn stdout_capture(input: Pipeline) !Pipeline;
fn stderr_capture(input: Pipeline) !Pipeline;
fn stdout_file(input: Pipeline, path: &const byte) !Pipeline;
fn stderr_file(input: Pipeline, path: &const byte) !Pipeline;
fn stderr_to_stdout(input: Pipeline) !Pipeline;
fn inherit_stdio(input: Pipeline) !Pipeline;

fn check(input: Pipeline) !void;
fn check_into(input: Pipeline, statuses: &[PipelineStageStatus], result: &PipelineResult) !void;
fn status_into(input: Pipeline, statuses: &[PipelineStageStatus], result: &PipelineResult) !void;
fn capture_into(input: Pipeline, statuses: &[PipelineStageStatus], stdout_buf: &[byte], stderr_buf: &[byte], result: &PipelineCaptureResult) !void;
fn capture_limit_into(input: Pipeline, max_bytes: usize, statuses: &[PipelineStageStatus], stdout_buf: &[byte], stderr_buf: &[byte], result: &PipelineCaptureResult) !void;

// 后续 facade；只在语言具备可靠 move-only result / drop 能力后开放。
fn status(input: Pipeline) !PipelineResult;
fn capture(input: Pipeline) !PipelineCaptureResult;
fn capture_limit(input: Pipeline, max_bytes: usize) !PipelineCaptureResult;
```

Uya 可变参数写作裸尾随 `...`，不是命名的 `args: ...`。当前 C99 codegen 中 `@params` 只稳定 materialize 固定形参；`...` 主要用于 C varargs 转发，不能当作可枚举、可类型检查、可保存生命周期的 Uya argv 列表。因此 process-only MVP 不应要求 `cmd(input, program, ...)` 直接读取 `@params`。

第一版必须先实现 `cmd_argv` / `cmd_path_argv` 这类 slice 形式的基础 API。裸变参 `cmd` / `cmd_path` 只有在编译器补齐 typed varargs materialization 后才能开放为公共 facade；届时实现必须显式跳过 `input` 和 `program` 后再校验剩余 argv 项均为 `&const byte`，不能把整个 `@params` 当作 argv 列表。

`cmd_argv` / `cmd` 是 PATH-searching API：它只接受不含路径分隔符的命令名，存储该名称，并在执行时按该 stage 的最终 child env 进行 PATH 查找；它不做 shell 展开、glob、alias 或函数查找。若调用方要传绝对路径、相对路径或已经解析出的可执行文件，必须使用 `cmd_path_argv` / `cmd_path`。

`cmd_path_argv` / `cmd_path` 是 exact-path API：路径中不做 PATH 查找。绝对路径按原样执行；相对路径按该 stage 的最终 cwd 解释，若没有显式 `cwd()` 则按调用 pipeline sink 时的宿主进程 cwd 解释。实现不得在 transformer 调用时把相对 `cmd_path` 绑定到当前父进程 cwd，因为后续 `cwd()` transformer 仍可改变该 stage 的执行目录。

`cmd_argv` / `cmd_path_argv` 的 `args` 不包含 child `argv[0]`。执行器构造最终 argv 时必须显式前置一个 `argv0`：`cmd_argv` 使用 `program` 本身，`cmd_path_argv` 使用调用方传入的 `path` 本身。若后续需要伪装或自定义 `argv[0]`，应添加单独的 `cmd_argv0` / `cmd_path_argv0` API，不能改变现有 `args` 语义。

PATH 查找属于 `std.process` / `std.path` 的平台敏感逻辑，不应在 pipeline executor 中另写一套。POSIX 使用 `PATH` 和 `/` 分隔规则；Windows hosted 后端需要处理 `PATH` 分隔符、可执行后缀和当前目录搜索策略。第一版可以先只交付 POSIX 规则，但必须先补出可由 pipeline 复用的 helper，例如 `process_resolve_path(program, env, cwd)` 或等价接口；不能让 executor 内部私有实现成为事实标准。

`cwd`、`env`、`unset_env` 是 stage-local transformer，作用于最近追加的 process stage。若当前计划尚无 process stage，或最近 stage 是 Uya stage，必须返回 `error.InvalidPipeline`。这样下面的写法含义固定：

```uya
const status_args: [&const byte: 1] = ["status"];

try (pipeline()
    |> cmd_argv("git", &status_args[0:1])
    |> cwd("repo-a")
    |> cmd_argv("git", &status_args[0:1])
    |> cwd("repo-b")
    |> check());
```

`stdin_file` 配置第一段 stage 的 stdin。`stdout_file`、`stdout_capture` 配置最后一段 stage 的 stdout。`stderr_file`、`stderr_capture`、`stderr_to_stdout` 配置整条 pipeline 的 stderr 收集策略；第一版不提供 per-stage stderr redirect。需要精确复刻 shell 的每段 stderr 重定向时，应在后续加入显式 stage handle API，而不是让当前 transformer 静默猜测。

`stdout_file` / `stderr_file` 是 transformer，不执行 pipeline。执行只发生在 sink：`check`、`check_into`、`status_into`、`capture_into`、`capture_limit_into`，以及后续按值返回 facade `status`、`capture`、`capture_limit`。

`stdout_capture` / `stderr_capture` 只是声明哪些终端流需要由 capture sink 收集。`capture_into()` / `capture_limit_into()` 是执行 sink；它们会隐式要求 terminal stdout 为 capture。若调用方已经显式配置 terminal stdout 为 file 或 inherit，再调用 capture sink 必须返回 `error.InvalidPipeline`。stderr 不会被 capture sink 隐式捕获；需要 stderr bytes 时必须显式添加 `stderr_capture()`，或者先用 `stderr_to_stdout()` 合并到 stdout capture。

## 结果模型

执行结果必须能表示“正常退出”和“未能启动”两类状态。推荐公共语义如下；字段形态应使用当前 Uya 可声明的 slice、struct 或 handle 组合，不能照搬伪动态数组语法：

```uya
enum PipelineStageStatusKind {
    not_started,
    spawn_failed,
    exited,
    signaled,
}

struct PipelineStageStatus {
    stage_index: usize,
    kind: PipelineStageStatusKind,
    exit_code: i32,
    signal: i32,
    error_name: &const byte,
}

struct PipelineResult {
    stage_count: usize,
    statuses: &[const PipelineStageStatus],
    pipefail: bool,
}

struct CaptureBuffer {
    captured: bool,
    bytes: &[const byte],
}

struct PipelineCaptureResult {
    result: PipelineResult,
    stdout: CaptureBuffer,
    stderr: CaptureBuffer,
}
```

`not_started` 表示由于更早的计划预检或 stage 启动失败，该 stage 没有被启动。`spawn_failed` 覆盖 PATH lookup 失败、fork / CreateProcess 失败、以及 fork 后 exec 失败并通过 diagnostic pipe 回传的情况。`exited` 使用 `exit_code`；`signaled` 使用 `signal`。未使用字段必须填 0 或空字符串。

上面的 `PipelineResult` / `PipelineCaptureResult` 是公共可读视图，不拥有底层存储。第一版锁定 caller-provided buffer 方案：`check_into` / `status_into` 接收调用方提供的 `statuses` 缓冲区并把 `PipelineResult.statuses` 设为其中已写入的前缀；`capture_into` / `capture_limit_into` 额外接收 `stdout_buf` / `stderr_buf`，并把 `CaptureBuffer.bytes` 设为对应 capture 缓冲区的已写入前缀。结果 slice 只在调用方缓冲区仍然存活且未被复用覆盖时有效，浅拷贝这些 result 只复制视图，不产生所有权或析构责任。

调用方提供的 `statuses` 长度必须至少覆盖 process stage 数量；不足时 sink 返回 `error.InvalidPipeline`，并把输出 result 重置为空视图。`capture_into` 的有效 capture 上限来自调用方提供的 stdout/stderr 缓冲区容量；`capture_limit_into` 使用 `min(max_bytes, buffer.len)` 作为每个 captured stream 的有效上限。未启用 stderr capture 时，`stderr_buf` 可以为空，executor 不得写入未启用 capture 的缓冲区。

如果后续语言具备可靠 drop / move-only result 能力，或结果改为不透明 handle，才可以开放按值返回的 `status()`、`capture()` 和 `capture_limit()` facade；那时必须重新定义所有权转移、clone 与释放规则，不能让 public struct 的 slice 字段浅拷贝成悬垂或双释放风险。

`CaptureBuffer.captured=false` 表示该流没有被 capture sink 收集；此时 `bytes` 必须为空。超过 capture limit 时返回 `error.CaptureLimitExceeded`，不通过 `CaptureBuffer` 表示截断。接收 result 指针的 sink 在返回普通 Uya error 或 `error.CaptureLimitExceeded` 前，必须把输出 result 重置为空视图；`check_into` 返回 `error.ProcessFailed` / `error.PipelineSpawnFailed` 是例外，必须保留已收集的 stage 状态。

空 `PipelineResult` 视图定义为 `stage_count=0`、`statuses` 为空 slice、`pipefail=false`。空 `PipelineCaptureResult` 视图定义为内嵌 `result` 为空视图，且 stdout/stderr 的 `captured=false`、`bytes` 为空 slice。

计划预检和 PATH lookup 应尽量在启动任何子进程前完成。若此阶段发现 PATH 查找失败或 stage 启动条件不满足，observing sink 应写入带 `spawn_failed` / `not_started` 状态的结果并成功返回；checked sink 应返回 `error.PipelineSpawnFailed`，其中 `check_into` 必须先写入 `PipelineResult`。如果错误发生在不属于某个 stage 的基础设施阶段，例如内存分配失败或 pipe 创建失败，则按普通 Uya error 返回，并按上一段规则清空输出 result。

错误分类必须稳定，不能由后端随意决定：

```text
cmd 命令名为空、cmd 名称含路径分隔符                => error.InvalidPipeline
空 pipeline 传给 sink                              => error.InvalidPipeline
PATH 查找失败                                       => PipelineResult spawn_failed/not_started
stage cwd 不存在或无法进入                         => PipelineResult spawn_failed/not_started
fork / CreateProcess 失败                          => PipelineResult spawn_failed/not_started
child-side chdir / execve 失败并经诊断 pipe 回传     => PipelineResult spawn_failed/not_started
stream policy 冲突、错误的 transformer 位置          => error.InvalidPipeline
打开 stdin/stdout/stderr 文件重定向失败              => 普通 Uya error
pipe / diagnostic pipe 创建失败                     => 普通 Uya error
内存分配、平台编码转换失败                           => 普通 Uya error
```

也就是说，`status_into()` / `capture_into()` 对“进程启动链路已经形成但某个 stage 没能启动或退出失败”的情况保持观察型；对执行器自身无法搭建管道拓扑、无法打开用户指定文件或无法分配资源的情况，仍返回普通 Uya error。

## 退出状态策略

执行 sink 分成 checked 和 observing 两类：

- `check()` 使用 `pipefail=true`：任一 stage 非零退出都会返回 `error.ProcessFailed`。
- `check()` 若出现 `spawn_failed` / `not_started` 失败链路，返回 `error.PipelineSpawnFailed`；若所有 stage 均启动但任一 stage 非零退出或 signal 终止，返回 `error.ProcessFailed`。
- `check_into(statuses, result)` 与 `check()` 相同，但无论成功、`error.ProcessFailed` 或 `error.PipelineSpawnFailed`，都必须先把所有可获得的 stage 状态写入 `statuses` 并让 `result` 指向已写入前缀。
- `status_into(statuses, result)` 是观察型 sink：写入完整 `PipelineResult`，但不把非零退出、signal 终止或 stage 启动失败视为 Uya error。
- `capture_into(statuses, stdout_buf, stderr_buf, result)` / `capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)` 是观察型 sink：写入 `PipelineCaptureResult`，其中必须包含 `PipelineResult`，非零退出、signal 终止或 stage 启动失败不映射为 Uya error。

Uya 的 `error` 值本身不携带业务 payload，因此设计不能依赖“error payload”保存 `PipelineResult`。需要失败详情时，调用方必须使用 `check_into`、`status_into`、`capture_into` 或 `capture_limit_into`。

`capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)` 的限制按被捕获的每个流单独计算。任一 captured stream 超过有效限制或调用方缓冲区容量时，executor 必须关闭相关 pipe、reap 已启动子进程、把输出 result 重置为空视图，并返回 `error.CaptureLimitExceeded`；由于 Uya error 不携带 payload，这条错误路径不承诺返回部分输出或完整状态。这是 observing sink 的明确例外：调用方若需要在超限时仍保留诊断状态，应使用文件 sink、更大的 limit，或等待后续显式保留部分结果的 API。

这样可以让脚本默认使用 `check()` 保持安全，同时仍然支持负向测试、探测命令和失败诊断。

## Stdio 策略

终端流策略每个方向只能有一个活跃策略。`unset` 不是策略，而是交给 sink 选择默认值：

```text
stdin:  unset | inherit | file
stdout: unset | inherit | file_truncate | capture
stderr: unset | inherit | file_truncate | capture | merge_stdout
```

第一版公开 API 只暴露上表中的状态。`null` stdin、terminal stdout/stderr null、append file 和 per-stream inherit transformer 可以作为后续扩展加入；加入前不能在冲突表或 public API 中假设它们已经存在。

冲突策略应报错，而不是静默覆盖：

```text
stderr_capture + stderr_file      => error.InvalidPipeline
stderr_capture + stderr_to_stdout => error.InvalidPipeline
stderr_file + stderr_to_stdout    => error.InvalidPipeline
stdout_capture + stdout_file      => error.InvalidPipeline
stdout_file + inherit_stdio       => error.InvalidPipeline
stderr_file + inherit_stdio       => error.InvalidPipeline
stdout_file + capture sink        => error.InvalidPipeline
```

`capture_into(statuses, stdout_buf, stderr_buf, result)` 使用调用方提供的 capture 缓冲区容量作为有效上限；`capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)` 在缓冲区容量之外额外施加 `max_bytes` 上限。第一版不提供隐藏默认 capture limit 常量。大输出应要求更大的调用方缓冲区、显式 limit 或文件 sink。

`check()` / `check_into()` / `status_into()` 对 unset stdout/stderr 默认使用 inherit。`capture_into()` / `capture_limit_into()` 对 unset stdout 默认使用 capture，对 unset stderr 默认使用 inherit。显式 `stdout_capture()` / `stderr_capture()` 要求最终 sink 是 `capture_into()` 或 `capture_limit_into()`；与 `check()` / `status_into()` 组合没有返回 bytes 的路径，必须报 `error.InvalidPipeline`。

`inherit_stdio()` 是显式策略，不是“清空之前配置”的 reset。它要求 stdin、stdout、stderr 三路都尚未设置终端策略，然后把三路都设为 inherit。后续再配置 file/capture 也必须报冲突。

Inter-stage stdout pipe 是执行拓扑的一部分，不受 `stdout_file` 等终端 stdout 策略影响：stage `i` 的 stdout 连接到 stage `i + 1` 的 stdin；只有最后一个 stage 的 stdout 进入终端 stdout 策略。stderr 默认不参与 stage 间数据流。整条 pipeline 的 stderr 策略等价于 shell group 级重定向，例如 `{ a | b; } 2>file` 或 `{ a | b; } 2>&1`，不是 `a 2>&1 | b` 这种 per-stage 数据流。多个 stage 同时写入同一个 stderr file/capture pipe 时，只保证 byte stream 不被 executor 主动重排，不保证跨进程日志行顺序稳定。

## 未来扩展：自定义 Uya Pipeline Stage

自定义流处理通过接口表示。Uya 使用 `struct S : I { ... }` 和方法块实现接口；没有 `impl` 关键字。

自定义 Uya stage 不属于 process-only MVP。第一版应先完成外部进程 pipeline；Uya stage 在 runtime task/thread 执行模型和 stage 所有权规则明确后再开放。fork-backed Uya stage 只能作为受控实验或测试模式，不能作为默认生产实现。本节只描述未来扩展方向，不是 MVP 公共 API。

推荐接口：

```uya
interface PipelineStage {
    fn run(self: &Self, input: &StreamReader, output: &StreamWriter) !void;
}
```

推荐 transformer：

```uya
fn stage<T: PipelineStage>(input: Pipeline, stage: T) !Pipeline;
```

`stage: T` 是有意设计。pipeline 是延迟执行的，因此必须拥有 stage 对象。`stage: &T` 会让 pipeline 在局部对象生命周期结束后仍可能持有悬垂引用。

按值保存 `T` 只拥有 stage 对象本身，不自动拥有对象内部的切片或指针。若 `T` 含有 `&T`、`*T`、slice、接口字段或其他借用式字段，`stage()` 必须满足以下二选一之一：

- 拒绝该类型并返回 `error.InvalidPipeline`。
- 通过显式 `clone` / owned buffer 约定把所有借用数据深拷贝进 pipeline 计划。

文档示例里的字符串字面量具有静态存储期，适合作为 `needle`；来自局部缓冲区的切片不能直接保存在延迟执行的 stage 中。

示例：

```uya
struct ContainsLine : PipelineStage {
    needle: &[const byte],

    fn run(self: &Self, input: &StreamReader, output: &StreamWriter) !void {
        var line: [byte: 4096] = [];
        while true {
            const n = try input.read_line(&line);
            if n == 0 {
                break;
            }
            if bytes_contains(&line[0:n], self.needle) {
                try output.write_all(&line[0:n]);
            }
        }
    }
}

const rg_args: [&const byte: 4] = ["-n", "TODO", "src", "docs"];
const sort_args: [&const byte: 0] = [];

try (pipeline()
    |> cmd_argv("rg", &rg_args[0:4])
    |> stage(ContainsLine { needle: "P8" as &[const byte] })
    |> cmd_argv("sort", &sort_args[0:0])
    |> stdout_file("build/p8_todos.txt")
    |> check());
```

`filter` 可以作为 `stage` 的别名提供，但通用概念是 pipeline stage，而不只是 filter。

## 运行时执行模型

Transformer 是同步计划构造器。它们可以校验输入、复制 argv/path/env 数据、分配计划节点，并拒绝冲突的流策略。它们不能启动进程。

Sink 执行计划。执行时必须先完成不需要启动子进程的预检，再启动所有 pipeline stage，最后等待完成：

```text
build final env/cwd for each process stage
resolve PATH-searching cmd stages through std.process helper
create all inter-stage pipes
start all enabled stages (process stages in the MVP; Uya stages after runtime task/thread support)
close parent copies of unused fds/handles
drive capture readers while children may still be writing
wait for all stages
collect statuses and output
apply sink-specific failure policy
```

executor 不能先把 stage 0 跑完再启动 stage 1。它也不能先等待所有子进程结束再 drain capture pipe。任一顺序在大输出填满 pipe buffer 时都可能死锁。

如果预检阶段发现某个 stage 无法解析或 stage 启动前置条件失败，executor 不应启动任何子进程；结果中该 stage 标记为 `spawn_failed`，其他 stage 标记为 `not_started`。若错误属于前文定义的普通 Uya error，例如 pipe 创建或文件重定向打开失败，则直接返回该错误而不伪造 `PipelineResult`。如果 stage 启动错误发生在部分子进程已启动之后，executor 必须关闭父进程持有的 pipe 端、继续 drain 必要 capture reader、reap 已启动子进程，并为未启动 stage 写入 `not_started`。

### POSIX 后端

进程 stage：

```text
build final argv/envp/cwd, including argv0 prefix
resolve cmd through PATH in parent using final env/cwd
fork
chdir to stage cwd when configured
dup2 stdin/stdout/stderr
close unused fds
execve exec_path argv envp
on execve failure, write errno to diagnostic pipe and _exit(127)
```

`cmd` 不能直接降低为裸 `execve(program, ...)`，因为 `execve` 不做 PATH 查找。推荐执行前在 parent 中按最终 child env 解析 PATH，生成 execution-time `exec_path`，再由 child 使用 `execve(exec_path, ...)`。`cmd_path` 不做 PATH 查找：绝对路径直接作为 `exec_path`；相对路径必须在应用 stage cwd 后解释，POSIX 后端可以在 child `chdir` 后用原相对路径 `execve`，也可以在 parent 以 stage cwd 为基准预解析成等价绝对路径。为了覆盖 TOCTOU、权限变化或 child-side `chdir` / `execve` 失败，父子之间需要一个 close-on-exec diagnostic pipe：exec 成功时 pipe 自动关闭；exec 失败时 child 写入 errno，parent 将该 stage 记为 `spawn_failed`。

process-only MVP 不执行 Uya stage。若后续为了实验加入 fork-backed Uya stage，必须明确标记为非默认路径：

```text
fork
dup2 input/output
call PipelineStage.run(reader, writer)
_exit(0 or 1)
```

fork 后的 Uya stage 不能依赖共享父进程锁、allocator 状态、线程运行时、async runtime 或任何需要回写父进程内存的行为；错误也只能通过退出状态和 stderr/diagnostic pipe 回传。因此它不能作为 `.ush` MVP 的主实现。

长期实现选项：

```text
spawn runtime task/thread
run PipelineStage.run(reader, writer)
close fds/handles on completion
```

### Windows 后端

公共 API 必须保持不变，但后端会把进程 stage 映射到 `CreateProcessW`，并使用继承或复制后的 handle。argv/env 应从 Uya UTF-8 数据转换为 Windows UTF-16；构造 command line 时必须使用明确的 argv quoting 规则，不得隐式调用 `cmd.exe`。Uya stage 应使用运行时线程/任务，而不是假设 fork 语义。

## 内部计划草图

内部表示不是公共 API，但应保留以下概念。下面是伪代码草图，不是可直接复制的 Uya 声明；真实实现应使用当前 Uya 可声明的 slice、固定数组、Vec 或 handle 表示动态列表：

```text
struct PipelinePlan {
    stages: [PipelinePlanStage],
    stdin: StreamSpec,
    terminal_stdout: StreamSpec,
    terminal_stderr: StreamSpec,
    pipefail: bool,
}

struct ProcessStagePlan {
    program_or_path: &const byte,
    args_without_argv0: [&const byte],
    path_lookup: bool,
    cwd: &const byte,
    env_overlay: EnvOverlay,
}

struct ProcessStageExec {
    exec_path: &const byte,
}

enum PipelinePlanStageKind {
    process,
    uya_stage,
}
```

`ProcessStagePlan` 是可 clone 的延迟执行计划，只保存用户传入的命令名或 exact path、去掉 argv0 的 args、cwd 和 env overlay。PATH 解析结果、最终 child argv、以 cwd 为基准解析出的绝对路径、diagnostic pipe 状态和进程 id 都属于单次 sink 调用的 execution state，不能持久化在 plan 中，也不能被 `clone(input)` 浅拷贝。

对于 erased Uya stage，后端可以存储：

```uya
struct ErasedPipelineStage {
    data: *void,
    run_fn: fn(*void, &StreamReader, &StreamWriter) !void,
    clone_fn: fn(*void) !*void,
    drop_fn: fn(*void) void,
}
```

`stage<T: PipelineStage>` 可以降低为一次 `T` 的分配/复制，加上生成的 thunk 函数。若 `T` 不满足深拷贝约束，`clone_fn` 必须缺失并使 `clone(input)` 返回 `error.InvalidPipeline`，或者 `stage()` 直接拒绝该 `T`。

## 必要不变量

- `Pipeline` 对用户不透明。
- `Pipeline` 是 move-only。
- 若底层暂用普通 struct/handle 表示，必须有单所有者或 consumed 兜底，防止浅拷贝后双执行。
- 每个进程 stage 都有非空程序名。
- args/env/cwd/path/stage 数据由计划拥有。
- 最终 child argv 必须由执行器构造，且 `argv[0]` 不来自 `args` slice。
- `cmd_path` 的相对路径按该 stage 的最终 cwd 解释。
- `cwd` / `env` / `unset_env` 只作用于最近追加的 process stage。
- terminal stdout / stderr 每个方向最多有一个活跃策略。
- capture stream policy 只能与 `capture_into` / `capture_limit_into` sink 组合；按值返回 facade 开放后也适用于 `capture` / `capture_limit`。
- `stderr_to_stdout` 与独立 stderr capture/file 策略冲突。
- sink 要求至少有一个可执行 stage；空 pipeline 传给任何 sink 必须返回 `error.InvalidPipeline`。
- 已消费的 pipeline 不能再次执行。
- capture buffer 有界，除非加入并文档化显式无界 API。
- `PipelineCaptureResult` 和 `PipelineResult` 只保存指向调用方缓冲区已写入前缀的非拥有视图；接收 result 指针的 sink 在返回普通 Uya error 或 `error.CaptureLimitExceeded` 前必须重置为空视图。
- 需要失败详情时不能依赖 `error.ProcessFailed` 携带 payload，必须使用 `check_into` / `status_into` / `capture_into` / `capture_limit_into`。

## Parser 和 Type Checker 备注

Lexer：

- 新增明确的 `TOKEN_PIPE_FORWARD`（或等价命名）表示 `|>`。
- 在 lexer 的 `|` 分支中先 peek 后续 `>` 并整体消费为 `TOKEN_PIPE_FORWARD`，否则再返回现有 `TOKEN_PIPE`。不能只在 `>` 分支处理，因为 `|` 一旦被消费，parser 就会把它当成 bit-or / pattern / for 语法的一部分。

Parser：

- 将 `|>` 解析为左结合的 pipeline expression，优先级低于当前 parser 中最低的非赋值表达式层级，高于赋值。若 parser 已有位或层级，`|>` 应低于位或；若 formal grammar 暂未列出位或层级，应先同步 grammar 文档，再按实际 parser 层级落点实现。
- 限制右侧必须是调用表达式。按当前 formal grammar，调用属于 postfix expression，因此实现上应接受外层节点为 call 的 postfix 形式，例如 `f("a")`、`script.f("a")` 或允许的泛型调用形式。
- `|>` 不应复用普通 `AST_BINARY_EXPR` 加一个新 token 的形态，除非所有 checker / codegen / fmt / macro / exec 访问器都显式拒绝或专门处理该 token。推荐新增 `AST_PIPELINE_EXPR`，或者在 parser/checker 边界立即 desugar 成带 synthetic lhs 的 call 节点，避免现有二元运算路径把它当成整数/bitwise 运算。
- 建议 grammar 形态如下；其中 `lowest_non_assign_expr` 代表当前 parser 中 `assign_expr` 之下的完整普通表达式层级，不能因为 formal grammar 暂缺 bit-or 文档而误删实际 parser 已有层级：

```text
expression              = assign_expr
assign_expr             = pipeline_expr [ assign_op assign_expr ]
pipeline_expr           = lowest_non_assign_expr { '|>' postfix_call_expr }
lowest_non_assign_expr  = ... current logical / bitwise expression ladder ...
```

`postfix_call_expr` 不是新的用户语法类别，而是 parser/checker 约束：右侧表达式的最外层必须是 call expression。

这样 `x = pipeline() |> f("a")` 解析为 `x = (pipeline() |> f("a"))`，而 `pipeline() |> f() = x` 会在 checker 阶段因赋值目标非法被拒绝。

Type checker：

- pipeline call 必须在普通 call arity/type check 之前走专门规则：先解析右侧 call 的 callee，查询其签名，把左侧表达式作为 synthetic 第 0 实参参与校验；否则 `cmd_argv("rg", args)` 会被普通 checker 误判为缺少 `input: Pipeline` 或把字符串实参错配到首参。
- 仅当 `lhs` 为 `Pipeline` 或 `!Pipeline`，且 `f` 的首个参数为 `Pipeline` 时，接受 `lhs |> f(args...)`。
- 仅对 `!Pipeline` 插入 try-forward。
- 拒绝 sink 之后继续链式管道，因为左侧不再是 `Pipeline`。
- 对 module-qualified call、方法形态 call、泛型 call 和 varargs facade，必须复用同一套 synthetic 第 0 实参规则；不能让这些 call 先走普通调用错误路径。

Lowering：

- 将表达式降低为普通调用和临时变量。
- `!Pipeline` try-forward 必须通过 AST 或临时变量语义实现，例如先构造 `const tmp: Pipeline = try lhs;` 再调用 `f(tmp, args...)`。实现不得把规则当作文本级 `f(try lhs, args...)` 重新解析，以免受当前 `try` 表达式优先级和泛型调用特殊解析影响。
- 保留 `Pipeline` 的移动语义。
- fmt、macro expand、C99 codegen、exec builder 和错误诊断路径都必须对 `AST_PIPELINE_EXPR` 或 desugared call 有回归覆盖，确保 `|>` 不会落入普通 binary operator 的格式化、类型检查或代码生成分支。

## 未决问题

- `pipefail=true` 是应允许按 pipeline 配置，还是对 `check` / `check_into` 固定。本设计推荐安全默认值，并使用 `status_into()` / `capture_into()` 做观察。
- Uya stage 的 owned-data 约束应通过接口、编译器能力还是运行时校验表达。
- `filter` 是否应保留为 `stage` 的公共别名。
- 其中多少内容应属于 `std.process`，多少内容应属于 `std.script` facade。
