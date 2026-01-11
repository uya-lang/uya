#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/parser.h"
#include "../src/lexer.h"
#include "../src/arena.h"
#include "../src/ast.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

// 测试 Parser 初始化
void test_parser_init(void) {
    printf("测试 Parser 初始化...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { return 0; }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    int result = parser_init(&parser, &lexer, &arena);
    
    assert(result == 0);
    assert(parser.lexer == &lexer);
    assert(parser.arena == &arena);
    assert(parser.current_token != NULL);
    
    printf("  ✓ Parser 初始化测试通过\n");
}

// 测试解析空程序
void test_parse_empty_program(void) {
    printf("测试解析空程序...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *program = parser_parse(&parser);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 0);
    
    printf("  ✓ 空程序解析测试通过\n");
}

// 主测试函数
int main(void) {
    printf("开始 Parser 基础框架测试...\n\n");
    
    test_parser_init();
    test_parse_empty_program();
    
    printf("\n所有测试通过！\n");
    printf("\n注意：Parser 完整实现需要分多个会话完成。\n");
    printf("当前只实现了基础框架（parser_init 和 parser_parse 的框架）。\n");
    
    return 0;
}

