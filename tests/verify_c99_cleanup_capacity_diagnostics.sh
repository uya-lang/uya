#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
C99_GLOBAL="$REPO_ROOT/src/codegen/c99/global.uya"
C99_STMT="$REPO_ROOT/src/codegen/c99/stmt.uya"
C99_EXPR="$REPO_ROOT/src/codegen/c99/expr.uya"
C99_FUNCTION="$REPO_ROOT/src/codegen/c99/function.uya"
C99_MAIN="$REPO_ROOT/src/codegen/c99/main.uya"

require_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 C99 locals/defer/drop 容量 diagnostic 证据: $description" >&2
        return 1
    fi
}

reject_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: 仍存在静默 C99 locals/defer/drop 上限路径: $description" >&2
        return 1
    fi
}

require_pattern "local variable registry" "$C99_GLOBAL" "统一 local variable registry diagnostic"
require_pattern "defer stack" "$C99_STMT" "defer stack depth diagnostic"
require_pattern "defer block" "$C99_STMT" "defer/errdefer per-block diagnostic"
require_pattern "drop cleanup stack" "$C99_STMT" "drop cleanup stack diagnostic"
require_pattern "drop cleanup block" "$C99_STMT" "drop cleanup per-block diagnostic"
require_pattern "g_c99_codegen_has_error[[:space:]]*!=[[:space:]]*0" "$C99_MAIN" "生成结束前传播 cleanup diagnostic"

reject_pattern "local_variable_count[[:space:]]*< C99_MAX_LOCAL_VARS[[:space:]]*\\{[[:space:]]*c99_push_local_variable" "$C99_FUNCTION" "函数参数 local 满后跳过登记"
reject_pattern "local_variable_count[[:space:]]*< C99_MAX_LOCAL_VARS[[:space:]]*\\{[[:space:]]*c99_push_local_variable" "$C99_STMT" "语句 local 满后跳过登记"
reject_pattern "local_variable_count[[:space:]]*< C99_MAX_LOCAL_VARS[[:space:]]*\\{[[:space:]]*c99_push_local_variable" "$C99_EXPR" "表达式 local 满后跳过登记"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
probe="$tmpdir/many_locals.uya"
out="$tmpdir/many_locals.out"
defer_probe="$tmpdir/many_defers.uya"
defer_out="$tmpdir/many_defers.out"
drop_probe="$tmpdir/many_drops.uya"
drop_out="$tmpdir/many_drops.out"
{
    echo "fn c99_local_seed() i32 { return 0; }"
    echo ""
    echo "export fn main() i32 {"
    for i in $(seq 0 1024); do
        printf '    var local_%04d: i32 = c99_local_seed();\n' "$i"
    done
    echo "    return 0;"
    echo "}"
} > "$probe"

set +e
output="$(cd "$REPO_ROOT" && ./bin/uya build "$probe" -o "$out" --no-split-c 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
    echo "错误: 超过 C99_MAX_LOCAL_VARS 的程序仍然编译成功，疑似静默跳过 local registry" >&2
    exit 1
fi
if ! grep -Fq "local variable registry" <<<"$output"; then
    echo "错误: 超过 C99_MAX_LOCAL_VARS 的程序未输出 local variable registry diagnostic" >&2
    echo "$output" >&2
    exit 1
fi

{
    echo "export fn main() i32 {"
    echo "    var marker: i32 = 0;"
    for i in $(seq 0 128); do
        echo "    defer { marker = marker + 1; }"
    done
    echo "    return marker;"
    echo "}"
} > "$defer_probe"

set +e
output="$(cd "$REPO_ROOT" && ./bin/uya build "$defer_probe" -o "$defer_out" --no-split-c 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
    echo "错误: 超过 C99_MAX_DEFERS_PER_BLOCK 的程序仍然编译成功，疑似静默跳过 defer block" >&2
    exit 1
fi
if ! grep -Fq "defer block" <<<"$output"; then
    echo "错误: 超过 C99_MAX_DEFERS_PER_BLOCK 的程序未输出 defer block diagnostic" >&2
    echo "$output" >&2
    exit 1
fi

{
    echo "struct S {"
    echo "    id: i32,"
    echo "    fn drop(self: S) void { }"
    echo "}"
    echo ""
    echo "export fn main() i32 {"
    for i in $(seq 0 128); do
        printf '    var item_%03d: S = S{ id: %d };\n' "$i" "$i"
    done
    echo "    return 0;"
    echo "}"
} > "$drop_probe"

set +e
output="$(cd "$REPO_ROOT" && ./bin/uya build "$drop_probe" -o "$drop_out" --no-split-c 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
    echo "错误: 超过 C99_MAX_DROP_VARS_PER_BLOCK 的程序仍然编译成功，疑似静默跳过 drop cleanup block" >&2
    exit 1
fi
if ! grep -Fq "drop cleanup block" <<<"$output"; then
    echo "错误: 超过 C99_MAX_DROP_VARS_PER_BLOCK 的程序未输出 drop cleanup block diagnostic" >&2
    echo "$output" >&2
    exit 1
fi

echo "✓ C99 locals/defer/drop 上限路径均有明确 diagnostic"
