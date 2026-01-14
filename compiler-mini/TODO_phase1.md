# 阶段1：基础模块 - Arena 分配器

## 概述

翻译 Arena 分配器模块，这是所有其他模块的基础依赖。

**优先级**：P0

**工作量估算**：1-2 小时

**依赖**：阶段0（准备工作）

**原因**：所有其他模块都依赖 Arena 分配器，必须最先翻译。

---

## 任务列表

### 任务 1.1：阅读和理解 C99 代码

- [ ] 阅读 `src/arena.h` - 理解 Arena 接口
- [ ] 阅读 `src/arena.c` - 理解 Arena 实现
- [ ] 理解 Arena 分配器的工作原理：
  - [ ] 内存布局（固定大小缓冲区）
  - [ ] 分配算法（简单的指针递增）
  - [ ] 对齐处理

**参考**：代码量小（80行），逻辑简单

---

### 任务 1.2：翻译 Arena 结构体定义

**文件**：`uya-src/arena.uya`

- [ ] 翻译 `Arena` 结构体：
  - [ ] `data` 字段：固定大小字节数组（`[byte: N]`）
  - [ ] `size` 字段：总大小（`i32`）
  - [ ] `offset` 字段：当前偏移（`i32`）

**类型映射**：
- `uint8_t *` → `&byte` 或 `[byte: N]`
- `size_t` → `i32`

---

### 任务 1.3：翻译 Arena 函数

- [ ] 翻译 `arena_init` 函数：
  - [ ] 初始化 Arena 结构体
  - [ ] 设置初始值
- [ ] 翻译 `arena_alloc` 函数：
  - [ ] 内存对齐处理
  - [ ] 分配内存（返回指针）
  - [ ] 更新偏移量
  - [ ] 边界检查（可选，但推荐）
- [ ] 翻译 `arena_reset` 函数：
  - [ ] 重置 Arena 到初始状态

**注意**：
- 使用 Uya Mini 的指针类型（`&T`）
- 使用 `as` 关键字进行类型转换
- 保持与 C99 版本功能完全一致

---

### 任务 1.4：添加中文注释

- [ ] 为所有结构体添加中文注释
- [ ] 为所有函数添加中文注释
- [ ] 为关键逻辑添加中文注释

---

### 任务 1.5：验证功能

- [ ] 创建简单的测试程序（`uya-src/test_arena.uya`）：
  - [ ] 测试 Arena 初始化
  - [ ] 测试内存分配
  - [ ] 测试内存对齐
  - [ ] 测试 Arena 重置
- [ ] 使用 C99 编译器编译测试程序
- [ ] 运行测试程序验证功能正确性

**参考**：`tests/test_arena.c` - 现有的 C99 测试程序

---

## 完成标准

- [ ] `arena.uya` 已创建，包含完整的 Arena 实现
- [ ] 所有结构体已翻译
- [ ] 所有函数已翻译
- [ ] 所有代码使用中文注释
- [ ] 功能与 C99 版本完全一致
- [ ] 测试程序通过
- [ ] 已更新 `PROGRESS.md`，标记阶段1为完成

---

## 参考文档

- `src/arena.h` - C99 版本的 Arena 接口
- `src/arena.c` - C99 版本的 Arena 实现
- `tests/test_arena.c` - Arena 测试程序
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范
- `BOOTSTRAP_PLAN.md` - 类型映射规则

---

## 注意事项

1. **无堆分配**：Arena 分配器本身不使用堆分配，使用固定大小的缓冲区
2. **类型转换**：使用 `as` 关键字进行指针类型转换
3. **对齐处理**：保持与 C99 版本相同的对齐逻辑
4. **边界检查**：虽然 C99 版本可能没有边界检查，但建议添加（提高安全性）

---

## C99 → Uya Mini 映射示例

```c
// C99
typedef struct {
    uint8_t *data;
    size_t size;
    size_t offset;
} Arena;

void *arena_alloc(Arena *arena, size_t size) {
    // ...
}

// Uya Mini
struct Arena {
    data: &byte;  // 或使用 [byte: N] 数组
    size: i32;
    offset: i32;
}

fn arena_alloc(arena: &Arena, size: i32) &void {
    // ...
}
```

