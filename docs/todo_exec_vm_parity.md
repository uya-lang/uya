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
- 最近一次实测（本轮 checked 算术 catch/try + `undefined` + 字符串转切片 + 宏深拷贝之后）：
  `test --vm` 通过 **456 / 914（49.9%）**，失败 458。
- 失败原因分布：`generic` 258、`simd` 69、`runtime` 30、`catch_expr` 18、
  `extern_abi` 16、`string_interp` 9、`build` 9、`async` 6、`timeout` 5、
  `c_import` 4、`try_expr` 1；`match_expr` 已清零。
- `generic` 内部 Top：泛型调用/varargs 转发 101、仅支持局部变量/参数/全局标识符 46、
  语句节点 `type=79`（inline asm）42、成员方法 `kind=13` 19、结构体声明 18、
  interface 方法表 15、表达式节点 `type=28` 7、编译期 builtin 折叠 5。
- `runtime` 内部 Top：`当前不支持该指针元素类型` 19（多为 fmt_* 系列，已推进到
  更深的运行时错误）、`LOAD_FIELD 字段越界` 6、`LOAD_INDEX 越界` 3。
- 本轮从 431 / 914（47.2%）起步，累计 +25。
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
- 余下：fmt_* 推进到 `tokenizer.uya:110` 的「切片基值不是 array/slice」，继续跟。

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
- [ ] 余下 3 个：`test_crypto_bigint`（超时，疑似 VM 死循环）、
  `test_protobuf_dynamic`（`lib/std/protobuf/dynamic.uya:86` 仍是
  `当前不支持该指针元素类型`）、`test_tls_x509`
  （`lib/tls/x509/cert.uya:468` `LOAD_FIELD 字段越界`）。

## 下一轮起点（上下文压缩后从这里继续）

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
3. 每完成一项：`make uya` → 相关脚本 → census → 更新本文件勾选 → 单独提交。
4. 收口（T11）前必须 `make check` 全绿且 `make exec-parity` 全绿，再
   `worktree finish` 合并到 main 并删除工作区。

### T11 收口

- [ ] `uya test --vm` 全量通过（跳过表只保留 C99 侧同样不适用的用例）
- [ ] `make exec-parity` 全绿
- [ ] `make check` 全绿
- [ ] 合并到 main 并删除工作区
