# 类型化管道 TODO — 完成归档

> 本文件记录已完成并验证的任务，从 `docs/todo_typed_pipeline.md` 移入。

---

## 阶段 0：规格锁定

- [x] 按当前 Uya grammar 和接口语法复核 `typed_pipeline_design.md`。
  验证：已在归档前完成并验证。

---

- [x] 在 `std_script_design.md` 中添加一个短章节链接到本设计。
  验证：已在归档前完成并验证。

---

## 阶段 9：文档与稳定性门禁

- [x] 更新 `std_script_design.md`。
  验证：已在归档前完成并验证。

---

## 阶段 0：规格锁定

- [x] 确定最终名称：
  - [x] `pipeline`（空管道构造器最终名称为 `pipeline()`，`empty_pipeline` 废弃）
    验证：复核 `docs/typed_pipeline_design.md` L126-L131、L196，以及 `docs/std_script_design.md` L238 均使用 `pipeline()`；无 `.uya` 实现引用任一候选名。
