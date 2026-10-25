# exec VM 对齐 C99：执行看板

> 判据与门禁见 `docs/exec_vm_c99_parity.md`。本文件是**可执行的任务清单**：
> 每完成一项，勾选并单独提交一次；全部完成后合并到 main 并删除工作区。
>
> 验收口径：`tests/verify_exec_vm_census.sh`（`uya test --vm` 全量通过率）与
> `tests/verify_exec_vm_parity.sh`（与 C99 逐用例差分）。**最终目标是
> `uya test --vm` 全量通过**，C99 只作为参照。

## 进度快照

- 最近一次实测（T4b 之后）：`test --vm` 通过 **345 / 913（37.8%）**，失败 568。
- 失败原因分布：`generic` 376、`simd` 55、`runtime` 48、`match_expr` 20、
  `unknown` 14、`extern_abi` 13、`string_interp` 9、`build` 8、`catch_expr` 7、
  `try_expr` 4、`c_import` 4、`async` 2。
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
- [x] 已完成：lowering 改为「先按调用边闭包补齐可达函数 → 按函数所在文件补采全局
  槽位 → 再降函数」，并用最多 4 轮定点循环补降新发现全局的初始化表达式。
- 实测：`220 / 911（24.1%）` → `325 / 911（35.7%）`；8 个 `verify_exec_vm_*.sh` 全过。

### T2b `as!` 数值转换（T2 暴露）

- 现象：`tests/test_as_force_cast.uya` 的 `f64 as! i32` 得到 `1374389535`
  （IEEE-754 位模式），C99 侧应为截断值 `3`；说明强制转换走了位重解释而非数值转换。
- [x] 已完成：`as!` 现在无条件发射 `HIR_EXPR_CAST`，不再直接复用操作数；
  `3.14 as! i32` 由 1374389535（位模式）修正为 3。
- 实测：`tests/test_as_force_cast.uya` 在 `--vm` 与 C99 下均全过；
  8 个 `verify_exec_vm_*.sh` 全过；census 325 → 326。

### T3 赋值表达式与 `@mc_source`（已完成）

- [x] 新增 `HIR_EXPR_ASSIGN`：赋值表达式与赋值语句共用目标/取值 lowering，
  builder 落库后返回被赋的值。`tests/test_and_return.uya` 在 `--vm` 下通过。
- [x] `@mc_source` 未展开时按 C99 口径发射空字符串（此前直接报未支持表达式）。
- 实测：通过率 35.8% → 37.2%，8 个 `verify_exec_vm_*.sh` 全过。

### T4 if 表达式（`type=15`，20 例）

- [x] 新增 `HIR_EXPR_IF` + 字节码分支合流（`BC_JMP_IF_FALSE`/`BC_JMP`/`BC_MOV`），
  分支取值走 checker 的 `checker_if_expr_branch_value_node` 规则，支持 `else if` 链。
- 回归用例：`tests/test_exec_vm_if_expr.uya`（C99 与 `--vm` 双通过）。
- 实测：通过率 37.2% → 37.4%；同原因文件在修复后暴露下一层错误，继续按直方图推进。

### T4 未支持表达式节点清零（84 例）

- 先给 `exec: 尚未支持的表达式节点` 补上节点类型诊断，再按直方图逐类实现
  （`@await` 除外，归 T9）。
- 验收：该消息在 census 中为 0。

### T4b match 分支尾部是语句（已完成）

- [x] 根因：`exec_lower_extract_block_result_expr` 把分支块的最后一条**语句**
  （`if i_val != 42 { return 10; }`）当作结果表达式 lower，报「if 表达式缺少条件或分支」。
- [x] 修复：尾部是无 else 的 `if` 时，整块按语句 lowering 成前缀块，结果用 void 零值占位
  （与 C99 的语句/void match 口径一致）。
- 实测：通过率 37.7% → 37.8%（这批文件继续前进到泛型/标识符/catch 等下一层）。

### T12 多维数组下标写入（已完成）

- [x] 根因：`exec_vm_index_ref` 对 internal-ref 一律先按
  `@size_of(ExecValue)` 做原始指针步进；但装箱聚合（数组/元组/结构体）的元素在
  `aggregate.values` 里，导致 `arr[i][j] = v` 写到聚合头之外的地址、写回丢失
  （`test_array_bounds` 的 `arr14[0][1]` 读回 20 而不是 200）。
- [x] 修复：internal-ref 分支先判断目标是否为装箱聚合，是则按 `aggregate.values`
  取元素，原始指针步进只保留给真正的 raw array。
- 回归用例：`tests/test_exec_vm_nested_array_write.uya`（C99 与 `--vm` 双通过）。
- 实测：通过率 37.6% → 37.7%；`test_array_bounds` 在 `--vm` 下全过。

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

- [x] `exec_run_program` 与 driver 的 exec 分支在退出前 flush `libc.stdout`/`libc.stderr`，
  避免未换行结尾的输出和运行后诊断信息随进程退出丢失。
- [x] 定位并修复首例静默失败：`for arr |v|` 数组迭代在 `exec_lower_make_for_range_stmt`
  里直接 `return null` 且不设错误，导致 build 失败但零输出。现在显式报
  `exec: 当前不支持 for 数组迭代`（census 中空消息失败 41 → 27）。
- [x] `exec_build_program`、全局初始化、函数 lowering 三处补「失败但未设置错误」兜底，
  避免再次出现无消息失败。
- [x] `null` 字面量（parser 用名为 `null` 的标识符表示）按零值指针 lowering，
  回归用例 `tests/test_exec_vm_null_pointer.uya`（C99/VM 双通过）。
- [x] 其余 29 例空消息失败已确认**不是**静默构建失败：flush 修复后都能看到
  `程序运行返回码：1`，属于「VM 跑完但结果不对」的语义缺陷（转 T12/T4b 等）。

### T5b for 数组迭代（`|v|` / `|&v|` / `|_|`）

- [x] 值绑定与 `|_|`：`exec_lower_make_for_array_stmt` 把数组值存进临时局部，
  再用下标循环把 `arr[i]` 绑定到 `for_stmt_var_name`（`_` 不绑定）。
- [ ] 引用绑定 `|&item|`（4 个文件）：尝试过用 `HIR_EXPR_ADDR` 包 `HIR_EXPR_INDEX`
  并在 builder 里新增 `ADDR_INDEX` 分支，运行时直接段错误（`run --vm` 返回 139），
  已整段回滚（保留显式 unsupported）。下次先补 `&arr[i]` 的 VM 单测与字节码断言，
  确认 `BC_ADDR_INDEX` 的 `c`（下标槽）/`imm`（元素类型）编码正确后再接到 for 上。
- 实测：通过率 37.4% → 37.6%；8 个 `verify_exec_vm_*.sh` 全过。

- `for arr |v|`、`for arr |&item|` 等在 `--vm` 下静默退出 1；
  任何失败都必须有原因码 + `file:line` + 消息。
- 验收：`tests/verify_exec_vm_diagnostics.sh` 通过，census 中无空消息失败。

### T11 收口

- [ ] `uya test --vm` 全量通过（跳过表只保留 C99 侧同样不适用的用例）
- [ ] `make exec-parity` 全绿
- [ ] `make check` 全绿
- [ ] 合并到 main 并删除工作区
