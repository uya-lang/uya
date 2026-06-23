#!/usr/bin/env bash
#
# Current-source MIR-C99 reject gate for direct target-sensitive builtins.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DRIVER="$REPO_ROOT/src/build_compiler_driver.uya"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 direct builtin capability reject missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$BUILD_DRIVER" "$GENERATOR" "$MATRIX_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    ASTNodeType.AST_ASM \
    ASTNodeType.AST_ASM_TARGET \
    ASTNodeType.AST_SYSCALL \
    ASTNodeType.AST_PTR_FROM_USIZE \
    ASTNodeType.AST_USIZE_FROM_PTR \
    inline_asm_requires_target_capability \
    asm_target_requires_target_capability \
    syscall_requires_target_capability \
    ptr_from_usize_requires_target_capability \
    usize_from_ptr_requires_target_capability; do
    require_pattern "$BUILD_DRIVER" "$symbol" "build driver symbol $symbol"
done

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-direct-builtins.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

asm_case="$tmp_dir/asm_case.uya"
asm_target_case="$tmp_dir/asm_target_case.uya"
syscall_case="$tmp_dir/syscall_case.uya"
ptr_from_usize_case="$tmp_dir/ptr_from_usize_case.uya"
usize_from_ptr_case="$tmp_dir/usize_from_ptr_case.uya"

cat >"$asm_case" <<'UYA'
export fn main() i32 {
    @asm {
        "nop" ();
    }
    return 0;
}
UYA

cat >"$asm_target_case" <<'UYA'
export fn main() i32 {
    const target: @asm_target = @asm_target();
    if target == .x86_64_linux {
        return 0;
    }
    return 1;
}
UYA

cat >"$syscall_case" <<'UYA'
export fn main() i32 {
    const pid: !i64 = @syscall(39);
    const _value: !i64 = pid;
    return 0;
}
UYA

cat >"$ptr_from_usize_case" <<'UYA'
export fn main() i32 {
    const ptr: &void = @ptr_from_usize(0usize);
    const _same: &void = ptr;
    return 0;
}
UYA

cat >"$usize_from_ptr_case" <<'UYA'
export fn main() i32 {
    const buf: [byte: 2] = "a";
    const addr: usize = @usize_from_ptr(&buf[0] as &void);
    const _same: usize = addr;
    return 0;
}
UYA

run_expect_diag() {
    local name="$1"
    local case_file="$2"
    local subset="$3"
    local kind="$4"
    local reason="$5"
    local output_file="$tmp_dir/${subset}.mir.c"
    local log_file="$tmp_dir/${subset}.mir.log"
    local stdout_file="$tmp_dir/${subset}.stdout"
    local stderr_file="$tmp_dir/${subset}.stderr"

    set +e
    bash "$GENERATOR" "$case_file" "$output_file" "$log_file" \
        >"$stdout_file" 2>"$stderr_file"
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        echo "error: expected $name to fail closed under MIR-C99 generator" >&2
        exit 1
    fi
    if [[ -e "$output_file" && -s "$output_file" ]]; then
        echo "error: $name left a non-empty MIR-C99 output after fail-closed diagnostic" >&2
        exit 1
    fi

    for pattern in \
        '^handoff_status=verified$' \
        '^writer_status=rejected$' \
        "^subset=${subset}$" \
        '^status=rejected$' \
        "^reject_reason=${reason}$" \
        "^mir_c99_capability_diagnostic: kind=${kind} reason=${reason}$"; do
        if ! grep -Eq "$pattern" "$log_file"; then
            echo "error: $name reject log missing pattern: $pattern" >&2
            cat "$log_file" >&2
            cat "$stdout_file" >&2
            cat "$stderr_file" >&2
            exit 1
        fi
    done

    if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
        "$log_file" "$stdout_file" "$stderr_file"; then
        echo "error: $name reject mentioned legacy fallback" >&2
        cat "$log_file" >&2
        cat "$stdout_file" >&2
        cat "$stderr_file" >&2
        exit 1
    fi
}

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| reject \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked reject in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_evidence() {
    local kind="$1"
    if ! grep -E "\\| \`$kind\` \\|" "$MATRIX_DOC" | \
        grep -Fq 'verify_mir_c99_full_language_direct_builtin_capability_reject.sh'; then
        echo "error: $kind must record direct builtin capability reject evidence" >&2
        exit 1
    fi
}

run_expect_diag "inline asm" "$asm_case" \
    "inline_asm_capability" "AST_ASM" \
    "inline_asm_requires_target_capability"
run_expect_diag "asm_target" "$asm_target_case" \
    "asm_target_capability" "AST_ASM_TARGET" \
    "asm_target_requires_target_capability"
run_expect_diag "syscall" "$syscall_case" \
    "syscall_capability" "AST_SYSCALL" \
    "syscall_requires_target_capability"
run_expect_diag "ptr_from_usize" "$ptr_from_usize_case" \
    "ptr_from_usize_capability" "AST_PTR_FROM_USIZE" \
    "ptr_from_usize_requires_target_capability"
run_expect_diag "usize_from_ptr" "$usize_from_ptr_case" \
    "usize_from_ptr_capability" "AST_USIZE_FROM_PTR" \
    "usize_from_ptr_requires_target_capability"

for kind in \
    AST_ASM \
    AST_ASM_TARGET \
    AST_SYSCALL \
    AST_PTR_FROM_USIZE \
    AST_USIZE_FROM_PTR \
    CORE_STMT_KIND_ASM \
    @syscall \
    @ptr_from_usize \
    @usize_from_ptr; do
    require_matrix_status "$kind"
    require_matrix_evidence "$kind"
done

require_pattern "$MATRIX_DOC" '\| `@asm`/`@asm_target` \| [^|]+ \| reject \|' \
    "@asm/@asm_target row must be marked reject"
if ! grep -E '\| `@asm`/`@asm_target` \|' "$MATRIX_DOC" | \
    grep -Fq 'verify_mir_c99_full_language_direct_builtin_capability_reject.sh'; then
    echo "error: @asm/@asm_target row must record direct builtin capability reject evidence" >&2
    exit 1
fi

echo "OK: MIR-C99 direct builtins fail closed with explicit capability diagnostics"
