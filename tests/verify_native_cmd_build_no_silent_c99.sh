#!/usr/bin/env bash

# Phase 10：防止 --native 未接入时静默回落到 C99 并产出伪 native cmd/build。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-native-cmd-build-no-silent-c99.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_hosted_reject_check() {
    local compiler="$1"
    local label="$2"
    local out="$TMP_DIR/${label}.bin"
    local stdout="$TMP_DIR/${label}.out"
    local stderr="$TMP_DIR/${label}.err"

    set +e
    "$compiler" build "$REPO_ROOT/tests/test_native_main_only.uya" \
        -o "$out" --native --no-split-c --project-root "$REPO_ROOT/src/" \
        >"$stdout" 2>"$stderr"
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        echo "错误: $label --native 不应静默成功" >&2
        exit 1
    fi
    if [[ -e "$out" ]]; then
        echo "错误: $label --native 未接入时不应生成输出文件: $out" >&2
        exit 1
    fi
    if ! grep -q '后端类型: Native' "$stderr"; then
        echo "错误: $label --native 未进入 native BackendType" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -q 'native_hosted_preflight: status=0 verifier_error=0 c_import_objects=0 hosted_link_objects=0' "$stderr"; then
        echo "错误: $label --native 缺少 hosted PortableMIR preflight 证据" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' "$stderr"; then
        echo "错误: $label --native 缺少函数体 MIR lowering 缺口诊断" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -q 'build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集' "$stderr"; then
        echo "错误: $label --native 未排除 build-seed helper" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q '后端类型: C99' "$stderr"; then
        echo "错误: $label --native 被静默回落到了 C99" >&2
        exit 1
    fi
}

run_cmd_build_self_reject_check() {
    local compiler="$1"
    local label="$2"
    local out="$TMP_DIR/${label}.bin"
    local stdout="$TMP_DIR/${label}.out"
    local stderr="$TMP_DIR/${label}.err"

    set +e
    "$compiler" build "$REPO_ROOT/src/cmd/build/main.uya" \
        -o "$out" --native --nostdlib --no-split-c --project-root "$REPO_ROOT/src/" \
        >"$stdout" 2>"$stderr"
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        echo "错误: $label --native 当前不应伪生成 native cmd/build" >&2
        exit 1
    fi
    if [[ -e "$out" ]]; then
        echo "错误: $label --native 拒绝生成 cmd/build 时不应留下输出文件: $out" >&2
        exit 1
    fi
    grep -q '输入文件数量: 87' "$stderr"
    grep -q 'src/cmd/build/main.uya' "$stderr"
    grep -q '后端类型: Native' "$stderr"
    grep -Eq 'native_unsupported_call_expr: name=compile_files.*args=16' "$stderr"
    grep -Eq 'native_unsupported_fn_body: .*name=build_compiler_driver_run.*reason=unsupported_var_init.*stmt_index=32.*stmt_kind=var' "$stderr"
    grep -Eq 'native_unsupported_fn_shape: .*body_stmts=39' "$stderr"
    grep -Eq 'native backend.*LoweredProgram.*机器码' "$stderr"
    if grep -q '后端类型: C99' "$stderr"; then
        echo "错误: $label --native 生成 cmd/build 时被静默回落到了 C99" >&2
        exit 1
    fi
}

run_hosted_reject_check "$REPO_ROOT/bin/uya" "uya"
run_hosted_reject_check "$REPO_ROOT/bin/cmd/build" "cmd-build"
run_cmd_build_self_reject_check "$REPO_ROOT/bin/cmd/build" "cmd-build-self"

echo "verify_native_cmd_build_no_silent_c99: ok"
