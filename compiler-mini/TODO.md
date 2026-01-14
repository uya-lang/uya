# Uya Mini 编译器自举任务索引

本文档提供各阶段任务的索引，详细任务请查看对应的 `TODO_phase*.md` 文件。

## 任务概览

| 阶段 | 模块 | 优先级 | 工作量估算 | 详细任务文档 |
|------|------|--------|-----------|-------------|
| 阶段0 | 准备工作 | P0 | 1-2 小时 | [TODO_phase0.md](TODO_phase0.md) |
| 阶段1 | Arena | P0 | 1-2 小时 | [TODO_phase1.md](TODO_phase1.md) |
| 阶段2 | AST | P0 | 2-3 小时 | [TODO_phase2.md](TODO_phase2.md) |
| 阶段3 | Lexer | P0 | 3-4 小时 | [TODO_phase3.md](TODO_phase3.md) |
| 阶段4 | Parser | P0 | 8-12 小时 | [TODO_phase4.md](TODO_phase4.md) |
| 阶段5 | Checker | P0 | 6-8 小时 | [TODO_phase5.md](TODO_phase5.md) |
| 阶段6 | CodeGen | P0 | 10-15 小时 | [TODO_phase6.md](TODO_phase6.md) |
| 阶段7 | Main | P0 | 2-3 小时 | [TODO_phase7.md](TODO_phase7.md) |

**总计**：约 33-49 小时（不包括整合和测试）

## 阶段说明

### 阶段0：准备工作
创建字符串辅助函数模块和 LLVM API 声明文件，为后续翻译工作做准备。

### 阶段1：基础模块（Arena）
翻译 Arena 分配器，所有其他模块都依赖它。

### 阶段2：AST 数据结构
翻译 AST 数据结构定义，Parser、Checker、CodeGen 都依赖它。

### 阶段3：词法分析器
翻译词法分析器，Parser 依赖它。

### 阶段4：语法分析器
翻译语法分析器，代码量最大（2,556行），逻辑复杂。

### 阶段5：类型检查器
翻译类型检查器，代码量大（1,678行），逻辑复杂。

### 阶段6：代码生成器
翻译代码生成器，代码量最大（3,456行），逻辑最复杂。

### 阶段7：主程序
翻译主程序，编译器入口点。

## 依赖关系

```
阶段0（准备工作）
  ↓
阶段1（Arena）
  ↓
阶段2（AST）
  ↓
阶段3（Lexer） → 阶段4（Parser）
  ↓              ↓
阶段5（Checker） → 阶段6（CodeGen）
  ↓              ↓
阶段7（Main）
```

## 使用说明

1. **查看总体进度**：查看 `PROGRESS.md`
2. **查看当前阶段任务**：查看对应的 `TODO_phase*.md` 文件
3. **了解详细计划**：查看 `BOOTSTRAP_PLAN.md`
4. **了解语言规范**：查看 `spec/UYA_MINI_SPEC.md`

## 注意事项

- 所有阶段都是 P0 优先级，必须按顺序完成
- 每个阶段完成后，立即更新 `PROGRESS.md`
- 遵循 TDD 流程：先写测试，再实现功能
- 功能必须完整实现，不能简化

