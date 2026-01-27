# Uya Mini 编译器 Makefile
# 使用 C99 标准，无堆分配，使用 Arena 分配器

CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -g
INCLUDES = -Isrc

# 源文件
SRC_DIR = src
TEST_DIR = tests

# 构建输出目录
BUILD_DIR = build

# 测试目标
ARENA_TEST = $(BUILD_DIR)/tests/test_arena
ARENA_TEST_SRC = tests/test_arena.c src/arena.c
AST_TEST = $(BUILD_DIR)/tests/test_ast
AST_TEST_SRC = tests/test_ast.c src/ast.c src/arena.c
LEXER_TEST = $(BUILD_DIR)/tests/test_lexer
LEXER_TEST_SRC = tests/test_lexer.c src/lexer.c src/arena.c
PARSER_TEST = $(BUILD_DIR)/tests/test_parser
PARSER_TEST_SRC = tests/test_parser.c src/parser.c src/lexer.c src/ast.c src/arena.c
CHECKER_TEST = $(BUILD_DIR)/tests/test_checker
CHECKER_TEST_SRC = tests/test_checker.c src/checker.c src/parser.c src/lexer.c src/ast.c src/arena.c
CODEGEN_TEST = $(BUILD_DIR)/tests/test_codegen
CODEGEN_TEST_SRC = tests/test_codegen.c \
	src/codegen/llvm_capi/utils.c \
	src/codegen/llvm_capi/init.c \
	src/codegen/llvm_capi/types.c \
	src/codegen/llvm_capi/vars.c \
	src/codegen/llvm_capi/funcs.c \
	src/codegen/llvm_capi/structs.c \
	src/codegen/llvm_capi/enums.c \
	src/codegen/llvm_capi/expr.c \
	src/codegen/llvm_capi/stmt.c \
	src/codegen/llvm_capi/function.c \
	src/codegen/llvm_capi/global.c \
	src/codegen/llvm_capi/main.c \
	src/checker.c src/parser.c src/lexer.c src/ast.c src/arena.c

# 主程序目标
TARGET = $(BUILD_DIR)/compiler-mini
MAIN_SRC = src/main.c \
	src/codegen/llvm_capi/utils.c \
	src/codegen/llvm_capi/init.c \
	src/codegen/llvm_capi/types.c \
	src/codegen/llvm_capi/vars.c \
	src/codegen/llvm_capi/funcs.c \
	src/codegen/llvm_capi/structs.c \
	src/codegen/llvm_capi/enums.c \
	src/codegen/llvm_capi/expr.c \
	src/codegen/llvm_capi/stmt.c \
	src/codegen/llvm_capi/function.c \
	src/codegen/llvm_capi/global.c \
	src/codegen/llvm_capi/main.c \
	src/codegen/c99/utils.c \
	src/codegen/c99/types.c \
	src/codegen/c99/structs.c \
	src/codegen/c99/enums.c \
	src/codegen/c99/expr.c \
	src/codegen/c99/stmt.c \
	src/codegen/c99/function.c \
	src/codegen/c99/global.c \
	src/codegen/c99/main.c \
	src/checker.c src/parser.c src/lexer.c src/ast.c src/arena.c

# LLVM 库链接选项
# 使用 llvm-config 获取编译和链接选项（如果可用）
LLVM_CONFIG ?= llvm-config
LLVM_CFLAGS = $(shell $(LLVM_CONFIG) --cflags 2>/dev/null || echo "")
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --ldflags 2>/dev/null || echo "")
LLVM_LIBS = $(shell $(LLVM_CONFIG) --libs core target 2>/dev/null || echo "-llvm")

# 测试程序目录
PROGRAMS_DIR = tests/programs
PROGRAMS = $(wildcard $(PROGRAMS_DIR)/*.uya)
PROGRAM_BINARIES = $(patsubst $(PROGRAMS_DIR)/%.uya,$(BUILD_DIR)/$(PROGRAMS_DIR)/%,$(PROGRAMS))

.PHONY: all build test clean test-arena test-ast test-lexer test-parser test-checker test-codegen compile-programs test-programs c99-backend test-c99

# 默认目标
all: build

# 构建所有目标（主程序）
build: $(TARGET)
	@echo "构建完成: $(TARGET)"

# 编译主程序（需要链接 LLVM 库）
$(TARGET): $(MAIN_SRC) | $(BUILD_DIR)/.dir
	$(CC) $(CFLAGS) $(LLVM_CFLAGS) $(INCLUDES) -o $@ $^ $(LLVM_LDFLAGS) $(LLVM_LIBS)

# 运行所有测试
test: test-arena test-ast test-lexer test-parser test-checker test-codegen
	@echo "所有测试完成"

# Arena 分配器测试
test-arena: $(ARENA_TEST)
	@echo "运行 Arena 分配器测试..."
	./$(ARENA_TEST)

# 编译 Arena 测试
$(ARENA_TEST): $(ARENA_TEST_SRC) | $(BUILD_DIR)/tests/.dir
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# AST 测试
test-ast: $(AST_TEST)
	@echo "运行 AST 节点创建测试..."
	./$(AST_TEST)

# 编译 AST 测试
$(AST_TEST): $(AST_TEST_SRC) | $(BUILD_DIR)/tests/.dir
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# Lexer 测试
test-lexer: $(LEXER_TEST)
	@echo "运行 Lexer 测试..."
	./$(LEXER_TEST)

# 编译 Lexer 测试
$(LEXER_TEST): $(LEXER_TEST_SRC) | $(BUILD_DIR)/tests/.dir
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# Parser 测试
test-parser: $(PARSER_TEST)
	@echo "运行 Parser 基础框架测试..."
	./$(PARSER_TEST)

# 编译 Parser 测试
$(PARSER_TEST): $(PARSER_TEST_SRC) | $(BUILD_DIR)/tests/.dir
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# Checker 测试
test-checker: $(CHECKER_TEST)
	@echo "运行 Checker 测试..."
	./$(CHECKER_TEST)

# 编译 Checker 测试
$(CHECKER_TEST): $(CHECKER_TEST_SRC) | $(BUILD_DIR)/tests/.dir
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# CodeGen 测试
test-codegen: $(CODEGEN_TEST)
	@echo "运行 CodeGen 测试..."
	./$(CODEGEN_TEST)

# 编译 CodeGen 测试（需要链接 LLVM 库）
$(CODEGEN_TEST): $(CODEGEN_TEST_SRC) | $(BUILD_DIR)/tests/.dir
	$(CC) $(CFLAGS) $(LLVM_CFLAGS) $(INCLUDES) -o $@ $^ $(LLVM_LDFLAGS) $(LLVM_LIBS)

# 编译所有测试程序
compile-programs: $(TARGET) $(PROGRAM_BINARIES)

$(PROGRAM_BINARIES): $(BUILD_DIR)/$(PROGRAMS_DIR)/%: $(PROGRAMS_DIR)/%.uya | $(BUILD_DIR)/$(PROGRAMS_DIR)/.dir
	@echo "编译测试程序: $<"
	./$(TARGET) $< -o $@

# 运行所有测试程序
test-programs: compile-programs
	@echo "运行 Uya 测试程序..."
	@bash tests/run_programs.sh

# C99 后端示例：编译示例程序并生成 C99 代码
c99-backend: $(TARGET)
	@echo "使用 C99 后端编译示例程序..."
	@mkdir -p $(BUILD_DIR)/c99_examples
	@if [ -f tests/programs/test_simple.uya ]; then \
		./$(TARGET) tests/programs/test_simple.uya -o $(BUILD_DIR)/c99_examples/test_simple.c --c99; \
		echo "生成的 C99 代码已保存到: $(BUILD_DIR)/c99_examples/test_simple.c"; \
		echo "使用以下命令编译: gcc --std=c99 -o $(BUILD_DIR)/c99_examples/test_simple $(BUILD_DIR)/c99_examples/test_simple.c"; \
	else \
		echo "示例文件不存在，使用第一个测试程序..."; \
		FIRST_UYA=$$(ls tests/programs/*.uya 2>/dev/null | head -1); \
		if [ -n "$$FIRST_UYA" ]; then \
			./$(TARGET) $$FIRST_UYA -o $(BUILD_DIR)/c99_examples/example.c --c99; \
			echo "生成的 C99 代码已保存到: $(BUILD_DIR)/c99_examples/example.c"; \
		else \
			echo "错误: 未找到测试程序文件"; \
		fi; \
	fi

# 运行 C99 后端测试
test-c99: $(TARGET)
	@echo "运行 C99 后端测试..."
	@bash tests/run_programs.sh --c99

# 创建构建目录（使用中间目标避免与 build 目标冲突）
$(BUILD_DIR)/.dir:
	@mkdir -p $(BUILD_DIR)
	@touch $@

$(BUILD_DIR)/tests/.dir: | $(BUILD_DIR)/.dir
	@mkdir -p $(BUILD_DIR)/tests
	@touch $@

$(BUILD_DIR)/$(PROGRAMS_DIR)/.dir: | $(BUILD_DIR)/.dir
	@mkdir -p $(BUILD_DIR)/$(PROGRAMS_DIR)
	@touch $@

# 清理编译产物
clean:
	rm -rf $(BUILD_DIR)
	@echo "清理完成"

