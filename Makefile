# Uya 项目根目录 Makefile
# 提供统一的构建和测试入口

.PHONY: all from-c uya-c uya uya-nostdlib b tests tests-c tests-uya outlibc c e clean backup restore help

# 默认目标
all: help

# 空目标：用于捕获参数（避免 make 报错）
# 注意：uya 是真实目标，不能在这里声明
c e:
	@:

# 构建 C 编译器（compiler-c）
uya-c:
	@echo "=========================================="
	@echo "构建 C 编译器 (uya-c)"
	@echo "=========================================="
	@cd compiler-c && $(MAKE) build
	@echo ""
	@echo "✓ C 编译器构建完成: bin/uya-c"

# 从 bin/uya.c 构建（零依赖，不需要 uya-c）
from-c:
	@echo "=========================================="
	@echo "从 C99 代码构建编译器 (from-c)"
	@echo "=========================================="
	@if [ ! -f bin/uya.c ]; then \
		if [ -f backup/uya.c.zip ]; then \
			echo "bin/uya.c 不存在，从备份恢复..."; \
			mkdir -p bin; \
			unzip -o backup/uya.c.zip -d bin/; \
		else \
			echo "错误: bin/uya.c 和 backup/uya.c.zip 都不存在"; \
			exit 1; \
		fi \
	fi
	@echo "编译 bin/uya.c ..."
	@gcc -std=c99 -O2 bin/uya.c -o bin/uya -lm
	@echo ""
	@echo "✓ 编译器构建完成: bin/uya"
	@ls -la bin/uya

# 构建自举编译器（src），并更新 bin/uya.c
uya:
	@echo "=========================================="
	@echo "构建自举编译器 (uya)"
	@echo "=========================================="
	@if [ ! -f bin/uya ]; then \
		echo "bin/uya 不存在，从备份构建..."; \
		$(MAKE) from-c; \
	fi
	@echo "使用 bin/uya 编译 src/ ..."
	@cd src && ./compile.sh --c99 -e
	@echo ""
	@echo "更新 bin/uya.c ..."
	@cp src/build/uya.c bin/uya.c
	@echo "✓ bin/uya.c 已更新"
	@echo "重新编译 bin/uya ..."
	@gcc -std=c99 -O2 bin/uya.c -o bin/uya -lm
	@echo ""
	@echo "✓ 自举编译器构建完成: bin/uya"
	@echo ""
	@echo "提示: 运行 'make b' 验证自举，通过后会自动备份"

# 构建自举编译器（--nostdlib 版本）
uya-nostdlib: uya-c
	@echo "=========================================="
	@echo "构建自举编译器 (uya-nostdlib)"
	@echo "使用 --nostdlib 选项（不链接标准库）"
	@echo "=========================================="
	@cd src && ./compile.sh --c99 -e --nostdlib
	@echo ""
	@echo "✓ 自举编译器（--nostdlib）构建完成: bin/uya"

# 自举验证：用自举编译器编译自身，验证输出一致性
b: uya
	@echo "=========================================="
	@echo "自举验证：编译器编译自身，验证输出一致性"
	@echo "=========================================="
	@cd src && ./compile.sh --c99 -e -b
	@echo ""
	@echo "✓ 自举验证完成"

# 运行测试：默认使用 tests/run_programs_parallel.sh 并行测试（可 -j N 控制线程数）
# 用法: make tests [c|uya] [e] [其他参数]
# 示例: make tests c -e
#       make tests uya -e
#       make tests c test_file.uya
tests:
	@COMPILER_TYPE=$$(echo "$(MAKECMDGOALS)" | grep -oE '\b(c|uya)\b' | head -1 || echo ""); \
	HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	OTHER_ARGS=$$(echo "$(MAKECMDGOALS)" | sed 's/tests//g' | sed 's/\b\(c\|uya\|e\)\b//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
	if [ -z "$$COMPILER_TYPE" ]; then \
		echo "=========================================="; \
		echo "运行测试套件（C 编译器和自举编译器）"; \
		echo "=========================================="; \
		echo ""; \
		echo "--- 测试 C 编译器 (uya-c) ---"; \
		$(MAKE) uya-c >/dev/null 2>&1; \
		if [ "$$HAS_E" = "yes" ]; then \
			./tests/run_programs_parallel.sh --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs_parallel.sh --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "--- 测试自举编译器 (uya) ---"; \
		$(MAKE) uya >/dev/null 2>&1; \
		if [ "$$HAS_E" = "yes" ]; then \
			./tests/run_programs_parallel.sh --uya --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs_parallel.sh --uya --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "✓ 所有测试完成"; \
	elif [ "$$COMPILER_TYPE" = "c" ]; then \
		echo "=========================================="; \
		echo "测试 C 编译器 (uya-c)"; \
		echo "=========================================="; \
		$(MAKE) uya-c >/dev/null 2>&1; \
		if [ "$$HAS_E" = "yes" ]; then \
			./tests/run_programs_parallel.sh --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs_parallel.sh --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "✓ C 编译器测试完成"; \
	elif [ "$$COMPILER_TYPE" = "uya" ]; then \
		echo "=========================================="; \
		echo "测试自举编译器 (uya)"; \
		echo "=========================================="; \
		$(MAKE) uya >/dev/null 2>&1; \
		if [ "$$HAS_E" = "yes" ]; then \
			./tests/run_programs_parallel.sh --uya --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs_parallel.sh --uya --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "✓ 自举编译器测试完成"; \
	fi

# 快捷目标：测试 C 编译器（默认 tests/run_programs_parallel.sh 并行）
tests-c:
	@HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	$(MAKE) uya-c >/dev/null 2>&1; \
	echo "=========================================="; \
	echo "测试 C 编译器 (uya-c)"; \
	echo "=========================================="; \
	if [ "$$HAS_E" = "yes" ]; then \
		./tests/run_programs_parallel.sh --c99 -e; \
	else \
		./tests/run_programs_parallel.sh --c99; \
	fi

# 快捷目标：测试自举编译器（默认 tests/run_programs_parallel.sh 并行）
tests-uya:
	@HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	$(MAKE) uya >/dev/null 2>&1; \
	echo "=========================================="; \
	echo "测试自举编译器 (uya)"; \
	echo "=========================================="; \
	if [ "$$HAS_E" = "yes" ]; then \
		./tests/run_programs_parallel.sh --uya --c99 -e; \
	else \
		./tests/run_programs_parallel.sh --uya --c99; \
	fi

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
	LIB_FILES=$$(find lib/std/c -name "*.uya" -type f | sort); \
	if [ -z "$$LIB_FILES" ]; then \
		echo "错误: 未找到标准库文件 (lib/std/c/*.uya)"; \
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
	@cd compiler-c && $(MAKE) clean
	@rm -rf bin/uya-c bin/uya
	@rm -rf compiler-c/build
	@rm -rf src/build
	@rm -rf tests/programs/build
	@rm -rf lib/build
	@echo "✓ 清理完成"

# 备份 bin/uya.c（依赖自举验证和测试通过）
backup: b
	@echo "=========================================="
	@echo "运行测试验证..."
	@echo "=========================================="
	@./tests/run_programs_parallel.sh --uya --c99 2>&1 | tail -5
	@echo ""
	@echo "备份 bin/uya.c 到 backup/uya.c.zip ..."
	@if [ ! -f bin/uya.c ]; then \
		echo "错误: bin/uya.c 不存在"; \
		exit 1; \
	fi
	@mkdir -p backup
	@cd bin && zip -u ../backup/uya.c.zip uya.c
	@echo "✓ 备份完成: backup/uya.c.zip"
	@ls -la backup/uya.c.zip

# 从备份恢复 bin/uya.c
restore:
	@echo "从备份恢复 bin/uya.c ..."
	@if [ ! -f backup/uya.c.zip ]; then \
		echo "错误: backup/uya.c.zip 不存在"; \
		exit 1; \
	fi
	@mkdir -p bin
	@unzip -o backup/uya.c.zip -d bin/
	@echo "✓ 恢复完成: bin/uya.c"
	@ls -la bin/uya.c

# 显示帮助信息
help:
	@echo "Uya 项目 Makefile"
	@echo ""
	@echo "可用目标:"
	@echo "  make from-c        - 从 bin/uya.c 构建（零依赖，不需要 uya-c）"
	@echo "  make uya-c         - 构建 C 编译器 (bin/uya-c)"
	@echo "  make uya           - 构建自举编译器 (bin/uya)，自动更新 bin/uya.c"
	@echo "  make uya-nostdlib  - 构建自举编译器（--nostdlib 版本，不链接标准库）"
	@echo "  make b             - 自举验证：编译器编译自身，验证输出一致性"
	@echo "  make tests          - 运行测试套件（默认 tests/run_programs_parallel.sh 并行）"
	@echo "  make tests e        - 运行所有测试，只显示失败的测试"
	@echo "  make tests c        - 只测试 C 编译器"
	@echo "  make tests uya      - 只测试自举编译器"
	@echo "  make tests c e       - 测试 C 编译器，只显示失败的测试"
	@echo "  make tests uya e     - 测试自举编译器，只显示失败的测试"
	@echo "  make tests-c         - 快捷方式：测试 C 编译器"
	@echo "  make tests-c e       - 快捷方式：测试 C 编译器，只显示失败的测试"
	@echo "  make tests-uya       - 快捷方式：测试自举编译器"
	@echo "  make tests-uya e     - 快捷方式：测试自举编译器，只显示失败的测试"
	@echo "  make outlibc         - 输出标准库为 C 代码（使用自举编译器）"
	@echo "  make backup          - 备份 bin/uya.c 到 backup/uya.c.zip"
	@echo "  make restore         - 从 backup/uya.c.zip 恢复 bin/uya.c"
	@echo "  make clean           - 清理所有构建产物"
	@echo "  make help            - 显示此帮助信息"
	@echo ""
	@echo "示例:"
	@echo "  make from-c                          # 从 C99 代码构建（首次克隆后）"
	@echo "  make uya && make b && make tests-uya # 完整构建和自举验证"
	@echo "  make tests                           # 运行所有测试"
	@echo "  make tests e                         # 运行所有测试，只显示错误"
	@echo "  make clean && make from-c            # 清理后从备份恢复并构建"

