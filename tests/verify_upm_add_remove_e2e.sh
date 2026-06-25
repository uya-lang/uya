#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
TMP_DIR="$(mktemp -d /tmp/uya_upm_add_remove_e2e.XXXXXX)"
APP_DIR="$TMP_DIR/app"
DEP_DIR="$TMP_DIR/gui_uya"
OUT_BIN="$TMP_DIR/out"
RUN_LOG="$TMP_DIR/run.log"
HELP_LOG="$TMP_DIR/help.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

mkdir -p "$APP_DIR/src" "$DEP_DIR/src"
cat > "$APP_DIR/uya.toml" <<'EOF_APP_MANIFEST'
[package]
name = "app"
version = "0.1.0"
source-dir = "src"
EOF_APP_MANIFEST
cat > "$APP_DIR/src/main.uya" <<'EOF_MAIN'
use gui_uya.file;

export fn main() i32 {
    @println("${file.message()}");
    return 0;
}
EOF_MAIN
cat > "$DEP_DIR/uya.toml" <<'EOF_DEP_MANIFEST'
[package]
name = "gui_uya"
version = "0.1.0"
source-dir = "src"
EOF_DEP_MANIFEST
cat > "$DEP_DIR/src/file.uya" <<'EOF_DEP'
export fn message() &byte {
    return "dep-ok" as &byte;
}
EOF_DEP

"$ROOT_DIR/bin/cmd/upm" add gui_uya --path "$DEP_DIR" --manifest-path "$APP_DIR/uya.toml" >"$HELP_LOG" 2>&1
"$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >/dev/null 2>&1
"$OUT_BIN" >"$RUN_LOG" 2>&1
grep -q 'dep-ok' "$RUN_LOG"

"$ROOT_DIR/bin/cmd/upm" remove gui_uya --dep --manifest-path "$APP_DIR/uya.toml" >"$HELP_LOG" 2>&1
set +e
"$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$RUN_LOG" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "✗ build unexpectedly succeeded after dependency removal"
    cat "$RUN_LOG"
    exit 1
fi

grep -Eq 'gui_uya|module|依赖|模块路径段|不是目录' "$RUN_LOG"

echo "verify_upm_add_remove_e2e: ok"
