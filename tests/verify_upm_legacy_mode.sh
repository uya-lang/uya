#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
OUT_BIN="$(mktemp /tmp/uya_upm_legacy_mode.XXXXXX)"
BUILD_LOG="$(mktemp /tmp/uya_upm_legacy_mode_build.XXXXXX.log)"
RUN_LOG="$(mktemp /tmp/uya_upm_legacy_mode_run.XXXXXX.log)"

cleanup() {
    rm -f "$OUT_BIN" "$BUILD_LOG" "$RUN_LOG"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

"$UPM_BIN" build "$ROOT_DIR/examples/HelloWorld.uya" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
"$OUT_BIN" >"$RUN_LOG" 2>&1
grep -q "Hello, World!" "$RUN_LOG"

echo "verify_upm_legacy_mode: ok"
