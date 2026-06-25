#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
TMP_DIR="$(mktemp -d /tmp/uya_upm_module_version_mismatch.XXXXXX)"
TMP_HOME="$TMP_DIR/home"
WORK_DIR="$TMP_DIR/app"
LOG_FILE="$TMP_DIR/build.log"
DEP_ONE="$TMP_DIR/foo_one"
DEP_TWO="$TMP_DIR/foo_two"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

mkdir -p "$WORK_DIR/src" "$DEP_ONE/src" "$DEP_TWO/src"
cat > "$WORK_DIR/uya.toml" <<'EOF_APP'
[package]
name = "app"
module = "uya.local/app"
version = "0.1.0"
source-dir = "src"

[dependencies]
foo1 = { path = "../foo_one", module = "uya.local/foo", version = "1.2.3" }
foo2 = { path = "../foo_two", module = "uya.local/foo", version = "1.2.3" }
EOF_APP
cat > "$WORK_DIR/src/main.uya" <<'EOF_MAIN'
export fn main() i32 {
    return 0;
}
EOF_MAIN
cat > "$DEP_ONE/uya.toml" <<'EOF_DEP1'
[package]
name = "foo"
module = "uya.local/foo"
version = "1.2.3"
source-dir = "src"
EOF_DEP1
cat > "$DEP_ONE/src/file.uya" <<'EOF_DEP1_SRC'
export fn foo_value() i32 {
    return 0;
}
EOF_DEP1_SRC
cat > "$DEP_TWO/uya.toml" <<'EOF_DEP2'
[package]
name = "foo"
module = "uya.local/foo"
version = "9.9.9"
source-dir = "src"
EOF_DEP2
cat > "$DEP_TWO/src/file.uya" <<'EOF_DEP2_SRC'
export fn foo_value() i32 {
    return 0;
}
EOF_DEP2_SRC

set +e
HOME="$TMP_HOME" "$UPM_BIN" build "$WORK_DIR" --no-split-c >"$LOG_FILE" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "✗ exact version mismatch 应阻止构建"
    cat "$LOG_FILE"
    exit 1
fi

if ! grep -q 'exact version 不匹配' "$LOG_FILE"; then
    cat "$LOG_FILE"
    exit 1
fi
echo "verify_upm_module_identity_version_mismatch: ok"
