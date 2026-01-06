# 错误码冲突检测 - 完整测试用例

## 测试用例列表

### 1. 正常情况测试（无冲突）

**文件**: `tests/test_error_collision.uya`

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
```

**运行**:
```bash
./uyac tests/test_error_collision.uya output.c
```

**预期**: ✅ 编译成功，无冲突

---

### 2. 可能冲突测试

**文件**: `tests/test_collision_manual.uya`

```uya
fn test1() !i32 {
    return error.TestError;
}

fn test2() !i32 {
    return error.TestErr;
}
```

**运行**:
```bash
./uyac tests/test_collision_manual.uya output.c
```

**预期**: 
- 如果无冲突：✅ 编译成功
- 如果有冲突：❌ 显示详细冲突报告

---

### 3. 强制冲突测试（演示冲突检测功能）

**文件**: `tests/test_force_collision.uya`

```uya
fn test1() !i32 {
    return error.TestError;
}

fn test2() !i32 {
    return error.AnotherError;
}
```

**步骤**:

1. **临时修改编译器代码** (`src/codegen/codegen.c`):

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

2. **重新编译**:
```bash
make clean && make
```

3. **运行测试**:
```bash
./uyac tests/test_force_collision.uya output.c
```

**预期输出**:
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

4. **恢复原始代码**:
```bash
# 恢复备份（如果有）
# 或者手动撤销修改
```

---

## 快速测试脚本

创建 `test_collision.sh`:

```bash
#!/bin/bash

echo "=== 测试1: 正常情况（无冲突）==="
./uyac tests/test_error_collision.uya test1.c 2>&1
echo ""

echo "=== 测试2: 可能冲突 ==="
./uyac tests/test_collision_manual.uya test2.c 2>&1
echo ""

echo "=== 测试3: 强制冲突（需要先修改编译器）==="
echo "请先修改 src/codegen/codegen.c 中的 hash_error_name 函数"
echo "然后运行: ./uyac tests/test_force_collision.uya test3.c"
```

---

## 验证清单

- [ ] 测试用例1：正常情况编译成功
- [ ] 测试用例2：可能冲突的情况（如果有冲突，显示错误信息）
- [ ] 测试用例3：强制冲突测试（显示完整的冲突报告）
- [ ] 验证错误信息包含：
  - [ ] 冲突的错误名称
  - [ ] 冲突的错误码
  - [ ] 解决方案说明
  - [ ] 重命名建议（方案1和方案2）
  - [ ] 最佳实践建议

---

## 注意事项

1. **实际冲突很难构造**：由于哈希函数的特性，要找到两个会产生相同哈希值的不同字符串非常困难
2. **冲突概率极低**：对于大多数项目（< 10,000 个错误），冲突概率 < 1%
3. **测试方法**：为了测试冲突检测功能，可以临时修改编译器代码强制产生冲突
4. **恢复代码**：测试完成后，记得恢复原始的哈希函数代码
