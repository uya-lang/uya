# 数组索引边界证明器不跨 `as usize` 传递范围事实（2026-06-06）

本文档记录在为 HTTP 基准（`benchmarks/http_bench_async_epoll.uya` 等）做定长数组下标时撞到的
**类型检查阶段**边界证明器限制。问题已压缩成不依赖业务代码的最小复现。

## 现象

```uya
const N: i32 = 8;
var g_arr: [i32: 8] = [];

export fn pick(i: i32) i32 {
    // 在 i32 上完整证明了下界与上界
    if i < 0 || i >= N {
        return -1;
    }
    // 该范围事实不跨 `as usize` 传递 → 此处证明失败
    return g_arr[i as usize];
}
```

类型检查失败：

```text
错误: 数组索引安全证明失败
  变量: i, 数组大小: 8
  建议: 添加边界检查 (如 if i >= 0 && i < 8)
```

守卫 `if i < 0 || i >= N { return }` 已经在 `i`（i32）上证明了 `0 <= i < N`，
其中 `N == @len(g_arr) == 8`。但下标用的是 `i as usize`，证明器没有把 `i` 上已知的
范围事实传播到 `i as usize` 这个表达式，于是判定下标越界证明失败。

## 触发条件

- 守卫建立在**被转换前的整型变量**（这里是 i32 `i`）上；
- 实际下标表达式是该变量经 `as usize`（或经命名常量参与的转换）后的值。

二者类型不同导致事实未跨 cast 传递。注意此处守卫上界用的是命名常量 `N`，
即便把 `N` 换成字面量 `8`，只要下标仍是 `i as usize`，依旧证明失败——
根因在 cast 边界丢事实，而非常量 vs 字面量。

## 期望行为

- 整型 widening / 同符号无损转换（如 `i32 -> usize`，在已证明 `i >= 0` 的前提下）应当
  **保留并传播**源变量上已知的范围事实到目标表达式；
- 至少对 `v as usize` 形式，当上下文已证明 `0 <= v` 且 `v < C` 时，应推得 `0 <= (v as usize) < C`。

## 可通过的写法（当前绕法）

把范围事实直接建立在 **usize 值**上即可证明通过：

```uya
export fn pick_ok(i: i32) i32 {
    if i < 0 {
        return -1;
    }
    const u: usize = (i as! usize).value;   // as! 为 checked cast，返回 !usize，取 .value
    if u >= @len(g_arr) {                    // 守卫直接作用在 usize 值上
        return -1;
    }
    return g_arr[u];
}
```

`@len(g_arr)` 与字面量 `8` 作为上界守卫均可被接受。`benchmarks/http_bench_async_epoll.uya`
的 `bench_worker_thread` 已采用此绕法。

## 影响范围

- 任何"先在窄整型上做范围守卫、再 `as usize` 下标定长数组"的常见写法都会被误报，
  迫使代码改用 checked cast + 在 usize 值上重做守卫，多一层样板。
- 已观察到的实例：
  - `benchmarks/http_bench_async_epoll.uya`（已绕过）
  - `benchmarks/http_bench_async_epoll_await.uya`（659/654 行，仍未编译，与本 bug 同源）

## 最小复现

- `tests/repros/bounds_prover_as_usize_cast.uya`

## 复现命令

```bash
./bin/uya build tests/repros/bounds_prover_as_usize_cast.uya -o /tmp/bounds_prover_as_usize_cast
```

## 当前结论

- 这不是 sample 逻辑 bug，而是**类型检查阶段边界证明器**对 `as usize` cast 的范围事实传播缺失。
- repro 足够小，建议补成回归测试，再定位 `src/` 中边界证明（range/bounds prover）对 cast 节点的事实传播路径，
  补上整型无损转换的区间传递规则。

## 后续（2026-09-27 更新）

- 已在当前树验证修复：本文档中的复现命令编译通过（退出码 0），
  `extract_linear_expr` 会剥掉 `AST_CAST_EXPR` 保留源变量的线性形式，
  上界事实由约束系统提供；`tests/repros/bounds_prover_as_usize_cast.uya` 保留为最小复现。
- 回归用例：`tests/test_bounds_prover_as_usize_cast.uya`（命名常量/字面量上界、上下界顺序互换、
  `&&` 型守卫、`i + 偏移`、结构体字段下标、usize 源，并做运行期取值校验）。
- 同时修掉了同源的反向问题：下标类型是 `usize` **不等于**值必然非负
  （`i as usize` 在 `i < 0` 时会回绕成巨大下标），因此"自动认定下界为 0"改为只在
  unchecked cast 的**源表达式**本身是无符号类型时成立；负例见
  `tests/error_array_bounds_signed_cast_lower_bound.uya`。
- 一并修掉约束名悬垂指针：`constraint_expr_name` 以前把 `对象.字段` 拼到栈上缓冲再交给
  `string_pool_intern`，负哈希时该函数直接返回入参，于是约束表里留下已失效的栈指针，
  表现为"换个局部变量名，同一个函数时好时坏"。
