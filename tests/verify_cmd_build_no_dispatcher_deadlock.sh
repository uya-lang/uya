#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-build-no-dispatcher-deadlock.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_REPO="$TMP_DIR/repo"
mkdir -p "$FIXTURE_REPO/backup" "$FIXTURE_REPO/bin" "$FIXTURE_REPO/src/cmd/build"
printf 'fn main() i32 { return 0; }\n' >"$FIXTURE_REPO/src/cmd/build/main.uya"
printf 'cmd-build seed c\n' >"$FIXTURE_REPO/backup/cmd-build.c"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"

DISPATCHER_LOG="$TMP_DIR/dispatcher.calls"
: >"$DISPATCHER_LOG"
cat >"$FIXTURE_REPO/bin/uya" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${UYA_DISPATCHER_CALL_LOG:?}"
echo "dispatcher-only bin/uya must not compile cmd/build" >&2
exit 77
EOF
chmod +x "$FIXTURE_REPO/bin/uya"

FAKE_CC="$TMP_DIR/fake-cc.sh"
CC_LOG="$TMP_DIR/fake-cc.calls"
COMPILER_LOG="$TMP_DIR/cmd-build.calls"
: >"$CC_LOG"
: >"$COMPILER_LOG"
cat >"$FAKE_CC" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CC_LOG="${UYA_FAKE_CC_CALL_LOG:?}"
out=""
want_out=0
for arg in "$@"; do
    if [[ "$arg" == -print-file-name=* ]]; then
        echo "/tmp/fake-${arg#-print-file-name=}"
        exit 0
    fi
    if [[ "$want_out" -eq 1 ]]; then
        out="$arg"
        want_out=0
        continue
    fi
    if [[ "$arg" == "-o" ]]; then
        want_out=1
    fi
done

printf '%s\n' "$*" >>"$CC_LOG"
if [[ -z "$out" ]]; then
    echo "fake cc: missing -o" >&2
    exit 2
fi
mkdir -p "$(dirname "$out")"
cat >"$out" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
out=""
want_out=0
for arg in "$@"; do
    if [[ "$want_out" -eq 1 ]]; then
        out="$arg"
        want_out=0
        continue
    fi
    if [[ "$arg" == "-o" ]]; then
        want_out=1
    fi
done
echo "$*" >>"${UYA_FAKE_CMD_BUILD_CALL_LOG:?}"
if [[ -z "$out" ]]; then
    echo "fake cmd/build: missing -o" >&2
    exit 2
fi
mkdir -p "$(dirname "$out")"
cp "$0" "$out"
chmod +x "$out"
SCRIPT
chmod +x "$out"
EOF
chmod +x "$FAKE_CC"

if ! UYA_DISPATCHER_CALL_LOG="$DISPATCHER_LOG" \
        UYA_FAKE_CC_CALL_LOG="$CC_LOG" \
        UYA_FAKE_CMD_BUILD_CALL_LOG="$COMPILER_LOG" \
        make -C "$FIXTURE_REPO" cmd-build \
        HOST_OS=linux HOST_ARCH=x86_64 \
        CC="$FAKE_CC" CC_DRIVER="$FAKE_CC" \
        SEED_CFLAGS="-std=c99" CFLAGS="-std=c99" >"$TMP_DIR/cmd-build.out" 2>"$TMP_DIR/cmd-build.err"; then
    echo "错误: dispatcher-only fixture make cmd-build 失败" >&2
    cat "$TMP_DIR/cmd-build.out" >&2
    cat "$TMP_DIR/cmd-build.err" >&2
    exit 1
fi

if [[ -s "$DISPATCHER_LOG" ]]; then
    echo "错误: make cmd-build 调用了 dispatcher-only bin/uya，存在互等风险" >&2
    cat "$DISPATCHER_LOG" >&2
    exit 1
fi
if ! grep -q 'backup/cmd-build.c' "$CC_LOG"; then
    echo "错误: make cmd-build 未从 backup/cmd-build.c 恢复 bin/cmd/build" >&2
    cat "$CC_LOG" >&2
    exit 1
fi
if [[ ! -x "$FIXTURE_REPO/bin/cmd/build" ]]; then
    echo "错误: make cmd-build 未生成 bin/cmd/build" >&2
    exit 1
fi

echo "verify_cmd_build_no_dispatcher_deadlock: ok"
