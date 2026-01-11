#include "checker.h"
#include <string.h>

// 哈希函数（djb2算法，用于字符串哈希）
static unsigned int hash_string(const char *str) {
    unsigned int hash = 5381;
    int c;
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c; // hash * 33 + c
    }
    return hash;
}

// 初始化 TypeChecker
int checker_init(TypeChecker *checker, Arena *arena) {
    if (checker == NULL || arena == NULL) {
        return -1;
    }
    
    checker->arena = arena;
    
    // 初始化符号表（所有槽位设为NULL）
    for (int i = 0; i < SYMBOL_TABLE_SIZE; i++) {
        checker->symbol_table.slots[i] = NULL;
    }
    checker->symbol_table.count = 0;
    
    // 初始化函数表（所有槽位设为NULL）
    for (int i = 0; i < FUNCTION_TABLE_SIZE; i++) {
        checker->function_table.slots[i] = NULL;
    }
    checker->function_table.count = 0;
    
    checker->scope_level = 0;
    checker->program_node = NULL;
    checker->error_count = 0;
    
    return 0;
}

// 获取错误计数
int checker_get_error_count(TypeChecker *checker) {
    if (checker == NULL) {
        return 0;
    }
    return checker->error_count;
}

// 类型检查主函数（基础框架，待实现）
int checker_check(TypeChecker *checker, ASTNode *ast) {
    if (checker == NULL || ast == NULL) {
        return -1;
    }
    
    checker->program_node = ast;
    
    // TODO: 实现类型检查逻辑
    
    return 0;
}

