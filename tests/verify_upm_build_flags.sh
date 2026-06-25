#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
FIXTURE="$ROOT_DIR/tests/fixtures/upm/path_dep"
TMP_DIR="$(mktemp -d /tmp/uya_upm_build_flags.XXXXXX)"
WORK_DIR="$TMP_DIR/path_dep"
APP_DIR="$WORK_DIR/app"
SPLIT_OUT="$TMP_DIR/path_dep_split.out"
SPLIT_LOG="$TMP_DIR/split.log"
RUN_LOG="$TMP_DIR/run.log"
SPLIT_DIR="$TMP_DIR/split-c"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

cp -R "$FIXTURE" "$WORK_DIR"

"$UPM_BIN" build --split-c-dir "$SPLIT_DIR" "$APP_DIR" -o "$SPLIT_OUT" >"$SPLIT_LOG" 2>&1
test -x "$SPLIT_OUT"
"$SPLIT_OUT" >"$RUN_LOG" 2>&1
grep -q "path-dep-ok" "$RUN_LOG"

echo "verify_upm_build_flags: ok"
