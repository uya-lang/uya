#!/usr/bin/env bash
#
# Lexical drop scope cleanup must match the existing C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-lexical-drop.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
drop_case="$tmp_dir/lexical_drop_scope.uya"

cat >"$drop_case" <<'UYA'
var drop_count: i32 = 0;

struct SmokeDrop {
    value: i32,
    fn drop(self: SmokeDrop) void {
        drop_count = drop_count + self.value;
    }
}

export fn main() i32 {
    drop_count = 0;
    {
        const dropped: SmokeDrop = SmokeDrop{ value: 7 };
    }
    return drop_count;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$drop_case" >/dev/null

echo "OK: MIR-C99 lexical drop parity matched C99 oracle"
