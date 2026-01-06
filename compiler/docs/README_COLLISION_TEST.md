# 错误码冲突检测测试用例

## 快速开始

### 运行所有测试

```bash
./test_collision_detection.sh
```

### 单独运行测试

```bash
# 测试1: 正常情况
./uyac tests/test_error_collision.uya output.c

# 测试2: 可能冲突
./uyac tests/test_collision_manual.uya output.c

# 测试3: 强制冲突（需要先修改编译器）
./uyac tests/test_force_collision.uya output.c
```

## 测试用例说明

### 1. `tests/test_error_collision.uya`
- **目的**: 测试正常情况（多个不同的错误名称）
- **预期**: 编译成功，无冲突
- **用途**: 验证基本功能正常工作

### 2. `tests/test_collision_manual.uya`
- **目的**: 测试可能冲突的情况
- **预期**: 如果有冲突则显示错误，否则编译成功
- **用途**: 验证冲突检测机制

### 3. `tests/test_force_collision.uya`
- **目的**: 强制演示冲突检测功能
- **预期**: 需要临时修改编译器代码来强制产生冲突
- **用途**: 完整演示冲突检测的错误信息

## 强制冲突测试步骤

1. **备份原始文件**:
```bash
cp src/codegen/codegen.c src/codegen/codegen.c.backup
```

2. **修改 `src/codegen/codegen.c`** 中的 `hash_error_name` 函数:

找到这个函数（大约在第166行）:
```c
static uint32_t hash_error_name(const char *error_name) {
    if (!error_name) return 1;
    uint32_t error_code = 0;
    for (const char *p = error_name; *p; p++) {
        error_code = error_code * 31 + (unsigned char)*p;
    }
    if (error_code == 0) error_code = 1;
    return error_code;
}
```

修改为:
```c
static uint32_t hash_error_name(const char *error_name) {
    if (!error_name) return 1;
    
    // 强制冲突：让 TestError 和 AnotherError 都返回相同的错误码
    if (strcmp(error_name, "TestError") == 0 || 
        strcmp(error_name, "AnotherError") == 0) {
        return 1234567890U;  // 强制冲突
    }
    
    // 正常哈希逻辑
    uint32_t error_code = 0;
    for (const char *p = error_name; *p; p++) {
        error_code = error_code * 31 + (unsigned char)*p;
    }
    if (error_code == 0) error_code = 1;
    return error_code;
}
```

3. **重新编译**:
```bash
make clean && make
```

4. **运行测试**:
```bash
./uyac tests/test_force_collision.uya output.c
```

5. **查看输出**: 应该看到详细的冲突报告

6. **恢复原始代码**:
```bash
mv src/codegen/codegen.c.backup src/codegen/codegen.c
make
```

## 预期输出示例

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

## 注意事项

- 实际冲突很难构造（哈希函数设计良好）
- 冲突概率对于大多数项目极低（< 1% for < 10,000 errors）
- 测试完成后记得恢复原始代码
