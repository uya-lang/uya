#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-build-seed-bootstrap.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_REPO="$TMP_DIR/repo"
mkdir -p "$FIXTURE_REPO/backup" "$FIXTURE_REPO/src/cmd/build" "$FIXTURE_REPO/tests"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"

cat >"$FIXTURE_REPO/backup/uya.c" <<'EOF'
int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return 0;
}
EOF

cat >"$FIXTURE_REPO/backup/cmd-build.c" <<'EOF'
int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return 0;
}
EOF

printf 'fn main() i32 { return 0; }\n' >"$FIXTURE_REPO/src/cmd/build/main.uya"
printf 'fn main() i32 { return 0; }\n' >"$FIXTURE_REPO/tests/smoke.uya"

FAKE_CC="$TMP_DIR/fake-cc.sh"
CC_LOG="$TMP_DIR/fake-cc.calls"
DISPATCHER_LOG="$TMP_DIR/dispatcher.calls"
CMD_BUILD_LOG="$TMP_DIR/cmd-build.calls"
: >"$CC_LOG"
: >"$DISPATCHER_LOG"
: >"$CMD_BUILD_LOG"

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
if [[ -z "$out" ]]; then
    echo "fake cc: missing -o" >&2
    exit 2
fi
mkdir -p "$(dirname "$out")"

case "$out" in
    bin/uya|*/bin/uya)
        cat >"$out" <<'SCRIPT'
#!/usr/bin/env bash
echo "$*" >>"${UYA_DISPATCHER_CALL_LOG:?}"
echo "dispatcher-only bin/uya must not compile during build seed bootstrap" >&2
exit 77
SCRIPT
        ;;
    bin/cmd/build|*/bin/cmd/build)
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
cat >"$out" <<'PROGRAM'
#!/usr/bin/env bash
exit 0
PROGRAM
chmod +x "$out"
SCRIPT
        ;;
    *)
        printf '#!/usr/bin/env bash\nexit 0\n' >"$out"
        ;;
esac
chmod +x "$out"
EOF
chmod +x "$FAKE_CC"

run_make_from_c() {
    UYA_FAKE_CC_CALL_LOG="$CC_LOG" \
        UYA_DISPATCHER_CALL_LOG="$DISPATCHER_LOG" \
        make -C "$FIXTURE_REPO" from-c \
        HOST_OS=linux HOST_ARCH=x86_64 \
        CC="$FAKE_CC" CC_DRIVER="$FAKE_CC" \
        SEED_CFLAGS="-std=c99" CFLAGS="-std=c99" \
        >"$TMP_DIR/from-c.out" 2>"$TMP_DIR/from-c.err"
}

if ! run_make_from_c; then
    echo "错误: build seed fixture make from-c 失败" >&2
    cat "$TMP_DIR/from-c.out" >&2
    cat "$TMP_DIR/from-c.err" >&2
    exit 1
fi

test -x "$FIXTURE_REPO/bin/uya"
test -x "$FIXTURE_REPO/bin/cmd/build"

if ! grep -q 'bin/uya.c' "$CC_LOG"; then
    echo "错误: build seed bootstrap 未编译 bin/uya.c" >&2
    cat "$CC_LOG" >&2
    exit 1
fi
if ! grep -q 'backup/cmd-build.c' "$CC_LOG"; then
    echo "错误: build seed bootstrap 未恢复通用 cmd-build seed" >&2
    cat "$CC_LOG" >&2
    exit 1
fi

SMOKE_OUT="$TMP_DIR/smoke"
if ! UYA_FAKE_CMD_BUILD_CALL_LOG="$CMD_BUILD_LOG" \
        "$FIXTURE_REPO/bin/cmd/build" "$FIXTURE_REPO/tests/smoke.uya" \
        -o "$SMOKE_OUT" --no-split-c >"$TMP_DIR/smoke-build.out" 2>"$TMP_DIR/smoke-build.err"; then
    echo "错误: 恢复出的 bin/cmd/build 无法编译 smoke" >&2
    cat "$TMP_DIR/smoke-build.out" >&2
    cat "$TMP_DIR/smoke-build.err" >&2
    exit 1
fi
"$SMOKE_OUT"

rm -f "$FIXTURE_REPO/bin/cmd/build"
if ! UYA_FAKE_CC_CALL_LOG="$CC_LOG" \
        UYA_DISPATCHER_CALL_LOG="$DISPATCHER_LOG" \
        make -C "$FIXTURE_REPO" cmd-build \
        HOST_OS=linux HOST_ARCH=x86_64 \
        CC="$FAKE_CC" CC_DRIVER="$FAKE_CC" \
        SEED_CFLAGS="-std=c99" CFLAGS="-std=c99" \
        >"$TMP_DIR/cmd-build.out" 2>"$TMP_DIR/cmd-build.err"; then
    echo "错误: build seed fixture make cmd-build 失败" >&2
    cat "$TMP_DIR/cmd-build.out" >&2
    cat "$TMP_DIR/cmd-build.err" >&2
    exit 1
fi

if [[ -s "$DISPATCHER_LOG" ]]; then
    echo "错误: build seed bootstrap 调用了 dispatcher-only bin/uya" >&2
    cat "$DISPATCHER_LOG" >&2
    exit 1
fi
test -x "$FIXTURE_REPO/bin/cmd/build"

echo "verify_build_seed_bootstrap: ok"
