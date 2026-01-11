# Uya Mini 编译器

Uya Mini 是 Uya 语言的最小子集编译器，设计目标是能够编译自身，实现编译器的自举。

## 项目状态

🚧 **开发中** - 当前处于项目初始化阶段

## 核心特性

- **最小子集**：仅包含编译自身所需的最少功能
- **无堆分配**：编译器自身代码不使用堆分配，使用 Arena 分配器
- **结构体支持**：支持结构体定义、实例化和字段访问
- **LLVM C API**：使用 LLVM C API 直接从 AST 生成二进制代码
- **自举目标**：最终目标是用 Uya Mini 编译器编译自身

## 支持的语言特性

Uya Mini 支持以下语言特性：

- **基础类型**：`i32`、`bool`、`void`
- **结构体类型**：结构体定义和实例化
- **变量声明**：`const` 和 `var`
- **函数声明和调用**
- **基本控制流**：`if`、`while`
- **基本表达式**：算术运算、逻辑运算、比较运算、函数调用、结构体字段访问

不支持的特性：数组、指针、枚举、接口、错误处理、for循环、match表达式、模块系统等。

详细规范请参考 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md)。

## 项目结构

```
compiler-mini/
├── spec/
│   └── UYA_MINI_SPEC.md          # 语言规范
├── src/
│   ├── arena.h / arena.c          # Arena 分配器
│   ├── lexer.h / lexer.c          # 词法分析器
│   ├── parser.h / parser.c        # 语法分析器
│   ├── checker.h / checker.c      # 类型检查器
│   ├── codegen.h / codegen.c      # 代码生成器（LLVM C API）
│   ├── ast.h / ast.c              # AST 定义
│   └── main.c                     # 主程序
├── tests/                         # 测试用例
├── PROGRESS.md                    # 进度跟踪
├── TODO.md                        # 待办事项
├── CONTEXT_SWITCH.md              # 上下文切换指南
└── README.md                      # 本文件
```

## 开发规则

### 代码质量约束

- 所有代码必须使用**中文注释**
- 禁止使用堆分配（不能使用 `malloc`、`calloc`、`realloc`、`free`）
- 使用 Arena 分配器管理内存
- 使用 C99 标准
- 使用 LLVM C API 生成二进制代码

### 开发流程

1. 查看 `PROGRESS.md` 了解当前进度
2. 查看 `TODO.md` 了解详细任务
3. 参考 `spec/UYA_MINI_SPEC.md` 了解语言规范
4. 实现功能后更新 `PROGRESS.md`

详细规则请参考 [.cursorrules](.cursorrules)。

## 构建

（构建系统待实现）

```bash
make build    # 构建编译器
make test     # 运行测试
make clean    # 清理编译产物
```

## 依赖

- C99 编译器（GCC 或 Clang）
- LLVM 库（用于代码生成）

## 参考文档

- [语言规范](spec/UYA_MINI_SPEC.md) - Uya Mini 完整语言规范
- [开发规则](.cursorrules) - 开发规则和规范
- [上下文切换指南](CONTEXT_SWITCH.md) - 多上下文协作指南
- [待办事项](TODO.md) - 详细任务列表
- [进度跟踪](PROGRESS.md) - 当前实现进度

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

