# @embed / @embed_dir 详细设计

**版本**：v0.2  
**日期**：2026-04-20  
**状态**：已实现（2026-10-19 核对，v0.10.4）

> **实现核对**：
>
> - 词法白名单与错误文案：`src/lexer.uya`（`@embed` / `@embed_dir` 均在未知内置错误列表中）。
> - 解析：`src/parser/primary.uya`，参数收紧为「恰好一个字符串字面量」。
> - 类型与内容读取：`src/checker/check_expr.uya`；`@embed` → `&[const byte]`，
>   `@embed_dir` → `&[const EmbedDirEntry]`（`EmbedDirEntry` 由 checker 前置阶段合成注入）。
> - Codegen：按需延迟补发射，镜像 split-C 下同样可用。
> - 回归：`tests/test_embed_builtin.uya`、`tests/verify_embed_dedupe.sh`、
>   `tests/verify_embed_dir_multifile_reuse.sh`、`tests/verify_embed_multifile_reuse.sh`、
>   `tests/verify_embed_empty_dir.sh`、`tests/verify_embed_nostdlib.sh`，以及
>   `tests/error_embed_*.uya` 一组负例。

---

## 1. 目标

为 Uya 增加两个内置函数：

```uya
@embed("path/to/file.bin")
@embed_dir("path/to/assets")
```

能力目标：

- 在编译期读取指定文件或目录，并把内容直接嵌入最终生成的 C99 代码。
- `@embed` 返回单个文件的二进制切片。
- `@embed_dir` 返回目录清单切片，目录下每个文件都有相对路径与对应字节数据。
- 支持任意二进制内容，包括 `0x00`。
- 在普通 C99、`--split-c`、镜像多 TU、`nostdlib`、microapp 模式下都可用。
- 同一个已解析文件路径在单次编译内只发射一份静态二进制常量。
- 同一个已解析目录路径在单次编译内只发射一份静态目录表。

---

## 2. 非目标

本阶段不做以下事情：

- 不支持运行时路径，也不支持变量、拼接表达式、插值表达式作为参数。
- 不让 `@embed("dir")` 直接兼容目录；目录能力单独由 `@embed_dir("dir")` 提供。
- 不自动追加结尾 `0`，也不把内容解释为字符串。
- 不做基于内容哈希的跨路径去重；v1 仅按“已解析后的绝对/规范化路径”去重。
- 不暴露文件修改时间、MIME、文件名等附加元信息。
- 不支持大于 `i32` 上限的嵌入文件。
- 不支持 symlink、设备文件、FIFO 等特殊文件作为目录成员。

最后一条大小限制是有意限制：当前 Uya 里 `@len(slice)` 的语言层结果仍是 `i32`，切片生态尚未完全升级到 `usize`。

---

## 3. 用户语义

### 3.1 语法

```uya
const cert: &[const byte] = @embed("assets/cert.der");
const model: &[const byte] = @embed("fixtures/model.tflite");

const assets: &[const EmbedDirEntry] = @embed_dir("assets");
```

v1 语法规则：

- `@embed` 必须写成 `@embed(<string-literal>)`
- `@embed_dir` 必须写成 `@embed_dir(<string-literal>)`
- 二者参数个数都必须恰好为 1
- 二者参数都必须是字符串字面量
- 常规字符串与 raw string 都可接受，只要最终落成字符串字面量 AST

### 3.2 返回类型

`@embed` 的类型固定为：

```uya
&[const byte]
```

设计上不返回 `&[const byte: N]`，原因：

- 现有切片类型系统对长度常量的承载仍偏向 `i32`
- 文件大小驱动返回类型变化会让语义变得不稳定
- `&[const byte]` 已能表达“只读、二进制、带长度”的核心语义

后续若语言层需要编译期长度信息，可以单独做：

- `@len(@embed(...))` 常量折叠
- 或新增更精确的嵌入元信息机制

`@embed_dir` 的类型固定为：

```uya
&[const EmbedDirEntry]
```

其中 `EmbedDirEntry` 为新增的编译器内建结构体声明：

```uya
struct EmbedDirEntry {
    path: &[const byte],
    data: &[const byte],
}
```

这里的“内建结构体”不是指一个脱离 AST 的魔法类型。为避免和现有编译器架构冲突，实施时应采用：

- 在 checker 前置阶段合成一个真实的 `AST_STRUCT_DECL`
- 将该声明注入到 `program AST`
- 后续让 member access、类型推断、C99 结构体发射、split-c 类型头都走现有结构体主路径
- 只要程序里出现 `@embed_dir(...)`，或任意类型位置显式引用 `EmbedDirEntry`，都要确保该声明已注入

不推荐把 `EmbedDirEntry` 仅做成 checker/codegen 私有特判类型，否则会在字段访问、结构体查找、类型头发射等路径上形成多套逻辑。

选择单独结构体而不是让 `@embed_dir` 复用 `@embed` 返回值的原因：

- 文件和目录是两种不同的语义对象
- 目录场景必须暴露相对路径
- `&[const EmbedDirEntry]` 在 checker、codegen、用户侧 API 上都更稳定

### 3.3 内容语义

`@embed`：

- 返回值指向静态只读数据
- 内容不追加结尾 `0`
- 文件为空时，返回长度为 `0` 的切片
- 同一已解析路径多次使用时，共享同一份静态 blob 符号

`@embed_dir`：

- 返回值是静态只读目录条目切片
- 目录递归遍历，收集所有普通文件
- 每个条目的 `path` 是相对 `@embed_dir` 根目录的相对路径
- 相对路径统一使用 `/` 作为分隔符
- 条目按相对路径字典序排序，保证构建稳定
- 空目录允许，返回长度为 `0` 的切片
- 每个条目的 `data` 不追加结尾 `0`

只读语义还包括：

- 禁止对 `entries[i]` 做整元素赋值
- 禁止对 `entries[i].path` / `entries[i].data` 做成员写入

第二条需要额外补 checker 规则；不能只依赖当前 `&[const T]` 的“整元素赋值禁止”逻辑。

### 3.4 路径解析

`@embed` 与 `@embed_dir` 的路径解析规则固定如下：

1. 若参数是绝对路径，则直接使用该路径。
2. 若参数是相对路径，则相对于“写出该调用的源文件所在目录”解析。
3. 对 `.` / `..` 与路径分隔符做规范化。
4. 若结果仍是相对路径，则再基于当前工作目录补成绝对路径并再次规范化。
5. 最终得到稳定的“已解析绝对路径”，用于去重与诊断。

明确不做：

- 不相对于当前工作目录
- 不回退到 `project_root_dir`
- 不回退到 `UYA_ROOT`

这样做的原因是让模块可搬运、可复用，并避免多文件工程里“同一字面路径在不同调用点含义不同却又意外落到项目根”的歧义。

### 3.5 错误语义

以下情况在 checker 阶段直接报错：

- `@embed` 参数不是字符串字面量
- `@embed_dir` 参数不是字符串字面量
- 参数个数不为 1
- `@embed` 目标文件不存在
- `@embed` 目标路径是目录或非普通文件
- `@embed_dir` 目标目录不存在
- `@embed_dir` 目标路径不是目录
- 文件读取失败
- 目录遍历失败
- 目录中出现 symlink 或其他暂不支持的特殊文件
- 文件大小超过 `2147483647` 字节

建议错误信息同时包含：

- 源码位置
- 原始字面量路径
- 已解析路径
- 失败原因

示例：

```text
错误: @embed 无法读取文件
  literal: "assets/cert.der"
  resolved: /path/to/tests/assets/cert.der
  reason: file not found
```

---

## 4. 编译器分层设计

### 4.1 Lexer

文件：

- `src/lexer.uya`

改动：

- 把 `embed` 加入 `TOKEN_AT_IDENTIFIER` 的内建函数白名单。
- 把 `embed_dir` 加入 `TOKEN_AT_IDENTIFIER` 的内建函数白名单。
- 更新未知内建函数报错文案，把 `@embed` 和 `@embed_dir` 列进去。

不需要新增 token 类型；沿用现有 `TOKEN_AT_IDENTIFIER`。

### 4.2 AST

文件：

- `src/ast.uya`

新增节点类型：

```uya
AST_EMBED
AST_EMBED_DIR
```

建议新增字段：

```uya
embed_path_literal: &byte,   // 用户源码中的字面路径
embed_resolved_path: &byte,  // checker 解析后的规范路径
embed_data: &byte,           // Arena 中保存的原始字节
embed_size: i32,             // 字节数，v1 限制 <= i32 max

embed_dir_paths: & & byte,           // 目录条目的相对路径数组
embed_dir_resolved_paths: & & byte,  // 目录条目的绝对/规范化路径数组
embed_dir_data: & & byte,            // 每个目录条目的文件字节
embed_dir_sizes: &i32,               // 每个目录条目的字节数
embed_dir_entry_count: i32,          // 条目数量
```

选择专用 AST 节点，而不是沿用 `AST_CALL_EXPR`，原因：

- 参数规则是固定的，不需要通用调用语义
- 后续需要携带“已解析路径/文件大小/文件字节”
- `fmt`、checker、codegen 可以更直接处理

### 4.3 Parser

文件：

- `src/parser/primary.uya`

解析规则：

- 识别 `@embed`
- 识别 `@embed_dir`
- 期望 `(`
- 期望一个字符串字面量
- 期望 `)`
- 分别生成 `AST_EMBED` / `AST_EMBED_DIR`

这里建议 parser 就把参数约束收紧为“字符串字面量”，而不是先收成任意表达式再由 checker 拒绝。这样：

- 错误更早
- AST 更干净
- 后续无需在 `AST_EMBED` / `AST_EMBED_DIR` 上再挂一个通用 operand

### 4.4 Formatter

文件：

- `src/fmt.uya`

改动：

- `format_expr` / `format_expr_prec` 增加 `AST_EMBED`
- `format_expr` / `format_expr_prec` 增加 `AST_EMBED_DIR`
- 固定输出成：

```uya
@embed("...")
@embed_dir("...")
```

这样 `uya fmt` 能稳定往返，不会把新语法打散。

### 4.5 Checker

文件：

- `src/checker/check_expr.uya`
- 如有需要，补充 `src/checker/check_expr_extra.uya`

职责：

1. 解析并规范化路径。
2. `@embed` 读取文件内容。
3. `@embed_dir` 遍历目录并读取每个普通文件。
4. 把字节数据复制到 compiler arena。
5. 把解析结果回填到 AST 节点。
6. 返回对应的只读切片类型。

`@embed` 建议实现流程：

1. 取 `expr.filename`，截出其目录。
2. 用 `embed_path_literal` 解析目标文件路径。
3. 读取文件状态与大小。
4. 若大小超 `i32`，报错。
5. 申请 `embed_size` 字节 arena 内存并读入原始字节。
6. 保存 `embed_resolved_path / embed_data / embed_size`。
7. 返回 `TYPE_SLICE`，元素类型为 `TYPE_BYTE`，`slice_element_is_const = 1`。

`@embed_dir` 建议实现流程：

1. 取 `expr.filename`，截出其目录。
2. 用 `embed_path_literal` 解析目标目录路径。
3. 递归收集目录下所有普通文件。
4. 为每个文件生成相对路径，统一 `/` 分隔符。
5. 按相对路径排序。
6. 逐个读取文件，保存到 `embed_dir_data / embed_dir_sizes / embed_dir_paths / embed_dir_resolved_paths`。
7. 返回 `TYPE_SLICE`，元素类型为内建结构体 `EmbedDirEntry`，并将切片元素标记为 const。

这里建议在 checker 阶段读取文件，而不是推迟到 codegen，原因：

- AST 一旦通过 checker，嵌入内容就被冻结，避免编译过程中源文件被外部改写造成前后不一致
- codegen 只消费 AST，不再做文件系统决策
- 诊断位置天然更准确

此外，`@embed_dir` 需要在 checker 前置阶段把 `EmbedDirEntry` 作为真实 `AST_STRUCT_DECL` 注入 `program AST`，供类型推断、字段访问与 codegen 统一复用。

### 4.6 Codegen 数据模型

文件：

- `src/codegen/c99/internal.uya`
- `src/codegen/c99/utils.uya`
- `src/codegen/c99/main.uya`

需要新增独立的“二进制常量池”，不能复用现有字符串常量池。

现有字符串池的问题：

- `StringConstant.value` 语义是以 `0` 结尾的文本
- 去重与输出依赖 `strcmp` / C 字符串字面量
- 遇到嵌入文件中的 `0x00` 会被截断

建议新增表项：

```uya
struct EmbeddedBinaryConstant {
    name: &byte,           // 例如 uya_embed_0
    resolved_path: &byte,  // 作为去重 key
    data: &byte,           // 二进制字节
    size: i32,             // 字节数
}

struct EmbeddedDirTableConstant {
    name: &byte,              // 例如 uya_embed_dir_0
    root_resolved_path: &byte,
    entry_paths: & & byte,
    entry_data_names: & & byte, // 指向二进制常量名数组
    entry_sizes: &i32,
    entry_count: i32
}
```

并在 `C99CodeGenerator` 中增加：

- `embedded_constants`
- `embedded_constant_count`
- `embedded_constants_emitted_count`
- `embedded_dir_tables`
- `embedded_dir_table_count`
- `embedded_dir_tables_emitted_count`

### 4.7 Codegen 预收集与延迟补发射

文件：

- `src/codegen/c99/utils.uya`
- `src/codegen/c99/main.uya`

建议完全平行于字符串常量的流程：

- `collect_embed_constants_from_expr`
- `collect_embed_constants_from_stmt`
- `collect_embed_constants_from_decl`
- `emit_embed_constants`
- `emit_pending_embed_constants`
- `collect_embed_dir_tables_from_expr`
- `emit_embed_dir_tables`
- `emit_pending_embed_dir_tables`

这样可以覆盖：

- 正常预收集路径
- 宏展开或后续 AST 合成导致的延迟注册路径

### 4.8 C99 发射形态

嵌入文件常量的推荐 C 代码形态：

```c
static const unsigned char uya_embed_0[] = {
    0x30, 0x82, 0x01, 0x0a
};
```

表达式位置生成：

```c
((struct uya_slice_uint8_t){
    .ptr = (uint8_t *)uya_embed_0,
    .len = (size_t)4
})
```

目录表的推荐 C 代码形态：

```c
static const struct EmbedDirEntry uya_embed_dir_0[] = {
    {
        .path = { .ptr = (uint8_t *)str0, .len = (size_t)11 },
        .data = { .ptr = (uint8_t *)uya_embed_0, .len = (size_t)731 }
    }
};
```

不使用 C 字符串字面量表示二进制的原因：

- 二进制里可能含 `0x00`
- `\x..` 形式在长数据下可读性差，且更容易踩转义细节
- 直接字节数组最稳定，也更容易空文件兜底

空文件的 C99 处理：

```c
static const unsigned char uya_embed_1[1] = { 0 };
```

对应切片：

```c
{ .ptr = (uint8_t *)uya_embed_1, .len = (size_t)0 }
```

这样避免生成标准 C99 不允许的零长数组。

目录条目里的 `path` 可继续复用现有字符串常量池，因为它是文本；`data` 仍必须来自独立二进制常量池。

命名约定必须和现有 C99 codegen 规则对齐：

- Uya 层结构体名使用 `EmbedDirEntry`
- C 侧命名结构体按现有规则落成 `struct EmbedDirEntry`
- 其切片类型按现有 slice 规则落成 `struct uya_slice_EmbedDirEntry`

不建议在文档里另起一套 snake_case 的专用结构体命名，否则实现时会和现有 `c99_type_to_c` 的命名路径冲突。

### 4.9 表达式与类型查询

文件：

- `src/codegen/c99/expr.uya`
- `src/codegen/c99/types.uya`

必须补的点：

- `gen_expr(AST_EMBED)` 直接输出切片复合字面量
- `gen_expr(AST_EMBED_DIR)` 直接输出目录表切片复合字面量
- `get_c_type_of_expr(AST_EMBED)` 返回 `struct uya_slice_uint8_t`
- `get_c_type_of_expr(AST_EMBED_DIR)` 返回 `struct uya_slice_EmbedDirEntry`

这点和 `@src_name/@src_path` 现有“类型是 slice、表达式却只输出裸字符串符号”的路径不同。`@embed` 建议直接一步到位输出 slice 表达式，避免局部/参数/返回值/插值时再靠上下文补形状。

对于 `@embed_dir`，还需要补一个固定的结构体声明，但应复用现有“命名结构体 -> struct <safe_name>”规则：

```c
struct EmbedDirEntry {
    struct uya_slice_uint8_t path;
    struct uya_slice_uint8_t data;
};
```

并保证它与 checker 侧合成注入的 `EmbedDirEntry` AST 声明语义一致。

### 4.10 全局初始化

文件：

- `src/codegen/c99/global.uya`

全局切片初始化不能简单复用局部变量路径，因为文件作用域初始化器必须保持 C99 兼容。

建议为 `AST_EMBED` 增加专门分支：

```c
const struct uya_slice_uint8_t g_cert = {
    .ptr = (uint8_t *)uya_embed_0,
    .len = (size_t)731
};
```

不要在全局初始化里输出函数体风格的复合字面量包装。

同理，`AST_EMBED_DIR` 需要支持：

```c
const struct uya_slice_EmbedDirEntry g_assets = {
    .ptr = (struct EmbedDirEntry *)uya_embed_dir_0,
    .len = (size_t)3
};
```

### 4.11 Split-C / 镜像多 TU

文件：

- `src/codegen/c99/utils.uya`

这是设计里的必选项，不能后补。

原因：

- 嵌入常量会被多个 TU 引用
- 只在 `uya_part1.c` 或公共 TU 里定义一次
- 其他 TU 需要 `extern` 声明

因此需要像字符串常量一样：

- 在共享头里为 embed 常量输出 `extern const unsigned char uya_embed_N[];`
- 在共享头里为目录表输出 `extern const struct EmbedDirEntry uya_embed_dir_N[];`
- 确保 `struct EmbedDirEntry` 与 `struct uya_slice_EmbedDirEntry` 进入共享类型头，例如 `uya_part1_types.h`

但 v1 更简单的做法是“不额外导出长度符号”，长度直接写死在切片表达式里，仅导出字节数组符号与目录表符号。

---

## 5. 运行时与安全语义

- `@embed` / `@embed_dir` 都是纯编译期功能，运行时不做文件 I/O。
- 对调用方而言数据应视为只读。
- 当前 C99 slice ABI 的 `ptr` 字段并未严格保留 `const`，因此 codegen 会把 `const unsigned char[]` 转成 `(uint8_t *)` 放进 slice。这是现有 slice const 表达能力的欠账，不是 `@embed` 新引入的问题。
- checker 仍必须把 `@embed` 的结果类型视为 `&[const byte]`，把 `@embed_dir` 的结果类型视为 `&[const EmbedDirEntry]`，并额外拦截 `entries[i].field = ...` 一类成员写入，防止 Uya 代码层面对其写入。

---

## 6. 去重策略

`@embed` 的去重 key：

- `embed_resolved_path`

即：

- 同一文件被同一路径再次引用，只发射一份 blob
- 同内容但不同路径，不做内容级去重

选择这个策略是因为：

- 实现简单
- 错误定位直接对应文件路径
- 不需要在编译器里额外做大块二进制哈希/比较

`@embed_dir` 的目录表去重 key：

- 根目录的 `resolved_path`

目录内部每个文件的数据仍复用文件级二进制常量池。

这里的 `resolved_path` / `root_resolved_path` 都指“绝对 + 规范化”路径，因此同一物理资源即使一处写相对路径、另一处写绝对路径，也应收敛到同一份静态常量。

---

## 7. 测试设计

建议覆盖以下测试面：

### 7.1 正例

- 基本二进制嵌入，读取首字节、中间字节、尾字节
- 含 `0x00` 的文件
- 空文件
- 相对路径解析
- 显式类型的局部声明：`const x: &[const byte] = @embed(...)`
- 作为函数实参传递
- 作为返回值返回
- 全局 `const`/`var` 初始化
- 多模块重复嵌入同一路径，验证只发射一次符号
- 基本目录嵌入，验证 `entries[i].path / entries[i].data`
- 目录递归子目录
- 目录条目排序稳定
- 空目录
- 多模块重复嵌入同一路径目录，验证只发射一次目录表

### 7.2 负例

- 非字符串参数
- 参数个数错误
- 文件不存在
- 传入目录
- 目录不存在
- 目录里出现 symlink/特殊文件
- 超过大小上限

### 7.3 Codegen 验证

- C99 输出包含 `static const unsigned char uya_embed_0[]`
- C99 输出包含 `static const struct EmbedDirEntry uya_embed_dir_0[]`
- `--split-c` 模式下其他 TU 能看到 `extern`
- 生成的切片表达式形如 `{ .ptr = ..., .len = ... }`

---

## 8. 实施顺序建议

推荐顺序：

1. `lexer + ast + parser + fmt`
2. `checker` 路径解析与文件读取
3. 注册内建结构体 `EmbedDirEntry`
4. `codegen` 二进制常量池与目录表池
5. `gen_expr / get_c_type_of_expr / gen_global_init_expr`
6. `split-c extern`
7. 测试
8. 文档补齐到 `docs/builtin_functions.md` 与 `docs/uya.md`

这样可以尽早把“语法能过、类型正确、基础单 TU 可用”打通，再补复杂输出模式。

---

## 9. 关键设计结论

本设计的五个关键结论如下：

1. `@embed` 使用专用 `AST_EMBED`，不走通用 `AST_CALL_EXPR`。
2. `@embed_dir` 使用专用 `AST_EMBED_DIR`，不让 `@embed("dir")` 复用文件语义。
3. `@embed` 的语言类型固定为 `&[const byte]`，`@embed_dir` 的语言类型固定为 `&[const EmbedDirEntry]`。
4. `@embed` / `@embed_dir` 的文件字节都必须使用独立的二进制常量池，不能复用当前基于 C 字符串的 `strN` 机制。
5. `@embed_dir` 目录表本身需要独立的静态表发射与 split-c extern 方案。
