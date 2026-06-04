#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="${UYA_COMPILER:-$ROOT/bin/uya}"
SRC_MAIN="$ROOT/src/main.uya"
TMP="$(mktemp -d /tmp/uya-main-input-capacity.XXXXXX)"
LOG="$TMP/check.log"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
    echo "verify_main_input_capacity_diagnostics: $*" >&2
    exit 1
}

grep -q 'input_file_capacity: i32' "$SRC_MAIN" || \
    fail "parse_args must receive the real input index capacity"

grep -q 'input_file_count\[0\] >= input_file_capacity' "$SRC_MAIN" || \
    fail "parse_args must diagnose input index capacity exhaustion before writing"

grep -q 'resolved_capacity: i32 = @len(resolved_files) as i32' "$SRC_MAIN" || \
    fail "compile_files must derive resolved_files capacity from the actual array"

grep -q 'main_file_capacity: i32 = @len(main_files) as i32' "$SRC_MAIN" || \
    fail "compile_files must derive main_files capacity from the actual array"

if grep -q 'already_in_list == 0 && resolved_count < MAX_INPUT_FILES' "$SRC_MAIN"; then
    fail "entry.uya append must diagnose capacity exhaustion instead of skipping"
fi

args=()
for i in $(seq 0 64); do
    src="$TMP/input_$i.uya"
    printf 'const capacity_probe_%03d: i32 = %d;\n' "$i" "$i" >"$src"
    args+=("$src")
done

ok_args=("${args[@]:0:64}")
if ! "$COMPILER" check "${ok_args[@]}" >"$LOG" 2>&1; then
    echo "verify_main_input_capacity_diagnostics: check with 64 inputs failed" >&2
    cat "$LOG" >&2
    exit 1
fi

grep -q '类型检查通过' "$LOG" || {
    echo "verify_main_input_capacity_diagnostics: missing checker success marker" >&2
    cat "$LOG" >&2
    exit 1
}

if "$COMPILER" check "${args[@]}" >"$LOG" 2>&1; then
    echo "verify_main_input_capacity_diagnostics: check with 65 inputs should fail with a diagnostic" >&2
    cat "$LOG" >&2
    exit 1
fi

grep -q '输入文件数量超过最大限制' "$LOG" || {
    echo "verify_main_input_capacity_diagnostics: missing too-many-inputs diagnostic" >&2
    cat "$LOG" >&2
    exit 1
}

echo "verify_main_input_capacity_diagnostics: ok"
