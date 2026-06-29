#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${UYA_COMPILER:-}" ]; then
    COMPILER="$UYA_COMPILER"
elif [ -x "$ROOT/bin/uya-hosted" ]; then
    COMPILER="$ROOT/bin/uya-hosted"
else
    COMPILER="$ROOT/bin/uya"
fi

TMP="$(mktemp -d)"
OUT_BIN="$TMP/dep-dedupe.out"
BUILD_LOG="$TMP/build.log"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT

if ! UYA_DEBUG_DEPENDENCY_LIST=1 "$COMPILER" build "$ROOT/tests/fixtures/dep_dedupe/main.uya" -o "$OUT_BIN" >"$BUILD_LOG" 2>&1; then
    cat "$BUILD_LOG" >&2
    exit 1
fi
test -x "$OUT_BIN"
"$OUT_BIN"

TARGET_PATH="$ROOT/tests/fixtures/dep_dedupe/lib/storage/wal_header.uya"
COUNT="$(awk -v path="$TARGET_PATH" '$0 ~ /^依赖文件\[[0-9]+\]: / && index($0, path) != 0 { c++ } END { print c + 0 }' "$BUILD_LOG")"

if [ "$COUNT" -ne 1 ]; then
    echo "verify_dependency_dedupe: expected exactly one wal_header dependency entry, got $COUNT" >&2
    grep '^依赖文件\[' "$BUILD_LOG" >&2 || true
    exit 1
fi

echo "verify_dependency_dedupe: ok"
