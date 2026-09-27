# 标准库重构待办

> **核对头（2026-09-27）**：本文件为 `std` 重构设计配套清单，未逐条核对；实现现状以 `lib/std/` 目录结构与测试为准。总体口径见 `docs/todo_status_index.md`。

基于 [std_refactor_design.md](std_refactor_design.md)，执行前请阅读设计文档。开发流程遵循 [.codebuddy/rules/uya-dev-flow.mdc](../.codebuddy/rules/uya-dev-flow.mdc)（TDD、`make check`）。

**实现约定**：每项任务均需「先写测试（或注明沿用现有测试）→ 实现 → `make check`」；大函数/深嵌套按 uya-dev-flow 规则拆分（函数 ≤50 行、嵌套 ≤3 层）。

**与仓库同步**（2026-04-02）：总览与 Phase 3 测试数、Phase 1.9 行数与当前 `lib/` 一致；Phase 4 区分「已有 `lib/libc/` 基线」与「按设计的大规模 libc 层重构」。

---

## 总览表

| Phase | 阶段       | 状态     | 说明 |
|-------|------------|----------|------|
| 1     | syscall 层 | 已完成   | 系统调用层，包含测试和迁移计划 |
| 2     | mem 层     | 已完成   | 纯内存操作层，独立基础层 |
| 3     | osal 层    | 已完成   | 操作系统抽象层，依赖 syscall（2026-03-05 完成） |
| 4     | libc 层    | 基线已有，重构暂缓 | **`lib/libc/`** 已有多模块薄封装（`string`/`stdio`/`syscall`/…）；与 mem 分工、跨层导入无冲突的「统一 libc 层」**重构**仍搁置，见 §Phase 4 |
| 5     | std 层     | 已完成   | Uya 原生风格层；Phase 5 条目已收口；另含 json/yaml/protobuf/http/async 等扩展模块，见 `lib/std/` |

**依赖与顺序**：syscall 无依赖；mem 无依赖；osal 仅依赖 syscall；libc 依赖 osal + mem；std 依赖 libc（及可选 osal）。执行顺序必须 Phase 1 → 2 → 3 → 4 → 5，避免跨层依赖。

---

## extern "libc" 与函数命名规则

> **重要**：AI 必须准确理解裸名与非裸名的规则，避免生成错误的函数声明。

### 规则速查表

| 语法 | C 输出 | 用途 |
|------|--------|------|
| `fn foo(...)` | `static void uya_foo(...)` | 内部函数，带 `uya_` 前缀 |
| `export fn foo(...)` | `void module_prefix_foo(...)` | 导出函数，**带模块前缀** |
| `extern fn foo(...)` | `extern void foo(...)` | 声明外部 C 函数，**裸名** |
| `extern "libc" fn foo(...)` | `extern void foo(...)` | 声明 C 标准库函数，**裸名**，`byte`→`char` |
| `export extern fn foo(...)` | `void foo(...)` | 用 Uya 实现 C 兼容函数，**裸名** |
| `export extern "libc" fn foo(...)` | `void foo(...)` | 用 Uya 实现 C 标准库函数，**裸名**，`byte`→`char` |

### 关键区分

**1. `export fn` vs `export extern fn`**

```uya
// ❌ 错误：libc 层使用 export fn 会导致 C 名带模块前缀
// lib/libc/string.uya（模块 libc.string → 前缀 libc_string）
export fn strlen(s: *const byte) usize { ... }
// 生成：usize libc_string_strlen(*const byte s)  ← 不是标准 C 库的 strlen！

// ✅ 正确：libc 层必须使用 export extern "libc" fn
export extern "libc" fn strlen(s: *const byte) usize { ... }
// 生成：size_t strlen(const char *s)  ← 标准 C 库签名！
```

**2. `lib/syscall/` 的特殊规则**

```uya
// lib/syscall/linux.uya（模块 syscall → 前缀 syscall_）
// 注意：此层不需要 extern "libc"，因为不链接 C 标准库

// ✅ 正确：syscall 层使用普通 export fn，会自动添加 syscall_ 前缀
export fn sys_read(fd: i32, buf: &byte, count: usize) !isize { ... }
// 生成：isize syscall_sys_read(i32 fd, byte* buf, usize count)

// ✅ 正确：syscall 层也可以使用裸名（如果需要与其他代码链接）
export extern fn sys_read(fd: i32, buf: &byte, count: usize) !isize { ... }
// 生成：isize sys_read(i32 fd, byte* buf, usize count)  ← 裸名
```

**3. `byte` 类型映射**

```uya
// 在 extern "libc" 声明中，byte 自动映射为 char
extern "libc" fn strlen(s: *const byte) usize;
// C 声明：size_t strlen(const char *s);  ← byte 变成 char

// 在普通函数中，byte 是 unsigned char
export fn my_func(s: &byte) void;
// C 声明：void module_prefix_my_func(unsigned char *s);
```

### 各层推荐用法

| 层 | 推荐语法 | 原因 |
|----|----------|------|
| **syscall** | `export fn sys_xxx(...)` | 自动添加 `syscall_` 前缀，避免符号冲突 |
| **mem** | `export fn xxx(...)` | 模块前缀隔离，如 `mem_copy` |
| **osal** | `export fn os_xxx(...)` | 模块前缀隔离，如 `osal_os_open` |
| **libc** | `export extern "libc" fn xxx(...)` | **必须裸名**，保持 C ABI 兼容 |
| **std** | `export fn xxx(...)` | 模块前缀隔离，Uya 原生风格 |

### 引用说明

详见 [`docs/uya.md`](uya.md) 第 114-133 行、第 2160-2199 行。

---

## Phase 1：syscall 层

### 1.1 基础设施（已完成）

- [x] 建立 `lib/syscall/`，新增 `linux.uya`（使用 `export fn`，不使用 `extern "libc"`，因为 syscall 层不链接 C 标准库）。
- [x] 编译器支持 `use syscall` → 收集 `lib/syscall/*.uya`（main.uya）；codegen 为 `lib/syscall/` 增加 `syscall_` 前缀（function.uya、expr.uya 回退）。
- [x] 为 lib/libc/ 和 lib/syscall/ 下的 export 变量添加模块前缀（排除 stderr/stdin/stdout 以保持与系统 libc 兼容）。

### 1.2 基础文件操作

- [x] `sys_read`、`sys_write`、`sys_open`、`sys_close`（已实现，已测试）。
- [x] `sys_lseek`（已实现，已测试）。
- [x] 补充 `test "sys_read_write_file" {}` 等功能测试（`tests/test_syscall_file.uya`）。

### 1.3 内存管理

- [x] `sys_mmap`、`sys_munmap`（已实现，已测试）。
- [x] `sys_brk`（已实现，已测试）。
- [x] 补充内存管理测试（已实现 test_syscall_mem.uya）。

### 1.4 进程/线程相关

- [x] `sys_exit`、`sys_getpid`、`sys_kill`、`sys_waitpid`（已实现，已测试）。
- [x] `sys_getppid`（已实现函数体，已测试）。
- [x] `sys_clone`（已实现，已测试）。
- [x] `sys_execve`（已实现，已测试）。
- [x] `sys_gettid`（已实现，已测试）。

### 1.5 时间相关

- [x] `sys_nanosleep`（已实现，已测试）。
- [x] `sys_gettimeofday`（已实现，已测试）。
- [x] 补充时间测试。

### 1.6 设备/控制

- [x] `sys_ioctl`（已实现，已测试）。
- [x] `sys_fcntl`（已实现，已测试）。
- [x] 补充设备/控制测试。

### 1.7 文件/目录

- [x] `sys_stat`、`sys_access`、`sys_readlink`、`sys_unlink`、`sys_mkdir`、`sys_rmdir`、`sys_chdir`、`sys_getcwd`（已实现，已测试）。
- [x] `sys_lstat`、`sys_fstat`、`sys_rename`、`sys_dup`、`sys_dup2`（已实现，已测试）。
- [x] 补充文件/目录测试（已实现 test_syscall_dir.uya）。

### 1.8 用户/组

- [x] `sys_getuid`、`sys_getgid`、`sys_setuid`、`sys_setgid`、`sys_geteuid`、`sys_getegid`（已实现，已测试）。
- [x] 补充用户/组测试。

### 1.9 清理工作

- [x] 明确 `lib/libc/syscall.uya` 的迁移/废弃计划（与 `lib/syscall/linux.uya` 存在重复）。

#### 迁移方案分析

**当前状态**（行数以仓库为准，会随提交变化）：
- `lib/libc/syscall.uya`（约 1100+ 行）：使用 `export extern "libc" fn` 等，提供 C 兼容封装
- `lib/syscall/linux.uya`（约 500+ 行）：使用 `export fn`，作为 syscall/osal 层的基础

**使用情况**：
- 测试文件（13 个）：`test_syscall_*.uya`、`test_std_syscall*.uya` 使用 `libc.sys_*`
- `lib/libc/pthread.uya`：使用 `libc.sys_futex`
- `lib/std/io/file.uya`：使用 `libc.sys_open`、`libc.sys_close`、`libc.sys_read`、`libc.sys_write`、`libc.sys_lseek`

**迁移策略对比**：

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| **方案 1：保留双文件** | 改动最小，维护简单，接口层次清晰 | 存在代码重复 | ⭐⭐⭐⭐⭐ |
| **方案 2：统一使用 syscall 层** | 消除重复，单一数据源 | 需修改所有测试和库文件 | ⭐⭐ |

**推荐方案：方案 1（保留双文件）**

理由：
1. **接口层次清晰**：
   - `lib/libc/syscall.uya`：提供 C 兼容接口（`export extern "libc" fn`），用于 libc 层
   - `lib/syscall/linux.uya`：提供 osal 接口（`export fn`），用于 osal 层

2. **维护简单**：
   - 无需大规模重构测试文件
   - 避免破坏现有 libc 层的兼容性

3. **明确分工**：
   - libc 层代码（如 `lib/libc/unistd.uya`、`lib/libc/stdio.uya`）继续使用 `@syscall` 内置函数
   - osal 层代码使用 `use syscall`（`lib/syscall/linux.uya`）
   - `lib/libc/syscall.uya` 仅作为测试和部分 libc 层的辅助函数

4. **代码重复可控**：
   - 两个文件各有其用途和接口要求
   - 可通过代码审查确保一致性

**实施计划**（Phase 4 统一处理）：
1. osal 层创建时，仅 `use syscall`（`lib/syscall/linux.uya`）
2. libc 层重构时，评估是否可以统一使用 syscall 层
3. 测试文件保持现状，减少不必要的改动

---

## Phase 2：mem 层

- [x] 建立 `lib/mem/`，**`mem.uya`（内存原语）+ `string.uya`（字符串原语）**（同属模块 `mem`，`use mem.*` 不变）。
- [x] 实现内存操作：`copy`、`copy_backward`、`set`、`zero`、`compare`、`memcmp`、`memset`、`memchr`；保证无系统调用依赖；测试先行，`make check` 通过。
- [x] 实现字符串操作（纯内存）：`strlen`、`strnlen`、`strcmp`、`strncmp`、`strcpy`、`strncpy`、`strcat`、`strncat`、`strchr`、`strrchr`；无外部依赖；测试先行，`make check` 通过。
- [x] 验证：编译通过、无循环依赖、被依赖方（如后续 libc）可引用。

### 2.1 std.mem 分配器（已落地，hosted）

- [x] **`lib/std/mem/allocator.uya`**：`export interface IAllocator`（`alloc` / `dealloc` / `realloc`，`!&byte`）；**`MallocAllocator`** 基于 **`extern fn malloc/realloc/free`**；**`g_allocator`**、**`get_allocator()`**。
- [x] 错误类型：`AllocError`、`AllocOutOfMemory`、`AllocInvalidSize`、`AllocInvalidPointer`（与设计中 union 式命名不同，以源码为准）。
- [x] 测试：**`tests/test_mem_allocator.uya`**（`test "..." {}`），覆盖分配/释放、`alloc(0)` 错误、`dealloc(null)`、`realloc` 扩容与空指针语义等；纳入 **`make tests`**。
- [x] **`lib/std/mem/arena.uya`**：**`export struct Arena : IAllocator`**（`alloc` / `dealloc` 空操作 / **`realloc`** 仅对**最后一次 bump** 原地缩扩；否则 **`AllocInvalidPointer`** / OOM）；保留 **`arena_init`**、**`arena_alloc`**、**`arena_reset`**；测试 **`tests/test_mem_arena.uya`**。设计名 **ArenaAllocator / FixedBufferAllocator** 在注释中与 **`Arena`** 对齐；独立类型别名待编译器对结构体别名 + `IAllocator` 单态 C 输出完善后再做。
- [x] **`lib/std/mem/heap.uya`**：**`HeapAllocator : IAllocator`**，基于 **`osal.os_mmap` / `osal.os_munmap`**（匿名私有映射 + 首部 `usize` 记录映射总长）；**`g_heap_allocator`**、**`get_heap_allocator()`**；测试 **`tests/test_mem_heap.uya`**。

---

## Phase 3：osal 层（已完成：2026-03-05）

- [x] 建立 `lib/osal/`，新增 `osal.uya`（统一实现，未拆分文件）。
- [x] `use syscall`；定义统一错误类型（使用 `error` 定义）；对外 API 使用 `!T` 风格。
- [x] 实现文件抽象：`os_open`、`os_close`、`os_read`、`os_write`、`os_seek`、`os_stat`、`os_fstat`、`os_lstat`；测试先行，`make check` 通过。
- [x] 实现内存管理抽象：`os_mmap`、`os_munmap`（底层调用 syscall）；测试先行，`make check` 通过。
- [x] 实现进程/线程抽象：`os_spawn`、`os_exec`、`os_exit`、`os_getpid`、`os_gettid`、`os_kill`、`os_waitpid`、`os_fork`、`os_getppid`；测试先行，`make check` 通过。
- [x] 实现时间抽象：`os_sleep`、`os_gettimeofday`、`os_clock_gettime`；测试先行，`make check` 通过。
- [x] 实现目录操作：`os_mkdir`、`os_rmdir`、`os_chdir`、`os_getcwd`、`os_access`、`os_unlink`、`os_rename`、`os_readlink`、`os_getdents64`；测试先行，`make check` 通过。
- [x] 实现其他功能：`os_dup`、`os_dup2`、`os_fcntl`、`os_ioctl`、`os_getuid`、`os_getgid`、`os_geteuid`、`os_getegid`、`os_setuid`、`os_setgid`、`os_getrlimit`、`os_setrlimit`；测试先行，`make check` 通过。
- [x] 验证：仅依赖 syscall，不依赖 libc/std；`make check` 通过（测试数以当前 CI/本地 `make check` 输出为准，2026-04-02 基线约 713）。

### osal 跨平台实现策略

- **接口统一**：所有平台暴露同一套 osal API（`os_open`、`os_read`、`os_write`、`OSError` 等），libc/std 只依赖该统一接口。
- **实现方式**：短期仅支持 Linux，osal 仅 `use syscall`（即 `lib/syscall/linux.uya`）。跨平台扩展采用「每平台一个 syscall 实现、接口一致」；osal 保持一份实现，通过构建/编译时选择当前平台的 syscall 模块；若工具链暂不支持按平台选 syscall 模块，则采用「每平台一份 osal 实现」（如 `osal/linux.uya`、`osal/windows.uya`），对外 API 严格一致，由应用或 libc 在编译时只 `use` 其中一份。
- **原则**：平台差异收敛在 syscall 层（或 per-platform 的 osal 实现）；osal 业务逻辑中不写 `#if`/平台分支。
- **验证**：新增平台时仅需新增对应 syscall 模块（及可选的 osal 实现），不修改已有 osal 调用方；`make check` 及该平台测试通过即可。

---

## Phase 4：libc 层（暂时搁置）

**仓库现状（与「未开始」区分）**：`lib/libc/` 下已有 **`ctype`/`errno`/`heap`/`math`/`mem`/`pthread`/`setjmp`/`signal`/`stdarg`/`stdio`/`stdlib`/`string`/`syscall`/`time`/`unistd`/`wchar`** 等模块，编译器与标准测试依赖这些基线。**搁置**的是：按 `std_refactor_design` 将 libc 与 `lib/mem` 职责彻底分清、并消除 `lib/libc/mem.uya` `use mem` 时的跨层命名冲突那一轮**重构**，而非从零实现 libc 目录。

**当前问题**（2026-03-05 发现）：
- lib/mem/mem.uya 同时导出内部函数（如 `mem_copy`）和 libc 兼容函数（如 `export extern "libc" fn memcmp`）
- 当 lib/libc/mem.uya 使用 `use mem` 时，编译器自举会因函数名冲突而失败
- 根本原因：编译器对 `lib/libc/` 目录有特殊处理，导致跨层导入时模块命名冲突

**短期方案**（推荐）：
1. 暂时搁置 Phase 4（libc 层）重构
2. 继续进行 Phase 5（std 层）开发
3. std 层可以直接使用 osal 和 mem 层，不受 libc 层问题影响

**长期方案**：
1. 分析并修复编译器对 `lib/libc/` 目录跨层导入的处理逻辑
2. 可能需要调整模块命名规则，支持同一目录下不同层级的模块隔离
3. 确保 libc 兼容函数能正确链接到系统 C 库而不产生冲突

---

---

## Phase 5：std 层

- [x] 在现有 `lib/std/` 基础上对齐设计文档：核心类型（`std.core.option.Option`、`std.core.error` 错误标签包装）与 traits（`Clone/Eq/Ord/Hash/Display` 接口）已就绪；新增 `tests/test_option_core.uya`，并完成 `make check`。
- [x] I/O 抽象（部分）：已导出 **`std.io.reader.Reader`**、**`std.io.writer.Writer`**；**`std.io.File`** + **`file_open` / `file_close` / `file_read` / `file_write`**（基于 **`libc.sys_*`**，与编译器依赖一致，避免拉入 `lib/syscall/linux.uya` 破坏多文件 C 的 err_union 顺序）。**`struct File : Reader, Writer`** 待编译器/单态稳定后再接；测试 **`tests/test_std_io_file.uya`**，`make check` 通过。
- [x] HeapAllocator（与 Phase 2.1 一致）：**`lib/std/mem/heap.uya`** 已用 **`osal.os_mmap` / `osal.os_munmap`** 实现 **`IAllocator`**；**`tests/test_mem_heap.uya`**。
- [x] 泛型容器（部分）：**`Vec<T>`**（**`lib/std/collections/vec.uya`** + **`tests/test_vec.uya`**）；**`StringBuf`**（**`lib/std/collections/string_buf.uya`**，内联 `byte` 缓冲、**不内嵌 `Vec<byte>`**，避免 C 后端对嵌套泛型 `Vec` 字段发射不完整；**`tests/test_string_buf.uya`**）。
- [x] 泛型容器：其余容器与设计对齐（如与 `Vec` 组合的更高层 API）；`HashMap` 通过 `values_vec/keys_vec` 将数据填充到调用方 `Vec`，并配套 `tests/test_hashmap.uya`。
- [x] SQL 抽象（首版）：已新增 **`lib/std/sql/`**，包含 **`types`** / **`driver`** / **`db`**；提供参考 Go `database/sql` 的 `Driver` / `Conn` / `Stmt` / `Rows` / `Tx` / `DB` 分层。为兼容当前 C99 backend，接口层优先采用“普通返回值 + `out` 参数”的稳定组合；回归 **`tests/test_std_sql.uya`** 已通过，真实 SQLite / MySQL 驱动待后续接入。
- [x] 验证：自举与测试通过；`lib/std` 仅向下依赖 **`libc`**、**`mem`**、**`syscall`**、**`osal`**（如 `HeapAllocator` 用 `osal`+`syscall` 常量），**`mem` / `osal` / `syscall` 不 `use std`**；`lib/libc` 中少数 shim 仍 `use std.runtime`（argv/env），为已知例外。2026-04-02：`make check` 通过（713/713）。

---

## 与 uya-dev-flow 的对接

- 每个任务均需「先写测试（或注明沿用现有测试）→ 实现 → `make check`」。
- 函数行数 ≤50 行、嵌套深度 ≤3 层；超出则拆分或提前返回/提取函数。
- 新增或修改的测试需同时通过 `--c99` 与 `--uya --c99` 方式。
