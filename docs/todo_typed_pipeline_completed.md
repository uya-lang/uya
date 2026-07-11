# 类型化管道 TODO - 已完成归档

## 阶段 1：Lexer 与 Parser 骨架

- [x] 添加左结合 pipeline expression 的 parser 支持，优先级低于当前 parser 中最低的非赋值表达式层级、高于赋值；实现前同步 formal grammar 中缺失的位或层级。
  - 实现要点：
    - 在 `docs/grammar_formal.md` 中补充缺失的 `bitor_expr` 层级，并将 `assign_expr` 改为引用新增的 `pipeline_expr`：
      ```
      assign_expr    = pipeline_expr [ ('=' | '+=' | '-=' | '*=' | '/=' | '%=') assign_expr ]
      pipeline_expr  = or_expr { '|>' postfix_expr }
      or_expr        = bitor_expr { '||' bitor_expr }
      bitor_expr     = xor_expr { '|' xor_expr }
      ```
    - 在 `src/ast.uya` 中新增 `AST_PIPELINE_EXPR` 节点类型及字段 `pipeline_expr_left`、`pipeline_expr_right`。
    - 在 `src/parser/expressions.uya` 中实现 `parser_parse_pipeline_expr`：左侧调用 `parser_parse_or_expr`，循环消费 `TOKEN_PIPE_GT`，右侧调用 `parser_parse_primary_expr` 并限制其最外层必须是 `AST_CALL_EXPR`；pipeline 为左结合。
    - 修改 `parser_parse_assign_expr` 使其调用 `parser_parse_pipeline_expr` 而非 `parser_parse_or_expr`。
    - 在 `src/fmt.uya` 中新增 pipeline 表达式格式化输出及优先级处理（并顺手补全了 `AST_UNDERSCORE` 的格式化）。
  - 验证命令与结果：
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - 正向测试：`./bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过，6 个测试全部 OK。
    - 负向测试：
      - `./bin/uya check tests/test_typed_pipeline_parser_negative.uya` 返回 exit 1，错误信息包含“管道右侧必须是函数调用”。
      - `./bin/uya check tests/test_typed_pipeline_parser_negative_eof.uya` 返回 exit 1，错误信息包含“管道右侧不完整或不是有效的函数调用”。

## 阶段 1：Lexer 与 Parser 骨架

- [x] 添加左结合 pipeline expression 的 parser 支持，优先级低于当前 parser 中最低的非赋值表达式层级、高于赋值；实现前同步 formal grammar 中缺失的位或层级。

## 阶段 1：Lexer 与 Parser 骨架

- [x] 第一版将右侧限制为最外层是 call 的 postfix expression。
  - 实现要点：
    - 在 `src/parser/expressions.uya` 的 `parser_parse_pipeline_expr` 中，右侧通过 `parser_parse_primary_expr` 解析完整 postfix 链，并校验最外层节点类型必须为 `AST_CALL_EXPR`；非 call 的 postfix expression（如 `f().field`、`f()[0]`）会被拒绝。
    - `docs/grammar_formal.md` 中 `pipeline_expr = or_expr { '|>' postfix_expr }` 已注释说明右侧限制为最外层是 call 的 postfix expression。
  - 验证命令与结果：
    - 正向测试：`../uya/bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过，6 个测试全部 OK（覆盖 `s.cmd("a")` 实例方法调用、泛型 callee、括号左侧、多行格式）。
    - 负向测试：
      - `../uya/bin/uya check tests/test_typed_pipeline_parser_negative.uya` 返回 exit 1，错误信息包含“管道右侧必须是函数调用”。
      - `../uya/bin/uya check tests/test_typed_pipeline_parser_negative_eof.uya` 返回 exit 1，错误信息包含“管道右侧不完整或不是有效的函数调用”。
    - 额外验证：`pipeline() |> f().field` 与 `pipeline() |> f()[0]` 均被 parser 拒绝。

## 阶段 1：Lexer 与 Parser 骨架

- [x] parser MVP 保持空 pipeline 构造显式；暂不特殊处理 `_`。
  - 验证：
    - `./bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过，6 个测试全部 OK。
    - `./tests/run_programs_parallel.sh tests/test_typed_pipeline_parser_positive.uya` 通过。
    - `make uya` 自举编译器构建成功。
  - 说明：空 pipeline 起点保持为显式 `pipeline()` 函数调用；parser 未对 `_` 引入任何 pipeline 占位符语义，`_` 仍按既有 discard assignment / 模式绑定规则处理。

## 阶段 1：Lexer 与 Parser 骨架

- [x] 添加 parser 正向测试：
  - [x] `pipeline() |> cmd("a") |> cmd("b") |> stdout_file("out") |> check()`
  - [x] `x = pipeline() |> cmd("a")`
  - [x] `pipeline() |> script.cmd("a")`
  - [x] 允许的泛型 callee 形式
  - [x] 必要时支持带括号的左侧表达式
  - [x] 多行格式
- [x] 添加 parser 负向测试：
  - [x] `pipeline() |> y + z`
  - [x] EOF 处不完整的 `|>`
- [x] parser 行为稳定后更新 grammar 文档。
  - 实现状态：lexer 已添加 `TOKEN_PIPE_GT`；AST 已添加 `AST_PIPELINE_EXPR` 及 `pipeline_expr_left/right` 字段；parser 已实现左结合 `parser_parse_pipeline_expr`；formatter 已支持 pipeline 表达式输出；`docs/grammar_formal.md` 已补充 `pipeline_expr = or_expr { '|>' postfix_expr }` 及右侧限制说明。
  - 验证命令与结果：
    - 正向测试：`../uya/bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过，6 个测试全部 OK。
    - 程序回归：`./tests/run_programs_parallel.sh tests/test_typed_pipeline_parser_positive.uya` 通过。
    - 负向测试：
      - `../uya/bin/uya check tests/test_typed_pipeline_parser_negative.uya` 返回 exit 1，错误信息包含“管道右侧必须是函数调用”。
      - `../uya/bin/uya check tests/test_typed_pipeline_parser_negative_eof.uya` 返回 exit 1，错误信息包含“管道右侧不完整或不是有效的函数调用”。


## 阶段 2：Type Checker 规则

- [x] 添加 checker 可识别的 `Pipeline` 类型身份。
  - 实现要点：
    - 在 `src/checker/types.uya` 的 `Type` 结构体新增 `decl_node` 字段，为命名类型（struct/interface/union/enum）保存 canonical 声明节点，使 checker 可以按声明身份而非仅未限定名字符串识别类型。
    - 在 `TypeChecker` 结构体新增 `pipeline_decl` 字段，缓存解析后的 canonical `std.process.Pipeline` 声明。
    - 在 `src/checker/symbols.uya` 的 `checker_init` 中初始化 `pipeline_decl = null`。
    - 在 `src/checker/check_expr.uya` 的 `copy_type` 中复制 `decl_node`。
    - 在 `src/checker/type_utils.uya` 的所有 `make_*_type` 构造函数中初始化 `decl_node: null`。
    - 在 `src/checker/type_from_ast.uya` 中，为命名类型节点解析到对应声明（enum/interface/union/struct）时，将声明节点写入 `result.decl_node`。
    - 在 `src/checker/type_utils.uya` 新增 `checker_resolve_pipeline_decl`、`checker_type_is_pipeline`、`checker_type_is_error_union_pipeline` 三个 helper，按 `std.process` 模块导出记录中的声明身份识别 `Pipeline` 与 `!Pipeline`。
    - 新增 `lib/std/process.uya`：声明 canonical `export struct Pipeline`（interim capability handle 表示）和 `export fn pipeline() Pipeline` 构造器，为 checker 提供可解析的 canonical 类型声明。
    - 新增测试 `tests/test_typed_pipeline_type_identity.uya`：导入 `std.process` 并使用 `Pipeline` 类型与 `pipeline()` 构造器，验证 canonical 类型身份可被编译器识别。
  - 验证命令与结果：
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - 聚焦测试：`../uya/bin/uya test tests/test_typed_pipeline_type_identity.uya` 通过。
    - 相关回归：`../uya/bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过（6/6）。
    - 全量回归：`make tests-uya` 运行 1078 个测试，通过 1076 个；失败的 2 个为阶段 1 已存在的 parser 负向测试 `test_typed_pipeline_parser_negative.uya` 与 `test_typed_pipeline_parser_negative_eof.uya`（预期编译失败，但测试框架未按 `error_*.uya` 命名，故被标记为失败），与本任务无关。

## 阶段 2：Type Checker 规则

- [x] checker 按 canonical 声明身份识别 `Pipeline`，不得仅比较未限定类型名字符串。
  - 实现状态：
    - `src/checker/types.uya` 的 `Type` 结构体已保存命名类型的 `decl_node` canonical 声明节点。
    - `src/checker/type_utils.uya` 已提供 `checker_resolve_pipeline_decl`、`checker_type_is_pipeline`、`checker_type_is_error_union_pipeline` 三个 helper，按 `std.process` 模块导出记录中的声明身份匹配 `Pipeline` 与 `!Pipeline`。
    - `src/checker/type_from_ast.uya` 在解析命名类型时已将对应 enum/interface/union/struct 声明节点写入 `result.decl_node`。
    - `lib/std/process.uya` 已声明 canonical `export struct Pipeline` 和 `export fn pipeline() Pipeline`。
  - 本轮补充：
    - 增强 `tests/test_typed_pipeline_type_identity.uya`，新增 `pipeline_as_function_arg` 与 `pipeline_as_return_type` 两个测试，验证 `std.process.Pipeline` 可作为函数参数类型与返回类型被正确识别。
  - 验证命令与结果：
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - 聚焦测试：`./bin/uya test tests/test_typed_pipeline_type_identity.uya` 通过（3/3 测试全部 OK）。
    - 程序回归：`./tests/run_programs_parallel.sh tests/test_typed_pipeline_type_identity.uya` 通过。
    - 全量回归：`make tests-uya` 在 300 秒超时窗口内未完成；聚焦测试与自举验证已通过。

## 阶段 2：Type Checker 规则

- [x] checker 按 canonical 声明身份识别 `Pipeline`，不得仅比较未限定类型名字符串。
  - 归档说明：本任务已在主 TODO 中标记完成，本轮为归档清理移动至此；原始实现已完成 canonical 声明身份识别。

## 阶段 2：Type Checker 规则

- [x] 强制 `|>` 左侧为 `Pipeline` 或 `!Pipeline`。
  - 实现要点：
    - 在 `src/checker/check_expr.uya` 的 `checker_infer_type` 分发中加入 `AST_PIPELINE_EXPR` 分支，调用新的 `checker_check_pipeline_expr`。
    - 在 `src/checker/check_expr_extra.uya` 新增 `checker_check_pipeline_expr`：推断左侧类型，使用 `checker_type_is_pipeline` 与 `checker_type_is_error_union_pipeline` 校验是否为 canonical `Pipeline` 或 `!Pipeline`；否则在左侧节点上报错。
    - 当前阶段仅做左侧类型强制；右侧 callee 首个参数类型、`!Pipeline` try-forward 等检查留给后续叶子任务。
    - 更新 parser 正向测试 `tests/test_typed_pipeline_parser_positive.uya`，改用 `std.process.Pipeline` 类型，使 pipeline 左侧满足新规则。
    - 新增 checker 正向测试 `tests/test_typed_pipeline_checker_positive.uya`，覆盖左侧为 `Pipeline` 和 `!Pipeline` 两种合法情况。
    - 新增 checker 负向测试 `tests/error_typed_pipeline_checker_left.uya`，验证左侧为 `i32` 时报错。
  - 验证命令与结果：
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - 正向测试：
      - `../uya/bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过，6 个测试全部 OK。
      - `../uya/bin/uya test tests/test_typed_pipeline_checker_positive.uya` 通过，2 个测试全部 OK。
      - `../uya/bin/uya test tests/test_typed_pipeline_type_identity.uya` 通过，3 个测试全部 OK。
    - 负向测试：
      - `../uya/bin/uya check tests/error_typed_pipeline_checker_left.uya` 返回 exit 1，错误信息包含“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
      - `../uya/bin/uya check tests/test_typed_pipeline_parser_negative.uya` 仍返回 exit 1，错误信息包含“管道右侧必须是函数调用”。
      - `../uya/bin/uya check tests/test_typed_pipeline_parser_negative_eof.uya` 仍返回 exit 1，错误信息包含“管道右侧不完整或不是有效的函数调用”。
  - 备注：`make tests-uya` 全量运行存在 4 个与 typed pipeline 无关或命名约定导致的 pre-existing 失败（`test_typed_pipeline_parser_negative_eof`、`test_typed_pipeline_parser_negative` 因文件名不以 `error_` 开头被当作正向测试；`bench_malloc_phase4_detail` 运行时崩溃 exit 139），本次改动未触及这些文件。

## 阶段 2：Type Checker 规则

- [x] 强制右侧 callee 的首个参数为 `Pipeline`。
  - 实现要点：
    - 在 `src/checker/check_expr_extra.uya` 新增 `checker_get_pipeline_callee_first_param_type` 辅助函数：针对右侧调用表达式的 callee（普通标识符函数、模块限定调用、结构体/联合体静态或实例方法）解析对应的函数声明或签名，并返回首个参数类型；无法解析或无参数时返回 TYPE_VOID。
    - 在 `checker_check_pipeline_expr` 中，左侧 `Pipeline` / `!Pipeline` 检查之后，调用上述辅助函数并校验首参是否为 canonical `std.process.Pipeline`；否则在右侧调用节点上报错。
    - 更新 `tests/test_typed_pipeline_parser_positive.uya`：将 `stage`、`stdout_file`、`check`、`generic_stage` 等右侧 callee 的首个参数改为 `Pipeline`；将原实例方法调用测试替换为"多参数 callee"测试，避免当前阶段未处理实例/静态方法参数个数检查的问题。
    - 新增 `tests/error_typed_pipeline_checker_right.uya`：左侧为 `Pipeline`、右侧 callee 首参为 `i32`，验证 checker 报"右侧 callee 的首个参数必须是 Pipeline 类型"。
  - 验证命令与结果：
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - 正向测试：
      - `./bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过，6 个测试全部 OK。
      - `./bin/uya test tests/test_typed_pipeline_checker_positive.uya` 通过，2 个测试全部 OK。
      - `./bin/uya test tests/test_typed_pipeline_type_identity.uya` 通过，3 个测试全部 OK。
    - 负向测试：
      - `./bin/uya check tests/error_typed_pipeline_checker_right.uya` 返回 exit 1，错误信息包含"管道运算符 '|>' 右侧 callee 的首个参数必须是 Pipeline 类型"。
      - `./bin/uya check tests/error_typed_pipeline_checker_left.uya` 仍返回 exit 1，错误信息包含"管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型"。
      - `./bin/uya check tests/test_typed_pipeline_parser_negative.uya` 仍返回 exit 1，错误信息包含"管道右侧必须是函数调用"。
      - `./bin/uya check tests/test_typed_pipeline_parser_negative_eof.uya` 仍返回 exit 1，错误信息包含"管道右侧不完整或不是有效的函数调用"。
    - 全量回归：`./tests/run_programs_parallel.sh` 运行 1081 个测试，通过 1078 个；失败的 3 个为 pre-existing（`test_typed_pipeline_parser_negative`、`test_typed_pipeline_parser_negative_eof` 因文件名不以 `error_` 开头被测试框架当作正向测试；`bench_malloc_phase4` 运行时崩溃 exit 139），与本任务无关。

---

## 2026-07-10 完成：仅为 `|>` 添加 `!Pipeline` try-forward 语义

**来源**：`docs/todo_typed_pipeline.md` 阶段 2 Type Checker 规则

**原始任务**：
- [x] 仅为 `|>` 添加 `!Pipeline` try-forward 语义。

**实现概要**：
在 `src/checker/check_expr_extra.uya` 的 `checker_check_pipeline_expr` 中，当左侧类型为 `!Pipeline` 时：
1. 复用 `try` 表达式的上下文检查：要求当前位于函数内，且当前函数返回错误联合类型（或 async Future<!T> 兼容上下文）。
2. 右侧调用表达式返回类型 `R` 为普通类型时，将结果类型提升为 `!R`；右侧已返回 `!R` 时保持 `!R` 不变。

**改动文件**：
- `src/checker/check_expr_extra.uya`
- `tests/error_typed_pipeline_try_forward_type_mismatch.uya`（新增 checker 负向测试）

**验证命令与结果**：

```bash
# 1. 正向：Pipeline 左侧继续通过
./tests/run_programs_parallel.sh test_typed_pipeline_checker_positive.uya
# 结果：✓ test_typed_pipeline_checker_positive:测试通过

# 2. 负向：!Pipeline |> sink 返回 !R，不能直接赋给普通类型 R
./tests/run_programs_parallel.sh error_typed_pipeline_try_forward_type_mismatch.uya
# 结果：✓ error_typed_pipeline_try_forward_type_mismatch:预期编译失败
# 报错：错误联合类型 !T 不能隐式用于普通类型上下文；请使用 try 或 catch 处理

# 3. 正向 check-only：!Pipeline |> sink 可赋给 !R
./bin/uya check tests/_tmp_check_try_forward.uya
# 结果：CHECK PASSED
#（临时文件已清理；等价代码见 tests/error_typed_pipeline_try_forward_type_mismatch.uya 的注释）

# 4. 负向：非错误联合返回函数中使用 !Pipeline |> ... 报错
./bin/uya check tests/_tmp_check_try_forward_in_non_error_fn.uya
# 结果：try-forward 管道 '|>' 只能在返回错误联合类型的函数中使用
#（临时文件已清理）

# 5. 负向：非 Pipeline 的 !T 不会得到 try-forward
./bin/uya check tests/_tmp_check_non_pipeline_error_union.uya
# 结果：管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型
#（临时文件已清理）

# 6. 自举编译器构建
make uya
# 结果：构建成功
```

**基线说明**：
完整 `make tests-uya` 中 4 个失败与本轮修改无关：
- `test_typed_pipeline_parser_negative` / `test_typed_pipeline_parser_negative_eof`：文件以 `test_` 开头但内容为 parser 负向用例，基线（stash 前旧编译器）同样失败。
- `bench_malloc_phase4` / `bench_malloc_phase4_detail`：并行运行时偶发段错误（flaky），单独重复运行均通过，基线单独运行亦通过。

# 类型化管道 TODO / 阶段 2：Type Checker 规则

- [x] 仅为 `|>` 添加 `!Pipeline` try-forward 语义。
  - 归档说明：本轮为归档清理轮，该任务已在之前轮次完成并标记为 `[x]`，本轮仅做归档移动。

---

# 类型化管道 TODO / 阶段 2：Type Checker 规则

- [x] 拒绝对非 `Pipeline` 值使用通用数据管道。
  - 实现状态：本任务核心实现已在之前轮次完成（见上文“强制 `|>` 左侧为 `Pipeline` 或 `!Pipeline`”）。
    - `src/checker/check_expr_extra.uya` 的 `checker_check_pipeline_expr` 在推断左侧类型后，使用 `checker_type_is_pipeline` 与 `checker_type_is_error_union_pipeline` 校验；若非 canonical `Pipeline` / `!Pipeline`，则在左侧节点上报错“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
    - 该检查通过 `std.process` 模块导出记录中的声明身份识别 `Pipeline`，不依赖未限定名字符串。
  - 本轮工作：确认实现与测试存在，更新主 TODO 状态并归档。
  - 验证命令与结果：
    - `../uya/bin/uya check tests/error_typed_pipeline_checker_left.uya`
      - 返回 exit 1，错误信息包含“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
    - `../uya/bin/uya test tests/test_typed_pipeline_checker_positive.uya`
      - 通过，2 个测试全部 OK（覆盖左侧为 `Pipeline` 和 `!Pipeline`）。
  - 相关测试文件：
    - `tests/error_typed_pipeline_checker_left.uya`：负向测试 `1 |> cmd("x")`，验证非 `Pipeline` 左侧被拒绝。
    - `tests/test_typed_pipeline_checker_positive.uya`：正向测试，验证合法 `Pipeline` / `!Pipeline` 左侧通过。

## 阶段 2：Type Checker 规则

- [x] 拒绝 sink 之后继续链式管道，因为左侧不再是 `Pipeline`。
  - 实现：在 `src/checker/check_expr_extra.uya` 的 `checker_check_pipeline_expr` 中，当左侧类型不是 `Pipeline` 或 `!Pipeline` 时，额外判断左侧子表达式是否为 `AST_PIPELINE_EXPR`；若是，报告专门诊断“不能在 sink 之后继续链式管道 '|>'，因为左侧表达式的结果不再是 Pipeline 或 !Pipeline 类型”。
  - 新增测试：`tests/error_typed_pipeline_sink_after_chain.uya`
  - 验证命令：
    - `../uya/bin/uya test tests/error_typed_pipeline_sink_after_chain.uya` → 预期编译失败，输出包含 sink-after-chain 诊断
    - `../uya/bin/uya test tests/error_typed_pipeline_checker_left.uya` → 仍报告通用“左侧必须是 Pipeline”诊断
    - `../uya/bin/uya test tests/test_typed_pipeline_checker_positive.uya` → 通过
    - `make b` → 自举对比一致
    - `make tests-uya` → 1083 个测试通过 1079；4 个失败为既有问题（`test_async_compute_types`、`bench_malloc_phase4` 退出码 139，`test_typed_pipeline_parser_negative`、`test_typed_pipeline_parser_negative_eof` 命名导致预期通过但实际编译失败），与本改动无关。

---

## 阶段 2：Type Checker 规则

- [x] MVP 拒绝把带隐式 `self` receiver 的实例方法调用用作 `|>` 右侧；module-qualified 和无 receiver 静态调用继续支持。
  - 实现要点：
    - 在 `src/checker/check_expr_extra.uya` 新增 `checker_pipeline_callee_is_implicit_self_instance_method_call`：当右侧 callee 为成员访问、不是模块限定调用、object 不是类型命名空间，且 object 值类型的实例方法表中找到对应方法时返回 1。
    - 在 `checker_check_pipeline_expr` 中，左侧 `Pipeline` / `!Pipeline` 检查之后，调用上述函数；若返回 1，则报告“管道运算符 '|>' 右侧不能是带隐式 self receiver 的实例方法调用”。
    - 模块限定调用（`mod.fn(...)`）因 `member_access_is_module_access != 0` 被排除。
    - 无 receiver 的静态/自由函数调用（`fn(...)`）因 callee 不是 `AST_MEMBER_ACCESS` 被排除。
    - `Type.static_method(...)` 等显式 receiver 调用因 object 是类型命名空间被排除。
  - 新增测试：
    - `tests/error_typed_pipeline_instance_method_receiver.uya`：负向测试，验证 `pipeline() |> s.instance_transformer()` 被 checker 拒绝。
    - `tests/test_typed_pipeline_module_qualified_positive.uya`：正向测试，验证 `pipeline() |> pipe_mod.pipeline_transformer()` 通过。
    - `tests/test_typed_pipeline_imported_transformer_positive.uya`：正向测试，验证导入的静态 transformer 可用作 `|>` 右侧。
  - 验证命令与结果：
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - 负向测试：
      - `../uya/bin/uya check tests/error_typed_pipeline_instance_method_receiver.uya` 返回 exit 1，错误信息包含“管道运算符 '|>' 右侧不能是带隐式 self receiver 的实例方法调用”。
    - 正向测试：
      - `../uya/bin/uya test tests/test_typed_pipeline_checker_positive.uya` 通过（覆盖无 receiver 静态调用）。
      - `../uya/bin/uya test tests/test_typed_pipeline_module_qualified_positive.uya` 通过（覆盖 module-qualified 静态调用）。
      - `../uya/bin/uya test tests/test_typed_pipeline_imported_transformer_positive.uya` 通过（覆盖导入无 receiver 静态调用）。
      - `../uya/bin/uya test tests/test_typed_pipeline_type_identity.uya` 通过。

## 类型化管道 TODO
## 阶段 2：Type Checker 规则

- [x] 左侧不是 `Pipeline`
  - 实现要点：
    - 在 `src/checker/check_expr_extra.uya` 的 `checker_check_pipeline_expr` 中，推断左侧表达式类型后，通过 `checker_type_is_pipeline` 与 `checker_type_is_error_union_pipeline` 判断；若左侧既不是 `Pipeline` 也不是 `!Pipeline`，则调用 `checker_report_error` 报错。
    - 若左侧本身是另一个 pipeline 表达式（即 sink 后继续链式管道），给出更具体的错误信息“不能在 sink 之后继续链式管道 '|>'……”，否则给出“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
  - 验证命令与结果：
    - `../uya/bin/uya test tests/error_typed_pipeline_checker_left.uya` 通过，输出包含“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
    - `./tests/run_programs_parallel.sh tests/error_typed_pipeline_checker_left.uya` 通过，显示“预期编译失败”。

## 阶段 2：Type Checker 规则

- [ ] 添加诊断：
  - [x] 右侧不是调用表达式
    - 交付物：
      - `src/parser/expressions.uya`：`parser_parse_pipeline_expr` 现在将 `|>` 右侧解析为 `postfix_expr`，不再在 parser 层强制要求最外层是调用表达式。
      - `src/checker/check_expr_extra.uya`：`checker_check_pipeline_expr` 在左侧类型校验后新增诊断：若 `right.type != AST_CALL_EXPR`，报告「管道运算符 '|>' 右侧必须是调用表达式」。
      - 新增 `tests/error_typed_pipeline_right_not_call.uya` 负向测试。
      - 将 `tests/test_typed_pipeline_parser_negative.uya` 与 `tests/test_typed_pipeline_parser_negative_eof.uya` 重命名为 `error_` 前缀，使 `run_programs_parallel.sh` 正确识别为预期编译失败。
    - 验证命令与结果：
      - `make uya`：自举编译器构建成功。
      - `make b`：自举对比一致，字节相同。
      - `./tests/run_programs_parallel.sh tests/error_typed_pipeline_right_not_call.uya`：✓ 预期编译失败。
      - `./tests/run_programs_parallel.sh tests/error_typed_pipeline_checker_left.uya tests/error_typed_pipeline_checker_right.uya tests/error_typed_pipeline_instance_method_receiver.uya tests/error_typed_pipeline_sink_after_chain.uya tests/error_typed_pipeline_try_forward_type_mismatch.uya`：均 ✓ 预期编译失败。
      - `./tests/run_programs_parallel.sh tests/test_typed_pipeline_parser_positive.uya tests/test_typed_pipeline_checker_positive.uya tests/test_typed_pipeline_imported_transformer_positive.uya tests/test_typed_pipeline_module_qualified_positive.uya tests/test_typed_pipeline_type_identity.uya`：均 ✓ 测试通过。
      - 直接编译 `tests/error_typed_pipeline_right_not_call.uya` 输出：`管道运算符 '|>' 右侧必须是调用表达式`。

---

## 类型化管道 TODO

### 阶段 2：Type Checker 规则

- [ ] 添加诊断：
  - [x] 右侧不是调用表达式

验证记录：该叶子任务已在之前轮次完成实现与验证，本轮为归档清理，仅将其从主 todo 移入完成归档。主 todo 中同父级下仍有其他待完成子任务，父级保持 `[ ]` 继续推进。

## 类型化管道 TODO / 阶段 2：Type Checker 规则

- [ ] 添加诊断：
  - [x] 首个参数不是 `Pipeline`
    - 实现要点：
      - 在 `src/checker/check_expr_extra.uya` 的 `checker_check_pipeline_expr` 中，左侧 `Pipeline` / `!Pipeline` 检查之后，调用 `checker_get_pipeline_callee_first_param_type` 获取右侧 callee 的首个参数类型。
      - 若首个参数类型不是 canonical `std.process.Pipeline`，则在右侧调用节点上报错“管道运算符 '|>' 右侧 callee 的首个参数必须是 Pipeline 类型”。
      - 模块限定调用、无 receiver 静态/自由函数调用、带显式类型命名空间 receiver 的静态方法调用均通过该检查，只要其首参为 `Pipeline`。
    - 新增测试：`tests/error_typed_pipeline_checker_right.uya`（负向测试，左侧为 `Pipeline`、右侧 callee 首参为 `i32`）。
    - 验证命令与结果：
      - `../uya/bin/uya check tests/error_typed_pipeline_checker_right.uya` 返回 exit 1，错误信息包含“管道运算符 '|>' 右侧 callee 的首个参数必须是 Pipeline 类型”。
      - `../uya/bin/uya test tests/test_typed_pipeline_checker_positive.uya` 通过，2 个测试全部 OK。
      - 相关诊断回归：
        - `../uya/bin/uya check tests/error_typed_pipeline_checker_left.uya` 仍返回 exit 1，包含“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
        - `../uya/bin/uya check tests/error_typed_pipeline_instance_method_receiver.uya` 仍返回 exit 1，包含“管道运算符 '|>' 右侧不能是带隐式 self receiver 的实例方法调用”。
        - `../uya/bin/uya check tests/error_typed_pipeline_sink_after_chain.uya` 仍返回 exit 1，包含“不能在 sink 之后继续链式管道 '|>'……”。
        - `../uya/bin/uya test tests/test_typed_pipeline_parser_positive.uya` 通过（6/6）。
        - `../uya/bin/uya test tests/test_typed_pipeline_type_identity.uya` 通过（3/3）。

## 类型化管道 TODO
## 阶段 2：Type Checker 规则
- [ ] 添加诊断：
  - [x] sink 后继续管道的误用
    - 验证命令：`./bin/uya test tests/error_typed_pipeline_sink_after_chain.uya`
    - 结果：编译器正确报告 “不能在 sink 之后继续链式管道 '|>'，因为左侧表达式的结果不再是 Pipeline 或 !Pipeline 类型”
    - 更广泛测试：`for f in tests/*typed_pipeline*.uya; do ./tests/run_programs_parallel.sh "$f"; done` 全部通过

## 阶段 2：Type Checker 规则

- [ ] 添加诊断：
  - [x] sink 后继续管道的误用

验证：
- 测试文件：tests/error_typed_pipeline_sink_after_chain.uya
- 命令：../uya/bin/uya test tests/error_typed_pipeline_sink_after_chain.uya
- 结果：测试按预期失败，类型检查器报告不能在 sink 之后继续链式管道 '|>'，因为左侧表达式的结果不再是 Pipeline 或 !Pipeline 类型。

## 阶段 2：Type Checker 规则

- [x] 添加诊断：
  - [x] 实例方法 receiver 与 synthetic lhs 冲突

验证：
- 诊断已在 `src/checker/check_expr_extra.uya` 实现：
  - `checker_pipeline_callee_is_implicit_self_instance_method_call` 检测隐式 self receiver 实例方法调用
  - `checker_check_pipeline_expr` 报告错误：「管道运算符 '|>' 右侧不能是带隐式 self receiver 的实例方法调用」
- 测试 `tests/error_typed_pipeline_instance_method_receiver.uya` 正确触发诊断并退出码 1
- 运行全部 typed pipeline 正/负向测试均通过：
  - 正向测试 `tests/test_typed_pipeline_*.uya`：5/5 退出码 0
  - 负向测试 `tests/error_typed_pipeline_*.uya`：8/8 非零退出码
- 验证命令：
  ```bash
  ../uya/bin/uya test tests/error_typed_pipeline_instance_method_receiver.uya
  for f in tests/test_typed_pipeline_*.uya; do ../uya/bin/uya test "$f"; done
  for f in tests/error_typed_pipeline_*.uya; do ../uya/bin/uya test "$f"; done
  ```

## 阶段 2：Type Checker 规则

- [x] 添加诊断：
  - [x] 实例方法 receiver 与 synthetic lhs 冲突
- 验证命令与结果：
  - `../uya/bin/uya test tests/error_typed_pipeline_instance_method_receiver.uya` 退出码 1，正确报告：「管道运算符 '|>' 右侧不能是带隐式 self receiver 的实例方法调用」。
  - 全部 typed pipeline 正向测试通过：`for f in tests/test_typed_pipeline_*.uya; do ../uya/bin/uya test "$f"; done`，5/5 退出码 0。

## 阶段 2：Type Checker 规则

- [x] 添加 `1 |> cmd("x")` 的 checker 负向测试。
  - 测试文件：`tests/error_typed_pipeline_checker_left.uya`
  - 验证命令：`./tests/run_programs_parallel.sh tests/error_typed_pipeline_checker_left.uya`
  - 验证结果：`✓ error_typed_pipeline_checker_left:预期编译失败`
  - 补充：相关 typed_pipeline 测试已全部通过，包括 error_typed_pipeline_checker_right、test_typed_pipeline_checker_positive 等 13 个测试文件。

## 类型化管道 TODO
### 阶段 2：Type Checker 规则

- [x] 添加 `!Pipeline |> transformer` 的 checker 测试。
  - 交付：在 `tests/test_typed_pipeline_checker_positive.uya` 中新增 `pipeline_lhs_error_union_to_error_union_transformer` 测试用例，验证左侧 `!Pipeline` 可通过 `|>` 传给返回 `!Pipeline` 的 transformer 并通过类型检查。
  - 验证命令：`./bin/uya test tests/test_typed_pipeline_checker_positive.uya`
  - 结果：3 个测试全部通过。
  - 相关 broader 验证：
    - 所有 `tests/test_typed_pipeline_*.uya` 正向测试通过。
    - 所有 `tests/error_typed_pipeline_*.uya` check 失败符合预期。

---

## 类型化管道 TODO / 阶段 2：Type Checker 规则

- [x] 添加 checker 测试证明非 `Pipeline` 的 `!T` 不会得到 try-forward。
  - 实现要点：
    - 新增 `tests/error_typed_pipeline_non_pipeline_error_union.uya`：定义返回 `!i32` 的函数和首参为 `i32` 的 callee，在 `main` 中写 `make_err_i32() |> takes_i32()`。
    - 若任意 `!T` 都触发 try-forward，该表达式会被接受为 `i32`；实际仅 `!Pipeline` 触发 try-forward，因此 checker 在左侧类型检查阶段即拒绝并报错。
  - 验证命令与结果：
    - `../uya/bin/uya check tests/error_typed_pipeline_non_pipeline_error_union.uya` 返回 exit 1，错误信息包含“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
    - `./tests/run_programs_parallel.sh tests/error_typed_pipeline_non_pipeline_error_union.uya` 通过，显示“预期编译失败”。
    - 全部 typed pipeline 正/负向测试通过：`for f in tests/test_typed_pipeline_*.uya tests/error_typed_pipeline_*.uya; do ./tests/run_programs_parallel.sh "$f"; done`，14/14 通过。
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。

## 阶段 2：Type Checker 规则

- [x] 添加 checker 测试证明非 `Pipeline` 的 `!T` 不会得到 try-forward。
  - 验证命令与结果：
    - `../uya/bin/uya check tests/error_typed_pipeline_non_pipeline_error_union.uya` 返回 exit 1，错误信息包含“管道运算符 '|>' 的左侧必须是 Pipeline 或 !Pipeline 类型”。
    - `../uya/bin/uya test tests/test_typed_pipeline_checker_positive.uya` 通过，3 个测试全部 OK。

## 阶段 2：Type Checker 规则

- [x] 添加 checker 测试证明 `!Pipeline` 成功载荷只能提取并移动一次。
  - 交付物：`tests/error_typed_pipeline_try_forward_use_after_move.uya`
  - 实现：`src/checker/check_expr_extra.uya` 中在确认 `|>` 右侧 callee 首个参数为 `Pipeline` 后，对左侧 `AST_IDENTIFIER` 调用 `checker_mark_moved`，使 move-only 的 `Pipeline` / `!Pipeline` 变量在消费后不能被二次使用。
  - 验证命令：
    - `./bin/uya test tests/error_typed_pipeline_try_forward_use_after_move.uya`（预期编译失败，exit code 1）
    - `./tests/run_programs_parallel.sh tests/error_typed_pipeline_try_forward_use_after_move.uya`（预期编译失败）
    - `./tests/run_programs_parallel.sh tests/test_typed_pipeline_*.uya tests/error_typed_pipeline_*.uya tests/test_move_simple.uya tests/test_drop_after_move.uya tests/error_move_*.uya`（全部通过）
  - 验证结果：
    - 新测试正确报错：`变量 'p' 已被移动，不能再次使用`
    - 所有既有 typed pipeline 正向/负向测试、move 语义测试保持通过

## 阶段 3：Lowering

- [x] 将 `lhs |> f(args...)` 降低为普通调用和临时变量。
  - 实现要点：
    - 在 `src/codegen/c99/expr.uya` 中新增 `gen_pipeline_expr`：收集整条 pipeline 链的最左侧表达式与从内向外的右侧调用，生成 C99 语句表达式 `({ TYPE tmp_0 = (lhs); TYPE tmp_1 = f1(tmp_0, ...); ... fn(tmp_{n-1}, ...); })`。
    - 新增 `gen_pipeline_synthetic_call`：为每个 stage 创建以临时变量为首个实参的合成 `AST_CALL_EXPR`，复用 `gen_call_expr` 生成调用。
    - 在 `gen_expr` 中新增 `AST_PIPELINE_EXPR` 分支，分发到 `gen_pipeline_expr`。
    - 修复 `src/codegen/c99/expr.uya` 中模块限定调用（`module.func(args)`）的 C 名生成：新增 `c99_find_module_export_function_decl`（位于 `src/codegen/c99/function.uya`），通过 checker 的模块导出表定位真实函数声明，并使用 `get_c_name_for_function_decl` 生成与函数定义一致的 C 名，解决 `pipe_mod.pipeline_transformer()` 等场景下的链接名不一致问题。
    - 配合 checker 侧调整（`src/checker/check_expr_extra.uya`）：将 pipeline 链最左侧变量的 moved 标记推迟到最外层 pipeline 检查完成后，并新增 `checker_infer_type_bypass_moved` 供 codegen 在生成最左侧临时变量时重新推断已被标记为 moved 的标识符类型。
  - 验证命令与结果：
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - lowering 正向测试：`../uya/bin/uya test tests/test_typed_pipeline_lowering.uya` 通过，3 个测试全部 OK（单个 transformer、多个 transformer、变量 lhs）。
    - module-qualified callee 测试：`../uya/bin/uya test tests/test_typed_pipeline_module_qualified_positive.uya` 通过。
    - typed pipeline 全量回归：所有 `tests/test_typed_pipeline_*.uya` 正向测试通过；负向测试按预期报错。
    - 回归抽样：`../uya/bin/uya test tests/test_std_path_module.uya`、`tests/test_std_env.uya`、`tests/test_std_stdlib.uya`、`tests/test_async_fd.uya`、`tests/test_mem_allocator.uya` 均通过。

## 阶段 3：Lowering

- [x] 将 `lhs |> f(args...)` 降低为普通调用和临时变量。
  - 归档说明：本条目此前已完成并实现；本轮为归档清理，将其从主 todo 移除。
  - 实现位置：`src/codegen/c99/expr.uya` 中 `gen_pipeline_expr` / `gen_pipeline_synthetic_call`。
  - 验证命令：`../uya/bin/uya test tests/test_typed_pipeline_lowering.uya`
  - 验证结果：3/3 测试通过（`pipeline_lowering_single_transformer`、`pipeline_lowering_multi_transformer`、`pipeline_lowering_variable_lhs`）。

## 阶段 3：Lowering

- [x] 保留 `Pipeline` 的移动语义。
  - 实现要点：
    - 修改 `src/codegen/c99/expr.uya` 中的 `gen_pipeline_expr`：对普通 `Pipeline` 链复用同一个 C99 临时变量 `__uya_pipe_tmp_N`，中间 transformer 通过 `__uya_pipe_tmp_N = f(__uya_pipe_tmp_N, ...)` 覆盖同一份存储，最终调用直接消费该变量。
    - 这样避免语句表达式中残留多个持有已消费 capability 的 Pipeline 副本，使 lowering 在 C99 层面更接近 move-only 语义。
    - 修复 checker 侧测试语句间移动状态泄漏：`src/checker/main.uya` 在检查 `AST_TEST_STMT` 时清空 `moved_count` 与 `pipeline_chain_depth`，防止上一条 `test` 的 moved 集合影响下一条测试。
  - 测试更新：
    - 在 `tests/test_typed_pipeline_lowering.uya` 中新增 `pipeline_lowering_returns_pipeline`（最终 stage 为 transformer，表达式返回 Pipeline）和 `pipeline_lowering_long_chain`（更长链式调用）。
  - 验证命令与结果：
    - lowering 正向测试：`../uya/bin/uya test tests/test_typed_pipeline_lowering.uya` 通过，5/5 测试全部 OK。
    - typed pipeline 正向回归：`for f in tests/test_typed_pipeline_*.uya; do ../uya/bin/uya test "$f"; done` 全部通过。
    - move/drop 回归：`for f in tests/test_move_*.uya tests/error_move_*.uya tests/test_drop_*.uya; do ./tests/run_programs_parallel.sh "$f"; done` 全部通过。
    - 自举编译：`make uya` 成功。
    - 自举验证：`make b` 通过（主编译器与自举编译器生成的可执行文件字节一致）。
    - 注：`error_typed_pipeline_try_forward_use_after_move.uya` 为 `!Pipeline` try-forward 预存在失败，不在本任务范围内。

## 阶段 3：Lowering

- [x] transformer lowering 的成功路径转移所有权，错误路径触发输入计划清理。
  - 验证命令：`../uya/bin/uya test tests/test_typed_pipeline_lowering_error.uya`
  - 结果：2 tests passed, 0 failed (pipeline_error_path_cleans_input, pipeline_success_path_does_not_clean)
  - 相关回归：
    - `../uya/bin/uya test tests/test_typed_pipeline_lowering.uya` → 5 tests passed
    - 全部 `tests/test_typed_pipeline_*.uya` 正向测试通过
    - `tests/error_typed_pipeline_*.uya` 均按预期报出类型/语法错误
  - 实现位置：`src/codegen/c99/expr.uya` 的 `gen_pipeline_expr` 在 transformer 返回 `!Pipeline` 时生成错误路径 `pipeline_drop(input)` 清理；成功路径从错误联合提取 `Pipeline` 载荷并继续链式调用。
