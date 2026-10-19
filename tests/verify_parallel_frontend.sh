#!/bin/bash
# 验证前端「进程级并行」的三条硬约束：
#   1. `--jobs N` 与 `--jobs 1`（串行）产出的 C **逐字节相同**；
#   2. 并行 codegen 的临时分片（*.uyabody）不残留；
#   3. 语法错误在并行/串行下报的一致（并行 parse 失败会整体回退串行重做）。
#
# 用法: bash tests/verify_parallel_frontend.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UYA="$REPO_ROOT/bin/uya"
TMP_DIR="$(mktemp -d /tmp/uya_parallel_frontend.XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
    echo "✗ $1"
    exit 1
}

if [ ! -x "$UYA" ]; then
    fail "未找到可执行编译器: $UYA（先 make uya）"
fi

# 小工程：两个模块 + 一个 main，够触发多 TU 镜像
mkdir -p "$TMP_DIR/proj"
cat >"$TMP_DIR/proj/helper.uya" <<'EOF'
export fn helper_add(a: i32, b: i32) i32 {
    return a + b;
}
EOF
cat >"$TMP_DIR/proj/main.uya" <<'EOF'
use helper;

fn main() i32 {
    const v: i32 = helper_add(2, 3);
    if v != 5 {
        return 1;
    }
    return 0;
}
EOF

echo "验证：--jobs 1 与 --jobs 8 生成的 C 一致 ..."
for mode in "serial 1" "parallel 8"; do
    set -- $mode
    name="$1"
    jobs="$2"
    out="$TMP_DIR/split_$name"
    rm -rf "$out"
    if ! UYA_ROOT="$REPO_ROOT/lib/" "$UYA" build "$TMP_DIR/proj/main.uya" \
        -o "$TMP_DIR/app_$name" --c99 --split-c-dir "$out" --jobs "$jobs" >"$TMP_DIR/build_$name.log" 2>&1; then
        cat "$TMP_DIR/build_$name.log"
        fail "--jobs $jobs 编译失败"
    fi
done

if ! diff -r "$TMP_DIR/split_serial" "$TMP_DIR/split_parallel" >"$TMP_DIR/diff.log" 2>&1; then
    # 只允许 .o 差异（目标文件由 make 顺序产生，不参与本验证）
    unexpected="$(grep -E '^Only in|^Files' "$TMP_DIR/diff.log" | grep -v '\.o ' | grep -v '\.o$' || true)"
    if [ -n "$unexpected" ]; then
        echo "$unexpected"
        fail "串行与并行 codegen 生成的 C 不一致"
    fi
fi

leftover="$(find "$TMP_DIR/split_parallel" -name '*.uyabody' 2>/dev/null | head -5)"
if [ -n "$leftover" ]; then
    echo "$leftover"
    fail "并行 codegen 残留临时分片 *.uyabody"
fi

if [ ! -x "$TMP_DIR/app_parallel" ]; then
    fail "并行路径未产出可执行文件"
fi
if ! "$TMP_DIR/app_parallel"; then
    fail "并行路径产出的程序运行结果不正确"
fi

echo "验证：语法错误在 --jobs 8 下报错与 --jobs 1 一致 ..."
mkdir -p "$TMP_DIR/bad"
cat >"$TMP_DIR/bad/main.uya" <<'EOF'
fn main() i32 {
    return 1 + ;
}
EOF
UYA_ROOT="$REPO_ROOT/lib/" "$UYA" build "$TMP_DIR/bad/main.uya" -o "$TMP_DIR/bad1.c" --c99 --jobs 1 >"$TMP_DIR/err1.log" 2>&1
rc1=$?
UYA_ROOT="$REPO_ROOT/lib/" "$UYA" build "$TMP_DIR/bad/main.uya" -o "$TMP_DIR/bad8.c" --c99 --jobs 8 >"$TMP_DIR/err8.log" 2>&1
rc8=$?
if [ "$rc1" -eq 0 ] || [ "$rc8" -eq 0 ]; then
    fail "语法错误用例本应编译失败（jobs1=$rc1 jobs8=$rc8）"
fi
if ! diff -q "$TMP_DIR/err1.log" "$TMP_DIR/err8.log" >/dev/null 2>&1; then
    echo "--- jobs=1 ---"
    cat "$TMP_DIR/err1.log"
    echo "--- jobs=8 ---"
    cat "$TMP_DIR/err8.log"
    fail "并行/串行报错文本不一致"
fi

echo "verify_parallel_frontend: ok"
