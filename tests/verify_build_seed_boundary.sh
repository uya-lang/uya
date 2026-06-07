#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-build-seed-boundary.XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

BUILD_SRC="$ROOT_DIR/src/build_compiler_driver.uya"
BUILD_ENTRY="$ROOT_DIR/src/cmd/build/main.uya"
CMD_BUILD="$TMP_DIR/cmd-build"
GEN_C="$TMP_DIR/cmd-build.c"

if [[ ! -x "$ROOT_DIR/bin/uya" ]]; then
    echo "错误: 缺少可执行编译器 bin/uya，请先运行 make uya" >&2
    exit 1
fi

grep -q 'use build_compiler_driver;' "$BUILD_ENTRY"
if grep -q 'use compiler_driver;' "$BUILD_ENTRY"; then
    echo "错误: cmd/build 入口仍导入完整 compiler_driver" >&2
    exit 1
fi
grep -q 'use checker_build;' "$BUILD_SRC"
grep -q 'use codegen.c99_build;' "$BUILD_SRC"
if grep -q 'use checker;' "$BUILD_SRC" || grep -q 'use codegen.c99;' "$BUILD_SRC"; then
    echo "错误: build seed driver 仍导入完整 checker/codegen.c99" >&2
    exit 1
fi

SOURCE_FORBIDDEN=(
    'use microapp;'
    'use exec;'
    'use fmt;'
    'use kernel\.'
    'cmd\.upm'
    'BackendType\.BACKEND_EXEC'
    'exec_backend_'
    'exec_build_program'
    'exec_run_program'
    'UPMPackageBuildPlan'
    'upm_prepare_build_plan'
    'fmt_main'
    'uyafmt_main'
    'pack_microapp_pobj_to_uapp'
    'write_microapp_payload_obj'
    'inspect_microapp_'
    'verify_microapp_'
    'MicroAppTargetProfile'
    'POBJ_'
    'UAPP'
    'MACHO_'
    'ELF64_'
    'payload_obj'
    'microapp_payload'
    'kernel_payload'
    'kernel_image'
)

for pattern in "${SOURCE_FORBIDDEN[@]}"; do
    if grep -Eq "$pattern" "$BUILD_SRC"; then
        echo "错误: build seed source 含有非 build 依赖符号: $pattern" >&2
        exit 1
    fi
done

UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" build "$BUILD_ENTRY" -o "$CMD_BUILD" --no-split-c --project-root "$ROOT_DIR/src/" >"$TMP_DIR/build.out" 2>"$TMP_DIR/build.err"
test -x "$CMD_BUILD"

if grep -Eq 'src/(exec|microapp|fmt|kernel)|src/cmd/upm|cmd/upm|kernel\.(image|payload)' "$TMP_DIR/build.err"; then
    echo "错误: cmd/build 编译依赖列表含有非 build 子系统" >&2
    grep -En 'src/(exec|microapp|fmt|kernel)|src/cmd/upm|cmd/upm|kernel\.(image|payload)' "$TMP_DIR/build.err" >&2
    exit 1
fi
if grep -Eq 'src/checker/|src/codegen/c99/' "$TMP_DIR/build.err"; then
    echo "错误: cmd/build 编译依赖列表仍含完整 checker/codegen.c99" >&2
    grep -En 'src/checker/|src/codegen/c99/' "$TMP_DIR/build.err" >&2
    exit 1
fi

dep_count="$(awk '/输入文件数量:/ { print $2; exit }' "$TMP_DIR/build.err")"
if [[ -z "$dep_count" || "$dep_count" -ge 86 ]]; then
    echo "错误: build seed 依赖数未低于旧基线 86: ${dep_count:-unknown}" >&2
    exit 1
fi

UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" build "$BUILD_ENTRY" -o "$GEN_C" --c99 --no-split-c --project-root "$ROOT_DIR/src/" >"$TMP_DIR/c99.out" 2>"$TMP_DIR/c99.err"
test -s "$GEN_C"
gen_c_bytes="$(wc -c <"$GEN_C")"

C_FORBIDDEN=(
    'exec_backend_'
    'exec_build_program'
    'exec_run_program'
    'g_exec_'
    'UPMPackageBuildPlan'
    'upm_prepare_build_plan'
    'upm_build_plan'
    'fmt_main'
    'uyafmt_main'
    'pack_microapp_pobj_to_uapp'
    'write_microapp_payload_obj'
    'inspect_microapp_'
    'verify_microapp_'
    'MicroAppTargetProfile'
    'POBJ_'
    'UAPP'
    'MACHO_'
    'ELF64_'
    'payload_obj'
    'microapp_payload'
    'kernel_payload'
    'kernel_image'
    'rv32_scan'
    'std\.microapp'
    'microapp bridge dispatch'
    'UYA_MICROAPP'
    'uya_microapp_bridge'
    'MICROAPP_DEBUG_MMU'
    '/lib/std/microapp'
    'lib/std/microapp'
    'E400[0-9]: microapp'
    'microapp 模式'
)

for pattern in "${C_FORBIDDEN[@]}"; do
    if grep -Eq "$pattern" "$GEN_C"; then
        echo "错误: build seed C 输出含有非 build 子系统符号: $pattern" >&2
        exit 1
    fi
done

set +e
UYA_ROOT="$ROOT_DIR" "$CMD_BUILD" --vm "$ROOT_DIR/tests/test_errno.uya" -o "$TMP_DIR/should-not-build" >"$TMP_DIR/vm.out" 2>"$TMP_DIR/vm.err"
vm_status=$?
set -e
if [[ "$vm_status" -eq 0 ]] || ! grep -q '不包含 exec backend' "$TMP_DIR/vm.err"; then
    echo "错误: cmd/build seed 未明确拒绝 exec/vm 后端" >&2
    cat "$TMP_DIR/vm.err" >&2
    exit 1
fi

set +e
UYA_ROOT="$ROOT_DIR" "$CMD_BUILD" --app microapp "$ROOT_DIR/tests/test_errno.uya" -o "$TMP_DIR/should-not-build" >"$TMP_DIR/microapp.out" 2>"$TMP_DIR/microapp.err"
microapp_status=$?
set -e
if [[ "$microapp_status" -eq 0 ]] || ! grep -q '不包含 microapp image/payload' "$TMP_DIR/microapp.err"; then
    echo "错误: cmd/build seed 未明确拒绝 microapp image/payload 路径" >&2
    cat "$TMP_DIR/microapp.err" >&2
    exit 1
fi

set +e
UYA_ROOT="$ROOT_DIR" "$CMD_BUILD" "$ROOT_DIR/tests/test_errno.uya" --manifest-path "$TMP_DIR/uya.toml" -o "$TMP_DIR/should-not-build" >"$TMP_DIR/upm.out" 2>"$TMP_DIR/upm.err"
upm_status=$?
set -e
if [[ "$upm_status" -eq 0 ]] || ! grep -q '不支持 --manifest-path' "$TMP_DIR/upm.err"; then
    echo "错误: cmd/build seed 未明确拒绝 upm manifest plan 路径" >&2
    cat "$TMP_DIR/upm.err" >&2
    exit 1
fi

UYA_ROOT="$ROOT_DIR" "$CMD_BUILD" "$ROOT_DIR/tests/test_errno.uya" -o "$TMP_DIR/errno" --no-split-c >"$TMP_DIR/errno_build.out" 2>"$TMP_DIR/errno_build.err"
"$TMP_DIR/errno" >"$TMP_DIR/errno.out" 2>"$TMP_DIR/errno.err"
grep -q 'libc.errno' "$TMP_DIR/errno.out"

echo "verify_build_seed_boundary: ok (deps=$dep_count c_bytes=$gen_c_bytes)"
