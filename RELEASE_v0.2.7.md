# Uya v0.2.7 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.6 以来的提交记录整理，在 v0.2.6 基础上完成 **错误 ID 哈希逻辑优化**、**开发流程约定（测试先行）**，以及 **切片类型与表达式** 的完整实现。C 版与自举版（uya-src）同步，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. 错误 ID 生成逻辑优化

- **哈希规则**：`error_id = hash(error_name)`（djb2），相同错误名在任意编译中映射到相同 `error_id`。
- **冲突处理**：不同错误名 hash 冲突时，编译器报错并提示冲突名称。
- **实现**：checker.c/checker.h、codegen/c99/utils.c；uya-src checker.uya、codegen/c99/utils.uya 同步。
- **测试**：error_error_id_collision、test_error_forward_use、test_error_global、test_error_runtime_only、test_error_same_id 等。

### 2. 开发流程约定：测试先行

- **实现约定**：编写编译器代码前，先在 `tests/programs/` 添加测试用例，覆盖目标场景。
- **验证要求**：测试需同时通过 `--c99`（C 版）与 `--uya --c99`（自举版），二者都通过才算通过。
- **文档**：todo_mini_to_full.md 更新实现约定与验证流程。

### 3. 切片类型与表达式（C 版 + 自举版同步）

- **切片类型**：`&[T]`（动态长度）、`&[T: N]`（已知长度），胖指针 ptr+len 布局。
- **切片语法**：`base[start:len]`，支持数组、切片作为 base；可再切片。
- **索引与 @len**：`slice[i]` 访问元素，`@len(slice)` 返回长度（usize）。
- **实现范围**：
  - **C 版**：AST_TYPE_SLICE、AST_SLICE_EXPR；Parser 解析 `&[T]`/`&[T: N]` 与 `base[start:len]`；Checker TYPE_SLICE、@len(slice)；Codegen `struct uya_slice_X { T* ptr; size_t len; }`、复合字面量、slice.ptr[i]、@len(slice).len。
  - **uya-src**：ast.uya、parser.uya、checker.uya、codegen（types/expr/main/internal/utils）完整同步。
- **测试**：test_slice.uya 覆盖动态/已知长度切片、索引、再切片、@len，通过 `--c99` 与 `--uya --c99`，自举对比 `--c99 -b` 一致。

---

## 主要变更（自 v0.2.6 起）

| 提交 | 变更摘要 |
|------|----------|
| b33d594 | 错误 ID 哈希：checker、codegen、文档与测试 |
| d688bf5 | todo_mini_to_full.md：添加测试先行约定与验证要求 |
| 4106c97 | 切片类型支持：AST、Parser、Checker、Codegen、spec、测试 |
| bbf871a | 切片表达式支持：Parser base[start:len]、@len、slice[i]，uya-src 同步 |

---

## 实现范围（概要）

| 区域 | 变更摘要 |
|------|----------|
| 规范/文档 | todo_mini_to_full.md、UYA_MINI_SPEC、error_id 补充说明 |
| C 编译器 | ast、parser、checker、codegen（types/expr/main/utils） |
| uya-src | ast、parser、checker、codegen（types/expr/main/internal/utils）、extern_decls |
| 测试 | test_slice.uya、error_error_id_collision、test_error_* |

---

## 验证

```bash
cd compiler-mini

# C 版
./tests/run_programs.sh --c99 test_slice.uya
./tests/run_programs.sh --c99 test_error_handling.uya

# 自举版
./tests/run_programs.sh --uya --c99 test_slice.uya
./tests/run_programs.sh --uya --c99 test_error_handling.uya

# 自举对比（C 输出与自举输出一致）
cd uya-src && ./compile.sh --c99 -e -b
```

---

## 已知限制与后续方向

- **本版本**：切片已完整实现并同步到自举版；结构体切片字段（`struct S { s: &[T] }`）类型与 Codegen 已支持，测试待补。
- **后续计划**：按 todo_mini_to_full.md 继续 match 表达式、for 扩展、接口等；保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 切片实现、错误 ID 优化与测试的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.7
- **基于**：v0.2.6
- **记录范围**：v0.2.6..HEAD（4 个提交）
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
