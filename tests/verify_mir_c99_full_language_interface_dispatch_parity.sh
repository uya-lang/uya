#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for basic interface value dispatch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_interface_dispatch.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
interface_case="$tmp_dir/interface_dispatch.uya"

cat >"$interface_case" <<'UYA'
interface IAdd {
    fn add(self: &Self, x: i32) i32;
}

struct Counter : IAdd {
    value: i32,
}

Counter {
    fn add(self: &Self, x: i32) i32 {
        return self.value + x;
    }
}

fn apply(adder: IAdd, x: i32) i32 {
    return adder.add(x);
}

export fn main() i32 {
    const counter: Counter = Counter{ value: 5 };
    return apply(counter, 10);
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$interface_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_note() {
    local kind="$1"
    local needle="$2"
    if ! grep -E "\\| \`$kind\` \\|" "$MATRIX_DOC" | grep -Fq "$needle"; then
        echo "error: $kind must record $needle in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_INTERFACE_DECL"
require_matrix_status "AST_STRUCT_DECL"
require_matrix_status "AST_METHOD_BLOCK"
require_matrix_status "AST_CALL_EXPR"
require_matrix_status "CORE_EXPR_KIND_CALL"
require_matrix_note "AST_INTERFACE_DECL" "interface dispatch parity shard"
require_matrix_note "AST_STRUCT_DECL" "interface dispatch parity shard"
require_matrix_note "AST_METHOD_BLOCK" "interface dispatch parity shard"
require_matrix_note "AST_CALL_EXPR" "interface dispatch parity shard"
require_matrix_note "CORE_EXPR_KIND_CALL" "interface dispatch parity shard"

echo "OK: MIR-C99 full-language interface dispatch parity matched C99 oracle"
