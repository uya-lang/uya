#!/usr/bin/env bash
#
# MIR-C99 self-build must expose a real compiler candidate for cmd/build.
# The candidate C must compile with the host C compiler and pass a minimal
# compiler smoke test (--help).

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
        echo "error: missing MIR-C99 cmd/build host binary evidence: $description" >&2
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

cc -std=c99 -Wall -Wextra -pedantic "$output_c" -o "$candidate_bin" -lm

set +e
"$candidate_bin" --help >"$candidate_stdout" 2>"$candidate_stderr"
run_status=$?
set -e

if [[ "$run_status" -ne 0 ]]; then
    echo "error: real compiler candidate should pass --help with exit 0, got $run_status" >&2
    cat "$candidate_stdout" >&2
    cat "$candidate_stderr" >&2
    exit 1
fi

require_pattern "$log_file" '^host_compiler_binary_attempt=1$' \
    "diagnostic log records the host compiler binary attempt gate"
require_pattern "$log_file" '^self_build_convergence_status=real_compiler_candidate$' \
    "diagnostic log records real compiler candidate convergence status"
require_pattern "$log_file" '^host_compiler_binary_status=generated$' \
    "diagnostic log records the generated compiler binary status"
require_pattern "$log_file" '^host_compiler_binary_candidate_role=compiler_binary$' \
    "diagnostic log distinguishes real compiler binary from summary executable"
require_pattern "$log_file" '^compiler_binary_status=generated$' \
    "diagnostic log records compiler binary generated"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_ATTEMPT=1$' \
    "summary sidecar records host compiler binary attempt"
require_pattern "$summary_file" '^MIR_C99_SELF_BUILD_CONVERGENCE_STATUS='\''real_compiler_candidate'\''$' \
    "summary sidecar records real compiler candidate convergence status"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_STATUS='\''generated'\''$' \
    "summary sidecar records generated compiler binary status"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_CANDIDATE_ROLE='\''compiler_binary'\''$' \
    "summary sidecar records compiler binary candidate role"
require_pattern "$summary_file" '^MIR_C99_COMPILER_SOURCE_BACKEND='\''mir_c99_unit_output'\''$' \
    "summary sidecar records the compiler source backend used for the candidate"
if ! grep -Eq 'Uya build compiler' "$candidate_stdout" "$candidate_stderr"; then
    echo "error: missing MIR-C99 cmd/build host binary evidence: candidate executable identifies as Uya build compiler" >&2
    echo "stdout file: $candidate_stdout" >&2
    echo "stderr file: $candidate_stderr" >&2
    exit 1
fi
if ! grep -Eq '用法:' "$candidate_stdout" "$candidate_stderr"; then
    echo "error: missing MIR-C99 cmd/build host binary evidence: candidate executable prints usage in Chinese" >&2
    echo "stdout file: $candidate_stdout" >&2
    echo "stderr file: $candidate_stderr" >&2
    exit 1
fi

# The candidate C is produced by the MIR-C99 unit output writer. Keep the
# fallback check focused on diagnostics and runtime output; source-body absence
# is covered by the dedicated true-writer gate.
if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$summary_file" "$candidate_stdout" "$candidate_stderr"; then
    echo "error: MIR-C99 cmd/build host binary gate mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    cat "$candidate_stdout" >&2
    cat "$candidate_stderr" >&2
    exit 1
fi

echo "OK: MIR-C99 cmd/build host compiler binary attempt gate emits real compiler candidate and passes --help smoke"
