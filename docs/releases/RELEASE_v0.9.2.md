# Uya v0.9.2 发布说明

> **类型**：**v0.9.x 发行线上的补丁版本**（patch）  
> **发布日期**：2026-04-12

在 **v0.9.1** 基础上改进测试基础设施：并行测试脚本支持独立输出目录、实时结果输出，并修复 `make tests` 下的缓冲与参数问题。`make check` 下 **779** 项测试通过（2026-04-12）。

---

## 核心变更

### 测试基础设施：并行测试脚本重构

#### 1. 独立输出目录（避免同名测试冲突）

- `tests/run_programs_parallel.sh`：
  - 新增 `generate_test_id()`，基于 `.uya` 文件的相对路径生成唯一 ID，将路径分隔符替换为下划线。
  - 单文件测试的编译产物（`.c`、`.bin`、`_bridge.c`、`.compiler_output.log`、`.result`）从统一的 `$BUILD_DIR` 迁移到 `$BUILD_DIR/tests/${test_id}/`。
  - 多文件测试的编译产物迁移到 `$BUILD_DIR/multifile_tests/${test_name}/${case_name}/`。
  - `run_multifile_test` 的 `case_file` 与 `result_file` 也同步迁入独立目录，消除并行执行时的写覆盖风险。

#### 2. 实时输出改进

- `tests/run_programs_parallel.sh`：
  - 新增 `process_ready_single_results()`，在 `wait -n` 每次返回后立即检测并输出已完成的后台测试结果，实现**完成一个、输出一个**的流水线式反馈。
  - 脚本顶部增加 `stdbuf -oL` 自动重载逻辑：当 stdout 不是 TTY 时（如通过 `make`/`pipe`/`CI` 运行），强制行缓冲，避免输出被块缓冲延迟。
  - 旧 Bash（不支持 `wait -n`）回退到批量模式，每批 `wait` 结束后立即输出该批结果，优于原先的全局汇总输出。

#### 3. `make tests` 参数修复

- `Makefile`：
  - 移除 `tests:`、`tests-hosted:`、`tests-uya:` 目标中硬编码的 `--hide-pass` 参数。
  - 现在 `make tests` 与直接运行 `./tests/run_programs_parallel.sh` 行为一致，通过的测试会实时显示 `✓`，不再静默等待全部结束后才打印汇总。

---

## 前序版本：v0.9.1 核心变更摘要

### 编译器：async 状态机 lowering

#### 1. 变量提升容量不足（16 → 32）

- `src/codegen/c99/internal.uya`：将 `async_local_names` / `async_local_types` / `async_local_inits` / `async_local_root_stmt` / `async_param_names` 容量从 **16** 扩至 **32**。
- `src/codegen/c99/function.uya`、`global.uya`、`types.uya`、`utils.uya`：将所有硬编码 `16` 改为 `@len(...)` 动态上限检查，防止大函数 lowering 时局部变量被静默丢弃。

#### 2. 嵌套块内 hoisted 变量未初始化（SIGSEGV 根因）

- `src/codegen/c99/stmt.uya`：`gen_var_decl_stmt` 在生成 async poll 函数时，若变量已被 hoist 到 `async_local_names`，不再生成普通局部变量声明，而是直接生成状态机字段初始化：
  - 普通类型：`s->_uya_loc_xxx = init_expr;`
  - 数组字面量：`__builtin_memset((void *)&s->_uya_loc_xxx, 0, sizeof(...));`
  - 标识符（数组拷贝）：`__uya_memcpy((void *)s->_uya_loc_xxx, ..., sizeof(...));`
- 这修复了 `while`/`if` 等**不含 `@await` 的嵌套控制流**中的 `const` 指针在 resume 路径上未初始化导致的 null 指针解引用崩溃。

#### 3. 泛型上下文下的类型单态化

- `src/codegen/c99/stmt.uya`：`return error.X` 的 payload C 类型通过 `c99_mono_type_to_c` 解析，避免在泛型 `@async_fn` 中使用未单态化的 `struct err_union_size_t`。
- `src/codegen/c99/expr.uya`：`as!` 强制类型转换的 `value` 字段同样通过 `c99_mono_type_to_c` 处理泛型参数。

### 标准库修复

- `lib/std/http/http1_async.uya`：
  - 移除 `catch { ... }` 块内的多余分号（语法错误）。
  - 重新启用此前被 TODO 绕过的 `http_check_deadline(deadline_ms)` 超时检查。
- `lib/tls/https.uya`：
  - 修复 `catch` 块语法。
  - 修正 `as!` 溢出使用方式：先提取 `!i32` 的 `.value`，再进行位运算与强制转换。

---

## 升级指南

从 v0.9.1 升级到 v0.9.2（或从 v0.9.0 直接升级）：

```bash
git pull
git checkout v0.9.2   # 发布打 tag 后

make clean && make check   # 或 make release-dirty 完整验证
```

若依赖单文件种子：提交中包含 **`backup/uya.c`** 时与仓库保持一致。

---

## 统计与验证

| 项目 | 说明 |
|------|------|
| 相对 v0.9.1 | 见 `git log v0.9.1..HEAD` |
| 回归测试 | `make check` **779** 项全部通过 |
| 重点验证 | `test_http1_async_client`、`test_https_loopback`、`test_https_production`、`test_https_bridge_safety` 等 14 项 HTTP/HTTPS 测试全部通过 |
| 自举验证 | `make b` 通过，字节一致 |
| 上一标签 | `v0.9.1` |

---

## 致谢

感谢所有为本版本贡献代码、测试与文档的参与者。

---

**标签**：`v0.9.2`  
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.9.2)  
**完整变更日志**：[CHANGELOG.md](../../CHANGELOG.md)
