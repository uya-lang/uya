# Uya v0.2.11 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.10 以来的提交记录整理，完成**接口（interface）**与**结构体方法（struct methods）**的全面支持，包括外部方法块和内部定义两种方式。C 版与自举版（uya-src）同步，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. 接口（interface）完整实现（C 版 + 自举版同步）

- **interface 定义**：`interface I { fn method(self: *Self, ...) Ret; ... }`，规范 uya.md §6
- **结构体实现接口**：`struct S : I { }`，编译器检查实现完整性
- **方法块**：`S { fn method(...) { ... } }` 外部方法块定义接口方法
- **装箱与调用**：
  - 接口值为 8/16B（vtable+data）胖指针
  - 自动装箱：`struct` → `interface` 传参时自动装箱
  - vtable 派发：`obj.method()` 通过 vtable 调用对应实现

- **实现范围**：
  - **C 版**：Lexer（TOKEN_INTERFACE）、AST（AST_INTERFACE_DECL）、Parser（interface/method_block）、Checker（TYPE_INTERFACE、接口实现校验）、Codegen（vtable 生成、装箱、方法调用）
  - **uya-src**：lexer.uya、ast.uya、parser.uya、checker.uya、codegen/c99/structs.uya、expr.uya、main.uya 同步

- **测试**：test_interface.uya 通过 `--c99` 与 `--uya --c99`

### 2. 结构体方法（外部方法块）

- **语法**：`StructName { fn method(self: *Self, ...) Ret { ... } }`，规范 uya.md §4、§29.3
- **self 参数**：首个参数必须为 `self: *Self`，支持值/指针 receiver
- **方法调用**：`obj.method(args)` 自动传递 `&obj` 或 `obj`（指针）作为 self

- **实现范围**：
  - **Checker**：
    - `checker_check_call_expr`：识别结构体方法调用（`obj.method()`），查找 method_block 校验参数
    - `checker_check_member_access`：字段不存在时检查方法，返回方法返回类型
  - **Codegen**：
    - `gen_method_prototype`/`gen_method_function`：生成方法原型和定义
    - 方法调用生成：`uya_StructName_method(&obj, args...)`
    - 支持 const 前缀类型、值/指针两种 receiver

- **测试用例**（全部通过）：
  - `test_struct_method.uya` - 基本方法调用
  - `test_struct_method_args.uya` - 带参数的方法
  - `test_struct_method_multi.uya` - 多个方法
  - `test_struct_method_ptr.uya` - 指针 receiver
  - `test_struct_method_void.uya` - void 返回
  - `test_struct_method_with_interface.uya` - 方法与接口共存
  - `error_struct_method_arg_count.uya` - 参数个数错误（编译失败）
  - `error_struct_method_not_found.uya` - 方法不存在（编译失败）

### 3. 结构体方法（内部定义）

- **语法**：方法定义在结构体花括号内，与字段并列
  ```uya
  struct Point {
    x: f32,
    y: f32,
    fn distance(self: *Self) f32 {
      return self.x + self.y;
    }
  }
  ```
  规范 uya.md §29.3

- **特性**：
  - 字段与方法可混合定义
  - 支持可选逗号分隔
  - 可与外部方法块共存
  - 可与接口实现结合使用

- **实现范围**：
  - **AST**：struct_decl 增加 `methods`/`method_count` 字段
  - **Parser**：parse_struct 支持解析内部 `fn` 关键字
  - **Checker**：`find_method_in_struct` 统一查找外部方法块和内部方法
  - **Codegen**：
    - main.c：生成内部方法原型和实现
    - function.c：`find_method_in_struct_c99` 统一查找
    - expr.c、structs.c：使用新函数处理方法调用和 vtable

- **测试用例**（全部通过 `--c99` 与 `--uya --c99`）：
  - `test_struct_inner_method.uya` - 基本的内部方法定义
  - `test_struct_inner_method_args.uya` - 带参数的内部方法
  - `test_struct_inner_method_multi.uya` - 多个内部方法
  - `test_struct_inner_method_void.uya` - void 返回的内部方法
  - `test_struct_inner_method_mixed.uya` - 字段与方法混合定义
  - `test_struct_inner_method_with_interface.uya` - 内部方法 + 接口实现

---

## 测试验证

- **C 版编译器（`--c99`）**：205/205 测试通过
- **自举版编译器（`--uya --c99`）**：205/205 测试通过
- **自举对比（`--c99 -b`）**：C 版与自举版生成 C 代码一致

---

## 文件变更统计

```
44 files changed, 1028 insertions(+), 58 deletions(-)
```

### 主要修改文件

**C 实现**：
- `src/ast.h` / `src/ast.c` - AST 结构扩展
- `src/parser.c` - 接口、方法块、内部方法解析
- `src/checker.c` - 类型检查与方法查找
- `src/codegen/c99/*.c` - 接口 vtable、方法调用代码生成

**自举实现（uya-src）**：
- `ast.uya` / `parser.uya` / `checker.uya` - 与 C 版同步
- `codegen/c99/*.uya` - 代码生成逻辑同步

**测试用例**：
- 新增 15 个测试用例（9 个成功路径 + 2 个错误检测 + 6 个内部方法）

**文档更新**：
- `todo_mini_to_full.md` - 更新阶段 7（接口）、阶段 8（结构体方法）状态

---

## 待办事项状态

在 `todo_mini_to_full.md` 中：

| 阶段 | 状态 | 说明 |
|------|------|------|
| 7. 接口 | ✅ | C 实现完成，uya-src 已同步 |
| 8. 结构体方法（外部方法块） | ✅ | C 实现完成，uya-src 已同步 |
| 8. 结构体方法（内部定义） | ✅ | C 实现完成，uya-src 已同步 |
| 8. drop / RAII | ⏳ | 待实现 |
| 8. 移动语义 | ⏳ | 待实现 |

---

## 版本对比

### v0.2.10 → v0.2.11 变更

- **新增特性**：
  - ✅ 接口（interface）完整支持
  - ✅ 结构体方法（外部方法块）
  - ✅ 结构体方法（内部定义）

- **改进**：
  - vtable 生成与派发机制
  - 方法查找统一处理（外部+内部）
  - 接口装箱与类型转换

- **测试覆盖**：
  - 新增 15 个测试用例
  - 总计 205 个测试用例全部通过

---

## 使用示例

### 接口定义与实现

```uya
interface IAdd {
  fn add(self: *Self, x: i32) i32;
}

struct Counter : IAdd {
  value: i32
}

Counter {
  fn add(self: *Self, x: i32) i32 {
    return self.value + x;
  }
}

fn use_interface(a: IAdd) i32 {
  return a.add(10);  // vtable 派发
}

fn main() i32 {
  const c: Counter = Counter{ value: 5 };
  return use_interface(c);  // 自动装箱
}
```

### 结构体方法（外部方法块）

```uya
struct Point {
  x: f32,
  y: f32
}

Point {
  fn distance(self: *Self) f32 {
    return self.x + self.y;
  }
}

fn main() i32 {
  const p: Point = Point{ x: 2.0, y: 3.0 };
  const d: f32 = p.distance();  // 调用方法
  return 0;
}
```

### 结构体方法（内部定义）

```uya
struct Rect {
  width: i32,
  fn getWidth(self: *Self) i32 {
    return self.width;
  },
  height: i32,
  fn area(self: *Self) i32 {
    return self.width * self.height;
  }
}

fn main() i32 {
  const r: Rect = Rect{ width: 3, height: 4 };
  const a: i32 = r.area();
  return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：

1. **drop / RAII**：用户自定义 `fn drop(self: T) void`，作用域结束逆序调用
2. **移动语义**：结构体赋值/传参/返回为移动，活跃指针禁止移动
3. **模块系统**：目录即模块、export/use 语法、循环依赖检测

---

## 相关资源

- **语言规范**：`uya.md`
- **语法规范**：`grammar_formal.md`
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/`

---

**本版本继续推进 Uya 语言从 Mini 到完整版的实现路线，接口和结构体方法为后续面向对象特性打下基础。**
