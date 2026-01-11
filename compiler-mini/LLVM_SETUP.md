# LLVM 开发环境设置指南

本文档说明如何在 WSL（Windows Subsystem for Linux）环境中安装 LLVM 开发库，以支持 Uya Mini 编译器的代码生成器（CodeGen）模块。

## 安装步骤

### 1. 更新包列表

首先更新包管理器：

```bash
sudo apt update
```

### 2. 安装 LLVM 开发库

安装 LLVM 开发库和工具：

```bash
sudo apt install llvm-dev clang libclang-dev
```

或者如果上述命令不可用，可以尝试：

```bash
sudo apt install llvm clang libllvm-dev
```

**说明**：
- `llvm` - LLVM 核心工具和库
- `llvm-dev` 或 `libllvm-dev` - LLVM 开发库（包含头文件和库文件）
- `clang` - Clang 编译器（可选，用于测试）
- `libclang-dev` - Clang 开发库（可选）

### 3. 验证安装

验证 LLVM 是否安装成功：

```bash
# 检查 llvm-config 是否可用
llvm-config --version

# 检查 LLVM 库路径
llvm-config --libdir

# 检查 LLVM 头文件路径
llvm-config --includedir

# 检查可用的库
llvm-config --libs core target

# 检查编译选项
llvm-config --cflags
```

### 4. 测试编译

在 `compiler-mini` 目录下测试编译 CodeGen 测试：

```bash
cd /mnt/c/Users/27027/uya/compiler-mini
make test-codegen
```

如果编译成功，运行测试：

```bash
./tests/test_codegen
```

## 常见问题

### 问题1：找不到 llvm-config

**症状**：运行 `llvm-config --version` 时提示命令未找到

**解决方案**：
1. 检查是否安装了 `llvm-dev` 或 `libllvm-dev` 包
2. 检查 `llvm-config` 是否在 PATH 中：`which llvm-config`
3. 如果没有找到，尝试安装：`sudo apt install llvm-dev`

### 问题2：找不到 LLVM 头文件

**症状**：编译时提示 `fatal error: llvm-c/Core.h: No such file or directory`

**解决方案**：
1. 确保已安装 `llvm-dev` 或 `libllvm-dev`
2. 检查头文件位置：`llvm-config --includedir`
3. 手动检查头文件是否存在：`ls $(llvm-config --includedir)/llvm-c/`

### 问题3：链接错误

**症状**：编译时出现链接错误，提示找不到 LLVM 库

**解决方案**：
1. 确保已安装 `llvm-dev` 或 `libllvm-dev`
2. 检查库文件位置：`llvm-config --libdir`
3. 检查 Makefile 中的链接选项是否正确

### 问题4：版本不匹配

**症状**：不同 LLVM 工具的版本不一致

**解决方案**：
1. 确保所有 LLVM 相关包来自同一个源
2. 重新安装所有 LLVM 包：`sudo apt reinstall llvm-dev clang libclang-dev`

## 安装特定版本的 LLVM

如果需要安装特定版本的 LLVM（例如 LLVM 14 或 15），可以使用以下方法：

### 方法1：使用 Ubuntu 官方仓库（推荐）

Ubuntu 22.04 默认提供 LLVM 14：

```bash
sudo apt update
sudo apt install llvm-14-dev clang-14 libclang-14-dev
```

然后使用 `llvm-config-14` 替代 `llvm-config`。

### 方法2：使用 LLVM 官方 APT 仓库

```bash
# 添加 LLVM 官方 APT 仓库
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
sudo add-apt-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy main"
sudo apt update

# 安装特定版本（例如 LLVM 16）
sudo apt install llvm-16-dev clang-16 libclang-16-dev
```

然后使用 `llvm-config-16` 替代 `llvm-config`。

如果使用特定版本，需要修改 Makefile：

```makefile
# 使用特定版本的 llvm-config
LLVM_CONFIG ?= llvm-config-14
```

## 验证编译环境

运行以下命令验证编译环境是否正确配置：

```bash
cd /mnt/c/Users/27027/uya/compiler-mini

# 检查 llvm-config
llvm-config --version

# 尝试编译 CodeGen 测试
make clean
make test-codegen

# 如果编译成功，运行测试
./tests/test_codegen
```

## 参考文档

- [LLVM 官方文档](https://llvm.org/docs/)
- [LLVM C API 文档](https://llvm.org/doxygen/group__LLVMCCore.html)
- [Ubuntu 包管理文档](https://help.ubuntu.com/lts/serverguide/apt.html)

## 注意事项

1. **LLVM 版本兼容性**：不同版本的 LLVM API 可能有差异，建议使用较新的稳定版本（LLVM 14+）
2. **磁盘空间**：LLVM 开发库较大（几百 MB），确保有足够的磁盘空间
3. **编译时间**：首次编译可能需要一些时间，因为需要链接 LLVM 库
4. **WSL 路径**：在 WSL 中访问 Windows 文件系统时，使用 `/mnt/c/Users/...` 路径格式

