#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-test-entry.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENTRY_SRC="$REPO_ROOT/src/cmd/test/main.uya"
CMD_TEST_BIN="$TMP_DIR/cmd-test"

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
    echo "错误: 缺少 src/cmd/test/main.uya" >&2
    exit 1
fi

require_pattern "$ENTRY_SRC" '^use[[:space:]]+compiler_driver;' "cmd/test 导入 compiler_driver"
require_pattern "$ENTRY_SRC" 'return[[:space:]]+compiler_driver_test_main\(\);' "cmd/test 调用 compiler_driver_test_main"

"$REPO_ROOT/bin/uya" build "$ENTRY_SRC" -o "$CMD_TEST_BIN" --no-split-c --project-root "$REPO_ROOT/src/" >"$TMP_DIR/compile.out" 2>"$TMP_DIR/compile.err"
test -x "$CMD_TEST_BIN"

UYA_ROOT="$REPO_ROOT" "$CMD_TEST_BIN" "$REPO_ROOT/tests/test_errno.uya" --no-split-c >"$TMP_DIR/test.out" 2>"$TMP_DIR/test.err"
grep -q 'Tests Failed:[[:space:]]*0' "$TMP_DIR/test.out"
grep -q '总计: 1 个测试' "$TMP_DIR/test.err"
grep -q '失败: 0' "$TMP_DIR/test.err"

echo "✓ cmd/test 入口可编译，并默认执行 test CLI"
