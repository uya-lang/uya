# 错误码冲突处理 - 最终实现

## ✅ 已实现功能

### 1. 编译期冲突检测

在代码生成阶段，编译器会：
1. **收集**所有错误名称（从 IR 中遍历所有 `IR_ERROR_VALUE`）
2. **计算**每个错误名称的哈希值（错误码）
3. **检测**所有错误名称对，如果发现相同的错误码，报告冲突
4. **处理**：如果发现冲突，编译失败，提示用户重命名错误名称

### 2. 错误信息

当发现冲突时，编译器会输出清晰的错误信息：

```
错误: 错误码冲突！
  error.TestError 和 error.AnotherError 都生成了错误码 1234567890U
  建议: 重命名其中一个错误名称以避免冲突

编译失败: 发现 1 个错误码冲突
请重命名冲突的错误名称以避免冲突
```

### 3. 实现代码

```c
// 计算错误名称的哈希值
static uint32_t hash_error_name(const char *error_name) {
    if (!error_name) return 1;
    uint32_t error_code = 0;
    for (const char *p = error_name; *p; p++) {
        error_code = error_code * 31 + (unsigned char)*p;
    }
    if (error_code == 0) error_code = 1;
    return error_code;
}

// 检测错误码冲突并报告
static int detect_error_code_collisions(CodeGenerator *codegen) {
    if (!codegen || codegen->error_map_size == 0) {
        return 0; // 无冲突
    }
    
    int collision_count = 0;
    
    // 检查所有错误名称对
    for (int i = 0; i < codegen->error_map_size; i++) {
        uint32_t code_i = codegen->error_map[i].error_code;
        for (int j = i + 1; j < codegen->error_map_size; j++) {
            uint32_t code_j = codegen->error_map[j].error_code;
            if (code_i == code_j) {
                // 发现冲突
                collision_count++;
                fprintf(stderr, "错误: 错误码冲突！\n");
                fprintf(stderr, "  error.%s 和 error.%s 都生成了错误码 %uU\n",
                        codegen->error_map[i].error_name,
                        codegen->error_map[j].error_name,
                        code_i);
                fprintf(stderr, "  建议: 重命名其中一个错误名称以避免冲突\n");
            }
        }
    }
    
    return collision_count;
}
```

## 冲突概率

根据之前的分析：
- **< 100 个错误**：冲突概率 < 0.0001%
- **< 1,000 个错误**：冲突概率 < 0.01%
- **< 10,000 个错误**：冲突概率 < 1.16%

对于大多数项目，冲突概率极低，实际很少遇到。

## 处理流程

```
编译开始
    ↓
收集所有错误名称
    ↓
计算每个错误名称的哈希值
    ↓
检测冲突
    ↓
有冲突？
    ├─ 是 → 报告错误，编译失败
    └─ 否 → 继续编译，生成代码
```

## 优势

1. ✅ **编译期检测**：在编译时发现冲突，而不是运行时
2. ✅ **清晰错误信息**：明确指出哪些错误冲突
3. ✅ **用户控制**：用户可以选择重命名哪个错误
4. ✅ **保证无冲突**：编译通过即保证无冲突

## 使用建议

1. **使用描述性的错误名称**：如 `error.FileNotFound` 而不是 `error.Err1`
2. **避免相似的错误名称**：如 `error.TestError` 和 `error.TestErr` 可能冲突
3. **如果发现冲突，重命名其中一个**：编译器会提示哪些错误冲突

## 总结

✅ **冲突检测已实现**：编译器会在编译期检测并报告冲突
✅ **处理方案明确**：用户重命名冲突的错误名称
✅ **冲突概率极低**：对于大多数项目，实际很少遇到冲突
