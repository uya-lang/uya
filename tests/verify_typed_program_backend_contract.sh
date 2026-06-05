#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
TYPED_BACKEND_FILE="$REPO_ROOT/src/checker/typed_backend.uya"
CHECKER_TYPES_FILE="$REPO_ROOT/src/checker/types.uya"
CHECKER_SYMBOLS_FILE="$REPO_ROOT/src/checker/symbols.uya"
C99_DIR="$REPO_ROOT/src/codegen/c99"

require_file() {
    local file="$1"
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: TypedProgram backend contract 缺少证据: $description" >&2
        return 1
    fi
}

require_file "$COMPILER"
require_file "$TYPED_BACKEND_FILE"
require_file "$CHECKER_TYPES_FILE"
require_file "$CHECKER_SYMBOLS_FILE"
require_file "$C99_DIR"

if grep -RIn --include='*.uya' 'checker_infer_type(' "$C99_DIR" \
    | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*//'; then
    echo "错误: C99 后端仍直接调用 checker_infer_type" >&2
    exit 1
fi

require_pattern "$TYPED_BACKEND_FILE" 'typed_program_get_expr_type' "TypedProgram expr type 查询"
require_pattern "$TYPED_BACKEND_FILE" 'checker_typed_backend_type_for_codegen' "C99 后端类型查询入口"
require_pattern "$TYPED_BACKEND_FILE" 'UYA_STRICT_TYPED_BACKEND' "strict typed backend 环境变量"
require_pattern "$TYPED_BACKEND_FILE" 'TypedProgram 缺少后端表达式类型' "strict 缺失合同诊断"
require_pattern "$TYPED_BACKEND_FILE" 'checker\.typed_backend_reentry_count = checker\.typed_backend_reentry_count \+ 1' "后端重进 checker 计数"
require_pattern "$TYPED_BACKEND_FILE" 'checker_typed_backend_reentry_count' "后端重进计数查询 API"
require_pattern "$CHECKER_TYPES_FILE" 'typed_program:[[:space:]]*TypedProgram' "TypeChecker 持有 TypedProgram"
require_pattern "$CHECKER_TYPES_FILE" 'typed_type_records:[[:space:]]*SemanticVector' "TypeChecker 持有 TypeId -> Type 记录表"
require_pattern "$CHECKER_TYPES_FILE" 'typed_backend_reentry_count:[[:space:]]*i32' "TypeChecker 持有 reentry 计数"
require_pattern "$CHECKER_SYMBOLS_FILE" 'checker\.typed_backend_reentry_count = 0' "checker reset 清零 reentry 计数"

if ! grep -RIn --include='*.uya' 'checker_typed_backend_type_for_codegen' "$C99_DIR" >/dev/null; then
    echo "错误: C99 后端未通过 TypedProgram backend 查询入口读取表达式类型" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d /tmp/uya-typed-backend-contract.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat >"$TMP_DIR/main.uya" <<'EOF'
use std.runtime.entry;

struct Counter {
    value: i32,
}

Counter {
    fn add(self: &Self, delta: i32) i32 {
        return self.value + delta;
    }
}

struct Box<T> {
    item: T,
}

fn bump(x: i32) i32 {
    return x + 1;
}

fn identity<T>(x: T) T {
    return x;
}

const GLOBAL_COUNTER: Counter = Counter{ value: 10 };

export fn main() i32 {
    const ordinary: i32 = bump(1);
    const c: Counter = Counter{ value: ordinary };
    const method: i32 = c.add(2);
    const wrapped: Box<i32> = Box<i32>{ item: identity<i32>(method) };
    const field: i32 = wrapped.item + GLOBAL_COUNTER.value;
    return field - 14;
}
EOF

stdout_file="$TMP_DIR/stdout.txt"
stderr_file="$TMP_DIR/stderr.txt"

UYA_STRICT_TYPED_BACKEND=1 "$COMPILER" build "$TMP_DIR/main.uya" \
    --c99 --no-split-c -O0 -o "$TMP_DIR/main.c" >"$stdout_file" 2>"$stderr_file"

if grep -Fq "TypedProgram 缺少后端表达式类型" "$stdout_file" "$stderr_file"; then
    echo "错误: strict typed backend 样例触发了后端重进 checker 诊断" >&2
    cat "$stderr_file" >&2
    exit 1
fi

for pattern in 'bump' 'Counter_add' 'identity_i32' 'GLOBAL_COUNTER' 'wrapped.item'; do
    if ! grep -Fq "$pattern" "$TMP_DIR/main.c"; then
        echo "错误: strict typed backend 覆盖样例缺少 C99 证据: $pattern" >&2
        exit 1
    fi
done

echo "✓ TypedProgram backend contract verified"
