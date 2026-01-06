# 错误码稳定性分析

## 问题：编译期枚举方案的稳定性问题

### 问题描述

使用**编译期枚举方案**（按字母序排序后分配递增错误码）时，添加或删除错误会导致错误码发生变化。

### 示例

#### 初始状态
```uya
fn test1() !i32 { return error.Apple; }    // error_id = 1
fn test2() !i32 { return error.Banana; }   // error_id = 2
fn test3() !i32 { return error.Cherry; }   // error_id = 3
```

#### 添加新错误后
```uya
fn test1() !i32 { return error.Aardvark; } // error_id = 1 (新)
fn test2() !i32 { return error.Apple; }    // error_id = 2 (变了！原来是1)
fn test3() !i32 { return error.Banana; }   // error_id = 3 (变了！原来是2)
fn test4() !i32 { return error.Cherry; }   // error_id = 4 (变了！原来是3)
```

#### 删除错误后
```uya
fn test1() !i32 { return error.Apple; }    // error_id = 1 (变了！原来是2)
fn test2() !i32 { return error.Cherry; }  // error_id = 2 (变了！原来是4)
```

### 影响

1. **二进制兼容性问题**：如果错误码用于跨模块通信或序列化，错误码变化会导致不兼容
2. **调试困难**：错误码变化使得日志和错误追踪变得困难
3. **版本控制问题**：不同版本的代码生成不同的错误码

## 解决方案：哈希函数方案

### 优势

✅ **稳定性**：相同错误名称总是生成相同的错误码，不受其他错误影响

### 示例

#### 初始状态
```uya
fn test1() !i32 { return error.Apple; }    // error_id = 63476538U
fn test2() !i32 { return error.Banana; }   // error_id = 1982479237U
fn test3() !i32 { return error.Cherry; }   // error_id = 2017321401U
```

#### 添加新错误后
```uya
fn test1() !i32 { return error.Aardvark; } // error_id = 866753430U (新)
fn test2() !i32 { return error.Apple; }    // error_id = 63476538U (不变！)
fn test3() !i32 { return error.Banana; }   // error_id = 1982479237U (不变！)
fn test4() !i32 { return error.Cherry; }   // error_id = 2017321401U (不变！)
```

#### 删除错误后
```uya
fn test1() !i32 { return error.Apple; }    // error_id = 63476538U (不变！)
fn test2() !i32 { return error.Cherry; }   // error_id = 2017321401U (不变！)
```

## 方案对比

| 特性 | 编译期枚举 | 哈希函数 |
|------|-----------|---------|
| **稳定性** | ❌ 不稳定（添加/删除错误会改变错误码） | ✅ **稳定**（不受其他错误影响） |
| **冲突率** | ✅ 0%（保证无冲突） | ⚠️ 低（<1% for <10K errors） |
| **可预测性** | ✅ 高（按字母序） | ⚠️ 中（需要计算） |
| **二进制兼容性** | ❌ 差 | ✅ **好** |
| **调试友好性** | ❌ 差（错误码会变化） | ✅ **好**（错误码固定） |

## 结论

**哈希函数方案更适合实际使用**，因为：

1. ✅ **稳定性最重要**：错误码不应该因为添加/删除其他错误而改变
2. ✅ **二进制兼容性**：保证跨版本、跨模块的兼容性
3. ✅ **调试友好**：错误码固定，便于日志分析和错误追踪
4. ⚠️ **冲突率可接受**：对于大多数项目（< 10,000 个错误），冲突概率 < 1%

### 推荐方案

**使用哈希函数生成错误码**，确保：
- 相同错误名称总是生成相同的错误码
- 添加或删除其他错误不会影响现有错误的错误码
- 保证二进制兼容性和调试友好性
