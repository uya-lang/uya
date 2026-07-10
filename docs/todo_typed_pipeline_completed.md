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

