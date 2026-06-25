# Uya 包管理规范完善 TODO

**状态**: executable TODO, specification + staged implementation pending
**更新日期**: 2026-05-29
**关联文档**: `docs/uya.md`、`docs/todo_cmd_subcommand_split.md`、`docs/cmd_subcommand_split_design.md`

---

## 当前基线

- `docs/uya.md` 目前只在 §29.1 简单提到“官方包管理器：`uyapm`”，还没有正式规范。
- 当前模块解析真实行为来自 `src/driver/modules.uya`：
  - 仅按 `project_root -> UYA_ROOT` 查找模块。
  - 还没有 manifest、lockfile、外部依赖根目录或包别名表。
- 当前“项目根目录”语义与包管理预期存在冲突：
  - 文档写的是“包含 `main` 函数的目录”。
  - 实现里已经存在 `--project-root` 支持，但文档仍写“不支持显式指定项目根目录”。
  - 旧草案直接假定了 `uya.toml + src/ + deps/`，没有先解决 package root 和 module root 的映射关系。
- `docs/cmd_subcommand_split_design.md` 与 `docs/todo_cmd_subcommand_split.md` 已经为 `upm` 预留了骨架，但以下内容仍未落地：
  - `src/cmd/upm/main.uya`
  - `make cmds` / `bin/cmd/upm`
  - `dispatch_external_cmd(... upm ...)`
  - `tests/test_cmd_upm_direct.sh` 中的 `upm` 入口验证
- 当前仓库里没有通用 TOML 解析器；如果坚持 `uya.toml`，要么先实现 manifest 子集解析器，要么把通用 TOML 库拆成独立前置任务。

这意味着本计划的第一优先级不是“直接写字段”，而是先冻结以下关系：

- `package root`
- `source root`
- 当前实现里的 `project_root`
- `upm` / `uyapm` 的命名与调用入口
- 依赖安装目录与模块查找顺序

---

## 总体目标

- 为 Uya 定义一套与现有模块系统兼容的包管理规范，而不是另起一套与当前编译器割裂的理想模型。
- v1 先补齐：
  - `uya.toml`
  - `uya.lock`
  - `path` / `git` 依赖
  - 外部包模块查找规则
  - `upm` 基础命令
- 保留当前无 manifest 的工作流：
  - `uya build file.uya`
  - `uya build dir/`
  - `uya run/test/check ...`
- 在规范和实现都稳定前，不承诺：
  - 中央注册表
  - 多版本并存
  - semver range 求解
  - workspaces
  - publish 流程

---

## 执行原则

- 先读当前实现，再写规范；不要把计划建立在不存在的语法或隐藏假设上。
- 先冻结术语和目录语义，再定义 manifest 字段和 lockfile 格式。
- 文档先行、测试先行、实现后置；避免“文档写一套，实现做另一套”。
- 以最小闭环推进：
  - Phase 1：规范 + 示例
  - Phase 2：manifest + path 依赖
  - Phase 3：git 依赖 + lockfile
  - Phase 4：`upm` CLI 和回归测试
- 所有需要联网的 Git 依赖测试都必须使用本地 fixture 仓库或本地 bare repo，避免测试依赖公网。
- 如果会改变模块路径解析或“项目根目录”含义，必须同步更新 `docs/uya.md`；若语言语法本身不变，则无需改 BNF。

---

## 设计冻结前必须回答

- [x] `package root`、`source root`、当前 `project_root` 是否拆成三个显式概念。
- [x] v1 是否默认 `source-dir = "."` 以兼容当前编译器，再把 `src/` 布局作为可选项，而不是反过来。
- [x] Canonical CLI 名称到底是 `uya upm`、`upm` 还是 `uyapm`；是否允许安装别名。
- [x] 依赖安装目录是否使用 `deps/`，还是隐藏目录（如 `.uya/deps/`）；下载缓存是否与 vendor 目录分离。
- [x] manifest 中 `[dependencies]` 的 table key 是否就是 import 前缀；若与实际 `package.name` 不同，冲突和诊断规则是什么。
- [x] v1 是否只支持 exact refs：
  - [x] `path`
  - [x] `git + tag`
  - [x] `git + branch`
  - [x] `git + commit`
- [x] `upm build` 是否直接构建 source root 目录，还是需要 manifest 中显式 entry 字段。
- [x] path 依赖与 git 依赖是否都要求依赖包自身必须包含 `uya.toml`。
- [x] v1 是否明确禁止“同一 import 前缀的多版本并存”。

---

## 推荐的 v1 冻结方案

以下建议可以作为规范初稿的默认方向，除非评审后决定调整：

- `package root`：包含 `uya.toml` 的目录。
- `source root`：`[package].source-dir` 指定，默认 `"."`。
- `module root`：编译器真正用于模块查找的目录；对包项目来说等于 `package root + source-dir`。
- `legacy mode`：找不到 `uya.toml` 时，继续沿用当前“输入文件/包含 `main` 的目录就是项目根目录”的行为。
- v1 依赖源仅支持：
  - `path`
  - `git`
- v1 不支持多版本并存；冲突直接报错。
- v1 规范只定义“如何声明/解析/锁定依赖”，不引入中央 registry。
- 仓库内命令入口先统一为 `uya upm` / `cmd/upm`；是否额外安装 `uyapm` 作为别名放到后续阶段。
- `upm build` 首版直接把 source root 目录交给现有 build 流程，让当前“目录中唯一 `main`”逻辑继续发挥作用；不急着引入 manifest entry 字段。

---

## 非目标

- 不在本轮实现中央注册表或包发布站点。
- 不在 v1 中支持 semver range 求解、版本回溯、依赖 SAT solver。
- 不在 v1 中支持 workspaces / monorepo 多包统一锁定。
- 不在 v1 中支持同一 import 前缀的多版本并存。
- 不在 v1 中设计二进制包、预编译缓存、签名校验、镜像源和离线索引。
- 不要求第一阶段就让 `uya build/run/test` 完全依赖 `upm`；无 manifest 旧路径必须继续可用。

---

## Phase 0：基线核对与术语冻结

- [x] 重新阅读并摘录当前真实语义：
  - [x] `src/driver/modules.uya`
  - [x] `src/main.uya`
  - [x] `docs/uya.md` 中 1.5 模块系统和 29.1 包管理占位
  - [x] `docs/todo_cmd_subcommand_split.md`
  - [x] `docs/cmd_subcommand_split_design.md`
- [x] 明确记录“文档语义”和“当前实现”之间的矛盾点：
  - [x] 文档说项目根目录不能显式指定
  - [x] 实现里已有 `--project-root`
  - [x] 文档只认识 `main` 所在目录
  - [x] 旧计划假定 package root 可以是 `main` 的父目录
- [x] 输出一份术语表，至少覆盖：
  - [x] package root
  - [x] source root
  - [x] module root
  - [x] dependency root
  - [x] install/vendor directory
  - [x] lockfile
- [x] 冻结 v1 支持边界：
  - [x] 支持 `path` / `git`
  - [x] 不支持 registry / publish / workspace / multi-version
- [x] 冻结 public 命名：
  - [x] `upm`
  - [x] `uyapm`
  - [x] `uya upm`
- [x] 把以上决策先写进本计划或 `docs/package_management.md` 的“术语与范围”章节，避免后续反复改口。

**建议检查命令**:

```bash
rg -n "项目根目录|UYA_ROOT|project-root|官方包管理器|upm|uyapm" \
  docs/uya.md src/main.uya src/driver/modules.uya \
  docs/todo_cmd_subcommand_split.md docs/cmd_subcommand_split_design.md
```

---

## Phase 1：规范文档骨架

- [x] 新建 `docs/package_management.md`，先写完整目录，不急着一口气填满实现细节。
- [x] 文档首段明确状态：
  - [x] `design draft`
  - [x] `MVP planned`
  - [x] 哪些已实现，哪些尚未实现
- [x] 先落章节骨架：
  - [x] 术语
  - [x] 目标与非目标
  - [x] 目录布局与 root 语义
  - [x] `uya.toml`
  - [x] `uya.lock`
  - [x] 依赖源模型
  - [x] 模块解析扩展
  - [x] CLI 工作流
  - [x] 错误与诊断
  - [x] 与 legacy 模式兼容
- [x] 把“旧工作流仍可用”的兼容策略写清楚，避免用户误以为以后只能通过 manifest 构建。
- [x] 在文档中单列“未实现项”，防止规范写成“已经存在”的口吻。

---

## Phase 2：目录语义与项目根目录收口

这是整个计划的关键前置阶段，必须优先写清楚。

- [x] 定义 `package root` 与 `source root` 的关系：
  - [x] `uya.toml` 放哪
  - [x] 源码默认从哪找
  - [x] `source-dir = "."` 和 `source-dir = "src"` 是否都允许
- [x] 定义 `module root` 与当前 `project_root` 的关系：
  - [x] 是否把 `project_root` 在实现层重命名为更准确的 `module_root`
  - [x] 是否只在 CLI 层保留 `--project-root`，对用户文档改成更清晰的 `--manifest-path` / `--source-root`
- [x] 定义 manifest 发现规则：
  - [x] 当前目录向上查找 `uya.toml`
  - [x] 显式 `--manifest-path`
  - [x] 找不到 manifest 时回退 legacy mode
- [x] 定义以下布局示例，并写进文档：
  - [x] flat layout
  - [x] `src/` layout
  - [x] 仅库包（无 `main`）
  - [x] 带 `deps/` 或 vendor 目录的项目
- [x] 明确 source root 相对路径基准：
  - [x] 相对 manifest 所在目录
  - [x] 必须是 package root 内部路径，还是允许 `../src`
- [x] 明确冲突策略：
  - [x] 本地顶层模块名与依赖别名冲突时如何处理
  - [x] 多个依赖声明同一 import 前缀时如何报错

**Phase 2 验收**:

- [x] 文档能明确回答“`uya.toml` 在仓库根，源码在 `src/` 时，模块根目录到底是哪一层”。
- [x] 文档能明确回答“没有 manifest 的单文件/单目录项目是否还能构建”。

---

## Phase 3：`uya.toml` 规范

- [x] 冻结 manifest 最小字段集合，建议首版只保留必要字段：
  - [x] `[package].name`
  - [x] `[package].version`
  - [x] `[package].source-dir`（可选，默认 `"."`）
  - [x] `[package].description`（可选）
  - [x] `[package].license`（可选）
  - [x] `[package].repository`（可选）
- [x] 明确 `[dependencies]` 与 `[dev-dependencies]` 的语义差异。
- [x] 冻结依赖声明格式，建议 v1 仅支持显式 table，不支持字符串 shorthand：

```toml
[dependencies]
http = { path = "../http" }
json = { git = "https://example.com/json.git", tag = "v1.2.3" }
util = { git = "ssh://git@example.com/util.git", commit = "abc123" }
```

- [x] 定义同一依赖里 `tag` / `branch` / `commit` 只能三选一。
- [x] 定义 path 依赖的路径基准为 manifest 所在目录。
- [x] 明确依赖包自身是否必须包含 `uya.toml`。
- [x] 明确 package 名合法字符、import alias 合法字符、大小写策略。
- [x] 若保留 `authors`、`build` 等字段，必须标注是 v1 必需还是“保留字段，后续实现”。

**实现建议**:

- [x] 若仓库内暂无通用 TOML 解析器，先实现“manifest TOML 子集解析器”，不要把“通用 TOML 标准库”硬塞进本任务。
- 若未来决定做通用 TOML 库，应把它拆成独立前置 TODO，并在本计划里显式依赖它。

---

## Phase 4：`uya.lock` 规范

- [x] 定义 lockfile 是否采用 TOML；建议保持与 manifest 同格式。
- [x] 定义 lockfile 顶层版本字段，例如：

```toml
version = 1

[[package]]
name = "http"
source = { kind = "git", url = "https://example.com/http.git", commit = "..." }
source_dir = "."
dependencies = ["util"]
```

- [x] 明确 `branch` / `tag` 在 lockfile 中都必须落成精确 commit。
- [x] 明确 path 依赖如何记录：
  - [x] 记录原始相对路径
  - [x] 记录规范化绝对路径
  - [x] 是否记录 manifest hash / mtime
- [x] 明确 lockfile 何时更新：
  - [x] `install`
  - [x] `update`
  - [x] `add/remove`
  - [x] `build` 是否允许隐式生成
- [x] 明确 lockfile 缺失或过期时的行为：
  - 当前冻结结果不是“报错”
  - [x] 自动重解
  - 当前冻结结果也不是“仅在 install/update 时写回”
- [x] 明确 lockfile 是否应该手动编辑；建议明确“不应手动编辑”。

**必须写清楚的约束**:

- [x] lockfile 保证的是“可重现版本解析”，不是“下载源永久可用”。
- [x] v1 不做 checksum / signature / registry mirror。

---

## Phase 5：依赖解析与模块查找规则

- [x] 把当前查找顺序从“`project_root -> UYA_ROOT`”扩展为包感知模型。
- [x] 冻结推荐顺序：
  1. [x] root package 的 source root
  2. [x] 已解析依赖的安装目录 / vendor 目录
  3. [x] `UYA_ROOT`
  4. [x] 编译器内置目录（若保留）
- [x] 明确依赖模块路径映射：
  - [x] `use http.client;` 对应哪个依赖根
  - [x] 是 `deps/http/client.uya`
  - [x] 还是 `deps/http/src/client.uya`
- [x] 明确“目录模块”和“文件模块别名”在依赖包里是否保持与 root package 一致。
- [x] 明确冲突策略：
  - [x] 本地模块 `http.*` 与依赖别名 `http` 冲突时
  - [x] 两个依赖都想占用 `http` 前缀时
  - [x] 依赖包名与 alias 不一致时
- [x] 明确 v1 版本冲突处理：
  - [x] 同一 import 前缀要求不同 commit/tag/branch 时直接报错
  - [x] 不支持 side-by-side 多版本目录
- [x] 明确循环依赖边界：
  - [x] 模块内循环依赖沿用当前规则
  - [x] 包级依赖循环是否直接拒绝

**实现落点建议**:

- MVP 当前采用“先组装临时 build root，再复用现有 `module_root -> UYA_ROOT` 查找”的实现路径，因此暂未要求把 `src/driver/modules.uya` 改造成多根 resolver 列表。
- 若后续继续演进长期 resolver 架构，再考虑引入 `PackageResolver` / `DependencyGraph` / `ResolvedPackage` 一类数据结构，而不是继续把逻辑塞进 `find_module_file(...)`。

---

## Phase 6：manifest 解析与 path 依赖 MVP

这是第一个真正值得落代码的闭环。

- [x] 先写测试夹具：
  - [x] 一个 flat layout 根包
  - [x] 一个 `src/` layout 根包
  - [x] 一个 path dependency 库包
  - [x] 一个 alias 冲突错误样例
  - [x] 一个缺失 `uya.toml` 错误样例
- [x] 先补验证脚本，再写实现：
  - [x] `tests/verify_upm_manifest_flat.sh`
  - [x] `tests/verify_upm_manifest_src.sh`
  - [x] `tests/verify_upm_path_dep.sh`
  - [x] `tests/verify_upm_alias_conflict.sh`
- [x] 实现 `uya.toml` 最小解析器。
- [x] 实现 manifest 发现逻辑与 source root 计算。
- [x] 实现 path 依赖递归解析。
- [x] 扩展模块查找，使 path 依赖的模块前缀可被 `build/check/run/test` 识别。
- [x] 首版可以不做共享缓存，先把依赖直接展开到项目本地 vendor 目录。
- [x] 明确 path 依赖对符号链接、越界路径、循环引用的安全限制。

**Phase 6 验收**:

- [x] `uya build` 能在带 `uya.toml` 的根包中构建 path 依赖。
- [x] 无 manifest 的旧样例不回归。
- [x] 错误信息能指出：
  - [x] 缺失 manifest
  - [x] 依赖 alias 冲突
  - [x] path 无效
  - [x] 依赖包缺少 `uya.toml`

---

## Phase 7：Git 依赖与 `uya.lock`

- [x] 为 Git 依赖设计完全离线可测的测试方案：
  - [x] 在 `tests/fixtures/` 中创建本地 git repo
  - [x] 或测试时动态初始化 bare repo
  - 当前实现改为“复制仓库内 bare fixture 到临时目录，再在临时 worktree 中生成测试所需的新 commit”，既保持完全离线，也避免污染跟踪中的 fixture。
- [x] 冻结 Git 解析策略：
  - [x] `tag`
  - [x] `branch`
  - [x] `commit`
- [x] 冻结 Git 工作流：
  - [x] clone 到临时目录或缓存目录
  - [x] checkout 指定 ref
  - [x] 解析该版本的 `uya.toml`
  - [x] vendor 到项目依赖目录
- [x] 决定是直接使用系统 `git`，还是长期目标改成原生实现；v1 推荐直接使用系统 `git`。
- [x] 若用系统 `git`：
  - [x] 优先使用 `os_spawn` / `execve`
  - [x] 保持所有用户输入都经过独立参数传递或安全引用，避免直接拼进未转义 shell 字符串
- [x] 实现 lockfile 生成与读取。
- [x] 支持“`branch` 解析后落 commit，后续 `build/install` 默认读 lockfile”的可重现行为。
- [x] 支持 `update` 刷新 branch/tag 对应的新 commit。
- [x] 完成冲突检测：
  - [x] 同一 alias 指向不同源
  - [x] 同一包要求不同 ref
  - [x] 传递依赖冲突

**Phase 7 验收**:

- [x] 本地 Git fixture 能稳定通过，不依赖公网。
- [x] 删除 vendor 目录后，仍可根据 lockfile 重建依赖。
- [x] branch 更新前后，`install` 与 `update` 行为可预测且文档一致。

---

## Phase 8：`upm` CLI 与工作流

- [x] 先落地 `src/cmd/upm/main.uya` 的最小骨架，保持与 `docs/todo_cmd_subcommand_split.md` 一致：
  - [x] `--help`
  - [x] `--version`
  - [x] 未实现命令给出明确提示
- [x] 统一 public UX：
  - [x] `uya upm <subcommand>`
  - [x] 是否额外提供 `upm` / `uyapm` 可执行别名
- [x] 冻结 MVP 子命令范围，建议首轮只做：
  - [x] `init`
  - [x] `install`
  - [x] `update`
  - [x] `build`
  - `add` 暂放第二批
  - `remove` 暂放第二批
- [x] 明确 `upm build` 与 `uya build` 的关系：
  - [x] 是 wrapper
  - [x] 还是独立逻辑
- [x] `upm init` 需要决定：
  - [x] 默认 flat layout
  - [x] 还是可选生成 `src/` layout
- [x] `upm add` 需要决定：
  - [x] 是否直接改写 manifest
  - [x] 是否自动写 lockfile
  - [x] 是否立即 install
- [x] `upm install/update` 需要决定：
  - [x] 是否在当前目录向上查找 manifest
  - [x] 是否支持 `--manifest-path`

**联动任务**:

- [x] 同步 `Makefile`、安装布局和 `cmd` 调度测试。
- [x] 若最终 CLI 公开名不是 `uyapm`，必须在 `docs/uya.md` 中解释它和 `upm` 的关系，避免文档分裂。

---

## Phase 9：文档同步、示例与回归测试

- [x] 更新 `docs/uya.md`：
  - [x] 模块系统章节补“package root / source root / legacy mode”
  - [x] §29.1 包管理器占位改成真实状态说明
- [x] 新建或完善 `examples/package_example/`：
  - [x] flat layout
  - [x] `src/` layout
  - [x] path 依赖示例
- [x] 在示例 README 中明确哪些命令今天已可运行，哪些仍是规划。
- [x] 补测试夹具目录，例如：
  - [x] `tests/fixtures/upm/basic_flat/`
  - [x] `tests/fixtures/upm/basic_src/`
  - [x] `tests/fixtures/upm/path_dep/`
  - [x] `tests/fixtures/upm/git_dep/`
  - [x] `tests/fixtures/upm/conflict_alias/`
- [x] 补脚本验证：
  - [x] manifest 发现
  - [x] source root 解析
  - [x] path 依赖
  - [x] git 依赖
  - [x] lockfile 重建
  - [x] CLI 帮助输出
- [x] 纯文档阶段至少运行：

```bash
git diff --check
```

- [x] 代码阶段按相关性逐步运行更大范围回归：

```bash
./bin/uya test tests/...
make tests-uya
make check
```

本轮验证记录：

- 已运行 `make upm-check`，结果全绿；过程中修复了 `cmd-upm` / `upm-check` 的 Makefile 前置依赖，避免 `make` 误走内建规则去尝试从 `bin/uya.c` 重新链接 `bin/uya`。
- 已运行 `make tests-uya` 的核心测试阶段，`./tests/run_programs_parallel.sh --uya --c99` 达到 `970/970` 全通过，原先记录的 `test_cfg_target` 与 `test_return_void_catch_elides_call` 已转绿。
- 已运行 `make check`，返回 `0`；输出显示其完成了自举、主测试、证明优化、默认顶层函数发射、UPM 套件、exec vm 专项、microapp 聚合、SIMD select C、切片形参 C99、`@syscall` C99、SIMD NEON 交叉编译与 `benchmarks/http_bench.uya` C99 编译验证。

---

## 验收标准

满足以下条件后，才算这份“包管理规范完善”真正收口：

- [x] `docs/package_management.md` 存在且能独立说明 v1 规范。
- [x] `docs/uya.md` 不再把“项目根目录”和“包根目录”写成互相冲突的定义。
- [x] 用户能明确知道：
  - [x] 什么时候需要 `uya.toml`
  - [x] 什么时候还能直接 `uya build file.uya`
  - [x] `source-dir` 如何影响模块路径
  - [x] path/git 依赖如何声明
  - [x] `uya.lock` 何时生成、何时更新
- [x] 至少有一组 path dependency 示例和一组 Git dependency fixture 跑通。
- [x] `upm --help` / `uya upm --help` 能输出稳定帮助文字。
- [x] 版本冲突、alias 冲突、缺失 manifest、缺失 lockfile 重建/错误路径等场景都有测试覆盖。
- [x] 文档中明确列出 v1 不支持项，避免用户误判功能范围。

---

## 建议首个提交切分

为了降低返工，建议按以下顺序切提交，而不是把规范、解析器、CLI 一次性混在一起：

1. 术语冻结 + `docs/package_management.md` 骨架 + `docs/uya.md` 勘误
2. 示例与 fixture 目录 + 文档测试脚本骨架
3. manifest 解析 + path 依赖 + 多根模块查找
4. lockfile + git 依赖
5. `cmd/upm` CLI + Makefile / dispatch / 安装集成

这样即使中途调整 `deps/`、`source-dir` 或 CLI 命名，也不会把后续实现一起推翻。
