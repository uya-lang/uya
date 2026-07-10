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
