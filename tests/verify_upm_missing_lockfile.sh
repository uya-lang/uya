#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
FIXTURE="$ROOT_DIR/tests/fixtures/upm/path_dep"
TMP_DIR="$(mktemp -d /tmp/uya_upm_missing_lockfile.XXXXXX)"
WORK_DIR="$TMP_DIR/path_dep"
APP_DIR="$WORK_DIR/app"
OUT_BIN="$TMP_DIR/path_dep.out"
BUILD_LOG="$TMP_DIR/build.log"
RUN_LOG="$TMP_DIR/run.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

cp -R "$FIXTURE" "$WORK_DIR"

"$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
test -f "$APP_DIR/uya.lock"

rm -f "$APP_DIR/uya.lock"
rm -rf "$APP_DIR/.uya/deps"

"$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
test -x "$OUT_BIN"
test -f "$APP_DIR/uya.lock"

"$OUT_BIN" >"$RUN_LOG" 2>&1
grep -q "path-dep-ok" "$RUN_LOG"

echo "verify_upm_missing_lockfile: ok"
