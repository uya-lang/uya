# 阶段3：词法分析器

## 概述

翻译词法分析器（Lexer）模块，Parser 依赖它。

**优先级**：P0

**工作量估算**：3-4 小时

**依赖**：阶段0（准备工作 - str_utils.uya）、阶段1（Arena）、阶段2（AST）

**原因**：Parser 依赖 Lexer。

---

## 任务列表

### 任务 3.1：阅读和理解 C99 代码

- [ ] 阅读 `src/lexer.h` - 理解 Lexer 接口
- [ ] 阅读 `src/lexer.c` - 理解 Lexer 实现
- [ ] 理解词法分析的工作原理：
  - [ ] 状态机逻辑
  - [ ] 字符读取和缓冲
  - [ ] Token 类型识别
  - [ ] 关键字匹配
  - [ ] 标识符识别
  - [ ] 数字字面量解析
  - [ ] 字符串字面量解析（如果有）

**参考**：代码量中等（465行），状态机逻辑相对简单

---

### 任务 3.2：翻译 Lexer 结构体定义

**文件**：`uya-src/lexer.uya`

- [ ] 翻译 `Lexer` 结构体：
  - [ ] 源代码相关字段（`source`, `source_len` 等）
  - [ ] 当前位置字段（`pos`, `line`, `col` 等）
  - [ ] 当前 Token 字段（`current_token` 等）
  - [ ] Arena 分配器字段（如果需要）

**类型映射**：
- `const char *` → `*byte`（extern 函数参数）或 `&byte`
- `char *` → `&byte`
- `int` → `i32`
- `size_t` → `i32`

---

### 任务 3.3：翻译 Lexer 函数

- [ ] 翻译 `lexer_init` 函数：
  - [ ] 初始化 Lexer 结构体
  - [ ] 设置初始值
- [ ] 翻译 `lexer_next_token` 函数：
  - [ ] 跳过空白字符
  - [ ] 识别各种 Token 类型
  - [ ] 处理关键字（使用 `strcmp` 或 `str_utils.uya` 中的函数）
  - [ ] 处理标识符
  - [ ] 处理数字字面量
  - [ ] 处理运算符和分隔符
  - [ ] 处理字符串字面量（如果有）
- [ ] 翻译辅助函数：
  - [ ] `is_keyword` - 关键字判断（使用 `strcmp`）
  - [ ] `read_char` - 读取字符
  - [ ] `peek_char` - 查看下一个字符
  - [ ] `skip_whitespace` - 跳过空白字符
  - [ ] `read_number` - 读取数字
  - [ ] `read_identifier` - 读取标识符
  - [ ] 其他辅助函数

**关键挑战**：
- 字符串处理：使用 `str_utils.uya` 中的封装函数（`strcmp`, `strlen` 等）
- 关键字匹配：使用 `strcmp` 进行字符串比较
- 字符操作：使用字节数组和索引

---

### 任务 3.4：使用字符串辅助函数

- [ ] 在 `lexer.uya` 中包含或引用 `str_utils.uya` 的声明
- [ ] 将所有字符串比较操作改为使用 `strcmp` 或 `str_equals`
- [ ] 将所有字符串长度操作改为使用 `strlen` 或 `str_length`
- [ ] 确保所有字符串字面量作为 `*byte` 类型传递给 `extern` 函数

---

### 任务 3.5：添加中文注释

- [ ] 为所有结构体添加中文注释
- [ ] 为所有函数添加中文注释
- [ ] 为关键逻辑添加中文注释
- [ ] 为状态机逻辑添加中文注释

---

### 任务 3.6：验证功能

- [ ] 创建简单的测试程序（`uya-src/test_lexer.uya`）：
  - [ ] 测试各种 Token 类型识别
  - [ ] 测试关键字识别
  - [ ] 测试标识符识别
  - [ ] 测试数字字面量解析
  - [ ] 测试运算符和分隔符识别
- [ ] 使用 C99 编译器编译测试程序
- [ ] 运行测试程序验证功能正确性

**参考**：`tests/test_lexer.c` - 现有的 C99 测试程序

---

## 完成标准

- [ ] `lexer.uya` 已创建，包含完整的 Lexer 实现
- [ ] 所有结构体已翻译
- [ ] 所有函数已翻译
- [ ] 使用 `str_utils.uya` 中的字符串函数
- [ ] 所有代码使用中文注释
- [ ] 功能与 C99 版本完全一致
- [ ] 测试程序通过
- [ ] 已更新 `PROGRESS.md`，标记阶段3为完成

---

## 参考文档

- `src/lexer.h` - C99 版本的 Lexer 接口
- `src/lexer.c` - C99 版本的 Lexer 实现
- `tests/test_lexer.c` - Lexer 测试程序
- `uya-src/str_utils.uya` - 字符串辅助函数模块
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范，确认 Token 类型
- `BOOTSTRAP_PLAN.md` - 字符串处理策略

---

## 注意事项

1. **字符串处理**：必须使用 `str_utils.uya` 中的封装函数，不能直接操作字符串
2. **关键字匹配**：使用 `strcmp` 进行关键字匹配，不能使用字面量比较
3. **字符编码**：确保字符处理与 C99 版本一致（ASCII）
4. **错误处理**：保持与 C99 版本相同的错误处理逻辑

---

## C99 → Uya Mini 映射示例

```c
// C99
typedef struct {
    const char *source;
    size_t source_len;
    size_t pos;
    int line;
    int col;
    Token current_token;
} Lexer;

bool is_keyword(const char *str) {
    if (strcmp(str, "fn") == 0) return true;
    if (strcmp(str, "if") == 0) return true;
    // ...
    return false;
}

// Uya Mini
struct Lexer {
    source: *byte;  // extern 函数参数
    source_len: i32;
    pos: i32;
    line: i32;
    col: i32;
    current_token: Token;
}

fn is_keyword(str: *byte) bool {
    if strcmp(str, "fn") == 0 {
        return true;
    }
    if strcmp(str, "if") == 0 {
        return true;
    }
    // ...
    return false;
}
```

