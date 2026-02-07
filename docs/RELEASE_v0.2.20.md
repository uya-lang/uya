# Uya v0.2.20 版本说明

**发布日期**：2026-02-02

本版本完成 **字符串插值 printf 脱糖**：当插值仅作 `printf`/`fprintf` 格式参数时，脱糖为单次 `printf(fmt, ...)`，无中间缓冲。规范见 uya.md §17。

---

## 核心亮点

### 1. 插值仅作 printf 格式参数时的脱糖优化

- **语义**：`printf("${x} world\n")` 或 `fprintf(stream, "n=${n}\n")` 不再生成临时缓冲区与多次 `sprintf` 调用
- **生成**：直接输出 `printf("%d world\n", x)` 或 `fprintf(stream, "n=%d\n", n)`，单次调用，零中间缓冲
- **适用**：`printf` 单参且为插值、`fprintf` 双参且第二参为插值；支持 `:spec` 格式说明符（如 `%.2f`、`#06x`）

### 2. emit_printf_fmt_inline

- **实现**：将插值段（文本 + 表达式格式占位符）直接构建为 C 格式串并内联输出
- **优点**：不依赖常量收集阶段顺序，避免 collect/emit 时序问题
- **转义**：文本段中 `%` 正确转义为 `%%`

### 3. 向后兼容

- **非直接 printf 用法**：插值用于变量初始化、数组初始化、或作为其他函数实参时，仍使用原有临时缓冲方案
- **无破坏性**：现有 test_string_interp.uya 等用例行为不变，输出一致

---

## 模块变更

### C 实现（compiler-mini/src）

| 模块 | 变更 |
|------|------|
| codegen/c99/utils.c | `emit_printf_fmt_inline`：从插值构建格式串并直接输出；`build_and_add_printf_fmt_from_interp` 保留供其他用途 |
| codegen/c99/internal.h | `emit_printf_fmt_inline` 声明 |
| codegen/c99/expr.c | AST_CALL_EXPR 中检测 `printf(interp)`、`fprintf(stream, interp)`，走直接路径调用 `emit_printf_fmt_inline` 生成单次 printf |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| codegen/c99/utils.uya | `emit_printf_fmt_inline`：与 C 版等价逻辑，内联输出格式串 |
| codegen/c99/expr.uya | AST_CALL_EXPR 中 printf/fprintf 插值脱糖，调用 `emit_printf_fmt_inline` |

### 规范与测试

- **todo_mini_to_full.md**：字符串插值章节补充「插值仅作 printf/fprintf 格式参数时脱糖为单次 printf(fmt, ...)、无中间缓冲」
- **test_string_interp.uya**：沿用现有 19 条用例，均通过

---

## 测试验证

- **C 版编译器（`--c99`）**：test_string_interp.uya 通过
- **自举版编译器（`--uya --c99`）**：test_string_interp.uya 通过
- **自举对比**：`./compile.sh --c99 -b` 一致（C 版与自举版生成 C 完全一致）

---

## 文件变更统计（自 v0.2.19 以来）

**C 实现**：
- `compiler-mini/src/codegen/c99/utils.c` — `emit_printf_fmt_inline`，移除 collect 阶段 printf 格式串预收集
- `compiler-mini/src/codegen/c99/internal.h` — `emit_printf_fmt_inline` 声明
- `compiler-mini/src/codegen/c99/expr.c` — printf/fprintf 插值直接路径

**自举实现（uya-src）**：
- `compiler-mini/uya-src/codegen/c99/utils.uya` — `emit_printf_fmt_inline`，移除 collect 阶段 printf 格式串预收集
- `compiler-mini/uya-src/codegen/c99/expr.uya` — printf/fprintf 插值直接路径

**文档**：
- `compiler-mini/todo_mini_to_full.md` — 插值 printf 脱糖描述更新

---

## 版本对比

### v0.2.19 → v0.2.20 变更

- **优化**：
  - ✅ 字符串插值作 `printf`/`fprintf` 格式参数时脱糖为单次 `printf(fmt, ...)`，无中间缓冲
  - ✅ `emit_printf_fmt_inline` 内联输出格式串，避免常量收集顺序依赖

- **非破坏性**：纯优化，输出 C 代码语义不变，测试全通过

---

## 使用示例

### 优化前（示意）

```c
char __uya_interp_0[32];
_off_0 += sprintf(__uya_interp_0 + _off_0, "%d", v);
memcpy(__uya_interp_0 + _off_0, " world\n", 7);
_off_0 += 7;
__uya_interp_0[_off_0] = '\0';
printf("%s", (uint8_t *)__uya_interp_0);
```

### 优化后

```uya
// Uya 源码
printf("${v} world\n");
```

```c
// 生成 C 代码
printf("%d world\n", v);
```

### 带格式说明符

```uya
printf("hex=${x:#06x}, pi=${pi:.2f}\n");
```

```c
printf("hex=%#06x, pi=%.2f\n", x, pi);
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **内存安全证明**：数组越界/空指针/未初始化/溢出/除零
- **原子类型**：atomic T、&atomic T
- **模块系统**：目录即模块、export/use 语法
- **原始字符串**：`` `...` `` 无转义

---

## 相关资源

- **语言规范**：`uya.md`（§17 字符串插值）
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_string_interp.uya`

---

**本版本完成字符串插值在 printf/fprintf 格式参数场景下的脱糖优化，生成单次 printf 调用，无中间缓冲。**
