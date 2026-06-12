#!/usr/bin/env bash
#
# MIR-C99 split-C build manifest verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
MANIFEST_FILE="$REPO_ROOT/src/codegen/mir_c99/build_manifest.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 build manifest plan missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$PLAN_FILE" "$MANIFEST_FILE" "$DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

require_pattern "$MANIFEST_FILE" 'export struct MirC99BuildManifestEntry' \
    "manifest entry row"
require_pattern "$MANIFEST_FILE" 'export struct MirC99BuildManifestPlan' \
    "manifest plan struct"
require_pattern "$MANIFEST_FILE" 'entries:[[:space:]]*SemanticVector' \
    "manifest stores entries dynamically"
require_pattern "$MANIFEST_FILE" 'semantic_vector_init\(&manifest\.entries,[[:space:]]*@size_of\(MirC99BuildManifestEntry\)\)' \
    "manifest entry vector initialized"
require_pattern "$MANIFEST_FILE" 'MIR_C99_BUILD_MANIFEST_ENTRY_SOURCE_C' \
    "source C entry kind"
require_pattern "$MANIFEST_FILE" 'MIR_C99_BUILD_MANIFEST_ENTRY_HEADER' \
    "header entry kind"
require_pattern "$MANIFEST_FILE" 'MIR_C99_BUILD_MANIFEST_ENTRY_OBJECT' \
    "object entry kind"
require_pattern "$MANIFEST_FILE" 'MIR_C99_BUILD_MANIFEST_ENTRY_DEP' \
    "dependency entry kind"
require_pattern "$MANIFEST_FILE" 'export fn mir_c99_build_manifest_plan_build' \
    "manifest build API"
require_pattern "$MANIFEST_FILE" 'while i < plan\.units\.count' \
    "all units are scanned"
require_pattern "$MANIFEST_FILE" 'mir_c99_build_manifest_append_unit_files\(manifest,[^)]*unit\)' \
    "unit source/header/object records"
require_pattern "$MANIFEST_FILE" 'mir_c99_build_manifest_append_unit_deps\(manifest,[^)]*unit\)' \
    "unit dependency records"
require_pattern "$DRIVER_FILE" 'use codegen\.mir_c99\.build_manifest' \
    "driver imports build manifest module"
require_pattern "$DRIVER_FILE" 'MirC99BuildManifestPlan' \
    "driver result exposes build manifest summary"
require_pattern "$DRIVER_FILE" 'mir_c99_build_manifest_plan_build\(plan,[[:space:]]*build_manifest\)' \
    "driver builds manifest after unit planning"

if grep -Eq 'c99_write_split_makefile|split_makefile|codegen\.c99|C99CodeGenerator' "$MANIFEST_FILE"; then
    echo "error: MIR-C99 build manifest must not call legacy C99 split writer" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_build_manifest_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' "$PLAN_FILE" "$MANIFEST_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 split-C build manifest plan verified"
