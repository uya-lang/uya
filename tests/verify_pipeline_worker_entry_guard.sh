#!/usr/bin/env bash
# 弱 worker 入口不得接管普通用户程序。
#
# 背景：C99 后端在 container_mode == 0 时总会发射一个弱桥接
# `uya_pipeline_worker_dispatch()`，它在 `main_main()` 之前先取
# `uya_pipeline_worker_main_if_requested` 的地址并调用。该函数（lib/std/process.uya）
# 原先**只看** `get_argc() == 2 && argv[1] == "--uya-pipeline-worker"`，
# 于是任何用新版标准库编出来的普通程序，只要恰好带这一个参数就被当成 worker：
# 它随即去 read 保留 fd 198/199，普通进程没有那层 dup2，read 失败后返回 122 ——
# 用户 main 一次都没执行。
#
#   修复前：./prog --uya-pipeline-worker   → 退出码 122（期望 42）
#   修复后：./prog --uya-pipeline-worker   → 退出码 42
#
# 修复：worker 自检加一层 `pipeline_worker_fds_are_wired()` —— 两个保留 fd 必须
# 已由 exec 侧 dup2 过（fcntl(F_GETFD) 成功）。真正的 worker 一定满足，
# 普通程序一定不满足。
#
# 用法：在仓库根目录 bash ./tests/verify_pipeline_worker_entry_guard.sh
# 环境变量：UYA_COMPILER 覆盖编译器路径（默认 <root>/bin/uya）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="${UYA_COMPILER:-$ROOT/bin/uya}"

TMP_DIR="$(mktemp -d /tmp/uya_verify_worker_guard.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

SRC="$TMP_DIR/worker_guard_main.uya"
OUT_BIN="$TMP_DIR/worker_guard_main"

cat > "$SRC" <<'UYA'
// 用户程序：带参数时走参数分支，返回 42；无参数返回 7。
// 修复前带 --uya-pipeline-worker 会被 worker 入口抢走并返回 122。
//
// 必须真的把 std.process 链进来 —— 弱符号 uya_pipeline_worker_main_if_requested
// 只在 std.process 参与链接时才被收进产物（否则弱引用为 null，dispatch 直接
// 返回 -1，本用例就覆盖不到任何东西）。
use std.process.pipeline_spawn;
use libc.get_argc;

export fn main() i32 {
    if get_argc() == 2 {
        return 42;
    }
    return 7;
}
UYA

UYA_ROOT="$ROOT/lib/" UYA_SPLIT_C=0 UYA_FORCE_BUILD=1 \
    "$COMPILER" build "$SRC" -o "$OUT_BIN" >/dev/null

fail() {
    echo "verify_pipeline_worker_entry_guard: 失败 —— $1" >&2
    exit 1
}

set +e
"$OUT_BIN"
no_arg_rc=$?
"$OUT_BIN" --uya-pipeline-worker
worker_arg_rc=$?
set -e

[ "$no_arg_rc" -eq 7 ] || fail "无参数时退出码应为 7，实际 $no_arg_rc"

# 核心断言：必须跑用户 main（42），不能是 worker 失败码 122。
if [ "$worker_arg_rc" -eq 122 ]; then
    fail "带 --uya-pipeline-worker 时用户程序被 worker 入口接管（退出码 122；期望 42）"
fi
[ "$worker_arg_rc" -eq 42 ] || fail "带 --uya-pipeline-worker 时退出码应为 42，实际 $worker_arg_rc"

echo "verify_pipeline_worker_entry_guard: ok"
