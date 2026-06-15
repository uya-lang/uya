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
return_program_bin="$TMP_DIR/mir-c99-return7"
return_oracle_c="$TMP_DIR/oracle-return7.c"
return_oracle_bin="$TMP_DIR/oracle-return7"
return_candidate_stdout="$TMP_DIR/return-candidate.out"
return_candidate_stderr="$TMP_DIR/return-candidate.err"
return_program_stdout="$TMP_DIR/return-program.out"
return_program_stderr="$TMP_DIR/return-program.err"
return_oracle_stdout="$TMP_DIR/return-oracle.out"
return_oracle_stderr="$TMP_DIR/return-oracle.err"
generic_program_bin="$TMP_DIR/mir-c99-generic-identity"
generic_oracle_c="$TMP_DIR/oracle-generic-identity.c"
generic_oracle_bin="$TMP_DIR/oracle-generic-identity"
outparam_program_bin="$TMP_DIR/mir-c99-local-array-outparam"
outparam_oracle_c="$TMP_DIR/oracle-local-array-outparam.c"
outparam_oracle_bin="$TMP_DIR/oracle-local-array-outparam"

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

set +e
"$candidate_bin" build "$RETURN_FIXTURE" -o "$return_program_bin" --project-root "$REPO_ROOT" \
    >"$return_candidate_stdout" 2>"$return_candidate_stderr"
return_build_status=$?
set -e

if [[ "$return_build_status" -ne 0 ]]; then
    echo "error: MIR-C99 cmd/build return-literal smoke build failed with exit $return_build_status" >&2
    cat "$return_candidate_stdout" >&2
    cat "$return_candidate_stderr" >&2
    exit 1
fi

"$ORACLE_COMPILER" build "$RETURN_FIXTURE" -o "$return_oracle_c" --no-split-c --project-root "$REPO_ROOT" \
    >"$TMP_DIR/oracle.build.out" 2>"$TMP_DIR/oracle.build.err"
cc -std=c99 -Wall -Wextra -pedantic "$return_oracle_c" -o "$return_oracle_bin" -lm \
    >"$TMP_DIR/oracle.cc.out" 2>"$TMP_DIR/oracle.cc.err"

set +e
"$return_program_bin" >"$return_program_stdout" 2>"$return_program_stderr"
return_program_status=$?
"$return_oracle_bin" >"$return_oracle_stdout" 2>"$return_oracle_stderr"
return_oracle_status=$?
set -e

if [[ "$return_program_status" -ne "$return_oracle_status" ]]; then
    echo "error: MIR-C99 cmd/build return-literal exit differs from C99 oracle: mir=$return_program_status oracle=$return_oracle_status" >&2
    cat "$return_program_stdout" >&2
    cat "$return_program_stderr" >&2
    cat "$return_oracle_stdout" >&2
    cat "$return_oracle_stderr" >&2
    exit 1
fi
if ! cmp -s "$return_program_stdout" "$return_oracle_stdout" ||
   ! cmp -s "$return_program_stderr" "$return_oracle_stderr"; then
    echo "error: MIR-C99 cmd/build return-literal output differs from C99 oracle" >&2
    exit 1
fi

"$candidate_bin" build "$GENERIC_FIXTURE" -o "$generic_program_bin" --project-root "$REPO_ROOT" \
    >"$TMP_DIR/generic.candidate.out" 2>"$TMP_DIR/generic.candidate.err"
"$ORACLE_COMPILER" build "$GENERIC_FIXTURE" -o "$generic_oracle_c" --no-split-c --project-root "$REPO_ROOT" \
    >"$TMP_DIR/generic.oracle.build.out" 2>"$TMP_DIR/generic.oracle.build.err"
cc -std=c99 -Wall -Wextra -pedantic "$generic_oracle_c" -o "$generic_oracle_bin" -lm \
    >"$TMP_DIR/generic.oracle.cc.out" 2>"$TMP_DIR/generic.oracle.cc.err"

set +e
"$generic_program_bin" >"$TMP_DIR/generic.program.out" 2>"$TMP_DIR/generic.program.err"
generic_program_status=$?
"$generic_oracle_bin" >"$TMP_DIR/generic.oracle.out" 2>"$TMP_DIR/generic.oracle.err"
generic_oracle_status=$?
set -e

if [[ "$generic_program_status" -ne "$generic_oracle_status" ]]; then
    echo "error: MIR-C99 cmd/build generic identity regression exit differs from C99 oracle: mir=$generic_program_status oracle=$generic_oracle_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/generic.program.out" "$TMP_DIR/generic.oracle.out" ||
   ! cmp -s "$TMP_DIR/generic.program.err" "$TMP_DIR/generic.oracle.err"; then
    echo "error: MIR-C99 cmd/build generic identity regression output differs from C99 oracle" >&2
    exit 1
fi

"$candidate_bin" build "$OUTPARAM_FIXTURE" -o "$outparam_program_bin" --project-root "$REPO_ROOT" \
    >"$TMP_DIR/outparam.candidate.out" 2>"$TMP_DIR/outparam.candidate.err"
"$ORACLE_COMPILER" build "$OUTPARAM_FIXTURE" -o "$outparam_oracle_c" --no-split-c --project-root "$REPO_ROOT" \
    >"$TMP_DIR/outparam.oracle.build.out" 2>"$TMP_DIR/outparam.oracle.build.err"
cc -std=c99 -Wall -Wextra -pedantic "$outparam_oracle_c" -o "$outparam_oracle_bin" -lm \
    >"$TMP_DIR/outparam.oracle.cc.out" 2>"$TMP_DIR/outparam.oracle.cc.err"

set +e
"$outparam_program_bin" >"$TMP_DIR/outparam.program.out" 2>"$TMP_DIR/outparam.program.err"
outparam_program_status=$?
"$outparam_oracle_bin" >"$TMP_DIR/outparam.oracle.out" 2>"$TMP_DIR/outparam.oracle.err"
outparam_oracle_status=$?
set -e

if [[ "$outparam_program_status" -ne "$outparam_oracle_status" ]]; then
    echo "error: MIR-C99 cmd/build local array out-param regression exit differs from C99 oracle: mir=$outparam_program_status oracle=$outparam_oracle_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/outparam.program.out" "$TMP_DIR/outparam.oracle.out" ||
   ! cmp -s "$TMP_DIR/outparam.program.err" "$TMP_DIR/outparam.oracle.err"; then
    echo "error: MIR-C99 cmd/build local array out-param regression output differs from C99 oracle" >&2
    exit 1
fi

require_pattern "$log_file" '^compiler_source_backend=mir_c99_unit_output$' \
    "generator uses MIR-C99 unit output backend"
require_pattern "$log_file" '^parity_frontier_status=return_literal_c99_output_parity$' \
    "generator records return-literal C99 output parity frontier"
require_pattern "$log_file" '^compiler_regression_status=generic_identity_and_outparam_smoke$' \
    "generator records generic identity and out-param compiler regression smoke"
require_pattern "$log_file" '^c99_output_parity_status=return_literal_smoke$' \
    "generator records return-literal C99 output parity smoke"
require_pattern "$log_file" '^full_language_backend_parity_status=not_yet_run$' \
    "generator does not claim full-language backend parity"
require_pattern "$summary_file" "^MIR_C99_COMPILER_SOURCE_BACKEND='mir_c99_unit_output'$" \
    "summary records MIR-C99 unit output backend"
require_pattern "$summary_file" "^MIR_C99_PARITY_FRONTIER_STATUS='return_literal_c99_output_parity'$" \
    "summary records return-literal C99 output parity frontier"
require_pattern "$summary_file" "^MIR_C99_COMPILER_REGRESSION_STATUS='generic_identity_and_outparam_smoke'$" \
    "summary records generic identity and out-param compiler regression smoke"
require_pattern "$summary_file" "^MIR_C99_C99_OUTPUT_PARITY_STATUS='return_literal_smoke'$" \
    "summary records return-literal C99 output parity smoke"
require_pattern "$summary_file" "^MIR_C99_FULL_LANGUAGE_BACKEND_PARITY_STATUS='not_yet_run'$" \
    "summary does not claim full-language backend parity"

echo "OK: MIR-C99 cmd/build candidate passes generic identity/out-param regressions and return-literal C99 output parity frontier"
