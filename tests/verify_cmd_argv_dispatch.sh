#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-argv-dispatch.XXXXXX)"
trap 'cleanup' EXIT

CMD_DIR="$REPO_ROOT/bin/cmd"
CMD_BUILD="$CMD_DIR/build"
BACKUP_BUILD="$TMP_DIR/build.backup"
CAPTURE="$TMP_DIR/argv.capture"
EXPECTED="$TMP_DIR/argv.expected"
HAD_BUILD=0

cleanup() {
    if [[ "$HAD_BUILD" -ne 0 && -f "$BACKUP_BUILD" ]]; then
        mkdir -p "$CMD_DIR"
        mv "$BACKUP_BUILD" "$CMD_BUILD"
    elif [[ "$HAD_BUILD" -eq 0 ]]; then
        rm -f "$CMD_BUILD"
    fi
    rm -rf "$TMP_DIR"
}

if [[ ! -x "$REPO_ROOT/bin/uya" ]]; then
    echo "错误: 缺少可执行编译器 bin/uya，请先运行 make uya" >&2
    exit 1
fi

mkdir -p "$CMD_DIR"
if [[ -e "$CMD_BUILD" ]]; then
    HAD_BUILD=1
    mv "$CMD_BUILD" "$BACKUP_BUILD"
fi

cat >"$CMD_BUILD" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${UYA_ARGV_CAPTURE:?}"
for arg in "$@"; do
    printf '<%s>\n' "$arg"
done >"$UYA_ARGV_CAPTURE"
SH
chmod +x "$CMD_BUILD"

UYA_ARGV_CAPTURE="$CAPTURE" "$REPO_ROOT/bin/uya" build "path with spaces/main.uya" "--flag=value" "two words" -- "--runtime arg"

cat >"$EXPECTED" <<'EOF'
<path with spaces/main.uya>
<--flag=value>
<two words>
<-->
<--runtime arg>
EOF

if ! cmp -s "$EXPECTED" "$CAPTURE"; then
    echo "错误: bin/uya build 未原样转发 argv" >&2
    echo "--- expected ---" >&2
    cat "$EXPECTED" >&2
    echo "--- actual ---" >&2
    cat "$CAPTURE" >&2
    exit 1
fi

echo "✓ bin/uya 子命令通过 execve 原样转发 argv"
