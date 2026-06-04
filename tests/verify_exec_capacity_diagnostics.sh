#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXEC_LOWER="$REPO_ROOT/src/exec/lower.uya"
EXEC_BUILDER="$REPO_ROOT/src/exec/builder.uya"
EXEC_VM="$REPO_ROOT/src/exec/vm.uya"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

require_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 exec 固定表容量 diagnostic 证据: $description" >&2
        return 1
    fi
}

reject_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: 仍存在静默 exec 固定表上限路径: $description" >&2
        return 1
    fi
}

require_pattern "exec: local slot table" "$EXEC_LOWER" "lower local/slot 表上限 diagnostic"
require_pattern "exec: interface method table" "$EXEC_LOWER" "interface method 表上限 diagnostic"
require_pattern "exec: module global request table" "$EXEC_LOWER" "module global request 表上限 diagnostic"
require_pattern "exec: hostcall site 超出上限" "$EXEC_BUILDER" "hostcall site 表上限 diagnostic"
require_pattern "exec: const pool 超出上限" "$EXEC_BUILDER" "const pool 上限 diagnostic"
require_pattern "exec: bytecode 指令超出上限" "$EXEC_BUILDER" "bytecode 指令上限 diagnostic"
require_pattern "exec: frame slot 超出上限" "$EXEC_BUILDER" "frame slot 上限 diagnostic"
require_pattern "exec: cleanup scope 嵌套过深" "$EXEC_BUILDER" "cleanup scope 上限 diagnostic"
require_pattern "exec: VM CALL 参数超出上限" "$EXEC_VM" "VM direct call 参数上限 diagnostic"
require_pattern "exec: VM CALL_INDIRECT 参数超出上限" "$EXEC_VM" "VM indirect call 参数上限 diagnostic"
require_pattern "exec: VM varargs 参数超出上限" "$EXEC_VM" "VM varargs 上限 diagnostic"

reject_pattern "active_local_count[[:space:]]*>=[[:space:]]*EXEC_MAX_LOCALS[[:space:]]*\\|\\|[[:space:]]*ctx\\.next_slot[[:space:]]*>=[[:space:]]*EXEC_MAX_LOCALS[[:space:]]*\\{[[:space:]]*return[[:space:]]+-1;" "$EXEC_LOWER" "lower local/slot 表满后直接 return -1"
reject_pattern "out_count\\[0\\][[:space:]]*>=[[:space:]]*EXEC_MAX_INTERFACE_METHODS[[:space:]]*\\{[[:space:]]*return[[:space:]]+-1;" "$EXEC_LOWER" "interface method 表满后直接 return -1"
reject_pattern "out_count\\[0\\][[:space:]]*>=[[:space:]]*EXEC_MAX_MODULE_GLOBAL_REQUESTS[[:space:]]*\\{[[:space:]]*return;" "$EXEC_LOWER" "module global request 表满后直接 return"
reject_pattern "while[[:space:]]+ai[[:space:]]*<[[:space:]]*instr\\.c[[:space:]]*&&[[:space:]]*ai[[:space:]]*<[[:space:]]*EXEC_MAX_CALL_ARGS" "$EXEC_VM" "VM CALL 参数按 EXEC_MAX_CALL_ARGS 静默截断"
reject_pattern "while[[:space:]]+ai3[[:space:]]*<[[:space:]]*instr\\.imm as i32[[:space:]]*&&[[:space:]]*ai3[[:space:]]*<[[:space:]]*EXEC_MAX_CALL_ARGS" "$EXEC_VM" "VM CALL_INDIRECT 参数按 EXEC_MAX_CALL_ARGS 静默截断"
reject_pattern "while[[:space:]]+function\\.param_count \\+ vi[[:space:]]*<[[:space:]]*arg_count[[:space:]]*&&[[:space:]]*vi[[:space:]]*<[[:space:]]*EXEC_MAX_CALL_ARGS" "$EXEC_VM" "VM varargs 参数按 EXEC_MAX_CALL_ARGS 静默截断"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
probe="$tmpdir/many_exec_locals.uya"
log="$tmpdir/many_exec_locals.log"
{
    echo "fn exec_capacity_seed() i32 { return 1; }"
    echo ""
    echo "export fn main() i32 {"
    for i in $(seq 0 256); do
        printf '    var exec_local_%04d: i32 = exec_capacity_seed();\n' "$i"
    done
    echo "    return exec_local_0000;"
    echo "}"
} > "$probe"

set +e
"$COMPILER" run --vm "$probe" >"$tmpdir/stdout.log" 2>"$log"
status=$?
set -e
if [[ $status -eq 0 ]]; then
    echo "错误: 超过 EXEC_MAX_LOCALS 的程序仍然 --vm 成功，疑似静默跳过 exec local/slot" >&2
    cat "$log" >&2
    exit 1
fi
if ! grep -Fq "exec: local slot table" "$log"; then
    echo "错误: 超过 EXEC_MAX_LOCALS 的程序未输出 exec local slot table diagnostic" >&2
    cat "$log" >&2
    exit 1
fi

echo "✓ exec 固定表上限路径均有明确 diagnostic"
