#!/usr/bin/env bash
# split-C 重名顶层常量回归：链接期不得出现 multiple definition。
#
# 背景：合并命名空间下两个源文件可以各写一份同名 export const（真实例子：
# lib/libc 的 CLOCKS_PER_SEC 曾由 stdlib.uya 与 time.uya 各定义一次）。
# C99 后端只应发射一份定义。
#
# 触发条件：后端登记「已发射定义的全局 C 名」用的 global_variables 注册表上限是
# C99_MAX_GLOBAL_VARS（512）。小程序撑不满，去重生效、看不出问题；大程序
# （uya-agent 1700+ 顶层全局、或本用例铺的 600 个 export const）一旦撑满，
# 登记被静默丢弃，同名常量就在两个镜像 TU 里各定义一次。
#
# 用法：在仓库根目录 bash ./tests/verify_split_dup_global.sh
# 环境变量：UYA_COMPILER 覆盖编译器路径（默认 <root>/bin/uya）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="${UYA_COMPILER:-$ROOT/bin/uya}"
SRC_DIR="$ROOT/tests/fixtures/split_dup_global"

TMP_DIR="$(mktemp -d /tmp/uya_verify_split_dup_global.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 拷到临时目录：镜像模式按源文件绝对路径分 TU，绝对路径才能稳定拆出
# dupmod/a.c 与 dupmod/b.c 两个 TU（在仓库内构建时路径是相对的会并进 common）。
WORK="$TMP_DIR/work"
mkdir -p "$WORK"
cp -r "$SRC_DIR/." "$WORK/"
SPLIT_DIR="$TMP_DIR/split"
OUT_BIN="$TMP_DIR/dup_global.out"

cd "$WORK"
"$COMPILER" build main.uya --split-c-dir "$SPLIT_DIR" -o "$OUT_BIN" --c99

# 1) 两个源文件确实各自落到了一个独立镜像 TU（否则本用例没覆盖到目标路径）
a_c="$(find "$SPLIT_DIR" -path '*dupmod/a.c' | head -n 1)"
b_c="$(find "$SPLIT_DIR" -path '*dupmod/b.c' | head -n 1)"
if [ -z "$a_c" ] || [ -z "$b_c" ]; then
    echo "verify_split_dup_global: 失败 —— 没找到 dupmod/a.c 与 dupmod/b.c 的镜像 TU" >&2
    find "$SPLIT_DIR" -name '*.c' >&2
    exit 1
fi

# 2) DUP_SHARED_CONST 的定义全树只能有一份
def_count="$(grep -rl 'const int64_t DUP_SHARED_CONST = ' "$SPLIT_DIR" --include='*.c' | wc -l)"
if [ "$def_count" -ne 1 ]; then
    echo "verify_split_dup_global: 失败 —— DUP_SHARED_CONST 有 $def_count 份定义（应为 1）" >&2
    grep -rn 'const int64_t DUP_SHARED_CONST = ' "$SPLIT_DIR" --include='*.c' >&2
    exit 1
fi

# 3) 链接产物可运行且算术正确（覆盖两处引用都解析到同一定义）
"$OUT_BIN"

echo "verify_split_dup_global: ok"
