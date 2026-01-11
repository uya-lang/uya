#include "checker.h"
#include "lexer.h"
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

// 前向声明
static Symbol *symbol_table_lookup(TypeChecker *checker, const char *name);
static int type_equals(Type t1, Type t2);
static Type type_from_ast(TypeChecker *checker, ASTNode *type_node);
static Type checker_infer_type(TypeChecker *checker, ASTNode *expr);
static int symbol_table_insert(TypeChecker *checker, Symbol *symbol);
static int function_table_insert(TypeChecker *checker, FunctionSignature *sig);
static FunctionSignature *function_table_lookup(TypeChecker *checker, const char *name);
static void checker_enter_scope(TypeChecker *checker);
static void checker_exit_scope(TypeChecker *checker);
static int checker_check_node(TypeChecker *checker, ASTNode *node);

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

// 类型比较函数（比较两个Type是否相等）
// 参数：t1, t2 - 要比较的两个类型
// 返回：1 表示相等，0 表示不相等
// 注意：结构体类型通过名称比较
static int type_equals(Type t1, Type t2) {
    // 类型种类必须相同
    if (t1.kind != t2.kind) {
        return 0;
    }
    
    // 对于结构体类型，需要比较结构体名称
    if (t1.kind == TYPE_STRUCT) {
        // 如果两个结构体名称都为NULL，则相等
        if (t1.struct_name == NULL && t2.struct_name == NULL) {
            return 1;
        }
        // 如果只有一个为NULL，则不相等
        if (t1.struct_name == NULL || t2.struct_name == NULL) {
            return 0;
        }
        // 比较结构体名称
        return strcmp(t1.struct_name, t2.struct_name) == 0;
    }
    
    // 对于其他类型（i32, bool, void），种类相同即相等
    return 1;
}

// 从AST类型节点创建Type结构
// 参数：checker - TypeChecker 指针，type_node - AST类型节点
// 返回：Type结构，如果类型节点无效返回TYPE_VOID类型
// 注意：结构体类型名称需要从program_node中查找结构体声明
static Type type_from_ast(TypeChecker *checker, ASTNode *type_node) {
    Type result;
    (void)checker;  // 暂时未使用，避免警告（将来可能用于查找结构体声明）
    
    // 如果类型节点为NULL，返回void类型
    if (type_node == NULL || type_node->type != AST_TYPE_NAMED) {
        result.kind = TYPE_VOID;
        result.struct_name = NULL;
        return result;
    }
    
    const char *type_name = type_node->data.type_named.name;
    if (type_name == NULL) {
        result.kind = TYPE_VOID;
        result.struct_name = NULL;
        return result;
    }
    
    // 根据类型名称确定类型种类
    if (strcmp(type_name, "i32") == 0) {
        result.kind = TYPE_I32;
        result.struct_name = NULL;
    } else if (strcmp(type_name, "bool") == 0) {
        result.kind = TYPE_BOOL;
        result.struct_name = NULL;
    } else if (strcmp(type_name, "void") == 0) {
        result.kind = TYPE_VOID;
        result.struct_name = NULL;
    } else {
        // 其他名称视为结构体类型
        result.kind = TYPE_STRUCT;
        // 结构体名称需要存储在Arena中（类型节点中的名称已经在Arena中）
        result.struct_name = type_name;
    }
    
    return result;
}

// 表达式类型推断函数（从表达式AST节点推断类型）
// 参数：checker - TypeChecker 指针，expr - 表达式AST节点
// 返回：Type结构，如果无法推断返回TYPE_VOID类型
// 注意：这是简化版本，完整的类型推断需要类型检查上下文
static Type checker_infer_type(TypeChecker *checker, ASTNode *expr) {
    Type result;
    
    if (checker == NULL || expr == NULL) {
        result.kind = TYPE_VOID;
        result.struct_name = NULL;
        return result;
    }
    
    switch (expr->type) {
        case AST_NUMBER:
            // 数字字面量类型为i32
            result.kind = TYPE_I32;
            result.struct_name = NULL;
            return result;
            
        case AST_BOOL:
            // 布尔字面量类型为bool
            result.kind = TYPE_BOOL;
            result.struct_name = NULL;
            return result;
            
        case AST_IDENTIFIER: {
            // 标识符类型需要从符号表中查找
            Symbol *symbol = symbol_table_lookup(checker, expr->data.identifier.name);
            if (symbol != NULL) {
                return symbol->type;
            }
            // 如果找不到符号，返回void类型（错误将在类型检查时报告）
            result.kind = TYPE_VOID;
            result.struct_name = NULL;
            return result;
        }
        
        case AST_UNARY_EXPR: {
            // 一元表达式：根据运算符推断类型
            int op = expr->data.unary_expr.op;
            Type operand_type = checker_infer_type(checker, expr->data.unary_expr.operand);
            
            if (op == TOKEN_EXCLAMATION) {
                // 逻辑非（!）返回bool类型
                result.kind = TYPE_BOOL;
                result.struct_name = NULL;
                return result;
            } else if (op == TOKEN_MINUS) {
                // 一元负号（-）返回操作数类型（应为i32）
                return operand_type;
            }
            
            // 其他一元运算符，返回操作数类型
            return operand_type;
        }
        
        case AST_BINARY_EXPR: {
            // 二元表达式：根据运算符推断类型
            int op = expr->data.binary_expr.op;
            
            // 比较运算符和逻辑运算符返回bool类型
            if (op == TOKEN_EQUAL || op == TOKEN_NOT_EQUAL ||
                op == TOKEN_LESS || op == TOKEN_GREATER ||
                op == TOKEN_LESS_EQUAL || op == TOKEN_GREATER_EQUAL ||
                op == TOKEN_LOGICAL_AND || op == TOKEN_LOGICAL_OR) {
                result.kind = TYPE_BOOL;
                result.struct_name = NULL;
                return result;
            }
            
            // 算术运算符返回左操作数的类型（假设左右操作数类型相同）
            Type left_type = checker_infer_type(checker, expr->data.binary_expr.left);
            return left_type;
        }
        
        case AST_CALL_EXPR: {
            // 函数调用：返回函数的返回类型
            ASTNode *callee = expr->data.call_expr.callee;
            if (callee == NULL || callee->type != AST_IDENTIFIER) {
                result.kind = TYPE_VOID;
                result.struct_name = NULL;
                return result;
            }
            
            FunctionSignature *sig = function_table_lookup(checker, callee->data.identifier.name);
            if (sig != NULL) {
                return sig->return_type;
            }
            
            // 如果找不到函数，返回void类型（错误将在类型检查时报告）
            result.kind = TYPE_VOID;
            result.struct_name = NULL;
            return result;
        }
        
        case AST_MEMBER_ACCESS: {
            // 字段访问：需要推断对象类型，然后查找字段类型
            // 这是简化版本，完整实现需要在类型检查时查找结构体定义
            // TODO: 从结构体定义中查找字段类型
            // 暂时返回void类型，完整实现将在类型检查时处理
            (void)checker;  // 暂时未使用，避免警告
            result.kind = TYPE_VOID;
            result.struct_name = NULL;
            return result;
        }
        
        case AST_STRUCT_INIT: {
            // 结构体字面量：返回结构体类型
            result.kind = TYPE_STRUCT;
            // 结构体名称需要存储在Arena中（从AST节点获取的名称已经在Arena中）
            result.struct_name = expr->data.struct_init.struct_name;
            return result;
        }
        
        default:
            // 其他表达式类型，返回void类型
            result.kind = TYPE_VOID;
            result.struct_name = NULL;
            return result;
    }
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

