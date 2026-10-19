# Uya YAML 编解码器实现待办

**参考**：[yaml_design.md](yaml_design.md)

**最后核对**：2026-10-19，按 `lib/std/yaml/{value,parser,encoder,errors,convert,impl}.uya` 与 `tests/test_yaml_*.uya`（17 个）逐条回填。

### 总体状态

| Phase | 状态 | 依据 |
| --- | --- | --- |
| Phase 1 Flow 解析 | 完成 | `parser.uya:1166`；`test_yaml_parse_flow_*.uya` |
| Phase 2 编码与互转 | 完成 | `encoder.uya:464/476/483`；`convert.uya:22/60`；`test_yaml_encode_*.uya`、`test_yaml_json_convert.uya` |
| Phase 3 Block/块标量/多文档 | 完成 | `parser.uya` 缩进栈 + 块标量（竖线 `\|` 与折叠符 `>`）+ `parse_multi(:1236)`；`test_yaml_parse_block*.uya`、`test_yaml_parse_multi.uya`、`test_yaml_fold_block.uya`、`test_yaml_encode_fold_roundtrip.uya` |
| Phase 4 锚点/别名 | 解析完成，编码仅占位 | `parser.uya:17-19` 三个上限常量；`YamlEncodeStyle.FlowAnchors` 与 Flow 同路径 |
| `ToYaml` 接口 / `to_yaml` 宏 | 仅接口声明，无实现 | `impl.uya:6` 是唯一 `ToYaml` 命中，无宏、无实现者 |
| Benchmark | 未开始 | 无 `tests/bench_yaml.uya`、无 `tests/data/yaml/` |

实现时遵循项目 TDD 流程：先添加测试 → 实现代码 → `make check` 验证。

---

## Phase 1：Flow 风格解析器（复用 std.json 扩展）

### 1.1 前置依赖

- [x] std.json Phase 1 已具备可用的 parse、JsonValue、Arena
- [x] 确认 Arena 接口：`arena_alloc` / `arena_reset` 或等效

### 1.2 扩展 JSON 词法/语法

- [x] 无引号 key：`key: value` 中 key 可为 bare word
- [x] YAML 布尔字面量：`yes`、`no`、`true`、`false`、`on`、`off`（标量带词边界，避免 `none`/`offer` 等误匹配）
- [x] 与 std.json 同构的 `null`、数字、字符串、数组、对象解析逻辑（实现于 `parser.uya`，未直接 `use` json.parse 以免类型不一致）

### 1.3 数据结构

- [x] 创建 `lib/std/yaml/` 目录
- [x] `errors.uya`：YAML 解析错误（InvalidUtf8、InvalidEscape、InvalidScalar、UnexpectedToken、UnexpectedEof、InvalidIndent、NumberOverflow、InvalidNumber、NestingTooDeep）
  - 现状（2026-10-19 核对，`lib/std/yaml/errors.uya`）：14 个 `export error`，上述 9 个之外还有 `BufferTooSmall`、`UnsupportedEncodeStyle`（编码侧）与 `AnchorTooDeep`、`AnchorOverflow`、`UnknownAlias`（Phase 4 锚点）
- [x] `value.uya`：`YamlValue`、`YamlStrView`、`YamlArray`、`YamlKeyValue`、`YamlObject`（与 JsonValue 对称；变体名为 `y_str`/`y_arr`/`y_obj`，避免与 `JsonValue` 的 `str`/`arr`/`obj` C 字段同名导致合并编译 match 错型）

### 1.4 解析器

- [x] `parser.uya`：实现 `parse(arena, ptr, len) !YamlValue`（与 json.parse 签名一致）
  - [ ] 优先调用 std.json 解析（当前为同构手写扩展，后续可选接 json 再转 YamlValue）
  - [x] 扩展词法：无引号 key、`yes`/`no`/`on`/`off`、`null`/`true`/`false` 词边界
  - [ ] 错误位置报告（行/列或偏移）

### 1.5 测试

- [x] `tests/test_yaml_parse_flow_basic.uya`：null、bool（含 yes/no/on/off）、数字、字符串
- [x] `tests/test_yaml_parse_flow_array.uya`：空数组、嵌套数组
- [x] `tests/test_yaml_parse_flow_object.uya`：无引号 key、引号 key、嵌套对象
- [x] `tests/test_yaml_parse_invalid.uya`：预期解析失败（尾随垃圾、空 key；`error_*.uya` 在本仓库表示**编译期**失败，故运行时失败用 `test_*`）

---

## Phase 2：编码器与 ToYaml

### 2.1 YamlWriter

- [x] `encoder.uya`：`YamlWriter`（buf/cap/used/overflow/style）
- [x] `yaml_write_null`、`yaml_write_bool`、`yaml_write_i32`、`yaml_write_i64`、`yaml_write_f64`
- [x] `yaml_write_str_view`（双引号 + 转义，与 JSON 一致）
- [x] `yaml_write_array_start`/`end`、`yaml_write_object_start`/`end`、`yaml_write_comma`
- [x] Flow 输出；对象 key 在安全字符集内可无引号

### 2.2 基础类型 ToYaml

- [x] `impl.uya`：`ToYaml` 接口（标量用 `yaml_write_*`）
  - **核对（2026-10-19）**：接口已声明（`impl.uya:6`：`fn to_yaml(self: &Self, w: &YamlWriter) void;`），但**没有任何基础类型或结构体实现它**，编码器也不接收 `&impl ToYaml`。当前标量写入直接调用 `encoder.uya` 的 `yaml_write_null/bool/i32/i64/f64/str_view`，等价功能已可用，接口本身是空壳。
- [ ] 结构体 ↔ YAML 的 `to_yaml` 反射宏（对应 json 侧 `to_json<T>` 单态展开）——`impl_macro.uya` 与 `impl_yaml!` 均不存在

### 2.3 API

- [x] `yaml_encode_to(value, buf, cap, style) !usize`（设计名 `encode_to`；与 `std.json.encoder.encode_to` 合并冲突故加前缀）
- [x] `yaml_encode` / `yaml_encode_into_arena`
- [x] `YamlEncodeStyle`：`Flow` / `Block`

### 2.4 与 std.json 互操作

- [x] `convert.uya`：`yaml_value_to_json_value`、`json_value_to_yaml_value`

### 2.5 测试

- [x] `tests/test_yaml_encode_basic.uya`
- [x] `tests/test_yaml_encode_flow.uya`
- [x] `tests/test_yaml_json_convert.uya`

---

## Phase 3：Block 风格与块标量

### 3.1 Block 解析

- [x] Block 映射：`key: value` + 缩进栈
- [x] Block 序列：`- item` 列表
- [x] 缩进规则：仅空格，Tab 报错
- [x] 扩展 `parse` 支持 Block 风格输入

### 3.2 块标量

- [x] `|` 字面量块
- [x] `>` 折叠块

### 3.3 Block 编码

- [x] `YamlEncodeStyle.Block` 输出
- [x] 块标量编码（多行字符串用 `|`）

### 3.4 多文档

- [x] `parse_multi(arena, input) !&[YamlValue]`
- [x] `---` 分隔符解析（上一文档在分隔行处截断）

### 3.5 测试

- [x] `tests/test_yaml_parse_block.uya`
- [x] `tests/test_yaml_parse_block_scalar.uya`
- [x] `tests/test_yaml_parse_multi.uya`
- [x] `tests/test_yaml_tab_indent.uya`：Tab 缩进解析失败（`error_*` 保留给编译期失败）
- [x] `tests/test_yaml_fold_block.uya`：YAML 1.2.2 块折叠规则（空行 → `\n`；行首空白内容行不折叠为空格）
- [x] `tests/test_yaml_encode_fold_roundtrip.uya`：Block 折叠编码 ↔ 解析往返

---

## Phase 4：锚点/别名（可选，带安全限制）

- [x] 解析 `&anchor`、`*alias`（Flow 与 Block 行内值，锚点名 ASCII `[a-zA-Z0-9_-]+`）
- [x] 深度上限（`MAX_ANCHOR_DEFINE_DEPTH` 64）、别名解引用次数上限（`MAX_ALIAS_RESOLUTIONS` 1024）、锚点表上限（`MAX_ANCHORS` 64）
- [x] 超出限制报 `AnchorTooDeep`、`AnchorOverflow`；未定义别名 `UnknownAlias`
- [x] 编码：`YamlEncodeStyle.FlowAnchors`（当前与 Flow 同路径，占位待图序列化输出 `&`/`*`）
- [x] 测试：`test_yaml_parse_anchor_flow`、`test_yaml_parse_anchor_block`、`test_yaml_anchor_limits`、`test_yaml_encode_flow_anchors`

---

## Benchmark

- [ ] **数据集**
  - [ ] Flow：可与 `bench_json` 内嵌负载同构（把 key 去引号、`true`/`yes` 等 YAML 字面量），或从 [yaml-test-suite](https://github.com/yaml/yaml-test-suite) / RapidYAML  fixtures 选小文件放 `tests/data/yaml/`（大文件可 `.gitignore`，用脚本拉取）
  - [ ] Block / 块标量 / 多文档 / 锚点：单独准备短样例（缩进栈、`|/>`、`---`、`&`/`*`），避免与纯 Flow 混测失真
- [ ] **实现**：新增 `tests/bench_yaml.uya`，对齐 `tests/bench_json.uya`——`@syscall(gettimeofday)` 墙钟微秒、`arena_reset` 每轮、打印 **usec** 与 **MB/s**（`MB_F = 1048576.0`，与 json 一致）；覆盖 **parse**、**encode**（`yaml_encode_to`，`Flow` / `Block` 可分两节或开关）
- [ ] **记录**：在本文档或 `yaml_design.md` 附录记下当前机器上 Phase 1（Flow）与含 Block/锚点样例的吞吐（MB/s），便于回归对比；优化 `@vector` 后再跑一轮

---

## 与主待办集成

- [x] 已在 [todo_mini_to_full.md](todo_mini_to_full.md) 第 39 项添加 **std.yaml** 条目
