# Uya 静态方法（`Type.method(...)`）设计文档

**版本**：v0.1  
**创建日期**：2026-04-25  
**状态**：主线已实现（2026-04-26 已按实现语义回填）  
**配套 TODO**：[todo_static_method.md](todo_static_method.md)

---

> 2026-04-26 实现回填：
> 当前真实语义以 `uya.md` 为准。最终行为是：
> 1. `Type.method(...)` 是所有方法的统一命名空间调用；
> 2. 当首参为实例 receiver 时，额外允许 `obj.method(...)` 语法糖；
> 3. 方法调用结果可继续参与任意深度的后缀链，包括 `obj.method<T>().next()`。

> **实现状态核对（2026-10-19，编译器 v0.10.4）**：已用 `bin/uya` 实测：
> - 无 receiver 的"静态"方法可用：`Counter.create(7)` ✅
> - 实例语法糖可用：`c.get()` ✅
> - 显式命名空间传值 receiver 可用：`Counter.getval(c)` ✅
> - **已知缺陷**：显式命名空间传**引用** receiver（`fn get(self: &Self)` + `Counter.get(&c)`）会生成坏 C（`({ void __uya_recv_0 = (&c); &__uya_recv_0; })`，宿主工具链报 `variable or field '__uya_recv_0' declared void`）。在此之前请用 `c.get()` 或按值 receiver 调用。

## 1. 背景

Uya 当前已经支持：

- 结构体内部方法
- 外部方法块
- 联合体内部方法
- 联合体外部方法块
- 接口方法签名
- 泛型方法
- `@async_fn` 方法

现有方法模型的核心特征是：

- 方法属于**类型命名空间**
- 方法调用在编译期静态绑定
- 编译器最终将方法展开为普通函数
- 实例方法通过显式 `self` 参数表达 receiver

这意味着 Uya 距离“静态方法”只差一步：允许类型命名空间中的方法**不带 receiver**。

本设计文档定义这一步如何落地，并明确采用：

```uya
Type.method(...)
```

而不是双冒号写法。

原因很简单：前者与 Uya 现有的成员访问视觉风格一致，语法扩展最小，也更适合与现有 `UnionName.variant(...)`、`obj.method(...)` 统一。

---

## 2. 目标

- 支持在结构体和联合体的类型命名空间中定义**无 receiver 方法**
- 用户侧调用语法统一为 `Type.method(...)`
- 复用现有方法块、方法查找、单态化与 C99 codegen 主链路
- 不引入函数重载
- 不破坏现有实例方法、接口方法、联合体变体构造语义
- 为 `new()`、`with_capacity()`、`from_*()`、工厂函数、纯类型级 helper 提供规范入口

---

## 3. 非目标

本方案**不**尝试同时解决以下问题：

- 不新增双冒号静态调用语法
- 不引入 `impl` 风格语法
- 不引入类（class）或新的对象模型
- 不让接口声明静态方法
- 不实现基于名字的重载
- 不要求立即把现有 `*_new` 顶层函数迁移为静态方法

---

## 4. 总体结论

### 4.1 公开语法

静态方法的定义位置与普通方法一致：

```uya
struct Engine {
    router: Router,
}

Engine {
    fn new() Engine {
        return Engine{ router: router_new() };
    }
}

var e: Engine = Engine.new();
```

也支持在结构体内部定义：

```uya
struct Vec<T> {
    data: &T,
    len: usize,
    cap: usize,

    fn empty() Vec<T> {
        return Vec<T>{ data: null as &T, len: 0, cap: 0 };
    }
}

const v: Vec<i32> = Vec<i32>.empty();
```

### 4.2 定义判定

- **实例方法**：首个参数是合法 receiver
  - `self: &Self`
  - `self: &StructName`
  - `self: &UnionName`
  - `drop(self: T)` 仍是按值 receiver 的特例
- **静态方法**：没有 receiver 参数

### 4.3 调用判定

- `obj.method(...)`：只匹配实例方法
- `Type.method(...)`：统一的类型命名空间调用
  - 若目标是静态方法，则按普通参数调用
  - 若目标是实例方法，则第一个实参必须显式提供 receiver

由于同一 owner 下静态/实例同名会报错，因此 `Type.method(...)` 仍不需要做“二者任选其一”的模糊解析。

---

## 5. 语法与示例

### 5.1 结构体静态方法

```uya
struct Engine {
    route_count: i32,
}

Engine {
    fn new() Engine {
        return Engine{ route_count: 0 };
    }

    fn with_routes(n: i32) Engine {
        return Engine{ route_count: n };
    }
}

var a: Engine = Engine.new();
var b: Engine = Engine.with_routes(4);
```

### 5.2 泛型结构体静态方法

```uya
struct Vec<T> {
    data: &T,
    len: usize,
    cap: usize,

    fn with_capacity(cap: usize) !Vec<T> {
        // ...
    }
}

const v: !Vec<i32> = Vec<i32>.with_capacity(16);
```

### 5.3 静态泛型方法

```uya
struct Cast {}

Cast {
    fn to<T>(x: i32) T {
        return x as T;
    }
}

const v: i64 = Cast.to<i64>(42);
```

### 5.4 异步静态方法

```uya
struct Dialer {}

Dialer {
    @async_fn
    fn connect(addr: &[const byte]) Future<!i32> {
        return try @await dial(addr);
    }
}

const fd: i32 = try @await Dialer.connect("127.0.0.1:8080");
```

### 5.5 联合体静态方法

```uya
union Token {
    eof: void,
    ident: &[const byte],
}

Token {
    fn eof_token() Token {
        return Token.eof();
    }
}
```

---

## 6. 语义规则

### 6.1 可定义位置

静态方法允许定义在：

- 结构体内部
- 结构体外部方法块
- 联合体内部
- 联合体外部方法块

静态方法**不允许**定义在：

- 顶层普通函数区
- 接口方法签名中
- 独立的接口实现块（Uya 当前也无该语法）

### 6.2 `Self` 的语义

在静态方法中，`Self` 依然表示“当前 owner 类型”，可用于：

- 返回类型
- 普通参数类型
- 局部变量类型标注
- 泛型推导相关类型位置

但静态方法体中**没有**隐式变量 `self`。

换句话说：

- `Self` 是类型占位符，仍然可用
- `self` 是值级 receiver 变量，静态方法中不存在

### 6.3 名称唯一性

同一 owner 类型内：

- 不允许实例方法与静态方法同名
- 不允许两个静态方法同名
- 不允许两个实例方法同名

也就是说，Uya 继续保持“同一类型命名空间内无重载”的原则。

### 6.4 receiver 规则

对于属于类型命名空间的方法：

- 如果第一个参数类型是合法 receiver 形式，则该方法为实例方法
- 结构体合法 receiver：`&Self` 或 `&StructName`
- 联合体合法 receiver：`&Self` 或 `&UnionName`
- 参数名不限；`self` 只是风格约定，不参与语义判定
- 无 receiver 的方法被视为静态方法

这样可以避免下面这种歧义：

```uya
Engine {
    fn build(ctx: i32) Engine { ... }   // 静态方法
}
```

### 6.5 接口约束

接口仍然只描述实例行为。

因此：

- `interface I { fn make() Self; }` 非法
- 结构体实现接口时，静态方法不参与接口实现完备性检查
- vtable 不收录静态方法

### 6.6 联合体变体冲突

联合体已经占用了：

```uya
UnionName.variant(...)
```

作为变体构造语法。

因此 v1 规则为：

- 联合体静态方法允许存在
- 但静态方法名不得与任一变体名冲突

例如：

```uya
union Token {
    eof: void,
}

Token {
    fn eof() Token { ... }   // 非法：与变体 eof 冲突
}
```

### 6.7 模块访问与类型访问

`A.B(...)` 当前可能表示：

- 模块项调用
- 联合体变体构造
- 实例成员调用
- 类型命名空间静态方法调用

引入静态方法后，member access 的语义判定原则为：

1. 如果左侧是值表达式，走字段 / 实例方法 / 接口方法逻辑
2. 如果左侧被判定为模块，走模块访问逻辑
3. 如果左侧被判定为类型，走：
   - 联合体变体构造
   - 静态方法

对于联合体，变体名与静态方法名已被禁止冲突，因此不会产生二义性。

---

## 7. 泛型与单态化

静态方法不引入新的泛型模型，只复用现有方法单态化。

### 7.1 泛型 owner

```uya
struct Vec<T> {
    data: &T,
    len: usize,
    cap: usize,

    fn with_capacity(cap: usize) !Vec<T> { ... }
}
```

调用：

```uya
Vec<i32>.with_capacity(16)
```

应像现有泛型实例方法一样生成对应单态。

注：当前实现优先覆盖 `Type<T>.method(...)` 调用与结构体内部静态方法；外部泛型方法块 `Type<T> { ... }` 仍可作为后续增强项。

### 7.2 方法自带类型参数

```uya
Cast {
    fn to<T>(x: i32) T { ... }
}
```

调用：

```uya
Cast.to<i64>(42)
```

继续沿用现有 `call_expr_type_args` 机制。

### 7.3 owner 泛型与方法泛型叠加

```uya
Box<T> {
    fn pair<U>(a: T, b: U) Pair<T, U> { ... }
}
```

调用：

```uya
Box<i32>.pair<f64>(1, 3.14);
```

单态化命名仍应复用当前“owner 类型实参 + 方法名 + 方法类型实参”的拼接逻辑。

---

## 8. 异步语义

静态方法允许加 `@async_fn`：

```uya
Client {
    @async_fn
    fn connect(addr: &[const byte]) Future<!Client> { ... }
}
```

其规则与现有异步方法保持一致：

- 可以返回 `Future<!T>` 或 `!Future<T>`
- 继续参与 async lowering
- 继续参与 monomorphization
- 不进入接口 vtable
- 不需要 receiver 传递

换句话说，它在 async 维度上只是“无 receiver 的类型命名空间方法”。

---

## 9. 编译器实现设计

## 9.1 Parser

本方案的核心判断是：**尽量不新增公开语法，只补语义分流**。

理想情况下，parser 侧无需引入新关键字，也无需为静态方法新增 AST 节点。

需要保证的是：

- 结构体内部 / 方法块中的 `fn` 仍按现有方式解析为 `AST_FN_DECL`
- 调用 `Type.method(...)` 时，现有的 `AST_MEMBER_ACCESS + AST_CALL_EXPR` 表达能力足够承载
- `Type<T>.method(...)` 的类型实参在 AST 上能够保留，不被错误降级为普通值成员访问

如果当前 parser 对 `Type<T>.method(...)` 的 object 保真不足，只做**最小补丁**，不引入新表面语法。

### 9.2 Checker：方法分类

checker 需要新增统一的分类助手，例如：

- `checker_fn_decl_receiver_kind(...)`
- `checker_fn_decl_has_receiver(...)`
- `checker_fn_decl_is_static_method(...)`

分类规则建议为：

- `drop(self: T)`：按值 receiver 特例
- `fn m(self: &Self, ...)` / `fn m(self: &Type, ...)`：实例方法
- `fn m(...)`：静态方法
- `fn m(self: X, ...)` 其中 `X` 非合法 receiver：报错

### 9.3 Checker：调用解析

现有实例方法调用大致是：

```uya
obj.method(a, b)
```

被解释为：

```uya
Type_method(&obj, a, b)
```

静态方法引入后，checker 需要同时支持两类 `Type.method(...)`：

```uya
Type.method(a, b)
```

被解释为：

```uya
Type_method(a, b)
```

以及：

```uya
Type.method(obj, a, b)
```

被解释为：

```uya
Type_method(&obj, a, b)
```

关键点：

- 参数个数校验要区分“是否有 receiver”
- 泛型方法注册要同时支持静态方法
- 返回类型推断要区分静态 / 实例两种路径，并在实例方法上继续替换 `Self` / owner 泛型
- “类型名成员访问”不能被误判成模块访问或普通字段访问
- 调用结果要能继续参与同一条后缀链，如 `Type.make().next().done()`

### 9.4 Checker：一致性校验

需要新增以下校验：

- 接口方法签名必须有 receiver
- 同一类型命名空间中静态/实例同名报错
- 联合体静态方法与变体重名报错
- 静态方法不得出现在接口实现完备性计数中

### 9.5 Codegen

静态方法不需要新的对象模型，沿用“方法降级为普通函数”的现有方案。

实例方法：

```uya
obj.add(1)
```

降级为：

```c
uya_Type_add(&obj, 1)
```

静态方法：

```uya
Type.new()
```

降级为：

```c
uya_Type_new()
```

对于 codegen，主要改动点是：

- 调用发射时不要再默认静态插入 receiver
- 方法原型 / 定义生成时允许首参为空
- 泛型静态方法的单态名继续复用现有方法命名规则
- `@async_fn` 静态方法继续接入 async frame / poll 生成

### 9.6 内部图键

异步调用图、可达性或调试输出如果需要“owner + method”的唯一键，允许继续使用任意内部字符串约定。

这属于**内部实现细节**，不构成用户语法，也不应影响语言手册的公开写法。

---

## 10. 与现有 API 的关系

Uya 当前已有大量顶层构造函数风格 API，例如：

- `uyagin_new()`
- `router_new()`
- `scheduler_new()`
- `async_fd_new(fd)`

引入静态方法后，不要求立即迁移，但允许逐步补齐等价入口：

```uya
Engine.new()
Router.new()
Scheduler.new()
AsyncFd.from_fd(fd)
```

迁移策略建议：

- v1：语言支持先落地，不动标准库公开 API
- v2：新增等价静态方法入口，保留旧顶层函数
- v3：按模块逐步决定是否废弃旧顶层入口

这样可以避免在语言能力落地之前就强行推动标准库重写。

---

## 11. 为什么不用双冒号写法

### 11.1 视觉风格不统一

Uya 当前已经有：

- `obj.method(...)`
- `Module.func(...)`
- `UnionName.variant(...)`

继续使用点号，语义上仍然是“命名空间里的成员”。

单独给静态方法引入另一套连接符，会让表面风格分裂。

### 11.2 语法成本更高

引入额外连接符意味着：

- lexer 新 token
- parser 新优先级 / 新分支
- AST 或 member access 额外状态
- codegen / checker 双路径维护

而 `Type.method(...)` 基本可以复用现有 AST 形状，只在语义层增加“左值是否为类型”的判断。

### 11.3 不符合 Uya 当前的“少新增表面语法”方向

静态方法并不是一个新对象模型，只是现有“类型命名空间函数”的一个自然补全。

如果能用最小语法增量做成，就不应先上更重的方案。

---

## 12. 为什么不用“继续只保留顶层 `*_new` 函数”

顶层构造函数当然能工作，但问题是：

- 破坏类型局部性
- 增加全局命名污染
- 泛型类型的构造函数命名不自然
- 与已有方法块模型不一致

例如下面两者相比：

```uya
const v = try vec_with_capacity<i32>(16);
```

```uya
const v = try Vec<i32>.with_capacity(16);
```

后者更接近“这是 `Vec<T>` 的能力”，也更符合类型命名空间的设计。

---

## 13. 回归样例

### 13.1 正例

```uya
struct Engine {
    route_count: i32,
}

Engine {
    fn new() Engine {
        return Engine{ route_count: 0 };
    }

    fn routes(self: &Self) i32 {
        return self.route_count;
    }
}

fn test_static_method() !void {
    const e: Engine = Engine.new();
    try assert_eq_i32(e.routes(), 0);
}
```

### 13.2 反例：实例调用静态方法

```uya
const e: Engine = Engine.new();
_ = e.new();   // 编译错误
```

### 13.3 反例：类型调用实例方法

```uya
_ = Engine.routes();   // 编译错误
```

### 13.4 反例：同名冲突

```uya
Engine {
    fn new() Engine { ... }
    fn new(self: &Self) Engine { ... }   // 编译错误
}
```

### 13.5 反例：接口静态方法

```uya
interface Factory {
    fn new() Self;   // 编译错误
}
```

---

## 14. 分阶段落地建议

### 阶段 1

- 先支持结构体静态方法
- 支持内部定义与外部方法块
- 支持普通返回类型和泛型方法

### 阶段 2

- 打通联合体静态方法
- 补齐异步静态方法
- 完善泛型 owner + 泛型方法叠加单态

### 阶段 3

- 文档入主规范
- 为标准库挑选少量代表性类型增加静态方法入口
- 评估是否保留顶层 `*_new` 兼容层

---

## 15. 最终结论

Uya 的静态方法应被视为：

**类型命名空间中的无 receiver 方法**

因此最合适的公开写法是：

```uya
Type.method(...)
```

而不是引入新的连接符或新的对象模型。

这条路线的优点是：

- 与现有方法模型一致
- 对 parser / AST 扰动最小
- 能复用 lookup / checker / codegen / monomorphization 现有基础设施
- 能自然承接 `new()`、工厂函数、类型级 helper、异步工厂与泛型构造接口

如果后续进入实施阶段，请以 [todo_static_method.md](todo_static_method.md) 作为分解执行清单。
