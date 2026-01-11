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

// 测试解析函数声明
void test_parse_function(void) {
    printf("测试解析函数声明...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn add(a: i32, b: i32) i32 { }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(strcmp(fn->data.fn_decl.name, "add") == 0);
    assert(fn->data.fn_decl.param_count == 2);
    assert(fn->data.fn_decl.return_type != NULL);
    assert(strcmp(fn->data.fn_decl.return_type->data.type_named.name, "i32") == 0);
    assert(fn->data.fn_decl.body != NULL);
    assert(fn->data.fn_decl.body->type == AST_BLOCK);
    
    // 检查参数
    assert(fn->data.fn_decl.params != NULL);
    assert(fn->data.fn_decl.params[0]->type == AST_VAR_DECL);
    assert(strcmp(fn->data.fn_decl.params[0]->data.var_decl.name, "a") == 0);
    assert(fn->data.fn_decl.params[1]->type == AST_VAR_DECL);
    assert(strcmp(fn->data.fn_decl.params[1]->data.var_decl.name, "b") == 0);
    
    printf("  ✓ 函数声明解析测试通过\n");
}

// 测试解析无参函数
void test_parse_function_no_params(void) {
    printf("测试解析无参函数...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "fn main() i32 { }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *fn = parser_parse_function(&parser);
    assert(fn != NULL);
    assert(fn->type == AST_FN_DECL);
    assert(strcmp(fn->data.fn_decl.name, "main") == 0);
    assert(fn->data.fn_decl.param_count == 0);
    
    printf("  ✓ 无参函数解析测试通过\n");
}

// 测试解析结构体声明
void test_parse_struct(void) {
    printf("测试解析结构体声明...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "struct Point { x: i32, y: i32 }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *struct_decl = parser_parse_struct(&parser);
    assert(struct_decl != NULL);
    assert(struct_decl->type == AST_STRUCT_DECL);
    assert(strcmp(struct_decl->data.struct_decl.name, "Point") == 0);
    assert(struct_decl->data.struct_decl.field_count == 2);
    
    // 检查字段
    assert(struct_decl->data.struct_decl.fields != NULL);
    assert(struct_decl->data.struct_decl.fields[0]->type == AST_VAR_DECL);
    assert(strcmp(struct_decl->data.struct_decl.fields[0]->data.var_decl.name, "x") == 0);
    assert(struct_decl->data.struct_decl.fields[1]->type == AST_VAR_DECL);
    assert(strcmp(struct_decl->data.struct_decl.fields[1]->data.var_decl.name, "y") == 0);
    
    printf("  ✓ 结构体声明解析测试通过\n");
}

// 测试解析程序（包含函数和结构体）
void test_parse_program_with_declarations(void) {
    printf("测试解析程序（包含函数和结构体）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    Lexer lexer;
    const char *source = "struct Point { x: i32, y: i32 } fn main() i32 { }";
    lexer_init(&lexer, source, strlen(source), "test.uya", &arena);
    
    Parser parser;
    parser_init(&parser, &lexer, &arena);
    
    ASTNode *program = parser_parse(&parser);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 2);
    
    // 检查第一个声明（结构体）
    assert(program->data.program.decls[0]->type == AST_STRUCT_DECL);
    assert(strcmp(program->data.program.decls[0]->data.struct_decl.name, "Point") == 0);
    
    // 检查第二个声明（函数）
    assert(program->data.program.decls[1]->type == AST_FN_DECL);
    assert(strcmp(program->data.program.decls[1]->data.fn_decl.name, "main") == 0);
    
    printf("  ✓ 程序解析测试通过\n");
}

// 主测试函数
int main(void) {
    printf("开始 Parser 测试...\n\n");
    
    test_parser_init();
    test_parse_empty_program();
    test_parse_function();
    test_parse_function_no_params();
    test_parse_struct();
    test_parse_program_with_declarations();
    
    printf("\n所有测试通过！\n");
    
    return 0;
}

