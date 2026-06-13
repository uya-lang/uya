#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_INTERVAL="$REPO_ROOT/src/checker/interval.uya"
CHECK_BUILD_INTERVAL="$REPO_ROOT/src/checker_build/interval.uya"

reject_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: proof 动态表仍存在固定容量路径: $description" >&2
        echo "文件: $file" >&2
        return 1
    fi
}

for file in "$CHECK_INTERVAL" "$CHECK_BUILD_INTERVAL"; do
    reject_pattern "min_needed[[:space:]]*>[[:space:]]*MAX_POINTER_NAMES" "$file" \
        "pointer proof 表超过 MAX_POINTER_NAMES 后直接失败"
    reject_pattern "const[[:space:]]+next_capacity:[[:space:]]*i32[[:space:]]*=[[:space:]]*MAX_POINTER_NAMES" "$file" \
        "pointer proof 表扩容仍固定到 MAX_POINTER_NAMES"
done

tmpdir="$(mktemp -d /tmp/uya-checker-proof-dynamic.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

probe="$tmpdir/many_pointer_states.uya"
log="$tmpdir/check.log"
{
    echo "use std.runtime.entry;"
    echo "fn many_pointer_states() i32 {"
    echo "    var x: i32 = 0;"
    for i in $(seq 0 39); do
        printf '    var p%02d: &i32 = &x;\n' "$i"
    done
    echo "    return 0;"
    echo "}"
    echo "export fn main() i32 { return many_pointer_states(); }"
} > "$probe"

set +e
output="$(cd "$REPO_ROOT" && UYA_ROOT="$REPO_ROOT/lib/" ./bin/uya check "$probe" --safety-proof 2>&1)"
status=$?
set -e
printf '%s\n' "$output" > "$log"
if [[ $status -ne 0 ]]; then
    echo "错误: proof 动态表回归程序 check 失败" >&2
    cat "$log" >&2
    exit 1
fi
if grep -Eq "checker pointer (nonnull|nullable) table 容量已满" "$log"; then
    echo "错误: 超过旧 MAX_POINTER_NAMES 后仍输出 pointer proof 表容量 warning" >&2
    cat "$log" >&2
    exit 1
fi

echo "verify_checker_proof_dynamic_tables: ok"
