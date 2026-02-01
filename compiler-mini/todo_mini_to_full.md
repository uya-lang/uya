# Uya Mini 到完整版待办文档

基于 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md) 第 9 节「与完整 Uya 的区别」与项目根目录 [uya.md](../uya.md) 完整规范对照。实现时按「建议实现顺序」执行，每项需同步更新 C 实现与 `uya-src/`，测试需同时通过 `--c99` 与 `--uya --c99`。

**实现约定**：在编写编译器代码前，先在 `tests/programs/` 添加测试用例（如 `test_xxx.uya` 或预期编译失败的 `error_xxx.uya`），覆盖目标场景；实现后再跑 `--c99` 与 `--uya --c99` 验证，二者都通过才算通过。

---

## 建议实现顺序（总览）

| 序号 | 阶段 | 状态 |
|------|------|------|
| 0 | 规范同步：内置函数以 @ 开头 | [x] |
| 1 | 基础类型与字面量 | [x] |
| 2 | 错误处理 | [x] |
| 3 | defer / errdefer | [x] |
| 4 | 切片 | [x] |
| 5 | match 表达式 | [x] |
| 6 | for 扩展 | [x]（整数范围已实现；迭代器依赖阶段 7 接口） |
| 7 | 接口 | [x]（C 实现完成；uya-src 待同步） |
| 8 | 结构体方法 + drop + 移动语义 | [x]（外部/内部方法、drop/RAII、移动语义 C 实现与 uya-src 已同步） |
| 9 | 模块系统 | [ ] |
| 10 | 字符串插值 | [x] |
| 11 | 原子类型 | [ ] |
| 12 | 运算符与安全 | [ ] |
| 13 | 联合体（union） | [x]（C 实现完成；uya-src 待同步） |

---

## 下次优先实现（规范 0.39 变更）

以下三项来自 uya.md 0.34 规范变更（0.35 已含联合体），建议在阶段 2（错误处理）之前或与之并行时优先实现。

- [x] **参数列表即元组**：函数体内通过 `@params` 访问整份参数列表作为元组，与现有元组类型、解构声明衔接；规范 uya.md 规范变更 0.34
- [x] **可变参数**：`...` 形参（C 语法兼容）、`printf(fmt, ...)` 参数转发、`@params` 元组访问；编译器智能优化（未用 `@params` 时零开销）；规范 uya.md §5.4
- [x] **字符串插值与 printf 结合**：`"a${x}"`、`"a${x:format}"`，结果类型与 printf 格式一致，规范 uya.md §17；可与阶段 10 合并实现  
  **C 实现**：Lexer（INTERP_*、string_mode/interp_depth、返回 INTERP_SPEC 后重置 reading_spec 修复 type=8）、AST、Parser、Checker、Codegen 已完成。支持多段、带 `:spec`（如 `#06x`、`.2f`、`ld`、`zu`）、连续插值、变量初始化、printf 单参（`printf("%s", arg)` 消除 -Wformat-security）、i64/f32/usize/u8 等类型。测试 test_string_interp.uya（19 条用例，含表达式插值 `${a+b}`）、test_string_interp_minimal/simple/one 通过 `--c99`。

**uya-src 已同步**：Lexer（TOKEN_INTERP_*、string_mode/interp_depth/reading_spec/pending_interp_open、read_string_char_into_buffer、next_token 插值逻辑）、AST（AST_STRING_INTERP、ASTStringInterpSegment）、Parser（primary_expr 中 INTERP_TEXT/OPEN 解析、parser_peek 禁用 string_mode）、Checker（checker_interp_format_max_width、AST_STRING_INTERP 类型与 computed_size）、Codegen（c99_emit_string_interp_fill、collect 阶段预收集格式串、call 实参临时缓冲、stmt 变量初始化）。test_string_interp*.uya 通过 `--uya --c99`。**自举对比（--c99 -b）已通过**：根因为 Arena 在解析 main.uya 时内存不足（实参列表扩展需 648 字节），修复为 arena_alloc 失败时打印「Arena 分配失败（内存不足）」并 exit(1)、ARENA_BUFFER_SIZE 增至 48MB。

**可变参数与 @params（C 实现与 uya-src 同步已完成）**：Lexer 支持 `@params`；AST 新增 AST_PARAMS、call 的 has_ellipsis_forward；Parser 支持 fn 形参 `...`、primary 中 `@params`/`@params.0`、调用末尾 `...`；Checker 中 `@params` 仅函数体内、类型为参数元组，`...` 转发仅可变参数函数、实参个数=被调固定参数个数；Codegen 按需生成（未用 @params 不生成元组、无 `...` 转发不生成 va_list），转发时用 va_list+vprintf 等。测试 `test_varargs.uya`、`test_varargs_full.uya` 通过 `--c99` 与 `--uya --c99`。

---

## 0. 规范同步：内置函数以 @ 开头

规范已升级为所有内置函数以 `@` 开头（uya.md 0.34、UYA_MINI_SPEC.md）。已实现新语法并迁移测试。

- [x] **Lexer**：识别 `@` 及 `@` 后标识符（如 `@sizeof`、`@alignof`、`@len`、`@max`、`@min`）；新增 `TOKEN_AT_IDENTIFIER` 类型
- [x] **AST**：沿用现有节点（AST_SIZEOF、AST_ALIGNOF、AST_LEN、AST_INT_LIMIT）
- [x] **Parser**：`primary_expr` 支持 `@max`、`@min`（无参）；支持 `@sizeof(...)`、`@alignof(...)`、`@len(...)` 调用形式
- [x] **Checker**：识别并校验 `@sizeof`、`@alignof`、`@len`、`@max`、`@min` 的语义
- [x] **Codegen**：生成与现有一致的 C 代码（输出不变）
- [x] **测试用例迁移**：将 `tests/programs/` 中所有用例改为 `@sizeof`、`@alignof`、`@len`、`@max`、`@min`
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

**uya-src 已同步**：Lexer（TOKEN_TRY/CATCH/ERROR/DEFER/ERRDEFER）、AST（AST_ERROR_DECL/AST_DEFER_STMT/AST_ERRDEFER_STMT/AST_TRY_EXPR/AST_CATCH_EXPR/AST_ERROR_VALUE/AST_TYPE_ERROR_UNION）、Parser（!T 类型、error.Name、try expr、catch 后缀、defer/errdefer 语句、error 声明）、Checker（TYPE_ERROR_UNION/TYPE_ERROR、type_from_ast、checker_infer_type、checker_check_node、return error.X 与 !T 成功值检查）、Codegen（emit_defer_cleanup、AST_BLOCK defer/errdefer 收集、return/break/continue 前插入、return error.X、!T 成功值、AST_TRY_EXPR/AST_CATCH_EXPR/AST_ERROR_VALUE、AST_TYPE_ERROR_UNION、c99_get_or_add_error_id、collect_string_constants）。**待修复**：自举编译尚有问题（C99 链接/编译阶段失败），需排查并修复后验证 `--uya --c99` 与 `--c99 -b`。

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
- [ ] **迭代器**：可迭代对象（接口）、`for obj |v|`、`for obj |&v|`、索引形式，规范 uya.md §6.12、§8（依赖阶段 7 接口）

**涉及**：Parser（range、迭代器）、Checker、Codegen、迭代器接口与 for 脱糖，uya-src。  
**uya-src 已同步**：lexer.uya（TOKEN_DOT_DOT、`.` 与 read_number）、ast.uya（for_stmt_is_range/range_start/range_end）、parser.uya（范围解析）、checker.uya（is_range 分支）、codegen/c99/stmt.uya（范围代码生成）、main.uya 与 utils.uya（collect）。test_for_range.uya、test_for_loop.uya 通过 `--uya --c99`。**自举对比（--c99 -b）已通过**：main.uya 中 ARENA_BUFFER_SIZE 增至 64MB 以容纳 for 范围等 AST 自举时 Arena 需求。

---

## 7. 接口

- [x] **interface 定义**：`interface I { fn method(self: &Self,...) Ret; ... }`，规范 uya.md §6
- [x] **实现**：`struct S : I { }`，方法块 `S { fn method(...) { ... } }`，Checker 校验实现
- [x] **装箱与调用**：接口值 8/16B（vtable+data）、装箱点、接口方法调用；Codegen 已实现（vtable 生成、装箱、call 通过 vtable）

**涉及**：AST、Parser、Checker、Codegen（vtable、装箱点、逃逸检查），uya-src。

**当前进度**：Lexer、AST、Parser、Checker 已完成。**C 实现 Codegen 已完成**：types.c 接口类型→struct uya_interface_I；structs.c 生成 interface/vtable 结构体与 vtable 常量；function.c 方法块生成 uya_S_m 函数；expr.c 接口方法调用（vtable 派发）、装箱（struct→interface 传参）；main.c 处理 AST_METHOD_BLOCK、emit_vtable_constants。test_interface.uya 通过 `--c99`。**uya-src 已同步**：lexer.uya（TOKEN_INTERFACE、interface 关键字）；ast.uya（AST_INTERFACE_DECL、AST_METHOD_BLOCK、struct_decl_interface_*、method_block_*）；parser.uya（parse_interface、parse_method_block、struct : I、顶层 IDENTIFIER+{）；checker.uya（TYPE_INTERFACE、find_interface_decl_from_program、find_method_block_for_struct、struct_implements_interface、type_equals/type_from_ast/check_expr_type、member_access 接口方法）；codegen types/structs/function/expr/main（接口类型、emit_interface_structs_and_vtables、emit_vtable_constants、方法前向声明与定义、接口方法调用与装箱、c99_type_to_c_with_self）。自举编译 `./compile.sh --c99 -e` 成功；test_interface.uya 通过 `--uya --c99`。**修复**：parser.uya 在「字段访问和数组访问链」循环中补全了 `TOKEN_LEFT_PAREN` 分支，以解析 `obj.method(args)` 形式的方法调用（如 `a.add(10)`）。自举对比 `--c99 -b` 仅有单行空行差异。

---

## 8. 结构体方法 + drop + 移动语义

- [x] **结构体方法（外部方法块）**：`self: &Self`、外部方法块（`S { fn method(self: &Self) Ret { } }`），规范 uya.md §4、§29.3  
  **C 实现**：Checker 增加 struct method call 分支（callee 为 obj.method、obj 类型为 struct 时，查找 method_block 校验实参）；checker_check_member_access 当字段不存在时检查 method_block 返回方法返回类型；expr.c 增加 struct method 调用代码生成（`uya_StructName_method(&obj, args...)`），支持 const 前缀类型、值/指针两种 receiver。  
  **uya-src 已同步**：checker.uya（checker_check_call_expr 接口+结构体方法、checker_check_member_access 方法返回类型）；expr.uya（struct method call 代码生成）。test_struct_method.uya 通过 `--c99` 与 `--uya --c99`。
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
  **C 实现（已完成）**：Checker 校验 drop 签名（仅一个参数 self: T 按值、返回 void）、每类型仅一个 drop（方法块与结构体内部不能重复）；Codegen 在块退出时先 defer 再按变量声明逆序插入 drop 调用，在 return/break/continue 前插入当前块变量的 drop；生成 drop 方法时先按字段逆序插入字段的 drop 再用户体。测试 test_drop_simple.uya、test_drop_order.uya 通过 `--c99`；error_drop_wrong_sig.uya、error_drop_duplicate.uya 预期编译失败。**uya-src**：checker.uya 已同步（check_drop_method_signature、METHOD_BLOCK 与 struct_decl 的 drop 校验）；codegen（stmt.uya 的 emit_drop_cleanup/emit_current_block_drops、current_drop_scope 与 drop_var_*、function.uya 的 drop 方法字段逆序）待同步后 test_drop_*.uya 方可通过 `--uya --c99`。
- [x] **移动语义**：结构体赋值/传参/返回为移动，活跃指针禁止移动，规范 uya.md §12.5  
  **C 实现（已完成）**：Checker 维护已移动集合（moved_names）、符号表 pointee_of 记录 `p = &x` 的活跃指针；赋值/const 初始化/return/函数实参/结构体字面量字段若源为结构体变量则标记移动；使用标识符时检查「已被移动」、移动前检查「存在活跃指针」「循环中不能移动」。测试 test_move_simple.uya 通过；error_move_use_after.uya、error_move_active_pointer.uya、error_move_in_loop.uya 预期编译失败。**uya-src 已同步**：checker.uya 增加 Symbol.pointee_of、TypeChecker.moved_names/moved_count；moved_set_contains、has_active_pointer_to、checker_mark_moved、checker_mark_moved_call_args；AST_IDENTIFIER 使用前查已移动、var_decl/assign/return/call/struct_init 处标记移动及 pointee_of；为满足自举在返回/赋值处使用 copy_type 避免对同一 Type 变量多次移动。test_move_simple 与 error_move_* 在 --c99 与 --uya --c99 下均通过/预期失败。

**涉及**：Parser、Checker、Codegen（drop 插入、移动与指针检查），uya-src。

---

## 9. 模块系统

- [ ] **目录即模块**：项目根=main，路径如 std.io，规范 uya.md §1.5
- [ ] **export**：`export fn/struct/interface/const/error`、`export extern`，规范 uya.md §1.5.3
- [ ] **use**：`use path;`、`use path.item;`、别名 `as`，无通配符，规范 uya.md §1.5.4
- [ ] **循环依赖**：编译期检测并报错，规范 uya.md §1.5.7

**涉及**：多文件/多目录解析、符号表与可见性、uya-src。

---

## 10. 字符串插值

- [x] **插值语法（C 实现 + uya-src 同步）**：`"a${x}"`、`"a${x:format}"`，结果类型 `[i8: N]`，与 printf 格式一致，规范 uya.md §17  
  已实现：多段、`:spec`（#06x、.2f、ld、zu）、连续插值、变量/数组初始化、printf 单参、表达式插值（如 `${a+b}`）、i32/u32/i64/f32/f64/usize/u8 等。test_string_interp.uya（19 条用例）等通过 `--c99` 与 `--uya --c99`。uya-src 已同步（Lexer/AST/Parser/Checker/Codegen）。
- [ ] **原始字符串**：`` `...` ``，无转义，规范 uya.md §1

**涉及**：Lexer、Parser、类型与宽度计算、Codegen。

---

## 11. 原子类型

- [ ] **atomic T**：语言层原子类型，规范 uya.md §13
- [ ] **&atomic T**：原子指针
- [ ] **读/写/复合赋值**：自动原子指令，零运行时锁

**涉及**：类型系统、Checker、Codegen（原子指令），uya-src。

---

## 12. 运算符与安全

- [ ] **饱和运算**：`+|`、`-|`、`*|`，规范 uya.md §10、§16
- [ ] **包装运算**：`+%`、`-%`、`*%`，规范 uya.md §10、§16
- [ ] **切片运算符**：`[start:len]` 用于切片语法，规范 uya.md §10
- [ ] **类型转换 as!**：强转返回 `!T`，需 try/catch，规范 uya.md §11
- [ ] **内存安全证明**：数组越界/空指针/未初始化/溢出/除零：证明或插入运行时检查，规范 uya.md §14

**涉及**：Lexer（新运算符）、Parser、Checker、Codegen，uya-src。

---

## 13. 联合体（union）

- [x] **union 定义**：`union Name { variant1: Type1, variant2: Type2 }`，规范 uya.md §4.5
- [x] **创建**：`UnionName.variant(expr)`，如 `IntOrFloat.i(42)`
- [x] **访问**：`match` 模式匹配（必须处理所有变体）、`.variant(bind)` 模式、穷尽性检查
- [x] **实现**：带隐藏 tag 的 C 布局（`struct uya_tagged_U { int _tag; union U u; }`），零开销 match
- [ ] **extern union**：外部 C 联合体声明与互操作（待实现）
- [ ] **联合体方法**：`self: &Self`，内部/外部方法块（待实现）

**C 实现（已完成）**：Lexer（TOKEN_UNION）、AST（AST_UNION_DECL、MATCH_PAT_UNION）、Parser（parse_union、match 中 .variant(bind)）、Checker（TYPE_UNION、union init 校验、match 穷尽与变体类型推断）、Codegen（gen_union_definition、union init、match union 的 _tag 分支）。测试 test_union.uya 通过 `--c99`。**uya-src 待同步**。

**涉及**：Lexer、AST、Parser、Checker、Codegen，uya-src。依赖 match 表达式（阶段 5）。

---

## 内置与标准库（补充）

- [ ] **@sizeof/@alignof**：保持（以 @ 开头），并支持上述完整类型集合
- [ ] **@len**：扩展至切片等，规范 uya.md §16
- [x] **忽略标识符 _**：用于忽略返回值、解构、match，规范 uya.md §3

**忽略标识符 _（已实现）**：Parser 在 primary_expr 中当标识符为 `_` 时生成 AST_UNDERSCORE；解构中 `_` 已支持（names 含 `"_"` 时 checker/codegen 跳过）。Checker：`_ = expr` 仅检查右侧；禁止 `var _`、参数 `_`；infer_type 对 AST_UNDERSCORE 报错「不能引用 _」。Codegen：`_ = expr` 语句生成 `(void)(expr);`，表达式生成 `(expr)`。测试 `test_underscore.uya` 通过 `--c99`；uya-src 已同步，自举编译通过。

---

## 文档与测试约定

- 新特性先在 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md)（或完整版 spec）中定义类型、BNF、语义、C99 映射。
- 测试放在 `tests/programs/`，需同时通过 `--c99` 与 `--uya --c99`。
- **测试用例 100% 覆盖**：新特性需添加多场景用例（含成功路径与预期失败用例 `error_*.uya`），覆盖主要分支与边界情况。
- 实现顺序：Lexer → AST → Parser → Checker → Codegen；C 实现与 `uya-src/` 同步。

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
| 错误联合 !T | 无 | !T, error 定义 | uya.md §2、§5 |
| 联合体类型 | 无 | union U { v1: T1, v2: T2 } | uya.md §4.5 |
| 接口类型 | 无 | interface I, struct S : I | uya.md §6 |
| 函数指针 | 无 | fn(...) type | uya.md §5.2 |
| 原子类型 | 无 | atomic T, &atomic T | uya.md §13 |

---

*文档版本：与计划「Mini到完整版TODO」一致，便于与 Cursor 计划联动。*
