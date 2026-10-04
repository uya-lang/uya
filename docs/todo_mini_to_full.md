# Uya Mini 到完整版待办文档

> **核对头（2026-09-27）**：本文件是 2026-05 的历史路线图，46 个未勾选条目中有相当部分**已落地**：
> `uya build/run/test`（含 `check`）命令、原子类型、`nostdlib`/freestanding 路线、`std.core`/`std.io`/`std.collections`/`std.mem`/`std.fmt`/`std.net` 等模块、`test "name" {}` 测试格式。
> 本文件最后更新已 3 个月以上，**不要再把它当当前进度表**；具体缺口以 `buglist.md`、`docs/async_status_matrix.md`、`docs/uyagin_todo.md` 与各专项 TODO 为准。

基于项目根目录 [uya.md](uya.md) 完整规范。实现时按「建议实现顺序」执行，每项需在自举编译器中实现，测试需同时通过 `--c99` 与 `--uya --c99`。

**实现约定**：在编写编译器代码前，先在 `tests/` 添加测试用例（如 `test_xxx.uya` 或预期编译失败的 `error_xxx.uya`），覆盖目标场景；实现后再跑 `--c99` 与 `--uya --c99` 验证，二者都通过才算通过。

---

## AI 开发流程（必读）

**基于本文档做开发时，必须按以下流程执行**：

| 阶段 | 操作 |
|------|------|
| **开始前** | `make backup` 验证当前状态（bin/uya 不存在则先 `make from-c`） |
| **新功能** | 1. 在 tests/ 添加 test "name" {} 测试 → 2. `make tests` 确认失败（红）→ 3. 实现代码 → 4. `make tests` 通过（绿） |
| **修 Bug/重构** | 修改后执行 `make backup` 验证 |
| **提交前必做** | **必须**执行 `make backup`，并将 `backup/uya.c` 一起提交（backup 包含自举+测试验证；否则 `make clean` 后无法恢复） |
| **禁止** | 测试失败时提交代码；跳过 `make backup` 即提交 |

**语法规范文档版本同步**：
- 若修改 `docs/uya.md`、`docs/grammar_formal.md`、`docs/grammar_quick.md` 或 `docs/builtin_functions.md` 的语法/语义/内建说明，必须同步升级这组语法规范文档的版本号，并保持版本引用一致。

详细规范见 [.codebuddy/rules/uya-dev-flow.mdc](../.codebuddy/rules/uya-dev-flow.mdc)。

---

## 版本里程碑

| 版本 | 名称 | 状态 | 说明 |
|------|------|------|------|
| **v0.5.9** | --outlibc | ✅ 完成 | 生成独立 libc 库 |
| **v0.5.8** | 零依赖构建 | ✅ 完成 | 编译器 -nostdlib 构建 |
| **v0.5.7** | 调试打印 | ✅ 完成 | @print/@println 内置函数 |
| **v0.5.0** | 内存安全证明 | ✅ 完成 | 约束系统 + 符号执行 |
| **v0.6.0** | 标准库重构 | 🚧 进行中 | std 使用现代特性，libc 薄封装 |
| **v0.7.0** | 异步完善 | 🚧 进行中 | 基础状态机/运行时已打通，剩余泛型队列、取消与跨平台扩展 |

---

## 建议实现顺序（总览）

| 序号 | 阶段 | 状态 |
|------|------|------|
| 0 | 规范同步：内置函数以 @ 开头 | [x] |
| 0.1 | **规范同步：内置函数命名统一（@sizeof→@size_of）** | [x] **优先** |
| 1 | 基础类型与字面量 | [x] |
| 2 | 错误处理 | [x] |
| 3 | defer / errdefer | [x] |
| 4 | 切片 | [x] |
| 5 | match 表达式 | [x] |
| 6 | for 扩展 | [x]（整数范围已实现；迭代器已实现，C 实现与 uya-src 已同步） |
| 7 | 接口 | [x]（C 实现与 uya-src 已同步） |
| 8 | 结构体方法 + drop + 移动语义 | [x]（外部/内部方法、drop/RAII、移动语义 C 实现与 uya-src 已同步） |
| 9 | 模块系统 | [x]（C 实现与 uya-src 已同步：目录即模块、export/use 可见性检查、模块路径解析、错误检测、递归依赖收集） |
| 10 | 字符串插值 | [x] |
| 11 | 原子类型 | [x]（C 实现与 uya-src 已同步，测试通过） |
| 12 | 运算符与安全 | [x]（饱和/包装运算、as! 已实现；内存安全证明 v0.48 已完成） |
| 13 | 联合体（union） | [x]（C 实现与 uya-src 已同步） |
| 14 | 消灭所有警告 | [x]（主要工作已完成，剩余问题见下方说明） |
| 15 | 泛型（Generics） | [x]（C 实现与 uya-src 已同步，类型推断与约束检查完成） |
| 16 | 异步编程（Async） | [x]（C 实现与 uya-src 已同步；`Future<!T>` 主路径 + `!Future<T>` 兼容路径、单/多 `@await` 状态机与 `std.async` 最小闭环已完成；编译期状态机大小计算（真实类型大小）、`@await` 上限 32 / 参数上限 16 的校验已落地） |
| 17 | test 关键字（测试单元） | [x]（C 实现与 uya-src 已同步） |
| 18 | **宏系统（Macro）** | [x] C 实现与 uya-src 已同步 |
| 19 | **标准库基础设施（std）** | [ ] **重要** |
| 20 | **@print/@println 内置函数** | [x] **v0.5.7 已完成** |
| 21 | **结构体默认值语法** | [x] 规范 §4.3（v0.2.31 已完成，C 实现与 uya-src 已同步） |
| 22 | **类型别名（type）** | [x] 规范 §5.2、§24.6.2（v0.2.31 已完成，C 实现与 uya-src 已同步） |
| 23 | **多维数组** | [x]（C 实现与 uya-src 已同步） |
| 24 | **块注释** | [x]（C 实现与 uya-src 已同步，支持嵌套） |
| 25 | **内存安全证明** | [x] 规范 §14（v0.48 已完成：约束系统+符号执行+区间分析+空指针检测+未初始化检测；v0.49 增强：交换律+线性表达式+const识别+错误去重） |
| 26 | **并发安全** | [ ] 规范 §15（依赖原子类型） |
| 27 | **接口组合** | [x]（C 实现与 uya-src 已同步，v0.2.30 已完成） |
| 28 | **源代码位置内置函数** | [x]（@src_name/@src_path/@src_line/@src_col/@func_name，v0.2.31 已完成） |
| 29 | **数字字面量增强** | [x]（十六进制/八进制/二进制、下划线分隔符，v0.2.32 已完成） |
| 30 | **只读指针类型 `&const T` 和 `*const T`** | [x] **规范 0.42 新增**（C 实现与 uya-src 已同步，标准库已更新，测试用例已通过） |
| 31 | **函数导出规则完善（static/export/extern）** | [x] **规范 0.42 新增**（C 实现与 uya-src 已同步，测试用例已通过） |
| 32 | **指针转换内置函数（@ptr_from_usize/@usize_from_ptr）** | [x] **TDD 完成**（C 实现与 uya-src 已同步，测试用例通过） |
| 33 | **新标准库系统调用层（std.syscall）** | [x] **已完成**（lib/std/syscall/linux.uya，测试用例通过） |
| 34 | **新标准库运行时支持（std.runtime）** | [x] **已完成**（lib/std/runtime/runtime.uya 已实现，编译和类型检查通过，链接时与 bridge.c 冲突是预期的，待移除 bridge.c 后验证） |
| 35 | **新标准库内存操作（std.mem）** | [x] **已完成**（lib/std/mem/mem.uya 已实现，包含 memcpy, memset, memmove, memcmp, memchr，测试用例通过） |
| 36 | **新标准库字符串操作（std.string）** | [x] **已完成**（lib/std/string/string.uya 已实现，包含 strlen, strcmp, strncmp, strcpy, strncpy, strcat, strchr, strrchr, strstr，测试用例通过） |
| 37 | **新标准库文件 I/O（std.io）** | [x] **已完成**（lib/std/io/file.uya 和 lib/std/io/stream.uya 已实现，包含 fopen, fclose, fread, fwrite, fgetc, fputc, fputs, fprintf, fflush，测试用例通过） |
| 38 | **新标准库 JSON（std.json）** | [x] Phase 1–3 已完成：解析器、编码器、`to_json<T>`/`from_json<T>` 反射（按结构体字段自动生成，无需方法块）；标量及多字段结构体往返测试通过；含嵌套/数组的 from_json 暂用默认实现。可选：Phase 4 SIMD（**优先 `@vector`/`@mask`**，可选 Phase 5 `@asm`）、大文件 benchmark。详见 [todo_json.md](todo_json.md)、[json_design.md](json_design.md) |
| 38.1 | **新标准库 HTTP（std.http）** | [~] `lib/std/http/`：`types` / `parse` / `router` / `server`（阻塞、Keep-alive）；路线图与测试要求见 [todo_http.md](todo_http.md)、[readme.md](../readme.md) §标准库 HTTP |
| 38.2 | **新标准库 Crypto（std.crypto）** | [x] `lib/std/crypto/`：`blake2b_digest`、`blake2s_digest`、`blake3_digest`、`sha256_digest`、`hmac_sha256`、`md5_digest`、`crc32_compute`；测试 `test_crypto_blake2b.uya` / `test_crypto_blake2s.uya` / `test_crypto_blake3.uya` / `test_crypto_sha256.uya` / `test_crypto_hmac_sha256.uya` / `test_crypto_md5.uya` / `test_crypto_crc32.uya` |
| 38.3 | **新标准库 SQL（std.sql）** | [~] `lib/std/sql/`：`types` / `driver` / `db` 已落地，提供 `Value`、`NamedArg`、`Driver`、`Conn`、`Stmt`、`Rows`、`Tx`、`DB` 等通用抽象；fake driver 回归 `tests/test_std_sql.uya` 已通过。SQLite / MySQL 等真实驱动待接入，说明见 [std_sql.md](std_sql.md) |
| 39 | **新标准库 YAML（std.yaml）** | [ ] 高性能 YAML 编解码器，详见 [todo_yaml.md](todo_yaml.md)、[yaml_design.md](yaml_design.md) |
| 40 | **新标准库 Protobuf（std.protobuf）** | [ ] 高性能 Protobuf 编解码器，详见 [todo_protobuf.md](todo_protobuf.md)、[protobuf_design.md](protobuf_design.md) |
| 41 | **统一命令行接口（build/check/run/test）** | [ ] **进行中**（详见 tests/MIGRATION_TODO.md） |

标准库分层重构（std → libc → osal → syscall）的详细任务见 [todo_std_refactor.md](todo_std_refactor.md)。

---

## 下次优先实现（规范 0.42 变更）

### 0.42 只读指针类型和函数导出规则（新增）

- [x] **只读指针类型 `&const T` 和 `*const T`**：
  - **语法**：新增 `&const T` (Uya 内部只读引用) 和 `*const T` (FFI 只读指针) 语法
  - **语义**：在类型系统中明确区分可变和只读指针，提升类型安全和 C 互操作性
  - **C 映射**：`&const T` 和 `*const T` 均映射为 `const T*`
  - **字符串字面量**：`"..."` 可赋值给 `[byte: N]`、`&byte`、`*byte`，语义上自动带 `\0` 结尾（规范见 uya.md §1.4）
  - **FFI 函数签名**：C 标准库中接受 `const char *` 的函数，在 `extern` 声明中应使用 `*const byte`
  - **类型转换规则**：
    - `&T` 可以隐式转换为 `&const T`（放宽约束，安全）✅ 已实现
    - `&const T` 不能隐式转换为 `&T`（收紧约束，需要显式转换）✅ 已实现
    - `&T` 可以通过 `as *const T` 显式转换为 `*const T`（待实现）
    - `&const T` 可以通过 `as *const T` 显式转换为 `*const T`（待实现）
  - **实现待办**：
    - [x] **Lexer**：识别 `&const` 和 `*const` 关键字（通过 `TOKEN_CONST` 识别）
    - [x] **AST**：扩展 `AST_TYPE_POINTER` 节点，添加 `is_const` 标志
    - [x] **Parser**：解析 `&const T` 和 `*const T` 类型语法
    - [x] **Checker**：类型检查时处理 `&const T` 的隐式转换和约束检查（`type_from_ast`、`type_equals`、`checker_check_expr_type`、`type_can_implicitly_convert`）
    - [x] **Codegen**：根据 `is_const` 标志生成 `const T*` 类型
    - [x] **标准库更新**：更新标准库函数签名，使用 `&const byte` 替代 `&byte`（只读参数）✅ 已完成（string.uya、stdio.uya、stdlib.uya）
    - [x] **测试用例**：添加 `&const T` 语法的测试用例，验证类型转换规则✅ 已完成（test_const_pointer.uya、test_const_pointer_simple.uya 通过 `--c99` 测试）

- [x] **函数导出规则完善**：
  - **函数可见性规则**：
    - `fn foo() void` → `static void foo(void)`（内部函数，不导出）✅ 已实现
    - `export fn foo() void` → `void foo(void)`（导出函数，供其他模块使用）✅ 已实现
    - `extern fn foo() void` → `extern void foo(void);`（外部 C 函数声明）✅ 已实现
    - `export extern fn foo() void` 或 `extern export fn foo() void` → `extern void foo(void);`（导出外部 C 函数，FFI，两种顺序等价）✅ 已实现
  - **实现待办**：
    - [x] **Parser**：解析 `export` 和 `extern` 关键字（支持两种顺序：`export extern` 和 `extern export`）
    - [x] **AST**：在函数节点中记录 `is_export` 和 `is_extern` 标志
    - [x] **Codegen**：根据 `is_export` 标志决定是否添加 `static` 关键字（`gen_function_prototype` 和 `gen_function`）
    - [x] **测试用例**：验证函数导出规则，确保生成的 C 代码正确✅ 已添加 test_function_export.uya、test_export_for_c.uya、test_export_for_c_complete.uya（通过 `--c99` 测试）

**参考文档**：
- [uya.md](uya.md) §0.42 - 规范变更说明
- [uya.md](uya.md) §2.1.1 - 指针类型说明
- [uya.md](uya.md) §5.1 - 函数定义语法
- [uya.md](uya.md) §5.2 - 外部 C 函数（FFI）

---

## 下次优先实现（统一命令行接口）

### 命令行接口标准化（build/check/run/test）

- [ ] **统一应用程序入口点**：
  - 应用程序必须包含 `export fn main() !int` 或 `export fn main() int`
  - 编译器自动包含 `std.runtime.entry` 模块
  - 用户无需手动写 `use std.runtime.entry;`

- [ ] **`uya build` 命令**：
  - 编译为可执行文件：`uya build main.uya -o myapp`
  - 支持现有参数：`--c99`、`--outlibc` 等

- [ ] **`uya check` 命令**：
  - 仅执行到 checker：`uya check main.uya`
  - 不生成 C、不链接、不运行

- [ ] **`uya run` 命令**：
  - 编译并运行：`uya run main.uya`
  - 传递运行时参数：`uya run main.uya -- --args`

- [ ] **`uya test` 命令**：
  - 运行测试：`uya test tests.uya`
  - 允许没有 `export fn main`
  - 收集所有 `test "name" {}` 块
  - 自动生成 main 函数运行测试

- [ ] **测试文件格式迁移**：
  - 旧格式（约 89 个待迁移文件）：
    ```uya
    use std.runtime.entry;
    use std.testing.*;

    fn test_xxx() !void {
        try expect(condition);
    }

    export fn main() i32 {
        test_suite_begin("Tests");
        run_test("test", test_xxx);
        return test_suite_end();
    }
    ```
  - 新格式：
    ```uya
    use std.testing.check_eq_i32;

    test "test_xxx" {
        check_eq_i32(actual, expected);
    }
    ```

**实现待办**：
- [ ] **编译器**：添加子命令解析 `build`/`run`/`test`（`src/main.uya`）
- [ ] **编译器**：收集所有 `test "name" {}` 块（`src/main.uya`）
- [ ] **编译器**：入口点检测逻辑改进（`src/main.uya`）
- [ ] **代码生成**：自动生成 main 函数（`src/codegen/c99/main.uya`）
- [ ] **标准库**：添加 `check_*` 系列断言（`lib/std/testing/testing.uya`）
- [ ] **标准库**：改进测试运行器（`lib/std/testing/testing.uya`）
- [ ] **测试迁移**：将 89 个待迁移文件改为新格式（`tests/programs/*.uya`）

**涉及**：`src/main.uya`、`src/codegen/c99/main.uya`、`lib/std/testing/testing.uya`、`tests/programs/*.uya`

**参考文档**：
- [tests/MIGRATION_TODO.md](../tests/MIGRATION_TODO.md) - 详细迁移计划

---

## 下次优先实现（规范 0.40.1 变更）

### 0.40.1 内置函数命名统一（优先完成）

- [x] **`@sizeof(T)` → `@size_of(T)`**：复合概念使用 snake_case
- [x] **`@alignof(T)` → `@align_of(T)`**：复合概念使用 snake_case
- [x] **命名惯例确立**：
  - 单一概念：`@len`, `@max`, `@min`（短形式）
  - 复合概念：`@size_of`, `@align_of`, `@async_fn`（下划线分隔）

**实现待办**：
- [x] **Lexer**：识别 `@size_of`、`@align_of`（替换 `@sizeof`、`@alignof`）
- [x] **AST**：更新节点名称（如 `AST_SIZEOF` → `AST_SIZE_OF`，或保持现有节点但更新识别逻辑）
- [x] **Parser**：解析 `@size_of(...)`、`@align_of(...)` 调用形式
- [x] **Checker**：识别并校验 `@size_of`、`@align_of` 的语义
- [x] **Codegen**：生成与现有一致的 C 代码（输出不变，仅函数名变更）
- [x] **测试用例迁移**：将 `tests/` 中所有用例从 `@sizeof`、`@alignof` 改为 `@size_of`、`@align_of`
- [x] **C 实现与 uya-src 同步**：`src/` 与 `uya-src/` 两套实现同步修改；`--c99` 与 `--uya --c99` 均通过，`--c99 -b` 自举对比一致

**涉及**：`lexer.c`/`lexer.uya`、`ast.c`/`ast.uya`、`parser.c`/`parser.uya`、`checker.c`/`checker.uya`、`codegen/c99/expr.c`/`expr.uya` 等；`tests/*.uya` 中引用内置的用例。

**参考文档**：
- [changelog.md](changelog.md) §0.40.1 - 内置函数命名统一
- [uya.md](uya.md) §16 - 内置函数规范

---

## 下次优先实现（规范 0.39 变更）

以下三项来自 uya.md 0.34 规范变更（0.35 已含联合体），建议在阶段 2（错误处理）之前或与之并行时优先实现。

- [x] **参数列表即元组**：函数体内通过 `@params` 访问整份参数列表作为元组，与现有元组类型、解构声明衔接；规范 uya.md 规范变更 0.34
- [x] **可变参数**：`...` 形参（C 语法兼容）、`printf(fmt, ...)` 参数转发、`@params` 元组访问；编译器智能优化（未用 `@params` 时零开销）；规范 uya.md §5.4
- [x] **字符串插值与 printf 结合**：`"a${x}"`、`"a${x:format}"`，结果类型与 printf 格式一致，规范 uya.md §17；可与阶段 10 合并实现  
  **C 实现**：Lexer（INTERP_*、string_mode/interp_depth、返回 INTERP_SPEC 后重置 reading_spec 修复 type=8）、AST、Parser、Checker、Codegen 已完成。支持多段、带 `:spec`（如 `#06x`、`.2f`、`ld`、`zu`）、连续插值、变量初始化、printf 单参（`printf("%s", arg)` 消除 -Wformat-security）、i64/f32/usize/u8 等类型。**插值仅作 printf/fprintf 格式参数时脱糖为单次 printf(fmt, ...)、无中间缓冲**（emit_printf_fmt_inline 内联输出格式串）。测试 test_string_interp.uya（19 条用例，含表达式插值 `${a+b}`）、test_string_interp_minimal/simple/one 通过 `--c99`。

**uya-src 已同步**：Lexer（TOKEN_INTERP_*、string_mode/interp_depth/reading_spec/pending_interp_open、read_string_char_into_buffer、next_token 插值逻辑）、AST（AST_STRING_INTERP、ASTStringInterpSegment）、Parser（primary_expr 中 INTERP_TEXT/OPEN 解析、parser_peek 禁用 string_mode）、Checker（checker_interp_format_max_width、AST_STRING_INTERP 类型与 computed_size）、Codegen（c99_emit_string_interp_fill、call 实参临时缓冲、stmt 变量初始化、**printf/fprintf 插值脱糖为单次 printf 无中间缓冲**）。test_string_interp*.uya 通过 `--uya --c99`。**自举对比（--c99 -b）已通过**：根因为 Arena 在解析 main.uya 时内存不足（实参列表扩展需 648 字节），修复为 arena_alloc 失败时打印「Arena 分配失败（内存不足）」并 exit(1)、ARENA_BUFFER_SIZE 增至 48MB。

**可变参数与 @params（C 实现与 uya-src 同步已完成）**：Lexer 支持 `@params`；AST 新增 AST_PARAMS、call 的 has_ellipsis_forward；Parser 支持 fn 形参 `...`、primary 中 `@params`/`@params.0`、调用末尾 `...`；Checker 中 `@params` 仅函数体内、类型为参数元组，`...` 转发仅可变参数函数、实参个数=被调固定参数个数；Codegen 按需生成（未用 @params 不生成元组、无 `...` 转发不生成 va_list），转发时用 va_list+vprintf 等。测试 `test_varargs.uya`、`test_varargs_full.uya` 通过 `--c99` 与 `--uya --c99`。

---

## 0. 规范同步：内置函数以 @ 开头

规范已升级为所有内置函数以 `@` 开头（uya.md 0.34、UYA_MINI_SPEC.md）。已实现新语法并迁移测试。

- [x] **Lexer**：识别 `@` 及 `@` 后标识符（如 `@size_of`、`@align_of`、`@len`、`@max`、`@min`）；新增 `TOKEN_AT_IDENTIFIER` 类型
- [x] **AST**：沿用现有节点（AST_SIZEOF、AST_ALIGNOF、AST_LEN、AST_INT_LIMIT）
- [x] **Parser**：`primary_expr` 支持 `@max`、`@min`（无参）；支持 `@size_of(...)`、`@align_of(...)`、`@len(...)` 调用形式
- [x] **Checker**：识别并校验 `@size_of`、`@align_of`、`@len`、`@max`、`@min` 的语义
- [x] **Codegen**：生成与现有一致的 C 代码（输出不变）
- [x] **测试用例迁移**：将 `tests/` 中所有用例改为 `@size_of`、`@align_of`、`@len`、`@max`、`@min`
- [x] **C 实现与 uya-src 同步**：`src/` 与 `uya-src/` 两套实现同步修改；`--c99` 与 `--uya --c99` 均通过，`--c99 -b` 自举对比一致

**涉及**：`lexer.c`/`lexer.uya`、`ast.c`/`ast.uya`、`parser.c`/`parser.uya`、`checker.c`/`checker.uya`、`codegen/c99/expr.c`/`expr.uya` 等；`tests/*.uya` 中引用内置的用例。

---

## 1. 基础类型与字面量

- [x] **整数类型**：增加 `i8`、`i16`、`i64`、`u8`、`u16`、`u32`、`u64`（Lexer 无需改，Checker + Codegen 类型映射）
- [x] **类型极值**：`@max`、`@min` 内置函数（编译期常量，以 @ 开头），规范 uya.md §2、§16
- [x] **元组类型**：`(T1, T2, ...)`，字面量、`.0`/`.1` 访问、解构，规范 uya.md §2 元组类型说明
- [x] **重复数组字面量**：`[value: N]`（与类型 `[T: N]` 一致），规范 uya.md §1、§7

**涉及**：`checker.h`/`checker.c`（TypeKind、type_from_ast、运算/转换）、`codegen/c99/types.c`（c99_type_to_c）、parser 数组字面量（`;` 分支）、uya-src 对应模块。

**说明**：元组类型已在 C 实现与 uya-src 自举中完成（类型、字面量、.0/.1、解构）。测试 `test_tuple.uya` 已加入，`--c99` 与 `--uya --c99` 均通过。

---

## 2. 错误处理

- [x] **错误类型与 !T**：预定义 `error Name;`、运行时 `error.Name`、`!T` 类型与内存布局，规范 uya.md §2 错误类型、§5
- [x] **error_id 稳定性**：`error_id = hash(error_name)`，相同错误名在任意编译中映射到相同值；hash 冲突时报错，规范 uya.md §2
- [x] **try 关键字**：`try expr` 传播错误、算术溢出检查（返回 error.Overflow），规范 uya.md §5、§10、§16
- [x] **catch 语法**：`expr catch |err| { }`、`expr catch { }`，两种返回方式，规范 uya.md §5
- [x] **main 签名**：支持 `fn main() !i32`，错误→退出码，规范 uya.md §5.1.1

**涉及**：Lexer（try、catch、error）、AST（!T、try/catch 节点）、Parser、Checker、Codegen、uya-src。uya-src 已同步（与 defer/errdefer 同步实现）。

---

## 3. defer / errdefer

- [x] **defer**：作用域结束 LIFO 执行（正常+错误返回），规范 uya.md §9
- [x] **errdefer**：仅错误返回时 LIFO 执行，用于资源清理，规范 uya.md §9

**涉及**：Lexer、AST、Parser、Checker、Codegen（作用域退出点插入），uya-src。

**C 实现与用例（作用域 100% 覆盖）**：Lexer（TOKEN_DEFER/TOKEN_ERRDEFER）、AST（AST_DEFER_STMT/AST_ERRDEFER_STMT）、Parser（defer/errdefer 后单句或块）、Checker（errdefer 仅允许在 !T 函数内；**defer/errdefer 块内禁止 return/break/continue**）、Codegen（块内收集 defer/errdefer 栈，return/break/continue/块尾 LIFO 插入）。**规范 §9 语义**：return 时**先计算返回值**，再执行 defer，最后返回；defer 不能修改返回值（与 Zig/Swift 一致）；defer/errdefer 块内禁止控制流语句（return、break、continue），只做清理不改变控制流。用例：test_defer、test_defer_lifo（同作用域 LIFO）、test_defer_scope（嵌套块内层先于外层）、test_defer_break、test_defer_continue（break/continue 前执行）、test_defer_single_stmt（单句语法）、test_errdefer、test_errdefer_lifo、test_errdefer_scope（嵌套 errdefer）、test_errdefer_only_on_error；error_defer_return、error_errdefer_return 等（块内 return/break/continue 编译失败）；均通过 `--c99`。

**uya-src 已同步**：Lexer（TOKEN_TRY/CATCH/ERROR/DEFER/ERRDEFER）、AST（AST_ERROR_DECL/AST_DEFER_STMT/AST_ERRDEFER_STMT/AST_TRY_EXPR/AST_CATCH_EXPR/AST_ERROR_VALUE/AST_TYPE_ERROR_UNION）、Parser（!T 类型、error.Name、try expr、catch 后缀、defer/errdefer 语句、error 声明）、Checker（TYPE_ERROR_UNION/TYPE_ERROR、type_from_ast 修复 !void 处理：移除对 TYPE_VOID payload 的特殊检查，允许 !void 作为有效错误联合类型、checker_infer_type、checker_check_node、return error.X 与 !T 成功值检查）、Codegen（emit_defer_cleanup、AST_BLOCK defer/errdefer 收集、return/break/continue 前插入、return error.X、!T 成功值、AST_TRY_EXPR/AST_CATCH_EXPR/AST_ERROR_VALUE、AST_TYPE_ERROR_UNION、c99_get_or_add_error_id、collect_string_constants；expr.uya 修复 catch 表达式中 !void 处理：支持 void payload，不声明结果变量；function.uya 为 !void 返回类型的函数添加默认返回语句；stmt.uya 添加 void 类型变量处理：生成 (void)(expr) 而不是变量声明；structs.uya 修复 err_union_void 结构体定义在 vtable 内部的问题：预先生成错误联合类型结构体定义）。**自举对比（--c99 -b）已通过**。

---

## 4. 切片

- [x] **切片类型**：`&[T]`、`&[T: N]`，胖指针（ptr+len），规范 uya.md §2、§4
- [x] **切片语法**：`base[start:len]`（C 实现：arr[start:len]、slice[start:len]；负索引待扩展），规范 uya.md §4
- [x] **结构体切片字段**：结构体含 `&[T]` 字段（类型与 Codegen 已支持，测试 test_struct_slice_field.uya 已补）

**涉及**：类型系统、Parser（切片表达式）、Checker、Codegen（胖指针布局）、uya-src。

**C 实现（已完成）**：AST_TYPE_SLICE、AST_SLICE_EXPR；Parser 解析 `&[T]`/`&[T: N]` 与 `base[start:len]`；Checker TYPE_SLICE、type_equals、@len(slice)；Codegen 切片结构体 `struct uya_slice_X { T* ptr; size_t len; }`、切片复合字面量、slice.ptr[i]、@len(slice).len。结构体切片字段：main.c 中 collect_slice_types_from_node 增加 AST_STRUCT_DECL 分支、emit 顺序调整为 slice 先于用户结构体；types.c 中 get_c_type_of_expr 支持 AST_MEMBER_ACCESS；expr.c 中 @len/数组访问对成员访问切片字段生成 .len/.ptr[i]。测试 test_slice.uya、test_struct_slice_field.uya 通过 `--c99`。
**uya-src 已同步**：ast.uya（AST_SLICE_EXPR、AST_TYPE_SLICE 及字段）；parser.uya（&[T]/&[T: N] 类型解析，base[start:len] 表达式）；checker.uya（TYPE_SLICE、type_equals、type_from_ast、checker_infer_type、@len(slice)、array_access 切片）；codegen（types/expr/main/structs/expr：collect AST_STRUCT_DECL 切片、emit 顺序、find_struct_decl_from_type_c、get_c_type_of_expr MEMBER_ACCESS、@len/array_access 成员访问切片）。test_slice.uya、test_struct_slice_field.uya 通过 `--uya --c99`，自举对比 `--c99 -b` 一致。

---

## 5. match 表达式

- [x] **match 语法**：`match expr { pat => expr, else => expr }`，规范 uya.md §8
- [x] **模式**：常量（整数、bool）、枚举变体、变量绑定、`_` 通配、else 分支

**涉及**：Lexer、AST、Parser、Checker、Codegen（if-else 链或跳转表），uya-src。

**C 实现（已完成）**：Lexer（TOKEN_MATCH、TOKEN_FAT_ARROW、`match` 关键字、`=>` 双符）；AST（AST_MATCH_EXPR、ASTMatchArm、MatchPatternKind：LITERAL/ENUM/ERROR/BIND/WILDCARD/ELSE）；Parser（primary_expr 中 match 解析、pat => expr/block、逗号分隔、else 可选）；Checker（所有分支返回类型一致、BIND 作用域、枚举模式类型校验、穷尽性：else 或 BIND/WILDCARD）；Codegen（表达式用 GCC 语句表达式 `({ ... })`，语句用 if-else 链；修复 find_enum_variant_value 自动递增值）。测试 test_match.uya 通过 `--c99`。
**uya-src 已同步**：Lexer（TOKEN_MATCH、TOKEN_FAT_ARROW、match 关键字、=>）；AST（MatchPatternKind、ASTMatchArm、AST_MATCH_EXPR、literal_int_value/literal_is_bool/result_is_block 避免指针 . 访问）；Parser（match 解析、字面量臂填 literal_int_value/literal_is_bool、result_is_block）；Checker（infer_type 统一类型、check_node 穷尽性/枚举/BIND 作用域）；Codegen（expr.uya 表达式、stmt.uya 语句、main.uya collect_slice_types）。自举编译器可成功生成 C（`./compile.sh --c99` 后手动链接 `gcc compiler.c bridge.c -o compiler`）；test_match.uya 通过 `--c99`（C 版）。自举版 `--uya --c99` 需在构建可执行后验证。

---

## 6. for 扩展

- [x] **整数范围**：`for start..end |v|`、`for start.. |v|`、可丢弃元素形式 `for start..end { }`，规范 uya.md §8  
  **C 实现**：Lexer（TOKEN_DOT_DOT、read_number 遇 `..` 不当作小数点）、AST（for_stmt.is_range/range_start/range_end）、Parser（识别 first_expr 后 TOKEN_DOT_DOT 为范围形式）、Checker（范围表达式须整数、循环变量类型）、Codegen（有界范围展开为 for(; v < _uya_end; v++)、丢弃形式用 _uya_i、无限范围 while(1)）。测试 test_for_range.uya 通过 `--c99`。
- [x] **迭代器**：可迭代对象（接口）、`for obj |v|`、`for obj |&v|`，规范 uya.md §6.12、§8（依赖阶段 7 接口）  
  **C 实现**：Checker（for 循环检查迭代器接口：查找 next 和 value 方法，next 返回 !void，value 返回元素类型；支持数组类型回退）、Codegen（for 循环迭代器代码生成：while(1) 循环，调用 next() 检查 error_id，调用 value() 获取当前值；支持数组类型回退）。测试 test_for_iterator.uya、test_iter_simple.uya 通过 `--c99`。  
  **uya-src 已同步**：checker.uya（for 循环迭代器检查：expr_type 使用 copy_type 避免移动，检查 next/value 方法签名）、codegen/c99/stmt.uya（for 循环迭代器代码生成：提取结构体名称、查找方法、生成 while 循环）。test_for_iterator.uya、test_iter_simple.uya 通过 `--uya --c99`。**自举对比（--c99 -b）已通过**。

**涉及**：Parser（range、迭代器）、Checker、Codegen、迭代器接口与 for 脱糖，uya-src。  
**uya-src 已同步**：lexer.uya（TOKEN_DOT_DOT、`.` 与 read_number）、ast.uya（for_stmt_is_range/range_start/range_end）、parser.uya（范围解析）、checker.uya（is_range 分支、迭代器检查）、codegen/c99/stmt.uya（范围代码生成、迭代器代码生成）、main.uya 与 utils.uya（collect）。test_for_range.uya、test_for_loop.uya、test_for_iterator.uya、test_iter_simple.uya 通过 `--uya --c99`。**自举对比（--c99 -b）已通过**：main.uya 中 ARENA_BUFFER_SIZE 增至 64MB 以容纳 for 范围等 AST 自举时 Arena 需求。

---

## 7. 接口

- [x] **interface 定义**：`interface I { fn method(self: &Self,...) Ret; ... }`，规范 uya.md §6
- [x] **实现**：`struct S : I { }`，方法块 `S { fn method(...) { ... } }`，Checker 校验实现
- [x] **装箱与调用**：接口值 8/16B（vtable+data）、装箱点、接口方法调用；Codegen 已实现（vtable 生成、装箱、call 通过 vtable）
- [x] **接口 async 方法签名**：`interface I { @async_fn fn method(...) Future<!T>; }` 与对应结构体/联合体 async 方法实现主链路已打通；固定回归 `test_async_method_interface.uya`

**涉及**：AST、Parser、Checker、Codegen（vtable、装箱点、逃逸检查），uya-src。

**当前进度**：Lexer、AST、Parser、Checker 已完成。**C 实现 Codegen 已完成**：types.c 接口类型→struct uya_interface_I；structs.c 生成 interface/vtable 结构体与 vtable 常量（修复：预先生成接口方法签名中使用的错误联合类型结构体定义，避免 err_union_void 等结构体定义出现在 vtable 内部）；function.c 方法块生成 uya_S_m 函数；expr.c 接口方法调用（vtable 派发）、装箱（struct→interface 传参）；main.c 处理 AST_METHOD_BLOCK、emit_vtable_constants。test_interface.uya 通过 `--c99`。**uya-src 已同步**：lexer.uya（TOKEN_INTERFACE、interface 关键字）；ast.uya（AST_INTERFACE_DECL、AST_METHOD_BLOCK、struct_decl_interface_*、method_block_*）；parser.uya（parse_interface、parse_method_block、struct : I、顶层 IDENTIFIER+{）；checker.uya（TYPE_INTERFACE、find_interface_decl_from_program、find_method_block_for_struct、struct_implements_interface、type_equals/type_from_ast/check_expr_type、member_access 接口方法）；codegen types/structs/function/expr/main（接口类型、emit_interface_structs_and_vtables 修复：预先生成错误联合类型结构体定义、emit_vtable_constants、方法前向声明与定义、接口方法调用与装箱、c99_type_to_c_with_self）。在此基础上，`@async_fn` 现也可用于接口方法签名，以及结构体内部/外部方法实现；method async wrapper、`Self` 解析与 vtable 分派主链路已由 `test_async_method_interface.uya` 覆盖。自举编译 `./compile.sh --c99 -e` 成功；test_interface.uya 通过 `--uya --c99`。**修复**：parser.uya 在「字段访问和数组访问链」循环中补全了 `TOKEN_LEFT_PAREN` 分支，以解析 `obj.method(args)` 形式的方法调用（如 `a.add(10)`）；structs.c/structs.uya 修复 err_union_void 结构体定义在 vtable 内部的问题：添加 pregenerate_error_union_structs_for_interface 函数，在生成 vtable 之前预先生成所有接口方法签名中使用的错误联合类型结构体定义。自举对比 `--c99 -b` 仅有单行空行差异。

---

## 8. 结构体方法 + drop + 移动语义

- [x] **结构体方法（外部方法块）**：`self: &Self`、外部方法块（`S { fn method(self: &Self) Ret { } }`），规范 uya.md §4、§29.3  
  **C 实现**：Checker 增加 struct method call 分支（callee 为 obj.method、obj 类型为 struct 时，查找 method_block 校验实参）；checker_check_member_access 当字段不存在时检查 method_block 返回方法返回类型；checker_infer_type 中 AST_CALL_EXPR 分支添加结构体方法调用的类型推断（obj.method() 时推断方法返回类型）；expr.c 增加 struct method 调用代码生成（`uya_StructName_method(&obj, args...)`），支持 const 前缀类型、值/指针两种 receiver；types.c 中 get_c_type_of_expr 支持方法调用的类型推断（AST_MEMBER_ACCESS 先查找字段，字段不存在时查找方法；AST_CALL_EXPR 递归处理 obj.method 形式）。  
  **uya-src 已同步**：checker.uya（checker_check_call_expr 接口+结构体方法、checker_check_member_access 方法返回类型、checker_infer_type 中 AST_CALL_EXPR 结构体方法类型推断）；expr.uya（struct method call 代码生成）；types.uya（get_c_type_of_expr 支持方法类型推断）。test_struct_method.uya、test_struct_method_err.uya 通过 `--c99` 与 `--uya --c99`。
- [x] **结构体方法（内部定义）**：方法定义在结构体花括号内，与字段并列，规范 uya.md §29.3  
  **语法**：`struct S { field: T, fn method(self: &Self) Ret { ... } }`  
  **用例**：
  ```uya
  // 结构体内定义方法（方法与字段写在一起）
  struct Point {
    x: f32,
    y: f32,
    fn distance(self: &Self) f32 {
      return self.x + self.y;
    }
  }
  
  fn main() i32 {
    const p: Point = Point{ x: 2.0, y: 3.0 };
    const d: f32 = p.distance();  // 调用内部定义的方法
    return 0;
  }
  ```
  **测试用例**（全部通过 `--c99` 与 `--uya --c99`）：
  - `test_struct_inner_method.uya` - 基本的内部方法定义
  - `test_struct_inner_method_args.uya` - 带参数的内部方法
  - `test_struct_inner_method_multi.uya` - 多个内部方法
  - `test_struct_inner_method_void.uya` - void 返回的内部方法
  - `test_struct_inner_method_mixed.uya` - 字段与方法混合定义
  - `test_struct_inner_method_with_interface.uya` - 内部方法 + 接口实现
  
  **C 实现**：AST 在 struct_decl 中增加 methods/method_count 字段；Parser 在 parse_struct 中支持解析 fn 关键字（内部方法）；Checker 添加 find_method_in_struct 函数同时查找外部方法块和内部方法；Codegen 在 main.c 中生成内部方法原型和实现，function.c 添加 find_method_in_struct_c99 函数，expr.c/structs.c 使用新函数。  
  **uya-src 已同步**：ast.uya、parser.uya、checker.uya、codegen/c99/structs.uya、codegen/c99/expr.uya、codegen/c99/main.uya 均已同步修改。
- [x] **drop / RAII**：用户自定义 `fn drop(self: T) void`，作用域结束逆序调用，规范 uya.md §12  
  **C 实现（已完成）**：Checker 校验 drop 签名（仅一个参数 self: T 按值、返回 void）、每类型仅一个 drop（方法块与结构体内部不能重复）；Codegen 在块退出时先 defer 再按变量声明逆序插入 drop 调用，在 return/break/continue 前插入当前块变量的 drop；生成 drop 方法时先按字段逆序插入字段的 drop 再用户体。测试 test_drop_simple.uya、test_drop_order.uya 通过 `--c99` 与 `--uya --c99`；error_drop_wrong_sig.uya、error_drop_duplicate.uya 预期编译失败。**uya-src 已同步**：checker.uya（check_drop_method_signature、METHOD_BLOCK 与 struct_decl 的 drop 校验）；codegen（stmt.uya 的 emit_drop_cleanup/emit_current_block_drops、current_drop_scope 与 drop_var_*、function.uya 的 drop 方法字段逆序）。
- [x] **移动语义**：结构体赋值/传参/返回为移动，活跃指针禁止移动，规范 uya.md §12.5  
  **C 实现（已完成）**：Checker 维护已移动集合（moved_names）、符号表 pointee_of 记录 `p = &x` 的活跃指针；赋值/const 初始化/return/函数实参/结构体字面量字段若源为结构体变量则标记移动；使用标识符时检查「已被移动」、移动前检查「存在活跃指针」「循环中不能移动」。测试 test_move_simple.uya 通过；error_move_use_after.uya、error_move_active_pointer.uya、error_move_in_loop.uya 预期编译失败。**uya-src 已同步**：checker.uya 增加 Symbol.pointee_of、TypeChecker.moved_names/moved_count；moved_set_contains、has_active_pointer_to、checker_mark_moved、checker_mark_moved_call_args；AST_IDENTIFIER 使用前查已移动、var_decl/assign/return/call/struct_init 处标记移动及 pointee_of；为满足自举在返回/赋值处使用 copy_type 避免对同一 Type 变量多次移动。test_move_simple 与 error_move_* 在 --c99 与 --uya --c99 下均通过/预期失败。  
  **数组元素部分移出（当前未实现）**：移动追踪仅针对「整个变量」（AST_VAR_DECL + 标识符名）。`x = arr[i]` 的源是 AST_ARRAY_ACCESS，不会调用 checker_mark_moved，故**没有对数组元素做细粒度移出追踪**。Codegen 的 emit_drop_cleanup 只处理类型为 AST_TYPE_NAMED 的变量，数组类型变量不会加入 drop 列表，因此**当前不会对数组整体或元素做 drop**。后果：（1）不会出现「对已移出槽位 double drop」的 UB，因为根本不 drop 数组元素；（2）若元素类型有 drop，则数组离开作用域时**未调用的 drop 为规范缺口**；（3）若将来实现对数组元素的 drop，则必须先实现「按槽位追踪已移出」或等价机制，否则会产生 double drop / use-after-move 的 UB。

**涉及**：Parser、Checker、Codegen（drop 插入、移动与指针检查），uya-src。

---

## 9. 模块系统

- [x] **目录即模块**：项目根=main，路径如 std.io，规范 uya.md §1.5（需要多文件支持）
  **C 实现（已完成）**：`extract_module_path_allocated` 从文件路径提取模块路径，基于目录结构。目录下的所有 `.uya` 文件属于同一模块。当前支持单级目录模块（如 `module_a/` → `module_a`），多级路径（如 `std/io/` → `std.io`）待扩展。测试用例已调整为目录结构：`tests/module_a/module_a.uya` 属于 `module_a` 模块。**测试验证通过**：所有测试用例已验证，包括基本模块导入、错误检测、单文件 export 测试等。
- [x] **export（语法解析与基本支持）**：`export fn/struct/interface/const/error`、`export extern`，规范 uya.md §1.5.3
  **C 实现（已完成）**：Lexer（TOKEN_EXPORT）、AST（所有声明节点添加 is_export 字段）、Parser（parser_parse_declaration 支持 export 前缀，所有解析函数设置 is_export）、Checker（基本检查，单文件场景下 export 标记记录但不影响可见性）、Codegen（跳过 use 语句，正常生成 export 标记的声明）。测试 test_module_export.uya 通过编译并运行（返回 42）。
- [x] **use（语法解析与基本支持）**：`use path;`、`use path.item;`、别名 `as`，无通配符，规范 uya.md §1.5.4
  **C 实现（已完成）**：Lexer（TOKEN_USE）、AST（AST_USE_STMT 节点，path_segments/item_name/alias 字段）、Parser（parser_parse_use_stmt 解析 use 语句，支持路径段、特定项、别名）、Checker（基本语法检查，单文件场景下 use 语句暂时不进行实际模块解析）、Codegen（跳过 use 语句，不生成代码）。语法解析和代码生成通过。
- [x] **模块可见性与路径解析（多文件）**：Checker 中处理 export 可见性、use 路径解析、模块查找（需要多文件支持）
  **C 实现（已完成）**：TypeChecker 中添加 ModuleTable 和 ImportTable；`build_module_exports` 遍历所有声明，根据文件路径提取模块路径，收集 export 标记的项；`process_use_stmt` 处理 use 语句，查找模块并验证导出项是否存在；`extract_module_path_allocated` 从文件路径提取模块路径（基于目录结构，如 `tests/module_a/file.uya` → `module_a`）。**目录即模块**：支持目录即模块，目录下的所有 `.uya` 文件属于同一模块。**测试验证**：所有测试用例已验证通过，包括 `tests/module_a/` 和 `tests/module_test/`、`tests/multifile/module_test/` 等。module_a 目录下的文件属于 `module_a` 模块，module_b.uya 使用 `use module_a.public_func;` 导入并调用，error_use_private.uya 正确检测到使用未导出项的错误。**编译警告已修复**：删除了未使用的变量和函数声明。
- [x] **循环依赖**：编译期检测并报错，规范 uya.md §1.5.7（需要多文件支持）
  **C 实现（已完成）**：在 `ModuleInfo` 中添加 `dependencies` 字段记录模块依赖；在 `process_use_stmt` 中记录当前模块对目标模块的依赖关系；添加 `detect_circular_dependencies` 函数使用 DFS 算法检测强连通分量（循环依赖）；在所有 use 语句处理完后调用循环检测。测试用例 `error_circular_dependency.uya` 正确检测到循环依赖并报错。
- [x] **多级模块路径**：支持多级路径（如 `std/io/` → `std.io`），当前仅支持单级目录模块（如 `module_a/` → `module_a`）
  **C 实现（已完成）**：修改 `extract_module_path_allocated` 提取从第一个目录到最后一个目录的所有目录名，用 `.` 连接（临时跳过 `tests/` 前缀以匹配测试用例）；修改 `process_use_stmt` 支持多级路径解析，处理 parser 将 `use std.io.read_file;` 解析为 `path_segments = ["std", "io", "read_file"]` 的情况（最后一个 segment 作为项名）。测试用例 `test_multilevel_module.uya` 通过 `--c99`。
- [x] **多文件模块系统**：实现目录即模块、模块路径解析、多文件编译（当前已支持多文件编译和单级模块路径）
- [x] **自动模块依赖解析**：编译器自动解析模块依赖，用户只需指定包含 main 函数的文件或目录
  **C 实现（已完成）**：
  - 支持单文件输入（必须包含 main 函数）
  - 支持目录输入（目录中必须只有一个文件包含 main 函数，多个则报错）
  - 实现 `get_compiler_dir()` 和 `get_uya_root()` 获取编译器目录和 UYA_ROOT 环境变量
  - 实现 `find_module_file()` 根据模块路径查找文件（项目根目录 → UYA_ROOT → 编译器目录）
  - 实现 `detect_main_function()` 检测文件是否包含 main 函数
  - 实现 `find_main_files_in_dir()` 在目录中查找包含 main 的文件
  - 实现 `extract_use_modules()` 从 AST 中提取 use 语句的模块路径
  - 实现 `collect_module_dependencies()` 递归收集所有模块依赖（避免循环依赖）
  - 修改 `parse_args()` 和 `compile_files()` 集成自动依赖收集功能
  - 使用 Arena 分配器管理内存，避免内存泄漏
  **测试验证**：基本功能已实现，完整测试待补充
- [x] **UYA_ROOT 环境变量支持**：支持通过环境变量指定标准库位置，默认在编译器程序所在目录查找
  **C 实现（已完成）**：
  - 实现 `get_uya_root()` 读取 UYA_ROOT 环境变量
  - 如果未设置，使用编译器程序所在目录（通过 `readlink("/proc/self/exe")` 获取）
  - 在 `find_module_file()` 中优先在 UYA_ROOT 目录查找模块文件
  - 支持路径规范化处理（相对路径、绝对路径、路径分隔符）
  **uya-src 已同步**：
  - 添加了外部函数声明（getenv, stat, opendir, readdir, closedir, readlink, strcpy）
  - 实现了基本框架（get_compiler_dir, get_uya_root, is_directory, is_file, detect_main_function, find_main_files_in_dir, find_module_file, extract_use_modules）
  - 修改了 compile_files 以支持目录输入和依赖收集框架
  - `collect_module_dependencies()` 已完整实现递归逻辑（检查已处理、解析 AST、提取 use 语句、递归处理模块、特殊处理 main 模块、Arena 内存管理）
- [x] **完善自举版本的依赖收集**：实现 `collect_module_dependencies()` 的完整递归逻辑
  **已实现功能**：
  - [x] 检查是否已处理过（避免循环依赖）
  - [x] 读取文件并解析 AST
  - [x] 提取 use 语句中的模块路径
  - [x] 对于每个模块，查找文件并递归处理
  - [x] 特殊处理 main 模块（在项目根目录查找）
  - [x] 使用 Arena 分配器管理文件路径内存
  **当前状态**：C 版本与 uya-src 版本均已完整实现递归依赖收集逻辑，功能已同步

**涉及**：多文件/多目录解析、符号表与可见性、uya-src。

---

## 10. 字符串插值

- [x] **插值语法（C 实现 + uya-src 同步）**：`"a${x}"`、`"a${x:format}"`，结果类型 `[i8: N]`，与 printf 格式一致，规范 uya.md §17  
  已实现：多段、`:spec`（#06x、.2f、ld、zu）、连续插值、变量/数组初始化、printf 单参、表达式插值（如 `${a+b}`）、i32/u32/i64/f32/f64/usize/u8 等。**插值仅作 printf/fprintf 格式参数时脱糖为单次 printf(fmt, ...)、无中间缓冲**。test_string_interp.uya（19 条用例）等通过 `--c99` 与 `--uya --c99`。uya-src 已同步（Lexer/AST/Parser/Checker/Codegen）。
- [x] **原始字符串**：`` `...` ``，无转义，规范 uya.md §1  
  **C 实现（已完成）**：Lexer（TOKEN_RAW_STRING、raw_string_mode 字段、反引号处理逻辑）、Parser（支持 TOKEN_RAW_STRING，生成 AST_STRING 节点）。原始字符串所有字符按字面量处理，不处理转义序列。测试 test_raw_string.uya 通过 `--c99`。  
  **uya-src 已同步**：lexer.uya（TOKEN_RAW_STRING、raw_string_mode 字段、反引号处理逻辑）、parser.uya（支持 TOKEN_RAW_STRING）。测试 test_raw_string.uya 通过 `--uya --c99`。

**涉及**：Lexer、Parser、类型与宽度计算、Codegen。

---

## 11. 原子类型

- [x] **atomic T**：语言层原子类型，规范 uya.md §13  
  **C 实现（已完成）**：Lexer（TOKEN_ATOMIC、复合赋值运算符 TOKEN_PLUS_ASSIGN/MINUS_ASSIGN/ASTERISK_ASSIGN/SLASH_ASSIGN/PERCENT_ASSIGN）、AST（AST_TYPE_ATOMIC）、Parser（parser_parse_type 支持 atomic T、复合赋值转换为 x = x op y）、Checker（type_from_ast 验证仅支持整数类型、支持原子类型与内部类型比较、错误报告）、Codegen（类型生成 _Atomic(T)、标识符访问生成 __atomic_load_n、赋值生成 __atomic_store_n、复合赋值 +=/-= 生成 __atomic_fetch_add/__atomic_fetch_sub）。测试 test_atomic_basic.uya、test_atomic_ops.uya、test_atomic_types.uya、test_atomic_struct.uya、error_atomic_non_integer.uya 通过 `--c99`。编译警告已修复（括号优先级、switch 语句完整性）。
  **uya-src 已同步**：Lexer（TOKEN_ATOMIC、is_keyword 识别 atomic）、AST（AST_TYPE_ATOMIC、type_atomic_inner_type 字段）、Parser（parser_parse_type 解析 atomic T）、Checker（TYPE_ATOMIC、type_from_ast 验证仅支持整数类型、type_equals 原子类型比较、比较运算符支持原子类型与内部类型比较、copy_type 包含 atomic_inner_type）、Codegen（types.uya 生成 _Atomic(T)、expr.uya 标识符访问生成 __atomic_load_n、stmt.uya 赋值生成 __atomic_store_n 和复合赋值 __atomic_fetch_add/__atomic_fetch_sub）。测试 test_atomic_basic.uya、test_atomic_ops.uya、test_atomic_types.uya、test_atomic_struct.uya 通过 `--uya --c99`。
- [ ] **&atomic T**：原子指针（待实现）
- [x] **读/写/复合赋值**：自动原子指令，零运行时锁（已实现）

**涉及**：类型系统、Checker、Codegen（原子指令），uya-src（已同步）。

---

## 12. 运算符与安全

- [x] **饱和运算**：`+|`、`-|`、`*|`，规范 uya.md §10、§16  
  **C 实现（已完成）**：Lexer（TOKEN_PLUS_PIPE/MINUS_PIPE/ASTERISK_PIPE）、Parser、Checker（仅支持整数类型，两操作数类型必须一致）、Codegen（使用 GCC __builtin_*_overflow 检测溢出，溢出时返回 MAX/MIN）。测试 test_saturating_wrapping.uya 通过 `--c99`。**uya-src 已同步**：lexer.uya、parser.uya、checker.uya、codegen/c99/expr.uya。通过 `--uya --c99`。
- [x] **包装运算**：`+%`、`-%`、`*%`，规范 uya.md §10、§16  
  **C 实现（已完成）**：Lexer（TOKEN_PLUS_PERCENT/MINUS_PERCENT/ASTERISK_PERCENT）、Parser、Checker（仅支持整数类型，两操作数类型必须一致）、Codegen（转换为无符号类型进行运算后转回有符号类型，实现包装语义）。测试 test_saturating_wrapping.uya 通过 `--c99`。**uya-src 已同步**：lexer.uya、parser.uya、checker.uya、codegen/c99/expr.uya。通过 `--uya --c99`。
- [x] **切片运算符**：`[start:len]` 用于切片语法，规范 uya.md §10（已实现：base[start:len] 得 &[T]，test_slice.uya 通过）
- [x] **类型转换 as!**：强转返回 `!T`，需 try/catch，规范 uya.md §11  
  **C 实现**：Lexer（TOKEN_AS_BANG，read_identifier_or_keyword 识别 as!）、AST（cast_expr.is_force_cast）、Parser（TOKEN_AS/AS_BANG 分支）、Checker（infer_type 对 as! 返回 TYPE_ERROR_UNION）、Codegen（as! 包装 !T、collect 预定义 !T 结构体、try/catch 使用操作数类型）、types（get_c_type_of_expr 对 as! 返回 err_union_X）。测试 test_as_force_cast.uya 通过 `--c99`。**uya-src 已同步**：lexer.uya、ast.uya、parser.uya、checker.uya、codegen expr/types/main.uya。通过 `--uya --c99`。
- [ ] **内存安全证明**：数组越界/空指针/未初始化/溢出/除零：证明或插入运行时检查，规范 uya.md §14

**涉及**：Lexer（新运算符）、Parser、Checker、Codegen，uya-src。

---

## 13. 联合体（union）

- [x] **union 定义**：`union Name { variant1: Type1, variant2: Type2 }`，规范 uya.md §4.5
- [x] **泛型 union**：`union Name<T> { ... }`，单态化 `Name<i32>`、`Name<T>.variant(x)` 与 match（uya-src 已实现，test_generic_union.uya 通过）
- [x] **创建**：`UnionName.variant(expr)`，如 `IntOrFloat.i(42)`
- [x] **访问**：`match` 模式匹配（必须处理所有变体）、`.variant(bind)` 模式、穷尽性检查
- [x] **实现**：带隐藏 tag 的 C 布局（`struct uya_tagged_U { int _tag; union U u; }`），零开销 match
- [x] **extern union**：外部 C 联合体声明与互操作（C 实现与 uya-src 已同步）
- [x] **联合体方法**：`self: &Self`，内部/外部方法块（C 实现与 uya-src 已同步）

**C 实现（已完成）**：Lexer（TOKEN_UNION）、AST（AST_UNION_DECL、MATCH_PAT_UNION）、Parser（parse_union、match 中 .variant(bind)）、Checker（TYPE_UNION、union init 校验、match 穷尽与变体类型推断）、Codegen（gen_union_definition、union init、match union 的 _tag 分支）。**联合体方法（C 实现已完成）**：AST（union_decl.methods/method_count、method_block.union_name）；Parser（union 内解析 fn 内部方法）；Checker（METHOD_BLOCK 解析目标为 struct/union、find_method_block_for_union、find_method_in_union、member_access/call 联合体方法、AST_UNION_DECL 内部方法及 drop 校验）；Codegen（find_method_in_union_c99、find_method_block_for_union_c99、find_union_decl_by_tagged_c99、expr 联合体方法调用、main 联合体方法块与内部方法、types c99_type_to_c_with_self_opt 联合体、get_c_type_of_expr AST_UNARY_EXPR/AST_CAST_EXPR）。测试 test_union.uya、test_union_method.uya（外部方法块）、test_union_inner_method.uya（内部方法）通过 `--c99`。**uya-src 已同步**：lexer.uya、ast.uya（union_decl_methods/method_count、method_block_union_name）、parser.uya（union 内 fn 解析）；checker.uya（find_method_block_for_union、find_method_in_union、call/member_access 联合体方法、AST_METHOD_BLOCK 联合体分支、AST_UNION_DECL 内部方法及 drop 校验）；codegen（structs.uya find_method_in_union_c99/find_method_block_for_union_c99、expr.uya 联合体方法调用、main.uya 联合体方法块与内部方法）。test_union_method.uya、test_union_inner_method.uya 通过 `--uya --c99`。

**extern union（C 实现与 uya-src 已同步）**：`extern union CName { v1: T1, v2: T2 }` 声明外部 C 联合体；Parser（parse_declaration 消费 extern 后分支 union/fn、parser_parse_union_body(parser, is_extern)、parser_parse_type 支持 `union TypeName`）；Checker（AST_UNION_DECL 禁止 is_extern 且含方法、AST_METHOD_BLOCK 禁止目标为 extern union、AST_MATCH_EXPR 禁止对 extern union 做 match）；Codegen（gen_union_definition 对 is_extern 仅生成 `union Name { ... };`、c99_type_to_c 对 extern union 生成 `union Name`、联合体变体构造对 extern 生成 `(union Name){ .v = expr }`）。测试 test_extern_union.uya 通过 `--c99` 与 `--uya --c99`；error_extern_union_match.uya、error_extern_union_method_block.uya 预期编译失败。

**涉及**：Lexer、AST、Parser、Checker、Codegen，uya-src。依赖 match 表达式（阶段 5）。

---

## 14. 消灭所有警告

通过修复代码中的问题来消除所有编译警告，而非通过编译器选项抑制警告。使用 `-Wall -Wextra -pedantic` 编译时，所有代码应无警告。

- [x] **C 实现代码修复**：修复 `src/` 目录下所有 C 代码中的警告问题
  - C 实现代码编译无警告（已验证）
- [x] **代码生成器改进（空初始化器）**：修复 `codegen/c99/` 中空数组字面量生成的空初始化器警告
  - **C 实现**：修复 `expr.c`、`stmt.c`、`global.c` 中空数组字面量生成 `{}` 的问题，改为生成 `{0}` 避免 ISO C 警告
  - **uya-src 已同步**：修复 `expr.uya`、`stmt.uya`、`global.uya` 中对应代码，空数组字面量生成 `{0}` 而不是 `{}`
  - 空初始化器警告已消除（4 个警告已修复）
- [x] **代码生成器改进（字符串参数类型）**：修复标准库函数调用中字符串参数的类型转换
  - **uya-src**：修复 `expr.uya` 中标准库函数调用时，字符串参数使用 `(const char *)` 而不是 `(uint8_t *)`
  - 部分 `uint8_t *` 转换警告已修复（函数调用中的字符串参数）
- [x] **copy_type 函数 const 限定符修复**：修复 `copy_type` 函数的 const 限定符警告
  - **C 实现**：在 `src/codegen/c99/function.c` 中添加 `is_copy_type` 检查，将第一个参数类型改为 `const struct Type *`
  - **uya-src 已同步**：在 `uya-src/codegen/c99/function.uya` 中添加相同逻辑
  - `copy_type` 相关警告已消除（25 个警告修复为 0）
- [x] **自举编译器代码修复（部分完成）**：修复 `uya-src/` 生成的 C 代码中部分警告问题
  - **已修复**：在 `expr.uya` 中添加了 `is_stdlib_function_for_string_arg` 函数，检查标准库函数调用
  - **已修复**：对于标准库函数的字符串参数（字符串字面量和 `*byte` 类型标识符），添加 `(const char *)` 转换
  - **已修复**：修复未使用的 `_dummy` 变量警告
  - **已同步到 C 实现**：在 `expr.c` 中添加了相同的 `is_stdlib_function_for_string_arg` 函数和类型转换逻辑
  - **剩余问题**：字符串常量（如 `str0`）在生成的 C 代码中是 `const char *` 类型，但在函数调用时仍被转换为 `(uint8_t *)`，导致警告
  - **说明**：这是 Uya 类型系统的设计问题。Uya 中字符串类型为 `&[i8]`（即 `uint8_t *`），而 C 标准库函数期望 `const char *`。完全消除这些警告需要修改 Uya 的字符串类型设计，超出本阶段范围。
- [x] **测试程序验证**：确保所有测试程序（`tests/*.uya`）编译生成的 C 代码无警告
  - **已验证**：测试程序编译生成的 C 代码无警告（已验证 test_atomic_basic.uya 等）
  - **说明**：虽然自举编译器生成的代码仍有字符串常量类型转换警告，但这是类型系统设计问题，不影响测试程序的编译

**涉及**：
- C 实现代码：`src/*.c`、`src/*.h`、`src/codegen/c99/*.c`
- 自举编译器：`uya-src/*.uya` 及其生成的 C 代码
- 代码生成器：`codegen/c99/*.c` 中的代码生成逻辑

**常见警告类型及修复方法**：
- **未使用的变量/函数/参数**：删除或添加 `(void)var;` 标记为有意未使用
- **类型转换警告**：添加显式类型转换或修正类型定义
- **格式字符串警告**：使用正确的 printf 格式字符串，避免直接使用用户输入作为格式字符串
- **未初始化变量**：初始化所有变量，或明确标记为有意未初始化
- **符号隐藏/重定义**：修复命名冲突，使用 static 限制作用域
- **指针比较警告**：修复指针与整数比较的问题

**验证方法**：
```bash
# C 实现编译（应无警告）
cd compiler-mini
make clean && make CFLAGS="-Wall -Wextra -pedantic" 2>&1 | grep -i warning

# 自举编译器编译（应无警告）
cd compiler-mini/uya-src
./compile.sh --c99 -e
gcc -Wall -Wextra -pedantic compiler.c bridge.c -o compiler 2>&1 | grep -i warning

# 测试程序编译（应无警告）
./tests/run_programs.sh --c99 test_xxx.uya 2>&1 | grep -i warning
```

**注意**：此任务的目标是修复代码中的问题，而不是通过编译器选项（如 `-Wno-xxx`）来抑制警告。

---

## 15. 泛型（Generics）

**语法规范**（规范 0.40）：使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`。详见 [uya.md](uya.md) §B.1 和 [grammar_formal.md](grammar_formal.md)。

**语法规范**：
- 函数泛型：`fn max<T: Ord>(a: T, b: T) T { ... }`
- 结构体泛型：`struct Vec<T: Default> { ... }`
- 接口泛型：`interface Iterator<T> { ... }`
- 类型参数使用：`Vec<i32>`, `Iterator<String>`

**实现状态**：

- [x] **Lexer**：识别泛型语法
  - [x] 识别尖括号 `<` 和 `>`（复用比较运算符 token）
  - [x] 识别类型参数约束语法 `<T: Ord>`、`<T: Default>`（已实现基本约束语法解析）
  - [x] 多约束语法 `<T: Ord + Clone + Default>`（已实现，用 `+` 连接多个约束）

- [x] **AST**：泛型节点扩展
  - [x] 函数声明添加 `type_params`/`type_param_count` 字段
  - [x] 结构体声明添加 `type_params`/`type_param_count` 字段
  - [x] 接口声明添加 `type_params`/`type_param_count` 字段
  - [x] 类型节点支持泛型类型参数（`type_args`/`type_arg_count`）
  - [x] 调用表达式支持泛型类型参数
  - [x] 结构体初始化支持泛型类型参数

- [x] **Parser**：泛型语法解析
  - [x] 解析函数泛型参数列表：`fn name<T>(...)`
  - [x] 解析结构体泛型参数列表：`struct Name<T>`
  - [x] 解析接口泛型参数列表：`interface Name<T>`
  - [x] 解析类型参数约束：`<T: Ord>`、`<T: Default>`（已实现基本约束语法解析）
  - [x] 解析多约束语法：`<T: Ord + Clone>`（已实现，用 `+` 连接多个约束）
  - [x] 解析泛型类型使用：`Vec<i32>`、`Pair<i32, i64>`
  - [x] 处理泛型与比较运算符的歧义（修复 `<` 误判为比较运算符的问题）

- [x] **Checker**：泛型类型检查（基础）
  - [x] 类型参数作用域管理（泛型函数/结构体内部）
  - [x] 单态化实例收集（`MonoInstance` 结构体）
  - [x] 泛型函数调用类型检查
  - [x] 泛型结构体初始化类型检查
  - [x] 泛型结构体字段访问类型推断（字段类型中的类型参数正确替换为具体类型）
  - [x] 泛型结构体指针字段支持（`&T` 字段正确单态化）
  - [x] 约束检查：验证类型参数是否满足约束（内置约束 Ord/Clone/Default/Copy/Eq 对基本类型隐式实现；结构体需显式实现接口）
  - [x] 类型推断：自动推断类型参数（从函数实参类型推断泛型类型参数）

- [x] **Codegen**：泛型代码生成（单态化）
  - [x] 泛型函数单态化：`identity<i32>` → `identity_i32`
  - [x] 泛型结构体单态化：`Pair<i32, i64>` → `struct Pair_i32_i64`
  - [x] 泛型函数调用代码生成（使用单态化名称）
  - [x] 泛型结构体初始化代码生成（使用单态化名称）
  - [x] 类型参数替换（在生成代码时替换为具体类型）

- [~] **泛型 RAII / 清理代码生成（待补齐）**
  - [ ] 泛型 `drop(self: Foo<T>) void` 的单态化与符号发射
  - [ ] 泛型类型跨模块调用泛型清理方法时的定义收集与发射（当前 `MpscChannel<T>` 直接调用 `RingQueue<T>.deinit()` 仍会漏发射）
  - [ ] 待补齐后，将 `RingQueue<T>` / `MpscChannel<T>` 从当前显式 `deinit()` 方案重新收敛回自动 RAII

- [x] **标准约束接口**：定义常用约束（内置实现）
  - [x] `Ord` 接口：数值类型和 bool 隐式实现（支持比较运算符）
  - [x] `Clone` 接口：数值类型和 bool 隐式实现（值语义复制）
  - [x] `Default` 接口：数值类型和 bool 隐式实现（默认值为 0/false）
  - [x] `Copy` 接口：数值类型、bool、指针隐式实现（位复制）
  - [x] `Eq` 接口：数值类型、bool、指针隐式实现（判等运算符）

- [x] **测试用例**（基础 + 扩展）：
  - [x] `test_generic_fn.uya` - 基本泛型函数
  - [x] `test_generic_struct.uya` - 基本泛型结构体
  - [x] `test_generic_minimal.uya` - 最小泛型测试
  - [x] `test_generic_simple.uya` - 简单泛型测试
  - [x] `test_generic_call.uya` - 泛型函数调用语法
  - [x] `test_generic_constraint.uya` - 带约束的泛型（`<T: Default>`、`<T: Ord>`）
  - [x] `test_generic_comprehensive.uya` - 综合测试（函数+结构体+约束+指针+嵌套调用+表达式）
  - [x] `test_generic_multi_type_param.uya` - 多类型参数（`<A, B>`、`<X, Y, Z>`）
  - [x] `test_generic_nested_call.uya` - 嵌套泛型调用（`identity<i32>(identity<i32>(42))`）
  - [x] `test_generic_multi_instance.uya` - 多实例化（同一泛型多次实例化为不同类型）
  - [x] `test_generic_pointer.uya` - 指针操作（`deref<T>`、`set_value<T>`、`swap<T>`）
  - [x] `test_generic_struct_field.uya` - 泛型结构体字段访问
  - [x] `test_generic_struct_ptr_field.uya` - 泛型结构体指针字段（`&T` 字段）
  - [x] `test_generic_field_compare.uya` - 泛型结构体字段比较
  - [x] `test_generic_field_debug.uya` - 泛型结构体字段访问调试
  - [x] `test_generic_edge_cases.uya` - 边界情况（命名、单/多字段、混合字段）
  - [x] `test_generic_in_expr.uya` - 表达式中使用泛型
  - [x] `test_generic_in_control_flow.uya` - 控制流中使用泛型（if/while）
  - [x] `test_generic_inference.uya` - 泛型类型推断（从实参类型自动推断类型参数）
  - [x] `test_generic_multi_constraint.uya` - 多约束泛型（`<T: Ord + Clone>`）
  - [x] `error_generic_constraint_fail.uya` - 约束检查失败测试（预期编译失败）
  - [x] `test_generic_interface.uya` - 泛型接口声明和约束
  - [x] `test_generic_interface_impl.uya` - 结构体实现泛型接口（`struct Foo : Interface<T>`）

**已知限制**：
- 嵌套泛型（如 `Box<Pair<i32, i32>>`）：已完全支持（`>>` 解析和代码生成顺序都已修复）
- 泛型接口方法的支持不完善
- 类型推断目前仅支持直接类型参数（如 `a: T`），不支持复杂类型中的类型参数（如 `a: &T`）
- 结构体需要显式实现接口才能满足约束，基本类型隐式满足内置约束

**涉及**：Lexer、AST、Parser、Checker、Codegen（单态化），uya-src。

**uya-src 已同步**：ast.uya（type_params/type_param_count/type_args/type_arg_count）；parser.uya（泛型参数列表解析、多约束语法 `+`、泛型类型使用解析）；checker.uya（MonoInstance、类型参数作用域、泛型函数/结构体类型检查、单态化实例收集、泛型字段类型推断、类型推断、**约束检查**）；codegen（function/structs/main/types/expr/utils/internal：单态化名称生成、泛型函数/结构体代码生成）。测试通过 `--uya --c99`。

**参考文档**：
- [uya.md](uya.md) §B.1 - 泛型语法说明
- [grammar_formal.md](grammar_formal.md) - 正式BNF语法规范（已包含泛型BNF）
- [examples/example_143.uya](../examples/example_143.uya) - 泛型函数示例
- [examples/example_144.uya](../examples/example_144.uya) - 泛型结构体示例
- [examples/example_145.uya](../examples/example_145.uya) - 泛型接口示例
- [examples/example_147.uya](../examples/example_147.uya) - 泛型综合示例
- [examples/example_149.txt](../examples/example_149.txt) - 泛型约束说明（Ord、Clone、Default）

**实现优先级**：低（建议在原子类型、内存安全证明等核心特性实现后再考虑）

---

## 18. 宏系统（Macro，规范 uya.md §25）

**语法规范**：`mc ID(param_list) return_tag { statements }`，规范 [uya.md](uya.md) §25。

**已实现（C 实现）**：
- [x] **Lexer**：`mc` 关键字，`@mc_eval`、`@mc_code`、`@mc_ast`、`@mc_error`、`@mc_get_env` 为合法 @ 内置；`${` 插值语法（`TOKEN_INTERP_OPEN`）
- [x] **AST**：`AST_MACRO_DECL`、`AST_MC_EVAL`、`AST_MC_CODE`、`AST_MC_AST`、`AST_MC_ERROR`、`AST_MC_INTERP`（`${expr}` 插值节点）
- [x] **Parser**：解析 `mc name(params) return_tag { body }`，解析 `@mc_*` 调用，解析 `${expr}` 插值语法
- [x] **Checker**：宏展开（带参数、`expr`/`stmt` 返回、`@mc_code(@mc_ast(...))`）
  - [x] 带参数宏（`MacroParamBinding` 参数绑定与 `deep_copy_ast` AST 替换）
  - [x] `@mc_eval` 编译时常量表达式求值（`macro_eval_expr`）
  - [x] `@mc_error` 编译时错误报告
  - [x] `@mc_get_env` 环境变量读取
  - [x] `${expr}` 插值语法（在 `deep_copy_ast` 中替换为参数 AST）
  - [x] `stmt` 返回标签支持
  - [x] `type` 返回标签支持（语法解析，调用暂不支持）
  - [x] 语法糖（最后一条语句自动包装为 `@mc_code(@mc_ast(...))`）
- [x] **Codegen**：跳过 `AST_MACRO_DECL`
- [x] **测试**：
  - `test_macro_simple.uya` - 基本宏定义与调用
  - `test_macro_with_params.uya` - 带参数宏
  - `test_macro_mc_eval.uya` - `@mc_eval` 编译时求值
  - `test_macro_mc_get_env.uya` - `@mc_get_env` 环境变量
  - `test_macro_stmt.uya` - `stmt` 返回标签
  - `test_macro_type.uya` - `type` 返回标签
  - `test_macro_sugar.uya` - 语法糖自动包装
  - `test_macro_interp.uya` - `${}` 插值语法（简单、复杂、多参数、嵌套）
  - `test_macro_integration.uya` - 宏综合测试
  - `test_macro_multiple_calls.uya` - 多次调用测试
  - `test_macro_complex_stmt.uya` - `@mc_ast` 复杂语句支持（块、if、for、while、变量声明等）
  - `test_macro_param_stmt.uya` - `stmt` 参数类型支持
  - `error_macro_mc_error.uya` - `@mc_error` 预期编译失败
- [x] **`@mc_ast` 复杂语句支持**：
  - [x] 块语句 `{ ... }` 解析与代码生成（使用 GCC 语句表达式 `({ ... })`）
  - [x] if 语句 / if-else 语句
  - [x] for 范围循环（`for start..end |i| { }`）
  - [x] while 循环
  - [x] const/var 变量声明
  - [x] return 语句
  - [x] 复杂语句内 `${}` 插值支持

- [x] **`stmt` 参数类型**：
  - [x] stmt 参数使用块语法传递（`my_macro({ stmt; })`）
  - [x] 在 `@mc_ast` 中使用 `${s};` 展开 stmt 参数
  - [x] 测试用例：`test_macro_param_stmt.uya`

- [x] **`struct` 返回标签**：
  - [x] Parser: 支持 `struct` 作为宏返回标签（TOKEN_STRUCT）
  - [x] Parser: 方法块内支持宏调用（`macro_name();`）
  - [x] Parser: `@mc_ast` 支持解析函数定义（TOKEN_FN）
  - [x] Checker: `struct` 返回类型的宏展开
  - [x] Checker: 在 `AST_METHOD_BLOCK` 中展开宏调用为方法定义
  - [x] 测试用例：`test_macro_struct_return.uya`

- [x] **`type` 返回标签调用**：
  - [x] Parser: 类型位置支持宏调用语法（`macro_name()`）
  - [x] Checker: 支持 `type` 返回类型的宏展开
  - [x] Checker: 在 `@mc_code(@mc_ast(...))` 处理中，将 AST_IDENTIFIER 转换为 AST_TYPE_NAMED
  - [x] 测试用例：`test_macro_type_return.uya`

**已实现**：
- [x] `@mc_type` 编译时类型反射（简化版本，返回 TypeInfo 结构体）
  - [x] AST: 新增 AST_MC_TYPE 节点和 mc_type 数据结构
  - [x] Parser: 解析 `@mc_type(Type)` 语法
  - [x] Checker: 类型反射实现（返回包含 name/size/align/kind/is_* 标志的 TypeInfo 结构体）
  - [x] Checker: AST_TYPE_NAMED 参数替换支持
  - [x] 测试用例：`test_macro_mc_type.uya`

- [x] **跨模块宏导出与导入**：
  - [x] Parser: 支持 `export mc` 语法（is_export 标志）
  - [x] Checker: 宏添加到模块导出表（item_type=8）
  - [x] Checker: `find_macro_decl_with_imports` 支持查找导入的宏
  - [x] 测试用例：`multifile/test_macro_export/` 目录（test_macro_export_main.uya、error_use_private_macro.uya）
  - [x] 文档更新：uya.md §25.2.1 跨模块宏导出与导入

**uya-src 同步已完成**：

### 18.1 词法分析器 (lexer.uya) ✅
- [x] 添加 `TOKEN_MC` 枚举值
- [x] 在 `is_keyword` 函数中识别 `"mc"` 关键字

### 18.2 AST 定义 (ast.uya) ✅
- [x] 添加 `AST_MACRO_DECL` 节点类型（宏声明）
- [x] 添加 `AST_MC_CODE` 节点类型（`@mc_code(expr)` 宏内生成代码）
- [x] 添加 `AST_MC_AST` 节点类型（`@mc_ast(expr)` 代码转 AST）
- [x] 添加 `AST_MC_EVAL` 节点类型（`@mc_eval(expr)` 编译时求值）
- [x] 添加 `AST_MC_ERROR` 节点类型（`@mc_error(msg)` 编译时错误）
- [x] 添加 `AST_MC_INTERP` 节点类型（`${expr}` 宏内插值）
- [x] 添加 `AST_MC_TYPE` 节点类型（`@mc_type(T)` 类型反射）
- [x] ASTNode 添加 `macro_decl_name: &byte` 字段
- [x] ASTNode 添加 `macro_decl_params: & & ASTNode` 字段
- [x] ASTNode 添加 `macro_decl_param_count: i32` 字段
- [x] ASTNode 添加 `macro_decl_return_tag: &byte` 字段
- [x] ASTNode 添加 `macro_decl_body: &ASTNode` 字段
- [x] ASTNode 添加 `macro_decl_is_export: i32` 字段
- [x] ASTNode 添加 `mc_code_operand: &ASTNode` 字段
- [x] ASTNode 添加 `mc_ast_operand: &ASTNode` 字段
- [x] ASTNode 添加 `mc_eval_operand: &ASTNode` 字段
- [x] ASTNode 添加 `mc_error_operand: &ASTNode` 字段
- [x] ASTNode 添加 `mc_interp_operand: &ASTNode` 字段
- [x] ASTNode 添加 `mc_type_operand: &ASTNode` 字段
- [x] `ast_new_node` 函数初始化所有新字段

### 18.3 语法分析器 (parser.uya) ✅
- [x] 添加 `parser_parse_macro` 函数：解析 `mc name(params) return_tag { body }`
- [x] 在 `parser_parse_declaration` 中添加 `TOKEN_MC` 分支，调用 `parser_parse_macro`
- [x] 在 `parser_parse_primary_expr` 中添加 `@mc_code` 解析（`TOKEN_AT_IDENTIFIER` 分支）
- [x] 在 `parser_parse_primary_expr` 中添加 `@mc_ast` 解析
- [x] 在 `parser_parse_primary_expr` 中添加 `@mc_eval` 解析
- [x] 在 `parser_parse_primary_expr` 中添加 `@mc_error` 解析
- [x] 在 `parser_parse_primary_expr` 中添加 `@mc_type` 解析
- [x] 在 `parser_parse_primary_expr` 中添加 `${expr}` 插值解析（`TOKEN_INTERP_OPEN`）

### 18.4 类型检查器 (checker.uya) ✅
- [x] 添加 `find_macro_decl_from_program` 函数：在程序中按名称查找宏声明
- [x] 添加 `expand_macros_in_node_simple` 递归函数：遍历 AST 展开所有宏调用
- [x] 在 `checker_check` 入口处调用 `expand_macros_in_node_simple`（类型检查前先展开宏）
- [x] 支持无参宏和带参宏的展开
- [x] 支持 `@mc_eval` 编译时求值
- [x] 支持 `@mc_type` 类型反射

### 18.5 代码生成器 (codegen/) ✅
- [x] `AST_MACRO_DECL` 在代码生成时被跳过（宏在 checker 阶段已展开）
- [x] `AST_MC_*` 节点在宏展开后不会出现在最终 AST 中
- [x] C99 `AST_MEMBER_ACCESS`：按左值表达式推断指针类型，正确交替 `.` / `->`（多级链如方法体内 `self.a.b.c`、局部变量经 C 关键字/保留名转义后仍可选对 `->`）；回归 `test_c99_pointer_access.uya`

### 18.6 验证 ✅
- [x] 运行 `cd uya-src && ./compile.sh --c99 -e` 编译自举编译器成功
- [x] 运行 `./tests/run_programs.sh --uya --c99 test_macro*.uya` 所有 27 个宏测试通过
- [x] 运行 `./compile.sh --c99 -b` 自举对比一致

**涉及**：Lexer、AST、Parser、Checker、Codegen。

---

## 16. 异步编程（Async）

**语法规范**（规范 0.40）：`@async_fn` 函数属性、`try @await` 挂起点、`union Poll<T>`、`interface Future<T>`。详见 [uya.md](uya.md) §18。

**异步标准库设计**：详见 [`docs/std_async_design.md`](./std_async_design.md)（`std.async.io`、`std.async.task`、`std.async.event`、`std.async.channel`、`std.async.scheduler`）。

**循环内 await 设计**：详见 [`docs/async_loop_await_design.md`](./async_loop_await_design.md)、[`docs/todo_async_loop_await.md`](./todo_async_loop_await.md)。

**设计目标**：
- 显式控制：所有挂起必须 `try @await`，取消必须显式检查 `is_cancelled()`
- 零成本：状态机栈分配，无运行时堆分配，无隐式锁
- 编译期证明：状态机安全性、Send/Sync 推导、跨线程验证编译期完成
- 类型安全：`Poll<T>` 使用 `union`（编译期标签跟踪），非 `enum`

**依赖**：
- 联合体（union）- 已实现（阶段 13）
- 接口（interface）- 已实现（阶段 7）
- 错误处理（!T）- 已实现（阶段 2）
- 原子类型（atomic T）- 建议先实现（阶段 11）

**实现待办**：

**重要语义说明（Pending vs Error）**：
- `poll()` 的返回 `Poll<T>` 表达的是**调度层状态**：`Ready` / `Pending`。`Pending` 不是“错误”，只是“尚未就绪”。
- `!T` 表达的是**业务层结果**：成功值 `T` 或错误集合中的某个 error。
- 因此更“正统/易实现状态机”的形态通常是 `Future<!T>`（即 `poll() -> Poll<!T>`）：  
  - `Poll.Pending`：挂起（应由调度器驱动再次 poll）  
  - `Poll.Ready(!T)`：就绪；其中 `!T` 再区分成功/失败  
- 当前实现已进入**兼容期中的阶段 B**：状态机 codegen 主路径使用 `Future<!T>` / `Poll<!T>`，`Pending` 走 `Poll.Pending`（`test_async_state_machine.uya` 覆盖）。
- 为兼容既有语法与测试，Checker 仍接受 `!Future<T>`；`test_async_await.uya` 仍保留 `error.AsyncPending` 兼容路径，后续应逐步收敛并删除这条旧控制流。

**迁移建议（兼容期 → 正统期）**：
- 兼容期：同时支持 `Future<!T>` 与 `!Future<T>`；以 `Future<!T>` + `Poll.Pending` 作为状态机主路径，逐步清理 `error.AsyncPending` 控制流与旧签名。
- 正统期：统一到 `Future<!T>`（或等价设计），让 Pending 走 `Poll.Pending`，让错误传播走 `!T`（或 `Poll<ErrUnion>`），移除 `!Future<T>` 兼容层。

**当前实现状态（2026-03，2026-04 增补）**：
- 已完成最小闭环：`@async_fn` / `try @await`、`Future<!T>` 的 `poll` 状态机、单/多 `@await`、基础错误传播、`block_on`
- **循环**：`while` / `if` 内含 await 的通用 lowering；**范围 `for` 与定长数组 `for` 内含 await**（`tests/test_async_for_await.uya`）
- **方法与接口**：结构体内部方法、外部方法块与接口方法签名现已支持 `@async_fn`；接口 async 调用经 vtable 分派 future 的主链路已打通（`tests/test_async_method_interface.uya`）
- 标准库已有最小模块：`std.async`、`std.async_event`、`std.async_channel`、`std.async_scheduler`
- 与最终目标仍有差距：跨平台后端、更完整 async I/O 原语、HTTP 连接池/keep-alive、TLS 会话复用与更严格唤醒安全性验证仍待完善（多-interest `Waker` 已于 2026-10-04 收口）

**已知语义缺口（更新至 2026-04）**：
- **已缓解**：连续 `while` 内多 await（Bug A）、`return try @await`（Bug C）、**范围/定长数组 `for` 内 await** 等已由通用段发射路径覆盖；见 `tests/test_async_bug_a_two_while.uya`、`tests/test_async_bug_c_tail_await.uya`、`tests/test_async_for_await.uya` 与 [plan_async_coroutine_transform.md](plan_async_coroutine_transform.md)。
- **已转正**：多个 `try @await` **循环之间**的同步语句已由 `tests/test_async_bug_b_sync_between.uya` 复核通过，不再是当前阻塞项；相关历史背景见 [todo_async_loop_await.md](todo_async_loop_await.md)。
- **已转正**：复合表达式中的 `try @await`（赋值 RHS、return 表达式）已接入通用回放/替换路径；固定回归见 `tests/test_async_compound_try_await.uya`。
- `benchmarks/http_bench_async_epoll.uya`：`make check` 中的 verify 脚本多仅保证 **C99 可编译**；**端到端 `curl` 成功**依赖 await 间及循环间语句完整发射。
- 服务只监听 **IPv4 `127.0.0.1`** 时，`curl http://localhost:…` 先试 **IPv6 `::1`** 出现「拒绝连接」属预期，与 Empty reply 不是同一类问题。

- [x] **Lexer**：识别异步编程语法（C 实现与 uya-src 已同步）
  - [x] 识别 `@async_fn` 函数属性（`@` 后跟 `async_fn`）
  - [x] 识别 `@await` 关键字（`@` 后跟 `await`）
  - [x] 注意与现有 `@` 内置函数（`@size_of`、`@len` 等）的区分

- [x] **AST**：异步编程节点扩展（C 实现与 uya-src 已同步）
  - [x] 函数声明添加 `is_async` 字段（标记 `@async_fn`）
  - [x] `AST_AWAIT_EXPR` 节点：`@await expression`
  - [x] 类型节点支持 `!Future<T>` 与 `Future<!T>`（基于泛型 interface 已可用）
  - [x] 支持 `union Poll<T>` 类型定义和使用（基于联合体泛型单态化）

- [x] **Parser**：异步编程语法解析（C 实现与 uya-src 已同步）
  - [x] 解析 `@async_fn` 函数属性（顶层函数、结构体/联合体方法实现、接口方法签名前的属性）
  - [x] 解析 `@await expression` 表达式
  - [x] 解析 `!Future<T>` 与 `Future<!T>` 返回类型（兼容双轨语义）
  - [x] 解析 `union Poll<T>` 类型定义（基于联合体泛型语法）
  - [x] 验证 `@await` 只能在 `@async_fn` 函数内使用

- [x] **Checker**：异步编程类型检查（基础实现，C 实现与 uya-src 已同步）
  - [x] `@async_fn` 函数必须返回 `Future<!T>` 或 `!Future<T>` 类型（`error_async_wrong_return.uya` 覆盖非法返回类型）
  - [x] `@await` 表达式操作数必须返回 `Future<!T>` 或 `!Future<T>` 类型（错误用例覆盖）
  - [x] `@await` 只能在 `@async_fn` 函数内使用
  - [x] `@await` 返回类型推断为 `!T`（当前已接入 `Poll<!T>` 最小状态机闭环）
  - [x] `union Poll<T>` 类型检查（`test_poll_std_async.uya` 覆盖）
  - [x] `interface Future<T>` 接口定义和实现检查（`test_async_future_interface_box.uya` 覆盖）
  - [x] 结构体/联合体 async 方法与接口 async 方法签名主链路（`Self` 解析、方法 async 上下文、vtable 派发 future）已接通；固定回归 `test_async_method_interface.uya`
  - [x] 接口方法 / 受约束泛型方法返回 `!T` 的推断（`test_interface_error_union_method.uya` 覆盖 `EventLoop.poll()` / `counter.next()`）
  - [x] 状态机大小编译期计算（已实现 `get_type_node_size_bytes()` 递归计算实际类型大小（基本类型、指针、数组、切片、元组、错误联合、具名 struct）；`@await` 上限 32 / 参数上限 16 已在 checker 阶段报错；估算 > 1024 字节时输出警告；栈分配优化暂未启用（待调度器存储期配合））

- [x] **CPS 变换（Continuation-Passing Style）**：状态机生成
  - [x] 分析 `@async_fn` 函数体，识别所有 `@await` 点（单/多 `@await` 已稳定，`async_copy` 覆盖循环内场景）
  - [x] 将函数体转换为状态机结构（state + await_fut 单槽，多状态）
  - [x] 为每个 `@await` 点创建状态（state 0 起点，state 1..n 各 await 就绪后）
  - [x] 生成状态转换代码（poll 内 if state==k 分支，绑定变量在函数顶声明、块内赋值）
  - [x] 处理局部变量在状态间的保存和恢复（多 await 时在 poll 开头声明所有绑定变量）
  - [x] 计算状态机大小（编译期确定，按实际绑定类型和参数类型字节大小求和，存储于 `codegen.async_state_size`；`checker` 阶段输出 >1024B 警告）

- [x] **Codegen**：异步编程代码生成（C 实现与 uya-src 已同步）
  - [x] `@await` 表达式代码生成（已接入 `Poll<!T>` 最小状态机闭环）
  - [x] 修复：i32 INT_MIN 用 `@min` 比较并输出 `(-2147483647-1)`，避免字面量溢出与 `--` 解析；err_union 先输出 payload 结构体（`ensure_struct_emitted_for_type_node`）；catch 表达式从 `err_union_structX` 推断 payload 类型；vtable 前先输出 union tagged 前向声明
  - [x] 单/多 `@await` 状态机：结构体（state + await_fut）、poll 内多状态（state 0..n）、绑定变量在 poll 顶声明；`test_async_state_machine`、`test_async_multiple_await`、`test_async_copy` 通过
  - [x] 生成状态机初始化代码（当前使用 `malloc`，栈分配优化暂未启用）
  - [x] 生成状态转换代码（多 `@await` 点循环生成 `if state==k`）
  - [x] 生成 `poll()` 方法实现（状态机驱动）
  - [x] 生成 `union Poll<T>` 结构体定义（`test_poll_std_async.uya`、`test_async_poll_inline_struct_init.uya` 覆盖）
  - [x] 生成 `interface Future<T>` vtable（`test_async_future_interface_box.uya` 覆盖）
  - [x] 处理错误传播（`!Future<T>` 中的错误联合；`test_async_error_propagation.uya` 覆盖）

- [x] **标准类型定义**：核心异步类型
  - [x] `union Poll<T>` 定义（Ready/Pending 两变体已在 `lib/std/async.uya` 落地）
  - [x] `interface Future<T>` 接口定义
  - [x] `struct Waker` 定义（`wake/reset/is_woken` 最小语义已落地）
  - [x] 为内置类型提供异步支持（`std.async` 已导出 `poll_ready_ok_i32` / `future_ready_ok_i32`、`poll_ready_ok_u32` / `future_ready_ok_u32`、`poll_ready_ok_usize` / `future_ready_ok_usize`，以及 `task_ready_ok_i32` / `task_ready_ok_u32` / `task_ready_ok_usize`；`test_task_std_async.uya` 覆盖）

- [~] **标准库实现**（基于核心类型，详见 [`docs/std_async_design.md`](./std_async_design.md)）
  - [x] `lib/std/async.uya`：`struct Waker`、`union Poll<T>`（Ready/Pending）、`interface Future<T>`、`struct Future<T>`（`state: Poll<T>`、`fn poll(...) Poll<T>`）、`struct Task<T> : Future<T>`（`task_ready`、`poll`）、`block_on`
  - [x] 结构体含泛型 union 字段时 codegen 先输出 union 单态（如 `Poll_i32`），并用 arena 持久化 tagged 名避免重定义
  - [x] 测试：`test_async_await_parse.uya`、`test_task_std_async.uya`、`test_async_return_value.uya`、`test_async_await_ready.uya`、`test_async_nested.uya` 通过 `--c99` 与 `--uya --c99`
  - [~] `std.async.task` 模块：`Task<T>` / `task_ready` 已在 `async.uya` 落地，后续再拆分/扩展
  - [~] `std.async.io` 模块：`AsyncWriter`, `AsyncReader` 接口 + `MemAsyncWriter`、`MemAsyncReader`、`AsyncFd`（已收敛到 `Future<!usize>` 主路径；`AsyncWriter` / `AsyncReader` 现已具备 `write_all` / `read_exact`，helper 层已补上 `async_write_bytes` / `async_write_cstr` / `async_print_to` / `async_println_to`，`AsyncFd` 在 `poll()` 时确保 `O_NONBLOCK`，并将 `EAGAIN` / `EWOULDBLOCK` 映射为 `Pending`；Pending 时会把 `fd + interest` 记录到 `Waker`，由 `Scheduler` 通过 `EventLoop.register()/poll()/deregister()` 驱动下一轮唤醒；`test_async_io.uya`、`test_async_fd.uya`、`test_async_copy.uya` 已覆盖，且 `test_async_fd.uya` 已新增“两个真实 pipe 共享一个 LinuxEpoll”的队列回归；更丰富格式化/helper 仍待扩展）
  - [x] `std.async.event` 模块：`EventLoop`（epoll/kqueue/IOCP）
    - [x] epoll 系统调用层：`lib/syscall/linux.uya` 与 `lib/libc/syscall.uya` 已添加 `SYS_epoll_*`、`EpollEvent`、`EPOLLET`、`sys_epoll_create1`/`sys_epoll_ctl`/`sys_epoll_wait`；`test_epoll_syscall.uya` 通过 `--c99` 与 `--uya --c99`
    - [x] `lib/std/async_event.uya`：`EventKind`、`interface EventLoop`、`struct LinuxEpoll : EventLoop`（`use libc.syscall`；`register`/`deregister` 当前返回 `!i32`，成功值为 `0`）
    - [x] `test_std_async_event.uya` 端到端通过（当前已覆盖 `LinuxEpoll.register()` + `poll()` 命中后 `Waker.wake()` 最小链路；codegen 已修复：err_union 先输出 payload 结构体、catch 推断 struct payload、union 前向声明、INT_MIN 用 @min）
  - [x] `std.async.channel` 模块：泛型 `Channel<T>` 与运行时容量版 `MpscChannel<T>` 已落地（旧兼容别名入口已移除）；新增 `std.collections.ring_queue.RingQueue<T>` 作为可复用环形队列容器。`test_async_channel.uya` 已覆盖 generic send/recv、单槽容量下的 CAS 抢占/满槽 Pending、以及多槽容量下的 FIFO/环回；`test_std_ring_queue.uya` 已独立覆盖运行时容量、满队列与环回行为。为支撑该能力，C99 后端补齐了泛型 `@size_of(T)` 在单态化代码中的替换。当前释放路径先通过显式 `deinit()` 收口；根因是“泛型 drop / 泛型类型跨模块调用泛型清理方法”的 codegen 仍有缺口，已单列到前面的泛型 RAII 待办
  - [x] `std.async.scheduler` 模块：`Scheduler` 主闭环已完成（`scheduler_new`、`scheduler_run`/`scheduler_run_i32`/`scheduler_run_u32`、`scheduler_run_i32_with_event_loop`/`scheduler_run_u32_with_event_loop`/`scheduler_run_usize_with_event_loop`、`scheduler_run_pair_i32_with_event_loop`、`TaskQueue<T>` / `TaskQueue_i32` / `TaskQueue_u32`、`scheduler_run_task_queue_with_event_loop<T>`；`Pending` 时会同步注册 `eventfd + io fd`，`poll()` 内同步 `wake()` 时当前轮直接重试；`Waker.cancel()` / `TaskQueue.cancel()` 与 `error.Cancelled` 写回已接通；同时 codegen 已修复“数组元素上的接口字段方法调用”和“结构体依赖收集误展开接口模板”这两个队列前置缺口；`test_std_async_scheduler.uya` 通过）
  - [x] `test_async_multi_fd_concurrent.uya` - 多 fd 并发调度：`MockEventLoop` + `WokenReadyFuture` 模拟共享 `EventLoop` 单轮推进；验证 2/3 任务并发完成、4/6 次注册以及每任务 2 次 poll，与当前“poll 前 reset、event loop 推进一步后 Ready”的调度契约一致
  - [x] `test_async_compute_types.uya` - 验证 `async_compute<T>` 新增类型（`i64`/`u64`/`i16`/`u16`/`i8`/`u8`/`bool`）通过 `scheduler_run_*_with_event_loop` 正确运行
  - [x] `std.thread` 模块：`ThreadPool` 最小实现稳定；**泛型 `export struct AsyncComputeFuture<T> : Future<!T>`** 覆盖整数/bool/**f32/f64**（typedef 别名保留）；共享 `thread_async_compute_future_new<T>`；worker/one-shot 路径对 `THREAD_TASK_KIND_F32`/`F64` 使用 `uya_thread_call_f32`/`f64`；**仅**导出 **`async_compute<T>`**（已移除 12 个 **`async_compute_*`**）。`test_std_thread.uya`、`test_async_compute_types.uya` 等在 `--c99` 与 `--uya --c99` 通过。C99：`Future<!T>` 单态 vtable、typedef **interface 装箱**与 **成员调用**；**`async_compute<T>`** 单态发射 **`std_thread_async_compute_future_new_<T>`** + 装箱（避免仅展开 Uya 体时 `thread_type_is_*` 全假）；泛型方法体内 `thread_type_is_*(T)` 在 C 端仍可折叠为 `0`/`1`；前导注入 `uya_thread_call_f32`/`f64`；`ok<bool>`/`ok<f32>`/`ok<f64>` 分别由 `thread_ok_*` 锚定。**待**：Send/Sync/跨线程验证。

- [~] **编译期验证**：
  - [x] 状态机大小编译期计算（`get_type_node_size_bytes()` 按实际类型递归求字节大小；`@await` 上限 32 与参数上限 16 在 checker 阶段报错；`>1024B` 警告已实现；间接递归分析待实现）
  - [ ] Send/Sync 约束推导（跨线程安全性）
  - [x] 状态机转换正确性验证（`validate_async_function()` 验证 `@await` 在 `try` 内、`@await` 不在 `return` 之后、`@await` 不在循环条件中）
  - [ ] 唤醒安全性验证（Waker 使用）

- [x] **测试用例**：
  - [x] `test_async_fn_basic.uya` - 基本异步函数（poll 立即 Ready）
  - [x] `test_async_await_parse.uya` - @async_fn/@await 解析与 @await 上下文校验（仅允许在 async 函数内）
  - [x] `test_task_std_async.uya` - std.async 提供 Task<T>、Poll<T>、Future<T>，task_ready + poll 返回 Ready
  - [x] `test_async_return_value.uya` - `@async_fn` 中直接 `return T` 自动包装为异步返回类型（兼容 `Future<!T>` / `!Future<T>`；无 `@await` 时 poll 立即 Ready）
  - [x] `test_async_await.uya` - `try @await` 基本使用（Ready 与 Pending 最小闭环）
  - [x] `test_async_await_ready.uya` - `try @await` 遇到 Ready future 时返回值类型与结果正确
  - [x] `test_poll_std_async.uya` - `Poll<T>` 使用（原计划名 `test_async_poll.uya`）
  - [x] `test_async_poll_inline_struct_init.uya` - 回归：结构体字段内联初始化 `Poll<T>` 时必须使用单态化 tagged union
  - [x] `test_async_future_interface_box.uya` - `Future<T>`（泛型 interface）单态化 + 装箱后可调用 poll（vtable+data）
  - [x] `test_generic_struct_array_future_method.uya` - 回归：泛型结构体数组字段与泛型方法内 `Future<T>{ state: Poll<T>... }` 必须同时正确单态化
  - [x] `test_epoll_syscall.uya` - libc.syscall 提供 epoll_create1/epoll_wait/EpollEvent，通过 `--c99` 与 `--uya --c99`
  - [x] `test_std_async_event.uya` - std.async_event 的 EventLoop/LinuxEpoll 端到端（含 `register -> poll -> wake`），通过 `--c99` 与 `--uya --c99`
  - [x] `test_async_state_machine.uya` - 状态机生成验证（单 @await Pending→Ready 闭环，通过 `--c99` 与 `--uya --c99`）
  - [x] `test_async_multiple_await.uya` - 多 @await 状态机（两处 try @await 顺序执行，返回值 a+b，通过 `--c99` 与 `--uya --c99`）
  - [x] `test_async_error_propagation.uya` - 错误传播（操作数错误直接传播）
  - [x] `test_async_nested.uya` - 多 @async_fn（poll Future&lt;i32&gt;；嵌套 Future&lt;Future&lt;T&gt;&gt; 待完善）
  - [x] `error_async_wrong_return.uya` - @async_fn 返回非 Future<!T>/!Future<T> 时编译报错，预期失败通过
  - [x] `error_await_outside_async.uya` - `try @await` 在非异步函数中使用
  - [x] `error_await_operand_not_error_union.uya` - @await 操作数为 `Future<T>`（缺少 !）应失败
  - [x] `error_await_operand_not_future.uya` - `@await` 操作数既非 `Future<!T>` 也非 `!Future<T>` 时应失败
  - [x] `error_async_recursive.uya` - 递归异步函数（应报错；当前先禁止直接递归，后续由状态机大小计算接管）
  - [x] `error_async_indirect_recursive.uya` - 异步函数形成调用环（如 ping/pong 互相 `@await`）应报错
  - [x] `error_async_too_many_awaits.uya` - `@async_fn` 中 `@await` 超过当前状态机槽位上限（32）应报错
  - [x] `error_async_too_many_params.uya` - `@async_fn` 参数超过当前状态机捕获上限（16）应报错
  - [x] `error_async_await_in_return.uya` - `@await` 在 `return` 之后（unreachable code）应报错
  - [x] `error_async_await_in_while_cond.uya` - `@await` 在 `while`/`for` 循环条件表达式中应报错
  - [x] `test_async_io.uya` - AsyncWriter/AsyncReader 接口与 MemAsyncWriter、MemAsyncReader（含 `write_all` / `read_exact` / `async_print*` helper 与 `UnexpectedEof`）
  - [x] `test_async_fd.uya` - AsyncFd 基于 fd 的 AsyncWriter/AsyncReader（含非阻塞 pipe 上 `EAGAIN -> Pending -> Ready`、`write_all` / `read_exact` / `async_println_to` / `UnexpectedEof`，以及两个真实 pipe 共享一个 `LinuxEpoll` 的队列调度）
  - [x] `test_async_copy.uya` - `async_copy` 覆盖循环内 `@await` 与 `MemAsyncReader`/`MemAsyncWriter`（当前走 `Future<!usize>` 主路径）
  - [x] `test_async_channel.uya` - `Channel<T>` / `MpscChannel<T>` generic send/recv、单槽容量下的 CAS 抢占/满槽 Pending、以及多槽容量下的 FIFO/环回
  - [x] `test_std_ring_queue.uya` - `RingQueue<T>` 运行时容量、满队列拒绝与出队后再入队的环回顺序
  - [x] `test_block_on.uya` - block_on 同步运行 Future<!T> 直到 Ready
  - [x] `test_std_async_waker.uya` - `Waker` 的 `wake/reset/is_woken` 最小状态语义
  - [x] `test_std_async_scheduler.uya` - `Scheduler`、`scheduler_run_i32`、`scheduler_run_i32_with_event_loop`、`scheduler_run_pair_i32_with_event_loop`、`TaskQueue<T>` / `TaskQueue_i32` / `TaskQueue_u32`、`scheduler_run_task_queue_with_event_loop<T>`（Pending 时驱动 `EventLoop.poll()`；同步 `wake()` 时直接重试；共享 EventLoop 单轮唤醒、泛型 `u32` 队列、取消语义、外部 `eventfd` wake 全覆盖）
  - [x] `test_async_method_interface.uya` - 结构体内部 async 方法、方法块 async 实现与接口 async 方法签名的 direct call / vtable dispatch 回归
  - [x] `test_interface_error_union_method.uya` - 接口方法与受约束泛型方法返回 `!T` 时，`try`/`catch` 类型推断正确

**涉及**：Lexer、AST、Parser、Checker、Codegen（CPS 变换、状态机生成），uya-src。

**参考文档**：
- [uya.md](uya.md) §18 - 异步编程完整规范
- [grammar_formal.md](grammar_formal.md) - 正式BNF语法规范（需添加异步编程BNF）
- [changelog.md](changelog.md) §0.40.4 - 异步编程基础设施变更

**实现优先级**：中（建议在原子类型实现后考虑，因为标准库中的 `Channel` 和 `MpscChannel` 依赖原子类型）

**技术难点**：
1. **CPS 变换**：将异步函数转换为状态机需要复杂的代码变换
2. **状态机生成**：需要正确保存和恢复局部变量状态
3. **状态机大小计算**：编译期计算状态机大小，检测递归调用
4. **Send/Sync 推导**：编译期验证跨线程安全性

---

## 内置与标准库（补充）

- [x] **@size_of/@align_of**：保持（以 @ 开头），支持基础类型、数组、结构体、切片等类型集合（规范 uya.md §16）
- [x] **@len**：扩展至切片等，规范 uya.md §16  
  **C 实现（已完成）**：Checker 支持数组（TYPE_ARRAY）和切片（TYPE_SLICE）类型；Codegen 对切片表达式生成 `.len` 访问，对切片字段也支持 `.len` 访问。测试 test_slice.uya 通过 `--c99`。**uya-src 已同步**：checker.uya、codegen/c99/expr.uya。通过 `--uya --c99`。
- [x] **@error_id**：读取 `error` 值的数值 ID，可用于 `@syscall` 失败路径的 errno 判定（规范 uya.md §16）
  **C 实现（已完成）**：Lexer/AST/Parser/Checker/Codegen 已新增 `@error_id(err)`；支持 `error.NamedFailure` 字面量与 `catch |err|` 绑定值；对 `@syscall` 失败路径返回 errno 数值。测试 `test_error_id_builtin.uya` 通过 `--c99` 与 `--uya --c99`，完整 `make check` 通过。
- [x] **@src_name/@src_path/@src_line/@src_col/@func_name 内置函数**：源代码位置信息和函数名（v0.2.31 已完成）
  - [x] Lexer：识别新内置函数（C 实现与 uya-src 已同步）
  - [x] AST：添加 AST_SRC_NAME/AST_SRC_PATH/AST_SRC_LINE/AST_SRC_COL/AST_FUNC_NAME 节点（C 实现与 uya-src 已同步）
  - [x] Parser：解析无参数调用（C 实现与 uya-src 已同步）
  - [x] Checker：类型推断（&[i8] 或 i32），@func_name 仅在函数体内可用（C 实现与 uya-src 已同步）
  - [x] Codegen：生成字符串常量或整数常量，@func_name 从 current_function_decl 获取函数名；字符串常量自动去重优化（C 实现与 uya-src 已同步）
  - [x] 测试用例：test_src_location.uya、test_func_name_simple.uya（C 版 `--c99` 和自举版 `--uya --c99` 均通过）
  - [x] 自举对比：C 编译器与自举编译器生成的 C 文件完全一致
  - [x] 完整文档：`docs/builtin_functions.md`（已同步 `@error_id`、异步内置最新状态与内置函数总览）
- [x] **忽略标识符 _**：用于忽略返回值、解构、match，规范 uya.md §3

**忽略标识符 _（已实现）**：Parser 在 primary_expr 中当标识符为 `_` 时生成 AST_UNDERSCORE；解构中 `_` 已支持（names 含 `"_"` 时 checker/codegen 跳过）。Checker：`_ = expr` 仅检查右侧；禁止 `var _`、参数 `_`；infer_type 对 AST_UNDERSCORE 报错「不能引用 _」。Codegen：`_ = expr` 语句生成 `(void)(expr);`，表达式生成 `(expr)`。测试 `test_underscore.uya` 通过 `--c99`；uya-src 已同步，自举编译通过。

---

## 17. test 关键字（测试单元）

**语法规范**：`test "测试说明" { statements }`，规范 [grammar_formal.md](grammar_formal.md) §4.1、[uya.md](uya.md) 第 28 章。

**语法说明**：
- `test`：测试关键字
- `STRING`：测试说明文字（字符串字面量）
- `statements`：测试函数体语句
- 可写在任意文件、任意作用域（顶层/函数内/嵌套块）

**示例**：
```uya
test "基本算术运算" {
    const x: i32 = 10;
    const y: i32 = 20;
    const sum: i32 = x + y;
    if sum != 30 {
        return;  // 测试失败
    }
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "函数调用测试" {
    const result: i32 = add(5, 3);
    if result != 8 {
        return;  // 测试失败
    }
}
```

**实现状态**：

- [x] **Lexer**：识别 `test` 关键字
  - [x] 添加 `TOKEN_TEST` Token 类型
  - [x] 在 `read_identifier_or_keyword` 中识别 `test` 关键字

- [x] **AST**：测试单元节点
  - [x] 添加 `AST_TEST_STMT` 节点类型
  - [x] 添加 `ASTTestStmt` 结构体（包含 `description` 字符串和 `body` 语句块）

- [x] **Parser**：解析测试单元语法
  - [x] 在 `parser_parse_declaration` 和 `parser_parse_statement` 中识别 `test` 关键字
  - [x] 解析 `test STRING { statements }` 语法
  - [x] 支持在顶层、函数内、嵌套块中解析测试单元

- [x] **Checker**：测试单元语义检查
  - [x] 测试单元内的语句类型检查
  - [x] 测试单元内可以使用外部作用域的变量和函数
  - [x] 测试单元内可以访问模块级别的声明
  - [x] 测试单元内允许 `return;` 语句（void 类型）

- [x] **Codegen**：测试单元代码生成
  - [x] 生成测试函数（如 `uya_test_<hash>()`，使用哈希避免中文函数名问题）
  - [x] 测试函数命名规则（基于测试说明字符串哈希生成唯一函数名）
  - [x] 测试函数调用机制（生成 `uya_run_tests()` 函数，在 `uya_main()` 开始时调用）
  - [x] 测试失败处理（测试函数中 `return;` 表示测试失败）

- [x] **测试运行器**：
  - [x] 自动收集所有测试单元（从顶层和嵌套块中递归收集）
  - [x] 生成测试运行函数 `uya_run_tests()`
  - [x] 在 `uya_main()` 开始时自动调用测试运行器

- [x] **测试用例**：
  - [x] `test_test_basic.uya` - 基本测试单元语法
  - [x] `test_test_nested.uya` - 嵌套块中的测试单元
  - [x] `test_test_multiple.uya` - 多个测试单元

**C 实现（已完成）**：Lexer（TOKEN_TEST）、AST（AST_TEST_STMT、test_stmt 结构体）、Parser（顶层和语句中解析 test 语句）、Checker（测试体语义检查，允许 void 类型的 return）、Codegen（收集测试语句、生成测试函数和运行器、在 uya_main 开始时调用）。测试用例通过 `--c99`。

**uya-src 已同步**：Lexer（TOKEN_TEST、is_keyword 识别 test）、AST（AST_TEST_STMT、test_stmt_description/test_stmt_body 字段）、Parser（parser_parse_statement 和 parser_parse_declaration 中解析 test 语句）、Checker（AST_TEST_STMT 分支，临时设置 void 返回类型和 in_function=1）、Codegen（collect_tests_from_node、get_test_function_name、gen_test_function、gen_test_runner、在 c99_codegen_generate 中收集和生成测试、在 function.uya 的 main 函数开始时调用 uya_run_tests、stmt.uya 中忽略 AST_TEST_STMT）。测试用例 test_test_basic.uya、test_test_nested.uya、test_test_multiple.uya 通过 `--uya --c99`。

**涉及**：Lexer、AST、Parser、Checker、Codegen（测试函数生成、测试运行器），uya-src。

**参考文档**：
- [grammar_formal.md](grammar_formal.md) §4.1 - 测试单元语法
- [uya.md](uya.md) 第 28 章 - Uya 测试单元（Test Block）

**实现优先级**：中（建议在核心功能稳定后实现，便于编写内联测试）

---

## 文档与测试约定

- **先添加测试用例**：在编写编译器代码前，先在 `tests/` 添加测试用例（如 `test_xxx.uya` 或预期编译失败的 `error_xxx.uya`），覆盖目标场景。
- 新特性先在完整版 spec [uya.md](uya.md) 中定义类型、BNF、语义、C99 映射。
- 测试放在 `tests/`，需同时通过 `--c99` 与 `--uya --c99`。
- **测试用例 100% 覆盖**：新特性需添加多场景用例（含成功路径与预期失败用例 `error_*.uya`），覆盖主要分支与边界情况。
- 实现顺序：Lexer → AST → Parser → Checker → Codegen；C 实现与 `uya-src/` 同步。

### 测试覆盖统计

**当前状态**：560 个测试任务，全部通过

| 类别 | 数量 | 说明 |
|------|------|------|
| **正常测试** | 299+ | `test_*.uya`，预期编译并运行成功 |
| **错误测试** | 52 | `error_*.uya`，预期编译失败 |
| **其他测试** | 46+ | 基础测试、递归测试等 |
| **多文件测试** | 若干 | `multifile/`、`cross_deps/` 目录 |
| **std.async 相关** | 20+ | `test_async_state_machine.uya`、`test_async_multiple_await.uya`、`test_async_copy.uya`、`test_std_async_event.uya`、`test_std_async_scheduler.uya` 等 |

**测试分类**：

| 功能模块 | 测试文件 | 说明 |
|----------|----------|------|
| **基础语法** | `test_*.uya` (基础) | 变量、函数、控制流 |
| **类型系统** | `test_int_types.uya`, `test_float.uya`, `test_bool.uya`, `test_byte.uya` | 整数、浮点、布尔、字节 |
| **数组与切片** | `test_array_*.uya`, `test_slice.uya`, `test_multidimensional_array.uya` | 数组操作、切片、多维数组 |
| **结构体** | `test_struct_*.uya` | 结构体定义、方法、默认值 |
| **联合体** | `test_union*.uya`, `test_extern_union.uya` | union、extern union |
| **接口** | `test_interface*.uya`, `test_struct_method_with_interface.uya` | interface、接口组合 |
| **泛型** | `test_generic*.uya` (30+ 个) | 泛型函数、结构体、接口、约束 |
| **宏系统** | `test_macro*.uya` (20+ 个) | mc 宏、@mc_eval、插值 |
| **错误处理** | `test_error*.uya`, `test_errdefer*.uya`, `test_defer*.uya` | !T、defer、errdefer |
| **内存安全** | `test_bounds*.uya`, `test_null*.uya`, `test_move*.uya` | 边界检查、空指针、移动语义 |
| **标准库** | `test_std_*.uya`, `test_crypto_*.uya`, `test_syscall*.uya`, `test_unistd.uya` | std.string, std.mem, std.io, std.crypto |
| **原子类型** | `test_atomic*.uya` | atomic T |
| **可变参数** | `test_varargs*.uya`, `test_va_builtin.uya` | ...、@params |
| **字符串插值** | `test_string_interp*.uya` | ${} 语法 |
| **内存安全证明** | `test_path_*.uya`, `test_proof*.uya` | 约束证明、符号执行 |
| **导出与 FFI** | `test_export*.uya`, `test_ffi*.uya`, `test_extern*.uya` | export、extern、FFI |
| **内建函数** | `test_print*.uya`, `test_src_location.uya`, `test_len*.uya`, `test_error_id_builtin.uya` | @print、@src_*、@len、@error_id |

### 测试程序约定

- **测试文件命名**：
  - 正常测试：`test_xxx.uya`（测试通过时返回 0）
  - 预期编译失败：`error_xxx.uya`（以 `error_` 开头，测试脚本会自动识别为预期编译失败）
- **测试返回值**：
  - 测试通过应返回 0（退出码 0）
  - 测试失败应返回非 0（退出码表示错误类型）
  - 测试脚本通过 `bridge.c` 提供 `main` 函数，调用 `uya_main()`（Uya 的 `main` 函数被重命名为 `uya_main`）
- **多文件测试**：
  - 多文件测试放在 `tests/multifile/` 或 `tests/cross_deps/` 目录下
  - 测试脚本会自动收集目录下所有 `.uya` 文件一起编译
- **语法约定**：
  - `use` 语句只能在顶层使用，不能在函数体内
  - 结构体按值传递会被移动，移动后不能再次使用（需重新创建变量）
  - `export` 关键字用于标记可导出的项（函数、结构体等）
- **验证要求**：
  - 每个测试用例必须同时通过 `--c99`（C 版编译器）和 `--uya --c99`（自举版编译器）
  - 二者都通过才算测试通过

### 测试运行指南

```bash
# 运行所有测试（使用 C 版编译器）
./tests/run_programs.sh

# 运行所有测试（使用自举编译器）
./tests/run_programs.sh --uya

# 只显示失败的测试
./tests/run_programs.sh -e

# 运行单个测试
./tests/run_programs.sh test_generic_simple.uya
./tests/run_programs.sh --uya test_generic_simple.uya

# 运行指定目录的测试
./tests/run_programs.sh tests/multifile

# 快速验证（并行执行）
./tests/run_programs_parallel.sh

# 使用 make 命令
make tests-uya      # 运行所有测试
make check          # 自举 + 测试
```

### 测试错误分类（error_*.uya）

| 错误类别 | 测试文件 | 检测内容 |
|----------|----------|----------|
| **类型错误** | `error_type_mismatch.uya` | 类型不匹配 |
| **常量错误** | `error_const_*.uya` | 常量重赋值、溢出、除零 |
| **移动语义** | `error_move_*.uya` | 移动后使用、循环中移动 |
| **内存安全** | `error_null_deref.uya`, `error_uninitialized_var.uya` | 空指针解引用、未初始化变量 |
| **边界检查** | `error_bounds_need_proof.uya`, `error_path_*.uya` | 数组越界、循环边界证明 |
| **控制流** | `error_defer_*.uya` | defer 中 return/break/continue |
| **接口** | `error_interface_*.uya` | 接口组合缺失、循环依赖 |
| **泛型** | `error_generic_constraint_fail.uya` | 泛型约束失败 |
| **宏** | `error_macro_*.uya` | mc 宏错误 |
| **可变参数** | `error_va_start_non_varargs.uya` | va_start 使用错误 |

### 完成任务后更新本文档

完成某项或某阶段实现后，请同步更新本待办文档，便于跟踪进度、与 Cursor 计划联动：

1. **勾选子项**：在该阶段的小节内，将已完成的具体子项复选框由 `[ ]` 改为 `[x]`。
2. **更新总览状态**：若某阶段（如「1. 基础类型与字面量」）下的**全部**子项均已完成，在文首「建议实现顺序（总览）」表中，将该阶段的状态由 `[ ]` 改为 `[x]`。
3. **类型系统详表（可选）**：若实现涉及「类型系统扩展（详表）」中的某行，可在该表中同步勾选或标注对应行，便于与 Mini 现状/完整版目标对照。

---

## 类型系统扩展（详表，供实现时勾选）

| 待办 | Mini 现状 | 完整版目标 | 规范 | 状态 |
|------|-----------|------------|------|------|
| 整数类型 | i32, usize, byte | + i8, i16, i64, u8, u16, u32, u64 | uya.md §2 | [x] |
| 类型极值 | 无 | @max, @min 内置函数（以 @ 开头） | uya.md §2、§16 | [x] |
| 切片类型 | 无 | &[T], &[T: N] | uya.md §2、§4 | [x] |
| 元组类型 | 无 | (T1, T2,...), .0/.1, 解构 | uya.md §2 | [x] |
| 错误联合 !T | 无 | !T, error 定义 | uya.md §2、§5 | [x] |
| 联合体类型 | 无 | union U { v1: T1, v2: T2 } | uya.md §4.5 | [x] |
| 接口类型 | 无 | interface I, struct S : I | uya.md §6 | [x] |
| 函数指针 | 无 | fn(...) type, type Alias = fn(...) type | uya.md §5.2 | [ ] |
| 原子类型 | 无 | atomic T, &atomic T | uya.md §13 | [x] |
| 类型别名 | 无 | type A = B | uya.md §5.2、§24.6.2 | [x] v0.2.31 |
| 多维数组 | 无 | [[T: N]: M]，多维访问 arr[i][j] | uya.md §2、§4 | [x] |
| 结构体默认值 | 无 | field: Type = default_value, Struct{} | uya.md §4.3 | [x] v0.2.31 |
| &void 通用指针 | 部分 | &void → &T 类型擦除 | uya.md §2 | [~] |
| 块注释 | 完整 | /* ... */（可嵌套） | uya.md §1 | [x] |

---

## 19. 标准库基础设施（std）- 重构计划 v0.6.0

**核心设计理念**：分层架构，std 使用 Uya 现代特性，libc 在 std 基础上做薄封装。

### 19.0 架构重构目标

| 层级 | 名称 | 特性 | 用途 |
|------|------|------|------|
| **std/** | Uya 标准库 | !T, interface, 泛型, union, mc | Uya 程序首选 |
| **libc/** | C 兼容层 | 薄封装，C99 ABI，零依赖 | C 程序互操作 |

**设计原则**：

1. **std 使用 Uya 现代特性**
   - `!T` 错误处理替代裸指针返回
   - `interface` 定义抽象（Writer, Reader, Iterator）
   - `union Option<T>` 类型安全
   - 泛型容器（Vec<T>, HashMap<K, V>）
   - `mc` 宏实现编译期优化

2. **libc 是 std 的薄封装**
   - 保持 C99 标准库签名兼容（musl/glibc）
   - 内部调用 std 实现，零重复代码
   - 更安全的 API（边界检查、空指针防护）

3. **分层依赖**
   ```
   libc/  →  std/  →  syscall/
   (C ABI)  (Uya)    (底层)
   ```

### 19.0.1 新架构概览

```
lib/
├── std/                          # Uya 风格标准库（使用现代特性）
│   ├── core/                     # 核心类型和 trait
│   │   ├── error.uya             # 错误类型定义（使用 union）
│   │   ├── option.uya            # Option<T> = union { Some: T, None }
│   │   └── traits.uya            # 核心接口（Clone, Eq, Ord, Hash）
│   ├── io/                       # I/O 抽象（使用 interface）
│   │   ├── writer.uya            # interface Writer { write(&Self, &[u8]) !usize }
│   │   ├── reader.uya            # interface Reader { read(&Self, &[u8]) !usize }
│   │   └── file.uya              # struct File : Writer, Reader
│   ├── string/                   # 字符串操作（使用 !T 错误处理）
│   │   └── string.uya            # fn parse_int(s: &str) !i32
│   ├── mem/                      # 内存操作
│   │   └── mem.uya               # fn copy(dst: &T, src: &const T, n: usize)
│   ├── collections/              # 泛型容器
│   │   ├── vec.uya               # struct Vec<T> { ... }
│   │   └── map.uya               # struct HashMap<K: Hash, V> { ... }
│   ├── syscall/                  # 系统调用封装
│   │   └── linux.uya             # Linux syscall 封装
│   ├── fmt/                      # 格式化（纯 Uya）
│   │   └── fmt.uya               # fn format<T: Display>(v: T) !String
│   └── runtime/                  # 运行时支持
│       └── runtime.uya           # 程序入口、panic 处理
│
└── libc/                         # C 兼容层（薄封装）
    ├── syscall.uya               # syscall 封装（调用 std.syscall）
    ├── string.uya                # C 签名：strlen, strcmp...（调用 std.string）
    ├── stdio.uya                 # C 签名：printf, fopen...（调用 std.io）
    ├── stdlib.uya                # C 签名：malloc, free...（调用 std.mem）
    ├── mem.uya                   # C 签名：memcpy, memset...
    └── unistd.uya                # C 签名：read, write...
```

### 19.0.2 Sprint 6: std.core 核心类型（1 周）⭐⭐⭐⭐⭐

**目标**：实现 Option<T>, Error 等核心类型

- [ ] **std.core.error** - 错误类型
  ```uya
  // 错误类型定义
  union Error {
      None,                        // 无错误
      Message: &[i8],             // 错误消息
      Code: i32,                  // 错误码
      System: i32                 // 系统错误码（errno）
  }
  
  export fn error_message(e: &Error) &const byte;
  export fn error_from_errno(errno: i32) Error;
  ```

- [ ] **std.core.option** - Option<T> 类型
  ```uya
  union Option<T> {
      Some: T,
      None
  }
  
  // 泛型方法（需要编译器支持）
  fn is_some<T>(self: &Option<T>) bool;
  fn is_none<T>(self: &Option<T>) bool;
  fn unwrap<T>(self: &Option<T>) !T;  // None 时返回错误
  fn unwrap_or<T>(self: &Option<T>, default: T) T;
  ```

- [ ] **std.core.traits** - 核心接口
  ```uya
  // Clone 接口
  interface Clone {
      fn clone(self: &Self) Self;
  }
  
  // Eq 接口
  interface Eq {
      fn eq(self: &Self, other: &Self) bool;
  }
  
  // Ord 接口
  interface Ord {
      fn cmp(self: &Self, other: &Self) i32;  // -1, 0, 1
  }
  
  // Hash 接口
  interface Hash {
      fn hash(self: &Self) u64;
  }
  
  // Display 接口
  interface Display {
      fn fmt(self: &Self, writer: &Writer) !void;
  }
  ```

- [x] **std.mem.allocator** - **`IAllocator` + `MallocAllocator`**（hosted，malloc/realloc/free）⭐⭐⭐⭐⭐
  
  **当前落地**（2026-03）：**`lib/std/mem/allocator.uya`**；**`export interface IAllocator`**（`alloc` / `dealloc` / `realloc`，**`!&byte`**）；**`MallocAllocator`**、**`g_allocator`**、**`get_allocator()`**；测试 **`tests/test_mem_allocator.uya`**。文档：**`docs/todo_std_refactor.md`** §2.1、**`docs/std_refactor_design.md`**（v0.7.2）。
  
  **设计理念（延续 v0.6.0）**：借鉴 Zig 的分配器设计，提供可插拔、类型安全的内存分配接口。下列代码块为**早期草图**，与当前源码在返回类型（`&byte` vs `&void`）、错误表示（`error` vs `union`）及方法集上**不完全一致**；扩展 **`HeapAllocator`（mmap）**、**`alloc_zeroed` / `resize` / `create` / `destroy`** 等待办。
  
  ```uya
  // std/mem/allocator.uya
  
  /// 分配错误类型
  union AllocError {
      None,
      OutOfMemory,           // 内存不足
      InvalidAlignment,      // 无效对齐要求
      InvalidPointer,        // 无效指针（释放/调整大小时）
  }
  
  /// Zig 风格分配器接口
  /// 设计原则：显式传递分配器，避免全局状态
  interface IAllocator {
      /// 分配 size 字节内存，返回 null 表示失败
      /// 对齐：默认按 usize 大小对齐
      fn alloc(self: &Self, size: usize) !&void;
      
      /// 分配并清零
      fn alloc_zeroed(self: &Self, size: usize) !&void;
      
      /// 释放内存
      fn free(self: &Self, ptr: &void) void;
      
      /// 调整内存大小（可选，返回 null 表示需要手动 alloc+copy+free）
      fn resize(self: &Self, ptr: &void, old_size: usize, new_size: usize) !&void;
      
      /// 创建单个对象（分配 + 构造）
      fn create<T>(self: &Self) !&T;
      
      /// 销毁单个对象（析构 + 释放）
      fn destroy<T>(self: &Self, ptr: &T) void;
  }
  
  /// 全局堆分配器（默认实现）
  struct HeapAllocator : IAllocator {
      fn alloc(self: &Self, size: usize) !&void {
          // 调用 syscall.mmap
      }
      fn free(self: &Self, ptr: &void) void {
          // 调用 syscall.munmap
      }
  }
  
  /// 全局分配器实例
  const heap_allocator: HeapAllocator = HeapAllocator{};
  
  /// 便捷函数（使用全局分配器）
  fn alloc(size: usize) !&void { return heap_allocator.alloc(size); }
  fn free(ptr: &void) void { heap_allocator.free(ptr); }
  ```
  
  **内置分配器实现**：
  
  ```uya
  /// Arena 分配器 - 线性分配，批量释放
  struct ArenaAllocator : IAllocator {
      buffer: &[u8],
      offset: usize,
      
      fn alloc(self: &Self, size: usize) !&void {
          if self.offset + size > self.buffer.len {
              return AllocError.OutOfMemory;
          }
          const ptr: &void = self.buffer[self.offset] as &void;
          self.offset += size;
          return ptr;
      }
      
      /// 重置 arena（释放所有分配）
      fn reset(self: &Self) void {
          self.offset = 0;
      }
      
      /// Arena 不支持单独 free
      fn free(self: &Self, ptr: &void) void { /* no-op */ }
  }
  
  /// 固定缓冲区分配器 - 栈上分配，零堆开销
  struct FixedBufferAllocator : IAllocator {
      buffer: &[u8],
      offset: usize,
      
      fn init(buf: &[u8]) FixedBufferAllocator {
          return FixedBufferAllocator{ buffer: buf, offset: 0 };
      }
  }
  
  /// 日志分配器 - 包装器，记录所有分配操作
  struct LoggingAllocator : IAllocator {
      child: &IAllocator,
      name: &const byte,
      
      fn alloc(self: &Self, size: usize) !&void {
          @print("alloc: ");
          @print(self.name);
          @print(" size=");
          @println(size);
          return self.child.alloc(size);
      }
  }
  ```
  
  **使用示例**：
  
  ```uya
  // 显式传递分配器
  fn Vec<T>.with_capacity(alloc: &IAllocator, cap: usize) !Vec<T> {
      return Vec<T>{
          data: alloc.alloc(cap * @size_of(T)) as &T,
          len: 0,
          cap: cap,
          allocator: alloc
      };
  }
  
  // 使用 arena 进行临时分配
  fn process_data(arena: &ArenaAllocator) !void {
      const temp: &byte = arena.alloc(1024);
      // ... 使用 temp ...
      arena.reset();  // 批量释放
  }
  
  // 栈上分配
  fn stack_example() void {
      var buf: [4096]u8;
      var arena: ArenaAllocator = ArenaAllocator.init(buf[0..]);
      // 使用 arena 分配临时数据
      const temp: &byte = arena.alloc(100)!;
      // 函数返回时 buf 在栈上自动释放
  }
  ```

### 19.0.3 Sprint 7: std.io I/O 抽象层（1 周）⭐⭐⭐⭐

**目标**：使用 interface 定义 I/O 抽象

- [ ] **std.io.writer** - Writer 接口
  ```uya
  interface Writer {
      fn write(self: &Self, data: &[u8]) !usize;
      fn write_str(self: &Self, s: &const byte) !usize;
      fn flush(self: &Self) !void;
  }
  
  // 辅助函数
  fn write_all(w: &Writer, data: &[u8]) !void;
  fn write_byte(w: &Writer, b: u8) !void;
  ```

- [ ] **std.io.reader** - Reader 接口
  ```uya
  interface Reader {
      fn read(self: &Self, buf: &[u8]) !usize;
      fn read_exact(self: &Self, buf: &[u8]) !void;
  }
  
  // 辅助函数
  fn read_to_end(r: &Reader, buf: &Vec<u8>) !usize;
  fn read_line(r: &Reader, buf: &[u8]) !usize;
  ```

- [ ] **std.io.file** - File 实现
  ```uya
  struct File : Writer, Reader {
      fd: i32,
      path: &[i8],
      
      fn open(path: &const byte, mode: i32) !File;
      fn close(self: &Self) !void;
      fn write(self: &Self, data: &[u8]) !usize;
      fn read(self: &Self, buf: &[u8]) !usize;
  }
  
  // 标准流
  const stdin: File = File{ fd: 0, ... };
  const stdout: File = File{ fd: 1, ... };
  const stderr: File = File{ fd: 2, ... };
  ```

### 19.0.4 Sprint 8: std.string 字符串操作（1 周）⭐⭐⭐⭐

**目标**：使用 !T 错误处理重构字符串操作

- [ ] **std.string.string** - 安全字符串操作
  ```uya
  // 安全版字符串函数（使用 !T 返回错误）
  export fn strlen(s: &const byte) usize;
  export fn strcmp(s1: &const byte, s2: &const byte) i32;
  
  // 返回错误版本
  export fn parse_int(s: &const byte) !i32;
  export fn parse_uint(s: &const byte) !u32;
  export fn parse_float(s: &const byte) !f64;
  
  // 切片操作
  export fn split(s: &const byte, delim: byte) Vec<&[i8]>;
  export fn trim(s: &const byte) &const byte;
  export fn to_lower(s: &byte) void;
  export fn to_upper(s: &byte) void;
  
  // 安全复制
  export fn copy_safe(dst: &byte, dst_len: usize, src: &const byte) !void;
  export fn cat_safe(dst: &byte, dst_len: usize, src: &const byte) !void;
  ```

### 19.0.5 Sprint 9: std.collections 泛型容器（2 周）⭐⭐⭐

**目标**：实现泛型容器（需要泛型编译器支持）

- [ ] **std.collections.vec** - 动态数组
  ```uya
  struct Vec<T> {
      data: &T,
      len: usize,
      cap: usize,
      
      fn new() Vec<T>;
      fn with_capacity(cap: usize) !Vec<T>;
      fn push(self: &Self, value: T) !void;
      fn pop(self: &Self) Option<T>;
      fn get(self: &Self, i: usize) !&T;      // 边界检查
      fn get_unchecked(self: &Self, i: usize) &T;
      fn len(self: &Self) usize;
      fn is_empty(self: &Self) bool;
      fn clear(self: &Self) void;
      fn drop(self: &Self) void;              // RAII
  }
  ```

- [ ] **C99 codegen：`Vec<本地复合结构体>` / 嵌套 `Vec` 的 `err_union_*` 完整性**（标准库跟进项）
  - **现象**：对含指针字段或特定单态的结构体，`err_union_Foo` 在 C 中可能未完整定义即被 `Vec_Foo_get` / `pop` 等使用，导致 gcc 失败；`Vec<Vec<T>>` 亦有生成顺序与类型名问题。
  - **影响**：`lib/std/collections/hashmap.uya` 当前用 `HashMapChainBuf`（手写扩容）代替 `Vec<槽位>` 存冲突链；修复后可删重复逻辑并统一使用 `Vec`。
  - **涉及**：`src/codegen/c99/`（错误联合与单态结构体 emit 顺序、泛型 `Vec` 单态方法生成）。

- [x] **std.collections.string_buf** - 字符串缓冲区（已落地：内联 `byte` 缓冲实现，避免嵌套 `Vec<byte>` 触发 C99 后端发射顺序问题）
  ```uya
  struct StringBuf {
      data: &byte,
      len: usize,
      cap: usize,
      
      fn new() StringBuf;
      fn push(self: &Self, c: byte) !void;
      fn push_str(self: &Self, s: &const byte) !void;
      fn as_str(self: &Self) &[const byte];
      fn append_slice(self: &Self, s: &[const byte]) !void;
      fn clear(self: &Self) void;
      fn is_empty(self: &Self) bool;
      fn pop_byte(self: &Self) !byte;
      fn truncate(self: &Self, new_len: usize) !void;
      fn starts_with(self: &Self, prefix: &[const byte]) bool;
      fn ends_with(self: &Self, suffix: &[const byte]) bool;
      fn contains_byte(self: &Self, b: byte) bool;
      fn set_byte(self: &Self, i: usize, b: byte) !void;
  }
  ```

### 19.0.6 Sprint 10: libc 薄封装（1 周）⭐⭐⭐⭐

**目标**：在 std 基础上实现 C 兼容层

- [ ] **libc.string** - C 签名字符串函数
  ```uya
  // 薄封装：调用 std.string，保持 C 签名
  export extern fn strlen(s: *const byte) usize {
      return std.strlen(s as &const byte);
  }
  
  export extern fn strcmp(s1: *const byte, s2: *const byte) i32 {
      return std.strcmp(s1 as &const byte, s2 as &const byte);
  }
  
  // 安全增强版
  export extern fn strcpy(dst: *byte, src: *const byte) *byte {
      const len: usize = std.strlen(src as &const byte);
      std.mem.copy(dst as &byte, src as &const byte, len + 1);
      return dst;
  }
  ```

- [ ] **libc.stdio** - C 签名 I/O 函数
  ```uya
  // 薄封装：调用 std.io，保持 C 签名
  export extern fn fopen(path: *const byte, mode: *const byte) *FILE {
      const m: i32 = parse_mode(mode);
      const f: !std.io.File = std.io.File.open(path as &const byte, m);
      if f is error { return null; }
      return to_file_ptr(f);
  }
  
  export extern fn fclose(fp: *FILE) i32 {
      const f: &std.io.File = from_file_ptr(fp);
      const r: !void = f.close();
      if r is error { return -1; }
      return 0;
  }
  ```

**关键特性**：
- ✅ **完全用 Uya 实现**：std 是纯 Uya 代码，不是 FFI 绑定
- ✅ **零外部依赖**：直接使用系统调用，不依赖任何 C 库
- ✅ **单文件输出**：`--outlibc` 生成单个 .c 和 .h 文件
- ✅ **可替代 musl/glibc**：兼容 C ABI，可作为 libc 使用
- ✅ **类型安全**：std 使用 !T, Option<T>
- ✅ **泛型容器**：Vec<T>, HashMap<K, V>

**实施路线**：

1. **阶段 0**：基础设施（`@syscall` 内置函数、错误类型）
2. **阶段 1**：单平台验证（Linux x86-64 MVP）
3. **阶段 2**：条件编译（`use std; std.cfg(...)` + `std.host_os/std.target_arch`）；**首个验收用例**：编译器 **host** 可执行路径解析 + **`dirent` 布局**（见 [`docs/std_c_design.md`](./std_c_design.md)「`std.cfg` / `std` 平台选择器：条件编译」）
4. **阶段 3**：多平台扩展（macOS、ARM64）
5. **阶段 4**：Windows 支持（可选）

**详细设计内容**（包括系统调用层、跨平台方案、条件编译、核心库实现、--outlibc 功能等）请参见：[`docs/std_c_design.md`](./docs/std_c_design.md)

**跨平台迁移详细待办**：见 [todo_multiplatform_migration.md](todo_multiplatform_migration.md)；共享平台基础见 [todo_platform_shared_foundation.md](todo_platform_shared_foundation.md)。

### 19.1 v0.3.0 实施计划（标准库基础设施）

**目标时间**：2026 Q1（约 5-7 周）

**核心目标**：
1. ✅ 实现 `@syscall` 内置函数（Linux 系统调用）
2. ✅ 实现 `std.c` 核心模块（零外部依赖）
3. ✅ 编译器自身使用 `-nostdlib` 构建成功
4. ✅ 生成 `--outlibc` 独立 C 库

---

#### Sprint 1: @syscall 内置函数（1-2 周）⭐⭐⭐⭐⭐ ✅ 已完成

**设计**：
- 语法：`@syscall(nr, arg1, arg2, ..., arg6)` → 返回 `!i64`
- 参数：syscall_number（整数常量），最多 6 个参数
- 错误：负数返回值自动转换为错误（如 -EBADF → error.BadFileDescriptor）

**任务清单**：
- [x] **Lexer**：识别 `@syscall` 关键字（添加到 `is_builtin_function`）
- [x] **AST**：新增 `AST_SYSCALL` 节点
  - 字段：`syscall_number`（编译期常量表达式）
  - 字段：`args[]`（最多 6 个参数）
- [x] **Parser**：解析 `@syscall(nr, ...args)` 调用
  - 验证参数个数（1-7 个，第一个为 syscall_number）
- [x] **Checker**：类型检查与语义验证
  - syscall_number 必须为整数常量
  - 所有参数类型必须可转换为 i64
  - 返回类型：`!i64`
- [x] **Codegen**：生成内联汇编（x86-64 Linux）
  - 实现 `uya_syscall0` - `uya_syscall6` 辅助函数
  - 使用寄存器约定：rax=nr, rdi/rsi/rdx/r10/r8/r9=args
  - 保留 rcx/r11（syscall 会破坏）
- [x] **测试用例**：
  - `test_syscall_write.uya`（SYS_write=1，写标准输出）
  - `test_syscall_exit.uya`（SYS_exit=60，程序退出）
  - `test_syscall_error.uya`（错误处理，如 EBADF）
  - `test_std_syscall.uya`（syscall 函数封装）
  - `test_syscall_module.uya`（多函数 syscall）
  - `error_syscall_not_const.uya`（syscall_number 非常量，预期失败）
- [x] **uya-src 同步**

**参考**：
- Linux 系统调用表：`/usr/include/asm/unistd_64.h`
- 系统调用约定：`man 2 syscall`

**Codegen 示例**：
```c
// @syscall(1, 1, buf, len) -> SYS_write(1, buf, len)
static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    __asm__ volatile("syscall" 
        : "=r"(rax) 
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
```

---

#### Sprint 2: std.c.syscall 模块（1 周）⭐⭐⭐⭐⭐ ✅ 已完成

**任务清单**：
- [x] **创建目录结构**：`lib/std/c/syscall/syscall.uya`（从 `std/c/syscall.uya` 迁移至 `lib/std/` 下）
- [x] **系统调用号常量**：定义 Linux 系统调用号（SYS_read/write/open/close/stat/fstat/lseek/mmap/munmap/brk/ioctl/access/dup/dup2/getpid/fork/execve/exit/kill/getcwd/chdir/mkdir/rmdir/unlink）
- [x] **文件操作标志**：O_RDONLY/O_WRONLY/O_RDWR/O_CREAT/O_EXCL/O_TRUNC/O_APPEND
- [x] **文件权限常量**：S_IRWXU/S_IRUSR/S_IWUSR/S_IXUSR 等
- [x] **标准文件描述符**：STDIN_FILENO/STDOUT_FILENO/STDERR_FILENO
- [x] **错误码常量**：`export const` 声明（EPERM=1 到 EINVAL=22，22 种标准 errno 错误码；原 `enum Errno : i32` 因 parser 不支持 typed enum 改为独立常量）
- [x] **封装函数**：实现系统调用封装（参数统一使用 i64 类型）
  - `sys_write(fd, buf, count) !i64`
  - `sys_read(fd, buf, count) !i64`
  - `sys_open(path, flags, mode) !i64`
  - `sys_close(fd) !i64`
  - `sys_exit(status) void`
  - `sys_getpid() i64`
  - `sys_lseek(fd, offset, whence) !i64`
  - `sys_access(path, mode) !i64`
  - `sys_unlink(path) !i64`
  - `sys_mkdir(path, mode) !i64`
  - `sys_rmdir(path) !i64`
  - `sys_chdir(path) !i64`
  - `sys_getcwd(buf, size) !i64`
- [x] **测试用例**：
  - `test_std_syscall.uya`（syscall 函数封装，通过 `--c99` 和 `--uya --c99`）
  - `test_syscall_module.uya`（多函数 syscall）

---

#### Sprint 3: std.c.string + std.c.stdio（1-2 周）⭐⭐⭐⭐ ✅ 已完成

**std.c.string（已完成）**：
- [x] **创建文件**：`lib/std/c/string/string.uya`（纯 Uya 实现，零外部依赖；从 `std/c/string.uya` 迁移至 `lib/std/` 下，函数名使用 snake_case 避免 C 名冲突）
- [x] **内存操作函数**：
  - `mem_copy(dest: &byte, src: &byte, n: usize) &byte` - 复制内存块
  - `mem_move(dest: &byte, src: &byte, n: usize) &byte` - 复制内存块（支持重叠）
  - `mem_set(s: &byte, c: byte, n: usize) &byte` - 填充内存块
  - `mem_cmp(s1: &byte, s2: &byte, n: usize) i32` - 比较内存块
  - `mem_find(s: &byte, c: byte, n: usize) i64` - 查找字节（返回索引或 -1）
- [x] **字符串操作函数**：
  - `str_len(s: &byte) usize` - 计算字符串长度
  - `str_cmp(s1: &byte, s2: &byte) i32` - 比较字符串
  - `str_ncmp(s1: &byte, s2: &byte, n: usize) i32` - 比较指定长度字符串
  - `str_copy(dest: &byte, src: &byte) &byte` - 复制字符串
  - `str_ncopy(dest: &byte, src: &byte, n: usize) &byte` - 复制指定长度字符串
  - `str_cat(dest: &byte, src: &byte) &byte` - 连接字符串
  - `str_find(s: &byte, c: byte) i64` - 查找字符首次出现位置
  - `str_rfind(s: &byte, c: byte) i64` - 查找字符最后出现位置
- [x] **测试**：`test_std_string.uya`（8 组测试：str_len/mem_copy/mem_set/mem_cmp/str_cmp/str_copy/str_ncmp/mem_find，通过 `--c99` 和 `--uya --c99`）

**std.c.stdlib（部分完成，存在运行时问题）**：
- [x] **创建文件**：`lib/std/c/stdlib.uya`（基于 @syscall，零外部依赖）
- [x] **内存分配函数**：
  - `malloc(size: usize) &void` - 基于 mmap 的内存分配（使用 &void 类型）
  - `free(ptr: &void) void` - 释放内存（使用 &void 类型，简化实现：固定大小 4096 字节）
  - `calloc(nmemb: usize, size: usize) &void` - 分配并清零（使用 &void 类型）
  - `realloc(ptr: &void, size: usize) &void` - 重新分配内存（简化实现：不复制旧数据）
- [x] **进程控制函数**：
  - `exit(status: i32) void` - 正常退出进程
  - `abort() void` - 异常终止进程（发送 SIGABRT）
- [x] **字符串转数字函数**：
  - `atoi(s: &byte) i32` - 字符串转整数（支持前导空白、符号、数字）
  - `atol(s: &byte) i64` - 字符串转长整数（支持前导空白、符号、数字）
  - `atof(s: &byte) f64` - 字符串转浮点数（简化实现：支持基本格式）
- [x] **测试用例**：
  - `test_std_stdlib_simple.uya` - 字符串转换函数测试（✅ 通过）
  - `test_std_stdlib_malloc_only.uya` - 仅测试 malloc（❌ 段错误）
  - `test_std_stdlib_malloc.uya` - 测试 malloc 和 calloc（❌ 段错误）
- [ ] **已知问题**：
  1. **内存分配函数运行时段错误**：
     - `malloc` 和 `calloc` 在运行时出现段错误（退出码 139）
     - `mmap` 系统调用成功（strace 显示返回有效地址），但后续内存访问失败
     - 可能原因：`&void` 到 `&byte` 的转换问题，或代码生成器对 `&void` 类型的处理问题
     - 需要进一步调试代码生成器对 `&void` 类型的处理
  2. **`free` 函数简化实现**：
     - 当前使用固定大小 4096 字节进行 `munmap`，实际应维护分配表记录每个指针的大小
     - `realloc` 不复制旧数据，实际应维护分配表并复制数据
  3. **`atof` 函数简化实现**：
     - 当前只支持基本格式（整数部分 + 可选小数部分），不支持科学计数法、无穷大、NaN 等

**std.c.stdio（已完成）**：
- [x] **创建文件**：`lib/std/c/stdio/stdio.uya`（基于 @syscall，零外部依赖；从 `std/c/stdio.uya` 迁移至 `lib/std/` 下，函数名使用 snake_case）
- [x] **输出函数**：
  - `put_char(c: i32) i32` - 写入单个字符到 stdout
  - `put_char_fd(c: i32, fd: i64) i32` - 写入单个字符到指定 fd
  - `write_bytes(buf: &byte, n: usize) i64` - 写入 n 字节到 stdout
  - `write_bytes_fd(buf: &byte, n: usize, fd: i64) i64` - 写入 n 字节到指定 fd
  - `put_str_len(s: &byte, len: usize) i32` - 写入指定长度字符串并换行
- [x] **输入函数**：
  - `get_char() i32` - 从 stdin 读取一个字符
  - `read_bytes(buf: &byte, n: usize) i64` - 从 stdin 读取最多 n 字节
  - `read_bytes_fd(buf: &byte, n: usize, fd: i64) i64` - 从指定 fd 读取
- [x] **整数转字符串辅助**：
  - `i32_to_str(value: i32, buf: &byte) usize` - i32 转十进制字符串
  - `i64_to_str(value: i64, buf: &byte) usize` - i64 转十进制字符串
  - `print_i32(value: i32) usize` - 打印 i32 到 stdout
  - `print_i64(value: i64) usize` - 打印 i64 到 stdout
- [x] **测试**：`test_std_stdio.uya`（i32_to_str/put_char/write_bytes，通过 `--c99` 和 `--uya --c99`）

**API 设计说明**：
- 使用 `&byte` 而非 `&void` 作为指针类型（当前 `&void` 仅部分支持）
- 使用 `byte` 而非 `i32` 作为 memset/memchr 的字符参数（更类型安全）
- 使用 `i64` 返回索引而非指针（memchr/strchr/strrchr 找到返回索引，未找到返回 -1）
- 所有函数纯 Uya 实现，唯一依赖为 @syscall（stdio）
- 函数名使用 snake_case（如 `str_len`、`mem_copy`、`put_char`、`sys_write`），避免与 C 标准库函数名冲突
- 标准库位于 `lib/std/` 目录，通过 `UYA_ROOT` 环境变量指向 `lib/`（测试脚本设置 `UYA_ROOT=../lib/`）
- 模块路径使用 `std.c.string`、`std.c.stdio`、`std.c.syscall`

---

#### Sprint 4: 编译器自举（1 周）⭐⭐⭐⭐

**任务清单**：
- [x] **审计编译器代码**：查找所有 C 标准库调用
  - 已完成：编译器不再直接调用 C 标准库函数
  - 仅依赖 C 运行时启动代码 `__libc_start_main`
- [x] **清理冗余 extern fn 声明**：
  - 删除 `checker.uya` 中的 `extern fn fprintf`
  - 删除 `parser.uya` 中未使用的 `extern fn malloc/free`
  - 删除 `arena.uya` 中的 `extern fn exit`
  - 所有标准库函数通过 `use libc.*` 导入
- [x] **替换 C 库调用**：
  - `fprintf` → `libc.fprintf`（纯 Uya 实现，基于 @syscall）
  - `exit` → `libc.exit`（纯 Uya 实现，基于 sys_exit）
  - `strlen/strcmp` → `std.string.*`（纯 Uya 实现）
  - `memcpy/memset` → `std.mem.*`（纯 Uya 实现）
- [x] **修改 Makefile**：
  - 已添加 `make uya-nostdlib` 目标
  - 创建自定义 `_start.S` 入口点（`lib/std/runtime/entry/_start.S`）
  - 修改 `compile.sh` 支持 `--nostdlib` 链接
- [x] **测试构建**：
  ```bash
  make uya-nostdlib  # 构建 nostdlib 版本编译器
  ```
- [x] **验证零依赖**：
  ```bash
  ldd bin/uya  # 输出: 不是动态可执行文件
  nm bin/uya | grep " U "  # 无未定义符号
  ```
- [x] **uya-src 同步**：编译器自举版本已使用纯 Uya 标准库

**成果**：
- 编译器可静态链接，零外部依赖
- 文件大小：1.3MB（含调试信息）
- 所有 399 测试通过

---

#### Sprint 5: --outlibc 功能（1 周）⭐⭐⭐ ✅ 已完成

**任务清单**：
- [x] **编译器选项**：
  - 新增 `--outlibc <path>` 命令行参数
  - 解析参数，设置输出路径
- [x] **代码生成逻辑**：
  - 生成 `libuya.h`（头文件）：
    - 零依赖类型定义（int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t, size_t, ssize_t）
    - syscall 内联函数（x86-64）
    - 所有导出函数声明（string/mem/stdio/stdlib/unistd 模块）
  - 生成 `libuya.c`（实现文件）：
    - `#include "libuya.h"`
    - 所有模块的函数实现
    - 按模块分段注释
- [x] **测试脚本**：
  - `tests/test_outlibc.sh`（生成 libuya.c/h、编译验证、freestanding 测试）

---

### 19.2 标准库模块清单（v0.6.0 重构计划）

**已完成（v0.3.0 - v0.5.9）**：

| 模块 | 状态 | 说明 |
|------|------|------|
| `std.syscall` | ✅ | 系统调用封装（Linux x86-64） |
| `std.string` | ✅ | 字符串操作 |
| `std.mem` | ✅ | 内存操作 |
| `std.crypto` | ✅ | 摘要 / MAC / 校验（BLAKE2b、BLAKE2s、SHA-256、HMAC-SHA256、MD5、CRC32） |
| `std.io.file` | ✅ | 文件 I/O |
| `libc.*` | ✅ | C 兼容层（string, stdio, stdlib, unistd） |
| `--outlibc` | ✅ | 生成独立 libc |

**v0.6.0 重构计划**：

| Sprint | 模块 | 说明 | 状态 |
|--------|------|------|------|
| 6 | `std.core.error` | 错误类型定义 | [ ] |
| 6 | `std.core.option` | Option<T> 类型 | [ ] |
| 6 | `std.core.traits` | Clone/Eq/Ord/Hash/Display | [ ] |
| 6 | `std.mem.allocator` | `IAllocator` + `MallocAllocator`（malloc）；HeapAllocator/mmap 等待扩展 ⭐ | [x] 部分 |
| 6 | `std.mem.arena` | `Arena` bump + **`IAllocator`**；测试 `test_mem_arena.uya` | [x] 部分 |
| 6 | `std.mem.fixed_buf` | FixedBufferAllocator | [ ] |
| 7 | `std.io.writer` | Writer 接口 | [ ] |
| 7 | `std.io.reader` | Reader 接口 | [ ] |
| 7 | `std.io.file` | File 实现（重构） | [ ] |
| 8 | `std.string` | 安全字符串操作（!T） | [ ] |
| 9 | `std.collections.vec` | Vec<T> 泛型容器 | [ ] |
| 9 | `std.collections.string_buf` | StringBuf | [x] |
| 10 | `std.sql` | `DB` / `Row` 包装 + `Driver` / `Conn` / `Stmt` / `Rows` / `Tx` 抽象；真实 SQLite/MySQL 驱动待补 | [x] 部分 |
| 10 | `libc.*` | 薄封装（调用 std） | [ ] |

**长期计划**：

- [ ] `std.fmt` - 格式化库（纯 Uya，使用 Display 接口）
- [ ] `std.collections.map` - HashMap<K, V> 泛型容器
- [ ] `std.bare_metal` - 裸机平台支持
- [ ] `std.builtin` - 编译器内置运行时
- [~] `std.cfg` / `std` 平台选择器 - 条件编译系统  
  - **当前接口**：`use std; std.cfg(std.host_os == .hos_linux, then, else)`（平台枚举变体见 `lib/std/platform.uya`，如 `hos_linux`、`tos_macos`、`ta_x86_64`）；平台值通过 `std.host_os` / `std.host_arch` / `std.target_os` / `std.target_arch` 暴露。  
  - **当前状态**：顶层 / 语句级 `std.cfg`、`HostOS` / `TargetArch` 等平台枚举、`src/main.uya` 中 Linux 宿主路径分支与 `dirent` 布局裁剪已落地。  
  - **Darwin**：`get_compiler_dir` 已接 `_NSGetExecutablePath` + `realpath`（`std.cfg(hos_macos)`，真机验收见 macOS 待办）。  
  - **设计文档**：[`docs/std_c_design.md`](./std_c_design.md) § `std.cfg` / `std` 平台选择器：条件编译（第一版）。
- [~] `std.async.*` - 异步标准库（`std.async` / `std.async_event` / `std.async_channel` / `std.async_scheduler` 已有最小实现，详见 `std_async_design.md`）

**详细实现方案**：
- 同步部分：参见 [`docs/std_c_design.md`](./docs/std_c_design.md)
- 异步部分：参见 [`docs/std_async_design.md`](./std_async_design.md)
- 核心类型设计：参见本文档 Sprint 6-10

---

## 20. @print/@println 内置函数（v0.3.0）

**设计目标**：提供类型安全、易用的输出功能，支持字符串插值，在不同运行环境下自动适配。

**目标时间**：Sprint 4（v0.3.0，1 周）

---

### 20.1 语法定义

```uya
@print(expr)    // 打印表达式（不换行）
@println(expr)  // 打印表达式并换行
```

**示例**：
```uya
@println("Hello, World!");           // 字符串
@println(42);                        // i32
@println(3.14);                      // f64
@println(true);                      // bool
@println("x=${x}, y=${y}");          // 字符串插值
```

---

### 20.2 支持的类型

| 类型 | 格式说明符 | 示例 |
|------|-----------|------|
| i32 | `%d` | `@println(42)` → `"42\n"` |
| i64 | `%lld` | `@println(42 as i64)` → `"42\n"` |
| u32 | `%u` | `@println(42 as u32)` → `"42\n"` |
| u64 | `%llu` | `@println(42 as u64)` → `"42\n"` |
| usize | `%zu` | `@println(42 as usize)` → `"42\n"` |
| f32 | `%f` | `@println(3.14 as f32)` → `"3.140000\n"` |
| f64 | `%lf` | `@println(3.14)` → `"3.140000\n"` |
| bool | `"true"`/`"false"` | `@println(true)` → `"true\n"` |
| &[i8] | `%s` | `@println("hello")` → `"hello\n"` |
| [i8: N] | `%s` | `@println(buf)` → `"...\n"` |
| *byte | `%s` | `@println(ptr)` → `"...\n"` |

---

### 20.3 实施任务清单

#### Sprint 4: @print/@println 实现（1 周）⭐⭐⭐⭐

**阶段 1：编译器实现（3-4 天）**

- [x] **Lexer**：
  - 识别 `@print` 和 `@println`（添加到 `is_builtin_function`）
  - 添加到合法内置函数列表

- [x] **AST**：
  - 新增 `AST_PRINT` 节点
  - 新增 `AST_PRINTLN` 节点
  - 字段：`print_expr`（要打印的表达式）

- [x] **Parser**：
  - 解析 `@print(expr)` 语法
  - 解析 `@println(expr)` 语法
  - 验证参数个数（恰好 1 个）

- [x] **Checker**：
  - 类型检查：验证表达式类型可打印
  - 支持的类型：i8/i16/i32/i64/u8/u16/u32/u64/usize/f32/f64/bool/字符串
  - 不支持的类型报错（如结构体、联合体）

- [x] **Codegen - Hosted 模式**（默认）：
  - 生成 `printf` 调用
  - 根据表达式类型选择格式说明符
  - 返回 i32 类型（printf 返回值）

- [ ] **Codegen - Freestanding 模式**（`--freestanding`）：（待实现）
  - 生成 `std.c.stdio.putchar` 循环
  - 对于字符串：逐字符调用 putchar
  - 对于整数：转换为字符串再逐字符输出
  - 对于浮点数：格式化为字符串再输出

- [ ] **编译器选项**：（待实现）
  - 实现 `--hosted`（默认，使用 printf）
  - 实现 `--freestanding`（使用 std.c.stdio.putchar）
  - 实现 `--no-io`（禁用 @print/@println，编译时报错）

**阶段 2：字符串插值集成（已完成）**

- [x] **字符串插值支持**：
  - 支持 `@println("x=${x}, y=${y}")` 语法
  - 支持格式说明符：`${num:#x}`、`${f:.2f}` 等
  @println("x=${x}, y=${y}")
  
  // 生成的 C 代码（Freestanding）
  {
      uya_puts("x=");         // std.c.stdio.puts
      uya_print_i32(x);       // 整数转字符串
      uya_puts(", y=");
      uya_print_i32(y);
      uya_putchar('\n');
  }
  ```

**阶段 3：测试用例（已完成）**

- [x] **基础测试**：
  - `test_print_basic.uya`（基本打印，不换行）
  - `test_println_basic.uya`（基本打印，换行）

- [x] **类型测试**：
  - i32/i64/u32/u64/usize/f32/f64/bool 类型均已测试
  - 字符串类型已测试

- [x] **字符串插值测试**：
  - `test_print_interp.uya`（字符串插值，含格式说明符）

- [ ] **模式测试**：（Freestanding 模式待实现）
  - `test_print_hosted.uya`（Hosted 模式，使用 printf）
  - `test_print_freestanding.uya`（Freestanding 模式，使用 putchar）

- [x] **错误测试**：
  - `error_print_no_arg.uya`（无参数，预期失败）
  - `error_println_no_arg.uya`（无参数，预期失败）
  - `error_print_unsupported_type.uya`（不支持的类型，预期失败）

**阶段 4：文档与集成（已完成）**

- [x] **内置函数文档更新**：`docs/builtin_functions.md`
  - 添加 @print/@println 详细说明
  - 更新内置函数总览表

- [x] **使用指南更新**：`docs/usage_guide.md`
  - 添加调试输出章节

- [x] **变更日志更新**：`docs/changelog.md`
  - 添加 v0.5.7 版本记录

- [x] **uya-src 同步**：
  - 同步所有编译器修改到 uya-src
  - 测试 `--uya --c99` 模式通过（399 个测试）

---

### 20.4 技术要点

#### 1. 类型推断与格式选择

```c
// Checker 阶段：推断表达式类型
Type *expr_type = checker_infer_type(checker, expr);

// Codegen 阶段：根据类型选择格式
const char *fmt = NULL;
switch (expr_type->kind) {
    case TYPE_I32:   fmt = "%d"; break;
    case TYPE_I64:   fmt = "%lld"; break;
    case TYPE_U32:   fmt = "%u"; break;
    case TYPE_F32:   fmt = "%f"; break;
    case TYPE_F64:   fmt = "%lf"; break;
    case TYPE_BOOL:  fmt = "%s"; break;  // 特殊处理
    // ...
}
```

#### 2. Bool 类型特殊处理

```c
// Codegen for bool
if (expr_type->kind == TYPE_BOOL) {
    fprintf(out, "printf(\"%%s\\n\", ");
    c99_codegen_expr(codegen, expr);
    fprintf(out, " ? \"true\" : \"false\")");
} else {
    fprintf(out, "printf(\"%s\\n\", ", fmt);
    c99_codegen_expr(codegen, expr);
    fprintf(out, ")");
}
```

#### 3. Freestanding 模式整数转字符串

需要实现辅助函数（在 std.c.stdio 或生成代码中）：

```c
// 生成的辅助函数
static int uya_i32_to_str(int32_t value, char *buf) {
    int len = 0;
    int is_neg = 0;
    
    if (value < 0) {
        is_neg = 1;
        value = -value;
    }
    
    // 转换为字符串（逆序）
    do {
        buf[len++] = '0' + (value % 10);
        value /= 10;
    } while (value > 0);
    
    if (is_neg) buf[len++] = '-';
    
    // 反转字符串
    for (int i = 0; i < len/2; i++) {
        char tmp = buf[i];
        buf[i] = buf[len-1-i];
        buf[len-1-i] = tmp;
    }
    
    return len;
}
```

#### 4. 编译器选项实现

```c
// src/main.c
typedef enum {
    OUTPUT_MODE_HOSTED,       // 使用 printf（默认）
    OUTPUT_MODE_FREESTANDING, // 使用 std.c.stdio
    OUTPUT_MODE_NO_IO         // 禁用 I/O
} OutputMode;

CompilerOptions opts = {
    .output_mode = OUTPUT_MODE_HOSTED,  // 默认
    // ...
};

// 解析命令行
if (strcmp(argv[i], "--hosted") == 0) {
    opts.output_mode = OUTPUT_MODE_HOSTED;
} else if (strcmp(argv[i], "--freestanding") == 0) {
    opts.output_mode = OUTPUT_MODE_FREESTANDING;
} else if (strcmp(argv[i], "--no-io") == 0) {
    opts.output_mode = OUTPUT_MODE_NO_IO;
}
```

---

### 20.5 依赖关系

| 功能 | 依赖 | 优先级 |
|------|------|--------|
| @print/@println 基础 | 无 | ⭐⭐⭐⭐⭐ |
| Hosted 模式 | printf（glibc） | ⭐⭐⭐⭐⭐ |
| Freestanding 模式 | std.c.stdio | ⭐⭐⭐⭐ |
| 字符串插值集成 | 现有字符串插值（已实现） | ⭐⭐⭐⭐ |

**建议实施顺序**：
1. 先实现 Hosted 模式（依赖 printf，简单快速）
2. 再实现 Freestanding 模式（依赖 std.c.stdio，需要 Sprint 3 完成）
3. 最后集成字符串插值

---

### 20.6 测试验证

```bash
# 测试 Hosted 模式（默认）
./compiler-mini --c99 test_println_basic.uya
gcc test_println_basic.c -o test && ./test
# 输出：Hello, World!

# 测试 Freestanding 模式
./compiler-mini --c99 --freestanding test_println_basic.uya
gcc -nostdlib test_println_basic.c std/c/syscall.c std/c/stdio.c -o test && ./test
# 输出：Hello, World!

# 测试字符串插值
./compiler-mini --c99 test_print_interp.uya
gcc test_print_interp.c -o test && ./test
# 输出：x=42, y=3.14
```

---

**实现优先级**：⭐⭐⭐⭐（高优先级，配合标准库，提升易用性）

**实现状态**：[x] 已完成（v0.5.7，Hosted 模式，Freestanding 模式待实现）

---

## 21. 结构体默认值语法（规范 uya.md §4.3，0.40 新增）

**设计目标**：减少样板代码，允许在结构体定义中为字段指定编译期常量默认值；初始化时可省略有默认值的字段。

**语法**：
```uya
struct Config {
    port: i32 = 8080,         // 编译期常量默认值
    debug: bool = false,
    name: [i8: 64] = []       // 零初始化
}
const cfg = Config{};              // 全部使用默认值
const cfg2 = Config{ port: 3000 }; // 仅覆盖 port
```

**约束**：
- 默认值必须是编译期常量（字面量、const 变量、常量算术）
- 无默认值的字段在初始化时必须显式提供
- 联合体字段不能有默认值
- 切片字段 `&[T]` 不能有默认值

**编译器实现**（✅ 已完成，v0.2.31）：

- [x] **Lexer**：无需修改（使用现有 `=` token）
- [x] **AST**：结构体字段节点增加 `default_value` 可选表达式
- [x] **Parser**：解析 `field_name: Type = const_expr`
  - 扩展 BNF：`field_decl ::= field_name ":" type ( "=" const_expr )?`
- [x] **Checker**：
  - [x] 默认值类型检查（默认值类型 vs 字段类型）
  - [x] 编译期常量求值验证
  - [x] 初始化完整性检查（无默认值字段必须提供）
  - [x] 联合体/切片字段默认值禁止
- [x] **Codegen**：
  - [x] 初始化时缺失字段插入默认值
  - [x] `Struct{}` 全默认值展开
- [x] **uya-src 同步**（已完成）

**测试用例**（已完成）：
- [x] `test_struct_default.uya` - 基础默认值（80 行，通过 `--c99` 和 `--uya --c99`）

**参考文档**：
- [uya.md](uya.md) §4.3 - 结构体默认值语法
- [RELEASE_v0.2.31.md](releases/RELEASE_v0.2.31.md) - v0.2.31 版本说明

**实现状态**：✅ 已完成（v0.2.31，C 实现与 uya-src 已同步，所有测试通过）

---

## 22. 类型别名（type，规范 uya.md §5.2、§24.6.2、§29.5）

**设计目标**：使用 `type` 关键字为类型定义别名，简化复杂类型的使用。

**语法**：
```uya
type Int = i32;                              // 基础类型别名
type IntPtr = &i32;                          // 指针类型别名
type Buffer = [u8: 1024];                    // 数组类型别名
type Position = Point;                       // 结构体类型别名
```

**编译器实现**（✅ 已完成，v0.2.31）：

- [x] **Lexer**：`type` 关键字 token
- [x] **AST**：`AST_TYPE_ALIAS` 节点（名称 + 目标类型）
- [x] **Parser**：解析 `type Identifier = type_expr ;`
- [x] **Checker**：
  - [x] 类型别名解析（别名 → 实际类型）
  - [x] 循环别名检测
  - [x] 别名在类型位置的透明替换
- [x] **Codegen**：
  - [x] C99 映射为 `typedef`
- [x] **uya-src 同步**（已完成）

**测试用例**（已完成）：
- [x] `test_type_alias.uya` - 基础类型别名（170 行，通过 `--c99` 和 `--uya --c99`）

**参考文档**：
- [uya.md](uya.md) §5.2 - 函数指针与类型别名
- [uya.md](uya.md) §24.6.2 - 类型别名实现
- [uya.md](uya.md) §29.5 - 已实现特性列表
- [RELEASE_v0.2.31.md](releases/RELEASE_v0.2.31.md) - v0.2.31 版本说明

**实现状态**：✅ 已完成（v0.2.31，C 实现与 uya-src 已同步，所有测试通过）

---

## 23. 多维数组（规范 uya.md §2、§4）

**设计目标**：支持多维数组类型 `[[T: N]: M]`，按行优先顺序存储，编译期边界检查。

**语法**：
```uya
// 二维数组声明
const matrix: [[i32: 4]: 3] = [[1,2,3,4], [5,6,7,8], [9,10,11,12]];
// 访问
const val: i32 = matrix[1][2];  // 第1行第2列 → 7
// 零初始化
var buf: [[f32: 4]: 4] = [[], [], [], []];
// 结构体字段
struct Matrix { data: [[f32: 4]: 4] }
```

**内存布局**：
- 行优先顺序（row-major order）
- 大小 = `M * N * sizeof(T)`
- 对齐 = `alignof(T)`
- 三维及更高维以此类推：`[[[T: N]: M]: K]`

**编译器实现**：

- [x] **Lexer**：无需修改（使用现有 `[` `]` `:` token）
- [x] **AST**：类型节点支持嵌套数组维度
- [x] **Parser**：解析嵌套 `[[ ... ]: M]` 类型语法
- [x] **Checker**：
  - [x] 多维数组类型构建
  - [x] 多维索引 `arr[i][j]` 类型推断（每级下标返回内层类型）
  - [x] 所有维度边界检查
  - [x] 多维数组字面量类型检查
- [x] **Codegen**：
  - [x] C99 映射为嵌套 C 数组 `T arr[M][N]`
  - [x] 多维索引生成 `arr[i][j]`
  - [x] 零初始化生成
- [x] **uya-src 同步**

**测试用例**：
- [x] `test_multidimensional_array.uya` - 综合测试（二维/三维数组、@size_of/@len/@align_of、循环遍历、函数参数）

**参考文档**：
- [uya.md](uya.md) §2 - 类型系统（`[[T: N]: M]`）
- [uya.md](uya.md) §4.2.3 - 数组字段布局
- [examples/mat3x4.uya](../examples/mat3x4.uya) - 多维数组示例

---

## 24. 块注释（规范 uya.md §1）

**设计目标**：支持 `/* ... */` 块注释，允许嵌套。

**语法**：
```uya
/* 单行块注释 */
/*
    多行块注释
    /* 嵌套块注释 */
    继续外层注释
*/
```

**编译器实现**：

- [x] **Lexer**（C 实现与 uya-src 已同步）：
  - [x] 识别 `/*` 开始块注释
  - [x] 维护嵌套深度计数器
  - [x] 匹配 `*/` 时递减计数器，计数器归零时结束
  - [x] 未闭合块注释报错（设置 `lexer.has_error`，导致编译失败）
- [x] **uya-src 同步**

**测试用例**：
- [x] `test_block_comment.uya` - 基础块注释和嵌套块注释
- [x] `error_block_comment_unclosed.uya` - 未闭合块注释（预期编译失败）

**参考文档**：
- [uya.md](uya.md) §1 - 词法约定（`/* 块 */`（可嵌套））

---

## 25. 内存安全证明（规范 uya.md §14）

**设计目标**：通过编译期证明消除所有未定义行为（UB）。证明范围仅限当前函数内，证明失败则报编译错误并给出修改建议。

**内存安全强制表**：

| UB 场景 | 编译期要求 | 失败处理 |
|---------|-----------|---------|
| 数组越界 | 常量越界 → 编译错误；变量 → 证明 `i >= 0 && i < len` | 证明失败 → 编译错误并给出修改建议 |
| 空指针解引用 | 证明 `ptr != null` 或前序有空检查 | 证明失败 → 编译错误并给出修改建议 |
| 未初始化使用 | 证明首次使用前已赋值 | 证明失败 → 编译错误并给出修改建议 |
| 整数溢出 | 常量溢出 → 编译错误；变量 → 编译器证明或显式检查 | 证明失败 → 编译错误并给出修改建议 |
| 除零 | 常量除零 → 编译错误；变量 → 证明 `y != 0` | 证明失败 → 编译错误并给出修改建议 |

**证明机制分层**：
1. **常量折叠**：编译期常量直接检查
2. **路径敏感分析**：跟踪代码路径，建立约束条件
3. **符号执行**：复杂场景建立约束系统验证
4. **函数返回值**：调用者必须显式处理（编译器不跨函数证明）
5. **证明失败处理**：报编译错误并给出友好的修改建议

**编译器实现**：

- [x] **Checker**：
  - [x] 常量折叠（溢出/越界/除零检测）
  - [x] 路径敏感分析框架（约束系统：constraint_add, constraint_verify_bounds）
  - [x] 符号执行引擎（LinearExpr, extract_linear_expr, verify_linear_expr_bounds）
  - [x] 区间分析（Interval, verify_expr_bounds_interval）
  - [x] 证明失败处理（报编译错误并给出建议）
  - [x] 未初始化使用检测（is_initialized 字段）
  - [x] 空指针解引用检测（pointer_nullable_add, pointer_is_known_nonnull）
  - [x] 证明超时机制（proof_step_limit, proof_step_count）
  - [x] 约束系统增强（v0.49）：
    - [x] 交换律支持：`10 > i` → `i < 10`
    - [x] 线性表达式支持：`i + offset < n` → `i < n - offset`
    - [x] const 变量识别：`const N = 10; if i < N { ... }`
    - [x] 错误去重：同一 `(变量名, 数组大小)` 只报告一次
- [x] **测试验证**：
  - [x] error_null_deref.uya - 空指针解引用检测
  - [x] error_uninitialized_var.uya - 未初始化变量检测
  - [x] test_array_bounds.uya - 数组边界测试
  - [x] test_null_comprehensive.uya - null 处理测试
  - [x] test_array_bounds.uya 新增测试（v0.49）：
    - [x] test_swapped_comparison - 交换律测试
    - [x] test_linear_expr - 线性表达式测试
    - [x] test_else_branch - else 分支约束测试
    - [x] test_const_bounds - const 变量边界测试
    - [x] test_multi_access - 多次访问合并证明测试
- [x] **Codegen**：不需要实现
  - Uya 编译期证明失败直接报错，不生成运行时检查，无冗余检查需消除
- [ ] **uya-src 同步**

**测试用例**：
- [x] `test_path_bounds.uya` - 路径敏感边界证明
- [x] `error_bounds_need_proof.uya` - 证明失败报错
- [ ] `test_safety_overflow.uya` - 整数溢出证明
- [ ] `test_safety_null.uya` - 空指针证明
- [ ] `test_safety_uninit.uya` - 未初始化检测

**参考文档**：
- [uya.md](uya.md) §14 - 内存安全

**实现优先级**：高（核心语言安全特性）

---

## 26. 并发安全（规范 uya.md §15）

**设计目标**：通过 `atomic T` + 自动原子指令实现零数据竞争、零运行时锁。

**机制**：
- `atomic T` 语言层原子类型
- 读/写/复合赋值自动生成原子指令
- 所有原子操作自动序列化（零数据竞争）
- 无运行时锁，直接硬件原子指令

**依赖**：原子类型（已实现，Section 11）

**编译器实现**：

- [x] **原子类型基础**：`atomic T`、`&atomic T` 类型、原子操作（已完成）
- [ ] **Send/Sync 推导**：编译期推导类型是否满足 Send/Sync 约束
- [ ] **跨线程验证**：编译期验证跨线程使用的安全性
- [ ] **uya-src 同步**（Send/Sync 部分）

**说明**：原子类型基础已在 Section 11 中实现（C 实现与 uya-src 已同步）。此 Section 关注更高层次的并发安全保证（Send/Sync 编译期推导），需要在异步编程和线程支持实现后进行。

**参考文档**：
- [uya.md](uya.md) §15 - 并发安全

**实现优先级**：中（依赖异步编程和线程支持）

---

## 27. 接口组合（规范 uya.md §29.3）

**设计目标**：接口可以组合其他接口的方法，实现接口继承。

**语法**：
```uya
interface IReader {
    fn read(self: &Self, buf: &[byte]) !usize;
}

interface IWriter {
    fn write(self: &Self, data: &[byte]) !usize;
}

// 接口组合：IReadWriter 包含 IReader + IWriter 的所有方法
interface IReadWriter {
    IReader;     // 组合 IReader 的方法
    IWriter;     // 组合 IWriter 的方法
    fn flush(self: &Self) !void;  // 额外方法
}
```

**编译器实现**：

- [x] **AST**：接口声明新增 `composed_interfaces` 和 `composed_count` 字段
- [x] **Parser**：解析接口体中的接口名引用（`IReader;`）
- [x] **Checker**：
  - [x] `find_interface_method_sig` 递归查找组合接口的方法签名
  - [x] 验证实现结构体提供所有组合接口的方法
  - [x] `check_interface_compose_cycle` 循环依赖检测
- [x] **Codegen**：
  - [x] `collect_interface_method_sigs` 收集组合接口的所有方法
  - [x] 组合接口 vtable 包含所有被组合接口的方法
- [x] **uya-src 同步**

**测试用例**：
- [x] `test_interface_compose.uya` - 基础接口组合
- [x] `error_interface_compose_missing.uya` - 未实现组合接口的方法（预期编译失败）
- [x] `error_interface_compose_cycle.uya` - 循环依赖检测（预期编译失败）

**参考文档**：
- [uya.md](uya.md) §29.3 - 接口组合
- [examples/file_6.uya](../examples/file_6.uya) - 接口组合示例

**实现状态**：✅ 已完成（v0.2.30）

---

## 当前进度总结（截至 v0.2.31）

### 已完成的主要特性（28 项中已完成 25 项）

**核心语言特性（15/15 完成）**：
- ✅ 基础类型与字面量（i8-i64, u8-u64, 元组, @max/@min）
- ✅ 错误处理（!T, try/catch, error 定义）
- ✅ defer / errdefer（作用域 LIFO 清理）
- ✅ 切片（&[T], &[T: N]）
- ✅ match 表达式（模式匹配）
- ✅ for 扩展（整数范围、迭代器）
- ✅ 接口（interface, struct : I, 接口组合）
- ✅ 结构体方法 + drop + 移动语义
- ✅ 模块系统（目录即模块、export/use、循环依赖检测）
- ✅ 字符串插值（多段、格式说明符）
- ✅ 原子类型（atomic T）
- ✅ 运算符与安全（饱和运算、包装运算、as!）
- ✅ 联合体（union、extern union、方法）
- ✅ 泛型（Generics，类型推断、约束检查）
- ✅ 宏系统（Macro，@mc_eval、@mc_code、@mc_ast、${}插值）

**辅助特性（7/7 完成）**：
- ✅ test 关键字（测试单元）
- ✅ 类型别名（type 关键字）
- ✅ 结构体默认值语法
- ✅ 多维数组（[[T: N]: M]）
- ✅ 块注释（/* */ 可嵌套）
- ✅ 接口组合（IReadWriter : IReader + IWriter）
- ✅ 源代码位置内置函数（@src_name/@src_path/@src_line/@src_col/@func_name）

**开发质量（2/2 完成）**：
- ✅ 消灭所有警告（编译器代码与生成代码）
- ✅ 完整自举（C 实现与 uya-src 完全同步，560 个测试任务全部通过）

### 部分完成的特性（1 项）

- ✅ **异步编程**（`Future<!T>` 主路径 + `!Future<T>` 兼容路径、单/多 `@await` 状态机与 `std.async` 核心闭环已完成；跨线程 wake/eventfd、泛型 `TaskQueue<T>`、协作式取消语义已收口；后续 P2 主要剩跨平台后端与更完整 async I/O 扩展）

### 待实现的核心特性（3 项）

**高优先级（关键基础设施）**：
1. **标准库基础设施（std）**
   - 纯 Uya 实现的 C 标准库（零外部依赖）
   - `@syscall` 内置函数
   - std.c.{string, stdio, stdlib, syscall}
   - std.io / std.fmt 抽象层
   - `--outlibc` 生成单文件 libc

2. **@print/@println 内置函数**
   - 配合标准库实现
   - Hosted / Freestanding 模式支持
   - 类型安全格式化输出

**中优先级（安全保证）**：
3. ~~**内存安全证明（规范 §14）**~~ ✅ **v0.48 已完成**
   - 已实现：编译期证明（数组越界、空指针、未初始化、溢出、除零）
   - 已实现：证明失败报编译错误并给出修改建议
   - 已实现：路径敏感分析与符号执行

**低优先级（依赖其他特性）**：
4. **并发安全（规范 §15）**
   - Send/Sync 推导（依赖异步编程）
   - 跨线程验证

---

## 下一步优先计划（v0.2.32 及以后）

### 短期计划（v0.2.32 - v0.3.0）

#### 1. 标准库基础设施（最高优先级）⭐⭐⭐⭐⭐

**目标**：实现完全独立的标准库，编译器零外部依赖

**实施路线**：
- **阶段 0**：`@syscall` 内置函数（Linux x86-64 系统调用）
- **阶段 1**：`std.c.syscall` 模块（read/write/open/close/exit 等）
- **阶段 2**：`std.c.string` 模块（memcpy/memset/strlen/strcmp）
- **阶段 3**：`std.c.stdio` 模块（putchar/puts，基于 syscall）
- **阶段 4**：`std.io` 抽象层（Writer/Reader 接口）
- **阶段 5**：`std.fmt` 格式化库（纯 Uya 实现）

**验证标准**：
- 编译器使用 `-nostdlib` 构建成功
- 生成的代码零 glibc 依赖

**详细设计**：见 [`docs/std_c_design.md`](./docs/std_c_design.md)

#### 2. @print/@println 内置函数（高优先级）⭐⭐⭐⭐

**目标**：提供易用的格式化输出，配合标准库

**功能**：
- `@print(expr)` / `@println(expr)`
- 支持所有基础类型（i32/i64/f32/f64/bool/字符串）
- 集成字符串插值（`@println("x=${x}")`）
- Hosted 模式（printf）/ Freestanding 模式（uya_putchar）

**依赖**：标准库基础设施

#### 3. 优化与完善（持续进行）⭐⭐⭐

- [x] **证明优化 Codegen 完善**：在 `src/codegen/c99/stmt.uya` 的 `gen_if_stmt` 中利用 `is_proved_safe`，当 if 条件恒为真时直接生成 then 分支（移除 if 包装），不保留条件；optimizer 已扩展支持 AST_BOOL/常量表达式，codegen 已完善
- [x] **优化器递归 test 体**：在 `src/checker/optimizer.uya` 中为 `dead_code_elimination_pass` 和 `proof_optimization_pass` 添加 `AST_TEST_STMT` 递归
- [x] **C99 顶层函数可达性裁剪**：在 `src/codegen/c99/main.uya` 中为顶层函数代码生成增加可达性收集与发射过滤，不再把未使用的 `fn` / `export fn` 无条件输出到生成的 C 文件；同时保留 `export extern`，并补充 `tests/test_function_reachability_codegen.uya` 与 `tests/verify_function_reachability_codegen.sh` 回归验证
- 修复泛型接口中的 const 限定符警告
- 完善错误信息提示
- 性能优化（编译速度、生成代码质量）
- 文档完善（教程、示例、API 文档）

### 中期计划（v0.3.x）

#### 1. ~~内存安全证明（核心安全特性）~~ ✅ **v0.48 已完成**

**目标**：编译期消除所有 UB（已完成）

**已实施**：
- [x] 常量折叠（溢出/越界/除零检测）
- [x] 路径敏感分析框架（约束系统）
- [x] 符号执行引擎（LinearExpr, 区间分析）
- [x] 证明失败处理（报编译错误并给出建议）
- [x] 空指针解引用检测
- [x] 未初始化变量检测
- [x] 证明超时机制

**测试验证**：
- [x] error_null_deref.uya
- [x] error_uninitialized_var.uya
- [x] test_array_bounds.uya

**详细方案**：见待办文档 §25

#### 2. 异步编程完善（运行时支持）⭐⭐⭐⭐

**目标**：补完编译期验证与完整运行时，收敛当前最小闭环实现

**当前已完成**：
- 单/多 `@await` 状态机、`Poll/Future/Waker` 基础类型
- `std.async`、`std.async_event`、`std.async_channel`、`std.async_scheduler` 最小闭环（含 `Waker` 最小状态语义）
- `block_on`、基础错误传播、`async_copy` 等端到端验证

**后续路线**：
- 状态机大小编译期计算与递归/间接递归分析
- `Scheduler` 从当前“单任务 + 双任务/固定容量任务队列共享 EventLoop + register/poll/deregister + wake 重试”推进到完整 `EventLoop` / `Waker` 调度，并扩展到通用泛型任务队列
- 为 `Channel` / `MpscChannel<T>` 增补更完整的唤醒策略、阻塞语义与跨线程约束，并补齐 `std.thread` / `ThreadPool`
- 补齐泛型 `drop` 与泛型清理方法跨模块单态化，让 `RingQueue<T>` / `MpscChannel<T>` 回到自动 RAII，而不是依赖显式 `deinit()`
- Send/Sync 推导与跨线程验证

**依赖**：标准库基础设施（syscall）

**详细设计**：见 [`docs/std_async_design.md`](./std_async_design.md)

### 长期计划（v0.4.x+）

#### 1. 并发安全（v0.4.0）⭐⭐⭐

- Send/Sync 自动推导
- 跨线程安全验证
- std.thread 模块

#### 2. 标准库完善（v0.4.x）⭐⭐⭐

- std.collections（Vec、HashMap、BTreeMap）
- std.net（TCP/UDP 网络）
- std.fs（文件系统）
- std.time（时间处理）

#### 3. 跨平台支持（v0.5.x）⭐⭐

- 多平台共享基础（工具链/host/target/codegen 宏；**Linux 可完成项已同步** [todo_platform_shared_foundation.md](todo_platform_shared_foundation.md)）
- Darwin/macOS 支持（hosted 构建、自举、`@syscall`、`syscall/osal`、`pthread`、`--nostdlib`、`std.async`/`kqueue`），纳入 [todo_multiplatform_migration.md](todo_multiplatform_migration.md)
- Windows 支持（IOCP、Win32 API）
- ARM64 支持
- RISC-V 支持（裸机）

#### 4. SIMD 语言内建与 lowering（v0.6.x+）⭐

**目标**：将 `@vector(T, N)` / `@mask(N)` 正式纳入语言内建，先落最小语义与前端支持，再逐步接入真实 SIMD lowering。

**第一阶段目标**：
- `@vector(T, N)` / `@mask(N)` 进入 `docs/uya.md` 与 `docs/grammar_formal.md`（✅ 已写入）
- Parser / Checker / C99 Codegen 支持最小语义（✅ 值级运算 + `@vector.splat` / `any` / `all` + C99 标量回退）
- 第一阶段仅保证语义正确，允许标量回退 lowering（✅ 当前实现）

**实施路线**：
- **阶段 1**：规范定稿（✅）
  - `docs/uya.md`：增加 SIMD 规范正文
  - `docs/grammar_formal.md`：增加 `vector_type` / `mask_type` / `vector_builtin_expr`
  - 锁定第一阶段边界：基础算术、整数位运算、比较、掩码逻辑、`@vector.splat` / `@vector.any` / `@vector.all`
- **阶段 2**：编译器最小落地（✅ 第一阶段语义）
  - `src/lexer.uya` / `src/ast.uya` / `src/parser/types.uya`
  - `src/checker/types.uya` / `type_from_ast.uya` / `check_expr_extra.uya`
  - `src/codegen/c99/*` 先做语义正确的标量回退
  - 测试：`test_simd_value_ops.uya`、`test_simd_unary_ops.uya`、`test_simd_div_f32_i32.uya`、`test_simd_f64_mul_div.uya`、`test_simd_vec2_i32_u32_f32.uya`（**2×** i32/u32/f32 快路径）、`test_simd_vec8_i32.uya`、`test_simd_vec8_sse_chain.uya`（8× 双 x4）、`test_simd_vec16_sse_chain.uya`（16× 四 x4）、`test_simd_vec32_sse_chain.uya`（32× 八 x4）、`test_simd_vec64_sse_chain.uya`（64× 十六 x4）、`test_simd_i16_add.uya`、`test_simd_u16_basic.uya`、`simd_c99_neon.uya`（NEON 交叉验证与并行套件共用）、`test_simd_mask_bitwise_shift.uya`、`test_simd_u32_basic.uya`、`test_simd_vector_mod_i32.uya`、`test_simd_vector_sat_wrap_i32.uya`、`test_simd_splat_binary_context.uya`、`test_simd_return_splat_binary.uya`（含 `catch`+`!Vec4i32` 载荷别名）、`test_simd_mask_inline_compare.uya`（不显式 `@mask` 类型）、`test_simd_sse_lower_i32x4.uya`（x86_64 SSE lowering / 标量 `#else`）、`test_simd_sse_compare_ops.uya`（向量六种比较掩码）、`test_simd_fn_vector_return.uya`、`test_simd_struct_field_ops.uya`、`test_simd_splat_f32_suffix.uya`、`test_simd_splat_peer_infer.uya`、`syscall_c99_cross.uya`（`@syscall` 交叉验证；**macOS** 默认跳过并行）与 `error_simd_*.uya`（含 `error_simd_float_vector_mod.uya`、`error_simd_float_vector_plus_pipe.uya`、`error_simd_u32_vector_plus_pipe.uya`、`error_simd_float_vector_bitwise.uya`、`error_simd_float_vector_tilde.uya`、`error_simd_float_vector_shift.uya`、`error_simd_mask_logical_and.uya`、`error_simd_vector_mask_mix_and.uya`、`error_simd_vector_load_pointee_mismatch.uya`、`error_simd_vector_select_mask_lanes.uya`）与 `test_simd_vector_load.uya`、`test_simd_vector_select.uya`
- **阶段 3**：标准库性能试点（🔄）
  - 在 `std.json` **`parser.uya`**：**`skip_ws`**（**0.49.33**）、**`parse_string`** / **对象键**无转义连续段、**`parse_number`** 连续 ASCII 数字段（**`@vector(u8,16)`/`@mask(16)`** 块 + 标量收尾）；**可选**再扩或加 AVX2/NEON `@asm` 分支
  - 编译期继续复用 `std.cfg(...)` / `@asm_target()`
  - 运行时 CPU 能力检测放在库内普通函数，不新增新的条件编译或目标特性内建
- **阶段 4**：真实 SIMD lowering（🔄 已启动）
  - ✅ **初版**：C99 在 **x86_64 + SSE2**（`UYA_HAVE_SIMD_X86_SSE`）或 **ARM + NEON**（`UYA_HAVE_SIMD_ARM_NEON`，同名 `uya_simd_sse_*`）或 **`#else` 标量**下，对 **2× / 4× / 8× / 16× / 32× / 64×**`i32`/`u32`/`f32`（**2×** 为 **`*_x2`**，0.49.29；8=2×x4 … 64=16×x4）部分运算、**`i32` 向量 `/` `%`**（`uya_simd_sse_div_i32x4`/`x2`、`rem_*`，0.49.22–0.49.23、0.49.29）、**`u32` 向量 `* / %`**（`mul`/`div`/`rem` **x4/x2**）、**`i32`/`u32` 向量 `<<` `>>`**（**x4/x2**）、**`f64` 向量 `+` / `-` / `* /` / 一元 `-`**（**2×/4×**）、**`i16`/`u16`（4×/8×）**、**`i8`/`u8`（2/4/8/16/32/64）与 `i64`/`u64`（2 通道 `x2` 分块）**（0.49.30）等；见 `emit_simd_x86_sse_runtime_helpers`、`c99_simd_try_emit_x86_sse_*`、`c99_simd_sse_x4_tile_lane_count_ok`、`c99_simd_sse_i32_u32_f32_two_or_x4_lane_ok`、`scripts/gen_simd_i8_i64_helpers.py`；验证 `verify_simd_c99_neon.sh`
  - 待办：**`shuffle`**（**`@vector.load` / `@vector.store` / `@vector.select`**：✅ **0.49.33** / **0.49.34** / **0.49.35**；**`@vector.reduce_add`**：✅ **0.49.36**（C99 **`×2`/`×4` i32/u32/f32** 助手与收集作用域：**0.49.37**）；**`@vector.reduce_mul`**：✅ **0.49.38**（C99 **`i32`/`u32`/`f32` `×2`/`×4`** 助手；SSE2 `_mm_mul_*`，i32/u32 ×4 用 SSE4.1 `_mm_mullo_epi32`，无 SSE4.1 回退标量）；**`@vector.reduce_min`/`@vector.reduce_max`**：✅ **0.49.39**（全部标量 while 循环回退）；其余见 `uya.md`）；ABI（**NEON**：✅ 0.49.16；**多宽 x4 分块**：✅ 至 64；**`2×` i32/u32/f32**：✅ 0.49.29；**i8/u8/i64/u64 快路径**：✅ 0.49.30；其余同上 ✅）

**验证标准**：
- 开发前与每轮修改后都执行 `make check`
- 新增 `error_simd_*.uya` 与 `test_simd_*.uya`
- 所有新增测试必须同时通过 `--c99` 与 `--uya --c99`
- `std.json` SIMD 试点保留 benchmark，对比标量、`@vector` 与（可选）`@asm` 路径
- 提交前执行 `make clean && make backup`

**详细设计**：
- 规范正文：`docs/uya.md`
- 正式语法：`docs/grammar_formal.md`
- JSON 试点：[`docs/todo_json.md`](./todo_json.md)、[`docs/json_design.md`](./json_design.md)

#### 5. 编译器后端扩展（v0.6.x+）⭐

- LLVM IR 后端（优化与多架构）
- WebAssembly 后端
- GPU 计算支持

---

## 里程碑规划

### v0.2.31（✅ 已完成，2026-02-06）
- ✅ 源代码位置内置函数
- ✅ 类型别名（type 关键字）
- ✅ 结构体默认值语法
- ✅ 内置函数完整文档（972 行）

### v0.2.32（✅ 已完成，2026-02-06）
- ✅ 数字字面量增强
  - ✅ 十六进制字面量（`0xFF`、`0x1A2B`）
  - ✅ 八进制字面量（`0o755`、`0O644`）
  - ✅ 二进制字面量（`0b1010`、`0B1111_0000`）
  - ✅ 下划线分隔符（`1_000_000`、`3.141_592_653`）
  - ✅ 完整测试覆盖（test_number_literals.uya）
  - ✅ 规范文档更新（UYA_MINI_SPEC.md、uya.md、grammar_formal.md、grammar_quick.md）
- ✅ 修复系统调用相关测试
  - ✅ test_std_syscall.uya（syscall 函数封装）
  - ✅ test_syscall_module.uya（错误联合类型返回修复）
  - ✅ 修复 struct err_union_int64_t 重复定义问题
- ✅ 回归测试全部通过（317 个测试）

### v0.2.33（✅ 已完成，2026-02-06）
- ✅ 标准库 Sprint 1-3 完成
  - ✅ `lib/std/c/syscall/syscall.uya`（系统调用封装：33 个常量 + 13 个封装函数）
  - ✅ `lib/std/c/string/string.uya`（纯 Uya 实现：13 个内存/字符串函数）
  - ✅ `lib/std/c/stdio/stdio.uya`（基于 @syscall 的 I/O：12 个函数 + 整数转字符串）
  - ✅ `test_std_string.uya`（8 组测试，通过 `--c99` 和 `--uya --c99`）
  - ✅ `test_std_stdio.uya`（3 组测试，通过 `--c99` 和 `--uya --c99`）
  - ✅ `test_std_syscall.uya`（通过 `--c99` 和 `--uya --c99`）
- ✅ 标准库目录重构：`std/` → `lib/std/`（目录即模块：`lib/std/c/string/string.uya` → 模块路径 `std.c.string`）
  - ✅ 测试脚本 `run_programs.sh` 设置 `UYA_ROOT=../lib/`
  - ✅ Checker 添加 `uya_root_dir` 字段，优先在 UYA_ROOT 下查找模块文件
  - ✅ `build_module_exports` 修复：支持 `AST_VAR_DECL`（常量声明）导出
  - ✅ Codegen 修复：`return @syscall(...)` 在 `!i64` 函数中不再双重包装 err_union
  - ✅ 自举编译器修复：`project_root` 路径包含尾部斜杠、Dirent 结构体通过指针偏移访问 d_type/d_name
- ✅ 回归测试全部通过（319 个测试）
- ✅ 自举对比（`--c99 -b`）一致

### v0.5.4（✅ 已完成，2026-02-19）
- ✅ 代码质量改进
  - ✅ 替换魔法数字为命名常量（C99_MAX_ERROR_IDS、C99_GENERIC_NAME_BUF_SIZE 等）
  - ✅ 修复 stmt.uya 中的 bug（j2 = j + 1 → j2 = j2 + 1）
- ✅ 回归测试全部通过

### v0.5.5（✅ 已完成，2026-02-19）
- ✅ 编译选项优化
  - ✅ 移除 -fwrapv 编译标志（使用 gcc -std=c99 -O3 -fno-builtin）
- ✅ 内存安全验证
  - ✅ Valgrind 检查通过（0 errors，无内存泄漏）
  - ✅ 使用 --max-stackframe=10000000 解决大栈帧问题
- ✅ 文档更新
  - ✅ 版本说明（RELEASE_v0.5.5.md）
  - ✅ 使用指南（usage_guide.md）
  - ✅ 编译器状态报告（compiler_status.md）
- ✅ 回归测试全部通过（393 个测试）

### v0.3.0（✅ 已完成）- 标准库里程碑
- ✅ 标准库基础设施（Sprint 1-3：@syscall + std.c.{syscall,string,stdio}）
- ✅ @print/@println 内置函数（v0.5.7 已完成）
- ✅ 编译器零外部依赖（-nostdlib 构建，Sprint 4 已完成）
- ✅ --outlibc 生成独立 libc（Sprint 5 已完成）

### v0.4.0（目标：2026 Q2）- 异步里程碑
- ✅ 内存安全证明（v0.48 已完成：编译期证明+运行时检查可选）
- 🎯 异步编程完整运行时（基础状态机与最小运行时已完成，P2 扩展待做）
- 🎯 并发安全保证
- 🎯 标准库：collections + async

### v0.5.0（目标：2026 Q3-Q4）- 跨平台里程碑
- 🎯 macOS / Windows 支持
- 🎯 ARM64 / RISC-V 支持
- 🎯 标准库：net + fs + time
- 详细实施任务见 [todo_multiplatform_migration.md](todo_multiplatform_migration.md)

### v0.6.0（目标：2026 Q4+）- 低层能力里程碑
- 🎯 SIMD 语言内建：`@vector(T, N)` / `@mask(N)`
- 🎯 真实 SIMD lowering 与标量回退共存
- 🎯 编译器后端扩展（LLVM IR / WebAssembly）

### v1.0.0（目标：2027）- 生产就绪
- 🎯 语言规范完全实现
- 🎯 完整标准库
- 🎯 多平台支持
- 🎯 LLVM 后端
- 🎯 完整文档与教程

---

*文档版本：v0.5.13（2026-03-22），642 个测试任务全部通过，内存安全证明已完成；异步最小闭环已打通：`Future<!T>` 主路径、单/多 `@await` 状态机、`Poll/Future/Waker`、`std.async` / `std.async_event` / `std.async_channel` / `std.async_scheduler` 基础实现均已落地；`std.async` 已为 `i32` / `u32` / `usize` 提供 `poll_ready_ok_*` / `future_ready_ok_*` / `task_ready_ok_*` 导出；`std.thread` 已落地 **泛型 `AsyncComputeFuture<T>`**（整数/bool/**f32/f64** + typedef 别名）与 **唯一入口 `async_compute<T>`**（C99 单态由展开体生成），以及 **interface 装箱 / typedef 成员调用 / `ok<bool>` 单态** 修复（详见 `docs/todo_async_runtime_and_http.md` §P1.5）。*
