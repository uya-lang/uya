# Uya v0.2.0 版本说明

**发布日期**：2026-01-31

本版本在 v0.1.x 基础上完成 **规范同步**（内置函数以 `@` 开头）与 **基础类型扩展**（扩展整数类型与类型极值 `@max`/`@min`），是 Uya Mini 向完整 Uya 迈进的第一个里程碑。C 编译器与自举编译器已同步实现，并通过自举对比验证。

---

## 核心亮点

### 规范同步：内置函数以 @ 开头

- **统一语法**：所有内置函数均以 `@` 开头，与完整 Uya 规范（uya.md 0.33）一致。
- **支持的内置**：`@sizeof`（类型/表达式大小）、`@alignof`（对齐）、`@len`（数组长度）、`@max`、`@min`（整数类型极值）。
- **迁移**：原有无前缀写法已废弃；测试与示例已全部迁移为 `@sizeof`、`@alignof`、`@len`、`@max`、`@min`。

### 基础类型扩展

- **扩展整数类型**：在原有 `i32`、`usize`、`byte` 基础上，新增 `i8`、`i16`、`i64`、`u8`、`u16`、`u32`、`u64`。
- **类型极值**：`@max`、`@min` 内置函数，编译期常量，类型从上下文推断（常量注解、表达式操作数、return 返回类型）。
- **C99 映射**：与规范一致，生成 `int8_t`/`uint8_t`、`int16_t`/`uint16_t`、`int32_t`/`uint32_t`、`int64_t`/`uint64_t` 等标准类型。

---

## 主要变更

### 内置函数 @ 语法

| 内置       | 说明 |
|------------|------|
| `@sizeof(expr)` / `@sizeof(T)` | 表达式或类型大小 |
| `@alignof(T)`                  | 类型对齐值 |
| `@len(arr)`                    | 数组长度（编译期常量） |
| `@max`                         | 当前上下文整数类型的最大值 |
| `@min`                         | 当前上下文整数类型的最小值 |

`@max`、`@min` 无参数，类型由以下方式推断：常量定义从类型注解（如 `const x: i32 = @max`）；表达式中从操作数类型推断；return 从函数返回类型推断。

### 支持的整数类型（本版本）

| 类型   | 大小 | C99 映射    |
|--------|------|-------------|
| `i8`   | 1 B  | `int8_t`    |
| `i16`  | 2 B  | `int16_t`   |
| `i32`  | 4 B  | `int32_t`   |
| `i64`  | 8 B  | `int64_t`   |
| `u8`   | 1 B  | `uint8_t`   |
| `u16`  | 2 B  | `uint16_t`  |
| `u32`  | 4 B  | `uint32_t`  |
| `usize`| 4/8 B| `uintptr_t` |
| `u64`  | 8 B  | `uint64_t`  |
| `byte` | 1 B  | `uint8_t`   |

`@max`、`@min` 支持上述所有整数类型。

---

## 实现范围

| 模块     | C 编译器 | 自举编译器 |
|----------|----------|------------|
| 规范     | UYA_MINI_SPEC 内置 @、整数类型、@max/@min | — |
| 词法     | `@` 与 TOKEN_AT_IDENTIFIER（@sizeof、@alignof、@len、@max、@min） | ✓ |
| AST      | 沿用 SIZEOF/ALIGNOF/LEN/INT_LIMIT 节点，primary 支持 @ 调用形式 | ✓ |
| 语法     | primary_expr 支持 @max、@min（无参）及 @sizeof/@alignof/@len 调用 | ✓ |
| 类型检查 | 扩展整数 TypeKind，@max/@min 类型推断与校验 | ✓ |
| C99 后端 | 扩展类型映射与 @max/@min 极值字面量生成 | ✓ |

---

## 与 v0.1.2 的差异

| 项目       | v0.1.2 | v0.2.0 |
|------------|--------|--------|
| 内置函数   | 无前缀或关键字形式 | **统一为 @ 前缀**：@sizeof、@alignof、@len、@max、@min |
| 整数类型   | i32、usize、byte（及已有 f32、f64） | 同上 + **i8、i16、i64、u8、u16、u32、u64** |
| 类型极值   | 无     | **@max、@min**（编译期常量，上下文推断类型） |

---

## 验证

### 测试

```bash
# C 版编译器
./tests/run_programs.sh --c99 test_int_types.uya
./tests/run_programs.sh --c99 test_max_min.uya

# 自举编译器
./tests/run_programs.sh --uya --c99 test_int_types.uya
./tests/run_programs.sh --uya --c99 test_max_min.uya
```

### 自举对比

```bash
cd compiler-mini/uya-src
./compile.sh --c99 -b    # C 输出与自举输出逐字节一致 ✓
```

所有测试用例需同时通过 `--c99` 与 `--uya --c99`（见 `.cursorrules` 验证流程）。

---

## 已知限制与后续方向

- **本版本未包含**：元组类型、重复数组字面量 `[value: N]`、错误处理、defer/errdefer、切片、match 等（见 `compiler-mini/todo_mini_to_full.md`）。
- **后续计划**：在稳定 0.2.0 基础上，按待办顺序继续实现错误处理、defer/errdefer、切片等特性。

---

## 致谢

感谢所有参与 Uya 规范同步与 Uya Mini 类型扩展、测试与文档工作的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.0
- **基于**：v0.1.2
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
