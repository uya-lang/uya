# Uya libc 实现完成度评估报告

> **核对头（2026-10-19）**：本报告原为 2026-03-03 的 libc 完整性快照，**各模块的「缺失」清单已按当前源码逐项复核并更新**（方法：对每个函数名执行 `grep -rn "fn <name>(" lib/libc/*.uya`）。原快照里大量标为缺失的函数其实已经实现（`qsort`/`bsearch`/`rand`/`srand`/`div`/`ldiv`/`atoll`/`strtoll`/`strtoull`/`setenv`/`putenv`/`unsetenv`/`vfprintf`/`vprintf`/`fscanf`/`sscanf`/`tmpfile`/`tmpnam`/`setbuf`/`setvbuf`/`fgetpos`/`fsetpos`/`fseek`/`ftell`/`feof`/`ferror`/`clearerr`/`perror`/`remove`/`rename`/`strerror`），下面已改标为 `[x]`。
> 进度以 `lib/libc/`、`lib/std/` 与 `tests/` 实际覆盖为准；总体口径见 `docs/todo_status_index.md`。

**评估日期**: 2026 年 3 月 3 日（原始快照）；**复核日期**: 2026-10-19

**代码总量**: 4,082 行（原始快照；当前 `lib/libc/` 有 16 个文件，`stdio.uya`/`stdlib.uya`/`pthread.uya` 均已显著增长）

**测试覆盖**: 464 个测试全部通过（原始快照；当前 `tests/test_*.uya` 有 894 个文件，通过数以 `make check` 为准）

---

## 总体完成度

> 下表「已实现」列已按 2026-10-19 的实际 `export extern "libc"` 数量校准：`ctype.uya` 16、`string.uya` 18、`mem.uya` 5、`stdio.uya` 50、`stdlib.uya` 32（另有 `heap.uya` 的 malloc/free/realloc）、`unistd.uya` 25。

| 模块 | 已实现 | C 标准库总数 | 完成度 | 状态 |
|------|--------|-------------|--------|------|
| **ctype.h** | 16 | 16 | 100% | ✅ 完成 |
| **string.h** | 19 | 24 | 79% | 🟡 大部分完成（`strerror` 在 `errno.uya` 提供） |
| **memory.h** | 5 | 5 | 100% | ✅ 完成 |
| **stdio.h** | 42+ | 50+ | ~84% | 🟡 大部分完成（50 个 export；缺 `scanf` 家族、`ungetc`/`getc`/`putc`/`fdopen`/`freopen`/`fileno`） |
| **stdlib.h** | 32+ | 40+ | ~80% | 🟡 大部分完成（缺 `mkstemp`、`realpath`） |
| **unistd.h** | 25 | 30+ | ~83% | 🟡 大部分完成（缺 `pipe`/`link`/`symlink`/`chown`/`chmod`/`truncate`/`fsync`/`getuid` 家族/`gethostname`） |
| **errno.h** | 完整 | - | 100% | ✅ 完成 |
| **syscall** | 完整 | - | 100% | ✅ 完成 |
| **总计（仅上表 6 个模块 + errno + syscall）** | 19+16+5+42+32+25 = 139 个具名函数 | ~165+ | ~84% | 🟢 高度完成（另有 `math`/`time`/`signal`/`setjmp`/`stdarg`/`wchar`/`pthread`（71 个 `export extern`）未计入本表，故总体实际远超 165 个符号；表中百分比只描述「C 标准头里的常用函数覆盖率」） |

---

## 各模块详细评估

### 1. ctype.h - 字符分类函数 ✅ 100%

**已实现 (16/16):**
- [x] isalpha - 字母检测
- [x] isdigit - 数字检测
- [x] isalnum - 字母数字检测
- [x] isspace - 空白字符检测
- [x] isupper - 大写字母检测
- [x] islower - 小写字母检测
- [x] isprint - 可打印字符检测
- [x] isgraph - 图形字符检测
- [x] iscntrl - 控制字符检测
- [x] ispunct - 标点符号检测
- [x] isxdigit - 十六进制数字检测
- [x] isblank - 空白字符检测
- [x] isascii - ASCII 字符检测
- [x] toupper - 转大写
- [x] tolower - 转小写
- [x] toascii - 转 ASCII

**评价**: 完整实现 C 标准库所有字符分类函数。

---

### 2. string.h - 字符串操作 🟡 75%

**已实现 (18/24):**
- [x] strlen - 字符串长度
- [x] strcmp - 字符串比较
- [x] strncmp - 前 n 字符比较
- [x] strcasecmp - 忽略大小写比较
- [x] strncasecmp - 忽略大小写前 n 字符比较
- [x] strdup - 字符串复制
- [x] strndup - 字符串复制 (限制长度)
- [x] strcpy - 字符串复制
- [x] strncpy - 字符串复制 (限制长度)
- [x] strcat - 字符串连接
- [x] strncat - 字符串连接 (限制长度)
- [x] strchr - 查找字符 (首次)
- [x] strrchr - 查找字符 (末次)
- [x] strstr - 查找子串
- [x] strcspn - 扫描补集
- [x] strspn - 扫描匹配
- [x] strpbrk - 查找任一字符
- [x] strtok - 字符串分割

**缺失 (5):**（2026-10-19 复核）
- [ ] strcoll - 区域设置字符串比较（`grep -n "fn strcoll(" lib/libc/*.uya` 无命中）
- [ ] strxfrm - 字符串转换（无命中）
- [x] ~~strerror~~ - 错误信息字符串 → **已实现**，位于 `lib/libc/errno.uya`（不在 `string.uya`）
- [ ] memccpy - 带条件内存复制（无命中）
- [ ] strlcat - 安全字符串连接（无命中）
- [ ] strlcpy - 安全字符串复制（无命中）

**评价**: 核心字符串操作函数已完整实现，缺失的主要是区域设置相关和安全版本函数。

---

### 3. memory.h - 内存操作 ✅ 100%

**已实现 (5/5):**
- [x] memcpy - 内存复制
- [x] memset - 内存填充
- [x] memmove - 内存移动 (处理重叠)
- [x] memcmp - 内存比较
- [x] memchr - 查找字符

**评价**: 完整实现 C 标准库所有内存操作函数。

---

### 4. stdio.h - 标准输入输出 🟡 50%

**已实现 (25+):**
- [x] fopen/fclose - 文件打开/关闭
- [x] fread/fwrite - 文件读写
- [x] fgetc/fputc - 字符读写
- [x] fputs - 字符串写入
- [x] fprintf - 格式化输出
- [x] sprintf/snprintf - 格式化到字符串
- [x] fflush - 刷新缓冲区
- [x] put_char/put_char_fd - 字符输出
- [x] write_bytes/write_bytes_fd - 字节写入
- [x] read_bytes/read_bytes_fd - 字节读取
- [x] get_char - 字符读取
- [x] put_str_len - 字符串输出
- [x] i32_to_str/i64_to_str - 数字转字符串
- [x] print_i32/print_i64 - 数字输出
- [x] flush_buffer/write_to_buffer - 缓冲机制
- [x] stdin/stdout/stderr - 标准流
- [x] FILE 结构体

**缺失 (2026-10-19 复核，原清单 9 项中 8 项已落地):**
- [x] ~~fscanf/scanf~~ - `fscanf` **已实现**；`scanf`（stdin 版）仍缺（`grep -n "fn scanf(" lib/libc/*.uya` 无命中）
- [x] ~~sscanf~~ - **已实现**
- [x] ~~vfprintf/vprintf~~ - **已实现**
- [x] ~~remove/rename~~ - **已实现**
- [x] ~~tmpfile/tmpnam~~ - **已实现**
- [x] ~~setbuf/setvbuf~~ - **已实现**
- [x] ~~fgetpos/fsetpos/ftell/fseek~~ - **均已实现**（`stdio.uya:1972` `fseek`、`:1983` `ftell`）
- [x] ~~feof/ferror/clearerr~~ - **均已实现**
- [x] ~~perror~~ - **已实现**
- [ ] 仍未实现：`scanf`、`ungetc`、`getc`、`putc`、`fdopen`、`freopen`、`fileno`

**评价**: 输出功能完善，输入功能较弱。缓冲机制已实现。

---

### 5. stdlib.h - 标准库函数 🟡 42%

**已实现 (17+):**
- [x] malloc - 内存分配 (musl 风格空闲链表)
- [x] free - 内存释放 (含块合并)
- [x] calloc - 分配并清零
- [x] realloc - 重新分配
- [x] exit - 正常退出
- [x] abort - 异常终止
- [x] atoi - 字符串转 int
- [x] atol - 字符串转 long
- [x] atof - 字符串转 double
- [x] strtod - 字符串转 double (带尾指针)
- [x] strtol - 字符串转 long (带进制)
- [x] abs/labs - 绝对值
- [x] strtoul - 字符串转 unsigned long
- [x] system - 执行系统命令
- [x] getenv - 获取环境变量
- [x] stat - 文件状态
- [x] opendir/readdir/closedir - 目录操作
- [x] readlink - 读取符号链接

**缺失 (2026-10-19 复核，原清单 8 项中 6 项已落地):**
- [x] ~~qsort/bsearch~~ - **均已实现**（`stdlib.uya:811` `qsort`、`:818` `bsearch`）
- [x] ~~rand/srand~~ - **均已实现**（`stdlib.uya:507` `rand`）
- [x] ~~div/ldiv~~ - **均已实现**
- [x] ~~atoll/strtoll~~ - **均已实现**（`stdlib.uya:585` `strtoll`）
- [x] ~~strtoull~~ - **已实现**
- [x] ~~putenv/setenv/unsetenv~~ - **均已实现**
- [ ] mkstemp - 临时文件（无命中）
- [ ] realpath - 规范化路径（无命中）
- 另：`malloc`/`free`/`realloc` 已从 `stdlib.uya` 拆到 `lib/libc/heap.uya`

**评价**: 内存分配器已实现 musl 风格空闲链表，数字转换功能完整。

---

### 6. unistd.h - POSIX 标准 🟡 67%

**已实现 (20+):**
- [x] read/write - 读写
- [x] close - 关闭文件描述符
- [x] lseek - 文件定位
- [x] getpid/getppid - 进程 ID
- [x] fork - 创建进程
- [x] execve - 执行程序
- [x] _exit - 立即退出
- [x] waitpid - 等待进程
- [x] access - 检查文件权限
- [x] unlink - 删除文件
- [x] mkdir/rmdir - 目录操作
- [x] chdir - 改变目录
- [x] getcwd - 获取当前目录
- [x] dup/dup2 - 复制文件描述符
- [x] sleep - 睡眠
- [x] system - 系统命令

**缺失 (2026-10-19 复核，全部仍未实现):**
- [ ] pipe - 管道（`grep -n "fn pipe(" lib/libc/*.uya` 无命中）
- [ ] link/symlink - 链接（无命中）
- [x] ~~readlink~~ - 读取链接 → **已实现**，在 `stdlib.uya`（原清单已注明）
- [ ] chown/lchown - 改变所有者（无命中）
- [ ] chmod/fchmod - 改变权限（无命中）
- [ ] truncate/ftruncate - 截断文件（无命中）
- [ ] fsync/fdatasync - 同步文件（无命中）
- [ ] getuid/geteuid/setuid - 用户 ID（无命中）
- [ ] getgid/getegid/setgid - 组 ID（无命中）
- [ ] gethostname/sethostname - 主机名（无命中）

**评价**: 核心 POSIX 功能已实现，缺少部分系统管理功能。

---

### 7. errno.h - 错误码 ✅ 100%

**已实现:**
- [x] errno 全局变量
- [x] EPERM, ENOENT, ESRCH, EINTR 等常见错误码
- [x] EAGAIN, ENOMEM, EACCES 等内存和权限错误
- [x] EFAULT, EBUSY, EEXIST 等系统错误
- [x] ENODEV, ENOTDIR, EISDIR 等设备错误

**评价**: 完整实现常见错误码。

---

### 8. syscall - 系统调用接口 ✅ 100%

**已实现:**
- [x] SYS_read, SYS_write, SYS_open, SYS_close
- [x] SYS_stat, SYS_fstat, SYS_lstat
- [x] SYS_lseek, SYS_mmap, SYS_munmap
- [x] SYS_mprotect, SYS_brk
- [x] SYS_fork, SYS_execve, SYS_exit
- [x] SYS_wait4, SYS_kill, SYS_getpid
- [x] SYS_dup, SYS_dup2, SYS_pipe
- [x] SYS_getuid, SYS_getgid, SYS_setuid
- [x] SYS_access, SYS_chdir, SYS_getcwd
- [x] SYS_mkdir, SYS_rmdir, SYS_unlink
- [x] SYS_readlink, SYS_chmod, SYS_chown
- [x] SYS_getdents64, SYS_clock_gettime
- [x] SYS_setrlimit 等

**评价**: 完整实现 x86-64 Linux 系统调用号和封装。

---

## 实现亮点

### 1. musl 风格内存分配器 ⭐⭐⭐（当前实现位于 `lib/libc/heap.uya`，`CHUNK_MAGIC = 0xDEADBEEF` 见 `heap.uya:37`）
- 空闲链表管理
- 首次适配算法
- 块分割策略
- 魔数验证 (`heap.uya:37` `CHUNK_MAGIC: u64 = 3735928559` = `0xDEADBEEF`)
- 原地优化 (realloc 缩小)

### 2. 标准 I/O 缓冲机制 ⭐⭐⭐
- 4096 字节缓冲区（`lib/libc/stdio.uya:1337` `var local_buf: [byte: 4096]`）
- 行缓冲/全缓冲/无缓冲三种模式
- stdout 默认行缓冲
- stderr 默认无缓冲

### 3. 类型安全设计 ⭐⭐
- 使用魔数验证块有效性
- 指针类型严格检查
- 错误码机制

---

## 优先级建议

### 高优先级 (核心功能增强) — 2026-10-19 复核后的实际剩余
1. **`scanf`（stdin 版）** — `fscanf`/`sscanf` 已有，只差 stdin 版本；顺带补 `ungetc`/`getc`/`putc`/`fdopen`/`freopen`/`fileno`
2. **`qsort`/`bsearch`** — ✅ 已实现，已从待办移除
3. **`vfprintf`/`vprintf`** — ✅ 已实现，已从待办移除

### 中优先级 (功能完善)
4. **`rand`/`srand`** — ✅ 已实现，已从待办移除
5. **文件定位函数** — ✅ `fseek`/`ftell`/`fgetpos`/`fsetpos` 均已实现，已从待办移除
6. **环境变量操作** — ✅ `setenv`/`putenv`/`unsetenv` 均已实现，已从待办移除

### 低优先级 (扩展功能)
7. **管道支持** - `pipe`（仍未实现）
8. **更多 POSIX 函数** - `getuid`/`getgid`/`chown`/`chmod`/`truncate`/`fsync`/`link`/`symlink`/`gethostname`（仍未实现）
9. **区域设置支持** - `strcoll`/`strxfrm`（仍未实现）
10. **其他** - `mkstemp`、`realpath`、`memccpy`、`strlcpy`/`strlcat`（仍未实现）

---

## 总结

**整体评价**: Uya libc 已实现 C 标准库的核心功能，完成度约 **73%**（2026-03 原始快照的结论）；2026-10-19 复核后按上表口径约为 **84%**（`stdio` 50 个 export、`stdlib` 32、`unistd` 25、`string` 18 + `errno.strerror`），剩余缺口集中在 `scanf` 家族、`pipe`/`chmod`/`chown`/`truncate`/`fsync` 等 POSIX 文件系统函数与 `strcoll`/`strxfrm`/`mkstemp`/`realpath`。

**优势**:
- ✅ 字符分类和内存操作 100% 完成
- ✅ 字符串操作核心函数完整
- ✅ musl 风格内存分配器
- ✅ 标准 I/O 缓冲机制
- ✅ 完整的系统调用接口

**待完善**（2026-10-19 复核后）:
- ⏳ 格式化输入只剩 stdin 版 `scanf` 与 `ungetc`/`getc`/`putc` 等字符 I/O
- ✅ 排序和搜索函数（`qsort`/`bsearch`）已实现
- ✅ 可变参数格式化输出（`vfprintf`/`vprintf`）已实现
- ⏳ POSIX 文件系统类补充：`pipe`/`chmod`/`chown`/`truncate`/`fsync`/`link`/`symlink`

**适用场景**:
- ✅ 系统编程
- ✅ 文件操作
- ✅ 字符串处理
- ✅ 内存管理
- ⏳ 复杂格式化输入 (待完善)
