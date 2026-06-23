#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$REPO_ROOT/tests/build/verify_run_programs_parallel_compiler_path"
fake_compiler="$tmp_dir/fake_uya.sh"
marker_file="$tmp_dir/fake_compiler_ran"
run_log="$tmp_dir/run.log"

rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$fake_compiler" <<EOF
#!/usr/bin/env bash
set -euo pipefail
touch "$marker_file"
echo "intentional fake compiler failure" >&2
exit 1
EOF
chmod +x "$fake_compiler"

(
    cd "$REPO_ROOT"
    UYA_COMPILER="./tests/build/verify_run_programs_parallel_compiler_path/fake_uya.sh" \
        ./tests/run_programs_parallel.sh --uya tests/error_const_div_zero.uya
) >"$run_log" 2>&1

if [[ ! -f "$marker_file" ]]; then
    echo "error: relative UYA_COMPILER was not executed from run_programs_parallel" >&2
    sed -n '1,160p' "$run_log" >&2 || true
    exit 1
fi

if grep -q 'No such file or directory' "$run_log"; then
    echo "error: relative UYA_COMPILER still resolved against compiler_work_dir" >&2
    sed -n '1,160p' "$run_log" >&2 || true
    exit 1
fi

if ! grep -q '预期编译失败' "$run_log"; then
    echo "error: runner did not treat fake compiler failure as expected failure" >&2
    sed -n '1,160p' "$run_log" >&2 || true
    exit 1
fi

echo "OK: run_programs_parallel resolves relative UYA_COMPILER before entering compiler_work_dir"
