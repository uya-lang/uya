#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-compiler-driver-split.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

MAIN_SRC="$REPO_ROOT/src/main.uya"
DRIVER_SRC="$REPO_ROOT/src/compiler_driver.uya"
UYA_BIN="$REPO_ROOT/bin/uya"

require_pattern() {
    local path="$1"
    local pattern="$2"
    local description="$3"

    if ! grep -Eq "$pattern" "$path"; then
        echo "错误: 缺少 ${description}: $path" >&2
        exit 1
    fi
}

reject_pattern() {
    local path="$1"
    local pattern="$2"
    local description="$3"

    if grep -Eq "$pattern" "$path"; then
        echo "错误: 不应出现 ${description}: $path" >&2
        exit 1
    fi
}

if [[ ! -x "$UYA_BIN" ]]; then
    echo "错误: 缺少可执行编译器 bin/uya，请先运行 make uya" >&2
    exit 1
fi

if [[ ! -f "$DRIVER_SRC" ]]; then
    echo "错误: 缺少 src/compiler_driver.uya" >&2
    exit 1
fi

require_pattern "$MAIN_SRC" '^use[[:space:]]+compiler_driver;' "launcher 导入 compiler_driver"
require_pattern "$MAIN_SRC" 'return[[:space:]]+compiler_driver_main\(\);' "launcher 调用 compiler_driver_main"
reject_pattern "$MAIN_SRC" 'fn[[:space:]]+compile_files[[:space:]]*\(' "编译业务仍留在 src/main.uya"
require_pattern "$DRIVER_SRC" 'export[[:space:]]+fn[[:space:]]+compiler_driver_main[[:space:]]*\(' "driver 导出 compiler_driver_main"
require_pattern "$DRIVER_SRC" 'fn[[:space:]]+compile_files[[:space:]]*\(' "driver 承载 compile_files"
require_pattern "$DRIVER_SRC" 'fn[[:space:]]+parse_args[[:space:]]*\(' "driver 承载 parse_args"
reject_pattern "$DRIVER_SRC" '^use[[:space:]]+main;' "compiler_driver 反向导入 launcher"

"$UYA_BIN" --version >"$TMP_DIR/version.out"
grep -q '^v' "$TMP_DIR/version.out"

"$UYA_BIN" check "$REPO_ROOT/tests/check_cli_no_main.uya" >"$TMP_DIR/check.out" 2>"$TMP_DIR/check.err"
grep -q '检查完成：checker 通过' "$TMP_DIR/check.err"

"$UYA_BIN" build "$REPO_ROOT/tests/test_errno.uya" -o "$TMP_DIR/errno_build" --no-split-c >"$TMP_DIR/build.out" 2>"$TMP_DIR/build.err"
test -x "$TMP_DIR/errno_build"

"$UYA_BIN" "$REPO_ROOT/tests/test_errno.uya" -o "$TMP_DIR/errno_implicit" --no-split-c >"$TMP_DIR/implicit.out" 2>"$TMP_DIR/implicit.err"
test -x "$TMP_DIR/errno_implicit"

"$UYA_BIN" fmt "$REPO_ROOT/tests/test_errno.uya" >"$TMP_DIR/fmt.out"
test -s "$TMP_DIR/fmt.out"

echo "✓ compiler_driver 提取后 launcher/check/build/implicit/fmt 行为保持可用"
