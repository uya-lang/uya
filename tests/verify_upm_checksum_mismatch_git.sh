#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
TMP_HOME="$(mktemp -d /tmp/uya_upm_checksum_home.XXXXXX)"
TMP_DIR="$(mktemp -d /tmp/uya_upm_checksum_mismatch.XXXXXX)"
APP_TEMPLATE="$ROOT_DIR/tests/fixtures/upm/git_dep/app"
REPO_SEED="$ROOT_DIR/tests/fixtures/upm/git_dep/repo_seed"
REPO_DIR="$TMP_DIR/repo.git"
REPO_WORK_DIR="$TMP_DIR/repo-work"
APP_DIR="$TMP_DIR/app"
OUT_BIN="$TMP_DIR/out"
LOG_FILE="$TMP_DIR/build.log"
LOCK_FILE="$APP_DIR/uya.lock"
CACHE_ROOT="$TMP_HOME/.uya/pkg/vcs"

cleanup() {
    rm -rf "$TMP_HOME" "$TMP_DIR"
}
trap cleanup EXIT

init_git_repo_fixture() {
    git init --bare "$REPO_DIR" >/dev/null
    git clone "$REPO_DIR" "$REPO_WORK_DIR" >/dev/null
    git -C "$REPO_WORK_DIR" config user.email codex@example.com
    git -C "$REPO_WORK_DIR" config user.name Codex
    cp -R "$REPO_SEED/." "$REPO_WORK_DIR/"
    git -C "$REPO_WORK_DIR" add uya.toml src/file.uya
    git -C "$REPO_WORK_DIR" commit -m "git v1" >/dev/null
    git -C "$REPO_WORK_DIR" branch -M stable
    git -C "$REPO_WORK_DIR" push origin stable >/dev/null
    git --git-dir="$REPO_DIR" symbolic-ref HEAD refs/heads/stable
}

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

init_git_repo_fixture
cp -R "$APP_TEMPLATE" "$APP_DIR"
python3 - "$APP_DIR/uya.toml.in" "$APP_DIR/uya.toml" "$REPO_DIR" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
repo = sys.argv[3]
dst.write_text(src.read_text(encoding="utf-8").replace("__GIT_URL__", repo), encoding="utf-8")
src.unlink()
PY

HOME="$TMP_HOME" "$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >/dev/null 2>&1
python3 - "$LOCK_FILE" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text(encoding='utf-8').splitlines()
out = []
replaced = False
for line in lines:
    if (not replaced) and line.startswith('content_hash = "'):
        out.append('content_hash = "broken-checksum"')
        replaced = True
    else:
        out.append(line)
if not replaced:
    raise SystemExit('content_hash line not found')
path.write_text('\n'.join(out) + '\n', encoding='utf-8')
PY
rm -rf "$CACHE_ROOT"

set +e
HOME="$TMP_HOME" "$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$LOG_FILE" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "✗ checksum mismatch 应阻止构建"
    cat "$LOG_FILE"
    exit 1
fi

grep -q 'lockfile checksum 校验失败' "$LOG_FILE"
echo "verify_upm_checksum_mismatch_git: ok"
