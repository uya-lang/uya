# Uya v0.2.10 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.9 以来的提交记录整理，在 v0.2.9 基础上完成 **结构体切片字段** 与 **接口（interface）** 的完整实现。C 版与自举版（uya-src）同步，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. 结构体切片字段（C 版 + 自举版同步）

- **语法**：结构体可含 `&[T]` 或 `&[T: N]` 字段，规范 uya.md §2、§4。
- **语义**：胖指针（ptr+len）作为结构体成员；`base[start:len]` 切片、`@len(slice)` 对成员访问（如 `s.field.len`）均支持。
- **实现范围**：
  - **C 版**：main.c 中 `collect_slice_types_from_node` 增加 AST_STRUCT_DECL 分支、emit 顺序调整为 slice 结构体先于用户结构体；types.c 中 `get_c_type_of_expr` 支持 AST_MEMBER_ACCESS；expr.c 中 `@len`/数组访问对成员访问切片字段生成 `.len`/`.ptr[i]`。
  - **uya-src**：ast.uya、parser.uya、checker.uya、codegen（types/expr/main/structs）同步。
- **测试**：test_struct_slice_field.uya 通过 `--c99` 与 `--uya --c99`；自举对比 `--c99 -b` 一致。

### 2. 接口（interface）完整支持（C 版 + 自举版同步）

- **interface 定义**：`interface I { fn method(self: *Self, ...) Ret; ... }`，规范 uya.md §6。
- **实现**：`struct S : I { }`，方法块 `S { fn method(...) { ... } }`，Checker 校验实现完整性。
- **装箱与调用**：接口值 8/16B（vtable+data）、装箱点、接口方法调用（vtable 派发）。
- **形式**：
  - 接口声明：`interface IAdd { fn add(self: *Self, x: i32) i32; }`
  - 结构体实现：`struct Counter : IAdd { value: i32 }`
  - 方法块：`Counter { fn add(self: *Self, x: i32) i32 { return self.value + x; } }`
  - 装箱传参：`fn use_it(a: IAdd) i32`，`use_it(c)` 将 struct 装箱为接口
  - 方法调用：`a.add(10)` 通过 vtable 派发
- **实现范围**：
  - **C 版**：types.c 接口类型→`struct uya_interface_I`；structs.c 生成 interface/vtable 结构体与 vtable 常量；function.c 方法块生成 `uya_S_m` 函数；expr.c 接口方法调用（vtable 派发）、装箱（struct→interface 传参）；main.c 处理 AST_METHOD_BLOCK、emit_vtable_constants。
  - **uya-src**：lexer.uya（TOKEN_INTERFACE）、ast.uya（AST_INTERFACE_DECL、AST_METHOD_BLOCK）、parser.uya（parse_interface、parse_method_block、`struct : I`、顶层 IDENTIFIER+{）、checker.uya（TYPE_INTERFACE、find_interface_decl_from_program、find_method_block_for_struct、struct_implements_interface、member_access 接口方法）、codegen（types/structs/function/expr/main 全面同步）。
  - **修复**：parser.uya 在「字段访问和数组访问链」循环中补全 `TOKEN_LEFT_PAREN` 分支，以解析 `obj.method(args)` 形式的方法调用（如 `a.add(10)`）。
- **测试**：test_interface.uya 覆盖接口定义、实现、装箱与调用，通过 `--c99` 与 `--uya --c99`；自举编译 `./compile.sh --c99 -e` 成功。

---

## 主要变更（自 v0.2.9 起）

| 提交 | 变更摘要 |
|------|----------|
| 5fa6f2a | 实现结构体切片字段支持：collect_slice_types_from_node AST_STRUCT_DECL、emit 顺序、get_c_type_of_expr、@len/array_access 成员访问；test_struct_slice_field.uya |
| 6b00595 | 实现接口支持：types/structs 接口类型、vtable 结构体；function 方法块；expr 装箱与 vtable 派发；UYA_MINI_SPEC、todo_mini_to_full |
| cbf64b7 | 实现接口方法调用和 vtable 生成：emit_vtable_constants、方法前向声明与定义、接口方法调用与装箱、c99_type_to_c_with_self |
| 98a10a7 | 实现接口声明和方法块的解析与生成：Lexer、AST、Parser、Checker 接口支持；uya-src 全面同步；parser 补全 obj.method(args) 解析 |

---

## 实现范围（概要）

| 区域 | 变更摘要 |
|------|----------|
| 规范/文档 | UYA_MINI_SPEC（接口语法）、todo_mini_to_full（结构体切片字段、接口已实现） |
| C 编译器 | main、types、structs、function、expr、ast、lexer、parser、checker |
| uya-src | ast、lexer、parser、checker、codegen/c99（types、structs、function、expr、main） |
| 测试 | test_struct_slice_field.uya、test_interface.uya |

---

## 验证

```bash
cd compiler-mini

# C 版
./tests/run_programs.sh --c99 test_struct_slice_field.uya
./tests/run_programs.sh --c99 test_interface.uya

# 自举版
./tests/run_programs.sh --uya --c99 test_struct_slice_field.uya
./tests/run_programs.sh --uya --c99 test_interface.uya

# 自举编译
cd uya-src && ./compile.sh --c99 -e

# 自举对比（C 输出与自举输出一致）
./compile.sh --c99 -e -b
```

---

## 已知限制与后续方向

- **本版本**：结构体切片字段、接口（interface、方法块、vtable、装箱、接口方法调用）已完整实现并同步到自举版。
- **自举对比**：v0.2.10 时自举对比 `--c99 -b` 存在单行空行差异（main.uya 中 prototype 循环后多一次 `fputs("\n")`），后续提交已修复。
- **后续计划**：按 todo_mini_to_full.md 继续迭代器接口、结构体方法、drop/RAII 等；保持 C 与 uya-src 同步。

---

## 致谢

感谢所有参与 Uya Mini 结构体切片字段与接口实现、自举测试的贡献者。

---

## 附录：版本与仓库

- **版本**：v0.2.10
- **基于**：v0.2.9
- **记录范围**：v0.2.9..v0.2.10（4 个提交）
- **仓库**：<https://github.com/uya-lang/uya>
- **许可**：MIT（见 [LICENSE](LICENSE)）
