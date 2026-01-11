#include "checker.h"
#include <string.h>

// 从 Arena 复制字符串
static const char *arena_strdup(Arena *arena, const char *src) {
    if (arena == NULL || src == NULL) {
        return NULL;
    }
    
    size_t len = strlen(src) + 1;
    char *result = (char *)arena_alloc(arena, len);
    if (result == NULL) {
        return NULL;
    }
    
    memcpy(result, src, len);
    return result;
}

// 哈希函数（djb2算法，用于字符串哈希）
static unsigned int hash_string(const char *str) {
    unsigned int hash = 5381;
    int c;
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c; // hash * 33 + c
    }
    return hash;
}

// 前向声明（函数表操作函数）
static Symbol *symbol_table_lookup(TypeChecker *checker, const char *name);

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

// 符号表插入函数（使用开放寻址的哈希表）
// 参数：checker - TypeChecker 指针，symbol - 要插入的符号（从 Arena 分配）
// 返回：成功返回 0，失败返回 -1
// 注意：允许同一名称的符号在不同作用域中共存（内层遮蔽外层）
//      如果符号已存在（相同名称和相同作用域级别），返回 -1
static int symbol_table_insert(TypeChecker *checker, Symbol *symbol) {
    if (checker == NULL || symbol == NULL || symbol->name == NULL) {
        return -1;
    }
    
    // 首先检查是否已存在相同名称和相同作用域级别的符号
    Symbol *existing = symbol_table_lookup(checker, symbol->name);
    if (existing != NULL && existing->scope_level == symbol->scope_level) {
        return -1;  // 符号已存在（相同作用域级别）
    }
    
    // 计算哈希值
    unsigned int hash = hash_string(symbol->name);
    unsigned int index = hash & (SYMBOL_TABLE_SIZE - 1);  // 使用位与运算（表大小必须是2的幂）
    
    // 开放寻址：查找空槽位
    for (int i = 0; i < SYMBOL_TABLE_SIZE; i++) {
        unsigned int slot = (index + i) & (SYMBOL_TABLE_SIZE - 1);
        
        if (checker->symbol_table.slots[slot] == NULL) {
            // 找到空槽位，插入符号
            checker->symbol_table.slots[slot] = symbol;
            checker->symbol_table.count++;
            return 0;
        }
    }
    
    // 哈希表已满（理论上不应该发生，因为我们有足够大的表）
    return -1;
}

// 符号表查找函数（支持作用域查找，返回最内层匹配的符号）
// 参数：checker - TypeChecker 指针，name - 符号名称
// 返回：找到的符号指针（最内层的匹配符号），未找到返回 NULL
// 注意：查找所有匹配的符号，返回作用域级别最高的（最内层的）
static Symbol *symbol_table_lookup(TypeChecker *checker, const char *name) {
    if (checker == NULL || name == NULL) {
        return NULL;
    }
    
    Symbol *found = NULL;
    int found_scope = -1;
    
    // 遍历整个符号表，查找所有匹配的符号
    // 由于使用开放寻址，同名符号可能存储在不同的位置（由于哈希冲突）
    for (int i = 0; i < SYMBOL_TABLE_SIZE; i++) {
        Symbol *symbol = checker->symbol_table.slots[i];
        
        if (symbol == NULL) {
            continue;
        }
        
        // 检查是否是目标符号
        if (strcmp(symbol->name, name) == 0) {
            // 找到匹配的符号，选择作用域级别最高的（最内层的）
            if (found == NULL || symbol->scope_level > found_scope) {
                found = symbol;
                found_scope = symbol->scope_level;
            }
        }
    }
    
    return found;
}

// 函数表插入函数（使用开放寻址的哈希表）
// 参数：checker - TypeChecker 指针，sig - 要插入的函数签名（从 Arena 分配）
// 返回：成功返回 0，失败返回 -1
// 注意：如果函数已存在，返回 -1
static int function_table_insert(TypeChecker *checker, FunctionSignature *sig) {
    if (checker == NULL || sig == NULL || sig->name == NULL) {
        return -1;
    }
    
    // 计算哈希值
    unsigned int hash = hash_string(sig->name);
    unsigned int index = hash & (FUNCTION_TABLE_SIZE - 1);
    
    // 开放寻址：查找空槽位或已存在的函数
    for (int i = 0; i < FUNCTION_TABLE_SIZE; i++) {
        unsigned int slot = (index + i) & (FUNCTION_TABLE_SIZE - 1);
        FunctionSignature *existing = checker->function_table.slots[slot];
        
        if (existing == NULL) {
            // 找到空槽位，插入函数签名
            checker->function_table.slots[slot] = sig;
            checker->function_table.count++;
            return 0;
        }
        
        // 检查是否是相同名称的函数
        if (strcmp(existing->name, sig->name) == 0) {
            // 函数已存在，返回错误
            return -1;
        }
    }
    
    // 哈希表已满（理论上不应该发生）
    return -1;
}

// 函数表查找函数
// 参数：checker - TypeChecker 指针，name - 函数名称
// 返回：找到的函数签名指针，未找到返回 NULL
static FunctionSignature *function_table_lookup(TypeChecker *checker, const char *name) {
    if (checker == NULL || name == NULL) {
        return NULL;
    }
    
    // 计算哈希值
    unsigned int hash = hash_string(name);
    unsigned int index = hash & (FUNCTION_TABLE_SIZE - 1);
    
    // 开放寻址：查找函数
    for (int i = 0; i < FUNCTION_TABLE_SIZE; i++) {
        unsigned int slot = (index + i) & (FUNCTION_TABLE_SIZE - 1);
        FunctionSignature *sig = checker->function_table.slots[slot];
        
        if (sig == NULL) {
            // 空槽位，继续查找
            continue;
        }
        
        // 检查是否是目标函数
        if (strcmp(sig->name, name) == 0) {
            return sig;
        }
    }
    
    return NULL;  // 未找到
}

// 进入作用域（增加作用域级别）
// 参数：checker - TypeChecker 指针
static void checker_enter_scope(TypeChecker *checker) {
    if (checker != NULL) {
        checker->scope_level++;
    }
}

// 退出作用域（减少作用域级别，并移除该作用域的符号）
// 参数：checker - TypeChecker 指针
// 注意：退出作用域时，移除当前作用域级别的所有符号
// 注意：在开放寻址哈希表中删除元素会导致查找链断裂，但我们的使用场景中，
//      退出作用域时删除符号是必要的，因此遍历整个表进行删除
static void checker_exit_scope(TypeChecker *checker) {
    if (checker == NULL || checker->scope_level <= 0) {
        return;
    }
    
    int current_scope = checker->scope_level;
    
    // 移除当前作用域级别的所有符号
    // 注意：在开放寻址哈希表中，删除元素会导致查找链断裂，但我们的使用场景中，
    //      符号表主要用于类型检查阶段，退出作用域后不会再查找已删除的符号
    for (int i = 0; i < SYMBOL_TABLE_SIZE; i++) {
        Symbol *symbol = checker->symbol_table.slots[i];
        if (symbol != NULL && symbol->scope_level == current_scope) {
            checker->symbol_table.slots[i] = NULL;
            checker->symbol_table.count--;
        }
    }
    
    checker->scope_level--;
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

