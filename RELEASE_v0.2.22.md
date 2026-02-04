# Uya v0.2.22 版本说明

**发布日期**：2026-02-04

本版本主要完成 **自举编译器一致性修复** 和 **编译器稳定性增强**：修复了自举编译器与 C 编译器输出不一致的问题，优化了路径检查和内存管理，增强了模块系统的稳定性。

---

## 核心亮点

### 1. 自举编译器一致性修复

- **修复 `paths_equal` 函数 bug**：之前仅比较文件名，导致 `codegen/c99/main.uya` 和 `main.uya` 被误判为同一文件，`main.uya` 被跳过
- **修复后使用 `stat` 检查**：通过比较设备和 inode 确保文件路径比较的准确性，与 C 版本一致
- **修复多维数组代码生成**：修复了 `gen_global_var` 函数，使其正确处理多维数组（如 `[[byte: PATH_MAX]: MAX_INPUT_FILES]`）
- **修复指向数组的指针代码生成**：修复了 `format_param_type` 函数，使其正确处理指向数组的指针（如 `uint8_t (*file_paths_buffer)[4096]`）
- **修复 `fflush` extern 声明**：将 `fflush` 添加到 `is_stdlib_function` 列表中，避免生成重复的 extern 声明
- **修复 `memcpy` 格式问题**：修复了 C 版本的 `memcpy` 生成代码，移除了多余的缩进空格

### 2. 编译器稳定性增强

- **增加 Arena 内存大小**：从 81MB 增加到 128MB，以支持自举编译所有文件
- **路径检查增强**：在 `main.c` 中新增路径检查，确保传入参数不为 NULL，避免潜在的崩溃
- **内存管理优化**：优化全局变量的使用，避免栈溢出，确保编译器在处理大数组时的稳定性

### 3. 模块系统增强

- **自动模块依赖解析**：支持仅指定包含 `main` 函数的文件或目录，编译器将自动处理依赖关系
- **环境变量支持**：实现 `get_uya_root()` 函数，支持通过 `UYA_ROOT` 环境变量指定标准库位置
- **项目根目录识别**：在 `checker.uya` 中新增 `project_root_dir` 字段，提取包含 `main` 函数的文件路径
- **模块路径查找优化**：完善 `collect_module_dependencies()` 函数的递归依赖收集逻辑

### 4. 代码生成优化

- **数组初始化优化**：在 `stmt.c` 中优化数组初始化的代码生成逻辑，简化 `memcpy` 的使用
- **代码格式统一**：确保 C 版和自举版编译器生成的代码格式完全一致

---

## 模块变更

### C 实现（compiler-mini/src）

| 模块 | 变更 |
|------|------|
| main.c | 新增路径检查，确保传入参数不为 NULL；新增获取编译器目录和 UYA_ROOT 环境变量的功能 |
| codegen/c99/stmt.c | 优化数组初始化的代码生成逻辑，简化 `memcpy` 的使用，移除多余的缩进空格 |
| codegen/c99/function.c | 将 `fflush` 添加到 `is_stdlib_function` 列表中 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| main.uya | 修复 `paths_equal` 函数，使用 `stat` 检查文件是否为同一文件；增加 Arena 缓冲区大小至 128MB；优化全局变量使用，避免栈溢出 |
| checker.uya | 新增 `project_root_dir` 字段，提取包含 `main` 函数的文件路径，支持项目根目录识别 |
| codegen/c99/global.uya | 修复多维数组的代码生成，正确处理 `[[byte: PATH_MAX]: MAX_INPUT_FILES]` 格式 |
| codegen/c99/function.uya | 修复指向数组的指针的代码生成；将 `fflush` 添加到 `is_stdlib_function` 列表中 |
| codegen/c99/main.uya | 确保 `AST_USE_STMT` 节点在代码生成时被正确跳过 |
| codegen/c99/types.uya | 修复类型转换相关的代码生成问题 |

### 测试与工具

- **自举对比验证**：`./compile.sh --c99 -b` 现在完全一致（C 版与自举版生成 C 完全一致）
- **测试用例验证**：所有测试用例在 C 版和自举版编译器中均通过

---

## 测试验证

- **C 版编译器（`--c99`）**：所有测试用例通过
- **自举版编译器（`--uya --c99`）**：所有测试用例通过
- **自举对比**：`./compile.sh --c99 -b` 完全一致（C 版与自举版生成 C 完全一致）
- **AST 合并**：共 351 个声明，与 C 编译器一致
- **代码生成**：所有函数、BackendType 枚举和字符串常量都正确生成

---

## 文件变更统计（自 v0.2.21 以来）

**C 实现**：
- `compiler-mini/src/main.c` — 新增路径检查、环境变量支持
- `compiler-mini/src/codegen/c99/stmt.c` — 优化数组初始化代码生成
- `compiler-mini/src/codegen/c99/function.c` — 修复 `fflush` 处理

**自举实现（uya-src）**：
- `compiler-mini/uya-src/main.uya` — 修复 `paths_equal`、增加内存、优化全局变量（209 行修改）
- `compiler-mini/uya-src/checker.uya` — 新增项目根目录识别（159 行新增）
- `compiler-mini/uya-src/codegen/c99/global.uya` — 修复多维数组代码生成（56 行修改）
- `compiler-mini/uya-src/codegen/c99/function.uya` — 修复指向数组的指针代码生成、`fflush` 处理（76 行修改）
- `compiler-mini/uya-src/codegen/c99/main.uya` — 确保 `AST_USE_STMT` 被正确跳过（23 行修改）
- `compiler-mini/uya-src/codegen/c99/types.uya` — 修复类型转换相关代码生成（27 行修改）
- `compiler-mini/uya-src/codegen/c99/expr.uya` — 修复表达式相关代码生成（16 行修改）

**其他**：
- 移除不再使用的子项目 `mquickjs` 和 `sqlite`
- 更新编译计划文档，移除冗余内容
- 新增文件级并行编译计划文档

**统计**：9 个文件变更，405 行新增，176 行删除

---

## 版本对比

### v0.2.21 → v0.2.22 变更

- **修复**：
  - ✅ 修复 `paths_equal` 函数 bug，确保文件路径比较的准确性
  - ✅ 修复多维数组代码生成问题
  - ✅ 修复指向数组的指针代码生成问题
  - ✅ 修复 `fflush` extern 声明重复问题
  - ✅ 修复 `memcpy` 格式空格问题
  - ✅ 修复自举编译器与 C 编译器输出不一致的问题

- **增强**：
  - ✅ 增加 Arena 内存大小至 128MB
  - ✅ 新增路径检查，避免潜在的崩溃
  - ✅ 优化内存管理，避免栈溢出
  - ✅ 增强模块系统稳定性
  - ✅ 支持自动模块依赖解析
  - ✅ 支持 `UYA_ROOT` 环境变量

- **优化**：
  - ✅ 优化数组初始化代码生成逻辑
  - ✅ 优化全局变量使用，避免栈溢出
  - ✅ 清理不再使用的子项目

- **非破坏性**：向后兼容，现有测试用例行为不变

---

## 技术细节

### paths_equal 函数修复

**问题**：之前仅比较文件名，导致 `codegen/c99/main.uya` 和 `main.uya` 被误判为同一文件，`main.uya` 被跳过。

**修复**：使用 `stat` 系统调用检查文件是否为同一文件（比较设备和 inode），与 C 版本一致。

```uya
// 修复前：仅比较文件名
if strcmp(name1 as *byte, name2 as *byte) == 0 {
    return 1;  // 误判
}

// 修复后：使用 stat 检查
var st1: Stat = Stat { _data: [0: 144] };
var st2: Stat = Stat { _data: [0: 144] };
if stat(path1 as *byte, &st1) == 0 && stat(path2 as *byte, &st2) == 0 {
    // 比较设备和 inode
    if dev1 == dev2 && ino1 == ino2 {
        return 1;
    }
}
```

### 多维数组代码生成修复

**问题**：`gen_global_var` 函数只处理单维数组，对于多维数组（如 `[[byte: PATH_MAX]: MAX_INPUT_FILES]`）生成错误的格式。

**修复**：使用 `c99_type_to_c` 处理整个类型，然后解析类型字符串，分离基类型和数组维度。

```uya
// 修复前：只处理单维数组
type_c = c99_type_to_c(codegen, element_type);
fprintf(codegen.output, "%s %s[%d]", type_c, var_name, array_size);

// 修复后：处理多维数组
const full_type_c = c99_type_to_c(codegen, var_type);
// 解析 "uint8_t[64][4096]" -> 基类型="uint8_t", 维度="[64][4096]"
fprintf(codegen.output, "%s %s%s", base_type, var_name, dimensions);
```

### 指向数组的指针代码生成修复

**问题**：`format_param_type` 函数没有正确处理指向数组的指针格式（如 `uint8_t (*)[4096]`）。

**修复**：检查是否包含 `"(*)"` 模式，将参数名插入到 `(*)` 中。

```uya
// 修复前：错误格式
fprintf(output, "%s %s%s", base_type, param_name, bracket);
// 生成：uint8_t (*) file_paths_buffer[4096]  ❌

// 修复后：正确格式
fprintf(output, "%s (*%s)%s", base_type, param_name, dims);
// 生成：uint8_t (*file_paths_buffer)[4096]  ✅
```

---

## 使用示例

### 自动模块依赖解析

```bash
# 只需指定包含 main 的文件或目录
./compiler-mini src/main.uya -o output.c --c99

# 或指定目录，编译器会自动查找包含 main 的文件
./compiler-mini src/ -o output.c --c99
```

### 环境变量配置

```bash
# 通过 UYA_ROOT 环境变量指定标准库位置
export UYA_ROOT=/path/to/stdlib
./compiler-mini src/main.uya -o output.c --c99
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **模块系统增强**：模块别名、模块重导出、条件编译
- **内存安全证明**：数组越界/空指针/未初始化/溢出/除零
- **原子类型**：atomic T、&atomic T
- **原始字符串**：`` `...` `` 无转义
- **文件级并行编译**：实现增量编译和并行编译支持

---

## 相关资源

- **语言规范**：`uya.md`（模块系统、类型转换）
- **实现文档**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_module_*.uya`

---

**本版本完成自举编译器一致性修复和编译器稳定性增强，确保了 C 版与自举版编译器生成的代码完全一致，为后续开发奠定了坚实的基础。**

