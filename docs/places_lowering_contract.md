# Places / Addressing Group Lowering Contract

**状态**: Phase 9B places/addressing 迁移组合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, leaf "places/addressing")
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §6 (CorePlace)
**配套 expressions contract**: `docs/expressions_lowering_contract.md`

---

## 1. 范围

本文件定义 `CorePlaceKind` 中所有 place 形态（4 个常量 + 派生）的通用
CoreBody → PortableMIR lowering 合同，涵盖：

- local
- global
- field
- index
- slice ptr / len
- pointer arithmetic
- out-param
- optional / null-like pointer comparison
- nested aggregate address

每种 place 必须显式落在 §2 表格中的一种状态：done / partial / reject / missing。

---

## 2. CorePlace 状态表

| kind | 状态 | 描述 | 验证证据 |
|------|------|------|----------|
| `CORE_PLACE_KIND_LOCAL` | done | 局部变量地址 | `tests/verify_hosted_native_main_local_if_preflight.sh` |
| `CORE_PLACE_KIND_FIELD` | done | `struct.field` 字段地址 | `tests/verify_hosted_native_full_language_smoke.sh` `interface`/`drop` shard (`self.value`) |
| `CORE_PLACE_KIND_INDEX` | done | 数组元素地址 `arr[i]` | `tests/verify_hosted_native_full_language_smoke.sh` `array_index` shard |
| `CORE_PLACE_KIND_SLICE` | done | 切片 ptr/len pair | `tests/verify_hosted_native_full_language_smoke.sh` `slice` shard |

### 2.1 派生 place 形态

以下形态落成 4 个核心 kind 的组合，不引入新 kind：

- **global**：落成 `LOCAL`（指向一个被 `__uya_global_<name>` 命名的 MirLocal，
  由 `MIR_INST_OP_LOAD`/`STORE` 访问 global storage）。
- **pointer arithmetic**：落成 `INDEX`（把指针视为 `[byte]` 数组）。
- **out-param**：落成 `LOCAL`（被调函数栈帧中的 out slot）。
- **optional / null-like pointer comparison**：落成 `LOCAL` + `I32_NE` 与 0 比较。
- **nested aggregate address**：field 链；每层 field 落成 `FIELD` place。
- **slice ptr**：`SLICE` 走 `place.field_start..field_start+1`（取 ptr）。
- **slice len**：`SLICE` 走 `place.field_start+1..field_start+2`（取 len）。

---

## 3. 通用 contract

每个 `CORE_PLACE_KIND_*` 必须满足：

1. **address semantics**：`MIR_INST_OP_LOAD` / `MIR_INST_OP_STORE` 对应
   `place` 时必须生成正确的 lvalue/rvalue 转换；verifier
   `MIR_VERIFY_ERR_INVALID_ADDRESS` 拒绝错位。
2. **flag 标记**：栈分配的 place 必须设置 `MIR_LOCAL_FLAG_ADDRESS_TAKEN`，
   否则会破坏 ABI 假设。
3. **field layout**：field place 必须携带 `field_id`，对应 `MirType` 的
   `field_start`/`field_count` 范围；越界则 verifier 拒绝。
4. **slice pair**：slice place 在 `MirInst.operand_start..operand_count`
   中必须包含连续 2 个 operand（ptr 和 len），缺一 verifier 拒绝。
5. **pointer arithmetic**：作为 `INDEX` place 时 stride 必须 >= element type
   size；越界则 verifier `MIR_VERIFY_ERR_INVALID_ADDRESS` 拒绝。

---

## 4. AST 节点到 CorePlace 入口

| AST kind | CorePlace kind |
|----------|---------------|
| `AST_IDENTIFIER` (local) | `LOCAL` |
| `AST_IDENTIFIER` (global) | `LOCAL`（指向 `__uya_global_<name>`） |
| `AST_MEMBER_ACCESS` | `FIELD` |
| `AST_ARRAY_ACCESS` | `INDEX` |
| `AST_SLICE_EXPR` | `SLICE` |
| `AST_UNARY_EXPR` (`&` / `*`) | `LOCAL`（address-of）或 `LOCAL`（deref 后 load/store） |
| `AST_CAST_EXPR` (pointer arithmetic) | `INDEX` |
| `AST_DESTRUCTURE_DECL` | 多个 `LOCAL`（每个 destructure 目标一个） |

---

## 5. 验证与守门

1. `tests/verify_portable_mir_language_coverage.sh`：矩阵 §6 覆盖守门。
2. `tests/verify_hosted_native_full_language_smoke.sh`：`array_index` /
   `slice` / `interface` / `drop` shard：hosted native 必须真实生成
   executable 且与 C99 parity 一致。
3. `tests/verify_portable_mir_lowering_contract.sh`：CorePlace kind 数量与
   matrix 报告的 `core_places.count` 一致。

新增 place 形态或 CorePlace kind 时：
- 更新本文件 §2 表格；
- 更新 `docs/portable_mir_language_coverage.md` §6 表格；
- 如果状态为 `done` 或 `partial`，添加或更新对应 verify 脚本的 shard。

---

## 6. 反向合同

禁止：

1. 绕过 CorePlace 直接消费 AST 节点生成 MIR 寻址。
2. field 链跳层（必须每层 field 都是显式 place）。
3. slice ptr/len 拆开作为独立 operand（必须连续成对）。
4. global place 不通过 `__uya_global_*` 命名空间。

---

## 7. 与其它迁移组的衔接

- **statements**（`docs/statements_lowering_contract.md`）：`ASSIGN` 涉及 place 寻址。
- **expressions**（`docs/expressions_lowering_contract.md`）：`LOAD` / `MEMBER_ACCESS`
  等 expr 引用 place。
- **types/layout**（`docs/types_layout_lowering_contract.md` 待补）：place 的
  `type_id` 必须翻译成 `MirTypeId`。
