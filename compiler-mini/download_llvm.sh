#!/bin/bash
# 下载 LLVM 预编译库到 compiler-mini 目录的脚本
# 注意：这会在 compiler-mini 目录下创建 llvm/ 子目录

set -e

# 配置
LLVM_VERSION="14.0.6"  # LLVM 版本号
ARCH="x86_64"          # 架构
OS="linux"             # 操作系统
BASE_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}"
TARBALL="clang+llvm-${LLVM_VERSION}-${ARCH}-${OS}-gnu-ubuntu-20.04.tar.xz"
TARGET_DIR="$(dirname "$0")/llvm"
EXTRACT_DIR="clang+llvm-${LLVM_VERSION}-${ARCH}-${OS}-gnu-ubuntu-20.04"

echo "========================================="
echo "下载 LLVM 预编译库"
echo "版本: ${LLVM_VERSION}"
echo "目标目录: ${TARGET_DIR}"
echo "========================================="
echo ""
echo "警告：这将下载约 300-500MB 的文件"
echo "建议使用系统包管理器安装：sudo apt install llvm-dev"
echo ""
read -p "继续？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 1
fi

# 创建目标目录
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 下载
echo "正在下载 ${TARBALL}..."
if command -v wget &> /dev/null; then
    wget "${BASE_URL}/${TARBALL}"
elif command -v curl &> /dev/null; then
    curl -L -O "${BASE_URL}/${TARBALL}"
else
    echo "错误：需要 wget 或 curl 来下载文件"
    exit 1
fi

# 解压
echo "正在解压..."
tar -xf "${TARBALL}"

# 重命名目录
if [ -d "$EXTRACT_DIR" ]; then
    if [ -d "lib" ] || [ -d "include" ]; then
        echo "警告：目标目录已存在文件"
    else
        mv "$EXTRACT_DIR"/* .
        rmdir "$EXTRACT_DIR"
    fi
fi

# 清理压缩包
rm -f "${TARBALL}"

echo ""
echo "========================================="
echo "下载完成！"
echo "LLVM 库位置: ${TARGET_DIR}"
echo ""
echo "接下来需要："
echo "1. 修改 Makefile 使用本地 LLVM 库"
echo "2. 或者设置环境变量指向本地库"
echo "========================================="

