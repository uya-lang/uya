#!/usr/bin/env bash
# 验证仓库内有源码入口的 cmd 子命令使用 --nostdlib 静态链接，没有动态 libc 依赖。
set -euo pipefail
export LANG=C LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_CMD_DIR="$ROOT_DIR/src/cmd"
CMD_DIR="$ROOT_DIR/bin/cmd"

if [ "${UYA_CMD_STATIC_SKIP_BUILD:-0}" != "1" ]; then
    make -C "$ROOT_DIR" cmds >/dev/null
fi

if [ ! -d "$CMD_DIR" ]; then
    echo "error: missing cmd output directory: $CMD_DIR" >&2
    exit 1
fi

found=0
while IFS= read -r main_file; do
    cmd_name="$(basename "$(dirname "$main_file")")"
    cmd_bin="$CMD_DIR/$cmd_name"
    found=1
    if [ ! -x "$cmd_bin" ]; then
        echo "error: cmd binary is not executable: $cmd_bin" >&2
        exit 1
    fi
    if ! file "$cmd_bin" | grep -q 'statically linked'; then
        echo "error: cmd binary is not statically linked: $cmd_bin" >&2
        file "$cmd_bin" >&2
        exit 1
    fi
    if readelf -d "$cmd_bin" 2>/dev/null | grep -q '(NEEDED)'; then
        echo "error: cmd binary has dynamic dependencies: $cmd_bin" >&2
        readelf -d "$cmd_bin" >&2 || true
        exit 1
    fi
done < <(find "$SRC_CMD_DIR" -mindepth 2 -maxdepth 2 -name main.uya | sort)

while IFS= read -r cmd_bin; do
    cmd_name="$(basename "$cmd_bin")"
    if [ ! -f "$SRC_CMD_DIR/$cmd_name/main.uya" ]; then
        echo "error: stale cmd binary has no source entry: $cmd_bin" >&2
        exit 1
    fi
done < <(find "$CMD_DIR" -maxdepth 1 -type f -perm -111 | sort)

if [ "$found" -eq 0 ]; then
    echo "error: no cmd sources found under $SRC_CMD_DIR" >&2
    exit 1
fi

echo "verify_cmd_bins_nostdlib_static: ok"
