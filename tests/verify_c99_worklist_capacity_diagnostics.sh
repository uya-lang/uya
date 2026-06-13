#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
C99_MAIN="$REPO_ROOT/src/codegen/c99/main.uya"
C99_UTILS="$REPO_ROOT/src/codegen/c99/utils.uya"
C99_BUILD_UTILS="$REPO_ROOT/src/codegen/c99_build/utils.uya"
COMPILER_DRIVER="$REPO_ROOT/src/compiler_driver.uya"
BUILD_COMPILER_DRIVER="$REPO_ROOT/src/build_compiler_driver.uya"

require_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 C99 worklist 容量 diagnostic 证据: $description" >&2
        return 1
    fi
}

reject_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: 仍存在静默 C99 worklist 上限路径: $description" >&2
        return 1
    fi
}

require_pattern "var[[:space:]]+g_c99_codegen_has_error:[[:space:]]*i32" "$C99_UTILS" "C99 codegen 模块级错误状态"
require_pattern "c99_codegen_report_capacity_error" "$C99_UTILS" "统一容量错误报告 helper"
require_pattern "g_c99_codegen_has_error[[:space:]]*=[[:space:]]*1" "$C99_UTILS" "容量错误设置失败状态"
require_pattern "g_c99_codegen_has_error[[:space:]]*!=[[:space:]]*0" "$C99_MAIN" "生成结束前返回失败"
require_pattern "mono instance worklist" "$C99_MAIN" "mono worklist 上限 diagnostic"
require_pattern "C99_MAX_MONO_INSTANCES" "$C99_MAIN" "mono worklist 上限常量"
require_pattern "reachable function worklist" "$C99_MAIN" "reachable worklist 上限 diagnostic"
require_pattern "C99_MAX_REACHABLE_FUNCTIONS" "$C99_MAIN" "reachable worklist 上限常量"
require_pattern "test worklist" "$C99_MAIN" "test worklist 上限 diagnostic"
require_pattern "MAX_TESTS" "$C99_MAIN" "test worklist 上限常量"
require_pattern "checker mono instance transfer" "$C99_UTILS" "checker mono instances 传入 C99 时超限 diagnostic"
require_pattern "checker reachable function transfer" "$C99_UTILS" "checker reachable functions 传入 C99 时超限 diagnostic"
require_pattern "checker mono instance transfer" "$C99_BUILD_UTILS" "cmd/build checker mono instances 传入 C99 时超限 diagnostic"
require_pattern "checker reachable function transfer" "$C99_BUILD_UTILS" "cmd/build checker reachable functions 传入 C99 时超限 diagnostic"
require_pattern "c99_codegen_set_mono_instances\\(c99_codegen,[[:space:]]*checker\\)[[:space:]]*!=[[:space:]]*0" "$COMPILER_DRIVER" "compiler driver 传播 mono transfer 失败"
require_pattern "c99_codegen_set_reachable_functions\\(c99_codegen,[[:space:]]*checker\\)[[:space:]]*!=[[:space:]]*0" "$COMPILER_DRIVER" "compiler driver 传播 reachable transfer 失败"
require_pattern "c99_codegen_set_mono_instances\\(c99_codegen,[[:space:]]*checker\\)[[:space:]]*!=[[:space:]]*0" "$BUILD_COMPILER_DRIVER" "build compiler driver 传播 mono transfer 失败"
require_pattern "c99_codegen_set_reachable_functions\\(c99_codegen,[[:space:]]*checker\\)[[:space:]]*!=[[:space:]]*0" "$BUILD_COMPILER_DRIVER" "build compiler driver 传播 reachable transfer 失败"
reject_pattern "mono_instance_count[[:space:]]*>=[[:space:]]*C99_MAX_MONO_INSTANCES[[:space:]]*\\{[[:space:]]*return;" "$C99_MAIN" "mono_instance_count >= C99_MAX_MONO_INSTANCES 后直接 return"
reject_pattern "idx_u[[:space:]]*>=[[:space:]]*C99_MAX_MONO_INSTANCES[[:space:]]+as[[:space:]]+usize[[:space:]]*\\{[[:space:]]*return;" "$C99_MAIN" "idx_u >= C99_MAX_MONO_INSTANCES 后直接 return"
reject_pattern "reachable_function_decl_count[[:space:]]*>=[[:space:]]*C99_MAX_REACHABLE_FUNCTIONS[[:space:]]*\\{[[:space:]]*return;" "$C99_MAIN" "reachable_function_decl_count >= C99_MAX_REACHABLE_FUNCTIONS 后直接 return"
reject_pattern "count[[:space:]]*>=[[:space:]]*MAX_TESTS[[:space:]]*\\{[[:space:]]*return[[:space:]]+0;" "$C99_MAIN" "count >= MAX_TESTS 后直接 return 0"
reject_pattern "while[[:space:]]+i[[:space:]]*<[[:space:]]*count[[:space:]]*&&[[:space:]]*i[[:space:]]*<[[:space:]]*C99_MAX_MONO_INSTANCES" "$C99_UTILS" "checker mono instances 传入 C99 时静默截断"
reject_pattern "while[[:space:]]+i[[:space:]]*<[[:space:]]*checker[.]reachable_fn_decl_count[[:space:]]*&&[[:space:]]*i[[:space:]]*<[[:space:]]*C99_MAX_REACHABLE_FUNCTIONS" "$C99_UTILS" "checker reachable functions 传入 C99 时静默截断"
reject_pattern "while[[:space:]]+i[[:space:]]*<[[:space:]]*count[[:space:]]*&&[[:space:]]*i[[:space:]]*<[[:space:]]*C99_MAX_MONO_INSTANCES" "$C99_BUILD_UTILS" "cmd/build checker mono instances 传入 C99 时静默截断"
reject_pattern "while[[:space:]]+i[[:space:]]*<[[:space:]]*checker[.]reachable_fn_decl_count[[:space:]]*&&[[:space:]]*i[[:space:]]*<[[:space:]]*C99_MAX_REACHABLE_FUNCTIONS" "$C99_BUILD_UTILS" "cmd/build checker reachable functions 传入 C99 时静默截断"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
many_tests="$tmpdir/many_tests.uya"
{
    echo "use std.testing.expect;"
    echo
    for i in $(seq 0 1000); do
        echo "test \"capacity_$i\" {"
        echo "    try expect(true);"
        echo "}"
        echo
    done
} > "$many_tests"

set +e
output="$(cd "$REPO_ROOT" && ./bin/uya test "$many_tests" --no-split-c 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
    echo "错误: 超过 MAX_TESTS 的测试集仍然编译成功，疑似静默截断" >&2
    exit 1
fi
if ! grep -Fq "test worklist" <<<"$output"; then
    echo "错误: 超过 MAX_TESTS 的测试集未输出 test worklist diagnostic" >&2
    echo "$output" >&2
    exit 1
fi

echo "✓ C99 mono/reachable/test worklist 上限路径均有明确 diagnostic"
