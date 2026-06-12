#!/usr/bin/env bash
#
# MIR-C99 independent-backend boundary gate.
#
# Contract:
#   - MIR-C99 production source must live under src/codegen/mir_c99/.
#   - It must not import the legacy AST/LoweredProgram C99 production backend.
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
    done

    if [[ "$violations" -gt 0 ]]; then
        echo "FAILED: MIR-C99 independent boundary found $violations file(s) with forbidden legacy C99 imports" >&2
        return 1
    fi

    echo "OK: MIR-C99 independent boundary has no forbidden legacy C99 imports in $dir"
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

    echo "OK: MIR-C99 independent boundary self-test passed"
}

if [[ "$SELF_TEST" -eq 1 ]]; then
    run_self_test
else
    scan_source_dir "$SOURCE_DIR"
fi
