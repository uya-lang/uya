# Uya v0.2.13 版本说明

**发布日期**：2026-02-01

本版本根据自 v0.2.11 以来的提交记录整理，完成 **drop/RAII** 的完整实现，并明确 **drop 只能在结构体内部或方法块中定义**（规范 0.36）。C 版与自举版（uya-src）同步，测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. drop/RAII 实现（C 版 + 自举版同步）

- **语法**：`fn drop(self: T) void { ... }`，规范 uya.md §12
  - **定义位置**：只能在**结构体内部**或**方法块**中定义，禁止顶层 `fn drop(self: T) void`（与不引入函数重载的设计一致）
  - 每个类型只能有一个 drop；结构体内部与方法块不能同时定义 drop

- **类型检查**：
  - 签名校验：恰好一个参数 `self: T`（按值，非指针），返回 `void`
  - 唯一性：结构体内部、方法块、顶层三者互斥（顶层 drop 直接报错「drop 只能在结构体内部或方法块中定义」）

- **代码生成**：
  - 块退出时在 defer 之后按变量声明**逆序**插入 drop 调用
  - `return` / `break` / `continue` 前对当前块已声明变量逆序调用 drop
  - drop 方法体内按字段声明**逆序**先调用字段的 drop，再执行用户逻辑
  - 空结构体 `const x: S = S{}` 零初始化时使用 `memset((void *)&x, 0, sizeof(x))` 避免 const 警告

- **实现范围**：
  - **C 版**：checker.c（drop 签名与唯一性）、codegen/c99/stmt.c（块/return/break/continue 处插入 drop）、function.c（type_has_drop_c99、drop 方法内字段逆序）
  - **uya-src**：checker.uya、codegen/c99/stmt.uya、function.uya、internal.uya、utils.uya 同步

- **测试用例**（全部通过）：
  - `test_drop_simple.uya` - 结构体内部 drop，作用域结束调用一次
  - `test_drop_order.uya` - 多变量逆序 drop（声明 a,b → 先 drop b 再 drop a）
  - `test_drop_external.uya` - 方法块中定义 drop
  - `test_drop_in_function.uya` - 全局函数内局部变量离开作用域时调用 drop
  - `error_drop_wrong_sig.uya` - drop 签名错误（编译失败）
  - `error_drop_duplicate.uya` - 同一方法块内两个 drop（编译失败）
  - `error_drop_duplicate_inner_and_block.uya` - 顶层 fn drop 禁止（编译失败）

### 2. 规范 0.36：drop 定义位置

- **uya.md**：版本 0.35 → 0.36，规范变更中明确 drop 只能在结构体/联合体内部或方法块中定义
- **§4.1 / §12 / §4.5.10**：示例与条文更新，顶层 `fn drop(self: T) void` 改为方法块形式 `T { fn drop(self: T) void { ... } }`
- **changelog.md**：新增 0.36 版本变更说明
- **compiler-mini/spec/UYA_MINI_SPEC.md**：基于规范版本 0.36，结构体行补充 drop 定义位置说明
- **readme / comparison / uya_ai_prompt / index.html**：版本与示例同步至 0.36

---

## 测试验证

- **C 版编译器（`--c99`）**：全部测试通过
- **自举版编译器（`--uya --c99`）**：全部测试通过
- **自举对比（`--c99 -b`）**：C 版与自举版生成 C 代码一致

---

## 文件变更统计（自 v0.2.11 以来，drop 与规范 0.36 相关）

**C 实现**：
- `compiler-mini/src/checker.c` - drop 签名与唯一性、禁止顶层 drop
- `compiler-mini/src/codegen/c99/stmt.c` - 块/return/break/continue 处 drop 插入、空结构体 memset  cast
- `compiler-mini/src/codegen/c99/function.c` - type_has_drop_c99、drop 方法内字段逆序
- `compiler-mini/src/codegen/c99/internal.h`、`utils.c` - drop 作用域与常量

**自举实现（uya-src）**：
- `checker.uya` - drop 校验与禁止顶层 drop
- `codegen/c99/stmt.uya` - drop 插入与 VAR_DECL 登记
- `codegen/c99/function.uya` - type_has_drop_c99、drop 方法字段逆序
- `codegen/c99/internal.uya`、`utils.uya` - drop 相关字段与初始化

**规范与文档**：
- `uya.md` - 0.36、§4.1/§12/§4.5.10 drop 定义位置与示例
- `changelog.md` - 0.36 变更
- `compiler-mini/spec/UYA_MINI_SPEC.md` - 0.36、结构体 drop 说明
- `readme.md`、`comparison.md`、`uya_ai_prompt.md`、`index.html`、`compiler-mini/todo_mini_to_full.md` - 版本与示例同步

**测试用例**：
- 新增/更新：test_drop_simple、test_drop_order、test_drop_external、test_drop_in_function、error_drop_wrong_sig、error_drop_duplicate、error_drop_duplicate_inner_and_block

---

## 待办事项状态

在 `todo_mini_to_full.md` 中：

| 阶段 | 状态 | 说明 |
|------|------|------|
| 8. drop / RAII | ✅ | C 实现完成，uya-src 已同步；规范 0.36 明确定义位置 |
| 8. 移动语义 | ⏳ | 待实现 |

---

## 版本对比

### v0.2.11 → v0.2.13 变更

- **新增特性**：
  - ✅ drop/RAII：结构体内部或方法块中 `fn drop(self: T) void`，作用域结束逆序调用
  - ✅ 规范 0.36：drop 只能在结构体/联合体内部或方法块中定义，禁止顶层定义

- **改进**：
  - 块退出、return/break/continue 前自动插入 drop；drop 方法内字段逆序清理
  - 空结构体 const 初始化 memset 使用 `(void *)` 消除警告

- **测试覆盖**：
  - 新增 7 个 drop 相关测试用例（4 个成功路径 + 3 个错误检测）

---

## 使用示例

### drop（结构体内部）

```uya
var drop_count: i32 = 0;

struct S {
  id: i32,
  fn drop(self: S) void {
    drop_count = drop_count + 1;
  }
}

fn main() i32 {
  { const s: S = S{ id: 42 }; }
  if drop_count != 1 { return 1; }
  return 0;
}
```

### drop（方法块）

```uya
struct S { id: i32 }

S {
  fn drop(self: S) void {
    // 清理
  }
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：

1. **移动语义**：结构体赋值/传参/返回为移动，活跃指针禁止移动
2. **模块系统**：目录即模块、export/use 语法、循环依赖检测

---

## 相关资源

- **语言规范**：`uya.md`（0.36）
- **语法规范**：`grammar_formal.md`
- **实现文档**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/`

---

**本版本完成 drop/RAII 实现并与规范 0.36 对齐，drop 仅允许在结构体/联合体内部或方法块中定义，避免引入函数重载。**
