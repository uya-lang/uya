#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-backup-cmd-build-seed.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_REPO="$TMP_DIR/repo"
mkdir -p "$FIXTURE_REPO/bin" "$FIXTURE_REPO/scripts" "$FIXTURE_REPO/src/cmd/build"
cp "$REPO_ROOT/Makefile" "$FIXTURE_REPO/Makefile"
cp "$REPO_ROOT/scripts/generate_cmd_build_blob_seed.sh" "$FIXTURE_REPO/scripts/generate_cmd_build_blob_seed.sh"
cp "$REPO_ROOT/scripts/cmd_build_seed_key.sh" "$FIXTURE_REPO/scripts/cmd_build_seed_key.sh"
chmod +x "$FIXTURE_REPO/scripts/generate_cmd_build_blob_seed.sh"
chmod +x "$FIXTURE_REPO/scripts/cmd_build_seed_key.sh"

FAKE_COMPILER="$FIXTURE_REPO/bin/uya"
FAKE_CC="$FIXTURE_REPO/bin/fake-cc"
CALL_LOG="$TMP_DIR/compiler.calls"
CC_LOG="$TMP_DIR/cc.calls"
: >"$CALL_LOG"
: >"$CC_LOG"
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
printf 'int main(int argc, char **argv) { (void)argc; (void)argv; return 0; }\n' >"$out"
EOF
chmod +x "$FAKE_COMPILER"
cat >"$FAKE_CC" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CC_LOG="${UYA_FAKE_CC_CALL_LOG:?}"
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

printf '%s\n' "$*" >>"$CC_LOG"
if [[ -z "$out" ]]; then
    echo "fake cc: missing -o" >&2
    exit 2
fi
mkdir -p "$(dirname "$out")"
cat >"$out" <<'EOF_BIN'
#!/usr/bin/env sh
exit 0
EOF_BIN
chmod +x "$out"
EOF
chmod +x "$FAKE_CC"

if ! grep -Eq '^backup-all-seed:.*backup-cmd-build-blob-seed' "$FIXTURE_REPO/Makefile"; then
    echo "错误: backup-all-seed 未依赖 backup-cmd-build-blob-seed" >&2
    exit 1
fi
if ! grep -Eq '^backup-cmd-build-blob-seed:.*backup-cmd-build-seed' "$FIXTURE_REPO/Makefile"; then
    echo "错误: backup-cmd-build-blob-seed 未依赖 backup-cmd-build-seed" >&2
    exit 1
fi

if ! UYA_FAKE_COMPILER_CALL_LOG="$CALL_LOG" UYA_FAKE_CC_CALL_LOG="$CC_LOG" \
        make -C "$FIXTURE_REPO" backup-cmd-build-blob-seed \
        HOST_OS=linux HOST_ARCH=x86_64 CC="$FAKE_CC" CC_DRIVER="$FAKE_CC" \
        UYA_BUILD_SEED_COMPILER=./bin/uya \
        CMD_BUILD_BLOB_CFLAGS="-std=c99" >"$TMP_DIR/backup.out" 2>"$TMP_DIR/backup.err"; then
    echo "错误: backup-cmd-build-blob-seed 运行失败" >&2
    cat "$TMP_DIR/backup.out" >&2
    cat "$TMP_DIR/backup.err" >&2
    exit 1
fi

if ! UYA_FAKE_COMPILER_CALL_LOG="$CALL_LOG" UYA_FAKE_CC_CALL_LOG="$CC_LOG" \
        make -C "$FIXTURE_REPO" backup-cmd-build-blob-seed \
        HOST_OS=linux HOST_ARCH=x86_64 CC="$FAKE_CC" CC_DRIVER="$FAKE_CC" \
        UYA_BUILD_SEED_COMPILER=./bin/uya \
        CMD_BUILD_BLOB_CFLAGS="-std=c99" >"$TMP_DIR/backup-second.out" 2>"$TMP_DIR/backup-second.err"; then
    echo "错误: backup-cmd-build-blob-seed 第二次运行失败" >&2
    cat "$TMP_DIR/backup-second.out" >&2
    cat "$TMP_DIR/backup-second.err" >&2
    exit 1
fi

test -s "$FIXTURE_REPO/src/build/cmd-build.c"
test -s "$FIXTURE_REPO/backup/cmd-build.c"
test -s "$FIXTURE_REPO/backup/cmd-build-linux-x86_64.c"
test -s "$FIXTURE_REPO/backup/cmd-build-linux-x86_64-blob.c"
test -s "$FIXTURE_REPO/backup/cmd-build-linux-x86_64.sha256"
test -s "$FIXTURE_REPO/backup/cmd-build-linux-x86_64-blob.key"
cmp "$FIXTURE_REPO/src/build/cmd-build.c" "$FIXTURE_REPO/backup/cmd-build.c"
cmp "$FIXTURE_REPO/src/build/cmd-build.c" "$FIXTURE_REPO/backup/cmd-build-linux-x86_64.c"

if ! grep -q -- '--c99 src/cmd/build/main.uya -o src/build/cmd-build.c --no-split-c --project-root src/' "$CALL_LOG"; then
    echo "错误: backup-cmd-build-seed 未用 cmd/build root 生成 C seed" >&2
    cat "$CALL_LOG" >&2
    exit 1
fi
if grep -q -- '-o bin/cmd/build' "$CALL_LOG"; then
    echo "错误: backup-cmd-build-blob-seed 仍通过 Uya 二次编译 bin/cmd/build" >&2
    cat "$CALL_LOG" >&2
    exit 1
fi
if ! grep -q -- 'src/build/cmd-build.c -o bin/cmd/build' "$CC_LOG"; then
    echo "错误: backup-cmd-build-blob-seed 未复用 src/build/cmd-build.c 生成 bin/cmd/build" >&2
    cat "$CC_LOG" >&2
    exit 1
fi
compiler_call_count="$(wc -l <"$CALL_LOG" | tr -d ' ')"
if [[ "$compiler_call_count" -ne 1 ]]; then
    echo "错误: backup-cmd-build seed 缓存未生效，Uya 编译器调用次数: $compiler_call_count" >&2
    cat "$CALL_LOG" >&2
    exit 1
fi
if ! grep -q '复用已有 cmd/build C seed' "$TMP_DIR/backup-second.out"; then
    echo "错误: backup-cmd-build-seed 第二次运行未报告复用 C seed" >&2
    cat "$TMP_DIR/backup-second.out" >&2
    exit 1
fi
if ! grep -q '复用已有 cmd/build blob seed' "$TMP_DIR/backup-second.out"; then
    echo "错误: backup-cmd-build-blob-seed 第二次运行未报告复用 blob seed" >&2
    cat "$TMP_DIR/backup-second.out" >&2
    exit 1
fi

echo "verify_backup_cmd_build_seed: ok"
