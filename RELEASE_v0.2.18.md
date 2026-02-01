# Uya v0.2.18 版本说明

**发布日期**：2026-02-01

本版本完成 **饱和运算**（`+|`、`-|`、`*|`）与 **包装运算**（`+%`、`-%`、`*%`）的 C 实现及自举编译器（uya-src）同步，并确认 **切片运算符**（`base[start:len]`）已完整支持。规范见 uya.md §10、§16。

---

## 核心亮点

### 1. 饱和运算（+|、-|、*|）

- **语义**：溢出时返回类型极值（上溢返回最大值，下溢返回最小值），不报错
- **操作数**：整数类型（i8/i16/i32/i64），两操作数类型必须一致
- **C 生成**：GCC/Clang `__builtin_add_overflow` / `__builtin_sub_overflow` / `__builtin_mul_overflow` + 语句表达式；乘法饱和用 if-else 分支避免嵌套三元运算符解析歧义

### 2. 包装运算（+%、-%、*%）

- **语义**：溢出时按模 2^n 包装（无符号语义），不报错
- **操作数**：整数类型（i8/i16/i32/i64），两操作数类型必须一致
- **C 生成**：`(T)((UT)(a) op (UT)(b))`，UT 为同宽无符号类型（如 i32 → uint32_t）

### 3. 切片运算符 [start:len]

- **语法**：`base[start:len]`，base 为数组或切片，结果为 `&[T]` 或 `&[T: N]`
- **状态**：C 与 uya-src 已支持，test_slice.uya 通过 `--c99` 与 `--uya --c99`

---

## 模块变更

### C 实现（compiler-mini/src）

| 模块 | 变更 |
|------|------|
| lexer.h / lexer.c | TOKEN_PLUS_PIPE、TOKEN_MINUS_PIPE、TOKEN_ASTERISK_PIPE、TOKEN_PLUS_PERCENT、TOKEN_MINUS_PERCENT、TOKEN_ASTERISK_PERCENT；`+`/`-`/`*` 后 peek `\|` 或 `%` 识别复合 token |
| parser.c | mul_expr 识别 *\|、*%；add_expr 识别 +\|、-\|、+%、-% |
| checker.c | 饱和/包装运算符：仅整数、两操作数类型一致，结果类型与操作数相同 |
| codegen/c99/expr.c | unsigned_type_for_wrapping、gen_saturate_limit；饱和用 __builtin_*_overflow，包装用 (T)((UT)(a) op (UT)(b)) |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| lexer.uya | 同上 6 个 TokenType 及识别逻辑 |
| parser.uya | mul_expr / add_expr 识别新 token |
| checker.uya | 饱和/包装运算符类型检查块 |
| codegen/c99/expr.uya | unsigned_type_for_wrapping、gen_saturate_limit_from_type_c；饱和/包装代码生成分支 |

### 规范与测试

- **spec/UYA_MINI_SPEC.md**：3.5 运算符补充饱和/包装运算符及语义
- **todo_mini_to_full.md**：饱和运算、包装运算、切片运算符三项勾选完成
- **tests/programs/test_saturating_wrapping.uya**：新增，覆盖饱和加/减/乘、包装加/减/乘及无溢出情形

---

## 测试验证

- **C 版编译器（`--c99`）**：test_saturating_wrapping.uya、test_slice.uya 通过
- **自举版编译器（`--uya --c99`）**：test_saturating_wrapping.uya、test_slice.uya 通过
- **自举构建**：`./compile.sh --c99 -e` 成功
- **自举对比**：`./compile.sh --c99 -b` 一致（C 版与自举版生成 C 完全一致）

---

## 文件变更统计（自 v0.2.17 以来）

**C 实现**：
- `compiler-mini/src/lexer.h` — 6 个新 Token 类型
- `compiler-mini/src/lexer.c` — +| -| *| +% -% *% 识别
- `compiler-mini/src/parser.c` — mul_expr / add_expr 新 token
- `compiler-mini/src/checker.c` — 饱和/包装类型检查
- `compiler-mini/src/codegen/c99/expr.c` — 饱和/包装代码生成及辅助函数

**自举实现（uya-src）**：
- `compiler-mini/uya-src/lexer.uya` — 6 个 TokenType 及识别
- `compiler-mini/uya-src/parser.uya` — mul_expr / add_expr 新 token
- `compiler-mini/uya-src/checker.uya` — 饱和/包装类型检查
- `compiler-mini/uya-src/codegen/c99/expr.uya` — unsigned_type_for_wrapping、gen_saturate_limit_from_type_c、饱和/包装分支

**规范与文档**：
- `compiler-mini/spec/UYA_MINI_SPEC.md` — 3.5 运算符与饱和/包装语义
- `compiler-mini/todo_mini_to_full.md` — 三项勾选完成

**测试**：
- `compiler-mini/tests/programs/test_saturating_wrapping.uya` — 新增

---

## 版本对比

### v0.2.17 → v0.2.18 变更

- **新增**：
  - ✅ 饱和运算：`+|`、`-|`、`*|`（C + uya-src）
  - ✅ 包装运算：`+%`、`-%`、`*%`（C + uya-src）
  - ✅ 切片运算符 `[start:len]` 在文档中标记为已实现

- **非破坏性**：纯新增运算符与规范更新，无 API 或既有语法变更

---

## 使用示例

### 饱和与包装运算

```uya
fn main() i32 {
    const max_i32: i32 = 2147483647;
    const min_i32: i32 = (-2147483647 - 1);

    // 饱和加法：溢出时钳位到极值
    const a: i32 = 2000000000;
    const b: i32 = 2000000000;
    const sat_add: i32 = a +| b;   // 2147483647
    if sat_add != max_i32 { return 1; }

    // 包装加法：溢出时模 2^32
    const w1: i32 = max_i32;
    const w2: i32 = 1;
    const wrap_add: i32 = w1 +% w2;  // INT32_MIN
    if wrap_add != min_i32 { return 2; }

    return 0;
}
```

### 切片语法（已有）

```uya
fn main() i32 {
    var arr: [i32: 10] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const s: &[i32] = arr[0:5];
    if @len(s) != 5 { return 1; }
    return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **类型转换 as!**：强转返回 !T，需 try/catch
- **内存安全证明**：数组越界/空指针/未初始化/溢出/除零
- **原子类型**：atomic T、&atomic T

---

## 相关资源

- **语言规范**：`uya.md`（§10 运算符与优先级、§16 溢出与安全）
- **实现规范**：`compiler-mini/spec/UYA_MINI_SPEC.md`（3.5 运算符）
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_saturating_wrapping.uya`、`test_slice.uya`

---

**本版本完成饱和运算与包装运算的 C 实现及 uya-src 同步，并确认切片运算符已完整支持。**
