# Uya v0.2.2 版本说明

**发布日期**：2026-01-31

本版本在 v0.2.1 基础上完成 **自举编译器（uya-src）元组支持**，与 C 编译器行为对齐。元组类型 `(T1, T2, ...)`、元组字面量、`.0`/`.1` 访问及解构声明在 `--uya --c99` 下均已通过测试，自举对比保持一致。

---

## 核心亮点

### 自举编译器元组完整支持

- **元组类型**：`(T1, T2, ...)` 在 uya-src 的 parser、checker、codegen 中完整实现，与 C 版一致映射为 C99 匿名结构体 `struct { T0 f0; T1 f1; ... }`。
- **元组字面量**：`(e1, e2, ...)` 解析与类型推断、C99 复合字面量生成已在自举中打通。
- **成员访问**：`.0`、`.1` 等元组下标在词法上接受 `NUMBER`，代码生成输出 `.f0`、`.f1`。
- **解构声明**：`const (a, b) = expr;` 与 `var (x, _) = expr;` 在自举中支持，生成逐元素局部变量并登记符号表。

至此，阶段「1. 基础类型与字面量」在 C 与 uya-src 两套实现中均已完成（整数类型、类型极值、元组、重复数组字面量）。

---

## 主要变更

### 元组在自举中的实现范围

| 能力           | C 编译器 | 自举编译器（本版本） |
|----------------|----------|------------------------|
| 元组类型 `(T1, T2, ...)` | ✓        | ✓                      |
| 元组字面量 `(e1, e2, ...)` | ✓        | ✓                      |
| 下标访问 `.0` / `.1` / … | ✓        | ✓                      |
| 解构 `const (a, b) = expr` | ✓        | ✓                      |

### 与 v0.2.1 的差异

| 项目       | v0.2.1 | v0.2.2 |
|------------|--------|--------|
| 元组（C）  | 已支持 | 不变   |
| 元组（自举） | 未同步，`--uya --c99` 跑元组测试会失败 | **已同步**，`test_tuple.uya` 在 `--c99` 与 `--uya --c99` 下均通过 |

---

## 实现范围（自举 uya-src）

| 模块       | 变更摘要 |
|------------|----------|
| AST        | 新增 `AST_TUPLE_LITERAL`、`AST_TYPE_TUPLE`、`AST_DESTRUCTURE_DECL` 及对应扁平字段 |
| Parser     | 类型解析 `(T1, T2, ...)`；primary 解析 `(e1, e2, ...)`；const/var 后解构分支；`.0`/`.1` 接受 NUMBER |
| Checker    | `TYPE_TUPLE`、`type_equals`/`type_from_ast`、元组字面量推断、解构校验、元组成员访问 `.0`/`.1` |
| Codegen    | `c99_type_to_c` 元组、`get_c_type_of_expr`、元组字面量/解构/元组变量初始化的 C99 生成，成员访问 `.f0`/`.f1` |
| Utils      | 字符串常量收集支持 `AST_TUPLE_LITERAL`、`AST_DESTRUCTURE_DECL` |

---

## 验证

### 测试

```bash
cd compiler-mini

# C 版编译器
./tests/run_programs.sh --c99 test_tuple.uya

# 自举编译器
./tests/run_programs.sh --uya --c99 test_tuple.uya
```

### 自举对比

```bash
cd compiler-mini/uya-src
./compile.sh --c99 -b    # C 输出与自举输出逐字节一致 ✓
```

所有相关测试需同时通过 `--c99` 与 `--uya --c99`（见 `.cursorrules` 验证流程）。

---

## 已知限制与后续方向

- **本版本**：仅完成自举侧元组与 C 对齐，未新增语言特性。
- **后续计划**：按 `compiler-mini/todo_mini_to_full.md` 继续错误处理、defer/errdefer、切片、match 等阶段，并保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 自举元组实现、测试与文档工作的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.2
- **基于**：v0.2.1
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
