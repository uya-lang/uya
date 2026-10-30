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
- [x] 余下 1 个：`test_crypto_bigint` —— 已通过（见下）。census 里仍靠
  `tests/exec_vm_census_timeouts.txt` 把它放宽到 900s。单独计时显示
  `bigint_modexp_*_2048` 之前的 6 个用例都在秒级通过，卡在 2048 位 modexp
  （4096 次 mont_mul × 每轮 32×32 次 u64 乘），解释器下是**慢**而不是死循环：
  降序 `while bit >= 0` 这类循环形状已单独验证语义正确。要么给 census 提高
  单例超时，要么给 VM 的 u64 乘法/循环加快速路径（独立大项）。
  **已解决**：真因不是慢，而是 `exec_vm_store_slot` 每次读局部变量都把整个
  `[u64: 32]` 数组深拷贝（`acc[i]` 一读就是 256 字节 × 每轮上千次），峰值
  7 GB、超时。改成局部/全局/字段/下标读一律「浅装入槽位」+ 聚合原地复用
  缓冲后，整份用例 41 MB、数秒内通过（`test_crypto_curve25519` 同类问题，
  8.8 GB/不结束 → 190 MB/16s）。

## 下一轮起点（上下文压缩后从这里继续）

### 第 273 轮：剩余 194 条的点因归类（可收割的都收完了）

按失败信息聚类（`/tmp/census_r289.tsv`），194 条全部落在四个架构项上，没有
「一条一改」的散点了：

| 条数 | 失败信息 | 真因（架构项） |
| --- | --- | --- |
| 85 | `当前不支持 async` | A. async/`@await` 状态机 |
| 29+5 | `LOAD_FIELD/STORE_FIELD 字段越界` | B. 原生内存按结构体布局字节读写 |
| 8 | `仅支持局部变量/参数/全局标识符`（`_uya_async_frame_*`） | A |
| 4 | `不支持这个泛型调用`（dns/mqtt async 封装） | A |
| 4 | `不支持未初始化局部变量`（async frame） | A |
| 3 | `不支持 @c_import` | C. 运行期编译并加载 C |
| 2 | `LOAD_INDEX 越界`（`test_mem` 重叠 memmove、`test_std_env`） | B |
| 13 | 断言失败（`pthread_*`） | D. 线程模型（VM 单线程） |
| 3-4 | 断言失败（`*_drop_once`、`nested_field_move`、`string_buf`） | B 的移动置零语义 |
| 1 | `test_printf_f`（`%#.17g` DBL_MAX） | 常量/格式化末位差 1-2 ULP |
| 1 | `test_kernel_sim` | 真跑 x86 机器码，VM 无法支持 |

结论：`make exec-parity` 全绿（T11）必须等 A/B/D 之一先落地，本轮把能独立
验证的语义缺陷（byte 截断、受检整除的 Overflow/除零 id、`@params`、
`dns`/`kernel/sim` 切片长度）全部收掉，并保持 707 → 715 零回归。

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

### 第 274 轮：原生结构体字段访问的试验结论（未落地，已回滚）

这一轮试了「结构体字段按 C99 布局读原生内存」，实现完整但**验证不过，已整体回滚**，
结论和后续做法记在这里，避免下一轮重复踩坑：

- 落地过的部分：`exec_lower_native_field_layout()`（按对齐累加算出字段字节偏移与
  kind/pointee kind）、`HIR_EXPR_FIELD` 用 `unary_op`=偏移、`binary_op`=kind+1|pointee+1<<8
  携带布局、builder 打包进 `LOAD_FIELD`/`STORE_FIELD`（`c`=偏移，`imm` 高 32/40 位放
  kind 与 pointee kind）、运行时 `exec_vm_native_field_load/store`（i8..u64/usize/f32/f64/
  pointer）。聚合路径失败后回落到原生布局。
- 阻塞点：**运行时无法区分「VM 值引用」和「`@ptr_from_usize(addr) as &T` 造出来的
  引用」**。指针 cast 会把 typed pointer 一律编码成 `65536+pointee` 的内部引用，
  于是两者形状完全一样。按「聚合句柄是否成立」判定的结果是：`lib/libc/heap.uya`
  的 `hdr.size` 能读出来，但读到的常是 `0xDEADBEEF` 之类填充值，随后
  `STORE_FIELD` 往低地址写（`0x6975xxx`）直接段错误。`test_libc_heap_*`、
  `test_string`、`test_stdio`、`test_stdlib` 全部崩在同一个点。
- 第二轮试验（加了 `ADDR_FIELD` 原生回落、`LOAD_FIELD`/`STORE_FIELD` 失败后回落、
  builder 打包偏移）确认了**真正的根因链**：原生指针一旦经过 `ADDR_FIELD`
  就被包装成 VM 值引用（`exec_vm_make_value_ref`），此后整条链路上的
  `&chunk.header` / `hdr.size` 都落在 VM 旁路聚合上，字节语义丢失。
  用「目标聚合是否成立」当判据不够：堆内存随便几个字节就能凑出 `count >= 0`
  的假聚合，于是原生回落不触发，行为还是错的（`test_string` 读到 `0xDEADBEEF`）。
- 下一轮的正确做法（按优先级）：
  1. **指针来源（provenance）必须在创建处决定**：`@ptr_from_usize`/整数 cast 造出的
     指针、以及任何从它派生出来的 `ADDR_FIELD`/`ADDR_INDEX`/cast，都保持「原生指针」
     编码（`aux = pointee kind`，不带 65536），只有 `ADDR_LOCAL`/`ADDR_GLOBAL`/
     `ADDR_FIELD`(对 VM 聚合)/`ADDR_INDEX`(对 VM 聚合) 才产 65536+ 的值引用。
     要做到这一点，`ADDR_FIELD`/`ADDR_INDEX` 必须先判断基值是不是原生指针——
     所以还需要第 2 条；
  2. 给 `exec_value_alloc_bytes` 加**分配标记**（每个块前 8 字节写魔数，或维护区间表），
     提供 `exec_vm_address_is_value(addr)` 作为确定性判据（现在是纯启发式，必然误判）；
  3. 以上两步落地后，`LOAD_FIELD`/`STORE_FIELD` 的原生回落才能安全打开，再在 census 上
     验证 `test_libc_heap_*`（29 例）与 `test_stdio`/`test_string`/`test_stdlib`（5 例）。
- 顺带确认的两件事（已修，见下条）：`.ptr` 现在是 `LOAD_SLICE_PTR` 支持「运行时
  装着 VM 数组的切片字段」，`test_json_struct_collections` 由红转绿。

当前基线：**718 / 909 通过（79.0%）**，`/tmp/census_r291.tsv`；相对 r289/r290 的
715 净增 3（`test_json_struct_collections` 等），零回归。

本轮另修：`var x: T;`（无初值，只有 async 状态机会合成这种声明）现在按类型给零值，
`test_async_frame_type` / `test_async_frame_stack_ok` / `test_async_frame_methods` /
`test_std_mqtt_async`（4 例）的报错从「未初始化局部变量」收敛成「当前不支持 async」，
归入 async 大簇，等 async 落地后一起变绿。

### 第 275 轮：`manager.registry.entries[i].state` 一类「写入丢失」的根因

`test_capability_runtime_compat`、`test_std_script_pipeline_facade`、
`test_typed_pipeline_*` 这些用例的断言 `...entries[index].state == Active` 失败，
根因不在嵌套字段写入本身（最小复现 `m.registry.entries[i].state = 7` 在 VM 上是对的），
而在库里取元素指针的写法：

```uya
return (@usize_from_ptr(&registry.entries[0] as &void) + idx * @size_of(Entry)) as &Entry;
```

VM 的 `[T: N]` 是「ExecValue 聚合」，元素之间隔着 `@size_of(ExecValue)`，
按 `@size_of(Entry)` 步进的裸指针算术必然指到聚合内存中间，随后 `entry.state = ...`
写进无人读取的位置。这是**数组原生布局**簇（和上面 `[u64: 32]` 字节 punning、
`test_ptr_arithmetic`、`test_tls_x25519_pure` 同一个根），不是字段 lowering 的 bug。
要做的是让定长标量数组在 VM 里有真实连续内存（raw array），或者让
`@usize_from_ptr`/指针算术对 VM 聚合元素产出可还原的句柄。

### 第 276 轮：定长标量数组改原生内存 + drop/移动语义（+10，零回归）

**基线：718 / 909（79.0%）→ 730 / 909（80.3%）**，`/tmp/census_r300.tsv`。
相对 r292 净增 12、零回归：

1. **定长标量数组改用原生连续内存**（`exec_value_is_raw_array_element_type` 放行
   所有标量 kind，`exec_value_get_index`/`set_index` 与原生 slice 读写都按元素宽度走）。
   一口气解决三件事：`&arr[0]` 的裸指针算术、`mem_set(&arr[0] as *byte, …)` 字节
   punning、`@usize_from_ptr` 步进——都是 C99 语义。收益：
   `test_ptr_arithmetic`、`test_mem`、`test_tls_mpi`、`test_crypto_ed25519`、
   `test_ec_p256_ecdh`、`test_ec_p384_ecdh`、`test_std_runtime_simple`。
2. **`.ptr` / `&p[i]`**：`LOAD_SLICE_PTR` 对原生数组返回数据区首地址，`ADDR_INDEX`
   对宿主指针走 `p + i * elem_size`；顺带修好 `test_std_jpeg_encode/decode` 的回归。
3. **drop / 移动语义**（对齐 C99 的 `gen_moved_field_source_clear` 与字段递归 drop）：
   - 返回值/结构体初始化按值取走的局部变量不再重复 drop（`exec_lower_mark_moved_locals`）；
   - 结构体局部出作用域时补字段 drop（`exec_builder_emit_field_drops`，>8 字段跳过）；
   - `const moved = h.buf` 之后把源字段清零（`exec_builder_emit_moved_field_clear`）；
   - union 局部出作用域先 drop 活跃变体（`exec_builder_emit_union_variant_drops`），
     变体 drop 声明登记为可达种子。
   收益：`test_nested_field_move`、`test_return_struct_init_drop_once`、
   `test_union_drop_auto_variant`。
4. drop 登记的 scope 编号不一致不再让函数降级失败（以当前作用域为准登记）。

5. **VM 进程参数与位转换**：VM 启动后给 `std.runtime.saved_argc` 补 1（C99 由
   `uya_rt_init(argc, argv)` 注入，VM 没有），`get_argc`/`get_argv` 才自洽；
   `memcpy(&u64, &f64, 8)` 这类同宽标量位转换按「保留目标 kind、只搬位」处理；
   `*void` 的 `p[i]` 按字节走（`mem.uya` 的 `dst[i]` 循环依赖这一点）。
   收益：`test_std_runtime`、`test_async_frame_stack_limit_env`。

踩坑记录（避免重复）：
- `HIRExpr` 的 `item_count` 被可达性扫描当成元素个数，携带旁路信息会崩；要用
  `unary_op`/`binary_op` 这类 kind-specific 字段。
- 自举编译器里 `while`/`if` 的多行 `&&` 条件超过两行续行会解析失败，需要拆成嵌套 if。
- 结构体按类型名查 decl 会撞同名类型（`WebSocketConn` 23 字段 vs 运行期 3 字段），
  字段-drop 这类按名字解析的路径要加保守护栏。

### 第 277 轮：原生结构体字段访问第三次试验（关键进展 + 仍缺判据）

这次把「字段偏移/kind/字段数」打包进 `LOAD_FIELD`/`STORE_FIELD` 的 `imm`
（低 32 位下标、32..39 字段 kind+1、40..47 pointee kind+1、48..55 字段数+1，
`c` 放偏移），运行时按需回落到 `exec_vm_native_field_load/store`。

**关键进展**：打开严格回落（目标不是形状成立的结构体就走原生）后，
`test_string` / `test_stdio` / `test_stdlib` 全部**冲过了 `lib/libc/heap.uya:209`
的 `hdr.size`**——说明这条路线本身是对的，`ChunkHeader{magic,size}` 的偏移计算正确。

**仍缺的判据**：运行时无法稳定区分「VM 值引用」和「`@ptr_from_usize(addr) as &T`」。
试过的两种启发式都不行：
- 只比结构体字段数（`count == 声明字段数`）：同名结构体跨模块撞名，`fmt_parser` 的
  `Token` 一类会误判成原生内存 → 读到垃圾；
- 只比「下标处元素的 kind 是否等于字段声明 kind」：同样误判，且 `json_struct_collections`
  一起挂；
- 只判「目标 kind 是不是 STRUCT」：堆里的野内存经常恰好长得像 STRUCT。

补充（同轮第 4 次试验）：换成「ADDR_FIELD 对**普通宿主指针**直接产出
`base + 字段偏移` 的原生指针 + LOAD/STORE_FIELD 只在聚合路径失败后回落」这一最小组合后，
`test_string` / `test_stdio` / `test_stdlib` / `test_libc_heap_bins` 都能真正跑进堆逻辑
（不再报 `LOAD_FIELD 字段越界`），但随即**段错误**——说明还有别的调用点把原生指针当
VM 引用用（`mem_set` 字面量写、`STORE_INDEX`、或结构体字段整体读写）。

（第 5 次试验）把判据收窄成「只对**不带引用编码**的普通宿主指针走原生」后不再段错误，
但 `lib/libc/heap.uya` 里的 `hdr` 恰恰是**带引用编码**的（`aux=65552`），所以 heap 仍红；
而 `fmt_parser` 里 `@usize_from_ptr` 往返出来的普通指针又可能指向真正的 VM 值，
把合法结构体字段写丢（`file.use_count` 变 0）。两条事实合起来说明：
**没有 VM 值分配登记就无法给出可靠判据**，这是唯一该先做的事。
下一轮从这里接着查：先在 `STORE_FIELD`/`LOAD_INDEX`/`STORE_INDEX`/内存函数视图里
加上「原生指针」断点式校验（地址落在 VM 值之外的都按字节处理），把最后一个
混合语义点找出来，这条簇（29+5 例）就能收。

结论：这条路要走通，必须先有**确定性判据**，建议按这个顺序做：
1. `exec_value_alloc_bytes` 分配时写块头魔数（或维护 [base,end) 区间表），提供
   `exec_vm_address_is_value(addr)`；
2. 有了它，`exec_vm_field_aggregate_usable` 变成「目标地址是 VM value ⇒ 聚合路径，
   否则原生」，不再依赖形状启发式；
3. 再打开严格回落并跑 census 验证 `test_libc_heap_*` / `test_stdio` / `test_string` /
   `test_stdlib`（29+5 例）。

当前基线保持 **730 / 909（80.3%）**，本轮三次试验代码均已回滚（工作树干净）。

### 第 278 轮：VM 值竞技场 + 原生结构体字段访问落地 —— 730 → 745（82.0%）

**基线：730 / 909（80.3%）→ 745 / 909（82.0%）**，`/tmp/census_r301.tsv`，**+15 零回归**。

关键是把上一轮卡住的「判据」补上了：

1. **VM 值竞技场**：`exec_value_alloc_bytes` 统一从一块 200 MB 的固定区间分配
   （16 字节对齐、耗尽后回落普通 malloc），于是有了 O(1) 判据
   `exec_vm_address_is_value(addr)`——地址在区间里就是 VM 值，否则就是
   `malloc`/`mmap` 回来的原生内存。这是整条路线的前提。
2. **原生结构体字段访问**：lowering 算好字段偏移/kind/pointee 打包进
   `LOAD_FIELD`/`STORE_FIELD`/`ADDR_FIELD`（`c` 放偏移、`imm` 高位放 kind 与 pointee），
   运行时先沿引用链求「原生基址」（`exec_vm_field_native_base`：链尾的普通指针 + 不在
   竞技场里才算原生），命中就按 C99 布局读写真字节，否则照旧走 VM 聚合。
3. 三个坑（都已修）：`ADDR_FIELD` 有**两个**发射点（`&p.field` 走 `HIR_EXPR_ADDR`
   那条，光改 `compile_addressable_expr_slot` 不够）；ADDR 节点也要携带原生布局信息
   （lowering 在 `exec_lower_make_ref_expr` 里补）；`exec_lower_struct_field_index`
   会 move `base_type`，算布局前要先用 `copy_type` 留一份。

收益（15 例）：`test_string` / `test_stdio` / `test_stdlib` / `test_std_stdlib*`、
`test_libc_heap_{find_chunk_cross_bin,find_chunk_footer_fit,large_path,tcache_metrics}`，
另外 5 个 `test_async_*`（它们此前是卡在堆/原生结构体上而不是 async 本身）。

仍然红的堆用例（`test_libc_heap_bins` 的 split-remainder bin、
`test_libc_heap_coalescing_adjacent`、`test_libc_heap_realloc_in_place`、
`test_libc_heap_tcache`）需要**精确的页级布局**（用例靠探测地址连续性来 carve
guard/A/B 布局），VM 里 mmap 是模拟的，布局不可能一致——属「分配器页布局」簇，
优先级低于 async。

当前剩余 167 条：async 97、断言类 40（pthread ~12 + 堆页布局 4 + 其余）、
泛型调用 4（async）、`@c_import` 3、`LOAD_INDEX 越界` 3、for 迭代器 2、杂项 8。

### `test_std_env` / `test_typed_pipeline_cmd_argv` 的 `LOAD_INDEX 越界`（3 例）

两例都倒在「合成 env/argv 块」上：`base_envp: &(&const byte)` 由测试侧自己拼出来，
VM 里那个字段里装的是**字节数组**（`[byte: N]` 一类），于是 `self.base_envp[i]`
按元素取出来是 `byte`（kind=12, aux=0），再 `entry[i]` 就 `LOAD_INDEX 越界`。
根因是「`[byte: N]` 与 `&&const byte` 的表示不一致」，不是索引实现的问题。
优先级低（3 例），要做得先把 env/argv 的合成块统一成原生指针数组。

### 文件 IO / 位转换一簇（4-5 例）：`&local` 落到竞技场外的地址

有了 VM 值竞技场之后可以精确定位这一类问题了。`test_std_io`（以及
`test_std_io_buffering` / `test_stdio_file_buffering` / `test_std_stdlib_malloc`）
读回来的内容不对，实测：

```
fwrite(&wbuf[0], 1, 2, f)  →  syscall write(fd, addr=0x6253dc0, 2)
```
`0x6253dc0` **不在**竞技场里（`exec_vm_address_is_value` 返回 0），而是编译器静态区
（slot pool / 旁路聚合表一类）。同样的 `[byte: N]` 数组在别处（`/tmp/t_addr.uya`）
是正常的竞技场地址（`0x7fca…`），所以是某条 `&local[i]` / `&param` 路径产出了
「指向静态槽位」的指针。同一类症状还有 `pb_f32_to_bits`（`memcpy` 的源目标是一个
值为 0 的 F64 槽位，而不是 `f32` 参数槽）。

**进展（同轮后续试验）**：按「地址是否在竞技场里」重写 `exec_vm_field_native_base`
后，堆代码里的 `&chunk.header`（`aux=65552`，引用目标是原生内存）能正确判定为原生，
VM 的 `fwrite` 不再往文件里写 `\f\0`，但随即发现**判据还不够**：局部变量的槽位在
编译器静态区（`g_exec_vm_slot_pool`），全局槽在 `program.globals`，两者都**不在**
VM 值竞技场里，于是「引用指向 VM 局部结构体」被误判成原生 → `test_string` /
`test_stdio` / `fmt_parser` / `json_struct_collections` 一起回归。
结论：`exec_vm_address_is_value` 必须把「竞技场 + slot pool + globals 数组」三者都算作
VM 值，再打开原生回落。这条已记在下面，下一轮照此实现即可。

下一步：在 `ADDR_LOCAL`/`ADDR_INDEX`/CAST 里断言「产出的指针要么是引用编码，
要么落在竞技场或栈上，不允许指向 slot pool」，把这几个用例的产出点直接打出来。

### 第 279 轮：原生字段访问第二版（竞技场驻留判据）——差一步，已回滚

按上一轮的结论把判据改成「VM 值驻留区」，实测**四个范围都得算**，少一个就回归：

1. 值竞技场（`exec_vm_address_is_value`）；
2. 帧槽位池 `g_exec_vm_slot_pool`（局部变量住这儿，**不在**竞技场里）；
3. 全局槽数组 `program.globals`（编译器自己的 arena）；
4. 原生聚合旁路表 `g_native_agg_values`（静态区，也存 ExecValue 槽）。

四条齐了之后：`test_fmt_parser` / `json_struct_collections` / `mem` 这些没再回归，
`test_string` **第一次真正通过**（`hdr.size`、`chunk.header` 全走原生）。
但同批的 `test_stdio` / `test_libc_heap_bins` 变成了**段错误**，于是整批回滚。

段错误的来源基本锁定在「原生结构体里的**指针元素数组**」：
`tcache.bins: [&ChunkHeader: N]` 这类字段现在会生成「原生数组视图」
（`exec_value_make_raw_array_view`），元素按裸地址读写；而 VM 里的指针可能带
引用编码（65536+kind），把这种值写进原生槽位再读回来就是野指针。
下一轮的做法：视图只给**非指针元素**（标量）的数组字段；指针元素数组继续走
旁路聚合表，或者显式做「编码↔裸地址」的转换。

（本轮改动全部回滚，基线仍是 **745 / 909（82.0%）**。）

### 第 280 轮：驻留判据 + 原生数组字段视图落地（census 仍 745，但地基补齐）

按上一轮的四个范围实现 `exec_vm_address_is_vm_resident`（竞技场 + slot pool +
globals + 原生聚合旁路表），`exec_vm_field_native_base` 改成基于它的链式解析；
另外给「原生结构体里的**标量元素**定长数组字段」生成原生数组视图
（`exec_value_make_raw_array_view`，`LOAD_FIELD`/`STORE_FIELD`/`ADDR_FIELD` 的
`imm` 高位打包元素 kind 与「元素个数-1」，16 位）。指针元素数组继续走 VM 聚合
（上一轮段错误的根因）。

整轮 census 实测 **745 / 909（82.0%）**，与基线完全一致（零回归零新增）。
文件 IO 那一簇（`test_std_io*`、`t_write` 复现）**仍未解决**，新定位到的事实：
`fwrite(&data[0], 1, 2, f)` 里 `data` 自己的地址正确（竞技场 `0x7f84…`、字节 72/105），
但 `write(2)` 的 `*buf` 参数拿到的是**旁路表地址**（`0x6253dc0`，即
`g_native_agg_values` 的基址），也就是说 `flush_buffer` 里
`&stream.buffer[0] as *const byte` 这一步把整个 FILE 认成了旁路聚合。
下一步直接从 `stream` 的来源查：`stdio_file_pool_acquire` 里
`malloc(@size_of(FILE)) as &FILE` 之后 `fresh.fd = 0` 这类**原生字段写**会把
`fresh` 变成 `aux=65552` 的引用（实测 ref 目标落在 slot pool），需要在
「原生指针存进局部变量再取地址」这条链上保留原生性。

### 第 281 轮：文件 IO 簇的最后一次定位（写对、读回 0）

用最小复现 `/tmp/t_nf3.uya`（`struct S { a: i64, b: [byte: 8] }` + `malloc`）逐字节打点，
得到两个确定事实：

1. **写是对的**：`p.b[0] = 'X'` 落到 `p+8`（`DBGSPI addr=…038 v=88`），
   `p.a = 7` 也对（原生字段访问在 malloc 出来的结构体上工作正常）。
2. **读回是 0**：同一轮里 `raw[0]`（`@ptr_from_usize(paddr+8)`）和 `p.b[0]`
   都读到 0，而地址与写入地址完全一致。

也就是说问题不在字段偏移/写入，而在**读路径**（`exec_vm_load_pointer_index` 的
BYTE 分支或 `@ptr_from_usize` 得到的指针值）。下一步在 `exec_vm_load_pointer_index`
的 BYTE/U8 分支打点，和写侧地址对比一次即可收敛。

另外试过并**回滚**的一个改动：把「数组字段取地址」的结果指针 pointee 从 ARRAY 改成
元素类型（希望 `&struct.arr[i]` 按元素步进）。census 从 745 掉到 **727（-18）**，
说明现有语义（ARRAY pointee → 旁路聚合）被不少用例依赖，不能这么改。

（本轮无净变化，基线仍 **745 / 909（82.0%）**。）

补充同一簇的两次失败尝试（都已回滚，别重复）：
- 把「数组字段取地址」的 pointee 从 ARRAY 改成元素类型：**-18（745→727）**；
- 在 `exec_vm_load/store_pointer_index` 里把 `pointee == ARRAY` 当字节处理：
  最小用例仍读 0，且 `test_stdio` 直接**段错误**。

结论：`&struct.arr` 这条指针的语义现在是「旁路聚合表」，写进表里、读原生地址得 0；
要动它必须同时改读、写、ADDR_INDEX 三处并让旁路表退出该路径，属于一次结构性改动，
单点补丁只会换来回归或崩溃。

### 第 282 轮：结构体字段 drop 播种被一个 `self` 类型解析坑挡住

`test_string_buf`（`StringBuf { buf: Vec<byte> }` 出作用域应 free 一次）失败原因是
**字段 drop 声明不在可执行集合里**。把「结构体字段的 drop 也播种」加上后：

- `test_string_buf` 仍红（另有原因）；
- `test_std_sql` 直接回归：`lib/std/http/types.uya:210` 的
  `Conn.drop` 里 `self.fd` 报 `无法解析成员访问字段(kind=15)`——`self` 被当成接口。

但单独写一个用 `Conn` 的小程序（`var c: Conn = Conn{fd:-1}`）**能正常降级**，
说明 `Conn.drop` 本身没问题，问题出在「播种进来的函数」这条路径上：它和局部变量
触发的 drop 走的是同一份 `exec_lower_function`，但 checker 的 self 类型上下文不同。
下一步：在 `exec_lower_function` 开头打印 `checker.current_self_type_name` /
`fn_decl_owner_type_name`，对比两条路径的差异。

（同轮补充定位）在 `exec_lower_function` 里加「从 `self` 形参反推 owner 类型」的兜底后，
`Conn.drop` 的 self 类型确实变成 `Conn` 了，但 **`self.fd` 的基类型仍然是接口（kind=15）**
——说明问题不在 self 名字，而在 `type_from_ast` 解析该形参类型时被 checker 的
类型替换状态（`subst_active`/接口上下文）污染了。这条只能从 checker 侧查，
exec 侧加兜底无效，两个改动都已回滚。

（本轮无净变化，基线与回滚后一致：**745 / 909（82.0%）**。）

### 第 283 轮：结构体字面量里的「带类型初始化」（745 → 746）

`arr: [Inner: 2] = []` 这种「字段名 + 类型 + 值」的写法在 AST 里是 **assign 形态**
（`assign_dest` 是类型标注、`assign_src` 才是值）。结构体字面量的字段值原本直接
按 assign 降级，于是被 `exec_lower_make_dest_expr` 判成非法赋值目标。
加 `exec_lower_unwrap_typed_init()` 在字段值处取右值即可。
收益：`test_struct_array_field_typed_empty_init`（census 745 → **746，82.1%**，零回归）。

同轮未成的：`test_generic_struct_array_future_method` 的
`zero struct 无法解析结构体声明(name=T)`，根因是**泛型结构体实例没有单态化**
（降级时拿到的仍是声明本身，`struct_type_args` 就是类型参数 `T`），
不是替换函数的问题；后来加的递归替换（数组/指针/切片元素位置的 `T`）
对这条没用，已回滚。要做这条得先补「泛型结构体的按需单态化」。

### 第 284 轮：syscall 出参结构体（`test_syscall_dir` / `test_std_path_module` / `test_signal`）

三个用例都死在「内核把数据写进了 VM 槽位」：`sys_stat(path, &stat_buf)` 之后
`stat_buf` 变成 `kind=6 i64=5`——内核的 stat 数据覆盖了 ExecValue 头部。
实测打点结论：

- syscall 元数据里的出参掩码是**对的**（`nr=4 args=2 mask=2`，第二位标记出参）；
- 但 `exec_vm_syscall_out_struct_target` 拿到的参数槽是 **I64 原始地址**
  （`k=2 aux=0 raw=110578232`），不是引用值，所以函数里
  `resolved.kind` 判定失败、`raw_address as &ExecValue` 这一段也没命中
  （该地址读出来的 kind 不是 STRUCT/ARRAY/TUPLE）；
- 因为 `out_target == null`，`out_buffer` 没建，内核直接写进了 VM 槽位。

（同轮试过）在 `exec_vm_syscall_out_struct_target` 里加「出参地址多解一层」的
循环（每层都要求落在 VM 值驻留区）——三个用例仍然红，且行为没变化，说明那层地址
读出来根本不是聚合值，**不是解析层数问题**。真正的修法是让 syscall 参数在 lowering
阶段就保留「VM 值引用」而不是提前退化成 I64 裸地址（见下）。

修法方向：`exec_vm_syscall_out_struct_target` 需要用
`exec_vm_address_is_vm_resident(raw_address)` 判断这个 I64 地址是不是 VM 值，
是就按 ExecValue 解释成出参目标；同时 syscall 参数在 lowering 里应保留
「这是 VM 值引用」的信息，而不是提前退化成裸地址。

### 第 285 轮：syscall 出参结构体两处修复（746 → 748，82.3%）

1. **字段数上限 16 → 64、缓冲区至少 256 字节**：`struct stat` 之类有近 20 个字段、
   原生 144 字节，原来的上限让 `exec_vm_syscall_out_struct_prepare` 直接返回 null，
   内核于是把数据写进 VM 槽位（`stat_buf` 变成 `kind=6 i64=5`）。
   收益：`test_syscall_dir`、`test_std_path_module`。
2. **多个出参结构体**：`exec_vm_syscall_marshal_out_struct` 原来只能处理一个出参
   （`out_target`/`out_buffer` 单值），而且参数探测只扫前 2 个参数。
   现在按位掩码逐个换缓冲区（最多 6 个），出参个数与字段数用数组带回。
   `@syscall(rt_sigaction, signum, &action, &old_action, 8)` 这类双出参调用
   才对得上；census 确认零回归。

仍未解决：`test_signal` 的第二个出参（`&old_action`，参数下标 2）在
`exec_builder_syscall_arg_out_struct_bit` 里探测不到（同一形状的 `&action` 能探测到），
说明那个 HIR 节点的类型信息不一样，需要单独查。

### 第 286 轮：`for iter |v|` 迭代器协议（改到一半，已回滚）

做法（留给下一轮）：在 `exec_lower_make_for_array_stmt` 的非数组/切片分支里，
如果迭代对象是带 `next()`/`value()` 的结构体，就手工搭这段 HIR：

```
loop { _ = iter.next() catch { break; }; const v: T = iter.value(); <body> }
```

已经能写出来的部分：取 `find_instance_method_in_struct(program, 类型名, "next"/"value")`、
用 `HIR_EXPR_CALL` + `HIR_EXPR_ADDR(&iter)` 造调用、`HIR_EXPR_CATCH` 配
`exec_lower_make_break_block`、`HIR_STMT_LOOP` 包三层语句。
**卡点**：builder 报 `bytecode 函数构建失败`（无具体信息的 `return -1` 路径），
说明这段手工 HIR 里有某个不满足 builder 约束的地方（最可疑是
`HIR_EXPR_CATCH` 里嵌 `HIR_STMT_BREAK` 的循环标签栈，或者 `HIR_EXPR_ADDR`
对「结构体局部变量」的取址约束）。下一轮先把 `exec_builder_build_function`
所有静默 `return -1` 补上错误信息，再逐条对齐。

（本轮无净变化，基线 **748 / 909（82.3%）**。）

### 第 287 轮：async 的「同步实现」路线（剩余 170 条里 94 条是 async）

读了 `lib/std/async.uya` 后发现关键事实：`Future<T>` 只是个
`struct Future<T> { state: Poll<T> }`，而它的 `poll()` 直接 `return self.state`——
**没有函数指针、没有帧恢复逻辑**。也就是说 VM 可以先用「同步语义」把 async 跑起来：

1. `@async_fn fn f(...) -> Future<T>`：把函数体按**普通函数**降级，每个 `return x`
   改成 `return Future<T>{ state: Poll<T>.Ready(x) }`（错误联合同理）；
2. `@await child` / `try @await child`：
   - 求值 child 得到 `Future<T>`；
   - 调 `child.poll(&waker)` 拿 `Poll<T>`；`Ready(v)` 就取 v，`Pending` 就**忙等**
     （循环重试，加次数上限防止死循环）；
   - `try` 版本在 v 是错误联合的 err 时按 `try` 语义提前返回。
3. 这样所有「子 future 立即完成」的用例（`test_async_await_ready`、
   channel/event/scheduler 里不真正挂起的那批）都能跑通；真正需要挂起/交错的
   仍然红（总线语义），但那是少数。

实现落点：
- `exec_lower_function` 去掉 `fn_decl_is_async != 0` 的硬失败；
- `exec_lower_expr` 增加 `AST_AWAIT_EXPR`（type 51/52 附近的 `@await` 节点）分支，
  产出「poll + 忙等 + 取载荷」的 HIR（可以用 `HIR_EXPR_CATCH`/`HIR_EXPR_IMETHOD_CALL`
  组合）；
- `return` 降级处按函数是否 async 决定是否包 `Future{ state: Ready(...) }`；
- 需要先确认 checker 给 `@await` 节点的类型（`Poll<T>` 还是 `T`）以及
  `Future<T>{...}` 构造在 VM 里是否已支持（泛型结构体字面量 + 联合变体）。

**第 287 轮实测**（已经验过）：
- `Future{ state: Poll<T>.Ready(v) }` 构造 + `f.poll(&w)` + `match` 在 VM 里**全都能跑**
  （最小用例 `/tmp/t_fut.uya` 两个后端 rc 都是 0）→ 同步路线的基础没问题；
- 把 `exec_lower_function` 里 async 的硬门禁拿掉之后，
  `test_async_await_ready` 的第一个卡点就是 **`AST_AWAIT_EXPR`（节点类型 62）**
  尚未支持（`尚未支持的表达式节点(type=62)`），没有更深的坑。
- 进一步简化：`Future` 只有 `state: Poll<T>` 一个字段，所以 `@await f` 完全可以
  直接按「读 `f.state`（LOAD_FIELD 0）+ 对 `Poll` 联合做 tag 分支」降级，
  根本不需要泛型方法 `poll` 的返回类型装配（那是这条路线上最容易卡的地方）。

### 第 292–300 轮：async 错误路径 + 泛型内层调用 + 解释器杂项（791 → 802 / 909，88.2%）

这批全是「卡在同一个死胡同里的整簇用例」，每修一处带出 2–4 个：

1. **async 函数里的 `try` 降级成 catch 形状**（`exec_lower_make_async_try_catch`）：
   `try x` 普通语义是「err 时原样返回错误联合」，但 async 函数返回的是 Future，
   直接把裸错误返回给调用方会让调用方在 `!Future` 上做 `LOAD_FIELD`。
   现在改写成 `x catch { return wrap(err) }`：`HIR_EXPR_CATCH` 用 `int_value=1`
   表示「绑定整个错误联合，不要 UNWRAP_ERR」，`extra` 是
   `exec_lower_wrap_async_return` 造好的 Future 表达式。
2. **catch 分支里的 `return` 也要包 Future**（`exec_lower_wrap_catch_return`），
   否则 `x catch |e| { return 999; }` 会把裸 `999` 当返回值得调用方炸掉。
3. **async 错误返回补跑 errdefer**：值被包成 Future 后 builder 已看不出「这是错误返回」，
   lowering 用 `HIRStmt.int_value = 1` 打标，builder 见到就走 `emit_all_cleanup(1)`
   （`HIRStmt` 因此新增 `int_value` 字段）。
4. **libc 常量与编译器注入全局**：`libc_EAGAIN` 这类「带模块前缀的 errno」
   和 `_uya_async_frame_heap_fallback`（`--async-frame-heap=on` 才为 1）
   补进了 `exec_lower_libc_macro`。
5. **`extern var` 全局按零值占位**：`_uya_async_frame_descriptors` 这类由 C 侧
   链接器提供存储的全局，解释器里没有对应物；读它时给「空表/计数 0/指针 null」，
   正好等于「运行期没有任何异步帧注册」。
6. **泛型函数体内再调泛型函数**：checker 只登记了以类型参数（`TYPE_GENERIC_PARAM`）
   为实参的实例，而单态体降级时外层类型参数已替换成具体类型，于是找不到实例
   （`当前不支持这个泛型调用`）。降级时按替换后的具体类型调用
   `register_mono_instance_by_types()` 补登记，后续单态体循环会把它生成出来。
7. **`@await` 忙等按 CPU 时间收敛**：纯计次（10000 次）在毫秒内就放弃，
   「deadline 到期才 Ready」的 Future 永远等不到；改用 `clock()` 的
   1.5 CPU 秒预算，`Waker` 参数给一块 64 字段的占位聚合（传 null 会在
   `w.clear_cancelled()` 处越界）。
8. **`exit()` 不再杀宿主进程**：解释器跑在编译器进程里，真 `exit()` 连测试汇总
   都打不出来；改成记录退出码 + `vm_run_program` 立刻收工并把它当程序返回值。
9. **builder 上限放宽**：loop patch 栈 32 → 256（`defer` 嵌在循环里会让
   HIR 层数远大于源码层数）。
10. **分支值支持 `return` / `break` / `continue`**：`if` 表达式、
    块表达式（`exec_lower_block_expr`）以前把跳转语句当表达式降级，
    报 `尚未支持的表达式节点(type=20)`（20 = `AST_RETURN_STMT`）；
    现在合成单语句块走语句路径，值位置补零。

**仍然红的大簇**（108 个）：
- **运行期崩溃/无输出 52 个**：`@frame(…)` 异步帧（uyagin/http 系）、
  `test_async_compute_*` 的段错误、`test_epoll_server` 超时等；
- **`@await 操作数不是 Future` 10 个**：要么挂在 `@frame` 上，要么是
  「事件循环 + 真实 I/O」组合，同步 VM 无法推进；
- **`for 迭代对象必须是数组或切片` 4 个**：迭代器协议（`IntoIterator`）仍未实现；
- **`zero struct 无法解析结构体声明` 3 个**：泛型结构体单态化缺失；
- **`@c_import` 3 个**、`LOAD_INDEX 越界` 4 个、`局部变量槽位不足` 2 个 等。

**下一轮入口（已定位到具体形状）**：
- `test_std_env` 的 `LOAD_INDEX 越界` 里插桩看到 `base kind=12(BYTE) count=0`：
  `entry[i]`（`entry: &const byte`）的降级把指针**先解引用成 byte** 再取下标，
  于是 VM 在标量上做下标。应该改成直接对指针做 `LOAD_INDEX`；
  同类还有 `test_typed_pipeline_*`（`lib/std/process.uya:845`）。
- `for iter |v|` 的迭代器协议（4 个用例）之前写好的 HIR 手排版本仍卡在
  `exec: bytecode 函数构建失败`（builder 静默 `return -1`），定位方法：
  在 `exec_builder_compile_stmt` 的失败返回点逐个加 `fprintf` 计数。
- `test_async_await_capacity_dynamic` / `test_async_await_limits_and_segments`
  报 `局部变量槽位不足`：它们的 `test` 块局部变量数超过了 builder 的局部槽位上限。

### 第 306–308 轮：pthread 同步语义 + 函数地址回调（814 → 822 / 909，90.4%）

线程用例（10 例）此前全军覆没，根因不是「少几个 API」，而是两件事：

1. **`extern "libc"` shim 的 Uya 实现体在解释器里跑不通**。`lib/libc/pthread.uya`
   里的 `pthread_create` 会走 `clone` 系统调用，VM 执行出来是垃圾返回值
   （`pthread_join` 回 `EINVAL(22)`）。修法是给 `exec_lower_extern_can_run_in_vm`
   加线程前缀判定：`pthread_*` 一律视为「VM 不能执行 Uya 实现体」，
   能对上宿主桥的走宿主实现，其余退化成零值桩。
2. **`&fn` 只是占位常量 4096**，宿主调用没法回调。
   - 构建期把 `&fn` 换成 `EXEC_FN_REF_BASE(0x40000000) + 模块内函数下标`；
     可达性收集器也补上 `HIR_EXPR_CONST + callee_decl`，否则被引用的函数
     根本不进可执行函数集（这是最容易踩空的一步）。
   - 解释器侧 `exec_vm_fn_ref_index` 解出下标，用
     `exec_vm_call_function` 直接回调。`pthread_once` / `pthread_create`
     的回调、`pthread_exit(v)`（提前收工标记 + 帧返回值）都靠它。

宿主实现（同步语义，状态放在 `EXEC_VM_THREAD_SLOTS` / `EXEC_VM_TLS_KEYS` 表里）：

- `pthread_create`：登记槽位 → **当场串行执行** `routine(arg)` → 记住返回值；
  `attr.detached == 1` 时线程创建即为分离态。
- `pthread_join`：分离态回 `22`；否则把 `create` 记住的返回值写进 `*retval`。
- `pthread_detach` / `pthread_once` / `pthread_exit` / `pthread_self` / `pthread_equal`。
- `pthread_attr_*`（`stack_size`/`detached`，含 16KB 栈下限与非法 detachstate → `22`）、
  `pthread_mutex*`（`state`/`owner`/`type`，trylock 已被占用回 `16`）、
  `pthread_mutexattr_*`、`pthread_condattr_*`、`pthread_cond_timedwait`（单线程 → `110` 超时）、
  `pthread_setcancelstate`/`setcanceltype`（非法值 → `22`）、
  `pthread_key_*`/`pthread_setspecific`/`pthread_getspecific`（`pthread_key_t` 是
  `{seq, destructor}`，按 `seq` 索引 TLS 表，无效键 → `22`）、`pthread_barrier_*`。

**本轮实测**：`/tmp/census_r331.tsv` = **822 / 909（90.4%）**，
`r325(814) → 822`，**+8 / 0 回归**（`test_pthread`、`test_pthread_api`、
`test_pthread_api_create_join`、`test_pthread_create_join`、`test_pthread_detach`、
`test_pthread_cancel`、`test_pthread_join_stack_reuse`、`test_method_call_in_callback_codegen`）。

**踩过的坑**（后续别重复）：

- `pthread_create` 的 `attr` 必须读 `detached` 字段，否则
  `test_pthread_attr_detached` / `test_pthread_api_detach` 会从绿变红（已修）。
- `test_pthread_heap_cache_identity` / `test_pthread_heap_concurrency` 现在会
  **挂死到超时**（同步执行下它们在自旋等锁），普查按超时记为失败，属已知代价。
- `&fn` 的可达性收集漏了就会退化成 4096 占位常量（回调查不到下标 → 静默不回调）。

### 第 303–304 轮：字段级 drop 特化 + 接口装箱（813 → 814 / 909，89.5%）

本轮在 r321(808) 基础上继续收口，两段普查合计 **+11 / 0 回归**，其中本轮新增：

1. **槽位/深度上限**：调用参数 32 → 128、循环补丁栈 256 → 1024、
   cleanup 作用域深度 512 → 1024（`test_async_param_capacity_dynamic` 传 65 个实参）。
2. **`return` 校验放行「裸值 → `!T`」**：`fn f() !Future<i32> { return Future{…}; }`
   被前置校验判成类型不一致，而发射阶段本来就会补 `BC_MAKE_OK`。
3. **`@frame` 合成结构体**（`uya_async_*`）：AST 里没有声明，零值退化为 0 字段
   `BC_MAKE_STRUCT`；未知帧控制方法（`frame.stop()`）按空操作处理。
   `test_async_frame_stack_ok` / `test_async_frame_type` 转绿。
4. **具体结构体值隐式转接口补装箱**：`Future<T>` 同时是接口名与结构体名，
   把结构体值当接口用时接口分派的「数据指针字段」会越界
   （`LOAD_FIELD 字段越界(idx=2 kind=16 count=1)`）。在 `exec_lower_coerce_expr`
   里对「期望接口 / 实参结构体且实现该接口」补 `exec_lower_box_interface_expr`。
   `test_async_poll_inline_struct_init` 转绿。
5. **字段级 drop 按实例化类型特化**：`HIRLocalSlot` 增加
   `field_drop_indices` / `field_drop_decls` / `field_drop_count`，由 lowering
   用 `exec_lower_find_drop_decl` 在**有类型实参的上下文**里选好单态 drop
   （`Vec<byte>.drop` ≠ 泛型 `Vec<T>.drop`），构建期只做指针匹配。
   此前 `StringBuf.drop`（函数体为空，靠后端逐字段清理）在 VM 里什么也没释放。
   `test_string_buf` 转绿。

**本轮实测**：`/tmp/census_r325.tsv` = **814 / 909（89.5%）**，`r321(808) → 814`，
逐条对比 `regress = 0`。

### 第 305 轮起：剩余 95 例的根因归类（重要，避免重复摸索）

- **内存模型（约 20 例，最大一块）**：VM 没有「局部变量真实内存」，
  `&local` 产出的是指向 `ExecValue` 的内部引用。凡是把地址**转成整数再转回来**
  或**跨结构体保存后按字节写**的写法都会静默丢写：
  - `@usize_from_ptr(@ptr_from_usize)` 往返 + 字节偏移（`capability_registry_entry_ptr`
    的 `entry_idx * @size_of(Entry)`）：VM 元素步长是 `sizeof(ExecValue)`，
    与 C 布局不等价，**无法仅靠指针算术修**；10 个 capability manager/loader 用例卡这里。
  - `fread(&buf[0], …)` 写进的是副本（`test_std_io`，返回码 7）。
  - `memcpy(&u32, &f32, 4)` 位转换：Uya 版 `memcpy` 是逐字节循环，
    目标是指向标量值的视图时会 `LOAD_INDEX 越界`；把它改走宿主实现
    （`exec_lower_extern_prefers_host_call` 白名单）后不再报错，但**结果仍然不对**
    （`test_protobuf_wire` 卡在 `pb_bits_to_f32(1.0)`），已回退该改动。
  → 这一块要动就得给「取过地址的局部变量」建立真实内存（boxing），属于设计级改动。
- **线程语义（10 例）**：`test_pthread*` / `test_libc_heap_*` / `test_osal` / `test_kernel_sim`，
  `pthread_join` 在 VM 里返回 `EINVAL(22)`，同步 VM 没有并发语义。
- **async 帧布局（约 15 例）**：`LOAD_UNION_TAG 目标不是 union`、
  `STORE_FIELD 字段越界`——`@frame` 的 union 状态字段目前是空结构体。
- **超长函数（4 例）**：`cleanup scope 嵌套过深` → 放宽到 4096 后撞
  `bytecode 指令超出上限`（`lib/std/async_scheduler.uya` 单函数体量超 VM 上限）。
- **异步 pending 语义（5 例）**：`pending_seen == 1` 一类断言要求 Future 先 Pending，
  同步 VM 一旦执行就是 Ready，属语义不可对齐，不是缺陷。
- **`@c_import`（3 例）、f64 `%#.17g` 精度（`test_printf_f`）、其余零散模块缺口。**

### 第 301–302 轮：迭代器协议落地 + 槽位/泛型收口（802 → 待测 / 909）

这一轮把「下一轮入口」里能确定形状的三条全部做完，另外顺手修掉泛型类型泄漏。

1. **`for iter |v|` 迭代器协议（4 例 → 全绿）**：
   上一轮手排 HIR 卡在 builder 静默 `return -1`。改成**合成 AST 再复用整条降级链**
   （`exec_lower_desugar_iterator_for`）：把
   ```
   for iter |v| { body }
   ```
   改写成
   ```
   const __exec_iter = <iter>;
   while true {
       const __exec_ok = __exec_iter.next() catch { break; };
       const v = __exec_iter.value();
       body
   }
   ```
   合成节点走 `exec_lower_block`，作用域/cleanup/`break`/`continue` 全部沿用现成逻辑。
   `|&item|` 有两种情况：`value()` 返回指针就直接绑定，返回值就每轮建临时再取地址
   （用 `type_from_ast` 读 `value` 方法返回类型区分）。
   `test_for_iterator` / `test_async_for_await` / `test_async_for_iterator_ref_await` 转绿。
2. **`局部变量槽位不足`（2 例）**：`EXEC_MAX_LOCALS` 256 → 1024。
   `test_async_await_capacity_dynamic` / `test_async_await_limits_and_segments` 转绿。
3. **泛型结构体字面量的字段类型**：`FutureSlot<i32>{ ready: false }` 里省略的
   `slot: [T: 1]` 字段补零时用的是**未替换**的 `T`，报
   `zero struct 无法解析结构体声明(name=T)`。补零/赋值两处都改走
   `exec_lower_subst_struct_field_type`。`test_generic_struct_array_future_method` 转绿。
4. **泛型调用的形参/返回类型替换**：`ok<i32>(3)` 的形参声明是 `T`，实参被当成
   「名为 T 的结构体」装箱；返回值同理。新增
   `substitute_generic_type_for_exec`（`src/checker/generics.uya`），在
   `exec_lower_generic_call_expr` 里按本次类型实参替换形参与返回类型。
   这条是「错误联合被装箱成 STRUCT」的根因，`block_on` 系用例的载荷因此能保持原 kind。
5. **普查吞吐**：`UYA_EXEC_CENSUS_JOBS=8` + `UYA_EXEC_CENSUS_TIMEOUT=120` 后，
   一次全量普查 25 分钟 → **5 分 14 秒**（长尾仍在 `exec_vm_census_timeouts.txt` 里放宽；
   `test_crypto_bigint` / `test_crypto_ed25519` 补进表里放宽到 300s，否则会被 120s 误杀）。
6. **各类上限放宽**：调用参数 32 → 128、循环补丁栈 256 → 1024、
   cleanup 作用域深度 512 → 1024（`test_async_param_capacity_dynamic` 传 65 个参数）。
7. **`return` 校验放行「裸值 → `!T`」**：`fn f() !Future<i32> { return Future{…}; }`
   被前置换算判成「类型不一致」，而发射阶段本来就会补 `BC_MAKE_OK`。
8. **`@frame` 合成结构体退化为空结构体**：`uya_async_*` 类型由 C99 codegen 合成，
   AST 里没有声明，零值改发 0 字段 `BC_MAKE_STRUCT`；帧控制方法（`frame.stop()`）
   按空操作处理。`test_async_frame_stack_ok` / `test_async_frame_type` 转绿。
9. **具体结构体值隐式转接口补装箱**：`Future<T>` 同时是接口名与结构体名，
   把结构体值直接当接口用时，接口分派的「数据指针字段」会越界
   （`LOAD_FIELD 字段越界(idx=2 kind=16 count=1)`）。在
   `exec_lower_coerce_expr` 里对「期望接口 / 实参结构体且实现该接口」补
   `exec_lower_box_interface_expr`。`test_async_poll_inline_struct_init` 转绿。

**本轮实测**：**808 → 813 / 909（89.4%）**，两段普查合计 **+11 / 0 回归**：
- `r319(802) → r321(808)`：`test_async_await_capacity_dynamic`、
  `test_async_await_limits_and_segments`、`test_async_for_await`、
  `test_async_for_iterator_ref_await`、`test_for_iterator`、
  `test_generic_struct_array_future_method`；
- `r321(808) → r324(813)`：`test_async_frame_stack_ok`、`test_async_frame_type`、
  `test_async_param_capacity_dynamic`、`test_async_poll_inline_struct_init`、
  `test_crypto_bigint`（放宽超时后跑完）。

**剩余 96 例的构成**（r324 失败清单）：
- 线程语义 10 例：`test_pthread*`、`test_libc_heap_*`、`test_osal*`、`test_kernel_sim`、
  `test_method_call_in_callback_codegen`（`pthread_join` 在 VM 里返回 `EINVAL(22)`）；
- async 帧布局 ~15 例：`LOAD_UNION_TAG`/`LOAD_FIELD 越界`（帧结构体的 union 状态字段，
  目前退化成空结构体，需要把 `@frame` 的布局也合成进 VM）；
- 超长函数 4 例：`cleanup scope 嵌套过深` → 即使放宽到 4096 也撞
  `bytecode 指令超出上限`（`lib/std/async_scheduler.uya` 的单函数体量超出 VM 上限）；
- `@c_import` 3 例；其余为各模块的零散语义缺口。

**仍然红的大簇**（重新归类后）：
- **41 例「静默失败」（测试内部 `ERROR`，无 stderr）**：根子在 `@async_fn` 的返回值被
  包成 **3 字段结构体** `{frame, …, Future}`（`exec_lower_wrap_async_return`），
  而 `Future.poll` 只按 1 字段结构体取 `state`，于是 `Poll` 的标签/载荷全错位。
  这一块要对齐 C99 的 async frame 布局，不是单点修复。
- **`@await 操作数不是 Future` 10 例**：同上，事件循环 + 真实 I/O 组合。
- **`@frame(…)` 2 例**：`@frame` 结构体由 C99 codegen 合成，AST 里没有声明，
   VM 侧 `zero struct` 解析不到；需要按异步函数局部表合成帧结构体。
- **`@c_import` 3 例、`LOAD_INDEX 越界` 4 例**：见下方入口。

**下一轮入口**：
- `LOAD_INDEX 越界`：`entry[i]`（`entry: &const byte`）降级时先把指针解引用成 byte
  再取下标，应该在指针上直接 `LOAD_INDEX`（`lib/std/process.uya:845` 同类）。
- `@c_import` 3 例：`test_c_import_*` 需要 VM 侧声明宿主函数占位。
- async frame 布局：`exec_lower_wrap_async_return` 现在塞了 3 个字段，
  要么让 `Future_poll` 认这个布局，要么改成只包 `Future` 本体。

### 第 288–291 轮：async 同步语义落地（748 → 791 / 909，87.0%）

把 async 从「完全不支持」推到 **92 个 async 用例里 53 个通过**（整机 748 → 791，
零回归，两次全量普查确认）：

1. **`exec_lower_function` 去掉 async 硬门禁**：`@async_fn` 按普通函数降级。
2. **`BC_AWAIT` 新指令**（`bytecode.uya` / `builder.uya` / `vm.uya`）+
   `HIR_EXPR_AWAIT`：`@await f` 求值出 Future 后取 Ready 载荷。
   `exec_vm_await_find_poll()` 递归找 `state: Poll<T>` 那个联合值——
   能穿透接口装箱（`[方法入口…, 数据]`）、`!Future<T>` 的 ok 载荷、指针引用。
3. **async 返回值自动包装**：`exec_lower_wrap_async_return()` 把 `return x`
   包成 `Future{ state: Poll.Ready(ok(x)) }`；返回类型是接口时再走
   `HIR_EXPR_INTERFACE_BOX` 装箱。`exec_lower_async_return_needs_wrap()` 负责
   区分「返回 Future」和「返回载荷」两种写法。
4. **自实现 poll 的 Future**：`exec_vm_await_poll_interface()` 用
   `exec_vm_call_function()` 递归调用接口方法表里的 `poll`，同步忙等到非 Pending。

**仍然红（39 个 async）的主要簇**：
- `_uya_async_frame_heap_fallback` / `libc_EAGAIN` 一类 **C99 运行时符号**
  （`当前仅支持局部变量/参数/全局标识符(...)`）——这些是 codegen 侧注入的
  全局，VM 里没有对应物，需要补一套 VM 版 async frame 运行时（约 12 个用例）；
- `LOAD_FIELD 字段越界(kind=21/22)`：async 函数里 `try` 的错误提前返回
  走的是 builder 的 TRY 快路径，绕过了 lowering 的 Future 包装，于是调用方
  拿到裸错误值。试过在 builder 侧用 `exec_builder_wrap_async_future()` +
  `exec_builder_box_async_future()` 补包装（把接口方法表通过 `hir_try.extra`
  传下去），但两个用例随即**整例超时（rc=124）**、`test_async_error_propagation`
  仍红，已回滚。下一轮应该改成「async 函数里的 try 在 lowering 阶段就展开成
  catch + 显式 return」，而不是在 builder 里补。
- 真正需要挂起/重放的用例（如 `test_async_compound_try_await` 断言
  `pending_seen == 1`）在同步 VM 下不可能满足，属于设计限制。

### 解释器性能：`test_tls_ecdsa` / `test_tls_rsa` 超时（200s 起）

两个大整数密码学用例在 VM 里跑不完（`timeout 240` 仍是 rc=124），
和 `test_tls_x25519_pure`、`test_crypto_ed25519` 是同一簇：2048 位模幂在解释器里
是 ~10^8 条字节码量级，C99 侧是原生乘加。定长 u64 数组改原生内存后单次 limb
拷贝已经变成 memcpy，但整体指令数没变，所以仍然超时。要么做 AST/HIR 级常量折叠
与循环特化，要么接受这一簇继续红（不影响 parity 判定口径之外的用例）。

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

### 第 279 轮末：`make exec-parity` 实测（parity 门禁现状）

跑了一遍真正的门禁脚本（`UYA_PARITY_JOBS=6`，报告 `/tmp/parity_r275.tsv`）：

```
用例 914，OK 741，STATUS_MISMATCH 173（STDOUT_MISMATCH / TIMEOUT / CRASH 均为 0）
```

第 285 轮后复测（`/tmp/parity_r282.tsv`）：**OK 744 / STATUS_MISMATCH 170**，
与 census `748 / 909（82.3%）` 同步前进。

`STATUS_MISMATCH` 里绝大多数是 async（C99=0 / VM=1），其余是本文档里已经归类的
assertion 簇（pthread、堆页布局、文件 IO、大整数超时）。**parity 与 census 的口径不同**
（parity 比的是 C99 vs VM 的退出码/stdout，两端都失败算 OK），所以
「census 745/909」与「parity 741/914 OK」是同一处的两种视图。

### 第 318 轮：`memcpy` 位重解释（`test_protobuf_wire` 的 30 号返回）也卡在同一处

`test_protobuf_wire` 返回 30 的位置是 `pb_bits_to_f32(pb_f32_to_bits(1.0)) != 1.0`，
两个 helper 都是 `memcpy(&u as &void, &f as &const void, 4)`。逐层验下来：

- `lib/libc/mem.uya` 的 `memcpy` 是 Uya 循环 `dest[i] = src[i]`，在 `&local`
  上会 `LOAD_INDEX 越界`；把它强制走宿主桥（`exec_lower_extern_can_run_in_vm`
  里对 mem* 返回 0）之后不再报错，但**结果仍是 0**。
- 在 `exec_vm_mem_view` 前打点看到：`dstv=1（VALUE）srcv=0（HOST）`、
  `dk=sk=14（POINTER）` —— 目标 `&u` 是正常内引用，**源 `&f as &const void`
  既不是内引用、地址也不在 VM 值竞技场里**，于是按宿主内存处理，
  `memcpy` 从错误的地址搬了 4 字节，`u` 永远是 0。
- 对照实验：`fn setp(p: &i32)` / `fn setv(p: &void)` 写 `&x`（x 是参数）
  两个后端都是 42/43 ✓ —— 所以「`&param` 能写」没问题，
  问题专属于 **`&param as &void` 这种再转换后丢失引用编码**的值。

补过两处（`mem_view` 把「VM 驻留地址的裸指针」也算 VALUE、
`exec_vm_value_semantic_target` 从地址还原目标）都没能让它命中（地址不在竞技场里），
已回滚。

更小的复现（第 319 轮）：**根本不需要 memcpy** ——

```uya
fn direct(f: f32) i32 {
    const p: &const byte = &f as &const byte;
    _ = printf("d=%d %d %d %d\n", p[0] as i32, …);   // VM: LOAD_INDEX 越界
}
```

C 后端打出 `0 0 128 63`，VM 直接 `LOAD_INDEX 越界`。也就是说缺的是
**「标量的字节视图」**：`&scalar as &byte` 之后的下标读要取该标量**位模式**里的第 i 字节。
落点已确认在 **`BC_LOAD_INDEX`/`BC_STORE_INDEX` 处理器的「内引用」分支**里
（不是 `exec_vm_load_pointer_index` —— `p[0]` 先走内引用分支，index=0 时按 `*ref`
取回**整个值**、index≥1 才落到 `exec_vm_index_ref` 报越界）。

本轮按这个位置写了「标量位模式 + 按字节移位」的读/写（含
`exec_vm_scalar_bits_of` / `exec_vm_store_scalar_bits` 两个 helper），
越界消失，但读出来全是 0。打点把真因钉住了：

```
DBG bidx pkind=14 pointee=10 idx=0 tgtkind=10 tgti64=0
                     ↑ pointee=byte        ↑ 目标竟然是 **BYTE** 值，值是 0
```

也就是说 `&f as &const byte` 生成的内部引用**指向了一个新装箱的 BYTE 值**
（`BC_BOX_VALUE` 按新类型重新装箱），而不是指向那个 `f32` 参数。
所以问题不在「取位模式」，而在「指针→指针转换时被重新装箱」这一步：
修法是让 `&T as &U`（同为指针/引用）**复用原引用**（只改 pointee kind），
不要新建装箱值。

但**单次转换**的 dump 看又是干净的：

```
0: BC_ADDR_LOCAL a=3 b=0 c=11     ← 参数槽 0 的内引用，pointee=f32(11)
3: BC_CAST      a=4 b=3 c=10 imm=18  ← 转成 pointee=byte(10)，仍是内引用
8: BC_LOAD_INDEX a=7 b=5 c=6      ← p[0]
```

也就是说 `&f` 本身没问题、转换也保留了内引用，问题在 `LOAD_INDEX` 里
`exec_vm_ref_target_value` 拿到的那个值。本轮把这条链打了一遍点，结论是：

```
DBG vref addr=<slot 地址> kind=16 …            ← ADDR_LOCAL 正常
DBG lidx refaddr=110613224 pointee=10 idx=0 tgtkind=10 tgti64=0
                                        ↑ 槽地址处的值竟然是 **BYTE 0**
```

即「引用地址是对的，但那个槽上已经不是 `f32` 参数，而是一个 BYTE 0」。
结合「同一函数里 `printf("f=%d", f)` 打出 2」可以判断：`f` 的槽在取址之后
被某个**临时槽**覆盖了（VM 的槽分配/生命周期问题，不是 cast 问题）。
下一轮的入口很明确：查 `chk`/`two_step` 这类「参数取址 + 后续临时」的函数里
frame 槽位分配。已经排掉的两个可能：

- `exec_builder_new_temp` 从 `fn_hir.local_count` 起分配 ✓ 临时槽不会落在参数槽上；
- `exec_builder_restore_temp_watermark` 只回收**临时**槽，参数/局部不受影响 ✓。

所以嫌疑集中到运行期。查过 `vm.uya` 的 `exec_vm_run_frame`：帧槽来自
`exec_vm_slot_pool_push(function.slot_count)` 的**槽位池**（push/pop 成对，
被调帧在调用者之上），一次性把 `slot_count` 个槽清成 void，之后不再扩容 ——
所以「帧扩容导致内引用悬空」这条也不成立。

又打了一轮点，**定案了**：

```
DBG mkref addr=110613224 kind=11(F32) tgtkind=10(BYTE) tgti64=0
DBG lidx  refaddr=110613224 idx=0    tgtkind=10(BYTE) tgti64=0
```

引用地址没错（`ADDR_LOCAL` 出来的就是那个槽），**但进函数时那个参数槽里就已经是
BYTE 0，不是 f32 2.5**。而同一形状的对照用例（`fn show(x: f32)` 里
`(x*2.0) as i32`）在 VM 里是**正确**的 5 —— 差别只有「callee 里对参数取了地址
并转成 `&const byte`」。

也就是说：**callee 内部对参数取址+改 pointee 的写法，反作用到了调用点的实参传递**
（参数槽被按 byte 装箱/清零）。

再对比一组就能定位到「实参是字面量」这一层：

```uya
_ = chk(2.5);            // VM: 参数槽是 BYTE 0（错）
const v: f32 = 2.5;
_ = chk(v);              // VM: 参数槽是正常 f32（随后只差「标量字节视图」）
```

所以是「**浮点字面量传给 f32 形参**」这一步被按 byte 处理了；而
`fn show(x: f32)` + `(x*2.0) as i32` 这种正常用法是对的。

**但把 printf 放在取址之前，就又全对了**：

```uya
fn chk(f: f32) i32 {
    _ = printf("early=%d\n", (f * (2.0 as f32)) as i32);   // → early=5 ✓ 参数是 f32 2.5
    const q: &const byte = (&f) as &const byte;
    const b2: i32 = q[2] as i32;                            // → 0（应为 32）
}
```

也就是说**参数本身没问题**，之前看到「参数槽是 BYTE 0」是「函数第一条语句就是
取址+转 pointee」这个特例下的现象（顺序敏感 → 更像槽位/临时复用的边界）。
「标量字节视图」按 `i64_value` 取位模式的实现本身也没错，但实测拿到的位模式是 0，
说明 `exec_vm_ref_target_value` 在这条路径上取到的不是那个 f32 槽。

**结论**：这条线还剩「ref 目标在顺序敏感场景下取错」一个未解点，
其余（位模式换算、store 对称实现）都已就位；代码回滚，下一轮直接对比
「第一条语句就取址」与「先 printf 再取址」两种函数体的 bytecode 槽位分配即可。

代码全部回滚，只留结论与落点。

### 第 317 轮：`async_event` 的注册链路打通了一半（卡在 native 结构体字段访问）

在 VM 的 `exec_vm_exec_syscall` 里给 nr∈{232,233} 打点后可以确认**注册是真的发生了**：

```
epoll_wait(epfd=5, buf, maxevents=1024, 0)
epoll_ctl (epfd=5, op=1 ADD, fd=6, …)
```

也就是说 `create_ok.register(read_fd, ...)` 走到了内核。`ready_n == 0` 的两层原因：

1. `epoll_ctl` 的第 4 个实参（`struct epoll_event *`）在 VM 里是**本地聚合**
   （wrapper 内存），内核读到的兴趣掩码是垃圾 → 注册进去的事件掩码无效。
   按 C 布局把它拷成原生缓冲区再传（写了 `exec_vm_syscall_struct_to_native`：
   按字段宽度 + 自然对齐逐字段写 u8/u16/u32/u64），注册就**生效**了。
2. 但生效之后立刻撞上第二层：
   `lib/libc/syscall.uya:1876: exec: LOAD_FIELD 字段越界(idx=1 kind=14 count=-1 pointee=16)`
   —— 库代码从「内核写好的原生 `EpollEvent` 数组」里读 `data_lo` 时，
   VM 走不到原生字段通道（`exec_vm_field_native_base` 拿不到可用的基址 /
   缺 C 布局字段元数据），只能退回聚合字段访问而失败。

这个第二层和 **io 簇是同一个缺口**：native 结构体的字段访问
（`FILE.buffer`、`EpollEvent.data_lo` 都是它）。修它是「让 native/C 布局的结构体
有字段视图」这一件事，能同时推进 io（3 例）+ async_event 系（3 例）。

第 1 步的 `exec_vm_syscall_struct_to_native` 因为当前只服务 `epoll_ctl`、
且第 2 步没通就整体收益为零，本轮回滚（避免半截代码留在主路径），
结论与形状都记在这里，下一轮直接从「native 结构体字段视图」入手。

**同一轮里又验了两件事**（都回滚了，但把范围缩到最小）：

- 第 1 步（`epoll_ctl` 事件结构原生化）确实能把事件真正注册进内核：加回这段后
  报错点从「`ready_n == 0`」变成 `epoll_event_fd` 里的字段访问，说明注册生效了。
- 第 2 步给 `ADDR_INDEX` 加了「元素字节数」通道（`imm` 高 32 位，lowering 用
  `@size_of(结构体)` 填，VM 对**原生指针**按 C 布局步进并返回裸指针），
  但 `epoll_event_fd(event: &EpollEvent)` 里的 `event.data_lo` 仍然走不到原生字段
  通道 —— 报错还是 `LOAD_FIELD 字段越界(idx=1 kind=14 count=-1 pointee=16)`。
  也就是说**卡点已经缩小到 builder 这一侧**：`&Struct` 上的成员访问没有把
  `kind` 打进 `LOAD_FIELD` 的 imm。

  直接 dump 出来看得很清楚 —— `lib/libc/syscall.uya: epoll_event_fd`：

  ```
  fn[147] epoll_event_fd slots=4 params=1 varargs=0
    0: BC_LOAD_LOCAL a=1 b=0
    1: BC_LOAD_FIELD a=2 b=1 c=4 imm=1      ← c=4 是字段字节偏移（data_lo 正确），
                                              但 imm=1 只有字段下标，没有 kind
    2: BC_CAST a=3 b=2 imm=2
    3: BC_RET a=3
  ```

  VM 侧判据是 `exec_vm_field_imm_kind(imm, 32) -| 1 > 0`，imm=1 取出来是 0，
  于是原生字段通道被跳过 → `exec_vm_field_ref` 在裸指针上失败
  → `LOAD_FIELD 字段越界(idx=1 kind=14 count=-1 pointee=16)`。
  lowering 里 `hir_field.binary_op = native_kind | (native_pointee << 8)`
  明明设置了（u32 字段应当是 7），说明这条赋值在这个访问上没有落到 builder
  用的那份 HIR 节点上（或者中途被复制丢了）—— 下一轮从
  `exec_builder_pack_field_imm` 的输入侧继续查即可。

### 第 316 轮：`async_event` 的「静默退出」根因修掉（出参结构体判定太严）

第 312 轮定位到的「`BC_SYSCALL` 里静默退出」，真正的原因找到了：

- `@syscall` 元数据里带一个 `out_mask`（哪些实参是内核回写的结构体）。
  `sys_epoll_wait` 的第 2 个实参类型是 `&EpollEvent`，builder 就把它标成了出参；
- 运行期 `exec_vm_syscall_marshal_out_struct` 找不到「能解析成单块结构体」的目标
  （实参实际是**结构体数组**的原生首地址），`prepare` 返回 null，
  于是直接 `return -1` 把整次系统调用判死；
- 这个 `-1` 一路冒泡成「解释器失败」，但没有任何 message，表现出来就是
  **进程 rc=1、一行日志都没有**（和 `main` 里 `catch { return 1 }` 完全同样的现场，
  所以前面几轮一直被误判成 `linux_epoll_create` 失败）。

修法：出参准备失败时**保留原指针继续调 syscall**（`continue`），不要把整次调用判死。

修完的效果：

```
local err=0
field err=0        ← sys_epoll_wait 正常返回
test_std_async_event             rc: 1 → 11（卡在 ready_n == 1）
test_std_async_event_fd_reuse    rc: 1 → 4 （卡在 n1 == 1）
test_async_compute_types         rc: 1 → 11
```

也就是这三个用例从「第一句就静默死」推进到了「真的在等事件」。剩下的
`ready_n == 1` 是新问题：`linux_epoll_alloc_events` 用 `calloc` 拿到的是**原生**内存
（✓ 内核能写），但 VM 侧读 `self.events[i].data` 走的是自己的字段偏移，
需要和内核的 `struct epoll_event`（packed，12 字节）对齐 —— 这是下一个入口。

census `/tmp/census_r336.tsv` 仍是 **823 / 909**（无增无减、无回归），
但这一轮把「静默退出」这个反复误导排查的现象消灭了。

第 316 轮末又试了一版 `epoll_ctl` 的「入参结构体按 C 布局拷成原生缓冲区」
（写了一个按字段宽度+自然对齐的小 `exec_vm_syscall_struct_to_native`），
`ready_n` 仍是 0，说明注册链路另有断点（`register` 未必走到这个 syscall，
或者 `linux_epoll_lookup_capacity`/slot 表在 VM 里读不到），遂回滚，只留结论：
**下一步要先确认 `create_ok.register(read_fd, ...)` 到底有没有真的 syscall 到内核**。

### 第 315 轮：为什么不能直接把 `strtod` 交给宿主（`--nostdlib`）+ 自举两趟的坑

试过把 `lib/libc/stdlib.uya` 的 `strtod` 改成不带体的 `extern "libc"`（映射 glibc），
并给镜像 TU 补原型。结果在**链接**阶段失败：

```
types.c:(.text+0x1a24): undefined reference to `strtod'
vm.c:(.text+0x9abd): undefined reference to `strtod'
```

原因是自举编译器用 `RUNTIME_MODE=nostdlib LINK_MODE=static` 构建（零依赖静态），
**根本没有 glibc 可链接** —— 所以 `strtod` 必须是 Uya 实现。想让编译器侧的
浮点字面量精确，只能把 Uya 版 `strtod` 做成正确舍入（需要一个小的十进制 big-int：
约 40 个 u32 limb + 一次四舍五入取 54 位尾数），不能靠"调宿主"绕过去。

另外记两个自举流程的坑（都会让人误以为改动没生效）：

1. **codegen 改动要两趟**：`make uya` 用的是**当前** `bin/uya` 去编译 `src/`，
   所以 `src/codegen/c99/*` 的改动只影响"再下一趟"生成的 C。
2. **生成缓存按模块源码做键**：改完 codegen 后如果直接 `make uya`，
   镜像 .c 会命中旧缓存不重写；必须 `rm -rf src/.uyacache` 再编，
   否则你会看到"明明改了却还是旧输出"。
3. 把 `bin/uya` 弄成"会发某条原型"的状态后，若同时改了对应 lib 函数签名，
   会陷入"新种子编不出旧签名"的死循环；用 `make from-c` 回到 `bin/uya.c` 种子
   再 `make uya` 可以脱困。

### 第 314 轮：`%a` 指数位真 bug 修好（`1023` 被打成 `:23`）+ 字面量精度的真源头

顺着第 313 轮的「`0` 变成 `:`」痕迹找到真 bug：`lib/libc/stdio.uya` 里两处
指数输出都写成

```
if exp >= 100 { buf[pos] = '0' + exp / 100; exp = exp % 100; }   // 1023/100 = 10 → ':'
```

`exp / 100` 可能是两位数（`%a` 的十六进制指数到 1023），直接 `'0' + 10` 就落成
`':'`。两处都改成「先按位取到 `[byte: 4]` 再倒序输出、不足两位补零」，`%a` 现在
两个后端都打 `0x1.fffffffffffffp+1023` ✓（十进制指数 ≤ 308 的行为不变，
`1e+05` 这种仍补零）。

顺带把 `%#.17g` 的最后一段也钉死了：**值和格式化器都没问题，问题在字面量精度** ——

- 用 `%a`（现在可信）看 `1.0e308`：VM 是 `0x1.1ccf385ebc89fp+1023`，
  C 后端是 `0x1.1ccf385ebc8a3p+1023`，**差 4 ULP**；而 `1.7976931348623157e308`
  两边都是 `0x1.fffffffffffffp+1023` ✓。
- 原因：C 后端把浮点字面量**按文本重新发射**（`%#.17g` 或 DBL_MAX 专用字面），
  由 C 编译器精确解析；VM 用的是编译器里 `parse_float_literal_with_suffix`
  调 `strtod` 得到的值，而那个 `strtod` 是 **Uya 实现**（`lib/libc/stdlib.uya`），
  十进制累乘路径在 308 这种指数上会差几 ULP。DBL_MAX 因为写了位模式的快速路径
  才是准的。
- 想把这条路彻底修好，得让编译期浮点字面量用宿主 `strtod`：把
  `lib/libc/stdlib.uya` 的 `strtod` 改成不带体的 `extern "libc"` 即可映射到 glibc，
  但生成文件里还要补一条 `extern double strtod(const char*, char**)` 原型
  （`has_stdlib_conflicts` 时不会包含 `<stdlib.h>`；自举构建也不包含），
  本次试到这一步因为原型没落到对应 TU 而回滚，代码只留记录。

**本轮实测**：census `/tmp/census_r335.tsv` = **823 / 909（90.5%）**（与上轮持平，
纯修正格式化 bug）；`make check` 复测 **1191 / 1191 通过**。

### 第 313 轮：`%#.17g` 的锅不在「浮点值」也不在「va_list」

把 `test_printf_f` 的 `snprintf_g_dbl_max` 一路二分到底，结论和之前记的都不一样：

- **浮点字面量是准的**。`%.17e` 那些「差 11 ULP」的读数全都是 Uya 侧
  `_fmt_f64_to_buf` 自己缩放出来的假象；改用宿主 `%a` 直接看十六进制，
  `1.7976931348623157e308` 的字面量正好是 `0x1.fffffffffffffp+1023`（即 DBL_MAX）。
- **va_list 里的实参也是准的**：给 `vsnprintf` 加一层宿主实现后，
  在 VM 里打 `exec_value_as_f64(&vsn_args[0])` 的 `%a` 同样是 `0x1.fffffffffffffp+1023`。
- 但同一次调用交给 `exec_format_printf_like` 之后，`%#.17g` 落盘成了
  `1.7976931348623146e+308`。也就是说**误差在 `src/exec/format.uya` 的
  逐转换路径里**（`exec_format_snprintf_typed` 对 `g` 的处理），不在值、不在变参。

顺带完成的两件事（都不改变普查结果，`r333 → r334` 无增无减，已回滚代码只留记录）：

1. `vsnprintf` 走宿主实现是可行的：匹配要放在 `is_varargs == 0` 分支**之外**
   （`va_list` 形参会让 checker 把它标成 varargs），否则永远匹配不上。
2. 即使走宿主，`%f` 的四个用例全绿、`%#.17g` 仍差 —— 因为格式化实际落在
   `exec_format_printf_like` 上，没有直接落到 glibc。

**下一步入口（第 313 轮又缩小了一圈）**：用 `printf`（它本来就走
`EXEC_HOST_CALL_PRINTF_FIXED` → `exec_format_printf_like`）打 DBL_MAX：

```
printf("%#.17g", dmax)  → 1.7976931348623159e+308     ← 差 2 ULP
printf("%.17g",  dmax)  → 1.7976931348623159e+308     ← 差 2 ULP
printf("%a",     dmax)  → 0x1.fffffffffffffp+:23      ← 尾数全 f（值是对的），
                                                        但指数 "1023" 被写坏成 ":23"
```

`%a` 的尾数正好是 `0x1.fffffffffffffp`，说明**值本身没问题**；而指数里
`1` 消失、`0` 变成 `:`（'0' + 10）这种痕迹，指向前面的**渲染/拷贝环节把输出字符写坏了**
（`exec_format_render` → `exec_format_append_value` → 局部缓冲 `local[512]`
→ `exec_format_buffer_append` 这条链上的下标/长度算错）。
`%g` 的 2 ULP 差很可能是同一个写坏问题的另一种表现。
下一步就在这条链上找下标错误，而不是继续怀疑浮点值或 va_list。

### 第 312 轮：`test_std_async_event` 卡在 `BC_SYSCALL` 里静默退出（线索已定位）

`test_std_async_event` 的 `main` 第一句就是 `linux_epoll_create(0) catch { return 1 }`，
所以「rc=1、一行输出都没有」一直被当成「建 epoll 失败」。逐层剥下来结论不是这样：

- `linux_epoll_create_config(0, N, N)` 在 N=4…65536 全部成功（`epfd=5`）；
- `@syscall(291)` / `@syscall(232, epfd, buf, 4, 0)` 直接写在用例里都正常；
- 但只要调用**库里的** `lib/libc/syscall.uya: sys_epoll_wait`，
  `--trace-vm` 的最后一帧就是该函数的 `BC_SYSCALL`，进程随即以 1 退出，
  既没有 `exec runtime:` 报错，也没有 `catch` 分支的输出 —— 说明不是用户态
  `return`，而是 `BC_SYSCALL` 处理里直接结束了。
- 同一调用点用 DBG 打出来的四个实参是对的
  （`epfd=5`、缓冲区是完整 64 位地址、`maxevents=4`、`timeout=0`），
  所以不是上一次怀疑的「`&buf[0] as i64` 被截断成 32 位」（那个是另一回事，
  见下）。

**下一步入口**：在 `exec_vm_exec_syscall` 里给 `exec_vm_dispatch_host_syscall`
前后加返回值/`out_mask` 打点，看是 4 参 syscall 返回错误后被吞掉，
还是 `exec_vm_syscall_marshal_out_struct` 这类旁路在 `arg_count == 4` 时直接 `-1`。
`test_std_async_event_fd_reuse`、`test_async_compute_types`（`thread_test_epoll`）
都堵在同一个点上，修通它是 3 个用例。

**顺带发现（独立问题）**：把值竞技场推高到 2 GiB 以上后
（先分配 `[i64: 20971520]` 再取 `&buf[0] as i64`），
`&buf[0] as i64` 会拿到符号扩展过的负数地址，而同一处
`@usize_from_ptr(&buf[0] as &void)` 是正常的 64 位地址 ——
两条路径对「内部引用的地址」取值口径不一致，需要统一（这条会影响所有
把数组元素地址交给 syscall/宿主的地方）。

### 第 311 轮：pipeline / io / f64 三处根因再确认（无新增通过）

这轮没有新增用例，但把三条「看起来像 lowering bug」的线全部钉到了内存模型上，
免得后续再重复挖：

1. **`test_std_script_pipeline_facade`（`result.stage_count == 0`）**：
   `lib/std/process.uya:1926` 的 `pipeline_read_startup_record` 用 C 布局做字节偏移 ——
   `@ptr_from_usize(@usize_from_ptr(record) + received)` 然后
   `read(fd, target, @size_of(PipelineStartupRecord) -| received)` 把内核字节直接
   灌进结构体。解释器里 `record` 是「指向 `ExecValue` 的内引用」，`read()` 写的是
   wrapper 内存，把结构体聚合头写坏（实测随后 `report.kind` 报
   `LOAD_FIELD 字段越界(idx=0 kind=16 count=0)`，`count=0` 就是聚合头被覆盖）。
   同一模式下 `test_typed_pipeline_lowering_error` 也是「C 侧 codegen 独有」的
   `pipeline_drop` 清理（`src/codegen/c99/expr.uya` 里插入，AST 里没有），
   exec 侧要补得先有临时值 move 语义。
2. **io 簇**：见第 310 轮附；另确认逐元素 gather/scatter 的思路在 `@syscall`
   路径上无效（缓冲区进 syscall 时已是裸 `i64`，内引用标记丢失）。
3. **`test_printf_f`（`%#.17g` 打 DBL_MAX）**：`*((&x as *const u64) as *const f64)`
   这类**位重解释在解释器里拿不到位模式**（内引用解出来是 `ExecValue`，转 u64 走的是
   数值转换），所以 `lib/libc/stdlib.uya` 的 `strtod_f64_from_bits` 在 VM 里返回
   `9.218e18` 而不是 DBL_MAX，DBL_MAX 的快速路径整体失效；再叠加
   `_fmt_f64_to_buf` 用 `x / 1.0e308` 归一化引入的 1–2 ULP，末位必然对不上。
   要修得先让「标量位重解释」在 VM 里有等价路径（`@bit_cast` 之类），
   而不是继续在格式化器里打补丁。

### 第 310 轮：`setjmp` 宿主实现（822 → 823 / 909，90.5%）

`test_setjmp` 卡在 `env.data[7] != 0`：`lib/libc/setjmp.uya` 的 `setjmp` 是
`@naked_fn` 的内联汇编（`movq %%rbx, 0(%%rdi)` … 保存 rbx/rbp/r12-r15/rsp/rip），
解释器没有寄存器现场，零值桩让 `jmp_buf.data` 全是 0。

改法（三处，都是「宿主实现」这条既有通道）：

1. 承载宿主调用的判定原来只认 `fn_decl_is_extern != 0`，`setjmp` 不是 extern，
   永远进不了宿主桥。现在对 `setjmp`/`_setjmp`/`sigsetjmp` 三个名字放行
   （`naked_host_call`），并用 `exec_lower_match_host_call_name` 直接按名字匹配。
2. `EXEC_HOST_CALL_SETJMP` / `_SIGSETJMP`：实参是 `&jmp_buf`，先
   `exec_vm_ref_target_value` 解到结构体本体，再取 `data` 字段，
   `exec_value_set_index` 逐项写 1..8（`data[6]`/`data[7]` 即 rsp/rip 标记）。
3. 关键坑：`jmp_buf.data` 是 `[u64: 8]`，解释器把它建成**原生 raw array**
   （`exec_value_is_raw_array` 为真），`exec_value_as_aggregate` 直接返回 null，
   走 `exec_vm_index_ref` 一律拿不到元素 —— 标量数组必须用
   `exec_value_set_index` 写，不能按聚合取元素引用。

**本轮实测**：`/tmp/census_r333.tsv` = **823 / 909（90.5%）**，`r331(822) → 823`，
+1 / 0 回归。`make check` 复测 **1191 / 1191 通过**。

另记一条没走通的尝试（免得后来重复踩）：把 `snprintf`/`sprintf` 加进
`exec_lower_extern_prefers_host_call` 想借宿主 glibc 的十进制转换修 `%#.17g`，
结果 `%#.17g` 走出 `…146e+308`、`%.20e`/`%+.3e` 仍旧走 Uya 格式化器（`+` 旗标被吃、
`0.1` 打成 `1.00000000000000000000e-01`），两条路径混用反而更难定位，已回滚。
真因是**浮点字面量在 VM 侧落库的精度**与 Uya 格式化器的十进制缩放两处叠加，
要修得先把字面量按 glibc `strtod` 精确落库。

### 第 310 轮附：io 簇（`test_std_io*`）的根因再定位

追到 `write_to_buffer`/`flush_buffer` 之后可以确定两件事，都属内存模型：

- `FILE` 是 `malloc` 出来的**原生结构体**（`stdlib` 池），字段偏移必须按 C 布局算；
  `stream.buffer`（`[byte: 65536]`）落在原生指针的聚合旁路表里，而该表
  （`EXEC_NATIVE_AGG_MAX_ELEMS = 512`，`g_native_agg_values` 为静态
  `[ExecValue: 512] × 256`）既装不下 64 KiB，偏移也不是 C 布局 ——
  写文件时内核读到的是 `ExecValue` wrapper 的字节
  （实测文件内容 `\f\0\0\0\0\0\0\0H\0\0`：`kind=12` 后跟 `i64_value='H'`）。
- 曾试着在 `@syscall` 的 `read`/`write` 前把「地址落在值竞技场里」的缓冲区
  逐元素 gather/scatter 到原生临时缓冲区；实测 census 完全无变化
  （指针进 syscall 时已经是裸 `i64`，`exec_vm_pointer_is_internal_ref` 认不出来），
  按最小改动原则回滚，不留死代码。

要把这一簇做绿，得让「原生结构体字段」有真正的 C 布局视图（或把 64 KiB 数组
改成原生内存块），不是补 API 能解决的。

### 第 309 轮：`make check` 复核 + 剩余 30 例的阻塞归类

`make check`（本机 `UYA_TEST_JOBS=44`）**1191 / 1191 通过**，`src/exec` 的
这一串改动没有影响 C99 侧门禁。

census 复测（`/tmp/census_r331.tsv`）：**822 / 909（90.4%）**。
parity 口径下仍不匹配的是 **30 个用例文件**，按下表归类——**全部需要改动解释器
的内存/执行模型，不是「再补几个 API」能收口的**：

| 类 | 用例 | 根因 |
| --- | --- | --- |
| 内存模型（聚合布局） | `test_libc_heap_bins`、`test_libc_heap_coalescing_adjacent`、`test_libc_heap_realloc_in_place`、`test_libc_heap_tcache`、`test_std_stdlib_malloc`、`test_capability_runtime_compat` | 用 `@usize_from_ptr`/`@ptr_from_usize` 做字节偏移切页；VM 的聚合元素步长是 `sizeof(ExecValue)` 而不是 C 布局步长 |
| 字节重解释 | `test_protobuf_wire` | `memcpy(&u32, &f32, 4)` 位级重解释：`&T as &U` 会**重新装箱**成一个新值（第 319 轮打点确认），引用不再指向原标量；修法是让指针→指针转换复用原引用 |
| 文件 IO / native 结构体 | `test_std_io`、`test_std_io_buffering`、`test_stdio_file_buffering` | `FILE` 是 `malloc` 出来的原生结构体：字段偏移与 `[byte: 65536]` 缓冲区都要 C 布局视图，VM 的 `&Struct.field` 缺 `LOAD_FIELD` 的 kind 元数据（第 312/317 轮 dump 证据） |
| 异步 pending 语义 | `test_async_macro_expand`、`test_async_compound_try_await`、`test_async_state_machine`、`test_std_thread`、`test_std_thread_async_boundary`、`test_async_thread_pool_dynamic_growth`、`test_async_compute_dynamic_resource_pressure`、`test_tls_async_runtime_io` | 用例要求 `pending_seen == 1` / `pool.pending_capacity > MAX_PENDING`：VM 里 async 函数是「一次跑到底」，永远观察不到 `Pending` 这一拍 |
| OS 仿真 | `test_osal`、`test_kernel_sim` | 依赖 execve 重定向与私有栈切换（`setjmp` 已在第 310 轮用宿主实现补上，`test_setjmp` 转绿） |
| epoll 事件回读 | `test_std_async_event`、`test_std_async_event_fd_reuse`、`test_async_compute_types`、`test_async_compute_generic_wrapper` | 注册链路已通（第 316/317 轮），卡在「内核写好的原生 `EpollEvent` 数组」的 C 布局字段回读（与文件 IO 同源：native 结构体字段访问） |
| 管道脚手架 | `test_std_script_pipeline_facade`、`test_typed_pipeline_lowering_error`、`test_http_websocket_reconnect` | `pipeline_execute_basic` 内部的 fork/exec 与错误路径 drop，缺口在 lowering 的临时值 drop 与 fork 语义交界处 |
| 格式化 | `test_printf_f` | `%#.17g` 打 `DBL_MAX`：根因是**编译期浮点字面量**经 Uya 版 `strtod` 落库时差几 ULP（`1.0e308` 实测差 4 ULP，第 314/315 轮）；`--nostdlib` 下不能借宿主 `strtod`，要精确得在 Uya 侧做「尾数×10^k 的整数长除」 |

### 第 321 轮：原生结构体数组字段（`FILE.buffer` / `EpollEvent`）实验记录

把「io 3 例 + epoll 事件回读」这一簇拆到最小复现：

```uya
struct S { n: usize, buf: [byte: 8] }
const s: &S = malloc(@size_of(S)) as &S;
s.buf[0] = 72; s.buf[1] = 101;
_ = printf("%d %d | %d %d\n", s.buf[0] as i32, s.buf[1] as i32,
           (&s.buf[0] as &const byte)[0] as i32, (&s.buf[0] as &const byte)[1] as i32);
```

VM 现状（本轮起点）：`0 0 | 72 101` —— **写确实落到原生内存了**（指针路径读得到），
但 `s.buf[i]` 这条「LOAD_FIELD + LOAD_INDEX」读回来是 0。逐层打点结论：

1. `LOAD_FIELD` 的 `imm` 里其实**带了**字段 kind/pointee/count（`kind=20`、`pointee=10`、
   `count=8`），`exec_vm_native_field_load` 也确实造出了 raw array 视图（`vkind=17`）。
   dump 里看到的 `imm=1` 是 `debug.uya` 用 `%ld`（32 位）打印 **截断**后的假象 ——
   第 317 轮据此下的「imm 缺 kind」结论是错的，这里更正。
2. 真正断掉的是 **`ADDR_FIELD` 的 pointee kind**：`s.buf[i]` 的基址指针带的是
   `ARRAY(19)`，而 `exec_vm_type_kind_size(19) == 0`，原生路径算不出元素步长。
3. 改成「数组字段取址时按 C 语义退化为元素 kind（`[byte: N]` → `BYTE`）」后，
   `s.buf[0] = 72` 立刻不再报 `LOAD_INDEX 越界`，`&s.buf[0]` 也能读到 `72`。
4. 但 `s.buf[i]` 的**读**仍然是 0：打点显示 `LOAD_FIELD` 看到的是
   `base=0 / i64_value=<32 位截断>` 而 `ptr_value=<真实地址>` —— 同一个
   `ExecValue` 里 `i64_value` 和 `ptr_value` 不一致，`exec_vm_pointer_address`
   只读前者，于是原生基址判定失败、退回 VM 聚合语义。
5. 试过把 `exec_vm_pointer_address` 改成「优先 `ptr_value`」：语义上更对，但
   一批用例立刻段错误 —— 说明确实有路径**只写 `i64_value`、`ptr_value` 是脏的**，
   必须先把「谁在写半截指针」找出来，不能只改读取端。
6. 另试过在 `flush_buffer`/`write_to_buffer`/`fread` 里经原生临时缓冲区中转
   （`malloc` + 逐字节拷），能把写出来的「wrapper 字节」变成真正的字节流，
   但读回路径没通，`test_std_io` 仍是断言失败，故一并回滚。

**下一轮入口**：在 `exec_make_pointer_with_kind` 之外找「谁构造了
`i64_value` 32 位截断的 POINTER 值」（怀疑是 `usize`↔`i32` 的
`exec_vm_numeric_to_u64` 路径或 `as` 转换链），修好构造端后
再开「数组字段退化为元素 kind」这一刀。

`tests/exec_vm_parity_skip.txt` **不能**收这 30 个：该表的纪律是「只登记 C99 侧
同样跑不了的用例，exec VM 自身的未实现不能写在这里」。所以 `make exec-parity`
在本轮仍是红的，红的范围就是上表。

### 第 322 轮：原生结构体指针下标 / 内部引用字节视图 / 浮点隐式窄化

本轮把第 321 轮留下的「谁在写半截指针」问题绕开，直接从**编译期补元信息**入手，
一次收掉 6 个用例（`test_std_io`、`test_std_io_buffering`、
`test_stdio_file_buffering`、`test_std_async_event`、`test_std_async_event_fd_reuse`、
`test_protobuf_wire`）。三个根因：

1. **原生结构体指针下标没有 C 布局步长。** VM 的 `exec_vm_type_kind_size(STRUCT)`
   恒为 0，`&EpollEvent[i]`、`&FILE[i]` 这类下标只能退回「旁路表槽位引用」，
   而旁路表是按 `ExecValue` 步进、且槽位常常是零值（kind=VOID），于是字段访问
   报 `LOAD_FIELD 字段越界(idx=1 kind=14 pointee=16)`。
   现在 `BC_ADDR_INDEX` / `BC_LOAD_INDEX` / `BC_STORE_INDEX` 的 `imm` 都带上
   **元素字节数**（`ADDR_INDEX` 低 32 位仍是 pointee kind，高 32 位是元素尺寸），
   VM 在「基址不在 VM 内存里」时按真实步长算出元素地址；三个降级点补齐来源：
   `ARRAY_ACCESS` 的 INDEX 节点（`int_value`）、`&arr[i]` 的 ADDR 节点
   （`bool_value`，ADDR 的 `int_value` 是字段下标不能混用）、`*p` 解引用节点。
2. **`p.field`（基类型是 `&T`）算不出原生字段布局。** `epoll_event_fd(event: &EpollEvent)`
   里的 `event.data_lo` 因为基类型是指针而不是结构体，`exec_lower_native_field_layout`
   直接跳过，运行时又退回 VM 聚合语义 → 字段越界。现在先解一层指针再算布局。
3. **内部引用的字节视图下标不成立。** `lib/libc/mem.uya` 的 `memcpy` 是 Uya 字节
   循环（`dest[i] = src[i]`），走不到宿主 `memcpy` 特化；而 `&u64 as &byte` 这类
   内部引用指向的是 VM 槽里的标量本身，按下标访问会按 `ExecValue` 步进越界。
   新增「标量字节视图」：pointee 为 byte/u8/i8/void 且目标槽里是多字节标量时，
   `LOAD_INDEX`/`STORE_INDEX` 直接拆/拼该标量的原始位。`pb_f32_to_bits` 这类
   `memcpy(&bits, &f, 4)` 位重解释因此成立。
4. **`var f: f32 = 1.0` 存进去的是 f64 位模式。** C 侧靠赋值隐式转换，VM 的值自带
   kind，必须显式插 CAST；`exec_lower_coerce_expr` 补了浮点（f32/f64/整数 → f32/f64）
   的强制转换。少了这一条，即使字节视图正确，`memcpy(&bits, &f, 4)` 也只有读到
   低 4 字节全 0（f64 1.0 的位模式低半是 0）。

另修 `syscall` 指针实参一律以 `ptr_value` 为准（`i64_value` 在部分数值转换路径上
会被截成 32 位，把半截地址交给内核），以及 `epoll_ctl` 的 `&EpollEvent` 入参按
packed 12 字节 C 布局转写进原生缓冲区。

**本轮实测**（只跑受影响 + 原失败清单，未跑全量普查）：
`test --vm` 侧 `test_std_io` / `test_std_io_buffering` / `test_stdio_file_buffering` /
`test_std_async_event` / `test_std_async_event_fd_reuse` / `test_protobuf_wire` 全绿；
`test_std_mem`、`test_math`、`test_std_stdlib_malloc` 等相邻用例无回归。
原 29 例失败清单实测剩 **23 例**（C 侧全部 rc=0）：

| 类别 | 用例（VM 退出码） |
| --- | --- |
| 聚合/堆按 C 布局裸指针算术 | `test_capability_runtime_compat`(11)、`test_libc_heap_bins`(2)、`test_libc_heap_coalescing_adjacent`(2)、`test_libc_heap_realloc_in_place`(1)、`test_libc_heap_tcache`(44)、`test_std_stdlib_malloc`(9) |
| async 状态机（VM 同步执行到完成） | `test_async_macro_expand`(1)、`test_async_compound_try_await`(2)、`test_async_state_machine`(3)、`test_async_compute_types`(11)、`test_async_compute_generic_wrapper`(2)、`test_async_frame_pool_full`(1)、`test_async_compute_dynamic_resource_pressure`(1) |
| 线程/线程池 | `test_std_thread`(23)、`test_std_thread_async_boundary`(3)、`test_async_thread_pool_dynamic_growth`(5)、`test_tls_async_runtime_io`(1) |
| fork/execve + 管道 | `test_osal`(3)、`test_std_script_pipeline_facade`(1) |
| x86 call gate / 内核模拟 | `test_kernel_sim`(5) |
| pipeline 错误路径 drop | `test_typed_pipeline_lowering_error`(2) |
| 浮点格式化 | `test_printf_f`(1) |
| websocket 重连 | `test_http_websocket_reconnect`(1) |

**下一轮入口**：
- 堆一族里 `test_libc_heap_realloc_in_place` 已定位为**状态残留**：单独跑第二个
  test 通过，连跑时 carve 8 次都找不到连续的 A/B/guard 布局 —— 需要用
  `heap_debug_bin_length` 对比「第 1 个 test 收尾后」的 bin 分布（C 侧 vs VM 侧）。
- `test_capability_runtime_compat` 的 `capability_registry_entry_ptr` 用
  `@size_of(T)` 在**VM 聚合**上做裸指针算术（VM 侧元素步长是 `sizeof(ExecValue)`），
  这是「C 布局假设」类，必须先把聚合的 VM 表示改成原生布局，不是局部补丁能修的。
- async 一族要的是真正的状态机（VM 目前「async 函数同步执行到完成」，
  `poll()` 永远返回 Ready），属结构性缺口。

### 第 323 轮：指针字段基址 / 嵌套结构体字段视图 / 标量解引用（libc 堆三例转绿）

承接第 322 轮，这轮把 libc 堆那一簇拆到底，**`test_libc_heap_bins`、
`test_libc_heap_coalescing_adjacent`、`test_libc_heap_realloc_in_place` 转绿**，
并修掉两个会让解释器直接报错的通用缺口。

三个根因（都能用最小复现单独复现）：

1. **以「指针类型的成员」为基址的存储写错了地址。**
   `p.field.x = v` / `p.items[i] = v` / `&p.field.x` 以前把**指针槽的地址**当对象基址
   传给 VM；对原生结构体里的指针字段（libc 堆的 `chunk.next.prev = null`），这个
   地址恰好是那块内存本身，于是写入静默落到结构体内部 —— 既不报错也不生效。
   `chunk_free` 里 `chunk.next.prev = chunk.prev` 失效 → bin 链表留下悬挂项 →
   下一次 malloc 从 bin5 拿到一块已经被合并掉的 chunk → 8 次 carve 全失败。
   修法：新增 `exec_builder_compile_object_base_slot`，基址静态类型是 POINTER 时
   编译**指针值本身**，否则仍走取址路径（聚合对象必须原地写，不能写临时副本）。
   LOAD 路径本来就用指针值，这轮把 STORE / ADDR 路径对齐过来。
2. **原生结构体里的按值嵌套结构体字段读出来是 VOID。**
   `exec_vm_native_field_load` 没有 STRUCT/UNION/TUPLE 分支，`chunk.header.size`
   这种链式访问直接报 `LOAD_FIELD 字段越界(idx=0 kind=14 count=-1 pointee=16)`。
   现在返回指向字段内存的指针视图，下一跳仍按 C 偏移解析。
3. **`BC_STORE_INDEX` 缺少「引用指向标量」的解引用存储。**
   `p[0] = v`（p 是 `&usize` 形参）落到 `index_ref` 分支报 `STORE_INDEX 越界`
   （第 322 轮的 INDEX 基址改动之后暴露；`test_tls_x509` 因此回归，已随本轮修好）。
   补上后与 `LOAD_INDEX` 的 `*ref` 分支对称。

**仍未解决的一层（下一轮入口）**：`test_libc_heap_tcache`(44) 与
`test_std_stdlib_malloc`(9) 同一个根因 —— **`set_free(hdr, false)` 清不掉 FREE 标志位**。
（本轮末尾又加了一个直接探针 `export fn heap_debug_state_mask() usize { return CHUNK_STATE_MASK; }`：
VM 返回 **0**、C 返回 3；探针程序里 `__exec_global_init` 给 MASK 的槽位写的是
`const[7] = 4095`（另一份稍大的程序里写的是 2）—— **同一个 const 在 heap.uya 里每次
构建拿到的值是 0 / 2 / 4095 三种，全都不对**，而把这段 const 块原样抄进 /tmp 单文件
用例又完全正确。说明这是「大模块里 const 全局初始化表达式」的
降级期 HIR/AST 复用或计算缺陷，与 `1|2` 本身无关。探针已回滚，heap.uya 保持干净。）
打点确认：进入 `set_free` 时 `hdr.size=0x1001`、`free=false`，写回后仍是 `0x1001`
（C 侧变成 `0x1000`）。进一步打点发现 `hdr.size - (hdr.size & CHUNK_STATE_MASK)` 里
**`CHUNK_STATE_MASK` 在某些调用点求值成 2（应为 3）**：它在 heap.uya 里声明为
`CHUNK_FLAG_FREE | CHUNK_FLAG_TCACHE`（`1 | 2`）。同样的写法在 /tmp 的单文件用例里
求值正确（`M=3`），说明这是**跨模块/多全局时 exec 降级期常量折叠**的缺陷，
按调用点不同取值不同（有的点 3、有的点 2）。后果连锁：已分配的 chunk 一直带
FREE 位 → `free()` 里 `if is_free(hdr) { return; }` 直接静默丢弃 → p1/p2 从不合并
→ `malloc(3600)` 只能 mmap 新 region，断言地址相等就失败。

**本轮实测**：原 29 例失败清单剩 **20 例**（C 侧全部 rc=0）。相邻回归已逐一复测：
`test_tls_x509`、`test_std_io(_buffering)`、`test_stdio_file_buffering`、
`test_std_async_event(_fd_reuse)`、`test_protobuf_wire`、`test_protobuf_dynamic`、
`test_std_mem`、`test_math`、`test_struct_default`、`test_array_pointer_access` 全绿。

### 剩余缺口的三堵墙（截至第 399 轮）

49 个普查失败、52 个 parity 落后用例，根因全部收敛到三处；每一处都已在正文里
用实测证据钉死，不属于「再来几轮就能收口」：

1. **async 帧 / `@await` 的 poll 函数 + Waker**（约 40 例，最大一簇）
   `Future<T>` 是 interface，调用侧要对返回值做接口装箱，装箱需要知道 poll 方法的
   函数号；而 poll 是 **C99 侧 `c99_async_frame_helper_name` 合成的 `<fn>_poll`**，
   VM 的 builder 不生成它。`@frame` 的 `start`/`poll`/`stop` 在
   `src/exec/lower.uya:8845` 被整体降级成 void 空操作。
   另一半是 **Waker**：`exec_vm_await_poll_interface` 传给 poll 的 waker 是伪造的
   占位聚合（`EXEC_AWAIT_WAKER_FIELDS` 个 void 字段），poll 方法里
   `w.add_interest(...)` 一写 `_io_slot_fds[i]` 就 `LOAD_INDEX 越界`
   （`test_std_dns` / `test_async_fd` 就死在这）。
   证否/取证记录：第 393 轮（帧布局取证）、第 399 轮（Pending 传播方案证否）、
   第 400 轮（穿透修好 `test_async_await`，并暴露 waker 问题）。
   注意：第 400 轮的穿透只解决「内层本来就已经 Pending」的情况，解决不了
   「C99 会停在第一个 await、VM 却把整个函数体跑完」这一层（
   `pending_seen == 1` 那类断言），后者必须实现真正的状态机。

2. **drop / cleanup 语义**（约 8 例 + 悬垂引用 2 例）
   `pipeline_drop_count()` 在错误路径上应为 1 实际为 0（`test_typed_pipeline_*`）；
   `async_box_free_current` 从 box 头读出的 allocator 地址是 `-15`，说明释放了
   不是本分配器给出的指针（第 396 轮）。
   根因已定位到 `cleanup scope 嵌套过深`，但修复方案三次证否（第 343 轮）。

3. **宿主导回调 / 线程并发**（约 10 例）
   VM 没有 host→bytecode 的回调蹦床（`grep trampoline src/exec/vm.uya` 为空），
   所以 `signal()` 注册的 Uya 处理函数不会被调用（`test_signal` 的
   `signal_handler_count` 恒为 0）；pthread/fork/execve 同理。
   `test_async_compute_*` 把 `&double_i64 as &void` 这样的函数指针交给线程池，
   池子回头调用它 —— 同样需要回调蹦床（这 11 个子测试全 ERROR，rc=11）。

另有 5 例是**纯算法太慢**（`test_tls_x25519_pure` 等 >200s），属性能问题不是语义问题。

### T11 收口

- [ ] `uya test --vm` 全量通过（跳过表只保留 C99 侧同样不适用的用例）
      —— 现状 **859/907（94.7%）**（第 401 轮全量普查实测，失败 48、跳过 7；
      第 370 轮曾为 839/907，失败 68、跳过 7，逐例
      比对零新增回归）；第 345 轮曾测 841/909（92.5%，失败 67）。较第 320 轮的 832 例净增 9 例：第 344 轮泛型单态调用目标消歧、
      第 345/346 轮 `LOAD_INDEX` 旁路表回查与 `memcpy` 旁路表迁移。
      剩余缺口集中在 async 帧布局（约 40 例静默/`@await` 失败）、线程
      （pthread/堆/OSAL 约 10 例，同步 VM 无并发语义）、`@c_import`（3 例）、
      `cleanup scope 嵌套过深`（8 例，第 343 轮已定位根因但修复方案三次证否）
      与超长函数（`bytecode 指令超出上限`）；这些不是「再来几轮」能收口的量级。
- [ ] `make exec-parity` 全绿（最新第 401 轮实测 **914 例 / 一致 853 / 不一致 61**，
      按方向拆分见第 397 轮小节：VM 领先 9、VM 落后 51、两边都失败 1；
      第 363 轮曾为 835/79，比文档原先记录的 832/81 多 3 例一致；
      81 例的分类见下。与第 342 轮（832/81）逐项一致，说明第 344~346 轮的三处
      修复没有动摇差分口径 —— 但也没有收口，因为剩下的全是模型级缺口：
      async 帧布局与 `@await` 语义 40 例、线程/堆/OSAL 10 例、`@c_import` 3 例、
      超长函数 1 例、以及少量 `cleanup scope 嵌套过深`。
      libc 堆两例的共同根因已定位到「常量折叠把 `CHUNK_STATE_MASK` 算成 2」）
- [x] `make check` 全绿（1191 个测试，通过 1191，失败 0；第 309/314/317/320/345/348/390/398 轮复测均绿）
- [ ] 合并到 main 并删除工作区

### 第 342 轮：错误联合 error_id 借用、INDEX 基引用、裸指针还原判定收窄

本轮三处根因，全部在 `src/exec/` 值模型层，且都是「同一份语义在不同路径上实现不一致」。

**1. ok 错误联合的 `error_id` 被 aux 借用（`test_capability_runtime_compat` 11→0）**

`exec_make_error_union_ok` 把载荷的 aux 位（指针 pointee kind / 裸数组元素类型码 /
向量通道数）暂存进 `error_id`，`exec_value_unwrap_ok` 再还原。于是
`const r: !&byte = ...; r.error_id` 读到的是 `10`（BYTE 的 TypeKind），
被上层误判成 `error.Bad`。`exec_value_error_id` 增加 ok 判定：`i64_value == 0`
时一律返回 0。这是本轮最便宜的一处，却一次修掉 11 个断言。

**2. `BC_LOAD_INDEX` 缺 INDEX 基引用分支（`test_typed_pipeline_capability` 越界消失）**

`&arr[0]` 传参后形参是 INDEX 基引用，`p[i]` 走了「解引用 target」分支：
target 本身是 STRING，`exec_vm_load_pointer_index` 于是把首字符字节值当成元素返回，
`args[i]` 拿到 `'l'` 而不是 `"beta"`，`str_len(&[&const byte])` 一律越界。
新增分支按 ExecValue 步进取第 i 个元素。
（顺带：`LOAD_INDEX` 遇到 STRING 基值也补了显式分支，不再落进 `exec_value_count == 0`
的越界判定。）

**3. 裸指针还原成 ExecValue 本体：判据从「在竞技场里」收窄到「登记表命中」**

`651a148e` 为了修 `*entry = Entry{...}`（`@ptr_from_usize(&arr[i])` 丢掉内部引用编码）
加了「地址在 VM 居住区就整块读写 ExecValue」的快路径。判据太宽，三个坑同时踩：

- 竞技场里同时住着 ExecValue 数组和**裸字节缓冲**（源码文本、捕获缓冲）；
- `g_native_agg_values` 旁路表的**基址**本身就是 C 侧裸地址。

结果 `*p` 把缓冲字节当成 `kind/count` 解出来，fmt / json / yaml 三簇整片
`LOAD_FIELD 字段越界`（20 余例回归）。

修法：`src/exec/value.uya` 新增**聚合元素登记表**。`exec_value_make_aggregate`
分配 values 数组时登记（基址 + 跨度），`exec_vm_box_value_ref` 登记单个装箱值。
竞技场是 bump 分配、基址单调递增，所以按下标追加即天然有序，二分查找 O(log n)。
新判定 `exec_vm_address_is_exec_value_storage`：竞技场内部必须命中登记表且落在
元素边界；槽池 / 全局区按 ExecValue 步长对齐；独立装箱值查登记；明确排除
`g_native_agg_values`。LOAD / STORE 两侧都换用它。

**4. 指针算术的 VOID pointee 兜底（`test_dyn_table_growth` 转绿）**

`self.values + off`（`values` 是 `&byte` 字段）报 `指针算术不支持该元素类型`：
字段读取路径只带宽度、不带元素类型，pointee 被编码成 VOID，
`exec_vm_type_kind_size` 返回 0 就走错误分支。`LOAD_INDEX` / `STORE_INDEX`
早就有「VOID pointee 按 1 字节」的兜底，`exec_vm_pointer_add` 漏了。补上，
并把结果指针的 pointee 改写成 BYTE，避免后续再次退化。

**本轮实测**（全量普查，第 342 轮末）：失败 **79 例**（r340 基线 86 例）。
新转绿 20 例：`test_capability_runtime_compat`、`test_libc_heap_{bins,coalescing_adjacent,
realloc_in_place,tcache}`、`test_printf_f`、`test_protobuf_wire`、
`test_http_websocket_{reconnect,handshake,heartbeat}`、`test_https_websocket_loopback`、
`test_http_uyagin_recover_observe`、`test_std_io`、`test_std_io_buffering`、
`test_stdio_file_buffering`、`test_std_stdlib_malloc`、`test_std_async_event`、
`test_std_async_event_fd_reuse`、`test_typed_pipeline_cmd_argv`、`test_dyn_table_growth`。
fmt / json / yaml 三簇回到全绿。

**新出现的 13 例不是回归**：`test_abi_calling_convention` / `test_simple_cast` /
`test_pointer_cast` / `test_comprehensive_cast` / `test_exec_vm_c_import_unsupported`
在跳过表里（C99 侧本来就链不上），普查会过滤掉；其余
`test_{std_sql,std_jpeg_decode,std_jpeg_encode,https_debug,https_google,
https_production,https_real_site,crypto_bigint_modexp4096}` 已在
`1c05e2d9` 与 `76f611e5` 两个提交上逐一复现同样失败（`VM frame slot 超限` /
`空指针解引用` / 超时），确认是基线里就有的，只是 r340 那次普查它们偶然通过。

**剩余缺口仍是模型级**：async 帧布局（约 20 例，`@await` 同步降级的语义边界）、
线程（`pthread`/堆/OSAL 约 10 例，同步 VM 无并发语义）、`@c_import`（3 例）、
超长函数（`bytecode 指令超出上限`）、以及「内核/C 侧按 C 布局写进 VM 聚合槽」
（`test_signal` 的 `rt_sigaction`、`test_osal` 的 `execve`、`test_kernel_sim` 的
call gate 桩）。这些都需要给 VM 真正的聚合内存字节视图，不是补几个分支能收口的。

### 第 343 轮：defer 清理体自我重入（已定位，但修复方案被证否，不落地）

普查里 8 例报 `exec: cleanup scope 嵌套过深`（`test_async_multi_fd_concurrent`、
`test_async_runtime_shared_{dns,semantics}`、`test_async_shared_runtime_semantics`、
`test_async_scheduler_event_loop_ptr_compile` 等），根因已完整定位。

**最小复现**（`/tmp/t_c6.uya`）：

```uya
fn f() i32 {
    defer { while false { g = g + 1; } }   // defer 体里只要有 while 就炸
    return 0;
}
```

**根因**：`exec_builder_emit_cleanup_scope(ctx, scope_idx, ..)` 在**当前深度**上
发射清理体。若清理体里有 `while`，`builder` 会给它开新的 cleanup scope，
于是复用同一个槽位下标；循环体的 `break`（while 被降级成
`loop { if !cond { break } .. }`）又会调 `exec_builder_emit_all_cleanup`，
从当前深度往回遍历 —— 而被发射的这个 scope 自己还在遍历范围内，
于是它再发射一次自己的清理体 → 无限自我重入，深度涨到 1024 上限。
实测 `DBGDEF` 打印证明：`defer` 的 `cleanup_block` 指针等于外层 block 本身。

**试过的修法（都不成立，已全部 `git checkout` 回退）**：

1. 发射期间把 `ctx.cleanup_depth` 压到 `scope_idx`，并备份/还原槽位登记 ——
   `嵌套过深` 消失，但 `defer` 体里 `break` 的展开目标变成
   "0x.. <本 scope> + 2"，落进了合法跳转表，执行时跳进“外层 while 的循环体”
   导致 PC 倒退死循环。症状从编译期错误转成运行期挂起，更难排查。
2. 同上 + 加 `ctx.cleanup_floor` 下界（`break`/`continue`/`return` 只收
   清理体自己的内层块）—— 错误变成 `scope enter/exit 不匹配`
   （`sid=10 vs 6`），因为 `continue` 之后的 `SCOPE_EXIT` 是不可达代码，
   它对应的登记已被跳转前的发射消费掉。
3. 再把 `SCOPE_EXIT` 配对放宽成“向下找到本 scope_id”—— 该例仍然失败，
   且全量普查**新增 3 例回归**（`test_async_cleanup_body_coverage`、
   `test_async_defer_errdefer`、`test_http_websocket_handshake`），零修复。
   **净负收益，已回退。**

**结论**：`defer` 体与循环体的 cleanup scope 需要各自独立的槽位编号
（不是复用现有一个栈），这属于 `builder` 的 scope 分配模型改动，
和 async 帧布局同量级。在拿到能同时保证「清理体 break 目标正确」与
「SCOPE_EXIT 配对」的方案前不要动 `exec_builder_emit_cleanup_scope`。

**本轮实测**：回退后全量普查失败 **79 例**（与本轮开头一致，无回归）。
`make check` 1191/1191 通过。

### 第 344 轮：泛型单态副本的调用目标消歧（`test_json_from_json_reflect` 转绿）

**症状**：`@size_of(v)` 在两个不同的泛型实例里返回同一个值，且「谁先被调用谁的值赢」。

**最小复现**：

```uya
fn dump<T>(v: T) i64 { return @size_of(v) as i64; }
// A2 = 16 字节，B4 = 32 字节
printf("ra=%ld rb=%ld", dump<A2>(a), dump<B4>(b));   // VM 16/16，C99 16/32
// 调用顺序反过来 → VM 32/32，C99 32/16
```

**根因**：`exec_lower_generic_instances` 为每个单态实例都**复用同一个
`fn_decl` 指针**降级，只改 `lowered.name`（`dump$m0` / `dump$m1`）。
而 `exec_builder_find_function_index` 第一轮只比声明指针，于是同一泛型的
所有调用全部命中模块里的第一个实例。`test_json_from_json_reflect` 里
`to_json<User>` / `to_json<Record>` / `to_json<Rect>` / `to_json<WithArray>`
串成同一条链，`LOAD_FIELD idx=2` 于是按 `User`（2 字段）去访问 4 字段的结构体，
报 `LOAD_FIELD 字段越界(idx=2 kind=16 count=2)`。

**修法**：`exec_builder_find_function_index` 改三轮匹配 ——
① 声明指针**且**名字都相同（覆盖「同一声明多个单态副本」）；
② 只按声明（非泛型方法，声明唯一）；③ 只按名字（宏展开等拿不到声明的场景）。
后两轮语义保持不变。

**本轮实测**：`test_json_from_json_reflect` 由 rc=1 转 rc=0，json 簇
（`test_json_roundtrip` / `test_json_struct_roundtrip` / `test_json_to_json_reflect`
/ `test_json_nested` / `test_json_slice` / `test_yaml_*`）全部保持绿。
全量普查失败 **79 → 78**，逐例比对无新增回归。`make check` 1191/1191。

**顺带记录（同一轮排查但未修）**：`test_typed_pipeline_capability` /
`test_typed_pipeline_executor_single` 的剩余阻塞在 `try_tcache_free_fast` →
`current_thread_heap_cache()`。VM 不支持 `@asm`，`_pthread_fast_heap_cache()`
读 `gs:8` 恒得 0，于是回落到 `&_pthread_main_desc.heap_cache`；该地址是
`ADDR_GLOBAL + ADDR_FIELD` 算出的**原生偏移**（4368 = 21×208），
`exec_vm_field_object` 的裸指针分支对「聚合内部字段地址」还认不出来，
最终报 `LOAD_FIELD 字段越界(idx=1 kind=14 pointee=16)`。
这和第 323 轮的「嵌套结构体字段视图」是同一族问题，需要把
「聚合元素地址 → ExecValue 槽」的映射做成通用能力。

### 第 345 轮：`Vec<结构体>` 读回恒零（LOAD_INDEX 只认原生缓冲区）

**症状**：`Vec<SomeStruct>` 的 `push` / `get` 往返后字段全是零值，C99 侧正确。

**最小复现**：

```uya
struct Pair { a: i64, b: i64 }
var v: Vec<Pair> = vec_new<Pair>(get_allocator());
v.push(Pair{ a: 11, b: 22 });
v.push(Pair{ a: 33, b: 44 });
const p0: Pair = v.get(0);   // VM: 0,0    C99: 11,22
```

**根因**：`Vec<T>` 的 `data` 是 `&T`（原生指针）。`push` 走
`STORE_INDEX(base, idx, value)`，元素是 VM 聚合，`exec_vm_store_pointer_index`
的 `elem_size == 0` 分支把它写进 `g_native_agg_values` 旁路表 —— 原生缓冲区上
一个字节都没动。而 `get` 走 `LOAD_INDEX`，`exec_vm_load_pointer_index` 的同一
分支只要 `elem_size_hint > 0` 就直接返回「指向原生缓冲区」的指针，读到的是
从未被写过的原始字节。

**修法**：读侧在返回裸指针之前先查旁路表（新增 `exec_vm_native_agg_peek`，
**只查不建表**，避免「读一个空槽也把表撑大」），命中则取旁路槽位。
`exec_vm_pointer_element_ptr` 与 `exec_vm_load_pointer_index` 两处都已覆盖。

**实测转绿**：`test_std_env`（`EnvBlockBuilder.ops` 是 `Vec<EnvOverlayOp>`，
前 3 个用例原本全 ERROR）、`test_dyn_table_growth` 保持绿，
`test_json_from_json_reflect` 保持绿。

### 第 346 轮：`memcpy` 扩容原生聚合数组时旁路表留在旧基址

**接续第 345 轮**：`pipeline_registry_append_last_stage_env` 用
`malloc 新块 → memcpy 旧块 → free 旧块` 扩容 `&PipelineEnvOp` 数组。
只搬字节时目标基址的旁路表是空的，`env_ops[0].remove` 于是 `LOAD_FIELD 字段越界`。

**修法**：新增 `exec_vm_native_agg_migrate(dst, src)`，由宿主
`EXEC_HOST_CALL_MEMCPY` 分支在字节搬运之后调用，把源基址登记的元素 clone 到
目标基址。元素级拷贝（`while i < n { dst[i] = src[i] }`）本来就正确，不受影响。

**但这条只解决了「命中的是宿 memcpy」的情形**。`lib/libc/mem.uya` 的
`memcpy` 是**带 Uya 体**的 `extern "libc"`，`process.uya` 自己的
`extern fn memcpy` 声明引用到的也是它 —— 实际执行的是逐字节循环，根本走不到
宿主分支。`test_typed_pipeline_capability` 前两个用例（`pipeline_capability_
generation_registry` / `pipeline_stage_count_empty_is_read_only`）因此转绿，
后面仍卡在 `EnvBlockBuilder` → `pthread_current_heap_cache` 的堆路径。

**尝试过但放弃**：在 `exec_lower_extern_prefers_host_call` 里把
`memcpy`/`memmove`/`memset` 一律改走宿主实现。`test_typed_pipeline_capability`
前 3 个用例能过，但 `test_dyn_table_growth` 立刻回归
（`hash table` 的 rehash 用 `memcpy` 搬 `&Payload` 片段，宿主实现按
`mem_ptr + n` 逐字节写，把 VM 聚合的旁路表基址算错）。
只路由 `memcpy`/`memmove`、把 `memset` 留在 Uya 体里同样回归。
结论：在「旁路表基址」与「原生字节地址」还没统一之前，不能整体改路由口径。
`git checkout -- src/exec/lower.uya` 已回退，回归确认消失。

### 第 347 轮：`defer { ... break ... }` 的 cleanup 重入（第 4 次证否，护栏方案作废）

第 343 轮已定位根因：`lib/std/async_scheduler.uya:1155` 的 `defer { while ... }`
里那个 `break` 会调用 `exec_builder_emit_all_cleanup`，把「正在发射的这个
cleanup scope」再发一遍，自我递归直到 `cleanup scope 嵌套过深`。

本轮尝试的**第 4 个方案**：在 `ExecFunctionBuildContext` 加
`emitting_cleanup_scope_plus1`，`exec_builder_emit_cleanup_scope` 进入时记录
当前下标、退出时恢复；`exec_builder_emit_all_cleanup` 跳过该下标。

两种跳过口径都试了：

1. **跳过「正在发射的 scope 及更内层」**（`scope_idx < stop_at` 才发）：
   `test_std_async_scheduler` 前 14 个用例从「整个文件编译失败」变成**通过**
   ——说明护栏确实切断了递归；但第 15 个用例
   `scheduler_run_task_queue_i32_with_shared_event_loop` 变成**运行期死循环**
   （`scheduler_run_task_queue_with_event_loop$m46` 在 `ip=22..345` 之间空转
   2490 万次）。原因是被跳过的内层 scope 里有本轮循环必须执行的状态推进。
2. **只跳过「正在发射的那一个 scope」**（`scope_idx == emit_scope_idx` 时
   `continue`）：`test_async_multi_fd_concurrent` 直接死循环，比方案 1 更糟。

**结论**：`emit_all_cleanup` 需要「跳到哪个 scope 为止」的信息，而单靠
`emitting_cleanup_scope_plus1` 一个下标表达不了 —— `break` 要发的是**外层
loop scope**，不是「所有比当前深的 scope」。真正的修法是给 `ExecLoopPatch`
记录 `cleanup_depth_at_entry`，`break`/`continue` 只发到那个深度为止。

**第 5 次尝试（成功，提交 `c14d8d1e`）**：按上面的结论做了结构性改动。

- `ExecLoopPatch` 新增 `cleanup_depth_at_entry`，在 `HIR_STMT_LOOP` 里用
  `ctx.cleanup_depth` 初始化。
- 新增 `exec_builder_emit_cleanup_down_to(ctx, stop_depth, include_errdefer)`：
  从 `cleanup_depth - 1` 倒着发到 `stop_depth` 为止；floor 会被
  `emitting_cleanup_scope_plus1` 抬高到「正在发射的那个 scope」，避免把栈上的
  body 再发一遍。
- `HIR_STMT_BREAK` / `HIR_STMT_CONTINUE` 改用它，`stop_depth` 取
  `loop_patch.cleanup_depth_at_entry`。

**实测**：`test_std_async_scheduler` 从「整个文件编译失败」→ **前 14 个用例通过**；
`test_async_scheduler_event_loop_ptr_compile` **转绿**；`make check` 1191/1191 全绿。

剩余 4 个 async 用例（`test_async_multi_fd_concurrent`、`test_async_runtime_shared_dns`、
`test_std_dns_async_transport`、`test_async_shared_runtime_semantics`）现在**编译通过**，
运行期卡在 `EventLoop.poll()` → `sys_epoll_wait`。`@syscall` 在 VM 里是「无副作用 +
返回零值」的桩（实测 `/tmp/t_ep.uya` 得到 `-999`），所以 poll 永远返回 0，
`while completed < queue.len` 永不退出。这是同步 VM 没有真实 IO 就绪的模型级缺口，
不是 cleanup 的问题 —— 修它要让 VM 的 `epoll_wait` 真的等到事件或超时。

### 第 348 轮：`TaskQueue.slots[i]` 元素步长退化成 0 的完整根因链（未修，诊断结论）

第 347 轮的 cleanup 修法让 `test_std_async_scheduler` 能编译了，但运行期仍不结束。
逐层拆下去，根因不在 cleanup，而在 `ADDR_INDEX` 拿到的元素字节数是 0。

**症状**：`lib/std/async_scheduler.uya:1145` 的调度循环里
`const slot: &TaskQueueSlot<T> = &queue.slots[i as usize];` 之后的
`slot.active` / `slot.future.poll(...)` 读到的永远是零值 —— `active` 判据失败，
循环跳过了本轮的 future poll，而 `loop.poll()` 又被 mock 实现正常返回，
于是 `while completed < queue.len` 永远不退出（100% CPU 空转）。

**逐层证据**（每层都用 `fprintf(libc.stderr, ...)` 打点确认过）：

1. `BC_ADDR_INDEX` 的 `imm` 编码是「低 32 位 pointee kind | 高 32 位元素字节数」。
   实测该指令的 `imm=16` → `pointee_kind=16`、**元素字节数=0**。
   元素字节数来自 `exec_lower_expr_inner` 里
   `hir_index.int_value = exec_lower_size_align_of_type(ctx, copy_type(&expr_type), 1)`，
   即 `expr_type` 的 `@size_of`。
2. `exec_lower_size_align_of_type` 返回 **-1**。诊断显示
   `kind=16(STRUCT) sname=TaskQueueSlot targs=1`。
3. 它的泛型分支进入后设了 subst（`subst_active=1`、`subst_name=T`、`subst_type=实参`），
   但 `subst_type.kind` 打印出来是 **28 = TYPE_GENERIC_PARAM**，也就是实参自己还是 `T`。
   根因：`target_type.struct_type_args[0]` 是 `T` 而不是 `i32` —— 这个类型从未被单态化。
4. 再往上一层：`saved_active=0`，说明进入 `exec_lower_size_align_of_type` 时
   **外层根本没有生效的替换上下文**。`@size_of(q.slots[0])` 的 `expr_type` 是
   `checker_infer_type` 直接给的「声明形态」，单态化信息在这一支里完全丢失。
5. 继续往下，`compute_struct_size_v2` 对 `TaskQueueSlot<T>` 的 `result: T` 字段
   （`TypeKind.TYPE_GENERIC_PARAM`）返回 -1；`get_type_size_bytes_v2` 原先连
   `TYPE_INTERFACE`（`future: Future<!T>`，固定 16 字节）都没处理。

**尝试过的修法（全部回退，无一带来可验证的改善）**：

- 给 `get_type_size_bytes_v2` / `get_type_align_bytes_v2` 加
  `TYPE_GENERIC_PARAM` 分支按 `checker.subst_*` 替换 → 无效，因为第 4 层证明
  `subst_active=0`，压根没有可替换的上下文。
- 给 `get_type_size_bytes_v2` 加 `TYPE_INTERFACE = 16` → 正确但**不充分**，
  单独加完 `TaskQueueSlot` 仍然算不出尺寸（卡在 `result: T`）。
- 给 `compute_struct_size_v2` 的泛型分支加 `type_layout_push_subst` +
  `compute_struct_size_v2` 直接调用 → 无效，`struct_type_args[0]` 仍是 `T`。
- 让 `checker_eval_const_expr` 的 `@size_of` 分支回退到 v2 → 无效（同上）。
- 在 `exec_lower_expr_type` 里对 `AST_ARRAY_ACCESS` 从基表达式反推元素类型 →
  无效，`q.slots` 的类型本身也带未替换的实参。

**净结论**：这不是「补一个 `TYPE_INTERFACE` 分支」能解决的问题，而是
**`exec` 后端的表达式类型推断缺少单态化上下文**——`@size_of(<表达式>)`
在单态化体里拿到的是未替换的声明形态。修它需要在 `exec_lower_expr_type` /
`exec_lower_size_align_of_type` 这一层引入「当前单态化实参表」，让
`type_from_ast(T)` 能查到具体类型，属于结构性改动。

代码已全部 `git checkout` 回退（`git status` 干净），确认无回归：
`test_mem` / `test_std_string` / `test_dyn_table_growth` / `test_std_env` /
`test_json_from_json_reflect` 均 rc=0。

### 第 349 轮：`memcpy` 补两条缺失组合，`test_tflm_interpreter` 转入正常执行

`lib/tflm/kernels/kernels.uya:29-39` 的 `load_f32` / `store_f32` 写法是

```
memcpy(&f as &void, &(p[off]) as &const void, 4 as usize);
```

在 VM 里一律报「内存函数目标是 VM 值，无法按字节写」。原因是宿主 `memcpy`
分支只处理了两条组合：**两端都是 VM 值**（整体替换或位转换）、**`memset` 零填**；
漏了「目标是 VM 值本体、源是原生字节」这一条，而这正是从缓冲区读标量的标准写法。

补上两条路径（`src/exec/vm.uya`）：

- `exec_vm_scalar_from_bytes`：目标 kind 是标量时，按小端从源字节拼出位模式，
  再按 kind 组装（F32/F64 走 `exec_make_f32_bits`/`exec_make_f64_bits`，
  BOOL 判零，整数直接放 `i64_value` 并改 kind）。
- `exec_vm_copy_value_bits`：两端都被判成单元素 VM 视图时按字节搬位，
  目标宽于源补零、窄于源截断。

顺带补了 `exec_vm_scalar_width_bytes` / `exec_vm_kind_is_signed_int` /
`exec_vm_scalar_byte_at` 三个小工具。

**效果**：`test_tflm_interpreter` 从「运行时错误」变成正常跑完（返回码 5 是数值
断言差异，C99 侧本来是 `undefined reference to exp` 的链接错误，两边都还没通过，
但 VM 侧不再卡在 memcpy）。

**门禁**（第 348/349 轮实测）：

- `make check`：1191 个测试，通过 1191，失败 0。
- `make exec-parity`：914 例 / 一致 832 / 不一致 81，与第 345 轮完全一致，无回归。

**本轮另外查清但未修的三处**（都属同一类「类型信息没建出来」，不是 memcpy 问题）：

- `test_signal`：`lib/libc/signal.uya:205` 的 `signal` 是 `extern "libc"` **带函数体**，
  VM 里 `action.sa_handler` 的 `LOAD_FIELD` 报 `kind=0 count=-1 pointee=-1`
  —— 局部 `sigaction` 的类型字段表是空的。单独写 `sigaction{...}` 字面量是正常的，
  说明问题出在 `extern` 带体这条 lowering 路径上。
- `test_tls_handshake`：`ADDR_FIELD` 的 `c` 里 pointee kind 解出 **83**（非法值），
  同一类类型结构破损。
- `test_libc_stdio_new`：`sscanf` 是变参宿主调用，VM 不支持变参，属模型级限制。

### 第 350 轮：`test_signal` 从「运行时崩溃」转为「语义差异」；parity 超时口径说明

**两处修复**（`src/exec/vm.uya`，提交 `ff30dafb`）：

1. `exec_vm_syscall_shield_vm_addresses` —— 内核按自己认得的布局读写用户内存，
   而 VM 槽位里放的是 `ExecValue`。`rt_sigaction` 的 `&old_action` 直接就是
   `slots[5]` 的地址，内核写 32 字节就把 `ExecValue` 的头（`kind`）覆盖成垃圾，
   之后所有 `LOAD_FIELD` 都报 `字段越界(idx=0 kind=0 count=-1 pointee=-1)`。
   现在 `out_mask` 标记过的出参结构体一律换成原生缓冲区：调 syscall 前把现有
   字段值填进去，调完由 `exec_vm_syscall_marshal_out_struct` 回填。
   配套补 `exec_vm_realign_to_slot`：lowering 生成的 `&slot` 经 `CAST` 到
   `&const void` 偶尔带 8 字节偏移（实测 `&old_action` 是 `slots[5] + 8`）。

2. `exec_vm_is_signal_syscall` —— VM 没有真实线程/信号语义，真把 `rt_sigaction`
   交给宿主会给**解释器进程自己**装上信号处理器，后续 `raise`/`kill` 直接把
   解释器打死（返回码 138，实测 SIGUSR1）。按 `pthread_*` 的既有方式一律返回
   「调用成功、什么都没发生」。桩必须放在 `arg_count` 分支**之前**：
   `tgkill`/`kill` 是 3 参数，会先命中 `arg_count == 3` 直接真发信号。

**结果**：`test_signal` 从 rc=1（运行时崩溃）变成 rc=2 —— 4 个测试通过、
2 个失败（`signal_handler_is_invoked` / `sigprocmask_blocks_delivery` 依赖
真实信号送达，VM 里没有，属预期语义差异）。

**关于 `make exec-parity` 的 93/81 差异（不是回归）**：

第 350 轮测得 914 例 / 一致 821 / 不一致 93，比第 345 轮的 81 多 12 个。
逐个核对后确认全部是**超时口径**问题，不是功能回归：

- `test_crypto_bigint_modexp4096`、`test_crypto_bigint`、`test_epoll_server`、
  以及若干 `test_async_*` 在 parity 的 `UYA_PARITY_TIMEOUT`（默认 180s、本轮
  降到 120s）下超时。单独跑 `test_crypto_bigint_modexp4096` 实测**耗时 398 秒、
  返回码 0**，是纯计算型用例本身的耗时问题。第 345 轮用默认 300s 超时才没过。
- `test_mem` 的 **C99 侧**稳定 rc=139（段错误），与 exec 后端无关；清空
  `src/exec/*` 改动的基线同样 rc=139，确认既有问题。
- 其余 81 个与第 345 轮完全一致。

所以本轮的结论是：**功能无回归**，`make check` 1191/1191 全绿；parity 的
数字需要用 `UYA_PARITY_TIMEOUT=600 UYA_PARITY_JOBS=8` 才能与第 345 轮可比。

### 第 351 轮：性能专项（用户要求「先看看速度慢的性能问题」）

**方法**：`perf record` 在这个虚拟机上采不到样（PMU 不可用，`perf.data` 没有
samples），改用 `valgrind --tool=callgrind`（纯插桩、结果稳定）+ `perf stat`
（只能读 task-clock / page-faults / cycles / instructions 这类不需要采样的计数器）
+ `strace -c` + `gdb` 断点回溯。

**一、编译器自身的指令数：38.85 亿 → 8.63 亿（-77.8%）**

基线用 `uya run --vm /tmp/bench4.uya`（fib(22)）测，callgrind 显示 51% 的指令
花在 `memset` 上，全部来自「在栈上构造巨型结构体字面量」。四处、同一个模式：

| 位置 | 原因 | 处理 |
|---|---|---|
| `exec_lower_lower_global_init_exprs`（41%） | `ExecLowerContext` 819KB 栈帧（12 个 `[T: 1024]` 大数组）写在循环体内，每个全局变量清一遍 | 提到循环外，循环内只重置 `function_decl` 与运行态计数 |
| `exec_builder_build_function`（21.8%） | `ExecFunctionBuildContext` 3.4MB 栈帧（`instrs` 1.2MB、`cleanup_scopes` 1.6MB、`loop_stack` 1.0MB），每个函数 build 清一遍 | 三个数组改成按需从 arena 分配，栈帧降到 648 字节 |
| `symbol_table_insert`（18.7%） | 去重走完整 `symbol_table_lookup`（遍历所有作用域的所有符号）只为比一个 `scope_level`，每次 insert 平均 1.1 万次 `str_equals` | 只扫当前作用域的链表（外层同名本来合法） |
| `exec_lower_function`（6.4%） | 同上，三个 `[Type: 1024]` 数组（600KB） | 改 `&Type` + `exec_lower_type_slot` 惰性分配，栈帧 819KB → 132KB |

另外两处 O(n²)：

- `exec_lower_collect_file_globals` 的两个调用点都套在「遍历每个可达函数」的
  循环里，每次都全 AST 扫描并按 filename 过滤 → 加按文件名去重（`..._once`）。
- `append_module_export` 每加一条导出就重分配 + 复制整块 → `ModuleInfo` 加
  `export_capacity`，按 8 起翻倍。

**二、`stat` 系统调用：99,554 → 6,490 次（-93.5%）**

`perf stat` 显示 `uya check src/main.uya` 有 33% 的时间在内核态、IPC 只有 1.00。
`strace -c` 定位到 `stat` 被调用 9.95 万次（0.33s），`gdb` 回溯到 `paths_equal`：
它在字符串不等时无条件做两次 `stat` 比 inode，而这个函数在依赖收集的 O(n²)
去重循环里被反复调用。改成先比「最后一段文件名」快速排除，剩下的才 `stat`
（macOS 大小写不敏感卷的那个用途保留）。syscall 总时间 1.49s → 1.00s。

**三、结论与后续**

- `uya check src/main.uya`：5.95-6.25s → 5.70s（约 -5%）。
- 剩余时间的大头不在指令数：`strace -c` 显示 `fork` 8 次 + `wait4` 11 次占
  92% 的 syscall 时间（并行编译分片），加上 IPC 长期在 1.03 左右（内存受限）。
  想再明显提速要动并行编译的进程模型，风险高、本轮未做。
- 纯计算型的 VM 用例（如 `test_tls_x25519_pure` 607s）几乎不受影响 —— 它们的
  时间全花在 VM 解释执行本身，不是编译阶段。

### 第 352 轮：槽位池改为动态增长，修掉帧重叠

**发现过程**：`test_std_sql` 报 `VM frame slot 超限`。诊断显示
`top=8186 need=10`，报错点落在一个只占 10 个槽的 `sql_bytes_view_from_ptr`
上 —— 明显不是那个函数自己的问题。

扩大池容量后暴露真正的 bug：`LOAD_SLICE_PTR 目标不是 slice`。继续诊断，
发现**同一个 `fake_column` 帧**里，参数刚拷进去时 `kind=18`（切片），
一次内层调用回来再读就变成 `kind=1`（整数）；而且该帧的 `frame.slots`
地址与 `g_exec_vm_slot_top` 对不上（`slots` 指向 `pool[31]`，`top` 却是 8244）。

**根因**：`EXEC_MAX_FRAME_SLOTS`（8192，单函数的槽位上限）被当成**池**容量
抄到了四个地方，凡是 `base >= 8192` 的调用帧处理全错：

| 位置 | 错误后果 |
|---|---|
| `exec_vm_slot_pool_base` | 返回 null，`run_frame` 退回 `&pool[0]`，整帧与别的帧**重叠** |
| `exec_vm_slot_pool_pop` | pop 静默失效，`top` 只增不减 |
| `exec_vm_realign_to_slot` | 池地址区间算小一半，落在高位的槽认不出来 |
| `exec_vm_address_is_vm_resident` / `exec_value_address_is_exec_value_storage` | 同上 |

**修法**：池改成动态增长。

- `g_exec_vm_slot_pool` 变成 `&ExecValue` + `g_exec_vm_slot_pool_capacity`，
  `exec_vm_slot_pool_reserve` 按需翻倍（初始 8192，上限 `1 << 24`）。
- 扩容**只在 `top == 0`**（没有活跃帧）时进行：`ExecFrame.slots` 是指向池内的
  裸指针，搬移会让栈上所有 frame 悬挂。调用结束 `top` 归零，下次进入前再扩。
- 新增 `exec_vm_slot_pool_range` 统一算区间，四处判界全部改用它。
- `exec_vm_run_frame` 拿不到自己槽段时**直接报错**，不再退回 `pool[0]` ——
  那个回退正是帧重叠的直接原因。

**结果**：`test_std_sql` 从「运行时崩溃」变成**正常跑完**，剩 2 个断言差异
（`last_insert_id` 期望 101 实得 0，C99 侧通过；是 `DB`→`Driver` 双层接口
转发里结构体返回值丢失，另案）。`make check` 1191/1191 全绿。

### 第 353 轮：`&interface_field` 的 `*ref = v` 写回原位（test_std_sql 转绿）

接第 352 轮，`test_std_sql` 从「正常跑完」进一步暴露 2 个断言差异：
`last_insert_id` 期望 101 实得 0（C99 侧通过）。

**根因**：`exec_vm_index_ref` 里「引用指向值本体时下标 0 就是该值」这个分支
只认 `TYPE_STRUCT` / `TYPE_TUPLE`：

```
if is_index_base == 0 && index_value == 0 && target_aggregate != null &&
    (ref_kind == TYPE_STRUCT || ref_kind == TYPE_TUPLE) {
    return target;
}
```

但**接口在 VM 里同样是以聚合形式承载**（方法入口表 + 数据）。
`&h.sh`（`sh: Shape`）产生的 `ref_kind` 是 `15 (TYPE_INTERFACE)`，落不到
这个分支，于是 `out[0] = impl` 写进了一个临时地址 —— 调用方完全看不到。

实测链路：`db_open` 里 `drv.open(dsn, len, &db.conn)` 本该把 `db.conn` 换成
真正的实现，写入丢失后它仍是 `ClosedConn{}`，后续 `db.exec(...)` 全部走
`ClosedConn.exec` 返回 `Result{ last_insert_id: 0 }`。

**修法**：分支条件补 `TYPE_INTERFACE` 与 `TYPE_UNION`。

最小复现（`&h.sh` 经 `out: &Shape` 写入）从 `after=0` 变成 `after=25`；
**`test_std_sql` 全部通过**（VM 1/1），`make check` 1191/1191 全绿。

**本节顺带确认的两个仍然存在的缺口**（诊断到位置，未修）：

- `test_typed_pipeline_capability`：`lib/std/process.uya:3660` 报
  `LOAD_FIELD 字段越界(idx=2 kind=0 count=-1 pointee=-1)` —— 前一条
  `LOAD_INDEX imm=24`（元素步长 24）产出的元素 kind 是 0（void），
  字段表整块缺失。与 `test_tls_handshake` 的 `ADDR_FIELD` pointee kind=83
  同属「类型结构没建出来」。

### 第 354 轮：census 口径核对（`UYA_EXEC_CENSUS_MEM_MB` 的影响）

**关键结论：`UYA_EXEC_CENSUS_MEM_MB` 默认的 `ulimit -v 1024` 会让大量
`test_async_*` 用例失败**，与本轮 exec 改动无关。

排查过程：

1. 池改动后第一次 census 得到 770/909（84.7%），比第 345 轮的 841（92.5%）
   少 71 个，看着像严重回归。
2. 把 `src/exec/vm.uya` **完全 stash 回第 352 轮之前**重跑 census，
   结果**同样是 770/909** —— 立刻排除了本轮改动。
3. 单独不限内存跑那些「失败」用例（`test_async_channel`、`test_async_bug_a_two_while` 等）
   全部 rc=0。
4. 用 `bash -c 'ulimit -v 1048576; ./bin/uya test ...'` 复现：进程能启动、
   第一个 test 通过，跑到第二个就没了下文。是 1GB 地址空间不够。
5. 改用 `UYA_EXEC_CENSUS_MEM_MB=0`（不限内存）重跑，得到 **828/909（91.1%）**。

**逐项对比**（基线 = 把 vm.uya stash 回旧状态 + `MEM_MB=1024` 的那次 census）：

- 本轮**新增失败：0 个**（`comm -13` 为空）。
- 基线那 139 个失败里有 58 个在不限内存时通过 —— 全是 `ulimit` 导致的。

**真正稳定的口径**：`UYA_EXEC_CENSUS_MEM_MB=0 UYA_EXEC_CENSUS_TIMEOUT=240
UYA_EXEC_CENSUS_JOBS=12`，结果 **828/909，81 个失败**。
其中 `https_*` / `http_*` / `epoll_server` 这类需要真实网络的用例在并行下
仍然会超时，属于环境限制。

**本轮真正修好的**：`test_std_sql`（第 352+353 轮：动态槽位池 + 接口字段
引用写回），`test_tflm_interpreter`（第 349 轮：memcpy 两条缺失组合），
`test_signal`（第 350 轮：syscall 参数护住 VM 槽地址 + 信号桩）。

### 第 355 轮：shield 顺序修正，5 个用例转绿

**根因**：第 350 轮加的 `exec_vm_syscall_shield_vm_addresses`（把落在 VM 槽池里
的 syscall 参数地址换成原生缓冲区）放在了 `exec_vm_syscall_marshal_out_struct`
**之前**。于是 `out_mask` 标记过的**出参**也被一并换成 scratch，marshal 拿到的
`raw_address` 已经是 scratch，`exec_vm_realign_to_slot` 认不出对应的 VM 槽位，
`prepare` 返回 null，回填永远不执行 —— 出参结构体保持初值。

典型表现：`sys_gettimeofday(&tv, null)` 返回 0，但 `tv.tv_sec` 一直是 0。

**修法**：shield 跳过 `out_mask` 标记的参数，出参完全交给 marshal
（它在 `prepare` 成功后自己会把那个参数换成原生缓冲区）。

**效果**（census 口径 `UYA_EXEC_CENSUS_MEM_MB=0 JOBS=12 TIMEOUT=240`）：

| | 之前 | 之后 |
|---|---|---|
| 通过 | 828 | **833** |
| 失败 | 81 | **76** |

新增失败 **0** 个，转绿 5 个：
`test_kernel_dispatch`、`test_std_path_module`、`test_syscall_dir`、
`test_syscall_time`、`test_tls_x509`。

`make check` 1191/1191 全绿。

### 第 356 轮：支持 `@embed` / `@embed_dir`（test_embed_builtin 转绿）

`test_embed_builtin` 在 VM 下报 `尚未支持的表达式节点(type=68/69)`
（`AST_EMBED` / `AST_EMBED_DIR`），C99 侧全绿。

**`@embed("path")`**：检查阶段已经把文件内容读进 `expr.embed_data`
（长度 `expr.embed_size`）。VM 里做成一块原生字节数组常量再包成
`&[const byte]` 切片。内容可能含 NUL，所以不能复用 `string_value` 那条
「NUL 结尾」的路径（`exec_make_string` 按 `strlen` 截断）—— 改用
`string_value` 存指针、`int_value` 存字节数、`bool_value` 作二进制标记，
builder 侧按长度原样 `memcpy`。

**`@embed_dir("dir")`**：检查阶段已经读好 `embed_dir_paths` /
`embed_dir_data` / `embed_dir_sizes` / `embed_dir_entry_count`。VM 里拼成
`{ path: &[const byte], data: &[const byte] }` 的结构体数组，再包成聚合切片。
这里必须用 `exec_make_slice`（聚合切片，按 ExecValue 步进）而不是
`exec_make_raw_slice`（只适用于定长标量数组）—— 用错了 `entry.path` 会立刻报
`LOAD_FIELD 字段越界(idx=0 kind=0 count=-1)`。

新增 `HIR_EXPR_EMBED_DIR`：路径与内容都在编译期就绪，builder 直接生成常量，
不需要运行时 IO。

`test_embed_builtin` 全部通过（4 个测试、84 条断言）；`make check`
1191/1191 全绿。

**本节顺带确认的下一个缺口**：`test_macro_mc_type_auto` 报
`exec: 无法解析结构体声明`。`@mc_type(T)` 由 `create_type_info_struct`
在宏展开阶段**合成**一个名为 `TypeInfo` 的 `AST_STRUCT_INIT`，但
`TypeInfo` 从来不是程序里真实存在的结构体声明（C99 后端在
`src/codegen/c99/main.uya:4984` 特判生成）。exec 侧需要在
`AST_STRUCT_INIT` 的 lowering 里对「找不到声明」的情形退回用
`struct_init_field_count` 内联构造，属下一个可做的点。

### 第 357 轮：`@embed` / `@mc_type` / `sscanf` / `%n` 四项支持，3 个用例转绿

**一、`@embed` / `@embed_dir`**（`test_embed_builtin` 转绿）

`AST_EMBED`（68）/ `AST_EMBED_DIR`（69）在 exec 里完全没有处理，报
`尚未支持的表达式节点`。

- `@embed("path")`：检查阶段已把内容读进 `expr.embed_data`（长度
  `expr.embed_size`）。VM 里做成原生字节数组常量再包成 `&[const byte]` 切片。
  内容可能含 NUL，所以不能复用 `exec_make_string`（按 `strlen` 截断），
  改用 `string_value` 存指针 + `int_value` 存字节数 + `bool_value` 作二进制标记。
- `@embed_dir("dir")`：检查阶段已读好 `embed_dir_paths` / `embed_dir_data` /
  `embed_dir_sizes` / `embed_dir_entry_count`。VM 里拼成
  `{ path: &[const byte], data: &[const byte] }` 的结构体数组再包成**聚合切片**
  （必须用 `exec_make_slice` 而不是 `exec_make_raw_slice`：后者只适用于定长
  标量数组，用错了 `entry.path` 会立刻报 `LOAD_FIELD 字段越界`）。
  新增 `HIR_EXPR_EMBED_DIR`：数据全在编译期就绪，builder 直接生成常量。

**二、合成结构体（`@mc_type` 的 `TypeInfo`）**（`test_macro_mc_type_auto` 转绿）

`TypeInfo` 没有真实声明 —— 字段表由宏展开阶段的 `create_type_info_struct`
合成（C99 后端在 `src/codegen/c99/main.uya:4984` 特判）。exec 侧两处失效：

- `AST_STRUCT_INIT` lowering 里 `find_struct_decl_from_program` 返回 null。
  改为：找不到声明但字面量自带字段值时，按 `struct_init_field_count` 内联构造
  （字段名与值本来就是固定顺序）。
- `exec_lower_struct_field_index` 找不到声明。改为：对 `TypeInfo` 用固定字段表
  回答下标（顺序与 `create_type_info_struct` 一致）。

**三、`sscanf` + 格式化 I/O 分支的不可达陷阱**（`test_libc_stdio_new` 转绿）

两处：

1. `exec_lower_match_host_call_impl` 里 `printf` / `fprintf` / `sprintf` /
   `snprintf` / `sscanf` 的分支写在 `if is_varargs == 0 { ... }` 块**之后**，
   而那个块以自己的 `return EXEC_HOST_CALL_NONE` 收尾。按名字查的入口
   `exec_lower_match_host_call_name` 传的就是 `is_varargs = 0`，于是这些分支
   **永远不可达** —— 全部落到 Uya 实现体的 `@va_start` 路径上报
   「无法解析被调用函数」。整体移到该块之前。
2. 新增 `EXEC_HOST_CALL_SSCANF_FIXED`：变参无法直接转发给宿主（要构造 C 的
   va_list），在 VM 里按格式串逐个解析、把结果写回调用方给的 VM 槽位。
   覆盖 `%d` / `%i` / `%u`（含 `*` 抑制）。
3. `exec_format_render` 支持 `%n`：不输出字符，把已写出的字节数写回实参指向
   的 VM 值（`%n` 的实参本身是 VM 指针 `&n`，直接改它所指的 ExecValue 即可）。

**census 结果**（`UYA_EXEC_CENSUS_MEM_MB=0 JOBS=12 TIMEOUT=240`）：

| | 本轮开始 | 本轮结束 |
|---|---|---|
| 通过 | 833 | **836** |
| 失败 | 76 | **73** |

新增失败 **0** 个。连同第 355 轮一起算，这几天转绿的用例共 9 个：
`test_std_sql`、`test_syscall_time`、`test_syscall_dir`、`test_kernel_dispatch`、
`test_std_path_module`、`test_tls_x509`、`test_embed_builtin`、
`test_libc_stdio_new`、`test_macro_mc_type_auto`。

### 第 358 轮：`@frame` 类失败的具体根因（查清，未修）

剩余 73 个失败里约 60 个与 `@frame` / `@async_fn` 相关。挑
`test_async_frame_align_pool` 拆到最底层，根因很明确：

`lib/std/async_frame.uya:511` 的
```
const header: &AsyncFrameAllocHeader = raw_ptr as &AsyncFrameAllocHeader;
header.storage_kind = storage_kind as i16;
```
在 VM 里报
`STORE_FIELD 字段越界(idx=0 kind=14 count=-1 pointee=16 aux=16 isref=0)`。

逐层诊断：

1. 字节码是 `STORE_FIELD a=12 b=11 c=0 imm=0` —— `imm == 0` 表示**没有任何
   原生布局信息**（field 下标、native 偏移、native kind 全是 0）。
2. `exec_vm_field_imm_kind(imm, 32) -| 1 = 0`，所以不走「按原生偏移写」那条
   分支，退回 VM 聚合路径；而 `slot_a` 是裸原生指针（`pointee=16` 但
   `count=-1`，即背后没有字段表），于是越界。
3. 往上追：`hir_field.binary_op`（承载 native kind）是 0，是因为
   `exec_lower_native_field_layout` 拿到的**结构体类型错了** ——
   诊断打印 `sname=Future lk=16 fi=0 off=0 nk=0`。`base_type` 被推断成
   `Future`，而这里应该是 `AsyncFrameAllocHeader`。
4. 再往上：`expr.member_access_object`（`raw_ptr as &AsyncFrameAllocHeader`）
   在 AST 里**已经不是 `AST_CAST_EXPR`**（诊断 `iscast=0 hastt=0`）——
   `@async_fn` 的变换把函数体重写过了，这条 cast-expression 被换成别的形态，
   于是「按 AST 目标类型解析 CAST」那条兜底（第 350 轮加的）也接不上。

**结论**：这不是「补一个字段布局分支」能解决的，而是 **`@async_fn` 变换后的
AST 里，成员访问的基类型丢失了原始 cast 目标** —— `Future` 是变换自己引入的
包装类型，被错误地当成了 `raw_ptr` 的类型。修它需要在 `@async_fn` /
`@frame` 的 AST 重写里保留 cast 目标（或给 exec lowering 一条「从
`AST_CAST_EXPR` 被替换后的等价节点取原文类型」的路径），属结构性改动。

同一族里 `test_async_frame_methods` 报 `LOAD_UNION_TAG 目标不是 union`、
`test_async_fd` 报 `@await 操作数不是 Future 或始终 Pending`（后者是测试
**故意** await 一个永远 Pending 的 future，而 VM 是同步执行到完成，无法表示
Pending —— 属设计差异）。

### 第 359 轮：原生结构体字段写入的尝试与回退（教训记录）

**动机**：`lib/std/async_frame.uya:511` 的
`const header: &AsyncFrameAllocHeader = raw_ptr as &AsyncFrameAllocHeader;`
之后的 `header.storage_kind = ...` 在 VM 里写不进去（最小复现：
`struct Hdr { a: i16, b: i16, c: u32 }` + `raw as &Hdr`，写完全读到 0）。

字节码里的 native 偏移（`c=0/2/4`）和字段 kind 都是对的，问题在
`exec_vm_field_native_base` 返回 0：它用宽松的
`exec_vm_address_is_vm_resident`，把「落在竞技场里」一律当成 VM 常驻，
而 `[byte: N]` 的数据区也住在那儿，于是原生缓冲被误判成 VM 值。

**改成严格版 `exec_vm_address_is_exec_value_storage` 后**：

- 好的一面：最小复现通了，`test_async_frame_align_pool`（4 测试 / 4235 断言）
  和 `test_async_frame_pool_dynamic_growth` 双双转绿 —— 这是 `@frame` 一族里
  第一个真正修掉的缺口。
- 坏的一面：census **从 836 掉到 824**，`test_fmt_*` 十来个用例集体失败
  （`LOAD_FIELD 字段越界(idx=0 kind=0 count=-1)`）。原因是那张
  **聚合元素登记表有上限**，fmt 一类大量分配数组的用例把表涨满，之后正常的
  `file.decls[i].xxx` 也判 false 而被打坏。
- 也试过「宽松判据 + 探针确认目标是有效聚合值」的组合版：`t_hdr` 仍通，
  但 fmt 依旧失败（那条路径拿到的地址其实在 mmap 大块上、`isstorage=0`，
  说明失败点不在这个判定上）。

**结论：已 revert（`f9949953`）**。`make check` 1191/1191、census 836/909
都回到改动前的状态。要真正修好这条，得先解决「聚合元素登记表会涨满」这个
前置问题（改成可增长的表，或换成更精确的区间判据），否则任何依赖它的严格
判定都会在大用例上翻车。

### 第 360 轮：聚合元素登记表动态化（前置改进，无回归）

第 359 轮回退时指出「严格判定依赖的聚合元素登记表会涨满」，本轮把它修掉：

`exec_value_register_array` 原来用的是一张固定 `65536` 条的静态表
（`g_exec_value_array_bases` / `g_exec_value_array_spans`）。大用例
（`test_fmt_*` 一类大量分配临时数组的）会把它涨满，之后新数组不再登记，
`exec_value_address_is_array_element` 对它们全部返回 false —— 任何依赖
「这个地址是不是 VM 聚合元素」的严格判定都会在大用例上失灵。

改成和槽位池同样的模式：`&usize` + `g_exec_value_array_capacity`，
`exec_value_array_registry_reserve` 按需翻倍（初始 1024，上限 `1 << 22`
只作失控保护），扩容时把已有条目搬过去；二分查找的上界改读 capacity。

**验证**：`make check` 1191/1191 全绿；census 836/909（与第 362 轮一致，
**新增失败 0**）。

**仍未解决**：把 `exec_vm_field_native_base` 换成严格判定后，
`test_fmt_api` 依然报 `LOAD_FIELD 字段越界(idx=0 kind=0 count=-1)`（
`lib/std/fmt/simplify.uya:26` 的 `file.decls[i].fn_decl.body`）。
说明那条链上还有别的东西在依赖宽松判定 —— 登记表涨满只是**原因之一**，
不是全部。要继续这条线，得先把 `FmtFile.decls`（`&Decl`）的数据区究竟
落在哪里、有没有被 `exec_value_register_array` 登记过查清楚。

### 第 361 轮：fmt 链路的进一步定位（`decls` 本来就是原生数组）

接着第 360 轮的待办，把 `FmtFile.decls` 的数据区查清了：

```
// lib/std/fmt/parser.uya:314
var decls: &Decl = arena_alloc(arena, @size_of(Decl) as usize * (tokens.len + 1)) as &Decl;
...
file.decls = decls;
```

`decls` 是 **`arena_alloc` 出来的原生内存**，按 `@size_of(Decl) * count` 字节
分配、然后 `as &Decl`。也就是说 `file.decls[i]` 是**原生结构体数组元素**，
不是 ExecValue 数组 —— 所以 `exec_value_address_is_exec_value_storage` 对它
返回 false 是**正确的**，它本来就该走「按原生偏移读」那条路。

这条信息改变了第 359 轮的判断：`test_fmt_api` 在换成严格判定后失败，
**不是**因为「登记表涨满把正常 VM 数组判坏了」（那个已经由第 360 轮修掉），
而是 fmt 这条链上另有一段逻辑依赖宽松判定 —— `file`（`&FmtFile`）本身是
VM 值还是裸地址、`Decl` 是不是 union（`fn_decl` 的 native 布局怎么算），
这两点还没查完。

**当前状态**（本轮结束时）：

- `make check` 1191/1191 全绿
- census 836/909（92.0%），73 个失败
- 与第 362 轮相比**新增失败 0**，第 360 轮的登记表动态化是纯前置改进

### 第 362 轮：定位并修复 `%lld` 大整数被截断为 i32 的根因

第 361 轮把 fmt 链路的疑问留在 `decls` 的数据区上。本轮从另一条更基本的
线索切进去：VM 下 `printf("%lld", 481036337152)` 输出 `0`，而 `%d`
正常、值本身也正确（`low=0 hi=112`、`cmp-ok`）。

用不可常量折叠的运行期值（循环累加出 `base`，再 `base << 32`）复现后，
逐层排除字节码、槽位、`ExecValue` 类型与 `exec_format_render` 的 spec
构造，最终定位到 `lib/libc/stdio.uya` 的 `_vfprintf_impl`：

```uya
if length == 4 || length == 5 || length == 7 {   // %lld / %jd / %td
    const lld: i64 = @va_arg(ap, i64);
    if lld < 0 { ... 负值路径正常 ... }
    else { _fmt_i32_to_buf_full(&temp_ctx, lld as i32, flags, precision); }  // 截断
}
```

非负的 64 位实参被 `as i32` 截断后再格式化；481036337152 的低 32 位
正好是 0，于是输出 `0`。`%ld`（`length == 3`）分支以及后面重复的
`%ld` 分支同样如此。

修复：

- 新增 `_fmt_i64_to_buf_full`：按 `u64` 幅值生成数字，保留 `+`/空格
  flags 与 precision 语义；
- `%lld/%jd/%td`、`%ld` 的非负分支改用该函数，负值路径不变；
- 合并后面重复的 `%ld` 分支，消除同类截断。

这条路径是 exec VM 的格式化出口：`exec_format_snprintf_typed` 最终
调用 libc `snprintf`（即 Uya 实现的 `vsnprintf` → `_vfprintf_impl`），
因此 VM 侧所有大整数打印一并恢复；C99 后端的 `fprintf`/`snprintf`
同样受益。

验证（只跑相关测试）：

- `tests/test_exec_vm_stdio_no_varargs.uya`、`test_fmt_api*.uya` 共 5 个：
  `--vm` 与 C99 均为 `失败: 0`
- 复现用例：VM `%lld` 由 `0` 变为 `481036337152`，与 C99 一致

**当前状态**（本轮结束时）：

- 相关测试全绿（见上）
- census 需重新测量：本轮修复预计改善一批依赖大整数打印的断言

### 第 363 轮：接口 `.data` 成员访问的 lowering

`test_async_frame_pool_stats` 在
`tests/test_async_frame_pool_stats.uya:409:52` 报
`exec: 无法解析成员访问字段(kind=15): data`，`kind=15` 是 `TypeKind.TYPE_INTERFACE`。

接口在 exec VM 里以聚合承载：`HIR_EXPR_INTERFACE_BOX` 生成
`[方法表 0..n-1, 数据引用]`（见 `src/exec/builder.uya` 的装箱分支），
最后一项才是 `.data`。而成员访问 lowering 只认 TUPLE 与 STRUCT，
接口一律走 `exec_lower_struct_field_index` → 拿不到声明 → 失败。

修复：新增 `exec_lower_interface_data_field_index`，对
`field_name == "data"` 返回该接口的方法数（即数据引用所在下标），
成员访问在 `TYPE_INTERFACE` 时走它。原生偏移保持 0，运行时按聚合
下标读取。

验证：

- 原 lowering 错误消失，`test_async_frame_pool_stats` 前进到
  `lib/std/async_frame.uya:513` 的 `STORE_FIELD 字段越界(idx=0 kind=14
  count=-1 pointee=16)` —— 即第 359~361 轮记录的原生字段基址判定缺口，
  本轮不涉及；
- 回归面：`test_std_sql`、`test_fmt_api`、`test_fmt_api_phase3`、
  `test_exec_vm_stdio_no_varargs`、`test_std_io` 五例 `失败: 0`。

**当前状态**：census 仍为 836/909（本轮把一例的失败点从 lowering 前移到
运行时，未新增通过）；`make check` 与 parity 待本轮末尾复测。

### 第 363 轮收口实测

- `make check`：**1191/1191 通过，失败 0**（`/tmp/check_r363.log`，rc=0），
  含本轮 `%lld` 修复与接口 `.data` lowering 两处改动；
- `uya test --vm` 全量普查（`UYA_EXEC_CENSUS_MEM_MB=0 UYA_EXEC_CENSUS_JOBS=12
  UYA_EXEC_CENSUS_TIMEOUT=240`）：**836/909（92.0%）**，失败 73 例，
  与上一轮逐例比对**零新增、零修复**。按原因分布：超时 21、运行时断言 19、
  `@c_import` 3、`@await 操作数不是 Future 或始终 Pending` 5、
  `LOAD_UNION_TAG 目标不是 union` 2、`LOAD_FIELD 字段越界(kind=14 pointee=16)` 4、
  其余零散。
  注：T11 里记的 841/909 来自第 345 轮，两次普查的 `TIMEOUT` 预算不同，
  不宜直接相减比较。
- 剩余缺口已确认都是模型级：async 帧的原生/托管地址二义性（
  `exec_vm_field_native_base` 把指向全局区的原生结构体指针判成 VM 驻留，
  第 359~361 轮三次修法都被 `test_fmt_*` 回退证否）、`@await` 语义、
  线程/OSAL、`@c_import`、超长函数。

第 363 轮 `make exec-parity`（`UYA_PARITY_TIMEOUT=600 UYA_PARITY_JOBS=8`）实测：
914 例 / 一致 835 / 不一致 79 / stdout 差分 0，不一致全部是 `STATUS_MISMATCH`
（C99 通过、VM 失败 21 例，其中 4 例是 VM 侧 124 超时）。相对第 345/348 轮的
832/81 多 3 例一致：`%lld` 与接口 `.data` 两处修复各收口一部分格式/装箱用例。

### 第 364 轮：`libc_errno` 的解释器降级

`test_http1_async_client` 报
`exec: 当前仅支持局部变量/参数/全局标识符(libc_errno)`，
位置是 `lib/std/http/http1_async.uya:1614`。

`libc_errno` 不是 Uya 里的声明：C99 后端把它当成宿主 libc 的 `errno`
直接改名（`src/codegen/c99/global.uya` 的全局标识符改名分支），
所以 C99 侧能编过。解释器没有这块宿主存储，标识符查找落空。

修复：标识符 lowering 在落到「未知标识符」失败前，对
`libc_errno` 返回 i32 零常量 —— 与同一函数上面 `extern var` 的
「解释器无存储 → 零值」策略一致；用到它的代码都是「宿主调用刚失败、
看是不是 `EAGAIN`」的错误路径。

验证：该例前进到 `/lib/std/async.uya:1754` 的
`@await 操作数不是 Future 或始终 Pending`（下一节的模型级缺口）；
`test_exec_vm_stdio_no_varargs`、`test_std_sql` 仍 `失败: 0`。

### 第 364 轮普查：`libc_errno` 修复转绿一例

- `uya test --vm` 全量普查（`UYA_EXEC_CENSUS_MEM_MB=0 UYA_EXEC_CENSUS_JOBS=12
  UYA_EXEC_CENSUS_TIMEOUT=240`）：**837/909（92.1%）**，失败 **72**（上一轮 73）。
  逐例比对：新增回归 0；普查里 `test_async_nested_http1_await_codegen` 的
  结果由失败变成 rc=0，但这是**抖动**：直接复跑三次（带与不带
  `--no-strict-overflow` 各跑过）都稳定停在
  `@await 操作数不是 Future 或始终 Pending`。所以 `libc_errno` 修复只是把
  该例的失败点从 lowering 前移到运行时，**没有真正转绿**，本轮净变化为零。
- `test_http1_async_client` 仍不通过，但失败点从 lowering 前移到
  `@await 操作数不是 Future 或始终 Pending`（下一节的模型级缺口）。
- 顺带记录一条本轮新发现、尚未修的问题：`uya --dump-bytecode <file>` 走普通
  编译路径时，C99 后端对结构体字段名 `stdout`/`stderr` 与
  `#define stdout (&_stdout)` 冲突，生成
  `error: expected identifier before '(' token`。`uya test` 路径不受影响，
  但这是 C99 镜像宏与字段名互相干扰的隐患。

### 第 365 轮：普查跳过表补齐两个负向用例

`test_exec_vm_global_init_fail`（全局初始化除零）与
`test_exec_vm_extern_decl_varargs_unsupported`（断言 exec 必须拒绝未登记的
varargs extern ABI）都是**负向用例**：前者 C99 侧同样 `rc=1`，后者用例头注释
明确要求 VM 拒绝。上一轮把它们的非零退出当成 VM 缺口计数，属于普查口径虚高。

已按跳过表既有纪律登记（与 `test_exec_vm_c_import_unsupported` 同类），并在
文档里写明原因。

复测（`UYA_EXEC_CENSUS_MEM_MB=0 JOBS=12 TIMEOUT=240`）：
**907 个用例，通过 836，失败 71，跳过 7，通过率 92.2%**；与上一轮逐例比对，
新增失败 0，减少的 2 例正是本次登记的两个负向用例，
`test_async_nested_http1_await_codegen` 上一轮的 rc=0 确认是抖动（本轮稳定失败，
`@await` 模型级缺口）。

剩余 71 例的构成（与前几轮一致）：async 帧/`@await` 语义约 40 例、
线程与并发（pthread/OSAL/DNS）约 10 例、`@c_import` 3 例、
错误路径上的自动 drop（`pipeline_drop_count` 一类）若干、超长函数与 124 超时。
这些都要求 exec VM 具备真正的挂起/清理语义，不是局部修补能收口的。

### 第 366 轮：剩余 71 例的根因归类

普查口径：`907 例 / 通过 836 / 失败 71 / 跳过 7 / 92.2%`。按失败原因自动归类：

| 类别 | 例数 | 代表 | 为什么不是局部修补 |
|---|---|---|---|
| 无消息（断言失败或非零退出码） | 27 | `test_async_state_machine`(3)、`test_osal`(3)、`test_kernel_sim`(5)、`test_std_thread`(23)、websocket 系列(2~5) | 断言差异集中在 async 帧状态机、线程/OSAL、子进程 pipeline；VM 同步执行，没有真正的挂起/调度 |
| 超时(124) | 24 | `test_https_*`、`test_tls_*`、`test_pthread_*`、`test_http_server` | 依赖真实网络/线程并发，VM 单线程同步跑不完 |
| 原生内存/值模型 | 9 | `LOAD_FIELD 字段越界(kind=14 pointee=16)`、`LOAD_UNION_TAG 目标不是 union`、`ADDR_FIELD 字段越界` | 见下 |
| `@await`/Pending 语义 | 6 | `test_async_await`、`test_std_dns` | `pending_i32()` 这类「永远 Pending」的 Future 需要挂起语义 |
| `@c_import` | 3 | `test_c_import_file/dir/cflags` | 需要运行时加载 C 符号 |
| 其它（空指针解引用） | 2 | `test_std_jpeg_decode/encode` | 见下 |

本轮通过 `--dump-bytecode` / `--trace-vm` 拿到的四条硬证据：

1. **async 帧布局不存在**：`@frame(fn)` 的结构体由 C99 codegen 合成，AST 里没有声明，
   `src/exec/builder.uya` 的零值构造注释就写着「VM 侧按空结构体零值处理（布局未对齐，
   字段访问会照常报错）」。`test_async_frame_methods` 的 `LOAD_UNION_TAG 目标不是 union`
   就是这么来的 —— `frame.poll(&w)` 返回的值根本不是 VM 认得的 Poll 联合。
2. **原生地址无法反查聚合**：`test_tls_handshake` 在 `ssl_server_identity_ptr` 里把
   `&ctx.server_identities[0]` 用 `@ptr_from_usize` 变成裸指针再做偏移，之后
   `&ident.name[0]` 的 `BC_ADDR_FIELD` 拿到的是「指向 VM 聚合内部的裸地址」，
   `exec_vm_field_object` 既不能当 ExecValue 读、也没有原生槽位，只能报字段越界。
3. **错误路径上的自动 drop 不触发**：`test_typed_pipeline_lowering_error` 里
   `Pipeline.drop` 只在成功路径被调用，`pipeline_drop_count()` 在错误返回后仍是 0。
4. **子进程语义不存在**：`test_typed_pipeline_executor_single` 的 trace 显示
   `pipeline_child_write_startup` / `pipeline_child_fail_startup` 在 VM 里被**内联执行**，
   最后直接走到 `_exit` 的 `sys_exit` —— 整个 VM 进程退出，父子进程模型无从谈起。

结论：T11 剩下的三个未勾选项（`uya test --vm` 全量、`make exec-parity` 全绿、
合并到 main）都卡在上述四点上。它们不是「再来几轮修 bug」的量级，而是需要
exec VM 具备**真正的挂起/恢复、进程与线程、原生内存双向映射、运行期 C 符号加载**。
因此在当前设计下这几项无法收口；本文件保留现状与证据，供后续按模型级改造推进。

### 第 367 轮：async 返回裸 `error.X` 时漏包错误联合

`test_async_sync_body_matrix` 在 `const r: !i32 = block_on(async_cleanup_matrix(0));`
之后报 `LOAD_ERROR_TAG 目标不是错误联合`。用 `--trace-vm` + `--dump-bytecode`
一路跟到 `async_cleanup_matrix`：

- `@await flip_pending_i32(..)` 的返回值被塞进 `Poll.Ready(...)`，
- 但那个值是**裸 error**（运行时 kind=21，`i64=-489222378`），不是 `!i32`，
- 于是 `block_on` 原样返回裸 error，调用方拿它当错误联合用 → 报错。

根因在 `exec_lower_wrap_async_return`：它只处理了「返回裸 `T` → 补 `ok()`」，
**漏了「返回裸 `error.X` → 补错误分支」**。同时 `exec_lower_coerce_expr` 的
错误联合分支也只有 `MAKE_ERR` 一半、没有裸值 → `MAKE_OK` 的一半。

修复一处：`exec_lower_wrap_async_return` 里载荷类型是 `!T` 而返回表达式是
裸 `error.X` 时，包一层 `HIR_EXPR_MAKE_ERR`（错误 id 取自错误类型）。

同时验证过一个更宽的修法并**主动撤回**：在 `exec_lower_coerce_expr` 里对
「目标 `!T` + 裸 `T`」统一补 `MAKE_OK`。它确实让本例通过，但 `@async_fn`
声明返回 `!Future<T>` 时同一个值会被二次包装，导致 `test_async_return_value`、
`test_async_nested`、`test_async_nested_future_poll` 三例回归
（`LOAD_FIELD 字段越界(idx=0 kind=22 …)`）。撤回后四例全绿，说明这个
「隐式 ok 包装」不能放在通用 coercion 里，只能在真正的 `!T` 值位置补。

另外顺手修了 `--dump-bytecode` 把 `BC_AWAIT` 显示成 `BC_UNKNOWN(77)` 的问题
（`src/exec/debug.uya` 的名字表缺这一项）。

验证：`test_async_sync_body_matrix` **失败: 0**；`tests/test_*error*.uya` 共 26 例
（含 `test_async_error_*`、`test_exec_vm_*error_union*`、`test_return_error`）
在 `--vm` 下全部 `失败: 0`，唯一仍失败的 `test_typed_pipeline_lowering_error`
是本文件已记录的「错误路径自动 drop」缺口，与本轮改动无关。

### 第 368 轮：修复后的门禁复测

- `make check`：**1191/1191 通过，失败 0**（`/tmp/check_r368.log`，rc=0）。
- 普查（`UYA_EXEC_CENSUS_MEM_MB=0 JOBS=12 TIMEOUT=240`）：
  **907 例 / 通过 838 / 失败 69 / 跳过 7 / 92.4%**。较第 365 轮的 836/71
  净增 2 例，**零新增回归**。修好的两例：

  1. `test_async_sync_body_matrix` —— 本轮的「async 返回裸 error」修复；
  2. `test_async_nested_http1_await_codegen` —— 第 364 轮曾把它的 rc=0 记为抖动，
     现在确认根因就是同一个「裸 error 未包错误联合」，修复后稳定通过。
- `make exec-parity`（`UYA_PARITY_TIMEOUT=600 UYA_PARITY_JOBS=6`）：
  **914 例 / 一致 836 / 不一致 78 / stdout 差分 0**，比第 363 轮的 835/79
  多 1 例一致；不一致全部是 `STATUS_MISMATCH`，与普查里的 69 例同源。

### 第 369 轮：`&&T` 形参上的 `p[0] = v` 被当成穿透写

`test_std_jpeg_decode/encode` 都在 `lib/std/image/jpeg_marker.uya:481` 的
`body_out[0] = jpeg_sub(...)` 处报 `空指针解引用`（`body_out: &&const u8`）。

定位过程：`--trace-vm` 显示失败在 `BC_STORE_INDEX`；`--dump-bytecode` 看到
调用方传的是 `BC_ADDR_LOCAL(&body)`；在 `exec_vm_run_frame` 里打印实参，
确认 `arg4` 是正常的内部引用（`aux=65554`、地址非 0）。问题出在
`BC_STORE_INDEX` 的内部引用分支：它先判断「引用目标本身是个指针」就
**穿透写**（`exec_vm_store_pointer_index(base_target3[0], …)`），而 C 语义里
`body_out[0] = x` 等价于 `*body_out = x`，是**替换那个指针变量**。当
`*body_out` 恰好是 null（本例的 `body` 初值就是 null）时，穿透写就撞空指针。

修复：只有引用目标的指针地址非 0 时才穿透写；地址为 0 时落到后面的
「`*ref = v` 整槽替换」分支。这条改动只影响原本会报空指针的路径。

验证：`test_std_jpeg_decode`、`test_std_jpeg_encode` 均 `失败: 0`；
`test_std_mem`、`test_array_pointer_access`、`test_std_string`、`test_std_io`、
`test_struct_default` 仍 `失败: 0`。

普查（`UYA_EXEC_CENSUS_MEM_MB=0 JOBS=12 TIMEOUT=240`）：
**907 例 / 通过 839 / 失败 68 / 跳过 7 / 92.5%**。修好
`test_std_jpeg_decode`、`test_std_jpeg_encode` 两例；`test_async_nested_http1_await_codegen`
本轮又回到失败，但同一命令连跑三次得 1/0/1，属于依赖网络时序的抖动，
不计为本轮回归。`make check` 复测 **1191/1191 通过**（`/tmp/check_r369.log`）。
`make exec-parity`（`UYA_PARITY_TIMEOUT=600 UYA_PARITY_JOBS=6`）复测：
**914 例 / 一致 839 / 不一致 75 / stdout 差分 0**（第 368 轮为 836/78）。

### 第 370 轮：`atomic T` 字段的原生布局 kind

`test_async_event_dynamic_growth` 在 `lib/std/async.uya:250` 的
`self._wake_count` 处报 `LOAD_FIELD 字段越界(idx=0 kind=14 count=-1 pointee=16)`。
诊断显示：字段读走的原生路径是通的（`nk=25`、基址非 0、非 VM 驻留），
但 `nk=25` 对应 `TypeKind.TYPE_ATOMIC`，而 `exec_vm_native_field_load` 只认
标量/指针/数组等具体 kind，返回 VOID，于是回落到聚合路径并失败。

根因：`exec_lower_native_field_layout` 直接把字段类型的 `kind + 1` 编进指令，
`atomic T` 字段因此带着 `TYPE_ATOMIC` 下去。可在原生内存里 `atomic T` 就是一个 `T`。

修复：该函数在编码前用 `type_get_atomic_inner` 把 atomic 解开成内层类型
（偏移和尺寸仍按原字段类型算）。修复后该例前进到
`exec: 当前不支持该指针元素类型`（`run_linux_epoll_growth_case` 里
`read_fds[i]` 这一处指针元素类型问题，属另一条线）。

回归：`test_asm_atomic`、`bench_asm_atomic` 仍 `失败: 0`。

门禁复测（第 370 轮）：

- `make check`：首跑 1190/1191，唯一失败是 `test_raw_tls` 在 44 线程并行下
  「测试运行超时（>120s）」；单独复跑 C99 与 `--vm` 两侧均 `失败: 0`，
  重跑整套后 **1191/1191 通过**（`/tmp/check_r370b.log`），判定为并行负载下的超时抖动。
- 普查：**907 例 / 通过 839 / 失败 68 / 跳过 7 / 92.5%**，与第 369 轮逐例比对
  **零新增、零减少**（`test_async_event_dynamic_growth` 被 atomic 修复推进了失败点，
  但还没整例通过，所以计数不变）。
- `make exec-parity` 首跑因 **`/tmp` 被其它任务写满**（32G tmpfs，ENOSPC）
  在 415/914 例处中断，已改用 `TMPDIR` 指向大盘重跑；该次中断的日志不作数。
- `make exec-parity`（`TMPDIR` 指到大盘后重跑）：**914 例 / 一致 838 / 不一致 76 /
  stdout 差分 0**。与第 369 轮的 839/75 相比是两例抖动互换：
  `test_async_nested_http1_await_codegen` 变不一致、
  `test_async_thread_pool_dynamic_growth` 变一致，两者都依赖网络/时序，
  单独复跑都不稳定，不构成本轮回归。

### 第 371 轮：`LOAD/STORE_FIELD(… kind=14 pointee=16)` 簇的两条根因（未修）

给 `BC_LOAD_FIELD` / `BC_STORE_FIELD` 的失败分支加临时诊断后，这个簇分成两类：

1. `test_typed_pipeline_executor_single`（`sigismember`）：
   `isref=1`、地址落在 VM 驻留区、**引用目标的 kind 是 0（VOID）**。
   调用点在 `lib/std/process.uya:2931`，位于 `if pid == 0 { … }` 的 fork 子进程分支里：
   `var current_mask: sigset_t = sigset_t {};` 之后 `&current_mask` 指向的槽位
   在解释器里从未被materialize（VM 没有 fork，子进程分支是内联跑的）。
   这不是字段布局问题，而是子进程语义缺口。
2. `test_async_frame_align_pool` / `test_async_frame_pool_stats`（`async_frame.uya:503`）：
   `isref=0`、裸指针、地址落在 VM 驻留区。这块内存是 `async_frame_pool` 用宿主
   `malloc` 借出来的原生块，但地址被判成「VM 驻留」，于是既不走原生字段读写、
   也找不到聚合。要区分「VM 值」与「解释器自己 malloc 的原生块」，
   得用 `g_exec_alloc_*` 分配登记表做判定；本轮未做（第 359~361 轮在这条线上
   已有三次被 `test_fmt_*` 证否的记录，需要单独设计）。

另试过一个「引用目标若是裸数组就用缓冲首地址当原生基址」的补丁，对该簇无效，
已撤回。当前树在 `f5184ed8` 干净，`test_std_sql` / `test_asm_atomic` /
`test_std_jpeg_decode` / `test_async_sync_body_matrix` 复跑均 `失败: 0`。

### 第 372 轮：`@frame` 改造的可行性评估

想推进 async 帧那条主线，先量了爆炸半径：`tests/` 里用到 `@frame(` 的用例共
**12** 个，其中当前 `--vm` 下通过的有 **2** 个（`test_async_frame_stack_ok`、
`test_async_frame_type`，只用到 `@size_of`/类型，不碰 `start/poll/stop`）。

也就是说，把 `@frame` 合成结构体在 VM 侧真正建出来（`start` 调 body、`poll`
返回 `Poll`、`stop` 空操作）不会波及大量已通过用例。但按失败点逐个核对后，
这 10 个失败例里只有 2 个（`test_async_frame_methods`、`test_std_mqtt_async`）
卡在「帧没有布局」，其余分别卡在帧池原生内存（`pool_stats`/`align_pool`）、
`Pending` 语义（`state_machine`）、指针元素类型（`event_dynamic_growth`）和
网络/超时上。所以单做帧布局的收益是 2 例量级，优先级排在原生内存模型之后。

### 第 373 轮：`kind` 探测法被证否

想用「裸地址落在 VM 内存里、但该处 ExecValue 的 kind 编码越界（>24）就说明是原生字节」
来区分原生内存与 VM 值。实测无效：`async_frame_pool` 的分配头第一个字段就是
`storage_kind: i16`，其值（1）恰好落在合法 kind 区间（1 = I32），探测无法区分。

结论：这个判别必须在**分配处**打标记（谁 malloc 的、是不是 VM 值），
不能靠读内存内容猜。改动撤回，树保持在 `d6868c09` 的干净状态。
- 追加一条证否：按「全局区/槽池里只有 `sizeof(ExecValue)` 对齐的地址才是 VM 值」
  的启发式也无效 —— `async_frame_pool` 那块地址就是对 56 字节对齐落在竞技场登记区里的，
  单看地址无法区分。这条线要真正解决，必须在**分配处**登记「这是原生块」，
  并且让字段访问查得到这份登记。
- 追加证否：把「全局裸数组（`[byte: N]`）」在全局初始化后登记成原生区、
  让字段访问认这些区间，同样无效 —— `async_frame_pool` 的地址不在任何全局裸数组
  区间里（它不是全局 arena，而是宿主 `malloc` 出来的池）。这条线只能改成
  「谁分配谁登记」，并且要覆盖宿主 `malloc` 的路径。

### 第 374 轮：`getsockname` 取不到端口 —— shielding 把标量入参清零

`test_http_websocket_json` / `test_http_websocket_handshake` 的用例都走
`make_pair`，而 `make_pair` 里 `http_tcp_connect_loopback` 报 111（= `ECONNREFUSED`）。
逐步收敛：

1. 三个用例都 ERROR、无断言消息 → 说明错误是从库经 `try` 冒上来的，不是断言；
2. 临时打印测试函数的返回值：`kind=22 i64=1 error_id=111` —— 111 正是
   `ECONNREFUSED`，所以 `connect()` 真到了内核、只是没人监听；
3. 探针断言 `srv.port != 0` 失败 → **`http_server_listen` 返回的端口是 0**；
4. 再探 `sys_getsockname` 本身：返回 0（成功），但 `out[0]` 仍是 0；
5. 对照探针 `sys_read` 写进局部 `[byte: 8]` 完全正常 → 不是「写不进局部裸数组」；
6. 读 `exec_vm_syscall_shield_vm_addresses` 发现根因：它把落在槽位池里的指针参数
   换成原生 scratch 缓冲区，memset 清零后**只回填聚合字段**（`field_probe`）；
   `&alen` 这种**标量局部**走不到回填分支，于是内核读到的 `addrlen` 是 0，
   `getsockname` 按「写 0 字节」处理、仍然返回 0，端口自然永远是 0。

修复：scratch 清零后，标量目标也把当前值写进 `scratch2[0]`
（`exec_vm_numeric_to_i64` 取数）。这条只影响「标量局部按指针传给 syscall」的入参，
以前一律按 0 传给内核。

验证：`sys_getsockname` 探针拿到真实端口；`http_tcp_connect_loopback` 探针由
`ECONNREFUSED` 变为成功；`test_http_websocket_handshake` 由失败转为
**失败: 0**；`test_http_websocket_json` 3 个用例里 2 个转绿（剩下
`websocket_conn_write_json` 报一个 json 侧的 error id，属另一条线）。
回归抽样：`test_std_mem`、`test_std_sql`、`test_fmt_api`、`test_std_io`、
`test_stdio_file_buffering`、`test_tls_x509` 均 `失败: 0`；
`test_signal`、`test_std_async_event` 仍失败，但它们在改动前就是失败状态。

普查复测（`UYA_EXEC_CENSUS_MEM_MB=0 JOBS=12 TIMEOUT=240`）：
**907 例 / 通过 848 / 失败 59 / 跳过 7 / 93.5%**（上一轮 839/68）。
净增 **9 例**，全部来自本次 shielding 修复：`test_epoll_server`、
`test_http_server`、`test_http_websocket_handshake`、`test_http_websocket_async`、
`test_http_websocket_backpressure`、`test_http_websocket_heartbeat`、
`test_http_websocket_read_message_semantics` 等。
`make check` 复测 **1191/1191 通过**（rc=0）。
`make exec-parity`（`UYA_PARITY_TIMEOUT=600 UYA_PARITY_JOBS=6`）复测：
**914 例 / 一致 846 / 不一致 68 / stdout 差分 0**（上一轮 838/76，净增 8 例一致）。

### 第 375 轮：libm host call + `memcpy` 从 VM 标量取源

两条都是「VM 缺能力」，后者影响面很大。

**1. `extern "libc"` 的 libm 函数在 VM 里解析不了**

`lib/tflm/kernels/kernels.uya` 只写了不带体的 `extern "libc" fn exp(x: f64) f64;`，
`lib/libc/math.uya` 里的同名函数有 Uya 实现体所以能解释执行，这种裸声明两边都不认。
以前 `exp` 直接报「无法解析被调用函数」。

修复：新增两个通用 host call id（`EXEC_HOST_CALL_LIBM1` / `EXEC_HOST_CALL_LIBM2`），
具体函数名走 `BCHostCallSite.name`，VM 按名字分派
（`fabs/sqrt/cbrt/exp/exp2/log/log2/log10/sin/cos/tan/asin/acos/atan/sinh/cosh/tanh/
floor/ceil/round/trunc` 与二元 `pow/fmod/atan2/hypot/copysign/fmin/fmax`）。
`expm1`/`log1p` 因生成的头文件没声明而暂不收录。

**2. `memcpy(dst, &scalar_local, n)` 静默丢数据**

`kernels.uya` 的 `store_f32` 是 `memcpy(&(p[off]) as &void, &v as &const void, 4)`。
VM 里 `&v` 是「指向 ExecValue 本体的内部引用」，`exec_vm_mem_view` 对它返回
`EXEC_MEM_VIEW_VALUE` 且指针为 null，于是走到字节拷贝分支时 `mem_src_ptr == null`、
**整段拷贝被直接跳过** —— 目标一个字节都没写，而且不报错。

这是通用缺陷：任何 `memcpy(&buf[off], &本地标量, sizeof T)` 的二进制序列化在 VM 下
都会写出全 0。反方向（`memcpy(&scalar, raw, n)`）本来就有 `exec_vm_scalar_from_bytes`
处理，所以一直是对的。

修复：新增 `exec_vm_scalar_to_bytes`（按 kind 展开成小端原生字节），并在 memcpy 的
分支链里加一条「目标是原生缓冲、源是 VM 标量」的路径。

验证：三个探针（`memcpy` 从 `f32`/`i32` 取源、写入标量）全绿；
`test_tflm_interpreter`（同时需要上面两条）由失败转为 **失败: 0**；
`test_tflm_phase2`、`test_tflm_arena`、`test_tflm_model`、`test_std_mem`、
`test_std_sql`、`test_fmt_api`、`test_std_io`、`test_protobuf_wire`、
`test_std_jpeg_decode`、`test_http_websocket_handshake` 均 `失败: 0`。

普查复测：**907 例 / 通过 848 / 失败 59 / 跳过 7 / 93.5%**。
逐例比对：修好 `test_tflm_interpreter`；`test_async_nested_http1_await_codegen`
再次出现（该例是已知的网络时序抖动，同一命令多次复跑会在 0/1 之间跳，不计回归）。
`make check` 复测 **1191/1191 通过**（rc=0）。
`make exec-parity` 复测：**914 例 / 一致 847 / 不一致 67 / stdout 差分 0**
（第 374 轮 846/68）。

### 第 376 轮：24 例 `TIMEOUT` 的根因是解释执行速度，不是缺陷

之前一直把普查里的 124 归成「网络/线程」，本轮做了量化，结论不同：

**1. 不是挂死，是在跑**

`test_tls_x25519_pure` 用 `--trace-vm` 跑 25 秒，输出 15,373,094 条指令
（约 615K 指令/秒），停在 `mpi_const_limb_ptr` 的大数运算里 —— 一直在前进。
它跑满 240 秒仍未完成；后台用 900 秒上限跑同样没有结束。

**2. 基础循环很快，慢在分配**

- 3,000,000 次整数自增循环：整例 1.1 秒（含约 1 秒构建），即 VM 本身可达
  千万级简单指令/秒；
- `malloc(64)` + `free` 各 5000/20000/80000 次：627/1518/5147 毫秒，
  扣掉固定开销后约 **60 微秒/次**，且随次数基本线性（不退化，就是每次都贵）。

**3. 为什么贵**

`use libc.malloc` 拿到的是 `lib/libc/heap.uya` 里**有 Uya 实现体**的分配器，
VM 只能解释执行它；只有「无实现体的 `extern "libc"`」才走宿主 `malloc`
（`EXEC_HOST_CALL_MALLOC`）。大数/哈希/AST 这类分配密集的代码因此被放大成
60 微秒一次分配，x25519/RSA/ECDSA、TLS 握手、线程池这些用例自然撞 240 秒上限。

不能简单地让 `malloc` 一律走宿主：`test_std_mem`、堆缓存身份、arena 统计等用例
断言的是 Uya 分配器自身的行为，改掉会直接换一批失败。

**4. 直接验证**

把 `test_tls_x25519_pure` 的时间上限从 240 秒放宽到 900 秒后，它**跑完并通过**
（`通过: 1 / 失败: 0`）。也就是说这例在语义上是对的，只是慢。

结论：**24 例 124 属于性能问题，不属于语义缺口**。要收口需要解释器性能工程
（分配路径特化、指令分派优化），不是本文件的 parity 修补范围。

**5. 放宽时限后的复跑实测（20 例 124 全部重跑，单例上限 480 秒，并行 5）**

| 结果 | 例数 | 用例 |
|---|---|---|
| `rc=0`（只是慢，语义正确） | 3 | `test_https_debug`(435s)、`test_https_google`(435s)、`test_https_real_site`(445s) |
| `rc=1`（放宽后暴露真实失败） | 1 | `test_https_production`(437s) |
| 仍然 124 | 16 | `test_async_multi_fd_concurrent`、`test_async_runtime_shared_dns`、`test_async_runtime_shared_semantics`、`test_async_shared_runtime_semantics`、`test_async_task_queue_dynamic_growth`、`test_http1_async_client`、`test_http_uyagin_websocket`、`test_pthread_affinity`、`test_pthread_api_cancel`、`test_pthread_heap_cache_identity`、`test_pthread_heap_concurrency`、`test_std_async_scheduler`、`test_std_dns_async_transport`、`test_tls_ecdsa`、`test_tls_rsa`、`test_tls_x25519_pure` |

其中 `test_tls_x25519_pure` 单独用 900 秒上限跑是**通过**的，480 秒不够。

结论细化：20 例 124 里

- **4 例是纯性能问题**（3 个 https + x25519）：语义正确，只是解释执行跑不完；
- **1 例 `test_https_production` 是真实失败**，只是被超时掩盖了（以后要按 `rc=1` 追它，别再当超时）；
- **15 例是真的不收敛**（pthread/OSAL、async runtime、DNS transport、ECDSA/RSA），
  它们要么依赖真实并发（VM 单线程同步执行，等不到别的线程推进），要么需要挂起语义。

这也说明普查的「失败 59」里，口径上应把 `test_https_production` 从超时类移出，
后面按普通失败处理。

### 第 377 轮：P-256 域乘法去掉通用大数除法（超时类最大的一块）

**发现的两件事**

1. `P256_R_LE`（即 `2^256 mod p`）是**错的**。正确值应为

   ```
   l0 = 0x0000000000000001
   l1 = 0xFFFFFFFF00000000
   l2 = 0xFFFFFFFFFFFFFFFF          // 原来写成了 0
   l3 = 0x00000000FFFFFFFE          // 原来写成了 0x00000000FFFFFFFF
   ```

   原来那个常数等于 `0xFFFFFFFF0000000000000000FFFFFFFF000000000000000000000001`，
   `mod p` 之后也不是 `2^256 mod p`。它只被 `fe256_reduce_fold`（无人调用的死代码）
   引用，所以一直没暴露；本轮换掉实现后立刻炸出 300 组对拍全错，才定位到它。

2. `fe256_mul` 原来走 `tls.base.mpi` 的 `mpi_mul` + `mpi_mod`，一次 **约 40 毫秒**。
   一次 P-256 标量乘要上万次域乘，`ec_p256_public_from_private` 在 VM 里
   **298 秒**，TLS 握手（至少三次标量乘）自然被 240 秒的超时全部判死。

**改动**

- 修正 `P256_R_LE`；
- `fe256_mul` 改成**常量时间双倍加**：逐位做 `acc = 2*acc` 和
  `acc += b_i ? a : 0`（条件加用掩码，不分支），进位用 `2^256 ≡ R` 折回，
  再条件减 `p`。完全不碰通用大数除法。
- 临时量全部提到循环外（解释执行下 `Fe256{ l: [0:4] }` 字面量一次约 20 微秒，
  原来每比特要分配 5 次）；另加 `fe256_cond_sub_p_into` / `fe256_reduce_257_into`
  两个热路径变体，由调用方提供临时量，热路径零分配。

**验证**

- 与旧实现（`fe256_mul_mpi`，走 mpi 除法）**逐位对拍 300 组随机输入全等**，
  另加边界：`1*(p-1)`、`0*(p-1)`、`(p-1)^2`；
- `test_ec_p256_ecdh` 在 VM 和 C99 两侧都是 `失败: 0`；
- C99 侧 29 个 `test_tls*` / `test_ec_*` / `test_https*` / `test_x509*` 用例全部
  `失败: 0`（无回归）；
- 单次 `fe256_mul` 由 40 毫秒降到约 25 毫秒；`ec_p256_public_from_private`
  从「180 秒都跑不完」变成 298 秒能跑完并通过（仍有很大优化空间）。

**第二轮优化：全标量展开 + 只在最后条件减一次**

第一版仍是「数组下标 + 每比特两次条件减」的写法，一次域乘 25 毫秒 ——
`--trace-vm` 直方图显示 `fe256_sub_p` 和条件减占了 60% 以上，全是
`acc.l[i]` 这种聚合下标访问（每次带越界检查）。

改成：

- 四个 64 位标量 `x0..x3` 承载累加器，全程不碰数组下标；
- 中间值只要求「mod p 同余」，不必随时 `< p`。2^256 的进位照 `2^256 ≡ R`
  折回低位即可，**条件减 p 只在最后做一次**（收尾时 `x < 2^256 < 2p`）。

效果：

| 指标 | 改前 | 改后 |
|---|---|---|
| 单次 `fe256_mul` | 40 ms（mpi）→ 25 ms（第一版） | **< 5 ms** |
| `ec_p256_public_from_private` | 298 s | **7 s** |
| `test_https_production`（VM） | 437 s 后报 LOAD_FIELD 错 | **37 s，失败: 0** |

对拍（300 组随机 + 边界）依旧全等，`test_ec_p256_ecdh` 两侧全绿。

### 第 378 轮：结构体数组不能用裸指针算术（router 三例转绿）

`test_https_loopback` 在 VM 里 4 秒就报：

```
exec: LOAD_FIELD 字段越界(idx=6 kind=14 count=-1 pointee=16)
    at lib/std/http/uyagin_router.uya:364 uyagin_router_find_static_child
```

`parent.first_static_child` 的 `parent` 来自 `uyagin_router_node_ptr`：

```uya
@ptr_from_usize(@usize_from_ptr(&router.nodes[0] as &void)
                + (idx as usize) * @size_of(UyaginRouterNode)) as &UyaginRouterNode
```

最小复现（1 秒，C99 通过、VM 报同样的错）：

```uya
const p: &Node = @ptr_from_usize(@usize_from_ptr(&r.nodes[0] as &void)
                                 + (3 as usize) * @size_of(Node)) as &Node;
p.first_child   // → LOAD_FIELD 字段越界
```

**根因**：`[Struct: N]` 这样的字段在 VM 里每个元素是一个 `ExecValue`
（56 字节），而 `@size_of(Node)` 给的是 C 布局大小（40 字节）。裸指针算术
落到 ExecValue 中间，`exec_vm_field_object` 在那里读不出合法聚合，于是报越界。
这不是 router 的问题，是**VM 不支持「对结构体数组做手动指针算术」**
这一类写法（`test_typed_pipeline_capability` 之前那个 `kind=0 count=-1` 也是同一类）。

**处理**：`uyagin_router_node_ptr` 改用下标取地址 `&router.nodes[ui]`
（VM 里 LOAD_INDEX 会给出元素 ExecValue 的内部引用，C99 下等价）。

结果：

| 用例（VM） | 改前 | 改后 |
|---|---|---|
| `test_https_loopback` | LOAD_FIELD 越界 | **失败: 0** |
| `test_https_local` | 同族 | **失败: 0** |
| `test_https_websocket_loopback` | 同族 | **失败: 0** |
| `test_http_websocket_json` | 124 超时 | 只剩 1 个用例 ERROR |

C99 侧这 4 例全绿（无回归）。

**本轮累计效果**

| 指标 | 第 374 轮 | 第 378 轮 |
|---|---|---|
| 普查通过 | 848 / 907（93.5%） | **853 / 907（94.0%）** |
| 失败 | 59 | **54** |
| 转绿用例 | — | `test_https_debug`、`test_https_google`、`test_https_loopback`、`test_https_production`、`test_https_real_site` |
| `make check`（C99） | 1191/1191 | **1191/1191** |

翻转的 5 例全是 https：P-256 提速让握手跑得完，router 的下标修复让它们真正通过
（含 `test_https_google` / `test_https_real_site` 这种连真实站点的）。
没有新增失败。
`make exec-parity` 复测：**914 例 / 一致 848 / 不一致 66 / stdout 差分 0**
（第 374 轮 846/68）。剩余 66 例里 async 相关占 30 例以上，其余是 pthread、
`@c_import`、TLS 大数、typed_pipeline 这几类已知的模型级缺口。

### 第 379 轮：`exec_vm_load_pointer_index` 的 ExecValue 越界读

`test_http_uyagin` 在 VM 下是 `rc=139`（**段错误**，不是断言失败）。gdb 回溯：

```
#0 exec_vm_load_pointer_index
#1 vm_step
#2 exec_vm_run_frame
#3 exec_vm_call_function
...
```

这条路径在「内部引用 + 下标」时直接做裸地址加法：

```uya
const value_elem: &ExecValue = @ptr_from_usize(exec_vm_index_ref_element_addr(&base, index_value)) as &ExecValue;
out_value[0] = exec_value_clone(value_elem);
```

`exec_vm_index_ref_element_addr` 是 `base.i64_value + sizeof(ExecValue) * index`，
没有任何上界。下标越界就会把任意内存当 ExecValue 克隆。

**已修**：先取引用目标，按目标的元素数（聚合 `count` 或裸数组长度）校验下标，
越界报「exec: 指针下标越界」而不是崩。

**仍在的**：同一测试里还有个野生指针。加临时标记（已删）打出来是

```
fn=async_box_free_current addr=fffffff1 idx=0 kind=14 pointee=7
```

`0xfffffff1` 是 async 帧盒子释放路径拿到的野地址，属于既有的 async frame
模拟缺口（VM 同步执行，`@frame` 的 start/poll/stop 是空操作），
这一处目前仍会让进程收到 SIGSEGV。它不影响别的用例，
但说明「VM 缺能力时应当报错而不是崩」这条纪律在 async 路径上还没落实。

### 第 380 轮：`test_std_async_event` 的 waker 没被唤醒（未修完，留档）

现象：`register(read_fd, Readable, &w) `后 `poll(0)` 返回 `ready_n == 1`，
但 `w.is_woken()` 仍是 0。

逐步插桩（已全部撤掉）得到的事实链：

1. `poll` 确实走的是 epoll 分支，`sys_epoll_wait` 返回 `n=1`；
2. 但 `epoll_event_fd(&self.events[0])` 读出 **fd=0** —— 内核回写的
   `data_lo` 是 0，于是 `find_slot(0)` 找不到槽位，waker 没被唤醒；
3. `data_lo` 为 0 说明注册时交给内核的 `struct epoll_event.data` 是 0；
4. 注册走 `sys_epoll_ctl`，VM 里本该由「`&EpollEvent` → 原生 12 字节布局」的
   转换（`exec_vm_epoll_ctl_native_event`）填好 `data_lo`；
5. 插桩显示这个转换**根本没跑到底**：`exec_vm_syscall_out_struct_target()`
   对第 4 个实参返回 null，于是整段转换被跳过，裸地址原样交给内核。

顺带排除了两个猜测（都写了探针、都通过）：

- `(waker as &void) as usize` 存进 `slot_wakers` 再 `@ptr_from_usize` 取回、
  调 `wake()` —— 往返正常，`is_woken()` 变 1；
- 原生 `EpollEvent` 数组按下标取元素再 `epoll_event_fd()` —— 读回正确。

所以缺口在「`@syscall` 变参里把 `&结构体` 降级成 i64 之后，
出参结构体目标的还原」。这条路径也解释了 `test_http_uyagin` 里
`async_box_free_current` 拿到野生指针 `0xfffffff1` 的同类问题：
**结构体指针一旦经过 i64 中转，VM 就找不回它对应的 ExecValue**。

下一步的方向（留给后续）：让 `exec_vm_syscall_arg_to_i64` 在遇到内部引用时
把「这是哪个 ExecValue」的旁路信息保留下来（例如把实参槽的索引一并编码），
而不是只丢一个裸地址给 `exec_vm_syscall_out_struct_target` 去猜。

### 第 381 轮：普查为什么"又慢又卡"——三个根因

这一轮没有推进覆盖率，专门查"跑一轮普查要一小时、CPU 还忽高忽低"。
结论是三个独立问题叠加，其中第一个是我自己引入的回归。

#### 根因 1（我的回归，已回退）：`@await` Pending 让用例无限忙等

我曾让 `@await` 遇到 Pending 时不再报错，而是让当前 async 函数返回
`Future{state: Pending}`。这对 `test_async_await` 是对的，但 `block_on` 的实现是

```uya
while true {
    w.reset();
    const p: Poll<!T> = f.poll(&w);
    match p { .Ready(v) => { return v; }, .Pending(_) => { } };
}
```

VM 里没有真正的挂起/恢复，Pending 永远不会自己变成 Ready，于是**每个这类用例
都变成死循环空转**，把 CPU 吃满还不结束。后果：整轮普查跑不完，
`test_std_dns_async_query_aggregate` 一个用例卡了 **50 分钟**（超时设置是 240 秒）。

已 `git checkout` 回退 `src/exec/{vm,builder,lower}.uya`。回退后该用例
**2 秒**就报出明确原因（`exec: @await 操作数不是 Future 或始终 Pending`）。
代价：`test_async_await` 回到"失败"，这是已知的模型级缺口
（真正的 Pending 语义需要栈式协程或真反应堆），不该用假成功换。

#### 根因 2：`timeout` 没有 `-k`，忽略 SIGTERM 的用例永远不被回收

`run_one` 原来是 `timeout "$timeout_s" ...`。只发 SIGTERM，进程若不理就直接
等到天荒地老 —— 这就是"超时明明设了 240 秒却跑了 50 分钟"的直接原因。
已改为 `timeout -k 10`（TERM 之后补 SIGKILL），并把超时信号发给整个子进程组，
fork 出去的子进程也会一起收掉。

#### 根因 3：我为"安全清理"加的 `setsid` 自我重启，反而制造了幽灵进程

为了避免按名字 `pkill` 误伤同机其它会话，我让脚本 `exec setsid "$0"` 把自己
放进独立进程组。但这有个副作用：**父进程立刻退出、真正的脚本被分离**，外层
`timeout` / 管道 / 调用者都拿不到它的生命周期。实测后果是单文件普查跑出
**209 秒**（外层 `timeout 200` 到期才结束），而同一文件用 `run_one` 单独跑只要
**1 秒**。

已改成不需要任何模式匹配的方案：

- 每个 worker 由 `timeout -k <grace>` 硬性封顶，单个用例不可能无限期占着 CPU；
- 因此即使脚本被 SIGKILL，遗留的也只是"各自会超时自动退出"的进程，
  不需要事后按名字扫射；
- 脚本里不再有任何默认执行的 `pkill`（只有显式 `UYA_EXEC_CENSUS_REAP=1` 才清）。

改完后同样那个单文件普查从 **209 秒降到 2 秒**，且不留进程。

#### 另外两点实测修正

- **默认 `MEM_MB=1024` 太小**：编译器自己的 `CompilerArena` 就要 1GB 以上，
  1024 会让 **79 个用例在编译期**就报 `CompilerArena 无法分配 chunk` 假失败
  （实测把上限放到 4096 后，抽查的 4 个全部恢复 `失败: 0`）。默认值已提到 4096。
- **"CPU 没起来"是正常的**：真正拖时间的网络/DNS 用例是**阻塞在 I/O 上**
  （实测 `timeout` 包着的 uya 进程 CPU 占用 **0.0%**），不是算得慢。
  这类用例低 CPU 却吃满整个超时槽位，并行度一高就互相拖死。
  想真正提速，应当给它们单独设**更短**的超时（现成的
  `tests/exec_vm_census_timeouts.txt` 目前只支持"放宽"，方向相反）。

- 机器上同时有一台 8 vCPU 的 macOS QEMU 虚拟机在跑，12 路并行普查和它抢核，
  也会显著放大耗时。

#### 治本：把"阻塞型"用例的等待时间收窄

`tests/exec_vm_census_timeouts.txt` 原来只支持"放宽"（纯 CPU 慢的用例）。但真正
拖垮普查的是另一类：**VM 里推不动、只会干等**的用例。历史数据
（`uya-tmp/slow_results.tsv`）里 20 个用例每个都吃满 **480 秒**，按并行度 6 折算，
光它们就占掉约 **27 分钟墙钟**。

判别方法很简单：跑的时候看 CPU。**CPU 打满 = 算得慢（放宽）；CPU 接近 0 =
阻塞干等（收窄）**。后者不该跳过（那会把覆盖率数字做漂亮），但也不该让它
吃满默认超时。

已给 13 个阻塞型用例设 60 秒超时：

```
test_async_multi_fd_concurrent         test_async_runtime_shared_semantics
test_async_shared_runtime_semantics    test_async_task_queue_dynamic_growth
test_http1_async_client                test_http_uyagin_websocket
test_pthread_affinity                  test_pthread_api_cancel
test_pthread_heap_cache_identity       test_pthread_heap_concurrency
test_std_async_scheduler               test_std_dns_async_transport
```

实测单个用例从"吃满 480 秒"变成 **62 秒**结束，判定结论不变（仍是失败）。
13 个合计每轮省下约 **39 分钟槽位时间**。

同时保留"放宽"侧的 3 个纯 CPU 用例（bigint/ed25519/modexp4096），
它们是真在算，必须给足时间。

#### 修完之后的实测

| 指标 | 修之前 | 修之后 |
|---|---|---|
| 全量普查墙钟 | 59 分钟仍在跑，被迫 kill | **约 14 分钟跑完** |
| 单文件普查 | 209 s（幽灵进程） | **2 s** |
| 阻塞用例单例 | 480 s 吃满 | **62 s** 快速失败 |
| 通过 / 失败 | 853 / 54 | 854 / 53（见下方保留） |

#### 一个必须记录的普查盲点：fork 出去的用例会假通过

本轮普查把 `test_async_nested_http1_await_codegen` 记成通过（`status=0`，
明细 `失败: 0`），但**单独连跑 5 次全部失败**。原因是这类用例会 `fork`：
父进程很快 `_exit(0)`，断言其实在子进程里跑；普查只看父进程的退出码，
于是把"子进程断言失败"记成通过。

结论：

- 这个 +1 **不算数**，稳定基线仍是 **853 / 54**；
- 普查对「fork 型」用例的结论不可信，涉及 `pipeline_*`、`test_osal`
  这类用例时必须单独跑一遍确认，不能只看普查数字；
- 这也是为什么本轮不把 854 当成收益写进结论。

### 第 382 轮：TLS 身份槽位的裸指针算术（`test_tls_handshake` 转绿）

`test_tls_handshake` 在 VM 里报：

```
lib/tls/ssl/context.uya:372:8: exec: ADDR_FIELD 字段越界
```

第 372 行是 `ssl_server_add_identity`，它调用 `ssl_server_identity_ptr(ctx, slot)`。
两个取槽位的 helper（`_ptr` / `_const_ptr`）写的是：

```uya
const base: &SslServerIdentity = &ctx.server_identities[0];
const off: usize = slot * @size_of(SslServerIdentity);
return @ptr_from_usize(@usize_from_ptr(base as &void) + off) as &SslServerIdentity;
```

和 router 那次是**同一类 bug**：`server_identities: [SslServerIdentity: N]` 在 VM 里
每个元素是一个 `ExecValue`（56 字节），而 `@size_of` 给的是 C 布局大小。
裸指针算术落进 ExecValue 中间，随后取字段地址就报「ADDR_FIELD 字段越界」。

改成下标取地址：

```uya
return &ctx.server_identities[slot];
```

C99 侧两者完全等价，所以行为不变。

验证：

- `test_tls_handshake` VM：`失败: 0`（原来 ADDR_FIELD 越界）
- C99 侧 `test_tls_handshake` / `test_https_loopback` / `test_tls_x509` /
  `test_https_production` 全部 `失败: 0`（无回归）
- VM 侧 `test_https_loopback` 仍 `失败: 0`

至此「结构体数组不要用裸指针算术」这个模式已在 router 和 TLS identity 两处
修掉；`rg '@size_of\(' + '@ptr_from_usize'` 在 `lib/` 里还剩 6 处，都属于同类，
后续按同样方式处理。

#### 顺带清掉其余同类写法

把剩余 4 处「结构体数组 + 裸指针算术」也改成指针下标（`ADDR_INDEX` 在 VM 里
支持指针基址，并按指令里的元素大小步进，C99 侧等价）：

| 文件 | 函数 |
|---|---|
| `lib/std/http/uyagin.uya` | `uyagin_conn_slot_ptr`、`uyagin_append_response_headers_fast` |
| `lib/std/http/uyagin_router.uya` | `uyagin_request_segment_ptr`、`uyagin_router_route_meta_ptr` |

`lib/` 里现在只剩 3 处 `@ptr_from_usize(... @size_of(x))`，都是**标量**数组
（`i32`/`byte`）——VM 里标量数组本来就是原生字节数组，这类写法是正确的，保留。

### 第 383 轮：async 帧池的原生字段写入（`test_async_frame_align_pool` 转绿）

`test_async_frame_align_pool` 报：

```
lib/std/async_frame.uya:503: exec: STORE_FIELD 字段越界(idx=0 kind=14 count=-1 pointee=16 aux=16 isref=0 nk=1 nb=0 c=0)
```

第 503 行是 `async_frame_pool_write_alloc_header(raw_ptr: &byte, ...)`，把裸字节块
转成 `&AsyncFrameAllocHeader` 再写字段——**内容确实是原生布局**。

- `nk=1`：指令里带了原生字段布局（译者已经知道这是一个原生 struct）
- `nb=0`：`exec_vm_field_native_base` 返回 0

`exec_vm_field_native_base` 对「非内部引用指针」的处理是：

```uya
if exec_vm_pointer_is_internal_ref(cursor) == 0 {
    if exec_vm_address_is_vm_resident(addr) {
        return 0 as usize;   // 认为这是 VM 值，不是原生内存
    }
    return addr;
}
```

async 帧池的字节块地址**恰好落在值 arena 的地址范围里**（池子自己就是从 arena
分配字节的），于是被误判成 VM 值而拒绝，随后 `exec_vm_field_ref_store` 找不到
聚合（`count=-1`）就报越界。

修法：加 `exec_vm_field_native_base_relaxed()`，只要求「非内部引用指针 + 非零
地址」，不做 VM 驻留判断。关键是**只在按 VM 值取字段确实失败之后才退到它**：

```uya
var field_ref2: &ExecValue = exec_vm_field_ref_store(slot_a, instr.imm as i32);
if field_ref2 == null && stf_native_kind > 0 && stf_native_base == 0 as usize {
    // 这里才尝试原生基址
}
```

`LOAD_FIELD` 同样加了这个兜底。因为只有在 VM 解释失败后才启用，真正的
`ExecValue` 聚合不会被误判成原生内存。

验证：

- `test_async_frame_align_pool`：VM `失败: 0`，C99 `失败: 0`
- `test_async_frame_pool_stats`：不再报「字段越界」，越过该点后卡在
  `async_box_free_current` 的 `BC_LOAD_INDEX` 段错误——**这是既有缺口**
  （`test_http_uyagin` 早先就在同一函数同一指令崩过，野生指针 `0xfffffff1`），
  与本次改动无关，单独记录。
- 回归抽查（VM）：`test_async_frame_methods`、`test_async_frame_pool_full`、
  `test_async_state_machine`、`test_async_compute_types`、
  `test_typed_pipeline_capability`、`test_typed_pipeline_executor_single`、
  `test_http_websocket_json`、`test_std_script_pipeline_facade`
  报错信息与改动前**完全一致**，无回归。

### 第 384 轮：门禁复测 + 本轮遗留问题定位

本轮（第 382~383 轮）共修 3 处，全部已单独提交：

| 提交 | 内容 | 转绿用例 |
|---|---|---|
| `c9520822` | TLS 身份槽位改下标取地址 | `test_tls_handshake` |
| `49da8b27` | 其余结构体数组辅助函数改指针下标 | （预防同类） |
| `8adb4ba1` | 原生字段读写加宽松基址回退 | `test_async_frame_align_pool` |

门禁复测：

- `make check`：**1191 个测试 / 通过 1191 / 失败 0**，`rc=0`
- `make exec-parity`：**914 例 / 一致 849 / 不一致 65 / stdout 差分 0**（上次 848）
- 普查基线（上一次全量）：907 例 / 通过 854 / 失败 53 / 跳过 7

#### 遗留 1：`async_box_free_current` 的 `BC_LOAD_INDEX` 段错误（`rc=139`）

`test_async_frame_pool_stats`、`test_http_uyagin` 都会崩在同一处。现场：

```
[vm] enter fn=async_box_free_current args=1
[vm] fn=async_box_free_current ip=0 op=BC_LOAD_LOCAL(1) a=7 b=0   ← 参数 ptr 进来就是 0xfffffff1
```

`ptr` 在函数入口就已经是野生指针（`0xfffffff1`，即 `-15` 被截成 32 位），
来源是 `async_frame_allocator_worker` 里的：

```uya
const boxed: &byte = async_box_alloc_current(16usize);
if boxed != null { async_box_free_current(boxed); }
```

也就是说 `async_box_alloc_current` 返回了一个非空但无效的指针。该函数经
`IAllocator` 接口派发 `alloc.alloc(total_size)`，接口调用在 VM 里的返回值需要
进一步核对（`lib/std/async.uya:118`）。**未修**，是当前唯一会让 VM 进程直接
段错误的已知点（其余失败都是干净的非零退出码）。

#### 遗留 2：`pipeline_capability_self_test` 的 `env_ops` 索引返回 VOID

`test_typed_pipeline_capability` 报 `LOAD_FIELD 字段越界(idx=2 kind=0 ...)`，
`kind=0` 是 VOID。trace 定位到 `lib/std/process.uya:3752` 附近：

```
LOAD_GLOBAL a=41 → LOAD_LOCAL b=6 → LOAD_INDEX elem=48   (定位 stage)
→ LOAD_FIELD c=32                                        (env_ops 字段)
→ LOAD_CONST → LOAD_INDEX elem=24                        (env_ops[1])
→ LOAD_FIELD c=16 idx=2                                  ← 操作数是 VOID
```

`env_ops: &PipelineEnvOp` 指向的是 lib 自己 malloc 出来的原生结构体数组，
`LOAD_INDEX` 原生分支本应返回「指向该元素的指针」，实际返回了 VOID，
没有报错。**未修**：需要核对 `exec_vm_load_pointer_index` 在
`elem_size_hint > 0` 与 `exec_vm_native_agg_slot` 两条路径上的取舍。

#### 已确认不可在本轮修的模型墙

- `test_kernel_sim` / `test_osal` / `test_std_thread*`：fork + execve 子进程，
  VM 侧没有该能力（断言拿到 `actual: 0`）。
- `test_http_websocket_json` / `test_std_script_pipeline_facade`：都走 `@await` /
  spawn，落回 async 语义缺口。
- async 家族约 20 例：`@await` / `@frame` 合成结构体在 VM 里不存在
  （`match frame.poll(...)` 的操作数是 VOID）。

### 第 385 轮：普查复测（855 / 52 / 7）

用当前二进制重跑普查（`MEM_MB=4096 JOBS=8`）：

- **通过 855 / 失败 52 / 跳过 7，通过率 94.3%**
- 上一轮是 854 / 53 / 7。净 +1 来自 `test_async_frame_align_pool`
  （第 383 轮的宽松基址回退）；`test_tls_handshake` 在上次普查时已按失败计入，
  本轮同样通过，`test_https_loopback` 等也保持通过。
- 三个已提交修复均无回归。

#### 本轮已确认的失败构成（52 例为主）

1. **async / `@await` / `@frame`（约 20 例）**：`@frame(fn)` 合成结构体在 VM
   里不存在，`frame.poll()` 的返回值是 VOID，`match` 于是报
   `LOAD_UNION_TAG 目标不是 union` 或 `@await 操作数不是 Future 或始终 Pending`。
2. **线程（约 8 例）**：`test_std_thread*`、`test_async_thread_pool_dynamic_growth`
   依赖真实工作线程，VM 里 `thread_wait_started_workers` 恒为 0；
   `test_pthread_*` 是 124（超时）。
3. **fork + execve（约 4 例）**：`test_kernel_sim`、`test_osal`、
   `test_std_script_pipeline_facade`（spawn `/usr/bin/true`）。
4. **`@c_import`（3 例）**：明确报「当前不支持」。
5. **原生信号/大数（约 5 例）**：`test_signal`、`test_tls_ecdsa` / `test_tls_rsa`
   超时、`test_typed_pipeline_executor_single`（`sigset_t` 原生字段）。

#### 已排除的误判

`test_abi_calling_convention` 在 parity 里 C99 侧也是失败，原因是该用例需要外链
C 助手（`c_large_struct_param` 等未定义），单独跑 `uya test` 必然链接失败。
属于 parity 夹具问题，不是 VM 缺陷。

### 第 386 轮：epoll_ctl 事件注册失败的定位（未修，已排除两条假设）

`test_std_async_event`、`test_std_async_event_fd_reuse` 共 4+ 个用例都卡在

```
assert_eq_i32 failed: w.is_woken() as i32 == 1 (actual: 0, expected: 1)
```

即 waker 永远不会被唤醒。链路是 `epoll_ctl(233)` 注册事件 →
`epoll_wait` 返回 → 按 `data` 找回 waker。实测 `epoll_wait` 能返回，但
`data_lo = 0`，说明**注册进去的 events/data 是 0**。

调用点在 `exec_vm_exec_syscall`：

```uya
if nr_value == EPOLL_CTL_NR && arg_count >= 4 &&
   exec_vm_address_is_vm_resident(args[3] as usize) {
    // 把 &EpollEvent 转成原生布局；失败就原样把裸地址交给内核
}
```

本轮验证并**否掉**了两条假设（改动均已回退）：

1. **假设：地址在原生聚合旁路表里** —— 加
   `agg = exec_vm_native_agg_handle(raw_addr)` 兜底。实测返回的聚合
   `count == 0`，`exec_vm_native_agg_peek(base, 0/1)` 也全是 null，
   说明旁路表里**没有**这个基址的字段。
2. **假设：地址是 arena 里带偏移的聚合元素** —— 加
   `exec_vm_realign_in_arena()`（按 `@size_of(i64)` 向下探测最多 8 步）。
   实测 `exec_vm_syscall_out_struct_target` 仍然返回 null，
   连 `target.kind` 都读不到聚合。

结论：`args[3]` 这个地址对应的内存**既不是 ExecValue 起始地址，也不是旁路表
基址**，epoll_event 在 VM 里根本没有被物化成任何可识别的形态。

真正的修法需要在 lowering 阶段把「取局部结构体地址并转成整数传给 syscall」
变成一次显式的物化（分配原生缓冲区 + 逐字段写入），而不是像现在这样只把地址
传下去。这属于 `@syscall` 入参 marshal 的一个独立特性，改动面较大，本轮不做。
相关代码位置：`src/exec/vm.uya` 的 `exec_vm_exec_syscall`（epoll_ctl 分支）与
`exec_vm_syscall_out_struct_target`。

### 第 387 轮：epoll 唤醒断链的真正原因（已修）

第 386 轮把结论写成「epoll_event 在 VM 里根本没有被物化成任何可识别的形态」，
**那个结论是错的**。本轮从内核侧取证，断链点不在「物化」而在「打包」。

#### 取证方法

`strace` 直接看内核收到的字节，绕开 VM 侧一切解读：

```
epoll_ctl(5, EPOLL_CTL_ADD, 6,
          {events=EPOLLIN, data={u32=0, u64=25769803776}}) = 0
epoll_wait(5, [{events=EPOLLIN, data={u32=0, u64=25769803776}}], 1024, 0) = 1
```

`25769803776 = 0x6_00000000` —— **fd 6 被写进了 `data` 的高 32 位**。
本机 `sizeof(struct epoll_event)` 实测为 12、`data` 在 offset 4（用一个等价
C 程序确认：`n=1 bytes: 01 00 00 00 06 00 00 00 ...`）。

#### 三个独立缺陷叠在一起

1. **聚合槽序不等于声明序。**
   `EpollEvent{ events, data_lo, data_hi }` 在 VM 聚合里可能落成
   `[events, data_hi, data_lo]`。`exec_vm_epoll_ctl_native_event` 按声明序取
   `values[1]` 当低 32 位，于是 fd 进了高半。
   修法：本运行时 `data` 只当 fd 用、值恒在低 32 位，所以「槽 1 为零而槽 2
   非零」时把槽 2 当低 32 位，两种槽序都能得到正确的 8 字节 `data`。

2. **`epoll_ctl` 分支的 residency 门禁把转换整体关掉。**
   `exec_vm_address_is_vm_resident(args[3])` 为真才做原生打包。但竞技场
   （200MB）和宿主 malloc 出来的内存在同一片地址空间里，
   `exec_vm_address_is_value` 会把不少宿主指针也判成驻留 —— 用 `strace`
   对照发现转换根本没发生。而且 `&ev as i64` 已经把指针整数化，
   参数槽里只剩 `kind=I64`，`exec_vm_syscall_out_struct_target` 返回 null，
   这正是最需要转换的一种。
   修法：去掉该门禁，改为「一律先尝试转换，失败才保留原地址」；
   参数已整数化时按原生缓冲区的 3 个 i64 读（每个字段占一个 i64，和
   `exec_vm_syscall_out_struct_prepare` 造出来的表示一致），并做内容校验
   （events 非零且落在 u32 内、data 高 32 位为空），不满足就不碰它。

3. **出参 marshal 的 scratch 回退不分场合。**
   `exec_vm_syscall_marshal_out_struct` 在出参解析不出结构时无条件换成
   256 字节 scratch 且不回填。`epoll_wait` 的事件数组是 malloc 出来的字节块，
   参数已经是 `events as i64`，永远解析不出 ExecValue 结构 —— 于是内核把事件
   全写进 scratch，调用方读到的永远是全 0。那一轮 `epoll_wait` 能返回 n=1
   却 `epoll_event_fd` 读到 0，就是这条。
   修法：scratch 只对**确实落在 VM 驻留区**的地址生效（那才是「内核会踩坏
   ExecValue 头」的危险场景，`test_signal` 的 `rt_sigaction`）；原生内存原样
   交给内核。

#### 结果

修好后 `strace` 变成 `data={u32=6, u64=6}`，`w1.is_woken()` 断言通过：

- `test_std_async_event`：`失败: 0`
- `test_std_async_event_fd_reuse`：`失败: 0`

提交 `916b1833`。

#### 仍然失败的部分（与 epoll 无关）

`test_signal` 的 `signal_handler_is_invoked` / `sigprocmask_blocks_delivery`
依旧 FAILED —— 那是「内核回调进 VM 执行 handler」的模型墙，不是打包问题。

#### 给后续轮次的提示

「VM 里读到的值和内核对不上」这类问题，**先上 `strace -xx` 看内核侧的字节**，
再用等价 C 程序确认 ABI 布局，最后回 VM 找打包/解包的位置。第 386 轮花了整轮
在 arena / 旁路表里找「物化形态」，方向就错了。

### 第 388 轮：epoll 修复的回归确认与门禁重测

#### 调试打印清理

第 387 轮定位过程中在 `exec_vm_epoll_ctl_native_event` 与 epoll_ctl 分支里
留了 `DBGEC5` / `DBGEC6` 两处 `fprintf`。上一轮删诊断的脚本中途退出，只改了
函数体、没清干净调用点。本轮手工清完，`grep -c "DBG" src/exec/vm.uya` = 0，
并 amended 进 epoll 修复提交，保证历史里不留噪声。

#### 异步/事件族回归

117 例异步/事件族用例跑到 94 例时被门禁抢占，已足够判定：

- 19 例失败，**全部落在既有失败清单内**（`@await` 语义、async 帧布局、
  线程/任务队列那几类），零新增倒退。
- 两个 epoll 用例单独复测：`test_std_async_event` `失败: 0`、
  `test_std_async_event_fd_reuse` `失败: 0`。

#### 门禁纪律：parity 必须限并行度，且不能与回归并发

这一轮踩了两个坑，都记进来免得再犯：

1. **`make exec-parity` 默认并行度 = 核数（本机 44）**。44 路同时跑 914 例
   时内存被打满（62G 全占），其中一个子进程 RSS 涨到 **58G**，整机进入
   内存枯竭状态 —— 这种局面下 `uya-agent` 很容易被 OOM 杀掉。
   改 `UYA_PARITY_JOBS=6` 后内存稳定在「已用 9G / 可用 53G」。
   **结论：parity 固定 6 路。**
2. **回归和 parity 不能并发**。两者抢 CPU 会让 async 用例大面积走 60s 超时，
   读数完全不可信（这一轮就出现了 15 例假失败）。门禁必须串行跑。

清理办法：`ps -eo pid,comm | awk '$2=="uya"'` 按 PID 精确 `kill`，
不要 `pkill -f`（会连带杀掉 agent 进程树）。

### 第 389 轮：epoll_wait 事件按 packed 12 字节记录解包

#### 发现

第 388 轮跑 parity 时 `test_epoll_server` 一例跑了 24 分钟不结束，单独复现是
**6 个断言失败**（`0 == 1`、`total_drained == 2` 实得 0），而改前普查里它是
`失败: 0`。把 `src/exec/vm.uya` 退回 `35c434be` 重建复测，同为 8/8 通过 ——
回归确认是本轮改动引入。

#### 根因：改前是「两边都错但互补」的假通过

用 `strace` 对比两个版本的 `epoll_wait` 返回值：

- 改前：`data={u32=0, u64=21474836480}` = `0x5_00000000`，fd 在**高 32 位**
  （`epoll_ctl` 把 fd 写进了 `data` 高半，见第 387 轮）。
- 改后：`data={u32=5, u64=5}`，fd 在 `data_lo`（低 32 位），这是正确的。

内核写的是 C 的 packed 布局：`events` u32 @0、`data_lo` u32 @4、
`data_hi` u32 @8，每条 **12 字节**（本机 `sizeof(struct epoll_event)=12`）。
而 VM 聚合是「一字段一个 i64」，通用 `exec_vm_syscall_out_struct_apply`
按 8 字节步长回填，于是：

- 改后：`buffer[0] = 0x00000005_00000001`（events 和 data_lo 粘进一个 i64），
  `buffer[1] = 0` → `epoll_event_fd` 读到 0 → 认不出监听事件 → 从不 accept。
- 改前：fd 在 offset 8，恰好被 apply 读成第二个 i64 字段 → `epoll_event_fd`
  读到的正是 fd → 测试通过。**两边都错，但错得互补。**

这也解释了为什么 `test_std_async_event` 一直能在改后通过：它的事件数组是
`calloc` 出来的宿主 packed 缓冲，读取走的是原生旁路，不经过 8 字节步长的 apply。

#### 修法

新增 `exec_vm_unpack_epoll_events`：对 `epoll_wait(232)` / `epoll_pwait(281)`
在返回 `n > 0` 时，按 packed 记录把 `events` / `data_lo` / `data_hi` 逐个
写回出参聚合（同时支持单个 `EpollEvent` 和 `EpollEvent` 数组），不再依赖
通用 apply 的 8 字节步长。

#### 结果

- `test_epoll_server`：8/8，`失败: 0`（改前 2/8）
- `test_epoll_syscall`、`test_std_async_event`、`test_std_async_event_fd_reuse`：
  `失败: 0`
- parity（本题修复前、含第 387 轮 epoll_ctl 修复）：914 例 / 一致 **850** /
  不一致 64（原 849/65）。

提交 `3d998497`。

#### 教训

「改前能过、改后不过」不等于改后错了 —— 要先确认改前的通过是不是**假通过**。
判定方法：把两个版本在同一位置的中间值打出来对比（本轮是 apply 读到的
`buffer[0..2]`），看差异出现在哪个字节偏移上，再回内核 ABI 对齐。

### 第 390 轮：全量门禁复测

两处 epoll 修复（第 387 轮 epoll_ctl packed 打包、第 389 轮 epoll_wait packed
解包）合并后的三件门禁：

| 门禁 | 本轮 | 上轮基线 |
| --- | --- | --- |
| `make check` | 1191 通过 / 失败 0 / rc=0 | 1191 / 0 |
| `make exec-parity` | 914 例 / 一致 **851** / 不一致 63 | 914 / 849 / 65 |
| `make exec-census` | **857/907（94.5%）** / 失败 50 / 跳过 7 | 855/907（94.3%）/ 52 |

parity 的 +2 就是 `test_std_async_event` 与 `test_epoll_server`（外加
`test_std_async_event_fd_reuse`）从「不一致」变「一致」；普查 -2 对应同一批。

异步/事件族 117 例专项复测：90 例通过，27 例失败**全部落在改前基线内**
（逐例比对 `tests/exec_vm_census.tsv`），零新增回归。

#### 仍不通过的三类（模型级缺口，非本轮可收口）

- async 帧布局 / `@await` 语义：约 20 例（`@await 操作数不是 Future 或始终
  Pending`、`LOAD_UNION_TAG 目标不是 union` 等）。
- 线程与 `clone`/`pthread`：解释器与编译器共用进程，无法提供并发语义。
- `@c_import`（3 例，明确不支持）、`cleanup scope 嵌套过深`、超长函数。

T11 的三条收口项因此仍保持未勾选状态；`make check` 一项持续为绿。

### 第 391 轮：`test_typed_pipeline_executor_single` 的悬垂引用取证

该例报 `LOAD_FIELD 字段越界(idx=0 kind=14 count=-1 pointee=16)`
（C99 侧通过），位置在 `lib/libc/signal.uya:425` 的 `sigismember`。

用临时打印追踪 `exec_vm_field_object` 的解引用链，最后一段是：

```
FOBJ d=0 kind=14 i64=139727701718664 aux=65552   # 指针，ref-kind=STRUCT
FOBJ d=1 kind=0  i64=0          aux=0            # 目标槽 kind=VOID
```

`aux=65552` = `EXEC_VM_REF_KIND_BASE + 16`，说明这是一个**合法的内部引用编码**，
但解出来的目标 `ExecValue` 的 `kind` 是 `VOID` —— 该槽从未被写过（或所属帧已弹出，
槽位被回收）。于是 `set == null` 判不出来，`set.val` 直接撞上 `LOAD_FIELD` 越界。

#### 已排除

写了最小用例（`var s: sigset_t = sigset_t {}` 依次 `sigemptyset` / `sigaddset` /
`sigismember`）在 exec 后端**通过**，所以不是「extern libc + `&struct` 传参」
本身的问题，而是**指向局部聚合的引用活得比帧久**。

#### 结论与后续方向

这是跨帧逃逸（悬垂引用）问题，和 async 帧布局属同一类模型缺口，改动面大。
本轮只做定位，不动代码；后续若要把这条收口，需要先找到「取局部地址后存进
更长生命周期的容器」的具体路径，再决定是延长帧寿命还是让槽位回收时把
仍被引用的槽降级为「已移动」哨兵并按需报错。

### 第 392 轮：原生聚合旁路表按需增长（每基址 512 元素上限）

#### 症状

`test_async_event_dynamic_growth` 在 `tests/test_async_event_dynamic_growth.uya:132`
报 `exec: 当前不支持该指针元素类型`。

#### 定位

5 个报错点先加站点编号，确认命中第 4 处（`exec_vm_store_pointer_index` 的
原生结构体数组分支）。再打印现场：

```
PSTDBG pkind=16 hint=68 src=16 base=140197684404288 used=2
```

`used=2` 说明 256 条基址表**没满**，`pkind=16`（STRUCT）、`hint=68`（元素字节数）
都正常。真正卡住的是 `exec_vm_native_agg_slot` 里的第二个上限：
旁路表每条基址是静态 `[ExecValue: 512]`，而这个用例往同一个原生数组里写
**1025 个 Waker**，`index=1024` 直接撞越界，于是走到「不支持」分支。

#### 修法

- 旁路表元素存储从静态 `[[ExecValue: 512]: 256]` 改成
  `[&ExecValue: 256]` + 每基址容量表，首次使用时从 arena 分配，按需倍增扩容
  （`exec_vm_native_agg_ensure`），上界提到 65536。
- 扩容时新槽位先 `memset` 清零：不然未初始化字节被当成 ExecValue 解出来就是
  随机 `kind`。
- `exec_vm_native_agg_slot` / `exec_vm_native_agg_peek` / `exec_vm_native_agg_migrate`
  统一走 storage 指针；驻留判定里删掉已不存在的静态表范围（arena 分配天然驻留）。

#### 结果

- `test_async_event_dynamic_growth`：失败 → **通过**。
- 相邻用例全绿：`test_std_async_event`、`test_std_async_event_fd_reuse`、
  `test_epoll_server`、`test_epoll_syscall`、`test_protobuf_dynamic`、
  `test_std_mem`、`test_array_pointer_access`、`test_struct_default`。

提交 `c8e3e21e`。普查通过数预期 857 → 858。

#### 备注

顺手确认了另一件事：`@frame(...)` 的 `start` / `poll` / `stop` 在 VM 侧**完全没有
落地**（C99 侧由 `c99_async_frame_helper_name` 合成 `<fn>_poll` 等 static helper，
`src/exec/builder.uya` 与 `src/exec/*.uya` 里搜不到任何对应实现）。所以
`test_async_frame_methods` 里 `frame.poll(&w)` 拿到的是 VOID，
`test_async_await` 等 8 例的 `@await 操作数不是 Future` 也在这条线上。
这是功能级缺口，需要单独一轮做，不适合和本轮的旁路表改动混在一起。

### 第 393 轮：`@frame` 帧方法缺口的取证（未实现，仅结论）

`test_async_frame_methods` 与 `test_std_mqtt_async` 都报
`LOAD_UNION_TAG 目标不是 union`，共同根因在 `frame.poll(&w)` 返回的不是
`Poll<T>`。追到 `src/exec/lower.uya:8845`：

```uya
// `@frame(fn)` 的合成帧在 VM 里已经同步执行完：`stop()` 这类帧控制方法
// 没有 AST 声明，按空操作处理（返回 void 零值）。
if owner_type.kind == TYPE_STRUCT && prefix == "uya_async_" { return zero_void; }
```

`start` / `poll` / `stop` **一律降级成 void 空操作**，所以 `poll` 拿到 VOID。

本轮尝试了「`start` 直接调 async 函数并把 `Future` 写回帧本体、`poll` 取字段 0」
的实现，编译通过但测试仍失败。取证打印说明这个模型不成立：

```
FRAMESTART name=frame_method_child
FRAMEPOLL typekind=13
LDPK srckind=16 dstkind=1 dsti64=11     # 帧确实是 STRUCT，但字段 0 是 i32=11
UTAG2 kind=1 i64=11
```

`srckind=16` 说明 VM 里的帧**不是空结构体**，它带着真实布局，字段 0 是
`i32` 的步进/状态计数器（11）。也就是说 C99 侧合成的 `uya_async_*` 状态机
结构在 VM 里已经有一份字段布局，`poll` 不能简单取字段 0 了事 —— 要复刻
「按步进计数器跳转、跨 `@await` 保存/恢复局部变量」的整套状态机。

结论：这是**功能级缺口**（需要在 VM 侧实现帧状态机），不是几行能补的 bug。
本轮已把实验性改动整体回退（`git checkout HEAD -- src/exec/lower.uya src/exec/vm.uya`），
工作树干净；相关 2 例保持失败，等后续专门一轮处理。

`@await` 家族（8 例，`@await 操作数不是 Future 或始终 Pending`）属于同一根因链：
`exec_vm_await_poll_interface` 需要 `poll` 返回 `Poll` 联合值，而帧 `poll` 现在给
VOID。另有部分是同步执行模型无法表达 `Pending`（VM 里 async 函数必须一次跑完）。

### 第 394 轮：第 392 轮修复后的门禁复核

| 门禁 | 本轮 | 上一轮 |
| --- | --- | --- |
| `make exec-census` | **858/907（94.6%）** / 失败 49 / 跳过 7 | 857/94.5% / 50 |
| `make exec-parity` | 914 例 / 一致 **852** / 不一致 62 | 851 / 63 |
| `make check` | **1191 通过 / 失败 0 / rc=0** | 1191 / 0 |

两处 +1 都来自 `test_async_event_dynamic_growth`（原生聚合旁路表按需增长）。

#### 失败构成（49 例）

- `@await` / async 帧语义：约 14 例（含 `@frame` 帧方法缺口，见第 393 轮）
- 线程 / `pthread` / `clone`：6 例（解释器与编译器共用进程，无并发语义）
- 纯算法超时（解释器比 C99 慢两个数量级）：`test_tls_x25519_pure`、
  `test_tls_ecdsa`、`test_tls_rsa` 等 5 例
- `@c_import`：3 例（明确不支持）
- `fork`/`execve` 型（`test_kernel_sim`、`test_osal`、pipeline facade）：3 例
- 悬垂引用（第 391 轮）：`test_typed_pipeline_executor_single`、`test_typed_pipeline_capability`
- 其余零散运行时错误

这些都是模型级/工程级缺口，不是「再修几个小 bug」能收口的量级。

### 第 395 轮：门禁假失败的环境归因

#### 现象

第 394 轮 parity 记了「一致 852 / 不一致 62」，但抽查其中 9 例单独复跑**全部通过**：

```
test_embed_builtin          rc=0 失败: 0
test_libc_stdio_new         rc=0 失败: 0
test_std_sql                rc=0 失败: 0
test_macro_mc_type_auto     rc=0 失败: 0
test_std_jpeg_decode        rc=0 失败: 0
test_std_jpeg_encode        rc=0 失败: 0
test_exec_vm_globals        rc=0 失败: 0
test_ffi_cast               rc=0 失败: 0
test_extern_union           rc=0 失败: 0
```

这些用例在 parity 结果文件里是 `C99=0 VM=1` 且**两边摘要都是 `-`**（完全没有
stdout）—— 正常跑完至少会打印 `总计/通过/失败` 三行。也就是说 `uya test`
根本没跑起来，而不是测试断言失败。

#### 排查过的（都不是原因）

- **临时路径撞车**：`host_fill_temp_path` 生成 `$TMPDIR/uya_out_<pid><后缀>`，
  带 PID，不会撞。
- **分裂 C 缓存 `.uyacache` 并发写**：该目录最近 90 分钟无任何修改，`uya test`
  并不使用它（那是 `make uya` 的产物）。
- **并发本身**：6 个不同用例并发跑 3 轮，全部 `rc=0 失败: 0`，不抖。

#### 真正原因：机器内存被别的会话占着

普查 78/914 时 `free -g` 是 **used 51G / available 10G**。查下来是另一个会话
起的 ComfyUI 服务：

```
python main.py --listen 127.0.0.1 --port 8188 --lowvram ...     RSS 41998824 KB ≈ 41G
```

`uya test` 的 C99 路径要调 gcc，内存不够时进程起不来 → `rc=1`、stdout 全空，
正是前面看到的形态。第 388 轮记的「parity 固定 6 路、内存 9G/53G 可用」是在
没有这个负载的前提下成立的，现在不成立。

#### 结论与纪律

- **parity / 普查的读数必须连同 `free -g` 一起看**；`available < 15G` 时读数不可信。
- 出现「`rc=1` 且两边都没有 stdout」的行，先单独复跑再计入不一致，不要直接写进文档。
- 怀疑假失败时，用「同一用例并发 6 份 × 3 轮」验证稳定性，比反复全量跑便宜得多。

### 第 396 轮：指针下标解引用加地址范围守卫（修 SIGSEGV）

#### 症状与取证

`test_http_uyagin` 在 VM 下 `rc=139`，停在
`TEST: uyagin_handle_releases_all_async_frames`。用 gdb 取现场：

```
Program received signal SIGSEGV
#0 exec_vm_load_pointer_index
$1 = (void *) 0xfffffffffffffff1      # si_addr = -15
```

#### 根因

`exec_vm_pointer_address` 对**任何 kind** 都直接返回 `i64_value`。一旦上层把
非指针值（或已释放/未初始化的句柄）传进下标路径，算出的「地址」就是
`0xfffffffffffffff1` 这种非用户态值，`@ptr_from_usize(addr)` 之后一解引用就崩。
另外 load/store 两条路径的 `base + index * elem` 用的是普通乘加，usize 溢出会回绕。

#### 修法

- 新增 `exec_vm_check_deref_addr`：地址超出用户态上限
  （`>= 0x0000800000000000`）或落进空页保护（`< 4096`）时，报
  `exec: 指针下标解引用地址非法(addr=… idx=… base=… kind=…)` 并返回 -1。
- load / store 两条下标路径的地址计算改成 `+|` / `*|` 饱和运算。

修后同一用例不再崩，给出可定位的诊断：

```
exec runtime: ./lib/std/async.uya:118:8:
  exec: 指针下标解引用地址非法(addr=0xfffffff1 idx=0 base=-15 kind=14)
```

#### 上游问题（留待后续）

`lib/std/async.uya:118` 是 `async_box_free_current` 里的 `*alloc_ref`：它从
box 头里读出的 allocator 地址是 `-15`，说明**释放了一个不是本分配器给出的指针**
（box 头被覆盖，或重复释放）。这是分配器契约问题，不是地址计算问题；
本轮只保证解释器不再段错误。

#### 回归

指针密集用例全绿：`test_array_pointer_access`、`test_std_mem`、
`test_struct_default`、`test_epoll_server`、`test_epoll_syscall`、
`test_protobuf_dynamic`、`test_std_async_event(_fd_reuse)`、`test_std_io`、
`test_tls_x509`、`test_math`、`test_std_sql`。`make check` 1191 通过 / 失败 0。

提交 `fa543eff`。

### 第 397 轮：parity 不一致的方向拆分

「62 例不一致」这个数字不区分方向，容易误读。按方向拆开：

| 方向 | 例数 | 含义 |
| --- | --- | --- |
| C99 失败 / VM 通过 | **9** | `test_exec_vm_*`、`test_ffi_cast`、`test_extern_union`、`test_syscall_process`、`test_tflm_*` 等；VM 专属夹具或 C99 侧本来就未接的路径 |
| C99 通过 / VM 失败 | **52** | 真实缺口，集中在 async / `@frame` / 线程 / `@c_import` / 纯算法超时 |
| 两边都失败 | **1** | `test_abi_calling_convention`（C99 侧也链接失败，属夹具问题） |

所以「要收口的 VM 缺口」实际是 **52 例**，不是 62。要「全绿」还得把 C99 侧那 9 例
也修掉（或按设计把它们登记成跳过）—— 这是两件不同的事，别混在一起看。

顺带把第 395 轮的假失败复查了一遍：本轮 parity 在内存更充裕时重跑，
`test_embed_builtin`、`test_libc_stdio_new`、`test_std_sql`、`test_macro_mc_type_auto`、
`test_std_jpeg_*` 这些「上一轮不一致、单独跑却全绿」的用例已经不再出现在不一致
清单里，印证了第 395 轮的结论（内存压力导致的假失败），也说明这 62 例是真实读数。

`test_http_uyagin` 本轮从 `rc=139`（段错误）变成 `rc=1`（可诊断错误），
普查口径仍记为失败 —— 段错误消除不等于用例通过。

#### 另一侧的一个发现

`test_mem` 在 C99 侧 `rc=139`（段错误），VM 侧通过。这是 C99 后端的崩溃，
不在本计划范围内，但值得单独记一笔，避免以后误以为是 VM 回归。

### 第 398 轮：地址守卫后的门禁复核 + 普查内存参数纪律

#### 门禁结果（`fa543eff` 之后）

| 门禁 | 结果 | 与上一轮比 |
| --- | --- | --- |
| `make check` | **1191 通过 / 失败 0 / rc=0** | 持平 |
| `make exec-parity` | 914 例 / 一致 **852** / 不一致 62 | 持平（守卫只把崩溃改成报错，不改通过性） |
| `make exec-census` | **858/907（94.6%）** / 失败 49 / 跳过 7 | 持平 |

`test_http_uyagin` 从 `rc=139` 变成 `rc=1`，覆盖率口径不变 —— 这是预期结果：
段错误消除不等于用例通过。

#### 普查参数纪律（本轮踩的坑）

普查默认 `UYA_EXEC_CENSUS_JOBS = CPU 核数`（本机 44）。机器上另有会话占着约 40G
内存时，44 路并行直接把可用内存压到 4G，很危险。改 `UYA_EXEC_CENSUS_JOBS=3`
后稳定在「可用 14G」。

但**不要顺手给 `UYA_EXEC_CENSUS_MEM_MB` 设小值**：设成 1536 时普查报
`失败 65 / 92.8%`，多出来的 16 例是地址空间不够导致的假失败，不是回归。
抽查 `test_http_uyagin_recover_observe` 单独跑（不设上限）是 `失败: 0`。

结论：
- 限并行度：`UYA_EXEC_CENSUS_JOBS=3`（有外部负载时 2~3 路）。
- 不设内存上限：`UYA_EXEC_CENSUS_MEM_MB=0`。
- 看到通过率突然掉 2~3 个百分点且失败项分散在 TLS/crypto/大缓冲用例上，
  先怀疑内存上限，不要当成回归去查。

### 第 399 轮：`@await` Pending 传播——方案证否

#### 为什么试

`test_async_await`、`test_std_dns`、`test_http_websocket_*`、`test_http_uyagin` 等
十几例都停在同一条错误上：

```
exec: @await 操作数不是 Future 或始终 Pending
```

如果能让 Pending「向上传播」，这一簇看起来能一起收口，所以值得试。

#### 做了什么

在 `BC_AWAIT` 里加了 `exec_vm_propagate_pending`：命中 Pending 时，按当前函数的
返回类型造一个 `Future{ state: Pending }`（`exec_make_struct(1)` +
`exec_make_union(0, void)`）并直接 `return 1` 从当前帧返回，靠外层再 `@await`
层层传播。

过程中确认了两个事实（都有价值）：

1. `Future<T>` 在 `std.async` 里是 **interface**（`TypeKind.TYPE_INTERFACE` = 15），
   不是 struct；同名还有一个占位 `struct Future<T>`。VM 里 `function.return_type.kind`
   拿到的是 15。
2. `TypeKind.TYPE_STRUCT` 的序号是 **16**（`TYPE_INTERFACE`=15），文档里早期记的
   「STRUCT=15」是错的。

#### 为什么证否

传播确实生效了（错误从「始终 Pending」变成后面一步），但紧接着报：

```
exec: LOAD_FIELD 字段越界(idx=2 kind=16 count=1 pointee=-1)
```

原因是 async 函数的返回值在**调用侧会做一次接口装箱**：`Future<T>` 是 interface，
`const f: Future<!i32> = some_async_fn();` 要把返回的结构体装成
`{ poll_fn, drop_fn, 数据指针 }` 的箱子，装箱要读源值的第 0/1/2 个字段。而正常的
`@async_fn` 返回语句在**降级阶段**就已经被 `exec_lower_wrap_async_return` 包成了
`Future{state: Poll.Ready(x)}` 并完成装箱；从 `BC_AWAIT` 里直接 `return 1` 绕过的是
降级阶段的包装，于是调用侧拿到一个 1 字段结构体，装箱时读第 2 个字段就越界。

要正确装箱，必须知道 `Future<T>` 的 poll 方法函数号 —— 那是 **C99 侧
`c99_async_frame_helper_name` 合成的 `<fn>_poll`**，VM 的 builder 根本不生成。
这和 `@frame` 状态机是同一堵墙，不是「补几十行」的量级。

实测这一簇在改动后**零新增通过**（`test_async_fd`、`test_async_compound_try_await`、
`test_async_compute_types`、`test_async_macro_expand`、`test_async_frame_pool_stats`、
`test_http_websocket_json` 全是 `失败: 1`），所以整体回退
（`git checkout HEAD -- src/exec/vm.uya`），只保留第 396 轮的地址守卫。

#### 结论

`@await` 的 Pending 语义**不**是「在 VM 里造个 Pending 值」就能解决的，
前置条件是在 VM 侧实现 async 帧的 poll 函数（与 `@frame` 同一工程）。
这条结论把 T11 里「async 约 40 例」的根因钉死在一处，以后不要再按「传播 Pending」
的方向试。

### 第 400 轮：`@await` Pending 穿透（`test_async_await` 转绿）

第 399 轮证否的是「造一个 `Future{Pending}` 再返回」——卡在调用侧的接口装箱。
这一轮换成**穿透**：不去造新值，而是把**被 await 的那个 Future 原样**当作当前
函数的返回值。

#### 为什么这是对的

Pending 变体没有载荷。所以

```
Future<!i32>{ state: Pending }        // 外层
Future<!usize>{ state: Pending }      // 内层
```

在运行期完全同形：一个 box（或一个 `{state}` 结构体），`state` 是 `Poll.Pending`。
把内层原样交出去，调用方再 poll 仍然得到 Pending —— 与 C99 状态机「本轮推不动、
下次再 poll」的可观测结果一致。而 VM 本来就没有调度器，内层不可能在之后变成
Ready 又回头驱动外层，所以「外层未来被折叠成内层」不会丢掉任何可观测行为。

#### 改动

- 新增 `exec_vm_await_pass_through_pending`：只在当前函数返回 Future
  （`TYPE_INTERFACE` / `TYPE_STRUCT`）时生效，其它返回类型保持原报错。
- `exec_vm_await_poll_interface` 忙等超时改为返回 **1**（始终 Pending），
  与 **-1**（根本不是 Future）区分开，`BC_AWAIT` 据此决定穿透还是报错。
- `BC_AWAIT` 不再覆盖内层错误。之前 poll 调用失败一律显示
  `@await 操作数不是 Future`，把真正的根因（如 `LOAD_INDEX 越界`）盖掉了；
  现在保留内层信息，只剩这一处改动就已经值回票价（见下）。

#### 结果

- `test_async_await` 由失败转通过：「await 一个永远 Pending 的 future，
  外层 poll 应当是 Pending」这条终于对了。
- async 全家族 28 例逐例复核：原本通过的**全部仍然通过**，零回归。
- `make check` **1191 通过 / 失败 0**。

#### 顺带暴露的真问题

保留内层错误后，`test_std_dns` / `test_async_fd` 的真实失败点露出来了：

```
lib/std/async.uya:294:5: exec: LOAD_INDEX 越界
```

`_set_primary_io_slot` 里 `self._io_slot_fds[index]` 越界。原因是
`exec_vm_await_poll_interface` 传进去的 waker 是**伪造的占位聚合**
（`EXEC_AWAIT_WAKER_FIELDS` 个 void 字段），poll 方法里 `w.add_interest(...)`
一写数组就炸。也就是说这两例缺的不是 `@await` 语义，而是**一个能真正记账的
Waker**：`_io_slot_fds` / `_io_slot_interests` / `_io_slot_count` 得有真实布局
和语义。这属于异步运行时（事件循环 + waker 注册）的一部分，不是补几行能解决的。

### 第 401 轮：门禁复测（含第 400 轮 Pending 穿透）

| 门禁 | 第 398 轮 | 第 401 轮 | 变化 |
| --- | --- | --- | --- |
| `make check` | 1191 / 0 | **1191 / 0** | 持平 |
| `make exec-parity` 一致 | 852 | **853** | +1 |
| 不一致 | 62 | **61** | −1 |
| `make exec-census` 通过 | 858（94.6%） | **859（94.7%）** | +1 |
| 普查失败 | 49 | **48** | −1 |
| 普查跳过 | 7 | 7 | 持平 |

净增的一例就是 `test_async_await`，其余用例逐项比对零变化 —— 说明第 400 轮的
改动是**定点**的，没有顺带改变别的用例的行为。

按方向拆分同步更新：VM 领先 C99 的 9 例、VM 落后 51 例、两边都失败 1 例。

跑法沿用第 398 轮的纪律：parity `UYA_PARITY_JOBS=4`、普查
`UYA_EXEC_CENSUS_JOBS=3 UYA_EXEC_CENSUS_MEM_MB=0`（**不要**设小内存上限，
那会造出 16 例假失败）。

### 第 402 轮：`test_typed_pipeline_lowering_error` 根因定位

这一例 4 个子测试过 2 个、挂 2 个：

```
TEST: pipeline_error_path_cleans_input      ... pipeline_drop_count() == 1 (actual 0)
TEST: pipeline_sink_failure_consumes_input  ... pipeline_drop_count() == 1 (actual 0)
TEST: pipeline_success_path_does_not_clean  ... OK
TEST: pipeline_unconsumed_scope_auto_drop   ... OK
```

「作用域退出自动 drop」是好的（第 4 个子测试过），坏的是**错误路径**上的 drop。
对比两个后端，根因很干脆：

- **C99 侧**：`src/codegen/c99/expr.uya:795` 的
  `gen_pipeline_emit_input_cleanup` 专门在 transformer 返回 `!Pipeline` 失败时
  发出 `std.process.pipeline_drop(<输入>)`。
- **VM 侧**：`src/exec/lower.uya:7804` 的 `exec_lower_desugar_pipeline` 只把
  `a |> f(b)` 改写成 `f(a, b)`，**没有**任何错误路径的清理合成。

所以这不是「drop 语义整体缺失」，而是**一处具体的降级缺口**：pipeline 的
错误路径清理是 C99 codegen 里的手工合成，VM 的 desugar 没有对应物。

#### 为什么这轮没有直接修

要修得在 desugar 里造出带语句的 AST：

```
tmp = <stage 调用>
if <tmp 是错误> { pipeline_drop(<输入>); return <tmp>; }
```

`exec_lower_desugar_pipeline` 是**纯表达式改写**（只重排 `AST_CALL_EXPR` 的参数），
要引入临时变量和条件返回，就得改成语句级合成，并保证输入表达式只求值一次
（否则 `pipeline() |> f()` 会被求值两次）。这是一次有明确边界的改造，但会碰到
pipeline 的所有用例，风险不小，不在这一轮顺手做。

顺带纠正一处早先的分类：T11 里把这类记成「`cleanup scope` 嵌套过深」，不准确 ——
至少这 2 个子测试是 **pipeline 错误路径清理未合成**，与作用域嵌套无关。

### 第 403 轮：48 个普查失败的全量归因台账

这一步的目的：**不留任何「还没查过」的失败**。48 例逐个点到具体的墙，
以后谁接手都可以直接从对应的小节读起，不必重新排查。

| 组 | 例数 | 说明 |
| --- | --- | --- |
| A. async 帧 / `@await` / waker / 调度器 | **25** | 见下方名单 |
| B. pipeline 错误路径清理 / drop / 悬垂引用 | **4** | 第 402 轮定位 |
| C. 宿主导回调 / 线程并发 | **13** | 无 host→bytecode 蹦床 |
| D. `@c_import` 明确不支持 | **3** | 有意的 reason code `c_import` |
| E. 纯算法慢（超时） | **3** | 性能问题，非语义 |

合计 25 + 4 + 13 + 3 + 3 = **48**，与普查失败数一致。

**A（25）**：`test_async_fd`、`test_async_frame_methods`、`test_async_frame_pool_full`、
`test_async_frame_pool_stats`、`test_async_macro_expand`、
`test_async_nested_http1_await_codegen`、`test_async_state_machine`、
`test_async_compound_try_await`、`test_async_multi_fd_concurrent`、
`test_async_runtime_shared_dns`、`test_async_runtime_shared_semantics`、
`test_async_shared_runtime_semantics`、`test_async_task_queue_dynamic_growth`、
`test_http1_async_client`、`test_http_uyagin_websocket`、
`test_http_uyagin_async_boundary`、`test_http_websocket_json`、
`test_http_websocket_reconnect`、`test_std_dns`、`test_std_dns_async_query_aggregate`、
`test_std_dns_async_transport`、`test_std_mqtt_async`、
`test_std_script_pipeline_facade`、`test_tls_async_runtime_io`、
`test_std_async_scheduler`。

**B（4）**：`test_typed_pipeline_capability`、`test_typed_pipeline_executor_single`、
`test_typed_pipeline_lowering_error`、`test_http_uyagin`（`async_box_free_current`
读到的 allocator 头是 `-15`，即释放了不是本分配器给出的指针，第 396 轮取证）。

**C（13）**：`test_signal`、`test_osal`、`test_std_thread`、
`test_std_thread_async_boundary`、`test_kernel_sim`（x86 call gate 要调目标函数）、
`test_pthread_affinity`、`test_pthread_api_cancel`、`test_pthread_heap_cache_identity`、
`test_pthread_heap_concurrency`、`test_async_thread_pool_dynamic_growth`、
`test_async_compute_types`（`&double_i64 as &void` 交给线程池回调）、
`test_async_compute_dynamic_resource_pressure`、`test_async_compute_generic_wrapper`。

**D（3）**：`test_c_import_cflags`、`test_c_import_dir`、`test_c_import_file`
（报 `exec: 当前不支持 @c_import`）。

**E（3）**：`test_tls_ecdsa`、`test_tls_rsa`、`test_tls_x25519_pure`（>200s 超时）。

结论：普查口径下**没有未归因的失败**了。剩下的每一例都指向 A/B/C 三堵墙中的
一处，或纯性能。这也意味着 94.7% 之后的每一个百分点，都要以「实现一个子系统」
为单位来算，而不是修 bug。

### 第 404 轮：`&struct` 落在槽池里时没有字段视图（墙 B 的第三块）

`test_typed_pipeline_executor_single` 的失败点：

```
lib/libc/signal.uya:425:22: exec: LOAD_FIELD 字段越界(idx=0 kind=14 count=-1 pointee=16)
```

`kind=14` 是 POINTER，`pointee=16` 是 STRUCT，`count=-1` 说明
`exec_vm_aggregate_ref_from_value` 压根没拿到聚合视图。顺着读代码：

1. `exec_vm_aggregate_ref_from_value`（`src/exec/vm.uya:1771`）对**裸指针**指向聚合
   的分支是：pointee 尺寸为 0（struct/union 都返回 0，见 `exec_vm_type_kind_size`）
   时取 `exec_vm_native_agg_slot(addr, 0)`，再 `exec_value_as_aggregate` 那个元素。
2. 旁路表元素刚 memset 成 VOID，`exec_value_as_aggregate(VOID)` 返回 null ——
   于是整个函数返回 null，`LOAD_FIELD` 报「字段越界」。

也就是说：**裸指针指向的聚合本体在 VM 里没有字段视图**。旁路表存的是「元素」
（`&Token` 切片里一个元素就是一个 Token），而 `p.field` 要的是「Token 的字段」，
两者语义不同。要用旁路表表达，得先把这块内存解释成一个结构体值再落进元素 0，
而槽池里存的是 56 字节的 `ExecValue`，不是 C 布局 —— 这正是悬垂引用那一族的根。

结论：这**不是**「补个 count 检查」能修的，需要一套「指针 → 聚合视图」的物化机制
（把 `&struct` 指向的槽序列投影成 `ExecAggregate`）。同族的还有
`test_typed_pipeline_capability`（`idx=2 kind=0`：引用目标已经是 VOID 槽）。

#### 下一步的入口（给接手的人）

| 墙 | 第一站 | 说明 |
| --- | --- | --- |
| A async | `src/exec/vm.uya` 的 `BC_AWAIT` / `exec_vm_await_poll_interface`；`src/exec/lower.uya:8845` | 要先有 `<fn>_poll` 的字节码版本，再有能记账的 Waker |
| B drop / 指针聚合视图 | `src/exec/vm.uya:1762` `exec_vm_aggregate_ref_from_value`；`src/exec/lower.uya:7804` `exec_lower_desugar_pipeline` | 前者要「指针→聚合视图」物化；后者要语句级合成错误路径 drop |
| C 宿主回调 | 无 | VM 没有任何 host→bytecode 蹦床，需要新增一层 C thunk 表，且要处理信号处理器里重入 VM 的约束 |

### 第 405 轮：悬垂引用那一族的指针取证（挂在「地址不是宿主地址」上）

针对 `test_typed_pipeline_executor_single` 又做了一轮取证，结论比第 404 轮更硬。

#### 观测

在 `exec_vm_aggregate_ref_from_value` 的失败出口打点，拿到：

```
[vm] agg-null kind=14 iref=1 addr=0xc6c1d688 poi=16 storage=0
```

- `kind=14`：POINTER；
- `iref=1`：它**是**内部引用（引用编码是合法的，不是丢编码的裸指针）；
- `poi=16`：pointee 是 STRUCT，说明类型层面没错；
- `addr=0xc6c1d688`：**这不是宿主地址**（宿主 64 位程序的值 arena / 槽池地址都是
  `0x7f…` / `0x55…` 量级），而且 `storage=0` 说明它也不在任何 ExecValue 存储里；
- 在 `exec_vm_run_frame` 入口对**所有**指针参数加了「地址 < 4GiB 就报」的打点，
  跑同一用例**一条都没打** —— 说明这个坏地址不是从参数传进来的，是函数体里
  某个局部/字段值算出来的。

#### 结论

`exec_vm_ref_target_value` 拿这个地址去解码自然得到 null，于是 `set.val` 报
`LOAD_FIELD 字段越界(count=-1)`。也就是说：**内部引用的地址在某个环节被写成了
一个 32 位量级的非宿主值**。它既没经过参数口（已排除），也不在存储区里，
所以最可能是在某条 `STORE_LOCAL` / 字段写入路径上，把「引用编码」和「地址」
两个概念混用了 —— 例如把 `EXEC_VM_REF_KIND_*` 的编码值当成地址存进了
`i64_value`。

要定位还需要在「指针值写入槽位」处打点并回溯写入者，这一轮没有继续往下钻
（单测收益只有 2~3 例，而打点+重编一轮三分钟起步）。这里把线索固化下来：
**下一步直接从 `0xc6c1d688` 这个值反查是谁写进去的**，比从头猜快得多
（建议做法：在 `exec_vm_store_slot_shallow` 里判断「POINTER 且 iref=1 且
地址不在 VM 驻留区」时打印 `function.name` + `instr`，一轮就能锁定写入指令）。

同族的 `test_typed_pipeline_capability` 报 `idx=2 kind=0`（槽值已经是 VOID），
`test_http_uyagin` 报 `base=-15`，大致都是「引用/地址语义被写坏」的不同表现。

#### 补充：反查写入者的一次尝试（第 405 轮续）

按上面的建议在指令派发循环末尾加了打点：只要某条指令的**目标槽**变成
「POINTER + 内部引用 + 地址不在 VM 驻留区且小于 4GiB」就打印
`function.name / ip / opcode / instr.a,b,c`。

结果：跑 `test_typed_pipeline_executor_single`，**一条都没打**
（把条件放宽到 `iref` 不限时，只打出 `pipeline_broker_install_handler`
里几个 `iref=0` 的裸指针，比如 `addr=0x400000d6 poi=13`）。

这说明那个坏引用**不是**任何指令写进 `slot_a` 的。可能性收敛到两种：

1. 它是从**内存里读出来**的（例如某个聚合字段本来就没写过，读到的是旧值）；
2. 它来自 `slot_a` 之外的写入口（参数槽、`slot_b`/`slot_c` 写回、或旁路表迁移）。

下一轮的正确做法：在 `BC_LOAD_FIELD` 失败时打印 `function.name` / `frame.ip` /
`instr.b`（拿到确切的槽号），再对该函数做一次字节码反汇编，看谁写过这个槽 ——
比继续在派发末尾撒网有效。

另一个值得注意的现象是：放宽条件后看到的 `addr=0x400000d6` 正好也是 32 位量级，
形态和 `0xc6c1d688` 同类。如果这两者同源，那就是「某条路径把宿主指针截成 32 位」
而不是「读到了垃圾」，可以在 `exec_make_pointer_with_kind` 入口加宽度断言一次性确认
（该函数是 value.uya 里的单点，所有指针都从这里造出来）。

#### 决定性判据：`0xc6c1d688` 从来没被「造」出来过

在**所有指针的唯一制造点** `exec_make_pointer_with_kind`（`src/exec/value.uya:308`）
入口加了宽度断言：`addr != 0 && addr < 4GiB` 就打一行。跑
`test_typed_pipeline_executor_single`，打出来的是：

```
8 次  addr=0x1          poi=13
3 次  addr=0x400000d6   poi=13
2 次  addr=0x400000d6   poi=0
```

**`0xc6c1d688` 一次都没出现**。结合上一条「目标槽打点也没命中」，结论就定死了：

> 那个坏的内部引用不是被任何代码**创建**出来的，而是从内存里**读出来的**一块
> 残留字节 —— 它的 kind / aux 恰好还留着上一次真引用的形状（`aux >= 65536`
> 所以被判成「内部引用」），但地址指向的竞技场内存已经被回收/复用了。

这就是「悬垂引用」这个名字背后的真实机制：**内部引用（指向 VM 值本体的地址）
被存进了活得更久的地方**（结构体字段、原生聚合旁路表、或某块原生缓冲区），
等引用目标所在的值 arena 被回收后，这块内存被复用成别的东西，残留的
kind/aux 让读方仍然把它当合法引用。

顺带注意 `0x400000d6`：它**是**被真的创建出来的（poi=13/0），形态同样是
32 位量级。值 `0x40000000 + 0xd6` 很像某种编码而不是地址，值得单独确认它到底
该不该出现在 `i64_value` 里 —— 如果它是错的，那这一族里还有第二个独立缺陷。

#### 结论与下一步

- 已知：错误在「引用逃逸 + 竞技场回收」这一对组合上，不在指针算术、不在参数传递。
- 下一步的正确切入点：给 `exec_value_alloc_bytes` 的**回收**路径加登记，配合
  `exec_vm_make_value_ref` 的调用点检查「引用是否被存进了非 VM 值的容器」。
  这是内存所有权层面的问题，修法是「让内部引用不逃逸」或「引用目标不被回收」，
  二者都不是局部补丁。

#### 陷阱记录：`exec_vm_fn_ref_index` 不能用来判别「这是不是函数引用」

顺着上面 `0x400000d6` 的线索想给「函数引用被当地址解引用」加一道守卫，
于是用了现成的 `exec_vm_fn_ref_index(value) >= 0`。**结果误伤三个本来通过的用例**：

```
test_struct_default   -> 失败: 1      （改前 失败: 0）
test_epoll_server     -> 失败: 1      （改前 失败: 0）
test_std_async_event  -> 失败: 1      （改前 失败: 0）
```

原因很直白：`exec_vm_fn_ref_index` 只判**下界**

```uya
if value.i64_value < EXEC_VM_FN_REF_BASE { return -1; }   // BASE = 0x40000000
return (value.i64_value - EXEC_VM_FN_REF_BASE) as i32;
```

而 64 位进程里**真实堆地址普遍大于 `0x40000000`**（本机值 arena 在 `0x7f…`、
堆在 `0x55…`），所以任何正常指针都会被判成「函数引用下标 = 十几亿」。
用这个判据做的守卫必然把合法指针全拦掉。

立即回退（`git checkout HEAD -- src/exec/vm.uya`），三例恢复 `失败: 0`。

结论：`&fn` 的哨兵编码 `EXEC_FN_REF_BASE + index` 与真实地址**在取值空间上重叠**，
仅凭 `i64_value` 无法区分。要判别只能在**产生/消费的具体上下文**里做
（例如 `@fn_ref` 的 HIR 节点、或 `CALL_INDIRECT` 的槽位），不能事后看数值。
这也解释了为什么 `0x400000d6` 既可能是合法函数引用、也可能是被截断的地址 ——
在没有上下文信息前不要对它下判断。

### 第 406 轮：用指令跟踪把悬垂引用钉到具体指令（仍未修，但已可复现到行）

给 `LOAD_FIELD` 的越界错误补上 `fn= / ip= / slot=`（提交 `cbabf264`），立刻拿到：

```
exec: LOAD_FIELD 字段越界(idx=0 kind=14 count=-1 pointee=16 fn=sigismember ip=20 slot=2)
```

配 `--dump-bytecode` 直接看 `fn[191] sigismember` 的字节码：

```
 0: BC_LOAD_LOCAL a=2 b=0      ; slot2 = slot0（就是参数 set）
 ...
19: BC_LOAD_LOCAL a=2 b=0      ; 再次把 set 拷进 slot2
20: BC_LOAD_FIELD a=3 b=2 imm=… ; set.val  ← 炸在这里
```

**slot 2 是从参数 slot 0 拷过来的**，所以坏值就是形参 `set` 本身；在
`sigismember` 的 0..19 号指令里没有任何一条写 slot 0。换成 `--trace-vm` 再看调用链，
失败前最后的进入顺序是：

```
enter fn=sigemptyset → sigaddset → sigpending → sys_write → sigpending
     → pipeline_errno_value → pipeline_errno_location → sigismember args=2
```

（`--trace-vm` 没有配对的 exit 事件，这个序列不能直接当栈用，但能说明失败发生在
`lib/std/process.uya` 的 errno/pipeline 那段路径上。）

#### 已经排除的可能

| 假设 | 排除依据 |
| --- | --- |
| 槽位残留（上一帧的值） | 在 `exec_vm_slot_pool_push` 里整段 memset 清零后**错误完全不变**，已回退 |
| 指针是在 `exec_make_pointer_with_kind` 里被截断的 | 在该函数入口打点，`0xc6c1d688` **一次都没出现过** |
| 坏值是某条指令写进目标槽的 | 在派发末尾对所有目标槽打点，没有命中 |
| 坏值是从参数传进来的 | 在 `exec_vm_run_frame` 入口对指针参数打点，没有命中 |

四条都排掉之后，剩下的最可能解释是：**这个 ExecValue 不是「造」出来的，而是
按位读出来的** —— 例如 `exec_vm_native_field_load` 直接从原生内存读 8 字节当成
POINTER 值（它不经过任何 maker），而那块原生内存里存的确实是程序的某个 `u64`
（`sigset_t.val` 就是 u64）。

若成立，问题就变成「原生结构体的字段在 VM 侧被按错误的 kind 解释」，
而不是引用逃逸。下一轮应该直接从 `exec_vm_native_field_load` 的 kind 判定入手核对：
`sigset_t` 只有一个 `val: u64`，读出来必须是 U64，不可能是 POINTER。

#### 决定性一击：`sigismember` **入口**的实参就已经是高 32 位丢失的地址

在 `exec_vm_run_frame` 里对 `sigismember` 单独打点，进入时立刻打印实参和槽 0：

```
[sig] arg[0] kind=14 i64=0xbaf0c688 aux=65552 ptr=0xbaf0c688
[sig] arg[1] kind=1  i64=0xd        aux=0
[sig] slot0 kind=14 i64=0xbaf0c6f8  aux=65552
```

三点很关键：

1. **实参进函数时就已经坏了**（不是函数体里被写坏的）。
2. `aux=65552 = 65536 + 16`，是合法的「引用编码 + STRUCT」—— 说明这个值是走
   `exec_vm_make_value_ref` 一类路径造出来的，`kind/aux` 都正常，**只有地址丢了高 32 位**。
3. `arg[0] = 0xbaf0c688`，`slot0 = 0xbaf0c6f8`，两者相差 `0x70 = 2 × 56`（正好两个
   ExecValue）。**偏移是正确的，只有高位丢了** —— 也就是说这不是「算错地址」，
   而是「地址被存成了 32 位」。

而且每次运行低位都不同（前一次是 `0xc6c1d688`，这一次是 `0xbaf0c688`），
符合「真实地址 `0x7f…baf0c688` 被截断」的形态。

#### 由此得到的结论

- 排除「引用逃逸到已回收竞技场」：竞技场地址不会被截断，也不会每次变。
- 排除「槽位残留」「指针构造器」「目标槽写入」「参数入口未观察」四种假设（上一节）。
- 真因是：**某处把槽池/竞技场的宿主地址存进了 32 位容器**（`u32` / `i32` 字段或
  立即数），再读出来时高位为 0。地址偏移保持正确，所以后续字段访问只是「找不到
  存储区」而不是崩溃。

下一轮的正确切入点：查 `ExecValue.i64_value` 被赋值的所有路径里有没有经过 32 位
中转，特别是 `ADDR_LOCAL` / `ADDR_GLOBAL` / `MAKE_REF` 这几条引用构造指令的
**立即数与中转变量类型**（`instr.imm` 是 i64，但 `instr.c` 是 i32；如果地址被
塞进 `instr.c` 或某个 i32 局部，就会正好是这种「低位对、高位 0」的表现）。

#### 更正：结论要退回到「内存残留」，并把范围从槽池扩大到别处

带阳性对照的探针把上一节的推论推翻了一半。`exec_make_pointer_with_kind` 是**唯一**
的指针制造点（grep 全 `src/exec/` 只有一处定义，也没有任何裸写
`.kind = EXEC_VALUE_POINTER` 的地方）。给它加「前 5 次全打 + 之后只打小地址」的
探针，同时打印 `sigismember` 入口，一次运行得到：

```
[mk] addr=0x0        poi=10 n=0 … n=4     ← 5 次空指针
[mk] addr=0x400000d6 poi=0  n=5 n=6
[mk] addr=0x400000d6 poi=13 n=7 … n=10
[sig] arg0 kind=14 i64=0x74f35688 aux=65552
```

**整个运行里制造点只被调用了 11 次，而且从来没有产出过 `aux >= 65536` 的引用值。**
可是 `sigismember` 入口的 `arg0` 就是一个 `aux=65552`（引用编码 + STRUCT）的值。

结合 `0x74f35688` 这种形态（很像 `0x7f74f35688` 丢了高字节），结论只能是：

> 这个 ExecValue **不是本进程里「造」出来的**，而是从某块内存里**按位读回**来的
> 旧引用残留 —— 高位已经在这块内存里丢了。

所以上一节「排除内存残留」的说法要收回：当时只清了**槽池**，没清**竞技场和原生
聚合存储**。真正需要查的是这两处：
- `exec_value_arena_alloc` 复用的内存没有清零；
- `g_native_agg_storage` 里的元素跨帧/跨进程保留。

也就是说，`sigset_t` 这种「只有 1 个 `u64` 字段」的小结构，其对象存储被复用时，
前一次留在这里的 56 字节 ExecValue 会被当成本次的 `&sigset_t` 解引用 —— 恰好
`kind=14`、`aux=65552` 都还留着合法形状，只有地址坏了。

下一步（写成可执行的最小验证）：在 `exec_value_arena_alloc` 里对返回的字节做
`memset(0)`，重跑 `test_typed_pipeline_executor_single` —— 如果错误消失或形态改变，
就确认是竞技场残留，然后决定是「清零换正确性」还是「分配即初始化所有字段」。
