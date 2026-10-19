# TensorFlow Lite Micro 纯 Uya 实现 — 详细设计文档

> **核对头（2026-10-19）**：已按 `lib/tflm/` 实际 10 个文件复核——`common/common.uya`、`model/model.uya`、`arena/arena.uya`、`tensor/tensor.uya`、`resolver/resolver.uya`、`interpreter/interpreter.uya`、`kernels/kernels.uya`、`quant/quant.uya`、`backend/backend.uya`、`backend/arm.uya`，与 §2.2 目录树**完全一致**。测试 5 个：`tests/test_tflm_model.uya`、`test_tflm_arena.uya`、`test_tflm_interpreter.uya`、`test_tflm_phase2.uya`、`test_tflm_cmsis.uya`（后者额外链接 `tests/tflm_cmsis_host_stub.c`）。
> **最需要注意的偏差**：§3 描述的 FlatBuffer 加载**尚未实现**，Phase 1 用的是线性 stub；实际入口是 `load_model_plan(data: &byte, len: usize) !ModelPlan`（`model/model.uya:29`，`TFLM_MODEL_HEADER_SIZE = 12`），不是本文示例的 `load_model(&[u8]) !&const ModelHeader`。详见 §3.3 的核对注记。

本文档描述用 Uya 语言从零实现与 TensorFlow Lite Micro (TFLM) 功能对等的嵌入式推理引擎的架构、模块接口、数据流与实现约束。与 [tflm_uya_todo.md](tflm_uya_todo.md) 配合使用：设计文档定「做什么、长什么样」，待办文档定「按什么顺序做、做到什么算完成」。

---

## 1. 目标与约束

### 1.1 目标

- 在 Uya 中实现一套 **纯 Uya** 的 TinyML 推理运行时，与 TFLM 行为对等的常用子集：FlatBuffer 模型加载、Arena 内存管理、算子注册与解释执行、常用算子（Conv2D、DepthwiseConv、FullyConnected、Softmax 等）。
- 可选：集成 ARM CMSIS-NN 等 C 优化库（通过 FFI），多后端（Cortex-M4F / RISC-V）编译期选择。
- 库根目录建议：`lib/tflm/`；测试位于 `tests/` 根目录，命名 `test_tflm_*.uya`；需通过 `--c99` 与 `--uya --c99`。

### 1.2 约束

- **内存**：无 GC，无隐式堆分配；张量内存由调用方提供的 Arena（如 `[u8: N]`）分配。
- **错误**：统一使用 Uya 错误联合类型 `!T`，错误在 `lib/tflm/common.uya` 集中定义（如 `error.ModelCorrupted`、`error.OpNotSupported`、`error.ArenaExhausted`、`error.InvalidAlignment`）。
- **无异常**：与 TFLM 一致，嵌入式禁用异常；Uya 的 `try`/`catch` 仅用于错误联合类型的传播与处理。
- **C 互操作**：可与现有 C 优化库（CMSIS-NN 等）通过 `extern` FFI 集成；Uya 结构体默认 C 内存布局（uya.md §4.1）。

### 1.3 与 TFLM C++ 的范式对应

| 特性           | TFLM (C++)           | Uya 实现                         |
|----------------|---------------------|----------------------------------|
| 面向对象       | 类、继承             | 结构体 + 接口（无继承）          |
| 泛型/模板      | C++ 模板             | 尖括号泛型 `<T: Constraint>`     |
| 动态派发       | 虚函数表             | 接口动态派发（接口值 8/16 字节）或函数指针数组 |
| 错误处理       | 错误码               | `!T` 错误联合 + `try`/`catch`    |
| 内存管理       | 静态 + Arena         | RAII + `defer`/`errdefer` + 移动语义 |
| 标准库依赖     | 无 C++ STL           | 无标准库（零依赖设计）           |

---

## 2. 总体架构

### 2.1 层次与依赖

```
应用层         推理入口（Interpreter.invoke）
    |
解释器层       Interpreter、OpResolver、执行循环
    |
算子层         Conv2D、FullyConnected、Softmax 等（含 CMSIS-NN 包装）
    |
内存层         ArenaAllocator、张量视图
    |
模型层         FlatBuffer 解析、Subgraph、Operator 元数据
```

- 实现顺序建议：**模型层 → 内存层 → 算子层（基础）→ 解释器层 → 算子扩展与优化**。
- 上层仅依赖下层公开接口，不跨层调用。

### 2.2 目录与模块

```
lib/tflm/
├── common/common.uya    # 错误码、BuiltinOperator、Context、常量
├── model/model.uya      # Phase 1：线性 stub ModelPlan（可演进为 FlatBuffer）
├── arena/arena.uya      # ArenaAllocator
├── tensor/tensor.uya    # TensorView
├── resolver/resolver.uya
├── interpreter/interpreter.uya
├── kernels/kernels.uya  # Phase 1～2：Conv / Depthwise / FC / Softmax + Pool / ReLU / Reshape
├── quant/quant.uya      # int8 饱和与 mul+shift 辅助
└── backend/
    ├── backend.uya      # 默认纯 Uya 通用实现（host / RISC-V / 通用 ARM）
    └── arm.uya          # ARM CMSIS-NN extern 声明占位（真机需替换链接库）
    # 编译期选择：use tflm.backend（默认通用）或 use tflm.backend.arm（ARM CMSIS-NN）
    # 文档：§7「多后端与编译期选择」
```

- 模块路径：`UYA_ROOT=lib/` 时，**须**「一层子目录 + 同名 `.uya`」以便解析为 `tflm.common`、`tflm.kernels` 等（与 `std.protobuf.*` 相同规则）。例：`lib/tflm/common/common.uya` → `use tflm.common`；`lib/tflm/kernels/kernels.uya` → `use tflm.kernels`。
- 测试：`tests/test_tflm_model.uya`、`tests/test_tflm_arena.uya`、`tests/test_tflm_interpreter.uya` 等，需通过 `--c99` 与 `--uya --c99`。

---

## 3. 模型层设计（model.uya）

### 3.1 目标

- 从字节缓冲区解析 TFLite FlatBuffer 模型，提供只读视图；**零拷贝**仅在保证对齐与布局兼容的前提下，对部分根表/子表做指针解释。
- FlatBuffer 根表、vtable、间接引用较多，首版可采用「子集/简化」：仅支持推理所需字段（operator_codes、subgraphs、buffers、tensors）；完整 vtable 走查与边界检查在无法编译期证明时需运行时完成。

### 3.2 数据结构（C 内存布局兼容）

- 与 FlatBuffer 布局兼容的结构体需按 TFLite schema 定义字段顺序与类型；Uya 的 `struct` 默认 C 内存布局（uya.md §4.1），可直接与 C 互操作。
- 示例（示意，具体偏移以 TFLite schema 为准）：

```uya
// 仅示意：实际偏移与类型需对照 flatbuffers 的 Model/SubGraph 等
struct ModelHeader {
    version: u32,
    // 其他根表字段...
}

struct SubGraphHeader {
    tensors_offset: u32,
    inputs: u32,
    outputs: u32,
    operators_offset: u32,
    // ...
}
```

- 字段偏移验证：当前 Uya **无** `@offset_of` 内置函数；若需编译期验证偏移，可（1）在规范/实现中新增 `@offset_of(Struct, field)`，或（2）使用手写常量 + 静态断言（如 `const_assert` 与 `@size_of`）做部分校验。设计上标注为「待编译器支持或手写常量」。

### 3.3 模型加载接口

- 从 Flash/ROM 或调用方提供的 `&[u8]` 加载模型；先做最小长度与魔数/版本检查，再解释为根表指针。
- Uya 中不能将 `&[u8]` 直接 `as &Model`；规范允许 `&void as &T`（类型擦除恢复）。正确做法：取缓冲区首地址转为 `&void`，再转为目标结构体指针，并保证对齐与长度由调用方保证或运行时检查。

```uya
error ModelTooShort;
error VersionMismatch;

const TFLITE_MIN_HEADER: usize = 4;  // 至少 version 等

fn load_model(data: &[u8]) !&const ModelHeader {
    if @len(data) < TFLITE_MIN_HEADER {
        return error.ModelTooShort;
    }
    const ptr: &const void = &data[0] as &const void;
    const model: &const ModelHeader = ptr as &const ModelHeader;
    if model.version != TFLITE_VERSION {
        return error.VersionMismatch;
    }
    return model;
}
```

> **2026-10-19 核对（重要）**：上面这段是**设计目标，不是当前实现**。现行代码是 Phase 1 的**线性 stub**：
> - `export const TFLM_MODEL_HEADER_SIZE: usize = 12;`（`lib/tflm/model/model.uya:6`）
> - `export struct ModelPlan { ... }`（`:8`）
> - `export fn load_model_plan(data: &byte, len: usize) !ModelPlan`（`:29`）—— 参数是 `(ptr, len)` 而非 `&[u8]`，返回的是值语义的 `ModelPlan` 而非 `&const ModelHeader`
> - `export fn model_plan_opcode_at(plan: &ModelPlan, i: usize) !i32`（`:57`）
> - 固定小端头 + opcode 列表，**不做** FlatBuffer vtable 走查；`error.ModelCorrupted` 等 9 个错误已在 `common/common.uya:4-12` 定义（`ModelTooShort`、`VersionMismatch`、`ModelCorrupted`、`OpNotSupported`、`ArenaExhausted`、`InvalidAlignment`、`DimensionMismatch`、`BufferTooSmall`、`ResolverFull`）。
> 真 `.tflite` 解析仍是待办（`tflm_uya_todo.md` 阶段 2 的最后一条/阶段 3）。

- 子图、算子、张量、buffer 的访问均通过偏移/索引在模型根表上计算；越界与空指针由运行时检查，必要时返回 `error.ModelCorrupted`。

---

## 4. 内存层设计（arena.uya, tensor.uya）

### 4.1 ArenaAllocator

- 单一连续缓冲区 `&[u8]`，维护 `offset: usize`；分配时按对齐前进，返回 `&void` 或类型化指针。
- 对齐要求：调用方传入的 `alignment` 需为 2 的幂；若无法在编译期证明不越界，则必须做运行时边界检查。若需更稳健，可在 `allocate` 内检查 `alignment != 0` 且为 2 的幂（如 `(alignment & (alignment - 1)) == 0`），否则返回 `error.InvalidAlignment`（该错误需在 common.uya 中定义）。

```uya
struct ArenaAllocator {
    buffer: &[u8],
    offset: usize,
}

fn align_forward(offset: usize, alignment: usize) usize {
    if alignment == 0 { return offset; }
    return (offset + alignment - 1) & ~(alignment - 1);
}

fn allocate(
    allocator: &mut ArenaAllocator,
    size: usize,
    alignment: usize
) !&void {
    const aligned = align_forward(allocator.offset, alignment);
    const end = aligned + size;
    if end > @len(allocator.buffer) {
        return error.ArenaExhausted;
    }
    const ptr: &void = &allocator.buffer[aligned] as &void;
    allocator.offset = end;
    return ptr;
}
```

- 资源清理：使用 `defer`/`errdefer` 在解释器或会话退出时重置 offset 或标记；不依赖 C++ 析构，由调用方或包装函数保证生命周期。

### 4.2 张量视图（tensor.uya）

- 张量不拥有内存，仅持有形状、类型、指向 Arena 内某段的指针；与 TFLite 的 `TfLiteTensor` 语义一致。
- 结构体字段示例：`dims: [i32: MAX_DIMS]`、`dim_count: u32`、`type: TensorType`、`data: &byte`（或 `&void`，**指向首元素的指针**）；可选 `bytes: usize` 表示数据区字节数；量化参数若需要可加 `params` 结构体。
- **FFI 传参约定**：`data` 为指向首元素的指针时，传给 C 时使用 `tensor.data as *i8`（或 `tensor.data as *const i8`），不要写 `&tensor.data[0]`。
- 访问元素时由调用方保证索引在 `dims` 范围内；若编译器无法证明，需运行时检查。

---

## 5. 算子注册与解释器（resolver.uya, interpreter.uya）

### 5.1 OpResolver

- **依赖**：`Context` 类型及 `PrepareFn`/`EvalFn` 类型别名建议放在 **common.uya** 或独立 **context.uya** 中定义，resolver.uya 与 interpreter.uya 均依赖该模块，避免循环依赖。
- TFLM 的 `MicroMutableOpResolver` 等价：按 `BuiltinOperator` 查找并返回「准备」与「执行」函数。
- 方案 A（轻量）：用函数指针数组 + 枚举数组，无接口 vtable；适合 MCU，8/16 字节 per-op。**Phase 1 现状**：当前 Uya 在 `struct` 字段中尚不能稳定使用 `fn(...) !void` 数组与对应类型别名，故 `OpResolver` 仅记录已注册 `BuiltinOperator`，`invoke` 内以 `match`/分支调用各 `kernels` 的 prepare/eval；待编译器支持后再收敛为设计中的函数指针表。

```uya
const MAX_OPS: u32 = 64;

enum BuiltinOperator : i32 {
    Conv2d = 3,
    DepthwiseConv2d = 4,
    FullyConnected = 9,
    Softmax = 25,
    // ...
}

type PrepareFn = fn(&mut Context) !void;
type EvalFn = fn(&Context) !void;

struct OpResolver {
    prepare: [PrepareFn: MAX_OPS],
    eval: [EvalFn: MAX_OPS],
    op_codes: [BuiltinOperator: MAX_OPS],
    count: u32,
}

fn register_op(
    resolver: &mut OpResolver,
    code: BuiltinOperator,
    prepare_fn: PrepareFn,
    eval_fn: EvalFn
) void {
    resolver.prepare[resolver.count] = prepare_fn;
    resolver.eval[resolver.count] = eval_fn;
    resolver.op_codes[resolver.count] = code;
    resolver.count += 1;
}

fn find(resolver: &const OpResolver, code: BuiltinOperator) !(PrepareFn, EvalFn) {
    var i: u32 = 0;
    while i < resolver.count {
        if resolver.op_codes[i] == code {
            return (resolver.prepare[i], resolver.eval[i]);
        }
        i += 1;
    }
    return error.OpNotSupported;
}
```

- **返回类型**：使用元组 `!(PrepareFn, EvalFn)` 而非匿名结构体，与 uya.md §2 元组类型一致，兼容性更好（元组在 C 代码生成中映射为匿名结构体 `.f0`/`.f1`）。若编译器支持匿名结构体作返回类型，也可用 `!struct { prepare: PrepareFn, eval: EvalFn }`。
- 方案 B：若希望统一接口，可定义 `interface Operator`，由各算子结构体实现；接口值在 64 位下为 16 字节（vtable 指针 + 数据指针），见 uya.md §6。首版推荐方案 A 以控制 footprint。

### 5.2 Interpreter 与 Context

- `struct Interpreter`：持有 `model: &const ModelHeader`、`allocator: &mut ArenaAllocator`、`resolver: &const OpResolver`、当前子图索引、`Context`（当前算子输入/输出张量、节点参数等）。
- `struct Context`：执行单算子时由解释器填充；包含输入/输出张量指针、临时缓冲区、op 参数（如 stride、padding）等。
- 主循环：遍历当前子图的 operators，按 op_code 从 resolver 查找 prepare/eval，依次调用 `try prepare(&mut ctx)`、`try eval(&ctx)`；任何 `!void` 返回即向上传播，由调用方 `catch` 处理。

```uya
fn invoke(interpreter: &mut Interpreter) !void {
    const subgraph = try get_subgraph(interpreter.model, interpreter.subgraph_index);
    var i: u32 = 0;
    while i < subgraph.operator_count {
        const op = get_operator(subgraph, i);
        const (prepare, eval) = try interpreter.resolver.find(op.code);
        try fill_context(&interpreter.context, interpreter, op);
        try prepare(&mut interpreter.context);
        try eval(&interpreter.context);
        i += 1;
    }
}
```

- 错误处理：调用方使用 `try interpreter.invoke()` 或 `interpreter.invoke() catch |err| { ... }`，与 uya.md §5 一致（`try` 传播错误，`catch` 捕获错误）。

---

## 6. 算子内核设计（kernels/*.uya）

### 6.1 通用约定

- 每个算子提供 `prepare` 与 `eval` 函数，签名与 OpResolver 中注册的一致；参数通过 Context 传入（张量指针、维度、量化参数等）。
- 量化卷积/全连接：累加器用 i32，再 requantize 到 int8；若使用饱和运算，可依赖 Uya 的饱和/包装运算符（如文档中提到的 `+|`、`+%`），在实现时注明以便与规范对齐。

### 6.2 Conv2D 示例（纯 Uya 示意）

- 输入：Context 中取 input、filter、bias、output 张量及 stride/padding 等；维度不匹配时返回 `error.DimensionMismatch`。
- 内层循环：按输出空间维度与卷积核遍历，累加 `acc: i32`，再写入 output（含量化和激活）；具体与 TFLite 的 ConvParams 一致。

### 6.3 CMSIS-NN 集成（FFI）

- 通过 `extern` 声明 C 函数（如 `arm_convolve_HWC_q7_basic`），参数使用 FFI 指针类型 `*i8`、`*u16` 等。张量视图的 `data` 为**指向首元素的指针**（见 §4.2）时，Uya 侧在边界检查后使用 `tensor.data as *i8`（或 `tensor.data as *const i8`）传参，不要写 `&tensor.data[0]`（uya.md §11：`&T as *T` 在 FFI 调用时允许）。
- 包装函数负责从 Context 解包参数、调用 C 函数、将结果写回输出张量；错误通过 `!void` 返回。边界检查可用张量的 `bytes` 字段或由 shape 计算得到的 `required_input_size`。

```uya
extern fn arm_convolve_HWC_q7_basic(
    Im_in: *i8,
    dim_im_in_x: u16,
    dim_im_in_y: u16,
    dim_im_in_ch: u16,
    wt: *const i8,
    ch_im_out: u16,
    dim_kernel_x: u16,
    dim_kernel_y: u16,
    padding_x: u16,
    padding_y: u16,
    stride_x: u16,
    stride_y: u16,
    bias: *const i32,
    Im_out: *i8,
    dim_im_out_x: u16,
    dim_im_out_y: u16,
    tmp_buf: *i16,
    out_shift: i32,
    out_mult: i32
) void;

fn conv2d_cmsis_wrapper(ctx: &Context) !void {
    const required_input_size: usize = ...;  // 由 shape 或 ctx.input.bytes 计算
    if ctx.input.bytes < required_input_size {
        return error.BufferTooSmall;
    }
    arm_convolve_HWC_q7_basic(
        ctx.input.data as *i8,
        ctx.dim_im_in_x,
        ctx.dim_im_in_y,
        ctx.dim_im_in_ch,
        ctx.filter.data as *const i8,
        ctx.ch_im_out,
        ctx.dim_kernel_x,
        ctx.dim_kernel_y,
        ctx.padding_x,
        ctx.padding_y,
        ctx.stride_x,
        ctx.stride_y,
        ctx.bias.data as *const i32,
        ctx.output.data as *i8,
        ctx.dim_im_out_x,
        ctx.dim_im_out_y,
        ctx.tmp_buf as *i16,
        ctx.out_shift,
        ctx.out_mult
    );
}
```

---

## 7. 多后端与编译期选择（Phase 3 完成）

- 目标：按目标架构选择不同实现（ARM 用 CMSIS-NN，x86_64 / RISC-V 用纯 Uya）。
- **当前实现**（Phase 3）：
  - `lib/tflm/backend/backend.uya`：默认纯 Uya 通用实现（`use tflm.backend`），覆盖 Conv2D/Depthwise/FC 等标准路径；亦可直接 `use tflm.backend.arm`。
  - `lib/tflm/backend/arm.uya`：ARM CMSIS-NN extern 声明占位（仅含 `extern fn arm_convolve_HWC_q7_basic` 声明，无 Uya 实现体）；ARM 目标可 `use tflm.backend.arm` 并在 C 链接阶段替换为 CMSIS-NN 库。
- **选择方式**（调用方源码层）：
  ```uya
  use tflm.backend;        // 默认：纯 Uya 通用实现（host / RISC-V）
  // 或
  use tflm.backend.arm;     // ARM CMSIS-NN（需链接 CMSIS-NN 库）
  ```
- 约束：Uya 当前 `use` 机制不支持运行时动态派发（无函数指针数组）；不同后端共用 `BuiltinOperator` 枚举值，调用方按目标编译期选择 `use` 路径即可。
- `@asm_target()` 可查询编译期平台（x86_64=0/1/2、arm64=3/4/5、riscv64=6），但 `std.cfg` 目前为运行时条件表达式，不能直接用于 `use` 静态路径选择；未来可扩展 `std.cfg` 支持编译期路径剪枝或宏 `@mc_if(cfg(...))` 实现真正的条件编译。

---

## 8. 数据流与调用关系

- **初始化**：应用提供 `[u8: ARENA_SIZE]`、模型 `&[u8]`；调用 `load_model` → 创建 `ArenaAllocator` → 创建 `OpResolver` 并注册算子 → 创建 `Interpreter`，`prepare` 阶段分配张量内存。
- **推理**：应用调用 `interpreter.invoke()` → 解释器按序执行各算子 `prepare`/`eval`，张量数据均在 Arena 内；错误通过 `!void` 返回并由应用 `catch` 处理。
- **清理**：Arena 由调用方管理生命周期；若需「重置」解释器，可 `defer` 或显式调用清理逻辑（如 offset 复位）。

---

## 9. 测试策略

- **单元**：`test_tflm_model.uya`（模型加载、版本/长度错误）；`test_tflm_arena.uya`（分配、对齐、ArenaExhausted）；`test_tflm_conv.uya`（单算子输入输出与已知向量一致）。
- **集成**：`test_tflm_interpreter.uya` 使用最小模型跑通 invoke 并校验输出张量；需通过 `./tests/run_programs_parallel.sh --c99` 与 `--uya --c99`。（2026-10-19 核对：这里用的仍是 stub `ModelPlan`，不是真 FlatBuffer；另有 `test_tflm_phase2.uya`、`test_tflm_cmsis.uya`。）
- **回归**：与 TFLite 转换的 .tflite 模型对比（相同输入下输出一致），可选、依赖测试数据与工具链。

---

## 10. 路线图与依赖

- **阶段 1（MVP）**：common、model（最小解析）、arena、tensor、resolver、interpreter 主循环；基础算子 Conv2D、DepthwiseConv、FullyConnected、Softmax；单子图、无量化或仅 int8 量化。
- **阶段 2**：CMSIS-NN 集成、更多算子（如 Pooling、Activation）；量化感知与 requantize 完善。
- **阶段 3**：多后端编译期选择（待 `TARGET_ARCH` 或等价支持）、工具链（内存分析、算子融合等）为可选扩展。

---

## 11. 风险与未实现能力

- **@offset_of**：当前 Uya 无此内置；FlatBuffer 偏移验证依赖手写常量或后续语言扩展。
- **编译期后端选择**：依赖 `TARGET_ARCH` 或宏/构建系统约定，非当前规范明确定义。
- **FlatBuffer 完整性**：完整 TFLite 模型含大量可选字段与扩展；首版聚焦推理必需子集，复杂模型可能需渐进支持。
- **性能与代码体积**：与 TFLM C++ 的对比需实测（代码体积、推理延迟）；Uya 无 RTTI/异常，预期体积可控，具体以 benchmark 为准。

---

## 12. 参考

- [uya.md](uya.md) — 类型、错误、接口、defer/errdefer、FFI、C 内存布局。
- [grammar_quick.md](grammar_quick.md) — 语法速查。
- TensorFlow Lite Micro：<https://github.com/tensorflow/tflite-micro>；FlatBuffer schema：`tflite/schema/schema.fbs`。
- 与 [tflm_uya_todo.md](tflm_uya_todo.md) 配合作为分阶段待办与验收标准。
