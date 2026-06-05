# 多文件 C 输出（默认 + `--split-c-dir`）

## 用途

**C99 后端默认**在目录 **`.uyacache`**（相对当前工作目录）生成多文件 C 与 **`Makefile`**，链接阶段走 **`make -C <dir> -j...`**，便于 **`make -j` 并行编译**。显式 **`-o xxx.c`**（只输出单个 C 文件）、或命令行 **`--no-split-c`**、或环境 **`UYA_SPLIT_C=0`** / **`false`** / **`no`** / **`off`**、或 **`UYA_SINGLE_FILE_C=1`** 时退回**单文件** C 路径（**`--no-split-c`** 还会忽略 **`UYA_SPLIT_C_DIR`** 与 **`--split-c-dir`**）。

若程序包含 **`@c_import`**：

- **单文件 `.c` 输出**：编译器会额外生成同名 sidecar，例如 `app.cimports.sh`
- **split-C 输出**：导入的 C translation unit 直接进入 split 根目录 Makefile 的额外 object 规则，不再额外生成 sidecar

仍可用 **`--split-c-dir`**（或 **`UYA_SPLIT_C_DIR`**）指定**其它**输出目录；行为与默认一致，仅路径不同。

**默认：镜像分 TU（一源一 `.c`）**——未设置 **`UYA_SPLIT_C_MIRROR`** 或设为 **`1`** / `true` 等时，按源路径生成多个 `.c`（外加 `uya_part1.c`、`uya_common.c` 等），**并行度最高**，适合大项目加速迭代。

**两文件模式（旧）**：设置 **`UYA_SPLIT_C_MIRROR=0`**（或 **`false`** / **`no`** / **`off`**）时，仅生成 **`uya_part1.c`** + **`uya_part2.c`** 两个大翻译单元（与早期行为一致）。生成结束后会将 **`uya_part2.c` 重写**为在文件开头插入对 part1 中全部字符串符号的 **`extern`** 声明。

**并发写保护**：同一个 **`--split-c-dir`**（包括默认 **`.uyacache`**）现在会在输出目录内部创建隐藏锁目录 **`<split-dir>/.uya-lock`**，并在其中写入 **`owner.pid`**。固定锁目录并不是先 `mkdir` 再补写 pid，而是先在 staging 目录准备好 `owner.pid`，再原子 `rename` 成正式锁目录；因此不会再出现“`.uya-lock` 已存在、但 `owner.pid` 还没写进去”的窗口。锁在 **写任何 split 生成物之前** 获取，并一直持有到整条 `uya` 命令结束，因此不仅覆盖 codegen，也覆盖后续的 **`make -C <split-dir>`** 链接阶段。若另一条编译链正在写该目录，新的 `uya` 进程会在代码生成前直接报 busy 并退出，避免把共享 `.c/.h/Makefile` 交错写坏。这样即使一个任务写成 `foo`、另一个写成 `foo/`，也仍会命中同一把锁；若发现 `owner.pid` 对应进程已死亡，或遇到旧版残留的空 `.uya-lock` 目录，编译器会自动回收 stale lock 并继续。

**`mirror_manifest.txt`**：同一目录下写入合并 AST 中各声明的 **`filename`**（去重，一行一个）。

### 镜像模式（默认）：一源一 `.c`

与 **`--split-c-dir`** 同用时，在 split 根目录生成（若未显式关闭镜像）：

- **`uya_part1_types.h`**：类型/枚举等前导声明（各 TU 先包含它）。
- **`uya_part1.c`**：`#include "uya_part1_types.h"` + 字符串池（`const char strN[]`）。
- **`uya_strings_extern.h`**：字符串符号的 `extern` 声明（供镜像 `.c` 使用）。
- **`uya_common.c`**：vtable、syscall、测试运行器等「公共」生成（避免 `static` 测试跨 TU 问题）。
- **按源路径镜像的多个 `.c`**：相对路径与工程内 `.uya` 对应（最长公共前缀剥除后落在 split 根下），每个 TU 首行包含上述头文件。

**路径**：合并 AST 里混用相对/绝对 `filename` 时，在准备阶段用 `getcwd` 将相对路径拼成绝对路径再算 LCP，避免镜像路径退化成宿主机上的绝对路径。

**类型头顺序**：`uya_part1_types.h` 在**第六步 d2（结构体定义）结束**后才关闭；此前的枚举、typedef、联合体、结构体等均写入该头文件，再切换到 `uya_part1.c` 字符串池与 `uya_common.c`，保证各镜像 `.c` 能包含完整类型。

**不单独拆成镜像 `.c` 的源**（代码生成进 `uya_common.c`，与 `runtime/entry/entry.uya`、`lib/std/runtime/runtime.uya`、`tests/` 下测试文件等同 TU）：
- **`runtime/entry/entry.uya`**：与运行时全局、栈限制初始化等强耦合。
- **`lib/std/runtime/runtime.uya`**：`static inline` 的 syscall 助手与 `uya_common` 同 TU，拆出会导致链接期找不到 `uya_syscall1` 等符号。
- **`tests/` 下 `test_*.uya`**：单独成 `.c` 时缺少跨 TU 的 C 函数原型（需后续生成前向声明或保留在 common）。

链接仍为 **`make -C <split-dir> -j...`**；Makefile 中**每条** `cc -c` 规则在 `$(CFLAGS)` 之后**固定追加** **`-I.`**（split 根目录），这样即使外层传入的 `CFLAGS` 覆盖了 Makefile 默认项，子目录下的 `.c` 仍能解析 **`#include "uya_part1_types.h"`** 等。

**`export var` / `export const`（`AST_EXTERN_VAR_DECL`）**：镜像时在 `uya_common.c` 中生成与其它 `.c` 中定义一致的全局名，并在 `get_c_name_for_identifier_ref` 中按合并 program 解析，避免仅 `AST_VAR_DECL` 路径下前缀不一致。

**已知限制**：镜像模式仍在完善中；部分宿主程序在链接成功后可能出现运行时异常（需与单文件 `--c99` 对照排查）。**`make check`** 在 **`make uya`（多文件自举）** 通过后跑测试；**`make b`** 验证多文件 C 输出一致性。

**手动** `uya build src/main.uya --split-c-dir= … --c99` 在**默认镜像**下可能因工程规模在 `make -C .uyacache` 阶段暴露问题；**根 Makefile 的 `make uya`** 已统一 **`UYA_MULTI_FILE_C=1`** 与清空 split 相关环境。小用例验证多文件生成可用 **`bash tests/split_c_smoke.sh`** 等。

若需**仅**两文件 split 以对照旧行为，可 **`export UYA_SPLIT_C_MIRROR=0`** 再 `uya build`。

**与 `make uya` / `make b`：**若在 shell 里 `export UYA_SPLIT_C_DIR` / `UYA_SPLIT_C_MIRROR`，会覆盖 Makefile 内清空逻辑，可能导致意外路径。根 Makefile 在调用 `compile.sh` 的自举目标中**清空** `UYA_SPLIT_C_DIR` / `UYA_SPLIT_C_MIRROR`，并设置 **`UYA_MULTI_FILE_C=1`**：C99 且 `-e` 时 **`-o`** 指向 **`bin/uya`**，在 **`src/.uyacache`** 生成多文件 C 并由 **`make -C .uyacache`** 链接。多文件模式下通常**不**生成 **`src/build/uya.c`**；需要单文件 **`bin/uya.c`** / **`backup/uya.c`** 时执行 **`make backup-seed`**（**`UYA_SINGLE_FILE_C=1`**、**`UYA_SPLIT_C=0`**、清空 **`UYA_MULTI_FILE_C`**）。

- **`make backup`**：依赖 **`make check`**，将 **`src/.uyacache`** 复制为 **`backup/uyacache`**（多文件备份）。
- **`make backup-seed`**：单文件重编译，更新 **`bin/uya.c`** 与 **`backup/uya.c`**（**`from-c` / `release`** 仍用单文件种子）。
- **`make backup-all`**：**`backup` + `backup-seed`**（提交前完整备份）。

**`compile.sh`** 支持 **`UYA_MULTI_FILE_C=1`** 与 **`UYA_SINGLE_FILE_C=1`**，二者互斥时以后者为准（见脚本内逻辑）。

自举 **`make check`** 在 **`make uya`（多文件）** 之后跑测试；日常 **`uya build -o app --c99`** 默认可并行多文件编译。

## 用法

```bash
# 命令行（合并写法 `--split-c-dir=<目录>` 与「下一参数为目录」相同）
uya build <输入.uya ...> --split-c-dir <目录> -o <可执行文件> --c99
uya build <输入.uya ...> --split-c-dir=<目录> -o <可执行文件> --c99

# 未指定目录时默认使用相对路径 `.uyacache`（当前工作目录下）：
#   --split-c-dir=   或   --split-c-dir  作为最后一个选项且无下一参数
uya build <输入.uya ...> --split-c-dir= -o <可执行文件> --c99

# 显式关闭多文件（单文件 C 或临时 .c + 链接）
uya build <输入.uya ...> --no-split-c -o <可执行文件> --c99

# 环境变量：显式路径覆盖默认 .uyacache；compile.sh 在 UYA_SPLIT_C 为「开启」且未设置 UYA_SPLIT_C_DIR 时可导出 .uyacache
export UYA_SPLIT_C_DIR=/path/to/uyacache
export UYA_SPLIT_C=0     # 强制单文件 C（Makefile / 测试与自举使用）

# 可选：关闭镜像，改用 uya_part1 + uya_part2 两文件模式
export UYA_SPLIT_C_MIRROR=0
```

- **`<目录>`**：将创建/使用 `Makefile`、**`mirror_manifest.txt`**，以及 **`uya_part1.c`**；镜像默认时另有 **`uya_common.c`**、**`uya_split_protos.h`**、按镜像路径生成的多个 `.c`；两文件模式时另有 **`uya_part2.c`**。
- **`-o`**：最终可执行文件路径，传给 `make UYA_OUT=...`。
- **并行度**：`make -j` 的任务数由环境变量 **`UYA_GCC_JOBS`** 控制（默认在实现中为 `2`，若未设置）。

## 与 `uya build` / `run` / `test`

生成 C 后若需要链接宿主工具链，多文件模式下会调用：

`make -C <split-dir> -j<jobs> UYA_OUT=<...> CC=... CFLAGS=... LDFLAGS=...`

与单文件模式下的一条 `cc ... one.c -o exe` 并列存在；**`--nostdlib`** 时链接参数会附加 `-nostdlib -static -lgcc`（与单文件行为对齐，且当前多文件 `nostdlib` 链接仅支持 **Linux** 目标）。

## 自举与 `compile.sh`

- **`src/compile.sh`**：若设置环境变量 **`UYA_SPLIT_C_DIR`**，主编译阶段与 `uya build` 一样生成多文件 C + `Makefile`（**默认镜像**；若需两文件可设 **`UYA_SPLIT_C_MIRROR=0`**），链接时执行 **`make -C <dir> -j$UYA_GCC_JOBS`**（与 `src/main.uya` 中 `link_split_with_make` 使用相同的 `CC` / `CFLAGS` / `LDFLAGS` 约定）。
- **自举对比（`compile.sh --c99 -e -b`）**：
  - 默认：对两次生成的 **单文件 C** 做 **`diff`**（与此前一致）。
  - 若设置了 **`UYA_SPLIT_C_DIR`**，或设置 **`UYA_BOOTSTRAP_COMPARE_BIN=1`**（或 `true`/`yes`）：改为先由自举编译器生成输出，再链接出 **`$BUILD_DIR/uya_bootstrap_compare`**，与 **`bin/uya`** 做 **`cmp -s`**（字节级一致）；多文件自举输出写入 **`$BUILD_DIR/bootstrap_split_c`**，避免覆盖主编译的 split 目录。

## 实现说明（节选）

- 顶层非 `export` 函数在 split 模式下**不再**生成 `static`，以便跨两个翻译单元链接。
- 字符串常量在 part1 中为**文件级** `const char strN[]`（非 `static`），part2 开头生成对应 `extern` 声明。
- 宏展开等阶段追加的**延迟字符串**仍写入 part1；若遇极端用例与 part2 引用顺序冲突，可再收紧（当前以自举与测试通过为准）。

## 与 `make check` / 注意事项

- **不要在测试阶段依赖全局多文件路径**：`make check` / `make tests` 会在调用 `tests/run_programs_parallel.sh` 时设置 **`UYA_SPLIT_C=0`** 并**清空** `UYA_SPLIT_C_DIR`。否则并行用例会拿不到 `-o` 指定的单文件 `.c`（split 模式下代码写入镜像 `.c` / `uya_part1.c` 等），且易与嵌套 `make` 行为冲突。
- **并发共享 split 目录**：当前策略是 **fail-fast**，不是多进程共享写入。若两个 `uya` 进程指向同一 `--split-c-dir` / 默认 `.uyacache`，其中一个会明确报 busy；如需并发编译，请给每个任务分配独立 `--split-c-dir`、独立 worktree，或串行化调用。
- **stale lock 回收边界**：当前会自动回收两类常见残留：`owner.pid` 指向已退出进程的锁目录，以及旧版实现留下的空 **`.uya-lock`** 目录。若锁目录内存在其它异常内容或权限异常，仍可能需要人工处理。
- **`zig cc` cache 目录**：若 split 链接阶段使用 **`zig cc`** 且未显式设置 **`ZIG_LOCAL_CACHE_DIR`** / **`ZIG_GLOBAL_CACHE_DIR`**，实现会默认将它们落在 **`<split-dir>/.zig-cache-local`** 与 **`<split-dir>/.zig-cache-global`**，避免把 Zig cache 散落到工作目录或全局位置；需要自定义时仍可直接覆写这两个环境变量。
- **自举编译不要依赖全局 split**：`make uya` / `make b` / `uya-hosted` 等调用 `compile.sh` 的目标会在子进程中设置 **`UYA_SPLIT_C=0`** 并**清空** `UYA_SPLIT_C_DIR` 与 `UYA_SPLIT_C_MIRROR`，始终生成单文件 `src/build/uya.c` 并更新 `bin/uya.c`。若文档旧版写「会继承」，以 Makefile 为准。
- **外层 `make -j` 与嵌套 `make`**：此前在 GNU make 开启 jobserver 时，子进程中的 `make -C <split>` 若继承 `MAKEFLAGS` 可能**死锁（表现为卡死）**。实现上在嵌套 `make` 前清除 `MAKEFLAGS` / `MFLAGS` / `GNUMAKEFLAGS`（见 `link_split_with_make` 与 `compile.sh` 的 `env -u …`）。
- **路径**：请使用**绝对路径**或确认**当前工作目录**；相对路径 `.uyacache` 会随 `cwd` 指到不同目录。拼写错误（如 `.uyacach`）会生成到意料外的目录。

## 可选冒烟测试

仓库根目录执行：

```bash
bash tests/split_c_smoke.sh
```

**更新日期**：2026-03-24
