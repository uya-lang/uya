#!/usr/bin/env bash
#
# Self-build absence gate: the MIR-C99 real compiler candidate path must not
# call the legacy AST C99 backend as its success path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-self-build-absence.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 self-build absence evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "error: forbidden MIR-C99 self-build absence evidence: $description" >&2
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
"$candidate_bin" --help >"$candidate_stdout" 2>"$candidate_stderr"

require_pattern "$log_file" '^self_build_convergence_status=real_compiler_candidate$' \
    "diagnostic log records real compiler candidate convergence status"
require_pattern "$log_file" '^host_compiler_binary_status=generated$' \
    "diagnostic log records generated compiler binary status"
require_pattern "$log_file" '^compiler_source_backend=mir_c99_unit_output$' \
    "diagnostic log records MIR-C99 unit output backend"
require_pattern "$summary_file" '^MIR_C99_SELF_BUILD_CONVERGENCE_STATUS='\''real_compiler_candidate'\''$' \
    "summary records real compiler candidate convergence status"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_STATUS='\''generated'\''$' \
    "summary records generated compiler binary status"
require_pattern "$summary_file" '^MIR_C99_COMPILER_SOURCE_BACKEND='\''mir_c99_unit_output'\''$' \
    "summary records MIR-C99 unit output backend"

reject_pattern "$log_file" 'legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|tracked_cmd_build_seed|backup/cmd-build' \
    "diagnostic log must not mention legacy AST C99 backend or tracked seed"
reject_pattern "$summary_file" 'legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|tracked_cmd_build_seed|backup/cmd-build' \
    "summary must not mention legacy AST C99 backend or tracked seed"
reject_pattern "$candidate_stdout" 'legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|tracked_cmd_build_seed|backup/cmd-build' \
    "candidate stdout must not mention legacy AST C99 backend or tracked seed"
reject_pattern "$candidate_stderr" 'legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|tracked_cmd_build_seed|backup/cmd-build' \
    "candidate stderr must not mention legacy AST C99 backend or tracked seed"

bash "$REPO_ROOT/tests/verify_mir_c99_independent_boundary.sh"

echo "OK: MIR-C99 self-build absence gate confirms no legacy AST C99 backend on real compiler candidate path"
