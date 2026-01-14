# 阶段5：类型检查器

## 概述

翻译类型检查器（Checker）模块，代码量大（1,678行），逻辑复杂。

**优先级**：P0

**工作量估算**：6-8 小时

**依赖**：阶段0（准备工作 - str_utils.uya）、阶段1（Arena）、阶段2（AST）、阶段4（Parser）

**原因**：CodeGen 依赖 Checker。

---

## 任务列表

### 任务 5.1：阅读和理解 C99 代码

- [ ] 阅读 `src/checker.h` - 理解 Checker 接口
- [ ] 阅读 `src/checker.c` - 理解 Checker 实现
- [ ] 理解类型检查的工作原理：
  - [ ] 符号表管理（作用域、符号查找）
  - [ ] 类型系统（类型比较、类型推断）
  - [ ] 哈希表实现（符号表存储）
  - [ ] 递归类型处理
  - [ ] 类型转换检查
  - [ ] 变量和函数检查

**参考**：代码量大（1,678行），逻辑复杂（类型系统、符号表）

---

### 任务 5.2：翻译 Checker 结构体定义

**文件**：`uya-src/checker.uya`

- [ ] 翻译 `Checker` 结构体：
  - [ ] Arena 分配器字段（`arena`）
  - [ ] 符号表相关字段（`symbols`, `symbol_count` 等）
  - [ ] 作用域相关字段（`scope_depth` 等）
  - [ ] 错误相关字段（`has_error` 等）
  - [ ] 其他辅助字段

**类型映射**：
- `Arena *` → `&Arena`
- `Symbol *` → `&Symbol`
- `Symbol **` → `&Symbol` 的数组（`[&Symbol: N]`）
- `int` → `i32`
- `size_t` → `i32`

---

### 任务 5.3：翻译符号表相关结构体

- [ ] 翻译 `Symbol` 结构体：
  - [ ] 符号名称字段（`name`）
  - [ ] 符号类型字段（`type`）
  - [ ] 符号种类字段（`kind`）
  - [ ] 其他字段
- [ ] 翻译符号表结构：
  - [ ] 使用固定大小的指针数组（`[&Symbol: 256]`）
  - [ ] 使用开放寻址法处理哈希冲突
  - [ ] 实际符号对象通过 Arena 分配

**关键挑战**：
- 哈希表实现：使用固定大小数组和开放寻址
- 指针数组：使用 `[&Symbol: 256]` 存储指向 Arena 分配对象的指针

---

### 任务 5.4：翻译符号表操作函数

- [ ] 翻译符号表操作函数：
  - [ ] `symbol_table_init` - 初始化符号表
  - [ ] `symbol_table_insert` - 插入符号
  - [ ] `symbol_table_lookup` - 查找符号
  - [ ] `symbol_table_remove` - 移除符号（作用域退出时）
  - [ ] `hash_string` - 字符串哈希函数（使用 `str_utils.uya` 中的函数）

---

### 任务 5.5：翻译类型检查函数

- [ ] 翻译类型检查函数：
  - [ ] `check_program` - 程序检查入口
  - [ ] `check_declaration` - 声明检查
  - [ ] `check_statement` - 语句检查
  - [ ] `check_expression` - 表达式检查
  - [ ] `check_function` - 函数检查
  - [ ] `check_struct` - 结构体检查
  - [ ] 其他检查函数

---

### 任务 5.6：翻译类型系统函数

- [ ] 翻译类型系统函数：
  - [ ] `type_equal` - 类型相等比较
  - [ ] `type_compatible` - 类型兼容性检查
  - [ ] `type_promote` - 类型提升
  - [ ] `resolve_type` - 类型解析
  - [ ] `check_type_conversion` - 类型转换检查
  - [ ] 其他类型系统函数

**关键挑战**：
- 类型系统实现：递归类型、类型比较
- 类型兼容性：保持与 C99 版本相同的类型规则

---

### 任务 5.7：翻译作用域管理函数

- [ ] 翻译作用域管理函数：
  - [ ] `enter_scope` - 进入作用域
  - [ ] `exit_scope` - 退出作用域
  - [ ] `push_symbol` - 推入符号到当前作用域
  - [ ] `lookup_symbol` - 在当前作用域查找符号
  - [ ] 其他作用域函数

---

### 任务 5.8：翻译错误处理函数

- [ ] 翻译错误处理函数：
  - [ ] `report_type_error` - 报告类型错误（使用 `fprintf`）
  - [ ] `report_symbol_error` - 报告符号错误
  - [ ] 其他错误处理函数

---

### 任务 5.9：使用字符串辅助函数

- [ ] 在 `checker.uya` 中包含或引用 `str_utils.uya` 的声明
- [ ] 将所有字符串操作改为使用 `str_utils.uya` 中的函数
- [ ] 确保所有错误消息使用 `fprintf` 输出

---

### 任务 5.10：添加中文注释

- [ ] 为所有结构体添加中文注释
- [ ] 为所有函数添加中文注释
- [ ] 为类型系统逻辑添加中文注释
- [ ] 为符号表管理逻辑添加中文注释
- [ ] 为作用域管理逻辑添加中文注释

---

### 任务 5.11：验证功能

- [ ] 创建简单的测试程序（`uya-src/test_checker.uya`）：
  - [ ] 测试类型检查
  - [ ] 测试符号表操作
  - [ ] 测试作用域管理
  - [ ] 测试错误处理
- [ ] 使用 C99 编译器编译测试程序
- [ ] 运行测试程序验证功能正确性

**参考**：`tests/test_checker.c` - 现有的 C99 测试程序

---

## 完成标准

- [ ] `checker.uya` 已创建，包含完整的 Checker 实现
- [ ] 所有结构体已翻译
- [ ] 所有符号表操作函数已翻译
- [ ] 所有类型检查函数已翻译
- [ ] 所有类型系统函数已翻译
- [ ] 所有作用域管理函数已翻译
- [ ] 所有错误处理函数已翻译
- [ ] 使用 `str_utils.uya` 中的字符串函数
- [ ] 所有代码使用中文注释
- [ ] 功能与 C99 版本完全一致
- [ ] 测试程序通过
- [ ] 已更新 `PROGRESS.md`，标记阶段5为完成

---

## 参考文档

- `src/checker.h` - C99 版本的 Checker 接口
- `src/checker.c` - C99 版本的 Checker 实现
- `tests/test_checker.c` - Checker 测试程序
- `uya-src/str_utils.uya` - 字符串辅助函数模块
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范，确认类型系统规则
- `BOOTSTRAP_PLAN.md` - 哈希表实现策略和类型映射规则

---

## 注意事项

1. **哈希表实现**：使用固定大小的指针数组（`[&Symbol: 256]`），实际对象通过 Arena 分配
2. **符号表管理**：使用开放寻址法处理哈希冲突
3. **作用域管理**：正确管理作用域的进入和退出
4. **类型系统**：保持与 C99 版本相同的类型规则和兼容性检查
5. **字符串处理**：必须使用 `str_utils.uya` 中的封装函数
6. **文件大小**：如果文件超过 1500 行，需要拆分为多个文件

---

## C99 → Uya Mini 映射示例

```c
// C99
typedef struct {
    Symbol *slots[256];
    int count;
} SymbolTable;

Symbol *symbol_table_lookup(SymbolTable *table, const char *name) {
    int hash = hash_string(name) % 256;
    // 开放寻址查找
    // ...
}

// Uya Mini
struct SymbolTable {
    slots: [&Symbol: 256];
    count: i32;
}

fn symbol_table_lookup(table: &SymbolTable, name: *byte) &Symbol {
    const hash: i32 = hash_string(name) % 256;
    // 开放寻址查找
    // ...
}
```

