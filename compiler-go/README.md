# Uya 编译器 (Go 版本)

Uya 编程语言的编译器，将 Uya 源代码编译为 C99 兼容代码。

这是从 C 编译器迁移到 Go 的版本，采用 TDD（测试驱动开发）方法实现。

## 项目状态

🚧 **开发中** - 正在进行从 C 到 Go 的迁移

## 代码质量约束

- 每个函数不超过 **150 行**
- 每个文件不超过 **1500 行**
- 遵循 TDD（测试驱动开发）方法
- 完整的测试覆盖

## 构建

```bash
make build
```

## 测试

```bash
make test
```

## 代码检查

```bash
make lint
```

## 项目结构

```
compiler-go/
├── cmd/uyac/          # 主程序
├── src/               # 源代码
│   ├── lexer/        # 词法分析器
│   ├── parser/       # 语法分析器
│   ├── checker/      # 类型检查器
│   ├── ir/           # 中间表示和生成器
│   └── codegen/      # 代码生成器
└── tests/            # 测试用例
```

## 开发

参考 `.cursorrules` 文件了解开发规范和规则。

详细的任务列表请查看 [TODO.md](TODO.md)。

