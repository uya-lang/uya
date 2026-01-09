# 预定义错误声明测试验证

## 测试目的

验证预定义错误声明的实现符合Uya语言设计：**只有被使用的错误才会生成错误码**。

## 测试用例

### 测试1: 只有部分预定义错误被使用

**文件**: `test_error_decl_only_used.uya`

```uya
error FileNotFound;
error DivisionByZero;  // 声明但未使用

fn main() !i32 {
    return error.FileNotFound;  // 只使用FileNotFound
}
```

**验证结果**:
- ✓ 只有1个错误码生成（FileNotFound: 449591851U）
- ✓ DivisionByZero虽然声明了但未使用，没有在生成的C代码中出现
- ✓ 错误名称不会作为标识符出现在生成的代码中，只有错误码

### 测试2: 所有预定义错误都被使用

**文件**: `test_error_decl_all_used.uya`

```uya
error FileNotFound;
error DivisionByZero;

fn test1() !i32 {
    return error.FileNotFound;
}

fn test2() !i32 {
    return error.DivisionByZero;
}

fn main() i32 {
    return 0;
}
```

**验证结果**:
- ✓ 生成了2个不同的错误码
  - FileNotFound: 449591851U
  - DivisionByZero: 979988172U
- ✓ 两个错误都被使用时，都正确生成错误码
- ✓ 错误名称不会作为标识符出现在生成的代码中

### 测试3: 预定义错误和运行时错误混合使用

**文件**: `test_error_decl_mixed.uya`

```uya
error FileNotFound;  // 预定义错误
// DivisionByZero 未声明，但会在使用时自动创建（运行时错误）

fn test1() !i32 {
    return error.FileNotFound;  // 使用预定义错误
}

fn test2() !i32 {
    return error.DivisionByZero;  // 使用运行时错误（未预定义）
}

fn main() i32 {
    return 0;
}
```

**验证结果**:
- ✓ 预定义错误（FileNotFound）正确生成错误码: 449591851U
- ✓ 运行时错误（DivisionByZero）也正确生成错误码: 979988172U
- ✓ 预定义错误和运行时错误使用相同的错误码生成机制（哈希函数）
- ✓ 两者可以混合使用，行为一致

## 测试结论

所有测试通过，验证了以下设计特性：

1. ✅ **只有被使用的错误生成错误码**：预定义错误声明只是声明错误名称，只有在实际使用时（通过 `error.ErrorName`）才会生成错误码

2. ✅ **预定义错误声明的作用**：预定义错误声明用于：
   - 声明错误名称，使其在类型检查时被识别
   - 验证错误名称的唯一性（全局命名空间）
   - 提供编译期错误检查

3. ✅ **预定义错误和运行时错误一致性**：两者使用相同的错误码生成机制，行为一致

4. ✅ **代码生成优化**：未使用的错误不会出现在生成的代码中，减少代码体积

## 实现符合Uya语言规范

根据 `uya.md` 规范：
- 预定义错误类型是编译期常量，用于标识不同的错误情况
- 错误码在编译时通过哈希函数生成
- 只有被使用的错误才会在代码中生成错误码

当前实现完全符合规范要求。

