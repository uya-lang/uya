#include "checker.h"
#include "lexer.h"
#include <string.h>
#include <stdio.h>

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
static void checker_check_cast_expr(TypeChecker *checker, ASTNode *node);
static int checker_check_node(TypeChecker *checker, ASTNode *node);
static ASTNode *find_struct_decl_from_program(ASTNode *program_node, const char *struct_name);
static ASTNode *find_enum_decl_from_program(ASTNode *program_node, const char *enum_name);
static Type find_struct_field_type(TypeChecker *checker, ASTNode *struct_decl, const char *field_name);
static int checker_register_fn_decl(TypeChecker *checker, ASTNode *node);

// 初始化 TypeChecker
int checker_init(TypeChecker *checker, Arena *arena, const char *default_filename) {
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
    checker->loop_depth = 0;
    checker->program_node = NULL;
    checker->error_count = 0;
    checker->default_filename = default_filename;
    
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
    
    // 对于枚举类型，需要比较枚举名称
    if (t1.kind == TYPE_ENUM) {
        // 如果两个枚举名称都为NULL，则相等
        if (t1.data.enum_name == NULL && t2.data.enum_name == NULL) {
            return 1;
        }
        // 如果只有一个为NULL，则不相等
        if (t1.data.enum_name == NULL || t2.data.enum_name == NULL) {
            return 0;
        }
        // 比较枚举名称
        return strcmp(t1.data.enum_name, t2.data.enum_name) == 0;
    }
    
    // 对于结构体类型，需要比较结构体名称
    if (t1.kind == TYPE_STRUCT) {
        // 如果两个结构体名称都为NULL，则相等
        if (t1.data.struct_name == NULL && t2.data.struct_name == NULL) {
            return 1;
        }
        // 如果只有一个为NULL，则不相等
        if (t1.data.struct_name == NULL || t2.data.struct_name == NULL) {
            return 0;
        }
        // 比较结构体名称
        return strcmp(t1.data.struct_name, t2.data.struct_name) == 0;
    }
    
    // 对于指针类型，需要比较指向的类型和是否FFI指针
    if (t1.kind == TYPE_POINTER) {
        if (t1.data.pointer.is_ffi_pointer != t2.data.pointer.is_ffi_pointer) {
            return 0;
        }
        if (t1.data.pointer.pointer_to == NULL && t2.data.pointer.pointer_to == NULL) {
            return 1;
        }
        if (t1.data.pointer.pointer_to == NULL || t2.data.pointer.pointer_to == NULL) {
            return 0;
        }
        return type_equals(*t1.data.pointer.pointer_to, *t2.data.pointer.pointer_to);
    }
    
    // 对于数组类型，需要比较元素类型和大小
    if (t1.kind == TYPE_ARRAY) {
        if (t1.data.array.array_size != t2.data.array.array_size) {
            return 0;
        }
        if (t1.data.array.element_type == NULL && t2.data.array.element_type == NULL) {
            return 1;
        }
        if (t1.data.array.element_type == NULL || t2.data.array.element_type == NULL) {
            return 0;
        }
        return type_equals(*t1.data.array.element_type, *t2.data.array.element_type);
    }
    
    // 对于其他类型（i32, bool, void），种类相同即相等
    return 1;
}

// 从AST类型节点创建Type结构
// 参数：checker - TypeChecker 指针，type_node - AST类型节点
// 返回：Type结构，如果类型节点无效返回TYPE_VOID类型
// 注意：结构体类型名称需要从program_node中查找结构体声明
//      指针和数组类型的子类型从Arena分配
static Type type_from_ast(TypeChecker *checker, ASTNode *type_node) {
    Type result;
    
    // 如果类型节点为NULL，返回void类型
    if (type_node == NULL) {
        result.kind = TYPE_VOID;
        return result;
    }
    
    // 根据类型节点类型处理
    if (type_node->type == AST_TYPE_POINTER) {
        // 指针类型（&T 或 *T）
        ASTNode *pointed_type_node = type_node->data.type_pointer.pointed_type;
        if (pointed_type_node == NULL) {
            // 指向的类型节点为空
            result.kind = TYPE_VOID;
            return result;
        }
        
        // 递归解析指向的类型
        Type pointed_type = type_from_ast(checker, pointed_type_node);
        
        // 特殊处理：&void 是一个有效的指针类型（通用指针类型）
        // 当指向的类型是 void 时，pointer_to 设为 NULL 表示 void
        if (pointed_type.kind == TYPE_VOID) {
            // 检查是否是 void 类型（而不是无效类型）
            if (pointed_type_node->type == AST_TYPE_NAMED) {
                const char *type_name = pointed_type_node->data.type_named.name;
                if (type_name != NULL && strcmp(type_name, "void") == 0) {
                    // 这是 &void 类型，创建一个有效的指针类型（pointer_to 为 NULL 表示 void）
                    result.kind = TYPE_POINTER;
                    result.data.pointer.pointer_to = NULL;  // NULL 表示指向 void
                    result.data.pointer.is_ffi_pointer = type_node->data.type_pointer.is_ffi_pointer;
                    return result;
                }
            }
            // 指向的类型无效（可能是前向引用的结构体，暂时允许）
            // 注意：这里不报告错误，因为可能是结构体前向引用
            // 错误会在使用该类型时报告
            result.kind = TYPE_VOID;
            return result;
        }
        
        // 分配指向的类型结构（从Arena分配）
        Type *pointed_type_ptr = (Type *)arena_alloc(checker->arena, sizeof(Type));
        if (pointed_type_ptr == NULL) {
            // Arena 分配失败
            result.kind = TYPE_VOID;
            return result;
        }
        *pointed_type_ptr = pointed_type;
        
        // 创建指针类型
        result.kind = TYPE_POINTER;
        result.data.pointer.pointer_to = pointed_type_ptr;
        result.data.pointer.is_ffi_pointer = type_node->data.type_pointer.is_ffi_pointer;
        
        return result;
    } else if (type_node->type == AST_TYPE_ARRAY) {
        // 数组类型（[T: N]）
        // 递归解析元素类型
        Type element_type = type_from_ast(checker, type_node->data.type_array.element_type);
        if (element_type.kind == TYPE_VOID && type_node->data.type_array.element_type != NULL) {
            // 元素类型无效
            result.kind = TYPE_VOID;
            return result;
        }
        
        // 分配元素类型结构（从Arena分配）
        Type *element_type_ptr = (Type *)arena_alloc(checker->arena, sizeof(Type));
        if (element_type_ptr == NULL) {
            result.kind = TYPE_VOID;
            return result;
        }
        *element_type_ptr = element_type;
        
        // 解析数组大小（必须是编译期常量）
        // 注意：这里先简单验证，详细的编译期常量检查在类型检查阶段进行
        int array_size = 0;
        if (type_node->data.type_array.size_expr != NULL &&
            type_node->data.type_array.size_expr->type == AST_NUMBER) {
            array_size = type_node->data.type_array.size_expr->data.number.value;
            if (array_size <= 0) {
                // 数组大小必须为正整数
                result.kind = TYPE_VOID;
                return result;
            }
        } else {
            // 数组大小不是数字字面量，暂时返回无效类型
            // 详细的编译期常量检查在类型检查阶段进行
            result.kind = TYPE_VOID;
            return result;
        }
        
        // 创建数组类型
        result.kind = TYPE_ARRAY;
        result.data.array.element_type = element_type_ptr;
        result.data.array.array_size = array_size;
        
        return result;
    } else if (type_node->type == AST_TYPE_NAMED) {
        // 命名类型（i32, bool, byte, void, 或结构体名称）
        const char *type_name = type_node->data.type_named.name;
        if (type_name == NULL) {
            result.kind = TYPE_VOID;
            return result;
        }
        
        // 根据类型名称确定类型种类
        if (strcmp(type_name, "i32") == 0) {
            result.kind = TYPE_I32;
        } else if (strcmp(type_name, "usize") == 0) {
            result.kind = TYPE_USIZE;
        } else if (strcmp(type_name, "bool") == 0) {
            result.kind = TYPE_BOOL;
        } else if (strcmp(type_name, "byte") == 0) {
            result.kind = TYPE_BYTE;
        } else if (strcmp(type_name, "void") == 0) {
            result.kind = TYPE_VOID;
        } else {
            // 其他名称可能是枚举类型或结构体类型
            // 需要从program_node中查找枚举或结构体声明（在类型检查阶段验证）
            if (checker != NULL && checker->program_node != NULL) {
                // 先检查是否是枚举类型
                ASTNode *enum_decl = find_enum_decl_from_program(checker->program_node, type_name);
                if (enum_decl != NULL) {
                    result.kind = TYPE_ENUM;
                    result.data.enum_name = type_name;
                } else {
                    // 不是枚举类型，视为结构体类型
                    result.kind = TYPE_STRUCT;
                    result.data.struct_name = type_name;
                }
            } else {
                // 无法检查，暂时视为结构体类型（向后兼容）
                result.kind = TYPE_STRUCT;
                result.data.struct_name = type_name;
            }
        }
        
        return result;
    }
    
    // 无法识别的类型节点类型
    result.kind = TYPE_VOID;
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
        return result;
    }
    
    switch (expr->type) {
        case AST_NUMBER:
            // 数字字面量类型为i32
            result.kind = TYPE_I32;
            return result;
            
        case AST_BOOL:
            // 布尔字面量类型为bool
            result.kind = TYPE_BOOL;
            return result;
            
        case AST_STRING: {
            // 字符串字面量类型为 *byte（FFI 指针类型）
            // 创建指向 byte 类型的指针类型
            Type byte_type;
            byte_type.kind = TYPE_BYTE;
            
            // 分配指向的类型结构（从Arena分配）
            Type *pointed_type_ptr = (Type *)arena_alloc(checker->arena, sizeof(Type));
            if (pointed_type_ptr == NULL) {
                result.kind = TYPE_VOID;
                return result;
            }
            *pointed_type_ptr = byte_type;
            
            // 创建 FFI 指针类型（*byte）
            result.kind = TYPE_POINTER;
            result.data.pointer.pointer_to = pointed_type_ptr;
            result.data.pointer.is_ffi_pointer = 1;  // FFI 指针类型
            return result;
        }
            
        case AST_IDENTIFIER: {
            // 标识符类型需要从符号表中查找
            Symbol *symbol = symbol_table_lookup(checker, expr->data.identifier.name);
            if (symbol != NULL) {
                return symbol->type;
            }
            // 如果找不到符号，返回void类型（错误将在类型检查时报告）
            result.kind = TYPE_VOID;
            return result;
        }
        
        case AST_UNARY_EXPR: {
            // 一元表达式：根据运算符推断类型
            int op = expr->data.unary_expr.op;
            Type operand_type = checker_infer_type(checker, expr->data.unary_expr.operand);
            
            if (op == TOKEN_EXCLAMATION) {
                // 逻辑非（!）返回bool类型
                result.kind = TYPE_BOOL;
                return result;
            } else if (op == TOKEN_MINUS) {
                // 一元负号（-）返回操作数类型（应为i32）
                return operand_type;
            } else if (op == TOKEN_AMPERSAND) {
                // 取地址（&expr）：返回指向操作数类型的指针类型
                if (operand_type.kind == TYPE_VOID) {
                    // 操作数类型无效
                    result.kind = TYPE_VOID;
                    return result;
                }
                
                // 分配操作数类型结构（从Arena分配）
                Type *pointed_type_ptr = (Type *)arena_alloc(checker->arena, sizeof(Type));
                if (pointed_type_ptr == NULL) {
                    result.kind = TYPE_VOID;
                    return result;
                }
                *pointed_type_ptr = operand_type;
                
                // 创建指针类型（普通指针）
                result.kind = TYPE_POINTER;
                result.data.pointer.pointer_to = pointed_type_ptr;
                result.data.pointer.is_ffi_pointer = 0;  // 普通指针
                return result;
            } else if (op == TOKEN_ASTERISK) {
                // 解引用（*expr）：操作数必须是指针类型，返回指针指向的类型
                if (operand_type.kind != TYPE_POINTER) {
                    // 操作数不是指针类型
                    result.kind = TYPE_VOID;
                    return result;
                }
                
                if (operand_type.data.pointer.pointer_to == NULL) {
                    // 指针类型无效
                    result.kind = TYPE_VOID;
                    return result;
                }
                
                // 返回指针指向的类型
                return *operand_type.data.pointer.pointer_to;
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
                return result;
            }
            
            FunctionSignature *sig = function_table_lookup(checker, callee->data.identifier.name);
            if (sig != NULL) {
                return sig->return_type;
            }
            
            // 如果找不到函数，返回void类型（错误将在类型检查时报告）
            result.kind = TYPE_VOID;
            return result;
        }
        
        case AST_MEMBER_ACCESS: {
            // 字段访问：推断对象类型，然后查找字段类型
            Type object_type = checker_infer_type(checker, expr->data.member_access.object);
            if (object_type.kind != TYPE_STRUCT || object_type.data.struct_name == NULL) {
                // 对象类型不是结构体，返回void类型
                result.kind = TYPE_VOID;
                return result;
            }
            
            // 查找结构体声明
            ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, object_type.data.struct_name);
            if (struct_decl == NULL) {
                // 结构体声明未找到，返回void类型
                result.kind = TYPE_VOID;
                return result;
            }
            
            // 查找字段类型
            Type field_type = find_struct_field_type(checker, struct_decl, expr->data.member_access.field_name);
            return field_type;  // 如果字段不存在，field_type.kind 为 TYPE_VOID
        }
        
        case AST_ARRAY_ACCESS: {
            // 数组访问：推断数组表达式类型，然后返回元素类型
            Type array_type = checker_infer_type(checker, expr->data.array_access.array);
            if (array_type.kind != TYPE_ARRAY || array_type.data.array.element_type == NULL) {
                // 数组表达式类型不是数组类型，返回void类型
                result.kind = TYPE_VOID;
                return result;
            }
            
            // 返回数组的元素类型
            return *array_type.data.array.element_type;
        }
        
        case AST_STRUCT_INIT: {
            // 结构体字面量：返回结构体类型
            result.kind = TYPE_STRUCT;
            // 结构体名称需要存储在Arena中（从AST节点获取的名称已经在Arena中）
            result.data.struct_name = expr->data.struct_init.struct_name;
            return result;
        }
        
        case AST_ARRAY_LITERAL: {
            // 数组字面量：从第一个元素推断元素类型，使用元素数量作为数组大小
            int element_count = expr->data.array_literal.element_count;
            ASTNode **elements = expr->data.array_literal.elements;
            
            if (element_count == 0) {
                // 空数组：无法推断类型，返回void类型（错误将在类型检查时报告）
                result.kind = TYPE_VOID;
                return result;
            }
            
            // 从第一个元素推断元素类型
            Type element_type = checker_infer_type(checker, elements[0]);
            if (element_type.kind == TYPE_VOID) {
                // 元素类型无效
                result.kind = TYPE_VOID;
                return result;
            }
            
            // 分配元素类型结构（从Arena分配）
            Type *element_type_ptr = (Type *)arena_alloc(checker->arena, sizeof(Type));
            if (element_type_ptr == NULL) {
                result.kind = TYPE_VOID;
                return result;
            }
            *element_type_ptr = element_type;
            
            // 创建数组类型
            result.kind = TYPE_ARRAY;
            result.data.array.element_type = element_type_ptr;
            result.data.array.array_size = element_count;
            
            return result;
        }
        
        case AST_SIZEOF: {
            // sizeof 表达式：返回 i32 类型（字节数）
            // 注意：这里不验证 target 是否有效，类型检查阶段会验证
            result.kind = TYPE_I32;
            return result;
        }
        
        case AST_ALIGNOF: {
            // alignof 表达式：返回 i32 类型（对齐字节数）
            // 注意：这里不验证 target 是否有效，类型检查阶段会验证
            result.kind = TYPE_I32;
            return result;
        }
        
        case AST_LEN: {
            // len 表达式：返回 i32 类型（元素个数）
            // 注意：这里不验证 array 是否是数组类型，类型检查阶段会验证
            result.kind = TYPE_I32;
            return result;
        }
        
        case AST_CAST_EXPR: {
            // 类型转换表达式：返回目标类型
            // 注意：这里不验证转换是否合法，类型检查阶段会验证
            ASTNode *target_type_node = expr->data.cast_expr.target_type;
            if (target_type_node == NULL) {
                result.kind = TYPE_VOID;
                return result;
            }
            return type_from_ast(checker, target_type_node);
        }
        
        default:
            // 其他表达式类型，返回void类型
            result.kind = TYPE_VOID;
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

// 从程序节点中查找枚举声明
static ASTNode *find_enum_decl_from_program(ASTNode *program_node, const char *enum_name) {
    if (program_node == NULL || program_node->type != AST_PROGRAM || enum_name == NULL) {
        return NULL;
    }
    
    for (int i = 0; i < program_node->data.program.decl_count; i++) {
        ASTNode *decl = program_node->data.program.decls[i];
        if (decl != NULL && decl->type == AST_ENUM_DECL) {
            if (decl->data.enum_decl.name != NULL && 
                strcmp(decl->data.enum_decl.name, enum_name) == 0) {
                return decl;
            }
        }
    }
    
    return NULL;
}

// 报告类型错误（增加错误计数）
// 参数：checker - TypeChecker 指针
// 报告类型检查错误
// 参数：checker - TypeChecker 指针，node - AST 节点（用于获取行号和列号），message - 错误消息
static void checker_report_error(TypeChecker *checker, ASTNode *node, const char *message) {
    if (checker != NULL) {
        checker->error_count++;
        
        // 输出错误信息（格式：文件名:(行:列)）
        const char *filename = checker->default_filename ? checker->default_filename : "(unknown)";
        if (node != NULL) {
            fprintf(stderr, "%s:(%d:%d): 错误: %s\n", 
                    filename,
                    node->line, 
                    node->column,
                    message ? message : "类型检查错误");
        } else {
            fprintf(stderr, "%s: 错误: %s\n", 
                    filename,
                    message ? message : "类型检查错误");
        }
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
    checker_report_error(checker, expr, "表达式类型不匹配");
    return 0;
}

// 在结构体声明中查找字段
// 参数：checker - 类型检查器指针，struct_decl - 结构体声明节点，field_name - 字段名称
// 返回：找到的字段类型，未找到返回TYPE_VOID类型
static Type find_struct_field_type(TypeChecker *checker, ASTNode *struct_decl, const char *field_name) {
    Type result;
    result.kind = TYPE_VOID;
    
    if (checker == NULL || struct_decl == NULL || struct_decl->type != AST_STRUCT_DECL || field_name == NULL) {
        return result;
    }
    
    for (int i = 0; i < struct_decl->data.struct_decl.field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (field != NULL && field->type == AST_VAR_DECL) {
            if (field->data.var_decl.name != NULL && 
                strcmp(field->data.var_decl.name, field_name) == 0) {
                // 找到字段，返回字段类型
                return type_from_ast(checker, field->data.var_decl.type);
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
                strcmp(type_name, "bool") != 0 && strcmp(type_name, "byte") != 0 && 
                strcmp(type_name, "void") != 0) {
                // 可能是结构体类型，检查是否存在
                ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, type_name);
                if (struct_decl == NULL) {
                    // 结构体类型未定义
                    checker_report_error(checker, node->data.var_decl.type, "结构体类型未定义");
                    return 0;
                }
                var_type.kind = TYPE_STRUCT;
                var_type.data.struct_name = type_name;
            }
        }
    }
    
    // 检查初始化表达式类型
    if (node->data.var_decl.init != NULL) {
        // 特殊处理空数组字面量：如果变量类型是数组类型，空数组字面量表示未初始化
        if (node->data.var_decl.init->type == AST_ARRAY_LITERAL &&
            node->data.var_decl.init->data.array_literal.element_count == 0 &&
            var_type.kind == TYPE_ARRAY) {
            // 空数组字面量用于数组类型变量，允许（表示未初始化）
            // 不需要进一步检查，直接跳过类型比较
        } else {
            // 先递归检查初始化表达式本身（包括函数调用、运算符等的类型检查）
            checker_check_node(checker, node->data.var_decl.init);
            // 然后推断类型并比较
            Type init_type = checker_infer_type(checker, node->data.var_decl.init);
            if (!type_equals(init_type, var_type)) {
                // 初始化表达式类型不匹配
                checker_report_error(checker, node->data.var_decl.init, "变量初始化表达式类型不匹配");
                return 0;
            }
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
        checker_report_error(checker, node, "变量重复定义");
        return 0;
    }
    
    return 1;
}

// 注册函数声明（仅收集函数签名，不检查函数体）
// 参数：checker - TypeChecker 指针，node - 函数声明节点
// 返回：1 表示注册成功，0 表示注册失败
// 注意：此函数用于第一遍检查，只收集函数签名到函数表，不检查函数体
static int checker_register_fn_decl(TypeChecker *checker, ASTNode *node) {
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
    sig->is_varargs = node->data.fn_decl.is_varargs;  // 是否为可变参数函数
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

                // 检查是否为 FFI 指针类型（*T），如果是普通函数则不允许
                if (!sig->is_extern && param_type.kind == TYPE_POINTER && param_type.data.pointer.is_ffi_pointer) {
                    // 普通函数不能使用 FFI 指针类型作为参数
                    checker_report_error(checker, node, "类型检查错误");
                    return 0;
                }

                sig->param_types[i] = param_type;
            }
        }
    } else {
        sig->param_types = NULL;
    }

    // 检查返回类型是否为 FFI 指针类型（如果是普通函数则不允许）
    if (!sig->is_extern && return_type.kind == TYPE_POINTER && return_type.data.pointer.is_ffi_pointer) {
        // 普通函数不能使用 FFI 指针类型作为返回类型
        checker_report_error(checker, node, "类型检查错误");
        return 0;
    }

    // 将函数添加到函数表
    if (function_table_insert(checker, sig) != 0) {
        // 函数重复定义
        checker_report_error(checker, node, "类型检查错误");
        return 0;
    }

    return 1;
}

// 检查函数声明
// 参数：checker - TypeChecker 指针，node - 函数声明节点
// 返回：1 表示检查通过，0 表示检查失败
// 注意：此函数假设函数签名已经通过 checker_register_fn_decl 注册到函数表
static int checker_check_fn_decl(TypeChecker *checker, ASTNode *node) {
    if (checker == NULL || node == NULL || node->type != AST_FN_DECL) {
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
            ASTNode *field_type_node = field->data.var_decl.type;
            if (field_type_node == NULL) {
                checker_report_error(checker, field, "结构体字段类型不能为空");
                return 0;
            }
            
            Type field_type = type_from_ast(checker, field_type_node);
            if (field_type.kind == TYPE_VOID) {
                // 字段类型无效，检查是否是结构体前向引用
                if (field_type_node->type == AST_TYPE_NAMED) {
                    const char *type_name = field_type_node->data.type_named.name;
                    if (type_name != NULL) {
                        // 检查是否是已知的基础类型（这些不应该返回 TYPE_VOID）
                        if (strcmp(type_name, "i32") == 0 || strcmp(type_name, "usize") == 0 ||
                            strcmp(type_name, "bool") == 0 || strcmp(type_name, "byte") == 0 ||
                            strcmp(type_name, "void") == 0) {
                            // 基础类型应该能正确解析，如果返回 TYPE_VOID 说明有问题
                            checker_report_error(checker, field_type_node, "无效的字段类型");
                            return 0;
                        }
                        // 可能是结构体或枚举类型的前向引用，暂时允许（TODO: 支持前向声明或两遍检查）
                    } else {
                        checker_report_error(checker, field_type_node, "字段类型名称为空");
                        return 0;
                    }
                } else {
                    // 非命名类型（指针、数组等）如果返回 TYPE_VOID，说明类型无效
                    checker_report_error(checker, field_type_node, "无效的字段类型");
                    return 0;
                }
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
    
    if (checker == NULL || node == NULL || node->type != AST_CALL_EXPR) {
        return result;
    }
    
    // 查找被调用的函数
    ASTNode *callee = node->data.call_expr.callee;
    if (callee == NULL || callee->type != AST_IDENTIFIER) {
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    FunctionSignature *sig = function_table_lookup(checker, callee->data.identifier.name);
    if (sig == NULL) {
        // 函数未定义
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 检查参数个数
    // 对于可变参数函数，参数个数必须 >= 固定参数数量
    // 对于普通函数，参数个数必须 == 固定参数数量
    if (sig->is_varargs) {
        // 可变参数函数：参数个数必须 >= 固定参数数量
        if (node->data.call_expr.arg_count < sig->param_count) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
    } else {
        // 普通函数：参数个数必须 == 固定参数数量
        if (node->data.call_expr.arg_count != sig->param_count) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
    }
    
    // 检查参数类型（只检查固定参数，不检查可变参数部分）
    int check_count = (sig->is_varargs) ? sig->param_count : node->data.call_expr.arg_count;
    for (int i = 0; i < check_count; i++) {
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
    
    if (checker == NULL || node == NULL || node->type != AST_MEMBER_ACCESS) {
        return result;
    }
    
    // 获取对象类型
    Type object_type = checker_infer_type(checker, node->data.member_access.object);
    
    // 如果对象是指针类型，自动解引用（Uya Mini 支持指针自动解引用访问字段）
    if (object_type.kind == TYPE_POINTER && object_type.data.pointer.pointer_to != NULL) {
        object_type = *object_type.data.pointer.pointer_to;
    }
    
    if (object_type.kind != TYPE_STRUCT || object_type.data.struct_name == NULL) {
        // 对象类型不是结构体
        checker_report_error(checker, node, "对象类型不是结构体，无法访问字段");
        return result;
    }
    
    // 查找结构体声明
    ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, object_type.data.struct_name);
    if (struct_decl == NULL) {
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 查找字段类型
    Type field_type = find_struct_field_type(checker, struct_decl, node->data.member_access.field_name);
    if (field_type.kind == TYPE_VOID) {
        // 字段不存在
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    return field_type;
}

// 检查数组访问
// 参数：checker - TypeChecker 指针，node - 数组访问节点
// 返回：元素类型（如果检查失败返回TYPE_VOID）
static Type checker_check_array_access(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    
    if (checker == NULL || node == NULL || node->type != AST_ARRAY_ACCESS) {
        return result;
    }
    
    // 获取数组表达式类型
    Type array_type = checker_infer_type(checker, node->data.array_access.array);
    if (array_type.kind != TYPE_ARRAY || array_type.data.array.element_type == NULL) {
        // 数组表达式类型不是数组类型
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 检查索引表达式类型是 i32
    Type index_type = checker_infer_type(checker, node->data.array_access.index);
    if (index_type.kind != TYPE_I32) {
        // 索引表达式类型不是 i32
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 返回数组的元素类型
    return *array_type.data.array.element_type;
}

// 检查 alignof 表达式
// 参数：checker - TypeChecker 指针，node - alignof 表达式节点
// 返回：i32 类型（如果检查失败返回TYPE_VOID）
static Type checker_check_alignof(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    
    if (checker == NULL || node == NULL || node->type != AST_ALIGNOF) {
        return result;
    }
    
    // alignof 可以接受类型或表达式
    // 如果 target 是类型节点，验证类型是否有效
    // 如果 target 是表达式节点，验证表达式类型是否有效
    ASTNode *target = node->data.alignof_expr.target;
    if (target == NULL) {
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    if (node->data.alignof_expr.is_type) {
        // target 是类型节点，验证类型是否有效
        Type target_type = type_from_ast(checker, target);
        if (target_type.kind == TYPE_VOID) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
    } else {
        // target 是表达式节点，验证表达式类型是否有效
        Type expr_type = checker_infer_type(checker, target);
        if (expr_type.kind == TYPE_VOID) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
    }
    
    // alignof 返回 i32 类型（对齐字节数）
    result.kind = TYPE_I32;
    return result;
}

// 检查 len 表达式
// 参数：checker - TypeChecker 指针，node - len 表达式节点
// 返回：i32 类型（如果检查失败返回TYPE_VOID）
static Type checker_check_len(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    
    if (checker == NULL || node == NULL || node->type != AST_LEN) {
        return result;
    }
    
    // 获取数组表达式类型
    Type array_type = checker_infer_type(checker, node->data.len_expr.array);
    if (array_type.kind != TYPE_ARRAY || array_type.data.array.element_type == NULL) {
        // 数组表达式类型不是数组类型
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // len 返回 i32 类型（元素个数）
    result.kind = TYPE_I32;
    return result;
}

// 检查结构体字面量
// 参数：checker - TypeChecker 指针，node - 结构体字面量节点
// 返回：结构体类型（如果检查失败返回TYPE_VOID）
static Type checker_check_struct_init(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    
    if (checker == NULL || node == NULL || node->type != AST_STRUCT_INIT) {
        return result;
    }
    
    const char *struct_name = node->data.struct_init.struct_name;
    if (struct_name == NULL) {
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 查找结构体声明
    ASTNode *struct_decl = find_struct_decl_from_program(checker->program_node, struct_name);
    if (struct_decl == NULL) {
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 检查字段数量和类型
    if (node->data.struct_init.field_count != struct_decl->data.struct_decl.field_count) {
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 检查每个字段的类型
    for (int i = 0; i < node->data.struct_init.field_count; i++) {
        const char *field_name = node->data.struct_init.field_names[i];
        ASTNode *field_value = node->data.struct_init.field_values[i];
        
        Type field_type = find_struct_field_type(checker, struct_decl, field_name);
        if (field_type.kind == TYPE_VOID) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        
        if (!checker_check_expr_type(checker, field_value, field_type)) {
            return result;
        }
    }
    
    result.kind = TYPE_STRUCT;
    result.data.struct_name = struct_name;
    return result;
}

// 检查二元表达式
// 参数：checker - TypeChecker 指针，node - 二元表达式节点
// 返回：表达式类型（如果检查失败返回TYPE_VOID）
static Type checker_check_binary_expr(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    
    if (checker == NULL || node == NULL || node->type != AST_BINARY_EXPR) {
        return result;
    }
    
    int op = node->data.binary_expr.op;
    Type left_type = checker_infer_type(checker, node->data.binary_expr.left);
    Type right_type = checker_infer_type(checker, node->data.binary_expr.right);
    
    // 算术运算符：支持 i32 和 usize 混合运算
    // 规则：如果两个操作数都是 i32，结果为 i32
    //       如果至少有一个是 usize，结果为 usize
    if (op == TOKEN_PLUS || op == TOKEN_MINUS || op == TOKEN_ASTERISK || 
        op == TOKEN_SLASH || op == TOKEN_PERCENT) {
        // 验证操作数类型：必须是 i32 或 usize
        if ((left_type.kind != TYPE_I32 && left_type.kind != TYPE_USIZE) ||
            (right_type.kind != TYPE_I32 && right_type.kind != TYPE_USIZE)) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        // 结果类型：如果至少有一个是 usize，结果为 usize，否则为 i32
        if (left_type.kind == TYPE_USIZE || right_type.kind == TYPE_USIZE) {
            result.kind = TYPE_USIZE;
        } else {
            result.kind = TYPE_I32;
        }
        return result;
    }
    
    // 比较运算符：支持 i32 和 usize 比较（操作数可以是 i32 或 usize，但必须都是数值类型）
    if (op == TOKEN_EQUAL || op == TOKEN_NOT_EQUAL || op == TOKEN_LESS || 
        op == TOKEN_GREATER || op == TOKEN_LESS_EQUAL || op == TOKEN_GREATER_EQUAL) {
        // 允许相同类型比较，也允许 i32 和 usize 之间的比较
        if (type_equals(left_type, right_type)) {
            result.kind = TYPE_BOOL;
            return result;
        }
        // 允许 i32 和 usize 之间的比较
        if ((left_type.kind == TYPE_I32 && right_type.kind == TYPE_USIZE) ||
            (left_type.kind == TYPE_USIZE && right_type.kind == TYPE_I32)) {
            result.kind = TYPE_BOOL;
            return result;
        }
        // 其他类型不匹配
        checker_report_error(checker, node, "类型检查错误");
        return result;
    }
    
    // 逻辑运算符：操作数必须是bool
    if (op == TOKEN_LOGICAL_AND || op == TOKEN_LOGICAL_OR) {
        if (left_type.kind != TYPE_BOOL || right_type.kind != TYPE_BOOL) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        result.kind = TYPE_BOOL;
        return result;
    }
    
    return result;
}

// 检查类型转换表达式
// 参数：checker - TypeChecker 指针，node - 类型转换表达式节点
// 返回：无（通过 checker_report_error 报告错误）
static void checker_check_cast_expr(TypeChecker *checker, ASTNode *node) {
    if (checker == NULL || node == NULL || node->type != AST_CAST_EXPR) {
        return;
    }
    
    ASTNode *expr = node->data.cast_expr.expr;
    ASTNode *target_type_node = node->data.cast_expr.target_type;
    
    if (expr == NULL || target_type_node == NULL) {
        checker_report_error(checker, node, "类型检查错误");
        return;
    }
    
    // 推断源表达式类型和目标类型
    Type source_type = checker_infer_type(checker, expr);
    Type target_type = type_from_ast(checker, target_type_node);
    
    // 检查类型是否有效
    if (source_type.kind == TYPE_VOID || target_type.kind == TYPE_VOID) {
        checker_report_error(checker, node, "类型转换中的类型无效");
        return;
    }
    
    // 验证类型转换是否合法
    // 1. 支持 i32 ↔ byte、i32 ↔ bool、i32 ↔ usize
    if (source_type.kind == TYPE_I32 && target_type.kind == TYPE_BYTE) {
        // i32 as byte：允许
        return;
    } else if (source_type.kind == TYPE_BYTE && target_type.kind == TYPE_I32) {
        // byte as i32：允许
        return;
    } else if (source_type.kind == TYPE_I32 && target_type.kind == TYPE_BOOL) {
        // i32 as bool：允许
        return;
    } else if (source_type.kind == TYPE_BOOL && target_type.kind == TYPE_I32) {
        // bool as i32：允许
        return;
    } else if (source_type.kind == TYPE_I32 && target_type.kind == TYPE_USIZE) {
        // i32 as usize：允许
        return;
    } else if (source_type.kind == TYPE_USIZE && target_type.kind == TYPE_I32) {
        // usize as i32：允许
        return;
    }
    // 2. 支持指针类型之间的转换（&void 可以转换为任何指针类型）
    else if (source_type.kind == TYPE_POINTER && target_type.kind == TYPE_POINTER) {
        // 指针类型转换：允许 &void 转换为任何指针类型
        // 也允许相同类型的指针转换（虽然通常不需要）
        if (source_type.data.pointer.pointer_to == NULL) {
            // 源类型是 &void（pointer_to 为 NULL 表示 void）
            // 允许转换为任何指针类型
            return;
        } else if (target_type.data.pointer.pointer_to == NULL) {
            // 目标类型是 &void，允许任何指针类型转换为 &void
            return;
        } else if (source_type.data.pointer.pointer_to != NULL && target_type.data.pointer.pointer_to != NULL &&
                   type_equals(*source_type.data.pointer.pointer_to, *target_type.data.pointer.pointer_to) &&
                   source_type.data.pointer.is_ffi_pointer == target_type.data.pointer.is_ffi_pointer) {
            // 相同类型的指针转换（虽然通常不需要，但允许）
            return;
        } else {
            // 不同指针类型之间的转换（除了 &void 的情况）
            // 根据 Uya Mini 规范，允许指针类型之间的转换（unsafe cast）
            // 但这里暂时不允许，需要明确使用 unsafe 或改进类型系统
            checker_report_error(checker, node, "不支持的指针类型转换");
            return;
        }
    } else {
        // 不支持的类型转换
        checker_report_error(checker, node, "不支持的类型转换");
        return;
    }
}

// 检查一元表达式
// 参数：checker - TypeChecker 指针，node - 一元表达式节点
// 返回：表达式类型（如果检查失败返回TYPE_VOID）
static Type checker_check_unary_expr(TypeChecker *checker, ASTNode *node) {
    Type result;
    result.kind = TYPE_VOID;
    
    if (checker == NULL || node == NULL || node->type != AST_UNARY_EXPR) {
        return result;
    }
    
    int op = node->data.unary_expr.op;
    Type operand_type = checker_infer_type(checker, node->data.unary_expr.operand);
    
    if (op == TOKEN_EXCLAMATION) {
        // 逻辑非：操作数必须是bool
        if (operand_type.kind != TYPE_BOOL) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        result.kind = TYPE_BOOL;
        return result;
    } else if (op == TOKEN_MINUS) {
        // 一元负号：操作数必须是i32
        if (operand_type.kind != TYPE_I32) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        result.kind = TYPE_I32;
        return result;
    } else if (op == TOKEN_AMPERSAND) {
        // 取地址（&expr）：操作数必须是左值（变量、字段访问等）
        // 注意：这里简化处理，只要操作数类型有效就允许取地址
        // 完整的左值检查需要在更详细的语义分析阶段进行
        if (operand_type.kind == TYPE_VOID) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        
        // 分配操作数类型结构（从Arena分配）
        Type *pointed_type_ptr = (Type *)arena_alloc(checker->arena, sizeof(Type));
        if (pointed_type_ptr == NULL) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        *pointed_type_ptr = operand_type;
        
        // 返回指向操作数类型的指针类型（普通指针）
        result.kind = TYPE_POINTER;
        result.data.pointer.pointer_to = pointed_type_ptr;
        result.data.pointer.is_ffi_pointer = 0;
        return result;
    } else if (op == TOKEN_ASTERISK) {
        // 解引用（*expr）：操作数必须是指针类型
        if (operand_type.kind != TYPE_POINTER) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        
        if (operand_type.data.pointer.pointer_to == NULL) {
            checker_report_error(checker, node, "类型检查错误");
            return result;
        }
        
        // 返回指针指向的类型
        return *operand_type.data.pointer.pointer_to;
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
                checker_report_error(checker, node, "类型检查错误");
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
                checker_report_error(checker, node, "类型检查错误");
            }
            // 进入循环（增加循环深度）
            checker->loop_depth++;
            // 检查循环体
            if (node->data.while_stmt.body != NULL) {
                checker_check_node(checker, node->data.while_stmt.body);
            }
            // 退出循环（减少循环深度）
            checker->loop_depth--;
            return 1;
        }
        
        case AST_FOR_STMT: {
            // for 循环类型检查
            // 1. 检查数组表达式类型（必须是数组类型）
            Type array_type = checker_infer_type(checker, node->data.for_stmt.array);
            if (array_type.kind != TYPE_ARRAY || array_type.data.array.element_type == NULL) {
                checker_report_error(checker, node, "类型检查错误");
                // 即使类型错误，也继续检查循环体（以便报告更多错误）
            } else {
                // 2. 如果引用迭代形式，检查数组是否为可变变量
                if (node->data.for_stmt.is_ref) {
                    // 引用迭代形式只能用于可变数组（var arr）
                    // 需要检查数组表达式是否是可变变量
                    // 注意：这里简化处理，如果数组表达式是标识符，检查符号表
                    if (node->data.for_stmt.array->type == AST_IDENTIFIER) {
                        Symbol *symbol = symbol_table_lookup(checker, node->data.for_stmt.array->data.identifier.name);
                        if (symbol != NULL && symbol->is_const) {
                            // 引用迭代形式不能用于 const 变量
                            checker_report_error(checker, node, "类型检查错误");
                        }
                    }
                    // 其他情况（如数组字面量）也允许引用迭代，但运行时可能出错
                }
                
                // 3. 进入循环作用域并添加循环变量
                checker_enter_scope(checker);
                checker->loop_depth++;  // 进入循环（增加循环深度）
                
                // 创建循环变量类型
                Type var_type;
                if (node->data.for_stmt.is_ref) {
                    // 引用迭代：变量类型为 &T（指向元素的指针）
                    Type element_type = *array_type.data.array.element_type;
                    Type *element_type_ptr = (Type *)arena_alloc(checker->arena, sizeof(Type));
                    if (element_type_ptr == NULL) {
                        checker_report_error(checker, node, "类型检查错误");
                    } else {
                        *element_type_ptr = element_type;
                        var_type.kind = TYPE_POINTER;
                        var_type.data.pointer.pointer_to = element_type_ptr;
                        var_type.data.pointer.is_ffi_pointer = 0;
                    }
                } else {
                    // 值迭代：变量类型为数组元素类型 T
                    var_type = *array_type.data.array.element_type;
                }
                
                // 添加循环变量到符号表（var，可修改）
                Symbol *loop_var = (Symbol *)arena_alloc(checker->arena, sizeof(Symbol));
                if (loop_var == NULL) {
                    checker_report_error(checker, node, "类型检查错误");
                } else {
                    loop_var->name = node->data.for_stmt.var_name;
                    loop_var->type = var_type;
                    loop_var->is_const = 0;  // for 循环变量是可修改的（即使是值迭代形式，在循环体内也可以使用）
                    loop_var->scope_level = checker->scope_level;
                    loop_var->line = node->line;
                    loop_var->column = node->column;
                    if (!symbol_table_insert(checker, loop_var)) {
                        checker_report_error(checker, node, "类型检查错误");
                    }
                }
                
                // 4. 检查循环体
                if (node->data.for_stmt.body != NULL) {
                    checker_check_node(checker, node->data.for_stmt.body);
                }
                
                // 5. 退出循环作用域和循环深度
                checker->loop_depth--;
                checker_exit_scope(checker);
            }
            return 1;
        }
        
        case AST_BREAK_STMT: {
            // 检查 break 是否在循环中
            if (checker->loop_depth == 0) {
                checker_report_error(checker, node, "类型检查错误");
                return 0;
            }
            return 1;
        }
        
        case AST_CONTINUE_STMT: {
            // 检查 continue 是否在循环中
            if (checker->loop_depth == 0) {
                checker_report_error(checker, node, "类型检查错误");
                return 0;
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
            // 检查赋值目标（可以是标识符或字段访问）
            ASTNode *dest = node->data.assign.dest;
            if (dest == NULL) {
                checker_report_error(checker, node, "赋值目标不能为空");
                return 0;
            }
            
            Type dest_type;
            if (dest->type == AST_IDENTIFIER) {
                // 标识符赋值：检查是否为 var（不能是 const）
                Symbol *symbol = symbol_table_lookup(checker, dest->data.identifier.name);
                if (symbol == NULL) {
                    checker_report_error(checker, dest, "未定义的变量");
                    return 0;
                }
                
                if (symbol->is_const) {
                    // 不能给 const 变量赋值
                    checker_report_error(checker, dest, "不能给 const 变量赋值");
                    return 0;
                }
                
                dest_type = symbol->type;
            } else if (dest->type == AST_MEMBER_ACCESS) {
                // 字段访问赋值：检查字段类型
                dest_type = checker_check_member_access(checker, dest);
                if (dest_type.kind == TYPE_VOID) {
                    // 字段访问失败（错误已在 checker_check_member_access 中报告）
                    return 0;
                }
            } else {
                checker_report_error(checker, dest, "无效的赋值目标");
                return 0;
            }
            
            // 检查赋值类型匹配
            if (!checker_check_expr_type(checker, node->data.assign.src, dest_type)) {
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
            
        case AST_ARRAY_ACCESS:
            checker_check_array_access(checker, node);
            return 1;
            
        case AST_STRUCT_INIT:
            checker_check_struct_init(checker, node);
            return 1;
            
        case AST_CAST_EXPR:
            checker_check_cast_expr(checker, node);
            return 1;
            
        case AST_ALIGNOF:
            checker_check_alignof(checker, node);
            return 1;
            
        case AST_LEN:
            checker_check_len(checker, node);
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
// 实现两遍检查机制：
// 第一遍：收集所有函数声明（解决函数循环依赖问题）
// 第二遍：检查所有声明（包括函数体、结构体、变量等）
int checker_check(TypeChecker *checker, ASTNode *ast) {
    if (checker == NULL || ast == NULL || ast->type != AST_PROGRAM) {
        return -1;
    }
    
    checker->program_node = ast;
    checker->error_count = 0;
    
    // 第一遍：收集所有函数声明（只注册函数签名，不检查函数体）
    // 这样在第二遍检查函数体时，所有函数都已被注册，可以相互调用
    for (int i = 0; i < ast->data.program.decl_count; i++) {
        ASTNode *decl = ast->data.program.decls[i];
        if (decl != NULL && decl->type == AST_FN_DECL) {
            if (checker_register_fn_decl(checker, decl) == 0) {
                return -1;  // 注册失败，返回错误
            }
        }
    }
    
    // 第二遍：检查所有声明（包括函数体、结构体、变量等）
    // 此时所有函数都已被注册，函数体中的函数调用可以正确解析
    checker_check_node(checker, ast);
    
    return 0;
}

