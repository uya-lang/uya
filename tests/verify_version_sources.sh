#!/usr/bin/env bash
# 版本号来源一致性校验
#
# 唯一来源是 src/version.uya 的 UYA_VERSION。本脚本校验：
#   1. src/version.uya 里恰好一个 UYA_VERSION 字面量，形态为 MAJOR.MINOR.PATCH；
#   2. 编译器与 upm 的版本输出（bin/uya --version、bin/cmd/upm --version）与它一致；
#   3. 文档没有漂移：readme / CHANGELOG / 发行说明 / 优化状态报告都指向同一个版本。
#
# 为什么要有这条闸门：版本号以前散落在 src/main.uya 的两处 fprintf 与
# src/cmd/upm/upm_lib/types.uya 的一个常量里，发版时靠人工逐个改，漏一处就会
# 出现「bin/uya --version 报新版本、upm 还在按旧版本比 manifest」这类漂移。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_SOURCE="$ROOT_DIR/src/version.uya"
FAILED=0

fail() {
    echo "✗ $*"
    FAILED=1
}

# --- 1. 唯一来源本身 ---
if [ ! -f "$VERSION_SOURCE" ]; then
    echo "✗ 缺少版本号唯一来源: src/version.uya"
    exit 1
fi

VERSION_LITERALS="$(grep -oE '^export const UYA_VERSION: &byte = "[0-9]+\.[0-9]+\.[0-9]+"' "$VERSION_SOURCE" || true)"
if [ -z "$VERSION_LITERALS" ]; then
    echo "✗ src/version.uya 里没有 'export const UYA_VERSION: &byte = \"X.Y.Z\"' 形式的定义"
    exit 1
fi
if [ "$(printf '%s\n' "$VERSION_LITERALS" | wc -l)" -ne 1 ]; then
    echo "✗ src/version.uya 里 UYA_VERSION 定义了多次，唯一来源不成立"
    exit 1
fi
VERSION="$(printf '%s\n' "$VERSION_LITERALS" | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')"
echo "✓ 唯一来源 src/version.uya: $VERSION"

# --- 2. 两个消费者（编译器本体、upm）不许再写死字面量 ---
if grep -qE '"v?[0-9]+\.[0-9]+\.[0-9]+"' "$ROOT_DIR/src/cmd/upm/upm_lib/types.uya"; then
    fail "src/cmd/upm/upm_lib/types.uya 仍写死了版本字面量；应引用 version.UYA_VERSION"
fi
if grep -qE '"v?[0-9]+\.[0-9]+\.[0-9]+' "$ROOT_DIR/src/main.uya"; then
    fail "src/main.uya 仍写死了版本字面量；应引用 version 的 UYA_VERSION"
fi

UYA_BIN="${UYA_COMPILER:-$ROOT_DIR/bin/uya}"
if [ -x "$UYA_BIN" ]; then
    ACTUAL="$( "$UYA_BIN" --version 2>&1 | head -1 | tr -d '\r' )"
    if [ "$ACTUAL" != "v$VERSION" ]; then
        fail "bin/uya --version 输出 '$ACTUAL'，与 src/version.uya 的 'v$VERSION' 不一致"
    else
        echo "✓ bin/uya --version: $ACTUAL"
    fi
    # --help 走 usage 分支并以非 0 退出，这里显式吞掉退出码
    USAGE_VERSION="$( { "$UYA_BIN" --help 2>&1 || true; } | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true )"
    if [ -n "$USAGE_VERSION" ] && [ "$USAGE_VERSION" != "v$VERSION" ]; then
        fail "bin/uya --help 首部版本 '$USAGE_VERSION' 与 src/version.uya 不一致"
    fi
else
    echo "· 跳过 bin/uya 版本输出校验（$UYA_BIN 不存在）"
fi

UPM_BIN="$ROOT_DIR/bin/cmd/upm"
if [ -x "$UPM_BIN" ]; then
    UPM_ACTUAL="$( "$UPM_BIN" --version 2>&1 | head -1 | tr -d '\r' )"
    case "$UPM_ACTUAL" in
        *"v$VERSION"*) echo "✓ bin/cmd/upm --version: $UPM_ACTUAL" ;;
        *) fail "bin/cmd/upm --version 输出 '$UPM_ACTUAL'，与 src/version.uya 的 'v$VERSION' 不一致" ;;
    esac
else
    echo "· 跳过 bin/cmd/upm 版本输出校验（$UPM_BIN 不存在）"
fi

# --- 3. 文档不许漂移 ---
expect_in_file() {
    local needle="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        fail "缺少文件: ${file#$ROOT_DIR/}"
        return
    fi
    if grep -qF "$needle" "$file"; then
        echo "✓ ${file#$ROOT_DIR/} 含 '$needle'"
    else
        fail "${file#$ROOT_DIR/} 缺少 '$needle'"
    fi
}

expect_in_file "## 当前状态（v$VERSION）" "$ROOT_DIR/readme.md"
expect_in_file "RELEASE_v$VERSION.md" "$ROOT_DIR/readme.md"
expect_in_file "## v$VERSION " "$ROOT_DIR/CHANGELOG.md"
expect_in_file "**版本**：v$VERSION" "$ROOT_DIR/docs/compile_time_optimization_status.md"

RELEASE_DOC="$ROOT_DIR/docs/releases/RELEASE_v$VERSION.md"
if [ -f "$RELEASE_DOC" ]; then
    echo "✓ docs/releases/RELEASE_v$VERSION.md 存在"
else
    fail "缺少发行说明 docs/releases/RELEASE_v$VERSION.md"
fi

if [ "$FAILED" -ne 0 ]; then
    echo "✗ 版本号来源一致性校验失败（唯一来源: src/version.uya = $VERSION）"
    exit 1
fi

echo "version sources ok ($VERSION)"
