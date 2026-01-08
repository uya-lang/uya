# Error 处理实现状态

## 已完成的工作

### 阶段1：引入 IR_ERROR_VALUE IR 指令类型 ✅

1. **IR 结构定义** (`compiler/src/ir/ir.h`)
   - ✅ 添加了 `IR_ERROR_VALUE` 到 `IRInstType` 枚举（第43行）
   - ✅ 添加了 `error_value` 结构体字段到 `IRInst` 的 union（第276-278行）

2. **IR 生成** (`compiler/src/ir_generator.c`)
   - ✅ 在 `AST_MEMBER_ACCESS` case 中添加了识别 `error.*` 的逻辑（第696-721行）
   - ✅ 当检测到 `error.ErrorName` 时，生成 `IR_ERROR_VALUE` 而不是 `IR_MEMBER_ACCESS`
   - ✅ 正确存储错误名称到 `error_value.error_name` 字段

3. **代码生成** (`compiler/src/codegen/codegen_value.c`)
   - ✅ 添加了 `IR_ERROR_VALUE` case 到 `codegen_write_value`（第78-104行）
   - ✅ 实现了错误码生成逻辑（使用哈希函数生成 `uint32_t` 错误码）
   - ✅ 哈希函数：`error_code = error_code * 31 + char`（类似 Java 的 String.hashCode）
   - ✅ 确保错误码非零（0 表示成功）

4. **内存管理** (`compiler/src/ir/ir.c`)
   - ✅ 添加了 `IR_ERROR_VALUE` 的释放逻辑（第229-232行）

5. **错误处理辅助功能** (`compiler/src/codegen/codegen_error.c`)
   - ✅ 实现了错误名称收集（`collect_error_names` 函数）
   - ✅ 实现了错误码冲突检测（`detect_error_code_collisions` 函数）
   - ✅ 更新了 `is_error_return_value` 函数以识别 `IR_ERROR_VALUE`（第251-281行）

### 阶段2：实现标记联合（完整支持 `!T` 类型）✅

1. **类型定义** (`compiler/src/codegen/codegen_type.c`)
   - ✅ 实现了 `codegen_write_error_union_type_def` 函数（第109-120行）
   - ✅ 生成标记联合结构：`struct error_union_T { uint32_t error_id; T value; }`
   - ✅ 支持 `!void` 类型（只有 `error_id` 字段，无 `value` 字段）
   - ✅ 实现了 `codegen_write_error_union_type_name` 函数（第100-103行）

2. **函数返回值处理** (`compiler/src/codegen/codegen_inst.c`)
   - ✅ 在函数定义中识别 `return_type_is_error_union` 标志（第37-38行，第97-98行）
   - ✅ 生成错误联合类型的返回值变量（第97-116行）
   - ✅ 实现了错误返回值的处理逻辑（第191-234行）：
     - 错误返回：设置 `error_id = 错误码`
     - 正常返回：设置 `error_id = 0`，设置 `value = 正常值`

3. **函数签名** (`compiler/src/codegen/codegen_main.c`)
   - ✅ 在代码生成前收集并生成错误联合类型定义（第107-174行）
   - ✅ 函数前向声明使用错误联合类型（第197-198行）
   - ✅ 函数定义使用错误联合类型作为返回类型（`codegen_inst.c` 第37-38行）

4. **IR 层支持** (`compiler/src/ir/ir.h`, `compiler/src/ir_generator.c`)
   - ✅ 添加了 `return_type_is_error_union` 标志到函数定义（`ir.h` 第112行）
   - ✅ 在 IR 生成时正确设置 `return_type_is_error_union` 标志（`ir_generator.c` 第921-922行）

### 阶段3：实现运行时检测（errdefer 支持）✅

1. **errdefer 块收集** (`compiler/src/codegen/codegen_inst.c`)
   - ✅ 实现了 errdefer 块的收集逻辑（第122-123行，第170-173行）
   - ✅ 支持嵌套块中的 errdefer 块收集（第732-746行）

2. **错误检测逻辑** (`compiler/src/codegen/codegen_inst.c`)
   - ✅ 实现了 `_check_error_return` 标签（第811-816行）
   - ✅ 在函数末尾检查 `error_id` 字段（`error_id != 0` 表示错误）
   - ✅ 根据 `error_id` 值跳转到 `_error_return` 或 `_normal_return` 标签

3. **errdefer 执行逻辑** (`compiler/src/codegen/codegen_inst.c`)
   - ✅ 实现了 `_error_return` 标签（第822-893行）
   - ✅ 错误返回时执行 errdefer 块（第825-841行，按 LIFO 顺序）
   - ✅ 错误返回时也执行 defer 块（第843-859行）
   - ✅ 错误返回时执行 drop 调用（第861-885行）

4. **正常返回处理** (`compiler/src/codegen/codegen_inst.c`)
   - ✅ 实现了 `_normal_return` 标签（第896行）
   - ✅ 正常返回时只执行 defer 块，不执行 errdefer 块（第898-917行）
   - ✅ 正常返回时执行 drop 调用（第919-943行）

5. **返回语句处理** (`compiler/src/codegen/codegen_inst.c`)
   - ✅ 所有返回语句跳转到 `_check_error_return` 标签（第264行）
   - ✅ 在 `_check_error_return` 标签中统一检查错误并跳转到相应的返回路径

## 实现细节

### 错误码生成

- **算法**：使用哈希函数 `error_code = error_code * 31 + char`（类似 Java 的 String.hashCode）
- **类型**：`uint32_t`（根据 uya.md 规范）
- **约束**：错误码不能为 0（0 表示成功）
- **稳定性**：相同的错误名称总是生成相同的错误码，即使其他错误被添加或删除

### 标记联合结构

- **结构定义**：
  ```c
  struct error_union_T {
      uint32_t error_id;  // 0 = 成功（使用 value），非零 = 错误（使用 error_id）
      T value;            // 成功值（仅在 error_id == 0 时有效）
  };
  ```
- **!void 类型**：只有 `error_id` 字段，无 `value` 字段

### errdefer 执行流程

1. 函数执行过程中收集所有 defer 和 errdefer 块
2. 返回语句设置返回值并跳转到 `_check_error_return` 标签
3. `_check_error_return` 标签检查 `error_id` 字段：
   - `error_id != 0`：跳转到 `_error_return` 标签
   - `error_id == 0`：跳转到 `_normal_return` 标签
4. `_error_return` 标签：
   - 执行 errdefer 块（LIFO 顺序）
   - 执行 defer 块（LIFO 顺序）
   - 执行 drop 调用（LIFO 顺序）
   - 返回
5. `_normal_return` 标签：
   - 执行 defer 块（LIFO 顺序）
   - 执行 drop 调用（LIFO 顺序）
   - 返回

## 相关文件

- **IR 定义**：`compiler/src/ir/ir.h`
- **IR 生成**：`compiler/src/ir_generator.c`
- **IR 内存管理**：`compiler/src/ir/ir.c`
- **错误处理**：`compiler/src/codegen/codegen_error.c`
- **类型处理**：`compiler/src/codegen/codegen_type.c`
- **值生成**：`compiler/src/codegen/codegen_value.c`
- **指令生成**：`compiler/src/codegen/codegen_inst.c`
- **主代码生成**：`compiler/src/codegen/codegen_main.c`

## 架构设计文档

详细的设计文档请参考 `error_design.md`。
