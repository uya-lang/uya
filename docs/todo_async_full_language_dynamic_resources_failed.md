# Uya 异步生产化 TODO（完整语法 + 动态资源）失败归档

归档时间：2026-06-20

# Uya 异步生产化 TODO（完整语法 + 动态资源）
## Phase 1：`@async_fn` 语法完整性
### 1.2 先补红测，再动实现

- [f] 新增 `tests/test_async_large_state_machine_syntax.uya`
  - 失败原因：主 todo 仅遗留 `[f]` 状态，未记录原始失败原因；当前仓库已存在同名测试文件，现状与该失败标记不一致，本轮只按归档清理要求移出主 todo。
  - 阻塞命令：未记录。
  - 关键错误：未记录。
  - 后续重开条件：如需继续追踪，重新以新任务立项，并补充真实失败命令、错误输出，或先核对当前仓库中 `tests/test_async_large_state_machine_syntax.uya` 与相关矩阵覆盖是否已满足原目标。
