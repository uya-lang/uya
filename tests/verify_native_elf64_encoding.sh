#!/usr/bin/env bash

# Phase 9：验证 ELF64 header/program-header/section-header 字节级编码。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ELF64_FILE="$REPO_ROOT/src/codegen/native/elf64.uya"

if [[ ! -f "$ELF64_FILE" ]]; then
    echo "错误: 缺少 $ELF64_FILE" >&2
    exit 1
fi

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$ELF64_FILE"; then
        echo "错误: ELF64 编码缺少证据: $description" >&2
        exit 1
    fi
}
require_pattern 'elf64_encode_ehdr' "ELF64 文件头编码入口"
require_pattern 'elf64_encode_phdr' "program header 编码入口"
require_pattern 'elf64_encode_shdr' "section header 编码入口"
require_pattern 'EM_X86_64' "x86_64 machine 常量"

tmp_dir="$(mktemp -d /tmp/uya-native-elf64.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ELF64_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "elf64 ehdr encodes exact little-endian bytes" {
    var buf: [byte: 256] = [];
    const n: i32 = elf64_encode_ehdr(&buf[0], 256usize, ET_EXEC, EM_X86_64,
        4198400i64, 64i64, 0i64, 1, 0, 0);  // entry = 0x401000, phoff=64
    try assert_eq_i32(n, 64);

    // magic + class/data/version/osabi
    try assert_eq_i32(bval(&buf[0], 0usize), 127);
    try assert_eq_i32(bval(&buf[0], 1usize), 69);
    try assert_eq_i32(bval(&buf[0], 2usize), 76);
    try assert_eq_i32(bval(&buf[0], 3usize), 70);
    try assert_eq_i32(bval(&buf[0], 4usize), 2);   // ELFCLASS64
    try assert_eq_i32(bval(&buf[0], 5usize), 1);   // ELFDATA2LSB
    try assert_eq_i32(bval(&buf[0], 6usize), 1);   // EV_CURRENT
    try assert_eq_i32(bval(&buf[0], 7usize), 0);   // SYSV

    // e_type / e_machine (LE u16)
    try assert_eq_i32(bval(&buf[0], 16usize), 2);  // ET_EXEC
    try assert_eq_i32(bval(&buf[0], 17usize), 0);
    try assert_eq_i32(bval(&buf[0], 18usize), 62); // EM_X86_64
    try assert_eq_i32(bval(&buf[0], 19usize), 0);

    // e_entry = 0x401000 -> 00 10 40 00 ...
    try assert_eq_i32(bval(&buf[0], 24usize), 0);
    try assert_eq_i32(bval(&buf[0], 25usize), 16);
    try assert_eq_i32(bval(&buf[0], 26usize), 64);
    try assert_eq_i32(bval(&buf[0], 27usize), 0);

    // e_phoff = 64
    try assert_eq_i32(bval(&buf[0], 32usize), 64);
    try assert_eq_i32(bval(&buf[0], 33usize), 0);

    // sizes
    try assert_eq_i32(bval(&buf[0], 52usize), 64); // e_ehsize
    try assert_eq_i32(bval(&buf[0], 54usize), 56); // e_phentsize
    try assert_eq_i32(bval(&buf[0], 56usize), 1);  // e_phnum
    try assert_eq_i32(bval(&buf[0], 58usize), 64); // e_shentsize
    try assert_eq_i32(bval(&buf[0], 60usize), 0);  // e_shnum
    try assert_eq_i32(bval(&buf[0], 62usize), 0);  // e_shstrndx

    // 容量不足返回 -1
    var tiny: [byte: 8] = [];
    try assert_eq_i32(elf64_encode_ehdr(&tiny[0], 8usize, ET_EXEC, EM_X86_64, 0i64, 0i64, 0i64, 0, 0, 0), -1);
}

test "elf64 phdr and shdr encode exact bytes" {
    var buf: [byte: 256] = [];
    const np: i32 = elf64_encode_phdr(&buf[0], 0usize, 256usize, PT_LOAD, 5,
        0i64, 4194304i64, 4096i64, 4096i64, 4096i64);  // vaddr 0x400000, sizes 0x1000, align 0x1000, flags R|X
    try assert_eq_i32(np, 56);
    try assert_eq_i32(bval(&buf[0], 0usize), 1);   // PT_LOAD
    try assert_eq_i32(bval(&buf[0], 4usize), 5);   // PF_R|PF_X
    // p_vaddr = 0x400000 -> 00 00 40 00 ...
    try assert_eq_i32(bval(&buf[0], 16usize), 0);
    try assert_eq_i32(bval(&buf[0], 17usize), 0);
    try assert_eq_i32(bval(&buf[0], 18usize), 64);
    // p_paddr mirrors p_vaddr
    try assert_eq_i32(bval(&buf[0], 26usize), 64);
    // p_align = 0x1000 -> off 48: 00 10 ...
    try assert_eq_i32(bval(&buf[0], 48usize), 0);
    try assert_eq_i32(bval(&buf[0], 49usize), 16);

    var sbuf: [byte: 256] = [];
    const ns: i32 = elf64_encode_shdr(&sbuf[0], 0usize, 256usize, 1, SHT_PROGBITS,
        6i64, 4194304i64, 0i64, 256i64, 0, 0, 16i64, 0i64);  // flags ALLOC|EXEC=6
    try assert_eq_i32(ns, 64);
    try assert_eq_i32(bval(&sbuf[0], 0usize), 1);  // sh_name
    try assert_eq_i32(bval(&sbuf[0], 4usize), 1);  // SHT_PROGBITS
    try assert_eq_i32(bval(&sbuf[0], 8usize), 6);  // sh_flags low byte
    // sh_size = 256 -> off 32: 00 01 ...
    try assert_eq_i32(bval(&sbuf[0], 32usize), 0);
    try assert_eq_i32(bval(&sbuf[0], 33usize), 1);
    // sh_addralign = 16 -> off 48
    try assert_eq_i32(bval(&sbuf[0], 48usize), 16);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native ELF64 ehdr/phdr/shdr byte encoding verified"
