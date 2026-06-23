#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-build-entry.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENTRY_SRC="$REPO_ROOT/src/cmd/build/main.uya"
CMD_BUILD_BIN="$TMP_DIR/cmd-build"

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
    echo "错误: 缺少 src/cmd/build/main.uya" >&2
    exit 1
fi

if grep -Eq '^use[[:space:]]+build_compiler_driver;' "$ENTRY_SRC"; then
    require_pattern "$ENTRY_SRC" 'return[[:space:]]+build_compiler_driver_main\(\);' "cmd/build 调用 build_compiler_driver_main"
else
    require_pattern "$ENTRY_SRC" '^use[[:space:]]+compiler_driver;' "cmd/build 导入 compiler_driver"
    require_pattern "$ENTRY_SRC" 'return[[:space:]]+compiler_driver_build_main\(\);' "cmd/build 调用 compiler_driver_build_main"
fi

"$REPO_ROOT/bin/uya" build "$ENTRY_SRC" -o "$CMD_BUILD_BIN" --no-split-c --project-root "$REPO_ROOT/src/" >"$TMP_DIR/compile.out" 2>"$TMP_DIR/compile.err"
test -x "$CMD_BUILD_BIN"

UYA_ROOT="$REPO_ROOT" "$CMD_BUILD_BIN" "$REPO_ROOT/tests/test_errno.uya" -o "$TMP_DIR/errno" --no-split-c >"$TMP_DIR/build.out" 2>"$TMP_DIR/build.err"
test -x "$TMP_DIR/errno"

echo "✓ cmd/build 入口可编译，并可直接执行 build CLI"
