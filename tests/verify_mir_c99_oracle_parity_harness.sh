#!/usr/bin/env bash
#
# MIR-C99 vs legacy C99 oracle parity harness.
#
# Contract:
#   - Generate MIR-C99 C from a Uya input.
#   - Generate legacy C99 oracle C from the same input.
#   - Compile both with the host C99 compiler.
#   - Run both and diff stdout, stderr, and exit code.
#   - Check MIR-C99 generation logs do not reveal a fallback to the legacy C99
#     production backend.
#
# Running a parity case requires real generator commands; missing commands are
# a failing gate so TODO parity shards cannot be marked by a pending hookup.
# `--self-test` exercises the full harness with fake generators.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST_CC="${HOST_CC:-cc}"
MIR_C99_GENERATE_CMD="${MIR_C99_GENERATE_CMD:-}"
C99_ORACLE_GENERATE_CMD="${C99_ORACLE_GENERATE_CMD:-}"
CASE_FILE=""
KEEP_TMP=0
SELF_TEST=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --case)
            if [[ $# -lt 2 ]]; then
                echo "error: --case requires a .uya path" >&2
                exit 1
            fi
            CASE_FILE="$2"
            shift 2
            ;;
        --keep-tmp)
            KEEP_TMP=1
            shift
            ;;
        --self-test)
            SELF_TEST=1
            shift
            ;;
        -h|--help)
            cat >&2 <<'EOF'
用法:
  MIR_C99_GENERATE_CMD='cmd {input} {output}' \
  C99_ORACLE_GENERATE_CMD='cmd {input} {output}' \
  bash tests/verify_mir_c99_oracle_parity_harness.sh --case tests/foo.uya

占位符:
  {input}  输入 Uya 文件
  {output} 输出 C 文件
  {log}    生成日志文件
EOF
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

run_generator() {
    local template="$1"
    local input="$2"
    local output="$3"
    local log="$4"
    local cmd
    cmd="${template//\{input\}/$input}"
    cmd="${cmd//\{output\}/$output}"
    cmd="${cmd//\{log\}/$log}"
    bash -c "$cmd" >"$log" 2>&1
}

compile_c() {
    local input_c="$1"
    local output_bin="$2"
    "$HOST_CC" -std=c99 -Wall -Wextra -pedantic "$input_c" -o "$output_bin"
}

run_binary_capture() {
    local bin="$1"
    local prefix="$2"
    set +e
    "$bin" >"$prefix.stdout" 2>"$prefix.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$prefix.exit"
}

check_no_fallback() {
    local log="$1"
    if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' "$log"; then
        echo "error: MIR-C99 generator log indicates legacy C99 fallback: $log" >&2
        grep -Ein 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' "$log" >&2 || true
        return 1
    fi
}

diff_outputs() {
    local mir_prefix="$1"
    local oracle_prefix="$2"
    diff -u "$oracle_prefix.stdout" "$mir_prefix.stdout"
    diff -u "$oracle_prefix.stderr" "$mir_prefix.stderr"
    diff -u "$oracle_prefix.exit" "$mir_prefix.exit"
}

run_parity_case() {
    local case_file="$1"
    local tmp_dir
    tmp_dir="$(mktemp -d /tmp/uya-mir-c99-parity.XXXXXX)"
    if [[ "$KEEP_TMP" -eq 0 ]]; then
        trap 'rm -rf "$tmp_dir"' RETURN
    else
        echo "tmp: $tmp_dir"
    fi

    local mir_c="$tmp_dir/mir.c"
    local oracle_c="$tmp_dir/oracle.c"
    local mir_log="$tmp_dir/mir.generate.log"
    local oracle_log="$tmp_dir/oracle.generate.log"
    local mir_bin="$tmp_dir/mir.out"
    local oracle_bin="$tmp_dir/oracle.out"

    run_generator "$MIR_C99_GENERATE_CMD" "$case_file" "$mir_c" "$mir_log"
    check_no_fallback "$mir_log"
    run_generator "$C99_ORACLE_GENERATE_CMD" "$case_file" "$oracle_c" "$oracle_log"

    compile_c "$mir_c" "$mir_bin"
    compile_c "$oracle_c" "$oracle_bin"

    run_binary_capture "$mir_bin" "$tmp_dir/mir"
    run_binary_capture "$oracle_bin" "$tmp_dir/oracle"
    diff_outputs "$tmp_dir/mir" "$tmp_dir/oracle"

    echo "OK: MIR-C99/oracle parity matched for $case_file"
}

run_self_test() {
    local tmp_dir
    local case_file
    local mir_gen
    local oracle_gen
    tmp_dir="$(mktemp -d /tmp/uya-mir-c99-parity-self.XXXXXX)"
    trap 'rm -rf "$tmp_dir"' RETURN
    case_file="$tmp_dir/return_7.uya"
    mir_gen="$tmp_dir/gen_mir.sh"
    oracle_gen="$tmp_dir/gen_oracle.sh"
    printf 'export fn main() i32 { return 7; }\n' >"$case_file"

    cat >"$mir_gen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input="$1"
output="$2"
log="$3"
printf 'mir generator consumed %s\n' "$input" >>"$log"
cat >"$output" <<'C_EOF'
#include <stdio.h>
int main(void) {
    fprintf(stderr, "diag\n");
    printf("value=%d\n", 7);
    return 7;
}
C_EOF
EOF
    chmod +x "$mir_gen"

    cat >"$oracle_gen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input="$1"
output="$2"
log="$3"
printf 'oracle generator consumed %s\n' "$input" >>"$log"
cat >"$output" <<'C_EOF'
#include <stdio.h>
int main(void) {
    fprintf(stderr, "diag\n");
    printf("value=%d\n", 7);
    return 7;
}
C_EOF
EOF
    chmod +x "$oracle_gen"

    MIR_C99_GENERATE_CMD="$mir_gen {input} {output} {log}" \
    C99_ORACLE_GENERATE_CMD="$oracle_gen {input} {output} {log}" \
    run_parity_case "$case_file" >/dev/null

    echo "OK: MIR-C99/oracle parity harness self-test passed"
}

if [[ "$SELF_TEST" -eq 1 ]]; then
    run_self_test
    exit 0
fi

if [[ -z "$MIR_C99_GENERATE_CMD" || -z "$C99_ORACLE_GENERATE_CMD" ]]; then
    if [[ -z "$CASE_FILE" ]]; then
        echo "OK: MIR-C99/oracle parity harness installed; generator commands are pending backend hookup"
        echo "hint: set MIR_C99_GENERATE_CMD and C99_ORACLE_GENERATE_CMD, then pass --case <file>"
        exit 0
    fi
    echo "error: MIR-C99/oracle parity generator commands are required for --case" >&2
    echo "hint: set MIR_C99_GENERATE_CMD and C99_ORACLE_GENERATE_CMD, then pass --case <file>" >&2
    exit 2
fi

if [[ -z "$CASE_FILE" ]]; then
    echo "error: --case is required when generator commands are configured" >&2
    exit 1
fi
if [[ ! -f "$CASE_FILE" ]]; then
    echo "error: missing case file: $CASE_FILE" >&2
    exit 1
fi

run_parity_case "$CASE_FILE"
