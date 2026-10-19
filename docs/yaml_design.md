# Uya 高性能 YAML 编解码器设计文档

**版本**：v0.1

**状态**：Phase 1–4 主体已实现（见 [todo_yaml.md](todo_yaml.md)）

**最后核对**：2026-10-19，按 `lib/std/yaml/{value,parser,encoder,errors,convert,impl}.uya` 与 `tests/test_yaml_*.uya` 回填

**参考**：YAML 1.2 规范、RapidYAML、[json_design.md](json_design.md)

---

## 1. 概述

本文档定义 Uya 标准库的 YAML 编解码器设计，基于 Uya 的零 GC、编译期证明、显式内存控制、切片零拷贝等特性，实现高性能 YAML 子集解析与编码。目标：Phase 1 接近 RapidYAML 水平，明显优于 Go/Java 标准库；Phase 1 优先 Flow 风格，最大化复用 std.json 解析器。

### 1.1 设计目标

- **零拷贝**：字符串值直接引用输入 buffer，不复制
- **单次分配**：解析阶段使用 Arena，一次分配得到 Tape
- **显式内存**：API 要求调用方传入 Arena 或预分配 buffer
- **编译期序列化**：设计目标是由宏生成 `to_yaml`，无运行时反射；**当前未实现**——仓库内只有 `ToYaml` 接口声明（`impl.uya`），无宏、无实现者（见 §8.1）
- **子集策略**：先 Flow 风格（接近 JSON），再扩展 Block、块标量、多文档、锚点（带安全限制）

---

## 2. 设计原则（对齐 Uya 特性）

| Uya 特性 | YAML 设计应用 |
|----------|---------------|
| 零 GC / 显式内存 | 解析器使用 Arena 单次分配，编码器接受预分配 buffer 或 Arena |
| 编译期证明 | 结构体 → YAML 映射设计上由宏在编译期生成，零反射（**当前宏未实现**，见 §8.1） |
| 错误联合 `!T` | `parse()` 返回 `!YamlValue`，`yaml_encode()` 返回 `!&[byte]`、`yaml_encode_to()` 返回 `!usize` |
| 切片 `&[T]` | 字符串值用 `YamlStrView`(ptr+len) 视图，直接指向输入 buffer（与 `JsonStrView` 同构，受 slice codegen 限制不走 `&[byte]`） |
| 无隐式分配 | API 显式要求传入 `&Arena` 或 buffer 容量 |
| `@vector`/`@mask`、`@asm` | 可选 SIMD（与 std.json 思路一致：优先 `@vector`，可选 `@asm`） |

---

## 3. YAML 标准范围与子集策略

### 3.1 Phase 1：Flow 风格（JSON 兼容子集）

- **首选路径**：仅支持 Flow 风格 `{key: value}`、`[a, b, c]`，最大化复用 std.json 解析
- **Phase 1 的「JSON 兼容」定义**：语法兼容（Flow 与 JSON 括号结构一致）+ 类型兼容（null、bool、数字、字符串、数组、对象）；YAML 特有字面量（如 `yes`/`no`）按 YAML 规则解析，输出统一到 YamlValue
- **YAML Flow 与 JSON 差异**：
  - key 可无引号
  - 布尔支持 `yes`/`no`/`true`/`false`/`on`/`off`
  - 需扩展 JSON 词法/语法
- **备选**：若 Flow 扩展成本高，则改为实现简单 Block 映射（`key: value` + 缩进栈），不依赖 JSON 后端

### 3.2 Phase 2：Block 风格

- Block 映射：`key: value` 通过缩进栈解析
- Block 序列：`- item` 列表

### 3.3 Phase 3：块标量与多文档

- 块标量：`|`（字面量）、`>`（折叠）
- 多文档：`---` 分隔，API 返回 `&[YamlValue]` 或迭代器

### 3.4 Phase 4：锚点/别名（可选，带安全限制）

- `&anchor` / `*alias`，可导致指数膨胀（YAML 炸弹）
- **限制**：深度上限、别名引用次数上限，超出报错
- **核对（2026-10-19）：已实现。** 解析侧常量见 `parser.uya:17-19`（`MAX_ANCHORS = 64`、`MAX_ALIAS_RESOLUTIONS = 1024`、`MAX_ANCHOR_DEFINE_DEPTH = 64`），超限分别报 `AnchorOverflow` / `AnchorTooDeep`，未定义别名报 `UnknownAlias`；锚点名限 ASCII `[a-zA-Z0-9_-]+`。测试：`tests/test_yaml_parse_anchor_flow.uya`、`test_yaml_parse_anchor_block.uya`、`test_yaml_anchor_limits.uya`。编码侧只有 `YamlEncodeStyle.FlowAnchors` 占位，尚不输出 `&`/`*`。

### 3.5 不支持与限制

| 特性 | 支持情况 |
|------|----------|
| Tab 缩进 | 不支持，遇到 Tab 报 `InvalidIndent`，强制空格 |
| 复杂标签 | 不支持 `!!binary`、`!!omap` 等 |
| 锚点（无限制） | 不支持，仅 Phase 4 带深度/次数限制 |
| 多行字符串（块标量） | Phase 3 支持 |

---

## 4. 与 std.json 关系

- **Phase 1** 若采用 Flow 风格，可复用 std.json 解析器并扩展 YAML 特有词法
- **互操作**：提供 `yaml_value_to_json_value` / `json_value_to_yaml_value` 转换函数
- **内存布局**：YamlValue 与 JsonValue 结构对称，可共用布局

---

## 5. 整体架构

```mermaid
flowchart TB
    subgraph Parse [解析流程]
        A[Input: &[byte]] --> B[词法/结构扫描]
        B --> C[构建 Tape]
        C --> D[YamlValue]
    end

    subgraph Encode [编码流程]
        E[结构化数据] --> F[ToYaml / 宏生成]
        F --> G[YamlWriter]
        G --> H[Output: &[byte]]
    end

    subgraph Memory [内存]
        I[Arena] --> J[parse 分配]
        K[调用方 buffer] --> G
    end
```

---

## 6. 核心数据结构

### 6.1 YamlValue（零拷贝值类型）

```uya
// lib/std/yaml/value.uya:10-18（全部为 export）
union YamlValue {
    yaml_null: void,        // 对应 YAML null；不用 null 变体名（非合法标识符写法）
    bool_val: bool,
    int_val: i64,
    float_val: f64,
    y_str: YamlStrView,     // 指向输入 buffer，零拷贝（ptr+len 视图，规避 slice codegen）
    y_arr: YamlArray,
    y_obj: YamlObject,
}

struct YamlArray {
    items: &YamlValue,  // Arena 分配
    len: usize,
}

struct YamlKeyValue {
    key: YamlStrView,   // 键名视图
    value: YamlValue,
}

struct YamlObject {
    pairs: &YamlKeyValue,  // Arena 分配
    len: usize,
}
```

变体名用 `y_str`/`y_arr`/`y_obj` 而非 `str`/`arr`/`obj`：`YamlValue` 与 `JsonValue` 常常同文件出现，C 后端 union 字段同名会让合并编译的 `match` 取错类型（`value.uya:9` 注释）。`YamlStrView`（`value.uya:4`）= `{ ptr: &byte, len: usize }`，与 `JsonStrView` 对称。

### 6.2 多文档

```uya
// 单文档（parser.uya:1166）—— 签名与 std.json.parse 一致：ptr + len，不是 &[byte]
export fn parse(arena: &Arena, ptr: &byte, len: usize) !YamlValue;

// 多文档（parser.uya:1236）—— 最多 MAX_MULTI_DOCS = 32 篇
export fn parse_multi(arena: &Arena, ptr: &byte, len: usize) !&[YamlValue];
```

---

## 7. 解析器（Decoder）

### 7.1 两阶段解析

1. **Stage 1**：扫描结构字符（Flow：`{ } [ ] , : "`；Block：缩进、`-`、`:`）
2. **Stage 2**：填充 Tape，指针指向 `input` 或 `arena`
3. **数值解析**：与 JSON 一致，手写整数/浮点解析

### 7.2 API

```uya
// 当前实现（lib/std/yaml/parser.uya:1166、:1236）
export fn parse(arena: &Arena, ptr: &byte, len: usize) !YamlValue;
export fn parse_multi(arena: &Arena, ptr: &byte, len: usize) !&[YamlValue];  // Phase 3，已实现
```

### 7.3 错误类型

语法规范（[grammar_formal.md](grammar_formal.md)）：预定义错误为 `error ID ;`，**单条声明**，不支持 `error { ... }` 聚合块。模块名用 `errors` 以免与关键字 `error` 冲突。

```uya
// lib/std/yaml/errors.uya:4-17，共 14 个 export error
export error InvalidUtf8;
export error InvalidEscape;
export error InvalidScalar;
export error UnexpectedToken;
export error UnexpectedEof;
export error InvalidIndent;          // Tab 或缩进错误
export error NumberOverflow;
export error InvalidNumber;
export error NestingTooDeep;
export error BufferTooSmall;         // 编码缓冲区不足
export error UnsupportedEncodeStyle;
export error AnchorTooDeep;          // Phase 4：锚点定义深度超限
export error AnchorOverflow;         // Phase 4：别名解引用次数 / 锚点表超限
export error UnknownAlias;           // Phase 4：未定义别名
```

（`UnknownAlias` 在设计稿里原先漏列，实际实现有；`BufferTooSmall` 与 `UnsupportedEncodeStyle` 是编码侧新增。）

---

## 8. 编码器（Encoder）

### 8.1 ToYaml 接口（**已声明，但仓库内无任何实现者**）

```uya
// lib/std/yaml/impl.uya:6-8
export interface ToYaml {
    fn to_yaml(self: &Self, w: &YamlWriter) void;
}
```

> **核对结论（2026-10-19）**：`grep -rn to_yaml lib src` 除该接口声明外无命中——没有任何结构体实现 `ToYaml`，编码器也不接受 `&impl ToYaml`，也没有 `to_yaml` 反射宏（`impl_macro.uya` 不存在）。当前把 `YamlValue` 树写成 YAML 的唯一路径是 `yaml_encode_to` / `yaml_encode` / `yaml_write_value`；结构体序列化仍需先手工构造 `YamlValue` 或经 `json_value_to_yaml_value` 转换。

### 8.2 API

```uya
// lib/std/yaml/encoder.uya:464 / :476 / :483 —— 均为 export
export fn yaml_encode_to(v: &YamlValue, buf: &byte, cap: usize, style: YamlEncodeStyle) !usize;
export fn yaml_encode_into_arena(ar: &Arena, v: &YamlValue, style: YamlEncodeStyle) !YamlStrView;
export fn yaml_encode(ar: &Arena, v: &YamlValue, style: YamlEncodeStyle) !&[byte];
```

命名差异：设计稿里的 `encode_to` / `encode` 实际命名为 `yaml_encode_to` / `yaml_encode`（外加 `yaml_encode_into_arena`），因为与 `std.json.encoder.encode_to` 同名会在合并编译时冲突（`yaml.uya` 模块注释有说明）。

### 8.3 输出风格

`export enum YamlEncodeStyle`（`encoder.uya:24-30`）有三个值：

- `Flow`：`{key: value}`、`[a, b]`（与 JSON 接近）
- `Block`：缩进风格（Phase 2/3 后支持，含 `|` 块标量）
- `FlowAnchors`：Phase 4 占位，**当前与 `Flow` 走同一路径**，还不会输出 `&anchor` / `*alias`

---

## 9. 模块与文件规划

```
lib/std/yaml/
  yaml.uya          # 模块入口：仅注释（无 export）
  value.uya         # YamlValue、YamlStrView、YamlArray、YamlObject、YamlKeyValue（export struct/union）
  errors.uya        # 14 个 export error（注意文件名是 errors.uya，不是 error.uya）
  parser.uya        # 解析器：parse、parse_multi（约 1245 行，Flow/Block/块标量/多文档/锚点）
  encoder.uya       # YamlWriter、YamlEncodeStyle、yaml_write_*、yaml_encode_to/encode_into_arena/encode
  impl.uya          # 只有 ToYaml 接口声明（无实现者）
  convert.uya       # yaml_value_to_json_value、json_value_to_yaml_value
```

与设计稿的差异：没有 `impl_macro.uya`（`impl_yaml!` 宏未实现）；`impl.uya` 不是“基础类型 ToYaml 实现”，只是一句接口声明。

---

## 10. 依赖与约束

- **Arena**：与 std.json 共用
- **std.json**：Phase 1 可复用解析逻辑；convert 模块依赖 JsonValue
- **std.mem**：mem_copy 等
- **std.string**：UTF-8 校验（可选）

---

## 11. 性能目标

| 阶段 | 目标 | 参考 |
|------|------|------|
| Phase 1（Flow 标量） | 0.2–0.5 GB/s | RapidYAML、RapidJSON |
| Phase 4（可选 SIMD） | 0.5–1.5 GB/s | 与 std.json 共用 SIMD 思路 |
| 编码 | 0.3–1 GB/s | 编译期宏，无反射 |

### 11.1 Benchmark 方案

- **数据集**：[YAML 官方测试矩阵](https://matrix.yaml.info/)、RapidYAML 仓库典型 YAML 文件
- **共用**：Flow 风格可与 JSON benchmark 共用部分数据集
- **方法**：单线程、热缓存、多次运行取中位数，单位 GB/s

---

## 12. 与主流库对比

| 库 | 语言 | 特点 |
|----|------|------|
| RapidYAML | C++ | 零拷贝、高性能，YAML 1.2 子集 |
| libyaml | C | 官方实现，功能全，性能中等 |
| yaml-cpp | C++ | 易用，功能全 |
| Go gopkg.in/yaml | Go | 标准选择，性能一般 |
| Java SnakeYAML | Java | 功能全，存在反序列化风险 |

Uya 设计目标：Phase 1 接近 RapidYAML；子集优先，安全限制锚点。
