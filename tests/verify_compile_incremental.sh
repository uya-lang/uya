#!/bin/bash
# 验证「增量编译」的两层机制都在生效：
#   1. **指纹短路**：源码 / 编译器 / 编译选项都没变时，compile.sh 直接跳过整轮编译；
#   2. **生成物 mtime 保持**：源码变了但某个 TU 生成的 C 没有变化时，该 TU 的 .o 不重编。
#
# 用 src/compile.sh 在临时目录里做一次真实自举太重，这里直接对仓库做两次 `make uya`：
# 第二次必须命中指纹（输出含「增量命中」），touch 源码后必须不再命中。
#
# 用法: bash tests/verify_compile_incremental.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$(mktemp -d /tmp/uya_incremental.XXXXXX)"

cleanup() {
    rm -rf "$LOG_DIR"
}
trap cleanup EXIT

fail() {
    echo "✗ $1"
    exit 1
}

cd "$REPO_ROOT" || fail "无法进入仓库根目录"

if [ ! -x bin/uya ]; then
    fail "未找到 bin/uya（先 make uya）"
fi
if [ ! -f src/.uyacache/mirror_manifest.txt ]; then
    fail "未找到 src/.uyacache/mirror_manifest.txt（先 make uya）"
fi

echo "验证：第一次 make uya 建指纹 ..."
if ! UYA_FORCE_BUILD=1 make uya >"$LOG_DIR/first.log" 2>&1; then
    tail -30 "$LOG_DIR/first.log"
    fail "第一次 make uya 失败"
fi
if [ ! -f src/.uyacache/.uya-build-stamp ]; then
    fail "第一次 make uya 后没有生成 .uya-build-stamp"
fi

echo "验证：无改动时第二次 make uya 命中增量指纹 ..."
if ! make uya >"$LOG_DIR/second.log" 2>&1; then
    tail -30 "$LOG_DIR/second.log"
    fail "第二次 make uya 失败"
fi
if ! grep -q "增量命中" "$LOG_DIR/second.log"; then
    fail "无改动时未命中增量指纹（期望输出含「增量命中」）"
fi

echo "验证：UYA_FORCE_BUILD=1 强制重建（不命中指纹） ..."
if ! UYA_FORCE_BUILD=1 make uya >"$LOG_DIR/forced.log" 2>&1; then
    tail -30 "$LOG_DIR/forced.log"
    fail "UYA_FORCE_BUILD=1 的 make uya 失败"
fi
if grep -q "增量命中" "$LOG_DIR/forced.log"; then
    fail "UYA_FORCE_BUILD=1 仍然命中了增量指纹"
fi

echo "验证：改动源码后不再命中指纹 ..."
PROBE=src/checker/interval.uya
BACKUP="$LOG_DIR/interval.uya.bak"
cp "$PROBE" "$BACKUP" || fail "无法备份 $PROBE"
restore_probe() {
    cp "$BACKUP" "$PROBE"
}
trap 'restore_probe; rm -rf "$LOG_DIR"' EXIT
printf '\n// incremental-build probe\n' >>"$PROBE"
if ! make uya >"$LOG_DIR/changed.log" 2>&1; then
    tail -30 "$LOG_DIR/changed.log"
    fail "改动源码后的 make uya 失败"
fi
if grep -q "增量命中" "$LOG_DIR/changed.log"; then
    fail "改动源码后仍然命中了增量指纹（指纹覆盖不全）"
fi
restore_probe

echo "验证：改动源码但生成 C 不变时，C 阶段不重编任何 TU ..."
# 上一轮（changed.log）已经把注释改动纳入；这一轮把文件恢复成原样，生成 C 应与上一轮
# 之前的主干一致，因此 .o 不应重编。允许 0 或极少数 TU 重编，但不得全量。
if ! make uya >"$LOG_DIR/restored.log" 2>&1; then
    tail -30 "$LOG_DIR/restored.log"
    fail "恢复源码后的 make uya 失败"
fi
compiled="$(grep -c '^cc -c' "$LOG_DIR/restored.log" || true)"
total_tu="$(grep -c '\.c ' src/.uyacache/Makefile || true)"
echo "  本轮 C 阶段编译的 TU 数: $compiled"
if [ "${compiled:-0}" -gt 5 ]; then
    fail "恢复源码后仍有 $compiled 个 TU 重编（期望 0，说明 mtime 未还原）"
fi

echo "verify_compile_incremental: ok"
