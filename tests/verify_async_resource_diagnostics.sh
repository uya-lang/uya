#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

src="$work_dir/async_resource_diagnostics_probe.uya"
cat >"$src" <<'UYA'
use std.async;

fn ready(v: i32) Future<!i32> {
    const p: Poll<!i32> = Poll<!i32>.Ready(ok<i32>(v));
    return Future<!i32>{ state: p };
}

@async_fn
fn probe() Future<!i32> {
    const v: i32 = try @await ready(7);
    return v;
}

export fn main() i32 {
    const f: Future<!i32> = probe();
    const bo: !i32 = block_on<i32>(f);
    const v: i32 = bo catch {
        return 1;
    };
    if v != 7 {
        return 2;
    }
    return 0;
}
UYA

run_case() {
    local key="$1"
    local expected="$2"
    local log="$work_dir/${key}.log"

    if UYA_TEST_ARENA_FAIL_CONTEXT="$key" ../uya/bin/uya --c99 "$src" -o "$work_dir/${key}.c" >"$log" 2>&1; then
        echo "expected compile failure but succeeded: $key" >&2
        return 1
    fi

    grep -q "$expected" "$log"
}

run_case "async-await-plan" "@async_fn lowering await 点表扩容失败"
run_case "async-await-codegen" "@async_fn C99 await 元数据扩容失败"
