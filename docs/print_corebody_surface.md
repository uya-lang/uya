# print/println CoreBody Surface Contract

**状态**: Phase 9B print/println surface 冻结合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, leaf 5)
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §3 (AST_PRINT, AST_PRINTLN)

---

## 1. 范围

本文件冻结 `AST_PRINT` / `AST_PRINTLN`（`@print(expr)` / `@println(expr)`）从 AST 到
CoreBody、再到 PortableMIR 的 surface 形状。范围包含：

- AST 节点构造（`src/ast.uya` `ASTNode.print_expr` 字段）。
- 类型推断（`src/exec/lower.uya:512` `exec_lower_expr_type`，第 542 行）。
- CoreBody statement/expression surface。
- PortableMIR shape 与 lowering feature mask。
- runtime helper ABI（`uya_write` / `uya_print_i32` / `uya_print_str` / `uya_println_*`）。
- 表达式位置返回值（`i32`，已写入字节数）。
- 字符串字面量、字符串插值、标量格式化的保留语义。

本文件是合同。任何对 `AST_PRINT` / `AST_PRINTLN` 的 lowering、verifier、emitter 改动必须
与本文件保持一致；不一致必须先更新本文件再改实现。

---

## 2. AST 层

- `AST_PRINT` / `AST_PRINTLN` 是 expression-form 节点；`src/ast.uya` 的
  `ASTNode.print_expr: &ASTNode` 字段保存被打印的内部表达式。
- 类型在 `src/exec/lower.uya` 中统一推断为 `i32`（已写入字节数），与 C99 backend
  `printf`/`uya_write` 的返回值一致。
- AST 节点可以出现在 expression statement 位置（`AST_EXPR_STMT`）或 expression
  位置（`const x: i32 = @println("hi");`）；两种位置必须生成等价代码，区别只在
  是否消费返回值。
- `@print` 不附加换行符；`@println` 在被打印内容之后追加 `'\n'`（1 字节）。

---

## 3. CoreBody Surface

### 3.1 语句形式

`@print(expr);` 或 `@println(expr);` 落到 `CORE_STMT_KIND_EXPR` 节点，节点的
`expr_id` 指向 `CORE_EXPR_KIND_CALL` 表达式。`flags` 不设置任何特殊 bit，复用
既有 `CORE_STMT_KIND_EXPR` 路径。

### 3.2 表达式形式

`const x: i32 = @println("hi");` 也走同一 `CORE_STMT_KIND_EXPR` + 内部
`CORE_EXPR_KIND_CALL` 路径，区别只是被外层 `AST_VAR_DECL` 消费。

### 3.3 print helper 协议

被打印表达式被归类为以下分支，每种分支对应一个 `CORE_EXPR_KIND_CALL` target：

| print_expr 形态 | call target | 返回值 |
|-----------------|-------------|--------|
| `AST_STRING` 字面量 | `uya_write_str(fd, ptr, len)` 或 packed `__uya_print_str` | `i32` 已写入字节数 |
| `AST_STRING_INTERP` 段 | `uya_write_str(fd, ptr, len)`（interp 缓冲区在 lowering 阶段物化） | `i32` |
| `AST_NUMBER` / `AST_INT_LIMIT` | `uya_print_i32(value)` | `i32` |
| `AST_FLOAT` | `uya_print_f64(value)` | `i32` |
| `AST_BOOL` | `uya_print_bool(value)` | `i32` |
| 其它 typed expr | `uya_print_<typename>(value)` | `i32` |

`@println` 在 call 之后追加第二个 `CORE_EXPR_KIND_CALL` 节点：call target
`uya_write_newline()`，等价于 `uya_write(1, "\n", 1)`。

所有 helper 的 calling convention 是 hosted profile `x86_64 SysV`：
- 参数 1：i32（fd，常量 1 = stdout）
- 参数 2-4：随 helper 而定，但都在 SysV i64 寄存器内
- 返回：i32，写入字节数（println 的 newline 写入也返回 1，合并到外层 result）

freestanding profile（microapp / `--nostdlib`）要求把 stdout fd 替换为 capability
table 解析的 `STDOUT_CAP` 句柄，或显式 reject `print/println` 并给出
`native_unsupported_hosted_path: reason=hosted_print_requires_stdout_capability`
诊断；不得静默走 C99 fallback 或 pre-MIR helper。

### 3.4 字符串插值

`@println("x=${a} y=${b:.2f}")` 在 lowering 阶段物化成一个栈缓冲
`[byte: N]`，内容是 `c99_emit_string_interp_fill` 的等价输出。物化后 print 走
`uya_write_str(1, buf, N)`；插值表达式自身不再出现在 CoreExpr / PortableMIR 内，
避免插值表达式需要新 MIR 表达式 kind。

物化缓冲由当前 `CoreBody` 的 transient arena 分配，离开 CoreBody 时释放，不得
跨越函数边界。

---

## 4. PortableMIR shape

- `CORE_STMT_KIND_EXPR` 节点的 `expr_id` 指向 `CORE_EXPR_KIND_CALL` 表达式。
- `CORE_EXPR_KIND_CALL` 的 `callee_expr_id` 指向 frozen `MirFunction` 名称
  （`uya_write_str` / `uya_print_i32` / `uya_write_newline` 等），其
  `target_function_id` 在 CoreSemanticFact 中标记为 `extern`。
- `core_stmt_kind_is_dumped_and_verified(CORE_STMT_KIND_EXPR) == 1`，无需新增
  kind；同理 `core_expr_kind_is_dumped_and_verified(CORE_EXPR_KIND_CALL) == 1`。
- `portable_mir_lowering_feature_for_stmt_kind(CORE_STMT_KIND_EXPR)` 已经覆盖
  print 路径；`portable_mir_lowering_feature_for_expr_kind(CORE_EXPR_KIND_CALL)`
  同理。无需新增 feature mask。
- 每个 print helper 在 PortableMIR 的 function table 中占据一个
  `mir_extern_function` slot；`native_hosted_preflight` 报告的
  `mir_extern_functions` 计数必须 >= print helper 集合大小。

---

## 5. C99 oracle 行为（已落地）

`src/codegen/c99/expr.uya:9167` 周围的 `gen_print_expr` 已经把
`AST_PRINT` / `AST_PRINTLN` 落成：

- `nostdlib` profile：`uya_write(1, ..., uya_strlen(...))` + 可选 newline
  `uya_write(1, "\n", 1)`，合并返回 i32。
- 普通 profile：`printf("%s\n", ...)` 或 `printf("%s", ...)`，i32 字节数。

C99 路径已端到端，hosted native 路径必须以同样 stdout / 退出码 / 字节数 parity。

`tests/verify_hosted_native_full_language_smoke.sh` 的 C99 oracle 行为是
`exit 0`、`@println("Hello, World!")` 在 stdout 出现 `Hello, World!\n`。

---

## 6. Hosted native 合同（待实现）

- `NativeMirEmitter` 接受 verifier-clean 的 PortableMIR；`@println("Hello, World!")`
  生成 x86_64 ELF，真实运行输出 `Hello, World!\n`。
- stderr 不包含 `native_hosted_portable_mir_lowering_missing`、不包含
  `后端类型: C99`、不包含 `hosted native assembly`、不包含
  `build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集`。
- exit code 0；stdout / stderr 与 C99 oracle 完全一致。
- 生成的 ELF 不依赖 C99 fallback、pre-MIR helper、build-seed `LoweredProgram`
  helper 中的任何一个。

freestanding profile（`--nostdlib` microapp）下，hosted native 必须给出
`native_unsupported_hosted_path: reason=hosted_print_requires_stdout_capability`
诊断；除非调用方注册了 `STDOUT_CAP` capability。

---

## 7. Verifier 合同

`src/lower/mir_verifier.uya` 在 `CORE_STMT_KIND_EXPR` / `CORE_EXPR_KIND_CALL`
路径上必须：

- 校验 `callee_expr_id` 指向的 MirFunction 是 `extern`（非 body）。
- 校验参数和返回类型与 ABI SysV i32/i64 一致。
- 不允许 print call 出现在裸函数（`@naked_fn`）内：naked fn 必须由 pre-MIR helper
  拒绝。

`lowered_program_coreir_stmt_kind_is_dumped_and_verified` 与
`lowered_program_coreir_expr_kind_is_dumped_and_verified` 在新增 helper 路径
时**不要**改写 — 现有 EXPR/CALL 验证足够。

---

## 8. 测试合同

- `tests/verify_hosted_native_helloworld_parity.sh`（Phase 9B 收口）覆盖：
  - `@println("Hello, World!")` 在 hosted native 下真实生成并运行。
  - `@print("Hello") + @println("")` 拼接等价于 `@println("Hello\n")`。
  - `@println` 的 i32 返回值可作为表达式使用。
  - native/C99 stdout / stderr / exit code 完全一致。
  - native build stderr 包含 `native_hosted_coreir_preflight`、
    `native_hosted_preflight`、`native_hosted_subset: no_deps_portable_mir_path=1`
    三类证据。
- C99 路径（现有 `bin/uya build ...`）持续是 oracle；`make check` 通过。

---

## 9. 风险与开放点

- **runtime helper ABI 稳定性**：`uya_print_i32` / `uya_write` 当前由
  `src/codegen/c99_build/main.uya` 静态生成内联实现，不在 `lib/std/runtime/` 内。
  hosted native 端必须由 MIR emitter 在 verify 阶段冻结同一 ABI，否则跨二进制
  输出会漂移。
- **字符串插值 buffer 大小**：当前 C99 使用 `computed_size` + `256` 兜底；MIR
  端必须复用相同算法，避免插值缓冲区溢出或输出截断。
- **format spec**：`${expr:.2f}` 等格式说明在 C99 端 `c99/expr.uya:9271` 周围处理，
  MIR 端若不支持 format spec，必须明确 reject（不允许静默退化为默认 `%s`）。

---

## 10. 阶段 KPI 衔接

本文件对应 `docs/portable_mir_language_coverage.md` §3 中：

- `AST_PRINT` / `AST_PRINTLN` 当前为 `done`（C99 oracle 已端到端）。
- `MIR -> Native` HelloWorld parity 是 Phase 9B 阶段 KPI
  "HelloWorld 作为 MIR -> Native 首个目标完成 native/C99 parity"。
- 当 hosted native HelloWorld 跑通后，§3 备注可以从"C99 已完整 codegen"升级为
  "C99 + hosted native 双端 codegen"，并从 §7 reject 集合中确认无新增项。
