#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
TMP_DIR="$(mktemp -d /tmp/uya_upm_proxy_backend.XXXXXX)"
TMP_HOME="$TMP_DIR/home"
WORK_DIR="$TMP_DIR/app"
PROXY_ROOT="$TMP_DIR/proxy"
PROXY_DEP_DIR="$PROXY_ROOT/uya.local/foo/1.2.3"
REGISTRY_ROOT="$TMP_DIR/registry"
REGISTRY_DEP_DIR="$REGISTRY_ROOT/uya.local/foo/1.2.3"
OUT_BIN="$TMP_DIR/out"
BUILD_LOG="$TMP_DIR/build.log"
RUN_LOG="$TMP_DIR/run.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

mkdir -p "$TMP_HOME" "$WORK_DIR/src" "$PROXY_DEP_DIR/src" "$REGISTRY_DEP_DIR/src"
cat > "$WORK_DIR/uya.toml" <<'EOF_MANIFEST'
[package]
name = "app"
module = "uya.local/app"
version = "0.1.0"
source-dir = "src"

[dependencies]
foo = { module = "uya.local/foo", version = "1.2.3" }
EOF_MANIFEST
cat > "$WORK_DIR/src/main.uya" <<'EOF_MAIN'
use foo.file.foo_value;

export fn main() i32 {
    @println("${foo_value()}");
    return 0;
}
EOF_MAIN
cat > "$PROXY_DEP_DIR/uya.toml" <<'EOF_DEP_MANIFEST'
[package]
name = "foo"
module = "uya.local/foo"
version = "1.2.3"
source-dir = "src"
EOF_DEP_MANIFEST
cat > "$PROXY_DEP_DIR/src/file.uya" <<'EOF_DEP_SRC'
export fn foo_value() i32 {
    return 11;
}
EOF_DEP_SRC
cat > "$REGISTRY_DEP_DIR/uya.toml" <<'EOF_REGISTRY_MANIFEST'
[package]
name = "foo"
module = "uya.local/foo"
version = "1.2.3"
source-dir = "src"
EOF_REGISTRY_MANIFEST
cat > "$REGISTRY_DEP_DIR/src/file.uya" <<'EOF_REGISTRY_SRC'
export fn foo_value() i32 {
    return 99;
}
EOF_REGISTRY_SRC

HOME="$TMP_HOME" UYA_UPM_PROXY_DIR="$PROXY_ROOT" UYA_UPM_REGISTRY_DIR="$REGISTRY_ROOT" "$UPM_BIN" build "$WORK_DIR" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
"$OUT_BIN" >"$RUN_LOG" 2>&1
grep -q '11' "$RUN_LOG"
if grep -q '99' "$RUN_LOG"; then
    echo "proxy backend did not take priority over registry" >&2
    exit 1
fi
grep -q 'module = "uya.local/foo"' "$WORK_DIR/uya.lock"
grep -q 'resolved_version = "1.2.3"' "$WORK_DIR/uya.lock"
grep -q 'content_hash = "' "$WORK_DIR/uya.lock"

echo "verify_upm_proxy_backend: ok"
