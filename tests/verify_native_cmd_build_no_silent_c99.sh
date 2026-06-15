#!/usr/bin/env bash

# Native build-seed boundary: --native must not silently fall back to C99 or
# leave a fake output while hosted CoreBody/PortableMIR coverage is incomplete.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-native-cmd-build-no-silent-c99.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 native no-silent-C99 证据: $description" >&2
        cat "$file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "错误: native no-silent-C99 边界回退: $description" >&2
        cat "$file" >&2
        exit 1
    fi
}

run_native_reject_check() {
    local compiler="$1"
    local label="$2"
    local input="$3"
    local out="$TMP_DIR/${label}.bin"
    local stdout="$TMP_DIR/${label}.out"
    local stderr="$TMP_DIR/${label}.err"

    set +e
    UYA_ROOT="$REPO_ROOT" "$compiler" build "$input" \
        -o "$out" --native --no-split-c --project-root "$REPO_ROOT/src/" \
        >"$stdout" 2>"$stderr"
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        echo "错误: $label --native 不应在 coverage 未完成时静默成功" >&2
        exit 1
    fi
    if [[ -e "$out" ]]; then
        echo "错误: $label --native 失败时不应生成输出文件: $out" >&2
        exit 1
    fi

    require_pattern "$stderr" '后端类型: Native' "$label 进入 Native backend"
    require_pattern "$stderr" '=== 代码生成阶段 ===' "$label 进入代码生成阶段"
    require_pattern "$stderr" 'mir_extern_function_count: name=uya_write' "$label 记录 hosted MIR extern function inventory"
    reject_pattern "$stderr" '后端类型: C99' "$label 静默回落到 C99"
    reject_pattern "$stderr" '编译完成|✓ 编译成功|可执行文件:' "$label 伪报告构建成功"
}

run_hosted_program_reject_check() {
    local compiler="$1"
    local label="$2"

    run_native_reject_check "$compiler" "$label" "$REPO_ROOT/tests/test_native_main_only.uya"
    local stderr="$TMP_DIR/${label}.err"

    require_pattern "$stderr" \
        'native_hosted_coreir_preflight: status=-1 verifier_error=0 functions=[1-9][0-9]* core_bodies=[1-9][0-9]* pending_bodies=[1-9][0-9]*' \
        "$label 记录 hosted CoreIR preflight 未完成"
    require_pattern "$stderr" \
        'native_hosted_preflight: status=-1 verifier_error=-1 mir_extern_functions=[1-9][0-9]* mir_body_functions=0 mir_types=0 extern_symbols=0 c_import_objects=0 hosted_link_objects=0' \
        "$label 记录 hosted PortableMIR preflight 未 verifier-clean"
    require_pattern "$stderr" \
        'native_hosted_pending_body_frontier: function=native_main_bval .*reason=pending_core_body' \
        "$label 记录当前 pending body frontier"
    require_pattern "$stderr" \
        'native_unsupported_hosted_path: reason=native_hosted_portable_mir_preflight_failed required=verifier-clean CoreBody\+PortableMIR self-build coverage' \
        "$label 记录 hosted PortableMIR preflight failure"
    require_pattern "$stderr" \
        '不能静默回落 C99，也不能使用 build-seed LoweredProgram helper' \
        "$label 明确禁止 C99 fallback 和 build-seed helper"
    reject_pattern "$stderr" \
        'build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集' \
        "$label 回到旧 freestanding helper 诊断"
}

run_cmd_build_self_reject_check() {
    local compiler="$1"
    local label="$2"

    run_native_reject_check "$compiler" "$label" "$REPO_ROOT/src/cmd/build/main.uya"
    local stderr="$TMP_DIR/${label}.err"

    require_pattern "$stderr" '输入: .*src/cmd/build/main[.]uya' "$label 使用 cmd/build self-build root"
    require_pattern "$stderr" '解析: ok \(103 个文件\)' "$label 收集完整 cmd/build 依赖"
    require_pattern "$stderr" '检查: ok' "$label 通过类型检查后才进入 native 边界"
    require_pattern "$stderr" 'mir_extern_function_count: name=uya_write_newline' "$label 记录 hosted extern inventory"
    reject_pattern "$stderr" 'native_unsupported_(call_expr|fn_body|fn_shape)' \
        "$label 回到 pre-MIR freestanding shape 诊断"
}

run_hosted_program_reject_check "$REPO_ROOT/bin/uya" "uya"
run_hosted_program_reject_check "$REPO_ROOT/bin/cmd/build" "cmd-build"
run_cmd_build_self_reject_check "$REPO_ROOT/bin/uya" "uya-self"
run_cmd_build_self_reject_check "$REPO_ROOT/bin/cmd/build" "cmd-build-self"

echo "verify_native_cmd_build_no_silent_c99: ok"
