#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"
UPM_BIN="${UYA_UPM_BIN:-$ROOT_DIR/bin/cmd/upm}"
FIXTURE="$ROOT_DIR/tests/fixtures/upm/path_dep"
TMP_HOME="$(mktemp -d /tmp/uya_upm_path_checksum_home.XXXXXX)"
TMP_DIR="$(mktemp -d /tmp/uya_upm_path_checksum.XXXXXX)"
WORK_DIR="$TMP_DIR/path_dep"
APP_DIR="$WORK_DIR/app"
OUT_BIN="$TMP_DIR/path_dep.out"
LOG_FILE="$TMP_DIR/build.log"
LOCK_FILE="$APP_DIR/uya.lock"

cleanup() {
    rm -rf "$TMP_HOME" "$TMP_DIR"
}
trap cleanup EXIT

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

cp -R "$FIXTURE" "$WORK_DIR"

HOME="$TMP_HOME" "$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >/dev/null 2>&1
python3 - "$LOCK_FILE" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
out = []
replaced = False
for line in lines:
    if (not replaced) and line.startswith('content_hash = "'):
        out.append('content_hash = "broken-checksum"')
        replaced = True
    else:
        out.append(line)
if not replaced:
    raise SystemExit("content_hash line not found")
path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY

set +e
HOME="$TMP_HOME" "$UPM_BIN" build "$APP_DIR" -o "$OUT_BIN" --no-split-c >"$LOG_FILE" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
    echo "path checksum mismatch 应阻止构建" >&2
    cat "$LOG_FILE"
    exit 1
fi

grep -q 'lockfile checksum 校验失败' "$LOG_FILE"
echo "verify_upm_checksum_mismatch_path: ok"
