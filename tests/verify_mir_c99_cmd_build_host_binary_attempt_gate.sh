#!/usr/bin/env bash
#
# MIR-C99 self-build must expose an explicit host compiler binary attempt gate.
# Until the compiler candidate is real, the gate must still compile the emitted
# C with the host compiler and report the current compiler-source frontier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-cmd-build-host-binary.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 cmd/build host binary attempt evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"
candidate_bin="$TMP_DIR/cmd-build-mir-candidate"
candidate_stdout="$TMP_DIR/candidate.out"
candidate_stderr="$TMP_DIR/candidate.err"

"$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

cc -std=c99 -Wall -Wextra -pedantic "$output_c" -o "$candidate_bin"

set +e
"$candidate_bin" --help >"$candidate_stdout" 2>"$candidate_stderr"
run_status=$?
set -e

if [[ "$run_status" -ne 70 ]]; then
    echo "error: summary-only compiler candidate should report not-yet-generated with exit 70, got $run_status" >&2
    cat "$candidate_stdout" >&2
    cat "$candidate_stderr" >&2
    exit 1
fi

require_pattern "$log_file" '^host_compiler_binary_attempt=1$' \
    "diagnostic log records the host compiler binary attempt gate"
require_pattern "$log_file" '^host_compiler_binary_status=not_yet_generated$' \
    "diagnostic log records the current non-compiler status"
require_pattern "$log_file" '^host_compiler_binary_candidate_role=summary_executable$' \
    "diagnostic log distinguishes summary executable from compiler binary"
require_pattern "$log_file" '^frontier_detail=native_hosted_reachable_body_frontier:function=compile_stats_record_and_release_typed_program,prefix_stmts=14,next_stmt=14,next_kind=AST_ASSIGN,reason=partial_core_body$' \
    "diagnostic log preserves the current compiler-source frontier"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_ATTEMPT=1$' \
    "summary sidecar records host compiler binary attempt"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_STATUS='\''not_yet_generated'\''' \
    "summary sidecar records non-compiler candidate status"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_CANDIDATE_ROLE='\''summary_executable'\''' \
    "summary sidecar records summary executable candidate role"
require_pattern "$candidate_stderr" '^compiler_binary_status=not_yet_generated$' \
    "candidate executable reports that it is not a compiler binary"
require_pattern "$candidate_stderr" '^frontier_name=native_hosted_handoff_frontier$' \
    "candidate executable reports the current self-build frontier"

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$summary_file" "$output_c" "$candidate_stdout" "$candidate_stderr"; then
    echo "error: MIR-C99 host binary attempt mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    cat "$output_c" >&2
    cat "$candidate_stdout" >&2
    cat "$candidate_stderr" >&2
    exit 1
fi

echo "OK: MIR-C99 cmd/build host compiler binary attempt gate records summary-only frontier"
