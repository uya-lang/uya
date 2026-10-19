# Uya 开发指导说明

**版本**：v0.10.4（版本唯一来源 `src/version.uya`）
**更新日期**：2026-10-19

本文档定义 Uya 编译器的开发流程。自 v0.3.4 起，**C 编译器（`compiler-c/`）已退役**，仓库只维护 `src/` 里的自举编译器。

---

## 开发模式

### 自举编译架构

```
backup/uya.c（仓库跟踪的单文件 C99 种子）
    ↓ make from-c（Linux；macOS 用 make from-c-native）
bin/uya（可执行编译器；bin/ 被 .gitignore 忽略）
    ↓ 编译 src/*.uya
src/.uyacache/（split-C 多文件 C，默认）+ bin/uya.c（单文件种子）
    ↓ make b（自举验证：两次产物一致）
    ↓ make backup-seed / make backup-all（刷新仓库跟踪的种子）
提交
```

### 关键原则

1. **单一编译器源**：`src/` 是唯一的编译器源代码。
2. **仓库跟踪的种子是 `backup/uya.c`**：`bin/uya.c` 位于被忽略的 `bin/` 目录，不入库；`make backup-seed` 会同时更新 `bin/uya.c`、`backup/uya.c` 与 `backup/uya-<host_os>-<host_arch>.c`。
3. **自举验证必须通过**：改动编译器后运行 `make b`（hosted 路线 `make b-hosted`）。
4. **平台入口**：Linux 用 `make from-c` / `make uya`；macOS 冷启动用 `make from-c-native`，日常用 `make uya-hosted`。

---

## TDD 开发流程

新功能开发推荐测试驱动开发（红 → 绿 → 重构）：

```bash
# 1. 先写测试（tests/test_<feature>.uya，使用 test "名称" {} 块）
# 2. 确认当前失败（红）
./bin/uya test tests/test_new_feature.uya

# 3. 写最小实现
# 4. 确认通过（绿）
make uya && ./bin/uya test tests/test_new_feature.uya

# 5. 重构后复跑
./bin/uya test tests/test_new_feature.uya

# 6. 最终验证
make b
make check    # 提交前口径；日常可先跑相关子集
```

若改动涉及 unknown/web target、libc/syscall bridge 或 Web 运行时，再补跑 `make tests-emcc`（需本机 emcc + node）。

### 测试编写规范

```uya
// tests/test_feature.uya
use std.testing.assert_eq_i32;

test "feature_case" {
    const result: i32 = my_function(input);
    try assert_eq_i32(result, expected);
}
```

- 文件名：`test_<功能>.uya`；负例用 `error_<功能>.uya`。
- 断言宏来自 `std.testing`（`assert` / `assert_eq_i32` 等），返回 `!void`，调用处需 `try`。
- 更完整的测试约定见 `docs/testing_guide.md` 与 `docs/TESTING.md`。

### TDD 核心原则

| 原则 | 说明 |
|------|------|
| 测试先行 | 任何新功能必须有对应测试 |
| 小步迭代 | 每次只添加一个小功能点 |
| 快速反馈 | 测试应该快速执行 |
| 覆盖边界 | 测试边界条件和异常情况 |

---

## 开发前准备

- 阅读 `docs/uya_ai_prompt.md`、`docs/uya.md`、`docs/grammar_quick.md` 与相邻测试，确认当前语法与约定。
- 不要臆造语法、关键字、内置函数或标准库 API；拿不准就搜索 `src/`、`lib/`、`tests/` 的既有用法。
- `.codebuddy/skills/uya-development.md` 记录了部分开发经验，可作参考，但**以代码与测试为准**。

### 遵循 Uya 语法规则

| 规则 | 说明 |
|------|------|
| `str_equals(a, b) != 0` | 字符串相等（返回非 0 表示相等） |
| `var` / `const` | 可变 / 不可变绑定；没有 `let`、`mut` |
| `use` 顶层 | `use` 只能在文件顶层 |
| 参考现有代码 | 查看 `tests/` 与 `lib/` 学习语法 |

---

## 从零开始构建

### 首次克隆仓库

```bash
git clone https://github.com/uya-lang/uya.git
cd uya

# Linux 冷启动：从仓库跟踪的 C99 种子构建
make from-c

# macOS 冷启动：使用本机 hosted 种子
make from-c-native

# 验证
./bin/uya --version
make tests-uya
```

### 日常开发流程

```bash
# 1. 修改编译器源代码
vim src/checker/check_expr.uya

# 2. 重新构建编译器（默认 nostdlib 静态；hosted 用 make uya-hosted）
make uya

# 3. 验证自举一致性
make b

# 4. 运行测试
make tests

# 5. 提交（种子有变化时一并提交 backup/ 下的文件）
git add -A && git commit -m "fix: 描述修复内容"
```

---

## Makefile 目标

| 目标 | 说明 |
|------|------|
| `make from-c` | Linux 冷启动：从 `bin/uya.c` 或 `backup/` 种子构建；nostdlib `_start` 产物走 `crti.o` + `.o` + `crtn.o` 链接 |
| `make from-c-native` | macOS 冷启动：优先 `backup/uya-hosted-macos-<arch>.c`，其次 `backup/uya-hosted-macos.c` |
| `make uya` | 构建自举编译器（默认 `--nostdlib`，静态链接，增量指纹 + 前端并行） |
| `make uya-hosted` | 构建 hosted 路线编译器 |
| `make uya-safety` | 构建启用内存安全检查的编译器 |
| `make b` | 自举验证（nostdlib）；`make b-hosted` 为 hosted 路线 |
| `make tests` | 运行测试套件（默认 CPU 核数并行，`UYA_TEST_JOBS=N` 可改） |
| `make tests-uya` | 只跑自举编译器路线 |
| `make tests-hosted` | hosted 主测试集 |
| `make tests-emcc` | 独立 emcc/unknown target smoke（需 emcc + node，不默认进 `make check`） |
| `make check` | 自举 + 全量测试（提交前口径）；`make check-hosted` 为 hosted |
| `make microapp-check` | microapp 聚合回归 |
| `make upm-check` | UPM / 包管理专项回归 |
| `make examples-check` | examples 可执行/服务/package/microapp 验证 |
| `make backup` | 备份 split-C 目录 `src/.uyacache` → `backup/uyacache` |
| `make backup-seed` | 单文件种子：更新 `bin/uya.c`、`backup/uya.c`、`backup/uya-<host_os>-<host_arch>.c` |
| `make backup-all` | `backup` + `backup-all-seed`（提交前完整备份） |
| `make release` | 最终 release 验证：要求工作树干净 |
| `make release-dirty` | 当前工作树强行执行完整 release（本地调试用） |
| `make release-clean` | 在 Git HEAD 干净快照中执行 `make release` |
| `make restore` | 从 `backup/uya.c` 恢复 `bin/uya.c` |
| `make clean` | 清理构建产物 |

完整目标与默认值以 `make help` 为准。

---

## 代码结构

```
uya/
├── src/                 # 编译器源代码（唯一维护源）
│   ├── main.uya         # CLI 入口（build/check/run/test/fmt/upm...）
│   ├── lexer.uya        # 词法分析
│   ├── parser/          # 语法分析（main/declarations/expressions/primary/statements/types）
│   ├── checker/         # 类型检查、证明、宏展开、模块解析
│   ├── codegen/c99/     # C99 后端
│   ├── lower/           # async lowering
│   ├── exec/            # exec / bytecode 后端（部分实现）
│   ├── driver/          # 构建驱动（modules/path_list/toolchain）
│   ├── cmd/             # 外置子命令（build、upm）
│   ├── microapp/        # microapp 目标与镜像
│   ├── fmt.uya          # uya fmt
│   └── version.uya      # 版本号唯一来源
├── lib/                 # 标准库（std）、libc、kernel、tls、tflm、osal、syscall
├── tests/               # 回归测试、负例、脚本（test_*/error_*/verify_*/stress_*）
├── backup/              # 仓库跟踪的单文件 C99 种子与 split-C 备份
├── docs/                # 规范、设计、状态与发行说明
├── bin/                 # 本地构建产物（gitignore）
└── .github/workflows/   # Linux / macOS CI
```

---

## 自举验证详解

### `make b` 流程

`make b` 调用 `src/compile.sh --bootstrap-compare`：

- **多文件 / split-C 模式**：对比主编译产物与自举产物的可执行文件（先剥离调试段与 build-id 再 `cmp`）；
- **单文件模式**：`diff` 两次生成的 C 输出；
- 一致则通过。

### 验证失败处理

1. 检查是否有未提交的改动；
2. 确认修改是否影响代码生成顺序；
3. 排序相关的输出必须稳定（如 err_union 按名称排序）。

---

## 发布流程

```bash
# 1. 确保测试与自举通过
make clean && make from-c && make b && make check

# 2. 改版本号：只改 src/version.uya
#    （upm 运行时版本与 readme/CHANGELOG/发行说明由 tests/verify_version_sources.sh 校验）

# 3. 写发行说明 docs/releases/RELEASE_vX.Y.Z.md，并更新 CHANGELOG.md / readme.md

# 4. 刷新种子（会跑完整验证）
make backup-all

# 5. 提交并打标签
git add -A && git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z: 版本描述"
git push origin main --tags
```

---

## 注意事项

### 已退役组件

- **compiler-c/**：C 语言实现的旧编译器，自 v0.3.4 起不再维护，仓库已不包含。
- **`make tests-c` / `bin/uya-c`**：已移除，不再存在。

### 禁止操作

- ❌ 不要修改或重新引入 `compiler-c/` 路线
- ❌ 不要跳过自举验证（`make b` / `make b-hosted`）
- ❌ 不要在测试失败时提交代码
- ❌ 不要删除有意义的测试
- ❌ 不要瞎编乱造语法

### 种子与备份

- `backup/uya.c` 是仓库跟踪的单文件种子；`bin/uya.c` 被 `.gitignore` 忽略。
- `make backup-seed` 刷新单文件种子；`make backup-all` = `make backup` + 单文件种子刷新。
- `make restore` 从 `backup/uya.c` 恢复 `bin/uya.c`。

---

## 相关文档

- **回归测试说明**：[TESTING.md](./TESTING.md)
- **测试编写规范**：[testing_guide.md](./testing_guide.md)
- **版本历史**：[releases/](./releases/)
- **语言规范**：[uya.md](./uya.md)
- **规范变更日志**：[changelog.md](./changelog.md)
- **任务状态总表**：[todo_status_index.md](./todo_status_index.md)
