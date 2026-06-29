#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR"' EXIT

echo "验证显式类型局部 + catch 标识符路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_typed_catch_local.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q 'typed catch local' "$TMP_STDOUT"
echo "  typed catch local ✓"

echo "验证 run --exec --verbose typed catch 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_typed_catch_local.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ typed catch local unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  typed catch local --exec ✓"

echo "验证字段数组/指针字段/全局数组下标写入路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_field_pointer_index.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  field/pointer/global index --vm ✓"

echo "验证 run --exec --verbose 字段数组/指针字段/全局数组下标写入路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_field_pointer_index.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ field/pointer/global index unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  field/pointer/global index --exec ✓"

echo "验证数组指针元素成员读取/写回路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_array_ptr_member.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  array ptr member --vm ✓"

echo "验证 run --exec --verbose 下数组指针元素成员路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_array_ptr_member.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ array ptr member unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  array ptr member --exec ✓"

echo "验证 byte slice.ptr 读写与宿主桥接路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_slice_ptr.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  slice.ptr --vm ✓"

echo "验证 run --exec --verbose 下 byte slice.ptr 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_slice_ptr.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ slice.ptr unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  slice.ptr --exec ✓"

echo "验证跨文件 shared whole-module import 的 libc.stderr 成员访问..."
"$COMPILER" run --vm \
    "$SCRIPT_DIR/exec_vm_compiler_shared_libc_import/main.uya" \
    "$SCRIPT_DIR/exec_vm_compiler_shared_libc_import/shared_imports.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q 'shared libc import stderr' "$TMP_STDERR"
echo "  shared libc.stderr --vm ✓"

echo "验证 run --exec --verbose 下跨文件 shared whole-module import 的 libc.stderr 成员访问不发生 fallback..."
"$COMPILER" run --exec --verbose \
    "$SCRIPT_DIR/exec_vm_compiler_shared_libc_import/main.uya" \
    "$SCRIPT_DIR/exec_vm_compiler_shared_libc_import/shared_imports.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q 'shared libc import stderr' "$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ shared libc.stderr unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  shared libc.stderr --exec ✓"

echo "验证 error union .error_id 成员读取路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_error_union_error_id.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  error union .error_id --vm ✓"

echo "验证 run --exec --verbose 下 error union .error_id 成员读取路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_error_union_error_id.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ error union .error_id unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  error union .error_id --exec ✓"

echo "验证 error union .value 成员读取路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_error_union_value.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  error union .value --vm ✓"

echo "验证 run --exec --verbose 下 error union .value 成员路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_error_union_value.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ error union .value unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  error union .value --exec ✓"

echo "验证 union match 基础路径不再打印返回类型误诊断..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_union_dispatch.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q 'match 所有分支的返回类型必须一致' "$TMP_STDERR"; then
    echo "✗ union dispatch printed stale match type diagnostic"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  union dispatch --vm ✓"

echo "验证 run --exec --verbose 下 union match 基础路径不发生 fallback，且不再打印误诊断..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_union_dispatch.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ union dispatch unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q 'match 所有分支的返回类型必须一致' "$TMP_STDERR"; then
    echo "✗ union dispatch printed stale match type diagnostic under --exec"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  union dispatch --exec ✓"

echo "验证 union struct-field match 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_union_field_match.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q 'match 所有分支的返回类型必须一致' "$TMP_STDERR"; then
    echo "✗ union field match printed stale match type diagnostic"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  union field match --vm ✓"

echo "验证 run --exec --verbose 下 union struct-field match 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_union_field_match.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ union field match unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q 'match 所有分支的返回类型必须一致' "$TMP_STDERR"; then
    echo "✗ union field match printed stale match type diagnostic under --exec"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  union field match --exec ✓"

echo "验证 match return block 中 union 结构体字段读取路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_match_return_struct_field.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q 'match 所有分支的返回类型必须一致' "$TMP_STDERR"; then
    echo "✗ match return struct field printed stale match type diagnostic"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  match return struct field --vm ✓"

echo "验证 run --exec --verbose 下 match return block union 结构体字段路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_match_return_struct_field.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ match return struct field unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q 'match 所有分支的返回类型必须一致' "$TMP_STDERR"; then
    echo "✗ match return struct field printed stale match type diagnostic under --exec"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  match return struct field --exec ✓"

echo "验证多语句 returning match arm block 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_match_return_block_multi_stmt.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '当前仅支持单表达式 catch/match 分支块' "$TMP_STDERR"; then
    echo "✗ multi-stmt returning match arm still hit single-expr blocker"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  multi-stmt returning match arm --vm ✓"

echo "验证 run --exec --verbose 下多语句 returning match arm block 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_match_return_block_multi_stmt.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ multi-stmt returning match arm unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q '当前仅支持单表达式 catch/match 分支块' "$TMP_STDERR"; then
    echo "✗ multi-stmt returning match arm still hit single-expr blocker under --exec"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  multi-stmt returning match arm --exec ✓"

echo "验证同作用域局部在 else-if 条件中的读取路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_else_if_local.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  else-if local read --vm ✓"

echo "验证 run --exec --verbose 下同作用域局部的 else-if 条件路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_else_if_local.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ else-if local read unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  else-if local read --exec ✓"

echo "验证 unary bitwise not 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_unary_bit_not.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  unary bitwise not --vm ✓"

echo "验证 run --exec --verbose 下 unary bitwise not 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_unary_bit_not.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ unary bitwise not unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  unary bitwise not --exec ✓"

echo "验证超过 32 项的 array literal 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_array_literal_many_items.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  array literal >32 items --vm ✓"

echo "验证 run --exec --verbose 下超过 32 项的 array literal 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_array_literal_many_items.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ array literal >32 items unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  array literal >32 items --exec ✓"

echo "验证同模块 file-local extern 声明命中另一文件真实函数体路径..."
"$COMPILER" run --vm \
    "$SCRIPT_DIR/exec_vm_compiler_file_local_extern/main.uya" \
    "$SCRIPT_DIR/exec_vm_compiler_file_local_extern/helper.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  file-local extern bodyful target --vm ✓"

echo "验证 run --exec --verbose 下同模块 file-local extern 声明路径不发生 fallback..."
"$COMPILER" run --exec --verbose \
    "$SCRIPT_DIR/exec_vm_compiler_file_local_extern/main.uya" \
    "$SCRIPT_DIR/exec_vm_compiler_file_local_extern/helper.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ file-local extern bodyful target unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  file-local extern bodyful target --exec ✓"

echo "验证 imported global 裸标识符读写路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_imported_global_ident.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  imported global ident --vm ✓"

echo "验证 run --exec --verbose 下 imported global 裸标识符路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_imported_global_ident.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ imported global ident unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  imported global ident --exec ✓"

echo "验证全局数组元素取地址路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_global_index_addr.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  global index addr --vm ✓"

echo "验证 run --exec --verbose 下全局数组元素取地址路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_global_index_addr.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ global index addr unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  global index addr --exec ✓"

echo "验证 runtime atomic global 直接读写与取址读取路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_atomic_global.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  atomic global --vm ✓"

echo "验证 run --exec --verbose 下 runtime atomic global 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_atomic_global.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ atomic global unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  atomic global --exec ✓"

echo "验证 repeat array literal 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_repeat_array_literal.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  repeat array literal --vm ✓"

echo "验证 run --exec --verbose 下 repeat array literal 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_repeat_array_literal.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ repeat array literal unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  repeat array literal --exec ✓"

echo "验证空 struct init 零填充路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_empty_struct_init.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  empty struct init --vm ✓"

echo "验证 run --exec --verbose 下空 struct init 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_empty_struct_init.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ empty struct init unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  empty struct init --exec ✓"

echo "验证全局 partial struct 大字段零填充路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_global_partial_struct_zero_fill.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  global partial struct zero-fill --vm ✓"

echo "验证 run --exec --verbose 下全局 partial struct 大字段零填充路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_global_partial_struct_zero_fill.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ global partial struct zero-fill unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  global partial struct zero-fill --exec ✓"

echo "验证全局 zero array-of-struct 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_zero_struct_array_global.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  global zero array-of-struct --vm ✓"

echo "验证 run --exec --verbose 下全局 zero array-of-struct 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_zero_struct_array_global.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ global zero array-of-struct unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  global zero array-of-struct --exec ✓"

echo "验证全局聚合初始化组合路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_global_aggregate_combo.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  global aggregate combo --vm ✓"

echo "验证 run --exec --verbose 下全局聚合初始化组合路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_global_aggregate_combo.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ global aggregate combo unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  global aggregate combo --exec ✓"

echo "验证 union 字段零值初始化路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/exec_vm_cases/compiler_zero_union_field.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  zero union field --vm ✓"

echo "验证 run --exec --verbose 下 union 字段零值初始化路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/exec_vm_cases/compiler_zero_union_field.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ zero union field unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  zero union field --exec ✓"

echo "验证 @asm_target() as! i32 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_asm_target.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  asm_target --vm ✓"

echo "验证 run --exec --verbose 下 @asm_target() 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_asm_target.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ asm_target unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  asm_target --exec ✓"

echo "验证 _ = expr; 丢弃赋值路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_discard_assign.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q 'discard assign' "$TMP_STDOUT"
echo "  discard assign --vm ✓"

echo "验证 run --exec --verbose 下 _ = expr; 丢弃赋值路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_discard_assign.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ discard assign unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  discard assign --exec ✓"

echo "验证 catch 前缀副作用 block 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_catch_block_prefix.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q 'catch prefix return' "$TMP_STDOUT"
echo "  catch prefix block --vm ✓"

echo "验证 run --exec --verbose 下 catch 前缀副作用 block 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_catch_block_prefix.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ catch prefix block unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  catch prefix block --exec ✓"

echo "验证 !void catch 的 void 尾语句路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_catch_void_tail.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  catch void tail --vm ✓"

echo "验证 run --exec --verbose 下 !void catch 的 void 尾语句路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_catch_void_tail.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ catch void tail unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  catch void tail --exec ✓"

echo "验证空 catch block 丢弃错误路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_catch_empty_block.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q 'catch 分支块为空' "$TMP_STDERR"; then
    echo "✗ empty catch block still unsupported"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  empty catch block --vm ✓"

echo "验证 run --exec --verbose 下空 catch block 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_catch_empty_block.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ empty catch block unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q 'catch 分支块为空' "$TMP_STDERR"; then
    echo "✗ empty catch block still unsupported under --exec"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  empty catch block --exec ✓"

echo "验证 catch block 裸 return 路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_catch_bare_return.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  catch bare return --vm ✓"

echo "验证 run --exec --verbose 下 catch block 裸 return 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_catch_bare_return.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ catch bare return unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  catch bare return --exec ✓"

echo "验证 catch 错误绑定路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_catch_error_bind.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '当前不支持带错误绑定的 catch' "$TMP_STDERR"; then
    echo "✗ catch error binding still unsupported"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  catch error binding --vm ✓"

echo "验证 run --exec --verbose 下 catch 错误绑定路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_catch_error_bind.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ catch error binding unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
if grep -q '当前不支持带错误绑定的 catch' "$TMP_STDERR"; then
    echo "✗ catch error binding still unsupported under --exec"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  catch error binding --exec ✓"

echo "验证 struct sizeof/alignof 在 --vm 下直接折叠..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_compiler_sizeof_struct.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  sizeof/alignof struct --vm ✓"

echo "验证 run --exec --verbose struct sizeof/alignof 路径不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_compiler_sizeof_struct.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ sizeof/alignof struct unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  sizeof/alignof struct --exec ✓"

echo "✓ exec vm compiler regression checks passed"
