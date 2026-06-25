# Uya Package Management v1 Draft

**状态**: design draft, MVP/M4 implemented + Phase 5 local backend prototype in current branch
**更新日期**: 2026-06-18
**适用范围**: `uya.toml`、`uya.lock`、`uya upm`、带依赖的 `uya build/check/run/test`
**相关文档**:

- [UPM 演进设计文档](./upm_evolution_design.md)
- [Uya 总文档中的包管理章节](./uya.md#291-包管理v1-draft--mvp-in-progress)

---

## 1. 背景与当前实现

本仓库当前稳定的模块系统仍以“模块根目录 + `UYA_ROOT`”为核心：

- 无 manifest 时，编译器把输入文件所在目录，或输入目录本身，当作模块查找根。
- 依赖查找的现状是先查本地模块根，再查 `UYA_ROOT` 指向的标准库目录。
- 当前已发布/已文档化的工作流仍然支持：
  - `uya build file.uya`
  - `uya build dir/`
  - `uya run/test/check ...`
- 中央 registry 服务、版本求解、多版本并存和 publish 流程都还不是 v1 目标；当前分支仅提供本地 proxy/registry/workspace backend 原型。

历史文档与当前源码之间还有几处需要明确拆开的漂移：

- `docs/uya.md` 旧版本把“项目根目录”直接等同于“包含 `main` 的目录”，不足以覆盖 package root / source root。
- 旧设计/待办文本曾把 `--project-root` 当作现成能力引用，但当前源码主线在包管理 MVP 落地前仍主要依赖自动推导的 module root。
- 旧草案默认 `uya.toml + src/ + deps/`，但没有先定义 package root 与 source root 的关系。

本草案的目标不是推翻现有模块系统，而是在它之上补一层与现状兼容的包管理模型。

---

## 2. 术语

### 2.1 package root

包含 `uya.toml` 的目录。一个 Uya 包的元数据、lockfile 和内部依赖目录都相对于这个目录定义。

### 2.2 source root

`[package].source-dir` 指向的源码根目录，默认值为 `"."`。它相对于 package root 解析，且必须落在 package root 内部。

### 2.3 module root

编译器真正用于 `use ...;` 模块查找的根目录。

- package mode 下：`module root = package root + source-dir`
- legacy mode 下：`module root` 继续等于当前编译器自动推导出的“项目根目录”
- 对当前实现层：若出现 `--project-root` 或旧变量名 `project_root`，默认都应理解为 `module root`

### 2.4 legacy mode

找不到 `uya.toml` 时的兼容模式。legacy mode 下：

- 不要求存在 package root。
- 继续允许直接 `uya build file.uya`。
- 模块路径继续相对于自动推导出的本地模块根解析。

### 2.5 dependency root

依赖被解析并准备给编译器使用后的源码根。v1 对用户暴露 alias 和 import 规则，不要求用户直接引用内部 vendor 路径。

### 2.6 install directory / cache directory

包管理器为当前 package root 写入依赖内容的本地目录，以及跨项目复用的全局缓存目录。当前实现采用：

- `.uya/deps/`：已安装依赖
- `~/.uya/pkg/vcs/`：全局 Git clone/cache
- `~/.uya/pkg/mod/`：全局模块内容层目录，path/git 依赖带有 `package.module + package.version` 时会写入，纯 `module + version` 依赖可从这里复用
- `UYA_UPM_WORKSPACE_ROOTS`：本地 workspace package root 列表，使用 `:` 分隔
- `UYA_UPM_PROXY_DIR`：本地 proxy backend 根目录
- `UYA_UPM_REGISTRY_DIR`：本地 registry backend 根目录

### 2.7 lockfile

`uya.lock`。用于记录一次依赖解析后得到的精确结果，保证后续 `install/build` 的可重现性。

---

## 3. 目标与非目标

### 3.1 v1 目标

- 定义 `uya.toml`
- 定义 `uya.lock`
- 支持 `path` 依赖
- 支持 `git` 依赖
- 定义带依赖时的模块查找与冲突规则
- 提供 `uya upm` / `cmd/upm` 最小命令集

### 3.2 明确非目标

v1 不承诺以下能力：

- 中央 registry
- publish
- semver range / SAT solver / 版本回溯
- workspaces / monorepo 统一锁定
- 同一 import alias 的多版本并存
- signature / registry mirror
- 二进制包和预编译缓存

---

## 4. 目录布局与根语义

### 4.1 package root 与 source root

`uya.toml` 必须位于 package root。源码根由 `source-dir` 指定：

- 默认 `source-dir = "."`
- 允许显式 `source-dir = "src"`
- `source-dir` 必须是 package root 内部路径
- v1 明确禁止 `source-dir = "../src"` 这类越出 package root 的配置

### 4.2 布局示例

#### flat layout

```text
hello/
  uya.toml
  main.uya
  util/
    fmt.uya
```

- package root: `hello/`
- source root: `hello/`
- module root: `hello/`

#### src layout

```text
hello/
  uya.toml
  src/
    main.uya
    util/
      fmt.uya
```

- package root: `hello/`
- source root: `hello/src/`
- module root: `hello/src/`

#### library package

```text
http/
  uya.toml
  src/
    client.uya
    server.uya
```

- 可以没有 `main`
- 仍然必须有 `uya.toml`
- 其它包通过 alias 方式导入，例如 `use http.client;`

### 4.3 manifest 发现

v1 的 manifest 发现顺序：

1. 若显式传入 `--manifest-path <path>`，直接使用它。
2. 否则，从当前 Uya 源文件所在目录开始向上查找；若输入本身是目录，则从该目录开始向上查找 `uya.toml`。
3. 若找到 manifest，则进入 package mode。
4. 若找不到 manifest，则回退 legacy mode。

换句话说，`project root` 的包管理语义应当是：

- 从“当前被编译的 Uya 源文件目录”向上
- 取第一个包含 `uya.toml` 的目录
- 该目录就是 package root

但在兼容 CLI 语义里：

- `--project-root` 覆盖的是 `module root`
- 它不是 `package root` 的别名
- `package root` 仍然由 manifest 发现规则决定

### 4.4 与现有 `project_root` 概念的关系

- 对用户文档：优先讲 `package root` / `source root` / `module root`
- 对实现层：
  - 当前主线已经优先统一为 `module_root`
  - `--project-root` 仍保留为兼容 CLI 名称
- 对语义解释：
  - 讨论 manifest 发现时，使用 `package root`
  - 讨论 `use` 解析与编译器查找顺序时，使用 `module root`
  - 不要再把 `project root` 同时指向这两个概念
- 语义上，旧实现里的 `project_root` 应理解为“当前一次编译实际使用的 module root”

---

## 5. `uya.toml` 规范

### 5.1 顶层约束

- 文件名固定为 `uya.toml`
- v1 只要求一个 TOML 子集，不要求仓库先提供完整 TOML 标准库
- 未识别字段应报出明确错误或被文档明确标成“保留字段”

### 5.2 `[package]`

v1 最小字段集合：

```toml
[package]
name = "hello"
module = "uya.local/hello"
version = "0.1.0"
source-dir = "."
description = "optional"
license = "optional"
repository = "optional"
```

字段规则：

- `name`：必填；包名
- `module`：可选；稳定模块身份，用于后续跨项目/生态级解析
- `version`：必填；版本字符串
- `source-dir`：可选；默认 `"."`
- `description` / `license` / `repository`：可选元数据
- `uya_min_version`：可选；要求运行当前包所需的最小 Uya 版本

### 5.2.1 `[layout]` 兼容段

当前实现额外兼容旧风格的 `[layout]`：

```toml
[layout]
source_dir = "src"
test_dir = "tests"
bench_dir = "benchmarks"
example_dir = "examples"
```

规则：

- `layout.source_dir` 作为 `package.source-dir` 的兼容别名解析
- 若同时声明 `package.source-dir` 与 `layout.source_dir`，且值不同，则直接报错
- `test_dir` / `bench_dir` / `example_dir` 当前仅做解析与路径校验，不参与 `upm build/test` 语义
- 未知表（例如 `[tool.make]`）不会再被误当成上一段继续解析

### 5.3 名称规则

- package 名和 dependency alias 都使用 ASCII 小写字母、数字、`-`、`_`
- import alias 额外要求能稳定映射为模块首段，推荐只使用小写字母、数字、`_`
- v1 大小写敏感，但规范推荐清一色小写，避免跨平台路径歧义

### 5.4 依赖表

v1 支持：

- `[dependencies]`
- `[dev-dependencies]`

语义：

- `[dependencies]`：普通构建依赖，参与 `build/check/run/test/install/update`
- `[dev-dependencies]`：只在开发工作流使用；v1 文档定义其语义，但 MVP 可以先不让普通 `build` 自动拉入它们

### 5.5 依赖声明格式

依赖表的 key 就是 import alias。v1 仅支持显式 inline table：

```toml
[dependencies]
http = { path = "../http" }
json = { git = "https://example.com/json.git", tag = "v1.2.3" }
util = { git = "ssh://git@example.com/util.git", commit = "abc123" }
foo = { path = "../foo", module = "uya.local/foo", version = "1.2.3" }
```

规则：

- 一个依赖必须二选一：`path` 或 `git`
- Git 依赖的 `tag` / `branch` / `commit` 三选一
- 依赖可选携带 `module` 与 `version`，用于校验目标包的 `package.module` 与 exact `package.version`
- 纯 `foo = { module = "...", version = "..." }` 当前按 workspace -> proxy -> registry -> `~/.uya/pkg/mod/<module>/<version>` 顺序解析真实包
- 不支持字符串 shorthand，如 `http = "../http"`
- `path` 相对当前 manifest 所在目录解析
- path 依赖与 git 依赖都要求目标包自身包含 `uya.toml`
- `package.version` 仍为必填字段；当前实现还支持可选的 `package.uya_min_version = "x.y.z"`，用于要求运行当前包所需的最小 Uya 版本；若当前 `uya` 版本低于该值，则 `upm install/update/build` 与 package mode 构建会直接报错

### 5.6 保留字段

`authors`、`build` 等字段不是 v1 必需字段。若保留：

- 必须在文档中标记为 reserved / future
- MVP 不要求解析和执行这些字段
- `package.uya_min_version` 不属于 reserved 字段；当前实现已支持它作为可选 package 字段，且不替代必填的 `package.version`

### 5.7 本地 backend 配置（Phase 5 原型）

当前 Phase 5 原型仅定义本地 backend，不定义远程网络协议。

- `UYA_UPM_WORKSPACE_ROOTS` 是 `:` 分隔的 package root 列表；每个 root 必须包含 `uya.toml`，并通过 `package.module` 与 `package.version` exact match 命中依赖。
- `UYA_UPM_PROXY_DIR` 使用 `<root>/<module>/<version>/uya.toml` 布局；proxy 命中后直接把该目录作为依赖 package root。
- `UYA_UPM_REGISTRY_DIR` 使用同样的 `<root>/<module>/<version>/uya.toml` 本地布局；registry 当前提供 module -> source metadata 查询和版本列表查询。
- 纯 `module + version` 依赖解析顺序为 workspace、proxy、registry、全局 module cache。workspace 用于本地联调，proxy 优先于 registry，cache 作为最后回退。
- path/git 依赖仍按显式来源解析，不受上述 backend 优先级影响。
- 当前 workspace 原型不做统一 lockfile、跨包批量 test、版本范围求解或多版本并存；这些能力仍属于后续设计。

### 5.8 Publish 最小协议（Phase 5 原型）

当前 publish 原型只定义本地可验证的发布元数据，不上传源码，也不定义远程认证、签名或 registry 服务协议。

最小发布计划包含：

- `package.name`
- `package.module`
- `package.version`
- `manifest_path`
- `package_root`
- `source_root`
- `content_hash`

发布前必须满足：

- manifest 可解析，且 `package.name`、`package.module`、`package.version` 均存在。
- `source-dir` 已解析为有效 `source_root`。
- 若配置了 `UYA_UPM_REGISTRY_DIR`，目标 `module + version` 不能已存在。
- `content_hash` 由源码树 checksum 生成，并写入发布 metadata receipt，作为后续 registry/proxy 校验输入。

当前不承诺：

- 上传、认证、签名和撤回流程。
- semver range、版本回溯或多版本求解。
- 远程 registry 的网络 API。

---

## 6. `uya.lock` 规范

### 6.1 文件格式

`uya.lock` 采用 TOML，与 manifest 同风格。当前实现写出顶层 `version = 2`，并兼容读取无显式版本头的旧 lockfile：

```toml
version = 2

[[package]]
alias = "http"
name = "http"
module = "uya.local/http"
source_kind = "git"
git = "https://example.com/http.git"
commit = "0123456789abcdef"
package_root = "/abs/cache/http/"
source_root = "/abs/cache/http/src/"
resolved_version = "1.2.3"
resolved_commit = "0123456789abcdef"
content_hash = "0123456789abcdef"
```

### 6.2 锁定内容

每个锁定条目至少记录：

- `alias`
- `name`
- `module`（若依赖声明或目标包提供）
- `source_kind`
- 对 path：
  - 原始 manifest 相对路径
  - 规范化后的绝对 package root
  - source root
  - content hash
- 对 git：
  - `git` URL
  - 精确 `commit`
- `package_root`
- `source_root`
- `resolved_version`
- `resolved_commit`
- `content_hash`

### 6.3 分支和标签

manifest 中允许写：

- `tag`
- `branch`
- `commit`

但写入 lockfile 时必须全部落成精确 `commit`。

### 6.4 更新时机

v1 约定：

- `upm install`：若 lockfile 缺失，则解析并生成
- `upm update`：重新解析并刷新 lockfile
- `upm add/remove`：当前已进入 MVP；命令会改写 manifest，并通过一次依赖同步重写 lockfile
- `uya build/check/run/test`：
  - 优先读取 lockfile
  - lockfile 缺失时允许按 manifest 解析，并生成 lockfile

### 6.5 过期与手改

- lockfile 缺失、无法匹配当前依赖或无法读取时，当前 MVP 按“需要重新解析”处理，而不是直接报错
- `uya.lock` 不应手动编辑
- lockfile 保障的是“同一份解析结果可重现”
- lockfile 不保证下载源永久可用
- 当前实现会写入源码树 `content_hash`
- git 依赖在已有 lockfile checksum 时会校验，校验失败会阻止构建
- path 依赖当前会生成并写入 checksum，但尚未按旧 lockfile checksum 做强校验
- v1 不做 signature / registry mirror

---

## 7. 依赖解析与模块查找

### 7.1 查找顺序

package mode 下推荐顺序：

1. root package 的 source root
2. 已解析依赖的 alias 根
3. `UYA_ROOT`
4. 编译器保留内置目录（若未来保留）

### 7.2 alias 到模块路径的映射

若 manifest 中写：

```toml
[dependencies]
http = { path = "../http" }
```

且依赖包的 `source-dir = "src"`，那么：

- `use http.client;`
- 逻辑上表示导入 alias `http`
- 它映射到依赖包的 source root，再在其中查找 `client.uya` 或 `client/`

换言之，用户看到的是 `http.client`，而不是 `.uya/deps/http/src/client`。

### 7.3 目录模块与文件模块

依赖包内的模块规则与 root package 保持一致：

- 目录模块仍然成立
- 单文件模块别名仍然成立
- `source-dir` 只改变模块根，不改变目录/文件模块本身的规则

### 7.4 冲突策略

v1 明确采用“及早报错”：

- root source root 下若已存在顶层模块 `http`，再声明 alias `http`，报冲突
- 两个依赖都声明 alias `http`，但解析到不同来源/不同 commit，报冲突
- 同一 alias 在不同位置要求不同版本，报冲突
- 同一 package 名若被解析到不同 path 来源或不同 git commit，即使 alias 不同，也直接报错
- v1 不支持同一 alias 多版本 side-by-side

### 7.5 循环依赖

- 模块内循环依赖：沿用当前编译器规则
- 包级依赖循环：v1 直接拒绝

---

## 8. 安装目录与安全边界

### 8.1 本地目录

v1 采用隐藏目录：

```text
.uya/
  deps/
```

- `.uya/deps/`：安装好的依赖内容
- `~/.uya/pkg/vcs/`：跨项目复用的 Git 下载缓存
- `~/.uya/pkg/mod/`：模块内容层缓存目录；当前已可写入并复用
- 原生 `uya build/check/run/test` package mode 当前使用 graph-only resolve 与 dependency alias -> source root 映射，不再依赖临时 staging root 进行模块查找
- `upm build` / `upm vendor` 的过渡物化层仍可使用 `TMPDIR` 或 `/tmp` 下的临时 build root，例如 `/tmp/uya-upm-build-<pid>/root/`

### 8.2 path 依赖安全规则

- manifest 中的 `path` 先相对 manifest 目录解析，再做规范化
- 目标必须是存在的目录，且目录内必须有 `uya.toml`
- `source-dir` 必须位于该依赖的 package root 内部
- 检测到 path 循环引用时直接报错

---

## 9. CLI 工作流

### 9.1 public naming

v1 的 canonical public UX 是：

- `uya upm <subcommand>`

仓库内的真实入口是：

- `cmd/upm`
- `bin/cmd/upm`

`uyapm` 作为独立别名不是 v1 必需项；若将来提供，必须明确说明它只是 `uya upm` 的别名。

### 9.2 MVP 子命令

当前实现已支持：

- `upm init`
- `upm install`
- `upm update`
- `upm build`
- `upm add`
- `upm remove`
- `upm graph`
- `upm why`
- `upm doctor`
- `upm cache dir`
- `upm vendor`
- `upm publish`

其中 `add/remove` 当前提供的最小 UX 为：

- `upm add <alias> --path <dir>`
- `upm add <alias> --git <url> --branch <name>`
- `upm add <alias> --git <url> --tag <name>`
- `upm add <alias> --git <url> --commit <sha>`
- `upm add <alias> --dev ...`（写入 `[dev-dependencies]`）
- `upm remove <alias>`
- `upm remove <alias> --dep`
- `upm remove <alias> --dev`
- `upm graph [--manifest-path <path>] [<dir>]`
- `upm why <alias> [--manifest-path <path>] [<dir>]`
- `upm doctor [--manifest-path <path>] [<dir>]`
- `upm cache dir`
- `upm vendor [--manifest-path <path>] [<dir>]`
- `upm publish [--manifest-path <path>] [<dir>]`

### 9.3 语义

- `upm init`：生成最小 `uya.toml`；默认生成 flat layout，可选生成 `src/` layout
- `upm install`：解析 manifest / lockfile，安装依赖并写回 lockfile
- `upm update`：刷新可变 ref（如 branch/tag）并重写 lockfile
- `upm build`：wrapper，按 package mode 准备依赖后调用现有构建流程；原生 `uya build/check/run/test` 已可直接使用 graph-only package plan
- `upm add`：直接改写 `uya.toml` 后自动执行一次 `install`，并同步刷新 `uya.lock`
- `upm add --dev`：把依赖写入 `[dev-dependencies]`
- `upm remove`：从 manifest 删除指定 alias 后自动执行一次 `install`
- `upm remove --dep`：只从 `[dependencies]` 删除
- `upm remove --dev`：只从 `[dev-dependencies]` 删除
- `upm graph`：打印当前 manifest 的 resolved graph
- `upm why <alias>`：解释指定依赖 alias 的 resolved graph 条目
- `upm doctor`：执行 manifest parse 与 graph resolve 诊断
- `upm cache dir`：打印 `pkg` / `vcs` / `mod` cache 目录
- `upm vendor`：只物化依赖到 `.uya/deps/` 并写回 lockfile，不调用编译器
- `upm publish`：生成本地 `.uya/publish.receipt`，包含 module、version 和 content_hash

### 9.4 示例

```bash
uya upm add gui_uya --git https://github.com/uya-lang/gui-uya.git --branch main
uya upm add gui_uya --dev --path ../gui_uya
uya upm remove gui_uya --dep
uya upm remove gui_uya --dev
```

### 9.5 remove 的分区语义

- `upm remove <alias>`：在 `[dependencies]` 与 `[dev-dependencies]` 中都允许匹配；命中即删除
- `upm remove <alias> --dep`：只检查并删除 `[dependencies]`
- `upm remove <alias> --dev`：只检查并删除 `[dev-dependencies]`
- 若目标分区中没有该 alias，应报错，而不是静默成功
- 当前实现按 alias 对应的整行声明做最小文本删除，不做完整 TOML 重排

### 9.6 manifest 发现

`upm install/update/build` 默认在当前目录向上查找 manifest，并支持显式：

```text
--manifest-path <path>
```

---

## 10. 错误与诊断

v1 至少要能稳定报出以下错误：

- manifest 不存在
- `source-dir` 非法或越界
- path 依赖路径不存在
- 依赖包缺少 `uya.toml`
- alias 冲突
- lockfile 写入失败
- Git ref 无法解析
- 包级循环依赖

诊断中应尽量包含：

- 当前 manifest 路径
- 发生冲突的 alias
- 冲突双方的源信息

---

## 11. 与 legacy mode 的兼容

以下工作流必须继续可用：

- `uya build file.uya`
- `uya build dir/`
- `uya run/test/check ...`

也就是说：

- `uya.toml` 不是进入编译器的必需前提
- 只有当 manifest 被发现时，才切换到 package mode
- 没有 manifest 的仓库和示例，不能因为包管理引入而回归

---

## 12. 当前实现状态

本节用于防止规范写成“已经全部存在”的口吻。

### 12.1 已存在的基础

- legacy mode 模块系统
- `UYA_ROOT` 标准库查找
- `uya build/check/run/test`

### 12.2 本草案要求的 MVP

- 已实现：
  - manifest 发现
  - manifest/lock 子集解析
  - path 依赖安装与构建接入
  - git 依赖安装、lockfile 落地与 branch/update 行为
  - `package.module` 解析
  - path/git 依赖携带 `module + version` 时的 identity 与 exact version 校验
  - 纯 `module + version` 依赖从 `~/.uya/pkg/mod/<module>/<version>` 解析
  - 纯 `module + version` 依赖通过本地 workspace/proxy/registry backend 解析
  - 本地 registry 版本列表查询
  - `upm publish` 及 publish 最小 metadata 校验、版本唯一性检查与 checksum receipt 写出
  - `upm graph` / `upm why` / `upm doctor` / `upm cache dir` / `upm vendor`
  - 全局 git cache：`~/.uya/pkg/vcs/`
  - 模块内容缓存：`~/.uya/pkg/mod/`
  - lockfile v2 头部与完整 lock item 读取入口
  - 源码树 `content_hash` 写入 lockfile
  - git 依赖 lockfile checksum 校验
  - path 依赖按旧 lockfile checksum 做强校验
  - `content_hash` 写入 resolved graph 条目
  - graph-only resolve 不再落盘 `.uya/deps` / staging root
  - 原生 `uya build/check/run/test` package mode 使用 source root 与 dependency alias source-root 映射，不再完全依赖 staging 目录结构
  - `cmd/upm`
  - repo-local `bin/cmd/upm` package build 验证入口
  - `upm add`
  - `upm remove`
- 尚未实现：
  - 远程 registry/proxy 网络协议
  - 远程 publish 服务与更完整 diagnostics 生态
  - workspace 统一 lockfile、批量 test 与 monorepo 视图

### 12.3 后续演进与正式设计文档

本文件聚焦于 **v1 draft / MVP 语义与当前实现边界**。对于后续更长期的架构拆分与演进规划，统一参考：

- [UPM 演进设计文档](./upm_evolution_design.md)

该文档覆盖：

- `src/cmd/upm/upm_lib/main.uya` 的分层拆分方向
- `resolver` / `build_plan` / `lockfile` / `git_fetch` 的目标边界
- package mode 下沉到编译器主流程的路径
- `module identity`、global cache、checksum 与版本模型的当前实现边界和后续设计
- proxy / registry / workspace / publish 的长期扩展路线

### 12.4 明确尚未承诺

- 远程 registry 服务
- publish
- semver range
- multi-version
- workspace 统一锁定与 monorepo 级命令
