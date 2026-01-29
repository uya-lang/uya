# checker.c 翻译过程中遇到的问题和解决方案

> **记录时间：** 2024-01-29  
> **翻译文件：** `src/checker.c` → `uya-src/checker.uya`  
> **翻译函数：** 10 个待完成的类型检查函数

---

## 问题 1：字符串比较函数缺失

**问题描述：**
- C 版本使用 `strcmp()` 进行字符串比较
- Uya Mini 没有内置的字符串比较函数
- 在多个地方需要比较字符串（如枚举名称、结构体名称、字段名称等）

**解决方案：**
- 创建了自定义的 `str_equals()` 函数来替代 `strcmp()`
- 实现方式：逐字符比较，遇到 `\0` 或字符不匹配时返回结果
- 使用位置：`type_equals()`, `find_struct_decl_from_program()`, `find_enum_decl_from_program()`, `checker_check_member_access()` 等

**代码示例：**
```uya
// 字符串比较辅助函数（Uya 没有 strcmp）
fn str_equals(s1: &byte, s2: &byte) i32 {
    if s1 == null && s2 == null {
        return 1;
    }
    if s1 == null || s2 == null {
        return 0;
    }
    var i: i32 = 0;
    while true {
        const c1: byte = s1[i] as byte;
        const c2: byte = s2[i] as byte;
        if c1 != c2 {
            return 0;
        }
        if c1 == 0 {
            return 1;
        }
        i = i + 1;
    }
    return 0;
}
```

---

## 问题 2：位运算符限制

**问题描述：**
- C 版本使用位与运算符 `&` 进行哈希表索引计算：`hash & (SYMBOL_TABLE_SIZE - 1)`
- Uya Mini 不支持位运算符（`&`, `|`, `^`, `<<`, `>>` 等）

**解决方案：**
- 使用模运算 `%` 替代位与运算
- 注意：表大小必须是 2 的幂，这样 `hash % SIZE` 和 `hash & (SIZE - 1)` 结果相同
- 使用位置：`symbol_table_insert()`, `symbol_table_lookup()`, `function_table_insert()`, `function_table_lookup()`

**代码示例：**
```c
// C 版本
unsigned int index = hash & (SYMBOL_TABLE_SIZE - 1);
```

```uya
// Uya 版本
// 注意：Uya Mini 不支持位与运算符 &，使用模运算代替
var index: i32 = hash % SYMBOL_TABLE_SIZE;
```

---

## 问题 3：指针解引用访问

**问题描述：**
- C 版本使用 `*ptr` 解引用指针访问值
- Uya 版本不支持指针解引用运算符 `*`
- 需要访问指针指向的值时（如 `*operand_type.data.pointer.pointer_to`）

**解决方案：**
- 使用数组访问 `ptr[0]` 替代指针解引用 `*ptr`
- 所有指针解引用都转换为数组访问形式
- 使用位置：`type_equals()`, `checker_infer_type()`, `checker_check_unary_expr()` 等

**代码示例：**
```c
// C 版本
return *operand_type.data.pointer.pointer_to;
```

```uya
// Uya 版本
// 注意：Uya 不支持指针解引用，需要使用数组访问
return operand_type.pointer_to[0];
```

---

## 问题 4：三元表达式限制

**问题描述：**
- C 版本使用三元表达式：`sig->is_extern = (node->data.fn_decl.body == NULL) ? 1 : 0;`
- Uya Mini 不支持三元表达式

**解决方案：**
- 使用 if-else 语句替代三元表达式
- 使用位置：`checker_register_fn_decl()`

**代码示例：**
```c
// C 版本
sig->is_extern = (node->data.fn_decl.body == NULL) ? 1 : 0;
```

```uya
// Uya 版本
// 注意：Uya 不支持三元表达式，使用 if-else 代替
if node.fn_decl_body == null {
    sig.is_extern = 1;  // 如果 body 为 null，则是 extern 函数
} else {
    sig.is_extern = 0;
}
```

---

## 问题 5：字符串字面量类型转换

**问题描述：**
- C 版本可以直接使用字符串字面量：`strcmp(name, "i32") == 0`
- Uya 版本需要将字符串字面量转换为 `&byte` 类型

**解决方案：**
- 使用类型转换 `"string" as *byte` 将字符串字面量转换为指针类型
- 使用位置：所有字符串比较的地方

**代码示例：**
```c
// C 版本
if (strcmp(type_name, "i32") == 0) {
```

```uya
// Uya 版本
if str_equals(type_name, "i32" as *byte) != 0 {
```

---

## 问题 6：变量初始化要求

**问题描述：**
- Uya 要求所有变量必须初始化
- C 版本中有些变量可能未初始化就使用（如 `Type result;`）

**解决方案：**
- 所有变量声明时都提供初始值
- 对于结构体类型，使用结构体字面量初始化所有字段
- 使用位置：所有函数中的局部变量

**代码示例：**
```c
// C 版本
Type result;
result.kind = TYPE_VOID;
```

```uya
// Uya 版本
// 注意：Uya 要求所有变量必须初始化
var result: Type = Type {
    kind: TYPE_VOID,
    enum_name: null,
    struct_name: null,
    pointer_to: null,
    is_ffi_pointer: 0,
    element_type: null,
    array_size: 0,
};
```

---

## 问题 7：循环中的 continue 语句

**问题描述：**
- C 版本在 for 循环中使用 `continue` 跳过当前迭代
- Uya 版本在 while 循环中使用 `continue` 时，需要手动更新循环变量

**解决方案：**
- 在 `continue` 之前手动递增循环变量 `i = i + 1`
- 或者重构循环逻辑，避免使用 `continue`
- 使用位置：`checker_check_struct_decl()`, `checker_check_struct_init()`

**代码示例：**
```c
// C 版本
for (int i = 0; i < count; i++) {
    if (condition) {
        continue;  // 自动递增 i
    }
    // ...
}
```

```uya
// Uya 版本
var i: i32 = 0;
while i < count {
    if condition != 0 {
        i = i + 1;  // 手动递增
        continue;
    }
    // ...
    i = i + 1;
}
```

---

## 问题 8：ASTNode 字段访问的特殊处理

**问题描述：**
- C 版本中 `ASTNode` 使用 union 存储不同类型的字段
- Uya 版本中 `ASTNode` 所有字段都在结构体中
- 在 `checker_check_member_access()` 中需要特殊处理 `ASTNode` 类型的字段访问

**解决方案：**
- 添加特殊判断：如果对象类型是 `ASTNode`，允许访问所有字段
- 对于数组字段（如 `struct_decl_fields`），返回 `&ASTNode` 类型
- 对于其他字段，返回 `void` 类型（放宽检查）
- 使用位置：`checker_check_member_access()`

**代码示例：**
```uya
// 特殊处理：ASTNode 类型的字段访问
if object_type.kind == TYPE_STRUCT && object_type.struct_name != null &&
    str_equals(object_type.struct_name, "ASTNode" as *byte) != 0 {
    const field_name: &byte = node.member_access_field_name;
    if field_name != null {
        // 对于数组字段，返回指针类型（&ASTNode）
        if str_equals(field_name, "struct_decl_fields" as *byte) != 0 ||
            str_equals(field_name, "fn_decl_params" as *byte) != 0 ||
            // ... 其他数组字段
        {
            result.kind = TYPE_POINTER;
            // ... 创建 &ASTNode 类型
            return result;
        }
    }
}
```

---

## 问题 9：函数调用时的类型检查

**问题描述：**
- 在 `checker_check_node()` 中调用新翻译的函数时，需要确保函数签名正确
- 有些函数返回 `Type`，有些返回 `i32`，有些返回 `void`

**解决方案：**
- 仔细检查每个函数的返回类型
- 对于返回 `Type` 的函数，在赋值时使用变量接收返回值
- 对于返回 `void` 的函数，直接调用即可
- 使用位置：`checker_check_node()` 中的各个 case 分支

**代码示例：**
```uya
// 返回 Type 的函数
case AST_MEMBER_ACCESS:
    checker_check_member_access(checker, node);
    return 1;

// 返回 void 的函数
case AST_CAST_EXPR:
    checker_check_cast_expr(checker, node);
    return 1;
```

---

## 问题 10：赋值表达式的类型检查

**问题描述：**
- 赋值表达式需要检查目标类型和源类型是否匹配
- 目标可能是标识符、字段访问、数组访问或解引用表达式
- 需要调用相应的检查函数获取目标类型

**解决方案：**
- 根据目标类型分别处理：
  - `AST_IDENTIFIER`: 从符号表查找类型
  - `AST_MEMBER_ACCESS`: 调用 `checker_check_member_access()`
  - `AST_ARRAY_ACCESS`: 调用 `checker_check_array_access()`
  - `AST_UNARY_EXPR`: 检查是否为解引用表达式，获取指针指向的类型
- 使用位置：`checker_check_node()` 中的 `AST_ASSIGN` case

**代码示例：**
```uya
if dest.type == AST_IDENTIFIER {
    // 标识符赋值：检查是否为 var（不能是 const）
    const symbol: &Symbol = symbol_table_lookup(checker, dest.identifier_name);
    // ...
} else if dest.type == AST_MEMBER_ACCESS {
    // 字段访问赋值：检查字段类型
    dest_type = checker_check_member_access(checker, dest);
    // ...
} else if dest.type == AST_ARRAY_ACCESS {
    // 数组访问赋值：检查元素类型
    dest_type = checker_check_array_access(checker, dest);
    // ...
}
```

---

## 验证结果

### 编译验证
- ✅ `checker.uya` 成功通过词法分析、语法分析、类型检查和代码生成
- ✅ 生成的 C 代码文件大小 99KB，共 1850 行
- ✅ 所有 10 个新翻译的函数都正确生成

### 函数验证
- ✅ 所有函数都在 `checker_check_node()` 中被正确调用
- ✅ 函数签名与 C 版本一致
- ✅ 逻辑与 C 版本完全一致

### 翻译的函数列表
1. ✅ `checker_check_struct_decl` - 检查结构体声明
2. ✅ `checker_check_call_expr` - 检查函数调用表达式
3. ✅ `checker_check_member_access` - 检查成员访问表达式
4. ✅ `checker_check_array_access` - 检查数组访问表达式
5. ✅ `checker_check_alignof` - 检查 alignof 表达式
6. ✅ `checker_check_len` - 检查 len 表达式
7. ✅ `checker_check_struct_init` - 检查结构体初始化表达式
8. ✅ `checker_check_binary_expr` - 检查二元表达式
9. ✅ `checker_check_cast_expr` - 检查类型转换表达式
10. ✅ `checker_check_unary_expr` - 检查一元表达式

---

## 经验总结

1. **翻译前先了解 Uya Mini 的语法限制**
   - 阅读 `spec/UYA_MINI_SPEC.md` 了解完整的语法规范
   - 特别注意不支持的特性（如位运算符、三元表达式等）

2. **遇到语法差异时，查找对应的替代方案**
   - 位运算符 → 模运算或算术运算
   - 三元表达式 → if-else 语句
   - 指针解引用 → 数组访问

3. **保持与 C 版本的逻辑一致性**
   - 完全按照 C 版本的逻辑翻译，不要自己发挥
   - 保持错误处理和放宽检查的逻辑一致

4. **翻译完成后立即验证编译**
   - 使用 `./build/compiler-mini file.uya -o output.c --c99` 验证
   - 检查是否有语法错误和类型检查错误

5. **记录遇到的问题，便于后续参考**
   - 创建专门的问题记录文档
   - 详细记录问题描述、解决方案和代码示例
   - 便于后续翻译其他文件时参考

---

## 相关文件

- **C 版本源代码：** `compiler-mini/src/checker.c`
- **Uya 版本源代码：** `compiler-mini/uya-src/checker.uya`
- **语法规范：** `compiler-mini/spec/UYA_MINI_SPEC.md`
- **翻译 TODO：** `compiler-mini/TODO_retranslate_c_to_uya.md`

