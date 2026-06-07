#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-implicit-entry-seed.XXXXXX)"
trap 'cleanup' EXIT

CMD_DIR="$REPO_ROOT/bin/cmd"
CMD_BACKUP="$TMP_DIR/cmd.backup"
HAD_CMD_DIR=0

cleanup() {
    rm -rf "$CMD_DIR"
    if [[ "$HAD_CMD_DIR" -ne 0 && -d "$CMD_BACKUP" ]]; then
        mkdir -p "$REPO_ROOT/bin"
        mv "$CMD_BACKUP" "$CMD_DIR"
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

if grep -Eq '^use[[:space:]]+compiler_driver;' "$REPO_ROOT/src/main.uya"; then
    echo "错误: launcher 不应再静态导入 compiler_driver" >&2
    exit 1
fi
if grep -Eq 'compiler_driver_main\(' "$REPO_ROOT/src/main.uya"; then
    echo "错误: launcher 不应再调用 compiler_driver_main" >&2
    exit 1
fi

if [[ -d "$CMD_DIR" ]]; then
    HAD_CMD_DIR=1
    mv "$CMD_DIR" "$CMD_BACKUP"
fi

set +e
UYA_ROOT="$REPO_ROOT" "$REPO_ROOT/bin/uya" "$REPO_ROOT/tests/test_errno.uya" -o "$TMP_DIR/errno" --no-split-c >"$TMP_DIR/implicit.out" 2>"$TMP_DIR/implicit.err"
implicit_status=$?
set -e

if [[ "$implicit_status" -eq 0 ]]; then
    echo "错误: 隐式编译入口已移除，bin/uya <file> 不应成功" >&2
    exit 1
fi
if [[ -x "$TMP_DIR/errno" ]]; then
    echo "错误: 隐式编译入口失败时不应生成可执行文件" >&2
    exit 1
fi
grep -q '隐式编译入口已移除' "$TMP_DIR/implicit.err"
grep -q './bin/uya build' "$TMP_DIR/implicit.err"

if [[ -e "$CMD_DIR" ]]; then
    echo "错误: 隐式入口移除路径不应依赖或重建 bin/cmd/" >&2
    exit 1
fi

echo "✓ cmd/build seed 稳定后，bin/uya 隐式编译入口已移除"
