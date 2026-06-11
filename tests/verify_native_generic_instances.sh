#!/usr/bin/env bash

# Native build-seed 边界：验证 native build compiler 子集所需泛型实例 registry / worklist 能力。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERIC_FILE="$REPO_ROOT/src/codegen/native/generic.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_generic_instances.uya"

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "错误: 缺少 $path" >&2
        exit 1
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 native generic instance 证据: $description" >&2
        exit 1
    fi
}

require_file "$GENERIC_FILE"
require_file "$TEST_FILE"

require_pattern "$GENERIC_FILE" '^export[[:space:]]+struct[[:space:]]+NativeGenericRegistry' "泛型实例 registry"
require_pattern "$GENERIC_FILE" '^export[[:space:]]+struct[[:space:]]+NativeGenericInstance' "泛型实例记录"
require_pattern "$GENERIC_FILE" '^export[[:space:]]+struct[[:space:]]+NativeGenericTypeArg' "泛型类型实参记录"
require_pattern "$GENERIC_FILE" '^export[[:space:]]+struct[[:space:]]+NativeGenericBinding' "泛型参数绑定记录"
require_pattern "$GENERIC_FILE" 'NativeTable' "动态表存储"
require_pattern "$GENERIC_FILE" 'native_generic_register_function' "泛型函数实例注册"
require_pattern "$GENERIC_FILE" 'native_generic_register_struct' "泛型结构实例注册"
require_pattern "$GENERIC_FILE" 'native_generic_register_method' "泛型方法实例注册"
require_pattern "$GENERIC_FILE" 'native_generic_next_work_item' "泛型实例 worklist"
require_pattern "$GENERIC_FILE" 'native_generic_write_instance_name' "稳定实例符号名生成"
require_pattern "$GENERIC_FILE" 'native_generic_binding_lookup' "泛型参数替换查询"

if grep -Eq 'MAX_NATIVE_GENERIC|NATIVE_GENERIC_MAX|\\[[[:space:]]*NativeGenericInstance[[:space:]]*:' "$GENERIC_FILE"; then
    echo "错误: native generic registry 不能使用固定泛型实例容量" >&2
    exit 1
fi

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_generic_instances.uya --no-split-c --project-root src/)

echo "verify_native_generic_instances: ok"
