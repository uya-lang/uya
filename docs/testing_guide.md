# Uya 测试规范

**版本**: 2.0.0
**日期**: 2026-10-19

---

## 1. 概述

本规范定义 Uya 项目的测试编写标准，依据当前 `lib/std/testing/testing.uya` 与
`src/main.uya` 的 `uya test` 实现整理。

### 1.1 核心理念

- **错误即测试失败**：测试函数返回 `!void`，断言失败返回 `error`
- **自动传播**：使用 `try` 自动传播断言失败
- **资源安全**：使用 `defer` / `errdefer` 确保清理
- **统一报告**：测试运行器自动统计通过/失败数与断言数
- **零依赖**：测试程序走标准库 + libc，不需要额外 bridge 文件

---

## 2. 测试框架

### 2.1 两种写法

**推荐：`test "名称" { ... }` 块**（`tests/` 中 400+ 个文件使用）：

```uya
use std.testing.assert_eq_i32;

test "addition" {
    const sum: i32 = 1 + 1;
    try assert_eq_i32(sum, 2);
}
```

**显式 runner**（需要自定义入口或输出时）：

```uya
use std.testing.assert_eq_i32;
use std.testing.test_suite_begin;
use std.testing.test_suite_end;
use std.testing.run_test;

fn test_addition() !void {
    try assert_eq_i32(1 + 1, 2);
}

export fn main() i32 {
    test_suite_begin("Arithmetic Tests");
    run_test("addition", test_addition);
    return test_suite_end();
}
```

### 2.2 核心组件（`lib/std/testing/testing.uya`）

| 组件 | 说明 |
|------|------|
| `test_suite_begin(name)` | 开始测试套件 |
| `run_test(name, test_fn)` | 宏：运行单个测试（`test_fn` 返回 `!void`） |
| `test_pass(name)` / `test_fail(name)` | 记录单个测试结果 |
| `test_suite_end()` | 结束套件，返回失败数（作为进程返回码） |

> `run_test` 是 `mc` 宏，不是普通函数；调用处不要加 `try`。

### 2.3 断言宏

全部来自 `std.testing`，返回 `!void`，调用处需 `try`：

```uya
try assert(condition, "message");          // 条件 + 消息
try assert_true(condition);                // 只验证条件
try expect(condition);                     // assert_true 的别名风格

try assert_eq_i32(actual, expected);
try assert_eq_i64(actual, expected);
try assert_eq_u64(actual, expected);
try assert_eq_bool(actual, expected);

try expect_not_null(ptr);
try expect_null(ptr);
```

**不存在** `expect_eq` / `expect_true` / `expect_false` / `assert_ne_i32` / `assert_gt_i32` /
`assert_lt_i32` / `assert_ge_i32` / `assert_le_i32` / `assert_ptr_eq` / `assert_null` / `skip_test`。
需要比较大小或检查不等时，直接用布尔表达式配合 `assert` / `expect`。

---

## 3. 测试文件结构

### 3.1 文件命名

| 前缀 | 用途 | 期望 |
|------|------|------|
| `test_*.uya` | 正向回归 | 编译并运行通过 |
| `error_*.uya` | 负向用例 | 编译/检查阶段必须报错 |
| `recursive_*` / `nested_*` | 递归 / 嵌套结构 | 编译并运行通过 |
| `tests/repros/*.uya` | 最小复现（缺陷未修时保留） | 记录用，不保证通过 |
| `verify_*.sh` / `stress_*.sh` | 脚本化验证 / 压测 | 由 `make check` 或专项目标调用 |

当前规模：`tests/test_*.uya` 894 个、`tests/error_*.uya` 198 个、`tests/repros/` 17 个、
`tests/*.sh` 184 个。

### 3.2 标准模板

```uya
// test_<module>.uya - <模块描述>
//
// 覆盖：<场景 1>、<场景 2>
// 运行：./bin/uya test tests/test_<module>.uya

use std.testing.assert_eq_i32;
use std.testing.expect_not_null;

test "<scenario one>" {
    const result: i32 = function1(input);
    try assert_eq_i32(result, expected);
}

test "<scenario with resource>" {
    var resource: Resource = try create_resource();
    defer { cleanup(resource); }
    errdefer { cleanup_on_error(resource); }

    try expect_not_null(resource.data);
}
```

### 3.3 入口机制

- `test "名称" {}` 块由编译器收集，`uya test` 自动生成运行器。
- 显式 runner 使用 `export fn main() i32 { ... }`；需要 entry 模块时 `use std.runtime.entry`。

### 3.4 运行与编译命令

```bash
# 推荐：直接编译并运行（默认 C99 split-C，放在 .uyacache）
./bin/uya test tests/test_std_sql.uya

# 指定 C99 后端 / 栈大小（KB）
./bin/uya test --c99 --stack-size 65536 tests/test_std_sql.uya

# 只做语法 + 类型检查（不生成 C、不运行）
./bin/uya check tests/test_std_sql.uya

# 单文件 C 输出（便于观察生成的 C）
./bin/uya build tests/test_std_sql.uya -o /tmp/test_std_sql.c --c99 --no-split-c
gcc -std=c99 /tmp/test_std_sql.c -o /tmp/test_std_sql -lm
/tmp/test_std_sql

# 批量 / 并行
make tests
./tests/run_programs_parallel.sh --uya --c99 -j 8
```

如果测试依赖 `@c_import`，推荐直接 `./bin/uya build ... --c99` 让编译器完成链接；只输出
`.c` 时会额外生成 sidecar，可用 `tests/link_cimports_posix.sh` 手动链接：

```bash
./bin/uya build tests/test_c_import_file.uya -o /tmp/test_c_import_file.c --c99 --no-split-c
CC=gcc ./tests/link_cimports_posix.sh /tmp/test_c_import_file.c /tmp/test_c_import_file
/tmp/test_c_import_file
```

---

## 4. 返回码约定

| 返回值 | 含义 |
|--------|------|
| `0` | 所有测试通过 |
| 非零 | 失败的测试数量（`test_suite_end()` 的返回值） |

### 4.1 CI/CD 集成

```bash
./bin/uya test tests/test_std_sql.uya
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "All tests passed"
else
    echo "$exit_code tests failed"
    exit 1
fi
```

---

## 5. 测试编写规范

### 5.1 测试函数签名

```uya
// 正确：返回 !void
fn test_feature() !void {
    try expect(condition);
}

// 旧方式（不推荐）
fn test_feature() i32 {
    return 0;
}
```

### 5.2 断言使用

```uya
// 推荐：带语义的断言
try assert_eq_i32(result, 5);

// 比较大小：用布尔条件
try assert(result > 0, "result should be positive");
```

### 5.3 资源管理

```uya
fn test_with_file() !void {
    const file: FileHandle = try open_file("test.txt");

    errdefer { rollback(file); }   // 出错时回滚
    defer { close_file(file); }    // 总是关闭

    try expect_not_null(file.data);
}
```

### 5.4 错误测试

```uya
test "divide by zero returns error" {
    const result: i32 = divide(10, 0) catch |err| {
        try expect(@error_id(err) == @error_id(error.DivisionByZero));
        return;
    };
    try assert(false, "divide should have failed");
}
```

### 5.5 表驱动测试

```uya
struct TestCase {
    input: i32,
    expected: i32,
}

fn square(x: i32) i32 {
    return x * x;
}

test "square table" {
    const cases: [TestCase: 3] = [
        TestCase{ input: 1, expected: 1 },
        TestCase{ input: 2, expected: 4 },
        TestCase{ input: 3, expected: 9 },
    ];
    for 0..3 |i| {
        const tc: TestCase = cases[i];
        try assert_eq_i32(square(tc.input), tc.expected);
    }
}
```

---

## 6. 输出格式

### 6.1 标准输出

`uya test` 的真实输出形如：

```
=== Running 2 tests ===
  TEST: addition ... OK
  TEST: failing ... assert_eq_i32 failed: 1 + 1 == 3 (actual: 2, expected: 3)
ERROR

=== Results ===
  Tests Passed:       1
  Tests Failed:       1
  Assertions Passed:  1
================================
总计: 1 个测试
通过: 0
失败: 1
================================
程序运行返回码：1
```

### 6.2 测试跳过

按平台/网络条件跳过的脚本级用例由 `tests/run_programs_parallel.sh` 的 `SKIP_TEST_PATTERNS` /
`SKIP_TESTS` / `SKIP_NETWORK` 处理（例如 macOS 默认跳过部分 Linux-centric 用例），
测试框架本身没有 `skip_test` 函数。

---

## 7. 最佳实践

### 7.1 测试命名

- 文件名：`test_<功能>.uya`；负例：`error_<功能>.uya`
- 测试名：描述「行为 + 条件」，如 `test "empty input returns zero"`

### 7.2 测试隔离

- 每个 `test` 块自带作用域，避免共享可变全局。
- 需要全局状态时，在每个测试里显式重置。

### 7.3 边界条件

优先覆盖：空输入、零/负数、最大/最小值、越界（负例）、错误路径、资源释放次数。

### 7.4 断言选择

- 能证明「具体值」就断言具体值，不要只断言非空。
- 负向用例要断言**具体错误**（`@error_id`），不要只断言「失败了」。

---

## 8. 附录

### 8.1 完整示例

```uya
// test_stack.uya - 计数器与资源释放
use std.testing.assert_eq_i32;
use std.testing.expect;

struct Counter {
    value: i32,
}

Counter {
    fn bump(self: &Counter) void {
        self.value = self.value + 1;
    }
}

test "counter bump" {
    var c: Counter = Counter{ value: 0 };
    c.bump();
    c.bump();
    try assert_eq_i32(c.value, 2);
}

test "defer runs once" {
    var closed: i32 = 0;
    {
        defer { closed = closed + 1; }
        try expect(closed == 0);
    }
    try expect(closed == 1);
}
```

### 8.2 断言宏完整列表

| 宏 | 签名 | 说明 |
|----|------|------|
| `assert` | `(condition, message)` | 条件为假时报错并带消息 |
| `assert_true` | `(condition)` | 条件为假时报错 |
| `expect` | `(condition)` | 同 `assert_true` |
| `assert_eq_i32` | `(actual, expected)` | i32 相等 |
| `assert_eq_i64` | `(actual, expected)` | i64 相等 |
| `assert_eq_u64` | `(actual, expected)` | u64 相等 |
| `assert_eq_bool` | `(actual, expected)` | bool 相等 |
| `expect_not_null` | `(ptr)` | 指针非空 |
| `expect_null` | `(ptr)` | 指针为空 |
| `run_test` | `(name, test_fn)` | 运行单个测试（`stmt` 宏） |
