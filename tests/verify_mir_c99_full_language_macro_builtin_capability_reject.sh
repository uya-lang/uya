#!/usr/bin/env bash
#
# Current-source MIR-C99 reject gate for macro builtins that still depend on
# compile-time macro helpers.

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
        echo "error: MIR-C99 macro builtin capability reject missing evidence: $description" >&2
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
    ASTNodeType.AST_MACRO_DECL \
    ASTNodeType.AST_MC_EVAL \
    ASTNodeType.AST_MC_CODE \
    ASTNodeType.AST_MC_AST \
    ASTNodeType.AST_MC_ERROR \
    ASTNodeType.AST_MC_INTERP \
    ASTNodeType.AST_MC_TYPE \
    ASTNodeType.AST_MC_SOURCE \
    mc_eval_requires_compile_time_macro_capability \
    mc_code_requires_compile_time_macro_capability \
    mc_ast_requires_compile_time_macro_capability \
    mc_error_requires_compile_time_macro_capability \
    mc_interp_requires_compile_time_macro_capability \
    mc_type_requires_compile_time_macro_capability \
    mc_source_requires_compile_time_macro_capability; do
    require_pattern "$BUILD_DRIVER" "$symbol" "build driver symbol $symbol"
done

require_pattern "$BUILD_DRIVER" \
    'node\.type == ASTNodeType\.AST_MACRO_DECL' \
    "build driver must traverse macro declarations"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-macro-builtins.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

mc_eval_case="$tmp_dir/mc_eval_case.uya"
mc_code_case="$tmp_dir/mc_code_case.uya"
mc_ast_case="$tmp_dir/mc_ast_case.uya"
mc_error_case="$tmp_dir/mc_error_case.uya"
mc_interp_case="$tmp_dir/mc_interp_case.uya"
mc_type_case="$tmp_dir/mc_type_case.uya"
mc_source_case="$tmp_dir/mc_source_case.uya"

cat >"$mc_eval_case" <<'UYA'
mc computed_const() expr {
    @mc_eval(10 + 20);
}

export fn main() i32 {
    return computed_const();
}
UYA

cat >"$mc_code_case" <<'UYA'
mc emit_const() expr {
    @mc_code(@mc_ast(42));
}

export fn main() i32 {
    return emit_const();
}
UYA

cat >"$mc_ast_case" <<'UYA'
mc keep_ast_only() expr {
    const ast = @mc_ast(42);
    @mc_error("stop");
}

export fn main() i32 {
    return 0;
}
UYA

cat >"$mc_error_case" <<'UYA'
mc fail_now() expr {
    @mc_error("stop");
}

export fn main() i32 {
    return 0;
}
UYA

cat >"$mc_interp_case" <<'UYA'
mc add_one(x: expr) expr {
    @mc_code(@mc_ast(${x} + 1));
}

export fn main() i32 {
    return add_one(41);
}
UYA

cat >"$mc_type_case" <<'UYA'
use std.macro_typeinfo.TypeInfo;

mc get_size(T: type) expr {
    const info: TypeInfo = @mc_type(T);
    info.size;
}

export fn main() i32 {
    return get_size(i32);
}
UYA

cat >"$mc_source_case" <<'UYA'
extern "libc" fn strcmp(s1: *i8, s2: *i8) i32;

mc to_string(e: expr) expr {
    @mc_source(e);
}

export fn main() i32 {
    const s: *i8 = to_string(1 + 2);
    if strcmp(s, "1 + 2" as *i8) == 0 {
        return 1;
    }
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
        grep -Fq 'verify_mir_c99_full_language_macro_builtin_capability_reject.sh'; then
        echo "error: $kind must record macro builtin capability reject evidence" >&2
        exit 1
    fi
}

run_expect_diag "mc_eval" "$mc_eval_case" \
    "mc_eval_capability" "AST_MC_EVAL" \
    "mc_eval_requires_compile_time_macro_capability"
run_expect_diag "mc_code" "$mc_code_case" \
    "mc_code_capability" "AST_MC_CODE" \
    "mc_code_requires_compile_time_macro_capability"
run_expect_diag "mc_ast" "$mc_ast_case" \
    "mc_ast_capability" "AST_MC_AST" \
    "mc_ast_requires_compile_time_macro_capability"
run_expect_diag "mc_error" "$mc_error_case" \
    "mc_error_capability" "AST_MC_ERROR" \
    "mc_error_requires_compile_time_macro_capability"
run_expect_diag "mc_interp" "$mc_interp_case" \
    "mc_interp_capability" "AST_MC_INTERP" \
    "mc_interp_requires_compile_time_macro_capability"
run_expect_diag "mc_type" "$mc_type_case" \
    "mc_type_capability" "AST_MC_TYPE" \
    "mc_type_requires_compile_time_macro_capability"
run_expect_diag "mc_source" "$mc_source_case" \
    "mc_source_capability" "AST_MC_SOURCE" \
    "mc_source_requires_compile_time_macro_capability"

for kind in \
    AST_MC_EVAL \
    AST_MC_CODE \
    AST_MC_AST \
    AST_MC_ERROR \
    AST_MC_INTERP \
    AST_MC_TYPE \
    AST_MC_SOURCE; do
    require_matrix_status "$kind"
    require_matrix_evidence "$kind"
done

require_pattern "$MATRIX_DOC" '\| `@mc_eval`/`@mc_code`/`@mc_ast`/`@mc_error`/`@mc_interp`/`@mc_type`/`@mc_source` \| [^|]+ \| reject \|' \
    "@mc_* builtin row must be marked reject"
if ! grep -E '\| `@mc_eval`/`@mc_code`/`@mc_ast`/`@mc_error`/`@mc_interp`/`@mc_type`/`@mc_source` \|' "$MATRIX_DOC" | \
    grep -Fq 'verify_mir_c99_full_language_macro_builtin_capability_reject.sh'; then
    echo "error: @mc_* builtin row must record macro builtin capability reject evidence" >&2
    exit 1
fi

echo "OK: MIR-C99 macro builtins fail closed with explicit capability diagnostics"
