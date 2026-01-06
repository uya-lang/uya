# 错误码冲突检测测试用例

## 测试用例1: 正常情况（无冲突）

### 文件: `tests/test_error_collision.uya`

```uya
fn test_file_operations() !i32 {
    return error.FileNotFound;
}

fn test_math_operations() !i32 {
    return error.DivisionByZero;
}

fn test_network_operations() !i32 {
    return error.NetworkError;
}

fn test_permission_operations() !i32 {
    return error.PermissionDenied;
}

fn test_validation() !i32 {
    return error.InvalidInput;
}

fn test_memory() !i32 {
    return error.OutOfMemory;
}
```

### 预期结果
- ✅ 编译成功
- ✅ 所有错误名称生成不同的错误码
- ✅ 无冲突报告

## 测试用例2: 手动测试（可能冲突）

### 文件: `tests/test_collision_manual.uya`

```uya
fn test1() !i32 {
    return error.TestError;
}

fn test2() !i32 {
    return error.TestErr;  // 可能与 TestError 冲突
}

fn test3() !i32 {
    return error.Error1;
}

fn test4() !i32 {
    return error.Error2;  // 可能与 Error1 冲突
}
```

### 预期结果
- 如果无冲突：编译成功
- 如果有冲突：显示详细的冲突报告

## 测试用例3: 强制冲突测试（需要修改编译器）

为了测试冲突检测功能，可以临时修改编译器代码：

### 方法1: 修改哈希函数

在 `codegen.c` 中临时修改 `hash_error_name` 函数：

```c
static uint32_t hash_error_name(const char *error_name) {
    // 临时测试：让所有错误都返回相同的错误码
    if (strcmp(error_name, "TestError") == 0 || 
        strcmp(error_name, "AnotherError") == 0) {
        return 1234567890U;  // 强制冲突
    }
    // ... 正常哈希逻辑 ...
}
```

### 方法2: 使用已知冲突的字符串对

通过暴力搜索找到会产生冲突的字符串对（如果存在）。

## 测试冲突检测的输出

当检测到冲突时，编译器会输出：

```
编译失败: 发现 1 个错误码冲突
请重命名冲突的错误名称以避免冲突

═══════════════════════════════════════════════════════════
错误: 错误码冲突！
═══════════════════════════════════════════════════════════

  冲突的错误名称:
    • error.TestError
    • error.AnotherError

  冲突的错误码: 1234567890U

  解决方案:
    请重命名其中一个错误名称以避免冲突。

  建议的重命名方案:
    方案1: 将 error.TestError 重命名为 error.TestError_Alt
    方案2: 将 error.AnotherError 重命名为 error.AnotherError_Alt

  其他建议:
    • 使用更具体、更具描述性的错误名称
    • 避免使用相似的错误名称（如 TestError 和 TestErr）
    • 考虑使用命名空间或前缀来区分不同类型的错误

═══════════════════════════════════════════════════════════
```

## 运行测试

```bash
# 测试正常情况
./uyac tests/test_error_collision.uya test_output.c

# 测试可能冲突的情况
./uyac tests/test_collision_manual.uya test_output.c

# 如果发现冲突，编译器会显示详细的错误信息
```

## 验证冲突检测功能

1. **编译测试用例**：运行上述测试用例
2. **检查输出**：如果无冲突，编译成功；如果有冲突，显示详细错误信息
3. **验证错误信息**：确认错误信息包含所有必要信息（冲突名称、错误码、建议等）

## 注意事项

- 由于哈希函数的特性，实际冲突很难构造
- 冲突概率对于大多数项目（< 10,000 个错误）极低（< 1%）
- 如果确实需要测试冲突检测，可以临时修改编译器代码强制产生冲突
