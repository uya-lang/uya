#!/usr/bin/env bash
#
# Current-source MIR-C99 reject gate for @embed/@embed_dir and varargs builtins.

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
        echo "error: MIR-C99 embed/varargs capability reject missing evidence: $description" >&2
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
    ASTNodeType.AST_EMBED \
    ASTNodeType.AST_EMBED_DIR \
    ASTNodeType.AST_VA_START \
    ASTNodeType.AST_VA_END \
    ASTNodeType.AST_VA_ARG \
    ASTNodeType.AST_VA_COPY \
    embed_requires_compile_time_embed_capability \
    embed_dir_requires_compile_time_embed_capability \
    va_start_requires_c_variadic_capability \
    va_end_requires_c_variadic_capability \
    va_arg_requires_c_variadic_capability \
    va_copy_requires_c_variadic_capability; do
    require_pattern "$BUILD_DRIVER" "$symbol" "build driver symbol $symbol"
done

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-embed-varargs.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

printf 'basic-bytes\n' >"$tmp_dir/basic.bin"
mkdir -p "$tmp_dir/assets"
printf 'asset-file\n' >"$tmp_dir/assets/one.txt"

embed_case="$tmp_dir/embed_case.uya"
embed_dir_case="$tmp_dir/embed_dir_case.uya"
va_start_case="$tmp_dir/va_start_case.uya"
va_end_case="$tmp_dir/va_end_case.uya"
va_arg_case="$tmp_dir/va_arg_case.uya"
va_copy_case="$tmp_dir/va_copy_case.uya"

cat >"$embed_case" <<'UYA'
export fn main() i32 {
    const bytes: &[const byte] = @embed("basic.bin");
    const _same: &[const byte] = bytes;
    return 0;
}
UYA

cat >"$embed_dir_case" <<'UYA'
export fn main() i32 {
    const entries: &[const EmbedDirEntry] = @embed_dir("assets");
    const _same: &[const EmbedDirEntry] = entries;
    return 0;
}
UYA

cat >"$va_start_case" <<'UYA'
fn touch_start(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);
    return 0;
}

export fn main() i32 {
    return touch_start("ok");
}
UYA

cat >"$va_end_case" <<'UYA'
fn touch_end(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_end(&ap);
    return 0;
}

export fn main() i32 {
    return touch_end("ok");
}
UYA

cat >"$va_arg_case" <<'UYA'
fn touch_arg(ap: va_list) i32 {
    return @va_arg(ap, i32);
}

export fn main() i32 {
    var ap: va_list = va_list{};
    return touch_arg(ap);
}
UYA

cat >"$va_copy_case" <<'UYA'
fn touch_copy(ap: va_list) i32 {
    var dst: va_list = va_list{};
    @va_copy(&dst, ap);
    return 0;
}

export fn main() i32 {
    var ap: va_list = va_list{};
    return touch_copy(ap);
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
        grep -Fq 'verify_mir_c99_full_language_embed_varargs_capability_reject.sh'; then
        echo "error: $kind must record embed/varargs capability reject evidence" >&2
        exit 1
    fi
}

run_expect_diag "embed" "$embed_case" \
    "embed_capability" "AST_EMBED" \
    "embed_requires_compile_time_embed_capability"
run_expect_diag "embed_dir" "$embed_dir_case" \
    "embed_dir_capability" "AST_EMBED_DIR" \
    "embed_dir_requires_compile_time_embed_capability"
run_expect_diag "va_start" "$va_start_case" \
    "va_start_capability" "AST_VA_START" \
    "va_start_requires_c_variadic_capability"
run_expect_diag "va_end" "$va_end_case" \
    "va_end_capability" "AST_VA_END" \
    "va_end_requires_c_variadic_capability"
run_expect_diag "va_arg" "$va_arg_case" \
    "va_arg_capability" "AST_VA_ARG" \
    "va_arg_requires_c_variadic_capability"
run_expect_diag "va_copy" "$va_copy_case" \
    "va_copy_capability" "AST_VA_COPY" \
    "va_copy_requires_c_variadic_capability"

for kind in \
    AST_EMBED \
    AST_EMBED_DIR \
    AST_VA_START \
    AST_VA_END \
    AST_VA_ARG \
    AST_VA_COPY; do
    require_matrix_status "$kind"
    require_matrix_evidence "$kind"
done

require_pattern "$MATRIX_DOC" '\| `@embed`/`@embed_dir` \| [^|]+ \| reject \|' \
    "@embed/@embed_dir row must be marked reject"
if ! grep -E '\| `@embed`/`@embed_dir` \|' "$MATRIX_DOC" | \
    grep -Fq 'verify_mir_c99_full_language_embed_varargs_capability_reject.sh'; then
    echo "error: @embed/@embed_dir row must record embed capability reject evidence" >&2
    exit 1
fi

require_pattern "$MATRIX_DOC" '\| `@va_start`/`@va_end`/`@va_arg`/`@va_copy` \| [^|]+ \| reject \|' \
    "@va_* row must be marked reject"
if ! grep -E '\| `@va_start`/`@va_end`/`@va_arg`/`@va_copy` \|' "$MATRIX_DOC" | \
    grep -Fq 'verify_mir_c99_full_language_embed_varargs_capability_reject.sh'; then
    echo "error: @va_* row must record varargs capability reject evidence" >&2
    exit 1
fi

echo "OK: MIR-C99 embed/varargs builtins fail closed with explicit capability diagnostics"
