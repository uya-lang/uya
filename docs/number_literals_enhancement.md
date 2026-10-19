# 数字字面量增强 - v0.2.31+

> **核对头（2026-10-19，编译器 v0.10.4）**：本文是 v0.2.31 时代的改造记录，功能现状以 `src/lexer.uya:449-591`（`read_number`）、`src/parser/types.uya:817-1026`（`parse_literal_suffix` / `parse_integer_literal_with_suffix` / `parse_float_literal_with_suffix`）为准。多进制、下划线、`i8..i64`/`u8..u64`/`usize`/`f32`/`f64` 后缀全部可用（已用 `bin/uya` 实测）。文中提到的 `compiler-mini/`、`compiler-c/`、`uya-src/` 目录**均已退役/不存于当前仓库**，实现只在自举编译器 `src/` 中维护。

## 功能概述

为 Uya 编译器添加了数字字面量的多进制支持、下划线分隔符和**类型后缀**，提高代码可读性和类型表达能力。

## 实现的功能

### 1. 多进制整数字面量

- **十六进制**：`0x` 或 `0X` 前缀
  - 示例：`0xFF`、`0x1A2B`、`0XDEAD_BEEF`
  
- **八进制**：`0o` 或 `0O` 前缀
  - 示例：`0o755`、`0O644`、`0o7_777`
  
- **二进制**：`0b` 或 `0B` 前缀
  - 示例：`0b1010`、`0B1111_0000`、`0b1111_0000_1010_0101`

- **十进制**：无前缀（保持原有行为）
  - 示例：`42`、`1_000_000`、`123_456_789`

### 2. 下划线分隔符

数字字面量中可以使用下划线 `_` 作为分隔符，提高可读性：

- **规则**：
  - 可以出现在任意两个数字之间
  - 不能出现在开头或结尾
  - 不能连续出现
  - 紧跟在进制前缀之后**实际被接受**：lexer 只校验下划线后面紧跟的是该进制的合法数字（`src/lexer.uya:487-492`），所以 `0x_FF`、`0b_1010` 都能编译（已用 `bin/uya` 实测）。本文早先写成“非法”，与实现不符
  
- **适用范围**：
  - 整数字面量：`1_000_000`
  - 浮点字面量：`3.141_592_653`
  - 指数部分：`1.0e1_0`
  - 所有进制：`0xFF_00_AA`、`0o7_777`、`0b1111_0000`

### 3. 浮点字面量

浮点字面量也支持下划线分隔符（仅限十进制）：

- 小数部分：`1_000.5`
- 小数点后：`3.141_592_653`
- 指数部分：`1.0e1_0`

### 4. 类型后缀（v0.7.x 起）

在多进制和下划线的基础上，整数和浮点字面量支持**显式类型后缀**，与主规范 `docs/uya.md`、词法/语法文档完全一致：

- **整数后缀**（对应 `LiteralSuffix` 枚举）：
  - `i8`、`i16`、`i32`、`i64`
  - `u8`、`u16`、`u32`、`u64`
  - `usize`
- **浮点后缀**：
  - `f32`、`f64`

示例：

```uya
// 整数类型后缀
const a: i8   = 100i8;
const b: i32  = 100000i32;
const c: u8   = 255u8;
const d: u32  = 0xFFu32;
const e: usize = 42usize;

// 浮点类型后缀
const f: f32 = 1.5f32;
const g: f64 = 3.14f64;
```

解析规则：

- 后缀直接跟在数字末尾，中间不能有下划线（例如 `0xFFu8`、`1.0e10f64`）。
- Lexer 读入完整字面量（含进制前缀、数字主体、下划线和类型后缀），Parser 通过 `parse_integer_literal_with_suffix` / `parse_float_literal_with_suffix`：
  - 去除下划线
  - 识别末尾的后缀并记录到 AST：`literal_suffix` / `float_literal_suffix`
  - 剥离后缀后再按进制解析数值
- 没有后缀时：整数默认 `i32`，浮点默认 `f64`，与之前行为保持一致。

对应测试用例：

- `tests/test_literal_suffix.uya`：覆盖整型与浮点型的各种后缀组合（十进制与十六进制）。

## 实现范围

> **现状（v0.10.4）**：下面两节是历史记录。`compiler-mini/`、`compiler-c/` 在当前仓库中已不存在，Uya 编译器只以 `src/` 的自举实现为维护源（见 `AGENTS.md`）。

### C 编译器 (`compiler-mini/src/`)　〔历史，目录已退役〕

- ✅ **Lexer** (`src/lexer.c`)
  - 识别 `0x`/`0X`（十六进制）前缀
  - 识别 `0o`/`0O`（八进制）前缀
  - 识别 `0b`/`0B`（二进制）前缀
  - 支持下划线分隔符（带验证规则）
  - 错误检测（连续下划线、末尾下划线、前缀后下划线等）

- ✅ **Parser** (`src/parser.c`)
  - 添加 `remove_underscores()` 辅助函数
  - 添加 `parse_integer_literal()` 解析不同进制
  - 添加 `parse_float_literal()` 处理浮点下划线
  - 使用 `strtol()` 转换不同进制为内部表示

- ✅ **AST/Checker/Codegen**
  - 无需修改（整数在 Parser 阶段已转换为统一的十进制值）
  - Codegen 生成标准十进制 C 字面量

### 自举编译器 (`src/` 自举版 Uya)

- ✅ **Lexer** (`src/lexer.uya`)
  - 已同步多进制、下划线分隔符和类型后缀的实现逻辑
  - 在 `read_number` 中读取完整数字+后缀，交由 Parser 解析
- ✅ **Parser** (`src/parser/types.uya`, `src/parser/primary.uya`)
  - 使用 `parse_integer_literal_with_suffix` / `parse_float_literal_with_suffix`
  - 将解析出的后缀写入 AST 节点的 `literal_suffix` / `float_literal_suffix`
  - 后缀识别表见 `src/parser/types.uya:817-905`：`i8`/`i16`/`i32`/`i64`/`u8`/`u16`/`u32`/`u64`/`usize`/`f32`/`f64`（枚举 1..11，0 表示无后缀）
  - 进制与后缀的切分是先按进制扫数字、再取尾部字母数字当后缀（`src/parser/types.uya:920-945`），因此 `0xFFu8`、`0b1010u16` 可用


## 测试

### 测试文件

- `tests/test_number_literals.uya`
  - 测试所有进制的整数字面量
  - 测试下划线分隔符
  - 测试浮点字面量（带下划线）
  - 验证运行时值的正确性
- `tests/test_literal_suffix.uya`
  - 覆盖整型与浮点型的各种后缀组合（十进制与十六进制）

### 测试结果

```bash
./bin/uya test tests/test_number_literals.uya
./bin/uya test tests/test_literal_suffix.uya
# 均通过
```

## 使用示例

```uya
fn main() i32 {
    // 多进制整数
    const hex: i32 = 0xFF_00_AA;      // 十六进制：16711850
    const oct: i32 = 0o755;            // 八进制：493
    const bin: i32 = 0b1111_0000;      // 二进制：240
    const dec: i32 = 1_000_000;        // 十进制：1000000
    
    // 浮点字面量（带下划线）
    const pi: f64 = 3.141_592_653;
    const big: f64 = 1_000.5;
    const sci: f64 = 1.0e1_0;          // 10000000000.0
    
    return 0;
}
```

## 规范文档

- `docs/uya.md`（数字字面量一节）与 `docs/grammar_formal.md`
  - 完整 BNF 语法
  - 下划线规则说明
  - 错误处理规则
- `compiler-mini/spec/UYA_MINI_SPEC.md` 为历史路径，`compiler-mini/` 目录已退役

## 兼容性

- ✅ 向后兼容（不使用新语法的代码仍然有效）
- ✅ 与 C99 互操作（生成标准十进制字面量）
- ✅ 所有原有测试通过

## 限制

1. 浮点字面量仅支持十进制（不支持 `0x1.0p10` 等十六进制浮点；`src/lexer.uya:501-554` 只在 `base == 10` 时识别小数与指数）
2. ~~自举编译器尚未同步更新~~（已过时）：自举编译器 `src/` 就是唯一维护源，词法、进制与后缀解析都已在其中实现
3. 无后缀的整数字面量默认 `i32`；带后缀时由后缀决定类型（`1u8` 就是 `u8`）。数值本身在 parser 里转成统一的 `i64`，不再保留原始进制

## 后续工作

- [ ] 进一步扩展自举编译器的十六进制浮点字面量（`0x1.0p10` 等）
- [ ] 在更多高级示例和教程中使用类型后缀（性能敏感、FFI 场景）

