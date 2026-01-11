# LLVM 库链接方式说明

Uya Mini 编译器的代码生成器（CodeGen）模块需要链接 LLVM 库。有两种方式可以链接 LLVM 库：

## 方式1：使用 llvm-config（推荐，当前使用）

**优点**：
- 自动获取正确的编译和链接选项
- 支持不同版本的 LLVM
- 跨平台兼容性好
- 自动处理依赖关系

**当前配置**（在 Makefile 中）：

```makefile
LLVM_CONFIG ?= llvm-config
LLVM_CFLAGS = $(shell $(LLVM_CONFIG) --cflags 2>/dev/null || echo "")
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --ldflags 2>/dev/null || echo "")
LLVM_LIBS = $(shell $(LLVM_CONFIG) --libs core target 2>/dev/null || echo "-llvm")
```

**使用前提**：需要安装 LLVM 开发库，并确保 `llvm-config` 在 PATH 中。

**安装命令**：
```bash
sudo apt install llvm-dev clang libclang-dev
```

## 方式2：手动指定库路径和链接选项

如果不想使用 `llvm-config`，可以直接指定库路径和链接选项。

### 方法A：使用系统库（简单但不够灵活）

在 Makefile 中直接指定库名：

```makefile
# 直接链接系统库
LLVM_CFLAGS = -I/usr/include/llvm-c
LLVM_LDFLAGS = -L/usr/lib/llvm-14/lib
LLVM_LIBS = -lLLVM-14
```

**问题**：
- 需要知道具体的库路径
- 不同系统路径可能不同
- 版本号可能不同（llvm-14, llvm-15 等）
- 不推荐使用

### 方法B：使用预编译的 LLVM 库

如果从 LLVM 官网下载了预编译的库，可以指定路径：

```makefile
# 假设 LLVM 安装在 /opt/llvm
LLVM_PREFIX = /opt/llvm
LLVM_CFLAGS = -I$(LLVM_PREFIX)/include
LLVM_LDFLAGS = -L$(LLVM_PREFIX)/lib
LLVM_LIBS = -lLLVM
```

## 推荐做法

**强烈推荐使用方式1（llvm-config）**，因为：

1. **自动适配**：自动处理不同版本的 LLVM
2. **依赖管理**：自动处理库之间的依赖关系
3. **路径管理**：自动获取正确的头文件和库文件路径
4. **标准化**：这是 LLVM 官方推荐的方式

## 如果 llvm-config 不可用

如果系统中没有 `llvm-config`，可以：

1. **安装 LLVM 开发库**（推荐）：
   ```bash
   sudo apt install llvm-dev
   ```

2. **手动安装 llvm-config**：
   ```bash
   sudo apt install llvm
   ```

3. **使用特定版本**：
   ```bash
   # Ubuntu 22.04 默认是 LLVM 14
   sudo apt install llvm-14-dev
   # 然后修改 Makefile 使用 llvm-config-14
   ```

4. **从源码编译 LLVM**（不推荐，非常耗时）：
   如果需要从源码编译，请参考 LLVM 官方文档。

## 验证链接配置

运行以下命令验证 LLVM 库链接配置是否正确：

```bash
# 检查 llvm-config 是否可用
llvm-config --version

# 查看编译选项
llvm-config --cflags

# 查看链接选项
llvm-config --ldflags

# 查看需要的库
llvm-config --libs core target

# 测试编译
cd /mnt/c/Users/27027/uya/compiler-mini
make clean
make test-codegen
```

## 当前项目的配置

当前项目使用方式1（llvm-config），这是最佳实践。如果 `llvm-config` 不可用，Makefile 会回退到使用 `-llvm`（可能无法正常工作）。

**建议**：确保安装了 `llvm-dev` 包，这样 `llvm-config` 就会可用。

