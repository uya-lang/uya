#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
DRIVER_ARGS=("$@")

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

await_count=4097
last_idx=$((await_count - 1))
final_state=$((await_count + 1))
src="$work_dir/test_async_await_capacity_${await_count}.uya"
out_c="$work_dir/test_async_await_capacity_${await_count}.c"
{
    cat <<'UYA_HEAD'
use std.async;
use std.testing.assert_eq_i32;

fn ready(v: i32) Future<!i32> {
    const p: Poll<!i32> = Poll<!i32>.Ready(ok<i32>(v));
    return Future<!i32>{ state: p };
}

@async_fn
fn await_many_segments() Future<!i32> {
UYA_HEAD
    i=0
    while [ "$i" -lt "$await_count" ]; do
        echo "    const a$i: i32 = try @await ready($i);"
        i=$((i + 1))
    done
    cat <<UYA_TAIL
    return a${last_idx};
}

test "async_await_capacity_${await_count}_segments" {
    const f: Future<!i32> = await_many_segments();
    const bo: !i32 = block_on<i32>(f);
    const v: i32 = bo catch { 0 - 1; };
    try assert_eq_i32(v, ${last_idx});
}
UYA_TAIL
} >"$src"

"$COMPILER" "${DRIVER_ARGS[@]}" --c99 "$src" -o "$out_c"
grep -q "if (s->state == ${final_state})" "$out_c"
