# Hosted Native HelloWorld Parity Target

**状态**: Phase 9B HelloWorld parity 目标合同
**更新日期**: 2026-06-09
**配套 TODO**: `docs/todo_compiler_1s.md` (Phase 9B, print/println MIR lowering 子链)
**配套 contract**: `docs/print_corebody_surface.md`
**配套 oracle 验证**: `tests/verify_hosted_native_helloworld_parity.sh`
**配套覆盖矩阵**: `docs/portable_mir_language_coverage.md` §3 (AST_PRINT, AST_PRINTLN)

---

## 1. 范围

本文件定义当 `make clean && make uya` 在 hosted native profile 下能真实编译并
运行 `@println("Hello, World!")` 时，必须满足的所有可观察合同。它是 §3
`AST_PRINT` / `AST_PRINTLN` 状态从 `done` (C99 端) 升级为 `done` (C99 + hosted
native 双端) 的门禁清单。

---

## 2. 端到端可观察合同

最小 HelloWorld 源：

```uya
export fn main() i32 {
    @println("Hello, World!");
    return 0;
}
```

`./bin/uya build hello.uya -o hello --native --no-split-c` 必须满足：

1. 退出码 0。
2. 生成 ELF 可执行 `hello`，架构 `x86_64`，sysv ABI。
3. 运行 `./hello` 退出 0，stdout 字节级匹配 `Hello, World!\n`。
4. `./hello` 的 stderr 为空。
5. `--native` build 的 stderr 必须**不**包含：
   - `后端类型: C99`
   - `hosted native assembly`
   - `build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集`
   - `native_hosted_portable_mir_lowering_missing`
6. `--native` build 的 stderr **必须**包含：
   - `native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[1-9][0-9]* core_bodies=[1-9][0-9]* pending_bodies=0`
   - `native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[1-9][0-9]* mir_body_functions=[1-9][0-9]* mir_types=[1-9][0-9]*`
   - `native_hosted_subset: no_deps_portable_mir_path=1`
   - `native_hosted_executable_writer_stream: status=ready target=1 code_bytes=[1-9][0-9]* output_bytes=[1-9][0-9]* temp_peak_bytes=[1-9][0-9]*`
   - `native_output_bytes:`

---

## 3. 三种 HelloWorld 变体 parity

`tests/verify_hosted_native_helloworld_parity.sh` 锁定的三种变体：

| 变体 | 源码 | 期望 stdout |
|------|------|-------------|
| bare | `@println("Hello, World!");` | `Hello, World!\n` |
| split | `@print("Hello, World!"); @println("");` | `Hello, World!\n` |
| return-as-expr | `const printed: i32 = @println("Hello, World!"); if printed <= 0 { return 1; } return 0;` | `Hello, World!\n` 退出 0 |

三种变体在 hosted native 下都必须：build 成功、生成 ELF、stdout 字节级一致、
exit 0、stderr 空。`verify_hosted_native_helloworld_parity.sh` 在 parity 路径
中通过 `cmp -s` 比对三者 stdout 与 C99 oracle 完全相同。

---

## 4. runtime helper ABI 合同

hosted native ELF 链接时必须可解析以下符号（链接器报错即合同违反）：

- `uya_write(fd: i32, buf: *const byte, len: usize) i32` — fd=1 表示 stdout。
- `uya_print_i32(value: i32) i32` — i32 整数 i32 字节数（带符号十进制）。
- `uya_print_str(buf: *const byte, len: usize) i32` — 字符串字面量 / 插值缓冲。
- `uya_print_bool(value: i32) i32` — `0` / `1`。
- `uya_print_f64(value: f64) i32` — 浮点。
- `uya_write_newline() i32` — 单字节 `'\n'`，等价于 `uya_write(1, "\n", 1)`。

上述 helper 当前由 `src/codegen/c99_build/main.uya:3091-3111` 静态生成；
hosted native 端 MIR emitter 必须消费同一 ABI 不可漂移。

`lib/std/runtime/print/*.uya` 应在 Phase 9B 收口前落地为 `uya` 模块，hosted
profile 编译到 ELF 时由 `bin/uya` 的链接流程拉入。

---

## 5. 性能合同

- `make clean && make uya` 不变，hosted native 编译 HelloWorld 单次耗时 < 50ms
  （C99 oracle 79ms 的 1.5x 以内）。这是 Phase 9B 中间目标；Phase 11 才会要求
  `make uya` 中位数 < 1 秒。
- hosted native HelloWorld 生成的 ELF 大小 < 16 KiB（不含 c_import 段）。
- `peak_rss_kb` 不高于 C99 oracle 同等输入的 1.5x。

---

## 6. 反向合同（防作弊）

hosted native 路径**禁止**通过以下任一方式达成 §2 合同：

1. **C99 fallback** — `--native` 实际调用 C99 backend 然后把结果链接成 ELF。
2. **pre-MIR helper** — 走 `hosted native assembly` 路径直接 emit 汇编，跳过
   CoreBody / PortableMIR。
3. **build-seed helper** — 走 `LoweredProgram` `body_ops` 直接生成 binary，跳过
   `CoreStmt` / `MirInst`。
4. **runtime shim** — 让 ELF 实际调 libc 的 `printf` 而非 `uya_print_*`。
5. **跨进程 oracle** — 在 native build 过程中 fork 出 C99 build 然后用其结果。

`verify_hosted_native_helloworld_parity.sh` 通过 stderr 标记守门第 1-3 条；
第 4-5 条由 `bin/uya` 自举构建 + 字节级 stdout 比对守门。

---

## 7. 验收流程

1. `make clean && make uya`：自举构建必须仍 < 30 秒（Phase 9 不变指标）。
2. `./bin/uya build hello.uya -o hello --native --no-split-c`：单步。
3. `./hello` 与 `bin/uya build hello.uya -o hello-c99` 的输出做 `cmp -s`。
4. `bash tests/verify_hosted_native_helloworld_parity.sh`：CI 守门。
5. `bash tests/verify_hosted_native_full_language_smoke.sh`：回归 baseline。
6. `bash tests/verify_portable_mir_language_coverage.sh`：矩阵覆盖守门。

第 1-6 全通过即可勾选对应 TODO leaf，并把 `docs/portable_mir_language_coverage.md`
§3 中 `AST_PRINT` / `AST_PRINTLN` 备注从 "C99 已完整 codegen" 升级为
"C99 + hosted native 双端 codegen"。

---

## 8. 与 §7 reject 集合的衔接

当前 `tests/verify_hosted_native_full_language_smoke.sh:635` 中
`run_native_reject_fragment full_language` 是 `full_language` shard 的 reject
注册点。当本文件 §2 合同达成后：

- 该 reject 注册行可以删除；
- `docs/portable_mir_language_coverage.md` §7 表中 `full_language` 行可以删除
  或状态改为 `done`；
- `docs/portable_mir_language_coverage.md` §10 阶段 KPI 中
  "HelloWorld 作为 MIR -> Native 首个目标完成 native/C99 parity" 勾选上。

但 `full_language` 综合集成体的完整 parity 仍需 Phase 10 / 11 推进，HelloWorld
只是首个端到端目标。
