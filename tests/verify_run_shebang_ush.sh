#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="${UYA_COMPILER:-$ROOT_DIR/bin/uya}"
if [[ "$COMPILER" != /* ]]; then
    COMPILER="$(cd "$(dirname "$COMPILER")" && pwd)/$(basename "$COMPILER")"
fi
TMP_DIR="$(mktemp -d /tmp/uya_run_shebang_ush.XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

SCRIPT="$TMP_DIR/hello.ush"
UYA_SCRIPT="$TMP_DIR/hello.uya"
STDOUT_LOG="$TMP_DIR/stdout.log"
STDERR_LOG="$TMP_DIR/stderr.log"
UYA_STDOUT_LOG="$TMP_DIR/uya_stdout.log"
UYA_STDERR_LOG="$TMP_DIR/uya_stderr.log"
DIRECT_STDOUT_LOG="$TMP_DIR/direct_stdout.log"
DIRECT_STDERR_LOG="$TMP_DIR/direct_stderr.log"
BAD_SCRIPT="$TMP_DIR/bad_mid_file_shebang.ush"
BAD_LOG="$TMP_DIR/bad.log"

cat >"$SCRIPT" <<'EOF_USH'
#!/usr/bin/env -S uya run
export fn main() i32 {
    @println("ush shebang ok");
    return 0;
}
EOF_USH
chmod +x "$SCRIPT"

cp "$SCRIPT" "$UYA_SCRIPT"

export UYA_ROOT="${ROOT_DIR}/lib/"
"$COMPILER" run "$SCRIPT" >"$STDOUT_LOG" 2>"$STDERR_LOG"
grep -q "ush shebang ok" "$STDOUT_LOG"

"$COMPILER" run "$UYA_SCRIPT" >"$UYA_STDOUT_LOG" 2>"$UYA_STDERR_LOG"
grep -q "ush shebang ok" "$UYA_STDOUT_LOG"

if /usr/bin/env -S true >/dev/null 2>&1; then
    mkdir -p "$TMP_DIR/path"
    ln -sf "$COMPILER" "$TMP_DIR/path/uya"
    PATH="$TMP_DIR/path:$PATH" "$SCRIPT" >"$DIRECT_STDOUT_LOG" 2>"$DIRECT_STDERR_LOG"
    grep -q "ush shebang ok" "$DIRECT_STDOUT_LOG"
fi

cat >"$BAD_SCRIPT" <<'EOF_BAD_USH'
const PLACEHOLDER: i32 = 1;
#!/usr/bin/env -S uya run
export fn main() i32 {
    return PLACEHOLDER;
}
EOF_BAD_USH

if "$COMPILER" run "$BAD_SCRIPT" >"$BAD_LOG" 2>&1; then
    echo "misplaced shebang unexpectedly ran"
    cat "$BAD_LOG"
    exit 1
fi

echo "verify_run_shebang_ush: ok"
