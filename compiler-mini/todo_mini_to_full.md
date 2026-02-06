# Uya Mini 到完整版待办文档

基于 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md) 第 9 节「与完整 Uya 的区别」与项目根目录 [uya.md](../uya.md) 完整规范对照。实现时按「建议实现顺序」执行，每项需同步更新 C 实现与 `uya-src/`，测试需同时通过 `--c99` 与 `--uya --c99`。

**实现约定**：在编写编译器代码前，先在 `tests/programs/` 添加测试用例（如 `test_xxx.uya` 或预期编译失败的 `error_xxx.uya`），覆盖目标场景；实现后再跑 `--c99` 与 `--uya --c99` 验证，二者都通过才算通过。

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
| 12 | 运算符与安全 | [x]（饱和/包装运算、as! 已实现；内存安全证明未实现） |
| 13 | 联合体（union） | [x]（C 实现与 uya-src 已同步） |
| 14 | 消灭所有警告 | [x]（主要工作已完成，剩余问题见下方说明） |
| 15 | 泛型（Generics） | [x]（C 实现与 uya-src 已同步，类型推断与约束检查完成） |
| 16 | 异步编程（Async） | [~]（语法解析完成：@async_fn/@await；CPS 变换/状态机生成待实现） |
| 17 | test 关键字（测试单元） | [x]（C 实现与 uya-src 已同步） |
| 18 | **宏系统（Macro）** | [x] C 实现与 uya-src 已同步 |
| 19 | **标准库基础设施（std）** | [ ] **重要** |
| 20 | **@print/@println 内置函数** | [ ] **配合标准库** |
| 21 | **结构体默认值语法** | [ ] 规范 §4.3（0.40 新增） |
| 22 | **类型别名（type）** | [ ] 规范 §5.2、§24.6.2 |
| 23 | **多维数组** | [x]（C 实现与 uya-src 已同步） |
| 24 | **块注释** | [x]（C 实现与 uya-src 已同步，支持嵌套） |
| 25 | **内存安全证明** | [ ] 规范 §14（编译期证明 + 运行时检查） |
| 26 | **并发安全** | [ ] 规范 §15（依赖原子类型） |
| 27 | **接口组合** | [x]（C 实现与 uya-src 已同步） |

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
- [x] **测试用例迁移**：将 `tests/programs/` 中所有用例从 `@sizeof`、`@alignof` 改为 `@size_of`、`@align_of`
- [x] **C 实现与 uya-src 同步**：`src/` 与 `uya-src/` 两套实现同步修改；`--c99` 与 `--uya --c99` 均通过，`--c99 -b` 自举对比一致

**涉及**：`lexer.c`/`lexer.uya`、`ast.c`/`ast.uya`、`parser.c`/`parser.uya`、`checker.c`/`checker.uya`、`codegen/c99/expr.c`/`expr.uya` 等；`tests/programs/*.uya` 中引用内置的用例。

**参考文档**：
- [changelog.md](../changelog.md) §0.40.1 - 内置函数命名统一
- [uya.md](../uya.md) §16 - 内置函数规范

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
- [x] **测试用例迁移**：将 `tests/programs/` 中所有用例改为 `@size_of`、`@align_of`、`@len`、`@max`、`@min`
- [x] **C 实现与 uya-src 同步**：`src/` 与 `uya-src/` 两套实现同步修改；`--c99` 与 `--uya --c99` 均通过，`--c99 -b` 自举对比一致

**涉及**：`lexer.c`/`lexer.uya`、`ast.c`/`ast.uya`、`parser.c`/`parser.uya`、`checker.c`/`checker.uya`、`codegen/c99/expr.c`/`expr.uya` 等；`tests/programs/*.uya` 中引用内置的用例。

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

**涉及**：AST、Parser、Checker、Codegen（vtable、装箱点、逃逸检查），uya-src。

**当前进度**：Lexer、AST、Parser、Checker 已完成。**C 实现 Codegen 已完成**：types.c 接口类型→struct uya_interface_I；structs.c 生成 interface/vtable 结构体与 vtable 常量（修复：预先生成接口方法签名中使用的错误联合类型结构体定义，避免 err_union_void 等结构体定义出现在 vtable 内部）；function.c 方法块生成 uya_S_m 函数；expr.c 接口方法调用（vtable 派发）、装箱（struct→interface 传参）；main.c 处理 AST_METHOD_BLOCK、emit_vtable_constants。test_interface.uya 通过 `--c99`。**uya-src 已同步**：lexer.uya（TOKEN_INTERFACE、interface 关键字）；ast.uya（AST_INTERFACE_DECL、AST_METHOD_BLOCK、struct_decl_interface_*、method_block_*）；parser.uya（parse_interface、parse_method_block、struct : I、顶层 IDENTIFIER+{）；checker.uya（TYPE_INTERFACE、find_interface_decl_from_program、find_method_block_for_struct、struct_implements_interface、type_equals/type_from_ast/check_expr_type、member_access 接口方法）；codegen types/structs/function/expr/main（接口类型、emit_interface_structs_and_vtables 修复：预先生成错误联合类型结构体定义、emit_vtable_constants、方法前向声明与定义、接口方法调用与装箱、c99_type_to_c_with_self）。自举编译 `./compile.sh --c99 -e` 成功；test_interface.uya 通过 `--uya --c99`。**修复**：parser.uya 在「字段访问和数组访问链」循环中补全了 `TOKEN_LEFT_PAREN` 分支，以解析 `obj.method(args)` 形式的方法调用（如 `a.add(10)`）；structs.c/structs.uya 修复 err_union_void 结构体定义在 vtable 内部的问题：添加 pregenerate_error_union_structs_for_interface 函数，在生成 vtable 之前预先生成所有接口方法签名中使用的错误联合类型结构体定义。自举对比 `--c99 -b` 仅有单行空行差异。

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
  **C 实现（已完成）**：`extract_module_path_allocated` 从文件路径提取模块路径，基于目录结构。目录下的所有 `.uya` 文件属于同一模块。当前支持单级目录模块（如 `module_a/` → `module_a`），多级路径（如 `std/io/` → `std.io`）待扩展。测试用例已调整为目录结构：`tests/programs/module_a/module_a.uya` 属于 `module_a` 模块。**测试验证通过**：所有测试用例已验证，包括基本模块导入、错误检测、单文件 export 测试等。
- [x] **export（语法解析与基本支持）**：`export fn/struct/interface/const/error`、`export extern`，规范 uya.md §1.5.3
  **C 实现（已完成）**：Lexer（TOKEN_EXPORT）、AST（所有声明节点添加 is_export 字段）、Parser（parser_parse_declaration 支持 export 前缀，所有解析函数设置 is_export）、Checker（基本检查，单文件场景下 export 标记记录但不影响可见性）、Codegen（跳过 use 语句，正常生成 export 标记的声明）。测试 test_module_export.uya 通过编译并运行（返回 42）。
- [x] **use（语法解析与基本支持）**：`use path;`、`use path.item;`、别名 `as`，无通配符，规范 uya.md §1.5.4
  **C 实现（已完成）**：Lexer（TOKEN_USE）、AST（AST_USE_STMT 节点，path_segments/item_name/alias 字段）、Parser（parser_parse_use_stmt 解析 use 语句，支持路径段、特定项、别名）、Checker（基本语法检查，单文件场景下 use 语句暂时不进行实际模块解析）、Codegen（跳过 use 语句，不生成代码）。语法解析和代码生成通过。
- [x] **模块可见性与路径解析（多文件）**：Checker 中处理 export 可见性、use 路径解析、模块查找（需要多文件支持）
  **C 实现（已完成）**：TypeChecker 中添加 ModuleTable 和 ImportTable；`build_module_exports` 遍历所有声明，根据文件路径提取模块路径，收集 export 标记的项；`process_use_stmt` 处理 use 语句，查找模块并验证导出项是否存在；`extract_module_path_allocated` 从文件路径提取模块路径（基于目录结构，如 `tests/programs/module_a/file.uya` → `module_a`）。**目录即模块**：支持目录即模块，目录下的所有 `.uya` 文件属于同一模块。**测试验证**：所有测试用例已验证通过，包括 `tests/programs/module_a/` 和 `tests/programs/module_test/`、`tests/programs/multifile/module_test/` 等。module_a 目录下的文件属于 `module_a` 模块，module_b.uya 使用 `use module_a.public_func;` 导入并调用，error_use_private.uya 正确检测到使用未导出项的错误。**编译警告已修复**：删除了未使用的变量和函数声明。
- [x] **循环依赖**：编译期检测并报错，规范 uya.md §1.5.7（需要多文件支持）
  **C 实现（已完成）**：在 `ModuleInfo` 中添加 `dependencies` 字段记录模块依赖；在 `process_use_stmt` 中记录当前模块对目标模块的依赖关系；添加 `detect_circular_dependencies` 函数使用 DFS 算法检测强连通分量（循环依赖）；在所有 use 语句处理完后调用循环检测。测试用例 `error_circular_dependency.uya` 正确检测到循环依赖并报错。
- [x] **多级模块路径**：支持多级路径（如 `std/io/` → `std.io`），当前仅支持单级目录模块（如 `module_a/` → `module_a`）
  **C 实现（已完成）**：修改 `extract_module_path_allocated` 提取从第一个目录到最后一个目录的所有目录名，用 `.` 连接（临时跳过 `tests/programs/` 前缀以匹配测试用例）；修改 `process_use_stmt` 支持多级路径解析，处理 parser 将 `use std.io.read_file;` 解析为 `path_segments = ["std", "io", "read_file"]` 的情况（最后一个 segment 作为项名）。测试用例 `test_multilevel_module.uya` 通过 `--c99`。
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
- [x] **测试程序验证**：确保所有测试程序（`tests/programs/*.uya`）编译生成的 C 代码无警告
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

**语法规范**（规范 0.40）：使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`。详见 [uya.md](../uya.md) §B.1 和 [grammar_formal.md](../grammar_formal.md)。

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
- [uya.md](../uya.md) §B.1 - 泛型语法说明
- [grammar_formal.md](../grammar_formal.md) - 正式BNF语法规范（已包含泛型BNF）
- [examples/example_143.uya](../examples/example_143.uya) - 泛型函数示例
- [examples/example_144.uya](../examples/example_144.uya) - 泛型结构体示例
- [examples/example_145.uya](../examples/example_145.uya) - 泛型接口示例
- [examples/example_147.uya](../examples/example_147.uya) - 泛型综合示例
- [examples/example_149.txt](../examples/example_149.txt) - 泛型约束说明（Ord、Clone、Default）

**实现优先级**：低（建议在原子类型、内存安全证明等核心特性实现后再考虑）

---

## 18. 宏系统（Macro，规范 uya.md §25）

**语法规范**：`mc ID(param_list) return_tag { statements }`，规范 [uya.md](../uya.md) §25。

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

### 18.6 验证 ✅
- [x] 运行 `cd uya-src && ./compile.sh --c99 -e` 编译自举编译器成功
- [x] 运行 `./tests/run_programs.sh --uya --c99 test_macro*.uya` 所有 27 个宏测试通过
- [x] 运行 `./compile.sh --c99 -b` 自举对比一致

**涉及**：Lexer、AST、Parser、Checker、Codegen。

---

## 16. 异步编程（Async）

**语法规范**（规范 0.40）：`@async_fn` 函数属性、`try @await` 挂起点、`union Poll<T>`、`interface Future<T>`。详见 [uya.md](../uya.md) §18。

**异步标准库设计**：详见 [`docs/std_async_design.md`](./docs/std_async_design.md)（`std.async.io`、`std.async.task`、`std.async.event`、`std.async.channel`、`std.async.scheduler`）。

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

- [x] **Lexer**：识别异步编程语法（C 实现与 uya-src 已同步）
  - [x] 识别 `@async_fn` 函数属性（`@` 后跟 `async_fn`）
  - [x] 识别 `@await` 关键字（`@` 后跟 `await`）
  - [x] 注意与现有 `@` 内置函数（`@size_of`、`@len` 等）的区分

- [x] **AST**：异步编程节点扩展（C 实现与 uya-src 已同步）
  - [x] 函数声明添加 `is_async` 字段（标记 `@async_fn`）
  - [x] `AST_AWAIT_EXPR` 节点：`@await expression`
  - [ ] 类型节点支持 `!Future<T>` 类型（需泛型接口支持）
  - [ ] 支持 `union Poll<T>` 类型定义和使用（需联合体泛型支持）

- [x] **Parser**：异步编程语法解析（C 实现与 uya-src 已同步）
  - [x] 解析 `@async_fn` 函数属性（函数声明前的属性）
  - [x] 解析 `@await expression` 表达式
  - [ ] 解析 `!Future<T>` 返回类型（需泛型接口支持）
  - [ ] 解析 `union Poll<T>` 类型定义（需联合体泛型支持）
  - [ ] 验证 `@await` 只能在 `@async_fn` 函数内使用

- [~] **Checker**：异步编程类型检查（基础实现，C 实现与 uya-src 已同步）
  - [ ] `@async_fn` 函数必须返回 `!Future<T>` 类型
  - [ ] `@await` 表达式操作数必须返回 `!Future<T>` 类型
  - [ ] `@await` 只能在 `@async_fn` 函数内使用
  - [x] `@await` 表达式基础类型推断（当前返回操作数类型）
  - [ ] `union Poll<T>` 类型检查（Pending/Ready/Error 变体）
  - [ ] `interface Future<T>` 接口定义和实现检查
  - [ ] 状态机大小编译期计算（递归调用检查）

- [ ] **CPS 变换（Continuation-Passing Style）**：状态机生成
  - [ ] 分析 `@async_fn` 函数体，识别所有 `@await` 点
  - [ ] 将函数体转换为状态机结构
  - [ ] 为每个 `@await` 点创建状态
  - [ ] 生成状态转换代码
  - [ ] 处理局部变量在状态间的保存和恢复
  - [ ] 计算状态机大小（编译期确定）

- [~] **Codegen**：异步编程代码生成（基础实现，C 实现与 uya-src 已同步）
  - [x] `@await` 表达式基础代码生成（当前生成同步调用）
  - [ ] 生成状态机结构体（包含状态、局部变量、continuation）
  - [ ] 生成状态机初始化代码
  - [ ] 生成状态转换代码（`@await` 点）
  - [ ] 生成 `poll()` 方法实现（状态机驱动）
  - [ ] 生成 `union Poll<T>` 结构体定义
  - [ ] 生成 `interface Future<T>` vtable
  - [ ] 处理错误传播（`!Future<T>` 中的错误联合）

- [ ] **标准类型定义**：核心异步类型
  - [ ] `union Poll<T>` 定义（Pending/Ready/Error 变体）
  - [ ] `interface Future<T>` 接口定义
  - [ ] `struct Waker` 定义（唤醒器）
  - [ ] 为内置类型提供异步支持

- [ ] **标准库实现**（基于核心类型，详见 [`docs/std_async_design.md`](./docs/std_async_design.md)）
  - [ ] `std.async.task` 模块：`Task<T>`, `Waker` 实现
  - [ ] `std.async.io` 模块：`AsyncWriter`, `AsyncReader`（非阻塞 I/O）
  - [ ] `std.async.event` 模块：`EventLoop`（epoll/kqueue/IOCP）
  - [ ] `std.async.channel` 模块：`Channel<T>`, `MpscChannel<T>`（依赖原子类型）
  - [ ] `std.async.scheduler` 模块：`Scheduler` 事件循环调度器
  - [ ] `std.thread` 模块：`ThreadPool`, `async_compute<T>`

- [ ] **编译期验证**：
  - [ ] 状态机大小编译期计算（递归调用报错）
  - [ ] Send/Sync 约束推导（跨线程安全性）
  - [ ] 状态机转换正确性验证
  - [ ] 唤醒安全性验证（Waker 使用）

- [ ] **测试用例**：
  - [ ] `test_async_fn_basic.uya` - 基本异步函数
  - [ ] `test_async_await.uya` - `try @await` 基本使用
  - [ ] `test_async_poll.uya` - `Poll<T>` 使用
  - [ ] `test_async_future.uya` - `Future<T>` 接口实现
  - [ ] `test_async_state_machine.uya` - 状态机生成验证
  - [ ] `test_async_error_propagation.uya` - 错误传播
  - [ ] `test_async_nested.uya` - 嵌套异步调用
  - [ ] `error_async_wrong_return.uya` - 返回类型错误
  - [ ] `error_await_outside_async.uya` - `try @await` 在非异步函数中使用
  - [ ] `error_async_recursive.uya` - 递归异步函数（应报错）

**涉及**：Lexer、AST、Parser、Checker、Codegen（CPS 变换、状态机生成），uya-src。

**参考文档**：
- [uya.md](../uya.md) §18 - 异步编程完整规范
- [grammar_formal.md](../grammar_formal.md) - 正式BNF语法规范（需添加异步编程BNF）
- [changelog.md](../changelog.md) §0.40.4 - 异步编程基础设施变更

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
- [x] **@src_name/@src_path/@src_line/@src_col/@func_name 内置函数**：源代码位置信息和函数名（v0.1.0 新增）
  - [x] Lexer：识别新内置函数（C 实现与 uya-src 已同步）
  - [x] AST：添加 AST_SRC_NAME/AST_SRC_PATH/AST_SRC_LINE/AST_SRC_COL/AST_FUNC_NAME 节点（C 实现与 uya-src 已同步）
  - [x] Parser：解析无参数调用（C 实现与 uya-src 已同步）
  - [x] Checker：类型推断（&[i8] 或 i32），@func_name 仅在函数体内可用（C 实现与 uya-src 已同步）
  - [x] Codegen：生成字符串常量或整数常量，@func_name 从 current_function_decl 获取函数名（C 实现与 uya-src 已同步）
  - [x] 测试用例：test_src_location.uya（C 版 `--c99` 和自举版 `--uya --c99` 均通过）
  - [x] 自举对比：C 编译器与自举编译器生成的 C 文件完全一致
- [x] **忽略标识符 _**：用于忽略返回值、解构、match，规范 uya.md §3

**忽略标识符 _（已实现）**：Parser 在 primary_expr 中当标识符为 `_` 时生成 AST_UNDERSCORE；解构中 `_` 已支持（names 含 `"_"` 时 checker/codegen 跳过）。Checker：`_ = expr` 仅检查右侧；禁止 `var _`、参数 `_`；infer_type 对 AST_UNDERSCORE 报错「不能引用 _」。Codegen：`_ = expr` 语句生成 `(void)(expr);`，表达式生成 `(expr)`。测试 `test_underscore.uya` 通过 `--c99`；uya-src 已同步，自举编译通过。

---

## 17. test 关键字（测试单元）

**语法规范**：`test "测试说明" { statements }`，规范 [grammar_formal.md](../grammar_formal.md) §4.1、[uya.md](../uya.md) 第 28 章。

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
- [grammar_formal.md](../grammar_formal.md) §4.1 - 测试单元语法
- [uya.md](../uya.md) 第 28 章 - Uya 测试单元（Test Block）

**实现优先级**：中（建议在核心功能稳定后实现，便于编写内联测试）

---

## 文档与测试约定

- **先添加测试用例**：在编写编译器代码前，先在 `tests/programs/` 添加测试用例（如 `test_xxx.uya` 或预期编译失败的 `error_xxx.uya`），覆盖目标场景。
- 新特性先在 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md)（或完整版 spec）中定义类型、BNF、语义、C99 映射。
- 测试放在 `tests/programs/`，需同时通过 `--c99` 与 `--uya --c99`。
- **测试用例 100% 覆盖**：新特性需添加多场景用例（含成功路径与预期失败用例 `error_*.uya`），覆盖主要分支与边界情况。
- 实现顺序：Lexer → AST → Parser → Checker → Codegen；C 实现与 `uya-src/` 同步。

### 测试程序约定

- **测试文件命名**：
  - 正常测试：`test_xxx.uya`（测试通过时返回 0）
  - 预期编译失败：`error_xxx.uya`（以 `error_` 开头，测试脚本会自动识别为预期编译失败）
- **测试返回值**：
  - 测试通过应返回 0（退出码 0）
  - 测试失败应返回非 0（退出码表示错误类型）
  - 测试脚本通过 `bridge.c` 提供 `main` 函数，调用 `uya_main()`（Uya 的 `main` 函数被重命名为 `uya_main`）
- **多文件测试**：
  - 多文件测试放在 `tests/programs/multifile/` 或 `tests/programs/cross_deps/` 目录下
  - 测试脚本会自动收集目录下所有 `.uya` 文件一起编译
- **语法约定**：
  - `use` 语句只能在顶层使用，不能在函数体内
  - 结构体按值传递会被移动，移动后不能再次使用（需重新创建变量）
  - `export` 关键字用于标记可导出的项（函数、结构体等）
- **验证要求**：
  - 每个测试用例必须同时通过 `--c99`（C 版编译器）和 `--uya --c99`（自举版编译器）
  - 二者都通过才算测试通过

### 完成任务后更新本文档

完成某项或某阶段实现后，请同步更新本待办文档，便于跟踪进度、与 Cursor 计划联动：

1. **勾选子项**：在该阶段的小节内，将已完成的具体子项复选框由 `[ ]` 改为 `[x]`。
2. **更新总览状态**：若某阶段（如「1. 基础类型与字面量」）下的**全部**子项均已完成，在文首「建议实现顺序（总览）」表中，将该阶段的状态由 `[ ]` 改为 `[x]`。
3. **类型系统详表（可选）**：若实现涉及「类型系统扩展（详表）」中的某行，可在该表中同步勾选或标注对应行，便于与 Mini 现状/完整版目标对照。

---

## 类型系统扩展（详表，供实现时勾选）

| 待办 | Mini 现状 | 完整版目标 | 规范 |
|------|-----------|------------|------|
| 整数类型 | i32, usize, byte | + i8, i16, i64, u8, u16, u32, u64 | uya.md §2 | [x] |
| 类型极值 | 无 | @max, @min 内置函数（以 @ 开头） | uya.md §2、§16 | [x] |
| 切片类型 | 无 | &[T], &[T: N] | uya.md §2、§4 | [x] |
| 元组类型 | 无 | (T1, T2,...), .0/.1, 解构 | uya.md §2 | [x] |
| 错误联合 !T | 无 | !T, error 定义 | uya.md §2、§5 | [x] |
| 联合体类型 | 无 | union U { v1: T1, v2: T2 } | uya.md §4.5 | [x] |
| 接口类型 | 无 | interface I, struct S : I | uya.md §6 | [x] |
| 函数指针 | 无 | fn(...) type, type Alias = fn(...) type | uya.md §5.2 | [ ] |
| 原子类型 | 无 | atomic T, &atomic T | uya.md §13 | [x] |
| 类型别名 | 无 | type A = B | uya.md §5.2、§24.6.2 | [ ] |
| 多维数组 | 无 | [[T: N]: M]，多维访问 arr[i][j] | uya.md §2、§4 | [ ] |
| 结构体默认值 | 无 | field: Type = default_value, Struct{} | uya.md §4.3 | [ ] |
| &void 通用指针 | 部分 | &void → &T 类型擦除 | uya.md §2 | [~] |
| 块注释 | 完整 | /* ... */（可嵌套） | uya.md §1 | [x] |

---

## 19. 标准库基础设施（std）

**详细设计文档**：
- 同步标准库（`std.c`、`std.io`、`std.fmt` 等）：[`docs/std_c_design.md`](./docs/std_c_design.md)
- 异步标准库（`std.async.*`）：[`docs/std_async_design.md`](./docs/std_async_design.md)

**核心目标**：

1. **编译器完全不依赖外部 C 标准库**
   - Uya 编译器自身使用 std.c（自己实现的标准库）
   - 实现真正的自举：用 Uya 实现的编译器 + 用 Uya 实现的标准库

2. **生成无依赖的 libc 给第三方使用**
   - 通过 `--outlibc` 生成单文件 C 库（libuya.c + libuya.h）
   - 生成的库零外部依赖，可替代 musl/glibc

**架构概览**：
```
std/
├── c/              # 纯 Uya 实现的 C 标准库（musl 替代）
│   ├── syscall/    # 系统调用封装（Linux/Windows/macOS）
│   ├── string.uya  # 字符串和内存操作
│   ├── stdio.uya   # 标准 I/O
│   ├── stdlib.uya  # 内存分配、进程控制
│   └── math.uya    # 数学函数
├── io/             # 平台无关同步 I/O 抽象
├── async/          # 异步编程标准库（详见 docs/std_async_design.md）
│   ├── io/         # AsyncWriter / AsyncReader
│   ├── task.uya    # Task<T>, Waker
│   ├── event/      # 平台事件后端（epoll/kqueue/IOCP）
│   ├── channel.uya # Channel<T>, MpscChannel<T>
│   └── scheduler.uya # Scheduler 事件循环调度器
├── fmt/            # 格式化库（纯 Uya 实现）
├── bare_metal/     # 裸机平台支持
└── builtin/        # 编译器内置运行时
```

**关键特性**：
- ✅ **完全用 Uya 实现**：std.c 是纯 Uya 代码，不是 FFI 绑定
- ✅ **零外部依赖**：直接使用系统调用，不依赖任何 C 库
- ✅ **单文件输出**：`--outlibc` 生成单个 .c 和 .h 文件
- ✅ **可替代 musl/glibc**：兼容 C ABI，可作为 libc 使用

**实施路线**：

1. **阶段 0**：基础设施（`@syscall` 内置函数、错误类型）
2. **阶段 1**：单平台验证（Linux x86-64 MVP）
3. **阶段 2**：条件编译宏（`std.target` 模块）
4. **阶段 3**：多平台扩展（macOS、ARM64）
5. **阶段 4**：Windows 支持（可选）

**详细设计内容**（包括系统调用层、跨平台方案、条件编译、核心库实现、--outlibc 功能等）请参见：[`docs/std_c_design.md`](./docs/std_c_design.md)

### 19.1 标准库实现清单

- [ ] `std.io` - 同步 I/O 抽象层（Writer/Reader 接口）
- [ ] `std.c.syscall` - 系统调用封装（`@syscall` 内置函数）
- [ ] `std.c.string` - 字符串和内存操作（纯 Uya）
- [ ] `std.c.stdio` - 标准 I/O（基于 syscall）
- [ ] `std.c.stdlib` - 内存分配、进程控制
- [ ] `std.c.math` - 数学函数（纯 Uya）
- [ ] `std.fmt` - 格式化库（纯 Uya）
- [ ] `std.bare_metal` - 裸机平台支持
- [ ] `std.builtin` - 编译器内置运行时
- [ ] `std.target` - 条件编译宏系统
- [ ] `std.async.*` - 异步标准库（Task/Waker/AsyncIO/EventLoop/Channel/Scheduler）

**详细实现方案**：
- 同步部分：参见 [`docs/std_c_design.md`](./docs/std_c_design.md)
- 异步部分：参见 [`docs/std_async_design.md`](./docs/std_async_design.md)

---

## 20. @print/@println 内置函数

**设计目标**：提供类型安全、易用的输出功能，支持字符串插值，在不同运行环境下自动适配。

### 20.1 语法定义

```uya
@print(expr)    // 打印表达式（不换行）
@println(expr)  // 打印表达式并换行
```

### 20.2 支持的类型

i32, i64, u32, u64, usize, f32, f64, bool, 字符串（&[i8], [i8: N], *byte）

### 20.3 实现方案

#### 编译器实现

- [ ] **Lexer**：添加 print/println 到合法内置函数列表
- [ ] **AST**：AST_PRINT 和 AST_PRINTLN 节点
- [ ] **Parser**：解析 `@print(expr)` 和 `@println(expr)`
- [ ] **Checker**：类型检查，验证参数可打印
- [ ] **Codegen - Hosted 模式**：生成 printf 调用
- [ ] **Codegen - Freestanding 模式**：生成 uya_putchar 调用链

#### 字符串插值集成

- [ ] **Hosted 模式**：`@println("x=${x}")` → `printf("x=%d\n", x)`
- [ ] **Freestanding 模式**：逐段展开插值

### 20.4 编译器选项

- [ ] `--hosted`（默认）：生成 printf
- [ ] `--freestanding`：生成弱符号 uya_putchar
- [ ] `--no-io`：禁用 @print/@println

### 20.5 测试用例

- [ ] `test_print_basic.uya` - 基础打印
- [ ] `test_print_types.uya` - 各种类型
- [ ] `test_print_interp.uya` - 字符串插值
- [ ] `test_print_format.uya` - 格式说明符
- [ ] `test_print_freestanding.uya` - 裸机测试

### 20.6 文档

- [ ] **用户文档**：`docs/builtins/print.md`
- [ ] **示例**：`examples/print/`

**实现优先级**：高（与标准库配合，提供基础 I/O 能力）

**参考文档**：
- [uya.md](../uya.md) §16 - 内置函数
- [uya.md](../uya.md) §17 - 字符串插值

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

**编译器实现**（已完成，v0.2.31）：

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
- [x] **uya-src 同步**

**测试用例**（已完成）：
- [x] `test_struct_default.uya` - 基础默认值（80 行，已通过）

**参考文档**：
- [uya.md](../uya.md) §4.3 - 结构体默认值语法
- [RELEASE_v0.2.31.md](../RELEASE_v0.2.31.md) - v0.2.31 版本说明

**实现状态**：✅ 已完成（v0.2.31）

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

**编译器实现**（已完成，v0.2.31）：

- [x] **Lexer**：`type` 关键字 token
- [x] **AST**：`AST_TYPE_ALIAS` 节点（名称 + 目标类型）
- [x] **Parser**：解析 `type Identifier = type_expr ;`
- [x] **Checker**：
  - [x] 类型别名解析（别名 → 实际类型）
  - [x] 循环别名检测
  - [x] 别名在类型位置的透明替换
- [x] **Codegen**：
  - [x] C99 映射为 `typedef`
- [x] **uya-src 同步**

**测试用例**（已完成）：
- [x] `test_type_alias.uya` - 基础类型别名（170 行，已通过）

**参考文档**：
- [uya.md](../uya.md) §5.2 - 函数指针与类型别名
- [uya.md](../uya.md) §24.6.2 - 类型别名实现
- [uya.md](../uya.md) §29.5 - 已实现特性列表
- [RELEASE_v0.2.31.md](../RELEASE_v0.2.31.md) - v0.2.31 版本说明

**实现状态**：✅ 已完成（v0.2.31）

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
- [uya.md](../uya.md) §2 - 类型系统（`[[T: N]: M]`）
- [uya.md](../uya.md) §4.2.3 - 数组字段布局
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
- [uya.md](../uya.md) §1 - 词法约定（`/* 块 */`（可嵌套））

---

## 25. 内存安全证明（规范 uya.md §14）

**设计目标**：通过编译期证明消除所有未定义行为（UB）。证明范围仅限当前函数内，证明超时则自动插入运行时检查。

**内存安全强制表**：

| UB 场景 | 编译期要求 | 失败处理 |
|---------|-----------|---------|
| 数组越界 | 常量越界 → 编译错误；变量 → 证明 `i >= 0 && i < len` | 证明超时 → 自动插入运行时检查 |
| 空指针解引用 | 证明 `ptr != null` 或前序有空检查 | 证明超时 → 自动插入运行时检查 |
| 未初始化使用 | 证明首次使用前已赋值 | 证明超时 → 自动插入运行时检查 |
| 整数溢出 | 常量溢出 → 编译错误；变量 → 编译器证明或显式检查 | 证明超时 → 自动插入运行时检查 |
| 除零 | 常量除零 → 编译错误；变量 → 证明 `y != 0` | 证明超时 → 自动插入运行时检查 |

**证明机制分层**：
1. **常量折叠**：编译期常量直接检查
2. **路径敏感分析**：跟踪代码路径，建立约束条件
3. **符号执行**：复杂场景建立约束系统验证
4. **函数返回值**：调用者必须显式处理（编译器不跨函数证明）
5. **证明超时**：有限时间内无法完成则自动插入运行时检查

**编译器实现**：

- [ ] **Checker**：
  - [ ] 常量折叠（溢出/越界/除零检测）
  - [ ] 路径敏感分析框架
  - [ ] 符号执行引擎（约束求解）
  - [ ] 证明超时机制
  - [ ] 未初始化使用检测
  - [ ] 空指针解引用检测
- [ ] **Codegen**：
  - [ ] 自动插入运行时边界检查代码
  - [ ] 自动插入运行时溢出检查代码
  - [ ] 自动插入运行时空指针检查代码
- [ ] **uya-src 同步**

**测试用例**：
- [ ] `test_safety_bounds.uya` - 数组越界证明
- [ ] `test_safety_overflow.uya` - 整数溢出证明
- [ ] `test_safety_null.uya` - 空指针证明
- [ ] `test_safety_uninit.uya` - 未初始化检测
- [ ] `test_safety_runtime.uya` - 运行时检查自动插入

**参考文档**：
- [uya.md](../uya.md) §14 - 内存安全

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
- [uya.md](../uya.md) §15 - 并发安全

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
- [uya.md](../uya.md) §29.3 - 接口组合
- [examples/file_6.uya](../examples/file_6.uya) - 接口组合示例

**实现状态**：✅ 已完成（v0.2.30）

---

*文档版本：与计划「Mini到完整版TODO」一致，便于与 Cursor 计划联动。*
