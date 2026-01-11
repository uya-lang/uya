# Uya Mini 编译器

Uya Mini 是 Uya 语言的最小子集编译器，设计目标是能够编译自身，实现编译器的自举。

## 项目状态

🚧 **开发中** - 当前进度：阶段2完成，阶段3进行中

详细进度请参考 [PROGRESS.md](PROGRESS.md)

## 核心特性

- **最小子集**：仅包含编译自身所需的最少功能
- **无堆分配**：编译器自身代码不使用堆分配，使用 Arena 分配器
- **结构体支持**：支持结构体定义、实例化和字段访问
- **LLVM C API**：使用 LLVM C API 直接从 AST 生成二进制代码
- **自举目标**：最终目标是用 Uya Mini 编译器编译自身

## 快速开始

### 构建

```bash
make test-arena    # 运行 Arena 测试
make clean         # 清理编译产物
```

### 依赖

- C99 编译器（GCC 或 Clang）
- LLVM 库（用于代码生成）

## 文档

- [语言规范](spec/UYA_MINI_SPEC.md) - Uya Mini 完整语言规范
- [开发规则](.cursorrules) - 开发规则和规范
- [待办事项](TODO.md) - 实现任务索引
- [进度跟踪](PROGRESS.md) - 当前实现进度
- [上下文切换指南](CONTEXT_SWITCH.md) - 多上下文协作指南

## 项目结构

```
compiler-mini/
├── spec/                          # 语言规范
│   ├── UYA_MINI_SPEC.md          # 语言规范文档
│   └── examples/                  # 示例代码
├── src/                           # 源代码
│   ├── arena.h / arena.c          # Arena 分配器
│   ├── lexer.h / lexer.c          # 词法分析器
│   ├── parser.h / parser.c        # 语法分析器
│   ├── checker.h / checker.c      # 类型检查器
│   ├── codegen.h / codegen.c      # 代码生成器
│   ├── ast.h / ast.c              # AST 定义
│   └── main.c                     # 主程序
├── tests/                         # 测试用例
└── TODO_phase*.md                 # 分阶段待办事项
```

## 相关项目

- [Uya 语言规范](../uya.md) - Uya 语言完整规范
- [Uya 编译器](../compiler/) - Uya 完整编译器（C 实现）
- [Uya 编译器 Go 版本](../compiler-go/) - Uya 编译器 Go 迁移版本

## 许可证

（待添加）

## 版本信息

- **版本**：0.1.0（开发中）
- **创建日期**：2026-01-11
- **目标**：实现 Uya Mini 编译器的自举
