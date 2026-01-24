# null 字面量测试用例说明

本文档说明 `null` 字面量相关的测试用例。

## 测试文件列表

### 1. `test_null_literal.uya`
**目的**：测试 `null` 字面量的基本功能

**测试内容**：
- `null` 指针初始化（`&i32`、`&Node`、`&usize`、`&bool`、`&byte`）
- `null` 指针比较（`==`、`!=`）
- `null` 指针赋值
- `null` 指针与非 `null` 指针比较

**状态**：✅ 已存在

---

### 2. `test_null_return.uya` ⭐ **新增**
**目的**：测试 `null` 字面量作为函数返回值

**测试内容**：
- 返回 `&i32` 类型的 `null`
- 返回 `&void` 类型的 `null`
- 返回结构体指针类型的 `null`（`&Node`、`&Point`）
- 返回基础类型指针的 `null`（`&usize`、`&bool`、`&byte`）
- 条件返回 `null`
- 多个 `return null` 语句

**关键测试点**：
- 验证类型检查器正确处理 `null` 作为返回值
- 验证 `null` 可以返回给任意类型的指针
- 验证条件返回和多个返回语句的场景

**状态**：✅ 新增，测试通过

---

### 3. `test_null_comprehensive.uya` ⭐ **新增**
**目的**：综合测试 `null` 字面量的所有使用场景

**测试内容**：
- `null` 变量初始化（所有指针类型）
- `null` 赋值
- `null` 比较（`==`、`!=`）
- `null` 在条件语句中的使用
- `null` 与结构体指针
- `null` 与嵌套结构体指针
- `null` 与 `&void` 通用指针
- `null` 在循环中的使用
- `null` 指针的 `sizeof`
- 多个 `null` 指针比较
- `null` 指针赋值链

**关键测试点**：
- 覆盖 `null` 的所有使用场景
- 验证 `null` 与各种指针类型的兼容性
- 验证 `null` 在复杂控制流中的行为

**状态**：✅ 新增，测试通过

---

## 测试覆盖范围

### 指针类型覆盖
- ✅ `&i32` - 整数指针
- ✅ `&usize` - 大小类型指针
- ✅ `&bool` - 布尔指针
- ✅ `&byte` - 字节指针
- ✅ `&void` - 通用指针
- ✅ `&Node` - 结构体指针
- ✅ `&Point` - 结构体指针（嵌套）

### 使用场景覆盖
- ✅ 变量初始化：`var ptr: &T = null;`
- ✅ 变量赋值：`ptr = null;`
- ✅ 函数返回值：`return null;`
- ✅ 指针比较：`ptr == null`、`ptr != null`
- ✅ 条件语句：`if ptr == null { ... }`
- ✅ 循环条件：`while ptr == null { ... }`
- ✅ 类型转换：`void_ptr = ptr as &void; void_ptr = null;`

---

## 运行测试

### 运行单个测试
```bash
cd compiler-mini
./tests/run_programs.sh tests/programs/test_null_return.uya
./tests/run_programs.sh tests/programs/test_null_comprehensive.uya
```

### 运行所有 null 相关测试
```bash
cd compiler-mini
./tests/run_programs.sh tests/programs/test_null_*.uya
```

---

## 相关修复

这些测试用例验证了以下修复：

1. **类型检查器修复**：
   - 在 `type_can_implicitly_convert` 中添加了 `TYPE_VOID` 到指针类型的隐式转换
   - 在 return 语句检查中添加了对 `null` 字面量的特殊处理

2. **错误消息改进**：
   - 改进了指针类型的错误消息显示
   - 支持显示 `&void`、`*void` 和指向结构体的指针类型

---

## 规范依据

根据 Uya Mini 语法规范（`spec/UYA_MINI_SPEC.md`）：

- **`null` 字面量**（第604-607行）：
  - 类型为指针类型（`&T` 或 `*T`），从上下文推断或显式指定
  - 用于指针初始化和比较
  - 示例：`var p: &Node = null;`（类型从变量声明推断）

- **指针比较规则**（第1026行）：
  - 指针比较：支持 `==` 和 `!=`，可以与 `null` 比较

这些测试用例确保 `null` 字面量可以正确赋值给任意类型的指针，符合规范要求。

