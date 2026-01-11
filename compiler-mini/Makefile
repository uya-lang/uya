# Uya Mini 编译器 Makefile
# 使用 C99 标准，无堆分配，使用 Arena 分配器

CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -g
INCLUDES = -Isrc

# 源文件
SRC_DIR = src
TEST_DIR = tests

# Arena 测试
ARENA_TEST = tests/test_arena
ARENA_TEST_SRC = tests/test_arena.c src/arena.c

.PHONY: all build test clean test-arena

# 默认目标
all: build

# 构建所有目标
build:
	@echo "构建目标（待实现）"

# 运行所有测试
test: test-arena
	@echo "所有测试完成"

# Arena 分配器测试
test-arena: $(ARENA_TEST)
	@echo "运行 Arena 分配器测试..."
	./$(ARENA_TEST)

# 编译 Arena 测试
$(ARENA_TEST): $(ARENA_TEST_SRC)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^

# 清理编译产物
clean:
	rm -f $(ARENA_TEST)
	@echo "清理完成"

