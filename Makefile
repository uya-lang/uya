# Uya 项目根目录 Makefile
# 提供统一的构建和测试入口

.PHONY: all uya-c uya b tests tests-c tests-uya outlibc c e clean help

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

# 构建自举编译器（src）
uya: uya-c
	@echo "=========================================="
	@echo "构建自举编译器 (uya)"
	@echo "=========================================="
	@cd src && ./compile.sh --c99 -e
	@echo ""
	@echo "✓ 自举编译器构建完成: bin/uya"

# 自举比对：用自举编译器编译自身，与 C 编译器输出对比
b: uya
	@echo "=========================================="
	@echo "自举比对：验证 C 编译器与自举编译器输出一致性"
	@echo "=========================================="
	@cd src && ./compile.sh --c99 -e -b
	@echo ""
	@echo "✓ 自举比对完成"

# 运行测试：支持参数传递
# 用法: make tests [c|uya] [-e] [其他参数]
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
			./tests/run_programs.sh --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs.sh --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "--- 测试自举编译器 (uya) ---"; \
		$(MAKE) uya >/dev/null 2>&1; \
		if [ "$$HAS_E" = "yes" ]; then \
			./tests/run_programs.sh --uya --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs.sh --uya --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "✓ 所有测试完成"; \
	elif [ "$$COMPILER_TYPE" = "c" ]; then \
		echo "=========================================="; \
		echo "测试 C 编译器 (uya-c)"; \
		echo "=========================================="; \
		$(MAKE) uya-c >/dev/null 2>&1; \
		if [ "$$HAS_E" = "yes" ]; then \
			./tests/run_programs.sh --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs.sh --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "✓ C 编译器测试完成"; \
	elif [ "$$COMPILER_TYPE" = "uya" ]; then \
		echo "=========================================="; \
		echo "测试自举编译器 (uya)"; \
		echo "=========================================="; \
		$(MAKE) uya >/dev/null 2>&1; \
		if [ "$$HAS_E" = "yes" ]; then \
			./tests/run_programs.sh --uya --c99 -e $$OTHER_ARGS; \
		else \
			./tests/run_programs.sh --uya --c99 $$OTHER_ARGS; \
		fi; \
		echo ""; \
		echo "✓ 自举编译器测试完成"; \
	fi

# 快捷目标：测试 C 编译器（支持 e 参数）
tests-c:
	@HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	$(MAKE) uya-c >/dev/null 2>&1; \
	echo "=========================================="; \
	echo "测试 C 编译器 (uya-c)"; \
	echo "=========================================="; \
	if [ "$$HAS_E" = "yes" ]; then \
		./tests/run_programs.sh --c99 -e; \
	else \
		./tests/run_programs.sh --c99; \
	fi

# 快捷目标：测试自举编译器（支持 e 参数）
tests-uya:
	@HAS_E=$$(echo "$(MAKECMDGOALS)" | grep -qE '\be\b' && echo "yes" || echo "no"); \
	$(MAKE) uya >/dev/null 2>&1; \
	echo "=========================================="; \
	echo "测试自举编译器 (uya)"; \
	echo "=========================================="; \
	if [ "$$HAS_E" = "yes" ]; then \
		./tests/run_programs.sh --uya --c99 -e; \
	else \
		./tests/run_programs.sh --uya --c99; \
	fi

# 输出标准库为 C 代码
outlibc: uya-c
	@echo "=========================================="
	@echo "输出标准库为 C 代码 (outlibc)"
	@echo "=========================================="
	@mkdir -p lib/build
	@echo "编译标准库文件..."
	@if [ -f bin/uya-c ]; then \
		COMPILER=bin/uya-c; \
	elif [ -f compiler-c/build/compiler-c ]; then \
		COMPILER=compiler-c/build/compiler-c; \
	else \
		echo "错误: 找不到编译器，请先运行 'make uya-c'"; \
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

# 显示帮助信息
help:
	@echo "Uya 项目 Makefile"
	@echo ""
	@echo "可用目标:"
	@echo "  make uya-c    - 构建 C 编译器 (bin/uya-c)"
	@echo "  make uya      - 构建自举编译器 (bin/uya)，需要先构建 uya-c"
	@echo "  make b        - 自举比对：验证 C 编译器与自举编译器输出一致性"
	@echo "  make tests          - 运行测试套件（同时测试 C 编译器和自举编译器）"
	@echo "  make tests e        - 运行所有测试，只显示失败的测试"
	@echo "  make tests c        - 只测试 C 编译器"
	@echo "  make tests uya      - 只测试自举编译器"
	@echo "  make tests c e       - 测试 C 编译器，只显示失败的测试"
	@echo "  make tests uya e     - 测试自举编译器，只显示失败的测试"
	@echo "  make tests-c         - 快捷方式：测试 C 编译器"
	@echo "  make tests-c e       - 快捷方式：测试 C 编译器，只显示失败的测试"
	@echo "  make tests-uya       - 快捷方式：测试自举编译器"
	@echo "  make tests-uya e     - 快捷方式：测试自举编译器，只显示失败的测试"
	@echo "  make outlibc         - 输出标准库为 C 代码 (lib/build/libuya.c)"
	@echo "  make clean           - 清理所有构建产物"
	@echo "  make help            - 显示此帮助信息"
	@echo ""
	@echo "示例:"
	@echo "  make uya-c && make uya && make b    # 完整构建和自举比对"
	@echo "  make tests                           # 运行所有测试"
	@echo "  make tests e                         # 运行所有测试，只显示错误"
	@echo "  make tests c e                       # 只测试 C 编译器，只显示错误"
	@echo "  make tests uya e                     # 只测试自举编译器，只显示错误"
	@echo "  make tests-c e                       # 快捷方式：测试 C 编译器，只显示错误"
	@echo "  make tests-uya e                     # 快捷方式：测试自举编译器，只显示错误"

