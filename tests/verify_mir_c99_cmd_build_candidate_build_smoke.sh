#!/usr/bin/env bash
#
# MIR-C99 self-build candidate must behave as a real build compiler: after the
# host C compiler turns the candidate C into an executable, it must compile a
# minimal Uya program into a runnable host binary with the expected exit code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-candidate-build-smoke.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 cmd/build candidate build smoke evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"
candidate_bin="$TMP_DIR/cmd-build-mir-candidate"
program_source="$TMP_DIR/return7.uya"
program_bin="$TMP_DIR/return7.bin"
build_stdout="$TMP_DIR/build.out"
build_stderr="$TMP_DIR/build.err"
run_stdout="$TMP_DIR/run.out"
run_stderr="$TMP_DIR/run.err"

cat >"$program_source" <<'UYA'
export fn main() i32 {
    return 7;
}
UYA

"$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

cc -std=c99 -Wall -Wextra -pedantic "$output_c" -o "$candidate_bin" -lm

set +e
"$candidate_bin" build "$program_source" -o "$program_bin" >"$build_stdout" 2>"$build_stderr"
build_status=$?
set -e

if [[ "$build_status" -ne 0 ]]; then
    echo "error: MIR-C99 cmd/build candidate failed to compile a minimal program, got $build_status" >&2
    cat "$build_stdout" >&2
    cat "$build_stderr" >&2
    exit 1
fi

if [[ ! -x "$program_bin" ]]; then
    echo "error: MIR-C99 cmd/build candidate did not leave a runnable output binary" >&2
    ls -l "$TMP_DIR" >&2
    exit 1
fi

set +e
"$program_bin" >"$run_stdout" 2>"$run_stderr"
run_status=$?
set -e

if [[ "$run_status" -ne 7 ]]; then
    echo "error: MIR-C99 cmd/build candidate output binary returned $run_status, expected 7" >&2
    cat "$run_stdout" >&2
    cat "$run_stderr" >&2
    exit 1
fi

require_pattern "$log_file" '^self_build_convergence_status=real_compiler_candidate$' \
    "diagnostic log records real compiler candidate convergence status"
require_pattern "$log_file" '^compiler_binary_status=generated$' \
    "diagnostic log records compiler binary generated"
require_pattern "$log_file" '^host_compiler_binary_candidate_role=compiler_binary$' \
    "diagnostic log records compiler binary candidate role"
require_pattern "$summary_file" '^MIR_C99_SELF_BUILD_CONVERGENCE_STATUS='\''real_compiler_candidate'\''$' \
    "summary sidecar records real compiler candidate convergence status"
require_pattern "$summary_file" '^MIR_C99_COMPILER_BINARY_STATUS='\''generated'\''$' \
    "summary sidecar records compiler binary generated"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_CANDIDATE_ROLE='\''compiler_binary'\''$' \
    "summary sidecar records compiler binary candidate role"

if ! grep -Eq 'MIR-C99 unit output build smoke generated executable with return 7' "$build_stderr"; then
    echo "error: missing MIR-C99 cmd/build candidate build smoke evidence: candidate reports successful build in stderr" >&2
    echo "stderr file: $build_stderr" >&2
    exit 1
fi

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$summary_file" "$build_stdout" "$build_stderr" "$run_stdout" "$run_stderr"; then
    echo "error: MIR-C99 cmd/build candidate build smoke mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    cat "$build_stdout" >&2
    cat "$build_stderr" >&2
    exit 1
fi

echo "OK: MIR-C99 cmd/build real compiler candidate compiles and runs a minimal program"
