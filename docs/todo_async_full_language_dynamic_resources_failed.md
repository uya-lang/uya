# Uya 异步生产化 TODO（完整语法 + 动态资源）失败归档

归档时间：2026-06-22

## 当前状态

当前没有有效失败项。

## 已清理的过期失败记录

- `tests/test_async_large_state_machine_syntax.uya`
  - 清理原因：该测试文件当前已存在，并已纳入 `tests/verify_async_full_language_matrix.sh` 的 baseline；完成归档中也已有对应通过记录。
  - 当前口径：它不是失败项，而是 async 大状态机 / 多 await / for range 覆盖的一部分。
  - 后续重开条件：只有在相关验证命令重新失败、且能记录具体命令和错误输出时，才应作为新的失败项写回本归档。
