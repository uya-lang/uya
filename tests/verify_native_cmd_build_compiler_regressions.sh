#!/usr/bin/env bash

# Native build-seed boundary: verify bin/cmd/build can compile a small compiler-regression group
# through the native build-seed path and hosted MIR-backed stream shards.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-native-cmd-build-regressions.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "error: native cmd/build compiler regressions require x86_64 host" >&2
    exit 1
fi

cat >"$TMP_DIR/generic_identity.uya" <<'EOF'
fn identity<T>(value: T) T {
    return value;
}

export fn main() i32 {
    const result: i32 = identity<i32>(6);
    return result;
}
EOF

cat >"$TMP_DIR/local_array_outparam.uya" <<'EOF'
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

cat >"$TMP_DIR/stack_limit_call.uya" <<'EOF'
use std.runtime.entry.set_process_stack_limit_bytes;

export fn main() i32 {
    var stack_size: i32 = 65536;
    var eff_stack_size: i32 = stack_size;
    set_process_stack_limit_bytes(eff_stack_size as u64 * 1024);
    return 4;
}
EOF

cat >"$TMP_DIR/parse_like_outparam.uya" <<'EOF'
fn parse_like(input: &i32, capacity: i32, count: &i32, output: &i32, backend: &i32, emit: &i32, safety: &i32, opt: &i32, nostd: &i32, stack: &i32, async_out: &i32) i32 {
    async_out[0] = 91;
    return 0;
}

export fn main() i32 {
    var input_file_indices: [i32: 64] = [];
    var input_file_count: i32 = 0;
    var output_file_index: i32 = -1;
    var backend: i32 = 0;
    var emit_line_directives: i32 = 0;
    var enable_safety_proof: i32 = 1;
    var opt_level: i32 = 1;
    var is_nostdlib: i32 = 0;
    var stack_size: i32 = 65536;
    var async_frame_heap_fallback: i32 = 0;
    const input_file_index_capacity: i32 = @len(input_file_indices) as i32;
    const parse_result: i32 = parse_like(&input_file_indices[0], input_file_index_capacity, &input_file_count, &output_file_index, &backend, &emit_line_directives, &enable_safety_proof, &opt_level, &is_nostdlib, &stack_size, &async_frame_heap_fallback);
    return async_frame_heap_fallback;
}
EOF

cat >"$TMP_DIR/hosted_array_index.uya" <<'EOF'
export fn main() i32 {
    var array: [i32: 4] = [2, 4, 6, 8];
    const idx: i32 = 2;
    return array[idx];
}
EOF

run_cmd_build_regression() {
    local name="$1"
    local expected_status="$2"
    local out="$TMP_DIR/$name.native"
    local build_out="$TMP_DIR/$name.build.out"
    local build_err="$TMP_DIR/$name.build.err"
    local run_out="$TMP_DIR/$name.run.out"
    local run_err="$TMP_DIR/$name.run.err"

    "$REPO_ROOT/bin/cmd/build" build "$TMP_DIR/$name.uya" \
        -o "$out" --native --nostdlib --no-split-c --project-root "$TMP_DIR/" \
        >"$build_out" 2>"$build_err"

    test -s "$out"
    grep -q '后端类型: Native' "$build_err"
    grep -q 'native_output_bytes:' "$build_err"
    if grep -q '后端类型: C99' "$build_err" ||
       grep -q 'native_hosted_portable_mir_lowering_missing' "$build_err" ||
       grep -q 'LoweredProgram 到机器码 compiler path 未接入' "$build_err"; then
        echo "error: cmd/build regression $name fell back or rejected unexpectedly" >&2
        cat "$build_err" >&2
        exit 1
    fi

    local magic
    magic="$(od -An -tx1 -N4 "$out" | tr -d ' \n')"
    if [[ "$magic" != "7f454c46" ]]; then
        echo "error: cmd/build regression $name did not emit ELF: $magic" >&2
        exit 1
    fi

    chmod +x "$out"
    set +e
    "$out" >"$run_out" 2>"$run_err"
    local run_status=$?
    set -e
    if [[ "$run_status" -ne "$expected_status" ]]; then
        echo "error: cmd/build regression $name exit=$run_status expected=$expected_status" >&2
        exit 1
    fi
    if [[ -s "$run_out" || -s "$run_err" ]]; then
        echo "error: cmd/build regression $name produced stdout/stderr" >&2
        exit 1
    fi
}

run_cmd_build_hosted_array_index_reject() {
    local out="$TMP_DIR/hosted_array_index.native"
    local build_out="$TMP_DIR/hosted_array_index.build.out"
    local build_err="$TMP_DIR/hosted_array_index.build.err"

    set +e
    "$REPO_ROOT/bin/cmd/build" build "$TMP_DIR/hosted_array_index.uya" \
        -o "$out" --native --no-split-c --project-root "$TMP_DIR/" \
        >"$build_out" 2>"$build_err"
    local build_status=$?
    set -e

    if [[ "$build_status" -eq 0 ]]; then
        echo "error: cmd/build hosted array-index regression should reject while hosted coverage is incomplete" >&2
        cat "$build_err" >&2
        exit 1
    fi
    if [[ -e "$out" ]]; then
        echo "error: cmd/build hosted array-index regression produced output while rejecting" >&2
        cat "$build_err" >&2
        exit 1
    fi
    grep -q '后端类型: Native' "$build_err"
    grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_preflight_failed' "$build_err"
    grep -q '不能静默回落 C99，也不能使用 build-seed LoweredProgram helper' "$build_err"
    if grep -q 'hosted native assembly' "$build_err" ||
       grep -q 'native_hosted_subset: core_mir_local_array_index_path=1' "$build_err" ||
       grep -q 'native_output_bytes:' "$build_err" ||
       grep -q '后端类型: C99' "$build_err"; then
        echo "error: cmd/build hosted array-index regression used fallback or emitted output" >&2
        cat "$build_err" >&2
        exit 1
    fi
}

run_cmd_build_regression generic_identity 6
run_cmd_build_regression local_array_outparam 9
run_cmd_build_regression stack_limit_call 4
run_cmd_build_regression parse_like_outparam 91
run_cmd_build_hosted_array_index_reject

echo "verify_native_cmd_build_compiler_regressions: ok"
