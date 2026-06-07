#!/usr/bin/env bash

# Phase 10：验证 build CLI 的第一个真实 --native 成功路径。
# 当前允许无参/窄 i32 参数函数，函数体为 `return 0..255;`、`return callee();`、
# `return lhs() + rhs();`，一个 direct call 局部初始化后 `return local;`，或最小 `&i32`
# / `&array[0]` out-param 写回，以及两个 `&i32` out-param 的最小调用。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-native-build-minimal.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "错误: native minimal build 当前只支持 x86_64 host" >&2
    exit 1
fi

cat >"$TMP_DIR/exit0.uya" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

cat >"$TMP_DIR/return1.uya" <<'EOF'
export fn main() i32 {
    return 1;
}
EOF

cat >"$TMP_DIR/call.uya" <<'EOF'
fn value() i32 {
    return 1;
}

export fn main() i32 {
    return value();
}
EOF

cat >"$TMP_DIR/add_calls.uya" <<'EOF'
fn left() i32 {
    return 1;
}

fn right() i32 {
    return 2;
}

export fn main() i32 {
    return left() + right();
}
EOF

cat >"$TMP_DIR/use_and_call.uya" <<'EOF'
use helper;

fn value() i32 {
    return 2;
}

export fn main() i32 {
    return value();
}
EOF

cat >"$TMP_DIR/var_then_return.uya" <<'EOF'
export fn main() i32 {
    var scratch: i32 = 7;
    const marker: i32 = -1;
    return 4;
}
EOF

cat >"$TMP_DIR/var_then_call.uya" <<'EOF'
fn value() i32 {
    return 2;
}

export fn main() i32 {
    var buf: [i32: 2] = [];
    const cap: i32 = @len(buf) as i32;
    return value();
}
EOF

cat >"$TMP_DIR/local_call_return.uya" <<'EOF'
fn value() i32 {
    return 5;
}

export fn main() i32 {
    const result: i32 = value();
    return result;
}
EOF

cat >"$TMP_DIR/local_const_arg_call_return.uya" <<'EOF'
fn echo(value: i32) i32 {
    return value;
}

export fn main() i32 {
    const result: i32 = echo(6);
    return result;
}
EOF

cat >"$TMP_DIR/local_const2_arg_call_return.uya" <<'EOF'
fn sum2(left: i32, right: i32) i32 {
    return left + right;
}

export fn main() i32 {
    const result: i32 = sum2(7, 8);
    return result;
}
EOF

cat >"$TMP_DIR/local_addr_call_return.uya" <<'EOF'
fn write_value(out: &i32) i32 {
    out[0] = 9;
    return 0;
}

export fn main() i32 {
    var result: i32 = 1;
    const status: i32 = write_value(&result);
    return result;
}
EOF

cat >"$TMP_DIR/local_array_addr_call_return.uya" <<'EOF'
fn write_value(out: &i32) i32 {
    out[0] = 9;
    return 0;
}

export fn main() i32 {
    var slots: [i32: 1] = [];
    const status: i32 = write_value(&slots[0]);
    return slots[0];
}
EOF

cat >"$TMP_DIR/local_addr2_call_return.uya" <<'EOF'
fn write_pair(left: &i32, right: &i32) i32 {
    left[0] = 4;
    right[0] = 8;
    return 0;
}

export fn main() i32 {
    var left: i32 = 1;
    var right: i32 = 2;
    const status: i32 = write_pair(&left, &right);
    return right;
}
EOF

cat >"$TMP_DIR/unsupported.uya" <<'EOF'
fn value(x: i32) i32 {
    return x;
}

export fn main() i32 {
    return value(1);
}
EOF

run_success_check() {
    local compiler="$1"
    local label="$2"
    local src="$3"
    local expected_status="$4"
    local expect_exit_metric="${5:-1}"
    local expected_functions="${6:-1}"
    local expected_body_ops="${7:-$expected_functions}"
    local expected_machine_insts="${8:-$expected_body_ops}"
    local out="$TMP_DIR/${label}-${expected_status}-native"

    "$compiler" build "$src" \
        -o "$out" --native --nostdlib --no-split-c --project-root "$TMP_DIR/" \
        >"$TMP_DIR/${label}.${expected_status}.build.out" 2>"$TMP_DIR/${label}.${expected_status}.build.err"

    test -s "$out"
    grep -q '后端类型: Native' "$TMP_DIR/${label}.${expected_status}.build.err"
    grep -q 'native_output_bytes:' "$TMP_DIR/${label}.${expected_status}.build.err"
    grep -q 'native_function_count:' "$TMP_DIR/${label}.${expected_status}.build.err"
    grep -q "native_lowered_body_ops: $expected_body_ops" "$TMP_DIR/${label}.${expected_status}.build.err"
    grep -q "native_machine_function_count: $expected_functions" "$TMP_DIR/${label}.${expected_status}.build.err"
    grep -q "native_machine_inst_count: $expected_machine_insts" "$TMP_DIR/${label}.${expected_status}.build.err"
    grep -q 'native_machine_peak_bytes:' "$TMP_DIR/${label}.${expected_status}.build.err"
    grep -q 'native_entry_index:' "$TMP_DIR/${label}.${expected_status}.build.err"
    if [[ "$expect_exit_metric" -ne 0 ]]; then
        grep -q "native_exit_code: $expected_status" "$TMP_DIR/${label}.${expected_status}.build.err"
    fi
    if grep -q '后端类型: C99' "$TMP_DIR/${label}.${expected_status}.build.err"; then
        echo "错误: $label --native 最小成功路径不应回落 C99" >&2
        exit 1
    fi

    local magic
    magic="$(od -An -tx1 -N4 "$out" | tr -d ' \n')"
    if [[ "$magic" != "7f454c46" ]]; then
        echo "错误: $label --native 输出不是 ELF magic: $magic" >&2
        exit 1
    fi

    chmod +x "$out"
    set +e
    "$out" >"$TMP_DIR/${label}.${expected_status}.run.out" 2>"$TMP_DIR/${label}.${expected_status}.run.err"
    local run_status=$?
    set -e
    if [[ "$run_status" -ne "$expected_status" ]]; then
        echo "错误: $label --native 最小程序退出码应为 $expected_status，实际 $run_status" >&2
        exit 1
    fi
    if [[ -s "$TMP_DIR/${label}.${expected_status}.run.out" || -s "$TMP_DIR/${label}.${expected_status}.run.err" ]]; then
        echo "错误: $label --native 最小程序不应产生 stdout/stderr" >&2
        exit 1
    fi
}

run_reject_check() {
    local compiler="$1"
    local label="$2"
    local out="$TMP_DIR/${label}-return1-native"

    set +e
    "$compiler" build "$TMP_DIR/unsupported.uya" \
        -o "$out" --native --nostdlib --no-split-c --project-root "$TMP_DIR/" \
        >"$TMP_DIR/${label}.unsupported.out" 2>"$TMP_DIR/${label}.unsupported.err"
    local reject_status=$?
    set -e
    if [[ "$reject_status" -eq 0 ]]; then
        echo "错误: $label --native 不应把 unsupported 程序伪生成 native executable" >&2
        exit 1
    fi
    if [[ -e "$out" ]]; then
        echo "错误: $label --native 拒绝 unsupported 程序时不应生成输出" >&2
        exit 1
    fi
    grep -q 'LoweredProgram 到机器码 compiler path 未接入' "$TMP_DIR/${label}.unsupported.err"
    grep -q '后端类型: Native' "$TMP_DIR/${label}.unsupported.err"
    if grep -q '后端类型: C99' "$TMP_DIR/${label}.unsupported.err"; then
        echo "错误: $label --native 拒绝路径不应回落 C99" >&2
        exit 1
    fi
}

run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/exit0.uya" 0 1 1
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/return1.uya" 1 1 1
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/call.uya" 1 0 2
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/add_calls.uya" 3 0 3
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/use_and_call.uya" 2 0 2
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/var_then_return.uya" 4 1 1
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/var_then_call.uya" 2 0 2
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/local_call_return.uya" 5 0 2 3 3
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/local_const_arg_call_return.uya" 6 0 2 3 3
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/local_const2_arg_call_return.uya" 15 0 2 3 3
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/local_addr_call_return.uya" 9 0 2 4 4
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/local_array_addr_call_return.uya" 9 0 2 4 4
run_success_check "$REPO_ROOT/bin/uya" "uya" "$TMP_DIR/local_addr2_call_return.uya" 8 0 2 5 5
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/exit0.uya" 0 1 1
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/return1.uya" 1 1 1
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/call.uya" 1 0 2
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/add_calls.uya" 3 0 3
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/use_and_call.uya" 2 0 2
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/var_then_return.uya" 4 1 1
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/var_then_call.uya" 2 0 2
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/local_call_return.uya" 5 0 2 3 3
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/local_const_arg_call_return.uya" 6 0 2 3 3
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/local_const2_arg_call_return.uya" 15 0 2 3 3
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/local_addr_call_return.uya" 9 0 2 4 4
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/local_array_addr_call_return.uya" 9 0 2 4 4
run_success_check "$REPO_ROOT/bin/cmd/build" "cmd-build" "$TMP_DIR/local_addr2_call_return.uya" 8 0 2 5 5
run_reject_check "$REPO_ROOT/bin/uya" "uya"
run_reject_check "$REPO_ROOT/bin/cmd/build" "cmd-build"

echo "verify_native_build_minimal_program: ok"
