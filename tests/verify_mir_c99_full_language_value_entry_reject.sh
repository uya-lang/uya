#!/usr/bin/env bash
#
# Real-CLI reject gate for MIR-C99 value/expr entrypoints that are still
# expected to fail closed before full expr/value/place lowering lands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

if [[ ! -x "$COMPILER" ]]; then
    echo "error: fixed MIR-C99 compiler is missing or not executable: $COMPILER" >&2
    exit 69
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-value-reject.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
CANDIDATE_BIN=""

int_limit_case="$tmp_dir/int_limit_case.uya"
string_interp_case="$tmp_dir/string_interp_case.uya"
params_case="$tmp_dir/params_case.uya"

cat >"$int_limit_case" <<'UYA'
export fn main() i32 {
    const limit: i32 = @max;
    return limit;
}
UYA

cat >"$string_interp_case" <<'UYA'
export fn main() i32 {
    const value: i32 = 7;
    const msg: [i8: 32] = "value=${value}\n";
    if @len(msg) == 0usize {
        return 1;
    }
    return 0;
}
UYA

cat >"$params_case" <<'UYA'
fn pair_sum(a: i32, b: i32) i32 {
    return @params.0 + @params.1;
}

export fn main() i32 {
    return pair_sum(3, 4);
}
UYA

build_candidate() {
    local candidate_log="$tmp_dir/cmd_build_candidate.generate.log"
    CANDIDATE_BIN="$tmp_dir/cmd_build_candidate"

    if ! (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" ../uya/bin/uya build \
            src/cmd/build/main.uya -o "$CANDIDATE_BIN" --no-split-c --project-root src
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

run_expect_diag() {
    local name="$1"
    local input="$2"
    local output="$3"
    local log="$4"
    local pattern="$5"

    set +e
    (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" "$CANDIDATE_BIN" build --mir-c99 "$input" \
            -o "$output" --project-root "$REPO_ROOT"
    ) >"$log" 2>&1
    local status=$?
    set -e

    if [[ $status -eq 0 ]]; then
        echo "error: expected $name to fail closed under real --mir-c99" >&2
        exit 1
    fi
    grep -q '\[MIR-C99\]' "$log"
    grep -q "$pattern" "$log"
    if [[ -e "$output" && -s "$output" ]]; then
        echo "error: $name left a non-empty MIR-C99 output after fail-closed diagnostic" >&2
        exit 1
    fi
}

require_matrix_reject() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| reject \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked reject in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

build_candidate

run_expect_diag "int-limit value" "$int_limit_case" "$tmp_dir/int_limit_case.mir.c" \
    "$tmp_dir/int_limit_case.mir.log" \
    'mir_c99_capability_diagnostic: kind=AST_INT_LIMIT reason=int_limit_requires_expr_value_place'

run_expect_diag "string interpolation value" "$string_interp_case" "$tmp_dir/string_interp_case.mir.c" \
    "$tmp_dir/string_interp_case.mir.log" \
    'mir_c99_capability_diagnostic: kind=AST_STRING_INTERP reason=string_interp_requires_expr_value_place'

run_expect_diag "params tuple builtin" "$params_case" "$tmp_dir/params_case.mir.c" \
    "$tmp_dir/params_case.mir.log" \
    'mir_c99_capability_diagnostic: kind=AST_PARAMS reason=params_tuple_requires_expr_value_place'

require_matrix_reject "AST_INT_LIMIT"
require_matrix_reject "AST_STRING_INTERP"
require_matrix_reject "AST_PARAMS"
require_matrix_reject "@params"

echo "OK: MIR-C99 real CLI fail-closed value entry diagnostics are explicit"
