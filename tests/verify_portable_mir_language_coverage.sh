#!/usr/bin/env bash
#
# Phase 9B coverage-matrix verifier.
#
# Contract:
#   - `docs/portable_mir_language_coverage.md` exists and is parseable.
#   - Every `AST_*` constant declared in `src/ast.uya` appears in the matrix
#     AST section with one of `done|partial|reject|missing`.
#   - Every covered AST/Core row also carries a MIR-C99 status with the same
#     vocabulary, so the matrix cannot claim Core/PortableMIR coverage as
#     MIR-C99 parity by omission.
#   - Every `CORE_STMT_KIND_*` / `CORE_EXPR_KIND_*` / `CORE_PLACE_KIND_*`
#     declared in `src/lower/core.uya` appears in the matrix's Core sections
#     with the same status vocabulary.
#   - The matrix must list at least one builtin and one runtime entry.
#
# The script is intentionally bash + awk to mirror the existing
# `verify_portable_mir_*.sh` style and to keep the CI surface flat.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AST_SRC="$REPO_ROOT/src/ast.uya"
CORE_SRC="$REPO_ROOT/src/lower/core.uya"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

for f in "$AST_SRC" "$CORE_SRC" "$MATRIX_DOC"; do
    if [[ ! -f "$f" ]]; then
        echo "error: missing $f" >&2
        exit 1
    fi
done

# Allowed status vocabulary.
ALLOWED_STATUS='done|partial|reject|missing'

# Collect ASTNodeType constants from src/ast.uya.
#   - Lines inside the enum ASTNodeType { ... } block.
#   - The enum ends at the first standalone `}` at column 0.
collect_ast_kinds() {
    awk '
        /^enum ASTNodeType[[:space:]]*\{/ { in_enum=1; next }
        in_enum && /^\}/ { in_enum=0 }
        in_enum {
            gsub(/[[:space:]]*\/\/.*$/, "")
            line=$0
            sub(/,$/, "", line)
            if (line ~ /^[[:space:]]*[A-Z][A-Z0-9_]+[[:space:]]*$/) {
                sub(/^[[:space:]]+/, "", line)
                print line
            }
        }
    ' "$AST_SRC" | sort -u
}

# Collect Core stmt/expr/place kind constants from src/lower/core.uya.
# Each constant is declared as `export const CORE_<KIND>_<NAME>: i32 = <N>;`.
collect_core_kinds() {
    local prefix="$1"
    # Match  declarations only, to avoid
    # substring hits like CORE_EXPR_KIND_I inside CORE_EXPR_KIND_INT_LITERAL.
    grep -oE "^export const (${prefix}[A-Z_]+):" "$CORE_SRC"         | sed -E "s/^export const (.+):$/\1/"         | sort -u
}

# Pull a kind-to-status map from the matrix.
# Strategy: parse every markdown table row of the form
#   `| \`KIND\` | STATUS | MIR_C99_STATUS | ...|`
# within the section whose header text mentions `KIND` and the desired prefix.
# To keep the parser small, we grep within the section text bounded by the
# nearest `## ` header. The function is invoked with the kind kind to look
# for and a section-anchor regex.

status_in_section() {
    local section_anchor="$1"
    local kind="$2"
    local column="$3"
    awk -v anchor="$section_anchor" -v k="$kind" -v status_column="$column" '
        $0 ~ "^## " {
            in_section=($0 ~ anchor)
        }
        in_section && $0 ~ "^\\| .*\\|" {
            # find column containing `kind`
            line=$0
            sub(/^\| /, "", line)
            n=split(line, cols, /[[:space:]]*\|[[:space:]]*/)
            for (i=1; i<=n; i++) {
                c=cols[i]
                gsub(/^`/, "", c)
                gsub(/`[[:space:]]*$/, "", c)
                if (c==k) {
                    found_status=cols[status_column]
                    gsub(/`/, "", found_status)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", found_status)
                    print found_status
                    exit
                }
            }
        }
    ' "$MATRIX_DOC"
}

failures=0

check_kind() {
    local section_anchor="$1"
    local kind="$2"
    local status
    local mir_c99_status
    status="$(status_in_section "$section_anchor" "$kind" 2 || true)"
    if [[ -z "$status" ]]; then
        echo "error: coverage matrix missing $kind in section '$section_anchor'" >&2
        failures=$((failures+1))
        return
    fi
    if ! [[ "$status" =~ ^($ALLOWED_STATUS)$ ]]; then
        echo "error: coverage matrix status for $kind is '$status', not in {$ALLOWED_STATUS}" >&2
        failures=$((failures+1))
    fi
    mir_c99_status="$(status_in_section "$section_anchor" "$kind" 3 || true)"
    if [[ -z "$mir_c99_status" ]]; then
        echo "error: coverage matrix missing MIR-C99 status for $kind in section '$section_anchor'" >&2
        failures=$((failures+1))
        return
    fi
    if ! [[ "$mir_c99_status" =~ ^($ALLOWED_STATUS)$ ]]; then
        echo "error: coverage matrix MIR-C99 status for $kind is '$mir_c99_status', not in {$ALLOWED_STATUS}" >&2
        failures=$((failures+1))
    fi
}

# AST section anchor matches `## 3. ASTNode 覆盖`.
AST_SECTION='^## 3\.[[:space:]]+ASTNode'
STMT_SECTION='^## 4\.[[:space:]]+CoreStmt'
EXPR_SECTION='^## 5\.[[:space:]]+CoreExpr'
PLACE_SECTION='^## 6\.[[:space:]]+CorePlace'

echo "==> checking ASTNode coverage"
while read -r kind; do
    [[ -z "$kind" ]] && continue
    check_kind "$AST_SECTION" "$kind"
done < <(collect_ast_kinds)

echo "==> checking CoreStmt coverage"
while read -r kind; do
    check_kind "$STMT_SECTION" "$kind"
done < <(collect_core_kinds "CORE_STMT_KIND_")

echo "==> checking CoreExpr coverage"
while read -r kind; do
    check_kind "$EXPR_SECTION" "$kind"
done < <(collect_core_kinds "CORE_EXPR_KIND_")

echo "==> checking CorePlace coverage"
while read -r kind; do
    check_kind "$PLACE_SECTION" "$kind"
done < <(collect_core_kinds "CORE_PLACE_KIND_")

# Builtin and runtime sections must exist (proves §8 / §9 were not silently dropped).
for anchor in '^## 8\.[[:space:]]+builtin' '^## 9\.[[:space:]]+标准库'; do
    if ! grep -Eq "$anchor" "$MATRIX_DOC"; then
        echo "error: coverage matrix section missing: $anchor" >&2
        failures=$((failures+1))
    fi
done

# MIR-C99 status section must stay present after removing legacy backend shards.
if ! grep -Eq 'MIR-C99 全局状态' "$MATRIX_DOC"; then
    echo "error: coverage matrix must include MIR-C99 global status" >&2
    failures=$((failures+1))
fi

if (( failures > 0 )); then
    echo "FAILED: $failures coverage gap(s)" >&2
    exit 1
fi

echo "OK: portable MIR language coverage matrix matches every AST/Core kind in src/ast.uya and src/lower/core.uya"
