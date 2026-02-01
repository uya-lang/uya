# Uya v0.2.16 版本说明

**发布日期**：2026-02-01

本版本完成 **联合体（union）** 的自举编译器（uya-src）同步。联合体在 v0.2.15 之前已于 C 版编译器中实现，本次将完整功能同步至 uya-src，实现 C 版与自举版一致。测试需同时通过 `--c99` 与 `--uya --c99`。

---

## 核心亮点

### 1. 联合体（union）自举同步完成

- **union 定义**：`union Name { variant1: Type1, variant2: Type2 }`
- **创建**：`UnionName.variant(expr)`，如 `IntOrFloat.i(42)`
- **访问**：`match` 模式匹配（`.variant(bind)` 语法），必须处理所有变体，穷尽性检查
- **实现**：带隐藏 tag 的 C 布局（`struct uya_tagged_U { int _tag; union U u; }`），零开销 match

### 2. uya-src 模块变更

| 模块 | 变更 |
|------|------|
| lexer.uya | TOKEN_UNION、`union` 关键字 |
| ast.uya | AST_UNION_DECL、MATCH_PAT_UNION、union_decl 字段 |
| parser.uya | parser_parse_union、顶层与 match 臂 `.variant(bind)` 解析 |
| checker.uya | TYPE_UNION、find_union_decl_from_program、union init/member access、match 穷尽性与变体类型推断 |
| codegen | structs/types/expr/stmt/main：find_union_decl_c99、gen_union_definition、union init、match MATCH_PAT_UNION |

### 3. 测试验证

- **test_union.uya**：定义、创建、match 表达式与语句访问，通过 `--c99` 与 `--uya --c99`
- **自举构建**：`./compile.sh --c99 -e` 成功

---

## 测试验证

- **C 版编译器（`--c99`）**：test_union.uya 通过
- **自举版编译器（`--uya --c99`）**：test_union.uya 通过
- **自举构建**：`./compile.sh --c99 -e` 成功

---

## 文件变更统计（自 v0.2.15 以来）

**自举实现（uya-src）**：
- `compiler-mini/uya-src/lexer.uya` — TOKEN_UNION、union 关键字
- `compiler-mini/uya-src/ast.uya` — AST_UNION_DECL、MATCH_PAT_UNION、union_decl 字段
- `compiler-mini/uya-src/parser.uya` — parser_parse_union、match 臂 .variant(bind) 解析
- `compiler-mini/uya-src/checker.uya` — TYPE_UNION、find_union_decl_from_program、union 类型检查与 match 穷尽性
- `compiler-mini/uya-src/codegen/c99/structs.uya` — find_union_decl_c99、gen_union_definition 等
- `compiler-mini/uya-src/codegen/c99/types.uya` — union 类型 → struct uya_tagged_Name
- `compiler-mini/uya-src/codegen/c99/expr.uya` — union init、match MATCH_PAT_UNION 表达式
- `compiler-mini/uya-src/codegen/c99/stmt.uya` — match MATCH_PAT_UNION 语句
- `compiler-mini/uya-src/codegen/c99/main.uya` — union 定义 emit

**文档**：
- `compiler-mini/todo_mini_to_full.md` — 联合体阶段标记为「C 实现与 uya-src 已同步」

---

## 版本对比

### v0.2.15 → v0.2.16 变更

- **新增/完成**：
  - ✅ 联合体（union）自举同步：uya-src 支持 union 定义、创建、match 访问
  - ✅ test_union.uya 通过 `--c99` 与 `--uya --c99`

- **非破坏性**：纯自举同步，无 API 或规范变更

---

## 使用示例

### 联合体定义与 match 访问

```uya
union IntOrFloat {
    i: i32,
    f: f64,
}

fn main() i32 {
    const vi: IntOrFloat = IntOrFloat.i(42);
    const vf: IntOrFloat = IntOrFloat.f(3.14);

    const ri: i32 = match vi {
        .i(x) => x,
        .f(_) => 0,
    };

    const rf: f64 = match vf {
        .i(_) => 0.0,
        .f(x) => x,
    };

    return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：

- **联合体扩展**：extern union、联合体方法（待实现）
- **模块系统**：目录即模块、export/use 语法
- **原子类型**：atomic T、&atomic T

---

## 相关资源

- **语言规范**：`uya.md`（§4.5 联合体）
- **语法规范**：`grammar_formal.md`
- **实现文档**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_union.uya`

---

**本版本完成联合体（union）的自举编译器同步，C 版与 uya-src 功能一致。**
