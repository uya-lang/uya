# Uya fmt Phase 3 TodoList

> **核对头（2026-09-27）**：本 phase 文档的 "Not started" 勾选状态已过时——对应能力已在 `src/fmt.uya` + `tests/test_fmt_*.uya` 落地（`uya fmt` 命令见 `src/main.uya` 的 `COMMAND_FMT`）。
> 保留本文件作为任务分解记录；唯一仍明确未支持的是 `fmt_phase4_cli_tasks.md` 里的"stdin 与 `-s/-r` 组合"。

> 基于 `docs/fmt_development_plan.md` 的方案 B，Phase 3 聚焦 import_sort / simplify / rewrite 的结构化变换能力。

**Goal**: 在 parser 和 printer 之间建立稳定的 AST transform 层。

---

## Status

- [ ] Not started
- [x] MVP Done

---

## Phase 3 Goals

- [x] 在打印前统一整理 use/import
- [x] 提供可选 simplify 规则
- [x] 提供结构化 rewrite 规则
- [x] 确保变换结果仍能稳定打印并保持幂等

---

## Main Pipeline

- [x] 打通 `source -> tokenize -> parse_file -> attach_comments -> sort_imports -> rewrite -> simplify -> print_file -> formatted source`

---

## File Tasks

### `lib/std/fmt/import_sort.uya`

- [x] 实现最小 `sort_use_lines(source)`
- [x] 保持 `std.*` 在前
- [x] 保持非 `std.*` 在后
- [x] 保持同组按字母排序
- [x] 去除重复 use
- [x] 验证排序只改顺序，不改文本内容
- [x] 验证再次排序结果不再变化
- [ ] 实现 AST 级 `collect_use_decls(file)`
- [ ] 实现 AST 级 `sort_use_decls(file)`
- [ ] 实现 AST 级 `dedup_use_decls(file)`
- [ ] 实现 AST 级 `group_use_decls(file)`

### `lib/std/fmt/simplify.uya`

- [x] 实现最小 `simplify_text(source)`
- [x] 实现 `return (x); -> return x;`
- [x] 实现 `return (1); -> return 1;`
- [x] 验证 simplify 可开关控制
- [x] 验证第二次 simplify 不再产生变化
- [ ] 实现 AST 级 `simplify_file(file)`
- [ ] 实现 AST 级 `simplify_decl(decl)`
- [ ] 实现 AST 级 `simplify_stmt(stmt)`
- [ ] 实现 AST 级 `simplify_expr(expr)`
- [ ] 实现更广义 `(x) -> x`
- [ ] 实现 `*&x -> x`
- [ ] 实现第一批冗余表达式包装简化
- [ ] 验证 AST simplify 前后语义等价

### `lib/std/fmt/rewrite.uya`

- [x] 定义 `RewriteRule`
- [x] 实现 `parse_rewrite_rule(text)`
- [x] 实现最小 `apply_rewrite_text(source, rule)`
- [x] 支持 `pattern -> replacement`
- [x] 验证 `foo.bar -> bar` 这类规则可工作
- [x] 验证 rewrite 结果可通过 formatter 主入口使用
- [ ] 实现 `match_expr(pattern, expr)`
- [ ] 实现 `rewrite_file(file, rule)`
- [ ] 实现 `rewrite_expr(expr, rule)`
- [ ] 支持 AST 表达式级 rewrite
- [ ] 支持基本标识符绑定

### `lib/std/fmt/fmt.uya`

- [x] 实现 `format_with_options(...)`
- [x] 增加 `sort_imports` 选项
- [x] 增加 `simplify` 选项
- [x] 增加 `rewrite_rule` 选项
- [x] 增加 `has_rewrite_rule` 选项
- [x] 串联 `attach_comments -> sort_imports -> rewrite -> simplify -> print_file`

---

## Tests

### `tests/test_fmt_import_sort.uya`
- [x] 验证 std 在前
- [x] 验证同组字母排序
- [x] 验证重复 use 去重
- [x] 验证 import_sort 幂等

### `tests/test_fmt_simplify.uya`
- [x] 验证 simplify 规则生效
- [x] 验证 simplify 可关闭/可选接入
- [x] 验证 simplify 幂等

### `tests/test_fmt_rewrite.uya`
- [x] 验证 rewrite 规则可解析
- [x] 验证 rewrite 输出正确
- [x] 验证 rewrite 幂等
- [ ] 验证 AST rewrite 匹配正确

### `tests/test_fmt_api_phase3.uya`
- [x] 验证 `format_with_options(..., sort_imports=true)`

### `tests/test_fmt_api_simplify.uya`
- [x] 验证 `format_with_options(..., simplify=true)`

### `tests/test_fmt_api_rewrite.uya`
- [x] 验证 `format_with_options(..., rewrite_rule=...)`

---

## Definition of Done

- [x] import 排序可用且幂等
- [x] simplify 可用且幂等
- [x] rewrite 可用且幂等
- [x] 变换结果均能被 printer 稳定输出
- [x] 所有最小变换均通过 `format_with_options` 暴露
- [x] 库层 API 已补充 `FormatOptions` / `FormatResult` 以支撑 CLI 与调用方

---

## Notes

- 当前完成的是 **Phase 3 最小可用目标**。
- `import_sort` 当前为 **源码级 use 行排序**，不是 AST 级 `UseDecl` 排序。
- `simplify` 当前为 **最小文本级规则**，仅覆盖 `return (x);` / `return (1);` 这类保守场景。
- `rewrite` 当前为 **文本级 rewrite**，不是 AST pattern match。
- 当前库层已补充 `FormatOptions` 与 `FormatResult`，可直接支撑 CLI 与外部调用方。
- 若后续需要更接近 gofmt，可在 Phase 3.5 再将三类 transform 升级为 AST 级实现。
