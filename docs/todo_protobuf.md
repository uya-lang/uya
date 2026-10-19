# Uya Protobuf 编解码器实现待办

**参考**：[protobuf_design.md](protobuf_design.md)

**最后核对**：2026-10-19，按 `lib/std/protobuf/{wire,impl,demo,decode,encode,dynamic,errors}.uya` 与 `tests/test_protobuf_*.uya`（10 个）、`tests/bench_protobuf.uya` 逐条回填。

### 总体状态

| Phase | 状态 | 依据 |
| --- | --- | --- |
| Phase 1 Wire + 基础类型 | 完成 | `wire.uya`、`errors.uya`、`impl.uya`、`demo.uya`、`decode.uya:36`、`encode.uya:89` |
| Phase 2 嵌套 + repeated | 完成 | `decode_demo_outer(_d)`、`decode_demo_inner_list`、packed/unpacked 编码 |
| Phase 3 map / oneof / enum / optional | 完成 | `demo.uya:44-78` + `decode.uya:395/442/490/516` + `encode.uya:249/304/335/342` |
| Phase 4 动态解析 | 完成 | `dynamic.uya:86` `decode_dynamic`、`:120` `pb_message_find_field` |
| 泛型 `decode<T>` / `impl_protobuf!` 宏 | **未实现** | 无 `impl_macro.uya`；所有编解码均为 `xxx_<type>` 手写函数 |
| Benchmark | 完成 | `tests/bench_protobuf.uya`；数据见 `protobuf_design.md` §13 |

实现时遵循项目 TDD 流程：先添加测试 → 实现代码 → `make check` 验证。

---

## Phase 1：Wire 层 + 基础类型

### 1.1 前置依赖

- [x] Arena：`std.mem.arena` 已与 std.json / std.yaml 等共用（`arena_alloc` / `arena_reset`）
- [x] `std.mem.mem_copy` 等基础例程（见 `lib/std/mem/mem.uya`）

### 1.2 Wire 层

- [x] 创建 `lib/std/protobuf/` 目录
- [x] `errors.uya`：TruncatedInput、InvalidVarint、InvalidTag、UnknownWireType、FieldNumberOverflow、RecursionLimit、BufferTooSmall、InvalidBool（模块名 **`errors`**，避免与关键字 `error` 冲突）
  - 现状（2026-10-19 核对，`lib/std/protobuf/errors.uya:4-13`）：实为 **10 个** `export error`，另有 Phase 3 增加的 `MapTooMany`（map 条目超 `DEMO_STR_INT_MAP_MAX`）与 `PbFieldMissing`（`pb_message_find_field` 未命中）
- [x] `wire.uya`：varint 读、tag 拆分/校验、`skip_field`、fixed32/fixed64 读、zigzag（sint32/sint64）
- [x] `encode.uya`：`PbWriter` + varint/tag/fixed 写（与 wire 对称）

### 1.3 基础类型编解码

- [x] `impl.uya`：f32/f64 与 u32/u64 位模式（`memcpy`，避免 union 与 err_union C 生成冲突）、`pb_read_f32`/`pb_read_f64`
- [x] string/bytes：`DemoUser.name` 为 `PbStrView`（length-delimited，零拷贝指向输入）
- [x] proto3 默认值：`decode_demo_user` 缺省 id=0、name len=0、active=false

### 1.4 单层 message

- [x] `decode.uya`：`decode_demo_user(arena, ptr, len) !DemoUser`（手写示例；未知 field 跳过）
- [x] `encode.uya`：`encode_demo_user_to`、`encode_demo_user_into_arena`（Arena 分配输出）、`encode_demo_user_size`
- [ ] 泛型 `decode<T>` / 宏 `impl_protobuf!`（延至后续）
  - 2026-10-19 核对：仍**未实现**。`lib/std/protobuf/` 无 `impl_macro.uya`，编译器侧也无 `impl_protobuf` 宏展开；每个 message 都必须手写 `decode_xxx` / `encode_xxx_to`。目前仓库中唯一的 message 定义是 `lib/std/protobuf/demo.uya` 里的 9 个 Demo* 结构体。

### 1.5 测试

- [x] `tests/test_protobuf_wire.uya`：varint、zigzag、tag、fixed、float 位模式
- [x] `tests/test_protobuf_decode_basic.uya`：单层 message，标量 + string 视图
- [x] `tests/test_protobuf_encode_basic.uya`：encode ↔ decode roundtrip（含负 int64 varint）
- [x] `tests/test_protobuf_decode_errors.uya`：截断 varint、超长 varint、field 0、非法 bool

---

## Phase 2：嵌套与 repeated

### 2.1 嵌套 message

- [x] 递归 decode：`decode_demo_outer` / `decode_demo_inner_d`（子 message 为 length-delimited）
- [x] 嵌套深度：`wire.PB_MAX_NEST_DEPTH`（64），超界 `RecursionLimit`

### 2.2 repeated

- [x] repeated int32：`DemoIntList` + `decode_demo_int_list`（合并 field 1 的 VARINT 与 LEN packed 载荷）
- [x] repeated message：`DemoInnerList` + `decode_demo_inner_list`（Arena 分配 `PbI32Strip`，与 `DemoInner` 单字段布局一致）
- [x] packed 编码：`encode_demo_int_list_packed_to`；解析与多次非 packed 写入合并

### 2.3 测试

- [x] `tests/test_protobuf_nested.uya`
- [x] `tests/test_protobuf_repeated.uya`
- [x] `tests/test_protobuf_packed.uya`

---

## Phase 3：高级特性

- [x] map（wire 等价 repeated message）
- [x] oneof（union + tag）
- [x] enum（varint）
- [x] optional
- [x] 测试：`tests/test_protobuf_map.uya`、`test_protobuf_oneof.uya`
  - 覆盖明细（2026-10-19 核对）：`test_protobuf_map.uya` 覆盖 `DemoStrIntMap`；`test_protobuf_oneof.uya` 同时覆盖 oneof（`DemoOneofMsg`）、enum（`DemoPaint` / `DemoColor_*`）与 optional（`DemoOptScores`）——即 Phase 3 四类特性都落在上面两个测试里，没有单独的 `test_protobuf_enum.uya` / `test_protobuf_optional.uya`

---

## Phase 4：动态解析（可选）

- [x] `PbValue`、`PbField`、`PbMessage` 结构（`dynamic.uya`；`PbValue` 为扁平 kind + 载荷，对齐 C 后端）
- [x] `decode_dynamic(arena, ptr, len) !PbMessage`（两遍扫描：计数字段 + Arena 填充）
- [x] 非法 wire type 与 typed 路径一致，由 `wire` 层报错（动态解析不吞未知 wire）
- [x] 与 typed decode 共用 `wire`（`pb_read_varint_u64`、`pb_skip_field`、`pb_read_fixed32_u32` / `pb_read_fixed64_u64` 等）
- [x] 测试：`tests/test_protobuf_dynamic.uya`

---

## Benchmark

- [x] **数据集**
  - [x] 内嵌小 message 字节（与 `test_protobuf_encode_basic` / `test_protobuf_packed` 对齐），便于 CI 稳定对比
  - [ ] 可选：`protocolbuffers/protobuf` 仓库内 benchmark 用例、或教程 **addressbook** 生成的二进制样本，放 `tests/data/protobuf/`（大文件可 `.gitignore`，本地脚本拉取/生成）
- [x] **实现**：`tests/bench_protobuf.uya`，对齐 `tests/bench_json.uya`——`@syscall(gettimeofday)` 墙钟微秒、decode 每轮 **`arena_reset`**、打印 **usec** 与 **MB/s**（`MB_F = 1048576.0`）；分节：**wire tag/varint 扫描**、**DemoUser encode/decode**、**packed `DemoIntList` encode/decode**
- [x] **记录**：见 `docs/protobuf_design.md` §13（示例一次运行数据；换机/优化后请重跑 `./tests/build/bench_protobuf.bin` 更新）

---

## 与主待办集成

- [x] 已在 [todo_mini_to_full.md](todo_mini_to_full.md) 第 40 项添加 **std.protobuf** 条目
