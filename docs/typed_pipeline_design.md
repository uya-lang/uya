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
- 自定义 Uya 流处理通过接口表示，而不是通过 shell 片段表示。

示例：

```uya
try (pipeline()
    |> cmd("rg", "-n", "TODO", "src", "docs")
    |> cmd("sort")
    |> stderr_file("build/todos.err")
    |> stdout_file("build/todos.txt"));
```

语义意图等价于：

```sh
rg -n TODO src docs | sort > build/todos.txt 2> build/todos.err
```

但它不会通过向 shell 发送字符串来实现。

## 目标

1. **没有隐式 shell**

命令是 argv 数组，不是命令字符串。shell 展开、命令替换、glob、alias 和 shell function 都不属于这个模型。

2. **类型化组合**

类型检查器证明每一个 `|>` 链接都接收有效的 `Pipeline` 或 `!Pipeline` 值，并调用首个参数为 `Pipeline` 的函数。

3. **脚本人体工学**

常见 shell 管道模式在 `.ush` 脚本中应足够紧凑。最终 sink 是执行点；常见场景不应要求脚本额外写尾随 `run()`。

4. **可扩展的流处理**

Uya 代码可以通过 `PipelineStage` 接口作为管道 stage 出现。stage 对象可以携带状态与配置。

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
123 |> cmd("sort");      // 左侧不是 Pipeline
"abc" |> trim();         // |> 不是通用数据管道
result |> exit_code();   // 左侧不是 Pipeline
```

### 空 Pipeline 构造器

MVP 应使用显式空 pipeline 构造器作为管道起点：

```uya
pipeline() |> cmd("rg", "TODO")
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
const p: Pipeline = try (pipeline() |> cmd("rg", "TODO"));
const sorted: Pipeline = try (p |> cmd("sort"));
const counted: Pipeline = try (p |> cmd("wc", "-l")); // 错误：p 已被移动
```

如果脚本需要从共同基础派生多个计划，必须显式 clone：

```uya
fn clone(input: &Pipeline) !Pipeline;
```

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

fn cmd(input: Pipeline, program: &const byte, ...) !Pipeline;
fn cwd(input: Pipeline, path: &const byte) !Pipeline;
fn env(input: Pipeline, key: &const byte, value: &const byte) !Pipeline;
fn unset_env(input: Pipeline, key: &const byte) !Pipeline;

fn stdin_file(input: Pipeline, path: &const byte) !Pipeline;
fn stdout_capture(input: Pipeline) !Pipeline;
fn stderr_capture(input: Pipeline) !Pipeline;
fn stdout_file(input: Pipeline, path: &const byte) !PipelineResult;
fn stderr_file(input: Pipeline, path: &const byte) !Pipeline;
fn stderr_to_stdout(input: Pipeline) !Pipeline;

fn capture(input: Pipeline) !PipelineCaptureResult;
fn capture_limit(input: Pipeline, max_bytes: usize) !PipelineCaptureResult;
fn inherit_stdio(input: Pipeline) !PipelineResult;
fn status(input: Pipeline) !PipelineResult;
```

Uya 可变参数写作裸尾随 `...`，不是命名的 `args: ...`。`cmd` 必须校验它的 `@params` 是否为 `&const byte` argv 项，或者提供基于 slice 的 fallback，例如 `cmd_argv(input, program, args)`。

`stdout_file` 是 sink，因为它消费并执行 pipeline。`stderr_file` 是 transformer，因为它配置 stderr 策略并仍然返回 `!Pipeline`。

## 退出状态策略

默认 checked sink 应使用 `pipefail=true` 语义：

- 任一 stage 非零退出都会使 sink 返回 `error.ProcessFailed`。
- error payload 或诊断路径必须保留包含所有 stage 状态的 `PipelineResult`。
- `status()` 是观察型 sink，返回状态但不把非零退出视为错误。

这样可以让脚本默认安全，同时仍然支持负向测试和探测命令。

## Stdio 策略

每个流只能有一个活跃策略：

```text
stdin:  inherit | null | file
stdout: inherit | null | file_truncate | file_append | capture
stderr: inherit | null | file_truncate | file_append | capture | merge_stdout
```

冲突策略应报错，而不是静默覆盖：

```text
stderr_capture + stderr_file      => error.InvalidPipeline
stderr_capture + stderr_to_stdout => error.InvalidPipeline
stderr_file + stderr_to_stdout    => error.InvalidPipeline
stdout_capture + stdout_file      => error.InvalidPipeline
```

capture 必须有有界默认值。大输出或无界输出应要求显式 limit 或文件 sink。

## 自定义 Uya Pipeline Stage

自定义流处理通过接口表示。Uya 使用 `struct S : I { ... }` 和方法块实现接口；没有 `impl` 关键字。

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
            if bytes_contains(line[0..n], self.needle) {
                try output.write_all(line[0..n]);
            }
        }
    }
}

try (pipeline()
    |> cmd("rg", "-n", "TODO", "src", "docs")
    |> stage(ContainsLine { needle: "P8" as &[const byte] })
    |> cmd("sort")
    |> stdout_file("build/p8_todos.txt"));
```

`filter` 可以作为 `stage` 的别名提供，但通用概念是 pipeline stage，而不只是 filter。

## 运行时执行模型

Transformer 是同步计划构造器。它们可以校验输入、复制 argv/path/env 数据、分配计划节点，并拒绝冲突的流策略。它们不能启动进程。

Sink 执行计划。执行时必须先启动所有 pipeline stage，再等待完成：

```text
create all inter-stage pipes
start all process and Uya stages
close parent copies of unused fds/handles
drive capture readers while children may still be writing
wait for all stages
collect statuses and output
apply sink-specific failure policy
```

executor 不能先把 stage 0 跑完再启动 stage 1。它也不能先等待所有子进程结束再 drain capture pipe。任一顺序在大输出填满 pipe buffer 时都可能死锁。

### POSIX 后端

进程 stage：

```text
fork
dup2 stdin/stdout/stderr
close unused fds
execve argv/envp
```

Uya stage 的第一版实现选项：

```text
fork
dup2 input/output
call PipelineStage.run(reader, writer)
_exit(0 or 1)
```

这对 `.ush` MVP 很实用，但 fork 后的 Uya stage 不能依赖共享父进程锁或复杂共享运行时状态。

长期实现选项：

```text
spawn runtime task/thread
run PipelineStage.run(reader, writer)
close fds/handles on completion
```

### Windows 后端

公共 API 必须保持不变，但后端会把进程 stage 映射到 `CreateProcessW`，并使用继承或复制后的 handle。Uya stage 应使用运行时线程/任务，而不是假设 fork 语义。

## 内部计划草图

内部表示不是公共 API，但应保留以下概念：

```uya
struct PipelinePlan {
    stages: [PipelinePlanStage],
    stdin: StreamSpec,
    stdout: StreamSpec,
    stderr: StreamSpec,
    pipefail: bool,
}

enum PipelinePlanStageKind {
    process,
    uya_stage,
}
```

对于 erased Uya stage，后端可以存储：

```uya
struct ErasedPipelineStage {
    data: *void,
    run_fn: fn(*void, &StreamReader, &StreamWriter) !void,
    drop_fn: fn(*void) void,
}
```

`stage<T: PipelineStage>` 可以降低为一次 `T` 的分配/复制，加上生成的 thunk 函数。

## 必要不变量

- `Pipeline` 对用户不透明。
- `Pipeline` 是 move-only。
- 每个进程 stage 都有非空程序名。
- argv/env/cwd/path/stage 数据由计划拥有。
- 每个流最多有一个活跃策略。
- `stderr_to_stdout` 与独立 stderr capture/file/null 策略冲突。
- sink 要求至少有一个可执行 stage，除非后续显式指定空 pipeline 行为。
- 已消费的 pipeline 不能再次执行。
- capture buffer 有界，除非加入并文档化显式无界 API。

## Parser 和 Type Checker 备注

Lexer：

- 在识别单字符 `|` 和 `>` 之前，先加入 `|>` token。

Parser：

- 将 `|>` 解析为低优先级、左结合的 pipeline expression。
- 限制右侧必须是调用表达式。

Type checker：

- 仅当 `lhs` 为 `Pipeline` 或 `!Pipeline`，且 `f` 的首个参数为 `Pipeline` 时，接受 `lhs |> f(args...)`。
- 仅对 `!Pipeline` 插入 try-forward。
- 拒绝 sink 之后继续链式管道，因为左侧不再是 `Pipeline`。

Lowering：

- 将表达式降低为普通调用和临时变量。
- 保留 `Pipeline` 的移动语义。

## 未决问题

- `stdout_file` 是否应作为 sink，或者是否总是要求显式 `status()` sink。本设计为了脚本人体工学选择 `stdout_file` 作为 sink。
- `pipefail=true` 是应允许按 pipeline 配置，还是对 checked sink 固定。本设计推荐安全默认值，并使用 `status()` 做观察。
- POSIX MVP 中 Uya stage 是否应先采用 fork-backed 实现，还是等运行时 task/thread 支持就绪后再做。
- `filter` 是否应保留为 `stage` 的公共别名。
- 其中多少内容应属于 `std.process`，多少内容应属于 `std.script` facade。
