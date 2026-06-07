#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]' | sed -e 's/darwin/macos/' -e 's/msys.*/windows/' -e 's/mingw.*/windows/' -e 's/cygwin.*/windows/')"
HOST_ARCH="$(uname -m | sed -e 's/amd64/x86_64/' -e 's/aarch64/arm64/')"
THRESHOLD_MS="${UYA_BUILD_SEED_RESTORE_TIME_BUDGET_MS:-3000}"
TMP_DIR="$(mktemp -d /tmp/uya-build-seed-restore-time.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! "$THRESHOLD_MS" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD_MS" -le 0 ]]; then
    echo "错误: UYA_BUILD_SEED_RESTORE_TIME_BUDGET_MS 必须是正整数" >&2
    exit 1
fi

BLOB_SEED="$ROOT_DIR/backup/cmd-build-${HOST_OS}-${HOST_ARCH}-blob.c"
if [[ ! -s "$BLOB_SEED" ]]; then
    echo "错误: 缺少 host/arch cmd/build 快速 blob seed: $BLOB_SEED" >&2
    exit 1
fi

now_ms() {
    local ns
    ns="$(date +%s%N)"
    if [[ "$ns" =~ ^[0-9]+$ ]]; then
        echo $((ns / 1000000))
        return
    fi
    echo $((SECONDS * 1000))
}

rm -f "$ROOT_DIR/bin/cmd/build"
start_ms="$(now_ms)"
if ! make -C "$ROOT_DIR" restore-cmd-build-seed >"$TMP_DIR/restore.out" 2>"$TMP_DIR/restore.err"; then
    echo "错误: restore-cmd-build-seed 失败" >&2
    cat "$TMP_DIR/restore.out" >&2
    cat "$TMP_DIR/restore.err" >&2
    exit 1
fi
end_ms="$(now_ms)"
elapsed_ms=$((end_ms - start_ms))

if [[ ! -x "$ROOT_DIR/bin/cmd/build" ]]; then
    echo "错误: restore-cmd-build-seed 未生成 bin/cmd/build" >&2
    cat "$TMP_DIR/restore.out" >&2
    cat "$TMP_DIR/restore.err" >&2
    exit 1
fi
if ! grep -q '快速 blob seed' "$TMP_DIR/restore.out" "$TMP_DIR/restore.err"; then
    echo "错误: restore-cmd-build-seed 未使用快速 blob seed" >&2
    cat "$TMP_DIR/restore.out" >&2
    cat "$TMP_DIR/restore.err" >&2
    exit 1
fi
if [[ "$elapsed_ms" -ge "$THRESHOLD_MS" ]]; then
    echo "错误: build seed 恢复超时: elapsed_ms=$elapsed_ms threshold_ms=$THRESHOLD_MS" >&2
    cat "$TMP_DIR/restore.out" >&2
    cat "$TMP_DIR/restore.err" >&2
    exit 1
fi

SMOKE_BIN="$TMP_DIR/errno"
if ! UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/cmd/build" "$ROOT_DIR/tests/test_errno.uya" \
        -o "$SMOKE_BIN" --no-split-c >"$TMP_DIR/smoke-build.out" 2>"$TMP_DIR/smoke-build.err"; then
    echo "错误: 恢复出的 bin/cmd/build 无法编译 smoke" >&2
    cat "$TMP_DIR/smoke-build.out" >&2
    cat "$TMP_DIR/smoke-build.err" >&2
    exit 1
fi
"$SMOKE_BIN" >"$TMP_DIR/smoke.out" 2>"$TMP_DIR/smoke.err"
grep -q 'Tests Failed:       0' "$TMP_DIR/smoke.out"

echo "verify_build_seed_restore_time: ok (elapsed_ms=$elapsed_ms threshold_ms=$THRESHOLD_MS)"
