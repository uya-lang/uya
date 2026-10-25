# exec VM / C99 后端行为对齐

本文是 `exec` 后端（`uya run --vm` / `uya test --vm`）与 C99 后端对齐工作的总纲：
判据、基线、工具、门禁、当前进度与后续阶段。

## 1. 目标与判据

判据只有一条：

> **C99 后端能编译、能运行的程序，exec VM 必须同样能跑，且执行结果与 C99 一致；
> `tests/` 全部通过。**

由此导出四条可执行约束：

1. **矩阵一致**：`tests/` 用例在 C99 与 exec VM 下的通过/失败集合相同。
2. **输出一致**：同一用例的 stdout（地址类输出归一化后）、退出码、测试摘要逐字节一致。
3. **无 unsupported**：对 C99 能编译成功的程序，`run --vm` 不得出现 `exec unsupported 原因码`。
4. **无静默失败**：任何 exec 失败必须给出原因码 + `file:line` + 消息。

范围限定在 hosted `run` / `test`（`--vm` 与 C99 `run` 的边界一致）；microapp /
softvm / baremetal 是另一条产物路径，`--vm` 不适用，保留 `EXEC_UNSUPPORTED_MICROAPP`。
若某用例在 C99 侧也因环境/平台原因失败，exec VM 只需与之相同，不要求「超过 C99」。

参照关系：**C99 后端是行为参照，语言规范用于裁决歧义**。差分发现差异时先判定归属；
若确认是 C99 后端偏离规范，按规范修复并单独提交，不混在 exec 改动里。

## 2. 工具与门禁

| 工具 | 作用 | 用法 |
|---|---|---|
| `tests/verify_exec_vm_census.sh` | 全量跑 `uya test --vm`，输出通过率与失败原因直方图 | `UYA_EXEC_CENSUS_MIN=<n> bash tests/verify_exec_vm_census.sh` |
| `tests/verify_exec_vm_parity.sh` | 逐用例比较 C99 / VM 的退出码与测试摘要；`PARITY_STDOUT=1` 时再比较 `run` 的 stdout | `PARITY_STDOUT=1 bash tests/verify_exec_vm_parity.sh` |
| `make exec-census` | 上面的普查，作为 `make` 目标 | `make exec-census` |
| `make exec-parity` | 上面的差分，作为 `make` 目标 | `make exec-parity` |

跳过表纪律：

- `tests/exec_vm_census_skip.txt` 与 `tests/exec_vm_parity_skip.txt` 每行 `文件名 # 原因`；
- **只允许登记「C99 侧同样不适用/同样失败」的用例**（网络、平台、外部服务）；
- 「exec VM 还没实现」不是跳过理由，必须留在失败列表里被计数。

两个脚本对测试语料统一带 `--no-strict-overflow`，与 `tests/run_programs_parallel.sh`
对 `tests/` 的口径一致（该语料刻意包含边界算术）。

## 3. 基线（可复现）

在提交 `20a34ca2` 的检出上，对 `tests/test_*.uya`（910 个文件）实测：

| 阶段 | `test --vm` 通过 | 通过率 | 主要失败原因 |
|---|---|---|---|
| 本工作开始 | 119 / 910 | 13.1% | `extern_abi` 600（其中 `uya_pipeline_worker_dispatch/0` 383、`printf/1` 195）、`generic` 102、`simd` 55 |
| P0 + P1.1 + P1.3 之后 | **216 / 910** | **23.7%** | `extern_abi` 403（几乎全是 `main_main/0`）、`generic` 181、`simd` 55 |
| P1.2（测试块 lowering + runner）之后 | **220 / 911** | **24.1%** | `generic` 531（模块全局槽位 230、泛型/varargs 90、未支持表达式 84、语句 31）、`simd` 55 |

C99 侧同口径基线：867 / 900（早期一次普查，含工作目录导致的 `@embed` 类噪声，
后续以 `tests/verify_exec_vm_parity.sh` 的逐用例结果为准）。

## 4. 已完成

### P0 门禁与基线

- 新增 `tests/verify_exec_vm_census.sh`、`tests/verify_exec_vm_parity.sh` 及两张跳过表；
- `Makefile` 新增 `exec-census` / `exec-parity` 目标；
- 覆盖率与差分从此可量化、可防回退。

### P1.1 编译器合成宿主符号

`lib/std/runtime/entry/entry.uya` 的 `uya_pipeline_worker_dispatch()` 在 C99 侧由
代码生成器内联为 `-1`（无 native worker 入口）。exec 侧在调用 lowering 阶段按
「符号名 + 0 参数 + extern 声明」识别并降为常量 `-1`，语义与 C99 一致。

### P1.2 顶层 `test "..."` 块与测试 runner

C99 侧把每个测试块发射成独立 `!void` 函数、再由 `uya_run_tests()` 逐个调用；exec 侧此前
完全没有这条路径，导致 `test` 语句直接报不支持，且没有用户 main 的测试文件会去调
C99 合成出来的 `main_main`（`extern_abi` 403 例的根因）。本轮补齐：

- `src/exec/lower.uya`：按源码顺序收集 `program_decls` 里的 `AST_TEST_STMT`，为每个块
  合成 `AST_FN_DECL`（返回 `!void`，body 指向测试块），交给统一的 `exec_lower_function`
  降成 HIR 函数；合成声明进入可达队列，因此测试体里调用的辅助函数会被正常带出来；
- 没有用户 main 时合成空入口 `__exec_test_entry`，不再走 `main_main`；
- `HIRModule` / `BCProgram` 增加测试函数下标与描述串；`src/exec/vm.uya` 在入口处逐个
  执行测试并输出与 C99 完全相同的文本：

  ```text
  
=== Running %d tests ===

    TEST: <描述> ... 
      （失败为 ERROR
）
  
=== Results ===

    Tests Passed:       %d
    Tests Failed:       %d
    Assertions Passed:  %d
  ```

  没有用户 main 时以失败用例数作为退出码（对齐 C99 `main_main` 的 `return _test_failed`）；
  有用户 main 时测试在入口前执行、退出码仍取 main 的返回值（对齐 C99 在 main 开头注入
  `uya_run_tests()`）。

副产物：`ast_new_node` 改为导出，供 exec 侧构造合成声明。

### P1.3 printf 家族 varargs

此前 exec 的 `printf/fprintf/sprintf/snprintf` 宿主调用只接受没有转换说明符的固定形态，
带 `%d/%s` 就直接以 `extern_abi` 回退。本轮补齐：

- 新增 `src/exec/format.uya`：逐条转换规格委托宿主 `snprintf` 渲染（flags/width/
  precision、浮点格式与 C99 调用的同一 libc 完全一致），再按目标分发到
  stdout（`libc.stdout`，与 `@print` 同缓冲）/ `FILE*` / 字符串缓冲区；
- `*` 宽度与精度在渲染前用实参替换成字面数字，避免向宿主 varargs 传动态宽度；
- `%n`、宽字符 `%ls/%lc` 明确拒绝（返回运行期错误），不做静默错答；
- `src/exec/lower.uya` 放宽四个函数的最小实参个数，`src/exec/vm.uya` 改用统一格式化入口。

回归用例：`tests/test_exec_vm_printf_varargs.uya`（整数/浮点/字符串/字符/宽度/精度/
`*`/`%%`/`snprintf` 截断语义），`run` 与 `run --vm` 输出逐字节一致。

边界负例更新：`tests/test_exec_vm_extern_decl_varargs_unsupported.uya` 原本用 `printf`
验证「仅有 extern 声明的 varargs 一律拒绝」，该边界已随本轮前移；改用不在宿主桥
登记表里的 `fcntl` 继续验证稳定拒绝（原因码 `extern_abi`）。

## 5. 已发现、尚未修复的差异

按优先级记录，均可复现：

1. **大整数字面量的期望类型传播**：`const v: i64 = 9000000000;` 在 VM 下被截断为
   `410065408`，C99 正确。根因在字面量 lowering 未接收期望类型（`exec_lower_expr`
   对 `AST_NUMBER` 直接用推断类型），属于通用类型传播问题，影响面大于 varargs。
2. **`for arr |v|` / `for arr |&item|` 静默失败**：`--vm` 下进程直接退出码 1 且无诊断，
   C99 正常；需要补 for 迭代 lowering 并补错误上报。
3. **slice 的 `.ptr` 下标**：`s.ptr[2]` 在 VM 运行期报 `exec: ADDR_FIELD 字段越界`，C99 正常。
4. **导入模块内部的全局变量拿不到槽位**（当前最大阻塞，约 230 例）：测试块现在能降成
   HIR 函数，但 `lib/std/testing/testing.uya` 的 `_test_passed` 等全局变量没有被
   `exec_lower_collect_global_slots` 收集到（实测 `globals=5`）。原因是 `std.testing`
   是选择性导入，主 checker 只保留了导入项符号，没有该模块自己的符号表/程序节点；
   `exec_lower_collect_global_slots_from_module_import` 的「同文件全局」补采只扫描
   `checker.program_node`，而该节点不含库模块的 decl。需要在 checker 侧保留或暴露
   「模块 → 程序节点/符号表」，exec 侧据此补采（不改语义，只补槽位）。

## 6. 后续阶段

| 阶段 | 内容 | 门禁 |
|---|---|---|
| P1.2 | ~~`test "..."` 块 lowering + exec 测试 runner~~（已完成；剩余：导入模块内部全局变量槽位） | 测试块用例可执行，census ≥ 60% |
| P1.4 | 静默失败整治 + 表驱动诊断测试 | 无静默失败 |
| P2 | 原生桥：`extern`/FFI/`extern var`/`@c_import`/`@asm`（生成的 C shim + `dlopen`） | `extern_abi` 清零，census ≥ 85% |
| P3 | 语义补齐：字符串插值、解构、`@params`/`@embed`、泛型单态化、`for` 全形态、`match` 全模式、slice/指针、checked 算术、浮点、atomic、interface | census ≥ 92% |
| P4 | SIMD（`VECTOR`/`MASK` 值 + 逐通道运算 + `@vector.*`） | SIMD 用例全通过 |
| P5 | async / `@frame` / `@await` 状态机 | async 用例全通过 |
| P6 | 全量 parity 收口 | 两个门禁脚本全绿 |
| P7 | 性能、bytecode cache、默认策略与文档 | 性能不退化 |
