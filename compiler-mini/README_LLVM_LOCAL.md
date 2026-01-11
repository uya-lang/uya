# 使用本地 LLVM 库

如果要将 LLVM 库下载到 `compiler-mini` 目录中（而不是系统安装），可以按照以下步骤操作。

## ⚠️ 重要说明

**不推荐**将 LLVM 库下载到项目目录，因为：
1. LLVM 库很大（300-500MB）
2. 会增加项目目录大小
3. 系统包管理器安装更简单可靠

**推荐方式**：使用系统包管理器安装
```bash
sudo apt install llvm-dev clang libclang-dev
```

但如果确实需要本地库（比如没有系统权限，或需要特定版本），可以按照以下方法操作。

## 方法1：使用下载脚本

运行下载脚本：

```bash
cd /mnt/c/Users/27027/uya/compiler-mini
chmod +x download_llvm.sh
./download_llvm.sh
```

脚本会：
1. 下载 LLVM 14.0.6 预编译包（约 300-500MB）
2. 解压到 `compiler-mini/llvm/` 目录
3. 清理压缩包

## 方法2：手动下载

1. **访问 LLVM 发布页面**：
   https://github.com/llvm/llvm-project/releases

2. **下载预编译包**：
   选择适合的版本，例如：
   - `clang+llvm-14.0.6-x86_64-linux-gnu-ubuntu-20.04.tar.xz`

3. **解压到 compiler-mini/llvm/**：
   ```bash
   cd /mnt/c/Users/27027/uya/compiler-mini
   mkdir -p llvm
   cd llvm
   tar -xf /path/to/clang+llvm-*.tar.xz --strip-components=1
   ```

## 配置 Makefile 使用本地库

下载后，需要修改 Makefile 使用本地库。有两种方式：

### 方式A：修改 Makefile（推荐）

在 `Makefile` 中添加本地库支持：

```makefile
# LLVM 库链接选项
LLVM_LOCAL = ./llvm
LLVM_CONFIG ?= $(LLVM_LOCAL)/bin/llvm-config

# 如果本地库存在，使用本地库；否则使用系统库
ifeq ($(wildcard $(LLVM_CONFIG)),)
    # 使用系统 llvm-config
    LLVM_CONFIG ?= llvm-config
    LLVM_CFLAGS = $(shell $(LLVM_CONFIG) --cflags 2>/dev/null || echo "")
    LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --ldflags 2>/dev/null || echo "")
    LLVM_LIBS = $(shell $(LLVM_CONFIG) --libs core target 2>/dev/null || echo "-llvm")
else
    # 使用本地库
    LLVM_CFLAGS = -I$(LLVM_LOCAL)/include
    LLVM_LDFLAGS = -L$(LLVM_LOCAL)/lib
    LLVM_LIBS = -lLLVM-14
endif
```

### 方式B：使用环境变量

设置环境变量后编译：

```bash
export LLVM_PREFIX=/mnt/c/Users/27027/uya/compiler-mini/llvm
export PATH=$LLVM_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$LLVM_PREFIX/lib:$LD_LIBRARY_PATH

make test-codegen
```

## 目录结构

下载后的目录结构：

```
compiler-mini/
├── llvm/                    # LLVM 本地库目录
│   ├── bin/                 # 可执行文件（包含 llvm-config）
│   ├── include/             # 头文件
│   │   └── llvm-c/          # LLVM C API 头文件
│   ├── lib/                 # 库文件
│   └── ...
├── src/
├── tests/
└── Makefile
```

## 添加到 .gitignore

将 LLVM 库目录添加到 `.gitignore`：

```bash
echo "llvm/" >> .gitignore
```

## 验证安装

验证本地 LLVM 库是否正确：

```bash
cd /mnt/c/Users/27027/uya/compiler-mini

# 检查本地 llvm-config
./llvm/bin/llvm-config --version

# 检查头文件
ls ./llvm/include/llvm-c/Core.h

# 检查库文件
ls ./llvm/lib/libLLVM*.so*

# 测试编译
make clean
make test-codegen
```

## 常见问题

### 问题1：找不到库文件

**症状**：链接时提示找不到 `-lLLVM-14`

**解决**：
1. 检查库文件是否存在：`ls llvm/lib/libLLVM*.so*`
2. 检查库版本号（可能是 LLVM-14, LLVM-15 等）
3. 修改 Makefile 中的库名

### 问题2：运行时找不到共享库

**症状**：运行程序时提示 `error while loading shared libraries`

**解决**：
```bash
export LD_LIBRARY_PATH=/mnt/c/Users/27027/uya/compiler-mini/llvm/lib:$LD_LIBRARY_PATH
```

或者永久设置（添加到 `~/.bashrc`）：
```bash
echo 'export LD_LIBRARY_PATH=/mnt/c/Users/27027/uya/compiler-mini/llvm/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

### 问题3：版本不匹配

**症状**：头文件和库文件版本不一致

**解决**：确保下载的预编译包是完整版本，包含所有需要的文件。

## 推荐做法

虽然可以使用本地库，但**强烈推荐使用系统包管理器安装**：

```bash
sudo apt update
sudo apt install llvm-dev clang libclang-dev
```

这样更简单、更可靠，并且会自动处理依赖关系。

