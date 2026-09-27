# Uya fmt 开发计划

> **核对头（2026-09-27）**：`uya fmt` 已落地：`src/main.uya` 有 `COMMAND_FMT`，实现主体在 `src/fmt.uya`（1100+ 行），仓库内还有 `tools/fmt*.uya` 与十余个 `tests/test_fmt_*.uya` 回归。
> 因此本计划与 `fmt_phase1..4` 任务文档里的 "Not started" 勾选状态**已过时**；其中明确仍未支持的只有 `fmt_phase4_cli_tasks.md` 记录的一项：stdin 与 `-s/-r` 组合。
> 进度请以测试与 `src/fmt.uya` 现状为准。

> 参考 Go `go/format` + `go/printer` + `gofmt` 实现

**版本**: v0.2.5  
**更新日期**: 2026-06-01

---

## 概述

### 目标

为 Uya 实现类似 Go `gofmt` 的代码格式化工具，使 Uya 代码风格统一、可读性增强，并提供稳定、幂等、可集成到开发流程中的格式化能力。

### 核心原理

解析源码 → AST → 可选 AST 变换 → 重新打印 → 输出/回写

### 项目集成

- 遵循 TDD 开发流程（`make tests` 验证）
- 测试文件放在 `tests/test_fmt_*.uya`
- 库文件放在 `lib/std/fmt/`
- CLI 工具放在 `tools/`

---

## 架构说明

### 设计决策：采用方案 B（完整 gofmt-like formatter）

由于要实现接近 Go `gofmt` 的能力，fmt 库不再只停留在“Tokenizer + 手工构造 AST + Printer”的最小模型，而是按完整格式化工具组织：

1. **完整词法与语法层**：在 fmt 库内实现独立可用的 tokenizer / parser / AST 结构
2. **注释与位置信息保留**：格式化过程必须保留 comments 与 positions
3. **AST 变换前置**：import 排序、rewrite、simplify 发生在打印前
4. **Printer 作为统一出口**：所有源码最终都通过 pretty printer 重新生成
5. **CLI 与库分层**：`lib/std/fmt/*` 提供库能力，`tools/fmt.uya` 负责编排与命令行行为

### 与 gofmt 对齐的分层

```text
tools/fmt.uya
   │
   ├─ 参数解析 / 文件遍历 / stdin / -w -d -l -r -s
   │
   ├─ lib/std/fmt/fmt.uya
   │    ├─ tokenize
   │    ├─ parse
   │    ├─ attach_comments
   │    ├─ sort_imports
   │    ├─ rewrite
   │    ├─ simplify
   │    └─ print
   │
   └─ 输出控制
        ├─ stdout
        ├─ 覆盖写回
        ├─ diff
        └─ list
```

### 实施策略

按两段交付，但总体架构按方案 B 设计：

- **阶段 A：最小可用 formatter**
  - formatter
  - tokenizer
  - AST 基础结构
  - printer
  - 少量表达式/语句节点
  - 幂等测试
- **阶段 B：完整 gofmt-like formatter**
  - 完整 parser
  - comments / positions
  - import sort
  - rewrite
  - simplify
  - CLI

这样可以先拿到可运行能力，再逐步向完整 `gofmt` 对齐。

### 分阶段任务总看板

- [x] 第一阶段：最小 formatter 主链路完成  
  详见：`docs/fmt_phase1_minimal_tasks.md`
- [x] 第二阶段：comments / positions 保持完成  
  详见：`docs/fmt_phase2_comments_tasks.md`
- [x] 第三阶段：import_sort / simplify / rewrite 完成  
  详见：`docs/fmt_phase3_transforms_tasks.md`
- [x] 第四阶段：CLI / Makefile / 工程集成完成  
  详见：`docs/fmt_phase4_cli_tasks.md`

### 推荐推进顺序（历史记录）

- [x] 先完成第一阶段，再进入第二阶段
- [x] 第二阶段完成后，再进入第三阶段
- [x] 第三阶段完成后，再进入第四阶段
- [x] 避免在主链路未稳定前并行铺开高级特性

当前四个阶段均已完成，具体勾选动作以下沉到各阶段 TodoList 为准。

---

## 文件结构

```text
lib/std/fmt/
├── fmt.uya              # 主入口和公开 API
├── formatter.uya        # 输出缓冲与缩进控制
├── tokenizer.uya        # 词法分析器
├── parser.uya           # 语法分析器
├── ast.uya              # AST 节点定义
├── printer.uya          # Pretty printer
├── comments.uya         # 注释收集与附着
├── positions.uya        # 位置信息与 span 定义
├── import_sort.uya      # use/import 排序
├── rewrite.uya          # AST rewrite 规则
├── simplify.uya         # AST 简化规则
└── rules.uya            # 打印和布局规则

tests/
├── test_fmt_api.uya
├── test_fmt_api_phase3.uya
├── test_fmt_api_rewrite.uya
├── test_fmt_api_simplify.uya
├── test_fmt_comment_collection.uya
├── test_fmt_comment_grouping.uya
├── test_fmt_comments.uya
├── test_fmt_comments_phase2.uya
├── test_fmt_doc_comment_attach.uya
├── test_fmt_formatter.uya
├── test_fmt_idempotent.uya
├── test_fmt_import_sort.uya
├── test_fmt_parser.uya
├── test_fmt_printer.uya
├── test_fmt_rewrite.uya
├── test_fmt_simplify.uya
├── test_fmt_tokenizer.uya
└── test_fmt_trailing_comment_attach.uya

tools/
└── fmt.uya              # CLI 工具
```

---

## 依赖关系

```text
lib/std/fmt/
    ├── positions.uya    # 无依赖，位置模型
    ├── ast.uya          # 依赖 positions
    ├── formatter.uya    # 无依赖，输出缓冲基础组件
    ├── tokenizer.uya    # 依赖 positions
    ├── parser.uya       # 依赖 tokenizer, ast, positions
    ├── comments.uya     # 依赖 ast, positions
    ├── rules.uya        # 无依赖，格式化规则定义
    ├── import_sort.uya  # 依赖 ast
    ├── rewrite.uya      # 依赖 ast
    ├── simplify.uya     # 依赖 ast
    ├── printer.uya      # 依赖 formatter, ast, comments, rules
    └── fmt.uya          # 依赖以上所有模块

tools/fmt.uya
    └── 依赖 lib/std/fmt/*
```

---

## 阶段摘要

### 第一阶段：最小 formatter 主链路

- [x] 打通 `tokenize -> parse -> print`
- [x] 完成最小 AST / parser / printer
- [x] 完成 `fmt.format()` / `fmt.is_formatted()`
- [x] 通过最小测试集与幂等测试
- 详见：`docs/fmt_phase1_minimal_tasks.md`

### 第二阶段：comments / positions 保持

- [x] 输出 comment token
- [x] 实现 comments 收集、归组、附着
- [x] printer 支持文档注释、独立行注释、行尾注释、块注释
- [x] 通过注释场景幂等测试
- 详见：`docs/fmt_phase2_comments_tasks.md`

### 第三阶段：AST 变换层

- [x] 完成 import_sort
- [x] 完成 simplify
- [x] 完成 rewrite
- [x] 通过 `format_with_options(...)` 暴露变换能力
- 详见：`docs/fmt_phase3_transforms_tasks.md`

### 第四阶段：CLI / 工程集成

- [x] 完成 `uya fmt`
- [x] 支持 `-w/-d/-l/-r/-s`
- [x] 支持文件、目录、stdin
- [x] 集成 `make fmt` / `make check-fmt`
- 详见：`docs/fmt_phase4_cli_tasks.md`
- 备注：CLI 运行级阻塞已解除，当前 CLI / Makefile / 最小集成验证已完成

---

## 推荐开发顺序

- [ ] Phase 1.1：formatter.uya（输出缓冲）
- [ ] Phase 1.2：positions.uya（位置模型）
- [ ] Phase 1.3：tokenizer.uya（词法分析）
- [ ] Phase 2.1：ast.uya（AST 定义）
- [ ] Phase 2.2：parser.uya（语法分析）
- [ ] Phase 3：printer.uya（表达式 / 语句 / 声明打印）
- [ ] Phase 4：comments.uya（注释附着与打印）
- [ ] Phase 5：import_sort.uya / simplify.uya / rewrite.uya
- [ ] Phase 6：fmt.uya 主入口与 options
- [ ] Phase 7：tools/fmt.uya CLI
- [ ] Phase 8：Makefile 集成

---

## 验收标准汇总

- [x] `formatter_write("hello")` 写入 5 字节
- [x] `Position` / `Span` 可表达源码范围
- [x] Token 列表正确解析
- [x] 完整源码可解析为 File AST
- [x] AST 可重新打印为稳定源码
- [x] 表达式 / 语句 / 声明格式化正确
- [x] 注释位置保持正确
- [x] Import 语句正确排序
- [x] simplify / rewrite 可选生效且幂等
- [x] `format(source)` 返回格式化结果
- [x] `format(format(x)) == format(x)`
- [x] CLI 工具可用
- [x] `-w/-d/-l/-r/-s` 行为符合预期

---

## 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| v0.1.0 | 2026-03-29 | 初始版本 |
| v0.1.1 | 2026-03-29 | 优化架构设计：明确 tokenizer 为手写，不依赖编译器 Lexer；增加量化验收标准 |
| v0.2.0 | 2026-04-25 | 按方案 B 重构文档：引入完整 parser/ast/comments/positions/rewrite/simplify 分层，整体架构对齐 gofmt |
| v0.2.5 | 2026-06-01 | 完成 Phase 4 运行级验收：修复 CLI 编译/运行阻塞，接入 `-w/-d/-l/-r/-s`、文件/目录/stdin、多路径参数，以及 `make fmt` / `make check-fmt` |
| v0.2.4 | 2026-04-25 | 启动 Phase 4 CLI 原型，完成 `tools/fmt.uya` 编译链路；运行级验证被 `arena_alloc` 写入即崩溃的底层 runtime 问题阻塞 |
| v0.2.3 | 2026-04-25 | 完成 Phase 3 最小变换链路：源码级 import_sort、最小文本级 simplify、最小文本级 rewrite，并通过 `format_with_options` 暴露 |
| v0.2.2 | 2026-04-25 | 完成 Phase 2 最小注释链路：显式 comment token、collect/group、最小 decl attach、doc/trailing comment 测试与幂等验证 |
| v0.2.1 | 2026-04-25 | 将主文档从长篇阶段正文精简为总看板 + 阶段摘要，详细执行项下沉到各阶段 TodoList |
