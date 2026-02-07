# Uya v0.2.30 版本说明

**发布日期**：2026-02-06

本版本主要完成了**接口组合（Interface Composition）**功能的完整实现，允许接口包含其他接口的方法，实现接口继承。同时优化了方法块语法，修复了泛型接口实现检查的问题。

---

## 核心亮点

### 1. 接口组合（Interface Composition）

- **组合语法**：接口可以在体内引用其他接口，自动继承其方法
- **循环检测**：编译器检测接口组合的循环依赖并报错
- **方法继承**：组合接口的 vtable 自动包含所有被组合接口的方法
- **实现验证**：结构体实现组合接口时，编译器验证所有方法（包括继承的方法）都已实现
- **自举同步**：uya-src 自举编译器完整支持接口组合功能

```uya
interface IReader {
    fn read(self: &Self) i32;
}

interface IWriter {
    fn write(self: &Self, value: i32) void;
}

// 接口组合：IReadWriter 包含 IReader 和 IWriter 的所有方法
interface IReadWriter {
    IReader;    // 组合 IReader
    IWriter;    // 组合 IWriter
    fn flush(self: &Self) i32;  // 自己的方法
}

// 实现组合接口：需要实现所有被组合接口的方法
struct Buffer : IReadWriter {
    data: i32,
    flushed: i32,
}

Buffer {
    fn read(self: &Self) i32 { return self.data; }
    fn write(self: &Self, value: i32) void { }
    fn flush(self: &Self) i32 { return self.flushed; }
}
```

### 2. 方法块语法优化

- **简化语法**：方法块现在只需要结构体名称 `Buffer { ... }`
- **移除冗余**：不再需要重复声明实现的接口 `Buffer : IReadWriter { ... }`
- **保持一致**：与现有代码风格保持一致

### 3. 泛型接口实现检查修复

- **泛型接口名称处理**：正确处理带类型参数的接口名（如 `Getter<i32>`）
- **基本名称提取**：实现验证时自动提取基本接口名进行查找

---

## 模块变更

### C 实现（src）

| 模块 | 变更 |
|------|------|
| ast.h/ast.c | 接口声明新增 `composed_interfaces` 和 `composed_count` 字段 |
| parser.c | 解析接口体中的组合接口引用（`IReader;`） |
| checker.c | 新增 `find_interface_method_sig` 递归查找、循环检测、实现完整性验证 |
| codegen/c99/structs.c | 新增 `collect_interface_method_sigs` 收集组合方法、vtable 生成支持组合接口 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| ast.uya | 新增 `interface_decl_composed_interfaces` 和 `interface_decl_composed_count` 字段 |
| parser.uya | 解析接口体中的组合接口引用 |
| checker.uya | 新增 `find_interface_method_sig`、`check_interface_compose_cycle`、实现完整性验证 |
| codegen/c99/structs.uya | 新增 `collect_interface_method_sigs`、`collect_interface_method_sigs_internal` |

### 测试用例

新增 3 个接口组合相关测试用例：

- `test_interface_compose.uya` - 接口组合基础功能测试
- `error_interface_compose_missing.uya` - 缺少方法实现错误检测
- `error_interface_compose_cycle.uya` - 循环依赖错误检测

---

## 测试验证

- **C 版编译器（`--c99`）**：306 个测试全部通过
- **自举版编译器（`--uya --c99`）**：所有测试通过
- **自举对比**：C 编译器与自举编译器生成的 C 文件完全一致

---

## 文件变更统计（自 v0.2.29 以来）

**统计**：12 个文件变更，约 450 行新增

**主要变更**：
- `compiler-mini/src/ast.h` — 新增组合接口字段定义
- `compiler-mini/src/ast.c` — 初始化组合接口字段
- `compiler-mini/src/parser.c` — 解析接口组合语法
- `compiler-mini/src/checker.c` — +80 行（循环检测、方法查找、实现验证）
- `compiler-mini/src/codegen/c99/structs.c` — +50 行（收集组合方法、vtable 生成）
- `compiler-mini/uya-src/ast.uya` — 新增组合接口字段
- `compiler-mini/uya-src/parser.uya` — +45 行（解析接口组合）
- `compiler-mini/uya-src/checker.uya` — +120 行（循环检测、方法查找、实现验证）
- `compiler-mini/uya-src/codegen/c99/structs.uya` — +70 行（收集组合方法）
- `compiler-mini/tests/programs/` — 3 个新测试用例

---

## 版本对比

### v0.2.29 → v0.2.30 变更

- **新增功能**：
  - ✅ 接口组合支持（组合语法、循环检测、方法继承）
  - ✅ 组合接口的 vtable 自动包含所有被组合接口的方法
  - ✅ 结构体实现组合接口时的方法完整性验证

- **优化改进**：
  - ✅ 方法块语法简化（只需结构体名，无需重复声明接口）
  - ✅ 修复泛型接口实现检查（正确处理 `Getter<i32>` 等名称）

- **测试改进**：
  - ✅ 新增 3 个接口组合测试用例
  - ✅ 测试覆盖：基础功能、缺少方法、循环依赖

- **非破坏性**：向后兼容，现有代码行为不变

---

## 技术细节

### 接口组合解析

接口体中可以包含两种元素：
1. **方法签名**：`fn method(self: &Self, ...) RetType;`
2. **组合接口引用**：`InterfaceName;`

```
interface IReadWriter {
    IReader;    // 组合接口引用
    IWriter;    // 组合接口引用
    fn flush(self: &Self) i32;  // 方法签名
}
```

### 循环依赖检测

编译器使用深度优先搜索检测接口组合的循环依赖：

```uya
// 错误示例：循环依赖
interface IA { IB; }
interface IB { IA; }  // 错误：接口组合存在循环依赖
```

### vtable 生成

组合接口的 vtable 结构体自动包含所有被组合接口的方法指针：

```c
// 生成的 C 代码
struct uya_vtable_IReadWriter {
    int32_t (*read)(void *self);      // 来自 IReader
    void (*write)(void *self, int32_t value);  // 来自 IWriter
    int32_t (*flush)(void *self);     // IReadWriter 自己的方法
};
```

### 实现验证流程

1. 获取结构体声明实现的接口列表
2. 对每个接口，递归收集所有方法签名（包括组合接口的方法）
3. 检查结构体是否实现了所有方法
4. 如有缺失，报告具体错误信息

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **异步编程完善**：完整的 async/await 运行时支持
- **内存安全证明**：数组越界/空指针/未初始化/溢出/除零检查
- **标准库实现**：实现 `@print/@println` 等内置函数
- **类型别名**：`type` 关键字支持

---

## 相关资源

- **语言规范**：`uya.md` - 接口组合语法
- **示例代码**：`examples/file_6.uya` - 接口组合示例
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md` §27 - 接口组合
- **测试用例**：`compiler-mini/tests/programs/test_interface_compose.uya`

---

**本版本完成了接口组合功能的完整实现，支持接口包含其他接口的方法，实现类似接口继承的功能。同时优化了方法块语法，修复了泛型接口实现检查的问题。C 实现与 uya-src 自举编译器已完全同步，所有 306 个测试用例全部通过，自举对比一致。**

