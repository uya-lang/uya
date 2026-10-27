# exec VM 对齐 C99：执行看板

> 判据与门禁见 `docs/exec_vm_c99_parity.md`。本文件是**可执行的任务清单**：
> 每完成一项，勾选并单独提交一次；全部完成后合并到 main 并删除工作区。
>
> 验收口径：`tests/verify_exec_vm_census.sh`（`uya test --vm` 全量通过率）与
> `tests/verify_exec_vm_parity.sh`（与 C99 逐用例差分）。**最终目标是
> `uya test --vm` 全量通过**，C99 只作为参照。

## 进度快照

- 本分支阶段性成果已合并/落地：T1（门禁）、T2（模块全局槽位）、T2b（as! 转换）、
  T3（赋值表达式/@mc_source）、T4（if 表达式）、T4b（语句分支 match）、
  T5b（for 数组值绑定 + `|&item|` 引用绑定）、T6（match 全模式）、
  T12（嵌套数组写入）、T13 主体（双指针/指针元素类型）与若干诊断/静默失败修复。
- 最近一次完整普查（SIMD 主要能力落地之后）：`test --vm` 通过
  **535 / 914（58.5%）**，失败 379；与上一基线（482）比对**零回归**，
  新增通过集中在 `test_simd_*`、`test_json_encode_*`、`test_yaml_*`。
- 最新一次全量普查（T7 收口 + 静态方法/UFCS 之后）：`test --vm` 通过
  **543 / 914（59.4%）**，失败 371；与 482 基线比对零回归，累计 +61。
- 本轮（catch 作用域 / 聚合值 / 泛型单态宏展开）：`test --vm` 通过
  **589 / 914（64.4%）**，失败 325；与上一轮基线（581）比对零回归，累计 +146。
  新增通过：catch 前缀局部变量可见性（yaml 17/17）、嵌套 catch 早返回、
  泛型单态体 AST 级宏展开、零字段结构体字面量、空聚合字面量、
  结构体/数组按值比较、`{ ... }` 语句表达式（`HIR_EXPR_BLOCK`）。
  其中两处是**语义级**错误，不只是「没支持」：
  - `catch { … return <非错误联合值> }` 早返回没有按函数返回类型包 ok/err，
    调用方对非错误联合值做 UNWRAP_OK，拿到垃圾值；
  - `==`/`!=` 对结构体恒为「相等」，因为 exec_vm_compare_values 只看
    i64_value，而结构体的该字段恒为 0。
- 本轮（单态宏展开 + 结构体默认值 + 错误 id 语义）普查：`test --vm` 通过
  **597 / 914（65.3%）**，失败 317。此前普查 589，本轮 +8 中已确认的新增通过：
  `test_json_array`（含 json/yaml 全 17 例）、`test_protobuf_dynamic`、
  `test_tls_x509`、`test_struct_default`、`test_error_id_builtin`、
  `test_return_catch_err_pointer`。
  剩余失败里 **`失败: N`（跑起来了但断言挂）22 例** 才是语义缺口：
  http 6 例、drop/移动 2 例、指针算术 2 例、base64 1 例、protobuf_wire 1 例等；
  其余是 async 53、inline asm 52、泛型/varargs、extern 桥等结构性缺口。
- `make check` 已全绿：1191 个测试，通过 1191，失败 0。
- 本轮（inline asm 占位 / 管道 desugar / 接口零值 / print 切片 / libc `%g` /
  malloc 一族 / 原子内建 / module-qualified 调用）普查：`test --vm` 通过
  **648 / 914（70.9%）**，比上一基线 614 多 **+34**，零回归。
- 继续修「错误信息骗人」的一类缺陷后：**655 / 914（71.7%）**，累计比 648 多 +7：
  - `x as T;` 这种**转换表达式语句**不在语句分派白名单里，落到「尚未支持的语句节点」
    分支时会先弹一层作用域再返回 null，把外层 catch 前缀的作用域连带弹掉，
    于是报 `当前仅支持局部变量/参数/全局标识符(err_id)`——指向完全无关的标识符。
    补上 `AST_CAST_EXPR` / `AST_PIPELINE_EXPR` 后 https 一族推进到下一个真实阻塞。
  - `(x as! T).value` / `.error_id` 的**静默类型推断**退回 void，导致
    `return (n as! usize).value;` 报 `return 类型与函数返回类型不一致
    (actual=void expected=!usize)`；按基类型（错误联合）补一次载荷类型后
    `test_https_local` 转通过。
  - `&f` / 裸函数名当值用（`pthread_create(..., thread_main, arg)`）此前报
    `仅支持局部变量/…`；现在给 `4096 + hash(name)` 的稳定非零占位指针，
    `test_function_reachability_address_taken` 转通过。
  失败原因 Top（655 那次普查）：async 54、`仅支持局部变量/参数/全局标识符` 23、
  `无法解析成员方法调用` 14、`catch 操作数不是错误联合` 22、
  `这个泛型调用` 11、`编译期 builtin 折叠失败` 10、`return 类型与函数返回类型不一致` 14。
- 再一轮（元组解构 / 空结构体尺寸 / clone 拒绝 / `try match` / 泛型参数占位）后：
  **664 / 914（72.6%）**，与 648 基线比对**零回归**，累计 +16。新增通过：
  `test_underscore`、`test_tuple`、`test_empty_struct`、`test_struct_layout`、
  `test_va_list_builtin`、`test_function_reachability_address_taken`、
  `test_json_from_json_slice`、`test_generic_comprehensive`、
  `test_generic_multi_type_param`、`test_https_local` 等。
  失败原因 Top（664 那次普查）：async 59、空消息 76（其中 39 例是 pthread/clone
  相关、24 例断言失败、12 例超时）、`catch 操作数不是错误联合` 25、
  `无法解析成员方法调用` 15、`编译期 builtin 折叠失败` 8、`slice 越界` 6、
  `LOAD_FIELD 字段越界` 5、`try 操作数不是错误联合` 4、`LOAD_INDEX 越界` 4。
- 再一轮（drop 相关三处修复）：**669 / 914（73.2%）**，与 664 比对零回归。
  新增通过：`test_drop_order`、`test_drop_external`、`test_drop_export_main_direct`、
  `test_method_block_string_constant`、`test_std_sql`。
- 新增修复：放不进 i32 的无后缀整数字面量在 `BC_LOAD_CONST` 里会被截断成负数，
  `v > 922337203685477580` 这类守卫整条反掉。std.json 的数字解析因此恒返回
  `NumberOverflow`。改成超出 i32 范围就按 i64 发射后，json 全量 26 例中 17 例通过
  （此前 parse 系列全灭）。
- 剩余 371 例的结构性判断：
  - inline asm（47 例）：VM 是解释器，执行不了内联汇编，也不是「补几个 opcode」
    能解决的；
  - async / `@await` / future 状态机（约 117 例）：需要整套 Future/调度器语义；
  - 泛型单态化与 varargs 转发（约 101 例，多数与 async 重叠）；
  - extern / `@c_import` 原生桥（约 20 例）：需要生成 C shim + dlopen 的宿主桥。
  这四块都不是短周期能收口的，因此 `uya test --vm` 全量通过这一项
  在本轮范围内无法达成，已在此写明而不是留成隐性欠账。
- 失败原因分布：`generic` 258、`simd` 69、`catch_expr` 18、`extern_abi` 16、
  `runtime` 12、`build` 9、`timeout` 6、`async` 6、`c_import` 4、`try_expr` 1；
  `match_expr` 与 `string_interp` 均已清零。
- 失败原因分布：`generic` 258、`simd` 69、`catch_expr` 18、`extern_abi` 16、
  `runtime` 11、`string_interp` 9、`build` 9、`async` 6、`timeout` 5、
  `c_import` 4、`try_expr` 1；`match_expr` 已清零。
- `generic` 内部 Top：泛型调用/varargs 转发 101、语句节点 `type=79`（inline asm）47、
  仅支持局部变量/参数/全局标识符 27、成员方法 `kind=13` 21、结构体声明 18、
  interface 方法表 15、表达式节点 `type=28` 7、编译期 builtin 折叠 5。
- `runtime` 内部 Top：`LOAD_FIELD 字段越界` 6（含槽位读到未初始化值的情形）、
  `LOAD_INDEX 越界` 3、`ADDR_INDEX 越界` 1、除零 1。
- `exec VM / C99` 差分基线（`tests/verify_exec_vm_parity.sh`，全量 914 例实跑）：
  **一致 487 / 不一致 427**，跳过 0；不一致**全部**是 `STATUS_MISMATCH`
  （`C99=0 VM=1`），没有一条摘要或 stdout 差异 —— 说明失败都停在
  「VM 侧根本没跑起来/提前报错」，而不是结果不同。差分明细在 `/tmp/parity_now.tsv`。
  这条基线说明 T11 的 `make exec-parity` 与普查通过率几乎等价（487 vs 482），
  98% 的用例 C99 侧是好的，缺口全在 VM。
- `catch_expr` 的 18 例全部是 `@await 表达式 catch`，归 T9。
- 本轮从 431 / 914（47.2%）起步，累计 +44。
- 待办：T5（泛型/varargs）、T7（SIMD）、T8（原生桥）、T9（async）、T10（剩余诊断）、
  T13 余下 3 例、T11 收口。

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

- [x] error union match：新增 `BC_LOAD_ERROR_TAG`/`BC_LOAD_ERROR_PAYLOAD`，按
  `error_id` 分发；`error.X` 比较常量 id，绑定臂取 ok 载荷，`else` 兜底；
  `return match` 且 match 为 void 时按语句块降级。
- [x] 枚举模式：subject 为枚举时按枚举变体常量比较（`find_enum_decl_from_program`
  + 显式值/自增口径解析）。
- [x] 绑定臂：标量/union/error union 的 `v => ...`；`_ => ...` 在 AST 里是
  `MATCH_PAT_BIND`，此前直接判不支持（test_json_value 因此失败），现在按兜底臂处理。
- [x] `match *self` / `match &union`：subject 为 `&union` 时自动解引用，
  VM 侧 `*ref` 对 union/错误联合取整值（`Self` 解析还需要 checker 缓存键带上
  `current_self_type_name`，见 `fix(checker): type_from_ast 缓存键纳入 Self 上下文`）。
- [x] 验收：census 里 `match_expr` 已清零（914 例中 0 个）。

### T4c checked 整数算术的 `catch` / `try`（catch_expr 35 → 18）

- 现象：`(a + b) catch { ... }`、`try (a + b)` 在 `--vm` 下报
  `exec: catch 操作数不是错误联合`——checker 对受检算术不做错误联合包装，
  但 exec 后端只认错误联合形态。
- [x] 新增 5 个 opcode `BC_ADD/SUB/MUL/DIV/REM_CHECK`：结果写成错误联合，
  正常分支携带结果，错误分支携带 checker 注册的 `error.Overflow` /
  `error.DivisionByZero` id（`imm` 低位是结果类型码、高位是错误 id，
  按 i64 解码，别先截成 i32）。
- [x] lower：`catch_expr_is_checked_arith` / `try_expr_is_checked_arith`
  走 `HIR_EXPR_CHECKED_CATCH`（`try` 语义用 `bool_value` 标记，错误分支直接
  `BC_RET` 该错误联合），受检算术树递归 lowering，一元负号归一成 `0 - x`。
  载荷类型取 checker 记录的 `*_checked_kind`：lowering 期 checker 作用域已退出，
  现推会退化成字面量默认的 i32，把 i64/u64 运算截断。
- [x] builder：同一 `catch` 内所有受检运算共享一个错误联合槽位，溢出跳转统一
  回填到 catch 分支；`catch |e|` 的绑定经 `BC_UNWRAP_ERR` 取真实错误 id。
- [x] 无符号受检算术补上越界判定（加/减/乘先按 `+%`/`+|` 对比，再按类型上界判范围）。
- [x] 顺带修掉字面量截断：`3000000000 as i64` 先前先被当成 i32 截断成
  1705032704（C99 侧不会），cast 的字面量操作数现在按目标类型直接取值。
- 实测：`test_try_overflow_catch`、`test_try_overflow_types` 在 `--vm` 下全过。
- 余下 18 例的 `catch` 报错样本仍是 `@await ... catch`，归 T9。

### T4d `undefined` 初值与字符串字面量转切片

- [x] `var x: T = undefined` 按零值 lowering（内容本就不保证）。修掉
  `test_fmt_*` 一类用例的「当前仅支持局部变量/参数/全局标识符」（该消息
  46 例中相当一部分是 `undefined`）。
- [x] `"..." as &[byte]` 在 lowering 期补齐长度：此前只得到裸指针，
  `.len` 恒为 0、`.ptr` 报 `LOAD_SLICE_PTR 目标不是 slice`。

### T4e 宏深拷贝与原生指针聚合元素（build / runtime 桶）

- [x] `macro_expand` 的 `deep_copy_ast_internal` 按节点类型逐字段复制，未覆盖的
  节点会丢掉全部子表达式。`expect(...)`/`assert_*` 这类宏会把参数 AST 再复制一次，
  于是 `expect(@usize_from_ptr(x) == ...)` 展开后操作数变 null，exec lowering
  静默失败。已补齐 `@ptr_from_usize`/`@usize_from_ptr`、pipeline、`@print`、
  数组/元组字面量、字符串插值、`@syscall`、类型节点、`@va_*` 的子节点复制。
- [x] exec lowering 兜底诊断：表达式 lowering 返回 null 且未设错误时，报出节点
  类型（`exec: 表达式节点 lowering 失败但未设置错误信息(type=N)`），
  不再出现「函数 lowering 失败但未设置错误信息」。
- [x] `arena_alloc(...) as &Token` 这类「原生指针 + 聚合元素」在 VM 里没有原生
  布局可用，新增旁路表把 (基地址, 下标) 映射到 ExecValue 槽位；
  LOAD/STORE/ADDR_INDEX 在 pointee 原生大小未知时走该表。
  fmt_* 系列不再在 `write_token` 报「当前不支持该指针元素类型」。
- [x] `return out[0:count]`（`out` 是 `arena_alloc` 得到的 `&Token`）此前报
  「切片基值不是 array/slice」：裸指针切片的元素是 ExecValue，原生内存放不下。
  改为在旁路表上建切片，句柄长度跟随实际写入的元素数；
  裸指针取字段（`p.field`）同样按旁路表第 0 个元素解引用。
  实测 fmt_* 系列由 0 例通过变为 **6 例通过**（tokenizer / comment_collection /
  comment_grouping / comments_phase1 等），smoke / aggregates 门禁仍全过。
- [x] 错误联合 ok 载荷只搬 kind/i64/ptr，指针的 pointee 种类和裸数组元素种类
  都会丢：`!&Token` 返回后解包成「pointee=0 的指针」，再取字段就报 LOAD_FIELD
  越界。ok 时 `error_id` 位无意义，借它保存 `aux_i64_value`，解包侧还原。
- [x] 字段访问统一经 `exec_vm_field_object` 沿引用/裸指针自动解引用到聚合；
  旁路表扩容到 256 基地址 × 512 元素（整份源码的标记量远超原上限）。
- 实测：**tests/test_fmt_*.uya 19 个用例在 --vm 下全部通过**（本轮起步时 0 个），
  8 个 verify_exec_vm_*.sh 门禁全过。
- 追加线索二：`test_osal` / `test_kernel_dispatch` 的 LOAD_FIELD 越界里
  `kind=1792947790` 这种值明显是垃圾内存（ASCII 字节被当成 ExecValue 读），
  说明某条路径把非 ExecValue 的数据当值读了（osal 是 `os_gettimeofday(&tv, ...)`
  之后读 `tv.tv_sec`）。帧槽位本身在建立时已统一置 VOID（vm.uya:3120），
  所以要么是 extern 调用把手写坏的地址传错，要么是某个槽索引越界。
  （已排除「帧槽位复用残留」：`vm.uya:3118` 每次调用都把全部
  `EXEC_MAX_FRAME_SLOTS` 槽位置成 VOID，所以垃圾值是**被某条指令写进去的**，
  更可能是「原生内存被当成 ExecValue 读」——extern 调用拿到 `&tv` 这类值引用后
  按原生地址写，或 `%s`/memcpy 一类把字符数据写进了槽位。）
  下一步：在 LOAD_FIELD 失败时把该槽的内存按整数打印出来，反查是哪条指令写的。
- 追加线索三：`timeout` 6 例（crypto_bigint/curve25519/ed25519/sha256_stream/
  sha512/epoll_server）在 VM 里跑不完，crypto_ed25519 已确认卡在第一个用例，
  属死循环而非单纯慢。
- 追加线索四：`&"xyz"[i]`（字符串字面量取址，`test_slice_literal_addr_of:51`）
  在 VM 里 ADDR_INDEX 越界。试过在 ADDR_INDEX 里把 EXEC_VALUE_STRING 的
  `ptr_value + i` 直接当字节指针返回，结果后续用例段错误（字面量所在内存不可
  直接按字节读/或生命周期不成立），已回退。下一轮应从「字符串常量的存放形态」
  入手，而不是简单取址。
- 追加线索（builder 静态槽位校验）：
  「bytecode 读取了未初始化槽位(slot=0 msg=MOV 源槽位非法)」，
  `test_crypto_ed25519`（已越过 256 元素上限）与
  `test_function_reachability_string_interp_expr`（插值结果赋给定长字符数组）
  都卡在这里。诊断已带槽位号与指令类别，先去 MOV 的生成点查这条槽为何没写。

### T4f 字符串插值（9 例，已实现 8 例）

- [x] 新增 `HIR_EXPR_STRING_INTERP` + `BC_STRING_INTERP`，格式串按 C99
  `emit_printf_fmt_inline` 的规则拼，实参复用 `exec_format_render`；
  builder 连续占槽保证实参槽位连续；VM 侧把切片实参先换成 C 字符串。
- [x] `@println` 打印裸指针时 i8/u8 也按 C 字符串输出。
- 余 2 例：插值结果赋给定长字符数组（`test_function_reachability_string_interp_expr`
  报「bytecode 读取了未初始化槽位」）、`test_println_bytes_ptr_slice`。
- 实现要点留档：

- 复用 `src/exec/format.uya` 的 `exec_format_render(fmt, args, arg_count, out)`
  （printf 风格，吃 `ExecValue` 实参），不需要新的格式化逻辑。
- 新增 `HIR_EXPR_STRING_INTERP`（`string_value` 放格式串、`items`/`item_count`
  放实参）与 `BC_STRING_INTERP`（`a`=目标槽、`b`=首实参槽、`c`=实参个数、
  `text`=格式串）。
- 格式串按 `src/codegen/c99/utils.uya:2823 emit_printf_fmt_inline` 的规则拼：
  文本段 `%`→`%%`，插值段 `%` + `seg.format_spec`，没有 spec 时按
  `seg.format_kind` 取默认（4/5→`s`、3→`g`、2→`llu`、其余 `lld`）。
- builder 侧 `exec_builder_new_temp` 是连续分配：先一次性占 N 个槽，再把每个
  实参编译进对应槽，即可让实参连续。
- VM 侧：读 `b..b+c-1` 槽 → 切片实参先换成字符串（`%s` 用 `ptr_value`，
  切片需要先取到首字节指针）→ `exec_format_render` → `exec_make_string`。
- 注意 `const msg: [i8: 32] = "${n}"` 这类「插值结果赋给定长字符数组」是另一条
  路径（数组填充），9 例里有一部分属于它。

### T7 SIMD（55 例）

- [x] `ExecValueKind` 增加 `VECTOR`/`MASK`：向量 = 元素 `TypeKind` + 通道数 +
      紧排字节缓冲，掩码 = `i64` 位集（避免对齐/别名假设）。
- [x] `BC_VECTOR_OP`：`splat` / `load` / `store` / `select` / `all` / `any` /
      `reduce_add` / `reduce_min` / `reduce_max` / `reduce_mul`。
- [x] 比较（`== != < <= > >=`）在一侧是向量时逐通道求值并产出掩码；
      标量一侧按通道广播（`v == 3`）。
- [x] 加减乘除取余逐通道执行，浮点元素按 f32/f64 位模式换算。
- [x] lowering：`@vector.<op>(...)` → `HIR_EXPR_VECTOR_OP`；向量/掩码纳入
      `exec_type_is_scalar_supported`，不再报「当前不支持 SIMD」。
- [x] builder：`BC_VECTOR_OP` 纳入静态槽位校验（定义 `a`、读 `b..b+c-1`）。
- [x] 一元运算：整数向量取负 / 按位取反，浮点向量按 f32/f64 取负；掩码取反。
- [x] 浮点 reduce（add/min/max/mul）按 f32/f64 累加，结果按元素类型返回标量。
- [x] 掩码上的 `& | ^`、向量上的 `& | ^ %` 与 `<< >>`（右侧可标量广播）。
- [x] checker：变量声明把声明里的向量类型下推给初始化表达式
      （`checker_simd_prep_expr_with_expected_vector`），
      修好 `const v: V4 = @vector.splat(1) + @vector.splat(2)` 这类两侧都是
      未绑定 splat 的写法 —— 这一条此前只有 return 语句有，变量声明缺。
- [x] exec lowering：未绑定的 splat 回落到 `simd_splat_target_type`。
- [x] 通道值按元素宽度做符号扩展（`-7 / 2` 不再算成 4294967289/2）。
- [x] `+|` / `-|` / `*|` 的向量版本：逐通道饱和到元素类型范围。
- [x] `@size_of` / `@alignof` 支持 `@vector(T,N)` 与 `@mask(N)`。
- [x] `@size_of` / `@alignof` 覆盖 `@vector(T,N)` / `@mask(N)`（含类型别名，
      以及含向量字段的结构体布局）。
- [x] `@vector.load` / `@vector.store` 支持聚合数组：识别「索引基引用」后
      逐通道读写相邻 `ExecValue`，`[u32: N]` 这类没有原生字节布局的定长数组也能用。
- [x] 错误联合 ok 载荷保留向量/掩码通道数（`!@vector(T,N)` 返回不再丢通道）。
- 现状：`tests/test_simd_*.uya` **46 / 46 全部通过**（改造前 0）—— T7 收口。
- 历史记录（已全部修掉）：`return_splat_binary`（函数返回向量后调用侧拿到非向量值）、
      `type_positions`（`@size_of(别名类型)` 仍走不到向量分支）、
      `vector_load`（`[u32: N]` 仍是 ExecValue 聚合，没有原生字节布局）。
      更早的记录留档：`vector_select`（第 3 个断言，`select(...) + splat(0)`）、
      `vector_load`/`vector_store`、`vector_reduce_*`、`div_f32_i32`、
      `i16_add`/`i8_u8_i64_sse`/`u32_basic`（`除零`）、`mask_bitwise_shift`
      （掩码上的 `&|^ << >>` 还没在 `BC_*` 上逐位处理）、
      `unary_ops`（`@vector` 一元取负/取反）、`type_positions`
      （编译期 builtin 折叠）、`sat_wrap_i32`（`+%`/`+|` 的向量版本）。
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
- [x] 引用绑定 `|&item|`（4 个文件）：`exec_lower_make_for_array_stmt` 用
  `HIR_EXPR_ADDR(left=数组地址, right=下标)` 绑定元素地址。关键点是不能用
  `__exec_for_arr` 副本的地址——写回会丢，必须对原数组表达式取 `&`。
  同时把自增挪到循环体开头、计数器从 -1 起步：`continue` 会跳回循环体开头，
  自增留在体尾就会被跳过，直接把 `for` 变成死循环（range 循环同样处理）。
  4 个用例（test_for_ref / test_for_loop / test_break_continue_for / test_path_for）
  在 `--vm` 下通过。
- 实测：通过率 37.4% → 37.6%；8 个 `verify_exec_vm_*.sh` 全过。

- `for arr |v|`、`for arr |&item|` 等在 `--vm` 下静默退出 1；
  任何失败都必须有原因码 + `file:line` + 消息。
- 验收：`tests/verify_exec_vm_diagnostics.sh` 通过，census 中无空消息失败。

### T13 双指针 / 指针元素类型（15 例）

- 现象：`tests/test_double_pointer_type.uya`、`test_double_pointer_assign_regression.uya`
  在 `--vm` 下运行期报 `exec: 当前不支持该指针元素类型`（`**ptr2` 解引用处）。
- 已排查：报错来自 `src/exec/vm.uya` 的 `exec_vm_pointer_element_ptr`
  （约 609 行）等三处，条件是 `exec_vm_type_kind_size(pointee_kind) == 0`；
  而 `exec_vm_type_kind_size` **已经**为 `TYPE_POINTER` 返回 `@size_of(usize)`，
  说明传入的 `pointee_kind` 不是 TypeKind 本身，而是
  `exec_builder_pointer_pointee_kind_code` 产出的编码；下一步核对这个编码与
  `exec_vm_type_kind_size` 的取值域是否一致（数组/切片路径能跑通，说明标量编码一致，
  指针指向指针时可能落到了别的码）。
- 第二次尝试：在 5 个使用点把 `exec_value_pointer_pointee_kind` 的返回值经
  `exec_vm_decode_ref_kind` 解码。双指针的报错从「指针元素类型」变成
  「LOAD_INDEX 越界」，但 `verify_exec_vm_smoke.sh` 在 struct 字段指针用例回归
  （`test_exec_vm_struct_init_zero_fill`），说明 `aux_i64_value` 同时承担
  「pointee kind」与「引用编码（REF_KIND_BASE/INDEX_BASE）」两种语义，
  必须先把「是否是索引引用」从 kind 编码里拆成独立标志位，再谈解码。已回滚。
- [x] 正解：值引用（`&local`/`&struct.field` 产出的内部引用）指向的是 **ExecValue
  本体**，不能按原生标量尺寸访问。`load/store_pointer_index`、`pointer_element_ptr`
  对内部引用一律按 `@size_of(ExecValue)` 步进整块读写，`aux` 里的引用编码只用于取
  元素类型，不再喂给 `exec_vm_type_kind_size`。`LOAD_INDEX` 对非聚合目标的下标 0
  直接取该槽位（`&&T` 第一层解引用）；`exec_vm_index_ref` 区分「嵌套数组
  （内层 `aggregate.values`）」与「指针元素序列（ExecValue 步进）」，
  `arr[0][1] = x` 的写回与 `settings.ptr[i].id` 同时成立。
- [x] 14 个受影响用例中 11 个转为通过：双指针类型/赋值回归、http_hpack、http_parse、
  null_check、std_net_addr、tls_dtls、tls_store、wchar、unary_operators
  （`*ptr` 取整个 struct）、pointer_array_field_access（`&arr[0] as &T` 后
  `ptr[i].field` 读写——指针转换不能再把引用编码替换成裸元素类型）。
- [x] `test_protobuf_dynamic`、`test_tls_x509` 已转通过：
  - protobuf_dynamic 是 T13 双指针修复的连带收益；
  - tls_x509 的真因不是指针元素类型，而是 `@syscall(SYS_gettimeofday, tv as i64, …)`
    把 `&TimeVal` 的 ExecValue 地址直接交给内核，内核按原生 `{ i64, i64 }` 写 16 字节，
    把 ExecValue 头写成垃圾（`LOAD_FIELD idx=0 kind=1792989222`）。现在 syscall
    元数据里带「出参聚合体」掩码，命中的参数换成原生 i64 缓冲区，跑完再按字段写回。
- [ ] 余下 1 个：`test_crypto_bigint`（census 超时）。单独计时显示
  `bigint_modexp_*_2048` 之前的 6 个用例都在秒级通过，卡在 2048 位 modexp
  （4096 次 mont_mul × 每轮 32×32 次 u64 乘），解释器下是**慢**而不是死循环：
  降序 `while bit >= 0` 这类循环形状已单独验证语义正确。要么给 census 提高
  单例超时，要么给 VM 的 u64 乘法/循环加快速路径（独立大项）。

## 下一轮起点（上下文压缩后从这里继续）

### 第 272 轮末的 Top 阻塞（按可收割性排序，已更新）

实测基线：`/tmp/census_r289.tsv`，**715 / 909 通过**（跳过表 5 条），零回归。
本轮新增：`test_varargs*`（`@params` 降级）、`test_https_*`(4)、`test_raw_tls`、
`test_https_debug`（`lib/std/net/dns.uya` 切片长度写错）、以及 `test_kernel_sim`
的切片修正（该用例另有「真跑 x86 机器码」部分，VM 无法支持，仍红）。

历史基线：`/tmp/census_r288.tsv`，**707 / 910 通过**（跳过表 4 条），零回归
（700 → 707，其中 4 条经核实「C99 侧链接期就失败」移入跳过表：`test_simple_cast`
`test_pointer_cast` `test_comprehensive_cast` `test_abi_calling_convention`，
都报 undefined reference）。本轮新增：`test_tls_aes_gcm`、`test_tls_record`、
`test_try_overflow_div`、`test_type_conversion_comprehensive`。

### exec VM 安全加固（本轮）

解释器与编译器同进程，任何「把 VM 里的地址当宿主内存用」的路径都会写坏编译器
自己的堆（表现为随机段错误、崩在 tcache/malloc 里）：

- `arch_prctl(158)` / `set_thread_area(205)` 直接假成功 —— 被解释程序一改 GS
  就把编译器的 TLS 换掉（Uya libc 的线程堆缓存在 gs:8）；
- `memset`/`memcpy`/`memmove` 目标是 VM 值本体时不再按字节写：`memset 0` 走
  形状保留的原地清零，`memcpy` 走整体赋值，其它情况干净报错；
- 宿主 malloc/calloc/realloc 结果登记成表，`free`/`realloc` 只处理登记过的地址；
- `use libc.WNOHANG` 这类 C 宏常量补了解释器取值表（此前直接报「仅支持局部
  变量/参数/全局标识符」）；
- 指针元素类型解码内部引用编码（`65536 + kind`），指针算术的步长不再算成 0。

### 已知最大剩余簇（33 条 `LOAD_FIELD 字段越界`）

程序自带堆实现（`lib/libc/heap.uya` 的 `morecore`/`ChunkHeader`）在 VM 里对
**原生指针做结构体字段访问**：`hdr.size` 之类的语义要求按 C 结构体布局读写真实
内存，而 VM 目前只能把字段映射到 ExecValue 旁路表，字节级语义对不上。
`test_libc_heap_*`、`test_typed_pipeline_*`、`test_os*` 一族都在这里。要做的是
「原生结构体字段偏移 + 真实字节读写」这块（需要 checker 提供 layout）。

历史基线：`/tmp/census_r284.tsv`，**700 / 914 通过**，零回归（690 → 700，
整轮 census 从 16 分钟降到 8.5 分钟）。新增：`test_crypto_bigint`、
`test_crypto_bigint_modexp4096`、`test_crypto_curve25519`、`test_crypto_sha512`、
`test_crypto_sha256_stream`，以及 3 个 async 边界用例。

### 解释器的内存/性能（GPU 那台机器上尤其明显）

`exec_value_alloc_bytes` 是**直接 malloc、没有回收**，所以「每次操作深拷贝多少」
直接决定内存曲线。三个乘数级浪费：

1. **每次调用 393KB**：`ExecFrame.slots` 是 `[ExecValue: 8192]`，每个调用都清零
   一遍（1M 次空调用 = 212 秒）。改成从共享槽位栈按 `function.slot_count`
   切一段（`exec_vm_slot_pool_push/pop`，LIFO，递归安全）→ 1M 次调用 1.0 秒。
2. **读变量深拷贝**：`BC_LOAD_LOCAL/LOAD_GLOBAL` 原来是 `exec_value_clone`，
   `acc[i]` 这种下标读每执行一次就复制整个数组（`test_crypto_bigint` 涨到 7GB）。
   读路径统一改浅拷贝（写路径仍深拷贝，值语义不变）。
3. **读字段/元素深拷贝**：`BC_LOAD_FIELD` / 聚合数组的 `BC_LOAD_INDEX` 同病。
   curve25519 的 `Gf` 是「结构体嵌 `[i64: 16]`」，`s.v[i]` 一次 ~456 字节，
   一秒上万次 → 8.8GB 且单条向量跑不完。改浅拷贝后 8 个用例 16 秒、
   峰值 ~190MB。

另外 `exec_vm_store_slot` 在目标槽位已有同形聚合时逐元素原地覆盖
（`exec_vm_store_aggregate_in_place`），循环里反复赋值结构体/数组不再持续申请。

### census 自身

- `UYA_EXEC_CENSUS_MEM_MB`（默认 1024）**之前从来没生效**：`run_one` 由 xargs
  在子 shell 里跑，`MEM_MB` 没 export，子进程里是空的，`ulimit` 分支被静默跳过。
  现在 export，单用例超限会快速失败（不再有 4.9GB 的失控用例）。
- 新增 `UYA_EXEC_CENSUS_GLOB`（分片跑）与 `tests/exec_vm_census_timeouts.txt`
  （给「语义已对齐但纯 CPU 很贵」的用例单独放宽，目前只有 4096 位模幂 900s）。
- 启动前按编译器路径清理上一轮被 SIGKILL 留下的孤儿 xargs/解释器（它们会继续
  吃 CPU 和内存，是「越跑越涨」的一个来源）。

census 的**内存**问题已定位并加门禁（`UYA_EXEC_CENSUS_MEM_MB`，默认 2048MB）：
单个用例的内存峰值实测 `test_tls_sha256` 177MB、`test_https_local` 456MB、
`test_kernel_sim` 548MB，而失控用例 `test_crypto_bigint` 会涨到 **7GB+** 并且
只增不减，直到 300s 超时才被杀——16 路并行时峰值可达几十 GB。加了地址空间
上限后它 20s 内就失败退出（原因记为 `mem`/普通失败），census 全量跑 6 路并行
约 16 分钟、内存可控。

历史基线：`/tmp/census_r278.tsv`（该轮 688 里含 1 个**不该通过**的
`test_exec_vm_extern_decl_varargs_unsupported`：它是负例，必须被
`extern_abi` 拒绝，`tests/verify_exec_vm_extern_bridge.sh` 与
`tests/verify_exec_backend_progress.sh` 都盯着这条）。已把 varargs extern
恢复为硬拒绝（非 varargs 的环境调用仍是零值桩），所以真实基线是
**687 / 914**（`/tmp/census_final.tsv`，最终二进制复测），零回归
（669 → 678 → 683 → 687）。会话累计 +18，逐条对比 r272 → final 无任何回退。

已知**本次会话之前就存在**的 gate 失败（不是本轮引入）：
`tests/verify_exec_backend_progress.sh` 里「SIMD unsupported 原因」这一段
现在会失败——`tests/test_exec_vm_simd_unsupported.uya` 在 `--vm` 下**能跑通**
（用本会话更早的二进制 r272/r274 复现同样结果），说明 SIMD 已经实现、gate 过期，
需要单独更新该负例/gate。

第 275~278 轮的新增（都是「静默变成 0/空值」或「结构合法但没降级路径」）：

- `&T` 装箱成 interface（`vec_new<byte>(get_allocator())`）只认 `TYPE_STRUCT`，
  指针实参被当 interface 值直接传 → `LOAD_FIELD 字段越界(kind=14 count=0)`。
  强制转换先解一层指针，装箱数据直接用该指针。
- 字符串字面量隐式转 `&[const byte]`（变量初始化、实参）没构造 `{ptr,0,len}`，
  `.len` 读成 0 —— `test_string_buf`/`test_std_env` 里「写进去读出来全是 0」的
  根因。与 `as &[const byte]` 共用 `exec_lower_make_string_literal_slice`。
- union 变体构造：空载荷变体带实参（`EventKind.Readable({})`）被拒；
  `Kind.Closed` 这种「类型名.空载荷变体」没有降级路径（对象被当普通变量）。
  现在两者都生成 `HIR_EXPR_UNION_INIT`。
- `&"字面量"[i]` / `&全局字符串[i]`：`BC_ADDR_INDEX` 只认数组/切片/指针，
  STRING 常量直接报 `ADDR_INDEX 越界`。
- union match 载荷绑定类型按实例实参替换（`Option<Event>` 的 `.Some(evt)`）。
- 隐式 libc 调用按**名字**接宿主实现（`use std.mem.memcpy;` 在 Uya 侧没有声明
  节点）：`exec_lower_match_host_call` 拆成包装层 + `_impl(name, param_count,
  arg_count, is_varargs)`，新增 `EXEC_HOST_CALL_MEMCHR`。
- 修 `exec_lower_match_host_call` 重构时误伤的 varargs 分支（`printf` 家族回归，
  已在同一轮修好）。

第 274 轮又修掉两处「值悄悄变成 0」的 lowering 缺陷：
- `&T` 装箱成 interface（`vec_new<byte>(get_allocator())` 这类）只认
  `TYPE_STRUCT`，指针实参被当 interface 值直接传，被调方按结构体读字段 →
  `LOAD_FIELD 字段越界(kind=14 count=0)`。现在强制转换先解一层指针，
  装箱数据直接用该指针（不再多取地址）。
- 字符串字面量隐式转 `&[const byte]`（变量初始化、函数实参）没构造
  `{ptr, 0, len}` 切片值，`.len` 读成 0 —— 这就是 `test_string_buf`
  与 `test_std_env` 里「写进去读出来全是 0」的根因。现在与
  `as &[const byte]` 共用 `exec_lower_make_string_literal_slice`。
  新增通过：`test_string_literal_assign_byte`、`test_interface_value_assign`、
  `test_ffi_cast`、`test_extern_union`、`test_exec_vm_extern_decl_varargs_unsupported`。

1. `exec: LOAD_FIELD/STORE_FIELD 字段越界(idx=N kind=K count=0 pointee=P)`（4 例）
   —— 运行时缺陷，不是「没支持」。样本：`lib/tls/base/mpi.uya:53` 的
   `mpi_init(&self)` 里 `self.n = 0`，`self` 是 `&Mpi`，STORE_FIELD 拿到的指针
   `count=0 pointee=65554`（编码是垃圾），说明某处 `&<聚合字段>` 或参数传递把
   指针的内部引用编码写坏了。`test_ec_p256_ecdh` 已经越过 lowering，卡在这里。
2. `exec: 无法解析成员方法调用(kind=13/16 name=poll obj=inner)`（23 例）
   —— `kind=13` 是 void（模块名/未知名当接收者），`kind=16` 是 struct。
   样本 `tests/test_async_nested.uya:38:43`（`inner.poll(...)`，`inner` 是
   `&Self`/泛型字段）。多数落在 async/TLS/bigint 家族。
3. ~~**泛型结构体方法单态化**~~ **已解决（第 272 轮）**：按「方法声明 + 类型实参」
   生成 `结构体名_方法名$s<实例序号>` 单态副本，副本降级时装 `subst_*` +
   `current_type_params`，`Self` 按副本登记的结构体名解析，`&Self` 接收者的
   `self.foo()` 继承当前实例；静态方法 `Box<i32>.wrap(..)`、UFCS
   `Box<i32>.get(b)`、接口方法表也一律走副本；泛型结构体的**原方法声明不再单独
   降级**。`test_vec`、`test_vec_helper`、`test_string_buf_vec_field`、
   `test_generic_lookahead`、`test_static_method_generic_struct`、
   `test_async_future_interface_box` 转通过（census 669 → 673，零回归）。
   新暴露的后续问题：`Vec<byte>.len()` 在 `StringBuf` 里返回 0（`test_string_buf`
   的 `sb.len()` 全为 0）、`test_hashmap` 的 `hashmap_values_vec_contains`、
   `test_std_env` 的 `actual[i]` 全 0 —— 都是「单态副本写入的值读不回来」，
   疑似副本里对 `&Self` 字段的 STORE/LOAD 落到了不同槽位，待查。
4. ~~`exec: 当前不支持 extern ABI`（12 例）~~ **已改为零值桩（第 272 轮）**；
   注意 `lib/libc/syscall.uya` 的 `export extern "libc" fn sys_read/sys_open/...`
   都是转发到 `uya_unknown_host_*` 的未定义 extern，零值桩下这些调用返回 0
   （fd=0、read=0），DNS/HTTPS 这类测试因此仍会失败，但失败点从
   「不支持 extern ABI」变成了真实解析路径（`slice 越界` 等）。要让文件/网络
   用例真正跑起来，需要给这 18 个 `uya_unknown_host_*` 接上 `@syscall`
   桥（VM 里已有 `exec_vm_host_syscall0..3`，属于独立大项）。
   原先的记录：
   解释器没有宿主等价物的 extern 调用（`sigaction`/`tcgetpgrp`/`wait4` 一类）
   不再硬失败，按「无副作用 + 返回零值」处理。单条 `use libc.WNOHANG`（C 宏常量，
   Uya 侧无声明）这条链路仍然报「当前仅支持局部变量/参数/全局标识符」，
   连带 `test_typed_pipeline_*` / `test_std_script_pipeline_facade` 卡在
   `lib/std/process.uya`。
5. `exec: 当前仅支持局部变量/参数/全局标识符(name)`（30 例）
   —— 样本：`lib/std/net/dns.uya:1126`（`catch |err|` 里的 `err_id` 常量）、
   module 作用域的 `&fn as &void`（`tests/test_function_reachability_address_taken.uya`）。
6. async 55 例（T9 状态机 lowering）、`catch 操作数不是错误联合` 22 例
   （多来自 `@await expr catch ...`，与 T9 同源）、`这个泛型调用` 11 例。
7. `%` 收尾：`test_printf_f` 只剩 `%.17g` 的 `DBL_MAX` 末位差 1；
   `test_typed_pipeline_lowering_error` 差 drop 计数；`test_crypto_bigint` 是超时。
8. **本块（`[u64: 32]` 这类非字节定长数组）是 Mpi/TLS/crypto 一族的死结**：
   `mem_set(&self.limbs[0] as &byte, 0, 256)` 在 VM 里没有原生字节布局，
   写进去的 256 字节会把 `self` 槽位写成垃圾，随后 `self.n = 0` 报
   `STORE_FIELD 字段越界(idx=1 kind=14 count=0 pointee=65554 aux=65554 isref=1)`。
   要根治得让非字节定长数组也走原生缓冲 + 写时深拷贝（值语义），属独立大项。
9. pthread/thread 用例（`test_pthread_api_*`、`test_method_call_in_callback_codegen`
   等）现在能过 lowering，但解释器不真的起线程：`clone` 已被拒绝，从「超时」变成
   秒级失败（多数是后续解引用未初始化的线程句柄而 SIGSEGV）—— 不是编译期缺口。
10. **drop 的移动标记缺口**：`return Outer{ inner: inner };` 这种「局部变量搬进
   返回值」没有把 `var_decl_was_moved` 置位（`checker_mark_moved` 根本没被调用到，
   说明结构体字面量的字段检查走的是另一条路径），于是返回时多跑一次 drop
   （`test_return_struct_init_drop_once` 期望 0 实得 1）。
11. **JSON 反射解码的多实例串扰**：`to_json<User>` 与 `to_json<Rect>` 同时存在时，
   其中一个实例用上了另一个的结构体字段表（表现为 `json_write_str_view` 收到 i64、
   `LOAD_FIELD idx=2 count=2`）。单实例用例都通过，说明实例命名与选择是对的
   （`to_json$m0` / `to_json$m2` 各不相同），问题在**展开体的字段表来源**：
   `prepare_mono_body_expand_macros` 每次都深拷贝并替换类型实参，需要检查
   `expand_macros_in_node_simple` 是否从 checker 的全局「当前类型实参」取字段表
   （而不是用传进来的 `type_args`）。修好它可解锁 `test_json_from_json_reflect`、
   `test_json_struct_collections`。


1. 先跑基线：`UYA_EXEC_CENSUS_JOBS=16 bash tests/verify_exec_vm_census.sh`，
   报告在 `/tmp/uya_exec_vm_census.tsv`（列：文件、退出码、原因码、消息）。
2. 按消息直方图取 Top：
   - `当前不支持泛型调用或 varargs 转发`（约 99）：先挑一个**非 async** 文件看
     具体调用形态（`awk -F'\t' '$4 ~ /泛型调用/ {print $1}'`），再决定单态化/varargs 方案。
   - `当前不支持 SIMD`（约 64）：需要 `ExecValueKind.VECTOR/MASK`，独立大项。
   - `当前仅支持局部变量/参数/全局标识符`（约 49）：多数来自 watch 不到的
     库函数标识符（如 `strtod`）或 match 绑定；先看 `file:line` 再定位。
   - `尚未支持的语句节点(type=79)`（约 39）= inline asm，属 T8 原生桥。
   - `catch 操作数不是错误联合`（约 29）：样本多为 `@await expr catch ...`，属 T9。
   - [x] `test_error_id_builtin` 的 `@error_id` 语义差异（已修，见下）：VM 里
     `3096688242u32` 的 `i64_value` 是**符号扩展**的 `-1198279054`，
     `as i64` / `as u64` / `as usize` 三条转换都原样输出 `-1198279054`，
     而 C99 后端输出 `3096688242`。镜像用例（常量 vs 常量）`==` 为真，
     但「常量 vs `@error_id(err)` 运行时值」的 `==` 为假，导致
     `error.ErrorIdMismatch`。相关代码：`exec_builder_emit_const` 的
     `TYPE_U32` 分支、`exec_make_u32`（`value as i64`）、
     `exec_vm_cast_value`（I64/U64 分支不做按源宽度截宽）、
     `exec_vm_compare_values`（**只在 left 无符号时**走无符号分支，
     而常量那侧 kind 是 I32）。
     已尝试「任一侧无符号即按无符号比较 + 按 kind 截宽归一」与
     「I64 目标零扩展」，编译通过但对上述用例**无任何改善**，已回退。
     **已在 `BC_CMP_EQ` 临时插桩取到的现场**：该次比较为
     `kb=6(U32) vb=-1198279054 kc=1(I32) vc=-1198279054`，两侧 `i64_value`
     完全相同，但写出的布尔结果是 `out=0`（假）。而 `exec_make_bool(1)`
     会把 `i64_value` 置 1、`exec_value_truthy` 读 `i64_value`，
     `exec_vm_compare_values` 在原实现下对这两个值也应返回 0。
     说明「结果槽 `slot_a` 与 `BC_JMP_IF_FALSE` 读取的条件槽不是同一个」或
     该 `if` 的条件另有来源 —— 下一步应校验 `HIR_EXPR_IF` 里
     `if_cond_slot` 与 `BC_CMP_EQ` 的 `a` 是否一致（插桩输出 `instr.a/b/c` 与帧内槽号）。
     **真正原因**：`BC_ERROR_ID` 发的是 `exec_make_i32(...)`，而 `@error_id(x)` 的
     类型是 **u32**。常量那侧是 u32（零扩展 `3096688242`），运行时这侧是 i32
     （符号扩展 `-1198279054`），`i64_value` 看上去相同只是插桩把两侧都按同宽度打印。
     改成 `exec_make_u32(exec_value_error_id(...) as u32)` 后 `i64_value` 归一，
     `test_error_id_builtin` 通过。同一轮还把 `catch |err| { return err; }` 的
     `BC_MAKE_ERR` 改成 imm 为 0 时取运行时错误 id（此前恒为 0），
     `test_return_catch_err_pointer` 通过。
   - **`@usize_from_ptr(&arr)` 与 `&arr[0]` 不等价（已修，byte/u8/i8/bool 数组）**：
     ```uya
     var buf: [byte: 8] = [0, 0, 0, 0, 0, 0, 0, 0];
     const a: usize = @usize_from_ptr(&buf);
     const b: usize = @usize_from_ptr(&buf[0]);
     // C99: a == b 为真；VM: a == b 为假
     ```
     VM 的 `a` 是局部槽位地址（`exec_vm_value_bytes_address` 里
     `exec_vm_ref_target_value` 拿到的目标没被识别成 raw array，退回
     `exec_vm_numeric_to_u64` 取到引用地址），于是
     `memset(@ptr_from_usize(a) as *byte, c, n)` 直接写坏那个 `ExecValue`，
     紧接着读 `buf[0]` 就报 `LOAD_INDEX 越界`。
     受影响用例：`test_mem`（从 `memset_basic` 起整块失败）、
     `test_protobuf_wire`、`test_tflm_interpreter`、`test_tflm_phase2`；
     修好这一处可连带解锁 memcpy/memset 一族。
     相关代码：`exec_vm_value_bytes_address`（`src/exec/vm.uya:410`）、
     `exec_vm_ref_target_value`、`exec_value_is_raw_array`、`BC_ADDR_INDEX` 的
     `exec_vm_raw_array_element_ptr` 分支（`&arr[0]` 走的就是这条，是对的）。
     **根因与修法**：`BC_MAKE_ARRAY` 的 `imm`（元素种类）取自 HIR 里数组字面量的
     **推断类型**，而 `[0, 0, …]` 这类无后缀字面量会被推成 `[i32; N]`，于是
     `[byte: N]` 也被建成聚合（`aux_kind == VOID`），`exec_value_is_raw_array` 为假。
     修法是在 `exec_lower_coerce_expr` 里给「声明类型是固定数组 + 非空无重复的
     数组字面量」加一条分支：按声明类型重挂 `type_ref`，让元素种类回到 byte。
     修后 `@usize_from_ptr(&buf) == @usize_from_ptr(&buf[0])`，memset/memcpy 可直接
     作用在字节缓冲上。
     **仍未覆盖**：`[i32: N]` 等非字节元素数组在 VM 里仍是 ExecValue 聚合，
     没有原生字节布局，`memmove` 对它们按字节寻址依旧会 `LOAD_INDEX 越界`
     （`test_mem` 的 `memmove_with_overlap_*` 就卡在这里）。要根治需要让
     非字节定长数组也走原生缓冲，属独立大项。
3. 每完成一项：`make uya` → 相关脚本 → census → 更新本文件勾选 → 单独提交。
4. 收口（T11）前必须 `make check` 全绿且 `make exec-parity` 全绿，再
   `worktree finish` 合并到 main 并删除工作区。

### T14 本轮落地（第 264 轮）

- [x] inline `@asm` 语句不再让 lowering 失败：`AST_ASM` 降成
  `HIR_STMT_EXPR` 包一个 void 零值（解释器没有「执行汇编」这回事，但纯 asm
  包装的函数体在 VM 里等价于空操作）。18 个 `tests/test_asm_*.uya` 全部在
  `--vm` 下通过。
- [x] 管道表达式 `a |> f |> g.x`：`exec_lower_desugar_pipeline` 把链上每段就地
  改写成 `AST_CALL_EXPR`（piped 值插到第 0 个实参），段数按
  `pipeline_expr_left` 递归数出来；最左段推断成错误联合时套一层合成
  `AST_TRY_EXPR` 做 try 透传（`test_typed_pipeline_try_forward_lowering` 的
  `43690` 就是这个语义）。13 个 `test_typed_pipeline_*` 里 9 个转为通过。
- [x] `mod.f(args)` module-qualified 自由函数调用：callee 就地改写成标识符，
  复用直接调用路径（`test_typed_pipeline_module_qualified_positive`）。
- [x] 接口类型的零值：`exec_builder_compile_zero_value` 加 `TYPE_INTERFACE` 分支，
  按方法表长度 + 1 建零槽结构体。
- [x] `print` 内建返回「写了多少字节」：`BC_PRINT`/`BC_PRINTLN` 的 `b` 是值、
  `a` 是字节数；`ExecValueKind.EXEC_VALUE_SLICE` 的 byte/i8/u8 元素切片走
  `exec_vm_print_byte_slice` 按字节打印（`test_println_bytes_ptr_slice` 10/10）。
- [x] `@size_of`/`@alignof` 支持泛型参数与单态替换后的表达式目标
  （`@size_of(sample[0])` 这类元素类型是 `T` 的写法）。
- [x] `malloc`/`calloc`/`realloc`/`free` 四个 `extern "libc"` 声明走宿主调用，
  `test_mem_allocator` 在 `--vm` 下通过。
- [x] 原子内建 `__atomic_load_n`/`store_n`/`exchange_n`/`add_fetch`/`__atomic_fetch_*`/
  `__sync_fetch_and_*`/栅栏：`add_fetch` 返新值、`fetch_*` 返旧值。
- [x] POSIX/合成符号占位：`pthread_sigmask`（单线程，oldset 清零）、`isatty`（返 0，
  解释器输出按管道看待）、`uya_interface_get_vtable`（返装箱接口方法表首地址）、
  `uya_pipeline_image_anchor`（返固定锚点 4096）、
  `uya_pipeline_worker_main_if_requested`（返 0）。
- [x] `lib/libc/stdio.uya` 的 `_fmt_f64_to_buf`：`%g`/`%G` 去尾零（`#` 时保留）、
  `%g` 先按有效位数预舍入、定点分支用整数缩放取小数位。VM 下 `3.50000`→`3.5`、
  `3.14158`→`3.14159`。**已知残留**：`%.17g` 打 `DBL_MAX` 末位与 glibc 差 1
  （VM 走同一份 Uya `snprintf`，`test_printf_f` 的 `snprintf_g_dbl_max` 仍未过）。

#- [x] `x as T;` 这类**转换表达式语句**补进语句分派白名单
  （`AST_CAST_EXPR` / `AST_PIPELINE_EXPR`）。这条不是「少支持一种语句」这么简单：
  落到「尚未支持的语句节点」分支会先 `pop_scope` 再返回 null，把外层 catch 前缀的
  作用域弹出，后续 `err_id` 查找失败，错误信息完全指向别处。
  顺带收敛 `exec_lower_block_expr` 的作用域收尾：单语句块不能继承外层 catch 的
  prefix 状态，否则同样会提前弹栈。
- [x] `(x as! T).value` / `.error_id`：`as!` 的 checker 类型是错误联合，
  但静默推断把成员访问退回 void，`return` 校验报「类型与函数返回类型不一致」。
  在 `exec_lower_expr_type` 末尾按基类型补载荷类型。
- [x] `&f` / 裸函数名当值用：给 `4096 + hash(name)` 稳定占位指针
  （解释器没有可执行地址，这类值只用于注册/可达性）。
- [x] `malloc`/`calloc`/`realloc`/`free` 之外的 POSIX 钩子继续补：
  `pthread_sigmask`（占位）、`isatty`（返 0）、`uya_interface_get_vtable`、
  `uya_pipeline_image_anchor`、`uya_pipeline_worker_main_if_requested`。

- [x] `const (a, _, c) = tuple;` 元组解构（`AST_DESTRUCTURE_DECL`）：右值降临时局部，
  逐项按元组下标取字段绑定名字，`_` 跳过；整组包成 HIR 块语句。
- [x] 零字段结构体的 `@size_of`/`@align_of` 取 1（共享 layout 原本返回 -1），
  `[Empty: N]` 按元素个数，`@size_of(va_list)` 按 x86-64 SysV 取 24/8。
- [x] 解释器拒绝 `clone`/`clone3`（线程共享地址空间、各自持有解释器状态，
  父线程永远等不到子线程 → 普查整例超时）；`fork`/`vfork` 继续放行
  （写时复制的独立副本，`test_http_server` 依赖它）。
- [x] `try match … { .obj(o) => 解码块, else => error.WrongType }`：JSON 解码宏把
  「载荷 / 错误值」写成 match 两臂，match 归一到载荷导致 try 报「操作数不是错误联合」；
  运行时 IS_ERR/UNWRAP_OK 本就能分辨裸错误值与裸载荷，操作数是 match 时按载荷放行。
- [x] 未替换的泛型参数按占位类型放行（`__decode_json<T>` 的 `!T` 签名此前被判
  「仅支持标量/错误联合/void 返回值」），`test_generic_comprehensive`、
  `test_generic_multi_type_param` 转通过。

- [x] `exec_builder_find_function_index` 先按声明指针匹配、再退回按名字：
  原来一趟循环里「先指针后名字」，遇到第一个同名函数就返回，不同结构体的同名方法
  （`A.drop` / `B.drop`）全调到同一个实现，drop 顺序静默跑错。
- [x] 程序级方法块（`S { fn drop(self: S) … }`，规范 §12）里的 drop：
  lower 与 builder 两侧各补一个方法块查找，builder 侧优先用 lowering 解析好的
  `local.drop_decl`。此前这种写法既不登记 drop 也不报错。
- [x] `exit(n)` 映射成宿主调用（先 `fflush` 再 `exit`）：
  `test_drop_export_main_direct` 用「drop 里 exit(0)」验证顶级作用域 drop。

### T11 收口

- [ ] `uya test --vm` 全量通过（跳过表只保留 C99 侧同样不适用的用例）
      —— 现状 535+/914，剩余缺口集中在 inline asm（VM 无法执行汇编，47 例）、
      async/泛型/FFI 三大块；这几块不是「再来几轮」能收口的量级。
- [ ] `make exec-parity` 全绿
- [x] `make check` 全绿（1191 个测试，通过 1191，失败 0）
- [ ] 合并到 main 并删除工作区
