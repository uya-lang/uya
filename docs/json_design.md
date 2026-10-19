# Uya 高性能 JSON 编解码器设计文档

**版本**：v0.1

**状态**：设计阶段，部分已实现（见 [todo_json.md](todo_json.md)）

**最后核对**：2026-10-19，按 `lib/std/json/{value,parser,encoder,errors,macros}.uya` 与 `tests/test_json_*.uya` 回填

**参考**：RFC 8259、simdjson、[grammar_formal.md](grammar_formal.md)（语法规范）、[todo_json.md](todo_json.md)（实现待办）

---

## 1. 概述

本文档定义 Uya 标准库的 JSON 编解码器设计，基于 Uya 的零 GC、编译期证明、显式内存控制、切片零拷贝等特性，实现高性能 JSON 解析与编码，目标性能接近 C/Rust 高性能库（serde_json、simd-json 水平），明显优于 Go/Java 标准库。

### 1.1 设计目标

- **零拷贝**：字符串值直接引用输入 buffer，不复制
- **单次分配**：解析阶段使用 Arena，一次分配得到 Tape
- **显式内存**：API 要求调用方传入 Arena 或预分配 buffer
- **编译期序列化与反序列化**：宏 to_json、from_json 利用编译器反射实现自动结构体序列化/反序列化；**有宏之后结构体无需手写**。未提供宏或需细粒度控制时可手写；无运行时反射。
- **可选 SIMD**：Phase 4 **优先**用 `@vector`/`@mask` 加速 Stage 1 可向量化扫描（与当前标量 struct 回退共存；lowering 落地后自动获益）；**可选** Phase 5 用 `@asm`（AVX2/NEON）补充裸指令热点；标量路径始终可用

---

## 2. 设计原则（对齐 Uya 特性）

| Uya 特性 | JSON 设计应用 |
|----------|---------------|
| 零 GC / 显式内存 | 解析器使用 Arena 单次分配，编码器接受预分配 buffer 或 Arena |
| 编译期证明 | 结构体 ↔ JSON 由编译器反射宏 to_json / from_json 自动生成，**结构体无需手写**；无宏时可手写，零反射 |
| 错误联合 `!T` | `parse()` 返回 `!JsonValue`；编码当前为 `encode_to` 返回 `!usize`、`encode_into_arena` 返回 `!JsonStrView`（避免 slice 返回值） |
| 指针 / 视图 | 字符串用 `JsonStrView`(ptr+len)；理想为 `&[byte]`，受 slice codegen 限制当前用 ptr+len |
| 无隐式分配 | API 显式要求传入 `&Arena` 或 buffer 容量 |
| `@vector`/`@mask`、`@asm` | Phase 4 以 `@vector`/`@mask` 为主做结构扫描加速；可选 `@asm`（AVX2/NEON）补充；与标量路径、`@asm_target()`/`std.cfg` 选路配合 |

---

## 3. JSON 标准范围

- **遵循**：RFC 8259 核心（对象、数组、字符串、数字、布尔、null）
- **支持**：`\uXXXX`、`\n\t\r\"\\` 转义
- **不支持**：注释、尾逗号、单引号
- **UTF-8**：默认不校验（零拷贝优先）；可选 `parse_strict` 启用 UTF-8 校验
  - **核对（2026-10-19）**：`parse_strict` **未实现**（`grep -rn parse_strict lib tests` 无命中）。`errors.uya:4` 定义了 `InvalidUtf8`，但目前只有 `errors` 层面上存在，解析器不会主动抛它。

---

## 4. 整体架构

```mermaid
flowchart TB
    subgraph Parse [解析流程]
        A[Input: &[byte]] --> B[Stage1: 结构扫描]
        B --> C[Stage2: 构建 Tape]
        C --> D[JsonValue]
    end
    
    subgraph Encode [编码流程]
        E[结构化数据] --> F[ToJson / mc 宏生成或手写]
        F --> G[JsonWriter]
        G --> H[Output: &[byte]]
    end
    
    subgraph Memory [内存]
        I[Arena] --> J[parse 分配]
        K[调用方 buffer] --> G
    end
```

结构体序列化由编译器反射宏（`encode_to_to_json` / `to_json_reflect()`）在 `to_json<T>` 单态展开时生成，或调用方手写「按字段调用 `json_write_*`」的代码；当前未定义 `ToJson` / `FromJson` 接口（见 §7.1）。

---

## 5. 核心数据结构

**语法依据**：[grammar_formal.md](grammar_formal.md) 联合体、结构体、指针类型。Uya 指针为 `&T` / `&const T`；联合体变体需为合法标识符（避免关键字 `null`）。

### 5.1 JsonValue（零拷贝值类型）

```uya
// lib/std/json/value.uya:10-19（全部为 export）
union JsonValue {
    json_null: void,        // 对应 JSON null；不用 null 避免与关键字冲突
    bool_val: bool,
    int_val: i64,
    float_val: f64,
    num_text: JsonStrView,  // 保留原始数字文本（parse_lossless_numbers 产生，供 f64 无损还原）
    str: JsonStrView,       // 当前实现用 (ptr, len) 视图，规避 slice codegen；理想为 &[byte]
    arr: JsonArray,
    obj: JsonObject,
}

struct JsonStrView {
    ptr: &byte,
    len: usize,
}

struct JsonArray {
    items: &JsonValue,  // Arena 分配
    len: usize,
}

struct JsonKeyValue {
    key: JsonStrView,
    value: JsonValue,
}

struct JsonObject {
    pairs: &JsonKeyValue,  // Arena 分配
    len: usize,
}
```

以上 `JsonStrView`(`value.uya:5`)、`JsonArray`(`:21`)、`JsonKeyValue`(`:26`)、`JsonObject`(`:31`) 在实现中均为 `export struct`；`JsonArray.items` / `JsonObject.pairs` 指向 Arena 内的连续数组。

### 5.2 JsonParser（可选，当前解析器未暴露此结构体）

```uya
struct JsonParser {
    input: &[byte],     // 理想形态；当前 parse 使用 (ptr, len) 以规避 slice 参数
    tape: &JsonValue,
    tape_len: usize,
    arena: &Arena,
}
```

### 5.3 访问方式

- `JsonValue` 通过 `match` 访问变体
- 数组：`arr.items[i]`（需证明 `0 <= i < arr.len`）
- 对象：`obj.pairs[i].key`、`obj.pairs[i].value`
- 反序列化见 §7.4（FromJson / from_json）

---

## 6. 解析器（Decoder）

### 6.1 两阶段解析

1. **Stage 1**：扫描结构字符 `{ } [ ] , : "`，构建结构索引（可选 SIMD：**优先 `@vector`/`@mask`**；可选 `@asm` 补充；标量路径始终可用）
2. **Stage 2**：按需或一次性填充 Tape，所有指针指向 `input` 或 `arena`
3. **数值解析**：手写整数/浮点解析（避免 strtod FFI），溢出/NaN/Inf 返回错误

### 6.2 API

```uya
// 当前实现（lib/std/json/parser.uya:367、:371）：用 (ptr, len) 替代 &[byte] 以规避 slice codegen
fn parse(arena: &Arena, ptr: &byte, len: usize) !JsonValue;

// 保留数字原文到 JsonValue.num_text（不做 i64/f64 归一），供需要原样回写的场景；
// f64 提取时由 json_expect_f64 走 strtod 还原（encoder.uya:337-346）。
export fn parse_lossless_numbers(arena: &Arena, ptr: &byte, len: usize) !JsonValue;

// 理想 API（待 slice 支持后）
// fn parse(arena: &Arena, input: &[byte]) !JsonValue;

// 懒解析（可选，未实现）
// fn parse_lazy(arena: &Arena, input: &[byte]) !JsonDoc;
// fn json_doc_get(doc: &JsonDoc, path: &const byte) !JsonValue;
```

`parse_lossless_numbers` 已落地并有测试覆盖：`tests/test_json_parse_float.uya:71,98`。

### 6.3 错误类型

语法规范（[grammar_formal.md](grammar_formal.md)）：预定义错误为 `error ID ;`，单条声明。模块名用 `errors` 以免与关键字 `error` 冲突。

```uya
// lib/std/json/errors.uya
export error InvalidUtf8;
export error InvalidEscape;
export error InvalidUnicode;
export error UnexpectedToken;
export error UnexpectedEof;
export error NumberOverflow;
export error InvalidNumber;
export error NestingTooDeep;
export error BufferTooSmall;
// from_json 用
export error NotAnObject;
export error MissingField;
export error WrongType;
```

### 6.4 数值策略

- 整数：`i64`，超出范围报 `NumberOverflow`
- 浮点：`f64`，NaN/Inf 报 `InvalidNumber`

---

## 7. 编码器（Encoder）

### 7.1 ToJson 接口（设计稿；**当前代码中不存在**）

> **核对结论（2026-10-19）**：`grep -rn "interface ToJson" lib/ src/` 无命中，`lib/std/json/` 下也没有 `impl.uya`。现行实现走的是**泛型单态 + 编译期反射宏**，不需要结构体实现接口：`to_json<T>(arena, obj)` 在调用点由 `encode_to_to_json(T, &obj, buf, cap)` 宏（`macros.uya:43`）按类型 `T` 展开编码代码。下方接口只作为备选的未来形态保留。

```uya
interface ToJson {
    fn to_json(self: &Self, writer: &JsonWriter) void;
}
```

若将来引入该接口，接口类型直接写成 `ToJson`（Uya 无 `impl` 关键字，见 [grammar_formal.md](grammar_formal.md)）。注意 `lib/std/json/json.uya:14-17` 的模块注释里仍保留 `encode_into_arena_for_to_json` / `ToJson` 的旧描述，属于待清理的过期注释。

### 7.2 API

```uya
// 均为 export；行号为 2026-10-19 的 lib/std/json/encoder.uya
fn encode_to(v: &JsonValue, buf: &byte, cap: usize) !usize;              // :243，BufferTooSmall
fn encode_into_arena(ar: &Arena, v: &JsonValue) !JsonStrView;            // :255
fn encode(ar: &Arena, v: &JsonValue) !&[byte];                          // :263
fn to_json<T>(ar: &Arena, obj: T) !&[byte];                             // :269，结构体→JSON 字节（arena 分配）
fn from_json<T>(ar: &Arena, buffer: &[byte]) !T;                        // :284，先 parse 再按 T 内联解码
fn parse(arena: &Arena, ptr: &byte, len: usize) !JsonValue;             // parser.uya:367
```

要点：

- `to_json` / `from_json` 都是**泛型函数**，实参是 `T`（按值）与 `&[byte]`，不是 `&ToJson`。
- `encode_to` / `encode_into_arena` / `encode` 只接受 `&JsonValue`，注释里明确写着“供测试与兼容用；结构体请用 to_json”。
- 编码缓冲区固定为 `ENCODE_ARENA_MAX = 65536`（`encoder.uya:252`），单次编码超过该长度返回 `error.BufferTooSmall`；因此 arena 需要预留足够空间（`tests/test_json_struct_roundtrip.uya:46` 用 256 KiB 跑两次 `to_json` + `parse`）。

### 7.3 结构体序列化（to_json）

**骨架宏 to_json_skeleton**：`use std.json.macros.to_json_skeleton`，在方法块内 `to_json_skeleton({ ... })` 生成 to_json 方法（仅负责开头/结尾的 `{` `}`，中间由调用方填写）。**反射宏 to_json_reflect**：`use std.json.macros.to_json_reflect`，在方法块内无参调用 `to_json_reflect()`，由编译器按结构体字段自动生成 to_json（支持 i64、i32、f64、bool、JsonStrView）。未用宏时可手写「按字段写 `json_write_key` / `json_write_*`」的语句。

注意：现行最优路径已不是接口方法，而是 `to_json<T>(arena, obj)` 的**单态展开**——编译器 `build_encode_to_to_json_block` 按类型 `T` 的字段直接生成 `json_write_*` 调用序列（`src/checker/macro_expand.uya` 的 `build_json_write_value_stmt`），因此结构体不必声明任何方法块。测试见 `tests/test_json_to_json_reflect.uya`、`tests/test_json_struct_roundtrip.uya`。

### 7.4 结构体反序列化（from_json）

- **目标 API**：`from_json(arena: &Arena, input: &[byte]) !T`（字节→T）。库侧提供 `parse(arena, ptr, len) !JsonValue`；类型 T 的 from_json 由用户实现：先 `parse(arena, &input[0], @len(input))` 再按 T 从 JsonValue 提取（如 `user_from_json(arena, &v)`）。
- **FromJson 形态**：`fn from_json(arena: &Arena, v: &JsonValue) !Self`（从 JsonValue 对象变体按字段名解析并填充结构体，失败返回错误）。
- **宏 from_json 利用编译器反射实现自动结构体反序列化；有宏之后结构体无需手写**。未提供宏或需细粒度控制时可手写。与 to_json 对称，实现 roundtrip。
- **手写辅助**：`json_object_find_index(o, key_ptr, key_len) !usize`；`json_expect_i64(v) !i64`、`json_expect_str(v) !JsonStrView`、`json_expect_bool(v) !bool`、`json_expect_f64(v) !f64`（类型不符返回 WrongType；f64 接受 int_val 自动转 float）；`json_str_view_eq`。调用方在同一作用域内用 `o.pairs[idx].value`，不返回/存储 `&JsonValue`（零 UB）。
- **当前实现细节**：`from_json<T>`（`encoder.uya:284`）先 `parse` 再调用 `fn __decode_json<T>(ar, &JsonValue) !T`（`encoder.uya:277`），该函数体由 codegen 在单态实例处内联替换；`ar` 参数主要为对齐签名，现有解码路径不改写 arena。

---

## 8. 模块与文件规划

```
lib/std/json/
  json.uya          # 模块入口：仅注释（无 export），注释里的 ToJson 描述已过期
  value.uya         # JsonValue、JsonStrView、JsonArray、JsonObject、JsonKeyValue（export struct/union）
  errors.uya        # 12 个 export error（命名 errors 避免与关键字 error 冲突，见 grammar）
  parser.uya        # parse / parse_lossless_numbers + 解析逻辑（含 skip_ws / 字符串 / 数字的 @vector 块扫描）
  encoder.uya       # JsonWriter、encode_to、encode_into_arena、encode、to_json<T>、from_json<T>、json_expect_*
  macros.uya        # to_json_skeleton(body)、to_json_reflect()、from_json_reflect()、encode_to_to_json(T, ...)
```

与设计稿的差异：`impl.uya` **不存在**（基础类型的 ToJson 实现改为 `to_json<T>` 单态展开）；`json.uya` 不重导出任何符号，子模块必须逐个 `use std.json.<sub>.<name>`。

---

## 9. 依赖与约束

- **Arena**：依赖 `src/arena.uya` 或新增 `std.mem.arena`；若无则退化为 libc
- **std.mem**：mem_copy 等
- **std.string**：UTF-8 校验（可选）
- **SIMD**：Phase 4 可选（**优先 `@vector`/`@mask`**，可选 Phase 5 `@asm`），标量路径必须能独立工作

---

## 10. 性能目标

| 阶段 | 目标 | 参考 |
|------|------|------|
| Phase 1（标量） | 0.2–0.5 GB/s | serde_json / RapidJSON |
| Phase 4（SIMD / `@vector` 为主，可选 `@asm`） | 1–3 GB/s | simd-json / sonic-rs |
| 编码 | 0.3–1 GB/s | 编译期 mc 宏或手写 to_json，无反射 |

### 10.1 Benchmark 方案

- **数据集**：twitter.json、citm_catalog.json、canada.json（可选：`tests/scripts/fetch_json_benchmark_data.sh` 下载至 `tests/data/json/`；`tests/bench_json.uya` 当前为内嵌小负载）
- **方法**：单线程、热缓存、多次运行取中位数，单位 GB/s

---

## 11. 与其他语言库对比

| 语言/库 | 解析吞吐量 |
|---------|------------|
| C++ simdjson | 4–14 GB/s |
| Rust simd-json | 0.7–1.2 GB/s |
| Rust serde_json | 0.3–0.9 GB/s |
| C++ RapidJSON | 0.3–0.9 GB/s |
| Go encoding/json | ~0.1–0.3 GB/s |
| Java Jackson | ~0.05–0.2 GB/s |

Uya 设计目标：Phase 1 接近 RapidJSON；Phase 4 以 `@vector`/`@mask`（及可选 `@asm`）使 Stage 1 吞吐接近 simd-json；`@vector` 真实 lowering 落地后同一代码路径进一步获益；整体性能应明显优于 Go/Java。
