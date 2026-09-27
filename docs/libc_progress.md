# libc 开发进度与改进计划 v0.9.2

> **核对头（2026-09-27）**：本进度文档为 2026-03 快照，其中"待办"多项**已落地**：
> `Option<T>`（`lib/std/core/option.uya`）、`Writer`/`Reader`（`lib/std/io/writer.uya`、`reader.uya`、`stream.uya`）、`Vec<T>`/`StringBuf`（`lib/std/collections/vec.uya`、`string_buf.uya`）、`HeapAllocator`（`lib/std/mem/heap.uya`、`allocator.uya`）；
> pthread 侧 `CLONE_THREAD`（`lib/libc/pthread.uya` 的 `CLONE_FLAGS`）与 `set_tid_address`（同文件 join 退出握手）也已落地。
> 仍有效的剩余项：TSD destructor、多轮 cancel 语义细化、与系统 libc 的性能对比基准。

**整合版本**：基于 std_refactor_design.md v0.7.1 架构  
**日期**：2026-03-12（stdio _vfprintf_impl C99 兼容）  
**参考**：musl-libc (https://musl.libc.org)

## 概述

本文档记录了 Uya 语言 libc 的开发进度和后续改进计划。

### 架构层次

```
                    ┌─────────────────┐
                    │      std        │  Uya 原生风格
                    └────────┬────────┘
                             │ use
                    ┌────────▼────────┐
                    │     libc        │  C 兼容层
                    └────────┬────────┘
                             │ use
                    ┌────────▼────────┐
                    │      osal       │  操作系统抽象层
                    └────────┬────────┘
                             │ use
                    ┌────────▼────────┐
                    │    syscall      │  系统调用层
                    └─────────────────┘
                             ▲
                             │ use
                    ┌────────┴────────┐
                    │      mem        │  纯内存操作层
                    └─────────────────┘
```

### 当前实现状态

| 层级 | 目录 | 状态 |
|------|------|------|
| syscall | `lib/syscall/` | **已完成** |
| mem | `lib/mem/` | **已完成** |
| osal | `lib/osal/` | **已完成**（2026-03-05）
| libc | `lib/libc/` | **已实现**（待重构以使用 osal/mem） |
| std | `lib/std/` | **部分实现** |

---

## 一、libc 层（已实现）

### 1.1 已实现模块总览

| 模块 | 文件 | 主要函数 |
|------|------|----------|
| string | `lib/libc/string.uya` | strlen, strcmp, strcpy, strdup... |
| mem | `lib/libc/mem.uya` | memcpy, memset, memmove, memcmp... |
| stdio | `lib/libc/stdio.uya` | printf, fprintf, fopen, fread, fwrite... |
| stdlib | `lib/libc/stdlib.uya` | malloc, free, exit, atoi, qsort... |
| syscall | `lib/libc/syscall.uya` | sys_read, sys_write, sys_open... |
| unistd | `lib/libc/unistd.uya` | read, write, close, fork, exec... |
| ctype | `lib/libc/ctype.uya` | isalpha, isdigit, toupper... |
| errno | `lib/libc/errno.uya` | errno, strerror |
| time | `lib/libc/time.uya` | time, clock, strftime, localtime... |
| math | `lib/libc/math.uya` | sin, cos, exp, log, sqrt... |
| signal | `lib/libc/signal.uya` | signal, raise |
| setjmp | `lib/libc/setjmp.uya` | setjmp, longjmp |
| stdarg | `lib/libc/stdarg.uya` | va_start, va_arg, va_end |
| wchar | `lib/libc/wchar.uya` | mbtowc, wcslen, wcscpy... |
| pthread | `lib/libc/pthread.uya` | pthread_create, pthread_join, pthread_exit, pthread_self, pthread_mutex_*, pthread_cond_*, pthread_once, pthread_key_*, pthread_cancel |

### 1.2 string 模块（已完成）

- [x] `strlen` - 计算字符串长度
- [x] `strcmp` / `strncmp` - 字符串比较
- [x] `strcasecmp` / `strncasecmp` - 大小写不敏感比较
- [x] `strcpy` / `strncpy` - 字符串复制
- [x] `strcat` / `strncat` - 字符串连接
- [x] `strchr` / `strrchr` - 字符查找
- [x] `strstr` - 子串查找
- [x] `strdup` / `strndup` - 字符串复制（动态分配）
- [x] `strcspn` / `strspn` - 字符集长度计算
- [x] `strpbrk` - 字符集查找
- [x] `strtok` - 字符串分割
- [x] `strerror` - 错误消息（errno.uya）

### 1.3 mem 模块（已完成）

- [x] `memcpy` - 内存拷贝
- [x] `memset` - 内存填充
- [x] `memmove` - 内存移动（处理重叠）
- [x] `memcmp` - 内存比较
- [x] `memchr` - 内存中查找字符

### 1.4 stdio 模块（已完成）

- [x] `fopen` / `fclose` - 文件打开/关闭
- [x] `fread` / `fwrite` - 文件读写
- [x] `fgetc` / `fputc` - 字符读写
- [x] `fgets` / `fputs` - 行读写
- [x] `fprintf` / `printf` / `sprintf` / `snprintf` - 格式化输出
- [x] `fscanf` / `sscanf` - 格式化输入
- [x] `fflush` - 缓冲区刷新
- [x] `remove` / `rename` - 文件操作
- [x] `tmpfile` / `tmpnam` - 临时文件
- [x] `setbuf` / `setvbuf` - 缓冲区设置

#### 1.4.1 _vfprintf_impl 格式说明符（C99 兼容）

`fprintf` / `printf` / `sprintf` / `snprintf` 内部使用 `_vfprintf_impl`，已实现 C99 风格格式解析与输出：

| 类别 | 支持项 |
|------|--------|
| **flags** | `-` 左对齐、`+` 正号、空格、`0` 零填充、`#` 八进制/十六进制前缀 |
| **width / precision** | 数字、`*` / `.*` 从参数读取；字符串 `%.Ns`、整数 `%.Nd`、浮点 `%W.Pf` |
| **length** | `h` / `hh`、`l`、`ll`、`j` (intmax_t)、`z` (size_t)、`t` (ptrdiff_t)、`L` |
| **转换** | `d`/`i`/`u`/`o`/`x`/`X`、`f`/`F`/`e`/`E`/`g`/`G`、`a`/`A`（十六进制浮点）、`c`/`s`/`p`/`n`、`%%` |
| **length+转换** | `%zu`/`%zd`、`%jd`/`%ju`、`%td`/`%tu`、`%hd`/`%hu`、`%lld`/`%llu` 等，均支持 width 填充 |

浮点、`%c`、`%p` 均支持 width 左/右对齐与零填充；`%a`/`%A` 输出形式为 `0x1.xxxp±d` / `0X1.XXXP±d`。

### 1.5 stdlib 模块（已完成）

- [x] `malloc` / `free` / `calloc` / `realloc` - 内存分配
- [x] `exit` / `abort` - 进程退出
- [x] `atoi` / `atol` / `atof` / `atoll` - 字符串转整数
- [x] `strtod` / `strtol` / `strtoul` / `strtoll` / `strtoull` - 进制转换
- [x] `abs` / `labs` / `llabs` - 绝对值
- [x] `div` / `ldiv` / `lldiv` - 除法
- [x] `rand` / `srand` - 随机数
- [x] `qsort` / `bsearch` - 排序与查找
- [x] `getenv` / `setenv` / `unsetenv` / `putenv` - 环境变量
- [x] `stat` / `readlink` - 文件状态
- [x] `opendir` / `readdir` / `closedir` - 目录操作

### 1.6 unistd 模块（已完成）

- [x] `read` / `write` / `close` - 基础 I/O
- [x] `lseek` - 文件指针移动
- [x] `fork` / `execve` / `_exit` - 进程管理
- [x] `getpid` / `getcwd` / `chdir` - 进程目录
- [x] `access` / `unlink` / `mkdir` / `rmdir` - 文件操作
- [x] `dup` / `dup2` - 文件描述符复制

### 1.7 ctype 模块（已完成）

- [x] `isalnum` / `isalpha` / `isdigit` - 字符分类
- [x] `islower` / `isupper` / `isspace` - 字符分类
- [x] `isprint` / `ispunct` / `iscntrl` - 字符分类
- [x] `isxdigit` / `isblank` / `isascii` - 字符分类
- [x] `tolower` / `toupper` / `toascii` - 大小写转换

### 1.8 其他模块（已完成）

- [x] **time**: `time`, `clock`, `strftime`, `localtime`, `gmtime`, `asctime`, `ctime`
- [x] **math**: `sin`, `cos`, `tan`, `asin`, `acos`, `atan2`, `exp`, `log`, `pow`, `sqrt` 及其 float 版本
- [x] **signal**: `signal`, `raise`
- [x] **setjmp**: `setjmp`, `longjmp`
- [x] **stdarg**: `va_start`, `va_arg`, `va_end`
- [x] **wchar**: `mbtowc`, `wctomb`, `wcslen`, `wcscpy`, `wcscmp`, `mbstowcs`, `wcstombs`

### 1.9 pthread 模块（已实现 NPTL-lite 基线）

```
状态：零 libpthread 依赖，基于 Linux SYS_clone + futex + GCC 原子 CAS + 线程描述符 registry
```

- [x] `pthread_create` - 创建线程（descriptor registry；child 入口直接调用 start routine 并退出）
- [x] `pthread_join` - 等待线程结束（当前仍通过 `waitpid`）
- [x] `pthread_exit` - 退出当前线程（保存 retval 到 descriptor）
- [x] `pthread_self` / `pthread_equal` / `pthread_detach`
- [x] `pthread_mutex_init` / `pthread_mutex_destroy`
- [x] `pthread_mutex_lock` / `pthread_mutex_unlock` / `pthread_mutex_trylock` / `pthread_mutex_timedlock`
- [x] `pthread_cond_init` / `pthread_cond_wait` / `pthread_cond_timedwait` / `pthread_cond_signal` / `pthread_cond_broadcast`
- [x] `pthread_once`
- [x] `pthread_key_create` / `pthread_key_delete` / `pthread_getspecific` / `pthread_setspecific`
- [x] `pthread_cancel` / `pthread_testcancel` / `pthread_setcancelstate` / `pthread_setcanceltype`
- [ ] `CLONE_THREAD` / TLS / TCB / futex joinstate 迁移
- [ ] TSD destructor、多轮 cancel 语义、condattr / clock 语义

---

## 二、待实现功能

### 2.1 libc 层待完善

| 模块 | 函数 | 优先级 |
|------|------|--------|
| string | `stpcpy`, `stpncpy`, `memmem`, `memrchr`, `mempcpy` | 低 |
| stdio | `vdprintf`, `asprintf`, `fseek`, `ftell` | 低 |
| pthread | `joinstate`、TLS/TCB、TSD destructor、cancel state/type | 中 |

### 2.2 新架构：syscall 层（待创建）

**职责**：直接封装 Linux 系统调用，无依赖

```
lib/syscall/linux.uya
```

| 函数 | 说明 |
|------|------|
| `sys_read` / `sys_write` | 文件读写 |
| `sys_open` / `sys_close` | 文件开关 |
| `sys_mmap` / `sys_munmap` | 内存映射 |
| `sys_clone` / `sys_execve` / `sys_exit` | 进程管理 |
| `sys_gettid` / `sys_kill` | 线程/信号 |
| `sys_nanosleep` / `sys_gettimeofday` | 时间 |
| `sys_stat` / `sys_lstat` / `sys_fstat` | 文件状态 |
| 其他... | |

### 2.3 新架构：mem 层（待创建）

**职责**：纯内存操作，无系统调用依赖

```
lib/mem/
├── mem.uya      # copy, set, compare
└── string.uya  # strlen, strcmp, strcpy...
```

### 2.4 新架构：osal 层（待创建）

**职责**：操作系统抽象层，统一接口

```
lib/osal/
├── osal.uya      # 核心抽象
├── file.uya      # 文件抽象
├── process.uya   # 进程抽象
├── time.uya      # 时间抽象
└── error.uya    # 错误类型
```

### 2.5 std 层待完善

**当前状态**：

| 模块 | 文件 | 状态 |
|------|------|------|
| std.io | `lib/std/io/file.uya` | 部分实现 |
| std.io | `lib/std/io/stream.uya` | 部分实现 |
| std.mem | `lib/std/mem/mem.uya` | 部分实现（memcpy 等） |
| std.mem | `lib/std/mem/allocator.uya` | **IAllocator + MallocAllocator**；测试 `tests/test_mem_allocator.uya` |
| std.mem | `lib/std/mem/arena.uya` | **Arena : IAllocator**（bump；`realloc` 仅最后块）；测试 `tests/test_mem_arena.uya` |
| std.string | `lib/std/string/string.uya` | 部分实现 |
| std.runtime | `lib/std/runtime/runtime.uya` | 部分实现 |
| std.testing | `lib/std/testing/testing.uya` | 部分实现 |

**待实现**：

- [ ] `Option<T>` 类型
- [ ] `interface Writer` / `Reader`
- [ ] `Vec<T>` / `StringBuf` 容器
- [x] `IAllocator` 接口（**`lib/std/mem/allocator.uya`**，`MallocAllocator` 实现）
- [ ] `HeapAllocator`（mmap，设计见 `std_refactor_design.md`）
- [x] **`Arena` + `IAllocator`**（**`lib/std/mem/arena.uya`**）
- [ ] **`FixedBufferAllocator`**（与 **`Arena`** 命名/能力进一步对齐待办）

---

## 三、实现优先级

### Phase 1: 完善 libc 层

1. 完善 pthread 模块（条件变量、exit retval）
2. 完善 stdio 缺失函数

### Phase 2: syscall 层

1. 创建 `lib/syscall/linux.uya`
2. 封装基本系统调用（read, write, open, close）
3. 封装内存管理（mmap, munmap）
4. 封装进程管理（clone, exec, exit）

### Phase 3: mem 层

1. 创建 `lib/mem/mem.uya`
2. 实现 copy, set, compare
3. 创建 `lib/mem/string.uya`
4. 实现 strlen, strcmp, strcpy...

### Phase 4: osal 层

1. 创建 `lib/osal/osal.uya`
2. 封装 syscall 为统一接口
3. 实现错误转换（!T）
4. 添加跨平台抽象

### Phase 5: std 层

1. 实现核心类型（Option）
2. 实现 I/O 抽象（Writer, Reader）
3. 实现分配器（HeapAllocator）
4. 实现容器（Vec, StringBuf）

---

## 四、设计原则

### 1. 零依赖原则

- **syscall**：无依赖
- **mem**：独立基础层，无依赖
- **osal**：依赖 syscall
- **libc**：依赖 osal + mem
- **std**：依赖 libc + osal

### 2. 依赖单向

```
std → libc → osal → syscall
         ↘
          mem
```

### 3. C 标准兼容

使用 `export extern fn` 保持 C 函数签名

### 4. 错误处理

- syscall：返回原始错误码
- osal：使用 error 定义（!T）
- libc：转换为 C 风格（-1/null）
- std：保持 !T

---

## 五、验证标准

每个阶段完成后需验证：

1. **编译通过**：`make check` 通过
2. **测试覆盖**：新增测试用例全部通过
3. **自举验证**：编译器能使用新标准库编译自身
4. **libc 兼容**：`--outlibc` 生成的库能与 C 代码链接

---

## 六、参考资源

- **musl-libc**: https://musl.libc.org
- **POSIX 标准**: https://pubs.opengroup.org/onlinepubs/9699919799/
- **Linux man pages**: https://man7.org/linux/man-pages/
