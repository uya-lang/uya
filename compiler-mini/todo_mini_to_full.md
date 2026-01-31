# Uya Mini 到完整版待办文档

基于 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md) 第 9 节「与完整 Uya 的区别」与项目根目录 [uya.md](../uya.md) 完整规范对照。实现时按「建议实现顺序」执行，每项需同步更新 C 实现与 `uya-src/`，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 建议实现顺序（总览）

| 序号 | 阶段 | 状态 |
|------|------|------|
| 0 | 规范同步：内置函数以 @ 开头 | [x] |
| 1 | 基础类型与字面量 | [x] |
| 2 | 错误处理 | [ ] |
| 3 | defer / errdefer | [ ] |
| 4 | 切片 | [ ] |
| 5 | match 表达式 | [ ] |
| 6 | for 扩展 | [ ] |
| 7 | 接口 | [ ] |
| 8 | 结构体方法 + drop + 移动语义 | [ ] |
| 9 | 模块系统 | [ ] |
| 10 | 字符串插值 | [ ] |
| 11 | 原子类型 | [ ] |
| 12 | 运算符与安全 | [ ] |

---

## 下次优先实现（规范 0.34 变更）

以下三项来自 uya.md 0.34 规范变更，建议在阶段 2（错误处理）之前或与之并行时优先实现。

- [ ] **参数列表即元组**：函数形参表 `(a: T1, b: T2)` 视为元组类型，实参为元组字面量或解构；与现有元组类型、解构声明衔接
- [ ] **可变参数**：`...T` 或 `...` 形参、`...expr` 展开实参，规范 uya.md 可变参数与调用约定
- [ ] **字符串插值与 printf 结合**：`"a${x}"`、`"a${x:format}"`，结果类型与 printf 格式一致，规范 uya.md §17；可与阶段 10 合并实现

**涉及**：Parser（形参/实参元组、`...`）、Checker（元组与可变参数类型）、Codegen（元组传参、va_list/va_arg）、Lexer/字符串插值；uya-src 同步。实现时先更新 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md) 与测试用例，再按 Lexer → AST → Parser → Checker → Codegen 顺序推进。

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

**说明**：元组类型已在 C 实现中完成（类型、字面量、.0/.1、解构），测试 `test_tuple.uya` 已加入，`--c99` 全部通过。uya-src 同步尚未完成，故 `--uya --c99` 运行元组测试会失败，待后续同步。

---

## 2. 错误处理

- [ ] **错误类型与 !T**：预定义 `error Name;`、运行时 `error.Name`、`!T` 类型与内存布局，规范 uya.md §2 错误类型、§5
- [ ] **try 关键字**：`try expr` 传播错误、算术溢出检查（返回 error.Overflow），规范 uya.md §5、§10、§16
- [ ] **catch 语法**：`expr catch |err| { }`、`expr catch { }`，两种返回方式，规范 uya.md §5
- [ ] **main 签名**：支持 `fn main() !i32`，错误→退出码，规范 uya.md §5.1.1

**涉及**：Lexer（try、catch、error）、AST（!T、try/catch 节点）、Parser、Checker、Codegen、uya-src。

---

## 3. defer / errdefer

- [ ] **defer**：作用域结束 LIFO 执行（正常+错误返回），规范 uya.md §9
- [ ] **errdefer**：仅错误返回时 LIFO 执行，用于资源清理，规范 uya.md §9

**涉及**：Lexer、AST、Parser、Checker、Codegen（作用域退出点插入），uya-src。

---

## 4. 切片

- [ ] **切片类型**：`&[T]`、`&[T: N]`，胖指针（ptr+len），规范 uya.md §2、§4
- [ ] **切片语法**：`&arr[start:len]`（含负索引），规范 uya.md §4 切片语法
- [ ] **结构体切片字段**：结构体含 `&[T]` 字段，规范 uya.md §4

**涉及**：类型系统、Parser（切片表达式）、Checker、Codegen（胖指针布局）、uya-src。

---

## 5. match 表达式

- [ ] **match 语法**：`match expr { pat => expr, else => expr }`，规范 uya.md §8
- [ ] **模式**：常量、绑定、结构体解构、错误分支、字符串匹配

**涉及**：Lexer、AST、Parser、Checker、Codegen（if-else 链或跳转表），uya-src。

---

## 6. for 扩展

- [ ] **整数范围**：`for start..end |v|`、`for start.. |v|`、可丢弃元素形式，规范 uya.md §8
- [ ] **迭代器**：可迭代对象（接口）、`for obj |v|`、`for obj |&v|`、索引形式，规范 uya.md §6.12、§8

**涉及**：Parser（range、迭代器）、Checker、Codegen、迭代器接口与 for 脱糖，uya-src。

---

## 7. 接口

- [ ] **interface 定义**：`interface I { }`，规范 uya.md §6
- [ ] **实现**：`struct S : I { }`，实现接口方法、vtable 生成
- [ ] **装箱与调用**：接口值 8/16B（vtable+data）、单条 call 指令

**涉及**：AST、Parser、Checker、Codegen（vtable、装箱点、逃逸检查），uya-src。

---

## 8. 结构体方法 + drop + 移动语义

- [ ] **结构体方法**：`self: *Self`、内部/外部方法块，规范 uya.md §4、§29.3
- [ ] **drop / RAII**：用户自定义 `fn drop(self: T) void`，作用域结束逆序调用，规范 uya.md §12
- [ ] **移动语义**：结构体赋值/传参/返回为移动，活跃指针禁止移动，规范 uya.md §12.5

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

- [ ] **插值语法**：`"a${x}"`、`"a${x:format}"`，结果类型 `[i8: N]`，与 printf 格式一致，规范 uya.md §17
- [ ] **原始字符串**：`` `...` ``，无转义，规范 uya.md §1

**涉及**：Lexer、Parser、类型与宽度计算、Codegen，uya-src。

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

## 内置与标准库（补充）

- [ ] **@sizeof/@alignof**：保持（以 @ 开头），并支持上述完整类型集合
- [ ] **@len**：扩展至切片等，规范 uya.md §16
- [ ] **忽略标识符 _**：用于忽略返回值、解构、match，规范 uya.md §3

---

## 文档与测试约定

- 新特性先在 [spec/UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md)（或完整版 spec）中定义类型、BNF、语义、C99 映射。
- 测试放在 `tests/programs/`，需同时通过 `--c99` 与 `--uya --c99`。
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
| 切片类型 | 无 | &[T], &[T: N] | uya.md §2、§4 |
| 元组类型 | 无 | (T1, T2,...), .0/.1, 解构 | uya.md §2 | [x] |
| 错误联合 !T | 无 | !T, error 定义 | uya.md §2、§5 |
| 接口类型 | 无 | interface I, struct S : I | uya.md §6 |
| 函数指针 | 无 | fn(...) type | uya.md §5.2 |
| 原子类型 | 无 | atomic T, &atomic T | uya.md §13 |

---

*文档版本：与计划「Mini到完整版TODO」一致，便于与 Cursor 计划联动。*
