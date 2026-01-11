#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/codegen.h"
#include "../src/arena.h"
#include "../src/checker.h"
#include "../src/parser.h"
#include "../src/lexer.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

// 辅助函数：解析源代码并返回AST
static ASTNode *parse_source(const char *source, Arena *arena) {
    Lexer lexer;
    lexer_init(&lexer, source, strlen(source), "test.uya", arena);
    
    Parser parser;
    parser_init(&parser, &lexer, arena);
    
    return parser_parse(&parser);
}

// 测试 CodeGenerator 初始化
void test_codegen_new(void) {
    printf("测试 CodeGenerator 初始化...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    
    assert(result == 0);
    assert(codegen.arena == &arena);
    assert(codegen.context != NULL);
    assert(codegen.module != NULL);
    assert(codegen.builder != NULL);
    assert(codegen.module_name != NULL);
    assert(strcmp(codegen.module_name, "test_module") == 0);
    assert(codegen.struct_type_count == 0);
    
    printf("  ✓ CodeGenerator 初始化测试通过\n");
}

// 测试基础类型映射 - i32
void test_codegen_get_base_type_i32(void) {
    printf("测试基础类型映射 - i32...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    LLVMTypeRef i32_type = codegen_get_base_type(&codegen, TYPE_I32);
    assert(i32_type != NULL);
    
    // 验证类型是否正确（LLVMInt32Type）
    // 注意：我们无法直接比较类型引用，但可以验证不为NULL
    printf("  ✓ i32 类型映射测试通过\n");
}

// 测试基础类型映射 - bool
void test_codegen_get_base_type_bool(void) {
    printf("测试基础类型映射 - bool...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    LLVMTypeRef bool_type = codegen_get_base_type(&codegen, TYPE_BOOL);
    assert(bool_type != NULL);
    
    printf("  ✓ bool 类型映射测试通过\n");
}

// 测试基础类型映射 - void
void test_codegen_get_base_type_void(void) {
    printf("测试基础类型映射 - void...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    LLVMTypeRef void_type = codegen_get_base_type(&codegen, TYPE_VOID);
    assert(void_type != NULL);
    
    printf("  ✓ void 类型映射测试通过\n");
}

// 测试基础类型映射 - 结构体类型（应该返回NULL）
void test_codegen_get_base_type_struct(void) {
    printf("测试基础类型映射 - 结构体类型（应该返回NULL）...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    LLVMTypeRef struct_type = codegen_get_base_type(&codegen, TYPE_STRUCT);
    assert(struct_type == NULL);  // 结构体类型不应使用此函数
    
    printf("  ✓ 结构体类型映射测试通过（正确返回NULL）\n");
}

// 测试错误情况 - NULL指针
void test_codegen_new_null_pointers(void) {
    printf("测试错误情况 - NULL指针...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    
    // 测试 codegen 为 NULL
    int result = codegen_new(NULL, &arena, "test_module");
    assert(result != 0);
    
    // 测试 arena 为 NULL
    result = codegen_new(&codegen, NULL, "test_module");
    assert(result != 0);
    
    // 测试 module_name 为 NULL
    result = codegen_new(&codegen, &arena, NULL);
    assert(result != 0);
    
    printf("  ✓ NULL指针错误处理测试通过\n");
}

// 测试结构体类型注册和查找 - 简单结构体
void test_codegen_register_struct_type_simple(void) {
    printf("测试结构体类型注册和查找 - 简单结构体...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    // 解析包含结构体声明的源代码
    const char *source = "struct Point { x: i32, y: i32 }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    assert(program->type == AST_PROGRAM);
    assert(program->data.program.decl_count == 1);
    
    ASTNode *struct_decl = program->data.program.decls[0];
    assert(struct_decl != NULL);
    assert(struct_decl->type == AST_STRUCT_DECL);
    
    // 注册结构体类型
    result = codegen_register_struct_type(&codegen, struct_decl);
    assert(result == 0);
    
    // 查找结构体类型
    LLVMTypeRef point_type = codegen_get_struct_type(&codegen, "Point");
    assert(point_type != NULL);
    
    printf("  ✓ 简单结构体类型注册和查找测试通过\n");
}

// 测试结构体类型注册 - 空结构体
void test_codegen_register_struct_type_empty(void) {
    printf("测试结构体类型注册 - 空结构体...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    // 解析空结构体声明
    const char *source = "struct Empty { }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    ASTNode *struct_decl = program->data.program.decls[0];
    assert(struct_decl != NULL);
    assert(struct_decl->type == AST_STRUCT_DECL);
    
    // 注册空结构体类型
    result = codegen_register_struct_type(&codegen, struct_decl);
    assert(result == 0);
    
    // 查找结构体类型
    LLVMTypeRef empty_type = codegen_get_struct_type(&codegen, "Empty");
    assert(empty_type != NULL);
    
    printf("  ✓ 空结构体类型注册测试通过\n");
}

// 测试结构体类型查找 - 不存在的结构体
void test_codegen_get_struct_type_not_found(void) {
    printf("测试结构体类型查找 - 不存在的结构体...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    // 查找不存在的结构体类型
    LLVMTypeRef not_found_type = codegen_get_struct_type(&codegen, "NonExistent");
    assert(not_found_type == NULL);
    
    printf("  ✓ 不存在的结构体类型查找测试通过（正确返回NULL）\n");
}

// 测试结构体类型注册 - 重复注册
void test_codegen_register_struct_type_duplicate(void) {
    printf("测试结构体类型注册 - 重复注册...\n");
    
    Arena arena;
    arena_init(&arena, test_buffer, TEST_BUFFER_SIZE);
    
    CodeGenerator codegen;
    int result = codegen_new(&codegen, &arena, "test_module");
    assert(result == 0);
    
    // 解析结构体声明
    const char *source = "struct Point { x: i32, y: i32 }";
    ASTNode *program = parse_source(source, &arena);
    assert(program != NULL);
    
    ASTNode *struct_decl = program->data.program.decls[0];
    assert(struct_decl != NULL);
    
    // 第一次注册
    result = codegen_register_struct_type(&codegen, struct_decl);
    assert(result == 0);
    
    // 第二次注册（应该成功，不重复注册）
    result = codegen_register_struct_type(&codegen, struct_decl);
    assert(result == 0);
    
    // 验证类型仍然可用
    LLVMTypeRef point_type = codegen_get_struct_type(&codegen, "Point");
    assert(point_type != NULL);
    
    printf("  ✓ 重复注册结构体类型测试通过\n");
}

// 主函数
int main(void) {
    printf("开始运行 CodeGen 测试...\n\n");
    
    test_codegen_new();
    test_codegen_get_base_type_i32();
    test_codegen_get_base_type_bool();
    test_codegen_get_base_type_void();
    test_codegen_get_base_type_struct();
    test_codegen_new_null_pointers();
    test_codegen_register_struct_type_simple();
    test_codegen_register_struct_type_empty();
    test_codegen_get_struct_type_not_found();
    test_codegen_register_struct_type_duplicate();
    
    printf("\n所有 CodeGen 测试通过！\n");
    return 0;
}

