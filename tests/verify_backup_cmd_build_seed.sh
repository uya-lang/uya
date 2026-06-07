#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-backup-cmd-build-seed.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_REPO="$TMP_DIR/repo"
mkdir -p "$FIXTURE_REPO/bin" "$FIXTURE_REPO/src/cmd/build"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"

FAKE_COMPILER="$FIXTURE_REPO/bin/uya"
CALL_LOG="$TMP_DIR/compiler.calls"
: >"$CALL_LOG"
cat >"$FAKE_COMPILER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CALL_LOG="${UYA_FAKE_COMPILER_CALL_LOG:?}"
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

printf '%s\n' "$*" >>"$CALL_LOG"
if [[ -z "$out" ]]; then
    echo "fake compiler: missing -o" >&2
    exit 2
fi
mkdir -p "$(dirname "$out")"
printf 'cmd-build seed c\n' >"$out"
EOF
chmod +x "$FAKE_COMPILER"

if ! grep -Eq '^backup-all-seed:.*backup-cmd-build-blob-seed' "$FIXTURE_REPO/Makefile"; then
    echo "错误: backup-all-seed 未依赖 backup-cmd-build-blob-seed" >&2
    exit 1
fi
if ! grep -Eq '^backup-cmd-build-blob-seed:.*backup-cmd-build-seed' "$FIXTURE_REPO/Makefile"; then
    echo "错误: backup-cmd-build-blob-seed 未依赖 backup-cmd-build-seed" >&2
    exit 1
fi

if ! UYA_FAKE_COMPILER_CALL_LOG="$CALL_LOG" make -C "$FIXTURE_REPO" backup-cmd-build-seed \
        HOST_OS=linux HOST_ARCH=x86_64 >"$TMP_DIR/backup.out" 2>"$TMP_DIR/backup.err"; then
    echo "错误: backup-cmd-build-seed 运行失败" >&2
    cat "$TMP_DIR/backup.out" >&2
    cat "$TMP_DIR/backup.err" >&2
    exit 1
fi

test -s "$FIXTURE_REPO/src/build/cmd-build.c"
test -s "$FIXTURE_REPO/backup/cmd-build.c"
test -s "$FIXTURE_REPO/backup/cmd-build-linux-x86_64.c"
cmp "$FIXTURE_REPO/src/build/cmd-build.c" "$FIXTURE_REPO/backup/cmd-build.c"
cmp "$FIXTURE_REPO/src/build/cmd-build.c" "$FIXTURE_REPO/backup/cmd-build-linux-x86_64.c"

if ! grep -q -- '--c99 src/cmd/build/main.uya -o src/build/cmd-build.c --no-split-c --project-root src/' "$CALL_LOG"; then
    echo "错误: backup-cmd-build-seed 未用 cmd/build root 生成 C seed" >&2
    cat "$CALL_LOG" >&2
    exit 1
fi

echo "verify_backup_cmd_build_seed: ok"
