#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
FIXTURE="$ROOT_DIR/tests/fixtures/upm/missing_dep_manifest"
TMP_DIR="$(mktemp -d /tmp/uya_upm_missing_dep_manifest.XXXXXX)"
WORK_DIR="$TMP_DIR/missing_dep_manifest"
APP_DIR="$WORK_DIR/app"
OUT_BIN="$TMP_DIR/out"
BUILD_LOG="$TMP_DIR/build.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

cp -R "$FIXTURE" "$WORK_DIR"

set +e
"$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "✗ 缺少依赖 manifest 的场景意外构建成功"
    cat "$BUILD_LOG"
    exit 1
fi

grep -q "uya.toml" "$BUILD_LOG"
grep -q "broken" "$BUILD_LOG"

echo "verify_upm_missing_dep_manifest: ok"
