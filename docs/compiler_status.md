# Uya 自举编译器实现程度报告

**版本**: v0.10.4（版本唯一来源 `src/version.uya`）
**更新日期**: 2026-10-19
**统计口径**: 当前工作树，排除 `src/build/` 与 `src/.uyacache/` 等生成目录

---

## 总体状态

| 指标 | 数值 |
|------|------|
| 源文件数（`src/` 下 `.uya`） | 82 个 |
| 源代码行数 | ~126,900 行 |
| 顶层入口 | `src/main.uya`（3,912 行）+ `src/compile.sh`（构建编排） |
| 单文件测试 | 1,164 个（`tests/*.uya`） |
| 其中功能 / 错误 / 复现 | `test_*` 894、`error_*` 198、`tests/repros/` 17 |
| 测试脚本 | `tests/*.sh` 184 个 |
| 最近一次全量验证 | `make check` **1153/1153** 单文件测试通过（见 `docs/releases/RELEASE_v0.10.4.md`） |

> 本文档为滚动更新：**以 `make check` / `make b` 的实际结果为准**。本轮文档同步未复跑全量闸门。

---

## 模块实现状态

### 词法 / 语法 / 语义

| 模块 | 文件 | 行数 | 状态 |
|------|------|------|------|
| 词法分析器 | `src/lexer.uya` | 1,464 | ✅ 完成 |
| 语法分析 · 入口 | `src/parser/main.uya` | 1,055 | ✅ 完成 |
| 语法分析 · 声明 | `src/parser/declarations.uya` | 2,675 | ✅ 完成 |
| 语法分析 · 表达式 | `src/parser/expressions.uya` | 975 | ✅ 完成 |
| 语法分析 · 基础表达式 | `src/parser/primary.uya` | 2,766 | ✅ 完成 |
| 语法分析 · 语句 | `src/parser/statements.uya` | 680 | ✅ 完成 |
| 语法分析 · 类型 | `src/parser/types.uya` | 1,038 | ✅ 完成 |
| AST 定义 | `src/ast.uya` | 904 | ✅ 完成 |
| Arena 分配 | `src/arena.uya` | 283 | ✅ 完成 |
| 检查器 · 入口 | `src/checker/main.uya` | 1,170 | ✅ 完成 |
| 检查器 · 表达式 | `src/checker/check_expr.uya` + `check_expr_extra.uya` | 6,938 | ✅ 完成 |
| 检查器 · 语句 | `src/checker/check_stmt.uya` + `check_node_extra.uya` | 2,038 | ✅ 完成 |
| 检查器 · 调用/元组/下标 | `src/checker/check_call.uya` | 2,869 | ✅ 完成 |
| 检查器 · 约束与区间证明 | `src/checker/interval.uya`、`proof.uya` | 3,262 | ✅ 完成 |
| 检查器 · 移动/类型 | `src/checker/types.uya`、`type_utils.uya`、`type_layout.uya` 等 | 3,838 | ✅ 完成 |
| 检查器 · 宏展开 | `src/checker/macro_expand.uya` | 4,175 | ✅ 完成 |
| 检查器 · 模块解析 | `src/checker/modules.uya`、`lookup.uya` | 3,714 | ✅ 完成 |
| 检查器 · 动态表 | `src/checker/dyn_table.uya` | 290 | ✅ 完成（v0.10.3+ 五张定长表已改为动态哈希表） |
| 主机/目标配置 | `src/std_cfg.uya` | 240 | ✅ 完成 |
| 格式化 | `src/fmt.uya` | 1,121 | ✅ `uya fmt` |
| 并行前端 | `src/parallel.uya`、`parse_parallel.uya` | 776 | ✅ 进程级并行 + 增量指纹 |

### 代码生成（C99 后端）

| 模块 | 文件 | 行数 | 状态 |
|------|------|------|------|
| 表达式生成 | `src/codegen/c99/expr.uya` | 10,657 | ✅ 完成 |
| 函数生成 | `src/codegen/c99/function.uya` | 9,374 | ✅ 完成 |
| 类型生成 | `src/codegen/c99/types.uya` | 8,930 | ✅ 完成 |
| 主生成器 | `src/codegen/c99/main.uya` | 6,604 | ✅ 完成 |
| 语句生成 | `src/codegen/c99/stmt.uya` | 4,228 | ✅ 完成 |
| 结构体生成 | `src/codegen/c99/structs.uya` | 3,689 | ✅ 完成 |
| 工具函数 | `src/codegen/c99/utils.uya` | 3,313 | ✅ 完成 |
| 全局变量 | `src/codegen/c99/global.uya` | 1,195 | ✅ 完成 |
| 枚举生成 | `src/codegen/c99/enums.uya` | 518 | ✅ 完成 |
| 内部定义 | `src/codegen/c99/internal.uya` | 480 | ✅ 完成 |
| 并行发射 | `src/codegen/c99/parallel.uya` | 407 | ✅ 完成 |

### 其他后端 / 驱动

| 模块 | 文件 | 行数 | 状态 |
|------|------|------|------|
| exec / bytecode 后端 | `src/exec/`（9 个文件） | 14,120 | 🔶 部分（基础标量、match、`!T`、聚合值；async 明确不支持） |
| async lowering | `src/lower/async.uya` | 1,532 | ✅ 完成 |
| 构建驱动 | `src/driver/{modules,path_list,toolchain}.uya` | 2,759 | ✅ 完成 |
| 子命令 | `src/cmd/build/`、`src/cmd/upm/` | — | 🔶 build/upm 已外置；`src/main.uya` 仍有 `CommandType` / `parse_args` / `print_usage` 待提取 |
| microapp | `src/microapp/main.uya` | 3,394 | ✅ 完成（5 个 profile：`linux_x86_64_hardvm` / `linux_aarch64_hardvm` / `macos_arm64_hardvm` / `rv32_baremetal_softvm` / `xtensa_baremetal_softvm`） |

---

## 语言特性支持

### ✅ 核心特性（已实现）

- 基本类型：`i8` `i16` `i32` `i64` `u8` `u16` `u32` `u64` `usize` `isize` `f32` `f64` `bool` `byte` `void`
- 指针：`&T`（普通指针）、`*T`（FFI 指针）、`&atomic T`
- 数组 / 切片：`[T: N]`、`&[T]`、`&[T: N]`（含负索引切片与切片范围校验）
- 结构体：普通 / `opaque struct`（字段与字面量构造仅声明文件可见，按值移动检查）；所有 struct 统一 C 布局
- 联合体：编译期标签跟踪 + 活跃变体 drop
- 枚举、元组、错误联合 `!T`
- 泛型：`<T>`、`<T: Constraint>`、多约束 `<T: Ord + Clone + Default>`、泛型方法
- 接口：鸭子类型、具体 struct → 接口赋值装箱
- 函数：普通 / 泛型 / 可变参数 / `@naked_fn` / `@async_fn` / `@align(N)`
- 控制流：if/else、while、for（`|v|`、`|&v|`、范围 `a..b`、`a..`）、break/continue、match
- 错误处理：`try` / `catch` / `defer` / `errdefer`、预定义 `error Name;` 与运行时错误
- 字符串插值、切片、安全指针算术、原子类型 `atomic T`
- 类型别名 `type Name = Type;`、`mc` 宏、`test "name" {}`、shebang 脚本
- **typed pipeline**：`|>` 前向操作符（仅用于 `Pipeline` / `!Pipeline`，右侧须为调用）
- `@c_import("path", cflags?, ldflags?)` 顶层构建指令

### ✅ 内存安全（编译期证明）

- [x] 数组边界检查（常量与区间证明）
- [x] 空指针检测（局部变量）
- [x] 未初始化变量检测
- [x] 整数溢出检测（常量折叠期报错 + `try`/`catch` 运行时 checked 算术：溢出 → `error.Overflow`、除零 → `error.DivisionByZero`）
- [x] `--strict-overflow` 静态闸门（可选，默认关）：**有符号** `+ - *` 必须能证明无溢出，否则编译错误（无符号模运算豁免）；
- [x] 未证明的有符号溢出不再落入 C UB：构建与生成代码统一带 `-fwrapv -fno-strict-overflow`，溢出为定义良好的回绕；
      证明器基于 i64 宽化区间，仅采纳可信约束（用户守卫 + 无回绕增量）。回归 `tests/verify_strict_overflow.sh`
- [x] 除零检测（常量）
- [x] 移动语义检测（含嵌套字段 / 访问路径）
- [x] 切片范围校验
- [x] 内存安全证明系统（`--safety-proof`，默认开启）

> 已知缺口（详见 `buglist.md`）：循环体下标 ③、切片形参下标 ⑤缺口1、指针形参解引用 ⑥ 仍未接上证明；除法的除数非零证明尚未实现；**变量算术的溢出不会自动报错**——需要检查时显式写 `try a + b` 或 `(a + b) catch |e| { … }`。

### ✅ 内置函数（已实现）

- `@size_of(T)` / `@align_of(T)` / `@len(x)` / `@min` / `@max`
- `@embed("path")` / `@embed_dir("path")` / `@c_import(...)`
- `@syscall(nr, ...)`（linux / macos / windows 目标）
- `@va_start` / `@va_arg` / `@va_end` / `@va_copy`（`va_list` 为内置类型）
- `@src_name` / `@src_path` / `@src_line` / `@src_col` / `@func_name`
- `@ptr_from_usize` / `@usize_from_ptr`
- `@error_id` / `@error_name`
- `@print` / `@println`
- `@frame(fn)` / `@async_fn` / `@await` / `@naked_fn` / `@align(N)`
- 宏：`@mc_ast` / `@mc_type` / `@mc_source` / `@mc_eval` / `@mc_code` / `@mc_error` / `@mc_get_env`
- SIMD：`@vector(T, N)` / `@mask(N)`
- 内联汇编：`@asm`、`@asm_target`、`@asm_reg*`、`@asm_mem`、`@cmpxchg` / `@xadd` / `@xchg`、`@lfence` / `@mfence` / `@sfence`

### ✅ 模块系统

- [x] 目录级模块
- [x] `use` 导入 / `export` 导出
- [x] 自动依赖收集与多文件 split-C 发射

---

## 部分实现 / 已知限制

| 特性 | 状态 | 说明 |
|------|------|------|
| SIMD `@vector(T,N)` / `@mask(N)` | 🔶 部分 | 规范 + Parser/Checker/C99 标量 struct 回退（含算术/比较/位运算/饱和与包装运算）；真实 SIMD lowering 待办 |
| exec `--exec` 后端 | 🔶 部分 | 基础程序可跑；async/`@await`/`@frame`、`@c_import` 直接接入、SIMD、inline asm、非 hosted 目标、JIT 未支持 |
| async 跨平台 | 🔶 部分 | Linux epoll、macOS kqueue 已落地；Windows IOCP 未实现 |
| Windows 目标 | 🔶 部分 | 交叉自举 / `@syscall` / Winsock / 控制台代码页已打通；运行时层与 hosted typed pipeline 未完成 |
| 标准库 | ✅ 主线可用 | `lib/std/` 30+ 模块（crypto、http、json、yaml、protobuf、sql、mqtt、image、process、script 等），真实数据库 / HTTP/3 等驱动未并入 |

---

## 测试覆盖

### 按类型统计（`tests/` 顶层）

| 类型 | 数量 |
|------|------|
| 功能测试 `test_*` | 894 |
| 错误测试 `error_*` | 198 |
| 多文件 / 其他 | 72 |
| 最小复现 `tests/repros/` | 17 |
| 合计单文件 `.uya` | 1,164 |

> 最近一次 `make check` 的任务口径为 **1153/1153**（见 `docs/releases/RELEASE_v0.10.4.md`）；测试文件数与任务数口径不同（部分用例由脚本按平台/网络条件跳过）。

### 主要覆盖领域

- ✅ 基本表达式和运算符
- ✅ 控制流语句
- ✅ 函数定义和调用
- ✅ 结构体 / 联合体 / 枚举 / 元组
- ✅ 泛型与接口
- ✅ 错误处理、defer/errdefer
- ✅ 内存安全证明与 UB 负例
- ✅ 宏系统与宏卫生
- ✅ 模块系统与多文件 split-C
- ✅ 系统调用与 FFI / `@c_import`
- ✅ async / `@frame` / `@await`
- ✅ 内联汇编与 SIMD 标量回退
- ✅ microapp 镜像与运行时

---

## 代码质量

| 指标 | 状态 |
|------|------|
| 自举验证 | ✅ `make b`（主编译器与自举编译器产物 `cmp` 字节一致） |
| 安全检查构建 | ✅ `make uya-safety` 可构建启用内存安全检查的编译器 |
| 测试结果 | 以 `make check` 实际结果为准 |
| 代码规范 | 命名常量、分模块文件、`///` 公共注释 |

---

## 构建信息

```bash
# 冷启动（Linux）
make from-c

# 冷启动（macOS）
make from-c-native

# 日常自举构建 / hosted 构建
make uya
make uya-hosted

# 验证
make b            # 自举一致性
make check        # 自举 + 全量测试
make check-hosted # hosted 路线
```

---

## 结论

Uya 自举编译器 **v0.10.4** 已实现语言规范的核心特性，能够成功编译自身并生成 C99 代码；
默认的编译期安全证明覆盖数组边界、空指针、初始化、溢出、移动语义与切片范围。
剩余工作集中在平台后端（Windows IOCP / async 运行时）、exec 后端补齐、typed pipeline 的
Windows hosted 路径与 HTTP/3 等协议扩展，详见 `docs/todo_status_index.md`。

（本文档为滚动更新：以 `make check` / `make b` 的实际结果为准。）
