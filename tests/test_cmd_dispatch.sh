#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-dispatch.XXXXXX)"
CMD_DIR="$ROOT_DIR/bin/cmd"
CMD_BACKUP="$TMP_DIR/cmd.backup"
STAGE2="$ROOT_DIR/bin/uya-upm-stage2"
STAGE2_BACKUP="$TMP_DIR/uya-upm-stage2.backup"
HAD_CMD_DIR=0
HAD_STAGE2=0

cleanup() {
    rm -rf "$CMD_DIR"
    if [[ "$HAD_CMD_DIR" -ne 0 && -d "$CMD_BACKUP" ]]; then
        mkdir -p "$ROOT_DIR/bin"
        mv "$CMD_BACKUP" "$CMD_DIR"
    fi
    rm -f "$STAGE2"
    if [[ "$HAD_STAGE2" -ne 0 && -f "$STAGE2_BACKUP" ]]; then
        mkdir -p "$ROOT_DIR/bin"
        mv "$STAGE2_BACKUP" "$STAGE2"
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_pattern() {
    local path="$1"
    local pattern="$2"
    local description="$3"

    if ! grep -Eq "$pattern" "$path"; then
        echo "错误: 缺少 ${description}: $path" >&2
        exit 1
    fi
}

if [[ ! -x "$ROOT_DIR/bin/uya" ]]; then
    echo "错误: 缺少可执行编译器 bin/uya，请先运行 make uya" >&2
    exit 1
fi

if [[ -d "$CMD_DIR" ]]; then
    HAD_CMD_DIR=1
    mv "$CMD_DIR" "$CMD_BACKUP"
fi
if [[ -e "$STAGE2" ]]; then
    HAD_STAGE2=1
    mv "$STAGE2" "$STAGE2_BACKUP"
fi
mkdir -p "$CMD_DIR"

require_pattern "$ROOT_DIR/src/main.uya" 'launcher_dispatch_external_cmd\(first_arg as &byte\)' "公开子命令外部分发"
require_pattern "$ROOT_DIR/src/main.uya" '错误: 缺少可执行子命令 .*make cmds' "缺失子命令错误提示"

make -C "$ROOT_DIR" cmd-build >/dev/null
test -x "$CMD_DIR/build"

UYA_ROOT="$ROOT_DIR" "$CMD_DIR/build" "$ROOT_DIR/tests/test_errno.uya" -o "$TMP_DIR/direct_errno" --no-split-c >"$TMP_DIR/direct_build.out" 2>"$TMP_DIR/direct_build.err"
UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" build "$ROOT_DIR/tests/test_errno.uya" -o "$TMP_DIR/dispatch_errno" --no-split-c >"$TMP_DIR/dispatch_build.out" 2>"$TMP_DIR/dispatch_build.err"
test -x "$TMP_DIR/direct_errno"
test -x "$TMP_DIR/dispatch_errno"

"$TMP_DIR/direct_errno" >"$TMP_DIR/direct_run.out" 2>"$TMP_DIR/direct_run.err"
"$TMP_DIR/dispatch_errno" >"$TMP_DIR/dispatch_run.out" 2>"$TMP_DIR/dispatch_run.err"
cmp -s "$TMP_DIR/direct_run.out" "$TMP_DIR/dispatch_run.out"
grep -q 'libc.errno' "$TMP_DIR/dispatch_run.out"

RUN_CAPTURE="$TMP_DIR/run.argv"
RUN_EXPECTED="$TMP_DIR/run.expected"
cat >"$CMD_DIR/run" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${UYA_RUN_ARGV_CAPTURE:?}"
for arg in "$@"; do
    printf '<%s>\n' "$arg"
done >"$UYA_RUN_ARGV_CAPTURE"
SH
chmod +x "$CMD_DIR/run"

UYA_RUN_ARGV_CAPTURE="$RUN_CAPTURE" "$ROOT_DIR/bin/uya" run "$ROOT_DIR/tests/test_errno.uya" -- "two words" "--runtime=value"
cat >"$RUN_EXPECTED" <<EOF
<$ROOT_DIR/tests/test_errno.uya>
<-->
<two words>
<--runtime=value>
EOF
if ! cmp -s "$RUN_EXPECTED" "$RUN_CAPTURE"; then
    echo "错误: bin/uya run 未原样转发 -- args" >&2
    echo "--- expected ---" >&2
    cat "$RUN_EXPECTED" >&2
    echo "--- actual ---" >&2
    cat "$RUN_CAPTURE" >&2
    exit 1
fi

make -C "$ROOT_DIR" cmd-upm >/dev/null
"$ROOT_DIR/bin/uya" upm --help >"$TMP_DIR/upm_dispatch.out" 2>"$TMP_DIR/upm_dispatch.err"
"$CMD_DIR/upm" --help >"$TMP_DIR/upm_direct.out" 2>"$TMP_DIR/upm_direct.err"
grep -q 'upm build' "$TMP_DIR/upm_dispatch.out"
grep -q 'upm build' "$TMP_DIR/upm_direct.out"

rm -f "$CMD_DIR/build"
set +e
"$ROOT_DIR/bin/uya" build "$ROOT_DIR/tests/test_errno.uya" -o "$TMP_DIR/missing_errno" --no-split-c >"$TMP_DIR/missing.out" 2>"$TMP_DIR/missing.err"
STATUS=$?
set -e
if [[ "$STATUS" -eq 0 ]]; then
    echo "错误: 缺失 cmd/build 时 dispatcher 意外成功" >&2
    exit 1
fi
grep -q 'cmd/build' "$TMP_DIR/missing.err"
grep -q 'make cmds' "$TMP_DIR/missing.err"

echo "test_cmd_dispatch: ok"
