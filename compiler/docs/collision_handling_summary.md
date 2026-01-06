# 错误码冲突处理方案

## 问题

使用哈希函数生成错误码时，虽然冲突概率很低（< 1% for < 10,000 个错误），但仍有可能发生冲突。

## 解决方案：编译期冲突检测

### 实现机制

1. **收集阶段**：在代码生成时，遍历所有 IR 指令，收集所有 `IR_ERROR_VALUE` 中的错误名称
2. **计算阶段**：为每个错误名称计算哈希值（错误码）
3. **检测阶段**：检查所有错误名称对，如果发现相同的错误码，报告冲突
4. **处理阶段**：如果发现冲突，编译失败，提示用户重命名错误名称

### 冲突检测代码

```c
// 检测错误码冲突并报告
static int detect_error_code_collisions(CodeGenerator *codegen) {
    // 检查所有错误名称对
    for (int i = 0; i < codegen->error_map_size; i++) {
        uint32_t code_i = codegen->error_map[i].error_code;
        for (int j = i + 1; j < codegen->error_map_size; j++) {
            uint32_t code_j = codegen->error_map[j].error_code;
            if (code_i == code_j) {
                // 发现冲突，报告错误
                fprintf(stderr, "错误: 错误码冲突！\n");
                fprintf(stderr, "  error.%s 和 error.%s 都生成了错误码 %uU\n",
                        codegen->error_map[i].error_name,
                        codegen->error_map[j].error_name,
                        code_i);
                fprintf(stderr, "  建议: 重命名其中一个错误名称以避免冲突\n");
                return 1; // 发现冲突
            }
        }
    }
    return 0; // 无冲突
}
```

### 错误信息示例

当发现冲突时，编译器会输出：

```
错误: 错误码冲突！
  error.TestError 和 error.AnotherError 都生成了错误码 1234567890U
  建议: 重命名其中一个错误名称以避免冲突

编译失败: 发现 1 个错误码冲突
请重命名冲突的错误名称以避免冲突
```

## 处理策略

### 策略1：编译期检测 + 用户重命名（当前实现）

**优点**：
- ✅ 简单直接
- ✅ 保证无冲突
- ✅ 用户控制错误名称

**缺点**：
- ⚠️ 需要用户手动重命名

**适用场景**：推荐用于大多数情况

### 策略2：自动冲突解决（未实现）

如果检测到冲突，可以自动添加后缀或使用其他哈希函数：

```c
// 伪代码
if (collision_detected) {
    // 尝试添加后缀
    error_code = hash_error_name(error_name + "_alt");
    // 或使用不同的哈希函数
    error_code = hash_error_name_fnv(error_name);
}
```

**优点**：
- ✅ 自动处理，无需用户干预

**缺点**：
- ❌ 错误码不可预测
- ❌ 可能破坏稳定性

**适用场景**：不推荐

### 策略3：使用更大的哈希空间（未实现）

如果冲突率太高，可以使用 `uint64_t` 而不是 `uint32_t`：

```c
uint64_t hash_error_name_64(const char *error_name) {
    uint64_t error_code = 0;
    for (const char *p = error_name; *p; p++) {
        error_code = error_code * 31 + (unsigned char)*p;
    }
    if (error_code == 0) error_code = 1;
    return error_code;
}
```

**优点**：
- ✅ 大幅降低冲突概率（2^64 空间）

**缺点**：
- ⚠️ 需要修改类型定义（`uya.md` 中规定为 `uint32_t`）

**适用场景**：如果冲突率确实成为问题

## 冲突概率分析

根据之前的分析：
- **< 100 个错误**：冲突概率 < 0.0001%
- **< 1,000 个错误**：冲突概率 < 0.01%
- **< 10,000 个错误**：冲突概率 < 1.16%
- **< 50,000 个错误**：冲突概率 < 25%

对于大多数项目，冲突概率极低。

## 最佳实践

1. **使用描述性的错误名称**：如 `error.FileNotFound` 而不是 `error.Err1`
2. **避免相似的错误名称**：如 `error.TestError` 和 `error.TestErr` 可能冲突
3. **如果发现冲突，重命名其中一个**：编译器会提示哪些错误冲突

## 结论

**当前实现：编译期检测 + 用户重命名**是最佳方案，因为：
- ✅ 简单可靠
- ✅ 保证无冲突
- ✅ 用户控制错误名称
- ✅ 冲突概率极低，实际很少遇到
