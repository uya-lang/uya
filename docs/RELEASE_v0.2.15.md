# Uya v0.2.15 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.14 以来的变更整理，完成 **规范 0.39** 的实现：方法 self 统一为 `&T`，`*T` 仅用于 FFI；同类型指针可通过 `as` 互相转换。C 版与 uya-src 自举版已同步，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. 规范 0.39：方法 self 统一为 &T，*T 仅用于 FFI（破坏性变更）

- **方法首个参数统一为 `self: &T`**：
  - 接口：`interface I { fn method(self: &Self, ...) Ret; ... }`
  - 结构体方法：`S { fn method(self: &Self, ...) Ret { ... } }`
  - 替换原有的 `self: *Self` / `self: *StructName`
- **`*T` 仅用于 FFI**：`extern fn foo(buf: *byte, ...) i32`，作为 extern 函数的参数与返回值
- **`&T as *T` 转换**：调用 FFI 函数时，可使用 `expr as *T` 将 Uya 普通指针转为 FFI 指针
- **向后兼容性**：破坏性变更，需将现有 `self: *Self` 改为 `self: &Self`

### 2. 同类型指针可通过 as 互相转换

- **`&T` ↔ `*T`**：指向相同类型 T 的指针可通过 `as` 互相转换，无精度损失
- **示例**：`&byte as *byte`（FFI 调用）、`*byte as &byte`（extern 返回值当普通指针使用）
- **规范**：UYA_MINI_SPEC、uya.md、uya_ai_prompt.md 已更新

### 3. 编译器实现

- **checker.c / checker.uya**：
  - 新增 `check_method_self_param`：方法（非 drop）的 self 参数必须为 `&T`，禁止 `*T`
  - 在接口定义、方法块、结构体内方法处调用该检查
  - drop 检查错误信息更新：`不能为 &Self、*Self 或指针`
- **实现已支持**：`*T as &T` 转换此前已在 checker 中允许（同类型指针），本次仅更新规范描述

### 4. 测试用例更新

- 所有接口/结构体方法测试：`self: *Self` → `self: &Self`
- **error_drop_wrong_sig.uya**：改为 `self: &Self`，预期报错（drop 须为按值 `self: T`）

---

## 测试验证

- **C 版编译器（`--c99`）**：test_interface、test_struct_method_*、test_struct_inner_method_* 等通过
- **自举版编译器（`--uya --c99`）**：同上
- **自举构建**：`./compile.sh --c99 -e` 成功
- **error_drop_wrong_sig**：预期编译失败，报错「drop 方法 self 必须为按值类型 T」

---

## 文件变更统计（自 v0.2.14 以来）

**规范与文档**：
- `changelog.md` — 0.39、0.38 版本变更
- `uya.md` — 规范 0.39、指针转换规则（&T ↔ *T）
- `compiler-c-spec/UYA_MINI_SPEC.md` — 方法语法、*T 用途、指针转换
- `grammar_formal.md`、`grammar_quick.md`、`uya_ai_prompt.md`、`comparison.md`、`readme.md`、`index.html`、`compiler-mini/todo_mini_to_full.md` — 示例与版本同步

**C 实现**：
- `compiler-mini/src/checker.c` — check_method_self_param、drop 错误信息、interface/method_block/struct_decl 处调用

**自举实现（uya-src）**：
- `compiler-mini/uya-src/checker.uya` — check_method_self_param、drop 错误信息、interface/method_block/struct_decl 处调用

**测试用例**：
- `test_interface.uya`、`test_struct_method*.uya`、`test_struct_inner_method*.uya`、`error_struct_method_*.uya`、`error_drop_wrong_sig.uya` — 全部 `*Self` → `&Self`

---

## 版本对比

### v0.2.14 → v0.2.15 变更

- **破坏性变更**：
  - 方法 self 由 `self: *Self` 改为 `self: &Self`
  - 现有使用 `*Self` 的代码需手动迁移

- **新增/改进**：
  - ✅ 规范 0.39：方法 self 统一为 &T，*T 仅用于 FFI
  - ✅ 同类型指针 &T ↔ *T 可通过 as 互相转换
  - ✅ 类型检查：方法 self 必须为 &T，禁止 *T

- **规范版本**：0.36/0.37 → 0.39

---

## 使用示例

### 接口与方法（self: &Self）

```uya
interface IAdd {
  fn add(self: &Self, x: i32) i32;
}

struct Counter : IAdd {
  value: i32
}

Counter {
  fn add(self: &Self, x: i32) i32 {
    return self.value + x;
  }
}
```

### 同类型指针转换

```uya
extern fn write(fd: i32, buf: *byte, count: i32) i32;

fn main() i32 {
  var buffer: [byte: 100] = [];
  // &T as *T：FFI 调用
  const n: i32 = write(1, &buffer[0] as *byte, 100);
  return n;
}
```

---

## 相关资源

- **语言规范**：`uya.md`（0.39）
- **语法规范**：`grammar_formal.md`
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/`

---

**本版本完成规范 0.39 实现：方法 self 统一为 &T，*T 仅用于 FFI；同类型指针可通过 as 互相转换。**
