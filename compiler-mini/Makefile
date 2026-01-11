# Uya Mini 编译器 Makefile
# 使用 C99 标准，无堆分配，使用 Arena 分配器

CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -g
INCLUDES = -Isrc

# 源文件
SRC_DIR = src
TEST_DIR = tests

# 测试目标
ARENA_TEST = tests/test_arena
ARENA_TEST_SRC = tests/test_arena.c src/arena.c
AST_TEST = tests/test_ast
AST_TEST_SRC = tests/test_ast.c src/ast.c src/arena.c
LEXER_TEST = tests/test_lexer
LEXER_TEST_SRC = tests/test_lexer.c src/lexer.c src/arena.c
PARSER_TEST = tests/test_parser
PARSER_TEST_SRC = tests/test_parser.c src/parser.c src/lexer.c src/ast.c src/arena.c
CHECKER_TEST = tests/test_checker
CHECKER_TEST_SRC = tests/test_checker.c src/checker.c src/parser.c src/lexer.c src/ast.c src/arena.c
CODEGEN_TEST = tests/test_codegen
CODEGEN_TEST_SRC = tests/test_codegen.c src/codegen.c src/checker.c src/parser.c src/lexer.c src/ast.c src/arena.c

# 主程序目标
TARGET = compiler-mini
MAIN_SRC = src/main.c src/codegen.c src/checker.c src/parser.c src/lexer.c src/ast.c src/arena.c

# LLVM 库链接选项
# 使用 llvm-config 获取编译和链接选项（如果可用）
LLVM_CONFIG ?= llvm-config
LLVM_CFLAGS = $(shell $(LLVM_CONFIG) --cflags 2>/dev/null || echo "")
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --ldflags 2>/dev/null || echo "")
LLVM_LIBS = $(shell $(LLVM_CONFIG) --libs core target 2>/dev/null || echo "-llvm")

.PHONY: all build test clean test-arena test-ast test-lexer test-parser test-checker test-codegen

# 默认目标
all: build

# 构建所有目标（主程序）
build: $(TARGET)
	@echo "构建完成: $(TARGET)"

# 编译主程序（需要链接 LLVM 库）
$(TARGET): $(MAIN_SRC)
	$(CC) $(CFLAGS) $(LLVM_CFLAGS) $(INCLUDES) -o $@ $^ $(LLVM_LDFLAGS) $(LLVM_LIBS)

# 运行所有测试
test: test-arena test-ast test-lexer test-parser test-checker test-codegen
	@echo "所有测试完成"

# Arena 分配器测试
test-arena: $(ARENA_TEST)
	@echo "运行 Arena 分配器测试..."
	./$(ARENA_TEST)

# 编译 Arena 测试
$(ARENA_TEST): $(ARENA_TEST_SRC)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# AST 测试
test-ast: $(AST_TEST)
	@echo "运行 AST 节点创建测试..."
	./$(AST_TEST)

# 编译 AST 测试
$(AST_TEST): $(AST_TEST_SRC)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# Lexer 测试
test-lexer: $(LEXER_TEST)
	@echo "运行 Lexer 测试..."
	./$(LEXER_TEST)

# 编译 Lexer 测试
$(LEXER_TEST): $(LEXER_TEST_SRC)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# Parser 测试
test-parser: $(PARSER_TEST)
	@echo "运行 Parser 基础框架测试..."
	./$(PARSER_TEST)

# 编译 Parser 测试
$(PARSER_TEST): $(PARSER_TEST_SRC)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# Checker 测试
test-checker: $(CHECKER_TEST)
	@echo "运行 Checker 测试..."
	./$(CHECKER_TEST)

# 编译 Checker 测试
$(CHECKER_TEST): $(CHECKER_TEST_SRC)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# CodeGen 测试
test-codegen: $(CODEGEN_TEST)
	@echo "运行 CodeGen 测试..."
	./$(CODEGEN_TEST)

# 编译 CodeGen 测试（需要链接 LLVM 库）
$(CODEGEN_TEST): $(CODEGEN_TEST_SRC)
	$(CC) $(CFLAGS) $(LLVM_CFLAGS) $(INCLUDES) -o $@ $^ $(LLVM_LDFLAGS) $(LLVM_LIBS)

# 清理编译产物
clean:
	rm -f $(ARENA_TEST) $(AST_TEST) $(LEXER_TEST) $(PARSER_TEST) $(CHECKER_TEST) $(CODEGEN_TEST) $(TARGET)
	@echo "清理完成"

