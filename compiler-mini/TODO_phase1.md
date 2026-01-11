# 阶段1：项目初始化 ✅

## 1.1 创建项目结构

- [x] 创建 `compiler-mini/` 目录
- [x] 创建 `spec/` 目录
- [x] 创建语言规范文档 `spec/UYA_MINI_SPEC.md`
- [x] 创建 `src/` 目录
- [x] 创建 `tests/` 目录

## 1.2 创建开发文档

- [x] 创建 `.cursorrules` 规则文件
- [x] 创建 `CONTEXT_SWITCH.md` 上下文切换指南
- [x] 创建 `TODO.md` 待办事项文档
- [x] 创建 `PROGRESS.md` 进度跟踪文档
- [x] 创建 `README.md` 项目说明文档

## 1.3 配置构建系统

- [x] 创建 `Makefile`
  - [x] 配置 C99 编译选项（`-Wall -Wextra -pedantic -std=c99`）
  - [ ] 配置 LLVM 库链接（`-llvm` 或具体库路径）（待 CodeGen 阶段实现）
  - [x] `make test-arena` - 运行 Arena 测试
  - [x] `make clean` - 清理编译产物
  - [ ] `make build` - 构建编译器（待主程序阶段实现）

