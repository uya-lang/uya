#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
BUILD_DIR="$TEST_DIR/build"
UYA_SRC="$TEST_DIR/bench_malloc_throughput.uya"
C_SRC="$TEST_DIR/bench_malloc_throughput.c"
UYA_C="$BUILD_DIR/bench_malloc_throughput_uya.c"
UYA_BIN="$BUILD_DIR/bench_malloc_throughput_uya"
C_BIN="$BUILD_DIR/bench_malloc_throughput_c"
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
cc -std=c99 -O2 -fno-builtin -o "$UYA_BIN" "$UYA_C"
cc -std=c99 -O2 -fno-builtin -o "$C_BIN" "$C_SRC"

UYA_OUTPUT="$("$UYA_BIN")"
C_OUTPUT="$("$C_BIN")"

printf '%s\n' "$UYA_OUTPUT"
printf '%s\n' "$C_OUTPUT"

UYA_ELAPSED_NS="$(field_from_line "$UYA_OUTPUT" elapsed_ns)"
UYA_AVG_PAIR_NS="$(field_from_line "$UYA_OUTPUT" avg_pair_ns)"
UYA_THROUGHPUT="$(field_from_line "$UYA_OUTPUT" throughput_ops_per_sec)"
UYA_CHECKSUM="$(field_from_line "$UYA_OUTPUT" checksum)"

C_ELAPSED_NS="$(field_from_line "$C_OUTPUT" elapsed_ns)"
C_AVG_PAIR_NS="$(field_from_line "$C_OUTPUT" avg_pair_ns)"
C_THROUGHPUT="$(field_from_line "$C_OUTPUT" throughput_ops_per_sec)"
C_CHECKSUM="$(field_from_line "$C_OUTPUT" checksum)"

if [[ "$UYA_CHECKSUM" != "$C_CHECKSUM" ]]; then
    echo "malloc_compare: checksum mismatch uya=$UYA_CHECKSUM c=$C_CHECKSUM" >&2
    exit 1
fi

printf 'malloc_compare_summary backend=uya elapsed_ns=%s avg_pair_ns=%s throughput_ops_per_sec=%s checksum=%s\n' \
    "$UYA_ELAPSED_NS" "$UYA_AVG_PAIR_NS" "$UYA_THROUGHPUT" "$UYA_CHECKSUM"
printf 'malloc_compare_summary backend=c elapsed_ns=%s avg_pair_ns=%s throughput_ops_per_sec=%s checksum=%s\n' \
    "$C_ELAPSED_NS" "$C_AVG_PAIR_NS" "$C_THROUGHPUT" "$C_CHECKSUM"
printf 'malloc_compare_ratio uya_over_c_elapsed=%s uya_over_c_throughput=%s\n' \
    "$(ratio_text "$UYA_ELAPSED_NS" "$C_ELAPSED_NS")" \
    "$(ratio_text "$UYA_THROUGHPUT" "$C_THROUGHPUT")"
