#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
TMP_DIR="$(mktemp -d /tmp/uya_upm_manifest_missing.XXXXXX)"
OUT_BIN="$TMP_DIR/out"
BUILD_LOG="$TMP_DIR/build.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

set +e
"$UPM_BIN" build "$ROOT_DIR/examples/HelloWorld.uya" \
    --manifest-path "$TMP_DIR/missing.uya.toml" \
    -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "✗ 缺失 manifest 场景意外构建成功"
    cat "$BUILD_LOG"
    exit 1
fi

grep -q "manifest" "$BUILD_LOG"

echo "verify_upm_manifest_missing: ok"
