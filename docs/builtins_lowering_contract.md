# Builtins Group Lowering Contract

**状态**: Phase 9B builtins 迁移组合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, leaf "builtins")
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §8 (builtin)
**配套 expressions contract**: `docs/expressions_lowering_contract.md`

---

## 1. 范围

本文件定义 Uya 内置表达式（`@xxx` 前缀）的通用 lowering 合同，涵盖：

- `@len` / `@size_of` / `@align_of`（编译期常量）
- `@error_id` / `@error_name`（错误元数据）
- `@print` / `@println`（输出）
- `@syscall`（系统调用）
- `@ptr_from_usize` / `@usize_from_ptr`（指针/usize 互转）
- `@c_import`（构建指令，statement 位置）
- `@naked_fn`（裸函数声明）
- `@vector` / `@mask`（SIMD）
- `@params`（函数体内参数元组）
- `@src_name` / `@src_path` / `@src_line` / `@src_col` / `@func_name`（源元数据）
- `@embed` / `@embed_dir`（编译期嵌入）
- `@asm` / `@asm_target`（内联汇编）
- `@va_start` / `@va_end` / `@va_arg` / `@va_copy`（可变参数）
- `@mc_eval` / `@mc_code` / `@mc_ast` / `@mc_error` / `@mc_interp` / `@mc_type` / `@mc_source`（宏内 builtin）
- `@await`（异步表达式）

---

## 2. 状态表

| builtin | 状态 | CoreExpr/MIR 落点 | 验证证据 |
|---------|------|-------------------|----------|
| `@size_of` | done | `INT_LITERAL`（编译期常量） | `tests/verify_hosted_native_full_language_smoke.sh` `builtin` shard |
| `@align_of` | done | `INT_LITERAL`（编译期常量） | 同上 |
| `@len` | done | `INT_LITERAL`（数组 / 切片） | `array_len` shard |
| `@print` | done | `EXPR + CALL → uya_write_str` | `docs/print_corebody_surface.md` §3 |
| `@println` | done | `EXPR + CALL → uya_write_str + uya_write_newline` | 同上 |
| `@error_id` | done | `INT_LITERAL`（编译期 error id） | `error_id` shard |
| `@error_name` | done | `CALL → uya_error_name` | 同上 |
| `@c_import` | done | 顶层构建指令（`@c_import_decl`） | `verify_hosted_native_c_import_link_parity.sh` |
| `@naked_fn` | done | 裸函数声明（`MIR_FUNCTION_FLAG_NAKED`） | `verify_portable_mir_naked_fn.sh` |
| `@vector` | done | `VECTOR` expr | `simd` shard |
| `@mask` | done | `MASK` expr | 同上 |
| `@syscall` | missing | microapp / freestanding 路径；hosted native 走 explicit reject | 覆盖矩阵 §3 `AST_SYSCALL` 标 missing |
| `@ptr_from_usize` | missing | 同上 | `AST_PTR_FROM_USIZE` missing |
| `@usize_from_ptr` | missing | 同上 | `AST_USIZE_FROM_PTR` missing |
| `@params` | partial | `build_compiler_driver.uya` 内 pre-MIR helper 路径 | `compile_files(...)` 调用 ABI 内部 |
| `@src_name` | done | `CALL → uya_src_name` | `c99/main.uya` 静态生成 helper |
| `@src_path` | done | `CALL → uya_src_path` | 同上 |
| `@src_line` | done | `INT_LITERAL`（编译期） | 同上 |
| `@src_col` | done | `INT_LITERAL`（编译期） | 同上 |
| `@func_name` | done | `CALL → uya_func_name` | 同上 |
| `@embed` | missing | 编译期嵌入未迁 MIR | `AST_EMBED` missing |
| `@embed_dir` | missing | 同上 | `AST_EMBED_DIR` missing |
| `@asm` | missing | microapp / freestanding | `AST_ASM` missing |
| `@asm_target` | missing | 平台检测 | `AST_ASM_TARGET` missing |
| `@va_start` | missing | c_import 边界 | `AST_VA_START` missing |
| `@va_end` | missing | 同上 | `AST_VA_END` missing |
| `@va_arg` | missing | 同上 | `AST_VA_ARG` missing |
| `@va_copy` | missing | 同上 | `AST_VA_COPY` missing |
| `@mc_eval` | partial | 宏内 pre-MIR helper | `AST_MC_EVAL` partial |
| `@mc_code` | partial | 同上 | `AST_MC_CODE` partial |
| `@mc_ast` | partial | 同上 | `AST_MC_AST` partial |
| `@mc_error` | partial | 同上 | `AST_MC_ERROR` partial |
| `@mc_interp` | partial | 同上 | `AST_MC_INTERP` partial |
| `@mc_type` | partial | 同上 | `AST_MC_TYPE` partial |
| `@mc_source` | partial | 同上 | `AST_MC_SOURCE` partial |
| `@await` | partial | 异步表达式；C99 走 async transform | `AST_AWAIT_EXPR` partial |

---

## 3. 通用 contract

每个 builtin 必须满足：

1. **状态可追溯**：每行 §2 表格的状态（done / partial / missing）必须有
   `tests/verify_*.sh` 验证脚本或显式 missing 文档说明。
2. **hosted native 显式 reject**：所有 missing 状态在 hosted native 路径下必须
   显式 reject 并给出 `native_unsupported_hosted_path: reason=...` 诊断；
   不得静默走 C99 fallback 或 pre-MIR helper 成功路径。
3. **runtime helper ABI 稳定**：所有 `done` 状态的 builtin 调用的 runtime
   helper（`uya_*`）必须与 C99 codegen 静态生成的实现 ABI 一致。
4. **编译期常量**：`@size_of` / `@align_of` / `@len` / `@error_id` /
   `@src_line` / `@src_col` 必须在编译期求值，不允许生成 runtime call。
5. **format spec 拒绝**：`${expr:.2f}` 格式说明在 MIR 端若不支持，
   必须显式 reject；不允许静默退化为默认 `%s`。

---

## 4. 入口

`src/exec/lower.uya` 的 `exec_lower_expr` 在 `AST_*` 形态识别后调用
`exec_lower_builtin_*` 系列函数。每个 `@xxx` builtin 必须有：

- 一个 `exec_lower_builtin_<name>(ctx, args, out_type) Type` 函数负责编译期求值
  （如 `@size_of`）或生成 lowering 路径。
- 一个 `portable_mir_append_builtin_call`（如适用）生成 MIR call inst。

任何新 `@xxx` builtin 添加时，本表 + `docs/builtin_functions.md` 必须先于
`src/ast.uya` 的 `AST_*` 常量新增；否则 parser 解析出无法 lower 的节点。

---

## 5. 验证与守门

1. `tests/verify_portable_mir_language_coverage.sh`：矩阵 §8 builtin 行覆盖守门。
2. `tests/verify_hosted_native_full_language_smoke.sh`：`builtin` /
   `array_len` / `error_id` / `atomic` / `simd` shard 覆盖核心 builtin。
3. `tests/verify_hosted_native_c_import_link_parity.sh`：`@c_import` 端到端。
4. `tests/verify_portable_mir_naked_fn.sh`：`@naked_fn` 端到端。
5. `tests/verify_hosted_native_helloworld_parity.sh`：`@print` / `@println`
   最小路径。

新增 builtin 时：
- 更新本文件 §2 表格；
- 更新 `docs/portable_mir_language_coverage.md` §8 表格；
- 添加或更新对应 verify 脚本的 shard。

---

## 6. 反向合同

禁止：

1. 把 missing 状态 builtin 静默走 pre-MIR helper 后报"成功"。
2. 在 hosted native 中调用 libc 替代 `@print` / `@println` 路径（必须走
   `uya_*` runtime helper）。
3. 编译期常量走 runtime call（违反编译期求值合同）。
4. format spec 静默退化（必须 explicit reject 或 explicit 走 c99 path）。

---

## 7. 与其它迁移组的衔接

- **statements**：builtin 表达式作为 stmt 子节点。
- **expressions**：`CALL` kind 落地所有非编译期常量 builtin。
- **runtime entry**（`docs/runtime_entry_lowering_contract.md` 待补）：
  部分 builtin 调用的 helper 在 runtime entry 模块内。
- **types/layout**：`@size_of` / `@align_of` 依赖 MirType.size_bytes /
  align_bytes。
