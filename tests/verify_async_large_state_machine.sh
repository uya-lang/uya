#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"

CONTROL_SRC="$(mktemp /tmp/uya-async-desc-control.XXXXXX.uya)"
STRESS_SRC="$(mktemp /tmp/uya-async-desc-stress.XXXXXX.uya)"
CONTROL_C="$(mktemp /tmp/uya-async-desc-control.XXXXXX.c)"
STRESS_C="$(mktemp /tmp/uya-async-desc-stress.XXXXXX.c)"

cleanup() {
    rm -f "$CONTROL_SRC" "$STRESS_SRC" "$CONTROL_C" "$STRESS_C"
}
trap cleanup EXIT

require_compiler() {
    if [ ! -x "$COMPILER" ]; then
        echo "missing compiler: $COMPILER"
        echo "hint: run 'make uya' first"
        exit 1
    fi
}

run_uya_test() {
    local rel="$1"
    local log
    log="$(mktemp)"
    if ! "$COMPILER" test "$REPO_ROOT/$rel" >"$log" 2>&1; then
        echo "uya test failed: $rel"
        cat "$log"
        rm -f "$log"
        exit 1
    fi
    rm -f "$log"
}

extract_descriptor_count() {
    sed -n 's/.*int32_t _uya_async_frame_descriptor_count = \([0-9][0-9]*\);.*/\1/p' "$1" | head -n 1
}

extract_entries_size() {
    sed -n 's/.*static struct AsyncFrameDescriptor _uya_async_frame_descriptor_entries\[\([0-9][0-9]*\)\].*/\1/p' "$1" | head -n 1
}

emit_prelude() {
    cat <<'EOF'
use std.async;
use std.testing.assert_eq_i32;

fn ready(v: i32) Future<!i32> {
    const p: Poll<!i32> = Poll<!i32>.Ready(ok<i32>(v));
    return Future<!i32>{ state: p };
}

fn expect_future_i32(f: Future<!i32>, expected: i32) !void {
    const value: i32 = try block_on<i32>(f);
    try assert_eq_i32(value, expected);
}

@async_fn
fn pair_add<T, U>(lhs: &T, rhs: &U, bias: i32) Future<!i32> {
    _ = lhs;
    _ = rhs;
    const a: i32 = try @await ready(bias);
    return a + 1;
}

@async_fn
fn pair_sub<T, U>(lhs: &T, rhs: &U, bias: i32) Future<!i32> {
    _ = lhs;
    _ = rhs;
    const a: i32 = try @await ready(bias);
    return a - 1;
}

@async_fn
fn single_tag<T>(item: &T, tag: i32) Future<!i32> {
    _ = item;
    const v: i32 = try @await ready(tag);
    return v;
}

struct Ty00 {}
struct Ty01 {}
struct Ty02 {}
struct Ty03 {}
struct Ty04 {}
struct Ty05 {}
struct Ty06 {}
struct Ty07 {}
struct Ty08 {}
struct Ty09 {}
struct Ty10 {}
struct Ty11 {}
struct Ty12 {}
struct Ty13 {}
struct Ty14 {}
struct Ty15 {}
EOF
}

generate_control_source() {
    emit_prelude >"$CONTROL_SRC"
    cat <<'EOF' >>"$CONTROL_SRC"

test "descriptor_growth_control_smoke" {
    const t00: Ty00 = Ty00{};
    const t01: Ty01 = Ty01{};
    const t15: Ty15 = Ty15{};

    try expect_future_i32(pair_add<Ty00, Ty01>(&t00, &t01, 11), 12);
    try expect_future_i32(pair_sub<Ty01, Ty15>(&t01, &t15, 23), 22);
    try expect_future_i32(single_tag<Ty15>(&t15, 35), 35);
}
EOF
}

generate_stress_source() {
    emit_prelude >"$STRESS_SRC"
    {
        echo
        echo 'test "descriptor_growth_stress" {'
        for i in $(seq 0 15); do
            printf '    const t%02d: Ty%02d = Ty%02d{};\n' "$i" "$i" "$i"
        done
        echo
        for i in $(seq 0 15); do
            for j in $(seq 0 15); do
                bias=$((i * 100 + j))
                printf '    try expect_future_i32(pair_add<Ty%02d, Ty%02d>(&t%02d, &t%02d, %d), %d);\n' "$i" "$j" "$i" "$j" "$bias" $((bias + 1))
                printf '    try expect_future_i32(pair_sub<Ty%02d, Ty%02d>(&t%02d, &t%02d, %d), %d);\n' "$i" "$j" "$i" "$j" "$bias" $((bias - 1))
            done
        done
        echo
        for i in $(seq 0 15); do
            tag=$((900 + i))
            printf '    try expect_future_i32(single_tag<Ty%02d>(&t%02d, %d), %d);\n' "$i" "$i" "$tag" "$tag"
        done
        echo '}'
    } >>"$STRESS_SRC"
}

require_compiler

run_uya_test "tests/test_async_await_limits_and_segments.uya"
run_uya_test "tests/test_async_descriptor_growth.uya"

generate_control_source
generate_stress_source

"$COMPILER" --c99 "$CONTROL_SRC" -o "$CONTROL_C" >/dev/null
"$COMPILER" --c99 "$STRESS_SRC" -o "$STRESS_C" >/dev/null

control_count="$(extract_descriptor_count "$CONTROL_C")"
stress_count="$(extract_descriptor_count "$STRESS_C")"
control_entries="$(extract_entries_size "$CONTROL_C")"
stress_entries="$(extract_entries_size "$STRESS_C")"

if [ -z "$control_count" ] || [ -z "$stress_count" ]; then
    echo "failed to extract async frame descriptor counts"
    exit 1
fi

if [ "$control_entries" != "$control_count" ]; then
    echo "control descriptor entries are not sized from descriptor count"
    exit 1
fi

if [ "$stress_entries" != "$stress_count" ]; then
    echo "stress descriptor entries are not sized from descriptor count"
    exit 1
fi

descriptor_delta=$((stress_count - control_count))
if [ "$descriptor_delta" -lt 525 ]; then
    echo "descriptor/meta growth truncated: control=$control_count stress=$stress_count delta=$descriptor_delta expected>=525"
    exit 1
fi

echo "verify_async_large_state_machine: ok (control=$control_count stress=$stress_count delta=$descriptor_delta)"
