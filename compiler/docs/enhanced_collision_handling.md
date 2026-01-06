# 增强的错误码冲突处理

## ✅ 已实现的增强功能

### 1. 详细的错误信息

当检测到冲突时，编译器会输出详细的错误信息，包括：

- **冲突的错误名称**：明确指出哪些错误冲突
- **冲突的错误码**：显示冲突的错误码值
- **解决方案**：说明需要重命名错误名称
- **建议的重命名方案**：提供具体的重命名建议
- **其他建议**：提供最佳实践建议

### 2. 错误信息示例

```
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

### 3. 重命名建议算法

当前实现提供简单的重命名建议（添加 "_Alt" 后缀），可以扩展为：

- **方案1**: 添加后缀 `_Alt`
- **方案2**: 添加数字后缀 `_2`, `_3`, ...
- **方案3**: 使用更描述性的名称（需要上下文信息）

### 4. 实现代码

```c
// 生成建议的重命名方案
static void suggest_rename(const char *original_name, char *suggestion, size_t max_len) {
    if (!original_name || !suggestion || max_len == 0) return;
    
    // 方案1: 添加后缀 "_Alt"
    snprintf(suggestion, max_len, "%s_Alt", original_name);
}

// 检测错误码冲突并报告
static int detect_error_code_collisions(CodeGenerator *codegen) {
    // ... 检测冲突 ...
    
    if (code_i == code_j) {
        // 输出详细的错误信息和建议
        fprintf(stderr, "错误: 错误码冲突！\n");
        fprintf(stderr, "  冲突的错误名称:\n");
        fprintf(stderr, "    • error.%s\n", name1);
        fprintf(stderr, "    • error.%s\n", name2);
        fprintf(stderr, "  建议的重命名方案:\n");
        // ... 提供重命名建议 ...
    }
}
```

## 优势

1. ✅ **清晰的错误信息**：用户一眼就能看出问题所在
2. ✅ **具体的修改建议**：提供重命名方案，减少用户思考时间
3. ✅ **最佳实践指导**：帮助用户避免未来冲突
4. ✅ **友好的用户体验**：格式化的输出，易于阅读

## 使用示例

### 场景：发现冲突

```uya
fn test1() !i32 {
    return error.TestError;  // 假设与另一个错误冲突
}

fn test2() !i32 {
    return error.AnotherError;  // 假设与 TestError 冲突
}
```

### 编译器输出

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

### 用户操作

用户根据建议，选择重命名其中一个错误：

```uya
fn test1() !i32 {
    return error.TestError_Alt;  // 重命名后
}

fn test2() !i32 {
    return error.AnotherError;  // 保持不变
}
```

## 总结

✅ **增强的错误提示已实现**：提供详细的错误信息和具体的修改建议
✅ **用户友好**：清晰的格式和具体的操作指导
✅ **最佳实践**：帮助用户避免未来冲突
