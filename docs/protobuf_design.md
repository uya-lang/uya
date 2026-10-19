# Uya 高性能 Protobuf 编解码器设计文档

**版本**：v0.1

**状态**：Phase 1–4 主体已实现（见 [todo_protobuf.md](todo_protobuf.md)）；泛型 `decode<T>` / `impl_protobuf!` 宏未实现

**最后核对**：2026-10-19，按 `lib/std/protobuf/{wire,impl,demo,decode,encode,dynamic,errors}.uya` 与 `tests/test_protobuf_*.uya`、`tests/bench_protobuf.uya` 回填

**参考**：Protocol Buffers Encoding、[protobuf 编解码器计划](../.cursor/plans/protobuf_编解码器计划_1cc43520.plan.md)

---

## 1. 概述

本文档定义 Uya 标准库的 Protocol Buffers 二进制编解码器设计，基于 Uya 的零 GC、编译期证明、显式内存控制、切片零拷贝等特性，实现高性能 protobuf 解析与编码。目标：Phase 1 接近 Rust prost 水平，力争达到 upb 的 1/2–2/3，明显优于 Go/Java 官方库。

### 1.1 设计目标

- **零拷贝**：string/bytes 字段返回 `&[byte]` 视图；调用方需保证 decoded 结构体生命周期不超 input
- **单次分配**：解析阶段使用 Arena
- **显式内存**：API 要求调用方传入 Arena 或预分配 buffer
- **编译期序列化**：设计目标是结构体经宏或手写生成 decode/encode，零反射。**当前为手写**：`impl_protobuf!` 宏与泛型 `decode<T>` 均未实现（`impl_macro.uya` 不存在），每个 message 需要手写 `decode_xxx` / `encode_xxx_to`，示例见 `lib/std/protobuf/demo.uya` + `decode.uya` + `encode.uya`
- **Wire format 兼容**：与标准 protobuf 互操作

### 1.2 Protobuf 特性概览

- **二进制格式**：非文本，顺序读取 tag + payload
- **Wire types**：0 (varint)、1 (64-bit)、2 (length-delimited)、5 (32-bit)
- **Tag**：`wire_type | (field_number << 3)`，varint 编码
- **Varint**：7-bit payload + MSB 续位
- **sint32/sint64**：zigzag 编码，负数更紧凑
- **Schema 依赖**：编解码皆需 field number 与类型

---

## 2. 设计原则（对齐 Uya 特性）

| Uya 特性 | Protobuf 设计应用 |
|----------|-------------------|
| 零 GC / 显式内存 | 解析器使用 Arena，编码器接受 buffer 或 Arena |
| 编译期证明 | 结构体 → protobuf 映射由宏或手写生成，零反射（**当前只有手写路径**） |
| 错误联合 `!T` | `decode_demo_user(...)` 返回 `!DemoUser`，`encode_demo_user_to(...)` 返回 `!usize`、`encode_demo_user_into_arena(...)` 返回 `!PbStrView` |
| 切片 `&[T]` | string/bytes 用 `PbStrView`(ptr+len) 视图指回输入，零拷贝（受 slice codegen 限制不走 `&[byte]`） |
| 无隐式分配 | API 显式要求传入 `&Arena` 或 buffer 容量 |

---

## 3. 标准范围与分阶段

### 3.1 Phase 1：Wire 层 + 基础类型

- Varint、zigzag（sint32/sint64）、fixed32、fixed64、double、float
- string、bytes（length-delimited，零拷贝，默认不校验 UTF-8，可选 `decode_strict`——**`decode_strict` 未实现**，UTF-8 校验待补）
- 单层 message，proto3 默认值（缺失字段填充 0、""、false）

### 3.2 Phase 2：嵌套与 repeated

- 嵌套 message
- repeated 标量、repeated message；同 field 多次出现合并
- repeated 内存：`ptr: &T, len: usize`（Arena 分配）
- packed repeated

### 3.3 Phase 3：高级特性

- map、oneof（Uya union + tag）、enum、optional

### 3.4 不做或延后

- .proto 文件解析（可交由独立工具生成 Uya 代码）
- proto2 完整语义、extensions、any、service/rpc

---

## 4. 整体架构

```mermaid
flowchart TB
    subgraph Decode [解码流程]
        A[Input: &[byte]] --> B[Wire 层: varint/tag/length]
        B --> C[按 schema 填充结构体]
        C --> D[T 或 PbMessage]
    end

    subgraph Encode [编码流程]
        E[结构体 T] --> F[宏/手写 encode]
        F --> G[PbWriter]
        G --> H[Output: &[byte]]
    end

    subgraph Memory [内存]
        I[Arena] --> J[decode 分配]
        K[调用方 buffer] --> G
    end
```

---

## 5. 核心数据结构

### 5.1 类型化 message（当前为**手写**，无宏）

```uya
// lib/std/protobuf/demo.uya:14-18（export struct）
struct DemoUser {
    id: i64,           // field 1, varint
    name: PbStrView,   // field 2, length-delimited（ptr+len 视图，不是 &[byte]）
    active: bool,      // field 3, varint
}
```

配套手写函数（`decode.uya` / `encode.uya`）：

```uya
export fn decode_demo_user(_arena: &Arena, ptr: &byte, len: usize) !DemoUser;          // decode.uya:36
export fn decode_demo_inner_d(_arena: &Arena, ptr: &byte, len: usize, depth: usize) !DemoInner;
export fn decode_demo_outer_d(arena: &Arena, ptr: &byte, len: usize, depth: usize) !DemoOuter;
export fn decode_demo_outer(arena: &Arena, ptr: &byte, len: usize) !DemoOuter;
export fn decode_demo_int_list(arena: &Arena, ptr: &byte, len: usize) !DemoIntList;
export fn decode_demo_inner_list(arena: &Arena, ptr: &byte, len: usize) !DemoInnerList;
export fn decode_demo_str_int_map(arena: &Arena, ptr: &byte, len: usize) !DemoStrIntMap;
export fn decode_demo_oneof_msg(_arena: &Arena, ptr: &byte, len: usize) !DemoOneofMsg;
export fn decode_demo_paint(_arena: &Arena, ptr: &byte, len: usize) !DemoPaint;
export fn decode_demo_opt_scores(_arena: &Arena, ptr: &byte, len: usize) !DemoOptScores;

export fn encode_demo_user_to(u: &DemoUser, buf: &byte, cap: usize) !usize;            // encode.uya:89
export fn encode_demo_user_into_arena(arena: &Arena, u: &DemoUser) !PbStrView;          // :116
export fn encode_demo_user_size(u: &DemoUser) usize;                                    // :353
```

`impl_protobuf!(User, 1 -> id, 2 -> name);` 这种宏**不存在**（`impl_macro.uya` 不存在），设计稿仅保留为未来方向。`DemoOuter` 的编码用固定 32 字节 scratch 先算内层长度（`encode.uya:137` `INNER_SCRATCH_CAP`），map 条目用 96 字节 scratch（`encode.uya:247` `MAP_ENTRY_INNER_CAP`）。

### 5.2 动态解析 PbMessage（可选）

逻辑模型可用 `union PbValue` 表达；**Uya 标准库实现**（`lib/std/protobuf/dynamic.uya`）采用**扁平 `PbValue`**（`kind` 与 wire type 一致 + `u64_v` / `u32_v` / `len_ptr`+`len_len`），避免 `struct` 内嵌 `union` 在 C99 后端上的不完整类型问题。

```uya
// dynamic.uya:25-41（export struct）
struct PbValue {
    kind: u32,          // 取值 = PbValueKind_varint(0) / _i64(1) / _len(2) / _i32(5)，与 wire type 编号一致
    u64_v: u64,
    u32_v: u32,
    len_ptr: &byte,
    len_len: usize,
}

struct PbField {
    field_num: u32,
    value: PbValue,
}

struct PbMessage {
    fields: &PbField,  // Arena 分配；`len == 0` 时为 null
    len: usize,
}
```

### 5.3 访问方式

- 类型化：直接访问 `user.id`、`user.name`
- 动态：`pb_message_find_field(msg, field_num) !PbValue`（首个匹配；同号重复字段在 `fields` 中各占一条，与 wire 出现次数一致）

---

## 6. Wire 层

### 6.1 Varint

- 每字节 7-bit 数据 + 1-bit 续位（MSB）
- 小端序拼接 7-bit 块
- 最大 10 字节（64-bit）

### 6.2 Zigzag（sint32/sint64）

- 0→0, -1→1, 1→2, -2→3, 2→4, ...
- `encode: (n << 1) ^ (n >> 31)` 等

### 6.3 Tag

- `tag = (field_number << 3) | wire_type`
- wire_type：0 varint, 1 64-bit, 2 length-delimited, 5 32-bit

### 6.4 Length-delimited

- 先 varint 长度，再 payload
- string、bytes、嵌套 message、packed repeated 均用此格式

---

## 7. 解析器（Decoder）

### 7.1 API

```uya
// 类型化：当前为「每题一函数」的手写形态，没有泛型 decode<T>（`decode_strict` 也未实现）
export fn decode_demo_user(_arena: &Arena, ptr: &byte, len: usize) !DemoUser;   // decode.uya:36

// 动态（dynamic.uya:86）
export fn decode_dynamic(arena: &Arena, ptr: &byte, buf_len: usize) !PbMessage;

// 设计稿期望但尚未实现：
// fn decode<T>(arena: &Arena, ptr: &byte, len: usize) !T;
// fn decode_strict(arena: &Arena, ptr: &byte, len: usize) !T;  // string 校验 UTF-8
```

注意参数是 `ptr + len`（与 `std.json.parse`、`std.yaml.parse` 一致），不是 `&[byte]`。

### 7.2 解析流程

1. 循环读取 tag（varint）
2. 根据 wire_type 读取 payload
3. 同 field 多次出现：repeated 合并，否则取最后一次（proto3）
4. unknown fields 跳过

### 7.3 错误类型

语法规范（[grammar_formal.md](grammar_formal.md)）：预定义错误为 `error ID ;`，**单条声明**，不支持 `error { ... }` 聚合块。

```uya
// lib/std/protobuf/errors.uya:4-13，共 10 个 export error
export error TruncatedInput;
export error InvalidVarint;
export error InvalidTag;
export error UnknownWireType;
export error FieldNumberOverflow;
export error RecursionLimit;
export error BufferTooSmall;
export error InvalidBool;
export error MapTooMany;      // Phase 3：map 条目数超过 DemoStrIntMap 的 DEMO_STR_INT_MAP_MAX(16)
export error PbFieldMissing;  // pb_message_find_field 找不到字段
```

---

## 8. 编码器（Encoder）

### 8.1 API

```uya
// 当前实现（无泛型 encode<T>）：每个 message 一对「写缓冲区 / 写 arena」函数
export fn encode_demo_user_to(u: &DemoUser, buf: &byte, cap: usize) !usize;      // encode.uya:89
export fn encode_demo_user_into_arena(arena: &Arena, u: &DemoUser) !PbStrView;    // :116
export fn encode_demo_user_size(u: &DemoUser) usize;                             // :353（预计算长度）

// 设计稿期望但尚未实现：
// fn encode_to(value: &T, buf: &byte, cap: usize) !usize;
// fn encode(arena: &Arena, value: &T) !&[byte];
```

底层写入原语在 `encode.uya`：`pb_writer(buf, cap)`、`pb_w_varint_u64`、`pb_w_tag`、`pb_w_fixed32_u32`、`pb_w_fixed64_u64`。

### 8.2 编码流程

1. 按 field number 顺序（或用户指定）写入 tag + payload
2. 嵌套 message 先算长度，再 length-delimited 写入
3. repeated：每项单独 tag+payload，或 packed（wire_type 2）

### 8.3 宏或手写

- `impl_protobuf!` **当前不可用**（`impl_macro.uya` 不存在，编译器也没有对应宏展开），因此只有手写路径
- 手写形态：为每个 message 实现 `fn xxx_decode(arena, ptr, len) !Xxx` 与 `fn encode_xxx_to(u: &Xxx, buf, cap) !usize`（可选加 `encode_xxx_size`、`encode_xxx_into_arena`），参照 `lib/std/protobuf/demo.uya` 的示例 message 与 `decode.uya` / `encode.uya` 的实现
- 若将来支持宏，应生成同样的函数名形状，避免破坏现有测试

---

## 9. 模块与文件规划

```
lib/std/protobuf/
  protobuf.uya     # 模块入口：仅注释（无 export）
  wire.uya         # varint、zigzag、tag 拆分/校验、skip_field、fixed32/64（export fn + PB_WIRE_* 常量）
  errors.uya       # 10 个 export error（模块 std.protobuf.errors；避免文件名 error 与关键字冲突）
  impl.uya         # f32/f64 ↔ 位模式（memcpy）、pb_read_f32 / pb_read_f64
  demo.uya         # 手写示例 message：DemoUser / DemoInner / DemoOuter / DemoIntList / DemoInnerList /
                   #   DemoStrIntMap / DemoOneofMsg / DemoPaint / DemoOptScores + PbStrView / PbI32Strip
  decode.uya       # decode_demo_* 系列（含 _d 深度变体）
  encode.uya       # PbWriter、pb_w_*、encode_demo_*_to / _into_arena / _size
  dynamic.uya      # PbValue / PbField / PbMessage、decode_dynamic、pb_message_find_field
```

与设计稿的差异：**没有** `impl_macro.uya`（`impl_protobuf!` 未实现）；新增了设计稿未列的 `demo.uya`（示例 message 定义）与 `dynamic.uya`（Phase 4 动态解析）；`impl.uya` 只做位模式转换，不是“基础类型编解码”。

---

## 10. 依赖与约束

- **Arena**：与 std.json 共用
- **std.mem**：mem_copy 等
- **std.string**：UTF-8 校验（decode_strict 时）
- **泛型**：`decode<T>` 需 T 实现 ProtobufDecode 或等效约束（**未实现**：当前无泛型入口，见 §7.1）

---

## 11. 性能目标

| 阶段 | 解码目标 | 编码目标 |
|------|----------|----------|
| Phase 1 | 0.5–1.5 GB/s | 0.3–1 GB/s |
| Phase 2 | 0.3–1 GB/s | 0.2–0.8 GB/s |

- **吞吐量**：消息字节数 × 重复次数 / 总耗时，单线程、热缓存、中位数

---

## 12. 与主流库对比

| 实现 | 语言 | 解析 | 编码 |
|------|------|------|------|
| upb | C | 2.0–2.3 GB/s | ~0.6 GB/s |
| libprotobuf | C++ | 0.2–0.4 GB/s | ~1.3 GB/s |
| prost | Rust | 0.5–1.5 GB/s 量级 | 类似 |
| Go 官方 | Go | 0.1–0.3 GB/s | 类似 |
| Java Protobuf | Java | 0.05–0.2 GB/s | 类似 |

Uya 目标：Phase 1 接近 prost，力争 upb 的 1/2–2/3；明显优于 Go/Java。

---

## 13. 内嵌基准（`tests/bench_protobuf.uya`）

- **计时**：Linux x86-64 `gettimeofday` 微秒，吞吐按处理字节 × 轮次 / 耗时换算 **MB/s**（`MB_F = 1048576.0`），与 `bench_json` 一致。
- **场景**：128 B 负载上重复 **wire 扫描**（64×「field1 varint 1」）；**`DemoUser`** 与 `test_protobuf_encode_basic` 同构；**packed `DemoIntList`** 8×`i32` 与 repeated 测试对齐。
- **示例一次运行**（本地 Linux x86_64，2026-03-28，单线程，热缓存，非正式中位数）：
  - wire scan 80000×128 B → **~70 MB/s**
  - `decode_demo_user` 50000×18 B → **~137 MB/s**
  - `encode_demo_user_to` 50000×~18 B → **~138 MB/s**
  - `decode_demo_int_list` packed 40000×10 B → **~23 MB/s**
  - `encode_demo_int_list_packed_to` 50000×~10 B → **~48 MB/s**

优化 `@vector` / 热循环后可再执行 `./tests/build/bench_protobuf.bin`（需先由测试脚本编译出该二进制）对比更新上表。
