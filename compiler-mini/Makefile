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

.PHONY: all build test clean test-arena test-ast test-lexer test-parser

# 默认目标
all: build

# 构建所有目标
build:
	@echo "构建目标（待实现）"

# 运行所有测试
test: test-arena test-ast test-lexer test-parser
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

# 清理编译产物
clean:
	rm -f $(ARENA_TEST) $(AST_TEST) $(LEXER_TEST) $(PARSER_TEST)
	@echo "清理完成"

