# Uya v0.2.5 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.4（57ed7b17）以来的提交记录整理，在 v0.2.4 基础上完成 **联合体（union）规范与文档**、**错误处理与 defer/errdefer 实现**、**error_id 哈希与稳定性规范**，以及 **if 单条语句解析** 与 **defer/errdefer 控制流限制** 等变更。C 版与自举版（uya-src）同步实现，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. 联合体（union）规范与文档

- **规范 0.35**：在 changelog、grammar_formal、grammar_quick、uya.md、uya_ai_prompt、index.html 等中补充联合体说明。
- **语法**：`union UnionName { variant1: Type1, variant2: Type2, ... }`，创建 `UnionName.variant(expr)`，访问需 `match` 或编译期可证明的已知标签。
- **C 互操作**：与 C union 100% 内存布局兼容，支持 `extern union`。
- **待办**：在 todo_mini_to_full.md 中增加联合体相关待办；UYA_MINI_SPEC 仍将联合体列为「不支持」，后续实现阶段可接入。

### 2. 错误处理与 defer/errdefer 实现

- **错误类型与 !T**：预定义 `error Name;`、运行时 `error.Name`、`!T` 类型与内存布局；AST 新增 AST_ERROR_DECL、AST_TRY_EXPR、AST_CATCH_EXPR、AST_ERROR_VALUE、AST_DEFER_STMT、AST_ERRDEFER_STMT。
- **try/catch**：`try expr` 传播错误、`expr catch |err| { }` / `expr catch { }`；main 支持 `fn main() !i32`，错误→退出码。
- **defer/errdefer**：defer 在块退出时执行，errdefer 仅在错误路径执行；LIFO 顺序、作用域与 C 版/uya-src 一致。
- **实现范围**：Lexer、AST、Parser、Checker、Codegen（expr、stmt、main、internal、types、utils）、arena；uya-src 对应模块同步。
- **测试**：test_defer*、test_errdefer*、test_error_handling、test_main_with_errors、test_return_error、test_try_div、test_catch_only、test_try_only 等；错误用例 error_defer_*、error_errdefer_*、error_error_id_collision、test_error_forward_use、test_error_global、test_error_runtime_only、test_error_same_id 等。

### 3. defer/errdefer 控制流限制

- **规范**：defer/errdefer 块内禁止使用控制流语句（return、break、continue），在 grammar_formal、grammar_quick、uya.md 中说明。
- **Checker**：对 defer/errdefer 块内 return/break/continue 报错。
- **Codegen**：块以 return/break/continue 结尾时不重复执行 defer 清理逻辑；stmt 注释明确控制流限制。
- **测试**：error_defer_break、error_defer_break_nested、error_defer_continue、error_defer_continue_nested、error_defer_return*、error_errdefer_return、error_errdefer_wrong_scope 等。

### 4. if 语句单条分支解析

- **解析**：if 的 then/else 分支允许单条语句，自动包装为块节点；C 版 parser_parse_statement、自举版 parser.uya 同步。
- **测试**：错误用例统一重命名为 `error_*.uya`（如 error_const_reassignment、error_enum_c_style_access、error_ffi_ptr_in_normal_fn 等）；run_programs.sh 简化编译失败预期检查；main 由测试时 bridge.c 提供，移除冗余 main 生成逻辑。

### 5. error_id 分配与稳定性（规范 0.35.1）

- **分配规则**：`error_id = hash(error_name)`（djb2），相同错误名在任意编译中映射到相同 `error_id`。
- **冲突处理**：不同错误名 hash 冲突时，编译器报错并提示冲突名称，开发者需重命名其一。
- **实现**：checker.c/checker.h、codegen_c99.h、codegen/c99/utils.c；uya-src checker.uya、codegen/c99/utils.uya、internal.uya 同步。
- **规范与文档**：changelog 0.35.1、UYA_MINI_SPEC、grammar_formal、grammar_quick、uya.md、uya_ai_prompt、index.html、todo_mini_to_full 已更新；main.c/main.uya 涉及 error 相关逻辑处与规范一致。

---

## 主要变更（自 57ed7b1 起）

| 提交 | 变更摘要 |
|------|----------|
| f1dc08f | 联合体（union）支持：文档与规范、todo 更新、版本标记 0.35 |
| 6b5ca18 | 错误处理与 defer/errdefer：AST/Lexer/Parser/Checker/Codegen、arena、测试与 todo |
| 5a0f0c7 | if 单条语句解析、错误用例重命名为 error_*、run_programs.sh、bridge.c |
| c65cbca | defer/errdefer 控制流限制：文档、Checker、Codegen、错误用例 |
| 49f5b33 | defer/errdefer 代码生成优化、errdefer 作用域错误、parser if 单条语句、uya-src 同步 |
| 9cfa6ed | error_id 改为哈希：checker、codegen、uya-src、测试（error_id_collision、error_forward_use 等） |
| 7fe212f | error_id 分配与稳定性规范：changelog 0.35.1、多文档与 spec、todo 标记完成 |

---

## 实现范围（概要）

| 区域 | 变更摘要 |
|------|----------|
| 规范/文档 | changelog 0.35/0.35.1、UYA_MINI_SPEC、grammar_*、uya.md、uya_ai_prompt、index.html、todo_mini_to_full |
| C 编译器 | arena、ast、lexer、parser、checker、codegen（expr/stmt/main/types/utils/internal）、codegen_c99.h |
| uya-src | ast、lexer、parser、checker、codegen（expr/stmt/main/types/utils/internal）、main |
| 测试 | test_defer*、test_errdefer*、test_error_*、test_main_*、test_try_*、test_catch_only、error_*；run_programs.sh |

---

## 验证

```bash
cd compiler-mini

# C 版
./tests/run_programs.sh --c99 tests/programs/test_defer.uya tests/programs/test_errdefer.uya
./tests/run_programs.sh --c99 tests/programs/test_error_handling.uya tests/programs/test_main_with_errors.uya

# 自举版
./tests/run_programs.sh --uya --c99 tests/programs/test_defer.uya tests/programs/test_errdefer.uya
./tests/run_programs.sh --uya --c99 tests/programs/test_error_handling.uya tests/programs/test_main_with_errors.uya
```

错误用例（error_*.uya）预期编译失败，由 run_programs.sh 按约定检查。

---

## 已知限制与后续方向

- **本版本**：联合体部分仅更新规范与文档，Mini 编译器尚未实现 union 语法与代码生成；错误处理与 defer/errdefer 已实现并与规范对齐。
- **后续计划**：按 todo_mini_to_full.md 继续切片、match、for 扩展、接口等；联合体实现可单独排期；保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 错误处理、defer/errdefer、规范 0.35/0.35.1 与测试的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.5
- **基于**：v0.2.4（57ed7b17e4817da9670b47af9e55e7cbcf4bbaf3）
- **记录范围**：57ed7b1..HEAD（7 个提交）
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
