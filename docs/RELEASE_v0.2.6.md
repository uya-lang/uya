# Uya v0.2.6 版本说明

**发布日期**：2026-02-01

本版本在 v0.2.4 基础上移除 **编译时 stderr 调试输出**，使 C 版与自举版编译器在正常编译时不再向终端打印「词法分析阶段」「语法分析阶段」等阶段提示及文件信息，输出更简洁。

---

## 核心亮点

### 移除编译时调试输出

- **C 版（main.c）**：删除 `fprintf(stderr, "=== 词法分析阶段 ===\n")`、`fprintf(stderr, "文件: %s (大小: %d 字节)\n", ...)`、`fprintf(stderr, "=== 语法分析阶段 ===\n")`。
- **自举版（uya-src/main.uya）**：同步删除上述三处调试输出，与 C 版行为一致。
- **效果**：编译单文件或多文件时，stderr 仅保留错误信息，无阶段提示干扰。

---

## 主要变更

### 与 v0.2.4 的差异

| 项目 | v0.2.4 | v0.2.6 |
|------|--------|--------|
| 编译时 stderr | 打印「词法分析阶段」「语法分析阶段」「文件: … 字节」 | **不再打印**，仅错误时输出 |
| main.c / main.uya | 含上述 fprintf | **已删除**，行为一致 |

---

## 实现范围

| 文件 | 变更摘要 |
|------|----------|
| compiler-mini/src/main.c | 删除词法/语法阶段及文件信息的 3 处 fprintf |
| compiler-mini/uya-src/main.uya | 同步删除上述 3 处 fprintf |

---

## 验证

```bash
cd compiler-mini

# C 版：编译时无阶段输出
make build && ./uya-mini -o /dev/null --c99 tests/programs/test_simple.uya

# 自举版：同样无阶段输出
./tests/run_programs.sh --uya --c99 tests/programs/test_simple.uya
```

正常编译时终端仅显示可能的错误信息，无「=== 词法分析阶段 ===」等重复输出。

---

## 已知限制与后续方向

- **本版本**：仅移除调试输出，未新增语言特性或修复其它问题。
- **后续计划**：按 `compiler-mini/todo_mini_to_full.md` 继续错误处理、defer/errdefer、切片、match 等阶段，并保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 开发与测试的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.6
- **基于**：v0.2.4
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
