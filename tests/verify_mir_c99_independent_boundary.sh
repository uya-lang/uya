#!/usr/bin/env bash
#
# MIR-C99 independent-backend boundary gate.
#
# Contract:
#   - MIR-C99 production source must live under src/codegen/mir_c99/.
#   - It must not import the legacy AST/LoweredProgram C99 production backend.
#   - It must not call or embed the legacy C99 production emitter surface.
#   - It must not read pre-MIR body/typing structures as a semantic side path.
#   - The legacy C99 backend can remain as oracle/fallback/release path outside
#     this directory, but not as MIR-C99's internal implementation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="${MIR_C99_SOURCE_DIR:-$REPO_ROOT/src/codegen/mir_c99}"
SELF_TEST=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --self-test)
            SELF_TEST=1
            shift
            ;;
        --source-dir)
            if [[ $# -lt 2 ]]; then
                echo "error: --source-dir requires a path" >&2
                exit 1
            fi
            SOURCE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: bash tests/verify_mir_c99_independent_boundary.sh [--self-test] [--source-dir DIR]" >&2
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

FORBIDDEN_USE_RE='^[[:space:]]*use[[:space:]]+codegen\.c99(_build)?([.;[:space:]]|$)'
FORBIDDEN_LEGACY_SYMBOL_RE='(^|[^A-Za-z0-9_])(c99_codegen_generate|C99CodeGenerator|C99Plan)([^A-Za-z0-9_]|$)'
FORBIDDEN_PRE_MIR_BODY_RE='(^|[^A-Za-z0-9_])(ASTNode|LoweredProgram|CoreBody|TypedProgram|TypeChecker)([^A-Za-z0-9_]|$)'

scan_source_dir() {
    local dir="$1"
    local violations=0
    local file
    local matches
    local -a files=()

    if [[ ! -d "$dir" ]]; then
        echo "OK: MIR-C99 source directory does not exist yet: $dir"
        return 0
    fi

    mapfile -t files < <(find "$dir" -type f -name '*.uya' | sort)
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "OK: MIR-C99 source directory has no .uya files yet: $dir"
        return 0
    fi

    for file in "${files[@]}"; do
        matches="$(grep -En "$FORBIDDEN_USE_RE" "$file" || true)"
        if [[ -n "$matches" ]]; then
            while IFS= read -r line; do
                echo "error: MIR-C99 backend must not import legacy C99 backend: $line" >&2
            done <<<"$matches"
            violations=$((violations + 1))
        fi
        matches="$(grep -En "$FORBIDDEN_LEGACY_SYMBOL_RE" "$file" || true)"
        if [[ -n "$matches" ]]; then
            while IFS= read -r line; do
                echo "error: MIR-C99 backend must not use legacy C99 production emitter surface: $line" >&2
            done <<<"$matches"
            violations=$((violations + 1))
        fi
        matches="$(grep -En "$FORBIDDEN_PRE_MIR_BODY_RE" "$file" || true)"
        if [[ -n "$matches" ]]; then
            while IFS= read -r line; do
                echo "error: MIR-C99 backend must not read pre-MIR body or typing structures: $line" >&2
            done <<<"$matches"
            violations=$((violations + 1))
        fi
    done

    if [[ "$violations" -gt 0 ]]; then
        echo "FAILED: MIR-C99 independent boundary found $violations forbidden legacy C99 reference group(s)" >&2
        return 1
    fi

    echo "OK: MIR-C99 independent boundary has no forbidden legacy C99 imports, emitter references, or pre-MIR body reads in $dir"
}

run_self_test() {
    local tmp_dir
    local good_dir
    local bad_dir
    local bad_out
    tmp_dir="$(mktemp -d /tmp/uya-mir-c99-boundary.XXXXXX)"
    trap 'rm -rf "$tmp_dir"' RETURN
    good_dir="$tmp_dir/good"
    bad_dir="$tmp_dir/bad"
    bad_out="$tmp_dir/bad.out"
    mkdir -p "$good_dir" "$bad_dir"

    cat >"$good_dir/driver.uya" <<'EOF'
use lower.mir_backend;
use lower.mir;

export fn mir_c99_boundary_good() i32 {
    return 0;
}
EOF

    cat >"$bad_dir/driver.uya" <<'EOF'
use lower.mir_backend;
use codegen.c99;
use codegen.c99_build;

export fn mir_c99_boundary_bad() i32 {
    const gen: C99CodeGenerator = C99CodeGenerator{};
    const plan: C99Plan = C99Plan{};
    const body: &CoreBody = null;
    const program: &LoweredProgram = null;
    const ast: &ASTNode = null;
    const typed: &TypedProgram = null;
    const checker: &TypeChecker = null;
    c99_codegen_generate(&gen, &plan);
    return 1;
}
EOF

    scan_source_dir "$good_dir" >/dev/null
    if scan_source_dir "$bad_dir" >"$bad_out" 2>&1; then
        echo "error: self-test expected forbidden legacy C99 imports to fail" >&2
        cat "$bad_out" >&2
        return 1
    fi
    if ! grep -q 'use codegen.c99' "$bad_out" || ! grep -q 'use codegen.c99_build' "$bad_out"; then
        echo "error: self-test did not report both forbidden imports" >&2
        cat "$bad_out" >&2
        return 1
    fi
    for symbol in c99_codegen_generate C99CodeGenerator C99Plan; do
        if ! grep -q "$symbol" "$bad_out"; then
            echo "error: self-test did not report forbidden legacy symbol $symbol" >&2
            cat "$bad_out" >&2
            return 1
        fi
    done
    for symbol in ASTNode LoweredProgram CoreBody TypedProgram TypeChecker; do
        if ! grep -q "$symbol" "$bad_out"; then
            echo "error: self-test did not report forbidden pre-MIR symbol $symbol" >&2
            cat "$bad_out" >&2
            return 1
        fi
    done

    echo "OK: MIR-C99 independent boundary self-test passed"
}

if [[ "$SELF_TEST" -eq 1 ]]; then
    run_self_test
else
    scan_source_dir "$SOURCE_DIR"
fi
