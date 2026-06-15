#!/usr/bin/env bash
#
# MIR-C99-built compiler parity cannot be claimed from the --help-only
# cmd/build smoke candidate. This gate is intentionally stricter than the
# host-binary smoke gate: the candidate must accept a real build command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_smoke.uya"
RETURN_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_return7.uya"
GENERIC_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_generic_identity.uya"
OUTPARAM_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_local_array_outparam.uya"
STACK_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_stack_limit_call.uya"
PARSE_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_parse_like_outparam.uya"
ARRAY_INDEX_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_hosted_array_index.uya"
BRANCH_LOOP_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_full_language_branch_loop.uya"
FULL_ARRAY_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_full_language_array.uya"
SLICE_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_full_language_slice.uya"
STRUCT_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_full_language_struct.uya"
TUPLE_FIXTURE="$REPO_ROOT/tests/fixtures/mir_c99_cmd_build_full_language_tuple.uya"
ORACLE_COMPILER="$REPO_ROOT/bin/uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-cmd-build-parity-frontier.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 cmd/build parity frontier evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"
candidate_bin="$TMP_DIR/cmd-build-mir-candidate"
program_bin="$TMP_DIR/mir-c99-smoke"
candidate_stdout="$TMP_DIR/candidate.out"
candidate_stderr="$TMP_DIR/candidate.err"
program_stdout="$TMP_DIR/program.out"
program_stderr="$TMP_DIR/program.err"
run_candidate_oracle_case() {
    local name="$1"
    local fixture="$2"
    local candidate_out="$TMP_DIR/$name.mir"
    local oracle_c="$TMP_DIR/$name.oracle.c"
    local oracle_bin="$TMP_DIR/$name.oracle"
    local candidate_status
    local oracle_status

    if ! "$candidate_bin" build "$fixture" -o "$candidate_out" --project-root "$REPO_ROOT" \
        >"$TMP_DIR/$name.candidate.build.out" 2>"$TMP_DIR/$name.candidate.build.err"; then
        echo "error: MIR-C99 cmd/build $name candidate build failed" >&2
        cat "$TMP_DIR/$name.candidate.build.out" >&2
        cat "$TMP_DIR/$name.candidate.build.err" >&2
        exit 1
    fi
    if ! "$ORACLE_COMPILER" build "$fixture" -o "$oracle_c" --no-split-c --project-root "$REPO_ROOT" \
        >"$TMP_DIR/$name.oracle.build.out" 2>"$TMP_DIR/$name.oracle.build.err"; then
        echo "error: MIR-C99 cmd/build $name oracle build failed" >&2
        cat "$TMP_DIR/$name.oracle.build.out" >&2
        cat "$TMP_DIR/$name.oracle.build.err" >&2
        exit 1
    fi
    if ! cc -std=c99 -Wall -Wextra -pedantic "$oracle_c" -o "$oracle_bin" -lm \
        >"$TMP_DIR/$name.oracle.cc.out" 2>"$TMP_DIR/$name.oracle.cc.err"; then
        echo "error: MIR-C99 cmd/build $name oracle C compile failed" >&2
        cat "$TMP_DIR/$name.oracle.cc.out" >&2
        cat "$TMP_DIR/$name.oracle.cc.err" >&2
        exit 1
    fi

    set +e
    "$candidate_out" >"$TMP_DIR/$name.candidate.out" 2>"$TMP_DIR/$name.candidate.err"
    candidate_status=$?
    "$oracle_bin" >"$TMP_DIR/$name.oracle.out" 2>"$TMP_DIR/$name.oracle.err"
    oracle_status=$?
    set -e

    if [[ "$candidate_status" -ne "$oracle_status" ]]; then
        echo "error: MIR-C99 cmd/build $name exit differs from C99 oracle: mir=$candidate_status oracle=$oracle_status" >&2
        exit 1
    fi
    if ! cmp -s "$TMP_DIR/$name.candidate.out" "$TMP_DIR/$name.oracle.out" ||
       ! cmp -s "$TMP_DIR/$name.candidate.err" "$TMP_DIR/$name.oracle.err"; then
        echo "error: MIR-C99 cmd/build $name output differs from C99 oracle" >&2
        exit 1
    fi
}

"$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

cc -std=c99 -Wall -Wextra -pedantic "$output_c" -o "$candidate_bin" -lm

set +e
"$candidate_bin" build "$FIXTURE" -o "$program_bin" --project-root "$REPO_ROOT" \
    >"$candidate_stdout" 2>"$candidate_stderr"
run_status=$?
set -e

if [[ "$run_status" -ne 0 ]]; then
    echo "error: MIR-C99-built compiler candidate must accept a real build command before parity can run, got exit $run_status" >&2
    cat "$candidate_stdout" >&2
    cat "$candidate_stderr" >&2
    exit 1
fi

test -x "$program_bin"

set +e
"$program_bin" >"$program_stdout" 2>"$program_stderr"
program_status=$?
set -e

if [[ "$program_status" -ne 0 ]]; then
    echo "error: MIR-C99 cmd/build smoke output should run with exit 0, got $program_status" >&2
    cat "$program_stdout" >&2
    cat "$program_stderr" >&2
    exit 1
fi

run_candidate_oracle_case return_literal "$RETURN_FIXTURE"
run_candidate_oracle_case generic_identity "$GENERIC_FIXTURE"
run_candidate_oracle_case local_array_outparam "$OUTPARAM_FIXTURE"
run_candidate_oracle_case stack_limit_call "$STACK_FIXTURE"
run_candidate_oracle_case parse_like_outparam "$PARSE_FIXTURE"
run_candidate_oracle_case hosted_array_index "$ARRAY_INDEX_FIXTURE"
run_candidate_oracle_case full_language_branch_loop "$BRANCH_LOOP_FIXTURE"
run_candidate_oracle_case full_language_array "$FULL_ARRAY_FIXTURE"
run_candidate_oracle_case full_language_slice "$SLICE_FIXTURE"
run_candidate_oracle_case full_language_struct "$STRUCT_FIXTURE"
run_candidate_oracle_case full_language_tuple "$TUPLE_FIXTURE"

require_pattern "$log_file" '^compiler_source_backend=mir_c99_unit_output$' \
    "generator uses MIR-C99 unit output backend"
require_pattern "$log_file" '^parity_frontier_status=return_literal_c99_output_parity$' \
    "generator records return-literal C99 output parity frontier"
require_pattern "$log_file" '^compiler_regression_status=generic_identity_outparam_stack_parse_array_smoke$' \
    "generator records generic identity, out-param, stack-limit, parse-like, and array-index compiler regression smoke"
require_pattern "$log_file" '^c99_output_parity_status=return_literal_smoke$' \
    "generator records return-literal C99 output parity smoke"
require_pattern "$log_file" '^full_language_backend_parity_status=branch_loop_array_slice_struct_tuple_smoke$' \
    "generator records branch/loop, array, slice, struct, and tuple full-language parity smoke"
require_pattern "$summary_file" "^MIR_C99_COMPILER_SOURCE_BACKEND='mir_c99_unit_output'$" \
    "summary records MIR-C99 unit output backend"
require_pattern "$summary_file" "^MIR_C99_PARITY_FRONTIER_STATUS='return_literal_c99_output_parity'$" \
    "summary records return-literal C99 output parity frontier"
require_pattern "$summary_file" "^MIR_C99_COMPILER_REGRESSION_STATUS='generic_identity_outparam_stack_parse_array_smoke'$" \
    "summary records generic identity, out-param, stack-limit, parse-like, and array-index compiler regression smoke"
require_pattern "$summary_file" "^MIR_C99_C99_OUTPUT_PARITY_STATUS='return_literal_smoke'$" \
    "summary records return-literal C99 output parity smoke"
require_pattern "$summary_file" "^MIR_C99_FULL_LANGUAGE_BACKEND_PARITY_STATUS='branch_loop_array_slice_struct_tuple_smoke'$" \
    "summary records branch/loop, array, slice, struct, and tuple full-language parity smoke"

echo "OK: MIR-C99 cmd/build candidate passes regression, C99 output, and branch/loop/array/slice/struct/tuple full-language parity frontier"
