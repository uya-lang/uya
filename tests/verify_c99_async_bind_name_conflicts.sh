#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_FILE="$REPO_ROOT/tests/test_async_bind_name_conflict.uya"
COMPILER="$REPO_ROOT/bin/uya"

for file in "$TEST_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

tmp_dir="$(mktemp -d /tmp/uya-c99-async-bind-conflict.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

"$COMPILER" build "$TEST_FILE" --c99 --no-split-c -O0 -o "$tmp_dir/main.c" >/dev/null

python3 - "$tmp_dir/main.c" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, "r", encoding="utf-8").read()

def frame_body(name: str) -> str:
    match = re.search(r"struct\s+" + re.escape(name) + r"\s*\{(?P<body>.*?)\};", text, re.S)
    if match is None:
        print(f"错误: C99 async 状态机缺少 {name}", file=sys.stderr)
        sys.exit(1)
    return match.group("body")

def bind_fields(body: str) -> list[str]:
    return re.findall(r"\b_yua_never_match\b|_uya_bind_([A-Za-z0-9_]+)\s*;", body)

sibling_fields = [name for name in bind_fields(frame_body("uya_async_sibling_async_bind_names")) if name]
if len(sibling_fields) != len(set(sibling_fields)):
    print(f"错误: sibling async frame 存在重复 await bind 字段: {sibling_fields}", file=sys.stderr)
    sys.exit(1)
if "step" not in sibling_fields:
    print("错误: sibling async frame 缺少第一个 step await bind 字段", file=sys.stderr)
    sys.exit(1)
if not any(name.startswith("step_await_") for name in sibling_fields):
    print(f"错误: sibling async frame 未给同名 step await bind 分配唯一 C 字段: {sibling_fields}", file=sys.stderr)
    sys.exit(1)

later_fields = [name for name in bind_fields(frame_body("uya_async_bind_then_later_local_same_name")) if name]
if later_fields.count("value") != 1:
    print(f"错误: later-local async frame 的 value await bind 字段不唯一: {later_fields}", file=sys.stderr)
    sys.exit(1)
if re.search(r"s->_uya_bind_value\s*=\s*6\b", text) is not None:
    print("错误: await 后同名普通局部 value 被错误写入 async bind 字段", file=sys.stderr)
    sys.exit(1)
if re.search(
    r"s->_uya_bind_value\s*=\s*r\.value;.*"
    r"s->_uya_loc_total\s*=\s*\(s->_uya_loc_total\s*\+\s*s->_uya_bind_value\);.*"
    r"s->_uya_loc_value\s*=\s*6;.*"
    r"s->_uya_loc_total\s*=\s*\(s->_uya_loc_total\s*\+\s*s->_uya_loc_value\);",
    text,
    re.S,
) is None:
    print("错误: await bind value 与后续 hoist local value 的使用顺序不正确", file=sys.stderr)
    sys.exit(1)
PY

echo "✓ C99 async bind names avoid sibling and later-local conflicts"
