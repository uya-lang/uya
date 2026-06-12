#!/usr/bin/env bash
#
# Global aggregate, extern global, and minimal @c_import parity must match the
# existing C99 oracle through host C compilation and execution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-global-import.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

run_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

aggregate_case="$tmp_dir/global_aggregate.uya"
cat >"$aggregate_case" <<'UYA'
var global_values: [i32: 4] = [3, 5, 8, 13];

export fn main() i32 {
    return global_values[0] + global_values[2] + global_values[3];
}
UYA

mkdir -p "$tmp_dir/c_import"
cat >"$tmp_dir/c_import/globals.c" <<'C_EOF'
int external_counter = 17;
int imported_bias(void) {
    return 6;
}
C_EOF

extern_case="$tmp_dir/extern_global.uya"
cat >"$extern_case" <<'UYA'
@c_import("c_import/globals.c");

extern var external_counter: i32;
extern fn imported_bias() i32;

export fn main() i32 {
    return external_counter + imported_bias();
}
UYA

minimal_c_import_case="$tmp_dir/minimal_c_import.uya"
cat >"$minimal_c_import_case" <<'UYA'
@c_import("c_import/globals.c");

extern fn imported_bias() i32;

export fn main() i32 {
    return imported_bias();
}
UYA

run_case "$aggregate_case"
run_case "$extern_case"
run_case "$minimal_c_import_case"

echo "OK: MIR-C99 global/import parity matched C99 oracle"
