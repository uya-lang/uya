# uya-nostdlib 构建计划

> **核对头（2026-10-19，v0.10.4）**：目标已达成——`make uya` 现在**默认就是 `--nostdlib`**
> （静态链接、生成 C 内含 `_start`、链接 `crti.o + uya.o + crtn.o`）。
> `make uya-nostdlib` 因此已退化为**空别名目标**（`Makefile` 里 `.PHONY` 之后没有任何 recipe），
> 保留只为兼容旧脚本；hosted 主线请用 `make uya-hosted`。
> 另外：「循环依赖问题」一节记录的现象已被实际解耦——`src/main.uya` 现在直接
> `use libc;` / `use libc.stdlib;` / `use libc.unistd;` / `use std;`，源码级自举不依赖预编译的 libc。

## 目标

构建一个不依赖系统 libc 的自托管 Uya 编译器，所有 C 标准库函数由 Uya 自身实现。

## 当前状态

### 已完成

#### 1. `extern "libc" fn` 语法支持 ✅

- **语法**：`extern "libc" fn name(...) type;` 或 `export extern "libc" fn name(...) type { }`
- **用途**：显式声明 C 标准库函数，或用 Uya 实现替代 C 标准库函数
- **编译器修改**（C 版本已退役，Uya 版本已完成）：
  - `src/ast.uya`：添加 `fn_decl_extern_lib_name` 字段
  - `src/parser/`：支持解析 `extern "libc" fn` 语法
  - `src/checker/`：允许 `extern "libc" fn` 使用 FFI 指针类型
  - `src/codegen/c99/`：生成裸函数名（无模块前缀）

#### 2. `extern` 变量支持 ✅

- **语法**：
  - `extern const name: type;` - 导入只读 C 变量
  - `extern var name: type;` - 导入可变 C 变量
  - `export const name: type = value;` - 导出只读常量
  - `export var name: type = value;` - 导出可变变量
- **文档**：`docs/uya.md` 5.2.3 章节、`docs/changelog.md`、`docs/grammar_formal.md`、`docs/grammar_quick.md`
- **编译器实现**：Uya 自举编译器已完成（详见 `docs/extern_var_impl_plan.md`）

#### 3. `lib/libc/` 模块创建 ✅

已创建（`lib/libc/`）：`syscall.uya`、`mem.uya`、`string.uya`、`stdio.uya`、`stdlib.uya`、
`unistd.uya`、`time.uya`、`math.uya`、`ctype.uya`、`errno.uya`、`heap.uya`、`pthread.uya`、
`setjmp.uya`、`signal.uya`、`stdarg.uya`、`wchar.uya`。

### 已解决

#### 循环依赖问题 ✅

**问题描述**：编译器代码（`src/`）如果使用 `use libc.xxx` 导入 `lib/libc/` 模块，会导致循环依赖：
- 编译 Uya 编译器需要先有 libc 函数
- libc 函数实现需要 Uya 编译器编译

**当前状态（2026-10-19）**：已解耦。`lib/libc/` 是**源码级** Uya 模块，随 `src/` 一起被
同一个编译器进程解析、检查与生成 C，不需要预先存在 `lib/libc.a`；`src/main.uya` 直接
`use libc;` / `use libc.stdlib;` / `use libc.unistd;`。`bin/uya` 的 `--nostdlib` 链接只是不带系统
libc，与「源码来自哪里」无关。

## 解决方案

### 方案 A：两阶段构建（推荐）

```
阶段 1：使用系统 libc 构建编译器
┌─────────────────────────────────────┐
│  src/*.uya + extern fn (系统 libc)  │
│           ↓                         │
│      bin/uya (依赖系统 libc)        │
└─────────────────────────────────────┘

阶段 2：用编译器构建 lib/libc
┌─────────────────────────────────────┐
│  lib/libc/*.uya (export extern "libc" fn)  │
│           ↓                         │
│      lib/libc.a (纯 Uya 实现)       │
└─────────────────────────────────────┘

阶段 3：构建 nostdlib 版本
┌─────────────────────────────────────┐
│  src/*.uya + 链接 lib/libc.a        │
│           ↓                         │
│  bin/uya-nostdlib (无系统 libc 依赖) │
└─────────────────────────────────────┘
```

**优点**：
- 清晰的构建阶段
- 无需修改编译器代码结构
- 可增量构建

**实现步骤**（实际没有按此路径落地，见本节末）：
1. [ ] 修改 Makefile 添加 `lib/libc.a` 目标
2. [ ] 修改 Makefile 添加 `uya-nostdlib` 目标
3. [ ] 创建链接脚本，将 `lib/libc.a` 静态链接

> **实际落地方式（2026-10-19）**：没有做 `lib/libc.a`。`lib/libc/` 与 `src/` 一起作为**源码**
> 参与同一次编译，`make uya` 直接以 `--nostdlib` 链接出 `bin/uya`；
> `make uya-nostdlib` 是空别名（保留兼容），`lib/libc.a` 目标不存在。

### 方案 B：分离编译

将编译器分为两部分：
- `src/core/` - 核心编译逻辑，不依赖任何外部模块
- `src/platform/` - 平台相关代码，可依赖 `lib/libc/`

**优点**：
- 架构清晰
- 便于移植

**缺点**：
- 需要大量重构
- 增加维护成本

### 方案 C：桥接层

在 bridge.c 中实现必要的 libc 函数，编译器使用这些桥接函数。

**优点**：
- 改动最小
- 快速实现

**缺点**：
- 不是纯 Uya 实现
- 违背项目目标

## 待办事项

### 编译器实现（已完成）

- [x] **AST 修改**
  - [x] `compiler-c/src/ast.h`：添加 `AST_EXTERN_VAR_DECL` 节点类型
  - [x] `src/ast.uya`：添加相应字段

- [x] **Parser 修改**
  - [x] `compiler-c/src/parser.c`：解析 `extern const/var` 和 `export const/var`
  - [x] `src/parser.uya`：同上

- [x] **Checker 修改**
  - [x] `compiler-c/src/checker.c`：类型检查（确保 C 兼容类型）
  - [x] `src/checker.uya`：同上

- [x] **Codegen 修改**
  - [x] `compiler-c/src/codegen/c99/`：生成 `extern type name;` 等
  - [x] `src/codegen/c99/`：同上

### lib/libc 完善（已完成，通过 lib/std/c/ 实现）

**说明**：libc 函数已在 `lib/std/c/` 中完整实现，编译器通过 `use std.c.*` 导入使用。

**已实现的功能**：

- [x] `stdio`（`lib/std/c/stdio.uya`）：fopen, fclose, fread, fwrite, fprintf, fputs, sprintf, snprintf, fgetc, fputc 等
- [x] `stdlib`（`lib/std/c/stdlib.uya`）：malloc, free, calloc, realloc, exit, abort, atoi, atol, atof, strtod, strtol, stat, readlink, opendir, readdir, closedir, getenv 等
- [x] `syscall`（`lib/std/c/syscall/syscall.uya`）：sys_read, sys_write, sys_open, sys_close, sys_exit, sys_getpid, sys_lseek, sys_access, sys_unlink, sys_mkdir, sys_rmdir, sys_chdir, sys_getcwd 等
- [x] `string`（`lib/std/c/string.uya` + `lib/std/string.uya`）：memcpy, memmove, memset, memcmp, memchr, strlen, strcmp, strncmp, strcpy, strncpy, strcat, strchr, strrchr, strstr 等

**lib/libc/ 保留用途**：
- `lib/libc/syscall.uya`：底层系统调用常量和 `extern "libc" fn` 封装
- `lib/libc/mem.uya`：内存操作函数（使用 `extern "libc" fn` 语法）
- `lib/libc/string.uya`：字符串操作函数（使用 `extern "libc" fn` 语法）

### Makefile 修改

- [x] 添加 `lib/libc.a` 目标（**不需要**：改为 `lib/libc/` + `lib/std/c/` 源码直接参与编译）
- [x] 添加 `uya-nostdlib` 目标（现为 `make uya` 的空别名，因 `make uya` 默认已 `--nostdlib`）
- [x] 添加 `-nostdlib -static` 链接选项（链接 `crti.o + uya.o + crtn.o`）

### 测试

- [x] 单元测试：`extern "libc" fn` 语法
- [x] 单元测试：`extern const/var` 语法
- [x] 集成测试：`make uya` 以 `--nostdlib` 构建成功
- [x] 集成测试：静态链接可执行文件正常运行（`tests/verify_cmd_bins_nostdlib_static.sh` 校验外置命令同样静态）

## 文件结构

```
uya/
├── src/                 # Uya 自举编译器（唯一维护源；compiler-c/ 已退役）
│   ├── ast.uya
│   ├── parser/
│   ├── checker/
│   └── codegen/c99/
├── lib/
│   ├── libc/            # Uya 实现的 libc 封装（syscall / mem / string / stdio / stdlib / …）
│   └── std/c/           # 面向编译器的高层 C 名字封装
└── Makefile             # from-c / uya / uya-hosted / b / check …
```

## 时间线

| 阶段 | 内容 | 状态 |
|------|------|------|
| 1 | `extern "libc" fn` 语法支持 | ✅ 已完成 |
| 2 | 文档更新 | ✅ 已完成 |
| 3 | `extern` 变量编译器实现 | ✅ 已完成 |
| 4 | `lib/libc` 完善 | ✅ 已完成 |
| 5 | Makefile 和 nostdlib 构建 | ✅ 已完成 |
| 6 | 测试和验证 | ✅ 已完成 |

---

*最后更新：2026-10-19（v0.10.4 核对：`make uya` 默认 `--nostdlib`、`uya-nostdlib` 为空别名、循环依赖已解耦）*
