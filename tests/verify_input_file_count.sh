#!/usr/bin/env bash
# 显式输入文件数回归：命令行上给 >64 个 .uya 必须正常编译，不许越界/报假错。
#
# 背景：`main()` 里 `input_file_indices` 曾声明成 `[i32: 64]`（compiler-mini 时代遗留），
# 而 `parse_args` 的上限守卫和其余所有表用的都是 `MAX_INPUT_FILES`（=512）。两者不一致 ⇒
# 第 65 个输入文件的下标被写进数组之外（栈上相邻变量），现场是两种假象之一：
#   * `错误: 无法获取输入文件路径（索引 1886221359）`—— 读回被写坏的下标；
#   * `错误: 收集模块依赖失败: <编译器自身路径>` —— 把坏下标当成路径。
# 报错指向的位置（编译器路径 / 文件路径）与真实原因（数组比守卫小）完全无关，很难定位。
#
# 用法：在仓库根目录 bash ./tests/verify_input_file_count.sh
# 环境变量：UYA_COMPILER 覆盖编译器路径（默认 <root>/bin/uya）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="${UYA_COMPILER:-$ROOT/bin/uya}"
# 数量必须有意义地大于旧上限 64，且远离 512 这个真实上限
FILE_COUNT="${UYA_VERIFY_INPUT_FILES:-100}"

TMP_DIR="$(mktemp -d /tmp/uya_verify_input_file_count.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

WORK="$TMP_DIR/work"
mkdir -p "$WORK"

# 1 个入口文件 + (FILE_COUNT-1) 个库文件，全部**显式**列在命令行上
{
    printf 'export fn main() i32 {\n'
    printf '    return argc_probe();\n'
    printf '}\n'
} > "$WORK/main.uya"
printf 'fn argc_probe() i32 { return 0; }\n' > "$WORK/lib000.uya"

# lib000 已单独写出，这里补到总共 FILE_COUNT 个（入口 main.uya 占 1 个）
i=1
while [ "$i" -lt $((FILE_COUNT - 1)) ]; do
    printf 'export fn lib_%03d() i32 { return %d; }\n' "$i" "$i" > "$WORK/lib$(printf '%03d' "$i").uya"
    i=$((i + 1))
done

INPUTS=$(ls "$WORK"/*.uya | sort)
INPUT_COUNT=$(printf '%s\n' "$INPUTS" | wc -l)
if [ "$INPUT_COUNT" -ne "$FILE_COUNT" ]; then
    echo "verify_input_file_count: 失败 —— 期望 $FILE_COUNT 个输入文件，实得 $INPUT_COUNT" >&2
    exit 1
fi

cd "$WORK"

# 2) build：>64 个显式输入必须编译成功并产出可运行产物
OUT_BIN="$TMP_DIR/many_files.out"
if ! "$COMPILER" build $INPUTS -o "$OUT_BIN" > "$TMP_DIR/build.log" 2>&1; then
    echo "verify_input_file_count: 失败 —— $FILE_COUNT 个显式输入文件编译失败" >&2
    cat "$TMP_DIR/build.log" >&2
    exit 1
fi
if [ ! -x "$OUT_BIN" ]; then
    echo "verify_input_file_count: 失败 —— 未产出可执行文件 $OUT_BIN" >&2
    cat "$TMP_DIR/build.log" >&2
    exit 1
fi
"$OUT_BIN"

# 3) check：同一批文件在只检查模式下也要通过
"$COMPILER" check $INPUTS > "$TMP_DIR/check.log" 2>&1

# 4) 依赖收集必须把每个显式输入都算进去（防止「被静默丢掉」这种更隐蔽的坏法）
UYA_DEBUG_DEPENDENCY_LIST=1 "$COMPILER" check $INPUTS > "$TMP_DIR/deps.log" 2>&1 || true
seen=$(grep -c '依赖文件\[' "$TMP_DIR/deps.log" || true)
if [ "$seen" -lt "$FILE_COUNT" ]; then
    echo "verify_input_file_count: 失败 —— 依赖列表只登记了 $seen 个文件（应 ≥ $FILE_COUNT）" >&2
    tail -20 "$TMP_DIR/deps.log" >&2
    exit 1
fi

echo "verify_input_file_count: ok ($FILE_COUNT 个显式输入文件)"
