# Uya JSON 编解码器实现待办

**参考**：[json_design.md](json_design.md)（设计与语法对齐 [grammar_formal.md](grammar_formal.md)）

**最后核对**：2026-10-19，按 `lib/std/json/{value,parser,encoder,errors,macros}.uya` 与 `tests/test_json_*.uya`、`tests/bench_json.uya` 逐条回填。

### 总体状态

| Phase | 状态 | 依据 |
| --- | --- | --- |
| Phase 1 标量解析器 | 完成 | `parser.uya:367` `parse`、`:371` `parse_lossless_numbers`；`test_json_parse_*.uya` 6 个测试（另有 `test_json_value` / `test_json_roundtrip` 等，`test_json_*.uya` 共 26 个） |
| Phase 2 编码器 | 完成 | `encoder.uya:243/255/263/269`；`test_json_encode_*.uya` 6 个测试 |
| Phase 3 结构体序列化/反序列化 | 完成 | `macros.uya` 四个宏 + 编译器 `build_encode_to_to_json_block`；`test_json_struct_*` / `from_json_*` / `to_json_*` 等 |
| Phase 4 SIMD | **部分回退** | 只有 `encoder.uya:171-196` 仍在用 `@vector`；parser 三个热点已在 `e086e88d` 改回标量 |
| Phase 5 `@asm` | 未开始 | 仓库内无 `@asm` JSON 热点 |

实现时遵循项目 TDD 流程：先添加测试 → 实现代码 → `make check` 验证。

---

## Phase 1：基础解析器（标量）

### 1.1 前置依赖

- [x] 确认 Arena 可用性：已实现 `lib/std/mem/arena.uya`（仅缓冲区 bump，无 malloc）
- [x] `arena_init`/`arena_alloc`/`arena_reset` 可用

### 1.2 数据结构

- [x] 创建 `lib/std/json/` 目录
- [x] `errors.uya`：Json 错误（InvalidUtf8、InvalidEscape、InvalidUnicode、UnexpectedToken、UnexpectedEof、NumberOverflow、InvalidNumber、NestingTooDeep）
  - 现状（2026-10-19 核对，`lib/std/json/errors.uya:4-16`）：共 12 个 `export error`，上述 8 个之外还有 `BufferTooSmall`（编码/arena 不足），以及 Phase 3 为手写 `from_json` 增加的 `NotAnObject`、`MissingField`、`WrongType`
- [x] `value.uya`：`JsonValue` union、`JsonStrView`、`JsonArray`、`JsonKeyValue`、`JsonObject`
  - 现状：`JsonValue`（`value.uya:10`）实为 8 个变体，除设计稿列的 7 个外还有 `num_text: JsonStrView`（供 `parse_lossless_numbers` 保留数字原文）

### 1.3 标量解析器

- [x] `parser.uya`：实现 `parse(arena, ptr, len) !JsonValue`（API 用 ptr+len 替代 `&[byte]` 以规避 slice codegen）
  - [x] 空白跳过、null/true/false、整数(i64)/浮点(f64)、字符串(JsonStrView)、数组、对象
  - [x] 转义 `\n\t\r\"\\`、`\uXXXX`
  - [x] codegen 已修复：err_union 的 union payload（如 `!JsonValue`）会先 emit union 定义、错误返回用 `(payload_c){0}` 初始化；i64 字面量用 `number_value_i64` 避免截断

### 1.4 测试

- [x] `tests/test_json_value.uya`：仅测试 JsonValue 构造与 match（通过）
- [x] `tests/test_json_parse_basic.uya`：null、bool、整数、浮点 3.0、字符串
- [x] `tests/test_json_parse_float.uya`：浮点数 3.14、-1.5、科学计数法 1e2
- [x] `tests/test_json_parse_array.uya`：空数组、[1,2]、嵌套数组
- [x] `tests/test_json_parse_object.uya`：空对象、{\"a\":1}、嵌套对象
- [x] `tests/test_json_parse_invalid.uya`：预期解析失败用例（非法 JSON 需返回 error）
- [x] `tests/test_json_parse_string.uya`：字符串解析与转义（`"abc"`、`"a\nb"`、`""`）
- [x] `tests/test_json_roundtrip.uya`：parse → encode_to → parse 往返（对象 `{"x":1}`、数组 `[1,2]`）

---

## Phase 2：编码器（基础类型）

### 2.1 JsonWriter

- [x] `encoder.uya`：`JsonWriter` 结构体（`encoder.uya:38-43`：buf、cap、used、overflow）
- [x] 内部连续写入辅助 `json_buf_write_bytes`（`encoder.uya:53`）：单次 `used + len` 容量检查后连续拷贝（不是逐字节 `write_byte`）；配合 `json_write_str_view` 的 16 字节 `@vector` 段使用
- [x] `json_write_null`、`json_write_bool`、`json_write_i64`、`json_write_f64`（均为 export）
- [x] `json_write_str_view`（转义 `\"\\\n\r\t`）+ `json_write_key`（键 + 冒号，供反射宏使用）
- [x] `json_write_value`（`encoder.uya:238`，**私有** `fn`）递归写入 JsonValue（含数组、对象）；对外只暴露 `encode_to` / `encode_into_arena` / `encode`

### 2.2 基础类型 ToJson

- [x] 通过 `json_write_value` 统一处理 JsonValue，未单独做 ToJson 接口（可后续加 `impl.uya`）

### 2.3 API

- [x] `encode_to(v: &JsonValue, buf, cap) !usize`（缓冲区不足返回 error.BufferTooSmall）
- [x] `encode_into_arena(arena, v) !JsonStrView`（在 arena 中编码并返回 ptr+len 视图，等价语义，避免 `!&[byte]` 的 slice 返回值）
- [x] `encode(arena, value) !&[byte]`（已实现：依赖 slice 返回值 + 指针作切片 base；见 test_json_encode_slice.uya）
- ~~`encode_into_arena_for_to_json(arena, value: &ToJson) !JsonStrView`~~ —— **条目作废（2026-10-19 核对）**：该函数**不存在**，`grep -rn encode_into_arena_for_to_json` 全仓库只命中 `lib/std/json/json.uya:14` 的一句过期模块注释。实际实现走泛型 `to_json<T>(arena, obj) !&[byte]`（`encoder.uya:269`），不需要 `ToJson` 接口，因此既不是已完成项也不是待办项。

### 2.4 测试

- [x] `tests/test_json_encode_long_str.uya`：长 ASCII 字符串与「向量段末遇换行」编码
- [x] `tests/test_json_encode_basic.uya`：null、bool、数字、字符串编码
- [x] `tests/test_json_encode_array.uya`：空数组、[1,2]
- [x] `tests/test_json_encode_object.uya`：空对象、{\"a\":1}
- [x] `tests/test_json_encode_arena.uya`：encode_into_arena 返回 JsonStrView
- [x] `tests/test_json_encode_slice.uya`：encode(arena, value) 返回 &[byte]，@len 与内容校验

---

## Phase 3：结构体序列化/反序列化

### 3.1 宏（编译器反射）或手写

- [x] 宏 to_json_skeleton：`lib/std/json/macros.uya`，方法块内 `to_json_skeleton({ ... })` 生成 to_json 骨架（开头/结尾 `{` `}` 由宏生成）。
- [x] 完整反射 to_json：`to_json_reflect()` 宏（方法块内无参调用），编译器按结构体字段自动生成 to_json；支持字段类型 i64、i32、f64、bool、JsonStrView；测试见 `tests/test_json_to_json_reflect.uya`。
- [x] **encode_to_to_json 宏 / to_json 单态展开**：库侧宏占位体，编译器 `build_encode_to_to_json_block` 按类型名生成编码块；单态体经 `prepare_mono_body_expand_macros` 展开；`to_json<T>(arena, obj)` 已可用，并支持嵌套结构体、定长数组、切片，以及结构体元素数组/切片；测试见 `test_json_to_json_reflect`、`test_json_nested`、`test_json_array`、`test_json_struct_collections`。
- [x] **宏 from_json**：单态 `from_json<T>(arena, buffer)` 当首类型实参为结构体时自动生成合成 body（parse + 按字段解码），无需方法块；已支持标量、嵌套结构体、定长数组与切片字段 `&[T]`，以及结构体元素数组/切片。手写时可用 `json_object_find_index`、`json_expect_*`。
- [x] **from_json 反射支持嵌套/数组/切片**：`build_decode_struct_expr` / `build_from_json_reflect_body` 已支持嵌套结构体、定长数组与切片字段，且数组/切片元素可递归解码为结构体；C99 后端已补齐 `try match` 的 payload 推断与 `err_union` 预注册，避免 `from_json` 反射在 codegen 阶段漏发错误联合定义。

### 3.2 测试

- [x] `tests/test_json_struct_roundtrip.uya`：结构体 → `encode_to_to_json` → 校验输出字节 → **parse 端到端**（再解析为 JsonValue 校验 id/name）
- [x] 结构体 roundtrip 含「parse → from_json → 结构体 → to_json → parse」，验证有宏时无需手写、无宏时手写 to_json/from_json 对称（见 `test_json_struct_roundtrip.uya`）。
- [x] `tests/test_json_from_json_errors.uya`：json_object_find_index 缺 key 返回 error.MissingField。
- [x] `tests/test_json_from_json_wrong_type.uya`：from_json 字段类型不匹配时返回 error.WrongType。
- [x] `tests/test_json_from_json_reflect.uya`：`from_json<T>` 反射往返（User、Record 等标量/多字段结构体，严格长度检查）。
- [x] `tests/test_json_from_json_slice.uya`：`from_json<T>` 反射支持 `&[i64]` 切片字段，并验证 roundtrip。
- [x] `tests/test_json_struct_collections.uya`：`to_json<T>` / `from_json<T>` 反射支持 `[Point: N]` 与 `&[Point]` 这类结构体元素数组/切片，并验证 parse + roundtrip。
- [x] `errors.uya`：新增 WrongType，手写 from_json 时用于字段类型不符。
- [x] `encoder.uya`：新增 json_expect_i64/str/bool/f64(v)，手写 from_json 时减少 match 样板；f64 接受 int_val 自动转 float。
- [x] `tests/test_json_expect_helpers.uya`：覆盖四种 expect 辅助及类型不符时 WrongType。

---

## Phase 4：SIMD 加速（可选，优先 `@vector`/`@mask`）

Stage 1 结构字符扫描等可向量化环**优先用 `@vector`/`@mask` 实现**，与当前 C99 标量 struct 回退语义一致；**真实 SIMD lowering** 落地后同一路径自动获益。标量路径必须始终保留。

> **核对结论（2026-10-19）：`@vector` 在解析器里已被回退，只剩编码器在用。**
> `skip_ws` / `parse_string` / 对象键 / `parse_number` 的 16 字节块扫描曾于 `10bc8b92`（skip_ws，规范 0.49.33）与 `cdb39a07`（parse_string/parse_number/对象键）落地，随后被 `e086e88d` 全部改回标量循环。
> 现状：`lib/std/json/parser.uya:41`（skip_ws）、`:81`（skip_ascii_digits_vec16）、`:88`（skip_string_unescaped_run_vec16）均为纯标量 `while` 循环（函数名仍带 `_vec16` 后缀但已无向量代码），`parser.uya:17-18` 的 `JsonWsVec16` / `JsonWsMask16` 类型别名成为未使用的残留；`lib/std/json/encoder.uya:176-179` 的 `json_write_str_view` 仍是真正的 `@vector.load` 块扫描。
> 下面三条因此从 `[x]` 改为 `[ ]`，作为“恢复向量路径”的待办保留。

- [ ] 在 **`skip_ws`** 中恢复 **`@vector(u8,16)`/`@mask(16)`** 块扫描（曾在 **0.49.33**/`10bc8b92` 落地，`e086e88d` 回退为标量；剩余不足 16 字节或块内非全空白时回退标量循环）
- [ ] 其余热点（**`parser.uya`**）：**`parse_string`** / **对象键**扫描在不含 **`"`** / **`\\`** 的连续段上用 **`@vector(u8,16)`** 块推进；**`parse_number`** 在 ASCII 数字连续段上用同宽块推进（曾在 `cdb39a07` 落地，`e086e88d` 以「debug C 后端下标量扫描开销更低」为由回退）
- [x] 编码器 `json_write_str_view`：连续段无 `"` `\` `\n` `\r` `\t` 时用 `@vector(u8,16)` 块 + `json_buf_write_bytes`（与 parser 对称）；测试 `tests/test_json_encode_long_str.uya` —— **仍是当前唯一生效的 `@vector` 路径**（`encoder.uya:171-196`）
- [ ] 运行时 CPU 检测或编译期 `@asm_target()`/`std.cfg` 选路，选择标量或向量路径（**当前**：`grep -rn "asm_target\|std.cfg" lib/std/json` 无命中，解析器已是纯标量，不做选路；若恢复 parser 向量路径再考虑 `std.cfg` 拆分）
- [x] Benchmark：**`bench_json`** 用 **`@syscall(gettimeofday)`** 墙钟微秒计时的 **MB/s**；含紧凑 JSON、**前导空白**、**长字符串** 三类 parse 负载，便于观察 **`skip_ws`/`parse_string`** 等 `@vector` 路径；与「纯标量解析器」二分对比需单独构建/开关（仍可选）

### Phase 5（可选）：`@asm` 补充（AVX2/NEON）

当仍存在需裸指令或手工调优的片段时，可**额外**保留 `@asm` 分支；与 Phase 4 的 `@vector` 路径并存，benchmark 可三者对比。

- [ ] （可选）AVX2/NEON `@asm` 热点补充
- [ ] （可选）Benchmark 纳入 `@asm` 路径

---

## Benchmark

- [x] 标准大文件样本（可选）：`tests/scripts/fetch_json_benchmark_data.sh` 从 simdjson `jsonexamples` 拉取 twitter/canada/citm_catalog 至 `tests/data/json/`（`*.json` 已 `.gitignore`）；`bench_json` 仍以内嵌负载为主，本地可自行接读入
- [x] 编写 `tests/bench_json.uya`：内嵌 JSON 负载，parse/encode 循环 + **墙钟微秒**测时；打印 **usec** 与 **MB/s**（`USEC_PER_SEC=1_000_000`）；含 **紧凑** / **前导空白** / **长字符串** 三类 parse 场景
- [x] 记录 Phase 1 基准：运行 `./tests/build/bench_json` 或程序测试 `bench_json.uya` 可见各场景吞吐；Phase 5 `@asm` 落地后可再对比

---

## 与主待办集成

- [x] 已在 [todo_mini_to_full.md](todo_mini_to_full.md) 第 38 项添加 **std.json** 条目
- [x] 已在 [todo_mini_to_full.md](todo_mini_to_full.md) 增加 SIMD 语言内建 `@vector(T, N)` / `@mask(N)` 的长期路线
- [x] 说明已统一：`std.json` Phase 4 优先 `@vector`/`@mask`，可选 Phase 5 `@asm` 补充；与 SIMD 总路线图（仓库 `.cursor/plans/simd设计路线_8b80f4bb.plan.md`）阶段 3/4 对齐
