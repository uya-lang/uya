# exec VM 对齐 C99：执行看板

> 判据与门禁见 `docs/exec_vm_c99_parity.md`。本文件是**可执行的任务清单**：
> 每完成一项，勾选并单独提交一次；全部完成后合并到 main 并删除工作区。
>
> 验收口径：`tests/verify_exec_vm_census.sh`（`uya test --vm` 全量通过率）与
> `tests/verify_exec_vm_parity.sh`（与 C99 逐用例差分）。**最终目标是
> `uya test --vm` 全量通过**，C99 只作为参照。

## 进度快照

- 最近一次实测：`test --vm` 通过 **220 / 911（24.1%）**，失败 691。
- 失败原因分布：`generic` 531、`simd` 55、`runtime` 20、`match_expr` 19、
  `unknown` 13、`extern_abi` 11、`string_interp` 9、`catch_expr` 7、
  `c_import` 4、`try_expr` 3、`async` 2、`build` 1。
- 门禁全绿：`make check` 1188/1188；8 个 `tests/verify_exec_vm_*.sh` 全过。

## 任务清单

### T0 门禁与基线工具（已完成）

- [x] `tests/verify_exec_vm_census.sh` + `make exec-census`
- [x] `tests/verify_exec_vm_parity.sh` + `make exec-parity`
- [x] 跳过表 `tests/exec_vm_census_skip.txt` / `tests/exec_vm_parity_skip.txt`
- [x] printf 家族 varargs（`src/exec/format.uya`）
- [x] 顶层 `test "..."` 块 lowering + VM runner
- [x] `uya_pipeline_worker_dispatch` 合成符号

### T1 执行看板（本文件）

- [x] 建立本清单并在后续每项完成时勾选、单独提交。

### T2 导入模块内部全局变量槽位（最大杠杆，约 230 例）

- 现象：`--vm` 下 `lib/std/testing/testing.uya:63` 的 `_test_passed` 报
  `exec: 当前仅支持局部变量/参数/全局标识符`，实测 `ctx.global_count = 5`。
- 已查明：`checker_find_export_decl_by_module_name` 直接扫描
  `checker.program_node.program_decls`，说明合并 AST 里**含**库模块的 decl；
  但 `exec_lower_collect_global_slots_from_program` 只收到 5 个全局槽位，
  需确认是收集入口的 program 节点不同、还是 decl 类型判断漏了。
- 验收：`tests/test_as_force_cast.uya` 等含 `use std.testing.<item>` 的用例
  在 `--vm` 下不再报该错误；census 通过率显著上升。

### T3 赋值表达式（`(x = 1) != 0`）

- 现象：`tests/test_and_return.uya:24:28` 报 `exec: 尚未支持的表达式节点`。
- 需要 HIR/bytecode 支持「表达式形式的赋值」：求值赋给目标并产出值。
- 验收：`test_and_return` 在 `--vm` 下通过；新增回归用例。

### T4 未支持表达式节点清零（84 例）

- 先给 `exec: 尚未支持的表达式节点` 补上节点类型诊断，再按直方图逐类实现
  （`@await` 除外，归 T9）。
- 验收：该消息在 census 中为 0。

### T5 泛型调用 / varargs 转发（90 例）

- 现象：`exec: 当前不支持泛型调用或 varargs 转发`。
- 需要单态化实例与 varargs 形参（`@params`/`...`）的 lowering。
- 验收：该消息清零。

### T6 match 全模式（19 例）

- 现象：`exec: 当前仅支持标量 match`。
- 覆盖枚举/错误/联合/元组模式与守卫。
- 验收：`match_expr` 原因码清零。

### T7 SIMD（55 例）

- `ExecValueKind` 增加 `VECTOR`/`MASK`，实现逐通道运算与 `@vector.*` 内建。
- 验收：`simd` 原因码清零。

### T8 extern / FFI 原生桥（11 例）

- 统一 native bridge：生成 C shim → 宿主 cc → `.so` → `dlopen/dlsym`；
  覆盖 `extern`、`extern var`、`@c_import`、`@asm`。
- 验收：`extern_abi`、`c_import`、`asm` 原因码清零。

### T9 async / `@await` / `@frame`（2 例）

- 状态机 lowering，与 C99 后端的 CPS 变换语义一致。
- 验收：`async` 原因码清零。

### T10 静默失败清理

- `for arr |v|`、`for arr |&item|` 等在 `--vm` 下静默退出 1；
  任何失败都必须有原因码 + `file:line` + 消息。
- 验收：`tests/verify_exec_vm_diagnostics.sh` 通过，census 中无空消息失败。

### T11 收口

- [ ] `uya test --vm` 全量通过（跳过表只保留 C99 侧同样不适用的用例）
- [ ] `make exec-parity` 全绿
- [ ] `make check` 全绿
- [ ] 合并到 main 并删除工作区
