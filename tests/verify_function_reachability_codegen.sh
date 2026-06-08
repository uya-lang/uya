#!/bin/bash
# 验证默认代码生成策略：按调用图裁剪未使用顶层函数；
# export extern 仍作为 ABI surface 正常生成。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
export UYA_ROOT="$REPO_ROOT/lib/"
OUT_C="$SCRIPT_DIR/build/function_reachability_verify.c"
CALLBACK_OUT_C="$SCRIPT_DIR/build/function_reachability_address_taken.c"
STRING_INTERP_OUT_C="$SCRIPT_DIR/build/function_reachability_string_interp.c"
MICROAPP_OUT_C="$SCRIPT_DIR/build/function_reachability_microapp.c"
IMPORT_MAIN_OUT_C="$SCRIPT_DIR/build/function_reachability_import_main.c"
IMPORT_MAIN_EXE="$SCRIPT_DIR/build/function_reachability_import_main"

extract_generated_microapp_c_path() {
    printf '%s\n' "$1" | sed -n 's/^输出文件: \(.*uya_output[^ ]*\.c\)$/\1/p' | head -n 1
}

mkdir -p "$SCRIPT_DIR/build"

echo "验证顶层函数可达性：编译 test_function_reachability_codegen.uya ..."
COMPILE_OUT=$("$COMPILER" build --c99 "$SCRIPT_DIR/test_function_reachability_codegen.uya" -o "$OUT_C" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ]; then
    echo "✗ 编译失败"
    echo "$COMPILE_OUT"
    exit 1
fi

if grep -q 'dead_internal(' "$OUT_C"; then
    echo "✗ 内部顶层函数 dead_internal 仍出现在 C 文件"
    exit 1
fi
echo "  dead_internal 未发射 ✓"

if grep -q 'dead_exported(' "$OUT_C"; then
    echo "✗ 未引用 export fn dead_exported 仍出现在 C 文件"
    exit 1
fi
echo "  dead_exported 已裁剪 ✓"

if ! grep -q 'kept_c_api(' "$OUT_C"; then
    echo "✗ export extern 函数未保留到 C 文件"
    exit 1
fi
echo "  kept_c_api 已保留 ✓"

echo ""
echo "验证 direct address root：编译 test_function_reachability_address_taken.uya ..."
COMPILE_OUT=$("$COMPILER" build --c99 "$SCRIPT_DIR/test_function_reachability_address_taken.uya" -o "$CALLBACK_OUT_C" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ]; then
    echo "✗ 编译失败"
    echo "$COMPILE_OUT"
    exit 1
fi

if grep -q 'dead_internal(' "$CALLBACK_OUT_C"; then
    echo "✗ dead_internal 仍出现在 address-taken C 文件"
    exit 1
fi
if ! grep -q 'callback_target(' "$CALLBACK_OUT_C"; then
    echo "✗ direct address root 函数 callback_target 未出现在 C 文件"
    exit 1
fi
echo "  callback_target 已保留 ✓"

echo ""
echo "验证 string interpolation callee root：编译 test_function_reachability_string_interp_expr.uya ..."
COMPILE_OUT=$("$COMPILER" build --c99 "$SCRIPT_DIR/test_function_reachability_string_interp_expr.uya" -o "$STRING_INTERP_OUT_C" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ]; then
    echo "✗ string interpolation reachability 编译失败"
    echo "$COMPILE_OUT"
    exit 1
fi

if grep -q 'dead_string_interp_helper(' "$STRING_INTERP_OUT_C"; then
    echo "✗ dead_string_interp_helper 仍出现在 string interpolation C 文件"
    exit 1
fi
if ! grep -q 'live_string_interp_helper(' "$STRING_INTERP_OUT_C"; then
    echo "✗ string interpolation callee live_string_interp_helper 未出现在 C 文件"
    exit 1
fi
echo "  string interpolation callee 已保留 ✓"

echo ""
echo "验证导入模块时普通 main 桥接：编译并运行 test_c99_import_main_codegen.uya ..."
RUN_OUT=$("$COMPILER" build --c99 "$SCRIPT_DIR/test_c99_import_main_codegen.uya" -o "$IMPORT_MAIN_OUT_C" 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ]; then
    echo "✗ import main C99 编译失败"
    echo "$RUN_OUT"
    exit 1
fi
cc -std=c99 -O0 -fno-builtin "$IMPORT_MAIN_OUT_C" -o "$IMPORT_MAIN_EXE"
"$IMPORT_MAIN_EXE"
echo "  import main 运行通过 ✓"

echo ""
echo "验证 microapp 顶层函数可达性：编译 test_function_reachability_codegen_microapp.uya ..."
set +e
COMPILE_OUT=$("$COMPILER" microapp build "$SCRIPT_DIR/test_function_reachability_codegen_microapp.uya" -o "$SCRIPT_DIR/build/function_reachability_microapp.uapp" 2>&1)
STATUS=$?
set -e
MICROAPP_TMP_C="$(extract_generated_microapp_c_path "$COMPILE_OUT")"
if [ -z "$MICROAPP_TMP_C" ]; then
    if printf '%s\n' "$COMPILE_OUT" | grep -q 'cmd/build seed 不包含 microapp image/payload 支持'; then
        echo "  microapp reachability: build seed 不包含 microapp image/payload，跳过 ✓"
        echo ""
        echo "✓ 顶层函数可达性验证通过"
        exit 0
    fi
    echo "✗ microapp 编译输出中未找到临时 C 路径"
    echo "$COMPILE_OUT"
    exit 1
fi
if [ ! -f "$MICROAPP_TMP_C" ]; then
    echo "✗ microapp 未生成 C 输出"
    echo "$COMPILE_OUT"
    exit 1
fi
if [ $STATUS -ne 0 ]; then
    echo "  microapp 后端链接失败，但 C 输出已生成，继续做可达性检查"
fi
cp "$MICROAPP_TMP_C" "$MICROAPP_OUT_C"

if grep -q 'dead_internal(' "$MICROAPP_OUT_C"; then
    echo "✗ microapp 的 dead_internal 仍出现在 C 文件"
    exit 1
fi
if ! grep -q 'kept_exported(' "$MICROAPP_OUT_C"; then
    echo "✗ microapp 的 kept_exported 未出现在 C 文件"
    exit 1
fi
echo "  microapp 裁剪验证通过 ✓"

echo ""
echo "✓ 顶层函数可达性验证通过"
