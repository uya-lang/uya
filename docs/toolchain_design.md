# Uya 工具链模块化架构设计文档

## 1. 概述

Uya 工具链采用**子命令独立程序**架构，每个子命令是一个独立的小程序，`uya` 作为主入口进行转发。

```
┌──────────────────────────────────────────────────────┐
│                       uya                            │
│                    (主入口)                          │
├──────────────────────────────────────────────────────┤
│  uya build  ──────▶ uya-build  (编译器)             │
│  uya check  ──────▶ uya-check  (前端检查器)         │
│  uya run    ──────▶ uya-run    (编译并运行)         │
│  uya test   ──────▶ uya-test   (测试运行器)         │
│  uya fmt    ──────▶ uya-fmt    (格式化器)           │
│  uya lint   ──────▶ uya-lint   (静态分析)           │
│  uya doc    ──────▶ uya-doc    (文档生成)           │
└──────────────────────────────────────────────────────┘
```

这种架构的优势：
- ✅ **模块化**：每个工具独立开发、测试、发布
- ✅ **可替换**：用户可以用自定义工具替换默认工具
- ✅ **轻量**：只需安装需要的工具
- ✅ **并行编译**：多个工具可同时构建
- ✅ **类似 Git/Rust**：用户熟悉的命令模式

---

## 2. 架构总览

### 2.1 目录结构

```
uya-asm/
├── src/
│   ├── main.uya           # uya 主入口（转发器）
│   ├── tools/             # 独立工具目录
│   │   ├── build.uya      # uya-build 入口
│   │   ├── check.uya      # uya-check 入口
│   │   ├── run.uya        # uya-run 入口
│   │   ├── test.uya       # uya-test 入口
│   │   ├── fmt.uya        # uya-fmt 入口
│   │   ├── lint.uya       # uya-lint 入口（未来）
│   │   └── doc.uya        # uya-doc 入口（未来）
│   ├── fmt/               # 格式化器模块
│   │   ├── formatter.uya
│   │   └── config.uya
│   ├── checker/           # 类型检查器（共享）
│   ├── parser/            # 解析器（共享）
│   ├── lexer.uya          # 词法分析（共享）
│   └── ast.uya            # AST 定义（共享）
├── lib/                   # 标准库
│   ├── std/
│   └── libc/
├── bin/                   # 编译输出
│   ├── uya                # 主入口
│   ├── uya-build
│   ├── uya-check
│   ├── uya-run
│   ├── uya-test
│   └── uya-fmt
└── Makefile
```

### 2.2 工具职责划分

| 工具 | 职责 | 入口文件 | 依赖模块 |
|------|------|----------|----------|
| `uya` | 子命令转发 | `main.uya` | 无 |
| `uya-build` | 编译为可执行文件 | `tools/build.uya` | lexer, parser, checker, codegen |
| `uya-check` | 只执行到 checker | `tools/check.uya` | lexer, parser, checker |
| `uya-run` | 编译并运行 | `tools/run.uya` | build (调用) |
| `uya-test` | 运行测试 | `tools/test.uya` | build (调用) |
| `uya-fmt` | 代码格式化 | `tools/fmt.uya` | lexer, parser, formatter |

### 2.3 依赖关系图

```
                    ┌─────────┐
                    │   uya   │ (转发器)
                    └────┬────┘
                         │ exec()
         ┌───────┬───────┼───────┬───────┐
         ▼       ▼       ▼       ▼       ▼
    ┌────────┐┌────────┐┌────────┐┌────────┐
    │uya-build││uya-run ││uya-test││uya-fmt │
    └───┬────┘└───┬────┘└───┬────┘└───┬────┘
        │         │         │         │
        │         │         │         │
        ▼         │         │         ▼
┌───────────────┐ │         │  ┌───────────────┐
│ 共享编译核心   │ │         │  │ 共享解析核心   │
│ • lexer       │ │         │  │ • lexer       │
│ • parser      │ │         │  │ • parser      │
│ • checker     │ │         │  │ • formatter   │
│ • codegen     │ │         │  └───────────────┘
└───────────────┘ │         │
        ▲         │         │
        │         ▼         ▼
        │    调用 uya-build 调用 uya-build
        │    然后 exec()    然后 exec()
```

---

## 3. 主入口设计（uya）

### 3.1 main.uya - 极简转发器

```uya
// main.uya - uya 主入口（转发器）
// 职责：解析子命令，转发到对应工具

use libc;
use libc.stdio;
use libc.stdlib;
use libc.string;
use libc.unistd;  // execv

const PATH_MAX: usize = 4096;

// 子命令映射
const TOOL_COUNT: i32 = 5;
const TOOL_NAMES: [&byte: 5] = [
    "build" as *byte,
    "run" as *byte,
    "test" as *byte,
    "fmt" as *byte,
    "lint" as *byte
];

const TOOL_BINS: [&byte: 5] = [
    "uya-build" as *byte,
    "uya-run" as *byte,
    "uya-test" as *byte,
    "uya-fmt" as *byte,
    "uya-lint" as *byte
];

// 打印使用说明
fn print_usage(program_name: &byte) void {
    fprintf(libc.stderr, "Uya - 零GC系统编程语言工具链\n" as *byte);
    fprintf(libc.stderr, "\n用法:\n" as *byte);
    fprintf(libc.stderr, "  %s <命令> [选项] [文件]\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "\n命令:\n" as *byte);
    fprintf(libc.stderr, "  build    编译为可执行文件\n" as *byte);
    fprintf(libc.stderr, "  run      编译并运行\n" as *byte);
    fprintf(libc.stderr, "  test     运行测试\n" as *byte);
    fprintf(libc.stderr, "  fmt      格式化代码\n" as *byte);
    fprintf(libc.stderr, "  lint     静态分析（开发中）\n" as *byte);
    fprintf(libc.stderr, "\n运行 '%s <命令> --help' 获取更多信息\n" as *byte, program_name as *byte);
}

// 查找工具可执行文件
fn find_tool_binary(tool_name: &byte, buffer: &byte, buffer_size: usize) i32 {
    // 方式1：从编译器所在目录查找
    const argv0: *byte = get_argv(0);
    if argv0 != null {
        // 提取目录
        const last_slash: *byte = strrchr(argv0, 47);  // '/'
        if last_slash != null {
            const dir_len: usize = ptr_diff(last_slash, argv0 as &byte) + 1;
            if dir_len + strlen(tool_name as *byte) + 1 < buffer_size {
                memcpy(buffer as *void, argv0 as *void, dir_len);
                strcpy(buffer + dir_len, tool_name as *byte);
                
                // 检查文件是否存在且可执行
                if access(buffer as *byte, 1) == 0 {  // X_OK = 1
                    return 0;
                }
            }
        }
    }
    
    // 方式2：从 PATH 环境变量查找
    const path_env: *byte = getenv("PATH" as *byte);
    if path_env != null {
        // 解析 PATH，逐个目录查找
        var path_copy: [byte: 4096] = [];
        strcpy(&path_copy[0], path_env);
        
        var start: &byte = &path_copy[0];
        while start[0] != 0 {
            // 找到下一个冒号或结尾
            var end: &byte = start;
            while end[0] != 0 && end[0] != 58 {  // ':'
                end = end + 1;
            }
            
            // 提取目录
            const dir_len: usize = ptr_diff(end, start);
            if dir_len + strlen(tool_name as *byte) + 2 < buffer_size {
                memcpy(buffer as *void, start as *void, dir_len);
                buffer[dir_len] = 47 as byte;  // '/'
                strcpy(buffer + dir_len + 1, tool_name as *byte);
                
                if access(buffer as *byte, 1) == 0 {
                    return 0;
                }
            }
            
            // 移动到下一个目录
            if end[0] == 58 {
                start = end + 1;
            } else {
                break;
            }
        }
    }
    
    return -1;  // 未找到
}

// 主函数
export fn main() i32 {
    const argc: i32 = get_argc();
    
    if argc < 2 {
        var name: &byte = "uya" as *byte;
        const argv0: *byte = get_argv(0);
        if argv0 != null {
            name = argv0 as &byte;
        }
        print_usage(name);
        return 1;
    }
    
    const first_arg: *byte = get_argv(1);
    if first_arg == null {
        fprintf(libc.stderr, "错误: 无法获取命令参数\n" as *byte);
        return 1;
    }
    
    // 检查是否是帮助请求
    if strcmp(first_arg, "-h" as *byte) == 0 || 
       strcmp(first_arg, "--help" as *byte) == 0 ||
       strcmp(first_arg, "help" as *byte) == 0 {
        var name: &byte = "uya" as *byte;
        const argv0: *byte = get_argv(0);
        if argv0 != null {
            name = argv0 as &byte;
        }
        print_usage(name);
        return 0;
    }
    
    // 检查是否是版本请求
    if strcmp(first_arg, "-v" as *byte) == 0 ||
       strcmp(first_arg, "--version" as *byte) == 0 ||
       strcmp(first_arg, "version" as *byte) == 0 {
        fprintf(libc.stderr, "Uya v0.9.2\n" as *byte);
        return 0;
    }
    
    // 查找对应的工具
    var tool_bin: &byte = null;
    var i: i32 = 0;
    while i < TOOL_COUNT {
        if strcmp(first_arg, TOOL_NAMES[i]) == 0 {
            tool_bin = TOOL_BINS[i];
            break;
        }
        i = i + 1;
    }
    
    if tool_bin == null {
        fprintf(libc.stderr, "错误: 未知命令 '%s'\n" as *byte, first_arg);
        fprintf(libc.stderr, "运行 'uya --help' 查看可用命令\n" as *byte);
        return 1;
    }
    
    // 查找工具可执行文件
    var tool_path: [byte: PATH_MAX] = [];
    if find_tool_binary(tool_bin, &tool_path[0] as &byte, PATH_MAX) != 0 {
        fprintf(libc.stderr, "错误: 未找到工具 '%s'\n" as *byte, tool_bin as *byte);
        fprintf(libc.stderr, "请确保 uya 工具链已正确安装\n" as *byte);
        return 1;
    }
    
    // 构建参数数组（跳过第一个参数，保留子命令名）
    // argv[0] = tool_path, argv[1..] = 原始参数[2..]
    var argv_array: [&byte: 128] = [];
    argv_array[0] = &tool_path[0];
    
    var arg_count: i32 = 1;
    i = 2;  // 从第3个参数开始
    while i < argc && arg_count < 127 {
        const arg: *byte = get_argv(i);
        if arg != null {
            argv_array[arg_count] = arg;
            arg_count = arg_count + 1;
        }
        i = i + 1;
    }
    argv_array[arg_count] = null;
    
    // 执行工具
    execv(&tool_path[0], &argv_array[0]);
    
    // 如果 execv 返回，说明执行失败
    fprintf(libc.stderr, "错误: 无法执行 '%s'\n" as *byte, &tool_path[0] as *byte);
    return 1;
}
```

---

## 4. 独立工具设计

### 4.1 uya-build - 编译器

`src/tools/build.uya`：

```uya
// build.uya - uya-build 入口
// 职责：编译 Uya 代码为可执行文件

use main;  // 收集同目录模块
use parser;
use checker;
use codegen.c99;
use std.runtime.entry;
use libc;
use libc.stdlib;
use libc.syscall;

// 编译统计结构体
struct CompileStats {
    parse_time_ms: i64,
    check_time_ms: i64,
    codegen_time_ms: i64,
    total_time_ms: i64,
    file_count: i32,
}

// 打印使用说明
fn print_usage(program_name: &byte) void {
    fprintf(libc.stderr, "Uya 编译器 - 编译为可执行文件\n" as *byte);
    fprintf(libc.stderr, "\n用法:\n" as *byte);
    fprintf(libc.stderr, "  %s <文件> [-o <输出>] [选项]\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "\n选项:\n" as *byte);
    fprintf(libc.stderr, "  -o <文件>            指定输出文件名\n" as *byte);
    fprintf(libc.stderr, "  --c99                生成 C99 代码\n" as *byte);
    fprintf(libc.stderr, "  --opt=<0-3>          优化级别\n" as *byte);
    fprintf(libc.stderr, "  -O0, -O1, -O2, -O3   优化级别（简写）\n" as *byte);
    fprintf(libc.stderr, "  --safety-proof       启用内存安全证明\n" as *byte);
    fprintf(libc.stderr, "  --nostdlib           无标准库模式\n" as *byte);
    fprintf(libc.stderr, "  -h, --help           显示帮助\n" as *byte);
}

// 主函数
export fn main() i32 {
    const argc: i32 = get_argc();
    if argc < 2 {
        print_usage("uya-build" as *byte);
        return 1;
    }
    
    // 检查帮助
    const first_arg: *byte = get_argv(1);
    if first_arg != null && 
       (strcmp(first_arg, "-h" as *byte) == 0 || 
        strcmp(first_arg, "--help" as *byte) == 0) {
        print_usage("uya-build" as *byte);
        return 0;
    }
    
    // 调用编译核心（复用现有 compile_files 函数）
    // ... 编译逻辑 ...
    
    fprintf(libc.stderr, "编译完成\n" as *byte);
    return 0;
}
```

### 4.2 uya-run - 编译并运行

`src/tools/run.uya`：

```uya
// run.uya - uya-run 入口
// 职责：编译代码并运行

use libc;
use libc.stdio;
use libc.stdlib;

fn print_usage(program_name: &byte) void {
    fprintf(libc.stderr, "Uya 运行器 - 编译并运行\n" as *byte);
    fprintf(libc.stderr, "\n用法:\n" as *byte);
    fprintf(libc.stderr, "  %s <文件> [编译选项] [-- <运行参数>]\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "\n选项:\n" as *byte);
    fprintf(libc.stderr, "  -- <参数>  传递给程序的参数\n" as *byte);
}

export fn main() i32 {
    // 1. 解析参数，找到 -- 分隔符
    // 2. 调用 uya-build 编译
    // 3. 执行生成的可执行文件
    
    var build_cmd: [byte: 4096] = [];
    // ... 构建命令 ...
    
    // 编译
    const build_result: i32 = system(&build_cmd[0]);
    if build_result != 0 {
        return build_result;
    }
    
    // 运行
    const run_result: i32 = system("/tmp/uya_out");
    return run_result;
}
```

### 4.3 uya-test - 测试运行器

`src/tools/test.uya`：

```uya
// test.uya - uya-test 入口
// 职责：运行测试用例

use libc;
use libc.stdio;

// 测试结果
struct TestResult {
    passed: i32,
    failed: i32,
    skipped: i32,
}

fn print_usage(program_name: &byte) void {
    fprintf(libc.stderr, "Uya 测试运行器\n" as *byte);
    fprintf(libc.stderr, "\n用法:\n" as *byte);
    fprintf(libc.stderr, "  %s <文件或目录> [选项]\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "\n选项:\n" as *byte);
    fprintf(libc.stderr, "  --verbose      详细输出\n" as *byte);
    fprintf(libc.stderr, "  --filter <模式> 过滤测试\n" as *byte);
}

export fn main() i32 {
    // 1. 查找测试文件
    // 2. 编译测试
    // 3. 运行并收集结果
    
    fprintf(libc.stderr, "运行测试...\n" as *byte);
    
    // ... 测试逻辑 ...
    
    return 0;
}
```

### 4.4 uya-fmt - 格式化器

`src/tools/fmt.uya`：

```uya
// fmt.uya - uya-fmt 入口
// 职责：格式化 Uya 代码（支持文件和目录）

use fmt.formatter;
use libc;
use libc.stdio;
use libc.dirent;

const PATH_MAX: usize = 4096;
const MAX_FILES: i32 = 1024;

// 格式化模式
enum FmtMode {
    FMT_MODE_WRITE,    // 覆盖原文件
    FMT_MODE_CHECK,    // 检查模式
    FMT_MODE_DIFF,     // 显示差异
}

// 格式化统计
struct FmtStats {
    total: i32,        // 总文件数
    formatted: i32,    // 已格式化
    changed: i32,      // 有变化
    errors: i32,       // 错误数
}

// 格式化结果
struct FormatResult {
    success: i32,          // 是否成功（0 = 失败，1 = 成功）
    output_len: usize,     // 输出长度
    error_message: &byte,  // 错误消息（失败时）
}

// Arena 分配器（用于持久化路径）
struct Arena {
    data: &byte,
    size: usize,
    used: usize,
}

fn arena_alloc(arena: &Arena, size: usize) &byte {
    if arena.used + size > arena.size {
        return null;
    }
    const ptr: &byte = arena.data + arena.used;
    arena.used = arena.used + size;
    return ptr;
}

// 打印使用说明
fn print_usage(program_name: &byte) void {
    fprintf(libc.stderr, "Uya 代码格式化工具\n" as *byte);
    fprintf(libc.stderr, "\n用法:\n" as *byte);
    fprintf(libc.stderr, "  %s <文件>           格式化单个文件\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "  %s <目录>           格式化目录下所有 .uya 文件\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "  %s -r <目录>        递归格式化目录\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "\n选项:\n" as *byte);
    fprintf(libc.stderr, "  -r, --recursive     递归处理子目录\n" as *byte);
    fprintf(libc.stderr, "  -c, --check         检查模式（不修改文件）\n" as *byte);
    fprintf(libc.stderr, "  -d, --diff          显示差异\n" as *byte);
    fprintf(libc.stderr, "  -o, --output <文件> 输出到指定文件\n" as *byte);
    fprintf(libc.stderr, "  -e, --exclude <模式> 排除文件模式\n" as *byte);
    fprintf(libc.stderr, "  -h, --help          显示帮助\n" as *byte);
    fprintf(libc.stderr, "\n示例:\n" as *byte);
    fprintf(libc.stderr, "  %s src/main.uya              # 格式化单个文件\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "  %s src/                      # 格式化 src 目录\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "  %s -r .                      # 递归格式化当前目录\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "  %s --check src/ tests/       # CI 检查\n" as *byte, program_name as *byte);
    fprintf(libc.stderr, "  %s -e 'vendor/*' src/        # 排除 vendor 目录\n" as *byte, program_name as *byte);
}

// 检查路径是否为目录
fn is_directory(path: &byte) i32 {
    var st: Stat = Stat { st_dev: 0, st_ino: 0, st_nlink: 0, st_mode: 0, st_uid: 0, st_gid: 0, _pad0: 0, st_rdev: 0, st_size: 0, st_blksize: 0, st_blocks: 0, st_atime: 0, st_atime_nsec: 0, st_mtime: 0, st_mtime_nsec: 0, st_ctime: 0, st_ctime_nsec: 0, _unused0: 0, _unused1: 0, _unused2: 0 };
    if stat(path as *byte, &st) == 0 {
        if ((st.st_mode as u32) & S_IFMT) == S_IFDIR {
            return 1;
        }
    }
    return 0;
}

// 检查路径是否为 .uya 文件
fn is_uya_file(path: &byte) i32 {
    const len: usize = strlen(path as *byte);
    if len > 4 {
        const ext: &byte = path + (len - 4);
        if strcmp(ext as *byte, ".uya" as *byte) == 0 {
            return 1;
        }
    }
    return 0;
}

// 检查路径是否应该排除
fn should_exclude(path: &byte, exclude_patterns: &&byte, exclude_count: i32) i32 {
    var i: i32 = 0;
    while i < exclude_count {
        // TODO: 实现 glob 模式匹配
        // 简单实现：前缀匹配
        const pattern: &byte = exclude_patterns[i];
        if pattern != null {
            const plen: usize = strlen(pattern as *byte);
            if strncmp(path as *byte, pattern as *byte, plen) == 0 {
                return 1;
            }
        }
        i = i + 1;
    }
    return 0;
}

// 收集目录下的 .uya 文件
fn collect_uya_files(
    dir_path: &byte,
    files: &&byte,
    max_files: i32,
    file_count: &i32,
    recursive: i32,
    exclude_patterns: &&byte,
    exclude_count: i32,
    arena: &Arena
) i32 {
    const dir: *DIR = opendir(dir_path as *byte);
    if dir == null {
        return -1;
    }
    
    var entry: *Dirent = readdir(dir);
    while entry != null && file_count[0] < max_files {
        const name: *byte = dirent_get_name(entry as &byte) as *byte;
        const name_len: usize = strlen(name);
        
        // 跳过 . 和 ..
        if strcmp(name, "." as *byte) == 0 || strcmp(name, ".." as *byte) == 0 {
            entry = readdir(dir);
            continue;
        }
        
        // 构建完整路径
        var full_path: [byte: PATH_MAX] = [];
        snprintf(&full_path[0], PATH_MAX, "%s/%s" as *byte, dir_path as *byte, name);
        
        // 检查排除
        if should_exclude(&full_path[0] as &byte, exclude_patterns, exclude_count) != 0 {
            entry = readdir(dir);
            continue;
        }
        
        if is_directory(&full_path[0] as &byte) != 0 {
            // 递归处理子目录
            if recursive != 0 {
                collect_uya_files(
                    &full_path[0] as &byte,
                    files,
                    max_files,
                    file_count,
                    recursive,
                    exclude_patterns,
                    exclude_count,
                    arena
                );
            }
        } else if is_uya_file(&full_path[0] as &byte) != 0 {
            // 添加 .uya 文件
            // 使用 arena 分配持久化路径（避免局部变量覆盖）
            const path_copy: &byte = arena_alloc(arena, PATH_MAX) as &byte;
            if path_copy != null {
                strcpy(path_copy as *byte, &full_path[0]);
                files[file_count[0]] = path_copy;
                file_count[0] = file_count[0] + 1;
            }
        }
        
        entry = readdir(dir);
    }
    
    closedir(dir);
    return 0;
}

// 格式化单个文件
fn format_single_file(
    filepath: &byte,
    mode: FmtMode,
    output_file: &byte,
    stats: &FmtStats
) i32 {
    stats.total = stats.total + 1;
    
    // 读取文件
    var buffer: [byte: 1024 * 1024] = [];
    const file: *void = fopen(filepath as *byte, "rb" as *byte);
    if file == null {
        fprintf(libc.stderr, "错误: 无法读取 '%s'\n" as *byte, filepath as *byte);
        stats.errors = stats.errors + 1;
        return -1;
    }
    
    const bytes_read: usize = fread(&buffer[0], 1, 1024 * 1024 - 1, file);
    buffer[bytes_read] = 0 as byte;
    fclose(file);
    
    // 格式化
    var output: [byte: 1024 * 1024] = [];
    const result: FormatResult = format_code(
        &buffer[0],
        bytes_read,
        &output[0],
        1024 * 1024
    );
    
    if result.success == 0 {
        fprintf(libc.stderr, "错误: 格式化失败 '%s': %s\n" as *byte, 
                filepath as *byte, result.error_message as *byte);
        stats.errors = stats.errors + 1;
        return -1;
    }
    
    // 根据模式处理
    if mode == FmtMode.FMT_MODE_CHECK {
        // 检查模式：比较是否相同
        if bytes_read == result.output_len && 
           memcmp(&buffer[0], &output[0], bytes_read) == 0 {
            fprintf(libc.stderr, "✓ %s\n" as *byte, filepath as *byte);
            stats.formatted = stats.formatted + 1;
        } else {
            fprintf(libc.stderr, "✗ %s (需要格式化)\n" as *byte, filepath as *byte);
            stats.changed = stats.changed + 1;
        }
    } else if mode == FmtMode.FMT_MODE_DIFF {
        // 差异模式
        fprintf(libc.stderr, "=== %s ===\n" as *byte, filepath as *byte);
        // TODO: 实现差异输出
    } else {
        // 写入模式
        var changed: i32 = 0;
        if bytes_read != result.output_len ||
           memcmp(&buffer[0], &output[0], bytes_read) != 0 {
            changed = 1;
        }
        
        if changed != 0 || output_file != null {
            var out_path: &byte = filepath;
            if output_file != null {
                out_path = output_file;
            }
            const out_file: *void = fopen(out_path as *byte, "wb" as *byte);
            if out_file == null {
                fprintf(libc.stderr, "错误: 无法写入 '%s'\n" as *byte, out_path as *byte);
                stats.errors = stats.errors + 1;
                return -1;
            }
            fwrite(&output[0], 1, result.output_len, out_file);
            fclose(out_file);
            
            if changed != 0 {
                stats.changed = stats.changed + 1;
                fprintf(libc.stderr, "已格式化: %s\n" as *byte, filepath as *byte);
            } else {
                stats.formatted = stats.formatted + 1;
            }
        } else {
            stats.formatted = stats.formatted + 1;
        }
    }
    
    return 0;
}

// 主函数
export fn main() i32 {
    const argc: i32 = get_argc();
    
    if argc < 2 {
        print_usage("uya-fmt" as *byte);
        return 1;
    }
    
    // 解析参数
    var mode: FmtMode = FmtMode.FMT_MODE_WRITE;
    var recursive: i32 = 0;
    var output_file: &byte = null;
    var exclude_patterns: [&byte: 16] = [];
    var exclude_count: i32 = 0;
    var input_paths: [&byte: 64] = [];
    var input_count: i32 = 0;
    
    var i: i32 = 1;
    while i < argc {
        const arg: *byte = get_argv(i);
        if arg == null { break; }
        
        if strcmp(arg, "-h" as *byte) == 0 || strcmp(arg, "--help" as *byte) == 0 {
            print_usage("uya-fmt" as *byte);
            return 0;
        } else if strcmp(arg, "-r" as *byte) == 0 || strcmp(arg, "--recursive" as *byte) == 0 {
            recursive = 1;
        } else if strcmp(arg, "-c" as *byte) == 0 || strcmp(arg, "--check" as *byte) == 0 {
            mode = FmtMode.FMT_MODE_CHECK;
        } else if strcmp(arg, "-d" as *byte) == 0 || strcmp(arg, "--diff" as *byte) == 0 {
            mode = FmtMode.FMT_MODE_DIFF;
        } else if strcmp(arg, "-o" as *byte) == 0 || strcmp(arg, "--output" as *byte) == 0 {
            if i + 1 < argc {
                output_file = get_argv(i + 1);
                i = i + 1;
            }
        } else if strcmp(arg, "-e" as *byte) == 0 || strcmp(arg, "--exclude" as *byte) == 0 {
            if i + 1 < argc && exclude_count < 16 {
                exclude_patterns[exclude_count] = get_argv(i + 1);
                exclude_count = exclude_count + 1;
                i = i + 1;
            }
        } else if arg[0] != 45 {  // 不是 '-' 开头
            input_paths[input_count] = arg;
            input_count = input_count + 1;
        }
        i = i + 1;
    }
    
    if input_count == 0 {
        fprintf(libc.stderr, "错误: 未指定输入文件或目录\n" as *byte);
        return 1;
    }
    
    // 统计
    var stats: FmtStats = FmtStats { total: 0, formatted: 0, changed: 0, errors: 0 };
    
    // 初始化 arena（用于存储文件路径）
    var arena_data: [byte: 1024 * 1024] = [];  // 1MB
    var arena: Arena = Arena {
        data: &arena_data[0],
        size: 1024 * 1024,
        used: 0
    };
    
    // 处理输入路径
    i = 0;
    while i < input_count {
        const path: &byte = input_paths[i];
        
        if is_directory(path as &byte) != 0 {
            // 目录：收集所有 .uya 文件
            var files: [&byte: MAX_FILES] = [];
            var file_count: i32 = 0;
            
            collect_uya_files(
                path as &byte,
                &files[0],
                MAX_FILES,
                &file_count,
                recursive,
                &exclude_patterns[0] as &&byte,
                exclude_count,
                &arena
            );
            
            // 格式化每个文件
            var j: i32 = 0;
            while j < file_count {
                format_single_file(files[j], mode, null, &stats);
                j = j + 1;
            }
        } else {
            // 单个文件
            format_single_file(path as &byte, mode, output_file, &stats);
        }
        i = i + 1;
    }
    
    // 输出统计
    fprintf(libc.stderr, "\n=== 格式化统计 ===\n" as *byte);
    fprintf(libc.stderr, "总文件数: %d\n" as *byte, stats.total);
    fprintf(libc.stderr, "已格式化: %d\n" as *byte, stats.formatted);
    fprintf(libc.stderr, "有变化: %d\n" as *byte, stats.changed);
    fprintf(libc.stderr, "错误: %d\n" as *byte, stats.errors);
    
    // 检查模式返回码
    if mode == FmtMode.FMT_MODE_CHECK {
        if stats.changed > 0 { return 1; }
        return 0;
    }
    
    if stats.errors > 0 { return 1; }
    return 0;
}
```

#### 目录处理流程

```
┌─────────────────────────────────────────────────────┐
│              uya-fmt src/ -r --check                │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  1. 解析参数                                        │
│     • mode = CHECK                                  │
│     • recursive = true                              │
│     • path = "src/"                                 │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  2. 收集文件 (collect_uya_files)                   │
│     • 遍历目录                                      │
│     • 过滤 .uya 文件                                │
│     • 排除 exclude 模式                             │
│     • 递归处理子目录                                │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  3. 格式化每个文件                                  │
│     for file in files:                              │
│       • 读取文件内容                                │
│       • 解析为 AST                                  │
│       • 格式化输出                                  │
│       • 比较/写入                                   │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  4. 输出统计                                        │
│     总文件数: 42                                    │
│     已格式化: 40                                    │
│     有变化: 2                                       │
│     返回码: 1 (check 模式下有变化则返回 1)          │
└─────────────────────────────────────────────────────┘
```

### 4.5 格式化器核心实现

`src/fmt/formatter.uya`：

```uya
// formatter.uya - 格式化器核心实现
// 职责：将源代码解析为 AST，然后按规则输出格式化代码

use lexer;
use parser;
use ast;
use libc;
use libc.stdio;

// 格式化配置
struct FormatConfig {
    indent_size: i32,       // 缩进空格数（默认 4）
    max_line_width: i32,    // 最大行宽（默认 100）
    use_tabs: i32,          // 使用 Tab 缩进（默认 false）
    trailing_newline: i32,  // 文件末尾空行（默认 true）
    semicolons: i32,        // 保留分号（默认 true）
}

// 格式化上下文
struct FormatContext {
    config: FormatConfig,
    output: &byte,          // 输出缓冲区
    output_size: usize,     // 输出缓冲区大小
    output_pos: usize,      // 当前写入位置
    indent_level: i32,      // 当前缩进级别
    line_start: i32,        // 是否在行首
    line_length: i32,       // 当前行长度
}

// 默认配置
fn default_config() FormatConfig {
    return FormatConfig {
        indent_size: 4,
        max_line_width: 100,
        use_tabs: 0,
        trailing_newline: 1,
        semicolons: 1
    };
}

// 写入字符
fn write_char(ctx: &FormatContext, c: byte) void {
    if ctx.output_pos < ctx.output_size {
        ctx.output[ctx.output_pos] = c;
        ctx.output_pos = ctx.output_pos + 1;
    }
    ctx.line_length = ctx.line_length + 1;
    ctx.line_start = 0;
}

// 写入字符串
fn write_str(ctx: &FormatContext, s: &byte) void {
    var i: usize = 0;
    while s[i] != 0 {
        write_char(ctx, s[i]);
        i = i + 1;
    }
}

// 写入换行
fn write_newline(ctx: &FormatContext) void {
    write_char(ctx, 10);  // '\n'
    ctx.line_length = 0;
    ctx.line_start = 1;
}

// 写入缩进
fn write_indent(ctx: &FormatContext) void {
    var i: i32 = 0;
    while i < ctx.indent_level {
        var j: i32 = 0;
        while j < ctx.config.indent_size {
            write_char(ctx, 32);  // ' '
            j = j + 1;
        }
        i = i + 1;
    }
}

// 格式化表达式
fn format_expr(ctx: &FormatContext, expr: &ASTNode) void {
    if expr == null { return; }
    
    if expr.type == ASTNodeType.AST_LITERAL {
        // 字面量：直接输出
        write_str(ctx, expr.value);
    } else if expr.type == ASTNodeType.AST_IDENTIFIER {
        // 标识符：直接输出
        write_str(ctx, expr.name);
    } else if expr.type == ASTNodeType.AST_BINARY_EXPR {
        // 二元表达式：(left op right)
        format_expr(ctx, expr.left);
        write_char(ctx, 32);  // ' '
        write_str(ctx, expr.op);
        write_char(ctx, 32);  // ' '
        format_expr(ctx, expr.right);
    } else if expr.type == ASTNodeType.AST_CALL_EXPR {
        // 调用表达式：func(args)
        format_expr(ctx, expr.callee);
        write_char(ctx, 40);  // '('
        var i: usize = 0;
        while i < expr.arg_count {
            if i > 0 {
                write_str(ctx, ", " as *byte);
            }
            format_expr(ctx, expr.args[i]);
            i = i + 1;
        }
        write_char(ctx, 41);  // ')'
    }
    // ... 其他表达式类型
}

// 格式化语句
fn format_stmt(ctx: &FormatContext, stmt: &ASTNode) void {
    if stmt == null { return; }
    
    write_indent(ctx);
    
    if stmt.type == ASTNodeType.AST_VAR_DECL {
        // 变量声明：var name: Type = value;
        write_str(ctx, "var " as *byte);
        write_str(ctx, stmt.name);
        write_str(ctx, ": " as *byte);
        write_str(ctx, stmt.var_type);
        write_str(ctx, " = " as *byte);
        format_expr(ctx, stmt.init);
        if ctx.config.semicolons != 0 {
            write_char(ctx, 59);  // ';'
        }
        write_newline(ctx);
    } else if stmt.type == ASTNodeType.AST_RETURN_STMT {
        // 返回语句：return value;
        write_str(ctx, "return" as *byte);
        if stmt.value != null {
            write_char(ctx, 32);  // ' '
            format_expr(ctx, stmt.value);
        }
        if ctx.config.semicolons != 0 {
            write_char(ctx, 59);  // ';'
        }
        write_newline(ctx);
    } else if stmt.type == ASTNodeType.AST_IF_STMT {
        // if 语句
        write_str(ctx, "if " as *byte);
        format_expr(ctx, stmt.condition);
        write_str(ctx, " {" as *byte);
        write_newline(ctx);
        
        ctx.indent_level = ctx.indent_level + 1;
        format_block(ctx, stmt.then_block);
        ctx.indent_level = ctx.indent_level - 1;
        
        write_indent(ctx);
        write_char(ctx, 125);  // '}'
        write_newline(ctx);
    }
    // ... 其他语句类型
}

// 格式化代码块
fn format_block(ctx: &FormatContext, block: &ASTNode) void {
    if block == null || block.statements == null { return; }
    
    var i: usize = 0;
    while i < block.stmt_count {
        format_stmt(ctx, block.statements[i]);
        i = i + 1;
    }
}

// 格式化函数定义
fn format_function(ctx: &FormatContext, func: &ASTNode) void {
    write_indent(ctx);
    
    // fn name(params) ReturnType { body }
    write_str(ctx, "fn " as *byte);
    write_str(ctx, func.name);
    write_char(ctx, 40);  // '('
    
    // 参数
    var i: usize = 0;
    while i < func.param_count {
        if i > 0 {
            write_str(ctx, ", " as *byte);
        }
        write_str(ctx, func.params[i].name);
        write_str(ctx, ": " as *byte);
        write_str(ctx, func.params[i].param_type);
        i = i + 1;
    }
    
    write_char(ctx, 41);  // ')'
    
    // 返回类型
    if func.return_type != null {
        write_str(ctx, " " as *byte);
        write_str(ctx, func.return_type);
    }
    
    write_str(ctx, " {" as *byte);
    write_newline(ctx);
    
    // 函数体
    ctx.indent_level = ctx.indent_level + 1;
    format_block(ctx, func.body);
    ctx.indent_level = ctx.indent_level - 1;
    
    write_indent(ctx);
    write_char(ctx, 125);  // '}'
    write_newline(ctx);
}

// 主格式化函数
export fn format_code(
    input: &byte,
    input_len: usize,
    output: &byte,
    output_max: usize
) FormatResult {
    var result: FormatResult = FormatResult {
        success: 1,
        output_len: 0,
        error_message: null
    };
    
    // 1. 词法分析
    var tokens: TokenBuffer = tokenize(input, input_len);
    if tokens.error != null {
        result.success = 0;
        result.error_message = tokens.error;
        return result;
    }
    
    // 2. 语法分析
    var ast_root: ASTNode = parse(tokens);
    if ast_root.error != null {
        result.success = 0;
        result.error_message = ast_root.error;
        return result;
    }
    
    // 3. 格式化输出
    var ctx: FormatContext = FormatContext {
        config: default_config(),
        output: output,
        output_size: output_max,
        output_pos: 0,
        indent_level: 0,
        line_start: 1,
        line_length: 0
    };
    
    // 遍历 AST，输出格式化代码
    var i: usize = 0;
    while i < ast_root.decl_count {
        const decl: &ASTNode = ast_root.declarations[i];
        if decl.type == ASTNodeType.AST_FUNCTION {
            format_function(&ctx, decl);
            write_newline(&ctx);
        }
        i = i + 1;
    }
    
    result.output_len = ctx.output_pos;
    return result;
}
```

---

## 5. 共享模块

### 5.1 编译核心模块

`src/core/` 目录，供 build/check/run/test 共享：

```
src/core/
├── compiler.uya    # 编译器核心（compile_files）
├── dependency.uya  # 依赖收集
├── linker.uya      # 链接器接口
└── config.uya      # 编译配置
```

### 5.2 解析核心模块

`src/parser/` 和 `src/lexer.uya`，供所有工具共享：

```
src/
├── lexer.uya       # 词法分析
├── ast.uya         # AST 定义
├── arena.uya       # 内存管理
└── parser/         # 语法分析
    ├── main.uya
    ├── expr.uya
    └── stmt.uya
```

---

## 6. 构建流程

### 6.1 Makefile

```makefile
# 工具链
TOOLS = bin/uya bin/uya-build bin/uya-run bin/uya-test bin/uya-fmt

# 默认目标
all: $(TOOLS)

# 主入口（转发器）
bin/uya: src/main.uya
	./bin/uya build src/main.uya -o bin/uya.c --c99
	gcc -O2 -o bin/uya bin/uya.c

# 编译器
bin/uya-build: src/tools/build.uya src/core/*.uya src/parser/*.uya
	./bin/uya build src/tools/build.uya -o bin/uya-build.c --c99
	gcc -O2 -o bin/uya-build bin/uya-build.c

# 运行器
bin/uya-run: src/tools/run.uya
	./bin/uya build src/tools/run.uya -o bin/uya-run.c --c99
	gcc -O2 -o bin/uya-run bin/uya-run.c

# 测试运行器
bin/uya-test: src/tools/test.uya
	./bin/uya build src/tools/test.uya -o bin/uya-test.c --c99
	gcc -O2 -o bin/uya-test bin/uya-test.c

# 格式化器
bin/uya-fmt: src/tools/fmt.uya src/fmt/*.uya src/parser/*.uya
	./bin/uya build src/tools/fmt.uya -o bin/uya-fmt.c --c99
	gcc -O2 -o bin/uya-fmt bin/uya-fmt.c

# 安装
install: $(TOOLS)
	install -m 755 bin/uya /usr/local/bin/
	install -m 755 bin/uya-build /usr/local/bin/
	install -m 755 bin/uya-run /usr/local/bin/
	install -m 755 bin/uya-test /usr/local/bin/
	install -m 755 bin/uya-fmt /usr/local/bin/

# 清理
clean:
	rm -f bin/uya bin/uya-build bin/uya-run bin/uya-test bin/uya-fmt
	rm -f bin/*.c
```

### 6.2 自举构建

```bash
# 第一阶段：用现有编译器构建工具链
make all

# 第二阶段：用新编译器自举
make clean
bin/uya-build src/tools/build.uya -o bin/uya-build.c --c99
gcc -O2 -o bin/uya-build bin/uya-build.c
# ... 重复其他工具 ...
```

---

## 7. 使用示例

### 7.1 直接使用工具

```bash
# 编译
uya-build main.uya -o myapp

# 运行
uya-run main.uya

# 测试
uya-test tests/

# 格式化
uya-fmt src/*.uya
```

### 7.2 通过主入口使用

```bash
# 编译
uya build main.uya -o myapp

# 运行
uya run main.uya

# 测试
uya test tests/

# 格式化
uya fmt src/*.uya
```

### 7.3 CI 集成

```yaml
# .github/workflows/ci.yml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build
        run: uya-build src/main.uya -o app
        
      - name: Test
        run: uya-test tests/
        
      - name: Format Check
        run: uya-fmt --check src/
```

---

## 8. 与其他工具链对比

| 工具链 | 架构 | 主入口 | 子命令 |
|--------|------|--------|--------|
| **Git** | 独立程序 | `git` | `git-add`, `git-commit` |
| **Rust** | 独立程序 | `cargo` | `rustc`, `rustfmt`, `clippy` |
| **Go** | 内置 | `go` | 内置子命令 |
| **Uya** | 独立程序 | `uya` | `uya-build`, `uya-fmt` |

Uya 采用类似 Git 的架构：
- `uya` 是极简转发器（~100 行）
- 每个子命令是独立程序
- 通过 `execv()` 调用，无缝传递参数

---

## 9. 迁移计划

### Phase 1：重构入口（不破坏现有功能）

1. 创建 `src/tools/` 目录
2. 将 `main.uya` 改为转发器
3. 创建 `build.uya` 作为独立编译器入口
4. 保持 `make check` 正常工作

### Phase 2：添加新工具

1. 创建 `run.uya`（调用 uya-build）
2. 创建 `test.uya`（调用 uya-build）
3. 创建 `fmt.uya`（独立实现）

### Phase 3：优化共享模块

1. 提取 `src/core/compiler.uya`
2. 统一配置管理
3. 优化构建时间

---

## 10. 总结

**独立程序架构** 的核心优势：

1. **模块化**：每个工具独立开发、测试
2. **可扩展**：添加新工具不影响现有工具
3. **可替换**：用户可自定义工具
4. **性能**：只加载需要的代码
5. **用户体验**：`uya build` 和 `uya-build` 两种方式都可用

这种架构既保持了简洁的用户界面，又提供了灵活的底层实现。
