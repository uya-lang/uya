#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-check-entry.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENTRY_SRC="$REPO_ROOT/src/cmd/check/main.uya"
CMD_CHECK_BIN="$TMP_DIR/cmd-check"

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
    echo "错误: 缺少 src/cmd/check/main.uya" >&2
    exit 1
fi

require_pattern "$ENTRY_SRC" '^use[[:space:]]+compiler_driver;' "cmd/check 导入 compiler_driver"
require_pattern "$ENTRY_SRC" 'return[[:space:]]+compiler_driver_check_main\(\);' "cmd/check 调用 compiler_driver_check_main"

"$REPO_ROOT/bin/uya" build "$ENTRY_SRC" -o "$CMD_CHECK_BIN" --no-split-c --project-root "$REPO_ROOT/src/" >"$TMP_DIR/compile.out" 2>"$TMP_DIR/compile.err"
test -x "$CMD_CHECK_BIN"

UYA_ROOT="$REPO_ROOT" "$CMD_CHECK_BIN" "$REPO_ROOT/tests/check_cli_no_main.uya" >"$TMP_DIR/check.out" 2>"$TMP_DIR/check.err"
grep -q '检查完成：checker 通过' "$TMP_DIR/check.err"

echo "✓ cmd/check 入口可编译，并默认执行 checker-only CLI"
