#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
OUT_C="$(mktemp /tmp/uya-async-frame-desc.XXXXXX.c)"
OUT_BIN="$(mktemp /tmp/uya-async-frame-desc.XXXXXX)"

cleanup() {
    rm -f "$OUT_C" "$OUT_BIN"
}
trap cleanup EXIT

export UYA_ROOT="$REPO_ROOT/lib/"

"$COMPILER" build --c99 "$SCRIPT_DIR/test_c99_async_frame_descriptors.uya" -o "$OUT_C" >/dev/null

if ! grep -q "struct AsyncFrameDescriptor {" "$OUT_C"; then
    echo "missing AsyncFrameDescriptor type definition"
    exit 1
fi

if ! grep -q "struct AsyncFrameDescriptorTable {" "$OUT_C"; then
    echo "missing AsyncFrameDescriptorTable type definition"
    exit 1
fi

if ! grep -q "struct AsyncFrameDescriptorTable _uya_async_frame_descriptors" "$OUT_C"; then
    echo "missing async frame descriptor table"
    exit 1
fi

cc -std=c99 -O0 -g -fno-builtin "$OUT_C" -o "$OUT_BIN" -lm
"$OUT_BIN" >/dev/null

echo "verify_c99_async_frame_descriptors: ok"
