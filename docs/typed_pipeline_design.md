# 类型化管道设计

**状态**：design draft
**更新日期**：2026-07-10
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

> **阶段 0 已锁定**：process-only MVP 的精确范围只包含外部进程 stage；MVP 不实现、不暴露、不测试自定义 Uya 流 stage。`PipelineStage` 接口、`StreamReader` / `StreamWriter` 和 `stage<T: PipelineStage>(input: Pipeline, stage: T) !Pipeline` 等 API 被锁定为未来扩展名称，但不属于 process-only MVP 的公开 API。自定义 Uya stage 只有在以下两个前置条件都满足后才能进入公共 API：
>
> 1. **owned-data 规则确定**：`stage: T` 按值保存于延迟执行计划中，必须明确 `T` 内部切片、指针、接口字段的拥有/深拷贝规则，或拒绝含借用字段的类型；不能遗留悬垂引用或隐式浅拷贝。
> 2. **execution domain 满足强制取消/终止门槛**：必须提供内存安全的强制 task 终止，或把 Uya stage 放入可由宿主强制终止的隔离 worker process；单纯设置 cancellation flag 后 join 的协作式取消不足以继承 process-only pipeline 的有限取消承诺。
>
> 在以上条件满足前，任何 fork-backed Uya stage 只能作为明确标记的实验/测试模式，不能作为默认生产实现。

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

> **阶段 0 已锁定**：`_` 作为 pipeline 占位符语法糖在 process-only MVP 中**延期实现**。第一版 parser/checker 保持空 pipeline 构造显式，使用 `pipeline()` 作为唯一起点，不特殊处理 `_`。`_` 的新语义可在 pipeline 核心稳定后作为独立语法糖追加，追加时必须显式处理与现有 discard assignment、模式、实参位置 `_` 的冲突，并限制其仅出现在 `|>` 右侧调用表达式的第一个 `Pipeline` 实参位置。

## Pipeline 类型

`Pipeline` 是由 `std.process` 拥有的抽象 move-only 执行计划。

> **阶段 0 已锁定**：公开 `Pipeline` 必须依赖真正 opaque / non-copyable 类型能力；普通 `export struct` 或 raw pointer handle 不得作为稳定 API。

当前 Uya 源码尚不支持如下形式的可工作声明：

```text
type Pipeline = opaque std.process.Pipeline;
```

当前 Uya 只有声明级 `export`，没有结构体字段级私有性；因此“导出普通 struct/裸指针 handle，再通过 `std.script` facade 隐藏字段”不能满足本设计的不透明性要求。公开 `Pipeline` API 的前置条件是编译器先具备真正的 opaque、non-copyable 类型能力，并让 checker 按规范声明身份而不是按未限定名称 `Pipeline` 识别该类型。内部 bring-up 可以暂用带 generation 校验的整数 capability + 私有注册表，但这种表示必须拒绝伪造、过期和重复消费的 capability，且在完成真正 opaque 类型前不能作为稳定公共 API 发布。导出的 raw pointer 字段或可任意构造的普通 struct 不属于可接受实现。

> **阶段 0 已锁定**：若内部 bring-up 使用 capability handle 表示 `Pipeline`，必须满足以下全部规则。
>
> 1. **Capability 形式**：handle 是由内部 `std.process` 模块生成的整数索引 + monotonic generation 组合。索引指向进程内私有注册表（不暴露给 `std.script` 或其他模块）中的 live slot；generation 在 slot 分配时递增，并在 slot 释放后保留为墓碑值。
> 2. **私有注册表**：注册表由 `std.process` 内部静态拥有，不提供公共查询、枚举或构造接口。调用方无法通过常量、算术、转换或内存伪造获得合法 capability。
> 3. **拒绝伪造**：任何不是由内部 API 分配的 capability 值（包括全零、越界索引、与当前 slot generation 不匹配的索引、来自其他进程的 capability）必须被识别为无效，并稳定返回 `error.InvalidPipeline`。
> 4. **拒绝过期**：已 `drop`、已消费或被显式释放的 slot 必须保持墓碑 generation；后续对该 capability 的访问必须因为 generation 不匹配而返回 `error.InvalidPipeline`，不得解引用已释放内存或复用被新分配占用的 slot。
> 5. **拒绝重复消费**：transformer 和 sink 必须在消费 input 的同时使原 capability 失效；同一个 capability 不能两次进入会读取或修改注册表的 API。运行时应在消费点原子地标记 slot 为已消费/释放，并校验调用方传入的 capability 尚未处于已消费状态。
> 6. **防御层定位**：运行时 capability 校验只作为对编译器移动检查缺陷、内存破坏或实现错误的纵深防御，不能替代静态 move-only / non-copyable 语义。
> 7. **公开 API 仍等待 opaque 类型**：capability handle 及其私有注册表属于内部实现细节，不得出现在任何 `export` 类型签名、脚本可见的 struct 字段或文档化公共函数参数中。在所有公共 API 中，`Pipeline` 仍必须表现为不透明、不可由脚本构造、不可按值复制的抽象。
> 8. **并发安全**：私有注册表的分配、查找、消费和释放操作必须保证线程安全；同一进程内多个线程可并发构造、消费或查询 pipeline，但同一 capability 的重复消费必须被互斥或原子状态检查阻止。

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

第一版必须把 `Pipeline` 接入 opaque / non-copyable 移动检查。该规则也覆盖 `!Pipeline` 的成功载荷：从 `!Pipeline` 执行 try-forward 时，成功载荷只能被提取和移动一次。运行时 consumed / generation 校验只能作为抵御编译器缺陷和失效 capability 的防御层，不能替代静态移动语义。

资源生命周期锁定如下：

> **阶段 0 已锁定**：transformer 与 sink 在所有返回路径上都必须消费 input；成功路径转移计划所有权，失败路径必须在返回前释放输入计划及本次调用已分配的资源。未进入 sink 的 live pipeline 离开作用域时，自动 `drop` 必须释放 argv、env、stream policy 和 stage 存储，不得要求脚本作者手动调用析构函数。

- `pipeline()` 返回一个 live、未消费的空计划。
- transformer 在所有返回路径上都消费 `input`。成功时把计划所有权转移到返回的 `Pipeline`；失败时必须释放输入计划及本次调用已经分配的资源，调用方不能继续使用旧值。
- sink 在成功或失败路径上都消费计划。若已经启动进程，sink 必须先完成取消/关闭/reap，再释放计划和 execution state。
- live pipeline 未进入 sink 就离开作用域时，自动 `drop` 必须释放 argv、env、stream policy 和 stage 存储；不得要求脚本作者手动调用析构函数。
- 已消费或已 drop 的 capability 再次使用必须稳定返回 `error.InvalidPipeline`，不得解引用过期内存。

`clone` 是唯一显式复制入口。

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

推荐的基础 API（名称已锁定为最终公共名）。**阶段 0 已锁定**：process-only MVP 必须先实现 `cmd_argv` / `cmd_path_argv` 这类 slice 形式的基础 API；裸变参 `cmd` / `cmd_path` 不是 MVP 的公开入口，仅在编译器补齐 typed varargs materialization 后作为 facade 开放。

```uya
fn pipeline() Pipeline;
fn stage_count(input: &Pipeline) !usize;
fn clone(input: &Pipeline) !Pipeline;

fn cmd_argv(input: Pipeline, program: &const byte, args: &[&const byte]) !Pipeline;
fn cmd_path_argv(input: Pipeline, path: &const byte, args: &[&const byte]) !Pipeline;

// 后续 facade；不属于缺少 typed varargs materialization 时的 MVP。名称同样锁定。
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
fn status(input: Pipeline) !OwnedPipelineResult;
fn capture(input: Pipeline) !OwnedPipelineCaptureResult;
fn capture_limit(input: Pipeline, max_bytes: usize) !OwnedPipelineCaptureResult;
```

> **阶段 0 已锁定**：`capture_into(input, statuses, stdout_buf, stderr_buf, result)` 与 `capture_limit_into(input, max_bytes, statuses, stdout_buf, stderr_buf, result)` 为观察型（observing）sink，执行 pipeline 并将完整结果写入调用方缓冲区。返回的 `PipelineCaptureResult` 内嵌完整 `PipelineResult`（含 `stage_count`），并分别通过 `CaptureStreamResult` 摘要 stdout / stderr 捕获状态与字节数；不保存指向调用方缓冲区的借用。

> **阶段 0 已锁定**：`stage_count(input: &Pipeline) !usize` 在 sink 前提供不消费、不执行的精确容量查询；空计划返回 0，无效 / 过期 / 伪造 capability 返回 `error.InvalidPipeline`。

`stage_count(input)` 是不消费、不执行计划的只读查询，返回当前计划中的完整可执行 stage 数量；空计划返回 0。使用 caller-provided `statuses` 的调用方必须在所有 transformer 完成后、sink 消费计划前通过 `try stage_count(&pipeline)` 查询该值并据此分配缓冲区。查询不得缓存 execution-time 状态，也不得改变后续 sink 结果。若内部 capability 已失效、过期或被伪造，查询返回 `error.InvalidPipeline`；因此它必须保留 `!usize` 错误通道，不能用 0 混淆“合法空计划”和“无效 capability”。这样即使 pipeline 由通用 helper 动态追加 stage，调用方也不需要猜测容量；容量不足仍属于调用方错误，但不再是无法预知且无法重试的协议。

Uya 可变参数写作裸尾随 `...`，不是命名的 `args: ...`。当前 C99 codegen 中 `@params` 只稳定 materialize 固定形参；`...` 主要用于 C varargs 转发，不能当作可枚举、可类型检查、可保存生命周期的 Uya argv 列表。因此 process-only MVP 不应要求 `cmd(input, program, ...)` 直接读取 `@params`。

第一版必须先实现 `cmd_argv` / `cmd_path_argv` 这类 slice 形式的基础 API。裸变参 `cmd` / `cmd_path` 只有在编译器补齐 typed varargs materialization 后才能开放为公共 facade。

> **阶段 0 已锁定**：若开放裸变参 `cmd(input, program, ...)` / `cmd_path(input, path, ...)`，`@params` 数组包含全部固定形参，即索引 0 为 `input`、索引 1 为 `program` / `path`；实现 materialization 时必须显式跳过这两个固定位置，从索引 2 开始枚举剩余实参，并逐项校验类型为 `&const byte`。不能把整个 `@params` 当作 argv 列表，也不能假设 `@params[0]` 或 `@params[1]` 是可变参的一部分。process-only MVP 不要求该能力，实现应优先暴露 `cmd_argv` / `cmd_path_argv`；`cmd` / `cmd_path` 仅作为后续 typed varargs 完备后的 facade。

> **阶段 0 已锁定**：`cmd_argv` / `cmd` 是 PATH-searching API：它只接受平台定义的 bare command name，存储该名称，并在执行时按该 stage 的最终 child env 进行 PATH 查找；它不做 shell 展开、glob、alias 或函数查找。POSIX bare name 不得包含 `/`；Windows bare name 不得包含 `/`、`\`、drive/namespace 前缀或 `:`。若调用方要传绝对路径、相对路径或已经解析出的可执行文件，必须使用 `cmd_path_argv` / `cmd_path`。

> **阶段 0 已锁定**：`cmd_path_argv` / `cmd_path` 是 exact-path API：路径中不做 PATH 查找。绝对路径按原样执行；相对路径按该 stage 的最终 cwd 解释，若没有显式 `cwd()` 则按调用 pipeline sink 时的宿主进程 cwd 解释。实现不得在 transformer 调用时把相对 `cmd_path` 绑定到当前父进程 cwd，因为后续 `cwd()` transformer 仍可改变该 stage 的执行目录。Windows 的 drive-relative 形式（例如 `C:tool.exe`）依赖进程级 per-drive cwd，无法由本设计的单一 cwd 快照稳定解释，因此 `cmd_path`、`cwd` 和 file-redirection path 都必须在外部副作用前以 `error.InvalidPipeline` 拒绝这种形式；`C:\tool.exe`、UNC/namespace absolute path 和不带 drive prefix 的普通相对路径仍按各自规则处理。

`cmd_argv` / `cmd_path_argv` 的 `args` 不包含 child `argv[0]`。执行器构造最终 argv 时必须显式前置一个 `argv0`：`cmd_argv` 使用 `program` 本身，`cmd_path_argv` 使用调用方传入的 `path` 本身。若后续需要伪装或自定义 `argv[0]`，应添加单独的 `cmd_argv0` / `cmd_path_argv0` API，不能改变现有 `args` 语义。

### PATH helper 接口

PATH 查找由 `std.process` 内部的平台敏感 helper 执行，并同时供 pipeline executor、`std.path` 和其他需要一致 PATH 语义的内部模块复用。阶段 0 锁定的 helper 接口形如：

```uya
/// Resolve a bare command name to an executable path using the stage's final env and cwd.
/// program: bare command name already validated to contain no path separators.
/// env:     immutable child env block after all env/unset_env overlays have been applied.
/// cwd:     final stage cwd used to interpret empty/relative PATH components and to reject
///          platform-relative forms that cannot be stably resolved.
fn process_resolve_path(program: &const byte, env: &EnvBlock, cwd: &const byte) !ProcessResolvePathResult;
```

`EnvBlock` 表示由 `std.env` 的 child-only env builder 生成的、以 null 结尾的不可变环境变量块；helper 对其只读访问，仅用于读取 `PATH`。`ProcessResolvePathResult` 承载以下结果之一：

- 成功：返回解析出的可执行文件路径 `exec_path`。
- `path_not_found`：`PATH` 缺失、为空，或按规则搜索后没有任何候选存在。
- `permission_denied`：至少一个候选存在，但因权限、目录类型或其他 lookup 阶段可判定的条件不可用。
- 其他可映射到 `PipelineSpawnFailureKind` 的 lookup 阶段具体失败类别；无法可靠映射时使用 `platform_error`，并保留原始平台码用于诊断。

PATH lookup 和最终 spawn 必须使用同一个解析出的 `exec_path`，但 child / `CreateProcessW` 仍需报告 TOCTOU 之后的真实启动失败（映像格式错误等属于 `exec_failed`，不在 helper 中返回）。

> **阶段 0 已锁定**：`process_resolve_path` 的 lookup 阶段只负责判定“按 env/cwd 能否找到可执行文件路径”，其稳定失败分类如下：
>
> - `path_not_found`：`PATH` 缺失、为空，或按规则搜索后没有任何候选存在。
> - `permission_denied`：至少一个候选存在，但因权限不足、候选为目录、候选不可执行（POSIX）或其他 lookup 阶段可判定的条件而不可用。
> - `platform_error`：lookup 阶段遇到无法稳定归类为前两项的平台错误；保留原始平台码用于诊断。
>
> lookup 阶段不返回 `cwd_unavailable`、`process_create_failed`、`execution_domain_failed`、`stdio_setup_failed` 或 `exec_failed`：这些属于 spawn 阶段。`cwd_unavailable` 由最终 stage cwd 的校验或 child-side `chdir` 失败产生；`process_create_failed` 由 `fork` / `CreateProcessW` 本身失败产生；`execution_domain_failed` 由 `setpgid`、child signal setup、launch barrier、Job assignment 或 primary thread resume 失败产生；`stdio_setup_failed` 由 child-side `dup2` 或 Windows stdio handle 安装失败产生；`exec_failed` 由已创建 child 但 `execve` / 启动映像失败产生。lookup 成功后到实际启动之间的 TOCTOU 失败统一归入 spawn 阶段报告。

> **阶段 0 已锁定**：`process_resolve_path` 的搜索规则如下：
>
> - PATH 缺失表示没有搜索目录并返回 `path_not_found`，不注入宿主实现自选的默认目录。
> - POSIX 使用 `:` 分隔；Windows 使用 `;` 分隔。空 component 明确表示该 stage 的最终 cwd，relative component 也以最终 cwd 为基准；除此之外不隐式把当前目录插入搜索序列。
> - POSIX 按 component 顺序尝试 bare name，并要求候选是可执行的非目录文件。Windows 对每个 component 先尝试调用方给出的 bare name；若名称没有扩展名，再尝试追加 `.exe`，比较扩展名时不区分大小写。MVP 不把 `.bat` / `.cmd` 当作可直接执行映像，也不为了 PATHEXT 条目隐式调用 `cmd.exe`。
> - 若没有候选存在，返回 `path_not_found`；若至少一个候选存在但都因权限、目录类型或其他 lookup 阶段可判定的条件不可用，返回最具体的稳定失败类别，例如 `permission_denied`，并保留所选平台码。映像格式错误等只能在 `execve` / `CreateProcessW` 时确认的失败属于 `exec_failed`。PATH lookup 和最终 spawn 使用同一个解析出的 `exec_path`，但 child/CreateProcess 仍需报告 TOCTOU 后的真实启动失败。

所有 process stage 在 sink 开始执行时共享同一个 canonical base-env 快照。该快照来自 `std.env` 的当前进程环境视图，不在 transformer 调用时捕获，也不能通过临时修改父进程全局环境再回滚来模拟。每个 stage 在该快照上按 transformer 调用顺序应用自己的 `env` / `unset_env`：后一次 `env` 覆盖同名旧值，`unset_env` 删除继承或更早设置的值，删除后再次 `env` 表示重新加入；最终 child env 中同一个 key 最多出现一次。POSIX key 比较按 byte 精确匹配；Windows key 比较使用平台 ordinal case-insensitive 规则，因此 `Path` / `PATH` 属于同一个 key，最后一次写入的 spelling/value 获胜。Windows bridge 必须把最终 UTF-16 environment block 按同一 case-insensitive 顺序排序并以双 `\0` 结束，不能把多个大小写变体传给 child。

`env` / `unset_env` 必须复用 `std.env` 的校验规则：key 非空且不含 `=`，value 不得为 null；非法输入返回对应的 `error.EnvInvalidName` / `error.EnvInvalidValue`，而不是延迟到 child 启动。transformer 阶段即调用 `std.env` 的 `env_key_valid` 等效检查并校验 `value != null`，校验通过后立即把 key/value 复制进计划私有存储；`unset_env` 同样复制 key。计划不保存调用方传入字符串的借用，后续 PATH 查找与最终 spawn 使用同一份已完成 overlay 的不可变 env block。PATH 解析与最终 spawn 必须使用同一份已经完成 overlay 的不可变 env block，避免查找时环境与 exec 时环境不一致。

> **阶段 0 已锁定**：`cwd`、`env`、`unset_env` 是 stage-local transformer，作用于最近追加的 process stage。若当前计划尚无 process stage，或最近 stage 是 Uya stage，必须返回 `error.InvalidPipeline`。
>
> 这样下面的写法含义固定：

```uya
const status_args: [&const byte: 1] = ["status"];

try (pipeline()
    |> cmd_argv("git", &status_args[0:1])
    |> cwd("repo-a")
    |> cmd_argv("git", &status_args[0:1])
    |> cwd("repo-b")
    |> check());
```

> **阶段 0 已锁定**：`stdin_file` 配置第一段 stage 的 stdin。`stdout_file`、`stdout_capture` 配置最后一段 stage 的 stdout。`stderr_file`、`stderr_capture`、`stderr_to_stdout` 配置整条 pipeline 的 stderr 收集策略；第一版不提供 per-stage stderr redirect。需要精确复刻 shell 的每段 stderr 重定向时，应在后续加入显式 stage handle API，而不是让当前 transformer 静默猜测。

`stdout_file` / `stderr_file` 是 transformer，不执行 pipeline。执行只发生在 sink：`check`、`check_into`、`status_into`、`capture_into`、`capture_limit_into`，以及后续按值返回 facade `status`、`capture`、`capture_limit`。

> **阶段 0 已锁定**：`stdout_file(input, path)` / `stderr_file(input, path)` 是 stream policy transformer，不是 sink。它们只把对应终端流配置为按 `path` 做文件重定向，返回修改后的 `Pipeline`，不会启动任何子进程或打开文件。文件打开、路径按 sink-time cwd 快照解释、与 capture/inherit 等策略的冲突检查，全部推迟到 sink 执行阶段处理；transformer 阶段仅复制并保存 `path`。

> **阶段 0 已锁定**：`stdout_capture` / `stderr_capture` 只是声明哪些终端流需要由 capture sink 收集。`capture_into()` / `capture_limit_into()` 是执行 sink；它们会隐式要求 terminal stdout 为 capture。若调用方已经显式配置 terminal stdout 为 file 或 inherit，再调用 capture sink 必须返回 `error.InvalidPipeline`。stderr 不会被 capture sink 隐式捕获；需要 stderr bytes 时必须显式添加 `stderr_capture()`，或者先用 `stderr_to_stdout()` 合并到 stdout capture。

## 结果模型

执行结果必须能表示 process stage 的正常退出/信号终止/未能启动，以及未来 Uya stage 的正常完成/错误返回。推荐公共语义如下；字段形态应使用当前 Uya 可声明的 slice、struct 或 handle 组合，不能照搬伪动态数组语法：

```uya
enum PipelineStageStatusKind {
    not_started,
    spawn_failed,
    cancelled,
    exited,
    signaled,
    completed,
    stage_failed,
}

> **阶段 0 已锁定**：`completed` 表示 Uya stage 正常返回，无额外 payload。
> **阶段 0 已锁定**：`stage_failed` 表示 Uya stage 返回 Uya error；`PipelineStageStatus.error_name` 保存稳定的语言级错误名，必须指向程序期静态/驻留字符串，不能指向 execution-state 临时缓冲区。

enum PipelineSpawnFailureKind {
    none,
    path_not_found,
    cwd_unavailable,
    permission_denied,
    process_create_failed,
    execution_domain_failed,
    stdio_setup_failed,
    exec_failed,
    platform_error,
}

> **阶段 0 已锁定**：`PipelineSpawnFailureKind` 枚举值与 `PipelineStageStatus.platform_code` 字段已冻结。
> `spawn_failure` 提供跨平台稳定失败类别，`platform_code` 仅保存 POSIX `errno` 或 Windows `GetLastError()` 作诊断用途，无适用平台码时为 0。
> 跨平台控制流只能依赖 `spawn_failure`，不得依赖 `platform_code` 数值。

struct PipelineStageStatus {
    stage_index: usize,
    kind: PipelineStageStatusKind,
    exit_code: u32,
    signal: i32,
    spawn_failure: PipelineSpawnFailureKind,
    platform_code: u32,
    error_name: &const byte,
}

struct PipelineResult {
    stage_count: usize,
}

struct CaptureStreamResult {
    captured: bool,
    byte_count: usize,
    complete: bool,
}

struct PipelineCaptureResult {
    result: PipelineResult,
    stdout: CaptureStreamResult,
    stderr: CaptureStreamResult,
}
```

> **阶段 0 已锁定**：`CaptureStreamResult.byte_count` 为 `usize`，表示在对应 stream policy 为 capture 时已写入调用方缓冲区的字节数；非 capture 路径、空摘要、预检失败、未观察到 EOF 的成功 observing 返回以及 `CaptureLimitExceeded` 路径均按规则为 `0`。`capture_into` / `capture_limit_into` 返回后，调用方通过 `stdout_buf[0:result.stdout.byte_count]` 与 `stderr_buf[0:result.stderr.byte_count]` 取得有效前缀；result 不保存指向缓冲区的借用。
>
> **阶段 0 已锁定**：`CaptureStreamResult.complete` 只有 executor 确实观察到对应 stream 的 EOF 时才为 `true`；正常 direct-stage cutoff（`EAGAIN`、drain budget 耗尽或 capture limit 触发的 `CaptureLimitExceeded` 路径）必须显式为 `false`，不得因数据已填满缓冲区或未等待到 EOF 而静默声称完整。
>
> **阶段 0 已锁定**：`PipelineCaptureResult` 仅保存内嵌 `PipelineResult` 与两路 `CaptureStreamResult` 的长度/状态摘要，不保存指向 `stdout_buf` / `stderr_buf` 或调用方任何其他缓冲区的 slice、指针或其他借用。调用方通过自己持有的缓冲区和 `result.stdout.byte_count` / `result.stderr.byte_count` 取得有效前缀；`PipelineCaptureResult` 可独立复制或保留，不延长缓冲区生命周期，也不形成函数签名无法表达的跨参数借用。

`CaptureStreamResult.captured` 的语义由 stream policy 决定，而不是由实际读取到的字节数决定：

- 当对应 stream 的 policy 为 capture 时，`captured` 为 `true`；此时 `byte_count` 表示已写入调用方缓冲区的字节数，`complete` 表示是否已观察到 EOF。
- 当 stream policy 不是 capture（例如 inherit、file、discard、通过 `stderr_to_stdout()` 合并到另一路等）时，`captured` 为 `false`；此时 `byte_count` 必须为 0、`complete` 必须为 false。
- 对成功返回的 observing capture sink，即使预检失败、pipe 未创建或没有 stage 越过执行释放边界，只要 policy 是 capture，`captured` 仍为 `true`，`byte_count=0`、`complete=false`。
- 返回普通 Uya error、`error.Interrupted` 或 `error.CaptureLimitExceeded` 前，输出 result 会被重置为空摘要，因此这些路径下 `captured=false`。

> **阶段 0 已锁定**：`PipelineResult` 只保存 `stage_count` 摘要，不保存指向调用方 `statuses` 缓冲区的 slice、指针或其他借用；`PipelineResult.stage_count` 与调用方 `statuses` 缓冲区覆盖完整可执行 stage 列表；`PipelineStageStatus.stage_index` 使用完整 stage 列表的零基索引，混合 process/Uya stage 时不得压缩编号。

公共状态使用平台中立的“执行释放边界”，它表示 executor 已经允许 stage 进入可能执行用户代码的阶段，不声称用户指令已经实际运行：POSIX process stage 在成功消费自己的 `RUN` token 后越过该边界；Windows process stage 在 `ResumeThread` 成功并使 primary thread suspend count 归零后越过；未来 Uya stage 在 runtime/worker 确认开始调用 `PipelineStage.run` 时越过。`not_started` 表示 stage 因更早的预检、启动失败或执行器取消而没有越过该边界。`spawn_failed` 只用于 process stage，覆盖 PATH lookup 失败、fork / CreateProcess 失败、执行域或 stdio setup 失败，以及 POSIX 已消费 RUN 但后续 chdir/dup2/exec 失败并通过 startup diagnostic 回传的情况。`cancelled` 表示 stage 已越过执行释放边界，但在尚未自然完成时被 executor 因其他 stage 启动失败、stage 错误或 sink 中断而强制终止；它不保证用户映像已经执行。若 executor 发起取消前已经观察到自然完成状态，则保留 `exited` / `signaled` / `completed` / `stage_failed`，不能覆盖成 `cancelled`。

`spawn_failed` 的 `spawn_failure` 必须保存稳定、跨平台的失败类别，`platform_code` 可保存 POSIX errno 或 Windows `GetLastError()` 值用于诊断，没有适用平台码时为 0。跨平台逻辑只能依赖 `spawn_failure`，不能依赖 `platform_code` 数值。`exited` 和 `signaled` 只用于 process stage，分别使用 `exit_code` 和 `signal`。`exit_code` 使用 `u32`：POSIX 的正常退出值以 0..255 扩宽保存，Windows 必须原样保存 `GetExitCodeProcess` 返回的完整 `DWORD` bit pattern；跨平台成功判断统一为 `exit_code == 0u32`。`signaled` 保存 `signal: i32`：POSIX 上为实际导致子进程终止的正 signal number（如 `SIGTERM=15`、`SIGKILL=9`、`SIGSEGV=11`），没有 signal number 的 platform-specific 终止原因不得映射为 `signaled`；Windows process stage 没有 POSIX 信号语义，process-only MVP 中 Windows 子进程的全部 `GetExitCodeProcess` 结果一律以 `exited` + `exit_code` 表示，只有 runtime/executor 显式将某个平台终止原因分类为 signal 时才允许使用 `signaled`，且必须在文档中显式声明映射。非 `signaled` 状态的 `signal` 字段必须为 0。跨平台逻辑只能把 `signal` 作为诊断信息，不能依赖 signal 数值做控制流。`completed` 表示 Uya stage 正常返回；`stage_failed` 表示 Uya stage 返回 Uya error，并通过 `error_name` 保存稳定的语言级错误名；该名字必须指向程序期静态/驻留字符串，不能指向 execution-state 临时缓冲区。`cancelled`、`not_started` 及其他非 `spawn_failed` 状态的 `spawn_failure` 必须为 `none`、`platform_code` 必须为 0；其他未使用字段也必须填 0 或空字符串。

`cancelled` 不是独立的 sink 失败原因；保留下来的结果中它必须伴随能够解释取消来源的 `spawn_failed`、`not_started` 或 `stage_failed` 状态。executor interruption 和普通基础设施错误按规则返回空摘要，因此不会只留下无法解释来源的 `cancelled` 列表。

上面的 `PipelineResult` / `PipelineCaptureResult` 只保存可复制的长度与状态摘要，不保存指向调用方缓冲区的 slice、指针或其他借用。第一版锁定 caller-provided buffer 方案：`check_into` / `status_into` 把完整 stage 状态写入调用方的 `statuses`，返回后有效前缀固定为 `statuses[0:result.stage_count]`；`capture_into` / `capture_limit_into` 额外把输出写入 `stdout_buf` / `stderr_buf`，有效前缀分别为 `stdout_buf[0:result.stdout.byte_count]` 和 `stderr_buf[0:result.stderr.byte_count]`。对 captured stream，`complete=true` 才表示已经观察到 EOF、返回前缀包含该 stream 的完整字节序列；`complete=false` 表示 executor 在收尾 drain 的 `EAGAIN` 或固定预算边界处仍未观察到 EOF并关闭了读端，调用方仍可使用已返回前缀，但必须把它视为显式不完整结果。因此 result 可以独立复制或保留，不会延长缓冲区生命周期，也不会形成函数签名无法表达的跨参数借用关系；缓冲区内容本身仍由调用方拥有。

调用方提供的 `statuses` 长度必须至少覆盖全部可执行 stage 数量，`PipelineResult.stage_count` 等于该数量，也等于成功或 checked-stage-error 返回时已经初始化的 statuses 前缀长度；process-only MVP 中它自然等于 process stage 数量。调用方通过非消费型 `try stage_count(&pipeline)` 查询所需容量。`stage_index` 是完整 pipeline stage 列表中的零基索引，混合 process/Uya stage 时不得重新压缩编号。缓冲区不足时 sink 必须在启动任何 stage 前返回 `error.InvalidPipeline`，消费计划并把输出 result 重置为空摘要；实现不得在发现容量不足前产生文件截断、创建子进程等外部副作用。

所有 caller-provided writable region 必须在执行前验证为两两不重叠：`statuses`、启用 capture 的 `stdout_buf` / `stderr_buf`，以及 `result` 指向的固定大小对象都不能共享任何字节；零长度 region 不参与重叠判断。当前 Uya 签名本身不能证明这一点，因此发现重叠时返回 `error.InvalidPipeline`、消费计划并保持空 result，且不得打开文件或启动 stage。需要把 stderr 合并进 stdout 时只能使用 `stderr_to_stdout()`，不能通过给两路 capture 传入同一缓冲区模拟。

`capture_into` 的有效 capture 上限来自调用方提供的 stdout/stderr 缓冲区容量；`capture_limit_into` 使用 `min(max_bytes, buffer.len)` 作为每个 captured stream 的有效上限。未启用 stderr capture 时，`stderr_buf` 可以为空，executor 不得写入未启用 capture 的缓冲区。

> **阶段 0 已锁定**：当某个 stream 的 `byte_count` 已达到有效上限但尚未观察到 EOF 时，reader 不得停止 drain 后直接等待 child；它必须继续在事件循环中用独立的一字节 scratch 做 exact-fit overflow probe。probe 返回 EOF 表示输出恰好等于上限，该 stream 可设置 `complete=true`；读到一个字节表示实际输出超过上限，立即进入 `CaptureLimitExceeded` 取消路径；`EAGAIN` 表示继续等待后续可读/EOF 事件，或在全部直接 stage 已结束后按正常最终 drain budget 返回 `complete=false`。该 scratch 字节不写入调用方缓冲区。

> **阶段 0 已锁定**：按值返回的 facade `status()`、`capture()` 和 `capture_limit()` 不得复用仅含长度/状态摘要的 `PipelineResult` / `PipelineCaptureResult` 类型。它们必须返回独立的 `OwnedPipelineResult` / `OwnedPipelineCaptureResult`（或等价不透明 handle），由 facade 自行分配并持有完整的 `statuses` 数组、captured stdout/stderr 字节缓冲区以及内嵌 `PipelineResult` / `PipelineCaptureResult` 摘要，再通过所有权转移交给调用方。`OwnedPipelineResult` / `OwnedPipelineCaptureResult` 必须附带明确的 drop/释放规则；若语言支持 move-only 类型，则它们为 move-only 且 drop 自动释放内部数据；若为不透明 handle，则必须提供对应的释放 API。clone 行为必须显式文档化，默认不实现隐式浅拷贝，因为内部数据可能包含动态分配或平台句柄。在语言/运行时具备这些能力之前，`status()` / `capture()` / `capture_limit()` 不能作为公共 API 开放。

`CaptureStreamResult.captured=false` 表示该流没有被 capture sink 收集；此时 `byte_count` 必须为 0、`complete` 必须为 false。captured stream 只有在实际读到 EOF 时才能设置 `complete=true`；因 normal direct-stage cutoff 在 `EAGAIN` 或 drain budget 处关闭时必须设置 `complete=false`，不能静默声称完整。超过 capture limit 时返回 `error.CaptureLimitExceeded`，不通过 `CaptureStreamResult` 表示截断。接收 result 指针的 sink 在返回普通 Uya error、`error.Interrupted` 或 `error.CaptureLimitExceeded` 前，必须把输出 result 重置为空摘要；`check_into` 返回 `error.ProcessFailed` / `error.PipelineSpawnFailed` / `error.PipelineStageFailed` 是例外，必须保留已经写入 statuses 的完整 stage 摘要。

对成功返回的 observing capture sink，只要对应 stream policy 是 capture，`captured` 就必须为 true，即使预检阶段已经得到 `spawn_failed`、没有创建 pipe 或没有 stage 越过执行释放边界。此时 `byte_count=0` 且 `complete=false`，因为没有观察到 EOF。部分启动或未来 Uya stage 错误触发统一取消时也遵循同一规则：只有取消和有限 drain 期间实际观察到 EOF 才能 `complete=true`，否则保留已写入前缀并返回 `complete=false`。返回 `Interrupted`、普通基础设施错误或 `CaptureLimitExceeded` 时仍按空摘要规则处理，不暴露部分 capture。

空 `PipelineResult` 摘要定义为 `stage_count=0`。空 `PipelineCaptureResult` 摘要定义为内嵌 `result.stage_count=0`，且 stdout/stderr 的 `captured=false`、`byte_count=0`、`complete=false`。

计划预检和 PATH lookup 应尽量在启动任何子进程前完成。若此阶段发现 PATH 查找失败或 stage 启动条件不满足，observing sink 应写入带 `spawn_failed` / `not_started` 状态的结果并成功返回；checked sink 应返回 `error.PipelineSpawnFailed`，其中 `check_into` 必须先写入 `PipelineResult`。如果错误发生在不属于某个 stage 的基础设施阶段，例如内存分配失败或 pipe 创建失败，则按普通 Uya error 返回，并按上一段规则清空输出 result。

> **阶段 0 已锁定**：空 pipeline 传给任何 sink 必须返回 `error.InvalidPipeline`。此规则覆盖 `check()` / `check_into()` / `status_into()` / `capture_into()` / `capture_limit_into()` 及所有未来新增 sink；执行器不得在没有任何可执行 stage 时启动子进程、打开文件或产生其他外部副作用。

## 错误分类（阶段 0 已锁定）

错误分类由公共 API 保证，不能由后端随意决定。四类边界划分如下：

1. **API 误用返回 `error.InvalidPipeline`**：调用方违反 transformer/sink 前置条件，例如空 pipeline 传给 sink、`cmd` 命令名为空或含路径分隔符、stream policy 冲突、`cwd/env/unset_env` 在非法位置调用、caller-provided 缓冲区重叠或不足、已消费/已 drop 的 capability 再次使用等。
2. **Stage 启动链路失败和 Uya stage 错误进入 `PipelineResult`**：PATH 查找失败、cwd 不可用、fork/CreateProcess 失败、执行域建立失败、stdio setup 失败、exec 映像失败、以及 Uya stage 正常返回或返回 Uya error，均通过 `statuses` / `PipelineResult` 传递，不由 sink 返回普通 Uya error 表示业务失败。
3. **执行器资源失败返回普通 Uya error**：文件重定向打开失败、inter-stage / launch / startup-report pipe 创建失败、内存分配失败、UTF-8/UTF-16 编码转换失败、以及其他不属于 API 误用也不属于 stage 启动链路的基础设施失败，按 Uya 既有 error 返回。
4. **Executor 自身收到未忽略的取消信号返回 `error.Interrupted`**：同步 sink 执行期间 executor 收到未被既有 disposition 忽略的 `SIGINT`、`SIGQUIT`、`SIGTERM`、`SIGHUP` 或 Windows console cancellation，或任一直接 stage 进入 stopped 状态，统一进入有限取消路径，清理后返回 `error.Interrupted`。

```text
cmd 命令名为空、cmd 名称含路径分隔符                => error.InvalidPipeline
空 pipeline 传给 sink                              => error.InvalidPipeline
PATH 查找失败                                       => PipelineResult spawn_failed/not_started
stage cwd 不存在或无法进入                         => PipelineResult spawn_failed/not_started
fork / CreateProcess 失败                          => PipelineResult spawn_failed/not_started
child-side setpgid/signal_setup/chdir/dup2/execve 失败并经启动诊断回传 => PipelineResult spawn_failed/not_started
Uya stage 返回错误                                  => PipelineResult stage_failed
executor 收到未被忽略的终止/取消信号                 => error.Interrupted
直接 stage 进入 stopped 状态                         => error.Interrupted
stream policy 冲突、错误的 transformer 位置          => error.InvalidPipeline
env key 为空/含 '='、env value 为 null                => error.EnvInvalidName / error.EnvInvalidValue
parent-side 打开 stdin/stdout/stderr 文件重定向失败   => 普通 Uya error
inter-stage / launch / startup-report pipe 创建失败   => 普通 Uya error
内存分配、平台编码转换失败                           => 普通 Uya error
```

上述 `spawn_failed` 必须进一步填写 `spawn_failure`：PATH 无候选为 `path_not_found`，cwd 校验或 child-side chdir 失败为 `cwd_unavailable`，可执行文件权限失败为 `permission_denied`，fork / CreateProcess 本身失败为 `process_create_failed`，`setpgid` / child signal setup / launch barrier / Job assignment / suspended-thread resume 等执行域建立失败为 `execution_domain_failed`，child-side `dup2` 或 Windows stdio handle 安装失败为 `stdio_setup_failed`，已经创建 child 但 exec/启动映像失败为 `exec_failed`；不能可靠映射时才使用 `platform_error`。POSIX startup diagnostic record 或 Windows bridge 必须保留失败阶段与原始平台码，先按阶段再按错误码映射稳定类别；不能只回传一个无法区分 signal setup/chdir/dup2/exec 的裸 `errno`。

也就是说，`status_into()` / `capture_into()` 对“进程启动链路已经形成但某个 stage 没能启动或退出失败”的情况保持观察型；对执行器自身无法搭建管道拓扑、无法打开用户指定文件或无法分配资源的情况，仍返回普通 Uya error。

## 失败详情返回路径

`check_into`、`status_into`、`capture_into`、`capture_limit_into` 通过调用方提供的 `statuses`、`result`、`stdout_buf` 与 `stderr_buf` 返回失败详情。Uya 的 `error` 值不携带业务 payload，因此除 `error.InvalidPipeline` 等 API 误用、`error.Interrupted` 以及内存、pipe、文件、编码等基础设施失败外，process stage 的非零退出 / signal 终止 / 启动失败、Uya stage 的错误返回，都不能依赖 sink 返回的 Uya error 传递；需要这些失败详情时，调用方必须使用上述 `_into` sink。

- `check_into` 在成功时写入完整 `PipelineResult`；在返回 `error.ProcessFailed`、`error.PipelineSpawnFailed` 或 `error.PipelineStageFailed` 前，必须保留已经写入 `statuses` 的完整 stage 摘要。
- `status_into` 是观察型 sink：无论 stage 成功或失败都成功返回，全部状态写入 `statuses` 与 `PipelineResult`。
- `capture_into` / `capture_limit_into` 是观察型 sink：无论 stage 成功或失败都成功返回（除非发生基础设施失败或 `CaptureLimitExceeded`），完整状态与 capture 长度写入 `PipelineCaptureResult`。

## 退出状态策略

执行 sink 分成 checked 和 observing 两类：

> **阶段 0 已锁定**：`check()` 使用固定的 all-stage/pipefail 策略：任一 process stage 非零退出或 signal 终止都会返回 `error.ProcessFailed`；`spawn_failed` / `not_started` 链路优先返回 `error.PipelineSpawnFailed`；Uya stage 错误返回 `error.PipelineStageFailed`。MVP 不提供按 pipeline 配置或关闭 pipefail 的入口。
> **阶段 0 已锁定**：`check_into(statuses, result)` 与 `check()` 使用同样的 all-stage/pipefail 策略，且在返回 `error.ProcessFailed`、`error.PipelineSpawnFailed` 或 `error.PipelineStageFailed` 前必须先把完整 stage 状态写入 `statuses[0:result.stage_count]` 并设置 `PipelineResult.stage_count`。

- `check()` 使用固定的 all-stage/pipefail 策略：任一 process stage 非零退出或 signal 终止都会返回 `error.ProcessFailed`。MVP 不提供按 pipeline 配置或关闭 pipefail 的入口。
- `check()` 若出现 `spawn_failed` / `not_started` 失败链路，优先返回 `error.PipelineSpawnFailed`；若 Uya stage 返回错误，则返回 `error.PipelineStageFailed`；否则任一 process stage 非零退出或 signal 终止时返回 `error.ProcessFailed`。
- `check_into(statuses, result)` 与 `check()` 相同，但无论成功、`error.ProcessFailed`、`error.PipelineSpawnFailed` 或 `error.PipelineStageFailed`，都必须先把全部 stage 状态写入 `statuses[0:result.stage_count]`；result 只记录长度，不保存指向该缓冲区的借用。

> **阶段 0 已锁定**：`status_into(statuses, result)` 是观察型 sink：完整 `PipelineResult` 写入调用方缓冲区，process stage 的非零退出、signal 终止、`spawn_failed` / `not_started` 启动链路失败以及 Uya stage 错误均不映射为 sink 自身的 Uya error。

- `capture_into(statuses, stdout_buf, stderr_buf, result)` / `capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)` 是观察型 sink：写入 `PipelineCaptureResult`，其中必须包含 `PipelineResult`，非零退出、signal 终止、stage 启动失败或 Uya stage 错误不映射为 sink 自身的 Uya error。

Uya 的 `error` 值本身不携带业务 payload，因此设计不能依赖“error payload”保存 `PipelineResult`。需要失败详情时，调用方必须使用 `check_into`、`status_into`、`capture_into` 或 `capture_limit_into`。

同步 sink 执行期间若 executor 自身收到未被既有 disposition 忽略的 `SIGINT`、`SIGQUIT`、`SIGTERM`、`SIGHUP` 或 Windows console cancellation，所有 sink 都必须进入 interruption cancellation 路径：唤醒等待循环，转发/终止 stage，关闭 pipe，reap 直接 stage，恢复终端与临时 signal 状态，然后返回 `error.Interrupted`。这是公共 API 的稳定结果，不把 executor interruption 伪装成 `error.ProcessFailed`，也不在清理后重新触发默认信号处理。接收 result 指针的 sink 按普通错误规则返回空摘要；需要中断时的部分输出或状态必须等待后续显式 partial-result API。

POSIX 实现不得在异步 signal handler 中分配、加锁、等待或操作 pipeline state；handler 只能设置原子标志或写入 runtime broker 的 self-pipe，由正常 poll/wait 路径执行清理。signal disposition 是进程级状态，不能由每个 sink 各自安装、保存和恢复：runtime broker 必须集中拥有 handler，通过引用计数/订阅表管理同时执行的 sink，并保存 broker 接管前的进程级 disposition；每个 sink 只保存和恢复自己调用线程的 mask。broker 收到进程定向的终止信号时必须通知所有活跃同步 pipeline sink，使它们各自进入 `Interrupted` 路径；注册/注销与 handler dispatch 必须避免 use-after-free。最后一个订阅者离开时，broker 只有在当前 disposition 仍由自己拥有时才能恢复原 handler，不能覆盖其他组件并发安装的新 disposition。既有 `SIG_IGN` 必须继续被忽略，已有自定义 handler 的 chaining/所有权由 broker 统一处理。

转发时先向每个 pipeline process group 发送一次原始信号，再只对 `getpgid(pid) != pipeline_pgid` 或无法证明仍在 group 的直接 PID 单独补发，不能让仍在 group 的 stage 收到重复信号。允许提供固定时长的 bounded grace period；期限到达后必须进入 process group + 直接 PID 的强制终止路径，不能因 stage 忽略终止信号而无限等待。Windows 对应路径通过同样的订阅式 runtime console-control broker 唤醒所有活跃 executor，并对每次执行分别完成有限取消。

fork child 不能继承 runtime broker 状态继续运行。每个 child 在 READY 前必须关闭 broker 的 self-pipe/event fd，并恢复 fork 前保存的调用线程 mask；对 broker 管理的信号，若 broker 接管前 disposition 是 `SIG_IGN` 则保持忽略，否则在 child 中设为默认 disposition，不能让 child 在 barrier/chdir/dup2/exec 阶段调用父进程的自定义 handler。该 child-side signal setup 只能使用 fork 后安全的操作；失败时通过 startup report 的 `signal_setup` phase 回传并写入 `spawn_failed(execution_domain_failed)`。这条规则只移除 runtime broker 状态，不擅自解除调用方在 sink 之前就显式设置的其他 signal mask。

parent 向 per-child launch pipe 写 `RUN` / `ABORT` 时必须使用不受默认 `SIGPIPE` 终止的 exact-token helper。POSIX 实现应在当前写入线程临时阻塞 `SIGPIPE`，循环处理 `EINTR`，把短写或 `EPIPE` 当作 launch failure，并只消费本次写入新产生的 pending `SIGPIPE` 后恢复原 mask；不得为了方便永久忽略整个进程的 `SIGPIPE`。这样目标 child 已关闭 launch read 端时，executor 仍能进入统一取消和 reap 路径。

event loop 必须在开始取消前锁存一个 terminal cause，后续 cleanup 事件不得覆盖它。在同一次 poll/wait batch 中，已经 pending 的 executor/console interruption 或 stopped-child event 优先于 capture overflow 和 stage failure，返回 `error.Interrupted`；否则先观察到的 capture overflow、普通基础设施错误或可表示的 stage failure成为本次执行的稳定原因。取消期间随后到达的 signal 只用于加速清理，不把已经锁存的 `CaptureLimitExceeded` / 普通错误改写成 `Interrupted`。这样同一组底层事件不会因遍历 fd/PID 的顺序不同而返回不同错误。

> **阶段 0 已锁定**：`CaptureLimitExceeded` 路径是普通 Uya error 返回，不通过 `PipelineCaptureResult` 携带部分输出。任一 captured stream 超过有效上限后，executor 进入强制取消路径：停止向调用方缓冲区写入新数据，可在固定字节数/轮次内做一次非阻塞 best-effort drain，但不得把“读到 EOF”作为继续回收的前置条件；随后关闭父进程持有的 capture 读端和其他 pipe 端，终止并 reap 所有直接 stage，最后把输出 result 重置为空摘要并返回 `error.CaptureLimitExceeded`。取消路径不得无限 drain，也不得因逃离后代仍持有 pipe 写端而等待 EOF。
>
> **阶段 0 已锁定**：POSIX 后端在 `CaptureLimitExceeded` 取消路径中必须先向本次 process group 发送 `SIGKILL`，再向每一个尚未 reap 的直接 process-stage PID 单独发送 `SIGKILL`；后一步覆盖直接 stage 在 exec 后主动调用 `setsid` / `setpgid` 逃离原 group 的情况。主动脱离且不再属于直接 stage 的后代不在回收保证范围内。Windows 后端必须使用 Job Object，并在超限时通过 `TerminateJobObject` 或等价机制终止整组进程；对尚未加入 Job 的直接进程需先单独 `TerminateProcess` 并等待其终止。有限完成保证以宿主内核能够调度并回收已收到强制终止请求的直接进程为前提。

`capture_into()` 以调用方缓冲区容量为限制，`capture_limit_into(max_bytes, ...)` 以 `min(max_bytes, buffer.len)` 为限制；两者都按被捕获的每个流单独计算，并使用上一节的一字节 probe 区分“恰好达到限制后 EOF”和“至少多出一个字节”。任一 captured stream 超过有效限制时，executor 必须进入强制取消路径：停止把新数据写入调用方缓冲区；可在固定字节数/固定轮次内做一次非阻塞 best-effort drain，但不得把“读到 EOF”作为继续回收的前置条件；随后关闭父进程持有的 capture 读端和其他 pipe 端，终止所有直接 stage，reap/等待这些直接 stage，并把输出 result 重置为空摘要后返回 `error.CaptureLimitExceeded`。仅“关闭 pipe 后等待自然退出”或无限 drain 都不满足本设计。

POSIX 后端必须先对本次 process group 发送 `SIGKILL`，再对每一个尚未 reap 的直接 process-stage PID 单独发送 `SIGKILL`；后一步覆盖直接 stage 在 exec 后主动调用 `setsid` / `setpgid` 逃离原 group 的情况。后代默认继承该 group，但主动脱离且不再属于直接 stage 的后代不在回收保证范围内；executor 不等待这些后代，也不能因其仍持有 pipe 写端而等待 EOF。Windows 后端必须使用 Job Object，并在超限时通过 `TerminateJobObject` 或等价机制终止整组进程。有限完成保证以宿主内核能够调度并回收已经收到强制终止请求的直接进程为前提。

未来 Uya runtime stage 不能仅凭“设置 cancellation flag 后 join”宣称同样的有限终止语义：任意 stage 可能在不访问 `StreamReader` / `StreamWriter` 的无限循环中忽略协作式取消。公开 `stage()` 前必须满足以下二选一之一：运行时提供可证明内存安全的强制 task 终止，并让阻塞 I/O 可被取消；或把 Uya stage 放入可由宿主强制终止的隔离 worker process。若两者都不具备，Uya stage 只能提供明确标注的协作式取消，且不能并入 process-only MVP 的有限完成承诺。由于 Uya error 不携带 payload，capture 超限路径不承诺返回部分输出或完整状态；调用方若需要诊断，应使用文件 sink、更大的 limit，或等待后续显式保留部分结果的 API。

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
stdout_capture + check            => error.InvalidPipeline
stdout_capture + check_into       => error.InvalidPipeline
stdout_capture + status_into      => error.InvalidPipeline
stderr_capture + check            => error.InvalidPipeline
stderr_capture + check_into       => error.InvalidPipeline
stderr_capture + status_into      => error.InvalidPipeline
stdout_file + inherit_stdio       => error.InvalidPipeline
stderr_file + inherit_stdio       => error.InvalidPipeline
stdout_capture + inherit_stdio    => error.InvalidPipeline
stderr_capture + inherit_stdio    => error.InvalidPipeline
stdout_file + capture sink        => error.InvalidPipeline
inherit_stdio + capture sink      => error.InvalidPipeline
```

`capture_into(statuses, stdout_buf, stderr_buf, result)` 使用调用方提供的 capture 缓冲区容量作为有效上限；`capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)` 在缓冲区容量之外额外施加 `max_bytes` 上限。第一版不提供隐藏默认 capture limit 常量。大输出应要求更大的调用方缓冲区、显式 limit 或文件 sink。

> **阶段 0 已锁定**：所有 sink 对 unset stdin 默认使用 inherit。`check()` / `check_into()` / `status_into()` 对 unset stdout/stderr 默认使用 inherit。`capture_into()` / `capture_limit_into()` 对 unset stdout 默认使用 capture，对 unset stderr 默认使用 inherit。显式 `stdout_capture()` / `stderr_capture()` 将对应终端流策略设为 capture；这类 capture policy 只能与返回 bytes 的 `capture_into()` / `capture_limit_into()` 组合。在已经设置 capture policy 的 pipeline 上使用 `check()`、`check_into()` 或 `status_into()` 没有返回 bytes 的路径，必须报 `error.InvalidPipeline`。

> **阶段 0 已锁定**：`inherit_stdio(input)` 是显式策略，不是“清空之前配置”的 reset。它要求 stdin、stdout、stderr 三路终端流都仍处于 `unset` 状态，然后把三路都设为 `inherit`；只要任意一路已经被显式配置为 file、capture 或 `merge_stdout`，就返回 `error.InvalidPipeline`。在 `inherit_stdio()` 之后再调用 `stdout_file` / `stderr_file` / `stdout_capture` / `stderr_capture` / capture sink 同样报冲突。

> **阶段 0 已锁定**：sink 开始执行时必须先捕获一次宿主进程 cwd 快照。该快照是本次 sink 调用期间解释所有相对路径的唯一基准：process stage 的相对 `cwd(path)` 按该快照解释；`stdin_file` / `stdout_file` / `stderr_file` 等 pipeline-global stream policy 的相对路径也按同一快照解释，绝不按任一 stage-local cwd 解释。

> **阶段 0 已锁定**：同一 process stage 多次调用 `cwd(path)` 时，最后一次覆盖前一次；`path` 始终按 sink-time 宿主进程 cwd 快照解释，不相对任何前一次 `cwd` 做链式拼接。例如 `cmd("git") |> cwd("a") |> cwd("b")` 等价于 `cmd("git") |> cwd("b")`，而不是 `cwd("a/b")`。

transformer 只复制并保存路径；实际文件必须在所有语义/PATH/cwd/buffer 预检和 pipe/control-fd 创建成功后、启动第一个 child 前由 parent 按 stdin、stdout、stderr 的固定顺序打开，不能推迟到 child-side setup。每个活跃 stream policy 只打开一次：stdin file 供第一 stage 使用，stdout file 供最后 stage 使用，group-level stderr file 的同一个 open file description 供所有 process stage安装；这样不会因每个 stage 分别使用 truncate open 而反复截断。

POSIX stdin 使用 `O_RDONLY | O_CLOEXEC`；stdout/stderr 使用 `O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC`，创建 mode 为 `0666` 并服从调用进程当前 umask，`open` 被 `EINTR` 中断时重试。Windows stdin 使用 `GENERIC_READ + OPEN_EXISTING`，stdout/stderr 使用 `GENERIC_WRITE + CREATE_ALWAYS`；sharing mode 允许 read/write/delete，以接近 POSIX 没有强制 sharing lock 的行为，原始 parent handle 默认不可继承，只为每个 child 创建进入 allowlist 的可继承副本。所有这些 file handle/fd 随后仍须遵守前述 source > 2、严格 handle allowlist 和 parent-side 关闭规则。

多文件打开不是事务。若较早的 stdout/stderr `CREATE_ALWAYS`/`O_TRUNC` 已经成功，而后续 policy 打开失败，实现必须关闭已经打开的文件和内部 pipe/handle、释放 terminal lease、返回普通 Uya error并保持没有 child 启动，但不承诺回滚已经发生的文件创建或截断。固定打开顺序使该副作用可预测；文档和测试不能声称“文件打开失败完全没有外部副作用”。

> **阶段 0 已锁定**：Inter-stage stdout pipe 是执行拓扑的一部分，不受 `stdout_file` 等终端 stdout 策略影响：stage `i` 的 stdout 连接到 stage `i + 1` 的 stdin；只有最后一个 stage 的 stdout 进入终端 stdout 策略。stderr 默认不参与 stage 间数据流。整条 pipeline 的 stderr 策略等价于 shell group 级重定向，例如 `{ a | b; } 2>file` 或 `{ a | b; } 2>&1`，不是 `a 2>&1 | b` 这种 per-stage 数据流。多个 stage 同时写入同一个 stderr file/capture pipe 时，只保证 byte stream 不被 executor 主动重排，不保证跨进程日志行顺序稳定。

## 未来扩展：自定义 Uya Pipeline Stage

自定义流处理通过接口表示。Uya 使用 `struct S : I { ... }` 和方法块实现接口；没有 `impl` 关键字。

自定义 Uya stage 不属于 process-only MVP。第一版应先完成外部进程 pipeline；Uya stage 在 runtime task/thread 执行模型和 stage 所有权规则明确后再开放。fork-backed Uya stage 只能作为受控实验或测试模式，不能作为默认生产实现。本节只描述未来扩展方向，不是 MVP 公共 API。

**名称锁定**：自定义 Uya pipeline stage 的 transformer 最终名称为 `stage`；该名称已锁定，不会改为 `filter`、`step`、`node` 或其他候选名。

推荐接口：

```uya
interface PipelineStage {
    fn run(self: &Self, input: &StreamReader, output: &StreamWriter) !void;
}
```

最终 transformer（名称已锁定）：

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
            const n: usize = try input.read_line(&line);
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

`filter` 不作为公共 API 别名。它仅在本文档中作为概念性术语使用，指代“执行过滤的 pipeline stage”；自定义 Uya pipeline stage 的唯一公共 transformer 名称是 `stage`。

## 运行时执行模型

Transformer 是同步计划构造器。它们可以校验输入、复制 argv/path/env 数据、分配计划节点，并拒绝冲突的流策略。它们不能启动进程。

Sink 执行计划。执行时必须先完成不需要启动子进程的预检，再启动所有 pipeline stage，最后等待完成：

```text
build final env/cwd for each process stage
resolve PATH-searching cmd stages through std.process helper
validate caller buffer capacities, pairwise non-overlap, and every stream policy
subscribe this sink to the runtime signal/console broker before any interruptible wait
if inherited stdio touches a controlling terminal, acquire its interruptible exclusive foreground lease
create all inter-stage and startup-control pipes/handles
open each active file-redirection policy exactly once in parent
start all enabled stages, immediately closing the parent copies of each child's child-only fds/handles after that child is created (process stages in the MVP; Uya stages only after the cancellation/termination gate is satisfied)
before releasing any stage, close every remaining parent copy of child-only data/control endpoints and capture writers
drive capture readers while children may still be writing
wait/reap only direct stages
perform the bounded nonblocking final capture drain and record each stream's completeness
restore terminal ownership, release any foreground lease, and unsubscribe the broker
collect statuses and output
apply sink-specific failure policy
```

上面的 cleanup 步骤是所有返回路径的 mandatory finally boundary；预检后任一步失败或中断都必须跳转到相应的有限取消/资源清理分支，再恢复终端、释放 lease 并注销 broker，不能在 `apply sink-specific failure policy` 返回之后补做清理。

executor 不能先把 stage 0 跑完再启动 stage 1。它也不能先等待所有子进程结束再 drain capture pipe。任一顺序在大输出填满 pipe buffer 时都可能死锁。

POSIX executor 在启动第一个 process stage 时创建本次执行专用的 process group，后续 process stage 加入同一 group；Windows executor 为本次执行创建 Job Object，并把所有 process stage 放入其中。该执行域用于 capture 超限和部分启动后发生基础设施错误时的统一取消，但正常完成边界只等待并报告直接 stage。direct stage 运行期间 capture reader 必须持续 drain，不能把大量已产生数据积压到 wait 之后；全部直接 stage 已 reap 后，再对当前可读数据做一次有固定字节/轮次上限的非阻塞收尾 drain，到 `EAGAIN`、达到上限或发现 EOF 即停止，然后关闭读端。只有观察到 EOF 的 stream 才设置 `complete=true`；因 `EAGAIN` 或预算耗尽关闭时必须设置 `complete=false`，即使 `byte_count` 尚未达到调用方容量也不能静默报告完整。executor 不得为了非直接后代仍持有的写端无限等待 EOF；关闭边界之后的后代输出不属于本次 capture 结果。正常路径不主动终止非直接后代；若未来需要“sink 返回前所有后代都结束”的结构化并发语义，必须作为单独模式设计，不能悄悄改变这里的 direct-stage 语义。

POSIX process group 必须通过带显式消息的启动屏障消除竞态。parent 在第一次 fork 前为每个预期 child 创建独立 launch pipe 和独立、close-on-exec 的 startup-report pipe；不能用无法识别 token 接收者的共享 launch pipe。第一个 child 在 fork 后、执行任何用户代码前调用 `setpgid(0, 0)` 成为 group leader，后续 child 调用 `setpgid(0, leader_pid)`；parent 对每个 child 同样调用 `setpgid(child_pid, leader_pid)` 并验证结果，作为 child/parent 调度顺序不确定时的双侧收敛。child-side `setpgid` 成功后必须向自己的 report pipe 写入固定大小的 `READY` record，然后只从自己的 launch pipe 读取一个 token：只有明确的 `RUN` token 才能继续 chdir/dup2/exec，`ABORT`、EOF、短读或未知 token 都必须关闭 child fds 并 `_exit`，不得执行用户映像。parent 必须 poll 全部 report pipe；在收到每个 child 的 `READY` 且完成 parent-side `setpgid` 验证前不能写入任何 `RUN`。report pipe 在 `READY` 前出现 EOF、格式错误或 `FAILED` record，或者已经 READY 的 child 在 RUN 前提前关闭 report pipe，都是启动失败。成功路径逐个向每个 child 的 launch pipe 写入一个 `RUN` token并关闭对应 pipe；失败路径向尚未释放的 child 写入 `ABORT`（写入失败时直接关闭对应 pipe），再对 group 和每个直接 PID 执行强制取消并 reap。这样关闭 launch pipe 不会被解释为正常释放，parent 也能精确记录哪些 stage 已经越过 RUN 边界。

因为全部 per-child pipe 在第一次 fork 前已经存在，fd 所有权必须在 READY 前收敛，不能依赖 exec-time `FD_CLOEXEC`：每个 child 一进入 fork 分支，就必须关闭所有 parent-only 控制端、runtime broker fd、其他 stage 的 launch/report 两端，以及与本 stage stdin/stdout/stderr 无关的数据 pipe 端，只保留自己的 launch read 端、startup-report write 端和完成本 stage stdio 安装所需的数据 fd。parent 在每次 fork 成功后必须立即关闭该 child 的 launch read 端和 startup-report write 端；某个 data/file fd 的最后一个预期继承者 fork 成功后，parent 也必须立即关闭自己的对应副本。全部 child READY 后、发送任何 `RUN` 前，parent 不得再持有任何 child-only control/data fd 或 capture write 端；否则 parent 自己持有的 pipe writer 会阻止下游 EOF并使直接 stage 永久等待。

不能假设宿主的 0/1/2 一定已打开。所有新建的 control fd、inter-stage/capture data fd 和 file-redirection fd 都必须在第一次 fork 前移动到大于 `STDERR_FILENO` 的编号，并设置与用途一致的 close-on-exec 标志；因此 child-side 三路 stdio source 不会与目标 0/1/2 形成覆盖环。继承策略直接使用原有 0/1/2，不把它们当作内部 source fd。child 对每个非 inherit stream 用 `dup2(source, target)` 安装 stdio；因为 source 大于 2，成功的 `dup2` 会得到不带 close-on-exec 的目标，随后才能关闭全部内部 source fd。若后端选择不统一搬移 source，则必须实现等价的循环安全 remap，并显式处理 `source == target` 时清除 `FD_CLOEXEC`，不能按 stdin/stdout/stderr 固定顺序做可能覆盖后续 source 的裸 `dup2`。

POSIX 执行释放边界以成功消费 `RUN` 为准：尚未消费 `RUN` 就因其他 stage 失败而退出的 child 即使已经有 PID，也写入 `not_started`；自身 fork、setpgid、signal setup、barrier 或后续 setup 失败的 stage 写入 `spawn_failed`。如果 parent 已经向部分 child 发出 `RUN` 后发生某个 per-child launch pipe 错误，未释放 child 记为 `not_started`，对应 launch pipe 的 stage 记为 `spawn_failed(execution_domain_failed)`；已经释放且在统一取消前尚未自然完成的 child 记为 `cancelled`，即使它还停留在 chdir/dup2/exec 前后；已经观察到自然完成的则保留实际状态。

独立 process group 不能破坏默认继承终端的行为。多个并发 sink 可能共享同一个 controlling terminal，因此 runtime 必须按 terminal identity 提供独占 foreground lease；需要把任一 inherit stream 连接到该 terminal 的 sink 必须在创建 child 和产生文件截断等外部副作用前取得 lease，并持有到前台 PGID恢复或确定从未转交为止。等待 lease 的 sink 可以被 runtime broker 中断并返回 `error.Interrupted`；不能让两个 sink 竞态调用 `tcsetpgrp`。不触及 controlling terminal 的 pipeline 不受该 lease 串行化。

取得 lease 后，executor 必须先通过 `tcgetpgrp(tty_fd)` 读取并保存当前前台 PGID，并且只有该值等于 executor 自身的 `getpgrp()` 时，才允许在发送 `RUN` 前用 `tcsetpgrp` 把终端前台权转交给 pipeline group。若 executor 本身处于后台，必须保持后台语义，不能忽略 `SIGTTOU` 后抢占终端，也不能把其他前台 job 的 PGID 当作“父 PGID”覆盖。完成过转交时，正常完成、启动失败、capture 超限、stage stop 和收到取消信号的所有路径都必须恢复先前保存的前台 PGID；从未转交则不得调用恢复。切换 `tcsetpgrp` 时只允许在调用线程临时阻塞 `SIGTTOU`，调用后立即恢复原 mask；等待期间父进程不得读写已经转交的终端。`tcgetpgrp` / `tcsetpgrp` 失败属于执行器基础设施错误：在任何 `RUN` 发出前按 ABORT 协议取消全部 child 并返回普通 Uya error。释放 foreground lease 前必须完成上述恢复或失败收敛。

同步 sink 不公开 suspended/stopped stage，因此 wait loop 必须使用 `WUNTRACED`（以及平台需要时的 `WCONTINUED`）观察直接 child 的停止状态，不能只等待退出。任一直接 child 因 `SIGTSTP`、`SIGTTIN`、`SIGTTOU`、`SIGSTOP` 或其他信号进入 stopped 状态时，executor 必须立即恢复曾转交的前台 PGID，对 process group 和全部直接 PID执行强制取消并 reap，然后返回 `error.Interrupted`；接收 result 指针的 sink 返回空摘要。该规则也覆盖后台 executor 的 child 因读取 controlling terminal 收到 `SIGTTIN`，避免同步 sink 永久挂起。若未来需要 shell 式“停止 executor、收到 SIGCONT 后恢复 pipeline”的行为，必须作为显式 job-control 模式另行设计；当前 MVP 不静默实现半套 job table。

executor 自身收到终止信号时必须遵循前述 `error.Interrupted` 协议和按 PGID 去重的转发规则。这里是同步 sink 的内部前台所有权、停止收敛和信号转发，不公开后台任务、继续控制或 shell job table，因此不改变“不提供公共 job control”的非目标。

如果预检阶段发现某个 stage 无法解析或 stage 启动前置条件失败，executor 不应启动任何子进程；结果中该 stage 标记为 `spawn_failed`，其他 stage 标记为 `not_started`。若错误属于前文定义的普通 Uya error，例如 pipe 创建或文件重定向打开失败，则直接返回该错误而不伪造 `PipelineResult`。如果 stage 启动错误或基础设施错误发生在部分 stage 已启动之后，executor 必须通过本次执行的 process group + 直接 PID、Job Object 或满足前述强制终止门槛的 Uya-stage execution domain 终止已启动 stage，停止 capture、关闭父进程持有的 pipe 端，并 reap/join 直接 stage；取消路径不得无限 drain 或等待 EOF。未启动 stage 写入 `not_started`，不能只等待仍可能无限运行的 stage 自然退出。

### POSIX 后端

进程 stage：

```text
build final argv/envp/cwd, including argv0 prefix
resolve cmd through PATH in parent using final env/cwd
fork
in child, close every unrelated control/data/broker fd and restore child signal state before reporting READY
in parent, immediately close that child's launch-read/report-write ends and every data/file fd whose last inheritor has now forked
setpgid in child and parent; child reports ready and waits on its launch pipe
after every child reported READY and both sides verified process-group membership, optionally transfer controlling terminal foreground PGID
verify the parent holds no child-only data/control fd or capture writer
write one explicit RUN token for each ready child through the SIGPIPE-safe exact-token helper
chdir to stage cwd when configured; on failure report {phase=chdir, code=errno}
install stdin/stdout/stderr from sources above fd 2; on failure report the exact stdio phase and errno
close the retained launch/data source fds; keep only close-on-exec report writer
execve exec_path argv envp
on execve failure, report {phase=execve, code=errno} and _exit(127)
```

`cmd` 不能直接降低为裸 `execve(program, ...)`，因为 `execve` 不做 PATH 查找。推荐执行前在 parent 中按最终 child env 解析 PATH，生成 execution-time `exec_path`，再由 child 使用 `execve(exec_path, ...)`。`cmd_path` 不做 PATH 查找：绝对路径直接作为 `exec_path`；相对路径必须在应用 stage cwd 后解释，POSIX 后端可以在 child `chdir` 后用原相对路径 `execve`，也可以在 parent 以 stage cwd 为基准预解析成等价绝对路径。

每个 child 的 startup-report pipe 同时承担 ready handshake 和 close-on-exec diagnostic。record 必须是固定大小、版本固定且不大于 `PIPE_BUF`，并由 child 用一次 async-signal-safe `write` 写入；至少包含 `kind = READY | FAILED`、`phase = setpgid | signal_setup | barrier | chdir | dup2_stdin | dup2_stdout | dup2_stderr | execve` 和 `platform_code`。`FAILED` 后 child 必须 `_exit(127)`；parent 先按 `phase` 决定稳定的 `PipelineSpawnFailureKind`，再把 errno 原值保存到 `platform_code`。只有 child 已收到 `RUN` 且 report pipe 因 close-on-exec 正常关闭时，才表示用户映像启动成功；裸 errno record 不满足本协议。

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

上面的 task/thread 方案只是调度形态，不自动满足取消保证。进入公共 API 前必须证明 runtime 能打断阻塞 stream I/O，并按照前文的强制终止门槛处理不协作的 CPU-bound stage；否则应改用隔离 worker process，或把该后端明确限制为不承诺有限取消的实验能力。

### Windows 后端

公共 API 必须保持不变，但后端会把进程 stage 映射到 `CreateProcessW`。每次 pipeline 执行必须先创建用于显式取消的 Job Object，并在创建任何 child 前完成全部 UTF 转换、command-line 构造、pipe 创建、每个活跃 file-redirection policy 的单次 parent-side `CreateFileW`，以及 `STARTUPINFOEXW` handle-list 准备；这些基础设施步骤失败时按普通 Uya error 返回，不伪造 stage 状态。group-level stderr file handle 必须由所有 stage 共享，不能为每个 child 重新 truncate/open。默认 direct-stage 语义不得设置 `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`：正常 sink 收尾关闭最后一个 Job handle 时不能把仍存活的非直接后代隐式杀死。每个 child 使用 `CREATE_SUSPENDED` 创建，通过 `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`（或语义等价的严格 allowlist）只继承该 stage 真正需要的 stdin/stdout/stderr/inter-stage handles，然后在执行任何用户代码前调用 `AssignProcessToJobObject`。每次 CreateProcess 成功后立即关闭仅供该 child 继承的 parent-side handle 副本；共享 handle 在最后一个需要它的 child 创建成功后关闭。全部 child 已成功创建并加入 job、parent 已关闭所有 child-only data/control handle 与 capture writer 后，才逐个恢复所有 child 的 primary thread；不能只恢复某一个“主线程”。

CreateProcess、job assignment 或 resume 某个 stage 失败时，该 stage 写入 `spawn_failed` 及对应失败详情。executor 必须分别跟踪 `created_unassigned`、`assigned_suspended` 和 `resumed`：先对每个已经创建但尚未成功加入 Job 的直接进程调用 `TerminateProcess`，再对 Job 中的 suspended/running process 调用 `TerminateJobObject`，随后等待所有已经创建的直接进程进入终止状态，最后才能关闭 thread/process/pipe/Job handles。`CloseHandle` 只释放句柄，绝不能替代对 created-but-unassigned child 的终止与等待。

Windows 执行释放边界是成功 `ResumeThread` 并使 primary thread suspend count 归零：从未越过该边界的其他 stage 标记为 `not_started`；已经恢复且在 job termination 前尚未自然完成的 stage 标记为 `cancelled`；已经观察到自然完成的 stage 保留其 `exited` 状态。不能留下“先运行、后入 job”的逃逸窗口，也不能让 parent 或无关 child 因多持有 pipe 写端而阻止 EOF。若宿主已有 Job Object 策略导致 assignment 不可用，必须在恢复 child 前稳定失败并按上一段终止未入 Job 的 suspended child，不得静默降级为无执行域模式。capture 超限时同样显式使用 `TerminateJobObject`，并单独终止任何尚未入 Job 的 direct child；正常完成时只等待直接 stage，并按前述有限 drain 规则关闭 capture 读端与 Job handle，不等待或终止非直接后代。

argv/env 应从 Uya UTF-8 数据转换为 Windows UTF-16；构造 command line 时必须使用明确的 argv quoting 规则，不得隐式调用 `cmd.exe`。Windows console control event 必须通过 runtime console-control broker 唤醒正常 executor 路径，按上一段分别 `TerminateProcess` 尚未入 Job 的 child、`TerminateJobObject` 已入 Job 的 child，完成 direct-process wait 和 handle 清理后返回 `error.Interrupted`；不能只在 console callback 中执行复杂清理，也不能让任何已创建的直接 process stage 留在后台或 suspended 状态。Uya stage 只有满足前述强制终止门槛后才能使用 runtime thread/task；不能仅因为 Windows 没有 fork 就降低取消保证。

## 内部计划草图

内部表示不是公共 API，但应保留以下概念。下面是伪代码草图，不是可直接复制的 Uya 声明；真实实现应使用当前 Uya 可声明的 slice、固定数组、Vec 或 handle 表示动态列表：

```text
struct PipelinePlan {
    stages: [PipelinePlanStage],
    stdin: StreamSpec,
    terminal_stdout: StreamSpec,
    terminal_stderr: StreamSpec,
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

`stage<T: PipelineStage>` 可以降低为一次 `T` 的分配/移动，加上生成的 thunk 函数；不能用 bitwise copy 复制按值参数后再让源参数执行 drop。若 `T` 不满足深拷贝约束，`clone_fn` 必须缺失并使 `clone(input)` 返回 `error.InvalidPipeline`，或者 `stage()` 直接拒绝该 `T`。

## 必要不变量

- `Pipeline` 对用户不透明。
- `Pipeline` 是 move-only。
- 公开 `Pipeline` 必须使用真正 opaque / non-copyable 类型；普通导出 struct 或 raw pointer handle 不能作为稳定 API。
- transformer 与 sink 在所有返回路径上消费 input；失败路径和未执行即离开作用域的路径都必须释放计划。
- `stage_count(&Pipeline) !usize` 是不消费、不执行的查询；调用方可在 sink 前可靠获得 statuses 所需容量，无效 capability 返回 `error.InvalidPipeline`，容量检查必须早于任何外部副作用。
- 每个进程 stage 都有非空程序名。
- args/env/cwd/path/stage 数据由计划拥有。
- 所有 process stage 从同一个 sink-time canonical base-env 快照派生；overlay 按调用顺序决议，PATH 查找与 spawn 使用同一最终 env block。
- `cmd` 的 PATH 缺失/空 component/relative component 和 Windows `.exe` fallback 必须遵守文档化规则；不能注入默认搜索目录、PATHEXT shell fallback 或另一份 spawn 环境。
- 最终 child argv 必须由执行器构造，且 `argv[0]` 不来自 `args` slice。
- `cmd_path` 的相对路径按该 stage 的最终 cwd 解释。
- Windows drive-relative command/cwd/file path 必须在外部副作用前拒绝，不能读取隐式 per-drive cwd。
- `cwd` / `env` / `unset_env` 只作用于最近追加的 process stage。
- terminal stdout / stderr 每个方向最多有一个活跃策略。
- capture stream policy 只能与 `capture_into` / `capture_limit_into` sink 组合；按值返回 facade 开放后也适用于 `capture` / `capture_limit`。
- `stderr_to_stdout` 与独立 stderr capture/file 策略冲突。
- sink 要求至少有一个可执行 stage；空 pipeline 传给任何 sink 必须返回 `error.InvalidPipeline`。
- 已消费的 pipeline 不能再次执行。
- capture buffer 有界，除非加入并文档化显式无界 API。
- caller-provided statuses/stdout/stderr/result writable region 必须在任何外部副作用前验证为两两不重叠；达到 capture 上限但尚未 EOF 时必须用独立一字节 scratch probe 区分 exact-fit 与 overflow。
- observing capture 即使在 preflight spawn failure 时也必须稳定标记启用流为 `captured=true`；只有实际观察到 EOF 才能设置 `complete=true`。
- process-only pipeline 在 capture 超限或部分启动后的执行器错误中必须对 process group 和所有直接 PID 强制取消、关闭 capture 读端并有限完成直接 child 的 reap；不得等待逃离后代持有的 pipe EOF。
> **阶段 0 已锁定**：正常完成只等待直接 stage；全部直接 stage reap 后做有界非阻塞 capture 收尾并关闭读端，不等待/终止非直接后代；只有 EOF 设置 `complete=true`，`EAGAIN`/预算 cutoff 必须返回 `complete=false`。
- Uya stage 在没有强制、安全的终止机制或隔离 worker process 前，不得继承 process-only pipeline 的有限取消承诺。
> **阶段 0 已锁定**：POSIX process group 建立必须使用 parent/child 双侧 `setpgid` 收敛：第一个 child 在 fork 后调用 `setpgid(0, 0)` 成为 group leader，后续 child 调用 `setpgid(0, leader_pid)`，parent 对每个 child 调用 `setpgid(child_pid, leader_pid)` 并验证结果。每个 child 拥有独立的 launch pipe 和 close-on-exec 的 startup-report pipe；禁止所有 child 共享一个无法识别 token 接收者的 launch pipe。child-side `setpgid` 成功后向自己的 report pipe 写入固定大小 `READY` record，然后只从自己的 launch pipe 读取一个 token：只有明确的 `RUN` token 才能继续 chdir/dup2/exec；`ABORT`、EOF、短读或未知 token 必须关闭 child fds 并 `_exit`，不得执行用户映像。parent 必须 poll 全部 report pipe，在收到每个 child 的 `READY` 且完成 parent-side `setpgid` 验证前不能写入任何 `RUN`；report pipe 在 READY 前出现 EOF、格式错误或 `FAILED` record，或已 READY child 在 RUN 前提前关闭 report pipe，均为启动失败。成功路径逐个向每个 child 的 launch pipe 写入 `RUN` token 并关闭对应 pipe；失败路径向尚未释放的 child 写入 `ABORT`（写入失败时直接关闭对应 pipe），再对 group 和每个直接 PID 执行强制取消并 reap。
- POSIX child 必须通过双侧 `setpgid`、per-child startup-report/launch pipe 和显式 `RUN`/`ABORT` protocol 建立完整 process group；EOF 只能表示 abort，不能释放 child 执行用户代码。
> **阶段 0 已锁定**：每个 POSIX child 在 READY 前必须关闭所有与本 stage 无关的控制 fd、数据 fd 和 runtime-broker fd；parent 必须在每次 fork 成功后立即关闭该 child 的 launch-read/report-write 端，并在某个 data/file fd 的最后一个预期继承者 fork 成功后立即关闭 parent 副本；全部 child READY 后、发送任何 `RUN` token 前，parent 不得再持有任何 child-only control/data fd 或 capture writer。
- POSIX child 必须在 READY 前移除 sink 临时 signal mask/disposition，并恢复 fork 前保存的调用线程 mask。
- 所有内部 control/data/file source fd 必须避开 0/1/2，或使用等价的循环安全 stdio remap；不能假设宿主标准 fd 已打开。
- POSIX launch token 写入必须屏蔽本次写入产生的 `SIGPIPE` 并把 `EPIPE`/短写作为可清理的启动失败，不能让 executor 被默认 signal action 直接终止。
- runtime signal/console broker 必须用安全订阅模型协调并发 sink；等待 terminal lease 前先注册，注销后 handler/callback 不得访问 execution state。
- 只有 executor 自身当前拥有 controlling terminal 前台权时才能把前台 PGID 转交给 pipeline，并且只在确实转交后恢复；并发 sink 必须按 terminal identity 持有独占 foreground lease，先恢复终端再释放 lease，其他终止信号仍必须转发。
- wait loop 必须观察 stopped direct child；当前无公共 job-control 的模式将任何 stopped 状态收敛为有限取消和 `error.Interrupted`，不能遗留前台终端或永久等待。
- executor 自身收到未忽略的终止/取消信号时必须去重转发、有限取消并返回 `error.Interrupted`；异步 handler/callback 不能执行复杂清理。
- Windows child 必须以 suspended 状态创建、在运行前加入 Job Object，并通过严格 handle allowlist 避免多余 pipe 端继承；成功 resume 是执行释放边界，默认 direct-stage 模式不得以 kill-on-close 改变正常后代语义。取消时必须显式终止 Job，并对 created-but-unassigned child 单独 `TerminateProcess`、等待后再关闭 handle。
- 相对 stage cwd 和 file stream path 都按 sink-time 宿主 cwd 快照解释；file stream path 不跟随任一 stage-local cwd。
- 每个 file-redirection policy 必须在第一个 child 启动前由 parent 按固定顺序和平台 flags 打开一次；group-level stderr file 的同一 open file description 由所有 stage 共享，后续打开失败不承诺回滚已经发生的 create/truncate。
- `PipelineCaptureResult` 和 `PipelineResult` 只保存长度/状态摘要，不保存指向调用方缓冲区的 slice 或指针；接收 result 指针的 sink 在返回普通 Uya error、`error.Interrupted` 或 `error.CaptureLimitExceeded` 前必须重置为空摘要。
- `PipelineResult.stage_count` 和 statuses 缓冲区覆盖完整可执行 stage 列表；未越过平台中立执行释放边界的 stage 使用 `not_started`，已释放但被 executor 强制终止的 stage 使用 `cancelled`，Uya stage 使用 `completed` / `stage_failed`；process `exit_code` 以 `u32` 无损覆盖 Windows `DWORD`。
- 每个 `spawn_failed` 状态都包含由 startup phase 与平台码共同映射的稳定 `spawn_failure` 类别；平台错误码只能用于诊断，不能作为跨平台控制流依据。
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
- 仅当 `lhs` 为规范中 canonical `Pipeline` 声明或其 `!Pipeline` 包装，且 `f` 的首个显式参数为 `Pipeline` 时，接受 `lhs |> f(args...)`。不得仅比较未限定类型名字符串。
- 仅对 `!Pipeline` 插入 try-forward。
- 拒绝 sink 之后继续链式管道，因为左侧不再是 `Pipeline`。
- 对 free function、module-qualified call、无隐式 receiver 的类型命名空间静态调用、泛型 call 和 varargs facade，必须复用同一套 synthetic 第 0 实参规则；不能让这些 call 先走普通调用错误路径。
- 实例方法调用已有隐式 `self: &Self` receiver，MVP 明确拒绝把 `obj.method(args...)` 用作 `|>` 右侧。若未来支持，必须另行定义 lhs 插入 receiver 之后的参数位置，不能把 lhs 和 receiver 同时当作第 0 实参。

Lowering：

- 将表达式降低为普通调用和临时变量。
- `!Pipeline` try-forward 必须通过 AST 或临时变量语义实现，例如先构造 `const tmp: Pipeline = try lhs;` 再调用 `f(tmp, args...)`。实现不得把规则当作文本级 `f(try lhs, args...)` 重新解析，以免受当前 `try` 表达式优先级和泛型调用特殊解析影响。
- 保留 `Pipeline` 的移动语义。
- fmt、macro expand、C99 codegen、exec builder 和错误诊断路径都必须对 `AST_PIPELINE_EXPR` 或 desugared call 有回归覆盖，确保 `|>` 不会落入普通 binary operator 的格式化、类型检查或代码生成分支。

## 未决问题

- Uya stage 的 owned-data 约束应通过接口、编译器能力还是运行时校验表达。
- `stage` 已锁定为最终名称；`filter` 仅作为文档术语，不暴露为公共别名。
- 其中多少内容应属于 `std.process`，多少内容应属于 `std.script` facade。
