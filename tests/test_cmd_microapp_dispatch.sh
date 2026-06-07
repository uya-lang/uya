#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-cmd-microapp-dispatch.XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_pattern() {
    local path="$1"
    local pattern="$2"
    local description="$3"

    if ! grep -Eq "$pattern" "$path"; then
        echo "错误: 缺少 ${description}: $path" >&2
        cat "$path" >&2
        exit 1
    fi
}

require_literal() {
    local path="$1"
    local literal="$2"
    local description="$3"

    if ! grep -Fq "$literal" "$path"; then
        echo "错误: 缺少 ${description}: $path" >&2
        cat "$path" >&2
        exit 1
    fi
}

require_failure() {
    local status="$1"
    local description="$2"

    if [[ "$status" -eq 0 ]]; then
        echo "错误: ${description} 意外成功" >&2
        exit 1
    fi
}

: "${TARGET_GCC:=x86_64-linux-gnu-gcc}"
: "${MICROAPP_TARGET_ARCH:=x86_64}"
export TARGET_GCC
export MICROAPP_TARGET_ARCH

make -C "$ROOT_DIR" uya cmd-build cmd-microapp >/dev/null
test -x "$ROOT_DIR/bin/uya"
test -x "$ROOT_DIR/bin/cmd/build"
test -x "$ROOT_DIR/bin/cmd/microapp"

RAW_POBJ="$TMP_DIR/hello_payload.pobj"
POBJ="$TMP_DIR/hello payload.pobj"
DISPATCH_UAPP="$TMP_DIR/dispatch image.uapp"
DIRECT_UAPP="$TMP_DIR/direct image.uapp"

UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" microapp build \
    "$ROOT_DIR/examples/microapp/microcontainer_hello_source.uya" \
    -o "$RAW_POBJ" >"$TMP_DIR/build.out" 2>"$TMP_DIR/build.err"
cp "$RAW_POBJ" "$POBJ"
test -s "$POBJ"

UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" microapp pack "$POBJ" \
    -o "$DISPATCH_UAPP" >"$TMP_DIR/pack_dispatch.out" 2>"$TMP_DIR/pack_dispatch.err"
UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/cmd/microapp" pack "$POBJ" \
    -o "$DIRECT_UAPP" >"$TMP_DIR/pack_direct.out" 2>"$TMP_DIR/pack_direct.err"
cmp -s "$DISPATCH_UAPP" "$DIRECT_UAPP"
cmp -s "$TMP_DIR/pack_dispatch.out" "$TMP_DIR/pack_direct.out"
require_literal "$TMP_DIR/pack_dispatch.err" "hello payload.pobj" "launcher pack 输入 argv"
require_literal "$TMP_DIR/pack_direct.err" "hello payload.pobj" "cmd/microapp pack 输入 argv"
require_pattern "$TMP_DIR/pack_dispatch.err" 'microapp pack 完成' "launcher pack 成功文案"
require_pattern "$TMP_DIR/pack_direct.err" 'microapp pack 完成' "cmd/microapp pack 成功文案"

UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" microapp inspect "$DISPATCH_UAPP" \
    >"$TMP_DIR/inspect_dispatch.out" 2>"$TMP_DIR/inspect_dispatch.err"
UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/cmd/microapp" inspect "$DISPATCH_UAPP" \
    >"$TMP_DIR/inspect_direct.out" 2>"$TMP_DIR/inspect_direct.err"
cmp -s "$TMP_DIR/inspect_dispatch.out" "$TMP_DIR/inspect_direct.out"
cmp -s "$TMP_DIR/inspect_dispatch.err" "$TMP_DIR/inspect_direct.err"
require_pattern "$TMP_DIR/inspect_dispatch.out" '^kind=uapp$' "microapp inspect kind"
require_pattern "$TMP_DIR/inspect_dispatch.out" '^validated=yes$' "microapp inspect validation"

UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" microapp verify "$DISPATCH_UAPP" \
    >"$TMP_DIR/verify_dispatch.out" 2>"$TMP_DIR/verify_dispatch.err"
UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/cmd/microapp" verify "$DISPATCH_UAPP" \
    >"$TMP_DIR/verify_direct.out" 2>"$TMP_DIR/verify_direct.err"
cmp -s "$TMP_DIR/verify_dispatch.out" "$TMP_DIR/verify_direct.out"
cmp -s "$TMP_DIR/verify_dispatch.err" "$TMP_DIR/verify_direct.err"
require_pattern "$TMP_DIR/verify_dispatch.out" '^kind=uapp$' "microapp verify kind"
require_pattern "$TMP_DIR/verify_dispatch.out" '^verified=yes$' "microapp verify status"

check_legacy_diag() {
    local old_command="$1"
    local new_command="$2"
    local out="$TMP_DIR/${old_command}.out"
    local err="$TMP_DIR/${old_command}.err"
    local status=0

    set +e
    UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/uya" "$old_command" "$POBJ" -o "$TMP_DIR/legacy.uapp" \
        >"$out" 2>"$err"
    status=$?
    set -e
    require_failure "$status" "顶层 ${old_command} 兼容诊断"
    require_pattern "$err" "microapp ${new_command}" "${old_command} 迁移目标"
    require_pattern "$err" 'bin/cmd/microapp' "${old_command} 独立子命令提示"
}

check_legacy_diag pack-image pack
check_legacy_diag inspect-image inspect
check_legacy_diag verify-image verify

set +e
UYA_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/cmd/build" --app microapp \
    "$ROOT_DIR/tests/test_errno.uya" -o "$TMP_DIR/should-not-build" \
    >"$TMP_DIR/build_seed_microapp.out" 2>"$TMP_DIR/build_seed_microapp.err"
seed_status=$?
set -e
require_failure "$seed_status" "cmd/build seed microapp 路径"
require_pattern "$TMP_DIR/build_seed_microapp.err" 'cmd/build seed 不包含 microapp image/payload 支持' "cmd/build seed 拒绝文案"
require_pattern "$TMP_DIR/build_seed_microapp.err" 'uya microapp build' "cmd/build seed 迁移提示"

echo "test_cmd_microapp_dispatch: ok"
