# Uya v0.2.4 版本说明

**发布日期**：2026-01-31

本版本在 v0.2.3 基础上完成 **自举编译器（uya-src）字符串插值与 printf 结合**，与 C 编译器行为对齐；并修复自举时 Arena 不足导致的解析失败、以及单参 printf 的 -Wformat-security 警告。

---

## 核心亮点

### 自举编译器字符串插值完整支持

- **插值语法**：`"a${x}"`、`"a${x:format}"` 在 uya-src 的 Lexer（TOKEN_INTERP_*、string_mode/interp_depth/reading_spec）、AST（AST_STRING_INTERP、ASTStringInterpSegment）、Parser、Checker、Codegen 中已与 C 版对齐。
- **多段与格式说明符**：多段文本+插值、`:spec`（如 `#06x`、`.2f`、`ld`、`zu`）、连续插值、变量/数组初始化、表达式插值（如 `${a+b}`）均在 `--uya --c99` 下通过。
- **类型支持**：i32/u32/i64/f32/f64/usize/u8 等类型插值及 checker 宽度计算（computed_size）已同步。
- **自举对比通过**：`./compile.sh --c99 -b` 下 C 编译器与自举编译器生成的 C 文件完全一致。

### 自举失败根因与修复

- **根因**：18 个文件共用一个 Arena，解析到 main.uya 时实参列表扩展需约 648 字节，arena_alloc 返回 null，parser 在逗号处失败并误报「意外的 token ','」。
- **修复**：arena_alloc 失败时向 stderr 打印「错误: Arena 分配失败（内存不足，需要 N 字节）」并 exit(1)；uya-src 的 ARENA_BUFFER_SIZE 从 32MB 增至 48MB，自举顺利通过。

### 单参 printf -Wformat-security 消除

- **问题**：自举生成的 C 中 `printf(interp_buf)` 或 `printf(&msg[0])` 触发 -Wformat-security。
- **修复**：uya-src 的 codegen（expr.uya）在单参数 printf 时生成 `printf("%s", arg)`，与 C 版 codegen 行为一致，相关测试编译无警告。

---

## 主要变更

### 字符串插值在自举中的实现范围

| 能力 | C 编译器 | 自举编译器（本版本） |
|------|----------|------------------------|
| 多段 `"a${x}b${y}"` | ✓ | ✓ |
| 格式说明符 `:spec`（#06x、.2f、ld、zu 等） | ✓ | ✓ |
| 连续插值 `${x}${y}` | ✓ | ✓ |
| 变量/数组初始化 `const msg = "..."` | ✓ | ✓ |
| 表达式插值 `${a+b}` | ✓ | ✓ |
| printf 直接实参 | ✓ | ✓ |
| 单参 printf 生成 `printf("%s", arg)` | ✓ | ✓ |

### 与 v0.2.3 的差异

| 项目 | v0.2.3 | v0.2.4 |
|------|--------|--------|
| 字符串插值（C） | 已支持 | 不变 |
| 字符串插值（自举） | 未同步，自举对比失败 | **已同步**，test_string_interp*.uya 在 `--c99` 与 `--uya --c99` 下均通过 |
| 自举对比 --c99 -b | 失败（main.uya:279 意外 token ','） | **通过**，Arena 报错退出 + 48MB |
| 单参 printf 警告 | 自举生成 C 有 -Wformat-security | **消除**，codegen 生成 `printf("%s", arg)` |

---

## 实现范围（自举 uya-src）

| 模块 | 变更摘要 |
|------|----------|
| Lexer | TOKEN_INTERP_*、string_mode/interp_depth/reading_spec/pending_interp_open、read_string_char_into_buffer、next_token 插值逻辑 |
| AST | AST_STRING_INTERP、ASTStringInterpSegment |
| Parser | primary_expr 中 INTERP_TEXT/INTERP_OPEN 解析、parser_peek 禁用 string_mode |
| Checker | checker_interp_format_max_width、AST_STRING_INTERP 类型与 computed_size |
| Codegen | c99_emit_string_interp_fill、collect 阶段预收集格式串、call 实参临时缓冲、stmt 变量初始化；**单参 printf 生成 "%s", arg** |
| Arena | arena_alloc 失败时 fprintf+exit(1)；extern_decls 增加 exit |
| main.uya | ARENA_BUFFER_SIZE 增至 48MB |

---

## 修复与测试

### Arena 与自举

- **arena.uya**：arena_alloc 在 arena/buffer 为 null 或空间不足时打印错误并 exit(1)，不再静默返回 null。
- **extern_decls.uya**：新增 `extern fn exit(code: i32) void;`。
- **main.uya**：ARENA_BUFFER_SIZE = 48 * 1024 * 1024（48MB），满足自举 18 个文件需求。

### Codegen 警告

- **uya-src/codegen/c99/expr.uya**：生成普通调用时，若被调函数为 `printf` 且实参个数为 1，在 `printf(` 后先输出 `"%s", `，再输出唯一实参，生成 `printf("%s", arg)`，消除 -Wformat-security。

### 测试用例

- **test_string_interp.uya**：19 条用例（含表达式插值 `${a+b}`），与 test_string_interp_minimal、test_string_interp_one、test_string_interp_simple 均通过 `--c99` 与 `--uya --c99`。

### 验证

```bash
cd compiler-mini

# C 版编译器
./tests/run_programs.sh --c99 test_string_interp.uya test_string_interp_minimal.uya test_string_interp_one.uya test_string_interp_simple.uya

# 自举编译器（无 -Wformat-security 警告）
./tests/run_programs.sh --uya --c99 test_string_interp.uya test_string_interp_minimal.uya test_string_interp_one.uya test_string_interp_simple.uya
```

### 自举对比

```bash
cd compiler-mini/uya-src
./compile.sh --c99 -b    # C 输出与自举输出完全一致 ✓
```

所有相关测试需同时通过 `--c99` 与 `--uya --c99`（见 `.cursorrules` 验证流程）。

---

## 已知限制与后续方向

- **本版本**：完成自举侧字符串插值与 C 对齐、自举对比通过、单参 printf 警告消除；未新增语言特性。
- **后续计划**：按 `compiler-mini/todo_mini_to_full.md` 继续错误处理、defer/errdefer、切片、match 等阶段，并保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 自举字符串插值实现、Arena 修复与测试的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.4
- **基于**：v0.2.3
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
