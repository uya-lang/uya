#!/usr/bin/env bash

# Phase 6 L471:
# - C99 输出缓冲峰值必须作为编译统计字段输出。
# - 单文件 C99 输出走固定 64KiB FILE 缓冲，输出文本变大时该峰值不得线性增长。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
TMP_DIR="$(mktemp -d /tmp/uya-c99-output-buffer-peak.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

SMALL_UYA="$TMP_DIR/small.uya"
LARGE_UYA="$TMP_DIR/large.uya"
SMALL_C="$TMP_DIR/small.c"
LARGE_C="$TMP_DIR/large.c"
SMALL_LOG="$TMP_DIR/small.log"
LARGE_LOG="$TMP_DIR/large.log"

extract_stat() {
    local label="$1"
    local file="$2"
    awk -F ': ' -v label="$label" '$1 == label { print $2; found = 1; exit } END { if (!found) exit 1 }' "$file"
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 C99 输出缓冲统计证据: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

if [[ ! -x "$COMPILER" ]]; then
    echo "错误: 未找到编译器: $COMPILER（请先 make uya）" >&2
    exit 1
fi

require_pattern "$REPO_ROOT/src/codegen/c99/internal.uya" 'C99_OUTPUT_STREAM_BUFFER_BYTES:[[:space:]]*usize[[:space:]]*=[[:space:]]*65536usize' "固定 64KiB 输出流缓冲常量"
require_pattern "$REPO_ROOT/src/codegen/c99/internal.uya" 'c99_output_buffer_peak_bytes:[[:space:]]*usize' "C99CodeGenerator 峰值字段"
require_pattern "$REPO_ROOT/src/codegen/c99/utils.uya" 'c99_output_buffer_note_open' "输出流打开记账"
require_pattern "$REPO_ROOT/src/codegen/c99/utils.uya" 'c99_codegen_output_buffer_peak_bytes' "输出缓冲峰值查询 API"
require_pattern "$REPO_ROOT/src/main.uya" 'c99_output_buffer_peak_bytes:' "编译统计输出字段"
require_pattern "$REPO_ROOT/scripts/bench_compiler_1s.sh" 'c99_output_buffer_peak_bytes' "benchmark 采集字段"

cat >"$SMALL_UYA" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

{
    echo "fn f0() i32 {"
    echo "    return 0;"
    echo "}"
    i=1
    while [[ "$i" -le 700 ]]; do
        prev=$((i - 1))
        echo "fn f$i() i32 {"
        echo "    return f$prev() + 1;"
        echo "}"
        i=$((i + 1))
    done
    echo "export fn main() i32 {"
    echo "    return f700();"
    echo "}"
} >"$LARGE_UYA"

"$COMPILER" "$SMALL_UYA" -o "$SMALL_C" --c99 --nostdlib --no-safety-proof >"$SMALL_LOG" 2>&1
"$COMPILER" "$LARGE_UYA" -o "$LARGE_C" --c99 --nostdlib --no-safety-proof >"$LARGE_LOG" 2>&1

small_peak="$(extract_stat "c99_output_buffer_peak_bytes" "$SMALL_LOG")"
large_peak="$(extract_stat "c99_output_buffer_peak_bytes" "$LARGE_LOG")"
small_bytes="$(stat -c '%s' "$SMALL_C" 2>/dev/null || stat -f '%z' "$SMALL_C")"
large_bytes="$(stat -c '%s' "$LARGE_C" 2>/dev/null || stat -f '%z' "$LARGE_C")"

if ! [[ "$small_peak" =~ ^[1-9][0-9]*$ && "$large_peak" =~ ^[1-9][0-9]*$ ]]; then
    echo "错误: c99_output_buffer_peak_bytes 必须为正整数" >&2
    cat "$SMALL_LOG" >&2
    cat "$LARGE_LOG" >&2
    exit 1
fi

if [[ "$small_peak" -ne 65536 || "$large_peak" -ne 65536 ]]; then
    echo "错误: 单文件 C99 输出缓冲峰值应固定为 65536 bytes，小=$small_peak 大=$large_peak" >&2
    exit 1
fi

if [[ "$large_bytes" -le $((small_bytes * 3)) ]]; then
    echo "错误: 大输出样本没有显著放大输出文本，小=$small_bytes 大=$large_bytes" >&2
    exit 1
fi

if [[ "$large_peak" -ne "$small_peak" ]]; then
    echo "错误: 输出文本放大时 C99 输出缓冲峰值不应增长，小=$small_peak 大=$large_peak" >&2
    exit 1
fi

echo "✓ C99 输出缓冲峰值可测量且不随输出文本大小线性常驻：small=${small_bytes}B large=${large_bytes}B peak=${large_peak}B"
