# Uya v0.2.24 版本说明

**发布日期**：2026-02-04

本版本主要修复了**测试文件变量名不一致问题**和**自举编译器测试运行器链接错误**：修复了 `test_field_array.uya` 测试文件中的变量名不一致问题，以及使用 `--uya` 选项时没有测试语句的程序会调用未定义的 `uya_run_tests()` 函数导致的链接错误。

---

## 核心亮点

### 1. 测试文件修复

- **修复变量名不一致**：修复了 `test_field_array.uya` 中变量名 `test` 与 `test1` 不一致的问题
- **避免关键字冲突**：将变量名从 `test` 改为 `test1`，避免与 `test` 关键字冲突

### 2. 自举编译器测试运行器修复

- **条件调用测试运行器**：只有在存在测试语句时才调用 `uya_run_tests()` 函数
- **添加测试计数字段**：在 `C99CodeGenerator` 结构体中添加 `test_count` 字段，用于记录测试语句数量
- **修复链接错误**：修复了使用 `--uya` 选项时，没有测试语句的程序会调用未定义的 `uya_run_tests()` 函数导致的链接错误

---

## 模块变更

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| codegen/c99/internal.uya | 添加 `test_count: i32` 字段到 `C99CodeGenerator` 结构体 |
| codegen/c99/utils.uya | 在 `c99_codegen_new` 函数中初始化 `test_count` 为 0 |
| codegen/c99/main.uya | 收集测试后，将 `test_count` 保存到 `codegen.test_count` |
| codegen/c99/function.uya | 只有在 `codegen.test_count > 0` 时才调用 `uya_run_tests()` |

### 测试与工具

- **修复测试用例**：`test_field_array.uya` - 修复变量名不一致问题
- **测试验证**：所有测试用例在 C 版和自举版编译器中均通过

---

## 测试验证

- **C 版编译器（`--c99`）**：所有测试用例通过（236 个测试，235 个通过，1 个修复后通过）
- **自举版编译器（`--uya --c99`）**：所有测试用例通过（修复前多个测试链接失败，修复后全部通过）
- **测试文件修复**：`test_field_array.uya` 通过 `--c99` 与 `--uya --c99`

---

## 文件变更统计（自 v0.2.23 以来）

**自举实现（uya-src）**：
- `compiler-mini/uya-src/codegen/c99/internal.uya` — 添加 `test_count` 字段
- `compiler-mini/uya-src/codegen/c99/utils.uya` — 初始化 `test_count` 为 0
- `compiler-mini/uya-src/codegen/c99/main.uya` — 保存测试计数到 `codegen.test_count`
- `compiler-mini/uya-src/codegen/c99/function.uya` — 条件调用 `uya_run_tests()`

**测试用例**：
- `compiler-mini/tests/programs/test_field_array.uya` — 修复变量名不一致问题

**统计**：4 个文件变更，约 10+ 行新增/修改

---

## 版本对比

### v0.2.23 → v0.2.24 变更

- **修复**：
  - ✅ 修复 `test_field_array.uya` 测试文件中的变量名不一致问题
  - ✅ 修复使用 `--uya` 选项时，没有测试语句的程序会调用未定义的 `uya_run_tests()` 函数导致的链接错误
  - ✅ 添加 `test_count` 字段到 `C99CodeGenerator` 结构体，用于条件调用测试运行器

- **非破坏性**：向后兼容，现有测试用例行为不变

---

## 技术细节

### 测试运行器条件调用修复

**问题**：在 `function.uya` 中，无论是否有测试语句，只要函数是 `main`，都会无条件调用 `uya_run_tests()`。但是 `uya_run_tests()` 函数只有在有测试语句时才会被生成（在 `main.uya` 的 `gen_test_runner` 函数中）。对于没有测试的程序，函数被调用但未定义，导致链接错误。

**修复**：
1. 在 `C99CodeGenerator` 结构体中添加 `test_count` 字段，用于记录测试语句数量
2. 在 `c99_codegen_new` 函数中初始化 `test_count` 为 0
3. 在 `main.uya` 中收集测试后，将 `test_count` 保存到 `codegen.test_count`
4. 在 `function.uya` 中，只有在 `codegen.test_count > 0` 时才调用 `uya_run_tests()`

```uya
// 修复前：无条件调用
if is_main != 0 {
    fputs(" {\n" as *byte, codegen.output);
    fputs("    uya_run_tests();\n" as *byte, codegen.output);  // ❌ 总是调用
}

// 修复后：条件调用
if is_main != 0 {
    fputs(" {\n" as *byte, codegen.output);
    if codegen.test_count > 0 {  // ✅ 只有在有测试时才调用
        fputs("    uya_run_tests();\n" as *byte, codegen.output);
    }
}
```

### 测试文件变量名修复

**问题**：`test_field_array.uya` 中第11行声明变量 `test`，但第14行使用了 `test1.size`，导致 `test1` 未定义。另外，使用 `test` 作为变量名可能与 `test` 关键字冲突。

**修复**：将第11行的变量名从 `test` 改为 `test1`，并确保第14行使用 `test1.size`，保持一致性。

```uya
// 修复前：变量名不一致
var test: Test = Test{ buffer: null, size: 100 };
const size: i32 = test1.size;  // ❌ test1 未定义

// 修复后：变量名一致
var test1: Test = Test{ buffer: null, size: 100 };
const size: i32 = test1.size;  // ✅ 正确
```

---

## 使用示例

### 测试运行器自动调用

```uya
// 有测试语句的程序：自动调用 uya_run_tests()
test "测试示例" {
    // 测试代码
}

fn main() i32 {
    // uya_run_tests() 会自动在 main 函数开始时调用
    return 0;
}
```

```uya
// 没有测试语句的程序：不调用 uya_run_tests()
fn main() i32 {
    // 不会调用 uya_run_tests()，避免链接错误
    return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **原子类型**：atomic T、&atomic T
- **泛型（Generics）**：类型参数、泛型函数、泛型结构体
- **异步编程（Async）**：async/await、Future 类型
- **test 关键字**：测试单元支持（已完成，本次修复了链接问题）
- **消灭所有警告**：消除编译器和生成的 C 代码中的所有警告

---

## 相关资源

- **语言规范**：`uya.md`（测试单元、错误处理）
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_field_array.uya`

---

**本版本修复了测试文件变量名不一致问题和自举编译器测试运行器链接错误，确保了所有测试用例在 C 版和自举版编译器中均能正常通过。**

