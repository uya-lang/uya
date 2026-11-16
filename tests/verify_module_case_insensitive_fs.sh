#!/usr/bin/env bash
# 回归门禁：大小写不敏感文件系统上，**符号导入**不得把同一份模块文件加载两次
#
# 现象（macos-ci · TEST_PROFILE=hosted）：
#   `test_multilevel_module` / `test_std_io_file` / `test_std_io_buffering` 生成单文件 C 时，
#   `std_io_file_write` 等同名函数出现**两处定义**，clang 报
#   `redefinition of 'std_io_file_write'` 并直接失败；`test_tflm_interpreter` 的
#   `interpreter_make` 是同一形态。
#
# 根因：macOS / Windows 的默认文件系统**大小写不敏感**。`use std.io.File;` 是一条**符号**
#   导入，模块解析却会去探测 `lib/std/io/File.uya` —— 在大小写不敏感的文件系统上这个路径
#   真的能打开（就是 `file.uya`），于是 `file.uya` 以 `std.io.File` 的身份被**第二次**合并进
#   程序，同名顶层函数重复发射。Linux 是大小写敏感的，`File.uya` 不存在，所以本地永远复现
#   不出来 —— 这正是这条 bug 长期只在 macos-ci 上红的原因。
#
# 修法：模块候选路径的存在性判断改成「目录项逐字节匹配」
#   （`src/driver/modules.uya` 的 `module_path_entry_exists_exact_case`），
#   让 Uya 模块名在 macOS 上也保持大小写敏感语义。
#
# 本脚本只在**大小写不敏感**的文件系统上有判别力：先探测，探测不到就 skip
# （Linux CI 恒 skip，macOS / Windows 上会真正跑）。
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uya_case_gate.XXXXXX")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

fail() {
    echo "✗ $*"
    exit 1
}

# --- 1. 探测文件系统是否大小写不敏感 ---
: > "$TMP_DIR/probe_case"
if [ -e "$TMP_DIR/PROBE_CASE" ]; then
    echo "· 文件系统大小写不敏感（本用例适用）"
else
    echo "skip: 当前文件系统大小写敏感，本用例不适用（Linux 上正常跳过）"
    exit 0
fi

# --- 2. 选编译器（hosted 编译器优先，与 macos-ci 的失败链路一致） ---
COMPILER="${UYA_COMPILER:-}"
if [ -z "$COMPILER" ]; then
    if [ -x "$ROOT_DIR/bin/uya-hosted" ]; then
        COMPILER="$ROOT_DIR/bin/uya-hosted"
    elif [ -x "$ROOT_DIR/bin/uya" ]; then
        COMPILER="$ROOT_DIR/bin/uya"
    else
        echo "skip: 找不到编译器（bin/uya-hosted / bin/uya 都不存在）"
        exit 0
    fi
fi

# --- 3. 生成单文件 C，统计同名函数定义数 ---
TEST_SRC="$ROOT_DIR/tests/test_multilevel_module.uya"
[ -f "$TEST_SRC" ] || fail "缺少用例 $TEST_SRC"
OUT_C="$TMP_DIR/out.c"
LOG="$TMP_DIR/build.log"

if ! UYA_ROOT="$ROOT_DIR/lib" RUNTIME_MODE=hosted \
    "$COMPILER" build "$TEST_SRC" -o "$OUT_C" --c99 --no-split-c >"$LOG" 2>&1; then
    echo "----- 编译器输出（末 30 行）-----"
    tail -30 "$LOG" || true
    fail "单文件 C 生成失败：疑似符号导入把同一模块加载了两次"
fi

# 只断言**定义**的处数：单文件 C 里本来就有 1 处前置声明（以 `;` 结尾），
# 把声明也算进来会得到 2，误报「重复定义」。
SIG='^struct err_union_size_t std_io_file_write'
ALL="$(grep -c "$SIG" "$OUT_C" 2>/dev/null || true)"
PROTOS="$(grep -c "$SIG.*;$" "$OUT_C" 2>/dev/null || true)"
ALL="${ALL:-0}"
PROTOS="${PROTOS:-0}"
DEFS=$(( ALL - PROTOS ))
if [ "$DEFS" != "1" ]; then
    echo "----- std_io_file_write 的出现位置（声明 + 定义）-----"
    grep -n 'std_io_file_write' "$OUT_C" | head -10 || true
    fail "std_io_file_write 在单文件 C 里有 $DEFS 处**定义**（共 $ALL 处出现，其中 $PROTOS 处是声明），期望 1 处定义（模块被重复加载）"
fi

echo "✓ 大小写不敏感文件系统上未重复加载模块（std_io_file_write 定义数 = 1）"
exit 0
