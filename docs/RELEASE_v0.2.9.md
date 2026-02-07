# Uya v0.2.9 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.8 以来的提交记录整理，在 v0.2.8 基础上完成 **整数范围 for 循环** 的完整实现。C 版与自举版（uya-src）同步，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 整数范围 for 循环（C 版 + 自举版同步）

- **语法**：`for start..end [ |v| ] { statements }`，支持迭代变量绑定或丢弃形式。
- **迭代语义**：迭代区间 `[start, end)`，循环变量 `v` 从 `start` 递增到 `end-1`。
- **形式**：
  - **带变量**：`for start..end |i| { ... }`，将当前迭代值绑定到 `i`。
  - **丢弃形式**：`for start..end { ... }`，不绑定变量，仅执行 `(end - start)` 次。
- **无限范围**：`for start.. |v| { ... }` 从 `start` 无限递增，需 `break` 或 `return` 终止（规范已定义，本版重点实现有界范围）。
- **实现范围**：
  - **规范**：UYA_MINI_SPEC.md 补充 range_expr、for 范围形式语法与语义说明。
  - **C 版**：AST（for_stmt.is_range、range_start、range_end）、Lexer（TOKEN_DOT_DOT、`..` 与数字解析）、Parser（识别 first_expr..second_expr 范围形式）、Checker（范围表达式须整数类型）、Codegen（有界范围展开为 C `for` 循环）。
  - **uya-src**：ast.uya、lexer.uya、parser.uya、checker.uya、codegen/c99/stmt.uya、main.uya、utils.uya 同步；ARENA_BUFFER_SIZE 增至 64MB 以容纳 for 范围等 AST 自举需求。
- **测试**：test_for_range.uya 覆盖 `for 0..5 |i|`、`for 0..3` 丢弃形式、`for 1..4 |k|` 乘积计算，通过 `--c99` 与 `--uya --c99`；自举对比 `--c99 -b` 一致。

---

## 主要变更（自 v0.2.8 起）

| 提交 | 变更摘要 |
|------|----------|
| e0c4886 | 新增 v0.2.8 版本说明，完整实现 match 表达式并同步 C 版与自举版 |
| dfd1c38 | 整数范围 for 循环：AST、Lexer、Parser、Checker、Codegen、UYA_MINI_SPEC、todo_mini_to_full、test_for_range.uya |

---

## 实现范围（概要）

| 区域 | 变更摘要 |
|------|----------|
| 规范/文档 | UYA_MINI_SPEC（range_expr、for 范围）、todo_mini_to_full（整数范围 for 已实现） |
| C 编译器 | ast、lexer、parser、checker、codegen/c99（stmt、main） |
| uya-src | ast、lexer、parser、checker、codegen/c99（stmt、main、utils）、main（ARENA_BUFFER_SIZE） |
| 测试 | test_for_range.uya |

---

## 验证

```bash
cd compiler-mini

# C 版
./tests/run_programs.sh --c99 test_for_range.uya

# 自举版
./tests/run_programs.sh --uya --c99 test_for_range.uya

# 全量自举测试
./tests/run_programs.sh --uya

# 自举对比（C 输出与自举输出一致）
cd uya-src && ./compile.sh --c99 -e -b
```

---

## 已知限制与后续方向

- **本版本**：整数范围 for 循环已完整实现并同步到自举版；有界形式 `start..end` 与丢弃形式均已支持。
- **后续计划**：按 todo_mini_to_full.md 继续 for 扩展（无限范围、迭代器形式）、接口等；保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 整数范围 for 循环实现与自举测试的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.9
- **基于**：v0.2.8
- **记录范围**：v0.2.8..HEAD（2 个提交）
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
