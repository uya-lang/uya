# Uya v0.2.3 版本说明

**发布日期**：2026-01-31

本版本在 v0.2.2 基础上完成 **自举编译器（uya-src）可变参数与 @params 支持**，与 C 编译器行为对齐。形参 `...`、调用末尾 `...` 转发、`@params` 元组访问及 va_list/vprintf 代码生成在 `--uya --c99` 下均已通过测试；并修复普通函数 FFI 指针形参的检查逻辑及测试用例中的 printf 格式串警告。

---

## 核心亮点

### 自举编译器可变参数与 @params 完整支持

- **形参 `...`**：`fn wrap_printf(fmt: *byte, ...) i32` 与 `extern fn printf(fmt: *byte, ...) i32` 在 uya-src 的 parser 中正确解析并设置 `fn_decl_is_varargs`。
- **调用末尾 `...` 转发**：`return printf(fmt, ...);` 在 parser 中解析为 `has_ellipsis_forward`，checker 校验仅在可变参数函数内且被调也为可变参数、实参个数等于固定参数个数；codegen 生成 va_list/va_start/vprintf/va_end 的零开销转发。
- **@params**：Lexer 识别 `@params`；parser 在 primary 中解析 `@params` 及 `@params.0`、`@params.1` 等成员访问链；checker 仅在函数体内允许、类型为当前函数参数元组；codegen 生成 `(struct { T0 f0; ... }){ .f0 = p0, ... }`，stmt 中 `const p = @params` 用大括号列表初始化。
- **FFI 指针形参放宽**：普通函数仅在**可变参数**时允许 FFI 指针形参（如 `wrap_printf(fmt: *byte, ...)`），非可变参数普通函数仍禁止 FFI 指针形参，与 test_ffi_ptr_in_normal_fn 预期一致。

至此，「下次优先实现」中的可变参数与 @params 在 C 与 uya-src 两套实现中均已完成（见 `compiler-mini/todo_mini_to_full.md`）。

---

## 主要变更

### 可变参数与 @params 在自举中的实现范围

| 能力 | C 编译器 | 自举编译器（本版本） |
|------|----------|------------------------|
| 形参 `...`（fn / extern fn） | ✓ | ✓ |
| 调用末尾 `...` 转发 | ✓ | ✓ |
| `@params`、`@params.0` / `.1` | ✓ | ✓ |
| `const p = @params` 初始化 | ✓ | ✓ |
| va_list / vprintf 生成 | ✓ | ✓ |
| `#include <stdarg.h>` | ✓ | ✓ |

### 与 v0.2.2 的差异

| 项目 | v0.2.2 | v0.2.3 |
|------|--------|--------|
| 可变参数 / @params（C） | 已支持 | 不变 |
| 可变参数 / @params（自举） | 未同步 | **已同步**，`test_varargs.uya`、`test_varargs_full.uya` 在 `--c99` 与 `--uya --c99` 下均通过 |
| 普通函数 FFI 指针形参 | C 端逻辑曾放行所有 | **修正**：仅可变参数函数允许 FFI 指针形参 |
| test_varargs_full printf | 源中 `%%d` 导致 C 端“格式参数过多”警告 | **修正**：改为 `%d`，消除警告 |

---

## 实现范围（自举 uya-src）

| 模块 | 变更摘要 |
|------|----------|
| AST | 新增 `AST_PARAMS`；`call_expr_has_ellipsis_forward` |
| Lexer | `@params` 加入 @ 后可接受标识符列表 |
| Parser | 形参列表识别 `...` 并设置 `is_varargs`；primary 解析 `@params` 及 `.0`/`.1` 链；调用参数列表末尾解析 `...` 并设置 `has_ellipsis_forward` |
| Checker | `current_function_decl`；`AST_PARAMS` 类型推断（仅函数体内、元组为当前参数）；`has_ellipsis_forward` 校验；普通函数 FFI 形参仅允许可变参数 |
| Codegen | `current_function_decl` 保存/恢复；`AST_PARAMS` 元组复合字面量；调用处 `...` 转发生成 va_list/vprintf；stmt 中 `const p = @params` 大括号初始化；`#include <stdarg.h>` |
| Utils | 字符串常量等无变更；expr/stmt 收集已支持新节点 |

---

## 修复与测试

### C 编译器

- **checker.c**：普通函数 + FFI 指针形参时，仅在 **非** 可变参数（`!node->data.fn_decl.is_varargs`）时报错「普通函数不能使用 FFI 指针类型作为参数」，恢复 test_ffi_ptr_in_normal_fn 的预期编译失败。
- **test_varargs_full.uya**：`printf("direct: %%d %%d\n", 1, 2)` 改为 `printf("direct: %d %d\n", 1, 2)`，消除 C 端 -Wformat-extra-args 警告。

### 验证

```bash
cd compiler-mini

# C 版编译器
./tests/run_programs.sh --c99 tests/programs/test_varargs_full.uya
./tests/run_programs.sh --c99 tests/programs/test_ffi_ptr_in_normal_fn.uya   # 预期编译失败 ✓

# 自举编译器
./tests/run_programs.sh --uya --c99 tests/programs/test_varargs_full.uya
```

### 自举对比

```bash
cd compiler-mini/uya-src
./compile.sh --c99 -b    # C 输出与自举输出一致 ✓
```

所有相关测试需同时通过 `--c99` 与 `--uya --c99`（见 `.cursorrules` 验证流程）。

---

## 已知限制与后续方向

- **本版本**：仅完成自举侧可变参数与 @params 与 C 对齐，并修正 FFI 形参规则与测试用例；未新增语言特性。
- **后续计划**：按 `compiler-mini/todo_mini_to_full.md` 继续字符串插值与 printf 结合、错误处理、defer/errdefer、切片、match 等阶段，并保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 自举可变参数实现、测试与文档工作的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.3
- **基于**：v0.2.2
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
