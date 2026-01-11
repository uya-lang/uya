# 阶段7：实现代码生成器（CodeGen，LLVM C API）

## 7.1 CodeGen 结构定义

- [ ] 创建 `src/codegen.h`
  - [ ] 定义 CodeGenerator 结构体
  - [ ] 声明代码生成函数
  - [ ] 包含 LLVM C API 头文件
  - [ ] 添加中文注释说明

## 7.2 CodeGen 核心实现（TDD，必须分部实现）

**注意**：CodeGen 功能复杂，必须分多次会话完成，不能简化。

### TDD Red: 编写测试

- [ ] 创建测试文件
  - [ ] 测试基础类型代码生成
  - [ ] 测试函数代码生成
  - [ ] 测试结构体代码生成
  - [ ] 运行测试确保失败

### TDD Green: 实现功能（分多次会话）

**会话1：基础框架和类型映射**
- [ ] 创建 `src/codegen.c`
- [ ] 实现 `codegen_new()` - 创建 CodeGenerator
- [ ] 实现 `codegen_generate()` - 代码生成主函数框架
- [ ] 实现 LLVM 模块和上下文创建
- [ ] 实现基础类型到 LLVM 类型映射（完整实现）
  - [ ] i32 → LLVMInt32Type()
  - [ ] bool → LLVMInt1Type()
  - [ ] void → LLVMVoidType()
- [ ] 运行测试，更新 PROGRESS.md

**会话2：结构体类型映射**
- [ ] 实现结构体类型到 LLVM 类型映射（完整实现，不能简化）
  - [ ] 使用 LLVMStructType() 创建结构体类型
- [ ] 运行测试，更新 PROGRESS.md

**会话3：表达式代码生成**
- [ ] 实现表达式代码生成（完整实现，不能简化）
- [ ] 运行测试，更新 PROGRESS.md

**会话4：语句代码生成**
- [ ] 实现语句代码生成（完整实现，不能简化）
- [ ] 运行测试，更新 PROGRESS.md

**会话5：函数代码生成**
- [ ] 实现函数代码生成（完整实现，不能简化）
- [ ] 运行测试，更新 PROGRESS.md

**会话6：结构体处理**
- [ ] 实现结构体处理（完整实现，不能简化）
  - [ ] 结构体字面量生成（LLVMConstStruct()）
  - [ ] 字段访问生成（LLVMBuildExtractValue()）
  - [ ] 字段赋值生成（LLVMBuildInsertValue()）
  - [ ] 结构体比较生成（逐字段比较）
- [ ] 运行测试，更新 PROGRESS.md

**会话7：目标代码生成和清理**
- [ ] 实现目标代码生成（LLVMTargetMachineEmitToFile()）
- [ ] 实现资源清理
- [ ] 运行测试，更新 PROGRESS.md

**所有会话完成后：**
- [ ] 添加中文注释说明
- [ ] **验证函数 < 200 行，文件 < 1500 行**
- [ ] **如果文件超过 1500 行，拆分为 codegen_*.c 多个文件**
- [ ] 验证代码可以编译并链接 LLVM 库

### TDD Refactor: 优化

- [ ] 代码审查和重构
- [ ] 运行所有测试确保通过

## 7.3 CodeGen 测试

- [ ] 创建测试用例验证 CodeGen 功能
- [ ] 测试基础类型代码生成
- [ ] 测试函数代码生成
- [ ] 测试结构体代码生成
- [ ] 测试生成的二进制文件可以执行

