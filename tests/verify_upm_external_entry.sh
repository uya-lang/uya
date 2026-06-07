#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-upm-external-entry.XXXXXX)"
trap 'cleanup' EXIT

CMD_DIR="$REPO_ROOT/bin/cmd"
CMD_BIN="$CMD_DIR/upm"
BACKUP_BIN="$TMP_DIR/upm.backup"
HAD_CMD_BIN=0

cleanup() {
    if [[ "$HAD_CMD_BIN" -ne 0 && -f "$BACKUP_BIN" ]]; then
        mkdir -p "$CMD_DIR"
        mv "$BACKUP_BIN" "$CMD_BIN"
    elif [[ "$HAD_CMD_BIN" -eq 0 ]]; then
        rm -f "$CMD_BIN"
    fi
    rm -rf "$TMP_DIR"
}

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

require_pattern "$REPO_ROOT/src/cmd/upm/main.uya" '^use[[:space:]]+upm_lib\.upm_cli_main;' "cmd/upm 导入 upm_lib CLI"
require_pattern "$REPO_ROOT/src/cmd/upm/main.uya" 'return[[:space:]]+upm_cli_main\(1\);' "cmd/upm 直接调用 upm_cli_main"
require_pattern "$REPO_ROOT/src/compiler_driver.uya" 'dispatch_external_upm\(1\)' "bin/uya upm 外部调度"

if grep -q 'COMMAND_UPM' "$REPO_ROOT/src/compiler_driver.uya"; then
    echo "错误: compiler_driver 不应把 upm 纳入内部 CommandType" >&2
    exit 1
fi

mkdir -p "$CMD_DIR"
if [[ -e "$CMD_BIN" ]]; then
    HAD_CMD_BIN=1
    mv "$CMD_BIN" "$BACKUP_BIN"
fi

"$REPO_ROOT/bin/uya" build "$REPO_ROOT/src/cmd/upm/main.uya" -o "$CMD_BIN" --no-split-c --project-root "$REPO_ROOT/src/cmd/upm/" >"$TMP_DIR/build.out" 2>"$TMP_DIR/build.err"
test -x "$CMD_BIN"

"$CMD_BIN" --help >"$TMP_DIR/direct.out" 2>"$TMP_DIR/direct.err"
"$REPO_ROOT/bin/uya" upm --help >"$TMP_DIR/dispatch.out" 2>"$TMP_DIR/dispatch.err"

grep -q 'Uya Package Manager' "$TMP_DIR/direct.out"
grep -q 'upm build' "$TMP_DIR/direct.out"
grep -q 'Uya Package Manager' "$TMP_DIR/dispatch.out"
grep -q 'upm build' "$TMP_DIR/dispatch.out"

echo "✓ upm 保持外置：cmd/upm 直调与 bin/uya upm 调度均可用"
