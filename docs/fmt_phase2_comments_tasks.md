# Uya fmt Phase 2 TodoList

> **核对头（2026-09-27）**：本 phase 文档的 "Not started" 勾选状态已过时——对应能力已在 `src/fmt.uya` + `tests/test_fmt_*.uya` 落地（`uya fmt` 命令见 `src/main.uya` 的 `COMMAND_FMT`）。
> 保留本文件作为任务分解记录；唯一仍明确未支持的是 `fmt_phase4_cli_tasks.md` 里的"stdin 与 `-s/-r` 组合"。

> 基于 `docs/fmt_development_plan.md` 的方案 B，Phase 2 聚焦 comments / positions 在格式化链路中的落地。

**Goal**: 在 Phase 1 最小 formatter 之上，补齐注释收集、注释附着、注释打印与位置保持能力。

---

## Status

- [ ] Not started
- [x] MVP Done

---

## Phase 2 Goals

- [x] token 流中保留注释信息
- [x] 将注释从 token 层附着到 AST 邻近节点
- [x] pretty printer 能正确输出行注释、块注释、文档注释
- [x] 格式化后注释不丢失、不明显漂移
- [x] 在幂等测试中验证注释稳定性

---

## Scope

- [x] 支持行注释 `// comment`
- [x] 支持块注释 `/* comment */`
- [x] 支持文档注释（声明前连续注释）
- [x] 支持独立行注释
- [x] 支持行尾注释
- [x] 支持基于 `Span` 的相邻节点附着

---

## Out of Scope

- [ ] 注释智能重排
- [ ] 多列注释对齐
- [ ] 复杂注释重流式排版
- [ ] 注释驱动的 AST 变换

---

## Main Pipeline

- [x] 打通 `source -> tokenize(with comments) -> parse_file -> collect comments -> attach_comments -> print_file(with comments) -> formatted source`

---

## File Tasks

### `lib/std/fmt/comments.uya`

- [x] 定义 `Comment`
- [x] 定义 `CommentKind`
- [x] 定义 `CommentGroup`
- [ ] 定义 `AttachedComments`
- [x] 实现 `collect_comments(tokens)`
- [x] 实现 `group_comments(comments)`
- [x] 实现最小 `attach_comments(file, groups)` / `attach_decl_comments(file, groups)`
- [x] 验证注释可从 token 流中提取
- [x] 验证连续注释可归组
- [x] 验证注释可附着到函数声明
- [x] 验证注释可泛化附着到语句或块（最小 printer 路径）

### `lib/std/fmt/positions.uya`

- [x] 增加 `span_before()`
- [x] 增加 `span_after()`
- [x] 增加 `span_contains()`
- [x] 增加注释附着所需的距离比较函数
- [x] 验证可依据源码顺序比较 comment 与 node 的相对位置

### `lib/std/fmt/tokenizer.uya`

- [x] 输出 `LINE_COMMENT` token
- [x] 输出 `BLOCK_COMMENT` token
- [x] 保留注释 token 完整原始文本
- [x] 保留注释 token 的 `span`
- [x] 验证注释文本不丢失
- [x] 验证注释位置准确

### `lib/std/fmt/ast.uya`

- [x] 为声明节点预留 doc comment 关联字段
- [x] 采用轻量索引字段避免引入 AST/comments 循环依赖
- [x] 验证 printer 能访问 declaration doc comments
- [ ] 为文件节点预留完整 attached comments 字段
- [ ] 为语句节点预留完整 attached comments 字段
- [ ] 定义泛化 comment wrapper 结构

### `lib/std/fmt/printer.uya`

- [ ] 实现完整 `print_comment()`
- [x] 实现 `print_comment_group()`
- [x] 在 `print_decl()` 中插入注释输出逻辑
- [x] 在 `print_stmt()` 中插入显式注释输出逻辑（最小 trailing/after-stmt 路径）
- [ ] 在 `print_block()` 中插入显式注释输出逻辑
- [x] 保持文档注释在声明前逐行输出
- [x] 保持独立行注释可保留
- [x] 保持行尾注释与主体同一行输出
- [x] 保持块注释原样输出，不做重排
- [x] 验证常见注释场景格式化后可读且稳定

### `lib/std/fmt/fmt.uya`

- [x] 在 `format()` 流程中插入 `collect_comments()`
- [x] 在 `format()` 流程中插入最小 `attach_comments()`
- [x] 串联 `tokenize -> parse_file -> collect_comments -> attach_comments -> print_file`

---

## Tests

### `tests/test_fmt_comments.uya`
- [x] 验证行注释不丢失
- [x] 验证块注释不丢失
- [x] 验证文档注释保留在声明前
- [x] 验证行尾注释保持在对应语句后

### `tests/test_fmt_comment_collection.uya`
- [x] 验证 comment token 显式输出
- [x] 验证 `collect_comments()` 收集 line/block comment

### `tests/test_fmt_comment_grouping.uya`
- [x] 验证连续注释归组
- [x] 验证隔空行注释拆组
- [x] 验证 block + line comment 归组

### `tests/test_fmt_comments_phase2.uya`
- [x] 验证 span helpers
- [x] 验证 comment model
- [x] 验证 mixed comments 场景保留

### `tests/test_fmt_doc_comment_attach.uya`
- [x] 验证 declaration doc comment attach
- [x] 验证 printer 在声明前输出 doc comment
- [x] 验证多 declaration doc comments 场景

### `tests/test_fmt_trailing_comment_attach.uya`
- [x] 验证 trailing comment 与 return 同行保留
- [x] 验证 trailing comment 与第二条语句同行保留

### `tests/test_fmt_idempotent.uya`
- [x] 验证 `format(format(x)) == format(x)`
- [x] 验证注释不重复输出
- [x] 验证注释不漂移到错误节点

---

## Acceptance Sample

```uya
// add returns sum
fn add(a,b){
    return a+b; // sum
}
```

- [x] 格式化后文档注释保留在函数前
- [x] 格式化后行尾注释仍保留在 `return` 语句后
- [x] 再次格式化结果完全一致

---

## Definition of Done

- [x] 格式化后注释不丢失
- [x] 文档注释能稳定绑定到声明
- [x] 行尾注释不会跳到下一行或错误节点
- [x] 注释场景通过幂等测试
- [x] 不引入与第一阶段主链路冲突的特化逻辑

---

## Notes

- 当前完成的是 **Phase 2 最小可用目标**。
- 已显式打通 comment token / collect / group / 最小 decl attach / printer 输出链路。
- 已具备最小 statement 级注释输出能力（覆盖 trailing comment 与 after-stmt comment 场景）。
- 尚未实现完整泛化的 `AttachedComments` 与完整 statement/block attach 模型。
- 若后续需要更接近 gofmt，可在 Phase 2.5 再扩展完整 attach 模型。
