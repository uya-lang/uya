#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
TMP_DIR="$(mktemp -d /tmp/uya_upm_git_ref_conflict.XXXXXX)"
TMP_HOME="$TMP_DIR/home"
APP_TEMPLATE="$ROOT_DIR/tests/fixtures/upm/git_ref_conflict/app"
REPO_SEED="$ROOT_DIR/tests/fixtures/upm/git_dep/repo_seed"
REPO_DIR="$TMP_DIR/repo.git"
REPO_WORK_DIR="$TMP_DIR/repo-work"
APP_DIR="$TMP_DIR/app"
OUT_BIN="$TMP_DIR/out"
BUILD_LOG="$TMP_DIR/build.log"

cleanup() {
    rm -rf "$TMP_DIR"
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
    git -C "$REPO_WORK_DIR" tag v1.0.0
    git -C "$REPO_WORK_DIR" push origin stable --tags >/dev/null
    git --git-dir="$REPO_DIR" symbolic-ref HEAD refs/heads/stable
}

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

init_git_repo_fixture

python3 - "$REPO_WORK_DIR/src/file.uya" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text('export fn message_text() &byte {\n    return "git-v2" as &byte;\n}\n', encoding='utf-8')
PY
git -C "$REPO_WORK_DIR" add src/file.uya
git -C "$REPO_WORK_DIR" commit -m "git v2" >/dev/null
git -C "$REPO_WORK_DIR" push origin stable >/dev/null
COMMIT_V2="$(git -C "$REPO_WORK_DIR" rev-parse HEAD)"

cp -R "$APP_TEMPLATE" "$APP_DIR"
python3 - "$APP_DIR/uya.toml.in" "$APP_DIR/uya.toml" "$REPO_DIR" "$COMMIT_V2" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
repo = sys.argv[3]
commit = sys.argv[4]
text = src.read_text(encoding="utf-8")
text = text.replace("__GIT_URL__", repo).replace("__COMMIT_V2__", commit)
dst.write_text(text, encoding="utf-8")
src.unlink()
PY

set +e
HOME="$TMP_HOME" "$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$BUILD_LOG" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "✗ git ref 冲突场景意外构建成功"
    cat "$BUILD_LOG"
    exit 1
fi

if ! grep -q "git_hello" "$BUILD_LOG" || ! grep -q "ref" "$BUILD_LOG"; then
    cat "$BUILD_LOG"
    exit 1
fi

echo "verify_upm_git_ref_conflict: ok"
