#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
TMP_DIR="$(mktemp -d /tmp/uya_upm_min_version_fail.XXXXXX)"
WORK_DIR="$TMP_DIR/app"
OUT_BIN="$TMP_DIR/app.out"
BUILD_LOG="$TMP_DIR/build.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

mkdir -p "$WORK_DIR"
cat > "$WORK_DIR/uya.toml" <<'EOF_MANIFEST'
[package]
name = "min_version_fail"
version = "0.1.0"
uya_min_version = "0.10.1"
EOF_MANIFEST

cat > "$WORK_DIR/main.uya" <<'EOF_SRC'
export fn main() i32 {
    return 0;
}
EOF_SRC

set +e
"$UPM_BIN" build "$WORK_DIR" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "✗ uya_min_version 不满足场景意外构建成功"
    cat "$BUILD_LOG"
    exit 1
fi

grep -q "package.uya_min_version" "$BUILD_LOG"
grep -q "当前 uya 版本 0.10.0 低于" "$BUILD_LOG"

echo "verify_upm_min_version_fail: ok"
