# Uya to C99 Compiler Makefile

CC = gcc
CFLAGS = -std=c99 -Wall -Wextra -pedantic -O2
SRCDIR = src
SOURCES = $(SRCDIR)/main.c \
          $(SRCDIR)/lexer/lexer.c \
          $(SRCDIR)/parser/ast.c \
          $(SRCDIR)/parser/parser_core.c \
          $(SRCDIR)/parser/parser_type.c \
          $(SRCDIR)/parser/parser_expression.c \
          $(SRCDIR)/parser/parser_match.c \
          $(SRCDIR)/parser/parser_statement.c \
          $(SRCDIR)/parser/parser_declaration.c \
          $(SRCDIR)/parser/parser_string_interp.c \
          $(SRCDIR)/checker/typechecker.c \
          $(SRCDIR)/checker/constraints.c \
          $(SRCDIR)/checker/const_eval.c \
          $(SRCDIR)/ir/ir.c \
          $(SRCDIR)/ir_generator.c \
          $(SRCDIR)/ir_generator/ir_generator_type.c \
          $(SRCDIR)/ir_generator/ir_generator_expr.c \
          $(SRCDIR)/ir_generator/ir_generator_stmt.c \
          $(SRCDIR)/ir_generator/ir_generator_func.c \
          $(SRCDIR)/codegen/codegen.c \
          $(SRCDIR)/codegen/codegen_error.c \
          $(SRCDIR)/codegen/codegen_type.c \
          $(SRCDIR)/codegen/codegen_value.c \
          $(SRCDIR)/codegen/codegen_inst.c \
          $(SRCDIR)/codegen/codegen_main.c
OBJECTS = $(SOURCES:.c=.o)
TARGET = uyac

# 默认目标
all: $(TARGET)

# 链接目标
$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(TARGET)

# 编译源文件
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# 依赖关系
$(SRCDIR)/main.o: $(SRCDIR)/lexer/lexer.h $(SRCDIR)/parser/ast.h $(SRCDIR)/ir/ir.h $(SRCDIR)/codegen/codegen.h
$(SRCDIR)/lexer/lexer.o: $(SRCDIR)/lexer/lexer.h
$(SRCDIR)/parser/ast.o: $(SRCDIR)/parser/ast.h
$(SRCDIR)/ir/ir.o: $(SRCDIR)/ir/ir.h
$(SRCDIR)/codegen/codegen.o: $(SRCDIR)/codegen/codegen.h $(SRCDIR)/codegen/codegen_error.h $(SRCDIR)/codegen/codegen_type.h $(SRCDIR)/codegen/codegen_value.h $(SRCDIR)/codegen/codegen_inst.h $(SRCDIR)/ir/ir.h
$(SRCDIR)/codegen/codegen_error.o: $(SRCDIR)/codegen/codegen_error.h $(SRCDIR)/codegen/codegen.h $(SRCDIR)/ir/ir.h
$(SRCDIR)/codegen/codegen_type.o: $(SRCDIR)/codegen/codegen_type.h $(SRCDIR)/codegen/codegen.h $(SRCDIR)/ir/ir.h
$(SRCDIR)/codegen/codegen_value.o: $(SRCDIR)/codegen/codegen_value.h $(SRCDIR)/codegen/codegen.h $(SRCDIR)/ir/ir.h
$(SRCDIR)/codegen/codegen_inst.o: $(SRCDIR)/codegen/codegen_inst.h $(SRCDIR)/codegen/codegen.h $(SRCDIR)/codegen/codegen_error.h $(SRCDIR)/codegen/codegen_type.h $(SRCDIR)/codegen/codegen_value.h $(SRCDIR)/ir/ir.h
$(SRCDIR)/codegen/codegen_main.o: $(SRCDIR)/codegen/codegen.h $(SRCDIR)/codegen/codegen_error.h $(SRCDIR)/codegen/codegen_type.h $(SRCDIR)/codegen/codegen_value.h $(SRCDIR)/codegen/codegen_inst.h $(SRCDIR)/ir/ir.h

# 清理
clean:
	rm -f $(OBJECTS) $(TARGET)

# 重新构建
rebuild: clean all

# 安装
install: $(TARGET)
	cp $(TARGET) /usr/local/bin/

# 测试
test:
	@echo "Testing compiler..."
	@./$(TARGET) test.uya test.c || echo "Compilation failed"
	@echo "Test completed"

.PHONY: all clean rebuild install test