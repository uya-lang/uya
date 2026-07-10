# Uya 脚本标准库与运行时设计文档

**状态**：design draft  
**更新日期**：2026-07-10
**配套 TODO**：[`todo_std_script.md`](todo_std_script.md)
**类型化管道设计**：[`typed_pipeline_design.md`](typed_pipeline_design.md)

---

## 概述

本文档定义 Uya “脚本化”能力的目标、边界与分层设计。

这里的“脚本化”不是要复刻 bash/csh 语法，也不是先做一个新的交互式 shell，而是要让 Uya 能够稳定替换仓库中的 `xxx.sh` 一类自动化脚本：

- 用同一份 Uya 源码在 Linux / macOS / Windows hosted 路线上执行
- 减少 shell 字符串拼接、`grep`/`sed`/`awk`/`python` 小进程编排带来的性能损耗
- 用结构化 API 取代脆弱的命令字符串、路径拼接和平台分支
- 为后续 `uya script`、shebang、`--exec`/`--vm` 加速路径预留接口

---

## 核心目标

1. **优先替换仓库现有 `.sh`**
   - 第一阶段目标不是“通用 shell 语言”，而是把 `tests/*.sh`、部分构建/验证脚本迁移为 Uya 脚本。

2. **结构化跨平台 API**
   - 进程、环境变量、路径、文件系统、目录遍历、临时目录、重定向、管道等能力应通过标准库抽象暴露，而不是依赖宿主 shell 语法。

3. **保留 Uya 的类型化风格**
   - 错误通过 `!T` 传播。
   - 命令执行、退出码、标准输出、工作目录等都是显式值，不做 bash 式隐式魔法。

4. **以 hosted 路线为主**
   - 脚本运行时第一目标是 hosted Linux / macOS，随后扩到 hosted Windows。
   - `nostdlib`、microapp、kernel 路线不作为脚本运行时 MVP 目标。

5. **为后续性能优化留口**
   - 短期先跑通 C99 hosted。
   - 中期允许 `uya script` 优先尝试 `--exec`/`--vm`，在能力不足时再回退。

---

## 非目标

1. **不做 bash/csh 语法兼容**
   - 不承诺支持 `$(...)`、反引号命令替换、`[[ ... ]]`、shell function、alias、job control、`trap`、`set -euo pipefail` 语法兼容。

2. **不做交互式 shell**
   - 本文档关注“脚本运行时”和“标准库”，不关注 REPL、提示符、历史记录、终端编辑。

3. **不把命令字符串当主接口**
   - `system("gcc ...")` 只能作为显式 fallback。
   - 默认 API 必须是 argv / env / cwd / stdio 的结构化模型。

4. **不在第一阶段替换 `src/compile.sh`**
   - `compile.sh` 兼容层级高、平台语义复杂，放在后续阶段。

5. **不承诺第一阶段完成 Windows 全覆盖**
   - 设计必须从第一天面向 Windows，但 MVP 可以先在 Linux / macOS hosted 跑通。

---

## 当前基线

仓库已经具备一部分脚本运行所需基础，但仍缺少“高层脚本 API”和“完整跨平台 hosted backend”。

### 已有基础

- `std.runtime` 已缓存 `argc` / `argv` / `envp`
- `lib/std/env.uya` 已提供 child-only env block builder：
  - `get` / `has` 读取当前保存的环境变量视图
  - `EnvBlockBuilder` 可从当前或指定 `envp` 继承，并按顺序应用 `with` / `without`
  - `build()` 生成以 null 结尾、可传给 `execve` / `os_execve` 的 child 专属 envp
- `lib/osal/osal.uya` 已提供：
  - `os_spawn`
  - `os_exec`
  - `os_waitpid`
  - `os_chdir`
  - `os_getcwd`
  - 文件、目录、stat、dup/dup2、pipe/pipe2 等基础能力
- `lib/libc/unistd.uya` 已提供：
  - `fork`
  - `execve`
  - `waitpid`
  - `system`
  - `chdir`
  - `getcwd`
  - `dup2`
- `lib/libc/syscall.uya` 已有 `sys_pipe2`
- `lib/std/io/file.uya` 已提供最小同步文件 I/O

### 当前缺口

1. **缺少高层模块边界**
   - 现在更接近 syscall/libc/osal 能力集合，还没有 `std.process`、`std.fs`、`std.env`、`std.path`、`std.script` 这类脚本作者直接可用的高层 API。

2. **当前进程全局环境变量写接口未完成**
   - child-only env block builder 已可用于子进程环境覆盖/删除。
   - `setenv` / `unsetenv` / `clearenv` 仍是占位实现，不适合作为脚本运行时公开“修改当前进程环境”的语义。

3. **默认 `run` 路径仍有字符串拼接**
   - 当前 `uya run/test` 仍有一部分逻辑靠命令字符串 + `system()` 驱动，不适合作为未来标准库 API 的方向。

4. **shebang launcher 约定未完成**
   - lexer 已支持忽略文件开头 `#!...`；完整脚本 UX 仍缺 `uya script` 或 wrapper 约定。

5. **Darwin hosted 的脚本运行时仍有少量 bridge 差集**
   - 已有下层能力：`chdir/getcwd`、`stat/fstat/lstat`、`readlink`、`dup2`、`pipe2`、`fork/waitpid`、`opendir/readdir/closedir`、`poll`、`clock_gettime/nanosleep` 已经有 Darwin 分支或 `uya_macos_*` 宿主 bridge，`std.process/std.fs` 可以直接复用这些原语。
   - 仍缺第一条真正的 process-launch bridge：`os_spawn` / `os_execve` 最终仍落到 `sys_execve()`，而 `sys_execve` 目前没有 `std.target_os == .tos_macos` 的 `uya_macos_*` 宿主桥，只保留原始 `@syscall(SYS_execve, ...)` 路径；如果要把“spawn child + argv/envp + cwd/stdio 重定向”作为 Darwin hosted 的公开承诺，这一层需要补显式 bridge，或至少有 macOS 真机 smoke 证明原始路径可靠。
   - 仍缺当前进程 env mutation bridge：`setenv` / `unsetenv` / `clearenv` 仍是占位实现。第一批脚本迁移可继续只依赖 child-local `EnvBlockBuilder`，但一旦脚本运行时要公开“修改当前进程环境”，Darwin hosted 需要补真实宿主 bridge 或运行时 canonical env view。
   - 若保持 A 类候选 `verify_project_root_embedded_uya_resolution.sh` 的“目录 symlink helper”目标，底层还缺 `symlink` / `os_symlink` / `sys_symlink` 这一条能力；当前仓库只有 `readlink`，还不能无 shell 地创建目录符号链接。

6. **Windows hosted backend 未完成**
   - 枚举、toolchain、target 宏已经具备，但脚本运行时需要的进程/环境/文件系统 Win32 bridge 还没有形成公共抽象。

7. **`--exec`/`--vm` 仍在扩覆盖**
   - 脚本运行时未来可利用 exec backend 降低启动成本，但不能把它作为当前设计前提。

---

## 设计原则

### 1. 结构化优先于字符串

脚本 API 的主路径必须显式表达：

- 程序路径
- argv
- cwd
- env
- stdin/stdout/stderr
- 退出状态

不允许要求调用方自己拼命令字符串、自己做 shell quoting、自己猜测平台差异。

### 2. `std.script` 只是 facade，不是大杂烩

脚本作者会直接使用 `std.script`，但核心能力应拆到更稳定的基础模块：

- `std.process`
- `std.fs`
- `std.env`
- `std.path`

`std.script` 只负责把这些能力组合成“替换 `.sh` 常用模式”的便捷层。

### 3. 默认不经过 shell

`run(["git", "status"])` 是一等用法。  
`run("git status")` 不应成为默认模型。

如果调用方明确要依赖宿主 shell 行为，应使用显式 API，例如：

- `run_shell_sh(...)`
- `run_shell_cmd(...)`

也可以接受更中性的命名，但必须让“经过 shell”是显式选择，而不是隐式行为。

### 4. 平台差异收敛在底层

上层脚本作者不应感知：

- POSIX `fork/execve`
- Windows `CreateProcessW`
- path separator
- executable suffix
- PATH 分隔符
- UTF-8 / UTF-16 细节

这些差异必须由 `osal` / hosted C bridge / `std.path` / `std.process` 吸收。

### 5. 先替脚本，再谈新语言特性

脚本化 MVP 不依赖新增语法。  
第一阶段仍使用普通 Uya 程序入口：

```text
export fn main() !i32
```

`uya script` 与 shebang 作为后续 UX 增强，而不是第一阶段阻塞项。

---

## 分层模型

建议采用如下结构：

```text
Uya script / tests/*.uya / tools/*.uya
            |
            v
        std.script
            |
            v
  std.process / std.fs / std.env / std.path
            |
            v
          osal
            |
            v
   syscall + hosted C bridge + runtime entry
```

分层职责：

| 层级 | 职责 |
|------|------|
| `std.script` | 面向脚本作者的高层帮助函数、日志、断言、pipeline facade、仓库脚本惯用法 |
| `std.process` | 结构化进程执行、重定向、输出捕获、退出码 |
| `std.fs` | 文件与目录操作、文本/字节读写、临时目录、递归删除/创建 |
| `std.env` | 环境变量读取、覆盖、子进程环境构造 |
| `std.path` | 路径拼接、规范化、后缀、PATH 搜索辅助 |
| `osal` | 平台能力统一抽象 |
| `syscall + hosted bridge` | 各平台真实系统接口 |

---

## 模块设计

## 1. `std.process`

`std.process` 是脚本化能力的核心模块。

### 1.1 语义要求

- 默认按 argv 调用可执行文件
- 不做 shell 展开
- 支持 cwd 覆盖
- 支持 child-only env 覆盖
- 支持 `stdin/stdout/stderr` 重定向
- 支持输出捕获
- 支持等待与退出码解析
- 支持 pipeline，但 pipeline 是“进程图”或 helper，不是 shell 文法

`Pipeline`、`|>`、checked/observing sink、capture 限制、stage 状态与跨平台取消域的详细语义由 [`typed_pipeline_design.md`](typed_pipeline_design.md) 统一定义；`std.process` / `std.script` 不得再建立不兼容的平行 pipeline API。

### 1.2 建议数据模型

- `Command`
  - path
  - argv
  - cwd override
  - env overlay / env remove
  - stdio config
- `Child`
  - pid / 平台句柄
  - `wait()`
  - `kill()`
  - `take_stdout()`
  - `take_stderr()`
- `ExitStatus`
  - 是否正常退出
  - exit code
  - signal / platform-specific termination reason
- `Output`
  - `status`
  - `stdout`
  - `stderr`

### 1.3 公开能力建议

- `status`：只关心退出码
- `output`：捕获 stdout/stderr
- `spawn`：异步或可等待 child
- `check`：非 0 直接返回错误
- `pipe`：创建父子或多进程管道

### 1.4 公开语义限制

- 不保证暴露 `fork`
  - `fork` 保留在 `osal`/`libc` 层，作为 POSIX 细节
- `exec` 可以保留，但不应成为脚本作者主路径
- `Command` 构造 PATH 搜索时应是显式策略
  - `command("git")` 可以执行 PATH 查找
  - `command_path("/abs/path/git")` 可显式绕过搜索

---

## 2. `std.env`

脚本需要大量环境变量操作，但这里必须区分两种语义：

1. **当前进程读取**
2. **子进程环境构造**

建议优先把“子进程环境构造”做稳，而不是把进程级 `setenv()` 作为第一优先级。

### 2.1 MVP 能力

- `get`
- `has`
- `iter`
- `inherit_current`
- `with`
- `without`
- 生成传给 `std.process.Command` 的 env block

### 2.2 设计原则

- 脚本 API 中，优先使用 child-local env overlay：
  - 不要求先修改当前进程全局环境，再起子进程
- 如果后续补齐真实 `setenv` / `unsetenv`，也应明确区分：
  - `env_set_current(...)`
  - `command.env_set(...)`

### 2.3 child-local env overlay 语义约束

- `Command` / `spawn` 默认从当前进程环境读取一个只读快照作为 base env。
- overlay/remove 只作用在“本次 child exec 要传入的 env block”：
  - `with(KEY, VALUE)` / `command.env_set(KEY, VALUE)`：为该 child 新增或覆盖变量。
  - `without(KEY)` / `command.env_remove(KEY)`：从该 child 的最终 env block 中删除变量。
- 同一个 key 的多次操作按调用顺序生效：
  - 后一次 `with` 覆盖前一次 `with`。
  - `without` 可以删除继承来的 key，也可以删除本轮更早的 `with`。
  - `without` 之后再次 `with`，表示重新加入该 key。
- 最终传给 `execve` / 平台等价 API 的 env block 中，同一个 key 最多出现一次。
- 这些修改不会回写当前进程的 `saved_envp`，也不会影响后续无关 `Command`；脚本内 `std.env.get(...)` 读取到的仍是当前进程原始环境。
- MVP 不允许通过“先全局 `setenv` / `unsetenv`，spawn 完再回滚”来模拟该能力；必须直接构造 child 专属 env block。
- 当前进程全局 env mutation 属于后续独立能力，不与 child-local overlay 复用同一套 API 名称或隐式副作用。

### 2.4 当前进程全局 env mutation 语义约束

- 这不是 Phase 1 MVP 的前置条件：
  - 脚本替换主路径仍优先依赖 child-local overlay，而不是先补进程级 `setenv()`。
- 若后续公开该能力，API 名称必须显式表达“修改当前进程”：
  - 例如 `env_set_current(...)` / `env_remove_current(...)` / `env_clear_current()`。
  - `with(...)` / `without(...)` / `command.env_set(...)` 继续只保留 child-only 语义。
- 成功后的可见性必须一致：
  - 同一进程后续 `std.env.get(...)` / `has(...)` / `iter(...)` 读取到更新后的状态。
  - 后续 `inherit_current()` 或 `Command` base-env 快照以更新后的当前进程环境为准。
  - 已经生成好的 env builder、child env block、以及已经启动的 child，不会被回溯修改。
- 失败语义必须显式暴露：
  - 不支持的 hosted backend、内存分配失败、非法 key/value 等情况必须返回错误。
  - 脚本层 API 不能复用当前 libc stub “返回成功但不生效”的行为；silent no-op 不可接受。
- 实现边界必须清楚：
  - `saved_envp` 只代表进程启动时捕获的初始视图，不应继续被当作可变真值源。
  - 一旦支持 current mutation，运行时必须维护可变的 canonical env view，确保 `getenv`、`inherit_current()` 和 child spawn 读取同一份状态。
  - 该能力是进程级共享状态，不提供 task-local / coroutine-local 环境变量语义。

---

## 3. `std.fs`

`std.fs` 负责替掉脚本里最常见的：

- `mkdir -p`
- `rm -rf`
- `cp`
- `mv`
- `test -f/-d`
- `cat`
- `printf > file`
- 目录遍历与查找

### 3.1 MVP 能力

- `exists`
- `is_file`
- `is_dir`
- `mkdir`
- `mkdir_all`
- `remove_file`
- `remove_dir`
- `remove_dir_all`
- `rename`
- `read_text`
- `write_text`
- `read_bytes`
- `write_bytes`
- `read_dir`
- `temp_dir`
- `create_temp_dir`

### 3.2 后续能力

- `copy_file`
- `canonicalize`
- `walk`
- `glob`
- 文件时间与权限

### 3.3 设计要求

- 尽量不要要求脚本作者自己处理 trailing slash、平台分隔符、临时目录命名
- 文本读写应显式区分字节与 UTF-8 文本

---

## 4. `std.path`

`std.path` 负责收敛平台差异，而不是让每个脚本都自己写：

- `"/"` 与 `"\\"`
- `.exe`
- `PATH` 分隔符
- 相对/绝对路径判断

### 4.1 MVP 能力

- `join`
- `dirname`
- `basename`
- `stem`
- `extension`
- `is_abs`
- `normalize`
- `path_list_separator`
- `executable_suffix`

### 4.2 Windows 要点

- 公共 API 仍使用 UTF-8 byte string
- Windows hosted bridge 内部负责 UTF-8 → UTF-16 转换
- 默认不把“路径大小写等价”作为隐式规则
  - 如有需要，单独提供 helper

---

## 5. `std.script`

`std.script` 是“替换 `.sh`”最直接的用户层。

它不应该重新包装所有底层 API，而应提供仓库脚本高频模式：

- `run_checked`
- `capture_text`
- `assert_exit_code`
- `require_tool`
- `project_root`
- `workspace_temp_dir`
- `log_info`
- `log_warn`
- `fail`

### 5.1 适合放进 `std.script` 的能力

- 仓库自动化常见的断言和错误输出风格
- pipeline helper
- 命令执行 + 文本匹配 + 退出码检查组合
- 临时工作区管理

### 5.2 不适合放进 `std.script` 的能力

- 裸 syscall / fd 细节
- 通用路径算法
- 目录项结构体定义
- 大量 libc 兼容函数别名

---

## 脚本入口与运行方式

## Phase 1：普通 Uya 程序入口

第一阶段不新增语法，脚本文件直接写成：

```text
export fn main() !i32
```

运行方式：

```text
./bin/uya run path/to/script.uya -- ...
./bin/uya run path/to/script.ush -- ...
```

优点：

- 不阻塞标准库设计
- 复用现有 runtime entry / argv / envp
- 迁移仓库脚本时最容易落地

## Phase 2：`uya script`

在标准库与迁移模式稳定后，可以新增：

```text
./bin/uya script path/to/script.uya -- ...
```

建议语义：

- 对脚本模式使用更贴近自动化任务的默认值
- 允许优先尝试 `--exec`
- 在能力不足时回退 C99 hosted
- 为 shebang 提供统一入口

## Phase 3：shebang

当前已支持 lexer / parser 容忍文件开头 `#!...`，因此 `uya run path/to/script.ush` 可运行带 shebang 的 Uya 源文件。

shebang 完整 UX 仍需要两部分支持：

1. **lexer / parser 容忍首行 `#!...`**（已落地）
2. **launcher 约定**

需要注意：

- POSIX shebang 与 Windows 无直接对称关系
- 在 `uya script` 落地前，POSIX 直接执行建议写作 `#!/usr/bin/env -S uya run`
- Windows 仍主要通过 `uya script file.uya` 或文件关联运行

因此 shebang 是 UX 增强，不是跨平台脚本 MVP 的核心前提。

---

## 跨平台策略

## 1. 公开 API 避免暴露 POSIX-only 语义

对脚本作者稳定承诺的是：

- `spawn`
- `status`
- `output`
- `cwd`
- `env overlay`
- `pipe`

不是：

- `fork`
- `execve`
- `SIGCHLD`

## 2. Windows hosted backend 走显式 bridge

若要把脚本运行时扩到 Windows，必须补齐一批 hosted bridge：

- 进程创建
- 等待子进程
- 目录遍历
- cwd
- 环境变量
- 路径 stat / remove / rename
- pipe / 重定向

建议在生成 C 的 hosted backend 中统一桥接，而不是在上层脚本库写大量平台 `cfg` 分支。

其中 `process spawn/wait` 这一项需要尽早收敛接口边界：

- 当前 `lib/osal/osal.uya` 的 `os_spawn` 仍建立在 `sys_fork() + sys_execve()` 上，`os_waitpid` 也直接透传 `sys_waitpid()`；这说明现有 POSIX 进程模型不能直接拿来做 Windows hosted 公共实现。
- Windows 最小 bridge 应围绕“创建子进程 + 等待并取回退出码”设计，而不是暴露 `fork/execve/waitpid`：
  - `spawn`：对外继续保持 UTF-8 `path/argv/env/cwd/stdio` 的结构化输入；bridge 内部负责命令行/环境块宽字符转换，并调用 `CreateProcessW`。
  - `wait`：持有子进程句柄，使用 `WaitForSingleObject` 等待完成，再用 `GetExitCodeProcess` 取退出码，并在回收路径关闭句柄。
- `cwd`、`env`、`pipe/stdio redirection` 虽然在 TODO 中拆成独立子项，但 `spawn` bridge 的 ABI 从一开始就应预留这些可选输入，避免后续为 Windows 再做一次公开 API 改版。
- `cwd` 这一项本身也需要尽早固定语义边界：
  - 分成两类能力：当前进程 `os_getcwd` / `os_chdir`，以及 child-only 的 `Command.cwd` override；两者都属于脚本运行时最小集合，但不能混成一个“先 `chdir` 再回滚”的实现。
  - 当前仓库的 hosted C99 codegen 已经声明 `_chdir` / `_getcwd` alias，这说明 Windows hosted 确实存在最小 `cwd` bridge 入口；但公共 API 既然承诺保持 UTF-8 byte string，这个入口最终不能停留在窄字符 CRT 语义上。
  - 最终 Windows bridge 应把 UTF-8 `path` 转成 UTF-16 后再调用 `_wchdir` / `_wgetcwd` 或等价 Win32 宿主接口，并把结果重新转回 UTF-8；否则带非 ASCII 路径的脚本行为会依赖本地代码页，破坏跨平台一致性。
  - `Command.cwd` 必须直接落到 child process 创建参数（例如 `CreateProcessW` 的 `lpCurrentDirectory`），不能通过修改父进程 cwd 来模拟；否则并发脚本、日志路径和后续相对路径解析都会出现竞态。
- `env` 这一项也应尽早固定为“两层 bridge”：
  - 当前 `std.env.get(...)` / `has(...)` 与 `inherit_current()` 都建立在 `saved_envp` 上，而 `saved_envp` 现在来自进程启动时捕获的窄字符 `envp`；这可作为 bring-up 路径，但不能当作 Windows 脚本运行时的最终跨平台承诺，因为它会受本地代码页影响。
  - Windows 最小可交付应在进程启动阶段从宽字符宿主环境（`GetEnvironmentStringsW` 或等价入口）构造 UTF-8 canonical env view，并让 `std.env.get/has/iter`、`inherit_current()` 与后续 child spawn 共用这份视图。
  - child-only overlay 继续复用现有 `EnvBlockBuilder` 语义：上层保持 UTF-8 `KEY=VALUE` 列表，Windows spawn bridge 在最后一步把最终 env block 转成 UTF-16 双 `\0` 结尾缓冲区，并通过 `CreateProcessW(..., lpEnvironment=...)` 传入；不允许通过先修改父进程全局环境、spawn 后再回滚的方式模拟。
  - 当前进程 env mutation 不是 Windows Phase 1 的前置条件；若后续公开 `env_set_current(...)` / `env_remove_current(...)` 一类能力，必须同时更新 canonical env view，并落到真实宿主 API，而不能复用当前 `setenv` / `unsetenv` / `clearenv` stub 的 silent success。
- `pipe / stdio redirection` 这一项也应作为同一批最小 bridge 收口：
  - 行为基线先与当前 POSIX 回归对齐：`tests/test_osal.uya` 已经覆盖 `stdin -> child` 文件重定向、`stderr -> file` 重定向，以及“父进程通过 pipe 捕获 child stdout”三类最小语义；Windows hosted 至少要能稳定复现这三条路径，才能支撑后续 `Command.stdin/stdout/stderr`、`output()` 与脚本日志捕获。
  - 公共 ABI 不应暴露 Win32 句柄细节，也不应要求上层模拟 `dup2(fd, 0/1/2)`；最小接口仍保持 `Command` 上的结构化 stdio 配置，例如 `inherit` / `null` / `file` / `pipe endpoint`，由 spawn bridge 在内部翻译成 `CreateProcessW` 所需的 child stdio 句柄。
  - `pipe` 最小 bridge 需要返回一对可区分“parent 端 / child 端”职责的匿名管道端点，并在创建后立刻收敛继承语义：父进程自己持有并继续读写的端点默认不可继承，只把 child 真正需要的端点暴露给 `spawn`。这样 `output()`、`take_stdout()`、`take_stderr()` 与后续 pipeline helper 才能共用同一套底层原语，而不是分别拼装临时方案。
  - `stdin/stdout/stderr` 重定向必须允许三路分别配置，不能把“capture stdout/stderr”偷换成单一 merged pipe；只有公开 API 显式请求合并时，bridge 才能复用同一个 child 端点。否则 `status/output/check` 与仓库脚本常见的“stdout 做数据、stderr 做日志”模式无法保持一致。
  - 句柄生命周期要由 bridge 自己封装：`spawn` 成功后父进程立即关闭 child-only 端点，失败路径也统一回收，避免泄漏；child 等待完成后只保留 `Child` 仍需读取的 pipe 端点或进程句柄。这样 Windows hosted 行为才与当前 POSIX `fork + dup2 + close` 模型在资源语义上对齐。
- `stat/remove/rename` 这一组也应作为同一批最小 bridge 收口：
  - 当前 `lib/libc/stdio.uya` 的 `remove()` 语义建立在 `sys_stat()` + `sys_rmdir()` / `sys_unlink()` 分发之上，`rename()` 直接透传 `sys_rename()`；而 `lib/libc/syscall.uya` 目前只对 macOS 提供了 hosted 分支，Windows hosted 还没有对应 bridge，因此这三项不能拆成彼此独立的“后补优化”。
  - `stat` 最小 bridge 需要接受 UTF-8 路径、在内部完成 UTF-16 转换，并返回脚本运行时真正需要的基础元数据：是否存在、是否目录、文件大小、时间戳与错误码。实现上可走 `GetFileAttributesExW` / `GetFileInformationByHandleEx`，或 `_wstat64` 一类宽字符 CRT 入口，但对外都要继续映射到统一的 `os_stat` / `std.fs` 语义。
  - `remove` 不能依赖当前 POSIX-only 的 `sys_unlink` / `sys_rmdir` 路径；最小 bridge 至少要能区分“文件删除”和“目录删除”，并保持与公共 API 一致的错误语义。实现上可以复用 `stat` 结果后分发到 `DeleteFileW` / `RemoveDirectoryW`，也可以直接调用宽字符 CRT 等价入口，但必须共用同一套 UTF-8 → UTF-16 路径转换。
  - `rename` 需要与现有 `sys_rename` 语义对齐，而不是退化成“目标已存在就失败”的弱语义；因此 Windows hosted 最小 bridge 应优先落到 `MoveFileExW(..., MOVEFILE_REPLACE_EXISTING)` 或等价实现，并继续复用同一套 UTF-8 路径转换与错误映射。
- `dir traversal` 这一项也应作为独立最小 bridge 收口：
  - 当前 `lib/libc/stdlib.uya` 的 `opendir/readdir/closedir` 只有两条实现路径：macOS hosted 走 `uya_macos_host_opendir/readdir_fill/closedir`，其余 target 走 `sys_open + sys_getdents64 + sys_close`；Windows hosted 既没有 POSIX `DIR*`，也没有现成 bridge，因此目录遍历不能直接复用当前 hosted 逻辑。
  - 对外接口仍应保持 UTF-8 `path` + 统一 `libc.Dirent` 抽象；Windows bridge 内部负责 UTF-8 → UTF-16 转换，并以 `FindFirstFileW` / `FindNextFileW` / `FindClose`（或等价宽字符 CRT）维护不透明目录句柄。诸如追加 `\\*` 搜索模式之类的 Windows 细节只能停留在 bridge 内部，不能泄漏到未来 `std.fs` / `std.path` API。
  - `readdir` 最小 bridge 只需要填充当前真实消费者依赖的 `d_type` 与 `d_name`，其余 `libc.Dirent` 字段可保持零值；这与当前 macOS hosted `uya_macos_host_readdir_fill(...)` 先清零再只写类型与名称的收敛方式保持一致，也避免把 Windows 原生目录项布局暴露给上层。
  - `d_type` 至少要稳定区分 `DT_DIR` / `DT_REG`，其余难以准确映射的情况可以退到 `DT_UNKNOWN`；当前编译器与模块扫描已经存在 `dirent_may_be_regular_file(...)` 的 `DT_UNKNOWN` fallback，因此不必把 Windows reparse point 细节变成 Phase 1 阻塞项。
  - 目录 bridge 还需要自己缓存 `FindFirstFileW` 返回的首个目录项，并在 `closedir` 与错误路径统一释放句柄；否则“首条目录项已被消费”这一 Win32 API 细节会泄漏进 `readdir` 语义，破坏现有 `opendir -> readdir* -> closedir` 调用模型。

## 3. PATH 搜索必须平台敏感

`which` / `Command` 路径查找要考虑：

- `PATH` 分隔符
- Windows 可执行后缀
- 是否接受当前目录搜索

这些都应收敛在 `std.path` / `std.process` 内部。

## 4. shell fallback 显式区分平台

如果必须执行 shell 字符串：

- POSIX 走 `/bin/sh -c`
- Windows 不能默认假设 `cmd.exe` 与 POSIX shell 语义等价

因此 fallback API 需要显式选择：

- `run_shell_sh`
- `run_shell_cmd`

或者等价设计，但不能把不同 shell 语义伪装成同一个接口。

---

## 性能策略

提升性能的来源主要有三类：

1. **减少 shell 层**
   - 直接 `spawn(argv)`，而不是 `system("cmd ...")`

2. **减少工具链小进程**
   - 用 `std.fs`、`std.path`、`std.env`、`std.process` 替掉 `grep`、`dirname`、`basename`、`mkdir -p`、`rm -rf` 等琐碎命令

3. **后续接入 exec backend**
   - `uya script` 可以优先尝试 `--exec`
   - 对纯 Uya 脚本可明显降低启动与链接成本

不应把性能目标绑定在“模拟 bash 语法”上。

---

## 仓库迁移策略

建议按复杂度分三类脚本推进：

### A 类：优先迁移

特征：

- 主要是编译器调用、退出码断言、文件存在性检查、少量文本匹配
- 少依赖复杂 shell 文法

候选：

- `tests/verify_check_cli.sh`
  - 理由：脚本仅包含三次编译器调用、成功/失败退出码断言和少量帮助文本匹配，没有循环、目录遍历或复杂 shell 展开，适合作为第一批 `.sh -> .ush` 迁移样板。
  - 行为 oracle：验证 `uya check` 对成功输入只走 checker、不进入代码生成；对语法错误返回失败；`--help` 继续暴露 `check <文件>` 入口。
  - 迁移所需最小能力：`std.process` 的退出码与 stdout/stderr 捕获，`std.script` 的包含匹配断言，以及临时日志文件创建/清理帮助函数。
- `tests/verify_exec_vm_compiler_regressions.sh`
- `tests/verify_split_build_output.sh`
- `tests/verify_project_root_embedded_uya_resolution.sh`
  - 理由：脚本主体是一次带 `UYA_ROOT` child env overlay 的编译器调用，加上临时目录创建、目录 symlink、内联测试源码写入和 `test -s` 文件断言，没有循环、管道或复杂 shell 展开，适合作为第一批 `.sh -> .ush` 迁移样板。
  - 行为 oracle：在临时 `uya/lib -> <repo>/lib` 布局下编译 `use std.async` 的最小程序时，`UYA_ROOT="$TMP_DIR/uya/lib/"` 必须让编译成功生成非空 `out.c`，并继续输出 `embedded project-root stdlib resolution ok`。
  - 迁移所需最小能力：`std.script.project_root` 定位仓库根，`std.env` 的 child-only env overlay，`std.fs` 的 `create_temp_dir` / `mkdir_all` / 目录 symlink helper / `write_text` / `remove_dir_all` / 文件大小断言，以及 `std.process` 的命令执行和 stderr 重定向到固定日志文件。

### B 类：第二批迁移

特征：

- 有较多临时目录、文本处理、目录遍历、并行/循环逻辑

候选：

- `tests/verify_exec_vm_smoke.sh`
- `tests/verify_exec_backend_progress.sh`
- `tests/run_programs_parallel.sh`

### C 类：后期迁移

特征：

- 平台分支重、工具链耦合深、兼容性要求高

候选：

- `src/compile.sh`
- `tests/run_cross_platform_tests.sh`
- 涉及交叉编译矩阵的脚本

### 迁移原则

- 初期 `.sh` 与 `.uya` 并存
- 先让 `.uya` 脚本与旧 `.sh` 产出、退出码、关键日志对齐
- CI 切换前保留一段“双跑比对”窗口

---

## 测试与验收

脚本运行时需要三层验证：

## 1. 单元测试

- `std.process`
- `std.fs`
- `std.env`
- `std.path`

## 2. 集成测试

- 用迁移后的 `.uya` 脚本替换或并行验证现有 `.sh`
- 对齐：
  - 退出码
  - 关键 stdout/stderr
  - 产物文件
  - 临时目录清理行为

## 3. 平台测试

- Linux hosted：第一优先级
- macOS hosted：第二优先级
- Windows hosted：跨平台承诺成立前必须补齐

---

## 与现有主线的关系

本设计与以下主线直接相关：

- `std_refactor_design.md`
  - 脚本库应复用 `osal` 方向，而不是新造一套系统抽象
- `todo_cmd_subcommand_split.md`
  - 公开调度器应继续往 argv / `execve` 方向收敛，减少 `system()` 路径
- `todo_platform_shared_foundation.md`
  - Windows / Darwin hosted bring-up 将直接影响脚本跨平台能力
- `todo_bytecode_exec.md`
  - 后续 `uya script --exec` 可作为启动性能优化方向

脚本运行时不应复制已有 `osal` / `libc` 能力，也不应抢先定义与 `std.fs`、`std.process` 冲突的平行 API。

---

## 开放问题

1. `std.script` 是否一开始就公开，还是先只做 `std.process/std.fs/std.env/std.path`？
2. `Command` 是否需要内建 PATH 搜索，还是要求调用方显式选择？
3. 是否要在 MVP 暴露 pipeline，还是先只做 `status/output/spawn`？
4. Windows hosted backend 是否统一走宽字符 bridge？
5. `uya script` 是否默认优先 `--exec`，还是默认 C99 hosted、用参数显式切换？

这些问题不阻塞第一阶段文档和基础模块落地，但需要在实现期逐步收口。
