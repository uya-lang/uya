#!/usr/bin/env bash

# Native build-seed boundary: compare build-only cmd/build C99 output against the C99-built
# compiler oracle for small regression programs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-native-cmd-build-c99-parity.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

CC_DRIVER="${CC:-cc}"
RUN_GENERATED_C_STATUS=0

cat >"$TMP_DIR/exit0.uya" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

cat >"$TMP_DIR/helper_call.uya" <<'EOF'
fn value() i32 {
    return 3;
}

export fn main() i32 {
    return value();
}
EOF

cat >"$TMP_DIR/generic_array.uya" <<'EOF'
fn identity<T>(value: T) T {
    return value;
}

export fn main() i32 {
    var slots: [i32: 2] = [];
    const cap: i32 = @len(slots) as i32;
    return identity<i32>(cap + 4);
}
EOF

normalize_c99_output() {
    local input="$1"
    local output="$2"
    awk 'seen || /alignof/ { seen=1; print }' "$input" >"$output"
}

run_generated_c() {
    local c_file="$1"
    local bin_file="$2"
    local run_out="$3"
    local run_err="$4"

    "$CC_DRIVER" -std=c99 -O0 -g -fno-builtin "$c_file" -o "$bin_file"
    set +e
    "$bin_file" >"$run_out" 2>"$run_err"
    RUN_GENERATED_C_STATUS=$?
    set -e
    return 0
}

run_c99_parity_case() {
    local name="$1"
    local src="$TMP_DIR/$name.uya"
    local uya_c="$TMP_DIR/$name.uya-oracle.c"
    local cmd_c="$TMP_DIR/$name.cmd-build.c"
    local uya_norm="$TMP_DIR/$name.uya-oracle.norm.c"
    local cmd_norm="$TMP_DIR/$name.cmd-build.norm.c"

    "$REPO_ROOT/bin/uya" build "$src" \
        -o "$uya_c" --no-split-c --project-root "$TMP_DIR/" \
        >"$TMP_DIR/$name.uya.build.out" 2>"$TMP_DIR/$name.uya.build.err"
    "$REPO_ROOT/bin/cmd/build" build "$src" \
        -o "$cmd_c" --no-split-c --project-root "$TMP_DIR/" \
        >"$TMP_DIR/$name.cmd.build.out" 2>"$TMP_DIR/$name.cmd.build.err"

    test -s "$uya_c"
    test -s "$cmd_c"
    grep -q '后端类型: C99' "$TMP_DIR/$name.uya.build.err"
    grep -q '后端类型: C99' "$TMP_DIR/$name.cmd.build.err"
    if grep -q '后端类型: Native' "$TMP_DIR/$name.cmd.build.err"; then
        echo "error: cmd/build C99 output parity unexpectedly used native backend for $name" >&2
        exit 1
    fi

    normalize_c99_output "$uya_c" "$uya_norm"
    normalize_c99_output "$cmd_c" "$cmd_norm"
    if ! cmp -s "$uya_norm" "$cmd_norm"; then
        echo "error: normalized C99 output differs for $name" >&2
        diff -u "$uya_norm" "$cmd_norm" | sed -n '1,160p' >&2
        exit 1
    fi

    run_generated_c "$uya_c" "$TMP_DIR/$name.uya.bin" \
        "$TMP_DIR/$name.uya.run.out" "$TMP_DIR/$name.uya.run.err"
    local uya_status="$RUN_GENERATED_C_STATUS"
    run_generated_c "$cmd_c" "$TMP_DIR/$name.cmd.bin" \
        "$TMP_DIR/$name.cmd.run.out" "$TMP_DIR/$name.cmd.run.err"
    local cmd_status="$RUN_GENERATED_C_STATUS"
    if [[ "$uya_status" -ne "$cmd_status" ]]; then
        echo "error: generated C99 status differs for $name: uya=$uya_status cmd=$cmd_status" >&2
        exit 1
    fi
    if ! cmp -s "$TMP_DIR/$name.uya.run.out" "$TMP_DIR/$name.cmd.run.out" ||
       ! cmp -s "$TMP_DIR/$name.uya.run.err" "$TMP_DIR/$name.cmd.run.err"; then
        echo "error: generated C99 runtime output differs for $name" >&2
        exit 1
    fi
}

run_c99_parity_case exit0
run_c99_parity_case helper_call
run_c99_parity_case generic_array

echo "verify_native_cmd_build_c99_output_parity: ok"
