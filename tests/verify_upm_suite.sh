#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BOOTSTRAP="${UYA_CMD_BOOTSTRAP_COMPILER:-$ROOT_DIR/bin/uya}"

if [ "${UYA_UPM_SUITE_PREBUILT:-0}" != "1" ] && [ ! -x "$ROOT_DIR/bin/cmd/upm" ]; then
    UYA_CMD_BOOTSTRAP_COMPILER="$CMD_BOOTSTRAP" make -C "$ROOT_DIR" cmd-upm >/dev/null
fi

SCRIPTS=(
    "$ROOT_DIR/tests/test_cmd_upm_direct.sh"
    "$ROOT_DIR/tests/verify_upm_legacy_mode.sh"
    "$ROOT_DIR/tests/verify_package_mode_legacy_fallback.sh"
    "$ROOT_DIR/tests/verify_upm_manifest_flat.sh"
    "$ROOT_DIR/tests/verify_upm_manifest_src.sh"
    "$ROOT_DIR/tests/verify_upm_manifest_discovery_file.sh"
    "$ROOT_DIR/tests/verify_package_mode_build_success.sh"
    "$ROOT_DIR/tests/verify_upm_manifest_missing.sh"
    "$ROOT_DIR/tests/verify_upm_min_version_ok.sh"
    "$ROOT_DIR/tests/verify_upm_min_version_fail.sh"
    "$ROOT_DIR/tests/verify_upm_missing_lockfile.sh"
    "$ROOT_DIR/tests/verify_upm_path_dep.sh"
    "$ROOT_DIR/tests/verify_upm_build_flags.sh"
    "$ROOT_DIR/tests/verify_upm_temp_cleanup.sh"
    "$ROOT_DIR/tests/verify_upm_graph_plan_no_staging.sh"
    "$ROOT_DIR/tests/verify_package_alias_source_roots.sh"
    "$ROOT_DIR/tests/verify_upm_path_invalid.sh"
    "$ROOT_DIR/tests/verify_upm_missing_dep_manifest.sh"
    "$ROOT_DIR/tests/verify_upm_alias_conflict.sh"
    "$ROOT_DIR/tests/verify_package_mode_alias_root_conflict.sh"
    "$ROOT_DIR/tests/verify_upm_transitive_conflict.sh"
    "$ROOT_DIR/tests/verify_upm_git_ref_conflict.sh"
    "$ROOT_DIR/tests/verify_upm_git_dep.sh"
    "$ROOT_DIR/tests/verify_upm_global_cache_git.sh"
    "$ROOT_DIR/tests/verify_upm_fetch_boundary.sh"
    "$ROOT_DIR/tests/verify_upm_proxy_backend.sh"
    "$ROOT_DIR/tests/verify_upm_registry_backend.sh"
    "$ROOT_DIR/tests/verify_upm_registry_versions.sh"
    "$ROOT_DIR/tests/verify_upm_workspace_backend.sh"
    "$ROOT_DIR/tests/verify_upm_publish_protocol.sh"
    "$ROOT_DIR/tests/verify_upm_diagnostics.sh"
    "$ROOT_DIR/tests/verify_upm_checksum_mismatch_git.sh"
    "$ROOT_DIR/tests/verify_upm_checksum_mismatch_path.sh"
    "$ROOT_DIR/tests/verify_upm_add_path.sh"
    "$ROOT_DIR/tests/verify_upm_layout_manifest.sh"
    "$ROOT_DIR/tests/verify_upm_add_git.sh"
    "$ROOT_DIR/tests/verify_upm_module_manifest_parse.sh"
    "$ROOT_DIR/tests/verify_upm_resolved_graph_hash.sh"
    "$ROOT_DIR/tests/verify_upm_module_identity_exact_version_path.sh"
    "$ROOT_DIR/tests/verify_upm_module_identity_version_mismatch.sh"
    "$ROOT_DIR/tests/verify_upm_remove.sh"
    "$ROOT_DIR/tests/verify_upm_add_remove_e2e.sh"
)

for script in "${SCRIPTS[@]}"; do
    UYA_UPM_SUITE_PREBUILT=1 bash "$script"
done

echo "verify_upm_suite: ok"
