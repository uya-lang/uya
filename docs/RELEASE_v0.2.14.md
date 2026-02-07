# Uya v0.2.14 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.13 以来的提交记录整理，完成 **移动语义** 的 C 实现与 uya-src 自举同步，并更新规范至 **0.37**（明确 drop 方法的使用限制）。测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. 规范 0.37：drop 方法使用限制

- **changelog.md**：新增 0.37 版本变更，强调 drop 只能在结构体或方法块中定义，禁止顶层定义
- **uya.md**：详细说明 drop 方法的定义位置及相关规范变更
- **comparison.md / readme.md / uya_ai_prompt.md**：版本与示例同步至 0.37
- **todo_mini_to_full.md**：待办标记为 0.37 版本变更

### 2. 移动语义实现（C 版）

- **规范**：uya.md §12.5，结构体赋值/传参/返回为移动，活跃指针禁止移动
- **类型检查（checker.c）**：
  - `moved_names` / `moved_count`：当前函数内已移动变量名集合
  - `Symbol.pointee_of`：若变量值为 `&x`，记录被指变量名 `x`，禁止移动 `x`
  - `moved_set_contains` / `has_active_pointer_to` / `checker_mark_moved` / `checker_mark_moved_call_args`
  - 使用标识符时检查「已被移动」；移动前检查「存在活跃指针」「循环中不能移动」
  - 在赋值/const 初始化/return/函数实参/结构体字面量字段处，对结构体变量源标记移动；`p = &x` 时记录 `pointee_of`
- **UYA_MINI_SPEC.md**：反映内存管理与移动语义支持

### 3. 移动语义自举同步（uya-src）

- **checker.uya**：
  - `Symbol.pointee_of`、`TypeChecker.moved_names` / `moved_count`
  - `moved_set_contains`、`has_active_pointer_to`、`checker_mark_moved`、`checker_mark_moved_call_args`
  - AST_IDENTIFIER 使用前查已移动；var_decl/assign/return/call/struct_init 处标记移动及 pointee_of；for/match/catch 等新建符号时 `pointee_of = null`
  - **自举兼容**：新增 `copy_type(t: &Type) Type`，在返回/赋值处用 `copy_type(&...)` 避免对同一 Type 变量多次移动；对指针链式访问使用局部变量避免 codegen 生成错误 C
- **checker.c**：修正 `checker_mark_moved` 前向声明（补全第四参数 `struct_name`）

### 4. 测试用例

- **成功路径**：`test_move_simple.uya` — 结构体赋值/传参/返回为移动，通过
- **预期编译失败**：
  - `error_move_use_after.uya` — 移动后再次使用
  - `error_move_active_pointer.uya` — 存在活跃指针时移动
  - `error_move_in_loop.uya` — 循环中移动

---

## 测试验证

- **C 版编译器（`--c99`）**：test_move_simple 通过，error_move_* 预期失败
- **自举版编译器（`--uya --c99`）**：同上
- **自举构建**：`./compile.sh --c99 -e` 成功

---

## 文件变更统计（自 v0.2.13 以来）

**规范与文档**：
- `uya.md`、`changelog.md` — 0.37、drop 使用限制
- `comparison.md`、`readme.md`、`uya_ai_prompt.md`、`todo_mini_to_full.md` — 版本与待办同步
- `compiler-c-spec/UYA_MINI_SPEC.md` — 移动语义与内存管理

**C 实现**：
- `compiler-mini/src/checker.c` — 移动语义（moved_names、pointee_of、mark_moved、mark_moved_call_args）、前向声明修正
- `compiler-mini/src/checker.h` — Symbol.pointee_of、TypeChecker.moved_names/moved_count（若在本轮提交中）

**自举实现（uya-src）**：
- `compiler-mini/uya-src/checker.uya` — 移动语义检查、copy_type、pointee_of 与 moved 集合、指针链访问局部变量

**测试用例**：
- `test_move_simple.uya`、`error_move_use_after.uya`、`error_move_active_pointer.uya`、`error_move_in_loop.uya`

---

## 待办事项状态

在 `todo_mini_to_full.md` 中：

| 阶段 | 状态 | 说明 |
|------|------|------|
| 8. drop / RAII | ✅ | v0.2.13 已完成 |
| 8. 移动语义 | ✅ | C 实现与 uya-src 已同步 |

---

## 版本对比

### v0.2.13 → v0.2.14 变更

- **新增特性**：
  - ✅ 移动语义：结构体赋值/传参/返回为移动，已移动变量不能再次使用
  - ✅ 活跃指针检查：`p = &x` 后禁止移动 `x`
  - ✅ 循环中禁止移动
  - ✅ 规范 0.37：drop 方法使用限制（定义位置）

- **改进**：
  - uya-src checker 增加 copy_type 与移动语义逻辑，满足自举与规范一致

- **测试覆盖**：
  - 1 个移动成功用例 + 3 个移动错误检测用例

---

## 使用示例

### 移动语义（合法）

```uya
struct S { x: i32 }

fn take(s: S) void { }

fn main() i32 {
  var a: S = S{ x: 1 };
  var b: S = a;        // a 被移动
  take(b);             // b 被移动
  return 0;
}
```

### 移动后使用（报错）

```uya
// error_move_use_after.uya
struct S { x: i32 }
fn main() i32 {
  var a: S = S{ x: 1 };
  var b: S = a;
  const _: i32 = a.x;  // 错误：变量 'a' 已被移动，不能再次使用
  return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：

1. **模块系统**：目录即模块、export/use 语法、循环依赖检测
2. **原子类型**：atomic T、&atomic T
3. **运算符与安全**：饱和/包装运算、as!、内存安全证明
4. **联合体（union）**

---

## 相关资源

- **语言规范**：`uya.md`（0.37）
- **语法规范**：`grammar_formal.md`
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/`

---

**本版本完成移动语义的 C 实现与 uya-src 同步，并更新规范至 0.37（drop 使用限制）。**
