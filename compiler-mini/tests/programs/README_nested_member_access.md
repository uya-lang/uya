# 嵌套字段访问测试用例说明

## 问题描述

在编译 `arena.uya` 等文件时，遇到以下错误：
- `错误: 无法确定结构体名称 /media/winger/_dde_home/winger/uya/compiler-mini/uya-src/arena.uya(83:29) (字段: type)`
- `错误: 二元表达式左操作数生成失败`

这些错误发生在处理嵌套字段访问时，例如：
- `parser.current_token.type` - 访问 `Parser` 结构体的 `current_token` 字段（类型为 `&Token`），然后访问 `Token` 结构体的 `type` 字段

## 根本原因

代码生成器在处理嵌套字段访问（`AST_MEMBER_ACCESS`）时，当对象是指针类型时，无法正确识别指向的结构体类型。

具体场景：
1. `parser` 是 `&Parser` 类型的变量
2. `parser.current_token` 返回 `&Token` 类型（指针）
3. `parser.current_token.type` 需要访问 `Token` 结构体的 `type` 字段

代码生成器在处理 `parser.current_token` 时，识别出返回的是指针类型，但无法从指针类型中获取指向的结构体类型名称（`Token`）。

## 修复方案

在 `compiler-mini/src/codegen.c` 中修复了嵌套字段访问的处理逻辑：

1. **添加了 `find_struct_field_ast_type` 函数**：
   - 用于从结构体声明中查找字段的 AST 类型节点
   - 支持获取字段的类型信息（包括指针类型）

2. **改进了嵌套字段访问的处理**：
   - 当对象是指针类型时，尝试从嵌套字段访问的 AST 中获取类型信息
   - 从变量表中查找外层变量的类型（如 `parser` 的类型 `&Parser`）
   - 查找外层结构体声明（`Parser`）
   - 查找字段的类型（`current_token` 的类型 `&Token`）
   - 从字段类型中提取指向的结构体类型名称（`Token`）

## 测试用例

### `test_nested_member_access.uya`
测试嵌套字段访问的各种场景：
- `parser.current_token.type` - 访问枚举字段
- `parser.current_token.line` - 访问整数字段
- `parser.current_token.column` - 访问整数字段
- `parser.arena.size` - 访问嵌套结构体字段
- `parser.arena.offset` - 访问嵌套结构体字段

## 验证

修复后：
- ✅ `test_nested_member_access.uya` 编译成功
- ✅ 之前的"无法确定结构体名称"错误已解决
- ✅ 嵌套字段访问的类型检查和代码生成正常工作

## 相关文件

- `compiler-mini/src/codegen.c` - 代码生成器修复
- `compiler-mini/tests/programs/test_nested_member_access.uya` - 测试用例

