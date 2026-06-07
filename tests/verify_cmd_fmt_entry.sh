#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-fmt-entry.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENTRY_SRC="$REPO_ROOT/src/cmd/fmt/main.uya"
CMD_FMT_BIN="$TMP_DIR/cmd-fmt"
FMT_INPUT="$TMP_DIR/test_errno.uya"

require_pattern() {
    local path="$1"
    local pattern="$2"
    local description="$3"

    if ! grep -Eq "$pattern" "$path"; then
        echo "错误: 缺少 ${description}: $path" >&2
        exit 1
    fi
}

if [[ ! -x "$REPO_ROOT/bin/uya" ]]; then
    echo "错误: 缺少可执行编译器 bin/uya，请先运行 make uya" >&2
    exit 1
fi

if [[ ! -f "$ENTRY_SRC" ]]; then
    echo "错误: 缺少 src/cmd/fmt/main.uya" >&2
    exit 1
fi

require_pattern "$ENTRY_SRC" '^use[[:space:]]+fmt;' "cmd/fmt 导入 fmt"
require_pattern "$ENTRY_SRC" 'return[[:space:]]+uyafmt_main\(\);' "cmd/fmt 调用 uyafmt_main"

"$REPO_ROOT/bin/uya" build "$ENTRY_SRC" -o "$CMD_FMT_BIN" --no-split-c --project-root "$REPO_ROOT/src/" >"$TMP_DIR/compile.out" 2>"$TMP_DIR/compile.err"
test -x "$CMD_FMT_BIN"

cp "$REPO_ROOT/tests/test_errno.uya" "$FMT_INPUT"
UYA_ROOT="$REPO_ROOT" "$CMD_FMT_BIN" "$FMT_INPUT" >"$TMP_DIR/fmt.out" 2>"$TMP_DIR/fmt.err"
grep -q 'fn main() i32' "$TMP_DIR/fmt.out"
grep -q 'test_suite_begin' "$TMP_DIR/fmt.out"

echo "✓ cmd/fmt 入口可编译，并直接调用 formatter CLI"
