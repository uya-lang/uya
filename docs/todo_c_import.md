# @c_import 实施 TODO

> **归档/核对头（2026-09-27）**：本 TODO 的功能目标已**全部落地**，清单里的复选框是 2026-04 的书写形式，未逐项回填。
>
> - 核对证据：`@c_import` 已进入 lexer 白名单（`src/lexer.uya` 的未知内置错误文案已列出 `@c_import`）、parser（`src/parser/declarations.uya`）、checker（`src/checker/main.uya`、`expr`、`macro_expand`）与构建集成（提交 `fba37b65`）；仓库内有 8 个 `tests/*c_import*` 用例与 `tests/verify_c_import_split_sidecar.sh`、`tests/verify_c_import_symlink_dedupe.sh` 两个验证脚本。
> - 仍有意义的后续（非本 TODO 项）：`@c_import` 与 exec/bytecode 后端的接入，见 `docs/todo_bytecode_exec.md`。
> - 本文件保留为历史实施顺序记录；若发现具体条目未落地，请按条目重新开 issue 而不是沿用本清单状态。

**参考**：[c_import_design.md](./c_import_design.md)  
**目标功能**：

- 新增顶层构建指令 `@c_import("path", cflags?, ldflags?);`
- 将额外 C 源文件纳入 `build/run/test` 构建图
- 支持单个 `.c` 文件
- 支持目录并递归收集所有 `*.c`
- `cflags` 仅作用于该导入展开出的 C 文件，`ldflags` 在最终链接阶段聚合

---

## Phase 1：语法入口与 AST

### 1.1 Lexer

- [ ] 在 [src/lexer.uya](../src/lexer.uya) 的 `TOKEN_AT_IDENTIFIER` 白名单中加入 `c_import`
- [ ] 更新未知内置函数错误文案，把 `@c_import` 列入支持列表
- [ ] 确认 `@c_import` 不影响现有 `@embed` / `@asm` / `@async_fn` 词法路径

### 1.2 AST

- [ ] 在 [src/ast.uya](../src/ast.uya) 增加 `AST_C_IMPORT_DECL`
- [ ] 为 `ASTNode` 增加 `c_import_path_literal`
- [ ] 为 `ASTNode` 增加 `c_import_resolved_path`
- [ ] 为 `ASTNode` 增加 `c_import_cflags_literal`
- [ ] 为 `ASTNode` 增加 `c_import_ldflags_literal`
- [ ] 为 `ASTNode` 增加 `c_import_cflags_normalized`
- [ ] 为 `ASTNode` 增加 `c_import_ldflags_normalized`
- [ ] 为 `ASTNode` 增加 `c_import_expanded_paths`
- [ ] 为 `ASTNode` 增加 `c_import_expanded_rel_paths`
- [ ] 为 `ASTNode` 增加 `c_import_expanded_count`
- [ ] 在 `ast_new_node()` 默认初始化里补齐这些字段

### 1.3 Parser

- [ ] 在 [src/parser/main.uya](../src/parser/main.uya) 的顶层声明入口识别 `@c_import`
- [ ] 新增 `parser_parse_c_import_decl(...)` helper
- [ ] 约束参数个数只能是 1~3
- [ ] 约束所有参数都必须是字符串字面量
- [ ] 参数缺失、缺右括号、缺分号时输出清晰错误信息
- [ ] 明确只允许顶层，函数体内不提供此语法入口
- [ ] 验证首参数既可写单文件 `.c`，也可写目录路径
- [ ] 验证 `std.cfg(...)` 顶层分支里可正常返回 `@c_import`

### 1.4 Formatter

- [ ] 在 [src/fmt.uya](../src/fmt.uya) 增加 `AST_C_IMPORT_DECL` 的格式化输出
- [ ] 保证 `uya fmt` 对 `@c_import("a.c");` 的 round-trip 稳定
- [ ] 保证 1 参数 / 2 参数 / 3 参数三种形态都稳定

---

## Phase 2：Checker 校验与路径规范化

### 2.1 顶层合法性

- [ ] 在 [src/checker/main.uya](../src/checker/main.uya) 为 `AST_C_IMPORT_DECL` 增加检查分支
- [ ] 若 `scope_level > 0`，报“`@c_import` 只能在顶层使用”
- [ ] 为 microapp / container mode 增加拒绝逻辑
- [ ] 新增错误码文案：`E4003: microapp 模式禁止使用 @c_import`

### 2.2 路径解析

- [ ] 仅复用或抽取 [src/checker/check_expr.uya](../src/checker/check_expr.uya) 中“字符串级路径规范化” helper
- [ ] 不直接复用 `@embed` 的 symlink 拒绝逻辑
- [ ] 相对路径按“当前源文件所在目录”解析
- [ ] 做 `.` / `..` / 分隔符规范化
- [ ] 若目标是 symlink，进一步得到 canonical target path
- [ ] 得到稳定 resolved path 并回填 AST
- [ ] 不回退到 `project_root_dir` / `UYA_ROOT`

### 2.3 文件合法性

- [ ] 校验 resolved path 存在
- [ ] 若 resolved path 是文件：校验最终 target 是普通 `.c`
- [ ] 若 resolved path 是目录：递归收集所有 `*.c`
- [ ] 目录遍历时维护 visited canonical directory set，避免 symlink 循环
- [ ] 对收集结果按相对导入根目录的相对路径稳定排序
- [ ] 目录中没有任何 `*.c` 时给出明确错误
- [ ] 明确拒绝既不是 `.c` 文件也不是目录的路径，以及非常规文件
- [ ] 允许 symlink，只要最终 target 是 regular `.c`
- [ ] 诊断里带上 literal path 与 resolved path

### 2.4 Flags 规范化

- [ ] 将缺省 `cflags` / `ldflags` 统一规范为空串
- [ ] 实现最小规范化：trim 首尾空白
- [ ] 实现最小规范化：collapse 连续空白为单个空格
- [ ] 把规范化后的 flags 回填到 AST
- [ ] 明确 v1 不支持复杂 shell quoting，并在文档中写清楚

---

## Phase 3：Program 级 CImportPlan

### 3.1 数据结构

- [ ] 在 [src/main.uya](../src/main.uya) 或新 helper 文件中新增 `CImportItem`
- [ ] 新增 `CImportPlan`
- [ ] 新增 `CompileArtifacts` 或等价输出结构，作为 `compile_files()` 的输出参数
- [ ] 为 `CImportItem` 记录 `resolved_path`
- [ ] 为 `CImportItem` 记录 `relative_path`
- [ ] 为 `CImportItem` 记录 token 化后的 `cflags`
- [ ] 为 `CImportItem` 记录 `cflags_token_count`
- [ ] 为 `CImportItem` 记录声明来源位置（`filename` / `line` / `column`）
- [ ] 为 `CImportPlan` 记录程序级 `aggregated_ldflags_tokens`
- [ ] 为 `CImportPlan` 记录 `aggregated_ldflags_token_count`
- [ ] 如需诊断/sidecar 注释，新增独立的声明级 `ldflags` 片段记录结构，而不是挂在 `CImportItem` 上
- [ ] 为 `CompileArtifacts` 记录 `generated_c_path`
- [ ] 为 `CompileArtifacts` 记录 sidecar 路径（仅 `.c` 输出时使用）

### 3.2 聚合逻辑

- [ ] 在 checker 成功后、codegen 之前收集整份 merged AST 的 `@c_import`
- [ ] 文件模式展开为 1 个文件项
- [ ] 目录模式展开为 N 个文件项
- [ ] 同一路径 + 同 `cflags`：去重
- [ ] 同一路径 + 不同 `cflags`：报冲突错误
- [ ] “直接导入某个 `.c`”与“目录递归导入同一 `.c`”也要在文件项层面正确去重/冲突
- [ ] `ldflags` 不参与编译单元去重 key
- [ ] 程序级 `ldflags` 片段按声明顺序聚合
- [ ] 在聚合阶段把 `cflags` / `ldflags` 按 ASCII 空白做语法级 token 化
- [ ] 对完全相同的 `ldflags token` 序列做稳定去重
- [ ] 冲突诊断要打印两处来源位置
- [ ] 保留最终 items 的稳定顺序，供链接阶段与 split Makefile 使用

### 3.3 与现有路径解耦

- [ ] 确保 `CImportPlan` 不进入类型系统
- [ ] 确保符号表、模块表、函数表无需登记 `@c_import`
- [ ] 确保 AST 合并后不改变 `@c_import` 的声明顺序语义
- [ ] 明确 `compile_files()` 负责填充 `CompileArtifacts`
- [ ] `main()` 在 `compile_files()` 返回后把 `artifacts.c_import_plan` 传给 `link_with_toolchain(...)`
- [ ] split-C 路径通过 codegen setter 或等价方式接收同一份 `CImportPlan`

---

## Phase 4：单文件 build/run/test 链接路径

### 4.1 链接主路径改造

- [ ] 在 [src/main.uya](../src/main.uya) 为 `link_with_toolchain(...)` 增加“存在 `CImportPlan`”分支
- [ ] 为 `link_with_toolchain(...)` 增加 `plan` 参数或等价入参
- [ ] 保留“无 `@c_import` 时走现有单命令链接”路径，避免无谓回归
- [ ] 有 `@c_import` 时切换为“先编译 object、再链接 object”

### 4.2 编译 Uya 主 TU

- [ ] 新增 helper：把 Uya 生成的 `*.c` 编译成临时 `*.o`
- [ ] 继续复用现有全局 `CFLAGS` / target flags / `-fno-inline-small-functions` 逻辑
- [ ] `--nostdlib` 下继续追加 `-fno-stack-protector`

### 4.3 编译导入的 C TU

- [ ] 新增 helper：编译单个 `CImportItem` 到临时 object
- [ ] 该 helper 复用全局 `CFLAGS`
- [ ] 该 helper 额外追加 item 自己的 `cflags`
- [ ] 为每个导入项生成稳定对象名，例如 `uya_cimport_0.o`
- [ ] 编译失败时打印具体 `resolved_path`

### 4.4 最终链接

- [ ] 链接时把 Uya object 与全部 `uya_cimport_N.o` 一起传给宿主编译器
- [ ] 在现有 `LDFLAGS` 后追加 `plan.aggregated_ldflags_tokens`
- [ ] 保留现有 `TARGET_TRIPLE` / `CC_TARGET_FLAGS` 行为
- [ ] `run/test` 直接复用这一条 object-link 路径

---

## Phase 5：split-C / Makefile 路径

### 5.1 Codegen 状态

- [ ] 在 [src/codegen/c99/internal.uya](../src/codegen/c99/internal.uya) 增加 codegen 侧只读 `CImportPlan` 引用
- [ ] 在 `c99_codegen_new(...)` 或对应 setter 中传入该 plan
- [ ] 确保 plan 只用于 Makefile，不影响普通 C 语句发射

### 5.2 Makefile 注入

- [ ] 在 [src/codegen/c99/utils.uya](../src/codegen/c99/utils.uya) 的 `c99_write_split_makefile()` 中追加 `uya_cimport_N.o`
- [ ] 为每个导入项生成单独规则：`uya_cimport_N.o: /abs/path/file.c`
- [ ] 在规则里使用 `$(CC) -c $(CFLAGS) <item.cflags_tokens...> ...`
- [ ] 在最终链接规则里把 `plan.aggregated_ldflags_tokens` 串回 recipe 文本并追加到 `$(LDFLAGS)` 后
- [ ] hosted 模式下仍保留现有 `-lm` 行为

### 5.3 镜像 / 两文件模式兼容

- [ ] 镜像 split-C 下验证 `OBJS` 正确追加 imported objects
- [ ] `uya_part1 + uya_part2` 两文件模式也验证 imported objects 正确追加
- [ ] 确保 `clean` 目标会删除 `uya_cimport_N.o`

### 5.4 Codegen 主循环兼容

- [ ] 在 [src/codegen/c99/main.uya](../src/codegen/c99/main.uya) 的顶层声明遍历中显式跳过 `AST_C_IMPORT_DECL`
- [ ] 确保不会把 `@c_import` 当成未知声明或意外落入其它生成分支

---

## Phase 6：`.c` 输出与 sidecar manifest

### 6.1 sidecar 设计与生成

- [ ] 在 [src/main.uya](../src/main.uya) 检测“输出目标是 `.c` 且 program 含 `@c_import`”
- [ ] 输出主文件 `app.c` 的同时生成 sidecar，例如 `app.cimports.sh`
- [ ] sidecar 采用 POSIX shell 片段格式，便于 `/bin/sh` 用 `.` 加载
- [ ] sidecar 记录 `UYA_CIMPORT_COUNT`
- [ ] sidecar 记录每个 `UYA_CIMPORT_SRC_N`
- [ ] sidecar 记录每个 `UYA_CIMPORT_REL_N`
- [ ] sidecar 记录每个 `UYA_CIMPORT_CFLAGC_N`
- [ ] sidecar 记录每个 `UYA_CIMPORT_CFLAG_N_M`
- [ ] sidecar 记录程序级 `UYA_CIMPORT_LDFLAGC`
- [ ] sidecar 记录程序级 `UYA_CIMPORT_LDFLAG_M`
- [ ] 无 `@c_import` 时不生成 sidecar

### 6.2 外部消费路径

- [ ] 在 [tests/Makefile](../tests/Makefile) 中检测并用 POSIX `. "$$sidecar"` 加载 sidecar
- [ ] 在 [tests/run_programs_parallel.sh](../tests/run_programs_parallel.sh) 中检测并用 POSIX `. "$sidecar"` 加载 sidecar
- [ ] sidecar 存在时，测试链接脚本按 token 数组逐参数构造 argv，先编译 imported C object，再与主 `.c` 一起链接
- [ ] sidecar 不存在时保持当前测试行为不变

### 6.3 预留后续扩展点

- [ ] 在设计与代码注释中预留 future hook，后续可扩展 sidecar Makefile / response file
- [ ] 避免把 v1 方案写死成只能输出 shell fragment 的结构

---

## Phase 7：测试

### 7.1 C 夹具

- [ ] 新增 `tests/fixtures/c_import/` 目录
- [ ] 新增最小正例 C 文件，例如 `add_impl.c`
- [ ] 新增带头文件依赖的正例 C 文件，用于验证 `-I...` 生效
- [ ] 新增需要额外 `ldflags` 的正例用例
- [ ] 新增目录夹具，包含多层子目录和多个 `*.c`

### 7.2 Uya 正例

- [ ] 新增 `tests/test_c_import_basic.uya`
- [ ] 新增 `tests/test_c_import_with_cflags.uya`
- [ ] 新增 `tests/test_c_import_with_ldflags.uya`
- [ ] 新增 `tests/test_c_import_duplicate_same_flags.uya`
- [ ] 新增 `tests/test_c_import_duplicate_extra_ldflags.uya`
- [ ] 新增 `tests/test_c_import_multifile_same_source.uya` 或对应多文件 fixture
- [ ] 新增 `tests/test_c_import_directory_recursive.uya`
- [ ] 新增 `tests/test_c_import_file_and_directory_overlap.uya`
- [ ] 新增 `tests/test_c_import_std_cfg_select.uya`

### 7.3 Uya 反例

- [ ] 新增 `tests/error_c_import_non_top_level.uya`
- [ ] 新增 `tests/error_c_import_not_c_file.uya`
- [ ] 新增 `tests/error_c_import_not_found.uya`
- [ ] 新增 `tests/error_c_import_duplicate_conflict.uya`
- [ ] 新增 `tests/error_c_import_duplicate_cflags_conflict.uya`
- [ ] 新增 `tests/error_c_import_bad_arg_count.uya`
- [ ] 新增 `tests/error_c_import_empty_directory.uya`
- [ ] 新增 `tests/error_c_import_directory_cycle.uya` 或等价目录 symlink 回归
- [ ] 新增 `tests/error_microapp_mode_c_import.uya`
- [ ] 新增“symlink 到 regular .c 可接受”的回归用例

### 7.4 shell 验证

- [ ] 新增 `tests/verify_c_import_split_build.sh`
- [ ] 新增 `tests/verify_c_import_c_output_sidecar.sh`
- [ ] 验证 split Makefile 里出现 `uya_cimport_0.o`
- [ ] 验证可执行文件真的链接到了导入的 C 实现
- [ ] 验证相同路径多模块导入只编译一次
- [ ] 验证相同路径多模块导入且仅 `ldflags` 不同时不会报冲突
- [ ] 验证目录导入会递归收集全部 `*.c`
- [ ] 验证目录导入的顺序稳定
- [ ] 验证 sidecar 里的 token 数组可被 `/bin/sh` 路径正确消费
- [ ] 验证 `run` / `test` 模式复用新路径

### 7.5 回归验证

- [ ] 跑 `make tests-uya`
- [ ] 跑 `./tests/run_programs_parallel.sh`
- [ ] 确认现有 `extern` / `embed` / split-C / microapp 相关测试没有回归

---

## Phase 8：文档

- [ ] 在 [docs/builtin_functions.md](./builtin_functions.md) 增加 `@c_import`
- [ ] 明确说明它是“顶层构建指令”，不是表达式 builtin
- [ ] 在 [docs/uya.md](./uya.md) 的内置/构建章节补齐语义
- [ ] 在 [docs/grammar_quick.md](./grammar_quick.md) 增加速查条目
- [ ] 在 [docs/std_sql.md](./std_sql.md) 的 SQLite / MySQL 示例中给出 `@c_import` 版本
- [ ] 在 [docs/TESTING.md](./TESTING.md) 里补一条“如何写带 `@c_import` 的测试”

---

## Phase 9：后续增强（非 v1 阻塞）

- [ ] 让 [src/compile.sh](../src/compile.sh) 与 `bin/uya build` 的 `@c_import` 行为完全对齐
- [ ] 评估是否需要单独 `@link("...")` 指令来覆盖“无 C 源、只追加系统库”的场景
- [ ] 评估是否扩展到 `.S` / `.cc` / `.cpp`
- [ ] 评估是否用 `@c_import_header` / `@bindgen` 之类能力补齐头文件导入

---

## 验收标准

- [ ] `@c_import` 只能在顶层使用
- [ ] 路径按当前源文件目录解析
- [ ] 接受单个 `.c` 文件
- [ ] 接受目录并递归收集全部 `*.c`
- [ ] symlink 到 regular `.c` 可接受
- [ ] `cflags` / `ldflags` 可省略
- [ ] `cflags` 只作用于该导入展开出的 C 文件
- [ ] `ldflags` 只在最终链接阶段生效
- [ ] 相同路径 + 相同 `cflags` 去重
- [ ] 相同路径 + 不同 `cflags` 报错
- [ ] `ldflags` 不参与编译单元冲突 key，而是程序级聚合
- [ ] `build` / `run` / `test` 均可工作
- [ ] `-o app.c` 会输出 `app.c + app.cimports.sh`
- [ ] split-C 生成的 Makefile 可正确编译 imported objects
- [ ] microapp / container mode 正确拒绝 `@c_import`
