# Uya 仓库代理说明

## 适用范围

本文件适用于仓库根目录及其所有子目录。若更深层目录出现新的 `AGENTS.md`，以更深层文件的说明为准。

## 项目概览

Uya 是一个自举系统编程语言和编译器项目，目标是零 GC、编译期安全证明和 C99 后端自举。

主要目录：

- `src/`：Uya 自举编译器源码，是编译器实现的主要维护源。
- `lib/`：标准库、libc 绑定、kernel/microapp/TLS/TFLM 等库代码。
- `tests/`：回归测试、错误测试、多文件测试和测试脚本。
- `docs/`：语言规范、设计文档、实现计划、发布说明和测试/开发说明。
- `examples/`：Uya 示例程序和 microapp 示例。
- `backup/`：自举种子与平台相关 C99 备份；提交前备份流程可能更新这里。
- `benchmarks/`：HTTP、UyaGin、Go、Rust 等基准测试代码。
- `bin/`、`build/`、`tests/build/`、`src/build/`、`.uyacache/`：本地构建产物，通常不要手动提交。

## 开发准则

- 修改语言或编译器行为前，先阅读 `docs/uya_ai_prompt.md`、相关规范文档和相邻测试，确认当前语法和约定。
- 不要臆造 Uya 语法、关键字、内置函数或标准库 API；拿不准时优先搜索 `src/`、`lib/`、`tests/` 中的既有用法。
- `src/` 是编译器实现的主要维护源；不要重新引入或修改退役的 `compiler-c/` 路线。
- 新功能按 TDD 推进：先补测试，确认失败，再做最小实现，最后重构。
- 修 bug 或重构时，先运行相关快速基线测试，了解当前行为再修改。
- 不要删除有意义的测试；如果必须调整测试语义，应在变更说明中解释原因。

## Uya 代码风格

- 遵循相邻 `.uya` 文件的命名、缩进、控制流和错误处理风格。
- 公共 `export fn`、`export struct` 方法等对外可见函数前必须写 `///` 注释。
- 公共注释至少包含功能说明、参数说明和返回值说明；无参数或无返回值时也明确写出。
- 函数保持短小、单一职责、低嵌套；优先使用提前返回、提取辅助函数和清晰的分发函数。
- 避免超过 50 行的函数、超过 3 层的嵌套、超过 5 个参数的函数；超过时优先拆分或封装结构体。
- `str_equals(a, b) != 0` 表示字符串相等，`== 0` 表示不相等。
- `use` 语句只能放在文件顶层；不要写通配导入或不存在的模块值。
- 可变绑定使用 `var x: T`，常量使用 `const x: T`；不要写 `let`、`mut`、`i++` 或三元 `?:`。

## 测试与验证

常用命令：

- 快速相关测试：`./bin/uya test tests/test_xxx.uya`
- 单个程序回归：`./tests/run_programs_parallel.sh test_xxx.uya`
- 自举编译器测试：`make tests-uya`
- 全量验证：`make check`
- hosted 路线验证：`make check-hosted`
- microapp 聚合回归：`make microapp-check`

开发阶段优先运行本次改动相关的快速测试；阶段收口或准备提交前运行 `make check`。

提交前验证规则：

- 编译加速相关开关见 `docs/build_speed.md`：`--jobs/-j`（前端并行，默认 CPU 核数）、
  `UYA_GCC_JOBS`（C 阶段 `make -j` 并行度）、`UYA_FORCE_BUILD=1`（跳过增量指纹短路，强制重建）、
  `UYA_SPLIT_C_CLEAN=1`（强制清空 split-C 缓存）。无改动时 `make uya` 会命中增量指纹并直接返回，
  想看完整重建请显式加 `UYA_FORCE_BUILD=1`。
- 准备提交时按顺序运行 `make clean`，然后运行 `make backup-all`。
- `make backup-all` 会执行完整验证并更新多文件/单文件种子备份；失败时不要提交。
- 如果 `make backup-seed` 更新了自举种子，同一提交中应包含仓库跟踪的 `backup/uya.c` 及必要备份文件。
- `bin/uya.c` 位于忽略的 `bin/` 目录，不要手动加入提交。

## 构建注意

- macOS 冷启动使用 `make from-c-native`；`make from-c` 在 macOS 主线会拒绝旧 seed 回退。
- Linux 冷启动可使用 `make from-c`。
- 构建自举编译器使用 `make uya`；hosted 路线使用 `make uya-hosted`。
- 自举验证使用 `make b`；hosted 自举验证使用 `make b-hosted`。
- 交叉目标用环境变量 `TARGET_OS`（linux / macos / windows）与 `TARGET_ARCH`（x86_64 / arm64 / riscv64）；microapp 目标 profile 见 `--microapp-profile` 与 `src/microapp/main.uya`。
- CLI 选项以 `./bin/uya --help` 为准；构建/测试目标以 `make help` 为准，不要在文档里手写猜测的 flag。
- 如果编译器因栈空间不足崩溃，可临时增大栈限制；相关脚本通常已经内置栈设置。
- `make release` 要求干净工作树；仅在发布任务中使用。日常本地调试可参考 `make release-dirty`，但它不能替代最终验证结论。

## 文档同步

- 修改语言语法、语义、BNF 或内建函数时，必须同步检查并更新相关规范文档。
- 重点同步文件包括 `docs/uya.md`、`docs/grammar_formal.md`、`docs/grammar_quick.md` 和 `docs/builtin_functions.md`。
- 需要升级规范版本时，同步更新文档头部版本、最后更新日期、版本同步说明和文中引用，避免新旧版本混用。
- 仅修正错字、排版或不改变规范含义时，可以不升级版本；无法判断时按需要升级处理。

## 变更安全

- 不要覆盖用户或其他代理未提交的改动；改动前查看相关文件和 `git status --short`。
- 不要使用 `git reset --hard`、`git checkout --` 等破坏性命令，除非用户明确要求。
- 不要手动清理构建产物以外的未知文件；若发现与当前任务冲突的意外改动，先暂停并确认。
- 文档初始化或纯文档变更不需要运行 `make check`，但应至少运行 `git diff --check`。


<claude-mem-context>
# Memory Context

# [uya] recent context, 2026-04-29 12:37am GMT+8

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (19,582t read) | 2,110,417t work | 99% savings

### Apr 25, 2026
237 1:47p ⚖️ UYA Compiler Output Files Marked as Read-Only
239 " 🔵 UYA Repository: bin/ Directory Ignored by Git
240 1:48p 🔴 UYA Runtime Restored from Backup: Compilation Successful
241 1:49p 🔵 UYA Compiler Segfault: Exit Code 139 on src/main.uya Build
242 " 🔄 UYA Runtime: Refactored Temp Path Generation to Eliminate snprintf Dependency
243 " 🔵 UYA Runtime Error Persists: Refactored Code Not Yet Compiled
244 1:58p ✅ Code Review Requested: 评审修改
245 " 🔄 UYA Compiler: Temp Path Generation Refactored to Eliminate snprintf Dependency
246 " 🔵 UYA Compiler: host_fill_temp_c_import_object_path Still Uses snprintf
247 2:00p 🔵 UYA Runtime: getenv and snprintf Are Custom UYA Implementations, Not System libc
248 2:01p 🔵 UYA: host_fill_temp_c_import_object_path Only Triggered for @c_import Projects
249 2:07p ⚖️ UYA Compiler Code Review: snprintf Elimination Refactor Approved
250 2:08p 🔵 host_fill_temp_c_import_object_path: Full snprintf Usage Confirmed Before Patch
251 2:09p 🔵 UYA src/fmt.uya: write_byte/write_str Pattern Uses &usize Position Pointer
252 " 🔄 UYA Temp Path Generation: Full snprintf Elimination via Three New Helper Primitives
253 2:10p 🔵 test_c_import_file.uya Crashes Old bin/uya with SIGSEGV (exit 139)
254 2:14p 🔵 macOS Sandbox Blocks `ps` Command in UYA Session Environment
256 2:15p 🔵 UYA Hosted Build Session 42136 Alive But Producing No Output — src/build Empty After 30s
257 2:16p 🔵 UYA src/compile.sh Structure: Build Paths, Bootstrap, and Backup Fallback Logic
258 " 🔵 UYA `*pos` Pointer Dereference Only Exists in Newly Added Helpers — Potentially Unsupported Syntax
259 2:17p 🔵 snprintf Used Extensively Beyond Temp Path Subsystem — Lexer, Fmt, and C99 Codegen All Affected
260 2:18p 🔵 UYA `*pos` Pointer Dereference Syntax Crashes Compiler — Smoke Test Exits Code -1 With No Output
261 2:19p 🔵 git diff Confirms Full Extent of src/main.uya Patch — 5 Call Sites for host_fill_temp_c_import_object_path
262 2:25p 🔄 UYA Compiler: snprintf Elimination Refactor Committed to src/main.uya
263 2:26p 🔵 UYA Compiler Bootstrap Build: No Output File Produced — Build Confirmed Stalled
264 2:27p ✅ UYA Compiler: Changes Committed to Version Control
265 2:29p 🔵 UYA Compiler: Pre-Commit State — src/main.uya Modified, AGENTS.md Untracked
266 2:31p ✅ UYA Compiler: Pending Changes Committed to Version Control
267 2:32p ✅ UYA Compiler: Code Changes Committed
268 " 🔵 UYA Compiler: Local Branch Ahead of Origin with Untracked AGENTS.md
269 2:33p 🔵 UYA Compiler: Pending Commit is snprintf Refactor in src/main.uya
270 " 🔴 UYA Compiler: git push Failed — HTTPS Credentials Not Configured
271 2:34p ✅ UYA Compiler: snprintf Refactor Pushed to GitHub via SSH
273 2:35p 🔵 UYA Compiler: SSH Push to GitHub Succeeded Despite Later Connection Drop
274 " ✅ UYA Compiler: AGENTS.md Committed to Repository
275 " 🔵 UYA Compiler: GitHub CLI Token Invalid — HTTPS Push Blocked
### Apr 28, 2026
417 8:34p 🔵 Project at /Users/dexplemr./uya — Tech Stack and Structure Identified
418 " 🔵 "uya" is a Compiler/Language Project with Empty AGENTS.md
419 8:35p 🔵 Uya Compiler Bootstrap Flow and Test Pipeline Fully Mapped
420 " 🔵 CI Pipeline Details and Developer Tooling Inventory
421 " 🔵 TDD Workflow and AI IDE Integration Configuration Discovered
422 8:36p 🔵 Comprehensive Documentation and Language Specification Inventory
423 " 🔵 Development Workflow, Testing Infrastructure, and Compiler Status Documented
424 8:37p 🔵 Compiler Performance Benchmarking Script Identified
425 " 🔵 Makefile Help Output Shows Complete Build Target Reference
426 " 🔵 Standard Library, Examples, Benchmarks, and Compiler Binary Inventory
427 8:38p 🔵 Git Repository Status and AGENTS.md File State Confirmed
428 " ⚖️ User Selected "生成 AGENTS（推荐）" for Initialization Command
429 8:40p 🟣 AGENTS.md File Generated with Comprehensive Project Guidelines
430 8:41p 🟣 AGENTS.md Successfully Written and Validated

Access 2110k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>