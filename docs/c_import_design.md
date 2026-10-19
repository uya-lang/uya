# @c_import 详细设计

**版本**：v0.1  
**日期**：2026-04-21  
**状态**：已实现（2026-10-19 核对，v0.10.4）

> **实现核对**：
>
> - 语法 `@c_import("path", cflags?, ldflags?)`：最多 3 个字符串字面量参数（`src/parser/declarations.uya` 的
>   `parser_parse_c_import_decl`，顶层入口 `src/parser/main.uya:734`）。
> - AST 节点 `AST_C_IMPORT_DECL` 与 `c_import_*` 字段：`src/ast.uya`。
> - Checker：`src/checker/main.uya` / `check_expr.uya` / `macro_expand.uya`；microapp（容器）模式拒绝使用，
>   报错码为 **`E4005: microapp 模式禁止使用 @c_import`**（不是设计稿里写的 E4003）。
> - 构建计划 `CImportPlan` / `CImportItem`：`src/main.uya`（结构定义）+ `src/driver/toolchain.uya`
>   （`collect_c_import_plan`、cflags 冲突诊断、ldflags token 聚合）。
> - `-o app.c` 输出的 sidecar 名为 `` `<c_path>` + "imports.sh" ``，即 `app.cimports.sh`
>   （`build_c_import_sidecar_path`，`src/driver/toolchain.uya:311`）。
> - split-C：`src/codegen/c99/utils.uya` 的 Makefile 生成器会为每个导入项写 `uya_cimport_N.o` 规则。
> - 回归：`tests/test_c_import_file.uya`、`test_c_import_dir.uya`、`test_c_import_cflags.uya`、
>   `tests/verify_c_import_split_sidecar.sh`、`verify_c_import_symlink_dedupe.sh`。
> - 仍未覆盖：`src/compile.sh` 自身不做 `@c_import` 展开（见 §8.8），exec/bytecode 后端也不接入。

---

## 1. 背景

当前 Uya 已经有比较完整的 C FFI 语义：

- `extern fn`
- `extern struct`
- `extern union`
- `extern var` / `export extern`

但这些能力只解决了“符号如何声明与调用”，没有解决“外部 C 源文件如何进入构建图”。

这导致两个现实问题：

1. 用户写 Uya + C 混合工程时，仍要在命令行或测试脚本里手工追加 `foo.c`
2. 标准库想接入 SQLite、MySQL shim、平台小型桥接层时，无法把“需要额外编译哪些 C 文件、这些文件需要哪些 CFLAGS/LDFLAGS”写回源码本身

仓库里已经有这个痛点的旁证：

- [tests/Makefile](../tests/Makefile) 会对特定测试名硬编码额外的 `test_abi_helpers.c`、`tflm_cmsis_host_stub.c`
- [tests/run_programs_parallel.sh](../tests/run_programs_parallel.sh) 也有同样的 `extra_c_file` 特判
- [docs/std_sql.md](./std_sql.md) 里 SQLite / MySQL 示例仍要求用户自己在 `gcc` 命令后手动追加 `sqlite3.c`、`mysql_shim.c`

因此，`@c_import` 的核心目标不是“再造一个 FFI 调用语法”，而是把 **C 源文件进入构建图** 这件事语言化。

---

## 2. 目标

新增一个顶层构建指令：

```uya
@c_import("path/to/file.c");
@c_import("path/to/dir/");
@c_import("path/to/file.c", "-Ivendor/foo -DFOO=1");
@c_import("path/to/dir/", "-Ivendor/foo -DFOO=1");
@c_import("path/to/file.c", "-Ivendor/foo -DFOO=1", "-lbar -lbaz");
```

能力目标：

- 让 Uya 源码能声明“本模块/本程序需要额外编译一个或多个 C translation unit”
- 路径解析规则与 `@embed` 保持一致，按“当前源文件所在目录”解析相对路径
- 支持传入单个 `.c` 文件
- 支持传入目录，并递归收集其中所有 `*.c`
- `cflags` 仅作用于该导入展开出的 C 文件
- `ldflags` 在最终链接阶段聚合
- `build` / `run` / `test` 可直接生效
- 单文件 C 临时构建路径与 split-C 路径都能工作
- 同一物理 C 文件被多个模块重复声明时可去重
- 同一物理 C 文件被“直接文件导入”和“目录递归导入”重叠命中时也可去重
- 若同一路径给出冲突 flags，编译阶段直接报错
- 与现有 `extern fn` / `extern struct` 体系正交，不破坏现有 FFI 语义

---

## 3. 非目标

v1 明确不做以下事情：

- 不解析 C 头文件，不自动生成 Uya 绑定
- 不等价于 Zig 的 header-style `@cImport`
- 不支持运行时路径，不支持变量、拼接表达式、宏表达式作为参数
- 不支持函数体内、代码块内、方法块内使用；仅允许顶层
- 不支持 `.h` / `.o` / `.a` / `.so` / `.dylib` / `.dll`；v1 仅把单个 regular `.c` 或目录下递归收集到的 `*.c` 纳入构建
- 不做通用 `@link(...)` 指令；如果只想追加系统库而没有 C 源，仍先使用命令行 `LDFLAGS`
- 不保证包含空格的单个 flag token 能正确工作；v1 仅支持“以空白分隔的普通 flag 字符串”
- 不保证 `-o xxx.c` 产出“单文件、完全自包含、离开 sidecar 仍可独立编译”的纯 C 产物；v1 改为输出 `main.c + sidecar manifest`，见 §8.7
- 不在 v1 解决 `src/compile.sh` / 自举链路对 `@c_import` 的完全对齐；见 §8.8

---

## 4. 方案比较

### 4.1 方案 A：把导入的 `.c` 直接 `#include` 到生成的 Uya C 中

看起来最简单，但问题很多：

- `cflags` 无法只作用于导入文件，会污染整份生成的 Uya C
- 导入 `.c` 的宏、`static` 符号、`#pragma` 会泄漏到 Uya 生成代码
- 不同导入文件之间更容易产生静态符号冲突
- split-C 路径下很难定义“应该 include 到哪个 TU”
- `run/test`、普通 build、split Makefile 三条路径会出现三套行为

这个方案实现快，但构建语义不稳定。

### 4.2 方案 B：把导入的 `.c` 当成额外 translation unit，单独编译成 object 后再链接

优点：

- `cflags` 可以天然做到“仅作用于该 C 文件”
- 与现有 `tests/*.c` 手工追加链接的做法一致，只是把脚本特判语言化
- split-C 本来就有 Makefile/object 模型，容易接入
- `extern fn` / `extern struct` 仍然是声明层，`@c_import` 只是构建层，职责清晰

代价：

- 需要给单文件链接路径新增“先编译对象、再链接对象”的分支
- 需要让 split Makefile 认识额外对象和 per-file flags
- 需要新增 program-level build plan 聚合逻辑

**推荐方案**：方案 B。  
`@c_import` 本质上应是 **build graph injection**，不是文本 include。

---

## 5. 用户语义

### 5.1 语法

`@c_import` 是 **顶层构建指令**，不是表达式 builtin。

合法写法：

```uya
@c_import("vendor/sqlite3.c");
@c_import("vendor/sqlite/");
@c_import("vendor/sqlite3.c", "-Ivendor/sqlite -DSQLITE_THREADSAFE=0");
@c_import("vendor/sqlite/", "-Ivendor/sqlite -DSQLITE_THREADSAFE=0");
@c_import("vendor/sqlite3.c", "-Ivendor/sqlite -DSQLITE_THREADSAFE=0", "-ldl -lpthread");
@c_import("vendor/sqlite3.c", "", "-ldl -lpthread");
```

规则：

- 必须写成 `@c_import(...);`
- 只能出现在顶层
- 参数个数只能是 1、2、3
- 第 1 个参数必须是字符串字面量路径
- 第 1 个参数可指向单个 `.c` 文件，或一个目录
- 第 2、3 个参数若出现，也必须是字符串字面量
- 省略参数只能从尾部省略
- 如果只想填 `ldflags`，第 2 个参数写空串 `""`

### 5.2 作用域与生效范围

`@c_import` 是 **整个程序级别** 的构建声明。

这意味着：

- 只要某个被编进来的 `.uya` 文件含有 `@c_import`，该 C 文件就进入当前最终构建
- 它不受运行时控制流影响
- 它不参与类型推断，也没有运行时值

### 5.3 与 `extern` 的关系

`@c_import` 只负责把 C 源文件纳入构建，不负责把 C 声明自动导入 Uya。

用户仍然需要手写 FFI 声明，例如：

```uya
@c_import("tests/fixtures/c_import/add_impl.c");

extern fn add_i32(a: i32, b: i32) i32;
```

也就是说：

- `extern fn` 负责“声明符号”
- `@c_import` 负责“把定义所在的 C 文件编进来”

二者互补，不互相替代。

### 5.4 路径解析

路径解析规则直接对齐 `@embed`：

1. 如果参数是绝对路径，直接使用
2. 如果参数是相对路径，则相对于“写出该指令的源文件所在目录”
3. 对 `.` / `..` / 分隔符做规范化
4. 若规范化后仍是相对路径，再补成绝对路径
5. 用最终 resolved path 做去重与冲突检查

明确不做：

- 不相对于 `project_root_dir`
- 不相对于 `UYA_ROOT`
- 不回退到当前模块名目录

这样能保证多模块复用时语义稳定。

在 resolved path 之后，`@c_import` 分成两种模式：

- **文件模式**：resolved path 指向单个 `.c`
- **目录模式**：resolved path 指向目录；递归收集该目录下所有 `*.c`

目录模式的 v1 规则：

- 递归遍历目录树
- 只收集最终 target 为 regular file 的 `*.c`
- 顶层路径若是 symlink 目录，则先 canonicalize 再遍历
- 遍历时若遇 symlink 目录，允许跟随，但必须维护 visited canonical directory set，避免循环递归
- 收集结果按“相对导入根目录的相对路径”做字典序稳定排序
- 相对路径统一使用 `/`
- 目录中若最终没有任何 `*.c`，报 checker 错误，避免静默 no-op

### 5.5 `cflags` 语义

`cflags` 仅用于编译该导入展开出的 C 文件：

```uya
@c_import("vendor/sqlite3.c", "-Ivendor/sqlite -DSQLITE_THREADSAFE=0");
```

等价于：

- 文件模式：在编译该单个 `.c` TU 时，额外追加这些 flags
- 目录模式：对该目录展开出的每一个 `.c` TU，都额外追加这些 flags

在实现上，v1 不走 shell 语义，而是：

- 先对字符串做最小规范化
- 再按 ASCII 空白做**语法级 token 化**
- 后续命令构造、sidecar 发射、Makefile 发射都基于 token 数组

这意味着 v1 支持：

- `-Ivendor/sqlite -DSQLITE_THREADSAFE=0`

但不支持依赖 shell quoting 才能成立的复杂写法。

它 **不会** 追加到：

- Uya 生成的 `app.c`
- 其它 `@c_import` 进来的 C 文件
- 最终链接命令

### 5.6 `ldflags` 语义

`ldflags` 只在最终链接时使用：

```uya
@c_import("vendor/sqlite3.c", "", "-ldl -lpthread");
```

行为：

- 该字符串不会用于 `cc -c vendor/sqlite3.c`
- 它只会在最后 `cc ... -o app ...` 时聚合进去
- 多个 `@c_import` 的 `ldflags` 按出现顺序追加
- 与 `cflags` 一样，v1 先做最小规范化，再按 ASCII 空白做语法级 token 化
- 即便目录模式展开成多个 `.c`，该 `ldflags` 也只作为这条 import 声明的一份程序级链接输入参与聚合，而不是每个文件重复追加

v1 为了降低复杂度，**不做 token 级语义归并**。  
也就是说：

- 同一路径的重复导入会去重
- 但不同路径带来的 `ldflags` 只做“token 序列完全相同”的稳定去重，不做更激进的语义级合并

### 5.7 重复导入、去重与冲突规则

在去重之前，所有 `@c_import` 都先被展开为扁平文件项：

- 文件模式展开为 1 个文件项
- 目录模式展开为 N 个文件项

随后，扁平文件项按单文件维度去重。

如果多个模块导入同一个 resolved C 路径：

- **编译单元去重 key** 只看：
  - `resolved_path`
  - 规范化后的 `cflags`
- `resolved_path` 相同，且规范化后的 `cflags` 相同：去重，只编译一次
- `resolved_path` 相同，但 `cflags` 不同：报错
- `ldflags` **不参与** 编译单元去重 key；它们是程序级别聚合输入
- 多处声明带来的 `ldflags` 片段按声明顺序聚合；对于完全相同的 token 序列可以做稳定去重，但 v1 不做 token 级语义去重

这条规则同样覆盖：

- 同一个文件被直接 `@c_import("foo.c")` 导入
- 同时又被某个 `@c_import("dir/")` 目录导入间接覆盖到

当同一个 `resolved_path` 以多种来源命中时，`CImportItem.relative_path` 的保留规则建议固定为：

1. 优先保留“来自目录导入”的相对路径
2. 若存在多个目录来源，则取字典序最小的相对路径
3. 若没有目录来源，仅有文件模式直接导入，则 `relative_path` 退化为该文件的 basename

这样做的原因是：

- 目录模式下的相对路径更适合 sidecar、日志和稳定 object 命名
- 字典序最小规则可保证重叠导入时输出稳定
- 直接文件导入也始终能得到一个非空的稳定展示名

示例：

```uya
// a.uya
@c_import("vendor/sqlite3.c", "-Ivendor/sqlite", "-ldl");

// b.uya
@c_import("../project/vendor/sqlite3.c", "-Ivendor/sqlite", "-ldl"); // 去重

// c.uya
@c_import("vendor/sqlite3.c", "-Ivendor/sqlite -DSQLITE_DEBUG=1", "-ldl"); // 报错（cflags 冲突）

// d.uya
@c_import("vendor/sqlite3.c", "-Ivendor/sqlite", "-lpthread"); // 允许；只追加新的程序级 ldflags

// e.uya
@c_import("vendor/"); // 若 vendor/ 递归收集到了 vendor/sqlite3.c，则与 a/b/c/d 在“文件项”层面去重/冲突判断
```

冲突报错建议带上：

- 两处源码位置
- literal path
- resolved path
- 双方 flags

### 5.8 支持模式

v1 推荐支持：

- `uya build app.uya -o app`
- `uya run app.uya`
- `uya test app.uya`
- `uya build app.uya -o app.c --c99`
  - 但不是“单文件纯产物”
  - 而是输出 `app.c` 的同时，再输出 sidecar manifest
- split-C 构建（`--split-c-dir` / 默认 `.uyacache`）
- `--nostdlib`，但导入的 C 文件是否真正 freestanding 由用户自己负责

v1 明确拒绝：

- microapp / container mode

---

## 6. 编译器分层设计

### 6.1 Lexer

文件：

- `src/lexer.uya`

改动：

- 把 `c_import` 加入 `TOKEN_AT_IDENTIFIER` 白名单
- 更新“未知内置”错误提示

虽然 `@c_import` 不是表达式 builtin，但为了沿用现有 `@identifier` 词法入口，lexer 仍可继续产出 `TOKEN_AT_IDENTIFIER`。

### 6.2 AST

文件：

- `src/ast.uya`

建议新增节点：

```uya
AST_C_IMPORT_DECL
```

建议新增字段：

```uya
c_import_path_literal: &byte,
c_import_resolved_path: &byte,
c_import_cflags_literal: &byte,
c_import_ldflags_literal: &byte,
c_import_cflags_normalized: &byte,
c_import_ldflags_normalized: &byte,
c_import_expanded_paths: & & byte,
c_import_expanded_rel_paths: & & byte,
c_import_expanded_count: i32,
```

选择“专用顶层声明节点”的原因：

- 它没有运行时值，不应该塞进表达式系统
- 它需要保存 resolved path、规范化 flags，以及目录模式展开后的文件列表
- checker / build planner / split Makefile 都需要直接读取这些字段

### 6.3 Parser

文件：

- `src/parser/main.uya`
- 可选拆 helper 到 `src/parser/declarations.uya`

解析规则：

- 在顶层 `parser_parse_declaration()` 里识别 `@c_import`
- 期望 `(`
- 解析 1~3 个字符串字面量参数
- 期望 `)`
- 期望 `;`
- 生成 `AST_C_IMPORT_DECL`

注意点：

- 只能在顶层声明位置识别
- 在 block / fn / method block 中不提供此语法入口
- `std.cfg(...)` 分支里如果返回的是顶层声明，允许其中出现 `@c_import`

### 6.4 Formatter

文件：

- `src/fmt.uya`

格式化输出固定为：

```uya
@c_import("path");
@c_import("path", "-Ifoo", "-lbar");
```

不做跨行花活，优先保证 round-trip 稳定。

### 6.5 Checker

文件：

- `src/checker/main.uya`
- 可在 `src/checker/check_stmt.uya` 新增专用检查函数
- 路径字符串规范化逻辑建议复用或抽取 `src/checker/check_expr.uya` 里 `@embed` 的 helper
- 但 **不要** 直接复用 `@embed` 的“拒绝 symlink”文件校验语义

checker 负责：

1. 验证只能出现在顶层
2. 在 microapp / container mode 下报错
3. 解析并规范化路径；若目标是 symlink，则进一步获取其 canonical target path
4. 若目标是单文件：检查最终 target 存在且是普通 `.c` 文件
5. 若目标是目录：递归收集所有 `*.c`，做稳定排序，并写回 `expanded_paths`
6. 规范化 `cflags` / `ldflags`（至少做 trim + collapse whitespace）
7. 把 resolved path、expanded file list 与 normalized flags 回填 AST

建议新增错误：

```text
E4003: microapp 模式禁止使用 @c_import
```

典型诊断：

```text
错误: @c_import 目标必须是单个 .c 文件或包含 .c 的目录
  literal: "vendor/sqlite3.h"
  resolved: /abs/path/vendor/sqlite3.h
```

### 6.6 Program 级 Build Plan 与产物传递

文件：

- 建议放在 `src/main.uya`
- 或新建独立 helper 文件，供 `main.uya` 与未来 `compile.sh` 对齐使用

建议新增结构：

```uya
struct CImportItem {
    resolved_path: &byte,
    relative_path: &byte,
    cflags_tokens: & & byte,
    cflags_token_count: i32,
    filename: &byte,
    line: i32,
    column: i32,
}

struct CImportPlan {
    items: &CImportItem,
    item_count: i32,
    aggregated_ldflags_tokens: & & byte,
    aggregated_ldflags_token_count: i32,
    // 可选：保留“每条原始 @c_import 声明贡献了哪些 ldflags”用于诊断/sidecar 注释
}

struct CompileArtifacts {
    generated_c_path: &byte,
    c_import_plan: CImportPlan,
    c_import_sidecar_path: &byte, // 仅在 -o *.c 时使用
}
```

聚合时机建议放在：

- checker 成功之后
- C99 codegen 之前

原因：

- 这时 AST 已是最终 merged program
- 路径与 flags 已经校验完
- 目录 import 已经被稳定展开成扁平文件列表
- 单文件链接路径和 split-C Makefile 路径都能复用同一份 plan

实现上建议明确为：

- `compile_files(..., out_artifacts: &CompileArtifacts)` 负责填充 `CImportPlan`
- `main()` 在 `compile_files()` 返回后，把 `artifacts.c_import_plan` 传给：
  - 单文件 `link_with_toolchain(...)`
  - split-C codegen / Makefile 路径
  - `-o *.c` 的 sidecar manifest 发射路径

不要把这份 plan 隐式塞进临时全局状态，否则后续 `run/test/build` 三条路径容易再出现重复收集。

### 6.7 单文件 build/run/test 链接路径

当前 `link_with_toolchain()` 假设只有一份 Uya 生成的 C 文件。  
当 `CImportPlan` 非空时，建议切换为“两阶段”：

1. 编译 Uya 生成的 C 为 object
2. 编译每个导入展开出的 C 为 object（追加该 item 的 `cflags_tokens`）
3. 链接全部 objects（追加全局 `LDFLAGS` + `plan.aggregated_ldflags_tokens`）

推荐命令形态：

```text
cc [target_flags] [global_cflags] -c uya_generated.c -o uya_generated.o
cc [target_flags] [global_cflags] [item.cflags_tokens...] -c vendor/foo.c -o uya_cimport_0.o
cc [target_flags] [global_cflags] uya_generated.o uya_cimport_0.o -o app [global_ldflags] [plan.aggregated_ldflags_tokens...]
```

这样做的关键收益：

- 每个 `@c_import` 真正拥有自己的 `cflags`
- `run/test` 路径虽然仍强制单文件 Uya C，但不影响额外 C 文件作为独立 TU 编译

### 6.8 split-C / Makefile 路径

文件：

- `src/codegen/c99/internal.uya`
- `src/codegen/c99/main.uya`
- `src/codegen/c99/utils.uya`

建议做法：

- `C99CodeGenerator` 持有只读 `CImportPlan`
- `c99_write_split_makefile()` 根据 plan 生成额外 object 规则
- `OBJS` 里追加 `uya_cimport_N.o`
- 链接规则把 `plan.aggregated_ldflags_tokens` 串回 recipe 文本并追加到链接命令尾部

示意：

```make
OBJS := uya_part1.o uya_common.o foo/bar.o uya_cimport_0.o uya_cimport_1.o uya_cimport_2.o

uya_cimport_0.o: /abs/vendor/sqlite3.c
	$(CC) -c $(CFLAGS) -Ivendor/sqlite -DSQLITE_THREADSAFE=0 /abs/vendor/sqlite3.c -o uya_cimport_0.o

uya_cimport_1.o: /abs/vendor/sqlite/ext/helper.c
	$(CC) -c $(CFLAGS) -Ivendor/sqlite -DSQLITE_THREADSAFE=0 /abs/vendor/sqlite/ext/helper.c -o uya_cimport_1.o

$(UYA_OUT): $(OBJS)
	$(CC) $(OBJS) -o $(UYA_OUT) $(LDFLAGS) -ldl -lpthread -lm
```

这里不需要把导入的 `.c` 再织入 Uya 生成的 `.c`，只需让 Makefile 多认识几个对象即可。

### 6.9 Codegen 本体如何看待 `AST_C_IMPORT_DECL`

`AST_C_IMPORT_DECL` 本身 **不生成任何 C 语句**。

它只影响：

- build plan
- split Makefile
- 可选的文件头注释

因此 codegen 主循环里对它应当显式“跳过但不报未知节点”。

### 6.10 `run/test` 路径

当前 `run/test` 已经会强制关闭 split-C，生成临时单文件 Uya C 再立即链接执行。  
这对 `@c_import` 不是问题：

- Uya 主体仍走“临时单文件 C”
- 额外 C 文件照样单独 `cc -c`
- 最后统一链接成临时可执行文件

所以 `run/test` 不需要单独语义，只要复用单文件 object-link 路径即可。

### 6.11 `-o *.c` 输出路径

方案 B 仍然可以支持 `-o app.c`，但输出结果不再是“单文件即可完整复现构建”的产物。

推荐行为：

- 生成主文件：`app.c`
- 同目录生成 sidecar manifest：`app.cimports.sh`

sidecar 采用 **POSIX shell 片段** 格式，要求能被：

- `/bin/sh` 里的 `. ./app.cimports.sh`
- bash 里的 `source ./app.cimports.sh`

直接消费。

为避免再做不安全分词，sidecar 不存“整串 flags”，而存 **token 化后的 argv 数据**，例如：

```sh
UYA_CIMPORT_COUNT='1'
UYA_CIMPORT_SRC_0='/abs/vendor/sqlite3.c'
UYA_CIMPORT_REL_0='sqlite3.c'
UYA_CIMPORT_CFLAGC_0='2'
UYA_CIMPORT_CFLAG_0_0='-Ivendor/sqlite'
UYA_CIMPORT_CFLAG_0_1='-DSQLITE_THREADSAFE=0'
UYA_CIMPORT_LDFLAGC='2'
UYA_CIMPORT_LDFLAG_0='-ldl'
UYA_CIMPORT_LDFLAG_1='-lpthread'
```

这样：

- `tests/Makefile` 和 `tests/run_programs_parallel.sh` 可以用 POSIX `.` 直接加载这个文件
- 用户手工 `gcc` 也能据此拼出正确命令
- 链接脚本可以逐 token 构造 argv，不需要 `eval`
- 仍然保持方案 B 的“额外 TU + per-file cflags”语义

如果程序不含 `@c_import`，则不生成 sidecar。

---

## 7. 与现有能力的关系

### 7.1 与 `@embed` 的关系

二者都需要：

- 源文件相对路径解析
- resolved path 规范化
- 在 AST 上保存编译期产物

区别是：

- `@embed` 产出表达式值，进入 type/codegen
- `@c_import` 产出 build metadata，进入 link/Makefile

因此路径解析 helper 应尽量复用，但 AST/检查/代码生成入口不应混用。
另外，`@embed` 出于资源确定性会拒绝 symlink；`@c_import` 不应默认继承这个限制。

### 7.2 与 `extern "libc"` 的关系

`extern "libc"` 影响的是：

- 符号名是否裸名
- FFI 指针类型是否合法

`@c_import` 影响的是：

- 额外 C 源是否被编译
- 使用哪些 per-file build flags

两者完全正交。

### 7.3 与 `std.cfg` 的关系

`@c_import` 是顶层声明，因此应天然支持：

```uya
std.cfg(
    std.target_os == .tos_linux,
    @c_import("platform/linux/"),
    @c_import("platform/fallback/")
);
```

这样平台特定的 shim 可以按现有顶层裁枝体系接入，而不需要新发明条件链接语法。
这里故意使用当前 parser 已支持的 selector 语法：

- `std.host_os`
- `std.host_arch`
- `std.target_os`
- `std.target_arch`

### 7.4 与 microapp / container mode 的关系

microapp 模式强调可移植、可裁剪、受控宿主接口。  
把任意宿主 C 文件直接纳入构建，会破坏这层边界。

因此建议：

- 在 `checker.container_mode != 0` 时直接拒绝用户代码里的 `@c_import`
- 诊断沿用现有 `E4001/E4002` 风格，新增 `E4003`

### 7.5 与 `--nostdlib` 的关系

`@c_import` 本身不应禁止 `--nostdlib`。

但要明确：

- 编译器只负责按当前 freestanding 规则去编译和链接
- 被导入的 C 文件若偷偷依赖 libc，那是用户自己的构建选择
- 如果导入文件需要 `-fno-stack-protector` 或特定 freestanding flag，用户应写到 `cflags`

---

## 8. 边界与取舍

### 8.1 为什么不自动从 C 头文件生成 Uya 声明

这是另一条完整功能线，至少会涉及：

- 预处理器
- C 语法前端
- 类型映射
- 宏处理
- 名称导入策略

明显超出当前需求。  
`@c_import` 应先解决“把 C 文件编进来”，不解决“自动绑定 C API”。

### 8.2 为什么只支持 `.c`

当前宿主工具链驱动统一走 `cc`，并没有 C++/汇编单独策略。  
先把 `.c` 做扎实，比一开始把 `.cc/.cpp/.S` 全部打开更稳。

### 8.3 为什么 `cflags` 只作用于导入文件

这是整套设计最重要的稳定性来源。

如果 `cflags` 同时污染 Uya 主体生成的 C：

- 会引入难以定位的 ABI 差异
- 会让一个 shim 的 `-D` 影响其它导入文件
- 会让“同样的 Uya 代码，因为是否导入某个 C 文件而改变主 TU 编译结果”

这不符合构建隔离预期。

### 8.4 为什么只对 `cflags` 冲突直接报错

同一路径给不同 **`cflags`**，本质上就是在问：

- 我们到底要编译哪一份对象？
- 最终链接进来的是哪一种 ABI / 宏配置？

静默选择一边会制造隐蔽问题。  
因此应该显式报错，让调用方统一配置。

但 **`ldflags` 不一样** 时语义不同：

- 它们不改变该 `.c` 的编译结果
- 它们只是给最终程序补链接依赖

因此更合理的策略是：

- `cflags` 决定编译单元 identity
- `ldflags` 走程序级聚合

### 8.5 flags 规范化策略

v1 建议最小规范化：

- `null` -> `""`
- trim 首尾空白
- collapse 连续空白为单个空格

这样能避免最常见的“只是空格数量不同却被判冲突”。
对于 `ldflags`，还可以在“token 序列完全相同”时做稳定去重。

v1 不做：

- shell quoting 解析
- token 级语义去重
- `-Ifoo` 与 `-I foo` 等价归一

### 8.6 链接顺序

建议策略：

- object 列表始终在前
- 全局 `LDFLAGS` 在 object 之后
- `CImportPlan` 聚合后的 `ldflags token` 再按声明顺序追加

理由：

- 与当前 `link_with_toolchain()` 的整体风格接近
- 用户若有更复杂静态库顺序需求，仍可通过命令行 `LDFLAGS` 控制

### 8.7 为什么 v1 的 `-o xxx.c` 需要 sidecar manifest

当用户要求“只输出单个 C 文件”时，当前 Uya 的语义是：

- 生成一份可以单独交给 `cc` 的 C 源

但 `@c_import` 带来的额外信息不是 C 语法本体，而是：

- 额外 translation unit
- 每个 TU 的专属 `cflags`
- 最终 link 时的 `ldflags`

在方案 B 下，要支持 `-o xxx.c`，就必须额外提供：

- sidecar manifest
- 或 sidecar Makefile

其中 sidecar manifest 是最轻量的折中：

- 主体仍保持方案 B，不把 imported `.c` 文本塞进主 TU
- 现有测试脚本和用户手工 gcc 路径可以继续工作
- 不会让 `cflags` 泄漏到 Uya 主 TU
- 可以直接复用内部已经 token 化的 argv 数据结构

因此推荐 v1 行为：

- 如果程序包含 `@c_import`
- 且用户输出目标是 `app.c`
- 则同时生成 `app.cimports.sh`
- 不再要求 `app.c` 单独就是完整构建描述

### 8.8 为什么 v1 暂不覆盖 `src/compile.sh`

`src/compile.sh` 当前大量依赖“先生成单个 `.c`，再直接 `cc` 它”的模型。  
而 `@c_import` 的推荐实现是“额外 TU + per-file flags”。

如果要让自举链也完全等价，需要至少补其中一条：

1. `compile.sh` 学会消费 build plan 并单独编译 imported C
2. 同时也学会在 `-o xxx.c` 路径生成并消费 sidecar manifest

这属于第二阶段工作。  
因此 v1 应先把功能落在 `bin/uya build/run/test` 用户入口与测试脚本路径，避免首版一次改太深。

---

## 9. 示例

### 9.1 最小示例

```uya
use std.runtime.entry;

@c_import("tests/fixtures/c_import/add_impl.c");

extern fn add_i32(a: i32, b: i32) i32;

export fn main() i32 {
    return add_i32(10, 32);
}
```

### 9.2 SQLite 示例

```uya
use std.runtime.entry;

@c_import(
    "third_party/sqlite/sqlite3.c",
    "-Ithird_party/sqlite -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION=1",
    "-ldl -lpthread"
);

extern fn sqlite3_open(filename: *byte, db: **void) i32;
extern fn sqlite3_close(db: *void) i32;
```

### 9.3 平台裁枝示例

```uya
std.cfg(
    std.target_os == .tos_linux,
    @c_import("platform/linux/"),
    @c_import("platform/fallback/")
);
```

---

## 10. 验收标准

- `@c_import("foo.c");` 能在顶层被正确解析
- `@c_import("dir/");` 能在顶层被正确解析
- `cflags` / `ldflags` 可省略，省略后视为空串
- 相对路径按当前源文件目录解析
- 目标既不是单个 `.c`，也不是目录时，checker 阶段报错
- symlink 到 regular `.c` 的目标可被接受
- 目录导入会递归收集全部 `*.c`
- 目录导入按相对路径稳定排序
- 目录导入若无任何 `*.c`，会给出明确错误
- 同一路径 + 同 `cflags` 只编译一次
- 同一路径 + 不同 `cflags` 明确报错
- `ldflags` 走程序级聚合，不参与编译单元冲突键
- `build` 可成功编译并链接导入的 C 文件
- `run` / `test` 可复用同一能力
- `-o app.c` 会生成 `app.c + app.cimports.sh`
- split-C 生成的 Makefile 包含额外 C object 规则
- microapp / container mode 下会拒绝 `@c_import`

---

## 11. 推荐落地顺序

1. Lexer / AST / Parser / Formatter
2. Checker 路径解析与合法性校验
3. Program 级 `CImportPlan` 聚合
4. 单文件 build/run/test 的 object-link 路径
5. split-C Makefile 注入
6. 目录 import 展开、排序、文件项去重
7. `-o *.c` sidecar manifest 与测试脚本接入
8. 文档与测试
9. 后续再做 `src/compile.sh` 对齐
