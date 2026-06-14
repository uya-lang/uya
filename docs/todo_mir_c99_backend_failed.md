# MIR-C99 Backend Failed Archive

**来源**: `docs/todo_mir_c99_backend.md`
**整理日期**: 2026-06-13
**说明**: 本文件保存从主 TODO 移出的失败项及其阻塞原因、复现命令和后续重开条件；若失败项已在后续修复，会在原条目处标记 `[x]` 并记录修复复验。

---

## 任务清单失败项

### 4.15 Full Language Parity

- （上下文，原状态 [ ]）MIR-C99-BACKEND-PARITY-MATRIX：把完整语言样本逐项迁为 MIR-C99 / 现有 C99 oracle parity。
  - [x] multi-file module/use/import alias。
    - 修复复验（2026-06-14）：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 成功刷新 `bin/cmd/build`，未再复现旧 `FUNCTION_TABLE_SIZE` 阻塞；`bash tests/verify_mir_c99_full_language_multifile_use_parity.sh` 通过，覆盖 `use dep.exported_sum; exported_sum(...)` 与 `use dep as d; d.exported_sum(...)` 两个 shard。手工 alias oracle probe 生成 `int32_t exported_sum(int32_t x, int32_t y)` 原型和函数体，未命中 `unknown(`，host C 链接后运行返回 0。
    - 失败复验（2026-06-13）：`bash tests/verify_mir_c99_full_language_multifile_use_parity.sh` 通过，确认已完成的 `use dep.exported_sum;` item import shard 未回退；手工 alias oracle probe 使用 `bash ./tests/c99_oracle_generate.sh /tmp/uya-mir-c99-alias.O1LlaN/main.uya /tmp/uya-mir-c99-alias.O1LlaN/oracle.c /tmp/uya-mir-c99-alias.O1LlaN/oracle.log --project-root /tmp/uya-mir-c99-alias.O1LlaN` 生成现有 C99 oracle，再运行 `rg -n 'unknown\(' /tmp/uya-mir-c99-alias.O1LlaN/oracle.c` 命中 `const int32_t sum = unknown(20, 22);`，`cc -std=c99 -Wall -Wextra -pedantic /tmp/uya-mir-c99-alias.O1LlaN/oracle.c -o /tmp/uya-mir-c99-alias.O1LlaN/oracle.bin` 失败于 `undefined reference to 'unknown'`。该聚合项仍被子任务 `whole-module import alias parity` 的现有 C99 oracle 阻塞，未声称 MIR-C99 alias parity 完成。
    - [x] whole-module import alias parity：现有 C99 oracle 已避免将 `use dep as d; d.fn()` 降成 unresolved `unknown(...)`。
      - 修复说明（2026-06-14）：C99 codegen 现在会从 whole-module import alias / `member_access_module_name` 解析 `module_alias.fn` 的导出函数声明，按函数声明发射调用参数，并在 precollect 阶段把该导出函数标记为 reachable，避免只生成调用而漏发函数体；MIR-C99 parity subset writer 同步识别最小 `use module as alias; alias.fn(i32, i32)` 形状。
      - 失败原因（2026-06-12）：新增最小 `use dep as d; d.exported_sum(20, 22)` 探针后，`C99_ORACLE_GENERATE_CMD="bash ./tests/c99_oracle_generate.sh {input} {output} {log} --project-root <case-root>" bash tests/verify_mir_c99_oracle_parity_harness.sh --case <case>/main.uya --keep-tmp` 复现现有 C99 oracle 生成 `const int32_t sum = unknown(20, 22);`，host C 链接失败于 `undefined reference to 'unknown'`。
      - 恢复尝试：在 `src/codegen/c99_build/expr.uya` / `src/codegen/c99/expr.uya` 内联 whole-module alias import-table 解析，并给 `tests/mir_c99_generate.sh` / `tests/verify_mir_c99_full_language_multifile_use_parity.sh` 增加 alias parity case；但刷新 oracle 所需的 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 被当前旧 `./bin/uya` 自身的固定函数表容量阻塞，报 `src/codegen/mir_c99/plan.uya:(298:8): 错误: 函数表容量不足，请增大 FUNCTION_TABLE_SIZE`，无法产出新的 `bin/cmd/build` 验证修复。
      - 本轮未提交未验证通过的生产/测试改动；后续需先用可恢复的 seed/新编译器解决旧二进制函数表容量，再重开该 parity 叶。
