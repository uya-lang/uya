# Uya v0.6.0 版本说明

**发布日期：** 2026年2月20日

## 里程碑：统一测试框架 & CLI 重构

本版本引入了全新的测试语法 `test "name" {}`，统一了命令行接口，大幅简化了测试编写和项目管理。

---

## 核心功能

### 1. 统一测试语法 `test "name" {}`

全新的测试语法，无需手动定义 main 函数：

```uya
// 旧写法（已废弃）
use std.runtime.entry;
fn test_add() !void {
    try assert_eq(1 + 1, 2);
}
export fn main() i32 { ... }

// 新写法（推荐）
test "test_add" {
    try assert_eq(1 + 1, 2);
}
```

特性：
- **自动检测**：编译器自动识别 `test "..."` 和 `export fn main`
- **测试运行器**：自动生成 `main` 函数和测试调度代码
- **错误传播**：`test "..."` 返回 `!void`，支持 `try` 表达式
- **测试输出**：自动打印测试名称和结果

### 2. 统一命令行接口 (CLI)

新增 `build`/`run`/`test` 子命令：

```bash
# 构建项目
uya build main.uya -o program

# 编译并运行
uya run main.uya

# 运行测试
uya test main.uya
```

### 3. --nostdlib 和 --static 编译选项

编译器现在原生支持生成独立可执行文件：

```bash
# --nostdlib: 生成带 _start 入口的代码，不依赖标准库
uya --nostdlib main.uya -o program.c

# --static: 静态链接，生成完全独立的可执行文件
uya build main.uya --static -o program

# 组合使用：最小化可执行文件
uya build main.uya --nostdlib --static -o program
```

特性：
- **--nostdlib**：生成 `_start` 入口，不使用 libc
- **--static**：静态链接所有依赖，无需动态库

---

## 语法改进

### test "name" {} 块

```uya
test "arithmetic operations" {
    try assert_eq_i32(1 + 2, 3);
    try assert_eq_i32(10 - 3, 7);
}

test "string operations" {
    const s = "hello";
    try assert_eq_i32(@len(s), 5);
}
```

### !void 返回类型修复

修复了 `return;` 在返回 `!void` 的函数中的代码生成问题：

```uya
fn maybe_fail() !void {
    if some_condition {
        return;  // 现在正确生成 (struct err_union_void){ .error_id = 0 }
    }
    return error.SomeError;
}
```

---

## 文件变更

### 编译器核心
- `src/main.uya` - 新增 `--nostdlib` 参数，统一 CLI
- `src/codegen/c99/main.uya` - 自动生成 `main` 和测试运行器
- `src/codegen/c99/stmt.uya` - 修复 `!void` 返回语句
- `src/codegen/c99/internal.uya` - 新增 `is_nostdlib` 字段

### 标准库
- `lib/std/testing/testing.uya` - 移除废弃的 `check_xxx` 函数
- `lib/std/runtime/entry/` - 统一程序入口模块

### 测试框架
- 46 个测试文件迁移到 `test "name" {}` 格式
- 所有 `check_xxx` 替换为 `try assert_xxx`

---

## 测试状态

- 自举验证：✓ 通过
- 单元测试：414/414 通过
- 测试格式迁移：100% 完成

---

## 贡献者

- winger - 核心开发

---

## 下一步计划

- [ ] 异步编程支持
- [ ] 包管理器
- [ ] IDE 插件

---

**测试更简单，开发更高效！**
