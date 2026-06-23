#!/usr/bin/env bash
#
# Real-CLI parity gate for MIR-C99 value/expr entrypoints handled by the
# current-source cmd/build candidate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

if [[ ! -x "$COMPILER" ]]; then
    echo "error: fixed MIR-C99 compiler is missing or not executable: $COMPILER" >&2
    exit 69
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-value-parity.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
BOOTSTRAP_BIN="$tmp_dir/build-bootstrap"
CANDIDATE_BIN="$tmp_dir/cmd-build-candidate"

float_case="$tmp_dir/float_case.uya"
char_case="$tmp_dir/char_case.uya"
string_case="$tmp_dir/string_case.uya"
null_case="$tmp_dir/null_case.uya"
int_limit_case="$tmp_dir/int_limit_case.uya"
string_interp_case="$tmp_dir/string_interp_case.uya"
params_case="$tmp_dir/params_case.uya"

cat >"$float_case" <<'UYA'
export fn main() i32 {
    const xf: f32 = 1.25f32;
    const yd: f64 = 2.5;
    const total: f64 = xf as f64 + yd;
    if total > 3.74 && total < 3.76 {
        return 0;
    }
    return 1;
}
UYA

cat >"$char_case" <<'UYA'
export fn main() i32 {
    const ch: byte = 'A';
    if ch == 'A' {
        return 0;
    }
    return 1;
}
UYA

cat >"$string_case" <<'UYA'
export fn main() i32 {
    const msg: [byte: 3] = "hi";
    if msg[0] == 'h' && msg[1] == 'i' && msg[2] == 0 as byte {
        return 0;
    }
    return 1;
}
UYA

cat >"$null_case" <<'UYA'
export fn main() i32 {
    const p: *byte = null;
    if p == null {
        return 0;
    }
    return 1;
}
UYA

cat >"$int_limit_case" <<'UYA'
export fn main() i32 {
    const maxv: i32 = @max;
    const minv: i32 = @min;
    if maxv > 2147483646 && minv < -2147483647 {
        return 0;
    }
    return 1;
}
UYA

cat >"$string_interp_case" <<'UYA'
export fn main() i32 {
    const value: i32 = 7;
    const msg: [i8: 32] = "value=${value}\n";
    if msg[0] == 'v' && msg[6] == '7' {
        return 0;
    }
    return 1;
}
UYA

cat >"$params_case" <<'UYA'
fn pair_sum(a: i32, b: i32) i32 {
    return @params.0 + @params.1;
}

export fn main() i32 {
    if pair_sum(3, 4) == 7 {
        return 0;
    }
    return 1;
}
UYA

build_candidate() {
    local bootstrap_log="$tmp_dir/build_bootstrap.generate.log"
    local candidate_log="$tmp_dir/cmd_build_candidate.generate.log"

    if ! (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT" "$COMPILER" build \
            src/cmd/build_bootstrap/main.uya -o "$BOOTSTRAP_BIN" \
            --project-root "$REPO_ROOT/src/" --no-split-c
    ) >"$bootstrap_log" 2>&1; then
        echo "error: real-CLI bootstrap build failed" >&2
        cat "$bootstrap_log" >&2
        exit 1
    fi
    if [[ ! -x "$BOOTSTRAP_BIN" ]]; then
        echo "error: bootstrap binary not executable: $BOOTSTRAP_BIN" >&2
        exit 1
    fi

    if ! (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT" "$BOOTSTRAP_BIN" build \
            src/cmd/build/main.uya -o "$CANDIDATE_BIN" \
            --project-root "$REPO_ROOT/src/" --no-split-c
    ) >"$candidate_log" 2>&1; then
        echo "error: MIR-C99 value-entry real CLI candidate build failed" >&2
        cat "$candidate_log" >&2
        exit 1
    fi
    if [[ ! -x "$CANDIDATE_BIN" ]]; then
        echo "error: MIR-C99 value-entry candidate did not leave an executable: $CANDIDATE_BIN" >&2
        exit 1
    fi
}

run_parity_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD="cd \"$REPO_ROOT\" && UYA_ROOT=\"$REPO_ROOT\" \"$CANDIDATE_BIN\" build --mir-c99 {input} -o {output} --project-root \"$REPO_ROOT\" --no-split-c" \
    C99_ORACLE_GENERATE_CMD="bash \"$REPO_ROOT/tests/c99_oracle_generate.sh\" {input} {output} {log} --project-root \"$REPO_ROOT\"" \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

require_matrix_status() {
    local kind="$1"
    local status="$2"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| $status \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked $status in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

build_candidate

run_parity_case "$float_case"
run_parity_case "$char_case"
run_parity_case "$string_case"
run_parity_case "$null_case"
run_parity_case "$int_limit_case"
run_parity_case "$string_interp_case"
run_parity_case "$params_case"

require_matrix_status "AST_FLOAT" "partial"
require_matrix_status "AST_INT_LIMIT" "partial"
require_matrix_status "AST_STRING" "partial"
require_matrix_status "AST_CHAR" "partial"
require_matrix_status "AST_STRING_INTERP" "partial"
require_matrix_status "AST_PARAMS" "partial"
require_matrix_status "@params" "partial"

echo "OK: MIR-C99 real CLI value entry parity matched the C99 oracle"
