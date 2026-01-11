#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "../src/codegen.h"
#include "../src/arena.h"
#include "../src/checker.h"

// 测试缓冲区大小（1MB）
#define TEST_BUFFER_SIZE (1024 * 1024)
static uint8_t test_buffer[TEST_BUFFER_SIZE];

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

// 主函数
int main(void) {
    printf("开始运行 CodeGen 测试...\n\n");
    
    test_codegen_new();
    test_codegen_get_base_type_i32();
    test_codegen_get_base_type_bool();
    test_codegen_get_base_type_void();
    test_codegen_get_base_type_struct();
    test_codegen_new_null_pointers();
    
    printf("\n所有 CodeGen 测试通过！\n");
    return 0;
}

