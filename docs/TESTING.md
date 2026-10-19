# Uya 回归测试说明

**版本**：v0.10.4
**更新日期**：2026-10-19

---

## 测试框架

推荐使用 `test "名称" { ... }` 块（`tests/` 中 400+ 个文件使用该形式）：

```uya
use std.testing.assert_eq_i32;

test "addition" {
    const a: i32 = 10;
    const b: i32 = 5;
    const sum: i32 = a + b;
    try assert_eq_i32(sum, 15);
}
```

断言宏返回 `!void`，所以调用处要写 `try`（或用 `catch` 处理）。

也可以使用 `std.testing` 的显式 runner（宏 `run_test` + `test_suite_begin/end`）：

```uya
use std.testing.run_test;
use std.testing.test_suite_begin;
use std.testing.test_suite_end;
use std.testing.assert_eq_i32;

fn test_feature() !void {
    assert_eq_i32(1 + 1, 2);
}

export fn main() i32 {
    test_suite_begin("Module Tests");
    run_test("feature", test_feature);
    return test_suite_end();
}
```

> `std.testing` 的断言都是宏（`mc`）：`assert`、`assert_true`、`expect`、`assert_eq_i32` /
> `assert_eq_i64` / `assert_eq_u64` / `assert_eq_bool`、`expect_not_null` / `expect_null`。
> 没有 `expect_eq` / `expect_true` 这两个名字。

---

## 运行测试

### 语法 / checker 快速检查

在跑完整回归前，建议先用 `check` 做单文件快速验证：

```bash
bin/uya check tests/check_cli_no_main.uya
bin/uya check tests/error_check_missing_brace.uya
```

`check` 只跑到 checker，不生成 C、不链接、不执行程序，适合先确认语法错误、模块解析错误和类型错误。

### 完整测试套件

```bash
make tests        # 默认 CPU 核数并行（UYA_TEST_JOBS=N 可改），默认不打印每条通过的 ✓
make tests-uya    # 只测自举编译器路线（nostdlib）
make tests-hosted # hosted 路线
make check        # 自举验证 + 全量测试（提交前口径）
```

输出示例（数字以当次运行为准）：

```
总计: 1153 个测试
通过: 1153
失败: 0
```

### 并行测试

```bash
./tests/run_programs_parallel.sh              # 全部（默认同 CPU 核数）
./tests/run_programs_parallel.sh -j 4         # 4 线程
./tests/run_programs_parallel.sh --uya --c99  # 自举编译器 + C99 路线
./tests/run_programs_parallel.sh --c99 -e     # 仅失败详情
./tests/run_programs_parallel.sh test_std_sql.uya
```

环境变量 `PARALLEL_JOBS=N` 等价于 `-j N`。

### unknown / emcc 独立 smoke

当改动涉及 `lib/libc/syscall.uya`、`lib/std/runtime/entry/entry.uya`、`std.target_os == .tos_unknown` 路径，或 Web/Node hosted 运行时桥接时，建议补跑：

```bash
make tests-emcc
```

说明：
- 该目标要求本机已安装 `emcc` 与 `node`
- 脚本入口是 `tests/verify_emcc_unknown_runtime.sh`
- 它会生成 `TARGET_OS=unknown TARGET_ARCH=unknown` 的 C99 程序，并与 `tests/emcc_unknown_host.c` 提供的宿主 bridge 一起链接执行
- 当前属于独立 smoke，不默认包含在 `make check` 或 `make release-dirty` 中

### Exec VM 专项回归

当改动涉及 `src/exec/`、`lib/libc/stdio.uya`、`try/catch` lowering、`@syscall` exec 路径或 `extern ABI` 边界时，建议先跑这批脚本：

```bash
bash ./tests/verify_exec_backend_progress.sh
bash ./tests/verify_exec_vm_stdio_varargs.sh
bash ./tests/verify_exec_vm_extern_bridge.sh
bash ./tests/verify_exec_vm_compiler_regressions.sh
```

其中：

- `verify_exec_vm_stdio_varargs.sh` 覆盖 `va_list` / `@va_start` / `@va_arg` / `@va_copy`，以及 `fprintf -> vfprintf -> _vfprintf_impl -> snprintf` 的 exec VM 路径
- `verify_exec_vm_compiler_regressions.sh` 覆盖“显式类型局部 + catch 标识符路径”和“字段数组 / 指针字段 / 全局数组下标写入路径”两类近期修复过的编译器回归

### 单个测试

最省事的方式是让编译器直接编译并运行：

```bash
./bin/uya test tests/test_std_sql.uya
./bin/uya test --c99 tests/test_std_sql.uya
```

也可以分步：先出 C，再自己链接运行：

```bash
./bin/uya build tests/programs/test_bounds_check.uya -o /tmp/test_bounds_check.c --c99 --no-split-c
gcc -std=c99 /tmp/test_bounds_check.c -o /tmp/test_bounds_check -lm
/tmp/test_bounds_check
```

对于带 `_start` 的 `--nostdlib` 产物，链接方式需改成仓库当前使用的 freestanding 方式。例如：

```bash
./bin/uya build --c99 --nostdlib tests/test_std_sql.uya -o /tmp/test_std_sql.c --no-split-c
gcc -std=c99 -nostdlib -static -no-pie /tmp/test_std_sql.c -o /tmp/test_std_sql
/tmp/test_std_sql
```

### 带 `@c_import` 的单个测试

如果测试文件包含 `@c_import`，有两种推荐方式：

1. 直接让编译器生成并链接可执行文件：

```bash
bin/uya build tests/test_c_import_file.uya -o /tmp/test_c_import_file --c99
/tmp/test_c_import_file
```

2. 只生成 C，再使用 sidecar 完成手动链接：

```bash
bin/uya build tests/test_c_import_dir.uya -o /tmp/test_c_import_dir.c --c99 --no-split-c
CC=gcc ./tests/link_cimports_posix.sh /tmp/test_c_import_dir.c /tmp/test_c_import_dir.bin
/tmp/test_c_import_dir.bin
```

说明：
- 当单文件 C 输出路径中检测到 `@c_import` 时，编译器会额外生成 `/tmp/test_c_import_dir.cimports.sh`
- 该 sidecar 保存了导入的 C 源、相对路径、逐 token 的 `cflags` 和聚合后的 `ldflags`
- `tests/link_cimports_posix.sh` 会读取 sidecar，先编译导入的 C object，再与主 `.c` 一起链接
- 若走 split-C / `--split-c-dir` 路径，导入的 C object 会直接进入 Makefile，不会额外生成 sidecar

---

## 测试分类

| 类别 | 文件前缀 | 数量 |
|------|----------|------|
| 基础语法 | `test_basic*.uya` | 1 |
| 类型系统 | `test_type*.uya` | 17 |
| 结构体 | `test_struct*.uya` | 25 |
| 联合体 | `test_union*.uya` | 11 |
| 接口 | `test_interface*.uya` | 6 |
| 错误处理 | `test_error*.uya`, `test_try*.uya` | 12 |
| 宏 | `test_macro*.uya` | 35 |
| 泛型 | `test_generic*.uya` | 38 |
| 切片 | `test_slice*.uya` | 7 |
| 指针 | `test_pointer*.uya` | 4 |
| 标准库 / crypto | `test_std_*.uya`, `test_crypto_*.uya` | 53 |
| libc | `test_ctype.uya`, `test_stdio*.uya` | 3 |
| 其他 | 其他 `test_*.uya` | 682 |
| 合计 | `tests/test_*.uya` | 894 |

另有负例 `tests/error_*.uya` 198 个、最小复现 `tests/repros/` 17 个，以及 `tests/*.sh` 脚本 184 个；
`tests/` 顶层 `.uya` 合计 1,164 个。

---

## 自举验证

```bash
make b
```

自举验证流程（`src/compile.sh --bootstrap-compare`）：
1. 用 `bin/uya` 编译 `src/*.uya`（自举编译）；
2. **多文件 / split-C 模式**：对比主编译产物与自举产物的可执行文件（先剥离调试段与 build-id 再 `cmp`，验证「可执行代码一致」）；
3. **单文件模式**：`diff` 两次生成的 C 输出；
4. 一致则通过。

如果你是在调试发布链路，也可以临时跑：

```bash
make release-dirty
```

它会在当前工作树里强行执行完整 release 流程，但不会替代 `make release` 或 `make release-clean` 作为最终结论。

---

## 测试编写规范

### 断言函数

| 函数 | 用途 |
|------|------|
| `assert(cond, msg)` | 断言条件，失败时带消息 |
| `assert_true(cond)` / `expect(cond)` | 布尔断言 |
| `assert_eq_i32(a, b)` | i32 相等 |
| `assert_eq_i64(a, b)` | i64 相等 |
| `assert_eq_u64(a, b)` | u64 相等 |
| `assert_eq_bool(a, b)` | bool 相等 |
| `expect_not_null(p)` / `expect_null(p)` | 指针空/非空 |

> 以上都是 `std.testing` 导出的 `mc` 宏，返回 `!void`，调用处需 `try`。

### 测试命名

- 文件名：`test_<功能>.uya`
- 测试函数：`test_<功能>_<场景>()`
- 新增标准库模块时，优先补对应回归文件，如 `tests/test_std_sql.uya`

### 错误处理

测试函数返回 `!void`，错误即测试失败：

```uya
use std.testing.assert_eq_i32;

fn test_division() !void {
    const result = divide(10, 2) catch |err| {
        return error.TestFailed;  // 显式失败
    };
    try assert_eq_i32(result, 5);
}
```

---

## CI 集成

推荐 CI 流程：

```yaml
test:
  script:
    - make from-c        # Linux 冷启动；macOS 用 make from-c-native
    - make tests-uya
    - make b
    # unknown/web 运行时改动时可追加：
    # - make tests-emcc
```

---

## 测试覆盖率

当前状态（2026-10-19）：
- **单文件测试**：`tests/*.uya` 共 1,164 个（`test_*` 894、`error_*` 198、其他 72）
- **最小复现**：`tests/repros/` 17 个
- **脚本**：`tests/*.sh` 184 个
- **最近一次全量结果**：`make check` **1153/1153**（见 `docs/releases/RELEASE_v0.10.4.md`）
- **自举验证**：`make b` 通过（产物 `cmp` 一致）

---

## 相关文档

- **开发指导**：[DEVELOPMENT.md](./DEVELOPMENT.md)
- **测试框架源码**：`lib/std/testing/testing.uya`
- **测试规范**：[testing_guide.md](./testing_guide.md)
- **发布流程**：`make release` / `make release-clean` / `make release-dirty`
- **`@c_import` 设计**：[c_import_design.md](./c_import_design.md)
