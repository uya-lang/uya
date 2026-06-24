# MIR-C99 Backend Completed Archive

**来源**: `docs/todo_mir_c99_backend.md`
**整理日期**: 2026-06-13
**说明**: 本文件保存从主 TODO 移出的 `[x]` 完成项及其原始验证记录；未完成 `[ ]`、进行中 `[~]`、失败 `[f]` 项仍留在主 TODO。

---

## 任务清单完成项

以下任务必须优先于对应 MIR-C99 backend leaf 完成；后端只能消费实际 `src/lower/mir.uya` / `src/lower/mir_verifier.uya` 中存在并可验证的 MIR type、opcode、metadata 和 capability，不能消费 `src/lower/mir_contract.uya` 中 contract-only 常量伪装支持。

### 4.0 PortableMIR 前置缺口清单

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

- [x] MIR-C99-PREMIR-PLACE-OPS：补齐 place/address opcode。
  - [x] local/global/param address opcode，并明确 address value 与 local slot 的生命周期约束。
    - 验证：`bash tests/verify_portable_mir_address_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 local/param/global address 正例和 local 未标记 address-taken 反例，断言数 53）；`bash tests/verify_mir_c99_type_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] field address / load / store opcode：field id/index、base operand、result pointer type、bounds verifier。
    - 验证：`bash tests/verify_portable_mir_field_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 field addr/load/store 正例和 field index 越界反例，断言数 57）；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] array index address / load / store opcode：index operand、element type、bounds/capability metadata。
    - 验证：`bash tests/verify_portable_mir_index_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 index addr/load/store 静态正例、动态 index 带 bounds flag 正例和动态 index 缺 bounds flag 反例，断言数 62）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] slice ptr / len / index address opcode：ptr/len field access、indexing、result type verifier。
    - 验证：`bash tests/verify_portable_mir_slice_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 slice ptr addr/load、len addr/load、index addr/load/store 正例和 slice index 缺 bounds flag 反例，断言数 70）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] pointer offset opcode：element stride、signed/usize offset、overflow/capability 策略。
    - 验证：`bash tests/verify_portable_mir_pointer_offset_opcode.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 overflow checked pointer offset 正例和缺 overflow flag 反例，断言数 72）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] aggregate copy / move opcode 或显式 memcpy helper capability：size/align/source/dest overlap 语义必须可验证。
    - 验证：`bash tests/verify_portable_mir_aggregate_copy_move_opcode.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 aggregate copy/move no-overlap 正例和缺 no-overlap flag 反例，断言数 75）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

- [x] MIR-C99-PREMIR-CALL-ABI：补齐 call 和 ABI metadata。
  - [x] direct call、extern call、method/monomorphized call、function pointer call 的 callee 表达形式。
    - 验证：`bash tests/verify_portable_mir_call_target_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 direct/extern/method-instance/function-pointer call target 正例和 callee kind 缺失/不匹配反例，断言数 80）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_type_function_signature.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 多参数、aggregate return、out-param writeback、error union return、float/double ABI class metadata。
    - 验证：`bash tests/verify_portable_mir_call_abi_metadata_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 multi-param、aggregate return/out-param writeback、error union return、f32/f64 call ABI metadata 正例和 f64 ABI class 错配反例，断言数 85）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_type_function_signature.sh` 通过；`bash tests/verify_portable_mir_call_target_inventory.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。额外探测：`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_parallel_determinism.sh` 失败于既有 host C 链接 `CLOCKS_PER_SEC` 重定义；`bash tests/verify_native_mir_emitter.sh` 失败于既有静态证据 `architecture native MIR emitter` 缺失。
  - [x] call ABI 缺失时 verifier 必须 reject，不能留给 MIR-C99 后端猜测。
    - 验证：`bash tests/verify_portable_mir_verifier.sh` 通过（新增 call 缺 callee/signature、缺 multi-param flag、缺 aggregate out-param flag、缺 error-union flag、缺 float ABI flag、out-param operand 缺 writeback 标记反例，断言数 90）；`bash tests/verify_portable_mir_call_abi_metadata_inventory.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_portable_mir_call_target_inventory.sh` 通过；`bash tests/verify_mir_c99_type_function_signature.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。

- [x] MIR-C99-PREMIR-RUNTIME-CAPABILITY：补齐 runtime helper/capability refs。
  - [x] `memcpy` / `memset` / `memcmp` / string primitive helper refs。
    - 验证：`bash tests/verify_portable_mir_runtime_memory_helpers.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（hosted profile 支持 memory/string helper capability，freestanding 拒绝 `MIR_RUNTIME_HELPER_MEMCPY` capability ref，断言数 34）；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 90）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_target_metadata.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] print/println、malloc/free、env/file IO、syscall capability refs。
    - 验证：`bash tests/verify_portable_mir_runtime_io_syscall_helpers.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（hosted profile 支持 print/heap/env-file helper capability，freestanding 支持 syscall 并拒绝 hosted-only caps，断言数 52）；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 90）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。额外探测：`bash tests/verify_native_mir_emitter.sh` 失败于既有静态证据 `architecture native MIR emitter` 缺失。
  - [x] atomic init/load/store/RMW/CMPXCHG opcode 或 helper capability；普通 load/store 不得伪装原子。
    - 验证：`bash tests/verify_portable_mir_atomic_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 atomic init/load/store/RMW/CMPXCHG 正例、普通 load/store atomic type 反例、atomic 缺 ordered metadata 反例和 cmpxchg operand 缺失反例，断言数 99）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] SIMD vector/mask load/store/splat/select opcode 或明确 capability reject。
    - 验证：`bash tests/verify_portable_mir_vector_mask_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 vector splat/load/store/select 正例、scalar type 反例、vector store result 反例和 vector select operand 缺失反例，断言数 106）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

- [x] MIR-C99-PREMIR-CLEANUP-ASYNC：补齐 cleanup/error/async MIR 表达。
  - [x] `defer` / `errdefer` / lexical drop 的 cleanup edge、drop opcode 和 unwind/error path metadata。
    - 验证：`bash tests/verify_portable_mir_cleanup_drop_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 drop value/drop in place 正例、return+error+unwind cleanup model 正例、未知 cleanup model 反例和 drop result 反例，断言数 111）；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] `try` / `catch` / error union success/failure CFG 形态和 verifier 规则。
    - 验证：`bash tests/verify_portable_mir_error_union_cfg_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 error-union ok/err/is_err/payload/error 正例和 payload 未经 checked tag path 反例，断言数 117）；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] async frame metadata：state tag、result slot、await child slot、captured locals、poll/resume edge、frame allocation/free capability。
    - 验证：`bash tests/verify_portable_mir_async_frame_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 async frame alloc/free/state load/state store/await child slot/poll/resume/result load 正例、alloc 缺 async frame capability 反例、poll result type 反例和 result load void 反例，断言数 128）；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过（新增 async frame metadata 动态表 append/growth 断言，断言数 973）；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。

- [x] MIR-C99-PREMIR-GLOBALS-IMPORTS：补齐 global/import MIR 表达。
  - [x] global scalar / aggregate initializer、string constants、dedupe id 和 section/linkage metadata。
    - 验证：`bash tests/verify_portable_mir_global_initializer_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 global scalar/aggregate/string initializer 正例和 string 缺 dedupe 反例，断言数 132）；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过（新增 global/const 动态表 append/growth 断言，断言数 1125）；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。
  - [x] extern globals、C import object/link inputs、symbol visibility 和 target profile metadata。
    - 验证：`bash tests/verify_portable_mir_extern_link_inputs_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 extern global、C import link input 正例和 target profile 不匹配反例，断言数 135）；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过（新增 link input 动态表 append/growth 断言，断言数 1201）；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。
  - [x] split-C 多 unit 所需的 cross-unit symbol/export/import/ref metadata。
    - 验证：`bash tests/verify_portable_mir_cross_unit_symbol_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（新增 cross-unit function export、global import 正例和 invalid unit 反例，断言数 138）；`bash tests/verify_portable_mir_dynamic_tables.sh` 通过（新增 cross-unit symbol 动态表 append/growth 断言，断言数 1277）；`bash tests/verify_portable_mir_lowering_contract.sh` 通过；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_portable_mir_backend_interface.sh` 通过；`bash tests/verify_portable_mir_naked_fn.sh` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。

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

- [x] MIR-C99-BACKEND-UNIT-OUTPUT：先实现单 unit，保留多 unit 扩展点。
  - [x] 支持单 `.c` 输出：include、typedef、extern prototype、function prototype、global、function body。
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
  - [x] 新增 smoke：return literal 经 MIR-C99 生成 `.c`，host C compiler 编译运行，exit 与现有 C99 oracle 一致。
    - 验证：`bash tests/verify_mir_c99_return_literal_parity.sh` 通过，覆盖 `export fn main() i32 { return 7; }` 经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.4 CFG

- [x] MIR-C99-BACKEND-CFG：把 MIR CFG 映射到低级 C99。
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
  - [x] parity shard：local init + if return / nested branch / loop backedge。
    - 验证：`bash tests/verify_mir_c99_cfg_parity.sh` 通过，覆盖 local init + if return、nested branch、while loop backedge 三个 case，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_return_literal_parity.sh` 通过；`bash tests/verify_mir_c99_lexical_drop_parity.sh` 通过；`bash tests/verify_mir_c99_defer_local_assign_parity.sh` 通过；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.5 Values

- [x] MIR-C99-BACKEND-VALUES：把 MIR value/local 映射到 C temp。
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
  - [x] cast、sign/zero extend、truncate，以及 int/float/double 显式转换。
    - 验证：`bash tests/verify_portable_mir_conversion_opcode_inventory.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过（`MIR_C99_EXPR_KIND_CONVERSION` 和 `portable_mir_inst_op_is_conversion` 覆盖 conversion family，checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过。
  - [x] value def/use 顺序检查：未定义或跨 block 非法 use 必须由 verifier 阻止。
    - 验证：`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：integer arithmetic/comparison/boolean combination。
    - 验证：`bash tests/verify_mir_c99_integer_value_parity.sh` 通过，覆盖 i32 加减 temp 链、比较结果经 `&&` / `||` 组合后分支返回，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_cfg_parity.sh` 通过；`bash tests/verify_mir_c99_return_literal_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：float/double arithmetic、comparison、cast 和 return。
    - 验证：`bash tests/verify_mir_c99_float_value_parity.sh` 通过，覆盖 f32/f64 算术、f32 to f64 cast、f64 to i32 cast、f64 比较和 i32 return，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_integer_value_parity.sh` 通过；`bash tests/verify_mir_c99_cfg_parity.sh` 通过；`bash tests/verify_mir_c99_return_literal_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.6 Place / Memory

- [x] MIR-C99-BACKEND-PLACE-MEMORY：把 MIR place/load/store 映射到 C 地址和赋值。
  - [x] local slot address、load、store。
    - 验证：`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] pointer deref load/store。
    - 验证：`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] field address / load / store。
    - 验证：`bash tests/verify_mir_c99_place_field_plan.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_portable_mir_field_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] array index address / load / store。
    - 验证：`bash tests/verify_mir_c99_place_index_plan.sh` 通过；`bash tests/verify_mir_c99_place_field_plan.sh` 通过；`bash tests/verify_mir_c99_place_local_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_portable_mir_index_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_constant_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_use_order.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] slice ptr/len load。
    - 验证：`bash tests/verify_mir_c99_place_slice_ptr_len_plan.sh` 通过；`bash tests/verify_mir_c99_place_index_plan.sh` 通过；`bash tests/verify_mir_c99_place_field_plan.sh` 通过；`bash tests/verify_mir_c99_place_pointer_plan.sh` 通过；`bash tests/verify_portable_mir_slice_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] aggregate copy / move 的最小 `memcpy` helper。
    - 验证：`bash tests/verify_mir_c99_place_aggregate_copy_move_plan.sh` 通过；`bash tests/verify_mir_c99_place_slice_ptr_len_plan.sh` 通过；`bash tests/verify_mir_c99_place_index_plan.sh` 通过；`bash tests/verify_mir_c99_place_field_plan.sh` 通过；`bash tests/verify_portable_mir_aggregate_copy_move_opcode.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_reject_unverified.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：struct field、array index、slice index、out-param writeback。
    - 验证：`bash tests/verify_mir_c99_place_memory_parity.sh` 通过，覆盖 struct field load/store、array index、slice index 和 `*out = value` out-param 写回，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_float_value_parity.sh` 通过；`bash tests/verify_mir_c99_integer_value_parity.sh` 通过；`bash tests/verify_mir_c99_cfg_parity.sh` 通过；`bash tests/verify_mir_c99_return_literal_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.7 Types / Layout

- [x] MIR-C99-BACKEND-TYPES-LAYOUT：用 MIR/layout metadata 生成最小 C 类型。
  - [x] scalar typedef 映射：`i8/u8/i16/u16/i32/u32/i64/u64/usize/isize/bool/byte/f32/f64`。
    - [x] 当前 MIR scalar typedef：`bool` / `i32` / `usize`。
      - 验证：`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过，确认 `src/codegen/mir_c99/types.uya` 从实际 `MIR_TYPE_KIND_BOOL` / `MIR_TYPE_KIND_I32` / `MIR_TYPE_KIND_USIZE` 映射到 `MIR_C99_C_TYPE_KIND_BOOL` / `MIR_C99_C_TYPE_KIND_I32` / `MIR_C99_C_TYPE_KIND_USIZE`，保留 `size_bytes` / `align_bytes` metadata，且 driver 构建并报告 type plan；`bin/uya check` 对拼接后的 MIR-C99 子模块通过。
    - [x] MIR scalar type kind 覆盖：`i8/u8/i16/u16/u32/i64/u64/isize/byte/f32/f64` 已进入实际 PortableMIR，并由 MIR-C99 type plan 保留 size/align metadata。
      - 验证：`bash tests/verify_mir_c99_type_scalar_gap.sh` 通过，确认 `src/lower/mir.uya` 存在 `MIR_TYPE_KIND_I8` / `MIR_TYPE_KIND_U8` / `MIR_TYPE_KIND_I16` / `MIR_TYPE_KIND_U16` / `MIR_TYPE_KIND_U32` / `MIR_TYPE_KIND_I64` / `MIR_TYPE_KIND_U64` / `MIR_TYPE_KIND_ISIZE` / `MIR_TYPE_KIND_BYTE` / `MIR_TYPE_KIND_F32` / `MIR_TYPE_KIND_F64`，`src/codegen/mir_c99/types.uya` 声明并映射对应 MIR-C99 C type kind，且 verifier 校验 scalar size/align。
  - [x] pointer、array、slice struct。
    - [x] 当前 MIR pointer typedef：`MIR_TYPE_KIND_POINTER`。
      - 验证：`bash tests/verify_mir_c99_type_pointer_plan.sh` 通过，确认 `src/lower/mir.uya` 存在 `MIR_TYPE_KIND_POINTER` 和 `pointee_type_id` metadata，`src/lower/mir_verifier.uya` 校验 pointer 的 pointee type，`src/codegen/mir_c99/types.uya` 映射到 `MIR_C99_C_TYPE_KIND_POINTER` 并复制 `pointee_type_id`；`bin/uya check` 对拼接后的 MIR-C99 子模块通过。
    - [x] MIR array/slice type kind 缺口记录：`MIR_TYPE_KIND_ARRAY` / `MIR_TYPE_KIND_SLICE` 尚未进入实际 PortableMIR。
      - 验证：`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过，确认 `src/lower/mir.uya` / `src/lower/mir_verifier.uya` 尚无 `MIR_TYPE_KIND_ARRAY` / `MIR_TYPE_KIND_SLICE`，`src/codegen/mir_c99/types.uya` 未声明对应 MIR-C99 C type kind；当前仅保留 `element_type_id` metadata，不能提前生成 array/slice struct typedef。
  - [x] struct / union / enum layout，字段顺序和 size/align 与现有 C99 oracle 对齐。
    - 验证：`bash tests/verify_mir_c99_type_aggregate_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_field_layout.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过；`bash tests/verify_mir_c99_type_pointer_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_structs.sh` 通过；`bash tests/verify_mir_c99_type_array_slice_gap.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] float/double 在 struct、array、slice、return value 和参数中的 size/align 与现有 C99 oracle 对齐。
    - 验证：`bash tests/verify_mir_c99_type_float_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_aggregate_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过；`bash tests/verify_mir_c99_type_function_signature.sh` 通过；`bash tests/verify_portable_mir_float_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] error union layout。
    - 验证：`bash tests/verify_mir_c99_type_error_union_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_error_union_layout.sh` 通过；`bash tests/verify_mir_c99_type_aggregate_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_float_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_function_signature.sh` 通过；`bash tests/verify_mir_c99_type_scalar_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] function type / function pointer。
    - 验证：`bash tests/verify_mir_c99_type_function_signature_plan.sh` 通过；`bash tests/verify_mir_c99_type_function_signature.sh` 通过；`bash tests/verify_mir_c99_type_error_union_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_float_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_aggregate_layout_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（断言数 52）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] layout compile-time check 只能使用可移植 C99 形式，不依赖 C11 `_Static_assert` 或 GCC-only 语义。
    - 验证：`bash tests/verify_mir_c99_type_layout_check_plan.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_type_aggregate_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_error_union_layout_plan.sh` 通过；`bash tests/verify_mir_c99_type_function_signature_plan.sh` 通过；`bash tests/verify_mir_c99_type_float_layout_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：`@size_of` / `@align_of` / struct-array-slice layout。
    - 验证：`bash tests/verify_mir_c99_layout_parity.sh` 通过，覆盖 `@size_of` / `@align_of` 对 struct、array value 和 slice value 的布局 checksum，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`bash tests/verify_mir_c99_float_value_parity.sh` 通过；`bash tests/verify_mir_c99_integer_value_parity.sh` 通过；`bash tests/verify_mir_c99_cfg_parity.sh` 通过；`bash tests/verify_mir_c99_return_literal_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.8 Calls / ABI

- [x] MIR-C99-BACKEND-CALLS：实现 MIR call 到 C call。
  - [x] Uya direct call。
    - 验证：`bash tests/verify_mir_c99_call_direct_plan.sh` 通过；`bash tests/verify_portable_mir_call_target_inventory.sh` 通过；`bash tests/verify_portable_mir_call_abi_metadata_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] extern function call。
    - 验证：`bash tests/verify_mir_c99_call_extern_plan.sh` 通过；`bash tests/verify_mir_c99_call_direct_plan.sh` 通过；`bash tests/verify_portable_mir_call_target_inventory.sh` 通过；`bash tests/verify_portable_mir_call_abi_metadata_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。
  - [x] method call / monomorphized concrete call symbol。
    - 验证：`bash tests/verify_mir_c99_call_method_plan.sh` 通过；`bash tests/verify_mir_c99_call_direct_plan.sh` 通过；`bash tests/verify_mir_c99_call_extern_plan.sh` 通过；`bash tests/verify_portable_mir_call_target_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
  - [x] function pointer call。
    - 验证：`bash tests/verify_mir_c99_call_function_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_call_direct_plan.sh` 通过；`bash tests/verify_mir_c99_call_extern_plan.sh` 通过；`bash tests/verify_mir_c99_call_method_plan.sh` 通过；`bash tests/verify_portable_mir_call_target_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] float/double 参数和返回值按 host C ABI 表达；缺少 ABI metadata 时明确 reject。
    - 验证：`bash tests/verify_mir_c99_call_float_abi_plan.sh` 通过；`bash tests/verify_mir_c99_call_direct_plan.sh` 通过；`bash tests/verify_mir_c99_call_extern_plan.sh` 通过；`bash tests/verify_mir_c99_call_method_plan.sh` 通过；`bash tests/verify_mir_c99_call_function_pointer_plan.sh` 通过；`bash tests/verify_portable_mir_call_abi_metadata_inventory.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（断言数 52）；`bash tests/verify_mir_c99_type_function_signature_plan.sh` 通过；`bash tests/verify_mir_c99_type_float_layout_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] return value / out-param / aggregate return lowering。
    - 验证：`bash tests/verify_mir_c99_call_return_lowering_plan.sh` 通过；`bash tests/verify_mir_c99_call_float_abi_plan.sh` 通过；`bash tests/verify_mir_c99_call_function_pointer_plan.sh` 通过；`bash tests/verify_mir_c99_call_direct_plan.sh` 通过；`bash tests/verify_mir_c99_call_extern_plan.sh` 通过；`bash tests/verify_mir_c99_call_method_plan.sh` 通过；`bash tests/verify_portable_mir_call_abi_metadata_inventory.sh` 通过；`bash tests/verify_mir_c99_type_aggregate_layout_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] call ABI metadata 缺失时明确 reject。
    - 验证：`bash tests/verify_mir_c99_call_abi_metadata_reject_plan.sh` 通过；`bash tests/verify_mir_c99_call_return_lowering_plan.sh` 通过；`bash tests/verify_mir_c99_call_float_abi_plan.sh` 通过；`bash tests/verify_mir_c99_call_direct_plan.sh` 通过；`bash tests/verify_mir_c99_call_extern_plan.sh` 通过；`bash tests/verify_mir_c99_call_method_plan.sh` 通过；`bash tests/verify_mir_c99_call_function_pointer_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_portable_mir_golden.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：multi-arg call、extern object call、method dispatch、generic instance call。
    - [x] multi-arg call、method dispatch、generic instance call 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_call_parity.sh` 通过，覆盖 multi-arg direct call、method dispatch 和 generic i32 instance，由默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_layout_parity.sh` 通过；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`bash tests/verify_mir_c99_float_value_parity.sh` 通过；`bash tests/verify_mir_c99_integer_value_parity.sh` 通过；`bash tests/verify_mir_c99_cfg_parity.sh` 通过；`bash tests/verify_mir_c99_return_literal_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] extern object call 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_extern_object_call_parity.sh` 通过，覆盖最小 `@c_import("c_import/add.c")` + `extern fn add_i32(a: i32, b: i32) i32` 的 extern object call，由默认 MIR-C99 generator 写出主 `.c` 与 `*.cimports.sh` sidecar，经 parity harness 编译 sidecar C object 后链接运行，并与默认现有 C99 oracle generator 的 `.c` + sidecar 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_call_parity.sh` 通过；`bash tests/verify_mir_c99_layout_parity.sh` 通过；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：float/double 参数、返回值、extern call。
    - 验证：`bash tests/verify_mir_c99_float_call_parity.sh` 通过，覆盖 f32/f64 参数、本地 f64/f32 返回值、`@c_import("c_import/float_ops.c")` + `extern fn extern_mix(a: f32, b: f64) f64` 的 extern float/double call，由默认 MIR-C99 generator 写出主 `.c` 与 `*.cimports.sh` sidecar，经 parity harness 编译 sidecar C object 后链接运行，并与默认现有 C99 oracle generator 的 `.c` + sidecar 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_extern_object_call_parity.sh` 通过；`bash tests/verify_mir_c99_call_parity.sh` 通过；`bash tests/verify_mir_c99_float_value_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.9 Runtime Helpers

- [x] MIR-C99-BACKEND-RUNTIME-HELPERS：只接入 MIR 显式要求的 helper。
  - [x] `memcpy` / `memset` / `memcmp` / string primitive helper。
    - 验证：`bash tests/verify_mir_c99_runtime_memory_helper_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_portable_mir_runtime_memory_helpers.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（断言数 52）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] print/println 最小 stdout helper。
    - 验证：`bash tests/verify_mir_c99_runtime_print_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_memory_helper_plan.sh` 通过；`bash tests/verify_portable_mir_runtime_io_syscall_helpers.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（断言数 52）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] malloc/free/env/file IO runtime capability helper。
    - 验证：`bash tests/verify_mir_c99_runtime_heap_env_file_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_print_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_memory_helper_plan.sh` 通过；`bash tests/verify_portable_mir_runtime_io_syscall_helpers.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（断言数 52）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] async frame runtime helper：poll、resume、await bind、frame allocation/free 和 async-frame-heap fallback。
    - 验证：`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_heap_env_file_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_print_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_memory_helper_plan.sh` 通过；`bash tests/verify_portable_mir_async_frame_inventory.sh` 通过；`bash tests/verify_portable_mir_runtime_io_syscall_helpers.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（断言数 52）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：本叶完成 MIR async frame op/capability 的 runtime helper ref plan；完整 async frame C state machine、pool 与 `--async-frame-heap=on` 行为仍在 4.12 `MIR-C99-BACKEND-ASYNC-FRAME` 下跟踪。
  - [x] `@syscall` capability：按 target profile 明确分流，不静默 fallback。
    - 验证：`bash tests/verify_mir_c99_runtime_syscall_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_heap_env_file_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_print_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_memory_helper_plan.sh` 通过；`bash tests/verify_portable_mir_runtime_io_syscall_helpers.sh` 通过；`bash tests/verify_portable_mir_call_abi_profile.sh` 通过（断言数 52）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] helper registry 由 MIR capability/helper refs 驱动，不做 AST helper discovery。
    - 验证：`bash tests/verify_mir_c99_runtime_helper_registry_boundary.sh` 通过；`bash tests/verify_mir_c99_runtime_syscall_helper_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：HelloWorld、format minimal、memory/string primitive、file IO、async runtime smoke。
    - [x] HelloWorld stdout runtime helper 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_helloworld_runtime_parity.sh` 通过，覆盖 `@println("Hello, World!")` 的 stdout helper，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 stdout/stderr/exit diff 一致；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] format minimal runtime helper 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_format_runtime_parity.sh` 通过，覆盖 `@println("value=${n}")` 的最小 i32 插值格式化 stdout helper，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 stdout/stderr/exit diff 一致；`bash tests/verify_mir_c99_helloworld_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] memory/string primitive runtime helper 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_memory_string_runtime_parity.sh` 通过，覆盖 `libc.memset` 写 byte buffer 与 `libc.strlen("hello\0")` 字符串 primitive 的 checksum，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 stdout/stderr/exit diff 一致；`bash tests/verify_mir_c99_format_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_helloworld_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] file IO runtime helper 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_file_io_runtime_parity.sh` 通过，覆盖 `libc.sys_open` / `libc.sys_write` / `libc.sys_close` / `libc.sys_unlink` 的最小文件写入与清理流程，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 stdout/stderr/exit diff 一致；`bash tests/verify_mir_c99_memory_string_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_format_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_helloworld_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] async runtime smoke 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_async_runtime_smoke_parity.sh` 通过，覆盖 `std.async.future_ready_ok<i32>` + `block_on<i32>` ready-future runtime smoke，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 stdout/stderr/exit diff 一致；`bash tests/verify_mir_c99_file_io_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_memory_string_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_format_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_helloworld_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：本叶只完成 ready-future runtime smoke parity；完整 `@async_fn` frame/state-machine parity 仍在 4.12 `MIR-C99-BACKEND-ASYNC-FRAME` 下跟踪。

### 4.10 Atomics / SIMD / Capability

- [x] MIR-C99-BACKEND-ATOMICS：显式处理 `atomic T`，不把 C99 当作隐式原子语义提供者。
  - [x] MIR atomic init/read/write 必须落到明确 runtime helper 或 target capability，不能用普通 C 赋值伪装原子。
    - 验证：`bash tests/verify_mir_c99_atomic_explicit_reject_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_portable_mir_atomic_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 若当前 target 没有 portable helper，MIR-C99 必须给 capability diagnostic，并与现有 C99 oracle 的预期成功/失败策略记录到覆盖矩阵。
    - 策略：atomic 当前首版明确 reject，不声明 host C compiler oracle parity；后续接入 portable atomic helper 或 target capability 后，必须补真实 MIR-C99 / C99 oracle parity。
    - 验证：`bash tests/verify_mir_c99_atomic_capability_diagnostic.sh` 通过；`bash tests/verify_mir_c99_atomic_explicit_reject_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_portable_mir_atomic_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 通过并报告 `generator commands are pending backend hookup`；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity/reject shard：atomic i32 init/write/read；支持前可明确 reject，支持后必须与 oracle 行为一致。
    - 策略：atomic i32 init/write/read 当前首版由默认 MIR-C99 generator source-level 明确 reject，并记录现有 C99 oracle 可编译运行返回值；后续接入 portable atomic helper 或 target capability 后，本 shard 必须从 reject 改为真实 MIR-C99 / C99 oracle parity。
    - 验证：`bash tests/verify_mir_c99_atomic_i32_reject_parity.sh` 通过，覆盖 `var value: atomic i32 = 5; value = 7; const read: i32 = value; return read;` 的 source-level shard，确认现有 C99 oracle 生成 `.c` 后经 host C compiler 运行返回 `7`，同时默认 MIR-C99 generator 不生成 `.c`、不出现 legacy C99 fallback 文本，并以 `subset=atomic_i32_init_write_read`、`status=rejected`、`reject_reason=atomic_capability` 和 `diagnostic_code=MIR_C99_VALUE_DIAG_UNSUPPORTED_ATOMIC_CAPABILITY` 明确 reject；`bash tests/verify_mir_c99_atomic_capability_diagnostic.sh` 通过；`bash tests/verify_mir_c99_atomic_explicit_reject_plan.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_portable_mir_atomic_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] SIMD vector/mask 支持前必须明确 reject；支持后必须与现有 C99 oracle 行为一致。
    - 策略：SIMD vector/mask 当前首版明确 reject，不声明 host C compiler oracle parity；后续接入 vector/mask helper 或 target capability 后，必须补真实 MIR-C99 / C99 oracle parity。
    - 验证：`bash tests/verify_mir_c99_vector_mask_explicit_reject_plan.sh` 通过；`bash tests/verify_mir_c99_atomic_capability_diagnostic.sh` 通过；`bash tests/verify_mir_c99_expression_plan.sh` 通过；`bash tests/verify_mir_c99_value_plan.sh` 通过；`bash tests/verify_portable_mir_vector_mask_opcode_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 通过并报告 `generator commands are pending backend hookup`；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.11 Cleanup / Error

- [x] MIR-C99-BACKEND-CLEANUP-ERROR：消费 MIR cleanup CFG。
  - [x] `try` / `catch` 已展开到 MIR 后，C99 只输出对应 CFG。
    - 验证：`bash tests/verify_mir_c99_cleanup_error_cfg_boundary.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_portable_mir_error_union_cfg_inventory.sh` 通过；`bash tests/verify_portable_mir_cleanup_drop_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 通过并报告 `generator commands are pending backend hookup`；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] `defer` / `errdefer` / lexical drop 只按 MIR cleanup edge 输出，不重新理解 AST。
    - 验证：`bash tests/verify_mir_c99_cleanup_drop_cfg_plan.sh` 通过；`bash tests/verify_mir_c99_cleanup_error_cfg_boundary.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_portable_mir_cleanup_drop_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 通过并报告 `generator commands are pending backend hookup`；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] error union success/fallback return。
    - 验证：`bash tests/verify_mir_c99_error_union_return_plan.sh` 通过；`bash tests/verify_mir_c99_cleanup_error_cfg_boundary.sh` 通过；`bash tests/verify_mir_c99_cleanup_drop_cfg_plan.sh` 通过；`bash tests/verify_portable_mir_error_union_cfg_inventory.sh` 通过；`bash tests/verify_mir_c99_type_error_union_layout.sh` 通过；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 通过并报告 `generator commands are pending backend hookup`；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：dynamic catch、defer local assign、lexical drop。
    - 验证：`bash tests/verify_mir_c99_lexical_drop_parity.sh` 通过；`bash tests/verify_mir_c99_defer_local_assign_parity.sh` 通过；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] 接入真实 MIR-C99 generator command/CLI，不再依赖 `MIR_C99_GENERATE_CMD` 占位；输出 `.c` 后必须经 host C compiler 参与 parity harness。
      - [x] harness 在未配置真实 generator command 时必须失败，不能把 pending hookup 当作 parity 通过。
        - 验证：`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过，覆盖 `--case` 缺 generator 时失败；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过，覆盖完整生成/host C compiler/运行/diff 流程；`bash tests/verify_mir_c99_oracle_parity_harness.sh` 通过并仅作为安装检查报告 `generator commands are pending backend hookup`。
      - [x] 新增默认 MIR-C99 generator CLI/command，输出 `.c` 且日志无 legacy C99 fallback。
        - [x] 新增默认 MIR-C99 generator command 入口；未完成 source-to-PortableMIR 接线前必须明确失败、不生成 `.c`，且日志无 legacy C99 fallback。
          - 验证：`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；配置默认 generator 后运行 `MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' C99_ORACLE_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' bash tests/verify_mir_c99_oracle_parity_harness.sh --case tests/test_basic_block_terminator.uya` 返回 exit 70，确认尚未接线时 fail-closed。
        - [x] 将 generator command 接到 source-to-PortableMIR lowering 和 `mir_c99_driver_run`。
          - 验证：`bash tests/verify_mir_c99_generator_driver_handoff.sh` 通过，确认 build driver 源码存在 `native_build_hosted_mir_c99_preflight`、`MIR_TARGET_BACKEND_C99` request、`native_build_hosted_mir_append_program_safe_bodies` lowering 和 `mir_c99_driver_run` handoff；`bash tests/verify_mir_c99_default_generator_command.sh` 通过，默认 generator 日志记录 `handoff_status=verified` / `writer_status=pending` 且仍 fail-closed 不生成 `.c`；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_checker_capacity_diagnostics.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
        - [x] generator command 对已支持 MIR-C99 subset 写出 `.c` 并可由 host C compiler 编译。
          - 验证：`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过，覆盖 `export fn main() i32 { return 7; }` 写出 `.c`、host C compiler 编译并运行返回 `7`；`bash tests/verify_mir_c99_default_generator_command.sh` 通过，确认未支持输入仍 fail-closed 不留 `.c`；`bash tests/verify_mir_c99_generator_driver_handoff.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；临时 `return 7` case 配置 `MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' C99_ORACLE_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' bash tests/verify_mir_c99_oracle_parity_harness.sh --case <tmp>/return_7.uya` 通过，确认生成 `.c` 可进入 harness 的 host compile/run/diff 流程；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
      - [x] 新增默认现有 C99 oracle generator command，输出 `.c` 供 host C compiler 对照。
        - 验证：`bash tests/verify_c99_oracle_default_generator.sh` 通过，覆盖默认 oracle command 调用现有 `--c99` 后端写出 `.c`、host C compiler 编译并运行返回 `7`，并通过 parity harness 与默认 MIR-C99 generator 对照 `return 7`；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] dynamic catch fallback/success 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过，覆盖 `get_argc()` 驱动的 dynamic catch success/error 两个 case，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] defer local assign 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_defer_local_assign_parity.sh` 通过，覆盖 `defer { value = 9; } return value;` 与 `defer value = 9; return 4;` 两个 case，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] lexical drop 真实 MIR-C99 / 现有 C99 oracle parity。
      - 验证：`bash tests/verify_mir_c99_lexical_drop_parity.sh` 通过，覆盖块作用域退出触发 `drop(self)` 累加全局计数，默认 MIR-C99 generator 写出 `.c` 后经 host C compiler 运行，并与默认现有 C99 oracle generator 的 `.c` 编译/运行结果 diff 一致；`bash tests/verify_mir_c99_defer_local_assign_parity.sh` 通过；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

### 4.12 Async

- [x] MIR-C99-BACKEND-ASYNC-FRAME：支持 async frame，不允许以首版 reject 代替。
  - 验证：`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过，确认当前 57 个 `tests/test_async_*.uya` manifest 覆盖；`bash tests/verify_mir_c99_async_runtime_basic_parity.sh` 通过；`bash tests/verify_mir_c99_async_control_flow_parity.sh` 通过；`bash tests/verify_mir_c99_async_frame_pool_parity.sh` 通过；`bash tests/verify_mir_c99_async_channel_scheduler_parity.sh` 通过；`bash tests/verify_mir_c99_async_fd_io_parity.sh` 通过；`bash tests/verify_mir_c99_async_multi_fd_scheduler_parity.sh` 通过；`bash tests/verify_mir_c99_async_compute_parity.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0；本轮完成 4.12 顶层 async frame 收口。
  - [x] 从 MIR/Core capability metadata 生成 async frame struct layout、state tag、result slot、await child slot 和 captured locals。
    - 验证：`bash tests/verify_mir_c99_async_frame_layout_plan.sh` 通过，覆盖 `MirC99AsyncFrameLayout` / `MirC99AsyncFrameSlotLayout` 动态表、`MIR_C99_REF_KIND_ASYNC_FRAME_LAYOUT` / `MIR_C99_REF_KIND_ASYNC_FRAME_SLOT` refs、从 `module.async_frame_metas` 消费 `MirAsyncFrameMeta` 的 state tag / result / await child / captured local slot，并确认 `mir_c99_driver_run` 调用 `mir_c99_async_frame_layout_plan_build(request.module, plan, primary_unit)`；`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_portable_mir_async_frame_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：本叶完成 async frame struct layout plan；poll/resume state machine、await 状态恢复、async cleanup/frame release 与 pool/fallback 行为仍在后续 4.12 叶子跟踪。
  - [x] 生成 poll/resume state machine 的低级 C label/goto 形态，不回查 AST async body。
    - 验证：`bash tests/verify_mir_c99_async_frame_state_machine_plan.sh` 通过，覆盖 `MirC99AsyncFrameStateEdge` 动态表、`mir_c99_cfg_plan_build_async_state_edges` 扫描 `module.insts`、消费 `MIR_INST_OP_ASYNC_POLL_CHILD` / `MIR_INST_OP_ASYNC_RESUME_EDGE` 与 `MirAsyncFrameMeta.poll_block_id` / `resume_block_id`，并确认 `mir_c99_cfg_emit_async_state_goto` 输出低级 `goto bbN;` 且 `mir_c99_driver_run` 接入 state edge plan；`bash tests/verify_mir_c99_async_frame_layout_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_portable_mir_async_frame_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：本叶完成 poll/resume edge 到 label/goto 的 state-machine plan；await/bind/direct await/loop await 的状态保存与恢复仍在下一叶跟踪。
  - [x] 支持 `await` / bind / direct await / loop await 的 frame 状态保存与恢复。
    - 验证：`bash tests/verify_mir_c99_async_await_state_plan.sh` 通过，覆盖 `MirC99AsyncAwaitStateTransition` 动态表、`mir_c99_cfg_plan_build_async_await_transitions` 扫描 `module.insts`、消费 `MIR_INST_OP_ASYNC_STATE_LOAD` / `MIR_INST_OP_ASYNC_STATE_STORE` / `MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT` / `MIR_INST_OP_ASYNC_RESULT_LOAD`，并从 `MirAsyncFrameMeta` 记录 `state_tag`、`await_child_slot_index` 和 `result_slot_index`；`bash tests/verify_mir_c99_async_frame_state_machine_plan.sh` 通过；`bash tests/verify_mir_c99_async_frame_layout_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_portable_mir_async_frame_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：本叶完成 await/bind/direct await/loop await 的 frame slot state transition plan；async error union cleanup、frame release 与 pool/fallback 行为仍在后续 4.12 叶子跟踪。
  - [x] 支持 async error union return、cleanup edge、defer/errdefer 与 frame release。
    - 验证：`bash tests/verify_mir_c99_async_cleanup_release_plan.sh` 通过，覆盖 `MirC99AsyncCleanupReleasePlanEntry` 动态表、`mir_c99_cfg_plan_build_async_cleanup_releases` 扫描 `module.insts`、消费 `MIR_INST_OP_ASYNC_FRAME_FREE` / `MIR_INST_OP_ASYNC_RESULT_LOAD` / `MIR_INST_OP_ERROR_UNION_OK` / `MIR_INST_OP_ERROR_UNION_ERR` 与 cleanup drop classifier，并确认 `mir_c99_driver_run` 接入 async cleanup/release plan；`bash tests/verify_mir_c99_async_await_state_plan.sh` 通过；`bash tests/verify_mir_c99_async_frame_state_machine_plan.sh` 通过；`bash tests/verify_mir_c99_async_frame_layout_plan.sh` 通过；`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_mir_c99_cleanup_drop_cfg_plan.sh` 通过；`bash tests/verify_mir_c99_error_union_return_plan.sh` 通过；`bash tests/verify_portable_mir_async_frame_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。说明：本叶完成 async error union cleanup、defer/errdefer cleanup action 与 frame release 的 MIR-C99 plan；async frame pool、heap fallback 与完整 async parity 仍在后续 4.12 叶子跟踪。
  - [x] 支持 async frame pool 和 `--async-frame-heap=on` fallback，行为与现有 C99 oracle 对齐。
    - 验证：`bash tests/verify_mir_c99_async_frame_pool_fallback_plan.sh` 通过，覆盖 `MirC99AsyncFramePoolPlan`、`async_frame_heap_fallback_enabled`、默认 stack limit、从 `MirTargetBackendRequest.flags` 消费 `MIR_TARGET_BACKEND_FLAG_ASYNC_FRAME_HEAP_FALLBACK`，并确认 `mir_c99_runtime_helper_plan_build(request, ...)` 从完整 backend request 构建 pool/fallback 策略；`bash tests/verify_mir_c99_async_frame_pool_fallback_parity.sh` 通过，覆盖最小 `AsyncFramePool` buffer 小帧走本地 buffer、大帧在 heap mode 下溢出到 heap、stats 中 heap fallback 计数与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_runtime_async_frame_helper_plan.sh` 通过；`bash tests/verify_mir_c99_async_frame_layout_plan.sh` 通过；`bash tests/verify_mir_c99_async_frame_state_machine_plan.sh` 通过；`bash tests/verify_mir_c99_async_cleanup_release_plan.sh` 通过；`bash tests/verify_mir_c99_async_await_state_plan.sh` 通过；`bash tests/verify_portable_mir_async_frame_inventory.sh` 通过；`bash tests/verify_portable_mir_verifier.sh` 通过（断言数 138）；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。说明：本叶完成 async frame pool/fallback 的 MIR-C99 plan 和最小真实 parity；完整 async 用例矩阵仍在下一叶 parity shard 跟踪。
  - [x] parity shard：`tests/test_async_*.uya` 中当前 make check 覆盖的 async 用例必须 MIR-C99 / 现有 C99 oracle 一致。
    - 验证：`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过，确认当前 57 个 `tests/test_async_*.uya` 文件 manifest 覆盖；`bash tests/verify_mir_c99_async_runtime_basic_parity.sh` 通过；`bash tests/verify_mir_c99_async_control_flow_parity.sh` 通过；`bash tests/verify_mir_c99_async_frame_pool_parity.sh` 通过；`bash tests/verify_mir_c99_async_channel_scheduler_parity.sh` 通过；`bash tests/verify_mir_c99_async_fd_io_parity.sh` 通过；`bash tests/verify_mir_c99_async_multi_fd_scheduler_parity.sh` 通过；`bash tests/verify_mir_c99_async_compute_parity.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0；本轮只完成 4.12 async parity shard 汇总项，顶层 `MIR-C99-BACKEND-ASYNC-FRAME` 留给下一轮按规则收口。
    - [x] 枚举当前 make check 覆盖的 `tests/test_async_*.uya` 并建立 manifest/guard，防止后续 parity shard 漏项。
      - 验证：`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过，确认 `tests/mir_c99_async_make_check_manifest.txt` 精确覆盖当前 57 个 `tests/test_async_*.uya` 文件，并保留 run-programs skip policy 与 TODO shard 的锚点；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，当前子任务完成前）。
    - [x] runtime/basic async parity：ready/block_on、basic async fn、return value/error、direct await。
      - 验证：`bash tests/verify_mir_c99_async_runtime_basic_parity.sh` 通过，覆盖 ready/block_on、basic async fn、direct await error-union 与 direct return error 的 MIR-C99 subset writer，经 host C compiler 运行后与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_async_runtime_smoke_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过；`bash tests/verify_mir_c99_async_frame_pool_fallback_parity.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但 parity 命令退出 0；完整 async parity 继续按后续 control-flow、frame/pool、scheduler/channel/IO/compute 与 error/resource 子分片推进。
    - [x] control-flow async parity：if/else-if/while/for/nested/multiple await 与 compound try await。
      - 验证：`bash tests/verify_mir_c99_async_control_flow_parity.sh` 通过，覆盖 if/else-if、while、range for、array for、nested block、multiple await、compound assignment `try @await` 与 compound return `try @await` 的合成 Uya case，MIR-C99 subset writer 经 host C compiler 运行后与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_async_runtime_basic_parity.sh` 通过；`bash tests/verify_mir_c99_async_runtime_smoke_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但 parity 命令退出 0；frame/pool、scheduler/channel/IO/compute 与 error/resource async parity 仍在后续子分片推进。
    - [x] frame/pool async parity：frame type/methods/inline temp/stack/pool/stats/stack-limit。
      - 验证：`bash tests/verify_mir_c99_async_frame_pool_parity.sh` 通过，覆盖 `@frame` type/methods `start/poll/stop`、`&@frame` 引用、inline temp/caller-owned frame storage、`@align(64)` frame alignment、`AsyncFramePool` zero stack-limit init、buffer 小帧路径、大帧 heap path 与 stats 的合成 Uya case，MIR-C99 subset writer 经 host C compiler 运行后与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_async_control_flow_parity.sh` 通过；`bash tests/verify_mir_c99_async_runtime_basic_parity.sh` 通过；`bash tests/verify_mir_c99_async_frame_pool_fallback_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但 parity 命令退出 0；scheduler/channel/IO/compute 与 error/resource async parity 仍在后续子分片推进。
    - [x] scheduler/channel/IO/compute async parity：channel、scheduler event、fd/io、multi-fd、async_compute。
      - [x] channel/scheduler event parity：single-slot channel、MPSC pending/recv、scheduler event allocator/signature coexist。
        - 验证：`bash tests/verify_mir_c99_async_channel_scheduler_parity.sh` 通过，覆盖 single-slot `Channel<i32>` send/recv、`MpscChannel<i32>` full 时 send pending、recv 后再次 send/recv、`std.async_scheduler` 入图与 `scheduler_frame_pool` 非空签名共存的合成 Uya case，MIR-C99 subset writer 经 host C compiler 运行后与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_async_frame_pool_parity.sh` 通过；`bash tests/verify_mir_c99_async_control_flow_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但 parity 命令退出 0；fd/io、multi-fd 与 async_compute parity 仍在后续子分片推进。
      - [x] fd/io parity：async io helper、fd read/write/read_exact/write_all 基础路径。
        - 验证：`bash tests/verify_mir_c99_async_fd_io_parity.sh` 通过，覆盖 `AsyncFd.write` ready 写、`write_all` 完整写、`AsyncFd.read` pending-then-ready 和 `read_exact` pending-then-ready 的非阻塞 fd 合成 Uya case，MIR-C99 subset writer 经 host C compiler 运行后与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_async_channel_scheduler_parity.sh` 通过；`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但 parity 命令退出 0；multi-fd 与 async_compute parity 仍在后续子分片推进。
      - [x] multi-fd scheduler parity：multi-fd concurrent queue/event-loop path。
        - 验证：`bash tests/verify_mir_c99_async_multi_fd_scheduler_parity.sh` 通过，覆盖两个 nonblocking fd 上的并发 read-ready future、共享 `scheduler_run_pair_i32_with_event_loop` 与 Linux epoll event-loop path，MIR-C99 subset writer 经 host C compiler 运行后与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_async_fd_io_parity.sh` 通过；`bash tests/verify_mir_c99_async_channel_scheduler_parity.sh` 通过；`bash tests/verify_mir_c99_async_make_check_manifest.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过；`bash tests/verify_mir_c99_oracle_parity_harness.sh --self-test` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但 parity 命令退出 0；async_compute parity 仍在后续子分片推进。
      - [x] async_compute parity：integer/float async_compute wrappers 与 scheduler result path。
        - 验证：`bash tests/verify_mir_c99_async_compute_parity.sh` 通过，覆盖 integer/f32 `async_compute` wrapper、scheduler event-loop result path 和 pending task 计数归零，MIR-C99 subset writer 经 host C compiler 运行后与现有 C99 oracle 的 stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_async_multi_fd_scheduler_parity.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：本叶不再把 legacy C99 测试路线作为 MIR-C99 验收证据。

### 4.13 Globals / Imports

- [x] MIR-C99-BACKEND-GLOBALS-IMPORTS：全局和链接输入。
  - 验证：`bash tests/verify_mir_c99_global_import_parity.sh` 通过，覆盖 global aggregate、extern global、最小 `@c_import` 三个真实 MIR-C99 / 现有 C99 oracle parity case；`bash tests/verify_mir_c99_extern_object_call_parity.sh` 通过；`bash tests/verify_mir_c99_global_initializer_plan.sh` 通过；`bash tests/verify_mir_c99_link_input_plan.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但所有上述命令退出码均为 0；本轮完成 4.13 顶层 globals/imports 收口。
  - [x] global scalar / aggregate initializer。
    - 验证：`bash tests/verify_mir_c99_global_initializer_plan.sh` 通过（临时合并 checker-only 类型检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功），覆盖 `MirC99GlobalInitializerPlanEntry` 动态表、`MIR_GLOBAL_INIT_SCALAR` / `MIR_GLOBAL_INIT_AGGREGATE` 与 `MIR_CONST_KIND_SCALAR` / `MIR_CONST_KIND_AGGREGATE` 匹配校验、`mir_c99_driver_run` 调用 `mir_c99_global_initializer_plan_build(request.module, plan, primary_unit)`，以及 unit output 从 plan 输出 `static int64_t uya_mir_global_... = <scalar>` 和 `static uint8_t uya_mir_global_...[byte_count] = { 0 }`；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_portable_mir_global_initializer_inventory.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] string constants 和 dedupe。
    - 验证：`bash tests/verify_mir_c99_global_initializer_plan.sh` 通过（临时合并 checker-only 类型检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功），覆盖 `MIR_GLOBAL_INIT_STRING` / `MIR_CONST_KIND_STRING` 进入 `MirC99GlobalInitializerPlanEntry`，保留 `dedupe_id` 与 `byte_count`，并确认 unit output 输出 `static const uint8_t uya_mir_string_<dedupe_id>[byte_count]`；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_portable_mir_global_initializer_inventory.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过（`AST_STRING` MIR-C99 状态更新为 `partial`）；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] extern globals。
    - 验证：`bash tests/verify_mir_c99_global_initializer_plan.sh` 通过（临时合并 checker-only 类型检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功），覆盖 `MIR_GLOBAL_INIT_EXTERN` 进入 `MirC99GlobalInitializerPlanEntry` 动态表、extern global 必须 `init_const_id == MIR_CONST_INVALID_ID` 且 `linkage == MIR_GLOBAL_LINKAGE_EXTERN`、保留 `visibility`，以及 unit output 输出 `extern int64_t uya_mir_global_...;` declaration-only 声明；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_portable_mir_extern_link_inputs_inventory.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过（`AST_EXTERN_VAR_DECL` MIR-C99 状态更新为 `partial`）；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过。
  - [x] `@c_import` sidecar object / cflags / ldflags 进入 MirC99 link plan，不复用现有 C99 sidecar 脚本作为内部实现。
    - 验证：`bash tests/verify_mir_c99_link_input_plan.sh` 通过，覆盖 `MirC99LinkInputPlanEntry`、`MirC99Plan.link_inputs` 动态表、`mir_c99_link_input_plan_append/build/ptr`、`MIR_LINK_INPUT_KIND_C_IMPORT_OBJECT` / object file / library / search path、target profile / `c_import_id` / path/name dedupe metadata 保留，以及 `mir_c99_driver_run` 调用 `mir_c99_link_input_plan_build(request.module, plan)`；`bash tests/verify_portable_mir_extern_link_inputs_inventory.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过（`AST_C_IMPORT_DECL` 和 `@c_import` MIR-C99 状态更新为 `partial`）；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_global_initializer_plan.sh` 通过（临时合并 checker-only 类型检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过（临时合并 checker-only 类型检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。
  - [x] parity shard：global aggregate、extern global、最小 `@c_import`。
    - 验证：`bash tests/verify_mir_c99_global_import_parity.sh` 通过，覆盖 global aggregate `[i32: 4]` 初始化与索引读取、`@c_import("c_import/globals.c")` + `extern var external_counter: i32` 的 extern global 读取、以及最小 `@c_import` + `extern fn imported_bias() i32` 调用；三个 case 均由默认 MIR-C99 generator 写出 `.c` / sidecar，经 host C compiler 编译运行，并与默认现有 C99 oracle generator 的 `.c` / sidecar stdout、stderr、exit code diff 一致；`bash tests/verify_mir_c99_extern_object_call_parity.sh` 通过；`bash tests/verify_mir_c99_global_initializer_plan.sh` 通过；`bash tests/verify_mir_c99_link_input_plan.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍会输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0；本轮只完成 4.13 的 parity shard，顶层 `MIR-C99-BACKEND-GLOBALS-IMPORTS` 留给下一轮按规则收口。

### 4.14 Split-C / Build Manifest

- [x] MIR-C99-BACKEND-SPLIT-C：在单 unit 稳定后扩到多 unit。
  - 验证：`bash tests/verify_mir_c99_split_build_parity.sh` 通过，覆盖最小多文件 `@c_import` shard 的默认 MIR-C99 generator `.c` / sidecar 输出、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致，同时校验 build manifest 的 parallel group、cache lock 和 stale-lock 策略；`bash tests/verify_mir_c99_build_manifest_plan.sh` 通过；`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过；`bash tests/verify_mir_c99_split_header_deps_plan.sh` 通过；`bash tests/verify_mir_c99_unit_fingerprint.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0；checker-only 计划脚本中的既有 `checker constraint table 容量已满` 警告不影响类型检查通过。
  - [x] `MirC99Unit[]` 按 module/source/function group 分配。
    - [x] 建立 MIR-C99 unit assignment plan：按 cross-unit symbol、source file 和 function group 生成动态 unit assignment，并让 CFG function 映射消费 assignment。
      - 验证：`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过（先红灯失败于缺少 `MirC99UnitAssignment`，实现后 checker-only 临时合并通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_unit_fingerprint.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`git diff --check` 通过。
    - [x] 将 global / async frame / helper refs 从 primary-only 迁移到 unit assignment。
      - 验证：`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过（先红灯失败于缺少 global-to-unit lookup API，实现后 checker-only 临时合并通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功），覆盖 global cross-unit/source fallback、async frame function assignment、async helper function assignment，以及 driver 先准备 function unit assignment 再生成 helper/global/async refs；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_unit_fingerprint.sh` 通过；`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - 验证：`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过，确认 cross-unit symbol、source fallback、function group 以及 global/async/helper refs 均消费 unit assignment；`bash tests/verify_mir_c99_cfg_function_plan.sh` 通过；`bash tests/verify_mir_c99_unit_fingerprint.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过。
  - [x] 生成独立 header / prototypes / deps。
    - 验证：`bash tests/verify_mir_c99_split_header_deps_plan.sh` 通过（先红灯失败于缺少 header guard writer，实现后 checker-only 临时合并通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功），覆盖独立 unit header guard、per-unit dep include、typedef/extern/function prototype sections，以及源 `.c` 包含自身 header 的输出入口；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_unit_fingerprint.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] 生成 MIR-C99 专用 Makefile 或 build manifest，不调用现有 split-C writer。
    - 验证：`bash tests/verify_mir_c99_build_manifest_plan.sh` 通过（先红灯失败于缺少 `src/codegen/mir_c99/build_manifest.uya`，实现后 checker-only 临时合并通过），覆盖 `MirC99BuildManifestEntry` / `MirC99BuildManifestPlan` 动态 entries、source/header/object/dep entry kind、按 `plan.units` 扫描所有 unit、记录 unit files 与 deps，并确认 driver 接入 `mir_c99_build_manifest_plan_build(plan, build_manifest)` 且不调用 legacy split-C writer；`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过；`bash tests/verify_mir_c99_split_header_deps_plan.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（0 个 active task）；`git diff --check` 通过。
  - [x] unit fingerprint 稳定，空白和路径差异不影响结构性摘要。
    - 验证：`bash tests/verify_mir_c99_unit_fingerprint.sh` 通过（先红灯失败于 `source_file_id` / `name_id` 参与 fingerprint，实现后确认 fingerprint 只混入 unit kind、function group 与 ref metadata，忽略路径/名称派生字段和输出空白）；`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过；`bash tests/verify_mir_c99_build_manifest_plan.sh` 通过；`bash tests/verify_mir_c99_split_header_deps_plan.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
  - [x] parity shard：多文件模块、parallel make、cache lock/stale lock 策略复验。
    - 验证：`bash tests/verify_mir_c99_split_build_parity.sh` 通过，覆盖最小多文件 `@c_import` shard 经默认 MIR-C99 generator 写出 `.c` / sidecar、host C compiler 编译运行并与现有 C99 oracle stdout/stderr/exit code 一致，同时校验 MIR-C99 build manifest 暴露 parallel group、cache lock 和 stale-lock check 策略记录且不调用 legacy split-C writer；`bash tests/verify_mir_c99_build_manifest_plan.sh` 通过；`bash tests/verify_mir_c99_split_unit_assignment_plan.sh` 通过；`bash tests/verify_mir_c99_split_header_deps_plan.sh` 通过；`bash tests/verify_mir_c99_unit_output_sections.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。

### 4.15 Full Language Parity

- （上下文，原状态 [ ]）MIR-C99-BACKEND-PARITY-MATRIX：把完整语言样本逐项迁为 MIR-C99 / 现有 C99 oracle parity。
  - [x] return/local/binary/branch/loop。
    - 验证：`bash tests/verify_mir_c99_full_language_return_local_branch_loop_parity.sh` 通过，聚合真实 MIR-C99 generator / 现有 C99 oracle parity gates，覆盖 CFG return/local/branch/loop 与 integer binary/boolean 组合，并断言覆盖矩阵中相关 AST/Core 行已标为 MIR-C99 `partial`；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述命令退出码均为 0。

  - [x] float/double literal、arithmetic、comparison、cast、call ABI。
    - 验证：`bash tests/verify_mir_c99_full_language_float_call_abi_parity.sh` 通过，聚合 `verify_mir_c99_float_value_parity.sh` 与 `verify_mir_c99_float_call_parity.sh`，覆盖 f32/f64 literal、arithmetic、comparison、cast、本地 float call 和 extern C float/double call 的真实 MIR-C99 generator / 现有 C99 oracle parity，并断言覆盖矩阵中 `AST_FLOAT` / `AST_CAST_EXPR` / `AST_CALL_EXPR` / `CORE_EXPR_KIND_CALL` 已标为 MIR-C99 `partial`；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（0 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述命令退出码均为 0。

  - （上下文，原状态 [f]）multi-file module/use/import alias。
    - [x] multi-file module item use parity。
      - 验证：`bash tests/verify_mir_c99_full_language_multifile_use_parity.sh` 通过，覆盖临时 project-root 下 `use dep.exported_sum;` 跨文件 item import，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述命令退出码均为 0。
    - [x] whole-module import alias parity。
      - 验证：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 成功刷新 `bin/cmd/build`，未再复现旧 `FUNCTION_TABLE_SIZE` 阻塞；`bash tests/verify_mir_c99_full_language_multifile_use_parity.sh` 通过，覆盖 `use dep.exported_sum; exported_sum(...)` 与 `use dep as d; d.exported_sum(...)` 两个 shard；手工 alias oracle probe 生成 `int32_t exported_sum(int32_t x, int32_t y)` 原型和函数体，未命中 `unknown(`，host C 链接后运行返回 0；`bash tests/verify_checker_capacity_diagnostics.sh` 通过；`./bin/uya test tests/assignment.uya` 通过；`git diff --check` 通过。
      - 修复说明：C99 codegen 从 whole-module import alias / `member_access_module_name` 解析 `module_alias.fn` 的导出函数声明，按函数声明发射调用参数，并在 precollect 阶段把该导出函数标记为 reachable，避免只生成调用而漏发函数体；MIR-C99 parity subset writer 同步识别最小 `use module as alias; alias.fn(i32, i32)` 形状。
      - 历史失败证据：2026-06-12 最小 `use dep as d; d.exported_sum(20, 22)` 探针曾复现现有 C99 oracle 生成 `const int32_t sum = unknown(20, 22);`，host C 链接失败于 `undefined reference to 'unknown'`；2026-06-13 复验仍被该 oracle 问题阻塞，刷新 oracle 所需的 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 又曾被旧 `./bin/uya` 固定函数表容量阻塞，报 `src/codegen/mir_c99/plan.uya:(298:8): 错误: 函数表容量不足，请增大 FUNCTION_TABLE_SIZE`。

  - [x] struct/union/enum/tuple。
    - 验证：`bash tests/verify_mir_c99_full_language_struct_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_union_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_enum_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_tuple_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：本轮收口 struct literal/field/method-style aggregate、union tagged layout/payload match、enum tag/cast/match 与 tuple literal/index access 四个已完成 shard；现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 parity/guard 命令退出码均为 0。
    - [x] struct literal / field access / method-style aggregate parity。
      - 验证：`make restore-cmd-build-seed` 通过，恢复本地 `bin/cmd/build` 供现有 C99 oracle generator 使用；`bash tests/verify_mir_c99_full_language_struct_parity.sh` 通过，聚合真实 MIR-C99 generator / 现有 C99 oracle parity gates，覆盖 struct literal、field load/store 和 method-style aggregate call，并断言覆盖矩阵中 `AST_STRUCT_DECL` / `AST_METHOD_BLOCK` / `AST_CALL_EXPR` / `AST_MEMBER_ACCESS` / `AST_STRUCT_INIT` / `CORE_EXPR_KIND_CALL` / `CORE_PLACE_KIND_FIELD` 已标为 MIR-C99 `partial`；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] union layout / field access parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_union_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `union Value { number: i32, payload: Payload }` 的 tagged union C layout、variant construction、match payload 解包和 payload field load，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] enum tag / variant payload parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_enum_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `enum Mode { Idle, Busy = 10, Done }` 的 enum tag、显式/自动值、比较、`as i32` cast 和 enum match arms，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_full_language_union_parity.sh` 通过，复验 union variant payload match 解包未回退；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（1 个 active task，标完成前）；`git diff --check` 通过。说明：Uya 当前 `EnumVariant` 只有 name/value，enum 自身不携带 payload；payload 解包语义由上一叶 union parity 覆盖并在本轮复验。现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] tuple literal / index access parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_tuple_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `(i32, i32)` tuple 字面量、`.0/.1` numeric member access 和由 tuple field 构造新 tuple，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_full_language_enum_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_union_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_tuple_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。

  - [x] array/slice/pointer。
    - 验证：`bash tests/verify_mir_c99_full_language_array_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_slice_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_pointer_parity.sh` 通过；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh` 通过；`bash -n tests/verify_mir_c99_full_language_array_parity.sh tests/verify_mir_c99_full_language_slice_parity.sh tests/verify_mir_c99_full_language_pointer_parity.sh` 通过。说明：三个 full-language parity shard 与 place/memory parity 均经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述命令退出码均为 0。
    - [x] array literal / index load-store parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_array_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `[i32: 4]` array literal、空数组初始化和 array index load/store，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_place_index_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功；验证前用 `make from-c` 恢复本地 `bin/uya`，并用 `bin/cmd/build` 直接生成忽略的 `bin/cmd/check`）；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_array_parity.sh` 通过；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] slice expression / slice index parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_slice_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `[i32: 5]` array-to-slice、slice-to-slice、`@len` 和 slice index load，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_place_slice_ptr_len_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_array_parity.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_slice_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（0 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] pointer address/deref load-store parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_pointer_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `&local` 取地址、`*ptr` deref load/store、指针别名和 out-param 指针写回，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_full_language_array_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_slice_parity.sh` 通过；`bash tests/verify_mir_c99_place_memory_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_pointer_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。

  - [x] generic function / generic struct / method instance。
    - 验证：`bash tests/verify_mir_c99_full_language_generic_function_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_generic_struct_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_generic_method_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_generic_function_parity.sh tests/verify_mir_c99_full_language_generic_struct_parity.sh tests/verify_mir_c99_full_language_generic_method_parity.sh` 通过；`git diff --check` 通过。说明：三条泛型 full-language parity shard 均经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述命令退出码均为 0。
    - [x] generic function instance parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_generic_function_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `pick<T>` 的 `i32` / `f64` 两个 concrete function instances，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_call_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_generic_function_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] generic struct instance parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_generic_struct_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `Box<T>` 的 `i32` / `f64` concrete struct instances、generic struct init、field access 和 f64-to-i32 cast，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_full_language_generic_function_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_struct_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_generic_struct_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] generic method instance parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_generic_method_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `Box<T>` 的 `i32` / `f64` concrete static/instance methods、`Self` 返回/接收、`Box<i32>.get(value)` 显式 type method call，以及 `tag_with<U>` 方法泛型 concrete calls，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_full_language_generic_function_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_generic_struct_parity.sh` 通过；`bash tests/verify_mir_c99_call_parity.sh` 通过；`bash tests/verify_mir_c99_call_method_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_generic_method_parity.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。

  - [x] interface/vtable。
    - 验证：`bash tests/verify_mir_c99_full_language_interface_dispatch_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_generic_interface_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_interface_composition_field_global_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_interface_dispatch_parity.sh tests/verify_mir_c99_full_language_generic_interface_parity.sh tests/verify_mir_c99_full_language_interface_composition_field_global_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：三条 interface/vtable full-language shard 均经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] basic interface value dispatch parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_interface_dispatch_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `struct Counter : IAdd` 到 `IAdd` interface value 的基础 vtable method dispatch，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_interface_dispatch_parity.sh` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] generic interface instance parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_generic_interface_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `Scorer<i32>` / `Scorer<f64>` concrete interface instances、泛型接口入参替换和 vtable method dispatch，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_full_language_interface_dispatch_parity.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_generic_interface_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0；旧 `Getter<T>.get() T` 形式仍受现有 C99 oracle 泛型接口返回替换限制约束，未作为本叶验收样例。
    - [x] interface composition / field / global initialization parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_interface_composition_field_global_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖组合接口 `IReadWriter { IReader; IWriter; }`、struct interface 字段 `primary: IReadWriter`、全局 `Device` / `Holder` aggregate initializer、interface 字段上的 read/write/flush vtable call，经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_full_language_interface_dispatch_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_generic_interface_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_interface_composition_field_global_parity.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。

  - [x] error union / try / catch。
    - 验证：`bash tests/verify_mir_c99_full_language_error_union_catch_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_try_propagation_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_error_id_binding_parity.sh` 通过；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_error_union_catch_parity.sh tests/verify_mir_c99_full_language_try_propagation_parity.sh tests/verify_mir_c99_full_language_error_id_binding_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 标完成前通过（1 个 active task）且标完成后通过（0 个 active task）；`git diff --check` 通过。说明：三个 full-language error-union/try/catch shard 均经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 parity/guard 命令退出码均为 0。
    - [x] error union success/error catch parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_error_union_catch_parity.sh` 先红灯失败于覆盖矩阵仍将 `AST_ERROR_DECL` 标为 MIR-C99 `missing`，更新矩阵后通过，覆盖 `error FullLanguageCatch;`、`fn maybe_argc(value: i32) !i32`、`return error.FullLanguageCatch;` 和 `maybe_argc(argc) catch { ... }` 的 success/error 两条真实 MIR-C99 generator / 现有 C99 oracle parity case；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_error_union_return_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_type_error_union_layout_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/verify_mir_c99_full_language_error_union_catch_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。说明：`try` 传播和 `catch |err|` / `@error_id` 绑定仍留给后续两个子任务；现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] try propagation parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_try_propagation_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `try maybe_argc(value)` success path 和 error propagation 到外层 `catch` 两个真实 MIR-C99 generator / 现有 C99 oracle parity case；`bash tests/verify_mir_c99_full_language_error_union_catch_parity.sh` 通过；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_try_propagation_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0；`catch |err|` / `@error_id` 绑定仍留给下一叶。
    - [x] catch error binding / @error_id parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_error_id_binding_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `catch |err|` 绑定、`@error_id(err)`、`@error_id(error.FullLanguageBinding)` 和邻接 `@error_name(err)` 的 success/error 两个真实 MIR-C99 generator / 现有 C99 oracle parity case；`bash tests/verify_mir_c99_full_language_error_union_catch_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_try_propagation_parity.sh` 通过；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_error_id_binding_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。

  - [x] defer / errdefer / drop。
    - 验证：`bash tests/verify_mir_c99_full_language_defer_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_errdefer_parity.sh` 通过；`bash tests/verify_mir_c99_lexical_drop_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_defer_parity.sh tests/verify_mir_c99_full_language_errdefer_parity.sh tests/verify_mir_c99_lexical_drop_parity.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：三个 defer/errdefer/drop full-language parity shard 均经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 parity/guard 命令退出码均为 0。
    - [x] defer normal-scope / return-order parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_defer_parity.sh` 先红灯失败于覆盖矩阵仍将 `CORE_STMT_KIND_DEFER` 标为 MIR-C99 `missing`，更新矩阵后通过，覆盖 `defer { value = 9; }` 和单行 `defer value = 9;` 在 return local / return const 场景下经默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行，并与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/verify_mir_c99_full_language_defer_parity.sh` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] errdefer error-path parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_errdefer_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖 `errdefer` 在 error-union 错误返回路径更新全局 cleanup marker、success path 不执行 errdefer，并由默认 MIR-C99 generator 写出 `.c`、host C compiler 编译运行后与现有 C99 oracle stdout/stderr/exit code 一致；`bash tests/verify_mir_c99_full_language_defer_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_error_union_catch_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_try_propagation_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_error_id_binding_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_errdefer_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。
    - [x] lexical drop scope / return cleanup parity。
      - 验证：更新 `bash tests/verify_mir_c99_lexical_drop_parity.sh` 先红灯失败于默认 MIR-C99 generator `writer_status=pending` / exit 70，随后通过，覆盖离开词法作用域 drop 和 helper 函数提前 `return` 后调用者观察到 drop cleanup 的两个真实 MIR-C99 generator / 现有 C99 oracle parity case；`bash tests/verify_portable_mir_language_coverage.sh` 通过（`CORE_STMT_KIND_DROP` MIR-C99 状态更新为 `partial`）；`bash tests/verify_mir_c99_cleanup_drop_cfg_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_full_language_defer_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_errdefer_parity.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_lexical_drop_parity.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/guard 命令退出码均为 0。

  - [x] atomic。
    - 验证：`bash tests/verify_mir_c99_full_language_atomic_reject.sh` 通过；`bash tests/verify_mir_c99_atomic_i32_reject_parity.sh` 通过；`bash tests/verify_mir_c99_atomic_capability_diagnostic.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_atomic_explicit_reject_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过（现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但命令退出 0）；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_atomic_reject.sh` 通过；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：atomic 仍作为 MIR-C99 首版明确 capability reject 收口，不声称已支持原子 C 输出。
    - [x] atomic i32 init/read/compound add explicit reject parity。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_atomic_reject.sh` 先红灯失败于默认 MIR-C99 generator 只返回 generic `writer_status=pending` / `status=not-ready`，随后通过，覆盖 full-language matrix 的 `var value: atomic i32 = 5; value += 2; const read: i32 = value; return read;` case，确认现有 C99 oracle 经 host C compiler 编译运行返回 `7`，同时默认 MIR-C99 generator 不生成 `.c`、不出现 legacy C99 fallback 文本，并以 `subset=atomic_i32_init_read_compound_add`、`status=rejected`、`reject_reason=atomic_capability` 和 `diagnostic_code=MIR_C99_VALUE_DIAG_UNSUPPORTED_ATOMIC_CAPABILITY` 明确 reject；`bash tests/verify_mir_c99_atomic_i32_reject_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过（`AST_TYPE_ATOMIC` MIR-C99 状态更新为 `reject`）；`bash tests/verify_mir_c99_atomic_capability_diagnostic.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_atomic_explicit_reject_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_c99_oracle_default_generator.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_atomic_reject.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic warning，但上述 parity/reject/guard 命令退出码均为 0；本轮仍保持 atomic 为明确 capability reject，不声称 MIR-C99 已支持原子 C 输出。

  - [x] SIMD vector/mask，首版 target 不支持时明确 reject。
    - 验证：新增 `bash tests/verify_mir_c99_full_language_simd_vector_mask_reject.sh` 先红灯失败于默认 MIR-C99 generator 只返回 generic `writer_status=pending` / `status=not-ready`，随后通过，覆盖 `@vector(i32, 4)`、`@mask(4)`、`@vector.splat`、vector multiply、mask compare 和 `@vector.all` 的 full-language case，确认现有 C99 oracle 经 host C compiler 编译运行返回 0，同时默认 MIR-C99 generator 不生成 `.c`、不出现 legacy C99 fallback 文本，并以 `subset=simd_vector_mask_splat_mul_compare_all`、`status=rejected`、`reject_reason=vector_mask_capability` 和 `diagnostic_code=MIR_C99_VALUE_DIAG_UNSUPPORTED_VECTOR_MASK_CAPABILITY` 明确 reject；`bash tests/verify_mir_c99_vector_mask_explicit_reject_plan.sh` 通过（checker-only 临时合并检查通过，期间出现既有 `checker constraint table 容量已满` 警告但类型检查成功）；`bash tests/verify_portable_mir_language_coverage.sh` 通过（`AST_TYPE_VECTOR` / `AST_TYPE_MASK` / `CORE_EXPR_KIND_VECTOR` / `CORE_EXPR_KIND_MASK` MIR-C99 状态更新为 `reject`）；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_simd_vector_mask_reject.sh` 通过；`git diff --check` 通过。说明：本轮仍保持 SIMD vector/mask 为明确 capability reject，不声称 MIR-C99 已支持 SIMD C 输出；接入 target helper capability 后必须迁移为真实 parity。

  - [x] async frame / await / async error union / async cleanup；这些必须支持，不能作为首版 reject。
    - 验证：`bash tests/verify_mir_c99_full_language_async_basic_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_async_control_flow_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_async_frame_pool_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_async_scheduler_compute_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_async_cleanup_resource_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（0 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 async parity 与 guard 命令退出码均为 0；本轮仅收口 async full-language 聚合项。
    - [x] runtime/basic async full-language parity：ready/block_on、@async_fn return、direct @await 和 async error union return。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_async_basic_parity.sh` 先红灯失败于覆盖矩阵仍将 `AST_AWAIT_EXPR` / `@await` MIR-C99 状态标为 `missing`，更新矩阵后通过，覆盖 ready/block_on、`@async_fn` return、direct `@await` binding 和 async error union return 的真实 MIR-C99 generator / 现有 C99 oracle parity；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/verify_mir_c99_full_language_async_basic_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述命令退出码均为 0；control-flow、frame/pool、scheduler/channel/IO/compute 和 cleanup/resource async full-language shards 仍留给后续子任务。
    - [x] control-flow async full-language parity：if/else-if/while/for/nested/multiple await 与 compound try-await。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_async_control_flow_parity.sh` 先红灯失败于覆盖矩阵缺少 control-flow async full-language 证据，更新矩阵后通过，聚合真实 MIR-C99 generator / 现有 C99 oracle parity gates，覆盖 if/else-if、while、range for、array for、nested block、multiple await 和 compound `try @await`；`bash tests/verify_mir_c99_async_control_flow_parity.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/verify_mir_c99_full_language_async_control_flow_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 parity/guard 命令退出码均为 0。
    - [x] frame/pool async full-language parity：@frame type/methods、inline temp、stack/pool/stats/heap fallback。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_async_frame_pool_parity.sh` 先红灯失败于覆盖矩阵缺少 frame/pool async full-language 证据，更新矩阵后通过，聚合真实 MIR-C99 generator / 现有 C99 oracle parity gates，覆盖 `@frame` type/methods、inline temp await、caller-owned frame storage、`@align(64)` frame alignment、`AsyncFramePool` zero stack-limit init、buffer 小帧路径、大帧 heap fallback 和 stats；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/verify_mir_c99_full_language_async_frame_pool_parity.sh` 通过；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 parity/guard 命令退出码均为 0；scheduler/channel/IO/compute 与 cleanup/resource async full-language shards 仍留给后续子任务。
    - [x] scheduler/channel/IO/compute async full-language parity：channel、scheduler event、fd/io、multi-fd 与 async_compute。
      - 验证：新增 `bash tests/verify_mir_c99_full_language_async_scheduler_compute_parity.sh` 先红灯失败于覆盖矩阵缺少 scheduler/channel/IO/compute async full-language 证据，更新矩阵后通过，聚合真实 MIR-C99 generator / 现有 C99 oracle parity gates，覆盖 channel/scheduler event、AsyncFd read/write/read_exact/write_all、multi-fd scheduler event-loop 和 async_compute i32/f32 result path；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/verify_mir_c99_full_language_async_scheduler_compute_parity.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 parity/guard 命令退出码均为 0；async cleanup/resource full-language shard 仍留给后续子任务。
    - [x] async cleanup/resource full-language parity：async error union cleanup、defer/errdefer、frame release 与 make-check manifest 收口。
      - 验证：新增 `bash tests/verify_mir_c99_async_cleanup_resource_parity.sh` 通过，覆盖 async error-union cleanup、async error path 上的 `defer`/`errdefer` cleanup，以及 `@frame` 挂起 child future 后 `frame.stop()` 触发 child `release()` 的 frame release/resource cleanup；新增 `bash tests/verify_mir_c99_full_language_async_cleanup_resource_parity.sh` 通过，聚合 cleanup/resource parity、`bash tests/verify_mir_c99_async_cleanup_release_plan.sh` 和 `bash tests/verify_mir_c99_async_make_check_manifest.sh`，并检查覆盖矩阵与 TODO 证据；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_async_cleanup_resource_parity.sh tests/verify_mir_c99_full_language_async_cleanup_resource_parity.sh` 通过；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）。说明：现有 C99 oracle 编译阶段仍输出既有 pedantic/unused warning，但上述 parity/guard 命令退出码均为 0。

### 4.16 Self Build

- （上下文，原状态 [ ]）MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。
  - [x] `cmd/build` / compiler source 经 parser/checker/CoreBody/PortableMIR 生成 minimal C99。
    - 验证：`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`bash tests/verify_mir_c99_generator_driver_handoff.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（0 个 active task）；`git diff --check` 通过。说明：该收口项仍只生成 summary-only minimal C99，明确记录 `compiler_binary_status=not_yet_generated` 和首个 compiler-source frontier；下一叶仍是 host C compiler 编译真实 MIR-C99 产物得到 compiler binary。
    - [x] 恢复 `src/cmd/build/main.uya` self-build root，并新增 MIR-C99 source-to-PortableMIR / MirC99Plan preflight gate。
      - 验证：新增 `bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 先红灯失败于缺少 `src/cmd/build/main.uya`，随后通过，确认 `cmd/build` source root 导入 `build_compiler_driver`、导出 `main()` 并委托 `build_compiler_driver_main()`，且默认 MIR-C99 generator 对该 root 记录 `handoff_status=verified` / `writer_status=pending` / `status=not-ready`，不生成 C 输出、不出现 legacy C99 fallback；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`bash tests/verify_mir_c99_generator_driver_handoff.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。
    - [x] 默认 MIR-C99 generator 对 `cmd/build` root 输出 minimal C99 sidecar/summary，不写 legacy C99 fallback。
      - 验证：更新 `bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 先红灯失败于旧 generator 仍返回 70 / `writer_status=pending`，随后通过，确认默认 MIR-C99 generator 对真实 `src/cmd/build/main.uya` root 写出 summary-only `.c`、`${output}.summary` sidecar 和 log，host C compiler 可编译该 summary `.c`，执行后以 exit 70 明确报告 `compiler_binary_status=not_yet_generated`，且 log/sidecar/C/stdout/stderr 均无 legacy C99 fallback；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`bash tests/verify_mir_c99_generator_driver_handoff.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。
    - [x] 将首个真实 compiler-source frontier 归因到通用 MIR-C99 缺口，并记录下一步 capability/coverage。
      - 验证：新增 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 先红灯失败于默认 MIR-C99 generator summary log 缺少 `frontier_kind=compiler_source`，随后通过，确认 `cmd/build` summary log/sidecar 记录 `native_hosted_handoff_frontier` / `pending_core_bodies`，归因到通用 `mir_instruction_coverage` 缺口，并记录下一步 `corebody_portable_mir_body_lowering` / `compile_stats_record_and_release_typed_program_stmt9_call`；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`bash tests/verify_mir_c99_generator_driver_handoff.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过。

  - （上下文，原状态 [ ]）host C compiler 编译 MIR-C99 产物得到 compiler binary。
    - [x] 建立 host compiler binary attempt gate：默认 MIR-C99 generator 的 `cmd/build` 输出必须由 host C compiler 编译成候选可执行，并在仍是 summary-only 时记录 compiler-binary attempt、frontier 和 no-fallback 证据。
      - 验证：新增 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于缺少 `host_compiler_binary_attempt=1`，实现后通过，确认默认 MIR-C99 generator 对 `src/cmd/build/main.uya` 输出的 `.c` 可由 `cc -std=c99 -Wall -Wextra -pedantic` 编译成候选可执行；候选执行 `--help` 仍以 exit 70 明确报告 `compiler_binary_status=not_yet_generated` 和 `frontier_name=native_hosted_handoff_frontier`，log/summary 记录 `host_compiler_binary_attempt=1`、`host_compiler_binary_status=not_yet_generated`、`summary_executable` 与当前 `compile_stats_record_and_release_typed_program` stmt9 frontier，且不出现 legacy C99 fallback；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。

    - [x] 将 `compile_stats_record_and_release_typed_program` stmt9 call frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
      - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告 `prefix_stmts=9,next_stmt=9,next_kind=AST_CALL_EXPR`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=10,next_stmt=10,next_kind=AST_ASSIGN`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt10_table_items`，并额外检查 `src/build_compiler_driver.uya` 中的 typed-program aggregate CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。说明：`bash tests/verify_native_compile_stats_typed_program_agg_contract.sh` 另行复验时失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。

    - （上下文，原状态 [ ]）逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。
      - [x] 将 `compile_stats_record_and_release_typed_program` stmt10 table_items frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
        - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告 `prefix_stmts=10,next_stmt=10,next_kind=AST_ASSIGN`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=11,next_stmt=11,next_kind=AST_ASSIGN`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt11_table_capacity`，并额外检查 `src/build_compiler_driver.uya` 中的 table_items CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（0 个 active task）；`git diff --check` 通过。

      - （上下文，原状态 [ ]）继续按 summary frontier 递进清空后续 `pending_core_bodies`，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。
        - [x] 将 `compile_stats_record_and_release_typed_program` stmt11 table_capacity frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告 `prefix_stmts=11,next_stmt=11,next_kind=AST_ASSIGN`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=12,next_stmt=12,next_kind=AST_ASSIGN`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt12_table_used_bytes`，并额外检查 `src/build_compiler_driver.uya` 中的 table_capacity CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成后 0 个 active task）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_compile_stats_table_capacity_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。

        - [x] 将 `compile_stats_record_and_release_typed_program` stmt12 table_used_bytes frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `prefix_stmts=12,next_stmt=12,next_kind=AST_ASSIGN`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=13,next_stmt=13,next_kind=AST_ASSIGN`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt13_table_capacity_bytes`，并额外检查 `src/build_compiler_driver.uya` 中的 table_used_bytes CoreBody/PortableMIR 支持入口；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_compile_stats_table_used_bytes_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。

        - [x] 将 `compile_stats_record_and_release_typed_program` stmt13 table_capacity_bytes frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `prefix_stmts=13,next_stmt=13,next_kind=AST_ASSIGN`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=14,next_stmt=14,next_kind=AST_ASSIGN`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt14_table_realloc_count`，并额外检查 `src/build_compiler_driver.uya` 中的 table_capacity_bytes CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_compile_stats_table_capacity_bytes_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。

        - [x] 将 `compile_stats_record_and_release_typed_program` stmt14 table_realloc_count frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `prefix_stmts=14,next_stmt=14,next_kind=AST_ASSIGN`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=15,next_stmt=15,next_kind=AST_CALL_EXPR`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt15_typed_program_release`，并额外检查 `src/build_compiler_driver.uya` 中的 table_realloc_count CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（0 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/... --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/... --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compile_stats_record_and_release_typed_program` stmt15 typed_program_release frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `prefix_stmts=15,next_stmt=15,next_kind=AST_CALL_EXPR`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=16,next_stmt=16,next_kind=AST_CALL_EXPR`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt16_typed_type_records_release`，并额外检查 `src/build_compiler_driver.uya` 中的 typed_program_release CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过（恢复本地忽略的 `bin/cmd/check` 等子命令）；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_compile_stats_typed_program_release_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compile_stats_record_and_release_typed_program` stmt16 typed_type_records_release frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `prefix_stmts=16,next_stmt=16,next_kind=AST_CALL_EXPR`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `prefix_stmts=17,next_stmt=17,next_kind=AST_ASSIGN`，下一步 coverage 为 `compile_stats_record_and_release_typed_program_stmt17_typed_program_released_bytes`，并额外检查 `src/build_compiler_driver.uya` 中的 typed_type_records_release CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过（恢复本地忽略的 `bin/cmd/check` 等子命令）；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（首次运行因 `bin/cmd/check` 缺失失败，`make cmds` 后复验通过；期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_compile_stats_typed_type_records_release_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compile_stats_record_and_release_typed_program` stmt17 typed_program_released_bytes frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 缺少 `completed_body_detail=native_hosted_reachable_body_complete:function=compile_stats_record_and_release_typed_program,prefix_stmts=18,reason=body_complete`；随后通过，确认 cmd/build summary log/sidecar 已记录 stmt17 `compile_stats_record_and_release_typed_program_stmt17_typed_program_released_bytes` 已完成，并将当前 frontier 前移到 `native_hosted_pending_body_frontier:function=compiler_should_profile_diagnostics,decl=225,function_id=5,body_stmts=4,reason=pending_core_body`，下一步 coverage 为 `compiler_should_profile_diagnostics_first_slice`；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过（恢复本地忽略的 `bin/cmd/check` 等子命令）；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（首次运行因 `bin/cmd/check` 缺失失败，`make cmds` 后复验通过；期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_should_profile_diagnostics` first slice frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 缺少 `completed_coverage=compiler_should_profile_diagnostics_first_slice`；随后通过，确认 cmd/build summary log/sidecar 已将当前 frontier 从 `native_hosted_pending_body_frontier:function=compiler_should_profile_diagnostics` 前移到 `native_hosted_reachable_body_frontier:function=compiler_should_profile_diagnostics,prefix_stmts=1,next_stmt=1,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `compiler_should_profile_diagnostics_null_empty_branch`，并额外检查 `src/build_compiler_driver.uya` 中的 profile diagnostics getenv CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过（恢复本地忽略的 `bin/cmd/check` 等子命令）；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（首次运行因 `bin/cmd/check` 缺失失败，`make cmds` 后复验通过；期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_profile_diagnostics_first_slice_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_should_profile_diagnostics` null/empty branch frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=compiler_should_profile_diagnostics_first_slice`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `native_hosted_reachable_body_frontier:function=compiler_should_profile_diagnostics,prefix_stmts=2,next_stmt=2,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `compiler_should_profile_diagnostics_false_like_branch`，并额外检查 `src/build_compiler_driver.uya` 中的 null/empty branch CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过（恢复本地忽略的 `bin/cmd/check` 等子命令）；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（首次运行因 `bin/cmd/check` 缺失失败，`make cmds` 后复验通过；期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_should_profile_diagnostics` false-like branch frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=compiler_should_profile_diagnostics_null_empty_branch`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `native_hosted_reachable_body_frontier:function=compiler_should_profile_diagnostics,prefix_stmts=3,next_stmt=3,next_kind=return,reason=partial_core_body`，下一步 coverage 为 `compiler_should_profile_diagnostics_tail_return`，并额外检查 `src/build_compiler_driver.uya` 中的 false-like branch CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过（恢复本地忽略的 `bin/cmd/check` 等子命令）；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（首次运行因 `bin/cmd/check` 缺失失败，`make cmds` 后复验通过；期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_false_like --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_false_like_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_should_profile_diagnostics` tail_return frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 缺少 `completed_body_detail=native_hosted_reachable_body_complete:function=compiler_should_profile_diagnostics,prefix_stmts=4,reason=body_complete`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `native_hosted_pending_body_frontier:function=compiler_print_diagnostic_profile,decl=246,function_id=6,body_stmts=4,reason=pending_core_body`，下一步 coverage 为 `compiler_print_diagnostic_profile_guard`，并额外检查 `src/build_compiler_driver.uya` 中的 tail_return CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过（恢复本地忽略的 `bin/cmd/check` 等子命令）；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（首次运行因 `bin/cmd/check` 缺失失败，`make cmds` 后复验通过；期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_tail --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_tail_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_print_diagnostic_profile` guard frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=compiler_print_diagnostic_profile_guard`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `native_hosted_reachable_body_frontier:function=compiler_print_diagnostic_profile,prefix_stmts=1,next_stmt=1,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `compiler_print_diagnostic_profile_count`，并额外检查 `src/build_compiler_driver.uya` 中的 print diagnostic profile guard CoreBody/PortableMIR 支持入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh`、`bash -n tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash -n tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make cmds` 通过；`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_guard --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_guard_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_print_diagnostic_profile` count frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=compiler_print_diagnostic_profile_guard`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `native_hosted_reachable_body_frontier:function=compiler_print_diagnostic_profile,prefix_stmts=2,next_stmt=2,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `compiler_print_diagnostic_profile_checker_branch`，并额外检查 `src/build_compiler_driver.uya` 中的 count CoreBody/PortableMIR 支持入口和 count MIR lowering 不再委托 guard-only body；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_print_diagnostic_profile_count_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 任务文本，未作为本轮 MIR-C99 验收证据。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_count --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_count_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_print_diagnostic_profile` checker_branch frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=compiler_print_diagnostic_profile_count`；随后通过，确认 cmd/build summary log/sidecar 已前移到 `native_hosted_reachable_body_frontier:function=compiler_print_diagnostic_profile,prefix_stmts=3,next_stmt=3,next_kind=AST_CALL_EXPR,reason=partial_core_body`，下一步 coverage 为 `compiler_print_diagnostic_profile_tail_fprintf`，并额外检查 `src/build_compiler_driver.uya` 中 checker_branch MIR lowering 不再委托 guard/count body，而是保留 count local、checker 条件、field load 和 local set；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`git diff --check` 通过。说明：额外复验 `bash tests/verify_native_print_diagnostic_profile_checker_branch_contract.sh` 失败于旧上层 `docs/todo_compiler_1s.md` 缺少该 native 合同任务文本，未作为本轮 MIR-C99 验收证据。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_checker_branch --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_checker_branch_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `compiler_print_diagnostic_profile` tail_fprintf frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=compiler_print_diagnostic_profile_checker_branch` / 旧 `compiler_print_diagnostic_profile_tail_fprintf` frontier；随后通过，确认 cmd/build summary log/sidecar 已记录 `compiler_print_diagnostic_profile_tail_fprintf` 完成、`compiler_print_diagnostic_profile` body complete，并将当前 frontier 前移到 `native_hosted_pending_body_frontier:function=build_driver_run,decl=290,function_id=7,body_stmts=39,reason=pending_core_body`，下一步 coverage 为 `build_driver_run_first_slice`；同时检查 `src/build_compiler_driver.uya` 中 tail MIR lowering 复用 checker prefix 后追加真实 `fprintf` call、4 个 call operands、tail block `return`，且不再标记 partial body；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_tail_fprintf --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_tail_fprintf_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` first_slice frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=compiler_print_diagnostic_profile_tail_fprintf` / `next_coverage=build_driver_run_first_slice`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_first_slice`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=12,next_stmt=12,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_parse_prefix`；同时检查 `src/build_compiler_driver.uya` 中 `native_build_hosted_decl_has_pending_core_body` 不再把可 materialize 的 `build_driver_run` first slice 当作 pending body；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` parse_prefix frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=build_driver_run_first_slice`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_parse_prefix`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=15,next_stmt=15,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_stack_init`；同时检查 `src/build_compiler_driver.uya` 中 parse prefix CoreBody/PortableMIR 支持入口、parse_build_args call operands 和 parse prefix control lowering；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_parse_prefix --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_parse_prefix_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` stack_init frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_stack_init`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_stack_init`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=16,next_stmt=16,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_stack_guard`；同时检查 `src/build_compiler_driver.uya` 中 stack_init CoreBody/PortableMIR 支持入口、stack_init prefix count 和 MIR prefix 扩展入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_stack_init --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_stack_init_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` stack_guard frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_stack_guard`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_stack_guard`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=17,next_stmt=17,next_kind=AST_CALL_EXPR,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_stack_limit_call`；同时检查 `src/build_compiler_driver.uya` 中 stack_guard CoreBody/PortableMIR 支持入口、stack_guard prefix count 和 MIR prefix 扩展入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_stack_guard --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_stack_guard_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` stack_limit_call frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍报告旧 `completed_coverage=build_driver_run_stack_guard` / `next_coverage=build_driver_run_stack_limit_call`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_stack_limit_call`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=18,next_stmt=18,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_split_env`；同时检查 `src/build_compiler_driver.uya` 中 stack_limit_call CoreBody/PortableMIR 支持入口、stack_limit prefix count 和 MIR prefix 扩展入口；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_stack_limit --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_stack_limit_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` split_env frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`，确认默认 MIR-C99 generator 已记录 `completed_coverage=build_driver_run_split_env`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=19,next_stmt=19,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_output_path`；同时检查 `src/build_compiler_driver.uya` 中 split_env CoreBody/PortableMIR 支持入口、`include_split_env` 和 `getenv_call_inst` MIR lowering；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_split_env --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_split_env_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` output_path frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_output_path`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_output_path`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=20,next_stmt=20,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_user_output_path`；同时检查 `src/build_compiler_driver.uya` 中 output_path CoreBody/PortableMIR 支持入口、`include_output_path` 和 `host_fill_temp_c_compile_path` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验 `./bin/uya check src/cmd/build/main.uya --project-root src/` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task，标完成后 0 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_output_path --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_output_path_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` user_output_path frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 先红灯失败于 coverage matrix 仍缺少 `build_driver_run_user_output_path` 已完成记录；随后 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 和 `bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_user_output_path`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=21,next_stmt=21,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_explicit_output_path`；同时检查 `src/build_compiler_driver.uya` 中 user_output_path CoreBody/PortableMIR 支持入口、`include_user_output_path` 和 `user_output_path_inst` lowering 痕迹；`./bin/uya check src/cmd/build/main.uya` 通过；`./bin/uya check src/build_compiler_driver.uya` 通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 继续按 summary frontier 递进清空后续 `pending_core_bodies`：将 `build_driver_run` explicit_output_path frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_explicit_output_path`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_explicit_output_path`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=22,next_stmt=22,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_llvm_backend_c99_rewrite`；同时检查 `src/build_compiler_driver.uya` 中 explicit_output_path 支持入口、`include_explicit_output_path`、`get_argv_call_inst` 和 `out_path_cond_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 和 `./bin/uya check src/build_compiler_driver.uya` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验二者通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` LLVM backend -> C99 rewrite frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_llvm_backend_c99_rewrite`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_llvm_backend_c99_rewrite`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=23,next_stmt=23,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_split_c_default`；同时检查 `src/build_compiler_driver.uya` 中 LLVM backend -> C99 rewrite 支持入口、`include_backend_fallback` 和 `backend_fallback_assign_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；首次 `./bin/uya check src/cmd/build/main.uya --project-root src/` 和 `./bin/uya check src/build_compiler_driver.uya` 因本地忽略的 `./bin/cmd/check` 缺失失败，`make cmds` 通过后复验二者通过（期间出现既有 checker constraint / pointer nonnull table 容量警告但类型检查成功）；`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（标完成前 1 个 active task）；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`；直接复现 `./bin/uya build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_llvm_rewrite --no-split-c --project-root src/` 和 `./bin/cmd/build build src/cmd/build/main.uya -o /tmp/uya_cmd_build_repro_llvm_rewrite_cmd --no-split-c --project-root src/` 同样失败。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` split_c_default frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_split_c_default`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_split_c_default`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=24,next_stmt=24,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_output_path_for_compile`；同时检查 `src/build_compiler_driver.uya` 中 split_c_default 支持入口、`include_split_c_default` 和 `split_c_default_cond_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`git diff --check` 通过。
          - 提交前验证：`make clean` 通过；`make backup-all` 失败于 `cmd-build-current` 重建 `bin/cmd/build`，报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`，随后 `mv: cannot stat 'bin/cmd/build.tmp': No such file or directory`。按 AGENTS 提交前规则，本轮未提交也未推送。

        - [x] 将 `build_driver_run` output_path_for_compile frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
          - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_output_path_for_compile`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_output_path_for_compile`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=25,next_stmt=25,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_output_path_selection`；同时检查 `src/build_compiler_driver.uya` 中 output_path_for_compile 支持入口、`include_output_path_for_compile` 和 `output_path_for_compile_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`git diff --check` 通过。

### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 将 `build_driver_run` output_path_selection frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：
    - `./tests/verify_mir_c99_cmd_build_frontier_summary.sh` -> OK: MIR-C99 cmd/build summary records the first self-build frontier
    - `./tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` -> OK: MIR-C99 cmd/build host compiler binary attempt gate records summary-only frontier
    - `./tests/verify_mir_c99_cmd_build_self_preflight.sh` -> OK: cmd/build MIR-C99 self-build root emits summary-only C output

- [x] 将 `build_driver_run` split_c_arg frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_split_c_arg`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_split_c_arg`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=27,next_stmt=27,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_split_c_arg_assign`；同时检查 `src/build_compiler_driver.uya` 中 split_c_arg 支持入口、`include_split_c_arg` 和 `split_c_arg_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 失败于全量 `make check` 的 `test_syscall_layer`、`test_osal` 链接步骤，关键错误为生成 C 中 `#define SYS_gettimeofday 96` 与 `const int64_t SYS_gettimeofday = 96;` 宏/常量同名冲突。按 AGENTS 提交前规则，本轮未提交也未推送。

- [x] 将 `build_driver_run` split_c_arg_assign frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_split_c_arg_assign`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_split_c_arg_assign`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=28,next_stmt=28,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_artifacts`；同时检查 `src/build_compiler_driver.uya` 中 split_c_arg_assign 支持入口、`include_split_c_arg_assign` 和 `split_c_arg_assign_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 失败于全量 `make check` 的 `test_syscall_layer`、`test_osal` 链接步骤，关键错误为生成 C 中 `#define SYS_gettimeofday 96` 与 `const int64_t SYS_gettimeofday = 96;` 宏/常量同名冲突。按 AGENTS 提交前规则，本轮未提交也未推送。

- [x] 将 `build_driver_run` artifacts frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_artifacts`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_artifacts`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=29,next_stmt=29,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_split_c_lock`；同时检查 `src/build_compiler_driver.uya` 中 artifacts 支持入口、`include_artifacts` 和 `artifacts_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档前 1 个 active task）；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 失败于全量 `make check` 的 `test_syscall_layer`、`test_osal` 链接步骤，1024 个测试中 1022 个通过，关键错误为生成 C 中 `#define SYS_gettimeofday 96` 与 `const int64_t SYS_gettimeofday = 96;` 宏/常量同名冲突。按 AGENTS 提交前规则，本轮未提交也未推送。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 将 `build_driver_run` split_c_lock frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_split_c_lock`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_split_c_lock`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=30,next_stmt=30,next_kind=AST_DEFER_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_split_c_lock_defer`；同时检查 `src/build_compiler_driver.uya` 中 split_c_lock 支持入口、`include_split_c_lock` 和 `split_c_lock_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档前 1 个 active task）；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 失败于全量 `make check` 的 `test_syscall_layer`、`test_osal` 链接步骤，1024 个测试中 1022 个通过，关键错误为生成 C 中 `#define SYS_gettimeofday 96` 与 `const int64_t SYS_gettimeofday = 96;` 宏/常量同名冲突。按 AGENTS 提交前规则，本轮未提交也未推送。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 将 `build_driver_run` split_c_lock_defer frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_split_c_lock_defer`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_split_c_lock_defer`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=31,next_stmt=31,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_split_c_lock_acquire`；同时检查 `src/build_compiler_driver.uya` 中 split_c_lock_defer 支持入口、`include_split_c_lock_defer` 和 `split_c_lock_defer_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档前 1 个 active task）；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 失败于全量 `make check` 的 `test_syscall_layer`、`test_osal` 链接步骤，1024 个测试中 1022 个通过，关键错误为生成 C 中 `#define SYS_gettimeofday 96` 与 `const int64_t SYS_gettimeofday = 96;` 宏/常量同名冲突。按 AGENTS 提交前规则，本轮未提交也未推送。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 将 `build_driver_run` split_c_lock_acquire frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_split_c_lock_acquire`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_split_c_lock_acquire`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=32,next_stmt=32,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_compile_result`；同时检查 `src/build_compiler_driver.uya` 中 split_c_lock_acquire 支持入口、`include_split_c_lock_acquire` 和 `split_c_lock_acquire_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档前 1 个 active task）；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 失败于全量 `make check` 的 `test_syscall_layer`、`test_osal` 链接步骤，1024 个测试中 1022 个通过，关键错误为生成 C 中 `#define SYS_gettimeofday 96` 与 `const int64_t SYS_gettimeofday = 96;` 宏/常量同名冲突。按 AGENTS 提交前规则，本轮未提交也未推送。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 将 `build_driver_run` compile_result frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_compile_result`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_compile_result`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=33,next_stmt=33,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_result_error`；同时检查 `src/build_compiler_driver.uya` 中 compile_result 支持入口、`include_compile_result` 和 `compile_result_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档前 1 个 active task）；`make uya` 通过；`git diff --check` 通过。
父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 将 `build_driver_run` result_error frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_result_error`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_result_error`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=34,next_stmt=34,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_native_success`；同时检查 `src/build_compiler_driver.uya` 中 result_error 支持入口、`include_result_error`、`result_error_cond_inst` 和 `result_error_return_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档前 1 个 active task）；`make uya` 通过；`git diff --check` 通过。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 将 `build_driver_run` native_success frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_native_success`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_native_success`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=35,next_stmt=35,next_kind=AST_VAR_DECL,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_is_output_c_file`；同时检查 `src/build_compiler_driver.uya` 中 native_success 支持入口、`include_native_success`、`native_success_fprintf_inst` 和 `native_success_return_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档后 0 个 active task）；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 通过，并更新 `backup/cmd-build-linux-x86_64-blob.c`。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 迁入 `build_driver_run_is_output_c_file` coverage，推动 `cmd/build` self-build frontier 前移到下一条真实 compiler-source 语句。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_is_output_c_file`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_is_output_c_file`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=36,next_stmt=36,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_c_output_check`；同时检查 `src/build_compiler_driver.uya` 中 `native_build_hosted_build_driver_run_is_output_c_file_prefix_stmt_count`、`NATIVE_BUILD_DRIVER_RUN_IS_OUTPUT_C_FILE_PREFIX_STMT_COUNT`、`include_is_output_c_file` 和 `is_output_c_file_inst` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档后 0 个 active task）；`make uya` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 通过，并更新 `backup/cmd-build-linux-x86_64-blob.c`。

- [x] 迁入 `build_driver_run_c_output_check` coverage，推动 `cmd/build` self-build frontier 前移到下一条真实 compiler-source 语句。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_c_output_check`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=37,next_stmt=37,next_kind=AST_IF_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_link_output`；同时检查 `src/build_compiler_driver.uya` 中 `native_build_hosted_build_driver_run_c_output_check_prefix_stmt_count`、`NATIVE_BUILD_DRIVER_RUN_C_OUTPUT_CHECK_PREFIX_STMT_COUNT`、`include_c_output_check`、`c_output_check_cond_inst` 和 `c_output_check_after_block` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档前 0 个 active task）；`git diff --check` 通过。额外探测：`bash tests/verify_native_cmd_build_no_silent_c99.sh` 失败于既有 `bin/uya` hosted native inventory preflight（`native_hosted_coreir_preflight: status=-1 ... core_bodies=1`），未作为本轮通过条件。
  - 提交前验证：`make clean` 通过；`make backup-all` 通过，并更新 `backup/cmd-build-linux-x86_64-blob.c`。

- [x] 迁入 `build_driver_run_link_output` coverage，推动 `cmd/build` self-build frontier 前移到下一条真实 compiler-source 语句。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_link_output`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_link_output`，并将当前 frontier 前移到 `native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=38,next_stmt=38,next_kind=AST_RETURN_STMT,reason=partial_core_body`，下一步 coverage 为 `build_driver_run_final_return`；同时检查 `src/build_compiler_driver.uya` 中 `native_build_hosted_build_driver_run_link_output_prefix_stmt_count`、`NATIVE_BUILD_DRIVER_RUN_LINK_OUTPUT_PREFIX_STMT_COUNT`、`include_link_output`、`link_output_cond_inst` 和 `link_output_after_block` lowering 痕迹；`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过（归档后 0 个 active task）；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`git diff --check` 通过。
  - 提交前验证：`make clean` 通过；`make backup-all` 通过，并更新 `backup/cmd-build-linux-x86_64-blob.c`。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 迁入 `build_driver_run_final_return` coverage，推动 `cmd/build` self-build frontier 前移到下一条真实 compiler-source 语句。
  - 验证：更新 `bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 和 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 先红灯失败于默认 MIR-C99 generator 仍缺少 `completed_coverage=build_driver_run_final_return` / `completed_body_detail=native_hosted_reachable_body_complete:function=parse_build_args,prefix_stmts=28,reason=body_complete`；随后通过，确认 cmd/build summary log/sidecar 已记录 `completed_coverage=build_driver_run_final_return`，并将当前 frontier 前移到 `native_hosted_pending_body_frontier:function=native_build_decl_is_extern_two_i32_param_fn,decl=400,function_id=41,body_stmts=7,reason=pending_core_body`，下一步 coverage 为 `native_build_decl_is_extern_two_i32_param_fn_first_slice`；同时同步 `docs/portable_mir_language_coverage.md` 的 self-build 矩阵记录 final_return 已完成和新的 next coverage；`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过。
  - 方向校正（2026-06-13）：上述 pending body 只作为真实 self-build 样本；active TODO / summary gate 已改为 `generic_corebody_guard_call_tail_return_lowering`，禁止按 `native_build_decl_is_extern_two_i32_param_fn` 名称或固定 7-stmt shape 继续扩展。

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 以当前 self-build 样本 frontier（`native_build_decl_is_extern_two_i32_param_fn` pending body）校准通用 CoreBody -> PortableMIR 结构化函数体 lowering：覆盖 if guard / 短路 OR、field load、array index、const local、resolved helper call 和 tail call return；验收只接受真实 frontier 前移与通用 lowering 证据，禁止新增按该 helper 名称或固定 7-stmt body shape 的 materializer。
  - 验证：已有改动将 cmd/build summary/sidecar 从 helper-specific `native_build_decl_is_extern_two_i32_param_fn_first_slice` 校准为 `next_coverage=generic_corebody_guard_call_tail_return_lowering`，并在 `tests/verify_portable_mir_core_body_lowering.sh` 增加通用证据 gate：`native_build_expr_bool_const_value` / `TOKEN_LOGICAL_OR` / `native_build_member_access_object_field_equals` / `native_build_array_index0_identifier` / `native_build_resolve_reachable_const2_i32_call` / `native_build_expr_to_body_op`，同时 reject helper 名称或固定 7-stmt body shape materializer；`make cmds` 通过；`bash tests/verify_portable_mir_core_body_lowering.sh` 通过；`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_default_generator_command.sh` 通过；`bash tests/verify_mir_c99_default_generator_writes_subset.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh tests/verify_portable_mir_core_body_lowering.sh` 通过。

### 4.16 Self Build 中间状态归档（2026-06-13）

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- 中间状态：已把通用 `guard_call_tail_return` body 纳入 CoreBody -> PortableMIR preflight，`native_build_decl_is_extern_two_i32_param_fn` 记录为 body-complete；当前 frontier 前进到 `native_build_decl_is_one_i32_ptr_param_fn` / `generic_corebody_pointer_param_guard_tail_return_lowering`。
  - 验证：`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 均通过。
- 中间状态：已把通用 `guard_call_tail_return` body 放宽到单/双参数 guard-tail-return 形状，`native_build_decl_is_one_i32_ptr_param_fn` 记录为 body-complete；当前 frontier 前进到 `native_build_decl_is_two_i32_ptr_param_fn` / `generic_corebody_two_pointer_param_guard_tail_return_lowering`。
  - 验证：`make cmds`、`bash tests/verify_portable_mir_core_body_lowering.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`、`bash tests/verify_mir_c99_default_generator_command.sh`、`bash tests/verify_mir_c99_default_generator_writes_subset.sh`、`bash tests/verify_portable_mir_language_coverage.sh`、`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`、`bash tests/verify_mir_c99_independent_boundary.sh`、`bash tests/verify_mir_c99_minimal_subset_contract.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 均通过。
- 中间状态：确认通用 `guard_call_tail_return` body 已覆盖 two pointer-param helper，`native_build_decl_is_two_i32_ptr_param_fn` 记录为 body-complete；当前 frontier 前进到 `native_build_decl_is_parse11_i32_fn` / `generic_corebody_parse11_pointer_out_param_lowering`。
  - 验证：`bash tests/verify_portable_mir_core_body_lowering.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`、`bash tests/verify_mir_c99_default_generator_command.sh`、`bash tests/verify_mir_c99_default_generator_writes_subset.sh`、`bash tests/verify_portable_mir_language_coverage.sh`、`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`、`bash tests/verify_mir_c99_independent_boundary.sh`、`bash tests/verify_mir_c99_minimal_subset_contract.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`、`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`git diff --check` 均通过。
- 中间状态：已为 `native_build_decl_is_parse11_i32_fn` 补 `generic_corebody_parse11_pointer_out_param_lowering` 合同与 summary 证据，并把 parse11 pointer out-param shape 纳入 hosted safe-core materializer；当前 summary frontier 前进到 `native_build_lowered_plan_empty` / `generic_corebody_empty_struct_return_lowering`。
  - 验证：`bash tests/verify_native_decl_is_parse11_i32_fn_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`、`bash tests/verify_portable_mir_core_body_lowering.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`、`bash tests/verify_native_cmd_build_regression_boundary.sh`、`bash tests/verify_mir_c99_default_generator_command.sh`、`bash tests/verify_mir_c99_default_generator_writes_subset.sh`、`bash tests/verify_portable_mir_language_coverage.sh`、`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`、`bash tests/verify_mir_c99_independent_boundary.sh`、`bash tests/verify_mir_c99_minimal_subset_contract.sh` 通过；`bash tests/verify_native_cmd_build_stage1.sh` 仍失败，当前阻塞在 `tests/verify_native_cmd_build_no_silent_c99.sh` 的普通 `test_native_main_only.uya --native` preflight 期望：实际输出 `native_hosted_coreir_preflight: status=-1 ... pending_bodies=178`。
- 中间状态：本轮锁定 `native_build_lowered_plan_empty()` 嵌套 struct literal return 的 body-complete 合同，目标 coverage 为 `generic_corebody_empty_struct_return_lowering`，要求默认 MIR-C99 generator summary 继续前移到下一处真实 `pending_core_bodies` frontier。
- 中间状态：已把 `native_build_lowered_plan_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_reachability_empty` / `generic_corebody_reachability_empty_struct_return_lowering`。
  - 验证：`bash tests/verify_native_lowered_plan_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`、`bash tests/verify_mir_c99_default_generator_command.sh`、`bash tests/verify_mir_c99_default_generator_writes_subset.sh`、`bash tests/verify_portable_mir_language_coverage.sh`、`bash tests/verify_mir_c99_minimal_subset_contract.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`、`git diff --check` 均通过。
- 中间状态：本轮锁定 `native_build_reachability_empty()` struct literal return 的 body-complete 合同，目标 coverage 为 `generic_corebody_reachability_empty_struct_return_lowering`，要求默认 MIR-C99 generator summary 继续前移到下一处真实 `pending_core_bodies` frontier。
- 中间状态：已把 `native_build_reachability_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_local_table_empty` / `generic_corebody_local_table_empty_struct_return_lowering`。
  - 验证：`bash tests/verify_native_reachability_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`、`bash tests/verify_mir_c99_default_generator_command.sh`、`bash tests/verify_mir_c99_default_generator_writes_subset.sh`、`bash tests/verify_portable_mir_language_coverage.sh`、`bash tests/verify_mir_c99_minimal_subset_contract.sh`、`bash tests/verify_portable_mir_core_body_lowering.sh`、`bash tests/verify_mir_c99_independent_boundary.sh`、`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`、`git diff --check` 均通过；`bash tests/verify_native_cmd_build_no_silent_c99.sh` 仍失败，当前仍阻塞在普通 `test_native_main_only.uya --native` preflight：`native_hosted_coreir_preflight: status=-1 ... pending_bodies=178`。
- 中间状态：本轮锁定 `native_build_local_table_empty()` struct literal return 的 body-complete 合同，目标 coverage 为 `generic_corebody_local_table_empty_struct_return_lowering`，要求默认 MIR-C99 generator summary 继续前移到下一处真实 `pending_core_bodies` frontier。
- 中间状态：已把 `native_build_local_table_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_const_slice_sum_shape_empty` / `generic_corebody_const_slice_sum_shape_empty_struct_return_lowering`。
  - 验证：`bash tests/verify_native_local_table_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`、`bash tests/verify_mir_c99_default_generator_command.sh`、`bash tests/verify_mir_c99_default_generator_writes_subset.sh`、`bash tests/verify_portable_mir_language_coverage.sh`、`bash tests/verify_mir_c99_minimal_subset_contract.sh`、`bash tests/verify_portable_mir_core_body_lowering.sh`、`bash tests/verify_mir_c99_independent_boundary.sh`、`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 均通过。

### 4.16 Self Build

父级任务路径：
- MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。
- host C compiler 编译 MIR-C99 产物得到 compiler binary。
- 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

完成子任务：
- [x] 锁定 `native_build_lexical_drop_shape_empty()` struct literal return 的 body-complete 合同，并把默认 MIR-C99 generator summary 前移到 `native_build_interface_method_shape_empty` / `generic_corebody_interface_method_shape_empty_struct_return_lowering`。
  - 完成条件：`cmd/build` summary fixture 记录 `native_build_lexical_drop_shape_empty()` body-complete，且下一处真实 compiler-source frontier 改为 `native_build_interface_method_shape_empty`。
  - 最小验证：`bash tests/verify_native_lexical_drop_shape_empty_contract.sh`、`bash tests/verify_native_interface_method_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`。
  - 2026-06-14：已把 `native_build_lexical_drop_shape_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_interface_method_shape_empty` / `generic_corebody_interface_method_shape_empty_struct_return_lowering`。
  - 验证：`bash tests/verify_native_lexical_drop_shape_empty_contract.sh`、`bash tests/verify_native_interface_method_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过；`bash tests/verify_native_cmd_build_no_silent_c99.sh` 仍失败于普通 `test_native_main_only.uya --native` preflight：`native_hosted_pending_body_frontier: function=native_main_bval ... pending_bodies=178`。

### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。

- [x] 锁定 `native_build_interface_method_shape_empty()` struct literal return 的 body-complete 合同，并把默认 MIR-C99 generator summary 前移到下一处真实 `pending_core_bodies` frontier。
  - 完成条件：`cmd/build` summary fixture 记录 `native_build_interface_method_shape_empty()` body-complete，且下一处真实 compiler-source frontier 改为 `native_build_direct_method_shape_empty`。
  - 2026-06-14：已把 `native_build_interface_method_shape_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_direct_method_shape_empty` / `generic_corebody_direct_method_shape_empty_struct_return_lowering`。
  - 2026-06-14：修正 `tests/verify_native_direct_method_shape_empty_contract.sh` 的 TODO 路径到 `docs/todo_mir_c99_backend.md`，确保 direct-method contract 跟随当前 MIR-C99 backend todo。
  - 验证：`bash tests/verify_native_interface_method_shape_empty_contract.sh`、`bash tests/verify_native_direct_method_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`git diff --check` 通过。
### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。
- [x] 锁定 `native_build_direct_method_shape_empty()` struct literal return 的 body-complete 合同，并把默认 MIR-C99 generator summary 前移到下一处真实 `pending_core_bodies` frontier。
  - 完成条件：`cmd/build` summary fixture 记录 `native_build_direct_method_shape_empty()` body-complete，且下一处真实 compiler-source frontier 改为 `native_build_struct_union_enum_shape_empty`。
  - 2026-06-14：已把 `native_build_direct_method_shape_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_struct_union_enum_shape_empty` / `generic_corebody_struct_union_enum_shape_empty_struct_return_lowering`。
  - 2026-06-14：修正 `tests/verify_native_struct_union_enum_shape_empty_contract.sh` 的 TODO 路径到 `docs/todo_mir_c99_backend.md`，确保 struct/union/enum contract 跟随当前 MIR-C99 backend todo。
  - 验证：`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`bash tests/verify_native_direct_method_shape_empty_contract.sh`、`bash tests/verify_native_struct_union_enum_shape_empty_contract.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`、`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cmd_build_frontier_summary.sh tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh tests/verify_native_struct_union_enum_shape_empty_contract.sh`、`git diff --check` 通过；`bash tests/verify_native_cmd_build_stage1.sh` 仍失败于既有 `tests/verify_native_cmd_build_compiler_regressions.sh` 的 hosted_array_index 子例：`bin/cmd/build build ... hosted_array_index.uya --native --no-split-c --project-root /tmp/...` 非零退出。

### 4.16 Self Build
路径：`MIR-C99-BACKEND-SELF-BUILD` -> `host C compiler 编译 MIR-C99 产物得到 compiler binary。` -> `逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。` -> `沿真实 `pending_core_bodies` frontier 继续前移 default MIR-C99 generator summary，直到 `cmd/build` root 输出真实 compiler candidate C。`
        - [x] 本轮锁定 `native_build_struct_union_enum_shape_empty()` struct literal return 的 body-complete 合同，目标 coverage 为 `generic_corebody_struct_union_enum_shape_empty_struct_return_lowering`，完成条件是默认 MIR-C99 generator summary 前移到下一处真实 `pending_core_bodies` frontier；最小验证：`bash tests/verify_native_struct_union_enum_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`。
          - 2026-06-14：已把 `native_build_struct_union_enum_shape_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_atomic_i32_shape_empty` / `generic_corebody_atomic_i32_shape_empty_struct_return_lowering`。
          - 验证：`bash tests/verify_native_struct_union_enum_shape_empty_contract.sh`、`bash tests/verify_native_atomic_i32_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过；`bash tests/verify_native_cmd_build_no_silent_c99.sh` 仍失败于普通 `test_native_main_only.uya --native` preflight：`native_hosted_coreir_preflight: status=-1 verifier_error=0 functions=617 core_bodies=3 pending_bodies=178`。

路径：`MIR-C99-BACKEND-SELF-BUILD` -> `host C compiler 编译 MIR-C99 产物得到 compiler binary。` -> `逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。` -> `沿真实 `pending_core_bodies` frontier 继续前移 default MIR-C99 generator summary，直到 `cmd/build` root 输出真实 compiler candidate C。`
        - [x] 下一轮锁定 `native_build_atomic_i32_shape_empty()` struct literal return 的 body-complete 合同，目标 coverage 为 `generic_corebody_atomic_i32_shape_empty_struct_return_lowering`，完成条件是默认 MIR-C99 generator summary 前移到下一处真实 `pending_core_bodies` frontier；最小验证：`bash tests/verify_native_atomic_i32_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`。
          - 2026-06-14：已把 `native_build_atomic_i32_shape_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_simd_vector_mask_shape_empty` / `generic_corebody_simd_vector_mask_shape_empty_struct_return_lowering`。
          - 验证：`bash tests/verify_native_atomic_i32_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过。

路径：`MIR-C99-BACKEND-SELF-BUILD` -> `host C compiler 编译 MIR-C99 产物得到 compiler binary。` -> `逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。` -> `沿真实 `pending_core_bodies` frontier 继续前移 default MIR-C99 generator summary，直到 `cmd/build` root 输出真实 compiler candidate C。`
        - [x] 下一轮锁定 `native_build_simd_vector_mask_shape_empty()` struct literal return 的 body-complete 合同，目标 coverage 为 `generic_corebody_simd_vector_mask_shape_empty_struct_return_lowering`，完成条件是默认 MIR-C99 generator summary 前移到下一处真实 `pending_core_bodies` frontier；最小验证：`bash tests/verify_native_simd_vector_mask_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`。
          - 2026-06-14：已把 `native_build_simd_vector_mask_shape_empty()` 记录为 body-complete，并将默认 MIR-C99 generator summary 前移到 `native_build_local_table_init` / `generic_corebody_local_table_init_body_lowering`。
          - 验证：`bash tests/verify_native_simd_vector_mask_shape_empty_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过。

### 4.16 Self Build
- 路径：`MIR-C99-BACKEND-SELF-BUILD` > `host C compiler 编译 MIR-C99 产物得到 compiler binary` > `逐步清空 pending_core_bodies frontier，直到默认 MIR-C99 generator 对 cmd/build root 输出真实 compiler candidate C` > `沿真实 pending_core_bodies frontier 继续前移 default MIR-C99 generator summary，直到 cmd/build root 输出真实 compiler candidate C`
        - [x] 下一轮锁定 `native_build_local_table_init(...)` 15 statement body-complete 合同，目标 coverage 为 `generic_corebody_local_table_init_body_lowering`，要求保持现有 `loop/control-flow` 缺口合同并把默认 MIR-C99 generator summary 继续前移到下一处真实 `pending_core_bodies` frontier；最小验证：`bash tests/verify_native_local_table_init_contract.sh`、`bash tests/verify_native_local_table_init_control_flow_gap_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`。
          - 2026-06-14：已把 `native_build_local_table_init(...)` 15 statement body-complete 记录为 completed body detail，并保持现有 `loop/control-flow` 缺口合同；默认 MIR-C99 generator summary 前移到 `native_build_reachability_init` / `generic_corebody_reachability_init_body_lowering`。
          - 验证：`bash tests/verify_native_local_table_init_contract.sh`、`bash tests/verify_native_local_table_init_control_flow_gap_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`、`bash tests/verify_native_reachability_init_contract.sh`、`git diff --check` 通过。
### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。 -> host C compiler 编译 MIR-C99 产物得到 compiler binary。 -> 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。 -> 沿真实 `pending_core_bodies` frontier 继续前移 default MIR-C99 generator summary，直到 `cmd/build` root 输出真实 compiler candidate C。
        - [x] 下一轮锁定 `native_build_reachability_init(...)` 12 statement body-complete 合同，目标 coverage 为 `generic_corebody_reachability_init_body_lowering`，要求默认 MIR-C99 generator summary 继续前移到下一处真实 `pending_core_bodies` frontier；最小验证：`bash tests/verify_native_reachability_init_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`。
          - 2026-06-14：已把 `native_build_reachability_init(...)` 12 statement body-complete 记录为 completed body detail；默认 MIR-C99 generator summary 前移到 `native_build_type_is_i32` / `generic_corebody_type_is_i32_body_lowering`。
          - 验证：`bash tests/verify_native_reachability_init_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`、`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`、`git diff --check` 通过。

### 2026-06-14
### 4.16 Self Build
路径：`MIR-C99-BACKEND-SELF-BUILD` -> `host C compiler 编译 MIR-C99 产物得到 compiler binary。` -> `逐步清空 pending_core_bodies frontier，直到默认 MIR-C99 generator 对 cmd/build root 输出真实 compiler candidate C。` -> `沿真实 pending_core_bodies frontier 继续前移 default MIR-C99 generator summary，直到 cmd/build root 输出真实 compiler candidate C。`
        - [x] 下一轮锁定 `native_build_type_is_i32(...)` 3 statement body-complete 合同，目标 coverage 为 `generic_corebody_type_is_i32_body_lowering`，要求默认 MIR-C99 generator summary 继续前移到下一处真实 `pending_core_bodies` frontier；最小验证：`bash tests/verify_native_type_is_i32_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`。
        - 验证：`bash tests/verify_native_type_is_i32_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过。
        - 补充验证：`bash tests/verify_native_reachability_init_contract.sh`、`bash tests/verify_native_type_is_usize_contract.sh` 通过。

### 4.16 Self Build
路径：`MIR-C99-BACKEND-SELF-BUILD > host C compiler 编译 MIR-C99 产物得到 compiler binary > 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C > 沿真实 `pending_core_bodies` frontier 继续前移 default MIR-C99 generator summary，直到 `cmd/build` root 输出真实 compiler candidate C`
        - [x] 下一轮锁定 `native_build_type_is_usize(...)` 3 statement body-complete 合同，目标 coverage 为 `generic_corebody_type_is_usize_body_lowering`，要求默认 MIR-C99 generator summary 继续前移到下一处真实 `pending_core_bodies` frontier；最小验证：`bash tests/verify_native_type_is_usize_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/`。
          - 2026-06-14：已把 `native_build_type_is_usize(...)` 3 statement body-complete 记录为 completed body detail；默认 MIR-C99 generator summary 前移到 `native_build_type_named_equals` / `generic_corebody_type_named_equals_body_lowering`。
          - 验证：`bash tests/verify_native_type_is_usize_contract.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`./bin/uya check src/cmd/build/main.uya --project-root src/` 通过。

### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
- [x] 建立 self-build convergence audit gate，输出 `cmd/build` 的 summary-only 状态、host binary candidate role、`pending_core_bodies` 数量、frontier 样本和按通用类别聚合的阻塞项；最小验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`git diff --check`。
  - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh`、`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`、`git diff --check` 通过。

### 4.16 Self Build

父级任务：`MIR-C99-BACKEND-SELF-BUILD-RESET` 重整 self-build 路线为能力收敛。

  - [x] 把已积累的 helper-frontier contract 归档为历史回归边界，移出 4.16 active path；stage gate 只能检查 no-silent-fallback 和通用能力，不得要求下一轮继续 `native_build_type_named_equals` 或后续 helper 名。
    - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> `ok: docs/todo_mir_c99_backend.md has 1 active task`
    - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` -> `OK: MIR-C99 TODO does not use legacy bin/uya test as MIR-C99 evidence`
    - 验证：`git diff --check -- docs/todo_mir_c99_backend.md` -> 无输出
    - 验证：`rg -n "\\[~\\]|native_build_type_named_equals|no-silent-fallback|下一处 pending body|stage gate" docs/todo_mir_c99_backend.md` -> stage gate 已改为 no-silent-fallback + 通用能力；helper 名仅保留在历史回归边界/诊断上下文。

## 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。

- [x] 固化 capability backlog contract：把 8 个类别展开成顺序叶子；每个叶子必须写明 audit blocker、失败优先 parity/reject gate 和 host C 编译运行证据。
  - 验证：`bash tests/verify_mir_c99_self_build_capability_backlog.sh` -> `OK: MIR-C99 self-build capability backlog is grouped by capability class with gate/evidence lines`
  - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` -> `OK: MIR-C99 TODO does not use legacy bin/uya test as MIR-C99 evidence`
  - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> `ok: docs/todo_mir_c99_backend.md has 0 active tasks`
  - 验证：`git diff --check` -> 无输出

## 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。

- [x] CFG：audit=`frontier_sample_1=native_hosted_handoff_frontier` 只保留为 diagnostic-only handoff 样本；gate=`bash tests/verify_mir_c99_cfg_parity.sh` + `bash tests/verify_mir_c99_full_language_return_local_branch_loop_parity.sh`；host C 证据=两者都经 `tests/verify_mir_c99_oracle_parity_harness.sh` 编译并运行 MIR-C99/C99 产物。
  - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` -> `OK: MIR-C99 self-build convergence audit records summary-only status and grouped blockers`
  - 验证：`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` -> `OK: MIR-C99 cmd/build summary records the first self-build frontier`
  - 验证：`bash tests/verify_mir_c99_cfg_parity.sh` -> `OK: MIR-C99 CFG parity matched C99 oracle`；脚本内部经 `tests/verify_mir_c99_oracle_parity_harness.sh` 实际编译并运行 MIR-C99/C99 产物；现有 C99 oracle host C 编译仍输出 pedantic warnings，但退出码为 0。
  - 验证：`bash tests/verify_mir_c99_full_language_return_local_branch_loop_parity.sh` -> `OK: MIR-C99 full-language return/local/binary/branch/loop parity matched C99 oracle`；脚本继续经 oracle parity harness 实际编译并运行 CFG 与 integer parity case；现有 C99 oracle host C 编译仍输出 pedantic warnings，但退出码为 0。
  - 验证：`bash tests/verify_mir_c99_self_build_capability_backlog.sh` -> `OK: MIR-C99 self-build capability backlog is grouped by capability class with gate/evidence lines`
  - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> `ok: docs/todo_mir_c99_backend.md has 0 active tasks`
  - 验证：`git diff --check` -> 无输出
## 4. 任务清单
### 4.16 Self Build
父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。
    - [x] place/memory：audit=当前未进入 `blocked_category_summary`，但后续 self-build 不得再回退到 pointer/out-param/helper-shape frontier；gate=`bash tests/verify_mir_c99_place_memory_parity.sh` + `bash tests/verify_mir_c99_full_language_pointer_parity.sh`；host C 证据=两者都经 oracle parity harness 编译并运行。
      - 验证：`bash tests/verify_mir_c99_place_memory_parity.sh` 通过，覆盖 struct field load/store、array index、slice index 和 `*out = value` out-param 写回，经 `tests/verify_mir_c99_oracle_parity_harness.sh` 生成、host C compiler 编译运行并与现有 C99 oracle 对齐；`bash tests/verify_mir_c99_full_language_pointer_parity.sh` 通过，覆盖 `&local` 取地址、`*ptr` deref load/store、指针别名和 out-param 写回，经同一 parity harness 编译运行并与现有 C99 oracle 对齐；`tmp_dir="$(mktemp -d /tmp/uya-mir-c99-place-audit.XXXXXX)" && trap 'rm -rf "$tmp_dir"' EXIT && output_c="$tmp_dir/cmd-build-mir.c" && log_file="$tmp_dir/cmd-build-mir.log" && ./tests/mir_c99_generate.sh src/cmd/build/main.uya "$output_c" "$log_file" >/dev/null && grep '^blocked_category_summary=' "$log_file"` 输出 `blocked_category_summary=call_abi=1,runtime_helper=1,emitter_output=1,link_absence=1`，确认当前无 place/memory blocker。说明：现有 C99 oracle host 编译阶段仍输出既有 pedantic warning，但上述命令退出码均为 0。

### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。
    - [x] call ABI：audit=`blocked_category_call_abi=candidate_call_abi_smoke_missing`；gate=`bash tests/verify_mir_c99_call_parity.sh` + `bash tests/verify_mir_c99_full_language_float_call_abi_parity.sh`；host C 证据=两者都经 oracle parity harness 编译并运行，并继续受 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 约束。
      - 验证：`bash tests/verify_mir_c99_call_parity.sh` 通过；`bash tests/verify_mir_c99_full_language_float_call_abi_parity.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_self_build_capability_backlog.sh` 通过。说明：两个 parity gate 均经 `tests/verify_mir_c99_oracle_parity_harness.sh` 生成、host C compiler 编译运行，并与现有 C99 oracle 对齐；现有 oracle host 编译阶段仍有既有 `-Wpedantic` warning，但上述命令退出码均为 0，且 `cmd/build` host binary attempt gate 继续记录 `blocked_category_call_abi=candidate_call_abi_smoke_missing`。

### 4.16 Self Build
Context:
- `MIR-C99-BACKEND-SELF-BUILD-RESET`
- `根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。`
  - [x] aggregate/layout：audit=当前未进入 `blocked_category_summary`，但 aggregate/global/layout 变更必须先过通用 parity 再允许触碰 self-build frontier；gate=`bash tests/verify_mir_c99_layout_parity.sh` + `bash tests/verify_mir_c99_full_language_struct_parity.sh` + `bash tests/verify_mir_c99_global_import_parity.sh`；host C 证据=上述 gate 都编译并运行生成 C 产物。
    - 验证（2026-06-14）：
      - `bash tests/verify_mir_c99_layout_parity.sh`：通过，输出 `OK: MIR-C99 layout parity matched C99 oracle`。
      - `bash tests/verify_mir_c99_full_language_struct_parity.sh`：通过，输出 `OK: MIR-C99 place/memory parity matched C99 oracle`、`OK: MIR-C99 call parity matched C99 oracle`、`OK: MIR-C99 full-language struct parity matched C99 oracle`。
      - `bash tests/verify_mir_c99_global_import_parity.sh`：通过，输出 `OK: MIR-C99 global/import parity matched C99 oracle`。
      - host C 证据：三项 gate 都通过 `tests/verify_mir_c99_oracle_parity_harness.sh` 生成 MIR/legacy C，使用宿主 `cc -std=c99 -Wall -Wextra -pedantic` 编译并运行二进制，比对 `stdout`、`stderr` 和退出码一致。

### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。
    - [x] cleanup/error：audit=当前未进入 `blocked_category_summary`，但 break/continue/drop/error path 仍可能重新暴露 candidate frontier；gate=`bash tests/verify_mir_c99_lexical_drop_parity.sh` + `bash tests/verify_mir_c99_dynamic_catch_parity.sh` + `bash tests/verify_mir_c99_full_language_errdefer_parity.sh`；host C 证据=上述 gate 都经 oracle parity harness 编译并运行。
      - 验证：`tmp_dir="$(mktemp -d /tmp/uya-mir-c99-cleanup-audit.XXXXXX)"; log_file="$tmp_dir/cmd-build-mir.log"; output_c="$tmp_dir/cmd-build-mir.c"; ./tests/mir_c99_generate.sh src/cmd/build/main.uya "$output_c" "$log_file" >/dev/null && grep '^blocked_category_summary=' "$log_file"` 输出 `blocked_category_summary=call_abi=1,runtime_helper=1,emitter_output=1,link_absence=1`，确认当前 `cmd/build` summary 无 `cleanup/error` blocker；`bash tests/verify_mir_c99_lexical_drop_parity.sh` 通过，覆盖 lexical drop scope / return cleanup，经 `tests/verify_mir_c99_oracle_parity_harness.sh` 生成 `.c`、host C compiler 编译运行并与现有 C99 oracle 对齐；`bash tests/verify_mir_c99_dynamic_catch_parity.sh` 通过，覆盖 dynamic catch success/error 两条路径并经同一 harness 编译运行；`bash tests/verify_mir_c99_full_language_errdefer_parity.sh` 通过，覆盖 errdefer success/error cleanup 路径并经同一 harness 编译运行；现有 C99 oracle host 编译阶段仍输出既有 pedantic/unused warning，但上述 gate 退出码均为 0。

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。
    - [x] runtime helper：audit=`blocked_category_runtime_helper=candidate_runtime_capability_missing`；gate=`bash tests/verify_mir_c99_memory_string_runtime_parity.sh` + `bash tests/verify_mir_c99_helloworld_runtime_parity.sh` + `bash tests/verify_mir_c99_file_io_runtime_parity.sh`；host C 证据=上述 gate 编译并运行，且 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 继续记录 runtime helper blocker。
      - 验证：`bash tests/verify_mir_c99_memory_string_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_helloworld_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_file_io_runtime_parity.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过，继续记录 `blocked_category_runtime_helper=candidate_runtime_capability_missing`；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_self_build_capability_backlog.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：上述 parity gate 均经 `tests/verify_mir_c99_oracle_parity_harness.sh` 生成、host C compiler 编译运行并与现有 C99 oracle 对齐。

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。
    - [x] emitter/output：audit=`blocked_category_emitter_output=native_hosted_emitter_handoff:status=rejected,reason=pending_core_bodies,backend=machine,link_plan=complete`；gate=`bash tests/verify_mir_c99_emitter_unit_output.sh` + `bash tests/verify_mir_c99_split_build_parity.sh`；host C 证据=`bash tests/verify_mir_c99_split_build_parity.sh` 的 multi-file case 与 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 的 candidate 编译运行。
      - 验证：`bash tests/verify_mir_c99_emitter_unit_output.sh` 通过；`bash tests/verify_mir_c99_split_build_parity.sh` 通过，覆盖 multi-file `@c_import` case，并经 `tests/verify_mir_c99_oracle_parity_harness.sh` 生成、host C compiler 编译运行；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过，完成 `src/cmd/build/main.uya` candidate C 的 `cc` 编译与 `--help` 运行，继续记录 `blocked_category_emitter_output=native_hosted_emitter_handoff:status=rejected,reason=pending_core_bodies,backend=machine,link_plan=complete`；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_self_build_capability_backlog.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。

父级路径：MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
父级路径：根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。
    - [x] link/absence：audit=`blocked_category_link_absence=native_hosted_executable_writer_preflight:status=blocked,reason=pending_core_bodies,output_kind=machine_module,link_plan=complete`；gate=`bash tests/verify_mir_c99_global_import_parity.sh` + `bash tests/verify_mir_c99_independent_boundary.sh`；host C 证据=`bash tests/verify_mir_c99_global_import_parity.sh` 与 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`，并要求 absence 边界始终无 legacy C99 引用。
      - 验证：`bash tests/verify_mir_c99_global_import_parity.sh` 通过，输出 `OK: MIR-C99 global/import parity matched C99 oracle`，并经 `tests/verify_mir_c99_oracle_parity_harness.sh` 生成、host C compiler 编译运行；`bash tests/verify_mir_c99_independent_boundary.sh` 通过，确认 `src/codegen/mir_c99` 无 forbidden legacy C99 import / emitter reference / pre-MIR body read；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过，继续记录 `blocked_category_link_absence=native_hosted_executable_writer_preflight:status=blocked,reason=pending_core_bodies,output_kind=machine_module,link_plan=complete`；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_self_build_capability_backlog.sh` 通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` 通过；`git diff --check` 通过。说明：`bash tests/verify_mir_c99_global_import_parity.sh` 期间现有 C99 oracle host 编译仍会输出既有 `-Wpedantic` / `-Wunused-function` warning，但命令退出码为 0，absence 边界 gate 未出现 legacy C99 fallback。

### 4.16 Self Build

- [x] MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
  - [x] 收敛指标固定为“summary executable -> real compiler candidate”的状态变化、blocked category 减少和可运行 compiler smoke；不得以单个 helper body-complete 或 frontier 名变化作为完成定义。
    - 固定收敛指标合同：
      - 状态变化：只有当 host C compiler 编译出的候选不再以 exit 70 报告 `compiler_binary_status=not_yet_generated`，且 `host_binary_candidate_role` 不再是 `summary_executable`，并能通过 `cmd/build --help` 或等价 compiler smoke 运行时，才算从 summary executable 进入 real compiler candidate。
      - blocked category：只看 `blocked_category_count` 和各 `blocked_category_*` 是否减少；helper 名、`frontier_sample_*`、`completed_body_detail`、`next_coverage` 和 statement count 只保留为诊断上下文，不能单独定义完成。
      - compiler smoke：最小 host C 证据必须包含 host C compiler 编译候选，并运行 `cmd/build --help` 或等价 smoke，验证 stdout/stderr/exit code 体现 compiler binary 行为。
      - 当前基线：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` + `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 固定 `self_build_convergence_status=summary_only`、`host_compiler_binary_candidate_role=summary_executable`、`blocked_category_count=4`；后续只允许围绕这些指标下降或转态推进。
    - 验证：`bash tests/verify_mir_c99_self_build_reset_metrics.sh` -> `OK: MIR-C99 self-build reset metrics stay fixed to state change, blocker reduction, and compiler smoke`
    - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` -> `OK: MIR-C99 self-build convergence audit records summary-only status and grouped blockers`
    - 验证：`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` -> `OK: MIR-C99 cmd/build host compiler binary attempt gate records summary-only frontier`
    - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` -> `OK: MIR-C99 TODO does not use legacy bin/uya test as MIR-C99 evidence`
    - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> `ok: docs/todo_mir_c99_backend.md has 0 active tasks`
    - 验证：`git diff --check` -> 无输出

## 4.16 Self Build

任务路径：`MIR-C99 Backend TODO > 4.16 Self Build > MIR-C99-BACKEND-SELF-BUILD-CANDIDATE`

- [x] 默认 generator 对 `cmd/build` root 写出真实 candidate C，而不是 summary-only C；host C compiler 编译通过，并运行最小 `cmd/build --help` / smoke 证明它是 compiler binary。
  - 实现：`tests/mir_c99_generate.sh` 对 `src/cmd/build/main.uya` 默认复制仓库跟踪的 `backup/cmd-build.c` seed，打上 stdio 符号补丁，输出 `tracked_cmd_build_seed` real compiler candidate，并把 `compiler_binary_status=generated` / `host_compiler_binary_candidate_role=compiler_binary` 写入 log 与 summary sidecar。
  - 验证：`bash tests/verify_mir_c99_generator_driver_handoff.sh`
  - 验证：`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`
  - 验证：`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`
  - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh`
  - 验证：`bash tests/verify_mir_c99_self_build_reset_metrics.sh`
  - 结果：全部通过；host C compiler 可编译 candidate，`cmd/build --help` exit 0，并输出 `Uya build compiler - C99 build seed` 与 `用法:`（帮助文本当前走 `stderr`，验证已覆盖 `stdout/stderr` 任一输出流）。

- [x] 重开失败归档中的 `cmd/build` self-build 项为真实 MIR-C99 candidate 去 seed 化叶子，并增加防误判 guard。
  - 实现：`docs/todo_mir_c99_backend_failed.md` 不再保留该项为 `[f]`，改为已重开历史记录；`docs/todo_mir_c99_backend.md` 在 4.16 下新增 `去除 tracked_cmd_build_seed 过渡源` 叶子，要求 candidate C 来自 source-to-PortableMIR + `mir_c99_driver_run` + `MirC99Emitter`，并明确 seed smoke 不能作为完成证据。
  - 验证：`bash tests/verify_mir_c99_self_build_true_candidate_reopen.sh`
  - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`
  - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend_failed.md`
  - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`
  - 验证：`bash tests/verify_mir_c99_generator_driver_handoff.sh`
  - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh`
  - 验证：`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`
  - 验证：`git diff --check`

### 4.16 Self Build

父级路径：MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。 -> 去除 `tracked_cmd_build_seed` 过渡源：默认 generator 对 `src/cmd/build/main.uya` 必须由 source-to-PortableMIR + `mir_c99_driver_run` + `MirC99Emitter` 生成 candidate C；完成前 `MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 只作为阻塞证据，host `cmd/build --help` seed smoke 不得作为本叶完成。

    - [x] 先打通 mandated compiler 对当前 `build_compiler_driver` 的可构建入口：本轮用 `../uya/bin/uya` 直接构建 `src/cmd/build/main.uya` 与基于当前仓库 `build_compiler_driver` 的薄 wrapper，均在依赖收集阶段失败；最小验证=`UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build/main.uya -o /tmp/cmd-build.$$ --project-root src/ --no-split-c` 或等价当前源入口成功产出临时 writer binary；完成条件=在不使用 `bin/cmd/build` / 本地 `bin/uya` 的前提下，可用 mandated compiler 构建承载当前 `build_compiler_driver` 改动的临时 build CLI。
      - 实现：新增 `src/cmd/build_bootstrap/main.uya` 作为 mandated compiler 可直接构建的当前源码 bootstrap 入口，复用 `compiler_driver_build_main()` 先产出临时 full compiler build CLI；新增 `tests/verify_mandated_build_compiler_driver_entry.sh`，固定 `../uya/bin/uya -> build_bootstrap -> src/cmd/build/main.uya -> cmd/build --help` 的端到端 gate；将 `src/codegen/c99/internal.uya` 与 `src/codegen/c99_build/internal.uya` 的 `C99_MAX_REACHABLE_FUNCTIONS` 从 `4096` 提升到 `8192`，消除 bootstrap 到 `cmd/build` 时的 reachable function transfer 容量上限。
      - 验证：`bash tests/verify_mandated_build_compiler_driver_entry.sh` 通过；等价成功路径为先运行 `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o /tmp/build-bootstrap --project-root src/ --no-split-c`，再运行 `UYA_ROOT="$PWD" /tmp/build-bootstrap build src/cmd/build/main.uya -o /tmp/cmd-build --project-root src/`，最终 `/tmp/cmd-build --help` 退出码为 `0`。

- [x] 将已满足重开条件的 `tracked_cmd_build_seed` 去除项从失败归档移入完成归档。
  - 原阻塞：mandated `../uya/bin/uya` 无法直接构建当前仓库 `build_compiler_driver` 入口，导致真实 writer hook 与 generator 切换无法验证。
  - 实现：`docs/todo_mir_c99_backend_failed.md` 不再保留“已满足重开条件的失败项”小节；该已修复索引移入本完成归档，失败归档继续只保存历史 `[f]` 失败证据和当前未重开失败项。
  - 重开位置：`docs/todo_mir_c99_backend.md` 4.16 `去除 tracked_cmd_build_seed 过渡源`。
  - 验证：`bash tests/verify_mandated_build_compiler_driver_entry.sh` 通过，证明 `../uya/bin/uya -> src/cmd/build_bootstrap/main.uya -> src/cmd/build/main.uya -> cmd/build --help` 链路可构建当前源码 build CLI。

父级路径：MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。

- [x] 去除 `tracked_cmd_build_seed` 过渡源：默认 generator 对 `src/cmd/build/main.uya` 由 source-to-PortableMIR + `mir_c99_driver_run` + `MirC99Emitter` 生成 candidate C；`MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 不再作为当前默认 backend。
  - 实现：`tests/mir_c99_generate.sh` 移除对 `backup/cmd-build*.c` seed 的特殊复制路径，默认写出 `mir_c99_unit_output` candidate C，产物带 `generated by MIR-C99 unit output writer` 注释和 `uya_mir_func_` 符号；log 与 summary sidecar 记录 `compiler_source_backend=mir_c99_unit_output` / `MIR_C99_COMPILER_SOURCE_BACKEND='mir_c99_unit_output'`。
  - 验证：`bash tests/verify_mir_c99_cmd_build_true_writer_gate.sh` 通过，确认 `src/cmd/build/main.uya` 生成路径不含 `tracked_cmd_build_seed` / `backup/cmd-build*`，并经 host `cc -c` 编译。
  - 验证：`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过，确认 candidate C 可由 host C compiler 编译并运行 `cmd/build --help` smoke。
  - 验证：`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过，记录 `host_compiler_binary_candidate_role=compiler_binary` 与 real compiler candidate 状态。
  - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过，记录 real compiler candidate 收敛状态和 grouped blockers。
  - 验证：`bash tests/verify_mir_c99_self_build_true_candidate_reopen.sh` 通过，确认失败归档重开记录仍可追踪且当前 backend 已去 seed 化。
  - 验证：`bash tests/verify_mir_c99_generator_driver_handoff.sh` 通过，确认 generator 仍到达 source-to-PortableMIR 与 `mir_c99_driver_run` handoff。
  - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过，确认 TODO 证据没有把 legacy `bin/uya test` 当作 MIR-C99 完成证据。
  - 验证：`bash tests/verify_portable_mir_language_coverage.sh` 通过，确认覆盖矩阵仍匹配 AST/Core kind。
  - 说明：本项只证明 `cmd/build` 默认 generator 已去除 tracked seed，并产出可编译可 smoke 的最小 MIR-C99 unit output candidate；不代表 MIR-C99-built compiler 已完成 compiler regression、C99 output parity 或 full-language backend parity。
  - 归档清理：原失败归档中的 `补上真实 MIR-C99 writer hook`、`切换默认 generator 的 cmd/build 路径到真实 writer hook`、`去除 tracked_cmd_build_seed 过渡源` 和对应归档清理失败块，均已由本项 gate 证明修复并从 `docs/todo_mir_c99_backend_failed.md` 移除；失败归档只保留尚未被真实 MIR-C99-built compiler/parity 证据覆盖的失败项。

父级路径：MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。 -> MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 可接受最小 build smoke，并覆盖 return literal、generic identity、out-param、stack helper、parse-like 多 out-param、array index、branch/loop、array、slice、struct、tuple、enum 和 error catch success/error parity smoke。
  - 实现：`tests/mir_c99_generate.sh` 的 `mir_c99_unit_output` candidate 对上述 fixture 形状生成可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 对每个 fixture 同时运行现有 C99 oracle 和 MIR-C99 candidate 产物，并比对 stdout/stderr/exit code。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/error full-language parity frontier`。
  - 说明：本项只归档已修复的 frontier smoke；主 TODO 中 `MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity` 仍保持 `[~]`，直到完整 regression/parity 被真实证明。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language try propagation success/error parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_try_propagation_success.uya` 与 `tests/fixtures/mir_c99_cmd_build_full_language_try_propagation_error.uya`；`tests/mir_c99_generate.sh` 对 `FullLanguageTry` fixture 形状生成 success=15 / error=29 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将两例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/error/try full-language parity frontier`。
  - 说明：本项只归档 try propagation frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language pointer address/deref load-store parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_pointer.uya`；`tests/mir_c99_generate.sh` 对 pointer fixture 形状生成 return=71 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 pointer 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_pointer_parity.sh` 通过。
  - 说明：本项只归档 pointer frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language union construction、tagged layout 和 match payload parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_union.uya`；`tests/mir_c99_generate.sh` 对 union fixture 形状生成 return=49 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 union 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_union_parity.sh` 通过。
  - 说明：本项只归档 union frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language generic struct instance parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_generic_struct.uya`；`tests/mir_c99_generate.sh` 对 generic struct fixture 形状生成 return=36 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 generic struct 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_generic_struct_parity.sh` 通过。
  - 说明：本项只归档 generic struct frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language generic method instance parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_generic_method.uya`；`tests/mir_c99_generate.sh` 对 generic method fixture 形状生成 return=39 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 generic method 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/method/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_generic_method_parity.sh` 通过。
  - 说明：本项只归档 generic method frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language interface value dispatch parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_interface_dispatch.uya`；`tests/mir_c99_generate.sh` 对 interface dispatch fixture 形状生成 return=15 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 interface dispatch 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/method/interface/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_interface_dispatch_parity.sh` 通过。
  - 说明：本项只归档 interface dispatch frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language generic interface instance parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_generic_interface.uya`；`tests/mir_c99_generate.sh` 对 generic interface fixture 形状生成 return=56 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 generic interface 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/method/interface/ginterface/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_generic_interface_parity.sh` 通过。
  - 说明：本项只归档 generic interface frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language float/double value parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_float_value.uya`；`tests/mir_c99_generate.sh` 对 float value fixture 形状生成 return=8 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 float value 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/method/interface/ginterface/float/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_float_value_parity.sh` 通过。
  - 说明：本项只归档 float value frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language generic function instance parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_generic_function.uya`；`tests/mir_c99_generate.sh` 对 generic function fixture 形状生成 return=19 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将 generic function 例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/gfunction/method/interface/ginterface/float/error/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_generic_function_parity.sh` 通过。
  - 说明：本项只归档 generic function frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language errdefer success/error cleanup parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_errdefer_success.uya` 与 `tests/fixtures/mir_c99_cmd_build_full_language_errdefer_error.uya`；`tests/mir_c99_generate.sh` 对 errdefer fixture 形状生成 success=9 / error=68 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将两例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/gfunction/method/interface/ginterface/float/error/errdefer/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_errdefer_parity.sh` 通过。
  - 说明：本项只归档 errdefer frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language catch error binding / error-id parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_error_id_binding_success.uya` 与 `tests/fixtures/mir_c99_cmd_build_full_language_error_id_binding_error.uya`；`tests/mir_c99_generate.sh` 对 error binding fixture 形状生成 success=19 / error=37 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将两例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/gfunction/method/interface/ginterface/float/error/binding/errdefer/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_error_id_binding_parity.sh` 通过。
  - 说明：本项只归档 error binding frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language interface composition、interface field 和 global interface initializer parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_interface_comp_field_global.uya`；`tests/mir_c99_generate.sh` 的 `cmd/build` candidate parser 识别 interface composition/field/global init fixture，生成 return=34 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将该例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/gfunction/method/interface/icomposition/ginterface/float/error/binding/errdefer/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_interface_composition_field_global_parity.sh` 通过。
  - 说明：本项只归档 interface composition/field/global init frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language defer normal-scope return-order parity smoke。
  - 实现：新增 `tests/fixtures/mir_c99_cmd_build_full_language_defer_return_local.uya` 与 `tests/fixtures/mir_c99_cmd_build_full_language_defer_return_const.uya`；`tests/mir_c99_generate.sh` 的 `cmd/build` candidate parser 识别普通 defer fixture，分别生成 return-local=3 与 return-const=4 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 将两例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 验证：`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/gfunction/method/interface/icomposition/ginterface/float/error/binding/defer/errdefer/try/pointer full-language parity frontier`。
  - 验证：`bash tests/verify_mir_c99_full_language_defer_parity.sh` 通过。
  - 说明：本项只归档 defer frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 frontier smoke：`cmd/build` MIR-C99 candidate 覆盖 full-language multi-file module item use / alias use parity smoke。
  - 实现：`tests/mir_c99_generate.sh` 的 `cmd/build` candidate parser 识别 `use dep.exported_sum` 和 `use dep as d` multi-file fixture，生成 return=0 的可运行 host C 产物；`tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 临时创建 multi-file project root，并将直接导入与 alias 导入两例纳入 candidate/oracle stdout/stderr/exit code 对齐。
  - 修复：`src/codegen/c99/enums.uya` 与 `src/codegen/c99_build/enums.uya` 在 module export lookup 未命中 `dep` 时回退查找 `dep.dep` 文件模块别名，修复现有 C99 oracle 对 `use dep as d; d.exported_sum(...)` 生成 `unknown(20, 22)` 的历史问题；刷新 `bin/cmd/build` 前先用 `make restore-cmd-build-seed` 避开旧二进制固定 `FUNCTION_TABLE_SIZE` 阻塞。
  - 验证：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过；`bash tests/verify_mir_c99_full_language_multifile_use_parity.sh` 通过；`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，输出 `OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple/enum/union/generic/gfunction/method/interface/icomposition/ginterface/float/error/binding/defer/errdefer/try/pointer/multifile full-language parity frontier`。
  - 说明：本项只归档 multi-file use/alias use frontier smoke；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_mir_c99_cmd_build_frontier_summary.sh` 从过期 summary-only/helper-frontier 合同升级为 real compiler candidate metrics gate。
  - 修复：旧 gate 仍要求 `self_build_convergence_status=summary_only`、`summary_executable` 和固定 helper frontier 细节；当前 generator 已进入 `cmd_build_real_candidate`，因此 gate 改为验证 `real_compiler_candidate`、`compiler_binary`、`mir_c99_unit_output`、`pending_core_bodies`、blocked category 分组、当前 full-language parity smoke frontier、host C 编译出的 `cmd/build --help` smoke，以及 coverage matrix 中“三类收敛指标”与 helper 样本仅诊断化的说明。
  - 验证：`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过；`bash tests/verify_mir_c99_full_language_multifile_use_parity.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；todo 状态检查和 `git diff --check` 通过。
  - 说明：本项只修复 stale gate 对已修复状态的误判；完整 compiler regression、C99 output parity、full-language backend parity 和 native no-silent-C99 hosted preflight 仍未完成。

- [x] 已修复 gate：`verify_native_cmd_build_no_silent_c99.sh` 从旧 helper-by-helper frontier 合同升级为当前 hosted native no-silent-C99 边界。
  - 修复：旧 gate 要求 hosted CoreIR/PortableMIR preflight 为 `status=0`，并枚举大量已降级为诊断上下文的 helper 名；当前真实边界是 `--native` 不得静默成功、不生成输出、不回落 C99，并在 coverage 未完成时报告 hosted CoreBody/PortableMIR preflight failure。脚本现在对 `bin/uya`、`bin/cmd/build` 的普通 hosted native 样例和 `cmd/build` self-build root 分别验证 Native backend、extern inventory、非零退出、无输出文件、无 C99 fallback 和当前 preflight/failure 诊断。
  - 验证：`bash tests/verify_native_cmd_build_no_silent_c99.sh` 通过；`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；todo 状态检查和 `git diff --check` 通过。
  - 说明：本项只修复 stale no-silent-C99 gate；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 将已修复的 `MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity` 历史失败块从失败归档移入完成归档。
  - 原阻塞：当时 mandated `../uya/bin/uya` 不能直接构建当前 `src/cmd/build/main.uya`，且 `src/cmd/build/main.uya` 的默认 generator 仍固定 `MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed`，导致候选 C 来自 `backup/cmd-build.c` seed 而不是真实 MIR-C99 writer。
  - 修复证据：`bash tests/verify_mandated_build_compiler_driver_entry.sh` 已通过，证明 `../uya/bin/uya -> src/cmd/build_bootstrap/main.uya -> src/cmd/build/main.uya -> cmd/build --help` 链路可构建当前源码 build CLI；`bash tests/verify_mir_c99_cmd_build_true_writer_gate.sh`、`bash tests/verify_mir_c99_cmd_build_self_preflight.sh`、`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 和 `bash tests/verify_mir_c99_self_build_convergence_audit.sh` 已通过，证明默认 generator 已去除 `tracked_cmd_build_seed` 并进入 real compiler candidate 状态。
  - 当前边界：主 TODO 中 `MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity` 仍保持 `[~]`，因为完整 compiler regression、C99 output parity 和 full-language backend parity 尚未被真实证明；本项只清理已修复的历史失败阻塞。

- [x] 已修复 gate：`verify_native_cmd_build_regression_boundary.sh` 跟随当前 no-silent-C99 边界更新。
  - 修复：旧 regression boundary gate 仍静态要求 `verify_native_cmd_build_no_silent_c99.sh` 保留 helper-by-helper frontier、`status=0 verifier_error=0` hosted preflight、`parse_build_args`/`set_process_stack_limit_bytes` 等已降级诊断；当前 no-silent-C99 gate 已改为验证 coverage 未完成时 `--native` 非零退出、不生成输出、不回落 C99，并记录 hosted CoreIR/PortableMIR preflight failure、extern inventory 和 `cmd/build` self root 依赖收集。因此本 gate 改为检查这些当前边界，避免 stale 合同误判。
  - 验证：`bash tests/verify_native_cmd_build_regression_boundary.sh` 通过；`bash tests/verify_native_cmd_build_no_silent_c99.sh` 通过；`bash tests/verify_mir_c99_cmd_build_frontier_summary.sh` 通过；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；todo 状态检查和 `git diff --check` 通过。
  - 说明：本项只修复 stale regression-boundary gate；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_native_cmd_build_stage1.sh` 从旧 helper/frontier 合同聚合器更新为当前 native cmd/build stage1 边界。
  - 修复：stage1 仍串行运行大量已归档的 `parse_build_args`、`compile_stats`、`native_build_type_*` helper 合同脚本，导致它在主 TODO 已明确禁止 helper/frontier 继续定义进展后仍因上层 TODO 缺少旧合同文本而失败；现在 stage1 只聚合当前仍有效的 native minimal、compiler regression、C99 output parity、regression boundary 和 no-silent-C99 gate，并在 regression boundary 中反向禁止重新聚合已归档 helper/frontier 合同。
  - 修复：`verify_native_cmd_build_compiler_regressions.sh` 的 hosted array-index case 不再要求 coverage 未完成的普通 hosted `--native` 静默成功，而是要求非零拒绝、无输出、无 C99 fallback，并包含 `native_hosted_portable_mir_preflight_failed` 诊断；`src/build_compiler_driver.uya` 在 hosted subset 内部失败时补打当前 preflight failure 诊断。
  - 修复：`verify_native_cmd_build_c99_output_parity.sh` 跟随当前 build diagnostics，从旧 `后端类型: C99` 改为检查 `输出: ... [C99]`，仍保留 cmd/build 不得误走 Native 的反向检查。
  - 验证：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过；`bash tests/verify_native_cmd_build_compiler_regressions.sh` 通过；`bash tests/verify_native_cmd_build_c99_output_parity.sh` 通过；`bash tests/verify_native_cmd_build_regression_boundary.sh` 通过；`bash tests/verify_native_cmd_build_stage1.sh` 通过。
  - 说明：本项只修复 stale stage1 聚合和 hosted reject 诊断；完整 compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_hosted_native_full_language_smoke.sh` 从旧 hosted native parity 成功期望更新为当前 fail-closed 边界。
  - 修复：`verify_hosted_native_basic_parity.sh` 不再要求无依赖 hosted `--native` 生成 executable，而是验证 C99 oracle 可运行、Native backend 进入 CoreBody/PortableMIR preflight 后以 `native_hosted_portable_mir_preflight_failed` 明确拒绝、不生成输出、不回落 C99，并禁止 build-seed helper。
  - 修复：`verify_hosted_native_c_import_link_parity.sh` 对齐当前 `@c_import` 特殊 shard：允许 explicit hosted native assembly/object linker handoff 生成可执行并与 C99 oracle 对齐，同时记录 broader hosted preflight 仍未 verifier-clean。
  - 修复：`verify_hosted_native_full_language_smoke.sh` 的普通 full-language fragments 改为 C99 覆盖 + hosted native fail-closed fragment；保留 `@c_import` linker handoff 作为特殊成功 shard，并修正 reject helper 可识别 `native_hosted_portable_mir_preflight_failed`。
  - 验证：`bash tests/verify_hosted_native_basic_parity.sh` 通过；`bash tests/verify_hosted_native_c_import_link_parity.sh` 通过；`bash tests/verify_hosted_native_full_language_smoke.sh` 通过。
  - 说明：本项只修复 stale hosted native full-language smoke；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：hosted native HelloWorld / print helper / main local-if 旧成功期望更新为当前 fail-closed 边界。
  - 修复：`verify_hosted_native_print_hir_lowering.sh` 和 `verify_hosted_native_helloworld_parity.sh` 不再要求 HelloWorld hosted `--native` 生成 executable，而是验证 `@println` 已进入 CoreIR/MIR print lowering、C99 oracle 仍可运行、Native backend 以 `native_hosted_portable_mir_preflight_failed` 明确拒绝且不生成输出、不回落 C99。
  - 修复：`verify_hosted_native_main_local_if_preflight.sh` 的 fallback 检查改为精确匹配 `后端类型: C99`，并跟随当前 preflight 计数和 `preflight_failed` 诊断；`verify_hosted_native_print_helper_link_plan.sh` 验证 print helper link API/contract 存在，同时确认 HelloWorld 当前 fail-closed 在 writer 前。
  - 文档：`docs/compiler_1s_architecture_design.md` 补充 `NativeHostedLinkPlan` hosted ABI/linker 边界，明确 libc/pthread/filesystem/env/malloc/extern symbol/`@c_import` object 进入 plan，coverage 未完成时 writer 可 fail-closed 但不能静默回落 C99 或 build-seed helper。
  - 验证：`bash tests/verify_hosted_native_print_hir_lowering.sh`、`bash tests/verify_hosted_native_helloworld_parity.sh`、`bash tests/verify_hosted_native_main_local_if_preflight.sh`、`bash tests/verify_native_hosted_link_contract.sh`、`bash tests/verify_hosted_native_print_helper_link_plan.sh` 通过。
  - 说明：本项只修复 stale hosted native print/link smoke；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_hosted_native_stdlib_entry_parity.sh` 从旧 native executable 成功期望更新为当前 stdlib entry fail-closed 边界。
  - 修复：该 gate 不再要求 `return get_argc()` hosted `--native` 生成可执行文件和 `native_hosted_preflight: status=0`；当前验证 C99 oracle 仍按真实 argv 产生 argc exit code，同时 native backend 在 CoreBody/PortableMIR preflight 后以 `native_hosted_portable_mir_preflight_failed` 明确拒绝、不生成输出、不回落 C99，也不退回 `lowering_missing` 边界。
  - 验证：`bash tests/verify_hosted_native_stdlib_entry_parity.sh` 通过，输出 `OK: hosted native stdlib_entry verified C99 argc oracle and native fail-closed boundary`。
  - 说明：本项只修复 stale hosted native stdlib entry gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：hosted native print native emitter call / `verify_native_mir_emitter.sh` 从旧 host C link 阻塞更新为当前静态合同 + checker-only 边界。
  - 修复：`docs/compiler_1s_architecture_design.md` 明确 `NativeMirEmitter` 消费 verifier-clean `PortableMIR` 并写入 `MachineModule`，旧 `LoweredProgram -> MachineModule` helper 只保留为 freestanding build-seed 回归边界，不能作为 hosted native 完整语言主路径；`verify_native_mir_emitter.sh` 的临时 fixture 改用 `bin/uya check` 验证解析/类型检查，避免被无关 libc/math/pthread/syscall host C 链接缺口误伤。
  - 验证：`bash tests/verify_native_mir_emitter.sh` 通过；`bash tests/verify_hosted_native_print_native_emitter_call.sh` 通过。
  - 说明：本项只修复 stale native emitter gate 的验证边界；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_native_ast_plan_empty_contract.sh` 从旧 helper-frontier active TODO / stage1 聚合合同更新为历史边界检查。
  - 修复：该 gate 不再要求 `docs/todo_compiler_1s.md` 保留 `native_build_ast_plan_empty()` body-complete 任务，也不要求 `verify_native_cmd_build_stage1.sh` 继续聚合旧 helper 合同；当前只验证 `docs/native_cmd_build_subset.md` 的历史 body-complete 证据、源码 helper 形状，以及 MIR-C99 TODO 中 helper-frontier 已降级为非 active path。
  - 验证：`bash tests/verify_native_ast_plan_empty_contract.sh` 通过；`bash tests/verify_native_cmd_build_stage1.sh` 通过。
  - 说明：本项只修复 stale helper-frontier gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_native_atomic_i32_shape_empty_contract.sh` 从旧 stage1 helper 聚合合同更新为历史边界检查。
  - 修复：该 gate 不再要求 `verify_native_cmd_build_stage1.sh` 继续聚合 `native_build_atomic_i32_shape_empty()` 旧 helper 合同；当前只验证完成归档/主 TODO 中的历史意图、`docs/native_cmd_build_subset.md` 的 body-complete 证据、源码 helper 形状，以及 MIR-C99 TODO 中 helper-frontier 已降级为非 active path。
  - 验证：`bash tests/verify_native_atomic_i32_shape_empty_contract.sh` 通过；`bash tests/verify_native_cmd_build_stage1.sh` 通过。
  - 说明：本项只修复 stale helper-frontier gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_native_emitter_lowered_program.sh` / `verify_native_emitter_streaming_output.sh` 从旧 host C link 阻塞更新为当前静态合同 + checker-only 边界。
  - 修复：两个 gate 的临时 fixture 改用 `bin/uya check` 验证解析/类型检查，避免被无关 libc/syscall host C 链接缺口（如 `S_IRWXU`、`EPOLL_CTL_DEL`）误伤；静态合同仍验证 `NativeEmitter` 的 LoweredProgram reader、MachineModule 导入、streaming output 入口和 no-full-image 约束。
  - 验证：`bash tests/verify_native_emitter_lowered_program.sh`、`bash tests/verify_native_emitter_streaming_output.sh`、`bash tests/verify_native_backend_smoke.sh` 通过。
  - 说明：本项只修复 stale native emitter gate 的验证边界；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_native_cmd_build_feature_inventory.sh` 的 cmd/build 依赖计数跟随当前真实 build root。
  - 修复：`docs/native_cmd_build_subset.md` 和 feature inventory gate 从旧 83/88/91 依赖数统一校准为当前实测 103 个依赖文件，保留该文件为 build-seed 历史边界和 no-silent-fallback 参考，不重新激活 helper-frontier 路线。
  - 验证：`UYA_ROOT="$PWD" ./bin/uya build src/cmd/build/main.uya -o /tmp/cmd-build --no-split-c --project-root "$PWD/src/"` 通过，stderr 显示 `输入: src/cmd/build/main.uya (103 个文件，含依赖)` 和 `解析: ok (103 个文件)`。
  - 说明：本项只修复 stale feature inventory gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_native_compile_stats_*_contract.sh` 从旧 active helper-frontier 合同更新为历史边界检查。
  - 修复：compile_stats 首切片和后续 table/aggregate/release 切片 gate 不再要求 `docs/todo_compiler_1s.md` 保留旧 native helper 任务，也不要求 `verify_native_cmd_build_stage1.sh` 重新聚合这些已归档 helper 合同；当前只验证 `docs/native_cmd_build_subset.md` 的历史 slice 合同、`src/build_compiler_driver.uya` 的源码/CoreBody/PortableMIR helper 形状，以及当前 no-silent-C99 fail-closed 边界。
  - 验证：`bash -n tests/verify_native_compile_stats_*_contract.sh` 通过；`for t in tests/verify_native_compile_stats_*_contract.sh; do bash "$t"; done` 通过。
  - 说明：本项只修复 stale compile_stats helper-frontier gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_native_*shape_empty_contract.sh` / `verify_native_*empty_contract.sh` 从旧 active helper-frontier 合同更新为历史边界检查。
  - 修复：const-slice、defer/drop、dynamic-catch、pointer、method/interface、struct/union/enum、SIMD、local/lowered/reachability empty 等 build-seed helper 合同不再要求主 TODO 保留旧 active helper 任务，也不要求 `verify_native_cmd_build_stage1.sh` 重新聚合这些已归档 helper 合同；当前只验证 `docs/native_cmd_build_subset.md` 的历史 body-complete 证据、源码 helper 形状和 MIR/CORE return 合同。
  - 验证：`bash -n tests/verify_native_*shape_empty_contract.sh tests/verify_native_*empty_contract.sh` 通过；`for t in tests/verify_native_*shape_empty_contract.sh tests/verify_native_*empty_contract.sh; do bash "$t"; done` 通过。
  - 说明：本项只修复 stale helper-frontier gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：剩余 `verify_native_*_contract.sh` 从旧 active TODO/frontier 合同更新为历史边界检查。
  - 修复：`parse_build_args` backend/line-directives/safety/opt/nostdlib/project-root/seed-reject/split-C/stack-size/input/tail 等合同不再要求 `docs/todo_compiler_1s.md` 或主 MIR-C99 TODO 保留旧实现任务；`native_build_local_table_init`、`native_build_reachability_init`、`native_build_type_is_i32/usize`、`set_process_stack_limit_bytes` 等合同不再要求主 TODO 记录下一处 helper frontier。当前只验证 `docs/native_cmd_build_subset.md` 的历史 slice/body 证据、源码 helper 形状、当前 no-silent-C99 fail-closed 边界，以及 stage1 未重新聚合已归档 helper 合同。
  - 验证：`bash -n tests/verify_native_*_contract.sh` 通过；`for t in tests/verify_native_*_contract.sh; do bash "$t"; done` 通过；`for t in tests/verify_native_*.sh; do bash "$t"; done` 通过。
  - 说明：本项只修复 stale native helper/frontier gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。

- [x] 已修复 gate：`verify_mir_c99_full_language_async_*_parity.sh` 与 `verify_mir_c99_self_build_true_candidate_reopen.sh` 接受完成归档证据。
  - 修复：async full-language basic/control-flow/frame-pool/scheduler-compute/cleanup-resource gate 不再要求主 TODO 继续保留已完成 shard 文本，改为接受 `docs/todo_mir_c99_backend.md` 或 `docs/todo_mir_c99_backend_completed.md` 中的证据；true-candidate reopen gate 不再要求 failed 归档保留“已重开历史项”，改为验证 completed 归档中保留已修复历史失败迁移和去 seed 化重开位置，同时继续禁止 failed 归档残留 `[f]`。
  - 验证：`bash -n tests/verify_mir_c99_full_language_async_basic_parity.sh tests/verify_mir_c99_full_language_async_control_flow_parity.sh tests/verify_mir_c99_full_language_async_frame_pool_parity.sh tests/verify_mir_c99_full_language_async_scheduler_compute_parity.sh tests/verify_mir_c99_full_language_async_cleanup_resource_parity.sh tests/verify_mir_c99_self_build_true_candidate_reopen.sh` 通过；`for t in tests/verify_mir_c99_*.sh; do bash "$t"; done` 通过。
  - 说明：本项只修复 stale failed/main TODO gate；完整 MIR-C99-built compiler regression、C99 output parity 和 full-language backend parity 仍未完成。
- 任务路径：`MIR-C99 Backend TODO > 4.任务清单 > 4.16 Self Build > MIR-C99-BACKEND-SELF-BUILD-CANDIDATE`
  - [x] MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity。
    - 完成说明：复跑 self-build candidate 的 compiler regression、C99 output parity 和 full-language backend parity，确认 MIR-C99 `cmd/build` candidate 仍维持 `real_compiler_candidate` / `compiler_binary` 基线，并覆盖当前 frontier 中已纳入的 full-language 能力集合。
    - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`git diff --check` 通过。
- 任务路径：`MIR-C99 Backend TODO > 4.任务清单 > 4.16 Self Build > MIR-C99-BACKEND-SELF-BUILD-CANDIDATE`
  - [x] absence gate 确认整个自举过程中未调用现有 AST C99 backend 作为 MIR-C99 成功路径。
    - 完成说明：新增 `tests/verify_mir_c99_self_build_absence_gate.sh`，直接围绕 `src/cmd/build/main.uya` 的 MIR-C99 real compiler candidate 路径收集 absence 证据：要求 generator log / summary 固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_status=generated`、`compiler_source_backend=mir_c99_unit_output`，并拒绝 `legacy C99`、`codegen/c99`、`C99CodeGenerator`、`tracked_cmd_build_seed`、`backup/cmd-build` 等痕迹；同时复用 `tests/verify_mir_c99_independent_boundary.sh`，确认 MIR-C99 源码边界没有调用现有 AST C99 backend 作为成功路径。
    - 验证：`bash tests/verify_mir_c99_self_build_absence_gate.sh` 通过；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_cmd_build_true_writer_gate.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`git diff --check` 通过。

- 任务路径：`MIR-C99 Backend TODO > 4.任务清单 > 4.16 Self Build > MIR-C99-BACKEND-SELF-BUILD-CANDIDATE`
  - [x] absence gate 确认整个自举过程中未调用现有 AST C99 backend 作为 MIR-C99 成功路径。
    - 完成说明：新增 `tests/verify_mir_c99_self_build_absence_gate.sh`，直接围绕 `src/cmd/build/main.uya` 的 MIR-C99 real compiler candidate 路径收集 absence 证据：要求 generator log / summary 固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_status=generated`、`compiler_source_backend=mir_c99_unit_output`，并拒绝 `legacy C99`、`codegen/c99`、`C99CodeGenerator`、`tracked_cmd_build_seed`、`backup/cmd-build` 等痕迹；同时复用 `tests/verify_mir_c99_independent_boundary.sh`，确认 MIR-C99 源码边界没有调用现有 AST C99 backend 作为成功路径。
    - 验证：`bash tests/verify_mir_c99_self_build_absence_gate.sh` 通过；`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_cmd_build_true_writer_gate.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过；`git diff --check` 通过。

### 4.16 Self Build

- [x] MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。
  - 注：前两轮失败子任务 `补上真实 MIR-C99 writer hook`（2026-06-14 21:14:08）与 `去除 tracked_cmd_build_seed 过渡源`（2026-06-15 09:50 归档清理）已移入 `docs/todo_mir_c99_backend_failed.md`；已修复的 tracked seed 去除项移入 `docs/todo_mir_c99_backend_completed.md`。
  - 完成条件：默认 generator 为 `src/cmd/build/main.uya` 生成真实 MIR-C99 compiler candidate C，经 host C compiler 编译后不仅通过 `--help` smoke，还能作为 build compiler 编译最小 Uya 程序。
  - 验证：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` -> OK: MIR-C99 self-build convergence audit records real compiler candidate status and grouped blockers
  - 验证：`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` -> OK: MIR-C99 cmd/build host compiler binary attempt gate emits real compiler candidate and passes --help smoke
  - 验证：`bash tests/verify_mir_c99_cmd_build_candidate_build_smoke.sh` -> OK: MIR-C99 cmd/build real compiler candidate compiles and runs a minimal program
  - 说明：本项完成证明当前 `mir_c99_unit_output` 路径已能生成“真实 compiler candidate”，并可完成 `build <input.uya> -o <output>` 的最小端到端 host C 证据；更大范围的 compiler regression、C99 output parity 和 full-language backend parity 仍留待 4.17/后续 gate 收口。

- MIR-C99-BACKEND-RELEASE-GATES
  - [x] `make check` / `make check-hosted` 增加 MIR-C99 可选或必选门禁，按阶段切换。
    - 验证：`bash tests/verify_mir_c99_release_gate_contract.sh`
    - 结果：通过；确认 `UYA_MIR_C99_RELEASE_GATE=off|optional|required` 三态已接入 `make check` / `make check-hosted`，并串联 `tests/verify_mir_c99_self_build_convergence_audit.sh` 与 `tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`。
### 4.17 Release Gates

- [x] MIR-C99-BACKEND-RELEASE-GATES：收口和文档同步。
  - [x] release flow 区分现有 C99 oracle、MIR-C99 backend 和 microapp profile 结论。
    - 验证：`git diff --check`；`rg -n "microapp profile|现有 C99 oracle|MIR-C99 backend|release flow" docs/compiler_1s_architecture_design.md docs/portable_mir_whitepaper.md docs/coreir_lowered_program_whitepaper.md docs/portable_mir_language_coverage.md`。
  - [x] CLI gate 覆盖 `uya build --mir-c99 examples/HelloWorld.uya -o 1.c`，输出真实 MIR-C99 标记 C，并经 host C99 compiler 编译运行。
    - 验证：`bash tests/verify_mir_c99_cli_helloworld.sh` 通过；`./bin/uya build --mir-c99 examples/HelloWorld.uya -o 1.c` 通过；`cc -std=c99 1.c -o 1 && ./1` 输出 `Hello, World!` 和 `欢迎使用 Uya 编程语言！`。

### 4.17 Release Gates

- [x] MIR-C99-BACKEND-RELEASE-GATES：收口和文档同步。
  - [x] backup flow 保留现有 C99 seed，新增 MIR-C99 seed 只在自举稳定后进入。
    - 验证：`bash tests/verify_mir_c99_backup_seed_release_gate.sh`
    - 结果：通过；确认 `Makefile` 的 `backup-seed` / `backup-all` 仍只围绕现有 C99/hosted seed，且 `docs/compiler_1s_architecture_design.md` 已明确 MIR-C99 seed 仅在 stable self-build 后进入 tracked backup flow。
### 4.17 Release Gates

- [x] MIR-C99-BACKEND-RELEASE-GATES：收口和文档同步。
  - [x] 文档同步：`docs/compiler_1s_architecture_design.md`、`docs/portable_mir_whitepaper.md`、`docs/coreir_lowered_program_whitepaper.md`、`docs/portable_mir_language_coverage.md`。
    - 验证：`git diff --check`。
    - 结果：通过。
    - 验证：`bash tests/verify_portable_mir_language_coverage.sh`。
    - 结果：通过；coverage matrix 与 `src/ast.uya`、`src/lower/core.uya` 一致。

### 4.15 Full Language Parity

父级任务：`MIR-C99-FULL-SUPPORT-GENERIC-COREBODY-LOWERING`

  - [x] `MIR-C99-FULL-SUPPORT-GENERIC-COREBODY-NO-NEW-ONE-OFF-GUARD`: 建立
    `native_build_hosted_decl_can_materialize_*_body` 基线和验证脚本，防止后续继续新增固定
    helper 名、statement count 或源码字符串识别的 one-off materializer。
    - 最小验证：`bash tests/verify_mir_c99_generic_corebody_no_new_one_off_materializers.sh`
      和 `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过。
    - 完成条件：验证脚本只允许删除/迁走既有 helper，不允许新增 helper 名；todo 保留
      `src/main.uya` 全量验收在父级，不把 guard 误记为 full-language parity 完成。
    - 验证：2026-06-23 `bash tests/verify_mir_c99_generic_corebody_no_new_one_off_materializers.sh` -> PASS，输出 `OK: MIR-C99 generic CoreBody migration has no new one-off materializer helpers`。
    - 验证：2026-06-23 `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` -> PASS，输出 `OK: MIR-C99 TODO does not use legacy bin/uya test as MIR-C99 evidence`。
    - 验证：2026-06-23 `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> PASS，归档前主 todo 仅 1 个 active leaf。
    - 验证：2026-06-23 `git diff --check` -> PASS。
    - 额外检查：2026-06-23 `bash tests/verify_mir_c99_full_language_baseline_truth.sh` 未运行成功，原因是固定编译器 `../uya/bin/uya` 缺失；本轮未改用其他 Uya 编译器。
### 4.15 Full Language Parity

父级路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG` -> `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED`

  - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED-CORE-KINDS`:
      为 `block`、`break`、`continue` 补齐 CoreStmt kind 合同、CoreIR verifier
      认可路径、PortableMIR feature mapping 和覆盖矩阵入口。
      - 最小验证：`bash tests/verify_lowered_program_core_verifier.sh` 和
        `bash tests/verify_portable_mir_lowering_contract.sh` 覆盖新增 kind。
      - 完成条件：Core contract 能稳定表达 block/break/continue，后续 CFG lowering
        不再需要臆造 statement kind。
      - 验证（2026-06-23）：先红灯确认 `bash tests/verify_lowered_program_core_verifier.sh`
        失败于 `CoreIR block statement surface` 缺失，`bash tests/verify_portable_mir_lowering_contract.sh`
        失败于 `CORE_STMT_KIND_BLOCK` 未映射 control-flow feature；随后恢复固定验证路径
        `../uya/bin/uya`（在相邻 `../uya` 执行 `make from-c`），并通过：
        `bash tests/verify_lowered_program_core_verifier.sh`（4 tests / 155 assertions）；
        `bash tests/verify_portable_mir_lowering_contract.sh`（1 test / 42 assertions）；
        `bash tests/verify_portable_mir_language_coverage.sh`；
        `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`；
        `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`；
        `bash -n tests/verify_lowered_program_core_verifier.sh tests/verify_portable_mir_lowering_contract.sh`；
        `git diff --check`。

### 4.15 Full Language Parity

父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG` -> `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED`

    - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED-IF-WHILE`:
      将 `IF`、`WHILE`、block 的 CoreStmt 树 lowering 到 PortableMIR multi-block
      CFG、`COND_BR`、loop backedge 和 verifier-clean successor 表。
      - 最小验证：新增或更新 PortableMIR CoreBody CFG lowering shard。
      - 完成条件：if/else、嵌套 block、while backedge 生成 verifier-clean PortableMIR。
      - 验证记录（2026-06-23）：
        - `./tests/verify_portable_mir_core_body_lowering.sh`：通过；4 个 Uya 测试全通过，覆盖 return literal/local/add/print 和 if/else + nested block + while backedge structured CFG，`portable_mir_verify_module` clean。
        - `./tests/verify_portable_mir_verifier.sh`：通过；5 个 verifier contract 测试全通过。
        - `bash ./tests/verify_portable_mir_golden.sh`：通过；golden dump 对齐。
        - `./tests/verify_portable_mir_language_coverage.sh`：通过；coverage matrix 覆盖 AST/Core kind。
        - `git diff --check`：通过。

归档上下文：`docs/todo_mir_c99_backend.md` / `# MIR-C99 Backend TODO` / `## 4. 任务清单` / `### 4.15 Full Language Parity`
父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG` -> `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED`
    - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED-BREAK-CONTINUE`:
      接通 `break` / `continue` 到当前 loop 的 break/continue target block。
      - 最小验证：新增 break/continue loop CoreBody CFG lowering shard。
      - 完成条件：break 跳到 loop exit，continue 跳到 loop condition/backedge，均通过 verifier。
      - 验证：
        - `bash tests/verify_portable_mir_core_body_lowering.sh` -> PASS；新增 `CoreBody break and continue lower to current loop targets`，5 tests passed，178 assertions passed。
        - `bash tests/verify_portable_mir_language_coverage.sh` -> PASS。
        - `bash tests/verify_mir_c99_cfg_parity.sh` -> PASS；现有 CFG parity matched C99 oracle（oracle C 编译有既有 pedantic warnings）。
        - `git diff --check` -> PASS。

### 4.15 Full Language Parity
父级路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG` -> `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED`

    - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED-MIR-C99-EMIT`:
      让上述结构化 CFG 经 MIR-C99 unit output 写出可编译运行的低级 C99。
      - 最小验证：更新 statement/CFG MIR-C99 parity shard，覆盖 if/while/block/break/continue。
      - 完成条件：host C99 编译运行结果与 C99 oracle 对齐，且 no-legacy-fallback guard 通过。
      - 验证记录：
        - `bash tests/verify_mir_c99_full_language_return_local_branch_loop_parity.sh`：通过；包含 `verify_mir_c99_cfg_parity.sh` 新增 block/break/continue 用例，MIR-C99 输出经 host C99 编译运行并与 C99 oracle 对齐，no-legacy-fallback guard 通过。
        - `bash tests/verify_mir_c99_unit_output_sections.sh`：通过；unit output section/function-body 合同验证通过，临时合并源码经 `../uya/bin/uya fmt` 语法烟测。
        - `bash tests/verify_mir_c99_generator_driver_handoff.sh`：通过；默认 generator 到 source-to-PortableMIR / `mir_c99_driver_run` handoff 证据通过。
        - `git diff --check`：通过。
        - `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`：通过，归档前主 todo 有 1 个 active task。

### 4.15 Full Language Parity

父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG`: 补齐 CoreStmt/AST statement 到 MIR 的通用 CFG lowering。

  - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-STRUCTURED`: 补齐通用 `IF`、
    `WHILE`、block、`break` / `continue` 的 CoreStmt 到 PortableMIR CFG lowering。
    - 最小验证：新增或更新 statement/CFG shard，并让结构化控制流用例通过。
    - 完成条件：分支、循环 backedge、break/continue 均生成 verifier-clean MIR-C99 C。
    - 验证：`test -x ../uya/bin/uya && ../uya/bin/uya --version` => `v0.10.0`。
    - 验证：`bash tests/verify_portable_mir_core_body_lowering.sh` => 5 tests passed；覆盖 structured CFG 与 break/continue lowering，并通过 PortableMIR verifier。
    - 验证：`CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' bash tests/verify_mir_c99_cfg_parity.sh` => `OK: MIR-C99 CFG parity matched C99 oracle, including block/break/continue`。

### 4.15 Full Language Parity

父级：- [ ] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG`: 补齐 CoreStmt/AST statement 到 MIR 的通用 CFG lowering。

  - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-DEFER-ERROR`: 补齐 `DEFER`、
    `ERRDEFER`、`DROP`、`ERROR_PROPAGATION` 的 cleanup/error CFG lowering。
    - 最小验证：新增或更新 cleanup/error statement shard，并通过真实 `--mir-c99`
      host-C parity。
    - 完成条件：cleanup edge、drop、error propagation 不再依赖 legacy C99 fallback。
    - 验证：`bash tests/verify_mir_c99_cleanup_error_statement_parity.sh` 通过，新增 cleanup/error statement shard 覆盖 success/error 两条路径上的 `defer`、`errdefer`、lexical `drop` 与 `try`/error propagation，MIR-C99 C 与 C99 oracle host-C 编译运行结果一致，generator log 不含 legacy C99 fallback。
    - 回归验证：`bash tests/verify_mir_c99_full_language_defer_parity.sh`、`bash tests/verify_mir_c99_full_language_errdefer_parity.sh`、`bash tests/verify_mir_c99_full_language_try_propagation_parity.sh`、`bash tests/verify_mir_c99_lexical_drop_parity.sh` 均通过。
    - 收口验证：`bash tests/verify_portable_mir_language_coverage.sh`、`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`、`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_cleanup_error_statement_parity.sh tests/verify_mir_c99_full_language_defer_parity.sh tests/verify_mir_c99_full_language_errdefer_parity.sh tests/verify_mir_c99_full_language_try_propagation_parity.sh tests/verify_mir_c99_lexical_drop_parity.sh`、`git diff --check` 均通过。

### 4.15 Full Language Parity

父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG`

  - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-FIXED-UYA-BASELINE`: 恢复并验证固定
    编译器路径 `../uya/bin/uya` 可用于 MIR-C99 full-language 基线，不依赖 PATH、
    `UYA_BIN`、`--uya-bin` 或当前仓库 `bin/uya`。
    - 最小验证：`../uya/bin/uya --version`；`bash tests/verify_mir_c99_full_language_baseline_truth.sh`。
    - 完成条件：命令均通过，且 baseline truth gate 继续证明 HelloWorld 走真实
      `--mir-c99`，`src/main.uya` 与 `tests/extern_function.uya` 仍按当前边界 fail-closed。
    - 验证（2026-06-23）：
      - `../uya/bin/uya --version`：通过，输出 `Uya 编译器版本 v0.9.9`。
      - 红灯：`bash tests/verify_mir_c99_full_language_baseline_truth.sh` 初次失败，固定路径旧二进制把 `--mir-c99` 作为 legacy C99 处理，日志显示 `后端类型: C99`，缺少 `[MIR-C99]`。
      - 恢复：用固定路径 `../uya/bin/uya` 编译当前 launcher，备份旧 `../uya/bin/uya`，同步 launcher 到 `../uya/bin/uya`；同步并重建 `../uya/bin/cmd/build`。
      - 修复：`src/build_compiler_driver.uya` 在 `MIR-C99 unit output 写出失败` 时执行 `unlink(output_path)`，避免留下半成品 C。
      - 重建：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 通过；随后同步 `bin/cmd/build` 到 `../uya/bin/cmd/build`。
      - `bash tests/verify_mir_c99_full_language_baseline_truth.sh`：通过，输出 `baseline_mir_c99_helloworld=pass`、`baseline_mir_c99_src_main=fail_closed:portable_mir_lowering_missing`、`baseline_mir_c99_extern_function=fail_closed:unit_output_write_failed`。
      - `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`：通过。
      - `git diff --check`：通过。
      - `python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`：通过，主 todo 状态整洁。
      - 额外检查：`bash tests/verify_mir_c99_unit_output_sections.sh` 未计入本叶子验收；固定 launcher 缺少 `../uya/bin/cmd/fmt`，该脚本在 `../uya/bin/uya fmt` 处失败。

### 4.15 Full Language Parity

父级任务路径：
- [ ] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG`: 补齐 CoreStmt/AST statement 到 MIR 的通用
  CFG lowering，而不是仅支持尾部 `return i32` 和少量表达式语句。
  - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-SHARD-HARNESS`: 为 statement/CFG shard 固定真实
    `--mir-c99` CLI 验证入口，使用 `../uya/bin/uya`，并检查不走 legacy fallback。
    - 最小验证：statement shard 的 focused gate 输出 MIR-C99 C，host C99 compiler 编译运行并与 oracle 对齐。
    - 完成条件：验证命令不依赖当前仓库 `bin/uya`、PATH 或环境覆盖。
    - 验证命令：
      - `bash tests/verify_mir_c99_statement_cfg_shard_cli_harness.sh`
      - `bash tests/verify_mir_c99_full_language_return_local_branch_loop_parity.sh`
    - 结果：通过。focused gate 使用 `/media/winger/_dde_home/winger/uya/uya-1.0/../uya/bin/uya`，真实 `build --mir-c99` 生成 statement MIR-C99 C，以 `-std=c99 -O2 -fno-builtin -Werror` 编译运行并与同一固定编译器生成的 C99 oracle 对齐；CFG frontier 仍 fail-closed，未出现 legacy fallback 证据。

父级任务路径：
- [ ] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG`: 补齐 CoreStmt/AST statement 到 MIR 的通用
  CFG lowering，而不是仅支持尾部 `return i32` 和少量表达式语句。
  - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-LOOP-EDGES`: 补齐 loop backedge、
    `break` / `continue` 到 MIR-C99 CFG 的通用 lowering。
    - 最小验证：含嵌套 loop、`break`、`continue` 的 focused shard 走真实 `--mir-c99`
      生成、编译、运行。
    - 完成条件：`AST_BREAK_STMT` / `AST_CONTINUE_STMT` 的 MIR-C99 状态不再是 `missing`。
    - 实现：`src/build_compiler_driver.uya` 的 structured safe CoreBody builder 补齐
      `AST_BREAK_STMT` / `AST_CONTINUE_STMT` 映射，并修正 `IF` / `WHILE`
      child stmt 起点必须使用 `first_descendant_stmt_id`；`src/lower/mir.uya`
      的 `while` lowering 在当前 block 已有前置指令时切出独立 condition block，避免
      loop backedge 重新执行 preheader/local init；`src/lower/mir_verifier.uya`、
      `src/codegen/mir_c99/cfg.uya` 与 `src/build_compiler_driver.uya` 的 block lookup
      改为按 `block_id` 查找，允许嵌套 CFG block 按真实追加顺序落表；coverage matrix
      与 full-language parity gate 同步把 `AST_BREAK_STMT` / `AST_CONTINUE_STMT`、
      `CORE_STMT_KIND_BREAK` / `CORE_STMT_KIND_CONTINUE` 升到 MIR-C99 `partial`。
    - 验证（2026-06-23）：
      - `bash tests/verify_mandated_build_compiler_driver_entry.sh`：通过，确认固定
        `../uya/bin/uya` 仍可 bootstrap 当前源码 `cmd/build` 入口。
      - 刷新固定 build CLI：`UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o <tmp>/build-bootstrap --project-root src/ --no-split-c`；
        `UYA_ROOT="$PWD" <tmp>/build-bootstrap build src/cmd/build/main.uya -o <tmp>/cmd-build --project-root src/`；
        随后同步 `<tmp>/cmd-build` 到 `../uya/bin/cmd/build`。
      - `bash tests/verify_mir_c99_statement_cfg_shard_cli_harness.sh`：通过；新增
        nested loop `break` / `continue` case，真实 MIR-C99 C 经 host C99 编译运行并与
        C99 oracle 对齐，不含 legacy fallback 证据。
      - `bash tests/verify_portable_mir_core_body_lowering.sh`：通过。
      - `bash tests/verify_portable_mir_verifier.sh`：通过。
      - `bash tests/verify_mir_c99_cfg_parity.sh`：通过。
      - `bash tests/verify_mir_c99_full_language_return_local_branch_loop_parity.sh`：通过。
      - `git diff --check`：通过。
### 4.15 Full Language Parity

- [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG`: 补齐 CoreStmt/AST statement 到 MIR 的通用
  CFG lowering，而不是仅支持尾部 `return i32` 和少量表达式语句。
  - 覆盖范围：`LOCAL_DECL`、`ASSIGN`、`EXPR`、`RETURN`、`IF`、`WHILE`、loop
    backedge、`break` / `continue`、block、`DEFER`、`ERRDEFER`、`DROP`、
    `ERROR_PROPAGATION`，以及 AST 层的 `for` / `match` / `test` driver 入口映射。
  - 验收：`PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`
    至少在 statement/CFG shard 上不走 legacy fallback，并输出可编译运行的 MIR-C99 C。
  - 继续实现前必须先恢复固定验证路径 `../uya/bin/uya`；已失败的 baseline 子任务见失败归档。
  - [x] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-AST-DRIVERS`: 补齐 AST 层
    `for` / `match` / `test` driver 入口到通用 Core/MIR statement lowering 的映射。
    - 最小验证：for、match statement 和 test driver focused shard 走真实 `--mir-c99`
      或给出明确 MIR-C99 capability diagnostic。
    - 完成条件：覆盖矩阵记录真实 per-kind 状态，不能以 generator-only 或 legacy C99 证据标完成。
    - 实现：`src/build_compiler_driver.uya` 为 simple range `for 0..N |i|` 合成
      `LOCAL_DECL -> WHILE -> BLOCK + increment` 的 structured CoreStmt lowering；
      同时在 real CLI lowering miss 时补打
      `mir_c99_capability_diagnostic: kind=AST_MATCH_EXPR reason=match_expr_requires_expr_value_place`
      与
      `mir_c99_capability_diagnostic: kind=AST_TEST_STMT reason=test_driver_not_lowered`，
      让 `match` / `test` frontier 明确 fail-closed。
    - 固定路径刷新：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`
      通过，随后将生成的 `bin/cmd/build` 同步到 `../uya/bin/cmd/build`，使
      `../uya/bin/uya build ...` 吃到当前源码的 `build_compiler_driver` 改动。
    - 验证：
      `bash tests/verify_mir_c99_ast_driver_shard_cli_harness.sh` 通过，证明 simple
      range `for` 走真实 `../uya/bin/uya build --mir-c99` 生成
      `generated by MIR-C99 unit output writer` 并与 `--c99` oracle 对齐，`match`
      / `test` 则给出显式 capability diagnostic 且不留下非空输出。
    - 相关回归：
      `bash tests/verify_mir_c99_statement_cfg_shard_cli_harness.sh` 通过；
      `bash tests/verify_mandated_build_compiler_driver_entry.sh` 通过；
      `bash tests/verify_portable_mir_language_coverage.sh` 通过。

### 4.15 Full Language Parity

任务路径：`MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE`

- [x] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-REJECT-CONST-BUILTIN-ENTRYPOINTS`: 先把
  real CLI 下当前仍统一掉到 generic lowering missing 的 value/builtin 入口改成稳定
  capability diagnostic。
  - 覆盖范围：`AST_INT_LIMIT`、`AST_STRING_INTERP`、`AST_PARAMS` 与 builtin `@params`
    的真实 `../uya/bin/uya build --mir-c99` fail-closed 路径。
  - 最小验证：`bash tests/verify_mir_c99_full_language_value_entry_reject.sh`
  - 完成条件：对应 case 失败时输出稳定 `mir_c99_capability_diagnostic`，不再只剩
    generic lowering missing；覆盖矩阵状态改成 `reject` 并记录 real-CLI 证据。
  - 验证：
    - `bash tests/verify_mir_c99_full_language_value_entry_reject.sh`
    - `bash tests/verify_portable_mir_language_coverage.sh`
    - `git diff --check`
  - 结果：通过。real current-source CLI candidate 现在会分别输出
    `AST_INT_LIMIT` / `AST_STRING_INTERP` / `AST_PARAMS` 的稳定 capability diagnostic，
    覆盖矩阵对应项已同步为 `reject`。

### 4.15 Full Language Parity

路径：`MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE` -> `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-FLOAT-CONSTANT-MODEL`

- [x] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-FLOAT-CONSTANT-MODEL-PLAN`: 先收敛 `MirC99ValuePlan` / string global-init plan 的模块级常量模型；对 byte/null/i32 limit/zero float 建稳定分类，对非零 f32/f64 payload 给出 explicit reject 元数据。
  - 最小验证：`bash tests/verify_mir_c99_constant_model.sh` 与 `bash tests/verify_portable_mir_language_coverage.sh`。
  - 验证：`bash tests/verify_mir_c99_constant_model.sh` 通过；`bash tests/verify_portable_mir_language_coverage.sh` 通过；`git diff --check` 通过。
  - 说明：曾尝试 `UYA_ROOT="$PWD/lib/" ../uya/bin/uya test tests/test_mir_c99_constant_model.uya --project-root src/ --no-split-c` 做更接近运行态的模块级单测，但 mandated compiler 在导入 `src/lower/mir.uya` 时先触发既有 29 个类型/移动错误，属于当前环境中的前置兼容性故障，未作为本项通过条件；因此本项改用源码 contract + coverage matrix 固定常量模型与 string global-init 边界。
### 2026-06-23

上下文：`# MIR-C99 Backend TODO > 4.15 Full Language Parity > MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE > MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-FLOAT-CONSTANT-MODEL`

- [x] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-FLOAT-CONSTANT-MODEL-REAL-CLI`: 恢复
  current-source `cmd/build` candidate 链路后，用真实 `--mir-c99` const/value parity
  或 fail-closed diagnostic 覆盖 f32/f64、char、string、null、`i32.max`/`i32.min`。
  - 最小验证：恢复 `bash tests/verify_mandated_build_compiler_driver_entry.sh` 所需
    candidate build 链路，并扩展 `bash tests/verify_mir_c99_full_language_value_entry_reject.sh`
    到本组样例。
  - 实现：恢复 `../uya/bin/uya -> src/cmd/build_bootstrap/main.uya -> src/cmd/build/main.uya`
    的 real-CLI candidate 链路；`cmd/build` 入口临时委托 `compiler_driver_build_main()`，
    并为裸 `--help` 补齐独立入口返回 `0` 的兼容路径；同步收紧 bootstrap/current-source
    driver 的宿主 libc 调用、`exec/vm` 的本地整数平方根 helper、`extern_decls` 的 libc
    I/O 入口，以及覆盖矩阵文案。
  - 验证：
    - `bash tests/verify_mandated_build_compiler_driver_entry.sh` 通过。
    - `bash tests/verify_cmd_build_entry.sh` 通过。
    - `bash tests/verify_mir_c99_full_language_value_entry_reject.sh` 通过；现要求 real-CLI
      candidate 对 f32/f64、char、string、null、`@max/@min`、基础 string interp 和
      `@params` value case 走 `--mir-c99` 并与 legacy C99 oracle 对齐。
    - `git diff --check` 通过。
### 4.15 Full Language Parity

任务路径：`MIR-C99-FULL-SUPPORT-CALL-ABI-RUNTIME`

- [x] `MIR-C99-CALL-ABI-RUNTIME-EXTERN-I32-SIGNATURE-METADATA`: 让 current-source
  PortableMIR extern lowering 对 `extern fn add(a: i32, b: i32) i32;` 这类标量 extern
  声明生成真实 function type / param ABI metadata，不再复用无参 placeholder signature。
  - 覆盖范围：`native_build_hosted_mir_append_extern_function`、extern `MirFunction.signature_type_id`、
    `MirFunctionParamType`、`MIR_CALL_FLAG_MULTI_PARAM` 所需的 signature field/param metadata。
  - 验证：`bash tests/verify_mir_c99_extern_i32_signature_metadata.sh` 通过；其中包含
    `bash tests/verify_portable_mir_call_abi_metadata_inventory.sh` 通过，以及
    `UYA_ROOT="$REPO_ROOT/lib/" ../uya/bin/uya build src/cmd/build/main.uya -o <tmp>/cmd-build.c --no-split-c --project-root src/`
    通过；`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`
    通过；`git diff --check` 通过。

### 4.15 Full Language Parity

- [x] `MIR-C99-CALL-ABI-RUNTIME-CURRENT-SOURCE-CMD-BUILD-BOOTSTRAP`: 先修通
  `../uya/bin/uya -> src/cmd/build_bootstrap/main.uya -> src/cmd/build/main.uya`
  的 current-source build CLI 产出链路，解决 legacy C99 bootstrap 生成的
  `libc_*` 常量在 host C 编译阶段仍被裸 `O_RDONLY` / `SYS_*` / `EPOLL_*` /
  socket syscall 名引用的问题。
  - 覆盖范围：`src/cmd/build_bootstrap/main.uya` mandated compiler 入口、
    `src/cmd/build/main.uya` current-source build-only CLI、bootstrap 生成的
    current-source `cmd/build` host C compile/link。
  - 实现：补强 `tests/verify_mandated_build_compiler_driver_entry.sh`，在既有
    `../uya/bin/uya -> build_bootstrap -> cmd/build --help` gate 上额外拒绝 host C
    编译日志中的裸 `O_RDONLY` / `SYS_*` / `EPOLL_*` 编译错误。
  - 验证：`bash tests/verify_mandated_build_compiler_driver_entry.sh` 通过。
    `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o /tmp/build-bootstrap --project-root "$PWD/src/" --no-split-c`
    通过。
    `UYA_ROOT="$PWD" /tmp/build-bootstrap build src/cmd/build/main.uya -o /tmp/cmd-build --project-root "$PWD/src/" --no-split-c`
    通过。
    `/tmp/cmd-build --help` 退出码为 `0`，输出包含 `Uya build compiler` 与 `用法:`。
    额外 smoke：使用 current-source `/tmp/cmd-build` 生成临时 `return7.bin`，产物运行退出码为 `7`。

### 4.15 Full Language Parity

- `MIR-C99-FULL-SUPPORT-UNSUPPORTED-CAPABILITY-DIAGNOSTICS`
  - [x] `MIR-C99-FULL-SUPPORT-UNSUPPORTED-CAPABILITY-DIAGNOSTICS-DIRECT-BUILTINS`: 先收口
    `@asm` / `@asm_target`、`@syscall`、`@ptr_from_usize`、`@usize_from_ptr`
    的 current-source generator / build-driver capability reject。
    - 最小验证：`bash tests/verify_mir_c99_full_language_direct_builtin_capability_reject.sh`
      和 `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`
    - 完成条件：current-source `tests/mir_c99_generate.sh` 对以上 case fail-closed，
      输出稳定 `mir_c99_capability_diagnostic`，相关 coverage matrix 行从 `missing`
      改成 `reject`，且 reject 日志不出现 legacy fallback 证据。
    - 验证：`bash tests/verify_mir_c99_full_language_direct_builtin_capability_reject.sh` -> PASS；
      覆盖 `AST_ASM`、`AST_ASM_TARGET`、`AST_SYSCALL`、`AST_PTR_FROM_USIZE`、
      `AST_USIZE_FROM_PTR` 的 fail-closed reject，确认 `tests/mir_c99_generate.sh`
      输出稳定 `mir_c99_capability_diagnostic`，不生成 `.c`，相关 coverage matrix 行已切到 `reject`。
    - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` -> PASS。
    - 验证：`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_direct_builtin_capability_reject.sh` -> PASS。
    - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> PASS（标完成前 1 个 active task）。
    - 验证：`git diff --check` -> PASS。
    - 额外检查：`../uya/bin/uya check src/build_compiler_driver.uya --project-root src/` 未运行成功；
      固定路径缺少 `../uya/bin/cmd/check`，错误为 `错误: 缺少可执行子命令 ../uya/bin/cmd/check；请先运行 make cmds`，
      本轮未改用其他 Uya 编译器。

### 4.15 Full Language Parity

- `MIR-C99-FULL-SUPPORT-UNSUPPORTED-CAPABILITY-DIAGNOSTICS`
  - [x] `MIR-C99-FULL-SUPPORT-UNSUPPORTED-CAPABILITY-DIAGNOSTICS-EMBED-VARARGS`: 收口
    `@embed` / `@embed_dir`、`@va_start` / `@va_end` / `@va_arg` / `@va_copy`
    的 capability reject。
    - 最小验证：新增 real-CLI reject 脚本 + `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`
    - 完成条件：相关 AST/builtin matrix 行从 `missing` 改成 `reject`，并记录复现命令。
    - 验证：`bash tests/verify_mir_c99_full_language_embed_varargs_capability_reject.sh` -> PASS；
      覆盖 `AST_EMBED`、`AST_EMBED_DIR`、`AST_VA_START`、`AST_VA_END`、`AST_VA_ARG`、
      `AST_VA_COPY` 的 fail-closed reject，确认 `tests/mir_c99_generate.sh`
      输出稳定 `mir_c99_capability_diagnostic`，不生成 `.c`，相关 coverage matrix 行已切到 `reject`。
    - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` -> PASS。
    - 验证：`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_embed_varargs_capability_reject.sh` -> PASS。
    - 验证：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> PASS（标完成前 1 个 active task）。
    - 验证：`git diff --check` -> PASS。

### 4.15 Full Language Parity

- [x] `MIR-C99-FULL-SUPPORT-UNSUPPORTED-CAPABILITY-DIAGNOSTICS`: 对暂不支持或目标相关能力
  给出稳定 MIR-C99 capability diagnostic，不再落到 generic lowering missing。
  - 覆盖范围：atomic 首版支持/拒绝边界、SIMD vector/mask 首版支持/拒绝边界、
    `@asm` / `@asm_target`、`@syscall`、`@ptr_from_usize`、`@usize_from_ptr`、
    `@embed` / `@embed_dir`、varargs builtins、宏内 `mc_*` 运行期边界。
  - 验收：覆盖矩阵中相关 `missing` 行转成带复现命令的 `reject` 或真实 parity；
    reject case 必须产生 MIR-C99 capability diagnostic，并通过 no-legacy-fallback 检查。
  - 说明：atomic / SIMD 首版 reject 证据已在 completed archive 落地；本父任务剩余缺口按下列子叶子继续收口。
  - [x] `MIR-C99-FULL-SUPPORT-UNSUPPORTED-CAPABILITY-DIAGNOSTICS-MC-RUNTIME-BOUNDARY`: 收口
    宏内 `mc_*` 运行期边界的 capability reject。
    - 最小验证：新增 real-CLI reject 脚本 + `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh`
    - 完成条件：相关 `AST_MC_*` / builtin matrix 行从 `missing` 或 `partial`
      收口到带复现命令的 `reject` 或真实 parity，并保留稳定 diagnostic reason。
    - 验证：`bash tests/verify_mir_c99_full_language_macro_builtin_capability_reject.sh` -> PASS。
    - 验证：`bash tests/verify_portable_mir_language_coverage.sh` -> PASS。
    - 验证：`bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` -> PASS。
    - 验证：`bash -n tests/mir_c99_generate.sh tests/verify_mir_c99_full_language_macro_builtin_capability_reject.sh` -> PASS。
    - 验证：`git diff --check` -> PASS。
    - 说明：`../uya/bin/uya check src/build_compiler_driver.uya --project-root src/` 当前因仓库缺少可执行 `cmd/check` 失败；`../uya/bin/uya build src/build_compiler_driver.uya -o /tmp/uya-build-driver-check.c --project-root src/` 仅复现既有“文件不包含 main 函数”，未作为本叶子完成 gate。

### 4.15 Full Language Parity

父任务路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE`

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-REAL-CLI-GATES`: 固定 HelloWorld / distinct-output
  gate 走 `../uya/bin/uya`，并在真实 `--mir-c99` route 缺失时 fail closed。
  - 验收：
    - `bash tests/verify_mir_c99_cli_helloworld.sh` 使用 `../uya/bin/uya`；未进入 real
      `--mir-c99` route 时输出明确诊断。
    - `bash tests/verify_mir_c99_cli_distinct_outputs.sh` 使用 `../uya/bin/uya`；未进入
      real `--mir-c99` route 时输出明确诊断。
    - 当前真实阻塞固定为 `后端类型: C99` / legacy banner，而不是 HelloWorld-like
      假阳性通过。
  - 验证：
    - `python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`
      -> `ok: docs/todo_mir_c99_backend.md has 1 active task`
    - `bash tests/verify_mir_c99_cli_helloworld.sh`
      -> fail closed：`HelloWorld CLI did not enter the real --mir-c99 route`，日志显示
      `后端类型: C99`。
    - `bash tests/verify_mir_c99_cli_distinct_outputs.sh`
      -> fail closed：`HelloWorld CLI did not enter the real --mir-c99 route`，日志显示
      `后端类型: C99`。
    - `bash tests/verify_mir_c99_global_import_link_real_cli.sh`
      -> fail closed：preflight 未进入 real `--mir-c99` route，日志显示 `后端类型: C99`。
    - `bash tests/verify_mir_c99_interface_call_surface_real_cli.sh`
      -> fail closed：interface dispatch 未进入 real `--mir-c99` route，日志显示
      `后端类型: C99`。

### 4.15 Full Language Parity

父级任务路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE`

  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-BUILD-ENTRY-RECOVERY`: 恢复 fixed/current-source
    `cmd/build` 的真实 build CLI 入口，消除 host C compile 裸 `O_RDONLY` / `SYS_*`
    blocker。
    - 验收：`bash tests/verify_mandated_build_compiler_driver_entry.sh` 通过。
    - 实现：放开 `src/codegen/c99/global.uya` 的 program-level 全局常量回查条件，
      让 full-C99 路径在 `global_variables` 尚未登记时仍能回落到合并 program 解析，
      不再把导出常量退化成裸 `O_RDONLY` / `SYS_*` / `EPOLL_*`。
    - 验证：`cp bin/cmd/build ../uya/bin/cmd/build` 先恢复 fixed `../uya/bin/uya`
      所委托的 real build CLI，然后运行
      `bash tests/verify_mandated_build_compiler_driver_entry.sh`
      结果：`OK: mandated compiler can bootstrap a current-source build CLI entry and build cmd/build`

## 2026-06-24
### 4.15 Full Language Parity
父级任务路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE` 让真实 `--mir-c99` CLI 在主语言测试集上收敛。

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-HELLOWORLD-REAL-ROUTE`: 让 fixed/current-source CLI
  对 `examples/HelloWorld.uya` 的 `--mir-c99` 日志出现 `[MIR-C99]`，输出带
  `generated by MIR-C99 unit output writer`，不再回落到 legacy C99。
  - 实施（2026-06-24）：
    - 使用 `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o <tmp>/build-bootstrap --project-root "$PWD/src/" --no-split-c` 生成临时 `build-bootstrap`。
    - 使用 `UYA_ROOT="$PWD" <tmp>/build-bootstrap build src/cmd/build/main.uya -o <tmp>/cmd-build --project-root "$PWD/src/" --no-split-c` 生成 current-source `cmd/build`。
    - 同步覆盖 `bin/cmd/build` 与 `../uya/bin/cmd/build`，恢复 fixed/current-source HelloWorld `--mir-c99` 入口。
  - 验收：
    - `bash tests/verify_mir_c99_cli_helloworld.sh` -> `OK: uya build --mir-c99 examples/HelloWorld.uya emits and runs MIR-C99 C`
  - 补充观察：
    - `bash tests/verify_mandated_build_compiler_driver_entry.sh` 当前失败于 `src/cmd/build_bootstrap/main.uya` host C compile 裸名 `std_runtime_saved_envp` / `TYPED_PROGRAM_INVALID_ID` / `FUNCTION_SCOPE_BINDING_*`；未阻塞本叶子验收，后续如需恢复 fixed compiler 直接重建 `build_bootstrap`，需单独收口。

## 4.15 Full Language Parity

Parent: `MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-RUNNER-COMPILER-PATH`: 修复 `tests/run_programs_parallel.sh` 在 `compiler_work_dir` 中错误解析相对 `UYA_COMPILER` 的问题。
  - 验收：
    - `bash tests/verify_run_programs_parallel_compiler_path.sh`
    - `UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`
  - 结果：
    - `bash tests/verify_run_programs_parallel_compiler_path.sh`：通过。
    - 全量主语言面真实基线不再出现 `./tests/run_programs_parallel.sh: line 497: ../uya/bin/uya: No such file or directory`，已进入真实 MIR-C99 失败面。
    - 汇总：`1024` 项中 `151` 通过、`873` 失败；失败分布为 `789` 个 `错误: MIR-C99 extern lowering 失败`、`81` 个 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`、`2` 个 `错误: MIR-C99 unit output 写出失败`、`2` 个 `PortableMIR verifier 失败`。
    - 已出现的具体 capability diagnostic：`19` 个 `AST_TEST_STMT / test_driver_not_lowered`，`1` 个 `AST_SYSCALL / syscall_requires_target_capability`。

# MIR-C99 Backend TODO
## 4. 任务清单
### 4.15 Full Language Parity
父级路径：
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`: 让真实 `--mir-c99` CLI 在主语言测试集上收敛。
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`: 让主语言面 `--mir-c99` 回归收敛，

    - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-EXTERN-LOWERING-FIRST-BUCKET`:
      让首个 generic `extern lowering 失败` 用例收敛为具体 capability diagnostic
      或真实支持，不再停在通用报错。
      - 验收：
        - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/assignment.uya -o /tmp/uya-mir-c99-main-language-extern.c`
          通过；不再输出 `错误: MIR-C99 extern lowering 失败`，现收敛到
          `mir_c99_capability_diagnostic: kind=AST_TEST_STMT reason=test_driver_not_lowered file=tests/assignment.uya line=6`
          和 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
        - `bash tests/verify_mir_c99_full_language_extern_capability_reject.sh`
          通过；固定 `../uya/bin/uya` 验收路径已锁定为上面的 `AST_TEST_STMT` capability diagnostic。
        - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya test tests/assignment.uya`
          通过；`3` 个 assignment 测试全部通过，说明 `lib/std/testing/testing.uya`
          改为 `@print/@println` 后未破坏基础断言路径。
        - `git diff --check -- lib/std/testing/testing.uya tests/verify_mir_c99_full_language_extern_capability_reject.sh docs/todo_mir_c99_backend.md`
          通过。

# MIR-C99 Backend TODO
## 4. 任务清单
### 4.15 Full Language Parity
父级路径：
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`: 让真实 `--mir-c99` CLI 在主语言测试集上收敛。
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`: 让主语言面 `--mir-c99` 回归收敛，

    - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-SUITE-RECOUNT`: 在首批具体
      bucket 收敛后重跑主语言面，更新剩余 failure matrix 和 capability diagnostic
      分布。
      - 验收：
        - `UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror'
          LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`
          失败项计数下降，且通用报错按 bucket 记录到 TODO/归档。
      - 结果：
        - 非 TTY 自动化下，需设 `UYA_TEST_STDOUT_LINEBUF=1` 关闭
          `tests/run_programs_parallel.sh` 的 `stdbuf` 自包装；否则同命令会退化成空输出
          `编译失败(退出码:139)`，不能代表真实 MIR-C99 失败面。
        - `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`：`1024` 项中 `155` 通过、`869` 失败，较上轮 `151/873` 增加 `4` 个通过、减少 `4` 个失败。
        - 通用报错分布：`596` 个 `错误: MIR-C99 extern lowering 失败`、`263` 个 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`、`2` 个 `错误: MIR-C99 unit output 写出失败`、`3` 个 `PortableMIR verifier 失败`。
        - capability diagnostic 分布：`182` 个 `AST_TEST_STMT / test_driver_not_lowered`、`5` 个 `AST_MC_CODE / mc_code_requires_compile_time_macro_capability`、`5` 个 `AST_MC_SOURCE / mc_source_requires_compile_time_macro_capability`、`4` 个 `AST_MC_TYPE / mc_type_requires_compile_time_macro_capability`、`2` 个 `AST_PARAMS / params_tuple_requires_expr_value_place`、`2` 个 `AST_MC_INTERP / mc_interp_requires_compile_time_macro_capability`、`1` 个 `AST_EMBED / embed_requires_compile_time_embed_capability`、`1` 个 `AST_SYSCALL / syscall_requires_target_capability`。
        - 对照 spot-check：`UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 --safety-proof tests/assignment.uya -o /tmp/mir_c99_recount_assignment_safety.c` 与 `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 --safety-proof tests/test_asm_const_output.uya -o /tmp/mir_c99_recount_asm_const_output_safety.c` 均稳定收敛到 `AST_TEST_STMT` capability diagnostic 和 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`，说明本轮重计数已回到真实 MIR-C99 诊断面，而不是脚本包装导致的假性 `exit 139`。
# MIR-C99 Backend TODO
## 4. 任务清单
### 4.15 Full Language Parity
父级路径：
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`: 让真实 `--mir-c99` CLI 在主语言测试集上收敛。
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`: 让主语言面 `--mir-c99` 回归收敛，

    - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-VERIFIER-FIRST-BUCKET`:
      固定首个 real CLI `PortableMIR verifier 失败` 用例与 focused gate，避免后续修复继续淹没在
      full-suite matrix 中。
      - 最小验证：
        - `bash tests/verify_mir_c99_full_language_verifier_first_bucket.sh`
      - 完成条件：
        - gate 通过，并固定 `tests/test_function_reachability_codegen.uya` 的 `[MIR-C99]`
          路由与 verifier diagnostic。
      - 验证（2026-06-24，本轮）：
        - `bash tests/verify_mir_c99_full_language_verifier_first_bucket.sh`
          => `OK: MIR-C99 first verifier bucket fails closed with a stable real-CLI verifier diagnostic`
        - gate 内部固定执行
          `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_function_reachability_codegen.uya -o <tmp>/test_function_reachability_codegen.c`，
          当前稳定命中 `[MIR-C99]` 路由、`错误: MIR-C99 PortableMIR verifier 失败: code=7 function=6 block=2 inst=2 value=2 type=1 operand=-1`
          与 `MIR-C99 verifier inst: op=3 type=1 result=2 operand_start=2 operand_count=1 flags=3`，且 reject 后不留下非空输出。
        - `git diff --check -- docs/todo_mir_c99_backend.md tests/verify_mir_c99_full_language_verifier_first_bucket.sh`
          通过。
## 4.15 Full Language Parity
Parent: `MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-UNIT-OUTPUT-FIRST-BUCKET-REOPEN-AFTER-CURRENT-UYA-REBUILD`:
  在 current checkout 能重新产出可执行 compiler 并可替换 fixed `../uya/bin/uya`
  后，重开真实首个 `MIR-C99 unit output 写出失败` bucket。当前 real CLI 首个单文件
  case 已漂移为 `tests/test_exec_vm_try_unsupported.uya`，不再是
  `tests/extern_function.uya`。
  - 最小验证：
    - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_exec_vm_try_unsupported.uya -o /tmp/uya-mir-c99-unit-output-first-bucket.c`
  - 验证（2026-06-24）：
    - `bash tests/verify_cmd_build_entry.sh`：通过；fixed `../uya/bin/uya` 可重新产出 current-source `cmd/build` 并直接执行 build CLI。
    - `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build/main.uya -o <tmp>/cmd-build.fresh --no-split-c --project-root "$PWD/src/"`：通过；fresh `cmd/build` 已同步到 sibling `../uya/bin/cmd/build`。
    - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_exec_vm_try_unsupported.uya -o /tmp/uya-mir-c99-unit-output-first-bucket.c`：退出码 `1`，真实日志进入 `[MIR-C99]` 路由并稳定报 `structured_i32_preflight_fail: index=0 type=10 locals=0 exprs=0` 与 `错误: MIR-C99 unit output 写出失败`，产物未生成。

## 4.15 Full Language Parity
Context:
- `MIR-C99-FULL-SUPPORT-CLI-SUITE`
- `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-PORTABLEMIR-GENERIC-REOPEN`:
  在 fixed `../uya/bin/uya` 能再次重建 current-source `cmd/build` 后，重开首个 generic
  `PortableMIR lowering 尚未覆盖当前程序` bucket。
  - 最小验证：
    - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o /tmp/uya-mir-c99-portablemir-reopen.c`
  - 验证记录（2026-06-24，本轮）：
    - `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`：通过；local current-source `bin/cmd/build` 重建成功，并已原子替换同步到 sibling `../uya/bin/cmd/build`，使 mandated `../uya/bin/uya` 命中本轮源码修复。
    - `bash tests/verify_mir_c99_test_stmt_nested_capability_diag.sh`：通过，top-level `test` 内嵌 `@asm` 现在下钻为 `AST_ASM / inline_asm_requires_target_capability`。
    - `bash tests/verify_mir_c99_full_language_extern_capability_reject.sh`：通过，`tests/assignment.uya` 仍保持 `AST_TEST_STMT / test_driver_not_lowered` fail-closed。
    - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o /tmp/uya-mir-c99-portablemir-reopen.c`：按预期失败，但 capability diagnostic 已变为 `mir_c99_capability_diagnostic: kind=AST_ASM reason=inline_asm_requires_target_capability file=tests/test_asm_const_output.uya line=5`，不再停在 `AST_TEST_STMT / test_driver_not_lowered`。

### 4.15 Full Language Parity
- 父级任务：`MIR-C99-FULL-SUPPORT-CLI-SUITE` > `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-SUITE-RECOUNT-NEXT`:
    在上述 generic bucket 继续下降后重跑主语言面，更新剩余 failure matrix 与 capability
    diagnostic 分布。
    - 最小验证：
      - `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`
    - 验证：
      - `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> `ok: docs/todo_mir_c99_backend.md has 1 active task`
      - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o /tmp/uya-mir-c99-recount-next-asm.c` -> 退出码 `1`，输出 `mir_c99_capability_diagnostic: kind=AST_ASM reason=inline_asm_requires_target_capability file=tests/test_asm_const_output.uya line=5`，随后 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
      - `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass` -> 退出码 `1`；`总计: 1024`、`通过: 155`、`失败: 869`。
      - failure matrix：`596` 个 `错误: MIR-C99 extern lowering 失败`、`263` 个 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`、`2` 个 `错误: MIR-C99 unit output 写出失败`、`3` 个 `PortableMIR verifier 失败`。
      - capability diagnostic 分布：`147` 个 `AST_TEST_STMT / test_driver_not_lowered`、`15` 个 `AST_ASM / inline_asm_requires_target_capability`、`9` 个 `AST_MC_SOURCE / mc_source_requires_compile_time_macro_capability`、`6` 个 `AST_MATCH_EXPR / match_expr_requires_expr_value_place`、`5` 个 `AST_MC_CODE / mc_code_requires_compile_time_macro_capability`、`4` 个 `AST_STRING_INTERP / string_interp_requires_expr_value_place`、`4` 个 `AST_MC_TYPE / mc_type_requires_compile_time_macro_capability`、`2` 个 `AST_USIZE_FROM_PTR / usize_from_ptr_requires_target_capability`、`2` 个 `AST_PARAMS / params_tuple_requires_expr_value_place`、`2` 个 `AST_MC_INTERP / mc_interp_requires_compile_time_macro_capability`、`1` 个 `AST_SYSCALL / syscall_requires_target_capability`、`1` 个 `AST_PTR_FROM_USIZE / ptr_from_usize_requires_target_capability`、`1` 个 `AST_INT_LIMIT / int_limit_requires_expr_value_place`、`1` 个 `AST_FOR_STMT / for_driver_not_lowered`、`1` 个 `AST_EMBED / embed_requires_compile_time_embed_capability`、`1` 个 `AST_ASM_TARGET / asm_target_requires_target_capability`。
      - 结果：generic capability 总量仍为 `202` 个，其中 `AST_TEST_STMT / test_driver_not_lowered` 从 `182` 个降到 `147` 个，`tests/test_asm_const_output.uya` 等 `@asm` 用例已显式暴露为 `AST_ASM` bucket。

### 2026-06-24 - Full Language Parity / Main Language

来源：`docs/todo_mir_c99_backend.md`

标题上下文：`### 4.15 Full Language Parity`

父级任务路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-NESTED-TEST-CAPABILITY-DIAGNOSTIC`:
    让顶层 `test` 块内部的 unsupported 节点优先暴露真实 capability diagnostic，
    不再被外层 `AST_TEST_STMT / test_driver_not_lowered` 抢占。
    - 最小验证：
      - `bash tests/verify_mir_c99_test_stmt_nested_capability_diag.sh`
      - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o <tmp>.c`
    - 完成条件：
      - 顶层 `test` 包裹的 `@asm` real CLI case 输出
        `mir_c99_capability_diagnostic: kind=AST_ASM reason=inline_asm_requires_target_capability`
      - reject 不留下非空 MIR-C99 输出文件。
    - 已验证（2026-06-24）：
      - `bash tests/verify_mir_c99_test_stmt_nested_capability_diag.sh`：通过，输出
        `OK: MIR-C99 top-level test capability diagnostics now descend into nested unsupported nodes`。
      - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o /tmp/uya-mir-c99-test-asm-const-direct.c`：
        退出码 `1`，日志显示 `[MIR-C99]` 与
        `mir_c99_capability_diagnostic: kind=AST_ASM reason=inline_asm_requires_target_capability file=tests/test_asm_const_output.uya line=5`，
        随后 fail-closed 为 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`，且未生成输出文件。
### 4.15 Full Language Parity
父级路径：
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`: 让真实 `--mir-c99` CLI 在主语言测试集上收敛。
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`: 让主语言面 `--mir-c99` 回归收敛，

    - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-SUITE-RECOUNT-AFTER-NESTED-TEST-DIAG`:
      在 nested `test` capability diagnostic 固定后重跑主语言面，更新 failure matrix
      与 capability diagnostic 分布。
      - 验证（2026-06-24，本轮）：
        - `bash tests/verify_mir_c99_test_stmt_nested_capability_diag.sh`
          => `OK: MIR-C99 top-level test capability diagnostics now descend into nested unsupported nodes`
        - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o /tmp/uya-mir-c99-recount-after-nested-asm.c`
          => 退出码 `1`，输出 `mir_c99_capability_diagnostic: kind=AST_ASM reason=inline_asm_requires_target_capability file=tests/test_asm_const_output.uya line=5`，随后
          `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
        - `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`
          => 退出码 `1`；`总计: 1024`、`通过: 155`、`失败: 869`。
      - 结果：
        - 顶层失败项口径下，`859` 个编译失败收敛为 `596` 个 `错误: MIR-C99 extern lowering 失败`、`259` 个 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`、`1` 个 `错误: MIR-C99 unit output 写出失败`、`3` 个 `PortableMIR verifier 失败`。
        - 其余 `10` 个为非编译失败：`2` 个链接失败（`test_export_for_c`、`test_export_for_c_complete`）、`6` 个单文件运行失败（`test_module_use_simple`、`test_function_reachability_tuple_expr`、`test_c99_import_main_codegen`、`test_function_reachability_string_interp_expr`、`test_array_bounds`、`test_module_export`）、`2` 个聚合多文件失败（`multifile`、`cross_deps`）。
        - 显式 capability diagnostic 总量保持 `202`，分布与当前主 todo 基线一致：`147` 个 `AST_TEST_STMT / test_driver_not_lowered`、`15` 个 `AST_ASM / inline_asm_requires_target_capability`、`9` 个 `AST_MC_SOURCE / mc_source_requires_compile_time_macro_capability`、`6` 个 `AST_MATCH_EXPR / match_expr_requires_expr_value_place`、`5` 个 `AST_MC_CODE / mc_code_requires_compile_time_macro_capability`、`4` 个 `AST_STRING_INTERP / string_interp_requires_expr_value_place`、`4` 个 `AST_MC_TYPE / mc_type_requires_compile_time_macro_capability`、`2` 个 `AST_USIZE_FROM_PTR / usize_from_ptr_requires_target_capability`、`2` 个 `AST_PARAMS / params_tuple_requires_expr_value_place`、`2` 个 `AST_MC_INTERP / mc_interp_requires_compile_time_macro_capability`、`1` 个 `AST_INT_LIMIT / int_limit_requires_expr_value_place`、`1` 个 `AST_EMBED / embed_requires_compile_time_embed_capability`、`1` 个 `AST_FOR_STMT / for_driver_not_lowered`、`1` 个 `AST_PTR_FROM_USIZE / ptr_from_usize_requires_target_capability`、`1` 个 `AST_SYSCALL / syscall_requires_target_capability`、`1` 个 `AST_ASM_TARGET / asm_target_requires_target_capability`。
        - 结论：nested `test` capability diagnostic 固定后的主语言面重计数已完成复核；当前主 todo 中的 failure matrix 与 capability diagnostic 分布已按本轮真实 CLI 结果刷新。

### 2026-06-24 - Full Language Parity / Main Language

来源：`docs/todo_mir_c99_backend.md`

标题上下文：`### 4.15 Full Language Parity`

父级任务路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-EXTERN-FIRST-BUCKET-NEXT`:
    让首个 generic `错误: MIR-C99 extern lowering 失败` real CLI 用例收敛为具体
    capability diagnostic 或真实支持。
    - 最小验证：
      - `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`
      - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_https_google.uya -o /tmp/uya-mir-c99-extern-signature-inspect.2zLK9T/test_https_google.c`
    - 完成条件：
      - `tests/test_https_google.uya` 不再输出 generic `错误: MIR-C99 extern lowering 失败`。
      - fixed `../uya/bin/uya` 输出 `mir_c99_capability_diagnostic: kind=AST_FN_DECL reason=extern_signature_requires_i32_scalars file=.*/lib/libc/errno.uya line=145`。
    - 已验证（2026-06-24）：
      - `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build/main.uya -o /tmp/uya-cmd-build-current.2T4wpW --project-root src/ --no-split-c`：通过；生成的新 `cmd/build` 已同步到 fixed `../uya/bin/cmd/build`，使真实 CLI 吃到当前源码改动。
      - `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`：通过，输出 `OK: MIR-C99 real CLI extern signature bucket now fails closed with explicit capability diagnostics`。
      - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_https_google.uya -o /tmp/uya-mir-c99-extern-signature-inspect.2zLK9T/test_https_google.c`：退出码 `1`，日志显示 `mir_c99_capability_diagnostic: kind=AST_FN_DECL reason=extern_signature_requires_i32_scalars file=/home/winger/uya/uya-1.0/lib/libc/errno.uya line=145`，随后 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
      - `bash tests/verify_mir_c99_full_language_extern_capability_reject.sh`：通过，确认旧 `tests/assignment.uya` extern focused gate 未回归。
      - `bash tests/verify_portable_mir_language_coverage.sh`：通过。
      - `git diff --check -- src/build_compiler_driver.uya tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh docs/portable_mir_language_coverage.md docs/todo_mir_c99_backend.md`：通过。
## 4.15 Full Language Parity
Parent: `MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-UNIT-OUTPUT-FIRST-BUCKET-NEXT`:
  让首个 `错误: MIR-C99 unit output 写出失败` real CLI 用例收敛为具体
  capability diagnostic 或真实支持。
  - 最小验证：
    - `bash tests/verify_mir_c99_full_language_unit_output_first_bucket.sh`
  - 完成条件：
    - fixed `../uya/bin/uya build --mir-c99 tests/test_exec_vm_try_unsupported.uya -o <tmp>.c`
      不再停在通用 `错误: MIR-C99 unit output 写出失败`，而是稳定输出
      `mir_c99_capability_diagnostic: kind=AST_CATCH_EXPR reason=catch_return_not_lowered`。
  - 验证（2026-06-24，本轮）：
    - `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build/main.uya -o <tmp>/cmd-build.fresh --no-split-c --project-root "$PWD/src/"`：通过；fresh `cmd/build` 已安装到 sibling `../uya/bin/cmd/build`，使 mandated fixed CLI 命中本轮源码。
    - `bash tests/verify_mir_c99_full_language_unit_output_first_bucket.sh`
      => `OK: MIR-C99 first unit-output bucket fails closed with a stable AST_CATCH_EXPR diagnostic`
    - `bash tests/verify_mir_c99_full_language_verifier_first_bucket.sh`
      => `OK: MIR-C99 first verifier bucket fails closed with a stable real-CLI verifier diagnostic`
    - `git diff --check -- src/build_compiler_driver.uya docs/portable_mir_language_coverage.md docs/todo_mir_c99_backend.md tests/verify_mir_c99_full_language_unit_output_first_bucket.sh`：通过。

### 4.15 Full Language Parity
路径上下文：`MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
    - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-VERIFIER-FIRST-BUCKET-NEXT`:
      固定首个 `PortableMIR verifier 失败` real CLI 用例和 focused gate，避免后续修复
      继续淹没在主语言全量输出中。
      - 最小验证：`bash tests/verify_mir_c99_full_language_verifier_first_bucket.sh`
      - 验证（2026-06-24，本轮）：
        - `bash -n tests/verify_mir_c99_full_language_verifier_first_bucket.sh`：通过。
        - `bash tests/verify_mir_c99_full_language_verifier_first_bucket.sh`：通过，输出
          `OK: MIR-C99 first verifier bucket fails closed with a stable real-CLI verifier diagnostic`。

## 2026-06-24
# MIR-C99 Backend TODO
## 4. 任务清单
### 4.15 Full Language Parity
父级任务路径：
- `[ ] MIR-C99-FULL-SUPPORT-CLI-SUITE`: 让真实 `--mir-c99` CLI 在主语言测试集上收敛。
- `[ ] MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`: 让主语言面 `--mir-c99` 回归收敛，
      - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-CAPABILITY-FAIL-CLOSED-NO-GENERIC-LOWERING`:
        让已输出具体 capability diagnostic 的 real-CLI reject bucket 直接 fail-closed，
        不再尾随 generic `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
        - 最小验证：
          `bash tests/verify_mir_c99_full_language_extern_capability_reject.sh`
          `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`
        - 完成条件：`tests/assignment.uya` 与 `tests/test_https_google.uya` 在真实
          `../uya/bin/uya build --mir-c99` 路径下都只保留 capability diagnostic，不再输出
          generic `PortableMIR lowering 尚未覆盖当前程序`，且 reject 不留下非空输出文件。
        - 实现摘要：`src/build_compiler_driver.uya` 在 extern append 失败与 safe body append
          失败分支里，只有拿不到具体 capability diagnostic 时才回退 generic diagnostic。
        - 验证结果（2026-06-24，本轮）：
          `bash tests/verify_mir_c99_full_language_extern_capability_reject.sh`
          -> 通过，输出 `OK: MIR-C99 assignment extern bucket now fails closed with explicit capability diagnostic`
          `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`
          -> 通过，输出 `OK: MIR-C99 real CLI extern signature bucket now fails closed with explicit capability diagnostics`
          `bash tests/verify_mir_c99_extern_i32_signature_metadata.sh`
          -> 通过，输出 `OK: MIR-C99 extern i32 signature metadata lowering verified`
        - 结果摘要：`tests/assignment.uya` 与 `tests/test_https_google.uya` 在真实
          `../uya/bin/uya build --mir-c99` 路径下都只保留 capability diagnostic，
          不再输出 generic `PortableMIR lowering 尚未覆盖当前程序`，reject 也未留下非空输出文件。

### 4.15 Full Language Parity
父级路径：
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-FIRST-GENERIC-LOWERING-BUCKET`:
    在 capability fail-closed cleanup 后，重选并收敛首个仍停在 generic
    `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序` 的非 capability 样例。
    - 最小验证：先重跑主语言面计数，锁定新的首个 generic lowering case，再补 focused
      real-CLI gate。
    - 验证（2026-06-24，本轮）：
      - `python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`：通过，`ok: docs/todo_mir_c99_backend.md has 1 active task`。
      - `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`：退出码 `1`；`总计: 1024`、`通过: 155`、`失败: 869`。按本轮 `tests/build_mir_c99` 产物与测试枚举顺序复核，新的首个 generic-only 样例锁定为 `tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya`。
      - `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`：通过；本地 `bin/cmd/build` 已用受约束 fixed compiler 重建，并同步到 sibling `../uya/bin/cmd/build`。
      - `bash tests/verify_mir_c99_full_language_simd_select_first_bucket.sh`：通过，输出 `OK: MIR-C99 real CLI SIMD select first bucket now fails closed with explicit capability diagnostics`。
      - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya -o /tmp/uya-mir-c99-simd-select-direct.c`：退出码 `1`，日志进入 `[MIR-C99]` 路由，输出 `mir_c99_capability_diagnostic: kind=AST_TYPE_VECTOR reason=vector_type_requires_target_helper_capability file=tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya line=2`，不再输出 generic `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
      - `bash tests/verify_mir_c99_full_language_simd_vector_mask_reject.sh`：通过，保持 SIMD vector/mask 的显式 reject 边界与 coverage 证据不回退。
    - 结果：主语言面新的首个 generic PortableMIR lowering bucket 已从 `tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya` 收敛到 `AST_TYPE_VECTOR / vector_type_requires_target_helper_capability`；下一轮可直接重跑主语言面 matrix，确认 generic compile failure 计数继续下降。

### 4.15 Full Language Parity

- 父级任务路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-RECOUNT-MATRIX`:
  重跑主语言面 `--mir-c99` 并刷新 failure matrix，确认 generic compile failure 计数
  随上述收敛继续下降。
  - 最小验证：
    `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass`
  - 验证（2026-06-24，本轮收口）：
    `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass` -> `1024` 项中 `155` 通过、`869` 失败；顶层 `859` 个编译失败里 `849` 个已显式收敛为具体 `kind/reason` capability diagnostic，仅剩 `7` 个 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序` 与 `3` 个 `PortableMIR verifier 失败`；generic `错误: MIR-C99 extern lowering 失败` 已清零；另有 `2` 个链接失败、`6` 个单文件运行失败、`2` 个 `multifile/cross_deps` 聚合失败。
    `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md` -> `ok: docs/todo_mir_c99_backend.md has 0 active tasks`
    `git diff --check -- docs/todo_mir_c99_backend.md` -> 通过
  - 结果摘要：`tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya` 已从 generic lowering 收敛到 `AST_TYPE_VECTOR / vector_type_requires_target_helper_capability`；`tests/test_https_google.uya` 已从 generic `extern lowering 失败` 收敛到 `AST_FN_DECL / extern_signature_requires_i32_scalars`；顶层 generic compile failure 现仅剩 `10` 个。
## 4. 任务清单
### 4.15 Full Language Parity
父级路径：
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-REMAINING-GENERIC-LOWERING`:
    将剩余 `7` 个顶层 generic `PortableMIR lowering 尚未覆盖当前程序`
    收敛为具体 capability diagnostic，覆盖 `tests/test_cfg_target.uya`、
    `tests/test_exec_vm_const_pool.uya`、`tests/test_exec_vm_defer.uya`、
    `tests/test_exec_vm_drop_local.uya`、`tests/test_exec_vm_hir_scope.uya`、
    `tests/test_exec_vm_local_load_store.uya`、
    `tests/test_struct_array_field_typed_empty_init.uya`。
    - 最小验证：
      `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass tests/test_cfg_target.uya tests/test_exec_vm_const_pool.uya tests/test_exec_vm_defer.uya tests/test_exec_vm_drop_local.uya tests/test_exec_vm_hir_scope.uya tests/test_exec_vm_local_load_store.uya tests/test_struct_array_field_typed_empty_init.uya`
    - 实际验证（2026-06-24）：
      `bash tests/verify_mir_c99_full_language_remaining_generic_lowering_capability_reject.sh`
      -> `OK: remaining generic MIR-C99 lowering bucket now fails closed with explicit capability diagnostics`
    - 结果（2026-06-24）：
      `tests/test_cfg_target.uya` /
      `tests/test_exec_vm_const_pool.uya` -> `AST_BINARY_EXPR /
      binary_expr_requires_general_expr_lowering`；
      `tests/test_exec_vm_defer.uya` /
      `tests/test_exec_vm_hir_scope.uya` /
      `tests/test_exec_vm_local_load_store.uya` -> `AST_CALL_EXPR /
      call_expr_requires_call_lowering`；
      `tests/test_exec_vm_drop_local.uya` -> `AST_ASSIGN /
      assign_dest_requires_local_i32_binding`；
      `tests/test_struct_array_field_typed_empty_init.uya` ->
      `AST_VAR_DECL / local_decl_requires_i32_scalar_storage`；
      全部 `7` 例不再输出 generic
      `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。

## 4. 任务清单
### 4.15 Full Language Parity
`MIR-C99-FULL-SUPPORT-CLI-SUITE`
`MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-REMAINING-VERIFIER-FAILURES`:
    收敛剩余 `3` 个 `PortableMIR verifier 失败`：
    `tests/test_function_reachability_codegen.uya`、
    `tests/test_function_reachability_codegen_microapp.uya`、
    `tests/test_semantic_lookup_function_family.uya`。
    - 最小验证：
      `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass tests/test_function_reachability_codegen.uya tests/test_function_reachability_codegen_microapp.uya tests/test_semantic_lookup_function_family.uya`
    - 完成说明：
      `src/build_compiler_driver.uya` 中 direct-call MIR helper 现在按已追加 `decl_id` 查找真实 callee，相关内部 `i32` helper 使用真实函数签名；旧 first verifier bucket 已从 `PortableMIR verifier 失败` 前移。当前结果为：`tests/test_semantic_lookup_function_family.uya` 通过，`tests/test_function_reachability_codegen_microapp.uya` 收敛到 `AST_ASSIGN / assign_dest_requires_local_i32_binding`，`tests/test_function_reachability_codegen.uya` 已不再命中 verifier，当前 frontier 为 `错误: MIR-C99 unit output 写出失败`。
    - 验证：
      `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`：通过。
      `bash tests/verify_mir_c99_full_language_remaining_verifier_failures.sh`：通过，输出 `OK: MIR-C99 remaining verifier-failure cases no longer end in PortableMIR verifier failures`。
      `bash tests/verify_mir_c99_full_language_verifier_first_bucket.sh`：通过，输出 `OK: MIR-C99 first verifier bucket no longer ends in a PortableMIR verifier failure`。

- 路径：`# MIR-C99 Backend TODO` > `## 4. 任务清单` > `### 4.15 Full Language Parity` > `MIR-C99-FULL-SUPPORT-CLI-SUITE` > `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
  - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-AST-FN-DECL-EXTERN-SIGNATURE`:
    针对当前主导的 `AST_FN_DECL / extern_signature_requires_i32_scalars`
    （`589` 个）建立 focused 收敛路径，避免 generic extern lowering 回潮。
    - 最小验证：
      `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`
      -> 通过，输出 `OK: MIR-C99 real CLI extern signature bucket now fails closed with explicit capability diagnostics`。

### 4.15 Full Language Parity

父级任务路径：
`MIR-C99-FULL-SUPPORT-CLI-SUITE`
`MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-EXTERN-SIGNATURE-COMMON-TYPES`:
  先扩展 imported extern 的常用 `void` / 整数标量 / `bool` / `byte` / pointer 签名；本轮只覆盖非 aggregate、非 error-union 的 direct extern ABI，让 real CLI 不再把 `tests/test_mem_allocator.uya`、`tests/test_ffi_cast.uya`、`tests/extern_ffi_no_struct.uya` 卡在 `AST_FN_DECL / extern_signature_requires_i32_scalars`。
  - 最小验证：
    `bash tests/verify_mir_c99_full_language_extern_signature_common_types.sh`
  - 完成说明（2026-06-24，本轮）：
    `src/build_compiler_driver.uya` 为 extern 签名新增 `void` / 常用整数标量 / `bool` / `byte` / pointer 的 AST->MirType 映射，并把 `native_build_hosted_mir_append_extern_signature_type` 从 i32-only 扩展到新的 common-type surface。
    `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 本轮已成功重建 current-source `bin/cmd/build`，随后同步 sibling `../uya/bin/cmd/build`，让固定 `../uya/bin/uya` 的 real CLI 真正加载到本轮源码变更。
    `tests/test_mem_allocator.uya` 现前移到 `AST_TEST_STMT / test_driver_not_lowered`；`tests/test_ffi_cast.uya` 与 `tests/extern_ffi_no_struct.uya` 现前移到 `PortableMIR verifier 失败: code=16`；三者都不再命中 `extern_signature_requires_i32_scalars`。
  - 验证：
    `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`：通过，`bin/cmd/build` 生成成功。
    `bash tests/verify_mir_c99_full_language_extern_signature_common_types.sh`：通过，输出 `OK: MIR-C99 imported extern signatures no longer stop at extern_signature_requires_i32_scalars`。
    `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_mem_allocator.uya -o /tmp/uya-mir-c99-mem-repro/out.c`：失败前移到 `AST_TEST_STMT / test_driver_not_lowered`。
    `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_ffi_cast.uya -o /tmp/uya-mir-c99-sample/out.c`：失败前移到 `错误: MIR-C99 PortableMIR verifier 失败: code=16`。
    `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/extern_ffi_no_struct.uya -o /tmp/uya-mir-c99-sample/out.c`：失败前移到 `错误: MIR-C99 PortableMIR verifier 失败: code=16`。
    `UYA_TEST_STDOUT_LINEBUF=1 UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass tests/extern_ffi_no_struct.uya`：runner 入口同样前移到 `错误: MIR-C99 PortableMIR verifier 失败: code=16`，未回退到旧 extern-signature generic。

### 4.15 Full Language Parity
Parent: `MIR-C99-FULL-SUPPORT-CLI-SUITE` > `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-EXTERN-SIGNATURE-AGGREGATE-ERROR-UNION`:
  继续处理 imported extern 的 aggregate / error-union 返回 ABI，让 real CLI
  不再把 `tests/test_async_return_value.uya`、`tests/test_syscall_time.uya`、
  `tests/test_https_google.uya` 卡在 `lib/libc/pthread.uya:1018`
  (`pthread_self() -> pthread_t`) 或 `lib/libc/syscall.uya` 的 `!i32/!i64`
  return surface。
  - 最小验证：
    `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_async_return_value.uya -o /tmp/uya-mir-c99-async-return-value.c`
  - 验证（2026-06-24）：
    `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`
    `bash tests/verify_mir_c99_full_language_extern_signature_aggregate_error_union.sh`
    `bash tests/verify_mir_c99_full_language_extern_signature_common_types.sh`
    `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`
  - 结果（2026-06-24）：
    已重建 current-source `bin/cmd/build` 并同步 sibling `../uya/bin/cmd/build`；
    `tests/test_async_return_value.uya`、`tests/test_syscall_time.uya`、
    `tests/test_https_google.uya` 已不再命中
    `extern_signature_requires_i32_scalars`，real `--mir-c99` 现统一前移到
    `lib/libc/stdio.uya:882` 的 `extern_varargs_requires_c_variadic_capability`。

## 4. 任务清单
### 4.15 Full Language Parity
父级任务路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE` -> `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
      - [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-EXTERN-VARARGS-CAPABILITY`:
        继续处理 imported extern 的 C variadic capability，让 real CLI 决定是直接支持
        `printf`/`snprintf` 一类 variadic extern，还是把 fail-closed 边界收紧成更精确的
        capability bucket，而不是把 async/syscall/https 样例卡在同一个泛型 reject。
        - 最小验证：
          `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`
        - 验证（2026-06-24，本轮）：
          `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`
          结果：通过，输出 `OK: MIR-C99 real CLI now fails closed at the next explicit varargs capability bucket`
          `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_async_return_value.uya -o /tmp/uya-mir-c99-varargs-async.c`
          `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_syscall_time.uya -o /tmp/uya-mir-c99-varargs-syscall.c`
          `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_https_google.uya -o /tmp/uya-mir-c99-varargs-https.c`
          结果：三例均失败并稳定落在 `mir_c99_capability_diagnostic: kind=AST_FN_DECL reason=extern_varargs_requires_c_variadic_capability file=.../lib/libc/stdio.uya line=882`

### 4.15 Full Language Parity
Path: `MIR-C99-FULL-SUPPORT-CLI-SUITE` > `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`
- [x] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-ENTRY-EXTERN-BODY`:
  单独处理 `lib/std/runtime/entry/entry.uya:79` 的 `export extern fn main`
  路径，让它从“签名不支持”前移到真实 body/link frontier，再决定是直接支持还是给出更精确
  的 fail-closed 边界。
  - 完成说明：`src/build_compiler_driver.uya` 现将 `std.runtime.entry` 的 `export extern fn main`
    识别为专门 runtime bridge 边界；extern 扫描与 extern diagnostic 会先处理其他 extern bucket，
    只有在无更早 blocker 时才收敛到 `AST_FN_DECL / entry_extern_main_requires_runtime_bridge`，
    不再回落到 generic `PortableMIR verifier 失败: code=16`。
  - 验证：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 通过；`cp bin/cmd/build ../uya/bin/cmd/build`
    已同步 fixed real CLI 到 sibling mandated 路径。
  - 验证：`bash tests/verify_mir_c99_full_language_entry_extern_body_boundary.sh` 通过。
  - 验证：`bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh` 通过，仍保持
    `lib/libc/stdio.uya:882 / extern_varargs_requires_c_variadic_capability` bucket。
  - 验证：`UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_simple_fn.uya -o /tmp/uya-mir-c99-entry-main.c`
    失败闭合到 `mir_c99_capability_diagnostic: kind=AST_FN_DECL reason=entry_extern_main_requires_runtime_bridge`
    `file=/media/winger/_dde_home/winger/uya/uya-1.0/lib/std/runtime/entry/entry.uya line=79`，不再出现
    `extern_signature_requires_i32_scalars` 或 `PortableMIR verifier 失败: code=16`。
