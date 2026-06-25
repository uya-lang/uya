#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
CMD_BIN="$ROOT_DIR/bin/cmd/upm"
FIXTURE="$ROOT_DIR/tests/fixtures/upm/path_dep"
TMP_DIR="$(mktemp -d /tmp/uya_upm_temp_cleanup.XXXXXX)"
WORK_DIR="$TMP_DIR/path_dep"
APP_DIR="$WORK_DIR/app"
TMP_STAGE_ROOT="$TMP_DIR/tmp"
OUT_BIN="$TMP_DIR/upm.out"
INSTALL_LOG="$TMP_DIR/install.log"
BUILD_LOG="$TMP_DIR/build.log"
RUN_LOG="$TMP_DIR/run.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_no_stage_dirs() {
    if find "$TMP_STAGE_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'uya-upm-build-*' | grep -q .; then
        echo "✗ 检测到未清理的 upm staging 目录"
        find "$TMP_STAGE_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'uya-upm-build-*' | sort
        exit 1
    fi
}

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

cp -R "$FIXTURE" "$WORK_DIR"
mkdir -p "$TMP_STAGE_ROOT"

TMPDIR="$TMP_STAGE_ROOT" "$CMD_BIN" install "$APP_DIR" >"$INSTALL_LOG" 2>&1
assert_no_stage_dirs

TMPDIR="$TMP_STAGE_ROOT" "$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
"$OUT_BIN" >"$RUN_LOG" 2>&1
grep -q "path-dep-ok" "$RUN_LOG"
assert_no_stage_dirs

echo "verify_upm_temp_cleanup: ok"
