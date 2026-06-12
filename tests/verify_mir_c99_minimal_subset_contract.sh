#!/usr/bin/env bash
#
# MIR-C99 minimal-C99-subset contract verifier.
#
# Contract:
#   - docs/mir_c99_backend.md must pin the low-level C99 subset.
#   - MIR-C99 source must not emit C11/GNU/non-portable C constructs unless the
#     contract is explicitly revised first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="${MIR_C99_SOURCE_DIR:-$REPO_ROOT/src/codegen/mir_c99}"
CONTRACT_DOC="$REPO_ROOT/docs/mir_c99_backend.md"
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
            echo "用法: bash tests/verify_mir_c99_minimal_subset_contract.sh [--self-test] [--source-dir DIR]" >&2
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

require_contract_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$CONTRACT_DOC"; then
        echo "error: MIR-C99 minimal subset contract missing: $description" >&2
        exit 1
    fi
}

verify_contract_doc() {
    if [[ ! -f "$CONTRACT_DOC" ]]; then
        echo "error: missing MIR-C99 backend contract doc: $CONTRACT_DOC" >&2
        exit 1
    fi

    require_contract_pattern '^## 8\. Minimal C99 子集' "Minimal C99 section"
    require_contract_pattern 'block label.*`goto`' "label/goto low-level CFG subset"
    require_contract_pattern 'scalar local.*load/store' "value/place low-level subset"
    require_contract_pattern 'C11 `_Static_assert`.*`_Generic`.*`_Atomic`' "C11 forbidden list"
    require_contract_pattern 'GCC/Clang extension' "compiler extension forbidden list"
    require_contract_pattern 'computed goto' "computed goto forbidden list"
    require_contract_pattern '可读源码还原目标' "source reconstruction forbidden target"
}

FORBIDDEN_C_RE='(_Static_assert|_Generic|_Atomic|thread_local|__typeof__|typeof[[:space:]]*\(|__attribute__[[:space:]]*\(|__builtin_[A-Za-z0-9_]+|__asm__|goto[[:space:]]*\*|&&[A-Za-z_][A-Za-z0-9_]*|\(\{)'

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
        matches="$(grep -En "$FORBIDDEN_C_RE" "$file" || true)"
        if [[ -n "$matches" ]]; then
            while IFS= read -r line; do
                echo "error: MIR-C99 minimal C99 subset forbids this emitted/source construct: $line" >&2
            done <<<"$matches"
            violations=$((violations + 1))
        fi
    done

    if [[ "$violations" -gt 0 ]]; then
        echo "FAILED: MIR-C99 minimal C99 subset found $violations file(s) with forbidden constructs" >&2
        return 1
    fi

    echo "OK: MIR-C99 source stays within the minimal C99 subset in $dir"
}

run_self_test() {
    local tmp_dir
    local good_dir
    local bad_dir
    local bad_out
    tmp_dir="$(mktemp -d /tmp/uya-mir-c99-subset.XXXXXX)"
    trap 'rm -rf "$tmp_dir"' RETURN
    good_dir="$tmp_dir/good"
    bad_dir="$tmp_dir/bad"
    bad_out="$tmp_dir/bad.out"
    mkdir -p "$good_dir" "$bad_dir"

    cat >"$good_dir/emitter.uya" <<'EOF'
export fn emit_good_c_subset() void {
    // Low-level C99 forms: label, goto, if/goto, return, scalar temp.
}
EOF

    cat >"$bad_dir/emitter.uya" <<'EOF'
export fn emit_bad_c_subset() void {
    const c11_static_assert = "_Static_assert(sizeof(int) == 4, \"bad\")";
    const generic_expr = "_Generic(x, int: 1)";
    const gnu_attr = "__attribute__((unused))";
    const builtin = "__builtin_expect(x, 1)";
    const computed = "goto *target";
    const label_address = "&&bb0";
    const stmt_expr = "({ int x = 1; x; })";
}
EOF

    scan_source_dir "$good_dir" >/dev/null
    if scan_source_dir "$bad_dir" >"$bad_out" 2>&1; then
        echo "error: self-test expected forbidden C subset constructs to fail" >&2
        cat "$bad_out" >&2
        return 1
    fi
    for symbol in _Static_assert _Generic __attribute__ __builtin_expect 'goto \*target' '&&bb0'; do
        if ! grep -q "$symbol" "$bad_out"; then
            echo "error: self-test did not report forbidden construct $symbol" >&2
            cat "$bad_out" >&2
            return 1
        fi
    done

    echo "OK: MIR-C99 minimal subset self-test passed"
}

verify_contract_doc
if [[ "$SELF_TEST" -eq 1 ]]; then
    run_self_test
else
    scan_source_dir "$SOURCE_DIR"
fi
