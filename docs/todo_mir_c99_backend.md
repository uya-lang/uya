# MIR-C99 Backend TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-06-12
**上层目标**: `docs/todo_compiler_1s.md`
**覆盖矩阵**: `docs/portable_mir_language_coverage.md`
**架构设计**: `docs/compiler_1s_architecture_design.md`

---

## 1. 目标

MIR-C99 后端必须让普通 Uya 程序按同一套语言规则走：

```text
CoreBody -> PortableMIR -> MirC99Plan -> MirC99Emitter -> host C99 compiler
```

验收目标：

- 支持完整 Uya 语法和当前 `tests/` 覆盖的主语言面。
- 与现有 AST/LoweredProgram C99 backend 的 stdout、stderr、exit code 和 diagnostics 语义对齐。
- MIR-C99-built compiler 能复跑 `cmd/build` self-build、compiler regression、C99 output parity 和完整语言后端 parity。
- 不调用现有 `src/codegen/c99*` 生产 emitter；现有 C99 只能作为 oracle、fallback 和 release 兜底。

当前状态：

- `src/codegen/mir_c99/` 尚不存在。
- `src/lower/mir_backend.uya` 只有 `MIR_TARGET_BACKEND_C99` 和 `c99_plan: &void` 占位。
- `docs/portable_mir_language_coverage.md` 已记录 MIR-C99 全局状态为 `missing` / `partial`。

---

## 2. 完成定义

`done` 只能由以下证据之一支撑：

- 专用 MIR-C99 harness 生成 `.c`，由 host C99 compiler 编译、链接、运行，并与现有 C99 oracle 对齐。
- MIR-C99-built compiler 复跑指定 self-build / regression / parity 套件通过。
- 对不支持能力给出明确 MIR-C99 capability diagnostic，并在覆盖矩阵中登记为 `reject`。

不能作为 `done` 证据：

- 现有 AST/LoweredProgram C99 emitter 成功。
- 固定函数名、固定 statement count、固定 AST/body shape 的成功路径。
- 回查 AST body 或 `LoweredProgram` body 来补 MIR-C99 语义。
- 只通过 dump/verifier，没有端到端 host C99 compiler 运行结果。

---

## 3. 执行规则

- 每次只把一个叶子标成 `[~]`；完成后补验证命令和结果，再标 `[x]`。
- 每个实现叶子先补合同或 parity/reject 测试，再改 generic lowering 或 MIR-C99 backend。
- 新增语言面必须先更新覆盖矩阵或 MIR-C99 per-kind 状态，不能只加单个 smoke。
- self-build frontier 必须归因到通用语言结构：CFG、place/memory、call ABI、cleanup/error、runtime capability 或 MIR instruction coverage。
- `make backup-all` 只放到阶段收口或发布前；普通叶子优先跑 focused gate、coverage verifier、`git diff --check`。

---

## 4. 任务清单

### 4.0 PortableMIR 前置缺口清单

以下任务必须优先于对应 MIR-C99 backend leaf 完成；后端只能消费实际 `src/lower/mir.uya` / `src/lower/mir_verifier.uya` 中存在并可验证的 MIR type、opcode、metadata 和 capability，不能消费 `src/lower/mir_contract.uya` 中 contract-only 常量伪装支持。

- [x] MIR-C99-PREMIR-TYPES：补齐后端需要的 PortableMIR type/layout metadata。
  - [x] 标量 type kind：`i8/u8/i16/u16/u32/i64/u64/isize/byte/f32/f64`，并同步 verifier size/align 规则。
    - 验证：`bash tests/verify_mir_c99_type_scalar_gap.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] array / slice type kind：包含 element type、length/capacity/ptr/len layout metadata，并同步 verifier。
    - 验证：`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_scalar_gap.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] struct / union / enum field layout metadata：字段顺序、offset、size、align、tag/payload offset 可由 MIR-C99 直接消费。
    - [x] 新增 PortableMIR aggregate field layout 表、append API 和 verifier range/field 规则。
      - 验证：`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_parallel_determinism.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] MIR-C99 type plan 保留 struct / union / enum field layout range 和 tag/payload metadata。
      - 验证：`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] 更新覆盖证据，证明 backend 不再只能看到 `field_start/field_count` 占位。
      - 验证：`bash tests/verify_mir_c99_type_field_layout.sh` 通过，覆盖 `MirFieldLayout`、`portable_mir_append_field_layout`、aggregate verifier range/field 规则，以及 MIR-C99 type plan 对 field range 与 tag/payload metadata 的保留；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] error union layout metadata：success/error tag、payload offset、ABI class 可由 MIR-C99 直接消费。
    - 验证：`bash tests/verify_mir_c99_type_error_union_layout.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] function type / function pointer type metadata：参数、返回值、calling convention、ABI class 和可调用 symbol/value 关系。
    - 验证：`bash tests/verify_mir_c99_type_function_signature.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_mir_c99_type_error_union_layout.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_parallel_determinism.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

- [x] MIR-C99-PREMIR-VALUE-OPS：补齐表达式和转换 opcode。
  - [x] 整数一元、逻辑、非 i32 算术/比较 opcode，并在 verifier 中校验 operand/result type。
    - [x] 建立整数 value opcode inventory / 分类 helper，覆盖一元、逻辑、非 i32 算术和比较族，并让 verifier 使用分类入口。
      - 验证：`bash tests/verify_portable_mir_value_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `U64_ADD` 正/反例，断言数 19）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] 新增非 i32 整数算术 opcode，校验 operand/result type 一致且结果为同宽整数。
      - 验证：`bash tests/verify_portable_mir_value_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（`U64_ADD` 同宽正例和错配反例覆盖）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] 新增整数比较 opcode，校验 operand type 一致且 result type 为 bool。
      - 验证：`bash tests/verify_portable_mir_value_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `U32_GE` bool result 正例和非 bool result 反例，断言数 21）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] 新增整数一元 opcode，校验 operand/result type 一致。
      - 验证：`bash tests/verify_portable_mir_value_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `INT_NEG` 同型正例和 operand 错配反例，断言数 23）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] 同步 MIR-C99 expression plan 对新增整数 opcode 的可见支持/拒绝边界。
      - 验证：`bash tests/verify_mir_c99_expression_plan.sh` 通过（新增 integer arithmetic / compare / unary expression kind，checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_value_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过。
  - [x] bool 组合 opcode：`and` / `or` / `not` 或等价短路/非短路 MIR 表达形式。
    - 验证：`bash tests/verify_mir_c99_expression_plan.sh` 通过（新增 `MIR_C99_EXPR_KIND_BOOL_LOGIC` 和 bool logic opcode family 分类，checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `BOOL_AND`、`BOOL_NOT` 正例和 bool operand 错配反例，断言数 26）；`bash tests/verify_portable_mir_value_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
  - [x] cast / sign extend / zero extend / truncate / int-float / float-int / float-double conversion opcode。
    - [x] 建立 conversion opcode inventory / 分类 helper，覆盖 int widen/narrow、int-float、float-double 转换族，并让 verifier 使用分类入口。
      - 验证：`bash tests/verify_portable_mir_conversion_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `INT_TO_F64` 正例和方向错配反例，断言数 28）；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] sign extend / zero extend / truncate opcode：校验 operand/result 都是整数，宽度方向与转换语义一致。
      - 验证：`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `SIGN_EXTEND i16->i64`、`TRUNCATE i64->i16` 正例和反向宽度反例，断言数 32）；`bash tests/verify_portable_mir_conversion_opcode_inventory.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] int-float / float-int conversion opcode：校验整数与 f32/f64 operand/result 方向。
      - 验证：`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `F64_TO_INT` 正例和结果类型方向错配反例，断言数 34）；`bash tests/verify_portable_mir_conversion_opcode_inventory.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] float promote / demote conversion opcode：校验 f32/f64 operand/result 方向。
      - 验证：`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `F32_TO_F64`、`F64_TO_F32` 正例和方向错配反例，断言数 38）；`bash tests/verify_portable_mir_conversion_opcode_inventory.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] 同步 MIR-C99 expression plan 对 conversion opcode 的可见支持/拒绝边界。
      - 验证：`bash tests/verify_mir_c99_expression_plan.sh` 通过（新增 `MIR_C99_EXPR_KIND_CONVERSION` 和 conversion opcode family 分类，checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_conversion_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
  - [x] f32/f64 算术、比较、常量和 return/call value verifier 规则。
    - [x] 建立 f32/f64 value opcode inventory / 分类 helper，覆盖浮点算术、比较和常量族，并让 verifier 使用分类入口。
      - 验证：`bash tests/verify_portable_mir_float_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `CONST_F32` 正例和非 float result 反例，断言数 40）；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] f32/f64 算术 opcode：校验 operand/result type 同为 f32 或同为 f64。
      - 验证：`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `F64_ADD` 同型正例和 operand 类型错配反例，断言数 42）；`bash tests/verify_portable_mir_float_opcode_inventory.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] f32/f64 比较 opcode：校验 operand type 同为 f32/f64 且 result type 为 bool。
      - 验证：`bash tests/verify_portable_mir_verifier.sh` 通过（新增 `F32_LE` bool result 正例、非 bool result 反例和 operand 类型错配反例，断言数 45）；`bash tests/verify_portable_mir_float_opcode_inventory.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] f32/f64 常量 literal：MIR operand/value plan 能记录 f32/f64 常量类别并明确当前 payload 边界。
      - 验证：`bash tests/verify_mir_c99_expression_plan.sh` 通过（新增 `MIR_C99_CONSTANT_KIND_F32_LITERAL` / `MIR_C99_CONSTANT_KIND_F64_LITERAL`，当前仅 `immediate_i32 == 0` 的 float 零值可记录为专用 literal，非零 payload 仍为 unsupported/reject；checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_float_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] return/call value verifier：f32/f64 return/call result/argument type 必须由 MIR type 和 ABI metadata 明确校验。
      - 验证：`bash tests/verify_portable_mir_verifier.sh` 通过（新增 f64 return 正例/签名错配反例，以及 f64 call result 正例/签名错配反例，断言数 49）；`bash tests/verify_portable_mir_float_opcode_inventory.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。
    - [x] 同步 MIR-C99 expression plan 对 f32/f64 算术/比较/常量的可见支持/拒绝边界。
      - 验证：`bash tests/verify_mir_c99_expression_plan.sh` 通过（新增 `MIR_C99_EXPR_KIND_FLOAT_ARITH` / `MIR_C99_EXPR_KIND_FLOAT_COMPARE` 和 float opcode family 分类，checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_float_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过。

- [ ] MIR-C99-PREMIR-PLACE-OPS：补齐 place/address opcode。
  - [x] local/global/param address opcode，并明确 address value 与 local slot 的生命周期约束。
    - 验证：`bash tests/verify_portable_mir_address_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 local/param/global address 正例和 local 未标记 address-taken 反例，断言数 53）；`bash tests/verify_mir_c99_type_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] field address / load / store opcode：field id/index、base operand、result pointer type、bounds verifier。
    - 验证：`bash tests/verify_portable_mir_field_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 field addr/load/store 正例和 field index 越界反例，断言数 57）；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] array index address / load / store opcode：index operand、element type、bounds/capability metadata。
    - 验证：`bash tests/verify_portable_mir_index_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 index addr/load/store 静态正例、动态 index 带 bounds flag 正例和动态 index 缺 bounds flag 反例，断言数 62）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] slice ptr / len / index address opcode：ptr/len field access、indexing、result type verifier。
  - [ ] pointer offset opcode：element stride、signed/usize offset、overflow/capability 策略。
  - [ ] aggregate copy / move opcode 或显式 memcpy helper capability：size/align/source/dest overlap 语义必须可验证。

- [ ] MIR-C99-PREMIR-CALL-ABI：补齐 call 和 ABI metadata。
  - [ ] direct call、extern call、method/monomorphized call、function pointer call 的 callee 表达形式。
  - [ ] 多参数、aggregate return、out-param writeback、error union return、float/double ABI class metadata。
  - [ ] call ABI 缺失时 verifier 必须 reject，不能留给 MIR-C99 后端猜测。

- [ ] MIR-C99-PREMIR-RUNTIME-CAPABILITY：补齐 runtime helper/capability refs。
  - [ ] `memcpy` / `memset` / `memcmp` / string primitive helper refs。
  - [ ] print/println、malloc/free、env/file IO、syscall capability refs。
  - [ ] atomic init/load/store/RMW/CMPXCHG opcode 或 helper capability；普通 load/store 不得伪装原子。
  - [ ] SIMD vector/mask load/store/splat/select opcode 或明确 capability reject。

- [ ] MIR-C99-PREMIR-CLEANUP-ASYNC：补齐 cleanup/error/async MIR 表达。
  - [ ] `defer` / `errdefer` / lexical drop 的 cleanup edge、drop opcode 和 unwind/error path metadata。
  - [ ] `try` / `catch` / error union success/failure CFG 形态和 verifier 规则。
  - [ ] async frame metadata：state tag、result slot、await child slot、captured locals、poll/resume edge、frame allocation/free capability。

- [ ] MIR-C99-PREMIR-GLOBALS-IMPORTS：补齐 global/import MIR 表达。
  - [ ] global scalar / aggregate initializer、string constants、dedupe id 和 section/linkage metadata。
  - [ ] extern globals、C import object/link inputs、symbol visibility 和 target profile metadata。
  - [ ] split-C 多 unit 所需的 cross-unit symbol/export/import/ref metadata。

### 4.1 合同与边界

- [x] MIR-C99-BACKEND-CONTRACTS：冻结独立 MIR-C99 合同。
  - [x] 新增 `docs/mir_c99_backend.md`：说明 C99 是 portable assembly，列出禁止可读性/源码结构还原作为目标。
    - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`rg -n "portable assembly|禁止路径|c99_codegen_generate|AST body|LoweredProgram body|MirC99Plan|done|reject" docs/mir_c99_backend.md` 覆盖关键合同；`git diff --check` 通过。
  - [x] 在 `docs/portable_mir_language_coverage.md` 增加 MIR-C99 per-kind 状态列：`missing` / `partial` / `done` / `reject`。
    - 验证：`bash tests/verify_portable_mir_language_coverage.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`rg -n "MIR-C99 状态|per-kind|status_column|missing MIR-C99 status" docs/portable_mir_language_coverage.md tests/verify_portable_mir_language_coverage.sh` 覆盖列和 verifier；`git diff --check` 通过。
  - [x] 新增 `tests/verify_mir_c99_independent_boundary.sh`：扫描 MIR-C99 源码不得 `use codegen.c99`、`use codegen.c99_build`。
    - 验证：`bash tests/verify_mir_c99_independent_boundary.sh --self-test` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] boundary gate 禁止调用 `c99_codegen_generate`、`C99CodeGenerator`、现有 `C99Plan` 生产 emitter。
    - 验证：`bash tests/verify_mir_c99_independent_boundary.sh --self-test` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] boundary gate 禁止读取 AST body / `LoweredProgram` body 作为成功路径。
    - 验证：`bash tests/verify_mir_c99_independent_boundary.sh --self-test` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 新增 `tests/verify_mir_c99_minimal_subset_contract.sh`：固定允许的低级 C99 子集和禁用项。
    - 验证：`bash tests/verify_mir_c99_minimal_subset_contract.sh --self-test` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 新增 `tests/verify_mir_c99_oracle_parity_harness.sh`：统一生成 MIR-C99、现有 C99 oracle、host C compiler 编译运行、stdout/stderr/exit diff 和 no-fallback 检查。
    - 验证：`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 通过并明确报告 generator commands pending backend hookup；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.2 后端骨架

- [x] MIR-C99-BACKEND-SKELETON：建立独立后端文件和 CLI/backend 接线。
  - [x] 新增 `src/codegen/mir_c99/plan.uya`：定义 `MirC99Plan`、`MirC99Unit`、prototype/global/function/helper 引用表，全部动态增长。
    - 验证：`./bin/uya check src/codegen/mir_c99/plan.uya` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] 新增 `src/codegen/mir_c99/emitter.uya`：只消费 `MirTargetBackendRequest` / verifier-clean `PortableMirModule` 和 `MirC99Plan`，输出 C bytes。
    - 验证：临时合并 `src/codegen/mir_c99/plan.uya` 与去掉 `use` 的 `src/codegen/mir_c99/emitter.uya` 后执行 `./bin/uya check <tmp>` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] 新增 `src/codegen/mir_c99/types.uya`：只从 MIR type/layout metadata 生成 C typedef，不查 AST/checker。
    - 验证：临时合并 `src/codegen/mir_c99/plan.uya` 与去掉 `use` 的 `src/codegen/mir_c99/types.uya` 后执行 `./bin/uya check <tmp>` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] 新增 `src/codegen/mir_c99/names.uya`：生成稳定 symbol/temp/block 名，不复用现有 C99 safe-name cache。
    - 验证：`./bin/uya check src/codegen/mir_c99/names.uya` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] 新增 `src/codegen/mir_c99/driver.uya`：从 `MIR_TARGET_BACKEND_C99` request 生成 `MirC99Plan` 和 output。
    - 验证：临时合并 `plan/names/types/emitter/driver` 并去掉 `use codegen.mir_c99.*` 后执行 `./bin/uya check <tmp>` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] 明确 `MIR_BACKEND_OUTPUT_C99_PLAN` 当前为 legacy 名称，或迁移为 `MIR_BACKEND_OUTPUT_MIR_C99_PLAN` 并同步 backend interface tests。
    - 验证：`bash tests/verify_portable_mir_backend_interface.sh` 通过；临时合并 `plan/names/types/emitter/driver` 并去掉 `use codegen.mir_c99.*` 后执行 `./bin/uya check <tmp>` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。

### 4.3 单元输出

- [ ] MIR-C99-BACKEND-UNIT-OUTPUT：先实现单 unit，保留多 unit 扩展点。
  - [ ] 支持单 `.c` 输出：include、typedef、extern prototype、function prototype、global、function body。
    - [x] 新增 MIR-C99 unit output writer 合同：只消费 `MirC99Plan` / `MirC99Unit`，输出 section 顺序和 byte 统计，不回查 AST/C99 backend。
      - 验证：临时合并 `src/codegen/mir_c99/plan.uya` 与去掉 `use` 的 `src/codegen/mir_c99/unit_output.uya` 后执行 `./bin/uya check <tmp>` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
    - [x] 支持 include / typedef / extern prototype / function prototype section 的低级 C bytes 输出。
      - 验证：`bash tests/verify_mir_c99_unit_output_sections.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
    - [x] 支持 global / function body section 的低级 C bytes 输出。
      - [x] 支持 global section 的低级 C bytes 输出。
        - 验证：`bash tests/verify_mir_c99_unit_output_sections.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
      - [x] 支持 function body section 的低级 C bytes 输出；不得输出固定 `return 0;` 伪函数体，需等待 CFG/return 语义接入。
        - 验证：`bash tests/verify_mir_c99_unit_output_sections.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] 单 `.c` 输出接入 emitter output result，并记录 no-fallback 验证。
      - 验证：`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 支持 `MirC99Unit[]` 数据结构和 unit fingerprint，即使首版只生成一个 unit。
    - 验证：`bash tests/verify_mir_c99_unit_fingerprint.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 支持 `.c` 输出编译命令和临时文件生命周期，不接入现有 split-C makefile writer。
    - 验证：`bash tests/verify_mir_c99_host_compile_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] 新增 smoke：return literal 经 MIR-C99 生成 `.c`，host C compiler 编译运行，exit 与现有 C99 oracle 一致。
    - 阻塞：`bash tests/verify_mir_c99_oracle_parity_harness.sh` 目前只报告 `generator commands are pending backend hookup`，尚无真实 `MIR_C99_GENERATE_CMD`/CLI；当前 RETURN 输出仍依赖 `return tmpN;`，return literal immediate/value emission 需要后续 Values 任务接入后才能做端到端 host C 编译运行。

### 4.4 CFG

- [ ] MIR-C99-BACKEND-CFG：把 MIR CFG 映射到低级 C99。
  - [x] MIR function -> C function。
    - 验证：`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] MIR block -> C label。
    - 验证：`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] MIR unconditional branch -> `goto bbN;`。
    - 验证：`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] MIR conditional branch -> `if (cond) goto bbT; goto bbF;`。
    - 验证：`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] MIR return -> `return expr;` / `return;`。
    - 验证：`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] MIR verifier 未通过时拒绝，不生成 C。
    - 验证：`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] parity shard：local init + if return / nested branch / loop backedge。
    - 阻塞：当前无真实 MIR-C99 generator command/CLI，`tests/verify_mir_c99_oracle_parity_harness.sh` 仍停在 pending backend hookup；该 shard 还需要 4.5 Values 的 local/temp/literal 与比较/branch value emission，现阶段无法生成可由 host C compiler 编译运行的对齐用例。

### 4.5 Values

- [ ] MIR-C99-BACKEND-VALUES：把 MIR value/local 映射到 C temp。
  - [x] 整数、bool、byte、usize/isize、f32/f64 scalar temp。
    - 验证：`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 常量 literal、zero/null。
    - 验证：`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 一元/二元算术、比较、逻辑。
    - [x] 当前 MIR opcode：`MIR_INST_OP_I32_ADD` / `MIR_INST_OP_I32_LE` expression plan。
      - 验证：`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] MIR opcode 缺口记录：一元、逻辑和其他算术/比较 opcode 尚未进入 PortableMIR，后端不得臆造 MIR 常量。
      - 证据：`rg -n "MIR_INST_OP_" src/lower/mir.uya src/lower/mir_verifier.uya` 显示当前相关表达式 opcode 只有 `MIR_INST_OP_I32_ADD` 和 `MIR_INST_OP_I32_LE`；一元、逻辑和其他算术/比较 opcode 尚未定义，MIR-C99 后端只规划已存在 MIR opcode。
      - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] cast、sign/zero extend、truncate，以及 int/float/double 显式转换。
    - 阻塞：当前 PortableMIR opcode 枚举和 verifier 只包含 `NOP`、`LOAD`、`STORE`、`CALL`、`ASM_BLOCK`、`I32_ADD`、`I32_LE`、`LOCAL_SET`，没有 cast/sign-extend/zero-extend/truncate/int-float conversion opcode；MIR-C99 后端不能臆造未定义 MIR 常量或未验证指令形态。
    - 验证：`rg -n "MIR_INST_OP_" src/lower/mir.uya src/lower/mir_verifier.uya` 确认 opcode 缺口；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] value def/use 顺序检查：未定义或跨 block 非法 use 必须由 verifier 阻止。
    - 验证：`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] parity shard：integer arithmetic/comparison/boolean combination。
    - 阻塞：当前仍无真实 MIR-C99 generator command/CLI；`tests/verify_mir_c99_oracle_parity_harness.sh` 报告 `generator commands are pending backend hookup`。虽然 value/constant/expression plan 已覆盖当前 `I32_ADD`/`I32_LE`，但 unit output 尚未发射表达式语句并生成可由 host C compiler 编译运行的 `.c`。
    - 验证：`bash tests/verify_mir_c99_oracle_parity_harness.sh` 仅确认 harness installed/pending backend hookup；不能作为 parity 通过证据。
  - [ ] parity shard：float/double arithmetic、comparison、cast 和 return。
    - 阻塞：当前 PortableMIR 没有 f32/f64 type kind、float/double arithmetic/comparison/cast opcode，也无真实 MIR-C99 generator command/CLI；`tests/verify_mir_c99_oracle_parity_harness.sh` 仍停在 pending backend hookup。
    - 验证：`rg -n "MIR_TYPE_KIND_F|MIR_INST_OP_.*F|MIR_INST_OP_.*CAST|MIR_INST_OP_" src/lower/mir.uya src/lower/mir_verifier.uya` 未发现 float/cast opcode；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 仅确认 harness installed/pending backend hookup；不能作为 parity 通过证据。

### 4.6 Place / Memory

- [ ] MIR-C99-BACKEND-PLACE-MEMORY：把 MIR place/load/store 映射到 C 地址和赋值。
  - [x] local slot address、load、store。
    - 验证：`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] pointer deref load/store。
    - 验证：`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] field address / load / store。
    - 阻塞：当前实际 PortableMIR 数据模型和 verifier（`src/lower/mir.uya`、`src/lower/mir_verifier.uya`）没有 `MIR_INST_OP_FIELD_ADDR` 或 field operand/index instruction；`MIR_INST_OP_FIELD_ADDR` 只在 `src/lower/mir_contract.uya` 作为 lowering contract 常量出现。MIR-C99 后端不能消费 contract-only opcode 伪装 field address/load/store 支持。
    - 验证：`rg -n "MIR_INST_OP_FIELD_ADDR|FIELD_ADDR|field_start|field_count" src/lower/mir.uya src/lower/mir_verifier.uya src/lower/mir_contract.uya src/codegen/mir_c99 -S` 确认只有 type metadata 和 contract-only opcode；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] array index address / load / store。
    - 阻塞：当前实际 PortableMIR 数据模型和 verifier 没有 `MIR_INST_OP_INDEX_ADDR` 或 array index address instruction；`MIR_INST_OP_INDEX_ADDR` 只在 `src/lower/mir_contract.uya` 作为 lowering contract 常量出现。MIR-C99 后端不能消费 contract-only opcode 伪装 array index address/load/store 支持。
    - 验证：`rg -n "MIR_INST_OP_.*INDEX|INDEX_ADDR|ARRAY|SLICE|CORE_PLACE_KIND_INDEX|index address|element_type_id|lane_count" src/lower/mir.uya src/lower/mir_verifier.uya src/lower/mir_contract.uya src/codegen/mir_c99 -S` 确认实际 MIR/verifier 无 index address opcode；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] slice ptr/len load。
    - 阻塞：当前实际 PortableMIR 数据模型和 verifier 没有 `MIR_INST_OP_SLICE_PTR_ADDR` / `MIR_INST_OP_SLICE_LEN_ADDR` 或 slice ptr/len instruction；这两个 opcode 只在 `src/lower/mir_contract.uya` 作为 lowering contract 常量出现。MIR-C99 后端不能消费 contract-only opcode 伪装 slice ptr/len load 支持。
    - 验证：`rg -n "MIR_INST_OP_SLICE|SLICE_PTR_ADDR|SLICE_LEN_ADDR|CORE_PLACE_KIND_SLICE|slice ptr|slice len|MIR_TYPE_KIND_STRUCT|element_type_id" src/lower/mir.uya src/lower/mir_verifier.uya src/lower/mir_contract.uya src/codegen/mir_c99 -S` 确认实际 MIR/verifier 无 slice ptr/len opcode；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] aggregate copy / move 的最小 `memcpy` helper。
    - 阻塞：当前实际 PortableMIR 数据模型和 verifier 没有 `MIR_INST_OP_COPY` / `MIR_INST_OP_MOVE`，也没有 MIR 显式 memcpy helper capability；`MIR_INST_OP_COPY` / `MIR_INST_OP_MOVE` 只在 `src/lower/mir_contract.uya` 作为 lowering contract 常量出现。MIR-C99 后端不能提前发明 aggregate copy/move 或隐式接入 memcpy。
    - 验证：`rg -n "MEMCPY|memcpy|COPY|MOVE|AGGREGATE|aggregate|MIR_INST_OP_.*COPY|MIR_INST_OP_.*MOVE|helper" src/lower/mir.uya src/lower/mir_verifier.uya src/lower/mir_contract.uya src/codegen/mir_c99 docs/todo_mir_c99_backend.md -S` 确认实际 MIR/verifier 无 copy/move opcode；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [ ] parity shard：struct field、array index、slice index、out-param writeback。
    - 阻塞：当前无真实 MIR-C99 generator command/CLI，`tests/verify_mir_c99_oracle_parity_harness.sh` 仍停在 pending backend hookup；同时本 shard 依赖的 field/index/slice/copy-out/out-param 写回对应 MIR opcode 或 helper 均未进入实际 MIR/verifier，不能生成 host C compiler 可编译运行的 parity 用例。
    - 验证：`bash tests/verify_mir_c99_oracle_parity_harness.sh` 仅确认 harness installed/pending backend hookup；field/index/slice/copy leaf 已分别记录实际 MIR/verifier 缺口；不能作为 parity 通过证据。

### 4.7 Types / Layout

- [ ] MIR-C99-BACKEND-TYPES-LAYOUT：用 MIR/layout metadata 生成最小 C 类型。
  - [x] scalar typedef 映射：`i8/u8/i16/u16/i32/u32/i64/u64/usize/isize/bool/byte/f32/f64`。
    - [x] 当前 MIR scalar typedef：`bool` / `i32` / `usize`。
      - 验证：`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过，确认 `src/codegen/mir_c99/types.uya` 从实际 `MIR_TYPE_KIND_BOOL` / `MIR_TYPE_KIND_I32` / `MIR_TYPE_KIND_USIZE` 映射到 `MIR_C99_C_TYPE_KIND_BOOL` / `MIR_C99_C_TYPE_KIND_I32` / `MIR_C99_C_TYPE_KIND_USIZE`，保留 `size_bytes` / `align_bytes` metadata，且 driver 构建并报告 type plan；`bin/uya check` 对拼接后的 MIR-C99 子模块通过。
    - [x] MIR scalar type kind 缺口记录：`i8/u8/i16/u16/u32/i64/u64/isize/byte/f32/f64` 尚未进入实际 PortableMIR。
      - 验证：`bash tests/verify_mir_c99_type_scalar_gap.sh` 通过，确认 `src/lower/mir.uya` 尚无 `MIR_TYPE_KIND_I8` / `MIR_TYPE_KIND_U8` / `MIR_TYPE_KIND_I16` / `MIR_TYPE_KIND_U16` / `MIR_TYPE_KIND_U32` / `MIR_TYPE_KIND_I64` / `MIR_TYPE_KIND_U64` / `MIR_TYPE_KIND_ISIZE` / `MIR_TYPE_KIND_BYTE` / `MIR_TYPE_KIND_F32` / `MIR_TYPE_KIND_F64`，且 `src/codegen/mir_c99/types.uya` 未声明对应 MIR-C99 C type kind；因此本项只收口当前实际 PortableMIR scalar coverage，不提前发明缺失 type kind。
  - [x] pointer、array、slice struct。
    - [x] 当前 MIR pointer typedef：`MIR_TYPE_KIND_POINTER`。
      - 验证：`bash tests/verify_mir_c99_type_pointer_plan.sh` 通过，确认 `src/lower/mir.uya` 存在 `MIR_TYPE_KIND_POINTER` 和 `pointee_type_id` metadata，`src/lower/mir_verifier.uya` 校验 pointer 的 pointee type，`src/codegen/mir_c99/types.uya` 映射到 `MIR_C99_C_TYPE_KIND_POINTER` 并复制 `pointee_type_id`；`bin/uya check` 对拼接后的 MIR-C99 子模块通过。
    - [x] MIR array/slice type kind 缺口记录：`MIR_TYPE_KIND_ARRAY` / `MIR_TYPE_KIND_SLICE` 尚未进入实际 PortableMIR。
      - 验证：`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过，确认 `src/lower/mir.uya` / `src/lower/mir_verifier.uya` 尚无 `MIR_TYPE_KIND_ARRAY` / `MIR_TYPE_KIND_SLICE`，`src/codegen/mir_c99/types.uya` 未声明对应 MIR-C99 C type kind；当前仅保留 `element_type_id` metadata，不能提前生成 array/slice struct typedef。
  - [ ] struct / union / enum layout，字段顺序和 size/align 与现有 C99 oracle 对齐。
  - [ ] float/double 在 struct、array、slice、return value 和参数中的 size/align 与现有 C99 oracle 对齐。
  - [ ] error union layout。
  - [ ] function type / function pointer。
  - [ ] layout compile-time check 只能使用可移植 C99 形式，不依赖 C11 `_Static_assert` 或 GCC-only 语义。
  - [ ] parity shard：`@size_of` / `@align_of` / struct-array-slice layout。

### 4.8 Calls / ABI

- [ ] MIR-C99-BACKEND-CALLS：实现 MIR call 到 C call。
  - [ ] Uya direct call。
  - [ ] extern function call。
  - [ ] method call / monomorphized concrete call symbol。
  - [ ] function pointer call。
  - [ ] float/double 参数和返回值按 host C ABI 表达；缺少 ABI metadata 时明确 reject。
  - [ ] return value / out-param / aggregate return lowering。
  - [ ] call ABI metadata 缺失时明确 reject。
  - [ ] parity shard：multi-arg call、extern object call、method dispatch、generic instance call。
  - [ ] parity shard：float/double 参数、返回值、extern call。

### 4.9 Runtime Helpers

- [ ] MIR-C99-BACKEND-RUNTIME-HELPERS：只接入 MIR 显式要求的 helper。
  - [ ] `memcpy` / `memset` / `memcmp` / string primitive helper。
  - [ ] print/println 最小 stdout helper。
  - [ ] malloc/free/env/file IO runtime capability helper。
  - [ ] async frame runtime helper：poll、resume、await bind、frame allocation/free 和 async-frame-heap fallback。
  - [ ] `@syscall` capability：按 target profile 明确分流，不静默 fallback。
  - [ ] helper registry 由 MIR capability/helper refs 驱动，不做 AST helper discovery。
  - [ ] parity shard：HelloWorld、format minimal、memory/string primitive、file IO、async runtime smoke。

### 4.10 Atomics / SIMD / Capability

- [ ] MIR-C99-BACKEND-ATOMICS：显式处理 `atomic T`，不把 C99 当作隐式原子语义提供者。
  - [ ] MIR atomic init/read/write 必须落到明确 runtime helper 或 target capability，不能用普通 C 赋值伪装原子。
  - [ ] 若当前 target 没有 portable helper，MIR-C99 必须给 capability diagnostic，并与现有 C99 oracle 的预期成功/失败策略记录到覆盖矩阵。
  - [ ] parity/reject shard：atomic i32 init/write/read；支持前可明确 reject，支持后必须与 oracle 行为一致。
  - [ ] SIMD vector/mask 支持前必须明确 reject；支持后必须与现有 C99 oracle 行为一致。

### 4.11 Cleanup / Error

- [ ] MIR-C99-BACKEND-CLEANUP-ERROR：消费 MIR cleanup CFG。
  - [ ] `try` / `catch` 已展开到 MIR 后，C99 只输出对应 CFG。
  - [ ] `defer` / `errdefer` / lexical drop 只按 MIR cleanup edge 输出，不重新理解 AST。
  - [ ] error union success/fallback return。
  - [ ] parity shard：dynamic catch、defer local assign、lexical drop。

### 4.12 Async

- [ ] MIR-C99-BACKEND-ASYNC-FRAME：支持 async frame，不允许以首版 reject 代替。
  - [ ] 从 MIR/Core capability metadata 生成 async frame struct layout、state tag、result slot、await child slot 和 captured locals。
  - [ ] 生成 poll/resume state machine 的低级 C label/goto 形态，不回查 AST async body。
  - [ ] 支持 `await` / bind / direct await / loop await 的 frame 状态保存与恢复。
  - [ ] 支持 async error union return、cleanup edge、defer/errdefer 与 frame release。
  - [ ] 支持 async frame pool 和 `--async-frame-heap=on` fallback，行为与现有 C99 oracle 对齐。
  - [ ] parity shard：`tests/test_async_*.uya` 中当前 make check 覆盖的 async 用例必须 MIR-C99 / 现有 C99 oracle 一致。

### 4.13 Globals / Imports

- [ ] MIR-C99-BACKEND-GLOBALS-IMPORTS：全局和链接输入。
  - [ ] global scalar / aggregate initializer。
  - [ ] string constants 和 dedupe。
  - [ ] extern globals。
  - [ ] `@c_import` sidecar object / cflags / ldflags 进入 MirC99 link plan，不复用现有 C99 sidecar 脚本作为内部实现。
  - [ ] parity shard：global aggregate、extern global、最小 `@c_import`。

### 4.14 Split-C / Build Manifest

- [ ] MIR-C99-BACKEND-SPLIT-C：在单 unit 稳定后扩到多 unit。
  - [ ] `MirC99Unit[]` 按 module/source/function group 分配。
  - [ ] 生成独立 header / prototypes / deps。
  - [ ] 生成 MIR-C99 专用 Makefile 或 build manifest，不调用现有 split-C writer。
  - [ ] unit fingerprint 稳定，空白和路径差异不影响结构性摘要。
  - [ ] parity shard：多文件模块、parallel make、cache lock/stale lock 策略复验。

### 4.15 Full Language Parity

- [ ] MIR-C99-BACKEND-PARITY-MATRIX：把完整语言样本逐项迁为 MIR-C99 / 现有 C99 oracle parity。
  - [ ] return/local/binary/branch/loop。
  - [ ] float/double literal、arithmetic、comparison、cast、call ABI。
  - [ ] multi-file module/use/import alias。
  - [ ] struct/union/enum/tuple。
  - [ ] array/slice/pointer。
  - [ ] generic function / generic struct / method instance。
  - [ ] interface/vtable。
  - [ ] error union / try / catch。
  - [ ] defer / errdefer / drop。
  - [ ] atomic。
  - [ ] SIMD vector/mask，target 不支持时明确 reject。
  - [ ] async frame / await / async error union / async cleanup；这些必须支持，不能作为首版 reject。

### 4.16 Self Build

- [ ] MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。
  - [ ] `cmd/build` / compiler source 经 parser/checker/CoreBody/PortableMIR 生成 minimal C99。
  - [ ] host C compiler 编译 MIR-C99 产物得到 compiler binary。
  - [ ] MIR-C99-built compiler 复跑 `cmd/build` self-build。
  - [ ] MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity。
  - [ ] absence gate 确认整个自举过程中未调用现有 AST C99 backend 作为 MIR-C99 成功路径。

### 4.17 Release Gates

- [ ] MIR-C99-BACKEND-RELEASE-GATES：收口和文档同步。
  - [ ] `make check` / `make check-hosted` 增加 MIR-C99 可选或必选门禁，按阶段切换。
  - [ ] release flow 区分现有 C99 oracle、MIR-C99 backend 和 microapp profile 结论。
  - [ ] backup flow 保留现有 C99 seed，新增 MIR-C99 seed 只在自举稳定后进入。
  - [ ] 文档同步：`docs/compiler_1s_architecture_design.md`、`docs/portable_mir_whitepaper.md`、`docs/coreir_lowered_program_whitepaper.md`、`docs/portable_mir_language_coverage.md`。

---

## 5. 评审结论

本 TODO 按当前目标评审后，固定以下裁定：

- 当前第一叶子是 `MIR-C99-BACKEND-CONTRACTS`，不是 HelloWorld 实现。
- HelloWorld 是第一个端到端 parity 目标，但必须在独立边界、最小 C99 子集和 oracle harness 落地后执行。
- async frame 属于完整 Uya 语法支持范围，不能作为 MIR-C99 首版长期 reject。
- 任何以现有 C99 emitter 成功、fixed-shape smoke 成功或 self-build helper 成功为证据的条目都不得标成 `[x]`。
- `docs/todo_compiler_1s.md` 只保留上层里程碑；本文件是 MIR-C99 后端的细粒度状态来源。
