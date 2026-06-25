#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
TMP_DIR="$(mktemp -d /tmp/uya_cmd_upm_direct.XXXXXX)"
HELP_LOG="$TMP_DIR/help.log"
VERSION_LOG="$TMP_DIR/version.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$UPM_BIN" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

"$UPM_BIN" --help >"$HELP_LOG" 2>&1
"$UPM_BIN" --version >"$VERSION_LOG" 2>&1

grep -q "upm build" "$HELP_LOG"
grep -q "upm draft" "$VERSION_LOG"

echo "test_cmd_upm_direct: ok"
