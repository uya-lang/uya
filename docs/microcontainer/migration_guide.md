# MicroApp 迁移指南

本文面向两类读者：

- 已经在仓库里使用旧的 `microapp`/微容器路径，希望迁到当前推荐用法
- 正在阅读历史文档、脚本或示例，需要快速分辨哪些是“当前推荐路径”，哪些只是宿主侧调试工具

---

## 1. 先记住当前推荐路径

当前推荐的 portable microapp 开发方式是：

1. 写 portable 源码
2. 只使用 `std.microapp.*`
3. 用 `--microapp-profile` 或 target tuple 选择目标 profile
4. 目标 CLI 使用 `uya microapp build|pack|inspect|verify|run` 走统一链路

> 迁移说明：旧形态 `build --app microapp`、`run --app microapp`、
> `pack-image`、`inspect-image`、`verify-image` 不再是推荐入口。新的工具链目标是
> `uya microapp build|pack|inspect|verify|run`；需要排查 launcher 分发时，可直调
> `bin/cmd/microapp ...` 做等价对照。

推荐优先参考这些源码示例：

- `examples/microapp/microcontainer_hello_source.uya`
- `examples/microapp/microcontainer_alloc_yield_source.uya`
- `examples/microapp/microcontainer_time_source.uya`
- `examples/microapp/microcontainer_bss_source.uya`

这几个文件属于：

- portable source 子集

下面这些不是 portable source，而是宿主侧工具：

- `examples/microapp/microcontainer_hello_build.uya`
- `examples/microapp/microcontainer_hello_load.uya`

---

## 2. 从旧心智迁到新心智

### 2.1 从 `arch-first` 迁到 `profile-first`

旧习惯（迁移前，不再推荐）：

```bash
MICROAPP_TARGET_ARCH=x86_64 ./bin/uya build --app microapp app.uya -o app.uapp
```

目标推荐：

```bash
./bin/uya microapp build \
  --microapp-profile linux_x86_64_hardvm \
  app.uya -o app.uapp
```

如果你更喜欢环境变量，也可以：

```bash
MICROAPP_TARGET_PROFILE=linux_x86_64_hardvm \
./bin/uya microapp build app.uya -o app.uapp
```

如果你不想显式写 profile，也可以让目标平台 tuple 自动推导：

```bash
TARGET_OS=macos TARGET_ARCH=arm64 \
./bin/uya microapp build app.uya -o app.uapp
```

一句话：

- `profile` 现在是主入口
- `arch` 只是在没显式给 profile 时的回退信息

---

### 2.2 从宿主 API 迁到 `std.microapp.*`

旧习惯通常会直接写：

- `use libc.write_stdout_bytes`
- `use std.time`
- 直接碰宿主 `libc` 时间/调度接口

当前推荐替换关系：

- 输出：`std.microapp.io.write_stdout_bytes`
- 分配：`std.microapp.mem.alloc`
- 让出执行：`std.microapp.task.yield_now`
- 时间：`std.microapp.time.unix_millis`

例如：

```uya
use std.runtime.entry;
use std.microapp.io.write_stdout_bytes;
use std.microapp.time.unix_millis;

export fn main() i32 {
    const now_ms: u64 = unix_millis() catch {
        return 1;
    };
    _ = write_stdout_bytes("time ok\n", 8) catch {
        return 2;
    };
    return 0;
}
```

当前编译器已经会对用户 portable source 直接：

- `use libc.*`
- `use std.time`
- 调用这些宿主 API

报 `E4004`，并给出 `std.microapp.*` 替代建议。

---

### 2.3 从手工 pack/load 迁到统一 CLI

旧路径里，常见做法是：

- 先自己产出 `.pobj`
- 再手工 `pack-image`
- 或直接跑宿主侧 builder / loader 示例

目标推荐把日常路径统一成：

```bash
./bin/uya microapp build app.uya -o app.uapp
./bin/uya microapp run app.uya
./bin/uya microapp inspect app.uapp
./bin/uya microapp verify app.uapp
```

如果你确实需要看中间产物，再拆成：

```bash
./bin/uya microapp build app.uya -o app.pobj
./bin/uya microapp pack app.pobj -o app.uapp
./bin/uya microapp inspect app.pobj
./bin/uya microapp verify app.pobj
```

所以现在的建议是：

- 日常开发优先直接 `.uapp`
- 需要调试镜像结构时再显式看 `.pobj`

---

## 3. 迁移检查清单

把旧项目迁到当前推荐路径时，建议按这个顺序做：

1. 把源码里的 `libc.*` / `std.time` 换成 `std.microapp.*`
2. 确认源码只保留 portable source 允许的接口
3. 把构建入口改成 `--microapp-profile ...`
4. 用 `uya microapp build -o xxx.c` 先验证 compile matrix
5. 用 `uya microapp build -o xxx.uapp` / `uya microapp run` 验证当前已支持的 runtime profile
6. 用 `uya microapp inspect` / `uya microapp verify` 确认产物元数据和格式版本

---

## 4. 当前建议的验证入口

如果你只想快速确认迁移结果：

- 全量 microapp 回归：`make microapp-check`
- hosted 平台 smoke：`make microapp-hosted-smoke`
- arm64-host-gated 的 aarch64 runtime：`make microapp-aarch64-runtime-check`
- macOS arm64-host-gated 的 runtime：`make microapp-macos-runtime-check`
- `.uapp v1/v2` 兼容：`make microapp-compat-check`
- crash/recovery/update：`make microapp-recovery-check`

---

## 5. 当前边界

迁移到当前推荐路径后，需要知道这些边界仍然存在：

- `linux_x86_64_hardvm` 是当前最完整的真执行路径
- 其他 profile 有的已打通 compile matrix / metadata，但 runtime 仍未完全补齐
- host-side builder/load 示例仍保留宿主依赖，它们不是 portable source 子集
- relocation / trampoline / 其他 hosted profile 真执行仍在持续推进

所以当前最稳的目标不是“所有平台一次到位”，而是：

- 先把源码迁到 portable source 子集
- 再按 profile 分层验证 compile/runtime 能力
