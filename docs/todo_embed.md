# @embed / @embed_dir 实施 TODO

> **核对头（2026-10-19，v0.10.4）**：全部 133 条已勾选并已落地，无未完成项。
> 落点：`src/lexer.uya`（白名单）、`src/parser/primary.uya`（恰好一个字符串字面量）、
> `src/checker/check_expr.uya`（路径解析 / 二进制读取 / 目录递归 / `EmbedDirEntry` 注入）、
> `src/codegen/c99/`（延迟补发射与 split-C 兼容）、`src/fmt.uya`（`AST_EMBED` / `AST_EMBED_DIR` 往返）。
> 回归：`tests/test_embed_builtin.uya`、`tests/verify_embed_*.sh` 与 `tests/error_embed_*.uya`。

**参考**：[embed_design.md](embed_design.md)  
**目标功能**：

- 新增 `@embed("path")`，编译期嵌入单文件并返回 `&[const byte]`
- 新增 `@embed_dir("path")`，编译期嵌入目录并返回 `&[const EmbedDirEntry]`

---

## Phase 1：语法与 AST

### 1.1 Lexer

- [x] 在 [src/lexer.uya](../src/lexer.uya) 内建函数白名单中加入 `embed`
- [x] 在 [src/lexer.uya](../src/lexer.uya) 内建函数白名单中加入 `embed_dir`
- [x] 更新未知内建函数错误信息，把 `@embed` / `@embed_dir` 列入支持列表

### 1.2 AST

- [x] 在 [src/ast.uya](../src/ast.uya) 增加 `AST_EMBED`
- [x] 在 [src/ast.uya](../src/ast.uya) 增加 `AST_EMBED_DIR`
- [x] 在 [src/ast.uya](../src/ast.uya) 为 `ASTNode` 增加 `embed_path_literal / embed_resolved_path / embed_data / embed_size`
- [x] 在 [src/ast.uya](../src/ast.uya) 为 `ASTNode` 增加 `embed_dir_paths / embed_dir_resolved_paths / embed_dir_data / embed_dir_sizes / embed_dir_entry_count`
- [x] 在 `ast_new_node()` 默认初始化中补齐这些字段

### 1.3 Parser

- [x] 在 [src/parser/primary.uya](../src/parser/primary.uya) 解析 `@embed("...")`
- [x] 在 [src/parser/primary.uya](../src/parser/primary.uya) 解析 `@embed_dir("...")`
- [x] 将参数收紧为“恰好一个字符串字面量”
- [x] 为参数个数错误、缺右括号、非字符串参数提供清晰错误信息

### 1.4 Formatter

- [x] 在 [src/fmt.uya](../src/fmt.uya) 增加 `AST_EMBED` 的格式化输出
- [x] 在 [src/fmt.uya](../src/fmt.uya) 增加 `AST_EMBED_DIR` 的格式化输出
- [x] 确保 `uya fmt` 对 `@embed("...")` 往返稳定
- [x] 确保 `uya fmt` 对 `@embed_dir("...")` 往返稳定

---

## Phase 2：Checker 与文件系统读取

### 2.1 路径解析

- [x] 在 [src/checker/check_expr.uya](../src/checker/check_expr.uya) 为 `AST_EMBED` 增加类型推断入口
- [x] 在 [src/checker/check_expr.uya](../src/checker/check_expr.uya) 为 `AST_EMBED_DIR` 增加类型推断入口
- [x] 相对路径按“当前源文件所在目录”解析
- [x] 绝对路径直接使用
- [x] 做 `.` / `..` / 分隔符规范化，得到稳定的 resolved path
- [x] 明确不回退到 `cwd / project_root_dir / UYA_ROOT`

### 2.2 文件与目录读取

- [x] 增加一个专用二进制读取 helper，按 `rb` 方式读取原始字节
- [x] 读取前先获取文件大小
- [x] 文件大小大于 `i32 max` 时直接报错
- [x] 文件内容复制到 compiler arena
- [x] 将 `embed_data / embed_size / embed_resolved_path` 回填到 AST 节点
- [x] 增加目录遍历 helper，递归收集普通文件
- [x] 为目录条目生成相对路径并统一 `/` 分隔符
- [x] 按相对路径排序，保证稳定构建
- [x] 将 `embed_dir_paths / embed_dir_data / embed_dir_sizes / embed_dir_resolved_paths` 回填到 AST 节点
- [x] 对 symlink 与特殊文件给出明确错误

### 2.3 类型系统

- [x] `AST_EMBED` 推断为 `&[const byte]`
- [x] 在 checker 前置阶段合成并注入真实 `AST_STRUCT_DECL EmbedDirEntry { path: &[const byte], data: &[const byte] }`
- [x] `AST_EMBED_DIR` 推断为 `&[const EmbedDirEntry]`
- [x] 确保后续赋值/传参路径把它们当只读切片处理
- [x] 新增 checker 规则：禁止对 `&[const T]` 元素成员做写入，例如 `entries[i].path = ...`
- [x] 验证显式类型的局部声明 `const x: &[const byte] = @embed(...)` 正常
- [x] 验证显式类型的局部声明 `const entries: &[const EmbedDirEntry] = @embed_dir(...)` 正常
- [x] 验证只在类型位置引用 `EmbedDirEntry` 也能编译通过（不依赖程序里必须出现 `@embed_dir(...)` 调用）

---

## Phase 3：C99 二进制常量池与目录表池

### 3.1 内部数据结构

- [x] 在 [src/codegen/c99/internal.uya](../src/codegen/c99/internal.uya) 新增 `EmbeddedBinaryConstant`
- [x] 在 [src/codegen/c99/internal.uya](../src/codegen/c99/internal.uya) 新增 `EmbeddedDirTableConstant`
- [x] 在 `C99CodeGenerator` 中增加 `embedded_constants / embedded_constant_count / embedded_constants_emitted_count`
- [x] 在 `C99CodeGenerator` 中增加 `embedded_dir_tables / embedded_dir_table_count / embedded_dir_tables_emitted_count`
- [x] 增加容量常量，如 `C99_MAX_EMBEDDED_CONSTANTS`

### 3.2 注册与去重

- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 增加 `add_embed_constant`
- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 增加 `add_embed_dir_table`
- [x] 去重 key 先使用绝对规范化后的 `embed_resolved_path`
- [x] 生成稳定符号名，例如 `uya_embed_0`
- [x] 目录表按根目录绝对规范化后的 `resolved_path` 去重，生成稳定符号名，例如 `uya_embed_dir_0`
- [x] 验证同一资源相对/绝对路径混用时只发射一份静态常量

### 3.3 发射

- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 增加 `emit_embed_constants`
- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 增加 `emit_embed_dir_tables`
- [x] 使用 `static const unsigned char uya_embed_N[] = { ... }` 形态输出
- [x] 使用 `static const struct EmbedDirEntry uya_embed_dir_N[] = { ... }` 形态输出目录表
- [x] 空文件发射成 1 字节哨兵数组，切片长度仍写 `0`
- [x] 加一个 `emit_pending_embed_constants`，与延迟注册路径兼容
- [x] 加一个 `emit_pending_embed_dir_tables`，与延迟注册路径兼容
- [x] 目录条目里的 `path` 复用字符串常量池，`data` 复用二进制常量池

---

## Phase 4：表达式、类型查询与全局初始化

### 4.1 表达式 codegen

- [x] 在 [src/codegen/c99/expr.uya](../src/codegen/c99/expr.uya) 增加 `AST_EMBED`
- [x] 在 [src/codegen/c99/expr.uya](../src/codegen/c99/expr.uya) 增加 `AST_EMBED_DIR`
- [x] 输出切片复合字面量：`((struct uya_slice_uint8_t){ .ptr = ..., .len = ... })`
- [x] 输出目录表切片复合字面量：`((struct uya_slice_EmbedDirEntry){ .ptr = ..., .len = ... })`
- [x] 保证局部初始化、函数实参、返回值、结构体字段初始化都能直接复用

### 4.2 `get_c_type_of_expr`

- [x] 在 [src/codegen/c99/types.uya](../src/codegen/c99/types.uya) 让 `AST_EMBED` 返回 `struct uya_slice_uint8_t`
- [x] 在 [src/codegen/c99/types.uya](../src/codegen/c99/types.uya) 让 `AST_EMBED_DIR` 返回 `struct uya_slice_EmbedDirEntry`
- [x] 复用现有命名结构体规则发射 `struct EmbedDirEntry { path: struct uya_slice_uint8_t; data: struct uya_slice_uint8_t; }`
- [x] 确保 `@len(@embed(...))`、字符串插值、其他依赖表达式类型查询的路径不会退化成错误类型
- [x] 确保 `entries[i].path / entries[i].data` 的字段访问类型推断正常

### 4.3 全局初始化

- [x] 在 [src/codegen/c99/global.uya](../src/codegen/c99/global.uya) 为 `AST_EMBED` 增加专用初始化分支
- [x] 在 [src/codegen/c99/global.uya](../src/codegen/c99/global.uya) 为 `AST_EMBED_DIR` 增加专用初始化分支
- [x] 生成文件作用域兼容的初始化器，而不是函数体风格复合字面量
- [x] 覆盖 `const g = @embed(...)` 和显式类型 `const g: &[const byte] = @embed(...)`
- [x] 覆盖 `const g = @embed_dir(...)` 和显式类型 `const g: &[const EmbedDirEntry] = @embed_dir(...)`

---

## Phase 5：预收集与 Split-C

### 5.1 预收集

- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 增加 `collect_embed_constants_from_expr/stmt/decl`
- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 增加 `collect_embed_dir_tables_from_expr/stmt/decl`
- [x] 在 [src/codegen/c99/main.uya](../src/codegen/c99/main.uya) 将 embed 常量发射插入与字符串池相同的阶段
- [x] 在 [src/codegen/c99/main.uya](../src/codegen/c99/main.uya) 将 embed_dir 表发射插入与字符串池相同的阶段

### 5.2 Split-C / 镜像多 TU

- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 的 split extern 逻辑里为 embed 常量生成 `extern const unsigned char uya_embed_N[];`
- [x] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 的 split extern 逻辑里为目录表生成 `extern const struct EmbedDirEntry uya_embed_dir_N[];`
- [x] 确保 `struct EmbedDirEntry` 与 `struct uya_slice_EmbedDirEntry` 进入共享类型头，例如 `uya_part1_types.h`
- [x] 验证 `uya_part2.c` 与镜像模式共享头都能看到这些声明
- [x] 确保 embed 常量只定义一次，不重复发射
- [x] 确保 embed_dir 表只定义一次，不重复发射

---

## Phase 6：测试

### 6.1 正例测试

- [x] 新增基础测试：嵌入一个小二进制文件并验证首尾字节
- [x] 新增零字节测试：文件中包含 `0x00`
- [x] 新增空文件测试
- [x] 新增显式类型局部声明测试：`const x: &[const byte] = @embed(...)`
- [x] 新增函数传参与返回值测试
- [x] 新增全局变量初始化测试
- [x] 新增多模块复用同一路径测试
- [x] 新增相对路径解析测试
- [x] 新增基础目录测试：验证 `entries[i].path / entries[i].data`
- [x] 新增递归目录测试
- [x] 新增空目录测试
- [x] 新增目录条目排序稳定测试
- [x] 新增多模块复用同一路径目录测试
- [x] 新增类型位置仅引用 `EmbedDirEntry` 的回归脚本
- [x] 新增相对/绝对路径混用去重回归脚本

### 6.2 负例测试

- [x] 参数不是字符串字面量
- [x] 参数个数错误
- [x] 文件不存在
- [x] 路径指向目录
- [x] 目录不存在
- [x] 目录中出现 symlink
- [x] `@embed_dir` 传入文件
- [x] 文件超上限

### 6.3 Codegen / 脚本验证

- [x] 新增 shell 验证：C99 输出确实包含 `uya_embed_0`
- [x] 新增 shell 验证：C99 输出确实包含 `uya_embed_dir_0`
- [x] 新增 shell 验证：`--split-c` 时其他 TU 通过 `extern` 成功编译
- [x] 增加 `--nostdlib` 最小 smoke test（`verify_embed_nostdlib.sh`）

---

## Phase 7：文档补齐

- [x] 在 [docs/builtin_functions.md](builtin_functions.md) 增加 `@embed`
- [x] 在 [docs/builtin_functions.md](builtin_functions.md) 增加 `@embed_dir`
- [x] 在 [docs/uya.md](uya.md) 的内置函数章节增加语义说明
- [x] 在 [docs/grammar_quick.md](grammar_quick.md) 增加速查条目

---

## 风险清单

- [x] 当前 slice C ABI 未严格保留 `const` 指针语义，`@embed` 只能先沿用现有只读切片约束
- [x] 二进制常量池不能复用字符串池，否则遇到 `0x00` 会截断
- [x] `@embed_dir` 需要作为真实 AST 结构体注入主流程，不能只做 checker/codegen 私有特判
- [x] 全局初始化与局部表达式初始化的 C99 代码形态不同，不能只修一边
- [x] split-c extern 漏掉会导致多 TU 编译失败
- [x] 目录遍历的排序与分隔符若不稳定，会导致构建产物不稳定

---

## 验收标准

- [x] `@embed("file.bin")` 能在 checker 阶段完成路径解析和文件读取
- [x] `@embed_dir("assets")` 能在 checker 阶段完成目录解析、递归收集与排序
- [x] 返回类型为 `&[const byte]`
- [x] 返回类型为 `&[const EmbedDirEntry]`
- [x] 含零字节、空文件都能正确嵌入
- [x] 目录递归、空目录、稳定排序都正确
- [x] 单 TU 与 split-C 都能通过编译
- [x] 同一路径重复引用只发射一份静态 blob
- [x] 同一路径目录重复引用只发射一份静态目录表
- [x] 同一物理资源相对/绝对路径混用时仍只发射一份静态常量
- [x] `EmbedDirEntry` 可在类型位置单独使用
- [x] 文档已同步到 builtin/functions 说明
