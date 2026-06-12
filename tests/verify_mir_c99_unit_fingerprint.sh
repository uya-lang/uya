#!/usr/bin/env bash
#
# MIR-C99 unit vector and fingerprint contract verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$PLAN_FILE"; then
        echo "error: MIR-C99 unit fingerprint missing evidence: $description" >&2
        exit 1
    fi
}

if [[ ! -f "$PLAN_FILE" ]]; then
    echo "error: missing MIR-C99 plan source: $PLAN_FILE" >&2
    exit 1
fi

require_pattern 'units:[[:space:]]*SemanticVector' "MirC99Plan stores units in a dynamic vector"
require_pattern 'semantic_vector_init\(&plan\.units,[[:space:]]*@size_of\(MirC99Unit\)\)' "unit vector initialization"
require_pattern 'fingerprint:[[:space:]]*u64' "MirC99Unit fingerprint field"
require_pattern 'export fn mir_c99_unit_compute_fingerprint' "fingerprint computation API"
require_pattern 'export fn mir_c99_unit_refresh_fingerprint' "fingerprint refresh API"
require_pattern 'mir_c99_unit_fingerprint_refs\(h,[[:space:]]*&unit\.includes\)' "include refs participate in fingerprint"
require_pattern 'mir_c99_unit_fingerprint_refs\(h,[[:space:]]*&unit\.typedefs\)' "typedef refs participate in fingerprint"
require_pattern 'mir_c99_unit_fingerprint_refs\(h,[[:space:]]*&unit\.prototypes\)' "prototype refs participate in fingerprint"
require_pattern 'mir_c99_unit_fingerprint_refs\(h,[[:space:]]*&unit\.globals\)' "global refs participate in fingerprint"
require_pattern 'mir_c99_unit_fingerprint_refs\(h,[[:space:]]*&unit\.functions\)' "function refs participate in fingerprint"
require_pattern 'return mir_c99_unit_refresh_fingerprint\(unit\)' "unit append refreshes fingerprint"
require_pattern 'mir_c99_unit_refresh_fingerprint\(stored\)' "new units get an initial fingerprint"

compute_body="$(awk '
    /^export fn mir_c99_unit_compute_fingerprint/ { in_fn=1 }
    in_fn { print }
    in_fn && /^}/ { exit }
' "$PLAN_FILE")"

if printf '%s\n' "$compute_body" | grep -Eq 'unit\.(source_file_id|name_id)'; then
    echo "error: MIR-C99 unit fingerprint must ignore path/name-derived fields" >&2
    exit 1
fi

"$REPO_ROOT/bin/uya" check "$PLAN_FILE" >/dev/null

echo "OK: MIR-C99 unit vector and fingerprint contract verified"
