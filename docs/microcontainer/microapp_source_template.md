# 微应用源码模板

本文给出一份当前阶段可参考的微应用源码形状。

## 目的

这个模板不是最终编译后端产物，而是帮助读者理解：

- 微应用源码应该长什么样
- microapp 模式下允许哪些入口风格
- 后续如何从源码走到 `payload_obj` 和 `.uapp`

## 示例

```uya
use std.runtime.entry;
use std.microapp.io.write_stdout_bytes;

export fn main() i32 {
    _ = write_stdout_bytes("hello microapp\n", 15) catch {
        return 1;
    };
    return 0;
}
```

## 说明

- 这份模板现在主要用于说明源码层的意图。
- 目标 CLI 是 `uya microapp build -o xxx.uapp`；调试分发时也可直调
  `bin/cmd/microapp build -o xxx.uapp`。
- 当前推荐的源码级心智是：
  - 优先使用 `std.microapp.*`
  - 优先使用 `--microapp-profile ...`
  - 需要时再让 `TARGET_OS/TARGET_ARCH` 自动推导 profile
- 现阶段 `microapp` 的 `code` 仍来源于目标 gcc 的 `.text` 输出，但默认编译/链接旗标已经按 profile 区分：
  - `call_gate` profile 默认 `-fpie/-pie`
  - `trap` profile 默认 `-fno-pie/-no-pie`
- 当前推荐直接参考这些 portable source 示例：
  - `examples/microapp/microcontainer_hello_source.uya`
  - `examples/microapp/microcontainer_alloc_yield_source.uya`
  - `examples/microapp/microcontainer_time_source.uya`
  - `examples/microapp/microcontainer_bss_source.uya`
- `examples/microapp/microcontainer_hello_build.uya` / `examples/microapp/microcontainer_hello_load.uya` 是宿主侧构建/加载工具，不属于 portable source 子集。
- 当前仍保留 `payload_obj` 作为中间边界，便于单独测试和调试；它现在也会携带源文件路径等 provenance 信息。
- 当前推荐的验证入口：
  - 全量 microapp 回归：`make microapp-check`
  - hosted smoke：`make microapp-hosted-smoke`
  - arm64-host-gated 的 aarch64 runtime：`make microapp-aarch64-runtime-check`
  - macOS arm64-host-gated 的 runtime：`make microapp-macos-runtime-check`
  - `.uapp v1/v2` 兼容：`make microapp-compat-check`
  - crash/recovery/update：`make microapp-recovery-check`
- 如果你是从旧路径迁移过来，建议继续看 `migration_guide.md`。
