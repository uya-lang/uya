# Runtime Entry / Stdlib Group Lowering Contract

**状态**: Phase 9B std/runtime entry 迁移组合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, leaf "std/runtime entry")
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §9 (标准库 / runtime 入口)
**配套 surface contract**: `docs/print_corebody_surface.md`

---

## 1. 范围

本文件定义 std.runtime / libc 入口的 hosted native 落点合同，涵盖：

- `std.runtime.entry`（C main 入口）
- `get_argc` / `get_argv`（命令行参数）
- stdout / stderr（输出）
- `malloc` / `free`（堆内存）
- file IO
- env（环境变量）
- toolchain / linker handoff
- hosted / freestanding capability 分流

---

## 2. 状态表

| 入口 | 状态 | MIR 落点 | 验证证据 |
|------|------|----------|----------|
| `std.runtime.entry` | done | hosted profile 自动注入 C main 包装 | `tests/verify_hosted_native_basic_parity.sh` / `verify_hosted_native_helloworld_parity.sh` |
| `get_argc` | done | `CALL → uya_get_argc` | hosted profile；freestanding 走 build-seed 路径 |
| `get_argv` | done | `CALL → uya_get_argv` | 同上 |
| stdout | done | 通过 `uya_write(1, buf, len)` | `print_corebody_surface.md` §3 |
| stderr | done | 通过 `uya_write(2, buf, len)` | 同上 |
| `malloc` | done | hosted 走 libc `malloc`；freestanding 走 build-seed | `tests/verify_native_mir_emitter.sh` |
| `free` | done | 同上 | 同上 |
| file IO | done | `libc_bindings` 路径 | `lib/libc/*.uya` |
| env | done | `libc_bindings` 路径 | 同上 |
| toolchain / linker handoff | done | `tests/verify_native_mir_emitter.sh` 守门 | MIR emit → MachineModule → ELF → host cc 链接 |
| hosted / freestanding capability 分流 | done | `tests/verify_portable_mir_target_metadata.sh` | profile id 决定 entry 路径 |

---

## 3. 通用 contract

每个 runtime 入口必须满足：

1. **ABI 稳定**：所有 `uya_*` runtime helper 与 C99 codegen 静态生成的
   实现 ABI 一致（见 `docs/print_corebody_surface.md` §3.3）。
2. **profile 分流**：`hosted` profile 调用 libc 实现；`freestanding` profile
   走 build-seed 路径或显式 reject。
3. **capability gate**：`stdout` / `stderr` / `malloc` / `file IO` 在
   microapp 中通过 capability table 解析；缺失 capability 必须显式 reject。
4. **入口包装**：`std.runtime.entry` 必须自动注入 `extern "libc" fn main(argc, argv)`
   包装用户 `export fn main() i32`。
5. **toolchain handoff**：`uya build` 路径在 native 端不依赖 host C
   编译器（自举产物为纯 ELF）；C99 oracle 路径允许使用 host cc 链接。

---

## 4. 入口

- `lib/std/runtime/entry/entry.uya`：定义 C main 包装（`extern "libc" fn main`）。
- `lib/std/runtime/runtime.uya`：提供 `get_argc` / `get_argv` / `saved_argc` /
  `saved_argv` / `saved_envp`。
- `lib/std/runtime/capability/capability.uya`：capability table 入口。
- `src/build_compiler_driver.uya` 的 `native_build_*` 系列：hosted native
  主路径的 entry 注入。

任何新 runtime 入口添加时，本表 + `lib/std/runtime/` 必须先于 `src/codegen/`
修改；否则 lowering 找不到 helper。

---

## 5. 验证与守门

1. `tests/verify_hosted_native_basic_parity.sh` / `verify_hosted_native_helloworld_parity.sh`：
   entry 路径必须可执行。
2. `tests/verify_native_mir_emitter.sh`：MIR emit → MachineModule 走通。
3. `tests/verify_portable_mir_target_metadata.sh`：profile 分流正确。
4. `tests/verify_native_hosted_link_contract.sh`：链接产物合规。
5. `lib/std/runtime/capability/*`：microapp 路径能力 gate。

新增 runtime 入口时：
- 更新本文件 §2 表格；
- 更新 `docs/portable_mir_language_coverage.md` §9 表格；
- 添加或更新对应 verify 脚本的 shard。

---

## 6. 反向合同

禁止：

1. hosted profile 静默调 libc `printf` 替代 `uya_print_*`。
2. freestanding profile 调 libc（必须走 build-seed）。
3. capability 缺失时静默走 fallback。
4. 入口包装重复（同一程序出现两个 `extern "libc" fn main`）。

---

## 7. 与其它迁移组的衔接

- **types/layout**（`docs/types_layout_lowering_contract.md`）：entry 的
  signature type 翻译。
- **builtins**（`docs/builtins_lowering_contract.md`）：`@print` / `@println`
  走 runtime entry 的 helper。
- **statements**（`docs/statements_lowering_contract.md`）：entry 自动注入
  是 hidden statement。
