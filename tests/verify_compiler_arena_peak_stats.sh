#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
BUILD_DIR="$SCRIPT_DIR/build/arena_peak_stats"
SRC="$BUILD_DIR/arena_peak_smoke.uya"
OUT_C="$BUILD_DIR/arena_peak_smoke.c"
OUT_LOG="$BUILD_DIR/arena_peak_smoke.err"

mkdir -p "$BUILD_DIR"

if [[ ! -x "$COMPILER" ]]; then
    echo "错误: 未找到可用编译器: $COMPILER（请先 make uya）" >&2
    exit 1
fi

cat >"$SRC" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

if ! "$COMPILER" build --c99 --nostdlib "$SRC" -o "$OUT_C" >/dev/null 2>"$OUT_LOG"; then
    echo "错误: 编译 arena peak smoke 失败" >&2
    cat "$OUT_LOG" >&2
    exit 1
fi

if ! grep -Eq '^arena_peak_bytes: [1-9][0-9]*$' "$OUT_LOG"; then
    echo "错误: 编译统计缺少 arena_peak_bytes 正整数输出" >&2
    cat "$OUT_LOG" >&2
    exit 1
fi

echo "✓ compiler arena_peak_bytes 统计输出验证通过"
