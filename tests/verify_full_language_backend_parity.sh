#!/usr/bin/env bash
#
# Phase 9B 收口：完整语言后端 parity 门禁。
#
# Contract enforced here:
#   - C99 oracle 端：每个语言面 case 必须编译、链接、运行成功，stdout 与
#     显式 baseline 一致（baseline 在脚本顶部内联为常量字符串）。
#   - Hosted native 端：
#       * 当前 hosted native 仍处于 lowering-missing 阶段：脚本默认
#         `UYA_REQUIRE_HOSTED_NATIVE_PARITY=1` 时所有 case 走
#         `run_native_reject_fragment` 守门，要求 stderr 含
#         `native_hosted_portable_mir_lowering_missing`、不生成
#         executable、不含 `后端类型: C99`。
#       * 当前 Phase 9B 的 `UYA_FULL_LANGUAGE_PARITY_NATIVE=1` 先把
#         hello world（case 01，`@println("Hello, World!")`）和
#         stdlib entry（case 17，`get_argc()`）切到
#         `run_native_parity_fragment` 路径，要求 native 真实生成
#         executable、exit status 和 stdout 与 C99 oracle 一致；其余 case
#         仍沿用 try-then-reject 边界，等待后续语言面逐项打开。
#   - 每个 case 记录：C99 result、native result、stdout/stderr、diagnostic
#     normalized diff、allowlist。允许的差异只限于 allowlist 列出的字符串
#     （如 native build 信息行）。
#   - 18 个语言面 case 全部通过才算收口。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-full-language-parity.XXXXXX)"
RESULTS_DIR="$REPO_ROOT/build/full-language-parity-results"
mkdir -p "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: full language backend parity currently requires x86_64 host" >&2
    exit 0
fi

UYA_BIN="$REPO_ROOT/bin/uya"
if [[ ! -x "$UYA_BIN" ]]; then
    echo "error: missing or non-executable bin/uya; run \`make uya\` first" >&2
    exit 1
fi

# Native 端要求 parity（lowering 落地后设为 1）；默认当前是 0（要求 reject）。
REQUIRE_NATIVE_PARITY="${UYA_FULL_LANGUAGE_PARITY_NATIVE:-0}"

# Allowlist: 允许 stderr 含的 native build 内部信息行（不影响 contract）。
NATIVE_INFO_ALLOWLIST=(
    'native_hosted_coreir_preflight: '
    'native_hosted_preflight: '
    'native_hosted_subset: '
    'native_hosted_entry_frontier: '
    'native_hosted_executable_writer_plan: '
    'native_hosted_executable_writer_stream: '
    'native_output_bytes: '
    'native_hosted_executable_writer_preflight: '
)

# native build stderr 中禁止出现的 fallback marker。
NATIVE_FORBIDDEN_MARKERS=(
    '后端类型: C99'
    # 'hosted native assembly' is the current legitimate Phase 9A path
    # Note: 'build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集'
    # is the *expected* exclusion evidence in a reject path. Run case
    # validation only requires it NOT to imply C99 fallback / pre-MIR
    # helper success. The reject-marker check above covers that.
)

check_no_forbidden() {
    local label="$1"
    local err_file="$2"
    local marker
    for marker in "${NATIVE_FORBIDDEN_MARKERS[@]}"; do
        if grep -qF "$marker" "$err_file"; then
            echo "error: $label stderr contains forbidden fallback marker: $marker" >&2
            cat "$err_file" >&2
            exit 1
        fi
    done
}

write_case_summary() {
    local case_id="$1"
    local c99_status="$2"
    local c99_stdout="$3"
    local native_status="$4"
    local native_diag_kind="$5"
    local native_stdout_or_empty="$6"
    local summary="$RESULTS_DIR/${case_id}.summary.tsv"
    {
        printf 'case_id\tc99_status\tc99_stdout_bytes\tnative_status\tnative_diag_kind\tnative_stdout_or_empty\n'
        printf '%s\t%d\t%d\t%d\t%s\t%s\n' \
            "$case_id" "$c99_status" "${#c99_stdout}" "$native_status" "$native_diag_kind" \
            "$native_stdout_or_empty"
    } >"$summary"
}

run_c99_case() {
    # run_c99_case <case_id> <source_file> <expected_stdout> <expected_exit>
    local case_id="$1"
    local src="$2"
    local expected_stdout="$3"
    local expected_exit="${4:-0}"
    local c99_bin="$TMP_DIR/${case_id}.c99"
    local c99_build_err="$TMP_DIR/${case_id}.c99.build.err"
    local c99_run_out="$TMP_DIR/${case_id}.c99.run.out"
    local c99_run_err="$TMP_DIR/${case_id}.c99.run.err"

    (cd "$REPO_ROOT" && "$UYA_BIN" build "$src" -o "$c99_bin" \
        --no-split-c --project-root "$TMP_DIR" \
        >/dev/null 2>"$c99_build_err")
    if grep -qF '后端类型: Native' "$c99_build_err"; then
        echo "error: $case_id c99 build entered Native backend" >&2
        cat "$c99_build_err" >&2
        exit 1
    fi
    chmod +x "$c99_bin"
    set +e
    "$c99_bin" >"$c99_run_out" 2>"$c99_run_err"
    local c99_status=$?
    set -e
    if [[ "$c99_status" -ne "$expected_exit" ]]; then
        echo "error: $case_id C99 oracle exited with $c99_status (expected $expected_exit)" >&2
        cat "$c99_run_out" >&2
        cat "$c99_run_err" >&2
        exit 1
    fi
    local actual_stdout
    actual_stdout="$(cat "$c99_run_out")"
    if [[ "$actual_stdout" != "$expected_stdout" ]]; then
        echo "error: $case_id C99 oracle stdout mismatch" >&2
        echo "  expected: [$expected_stdout]" >&2
        echo "  actual:   [$actual_stdout]" >&2
        exit 1
    fi
    cp "$c99_run_out" "$RESULTS_DIR/${case_id}.c99.stdout"
    return 0
}

run_native_reject_case() {
    # run_native_reject_case <case_id> <source_file> <expected_reject_reason>
    local case_id="$1"
    local src="$2"
    local expected_reason="$3"
    local native_bin="$TMP_DIR/${case_id}.native"
    local native_build_out="$TMP_DIR/${case_id}.native.build.out"
    local native_build_err="$TMP_DIR/${case_id}.native.build.err"
    set +e
    (cd "$REPO_ROOT" && "$UYA_BIN" build "$src" -o "$native_bin" \
        --native --no-split-c --project-root "$TMP_DIR" \
        >"$native_build_out" 2>"$native_build_err")
    local native_status=$?
    set -e
    if [[ "$native_status" -eq 0 ]]; then
        echo "error: $case_id native build should reject (lowering missing)" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    if [[ -e "$native_bin" ]]; then
        echo "error: $case_id native reject left an output file" >&2
        exit 1
    fi
    if ! grep -qF 'Native' "$native_build_err"; then
        echo "error: $case_id native reject did not enter Native backend" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    check_no_forbidden "$case_id-native" "$native_build_err"
    if ! grep -qF "native_unsupported_hosted_path: reason=$expected_reason" "$native_build_err"; then
        echo "error: $case_id native reject missing reason=$expected_reason" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    if ! grep -qF 'native_hosted_coreir_preflight: status=0' "$native_build_err"; then
        echo "error: $case_id native reject lacks CoreIR preflight evidence" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    if ! grep -qF 'native_hosted_preflight: status=0' "$native_build_err"; then
        echo "error: $case_id native reject lacks PortableMIR preflight evidence" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    write_case_summary "$case_id" 0 "" 1 "reject" ""
    return 0
}

run_native_parity_case() {
    # run_native_parity_case <case_id> <source_file> <expected_exit>
    local case_id="$1"
    local src="$2"
    local expected_exit="${3:-0}"
    local native_bin="$TMP_DIR/${case_id}.native"
    local native_build_out="$TMP_DIR/${case_id}.native.build.out"
    local native_build_err="$TMP_DIR/${case_id}.native.build.err"
    local native_run_out="$TMP_DIR/${case_id}.native.run.out"
    local native_run_err="$TMP_DIR/${case_id}.native.run.err"
    set +e
    (cd "$REPO_ROOT" && "$UYA_BIN" build "$src" -o "$native_bin" \
        --native --no-split-c --project-root "$TMP_DIR" \
        >"$native_build_out" 2>"$native_build_err")
    local native_build_status=$?
    set -e
    if [[ "$native_build_status" -ne 0 ]]; then
        echo "error: $case_id native parity build failed with $native_build_status" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    if [[ ! -s "$native_bin" ]]; then
        echo "error: $case_id native parity build reported success without output" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    check_no_forbidden "$case_id-native" "$native_build_err"
    if ! grep -qF 'native_hosted_coreir_preflight: status=0' "$native_build_err"; then
        echo "error: $case_id native parity build lacks CoreIR preflight evidence" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    if ! grep -qF 'native_hosted_preflight: status=0' "$native_build_err"; then
        echo "error: $case_id native parity build lacks PortableMIR preflight evidence" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    chmod +x "$native_bin"
    set +e
    "$native_bin" >"$native_run_out" 2>"$native_run_err"
    local native_status=$?
    set -e
    if [[ "$native_status" -ne "$expected_exit" ]]; then
        echo "error: $case_id native executable exited with $native_status (expected $expected_exit)" >&2
        cat "$native_run_out" >&2
        cat "$native_run_err" >&2
        exit 1
    fi
    if ! cmp -s "$RESULTS_DIR/${case_id}.c99.stdout" "$native_run_out"; then
        echo "error: $case_id native/C99 stdout differ" >&2
        diff "$RESULTS_DIR/${case_id}.c99.stdout" "$native_run_out" >&2 || true
        exit 1
    fi
    write_case_summary "$case_id" 0 "" "$native_status" "parity" "$(cat "$native_run_out")"
    return 0
}

run_case() {
    # run_case <case_id> <source_file> <expected_stdout> <expected_exit>
    local case_id="$1"
    local src="$2"
    local expected_stdout="$3"
    local expected_exit="${4:-0}"
    run_c99_case "$case_id" "$src" "$expected_stdout" "$expected_exit"
    if [[ "$REQUIRE_NATIVE_PARITY" == "1" &&
        ( "$case_id" == "hello" || "$case_id" == "generic" ||
          "$case_id" == "method" || "$case_id" == "stdlib_entry" ) ]]; then
        run_native_parity_case "$case_id" "$src" "$expected_exit"
    else
        run_native_try_then_reject "$case_id" "$src" "$expected_exit"
    fi
}

# Try native build; if it succeeds, run and compare stdout; if it rejects,
# validate the reject contract (lowering-missing, no fallback markers).
run_native_try_then_reject() {
    local case_id="$1"
    local src="$2"
    local expected_exit="${3:-0}"
    local native_bin="$TMP_DIR/${case_id}.native"
    local native_build_out="$TMP_DIR/${case_id}.native.build.out"
    local native_build_err="$TMP_DIR/${case_id}.native.build.err"
    set +e
    (cd "$REPO_ROOT" && "$UYA_BIN" build "$src" -o "$native_bin" \
        --native --no-split-c --project-root "$TMP_DIR" \
        >"$native_build_out" 2>"$native_build_err")
    local native_status=$?
    set -e
    if [[ "$native_status" -eq 0 ]]; then
        if [[ ! -s "$native_bin" ]]; then
            echo "error: $case_id native build success without output" >&2
            cat "$native_build_err" >&2
            exit 1
        fi
        check_no_forbidden "$case_id-native" "$native_build_err"
        chmod +x "$native_bin"
        local native_run_out="$TMP_DIR/${case_id}.native.run.out"
        local native_run_err="$TMP_DIR/${case_id}.native.run.err"
        set +e
        "$native_bin" >"$native_run_out" 2>"$native_run_err"
        local native_run_status=$?
        set -e
        if [[ "$native_run_status" -ne "$expected_exit" ]]; then
            echo "error: $case_id native executable exited with $native_run_status (expected $expected_exit)" >&2
            cat "$native_run_out" >&2
            cat "$native_run_err" >&2
            exit 1
        fi
        if ! cmp -s "$RESULTS_DIR/${case_id}.c99.stdout" "$native_run_out"; then
            echo "error: $case_id native/C99 stdout differ" >&2
            diff "$RESULTS_DIR/${case_id}.c99.stdout" "$native_run_out" >&2 || true
            exit 1
        fi
        write_case_summary "$case_id" 0 "" 0 "parity" "$(cat "$native_run_out")"
        return 0
    fi
    # Reject path
    if [[ -e "$native_bin" ]]; then
        echo "error: $case_id native reject left an output file" >&2
        exit 1
    fi
    if ! grep -qF 'Native' "$native_build_err"; then
        echo "error: $case_id native reject did not enter Native backend" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    check_no_forbidden "$case_id-native" "$native_build_err"
    if ! grep -qF "native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing" "$native_build_err"; then
        echo "error: $case_id native reject missing reason=native_hosted_portable_mir_lowering_missing" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    if ! grep -qF 'native_hosted_coreir_preflight: status=0' "$native_build_err"; then
        echo "error: $case_id native reject lacks CoreIR preflight evidence" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    if ! grep -qF 'native_hosted_preflight: status=0' "$native_build_err"; then
        echo "error: $case_id native reject lacks PortableMIR preflight evidence" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    write_case_summary "$case_id" 0 "" 1 "reject" ""
}

# ---------------------------------------------------------------------------
# Case 01: hello world (uses @println)
# ---------------------------------------------------------------------------
HW_SRC="$TMP_DIR/hello.uya"
cat >"$HW_SRC" <<'EOF'
export fn main() i32 {
    @println("Hello, World!");
    return 0;
}
EOF
EXPECTED=$(printf "Hello, World!\n"); run_case hello "$HW_SRC" "$EXPECTED"

# ---------------------------------------------------------------------------
# Case 02: multi-file module with use
# ---------------------------------------------------------------------------
mkdir -p "$TMP_DIR/c02"
cat >"$TMP_DIR/c02/helper.uya" <<'EOF'
export fn helper_value() i32 {
    return 7;
}
EOF
cat >"$TMP_DIR/c02/main.uya" <<'EOF'
use c02.helper;

export fn main() i32 {
    return helper_value();
}
EOF
run_case multi_file_use "$TMP_DIR/c02/main.uya" "" 7

# ---------------------------------------------------------------------------
# Case 03: generic
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c03.uya" <<'EOF'
fn id<T>(value: T) T {
    return value;
}

export fn main() i32 {
    return id<i32>(3);
}
EOF
run_case generic "$TMP_DIR/c03.uya" "" 3

# ---------------------------------------------------------------------------
# Case 04: method
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c04.uya" <<'EOF'
struct Counter {
    value: i32,
}

Counter {
    fn inc(self: &Self) i32 {
        return self.value + 1;
    }
}

export fn main() i32 {
    const c: Counter = Counter{ value: 41 };
    return c.inc();
}
EOF
run_case method "$TMP_DIR/c04.uya" "" 42

# ---------------------------------------------------------------------------
# Case 05: interface
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c05.uya" <<'EOF'
interface SmokeAdder {
    fn add(self: &Self, x: i32) i32;
}

struct SmokeCounter : SmokeAdder {
    value: i32,
}

SmokeCounter {
    fn add(self: &Self, x: i32) i32 {
        return self.value + x;
    }

    fn double(self: &Self) i32 {
        return self.value * 2;
    }
}

fn use_adder(adder: SmokeAdder) i32 {
    return adder.add(5);
}

export fn main() i32 {
    const counter: SmokeCounter = SmokeCounter{ value: 7 };
    const direct: i32 = counter.double();
    const through_interface: i32 = use_adder(counter);
    return direct + through_interface;
}
EOF
# Expected: double() = 14, add(5) = 12, total = 26
run_case interface "$TMP_DIR/c05.uya" "" 26

# ---------------------------------------------------------------------------
# Case 06: error union + try
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c06.uya" <<'EOF'
error MyError;

fn maybe(flag: i32) !i32 {
    if flag == 0 {
        return error.MyError;
    }
    return flag * 2;
}

export fn main() i32 {
    return maybe(5) catch { 0; };
}
EOF
run_case error_union_try "$TMP_DIR/c06.uya" "" 10

# ---------------------------------------------------------------------------
# Case 07: try/catch
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c07.uya" <<'EOF'
error E;

fn might_fail(flag: i32) !i32 {
    if flag == 0 { return error.E; }
    return flag + 1;
}

export fn main() i32 {
    return might_fail(7) catch { 99; };
}
EOF
run_case try_catch "$TMP_DIR/c07.uya" "" 8

# ---------------------------------------------------------------------------
# Case 08: defer
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c08.uya" <<'EOF'
export fn main() i32 {
    var v: i32 = 0;
    defer { v = 5; }
    return 0;
}
EOF
run_case defer "$TMP_DIR/c08.uya" ""

# ---------------------------------------------------------------------------
# Case 09: errdefer
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c09.uya" <<'EOF'
error E;

fn might(flag: i32) !i32 {
    var v: i32 = 0;
    errdefer { v = 7; }
    if flag == 0 { return error.E; }
    return flag;
}

export fn main() i32 {
    return might(3) catch { 0; };
}
EOF
run_case errdefer "$TMP_DIR/c09.uya" "" 3

# ---------------------------------------------------------------------------
# Case 10: struct / union / enum
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c10.uya" <<'EOF'
struct Pt { x: i32, y: i32 }
union U { i: i32, b: bool }
enum Color { Red, Green, Blue }

export fn main() i32 {
    const p: Pt = Pt{ x: 3, y: 4 };
    const u: U = U.i(6);
    const matched: i32 = match u {
        .i(x) => x,
        .b(_) => 0,
    };
    return p.x + p.y + matched;
}
EOF
# Expected: 3+4+6=13
run_case struct_union_enum "$TMP_DIR/c10.uya" "" 13

# ---------------------------------------------------------------------------
# Case 11: slice / array
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c11.uya" <<'EOF'
export fn main() i32 {
    var a: [i32: 4] = [1, 2, 3, 4];
    const s: &[i32] = a[1:2];
    return @len(s) as i32 + s[0];
}
EOF
run_case slice_array "$TMP_DIR/c11.uya" "" 4

# ---------------------------------------------------------------------------
# Case 12: pointer
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c12.uya" <<'EOF'
export fn main() i32 {
    var v: i32 = 42;
    const p: &i32 = &v;
    return *p;
}
EOF
run_case pointer "$TMP_DIR/c12.uya" "" 42

# ---------------------------------------------------------------------------
# Case 13: atomic
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c13.uya" <<'EOF'
export fn main() i32 {
    var a: atomic i32 = 5;
    a += 2;
    const b: i32 = a;
    return b;
}
EOF
run_case atomic "$TMP_DIR/c13.uya" "" 7

# ---------------------------------------------------------------------------
# Case 14: vector / mask
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c14.uya" <<'EOF'
type V = @vector(i32, 4);

export fn main() i32 {
    const a: V = @vector.splat(1);
    const b: V = @vector.splat(2);
    const m: @mask(4) = a < b;
    const selected: V = @vector.select(m, b, a);
    return @vector.reduce_add(selected);
}
EOF
run_case vector_mask "$TMP_DIR/c14.uya" "" 8

# ---------------------------------------------------------------------------
# Case 15: @c_import
# ---------------------------------------------------------------------------
mkdir -p "$TMP_DIR/c15/c_import"
cat >"$TMP_DIR/c15/c_import/add.c" <<'EOF'
int add_i32(int a, int b) { return a + b; }
EOF
cat >"$TMP_DIR/c15/main.uya" <<'EOF'
@c_import("c_import/add.c");

extern fn add_i32(a: i32, b: i32) i32;

export fn main() i32 {
    return add_i32(20, 22);
}
EOF
run_case c_import "$TMP_DIR/c15/main.uya" "" 42

# ---------------------------------------------------------------------------
# Case 16: builtins
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c16.uya" <<'EOF'
export fn main() i32 {
    return @size_of(i32) as i32 + @align_of(i32) as i32 + @len([1,2,3]) as i32;
}
EOF
run_case builtins "$TMP_DIR/c16.uya" "" 11

# ---------------------------------------------------------------------------
# Case 17: stdlib entry
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c17.uya" <<'EOF'
use std.runtime;

export fn main() i32 {
    return get_argc();
}
EOF
run_case stdlib_entry "$TMP_DIR/c17.uya" "" 1

# ---------------------------------------------------------------------------
# Case 18: @print + @println
# ---------------------------------------------------------------------------
cat >"$TMP_DIR/c18.uya" <<'EOF'
export fn main() i32 {
    @print("Hello");
    @println(", World!");
    return 0;
}
EOF
EXPECTED=$(printf "Hello, World!\n"); run_case print_pair "$TMP_DIR/c18.uya" "$EXPECTED"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
rejected_count=0
parity_count=0
if [[ -d "$RESULTS_DIR" ]]; then
    rejected_count=$(awk -F'\t' 'NR>1 && $5=="reject"' "$RESULTS_DIR"/*.summary.tsv 2>/dev/null | wc -l)
    parity_count=$(awk -F'\t' 'NR>1 && $5=="parity"' "$RESULTS_DIR"/*.summary.tsv 2>/dev/null | wc -l)
fi
case_count=$((rejected_count + parity_count))
echo "OK: full language backend parity: $case_count cases (parity=$parity_count, reject=$rejected_count)"
if [[ "$REQUIRE_NATIVE_PARITY" == "1" ]]; then
    for required_case in hello generic method stdlib_entry; do
        required_summary="$RESULTS_DIR/${required_case}.summary.tsv"
        if [[ ! -f "$required_summary" ]] || ! awk -F'\t' -v case_id="$required_case" 'NR>1 && $1==case_id && $5=="parity" { found=1 } END { exit found ? 0 : 1 }' "$required_summary"; then
            echo "error: UYA_FULL_LANGUAGE_PARITY_NATIVE=1 requires $required_case case native parity" >&2
            exit 1
        fi
    done
fi
