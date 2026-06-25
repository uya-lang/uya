#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
FIXTURE="$ROOT_DIR/tests/fixtures/upm/conflict_alias"
TMP_DIR="$(mktemp -d /tmp/uya_package_mode_alias_conflict.XXXXXX)"
WORK_DIR="$TMP_DIR/conflict_alias"
APP_DIR="$WORK_DIR/app"
OUT_BIN="$TMP_DIR/conflict_alias.out"
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
    echo "✗ package mode alias/root 冲突场景意外构建成功"
    cat "$BUILD_LOG"
    exit 1
fi

grep -q "依赖 alias" "$BUILD_LOG"
grep -q "alias=http" "$BUILD_LOG"

echo "verify_package_mode_alias_root_conflict: ok"
