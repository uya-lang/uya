# 类型化管道 TODO
## 阶段 1：Lexer 与 Parser 骨架

- [x] 添加 `|>` token。

验证：
- 修改 `src/lexer.uya`：在 `TokenType` 枚举添加 `TOKEN_PIPE_GT`；在扫描 `|` 的分支中优先识别 `|>`，再识别 `||`，最后回退到 `|`。
- 命令：`make uya`
- 结果：自举编译器构建成功。
- 命令：`../uya/bin/uya check /tmp/test_pipe_gt.uya`
- 结果：报“语法分析失败：意外的 token '|>'”，证明 lexer 将 `|>` 识别为单一 token，而非 `|` 与 `>`。
- 命令：`../uya/bin/uya run /tmp/test_pipe_single.uya`（包含 `a | b` 与 `true || false`）
- 结果：返回码 3，证明 `|` 与 `||` 仍然正常工作。
- 命令：`../uya/bin/uya test tests/test_exec_vm_bitwise.uya` 与 `../uya/bin/uya test tests/test_exec_vm_short_circuit.uya`
- 结果：均通过。

