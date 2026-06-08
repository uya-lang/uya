#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DRIVER_FILE="$REPO_ROOT/src/build_compiler_driver.uya"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-full-language.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/c_import"
cp "$REPO_ROOT/tests/fixtures/c_import/add_impl.c" "$TMP_DIR/c_import/add_impl.c"

helper_src="$TMP_DIR/smoke_helper.uya"
extern_src="$TMP_DIR/extern_fragment.uya"
builtin_src="$TMP_DIR/builtin_fragment.uya"
array_len_src="$TMP_DIR/array_len_fragment.uya"
array_index_src="$TMP_DIR/array_index_fragment.uya"
slice_src="$TMP_DIR/slice_fragment.uya"
error_id_src="$TMP_DIR/error_id_fragment.uya"
catch_src="$TMP_DIR/catch_fragment.uya"
dynamic_catch_src="$TMP_DIR/dynamic_catch_fragment.uya"
defer_src="$TMP_DIR/defer_fragment.uya"
drop_src="$TMP_DIR/drop_fragment.uya"
interface_src="$TMP_DIR/interface_fragment.uya"
atomic_src="$TMP_DIR/atomic_fragment.uya"
simd_src="$TMP_DIR/simd_fragment.uya"
main_src="$TMP_DIR/main.uya"
extern_c99_bin="$TMP_DIR/c99-extern-smoke"
extern_native_bin="$TMP_DIR/native-extern-smoke"
builtin_c99_bin="$TMP_DIR/c99-builtin-smoke"
builtin_native_bin="$TMP_DIR/native-builtin-smoke"
array_len_c99_bin="$TMP_DIR/c99-array-len-smoke"
array_len_native_bin="$TMP_DIR/native-array-len-smoke"
array_index_c99_bin="$TMP_DIR/c99-array-index-smoke"
array_index_native_bin="$TMP_DIR/native-array-index-smoke"
slice_c99_bin="$TMP_DIR/c99-slice-smoke"
slice_native_bin="$TMP_DIR/native-slice-smoke"
error_id_c99_bin="$TMP_DIR/c99-error-id-smoke"
error_id_native_bin="$TMP_DIR/native-error-id-smoke"
catch_c99_bin="$TMP_DIR/c99-catch-smoke"
catch_native_bin="$TMP_DIR/native-catch-smoke"
dynamic_catch_c99_bin="$TMP_DIR/c99-dynamic-catch-smoke"
dynamic_catch_native_bin="$TMP_DIR/native-dynamic-catch-smoke"
defer_c99_bin="$TMP_DIR/c99-defer-smoke"
defer_native_bin="$TMP_DIR/native-defer-smoke"
drop_c99_bin="$TMP_DIR/c99-drop-smoke"
drop_native_bin="$TMP_DIR/native-drop-smoke"
interface_c99_bin="$TMP_DIR/c99-interface-smoke"
interface_native_bin="$TMP_DIR/native-interface-smoke"
atomic_c99_bin="$TMP_DIR/c99-atomic-smoke"
atomic_native_bin="$TMP_DIR/native-atomic-smoke"
simd_c99_bin="$TMP_DIR/c99-simd-smoke"
simd_native_bin="$TMP_DIR/native-simd-smoke"
c99_bin="$TMP_DIR/c99-smoke"
native_bin="$TMP_DIR/native-smoke"
require_parity="${UYA_REQUIRE_HOSTED_NATIVE_PARITY:-1}"

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

cat >"$array_len_src" <<'EOF'
export fn main() i32 {
    return @len([1, 2, 3, 4]) as i32;
}
EOF

cat >"$array_index_src" <<'EOF'
export fn main() i32 {
    var array: [i32: 4] = [2, 4, 6, 8];
    const idx: i32 = 2;
    return array[idx];
}
EOF

cat >"$slice_src" <<'EOF'
export fn main() i32 {
    var array: [i32: 4] = [1, 2, 3, 4];
    const slice: &[i32] = array[1:2];
    return slice[0] + slice[1];
}
EOF

cat >"$error_id_src" <<'EOF'
error SmokeError;

export fn main() i32 {
    return @error_id(error.SmokeError) as i32;
}
EOF

cat >"$catch_src" <<'EOF'
error SmokeError;

fn maybe_value(flag: i32) !i32 {
    if flag == 0 {
        return error.SmokeError;
    }
    return flag + 10;
}

export fn main() i32 {
    const recovered: i32 = maybe_value(5) catch { 0; };
    const failed: i32 = maybe_value(0) catch { 8; };
    return recovered + failed;
}
EOF

cat >"$dynamic_catch_src" <<'EOF'
use std.runtime.get_argc;

error SmokeError;

fn maybe_value(flag: i32) !i32 {
    if flag == 1 {
        return error.SmokeError;
    }
    return 12;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const recovered: i32 = maybe_value(argc) catch { 8; };
    return recovered;
}
EOF

cat >"$defer_src" <<'EOF'
export fn main() i32 {
    var value: i32 = 1;
    defer { value = 9; }
    return value;
}
EOF

cat >"$drop_src" <<'EOF'
var drop_count: i32 = 0;

struct SmokeDrop {
    value: i32,
    fn drop(self: SmokeDrop) void {
        drop_count = drop_count + self.value;
    }
}

export fn main() i32 {
    drop_count = 0;
    {
        const dropped: SmokeDrop = SmokeDrop{ value: 7 };
    }
    return drop_count;
}
EOF

cat >"$interface_src" <<'EOF'
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

cat >"$atomic_src" <<'EOF'
export fn main() i32 {
    var atomic_value: atomic i32 = 5;
    atomic_value += 2;
    const atomic_read: i32 = atomic_value;
    return atomic_read;
}
EOF

cat >"$simd_src" <<'EOF'
type SmokeVec = @vector(i32, 4);

export fn main() i32 {
    const vec_a: SmokeVec = @vector.splat(1);
    const vec_b: SmokeVec = @vector.splat(2);
    const mask: @mask(4) = vec_a < vec_b;
    const selected: SmokeVec = @vector.select(mask, vec_b, vec_a);
    return @vector.reduce_add(selected);
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

if grep -q 'native_build_hosted_main_local_array_index_return_value' "$BUILD_DRIVER_FILE" ||
   grep -q 'native_build_decl_local_array_index_return_value' "$BUILD_DRIVER_FILE"; then
    echo "error: local array index native shard must not use pre-MIR AST return-value helpers" >&2
    exit 1
fi
require_pattern "$BUILD_DRIVER_FILE" 'native_build_hosted_verified_mir_local_array_index_return_value' \
    "verified PortableMIR local array index return extraction"
require_pattern "$BUILD_DRIVER_FILE" 'MIR_INST_OP_INDEX_ADDR' "MIR index address lowering evidence"
require_pattern "$BUILD_DRIVER_FILE" 'MIR_INST_OP_LOAD' "MIR indexed load lowering evidence"

require_pattern "$extern_src" '@c_import' "@c_import parity coverage"
require_pattern "$extern_src" 'extern fn add_i32' "extern parity coverage"
require_pattern "$extern_src" 'return add_i32\(20, 22\);' "extern call parity coverage"
require_pattern "$builtin_src" '@size_of\(i32\)' "builtin @size_of parity coverage"
require_pattern "$builtin_src" '@align_of\(i32\)' "builtin @align_of parity coverage"
require_pattern "$array_len_src" '@len\(\[1, 2, 3, 4\]\)' "array literal @len parity coverage"
require_pattern "$array_index_src" 'return array\[idx\];' "local array index read parity coverage"
require_pattern "$slice_src" 'array\[1:2\]' "slice construction parity coverage"
require_pattern "$slice_src" 'slice\[0\] \+ slice\[1\]' "slice index parity coverage"
require_pattern "$error_id_src" '@error_id\(error.SmokeError\)' "builtin @error_id parity coverage"
require_pattern "$catch_src" 'maybe_value\(5\) catch \{ 0; \}' "error-union catch success parity coverage"
require_pattern "$catch_src" 'maybe_value\(0\) catch \{ 8; \}' "error-union catch fallback parity coverage"
require_pattern "$dynamic_catch_src" 'get_argc\(\)' "dynamic catch runtime input parity coverage"
require_pattern "$dynamic_catch_src" 'maybe_value\(argc\) catch \{ 8; \}' "dynamic error-union catch parity coverage"
require_pattern "$defer_src" 'defer \{ value = 9; \}' "defer return-order parity coverage"
require_pattern "$drop_src" 'fn drop\(self: SmokeDrop\) void' "lexical drop method parity coverage"
require_pattern "$drop_src" 'const dropped: SmokeDrop = SmokeDrop\{ value: 7 \};' "lexical drop scope parity coverage"
require_pattern "$interface_src" 'interface SmokeAdder' "interface dispatch parity coverage"
require_pattern "$interface_src" 'const through_interface: i32 = use_adder\(counter\);' "method dispatch via interface parity coverage"
require_pattern "$atomic_src" 'var atomic_value: atomic i32 = 5;' "atomic i32 declaration parity coverage"
require_pattern "$atomic_src" 'atomic_value \+= 2;' "atomic i32 compound update parity coverage"
require_pattern "$simd_src" 'const mask: @mask\(4\) = vec_a < vec_b;' "SIMD mask parity coverage"
require_pattern "$simd_src" '@vector.select\(mask, vec_b, vec_a\)' "SIMD vector select parity coverage"
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

array_len_c99_build_out="$TMP_DIR/array-len.c99.build.out"
array_len_c99_build_err="$TMP_DIR/array-len.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$array_len_src" -o "$array_len_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$array_len_c99_build_out" 2>"$array_len_c99_build_err"); then
    cat "$array_len_c99_build_out" >&2
    cat "$array_len_c99_build_err" >&2
    exit 1
fi

set +e
"$array_len_c99_bin" >"$TMP_DIR/array-len.c99.run.out" 2>"$TMP_DIR/array-len.c99.run.err"
array_len_c99_status=$?
set -e
if [[ "$array_len_c99_status" -ne 4 ]]; then
    echo "error: C99 array @len parity fragment exited with $array_len_c99_status" >&2
    cat "$TMP_DIR/array-len.c99.run.out" >&2
    cat "$TMP_DIR/array-len.c99.run.err" >&2
    exit 1
fi

array_len_native_build_out="$TMP_DIR/array-len.native.build.out"
array_len_native_build_err="$TMP_DIR/array-len.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$array_len_src" -o "$array_len_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$array_len_native_build_out" 2>"$array_len_native_build_err"); then
    cat "$array_len_native_build_out" >&2
    cat "$array_len_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$array_len_native_bin" ]]; then
    echo "error: native array @len parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$array_len_native_build_err"; then
    echo "error: native array @len parity fragment appears to have fallen back to C99" >&2
    cat "$array_len_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$array_len_native_build_err"; then
    echo "error: native array @len parity fragment used reject path" >&2
    cat "$array_len_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$array_len_native_build_err"; then
    echo "error: native array @len parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$array_len_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$array_len_native_build_err"

chmod +x "$array_len_native_bin"
set +e
"$array_len_native_bin" >"$TMP_DIR/array-len.native.run.out" 2>"$TMP_DIR/array-len.native.run.err"
array_len_native_status=$?
set -e
if [[ "$array_len_native_status" -ne "$array_len_c99_status" ]]; then
    echo "error: hosted native/C99 array @len parity exit status differs: c99=$array_len_c99_status native=$array_len_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/array-len.c99.run.out" "$TMP_DIR/array-len.native.run.out"; then
    echo "error: hosted native/C99 array @len parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/array-len.c99.run.err" "$TMP_DIR/array-len.native.run.err"; then
    echo "error: hosted native/C99 array @len parity stderr differs" >&2
    exit 1
fi

array_index_c99_build_out="$TMP_DIR/array-index.c99.build.out"
array_index_c99_build_err="$TMP_DIR/array-index.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$array_index_src" -o "$array_index_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$array_index_c99_build_out" 2>"$array_index_c99_build_err"); then
    cat "$array_index_c99_build_out" >&2
    cat "$array_index_c99_build_err" >&2
    exit 1
fi

set +e
"$array_index_c99_bin" >"$TMP_DIR/array-index.c99.run.out" 2>"$TMP_DIR/array-index.c99.run.err"
array_index_c99_status=$?
set -e
if [[ "$array_index_c99_status" -ne 6 ]]; then
    echo "error: C99 local array index parity fragment exited with $array_index_c99_status" >&2
    cat "$TMP_DIR/array-index.c99.run.out" >&2
    cat "$TMP_DIR/array-index.c99.run.err" >&2
    exit 1
fi

array_index_native_build_out="$TMP_DIR/array-index.native.build.out"
array_index_native_build_err="$TMP_DIR/array-index.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$array_index_src" -o "$array_index_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$array_index_native_build_out" 2>"$array_index_native_build_err"); then
    cat "$array_index_native_build_out" >&2
    cat "$array_index_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$array_index_native_bin" ]]; then
    echo "error: native local array index parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$array_index_native_build_err"; then
    echo "error: native local array index parity fragment appears to have fallen back to C99" >&2
    cat "$array_index_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$array_index_native_build_err"; then
    echo "error: native local array index parity fragment used reject path" >&2
    cat "$array_index_native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[1-9][0-9]* core_bodies=1 pending_bodies=[0-9]+' "$array_index_native_build_err"; then
    echo "error: native local array index parity fragment lacks CoreIR index body evidence" >&2
    cat "$array_index_native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[0-9]+ mir_body_functions=1 mir_types=[1-9][0-9]* extern_symbols=[0-9]+ c_import_objects=0 hosted_link_objects=0' "$array_index_native_build_err"; then
    echo "error: native local array index parity fragment lacks PortableMIR index body evidence" >&2
    cat "$array_index_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: core_mir_local_array_index_path=1' "$array_index_native_build_err"; then
    echo "error: native local array index parity fragment lacks hosted Core/MIR executable evidence" >&2
    cat "$array_index_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$array_index_native_build_err"

chmod +x "$array_index_native_bin"
set +e
"$array_index_native_bin" >"$TMP_DIR/array-index.native.run.out" 2>"$TMP_DIR/array-index.native.run.err"
array_index_native_status=$?
set -e
if [[ "$array_index_native_status" -ne "$array_index_c99_status" ]]; then
    echo "error: hosted native/C99 local array index parity exit status differs: c99=$array_index_c99_status native=$array_index_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/array-index.c99.run.out" "$TMP_DIR/array-index.native.run.out"; then
    echo "error: hosted native/C99 local array index parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/array-index.c99.run.err" "$TMP_DIR/array-index.native.run.err"; then
    echo "error: hosted native/C99 local array index parity stderr differs" >&2
    exit 1
fi

slice_c99_build_out="$TMP_DIR/slice.c99.build.out"
slice_c99_build_err="$TMP_DIR/slice.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$slice_src" -o "$slice_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$slice_c99_build_out" 2>"$slice_c99_build_err"); then
    cat "$slice_c99_build_out" >&2
    cat "$slice_c99_build_err" >&2
    exit 1
fi

set +e
"$slice_c99_bin" >"$TMP_DIR/slice.c99.run.out" 2>"$TMP_DIR/slice.c99.run.err"
slice_c99_status=$?
set -e
if [[ "$slice_c99_status" -ne 5 ]]; then
    echo "error: C99 slice parity fragment exited with $slice_c99_status" >&2
    cat "$TMP_DIR/slice.c99.run.out" >&2
    cat "$TMP_DIR/slice.c99.run.err" >&2
    exit 1
fi

slice_native_build_out="$TMP_DIR/slice.native.build.out"
slice_native_build_err="$TMP_DIR/slice.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$slice_src" -o "$slice_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$slice_native_build_out" 2>"$slice_native_build_err"); then
    cat "$slice_native_build_out" >&2
    cat "$slice_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$slice_native_bin" ]]; then
    echo "error: native slice parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$slice_native_build_err"; then
    echo "error: native slice parity fragment appears to have fallen back to C99" >&2
    cat "$slice_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$slice_native_build_err"; then
    echo "error: native slice parity fragment used reject path" >&2
    cat "$slice_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$slice_native_build_err"; then
    echo "error: native slice parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$slice_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$slice_native_build_err"

chmod +x "$slice_native_bin"
set +e
"$slice_native_bin" >"$TMP_DIR/slice.native.run.out" 2>"$TMP_DIR/slice.native.run.err"
slice_native_status=$?
set -e
if [[ "$slice_native_status" -ne "$slice_c99_status" ]]; then
    echo "error: hosted native/C99 slice parity exit status differs: c99=$slice_c99_status native=$slice_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/slice.c99.run.out" "$TMP_DIR/slice.native.run.out"; then
    echo "error: hosted native/C99 slice parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/slice.c99.run.err" "$TMP_DIR/slice.native.run.err"; then
    echo "error: hosted native/C99 slice parity stderr differs" >&2
    exit 1
fi

error_id_c99_build_out="$TMP_DIR/error-id.c99.build.out"
error_id_c99_build_err="$TMP_DIR/error-id.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$error_id_src" -o "$error_id_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$error_id_c99_build_out" 2>"$error_id_c99_build_err"); then
    cat "$error_id_c99_build_out" >&2
    cat "$error_id_c99_build_err" >&2
    exit 1
fi

set +e
"$error_id_c99_bin" >"$TMP_DIR/error-id.c99.run.out" 2>"$TMP_DIR/error-id.c99.run.err"
error_id_c99_status=$?
set -e
if [[ "$error_id_c99_status" -ne 206 ]]; then
    echo "error: C99 @error_id parity fragment exited with $error_id_c99_status" >&2
    cat "$TMP_DIR/error-id.c99.run.out" >&2
    cat "$TMP_DIR/error-id.c99.run.err" >&2
    exit 1
fi

error_id_native_build_out="$TMP_DIR/error-id.native.build.out"
error_id_native_build_err="$TMP_DIR/error-id.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$error_id_src" -o "$error_id_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$error_id_native_build_out" 2>"$error_id_native_build_err"); then
    cat "$error_id_native_build_out" >&2
    cat "$error_id_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$error_id_native_bin" ]]; then
    echo "error: native @error_id parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$error_id_native_build_err"; then
    echo "error: native @error_id parity fragment appears to have fallen back to C99" >&2
    cat "$error_id_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$error_id_native_build_err"; then
    echo "error: native @error_id parity fragment used reject path" >&2
    cat "$error_id_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$error_id_native_build_err"; then
    echo "error: native @error_id parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$error_id_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$error_id_native_build_err"

chmod +x "$error_id_native_bin"
set +e
"$error_id_native_bin" >"$TMP_DIR/error-id.native.run.out" 2>"$TMP_DIR/error-id.native.run.err"
error_id_native_status=$?
set -e
if [[ "$error_id_native_status" -ne "$error_id_c99_status" ]]; then
    echo "error: hosted native/C99 @error_id parity exit status differs: c99=$error_id_c99_status native=$error_id_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/error-id.c99.run.out" "$TMP_DIR/error-id.native.run.out"; then
    echo "error: hosted native/C99 @error_id parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/error-id.c99.run.err" "$TMP_DIR/error-id.native.run.err"; then
    echo "error: hosted native/C99 @error_id parity stderr differs" >&2
    exit 1
fi

catch_c99_build_out="$TMP_DIR/catch.c99.build.out"
catch_c99_build_err="$TMP_DIR/catch.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$catch_src" -o "$catch_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$catch_c99_build_out" 2>"$catch_c99_build_err"); then
    cat "$catch_c99_build_out" >&2
    cat "$catch_c99_build_err" >&2
    exit 1
fi

set +e
"$catch_c99_bin" >"$TMP_DIR/catch.c99.run.out" 2>"$TMP_DIR/catch.c99.run.err"
catch_c99_status=$?
set -e
if [[ "$catch_c99_status" -ne 23 ]]; then
    echo "error: C99 catch parity fragment exited with $catch_c99_status" >&2
    cat "$TMP_DIR/catch.c99.run.out" >&2
    cat "$TMP_DIR/catch.c99.run.err" >&2
    exit 1
fi

catch_native_build_out="$TMP_DIR/catch.native.build.out"
catch_native_build_err="$TMP_DIR/catch.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$catch_src" -o "$catch_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$catch_native_build_out" 2>"$catch_native_build_err"); then
    cat "$catch_native_build_out" >&2
    cat "$catch_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$catch_native_bin" ]]; then
    echo "error: native catch parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$catch_native_build_err"; then
    echo "error: native catch parity fragment appears to have fallen back to C99" >&2
    cat "$catch_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$catch_native_build_err"; then
    echo "error: native catch parity fragment used reject path" >&2
    cat "$catch_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$catch_native_build_err"; then
    echo "error: native catch parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$catch_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$catch_native_build_err"

chmod +x "$catch_native_bin"
set +e
"$catch_native_bin" >"$TMP_DIR/catch.native.run.out" 2>"$TMP_DIR/catch.native.run.err"
catch_native_status=$?
set -e
if [[ "$catch_native_status" -ne "$catch_c99_status" ]]; then
    echo "error: hosted native/C99 catch parity exit status differs: c99=$catch_c99_status native=$catch_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/catch.c99.run.out" "$TMP_DIR/catch.native.run.out"; then
    echo "error: hosted native/C99 catch parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/catch.c99.run.err" "$TMP_DIR/catch.native.run.err"; then
    echo "error: hosted native/C99 catch parity stderr differs" >&2
    exit 1
fi

dynamic_catch_c99_build_out="$TMP_DIR/dynamic-catch.c99.build.out"
dynamic_catch_c99_build_err="$TMP_DIR/dynamic-catch.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$dynamic_catch_src" -o "$dynamic_catch_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$dynamic_catch_c99_build_out" 2>"$dynamic_catch_c99_build_err"); then
    cat "$dynamic_catch_c99_build_out" >&2
    cat "$dynamic_catch_c99_build_err" >&2
    exit 1
fi

set +e
"$dynamic_catch_c99_bin" >"$TMP_DIR/dynamic-catch.c99.fallback.out" 2>"$TMP_DIR/dynamic-catch.c99.fallback.err"
dynamic_catch_c99_fallback_status=$?
"$dynamic_catch_c99_bin" success >"$TMP_DIR/dynamic-catch.c99.success.out" 2>"$TMP_DIR/dynamic-catch.c99.success.err"
dynamic_catch_c99_success_status=$?
set -e
if [[ "$dynamic_catch_c99_fallback_status" -ne 8 ]]; then
    echo "error: C99 dynamic catch fallback fragment exited with $dynamic_catch_c99_fallback_status" >&2
    cat "$TMP_DIR/dynamic-catch.c99.fallback.out" >&2
    cat "$TMP_DIR/dynamic-catch.c99.fallback.err" >&2
    exit 1
fi
if [[ "$dynamic_catch_c99_success_status" -ne 12 ]]; then
    echo "error: C99 dynamic catch success fragment exited with $dynamic_catch_c99_success_status" >&2
    cat "$TMP_DIR/dynamic-catch.c99.success.out" >&2
    cat "$TMP_DIR/dynamic-catch.c99.success.err" >&2
    exit 1
fi

dynamic_catch_native_build_out="$TMP_DIR/dynamic-catch.native.build.out"
dynamic_catch_native_build_err="$TMP_DIR/dynamic-catch.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$dynamic_catch_src" -o "$dynamic_catch_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$dynamic_catch_native_build_out" 2>"$dynamic_catch_native_build_err"); then
    cat "$dynamic_catch_native_build_out" >&2
    cat "$dynamic_catch_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$dynamic_catch_native_bin" ]]; then
    echo "error: native dynamic catch parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$dynamic_catch_native_build_err"; then
    echo "error: native dynamic catch parity fragment appears to have fallen back to C99" >&2
    cat "$dynamic_catch_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$dynamic_catch_native_build_err"; then
    echo "error: native dynamic catch parity fragment used reject path" >&2
    cat "$dynamic_catch_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$dynamic_catch_native_build_err"; then
    echo "error: native dynamic catch parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$dynamic_catch_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$dynamic_catch_native_build_err"

chmod +x "$dynamic_catch_native_bin"
set +e
"$dynamic_catch_native_bin" >"$TMP_DIR/dynamic-catch.native.fallback.out" 2>"$TMP_DIR/dynamic-catch.native.fallback.err"
dynamic_catch_native_fallback_status=$?
"$dynamic_catch_native_bin" success >"$TMP_DIR/dynamic-catch.native.success.out" 2>"$TMP_DIR/dynamic-catch.native.success.err"
dynamic_catch_native_success_status=$?
set -e
if [[ "$dynamic_catch_native_fallback_status" -ne "$dynamic_catch_c99_fallback_status" ]]; then
    echo "error: hosted native/C99 dynamic catch fallback exit status differs: c99=$dynamic_catch_c99_fallback_status native=$dynamic_catch_native_fallback_status" >&2
    exit 1
fi
if [[ "$dynamic_catch_native_success_status" -ne "$dynamic_catch_c99_success_status" ]]; then
    echo "error: hosted native/C99 dynamic catch success exit status differs: c99=$dynamic_catch_c99_success_status native=$dynamic_catch_native_success_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/dynamic-catch.c99.fallback.out" "$TMP_DIR/dynamic-catch.native.fallback.out"; then
    echo "error: hosted native/C99 dynamic catch fallback stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/dynamic-catch.c99.success.out" "$TMP_DIR/dynamic-catch.native.success.out"; then
    echo "error: hosted native/C99 dynamic catch success stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/dynamic-catch.c99.fallback.err" "$TMP_DIR/dynamic-catch.native.fallback.err"; then
    echo "error: hosted native/C99 dynamic catch fallback stderr differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/dynamic-catch.c99.success.err" "$TMP_DIR/dynamic-catch.native.success.err"; then
    echo "error: hosted native/C99 dynamic catch success stderr differs" >&2
    exit 1
fi

defer_c99_build_out="$TMP_DIR/defer.c99.build.out"
defer_c99_build_err="$TMP_DIR/defer.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$defer_src" -o "$defer_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$defer_c99_build_out" 2>"$defer_c99_build_err"); then
    cat "$defer_c99_build_out" >&2
    cat "$defer_c99_build_err" >&2
    exit 1
fi

set +e
"$defer_c99_bin" >"$TMP_DIR/defer.c99.run.out" 2>"$TMP_DIR/defer.c99.run.err"
defer_c99_status=$?
set -e
if [[ "$defer_c99_status" -ne 1 ]]; then
    echo "error: C99 defer parity fragment exited with $defer_c99_status" >&2
    cat "$TMP_DIR/defer.c99.run.out" >&2
    cat "$TMP_DIR/defer.c99.run.err" >&2
    exit 1
fi

defer_native_build_out="$TMP_DIR/defer.native.build.out"
defer_native_build_err="$TMP_DIR/defer.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$defer_src" -o "$defer_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$defer_native_build_out" 2>"$defer_native_build_err"); then
    cat "$defer_native_build_out" >&2
    cat "$defer_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$defer_native_bin" ]]; then
    echo "error: native defer parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$defer_native_build_err"; then
    echo "error: native defer parity fragment appears to have fallen back to C99" >&2
    cat "$defer_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$defer_native_build_err"; then
    echo "error: native defer parity fragment used reject path" >&2
    cat "$defer_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$defer_native_build_err"; then
    echo "error: native defer parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$defer_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$defer_native_build_err"

chmod +x "$defer_native_bin"
set +e
"$defer_native_bin" >"$TMP_DIR/defer.native.run.out" 2>"$TMP_DIR/defer.native.run.err"
defer_native_status=$?
set -e
if [[ "$defer_native_status" -ne "$defer_c99_status" ]]; then
    echo "error: hosted native/C99 defer parity exit status differs: c99=$defer_c99_status native=$defer_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/defer.c99.run.out" "$TMP_DIR/defer.native.run.out"; then
    echo "error: hosted native/C99 defer parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/defer.c99.run.err" "$TMP_DIR/defer.native.run.err"; then
    echo "error: hosted native/C99 defer parity stderr differs" >&2
    exit 1
fi

drop_c99_build_out="$TMP_DIR/drop.c99.build.out"
drop_c99_build_err="$TMP_DIR/drop.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$drop_src" -o "$drop_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$drop_c99_build_out" 2>"$drop_c99_build_err"); then
    cat "$drop_c99_build_out" >&2
    cat "$drop_c99_build_err" >&2
    exit 1
fi

set +e
"$drop_c99_bin" >"$TMP_DIR/drop.c99.run.out" 2>"$TMP_DIR/drop.c99.run.err"
drop_c99_status=$?
set -e
if [[ "$drop_c99_status" -ne 7 ]]; then
    echo "error: C99 drop parity fragment exited with $drop_c99_status" >&2
    cat "$TMP_DIR/drop.c99.run.out" >&2
    cat "$TMP_DIR/drop.c99.run.err" >&2
    exit 1
fi

drop_native_build_out="$TMP_DIR/drop.native.build.out"
drop_native_build_err="$TMP_DIR/drop.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$drop_src" -o "$drop_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$drop_native_build_out" 2>"$drop_native_build_err"); then
    cat "$drop_native_build_out" >&2
    cat "$drop_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$drop_native_bin" ]]; then
    echo "error: native drop parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$drop_native_build_err"; then
    echo "error: native drop parity fragment appears to have fallen back to C99" >&2
    cat "$drop_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$drop_native_build_err"; then
    echo "error: native drop parity fragment used reject path" >&2
    cat "$drop_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$drop_native_build_err"; then
    echo "error: native drop parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$drop_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$drop_native_build_err"

chmod +x "$drop_native_bin"
set +e
"$drop_native_bin" >"$TMP_DIR/drop.native.run.out" 2>"$TMP_DIR/drop.native.run.err"
drop_native_status=$?
set -e
if [[ "$drop_native_status" -ne "$drop_c99_status" ]]; then
    echo "error: hosted native/C99 drop parity exit status differs: c99=$drop_c99_status native=$drop_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/drop.c99.run.out" "$TMP_DIR/drop.native.run.out"; then
    echo "error: hosted native/C99 drop parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/drop.c99.run.err" "$TMP_DIR/drop.native.run.err"; then
    echo "error: hosted native/C99 drop parity stderr differs" >&2
    exit 1
fi

interface_c99_build_out="$TMP_DIR/interface.c99.build.out"
interface_c99_build_err="$TMP_DIR/interface.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$interface_src" -o "$interface_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$interface_c99_build_out" 2>"$interface_c99_build_err"); then
    cat "$interface_c99_build_out" >&2
    cat "$interface_c99_build_err" >&2
    exit 1
fi

set +e
"$interface_c99_bin" >"$TMP_DIR/interface.c99.run.out" 2>"$TMP_DIR/interface.c99.run.err"
interface_c99_status=$?
set -e
if [[ "$interface_c99_status" -ne 26 ]]; then
    echo "error: C99 interface parity fragment exited with $interface_c99_status" >&2
    cat "$TMP_DIR/interface.c99.run.out" >&2
    cat "$TMP_DIR/interface.c99.run.err" >&2
    exit 1
fi

interface_native_build_out="$TMP_DIR/interface.native.build.out"
interface_native_build_err="$TMP_DIR/interface.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$interface_src" -o "$interface_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$interface_native_build_out" 2>"$interface_native_build_err"); then
    cat "$interface_native_build_out" >&2
    cat "$interface_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$interface_native_bin" ]]; then
    echo "error: native interface parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$interface_native_build_err"; then
    echo "error: native interface parity fragment appears to have fallen back to C99" >&2
    cat "$interface_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$interface_native_build_err"; then
    echo "error: native interface parity fragment used reject path" >&2
    cat "$interface_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$interface_native_build_err"; then
    echo "error: native interface parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$interface_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$interface_native_build_err"

chmod +x "$interface_native_bin"
set +e
"$interface_native_bin" >"$TMP_DIR/interface.native.run.out" 2>"$TMP_DIR/interface.native.run.err"
interface_native_status=$?
set -e
if [[ "$interface_native_status" -ne "$interface_c99_status" ]]; then
    echo "error: hosted native/C99 interface parity exit status differs: c99=$interface_c99_status native=$interface_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/interface.c99.run.out" "$TMP_DIR/interface.native.run.out"; then
    echo "error: hosted native/C99 interface parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/interface.c99.run.err" "$TMP_DIR/interface.native.run.err"; then
    echo "error: hosted native/C99 interface parity stderr differs" >&2
    exit 1
fi

atomic_c99_build_out="$TMP_DIR/atomic.c99.build.out"
atomic_c99_build_err="$TMP_DIR/atomic.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$atomic_src" -o "$atomic_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$atomic_c99_build_out" 2>"$atomic_c99_build_err"); then
    cat "$atomic_c99_build_out" >&2
    cat "$atomic_c99_build_err" >&2
    exit 1
fi

set +e
"$atomic_c99_bin" >"$TMP_DIR/atomic.c99.run.out" 2>"$TMP_DIR/atomic.c99.run.err"
atomic_c99_status=$?
set -e
if [[ "$atomic_c99_status" -ne 7 ]]; then
    echo "error: C99 atomic parity fragment exited with $atomic_c99_status" >&2
    cat "$TMP_DIR/atomic.c99.run.out" >&2
    cat "$TMP_DIR/atomic.c99.run.err" >&2
    exit 1
fi

atomic_native_build_out="$TMP_DIR/atomic.native.build.out"
atomic_native_build_err="$TMP_DIR/atomic.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$atomic_src" -o "$atomic_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$atomic_native_build_out" 2>"$atomic_native_build_err"); then
    cat "$atomic_native_build_out" >&2
    cat "$atomic_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$atomic_native_bin" ]]; then
    echo "error: native atomic parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$atomic_native_build_err"; then
    echo "error: native atomic parity fragment appears to have fallen back to C99" >&2
    cat "$atomic_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$atomic_native_build_err"; then
    echo "error: native atomic parity fragment used reject path" >&2
    cat "$atomic_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$atomic_native_build_err"; then
    echo "error: native atomic parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$atomic_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$atomic_native_build_err"

chmod +x "$atomic_native_bin"
set +e
"$atomic_native_bin" >"$TMP_DIR/atomic.native.run.out" 2>"$TMP_DIR/atomic.native.run.err"
atomic_native_status=$?
set -e
if [[ "$atomic_native_status" -ne "$atomic_c99_status" ]]; then
    echo "error: hosted native/C99 atomic parity exit status differs: c99=$atomic_c99_status native=$atomic_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/atomic.c99.run.out" "$TMP_DIR/atomic.native.run.out"; then
    echo "error: hosted native/C99 atomic parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/atomic.c99.run.err" "$TMP_DIR/atomic.native.run.err"; then
    echo "error: hosted native/C99 atomic parity stderr differs" >&2
    exit 1
fi

simd_c99_build_out="$TMP_DIR/simd.c99.build.out"
simd_c99_build_err="$TMP_DIR/simd.c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$simd_src" -o "$simd_c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$simd_c99_build_out" 2>"$simd_c99_build_err"); then
    cat "$simd_c99_build_out" >&2
    cat "$simd_c99_build_err" >&2
    exit 1
fi

set +e
"$simd_c99_bin" >"$TMP_DIR/simd.c99.run.out" 2>"$TMP_DIR/simd.c99.run.err"
simd_c99_status=$?
set -e
if [[ "$simd_c99_status" -ne 8 ]]; then
    echo "error: C99 SIMD parity fragment exited with $simd_c99_status" >&2
    cat "$TMP_DIR/simd.c99.run.out" >&2
    cat "$TMP_DIR/simd.c99.run.err" >&2
    exit 1
fi

simd_native_build_out="$TMP_DIR/simd.native.build.out"
simd_native_build_err="$TMP_DIR/simd.native.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$simd_src" -o "$simd_native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$simd_native_build_out" 2>"$simd_native_build_err"); then
    cat "$simd_native_build_out" >&2
    cat "$simd_native_build_err" >&2
    exit 1
fi
if [[ ! -s "$simd_native_bin" ]]; then
    echo "error: native SIMD parity fragment reported success without output" >&2
    exit 1
fi
if grep -q 'C99' "$simd_native_build_err"; then
    echo "error: native SIMD parity fragment appears to have fallen back to C99" >&2
    cat "$simd_native_build_err" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$simd_native_build_err"; then
    echo "error: native SIMD parity fragment used reject path" >&2
    cat "$simd_native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: no_deps_lowered_program_path=1' "$simd_native_build_err"; then
    echo "error: native SIMD parity fragment lacks hosted no-deps executable evidence" >&2
    cat "$simd_native_build_err" >&2
    exit 1
fi
grep -q 'native_output_bytes:' "$simd_native_build_err"

chmod +x "$simd_native_bin"
set +e
"$simd_native_bin" >"$TMP_DIR/simd.native.run.out" 2>"$TMP_DIR/simd.native.run.err"
simd_native_status=$?
set -e
if [[ "$simd_native_status" -ne "$simd_c99_status" ]]; then
    echo "error: hosted native/C99 SIMD parity exit status differs: c99=$simd_c99_status native=$simd_native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/simd.c99.run.out" "$TMP_DIR/simd.native.run.out"; then
    echo "error: hosted native/C99 SIMD parity stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/simd.c99.run.err" "$TMP_DIR/simd.native.run.err"; then
    echo "error: hosted native/C99 SIMD parity stderr differs" >&2
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

echo "OK: hosted native full-language smoke covered extern/@c_import parity, builtin parity, array @len parity, local array index parity, slice parity, @error_id parity, constant/dynamic catch parity, defer/drop parity, interface/method parity, atomic parity, SIMD parity, C99 success, and explicit native reject"
