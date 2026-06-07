#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-full-language.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/c_import"
cp "$REPO_ROOT/tests/fixtures/c_import/add_impl.c" "$TMP_DIR/c_import/add_impl.c"

helper_src="$TMP_DIR/smoke_helper.uya"
extern_src="$TMP_DIR/extern_fragment.uya"
builtin_src="$TMP_DIR/builtin_fragment.uya"
main_src="$TMP_DIR/main.uya"
extern_c99_bin="$TMP_DIR/c99-extern-smoke"
extern_native_bin="$TMP_DIR/native-extern-smoke"
builtin_c99_bin="$TMP_DIR/c99-builtin-smoke"
builtin_native_bin="$TMP_DIR/native-builtin-smoke"
c99_bin="$TMP_DIR/c99-smoke"
native_bin="$TMP_DIR/native-smoke"
require_parity="${UYA_REQUIRE_HOSTED_NATIVE_PARITY:-0}"

cat >"$helper_src" <<'EOF'
export fn helper_value() i32 {
    return 3;
}

export fn helper_passthrough() i32 {
    return helper_value();
}

export fn helper_identity<T>(value: T) T {
    return value;
}
EOF

cat >"$extern_src" <<'EOF'
@c_import("c_import/add_impl.c");

extern fn add_i32(a: i32, b: i32) i32;

export fn main() i32 {
    return add_i32(20, 22);
}
EOF

cat >"$builtin_src" <<'EOF'
fn size_i32() i32 {
    return @size_of(i32) as i32;
}

fn align_i32() i32 {
    return @align_of(i32) as i32;
}

export fn main() i32 {
    return size_i32() + align_i32();
}
EOF

cat >"$main_src" <<'EOF'
use smoke_helper;

error SmokeError;

enum SmokeColor {
    Red,
    Green,
    Blue,
}

union SmokeUnion {
    i: i32,
    b: bool,
}

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

struct SmokeDrop {
    value: i32,
    fn drop(self: SmokeDrop) void {
        smoke_drop_count = smoke_drop_count + self.value;
    }
}

var smoke_drop_count: i32 = 0;

fn use_adder(adder: SmokeAdder) i32 {
    return adder.add(5);
}

fn maybe_value(flag: i32) !i32 {
    if flag == 0 {
        return error.SmokeError;
    }
    return flag + 10;
}

fn defer_value() i32 {
    var value: i32 = 1;
    defer { value = 9; }
    return value;
}

fn smoke_noop() void {
    return;
}

type SmokeVec = @vector(i32, 4);

export fn main() i32 {
    const from_helper: i32 = helper_value();
    const call_return: i32 = helper_passthrough();
    if from_helper != 3 { return 1; }
    const generic_value: i32 = helper_identity<i32>(4);
    const counter: SmokeCounter = SmokeCounter{ value: 7 };
    const method_value: i32 = counter.double();
    const interface_value: i32 = use_adder(counter);
    const color: SmokeColor = SmokeColor.Green;
    const union_value: SmokeUnion = SmokeUnion.i(6);
    const matched: i32 = match union_value {
        .i(x) => x,
        .b(_) => 0,
    };
    var array: [i32: 4] = [1, 2, 3, 4];
    const slice: &[i32] = array[1:2];
    var atomic_value: atomic i32 = 5;
    atomic_value += 2;
    const atomic_read: i32 = atomic_value;
    const vec_a: SmokeVec = @vector.splat(1);
    const vec_b: SmokeVec = @vector.splat(2);
    const mask: @mask(4) = vec_a < vec_b;
    const selected: SmokeVec = @vector.select(mask, vec_b, vec_a);
    const recovered: i32 = maybe_value(5) catch { 0; };
    const failed: i32 = maybe_value(0) catch { 8; };
    smoke_noop();
    smoke_drop_count = 0;
    {
        const dropped: SmokeDrop = SmokeDrop{ value: 11 };
    }
    if generic_value != 4 { return 2; }
    if method_value != 14 { return 4; }
    if interface_value != 12 { return 5; }
    if color != SmokeColor.Green { return 6; }
    if matched != 6 { return 7; }
    if @len(slice) != 2 { return 8; }
    if slice[0] != 2 || slice[1] != 3 { return 9; }
    if @size_of(SmokeCounter) < 4usize { return 10; }
    if @align_of(SmokeCounter) < 4usize { return 11; }
    if atomic_read != 7 { return 12; }
    if @vector.all(selected == vec_b) == false { return 13; }
    if recovered != 15 { return 14; }
    if failed != 8 { return 15; }
    if defer_value() != 1 { return 16; }
    if smoke_drop_count != 11 { return 17; }
    if @error_id(error.SmokeError) == 0 { return 18; }
    if call_return != 3 { return 19; }
    return 0;
}
EOF

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: full-language smoke fixture missing $description" >&2
        exit 1
    fi
}

require_pattern "$extern_src" '@c_import' "@c_import parity coverage"
require_pattern "$extern_src" 'extern fn add_i32' "extern parity coverage"
require_pattern "$extern_src" 'return add_i32\(20, 22\);' "extern call parity coverage"
require_pattern "$builtin_src" '@size_of\(i32\)' "builtin @size_of parity coverage"
require_pattern "$builtin_src" '@align_of\(i32\)' "builtin @align_of parity coverage"
require_pattern "$main_src" 'use smoke_helper' "multi-file coverage"
require_pattern "$helper_src" 'helper_identity<T>' "generic helper coverage"
require_pattern "$main_src" 'helper_identity<i32>' "generic instantiation coverage"
require_pattern "$main_src" 'fn double\(self: &Self\)' "method coverage"
require_pattern "$main_src" 'interface SmokeAdder' "interface coverage"
require_pattern "$main_src" 'fn maybe_value\(flag: i32\) !i32' "error-union coverage"
require_pattern "$main_src" 'defer \{' "defer coverage"
require_pattern "$main_src" 'fn smoke_noop\(\) void' "void CoreBody coverage"
require_pattern "$helper_src" 'return 3;' "integer literal CoreBody coverage"
require_pattern "$helper_src" 'return helper_value\(\);' "call-return CoreBody coverage"
require_pattern "$main_src" 'fn drop\(self: SmokeDrop\)' "drop coverage"
require_pattern "$main_src" 'const slice: &\[i32\]' "slice coverage"
require_pattern "$main_src" 'var array: \[i32: 4\]' "array coverage"
require_pattern "$main_src" 'struct SmokeCounter' "struct coverage"
require_pattern "$main_src" 'union SmokeUnion' "union coverage"
require_pattern "$main_src" 'enum SmokeColor' "enum coverage"
require_pattern "$main_src" 'atomic i32' "atomic coverage"
require_pattern "$main_src" '@vector\(i32, 4\)' "SIMD vector coverage"
require_pattern "$main_src" '@mask\(4\)' "SIMD mask coverage"
require_pattern "$main_src" '@len\(slice\)' "builtin @len coverage"
require_pattern "$main_src" '@size_of\(SmokeCounter\)' "builtin @size_of coverage"
require_pattern "$main_src" '@align_of\(SmokeCounter\)' "builtin @align_of coverage"
require_pattern "$main_src" '@error_id\(error.SmokeError\)' "builtin @error_id coverage"

extern_c99_build_out="$TMP_DIR/extern.c99.build.out"
extern_c99_build_err="$TMP_DIR/extern.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$extern_src" -o "$extern_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$extern_c99_build_out" 2>"$extern_c99_build_err"); then
    cat "$extern_c99_build_out" >&2
    cat "$extern_c99_build_err" >&2
    exit 1
fi

set +e
"$extern_c99_bin" >"$TMP_DIR/extern.c99.run.out" 2>"$TMP_DIR/extern.c99.run.err"
extern_c99_status=$?
set -e
if [[ "$extern_c99_status" -ne 42 ]]; then
    echo "error: C99 extern/@c_import parity fragment exited with $extern_c99_status" >&2
    cat "$TMP_DIR/extern.c99.run.out" >&2
    cat "$TMP_DIR/extern.c99.run.err" >&2
    exit 1
fi

extern_native_build_out="$TMP_DIR/extern.native.build.out"
extern_native_build_err="$TMP_DIR/extern.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$extern_src" -o "$extern_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$extern_native_build_out" 2>"$extern_native_build_err"); then
    cat "$extern_native_build_out" >&2
    cat "$extern_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$extern_native_bin" ]]; then
    echo "error: native extern/@c_import parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$extern_native_build_err"; then
    echo "error: native extern/@c_import parity fragment appears to have fallen back to C99" >&2
    cat "$extern_native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[1-9][0-9]* core_bodies=1 pending_bodies=[0-9]+' "$extern_native_build_err"; then
    echo "error: native extern/@c_import parity fragment lacks CoreIR body preflight evidence" >&2
    cat "$extern_native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[1-9][0-9]* mir_body_functions=1 mir_types=[1-9][0-9]* extern_symbols=[1-9][0-9]* c_import_objects=1 hosted_link_objects=1' "$extern_native_build_err"; then
    echo "error: native extern/@c_import parity fragment lacks PortableMIR/link preflight evidence" >&2
    cat "$extern_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_linker_handoff: extern=add_i32 c_import_objects=1 linked_objects=2' "$extern_native_build_err"; then
    echo "error: native extern/@c_import parity fragment lacks linker handoff evidence" >&2
    cat "$extern_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: c_import_extern_link_path=1' "$extern_native_build_err"; then
    echo "error: native extern/@c_import parity fragment lacks hosted native subset evidence" >&2
    cat "$extern_native_build_err" >&2
    exit 1
fi

chmod +x "$extern_native_bin"
set +e
"$extern_native_bin" >"$TMP_DIR/extern.native.run.out" 2>"$TMP_DIR/extern.native.run.err"
extern_native_status=$?
set -e
if [[ "$extern_native_status" -ne "$extern_c99_status" ]]; then
    echo "error: hosted native/C99 extern parity exit status differs: c99=$extern_c99_status native=$extern_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/extern.c99.run.out" "$TMP_DIR/extern.native.run.out"; then
    echo "error: hosted native/C99 extern parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/extern.c99.run.err" "$TMP_DIR/extern.native.run.err"; then
    echo "error: hosted native/C99 extern parity stderr differs" >&2
    exit 1
fi

builtin_c99_build_out="$TMP_DIR/builtin.c99.build.out"
builtin_c99_build_err="$TMP_DIR/builtin.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$builtin_src" -o "$builtin_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$builtin_c99_build_out" 2>"$builtin_c99_build_err"); then
    cat "$builtin_c99_build_out" >&2
    cat "$builtin_c99_build_err" >&2
    exit 1
fi

set +e
"$builtin_c99_bin" >"$TMP_DIR/builtin.c99.run.out" 2>"$TMP_DIR/builtin.c99.run.err"
builtin_c99_status=$?
set -e
if [[ "$builtin_c99_status" -ne 8 ]]; then
    echo "error: C99 builtin parity fragment exited with $builtin_c99_status" >&2
    cat "$TMP_DIR/builtin.c99.run.out" >&2
    cat "$TMP_DIR/builtin.c99.run.err" >&2
    exit 1
fi

builtin_native_build_out="$TMP_DIR/builtin.native.build.out"
builtin_native_build_err="$TMP_DIR/builtin.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$builtin_src" -o "$builtin_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$builtin_native_build_out" 2>"$builtin_native_build_err"); then
    cat "$builtin_native_build_out" >&2
    cat "$builtin_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$builtin_native_bin" ]]; then
    echo "error: native builtin parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$builtin_native_build_err"; then
    echo "error: native builtin parity fragment appears to have fallen back to C99" >&2
    cat "$builtin_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$builtin_native_build_err"; then
    echo "error: native builtin parity fragment used reject path" >&2
    cat "$builtin_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$builtin_native_build_err"; then
    echo "error: native builtin parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$builtin_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$builtin_native_build_err"

chmod +x "$builtin_native_bin"
set +e
"$builtin_native_bin" >"$TMP_DIR/builtin.native.run.out" 2>"$TMP_DIR/builtin.native.run.err"
builtin_native_status=$?
set -e
if [[ "$builtin_native_status" -ne "$builtin_c99_status" ]]; then
    echo "error: hosted native/C99 builtin parity exit status differs: c99=$builtin_c99_status native=$builtin_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/builtin.c99.run.out" "$TMP_DIR/builtin.native.run.out"; then
    echo "error: hosted native/C99 builtin parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/builtin.c99.run.err" "$TMP_DIR/builtin.native.run.err"; then
    echo "error: hosted native/C99 builtin parity stderr differs" >&2
    exit 1
fi

c99_build_out="$TMP_DIR/c99.build.out"
c99_build_err="$TMP_DIR/c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$main_src" -o "$c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$c99_build_out" 2>"$c99_build_err"); then
    cat "$c99_build_out" >&2
    cat "$c99_build_err" >&2
    exit 1
fi

set +e
"$c99_bin" >"$TMP_DIR/c99.run.out" 2>"$TMP_DIR/c99.run.err"
c99_status=$?
set -e
if [[ "$c99_status" -ne 0 ]]; then
    echo "error: C99 full-language smoke exited with $c99_status" >&2
    cat "$TMP_DIR/c99.run.out" >&2
    cat "$TMP_DIR/c99.run.err" >&2
    exit 1
fi

native_build_out="$TMP_DIR/native.build.out"
native_build_err="$TMP_DIR/native.build.err"
set +e
(cd "$REPO_ROOT" && ./bin/uya build "$main_src" -o "$native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$native_build_out" 2>"$native_build_err")
native_build_status=$?
set -e

if [[ "$native_build_status" -eq 0 ]]; then
    if [[ ! -s "$native_bin" ]]; then
        echo "error: native full-language smoke reported success without output" >&2
        exit 1
    fi
    if grep -q 'C99' "$native_build_err"; then
        echo "error: native full-language smoke appears to have fallen back to C99" >&2
        cat "$native_build_err" >&2
        exit 1
    fi
    chmod +x "$native_bin"
    set +e
    "$native_bin" >"$TMP_DIR/native.run.out" 2>"$TMP_DIR/native.run.err"
    native_status=$?
    set -e
    if [[ "$native_status" -ne "$c99_status" ]]; then
        echo "error: hosted native/C99 exit status differs: c99=$c99_status native=$native_status" >&2
        exit 1
    fi
    if ! cmp -s "$TMP_DIR/c99.run.out" "$TMP_DIR/native.run.out"; then
        echo "error: hosted native/C99 stdout differs" >&2
        exit 1
    fi
    if ! cmp -s "$TMP_DIR/c99.run.err" "$TMP_DIR/native.run.err"; then
        echo "error: hosted native/C99 stderr differs" >&2
        exit 1
    fi
    echo "OK: hosted native full-language smoke matches C99"
    exit 0
fi

if [[ "$require_parity" != "0" ]]; then
    echo "error: hosted native full-language parity required but native build rejected" >&2
    echo "c99_build_status=0 c99_run_status=$c99_status native_build_status=$native_build_status" >&2
    cat "$native_build_err" >&2
    exit 1
fi

if [[ -e "$native_bin" ]]; then
    echo "error: native full-language reject left an output file" >&2
    exit 1
fi
if ! grep -q 'Native' "$native_build_err"; then
    echo "error: native full-language reject did not enter Native backend" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if grep -q 'C99' "$native_build_err"; then
    echo "error: native full-language reject fell back to C99" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[1-9][0-9]* core_bodies=4 pending_bodies=10' "$native_build_err"; then
    echo "error: native full-language reject lacks hosted CoreIR void/int-literal/call-return/main-prefix body preflight evidence" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[0-9]+ mir_body_functions=4 mir_types=[1-9][0-9]* extern_symbols=[0-9]+ c_import_objects=0 hosted_link_objects=0' "$native_build_err"; then
    echo "error: native full-language reject lacks hosted PortableMIR preflight evidence" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' "$native_build_err"; then
    echo "error: native full-language reject lacks function-body MIR lowering gap" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -q 'PortableMIR/NativeHostedLinkPlan preflight' "$native_build_err"; then
    echo "error: native full-language reject lacks hosted native preflight summary" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -q 'build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集' "$native_build_err"; then
    echo "error: native full-language reject did not exclude build-seed helper" >&2
    cat "$native_build_err" >&2
    exit 1
fi

echo "OK: hosted native full-language smoke covered extern/@c_import parity, builtin parity, C99 success, and explicit native reject"
