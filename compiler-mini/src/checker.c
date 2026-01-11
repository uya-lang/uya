#include "checker.h"
#include "lexer.h"
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
static ASTNode *find_struct_decl_from_program(ASTNode *program_node, const char *struct_name);
static Type find_struct_field_type(ASTNode *struct_decl, const char *field_name);

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
// 注意：禁止变量遮蔽，内层作用域不能声明与外层作用域同名的变量（应在类型检查时验证）
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
            // 字段访问：推断对象类型，然后查找字段类型
            Type object_type = checker_infer_type(checker, expr->data.member_access.object);
            if (object_type.kind != TYPE_STRUCT || object_type.struct_name == NULL) {
                // 对象类型不是结构体，返回void类型
                result.kind = TYPE_VOID;
                result.struct_name = NULL;
                return result;
            }
            
            // 查找结构体声明
            ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, object_type.struct_name);
            if (struct_decl == NULL) {
                // 结构体声明未找到，返回void类型
            result.kind = TYPE_VOID;
            result.struct_name = NULL;
            return result;
            }
            
            // 查找字段类型
            Type field_type = find_struct_field_type(struct_decl, expr->data.member_access.field_name);
            return field_type;  // 如果字段不存在，field_type.kind 为 TYPE_VOID
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

// 从程序节点中查找结构体声明
// 参数：program_node - 程序节点，struct_name - 结构体名称
// 返回：找到的结构体声明节点指针，未找到返回 NULL
static ASTNode *find_struct_decl_from_program(ASTNode *program_node, const char *struct_name) {
    if (program_node == NULL || program_node->type != AST_PROGRAM || struct_name == NULL) {
        return NULL;
    }
    
    for (int i = 0; i < program_node->data.program.decl_count; i++) {
        ASTNode *decl = program_node->data.program.decls[i];
        if (decl != NULL && decl->type == AST_STRUCT_DECL) {
            if (decl->data.struct_decl.name != NULL && 
                strcmp(decl->data.struct_decl.name, struct_name) == 0) {
                return decl;
            }
        }
    }
    
    return NULL;
}

// 报告类型错误（增加错误计数）
// 参数：checker - TypeChecker 指针
static void checker_report_error(TypeChecker *checker) {
    if (checker != NULL) {
        checker->error_count++;
    }
}

// 检查表达式类型是否匹配预期类型
// 参数：checker - TypeChecker 指针，expr - 表达式节点，expected_type - 预期类型
// 返回：1 表示类型匹配，0 表示类型不匹配
static int checker_check_expr_type(TypeChecker *checker, ASTNode *expr, Type expected_type) {
    if (checker == NULL || expr == NULL) {
        return 0;
    }
    
    Type actual_type = checker_infer_type(checker, expr);
    if (type_equals(actual_type, expected_type)) {
        return 1;
    }
    
    // 类型不匹配，报告错误
    checker_report_error(checker);
    return 0;
}

// 在结构体声明中查找字段
// 参数：struct_decl - 结构体声明节点，field_name - 字段名称
// 返回：找到的字段类型，未找到返回TYPE_VOID类型
static Type find_struct_field_type(ASTNode *struct_decl, const char *field_name) {
    Type result;
    result.kind = TYPE_VOID;
    result.struct_name = NULL;
    
    if (struct_decl == NULL || struct_decl->type != AST_STRUCT_DECL || field_name == NULL) {
        return result;
    }
    
    for (int i = 0; i < struct_decl->data.struct_decl.field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (field != NULL && field->type == AST_VAR_DECL) {
            if (field->data.var_decl.name != NULL && 
                strcmp(field->data.var_decl.name, field_name) == 0) {
                // 找到字段，返回字段类型
                return type_from_ast(NULL, field->data.var_decl.type);
            }
        }
    }
    
    return result;
}

// 检查变量声明
// 参数：checker - TypeChecker 指针，node - 变量声明节点
// 返回：1 表示检查通过，0 表示检查失败
static int checker_check_var_decl(TypeChecker *checker, ASTNode *node) {
    if (checker == NULL || node == NULL || node->type != AST_VAR_DECL) {
        return 0;
    }
    
    // 获取变量类型
    Type var_type = type_from_ast(checker, node->data.var_decl.type);
    if (var_type.kind == TYPE_VOID && node->data.var_decl.type != NULL) {
        // 结构体类型需要在程序节点中查找
        if (node->data.var_decl.type->type == AST_TYPE_NAMED) {
            const char *type_name = node->data.var_decl.type->data.type_named.name;
            if (type_name != NULL && strcmp(type_name, "i32") != 0 && 
                strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0) {
                // 可能是结构体类型，检查是否存在
                ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, type_name);
                if (struct_decl == NULL) {
                    // 结构体类型未定义
                    checker_report_error(checker);
                    return 0;
                }
                var_type.kind = TYPE_STRUCT;
                var_type.struct_name = type_name;
            }
        }
    }
    
    // 检查初始化表达式类型
    if (node->data.var_decl.init != NULL) {
        // 先递归检查初始化表达式本身（包括函数调用、运算符等的类型检查）
        checker_check_node(checker, node->data.var_decl.init);
        // 然后推断类型并比较
        Type init_type = checker_infer_type(checker, node->data.var_decl.init);
        if (!type_equals(init_type, var_type)) {
            // 初始化表达式类型不匹配
            checker_report_error(checker);
            return 0;
        }
    }
    
    // 将变量添加到符号表
    Symbol *symbol = (Symbol *)arena_alloc(checker->arena, sizeof(Symbol));
    if (symbol == NULL) {
        return 0;
    }
    symbol->name = node->data.var_decl.name;
    symbol->type = var_type;
    symbol->is_const = node->data.var_decl.is_const;
    symbol->scope_level = checker->scope_level;
    symbol->line = node->line;
    symbol->column = node->column;
    
    if (symbol_table_insert(checker, symbol) != 0) {
        // 符号插入失败（可能是重复定义）
        checker_report_error(checker);
        return 0;
    }
    
    return 1;
}

// 检查函数声明
// 参数：checker - TypeChecker 指针，node - 函数声明节点
// 返回：1 表示检查通过，0 表示检查失败
static int checker_check_fn_decl(TypeChecker *checker, ASTNode *node) {
    if (checker == NULL || node == NULL || node->type != AST_FN_DECL) {
        return 0;
    }
    
    // 获取返回类型
    Type return_type = type_from_ast(checker, node->data.fn_decl.return_type);
    
    // 创建函数签名
    FunctionSignature *sig = (FunctionSignature *)arena_alloc(checker->arena, sizeof(FunctionSignature));
    if (sig == NULL) {
        return 0;
    }
    sig->name = node->data.fn_decl.name;
    sig->param_count = node->data.fn_decl.param_count;
    sig->return_type = return_type;
    sig->is_extern = (node->data.fn_decl.body == NULL) ? 1 : 0;  // 如果 body 为 NULL，则是 extern 函数
    sig->line = node->line;
    sig->column = node->column;
    
    // 分配参数类型数组
    if (sig->param_count > 0) {
        sig->param_types = (Type *)arena_alloc(checker->arena, sizeof(Type) * sig->param_count);
        if (sig->param_types == NULL) {
            return 0;
        }
        
        // 填充参数类型（对所有函数都需要，包括extern函数）
        for (int i = 0; i < node->data.fn_decl.param_count; i++) {
            ASTNode *param = node->data.fn_decl.params[i];
            if (param != NULL && param->type == AST_VAR_DECL) {
                Type param_type = type_from_ast(checker, param->data.var_decl.type);
                sig->param_types[i] = param_type;
            }
        }
    } else {
        sig->param_types = NULL;
    }
    
    // 将函数添加到函数表
    if (function_table_insert(checker, sig) != 0) {
        // 函数重复定义
        checker_report_error(checker);
        return 0;
    }
    
    // 检查函数体（如果有）
    if (node->data.fn_decl.body != NULL) {
        checker_enter_scope(checker);
        
        // 将参数添加到符号表（仅用于函数体内的类型检查）
        for (int i = 0; i < node->data.fn_decl.param_count; i++) {
            ASTNode *param = node->data.fn_decl.params[i];
            if (param != NULL && param->type == AST_VAR_DECL) {
                Type param_type = type_from_ast(checker, param->data.var_decl.type);
                
                // 将参数添加到符号表
                Symbol *param_symbol = (Symbol *)arena_alloc(checker->arena, sizeof(Symbol));
                if (param_symbol != NULL) {
                    param_symbol->name = param->data.var_decl.name;
                    param_symbol->type = param_type;
                    param_symbol->is_const = 1;  // 参数是只读的
                    param_symbol->scope_level = checker->scope_level;
                    param_symbol->line = param->line;
                    param_symbol->column = param->column;
                    symbol_table_insert(checker, param_symbol);
                }
            }
        }
        
        // 检查函数体
        checker_check_node(checker, node->data.fn_decl.body);
        
        checker_exit_scope(checker);
    }
    
    return 1;
}

// 检查结构体声明
// 参数：checker - TypeChecker 指针，node - 结构体声明节点
// 返回：1 表示检查通过，0 表示检查失败
static int checker_check_struct_decl(TypeChecker *checker, ASTNode *node) {
    if (checker == NULL || node == NULL || node->type != AST_STRUCT_DECL) {
        return 0;
    }
    
    // 检查字段
    for (int i = 0; i < node->data.struct_decl.field_count; i++) {
        ASTNode *field = node->data.struct_decl.fields[i];
        if (field != NULL && field->type == AST_VAR_DECL) {
            // 检查字段类型
            Type field_type = type_from_ast(checker, field->data.var_decl.type);
            if (field_type.kind == TYPE_VOID && field->data.var_decl.type != NULL) {
                // 可能是结构体类型，检查是否存在（但结构体可能前向引用，这里暂时不检查）
                // TODO: 支持前向声明或两遍检查
            }
        }
    }
    
    return 1;
}

// 检查函数调用
// 参数：checker - TypeChecker 指针，node - 函数调用节点
// 返回：函数返回类型（如果检查失败返回TYPE_VOID）
static Type checker_check_call_expr(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    result.struct_name = NULL;
    
    if (checker == NULL || node == NULL || node->type != AST_CALL_EXPR) {
        return result;
    }
    
    // 查找被调用的函数
    ASTNode *callee = node->data.call_expr.callee;
    if (callee == NULL || callee->type != AST_IDENTIFIER) {
        checker_report_error(checker);
        return result;
    }
    
    FunctionSignature *sig = function_table_lookup(checker, callee->data.identifier.name);
    if (sig == NULL) {
        // 函数未定义
        checker_report_error(checker);
        return result;
    }
    
    // 检查参数个数
    if (node->data.call_expr.arg_count != sig->param_count) {
        checker_report_error(checker);
        return result;
    }
    
    // 检查参数类型
    for (int i = 0; i < node->data.call_expr.arg_count; i++) {
        ASTNode *arg = node->data.call_expr.args[i];
        if (arg != NULL && !checker_check_expr_type(checker, arg, sig->param_types[i])) {
            // 参数类型不匹配
            return result;
        }
    }
    
    return sig->return_type;
}

// 检查字段访问
// 参数：checker - TypeChecker 指针，node - 字段访问节点
// 返回：字段类型（如果检查失败返回TYPE_VOID）
static Type checker_check_member_access(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    result.struct_name = NULL;
    
    if (checker == NULL || node == NULL || node->type != AST_MEMBER_ACCESS) {
        return result;
    }
    
    // 获取对象类型
    Type object_type = checker_infer_type(checker, node->data.member_access.object);
    if (object_type.kind != TYPE_STRUCT || object_type.struct_name == NULL) {
        // 对象类型不是结构体
        checker_report_error(checker);
        return result;
    }
    
    // 查找结构体声明
    ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, object_type.struct_name);
    if (struct_decl == NULL) {
        checker_report_error(checker);
        return result;
    }
    
    // 查找字段类型
    Type field_type = find_struct_field_type(struct_decl, node->data.member_access.field_name);
    if (field_type.kind == TYPE_VOID) {
        // 字段不存在
        checker_report_error(checker);
        return result;
    }
    
    return field_type;
}

// 检查结构体字面量
// 参数：checker - TypeChecker 指针，node - 结构体字面量节点
// 返回：结构体类型（如果检查失败返回TYPE_VOID）
static Type checker_check_struct_init(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    result.struct_name = NULL;
    
    if (checker == NULL || node == NULL || node->type != AST_STRUCT_INIT) {
        return result;
    }
    
    const char *struct_name = node->data.struct_init.struct_name;
    if (struct_name == NULL) {
        checker_report_error(checker);
        return result;
    }
    
    // 查找结构体声明
    ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, struct_name);
    if (struct_decl == NULL) {
        checker_report_error(checker);
        return result;
    }
    
    // 检查字段数量和类型
    if (node->data.struct_init.field_count != struct_decl->data.struct_decl.field_count) {
        checker_report_error(checker);
        return result;
    }
    
    // 检查每个字段的类型
    for (int i = 0; i < node->data.struct_init.field_count; i++) {
        const char *field_name = node->data.struct_init.field_names[i];
        ASTNode *field_value = node->data.struct_init.field_values[i];
        
        Type field_type = find_struct_field_type(struct_decl, field_name);
        if (field_type.kind == TYPE_VOID) {
            checker_report_error(checker);
            return result;
        }
        
        if (!checker_check_expr_type(checker, field_value, field_type)) {
            return result;
        }
    }
    
    result.kind = TYPE_STRUCT;
    result.struct_name = struct_name;
    return result;
}

// 检查二元表达式
// 参数：checker - TypeChecker 指针，node - 二元表达式节点
// 返回：表达式类型（如果检查失败返回TYPE_VOID）
static Type checker_check_binary_expr(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    result.struct_name = NULL;
    
    if (checker == NULL || node == NULL || node->type != AST_BINARY_EXPR) {
        return result;
    }
    
    int op = node->data.binary_expr.op;
    Type left_type = checker_infer_type(checker, node->data.binary_expr.left);
    Type right_type = checker_infer_type(checker, node->data.binary_expr.right);
    
    // 算术运算符：操作数必须是i32
    if (op == TOKEN_PLUS || op == TOKEN_MINUS || op == TOKEN_ASTERISK || 
        op == TOKEN_SLASH || op == TOKEN_PERCENT) {
        if (left_type.kind != TYPE_I32 || right_type.kind != TYPE_I32) {
            checker_report_error(checker);
            return result;
        }
        result.kind = TYPE_I32;
        result.struct_name = NULL;
        return result;
    }
    
    // 比较运算符：操作数类型必须相同
    if (op == TOKEN_EQUAL || op == TOKEN_NOT_EQUAL || op == TOKEN_LESS || 
        op == TOKEN_GREATER || op == TOKEN_LESS_EQUAL || op == TOKEN_GREATER_EQUAL) {
        if (!type_equals(left_type, right_type)) {
            checker_report_error(checker);
            return result;
        }
        result.kind = TYPE_BOOL;
        result.struct_name = NULL;
        return result;
    }
    
    // 逻辑运算符：操作数必须是bool
    if (op == TOKEN_LOGICAL_AND || op == TOKEN_LOGICAL_OR) {
        if (left_type.kind != TYPE_BOOL || right_type.kind != TYPE_BOOL) {
            checker_report_error(checker);
            return result;
        }
        result.kind = TYPE_BOOL;
        result.struct_name = NULL;
        return result;
    }
    
    return result;
}

// 检查一元表达式
// 参数：checker - TypeChecker 指针，node - 一元表达式节点
// 返回：表达式类型（如果检查失败返回TYPE_VOID）
static Type checker_check_unary_expr(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    result.struct_name = NULL;
    
    if (checker == NULL || node == NULL || node->type != AST_UNARY_EXPR) {
        return result;
    }
    
    int op = node->data.unary_expr.op;
    Type operand_type = checker_infer_type(checker, node->data.unary_expr.operand);
    
    if (op == TOKEN_EXCLAMATION) {
        // 逻辑非：操作数必须是bool
        if (operand_type.kind != TYPE_BOOL) {
            checker_report_error(checker);
            return result;
        }
        result.kind = TYPE_BOOL;
        result.struct_name = NULL;
        return result;
    } else if (op == TOKEN_MINUS) {
        // 一元负号：操作数必须是i32
        if (operand_type.kind != TYPE_I32) {
            checker_report_error(checker);
            return result;
        }
        result.kind = TYPE_I32;
        result.struct_name = NULL;
        return result;
    }
    
    return result;
}

// 递归类型检查节点函数
// 参数：checker - TypeChecker 指针，node - AST节点
// 返回：1 表示检查通过，0 表示检查失败
static int checker_check_node(TypeChecker *checker, ASTNode *node) {
    if (checker == NULL || node == NULL) {
        return 0;
    }
    
    switch (node->type) {
        case AST_PROGRAM:
            // 检查所有声明
            for (int i = 0; i < node->data.program.decl_count; i++) {
                ASTNode *decl = node->data.program.decls[i];
                if (decl != NULL) {
                    checker_check_node(checker, decl);
                }
            }
            return 1;
            
        case AST_STRUCT_DECL:
            return checker_check_struct_decl(checker, node);
            
        case AST_FN_DECL:
            return checker_check_fn_decl(checker, node);
            
        case AST_VAR_DECL:
            return checker_check_var_decl(checker, node);
            
        case AST_BLOCK:
            checker_enter_scope(checker);
            for (int i = 0; i < node->data.block.stmt_count; i++) {
                ASTNode *stmt = node->data.block.stmts[i];
                if (stmt != NULL) {
                    checker_check_node(checker, stmt);
                }
            }
            checker_exit_scope(checker);
            return 1;
            
        case AST_IF_STMT: {
            // 检查条件类型（必须是bool）
            Type cond_type = checker_infer_type(checker, node->data.if_stmt.condition);
            if (cond_type.kind != TYPE_BOOL) {
                checker_report_error(checker);
            }
            // 检查then分支
            if (node->data.if_stmt.then_branch != NULL) {
                checker_check_node(checker, node->data.if_stmt.then_branch);
            }
            // 检查else分支
            if (node->data.if_stmt.else_branch != NULL) {
                checker_check_node(checker, node->data.if_stmt.else_branch);
            }
            return 1;
        }
        
        case AST_WHILE_STMT: {
            // 检查条件类型（必须是bool）
            Type cond_type = checker_infer_type(checker, node->data.while_stmt.condition);
            if (cond_type.kind != TYPE_BOOL) {
                checker_report_error(checker);
            }
            // 检查循环体
            if (node->data.while_stmt.body != NULL) {
                checker_check_node(checker, node->data.while_stmt.body);
            }
            return 1;
        }
        
        case AST_RETURN_STMT: {
            // TODO: 检查返回值类型是否匹配函数返回类型
            // 这需要在函数上下文中检查，暂时跳过
            if (node->data.return_stmt.expr != NULL) {
                checker_infer_type(checker, node->data.return_stmt.expr);
            }
            return 1;
        }
        
        case AST_ASSIGN: {
            // 检查目标是否为var（不能是const）
            ASTNode *dest = node->data.assign.dest;
            if (dest == NULL || dest->type != AST_IDENTIFIER) {
                checker_report_error(checker);
                return 0;
            }
            
            Symbol *symbol = symbol_table_lookup(checker, dest->data.identifier.name);
            if (symbol == NULL) {
                checker_report_error(checker);
                return 0;
            }
            
            if (symbol->is_const) {
                // 不能给const变量赋值
                checker_report_error(checker);
                return 0;
            }
            
            // 检查赋值类型匹配
            if (!checker_check_expr_type(checker, node->data.assign.src, symbol->type)) {
                return 0;
            }
            
            return 1;
        }
        
        case AST_EXPR_STMT: {
            // 表达式语句：表达式语句在解析时直接返回表达式节点
            // 所以AST_EXPR_STMT节点本身应该被当作表达式节点处理
            // 但由于AST_EXPR_STMT在union中没有对应的数据结构，这里直接跳过
            // 实际上，表达式语句在parser中已经作为表达式节点返回，不会到达这里
            return 1;
        }
        
        case AST_BINARY_EXPR:
            checker_check_binary_expr(checker, node);
            return 1;
            
        case AST_UNARY_EXPR:
            checker_check_unary_expr(checker, node);
            return 1;
            
        case AST_CALL_EXPR:
            checker_check_call_expr(checker, node);
            return 1;
            
        case AST_MEMBER_ACCESS:
            checker_check_member_access(checker, node);
            return 1;
            
        case AST_STRUCT_INIT:
            checker_check_struct_init(checker, node);
            return 1;
            
        case AST_IDENTIFIER:
        case AST_NUMBER:
        case AST_BOOL:
        case AST_TYPE_NAMED:
            // 这些节点类型不需要单独检查（在表达式中检查）
            return 1;
            
        default:
            return 1;
    }
}

// 类型检查主函数
int checker_check(TypeChecker *checker, ASTNode *ast) {
    if (checker == NULL || ast == NULL) {
        return -1;
    }
    
    checker->program_node = ast;
    checker->error_count = 0;
    
    // 检查程序节点
    checker_check_node(checker, ast);
    
    return 0;
}

