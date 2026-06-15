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

require_pattern "$log_file" '^compiler_source_backend=mir_c99_unit_output$' \
    "generator uses MIR-C99 unit output backend"
require_pattern "$log_file" '^parity_frontier_status=build_smoke_only$' \
    "generator records that parity frontier is only a build smoke"
require_pattern "$log_file" '^compiler_regression_status=not_yet_run$' \
    "generator does not claim compiler regression parity"
require_pattern "$log_file" '^c99_output_parity_status=not_yet_run$' \
    "generator does not claim C99 output parity"
require_pattern "$log_file" '^full_language_backend_parity_status=not_yet_run$' \
    "generator does not claim full-language backend parity"
require_pattern "$summary_file" "^MIR_C99_COMPILER_SOURCE_BACKEND='mir_c99_unit_output'$" \
    "summary records MIR-C99 unit output backend"
require_pattern "$summary_file" "^MIR_C99_PARITY_FRONTIER_STATUS='build_smoke_only'$" \
    "summary records build-smoke-only parity frontier"
require_pattern "$summary_file" "^MIR_C99_COMPILER_REGRESSION_STATUS='not_yet_run'$" \
    "summary does not claim compiler regression parity"
require_pattern "$summary_file" "^MIR_C99_C99_OUTPUT_PARITY_STATUS='not_yet_run'$" \
    "summary does not claim C99 output parity"
require_pattern "$summary_file" "^MIR_C99_FULL_LANGUAGE_BACKEND_PARITY_STATUS='not_yet_run'$" \
    "summary does not claim full-language backend parity"

echo "OK: MIR-C99 cmd/build candidate accepts real build command for parity frontier"
