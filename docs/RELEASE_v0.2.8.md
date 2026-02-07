# Uya v0.2.8 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.7 以来的提交记录整理，在 v0.2.7 基础上完成 **match 表达式** 的完整实现。C 版与自举版（uya-src）同步，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### match 表达式完整支持（C 版 + 自举版同步）

- **语法**：`match expr { pat => result, ... }`，支持作为表达式或语句使用。
- **模式类型**：
  - **常量模式**：整数、布尔、枚举成员（如 `Color.Red`），匹配相等时执行对应分支。
  - **变量绑定**：单变量模式（如 `v => v`），将匹配值绑定到变量。
  - **else 分支**：`else => result` 兜底。
- **枚举匹配**：支持对枚举类型进行模式匹配，正确解析枚举成员名并生成对应整型比较。
- **实现范围**：
  - **规范**：UYA_MINI_SPEC.md 补充 match 语法与语义说明。
  - **C 版**：AST（AST_MATCH_EXPR、MatchPatternKind）、Parser 解析 match 与多种模式、Checker 类型检查、Codegen 生成 GCC 语句表达式（`({ type _uya_m = ...; type _uya_r; if (...) _uya_r = ...; ... _uya_r; })`）。
  - **uya-src**：ast.uya、lexer.uya（match、=>）、parser.uya、checker.uya、codegen/c99/expr.uya、codegen/c99/enums.uya（find_enum_variant_value）同步；字符串常量表扩容（C99_MAX_STRING_CONSTANTS 1024）、枚举变体值递增逻辑与 C 版一致，保证自举编译与测试全部通过。
- **测试**：test_match.uya 覆盖整数/布尔/枚举常量匹配、变量绑定、else 分支、match 语句，通过 `--c99` 与 `--uya --c99`；自举对比 `--c99 -b` 一致。

---

## 主要变更（自 v0.2.7 起）

| 提交 | 变更摘要 |
|------|----------|
| 3b87611 | match 表达式支持：AST、Parser、Checker、Codegen、UYA_MINI_SPEC、todo_mini_to_full、test_match.uya |
| f46952b | match 表达式完整支持：lexer match/=>、多模式解析、C 与自举版一致、文档与测试更新 |

---

## 实现范围（概要）

| 区域 | 变更摘要 |
|------|----------|
| 规范/文档 | UYA_MINI_SPEC（match 语法）、todo_mini_to_full（match 已实现） |
| C 编译器 | ast、lexer、parser、checker、codegen/c99（expr、enums） |
| uya-src | ast、lexer、parser、checker、codegen/c99（expr、enums、internal 字符串常量上限） |
| 测试 | test_match.uya |

---

## 验证

```bash
cd compiler-mini

# C 版
./tests/run_programs.sh --c99 test_match.uya

# 自举版
./tests/run_programs.sh --uya --c99 test_match.uya

# 全量自举测试
./tests/run_programs.sh --uya

# 自举对比（C 输出与自举输出一致）
cd uya-src && ./compile.sh --c99 -e -b
```

---

## 已知限制与后续方向

- **本版本**：match 表达式已完整实现并同步到自举版；全量 188 个测试在 `--uya` 下通过。
- **后续计划**：按 todo_mini_to_full.md 继续 for 扩展、接口等；保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini match 表达式实现与自举测试的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.8
- **基于**：v0.2.7
- **记录范围**：v0.2.7..HEAD（3 个提交，含 v0.2.7 版本说明提交）
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
