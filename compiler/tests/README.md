# Uya语言测试套件

这个目录包含Uya编程语言的各种功能测试。

## 测试文件说明

### 1. `final_slice_test.uya`
- 测试切片语法的核心功能
- 包括基本切片、负数索引切片、范围切片等

### 2. `simple_slice_test.uya`
- 简单的切片语法测试
- 验证基本的slice函数功能

### 3. `slice_tests.uya`
- 完整的切片功能测试
- 包括数组切片、字符串切片、结构体数组切片等

### 4. `test_extern_comprehensive.uya`
- 测试extern声明功能
- 包括可变参数函数声明

### 5. `test_slice_comprehensive.uya`
- 综合切片语法测试
- 包括各种边界情况和负数索引

### 6. `test_python_slice.uya`
- Python风格切片语法测试
- 验证类似Python的切片语法

## 运行测试

```bash
# 编译测试文件
./uyac tests/final_slice_test.uya output.c

# 查看生成的C代码
cat output.c
```

## 已实现功能

1. **基本切片语法**：`slice(arr, start, end)`
2. **负数索引支持**：`slice(arr, -3, 10)` 等价于从倒数第3个到末尾
3. **范围切片**：支持从开头到某位置、从某位置到末尾等
4. **数组类型切片**：支持各种基本类型数组的切片
5. **结构体数组切片**：支持结构体数组的切片操作

## 语法示例

```uya
var arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

// 基本切片
const slice1: [i32; 3] = slice(arr, 2, 5);  // [2, 3, 4]

// 负数索引切片
const slice2: [i32; 3] = slice(arr, -3, 10);  // [7, 8, 9]

// 从开头到某位置
const slice3: [i32; 3] = slice(arr, 0, 3);  // [0, 1, 2]

// 从某位置到末尾
const slice4: [i32; 3] = slice(arr, 7, 10);  // [7, 8, 9]

// 负数到负数
const slice5: [i32; 3] = slice(arr, -5, -2);  // [5, 6, 7]
```