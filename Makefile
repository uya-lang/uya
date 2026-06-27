# Uya 项目根目录 Makefile
# 提供统一的构建和测试入口
#
# 若出现「没有规则可制作目标 install」：说明当前 Makefile 过旧，请用本仓库最新 Makefile
# 替换，或从上游同步后再执行：make install PREFIX=$HOME/.local

.PHONY: all from-c from-c-native uya uya-hosted uya-std uya-nostdlib uya-portable b b-hosted b-portable bench-compile-stats tests tests-hosted tests-uya tests-emcc tests-portable examples-check microapp-check microapp-hosted-smoke microapp-aarch64-runtime-check microapp-macos-runtime-check microapp-compat-check microapp-recovery-check outlibc c e clean check check-hosted backup backup-seed backup-hosted-seed backup-all-seed back-all-seed backup-hosted-seed-native backup-all restore release release-bootstrap release-flow release-build release-dirty release-preflight release-clean install help cmds cmd-upm upm-check fmt check-fmt

# 共享平台/工具链模型（可通过环境变量覆盖）
HOST_OS ?= $(shell uname -s | tr '[:upper:]' '[:lower:]' | sed -e 's/darwin/macos/' -e 's/msys.*/windows/' -e 's/mingw.*/windows/' -e 's/cygwin.*/windows/')
HOST_ARCH ?= $(shell uname -m | sed -e 's/amd64/x86_64/' -e 's/aarch64/arm64/')
TARGET_OS ?= $(HOST_OS)
TARGET_ARCH ?= $(HOST_ARCH)
TARGET_TRIPLE ?=
RUNTIME_MODE ?= hosted
LINK_MODE ?= default
TOOLCHAIN ?= system
ZIG ?= /home/winger/zig/zig
CC ?= cc
ifeq ($(TOOLCHAIN),zig)
CC_DRIVER ?= $(ZIG) cc
else
CC_DRIVER ?= $(CC)
endif
CC_TARGET_FLAGS ?=

# 编译选项（可通过环境变量覆盖）
# 默认 -O2：加快自举编译器与 codegen 性能；调试可用 CFLAGS='-std=c99 -O0 -g ...' 覆盖
CFLAGS ?= -std=c99 -O2 -fno-builtin -Werror
LDFLAGS ?=

# 并行程序测试 worker 数（默认 CPU 核数；可覆盖：make tests UYA_TEST_JOBS=4）
UYA_TEST_JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 8)
UYA_CMD_NAMES := upm
UYA_CMD_BINS := $(patsubst %,bin/cmd/%,$(UYA_CMD_NAMES))
UYA_CMD_BOOTSTRAP_COMPILER ?= ./bin/uya
UYA_CMD_STATIC_BUILD_FLAGS := --nostdlib --no-split-c --project-root src/

# 安装路径（install 目标）
# 用法: make install
#       make install PREFIX=$$HOME/.local
#       make install BINDIR=/opt/bin
#       make install BINDIR=out            # 前缀布局：out/bin/uya + out/lib/（与 PREFIX 一致）
#       make install DESTDIR=/tmp/stage PREFIX=/usr   # 打包：安装到 /tmp/stage/usr/bin/uya
#       make install TESTSDIR=/path/tests             # 显式测试树目录（默认 前缀/tests）
# BINDIR 语义：
#   - 路径最后一段为 bin：视为「可执行目录」，如 /custom/bin → /custom/bin/uya、/custom/lib/
#   - 否则视为「安装前缀」，如 out、/opt/uya → 前缀/bin/uya、前缀/lib/（与 ~/.local 布局一致）
#       可显式覆盖 LIBDIR、DOCDIR；若与上述布局不一致，请设置环境变量 UYA_ROOT
PREFIX ?= out
BINDIR ?= $(PREFIX)/bin
_BINDIR_NORM := $(patsubst %/,%,$(BINDIR))
ifeq ($(notdir $(_BINDIR_NORM)),bin)
INSTALL_BINDIR := $(_BINDIR_NORM)
LIBDIR ?= $(patsubst %/,%,$(dir $(_BINDIR_NORM)))/lib
INSTALL_PREFIX := $(patsubst %/,%,$(dir $(_BINDIR_NORM)))
else
INSTALL_BINDIR := $(_BINDIR_NORM)/bin
LIBDIR ?= $(_BINDIR_NORM)/lib
INSTALL_PREFIX := $(_BINDIR_NORM)
endif
# 文档：与仓库根目录一致为 前缀/docs/*.md（uya_ai_prompt.md 及文中显式引用的规范文档）
DOCDIR ?= $(INSTALL_PREFIX)/docs
# 测试套件源码树：与仓库 tests/ 一致，安装到 前缀/tests/
TESTSDIR ?= $(INSTALL_PREFIX)/tests
# 打包时 DESTDIR 与相对 BINDIR（如 out）拼接须带 '/'，否则 /tmp/st + out → /tmp/stout
ifneq ($(strip $(DESTDIR)),)
INSTALL_DEST_ROOT := $(patsubst %/,%,$(DESTDIR))/
else
INSTALL_DEST_ROOT :=
endif

# 默认目标
all: help

# 空目标：用于捕获参数（避免 make 报错）
# 注意：uya 是真实目标，不能在这里声明
c e:
	@:

# 从本机 seed 构建（macOS 不回退 Linux seed）
# macOS 主线优先使用 backup/uya-hosted-macos-<arch>.c，本机 arch seed 不存在时才回退
# 到 backup/uya-hosted-macos.c；backup/uya-hosted-macos-arm64.c 与
# backup/uya-hosted-macos-x86_64.c 永久保留作对照。zig 交叉产物仅作辅助参考，
# 不作为 macOS 主线 seed 的可信依据。
from-c-native:
	@echo "=========================================="
	@echo "从本机 C99 seed 构建编译器 (from-c-native)"
	@echo "=========================================="
	@mkdir -p bin
	@bash -c 'set -e; \
		SEED_PATH=""; \
		SEED_DESC=""; \
		if [ "$(HOST_OS)" = "macos" ]; then \
			HOSTED_SEED_UNIFIED="backup/uya-hosted-macos.c"; \
			HOSTED_SEED_ARCH="backup/uya-hosted-macos-$(HOST_ARCH).c"; \
			if [ -f "$$HOSTED_SEED_ARCH" ]; then \
				SEED_PATH="$$HOSTED_SEED_ARCH"; \
				SEED_DESC="macOS hosted 本机备份 $$HOSTED_SEED_ARCH"; \
			elif [ -f "$$HOSTED_SEED_UNIFIED" ]; then \
				SEED_PATH="$$HOSTED_SEED_UNIFIED"; \
				SEED_DESC="macOS hosted 通用备份 $$HOSTED_SEED_UNIFIED"; \
			fi; \
		else \
			HOSTED_SEED="backup/uya-hosted-$(HOST_OS)-$(HOST_ARCH).c"; \
			NOSTDLIB_SEED="backup/uya-$(HOST_OS)-$(HOST_ARCH).c"; \
			if [ -f "$$HOSTED_SEED" ]; then \
				SEED_PATH="$$HOSTED_SEED"; \
				SEED_DESC="host/arch hosted 备份 $$HOSTED_SEED"; \
			elif [ -f "$$NOSTDLIB_SEED" ]; then \
				SEED_PATH="$$NOSTDLIB_SEED"; \
				SEED_DESC="host/arch nostdlib 备份 $$NOSTDLIB_SEED"; \
			fi; \
		fi; \
		if [ ! -f bin/uya.c ]; then \
			if [ -z "$$SEED_PATH" ]; then \
				echo "错误: 当前平台缺少本机 seed。"; \
				if [ "$(HOST_OS)" = "macos" ]; then \
					echo "macOS 仅接受 backup/uya-hosted-macos.c 或 backup/uya-hosted-macos-$(HOST_ARCH).c，不会回退到 Linux seed。"; \
				else \
					echo "请先准备 host/arch seed。"; \
				fi; \
				exit 1; \
			fi; \
			echo "bin/uya.c 不存在，使用 $$SEED_DESC ..."; \
			cp "$$SEED_PATH" bin/uya.c; \
		elif [ -n "$$SEED_PATH" ] && [ "$$SEED_PATH" -nt bin/uya.c ]; then \
			echo "检测到 $$SEED_DESC 更新，刷新过期的 bin/uya.c ..."; \
			cp "$$SEED_PATH" bin/uya.c; \
		fi'
	@echo "编译 bin/uya.c ..."
	@echo "CFLAGS: $(CFLAGS)"
	@echo "HOST_OS=$(HOST_OS) HOST_ARCH=$(HOST_ARCH)"
	@echo "TOOLCHAIN=$(TOOLCHAIN)"
	@echo "CC_DRIVER=$(CC_DRIVER)"
	@HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" \
		CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" \
		bash -c 'set -e; ulimit -s 32768 2>/dev/null || true; \
		EXTRA_HOST_SOURCES=""; \
		if [ "$$HOST_OS" = "macos" ] && [ -f "src/host/macos_stat_shim.c" ]; then EXTRA_HOST_SOURCES="src/host/macos_stat_shim.c"; fi; \
		if grep -qE "^[[:space:]]*__attribute__\\(\\(naked\\)\\)[[:space:]]+void[[:space:]]+_start\\(void\\)" bin/uya.c 2>/dev/null \
			&& [ "$$HOST_OS" = "macos" ]; then \
			echo "错误: 检测到 Linux nostdlib seed，macOS 本机构建拒绝继续。"; \
			echo "请提供 backup/uya-hosted-macos.c 或 backup/uya-hosted-macos-$$HOST_ARCH.c，或先在 macOS 本机生成 hosted seed。"; \
			exit 1; \
		fi; \
		if grep -qE "^[[:space:]]*__attribute__\\(\\(naked\\)\\)[[:space:]]+void[[:space:]]+_start\\(void\\)" bin/uya.c 2>/dev/null \
			&& [ "$$HOST_OS" = "linux" ] && [ "$$HOST_ARCH" = "x86_64" ]; then \
			echo "备份 C 含 nostdlib _start，使用 crti.o + uya.o + crtn.o 链接（避免与 Scrt1 _start 冲突）..."; \
			$$CC_DRIVER $$CC_TARGET_FLAGS $$CFLAGS -fno-stack-protector -c bin/uya.c -o bin/.from_c.o; \
			CRTI=$$($$CC_DRIVER $$CC_TARGET_FLAGS -print-file-name=crti.o); \
			CRTN=$$($$CC_DRIVER $$CC_TARGET_FLAGS -print-file-name=crtn.o); \
			if [ ! -f "$$CRTI" ] || [ "$$CRTI" = "crti.o" ] || [ ! -f "$$CRTN" ] || [ "$$CRTN" = "crtn.o" ]; then \
				echo "错误: 当前工具链无法解析 crti.o/crtn.o，无法用 from-c-native 链接 nostdlib 版 uya.c"; exit 1; \
			fi; \
			$$CC_DRIVER $$CC_TARGET_FLAGS $$CFLAGS -fno-stack-protector -no-pie -nostdlib -static \
				-o bin/uya "$$CRTI" bin/.from_c.o "$$CRTN" $$LDFLAGS; \
			rm -f bin/.from_c.o; \
		else \
			$$CC_DRIVER $$CC_TARGET_FLAGS $$CFLAGS bin/uya.c $$EXTRA_HOST_SOURCES -o bin/uya -lm $$LDFLAGS; \
		fi'
	@echo ""
	@echo "✓ 编译器构建完成: bin/uya"
	@touch bin/.uya_cold_start
	@ls -la bin/uya

# 从 bin/uya.c 构建（零依赖）
from-c:
	@echo "=========================================="
	@echo "从 C99 代码构建编译器 (from-c)"
	@echo "=========================================="
	@mkdir -p bin
	@if [ "$(HOST_OS)" = "macos" ]; then \
		echo "提示: macOS 主线请使用 'make from-c-native'，避免回退到旧的通用 seed 选择逻辑。"; \
		exit 1; \
	fi
	@bash -c 'set -e; \
		HOSTED_SEED="backup/uya-hosted-$(HOST_OS)-$(HOST_ARCH).c"; \
		NOSTDLIB_SEED="backup/uya-$(HOST_OS)-$(HOST_ARCH).c"; \
		SEED_PATH=""; \
		SEED_DESC=""; \
		if [ -f "$$NOSTDLIB_SEED" ]; then \
			SEED_PATH="$$NOSTDLIB_SEED"; \
			SEED_DESC="host/arch nostdlib 备份 $$NOSTDLIB_SEED"; \
		elif [ -f backup/uya.c ]; then \
			SEED_PATH="backup/uya.c"; \
			SEED_DESC="备份 backup/uya.c"; \
		elif [ -f "$$HOSTED_SEED" ]; then \
			SEED_PATH="$$HOSTED_SEED"; \
			SEED_DESC="host/arch hosted 备份 $$HOSTED_SEED"; \
		elif [ -f backup/uya-hosted.c ]; then \
			SEED_PATH="backup/uya-hosted.c"; \
			SEED_DESC="hosted 备份 backup/uya-hosted.c"; \
		fi; \
		if [ ! -f bin/uya.c ]; then \
			if [ -z "$$SEED_PATH" ]; then \
				echo "错误: bin/uya.c、host/arch 备份、backup/uya-hosted.c 和 backup/uya.c 都不存在"; \
				exit 1; \
			fi; \
			echo "bin/uya.c 不存在，使用 $$SEED_DESC ..."; \
			cp "$$SEED_PATH" bin/uya.c; \
		elif [ -n "$$SEED_PATH" ] && [ "$$SEED_PATH" -nt bin/uya.c ]; then \
			echo "检测到 $$SEED_DESC 更新，刷新过期的 bin/uya.c ..."; \
			cp "$$SEED_PATH" bin/uya.c; \
		fi'
	@echo "编译 bin/uya.c ..."
	@echo "CFLAGS: $(CFLAGS)"
	@echo "HOST_OS=$(HOST_OS) HOST_ARCH=$(HOST_ARCH)"
	@echo "TOOLCHAIN=$(TOOLCHAIN)"
	@echo "CC_DRIVER=$(CC_DRIVER)"
	@HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" \
		CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" \
		bash -c 'set -e; ulimit -s 32768 2>/dev/null || true; \
		if grep -qE "^[[:space:]]*__attribute__\\(\\(naked\\)\\)[[:space:]]+void[[:space:]]+_start\\(void\\)" bin/uya.c 2>/dev/null \
			&& [ "$$HOST_OS" = "macos" ]; then \
			echo "错误: backup/uya.c 为 Linux nostdlib（含 x86_64 Linux _start），无法在 macOS 上 make from-c。"; \
			echo "请使用 '\''make from-c-native'\'' 或准备本机 macOS hosted seed。"; \
			exit 1; \
		fi; \
		if grep -qE "^[[:space:]]*__attribute__\\(\\(naked\\)\\)[[:space:]]+void[[:space:]]+_start\\(void\\)" bin/uya.c 2>/dev/null \
			&& [ "$$HOST_OS" = "linux" ] && [ "$$HOST_ARCH" = "x86_64" ]; then \
			echo "备份 C 含 nostdlib _start，使用 crti.o + uya.o + crtn.o 链接（避免与 Scrt1 _start 冲突）..."; \
			$$CC_DRIVER $$CC_TARGET_FLAGS $$CFLAGS -fno-stack-protector -c bin/uya.c -o bin/.from_c.o; \
			CRTI=$$($$CC_DRIVER $$CC_TARGET_FLAGS -print-file-name=crti.o); \
			CRTN=$$($$CC_DRIVER $$CC_TARGET_FLAGS -print-file-name=crtn.o); \
			if [ ! -f "$$CRTI" ] || [ "$$CRTI" = "crti.o" ] || [ ! -f "$$CRTN" ] || [ "$$CRTN" = "crtn.o" ]; then \
				echo "错误: 当前工具链无法解析 crti.o/crtn.o，无法用 from-c 链接 nostdlib 版 uya.c"; exit 1; \
			fi; \
			$$CC_DRIVER $$CC_TARGET_FLAGS $$CFLAGS -fno-stack-protector -no-pie -nostdlib -static \
				-o bin/uya "$$CRTI" bin/.from_c.o "$$CRTN" $$LDFLAGS; \
			rm -f bin/.from_c.o; \
		else \
			$$CC_DRIVER $$CC_TARGET_FLAGS $$CFLAGS bin/uya.c -o bin/uya -lm $$LDFLAGS; \
		fi'
	@echo ""
	@echo "✓ 编译器构建完成: bin/uya"
	@touch bin/.uya_cold_start
	@ls -la bin/uya

# 构建自举编译器（src），默认使用 --nostdlib（静态链接，零依赖）
uya:
	@echo "=========================================="
	@echo "构建自举编译器 (uya) --nostdlib"
	@echo "=========================================="
	@bash -c 'set -e; \
		if [ "$${UYA_SKIP_UYA:-0}" = "1" ]; then \
			if [ ! -x bin/uya ]; then \
				echo "错误: UYA_SKIP_UYA=1 但 bin/uya 不存在，无法复用现有编译器"; \
				exit 1; \
			fi; \
			echo "提示: UYA_SKIP_UYA=1，复用现有 bin/uya，跳过重复自举"; \
			exit 0; \
		fi; \
		COLD_START=0; \
		EXTRA_FLAGS=""; \
		if [ -n "$$CI" ] || [ -n "$$GITHUB_ACTIONS" ]; then EXTRA_FLAGS="--verbose"; fi; \
		if [ -f bin/.uya_cold_start ]; then COLD_START=1; fi; \
		if [ ! -f bin/uya ]; then \
			COLD_START=1; \
			echo "bin/uya 不存在，从备份构建..."; \
			if [ "$(HOST_OS)" = "macos" ]; then \
				$(MAKE) from-c-native; \
			else \
				$(MAKE) from-c; \
			fi; \
		fi; \
		echo "使用 bin/uya 编译 src/ ..."; \
		echo "TARGET_OS=$(TARGET_OS) TARGET_ARCH=$(TARGET_ARCH) TARGET_TRIPLE=$(TARGET_TRIPLE)"; \
		( ulimit -s 32768 && cd src && UYA_MULTI_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static CFLAGS="$(CFLAGS) -fno-stack-protector" LDFLAGS="$(LDFLAGS)" ./compile.sh --c99 -e --nostdlib --safety-proof $$EXTRA_FLAGS ); \
		if [ "$$COLD_START" = "1" ]; then \
			echo ""; \
			echo "检测到冷启动 seed，自举后再收敛复编译一轮..."; \
			( ulimit -s 32768 && cd src && UYA_MULTI_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static CFLAGS="$(CFLAGS) -fno-stack-protector" LDFLAGS="$(LDFLAGS)" ./compile.sh --c99 -e --nostdlib --safety-proof $$EXTRA_FLAGS ); \
			rm -f bin/.uya_cold_start; \
		fi'
	@echo ""
	@echo "更新 bin/uya.c（若存在单文件 src/build/uya.c）…"
	@if [ -f src/build/uya.c ]; then cp src/build/uya.c bin/uya.c && echo "✓ bin/uya.c 已更新"; else echo "（多文件 C：未生成 src/build/uya.c；单文件见 make backup-seed）"; fi
	@echo ""
	@echo "✓ 自举编译器构建完成: bin/uya（静态链接，零依赖）"
	@echo ""
	@echo "提示: 运行 'make b' 验证自举，通过后会自动备份"

# 构建自举编译器（hosted 版本）
uya-hosted:
	@echo "=========================================="
	@echo "构建自举编译器 (uya-hosted)"
	@echo "使用 hosted 链接路径"
	@echo "=========================================="
	@if [ ! -f bin/uya ] && [ ! -f bin/uya-hosted ]; then \
		echo "错误: bin/uya 与 bin/uya-hosted 均不存在。"; \
		if [ "$(HOST_OS)" = "macos" ]; then \
			echo "提示: 当前 hosted 主线默认依赖已有可运行编译器；macOS 先尝试 from-c-native 冷启动。"; \
			$(MAKE) from-c-native; \
		else \
			echo "提示: 当前 hosted 主线默认依赖已有可运行编译器，请先准备 bin/uya 或 bin/uya-hosted。"; \
			exit 1; \
		fi; \
	fi
	@echo "使用 hosted 编译器编译 src/ ..."
	@echo "TARGET_OS=$(TARGET_OS) TARGET_ARCH=$(TARGET_ARCH) TARGET_TRIPLE=$(TARGET_TRIPLE)"
	@bash -c 'set -e; REPO_ROOT="$$(pwd)"; UYA_COMPILER_PATH=""; if [ -f "$$REPO_ROOT/bin/uya" ]; then UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya"; else UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya-hosted"; fi; BUILD_MODE_ENV="UYA_MULTI_FILE_C=1 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR="; if [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ]; then BUILD_MODE_ENV="UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR="; fi; ulimit -s 32768 && cd src && eval "$$BUILD_MODE_ENV UYA_COMPILER=\"$$UYA_COMPILER_PATH\" CC=\"$(CC)\" CC_DRIVER=\"$(CC_DRIVER)\" CC_TARGET_FLAGS=\"$(CC_TARGET_FLAGS)\" HOST_OS=\"$(HOST_OS)\" HOST_ARCH=\"$(HOST_ARCH)\" TARGET_OS=\"$(TARGET_OS)\" TARGET_ARCH=\"$(TARGET_ARCH)\" TARGET_TRIPLE=\"$(TARGET_TRIPLE)\" TOOLCHAIN=\"$(TOOLCHAIN)\" ZIG=\"$(ZIG)\" RUNTIME_MODE=hosted LINK_MODE=\"$(LINK_MODE)\" UYA_BOOTSTRAP_PROFILE=\"$$( [ \"$(HOST_OS)\" = \"macos\" ] && [ \"$(TARGET_OS)\" = \"macos\" ] && echo darwin-hosted || echo hosted )\" UYA_NATIVE_BOOTSTRAP=\"$$( [ \"$(HOST_OS)\" = \"macos\" ] && [ \"$(TARGET_OS)\" = \"macos\" ] && [ \"$(HOST_ARCH)\" = \"$(TARGET_ARCH)\" ] && echo 1 || echo 0 )\" CFLAGS=\"$(CFLAGS)\" LDFLAGS=\"$(LDFLAGS)\" ./compile.sh --c99 -e --name uya-hosted --safety-proof"'
	@echo ""
	@echo "更新 bin/uya.c（若存在单文件 src/build/uya.c）…"
	@if [ -f src/build/uya.c ]; then cp src/build/uya.c bin/uya.c && echo "✓ bin/uya.c 已更新"; else echo "（多文件 C：未生成 src/build/uya.c；单文件见 make backup-seed）"; fi
	@echo ""
	@echo "✓ 自举编译器构建完成: bin/uya-hosted（hosted）"
	@echo ""
	@echo "提示: 运行 'make b-hosted' 验证 hosted 自举"

# 跨平台入口：Linux 走已验证的 nostdlib 主线，其它平台走 hosted 主线
uya-portable:
ifeq ($(HOST_OS),linux)
	@$(MAKE) uya
else
	@$(MAKE) uya-hosted
endif

# 构建自举编译器（标准库版本，用于调试）
uya-std: uya-hosted

# 构建自举编译器（--nostdlib 版本）- 别名
uya-nostdlib:

# 构建自举编译器（启用内存安全检查）
uya-safety:
	@echo "=========================================="
	@echo "构建自举编译器 (uya-safety)"
	@echo "启用内存安全检查 (--safety-proof)"
	@echo "=========================================="
	@if [ ! -f bin/uya ]; then \
		echo "bin/uya 不存在，从备份构建..."; \
		if [ "$(HOST_OS)" = "macos" ]; then \
			$(MAKE) from-c-native; \
		else \
			$(MAKE) from-c; \
		fi; \
	fi
	@bash -c 'ulimit -s 32768 && cd src && UYA_MULTI_FILE_C=1 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=hosted LINK_MODE="$(LINK_MODE)" UYA_BOOTSTRAP_PROFILE="$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && echo darwin-hosted || echo hosted )" UYA_NATIVE_BOOTSTRAP="$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && [ "$(HOST_ARCH)" = "$(TARGET_ARCH)" ] && echo 1 || echo 0 )" CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" ./compile.sh --c99 -e --safety-proof'
	@echo ""
	@echo "✓ 自举编译器（内存安全版）构建完成: bin/uya"

# 自举验证：用自举编译器编译自身，验证输出一致性
b:
	@echo "=========================================="
	@echo "自举验证：编译器编译自身，验证输出一致性"
	@echo "=========================================="
	@bash -c 'ulimit -s 32768 && cd src && UYA_MULTI_FILE_C=1 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static CFLAGS="$(CFLAGS) -fno-stack-protector" LDFLAGS="$(LDFLAGS)" ./compile.sh --c99 -e -b --nostdlib --safety-proof'
	@echo ""
	@echo "✓ 自举验证完成"

# hosted 自举验证：用 hosted 编译器编译自身，验证输出一致性
b-hosted: uya-hosted
	@echo "=========================================="
	@echo "hosted 自举验证：编译器编译自身，验证输出一致性"
	@echo "=========================================="
	@bash -c 'REPO_ROOT="$$(pwd)"; BUILD_MODE_ENV="UYA_MULTI_FILE_C=1 UYA_SPLIT_C_DIR= UYA_SPLIT_C_MIRROR="; if [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ]; then BUILD_MODE_ENV="UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR="; fi; ulimit -s 32768 && cd src && eval "$$BUILD_MODE_ENV UYA_COMPILER=\"$$REPO_ROOT/bin/uya-hosted\" CC=\"$(CC)\" CC_DRIVER=\"$(CC_DRIVER)\" CC_TARGET_FLAGS=\"$(CC_TARGET_FLAGS)\" HOST_OS=\"$(HOST_OS)\" HOST_ARCH=\"$(HOST_ARCH)\" TARGET_OS=\"$(TARGET_OS)\" TARGET_ARCH=\"$(TARGET_ARCH)\" TARGET_TRIPLE=\"$(TARGET_TRIPLE)\" TOOLCHAIN=\"$(TOOLCHAIN)\" ZIG=\"$(ZIG)\" RUNTIME_MODE=hosted LINK_MODE=\"$(LINK_MODE)\" UYA_BOOTSTRAP_PROFILE=\"$$( [ \"$(HOST_OS)\" = \"macos\" ] && [ \"$(TARGET_OS)\" = \"macos\" ] && echo darwin-hosted || echo hosted )\" UYA_NATIVE_BOOTSTRAP=\"$$( [ \"$(HOST_OS)\" = \"macos\" ] && [ \"$(TARGET_OS)\" = \"macos\" ] && [ \"$(HOST_ARCH)\" = \"$(TARGET_ARCH)\" ] && echo 1 || echo 0 )\" CFLAGS=\"$(CFLAGS)\" LDFLAGS=\"$(LDFLAGS)\" ./compile.sh --c99 -e -b --name uya-hosted --safety-proof"'
	@echo ""
	@echo "✓ hosted 自举验证完成"

# 跨平台入口：Linux 走已验证的 nostdlib 自举，其它平台走 hosted 自举
b-portable:
ifeq ($(HOST_OS),linux)
	@$(MAKE) b
else
	@$(MAKE) b-hosted
endif

# 抓取编译器 CompileStats，便于对比 parse/check/codegen/total 耗时
bench-compile-stats:
	@bash scripts/bench_compile_stats.sh $(ARGS)

# 运行测试：默认使用 tests/run_programs_parallel.sh 并行测试（默认同 CPU 核数；可 UYA_TEST_JOBS= 或脚本 -j N）
# 默认 --hide-pass：不打印每条通过的 ✓，其余输出与直接跑脚本相同
# 用法: make tests [e] [其他参数]
# 示例: make tests e          # 最小输出（原 -e）
#       make tests test_file.uya
tests:
	@HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	OTHER_ARGS=$$(echo "$(MAKECMDGOALS)" | sed 's/tests//g' | sed 's/\be\b//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
	echo "=========================================="; \
	echo "测试自举编译器 (uya)"; \
	echo "=========================================="; \
	$(MAKE) uya >/dev/null 2>&1; \
	if [ "$$HAS_E" = "yes" ]; then \
		PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static ./tests/run_programs_parallel.sh --uya --c99 -e $$OTHER_ARGS; \
	else \
		PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static ./tests/run_programs_parallel.sh --uya --c99 $$OTHER_ARGS; \
		fi; \
		TS=$$?; \
		echo ""; \
		if [ $$TS -ne 0 ]; then echo "✗ 测试失败（退出码 $$TS）"; exit $$TS; fi; \
		if [ -z "$$OTHER_ARGS" ]; then \
			$(MAKE) upm-check; \
		else \
			echo "跳过 UPM 验证套件（定向 tests 参数）"; \
		fi; \
		echo "✓ 测试完成"

# hosted 主测试集：为 Darwin/Windows 预留的普通链接测试主线
tests-hosted:
	@HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	OTHER_ARGS=$$(echo "$(MAKECMDGOALS)" | sed 's/tests-hosted//g' | sed 's/\be\b//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
	echo "=========================================="; \
	echo "测试 hosted 编译器 (uya-hosted)"; \
	echo "=========================================="; \
	$(MAKE) uya-hosted >/dev/null 2>&1; \
	BOOTSTRAP_PROFILE=$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && echo darwin-hosted || echo hosted ); \
	NATIVE_BOOTSTRAP=$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && [ "$(HOST_ARCH)" = "$(TARGET_ARCH)" ] && echo 1 || echo 0 ); \
	if [ "$$HAS_E" = "yes" ]; then \
		PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_COMPILER="$(PWD)/bin/uya-hosted" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" UYA_BOOTSTRAP_PROFILE="$$BOOTSTRAP_PROFILE" UYA_NATIVE_BOOTSTRAP="$$NATIVE_BOOTSTRAP" RUNTIME_MODE=hosted LINK_MODE="$(LINK_MODE)" TEST_PROFILE=hosted ./tests/run_programs_parallel.sh --uya --c99 -e $$OTHER_ARGS; \
	else \
		PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_COMPILER="$(PWD)/bin/uya-hosted" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" UYA_BOOTSTRAP_PROFILE="$$BOOTSTRAP_PROFILE" UYA_NATIVE_BOOTSTRAP="$$NATIVE_BOOTSTRAP" RUNTIME_MODE=hosted LINK_MODE="$(LINK_MODE)" TEST_PROFILE=hosted ./tests/run_programs_parallel.sh --uya --c99 $$OTHER_ARGS; \
	fi; \
	TS=$$?; \
	echo ""; \
	if [ $$TS -ne 0 ]; then echo "✗ hosted 测试失败（退出码 $$TS）"; exit $$TS; fi; \
	echo "✓ hosted 测试完成"

# 快捷目标：测试自举编译器（默认 tests/run_programs_parallel.sh 并行）
tests-uya:
	@HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	$(MAKE) uya >/dev/null 2>&1; \
	echo "=========================================="; \
	echo "测试自举编译器 (uya)"; \
	echo "=========================================="; \
	if [ "$$HAS_E" = "yes" ]; then \
		PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static ./tests/run_programs_parallel.sh --uya --c99 -e; \
	else \
		PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static ./tests/run_programs_parallel.sh --uya --c99; \
		fi; \
		TS=$$?; \
		if [ $$TS -ne 0 ]; then echo "✗ 测试失败（退出码 $$TS）"; exit $$TS; fi; \
		echo ""; \
		$(MAKE) upm-check

tests-emcc:
	@echo "=========================================="
	@echo "运行独立 emcc smoke"
	@echo "=========================================="
	@$(MAKE) uya >/dev/null 2>&1
	@./tests/verify_emcc_unknown_runtime.sh
	@echo ""
	@echo "✓ emcc smoke 通过"

fmt:
	@echo "=========================================="
	@echo "运行 uya fmt（当前最小集成）"
	@echo "=========================================="
	@bash ./tests/verify_fmt_cli.sh
	@echo ""
	@echo "✓ uya fmt CLI 验证通过"

check-fmt:
	@echo "=========================================="
	@echo "检查 uya fmt 状态（仓库检查）"
	@echo "=========================================="
	@mkdir -p ./tests/build/fmt_cli ./bin
	@./bin/uya --c99 ./tools/fmt.uya -o ./tests/build/fmt_cli/uyafmt.c >/tmp/check_fmt_build.out 2>/tmp/check_fmt_build.err
	@cc -O0 -g ./tests/build/fmt_cli/uyafmt.c -o ./bin/uyafmt
	@OUT="$$(./bin/uyafmt -l ./src ./lib ./tests ./tools 2>/dev/null || true)"; \
	if [ -n "$$OUT" ]; then \
		echo "以下文件未格式化:"; \
		printf '%s\n' "$$OUT"; \
		exit 1; \
	fi
	@echo ""
	@echo "✓ uya fmt 检查通过"

microapp-check:
	@echo "=========================================="
	@echo "运行 microapp 验证套件"
	@echo "=========================================="
	@./tests/verify_microapp_suite.sh
	@echo ""
	@echo "✓ microapp 验证套件通过"

examples-check:
	@echo "=========================================="
	@echo "运行 examples 验证套件"
	@echo "=========================================="
	@./tests/verify_examples_suite.sh
	@echo ""
	@echo "✓ examples 验证套件通过"

microapp-hosted-smoke:
	@echo "=========================================="
	@echo "运行 microapp hosted smoke 套件"
	@echo "=========================================="
	@./tests/verify_microapp_hosted_smoke.sh
	@echo ""
	@echo "✓ microapp hosted smoke 套件通过"

microapp-aarch64-runtime-check:
	@echo "=========================================="
	@echo "运行 microapp aarch64 hosted runtime 回归"
	@echo "=========================================="
	@./tests/verify_microapp_aarch64_hosted_runtime.sh
	@echo ""
	@echo "✓ microapp aarch64 hosted runtime 回归通过"

microapp-macos-runtime-check:
	@echo "=========================================="
	@echo "运行 microapp macOS arm64 hosted runtime 回归"
	@echo "=========================================="
	@./tests/verify_microapp_macos_arm64_hosted_runtime.sh
	@echo ""
	@echo "✓ microapp macOS arm64 hosted runtime 回归通过"

microapp-compat-check:
	@echo "=========================================="
	@echo "运行 microapp .uapp 兼容回归"
	@echo "=========================================="
	@./tests/verify_microapp_uapp_compat.sh
	@echo ""
	@echo "✓ microapp .uapp 兼容回归通过"

microapp-recovery-check:
	@echo "=========================================="
	@echo "运行 microapp crash/recovery/update 回归"
	@echo "=========================================="
	@./tests/verify_microapp_recovery_update.sh
	@echo ""
	@echo "✓ microapp crash/recovery/update 回归通过"
# 跨平台入口：Linux 走已验证的 nostdlib 测试，其它平台走 hosted 测试
tests-portable:
ifeq ($(HOST_OS),linux)
	@$(MAKE) tests
else
	@$(MAKE) tests-hosted
endif

# 输出标准库为 C 代码（使用自举编译器）
outlibc: uya
	@echo "=========================================="
	@echo "输出标准库为 C 代码 (outlibc)"
	@echo "使用自举编译器 (uya)"
	@echo "=========================================="
	@mkdir -p lib/build
	@echo "编译标准库文件..."
	@if [ -f bin/uya ]; then \
		COMPILER=bin/uya; \
	else \
		echo "错误: 找不到自举编译器，请先运行 'make uya'"; \
		exit 1; \
	fi; \
	echo "使用编译器: $$COMPILER"; \
	echo ""; \
	LIB_FILES=$$(find lib/libc/ -name "*.uya" -type f | sort); \
	if [ -z "$$LIB_FILES" ]; then \
		echo "错误: 未找到标准库文件 (lib/libc/*.uya)"; \
		exit 1; \
	fi; \
	echo "找到的标准库文件:"; \
	echo "$$LIB_FILES" | sed 's/^/  /'; \
	echo ""; \
	echo "生成 C 代码到 lib/build/libuya.c..."; \
	$$COMPILER --c99 $$LIB_FILES -o lib/build/libuya.c; \
	if [ $$? -eq 0 ]; then \
		echo ""; \
		echo "✓ 标准库 C 代码已生成: lib/build/libuya.c"; \
		FILE_SIZE=$$(du -h lib/build/libuya.c 2>/dev/null | cut -f1 || echo "未知"); \
		echo "  文件大小: $$FILE_SIZE"; \
		echo "  使用编译器: 自举编译器 (uya)"; \
	else \
		echo ""; \
		echo "✗ 生成失败"; \
		exit 1; \
	fi

# 清理构建产物
clean:
	@echo "清理构建产物..."
	@rm -rf bin
	@rm -rf src/build
	@rm -rf src/build/cmd
	@rm -rf tests/programs/build
	@rm -rf lib/build
	@echo "✓ 清理完成"

cmds: $(UYA_CMD_BINS)
	@if [ -d bin/cmd ]; then \
		for cmd_bin in bin/cmd/*; do \
			if [ ! -e "$$cmd_bin" ]; then continue; fi; \
			base=$$(basename "$$cmd_bin"); \
			keep=0; \
			for name in $(UYA_CMD_NAMES); do \
				if [ "$$base" = "$$name" ]; then keep=1; fi; \
			done; \
			if [ "$$keep" = "0" ]; then \
				echo "移除过期 cmd 产物: $$cmd_bin"; \
				rm -f "$$cmd_bin"; \
			fi; \
		done; \
	fi

cmd-upm: bin/cmd/upm

bin/cmd/upm: src/cmd/upm/main.uya Makefile
	@mkdir -p bin/cmd
	@echo "构建 cmd/upm ..."
	@if [ ! -x "$(UYA_CMD_BOOTSTRAP_COMPILER)" ]; then \
		echo "缺少 $(UYA_CMD_BOOTSTRAP_COMPILER)，先构建 bin/uya ..."; \
		$(MAKE) uya; \
	fi
	@$(UYA_CMD_BOOTSTRAP_COMPILER) build $(UYA_CMD_STATIC_BUILD_FLAGS) $< -o $@

bin/cmd/%: src/cmd/%/main.uya Makefile
	@mkdir -p bin/cmd
	@echo "构建 cmd/$* ..."
	@if [ ! -x "$(UYA_CMD_BOOTSTRAP_COMPILER)" ]; then \
		echo "缺少 $(UYA_CMD_BOOTSTRAP_COMPILER)，先构建 bin/uya ..."; \
		$(MAKE) uya; \
	fi
	@$(UYA_CMD_BOOTSTRAP_COMPILER) build $(UYA_CMD_STATIC_BUILD_FLAGS) $< -o $@

upm-check: uya cmd-upm
	@echo "=========================================="
	@echo "运行 UPM 验证套件"
	@echo "=========================================="
	@bash ./tests/verify_cmd_bins_nostdlib_static.sh
	@bash ./tests/verify_upm_suite.sh
	@echo ""
	@echo "✓ UPM 验证套件通过"

# 备份 bin/uya.c（依赖自举验证和测试通过）
check: uya
	@echo "=========================================="
	@echo "运行测试验证..."
	@echo "=========================================="
	@PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" \
		HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" \
		TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" \
		TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" \
		RUNTIME_MODE=nostdlib LINK_MODE=static \
		./tests/run_programs_parallel.sh --uya --c99 --hide-pass > /tmp/make_check_output.txt 2>&1; \
	TEST_EXIT=$$?; \
	if [ -f /tmp/uya_test_summary.txt ]; then cp /tmp/uya_test_summary.txt /tmp/uya_main_test_summary.txt; fi; \
	rm -f /tmp/uya_test_summary.txt; \
	echo ""; \
	echo "验证证明优化..."; \
	if ./tests/verify_proof_optimization.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "✓|✗|证明优化" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ 证明优化验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证默认顶层函数发射..."; \
	if ./tests/verify_function_reachability_codegen.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ 默认顶层函数发射验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证模块别名 import table codegen..."; \
	if bash ./tests/verify_module_alias_import_table_codegen.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "ok$$|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ 模块别名 import table codegen 验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 nested async split-C codegen..."; \
	if bash ./tests/verify_async_nested_split_codegen.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "ok$$|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ nested async split-C codegen 验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 async frame descriptor C99 发射..."; \
	VERIFY_EXIT=0; \
	for script in \
		./tests/verify_c99_async_frame_descriptors.sh \
		./tests/verify_c99_async_frame_empty_descriptors.sh; do \
		if bash "$$script" > /tmp/verify_out.txt 2>&1; then \
			grep -E "ok$$|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		else \
			cat /tmp/verify_out.txt; \
			VERIFY_EXIT=1; \
			break; \
		fi; \
	done; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ async frame descriptor C99 发射验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 split-C 共享 cache 并发锁..."; \
	if bash ./tests/verify_split_c_cache_lock.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "ok$$|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ split-C 共享 cache 并发锁验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 split-C stale lock 自动回收..."; \
	if bash ./tests/verify_split_c_cache_stale_lock.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "ok$$|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ split-C stale lock 自动回收验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 check 子命令..."; \
	if bash ./tests/verify_check_cli.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "ok$$|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
		if [ $$VERIFY_EXIT -ne 0 ]; then \
			echo "✗ check 子命令验证失败"; \
			exit 1; \
		fi; \
		echo ""; \
		echo "验证 UPM 套件..."; \
		if $(MAKE) upm-check > /tmp/verify_out.txt 2>&1; then \
			grep -E "verify_upm_.*: ok$$|test_cmd_upm_direct: ok$$|verify_upm_suite: ok$$|✓" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
			VERIFY_EXIT=0; \
		else \
			cat /tmp/verify_out.txt; \
			VERIFY_EXIT=1; \
		fi; \
		if [ $$VERIFY_EXIT -ne 0 ]; then \
			echo "✗ UPM 套件验证失败"; \
			exit 1; \
		fi; \
		echo ""; \
		echo "验证 exec vm 专项回归..."; \
		VERIFY_EXIT=0; \
	for script in \
		./tests/verify_exec_vm_smoke.sh \
		./tests/verify_exec_vm_globals.sh \
		./tests/verify_exec_vm_error_builtin.sh \
		./tests/verify_exec_vm_builtin_bridge.sh \
		./tests/verify_exec_vm_extern_bridge.sh \
		./tests/verify_exec_vm_defer.sh \
		./tests/verify_exec_vm_aggregates.sh \
		./tests/verify_exec_vm_compiler_regressions.sh; do \
		if bash "$$script" > /tmp/verify_out.txt 2>&1; then \
			grep -E "passed$$|checks passed$$|ok$$|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		else \
			cat /tmp/verify_out.txt; \
			VERIFY_EXIT=1; \
			break; \
		fi; \
	done; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ exec vm 专项回归验证失败"; \
		exit 1; \
	fi; \
		echo ""; \
		echo "验证 microapp 聚合套件..."; \
		if $(MAKE) microapp-check > /tmp/verify_out.txt 2>&1; then \
			grep -E "✓|==>|ok$$|通过" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
			VERIFY_EXIT=0; \
		else \
			cat /tmp/verify_out.txt; \
			VERIFY_EXIT=1; \
		fi; \
		if [ $$VERIFY_EXIT -ne 0 ]; then \
			echo "✗ microapp 聚合套件验证失败"; \
			exit 1; \
		fi; \
		echo ""; \
		echo "验证 SIMD @vector.select C 按需生成..."; \
		if ./tests/verify_simd_select_c_emit.sh > /tmp/verify_out.txt 2>&1; then \
			grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
			VERIFY_EXIT=0; \
		else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ SIMD select C 按需生成验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证切片形参 C99 按值与调用约定..."; \
	if ./tests/verify_slice_param_c99_emit.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ 切片形参 C99 验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证结构体数组字段复制与 typed route 泛型回归..."; \
	if ./tests/verify_c99_struct_array_and_typed_route_regressions.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "ok$$|probe|✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ 结构体数组字段 / typed route C99 回归验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 macOS hosted 单文件 seed extern 声明..."; \
	if ./tests/verify_macos_hosted_seed_decls.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ macOS hosted 单文件 seed extern 声明验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 @syscall C99（Linux AArch64 / ARM32 交叉）..."; \
	if ZIG="$(ZIG)" ./tests/verify_syscall_c99_cross.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ @syscall C99 交叉目标验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 SIMD C99（ARM NEON 片段交叉编译）..."; \
	if ZIG="$(ZIG)" ./tests/verify_simd_c99_neon.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ SIMD C99 NEON 验证失败"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "验证 benchmarks/http_bench.uya C99..."; \
	if ./tests/verify_http_bench_compile.sh > /tmp/verify_out.txt 2>&1; then \
		grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
		VERIFY_EXIT=0; \
	else \
		cat /tmp/verify_out.txt; \
		VERIFY_EXIT=1; \
	fi; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ http_bench C99 验证失败"; \
		exit 1; \
		fi; \
		echo ""; \
		if [ "$${UYA_ENABLE_HTTP_BENCH_ASYNC_EPOLL_CHECK:-0}" = "1" ]; then \
			echo "验证 benchmarks/http_bench_async_epoll.uya C99..."; \
			if ./tests/verify_http_bench_async_epoll_compile.sh > /tmp/verify_out.txt 2>&1; then \
				grep -E "✓|✗" /tmp/verify_out.txt || cat /tmp/verify_out.txt; \
				VERIFY_EXIT=0; \
			else \
				cat /tmp/verify_out.txt; \
				VERIFY_EXIT=1; \
			fi; \
			if [ $$VERIFY_EXIT -ne 0 ]; then \
				echo "✗ http_bench_async_epoll C99 验证失败"; \
				exit 1; \
			fi; \
		else \
			echo "跳过 benchmarks/http_bench_async_epoll.uya C99（设 UYA_ENABLE_HTTP_BENCH_ASYNC_EPOLL_CHECK=1 启用）"; \
		fi; \
		echo ""; \
		echo "=========================================="; \
	echo "测试结果："; \
	echo "=========================================="; \
	if [ $$TEST_EXIT -ne 0 ]; then \
		echo "测试执行失败（退出码: $$TEST_EXIT）"; \
		grep -E "FAIL:|❌|失败:|编译失败|链接失败|未计入" /tmp/make_check_output.txt | tail -40 || true; \
		echo "--- 日志尾部（便于定位）---"; \
		tail -60 /tmp/make_check_output.txt; \
		rm -f /tmp/make_check_output.txt /tmp/verify_out.txt; \
		exit 1; \
	fi; \
	if [ -f /tmp/uya_main_test_summary.txt ]; then \
		cat /tmp/uya_main_test_summary.txt; \
		rm -f /tmp/uya_main_test_summary.txt; \
	else \
		grep -E "总计|通过|失败" /tmp/make_check_output.txt | tail -5; \
	fi; \
	rm -f /tmp/make_check_output.txt /tmp/verify_out.txt; \
	echo ""; \
		echo "✓ 验证通过（自举 + 测试 + 证明优化 + 默认顶层函数发射 + SIMD select C + 切片形参 C99 + @syscall C99 + SIMD NEON + http_bench C99）"

# hosted 验证：普通链接自举 + 主测试 + 证明优化
check-hosted: b-hosted
	@echo "=========================================="
	@echo "运行 hosted 测试验证..."
	@echo "=========================================="
	@BOOTSTRAP_PROFILE=$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && echo darwin-hosted || echo hosted ); \
	NATIVE_BOOTSTRAP=$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && [ "$(HOST_ARCH)" = "$(TARGET_ARCH)" ] && echo 1 || echo 0 ); \
	PARALLEL_JOBS="$(UYA_TEST_JOBS)" UYA_COMPILER="$(PWD)/bin/uya-hosted" UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" UYA_BOOTSTRAP_PROFILE="$$BOOTSTRAP_PROFILE" UYA_NATIVE_BOOTSTRAP="$$NATIVE_BOOTSTRAP" RUNTIME_MODE=hosted LINK_MODE="$(LINK_MODE)" TEST_PROFILE=hosted ./tests/run_programs_parallel.sh --uya --c99; \
	TEST_EXIT=$$?; \
	if [ $$TEST_EXIT -ne 0 ]; then \
		echo ""; \
		echo "✗ hosted 测试失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证证明优化..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" ./tests/verify_proof_optimization.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ 证明优化验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证默认顶层函数发射..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" ./tests/verify_function_reachability_codegen.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ 默认顶层函数发射验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 nested async split-C codegen..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" bash ./tests/verify_async_nested_split_codegen.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ nested async split-C codegen 验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 split-C 共享 cache 并发锁..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" bash ./tests/verify_split_c_cache_lock.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ split-C 共享 cache 并发锁验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 split-C stale lock 自动回收..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" bash ./tests/verify_split_c_cache_stale_lock.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ split-C stale lock 自动回收验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 microapp 聚合套件..."
	@if [ "$(HOST_OS)" = "macos" ]; then \
		bash ./tests/verify_microapp_macos_profile_guard.sh; \
		bash ./tests/verify_microapp_macos_object_extract.sh; \
		$(MAKE) microapp-macos-runtime-check; \
	else \
		$(MAKE) microapp-check; \
	fi; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ microapp 聚合套件验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 SIMD @vector.select C 按需生成..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" ./tests/verify_simd_select_c_emit.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ SIMD select C 按需生成验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 macOS hosted 单文件 seed extern 声明..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" ./tests/verify_macos_hosted_seed_decls.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ macOS hosted 单文件 seed extern 声明验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 hosted libc 使用系统符号..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" bash ./tests/verify_c99_hosted_libc_uses_system_symbols.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ hosted libc 系统符号验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 @syscall C99（Linux AArch64 / ARM32 交叉）..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" ZIG="$(ZIG)" ./tests/verify_syscall_c99_cross.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ @syscall C99 交叉目标验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "验证 SIMD C99（ARM NEON 片段交叉编译）..."
	@UYA_COMPILER="$(PWD)/bin/uya-hosted" ZIG="$(ZIG)" ./tests/verify_simd_c99_neon.sh; \
	VERIFY_EXIT=$$?; \
	if [ $$VERIFY_EXIT -ne 0 ]; then \
		echo "✗ SIMD C99 NEON 验证失败"; \
		exit 1; \
	fi
	@echo ""
	@echo "✓ hosted 验证通过（自举 + 测试 + 证明优化 + 默认顶层函数发射 + SIMD select C + hosted libc 系统符号 + @syscall C99 + SIMD NEON）"

# 备份（依赖 check 通过）：多文件 C 产物目录 -> backup/uyacache（与 make uya 一致）
backup: check
	@echo "备份多文件 C 目录 src/.uyacache -> backup/uyacache …"
	@if [ ! -f src/.uyacache/Makefile ]; then \
		echo "错误: src/.uyacache/Makefile 不存在（请先 make uya）"; \
		exit 1; \
	fi
	@mkdir -p backup
	@if command -v rsync >/dev/null 2>&1; then \
		mkdir -p backup/uyacache; \
		rsync -a --delete src/.uyacache/ backup/uyacache/; \
	else \
		rm -rf backup/uyacache; \
		cp -a src/.uyacache backup/uyacache; \
	fi
	@echo "✓ 备份完成: backup/uyacache"

# 单文件 C 种子：更新 bin/uya.c 与 backup/uya.c（from-c / release 依赖单文件）
backup-seed:
	@echo "单文件 C 编译（UYA_SINGLE_FILE_C=1）以更新 bin/uya.c 与 backup/uya.c …"
	@bash -c 'ulimit -s 32768 && cd src && UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR= CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=nostdlib LINK_MODE=static CFLAGS="$(CFLAGS) -fno-stack-protector" LDFLAGS="$(LDFLAGS)" ./compile.sh --c99 -e --nostdlib --safety-proof'
	@cp src/build/uya.c bin/uya.c
	@mkdir -p backup
	@cp bin/uya.c backup/uya.c
	@cp bin/uya.c backup/uya-$(HOST_OS)-$(HOST_ARCH).c
	@if [ ! -x bin/uya ]; then \
		echo "错误: 单文件 seed 编译后未生成 bin/uya"; \
		exit 1; \
	fi
	@echo "✓ backup/uya.c、backup/uya-$(HOST_OS)-$(HOST_ARCH).c 与 bin/uya.c 已更新（单文件种子；bin/uya 已由 compile.sh 同步重建）"

# hosted 单文件 C 本机种子：在当前宿主平台上更新 hosted seed；macOS 同步刷新统一入口 seed
backup-hosted-seed-native:
	@echo "单文件 C 编译（UYA_SINGLE_FILE_C=1）以更新当前宿主 hosted 本机种子 …"
	@bash -c 'set -e; REPO_ROOT="$$(pwd)"; UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya-hosted"; if [ ! -x "$$UYA_COMPILER_PATH" ]; then UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya"; fi; ulimit -s 32768 && cd src && UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR= UYA_COMPILER="$$UYA_COMPILER_PATH" CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=hosted LINK_MODE="$(LINK_MODE)" UYA_BOOTSTRAP_PROFILE="$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && echo darwin-hosted || echo hosted )" UYA_NATIVE_BOOTSTRAP="$$( [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && [ "$(HOST_ARCH)" = "$(TARGET_ARCH)" ] && echo 1 || echo 0 )" CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" ./compile.sh --c99 -e --name uya-hosted --safety-proof'
	@mkdir -p backup
	@cp src/build/uya-hosted.c backup/uya-hosted.c
	@cp src/build/uya-hosted.c backup/uya-hosted-$(HOST_OS)-$(HOST_ARCH).c
	@if [ "$(HOST_OS)" = "macos" ]; then \
		cp src/build/uya-hosted.c backup/uya-hosted-macos.c; \
		cp src/build/uya-hosted.c backup/uya-hosted-macos-$(HOST_ARCH).c; \
		echo "✓ backup/uya-hosted-macos.c 与 backup/uya-hosted-macos-$(HOST_ARCH).c 已按本机结果更新"; \
	fi
	@echo "✓ backup/uya-hosted.c 与 backup/uya-hosted-$(HOST_OS)-$(HOST_ARCH).c 已按当前宿主更新"

# hosted 单文件 C 种子：更新通用备份与 host/arch 专用备份（std.cfg 会固化 host/target）
# 若检测到 zig，则默认交叉刷新 macOS hosted seeds 作为辅助参考；本地提速可设 UYA_BACKUP_MACOS_AUX=0 跳过该可选步骤
backup-hosted-seed:
	@echo "单文件 C 编译（UYA_SINGLE_FILE_C=1）以更新 backup/uya-hosted.c 与 host/arch 专用备份 …"
	@bash -c 'set -e; REPO_ROOT="$$(pwd)"; UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya"; if [ ! -x "$$UYA_COMPILER_PATH" ]; then UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya-hosted"; fi; ulimit -s 32768 && cd src && UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR= UYA_COMPILER="$$UYA_COMPILER_PATH" CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" RUNTIME_MODE=hosted LINK_MODE="$(LINK_MODE)" CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" ./compile.sh --c99 -e --name uya-hosted --safety-proof'
	@mkdir -p backup
	@cp src/build/uya-hosted.c backup/uya-hosted.c
	@cp src/build/uya-hosted.c backup/uya-hosted-$(HOST_OS)-$(HOST_ARCH).c
	@bash -c 'set -e; \
		REPO_ROOT="$$(pwd)"; \
			UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya"; \
			if [ ! -x "$$UYA_COMPILER_PATH" ]; then UYA_COMPILER_PATH="$$REPO_ROOT/bin/uya-hosted"; fi; \
		UPDATED_UNIFIED=0; \
		case "$${UYA_BACKUP_MACOS_AUX:-auto}" in \
			0|false|FALSE|no|NO|off|OFF) REFRESH_MACOS_AUX=0 ;; \
			*) REFRESH_MACOS_AUX=1 ;; \
		esac; \
		if [ "$$REFRESH_MACOS_AUX" -eq 1 ] && [ -x "$(ZIG)" ]; then \
			echo "检测到 zig，可选地交叉刷新 macOS hosted 种子（仅辅助参考）…"; \
			for ARCH in arm64 x86_64; do \
				case "$$ARCH" in \
					arm64) TRIPLE="aarch64-macos-none" ;; \
					x86_64) TRIPLE="x86_64-macos-none" ;; \
				esac; \
				if [ "$(HOST_OS)" = "macos" ] && [ "$(TARGET_OS)" = "macos" ] && [ "$(HOST_ARCH)" = "$$ARCH" ] && [ "$(TARGET_ARCH)" = "$$ARCH" ] && [ -f "src/build/uya-hosted.c" ]; then \
					cp "src/build/uya-hosted.c" "backup/uya-hosted-macos-$$ARCH.c"; \
					if [ "$$ARCH" = "x86_64" ]; then \
						cp "src/build/uya-hosted.c" "backup/uya-hosted-macos.c"; \
						UPDATED_UNIFIED=1; \
					fi; \
					echo "提示: 复用当前宿主 macOS $$ARCH hosted seed，跳过重复交叉编译"; \
					continue; \
				fi; \
				STATUS=0; \
				ulimit -s 32768 || true; \
				( cd src && \
					UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR= \
					UYA_COMPILER="$$UYA_COMPILER_PATH" \
					CC="$(CC)" CC_DRIVER="$(ZIG) cc" CC_TARGET_FLAGS="-target $$TRIPLE" \
					HOST_OS="macos" HOST_ARCH="$$ARCH" TARGET_OS="macos" TARGET_ARCH="$$ARCH" TARGET_TRIPLE="$$TRIPLE" \
					TOOLCHAIN="zig" ZIG="$(ZIG)" RUNTIME_MODE=hosted LINK_MODE=dynamic \
					CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" \
					./compile.sh --c99 -e --name "uya-hosted-macos-$$ARCH" --safety-proof \
				) || STATUS=$$?; \
				if [ ! -f "src/build/uya-hosted-macos-$$ARCH.c" ]; then \
					exit $$STATUS; \
				fi; \
				cp "src/build/uya-hosted-macos-$$ARCH.c" "backup/uya-hosted-macos-$$ARCH.c"; \
				if [ "$$ARCH" = "x86_64" ]; then \
					cp "src/build/uya-hosted-macos-$$ARCH.c" "backup/uya-hosted-macos.c"; \
					UPDATED_UNIFIED=1; \
				fi; \
				if [ "$$STATUS" -ne 0 ]; then \
					echo "提示: zig 交叉链接 macOS $$ARCH hosted 可执行文件失败，但已保留并更新 C 种子"; \
				fi; \
			done; \
			echo "✓ backup/uya-hosted-macos-arm64.c 与 backup/uya-hosted-macos-x86_64.c 已更新（zig 交叉 hosted 种子，仅辅助参考）"; \
		elif [ "$$REFRESH_MACOS_AUX" -eq 1 ]; then \
			echo "提示: 未找到可执行 zig ($(ZIG))，跳过 macOS hosted 交叉种子"; \
		else \
			echo "提示: UYA_BACKUP_MACOS_AUX=$${UYA_BACKUP_MACOS_AUX:-auto}，跳过可选 macOS hosted 交叉种子"; \
		fi; \
		if [ "$$UPDATED_UNIFIED" -eq 1 ]; then \
			echo "✓ backup/uya-hosted-macos.c 已同步为当前 macOS 统一入口 seed（基于 x86_64 种子；macOS 主线仍以本机验证结果为准）"; \
		fi'
	@echo "✓ backup/uya-hosted.c、backup/uya-hosted-$(HOST_OS)-$(HOST_ARCH).c 与可用的 macOS hosted 种子已更新"

# 全量单文件种子：Linux/host nostdlib + hosted + 可用的 macOS hosted 种子
backup-all-seed: backup-seed backup-hosted-seed

# 兼容缩写/旧口误：make back-all-seed
back-all-seed: backup-all-seed

# 验证 + 多文件备份 + 全量单文件种子（提交前完整备份）
backup-all:backup backup-all-seed

# 发布前检查：确保本地 release 结果可作为“一键最终验证”
# 要求工作树干净；否则直接失败，避免把“本地脏状态”误当成可发布结果
# 注意：release-flow 首步会执行 clean，因此忽略目录 bin/ 下的陈旧种子不应拦截 release；
# 真正需要收口的是 Git 已跟踪的 backup/* 种子与已提交快照的一致性。
release-preflight:
	@echo "=========================================="
	@echo "发布前检查 (release-preflight)"
	@echo "=========================================="
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		STATUS=$$(git status --short --untracked-files=normal); \
		if [ -n "$$STATUS" ]; then \
			echo "错误: 当前工作树不是干净状态；拒绝执行 make release。"; \
			echo "make release 旨在作为一键最终验证入口，请先提交/暂存/清理改动。"; \
			echo "若要验证已提交的 HEAD，请使用 'make release-clean'。"; \
			echo ""; \
			echo "工作树摘要（前 20 行）:"; \
			printf '%s\n' "$$STATUS" | sed -n '1,20p'; \
			echo ""; \
			exit 1; \
		else \
			echo "✓ Git 工作树干净"; \
		fi; \
	else \
		echo "提示: 当前目录不是 Git 工作树，跳过工作树一致性检查"; \
	fi
	@if [ -f bin/uya.c ] && [ -f backup/uya.c ]; then \
		if cmp -s bin/uya.c backup/uya.c; then \
			echo "✓ bin/uya.c 与 backup/uya.c 一致"; \
		else \
			echo "提示: bin/uya.c 与 backup/uya.c 不一致；release-flow 会先 clean 并按已跟踪 seed 重建。"; \
			echo "若要同步本地单文件种子，可运行 'make backup-seed'。"; \
		fi; \
	else \
		echo "提示: bin/uya.c 或 backup/uya.c 缺失，release 过程中可能触发恢复/重生成"; \
	fi

# 发布流程内部 bootstrap：macOS 走 from-c-native，其它平台走 from-c
release-bootstrap:
ifeq ($(HOST_OS),macos)
	@$(MAKE) --no-print-directory from-c-native
else
	@$(MAKE) --no-print-directory from-c
endif

# 发布流程内部流水线：Linux 使用 nostdlib 主线；其它平台使用 hosted 主线。
release-flow:
	@$(MAKE) --no-print-directory clean
	@$(MAKE) --no-print-directory release-bootstrap
ifeq ($(HOST_OS),linux)
	@$(MAKE) --no-print-directory uya
	@$(MAKE) --no-print-directory b UYA_SKIP_UYA=1
	@$(MAKE) --no-print-directory check UYA_SKIP_UYA=1
	@UYA_BACKUP_MACOS_AUX="$${UYA_BACKUP_MACOS_AUX:-0}" $(MAKE) --no-print-directory backup-all-seed
else
	@$(MAKE) --no-print-directory check-hosted
	@$(MAKE) --no-print-directory backup-hosted-seed-native
	@if [ -f src/build/uya-hosted.c ]; then \
		cp src/build/uya-hosted.c bin/uya.c; \
		echo "✓ bin/uya.c 已更新为当前 hosted seed"; \
	else \
		echo "错误: hosted seed 未生成: src/build/uya-hosted.c"; \
		exit 1; \
	fi
endif
	@$(MAKE) --no-print-directory release-build

# 发布版本：验证 + 多文件备份 + 单文件种子 + 构建优化版本
# 与 from-c 一致：Linux x86_64 的 nostdlib 种子含裸 _start，不可直接 cc uya.c（会与 Scrt1 _start 冲突），须 crti + .o + crtn 链接
release: release-preflight
	@$(MAKE) --no-print-directory release-flow

release-build:
	@echo "=========================================="
	@echo "构建发布版本 (release)"
	@echo "=========================================="
	@echo "编译优化版本 bin/uya ..."
	@HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" \
		CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		bash -c 'set -e; ulimit -s 32768 2>/dev/null || true; \
		EXTRA_HOST_SOURCES=""; \
		if [ "$$HOST_OS" = "macos" ] && [ -f "src/host/macos_stat_shim.c" ]; then EXTRA_HOST_SOURCES="src/host/macos_stat_shim.c"; fi; \
		if grep -qE "^[[:space:]]*__attribute__\\(\\(naked\\)\\)[[:space:]]+void[[:space:]]+_start\\(void\\)" bin/uya.c 2>/dev/null \
			&& [ "$$HOST_OS" = "linux" ] && [ "$$HOST_ARCH" = "x86_64" ]; then \
			echo "nostdlib 种子：-O3 -DNDEBUG，crti.o + uya.o + crtn.o 链接（同 from-c）..."; \
			$$CC_DRIVER $$CC_TARGET_FLAGS -std=c99 -O3 -fno-builtin -DNDEBUG -fno-stack-protector -c bin/uya.c -o bin/.release.o; \
			CRTI=$$($$CC_DRIVER $$CC_TARGET_FLAGS -print-file-name=crti.o); \
			CRTN=$$($$CC_DRIVER $$CC_TARGET_FLAGS -print-file-name=crtn.o); \
			if [ ! -f "$$CRTI" ] || [ "$$CRTI" = "crti.o" ] || [ ! -f "$$CRTN" ] || [ "$$CRTN" = "crtn.o" ]; then \
				echo "错误: 无法解析 crti.o/crtn.o，无法链接 nostdlib 版 release"; exit 1; \
			fi; \
			$$CC_DRIVER $$CC_TARGET_FLAGS -fno-stack-protector -no-pie -nostdlib -static \
				-o bin/uya "$$CRTI" bin/.release.o "$$CRTN" $$LDFLAGS; \
			rm -f bin/.release.o; \
		else \
			$$CC_DRIVER $$CC_TARGET_FLAGS -std=c99 -O3 -fno-builtin -DNDEBUG bin/uya.c $$EXTRA_HOST_SOURCES -o bin/uya -lm $$LDFLAGS; \
		fi'
	@strip bin/uya
	@echo ""
	@echo "✓ 发布版本构建完成: bin/uya"
	@ls -la bin/uya
	@echo ""
	@echo "优化选项: -O3 -fno-builtin -DNDEBUG"
	@echo "已剥离调试符号 (strip)"

# 在当前工作树直接执行完整 release 流程；跳过干净树检查
# 默认跳过外网敏感测试，避免本地调试被瞬时网络波动误判阻塞
# 适合本地调试，不适合作为“最终验证”结论
release-dirty:
	@ALLOW_SKIP_NETWORK=1 $(MAKE) --no-print-directory release-flow

# 在干净快照里执行 release，尽量贴近 GitHub Actions 的 checkout 环境
# 注意：只包含已提交到 HEAD 的内容；未提交修改不会进入快照
release-clean:
	@echo "=========================================="
	@echo "构建干净快照发布版本 (release-clean)"
	@echo "=========================================="
	@if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		echo "错误: release-clean 需要在 Git 工作树中运行"; \
		exit 1; \
	fi
	@set -e; TMP_DIR=$$(mktemp -d /tmp/uya-release-clean.XXXXXX); \
	trap 'rm -rf "$$TMP_DIR"' EXIT INT TERM; \
	echo "导出 HEAD 快照到 $$TMP_DIR ..."; \
	git archive --format=tar HEAD | tar -xf - -C "$$TMP_DIR"; \
	echo "在干净快照中执行 make release ..."; \
	ALLOW_SKIP_NETWORK=1 $(MAKE) -C "$$TMP_DIR" release HOST_OS="$(HOST_OS)" HOST_ARCH="$(HOST_ARCH)" TARGET_OS="$(TARGET_OS)" TARGET_ARCH="$(TARGET_ARCH)" TARGET_TRIPLE="$(TARGET_TRIPLE)" TOOLCHAIN="$(TOOLCHAIN)" ZIG="$(ZIG)" CC="$(CC)" CC_DRIVER="$(CC_DRIVER)" CC_TARGET_FLAGS="$(CC_TARGET_FLAGS)" CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" UYA_TEST_JOBS="$(UYA_TEST_JOBS)"; \
	ARTIFACT_PATH="bin/uya.release-clean"; \
	mkdir -p "$$(dirname "$$ARTIFACT_PATH")"; \
	cp "$$TMP_DIR/bin/uya" "$$ARTIFACT_PATH"; \
	echo ""; \
	echo "✓ 干净快照 release 成功"; \
	echo "已复制到: $$ARTIFACT_PATH"

# 安装编译器、标准库源码树与 tests/（需系统 install(1)；标准库排除 lib/build）
# tests 安装会排除常见中间目录与二进制产物（避免将本地测试构建垃圾安装到目标目录）
install:
	@if [ ! -f bin/uya ]; then \
		echo "bin/uya 不存在，先执行 from-c ..."; \
		$(MAKE) from-c; \
	fi
	@$(MAKE) cmds
	@echo "安装 uya -> $(INSTALL_DEST_ROOT)$(INSTALL_BINDIR)/uya"
	@install -d "$(INSTALL_DEST_ROOT)$(INSTALL_BINDIR)"
	@install -m 755 bin/uya "$(INSTALL_DEST_ROOT)$(INSTALL_BINDIR)/uya"
	@install -d "$(INSTALL_DEST_ROOT)$(INSTALL_BINDIR)/cmd"
	@for cmd_bin in $(UYA_CMD_BINS); do \
		install -m 755 "$$cmd_bin" "$(INSTALL_DEST_ROOT)$(INSTALL_BINDIR)/cmd/$$(basename "$$cmd_bin")"; \
	done
	@echo "安装标准库 -> $(INSTALL_DEST_ROOT)$(LIBDIR)/"
	@install -d "$(INSTALL_DEST_ROOT)$(LIBDIR)"
	@for entry in lib/*; do \
		if [ ! -e "$$entry" ]; then continue; fi; \
		base=$$(basename "$$entry"); \
		if [ "$$base" = "build" ]; then continue; fi; \
		cp -a "$$entry" "$(INSTALL_DEST_ROOT)$(LIBDIR)/"; \
	done
	@echo "安装文档 -> $(INSTALL_DEST_ROOT)$(DOCDIR)/"
	@install -d "$(INSTALL_DEST_ROOT)$(DOCDIR)"
	@for f in uya_ai_prompt.md uya.md grammar_formal.md builtin_functions.md union_memory_layout.md; do \
		if [ ! -f "docs/$$f" ]; then echo "错误: 缺少 docs/$$f"; exit 1; fi; \
		install -m 644 "docs/$$f" "$(INSTALL_DEST_ROOT)$(DOCDIR)/$$f"; \
	done
	@echo "安装测试树 -> $(INSTALL_DEST_ROOT)$(TESTSDIR)/"
	@if [ ! -d tests ]; then echo "错误: tests 目录不存在"; exit 1; fi
	@rm -rf "$(INSTALL_DEST_ROOT)$(TESTSDIR)"
	@install -d "$(INSTALL_DEST_ROOT)$(TESTSDIR)"
	@cp -a tests/. "$(INSTALL_DEST_ROOT)$(TESTSDIR)/"
	@rm -rf "$(INSTALL_DEST_ROOT)$(TESTSDIR)/programs/build" \
		"$(INSTALL_DEST_ROOT)$(TESTSDIR)/build" \
		"$(INSTALL_DEST_ROOT)$(TESTSDIR)/.uyacache"
	@find "$(INSTALL_DEST_ROOT)$(TESTSDIR)" -type f \( \
		-name '*.o' -o -name '*.obj' -o -name '*.a' -o -name '*.so' -o -name '*.dylib' -o -name '*.exe' -o -name '*.out' \
	\) -delete
	@echo "✓ 安装完成: $(INSTALL_DEST_ROOT)$(INSTALL_BINDIR)/uya + $(INSTALL_DEST_ROOT)$(LIBDIR)/ + $(INSTALL_DEST_ROOT)$(DOCDIR)/ + $(INSTALL_DEST_ROOT)$(TESTSDIR)/"

# 从备份恢复 bin/uya.c
restore:
	@echo "从备份恢复 bin/uya.c ..."
	@if [ ! -f backup/uya.c ]; then \
		echo "错误: backup/uya.c 不存在"; \
		exit 1; \
	fi
	@mkdir -p bin
	@cp backup/uya.c bin/uya.c
	@echo "✓ 恢复完成: bin/uya.c"
	@ls -la bin/uya.c

# 显示帮助信息
help:
	@echo "Uya 项目 Makefile"
	@echo ""
	@echo "编译选项（可通过环境变量覆盖）:"
	@echo "  HOST_OS  = $(HOST_OS)"
	@echo "  HOST_ARCH= $(HOST_ARCH)"
	@echo "  TARGET_OS= $(TARGET_OS)"
	@echo "  TARGET_ARCH= $(TARGET_ARCH)"
	@echo "  TARGET_TRIPLE = $(TARGET_TRIPLE)"
	@echo "  RUNTIME_MODE = $(RUNTIME_MODE)"
	@echo "  LINK_MODE = $(LINK_MODE)"
	@echo "  TOOLCHAIN = $(TOOLCHAIN)"
	@echo "  ZIG      = $(ZIG)"
	@echo "  CC       = $(CC)"
	@echo "  CC_DRIVER= $(CC_DRIVER)"
	@echo "  CC_TARGET_FLAGS = $(CC_TARGET_FLAGS)"
	@echo "  CFLAGS   = $(CFLAGS)"
	@echo "  LDFLAGS  = $(LDFLAGS)"
	@echo ""
	@echo "用法示例:"
	@echo "  CFLAGS='-std=c99 -O0 -g -fno-builtin' make from-c    # 覆盖默认（默认含 -Werror）"
	@echo "  CFLAGS='-std=c99 -O2 -fno-builtin -Werror' make uya   # 使用 O2 优化构建"
	@echo "  TOOLCHAIN=zig ZIG=$(ZIG) make uya-hosted # 使用 zig cc hosted 构建"
	@echo ""
	@echo "可用目标:"
	@echo "  make from-c        - 从 bin/uya.c 构建（零依赖）"
	@echo "  make from-c-native - 从本机 seed 构建；macOS 优先使用 backup/uya-hosted-macos-<arch>.c，其次是 backup/uya-hosted-macos.c"
	@echo "  make uya           - 构建自举编译器（默认 --nostdlib，静态链接）"
	@echo "  make uya-hosted    - 构建自举编译器（hosted 主线）"
	@echo "  make uya-portable  - 跨平台入口：Linux 用 uya，其它平台用 uya-hosted"
	@echo "  make uya-std       - 构建自举编译器（标准库链接，用于调试）"
	@echo "  make uya-safety    - 构建自举编译器（启用内存安全检查）"
	@echo "  make b             - 自举验证：编译器编译自身，验证输出一致性"
	@echo "  make b-hosted      - hosted 自举验证"
	@echo "  make b-portable    - 跨平台入口：Linux 用 b，其它平台用 b-hosted"
	@echo "  make bench-compile-stats ARGS='--runs 3' - 抓取 CompileStats 基准数据"
	@echo "  make tests         - 运行测试套件（并行数默认 CPU 核数，UYA_TEST_JOBS=N 可改；默认不打印每条通过的 ✓）"
	@echo "  make tests-hosted  - 运行 hosted 主测试集（同上，默认 --hide-pass）"
	@echo "  make tests-portable - 跨平台入口：Linux 用 tests，其它平台用 tests-hosted"
	@echo "  make tests e       - 运行所有测试，最小输出（仅失败详情，等同脚本 -e）"
	@echo "  make tests-uya     - 快捷方式：测试自举编译器"
	@echo "  make tests-uya e   - 同上 + 最小输出（-e）"
	@echo "  make tests-emcc    - 运行独立 emcc/unknown target smoke（需本机安装 emcc 与 node）"
	@echo "  make cmds          - 构建外置子命令（当前包含 cmd/upm）"
	@echo "  make upm-check     - 运行 UPM/包管理专项回归套件"
	@echo "  make examples-check - 运行 examples 可执行/服务/package/microapp 验证套件"
	@echo "  make microapp-check - 运行当前 microapp 聚合回归套件"
	@echo "  make microapp-hosted-smoke - 运行 hosted 平台可用的 microapp smoke 套件"
	@echo "  make microapp-aarch64-runtime-check - 运行 arm64-host-gated 的 aarch64 microapp runtime 回归"
	@echo "  make microapp-macos-runtime-check - 运行 macOS arm64-host-gated 的 microapp runtime 回归"
	@echo "  make microapp-compat-check - 运行 .uapp v1/v2 兼容回归"
	@echo "  make microapp-recovery-check - 运行 crash/recovery/update 回归"
	@echo "  make outlibc       - 输出标准库为 C 代码（使用自举编译器）"
	@echo "  make check         - 验证（自举 + 测试），不备份"
	@echo "  make check-hosted  - hosted 验证（自举 + 测试），不备份"
	@echo "  make backup        - 验证 + 备份多文件 C 目录 backup/uyacache（与 make uya 一致）"
	@echo "  make backup-seed   - 单文件 C 重编译，更新 bin/uya.c、backup/uya.c 与 host/arch 专用备份"
	@echo "  make backup-hosted-seed - hosted 单文件种子，更新 backup/uya-hosted.c、host/arch 备份；有 zig 时可辅助刷新 macOS hosted seeds"
	@echo "  make backup-hosted-seed-native - 仅按当前宿主更新 hosted 本机种子；macOS 同步刷新 backup/uya-hosted-macos.c"
	@echo "                           macOS 统一入口 seed 为 backup/uya-hosted-macos.c；backup/uya-hosted-macos-arm64.c 与 -x86_64.c 永久保留作对照"
	@echo "  make backup-all-seed - 全量单文件种子：Linux/host nostdlib + hosted + 可选的 macOS hosted seeds（可加 UYA_BACKUP_MACOS_AUX=0 提速）"
	@echo "  make back-all-seed - backup-all-seed 的别名"
	@echo "  make backup-all    - backup + backup-all-seed（提交前完整备份；本地提速可加 UYA_BACKUP_MACOS_AUX=0）"
	@echo "  make release       - 一键最终验证：要求工作树干净，再 clean+自举验证+backup-all-seed 后 -O3 -DNDEBUG 重链 + strip"
	@echo "  make release-dirty - 在当前工作树强行执行完整 release；用于本地调试，不作为最终验证结论"
	@echo "  make release-clean - 用 Git HEAD 干净快照执行 make release，贴近 CI（忽略未提交修改）"
	@echo "  make install       - 安装 uya、lib/、前缀/docs/、前缀/tests/；BINDIR/LIBDIR/DOCDIR/TESTSDIR/DESTDIR"
	@echo "  make restore       - 从 backup/uya.c 恢复 bin/uya.c"
	@echo "  make clean         - 清理所有构建产物"
	@echo "  make help          - 显示此帮助信息"
	@echo ""
	@echo "示例:"
	@echo "  make from-c-native                    # macOS 本机 seed 冷启动"
	@echo "  make uya-hosted && make b-hosted      # hosted 自举验证"
	@echo "  make tests-hosted                     # hosted 主测试集"
	@echo "  make tests e                         # 运行所有测试，最小输出"
	@echo "  make clean && make from-c            # 清理后从备份恢复并构建"
	@echo '  make install PREFIX=$$HOME/.local   # ~/.local/bin/uya + ~/.local/lib/{std,libc,...}'
	@echo "  make install BINDIR=out              # out/bin/uya + out/lib/（BINDIR 作前缀，同 PREFIX 布局）"
	@echo "  make install BINDIR=/custom/bin      # 路径以 bin 结尾：可执行目录本身 + /custom/lib/"
	@echo "  make install LIBDIR=/other/lib       # 显式标准库目录（通常需配合 export UYA_ROOT）"
	@echo "  make install DOCDIR=/path/docs       # 显式文档目录（默认 前缀/docs）"
	@echo "  make install TESTSDIR=/path/tests    # 显式测试目录（默认 前缀/tests）"
	@echo ""
	@echo "macOS: from-c-native 优先使用 backup/uya-hosted-macos-<arch>.c；backup/uya-hosted-macos.c 仅作统一回退入口。"
