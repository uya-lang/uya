# 发版流程（v0.12.0 起自动化）

本文件描述一次版本发布的完整动作，以及「**打 tag 的提交通过 CI 之后才发布**」这条闸门
是怎么落地的。日常改代码不需要读它。

---

## 一、一句话版本

```bash
# 1. 改版本号、写发行说明、跑全量验证（详见第二节）
git commit -am "release: vX.Y.Z"
git tag -a vX.Y.Z -F /tmp/tag-vX.Y.Z.txt
git push origin main
git push origin vX.Y.Z     # ← 这一下之后全自动：CI 跑 → 全绿 → GitHub Release 自动发布
```

标签推进去之后不需要再手动点任何东西。反过来说，**CI 没全绿就绝不会发出 Release**：
发布工作流会拒绝发布并把原因写进 job 的报错注解。

---

## 二、发版前的人工步骤

1. **版本号**：`src/version.uya` 的 `UYA_VERSION` 是唯一事实来源，其它地方都指向它。
2. **发行说明**：新建 `docs/releases/RELEASE_vX.Y.Z.md`。
3. **同步引用**：`CHANGELOG.md` 加 `## vX.Y.Z - <标题>` 段；`readme.md` 的「当前状态」
   与页脚、`docs/comparison.md`、`docs/compile_time_optimization_status.md` 的版本号。
4. **版本一致性闸门**：

   ```bash
   bash tests/verify_version_sources.sh     # 期望输出 version sources ok (X.Y.Z)
   ```

5. **全量验证**（必须干净工作树）：

   ```bash
   make release
   ```

   `make release` = `clean` 冷启动 → `make uya` → `make b` 自举对比 → `make check`
   → 刷新单文件种子 → `-O3 -DNDEBUG` + `strip` 的发布构建。
6. **提交与打标签**：种子刷新（`backup/uya*.c`）必须和代码改动在同一个提交里；
   标签用 annotated tag，正文写明里程碑、主线与验证结论。

---

## 三、CI 与自动发布

```
push tag vX.Y.Z
      │
      ├─ ubuntu-ci   （在该标签的提交上跑完整 make release）
      ├─ macos-ci    （在该标签的提交上跑 hosted 主线）
      │
      └─ 任一轮结束 ──► release-publish (.github/workflows/release-publish.yml)
                            │
                            ├─ 轮询该标签上的 ubuntu-ci / macos-ci 结论
                            ├─ 有任何一条 failed / cancelled ──► 拒绝发布（报错退出）
                            ├─ 等满 2 小时仍未出结论 ────────► 拒绝发布（报错退出）
                            ├─ 标签提交不在 main 上 ─────────► 拒绝发布（报错退出）
                            └─ 全部 success ─────────────────► gh release create
```

要点：

- 两个 CI workflow 都有 `tags: [ "v*" ]` 触发，所以**标签提交自己会跑一轮**；
  发布工作流只看 `headBranch == <tag>` 的 push run，main 上同名 workflow 的成功不能替代。
- 发行说明取自 `docs/releases/RELEASE_<tag>.md`；文件缺失时拒绝发布
  （缺发行说明的版本不允许发）。
- 标签带后缀（如 `v0.13.0-rc1`）时自动标记为 **pre-release**。
- 重复执行是幂等的：Release 已存在时走 `gh release edit` 更新标题与说明，不会报错。

### 失败之后怎么补发

| 情况 | 处理 |
| --- | --- |
| CI 抖动（超时、runner 被回收） | Actions 里 **Re-run jobs**，结束后发布工作流会再被唤醒 |
| 修了代码要重发同一版本 | 不建议复用旧标签；改版本号重新走第二节 |
| 只想补/改 Release 说明 | Actions → `release-publish` → **Run workflow**，填 `tag`（可先开 `dry_run` 演练） |
| 历史标签（推送时还没有本工作流，如 v0.12.0） | 重推标签即可补跑 CI 并自动发布：`git push origin :refs/tags/vX.Y.Z && git push origin vX.Y.Z` |

> 历史标签那条之所以要重推：发布工作流只认「这个标签自己跑过一轮 CI」，
> 没有标签上的 CI 结论就一律拒绝（`missing`），不会拿 main 上的成功来顶替。

### 权限

发布工作流只需要仓库自带的 `GITHUB_TOKEN`（`contents: write` 建 Release、`actions: read`
查 CI 结论），不需要额外 secret。若仓库策略把 `GITHUB_TOKEN` 设为只读，需要
Settings → Actions → Workflow permissions 改成 "Read and write"。

---

## 四、回滚

GitHub Release 只是发布出口，回滚分两层：

- **撤回发布**：Actions 手动触发或本地 `gh release delete vX.Y.Z`（标签与提交不受影响）。
- **撤回版本**：删除标签 `git push origin :refs/tags/vX.Y.Z` 与 `git tag -d vX.Y.Z`，
  代码按常规 revert。已发布的 Release 需同时删除，否则会指向不存在的标签。

---

## 五、相关文件

- `.github/workflows/ubuntu-ci.yml`、`.github/workflows/macos-ci.yml`：CI（含 `tags: [ "v*" ]`）
- `.github/workflows/release-publish.yml`：CI 全绿后自动发布
- `src/version.uya`、`tests/verify_version_sources.sh`：版本号与一致性闸门
- `docs/releases/RELEASE_v*.md`：发行说明（Release 正文来源）
- `Makefile` 的 `release` / `release-flow` / `backup-all` 目标：本地发版验证
