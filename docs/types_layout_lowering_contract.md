# Types / Layout Group Lowering Contract

**状态**: Phase 9B types/layout 迁移组合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, leaf "types/layout")
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §3 (AST_TYPE_*)
**配套 expressions contract**: `docs/expressions_lowering_contract.md`

---

## 1. 范围

本文件定义从 Uya typed-program `Type` 到 `MirType` 的翻译合同，涵盖：

- integer / float / bool / byte
- pointer
- array
- slice
- struct
- union
- enum
- error union
- function type
- interface / vtable
- generic instance
- atomic
- vector / mask
- naked function layout / capability

每种 type 必须显式落在 §2 表格中的一种状态：done / partial / reject / missing。

---

## 2. AST type kind → MirType kind 状态表

| AST type | MirType kind | 状态 | 备注 |
|----------|--------------|------|------|
| `AST_TYPE_NAMED` (i8/i16/i32/i64/u8/u16/u32/u64/usize/byte/bool) | `MIR_TYPE_KIND_I32` 等 | done | 基础整数/布尔 |
| `AST_TYPE_NAMED` (f32/f64) | `MIR_TYPE_KIND_*` (待补 f32/f64 标记) | partial | Phase 9A shard `simd` 仅覆盖 `@vector(f32)` 路径 |
| `AST_TYPE_POINTER` | `MIR_TYPE_KIND_POINTER` + pointee | done | |
| `AST_TYPE_ARRAY` | `MIR_TYPE_KIND_*` (array) | done | |
| `AST_TYPE_SLICE` | `MIR_TYPE_KIND_*` (slice) + ptr/len pair | done | |
| `AST_TYPE_NAMED` (struct) | `MIR_TYPE_KIND_STRUCT` + field range | done | |
| `AST_TYPE_NAMED` (union) | `MIR_TYPE_KIND_STRUCT` + tag | done | |
| `AST_TYPE_NAMED` (enum) | `MIR_TYPE_KIND_STRUCT` + tag 字段 | done | |
| `AST_TYPE_ERROR_UNION` | `MIR_TYPE_KIND_STRUCT` + tag + payload | done | |
| `AST_TYPE_NAMED` (function type) | `MIR_TYPE_KIND_POINTER` to function | done | SysV ABI 翻译 |
| `AST_TYPE_NAMED` (interface) | `MIR_TYPE_KIND_STRUCT` + vtable pointer | done | `interface` shard 覆盖 |
| `AST_TYPE_NAMED` (generic instance) | 单态后按上述分发 | done | 单态化在 lower 之前完成 |
| `AST_TYPE_ATOMIC` | `MIR_TYPE_KIND_ATOMIC` + pointee + align | done | `atomic` shard |
| `AST_TYPE_VECTOR` | `MIR_TYPE_KIND_VECTOR` + lane_count + element | done | `simd` shard |
| `AST_TYPE_MASK` | `MIR_TYPE_KIND_MASK` + lane_count | done | `simd` shard |
| `AST_TYPE_NAMED` (naked function) | `MIR_TYPE_KIND_POINTER` to function + naked flag | done | `verify_portable_mir_naked_fn.sh` |
| `AST_TYPE_TUPLE` | `MIR_TYPE_KIND_STRUCT` + field range | partial | 走 typed-program 路径；MIR 仅 basic tuple 表面 |
| `AST_TYPE_FRAME` (async) | `MIR_TYPE_KIND_STRUCT` + 异步帧字段 | partial | C99 走 async transform |

### 2.1 状态语义

- **done**：C99 + hosted native 端到端 parity 验证脚本已存在。
- **partial**：C99 端通过；hosted native 端到端 parity 待 Phase 9B 收口。
- **missing**：尚未落地；本阶段不新增 missing。

---

## 3. 通用 contract

每个 type translation 必须满足：

1. **layout_id 唯一**：`MirType` 的 `layout_id` 在 module 内必须唯一，
   verifier 拒绝重复。
2. **size / align**：`size_bytes` 和 `align_bytes` 必须与 C99 ABI 对齐
   （即 `sizeof(T) == MirType.size_bytes`）；`@size_of` 路径依赖此。
3. **address space**：hosted native 默认 `MIR_ADDRESS_SPACE_HOST`；
   `atomic` 走 `MIR_ADDRESS_SPACE_GENERIC` + atomic ordering。
4. **pointed-to**：所有 pointer-like kind（`POINTER` / `ATOMIC` / 引用类型）
   必须填 `pointee_type_id`；空则 verifier 拒绝。
5. **field range**：struct / union / error union 的 `field_start` /
   `field_count` 必须指向合法的 `MirType` slot 范围。
6. **tag 偏移**：union / enum / error union 必须填
   `tag_offset_bytes` / `payload_offset_bytes`；缺失则 `@error_id` /
   match 走错。

---

## 4. AST type 入口

`src/exec/lower.uya` 的 `exec_lower_type_ast_*` 必须为以下 AST type kind
落成对应 `MirType` kind：

| AST type kind | MirType kind | 翻译入口 |
|---------------|--------------|----------|
| `AST_TYPE_NAMED` (primitive) | 基础 kind | 内部查表 |
| `AST_TYPE_NAMED` (struct) | `STRUCT` | `exec_lower_type_ast_*` 递归 field |
| `AST_TYPE_NAMED` (union / enum) | `STRUCT` | + tag 字段 |
| `AST_TYPE_POINTER` | `POINTER` | 递归 pointee |
| `AST_TYPE_ARRAY` | array | 递归 element + size constant |
| `AST_TYPE_SLICE` | slice | ptr/len pair |
| `AST_TYPE_ERROR_UNION` | `STRUCT` | + error 字段 |
| `AST_TYPE_ATOMIC` | `ATOMIC` | 递归 pointee + align |
| `AST_TYPE_VECTOR` | `VECTOR` | 递归 element + lane_count |
| `AST_TYPE_MASK` | `MASK` | lane_count |
| `AST_TYPE_FRAME` | `STRUCT` | 异步帧布局 |
| `AST_TYPE_TUPLE` | `STRUCT` | 递归每个 tuple field |

任何新 `AST_TYPE_*` 添加时，本表必须先于 `MirType.kind` 枚举扩展；否则
`@size_of` 路径会在新 type 形态上静默返回 0。

---

## 5. 验证与守门

1. `tests/verify_portable_mir_language_coverage.sh`：矩阵 §3 中 AST_TYPE_*
   行覆盖守门。
2. `tests/verify_hosted_native_full_language_smoke.sh`：
   - `builtin` shard 覆盖 `@size_of` / `@align_of`。
   - `atomic` / `simd` / `interface` shard 覆盖对应 type。
3. `tests/verify_portable_mir_structs.sh`：MirType struct 字段完整。
4. `tests/verify_portable_mir_dynamic_tables.sh`：MirType table 动态增长。

新增 type kind 时：
- 更新本文件 §2 表格；
- 更新 `docs/portable_mir_language_coverage.md` §3 表格；
- 添加或更新对应 verify 脚本的 shard。

---

## 6. 反向合同

禁止：

1. 绕过 MirType 直接消费 AST type（`@size_of` 路径必须查 MirType.size_bytes）。
2. 重复 `layout_id`（verifier 拒绝）。
3. atomic 走非 atomic MirType kind（违反 memory model）。
4. 浮点类型走整数 MirType kind（违反 ABI）。

---

## 7. 与其它迁移组的衔接

- **statements / expressions / places**：所有 group 中 `type_id` 字段
  翻译都依赖本文件。
- **builtins**（`docs/builtins_lowering_contract.md` 待补）：`@size_of` /
  `@align_of` 走 `INT_LITERAL` 路径，但语义上依赖本文件的 `size_bytes` /
  `align_bytes` 字段。
- **runtime entry**（`docs/runtime_entry_lowering_contract.md` 待补）：
  std.runtime.entry 的 signature type 翻译走本文件。
