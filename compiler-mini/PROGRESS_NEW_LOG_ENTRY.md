### 2026-01-13（指针类型字段访问和 null 字面量支持实现）

- 实现指针类型字段访问和 null 字面量的完整支持
  - ✅ 修复 `null` 字面量处理
    - 在变量初始化时，添加了对 `null` 标识符的特殊处理
    - 在 `AST_IDENTIFIER` 处理中，添加了对 `null` 标识符的特殊处理，使其在比较运算符中能够被正确处理
    - 当变量类型是指针类型时，使用 `LLVMConstNull` 生成 null 常量
  - ✅ 修复指针类型字段访问
    - 在 `codegen_gen_expr` 的 `AST_MEMBER_ACCESS` 处理中，添加了对指针类型变量的字段访问支持（如 `point_ptr.x`）
    - 在 `codegen_gen_lvalue_address` 的 `AST_MEMBER_ACCESS` 处理中，添加了对指针类型变量的字段访问支持（用于赋值语句，如 `point_ptr.x = 50`）
    - 关键修复：函数参数为指针类型时，无论 `struct_name` 是否设置，都检查变量类型并加载指针值
    - 添加了 `lookup_var_ast_type` 函数的前向声明
  - ✅ 修复链接问题
    - 在测试脚本 `run_programs.sh` 中添加了 `-no-pie` 选项来修复链接失败
  - ✅ 代码质量检查通过（编译通过，无错误）
  - ✅ 测试状态：
    - `pointer_test` ✅ 完全通过（编译、链接、运行全部成功）
    - 所有指针相关功能测试通过（null 初始化、指针比较、字段访问、函数参数等）
  - 参考：`compiler-mini/src/codegen.c` 中的 `AST_MEMBER_ACCESS` 处理代码和变量初始化代码
  - **状态**：指针类型字段访问和 null 字面量支持已完成

### 2026-01-13（sizeof 运算符对结构体类型的支持实现）

- 实现 `sizeof` 运算符对结构体类型和结构体数组类型的支持
  - ✅ 添加必要的头文件 (`llvm-c/Target.h`) 以支持 TargetData API
  - ✅ 在代码生成开始时就初始化 DataLayout（在第零步，在函数体生成之前）
    - 使用 `LLVMInitializeNativeTarget()` 初始化 LLVM 目标
    - 创建 `LLVMTargetMachine` 并设置模块的 DataLayout
    - 确保在生成函数体时 DataLayout 已可用
  - ✅ 实现 `sizeof` 对结构体类型的支持
    - 在 `codegen_gen_expr()` 的 `AST_SIZEOF` 处理中
    - 使用 `LLVMGetModuleDataLayout()` 获取模块的 DataLayout
    - 使用 `LLVMStoreSizeOfType()` 获取结构体的存储大小（字节数）
  - ✅ 实现 `sizeof` 对结构体数组类型的支持
    - 在数组类型的 `sizeof` 处理中
    - 对于结构体类型的数组元素，使用 `LLVMStoreSizeOfType()` 获取元素大小
  - ✅ 优化 `sizeof(identifier)` 的处理
    - 对于标识符表达式，直接从变量表获取类型，不生成代码
    - 避免不必要的代码生成，提高效率
  - ✅ 代码质量检查通过（编译通过，无错误）
  - ⚠️ 测试状态：
    - `sizeof(&i32)` ✅ 工作正常
    - `sizeof(结构体变量)` ✅ 工作正常
    - `sizeof(结构体类型)` ✅ 已实现
    - `sizeof_test` ❌ 失败（使用了 `byte` 类型，compiler-mini 可能不支持）
  - 参考：`compiler-mini/src/codegen.c` 中的 `AST_SIZEOF` 处理代码

