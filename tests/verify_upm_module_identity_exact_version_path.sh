#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
TMP_DIR="$(mktemp -d /tmp/uya_upm_module_identity.XXXXXX)"
TMP_HOME="$TMP_DIR/home"
WORK_DIR="$TMP_DIR/app"
LOG_FILE="$TMP_DIR/build.log"
DEP_DIR="$TMP_DIR/foo_pkg"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

mkdir -p "$WORK_DIR/src" "$DEP_DIR/src"
cat > "$WORK_DIR/uya.toml" <<'EOF_APP'
[package]
name = "app"
module = "uya.local/app"
version = "0.1.0"
source-dir = "src"

[dependencies]
foo = { path = "../foo_pkg", module = "uya.local/foo", version = "1.2.3" }
EOF_APP
cat > "$WORK_DIR/src/main.uya" <<'EOF_MAIN'
use foo.file.foo_value;

export fn main() i32 {
    return foo_value();
}
EOF_MAIN
cat > "$DEP_DIR/uya.toml" <<'EOF_DEP'
[package]
name = "foo"
module = "uya.local/foo"
version = "1.2.3"
source-dir = "src"
EOF_DEP
cat > "$DEP_DIR/src/file.uya" <<'EOF_DEP_SRC'
export fn foo_value() i32 {
    return 0;
}
EOF_DEP_SRC

HOME="$TMP_HOME" "$UPM_BIN" build "$WORK_DIR" --no-split-c >"$LOG_FILE" 2>&1
grep -q 'resolved_version = "1.2.3"' "$WORK_DIR/uya.lock"
grep -q 'content_hash = "' "$WORK_DIR/uya.lock"
test -f "$TMP_HOME/.uya/pkg/mod/uya.local/foo/1.2.3/uya.toml"
test -f "$TMP_HOME/.uya/pkg/mod/uya.local/foo/1.2.3/src/file.uya"

echo "verify_upm_module_identity_exact_version_path: ok"
