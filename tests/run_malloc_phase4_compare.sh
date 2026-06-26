#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
BUILD_DIR="$TEST_DIR/build"
UYA_SRC="$TEST_DIR/bench_malloc_phase4.uya"
C_SRC="$TEST_DIR/bench_malloc_phase4.c"
UYA_C="$BUILD_DIR/bench_malloc_phase4_uya.c"
UYA_BIN="$BUILD_DIR/bench_malloc_phase4_uya"
C_BIN="$BUILD_DIR/bench_malloc_phase4_c"
export UYA_ROOT="$ROOT_DIR/lib/"

field_from_line() {
    local line="$1"
    local key="$2"
    printf '%s\n' "$line" | awk -v key="$key" '{
        for (i = 1; i <= NF; i++) {
            split($i, kv, "=")
            if (kv[1] == key) {
                print kv[2]
                exit
            }
        }
    }'
}

ratio_text() {
    local numerator="$1"
    local denominator="$2"
    awk -v n="$numerator" -v d="$denominator" 'BEGIN {
        if (d == 0) {
            printf "0.0000x"
        } else {
            printf "%.4fx", n / d
        }
    }'
}

summary_for_thread() {
    local thread_count="$1"
    local uya_line="$2"
    local c_line="$3"

    local uya_elapsed uya_throughput uya_checksum
    local c_elapsed c_throughput c_checksum

    uya_elapsed="$(field_from_line "$uya_line" elapsed_ns)"
    uya_throughput="$(field_from_line "$uya_line" throughput_ops_per_sec)"
    uya_checksum="$(field_from_line "$uya_line" checksum)"
    c_elapsed="$(field_from_line "$c_line" elapsed_ns)"
    c_throughput="$(field_from_line "$c_line" throughput_ops_per_sec)"
    c_checksum="$(field_from_line "$c_line" checksum)"

    if [[ "$uya_checksum" != "$c_checksum" ]]; then
        echo "malloc_phase4_compare: checksum mismatch threads=$thread_count uya=$uya_checksum c=$c_checksum" >&2
        exit 1
    fi

    printf 'malloc_phase4_compare threads=%s uya_elapsed_ns=%s c_elapsed_ns=%s uya_throughput_ops_per_sec=%s c_throughput_ops_per_sec=%s uya_over_c_elapsed=%s uya_over_c_throughput=%s checksum=%s\n' \
        "$thread_count" \
        "$uya_elapsed" \
        "$c_elapsed" \
        "$uya_throughput" \
        "$c_throughput" \
        "$(ratio_text "$uya_elapsed" "$c_elapsed")" \
        "$(ratio_text "$uya_throughput" "$c_throughput")" \
        "$uya_checksum"
}

mkdir -p "$BUILD_DIR"

if [[ ! -x "$ROOT_DIR/bin/uya" ]]; then
    echo "missing Uya compiler: $ROOT_DIR/bin/uya" >&2
    exit 1
fi
if [[ ! -f "$UYA_SRC" ]]; then
    echo "missing Uya benchmark source: $UYA_SRC" >&2
    exit 1
fi
if [[ ! -f "$C_SRC" ]]; then
    echo "missing C benchmark source: $C_SRC" >&2
    exit 1
fi

cd "$TEST_DIR"
"$ROOT_DIR/bin/uya" build "$UYA_SRC" --c99 --no-split-c -O2 -o "$UYA_C"
cc -std=c99 -O2 -pthread -fno-builtin -o "$UYA_BIN" "$UYA_C"
cc -std=c99 -O2 -pthread -fno-builtin -o "$C_BIN" "$C_SRC"

UYA_OUTPUT="$("$UYA_BIN")"
C_OUTPUT="$("$C_BIN")"

printf '%s\n' "$UYA_OUTPUT"
printf '%s\n' "$C_OUTPUT"

for thread_count in 1 2 4 8; do
    uya_line="$(printf '%s\n' "$UYA_OUTPUT" | awk -v t="$thread_count" '$1 == "malloc_phase4" { for (i = 1; i <= NF; i++) { split($i, kv, "="); if (kv[1] == "threads" && kv[2] == t) { print; exit } } }')"
    c_line="$(printf '%s\n' "$C_OUTPUT" | awk -v t="$thread_count" '$1 == "malloc_phase4" { for (i = 1; i <= NF; i++) { split($i, kv, "="); if (kv[1] == "threads" && kv[2] == t) { print; exit } } }')"

    if [[ -z "$uya_line" || -z "$c_line" ]]; then
        echo "malloc_phase4_compare: missing result line for threads=$thread_count" >&2
        exit 1
    fi

    summary_for_thread "$thread_count" "$uya_line" "$c_line"
done
