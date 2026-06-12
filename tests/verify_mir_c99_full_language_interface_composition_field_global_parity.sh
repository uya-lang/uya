#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for interface composition, interface fields,
# and global interface initializers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_interface_comp_field_global.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
interface_case="$tmp_dir/interface_comp_field_global.uya"

cat >"$interface_case" <<'UYA'
interface IReader {
    fn read(self: &Self) i32;
}

interface IWriter {
    fn write(self: &Self, value: i32) i32;
}

interface IReadWriter {
    IReader;
    IWriter;
    fn flush(self: &Self) i32;
}

struct Device : IReadWriter {
    base: i32,
    bonus: i32,
}

Device {
    fn read(self: &Self) i32 {
        return self.base;
    }

    fn write(self: &Self, value: i32) i32 {
        return self.base + value;
    }

    fn flush(self: &Self) i32 {
        return self.bonus;
    }
}

struct Holder {
    primary: IReadWriter,
    offset: i32,
}

const GLOBAL_DEVICE: Device = Device{ base: 11, bonus: 4 };
const GLOBAL_HOLDER: Holder = Holder{ primary: GLOBAL_DEVICE, offset: 3 };

fn run(holder: &Holder, value: i32) i32 {
    return holder.primary.read() + holder.primary.write(value) + holder.primary.flush() + holder.offset;
}

export fn main() i32 {
    return run(&GLOBAL_HOLDER, 5);
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
require_matrix_status "AST_VAR_DECL"
require_matrix_status "AST_CALL_EXPR"
require_matrix_status "AST_MEMBER_ACCESS"
require_matrix_status "AST_STRUCT_INIT"
require_matrix_status "CORE_EXPR_KIND_CALL"
require_matrix_status "CORE_PLACE_KIND_FIELD"
require_matrix_note "AST_INTERFACE_DECL" "interface composition/field/global init parity shard"
require_matrix_note "AST_STRUCT_DECL" "interface composition/field/global init parity shard"
require_matrix_note "AST_METHOD_BLOCK" "interface composition/field/global init parity shard"
require_matrix_note "AST_VAR_DECL" "interface composition/field/global init parity shard"
require_matrix_note "AST_CALL_EXPR" "interface composition/field/global init parity shard"
require_matrix_note "AST_MEMBER_ACCESS" "interface composition/field/global init parity shard"
require_matrix_note "AST_STRUCT_INIT" "interface composition/field/global init parity shard"
require_matrix_note "CORE_EXPR_KIND_CALL" "interface composition/field/global init parity shard"
require_matrix_note "CORE_PLACE_KIND_FIELD" "interface composition/field/global init parity shard"

echo "OK: MIR-C99 full-language interface composition/field/global init parity matched C99 oracle"
