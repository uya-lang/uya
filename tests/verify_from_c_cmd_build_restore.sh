#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-from-c-cmd-build-restore.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_REPO="$TMP_DIR/repo"
mkdir -p "$FIXTURE_REPO/backup"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"

cat >"$FIXTURE_REPO/backup/uya-hosted-linux-x86_64.c" <<'EOF'
int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return 0;
}
EOF

cat >"$FIXTURE_REPO/backup/cmd-build-linux-x86_64.c" <<'EOF'
int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return 0;
}
EOF

FAKE_CC="$TMP_DIR/fake-cc.sh"
CALL_LOG="$TMP_DIR/fake-cc.calls"
: >"$CALL_LOG"
cat >"$FAKE_CC" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CALL_LOG="${UYA_FAKE_CC_CALL_LOG:?}"
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

printf '%s\n' "$*" >>"$CALL_LOG"
if [[ -n "$out" ]]; then
    mkdir -p "$(dirname "$out")"
    printf 'fake executable\n' >"$out"
    chmod +x "$out"
fi
EOF
chmod +x "$FAKE_CC"

if ! UYA_FAKE_CC_CALL_LOG="$CALL_LOG" make -C "$FIXTURE_REPO" from-c \
        HOST_OS=linux HOST_ARCH=x86_64 \
        CC="$FAKE_CC" CC_DRIVER="$FAKE_CC" \
        SEED_CFLAGS="-std=c99" CFLAGS="-std=c99" >"$TMP_DIR/from-c.out" 2>"$TMP_DIR/from-c.err"; then
    echo "错误: fixture make from-c 失败" >&2
    cat "$TMP_DIR/from-c.out" >&2
    cat "$TMP_DIR/from-c.err" >&2
    exit 1
fi

if [[ ! -x "$FIXTURE_REPO/bin/uya" ]]; then
    echo "错误: from-c 未恢复 bin/uya" >&2
    cat "$TMP_DIR/from-c.out" >&2
    cat "$TMP_DIR/from-c.err" >&2
    exit 1
fi
if [[ ! -x "$FIXTURE_REPO/bin/cmd/build" ]]; then
    echo "错误: from-c 未恢复 bin/cmd/build" >&2
    cat "$TMP_DIR/from-c.out" >&2
    cat "$TMP_DIR/from-c.err" >&2
    exit 1
fi

if ! grep -q 'bin/uya.c' "$CALL_LOG"; then
    echo "错误: from-c 未编译 bin/uya.c" >&2
    cat "$CALL_LOG" >&2
    exit 1
fi
if ! grep -q 'backup/cmd-build-linux-x86_64.c' "$CALL_LOG"; then
    echo "错误: from-c 未编译 host/arch cmd-build seed" >&2
    cat "$CALL_LOG" >&2
    exit 1
fi

echo "verify_from_c_cmd_build_restore: ok"
