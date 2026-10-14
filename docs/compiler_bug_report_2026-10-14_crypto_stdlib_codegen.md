# C99 backend 编译器 bug 报告（2026-10-14）

在为标准库补密码学模块（`lib/std/crypto/`：sha512、bigint、curve25519、ed25519）的过程中，
撞到三个独立的 C99 后端缺陷。三者都**不是**类型检查器的问题（`uya check` 全绿），
是代码生成/边界证明阶段的问题，且都表现为「与逻辑无关的编译失败」或「静默算错」。

当前状态：**未修复**（已在本仓库工作区里用可复现的最小样例定位到具体发射点；本文只报，未改编译器）

---

## Bug 1：同一作用域内两次「忽略返回值地调用 `!void` 函数」发射重复变量名

现象：一个 `!void` 函数被当作语句调用两次以上（返回值丢弃），生成的 C 里
每次都用同一个变量名 `_uya_stmt_tmp` 声明，于是宿主 C 编译阶段报
`redefinition of '_uya_stmt_tmp'`。

最小复现：

```uya
use std.testing.assert_eq_i32;

fn f(n: usize) !void {
    if n == 3 {
        try assert_eq_i32(0, 1);
    }
}

test "repeated_ignored_error_calls" {
    f(1);
    f(2);
    f(4);
}
```

```
$ ./bin/uya test repro.uya
/tmp/uya_output_*.c: redefinition of '_uya_stmt_tmp'
错误：宿主工具链链接失败
```

发射点：`src/codegen/c99/stmt.uya:732`（`stmt_expr_needs_error_void_propagation` 分支）：

```uya
fprintf(codegen.emit_stream as *void, "%s _uya_stmt_tmp = " as *byte, stmt_union_c as *byte);
```

变量名是**硬编码**的，没有像 `codegen.interp_temp_counter`（同文件 698 行）那样带自增后缀，
也没有把声明包进 `{ }` 作用域。

影响面：任何「连续两次调用同一个丢弃返回值的 `!void` 函数」的代码都编不过。这在
测试里极常见（辅助断言函数、准备夹具函数），本仓库新加的
`tests/test_crypto_sha512.uya` 里 `check_bytewise(...)` 被调 4 次就直接撞上。

规避（当前工作区采用）：把调用写成 `_ = f(x);`，走的是 `(void)(expr)` 分支（stmt.uya:747），不带临时变量。

建议修法（二选一）：
1. 给临时名加自增后缀：`_uya_stmt_tmp_%d`，用 `codegen.interp_temp_counter` 同款计数；
2. 或把整段（声明 + `if (error_id != 0)` + `return`）包进 `{ }`，让重复名落在不同作用域。

---

## Bug 2：`&const byte` 形参指向字面量切片时，下标访问取到错位基址

现象：把 `&"hex串"[0: n]` 这样的字面量切片作为实参传给 `&const byte` 形参，
在**函数内部**对该形参做下标（`p[i]`）会读到错误的内存——看起来像是基址错位/多加了偏移。

最小复现：

```uya
fn f(hex: &const byte, n: usize) void {
    @println(hex[0] as i64);   // 期望 100（'d'），实测 64（'@'）
    @println(hex[1] as i64);   // 期望 55（'7'），实测 208
}

export fn main() i32 {
    const hx: &[byte] = &"d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"[0: 64];
    f(hx, 64);
    return 0;
}
```

对照实验（都在同一份代码里试过）：

| 写法 | 结果 |
|---|---|
| 字面量切片直接赋给 `const hx: &[byte]`，**在 main 里**下标 | ✅ 正确（100/55） |
| 同上，但**经函数参数**传进去再下标 | ❌ 错位（64/208） |
| 把它先拷进真实 `var buf: [byte: n]`，再取 `buf[i]` | ✅ 正确 |
| 用 `.ptr[i]` 访问字面量切片 | 部分场景下生成 `(非结构体)->ptr[...]`，编译失败 |

影响面：本仓库的 `tests/test_crypto_ed25519.uya` 最初就是「用 hex 字面量解出向量再比对」的写法，
7 条用例全部因为读错数据而失败；换写成 byte 数组常量后立刻全绿。密码学测试里
「hex 常量 → 字节」是非常自然的写法，这个陷阱会让人反复怀疑自己的算法实现（本轮就绕了很久）。

规避（当前工作区采用）：向量常量写成 `var x: [byte: n] = [ ... ];` 数组字面量，不用字符串切片。

---

## Bug 3：`(a >> n) & 字面量` 这类混合类型位运算被拒（错误信息指向错误方向）

现象：`u64 >> i32` 的左操作数是 `u64`、右操作数是「未标注整型字面量」时，
`& 255` / `| 1` 之类的后续位运算会报
`位运算符 & | ^ 的两个操作数类型必须一致`，即使两边「看起来」都是整数。
把字面量补成 `255u64` / `1 as i64` 即可通过。

最小复现：

```uya
var v: u64 = 0x1122334455667788u64;
var i: usize = 0;
var b: byte = 0;
while i < 8 {
    b = ((v >> ((i * 8) as i32)) & 255) as byte;   // 报「两个操作数类型必须一致」
    i = i + 1;
}
```

同类的还有 `res[i] = res[i] & 65535;`（`res` 是 `i64`）、
`const lo: usize = (s[j] as usize) & 15;`。

影响面：手写字节序打包/解包（密码学里满地都是）时几乎每行都要改。
错误信息没有指出「你需要给字面量加类型后缀」，只说「类型必须一致」，
而调用者看到的两个操作数在源码上都是整数，定位成本高。本轮在
`lib/std/crypto/ed25519.uya` 里一次性撞出 40 处，全部靠加后缀解决。

（这一条更像「诊断质量 + 便利性」问题，不是错误代码生成；但如果后端的整数提升规则
本来就应该允许字面量参与，那它是个真 bug。）

---

## 复现环境

* 编译器：`bin/uya` v0.10.3，宿主 Linux x86_64，`cc` 为系统 gcc。
* 未使用的 `--opt` 级别：默认。
* Bug 1 的样例在 `./bin/uya test` 与 `./bin/uya build` 下都能复现。
* Bug 2/3 在 `uya build` 与 `uya test` 下都能复现。

## 本轮怎么绕过去的（供他人参考）

1. Bug 1 → 丢弃返回值时写 `_ = f(x);`。
2. Bug 2 → 常量一律写成 byte 数组；需要字符串语义时在**调用点**拷进数组再传指针。
3. Bug 3 → 位运算的字面量一律带类型后缀（`255u64`、`1 as i64`、`15 as usize`）。
