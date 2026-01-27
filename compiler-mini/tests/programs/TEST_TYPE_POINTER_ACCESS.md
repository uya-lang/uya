# 指针类型访问测试用例

本目录包含专门测试指针类型成员访问的测试用例，主要用于验证 C99 代码生成器是否正确生成 `->` 操作符。

## 测试用例列表

### 1. test_pointer_member_access.uya
测试指针类型参数的成员访问：
- 单层指针访问（`rect.top_left.x` 应该生成 `rect->top_left.x`）
- 嵌套指针访问（`parser.codegen.count` 应该生成 `parser->codegen->count`）
- 指针类型作为结构体字段的访问

### 2. test_type_conversion_pointer.uya
测试指针类型转换和类型推断：
- 指针类型转换
- 空指针处理
- 指针类型推断

### 3. test_c99_pointer_access.uya
专门测试 C99 代码生成器中的指针访问：
- 函数参数为指针类型时的成员访问
- 嵌套指针访问
- 局部指针变量访问
- 结构体中的指针字段访问

## 验证要点

生成的 C 代码应该：
1. 指针类型参数使用 `->` 操作符访问成员
2. 非指针类型使用 `.` 操作符访问成员
3. 嵌套指针访问正确使用 `->` 链式访问

## 运行测试

使用 C99 后端编译测试用例：
```bash
./build/compiler-mini tests/programs/test_c99_pointer_access.uya -o test.c --c99
```

检查生成的 C 代码中是否正确使用了 `->` 操作符：
```bash
grep "codegen->count\|parser->codegen" test.c
```

